"""Qui a le droit de voir quoi — une seule question, posée partout pareil.

── Pourquoi un service, et pas huit réglages ────────────────────────────

Huit règles de confidentialité, c'est huit occasions d'écrire « si c'est un
contact, alors… ». La neuvième route l'oublierait, et une règle oubliée à un
seul endroit n'est pas une règle : c'est une fuite avec une case à cocher
devant.

Ici, chaque point d'entrée pose la MÊME question :

    if not privacy_service.peut_voir(db, cible_id, spectateur_id, Aspect.PHOTO):
        ...

Ajouter une règle demain, c'est une valeur dans [Aspect] et une colonne —
pas une relecture de toutes les routes.

── Ce que ce service décide, et ce qu'il ne décide pas ──────────────────

Il répond « ce spectateur a-t-il le droit ». Il ne sait pas ce qu'on va en
faire, et c'est voulu : la même réponse sert à masquer un champ dans une
réponse JSON, à refuser un média, à filtrer une liste. Une fonction qui
renverrait déjà du JSON masqué ne servirait qu'au premier appelant.

Il ne décide pas non plus **à la place du fonctionnement d'un groupe**. Les
membres d'un groupe se connaissent entre eux quoi qu'il arrive : la règle
`GROUP_MEMBERSHIP` porte sur la visibilité PUBLIQUE de l'appartenance, vue
de l'extérieur. Confondre les deux casserait les groupes au nom de la
confidentialité, ce qui n'aiderait personne.

── La règle d'or ────────────────────────────────────────────────────────

**Le serveur ne doit jamais envoyer une donnée que la règle interdit.** Pas
« le client ne l'affiche pas » : le client ne la REÇOIT pas. Un champ masqué
part à `null`, jamais en 403 — un refus explicite apprendrait au demandeur
que quelqu'un se cache, exactement ce qu'il ne veut pas dire.
"""
import enum
from typing import Iterable, Optional, Set

from sqlalchemy import or_
from sqlalchemy.orm import Session

from app.models import Contact, PrivacyAudience, User


class Aspect(str, enum.Enum):
    """Ce dont on demande la visibilité.

    Un par colonne de confidentialité. L'énumération existe pour que l'appel
    se lise — `peut_voir(..., Aspect.DERNIERE_ACTIVITE)` plutôt qu'une chaîne
    qu'une faute de frappe rendrait silencieusement permissive.
    """

    DERNIERE_ACTIVITE = "privacy_last_seen"
    EN_LIGNE = "privacy_online"
    PHOTO_DE_PROFIL = "privacy_profile_photo"
    INFOS_DE_PROFIL = "privacy_profile_info"
    APPARTENANCE_GROUPES = "privacy_group_membership"
    INVITATIONS_GROUPES = "privacy_group_invites"


def regle(cible: User, aspect: Aspect) -> PrivacyAudience:
    """La règle en vigueur, avec un repli sûr.

    `CONTACTS` si la colonne est absente ou nulle — une ligne écrite avant
    la migration, un objet partiellement chargé. Le repli va vers le PLUS
    RESTRICTIF des deux comportements plausibles : se tromper vers
    « personne ne voit » se corrige d'un réglage, se tromper vers « tout le
    monde voit » ne se rattrape pas.
    """
    valeur = getattr(cible, aspect.value, None)
    if valeur is None:
        return PrivacyAudience.CONTACTS
    if isinstance(valeur, PrivacyAudience):
        return valeur
    try:
        return PrivacyAudience(str(valeur))
    except ValueError:
        return PrivacyAudience.CONTACTS


def est_dans_les_contacts(db: Session, proprietaire_id: int, autre_id: int) -> bool:
    """Ces deux personnes se connaissent-elles ?

    **Dans un sens OU dans l'autre**, et ce n'est pas un relâchement : c'est
    ce que « mes contacts » a toujours voulu dire dans Pokou, et la raison
    est écrite depuis longtemps dans `media.py::_is_contact_of` — la
    relation Contact est unidirectionnelle, et quelqu'un peut parfaitement
    répondre à un appel ou à un message sans avoir ajouté son
    interlocuteur.

    La première version de cette fonction ne regardait que le carnet de
    celui qui se montre. C'était défendable en théorie, et deux tests l'ont
    immédiatement mise en défaut :

    - la présence disparaissait entre deux personnes qui se parlaient, tant
      que l'une des deux n'avait pas enregistré l'autre ;
    - créer un groupe échouait en 403 dès qu'un invité n'avait pas ajouté
      l'organisateur — c'est-à-dire, sur ce marché, presque toujours.

    Autrement dit : ce réglage RESSERRAIT le produit sans que personne l'ait
    demandé, ce que la migration s'engageait précisément à ne pas faire.
    Réduire la visibilité est une décision à prendre explicitement, pas un
    effet de bord d'un écran de réglages.

    Qui veut vraiment restreindre a `NOBODY`, qui est sans ambiguïté.
    """
    if proprietaire_id == autre_id:
        return True
    return (
        db.query(Contact.id)
        .filter(
            or_(
                (Contact.owner_user_id == proprietaire_id)
                & (Contact.contact_user_id == autre_id),
                (Contact.owner_user_id == autre_id)
                & (Contact.contact_user_id == proprietaire_id),
            )
        )
        .first()
        is not None
    )


def peut_voir(
    db: Session,
    cible_id: int,
    spectateur_id: Optional[int],
    aspect: Aspect,
    *,
    cible: Optional[User] = None,
) -> bool:
    """Ce spectateur a-t-il le droit de voir cet aspect de cette personne ?

    [cible] permet de passer l'utilisateur déjà chargé et d'éviter une
    requête — une liste de trente conversations poserait sinon trente fois
    la même.
    """
    # Soi-même : toujours. Se cacher des autres n'a aucune raison de se
    # cacher de soi, et un écran de réglages qui masque ce qu'il règle serait
    # absurde.
    if spectateur_id is not None and spectateur_id == cible_id:
        return True

    personne = cible or db.query(User).filter(User.id == cible_id).first()
    if personne is None:
        return False

    # Un bot est la vitrine d'une entreprise : son nom, sa photo et sa
    # description sont publics par nature — personne n'a de bot « dans ses
    # contacts » avant de lui écrire, et c'est en le voyant qu'on décide de
    # le faire.
    if getattr(personne, "is_bot", False):
        return True

    match regle(personne, aspect):
        case PrivacyAudience.EVERYONE:
            return True
        case PrivacyAudience.NOBODY:
            return False
        case _:
            # Anonyme : « mes contacts » exclut par construction quelqu'un
            # qu'on ne peut pas identifier.
            if spectateur_id is None:
                return False
            return est_dans_les_contacts(db, cible_id, spectateur_id)


def filtrer_visibles(
    db: Session,
    cible_ids: Iterable[int],
    spectateur_id: int,
    aspect: Aspect,
) -> Set[int]:
    """La version en LOT — ceux dont l'aspect est visible par ce spectateur.

    Une liste de conversations, une liste de membres, une liste de vues :
    chacune interrogerait sinon la base une fois par ligne. Deux requêtes
    ici, quelle que soit la longueur.
    """
    ids = {i for i in cible_ids if i is not None}
    if not ids:
        return set()

    personnes = db.query(User).filter(User.id.in_(ids)).all()

    visibles: Set[int] = set()
    a_verifier: Set[int] = set()
    for personne in personnes:
        if personne.id == spectateur_id:
            visibles.add(personne.id)
            continue
        match regle(personne, aspect):
            case PrivacyAudience.EVERYONE:
                visibles.add(personne.id)
            case PrivacyAudience.NOBODY:
                pass
            case _:
                a_verifier.add(personne.id)

    if a_verifier:
        # Les DEUX sens, comme `est_dans_les_contacts` — sans quoi le
        # chemin en lot serait plus strict que le chemin unitaire, et une
        # liste cacherait ce qu'une fiche montre.
        lignes = (
            db.query(Contact.owner_user_id, Contact.contact_user_id)
            .filter(
                or_(
                    (Contact.owner_user_id.in_(a_verifier))
                    & (Contact.contact_user_id == spectateur_id),
                    (Contact.owner_user_id == spectateur_id)
                    & (Contact.contact_user_id.in_(a_verifier)),
                )
            )
            .all()
        )
        for proprietaire, contact in lignes:
            visibles.add(proprietaire if proprietaire in a_verifier else contact)

    return visibles


def reglages(user: User) -> dict:
    """Ce que l'écran « Confidentialité » affiche et enregistre."""
    return {
        "last_seen": regle(user, Aspect.DERNIERE_ACTIVITE).value,
        "online": regle(user, Aspect.EN_LIGNE).value,
        "profile_photo": regle(user, Aspect.PHOTO_DE_PROFIL).value,
        "profile_info": regle(user, Aspect.INFOS_DE_PROFIL).value,
        "group_membership": regle(user, Aspect.APPARTENANCE_GROUPES).value,
        "group_invites": regle(user, Aspect.INVITATIONS_GROUPES).value,
        # Booléens, et non une audience à trois valeurs : les accusés de
        # lecture portent une RÉCIPROCITÉ (les couper me prive de ceux des
        # autres), ce qu'une audience ne saurait pas exprimer. Les laisser
        # ici permet à l'écran de tout lire d'un coup.
        "read_receipts": bool(user.read_receipts_enabled),
        "presence_reciprocal": bool(user.presence_visible),
    }


#: Ce que la route de mise à jour accepte, et rien d'autre.
CHAMPS_AUDIENCE = {
    "last_seen": Aspect.DERNIERE_ACTIVITE,
    "online": Aspect.EN_LIGNE,
    "profile_photo": Aspect.PHOTO_DE_PROFIL,
    "profile_info": Aspect.INFOS_DE_PROFIL,
    "group_membership": Aspect.APPARTENANCE_GROUPES,
    "group_invites": Aspect.INVITATIONS_GROUPES,
}


def appliquer(db: Session, user: User, modifications: dict) -> dict:
    """Écrit les règles envoyées, et LAISSE les autres.

    Sémantique de PATCH, y compris quand la route est un PUT : l'écran de
    confidentialité change une ligne à la fois, et un envoi partiel ne doit
    pas remettre les cinq autres à leur défaut. C'est le genre d'erreur qui
    rouvre en silence ce que quelqu'un avait fermé.
    """
    for champ, aspect in CHAMPS_AUDIENCE.items():
        if champ not in modifications or modifications[champ] is None:
            continue
        setattr(user, aspect.value, PrivacyAudience(modifications[champ]))

    if modifications.get("read_receipts") is not None:
        user.read_receipts_enabled = bool(modifications["read_receipts"])
    if modifications.get("presence_reciprocal") is not None:
        user.presence_visible = bool(modifications["presence_reciprocal"])

    db.commit()
    db.refresh(user)
    return reglages(user)
