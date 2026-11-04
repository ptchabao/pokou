"""Les deux fichiers de vérification de domaine (App Links Android /
Universal Links iOS) doivent être servis SANS le préfixe `/api/v1` et en
JSON — sinon la vérification automatique du domaine échoue silencieusement
côté OS, bien avant qu'un utilisateur ne clique le moindre lien."""
import pytest
from fastapi.testclient import TestClient
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker

from app.core.database import Base, get_db
from app.main import app

TEST_DATABASE_URL = "sqlite:///./test_wellknown.db"

engine = create_engine(
    TEST_DATABASE_URL,
    connect_args={"check_same_thread": False},
)
TestingSessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)


def override_get_db():
    try:
        db = TestingSessionLocal()
        yield db
    finally:
        db.close()




@pytest.fixture(scope="function")
def client():
    Base.metadata.create_all(bind=engine)
    # L'override est posé PAR TEST et retiré ensuite, jamais au niveau du
    # module : pytest importe tous les fichiers de test avant d'en exécuter
    # un seul, donc une affectation au niveau module est écrasée par celle
    # du dernier fichier importé. Toutes les suites se retrouvaient alors à
    # lire la base d'une autre — ce qui ne se voit qu'en lançant la suite
    # entière, et jamais un fichier seul.
    previous = app.dependency_overrides.get(get_db)
    app.dependency_overrides[get_db] = override_get_db
    yield TestClient(app)
    if previous is not None:
        app.dependency_overrides[get_db] = previous
    else:
        app.dependency_overrides.pop(get_db, None)
    Base.metadata.drop_all(bind=engine)


def test_android_asset_links_is_served_without_api_prefix(client):
    response = client.get("/.well-known/assetlinks.json")
    assert response.status_code == 200
    assert "application/json" in response.headers["content-type"]

    body = response.json()
    assert isinstance(body, list) and body
    target = body[0]["target"]
    assert target["package_name"] == "com.pokou.pokou"

    fingerprints = target["sha256_cert_fingerprints"]
    # L'empreinte du keystore de RELEASE — celui qui signe les binaires
    # distribués — doit y être. Son absence n'émet aucune erreur : les liens
    # d'invitation s'ouvrent simplement dans le navigateur au lieu de
    # l'application, et rien nulle part ne le signale.
    assert "5F:2C:D7:94:E2:35:96:3D:2E:7B:0D:09:7E:41:A7:95:B4:13:D2:2C:12:51:B9:5A:76:87:5F:3E:3A:00:A5:7A" in fingerprints

    # Et chacune doit avoir la FORME d'une empreinte SHA-256 : 32 octets en
    # hexadécimal séparés par des deux-points. Une empreinte tronquée ou mal
    # recopiée échoue elle aussi en silence.
    for fingerprint in fingerprints:
        octets = fingerprint.split(":")
        assert len(octets) == 32, fingerprint
        assert all(len(octet) == 2 and int(octet, 16) >= 0 for octet in octets), fingerprint


def test_apple_app_site_association_is_served_without_api_prefix(client):
    response = client.get("/.well-known/apple-app-site-association")
    assert response.status_code == 200
    assert "application/json" in response.headers["content-type"]

    body = response.json()
    details = body["applinks"]["details"]
    # Toutes les formes de liens gérées par l'application doivent être
    # déclarées ; sinon iOS les ouvre dans le navigateur.
    assert details[0]["paths"] == [
        "/invite/*",
        "/c/*",
        "/channel/*",
        "/bot/*",
        "/kory/*",
        "/honam/order/*",
        "/kory/pots/*",
        "/honam/orders/*",
    ]


def test_la_cle_de_signature_du_play_store_peut_etre_ajoutee_sans_toucher_au_code(client, monkeypatch):
    """Le piège central des App Links sur le Play Store.

    On téléverse un bundle signé avec SA clé, puis Google le RESIGNE avec la
    sienne avant de le distribuer. L'empreinte que les appareils vérifient est
    donc celle de Google — et tant qu'elle manque, la vérification échoue pour
    tout le monde sauf sur les binaires installés à la main. La console Play
    dit alors « Échec de la validation de 1 domaine », sans jamais nommer la
    cause.

    Elle se lit dans la console et n'existe pas tant que l'application n'y est
    pas : c'est une donnée de déploiement, pas de source.
    """
    baseline = client.get("/.well-known/assetlinks.json").json()
    baseline_fingerprints = baseline[0]["target"]["sha256_cert_fingerprints"]

    monkeypatch.setenv("ANDROID_PLAY_SIGNING_SHA256", "aa:bb:cc, dd:ee:ff")
    updated = client.get("/.well-known/assetlinks.json").json()
    fingerprints = updated[0]["target"]["sha256_cert_fingerprints"]

    # Ajoutées, pas substituées : les clés locales doivent continuer à
    # fonctionner pour un binaire installé directement.
    assert fingerprints[: len(baseline_fingerprints)] == baseline_fingerprints
    assert fingerprints[-2:] == ["AA:BB:CC", "DD:EE:FF"]


def test_sans_variable_d_environnement_rien_ne_change(client, monkeypatch):
    monkeypatch.delenv("ANDROID_PLAY_SIGNING_SHA256", raising=False)
    fingerprints = client.get("/.well-known/assetlinks.json").json()[0]["target"][
        "sha256_cert_fingerprints"
    ]
    # Aucune empreinte vide ni fantôme : une empreinte invalide dans ce
    # fichier ne casse pas la vérification, elle la rend seulement plus
    # difficile à lire quand on la débogue.
    assert all(f and ":" in f for f in fingerprints)
