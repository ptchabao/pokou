"""Les cinq modules monétisés, de bout en bout.

Ce qui est vérifié ici est ce qu'on ne peut pas vérifier sans routes : le
double verrou d'activation, le fait qu'une intention de paiement n'accorde
RIEN, et ce que chaque module fait une fois le paiement confirmé. Les
règles pures (chaînes, ligues) sont testées sans base ailleurs.
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
from app.models import AppModule, CeremonyFund, ConversationStreak, HypeTrain, MarketplacePayment, UserModuleActivation
from app.services.auth import otp_service
from app.services.marketplace.marketplace_monetization_service import confirm_payment

TEST_DATABASE_URL = "sqlite:///./test_pokou_modules.db"

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
    """Semoa n'est pas configuré en test, et n'a rien à faire ici."""
    from app.services.marketplace import marketplace_monetization_service as service

    with patch.object(service, "semoa_client") as gateway:
        gateway.create_order.return_value = {
            "reference": "ref-test",
            "payment_url": "https://exemple.test/payer",
        }
        gateway.build_callback_url.return_value = "https://exemple.test/webhook"
        yield gateway


_PHONE = iter(range(1000, 9999))


def _signup(client, phone=None):
    phone = phone or f"+2288{next(_PHONE)}000"
    with patch.object(otp_service.sms_service, "send_sms", return_value=True) as mock_send:
        client.post("/api/v1/auth/phone/request-otp", json={"phone": phone})
    code = re.search(r"\b(\d{6})\b", mock_send.call_args.args[2]).group(1)
    body = client.post("/api/v1/auth/phone/verify-otp", json={"phone": phone, "code": code}).json()
    client.cookies.clear()
    return {"Authorization": f"Bearer {body['access_token']}"}, body["user"]["id"], phone


def _send(client, headers, recipient_id, recipient_phone, content="salut"):
    """Envoie un message en PROUVANT qu'on connaît le numéro.

    Sans `recipient_phone`, le serveur refuse — c'est la règle qui empêche
    d'écrire à un inconnu en devinant son identifiant, et elle s'applique
    aussi aux tests.
    """
    return client.post(
        "/api/v1/messages",
        json={"recipient_id": recipient_id, "recipient_phone": recipient_phone, "content": content},
        headers=headers,
    )


def _open_module(slug, enabled=True):
    with TestingSessionLocal() as db:
        module = db.query(AppModule).filter(AppModule.slug == slug).first()
        if module is None:
            module = AppModule(
                slug=slug, name=slug, tagline="…", description="…",
                icon="extension", accent_color="#000000",
                category="SOCIAL", is_enabled=enabled,
            )
            db.add(module)
        else:
            module.is_enabled = enabled
        db.commit()
        return module.id


def _enable_for(slug, *user_ids):
    module_id = _open_module(slug)
    with TestingSessionLocal() as db:
        for user_id in user_ids:
            db.add(UserModuleActivation(user_id=user_id, module_id=module_id))
        db.commit()
    return module_id


def _confirm(payment_id):
    with TestingSessionLocal() as db:
        payment = db.query(MarketplacePayment).filter(
            MarketplacePayment.id == payment_id
        ).first()
        reference = payment.provider_reference
    return confirm_payment(TestingSessionLocal(), reference)


# ── Le verrou, pour les cinq ─────────────────────────────────────────────


@pytest.mark.parametrize(
    "slug,path",
    [
        ("truth_market", "/api/v1/truth/received"),
        ("social_tax", "/api/v1/ceremonies"),
        ("vip_room", "/api/v1/vip/rooms"),
        ("hype_train", "/api/v1/hype"),
        ("streak_lock", "/api/v1/streaks"),
    ],
)
def test_module_ferme_par_l_equipe_coupe_l_acces(client, slug, path):
    """Le refus doit venir du serveur, pas de l'absence de bouton."""
    headers, user_id, user_phone = _signup(client)
    _enable_for(slug, user_id)
    assert client.get(path, headers=headers).status_code == 200

    _open_module(slug, enabled=False)
    assert client.get(path, headers=headers).status_code == 404


# ── Truth Market ─────────────────────────────────────────────────────────


def test_une_question_n_arrive_qu_une_fois_payee(client):
    asker, asker_id, asker_phone = _signup(client)
    target, target_id, target_phone = _signup(client)
    _enable_for("truth_market", asker_id, target_id)

    created = client.post(
        "/api/v1/truth",
        json={"target_id": target_id, "question": "Pourquoi ?", "amount": 500},
        headers=asker,
    ).json()

    # Payée : rien. C'est tout l'intérêt de séparer l'intention de l'effet.
    assert client.get("/api/v1/truth/received", headers=target).json()["items"] == []

    _confirm(created["payment_id"])
    received = client.get("/api/v1/truth/received", headers=target).json()["items"]
    assert len(received) == 1
    assert received[0]["question"] == "Pourquoi ?"


def test_celui_qui_repond_ne_voit_pas_qui_demande(client):
    """L'anonymat de l'acheteur est ce qui rend la question posable."""
    asker, asker_id, asker_phone = _signup(client)
    target, target_id, target_phone = _signup(client)
    _enable_for("truth_market", asker_id, target_id)
    created = client.post(
        "/api/v1/truth",
        json={"target_id": target_id, "question": "Tu m'aimes ?", "amount": 500},
        headers=asker,
    ).json()
    _confirm(created["payment_id"])

    item = client.get("/api/v1/truth/received", headers=target).json()["items"][0]
    assert item["asker_name"] is None


def test_refuser_est_toujours_possible(client):
    asker, asker_id, asker_phone = _signup(client)
    target, target_id, target_phone = _signup(client)
    _enable_for("truth_market", asker_id, target_id)
    created = client.post(
        "/api/v1/truth",
        json={"target_id": target_id, "question": "Alors ?", "amount": 500},
        headers=asker,
    ).json()
    _confirm(created["payment_id"])
    question_id = created["question_id"]

    assert client.post(f"/api/v1/truth/{question_id}/decline", headers=target).status_code == 200
    # Et elle ne revient pas dans la pile.
    assert client.get("/api/v1/truth/received", headers=target).json()["items"] == []
    # Répondre après avoir refusé n'est plus possible.
    late = client.post(
        f"/api/v1/truth/{question_id}/answer", json={"answer": "Si"}, headers=target
    )
    assert late.status_code == 404


def test_la_reponse_ne_va_qu_a_celui_qui_a_paye(client):
    asker, asker_id, asker_phone = _signup(client)
    target, target_id, target_phone = _signup(client)
    intruder, intruder_id, intruder_phone = _signup(client)
    _enable_for("truth_market", asker_id, target_id, intruder_id)
    created = client.post(
        "/api/v1/truth",
        json={"target_id": target_id, "question": "Dis-moi", "amount": 500},
        headers=asker,
    ).json()
    _confirm(created["payment_id"])
    client.post(
        f"/api/v1/truth/{created['question_id']}/answer",
        json={"answer": "Voilà la vérité"},
        headers=target,
    )

    mine = client.get("/api/v1/truth/sent", headers=asker).json()["items"]
    assert mine[0]["answer"] == "Voilà la vérité"
    # Un tiers n'a rien dans sa liste : elle est filtrée sur l'acheteur.
    assert client.get("/api/v1/truth/sent", headers=intruder).json()["items"] == []


# ── Social Tax ───────────────────────────────────────────────────────────


def test_la_cagnotte_ne_compte_que_les_contributions_confirmees(client):
    organizer, organizer_id, organizer_phone = _signup(client)
    giver, giver_id, giver_phone = _signup(client)
    _enable_for("social_tax", organizer_id, giver_id)

    fund = client.post(
        "/api/v1/ceremonies",
        json={"title": "Mariage", "kind": "MARIAGE", "goal_amount": 100000},
        headers=organizer,
    ).json()
    created = client.post(
        f"/api/v1/ceremonies/{fund['id']}/contribute",
        json={"amount": 2000},
        headers=giver,
    ).json()

    detail = client.get(f"/api/v1/ceremonies/{fund['id']}", headers=organizer).json()
    assert detail["collected_amount"] == 0, "une cagnotte ne montre pas de l'argent non encaissé"

    _confirm(created["payment_id"])
    detail = client.get(f"/api/v1/ceremonies/{fund['id']}", headers=organizer).json()
    assert detail["collected_amount"] == 2000
    assert detail["contributor_count"] == 1


def test_l_anonymat_masque_le_nom_pas_le_montant(client):
    organizer, organizer_id, organizer_phone = _signup(client)
    giver, giver_id, giver_phone = _signup(client)
    _enable_for("social_tax", organizer_id, giver_id)
    fund = client.post(
        "/api/v1/ceremonies", json={"title": "Baptême", "kind": "BAPTEME"}, headers=organizer
    ).json()
    created = client.post(
        f"/api/v1/ceremonies/{fund['id']}/contribute",
        json={"amount": 300, "is_anonymous": True},
        headers=giver,
    ).json()
    _confirm(created["payment_id"])

    wall = client.get(f"/api/v1/ceremonies/{fund['id']}", headers=organizer).json()["contributors"]
    assert wall[0]["name"] is None
    # Le total doit rester vérifiable, sinon la cagnotte ne prouve rien.
    assert wall[0]["amount"] == 300


def test_une_cagnotte_cloturee_refuse_l_argent(client):
    organizer, organizer_id, organizer_phone = _signup(client)
    giver, giver_id, giver_phone = _signup(client)
    _enable_for("social_tax", organizer_id, giver_id)
    fund = client.post(
        "/api/v1/ceremonies", json={"title": "Deuil", "kind": "DEUIL"}, headers=organizer
    ).json()
    client.post(f"/api/v1/ceremonies/{fund['id']}/close", headers=organizer)

    refused = client.post(
        f"/api/v1/ceremonies/{fund['id']}/contribute", json={"amount": 500}, headers=giver
    )
    assert refused.status_code == 409


def test_seul_l_organisateur_cloture(client):
    organizer, organizer_id, organizer_phone = _signup(client)
    other, other_id, other_phone = _signup(client)
    _enable_for("social_tax", organizer_id, other_id)
    fund = client.post(
        "/api/v1/ceremonies", json={"title": "Mariage", "kind": "MARIAGE"}, headers=organizer
    ).json()
    assert client.post(f"/api/v1/ceremonies/{fund['id']}/close", headers=other).status_code == 403


# ── VIP Room ─────────────────────────────────────────────────────────────


def test_le_salon_reste_ferme_tant_que_l_abonnement_n_est_pas_paye(client):
    owner, owner_id, owner_phone = _signup(client)
    fan, fan_id, fan_phone = _signup(client)
    _enable_for("vip_room", owner_id, fan_id)

    room = client.put(
        "/api/v1/vip/room",
        json={"title": "Mon salon", "pitch": "Des coulisses tous les jours", "monthly_price": 2000},
        headers=owner,
    ).json()
    client.post("/api/v1/vip/posts", json={"text_content": "Secret"}, headers=owner)

    locked = client.get(f"/api/v1/vip/rooms/{room['id']}/posts", headers=fan).json()
    assert locked["locked"] is True
    assert locked["items"] == []
    # Mais le pitch est visible : sinon personne n'a de raison de payer.
    assert locked["room"]["pitch"] == "Des coulisses tous les jours"

    created = client.post(f"/api/v1/vip/rooms/{room['id']}/subscribe", headers=fan).json()
    assert client.get(f"/api/v1/vip/rooms/{room['id']}/posts", headers=fan).json()["locked"] is True

    _confirm(created["payment_id"])
    opened = client.get(f"/api/v1/vip/rooms/{room['id']}/posts", headers=fan).json()
    assert opened["locked"] is False
    assert [p["text_content"] for p in opened["items"]] == ["Secret"]


def test_renouveler_prolonge_au_lieu_de_repartir_de_zero(client):
    """Repartir de zéro punirait celui qui paie d'avance."""
    owner, owner_id, owner_phone = _signup(client)
    fan, fan_id, fan_phone = _signup(client)
    _enable_for("vip_room", owner_id, fan_id)
    room = client.put(
        "/api/v1/vip/room",
        json={"title": "Salon", "pitch": "Du contenu chaque jour", "monthly_price": 1000},
        headers=owner,
    ).json()

    first = client.post(f"/api/v1/vip/rooms/{room['id']}/subscribe", headers=fan).json()
    _confirm(first["payment_id"])
    after_first = client.get("/api/v1/vip/subscriptions", headers=fan).json()["items"][0]

    second = client.post(f"/api/v1/vip/rooms/{room['id']}/subscribe", headers=fan).json()
    _confirm(second["payment_id"])
    after_second = client.get("/api/v1/vip/subscriptions", headers=fan).json()["items"][0]

    gap = datetime.fromisoformat(after_second["expires_at"]) - datetime.fromisoformat(
        after_first["expires_at"]
    )
    assert gap > timedelta(days=29)


def test_un_abonnement_expire_referme_le_salon(client):
    owner, owner_id, owner_phone = _signup(client)
    fan, fan_id, fan_phone = _signup(client)
    _enable_for("vip_room", owner_id, fan_id)
    room = client.put(
        "/api/v1/vip/room",
        json={"title": "Salon", "pitch": "Du contenu chaque jour", "monthly_price": 1000},
        headers=owner,
    ).json()
    created = client.post(f"/api/v1/vip/rooms/{room['id']}/subscribe", headers=fan).json()
    _confirm(created["payment_id"])

    with TestingSessionLocal() as db:
        from app.models import VipSubscription

        subscription = db.query(VipSubscription).first()
        subscription.expires_at = datetime.utcnow() - timedelta(seconds=1)
        db.commit()

    # L'extinction se fait par la DATE, sans tâche de fond — c'est la panne
    # de cette tâche qui laisserait des accès ouverts indéfiniment.
    assert client.get(f"/api/v1/vip/rooms/{room['id']}/posts", headers=fan).json()["locked"] is True


def test_on_ne_publie_pas_le_media_de_quelqu_un_d_autre(client):
    owner, owner_id, owner_phone = _signup(client)
    _enable_for("vip_room", owner_id)
    client.put(
        "/api/v1/vip/room",
        json={"title": "Salon", "pitch": "Du contenu chaque jour", "monthly_price": 1000},
        headers=owner,
    )
    refused = client.post(
        "/api/v1/vip/posts", json={"media_asset_id": 4242}, headers=owner
    )
    assert refused.status_code == 404


# ── Hype Train ───────────────────────────────────────────────────────────


def test_le_palier_ne_tombe_qu_avec_de_l_argent_confirme(client):
    owner, owner_id, owner_phone = _signup(client)
    fan, fan_id, fan_phone = _signup(client)
    _enable_for("hype_train", owner_id, fan_id)

    train = client.post(
        "/api/v1/hype",
        json={"title": "Objectif", "promise": "Un live de deux heures", "goal_amount": 1000, "hours": 24},
        headers=owner,
    ).json()
    created = client.post(
        f"/api/v1/hype/{train['id']}/contribute", json={"amount": 1000}, headers=fan
    ).json()

    detail = client.get(f"/api/v1/hype/{train['id']}", headers=fan).json()
    assert detail["is_unlocked"] is False

    result = _confirm(created["payment_id"])
    assert result["unlocked_now"] is True
    detail = client.get(f"/api/v1/hype/{train['id']}", headers=fan).json()
    assert detail["is_unlocked"] is True
    assert detail["collected_amount"] == 1000


def test_un_createur_ne_finance_pas_son_propre_palier(client):
    owner, owner_id, owner_phone = _signup(client)
    _enable_for("hype_train", owner_id)
    train = client.post(
        "/api/v1/hype",
        json={"title": "Objectif", "promise": "Un live de deux heures", "goal_amount": 1000},
        headers=owner,
    ).json()
    refused = client.post(
        f"/api/v1/hype/{train['id']}/contribute", json={"amount": 1000}, headers=owner
    )
    assert refused.status_code == 400


def test_un_seul_objectif_en_cours_par_createur(client):
    owner, owner_id, owner_phone = _signup(client)
    _enable_for("hype_train", owner_id)
    body = {"title": "Objectif", "promise": "Un live de deux heures", "goal_amount": 1000}
    assert client.post("/api/v1/hype", json=body, headers=owner).status_code == 200
    assert client.post("/api/v1/hype", json=body, headers=owner).status_code == 409


def test_un_objectif_expire_n_accepte_plus_rien(client):
    owner, owner_id, owner_phone = _signup(client)
    fan, fan_id, fan_phone = _signup(client)
    _enable_for("hype_train", owner_id, fan_id)
    train = client.post(
        "/api/v1/hype",
        json={"title": "Objectif", "promise": "Un live de deux heures", "goal_amount": 1000},
        headers=owner,
    ).json()
    with TestingSessionLocal() as db:
        row = db.query(HypeTrain).filter(HypeTrain.id == train["id"]).first()
        row.expires_at = datetime.utcnow() - timedelta(seconds=1)
        db.commit()

    refused = client.post(
        f"/api/v1/hype/{train['id']}/contribute", json={"amount": 500}, headers=fan
    )
    assert refused.status_code == 409


def test_un_paiement_confirme_en_retard_compte_quand_meme(client):
    """C'est la passerelle qui a tardé, pas la personne qui a payé."""
    owner, owner_id, owner_phone = _signup(client)
    fan, fan_id, fan_phone = _signup(client)
    _enable_for("hype_train", owner_id, fan_id)
    train = client.post(
        "/api/v1/hype",
        json={"title": "Objectif", "promise": "Un live de deux heures", "goal_amount": 1000},
        headers=owner,
    ).json()
    created = client.post(
        f"/api/v1/hype/{train['id']}/contribute", json={"amount": 1000}, headers=fan
    ).json()
    with TestingSessionLocal() as db:
        row = db.query(HypeTrain).filter(HypeTrain.id == train["id"]).first()
        row.expires_at = datetime.utcnow() - timedelta(seconds=1)
        db.commit()

    assert _confirm(created["payment_id"])["unlocked_now"] is True


# ── Streak Lock ──────────────────────────────────────────────────────────


def test_un_message_fait_avancer_la_chaine(client):
    alice, alice_id, alice_phone = _signup(client)
    bob, bob_id, bob_phone = _signup(client)
    _enable_for("streak_lock", alice_id, bob_id)

    _send(client, alice, bob_id, bob_phone)
    _send(client, bob, alice_id, alice_phone)

    streak = client.get(f"/api/v1/streaks/{bob_id}", headers=alice).json()
    # Un seul jour d'échange : la chaîne démarre à 1, pas à 2.
    assert streak["current_days"] == 1


def test_un_message_passe_meme_si_la_chaine_echoue(client):
    """Un compteur perdu est désagréable ; un message perdu est une panne."""
    alice, alice_id, alice_phone = _signup(client)
    bob, bob_id, bob_phone = _signup(client)
    from app.services.modules import streak_service

    with patch.object(streak_service, "apply_message", side_effect=RuntimeError("boum")):
        sent = _send(client, alice, bob_id, bob_phone)
    assert sent.status_code == 200


def test_la_chaine_se_construit_meme_module_non_active(client):
    """Pour que celui qui active demain retrouve son historique."""
    alice, alice_id, alice_phone = _signup(client)
    bob, bob_id, bob_phone = _signup(client)
    _send(client, alice, bob_id, bob_phone)

    with TestingSessionLocal() as db:
        assert db.query(ConversationStreak).count() == 1


def test_racheter_une_chaine_intacte_est_refuse(client):
    alice, alice_id, alice_phone = _signup(client)
    bob, bob_id, bob_phone = _signup(client)
    _enable_for("streak_lock", alice_id, bob_id)
    _send(client, alice, bob_id, bob_phone)

    refused = client.post(f"/api/v1/streaks/{bob_id}/restore", headers=alice)
    assert refused.status_code == 409


def test_le_rachat_repose_la_chaine_apres_confirmation(client):
    alice, alice_id, alice_phone = _signup(client)
    bob, bob_id, bob_phone = _signup(client)
    _enable_for("streak_lock", alice_id, bob_id)
    _send(client, alice, bob_id, bob_phone)

    with TestingSessionLocal() as db:
        row = db.query(ConversationStreak).first()
        row.current_days = 0
        row.broken_days = 12
        row.broken_at = datetime.utcnow()
        db.commit()

    created = client.post(f"/api/v1/streaks/{bob_id}/restore", headers=alice).json()
    assert client.get(f"/api/v1/streaks/{bob_id}", headers=alice).json()["current_days"] == 0

    _confirm(created["payment_id"])
    assert client.get(f"/api/v1/streaks/{bob_id}", headers=alice).json()["current_days"] == 12


def test_un_paiement_confirme_deux_fois_n_accorde_rien_de_plus(client):
    """Les passerelles Mobile Money rappellent leur webhook en cas de doute."""
    organizer, organizer_id, organizer_phone = _signup(client)
    giver, giver_id, giver_phone = _signup(client)
    _enable_for("social_tax", organizer_id, giver_id)
    fund = client.post(
        "/api/v1/ceremonies", json={"title": "Mariage", "kind": "MARIAGE"}, headers=organizer
    ).json()
    created = client.post(
        f"/api/v1/ceremonies/{fund['id']}/contribute", json={"amount": 5000}, headers=giver
    ).json()

    _confirm(created["payment_id"])
    second = _confirm(created["payment_id"])
    assert second.get("already_processed") is True

    with TestingSessionLocal() as db:
        assert db.query(CeremonyFund).filter(CeremonyFund.id == fund["id"]).first().collected_amount == 5000
