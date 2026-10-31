"""Pokou Business — bots d'entreprise facturés au message.

Le parcours entier : une entreprise s'inscrit en bac à sable, crée un bot
et une clé de test, n'écrit qu'à ses numéros de test ; puis son dossier
est approuvé, elle recharge son crédit et écrit en production — au tarif
« service » dans la fenêtre de 24 h, au tarif « initié » au-delà.
"""
import hashlib
import hmac
import json
import re
from datetime import datetime, timedelta
from unittest.mock import patch

import httpx
import pytest
from fastapi.testclient import TestClient
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker

from app.core.database import Base, get_db
from app.main import app
from app.models import DirectMessage, User, UserRole
from app.models.business import Bot, Invoice, LedgerEntry, BusinessOrganization, WebhookDelivery
from app.services.auth import otp_service
from app.services.marketplace.marketplace_monetization_service import confirm_payment
from app.services.business import billing, webhooks
from tests.helpers import bearer_for_email

TEST_DATABASE_URL = "sqlite:///./test_pokou_business.db"
engine = create_engine(TEST_DATABASE_URL, connect_args={"check_same_thread": False})
TestingSessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)


def override_get_db():
    db = TestingSessionLocal()
    try:
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
    else:
        app.dependency_overrides.pop(get_db, None)
    Base.metadata.drop_all(bind=engine)


def _signup(client, phone, name=None):
    with patch.object(otp_service.sms_service, "send_sms", return_value=True) as mock_send:
        client.post("/api/v1/auth/phone/request-otp", json={"phone": phone})
    code = re.search(r"\b(\d{6})\b", mock_send.call_args.args[2]).group(1)
    body = client.post("/api/v1/auth/phone/verify-otp", json={"phone": phone, "code": code}).json()
    headers = {"Authorization": f"Bearer {body['access_token']}"}
    if name:
        client.put("/api/v1/users/me/profile", json={"full_name": name}, headers=headers)
    return headers, body["user"]["id"]


def _admin(client):
    db = TestingSessionLocal()
    try:
        db.add(User(email="equipe@example.com", role=UserRole.ADMIN))
        db.commit()
    finally:
        db.close()
    return bearer_for_email(TestingSessionLocal, "equipe@example.com")


def _org_et_bot(client, owner):
    org = client.post("/api/v1/business/organizations", json={"name": "Boutique Akwaba"}, headers=owner).json()
    bot = client.post(
        f"/api/v1/business/organizations/{org['id']}/bots",
        json={"name": "Akwaba Service", "handle": "akwaba"},
        headers=owner,
    ).json()
    return org, bot


def _cle(client, owner, org, bot, mode="TEST"):
    return client.post(
        f"/api/v1/business/organizations/{org['id']}/bots/{bot['id']}/keys",
        json={"name": "serveur", "mode": mode},
        headers=owner,
    )


def _envoyer(client, cle, to, **contenu):
    return client.post("/api/v1/bot/v1/messages", json={"to": to, **contenu}, headers={"Authorization": f"Bearer {cle}"})


def _approuver(client, owner, admin, org):
    rccm = client.post("/api/v1/media/upload", data={"message_type": "IMAGE"}, files={"file": ("rccm.jpg", b"\xff\xd8\xff\xd9", "image/jpeg")}, headers=owner).json()
    piece = client.post("/api/v1/media/upload", data={"message_type": "IMAGE"}, files={"file": ("cni.jpg", b"\xff\xd8\xff\xd9", "image/jpeg")}, headers=owner).json()
    soumis = client.post(
        f"/api/v1/business/organizations/{org['id']}/verification",
        json={
            "legal_name": "Akwaba SARL",
            "rccm": "TG-LOM-2024-B-1234",
            "nif": "1000123456",
            "address": "Boulevard du 13 Janvier, Lomé",
            "rccm_media_id": rccm["id"],
            "identity_media_id": piece["id"],
        },
        headers=owner,
    )
    assert soumis.status_code == 200, soumis.text
    decision = client.put(
        f"/api/v1/admin/business/organizations/{org['id']}/verification",
        json={"approved": True, "note": "RCCM et NIF concordants"},
        headers=admin,
    )
    assert decision.status_code == 200, decision.text


def _crediter(org_id, montant):
    db = TestingSessionLocal()
    try:
        org = db.query(BusinessOrganization).filter(BusinessOrganization.id == org_id).one()
        billing.crediter(db, org, montant, reference="test")
        db.commit()
    finally:
        db.close()


# ── Bac à sable ───────────────────────────────────────────────────────────


def test_une_entreprise_commence_en_bac_a_sable(client):
    owner, _ = _signup(client, "+22890100001")
    org, bot = _org_et_bot(client, owner)
    assert org["status"] == "SANDBOX"
    assert org["my_role"] == "OWNER"
    assert len(bot["webhook_secret"]) == 64

    cle = _cle(client, owner, org, bot, "TEST")
    assert cle.status_code == 201
    assert cle.json()["key"].startswith("vb_test_")
    # La production attend la vérification.
    assert _cle(client, owner, org, bot, "LIVE").status_code == 409


def test_en_bac_a_sable_un_bot_n_ecrit_qu_aux_numeros_de_test(client):
    owner, _ = _signup(client, "+22890100002")
    _, testeur_id = _signup(client, "+22890100003")
    _, inconnu_id = _signup(client, "+22890100004")
    org, bot = _org_et_bot(client, owner)
    cle = _cle(client, owner, org, bot).json()["key"]
    client.post(f"/api/v1/business/organizations/{org['id']}/test-numbers", json={"phone": "+22890100003"}, headers=owner)

    assert _envoyer(client, cle, inconnu_id, text="Bonjour").status_code == 403
    envoye = _envoyer(client, cle, testeur_id, text="Bonjour")
    assert envoye.status_code == 201, envoye.text
    assert envoye.json()["price"] == 0
    assert envoye.json()["mode"] == "TEST"
    with TestingSessionLocal() as db:
        message = db.query(DirectMessage).filter(DirectMessage.recipient_id == testeur_id).one()
        assert message.sender_id == bot["user_id"]


def test_une_cle_inconnue_ou_revoquee_est_refusee(client):
    owner, _ = _signup(client, "+22890100005")
    org, bot = _org_et_bot(client, owner)
    cle = _cle(client, owner, org, bot).json()
    assert _envoyer(client, "vb_test_inventee", 1, text="x").status_code == 401
    client.delete(f"/api/v1/business/organizations/{org['id']}/bots/{bot['id']}/keys/{cle['id']}", headers=owner)
    assert client.get("/api/v1/bot/v1/me", headers={"Authorization": f"Bearer {cle['key']}"}).status_code == 401


def test_ecrire_a_un_bot_le_rend_au_developpeur_par_webhook(client):
    owner, _ = _signup(client, "+22890100006")
    testeur, testeur_id = _signup(client, "+22890100007", name="Kossi")
    org, bot = _org_et_bot(client, owner)
    with patch("app.utils.net.is_publicly_routable_url", return_value=True):
        regle = client.patch(
            f"/api/v1/business/organizations/{org['id']}/bots/{bot['id']}",
            json={"webhook_url": "https://bots.example.com/pokou"},
            headers=owner,
        )
    assert regle.json()["webhook_url"] == "https://bots.example.com/pokou"
    client.post(f"/api/v1/business/organizations/{org['id']}/test-numbers", json={"phone": "+22890100007"}, headers=owner)
    cle = _cle(client, owner, org, bot).json()["key"]
    menu = _envoyer(client, cle, testeur_id, text="Que voulez-vous ?", buttons=[{"id": "commande", "title": "Commander"}]).json()

    reponse = client.post(
        "/api/v1/messages",
        json={"recipient_id": bot["user_id"], "content": "Commander", "reply_to_id": menu["id"]},
        headers=testeur,
    )
    assert reponse.status_code == 200, reponse.text
    with TestingSessionLocal() as db:
        evt = db.query(WebhookDelivery).one()
    assert evt.event_type == "message.received"
    assert evt.payload["data"]["from"] == {"user_id": testeur_id, "name": "Kossi"}
    assert evt.payload["data"]["button_reply"] == {"id": "commande", "title": "Commander"}
    # Le développeur n'apprend pas le numéro de la personne.
    assert "+22890100007" not in json.dumps(evt.payload)


def test_on_n_ecrit_pas_a_un_bot_de_bac_a_sable_sans_etre_numero_de_test(client):
    owner, _ = _signup(client, "+22890100008")
    inconnu, _ = _signup(client, "+22890100009")
    _, bot = _org_et_bot(client, owner)
    reponse = client.post("/api/v1/messages", json={"recipient_id": bot["user_id"], "content": "Salut"}, headers=inconnu)
    assert reponse.status_code == 403


# ── Production et facturation ─────────────────────────────────────────────


def test_production_consentement_fenetre_de_24h_et_debit(client):
    owner, _ = _signup(client, "+22890100010")
    client_pokou, client_id = _signup(client, "+22890100011")
    admin = _admin(client)
    org, bot = _org_et_bot(client, owner)
    _approuver(client, owner, admin, org)
    with TestingSessionLocal() as db:
        assert db.query(User).filter(User.id == bot["user_id"]).one().is_verified is True
    cle = _cle(client, owner, org, bot, "LIVE").json()["key"]

    # Personne ne lui a écrit : pas de démarchage.
    assert _envoyer(client, cle, client_id, text="Promo !").status_code == 403

    client.post("/api/v1/messages", json={"recipient_id": bot["user_id"], "content": "Bonjour"}, headers=client_pokou)
    # Solde vide : 402, et rien n'est envoyé.
    assert _envoyer(client, cle, client_id, text="Bonjour à vous").status_code == 402
    with TestingSessionLocal() as db:
        assert db.query(DirectMessage).filter(DirectMessage.sender_id == bot["user_id"]).count() == 0

    _crediter(org["id"], 100)
    service = _envoyer(client, cle, client_id, text="Bonjour à vous")
    assert service.status_code == 201, service.text
    assert (service.json()["category"], service.json()["price"]) == ("SERVICE", 5)

    # 25 h plus tard, la fenêtre est fermée : tarif « initié ».
    with TestingSessionLocal() as db:
        db.query(DirectMessage).filter(DirectMessage.sender_id == client_id).update(
            {DirectMessage.created_at: datetime.utcnow() - timedelta(hours=25)}
        )
        db.commit()
    initie = _envoyer(client, cle, client_id, text="Votre commande est prête")
    assert (initie.json()["category"], initie.json()["price"]) == ("INITIATED", 25)

    with TestingSessionLocal() as db:
        org_db = db.query(BusinessOrganization).filter(BusinessOrganization.id == org["id"]).one()
        assert org_db.credit_balance == 100 - 5 - 25
        lignes = db.query(LedgerEntry).filter(LedgerEntry.organization_id == org["id"]).order_by(LedgerEntry.id).all()
        assert [e.amount for e in lignes] == [100, -5, -25]
        assert lignes[-1].balance_after == 70


def test_la_recharge_credite_a_la_confirmation_et_emet_une_facture(client):
    owner, _ = _signup(client, "+22890100012")
    org, _ = _org_et_bot(client, owner)
    with patch("app.services.payments.semoa_client.create_order", return_value={"order_reference": "ref-vb-1", "payment_url": "https://pay.example/1"}):
        reponse = client.post(f"/api/v1/business/organizations/{org['id']}/recharges", json={"amount": 5000}, headers=owner)
    assert reponse.status_code == 201, reponse.text
    assert reponse.json()["payment_url"] == "https://pay.example/1"
    with TestingSessionLocal() as db:
        assert db.query(BusinessOrganization).filter(BusinessOrganization.id == org["id"]).one().credit_balance == 0
        confirm_payment(db, "ref-vb-1")
        confirm_payment(db, "ref-vb-1")  # la passerelle rappelle : sans effet
    with TestingSessionLocal() as db:
        assert db.query(BusinessOrganization).filter(BusinessOrganization.id == org["id"]).one().credit_balance == 5000
        facture = db.query(Invoice).one()
        assert (facture.kind, facture.status, facture.total) == ("RECHARGE", "PAID", 5000)
        assert re.match(r"^VB-\d{4}-000001$", facture.number)

    pdf = client.get(f"/api/v1/business/organizations/{org['id']}/invoices/{facture.id}/pdf", headers=owner)
    assert pdf.status_code == 200
    assert pdf.content.startswith(b"%PDF")


def test_postpaye_facture_mensuelle_echeance_suspension_et_reglement(client):
    owner, _ = _signup(client, "+22890100013")
    client_pokou, client_id = _signup(client, "+22890100014")
    admin = _admin(client)
    org, bot = _org_et_bot(client, owner)
    _approuver(client, owner, admin, org)
    regle = client.put(
        f"/api/v1/admin/business/organizations/{org['id']}/billing",
        json={"billing_mode": "POSTPAID", "postpaid_limit": 30, "payment_terms_days": 10},
        headers=admin,
    )
    assert regle.status_code == 200, regle.text
    cle = _cle(client, owner, org, bot, "LIVE").json()["key"]
    client.post("/api/v1/messages", json={"recipient_id": bot["user_id"], "content": "Bonjour"}, headers=client_pokou)

    for _ in range(6):
        assert _envoyer(client, cle, client_id, text="Suivi").status_code == 201
    # 6 × 5 = 30 : le plafond est atteint.
    assert _envoyer(client, cle, client_id, text="De trop").status_code == 402

    mois_prochain = billing.debut_du_mois(datetime.utcnow()) + timedelta(days=32)
    with TestingSessionLocal() as db:
        bilan = billing.cycle_mensuel(db, now=mois_prochain)
        db.commit()
        assert bilan["invoices_issued"] == 1
        facture = db.query(Invoice).one()
        assert (facture.kind, facture.status, facture.total) == ("MONTHLY", "ISSUED", 30)
        assert facture.lines == [{"label": "Messages de service (réponse sous 24 h)", "quantity": 6, "unit_price": 5, "amount": 30}]
        # Relancé, le cycle ne refacture rien.
        assert billing.cycle_mensuel(db, now=mois_prochain)["invoices_issued"] == 0

        bilan = billing.cycle_mensuel(db, now=mois_prochain + timedelta(days=11))
        db.commit()
        assert bilan["organizations_suspended"] == 1
        facture_id = facture.id

    assert _envoyer(client, cle, client_id, text="Suspendu ?").status_code == 403

    with patch("app.services.payments.semoa_client.create_order", return_value={"order_reference": "ref-vb-2", "payment_url": "https://pay.example/2"}):
        assert client.post(f"/api/v1/business/organizations/{org['id']}/invoices/{facture_id}/pay", headers=owner).status_code == 201
    with TestingSessionLocal() as db:
        confirm_payment(db, "ref-vb-2")
    with TestingSessionLocal() as db:
        assert db.query(Invoice).filter(Invoice.id == facture_id).one().status == "PAID"
        assert db.query(BusinessOrganization).filter(BusinessOrganization.id == org["id"]).one().status == "VERIFIED"


# ── Rôles ─────────────────────────────────────────────────────────────────


def test_les_roles_bornent_ce_que_chacun_fait(client):
    owner, _ = _signup(client, "+22890100015")
    dev, _ = _signup(client, "+22890100016")
    etranger, _ = _signup(client, "+22890100017")
    org, _ = _org_et_bot(client, owner)
    client.post(f"/api/v1/business/organizations/{org['id']}/members", json={"phone": "+22890100016", "role": "DEVELOPER"}, headers=owner)

    assert client.get(f"/api/v1/business/organizations/{org['id']}/bots", headers=dev).status_code == 200
    assert client.get(f"/api/v1/business/organizations/{org['id']}/billing", headers=dev).status_code == 403
    # Non-membre : 404, l'entreprise n'existe pas pour lui.
    assert client.get(f"/api/v1/business/organizations/{org['id']}", headers=etranger).status_code == 404


def test_les_pieces_du_dossier_sont_reservees_a_l_equipe(client):
    owner, _ = _signup(client, "+22890100018")
    curieux, _ = _signup(client, "+22890100019")
    admin = _admin(client)
    org, _ = _org_et_bot(client, owner)
    _approuver(client, owner, admin, org)
    with TestingSessionLocal() as db:
        media_id = db.query(BusinessOrganization).filter(BusinessOrganization.id == org["id"]).one().rccm_media_id
    assert client.get(f"/api/v1/media/{media_id}", headers=curieux).status_code == 404


# ── Webhooks ──────────────────────────────────────────────────────────────


def test_le_webhook_est_signe_horodate_et_relance(client):
    owner, _ = _signup(client, "+22890100020")
    org, bot = _org_et_bot(client, owner)
    secret = bot["webhook_secret"]
    with TestingSessionLocal() as db:
        bot_db = db.query(Bot).filter(Bot.id == bot["id"]).one()
        bot_db.webhook_url = "https://bots.example.com/pokou"
        webhooks.mettre_en_file(db, bot_db, "ping", {"message": "test"})
        db.commit()

    recus = []

    def premiere_fois_en_panne(request: httpx.Request):
        recus.append(request)
        return httpx.Response(500 if len(recus) == 1 else 200)

    with patch("app.services.business.webhooks.is_publicly_routable_url", return_value=True):
        with TestingSessionLocal() as db:
            transport = httpx.Client(transport=httpx.MockTransport(premiere_fois_en_panne))
            assert webhooks.remettre_en_attente(db, client=transport) == {"delivered": 0, "retried": 1, "failed": 0}
            evt = db.query(WebhookDelivery).one()
            assert evt.next_attempt_at > datetime.utcnow()
            plus_tard = datetime.utcnow() + timedelta(minutes=1)
            assert webhooks.remettre_en_attente(db, now=plus_tard, client=transport)["delivered"] == 1

    requete = recus[-1]
    entete = dict(part.split("=", 1) for part in requete.headers["X-Pokou-Signature"].split(","))
    attendu = hmac.new(secret.encode(), f"{entete['t']}.".encode() + requete.content, hashlib.sha256).hexdigest()
    assert hmac.compare_digest(entete["v1"], attendu)
    assert requete.headers["X-Pokou-Event"] == "ping"


def test_l_annuaire_ne_montre_que_les_bots_verifies(client):
    owner, _ = _signup(client, "+22890100021")
    lecteur, _ = _signup(client, "+22890100022")
    admin = _admin(client)
    org, bot = _org_et_bot(client, owner)
    assert client.get("/api/v1/bots/search", params={"q": "akwaba"}, headers=lecteur).json()["items"] == []
    assert client.get("/api/v1/bots/akwaba", headers=lecteur).status_code == 404
    _approuver(client, owner, admin, org)
    trouves = client.get("/api/v1/bots/search", params={"q": "akwaba"}, headers=lecteur).json()["items"]
    assert [b["handle"] for b in trouves] == ["akwaba"]
    assert trouves[0]["is_verified"] is True
    assert client.get("/api/v1/bots/akwaba", headers=lecteur).json()["user_id"] == bot["user_id"]
