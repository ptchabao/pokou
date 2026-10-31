"""Les clés d'API des bots.

Format : `vb_test_…` ou `vb_live_…` suivi de 43 caractères d'aléa. Le
préfixe dit le MODE au premier coup d'œil — une clé de production collée
dans un dépôt public doit se reconnaître sans la tester.
"""
import hashlib
import hmac
import secrets
from datetime import datetime
from typing import Optional

from sqlalchemy.orm import Session

from app.models.business import BotApiKey

PREFIXES = {"TEST": "vb_test_", "LIVE": "vb_live_"}


def empreinte(cle_brute: str) -> str:
    return hashlib.sha256(cle_brute.encode()).hexdigest()


def generer(mode: str) -> tuple[str, str, str]:
    """(clé brute, préfixe affichable, empreinte). La clé brute n'est
    montrée qu'une fois : seule l'empreinte est gardée."""
    if mode not in PREFIXES:
        raise ValueError("Mode inconnu")
    brute = PREFIXES[mode] + secrets.token_urlsafe(32)
    return brute, brute[:16], empreinte(brute)


def retrouver(db: Session, cle_brute: str) -> Optional[BotApiKey]:
    if not cle_brute or not cle_brute.startswith(tuple(PREFIXES.values())):
        return None
    cible = empreinte(cle_brute)
    cle = db.query(BotApiKey).filter(BotApiKey.key_hash == cible).first()
    if cle is None or cle.revoked_at is not None:
        return None
    # Comparaison à temps constant, par principe : l'index a déjà trouvé la
    # ligne, mais une égalité de chaînes ordinaire n'a rien à faire ici.
    if not hmac.compare_digest(cle.key_hash, cible):
        return None
    cle.last_used_at = datetime.utcnow()
    return cle
