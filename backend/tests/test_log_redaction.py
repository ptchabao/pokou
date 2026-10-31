"""Le jeton d'accès ne doit jamais atteindre les journaux.

Il voyage dans l'URL du WebSocket (routes/ws.py) faute d'en-tête
Authorization exploitable au handshake côté mobile. Le journal d'accès
d'uvicorn écrit l'URL complète : sans filtre, un JWT valable se retrouvait en
clair dans les logs, donc rejouable par quiconque les lit.
"""
import logging

from app.core.log_redaction import RedactSecretsFilter


def _rendered(message: str, *args) -> str:
    record = logging.LogRecord(
        name="uvicorn.access",
        level=logging.INFO,
        pathname=__file__,
        lineno=1,
        msg=message,
        args=args,
        exc_info=None,
    )
    RedactSecretsFilter().filter(record)
    return record.getMessage()


def test_le_jeton_du_websocket_est_masque():
    jwt = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJ1c2VyX2lkIjo4fQ.sIgNaTuRe"
    rendered = _rendered('WebSocket /api/v1/ws?token=%s [accepted]', jwt)
    assert jwt not in rendered
    assert "token=…" in rendered


def test_les_autres_secrets_usuels_aussi():
    for param in ("access_token", "refresh_token", "api_key", "secret", "password"):
        rendered = _rendered(f"GET /x?{param}=VALEUR_SENSIBLE")
        assert "VALEUR_SENSIBLE" not in rendered, param


def test_une_url_ordinaire_reste_lisible():
    # Le filtre ne doit pas rendre les journaux inutilisables : c'est la
    # VALEUR des paramètres sensibles qu'on masque, pas l'URL entière.
    url = "GET /api/v1/link-preview?url=https%3A%2F%2Fpok.app%2Fc%2F22Nc0"
    assert _rendered(url) == url


def test_un_parametre_suivant_survit():
    rendered = _rendered("POST /x?token=abc&page=2")
    assert "page=2" in rendered
    assert "abc" not in rendered


def test_le_journal_d_acces_d_uvicorn_reste_formatable():
    # Le formateur d'accès d'uvicorn relit les cinq arguments un par un. Les
    # remplacer par un tuple vide le faisait lever à chaque requête portant
    # un jeton — une trace « Logging error » au lieu de la ligne d'accès.
    from uvicorn.logging import AccessFormatter

    record = logging.LogRecord(
        name="uvicorn.access",
        level=logging.INFO,
        pathname=__file__,
        lineno=1,
        msg='%s - "%s %s HTTP/%s" %d',
        args=("10.0.1.22:50162", "GET", "/api/v1/ws?token=eyJ.secret.sig", "1.1", 405),
        exc_info=None,
    )
    RedactSecretsFilter().filter(record)
    line = AccessFormatter('%(client_addr)s - "%(request_line)s" %(status_code)s', use_colors=False).format(record)
    assert line == '10.0.1.22:50162 - "GET /api/v1/ws?token=… HTTP/1.1" 405 Method Not Allowed'
