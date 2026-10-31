"""Pokou — stockage objet S3-compatible (MinIO).

Remplace le disque local pour les pièces jointes (voir media_storage.py) :
le déploiement n'est plus obligé d'être mono-instance, et le volume de l'API
n'a plus à grandir avec les uploads.

Client S3 plutôt que le SDK `minio` : la même implémentation marche sur
MinIO, Amazon S3, Scaleway, Backblaze… sans rien réécrire — seule l'URL
d'endpoint change. `addressing_style="path"` est indispensable : MinIO servi
sur un domaine simple ne répond pas au style « virtual-host »
(bucket.domaine/objet) que boto3 utilise par défaut.
"""
import logging
from functools import lru_cache
from typing import Iterator, Optional

import boto3
from botocore.client import Config
from botocore.exceptions import BotoCoreError, ClientError

from app.core.config import get_settings

logger = logging.getLogger(__name__)

# Erreurs réseau/serveur du stockage objet, à distinguer d'une erreur de
# l'appelant : ce n'est pas la faute du client si MinIO est injoignable.
StorageError = (ClientError, BotoCoreError, OSError)


def is_enabled() -> bool:
    """Le stockage objet n'est utilisé que s'il est entièrement configuré —
    sinon on retombe sur le disque local (tests, poste de dev)."""
    settings = get_settings()
    return bool(settings.s3_endpoint_url and settings.s3_access_key and settings.s3_secret_key)


@lru_cache(maxsize=1)
def _client():
    settings = get_settings()
    return boto3.client(
        "s3",
        endpoint_url=settings.s3_endpoint_url,
        aws_access_key_id=settings.s3_access_key,
        aws_secret_access_key=settings.s3_secret_key,
        region_name=settings.s3_region,
        config=Config(
            signature_version="s3v4",
            s3={"addressing_style": "path"},
            retries={"max_attempts": 3, "mode": "standard"},
            connect_timeout=5,
            read_timeout=30,
        ),
    )


def reset_client_cache() -> None:
    """Pour les tests, et après un changement de configuration : le client
    boto3 capture l'endpoint et les clés à sa création."""
    _client.cache_clear()
    _ensure_bucket.cache_clear()


@lru_cache(maxsize=None)
def _ensure_bucket(bucket: str) -> None:
    """Crée le bucket au premier usage s'il n'existe pas. Mis en cache : un
    head_bucket à chaque upload ajouterait un aller-retour réseau inutile."""
    client = _client()
    try:
        client.head_bucket(Bucket=bucket)
        return
    except ClientError as exc:
        code = exc.response.get("Error", {}).get("Code")
        # 404/NoSuchBucket = à créer ; 403 = le bucket existe mais appartient
        # à quelqu'un d'autre (ou les droits manquent), ne pas le masquer.
        if code not in {"404", "NoSuchBucket"}:
            raise
    client.create_bucket(Bucket=bucket)
    logger.info("Bucket de stockage objet créé: %s", bucket)


def put_object(key: str, content: bytes, content_type: str) -> None:
    settings = get_settings()
    _ensure_bucket(settings.s3_bucket)
    _client().put_object(
        Bucket=settings.s3_bucket,
        Key=key,
        Body=content,
        ContentType=content_type,
    )


def open_stream(key: str, chunk_size: int = 64 * 1024) -> tuple[Iterator[bytes], Optional[int]]:
    """Itérateur de morceaux + taille annoncée par le stockage. On relaie le
    flux à travers l'API au lieu de rediriger vers une URL présignée : le
    contrôle d'accès de /media/{id} reste la seule porte d'entrée, et
    l'endpoint MinIO peut rester privé (il est ici en http simple)."""
    settings = get_settings()
    response = _client().get_object(Bucket=settings.s3_bucket, Key=key)
    body = response["Body"]
    return body.iter_chunks(chunk_size=chunk_size), response.get("ContentLength")


def object_exists(key: str) -> bool:
    settings = get_settings()
    try:
        _client().head_object(Bucket=settings.s3_bucket, Key=key)
        return True
    except ClientError:
        return False


def delete_object(key: str) -> None:
    settings = get_settings()
    try:
        _client().delete_object(Bucket=settings.s3_bucket, Key=key)
    except StorageError:
        # Best-effort : un objet orphelin coûte de l'espace, pas la
        # cohérence — la métadonnée en base reste la source de vérité.
        logger.warning("Suppression de l'objet %s impossible", key, exc_info=True)

# ── Téléversement DIRECT, sans passer par la RAM de l'API ─────────────────
#
# `media_storage.save_upload` fait `content = await upload.read()` : le
# fichier ENTIER passe en mémoire du processus avant d'être recopié vers
# MinIO. Dix vidéos de 50 Mo simultanées font 500 Mo de pic, et l'API devient
# le goulot d'étranglement de sa propre bande passante.
#
# Une URL présignée règle les deux d'un coup : le client téléverse
# directement vers MinIO, l'API ne voit qu'une confirmation. Elle ne transporte
# plus d'octets, elle autorise.
#
# Ce que l'URL porte, et qui doit être borné AVANT de la remettre :
#   - la clé exacte de l'objet (le client ne choisit pas où écrire) ;
#   - le type MIME attendu ;
#   - la taille maximale ;
#   - une expiration courte.


class PresignError(Exception):
    """L'URL n'a pas pu être fabriquée.

    Une classe à part entière, et non un membre de `StorageError` : celui-ci
    est un TUPLE d'exceptions de boto3, destiné aux clauses `except`. En
    hériter créerait une classe à bases multiples dont l'ordre de résolution
    n'a aucun sens ici.
    """


def presigned_put(
    key: str,
    content_type: str,
    max_bytes: int,
    expires_in: int = 900,
) -> dict:
    """Une autorisation d'écriture, pour UN objet et rien d'autre.

    `presigned_post` plutôt que `generate_presigned_url('put_object')` : la
    forme POST permet d'imposer une BORNE DE TAILLE côté serveur de stockage
    (`content-length-range`), que la forme PUT ne sait pas exprimer. Sans
    elle, une URL d'écriture serait un droit de déposer un fichier de
    n'importe quelle taille — c'est-à-dire de remplir le disque.

    Quinze minutes : de quoi téléverser une grosse vidéo sur un réseau lent,
    pas de quoi laisser traîner un droit d'écriture.
    """
    settings = get_settings()
    _ensure_bucket(settings.s3_bucket)
    try:
        return _client().generate_presigned_post(
            Bucket=settings.s3_bucket,
            Key=key,
            Fields={"Content-Type": content_type},
            Conditions=[
                {"Content-Type": content_type},
                ["content-length-range", 1, max_bytes],
            ],
            ExpiresIn=expires_in,
        )
    except (BotoCoreError, ClientError) as exc:
        raise PresignError(f"URL de dépôt impossible: {exc}") from exc


def presigned_get(key: str, expires_in: int = 3600) -> str:
    """Une autorisation de LECTURE, pour un objet et une heure.

    Sert au téléchargement d'un média : le client va le chercher directement
    dans MinIO au lieu de le faire transiter par l'API, qui le chargerait
    lui aussi en mémoire.
    """
    settings = get_settings()
    try:
        return _client().generate_presigned_url(
            "get_object",
            Params={"Bucket": settings.s3_bucket, "Key": key},
            ExpiresIn=expires_in,
        )
    except (BotoCoreError, ClientError) as exc:
        raise PresignError(f"URL de lecture impossible: {exc}") from exc


def head_object(key: str) -> Optional[dict]:
    """Ce que le stockage sait d'un objet — ou `None` s'il n'existe pas.

    C'est ce qui permet de VÉRIFIER un téléversement direct : le client dit
    « j'ai fini », et l'API confirme la taille et le type réellement déposés
    plutôt que de croire ce qu'on lui annonce. Sans ce contrôle, une
    métadonnée en base pourrait décrire un objet absent, ou mentir sur sa
    taille.
    """
    settings = get_settings()
    try:
        response = _client().head_object(Bucket=settings.s3_bucket, Key=key)
    except ClientError:
        return None
    except BotoCoreError as exc:
        raise StorageError(f"Lecture des métadonnées impossible: {exc}") from exc
    return {
        "size_bytes": response.get("ContentLength", 0),
        "content_type": response.get("ContentType", ""),
        "etag": (response.get("ETag") or "").strip('"'),
    }
