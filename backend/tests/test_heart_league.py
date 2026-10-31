"""Heart League — le classement de bout en bout.

Les règles elles-mêmes sont testées sans base dans
`test_heart_league_rules.py`. Ce fichier vérifie ce qui ne peut l'être
qu'avec des routes : le verrou du module, le fait qu'un paiement n'accorde
rien avant d'être confirmé, et qu'il n'accorde pas deux fois.
"""
import re
from datetime import datetime, timedelta
from unittest.mock import patch

import pytest
from fastapi.testclient import TestClient
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker

from app.core.database import Base, get_db
from app.main import app
from app.models import AppModule, HeartLeagueProfile, MarketplacePayment, User, UserModuleActivation
from app.services.auth import otp_service
from app.services.marketplace.marketplace_monetization_service import confirm_payment

TEST_DATABASE_URL = "sqlite:///./test_heart_league.db"

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


@pytest.fixture(autouse=True)
def stub_mobile_money():
    """Semoa n'est pas configuré en test, et n'a rien à faire ici.

    Ces tests vérifient ce que Pokou fait d'un paiement CONFIRMÉ, pas la
    passerelle qui l'encaisse. Sans ce double, ils échoueraient sur une
    absence d'identifiants — c'est-à-dire pour une raison sans rapport avec
    ce qu'ils décrivent.
    """
    from app.services.marketplace import marketplace_monetization_service as service

    with patch.object(service, "semoa_client") as gateway:
        gateway.create_order.return_value = {
            "reference": "ref-test",
            "payment_url": "https://exemple.test/payer",
        }
        gateway.build_callback_url.return_value = "https://exemple.test/webhook"
        yield gateway


def _signup(client, phone):
    with patch.object(otp_service.sms_service, "send_sms", return_value=True) as mock_send:
        client.post("/api/v1/auth/phone/request-otp", json={"phone": phone})
    code = re.search(r"\b(\d{6})\b", mock_send.call_args.args[2]).group(1)
    body = client.post("/api/v1/auth/phone/verify-otp", json={"phone": phone, "code": code}).json()
    client.cookies.clear()
    return {"Authorization": f"Bearer {body['access_token']}"}, body["user"]["id"]


def _open_module(enabled=True):
    with TestingSessionLocal() as db:
        module = db.query(AppModule).filter(AppModule.slug == "heart_league").first()
        if module is None:
            module = AppModule(
                slug="heart_league", name="Heart League", tagline="…",
                description="…", icon="emoji_events", accent_color="#D4AF37",
                category="SOCIAL", is_enabled=enabled,
            )
            db.add(module)
        else:
            module.is_enabled = enabled
        db.commit()
        return module.id


def _activate(user_id, module_id):
    with TestingSessionLocal() as db:
        db.add(UserModuleActivation(user_id=user_id, module_id=module_id))
        db.commit()


def _set_points(user_id, points):
    with TestingSessionLocal() as db:
        profile = db.query(HeartLeagueProfile).filter(
            HeartLeagueProfile.user_id == user_id
        ).first()
        if profile is None:
            # `best_points` explicite : la valeur par défaut de la colonne
            # n'est appliquée qu'à l'insertion, et le `max()` ci-dessous
            # tomberait sur None avant le flush.
            profile = HeartLeagueProfile(
                user_id=user_id, week_start=datetime.utcnow(),
                points=0, best_points=0,
            )
            db.add(profile)
        profile.points = points
        profile.best_points = max(profile.best_points or 0, points)
        db.commit()


# ── Le verrou du module ──────────────────────────────────────────────────


def test_le_module_non_active_rend_les_routes_muettes(client):
    headers, user_id = _signup(client, "+22895000001")
    _open_module()
    # Ouvert par l'équipe, mais pas activé par la personne.
    assert client.get("/api/v1/heart-league/me", headers=headers).status_code == 404


def test_le_module_ferme_par_l_equipe_coupe_l_acces_meme_si_active(client):
    """Sans cette vérification, une fonctionnalité fermée resterait
    joignable par appel direct à l'API — et l'interrupteur d'équipe ne
    servirait plus à rien au moment précis où il doit servir."""
    headers, user_id = _signup(client, "+22895000002")
    module_id = _open_module(enabled=True)
    _activate(user_id, module_id)
    assert client.get("/api/v1/heart-league/me", headers=headers).status_code == 200

    _open_module(enabled=False)
    assert client.get("/api/v1/heart-league/me", headers=headers).status_code == 404


# ── Le classement ────────────────────────────────────────────────────────


def test_un_nouveau_joueur_demarre_en_bronze_sans_erreur(client):
    headers, user_id = _signup(client, "+22895000003")
    _activate(user_id, _open_module())

    me = client.get("/api/v1/heart-league/me", headers=headers).json()
    # Le cas du tout premier écran : sans profil créé à la volée, il n'y
    # aurait rien à afficher au moment où il faut convaincre.
    assert me["points"] == 0
    assert me["league"]["code"] == "BRONZE"
    assert me["next_league"]["code"] == "ARGENT"
    assert me["is_protected"] is False


def test_je_vois_ma_place_meme_hors_du_classement_affiche(client):
    """Un classement où l'on ne se voit pas ne dit rien à celui qui le
    consulte — et c'est précisément lui qu'on cherche à faire revenir."""
    module_id = _open_module()
    for index, phone in enumerate(["+2289500001%d" % i for i in range(4)]):
        headers, user_id = _signup(client, phone)
        _activate(user_id, module_id)
        _set_points(user_id, 1000 - index * 100)

    last, last_id = _signup(client, "+22895000020")
    _activate(last_id, module_id)
    _set_points(last_id, 5)

    board = client.get("/api/v1/heart-league/leaderboard?limit=2", headers=last).json()
    assert len(board["items"]) == 2
    assert board["my_rank"] == 5
    assert board["my_points"] == 5


# ── Le laissez-passer ────────────────────────────────────────────────────


def test_ecrire_a_un_voisin_de_classement_ne_coute_rien(client):
    module_id = _open_module()
    mine, my_id = _signup(client, "+22895000030")
    _activate(my_id, module_id)
    _set_points(my_id, 150)  # Argent
    _other, other_id = _signup(client, "+22895000031")
    _set_points(other_id, 600)  # Or — un seul cran

    response = client.get(f"/api/v1/heart-league/can-write/{other_id}", headers=mine).json()
    assert response["allowed"] is True
    assert response["needs_pass"] is False


def test_deux_crans_d_ecart_demandent_un_pass(client):
    module_id = _open_module()
    mine, my_id = _signup(client, "+22895000032")
    _activate(my_id, module_id)
    _set_points(my_id, 0)  # Bronze
    _other, other_id = _signup(client, "+22895000033")
    _set_points(other_id, 6000)  # Couronne

    response = client.get(f"/api/v1/heart-league/can-write/{other_id}", headers=mine).json()
    assert response["allowed"] is False
    assert response["needs_pass"] is True
    assert response["target_league"] == "Couronne"


def test_un_pass_n_est_accorde_qu_APRES_paiement(client):
    """Accorder avant que l'argent n'arrive le rendrait gratuit pour qui
    abandonne à l'écran de paiement."""
    module_id = _open_module()
    mine, my_id = _signup(client, "+22895000034")
    _activate(my_id, module_id)
    _set_points(my_id, 0)
    _other, other_id = _signup(client, "+22895000035")
    _set_points(other_id, 6000)

    created = client.post(f"/api/v1/heart-league/pass/{other_id}", headers=mine)
    assert created.status_code == 200, created.text

    # Paiement en attente : rien n'est encore ouvert.
    assert client.get(
        f"/api/v1/heart-league/can-write/{other_id}", headers=mine
    ).json()["allowed"] is False

    with TestingSessionLocal() as db:
        payment = db.query(MarketplacePayment).filter(
            MarketplacePayment.id == created.json()["payment_id"]
        ).one()
        payment.provider_reference = "ref-pass-1"
        db.commit()
        confirm_payment(db, "ref-pass-1")

    assert client.get(
        f"/api/v1/heart-league/can-write/{other_id}", headers=mine
    ).json()["allowed"] is True


def test_un_webhook_rejoue_n_accorde_pas_deux_fois(client):
    """Les passerelles Mobile Money rappellent leur webhook en cas de doute.

    Sans verrou, deux semaines de protection seraient accordées pour une
    seule payée.
    """
    module_id = _open_module()
    mine, my_id = _signup(client, "+22895000036")
    _activate(my_id, module_id)
    with TestingSessionLocal() as db:
        db.query(User).filter(User.id == my_id).update({"phone": "+22890001133"})
        db.commit()

    created = client.post("/api/v1/heart-league/protection", headers=mine).json()
    with TestingSessionLocal() as db:
        payment = db.query(MarketplacePayment).filter(
            MarketplacePayment.id == created["payment_id"]
        ).one()
        payment.provider_reference = "ref-protection-1"
        db.commit()
        confirm_payment(db, "ref-protection-1")
        first = db.query(HeartLeagueProfile).filter(
            HeartLeagueProfile.user_id == my_id
        ).one().protected_until
        confirm_payment(db, "ref-protection-1")
        second = db.query(HeartLeagueProfile).filter(
            HeartLeagueProfile.user_id == my_id
        ).one().protected_until

    assert first == second


def test_la_protection_achetee_apparait_dans_mon_profil(client):
    module_id = _open_module()
    mine, my_id = _signup(client, "+22895000037")
    _activate(my_id, module_id)
    with TestingSessionLocal() as db:
        profile = HeartLeagueProfile(
            user_id=my_id, week_start=datetime.utcnow(),
            protected_until=datetime.utcnow() + timedelta(days=5),
        )
        db.add(profile)
        db.commit()

    me = client.get("/api/v1/heart-league/me", headers=mine).json()
    assert me["is_protected"] is True
    assert me["protected_until"] is not None


def test_on_ne_s_achete_pas_un_pass_vers_soi_meme(client):
    module_id = _open_module()
    mine, my_id = _signup(client, "+22895000038")
    _activate(my_id, module_id)
    assert client.post(f"/api/v1/heart-league/pass/{my_id}", headers=mine).status_code == 400
