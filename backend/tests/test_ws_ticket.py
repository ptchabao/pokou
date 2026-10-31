"""Le laissez-passer d'ouverture du WebSocket.

Le jeton d'accès voyageait dans l'URL (`/api/v1/ws?token=eyJ...`). Une URL se
retrouve dans le journal d'accès du serveur, chez le reverse proxy, dans les
traces de supervision : quiconque en lisait une pouvait rejouer la session
pendant trente minutes.

Chaque test ci-dessous correspond à une attaque précise contre le
remplacement — un ticket rejoué, périmé, volé, ou émis par une session
révoquée.
"""
import logging
from datetime import datetime, timedelta

import pytest
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker

from app.core.database import Base
from app.models import Token, User, WSTicket
from app.services.auth import ws_ticket_service

TEST_DATABASE_URL = "sqlite:///./test_ws_ticket.db"


@pytest.fixture
def db():
    engine = create_engine(
        TEST_DATABASE_URL, connect_args={"check_same_thread": False}
    )
    Base.metadata.create_all(bind=engine)
    session = sessionmaker(bind=engine)()
    yield session
    session.close()
    Base.metadata.drop_all(bind=engine)
    engine.dispose()
    import os

    if os.path.exists("./test_ws_ticket.db"):
        os.remove("./test_ws_ticket.db")


@pytest.fixture
def user(db):
    row = User(phone="+22890000001", is_active=True)
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


def test_un_ticket_valide_ouvre_la_socket(db, user):
    ticket, expires_in = ws_ticket_service.issue(db, user_id=user.id, jti=None)

    assert ws_ticket_service.consume(db, ticket) == user.id
    assert expires_in == int(ws_ticket_service.TICKET_TTL.total_seconds())


def test_il_ne_sert_qu_UNE_fois(db, user):
    # La propriété centrale. Sans elle, un ticket retrouvé dans un journal
    # resterait exploitable exactement comme le jeton qu'il remplace.
    ticket, _ = ws_ticket_service.issue(db, user_id=user.id, jti=None)

    assert ws_ticket_service.consume(db, ticket) == user.id
    assert ws_ticket_service.consume(db, ticket) is None


def test_la_seconde_tentative_echoue_meme_immediatement(db, user):
    # Deux ouvertures simultanées avec le même ticket : la consommation est
    # une écriture conditionnelle en UN ordre SQL, donc une seule gagne.
    # Lire puis écrire laisserait passer les deux.
    ticket, _ = ws_ticket_service.issue(db, user_id=user.id, jti=None)
    resultats = [ws_ticket_service.consume(db, ticket) for _ in range(5)]

    assert resultats.count(user.id) == 1
    assert resultats.count(None) == 4


def test_un_ticket_perime_est_refuse(db, user):
    ticket, _ = ws_ticket_service.issue(db, user_id=user.id, jti=None)
    row = db.query(WSTicket).first()
    row.expires_at = datetime.utcnow() - timedelta(seconds=1)
    db.commit()

    assert ws_ticket_service.consume(db, ticket) is None


def test_sa_duree_de_vie_est_tres_courte(db, user):
    # Trente secondes suffisent pour aller de la réponse HTTP à la poignée
    # de main ; tout ce qui dépasse est du temps offert à un attaquant.
    assert ws_ticket_service.TICKET_TTL <= timedelta(seconds=60)


def test_un_ticket_inconnu_est_refuse(db, user):
    assert ws_ticket_service.consume(db, "ticket-invente-de-toutes-pieces") is None


def test_le_ticket_d_un_autre_ouvre_SA_socket_et_pas_la_mienne(db, user):
    # Le ticket porte l'identité de son propriétaire. Il n'y a donc pas de
    # « mauvais utilisateur » qui puisse s'en servir pour devenir quelqu'un
    # d'autre : le voler donne accès au compte du volé, jamais à un
    # troisième.
    autre = User(phone="+22890000002", is_active=True)
    db.add(autre)
    db.commit()
    db.refresh(autre)

    ticket, _ = ws_ticket_service.issue(db, user_id=autre.id, jti=None)

    assert ws_ticket_service.consume(db, ticket) == autre.id
    assert ws_ticket_service.consume(db, ticket) != user.id


def test_une_session_revoquee_invalide_ses_tickets(db, user):
    # Sinon « Appareils connectés » mentirait : révoquer fermerait l'API
    # mais laisserait un ticket déjà émis ouvrir une socket.
    _session_row(db, user, "jti-actif")
    ticket, _ = ws_ticket_service.issue(db, user_id=user.id, jti="jti-actif")

    db.query(Token).filter(Token.jti == "jti-actif").update(
        {"revoked_at": datetime.utcnow()}
    )
    db.commit()

    assert ws_ticket_service.consume(db, ticket) is None


def test_une_session_disparue_invalide_aussi(db, user):
    ticket, _ = ws_ticket_service.issue(db, user_id=user.id, jti="jti-fantome")

    assert ws_ticket_service.consume(db, ticket) is None


def test_le_ticket_n_est_jamais_stocke_en_clair(db, user):
    # Un export de base ne doit pas livrer de quoi ouvrir une socket — même
    # raisonnement que pour la table des sessions.
    ticket, _ = ws_ticket_service.issue(db, user_id=user.id, jti=None)
    row = db.query(WSTicket).first()

    assert row.ticket_hash != ticket
    assert ticket not in row.ticket_hash
    assert len(row.ticket_hash) == 64


def test_le_ticket_n_apparait_dans_aucun_journal(db, user, caplog):
    # « logs qui ne permettent pas de récupérer le ticket » : on vérifie ce
    # qui SORT, pas ce que le code a l'air de faire.
    caplog.set_level(logging.DEBUG)
    ticket, _ = ws_ticket_service.issue(db, user_id=user.id, jti=None)
    ws_ticket_service.consume(db, ticket)

    assert ticket not in caplog.text
    assert str(user.id) in caplog.text, "on journalise quand même QUI se connecte"


def test_deux_tickets_ne_se_ressemblent_pas(db, user):
    # Tirés par `secrets`, pas par `random` : la graine de ce dernier se
    # devine depuis l'heure d'émission.
    tickets = {ws_ticket_service.issue(db, user_id=user.id, jti=None)[0] for _ in range(20)}

    assert len(tickets) == 20
    assert all(len(t) >= 40 for t in tickets)


def test_le_menage_supprime_les_perimes_et_garde_les_vivants(db, user):
    # La table grandit d'une ligne par ouverture de socket, donc vite.
    ws_ticket_service.issue(db, user_id=user.id, jti=None)
    vieux = WSTicket(
        ticket_hash="a" * 64,
        user_id=user.id,
        expires_at=datetime.utcnow() - timedelta(days=1),
    )
    db.add(vieux)
    db.commit()

    assert ws_ticket_service.purge_expired(db) == 1
    assert db.query(WSTicket).count() == 1


# ── « Appareils connectés » révoque-t-il vraiment ? ───────────────────────


def test_revoquer_un_appareil_ferme_aussi_ses_tickets(db, user):
    """La chaîne complète, telle que l'utilisateur la vit.

    L'écran « Appareils connectés » ne révoquait RIEN : il supprimait le
    jeton de notification. L'appareil perdait ses notifications et gardait
    tout le reste — lire les conversations, écrire, renouveler sa session
    pendant sept jours. Quelqu'un qui révoquait un téléphone perdu croyait
    avoir fermé la porte.
    """
    from app.models import DeviceToken

    session = _session_row(db, user, "jti-du-telephone-perdu")
    db.add(
        DeviceToken(
            user_id=user.id,
            token="fcm-du-telephone-perdu",
            platform="android",
            session_jti="jti-du-telephone-perdu",
        )
    )
    db.commit()

    ticket_avant, _ = ws_ticket_service.issue(
        db, user_id=user.id, jti="jti-du-telephone-perdu"
    )

    # Ce que fait la route DELETE /devices/{id} : révoquer la session, puis
    # supprimer l'appareil.
    session.revoked_at = datetime.utcnow()
    db.query(DeviceToken).filter(DeviceToken.session_jti == "jti-du-telephone-perdu").delete()
    db.commit()

    assert ws_ticket_service.consume(db, ticket_avant) is None, (
        "un ticket déjà émis ne doit pas survivre à la révocation"
    )
    assert (
        ws_ticket_service.consume(
            db, ws_ticket_service.issue(db, user_id=user.id, jti="jti-du-telephone-perdu")[0]
        )
        is None
    ), "et aucun nouveau ticket ne peut être obtenu par cette session"
