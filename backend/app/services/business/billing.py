"""La facturation des bots : fenêtre de 24 h, débit, factures, impayés.

Deux modes par entreprise :

- **prépayé** (par défaut) : un solde rechargé en Mobile Money, débité à
  chaque message. À zéro, l'envoi est refusé — jamais de dette ;
- **postpayé** (ouvert par l'équipe) : la consommation s'accumule jusqu'à
  un plafond, puis une facture mensuelle part avec une échéance. Passé
  l'échéance, l'entreprise est suspendue jusqu'au paiement.

Rien ici ne fait `db.commit()` : l'appelant tient la transaction, si bien
qu'un message qui échoue après le débit est annulé AVEC son débit.
"""
from __future__ import annotations

from dataclasses import dataclass
from datetime import datetime, timedelta
from typing import Optional

from sqlalchemy import func
from sqlalchemy.orm import Session

from app.models import DirectMessage
from app.models.business import Bot, BotUsage, Invoice, LedgerEntry, BusinessOrganization
from app.services.business import pricing

SERVICE_WINDOW = timedelta(hours=24)


class CreditInsuffisant(Exception):
    """Solde prépayé épuisé, ou plafond postpayé atteint — HTTP 402."""


@dataclass
class Facturation:
    category: str
    unit_price: int
    usage: BotUsage


def categorie(db: Session, bot: Bot, recipient_id: int, now: Optional[datetime] = None) -> str:
    """SERVICE si le destinataire a écrit au bot dans les 24 dernières
    heures, INITIATED sinon. C'est le message de l'UTILISATEUR qui ouvre la
    fenêtre — un bot qui s'écrit des relances ne la rouvre pas."""
    now = now or datetime.utcnow()
    dernier = (
        db.query(func.max(DirectMessage.created_at))
        .filter(
            DirectMessage.sender_id == recipient_id,
            DirectMessage.recipient_id == bot.user_id,
        )
        .scalar()
    )
    if dernier is not None and now - dernier <= SERVICE_WINDOW:
        return "SERVICE"
    return "INITIATED"


def encours_postpaye(db: Session, org: BusinessOrganization) -> int:
    """Ce que l'entreprise doit en postpayé : la consommation pas encore
    facturée, plus les factures émises et non réglées."""
    non_facture = (
        db.query(func.coalesce(func.sum(BotUsage.unit_price), 0))
        .filter(
            BotUsage.organization_id == org.id,
            BotUsage.mode == "LIVE",
            BotUsage.billing_mode == "POSTPAID",
            BotUsage.invoice_id.is_(None),
        )
        .scalar()
    )
    impaye = (
        db.query(func.coalesce(func.sum(Invoice.total), 0))
        .filter(Invoice.organization_id == org.id, Invoice.status.in_(["ISSUED", "OVERDUE"]))
        .scalar()
    )
    return int(non_facture or 0) + int(impaye or 0)


def _ecrire(db: Session, org: BusinessOrganization, kind: str, amount: int, reference: str, by: Optional[int] = None) -> LedgerEntry:
    db.flush()
    db.refresh(org)
    entry = LedgerEntry(
        organization_id=org.id,
        kind=kind,
        amount=amount,
        balance_after=org.credit_balance,
        reference=reference,
        created_by_id=by,
    )
    db.add(entry)
    return entry


def facturer_message(
    db: Session,
    *,
    org: BusinessOrganization,
    bot: Bot,
    recipient_id: int,
    mode: str,
    now: Optional[datetime] = None,
) -> Facturation:
    """Compte un message et le fait payer — AVANT qu'il ne parte.

    Le débit prépayé est une seule instruction conditionnelle
    (`… WHERE credit_balance >= prix`) : deux envois simultanés ne peuvent
    pas dépenser deux fois le même dernier franc, ce qu'un « lire, puis
    écrire » laisserait faire.
    """
    now = now or datetime.utcnow()
    cat = categorie(db, bot, recipient_id, now)
    if mode == "TEST":
        # Le bac à sable ne coûte rien : il sert à développer, et facturer
        # les essais pousserait à tester directement en production.
        prix = 0
    else:
        tarif = pricing.tarifs(db)
        prix = tarif["service_price"] if cat == "SERVICE" else tarif["initiated_price"]

    if mode == "LIVE" and prix > 0:
        if org.billing_mode == "POSTPAID":
            if encours_postpaye(db, org) + prix > org.postpaid_limit:
                raise CreditInsuffisant("Plafond de consommation atteint — réglez vos factures ou contactez Pokou")
        else:
            debite = (
                db.query(BusinessOrganization)
                .filter(BusinessOrganization.id == org.id, BusinessOrganization.credit_balance >= prix)
                .update(
                    {BusinessOrganization.credit_balance: BusinessOrganization.credit_balance - prix},
                    synchronize_session=False,
                )
            )
            if not debite:
                raise CreditInsuffisant("Solde insuffisant — rechargez votre crédit Pokou Business")
            _ecrire(db, org, "DEBIT", -prix, f"bot:{bot.id}")

    usage = BotUsage(
        organization_id=org.id,
        bot_id=bot.id,
        recipient_id=recipient_id,
        mode=mode,
        category=cat,
        unit_price=prix,
        billing_mode=org.billing_mode,
        created_at=now,
    )
    db.add(usage)
    db.flush()
    return Facturation(category=cat, unit_price=prix, usage=usage)


def crediter(db: Session, org: BusinessOrganization, montant: int, *, reference: str, by: Optional[int] = None, kind: str = "RECHARGE") -> LedgerEntry:
    db.query(BusinessOrganization).filter(BusinessOrganization.id == org.id).update(
        {BusinessOrganization.credit_balance: BusinessOrganization.credit_balance + montant},
        synchronize_session=False,
    )
    return _ecrire(db, org, kind, montant, reference, by)


# ── Factures ──────────────────────────────────────────────────────────────


def prochain_numero(db: Session, annee: int) -> str:
    prefixe = f"VB-{annee}-"
    dernier = (
        db.query(func.max(Invoice.number)).filter(Invoice.number.like(f"{prefixe}%")).scalar()
    )
    suivant = int(dernier[len(prefixe):]) + 1 if dernier else 1
    return f"{prefixe}{suivant:06d}"


def _totaux(db: Session, lignes: list[dict]) -> tuple[int, int, int, int]:
    taux = pricing.tarifs(db)["tax_rate_bp"]
    sous_total = sum(int(ligne["amount"]) for ligne in lignes)
    taxe = (sous_total * taux + 5000) // 10000
    return sous_total, taux, taxe, sous_total + taxe


def facture_de_recharge(db: Session, org: BusinessOrganization, montant: int, payment_id: int, now: Optional[datetime] = None) -> Invoice:
    """Une recharge prépayée : facture émise PAYÉE, pour la comptabilité
    de l'entreprise. Le montant facturé est le montant encaissé, taxe
    comprise — la taxe est donc extraite, pas ajoutée."""
    now = now or datetime.utcnow()
    taux = pricing.tarifs(db)["tax_rate_bp"]
    hors_taxe = (montant * 10000 + (10000 + taux) // 2) // (10000 + taux)
    facture = Invoice(
        organization_id=org.id,
        number=prochain_numero(db, now.year),
        kind="RECHARGE",
        status="PAID",
        lines=[{"label": "Recharge de crédit Pokou Business", "quantity": 1, "unit_price": hors_taxe, "amount": hors_taxe}],
        subtotal=hors_taxe,
        tax_rate_bp=taux,
        tax_amount=montant - hors_taxe,
        total=montant,
        issued_at=now,
        paid_at=now,
        payment_id=payment_id,
    )
    db.add(facture)
    db.flush()
    return facture


LIBELLES = {
    "SERVICE": "Messages de service (réponse sous 24 h)",
    "INITIATED": "Messages initiés par l'entreprise",
}


def facturer_mois(db: Session, org: BusinessOrganization, debut_mois_courant: datetime, now: Optional[datetime] = None) -> Optional[Invoice]:
    """Le relevé postpayé de tout ce qui précède `debut_mois_courant` et
    n'a pas encore été facturé. Idempotent : relancé, il ne trouve plus
    rien à facturer."""
    now = now or datetime.utcnow()
    lignes_usage = (
        db.query(BotUsage)
        .filter(
            BotUsage.organization_id == org.id,
            BotUsage.mode == "LIVE",
            BotUsage.billing_mode == "POSTPAID",
            BotUsage.invoice_id.is_(None),
            BotUsage.created_at < debut_mois_courant,
        )
        .all()
    )
    if not lignes_usage:
        return None
    par_categorie: dict[tuple[str, int], int] = {}
    for u in lignes_usage:
        cle = (u.category, u.unit_price)
        par_categorie[cle] = par_categorie.get(cle, 0) + 1
    lignes = [
        {
            "label": LIBELLES.get(cat, cat),
            "quantity": n,
            "unit_price": prix,
            "amount": n * prix,
        }
        for (cat, prix), n in sorted(par_categorie.items())
    ]
    sous_total, taux, taxe, total = _totaux(db, lignes)
    debut = min(u.created_at for u in lignes_usage)
    facture = Invoice(
        organization_id=org.id,
        number=prochain_numero(db, now.year),
        kind="MONTHLY",
        status="ISSUED" if total > 0 else "PAID",
        period_start=debut,
        period_end=debut_mois_courant,
        lines=lignes,
        subtotal=sous_total,
        tax_rate_bp=taux,
        tax_amount=taxe,
        total=total,
        issued_at=now,
        due_at=now + timedelta(days=org.payment_terms_days),
        paid_at=now if total == 0 else None,
    )
    db.add(facture)
    db.flush()
    for u in lignes_usage:
        u.invoice_id = facture.id
    return facture


def debut_du_mois(moment: datetime) -> datetime:
    return moment.replace(day=1, hour=0, minute=0, second=0, microsecond=0)


def cycle_mensuel(db: Session, now: Optional[datetime] = None) -> dict[str, int]:
    """Émet les relevés postpayés et suspend les impayés. Appelé par le
    planificateur ; sans effet s'il n'y a rien à faire."""
    now = now or datetime.utcnow()
    debut = debut_du_mois(now)
    emises = 0
    orgs_ids = {
        row[0]
        for row in db.query(BotUsage.organization_id)
        .filter(
            BotUsage.billing_mode == "POSTPAID",
            BotUsage.mode == "LIVE",
            BotUsage.invoice_id.is_(None),
            BotUsage.created_at < debut,
        )
        .distinct()
        .all()
    }
    for org in db.query(BusinessOrganization).filter(BusinessOrganization.id.in_(orgs_ids or {0})).all():
        if facturer_mois(db, org, debut, now) is not None:
            emises += 1

    suspendues = 0
    echues = (
        db.query(Invoice)
        .filter(Invoice.status == "ISSUED", Invoice.due_at.isnot(None), Invoice.due_at < now)
        .all()
    )
    for facture in echues:
        facture.status = "OVERDUE"
        org = db.query(BusinessOrganization).filter(BusinessOrganization.id == facture.organization_id).first()
        if org and org.status != "SUSPENDED":
            org.status = "SUSPENDED"
            org.suspended_reason = f"Facture {facture.number} impayée à l'échéance"
            suspendues += 1
    return {"invoices_issued": emises, "organizations_suspended": suspendues}


def regler_facture(db: Session, facture: Invoice, payment_id: int, now: Optional[datetime] = None) -> None:
    """Une facture payée — et, si c'était la dernière en retard, la fin de
    la suspension qu'elle avait causée (et seulement celle-là : une
    suspension décidée par l'équipe pour abus ne se lève pas en payant)."""
    now = now or datetime.utcnow()
    facture.status = "PAID"
    facture.paid_at = now
    facture.payment_id = payment_id
    db.flush()
    org = db.query(BusinessOrganization).filter(BusinessOrganization.id == facture.organization_id).first()
    if org is None or org.status != "SUSPENDED":
        return
    if not (org.suspended_reason or "").startswith("Facture "):
        return
    encore = (
        db.query(Invoice.id)
        .filter(Invoice.organization_id == org.id, Invoice.status == "OVERDUE")
        .first()
    )
    if encore is None:
        org.status = "VERIFIED" if org.verified_at else "SANDBOX"
        org.suspended_reason = None
