"""SMS des codes : Twilio d'abord, NGH en secours."""
from types import SimpleNamespace
from unittest.mock import MagicMock, patch

from app.services.auth import otp_service
from app.services.notifications import sms_service


def _settings(**overrides):
    base = dict(
        twilio_account_sid="AC123", twilio_auth_token="secret",
        twilio_sms_from="POKOU", twilio_messaging_service_sid="",
    )
    base.update(overrides)
    return SimpleNamespace(**base)


def _response(status, body):
    response = MagicMock(status_code=status)
    response.json.return_value = body
    return response


def test_twilio_envoie_le_code_au_format_e164(monkeypatch):
    monkeypatch.setattr(sms_service, "get_settings", lambda: _settings())
    with patch.object(sms_service.httpx, "post", return_value=_response(201, {"sid": "SM1"})) as post:
        assert sms_service.send_sms(MagicMock(), "+22890000000", "Votre code", "POKOU") is True
    url = post.call_args.args[0]
    assert url == "https://api.twilio.com/2010-04-01/Accounts/AC123/Messages.json"
    assert post.call_args.kwargs["data"] == {"To": "+22890000000", "Body": "Votre code", "From": "POKOU"}
    assert post.call_args.kwargs["auth"] == ("AC123", "secret")


def test_service_de_messagerie_a_la_place_de_l_expediteur(monkeypatch):
    monkeypatch.setattr(sms_service, "get_settings", lambda: _settings(twilio_sms_from="", twilio_messaging_service_sid="MG9"))
    with patch.object(sms_service.httpx, "post", return_value=_response(201, {"sid": "SM1"})) as post:
        sms_service.send_sms(MagicMock(), "+22890000000", "x", "POKOU")
    assert post.call_args.kwargs["data"]["MessagingServiceSid"] == "MG9"
    assert "From" not in post.call_args.kwargs["data"]


def test_refus_twilio_bascule_sur_ngh(monkeypatch):
    monkeypatch.setattr(sms_service, "get_settings", lambda: _settings())
    with patch.object(sms_service.httpx, "post", return_value=_response(400, {"code": 21211, "message": "invalid"})), \
         patch.object(sms_service, "_send_via_ngh", return_value=True) as ngh:
        assert sms_service.send_sms(MagicMock(), "+22890000000", "x", "POKOU") is True
    ngh.assert_called_once()


def test_sans_twilio_c_est_ngh(monkeypatch):
    monkeypatch.setattr(sms_service, "get_settings", lambda: _settings(twilio_account_sid=""))
    with patch.object(sms_service, "_send_via_ngh", return_value=False) as ngh, \
         patch.object(sms_service, "_send_via_twilio") as twilio:
        assert sms_service.send_sms(MagicMock(), "+22890000000", "x", "POKOU") is False
    twilio.assert_not_called()
    ngh.assert_called_once()


def test_le_code_expire_en_50_secondes():
    assert otp_service.OTP_TTL_SECONDS == 50
    assert otp_service.RESEND_MIN_SECONDS == 50
    assert "50 secondes" in otp_service._otp_message("123456")
