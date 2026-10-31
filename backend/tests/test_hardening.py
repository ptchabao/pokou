"""Trois failles corrigées avant la prochaine mise en production de Pokou.

1. Les médias d'une chaîne PRIVÉE (logo, images publiées) étaient lisibles de
   tout utilisateur connecté : `media._can_access` accordait l'accès à tout ce
   qui appartenait à une chaîne, avant même que les chaînes privées existent.
2. Voter dans le sondage d'une chaîne privée, ou le lire, ne demandait pas
   l'abonnement : l'identifiant du sondage suffisait.
3. `PUT /marketplace/verification/{id}` accordait un badge vendeur PERMANENT
   sans exiger de paiement confirmé, contrairement à la route d'administration.

On teste ce qui SORT (le code HTTP vu par l'étranger), pas l'intention du code.
"""
import re
from unittest.mock import patch

import pytest
from fastapi.testclient import TestClient
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker

from app.core.database import Base, get_db
from app.main import app
from app.models import User
from app.services.auth import otp_service
from tests.helpers import bearer_for_email

engine = create_engine("sqlite:///./test_pokou_hardening.db", connect_args={"check_same_thread": False})
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
    else:
        app.dependency_overrides.pop(get_db, None)
    Base.metadata.drop_all(bind=engine)


def _signup(client, phone):
    with patch.object(otp_service.sms_service, "send_sms", return_value=True) as mock_send:
        client.post("/api/v1/auth/phone/request-otp", json={"phone": phone})
    code = re.search(r"\b(\d{6})\b", mock_send.call_args.args[2]).group(1)
    body = client.post("/api/v1/auth/phone/verify-otp", json={"phone": phone, "code": code}).json()
    return {"Authorization": f"Bearer {body['access_token']}"}, body["user"]["id"]


def _upload(client, headers):
    return client.post(
        "/api/v1/media/upload",
        data={"message_type": "IMAGE"},
        files={"file": ("photo.jpg", b"des-octets", "image/jpeg")},
        headers=headers,
    ).json()["id"]


def _private_channel_with_media_and_poll(client, owner):
    channel = client.post(
        "/api/v1/channels", json={"name": "Prix grossistes", "is_private": True}, headers=owner
    ).json()
    logo_id = _upload(client, owner)
    client.patch(f"/api/v1/channels/{channel['id']}", json={"avatar_media_id": logo_id}, headers=owner)
    image_id = _upload(client, owner)
    client.post(
        f"/api/v1/channels/{channel['id']}/posts",
        json={"text_content": "Prix du jour", "media_asset_id": image_id},
        headers=owner,
    )
    poll_post = client.post(
        f"/api/v1/channels/{channel['id']}/posts",
        json={"poll": {"question": "On baisse ?", "options": ["Oui", "Non"]}},
        headers=owner,
    ).json()
    return channel, logo_id, image_id, poll_post


def test_les_medias_d_une_chaine_privee_sont_introuvables_pour_un_etranger(client):
    owner, _ = _signup(client, "+22897700001")
    stranger, _ = _signup(client, "+22897700002")
    channel, logo_id, image_id, _ = _private_channel_with_media_and_poll(client, owner)

    for media_id in (logo_id, image_id):
        assert client.get(f"/api/v1/media/{media_id}", headers=stranger).status_code == 404
        assert client.get(f"/api/v1/media/{media_id}", headers=owner).status_code == 200


def test_un_abonne_lit_les_medias_d_une_chaine_privee(client):
    owner, _ = _signup(client, "+22897700003")
    member, _ = _signup(client, "+22897700004")
    channel, logo_id, image_id, _ = _private_channel_with_media_and_poll(client, owner)
    code = channel["invite_code"]
    assert code, "le propriétaire doit disposer du lien d'une chaîne privée"
    assert client.post(f"/api/v1/channels/invite/{code}/join", headers=member).status_code == 200

    for media_id in (logo_id, image_id):
        assert client.get(f"/api/v1/media/{media_id}", headers=member).status_code == 200


def test_les_medias_d_une_chaine_publique_restent_lisibles_de_tous(client):
    owner, _ = _signup(client, "+22897700005")
    stranger, _ = _signup(client, "+22897700006")
    channel = client.post("/api/v1/channels", json={"name": "Annonces"}, headers=owner).json()
    logo_id = _upload(client, owner)
    client.patch(f"/api/v1/channels/{channel['id']}", json={"avatar_media_id": logo_id}, headers=owner)

    assert client.get(f"/api/v1/media/{logo_id}", headers=stranger).status_code == 200


def test_le_sondage_d_une_chaine_privee_est_introuvable_pour_un_etranger(client):
    owner, _ = _signup(client, "+22897700007")
    stranger, _ = _signup(client, "+22897700008")
    _, _, _, poll_post = _private_channel_with_media_and_poll(client, owner)
    poll = poll_post["poll"]

    assert client.get(f"/api/v1/polls/{poll['id']}", headers=stranger).status_code == 404
    vote = client.post(
        f"/api/v1/polls/{poll['id']}/vote",
        json={"option_ids": [poll["options"][0]["id"]]},
        headers=stranger,
    )
    assert vote.status_code == 404
    assert client.get(f"/api/v1/polls/{poll['id']}", headers=owner).status_code == 200


@pytest.fixture()
def admin_headers(client):
    from app.models import UserRole

    db = TestingSessionLocal()
    db.add(User(email="equipe@pok.app", full_name="Équipe", role=UserRole.SUPER_ADMIN))
    db.commit()
    db.close()
    client.cookies.clear()
    return bearer_for_email(TestingSessionLocal, "equipe@pok.app")


def _pending_seller_application(client, seller):
    document = _upload(client, seller)
    response = client.post(
        "/api/v1/marketplace/verification",
        json={"plan": "MONTHLY", "identity_media_id": document},
        headers=seller,
    )
    assert response.status_code in (200, 201), response.text
    return response.json()["application_id"]


def test_la_route_historique_de_certification_exige_un_paiement_confirme(client, admin_headers):
    seller, seller_id = _signup(client, "+22897700009")
    application_id = _pending_seller_application(client, seller)

    refused = client.put(
        f"/api/v1/marketplace/verification/{application_id}", json={"certified": True}, headers=admin_headers
    )
    assert refused.status_code == 409

    db = TestingSessionLocal()
    assert db.query(User).filter(User.id == seller_id).one().is_certified_seller in (False, None)
    db.close()


def test_la_route_historique_accorde_une_certification_datee_et_une_seule_fois(client, admin_headers):
    from app.models import MarketplacePayment, SellerVerificationApplication

    seller, seller_id = _signup(client, "+22897700010")
    application_id = _pending_seller_application(client, seller)
    db = TestingSessionLocal()
    application = db.query(SellerVerificationApplication).filter(SellerVerificationApplication.id == application_id).one()
    db.query(MarketplacePayment).filter(MarketplacePayment.id == application.payment_id).update({"status": "CONFIRMED"})
    db.commit()
    db.close()

    approved = client.put(
        f"/api/v1/marketplace/verification/{application_id}", json={"certified": True}, headers=admin_headers
    )
    assert approved.status_code == 200, approved.text

    db = TestingSessionLocal()
    user = db.query(User).filter(User.id == seller_id).one()
    assert user.is_certified_seller is True
    assert user.certified_seller_until is not None, "plus de badge permanent sans échéance"
    db.close()

    again = client.put(
        f"/api/v1/marketplace/verification/{application_id}", json={"certified": False}, headers=admin_headers
    )
    assert again.status_code == 409
