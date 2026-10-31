"""Les tarifs de Pokou Business, réglés depuis l'admin (SystemSetting).

Deux prix, selon la fenêtre de 24 h (modèle WhatsApp Business) :

- `service_price` : le bot RÉPOND à quelqu'un qui lui a écrit dans les
  24 dernières heures — la conversation vient de l'utilisateur ;
- `initiated_price` : le bot écrit en premier, hors de cette fenêtre — il
  sollicite, ce qui coûte plus cher et décourage le démarchage en masse.

Les valeurs par défaut sont des points de départ, pas une décision
commerciale : elles se règlent depuis l'admin, sans redéploiement.
"""
import json
import logging
from typing import Any, Optional

from sqlalchemy.orm import Session

from app.services.settings_service import get_setting, set_setting

logger = logging.getLogger(__name__)

CLE_TARIFS = "pokou_business_pricing"

TARIFS_PAR_DEFAUT: dict[str, int] = {
    "service_price": 5,
    "initiated_price": 25,
    # Taxe en points de base (1800 = 18 %). Zéro par défaut : le taux
    # applicable se décide avec le comptable, pas dans le code.
    "tax_rate_bp": 0,
    "min_recharge": 1000,
    "max_recharge": 5_000_000,
}


class TarifsInvalides(ValueError):
    pass


def tarifs(db: Session) -> dict[str, int]:
    brut = get_setting(db, CLE_TARIFS)
    valeurs = dict(TARIFS_PAR_DEFAUT)
    if not brut:
        return valeurs
    try:
        lus = json.loads(brut)
    except (TypeError, ValueError):
        logger.warning("[PokouBusiness] tarifs illisibles — retour au défaut")
        return valeurs
    if isinstance(lus, dict):
        for cle in TARIFS_PAR_DEFAUT:
            if isinstance(lus.get(cle), int) and lus[cle] >= 0:
                valeurs[cle] = lus[cle]
    return valeurs


def enregistrer(db: Session, entrees: dict[str, Any], admin_id: Optional[int] = None) -> dict[str, int]:
    propre = tarifs(db)
    for cle, valeur in entrees.items():
        if cle not in TARIFS_PAR_DEFAUT:
            raise TarifsInvalides(f"Champ inconnu : {cle}")
        if not isinstance(valeur, int) or isinstance(valeur, bool) or valeur < 0:
            raise TarifsInvalides(f"{cle} doit être un entier positif (FCFA)")
        propre[cle] = valeur
    if propre["tax_rate_bp"] > 5000:
        raise TarifsInvalides("Taux de taxe invraisemblable (au-delà de 50 %)")
    if propre["min_recharge"] > propre["max_recharge"]:
        raise TarifsInvalides("La recharge minimale dépasse la maximale")
    set_setting(db, CLE_TARIFS, json.dumps(propre), admin_id)
    return propre
