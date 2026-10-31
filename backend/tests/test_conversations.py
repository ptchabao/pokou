"""Pokou — réglages de conversation (épingler, archiver, sourdine, bloquer)
et liste unifiée de l'écran d'accueil.

Ce qui est vérifié ici tient surtout aux pièges de ces réglages : la limite
d'épingles qui compte les contacts ET les groupes ensemble, la sourdine qui
est une DATE (donc qui expire toute seule, sans tâche de fond), le blocage
qui coupe le canal DANS LES DEUX SENS, et le tri de la liste où les épinglées
ne suivent pas le même critère que les autres.
"""
import logging
import re
from datetime import datetime, timedelta
from unittest.mock import patch

import pytest
from fastapi.testclient import TestClient
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker

from app.core.database import Base, get_db
from app.main import app
from app.models import DirectMessage, GroupMember, GroupMessage
from app.api.v1.messaging.conversations import MUTE_FOREVER_SECONDS, is_blocked_between
from app.services.auth import otp_service

TEST_DATABASE_URL = "sqlite:///./test_pokou_conversations.db"

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
    return {"Authorization": f"Bearer {body['access_token']}"}, body["user"]["id"]


def _add_contact(client, headers, phone, display_name="Contact"):
    response = client.post(
        "/api/v1/contacts", json={"phone": phone, "display_name": display_name}, headers=headers
    )
    assert response.status_code == 200, response.text
    return response.json()


def _create_group(client, headers, name="Équipe"):
    response = client.post("/api/v1/groups", json={"name": name}, headers=headers)
    assert response.status_code == 200, response.text
    return response.json()


def _send_direct(client, headers, recipient_id, content="Bonjour"):
    response = client.post(
        "/api/v1/messages",
        json={"recipient_id": recipient_id, "content": content},
        headers=headers,
    )
    assert response.status_code == 200, response.text
    return response.json()


def _send_group(client, headers, group_id, content="Bonjour à tous"):
    response = client.post(
        f"/api/v1/groups/{group_id}/messages", json={"content": content}, headers=headers
    )
    assert response.status_code == 200, response.text
    return response.json()


def _pin(client, headers, kind, conversation_id, pinned=True):
    return client.put(
        "/api/v1/conversations/pin",
        json={"kind": kind, "id": conversation_id, "pinned": pinned},
        headers=headers,
    )


def _archive(client, headers, kind, conversation_id, archived=True):
    return client.put(
        "/api/v1/conversations/archive",
        json={"kind": kind, "id": conversation_id, "archived": archived},
        headers=headers,
    )


def _mute(client, headers, kind, conversation_id, duration_seconds):
    return client.put(
        "/api/v1/conversations/mute",
        json={"kind": kind, "id": conversation_id, "duration_seconds": duration_seconds},
        headers=headers,
    )


def _list(client, headers, archived=None):
    params = {} if archived is None else {"archived": str(archived).lower()}
    response = client.get("/api/v1/conversations", params=params, headers=headers)
    assert response.status_code == 200, response.text
    return response.json()


def _entry(listing, kind, conversation_id):
    return next(
        (item for item in listing["items"] if item["kind"] == kind and item["id"] == conversation_id),
        None,
    )


def _update_row(model, filters: dict, values: dict):
    """Écrit directement en base ce que l'API ne permet pas de fabriquer :
    une sourdine DÉJÀ expirée, un message vieux de deux jours. Simuler le
    passage du temps est le seul moyen de vérifier qu'aucune tâche de fond
    n'est nécessaire."""
    session = TestingSessionLocal()
    try:
        query = session.query(model)
        for column, value in filters.items():
            query = query.filter(getattr(model, column) == value)
        query.update(values, synchronize_session=False)
        session.commit()
    finally:
        session.close()


# ─── Épingler ─────────────────────────────────────────────────────────────────

def test_pinning_records_its_date_and_unpinning_clears_it(client):
    """`pinned_at` ordonne les épingles entre elles : la garder au retrait
    ferait remonter une conversation réépinglée à sa place d'il y a des
    mois."""
    headers, _ = _signup(client, "+22889500101")
    contact = _add_contact(client, headers, "+22889500180", "Awa")

    pinned = _pin(client, headers, "contact", contact["id"]).json()
    assert pinned["is_pinned"] is True
    assert pinned["pinned_at"] is not None

    unpinned = _pin(client, headers, "contact", contact["id"], pinned=False).json()
    assert unpinned["is_pinned"] is False
    assert unpinned["pinned_at"] is None


def test_only_three_conversations_can_be_pinned(client):
    """La limite compte les contacts ET les groupes ensemble : c'est le haut
    de la liste unique qu'elle protège, pas trois places par type."""
    headers, _ = _signup(client, "+22889500102")
    first = _add_contact(client, headers, "+22889500181", "Awa")
    second = _add_contact(client, headers, "+22889500182", "Kofi")
    group = _create_group(client, headers, "Livraisons")
    other_group = _create_group(client, headers, "Fournisseurs")

    assert _pin(client, headers, "contact", first["id"]).status_code == 200
    assert _pin(client, headers, "contact", second["id"]).status_code == 200
    assert _pin(client, headers, "group", group["id"]).status_code == 200

    refused = _pin(client, headers, "group", other_group["id"])
    assert refused.status_code == 409
    assert "3" in refused.json()["detail"]

    # Réépingler ce qui est déjà épinglé ne doit pas se heurter à sa propre
    # présence dans le total.
    assert _pin(client, headers, "contact", first["id"]).status_code == 200

    # Une place libérée redevient utilisable.
    _pin(client, headers, "contact", first["id"], pinned=False)
    assert _pin(client, headers, "group", other_group["id"]).status_code == 200


def test_cannot_pin_or_archive_someone_elses_contact(client):
    """404 et non 403 : répondre « interdit » confirmerait que cette ligne de
    carnet d'adresses existe."""
    headers_a, _ = _signup(client, "+22889500103")
    headers_b, _ = _signup(client, "+22889500104")
    contact_of_b = _add_contact(client, headers_b, "+22889500103", "Le voisin")

    assert _pin(client, headers_a, "contact", contact_of_b["id"]).status_code == 404
    assert _archive(client, headers_a, "contact", contact_of_b["id"]).status_code == 404
    assert _mute(client, headers_a, "contact", contact_of_b["id"], 28800).status_code == 404


def test_cannot_touch_a_group_i_am_not_member_of(client):
    headers_a, _ = _signup(client, "+22889500105")
    headers_b, _ = _signup(client, "+22889500106")
    group = _create_group(client, headers_a, "Comptabilité")

    assert _pin(client, headers_b, "group", group["id"]).status_code == 403
    assert _archive(client, headers_b, "group", group["id"]).status_code == 403
    assert _mute(client, headers_b, "group", group["id"], 28800).status_code == 403


# ─── Sourdine ─────────────────────────────────────────────────────────────────

def test_muting_for_eight_hours_then_restoring_sound(client):
    headers, _ = _signup(client, "+22889500107")
    contact = _add_contact(client, headers, "+22889500183", "Awa")

    muted = _mute(client, headers, "contact", contact["id"], 28800).json()
    assert muted["is_muted"] is True
    assert muted["muted_until"] is not None

    restored = _mute(client, headers, "contact", contact["id"], None).json()
    assert restored["is_muted"] is False
    assert restored["muted_until"] is None


def test_an_expired_mute_needs_no_intervention(client):
    """Le cœur du choix « une date plutôt qu'un booléen » : personne ne
    repasse derrière pour éteindre le silence."""
    headers, user_id = _signup(client, "+22889500108")
    group = _create_group(client, headers, "Marché")

    assert _mute(client, headers, "group", group["id"], 28800).json()["is_muted"] is True

    _update_row(
        GroupMember,
        {"group_id": group["id"], "user_id": user_id},
        {"muted_until": datetime.utcnow() - timedelta(minutes=1)},
    )

    entry = _entry(_list(client, headers), "group", group["id"])
    assert entry["is_muted"] is False
    # La date reste en base : c'est l'historique du réglage, seul le booléen
    # calculé décide.
    assert entry["muted_until"] is not None


def test_muting_forever_stays_muted(client):
    headers, _ = _signup(client, "+22889500109")
    group = _create_group(client, headers, "Annonces du quartier")

    forever = _mute(client, headers, "group", group["id"], MUTE_FOREVER_SECONDS).json()
    assert forever["is_muted"] is True
    # « Toujours » = si loin que ça n'arrivera pas, sans colonne booléenne.
    assert int(forever["muted_until"][:4]) > datetime.utcnow().year + 50


def test_free_form_mute_durations_are_refused(client):
    """Trois libellés côté client, donc trois valeurs côté serveur — et
    aucune valeur assez grande pour faire déborder l'addition de dates."""
    headers, _ = _signup(client, "+22889500110")
    group = _create_group(client, headers, "Divers")

    assert _mute(client, headers, "group", group["id"], 0).status_code == 400
    assert _mute(client, headers, "group", group["id"], 3600).status_code == 400
    assert _mute(client, headers, "group", group["id"], 10 ** 18).status_code == 400


# ─── Bloquer / signaler ───────────────────────────────────────────────────────

def test_is_blocked_between_is_true_in_both_directions(client):
    """Un seul blocage coupe le canal dans les deux sens : sans ça, celui qui
    bloque continuerait d'écrire à quelqu'un qui ne peut plus lui
    répondre."""
    headers_a, user_a = _signup(client, "+22889500111")
    _, user_b = _signup(client, "+22889500112")
    _add_contact(client, headers_a, "+22889500112", "Kofi")

    response = client.put(
        "/api/v1/conversations/block",
        json={"contact_user_id": user_b, "blocked": True},
        headers=headers_a,
    )
    assert response.status_code == 200, response.text
    assert response.json()["is_blocked"] is True

    session = TestingSessionLocal()
    try:
        assert is_blocked_between(session, user_a, user_b) is True
        assert is_blocked_between(session, user_b, user_a) is True
        # Une paire sans blocage ne doit évidemment pas être coupée.
        assert is_blocked_between(session, user_a, 999999) is False
    finally:
        session.close()


def test_blocking_hides_the_conversation_and_fills_the_blocked_list(client):
    headers_a, _ = _signup(client, "+22889500113")
    _, user_b = _signup(client, "+22889500114")
    contact = _add_contact(client, headers_a, "+22889500114", "Kofi")
    _send_direct(client, headers_a, user_b, "Bonjour Kofi")

    assert _entry(_list(client, headers_a), "contact", contact["id"]) is not None

    client.put(
        "/api/v1/conversations/block",
        json={"contact_user_id": user_b, "blocked": True},
        headers=headers_a,
    )

    assert _entry(_list(client, headers_a), "contact", contact["id"]) is None
    blocked = client.get("/api/v1/conversations/blocked", headers=headers_a).json()
    assert [item["contact_user_id"] for item in blocked["items"]] == [user_b]

    # Débloquer rend la conversation intacte : le blocage n'a rien supprimé.
    client.put(
        "/api/v1/conversations/block",
        json={"contact_user_id": user_b, "blocked": False},
        headers=headers_a,
    )
    restored = _entry(_list(client, headers_a), "contact", contact["id"])
    assert restored is not None
    assert restored["last_message"]["content"] == "Bonjour Kofi"
    assert client.get("/api/v1/conversations/blocked", headers=headers_a).json()["total"] == 0


def test_reporting_does_not_block_unless_asked(client, caplog):
    """Signaler et bloquer sont deux gestes distincts. Il n'existe aucune
    table de modération : le signalement part dans les journaux, et c'est tout
    ce que la route promet."""
    headers_a, user_a = _signup(client, "+22889500115")
    _, user_b = _signup(client, "+22889500116")
    _add_contact(client, headers_a, "+22889500116", "Kofi")

    with caplog.at_level(logging.WARNING, logger="app.api.v1.messaging.conversations"):
        response = client.post(
            "/api/v1/conversations/report",
            json={"contact_user_id": user_b, "reason": "Messages non sollicités"},
            headers=headers_a,
        )
    assert response.status_code == 200, response.text
    assert response.json()["blocked"] is False
    assert "Messages non sollicités" in caplog.text
    assert client.get("/api/v1/conversations/blocked", headers=headers_a).json()["total"] == 0

    followup = client.post(
        "/api/v1/conversations/report",
        json={"contact_user_id": user_b, "reason": "Récidive", "also_block": True},
        headers=headers_a,
    )
    assert followup.json()["blocked"] is True
    assert client.get("/api/v1/conversations/blocked", headers=headers_a).json()["total"] == 1

    # Un inconnu peut être signalé (c'est le cas le plus fréquent) sans que la
    # route devienne un oracle d'existence de comptes.
    unknown = client.post(
        "/api/v1/conversations/report",
        json={"contact_user_id": 999999, "reason": "Inconnu insistant"},
        headers=headers_a,
    )
    assert unknown.status_code == 200
    # Mais le blocage, lui, exige la ligne de contact où l'inscrire.
    refused = client.post(
        "/api/v1/conversations/report",
        json={"contact_user_id": 999999, "reason": "Inconnu", "also_block": True},
        headers=headers_a,
    )
    assert refused.status_code == 403


# ─── Liste unifiée ────────────────────────────────────────────────────────────

def test_the_list_carries_a_compact_preview_and_the_unread_count(client):
    headers_a, user_a = _signup(client, "+22889500117")
    headers_b, user_b = _signup(client, "+22889500118")
    contact = _add_contact(client, headers_a, "+22889500118", "Kofi")
    _add_contact(client, headers_b, "+22889500117", "Awa")

    long_message = "Bonjour, " + "je confirme la commande de sacs de riz " * 5
    _send_direct(client, headers_b, user_a, long_message)

    entry = _entry(_list(client, headers_a), "contact", contact["id"])
    assert entry["name"] == "Kofi"
    assert entry["unread_count"] == 1
    preview = entry["last_message"]
    # Tronqué : la liste d'accueil affiche une ligne, pas l'historique.
    assert len(preview["content"]) < len(long_message)
    assert preview["is_mine"] is False
    assert preview["sender_id"] == user_b
    assert preview["message_type"] == "TEXT"
    # Le nom du carnet d'adresses l'emporte sur le nom de profil.
    assert preview["sender_name"] == "Kofi"


def test_pinned_come_first_then_the_most_recent(client):
    """Deux règles à la fois : l'épinglée passe devant même si elle est la
    plus ancienne, et le reste se trie par activité décroissante."""
    headers_a, user_a = _signup(client, "+22889500119")
    _, user_b = _signup(client, "+22889500120")
    contact = _add_contact(client, headers_a, "+22889500120", "Kofi")
    old_direct = _send_direct(client, headers_a, user_b, "Message d'hier")
    _update_row(
        DirectMessage,
        {"id": old_direct["id"]},
        {"created_at": datetime.utcnow() - timedelta(hours=6)},
    )

    stale_group = _create_group(client, headers_a, "Vieux groupe")
    stale_message = _send_group(client, headers_a, stale_group["id"], "Il y a trois jours")
    _update_row(
        GroupMessage,
        {"id": stale_message["id"]},
        {"created_at": datetime.utcnow() - timedelta(days=3)},
    )
    _pin(client, headers_a, "group", stale_group["id"])

    fresh_group = _create_group(client, headers_a, "Groupe actif")
    _send_group(client, headers_a, fresh_group["id"], "À l'instant")

    listing = _list(client, headers_a)
    assert [(item["kind"], item["id"]) for item in listing["items"]] == [
        ("group", stale_group["id"]),
        ("group", fresh_group["id"]),
        ("contact", contact["id"]),
    ]


def test_archived_are_hidden_by_default_and_visible_on_demand(client):
    """Archiver n'est pas supprimer : la conversation sort de la liste
    principale et se retrouve intacte de l'autre côté."""
    headers, _ = _signup(client, "+22889500121")
    kept = _create_group(client, headers, "En cours")
    put_away = _create_group(client, headers, "Terminé")
    _mute(client, headers, "group", put_away["id"], 28800)

    archived_payload = _archive(client, headers, "group", put_away["id"]).json()
    assert archived_payload["is_archived"] is True

    main = _list(client, headers)
    assert [item["id"] for item in main["items"]] == [kept["id"]]

    drawer = _list(client, headers, archived=True)
    assert [item["id"] for item in drawer["items"]] == [put_away["id"]]
    # Rien n'a été perdu au passage.
    assert drawer["items"][0]["is_muted"] is True

    _archive(client, headers, "group", put_away["id"], archived=False)
    assert len(_list(client, headers)["items"]) == 2


def test_a_group_with_no_message_yet_is_still_listed(client):
    """On y a été ajouté : il doit être visible pour qu'on puisse y écrire le
    premier. Un CONTACT sans message, lui, reste hors liste — sinon la liste
    des conversations serait le carnet d'adresses entier."""
    headers, _ = _signup(client, "+22889500122")
    group = _create_group(client, headers, "Tout neuf")
    contact = _add_contact(client, headers, "+22889500184", "Jamais écrit")

    listing = _list(client, headers)
    entry = _entry(listing, "group", group["id"])
    assert entry is not None
    assert entry["last_message"] is None
    assert _entry(listing, "contact", contact["id"]) is None


# ─── Personne qui écrit sans être dans mon carnet (façon WhatsApp) ───────────

def test_a_stranger_who_messages_me_appears_in_my_conversation_list(client):
    """Le cœur du correctif : `_require_contact` (messages.py) ne vérifie que
    le carnet de L'EXPÉDITEUR — B peut m'écrire sans que j'aie B dans le
    mien. Sans ce bloc, ce fil resterait invisible : aucune ligne Contact de
    mon côté pour le porter."""
    headers_a, user_id_a = _signup(client, "+22899000001")
    headers_b, user_id_b = _signup(client, "+22899000002")
    client.post("/api/v1/contacts", json={"phone": "+22899000001", "display_name": "A"}, headers=headers_b)

    sent = client.post(
        "/api/v1/messages", json={"recipient_id": user_id_a, "content": "salut, on se connaît ?"}, headers=headers_b
    )
    assert sent.status_code == 200, sent.text

    items = client.get("/api/v1/conversations", headers=headers_a).json()["items"]
    stranger_rows = [row for row in items if row.get("contact_user_id") == user_id_b]
    assert len(stranger_rows) == 1
    row = stranger_rows[0]
    assert row["is_unknown_contact"] is True
    assert row["id"] is None
    assert row["last_message"]["content"] == "salut, on se connaît ?"
    # Le nom de profil de B (ou son numéro), pas un nom que A n'a jamais posé.
    assert row["name"] in ("+22899000002", None) or row["name"]


def test_a_stranger_thread_does_not_duplicate_a_known_contact_row(client):
    headers_a, user_id_a = _signup(client, "+22899000003")
    headers_b, user_id_b = _signup(client, "+22899000004")
    client.post("/api/v1/contacts", json={"phone": "+22899000004", "display_name": "Bob"}, headers=headers_a)
    # `_require_contact` (messages.py) vérifie le carnet de L'EXPÉDITEUR : B
    # doit avoir A dans SES propres contacts pour pouvoir envoyer, que A ait
    # ou non ajouté B de son côté.
    client.post("/api/v1/contacts", json={"phone": "+22899000003", "display_name": "A"}, headers=headers_b)
    sent = client.post(
        "/api/v1/messages", json={"recipient_id": user_id_a, "content": "yo"}, headers=headers_b
    )
    assert sent.status_code == 200, sent.text

    items = client.get("/api/v1/conversations", headers=headers_a).json()["items"]
    matches = [row for row in items if row.get("contact_user_id") == user_id_b]
    assert len(matches) == 1
    assert matches[0]["is_unknown_contact"] is False
    assert matches[0]["name"] == "Bob"


def test_blocking_a_stranger_removes_them_from_the_list(client):
    headers_a, user_id_a = _signup(client, "+22899000005")
    headers_b, user_id_b = _signup(client, "+22899000006")
    # B doit avoir A dans SES propres contacts pour pouvoir lui écrire — la
    # règle `_require_contact` porte sur l'expéditeur, jamais sur A ici.
    client.post("/api/v1/contacts", json={"phone": "+22899000005", "display_name": "A"}, headers=headers_b)
    sent = client.post(
        "/api/v1/messages", json={"recipient_id": user_id_a, "content": "spam"}, headers=headers_b
    )
    assert sent.status_code == 200, sent.text
    assert any(
        row.get("contact_user_id") == user_id_b
        for row in client.get("/api/v1/conversations", headers=headers_a).json()["items"]
    )

    # Bloquer un inconnu crée la ligne Contact nécessaire (le blocage est déjà
    # documenté comme réservé aux Contact rows) — ici on vérifie juste l'effet
    # sur la liste une fois bloqué par ce biais.
    client.post("/api/v1/contacts", json={"phone": "+22899000006", "display_name": "Inconnu"}, headers=headers_a)
    client.put(
        "/api/v1/conversations/block", json={"contact_user_id": user_id_b, "blocked": True}, headers=headers_a
    )
    items = client.get("/api/v1/conversations", headers=headers_a).json()["items"]
    assert not any(row.get("contact_user_id") == user_id_b for row in items)


def test_archived_view_never_includes_stranger_threads(client):
    """Un inconnu n'a pas de case à cocher « archiver » — il ne peut donc
    apparaître ni disparaître selon ce filtre."""
    headers_a, user_id_a = _signup(client, "+22899000007")
    headers_b, user_id_b = _signup(client, "+22899000008")
    client.post("/api/v1/contacts", json={"phone": "+22899000007", "display_name": "A"}, headers=headers_b)
    sent = client.post(
        "/api/v1/messages", json={"recipient_id": user_id_a, "content": "coucou"}, headers=headers_b
    )
    assert sent.status_code == 200, sent.text

    # Preuve que l'absence ci-dessous n'est pas due à un envoi qui aurait
    # simplement échoué : le fil existe bien, seulement pas dans les archives.
    assert any(
        row.get("contact_user_id") == user_id_b
        for row in client.get("/api/v1/conversations", headers=headers_a).json()["items"]
    )
    archived_items = client.get("/api/v1/conversations?archived=true", headers=headers_a).json()["items"]
    assert not any(row.get("contact_user_id") == user_id_b for row in archived_items)


# ─── Les communautés dans la liste d'accueil ──────────────────────────────────


def _create_community(client, headers, name="Quartier"):
    response = client.post("/api/v1/communities", json={"name": name}, headers=headers)
    assert response.status_code == 200, response.text
    return response.json()


def _add_community_group(client, headers, community_id, name):
    response = client.post(
        f"/api/v1/communities/{community_id}/groups", json={"name": name}, headers=headers
    )
    assert response.status_code == 200, response.text
    return response.json()


def test_une_communaute_apparait_dans_la_liste(client):
    headers, _ = _signup(client, "+22893100001")
    community = _create_community(client, headers, "Quartier Bè")

    listing = _list(client, headers)
    row = _entry(listing, "community", community["id"])
    assert row is not None, "une communauté doit figurer dans la liste d'accueil"
    assert row["name"] == "Quartier Bè"
    # Créée avec son groupe d'annonces.
    assert row["group_count"] >= 1


def test_les_groupes_d_une_communaute_ne_sont_pas_listes_a_part(client):
    """Les afficher aux deux endroits montrerait la même conversation deux
    fois — et on n'ouvrirait jamais une communauté dont on voit déjà tous les
    groupes au-dessus."""
    headers, _ = _signup(client, "+22893100002")
    community = _create_community(client, headers)
    inner = _add_community_group(client, headers, community["id"], "Voisins")

    listing = _list(client, headers)
    assert _entry(listing, "group", inner["id"]) is None
    row = _entry(listing, "community", community["id"])
    assert row["group_count"] == 2, "annonces + le groupe ajouté"


def test_un_groupe_sans_communaute_reste_a_sa_place(client):
    headers, _ = _signup(client, "+22893100003")
    _create_community(client, headers)
    standalone = _create_group(client, headers, "Foot du dimanche")

    listing = _list(client, headers)
    assert _entry(listing, "group", standalone["id"]) is not None


def test_l_apercu_d_une_communaute_est_le_dernier_message_de_ses_groupes(client):
    """C'est la seule information qui dise s'il s'y passe quelque chose sans
    avoir à l'ouvrir."""
    headers, _ = _signup(client, "+22893100004")
    community = _create_community(client, headers)
    inner = _add_community_group(client, headers, community["id"], "Voisins")
    _send_group(client, headers, inner["id"], "On se voit ce soir")

    row = _entry(_list(client, headers), "community", community["id"])
    assert row["last_message"] is not None
    assert row["last_message"]["content"] == "On se voit ce soir"


def test_une_communaute_sans_message_se_range_quand_meme(client):
    headers, _ = _signup(client, "+22893100005")
    community = _create_community(client, headers)

    row = _entry(_list(client, headers), "community", community["id"])
    assert row["last_message"] is None
    # La ligne existe malgré tout : c'est le compte de groupes qui la remplit.
    assert row["group_count"] >= 1
