"""Paramètres par pays : modules ouverts, monnaie, TVA, prix de la course.

Les valeurs par défaut sont écrites ici ; chacune se surcharge sans
publication par un réglage système `country.<CC>` (JSON partiel), que
l'équipe modifie depuis la console. Chaque module, Kory et HONAM compris,
se règle pays par pays : tous les pays les ont par défaut.

Un pays absent de la table a la même application que les autres : Kory,
Honam et Assimé y sont ouverts par défaut. La console peut fermer un module
dans un pays ; s'ils sont tous fermés, l'app se présente en Lot 1
(Discussions, Statuts, Appels, Réglages).
"""
import json
from typing import Any, Optional

from sqlalchemy.orm import Session

from app.services.settings_service import get_setting
from app.utils.phone import country_for_e164

#: Les modules connus. Un module absent du réglage d'un pays y est fermé.
MODULES = ("discussions", "kory", "kory_plus", "honam", "assime", "certified")

_DEFAULTS: dict[str, dict[str, Any]] = {
    "TG": {
        "currency": "XOF",
        "vat_rate": 0.18,
        "delivery_price": 1000,
        "pharmacy_monthly_price": 5000,
        "pharmacy_yearly_price": 50000,
        #: Surcharge des numéros d'urgence depuis la console. La référence est
        #: le fichier app/data/emergency_numbers.csv (voir
        #: app/services/honam/emergency.py) : vide, c'est lui qui s'applique.
        "emergency_numbers": {},
        #: Villes où Honam livre. Ailleurs, l'offre coursier laisse place à
        #: la liste d'attente (maquette Coursiers 16).
        "honam_cities": ["Lomé"],
        #: Frais d'ouverture d'une tontine Kory Plus, HT, par membre, une fois.
        "kory_plus_fee_ht": 1000,
        "modules": ["discussions", "kory", "kory_plus", "honam", "assime", "certified"],
    },
    "CI": {
        "currency": "XOF",
        "vat_rate": 0.18,
        "delivery_price": 1500,
        "pharmacy_monthly_price": 7500,
        "pharmacy_yearly_price": 75000,
        "emergency_numbers": {},
        "honam_cities": ["Abidjan"],
        "kory_plus_fee_ht": 1000,
        "modules": ["discussions", "kory", "kory_plus", "honam", "assime"],
    },
    # ── PAYS DE TEST ──────────────────────────────────────────────────────
    # La France n'est PAS un pays de lancement : elle sert aux testeurs qui
    # y vivent, pour qu'ils puissent faire tout le parcours Honam (officines
    # de démonstration, coursier, abonnement) avec leur numéro français.
    # À couper depuis la console (Pays → FR : fermer les modules, ou
    # « Pays de test » / « Paiements simulés » décochés) dès la fin des tests.
    #
    # Devise : XOF et non EUR, volontairement — les tarifs restent ceux du
    # Togo et se lisent de la même façon que dans les maquettes.
    "FR": {
        "test_only": True,
        #: Paiements SIMULÉS (aucun appel à Semoa, aucun débit) : l'effet du
        #: paiement est posé tout de suite, et la réponse le signale
        #: (`test_mode`). Jamais pour un pays de lancement : voir
        #: `simulated_payments_enabled`.
        "test_payments": True,
        #: Les trois officines « Démo » créées par le seed sont visibles.
        "honam_demo_pharmacies": True,
        "currency": "XOF",
        "vat_rate": 0.18,
        "delivery_price": 1000,
        "pharmacy_monthly_price": 5000,
        "pharmacy_yearly_price": 50000,
        "emergency_numbers": {},
        "honam_cities": ["Paris", "Lyon", "Marseille", "Toulouse", "Lille", "Bordeaux", "Nantes", "Strasbourg"],
        "kory_plus_fee_ht": 1000,
        "modules": ["discussions", "kory", "kory_plus", "honam", "assime", "certified"],
    },
}

#: Les pays de lancement : jamais de paiement simulé, quoi que dise leur
#: réglage. Un garde-fou écrit dans le code, pas seulement dans la console.
PRODUCTION_COUNTRIES = frozenset({"TG", "CI"})

_FALLBACK: dict[str, Any] = {
    "currency": "XOF",
    "vat_rate": 0.0,
    "delivery_price": None,
    "pharmacy_monthly_price": None,
    "pharmacy_yearly_price": None,
    "emergency_numbers": {},
    "honam_cities": [],
    "kory_plus_fee_ht": 1000,
    #: Pays de test (coupable depuis la console), paiements simulés, et
    #: officines de démonstration visibles : tout est fermé par défaut.
    "test_only": False,
    "test_payments": False,
    "honam_demo_pharmacies": False,
    #: « Découvrir Pokou » (Accueil, sous Assimé) : la vidéo de présentation.
    #: Vide, l'entrée ne s'affiche pas.
    "discover_video_url": None,
    #: La même application partout : Kory, Honam et Assimé sont ouverts par
    #: défaut dans tous les pays. Pokou certifié reste réservé aux pays où
    #: la vérification d'identité est en place.
    "modules": ["discussions", "kory", "kory_plus", "honam", "assime"],
}


def country_config(db: Session, country: Optional[str]) -> dict[str, Any]:
    code = (country or "").upper()
    # Les clés ajoutées après coup (pays de test, vidéo…) existent partout,
    # même pour un pays écrit avant elles.
    config = {**_FALLBACK, **_DEFAULTS.get(code, {})}
    override = get_setting(db, f"country.{code}") if code else None
    if override:
        try:
            patch = json.loads(override)
        except ValueError:
            patch = None
        # Un réglage mal formé ne doit pas fermer les modules d'un pays
        # entier : il est ignoré, et la valeur par défaut reste en vigueur.
        if isinstance(patch, dict):
            config.update(patch)
    configured_modules = config.get("modules", [])
    if not isinstance(configured_modules, list):
        configured_modules = []
    enabled = {
        module
        for module in configured_modules
        if isinstance(module, str) and module in MODULES
    }
    config["modules"] = [module for module in MODULES if module in enabled]
    config["country"] = code or None
    return config


def country_of_phone(phone: Optional[str]) -> Optional[str]:
    return country_for_e164(phone) if phone else None


def module_open(db: Session, phone: Optional[str], module: str) -> bool:
    return module in country_config(db, country_of_phone(phone))["modules"]


def simulated_payments_enabled(db: Session, country: Optional[str]) -> bool:
    """Paiements simulés : seulement dans un pays marqué « de test » ET dont
    les paiements simulés sont ouverts — et jamais au Togo ni en Côte
    d'Ivoire, même si la console le demandait par erreur."""
    code = (country or "").upper()
    if not code or code in PRODUCTION_COUNTRIES:
        return False
    config = country_config(db, code)
    return bool(config.get("test_only")) and bool(config.get("test_payments"))


def demo_pharmacies_visible(db: Session, country: Optional[str]) -> bool:
    """Les officines « Démo » du seed : visibles seulement là où le réglage
    `honam_demo_pharmacies` du pays est ouvert (ouvert par défaut pour le
    pays de test, fermé pour les pays de lancement)."""
    if not country:
        return False
    return bool(country_config(db, country).get("honam_demo_pharmacies"))
