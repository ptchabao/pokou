"""Vignettes d'images — parce que rien n'en produisait.

`GET /media/{id}` servait le fichier d'ORIGINE, toujours, quelle que soit la
taille à laquelle il allait s'afficher. Une photo prise au téléphone pèse
deux à cinq méga-octets ; la pastille d'un contact fait 40 points de côté et
la vignette d'une annonce 76. Une liste de contacts téléchargeait donc
plusieurs dizaines de méga-octets pour afficher l'équivalent de quelques
dizaines de kilo-octets — sur un réseau mobile à Lomé, c'est la différence
entre « instantané » et « on attend ».

Le cache mémoire et la borne de décodage posés côté application ne pouvaient
rien contre ça : ils évitent de REFAIRE le travail, pas de le faire une
première fois.

── Ce que ce module garantit ─────────────────────────────────────────────

- **Des largeurs FERMÉES.** `?w=` n'accepte que trois valeurs. Sans cette
  liste, n'importe qui pouvait demander dix mille largeurs différentes sur
  la même image et remplir le disque — un déni de service qui ne ressemble
  même pas à une attaque dans les journaux.
- **Un travail fait une seule fois.** La vignette est écrite à côté de
  l'original, et relue ensuite. Redimensionner à chaque requête aurait
  seulement déplacé le coût du réseau vers le processeur.
- **Jamais d'agrandissement.** Une image déjà plus petite que la largeur
  demandée est servie telle quelle : la réencoder la rendrait plus lourde,
  pas plus légère.
- **Aucune décision d'accès.** Ce module ne sait pas qui demande. C'est
  `media.py::_can_access` qui décide, avant d'arriver ici, et lui seul.
"""
import logging
from io import BytesIO
from pathlib import Path
from typing import Optional

from app.services.media import media_storage

logger = logging.getLogger(__name__)

#: Les seules largeurs servies, en points logiques × la densité usuelle.
#:
#: 96 → pastilles de contact et d'appel ; 320 → vignettes du catalogue, de
#: la grille du marché et des chaînes ; 1080 → images pleine largeur (fiche
#: produit, publication de chaîne, bulle de conversation). Au-delà,
#: l'original — c'est ce que demande une visionneuse plein écran, où la
#: définition est précisément le sujet.
LARGEURS = (96, 320, 1080)

#: Au-dessus, on ne tente pas : décompresser une image de très grande
#: définition coûte de la mémoire vive proportionnelle à sa surface, et
#: c'est le vecteur classique de la « bombe de décompression ».
_SURFACE_MAX = 50_000_000  # 50 mégapixels

_TYPES = {"image/jpeg", "image/jpg", "image/png", "image/webp"}

#: Qualité JPEG de sortie. 82 est le point où l'on cesse de voir la
#: différence à l'œil sur une vignette, et où le fichier a déjà fondu.
_QUALITE = 82


def largeur_valide(valeur: Optional[int]) -> Optional[int]:
    """La largeur demandée si elle fait partie de la liste, sinon `None`.

    `None` veut dire « sers l'original » — jamais « erreur ». Une largeur
    inconnue ne doit pas faire échouer l'affichage d'une image : au pire on
    renvoie ce qu'on a toujours renvoyé.
    """
    return valeur if valeur in LARGEURS else None


def peut_etre_redimensionne(mime_type: str) -> bool:
    return (mime_type or "").lower() in _TYPES


def _chemin_vignette(asset_id: int, largeur: int) -> Path:
    dossier = media_storage._storage_dir() / "thumbs"
    dossier.mkdir(parents=True, exist_ok=True)
    return dossier / f"{asset_id}_{largeur}.jpg"


def vignette(asset, largeur: int, source: bytes) -> Optional[Path]:
    """Le chemin de la vignette, en la produisant si elle n'existe pas encore.

    `None` si l'image ne peut pas être réduite — format non géré, fichier
    illisible, ou déjà plus étroite que la largeur demandée. L'appelant sert
    alors l'original, ce qui est exactement le comportement d'avant.
    """
    if not peut_etre_redimensionne(asset.mime_type):
        return None

    chemin = _chemin_vignette(asset.id, largeur)
    if chemin.exists():
        return chemin

    try:
        from PIL import Image, ImageOps
    except ImportError:  # pragma: no cover - Pillow est dans requirements.txt
        logger.warning("[Vignettes] Pillow absent — l'original sera servi")
        return None

    try:
        with Image.open(BytesIO(source)) as image:
            if image.width * image.height > _SURFACE_MAX:
                logger.info(
                    "[Vignettes] média %s ignoré : %s×%s dépasse la surface maximale",
                    asset.id, image.width, image.height,
                )
                return None
            if image.width <= largeur:
                # Déjà plus petite : la réencoder l'alourdirait.
                return None

            # `exif_transpose` AVANT le redimensionnement : sans lui, une
            # photo prise en portrait sur un téléphone ressort couchée. Le
            # visualiseur d'origine lisait l'orientation EXIF, la vignette
            # ne la porte plus.
            image = ImageOps.exif_transpose(image)
            hauteur = max(1, round(image.height * largeur / image.width))
            reduite = image.resize((largeur, hauteur), Image.LANCZOS)
            if reduite.mode not in ("RGB", "L"):
                # La transparence n'a pas de sens en JPEG ; on aplatit sur
                # du blanc plutôt que de produire un fond noir.
                fond = Image.new("RGB", reduite.size, (255, 255, 255))
                masque = reduite.split()[-1] if reduite.mode in ("RGBA", "LA") else None
                fond.paste(reduite.convert("RGB"), mask=masque)
                reduite = fond
            # Écriture atomique : deux requêtes simultanées sur la même
            # vignette produiraient sinon un fichier à moitié écrit, que la
            # seconde servirait tronqué.
            temporaire = chemin.with_suffix(f".{id(reduite)}.tmp")
            reduite.save(temporaire, "JPEG", quality=_QUALITE, optimize=True)
            temporaire.replace(chemin)
        return chemin
    except Exception:
        # Un fichier corrompu ou un format exotique ne doit pas faire
        # échouer l'affichage : on retombe sur l'original.
        logger.info("[Vignettes] média %s non redimensionnable", asset.id, exc_info=True)
        return None


def purger(asset_id: int) -> None:
    """Efface les vignettes d'un média — à appeler si l'original disparaît."""
    for largeur in LARGEURS:
        chemin = _chemin_vignette(asset_id, largeur)
        if chemin.exists():
            chemin.unlink(missing_ok=True)
