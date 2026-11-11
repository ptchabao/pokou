"""Outils partagés des tests."""
from fastapi import Response

from app.api.v1.auth.auth import _issue_session
from app.models import User, UserRole


def bearer_for_email(session_factory, email: str) -> dict:
    """En-tête d'authentification d'un compte déjà en base, sans passer par
    l'OTP — pour les comptes d'équipe que les tests créent directement.

    La session est ouverte par la MÊME fonction que la vraie connexion : le
    jeton est révocable et vérifié exactement comme en production."""
    db = session_factory()
    try:
        user = db.query(User).filter(User.email == email).one()
        if user.role is not None and user.role != UserRole.USER:
            # Un compte d'équipe n'entre dans l'administration que par la
            # console (e-mail + mot de passe) : sa session en porte la marque.
            return console_bearer(session_factory, user.id)
        access_token, _, _ = _issue_session(db, Response(), user)
        return {"Authorization": f"Bearer {access_token}"}
    finally:
        db.close()


def console_bearer(session_factory, user_id: int) -> dict:
    """Session de console (celle de POST /admin/auth/login) pour un compte."""
    from app.services.auth.console_session import issue_console_session
    db = session_factory()
    try:
        user = db.get(User, user_id)
        return {"Authorization": f"Bearer {issue_console_session(db, user)}"}
    finally:
        db.close()


class _PlainResponse:
    """Une réponse dont `.json()` remet le « chiffré » des tests dans
    `content` (voir GroupCryptoClient)."""

    def __init__(self, response):
        self._response = response

    def __getattr__(self, name):
        return getattr(self._response, name)

    def json(self):
        def plain(value):
            if isinstance(value, list):
                return [plain(v) for v in value]
            if isinstance(value, dict):
                value = {k: plain(v) for k, v in value.items()}
                if value.get("content") is None and isinstance(value.get("ciphertext"), str):
                    value["content"] = value["ciphertext"]
            return value

        return plain(self._response.json())


class GroupCryptoClient:
    """Un TestClient qui envoie les messages de groupe comme l'application :
    CHIFFRÉS, après avoir remis sa clé d'expéditeur aux autres membres.

    Le serveur refuse désormais tout message de groupe en clair. Les suites
    qui vérifient la MÉCANIQUE des groupes (ordre, pagination, réactions,
    mentions, délais d'édition) écrivent `{"content": "bonjour"}` ; ce client
    le convertit en `{"encryption", "ciphertext": "bonjour", "crypto_epoch"}`
    et, à la lecture, remet le chiffré dans `content`. Le serveur ne déchiffre
    jamais rien : pour lui, le chiffré est une chaîne opaque, et ici cette
    chaîne est le texte du test. Le chiffrement lui-même est vérifié
    ailleurs (test_group_sender_keys.py, test_e2ee*.py).
    """

    _MESSAGES = __import__("re").compile(r"^/api/v1/groups/(\d+)/messages(?:/[^/?]+)?$")

    def __init__(self, client):
        self._client = client

    def __getattr__(self, name):
        return getattr(self._client, name)

    def _sealed(self, group_id: int, body: dict, headers) -> dict:
        content = body.get("content")
        if not isinstance(content, str) or not content.strip() or "ciphertext" in body:
            return body
        group = self._client.get(f"/api/v1/groups/{group_id}", headers=headers)
        if group.status_code != 200:
            return body  # pas membre : au serveur de le dire
        epoch = group.json().get("crypto_epoch", 0)
        me = self._client.get("/api/v1/auth/me", headers=headers).json().get("id")
        others = [m["user_id"] for m in group.json().get("members", []) if m["user_id"] != me]
        if others:
            self._client.post(
                f"/api/v1/groups/{group_id}/sender-key-distributions",
                json={"epoch": epoch, "distributions": [
                    {"recipient_id": uid, "encryption": "v1", "ciphertext": "cle", "envelope": {"sid": "s"}}
                    for uid in others
                ]},
                headers=headers,
            )
        sealed = {k: v for k, v in body.items() if k != "content"}
        sealed.update({"encryption": "sender-key-v1", "ciphertext": content, "crypto_epoch": epoch})
        return sealed

    def _send(self, method: str, url: str, **kwargs):
        match = self._MESSAGES.match(url.split("?")[0])
        if match and isinstance(kwargs.get("json"), dict):
            kwargs["json"] = self._sealed(int(match.group(1)), kwargs["json"], kwargs.get("headers"))
        response = getattr(self._client, method)(url, **kwargs)
        return _PlainResponse(response) if "/groups" in url or "/mentions" in url or "/conversations" in url else response

    def post(self, url, **kwargs):
        return self._send("post", url, **kwargs)

    def patch(self, url, **kwargs):
        return self._send("patch", url, **kwargs)

    def get(self, url, **kwargs):
        response = self._client.get(url, **kwargs)
        return _PlainResponse(response) if "/groups" in url or "/mentions" in url or "/conversations" in url else response
