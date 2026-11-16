"""Chiffrement au repos des messages joints à un signalement.

La personne qui signale peut joindre, avec son accord explicite, les 5
derniers messages de la discussion — que SON appareil a déchiffrés. Ils ne
doivent pas dormir en clair dans la base : ils sont chiffrés ici avec une
clé dédiée (`REPORTS_ENCRYPTION_KEY`, une clé Fernet), distincte de toutes
les autres, et ne sont déchiffrés qu'à la lecture d'un signalement dans
l'espace d'administration.

Sans clé configurée, on REFUSE de stocker ces messages (le signalement
passe sans eux) plutôt que de les garder en clair : c'est la seule
dégradation acceptable.

Générer une clé : ``python -c "from cryptography.fernet import Fernet;
print(Fernet.generate_key().decode())"``.
"""
import json
import logging
import os
from typing import Any, List, Optional

from cryptography.fernet import Fernet, InvalidToken

logger = logging.getLogger(__name__)

ENV_VAR = "REPORTS_ENCRYPTION_KEY"


def _fernet() -> Optional[Fernet]:
    """Lue à chaque appel (et non mise en cache) : une clé posée ou retirée
    de l'environnement s'applique sans redémarrer — et les tests peuvent la
    faire varier."""
    # L'environnement d'abord (Kubero, Kubernetes), puis le fichier .env lu
    # par les réglages en développement.
    key = os.environ.get(ENV_VAR, "").strip()
    if not key:
        from app.core.config import get_settings

        key = get_settings().reports_encryption_key.strip()
    if not key:
        return None
    try:
        return Fernet(key.encode())
    except (ValueError, TypeError):
        logger.error("%s n'est pas une clé Fernet valide : messages joints refusés", ENV_VAR)
        return None


def is_configured() -> bool:
    return _fernet() is not None


def encrypt_messages(messages: List[Any]) -> Optional[str]:
    """Le jeton chiffré, ou None si aucune clé n'est configurée (l'appelant
    ne stocke alors RIEN)."""
    fernet = _fernet()
    if fernet is None or not messages:
        return None
    payload = json.dumps(messages, ensure_ascii=False).encode("utf-8")
    return fernet.encrypt(payload).decode("ascii")


def decrypt_messages(token: Optional[str]) -> Optional[List[Any]]:
    """Les messages en clair, ou None si absents, si la clé manque ou si le
    jeton ne s'ouvre pas avec elle (clé changée) — jamais d'exception vers
    l'écran d'administration."""
    if not token:
        return None
    fernet = _fernet()
    if fernet is None:
        return None
    try:
        return json.loads(fernet.decrypt(token.encode("ascii")).decode("utf-8"))
    except (InvalidToken, ValueError):
        logger.warning("Messages joints d'un signalement illisibles avec la clé actuelle")
        return None
