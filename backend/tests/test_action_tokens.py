"""Les laissez-passer que porte une notification push.

La couche native doit pouvoir accepter ou refuser un appel depuis l'écran
verrouillé, sans que Flutter démarre. Elle ne peut donc produire aucun jeton
de session : elle rend celui que le push lui a donné.

Chaque test ci-dessous correspond à une attaque ou à un cas limite précis —
un jeton rejoué, détourné vers une autre action, présenté après l'appel, ou
issu d'une session révoquée.
"""
from datetime import datetime, timedelta

import pytest
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker

from app.core.database import Base
from app.models import ActionToken, Token, User
from app.services.auth import action_token_service as ats

TEST_DATABASE_URL = "sqlite:///./test_action_tokens.db"
engine = create_engine(TEST_DATABASE_URL, connect_args={"check_same_thread": False})
Base.metadata.create_all(bind=engine)
TestingSessionLocal = sessionmaker(bind=engine)


@pytest.fixture
def db():
    session = TestingSessionLocal()
    session.query(ActionToken).delete()
    session.query(Token).delete()
    session.commit()
    yield session
    session.close()


@pytest.fixture
def user(db):
    row = db.query(User).filter(User.phone == "+22890200001").first()
    if row is None:
        row = User(phone="+22890200001", is_active=True)
        db.add(row)
        db.commit()
        db.refresh(row)
    return row


def _session_row(db, user, jti, revoked=False):
    row = Token(
        user_id=user.id,
        access_token="empreinte",
        refresh_token="empreinte",
        jti=jti,
        expires_at=datetime.utcnow() + timedelta(days=7),
        revoked_at=datetime.utcnow() if revoked else None,
    )
    db.add(row)
    db.commit()
    return row


def test_un_jeton_valide_autorise_son_action(db, user):
    token = ats.issue(db, scope=ats.SCOPE_CALL_ACCEPT, user_id=user.id, room="r1")

    row = ats.consume(db, token, expected_scope=ats.SCOPE_CALL_ACCEPT)

    assert row is not None
    assert row.user_id == user.id
    assert row.room == "r1"


def test_il_ne_sert_qu_UNE_fois(db, user):
    # C'est aussi ce qui rend l'action idempotente : Android peut délivrer
    # deux fois le même appui.
    token = ats.issue(db, scope=ats.SCOPE_CALL_ACCEPT, user_id=user.id, room="r1")

    assert ats.consume(db, token, expected_scope=ats.SCOPE_CALL_ACCEPT) is not None
    assert ats.consume(db, token, expected_scope=ats.SCOPE_CALL_ACCEPT) is None


def test_cinq_delivrances_simultanees_n_en_laissent_passer_qu_une(db, user):
    # La consommation est une écriture conditionnelle en UN ordre SQL. Lire
    # puis écrire laisserait passer les cinq.
    token = ats.issue(db, scope=ats.SCOPE_CALL_ACCEPT, user_id=user.id, room="r1")

    resultats = [
        ats.consume(db, token, expected_scope=ats.SCOPE_CALL_ACCEPT) for _ in range(5)
    ]

    assert sum(1 for r in resultats if r is not None) == 1


def test_apres_consommation_on_sait_que_c_etait_DEJA_fait(db, user):
    # La distinction qui permet de répondre 200 plutôt qu'une erreur sur un
    # double appui : du point de vue de l'utilisateur, l'action a réussi.
    token = ats.issue(db, scope=ats.SCOPE_CALL_ACCEPT, user_id=user.id, room="r1")
    ats.consume(db, token, expected_scope=ats.SCOPE_CALL_ACCEPT)

    assert ats.was_consumed(db, token, expected_scope=ats.SCOPE_CALL_ACCEPT) is True
    assert ats.was_consumed(db, "jamais-vu", expected_scope=ats.SCOPE_CALL_ACCEPT) is False


def test_un_jeton_d_acceptation_ne_sert_pas_a_refuser(db, user):
    # La portée étroite. Sans ce contrôle, un seul jeton ouvrirait toutes les
    # actions du même appel.
    token = ats.issue(db, scope=ats.SCOPE_CALL_ACCEPT, user_id=user.id, room="r1")

    assert ats.consume(db, token, expected_scope=ats.SCOPE_CALL_DECLINE) is None
    # Et il reste utilisable pour ce à quoi il donne droit.
    assert ats.consume(db, token, expected_scope=ats.SCOPE_CALL_ACCEPT) is not None


def test_un_jeton_perime_est_refuse(db, user):
    token = ats.issue(db, scope=ats.SCOPE_CALL_ACCEPT, user_id=user.id, room="r1")
    db.query(ActionToken).update({"expires_at": datetime.utcnow() - timedelta(seconds=1)})
    db.commit()

    assert ats.consume(db, token, expected_scope=ats.SCOPE_CALL_ACCEPT) is None


def test_la_duree_d_un_jeton_d_appel_est_celle_de_la_sonnerie(db, user):
    # Un jeton qui survivrait à l'appel n'aurait plus rien à autoriser.
    assert ats.CALL_TTL <= timedelta(seconds=120)
    # Une notification de message, elle, reste affichée : répondre le
    # lendemain matin est un usage normal.
    assert ats.REPLY_TTL >= timedelta(hours=12)


def test_un_appel_donne_DEUX_jetons_distincts(db, user):
    # Un seul jeton partagé serait consommé par la première action : après un
    # « Répondre » suivi d'un « Refuser », le refus se dirait réussi alors
    # qu'on a répondu.
    paire = ats.issue_call_pair(db, user_id=user.id, room="r1")

    assert paire["answer_token"] != paire["decline_token"]
    assert ats.consume(db, paire["answer_token"], expected_scope=ats.SCOPE_CALL_ACCEPT)
    assert ats.consume(db, paire["decline_token"], expected_scope=ats.SCOPE_CALL_DECLINE)


def test_une_session_revoquee_invalide_ses_jetons(db, user):
    # Sinon « Appareils connectés » mentirait : révoquer fermerait l'API mais
    # laisserait un jeton déjà émis répondre à un appel.
    _session_row(db, user, "jti-actif")
    token = ats.issue(
        db, scope=ats.SCOPE_CALL_ACCEPT, user_id=user.id, room="r1", jti="jti-actif"
    )

    db.query(Token).filter(Token.jti == "jti-actif").update(
        {"revoked_at": datetime.utcnow()}
    )
    db.commit()

    assert ats.consume(db, token, expected_scope=ats.SCOPE_CALL_ACCEPT) is None


def test_le_jeton_n_est_jamais_stocke_en_clair(db, user):
    token = ats.issue(db, scope=ats.SCOPE_CALL_ACCEPT, user_id=user.id, room="r1")
    row = db.query(ActionToken).first()

    assert row.token_hash != token
    assert len(row.token_hash) == 64


def test_le_jeton_n_apparait_dans_aucun_journal(db, user, caplog):
    import logging

    caplog.set_level(logging.DEBUG)
    token = ats.issue(db, scope=ats.SCOPE_CALL_ACCEPT, user_id=user.id, room="r1")
    ats.consume(db, token, expected_scope=ats.SCOPE_CALL_ACCEPT)

    assert token not in caplog.text
    assert ats.SCOPE_CALL_ACCEPT in caplog.text, "la portée, elle, se journalise"


def test_une_portee_inconnue_est_refusee(db, user):
    # On n'invente pas un droit à la volée.
    with pytest.raises(ValueError):
        ats.issue(db, scope="tout_faire", user_id=user.id, room="r1")

    assert ats.consume(db, "peu importe", expected_scope="tout_faire") is None


def test_deux_jetons_ne_se_ressemblent_pas(db, user):
    jetons = {
        ats.issue(db, scope=ats.SCOPE_CALL_ACCEPT, user_id=user.id, room="r1")
        for _ in range(20)
    }

    assert len(jetons) == 20
    assert all(len(j) >= 40 for j in jetons)


def test_le_menage_garde_les_vivants(db, user):
    ats.issue(db, scope=ats.SCOPE_CALL_ACCEPT, user_id=user.id, room="r1")
    db.add(
        ActionToken(
            token_hash="a" * 64,
            scope=ats.SCOPE_CALL_ACCEPT,
            user_id=user.id,
            expires_at=datetime.utcnow() - timedelta(days=5),
        )
    )
    db.commit()

    assert ats.purge_expired(db) == 1
    assert db.query(ActionToken).count() == 1
