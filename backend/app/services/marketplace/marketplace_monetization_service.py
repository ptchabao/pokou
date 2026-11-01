"""Paiements et activation des fonctionnalités payantes de la Marketplace."""
import logging
from datetime import datetime, timedelta
from typing import Any

from sqlalchemy.orm import Session

from app.models import ChannelCertificationApplication, MarketplaceAd, MarketplaceBoost, MarketplacePayment, MarketplaceProduct, SellerVerificationApplication, User
from app.services.payments import semoa_client

logger = logging.getLogger(__name__)

#: Mise en avant d'une annonce Assimé (maquettes Assimé 10 et 14 à 17) :
#: montants ronds TTC, sans renouvellement automatique. 3 jours = en tête
#: des résultats ; 7 jours = résultats et une place dans la bande des statuts.
PRODUCT_BOOST_OPTIONS = {3: 600, 7: 1300}
#: Au plus deux annonces sponsorisées par écran de résultats.
SPONSORED_PER_PAGE = 2
#: Les médicaments ne se vendent pas sur Assimé : ils renvoient vers Honam.
MEDICINE_CATEGORIES = {"MEDICAMENTS", "MEDICAMENT", "PHARMACIE"}
#: Hypothèse (ASM-05, partie du cahier non reçue) : catégories qui ne se
#: mettent jamais en avant.
BOOST_FORBIDDEN_CATEGORIES = MEDICINE_CATEGORIES | {"ARMES", "TABAC", "ALCOOL"}
STATUS_BOOST_AMOUNT = 1000
VERIFICATION_AMOUNT = 5000

#: Certification d'une chaîne — un ABONNEMENT, pas un achat définitif.
#:
#: L'annuel vaut dix mois : deux offerts, assez pour qu'il soit le choix
#: évident sans que le mensuel devienne une punition. Un badge est un
#: engagement continu de l'équipe qui le délivre — il se renouvelle, donc il
#: se paie de même.
CHANNEL_CERTIFICATION_MONTHLY_AMOUNT = 3000
CHANNEL_CERTIFICATION_ANNUAL_AMOUNT = 30000

#: Ce que chaque formule accorde, en jours.
CHANNEL_CERTIFICATION_PLANS = {
    "MONTHLY": (CHANNEL_CERTIFICATION_MONTHLY_AMOUNT, 30),
    "ANNUAL": (CHANNEL_CERTIFICATION_ANNUAL_AMOUNT, 365),
}


def channel_certification_terms(plan: str) -> tuple[int, int]:
    """Le montant et la durée d'une formule, décidés ICI.

    Jamais reçus du client : c'est la leçon d'`ad_amount_for`, où le montant
    arrivait de la requête et où n'importe qui pouvait donc s'offrir une
    campagne au dixième du tarif sans que rien ne le signale.
    """
    try:
        return CHANNEL_CERTIFICATION_PLANS[plan]
    except KeyError:
        raise ValueError(f"Formule inconnue : {plan}") from None

#: Publicité : 10 000 FCFA la semaine. Le tarif est calculé à partir de cette
#: base, jamais reçu du client — voir AD_WEEKLY_AMOUNT dans marketplace.py.
AD_WEEKLY_AMOUNT = 10000


def ad_amount_for(duration_days: int) -> int:
    """Le prix d'une campagne, décidé ICI et par personne d'autre.

    Le montant arrivait du CLIENT (`AdCreate.amount`, borné à 1 000 FCFA au
    minimum). N'importe qui pouvait donc publier une campagne à un dixième du
    tarif en changeant un champ de la requête — et rien ne l'aurait signalé :
    le paiement aboutit, la campagne s'affiche, seul le montant encaissé est
    faux. Un tarif ne se demande pas au payeur.

    Proportionnel à la durée, arrondi à la semaine entamée : une campagne de
    huit jours coûte deux semaines. Découper en tranches plus fines
    inviterait à optimiser la durée plutôt qu'à réfléchir à la campagne.
    """
    weeks = max(1, -(-duration_days // 7))  # division entière par excès
    return AD_WEEKLY_AMOUNT * weeks


def create_payment(
    db: Session,
    user: User,
    *,
    kind: str,
    amount: int,
    description: str,
    metadata: dict[str, Any],
) -> MarketplacePayment:
    """Crée une intention de paiement et son checkout Semoa.

    Rien n'est activé ici: seule la confirmation signée du webhook le peut.
    """
    if not user.phone:
        raise ValueError("Un numéro de téléphone est nécessaire pour Mobile Money")
    payment = MarketplacePayment(
        user_id=user.id,
        kind=kind,
        amount=amount,
        currency="XOF",
        metadata_json=metadata,
        status="PENDING",
    )
    db.add(payment)
    db.flush()
    try:
        body = semoa_client.create_order(
            db,
            amount=amount,
            description=description,
            merchant_reference=f"marketplace-payment-{payment.id}",
            client_phone=user.phone,
            client_firstname=user.full_name or user.phone,
            client_lastname=user.full_name or user.phone,
            callback_url=semoa_client.build_callback_url(db, "marketplace-payment"),
        )
        payment.provider_reference = body.get("order_reference") or f"marketplace-payment-{payment.id}"
        payment.payment_url = body.get("payment_url")
    except Exception:
        logger.exception("Échec de l'initiation du paiement Marketplace %s", payment.id)
        payment.status = "FAILED"
    db.commit()
    db.refresh(payment)
    return payment


#: Un paiement de module et le fichier qui sait quoi en faire.
#:
#: Les imports sont LOCAUX à l'appel : chacun de ces modules importe
#: `create_payment` depuis ce service, et un import en tête de fichier
#: créerait un cycle.
_MODULE_PAYMENT_KINDS = {
    "LEAGUE_PROTECTION": "app.api.v1.modules.heart_league",
    "LEAGUE_PASS": "app.api.v1.modules.heart_league",
    "STREAK_RESTORE": "app.api.v1.modules.streak_lock",
    "TRUTH_QUESTION": "app.api.v1.modules.truth_market",
    "CEREMONY_CONTRIBUTION": "app.api.v1.modules.social_tax",
    "VIP_SUBSCRIPTION": "app.api.v1.modules.vip_room",
    "HYPE_CONTRIBUTION": "app.api.v1.modules.hype_train",
    "SPARK_LIKES": "app.api.v1.spark.spark",
    "CERTIFIED_SUBSCRIPTION": "app.api.v1.certified.certified",
    "HONAM_PHARMACY_SUB": "app.api.v1.honam.honam",
    "HONAM_CREDIT": "app.api.v1.honam.honam",
    "HONAM_COURIER_MEMBERSHIP": "app.api.v1.honam.honam",
    "HONAM_COURIER_PACK": "app.api.v1.honam.honam",
    "SPARK_PLUS": "app.api.v1.spark.spark",
    "SPARK_LIKERS": "app.api.v1.spark.spark",
    "SPARK_BOOST": "app.api.v1.spark.spark",
    "SPARK_SUPER": "app.api.v1.spark.spark",
    "SPARK_EXTEND": "app.api.v1.spark.spark",
    #: Le seul paiement Spark qui ouvre une séquestre, et donc le seul traité
    #: dans `spark_dates` : l'argent d'un rendez-vous ne devient pas un droit,
    #: il devient une somme bloquée.
    "SPARK_DATE": "app.api.v1.spark.spark_dates",
    # Pokou Business : la recharge du solde prépayé d'une entreprise, et le
    # règlement d'une facture postpayée.
    "BOT_CREDIT": "app.api.v1.business.business",
    "BOT_INVOICE": "app.api.v1.business.business",
}


def _apply_module_payment(db: Session, payment: MarketplacePayment) -> dict[str, Any] | None:
    import importlib

    module = importlib.import_module(_MODULE_PAYMENT_KINDS[payment.kind])
    return module.apply_confirmed_payment(db, payment)


def attach_payer_name(db: Session, provider_reference: str, payer_name: str) -> None:
    """Retient le nom du titulaire du wallet AVANT la confirmation, pour que
    l'effet du paiement (Pokou certifié) puisse le comparer."""
    payment = (
        db.query(MarketplacePayment)
        .filter(MarketplacePayment.provider_reference == provider_reference)
        .first()
    )
    if payment is None or payment.status != "PENDING":
        return
    payment.metadata_json = {**(payment.metadata_json or {}), "payer_name": payer_name}
    db.flush()


def confirm_payment(db: Session, provider_reference: str) -> dict[str, Any]:
    payment = (
        db.query(MarketplacePayment)
        .filter(MarketplacePayment.provider_reference == provider_reference)
        .first()
    )
    if not payment:
        raise ValueError("Paiement Marketplace introuvable")
    # Un paiement n'a d'effet qu'UNE fois. Sans ce verrou, une passerelle
    # Mobile Money qui rappelle son webhook — ce qu'elles font toutes en cas
    # de doute — accorderait deux semaines de protection pour une payée.
    if payment.status != "PENDING":
        return {"status": payment.status.lower(), "payment_id": payment.id, "already_processed": True}

    now = datetime.utcnow()
    payment.status = "CONFIRMED"
    payment.confirmed_at = now
    metadata = payment.metadata_json or {}
    result: dict[str, Any] = {"status": "confirmed", "payment_id": payment.id, "kind": payment.kind}

    if payment.kind in {"PRODUCT_BOOST", "STATUS_BOOST"}:
        days = metadata.get("days")
        product = (
            db.query(MarketplaceProduct).filter(MarketplaceProduct.id == metadata.get("product_id")).first()
            if metadata.get("product_id") else None
        )
        boost = MarketplaceBoost(
            seller_id=payment.user_id,
            product_id=metadata.get("product_id"),
            status_id=metadata.get("status_id"),
            payment_id=payment.id,
            starts_at=now,
            expires_at=now + timedelta(hours=int(metadata.get("duration_hours") or 48)),
            days=days,
            # 7 jours = une place dans la bande des statuts, relue par la
            # modération avant d'apparaître. Les résultats n'attendent pas.
            status_moderation="PENDING" if days == 7 else None,
            city=product.location if product else None,
        )
        db.add(boost)
        db.flush()
        result["boost_id"] = boost.id
        result["expires_at"] = boost.expires_at.isoformat()
    elif payment.kind == "AD":
        ad = db.query(MarketplaceAd).filter(MarketplaceAd.id == metadata.get("ad_id")).first()
        if ad:
            # « PAID » et non « ACTIVE » : payée, en attente de RELECTURE.
            #
            # Une campagne s'activait toute seule à la confirmation du
            # paiement. Concrètement, quiconque payait diffusait son message
            # à tous les utilisateurs de l'application sans qu'un humain
            # l'ait jamais lu — escroquerie, contenu illégal ou attaque d'un
            # concurrent, sous notre marque. Le modèle annonçait pourtant
            # « activée après paiement ET validation » : c'est la validation
            # qui manquait, pas l'intention.
            #
            # Les dates de diffusion ne sont PAS posées ici : elles partent
            # de l'approbation (voir marketplace_admin.decide_ad), pour
            # qu'une campagne retenue trois jours en relecture ne perde pas
            # trois jours de diffusion payés.
            ad.status = "PAID"
            result["ad_id"] = ad.id
            result["awaiting_review"] = True
    elif payment.kind in _MODULE_PAYMENT_KINDS:
        # Chaque module pose son effet dans son propre fichier ; c'est ici que
        # le paiement lui est remis, et nulle part ailleurs.
        applied = _apply_module_payment(db, payment)
        if applied:
            result.update(applied)
    elif payment.kind == "VERIFICATION":
        # Le paiement confirme le dossier; le badge reste réservé à l'équipe.
        application = db.query(SellerVerificationApplication).filter(
            SellerVerificationApplication.id == metadata.get("application_id")
        ).first()
        if application:
            result["application_id"] = application.id
    elif payment.kind == "CHANNEL_CERTIFICATION":
        # Même règle que la vérification vendeur : payer ouvre le dossier,
        # l'équipe accorde. Un badge qui s'allumerait sur simple paiement ne
        # dirait plus « fiable » mais « a payé », ce qui est exactement ce
        # qu'il ne doit pas dire.
        application = db.query(ChannelCertificationApplication).filter(
            ChannelCertificationApplication.id
            == metadata.get("certification_application_id")
        ).first()
        if application:
            result["certification_application_id"] = application.id

    db.commit()
    return result
