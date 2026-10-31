"""Pokou — appels audio/vidéo/de groupe via LiveKit Cloud.

Aucune session d'appel n'est persistée côté serveur : le nom de salon est un
identifiant opaque (uuid) distribué uniquement aux participants invités via
l'événement WebSocket `call:invite` (voir app/routes/calls.py) — connaître le
nom du salon vaut invitation, cohérent avec le reste de Pokou qui ne fait pas
de suivi d'état côté appels/messages temps réel au-delà de ce qui existe déjà.
"""
import uuid
from datetime import timedelta

from livekit.api import AccessToken, VideoGrants

from app.core.config import get_settings
from app.models import User


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
