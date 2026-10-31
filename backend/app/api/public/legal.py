"""Les documents légaux, lisibles DANS l'application (section 8.1).

Servis par l'API plutôt qu'embarqués dans le binaire : une correction du
texte ne doit pas attendre une revue de store. Le fichier Markdown est la
source ; l'application l'affiche tel quel.
"""
from pathlib import Path

from fastapi import APIRouter, HTTPException

from app.api.v1.auth.auth import TERMS_VERSION

router = APIRouter(prefix="/legal", tags=["legal"])

_DIR = Path(__file__).resolve().parents[2] / "legal"
_DOCS = {"conditions": "conditions.md", "confidentialite": "confidentialite.md"}


@router.get("/{name}")
def legal_document(name: str):
    filename = _DOCS.get(name)
    if filename is None:
        raise HTTPException(status_code=404, detail="Document inconnu")
    body = (_DIR / filename).read_text(encoding="utf-8")
    title = body.splitlines()[0].lstrip("# ").strip()
    return {"name": name, "title": title, "version": TERMS_VERSION, "body": body}
