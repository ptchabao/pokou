"""Les officines de DÉMONSTRATION, pour les testeurs de Honam.

Trois officines fictives, « Démo » dans leur nom, créées UNE fois par le
seed (scripts/seed.py, joué à chaque déploiement) :

- une à Lomé (Togo) — invisible tant que le réglage `honam_demo_pharmacies`
  du Togo est fermé, ce qui est le cas par défaut : le Togo est un pays de
  lancement ;
- deux à Paris (France, pays de test), dont une de garde — visibles par
  défaut, puisque la France est marquée pays de test.

Abonnées (ÉPÉ, dix ans), avec du crédit, un wallet « vérifié » mais
fictif : aucun numéro de paiement réel. Les numéros français sont pris dans
la plage que l'ARCEP réserve aux œuvres de fiction (06 39 98 xx xx) ; celui
du Togo n'est pas un numéro valide.

Les retirer :

- les cacher : console → Pays → décocher « Officines de démonstration »
  (réglage `honam_demo_pharmacies` du pays) ;
- les supprimer : `python -m scripts.honam_demo_pharmacies remove`. Le seed
  ne les recrée pas ensuite (le repère `honam_demo_pharmacies_seeded` reste).
"""
from datetime import datetime, timedelta

from sqlalchemy.orm import Session

from app.models import HonamOrder, Pharmacy
from app.services.settings_service import get_setting, set_setting

SEEDED_MARKER = "honam_demo_pharmacies_seeded"

DEMO_PHARMACIES = [
    {
        "country": "TG",
        "name": "Pharmacie Démo du Grand Marché",
        "address": "Rue du Grand Marché, Adawlato, Lomé (officine de démonstration)",
        "phone": "+22800000001",
        "wallet_phone": "+22800000001",
        "opening_hours": "Lun-Sam 8h-21h",
        "latitude": 6.1319,
        "longitude": 1.2228,
        "is_on_duty": False,
    },
    {
        "country": "FR",
        "name": "Pharmacie Démo Bastille",
        "address": "Place de la Bastille, 75011 Paris (officine de démonstration)",
        "phone": "+33639980001",
        "wallet_phone": "+33639980001",
        "opening_hours": "Lun-Dim 8h30-22h · de garde cette nuit",
        "latitude": 48.8532,
        "longitude": 2.3692,
        "is_on_duty": True,
    },
    {
        "country": "FR",
        "name": "Pharmacie Démo Château Rouge",
        "address": "Rue Poulet, 75018 Paris (officine de démonstration)",
        "phone": "+33639980002",
        "wallet_phone": "+33639980002",
        "opening_hours": "Lun-Sam 9h-20h",
        "latitude": 48.8870,
        "longitude": 2.3494,
        "is_on_duty": False,
    },
]

#: Assez de crédit pour ne jamais tomber à court pendant les tests.
DEMO_CREDIT_HT = 1_000_000
DEMO_SUBSCRIPTION_DAYS = 3650


def seed_demo_pharmacies(db: Session) -> int:
    """Crée les officines de démonstration la PREMIÈRE fois seulement.

    Idempotent : le repère posé après la création empêche de les recréer —
    même après leur suppression, qui est un choix de l'équipe. Une officine
    déjà présente (même nom, marquée démo) n'est jamais dupliquée.
    """
    if get_setting(db, SEEDED_MARKER):
        return 0
    existing = {name for (name,) in db.query(Pharmacy.name).filter(Pharmacy.is_demo.is_(True))}
    now = datetime.utcnow()
    added = 0
    for spec in DEMO_PHARMACIES:
        if spec["name"] in existing:
            continue
        db.add(Pharmacy(
            **spec,
            is_demo=True,
            wallet_verified=True,
            subscription_plan="EPE",
            subscription_until=now + timedelta(days=DEMO_SUBSCRIPTION_DAYS),
            credit_balance=DEMO_CREDIT_HT,
            status="ACTIVE",
        ))
        added += 1
    db.flush()
    set_setting(db, SEEDED_MARKER, now.isoformat())
    return added


def remove_demo_pharmacies(db: Session) -> dict:
    """Supprime les officines de démonstration. Une officine qui a déjà reçu
    des commandes de test est EXCLUE (elle disparaît de l'annuaire) plutôt
    que supprimée, pour ne pas laisser de commandes orphelines."""
    removed, excluded = 0, 0
    for pharmacy in db.query(Pharmacy).filter(Pharmacy.is_demo.is_(True)).all():
        if db.query(HonamOrder.id).filter(HonamOrder.pharmacy_id == pharmacy.id).first() is not None:
            pharmacy.status = "EXCLUDED"
            pharmacy.suspension_reason = "Officine de démonstration retirée"
            excluded += 1
        else:
            db.delete(pharmacy)
            removed += 1
    # Le repère reste : le seed ne les recréera pas.
    if not get_setting(db, SEEDED_MARKER):
        set_setting(db, SEEDED_MARKER, datetime.utcnow().isoformat())
    db.commit()
    return {"removed": removed, "excluded": excluded}
