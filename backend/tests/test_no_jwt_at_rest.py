"""Aucun JWT complet ne doit subsister — ni en base, ni dans les journaux.

Corriger le code d'émission ne suffisait pas : les lignes DÉJÀ écrites
portaient des jetons rejouables, et ce sont précisément celles dont la fuite
serait exploitable aujourd'hui. La migration 20260922_hash_tokens les
réécrit ; ces tests vérifient qu'aucun chemin ne les réintroduit.

Le contrôle porte sur la FORME d'un JWT — trois segments base64url séparés
par des points, commençant par `eyJ` (le `{"` d'un en-tête JSON encodé). On
cherche donc le motif partout, plutôt que de faire confiance à une liste de
colonnes qu'on aurait pu oublier de tenir à jour.
"""
import logging
import re
from datetime import datetime, timedelta

import pytest
from sqlalchemy import create_engine, inspect, text
from sqlalchemy.orm import sessionmaker

from app.core.database import Base
from app.models import Token, User
from app.api.v1.auth.auth import _token_digest
from app.core.log_redaction import RedactSecretsFilter
from app.core.security import create_access_token, create_refresh_token

TEST_DATABASE_URL = "sqlite:///./test_no_jwt.db"

#: Un JWT : en-tête.charge.signature, en base64url. L'en-tête commence
#: toujours par `eyJ` puisqu'il encode un objet JSON.
JWT_PATTERN = re.compile(r"eyJ[A-Za-z0-9_-]{10,}\.[A-Za-z0-9_-]{10,}\.[A-Za-z0-9_-]{10,}")


@pytest.fixture
def db():
    engine = create_engine(TEST_DATABASE_URL, connect_args={"check_same_thread": False})
    Base.metadata.create_all(bind=engine)
    session = sessionmaker(bind=engine)()
    yield session
    session.close()
    Base.metadata.drop_all(bind=engine)
    engine.dispose()
    import os

    if os.path.exists("./test_no_jwt.db"):
        os.remove("./test_no_jwt.db")


def test_le_motif_reconnait_bien_un_vrai_jwt():
    # Garde-fou : sans lui, les tests suivants passeraient parce que le motif
    # ne trouve jamais rien, et non parce qu'il n'y a rien à trouver.
    jeton = create_access_token({"sub": "a@b.c", "user_id": 1}, jti="x")

    assert JWT_PATTERN.search(jeton)


def test_aucune_colonne_de_la_base_ne_contient_de_JWT(db):
    """Balaie TOUTES les tables, pas seulement celle qu'on soupçonne.

    Une liste de colonnes à surveiller se périme dès qu'on ajoute une table.
    Ici, tout nouveau modèle qui rangerait un jeton quelque part fera tomber
    ce test sans que personne n'ait à y penser.
    """
    acces = create_access_token({"sub": "a@b.c", "user_id": 1}, jti="jti-1")
    rafraichissement = create_refresh_token({"sub": "a@b.c", "user_id": 1}, jti="jti-1")
    utilisateur = User(phone="+22890000003", is_active=True)
    db.add(utilisateur)
    db.commit()
    db.add(
        Token(
            user_id=utilisateur.id,
            access_token=_token_digest(acces),
            refresh_token=_token_digest(rafraichissement),
            jti="jti-1",
            expires_at=datetime.utcnow() + timedelta(days=7),
        )
    )
    db.commit()

    trouvailles = []
    inspector = inspect(db.get_bind())
    for table in inspector.get_table_names():
        colonnes = [
            c["name"]
            for c in inspector.get_columns(table)
            if "CHAR" in str(c["type"]).upper() or "TEXT" in str(c["type"]).upper()
        ]
        for colonne in colonnes:
            for (valeur,) in db.execute(
                text(f'SELECT "{colonne}" FROM "{table}" WHERE "{colonne}" IS NOT NULL')
            ):
                if isinstance(valeur, str) and JWT_PATTERN.search(valeur):
                    trouvailles.append(f"{table}.{colonne}")

    assert trouvailles == [], f"JWT trouvés en base : {trouvailles}"


def test_la_ligne_de_session_garde_une_empreinte_et_pas_le_jeton(db):
    acces = create_access_token({"sub": "a@b.c", "user_id": 1}, jti="jti-2")

    empreinte = _token_digest(acces)

    assert empreinte != acces
    assert len(empreinte) == 64
    assert not JWT_PATTERN.search(empreinte)


def test_l_empreinte_permet_encore_de_retrouver_une_session(db):
    # Ce que le hachage ne doit PAS coûter : partant d'un jeton trouvé
    # quelque part, savoir quelle session l'a émis reste possible.
    acces = create_access_token({"sub": "a@b.c", "user_id": 1}, jti="jti-3")
    utilisateur = User(phone="+22890000004", is_active=True)
    db.add(utilisateur)
    db.commit()
    db.add(
        Token(
            user_id=utilisateur.id,
            access_token=_token_digest(acces),
            refresh_token="autre",
            jti="jti-3",
            expires_at=datetime.utcnow() + timedelta(days=7),
        )
    )
    db.commit()

    retrouvee = (
        db.query(Token).filter(Token.access_token == _token_digest(acces)).first()
    )

    assert retrouvee is not None
    assert retrouvee.jti == "jti-3"


@pytest.mark.parametrize(
    "ligne",
    [
        'WebSocket /api/v1/ws?token=%s [accepted]',
        'GET /api/v1/ws?ticket=%s HTTP/1.1',
        'connexion avec access_token=%s',
        'POST /auth/refresh refresh_token=%s',
    ],
)
def test_le_filtre_de_redaction_coupe_les_secrets_des_journaux(ligne):
    # Le journal d'accès d'uvicorn écrit l'URL COMPLÈTE de chaque requête.
    # Le jeton n'y est plus (voir le ticket WebSocket), mais le filtre reste
    # la dernière barrière — et il couvre maintenant `ticket=` aussi.
    secret = create_access_token({"sub": "a@b.c", "user_id": 1}, jti="jti-4")
    record = logging.LogRecord(
        name="uvicorn.access",
        level=logging.INFO,
        pathname=__file__,
        lineno=1,
        msg=ligne % secret,
        args=(),
        exc_info=None,
    )

    RedactSecretsFilter().filter(record)

    assert secret not in record.getMessage()
    assert JWT_PATTERN.search(record.getMessage()) is None


def test_le_filtre_ne_detruit_pas_la_ligne():
    # Une ligne de journal illisible est presque aussi inutile qu'une ligne
    # absente : on doit encore savoir quelle route a été appelée.
    record = logging.LogRecord(
        name="uvicorn.access",
        level=logging.INFO,
        pathname=__file__,
        lineno=1,
        msg="WebSocket /api/v1/ws?ticket=abcdef [accepted]",
        args=(),
        exc_info=None,
    )

    RedactSecretsFilter().filter(record)
    rendu = record.getMessage()

    assert "/api/v1/ws" in rendu
    assert "[accepted]" in rendu
    assert "abcdef" not in rendu
