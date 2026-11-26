"""L'identité de CETTE base de données, pour que les téléphones sachent
quand le serveur a été remis à zéro.

Le symptôme (25 novembre 2026) : après une remise à zéro, des comptes ne
lisaient plus les messages reçus et ne rejoignaient plus les appels. Les
identifiants de comptes (1, 2, 3…) sont redistribués à d'autres personnes,
alors que chaque téléphone garde ses sessions de chiffrement rangées PAR
identifiant de correspondant : il chiffrait pour « le compte 3 » avec la
session de l'ancien compte 3, que le nouveau ne peut pas ouvrir.

Cet identifiant naît avec la base (créé à la première demande) et disparaît
avec elle. L'application le compare à celui qu'elle a enregistré : s'il a
changé, elle efface ses clés, ses sessions et son cache, puis publie de
nouvelles clés. Il ne révèle rien : un nombre aléatoire, sans rapport avec
un compte.
"""
import uuid

from fastapi import APIRouter, Depends
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session

from app.core.database import get_db
from app.models import SystemSetting

router = APIRouter(tags=["Pokou configuration"])

_KEY = "instance_id"


def instance_id(db: Session) -> str:
    row = db.query(SystemSetting).filter(SystemSetting.key == _KEY).first()
    if row is not None and row.value:
        return row.value
    db.add(SystemSetting(key=_KEY, value=uuid.uuid4().hex))
    try:
        db.commit()
    except IntegrityError:
        # Deux premières demandes simultanées : l'autre a gagné, on lit la sienne.
        db.rollback()
    return db.query(SystemSetting).filter(SystemSetting.key == _KEY).one().value


@router.get("/instance")
def get_instance(db: Session = Depends(get_db)):
    return {"instance_id": instance_id(db)}
