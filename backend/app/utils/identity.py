"""Identité d'un compte Pokou — ce qui le désigne partout pareil."""

from datetime import datetime
from typing import Optional


def est_certifie(user) -> bool:
    """Le compte porte-t-il le ✓ à côté de son nom ?

    Une SEULE fonction pour toute l'API. Recopier `user.is_verified` dans
    chaque route garantirait qu'au neuvième écran le badge manque — et un
    badge d'identité qui apparaît par intermittence est pire qu'absent : il
    apprend à ne pas s'y fier.

    **À ne pas confondre avec [est_vendeur_verifie].** Ce ✓ répond à « est-ce
    bien cette personne ? ». Il se lit dans une conversation, un groupe, un
    statut, une chaîne — partout où quelqu'un est désigné.
    """
    return bool(getattr(user, "is_verified", False))


def est_vendeur_verifie(user) -> bool:
    """Le VENDEUR est-il vérifié sur le marché ?

    Question tout à fait différente : « puis-je lui acheter quelque
    chose ? ». Elle n'a de sens que sur une annonce ou une fiche vendeur,
    elle se paie 5 000 FCFA et l'équipe examine une pièce d'identité.

    Les deux ont failli n'en faire qu'une. Le ✓ à côté d'un nom dans une
    conversation aurait alors voulu dire « vendeur payant », ce que personne
    ne devine — un ✓ à côté d'un nom se lit universellement comme « c'est
    bien cette personne ».
    """
    if not bool(getattr(user, "is_certified_seller", False)):
        return False
    expires_at = getattr(user, "certified_seller_until", None)
    return expires_at is None or expires_at > datetime.utcnow()


def nom_certifie(user) -> Optional[str]:
    """Le nom qu'un compte CERTIFIÉ s'est donné, ou `None`.

    `None` aussi pour un compte certifié sans nom : il n'y a alors rien à
    imposer, et l'appelant retombe sur le carnet ou le numéro."""
    if user is None or not est_certifie(user):
        return None
    nom = (getattr(user, "full_name", None) or "").strip()
    return nom or None


def nom_affiche(user, nom_du_carnet: Optional[str] = None, repli: str = "Utilisateur") -> str:
    """LE nom sous lequel quelqu'un apparaît, partout.

    1. Compte certifié qui a un nom : CE nom, toujours — y compris chez qui
       l'a enregistré autrement, et chez qui n'a pas son numéro. Le ✓ dit
       « c'est bien cette personne » ; il serait contredit par un surnom
       local qui la désigne autrement à côté du badge.
    2. Sinon, le nom de MON carnet : c'est sous lui que je connais la
       personne.
    3. Sinon, le nom qu'elle s'est choisi, puis son numéro.

    Une seule fonction, pour la même raison que `est_certifie` : recopiée
    route par route, la règle finirait par différer d'un écran à l'autre."""
    certifie = nom_certifie(user)
    if certifie:
        return certifie
    if nom_du_carnet and nom_du_carnet.strip():
        return nom_du_carnet
    if user is None:
        return repli
    return user.full_name or user.phone or repli
