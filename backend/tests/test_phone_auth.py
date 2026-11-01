import re
from unittest.mock import patch

import pytest
from fastapi.testclient import TestClient
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker

from app.main import app
from app.core.database import Base, get_db
from app.models import User
from app.services.auth import otp_service

TEST_DATABASE_URL = "sqlite:///./test_phone_auth.db"

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
    # L'override est posé PAR TEST et retiré ensuite, jamais au niveau du
    # module : pytest importe tous les fichiers de test avant d'en exécuter
    # un seul, donc une affectation au niveau module est écrasée par celle
    # du dernier fichier importé. Toutes les suites se retrouvaient alors à
    # lire la base d'une autre — ce qui ne se voit qu'en lançant la suite
    # entière, et jamais un fichier seul.
    previous = app.dependency_overrides.get(get_db)
    app.dependency_overrides[get_db] = override_get_db
    yield TestClient(app)
    if previous is not None:
        app.dependency_overrides[get_db] = previous
    else:
        app.dependency_overrides.pop(get_db, None)
    Base.metadata.drop_all(bind=engine)


def _request_otp_and_extract_code(client, phone="+22890123456"):
    with patch.object(otp_service.sms_service, "send_sms", return_value=True) as mock_send:
        response = client.post("/api/v1/auth/phone/request-otp", json={"phone": phone})
    assert response.status_code == 200, response.text
    sent_text = mock_send.call_args.args[2]
    code = re.search(r"\b(\d{6})\b", sent_text).group(1)
    return code


def test_request_otp_creates_row_without_creating_user(client):
    db = TestingSessionLocal()
    try:
        _request_otp_and_extract_code(client, phone="+22890000001")
        assert db.query(User).filter(User.phone == "+22890000001").first() is None
    finally:
        db.close()


def test_verify_otp_success_creates_user_and_returns_tokens(client):
    phone = "+22890000002"
    code = _request_otp_and_extract_code(client, phone=phone)

    response = client.post("/api/v1/auth/phone/verify-otp", json={"phone": phone, "code": code})
    assert response.status_code == 200, response.text
    body = response.json()
    assert body["access_token"]
    assert body["refresh_token"]
    assert body["user"]["phone"] == phone
    assert body["user"]["email"] is None

    db = TestingSessionLocal()
    try:
        user = db.query(User).filter(User.phone == phone).first()
        assert user is not None
    finally:
        db.close()


def test_verify_otp_is_idempotent_same_user(client):
    phone = "+22890000003"
    code = _request_otp_and_extract_code(client, phone=phone)
    r1 = client.post("/api/v1/auth/phone/verify-otp", json={"phone": phone, "code": code})
    user_id_1 = r1.json()["user"]["id"]

    code2 = _request_otp_and_extract_code(client, phone=phone)
    r2 = client.post("/api/v1/auth/phone/verify-otp", json={"phone": phone, "code": code2})
    assert r2.json()["user"]["id"] == user_id_1


def test_verify_otp_wrong_code_rejected(client):
    phone = "+22890000004"
    _request_otp_and_extract_code(client, phone=phone)
    response = client.post("/api/v1/auth/phone/verify-otp", json={"phone": phone, "code": "000000"})
    assert response.status_code == 400


def test_verify_otp_cannot_be_replayed(client):
    phone = "+22890000005"
    code = _request_otp_and_extract_code(client, phone=phone)
    first = client.post("/api/v1/auth/phone/verify-otp", json={"phone": phone, "code": code})
    assert first.status_code == 200
    replay = client.post("/api/v1/auth/phone/verify-otp", json={"phone": phone, "code": code})
    assert replay.status_code == 400


def test_invalid_phone_format_rejected(client):
    with patch.object(otp_service.sms_service, "send_sms", return_value=True):
        response = client.post("/api/v1/auth/phone/request-otp", json={"phone": "not-a-phone"})
    assert response.status_code == 400


def test_request_otp_rate_limited_after_three_requests(client, monkeypatch):
    # La fenêtre de 15 minutes, sans le délai de renvoi de 60 s testé à part.
    monkeypatch.setattr(otp_service, "RESEND_MIN_SECONDS", 0)
    phone = "+22890000006"
    with patch.object(otp_service.sms_service, "send_sms", return_value=True):
        for _ in range(3):
            r = client.post("/api/v1/auth/phone/request-otp", json={"phone": phone})
            assert r.status_code == 200
        blocked = client.post("/api/v1/auth/phone/request-otp", json={"phone": phone})
    assert blocked.status_code == 429


# ─── Chat endpoint ────────────────────────────────────────────────────────────

def _wait_for(event, seconds=5.0):
    """L'envoi WhatsApp part dans un thread détaché : le test doit
    l'attendre explicitement, sinon il asserte avant que l'appel ait eu lieu."""
    assert event.wait(seconds), "l'envoi WhatsApp n'a pas eu lieu dans le délai imparti"


def test_otp_is_also_sent_over_whatsapp(client):
    import threading

    sent = threading.Event()
    calls = []

    def fake_whatsapp(message, destination, raw_id=None):
        calls.append((message, destination, threading.current_thread().name))
        sent.set()
        return True

    with patch.object(otp_service.sms_service, "send_sms", return_value=True) as mock_sms:
        with patch(
            "app.services.notifications.whatsapp_service.send_whatsapp",
            side_effect=fake_whatsapp,
        ):
            response = client.post("/api/v1/auth/phone/request-otp", json={"phone": "+22890123490"})
            assert response.status_code == 200
            _wait_for(sent)

    assert len(calls) == 1
    whatsapp_message, destination, thread_name = calls[0]
    assert destination == "+22890123490"
    # Même texte que le SMS : un seul code, deux canaux.
    assert whatsapp_message == mock_sms.call_args.args[2]
    assert re.search(r"\b\d{6}\b", whatsapp_message)
    # Hors du thread principal : la réponse HTTP ne doit pas attendre les
    # retries de la passerelle (voir _send_whatsapp_otp).
    assert thread_name != "MainThread"


def test_whatsapp_failure_does_not_break_the_otp_request(client):
    """Le SMS reste le canal de référence : une passerelle WhatsApp en panne
    ne doit pas empêcher de se connecter."""
    import threading

    attempted = threading.Event()

    def exploding_whatsapp(*args, **kwargs):
        attempted.set()
        raise RuntimeError("passerelle injoignable")

    with patch.object(otp_service.sms_service, "send_sms", return_value=True):
        with patch(
            "app.services.notifications.whatsapp_service.send_whatsapp",
            side_effect=exploding_whatsapp,
        ):
            response = client.post("/api/v1/auth/phone/request-otp", json={"phone": "+22890123491"})
            _wait_for(attempted)

    assert response.status_code == 200
    assert response.json()["expires_in"] == otp_service.OTP_TTL_SECONDS == 50


def test_whatsapp_is_not_attempted_for_an_invalid_number(client):
    """Le numéro est validé avant tout envoi : pas de code généré, donc rien
    à livrer sur aucun canal."""
    import threading

    sent = threading.Event()

    with patch.object(otp_service.sms_service, "send_sms", return_value=True) as mock_sms:
        with patch(
            "app.services.notifications.whatsapp_service.send_whatsapp",
            side_effect=lambda *a, **k: sent.set(),
        ):
            response = client.post("/api/v1/auth/phone/request-otp", json={"phone": "pas-un-numero"})

    assert response.status_code == 400
    mock_sms.assert_not_called()
    assert not sent.wait(0.5)


def test_rate_limited_request_sends_nothing_on_either_channel(client, monkeypatch):
    import threading

    monkeypatch.setattr(otp_service, "RESEND_MIN_SECONDS", 0)

    sent = threading.Event()
    phone = "+22890123492"

    with patch.object(otp_service.sms_service, "send_sms", return_value=True):
        with patch("app.services.notifications.whatsapp_service.send_whatsapp", return_value=True):
            for _ in range(otp_service.RATE_LIMIT_MAX_REQUESTS):
                assert client.post("/api/v1/auth/phone/request-otp", json={"phone": phone}).status_code == 200

    with patch.object(otp_service.sms_service, "send_sms", return_value=True) as mock_sms:
        with patch(
            "app.services.notifications.whatsapp_service.send_whatsapp",
            side_effect=lambda *a, **k: sent.set(),
        ):
            blocked = client.post("/api/v1/auth/phone/request-otp", json={"phone": phone})

    assert blocked.status_code == 429
    mock_sms.assert_not_called()
    assert not sent.wait(0.5)


# ─── Compte de démonstration pour la revue des stores ─────────────────────────
#
# Google Play exige des identifiants de test quand l'application est derrière
# une connexion. Pokou n'a pas de mot de passe — on n'entre qu'avec un code
# SMS, et un relecteur à Mountain View ne peut pas recevoir le SMS d'un numéro
# togolais. Un numéro déclaré reçoit donc un code FIXE, sans SMS.
#
# C'est une porte dérobée dans l'authentification. Ces tests vérifient
# qu'elle reste ÉTROITE : deux réglages exigés, correspondance exacte, et
# aucun effet sur le flux de tout le monde.

_REVIEW_PHONE = "+22890000000"
_REVIEW_CODE = "609785"


class _ReviewSettings:
    """Réglages où le compte de démonstration est configuré. Attributs posés
    explicitement, pas un MagicMock : un faux qui fabrique ses attributs
    rendrait VRAI tout réglage qu'on aurait oublié de nommer (voir
    test_push_status.py, où ce piège a masqué un échec)."""

    review_phone_numbers = _REVIEW_PHONE
    review_otp_code = _REVIEW_CODE
    sms_sender_id = "POKOU"


def _with_review_account():
    return patch.object(otp_service, "get_settings", return_value=_ReviewSettings())


def test_the_review_account_logs_in_with_a_fixed_code_and_no_sms(client):
    with _with_review_account(), patch.object(
        otp_service.sms_service, "send_sms", return_value=True
    ) as mock_sms, patch.object(otp_service, "_send_whatsapp_otp") as mock_whatsapp:
        requested = client.post("/api/v1/auth/phone/request-otp", json={"phone": _REVIEW_PHONE})
        assert requested.status_code == 200, requested.text

        # Aucun message ne part : le numéro n'appartient à personne, et s'il
        # finissait attribué à quelqu'un, il recevrait nos codes.
        mock_sms.assert_not_called()
        mock_whatsapp.assert_not_called()

        verified = client.post(
            "/api/v1/auth/phone/verify-otp", json={"phone": _REVIEW_PHONE, "code": _REVIEW_CODE}
        )

    assert verified.status_code == 200, verified.text
    assert "access_token" in verified.json()
    # Le compte porte son nom : sans ça, il ressemble à n'importe quel
    # utilisateur en production et personne ne sait lequel supprimer après la
    # revue.
    assert "démonstration" in verified.json()["user"]["full_name"]


def test_the_review_account_still_refuses_a_wrong_code(client):
    """Le code est prédéterminé, pas la vérification : on ne saute AUCUN
    contrôle, et c'est ce qui rend cette porte étroite."""
    with _with_review_account(), patch.object(
        otp_service.sms_service, "send_sms", return_value=True
    ), patch.object(otp_service, "_send_whatsapp_otp"):
        client.post("/api/v1/auth/phone/request-otp", json={"phone": _REVIEW_PHONE})
        refused = client.post(
            "/api/v1/auth/phone/verify-otp", json={"phone": _REVIEW_PHONE, "code": "000000"}
        )

    assert refused.status_code == 400


def test_the_fixed_code_opens_only_the_declared_number(client):
    """La correspondance est EXACTE : un autre numéro garde un code aléatoire
    et son SMS, même pendant que le compte de démonstration est configuré."""
    other = "+22890123456"
    with _with_review_account(), patch.object(
        otp_service.sms_service, "send_sms", return_value=True
    ) as mock_sms, patch.object(otp_service, "_send_whatsapp_otp"):
        client.post("/api/v1/auth/phone/request-otp", json={"phone": other})
        # Son SMS part bien, et ne contient PAS le code de démonstration.
        mock_sms.assert_called_once()
        assert _REVIEW_CODE not in mock_sms.call_args.args[2]

        refused = client.post(
            "/api/v1/auth/phone/verify-otp", json={"phone": other, "code": _REVIEW_CODE}
        )

    assert refused.status_code == 400


def test_without_the_code_setting_the_declared_number_behaves_normally(client):
    """Fail-closed : les DEUX réglages sont exigés. Une moitié de
    configuration oubliée n'ouvre pas la porte à moitié."""

    class _HalfConfigured:
        review_phone_numbers = _REVIEW_PHONE
        review_otp_code = ""
        sms_sender_id = "POKOU"

    with patch.object(otp_service, "get_settings", return_value=_HalfConfigured()), patch.object(
        otp_service.sms_service, "send_sms", return_value=True
    ) as mock_sms, patch.object(otp_service, "_send_whatsapp_otp"):
        client.post("/api/v1/auth/phone/request-otp", json={"phone": _REVIEW_PHONE})
        # Le SMS part : ce numéro n'a rien de particulier sans son code.
        mock_sms.assert_called_once()
        assert _REVIEW_CODE not in mock_sms.call_args.args[2]

        refused = client.post(
            "/api/v1/auth/phone/verify-otp", json={"phone": _REVIEW_PHONE, "code": _REVIEW_CODE}
        )

    assert refused.status_code == 400


def test_no_number_is_special_when_nothing_is_configured(client):
    """L'état par défaut du produit : aucun compte de démonstration.

    Les réglages sont ISOLÉS, comme dans les deux tests ci-dessus. Lus
    depuis l'environnement réel, ce test passait ou échouait selon le
    contenu du `.env` de la machine — et il a effectivement échoué le jour
    où ce fichier portait une configuration de revue de store. Un test qui
    dépend de la machine ne prouve rien sur le produit.
    """

    class _RienDeConfigure:
        review_phone_numbers = ""
        review_otp_code = ""

    with patch.object(otp_service, "get_settings", return_value=_RienDeConfigure()):
        assert otp_service.is_review_phone(_REVIEW_PHONE) is False
        assert otp_service.is_review_phone("+22890123456") is False


def test_the_review_code_lives_long_enough_for_a_review_session(client):
    """Les 5 minutes ordinaires sont trop courtes pour une revue de store :
    entre les captures d'écran et les formulaires, le code expire, et seules
    3 demandes sont permises par quart d'heure — un refus de publication
    pour une raison purement mécanique. Sans coût en sécurité : ce code est
    publié dans la console Play, sa durée de vie ne protège rien."""
    with _with_review_account(), patch.object(
        otp_service.sms_service, "send_sms", return_value=True
    ), patch.object(otp_service, "_send_whatsapp_otp"):
        response = client.post("/api/v1/auth/phone/request-otp", json={"phone": _REVIEW_PHONE})
        ordinary = client.post("/api/v1/auth/phone/request-otp", json={"phone": "+22890123456"})

    assert response.json()["expires_in"] == otp_service.REVIEW_OTP_TTL_MINUTES * 60
    # Et la durée ordinaire n'a pas bougé pour autant.
    assert ordinary.json()["expires_in"] == otp_service.OTP_TTL_SECONDS


# ─── Section 8.1 du cahier des charges ────────────────────────────────────────

def test_renvoi_refuse_avant_60_secondes(client):
    phone = "+22890000041"
    _request_otp_and_extract_code(client, phone=phone)
    with patch.object(otp_service.sms_service, "send_sms", return_value=True) as mock_sms:
        again = client.post("/api/v1/auth/phone/request-otp", json={"phone": phone})
    assert again.status_code == 429
    mock_sms.assert_not_called()


def test_cinq_codes_faux_verrouillent_le_numero(client):
    phone = "+22890000042"
    code = _request_otp_and_extract_code(client, phone=phone)
    messages = []
    for _ in range(4):
        r = client.post("/api/v1/auth/phone/verify-otp", json={"phone": phone, "code": "000000"})
        assert r.status_code == 400
        messages.append(r.json()["detail"])
    assert "4 essais" in messages[0] and "1 essai" in messages[-1]
    fifth = client.post("/api/v1/auth/phone/verify-otp", json={"phone": phone, "code": "000000"})
    assert fifth.status_code == 429
    # Même le BON code est refusé pendant le verrou.
    locked = client.post("/api/v1/auth/phone/verify-otp", json={"phone": phone, "code": code})
    assert locked.status_code == 429


def test_onboarding_tant_que_nom_et_conditions_manquent(client):
    phone = "+22890000043"
    code = _request_otp_and_extract_code(client, phone=phone)
    body = client.post("/api/v1/auth/phone/verify-otp", json={"phone": phone, "code": code}).json()
    headers = {"Authorization": f"Bearer {body['access_token']}"}
    assert body["user"]["needs_onboarding"] is True

    refused = client.post("/api/v1/auth/me/consents", json={"accept_terms": True}, headers=headers)
    assert refused.status_code == 422  # l'âge requis manque

    client.patch("/api/v1/auth/me", json={"full_name": "Afi"}, headers=headers)
    me = client.post(
        "/api/v1/auth/me/consents",
        json={"accept_terms": True, "age_confirmed": True, "consent_analytics": True},
        headers=headers,
    ).json()
    assert me["needs_onboarding"] is False
    assert me["consent_analytics"] is True and me["consent_marketing"] is False


def test_conditions_cochees_avec_le_numero(client):
    phone = "+22890000044"
    code = _request_otp_and_extract_code(client, phone=phone)
    body = client.post("/api/v1/auth/phone/verify-otp", json={
        "phone": phone, "code": code, "accept_terms": True, "age_confirmed": True, "consent_marketing": False,
    }).json()
    assert body["user"]["terms_accepted_at"] is not None
    # Reste le nom affiché : l'étape « Profil, avec Baba ».
    assert body["user"]["needs_onboarding"] is True
