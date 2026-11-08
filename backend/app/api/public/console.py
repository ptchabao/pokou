"""La console d'administration de l'équipe Pokou, servie sous `/console/`.

C'est l'export statique de `admin/` (Next.js + shadcn/ui), copié dans
`app/console` par `npm run publish` : même origine que `/api/v1`, donc ni
CORS ni second déploiement — comme l'officine. Les droits ne sont PAS
décidés ici : chaque appel de la console passe par `/api/v1/admin/*`, qui
vérifie la permission du rôle à chaque requête (app/core/permissions.py).
"""
import mimetypes
from pathlib import Path

from fastapi import APIRouter, HTTPException
from fastapi.responses import FileResponse, RedirectResponse

router = APIRouter(tags=["console"])

_DIR = (Path(__file__).resolve().parents[2] / "console").resolve()
_HEADERS = {
    # Next.js injecte de petits scripts en ligne (données de rendu) : d'où
    # 'unsafe-inline' pour les scripts. Tout le reste ne vient que d'ici,
    # et la console ne parle qu'à sa propre origine.
    "Content-Security-Policy": (
        "default-src 'self'; script-src 'self' 'unsafe-inline'; style-src 'self' 'unsafe-inline'; "
        "img-src 'self' data: blob: https:; font-src 'self' data:; connect-src 'self'; "
        "frame-ancestors 'none'; base-uri 'none'; form-action 'self'"
    ),
    "X-Content-Type-Options": "nosniff",
    "Referrer-Policy": "no-referrer",
    "X-Robots-Tag": "noindex, nofollow",
}


@router.get("/console", include_in_schema=False)
def console_root():
    return RedirectResponse("/console/")


@router.get("/console/{name:path}", include_in_schema=False)
def console_file(name: str):
    target = (_DIR / name).resolve()
    # Jamais hors du dossier de la console (« ../ »).
    if _DIR not in target.parents and target != _DIR:
        raise HTTPException(status_code=404)
    if target.is_dir():
        target = target / "index.html"
    if not target.is_file():
        raise HTTPException(status_code=404)
    headers = dict(_HEADERS)
    # Les fichiers de _next/static portent une empreinte : cache long.
    headers["Cache-Control"] = (
        "public, max-age=31536000, immutable" if name.startswith("_next/static/") else "no-cache"
    )
    media_type = mimetypes.guess_type(target.name)[0] or "application/octet-stream"
    if media_type.startswith("text/") or media_type in ("application/javascript", "text/javascript"):
        media_type += "; charset=utf-8"
    return FileResponse(target, media_type=media_type, headers=headers)
