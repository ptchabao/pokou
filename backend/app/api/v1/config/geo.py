"""Une position GPS traduite en nom de lieu lisible (« Bè, Lomé »).

Afficher « 6.1319, 1.2228 » dans une annonce ou une adresse de livraison
n'est pas professionnel, et ne dit rien à personne. Le téléphone garde les
coordonnées pour calculer les distances ; l'écran montre le quartier et la
ville.

Source : le géocodage inverse d'OpenStreetMap (Nominatim), interrogé par le
serveur et non par chaque téléphone — un seul point de contact, une
identification correcte du client, et un cache qui respecte la règle
d'usage (une requête par seconde au plus). Arrondi à ~100 m : deux
annonces du même quartier partagent la même réponse.

Jamais bloquant : sans réponse en 5 s, `label` vaut null et l'application
garde ce que la personne a saisi.
"""
import asyncio
import logging
import time
from collections import OrderedDict
from typing import Optional

import httpx
from fastapi import APIRouter, Depends, Header, Query

from app.core.security import get_current_user

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/geo", tags=["Pokou configuration"])

NOMINATIM_URL = "https://nominatim.openstreetmap.org/reverse"
_USER_AGENT = "Pokou/1.0 (+https://pokou.app)"
_CACHE_MAX = 5000
_cache: "OrderedDict[tuple, Optional[dict]]" = OrderedDict()
_lock = asyncio.Lock()
_last_call = 0.0


def _label(address: dict) -> Optional[str]:
    """Le quartier, puis la ville — ce qu'on dirait à quelqu'un."""
    district = next(
        (address.get(k) for k in ("suburb", "neighbourhood", "quarter", "city_district", "village", "hamlet")
         if address.get(k)),
        None,
    )
    city = next(
        (address.get(k) for k in ("city", "town", "municipality", "county", "state") if address.get(k)),
        None,
    )
    parts = [p for p in (district, city) if p]
    if district and city and district == city:
        parts = [city]
    return ", ".join(dict.fromkeys(parts)) or None


async def reverse(lat: float, lon: float, lang: str = "fr") -> Optional[dict]:
    global _last_call
    key = (round(lat, 3), round(lon, 3), lang)
    if key in _cache:
        _cache.move_to_end(key)
        return _cache[key]
    async with _lock:
        # Une requête par seconde au plus vers Nominatim (règle d'usage).
        wait = 1.0 - (time.monotonic() - _last_call)
        if wait > 0:
            await asyncio.sleep(wait)
        _last_call = time.monotonic()
        try:
            async with httpx.AsyncClient(timeout=5) as client:
                response = await client.get(
                    NOMINATIM_URL,
                    params={"lat": lat, "lon": lon, "format": "jsonv2", "zoom": 16, "addressdetails": 1},
                    headers={"User-Agent": _USER_AGENT, "Accept-Language": lang},
                )
            response.raise_for_status()
            address = response.json().get("address") or {}
        except Exception as exc:  # noqa: BLE001 — jamais bloquant
            logger.warning("[Géo] Nominatim indisponible : %s", exc)
            return None  # pas mis en cache : on réessaiera
    result = {
        "label": _label(address),
        "district": next((address.get(k) for k in ("suburb", "neighbourhood", "quarter") if address.get(k)), None),
        "city": next((address.get(k) for k in ("city", "town", "municipality") if address.get(k)), None),
        "country_code": (address.get("country_code") or "").upper() or None,
    }
    _cache[key] = result
    if len(_cache) > _CACHE_MAX:
        _cache.popitem(last=False)
    return result


@router.get("/reverse")
async def reverse_geocode(
    lat: float = Query(..., ge=-90, le=90),
    lon: float = Query(..., ge=-180, le=180),
    accept_language: Optional[str] = Header(None),
    current_user: dict = Depends(get_current_user),
):
    lang = (accept_language or "fr").split(",")[0].split("-")[0].strip() or "fr"
    result = await reverse(lat, lon, lang)
    return result or {"label": None, "district": None, "city": None, "country_code": None}
