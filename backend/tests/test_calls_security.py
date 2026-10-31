"""Appels Pokou — contrôles d'accès et cycle de vie (audit du 23 octobre 2026).

Chaque test négatif reproduit une faille PROUVÉE par l'audit :

- A1 : `/calls/signal` acceptait le signal de n'importe qui sur n'importe quel
  salon, et relayait l'événement (WebSocket et push) à n'importe quel
  identifiant ;
- A2 : `/calls/token` délivrait un jeton LiveKit de six heures pour une salle
  inventée ;
- A3 : un appel de groupe faisait sonner une personne qui avait bloqué
  l'appelant.

On vérifie ce qui SORT (code HTTP, journal, événements envoyés), pas
l'intention du code.
"""
from datetime import datetime, timedelta
from unittest.mock import AsyncMock, patch

import jwt

from tests.test_calls import (  # noqa: F401 — `client` est une fixture
    TestingSessionLocal,
    _accepter_invitations,
    _make_group,
    _patched_livekit,
    _signup,
    client,
)


def _call(client, headers_caller, phone_callee, callee_id, *, is_video=False):
    client.post("/api/v1/contacts", json={"phone": phone_callee, "display_name": "B"}, headers=headers_caller)
    patch_service, patch_route = _patched_livekit()
    with patch_service, patch_route:
        response = client.post(
            "/api/v1/calls/token", json={"contact_ids": [callee_id], "is_video": is_video}, headers=headers_caller
        )
    assert response.status_code == 200, response.text
    return response.json()["room"]


def _status_seen_by(client, headers):
    return client.get("/api/v1/calls/log", headers=headers).json()["items"][0]["status"]


def _token(client, headers, room):
    patch_service, patch_route = _patched_livekit()
    with patch_service, patch_route:
        return client.post("/api/v1/calls/token", json={"room": room}, headers=headers)


# ── A1 : /calls/signal ──────────────────────────────────────────────────────


def test_un_etranger_ne_peut_ni_terminer_ni_accepter_ni_refuser_l_appel_d_autrui(client):
    headers_a, _, _ = _signup(client, "+22894200001")
    _, user_id_b, _ = _signup(client, "+22894200002")
    headers_c, _, _ = _signup(client, "+22894200003")
    room = _call(client, headers_a, "+22894200002", user_id_b)

    with patch("app.api.v1.calls.calls.manager.send_to_user", new=AsyncMock(return_value=False)) as relayed, patch(
        "app.api.v1.calls.calls.send_push"
    ) as pushed:
        for event in ("end", "accept", "decline"):
            response = client.post(
                "/api/v1/calls/signal",
                json={"room": room, "target_user_id": user_id_b, "event": event},
                headers=headers_c,
            )
            assert response.status_code == 404, (event, response.text)

    relayed.assert_not_called()
    pushed.assert_not_called()
    assert _status_seen_by(client, headers_a) == "ringing", "le journal ne doit pas bouger"


def test_un_participant_ne_peut_pas_signaler_a_quelqu_un_hors_de_l_appel(client):
    headers_a, _, _ = _signup(client, "+22894200004")
    _, user_id_b, _ = _signup(client, "+22894200005")
    _, user_id_c, _ = _signup(client, "+22894200006")
    room = _call(client, headers_a, "+22894200005", user_id_b)

    with patch("app.api.v1.calls.calls.manager.send_to_user", new=AsyncMock(return_value=False)) as relayed, patch(
        "app.api.v1.calls.calls.send_push"
    ) as pushed:
        response = client.post(
            "/api/v1/calls/signal",
            json={"room": room, "target_user_id": user_id_c, "event": "end"},
            headers=headers_a,
        )

    assert response.status_code == 400
    relayed.assert_not_called()
    pushed.assert_not_called()


def test_l_appelant_ne_repond_pas_a_son_propre_appel(client):
    headers_a, user_id_a, _ = _signup(client, "+22894200007")
    _, user_id_b, _ = _signup(client, "+22894200008")
    room = _call(client, headers_a, "+22894200008", user_id_b)

    response = client.post(
        "/api/v1/calls/signal", json={"room": room, "target_user_id": user_id_b, "event": "accept"}, headers=headers_a
    )
    assert response.status_code == 400


def test_on_n_accepte_pas_un_appel_termine_mais_raccrocher_deux_fois_est_sans_effet(client):
    headers_a, user_id_a, _ = _signup(client, "+22894200009")
    headers_b, user_id_b, _ = _signup(client, "+22894200010")
    room = _call(client, headers_a, "+22894200010", user_id_b)

    first = client.post(
        "/api/v1/calls/signal", json={"room": room, "target_user_id": user_id_b, "event": "end"}, headers=headers_a
    )
    assert first.status_code == 200
    assert _status_seen_by(client, headers_a) == "missed"

    late_accept = client.post(
        "/api/v1/calls/signal", json={"room": room, "target_user_id": user_id_a, "event": "accept"}, headers=headers_b
    )
    assert late_accept.status_code == 409
    second_end = client.post(
        "/api/v1/calls/signal", json={"room": room, "target_user_id": user_id_a, "event": "end"}, headers=headers_b
    )
    assert second_end.status_code == 200 and second_end.json().get("already_over") is True
    assert _status_seen_by(client, headers_a) == "missed"


# ── A2 : /calls/token ───────────────────────────────────────────────────────


def test_pas_de_jeton_pour_une_salle_inventee(client):
    headers, _, _ = _signup(client, "+22894200011")
    response = _token(client, headers, "ma-salle-privee-hors-pokou")
    assert response.status_code == 404
    assert "token" not in response.json()


def test_pas_de_jeton_pour_l_appel_d_autrui(client):
    headers_a, _, _ = _signup(client, "+22894200012")
    _, user_id_b, _ = _signup(client, "+22894200013")
    headers_c, _, _ = _signup(client, "+22894200014")
    room = _call(client, headers_a, "+22894200013", user_id_b)

    assert _token(client, headers_c, room).status_code == 404


def test_pas_de_jeton_apres_la_fin_de_l_appel(client):
    headers_a, _, _ = _signup(client, "+22894200015")
    headers_b, user_id_b, _ = _signup(client, "+22894200016")
    room = _call(client, headers_a, "+22894200016", user_id_b)
    assert _token(client, headers_b, room).status_code == 200

    client.post(
        "/api/v1/calls/signal", json={"room": room, "target_user_id": user_id_b, "event": "end"}, headers=headers_a
    )
    assert _token(client, headers_b, room).status_code == 409


def test_un_membre_du_groupe_rejoint_l_appel_de_groupe_mais_pas_un_etranger(client):
    headers_a, _, _ = _signup(client, "+22894200017")
    headers_b, user_id_b, _ = _signup(client, "+22894200018")
    headers_c, _, _ = _signup(client, "+22894200019")
    group = _make_group(client, headers_a, "Chantier", [("+22894200018", user_id_b)])
    patch_service, patch_route = _patched_livekit()
    with patch_service, patch_route:
        room = client.post("/api/v1/calls/token", json={"group_id": group["id"]}, headers=headers_a).json()["room"]

    assert _token(client, headers_b, room).status_code == 200
    assert _token(client, headers_c, room).status_code == 404


def test_le_jeton_livekit_est_court_et_ne_porte_pas_le_numero(client):
    headers_a, _, _ = _signup(client, "+22894200020")
    _, user_id_b, _ = _signup(client, "+22894200021")
    client.post("/api/v1/contacts", json={"phone": "+22894200021", "display_name": "B"}, headers=headers_a)
    patch_service, patch_route = _patched_livekit()
    with patch_service, patch_route:
        body = client.post("/api/v1/calls/token", json={"contact_ids": [user_id_b]}, headers=headers_a).json()

    claims = jwt.decode(body["token"], options={"verify_signature": False})
    assert claims["exp"] - claims["nbf"] <= 15 * 60 + 5
    assert "+22894200020" not in str(claims), "le numéro de l'appelant ne doit pas circuler dans LiveKit"


# ── A3 : blocage dans les appels de groupe ──────────────────────────────────


def _block(client, headers_owner, phone_other, other_id):
    client.post("/api/v1/contacts", json={"phone": phone_other, "display_name": "X"}, headers=headers_owner)
    response = client.put(
        "/api/v1/conversations/block", json={"contact_user_id": other_id, "blocked": True}, headers=headers_owner
    )
    assert response.status_code == 200, response.text


def test_un_appel_de_groupe_ne_fait_pas_sonner_qui_a_bloque_l_appelant(client):
    headers_a, user_id_a, _ = _signup(client, "+22894200022")  # a bloqué B
    headers_b, user_id_b, _ = _signup(client, "+22894200023")  # appelle le groupe
    _, user_id_c, _ = _signup(client, "+22894200024")
    group = _make_group(client, headers_b, "Famille", [("+22894200022", user_id_a), ("+22894200024", user_id_c)])
    _block(client, headers_a, "+22894200023", user_id_b)

    with patch("app.api.v1.calls.calls.manager.send_to_user", new=AsyncMock(return_value=True)) as relayed:
        patch_service, patch_route = _patched_livekit()
        with patch_service, patch_route:
            response = client.post("/api/v1/calls/token", json={"group_id": group["id"]}, headers=headers_b)

    assert response.status_code == 200, response.text
    rung = {call.args[0] for call in relayed.call_args_list}
    assert user_id_a not in rung and user_id_c in rung
    assert client.get("/api/v1/calls/log", headers=headers_a).json()["items"] == []


def test_un_appel_de_groupe_ou_tout_le_monde_a_bloque_l_appelant_est_refuse(client):
    headers_a, user_id_a, _ = _signup(client, "+22894200025")
    headers_b, user_id_b, _ = _signup(client, "+22894200026")
    group = _make_group(client, headers_b, "Duo", [("+22894200025", user_id_a)])
    _block(client, headers_a, "+22894200026", user_id_b)

    patch_service, patch_route = _patched_livekit()
    with patch_service, patch_route:
        response = client.post("/api/v1/calls/token", json={"group_id": group["id"]}, headers=headers_b)
    assert response.status_code == 400


def test_un_groupe_trop_grand_ne_peut_pas_tout_faire_sonner(client):
    headers_a, _, _ = _signup(client, "+22894200027")
    _, user_id_b, _ = _signup(client, "+22894200028")
    _, user_id_c, _ = _signup(client, "+22894200029")
    group = _make_group(client, headers_a, "Grand", [("+22894200028", user_id_b), ("+22894200029", user_id_c)])

    patch_service, patch_route = _patched_livekit()
    with patch_service, patch_route as route_settings:
        route_settings.return_value.call_max_group_ring = 1
        response = client.post("/api/v1/calls/token", json={"group_id": group["id"]}, headers=headers_a)
    assert response.status_code == 400
    assert "trop grand" in response.json()["detail"]


# ── Cycle de vie : appels abandonnés ────────────────────────────────────────


def test_le_balayage_clot_les_appels_abandonnes_et_seulement_eux(client):
    from app.models import ActionToken, CallLog, DirectMessage
    from app.services.calls import call_housekeeping

    headers_a, _, _ = _signup(client, "+22894200030")
    _, user_id_b, _ = _signup(client, "+22894200031")
    stale_ringing = _call(client, headers_a, "+22894200031", user_id_b)
    stale_ongoing = _call(client, headers_a, "+22894200031", user_id_b)
    fresh = _call(client, headers_a, "+22894200031", user_id_b)

    db = TestingSessionLocal()
    try:
        now = datetime.utcnow()
        db.query(CallLog).filter(CallLog.room == stale_ringing).update({"created_at": now - timedelta(minutes=5)})
        db.query(CallLog).filter(CallLog.room == stale_ongoing).update(
            {"created_at": now - timedelta(hours=5), "status": "ongoing"}
        )
        db.query(ActionToken).update({"expires_at": now - timedelta(days=3)})
        db.commit()

        result = call_housekeeping.run(db)
        assert result["closed_calls"] == 2
        assert result["purged_action_tokens"] >= 1

        status = {c.room: c.status for c in db.query(CallLog).all()}
        assert status[stale_ringing] == "missed"
        assert status[stale_ongoing] == "ended"
        assert status[fresh] == "ringing"
        bubbles = db.query(DirectMessage).filter(DirectMessage.payload.isnot(None)).count()
        assert bubbles == 2, "chaque appel clos laisse sa trace dans la conversation"

        assert call_housekeeping.run(db)["closed_calls"] == 0, "idempotent"
    finally:
        db.close()
