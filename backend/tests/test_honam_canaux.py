"""Les conversations d'une commande Honam, séparées selon les acteurs
(migration 0025_honam_canaux) : patient (patiente ↔ officine), coursier
(officine ↔ coursier), livraison (patiente ↔ coursier). Personne ne voit un
canal qui ne le concerne pas ; un coursier remplacé perd l'accès."""
from unittest.mock import patch

from app.models import CourierProfile, HonamOrder, HonamOrderMessage
from app.services.events.live_updates import honam_message_sends
from app.services.honam import order_notifications
from tests.test_honam import (  # noqa: F401  (fixtures réutilisées)
    TestingSessionLocal,
    _pharmacy,
    _quote,
    _signup,
    _submit,
    client,
    stub_mobile_money,
)

API = "/api/v1/honam/orders"


def _validated_courier(client):
    headers, user_id = _signup(client)
    client.post("/api/v1/honam/courier/join", json={
        "zones": "Bè", "wallet_phone": "+22890777777", "accept_rules": True,
    }, headers=headers)
    from app.services.honam import rules
    with TestingSessionLocal() as db:
        courier = db.query(CourierProfile).filter(CourierProfile.user_id == user_id).first()
        rules.start_trial(db, courier)
        db.commit()
    return headers, user_id


def _ready_order(client):
    patient, patient_id = _signup(client)
    pharmacist, pharmacist_id = _signup(client)
    pharmacy_id = _pharmacy(pharmacist_id)
    oid = _submit(client, patient, pharmacy_id).json()["id"]
    _quote(client, pharmacist, oid)
    client.post(f"{API}/{oid}/accept", headers=patient)
    client.post(f"/api/v1/honam/pharmacy/orders/{oid}/confirm-payment", headers=pharmacist)
    client.post(f"/api/v1/honam/pharmacy/orders/{oid}/ready", headers=pharmacist)
    return patient, patient_id, pharmacist, pharmacist_id, oid


def _say(client, headers, oid, channel, text):
    return client.post(f"{API}/{oid}/messages", json={"body": text, "channel": channel}, headers=headers)


def _read(client, headers, oid, channel):
    return client.get(f"{API}/{oid}/messages?channel={channel}", headers=headers)


def _bodies(response):
    return [m["body"] for m in response.json()["items"]]


def test_chaque_acteur_ne_lit_et_necrit_que_ses_canaux(client):
    patient, _, pharmacist, _, oid = _ready_order(client)
    courier, _ = _validated_courier(client)
    outsider, _ = _signup(client)

    # Sans coursier, les canaux du coursier n'existent pour personne.
    assert _say(client, pharmacist, oid, "coursier", "Prêt").status_code == 404
    assert _say(client, patient, oid, "livraison", "Je suis là").status_code == 404

    client.post(f"/api/v1/honam/courier/rides/{oid}/accept", headers=courier)
    assert _say(client, patient, oid, "patient", "P→O").json()["sender_role"] == "PATIENT"
    assert _say(client, pharmacist, oid, "patient", "O→P").json()["sender_role"] == "PHARMACY"
    assert _say(client, pharmacist, oid, "coursier", "O→C").json()["sender_role"] == "PHARMACY"
    assert _say(client, courier, oid, "coursier", "C→O").json()["sender_role"] == "COURIER"
    assert _say(client, patient, oid, "livraison", "P→C").json()["sender_role"] == "PATIENT"
    assert _say(client, courier, oid, "livraison", "C→P").json()["channel"] == "livraison"

    # La patiente : patient et livraison, jamais coursier.
    assert _bodies(_read(client, patient, oid, "patient")) == ["P→O", "O→P"]
    assert _bodies(_read(client, patient, oid, "livraison")) == ["P→C", "C→P"]
    assert _read(client, patient, oid, "coursier").status_code == 404
    assert _say(client, patient, oid, "coursier", "Indu").status_code == 404
    assert _read(client, patient, oid, "patient").json()["channels"] == ["patient", "livraison"]
    # Le coursier : coursier et livraison, jamais patient.
    assert _bodies(_read(client, courier, oid, "coursier")) == ["O→C", "C→O"]
    assert _bodies(_read(client, courier, oid, "livraison")) == ["P→C", "C→P"]
    assert _read(client, courier, oid, "patient").status_code == 404
    assert _say(client, courier, oid, "patient", "Indu").status_code == 404
    # L'officine : patient et coursier, jamais livraison.
    assert _bodies(_read(client, pharmacist, oid, "patient")) == ["P→O", "O→P"]
    assert _bodies(_read(client, pharmacist, oid, "coursier")) == ["O→C", "C→O"]
    assert _read(client, pharmacist, oid, "livraison").status_code == 404
    assert _say(client, pharmacist, oid, "livraison", "Indu").status_code == 404
    # Un tiers : rien ; un canal inconnu : rien.
    for channel in ("patient", "coursier", "livraison"):
        assert _read(client, outsider, oid, channel).status_code == 404
    assert _read(client, patient, oid, "tout").status_code == 404


def test_canal_par_defaut_des_anciennes_versions(client):
    patient, _, pharmacist, _, oid = _ready_order(client)
    courier, _ = _validated_courier(client)
    client.post(f"/api/v1/honam/courier/rides/{oid}/accept", headers=courier)
    assert client.post(f"{API}/{oid}/messages", json={"body": "a"}, headers=patient).json()["channel"] == "patient"
    assert client.post(f"{API}/{oid}/messages", json={"body": "b"}, headers=pharmacist).json()["channel"] == "patient"
    assert client.post(f"{API}/{oid}/messages", json={"body": "c"}, headers=courier).json()["channel"] == "coursier"
    assert client.get(f"{API}/{oid}/messages", headers=courier).json()["channel"] == "coursier"


def test_coursier_remplace_perd_lacces(client):
    patient, _, pharmacist, _, oid = _ready_order(client)
    first, _ = _validated_courier(client)
    second, _ = _validated_courier(client)
    client.post(f"/api/v1/honam/courier/rides/{oid}/accept", headers=first)
    _say(client, pharmacist, oid, "coursier", "Pour le premier")
    _say(client, patient, oid, "livraison", "Au premier")
    # L'officine signale un défaut : la course revient à « prête ».
    client.post(f"/api/v1/honam/pharmacy/orders/{oid}/courier-default", json={"reason": "Jamais venu"}, headers=pharmacist)
    for channel in ("coursier", "livraison", "patient"):
        assert _read(client, first, oid, channel).status_code == 404
        assert _say(client, first, oid, channel, "Encore là").status_code == 404
    client.post(f"/api/v1/honam/courier/rides/{oid}/accept", headers=second)
    # Le remplaçant ne lit pas ce qui a été dit à l'autre.
    assert _bodies(_read(client, second, oid, "coursier")) == []
    assert _bodies(_read(client, second, oid, "livraison")) == []
    _say(client, pharmacist, oid, "coursier", "Pour le second")
    assert _bodies(_read(client, second, oid, "coursier")) == ["Pour le second"]
    # L'officine garde tout son fil avec les coursiers.
    assert _bodies(_read(client, pharmacist, oid, "coursier")) == ["Pour le premier", "Pour le second"]


def test_temps_reel_et_push_aux_seuls_membres_du_canal(client):
    patient, patient_id, pharmacist, pharmacist_id, oid = _ready_order(client)
    courier, courier_id = _validated_courier(client)
    client.post(f"/api/v1/honam/courier/rides/{oid}/accept", headers=courier)

    with patch.object(order_notifications, "send_push") as push:
        _say(client, courier, oid, "coursier", "Je suis devant")
    assert {c.args[1] for c in push.call_args_list} == {pharmacist_id}
    with patch.object(order_notifications, "send_push") as push:
        _say(client, pharmacist, oid, "patient", "Votre commande part")
    assert {c.args[1] for c in push.call_args_list} == {patient_id}
    with patch.object(order_notifications, "send_push") as push:
        _say(client, patient, oid, "livraison", "Portail bleu")
    assert {c.args[1] for c in push.call_args_list} == {courier_id}

    with TestingSessionLocal() as db:
        by_channel = {
            m.channel: m.id for m in db.query(HonamOrderMessage).filter(HonamOrderMessage.order_id == oid)
        }
        expected = {
            "coursier": {pharmacist_id, courier_id},
            "patient": {patient_id, pharmacist_id},
            "livraison": {patient_id, courier_id},
        }
        for channel, message_id in by_channel.items():
            sends = honam_message_sends(db, {message_id})
            assert {u for u, _ in sends} == expected[channel]
            assert all(e == {"type": "honam:order_message", "order_id": oid, "channel": channel} for _, e in sends)
        # Coursier remplacé : il ne reçoit plus rien de ses anciens canaux.
        db.query(HonamOrder).filter(HonamOrder.id == oid).update({"courier_id": None})
        db.commit()
        for channel in ("coursier", "livraison"):
            assert courier_id not in {u for u, _ in honam_message_sends(db, {by_channel[channel]})}
