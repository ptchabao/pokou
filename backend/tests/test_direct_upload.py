"""Le téléversement DIRECT vers le stockage objet.

`save_upload` fait `content = await upload.read()` : le fichier entier passe
en RAM du processus avant d'être recopié vers MinIO. Dix vidéos de 50 Mo
simultanées font 500 Mo de pic, et la bande passante de l'API devient le
goulot de son propre stockage.

Le chemin direct inverse la charge : l'API AUTORISE, elle ne transporte pas.
Ces tests portent sur ce qui doit rester vrai quand le fichier ne passe plus
par elle — c'est-à-dire sur tout ce qu'elle ne peut plus vérifier en le
lisant.
"""
from unittest.mock import MagicMock, patch

import pytest

from app.models import MessageType
from app.services.media import media_storage


@pytest.fixture
def stockage():
    with patch.object(media_storage, "object_storage") as fake:
        fake.is_enabled.return_value = True
        fake.presigned_put.return_value = {"url": "https://minio/x", "fields": {}}
        yield fake


def test_la_cle_est_choisie_par_le_SERVEUR(stockage):
    # La laisser au client reviendrait à lui donner un droit d'écriture sur
    # n'importe quel chemin du bucket — écraser le média de quelqu'un
    # d'autre, par exemple.
    a = media_storage.prepare_direct_upload(1, MessageType.IMAGE, "image/jpeg", "a.jpg")
    b = media_storage.prepare_direct_upload(1, MessageType.IMAGE, "image/jpeg", "a.jpg")

    assert a["storage_path"] != b["storage_path"]
    assert a["storage_path"].startswith("pokou/media/")


def test_l_url_est_bornee_en_taille(stockage):
    # `presigned_post` impose `content-length-range` côté stockage. Sans
    # cette borne, une URL d'écriture serait un droit de remplir le disque.
    media_storage.prepare_direct_upload(1, MessageType.VIDEO, "video/mp4")

    _, kwargs = stockage.presigned_put.call_args
    assert kwargs["max_bytes"] > 0
    assert kwargs["content_type"] == "video/mp4"


def test_un_type_incoherent_est_refuse_avant_l_URL(stockage):
    # Le contrôle de type arrive AVANT l'émission : une URL déjà remise ne
    # se rappelle pas.
    with pytest.raises(media_storage.MediaTypeNotAllowedError):
        media_storage.prepare_direct_upload(1, MessageType.IMAGE, "application/pdf")

    stockage.presigned_put.assert_not_called()


def test_sans_stockage_objet_on_refuse_plutot_que_de_promettre(stockage):
    stockage.is_enabled.return_value = False

    with pytest.raises(media_storage.MediaError):
        media_storage.prepare_direct_upload(1, MessageType.IMAGE, "image/jpeg")


# ── La confirmation : ce que l'API ne peut plus voir ─────────────────────


def _db_vide():
    db = MagicMock()
    db.query.return_value.filter.return_value.first.return_value = None
    return db


def test_la_taille_vient_du_STOCKAGE_pas_du_client(stockage):
    """Le point central.

    L'API ne lit plus le fichier : si elle croyait le client sur parole, une
    ligne en base pourrait décrire un objet plus gros qu'annoncé, ou absent.
    """
    stockage.head_object.return_value = {
        "size_bytes": 4242,
        "content_type": "image/jpeg",
    }
    db = _db_vide()

    media_storage.confirm_direct_upload(
        db, 1, "pokou/media/abc.jpg", MessageType.IMAGE, "photo.jpg"
    )

    asset = db.add.call_args.args[0]
    assert asset.size_bytes == 4242
    assert asset.mime_type == "image/jpeg"


def test_un_objet_ABSENT_ne_laisse_aucune_ligne(stockage):
    # Dépôt abandonné, URL périmée, coupure réseau : la base ne doit pas
    # référencer un fichier introuvable.
    stockage.head_object.return_value = None
    db = _db_vide()

    with pytest.raises(media_storage.MediaError):
        media_storage.confirm_direct_upload(
            db, 1, "pokou/media/abc.jpg", MessageType.IMAGE
        )

    db.add.assert_not_called()


def test_un_objet_trop_gros_est_refuse_meme_apres_depot(stockage):
    # La borne est déjà dans l'URL. Ce second contrôle couvre un objet
    # déposé autrement — clé réutilisée, stockage qui n'applique pas la
    # condition.
    stockage.head_object.return_value = {
        "size_bytes": 10 * 1024 * 1024 * 1024,
        "content_type": "video/mp4",
    }
    db = _db_vide()

    with pytest.raises(media_storage.MediaTooLargeError):
        media_storage.confirm_direct_upload(
            db, 1, "pokou/media/abc.mp4", MessageType.VIDEO
        )


def test_un_type_incoherent_est_refuse_a_la_confirmation(stockage):
    # Le client a annoncé une image et déposé autre chose.
    stockage.head_object.return_value = {
        "size_bytes": 100,
        "content_type": "application/x-msdownload",
    }
    db = _db_vide()

    with pytest.raises(media_storage.MediaTypeNotAllowedError):
        media_storage.confirm_direct_upload(
            db, 1, "pokou/media/abc.jpg", MessageType.IMAGE
        )


@pytest.mark.parametrize(
    "chemin",
    ["autre/prefixe/x.jpg", "pokou/media/../../etc/passwd", "/etc/passwd"],
)
def test_une_cle_forgee_est_refusee(stockage, chemin):
    """Sans ce contrôle, une clé choisie par le client ferait référencer
    n'importe quel objet du bucket — y compris celui de quelqu'un d'autre."""
    db = _db_vide()

    with pytest.raises(media_storage.MediaError):
        media_storage.confirm_direct_upload(db, 1, chemin, MessageType.IMAGE)

    stockage.head_object.assert_not_called()


def test_confirmer_deux_fois_ne_cree_pas_deux_medias(stockage):
    """Idempotent : un réessai du client sur un réseau lent ne doit pas
    doubler le média."""
    existant = MagicMock()
    db = MagicMock()
    db.query.return_value.filter.return_value.first.return_value = existant

    rendu = media_storage.confirm_direct_upload(
        db, 1, "pokou/media/abc.jpg", MessageType.IMAGE
    )

    assert rendu is existant
    db.add.assert_not_called()
    stockage.head_object.assert_not_called()


def test_un_objet_vide_est_refuse(stockage):
    stockage.head_object.return_value = {"size_bytes": 0, "content_type": "image/jpeg"}
    db = _db_vide()

    with pytest.raises(media_storage.MediaError):
        media_storage.confirm_direct_upload(
            db, 1, "pokou/media/abc.jpg", MessageType.IMAGE
        )
