"""Pokou — qui peut voir les statuts de qui.

Isolé dans un service parce que la règle doit être appliquée à DEUX endroits
qui ne se parlent pas : le fil de statuts (routes/status.py) et l'accès aux
pièces jointes (routes/media.py). Si seul le fil filtrait, il suffirait de
demander `GET /media/{id}` pour voir la photo d'un statut qu'on n'a pas le
droit de voir.
"""
from typing import Set

from sqlalchemy.orm import Session

from app.models import Contact, StatusPrivacy, StatusPrivacyEntry

MODE_CONTACTS = "CONTACTS"
MODE_NOBODY = "NOBODY"
MODE_EXCEPT = "EXCEPT"
MODE_ONLY = "ONLY"

VALID_MODES = (MODE_CONTACTS, MODE_NOBODY, MODE_EXCEPT, MODE_ONLY)

# Sans ligne enregistrée, un compte garde le comportement d'avant : visible
# par ses contacts.
DEFAULT_MODE = MODE_CONTACTS


def _entries(db: Session, author_id: int) -> Set[int]:
    return {
        row[0]
        for row in db.query(StatusPrivacyEntry.target_user_id)
        .filter(StatusPrivacyEntry.user_id == author_id)
        .all()
    }


def _is_in_author_contacts(db: Session, author_id: int, viewer_id: int) -> bool:
    """Le spectateur est-il dans le carnet de l'AUTEUR ? C'est l'auteur qui
    choisit son public : l'inverse permettrait de s'inviter dans les statuts
    de n'importe qui en l'ajoutant à ses propres contacts."""
    return db.query(Contact).filter(
        Contact.owner_user_id == author_id, Contact.contact_user_id == viewer_id
    ).first() is not None


def can_view_statuses_of(db: Session, author_id: int, viewer_id: int) -> bool:
    if author_id == viewer_id:
        return True

    privacy = db.query(StatusPrivacy).filter(StatusPrivacy.user_id == author_id).first()
    mode = privacy.mode if privacy else DEFAULT_MODE

    if mode == MODE_NOBODY:
        return False
    if mode == MODE_ONLY:
        # Pas besoin d'être un contact : l'auteur a désigné nommément son
        # public.
        return viewer_id in _entries(db, author_id)
    if mode == MODE_EXCEPT:
        return _is_in_author_contacts(db, author_id, viewer_id) and viewer_id not in _entries(db, author_id)
    return _is_in_author_contacts(db, author_id, viewer_id)


def visible_author_ids(db: Session, viewer_id: int, candidate_ids: Set[int]) -> Set[int]:
    """Filtre une liste d'auteurs en une passe — le fil en évalue plusieurs
    d'un coup."""
    return {
        author_id
        for author_id in candidate_ids
        if can_view_statuses_of(db, author_id, viewer_id)
    }


def viewer_ids_for(db: Session, author_id: int) -> Set[int]:
    """L'INVERSE de `can_view_statuses_of` : qui verra ce statut ?

    `can_view_statuses_of` répond spectateur par spectateur, ce qui convient
    au fil (un seul lecteur, quelques auteurs). Pour POUSSER un statut
    nouvellement publié, la question se retourne : un auteur, potentiellement
    des centaines de lecteurs. Les évaluer un par un ferait une requête par
    personne à chaque statut publié.

    Deux conditions se cumulent, et elles ne disent pas la même chose :

    - le lecteur doit avoir l'auteur DANS SON carnet, sinon le statut
      n'apparaîtrait pas dans son fil de toute façon (voir get_feed) ;
    - l'auteur doit l'autoriser, selon le mode qu'il a choisi. C'est
      l'auteur qui décide de son public — l'inverse permettrait de s'inviter
      dans les statuts de n'importe qui en l'ajoutant à ses contacts.

    Trois requêtes au total, quel que soit le nombre de lecteurs.
    """
    audience = {
        row[0]
        for row in db.query(Contact.owner_user_id)
        .filter(Contact.contact_user_id == author_id)
        .all()
    } - {author_id}
    if not audience:
        return set()

    privacy = db.query(StatusPrivacy).filter(StatusPrivacy.user_id == author_id).first()
    mode = privacy.mode if privacy else DEFAULT_MODE

    if mode == MODE_NOBODY:
        return set()
    if mode == MODE_ONLY:
        # L'auteur a désigné nommément son public : être dans son carnet
        # n'entre pas en ligne de compte.
        return audience & _entries(db, author_id)

    author_contacts = {
        row[0]
        for row in db.query(Contact.contact_user_id)
        .filter(Contact.owner_user_id == author_id, Contact.contact_user_id.isnot(None))
        .all()
    }
    if mode == MODE_EXCEPT:
        return (audience & author_contacts) - _entries(db, author_id)
    return audience & author_contacts


def get_privacy(db: Session, user_id: int) -> dict:
    privacy = db.query(StatusPrivacy).filter(StatusPrivacy.user_id == user_id).first()
    return {
        "mode": privacy.mode if privacy else DEFAULT_MODE,
        "user_ids": sorted(_entries(db, user_id)) if privacy else [],
    }


def set_privacy(db: Session, user_id: int, mode: str, target_user_ids: list[int]) -> dict:
    privacy = db.query(StatusPrivacy).filter(StatusPrivacy.user_id == user_id).first()
    if privacy is None:
        privacy = StatusPrivacy(user_id=user_id, mode=mode)
        db.add(privacy)
        db.flush()
    else:
        privacy.mode = mode

    # La liste est remplacée, pas fusionnée : c'est un réglage, pas un
    # journal d'ajouts.
    db.query(StatusPrivacyEntry).filter(StatusPrivacyEntry.user_id == user_id).delete()
    if mode in (MODE_EXCEPT, MODE_ONLY):
        for target_id in dict.fromkeys(target_user_ids):
            if target_id == user_id:
                continue
            db.add(StatusPrivacyEntry(user_id=user_id, target_user_id=target_id))

    db.commit()
    return get_privacy(db, user_id)
