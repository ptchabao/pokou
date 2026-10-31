"""Les catégories et les devises du marché — pilotées depuis l'admin.

Elles étaient écrites en dur dans l'application mobile : une liste Dart de
six catégories, et un champ de texte libre pour la devise. Deux conséquences,
dont la seconde est la plus coûteuse :

- **ajouter une catégorie exigeait une publication Play Store.** Trois jours
  d'attente pour un mot, et la version précédente reste sur les téléphones
  qui ne se mettent pas à jour ;
- **la devise était saisie à la main.** « XOF », « FCFA », « fcfa », « Fcfa »
  et « CFA » désignaient la même chose et ne se comparaient pas. Rien ne
  permettait de totaliser un catalogue, et rien n'empêchait un prix en
  « BTC ».

Le stockage passe par `SystemSetting` plutôt qu'une table dédiée : c'est déjà
le magasin de configuration du produit (passerelles SMS, réglages CEO IA), il
porte la trace de l'admin qui a modifié, et ça évite une migration pour deux
listes d'une dizaine de lignes.

**Les valeurs par défaut sont dans le code, pas seulement en base.** Tant
qu'aucun administrateur n'a rien enregistré — et si la base répond mal — le
marché fonctionne exactement comme avant. Une configuration absente ne doit
jamais vider les filtres d'un écran.
"""
import json
import logging
import re
from typing import Any, Optional

from sqlalchemy.orm import Session

from app.services.settings_service import get_setting, set_setting

logger = logging.getLogger(__name__)

CLE_CATEGORIES = "marketplace_categories"
CLE_DEVISES = "marketplace_currencies"
CLE_FORMULES = "marketplace_verification_plans"

# Les six catégories historiques de `kMarketCategories`, côté Flutter —
# reprises à l'identique pour que la bascule ne change rien tant que
# personne n'a touché à la configuration. « TOUT » n'en fait pas partie :
# c'est le filtre « toutes catégories », que le client ajoute lui-même.
CATEGORIES_PAR_DEFAUT: list[dict[str, Any]] = [
    {"slug": "TELEPHONES", "label": "Téléphones", "active": True},
    {"slug": "MODE", "label": "Mode", "active": True},
    {"slug": "MAISON", "label": "Maison", "active": True},
    {"slug": "SERVICES", "label": "Services", "active": True},
    {"slug": "AUTRE", "label": "Autre", "active": True},
]

DEVISES_PAR_DEFAUT: list[dict[str, Any]] = [
    {"code": "XOF", "label": "FCFA", "active": True, "default": True},
]

# Tarifs vendeur alignés sur ceux des chaînes. Les montants sont décidés et
# validés côté serveur ; l'application n'envoie que le code de formule.
FORMULES_PAR_DEFAUT: list[dict[str, Any]] = [
    {
        "code": "MONTHLY",
        "label": "Mensuel",
        "description": "Certification vendeur pendant 30 jours.",
        "amount": 3000,
        "duration_days": 30,
        "active": True,
        "default": False,
    },
    {
        "code": "ANNUAL",
        "label": "Annuel",
        "description": "Certification vendeur pendant 365 jours.",
        "amount": 30000,
        "duration_days": 365,
        "active": True,
        "default": True,
    },
]

_SLUG = re.compile(r"^[A-Z][A-Z0-9_]{0,63}$")
_CODE = re.compile(r"^[A-Z]{3,8}$")


class ConfigurationInvalide(ValueError):
    """Le contenu proposé rendrait le marché inutilisable."""


# ── Lecture ───────────────────────────────────────────────────────────────


def _charger(db: Session, cle: str, defaut: list[dict[str, Any]]) -> list[dict[str, Any]]:
    brut = get_setting(db, cle)
    if not brut:
        return [dict(e) for e in defaut]
    try:
        valeur = json.loads(brut)
    except (TypeError, ValueError):
        # Une configuration illisible ne doit pas casser le marché : on
        # journalise et on retombe sur le défaut, plutôt que de renvoyer une
        # liste vide qui viderait les filtres de tous les téléphones.
        logger.warning("[MarketplaceConfig] %s illisible — retour au défaut", cle)
        return [dict(e) for e in defaut]
    if not isinstance(valeur, list) or not valeur:
        return [dict(e) for e in defaut]
    return valeur


def categories(db: Session, *, actives_seulement: bool = True) -> list[dict[str, Any]]:
    liste = _charger(db, CLE_CATEGORIES, CATEGORIES_PAR_DEFAUT)
    if actives_seulement:
        liste = [c for c in liste if c.get("active", True)]
    return liste


def devises(db: Session, *, actives_seulement: bool = True) -> list[dict[str, Any]]:
    liste = _charger(db, CLE_DEVISES, DEVISES_PAR_DEFAUT)
    if actives_seulement:
        liste = [d for d in liste if d.get("active", True)]
    return liste


def formules_verification(db: Session, *, actives_seulement: bool = True) -> list[dict[str, Any]]:
    """Les formules proposées pour faire vérifier son compte.

    Même logique que les devises : le CLIENT n'envoie qu'un code, jamais un
    montant. C'est la leçon des campagnes publicitaires, où le prix arrivait
    de la requête et où n'importe qui pouvait donc s'offrir une semaine de
    diffusion au dixième du tarif.
    """
    liste = _charger(db, CLE_FORMULES, FORMULES_PAR_DEFAUT)
    normalisees = []
    for formule in liste:
        item = dict(formule)
        if "duration_days" not in item:
            item["duration_days"] = 30 if item.get("code") == "MONTHLY" else 365
        normalisees.append(item)
    if actives_seulement:
        normalisees = [f for f in normalisees if f.get("active", True)]
    return normalisees


def formule_verification(db: Session, code: Optional[str]) -> dict[str, Any]:
    """La formule demandée, ou celle par défaut. Lève si le code est inconnu."""
    actives = formules_verification(db)
    if not actives:
        return dict(FORMULES_PAR_DEFAUT[0])
    if code:
        for f in actives:
            if f["code"] == code.upper():
                return f
        raise ConfigurationInvalide(f"Formule inconnue : {code}")
    for f in actives:
        if f.get("default"):
            return f
    return actives[0]


def devise_par_defaut(db: Session) -> str:
    actives = devises(db)
    for d in actives:
        if d.get("default"):
            return d["code"]
    return actives[0]["code"] if actives else "XOF"


def devise_connue(db: Session, code: str) -> bool:
    return any(d["code"] == code for d in devises(db))


def configuration_publique(db: Session) -> dict[str, Any]:
    """Ce que l'application mobile lit au démarrage du marché."""
    return {
        "categories": [
            {"slug": c["slug"], "label": c.get("label") or c["slug"]}
            for c in categories(db)
        ],
        "currencies": [
            {
                "code": d["code"],
                "label": d.get("label") or d["code"],
                "default": bool(d.get("default")),
            }
            for d in devises(db)
        ],
        "verification_plans": [
            {
                "code": f["code"],
                "label": f.get("label") or f["code"],
                "description": f.get("description") or "",
                "amount": int(f.get("amount") or 0),
                "duration_days": int(f.get("duration_days") or 365),
                "default": bool(f.get("default")),
            }
            for f in formules_verification(db)
        ],
    }


# ── Écriture ──────────────────────────────────────────────────────────────


def _texte(valeur: Any, champ: str, maxi: int) -> str:
    if not isinstance(valeur, str) or not valeur.strip():
        raise ConfigurationInvalide(f"« {champ} » est obligatoire")
    texte = valeur.strip()
    if len(texte) > maxi:
        raise ConfigurationInvalide(f"« {champ} » dépasse {maxi} caractères")
    return texte


def valider_categories(entrees: list[dict[str, Any]]) -> list[dict[str, Any]]:
    propre: list[dict[str, Any]] = []
    vus: set[str] = set()
    for entree in entrees:
        slug = _texte(entree.get("slug"), "slug", 64).upper()
        if not _SLUG.match(slug):
            raise ConfigurationInvalide(
                f"« {slug} » n'est pas un identifiant valide — lettres majuscules,"
                " chiffres et tirets bas uniquement"
            )
        if slug == "TOUT":
            # `TOUT` est le filtre « toutes catégories » côté client. En
            # faire une vraie catégorie donnerait deux entrées identiques
            # dans la barre de filtres, dont une qui ne trouve rien.
            raise ConfigurationInvalide("« TOUT » est réservé au filtre « toutes catégories »")
        if slug in vus:
            raise ConfigurationInvalide(f"« {slug} » apparaît deux fois")
        vus.add(slug)
        propre.append(
            {
                "slug": slug,
                "label": _texte(entree.get("label") or slug, "label", 64),
                "active": bool(entree.get("active", True)),
            }
        )
    if not any(c["active"] for c in propre):
        # Sans catégorie active, la barre de filtres du marché est vide et
        # le formulaire d'annonce n'a plus rien à proposer.
        raise ConfigurationInvalide("Au moins une catégorie doit rester active")
    return propre


def valider_devises(entrees: list[dict[str, Any]]) -> list[dict[str, Any]]:
    propre: list[dict[str, Any]] = []
    vus: set[str] = set()
    for entree in entrees:
        code = _texte(entree.get("code"), "code", 8).upper()
        if not _CODE.match(code):
            raise ConfigurationInvalide(
                f"« {code} » n'est pas un code de devise valide — 3 à 8 lettres majuscules"
            )
        if code in vus:
            raise ConfigurationInvalide(f"« {code} » apparaît deux fois")
        vus.add(code)
        propre.append(
            {
                "code": code,
                "label": _texte(entree.get("label") or code, "label", 16),
                "active": bool(entree.get("active", True)),
                "default": bool(entree.get("default")),
            }
        )
    actives = [d for d in propre if d["active"]]
    if not actives:
        raise ConfigurationInvalide("Au moins une devise doit rester active")
    defauts = [d for d in actives if d["default"]]
    if len(defauts) > 1:
        raise ConfigurationInvalide("Une seule devise peut être celle par défaut")
    if not defauts:
        # Plutôt que de refuser : le formulaire d'annonce doit toujours
        # pouvoir pré-remplir une devise. La première active fait l'affaire.
        actives[0]["default"] = True
    for d in propre:
        if not d["active"]:
            d["default"] = False
    return propre


def valider_formules(entrees: list[dict[str, Any]]) -> list[dict[str, Any]]:
    propre: list[dict[str, Any]] = []
    vus: set[str] = set()
    for entree in entrees:
        code = _texte(entree.get("code"), "code", 32).upper()
        if not re.match(r"^[A-Z][A-Z0-9_]{0,31}$", code):
            raise ConfigurationInvalide(
                f"« {code} » n'est pas un identifiant de formule valide"
            )
        if code in vus:
            raise ConfigurationInvalide(f"« {code} » apparaît deux fois")
        vus.add(code)
        montant = entree.get("amount")
        if not isinstance(montant, int) or isinstance(montant, bool) or montant < 0:
            raise ConfigurationInvalide(
                f"Le montant de « {code} » doit être un entier positif"
            )
        jours = entree.get("duration_days", 30 if code == "MONTHLY" else 365)
        if not isinstance(jours, int) or isinstance(jours, bool) or jours < 1:
            raise ConfigurationInvalide(
                f"La durée de « {code} » doit être un nombre de jours positif"
            )
        propre.append(
            {
                "code": code,
                "label": _texte(entree.get("label") or code, "label", 64),
                "description": (entree.get("description") or "").strip()[:200],
                "amount": montant,
                "duration_days": jours,
                "active": bool(entree.get("active", True)),
                "default": bool(entree.get("default")),
            }
        )
    actives = [f for f in propre if f["active"]]
    if not actives:
        raise ConfigurationInvalide("Au moins une formule doit rester active")
    defauts = [f for f in actives if f["default"]]
    if len(defauts) > 1:
        raise ConfigurationInvalide("Une seule formule peut être celle par défaut")
    if not defauts:
        actives[0]["default"] = True
    for f in propre:
        if not f["active"]:
            f["default"] = False
    return propre


def enregistrer_formules(
    db: Session, entrees: list[dict[str, Any]], admin_id: Optional[int] = None
) -> list[dict[str, Any]]:
    propre = valider_formules(entrees)
    set_setting(db, CLE_FORMULES, json.dumps(propre, ensure_ascii=False), admin_id)
    return propre


def enregistrer_categories(
    db: Session, entrees: list[dict[str, Any]], admin_id: Optional[int] = None
) -> list[dict[str, Any]]:
    propre = valider_categories(entrees)
    set_setting(db, CLE_CATEGORIES, json.dumps(propre, ensure_ascii=False), admin_id)
    return propre


def enregistrer_devises(
    db: Session, entrees: list[dict[str, Any]], admin_id: Optional[int] = None
) -> list[dict[str, Any]]:
    propre = valider_devises(entrees)
    set_setting(db, CLE_DEVISES, json.dumps(propre, ensure_ascii=False), admin_id)
    return propre
