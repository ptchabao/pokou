"""Pokou — rattachement des fiches de carnet qui attendaient un numéro.

Une fiche ajoutée à la main pour un numéro qui n'est pas encore sur Pokou
existe bel et bien en base, avec `contact_user_id` à NULL : on garde le nom
et le numéro, on ne sait simplement pas encore à quel compte les rattacher.

Jusqu'ici personne ne repassait jamais dessus. Quelqu'un que vous aviez
enregistré avant qu'il n'installe l'application restait indéfiniment
« non inscrit » dans votre carnet, même des mois après son arrivée — à
moins que la synchronisation du répertoire de l'appareil ne le rattrape,
ce qui suppose que son numéro soit AUSSI dans le répertoire du téléphone.

Le rattachement se fait donc au seul moment où l'information apparaît :
quand la personne valide son code. C'est aussi ce qui permet de prévenir
en temps réel ceux qui l'attendaient, sans jamais rien stocker de plus —
ces fiches existaient déjà, écrites par leurs propriétaires.
"""
import logging
from typing import Any, Dict, List

from sqlalchemy.orm import Session

from app.models import Contact, User

logger = logging.getLogger(__name__)


def link_pending_contacts(db: Session, user: User) -> List[int]:
    """Rattache à `user` toutes les fiches en attente portant son numéro.

    Renvoie les identifiants des propriétaires de ces fiches — ceux à qui
    l'arrivée doit être annoncée. Liste vide dans le cas courant, qui est
    celui d'une reconnexion : la fonction est appelée à CHAQUE validation de
    code, pas seulement à la création du compte. Rendre l'appel conditionnel
    à « le compte vient d'être créé » ferait une branche de plus à maintenir
    pour économiser une requête indexée, et laisserait sans recours toute
    fiche qui aurait dangé pour une autre raison.
    """
    if not user.phone:
        return []

    pending = (
        db.query(Contact)
        .filter(Contact.phone == user.phone, Contact.contact_user_id.is_(None))
        .all()
    )
    if not pending:
        return []

    for contact in pending:
        contact.contact_user_id = user.id
    db.commit()

    owners = sorted({c.owner_user_id for c in pending})
    logger.info("Pokou: %s fiche(s) rattachée(s) au compte %s", len(pending), user.id)
    return owners


def contact_registered_event(user: User) -> Dict[str, Any]:
    """L'événement poussé aux propriétaires concernés.

    Il ne dit rien que le destinataire ne puisse déjà apprendre : le numéro
    vient de son propre carnet, et un simple rafraîchissement le lui aurait
    appris. Ce qui change est le DÉLAI, pas la divulgation.
    """
    return {
        "type": "contact:registered",
        "contact_user_id": user.id,
        "phone": user.phone,
        "display_name": user.full_name,
    }
