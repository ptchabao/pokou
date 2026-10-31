"""Pokou — pièces jointes (notes vocales/documents/images/vidéos).

Deux stockages possibles, choisis à l'upload et mémorisés par pièce jointe
dans `media_assets.storage_backend` :

- stockage objet S3-compatible (MinIO) dès qu'il est configuré — voir
  app/services/object_storage.py ;
- disque local sous `settings.media_storage_dir` sinon (tests, poste de dev).

Les fichiers déposés avant la bascule restent donc lisibles là où ils sont,
sans migration de données ni fichier introuvable."""
import logging
import uuid
from pathlib import Path
from typing import Iterator, Optional

from fastapi import UploadFile
from sqlalchemy.orm import Session

from app.core.config import get_settings
from app.models import MediaAsset, MessageType
from app.services.media import object_storage

logger = logging.getLogger(__name__)

BACKEND_LOCAL = "local"
BACKEND_OBJECT = "s3"

_DENYLISTED_MIME_PREFIXES = (
    "application/x-msdownload",
    "application/x-executable",
    "application/vnd.microsoft.portable-executable",
    "application/x-sh",
    "application/x-elf",
)

# Préfixe de clé dans le bucket — garde le bucket navigable si d'autres
# usages viennent s'y ajouter plus tard.
_OBJECT_PREFIX = "pokou/media/"

_TYPE_PREFIX = {
    MessageType.IMAGE: "image/",
    MessageType.VIDEO: "video/",
    MessageType.AUDIO: "audio/",
    # Un sticker est une IMAGE, même s'il n'est pas un message IMAGE. Sans
    # cette ligne il tombait dans le cas « DOCUMENT », qui accepte tout :
    # on aurait pu déposer un PDF dans un pack, et le panneau aurait affiché
    # un cadre cassé au milieu des stickers.
    MessageType.STICKER: "image/",
}


class MediaError(Exception):
    """Base class — callers map this to an HTTP error."""


class MediaTooLargeError(MediaError):
    pass


class MediaTypeNotAllowedError(MediaError):
    pass


class MediaStorageUnavailableError(MediaError):
    """Le stockage objet est configuré mais injoignable. Distinct des autres
    MediaError : ce n'est pas la requête du client qui est fautive, donc
    l'appelant doit répondre 503 et non 400 (voir routes/media.py)."""


def _storage_dir() -> Path:
    path = Path(get_settings().media_storage_dir)
    path.mkdir(parents=True, exist_ok=True)
    return path


def validate_mime_for_type(message_type: MessageType, mime_type: str) -> None:
    mime_type = (mime_type or "").lower()
    if any(mime_type.startswith(bad) for bad in _DENYLISTED_MIME_PREFIXES):
        raise MediaTypeNotAllowedError("Type de fichier non autorisé.")

    expected_prefix = _TYPE_PREFIX.get(message_type)
    if expected_prefix and not mime_type.startswith(expected_prefix):
        raise MediaTypeNotAllowedError(
            f"Ce fichier ne correspond pas au type de message déclaré ({message_type.value})."
        )
    # DOCUMENT accepte tout ce qui n'est pas explicitement bloqué au-dessus
    # (audio/vidéo/image inclus, un document peut être n'importe quoi).


async def save_upload(db: Session, uploader_id: int, upload: UploadFile, message_type: MessageType) -> MediaAsset:
    settings = get_settings()
    mime_type = upload.content_type or "application/octet-stream"
    validate_mime_for_type(message_type, mime_type)

    max_bytes = settings.media_max_size_mb * 1024 * 1024
    # Lecture BORNÉE : Starlette a déjà déposé le fichier sur disque, et un
    # `read()` sans limite le remonterait entier en mémoire — quelques envois
    # de plusieurs Go suffiraient à faire tomber le processus. Un octet de
    # plus que le plafond suffit à savoir qu'il est dépassé.
    content = await upload.read(max_bytes + 1)
    if len(content) > max_bytes:
        raise MediaTooLargeError(f"Fichier trop volumineux (max {settings.media_max_size_mb} Mo).")
    if len(content) == 0:
        raise MediaError("Fichier vide.")

    suffix = Path(upload.filename or "").suffix[:10]  # borne la longueur d'une extension farfelue
    filename = f"{uuid.uuid4().hex}{suffix}"

    # Le contenu est écrit AVANT la ligne en base : une écriture qui échoue
    # ne doit pas laisser une pièce jointe référencée mais introuvable.
    if object_storage.is_enabled():
        backend = BACKEND_OBJECT
        storage_path = f"{_OBJECT_PREFIX}{filename}"
        try:
            object_storage.put_object(storage_path, content, mime_type)
        except object_storage.StorageError as exc:
            logger.error("Écriture dans le stockage objet impossible", exc_info=True)
            raise MediaStorageUnavailableError(
                "Le stockage de fichiers est momentanément indisponible."
            ) from exc
    else:
        backend = BACKEND_LOCAL
        storage_path = filename
        (_storage_dir() / filename).write_bytes(content)

    asset = MediaAsset(
        uploader_id=uploader_id,
        storage_path=storage_path,
        storage_backend=backend,
        original_filename=(upload.filename or None),
        mime_type=mime_type,
        size_bytes=len(content),
    )
    db.add(asset)
    db.commit()
    db.refresh(asset)
    return asset


def resolve_path(asset: MediaAsset) -> Optional[Path]:
    """Chemin disque d'une pièce jointe locale, ou None si elle a disparu.
    Renvoie None pour une pièce jointe en stockage objet : elle n'a pas de
    chemin (voir open_stream)."""
    if (asset.storage_backend or BACKEND_LOCAL) != BACKEND_LOCAL:
        return None
    path = _storage_dir() / asset.storage_path
    return path if path.exists() else None


def open_stream(asset: MediaAsset) -> tuple[Iterator[bytes], Optional[int]]:
    """Flux de lecture d'une pièce jointe en stockage objet, relayé par
    l'API : le contrôle d'accès de /media/{id} reste ainsi la seule porte
    d'entrée (pas d'URL présignée qui circulerait hors de ce contrôle)."""
    try:
        return object_storage.open_stream(asset.storage_path)
    except object_storage.StorageError as exc:
        logger.error("Lecture du stockage objet impossible: %s", asset.storage_path, exc_info=True)
        raise MediaStorageUnavailableError(
            "Le stockage de fichiers est momentanément indisponible."
        ) from exc


def delete_content(asset: MediaAsset) -> None:
    """Supprime le contenu là où il vit réellement. Sans cette indirection,
    un appelant qui ne connaît que le disque (comme la purge des statuts)
    laisserait les objets s'accumuler dans le bucket indéfiniment.

    Best-effort : un objet orphelin coûte de l'espace, pas la cohérence — la
    métadonnée en base reste la source de vérité."""
    if uses_object_storage(asset):
        object_storage.delete_object(asset.storage_path)
        return
    path = resolve_path(asset)
    if path is None:
        return
    try:
        path.unlink()
    except OSError:
        logger.warning("Impossible de supprimer le fichier média %s", path)


def uses_object_storage(asset: MediaAsset) -> bool:
    return (asset.storage_backend or BACKEND_LOCAL) == BACKEND_OBJECT


# ── Téléversement DIRECT vers le stockage objet ───────────────────────────
#
# `save_upload` charge le fichier ENTIER en RAM (`await upload.read()`) avant
# de le recopier vers MinIO. C'est tenable pour une photo, pas pour une vidéo
# — dix envois de 50 Mo simultanés font 500 Mo de pic, et la bande passante
# de l'API devient le goulot d'étranglement de son propre stockage.
#
# Le chemin direct inverse la charge :
#
#     Flutter → API : « je veux déposer une vidéo de 40 Mo »
#     API → Flutter : une URL présignée, bornée en type et en taille
#     Flutter → MinIO : le fichier, sans passer par l'API
#     Flutter → API : « c'est déposé »
#     API → MinIO : vérifie ce qui A RÉELLEMENT été déposé, puis enregistre
#
# La dernière étape n'est pas une formalité : sans elle, le client pourrait
# annoncer une taille et un type qui ne correspondent pas à l'objet, et la
# ligne en base décrirait un fichier qui n'existe pas.


def prepare_direct_upload(
    uploader_id: int,
    message_type: MessageType,
    mime_type: str,
    filename: Optional[str] = None,
) -> dict:
    """Ouvre un dépôt direct et renvoie de quoi le faire.

    La clé est CHOISIE PAR LE SERVEUR. La laisser au client reviendrait à
    lui donner un droit d'écriture sur n'importe quel chemin du bucket —
    écraser le média de quelqu'un d'autre, par exemple.
    """
    if not object_storage.is_enabled():
        raise MediaError("Stockage objet non configuré.")

    validate_mime_for_type(message_type, mime_type)

    settings = get_settings()
    max_bytes = settings.media_max_size_mb * 1024 * 1024
    suffix = Path(filename or "").suffix[:10]
    key = f"{_OBJECT_PREFIX}{uuid.uuid4().hex}{suffix}"

    presigned = object_storage.presigned_put(
        key=key,
        content_type=mime_type,
        max_bytes=max_bytes,
    )
    return {
        "storage_path": key,
        "upload": presigned,
        "max_bytes": max_bytes,
        # Le client s'en sert pour ne pas retenter indéfiniment une URL
        # périmée : il en redemande une plutôt que de boucler sur un 403.
        "expires_in": 900,
    }


def confirm_direct_upload(
    db: Session,
    uploader_id: int,
    storage_path: str,
    message_type: MessageType,
    original_filename: Optional[str] = None,
) -> MediaAsset:
    """Enregistre un objet DÉJÀ déposé, après l'avoir vérifié.

    On interroge le stockage plutôt que de croire le client : la taille et
    le type viennent de MinIO, pas de la requête. Un objet absent — dépôt
    abandonné, URL périmée, erreur réseau — ne laisse aucune ligne en base.

    La clé est re-vérifiée : elle doit commencer par notre préfixe et ne
    contenir aucun segment de remontée. Sans ce contrôle, une clé forgée
    ferait référencer n'importe quel objet du bucket.
    """
    if not storage_path.startswith(_OBJECT_PREFIX) or ".." in storage_path:
        raise MediaError("Chemin de dépôt invalide.")

    existing = db.query(MediaAsset).filter(MediaAsset.storage_path == storage_path).first()
    if existing is not None:
        # Idempotent : une confirmation rejouée — réseau lent, réessai du
        # client — ne doit pas créer un second média pour le même objet.
        return existing

    infos = object_storage.head_object(storage_path)
    if infos is None:
        raise MediaError("Aucun fichier déposé à cet emplacement.")

    size_bytes = int(infos.get("size_bytes") or 0)
    settings = get_settings()
    max_bytes = settings.media_max_size_mb * 1024 * 1024
    if size_bytes <= 0:
        raise MediaError("Fichier vide.")
    if size_bytes > max_bytes:
        # La borne est déjà imposée par l'URL présignée
        # (`content-length-range`). Ce second contrôle couvre le cas d'un
        # objet déposé autrement — une clé réutilisée, un stockage qui
        # n'applique pas la condition.
        raise MediaTooLargeError(
            f"Fichier trop volumineux (max {settings.media_max_size_mb} Mo)."
        )

    mime_type = infos.get("content_type") or "application/octet-stream"
    validate_mime_for_type(message_type, mime_type)

    asset = MediaAsset(
        uploader_id=uploader_id,
        storage_backend=BACKEND_OBJECT,
        storage_path=storage_path,
        mime_type=mime_type,
        size_bytes=size_bytes,
        original_filename=(original_filename or "")[:255] or None,
    )
    db.add(asset)
    db.commit()
    db.refresh(asset)
    return asset
