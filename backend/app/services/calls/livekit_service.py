"""Pokou — appels audio/vidéo/de groupe via LiveKit Cloud.

Aucune session d'appel n'est persistée côté serveur : le nom de salon est un
identifiant opaque (uuid) distribué uniquement aux participants invités via
l'événement WebSocket `call:invite` (voir app/routes/calls.py) — connaître le
nom du salon vaut invitation, cohérent avec le reste de Pokou qui ne fait pas
de suivi d'état côté appels/messages temps réel au-delà de ce qui existe déjà.
"""
import logging
import uuid
from datetime import timedelta
from typing import Optional

import aiohttp
from livekit.api import AccessToken, ListParticipantsRequest, LiveKitAPI, VideoGrants

from app.core.config import get_settings
from app.models import User


logger = logging.getLogger(__name__)


class LiveKitNotConfiguredError(Exception):
    """Levée si LIVEKIT_ENABLED est faux ou que les clés API sont vides —
    voir livekit_enabled/livekit_api_key/livekit_api_secret dans config.py."""


def new_room_name() -> str:
    return f"pokou-call-{uuid.uuid4().hex}"


def generate_token(room_name: str, user: User) -> str:
    settings = get_settings()
    if not settings.livekit_enabled or not settings.livekit_api_key or not settings.livekit_api_secret:
        raise LiveKitNotConfiguredError(
            "LiveKit n'est pas configuré — LIVEKIT_ENABLED, LIVEKIT_API_KEY et "
            "LIVEKIT_API_SECRET doivent être renseignés (compte LiveKit Cloud requis)."
        )

    identity = str(user.id)
    # Jamais le numéro de téléphone : ce nom est montré aux autres
    # participants, y compris à ceux qui n'ont pas la personne dans leur
    # carnet (voir CallScreen.nameForParticipant).
    display_name = user.full_name or "Utilisateur Pokou"

    token = (
        AccessToken(settings.livekit_api_key, settings.livekit_api_secret)
        .with_identity(identity)
        .with_name(display_name)
        .with_ttl(timedelta(minutes=settings.livekit_token_ttl_minutes))
        .with_grants(VideoGrants(room_join=True, room=room_name, can_publish=True, can_subscribe=True))
    )
    return token.to_jwt()


async def participant_count(room_name: str) -> Optional[int]:
    """Combien de personnes sont RÉELLEMENT connectées à ce salon.

    `None` quand on ne peut pas le savoir (LiveKit non configuré, injoignable,
    réponse inattendue) : l'appelant ne doit alors rien conclure. `0` quand
    le salon est vide ou n'existe plus.

    C'est la seule source de vérité sur la présence : l'état que le serveur
    tient d'un appel n'avance qu'avec les signaux des clients, et un client
    qui échoue à rejoindre, plante ou perd le réseau n'en envoie aucun.
    """
    settings = get_settings()
    if not (
        settings.livekit_enabled
        and settings.livekit_api_key
        and settings.livekit_api_secret
        and settings.livekit_url
    ):
        return None
    try:
        api = LiveKitAPI(
            settings.livekit_url,
            settings.livekit_api_key,
            settings.livekit_api_secret,
            timeout=aiohttp.ClientTimeout(total=3),
        )
        try:
            response = await api.room.list_participants(ListParticipantsRequest(room=room_name))
        finally:
            await api.aclose()
        return len(response.participants)
    except Exception as exc:  # noqa: BLE001 — jamais bloquant
        if getattr(exc, "code", None) == "not_found":
            return 0
        logger.warning("[Appels] présence LiveKit indisponible pour %s : %s", room_name, exc)
        return None
