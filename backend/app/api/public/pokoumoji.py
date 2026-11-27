"""Les packs d'images Pokoumoji, servis tels quels.

Le serveur ne fait que DISTRIBUER : la confiance est ailleurs. Chaque pack
porte un `manifest.json` signé en Ed25519 (`manifest.sig`), avec l'empreinte
SHA-256 de chaque fichier ; l'application vérifie la signature avec une clé
qu'elle embarque, puis chaque fichier, et refuse ce qui ne correspond pas
(contrat Pokoumoji §6). Un fichier altéré ici serait donc refusé là-bas.

Deux canaux :
- `prod` — le pack de production, signé avec la clé de production (gardée
  hors du dépôt, voir tools/pokoumoji/signer_pack.py). Vide tant que la
  marque n'a validé aucun visuel ;
- `dev`  — les vignettes provisoires du dossier développeurs V1.3, signées
  avec la clé de développement. Une application de production les refuse
  (statut `placeholder`, test T25).

Chemins autorisés : `manifest.json`, `manifest.sig` et
`<64|128|256>/assets/<catégorie>/<id>.webp` — rien d'autre, ni `..`, ni
chemin absolu.
"""
import os
import re
from pathlib import Path

from fastapi import APIRouter, HTTPException
from fastapi.responses import FileResponse

router = APIRouter(tags=["pokoumoji"], include_in_schema=False)

_CHANNELS = {"dev", "prod"}
_FILE = re.compile(r"^(manifest\.json|manifest\.sig|(64|128|256)/assets/[a-z0-9_]+/[a-z0-9_]+\.webp)$")
_TYPES = {".json": "application/json", ".sig": "text/plain", ".webp": "image/webp"}


def _root() -> Path:
    return Path(os.getenv("POKOUMOJI_PACKS_DIR") or Path(__file__).resolve().parents[2] / "data" / "pokoumoji_packs")


@router.get("/pokoumoji/packs/{channel}/{path:path}")
async def pack_file(channel: str, path: str):
    if channel not in _CHANNELS or not _FILE.match(path):
        raise HTTPException(status_code=404, detail="Introuvable")
    base = (_root() / channel).resolve()
    target = (base / path).resolve()
    if base not in target.parents or not target.is_file():
        raise HTTPException(status_code=404, detail="Introuvable")
    # Le manifeste change à chaque publication ; une image, jamais (son nom
    # suit l'identifiant, son contenu est contrôlé par l'empreinte).
    cache = "public, max-age=300" if path.startswith("manifest") else "public, max-age=86400"
    return FileResponse(target, media_type=_TYPES[target.suffix], headers={"Cache-Control": cache})
