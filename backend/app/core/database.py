import logging
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker, declarative_base
from app.core.config import get_settings

settings = get_settings()

# Create database engine
# ── Le pool de connexions, explicite ─────────────────────────────────────
#
# Les valeurs étaient laissées aux défauts de SQLAlchemy (pool_size=5,
# max_overflow=10). Ça tient à une instance ; ça ne tient plus dès qu'on en
# ajoute, et la panne est brutale : PostgreSQL refuse les connexions
# au-delà de `max_connections`, et TOUTE l'API tombe d'un coup au lieu de
# ralentir.
#
# Le calcul, à refaire avant d'ajouter des instances :
#
#     connexions_max = instances × workers_uvicorn × (pool_size + max_overflow)
#
# Avec les valeurs ci-dessous et 1 worker par instance :
#
#     1 instance  →  1 × 1 × (10 + 10) =  20 connexions
#     5 instances →  5 × 1 × (10 + 10) = 100 connexions   ← plafond Postgres par défaut
#    10 instances → 10 × 1 × (10 + 10) = 200 connexions   ← à ce stade, PgBouncer
#
# Le `max_connections` de PostgreSQL vaut 100 par défaut. **Cinq instances
# le saturent donc exactement**, et la sixième commence à recevoir des
# refus. Au-delà, deux voies : relever `max_connections` (chaque connexion
# coûte de la mémoire côté serveur), ou poser un PgBouncer en mode
# transaction — la seconde étant la bonne à partir d'une dizaine
# d'instances.
#
# `pool_timeout` est EXPLICITE et court : sans lui, une requête attend
# indéfiniment qu'une connexion se libère, et une saturation se manifeste
# par un gel plutôt que par une erreur. Un échec rapide est diagnosticable ;
# un gel ne l'est pas.
# `connect_timeout` n'existe que côté PostgreSQL : SQLite (le repli de
# développement) rejetterait l'argument plutôt que de l'ignorer.
_pg_only_connect_args = (
    {"connect_timeout": settings.db_connect_timeout}
    if settings.database_url.startswith("postgres")
    else {}
)

engine = create_engine(
    settings.database_url,
    echo=False,
    connect_args=_pg_only_connect_args,
    # Vérifie que la connexion est vivante avant de la prêter : un pare-feu
    # ou PostgreSQL lui-même coupe les connexions inactives, et sans ce test
    # la première requête d'après échoue.
    pool_pre_ping=True,
    # Recycle avant que quiconque ne coupe : une heure est en dessous de tous
    # les délais d'inactivité usuels.
    pool_recycle=3600,
    pool_size=settings.db_pool_size,
    max_overflow=settings.db_max_overflow,
    pool_timeout=settings.db_pool_timeout,
)
logging.getLogger("sqlalchemy.engine").setLevel(logging.WARNING)


# Create session factory
SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)

# Create declarative base for models
Base = declarative_base()

# Dependency
def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()

logger = logging.getLogger(__name__)
