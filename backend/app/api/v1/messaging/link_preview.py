"""Pokou — aperçu d'un lien partagé dans un message (titre/description/image
Open Graph), façon WhatsApp/Telegram/iMessage.

Danger central de cette fonctionnalité : le SERVEUR va chercher une URL que
N'IMPORTE QUEL utilisateur lui fournit. Sans garde-fou, c'est une porte
ouverte au SSRF — un lien vers http://169.254.169.254/ (métadonnées cloud),
http://localhost:5432 (Postgres du même hôte) ou une IP de rack interne
ferait de l'API un proxy pour sonder le réseau qui l'héberge. D'où :
- seuls http/https sont acceptés ;
- l'IP RÉELLEMENT résolue est vérifiée (pas juste l'apparence de l'URL —
  un domaine public peut très bien résoudre vers une IP privée) et toute IP
  privée/loopback/link-local/réservée est refusée ;
- redirections suivies MAIS chaque saut revérifié pour la même raison (un
  serveur au premier hop légitime pourrait rediriger en interne) ;
- taille et temps de réponse bornés — on ne télécharge qu'un aperçu, pas le
  fichier entier derrière un lien de plusieurs gigaoctets.
"""
import ipaddress
import logging
import socket
import time
from collections import OrderedDict
from typing import Any, Optional
from urllib.parse import urlparse

import httpx
from bs4 import BeautifulSoup
from fastapi import APIRouter, Depends, HTTPException, Query, Response

from app.core.security import get_current_user

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/link-preview", tags=["Pokou link preview"])

_MAX_REDIRECTS = 3
_TIMEOUT_SECONDS = 5.0
_MAX_BYTES = 1_000_000  # 1 Mo — largement assez pour le <head> d'une page
_USER_AGENT = "PokouLinkPreview/1.0 (+https://pok.app)"

# Une image d'aperçu Open Graph pèse quelques dizaines de kilo-octets. La
# borne est large, mais elle existe : sans elle, une page pourrait annoncer
# en `og:image` un fichier de plusieurs gigaoctets et faire tenir l'API
# occupée à le télécharger.
_MAX_IMAGE_BYTES = 2_000_000

# ── Le cache ──────────────────────────────────────────────────────────────
#
# Il n'y en avait aucun : chaque bulle de message contenant un lien, sur
# chaque appareil, à chaque défilement, déclenchait une requête sortante
# vers le site tiers. Dix personnes dans un groupe qui partage un lien, ça
# faisait dix visites — puis dix de plus à chaque relecture de la
# conversation.
#
# Un dictionnaire ordonné borné, en mémoire du processus : pas de dépendance
# nouvelle, pas de table, rien à purger à la main. Le cache est par
# processus, donc plusieurs ouvriers gunicorn en tiennent chacun un ; c'est
# volontairement accepté — l'objectif est de diviser le trafic sortant par
# un grand facteur, pas d'être exact.
_PREVIEW_TTL_SECONDS = 6 * 3600
_IMAGE_TTL_SECONDS = 24 * 3600
# Un aperçu VIDE se retient beaucoup moins longtemps. Un site qui n'a pas
# d'Open Graph n'en aura pas dans six heures non plus, mais un timeout
# réseau, lui, se répare tout seul — le retenir une demi-journée
# transformerait une coupure passagère en absence durable.
_VIDE_TTL_SECONDS = 10 * 60
_PREVIEW_CACHE_SIZE = 512
# Les images se bornent en OCTETS, pas en nombre d'entrées.
#
# Une borne à 128 entrées de 2 Mo chacune autorise 256 Mo de mémoire vive
# pour un cache d'illustrations — plus que ce que l'API entière a le droit
# d'occuper. En pratique une image Open Graph pèse une centaine de
# kilo-octets, donc 24 Mo en tiennent largement deux cents ; et le pire cas
# reste borné quoi qu'annonce le site d'en face.
_IMAGE_CACHE_MAX_BYTES = 24 * 1024 * 1024

# La date d'EXPIRATION est stockée avec l'entrée, pas déduite à la lecture :
# c'est ce qui permet deux durées de vie différentes dans le même cache.
_previews: "OrderedDict[str, tuple[float, dict[str, Any]]]" = OrderedDict()
_images: "OrderedDict[str, tuple[float, str, bytes]]" = OrderedDict()


def _cache_lire(cache: OrderedDict, cle: str):
    entree = cache.get(cle)
    if entree is None:
        return None
    if time.monotonic() > entree[0]:
        cache.pop(cle, None)
        return None
    cache.move_to_end(cle)
    return entree[1:]


def _cache_ecrire(cache: OrderedDict, cle: str, valeur: tuple, ttl: float, taille: int) -> None:
    cache[cle] = (time.monotonic() + ttl,) + valeur
    cache.move_to_end(cle)
    while len(cache) > taille:
        cache.popitem(last=False)


def _cache_image_ecrire(cle: str, type_mime: str, corps: bytes) -> None:
    """Écrit une image et expulse les plus anciennes jusqu'à repasser sous la
    borne d'octets."""
    _images[cle] = (time.monotonic() + _IMAGE_TTL_SECONDS, type_mime, corps)
    _images.move_to_end(cle)
    total = sum(len(v[2]) for v in _images.values())
    while total > _IMAGE_CACHE_MAX_BYTES and len(_images) > 1:
        _, expulsee = _images.popitem(last=False)
        total -= len(expulsee[2])


def _is_public_hostname(hostname: str) -> bool:
    """Résout le nom d'hôte et refuse toute IP privée/loopback/link-local/
    réservée — voir la docstring du module. `getaddrinfo` peut renvoyer
    plusieurs IP (round-robin DNS) : la moindre IP privée dans le lot fait
    échouer la vérification, un attaquant contrôlant le DNS pourrait sinon
    alterner une réponse publique (passe la vérification) et une privée
    (utilisée pour la requête réelle)."""
    try:
        infos = socket.getaddrinfo(hostname, None)
    except socket.gaierror:
        return False
    for info in infos:
        ip = ipaddress.ip_address(info[4][0])
        if ip.is_private or ip.is_loopback or ip.is_link_local or ip.is_reserved or ip.is_multicast:
            return False
    return True


def _validate_url(url: str) -> str:
    parsed = urlparse(url)
    if parsed.scheme not in ("http", "https") or not parsed.hostname:
        raise HTTPException(status_code=400, detail="URL invalide — http(s) uniquement")
    if not _is_public_hostname(parsed.hostname):
        raise HTTPException(status_code=400, detail="Cette adresse n'est pas accessible")
    return url


def _extract_meta(soup: BeautifulSoup, *names: str) -> Optional[str]:
    for name in names:
        tag = soup.find("meta", attrs={"property": name}) or soup.find("meta", attrs={"name": name})
        if tag and tag.get("content"):
            return tag["content"].strip()[:500]
    return None


@router.get("")
async def get_link_preview(
    url: str = Query(..., max_length=2000),
    current_user: dict = Depends(get_current_user),
):
    """Renvoie `{url, title, description, image}` (n'importe quel champ peut
    être `null`) — jamais une erreur dure pour un lien qui ne se laisse pas
    résumer : un aperçu manquant doit juste faire disparaître la carte côté
    client, pas casser l'affichage du message."""
    _validate_url(url)

    en_cache = _cache_lire(_previews, url)
    if en_cache is not None:
        return en_cache[0]

    try:
        async with httpx.AsyncClient(
            timeout=_TIMEOUT_SECONDS,
            follow_redirects=False,  # on gère la redirection nous-mêmes pour revalider chaque saut
            headers={"User-Agent": _USER_AGENT},
        ) as client:
            current_url = url
            html = ""
            for _ in range(_MAX_REDIRECTS + 1):
                async with client.stream("GET", current_url) as response:
                    if response.is_redirect:
                        next_url = response.headers.get("location")
                        if not next_url:
                            break
                        current_url = httpx.URL(current_url).join(next_url).human_repr()
                        _validate_url(current_url)
                        continue
                    content_type = response.headers.get("content-type", "")
                    if "text/html" not in content_type:
                        return _sans_apercu(url)
                    body = b""
                    async for chunk in response.aiter_bytes():
                        body += chunk
                        if len(body) >= _MAX_BYTES:
                            break
                    html = body.decode(response.encoding or "utf-8", errors="ignore")
                    break
    except (httpx.HTTPError, OSError) as exc:
        logger.info("[LinkPreview] Récupération impossible pour %s: %s", url, exc)
        # Un échec se retient AUSSI, mais dix minutes seulement : sinon un
        # lien mort relance une requête sortante à chaque défilement, et une
        # coupure passagère ne resterait pas gravée pour la journée.
        return _sans_apercu(url)

    if not html:
        return _sans_apercu(url)

    soup = BeautifulSoup(html, "lxml")
    title = _extract_meta(soup, "og:title", "twitter:title")
    if not title and soup.title:
        title = soup.title.get_text(strip=True)[:200]
    description = _extract_meta(soup, "og:description", "twitter:description", "description")
    image = _extract_meta(soup, "og:image", "twitter:image")
    # Une image relative (« /img/preview.png ») ne veut rien dire hors de son
    # site — on la rend absolue pour que le client puisse l'afficher telle
    # quelle, sans connaître l'URL d'origine.
    if image and not urlparse(image).netloc:
        image = httpx.URL(current_url).join(image).human_repr()

    apercu = {"url": url, "title": title, "description": description, "image": image}
    _cache_ecrire(_previews, url, (apercu,), _PREVIEW_TTL_SECONDS, _PREVIEW_CACHE_SIZE)
    return apercu


def _sans_apercu(url: str) -> dict:
    vide = {"url": url, "title": None, "description": None, "image": None}
    _cache_ecrire(_previews, url, (vide,), _VIDE_TTL_SECONDS, _PREVIEW_CACHE_SIZE)
    return vide


@router.get("/image")
async def get_link_preview_image(
    url: str = Query(..., max_length=2000),
    current_user: dict = Depends(get_current_user),
):
    """L'illustration d'un aperçu, RELAYÉE par l'API.

    Ce module dit depuis le premier jour que c'est toujours le serveur qui
    va chercher la page, jamais l'application, pour ne pas livrer au site
    tiers l'adresse IP de l'utilisateur ni le moment où il lit un message.
    L'`og:image` sortait pourtant du serveur sous forme d'URL brute, et le
    client l'affichait avec un `Image.network` : le téléphone allait donc
    lui-même chercher l'image chez le tiers, et lui annonçait son IP, son
    agent, et l'instant exact où la conversation s'ouvrait. La promesse
    tenait pour le HTML et tombait sur l'image — c'est-à-dire sur la seule
    ressource que l'utilisateur voit forcément se charger.

    Même validation SSRF que l'aperçu lui-même : l'URL vient d'une page
    tierce, donc d'un inconnu, exactement comme celle que l'utilisateur colle.
    """
    _validate_url(url)

    en_cache = _cache_lire(_images, url)
    if en_cache is not None:
        type_mime, corps = en_cache
        return Response(content=corps, media_type=type_mime)

    try:
        async with httpx.AsyncClient(
            timeout=_TIMEOUT_SECONDS,
            follow_redirects=False,
            headers={"User-Agent": _USER_AGENT},
        ) as client:
            courante = url
            for _ in range(_MAX_REDIRECTS + 1):
                async with client.stream("GET", courante) as response:
                    if response.is_redirect:
                        suivante = response.headers.get("location")
                        if not suivante:
                            raise HTTPException(status_code=404, detail="Image introuvable")
                        courante = httpx.URL(courante).join(suivante).human_repr()
                        _validate_url(courante)
                        continue
                    type_mime = response.headers.get("content-type", "").split(";")[0].strip()
                    if not type_mime.startswith("image/"):
                        raise HTTPException(status_code=415, detail="Ce lien ne renvoie pas une image")
                    corps = b""
                    async for morceau in response.aiter_bytes():
                        corps += morceau
                        if len(corps) > _MAX_IMAGE_BYTES:
                            raise HTTPException(status_code=413, detail="Image trop lourde")
                    _cache_image_ecrire(url, type_mime, corps)
                    return Response(content=corps, media_type=type_mime)
            raise HTTPException(status_code=404, detail="Image introuvable")
    except (httpx.HTTPError, OSError) as exc:
        logger.info("[LinkPreview] Image inaccessible pour %s: %s", url, exc)
        raise HTTPException(status_code=404, detail="Image introuvable")
