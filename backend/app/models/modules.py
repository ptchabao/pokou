"""Modules activables de l'application (Heart League, séries, Truth, cérémonies, VIP, Hype Train)."""
from datetime import datetime

from sqlalchemy import Column, Integer, String, DateTime, Date, Boolean, ForeignKey, Text, UniqueConstraint
from sqlalchemy.orm import relationship

from app.core.database import Base


class AppModule(Base):
    """Un module activable de Pokou — le catalogue des extensions.

    EN BASE, et non une liste écrite en dur dans l'application. C'est ce qui
    permet d'ouvrir ou de fermer un module sans publier une version sur le
    Play Store : une fonctionnalité qui dérape — un fil anonyme qui tourne au
    harcèlement, un défi qui met quelqu'un en danger — doit pouvoir être
    coupée dans la minute, pas dans les trois jours d'une revue de store.

    Deux interrupteurs, et ils ne font pas la même chose :

    - `is_enabled` appartient à l'ÉQUIPE. Coupé, le module disparaît pour
      tout le monde, y compris ceux qui l'avaient activé.
    - l'activation par personne vit dans `UserModuleActivation`. C'est un
      choix individuel, et il survit à une désactivation temporaire de
      l'équipe — on ne redemande pas à quelqu'un de réactiver ce qu'il avait
      déjà choisi.
    """
    __tablename__ = "app_modules"

    id = Column(Integer, primary_key=True, index=True)
    #: Identifiant stable, cité par le code client (ex. « secret_crush »).
    #: Jamais l'identifiant numérique : celui-ci change d'un environnement à
    #: l'autre, le slug non.
    slug = Column(String(48), nullable=False, unique=True, index=True)
    name = Column(String(80), nullable=False)
    #: Une phrase. C'est ce que lit quelqu'un qui hésite à activer.
    tagline = Column(String(160), nullable=False)
    description = Column(Text, nullable=False)
    #: Nom d'icône Material, résolu côté client par une table explicite —
    #: pas par réflexion, que l'élagage de code de Flutter casserait en
    #: release sans rien dire.
    icon = Column(String(48), nullable=False, default="extension")
    #: Couleur d'accent hexadécimale, pour que chaque module ait sa
    #: physionomie dans la galerie.
    accent_color = Column(String(9), nullable=False, default="#075E54")
    category = Column(String(24), nullable=False, default="SOCIAL")

    #: Coupé par l'équipe : le module disparaît pour tout le monde.
    is_enabled = Column(Boolean, nullable=False, default=False, index=True)
    #: Mis en avant dans « Recommandés ». Éditorial, choisi par l'équipe.
    is_recommended = Column(Boolean, nullable=False, default=False)
    #: Ordre d'affichage à popularité égale — un module tout neuf n'a aucune
    #: activation et resterait invisible sans ça.
    position = Column(Integer, nullable=False, default=0)

    created_at = Column(DateTime, default=datetime.utcnow, nullable=False)
    updated_at = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow, nullable=False)

    activations = relationship(
        "UserModuleActivation", cascade="all, delete-orphan", back_populates="module"
    )


class UserModuleActivation(Base):
    """Le choix d'une personne d'activer un module.

    Une LIGNE et non un booléen sur l'utilisateur : le nombre de modules
    change, et une colonne par module obligerait à une migration à chaque
    ajout. C'est aussi ce qui donne gratuitement le compteur de popularité.

    Conservée même quand l'équipe coupe le module : on ne redemande pas à
    quelqu'un de réactiver ce qu'il avait déjà choisi parce qu'on a fermé la
    fonctionnalité une semaine.
    """
    __tablename__ = "user_module_activations"
    __table_args__ = (
        UniqueConstraint("user_id", "module_id", name="uq_user_module"),
    )

    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True)
    module_id = Column(Integer, ForeignKey("app_modules.id", ondelete="CASCADE"), nullable=False, index=True)
    activated_at = Column(DateTime, default=datetime.utcnow, nullable=False)

    module = relationship("AppModule", back_populates="activations")


class HeartLeagueProfile(Base):
    """Heart League — le classement d'un utilisateur.

    Une ligne PAR UTILISATEUR et non des colonnes sur `User` : le module est
    activable, et la majorité des comptes n'y participeront jamais. Une
    colonne sur `users` la ferait payer à tout le monde, y compris à ceux
    qui n'ont jamais ouvert le module.

    ── Ce que les points mesurent ──────────────────────────────────────

    Uniquement des signaux REÇUS : messages entrants, cadeaux reçus. Jamais
    ce que l'utilisateur envoie. C'est la seule façon d'éviter qu'on monte en
    écrivant à tout le monde, ce qui transformerait le classement en concours
    de spam — et rendrait l'application désagréable pour les destinataires.
    """
    __tablename__ = "heart_league_profiles"

    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(
        Integer, ForeignKey("users.id", ondelete="CASCADE"),
        nullable=False, unique=True, index=True,
    )
    points = Column(Integer, nullable=False, default=0, index=True)
    #: Début de la semaine de décompte en cours. Une DATE et non un compteur
    #: de jours : le décompte se calcule alors sans tâche de fond, à la
    #: lecture, et reste exact même si personne n'ouvre l'application.
    week_start = Column(DateTime, nullable=False, default=datetime.utcnow)
    #: Protection contre le décompte hebdomadaire, achetée. Une DATE
    #: d'expiration et non un booléen : elle s'éteint toute seule.
    protected_until = Column(DateTime, nullable=True)
    #: Plus haut palier jamais atteint — sert à féliciter, pas à classer.
    best_points = Column(Integer, nullable=False, default=0)
    updated_at = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow, nullable=False)


class HeartLeaguePass(Base):
    """Un laissez-passer acheté pour écrire à quelqu'un d'une ligue
    supérieure.

    Rattaché à une PAIRE et daté : il ouvre une conversation précise, pour
    une durée précise. Un pass global permettrait d'acheter une fois pour
    écrire à tout le monde — ce qui viderait la mécanique de son sens et
    ferait de l'application un canal de démarchage.
    """
    __tablename__ = "heart_league_passes"
    __table_args__ = (
        UniqueConstraint("buyer_id", "target_id", "expires_at", name="uq_league_pass"),
    )

    id = Column(Integer, primary_key=True, index=True)
    buyer_id = Column(Integer, ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True)
    target_id = Column(Integer, ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True)
    payment_id = Column(Integer, ForeignKey("marketplace_payments.id", ondelete="SET NULL"), nullable=True)
    created_at = Column(DateTime, default=datetime.utcnow, nullable=False)
    expires_at = Column(DateTime, nullable=False, index=True)


class ConversationStreak(Base):
    """La chaîne d'une conversation — un jour d'échange à la fois.

    Une ligne par PAIRE, avec les deux identifiants toujours rangés dans le
    même ordre (`low` < `high`). Sans cet ordre, la même conversation
    produirait deux lignes selon qui écrit le premier, et chacune compterait
    sa propre chaîne.

    Ce qui la fait avancer est un ÉCHANGE, pas un envoi : les deux doivent
    avoir écrit dans la journée. Compter les envois ferait monter une chaîne
    en écrivant dans le vide, ce qui la viderait de son sens — une chaîne
    mesure une relation, pas une assiduité solitaire.
    """
    __tablename__ = "conversation_streaks"
    __table_args__ = (
        UniqueConstraint("low_user_id", "high_user_id", name="uq_streak_pair"),
    )

    id = Column(Integer, primary_key=True, index=True)
    low_user_id = Column(Integer, ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True)
    high_user_id = Column(Integer, ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True)

    current_days = Column(Integer, nullable=False, default=0)
    best_days = Column(Integer, nullable=False, default=0)
    #: Dernier jour où les DEUX ont écrit. Une date et non un horodatage :
    #: la chaîne se compte en jours, et comparer des instants ferait dépendre
    #: le résultat de l'heure d'envoi.
    last_exchange_day = Column(Date, nullable=True)
    #: Jours où chacun a écrit pour la dernière fois — c'est leur
    #: intersection qui fait un échange.
    low_last_day = Column(Date, nullable=True)
    high_last_day = Column(Date, nullable=True)
    #: Quand la chaîne s'est rompue. Renseigné, un rachat reste possible
    #: pendant la fenêtre de grâce.
    broken_at = Column(DateTime, nullable=True)
    #: Longueur perdue, conservée pour pouvoir la RENDRE en cas de rachat.
    broken_days = Column(Integer, nullable=False, default=0)
    updated_at = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow, nullable=False)


class TruthQuestion(Base):
    """Une question payée, posée à quelqu'un.

    La réponse ne va QU'À l'acheteur. La revente anonyme prévue au concept
    initial n'est pas implémentée, et ce n'est pas un oubli : quelqu'un
    répond à UN acheteur, pas au public. Redistribuer sa confession en ferait
    un outil de chantage hébergé par Pokou.

    L'argent n'est versé qu'à la RÉPONSE. Payer à la question donnerait de
    l'argent pour un silence, et transformerait le refus en gain.
    """
    __tablename__ = "truth_questions"

    id = Column(Integer, primary_key=True, index=True)
    asker_id = Column(Integer, ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True)
    target_id = Column(Integer, ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True)
    payment_id = Column(Integer, ForeignKey("marketplace_payments.id", ondelete="SET NULL"), nullable=True)

    question = Column(String(280), nullable=False)
    amount = Column(Integer, nullable=False)
    #: PENDING (payée, en attente) | ANSWERED | DECLINED | EXPIRED
    status = Column(String(12), nullable=False, default="PENDING", index=True)
    answer = Column(Text, nullable=True)
    #: Média d'une réponse vocale, quand il y en a une.
    answer_media_id = Column(Integer, ForeignKey("media_assets.id"), nullable=True)

    created_at = Column(DateTime, default=datetime.utcnow, nullable=False, index=True)
    answered_at = Column(DateTime, nullable=True)
    #: Au-delà, la question s'éteint et l'acheteur est remboursable. Sans
    #: échéance, l'argent resterait bloqué indéfiniment sur un silence.
    expires_at = Column(DateTime, nullable=False, index=True)

    answer_media = relationship("MediaAsset")


class CeremonyFund(Base):
    """Une cagnotte de cérémonie — mariage, baptême, deuil.

    Le mur des contributeurs existe ; les relances aux non-payeurs, NON. La
    cotisation cérémonielle est une pratique réelle et utile ; le harcèlement
    automatisé de ceux qui n'ont pas donné ne l'est pas, et ferait partir
    exactement les gens qui n'avaient pas l'argent ce mois-là.
    """
    __tablename__ = "ceremony_funds"

    id = Column(Integer, primary_key=True, index=True)
    organizer_id = Column(Integer, ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True)
    title = Column(String(120), nullable=False)
    description = Column(String(500), nullable=True)
    kind = Column(String(16), nullable=False, default="AUTRE")  # MARIAGE|BAPTEME|DEUIL|AUTRE
    #: Objectif indicatif, jamais contraignant : une cagnotte qui refuse une
    #: contribution parce que l'objectif est atteint est absurde.
    goal_amount = Column(Integer, nullable=True)
    #: Total confirmé, tenu à jour à chaque contribution — le recalculer à
    #: chaque affichage coûterait une agrégation par ouverture d'écran.
    collected_amount = Column(Integer, nullable=False, default=0)
    is_closed = Column(Boolean, nullable=False, default=False)
    created_at = Column(DateTime, default=datetime.utcnow, nullable=False)
    closes_at = Column(DateTime, nullable=True)


class CeremonyContribution(Base):
    """Une participation à une cagnotte.

    `is_anonymous` n'est pas un ornement : quelqu'un qui donne peu doit
    pouvoir donner sans que le montant s'affiche à côté de son nom. Sans
    cette option, le mur des contributeurs devient un classement de revenus.
    """
    __tablename__ = "ceremony_contributions"

    id = Column(Integer, primary_key=True, index=True)
    fund_id = Column(Integer, ForeignKey("ceremony_funds.id", ondelete="CASCADE"), nullable=False, index=True)
    contributor_id = Column(Integer, ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True)
    payment_id = Column(Integer, ForeignKey("marketplace_payments.id", ondelete="SET NULL"), nullable=True)
    amount = Column(Integer, nullable=False)
    message = Column(String(280), nullable=True)
    is_anonymous = Column(Boolean, nullable=False, default=False)
    status = Column(String(12), nullable=False, default="PENDING", index=True)
    created_at = Column(DateTime, default=datetime.utcnow, nullable=False)
    confirmed_at = Column(DateTime, nullable=True)


class VipRoom(Base):
    """Le salon d'abonnés d'un créateur.

    Un seul par compte : plusieurs salons obligeraient l'abonné à choisir
    lequel prendre, ce qui n'a de sens que pour un catalogue — or ce qu'on
    achète ici est une PERSONNE, pas un produit.
    """
    __tablename__ = "vip_rooms"

    id = Column(Integer, primary_key=True, index=True)
    owner_id = Column(
        Integer, ForeignKey("users.id", ondelete="CASCADE"),
        nullable=False, unique=True, index=True,
    )
    title = Column(String(120), nullable=False)
    pitch = Column(String(500), nullable=False)
    monthly_price = Column(Integer, nullable=False)
    is_open = Column(Boolean, nullable=False, default=True, index=True)
    created_at = Column(DateTime, default=datetime.utcnow, nullable=False)


class VipSubscription(Base):
    """Un abonnement à un salon, avec une échéance.

    Une DATE de fin et non un drapeau : l'abonnement s'éteint tout seul, sans
    tâche de fond qui devrait passer sur chaque ligne chaque jour — et dont
    la panne laisserait des accès ouverts indéfiniment.

    Pas de reconduction automatique : la prélever supposerait de conserver un
    moyen de paiement, ce que Pokou ne fait pas, et surtout d'expliquer très
    clairement comment l'arrêter. Un renouvellement explicite coûte un geste
    et évite la moitié des litiges d'un abonnement.
    """
    __tablename__ = "vip_subscriptions"

    id = Column(Integer, primary_key=True, index=True)
    room_id = Column(Integer, ForeignKey("vip_rooms.id", ondelete="CASCADE"), nullable=False, index=True)
    subscriber_id = Column(Integer, ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True)
    payment_id = Column(Integer, ForeignKey("marketplace_payments.id", ondelete="SET NULL"), nullable=True)
    started_at = Column(DateTime, default=datetime.utcnow, nullable=False)
    expires_at = Column(DateTime, nullable=False, index=True)


class VipPost(Base):
    """Une publication réservée aux abonnés."""
    __tablename__ = "vip_posts"

    id = Column(Integer, primary_key=True, index=True)
    room_id = Column(Integer, ForeignKey("vip_rooms.id", ondelete="CASCADE"), nullable=False, index=True)
    text_content = Column(Text, nullable=True)
    media_asset_id = Column(Integer, ForeignKey("media_assets.id"), nullable=True)
    created_at = Column(DateTime, default=datetime.utcnow, nullable=False, index=True)

    media = relationship("MediaAsset")


class HypeTrain(Base):
    """Un objectif collectif, à atteindre ensemble avant l'échéance.

    Ce qu'on achète débloque un CONTENU — jamais convertible en argent.
    C'est ce qui sépare ce module de Gift Rain, abandonné parce que la
    conversion en Mobile Money est une émission de monnaie électronique.
    """
    __tablename__ = "hype_trains"

    id = Column(Integer, primary_key=True, index=True)
    owner_id = Column(Integer, ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True)
    title = Column(String(120), nullable=False)
    promise = Column(String(500), nullable=False)
    goal_amount = Column(Integer, nullable=False)
    collected_amount = Column(Integer, nullable=False, default=0)
    #: Renseigné au franchissement de l'objectif — et jamais recalculé
    #: ensuite. Un palier atteint reste atteint, même si une contribution
    #: est annulée après coup.
    unlocked_at = Column(DateTime, nullable=True)
    expires_at = Column(DateTime, nullable=False, index=True)
    created_at = Column(DateTime, default=datetime.utcnow, nullable=False)


class HypeContribution(Base):
    """Une participation à un objectif collectif."""
    __tablename__ = "hype_contributions"

    id = Column(Integer, primary_key=True, index=True)
    train_id = Column(Integer, ForeignKey("hype_trains.id", ondelete="CASCADE"), nullable=False, index=True)
    contributor_id = Column(Integer, ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True)
    payment_id = Column(Integer, ForeignKey("marketplace_payments.id", ondelete="SET NULL"), nullable=True)
    amount = Column(Integer, nullable=False)
    status = Column(String(12), nullable=False, default="PENDING", index=True)
    created_at = Column(DateTime, default=datetime.utcnow, nullable=False)
