"""Remise à zéro COMPLÈTE de Pokou : base, médias MinIO, médias sur disque.

IRRÉVERSIBLE. Aucune sauvegarde n'est faite.

Ne s'exécute qu'au démarrage, AVANT les migrations, et seulement si la
variable `POKOU_RESET_DATABASE` vaut exactement `EFFACER-TOUT-<AAAA-MM-JJ>`
pour la date du jour (UTC). Une valeur oubliée dans la configuration ne peut
donc pas effacer la production un autre jour.

Chaque phrase ne sert qu'UNE fois : une fois la remise à zéro faite, une
marque est posée sur le volume persistant (`MEDIA_STORAGE_DIR/..`), et les
redémarrages suivants avec la même phrase ne refont rien.

Après la remise à zéro, les migrations recréent le schéma et le seed recrée
le catalogue des modules et le super-administrateur de la console (nouveau
mot de passe, affiché une fois dans les journaux).

Procédure : docs/DOCUMENTATION-OFFICIELLE.md § 11, « Remettre la production
à zéro ».

    python -m scripts.reset_database
"""
import os
import shutil
import sys
from datetime import datetime, timezone
from pathlib import Path

from sqlalchemy import MetaData, text

from app.core.config import get_settings
from app.core.database import engine

settings = get_settings()

PREFIX = "EFFACER-TOUT-"


def _expected() -> str:
    return PREFIX + datetime.now(timezone.utc).strftime("%Y-%m-%d")


def _marker(phrase: str) -> Path:
    # À côté du dossier des médias, sur le volume persistant : la marque
    # survit au redémarrage, et n'est pas effacée avec les médias.
    return Path(settings.media_storage_dir).resolve().parent / f".pokou-reset-{phrase}.done"


def wipe_database() -> str:
    with engine.begin() as conn:
        if engine.dialect.name == "postgresql":
            tables = [r[0] for r in conn.execute(text(
                "SELECT tablename FROM pg_tables WHERE schemaname = 'public'"))]
            accounts = (conn.execute(text("SELECT count(*) FROM users")).scalar()
                        if "users" in tables else 0)
            if tables:
                conn.execute(text("DROP TABLE " + ", ".join(f'"{t}"' for t in tables) + " CASCADE"))
            types = [r[0] for r in conn.execute(text(
                "SELECT t.typname FROM pg_type t JOIN pg_namespace n ON n.oid = t.typnamespace "
                "WHERE n.nspname = 'public' AND t.typtype = 'e'"))]
            for name in types:
                conn.execute(text(f'DROP TYPE IF EXISTS "{name}" CASCADE'))
            return f"base : {len(tables)} tables et {len(types)} types supprimés ({accounts} comptes)"
    # SQLite (développement, tests) : même résultat, sans les types.
    meta = MetaData()
    meta.reflect(bind=engine)
    count = len(meta.tables)
    with engine.begin() as conn:
        conn.execute(text("PRAGMA foreign_keys = OFF"))
        for table in meta.tables.values():
            conn.execute(text(f'DROP TABLE IF EXISTS "{table.name}"'))
    return f"base : {count} tables supprimées"


def wipe_object_storage() -> str:
    from app.services.media import object_storage

    if not object_storage.is_enabled():
        return "stockage objet : non configuré"
    import boto3

    s3 = boto3.client(
        "s3",
        endpoint_url=settings.s3_endpoint_url,
        aws_access_key_id=settings.s3_access_key,
        aws_secret_access_key=settings.s3_secret_key,
        region_name=settings.s3_region,
    )
    deleted = 0
    token = None
    while True:
        kwargs = {"Bucket": settings.s3_bucket}
        if token:
            kwargs["ContinuationToken"] = token
        page = s3.list_objects_v2(**kwargs)
        keys = [{"Key": o["Key"]} for o in page.get("Contents", [])]
        for i in range(0, len(keys), 1000):
            s3.delete_objects(Bucket=settings.s3_bucket, Delete={"Objects": keys[i:i + 1000], "Quiet": True})
            deleted += len(keys[i:i + 1000])
        if not page.get("IsTruncated"):
            break
        token = page.get("NextContinuationToken")
    return f"stockage objet {settings.s3_bucket} : {deleted} fichiers supprimés"


def wipe_local_media() -> str:
    root = Path(settings.media_storage_dir)
    if not root.is_dir():
        return f"disque {root} : absent"
    files = 0
    for entry in root.iterdir():
        if entry.is_dir():
            files += sum(len(f) for _, _, f in os.walk(entry))
            shutil.rmtree(entry)
        else:
            files += 1
            entry.unlink()
    return f"disque {root} : {files} fichiers supprimés"


def main() -> int:
    phrase = os.environ.get("POKOU_RESET_DATABASE", "").strip()
    if not phrase:
        return 0
    if phrase != _expected():
        print(f"Remise à zéro REFUSÉE : POKOU_RESET_DATABASE doit valoir « {_expected()} » aujourd'hui.")
        return 0
    marker = _marker(phrase)
    if marker.exists():
        print(f"Remise à zéro « {phrase} » déjà faite : rien à refaire. Retirez POKOU_RESET_DATABASE.")
        return 0

    print("═" * 64)
    print(f"REMISE À ZÉRO DE POKOU ({phrase})")
    for step in (wipe_database, wipe_object_storage, wipe_local_media):
        try:
            print("  " + step())
        except Exception as exc:  # noqa: BLE001 — on dit tout, puis on arrête
            print(f"  ÉCHEC {step.__name__} : {type(exc).__name__}: {exc}")
            print("═" * 64)
            return 1
    marker.parent.mkdir(parents=True, exist_ok=True)
    marker.write_text(datetime.now(timezone.utc).isoformat())
    print("  terminé — les migrations et le seed vont recréer le schéma.")
    print("  RETIREZ maintenant POKOU_RESET_DATABASE de la configuration.")
    print("═" * 64)
    return 0


if __name__ == "__main__":
    sys.exit(main())
