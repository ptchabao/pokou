"""Spark de bout en bout.

Les règles pures sont testées sans base dans `test_spark_rules.py`. Ce
fichier vérifie ce qui ne peut l'être qu'avec des routes : le verrou d'âge,
le fait qu'un flux ne mélange pas deux intentions, qu'un paiement n'accorde
rien avant d'être confirmé, que la séquestre ne se dénoue pas d'un seul côté,
et que le Safe Word part même quand personne ne l'écoute.
"""
import re
from datetime import date, datetime, timedelta
from unittest.mock import patch

import pytest
from fastapi.testclient import TestClient
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker

from app.core.database import Base, get_db
from app.main import app
from app.models import AppModule, MarketplacePayment, MediaAsset, SparkCheckin, SparkDate, SparkDatePack, SparkMatch, SparkProfile, SparkSafetyAlert, UserModuleActivation
from app.services.auth import otp_service
from app.services.marketplace.marketplace_monetization_service import confirm_payment

TEST_DATABASE_URL = "sqlite:///./test_spark.db"

engine = create_engine(TEST_DATABASE_URL, connect_args={"check_same_thread": False})
TestingSessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)
Base.metadata.create_all(bind=engine)

# Lomé, et un point à environ 3 km — dans le rayon.
LOME = (6.1319, 1.2228)
NEARBY = (6.1550, 1.2380)
# Kpalimé : bien au-delà des 5 km.
FAR = (6.9000, 0.6300)


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
    from app.services.marketplace import marketplace_monetization_service as service

    with patch.object(service, "semoa_client") as gateway:
        gateway.create_order.return_value = {
            "reference": "ref-test",
            "payment_url": "https://exemple.test/payer",
        }
        gateway.build_callback_url.return_value = "https://exemple.test/webhook"
        yield gateway


_PHONE = iter(range(2000, 9999))


def _signup(client):
    phone = f"+2289{next(_PHONE)}000"
    with patch.object(otp_service.sms_service, "send_sms", return_value=True) as mock_send:
        client.post("/api/v1/auth/phone/request-otp", json={"phone": phone})
    code = re.search(r"\b(\d{6})\b", mock_send.call_args.args[2]).group(1)
    body = client.post("/api/v1/auth/phone/verify-otp", json={"phone": phone, "code": code}).json()
    client.cookies.clear()
    return {"Authorization": f"Bearer {body['access_token']}"}, body["user"]["id"]


def _open_module(enabled=True):
    with TestingSessionLocal() as db:
        module = db.query(AppModule).filter(AppModule.slug == "spark").first()
        if module is None:
            module = AppModule(
                slug="spark", name="Spark", tagline="…", description="…",
                icon="local_fire_department", accent_color="#E11D48",
                category="SOCIAL", is_enabled=enabled,
            )
            db.add(module)
        else:
            module.is_enabled = enabled
        db.commit()
        return module.id


def _enable_for(*user_ids):
    module_id = _open_module()
    with TestingSessionLocal() as db:
        for user_id in user_ids:
            db.add(UserModuleActivation(user_id=user_id, module_id=module_id))
        db.commit()
    return module_id


ADULT = date(1998, 5, 12)


def _make_profile(client, headers, *, name="Kossi", gender="M", birth=ADULT, at=LOME):
    response = client.put(
        "/api/v1/spark/profile",
        json={
            "display_name": name,
            "bio": "Ici pour de vrai",
            "birth_date": birth.isoformat(),
            "gender": gender,
        },
        headers=headers,
    )
    if response.status_code == 200 and at is not None:
        client.post(
            "/api/v1/spark/profile/location",
            json={"latitude": at[0], "longitude": at[1]},
            headers=headers,
        )
    return response


def _set_intent(client, headers, kind="JUS"):
    return client.post("/api/v1/spark/intent", json={"kind": kind}, headers=headers)


def _confirm(payment_id):
    with TestingSessionLocal() as db:
        payment = db.query(MarketplacePayment).filter(
            MarketplacePayment.id == payment_id
        ).first()
        reference = payment.provider_reference
    return confirm_payment(TestingSessionLocal(), reference)


_MEDIA_SEQ = iter(range(1, 100000))


def _media_for(user_id, mime="audio/ogg"):
    """Un média, avec son FICHIER réellement écrit sur disque.

    Sans le fichier, `/media/{id}` répond 404 APRÈS avoir accordé l'accès —
    et le test confond alors « accès refusé » avec « fichier absent », deux
    causes très différentes derrière le même code.
    """
    from app.services.media import media_storage

    name = f"spark-test-{next(_MEDIA_SEQ)}"
    storage_dir = media_storage._storage_dir()
    storage_dir.mkdir(parents=True, exist_ok=True)
    (storage_dir / name).write_bytes(b"\xff\xd8\xff\xd9")

    with TestingSessionLocal() as db:
        asset = MediaAsset(
            uploader_id=user_id,
            storage_path=name,
            storage_backend="local",
            mime_type=mime,
            size_bytes=4,
            original_filename="vocal.ogg",
        )
        db.add(asset)
        db.commit()
        return asset.id


def _pair(client, *, intent="JUS", at_b=NEARBY):
    """Deux profils Spark, même intention, à portée l'un de l'autre."""
    a, a_id = _signup(client)
    b, b_id = _signup(client)
    _enable_for(a_id, b_id)
    _make_profile(client, a, name="Ama", gender="F", at=LOME)
    _make_profile(client, b, name="Kossi", gender="M", at=at_b)
    _set_intent(client, a, intent)
    _set_intent(client, b, intent)
    return (a, a_id), (b, b_id)


# ── Le verrou du module et l'âge ─────────────────────────────────────────


def test_le_module_ferme_coupe_l_acces(client):
    headers, user_id = _signup(client)
    _enable_for(user_id)
    assert client.get("/api/v1/spark/profile", headers=headers).status_code == 200
    _open_module(enabled=False)
    assert client.get("/api/v1/spark/profile", headers=headers).status_code == 404


def test_un_mineur_est_refuse(client):
    headers, user_id = _signup(client)
    _enable_for(user_id)
    minor = date.today() - timedelta(days=365 * 16)
    response = _make_profile(client, headers, birth=minor, at=None)
    assert response.status_code == 403


def test_la_date_de_naissance_ne_se_corrige_pas_apres_coup(client):
    """Sinon on s'inscrit majeur, puis on corrige — et la vérification d'âge
    n'aurait protégé que le jour de l'inscription."""
    headers, user_id = _signup(client)
    _enable_for(user_id)
    _make_profile(client, headers)
    response = _make_profile(client, headers, birth=date(2010, 1, 1))
    assert response.status_code == 409


# ── La Carte du Moment ───────────────────────────────────────────────────


def test_une_intention_est_annoncee_avec_son_echeance(client):
    headers, user_id = _signup(client)
    _enable_for(user_id)
    _make_profile(client, headers)
    body = _set_intent(client, headers, "AFTER").json()
    assert body["kind"] == "AFTER"
    # Vingt-quatre heures, et le client doit pouvoir l'afficher sans calculer.
    assert 86000 < body["seconds_left"] <= 86400


def test_sans_intention_le_flux_le_dit_au_lieu_d_etre_vide(client):
    headers, user_id = _signup(client)
    _enable_for(user_id)
    _make_profile(client, headers)
    body = client.get("/api/v1/spark/feed", headers=headers).json()
    assert body["needs_intent"] is True
    assert body["message"]


def test_sans_position_le_flux_le_dit_aussi(client):
    headers, user_id = _signup(client)
    _enable_for(user_id)
    _make_profile(client, headers, at=None)
    _set_intent(client, headers)
    body = client.get("/api/v1/spark/feed", headers=headers).json()
    assert body["needs_location"] is True


# ── Le flux ──────────────────────────────────────────────────────────────


def test_le_flux_ne_montre_que_la_meme_intention(client):
    (a, a_id), (b, b_id) = _pair(client)
    assert [card["user_id"] for card in client.get("/api/v1/spark/feed", headers=a).json()["items"]] == [b_id]

    # B change d'avis : il ne doit plus apparaître dans le flux de A.
    _set_intent(client, b, "SERIEUX")
    assert client.get("/api/v1/spark/feed", headers=a).json()["items"] == []


def test_le_flux_s_arrete_a_cinq_kilometres(client):
    (a, _), (b, b_id) = _pair(client, at_b=FAR)
    assert client.get("/api/v1/spark/feed", headers=a).json()["items"] == []


def test_une_position_perimee_retire_du_flux(client):
    """Afficher « à 2 km » d'après un relevé d'hier est une information
    fausse — et pour une rencontre physique, c'est un risque."""
    (a, _), (b, b_id) = _pair(client)
    with TestingSessionLocal() as db:
        profile = db.query(SparkProfile).filter(SparkProfile.user_id == b_id).first()
        profile.location_updated_at = datetime.utcnow() - timedelta(hours=20)
        db.commit()
    assert client.get("/api/v1/spark/feed", headers=a).json()["items"] == []


def test_un_profil_ecarte_ne_revient_pas(client):
    (a, _), (b, b_id) = _pair(client)
    client.post(f"/api/v1/spark/pass/{b_id}", headers=a)
    assert client.get("/api/v1/spark/feed", headers=a).json()["items"] == []


def test_la_carte_ne_porte_pas_le_compte_pokou(client):
    """Ouvrir Spark ne doit pas exposer son compte de messagerie."""
    (a, _), (b, b_id) = _pair(client)
    card = client.get("/api/v1/spark/feed", headers=a).json()["items"][0]
    assert card["display_name"] == "Kossi"
    assert "phone" not in card and "full_name" not in card


# ── Le swipe à crédit ────────────────────────────────────────────────────


def test_un_homme_epuise_ses_cinq_likes_puis_se_voit_refuser(client):
    headers, user_id = _signup(client)
    _enable_for(user_id)
    _make_profile(client, headers, gender="M")
    targets = []
    for _ in range(6):
        other, other_id = _signup(client)
        _enable_for(other_id)
        _make_profile(client, other, name="Cible", gender="F")
        targets.append(other_id)

    for target_id in targets[:5]:
        assert client.post(
            f"/api/v1/spark/like/{target_id}", json={"kind": "LIKE"}, headers=headers
        ).status_code == 200
    refused = client.post(
        f"/api/v1/spark/like/{targets[5]}", json={"kind": "LIKE"}, headers=headers
    )
    assert refused.status_code == 402


def test_une_femme_like_sans_limite(client):
    headers, user_id = _signup(client)
    _enable_for(user_id)
    _make_profile(client, headers, gender="F")
    for _ in range(8):
        other, other_id = _signup(client)
        _enable_for(other_id)
        _make_profile(client, other, gender="M")
        assert client.post(
            f"/api/v1/spark/like/{other_id}", json={"kind": "LIKE"}, headers=headers
        ).status_code == 200


def test_un_pack_de_likes_n_est_credite_qu_apres_paiement(client):
    headers, user_id = _signup(client)
    _enable_for(user_id)
    _make_profile(client, headers, gender="M")
    created = client.post(
        "/api/v1/spark/likes/purchase", json={"size": 10}, headers=headers
    ).json()
    assert client.get("/api/v1/spark/profile", headers=headers).json()["profile"]["likes_balance"] == 0

    _confirm(created["payment_id"])
    assert client.get("/api/v1/spark/profile", headers=headers).json()["profile"]["likes_balance"] == 10


def test_le_super_spark_n_existe_qu_une_fois_paye(client):
    (a, a_id), (b, b_id) = _pair(client)
    voice = _media_for(a_id)
    created = client.post(
        f"/api/v1/spark/like/{b_id}",
        json={"kind": "SUPER", "voice_media_id": voice},
        headers=a,
    ).json()
    assert created["pending_payment"] is True
    # Rien n'est arrivé chez B.
    assert client.get("/api/v1/spark/likers", headers=b).json()["count"] == 0

    _confirm(created["payment_id"])
    assert client.get("/api/v1/spark/likers", headers=b).json()["count"] == 1


def test_le_vocal_d_un_super_spark_doit_m_appartenir(client):
    (a, a_id), (b, b_id) = _pair(client)
    someone_elses = _media_for(b_id)
    refused = client.post(
        f"/api/v1/spark/like/{b_id}",
        json={"kind": "SUPER", "voice_media_id": someone_elses},
        headers=a,
    )
    assert refused.status_code == 404


def test_le_nombre_de_likes_recus_est_visible_meme_sans_payer(client):
    """Cacher jusqu'à l'existence des likes rendrait l'offre invérifiable :
    on paierait sans savoir s'il y a quelque chose à voir."""
    (a, a_id), (b, b_id) = _pair(client)
    client.post(f"/api/v1/spark/like/{b_id}", json={"kind": "LIKE"}, headers=a)
    body = client.get("/api/v1/spark/likers", headers=b).json()
    assert body["count"] == 1
    assert body["locked"] is True
    assert body["items"] == []


def test_l_abonnement_ouvre_la_liste_des_likes(client):
    (a, a_id), (b, b_id) = _pair(client)
    client.post(f"/api/v1/spark/like/{b_id}", json={"kind": "LIKE"}, headers=a)
    created = client.post("/api/v1/spark/see-likers", headers=b).json()
    _confirm(created["payment_id"])
    body = client.get("/api/v1/spark/likers", headers=b).json()
    assert body["locked"] is False and len(body["items"]) == 1


# ── Le match et la Salle d'Entrée ────────────────────────────────────────


def _match(client, a, a_id, b, b_id):
    client.post(f"/api/v1/spark/like/{b_id}", json={"kind": "LIKE"}, headers=a)
    return client.post(
        f"/api/v1/spark/like/{a_id}", json={"kind": "LIKE"}, headers=b
    ).json()


def test_un_like_reciproque_ouvre_la_salle(client):
    (a, a_id), (b, b_id) = _pair(client)
    body = _match(client, a, a_id, b, b_id)
    assert body["matched"] is True
    detail = client.get(f"/api/v1/spark/matches/{body['match_id']}", headers=a).json()
    assert detail["status"] == "ROOM"
    assert 0 < detail["room_seconds_left"] <= 600


def test_le_texte_est_refuse_par_le_serveur(client):
    """Une interdiction qui ne vit que dans l'écran se contourne par un appel
    direct — et c'est l'impossibilité du copier-coller qui fait le tri."""
    (a, a_id), (b, b_id) = _pair(client)
    match_id = _match(client, a, a_id, b, b_id)["match_id"]
    refused = client.post(
        f"/api/v1/spark/matches/{match_id}/messages",
        json={"kind": "TEXT", "sticker": "bonjour"},
        headers=a,
    )
    assert refused.status_code == 422


def test_un_vocal_passe_un_fichier_image_non(client):
    (a, a_id), (b, b_id) = _pair(client)
    match_id = _match(client, a, a_id, b, b_id)["match_id"]
    assert client.post(
        f"/api/v1/spark/matches/{match_id}/messages",
        json={"kind": "VOICE", "media_asset_id": _media_for(a_id)},
        headers=a,
    ).status_code == 200
    refused = client.post(
        f"/api/v1/spark/matches/{match_id}/messages",
        json={"kind": "VOICE", "media_asset_id": _media_for(a_id, mime="image/jpeg")},
        headers=a,
    )
    assert refused.status_code == 400


def test_on_ne_sait_pas_si_l_autre_a_deja_appuye(client):
    """Le savoir transformerait « veux-tu continuer ? » en « oseras-tu
    refuser ? »."""
    (a, a_id), (b, b_id) = _pair(client)
    match_id = _match(client, a, a_id, b, b_id)["match_id"]
    client.post(f"/api/v1/spark/matches/{match_id}/continue", headers=a)
    detail = client.get(f"/api/v1/spark/matches/{match_id}", headers=b).json()
    assert detail["peer_continued"] is None


def test_les_deux_continuent_et_la_discussion_s_ouvre(client):
    (a, a_id), (b, b_id) = _pair(client)
    match_id = _match(client, a, a_id, b, b_id)["match_id"]
    client.post(f"/api/v1/spark/matches/{match_id}/continue", headers=a)
    body = client.post(f"/api/v1/spark/matches/{match_id}/continue", headers=b).json()
    assert body["status"] == "CONTINUED"


def test_un_seul_continue_l_autre_perd_du_karma(client):
    (a, a_id), (b, b_id) = _pair(client)
    match_id = _match(client, a, a_id, b, b_id)["match_id"]
    client.post(f"/api/v1/spark/matches/{match_id}/continue", headers=a)

    with TestingSessionLocal() as db:
        match = db.query(SparkMatch).filter(SparkMatch.id == match_id).first()
        match.room_expires_at = datetime.utcnow() - timedelta(seconds=1)
        db.commit()

    detail = client.get(f"/api/v1/spark/matches/{match_id}", headers=a).json()
    assert detail["status"] == "SAVED"
    profile = client.get("/api/v1/spark/profile", headers=b).json()["profile"]
    assert profile["karma"] < 100


def test_la_prolongation_n_est_ajoutee_qu_apres_paiement(client):
    (a, a_id), (b, b_id) = _pair(client)
    match_id = _match(client, a, a_id, b, b_id)["match_id"]
    before = client.get(f"/api/v1/spark/matches/{match_id}", headers=a).json()

    created = client.post(f"/api/v1/spark/matches/{match_id}/extend", headers=a).json()
    during = client.get(f"/api/v1/spark/matches/{match_id}", headers=a).json()
    assert during["extensions"] == 0

    _confirm(created["payment_id"])
    after = client.get(f"/api/v1/spark/matches/{match_id}", headers=a).json()
    assert after["extensions"] == 1
    assert after["room_seconds_left"] > before["room_seconds_left"]


# ── Le Wingman ───────────────────────────────────────────────────────────


def test_l_avis_des_amis_est_agrege_jamais_nominatif(client):
    (a, a_id), (b, b_id) = _pair(client)
    friend_one, friend_one_id = _signup(client)
    friend_two, friend_two_id = _signup(client)

    client.post(
        f"/api/v1/spark/wingman/{b_id}",
        json={"friend_ids": [friend_one_id, friend_two_id]},
        headers=a,
    )
    for friend in (friend_one, friend_two):
        requests = client.get("/api/v1/spark/wingman/requests", headers=friend).json()["items"]
        assert len(requests) == 1
        client.post(
            f"/api/v1/spark/wingman/requests/{requests[0]['id']}",
            json={"vote": "GREEN"},
            headers=friend,
        )

    verdict = client.get(f"/api/v1/spark/wingman/{b_id}", headers=a).json()
    assert verdict["verdict"] == "GREEN"
    assert verdict["answered"] == 2
    # Aucun nom : montrer qui a voté rouge transformerait un service rendu en
    # dispute entre amis.
    assert "votes" not in verdict and "voters" not in verdict


def test_un_ami_sans_spark_peut_quand_meme_voter(client):
    """C'est par là que le module se diffuse : pour aider son pote, on
    installe l'application."""
    (a, a_id), (b, b_id) = _pair(client)
    friend, friend_id = _signup(client)  # Spark non activé chez lui
    client.post(
        f"/api/v1/spark/wingman/{b_id}", json={"friend_ids": [friend_id]}, headers=a
    )
    assert client.get("/api/v1/spark/wingman/requests", headers=friend).status_code == 200


# ── Le Date Pack et sa séquestre ─────────────────────────────────────────


def _pack(price=3500, merchant_id=None):
    with TestingSessionLocal() as db:
        pack = SparkDatePack(
            title="Garba & jus chez Aïcha",
            venue_name="Chez Aïcha",
            price=price,
            latitude=LOME[0],
            longitude=LOME[1],
            merchant_id=merchant_id,
        )
        db.add(pack)
        db.commit()
        return pack.id


def _continued_match(client):
    (a, a_id), (b, b_id) = _pair(client)
    match_id = _match(client, a, a_id, b, b_id)["match_id"]
    client.post(f"/api/v1/spark/matches/{match_id}/continue", headers=a)
    client.post(f"/api/v1/spark/matches/{match_id}/continue", headers=b)
    return (a, a_id), (b, b_id), match_id


def _book(client, headers, match_id, pack_id, *, when=None):
    when = when or datetime.utcnow() + timedelta(days=3)
    return client.post(
        "/api/v1/spark/dates",
        json={
            "match_id": match_id,
            "pack_id": pack_id,
            "scheduled_at": when.isoformat(),
        },
        headers=headers,
    )


def test_on_ne_reserve_pas_avant_d_avoir_quitte_la_salle(client):
    (a, a_id), (b, b_id) = _pair(client)
    match_id = _match(client, a, a_id, b, b_id)["match_id"]
    response = _book(client, a, match_id, _pack())
    assert response.status_code == 409


def test_le_bon_n_existe_qu_une_fois_l_argent_encaisse(client):
    """Un bon émis avant paiement serait un repas gratuit."""
    (a, a_id), (b, b_id), match_id = _continued_match(client)
    created = _book(client, a, match_id, _pack()).json()

    detail = client.get(f"/api/v1/spark/dates/{created['date_id']}", headers=a).json()
    assert detail["status"] == "PENDING"
    assert "voucher_code" not in detail

    _confirm(created["payment_id"])
    detail = client.get(f"/api/v1/spark/dates/{created['date_id']}", headers=a).json()
    assert detail["status"] == "HELD"
    assert len(detail["voucher_code"]) == 8


def test_la_sequestre_ne_se_denoue_pas_d_un_seul_cote(client):
    (a, a_id), (b, b_id), match_id = _continued_match(client)
    when = datetime.utcnow() - timedelta(minutes=30)
    created = _book(client, a, match_id, _pack(), when=datetime.utcnow() + timedelta(days=2)).json()
    _confirm(created["payment_id"])
    with TestingSessionLocal() as db:
        row = db.query(SparkDate).filter(SparkDate.id == created["date_id"]).first()
        row.scheduled_at = when
        db.commit()

    body = client.post(f"/api/v1/spark/dates/{created['date_id']}/validate", headers=a).json()
    assert body["status"] == "HELD", "une validation unilatérale ne libère rien"

    body = client.post(f"/api/v1/spark/dates/{created['date_id']}/validate", headers=b).json()
    assert body["status"] == "RELEASED"
    assert body["settlement"]["merchant_due"] == 3150
    assert body["settlement"]["platform_fee"] == 350


def test_annuler_a_temps_rembourse_tout(client):
    (a, a_id), (b, b_id), match_id = _continued_match(client)
    created = _book(
        client, a, match_id, _pack(), when=datetime.utcnow() + timedelta(days=5)
    ).json()
    _confirm(created["payment_id"])
    body = client.post(f"/api/v1/spark/dates/{created['date_id']}/cancel", headers=a).json()
    assert body["status"] == "REFUNDED"


def test_annuler_trop_tard_paie_le_commercant(client):
    (a, a_id), (b, b_id), match_id = _continued_match(client)
    created = _book(
        client, a, match_id, _pack(), when=datetime.utcnow() + timedelta(days=2)
    ).json()
    _confirm(created["payment_id"])
    with TestingSessionLocal() as db:
        row = db.query(SparkDate).filter(SparkDate.id == created["date_id"]).first()
        row.scheduled_at = datetime.utcnow() + timedelta(hours=2)
        db.commit()

    body = client.post(f"/api/v1/spark/dates/{created['date_id']}/cancel", headers=a).json()
    assert body["status"] == "CANCELLED"
    assert body["settlement"]["merchant_due"] == 3500
    # Se rémunérer sur un rendez-vous qui n'a pas eu lieu serait indéfendable.
    assert body["settlement"]["platform_fee"] is None


def test_on_ne_peut_pas_se_declarer_soi_meme_absent(client):
    """Sinon celui qui a payé se désigne absent et récupère la moitié de sa
    mise."""
    (a, a_id), (b, b_id), match_id = _continued_match(client)
    created = _book(client, a, match_id, _pack()).json()
    _confirm(created["payment_id"])
    refused = client.post(
        f"/api/v1/spark/dates/{created['date_id']}/no-show",
        json={"absent_user_id": a_id},
        headers=a,
    )
    assert refused.status_code == 400


def test_un_lapin_verse_la_moitie_a_celui_qui_s_est_deplace(client):
    (a, a_id), (b, b_id), match_id = _continued_match(client)
    created = _book(client, a, match_id, _pack()).json()
    _confirm(created["payment_id"])
    with TestingSessionLocal() as db:
        row = db.query(SparkDate).filter(SparkDate.id == created["date_id"]).first()
        row.scheduled_at = datetime.utcnow() - timedelta(hours=1)
        db.commit()

    body = client.post(
        f"/api/v1/spark/dates/{created['date_id']}/no-show",
        json={"absent_user_id": b_id},
        headers=a,
    ).json()
    assert body["status"] == "PENALIZED"
    assert body["settlement"]["penalty_amount"] == 1750
    assert body["settlement"]["penalty_to_me"] is True
    # Et l'absent le paie aussi en Street Cred.
    assert client.get("/api/v1/spark/profile", headers=b).json()["profile"]["karma"] == 80


def test_un_karma_trop_bas_ne_peut_plus_inviter(client):
    (a, a_id), (b, b_id), match_id = _continued_match(client)
    with TestingSessionLocal() as db:
        profile = db.query(SparkProfile).filter(SparkProfile.user_id == a_id).first()
        profile.karma = 10
        db.commit()
    assert _book(client, a, match_id, _pack()).status_code == 403


def test_le_commercant_encaisse_le_bon_sans_liberer_l_argent(client):
    """Un commerçant qui pourrait à la fois scanner et libérer serait payé
    pour un rendez-vous auquel personne n'est venu."""
    merchant, merchant_id = _signup(client)
    (a, a_id), (b, b_id), match_id = _continued_match(client)
    created = _book(client, a, match_id, _pack(merchant_id=merchant_id)).json()
    _confirm(created["payment_id"])
    code = client.get(f"/api/v1/spark/dates/{created['date_id']}", headers=a).json()["voucher_code"]

    body = client.post(f"/api/v1/spark/vouchers/{code}/redeem", headers=merchant).json()
    assert body["ok"] is True
    detail = client.get(f"/api/v1/spark/dates/{created['date_id']}", headers=a).json()
    assert detail["status"] == "HELD", "encaisser le bon ne libère pas la séquestre"

    # Et il ne s'utilise qu'une fois.
    assert client.post(f"/api/v1/spark/vouchers/{code}/redeem", headers=merchant).status_code == 409


def test_un_autre_commercant_ne_peut_pas_encaisser_le_bon(client):
    merchant, merchant_id = _signup(client)
    intruder, intruder_id = _signup(client)
    (a, a_id), (b, b_id), match_id = _continued_match(client)
    created = _book(client, a, match_id, _pack(merchant_id=merchant_id)).json()
    _confirm(created["payment_id"])
    code = client.get(f"/api/v1/spark/dates/{created['date_id']}", headers=a).json()["voucher_code"]
    assert client.post(f"/api/v1/spark/vouchers/{code}/redeem", headers=intruder).status_code == 403


def test_un_paiement_confirme_deux_fois_n_ouvre_qu_une_sequestre(client):
    (a, a_id), (b, b_id), match_id = _continued_match(client)
    created = _book(client, a, match_id, _pack()).json()
    _confirm(created["payment_id"])
    second = _confirm(created["payment_id"])
    assert second.get("already_processed") is True
    with TestingSessionLocal() as db:
        assert db.query(SparkCheckin).filter(
            SparkCheckin.date_id == created["date_id"]
        ).count() == 2


# ── La sécurité silencieuse ──────────────────────────────────────────────


def test_le_safe_word_part_meme_sans_cercle_configure(client):
    """Un écran qui afficherait une erreur au moment où quelqu'un déclenche
    discrètement une alerte le mettrait en danger."""
    headers, user_id = _signup(client)
    _enable_for(user_id)
    _make_profile(client, headers)
    body = client.post(
        "/api/v1/spark/safety/alert",
        json={"latitude": LOME[0], "longitude": LOME[1]},
        headers=headers,
    ).json()
    assert body["ok"] is True and body["notified"] == 0
    with TestingSessionLocal() as db:
        assert db.query(SparkSafetyAlert).count() == 1


def test_le_cercle_de_securite_est_prevenu(client):
    headers, user_id = _signup(client)
    friend, friend_id = _signup(client)
    _enable_for(user_id)
    _make_profile(client, headers)
    client.post(
        "/api/v1/spark/safety/contacts", json={"contact_user_id": friend_id}, headers=headers
    )
    with patch("app.services.notifications.push_service.send_push") as push:
        body = client.post("/api/v1/spark/safety/alert", json={}, headers=headers).json()
    assert body["notified"] == 1
    assert push.called


def test_le_check_in_arrive_puis_se_referme(client):
    (a, a_id), (b, b_id), match_id = _continued_match(client)
    created = _book(client, a, match_id, _pack()).json()
    _confirm(created["payment_id"])
    with TestingSessionLocal() as db:
        for row in db.query(SparkCheckin).all():
            row.due_at = datetime.utcnow() - timedelta(minutes=1)
        db.commit()

    pending = client.get("/api/v1/spark/safety/checkins", headers=a).json()
    assert len(pending["items"]) == 1
    client.post(f"/api/v1/spark/safety/checkins/{pending['items'][0]['id']}", headers=a)
    assert client.get("/api/v1/spark/safety/checkins", headers=a).json()["items"] == []


def test_le_silence_declenche_l_alerte(client):
    (a, a_id), (b, b_id), match_id = _continued_match(client)
    created = _book(client, a, match_id, _pack()).json()
    _confirm(created["payment_id"])
    with TestingSessionLocal() as db:
        for row in db.query(SparkCheckin).filter(SparkCheckin.user_id == a_id):
            row.due_at = datetime.utcnow() - timedelta(minutes=10)
        db.commit()

    body = client.get("/api/v1/spark/safety/checkins", headers=a).json()
    assert body["escalated"] == 1
    with TestingSessionLocal() as db:
        alert = db.query(SparkSafetyAlert).first()
        assert alert.kind == "CHECKIN_MISSED"


# ── Les médias de Spark ──────────────────────────────────────────────────


def _upload_photo(client, headers, user_id):
    """Dépose une photo sur MA fiche et renvoie l'identifiant du média."""
    media_id = _media_for(user_id, mime="image/jpeg")
    response = client.post(
        "/api/v1/spark/photos", json={"media_asset_id": media_id}, headers=headers
    )
    assert response.status_code == 200, response.text
    return media_id


def test_la_photo_d_une_fiche_est_visible_des_autres_sparkeurs(client):
    """Sans cette règle, une photo n'était lisible que par celui qui l'avait
    envoyée — la seule personne qui n'en a pas besoin."""
    (a, a_id), (b, b_id) = _pair(client)
    media_id = _upload_photo(client, a, a_id)

    assert client.get(f"/api/v1/media/{media_id}", headers=b).status_code == 200


def test_un_utilisateur_hors_spark_ne_parcourt_pas_les_photos(client):
    """Quelqu'un qui a ouvert Spark a accepté d'y être vu. Un utilisateur
    ordinaire de Pokou n'a pas à parcourir des photos de rencontre."""
    (a, a_id), (b, b_id) = _pair(client)
    media_id = _upload_photo(client, a, a_id)

    outsider, outsider_id = _signup(client)  # pas de fiche Spark
    assert client.get(f"/api/v1/media/{media_id}", headers=outsider).status_code == 404


def test_le_vocal_d_un_super_spark_s_ecoute_par_son_destinataire(client):
    (a, a_id), (b, b_id) = _pair(client)
    voice = _media_for(a_id)
    created = client.post(
        f"/api/v1/spark/like/{b_id}",
        json={"kind": "SUPER", "voice_media_id": voice},
        headers=a,
    ).json()
    _confirm(created["payment_id"])

    # C'est ce que l'expéditeur a payé : le destinataire doit pouvoir
    # l'écouter avant de trancher.
    assert client.get(f"/api/v1/media/{voice}", headers=b).status_code == 200

    intruder, intruder_id = _signup(client)
    _enable_for(intruder_id)
    _make_profile(client, intruder)
    assert client.get(f"/api/v1/media/{voice}", headers=intruder).status_code == 404


def test_un_vocal_de_salle_reste_entre_les_deux(client):
    (a, a_id), (b, b_id) = _pair(client)
    match_id = _match(client, a, a_id, b, b_id)["match_id"]
    voice = _media_for(a_id)
    client.post(
        f"/api/v1/spark/matches/{match_id}/messages",
        json={"kind": "VOICE", "media_asset_id": voice},
        headers=a,
    )

    assert client.get(f"/api/v1/media/{voice}", headers=b).status_code == 200

    # Dix minutes de conversation privée n'ont pas à survivre au-delà de ceux
    # qui les ont tenues.
    outsider, outsider_id = _signup(client)
    _enable_for(outsider_id)
    _make_profile(client, outsider)
    assert client.get(f"/api/v1/media/{voice}", headers=outsider).status_code == 404
