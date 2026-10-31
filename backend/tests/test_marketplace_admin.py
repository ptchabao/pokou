"""Administration de la Marketplace — la moitié qui manquait à chaque flux.

Deux propriétés dominent ce fichier, et aucune ne se voit casser :

- **une file d'attente sans écran n'est pas une file.** Un vendeur pouvait
  déposer un dossier de vérification et le payer ; la route d'examen
  existait, mais aucune ne listait les dossiers. Il fallait déjà connaître
  l'identifiant pour approuver. Le vendeur, lui, attendait indéfiniment.
- **une publicité payée s'activait toute seule.** Quiconque payait diffusait
  son message à tous les utilisateurs sans qu'un humain l'ait lu.
"""
from datetime import datetime, timedelta

import pytest
from fastapi.testclient import TestClient
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker

from app.core.database import Base, get_db
from app.main import app
from app.models import Contact, DirectMessage, MarketplaceAd, MarketplacePayment, MarketplaceProduct, MediaAsset, SellerVerificationApplication, User, UserRole
from app.services.marketplace.marketplace_monetization_service import confirm_payment
from tests.helpers import bearer_for_email

TEST_DATABASE_URL = "sqlite:///./test_marketplace_admin.db"

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
    else:
        app.dependency_overrides.pop(get_db, None)
    Base.metadata.drop_all(bind=engine)


def auth_headers(client, email, role=UserRole.USER):
    db = TestingSessionLocal()
    try:
        user = db.query(User).filter(User.email == email).first()
        if user is None:
            user = User(
                email=email,
                full_name=email.split("@")[0].title(),
                role=role,
            )
            db.add(user)
            db.commit()
    finally:
        db.close()
    client.cookies.clear()
    return bearer_for_email(TestingSessionLocal, email)


def _seed_verification(seller_email="vendeur@example.com"):
    """Un dossier déposé et payé, comme après un passage par l'application."""
    db = TestingSessionLocal()
    try:
        seller = db.query(User).filter(User.email == seller_email).first()
        # Fichier RÉELLEMENT écrit sur disque : sans lui, la route répond
        # 404 après avoir accordé l'accès, et le test confond « accès
        # refusé » avec « fichier absent » — deux causes très différentes
        # derrière le même code.
        from app.services.media import media_storage

        storage_dir = media_storage._storage_dir()
        storage_dir.mkdir(parents=True, exist_ok=True)
        (storage_dir / "cni-test.jpg").write_bytes(b"\xff\xd8\xff\xd9")

        media = MediaAsset(
            uploader_id=seller.id,
            storage_path="cni-test.jpg",
            storage_backend="local",
            mime_type="image/jpeg",
            size_bytes=4,
        )
        db.add(media)
        db.flush()
        payment = MarketplacePayment(
            user_id=seller.id, kind="VERIFICATION", amount=5000, status="CONFIRMED"
        )
        db.add(payment)
        db.flush()
        application = SellerVerificationApplication(
            seller_id=seller.id, identity_media_id=media.id, payment_id=payment.id
        )
        db.add(application)
        db.commit()
        return application.id, seller.id
    finally:
        db.close()


# ── La file d'attente des vérifications ──────────────────────────────────


def test_les_dossiers_en_attente_sont_enfin_listables(client):
    auth_headers(client, "vendeur@example.com")
    admin = auth_headers(client, "admin@example.com", UserRole.ADMIN)
    application_id, seller_id = _seed_verification()

    items = client.get("/api/v1/admin/marketplace/verifications", headers=admin).json()["items"]
    assert [i["id"] for i in items] == [application_id]

    row = items[0]
    assert row["seller_id"] == seller_id
    assert row["status"] == "PENDING"
    # L'admin doit VOIR la pièce d'identité pour décider — sans elle, la
    # page ne sert qu'à cliquer au hasard.
    assert row["identity_media_url"] is not None
    # Et savoir si le vendeur a effectivement payé.
    assert row["payment_status"] == "CONFIRMED"


def test_approuver_un_dossier_pose_le_badge_et_garde_le_motif(client):
    auth_headers(client, "vendeur@example.com")
    admin = auth_headers(client, "admin@example.com", UserRole.ADMIN)
    application_id, seller_id = _seed_verification()

    response = client.put(
        f"/api/v1/admin/marketplace/verifications/{application_id}",
        json={"approved": True, "note": "CNI lisible, nom concordant"},
        headers=admin,
    )
    assert response.status_code == 200, response.text
    assert response.json()["status"] == "APPROVED"

    with TestingSessionLocal() as db:
        assert db.query(User).filter(User.id == seller_id).one().is_certified_seller is True
        # La note est conservée : un refus sans motif écrit est indéfendable
        # si le vendeur le conteste, et l'équipe ne s'en souviendra pas dans
        # six mois.
        application = db.query(SellerVerificationApplication).filter(
            SellerVerificationApplication.id == application_id
        ).one()
        assert application.review_note == "CNI lisible, nom concordant"
        assert application.reviewer_id is not None


def test_le_vendeur_approuve_voit_sa_certification_sur_son_profil(client):
    """Le profil lisait le seul ✓ d'identité, que l'approbation ne pose pas :
    le vendeur approuvé se voyait encore proposer « Vérifier mon compte »."""
    vendeur = auth_headers(client, "vendeur@example.com")
    admin = auth_headers(client, "admin@example.com", UserRole.ADMIN)
    application_id, _ = _seed_verification()

    avant = client.get("/api/v1/users/me/profile", headers=vendeur).json()
    assert avant["is_certified_seller"] is False
    assert avant["is_certification_pending"] is True

    client.put(
        f"/api/v1/admin/marketplace/verifications/{application_id}",
        json={"approved": True, "note": "CNI lisible"},
        headers=admin,
    )

    apres = client.get("/api/v1/users/me/profile", headers=vendeur).json()
    assert apres["is_certified_seller"] is True
    assert apres["certified_seller_until"] is not None
    assert apres["is_certification_pending"] is False
    # Les deux certifications restent distinctes : être vendeur vérifié ne
    # pose pas le ✓ d'identité.
    assert apres["is_verified"] is False


def test_refuser_un_dossier_ne_pose_pas_le_badge(client):
    auth_headers(client, "vendeur@example.com")
    admin = auth_headers(client, "admin@example.com", UserRole.ADMIN)
    application_id, seller_id = _seed_verification()

    client.put(
        f"/api/v1/admin/marketplace/verifications/{application_id}",
        json={"approved": False, "note": "Pièce illisible"},
        headers=admin,
    )
    with TestingSessionLocal() as db:
        assert db.query(User).filter(User.id == seller_id).one().is_certified_seller is False


def test_un_simple_utilisateur_ne_voit_pas_les_dossiers(client):
    user = auth_headers(client, "curieux@example.com")
    # Ces dossiers contiennent des pièces d'IDENTITÉ : la fuite ici n'est pas
    # un désagrément, c'est une violation de données personnelles.
    assert client.get("/api/v1/admin/marketplace/verifications", headers=user).status_code == 403


# ── La relecture des publicités ──────────────────────────────────────────


def _seed_paid_ad(advertiser_email="annonceur@example.com"):
    db = TestingSessionLocal()
    try:
        advertiser = db.query(User).filter(User.email == advertiser_email).first()
        payment = MarketplacePayment(
            user_id=advertiser.id,
            kind="AD",
            amount=10000,
            status="PENDING",
            provider_reference="ref-pub-1",
        )
        db.add(payment)
        db.flush()
        ad = MarketplaceAd(
            advertiser_id=advertiser.id,
            title="Promo",
            body="Offre exceptionnelle",
            payment_id=payment.id,
            status="PENDING",
        )
        db.add(ad)
        db.flush()
        payment.metadata_json = {"ad_id": ad.id, "duration_days": 7}
        db.commit()
        return ad.id
    finally:
        db.close()


def test_une_publicite_payee_attend_une_relecture_humaine(client):
    auth_headers(client, "annonceur@example.com")
    ad_id = _seed_paid_ad()

    with TestingSessionLocal() as db:
        confirm_payment(db, "ref-pub-1")
        ad = db.query(MarketplaceAd).filter(MarketplaceAd.id == ad_id).one()

    # LA propriété. Elle passait directement à ACTIVE : n'importe quel
    # message atteignait tous les utilisateurs sans qu'un humain l'ait lu.
    assert ad.status == "PAID"
    assert ad.starts_at is None
    assert ad.expires_at is None


def test_une_publicite_en_attente_ne_se_diffuse_pas(client):
    advertiser = auth_headers(client, "annonceur@example.com")
    _seed_paid_ad()
    with TestingSessionLocal() as db:
        confirm_payment(db, "ref-pub-1")

    feed = client.get("/api/v1/marketplace/ads/feed", headers=advertiser).json()
    assert feed.get("items", feed) in ([], {"items": []}) or feed["items"] == []


def test_approuver_une_publicite_la_diffuse_et_part_de_l_approbation(client):
    auth_headers(client, "annonceur@example.com")
    admin = auth_headers(client, "admin@example.com", UserRole.ADMIN)
    ad_id = _seed_paid_ad()
    with TestingSessionLocal() as db:
        confirm_payment(db, "ref-pub-1")

    approved_at = datetime.utcnow()
    response = client.put(
        f"/api/v1/admin/marketplace/ads/{ad_id}",
        json={"approved": True, "duration_days": 7},
        headers=admin,
    )
    assert response.status_code == 200, response.text
    assert response.json()["status"] == "ACTIVE"

    with TestingSessionLocal() as db:
        ad = db.query(MarketplaceAd).filter(MarketplaceAd.id == ad_id).one()
    # Le décompte part de l'APPROBATION : une campagne retenue trois jours en
    # relecture ne doit pas perdre trois jours de diffusion payés.
    assert ad.expires_at - approved_at > timedelta(days=6, hours=23)


def _diffuser(client, admin, ad_id):
    with TestingSessionLocal() as db:
        confirm_payment(db, "ref-pub-1")
    response = client.put(
        f"/api/v1/admin/marketplace/ads/{ad_id}",
        json={"approved": True, "duration_days": 7},
        headers=admin,
    )
    assert response.status_code == 200, response.text


def test_le_fil_des_publicites_nomme_l_annonceur(client):
    """Sans l'annonceur, une publicité ne mène nulle part : on la regarde,
    on ne peut pas lui écrire."""
    auth_headers(client, "annonceur@example.com")
    admin = auth_headers(client, "admin@example.com", UserRole.ADMIN)
    lecteur = auth_headers(client, "lecteur@example.com")
    ad_id = _seed_paid_ad()
    _diffuser(client, admin, ad_id)

    items = client.get("/api/v1/marketplace/ads/feed", headers=lecteur).json()["items"]
    assert [i["id"] for i in items] == [ad_id]
    with TestingSessionLocal() as db:
        annonceur = db.query(User).filter(User.email == "annonceur@example.com").one()
    assert items[0]["advertiser_id"] == annonceur.id
    assert items[0]["advertiser_name"] == "Annonceur"


def test_contacter_l_annonceur_ouvre_la_conversation(client):
    auth_headers(client, "annonceur@example.com")
    admin = auth_headers(client, "admin@example.com", UserRole.ADMIN)
    lecteur = auth_headers(client, "lecteur@example.com")
    ad_id = _seed_paid_ad()
    _diffuser(client, admin, ad_id)

    response = client.post(f"/api/v1/marketplace/ads/{ad_id}/contact", headers=lecteur)
    assert response.status_code == 200, response.text
    with TestingSessionLocal() as db:
        annonceur = db.query(User).filter(User.email == "annonceur@example.com").one()
        message = db.query(DirectMessage).one()
    assert response.json()["advertiser_id"] == annonceur.id
    assert message.recipient_id == annonceur.id
    assert "Promo" in message.content


def test_on_ne_contacte_pas_l_annonceur_d_une_publicite_non_diffusee(client):
    """Une campagne refusée ou en relecture ne doit pas servir de porte
    d'entrée vers un compte."""
    auth_headers(client, "annonceur@example.com")
    lecteur = auth_headers(client, "lecteur@example.com")
    ad_id = _seed_paid_ad()
    with TestingSessionLocal() as db:
        confirm_payment(db, "ref-pub-1")  # payée, jamais approuvée

    response = client.post(f"/api/v1/marketplace/ads/{ad_id}/contact", headers=lecteur)
    assert response.status_code == 404


def test_le_blocage_ferme_aussi_le_contact_par_publicite(client):
    auth_headers(client, "annonceur@example.com")
    admin = auth_headers(client, "admin@example.com", UserRole.ADMIN)
    lecteur = auth_headers(client, "lecteur@example.com")
    ad_id = _seed_paid_ad()
    _diffuser(client, admin, ad_id)
    with TestingSessionLocal() as db:
        annonceur = db.query(User).filter(User.email == "annonceur@example.com").one()
        moi = db.query(User).filter(User.email == "lecteur@example.com").one()
        db.add(Contact(owner_user_id=annonceur.id, contact_user_id=moi.id, phone="+22890000001", display_name="X", is_blocked=True))
        db.commit()

    response = client.post(f"/api/v1/marketplace/ads/{ad_id}/contact", headers=lecteur)
    assert response.status_code == 403
    with TestingSessionLocal() as db:
        assert db.query(DirectMessage).count() == 0


def test_on_ne_contacte_pas_sa_propre_publicite(client):
    annonceur = auth_headers(client, "annonceur@example.com")
    admin = auth_headers(client, "admin@example.com", UserRole.ADMIN)
    ad_id = _seed_paid_ad()
    _diffuser(client, admin, ad_id)

    response = client.post(f"/api/v1/marketplace/ads/{ad_id}/contact", headers=annonceur)
    assert response.status_code == 400


def test_on_ne_peut_pas_diffuser_une_campagne_impayee(client):
    auth_headers(client, "annonceur@example.com")
    admin = auth_headers(client, "admin@example.com", UserRole.ADMIN)
    ad_id = _seed_paid_ad()  # reste en PENDING, paiement jamais confirmé

    response = client.put(
        f"/api/v1/admin/marketplace/ads/{ad_id}",
        json={"approved": True, "duration_days": 7},
        headers=admin,
    )
    assert response.status_code == 409


# ── Modération des produits ──────────────────────────────────────────────


def test_desactiver_un_produit_le_retire_sans_l_effacer(client):
    seller = auth_headers(client, "vendeur@example.com")
    admin = auth_headers(client, "admin@example.com", UserRole.ADMIN)
    with TestingSessionLocal() as db:
        seller_row = db.query(User).filter(User.email == "vendeur@example.com").one()
        product = MarketplaceProduct(seller_id=seller_row.id, name="Ciment", price=5500)
        db.add(product)
        db.commit()
        product_id = product.id

    response = client.put(
        f"/api/v1/admin/marketplace/products/{product_id}",
        json={"is_active": False, "reason": "Produit interdit"},
        headers=admin,
    )
    assert response.status_code == 200
    assert response.json()["is_active"] is False

    with TestingSessionLocal() as db:
        # Toujours là : supprimer effacerait aussi les conversations qui le
        # citent, et priverait l'équipe de la trace d'une annonce retirée —
        # exactement ce qu'il faut montrer quand un vendeur conteste.
        assert db.query(MarketplaceProduct).filter(MarketplaceProduct.id == product_id).one()

    assert seller  # le vendeur existe, la fixture a bien tourné


# ── Vue d'ensemble ───────────────────────────────────────────────────────


def test_la_vue_d_ensemble_compte_ce_qui_attend_une_decision(client):
    auth_headers(client, "vendeur@example.com")
    admin = auth_headers(client, "admin@example.com", UserRole.ADMIN)
    _seed_verification()

    overview = client.get("/api/v1/admin/marketplace/overview", headers=admin).json()
    # Les compteurs « en attente » viennent en premier : ce sont les seuls
    # qui réclament une action. Un dossier oublié, c'est un vendeur qui a
    # payé 5 000 FCFA et attend.
    assert overview["pending"]["verifications"] == 1
    assert overview["revenue"]["VERIFICATION"]["amount"] == 5000
    assert overview["revenue_total"] == 5000


# ── Tarification ─────────────────────────────────────────────────────────


def test_le_tarif_d_une_publicite_est_decide_par_le_serveur(client):
    """Le montant arrivait du CLIENT.

    `AdCreate.amount` était un champ de la requête, borné à 1 000 FCFA au
    minimum : n'importe qui pouvait publier une campagne à un dixième du
    tarif en changeant une valeur. Rien ne l'aurait signalé — le paiement
    aboutit, la campagne s'affiche, seul le montant encaissé est faux. Un
    tarif ne se demande pas au payeur.
    """
    from app.services.marketplace.marketplace_monetization_service import ad_amount_for

    advertiser = auth_headers(client, "annonceur@example.com")
    # Mobile Money exige un numéro : sans lui la création s'arrête avant
    # d'arriver au calcul du tarif, et le test passerait à côté de ce qu'il
    # vérifie.
    with TestingSessionLocal() as db:
        user = db.query(User).filter(User.email == "annonceur@example.com").one()
        user.phone = "+22890001122"
        db.commit()

    response = client.post(
        "/api/v1/marketplace/ads",
        json={
            "title": "Promo",
            "body": "Offre",
            "duration_days": 7,
            # Une tentative de fixer soi-même le prix : le champ n'existe
            # plus au schéma, la valeur est donc simplement ignorée.
            "amount": 1000,
        },
        headers=advertiser,
    )
    assert response.status_code == 200, response.text

    with TestingSessionLocal() as db:
        payment = (
            db.query(MarketplacePayment)
            .filter(MarketplacePayment.id == response.json()["payment_id"])
            .one()
        )
    assert payment.amount == ad_amount_for(7) == 10000


def test_le_tarif_suit_la_duree_par_semaine_entamee():
    from app.services.marketplace.marketplace_monetization_service import ad_amount_for

    # Arrondi à la semaine entamée : huit jours coûtent deux semaines.
    # Découper plus finement inviterait à optimiser la durée plutôt qu'à
    # réfléchir à la campagne.
    assert ad_amount_for(1) == 10000
    assert ad_amount_for(7) == 10000
    assert ad_amount_for(8) == 20000
    assert ad_amount_for(14) == 20000
    assert ad_amount_for(30) == 50000


def test_la_moderation_ne_ressuscite_pas_une_annonce_supprimee_par_son_vendeur(client):
    """`deleted_at` et `is_active` ne se défont pas de la même main.

    Les deux retirent l'annonce du marché, et il serait tentant de n'avoir
    qu'un seul drapeau. Mais remettre en ligne, depuis l'administration, une
    annonce que son vendeur a supprimée la republierait SOUS SON NOM sans
    qu'il en sache rien.
    """
    from datetime import datetime as dt

    seller = auth_headers(client, "vendeur@example.com")
    admin = auth_headers(client, "admin@example.com", UserRole.ADMIN)
    with TestingSessionLocal() as db:
        seller_row = db.query(User).filter(User.email == "vendeur@example.com").one()
        product = MarketplaceProduct(
            seller_id=seller_row.id, name="Ciment", price=5500, deleted_at=dt.utcnow()
        )
        db.add(product)
        db.commit()
        product_id = product.id

    response = client.put(
        f"/api/v1/admin/marketplace/products/{product_id}",
        json={"is_active": True},
        headers=admin,
    )
    assert response.status_code == 409

    # L'équipe la VOIT toujours — la trace est conservée, et c'est elle qu'il
    # faut pouvoir montrer en cas de litige.
    items = client.get("/api/v1/admin/marketplace/products", headers=admin).json()["items"]
    row = next(p for p in items if p["id"] == product_id)
    assert row["deleted_by_seller"] is True
    assert seller  # la fixture a bien créé le vendeur


def test_un_vendeur_ne_remet_pas_en_ligne_ce_que_la_moderation_a_retire(client):
    """`is_active` appartient à la modération, et à elle seule.

    Il figurait dans le schéma du PATCH VENDEUR. L'application mobile ne
    l'envoyait pas, mais une API ouverte n'a pas le droit de compter sur la
    politesse de ses clients : il suffisait d'un `{"is_active": true}` sur
    sa propre annonce pour annuler la décision de l'équipe, sans trace et
    sans que personne en soit averti.

    Le champ a quitté le schéma. Le PATCH continue de servir à tout le
    reste — c'est ce que la seconde moitié du test vérifie, car retirer un
    champ d'un modèle Pydantic est exactement le genre de correction qui
    casse silencieusement les champs voisins.
    """
    seller = auth_headers(client, "vendeur@example.com")
    admin = auth_headers(client, "admin@example.com", UserRole.ADMIN)
    with TestingSessionLocal() as db:
        seller_row = db.query(User).filter(User.email == "vendeur@example.com").one()
        product = MarketplaceProduct(seller_id=seller_row.id, name="Ciment", price=5500)
        db.add(product)
        db.commit()
        product_id = product.id

    # La modération retire l'annonce.
    assert client.put(
        f"/api/v1/admin/marketplace/products/{product_id}",
        json={"is_active": False},
        headers=admin,
    ).status_code == 200

    # Le vendeur tente de la remettre en ligne par son propre PATCH.
    reponse = client.patch(
        f"/api/v1/marketplace/{product_id}",
        json={"name": "Ciment", "price": "5500", "is_active": True},
        headers=seller,
    )
    assert reponse.status_code == 200  # le PATCH lui-même reste légitime
    with TestingSessionLocal() as db:
        assert db.query(MarketplaceProduct).get(product_id).is_active is False

    # …et le reste du PATCH fonctionne toujours.
    assert reponse.json()["name"] == "Ciment"
    modifie = client.patch(
        f"/api/v1/marketplace/{product_id}",
        json={"name": "Ciment 50 kg", "price": "6000"},
        headers=seller,
    ).json()
    assert modifie["name"] == "Ciment 50 kg"
    assert str(modifie["price"]) in ("6000", "6000.00", "6000.0")


# ── Accès à la pièce d'identité ──────────────────────────────────────────


def test_l_equipe_peut_ouvrir_la_piece_d_identite_d_un_dossier(client):
    """C'est LA branche qui manquait à `media.py::_can_access`.

    L'écran listait les dossiers, et ouvrir le document renvoyait 404 : une
    file d'attente qu'on peut voir mais pas instruire. Sixième occurrence de
    la même classe de bug dans ce fichier — un média rattaché à un objet dont
    le contrôle d'accès n'avait pas de branche.
    """
    auth_headers(client, "vendeur@example.com")
    admin = auth_headers(client, "admin@example.com", UserRole.ADMIN)
    _seed_verification()

    row = client.get("/api/v1/admin/marketplace/verifications", headers=admin).json()["items"][0]
    # L'admin passe par le rewrite Next `/api/:path*` → `<API>/api/v1/:path*`.
    # Une URL `/api/v1/media/5` y devenait `/api/v1/v1/media/5` : un `/v1` en
    # double, et un 404 que rien n'explique.
    assert row["identity_media_url"].startswith("/api/media/")
    assert "/api/v1/" not in row["identity_media_url"]

    media_id = int(row["identity_media_url"].rsplit("/", 1)[1])
    assert client.get(f"/api/v1/media/{media_id}", headers=admin).status_code == 200


def test_un_utilisateur_ordinaire_ne_peut_PAS_ouvrir_une_piece_d_identite(client):
    """L'ouverture large serait bien pire que le 404.

    Ce sont des cartes d'identité : l'accès est limité aux rôles d'équipe ET
    au seul document rattaché à un dossier.
    """
    auth_headers(client, "vendeur@example.com")
    admin = auth_headers(client, "admin@example.com", UserRole.ADMIN)
    curieux = auth_headers(client, "curieux@example.com")
    _seed_verification()

    row = client.get("/api/v1/admin/marketplace/verifications", headers=admin).json()["items"][0]
    media_id = int(row["identity_media_url"].rsplit("/", 1)[1])

    assert client.get(f"/api/v1/media/{media_id}", headers=curieux).status_code == 404


def test_le_vendeur_garde_l_acces_a_sa_propre_piece(client):
    seller = auth_headers(client, "vendeur@example.com")
    admin = auth_headers(client, "admin@example.com", UserRole.ADMIN)
    _seed_verification()

    row = client.get("/api/v1/admin/marketplace/verifications", headers=admin).json()["items"][0]
    media_id = int(row["identity_media_url"].rsplit("/", 1)[1])

    # Par la branche `uploader_id`, qui existait déjà : on ne perd pas accès
    # à son propre document parce qu'on l'a soumis.
    assert client.get(f"/api/v1/media/{media_id}", headers=seller).status_code == 200
