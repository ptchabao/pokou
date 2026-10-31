"""Vignettes d'images — `GET /media/{id}?w=…`.

Ce que ce fichier protège : **la route ne doit jamais échouer à cause d'une
vignette.** Largeur inconnue, format qui ne se redimensionne pas, image déjà
plus petite, Pillow absent — dans tous ces cas elle sert l'original, c'est-
à-dire exactement ce qu'elle faisait avant que les vignettes existent. Une
photo qui ne s'affiche pas est un défaut bien pire qu'une photo trop lourde.

Et une propriété de sécurité : `?w=` n'accepte que des largeurs FERMÉES.
Sans cette liste, dix mille largeurs différentes sur la même image
rempliraient le disque — un déni de service qui ne ressemble même pas à une
attaque dans les journaux.
"""
from io import BytesIO

import pytest
from fastapi.testclient import TestClient
from PIL import Image
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker

from app.core.database import Base, get_db
from app.main import app
from app.models import MediaAsset, User, UserRole
from app.services.media import media_storage, thumbnail_service
from tests.helpers import bearer_for_email

TEST_DATABASE_URL = "sqlite:///./test_media_thumbnails.db"

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
    # Le dossier des vignettes SURVIT d'un test à l'autre, alors que la base
    # est recréée et que les identifiants de média repartent à 1. Sans ce
    # nettoyage, un test lit la vignette d'une image d'un test précédent
    # portant le même identifiant — et croit avoir prouvé quelque chose.
    #
    # (En production le cas n'existe pas : les identifiants sont
    # auto-incrémentés et jamais réattribués.)
    thumbs = media_storage._storage_dir() / "thumbs"
    if thumbs.exists():
        for fichier in thumbs.iterdir():
            fichier.unlink(missing_ok=True)
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


def _seed_image(email: str, taille=(2400, 1800), mime="image/jpeg") -> int:
    """Une image RÉELLEMENT écrite sur disque, aux dimensions d'une photo.

    Un fichier factice de quelques octets ne prouverait rien : c'est
    justement le décodage et le redimensionnement qu'on veut voir marcher.
    """
    db = TestingSessionLocal()
    try:
        user = db.query(User).filter(User.email == email).one()
        dossier = media_storage._storage_dir()
        dossier.mkdir(parents=True, exist_ok=True)
        nom = f"photo-{user.id}-{taille[0]}.jpg"
        image = Image.new("RGB", taille, (30, 150, 120))
        tampon = BytesIO()
        image.save(tampon, "JPEG", quality=92)
        octets = tampon.getvalue()
        (dossier / nom).write_bytes(octets)

        asset = MediaAsset(
            uploader_id=user.id,
            storage_path=nom,
            storage_backend="local",
            mime_type=mime,
            size_bytes=len(octets),
        )
        db.add(asset)
        db.commit()
        return asset.id
    finally:
        db.close()


def test_la_vignette_est_bien_plus_legere_que_l_original(client):
    entetes = auth_headers(client, "vendeur@example.com")
    media_id = _seed_image("vendeur@example.com")

    original = client.get(f"/api/v1/media/{media_id}", headers=entetes)
    vignette = client.get(f"/api/v1/media/{media_id}?w=96", headers=entetes)

    assert original.status_code == 200
    assert vignette.status_code == 200
    # C'est tout l'objet de la fonctionnalité : une pastille de contact ne
    # doit pas coûter le poids d'une photo d'appareil.
    assert len(vignette.content) < len(original.content) / 10

    with Image.open(BytesIO(vignette.content)) as image:
        assert image.width == 96
        # Les proportions sont conservées : 2400×1800 → 96×72.
        assert image.height == 72


def test_chaque_palier_rend_sa_largeur(client):
    entetes = auth_headers(client, "vendeur@example.com")
    media_id = _seed_image("vendeur@example.com")
    for largeur in thumbnail_service.LARGEURS:
        reponse = client.get(f"/api/v1/media/{media_id}?w={largeur}", headers=entetes)
        assert reponse.status_code == 200, largeur
        with Image.open(BytesIO(reponse.content)) as image:
            assert image.width == largeur


def test_une_largeur_hors_liste_sert_l_original(client):
    """Pas une erreur : l'original.

    `?w=` est une OPTIMISATION. La faire échouer transformerait un réglage
    de performance en panne d'affichage, et un client un peu ancien ou un
    peu créatif casserait toutes les images de l'écran.
    """
    entetes = auth_headers(client, "vendeur@example.com")
    media_id = _seed_image("vendeur@example.com")

    original = client.get(f"/api/v1/media/{media_id}", headers=entetes)
    for largeur in (0, 1, 97, 5000, -3):
        reponse = client.get(f"/api/v1/media/{media_id}?w={largeur}", headers=entetes)
        assert reponse.status_code == 200, largeur
        assert len(reponse.content) == len(original.content), largeur


def test_une_image_deja_plus_petite_n_est_pas_reencodee(client):
    """La réencoder l'alourdirait sans rien gagner."""
    entetes = auth_headers(client, "vendeur@example.com")
    media_id = _seed_image("vendeur@example.com", taille=(64, 64))

    original = client.get(f"/api/v1/media/{media_id}", headers=entetes)
    vignette = client.get(f"/api/v1/media/{media_id}?w=96", headers=entetes)
    assert vignette.status_code == 200
    assert len(vignette.content) == len(original.content)


def test_un_format_non_redimensionnable_passe_tel_quel(client):
    entetes = auth_headers(client, "vendeur@example.com")
    media_id = _seed_image("vendeur@example.com", mime="application/pdf")

    original = client.get(f"/api/v1/media/{media_id}", headers=entetes)
    reponse = client.get(f"/api/v1/media/{media_id}?w=96", headers=entetes)
    assert reponse.status_code == 200
    assert len(reponse.content) == len(original.content)


def test_la_vignette_n_est_fabriquee_qu_une_fois(client):
    entetes = auth_headers(client, "vendeur@example.com")
    media_id = _seed_image("vendeur@example.com")

    premiere = client.get(f"/api/v1/media/{media_id}?w=320", headers=entetes)
    chemin = thumbnail_service._chemin_vignette(media_id, 320)
    assert chemin.exists()
    empreinte = chemin.stat().st_mtime_ns

    seconde = client.get(f"/api/v1/media/{media_id}?w=320", headers=entetes)
    assert seconde.content == premiere.content
    # Même fichier, pas réécrit : redimensionner à chaque requête aurait
    # seulement déplacé le coût du réseau vers le processeur.
    assert chemin.stat().st_mtime_ns == empreinte

    thumbnail_service.purger(media_id)
    assert not chemin.exists()


def test_la_vignette_respecte_le_controle_d_acces(client):
    """`?w=` ne contourne rien.

    Ce serait le défaut le plus grave possible ici : une porte dérobée vers
    des images privées, ouverte par un paramètre de performance.
    """
    auth_headers(client, "vendeur@example.com")
    media_id = _seed_image("vendeur@example.com")

    etranger = auth_headers(client, "inconnu@example.com")
    assert client.get(f"/api/v1/media/{media_id}", headers=etranger).status_code == 404
    assert (
        client.get(f"/api/v1/media/{media_id}?w=96", headers=etranger).status_code == 404
    )


def test_le_media_s_annonce_immuable(client):
    """Le contenu d'un média ne change jamais pour un identifiant donné."""
    entetes = auth_headers(client, "vendeur@example.com")
    media_id = _seed_image("vendeur@example.com")

    for url in (f"/api/v1/media/{media_id}", f"/api/v1/media/{media_id}?w=96"):
        reponse = client.get(url, headers=entetes)
        cache = reponse.headers.get("cache-control", "")
        assert "immutable" in cache
        # `private` : l'accès dépend de qui demande, donc aucun cache
        # partagé ne doit conserver la photo d'un statut privé.
        assert "private" in cache
