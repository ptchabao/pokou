import sys
from logging.config import fileConfig
from pathlib import Path

from alembic import context
from sqlalchemy import engine_from_config, pool

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from app import models  # noqa: E402,F401 — enregistre toutes les tables
from app.core.config import get_settings  # noqa: E402
from app.core.database import Base  # noqa: E402

config = context.config

# Toujours la base de l'application (DATABASE_URL), jamais le repli sqlite
# d'alembic.ini : sinon `alembic upgrade head` migrerait en silence un
# fichier local jetable au lieu de la vraie base.
config.set_main_option("sqlalchemy.url", get_settings().database_url.replace("%", "%%"))

if config.config_file_name is not None:
    fileConfig(config.config_file_name)

target_metadata = Base.metadata


def run_migrations_offline() -> None:
    context.configure(
        url=config.get_main_option("sqlalchemy.url"),
        target_metadata=target_metadata,
        literal_binds=True,
        dialect_opts={"paramstyle": "named"},
        render_as_batch=True,
    )
    with context.begin_transaction():
        context.run_migrations()


def run_migrations_online() -> None:
    connectable = engine_from_config(
        config.get_section(config.config_ini_section, {}),
        prefix="sqlalchemy.",
        poolclass=pool.NullPool,
    )
    with connectable.connect() as connection:
        # Plusieurs réplicas peuvent migrer au même démarrage (Kubero lance
        # les migrations depuis les pods web, faute de Job préalable) : un
        # verrou PostgreSQL les fait passer l'un après l'autre. Le second
        # trouve la base déjà à jour et ne fait rien. Libéré à la fermeture
        # de la connexion, même après une erreur.
        if connection.dialect.name == "postgresql":
            connection.exec_driver_sql("SELECT pg_advisory_lock(7468757)")
            connection.commit()
        context.configure(
            connection=connection,
            target_metadata=target_metadata,
            # SQLite ne sait pas ALTER une colonne : le mode batch recrée la
            # table. Sans effet sur PostgreSQL.
            render_as_batch=connection.dialect.name == "sqlite",
        )
        with context.begin_transaction():
            context.run_migrations()


if context.is_offline_mode():
    run_migrations_offline()
else:
    run_migrations_online()
