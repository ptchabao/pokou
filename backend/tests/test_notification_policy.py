"""La décision de notifier — ce que la sourdine doit couvrir, et pas.

Ces règles sont exactement celles qu'on regrette d'avoir laissées implicites :
chacune est un compromis entre « ne pas déranger » et « ne pas faire manquer
quelque chose », et une erreur dans un sens comme dans l'autre coûte un
utilisateur.
"""
from datetime import datetime, timedelta

import pytest
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker

from app.core.database import Base
from app.models import Contact, Group, GroupMember, User
from app.services.messaging.notification_policy import NotificationEvent, Priority, decide


@pytest.fixture()
def db():
    engine = create_engine("sqlite:///:memory:")
    Base.metadata.create_all(engine)
    session = sessionmaker(bind=engine)()
    yield session
    session.close()


def _user(db, phone: str) -> User:
    user = User(phone=phone, full_name=phone)
    db.add(user)
    db.commit()
    db.refresh(user)
    return user


@pytest.fixture()
def pair(db):
    return _user(db, "+22890000001"), _user(db, "+22890000002")


def _mute_contact(db, owner: User, other: User, *, muted: bool):
    db.add(
        Contact(
            owner_user_id=owner.id,
            contact_user_id=other.id,
            display_name="Kodjo",
            phone=other.phone,
            muted_until=datetime.utcnow() + timedelta(hours=8) if muted else None,
        )
    )
    db.commit()


def _group_with_member(db, member: User, *, muted: bool) -> Group:
    group = Group(name="Marché de Lomé", created_by=member.id)
    db.add(group)
    db.commit()
    db.refresh(group)
    db.add(
        GroupMember(
            group_id=group.id,
            user_id=member.id,
            muted_until=datetime.utcnow() + timedelta(hours=8) if muted else None,
        )
    )
    db.commit()
    return group


def test_un_message_ordinaire_passe_en_priorite_normale(db, pair):
    me, other = pair
    _mute_contact(db, me, other, muted=False)

    verdict = decide(
        db, recipient_id=me.id, event=NotificationEvent.DIRECT_MESSAGE, sender_id=other.id
    )

    assert verdict.deliver
    assert verdict.priority is Priority.NORMAL
    assert not verdict.muted


def test_une_conversation_en_sourdine_notifie_sans_bruit(db, pair):
    # La sourdine porte sur le BRUIT, pas sur l'information : la notification
    # reste visible en ouvrant le volet. La supprimer ferait disparaître des
    # messages sans que personne ne l'ait demandé.
    me, other = pair
    _mute_contact(db, me, other, muted=True)

    verdict = decide(
        db, recipient_id=me.id, event=NotificationEvent.DIRECT_MESSAGE, sender_id=other.id
    )

    assert verdict.deliver
    assert verdict.muted


def test_un_appel_ignore_la_sourdine_de_la_conversation(db, pair):
    # Mettre une conversation en sourdine veut dire « ne me lis pas les
    # messages à voix haute », pas « ne me préviens pas si cette personne
    # m'appelle ». Un appel manqué ne se rattrape pas.
    me, other = pair
    _mute_contact(db, me, other, muted=True)

    verdict = decide(
        db, recipient_id=me.id, event=NotificationEvent.CALL, sender_id=other.id
    )

    assert verdict.deliver
    assert verdict.priority is Priority.URGENT
    assert not verdict.muted


def test_une_mention_passe_meme_dans_un_groupe_en_sourdine(db, pair):
    # Quelqu'un qui a silencé un groupe de cent personnes veut toujours
    # savoir qu'on s'adresse à LUI — c'est la seule raison de rouvrir un
    # groupe qu'on a cessé de suivre.
    me, _ = pair
    group = _group_with_member(db, me, muted=True)

    verdict = decide(
        db, recipient_id=me.id, event=NotificationEvent.GROUP_MENTION, group_id=group.id
    )

    assert verdict.deliver
    assert verdict.muted, "elle passe, mais sans rompre le silence demandé"


def test_une_mention_hors_sourdine_est_prioritaire(db, pair):
    me, _ = pair
    group = _group_with_member(db, me, muted=False)

    verdict = decide(
        db, recipient_id=me.id, event=NotificationEvent.GROUP_MENTION, group_id=group.id
    )

    assert verdict.priority is Priority.HIGH


def test_un_message_de_groupe_en_sourdine_ne_sonne_pas(db, pair):
    me, _ = pair
    group = _group_with_member(db, me, muted=True)

    verdict = decide(
        db, recipient_id=me.id, event=NotificationEvent.GROUP_MESSAGE, group_id=group.id
    )

    assert verdict.deliver
    assert verdict.muted


def test_une_reaction_en_sourdine_ne_passe_pas_du_tout(db, pair):
    # L'événement de plus faible valeur. En faire vibrer un téléphone qu'on a
    # explicitement demandé de taire, c'est ce qui pousse à désinstaller.
    me, other = pair
    _mute_contact(db, me, other, muted=True)

    verdict = decide(
        db, recipient_id=me.id, event=NotificationEvent.REACTION, sender_id=other.id
    )

    assert not verdict.deliver


def test_une_reaction_hors_sourdine_passe_en_priorite_basse(db, pair):
    me, other = pair
    _mute_contact(db, me, other, muted=False)

    verdict = decide(
        db, recipient_id=me.id, event=NotificationEvent.REACTION, sender_id=other.id
    )

    assert verdict.deliver
    assert verdict.priority is Priority.LOW


def test_une_sourdine_expiree_ne_fait_plus_taire(db, pair):
    # La sourdine est une DATE et non un booléen : elle doit s'éteindre toute
    # seule, sans tâche de fond pour la nettoyer.
    me, other = pair
    db.add(
        Contact(
            owner_user_id=me.id,
            contact_user_id=other.id,
            display_name="Kodjo",
            phone=other.phone,
            muted_until=datetime.utcnow() - timedelta(minutes=1),
        )
    )
    db.commit()

    verdict = decide(
        db, recipient_id=me.id, event=NotificationEvent.DIRECT_MESSAGE, sender_id=other.id
    )

    assert not verdict.muted


def test_la_decision_voyage_jusqu_au_client(db, pair):
    # Le client a besoin des DEUX informations pour choisir sa présentation :
    # le niveau d'interruption, et le fait que la conversation est en
    # sourdine. FCM n'accepte que des chaînes dans `data`.
    me, other = pair
    _mute_contact(db, me, other, muted=True)

    payload = decide(
        db, recipient_id=me.id, event=NotificationEvent.DIRECT_MESSAGE, sender_id=other.id
    ).as_payload()

    assert payload == {"priority": "normal", "muted": "1"}
    assert all(isinstance(value, str) for value in payload.values())
