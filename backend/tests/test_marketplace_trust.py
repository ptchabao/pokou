"""Pokou marketplace — galerie d'images, avis/note du vendeur, certification.

La marketplace ne fait que METTRE EN RELATION (aucun paiement encaissé), donc
la confiance se joue sur le vendeur : ces tests portent surtout sur ce qui
pourrait la falsifier (se noter soi-même, empiler des avis, s'auto-certifier,
illustrer son produit avec le média d'autrui).
"""
import re
from unittest.mock import patch

import pytest
from fastapi.testclient import TestClient
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker

from app.core.database import Base, get_db
from app.main import app
from app.models import User, UserRole
from app.services.auth import otp_service

TEST_DATABASE_URL = "sqlite:///./test_marketplace_trust.db"

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


def _promote_to_admin(user_id):
    """Le rôle est relu en base à chaque requête (voir rbac.require_admin_role),
    jamais porté par le jeton — on peut donc promouvoir après l'inscription."""
    db = TestingSessionLocal()
    try:
        db.query(User).filter(User.id == user_id).update({User.role: UserRole.ADMIN})
        db.commit()
    finally:
        db.close()


def _upload(client, headers, filename="photo.jpg", content=b"des-octets-de-photo"):
    return client.post(
        "/api/v1/media/upload",
        data={"message_type": "IMAGE"},
        files={"file": (filename, content, "image/jpeg")},
        headers=headers,
    ).json()["id"]


def _create_product(client, headers, **overrides):
    payload = {"name": "Sac de ciment", "price": "4500", "currency": "XOF"}
    payload.update(overrides)
    return client.post("/api/v1/marketplace", json=payload, headers=headers)


def _sold_to(client, headers_seller, buyer_id, price=11500):
    """ASM-16 : une note suppose une vente confirmée par le vendeur (ANN-18)."""
    product = _create_product(client, headers_seller, name="Pagne wax").json()
    response = client.post(
        f"/api/v1/marketplace/{product['id']}/sold",
        json={"buyer_id": buyer_id, "final_price": price},
        headers=headers_seller,
    )
    assert response.status_code == 200, response.text
    return product


# ─── Images produit ───────────────────────────────────────────────────────────

def test_product_carries_a_main_image_and_an_ordered_gallery(client):
    headers, _ = _signup(client, "+22897200001")
    main = _upload(client, headers, "principale.jpg")
    second = _upload(client, headers, "profil.jpg")
    third = _upload(client, headers, "detail.jpg")

    created = _create_product(
        client,
        headers,
        image_media_id=main,
        gallery_media_ids=[second, third],
    )
    assert created.status_code == 200, created.text
    body = created.json()
    assert body["image"]["id"] == main
    # L'ordre reçu EST l'ordre d'affichage.
    assert [image["id"] for image in body["gallery"]] == [second, third]


def test_gallery_order_is_the_one_sent_not_the_upload_order(client):
    headers, _ = _signup(client, "+22897200002")
    first_uploaded = _upload(client, headers, "a.jpg")
    second_uploaded = _upload(client, headers, "b.jpg")
    product_id = _create_product(client, headers).json()["id"]

    updated = client.patch(
        f"/api/v1/marketplace/{product_id}",
        json={
            "name": "Sac de ciment",
            "price": "4500",
            "gallery_media_ids": [second_uploaded, first_uploaded],
        },
        headers=headers,
    ).json()
    assert [image["id"] for image in updated["gallery"]] == [second_uploaded, first_uploaded]


def test_replacing_the_gallery_does_not_duplicate_images(client):
    """Rejouer un PATCH doit être idempotent : la liste reçue EST la galerie."""
    headers, _ = _signup(client, "+22897200003")
    media_id = _upload(client, headers)
    product_id = _create_product(client, headers, gallery_media_ids=[media_id]).json()["id"]

    for _ in range(3):
        body = client.patch(
            f"/api/v1/marketplace/{product_id}",
            json={"name": "Sac de ciment", "price": "4500", "gallery_media_ids": [media_id]},
            headers=headers,
        ).json()
    assert len(body["gallery"]) == 1


def test_a_patch_that_omits_the_gallery_leaves_it_untouched(client):
    headers, _ = _signup(client, "+22897200004")
    media_id = _upload(client, headers)
    product_id = _create_product(client, headers, gallery_media_ids=[media_id]).json()["id"]

    body = client.patch(
        f"/api/v1/marketplace/{product_id}",
        json={"name": "Ciment 50kg", "price": "5000"},
        headers=headers,
    ).json()
    assert [image["id"] for image in body["gallery"]] == [media_id]

    # Une liste VIDE, elle, vide vraiment la galerie — la distinction compte.
    emptied = client.patch(
        f"/api/v1/marketplace/{product_id}",
        json={"name": "Ciment 50kg", "price": "5000", "gallery_media_ids": []},
        headers=headers,
    ).json()
    assert emptied["gallery"] == []


def test_cannot_illustrate_a_product_with_someone_elses_upload(client):
    """Sans ce verrou, connaître l'id d'un média d'autrui (une photo privée)
    suffirait à l'exposer publiquement dans son propre catalogue."""
    headers_a, _ = _signup(client, "+22897200005")
    headers_b, _ = _signup(client, "+22897200006")
    media_of_b = _upload(client, headers_b, "prive.jpg")

    refused_main = _create_product(client, headers_a, image_media_id=media_of_b)
    assert refused_main.status_code == 404

    refused_gallery = _create_product(client, headers_a, gallery_media_ids=[media_of_b])
    assert refused_gallery.status_code == 404


def test_gallery_is_capped(client):
    headers, _ = _signup(client, "+22897200007")
    media_ids = [_upload(client, headers, f"img{index}.jpg") for index in range(9)]
    response = _create_product(client, headers, gallery_media_ids=media_ids)
    assert response.status_code == 400


# ─── Avis et note du vendeur ──────────────────────────────────────────────────

def test_a_review_sets_the_sellers_rating(client):
    headers_seller, seller_id = _signup(client, "+22897200010")
    headers_buyer, buyer_id = _signup(client, "+22897200011")
    _create_product(client, headers_seller)
    _sold_to(client, headers_seller, buyer_id)

    posted = client.put(
        f"/api/v1/marketplace/sellers/{seller_id}/review",
        json={"rating": 4, "comment": "Livraison rapide"},
        headers=headers_buyer,
    )
    assert posted.status_code == 200, posted.text
    assert posted.json()["rating"] == 4

    profile = client.get(f"/api/v1/marketplace/sellers/{seller_id}", headers=headers_buyer).json()
    assert profile["rating"] == 4.0
    assert profile["review_count"] == 1

    # La note remonte aussi sur les produits, pour la liste marketplace.
    listed = client.get("/api/v1/marketplace", headers=headers_buyer).json()["items"]
    assert listed[0]["seller_rating"] == 4.0
    assert listed[0]["seller_review_count"] == 1


def test_paid_pro_status_is_exposed_separately_from_seller_certification(client):
    headers, seller_id = _signup(client, "+22897200014")
    _create_product(client, headers)

    with patch(
        "app.api.v1.certified.certified.public_badge",
        return_value={"badge": "PRO"},
    ):
        listed = client.get("/api/v1/marketplace", headers=headers).json()["items"][0]
        profile = client.get(
            f"/api/v1/marketplace/sellers/{seller_id}",
            headers=headers,
        ).json()

    assert listed["seller_is_pro"] is True
    assert listed["seller_is_certified"] is False
    assert profile["is_pro"] is True
    assert profile["is_certified"] is False


def test_a_second_review_by_the_same_person_replaces_the_first(client):
    """Un avis par personne : sinon la note se gonfle depuis un seul compte."""
    headers_seller, seller_id = _signup(client, "+22897200012")
    headers_buyer, buyer_id = _signup(client, "+22897200013")
    _sold_to(client, headers_seller, buyer_id)

    for rating in (5, 5, 5):
        client.put(
            f"/api/v1/marketplace/sellers/{seller_id}/review",
            json={"rating": rating},
            headers=headers_buyer,
        )
    client.put(
        f"/api/v1/marketplace/sellers/{seller_id}/review",
        json={"rating": 2, "comment": "finalement non"},
        headers=headers_buyer,
    )

    reviews = client.get(
        f"/api/v1/marketplace/sellers/{seller_id}/reviews", headers=headers_buyer
    ).json()
    assert reviews["review_count"] == 1
    assert reviews["rating"] == 2.0
    assert reviews["items"][0]["comment"] == "finalement non"
    assert reviews["items"][0]["is_mine"] is True


def test_the_rating_is_the_average_of_every_review(client):
    headers_seller, seller_id = _signup(client, "+22897200014")
    headers_b, b_id = _signup(client, "+22897200015")
    headers_c, c_id = _signup(client, "+22897200016")
    _sold_to(client, headers_seller, b_id)
    _sold_to(client, headers_seller, c_id)

    client.put(f"/api/v1/marketplace/sellers/{seller_id}/review", json={"rating": 5}, headers=headers_b)
    client.put(f"/api/v1/marketplace/sellers/{seller_id}/review", json={"rating": 2}, headers=headers_c)

    profile = client.get(f"/api/v1/marketplace/sellers/{seller_id}", headers=headers_b).json()
    assert profile["rating"] == 3.5
    assert profile["review_count"] == 2


def test_nobody_can_review_themselves(client):
    headers, user_id = _signup(client, "+22897200017")
    response = client.put(
        f"/api/v1/marketplace/sellers/{user_id}/review", json={"rating": 5}, headers=headers
    )
    assert response.status_code == 403


def test_a_rating_outside_one_to_five_is_refused(client):
    headers_seller, seller_id = _signup(client, "+22897200018")
    headers_buyer, _ = _signup(client, "+22897200019")
    for rating in (0, 6, -3):
        response = client.put(
            f"/api/v1/marketplace/sellers/{seller_id}/review",
            json={"rating": rating},
            headers=headers_buyer,
        )
        assert response.status_code == 422, rating


def test_deleting_my_review_removes_it_from_the_average(client):
    headers_seller, seller_id = _signup(client, "+22897200020")
    headers_buyer, buyer_id = _signup(client, "+22897200021")
    _sold_to(client, headers_seller, buyer_id)
    client.put(
        f"/api/v1/marketplace/sellers/{seller_id}/review", json={"rating": 1}, headers=headers_buyer
    )

    assert client.delete(
        f"/api/v1/marketplace/sellers/{seller_id}/review", headers=headers_buyer
    ).json() == {"deleted": True}

    profile = client.get(f"/api/v1/marketplace/sellers/{seller_id}", headers=headers_buyer).json()
    assert profile["rating"] is None
    assert profile["review_count"] == 0


def test_a_review_on_an_unknown_seller_is_404(client):
    headers, _ = _signup(client, "+22897200022")
    response = client.put(
        "/api/v1/marketplace/sellers/999999/review", json={"rating": 4}, headers=headers
    )
    assert response.status_code == 404


# ─── Certification par l'équipe ───────────────────────────────────────────────

def test_a_seller_cannot_certify_himself(client):
    """La certification est une garantie DE LA PLATEFORME — elle ne vaudrait
    rien si le vendeur pouvait se l'attribuer."""
    headers, user_id = _signup(client, "+22897200030")
    response = client.put(
        f"/api/v1/marketplace/sellers/{user_id}/certification",
        json={"certified": True},
        headers=headers,
    )
    assert response.status_code == 403
    profile = client.get(f"/api/v1/marketplace/sellers/{user_id}", headers=headers).json()
    assert profile["is_certified"] is False


def test_the_team_can_certify_and_revoke_a_seller(client):
    headers_seller, seller_id = _signup(client, "+22897200031")
    headers_admin, admin_id = _signup(client, "+22897200032")
    _promote_to_admin(admin_id)

    certified = client.put(
        f"/api/v1/marketplace/sellers/{seller_id}/certification",
        json={"certified": True},
        headers=headers_admin,
    )
    assert certified.status_code == 200, certified.text
    assert certified.json()["is_certified"] is True
    assert certified.json()["certified_at"] is not None

    # Le badge suit le COMPTE, donc tout son catalogue.
    _create_product(client, headers_seller)
    listed = client.get("/api/v1/marketplace", headers=headers_seller).json()["items"]
    assert listed[0]["seller_is_certified"] is True

    revoked = client.put(
        f"/api/v1/marketplace/sellers/{seller_id}/certification",
        json={"certified": False},
        headers=headers_admin,
    ).json()
    assert revoked["is_certified"] is False
    assert revoked["certified_at"] is None


def test_certification_is_independent_of_the_rating(client):
    """Un vendeur certifié mal noté reste mal noté : la certification dit
    « ce compte est vérifié », pas « ce vendeur est bon »."""
    headers_seller, seller_id = _signup(client, "+22897200033")
    headers_admin, admin_id = _signup(client, "+22897200034")
    headers_buyer, buyer_id = _signup(client, "+22897200035")
    _sold_to(client, headers_seller, buyer_id)
    _promote_to_admin(admin_id)

    client.put(
        f"/api/v1/marketplace/sellers/{seller_id}/certification",
        json={"certified": True},
        headers=headers_admin,
    )
    client.put(
        f"/api/v1/marketplace/sellers/{seller_id}/review", json={"rating": 1}, headers=headers_buyer
    )

    profile = client.get(f"/api/v1/marketplace/sellers/{seller_id}", headers=headers_buyer).json()
    assert profile["is_certified"] is True
    assert profile["rating"] == 1.0


# ─── Recherche ────────────────────────────────────────────────────────────────

def test_search_matches_name_and_description_case_insensitively(client):
    headers, _ = _signup(client, "+22897200040")
    _create_product(client, headers, name="Sac de CIMENT", description="50 kg")
    _create_product(client, headers, name="Tôle bac", description="Toiture en ciment allégé")
    _create_product(client, headers, name="Brouette", description="Chantier")

    found = client.get("/api/v1/marketplace", params={"q": "ciment"}, headers=headers).json()["items"]
    names = {item["name"] for item in found}
    assert names == {"Sac de CIMENT", "Tôle bac"}


def test_search_treats_like_wildcards_as_plain_text(client):
    """Sans échappement, « % » serait un joker LIKE et ramènerait tout le
    catalogue au lieu de ne rien trouver."""
    headers, _ = _signup(client, "+22897200041")
    _create_product(client, headers, name="Ciment", description="rien")
    _create_product(client, headers, name="Remise 100%", description="promo")

    percent = client.get("/api/v1/marketplace", params={"q": "100%"}, headers=headers).json()["items"]
    assert [item["name"] for item in percent] == ["Remise 100%"]

    underscore = client.get("/api/v1/marketplace", params={"q": "_"}, headers=headers).json()["items"]
    assert underscore == []


def test_search_can_be_combined_with_a_seller_filter(client):
    headers_a, seller_a = _signup(client, "+22897200042")
    headers_b, seller_b = _signup(client, "+22897200043")
    _create_product(client, headers_a, name="Ciment de A")
    _create_product(client, headers_b, name="Ciment de B")

    found = client.get(
        "/api/v1/marketplace",
        params={"q": "ciment", "seller_id": seller_b},
        headers=headers_a,
    ).json()["items"]
    assert [item["name"] for item in found] == ["Ciment de B"]


def test_an_empty_search_returns_the_whole_catalogue(client):
    headers, _ = _signup(client, "+22897200044")
    _create_product(client, headers, name="Un")
    _create_product(client, headers, name="Deux")
    for value in ("", "   "):
        items = client.get("/api/v1/marketplace", params={"q": value}, headers=headers).json()["items"]
        assert len(items) == 2, value


# ─── Accès aux photos des produits ────────────────────────────────────────────

def test_anyone_can_see_another_sellers_product_photos(client):
    """Le bug signalé : les photos des produits des AUTRES ne s'affichaient
    pas. media.py::_can_access ne connaissait pas la marketplace, donc seul
    l'auteur du téléversement pouvait récupérer le fichier — pour tout le
    monde d'autre, GET /media/{id} rendait 404 et l'image restait cassée."""
    headers_seller, _ = _signup(client, "+22897200050")
    headers_buyer, _ = _signup(client, "+22897200051")
    main = _upload(client, headers_seller, "principale.jpg", b"photo-principale")
    gallery = _upload(client, headers_seller, "detail.jpg", b"photo-detail")
    _create_product(
        client, headers_seller, image_media_id=main, gallery_media_ids=[gallery]
    )

    # L'acheteur n'a rien téléversé et n'est même pas un contact du vendeur.
    principale = client.get(f"/api/v1/media/{main}", headers=headers_buyer)
    assert principale.status_code == 200
    assert principale.content == b"photo-principale"
    assert client.get(f"/api/v1/media/{gallery}", headers=headers_buyer).status_code == 200


def test_deactivating_a_product_also_hides_its_photos(client):
    """Retirer un produit de la vente doit retirer ses photos, pas seulement
    sa fiche."""
    headers_seller, _ = _signup(client, "+22897200052")
    headers_buyer, _ = _signup(client, "+22897200053")
    media_id = _upload(client, headers_seller)
    product_id = _create_product(client, headers_seller, image_media_id=media_id).json()["id"]
    assert client.get(f"/api/v1/media/{media_id}", headers=headers_buyer).status_code == 200

    # `DELETE`, et non un PATCH `is_active: false`.
    #
    # `is_active` appartient à la MODÉRATION (voir marketplace_admin.py) ;
    # le seul geste de retrait dont le vendeur dispose est la suppression,
    # qui pose `deleted_at`. Ce test empruntait donc un levier que ni
    # l'application ni le vendeur n'ont jamais eu — il prouvait une
    # propriété que le produit n'avait pas sur son vrai chemin.
    client.delete(f"/api/v1/marketplace/{product_id}", headers=headers_seller)

    assert client.get(f"/api/v1/media/{media_id}", headers=headers_buyer).status_code == 404
    # Le vendeur, lui, garde l'accès à son propre téléversement.
    assert client.get(f"/api/v1/media/{media_id}", headers=headers_seller).status_code == 200


def test_an_unrelated_upload_stays_private(client):
    """Non-régression : la branche marketplace ne doit pas ouvrir l'accès à
    n'importe quel média — seulement à ceux réellement rattachés à un
    produit en vente."""
    headers_a, _ = _signup(client, "+22897200054")
    headers_b, _ = _signup(client, "+22897200055")
    private_media = _upload(client, headers_a, "prive.jpg")

    assert client.get(f"/api/v1/media/{private_media}", headers=headers_b).status_code == 404


# ─── Mise en relation : partager un produit dans une conversation ─────────────

def test_writing_to_the_seller_pins_the_product_in_the_conversation(client):
    """« Écrire au vendeur » doit ouvrir une discussion où l'article est déjà
    sous les yeux — sans que l'acheteur ait à le décrire."""
    headers_seller, seller_id = _signup(client, "+22897200060")
    headers_buyer, buyer_id = _signup(client, "+22897200061")
    media_id = _upload(client, headers_seller)
    product = _create_product(
        client, headers_seller, name="Tôle bac 3m", price="12000", image_media_id=media_id
    ).json()

    shared = client.post(
        f"/api/v1/marketplace/{product['id']}/share",
        json={"message": "Bonjour, est-elle encore disponible ?"},
        headers=headers_buyer,
    )
    assert shared.status_code == 200, shared.text
    body = shared.json()
    assert body["message_type"] == "PRODUCT"
    assert body["recipient_id"] == seller_id
    assert body["content"] == "Bonjour, est-elle encore disponible ?"
    # Instantané du produit, pas juste son identifiant : la bulle doit
    # rester lisible si l'article quitte le catalogue.
    assert body["payload"]["product_id"] == product["id"]
    assert body["payload"]["name"] == "Tôle bac 3m"
    assert body["payload"]["price"] == "12000.00"
    assert body["payload"]["image_media_id"] == media_id

    # La fiche est bien dans le fil des DEUX côtés.
    for headers, other_id in ((headers_buyer, seller_id), (headers_seller, buyer_id)):
        items = client.get(f"/api/v1/messages/{other_id}", headers=headers).json()["items"]
        assert [item["message_type"] for item in items] == ["PRODUCT"]


def test_writing_to_the_seller_needs_no_prior_contact(client):
    """C'est tout l'objet d'une marketplace : mettre en relation des gens qui
    ne se connaissent pas."""
    headers_seller, _ = _signup(client, "+22897200062")
    headers_buyer, _ = _signup(client, "+22897200063")
    product_id = _create_product(client, headers_seller).json()["id"]

    assert client.post(
        f"/api/v1/marketplace/{product_id}/share", json={}, headers=headers_buyer
    ).status_code == 200


def test_recommending_a_product_to_a_third_party_requires_a_contact(client):
    """Envoyer la fiche à quelqu'un d'AUTRE que le vendeur reste soumis à la
    règle habituelle du carnet d'adresses."""
    headers_seller, _ = _signup(client, "+22897200064")
    headers_buyer, _ = _signup(client, "+22897200065")
    _, stranger_id = _signup(client, "+22897200066")
    product_id = _create_product(client, headers_seller).json()["id"]

    refused = client.post(
        f"/api/v1/marketplace/{product_id}/share",
        json={"recipient_id": stranger_id},
        headers=headers_buyer,
    )
    assert refused.status_code == 403

    client.post(
        "/api/v1/contacts", json={"phone": "+22897200066", "display_name": "Ami"}, headers=headers_buyer
    )
    assert client.post(
        f"/api/v1/marketplace/{product_id}/share",
        json={"recipient_id": stranger_id},
        headers=headers_buyer,
    ).status_code == 200


def test_a_seller_cannot_share_a_product_with_himself(client):
    headers_seller, _ = _signup(client, "+22897200067")
    product_id = _create_product(client, headers_seller).json()["id"]
    assert client.post(
        f"/api/v1/marketplace/{product_id}/share", json={}, headers=headers_seller
    ).status_code == 400


def test_a_withdrawn_product_can_no_longer_be_shared(client):
    headers_seller, _ = _signup(client, "+22897200068")
    headers_buyer, _ = _signup(client, "+22897200069")
    product_id = _create_product(client, headers_seller).json()["id"]
    # `DELETE`, et non un PATCH `is_active: false`.
    #
    # `is_active` appartient à la MODÉRATION (voir marketplace_admin.py) ;
    # le seul geste de retrait dont le vendeur dispose est la suppression,
    # qui pose `deleted_at`. Ce test empruntait donc un levier que ni
    # l'application ni le vendeur n'ont jamais eu — il prouvait une
    # propriété que le produit n'avait pas sur son vrai chemin.
    client.delete(f"/api/v1/marketplace/{product_id}", headers=headers_seller)

    assert client.post(
        f"/api/v1/marketplace/{product_id}/share", json={}, headers=headers_buyer
    ).status_code == 404


# ─── Suppression d'une annonce par son vendeur ──────────────────────────────


def test_supprimer_une_annonce_ne_l_efface_pas_de_la_base(client):
    """Suppression DOUCE, et ce n'est pas un détail d'implémentation.

    La route faisait un vrai `DELETE`. Trois choses partaient avec la ligne,
    et la deuxième est la plus grave :

    - les images de l'annonce, en cascade ;
    - **les enregistrements de boost**, en cascade aussi — la trace d'une
      somme réellement encaissée, effacée par un geste d'interface ;
    - les bulles produit des conversations citent `product_id` : elles
      pointaient dans le vide, et le suivi d'un achat en cours perdait son
      objet.
    """
    from app.models import MarketplaceProduct

    headers, seller_id = _signup(client, "+22893000501")
    product_id = client.post(
        "/api/v1/marketplace",
        json={"name": "Ciment", "price": "5500", "currency": "XOF"},
        headers=headers,
    ).json()["id"]

    assert client.delete(f"/api/v1/marketplace/{product_id}", headers=headers).status_code == 200

    with TestingSessionLocal() as db:
        row = db.query(MarketplaceProduct).filter(MarketplaceProduct.id == product_id).one()
        assert row.deleted_at is not None
        # Toujours là — c'est tout l'intérêt.
        assert row.name == "Ciment"


def test_une_annonce_supprimee_sort_de_toutes_les_listes(client):
    headers, seller_id = _signup(client, "+22893000502")
    product_id = client.post(
        "/api/v1/marketplace",
        json={"name": "Ciment", "price": "5500", "currency": "XOF"},
        headers=headers,
    ).json()["id"]
    client.delete(f"/api/v1/marketplace/{product_id}", headers=headers)

    public = client.get("/api/v1/marketplace", headers=headers).json()["items"]
    assert product_id not in [p["id"] for p in public]

    # Y compris du catalogue de son propre vendeur : sinon le geste semble
    # sans effet, et il recommence.
    mine = client.get("/api/v1/marketplace/mine", headers=headers).json()["items"]
    assert product_id not in [p["id"] for p in mine]


def test_on_ne_peut_pas_booster_une_annonce_supprimee(client):
    headers, _ = _signup(client, "+22893000503")
    product_id = client.post(
        "/api/v1/marketplace",
        json={"name": "Ciment", "price": "5500", "currency": "XOF"},
        headers=headers,
    ).json()["id"]
    client.delete(f"/api/v1/marketplace/{product_id}", headers=headers)

    # Payer pour mettre en avant une annonce supprimée reviendrait à payer
    # pour du vide, sans que rien ne le dise.
    response = client.post(f"/api/v1/marketplace/{product_id}/boost", headers=headers)
    assert response.status_code == 404


def test_supprimer_deux_fois_ne_produit_pas_d_erreur(client):
    headers, _ = _signup(client, "+22893000504")
    product_id = client.post(
        "/api/v1/marketplace",
        json={"name": "Ciment", "price": "5500", "currency": "XOF"},
        headers=headers,
    ).json()["id"]

    assert client.delete(f"/api/v1/marketplace/{product_id}", headers=headers).status_code == 200
    # Un double appui sur un bouton ne doit pas produire une erreur pour une
    # action déjà obtenue.
    assert client.delete(f"/api/v1/marketplace/{product_id}", headers=headers).status_code == 200


def test_on_ne_supprime_que_ses_propres_annonces(client):
    seller, _ = _signup(client, "+22893000505")
    intruder, _ = _signup(client, "+22893000506")
    product_id = client.post(
        "/api/v1/marketplace",
        json={"name": "Ciment", "price": "5500", "currency": "XOF"},
        headers=seller,
    ).json()["id"]

    assert client.delete(f"/api/v1/marketplace/{product_id}", headers=intruder).status_code == 404


# ─── La fiche doit TOUJOURS avoir une image si le vendeur en a mis une ────────
#
# Le formulaire propose deux zones séparées — « Photo principale » et
# « Autres photos » — et rien n'obligeait à remplir la première. Une annonce
# publiée avec des photos ressortait alors sans aucune image sur sa fiche,
# parce que la liste ne lit que l'image principale. Constaté en production le
# 24/09/2026 : « les nouveaux articles n'ont pas leur image sur la fiche ».


def test_une_galerie_sans_photo_principale_en_designe_une(client):
    headers, _ = _signup(client, "+22897205001")
    premiere = _upload(client, headers, "vue-1.jpg")
    seconde = _upload(client, headers, "vue-2.jpg")

    cree = _create_product(client, headers, gallery_media_ids=[premiere, seconde])

    assert cree.status_code == 200, cree.text
    corps = cree.json()
    # La PREMIÈRE de la galerie, pas n'importe laquelle : c'est celle que le
    # vendeur a choisi de montrer en tête.
    assert corps["image"]["id"] == premiere
    # Et la galerie garde ses deux photos — la promotion ne retire rien.
    assert [i["id"] for i in corps["gallery"]] == [premiere, seconde]


def test_une_photo_principale_explicite_n_est_jamais_ecrasee(client):
    # Le garde-fou du test précédent : la promotion ne doit s'appliquer QUE
    # s'il n'y a pas de choix du vendeur.
    headers, _ = _signup(client, "+22897205002")
    principale = _upload(client, headers, "principale.jpg")
    autre = _upload(client, headers, "autre.jpg")

    corps = _create_product(
        client,
        headers,
        image_media_id=principale,
        gallery_media_ids=[autre],
    ).json()

    assert corps["image"]["id"] == principale


def test_une_annonce_sans_aucune_photo_reste_sans_photo(client):
    # Rien à promouvoir : la fiche s'affiche avec son visuel de repli, et
    # surtout la route ne plante pas sur une galerie vide.
    headers, _ = _signup(client, "+22897205003")

    corps = _create_product(client, headers).json()

    assert corps["image"] is None
    assert corps["gallery"] == []


def test_modifier_le_prix_n_efface_pas_la_photo_principale(client):
    # `image_media_id` valait None par défaut et était écrit tel quel : toute
    # modification qui ne renvoyait pas la photo l'EFFAÇAIT. L'application y
    # échappait parce qu'elle la renvoie toujours — un autre client, ou
    # l'admin, aurait perdu l'image en corrigeant un prix.
    headers, _ = _signup(client, "+22897205004")
    photo = _upload(client, headers, "principale.jpg")
    produit_id = _create_product(client, headers, image_media_id=photo).json()["id"]

    modifie = client.patch(
        f"/api/v1/marketplace/{produit_id}",
        json={"name": "Sac de ciment", "price": "5000"},
        headers=headers,
    )

    assert modifie.status_code == 200, modifie.text
    assert modifie.json()["image"]["id"] == photo


def test_on_peut_toujours_RETIRER_la_photo_principale(client):
    # L'autre moitié de la règle : absent = inchangé, mais `null` explicite
    # doit encore effacer. Sans ce test, la correction ci-dessus aurait rendu
    # la photo principale indéboulonnable.
    headers, _ = _signup(client, "+22897205005")
    photo = _upload(client, headers, "principale.jpg")
    produit_id = _create_product(client, headers, image_media_id=photo).json()["id"]

    modifie = client.patch(
        f"/api/v1/marketplace/{produit_id}",
        json={"name": "Sac de ciment", "price": "4500", "image_media_id": None},
        headers=headers,
    )

    assert modifie.status_code == 200, modifie.text
    assert modifie.json()["image"] is None


def test_only_the_buyer_of_a_confirmed_sale_can_review(client):
    headers_seller, seller_id = _signup(client, "+22897200040")
    headers_buyer, buyer_id = _signup(client, "+22897200041")
    headers_other, _ = _signup(client, "+22897200042")
    refused = client.put(
        f"/api/v1/marketplace/sellers/{seller_id}/review", json={"rating": 5}, headers=headers_other
    )
    assert refused.status_code == 403
    product = _sold_to(client, headers_seller, buyer_id)
    # Vendue : l'annonce quitte le marché.
    listed = client.get("/api/v1/marketplace", headers=headers_other).json()["items"]
    assert all(item["id"] != product["id"] for item in listed)
    # L'acheteur est invité à noter (centre de notifications).
    inbox = client.get("/api/v1/notifications", headers=headers_buyer).json()["items"]
    assert inbox[0]["route"] == f"assime/review/{product['id']}"
    assert "a indiqué que tu as acheté cet article pour 11 500 FCFA." in inbox[0]["body"]
    sale = client.get(f"/api/v1/marketplace/{product['id']}/sale", headers=headers_buyer).json()
    assert sale["seller_id"] == seller_id and sale["reviewed"] is False
    ok = client.put(
        f"/api/v1/marketplace/sellers/{seller_id}/review",
        json={"rating": 4, "comment": "Tissu de belle qualité", "tags": ["as_described", "punctual", "bogus"]},
        headers=headers_buyer,
    )
    assert ok.status_code == 200 and ok.json()["tags"] == ["as_described", "punctual"]
