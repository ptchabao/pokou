"""Retours des testeurs : la France pays de test, les officines de
démonstration, les numéros d'urgence par pays, « Recommencer » la
candidature coursier, et les paiements simulés (jamais au Togo ni en CI)."""
import re
from datetime import datetime
from unittest.mock import patch

from app.core.countries import country_config, simulated_payments_enabled
from app.models import CourierProfile, CourierWalletCheck, MarketplacePayment, Pharmacy, SystemSetting
from app.services.auth import otp_service
from app.services.honam import demo
from app.services.honam.emergency import parse_number, parse_others
from tests.test_honam import (  # noqa: F401  (fixtures réutilisées)
    TestingSessionLocal,
    _pharmacy,
    _signup,
    client,
    stub_mobile_money,
)

_FR = iter(range(10, 99))


def _signup_fr(client):
    phone = f"+336123456{next(_FR)}"
    with patch.object(otp_service.sms_service, "send_sms", return_value=True) as send:
        client.post("/api/v1/auth/phone/request-otp", json={"phone": phone})
    code = re.search(r"\b(\d{6})\b", send.call_args.args[2]).group(1)
    body = client.post("/api/v1/auth/phone/verify-otp", json={"phone": phone, "code": code}).json()
    client.cookies.clear()
    return {"Authorization": f"Bearer {body['access_token']}"}, body["user"]["id"]


# ── Pays de test ─────────────────────────────────────────────────────────


def test_la_france_est_un_pays_de_test_aux_tarifs_du_togo(client):
    with TestingSessionLocal() as db:
        fr = country_config(db, "FR")
        tg = country_config(db, "TG")
        assert fr["test_only"] is True and fr["currency"] == "XOF"
        assert "honam" in fr["modules"] and "Paris" in fr["honam_cities"]
        for key in ("delivery_price", "pharmacy_monthly_price", "pharmacy_yearly_price", "vat_rate"):
            assert fr[key] == tg[key]
        assert tg["test_only"] is False and tg["discover_video_url"] is None
        assert simulated_payments_enabled(db, "FR") is True
        # Jamais au Togo ni en Côte d'Ivoire, même si un réglage le demande.
        db.add(SystemSetting(key="country.CI", value='{"test_only": true, "test_payments": true}'))
        db.commit()
        assert simulated_payments_enabled(db, "TG") is False
        assert simulated_payments_enabled(db, "CI") is False


def test_la_console_coupe_le_pays_de_test(client):
    with TestingSessionLocal() as db:
        db.add(SystemSetting(key="country.FR", value='{"test_only": false}'))
        db.commit()
        assert simulated_payments_enabled(db, "FR") is False


# ── Urgences ─────────────────────────────────────────────────────────────


def test_lecture_des_valeurs_du_tableur():
    assert parse_number("170 (ou 110, 111)") == {"number": "170", "alternatives": ["110", "111"], "note": None}
    assert parse_number("10 111 (10 112 depuis un mobile)") == {
        "number": "10111", "alternatives": ["10112"], "note": "depuis un mobile"}
    assert parse_number("'+269 772 03 73")["number"] == "+2697720373"
    assert parse_number("117 (ou 84 911, privé)") == {"number": "117", "alternatives": ["84911"], "note": "privé"}
    assert parse_number("") is None and parse_number("—") is None
    others = parse_others("Protection civile (ANPC) : 170 · Police depuis un mobile : 161 (selon le Canada)")
    assert others == [
        {"label": "Protection civile (ANPC)", "number": "170", "alternatives": [], "note": None},
        {"label": "Police depuis un mobile", "number": "161", "alternatives": [], "note": "selon le Canada"},
    ]


def test_urgences_du_togo_selon_le_numero(client):
    patient, _ = _signup(client)
    body = client.get("/api/v1/honam/config", headers=patient).json()
    numbers = {s["key"]: s for s in body["emergency"]["services"]}
    assert {k: v["number"] for k, v in numbers.items()} == {
        "police": "117", "pompiers": "118", "samu": "8200", "gendarmerie": "172"}
    assert body["emergency"]["reliability"] == "medium"
    assert any(o["number"] == "1014" for o in body["emergency"]["others"])
    # La forme d'avant reste, pour les anciennes versions de l'app.
    assert body["emergency_numbers"] == {"police": "117", "pompiers": "118", "samu": "8200"}


def test_urgences_de_cote_d_ivoire_et_d_un_autre_pays(client):
    patient, _ = _signup(client)
    ci = client.get("/api/v1/honam/emergency?country=CI", headers=patient).json()
    police = next(s for s in ci["services"] if s["key"] == "police")
    assert police["number"] == "170" and police["alternatives"] == ["110", "111"]
    assert ci["reliability"] == "high"
    guinee = client.get("/api/v1/honam/emergency?country=gn", headers=patient).json()
    assert guinee["reliability"] == "low" and guinee["reliability_label"] == "Faible"
    inconnu = client.get("/api/v1/honam/emergency?country=US", headers=patient).json()
    assert inconnu["services"] == []
    assert client.get("/api/v1/honam/emergency?country=FRA", headers=patient).status_code == 422


def test_urgences_francaises_pour_un_numero_francais(client):
    testeur, _ = _signup_fr(client)
    body = client.get("/api/v1/honam/config", headers=testeur).json()
    numbers = {s["key"]: s["number"] for s in body["emergency"]["services"]}
    assert numbers["samu"] == "15" and numbers["unique"] == "112"
    assert body["test_country"] is True


def test_la_console_surcharge_un_numero(client):
    with TestingSessionLocal() as db:
        db.query(SystemSetting).filter(SystemSetting.key == "country.TG").delete()
        db.add(SystemSetting(key="country.TG", value='{"emergency_numbers": {"samu": "1500"}}'))
        db.commit()
    patient, _ = _signup(client)
    samu = next(s for s in client.get("/api/v1/honam/emergency", headers=patient).json()["services"]
                if s["key"] == "samu")
    assert samu["number"] == "1500" and samu["alternatives"] == ["8200"]


# ── Officines de démonstration ───────────────────────────────────────────


def test_le_seed_cree_les_officines_demo_une_seule_fois(client):
    with TestingSessionLocal() as db:
        assert demo.seed_demo_pharmacies(db) == 3
        db.commit()
        assert demo.seed_demo_pharmacies(db) == 0
        rows = db.query(Pharmacy).filter(Pharmacy.is_demo.is_(True)).all()
        assert len(rows) == 3 and all("Démo" in p.name for p in rows)
        assert {p.country for p in rows} == {"TG", "FR"}
        assert sum(p.is_on_duty for p in rows) == 1
        assert all(p.credit_balance > 0 and p.subscription_until > datetime.utcnow() for p in rows)


def test_les_officines_demo_ne_se_montrent_que_dans_le_pays_de_test(client):
    with TestingSessionLocal() as db:
        demo.seed_demo_pharmacies(db)
        db.commit()
    togolais, _ = _signup(client)
    testeur, _ = _signup_fr(client)
    # Togo : pays de lancement, réglage fermé par défaut.
    assert client.get("/api/v1/honam/pharmacies", headers=togolais).json()["items"] == []
    names = [p["name"] for p in client.get("/api/v1/honam/pharmacies", headers=testeur).json()["items"]]
    assert sorted(names) == ["Pharmacie Démo Bastille", "Pharmacie Démo Château Rouge"]
    on_duty = client.get("/api/v1/honam/pharmacies?on_duty=true", headers=testeur).json()["items"]
    assert [p["name"] for p in on_duty] == ["Pharmacie Démo Bastille"]
    # La console les coupe.
    with TestingSessionLocal() as db:
        db.add(SystemSetting(key="country.FR", value='{"honam_demo_pharmacies": false}'))
        db.commit()
    assert client.get("/api/v1/honam/pharmacies", headers=testeur).json()["items"] == []


def test_retirer_les_officines_demo(client):
    with TestingSessionLocal() as db:
        demo.seed_demo_pharmacies(db)
        db.commit()
        assert demo.remove_demo_pharmacies(db) == {"removed": 3, "excluded": 0}
        # Le seed ne les recrée pas.
        assert demo.seed_demo_pharmacies(db) == 0
        assert db.query(Pharmacy).count() == 0


# ── Coursier : « Recommencer » ───────────────────────────────────────────


def test_recommencer_efface_la_candidature_en_attente(client):
    headers, user_id = _signup(client)
    client.post("/api/v1/honam/courier/join", json={
        "zones": "Bè", "wallet_phone": "+22890777777", "accept_rules": True}, headers=headers)
    with TestingSessionLocal() as db:
        db.add(CourierWalletCheck(user_id=user_id, phone="+22890777777"))
        db.commit()
    reset = client.delete("/api/v1/honam/courier/application", headers=headers)
    assert reset.status_code == 200 and reset.json()["had_application"] is True
    with TestingSessionLocal() as db:
        assert db.query(CourierProfile).count() == 0
        assert db.query(CourierWalletCheck).count() == 0
    # Sans candidature : rien à effacer, pas d'erreur.
    assert client.delete("/api/v1/honam/courier/application", headers=headers).json()["had_application"] is False


def test_recommencer_ne_touche_jamais_un_coursier_valide(client):
    from tests.test_honam import _courier

    headers, _ = _signup(client)
    _courier(client, headers)
    assert client.delete("/api/v1/honam/courier/application", headers=headers).status_code == 409
    with TestingSessionLocal() as db:
        assert db.query(CourierProfile).one().status == "TRIAL"


# ── Officine : montants et souscription en pays de test ──────────────────


def test_formules_avec_montants_et_souscription_simulee_en_pays_de_test(client, stub_mobile_money):
    pharmacist, pid = _signup_fr(client)
    pharmacy_id = _pharmacy(pid)
    with TestingSessionLocal() as db:
        db.query(Pharmacy).filter(Pharmacy.id == pharmacy_id).update(
            {"country": "FR", "subscription_plan": None, "subscription_until": None})
        db.commit()
    me = client.get("/api/v1/honam/pharmacy/me", headers=pharmacist).json()
    assert me["subscription"]["prices_ht"] == {"WETRI": 5000, "EPE": 50000}
    assert me["subscription"]["vat_rate"] == 0.18
    paid = client.post("/api/v1/honam/pharmacy/subscribe", json={"plan": "EPE"}, headers=pharmacist).json()
    assert paid["test_mode"] is True and paid["status"] == "confirmed" and paid["payment_url"] is None
    assert paid["amount"] == 59000
    stub_mobile_money.create_order.assert_not_called()
    me = client.get("/api/v1/honam/pharmacy/me", headers=pharmacist).json()
    assert me["subscription"]["plan"] == "EPE" and me["subscription"]["until"]


def test_au_togo_la_souscription_passe_toujours_par_mobile_money(client, stub_mobile_money):
    pharmacist, pid = _signup(client)
    _pharmacy(pid)
    paid = client.post("/api/v1/honam/pharmacy/subscribe", json={"plan": "WETRI"}, headers=pharmacist).json()
    assert paid["test_mode"] is False and paid["status"] == "pending" and paid["payment_url"]
    stub_mobile_money.create_order.assert_called_once()
    with TestingSessionLocal() as db:
        assert db.query(MarketplacePayment).one().status == "PENDING"
