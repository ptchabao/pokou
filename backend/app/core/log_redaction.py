"""Masquage des secrets dans les journaux.

Le journal d'accès d'uvicorn écrit l'URL complète de chaque requête. Pour le
WebSocket, cette URL PORTE le jeton d'accès :

    "WebSocket /api/v1/ws?token=eyJhbGciOiJIUzI1NiIs..." [accepted]

Un JWT d'accès valable se retrouvait donc en clair dans les fichiers de log,
et par ricochet dans tout ce qui les relaie — supervision, reverse proxy,
traces, exports de débogage. Quiconque lit ces journaux peut rejouer la
session de l'utilisateur jusqu'à l'expiration du jeton.

Ce filtre ne corrige pas la cause — le jeton reste dans l'URL, parce que le
handshake WebSocket porte mal un en-tête Authorization côté mobile (voir
routes/ws.py). Il coupe la fuite vers les journaux, qui est le chemin par
lequel le secret sort réellement de la machine.
"""
import logging
import re

# `token`, `access_token`, `refresh_token`, `api_key`, `password`… suivis de
# leur valeur jusqu'au prochain séparateur de query.
_SECRET_PARAM = re.compile(
    r"(?i)\b((?:access_|refresh_)?token|ticket|api[_-]?key|secret|password)=[^&\s\"']+"
)


class RedactSecretsFilter(logging.Filter):
    """Remplace la valeur des paramètres sensibles par « … » dans le message.

    Posé sur le *record* et non sur le formateur : le journal d'accès
    d'uvicorn compose son message par arguments positionnels, et c'est le
    message rendu qu'il faut nettoyer.

    Le masquage se fait DANS chaque argument, sans les fusionner au message.
    La première version rendait le message, puis vidait `record.args` — or
    le formateur d'accès d'uvicorn relit ces arguments un par un (adresse,
    méthode, chemin, version, statut) pour colorer la ligne. Avec un tuple
    vide, il levait « not enough values to unpack », et chaque requête
    portant un jeton imprimait une trace d'erreur de journalisation à la
    place de sa ligne d'accès (constaté en production le 05/10/2026).
    """

    def filter(self, record: logging.LogRecord) -> bool:
        try:
            if isinstance(record.args, tuple):
                record.args = tuple(_redact(a) if isinstance(a, str) else a for a in record.args)
            elif isinstance(record.args, dict):
                record.args = {
                    k: _redact(v) if isinstance(v, str) else v for k, v in record.args.items()
                }
            message = record.getMessage()
        except Exception:
            # Un enregistrement mal formé ne doit pas faire disparaître la
            # ligne : on le laisse passer tel quel plutôt que de le perdre.
            return True
        # Le secret est encore là quand il est coupé entre le gabarit et
        # l'argument (« token=%s ») : seul le message rendu peut alors être
        # nettoyé. Jamais le cas du journal d'accès, dont l'argument porte le
        # chemin complet — ses arguments restent donc intacts.
        redacted = _redact(message)
        if redacted != message:
            record.msg = redacted
            record.args = ()
        return True


def _redact(text: str) -> str:
    return _SECRET_PARAM.sub(r"\1=…", text)


def install_secret_redaction() -> None:
    """Applique le filtre aux journaux qui portent des URL."""
    for name in ("uvicorn.access", "uvicorn.error", "httpx", ""):
        logging.getLogger(name).addFilter(RedactSecretsFilter())
