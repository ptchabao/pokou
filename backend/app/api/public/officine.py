"""L'espace officine HONAM, en application web installable (BM-08).

Servi par l'API elle-même, sous `/officine/` : même origine que `/api/v1`,
donc ni CORS ni second déploiement. La politique de sécurité du contenu
n'autorise que les fichiers de ce dossier — c'est elle qui protège le jeton
de rafraîchissement gardé par le navigateur.
"""
from pathlib import Path

from fastapi import APIRouter, HTTPException
from fastapi.responses import FileResponse, RedirectResponse

router = APIRouter(tags=["officine"])

_DIR = Path(__file__).resolve().parents[2] / "officine"
_FILES = {
    "": ("index.html", "text/html; charset=utf-8"),
    "officine.js": ("officine.js", "text/javascript; charset=utf-8"),
    "officine.css": ("officine.css", "text/css; charset=utf-8"),
    "manifest.webmanifest": ("manifest.webmanifest", "application/manifest+json"),
    "sw.js": ("sw.js", "text/javascript; charset=utf-8"),
    "icon.svg": ("icon.svg", "image/svg+xml"),
}
_HEADERS = {
    "Content-Security-Policy": (
        "default-src 'self'; script-src 'self'; style-src 'self'; img-src 'self' blob:; "
        "connect-src 'self'; frame-ancestors 'none'; base-uri 'none'; form-action 'self'"
    ),
    "X-Content-Type-Options": "nosniff",
    "Referrer-Policy": "no-referrer",
    "Cache-Control": "no-cache",
}


@router.get("/officine", include_in_schema=False)
def officine_root():
    return RedirectResponse("/officine/")


@router.get("/officine/{name:path}", include_in_schema=False)
def officine_file(name: str):
    entry = _FILES.get(name)
    if entry is None:
        raise HTTPException(status_code=404)
    filename, media_type = entry
    headers = dict(_HEADERS)
    if name == "sw.js":
        headers["Service-Worker-Allowed"] = "/officine/"
    return FileResponse(_DIR / filename, media_type=media_type, headers=headers)
