"""Catégories et devises du marché — réglées depuis l'admin.

Ce qu'elles remplacent : une liste Dart écrite en dur dans l'application, et
un champ de texte libre pour la devise. Ajouter une catégorie demandait une
publication Play Store ; et « XOF », « FCFA », « fcfa », « CFA » désignaient
la même monnaie sans jamais se comparer.

Trois propriétés tiennent ce fichier, et aucune n'est cosmétique :

- **une configuration absente ne vide jamais le marché.** Tant qu'aucun
  administrateur n'a rien enregistré — ou si ce qui est en base est
  illisible — le marché sert exactement les catégories historiques. Des
  filtres vides seraient pires que des filtres figés ;
- **on ne peut pas se couper le marché sous les pieds.** Zéro catégorie
  active, zéro devise active, deux devises par défaut : refusés ;
- **le serveur décide de la devise, pas le menu déroulant.** Un client qui
  poste « BTC » est refusé, même si l'application ne l'offre pas.
"""
import json

import pytest
from fastapi.testclient import TestClient
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker

from app.core.database import Base, get_db
from app.main import app
from app.models import MediaAsset, SystemSetting, User, UserRole
from app.services.marketplace import marketplace_config_service as config
from tests.helpers import bearer_for_email

TEST_DATABASE_URL = "sqlite:///./test_marketplace_config.db"

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
            db.add(
                User(
                    email=email,
                    full_name=email.split("@")[0].title(),
                    role=role,
                )
            )
            db.commit()
    finally:
        db.close()
    client.cookies.clear()
    return bearer_for_email(TestingSessionLocal, email)


def _seed_media(email: str) -> int:
    """Une pièce d'identité téléversée, comme après un passage par l'app."""
    db = TestingSessionLocal()
    try:
        user = db.query(User).filter(User.email == email).first()
        # Mobile Money exige un numéro : sans lui, `create_payment` refuse
        # avant même d'avoir regardé la formule, et le test confondrait
        # « formule inconnue » avec « compte incomplet ».
        if not user.phone:
            user.phone = "+22890000001"
        media = MediaAsset(
            uploader_id=user.id,
            storage_path=f"cni-{user.id}.jpg",
            storage_backend="local",
            mime_type="image/jpeg",
            size_bytes=4,
        )
        db.add(media)
        db.commit()
        return media.id
    finally:
        db.close()


# ── Le repli ──────────────────────────────────────────────────────────────


def test_sans_configuration_le_marche_garde_ses_categories_historiques(client):
    entetes = auth_headers(client, "acheteur@example.com")
    reponse = client.get("/api/v1/marketplace/config", headers=entetes)
    assert reponse.status_code == 200

    slugs = [c["slug"] for c in reponse.json()["categories"]]
    assert slugs == ["TELEPHONES", "MODE", "MAISON", "SERVICES", "AUTRE"]
    devises = reponse.json()["currencies"]
    assert devises == [{"code": "XOF", "label": "FCFA", "default": True}]


def test_une_configuration_illisible_ne_vide_pas_le_marche(client):
    """Du JSON cassé en base doit dégrader vers le défaut, pas vers le vide.

    C'est le pire cas de cette fonctionnalité : une liste vide rendrait la
    barre de filtres et le formulaire d'annonce inutilisables sur TOUS les
    téléphones à la fois, sans qu'aucun d'eux ait de recours.
    """
    db = TestingSessionLocal()
    try:
        db.add(SystemSetting(key=config.CLE_CATEGORIES, value="{ceci n'est pas du JSON"))
        db.commit()
    finally:
        db.close()

    entetes = auth_headers(client, "acheteur@example.com")
    reponse = client.get("/api/v1/marketplace/config", headers=entetes)
    assert reponse.status_code == 200
    assert [c["slug"] for c in reponse.json()["categories"]] == [
        "TELEPHONES",
        "MODE",
        "MAISON",
        "SERVICES",
        "AUTRE",
    ]


# ── L'écriture depuis l'admin ─────────────────────────────────────────────


def test_un_admin_regle_les_categories_et_le_marche_les_sert(client):
    admin = auth_headers(client, "admin@example.com", UserRole.SUPER_ADMIN)
    reponse = client.put(
        "/api/v1/admin/marketplace/config",
        json={
            "categories": [
                {"slug": "motos", "label": "Motos", "active": True},
                {"slug": "GROSSISTE", "label": "Grossistes", "active": False},
            ]
        },
        headers=admin,
    )
    assert reponse.status_code == 200
    # Le slug est normalisé en majuscules — l'admin n'a pas à y penser.
    assert reponse.json()["categories"][0]["slug"] == "MOTOS"

    public = client.get(
        "/api/v1/marketplace/config",
        headers=auth_headers(client, "acheteur@example.com"),
    ).json()
    # La route publique ne sert QUE l'actif : une catégorie désactivée ne
    # doit plus apparaître dans les filtres du marché.
    assert [c["slug"] for c in public["categories"]] == ["MOTOS"]

    # …mais l'admin doit continuer à la voir, sinon il ne peut plus la
    # réactiver.
    complet = client.get("/api/v1/admin/marketplace/config", headers=admin).json()
    assert [c["slug"] for c in complet["categories"]] == ["MOTOS", "GROSSISTE"]


def test_une_liste_absente_reste_inchangee(client):
    """Enregistrer les catégories ne doit pas effacer les devises."""
    admin = auth_headers(client, "admin@example.com", UserRole.SUPER_ADMIN)
    client.put(
        "/api/v1/admin/marketplace/config",
        json={"currencies": [{"code": "EUR", "label": "€", "active": True, "default": True}]},
        headers=admin,
    )
    client.put(
        "/api/v1/admin/marketplace/config",
        json={"categories": [{"slug": "MOTOS", "label": "Motos", "active": True}]},
        headers=admin,
    )
    complet = client.get("/api/v1/admin/marketplace/config", headers=admin).json()
    assert [d["code"] for d in complet["currencies"]] == ["EUR"]


def test_on_ne_peut_pas_desactiver_toutes_les_categories(client):
    admin = auth_headers(client, "admin@example.com", UserRole.SUPER_ADMIN)
    reponse = client.put(
        "/api/v1/admin/marketplace/config",
        json={"categories": [{"slug": "MOTOS", "label": "Motos", "active": False}]},
        headers=admin,
    )
    assert reponse.status_code == 422
    assert "active" in reponse.json()["detail"]


def test_tout_est_reserve_au_filtre_toutes_categories(client):
    admin = auth_headers(client, "admin@example.com", UserRole.SUPER_ADMIN)
    reponse = client.put(
        "/api/v1/admin/marketplace/config",
        json={"categories": [{"slug": "TOUT", "label": "Tout", "active": True}]},
        headers=admin,
    )
    assert reponse.status_code == 422


def test_une_seule_devise_par_defaut(client):
    admin = auth_headers(client, "admin@example.com", UserRole.SUPER_ADMIN)
    reponse = client.put(
        "/api/v1/admin/marketplace/config",
        json={
            "currencies": [
                {"code": "XOF", "label": "FCFA", "active": True, "default": True},
                {"code": "EUR", "label": "€", "active": True, "default": True},
            ]
        },
        headers=admin,
    )
    assert reponse.status_code == 422


def test_sans_devise_par_defaut_la_premiere_active_le_devient(client):
    """Le formulaire d'annonce doit toujours pouvoir pré-remplir une devise."""
    admin = auth_headers(client, "admin@example.com", UserRole.SUPER_ADMIN)
    reponse = client.put(
        "/api/v1/admin/marketplace/config",
        json={
            "currencies": [
                {"code": "XOF", "label": "FCFA", "active": True, "default": False},
                {"code": "EUR", "label": "€", "active": True, "default": False},
            ]
        },
        headers=admin,
    )
    assert reponse.status_code == 200
    assert reponse.json()["currencies"][0]["default"] is True


def test_un_simple_utilisateur_ne_regle_pas_le_marche(client):
    entetes = auth_headers(client, "vendeur@example.com")
    reponse = client.put(
        "/api/v1/admin/marketplace/config",
        json={"categories": [{"slug": "MOTOS", "label": "Motos", "active": True}]},
        headers=entetes,
    )
    assert reponse.status_code in (401, 403)


# ── La devise d'une annonce ───────────────────────────────────────────────


def test_une_devise_hors_liste_est_refusee_a_la_publication(client):
    """Le contrôle est côté serveur, pas seulement dans le menu déroulant.

    Le champ était libre : rien n'empêchait de publier un prix en « BTC »,
    ni d'écrire « fcfa » là où le voisin écrivait « XOF ». Deux prix dans
    deux orthographes de la même monnaie ne s'additionnent pas.
    """
    entetes = auth_headers(client, "vendeur@example.com")
    reponse = client.post(
        "/api/v1/marketplace",
        json={
            "name": "Vélo",
            "description": "Bon état",
            "price": "50000",
            "currency": "BTC",
        },
        headers=entetes,
    )
    assert reponse.status_code == 422
    assert "BTC" in reponse.json()["detail"]


def test_la_devise_par_defaut_passe(client):
    entetes = auth_headers(client, "vendeur@example.com")
    reponse = client.post(
        "/api/v1/marketplace",
        json={
            "name": "Vélo",
            "description": "Bon état",
            "price": "50000",
            "currency": "XOF",
        },
        headers=entetes,
    )
    assert reponse.status_code == 200, reponse.text


def test_une_devise_ouverte_par_l_admin_devient_publiable(client):
    admin = auth_headers(client, "admin@example.com", UserRole.SUPER_ADMIN)
    client.put(
        "/api/v1/admin/marketplace/config",
        json={
            "currencies": [
                {"code": "XOF", "label": "FCFA", "active": True, "default": True},
                {"code": "GHS", "label": "GH₵", "active": True, "default": False},
            ]
        },
        headers=admin,
    )
    vendeur = auth_headers(client, "vendeur@example.com")
    reponse = client.post(
        "/api/v1/marketplace",
        json={
            "name": "Sac",
            "description": "Cuir",
            "price": "12000",
            "currency": "GHS",
        },
        headers=vendeur,
    )
    assert reponse.status_code == 200, reponse.text


# ── Le service, hors HTTP ─────────────────────────────────────────────────


def test_les_slugs_et_les_codes_sont_normalises():
    propre = config.valider_categories([{"slug": " motos ", "label": " Motos "}])
    assert propre == [{"slug": "MOTOS", "label": "Motos", "active": True}]

    devises = config.valider_devises([{"code": "ghs", "label": "GH₵"}])
    assert devises[0]["code"] == "GHS"


def test_un_slug_en_double_est_refuse():
    with pytest.raises(config.ConfigurationInvalide):
        config.valider_categories(
            [{"slug": "MOTOS", "label": "Motos"}, {"slug": "motos", "label": "Deux-roues"}]
        )


def test_une_devise_inactive_ne_peut_pas_etre_celle_par_defaut():
    devises = config.valider_devises(
        [
            {"code": "XOF", "label": "FCFA", "active": True},
            {"code": "EUR", "label": "€", "active": False, "default": True},
        ]
    )
    assert {d["code"]: d["default"] for d in devises} == {"XOF": True, "EUR": False}


def test_la_configuration_enregistree_est_du_json_relisible(client):
    admin = auth_headers(client, "admin@example.com", UserRole.SUPER_ADMIN)
    client.put(
        "/api/v1/admin/marketplace/config",
        json={"categories": [{"slug": "MOTOS", "label": "Motos", "active": True}]},
        headers=admin,
    )
    db = TestingSessionLocal()
    try:
        brut = (
            db.query(SystemSetting)
            .filter(SystemSetting.key == config.CLE_CATEGORIES)
            .first()
        )
        assert json.loads(brut.value)[0]["slug"] == "MOTOS"
    finally:
        db.close()


# ── Formules de vérification ──────────────────────────────────────────────


def test_la_formule_par_defaut_reprend_le_tarif_existant(client):
    """Sans configuration, ce sont les deux formules du cahier des charges :
    mensuelle à 3 000 FCFA, annuelle à 30 000 FCFA (proposée par défaut)."""
    entetes = auth_headers(client, "acheteur@example.com")
    formules = client.get("/api/v1/marketplace/config", headers=entetes).json()[
        "verification_plans"
    ]
    assert [(f["code"], f["amount"], f["duration_days"], f["default"]) for f in formules] == [
        ("MONTHLY", 3000, 30, False),
        ("ANNUAL", 30000, 365, True),
    ]


def test_le_client_ne_choisit_jamais_le_montant(client):
    """Le corps de la requête ne porte qu'un CODE.

    C'est la leçon des campagnes publicitaires, où le prix arrivait de la
    requête : n'importe qui pouvait s'offrir une semaine de diffusion au
    dixième du tarif sans que rien ne le signale.
    """
    admin = auth_headers(client, "admin@example.com", UserRole.SUPER_ADMIN)
    client.put(
        "/api/v1/admin/marketplace/config",
        json={
            "verification_plans": [
                {
                    "code": "ANNUAL",
                    "label": "1 an",
                    "description": "",
                    "amount": 5000,
                    "active": True,
                    "default": True,
                },
                {
                    "code": "PREMIUM",
                    "label": "Premium",
                    "description": "",
                    "amount": 20000,
                    "active": True,
                    "default": False,
                },
            ]
        },
        headers=admin,
    )

    vendeur_entetes = auth_headers(client, "vendeur@example.com")
    media_id = _seed_media("vendeur@example.com")
    reponse = client.post(
        "/api/v1/marketplace/verification",
        json={"identity_media_id": media_id, "plan": "PREMIUM", "amount": 1},
        headers=vendeur_entetes,
    )
    assert reponse.status_code == 200, reponse.text
    # « amount: 1 » dans la requête est ignoré : c'est le tarif de la
    # formule qui est facturé.
    assert reponse.json()["amount"] == 20000


def test_une_formule_inconnue_est_refusee(client):
    vendeur_entetes = auth_headers(client, "vendeur@example.com")
    media_id = _seed_media("vendeur@example.com")
    reponse = client.post(
        "/api/v1/marketplace/verification",
        json={"identity_media_id": media_id, "plan": "GRATUIT"},
        headers=vendeur_entetes,
    )
    assert reponse.status_code == 422
    assert "GRATUIT" in reponse.json()["detail"]


def test_sans_formule_demandee_c_est_celle_par_defaut(client):
    vendeur_entetes = auth_headers(client, "vendeur@example.com")
    media_id = _seed_media("vendeur@example.com")
    reponse = client.post(
        "/api/v1/marketplace/verification",
        json={"identity_media_id": media_id},
        headers=vendeur_entetes,
    )
    assert reponse.status_code == 200, reponse.text
    assert reponse.json()["amount"] == 30000


def test_on_ne_peut_pas_desactiver_toutes_les_formules(client):
    admin = auth_headers(client, "admin@example.com", UserRole.SUPER_ADMIN)
    reponse = client.put(
        "/api/v1/admin/marketplace/config",
        json={
            "verification_plans": [
                {
                    "code": "ANNUAL",
                    "label": "1 an",
                    "description": "",
                    "amount": 5000,
                    "active": False,
                    "default": False,
                }
            ]
        },
        headers=admin,
    )
    assert reponse.status_code == 422


def test_les_anciennes_versions_de_l_app_publient_quand_meme(client):
    """Jusqu'à la 1.28.0, le formulaire envoyait les LIBELLÉS de ses menus :
    « FCFA (XOF) » pour la devise, « TÉLÉPHONES » pour la catégorie. La
    publication était refusée ; elle passe, et l'annonce est rangée sous les
    vrais codes."""
    entetes = auth_headers(client, "vendeur@example.com")
    reponse = client.post(
        "/api/v1/marketplace",
        json={
            "name": "Téléphone",
            "description": "Neuf",
            "price": "50000",
            "currency": "FCFA (XOF)",
            "category": "TÉLÉPHONES",
        },
        headers=entetes,
    )
    assert reponse.status_code == 200, reponse.text
    assert reponse.json()["currency"] == "XOF"
    assert reponse.json()["category"] == "TELEPHONES"


def test_une_categorie_libre_est_gardee(client):
    entetes = auth_headers(client, "vendeur@example.com")
    reponse = client.post(
        "/api/v1/marketplace",
        json={"name": "Igname", "price": "500", "currency": "xof", "category": "Vivrier"},
        headers=entetes,
    )
    assert reponse.status_code == 200, reponse.text
    assert reponse.json()["category"] == "VIVRIER"
    assert reponse.json()["currency"] == "XOF"
