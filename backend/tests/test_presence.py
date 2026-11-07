"""Pokou — présence (« en ligne », « vu à ») et indicateur de saisie.

Ce qui est vérifié ici tient surtout aux deux règles qui ne se lisent pas
dans les signatures : la RÉCIPROCITÉ (masquer son « vu à » prive aussi de
celui des autres, dans les deux sens) et le fait qu'« en ligne » se déduise
du registre de sockets, donc redevienne faux dès la fermeture du WebSocket
sans qu'aucune tâche de nettoyage n'ait à passer.
"""
import re
from datetime import datetime
from unittest.mock import patch

import pytest
from fastapi.testclient import TestClient
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker

from app.core.database import Base, get_db
from app.main import app
from app.models import User
from app.services.auth import otp_service

TEST_DATABASE_URL = "sqlite:///./test_pokou_presence.db"

engine = create_engine(TEST_DATABASE_URL, connect_args={"check_same_thread": False})
TestingSessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)
Base.metadata.create_all(bind=engine)


def override_get_db():
    try:
        db = TestingSessionLocal()
        yield db
    finally:
        db.close()


@pytest.fixture(scope="function")
def client():
    """L'override est posé DANS la fixture et l'ancien restauré à la sortie :
    posé au niveau du module, c'est l'ordre d'import des fichiers de tests qui
    déciderait quelle base sert à quelle suite."""
    Base.metadata.create_all(bind=engine)
    previous = app.dependency_overrides.get(get_db)
    app.dependency_overrides[get_db] = override_get_db
    yield TestClient(app)
    if previous is not None:
        app.dependency_overrides[get_db] = previous
    Base.metadata.drop_all(bind=engine)


def _signup(client, phone):
    with patch.object(otp_service.sms_service, "send_sms", return_value=True) as mock_send:
        client.post("/api/v1/auth/phone/request-otp", json={"phone": phone})
    code = re.search(r"\b(\d{6})\b", mock_send.call_args.args[2]).group(1)
    body = client.post("/api/v1/auth/phone/verify-otp", json={"phone": phone, "code": code}).json()
    return {"Authorization": f"Bearer {body['access_token']}"}, body["user"]["id"], body["access_token"]


def _add_contact(client, headers, phone, name):
    response = client.post(
        "/api/v1/contacts", json={"phone": phone, "display_name": name}, headers=headers
    )
    assert response.status_code == 200, response.text


def _befriend(client, headers_a, phone_a, headers_b, phone_b):
    """Carnets croisés : la relation de contact n'est pas symétrique en base,
    et une présence consultable dans un sens ne l'est pas dans l'autre."""
    _add_contact(client, headers_a, phone_b, "B")
    _add_contact(client, headers_b, phone_a, "A")


def _ws(client, token):
    return client.websocket_connect(f"/api/v1/ws?token={token}")


def _last_seen(user_id):
    """Lu directement en base : les routes masquent la valeur dès que la
    réciprocité s'applique, ce qui rendrait indistinguables « masqué » et
    « jamais écrit »."""
    db = TestingSessionLocal()
    try:
        return db.query(User).filter(User.id == user_id).first().last_seen_at
    finally:
        db.close()


def _force_last_seen(user_id, moment):
    db = TestingSessionLocal()
    try:
        db.query(User).filter(User.id == user_id).update(
            {"last_seen_at": moment}, synchronize_session=False
        )
        db.commit()
    finally:
        db.close()


def _set_visible(client, headers, visible):
    response = client.put("/api/v1/presence/settings", json={"presence_visible": visible}, headers=headers)
    assert response.status_code == 200, response.text
    return response.json()


# ─── Autorisation ─────────────────────────────────────────────────────────────

def test_presence_of_a_stranger_is_refused(client):
    """Sans cette règle, la présence de n'importe qui serait consultable en
    énumérant les user_id — un annuaire de qui est en ligne."""
    headers_a, _, _ = _signup(client, "+228896000101")
    _, user_id_b, _ = _signup(client, "+228896000102")

    response = client.get(f"/api/v1/presence/{user_id_b}", headers=headers_a)

    assert response.status_code == 403
    # Le libellé a changé en même temps que la RÈGLE : presence.py partageait
    # une règle « uniquement mon carnet » qui avait divergé de celle de
    # l'envoi, et l'appelle désormais (voir routes/messages.py
    # ::_require_reachable). Le message est donc le même partout, et c'est
    # volontaire : il ne dit pas SI l'on est bloqué ou simplement inconnu,
    # ce qui est exactement ce qu'un blocage doit taire.
    assert "ne pouvez pas" in response.json()["detail"]


def test_own_presence_is_always_readable(client):
    """Se masquer aux autres n'a pas de raison de se masquer à soi-même."""
    headers_a, user_id_a, _ = _signup(client, "+228896000103")
    _set_visible(client, headers_a, False)

    body = client.get(f"/api/v1/presence/{user_id_a}", headers=headers_a).json()

    assert body["user_id"] == user_id_a
    assert body["is_online"] is False


# ─── « Vu à » ─────────────────────────────────────────────────────────────────

def test_last_seen_is_written_at_both_connection_transitions(client):
    """Les deux transitions comptent : sans l'écriture à la FERMETURE, le
    « vu à » resterait figé à l'heure d'arrivée, et afficherait « vu à 8 h »
    quelqu'un parti à 18 h."""
    _, user_id_b, token_b = _signup(client, "+228896000104")
    assert _last_seen(user_id_b) is None

    with _ws(client, token_b):
        assert _last_seen(user_id_b) is not None
        # Repère volontairement daté : la seule façon de prouver qu'une
        # SECONDE écriture a lieu à la fermeture, les deux instants réels
        # n'étant séparés que de quelques millisecondes.
        _force_last_seen(user_id_b, datetime(2020, 1, 1))

    assert _last_seen(user_id_b) > datetime(2020, 1, 1)


def test_is_online_follows_the_socket_and_not_a_stored_flag(client):
    headers_a, _, _ = _signup(client, "+228896000105")
    headers_b, user_id_b, token_b = _signup(client, "+228896000106")
    _befriend(client, headers_a, "+228896000105", headers_b, "+228896000106")

    with _ws(client, token_b):
        live = client.get(f"/api/v1/presence/{user_id_b}", headers=headers_a).json()
        assert live["is_online"] is True

    gone = client.get(f"/api/v1/presence/{user_id_b}", headers=headers_a).json()
    assert gone["is_online"] is False
    assert gone["last_seen_at"] is not None


# ─── Réciprocité ──────────────────────────────────────────────────────────────

def test_hiding_my_presence_hides_it_from_my_contacts(client):
    headers_a, _, _ = _signup(client, "+228896000107")
    headers_b, user_id_b, token_b = _signup(client, "+228896000108")
    _befriend(client, headers_a, "+228896000107", headers_b, "+228896000108")
    with _ws(client, token_b):
        pass

    _set_visible(client, headers_b, False)

    body = client.get(f"/api/v1/presence/{user_id_b}", headers=headers_a).json()
    # `null` et non 403 : un refus apprendrait justement que la personne se
    # cache, ce qu'elle ne veut pas dire.
    assert body["is_online"] is None
    assert body["last_seen_at"] is None


def test_hiding_my_presence_also_blinds_me_to_others(client):
    """L'autre moitié de la réciprocité, celle qu'on oublie : sans elle le
    réglage serait un avantage gratuit — tout voir sans être vu."""
    headers_a, user_id_a, token_a = _signup(client, "+228896000109")
    headers_b, _, _ = _signup(client, "+228896000110")
    _befriend(client, headers_a, "+228896000109", headers_b, "+228896000110")
    with _ws(client, token_a):
        pass

    visible_before = client.get(f"/api/v1/presence/{user_id_a}", headers=headers_b).json()
    assert visible_before["last_seen_at"] is not None

    _set_visible(client, headers_b, False)

    body = client.get(f"/api/v1/presence/{user_id_a}", headers=headers_b).json()
    assert body["is_online"] is None
    assert body["last_seen_at"] is None


def test_presence_settings_roundtrip(client):
    headers_a, _, _ = _signup(client, "+228896000111")

    assert client.get("/api/v1/presence/settings", headers=headers_a).json() == {"presence_visible": True}
    assert _set_visible(client, headers_a, False) == {"presence_visible": False}
    assert client.get("/api/v1/presence/settings", headers=headers_a).json() == {"presence_visible": False}


# ─── Version groupée ──────────────────────────────────────────────────────────

def test_batch_presence_returns_only_authorized_contacts(client):
    """Un id hors carnet est absent de la réponse, pas une erreur globale :
    la liste de conversations ne doit pas perdre toute sa présence parce
    qu'une ligne n'est plus un contact."""
    headers_a, _, _ = _signup(client, "+228896000112")
    headers_b, user_id_b, token_b = _signup(client, "+228896000113")
    _, user_id_c, _ = _signup(client, "+228896000114")
    _, user_id_stranger, _ = _signup(client, "+228896000115")
    _add_contact(client, headers_a, "+228896000113", "B")
    _add_contact(client, headers_a, "+228896000114", "C")

    with _ws(client, token_b):
        response = client.get(
            f"/api/v1/presence?user_ids={user_id_b},{user_id_c},{user_id_stranger}",
            headers=headers_a,
        )

        assert response.status_code == 200, response.text
        items = response.json()["items"]
        assert [item["user_id"] for item in items] == [user_id_b, user_id_c]
        assert items[0]["is_online"] is True
        assert items[1]["is_online"] is False


def test_batch_presence_applies_the_same_reciprocity(client):
    headers_a, _, _ = _signup(client, "+228896000116")
    headers_b, user_id_b, _ = _signup(client, "+228896000117")
    _befriend(client, headers_a, "+228896000116", headers_b, "+228896000117")
    _set_visible(client, headers_b, False)

    items = client.get(f"/api/v1/presence?user_ids={user_id_b}", headers=headers_a).json()["items"]

    assert items == [{"user_id": user_id_b, "is_online": None, "last_seen_at": None}]


def test_batch_presence_rejects_a_malformed_list(client):
    headers_a, _, _ = _signup(client, "+228896000118")

    assert client.get("/api/v1/presence?user_ids=1,abc", headers=headers_a).status_code == 400


# ─── Indicateur de saisie ─────────────────────────────────────────────────────

def test_typing_reaches_the_other_party_in_one_to_one(client):
    headers_a, user_id_a, _ = _signup(client, "+228896000119")
    headers_b, user_id_b, token_b = _signup(client, "+228896000120")
    _befriend(client, headers_a, "+228896000119", headers_b, "+228896000120")
    client.put("/api/v1/users/me/profile", json={"full_name": "Awa"}, headers=headers_a)

    with _ws(client, token_b) as ws:
        sent = client.post(
            "/api/v1/presence/typing",
            json={"kind": "contact", "id": user_id_b, "typing": True},
            headers=headers_a,
        )
        assert sent.status_code == 200, sent.text
        assert sent.json()["notified"] == 1

        event = ws.receive_json()

    assert event == {
        "type": "typing",
        "kind": "contact",
        "id": user_id_b,
        "user_id": user_id_a,
        "typing": True,
        # Le nom voyage avec l'événement : résoudre « qui écrit » par un
        # second appel prendrait plus longtemps que ne dure l'indicateur.
        "user_name": "Awa",
    }


def test_typing_false_is_broadcast_too(client):
    """L'arrêt de frappe doit voyager comme le début, sinon l'indicateur
    resterait affiché jusqu'à l'expiration du minuteur côté client."""
    headers_a, _, _ = _signup(client, "+228896000121")
    headers_b, user_id_b, token_b = _signup(client, "+228896000122")
    _befriend(client, headers_a, "+228896000121", headers_b, "+228896000122")

    with _ws(client, token_b) as ws:
        client.post(
            "/api/v1/presence/typing",
            json={"kind": "contact", "id": user_id_b, "typing": False},
            headers=headers_a,
        )
        event = ws.receive_json()

    assert event["typing"] is False


def test_typing_to_a_stranger_is_refused(client):
    headers_a, _, _ = _signup(client, "+228896000123")
    _, user_id_b, _ = _signup(client, "+228896000124")

    response = client.post(
        "/api/v1/presence/typing",
        json={"kind": "contact", "id": user_id_b, "typing": True},
        headers=headers_a,
    )

    assert response.status_code == 403


def test_group_typing_reaches_other_members_but_not_its_author(client):
    headers_a, user_id_a, token_a = _signup(client, "+228896000125")
    headers_b, user_id_b, token_b = _signup(client, "+228896000126")
    headers_c, user_id_c, token_c = _signup(client, "+228896000127")
    _add_contact(client, headers_a, "+228896000126", "B")
    _add_contact(client, headers_a, "+228896000127", "C")
    group = client.post(
        "/api/v1/groups",
        json={"name": "Chantier", "member_user_ids": [user_id_b, user_id_c]},
        headers=headers_a,
    ).json()
    # Un groupe naît avec son seul créateur : les autres sont invités. Ce
    # test porte sur la diffusion de l'indicateur de saisie ENTRE MEMBRES,
    # donc ils acceptent.
    for entetes in (headers_b, headers_c):
        for invitation in client.get(
            "/api/v1/groups/invitations", headers=entetes
        ).json()["items"]:
            client.post(
                f"/api/v1/groups/invitations/{invitation['id']}/accept",
                headers=entetes,
            )

    with _ws(client, token_a) as ws_a, _ws(client, token_b) as ws_b, _ws(client, token_c) as ws_c:
        sent = client.post(
            "/api/v1/presence/typing",
            json={"kind": "group", "id": group["id"], "typing": True},
            headers=headers_a,
        )
        assert sent.status_code == 200, sent.text
        assert sent.json()["notified"] == 2

        for ws in (ws_b, ws_c):
            event = ws.receive_json()
            assert event["type"] == "typing"
            assert event["kind"] == "group"
            assert event["id"] == group["id"]
            assert event["user_id"] == user_id_a
            assert event["user_name"]

        # L'auteur ne doit rien avoir reçu. Une lecture bloquerait, donc on
        # provoque un événement POSTÉRIEUR : s'il arrive en premier chez A,
        # c'est que l'événement `typing` ne lui a jamais été adressé.
        # Message de groupe tel que l'app l'envoie : chiffré, après avoir
        # remis sa clé d'expéditeur aux autres membres.
        epoch = client.get(f"/api/v1/groups/{group['id']}", headers=headers_c).json()["crypto_epoch"]
        client.post(
            f"/api/v1/groups/{group['id']}/sender-key-distributions",
            json={"epoch": epoch, "distributions": [
                {"recipient_id": uid, "encryption": "v1", "ciphertext": "cle", "envelope": {"sid": "s"}}
                for uid in (user_id_a, user_id_b)
            ]},
            headers=headers_c,
        )
        posted = client.post(
            f"/api/v1/groups/{group['id']}/messages",
            json={"encryption": "sender-key-v1", "ciphertext": "on y va", "crypto_epoch": epoch},
            headers=headers_c,
        )
        assert posted.status_code == 200, posted.text
        assert ws_a.receive_json()["type"] == "group:message:new"


def test_group_typing_is_refused_to_a_non_member(client):
    headers_a, _, _ = _signup(client, "+228896000128")
    headers_d, _, _ = _signup(client, "+228896000129")
    group = client.post(
        "/api/v1/groups", json={"name": "Chantier", "member_user_ids": []}, headers=headers_a
    ).json()

    response = client.post(
        "/api/v1/presence/typing",
        json={"kind": "group", "id": group["id"], "typing": True},
        headers=headers_d,
    )

    assert response.status_code == 403
    assert "membre" in response.json()["detail"]


def test_typing_persists_nothing(client):
    """Un état de trois secondes n'a pas à laisser de trace : le « vu à »
    ne bouge pas d'un signal de frappe, seules les transitions de connexion
    l'écrivent."""
    headers_a, user_id_a, _ = _signup(client, "+228896000130")
    headers_b, user_id_b, _ = _signup(client, "+228896000131")
    _befriend(client, headers_a, "+228896000130", headers_b, "+228896000131")
    _force_last_seen(user_id_a, datetime(2020, 1, 1))

    client.post(
        "/api/v1/presence/typing",
        json={"kind": "contact", "id": user_id_b, "typing": True},
        headers=headers_a,
    )

    assert _last_seen(user_id_a) == datetime(2020, 1, 1)
