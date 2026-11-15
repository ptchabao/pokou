"""Paramètres par pays : modules ouverts, monnaie, TVA, prix de la course.

Les valeurs par défaut sont écrites ici ; chacune se surcharge sans
publication par un réglage système `country.<CC>` (JSON partiel), que
l'équipe modifie depuis la console. Chaque module, Kory et HONAM compris,
s'ouvre pays par pays : le Togo et la Côte d'Ivoire les ont par défaut.

Un pays absent de la table n'a que la messagerie (le Lot 1 de la maquette :
Discussions, Statuts, Appels, Réglages). Les modules rejoignent l'app quand
la console les ouvre dans ce pays.
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
        "emergency_numbers": {"police": "117", "pompiers": "118", "samu": "8200"},
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
        "emergency_numbers": {"police": "110", "pompiers": "180", "samu": "185"},
        "honam_cities": ["Abidjan"],
        "kory_plus_fee_ht": 1000,
        "modules": ["discussions", "kory", "kory_plus", "honam", "assime"],
    },
}

_FALLBACK: dict[str, Any] = {
    "currency": "XOF",
    "vat_rate": 0.0,
    "delivery_price": None,
    "pharmacy_monthly_price": None,
    "pharmacy_yearly_price": None,
    "emergency_numbers": {},
    "honam_cities": [],
    "kory_plus_fee_ht": 1000,
    #: Messagerie seule (Lot 1). Pokou certifié reste réservé aux pays où
    #: la vérification d'identité est en place.
    "modules": ["discussions"],
}


def country_config(db: Session, country: Optional[str]) -> dict[str, Any]:
    code = (country or "").upper()
    config = dict(_DEFAULTS.get(code, _FALLBACK))
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
