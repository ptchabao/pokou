"""Paramètres par pays : modules ouverts, monnaie, TVA, prix de la course.

Les valeurs par défaut sont écrites ici ; chacune se surcharge sans
publication par un réglage système `country.<CC>` (JSON partiel), que
l'équipe modifie depuis la base. C'est ce qui permet d'ouvrir HONAM à Lomé
au mois 4 sans attendre une revue de store (NAV-01).

Un pays absent de la table n'a aucun module de service : la messagerie
reste disponible partout, Kory et HONAM ne le sont que là où Pokou est lancé.
"""
import json
from typing import Any, Optional

from sqlalchemy.orm import Session

from app.services.settings_service import get_setting
from app.utils.phone import country_for_e164

#: Les modules connus. Un module qui n'est pas listé dans `modules` est
#: fermé, et son onglet n'apparaît pas.
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
        "modules": ["discussions", "kory", "certified"],
    },
    "CI": {
        "currency": "XOF",
        "vat_rate": 0.18,
        "delivery_price": 1500,
        "pharmacy_monthly_price": 7500,
        "pharmacy_yearly_price": 75000,
        "emergency_numbers": {"police": "110", "pompiers": "180", "samu": "185"},
        "honam_cities": ["Abidjan"],
        # Lancement au mois 13 : la Côte d'Ivoire n'ouvre que la messagerie
        # tant que l'équipe ne surcharge pas ce réglage.
        "modules": ["discussions"],
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
    config["modules"] = [m for m in config.get("modules", []) if m in MODULES]
    config["country"] = code or None
    return config


def country_of_phone(phone: Optional[str]) -> Optional[str]:
    return country_for_e164(phone) if phone else None


def module_open(db: Session, phone: Optional[str], module: str) -> bool:
    return module in country_config(db, country_of_phone(phone))["modules"]
