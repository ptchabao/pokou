"""La page web de suppression de compte (AUTH-06).

Google Play et l'App Store exigent que la suppression puisse être demandée
depuis une adresse web, sans installer l'application : c'est elle qu'on
déclare dans la fiche du store. La page ne détient aucun pouvoir propre —
elle se connecte avec un code à usage unique, comme l'application, puis
appelle la même route de suppression (`DELETE /api/v1/account/account`).

Même traitement que l'espace officine : fichiers statiques servis par
l'API, avec une politique de sécurité de contenu stricte (aucun script ni
style en ligne, aucun domaine tiers).
"""
from pathlib import Path

from fastapi import APIRouter, HTTPException
from fastapi.responses import FileResponse, RedirectResponse

router = APIRouter(tags=["suppression de compte"])

_DIR = Path(__file__).resolve().parents[2] / "suppression"
_FILES = {
    "": ("index.html", "text/html; charset=utf-8"),
    "suppression.css": ("suppression.css", "text/css; charset=utf-8"),
    "suppression.js": ("suppression.js", "text/javascript; charset=utf-8"),
}
_HEADERS = {
    "Content-Security-Policy": (
        "default-src 'self'; script-src 'self'; style-src 'self'; img-src 'self' data:; "
        "connect-src 'self'; frame-ancestors 'none'; base-uri 'none'; form-action 'self'"
    ),
    "X-Content-Type-Options": "nosniff",
    "Referrer-Policy": "no-referrer",
    "Cache-Control": "no-cache",
}


@router.get("/compte/suppression", include_in_schema=False)
def suppression_root():
    return RedirectResponse("/compte/suppression/")


@router.get("/compte/suppression/{name:path}", include_in_schema=False)
def suppression_file(name: str):
    entry = _FILES.get(name)
    if entry is None:
        raise HTTPException(status_code=404)
    filename, media_type = entry
    return FileResponse(_DIR / filename, media_type=media_type, headers=_HEADERS)
