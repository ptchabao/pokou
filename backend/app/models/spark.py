"""Spark : rencontres, matchs, rendez-vous et sécurité."""
from datetime import datetime

from sqlalchemy import Column, Integer, String, DateTime, Date, Boolean, ForeignKey, Float, UniqueConstraint
from sqlalchemy.orm import relationship

from app.core.database import Base


class SparkProfile(Base):
    """La fiche Spark de quelqu'un, distincte de son profil Pokou.

    Distincte, et c'est délibéré : la photo qu'on met sur une application de
    messagerie n'est pas celle qu'on met sur une application de rencontres, et
    réutiliser l'avatar Pokou exposerait à Spark des gens qui n'y sont pas.
    Ouvrir Spark est un geste, pas un héritage.
    """
    __tablename__ = "spark_profiles"

    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(
        Integer, ForeignKey("users.id", ondelete="CASCADE"),
        nullable=False, unique=True, index=True,
    )
    display_name = Column(String(60), nullable=False)
    bio = Column(String(300), nullable=True)
    #: Date de naissance, et non un âge : un âge se périme, et il faudrait le
    #: recalculer sans jamais savoir quand il a été saisi. La règle des 18 ans
    #: est vérifiée à l'inscription ET à chaque affichage.
    birth_date = Column(Date, nullable=False)
    gender = Column(String(8), nullable=False)  # F | M | AUTRE
    latitude = Column(Float, nullable=True)
    longitude = Column(Float, nullable=True)
    #: Dernière position connue. Un profil dont la position date de trois
    #: semaines ne doit pas apparaître « à 2 km » : c'est faux, et pour une
    #: rencontre physique c'est une information trompeuse.
    location_updated_at = Column(DateTime, nullable=True)
    is_visible = Column(Boolean, nullable=False, default=True, index=True)

    #: Street Cred. Ce que quelqu'un vaut en tant que personne avec qui on
    #: prend rendez-vous — pas en tant que profil.
    karma = Column(Integer, nullable=False, default=100)

    #: L'économie des likes. Le quota gratuit se remet à zéro par JOUR, d'où
    #: la date : un compteur seul ne saurait pas de quel jour il parle.
    free_likes_day = Column(Date, nullable=True)
    free_likes_used = Column(Integer, nullable=False, default=0)
    #: Likes achetés, qui ne se périment pas. Les périmer reviendrait à
    #: reprendre quelque chose de payé.
    likes_balance = Column(Integer, nullable=False, default=0)

    #: Les droits achetés, tenus par une DATE de fin plutôt qu'un drapeau :
    #: ils s'éteignent seuls, sans tâche de fond dont la panne laisserait des
    #: accès ouverts.
    plus_until = Column(DateTime, nullable=True)
    see_likers_until = Column(DateTime, nullable=True)
    boost_until = Column(DateTime, nullable=True, index=True)

    #: Quota de consultation du jour, pour les comptes sans Spark+.
    views_day = Column(Date, nullable=True)
    views_used = Column(Integer, nullable=False, default=0)

    created_at = Column(DateTime, default=datetime.utcnow, nullable=False)

    photos = relationship(
        "SparkPhoto", cascade="all, delete-orphan", order_by="SparkPhoto.position"
    )


class SparkPhoto(Base):
    """Une photo de fiche Spark."""
    __tablename__ = "spark_photos"

    id = Column(Integer, primary_key=True, index=True)
    profile_id = Column(
        Integer, ForeignKey("spark_profiles.id", ondelete="CASCADE"),
        nullable=False, index=True,
    )
    media_asset_id = Column(Integer, ForeignKey("media_assets.id"), nullable=False)
    position = Column(Integer, nullable=False, default=0)

    media = relationship("MediaAsset")


class SparkIntent(Base):
    """La Carte du Moment — ce que je cherche AUJOURD'HUI.

    Elle expire en 24 heures, et c'est le mécanisme central du produit : une
    intention permanente redevient un profil, c'est-à-dire une description de
    soi qu'on ne relit jamais. Une intention qui meurt oblige à revenir dire
    ce qu'on veut, et garantit que ce qu'on lit d'un autre est vrai
    aujourd'hui.

    Les lignes expirées ne sont PAS effacées : elles disent ce que quelqu'un
    cherchait la semaine dernière, ce qui est précisément ce qu'il faut pour
    instruire un signalement.
    """
    __tablename__ = "spark_intents"

    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True)
    kind = Column(String(12), nullable=False, index=True)  # JASE|JUS|AFTER|SERIEUX
    created_at = Column(DateTime, default=datetime.utcnow, nullable=False)
    expires_at = Column(DateTime, nullable=False, index=True)


class SparkLike(Base):
    """Un like, ordinaire ou Super Spark.

    Unique par couple (émetteur, destinataire) : sans cette contrainte, on
    pourrait liker cent fois la même personne, ce qui viderait le quota de son
    sens et transformerait la notification en harcèlement.
    """
    __tablename__ = "spark_likes"

    id = Column(Integer, primary_key=True, index=True)
    from_user_id = Column(Integer, ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True)
    to_user_id = Column(Integer, ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True)
    kind = Column(String(8), nullable=False, default="LIKE")  # LIKE | SUPER
    #: Le vocal de cinq secondes d'un Super Spark. Le destinataire doit
    #: l'écouter avant de pouvoir trancher — c'est ce qui le distingue d'un
    #: like payant qui ne serait qu'un like plus cher.
    voice_media_id = Column(Integer, ForeignKey("media_assets.id"), nullable=True)
    listened_at = Column(DateTime, nullable=True)
    created_at = Column(DateTime, default=datetime.utcnow, nullable=False)

    __table_args__ = (
        UniqueConstraint("from_user_id", "to_user_id", name="uq_spark_like_pair"),
    )


class SparkPass(Base):
    """Un profil écarté. Gardé pour ne pas le remontrer le lendemain."""
    __tablename__ = "spark_passes"

    id = Column(Integer, primary_key=True, index=True)
    from_user_id = Column(Integer, ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True)
    to_user_id = Column(Integer, ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True)
    created_at = Column(DateTime, default=datetime.utcnow, nullable=False)

    __table_args__ = (
        UniqueConstraint("from_user_id", "to_user_id", name="uq_spark_pass_pair"),
    )


class SparkMatch(Base):
    """Un match, et sa Salle d'Entrée.

    Le couple est ordonné (low < high) comme pour les chaînes de Streak Lock :
    une même paire ne doit pas pouvoir exister deux fois selon qui a liké en
    premier.
    """
    __tablename__ = "spark_matches"

    id = Column(Integer, primary_key=True, index=True)
    low_user_id = Column(Integer, ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True)
    high_user_id = Column(Integer, ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True)
    created_at = Column(DateTime, default=datetime.utcnow, nullable=False)

    #: Fin de la Salle d'Entrée. Repoussée par les prolongations payées.
    room_expires_at = Column(DateTime, nullable=False, index=True)
    extensions = Column(Integer, nullable=False, default=0)

    #: Qui a appuyé sur « Continuer ». Horodaté, pas booléen : l'ordre compte
    #: pour attribuer le malus à celui qui n'a pas répondu.
    low_continued_at = Column(DateTime, nullable=True)
    high_continued_at = Column(DateTime, nullable=True)

    #: ROOM (en cours) | CONTINUED (les deux ont accepté) | SAVED (un seul) |
    #: EXPIRED (personne) | ENDED (quelqu'un a quitté)
    status = Column(String(12), nullable=False, default="ROOM", index=True)
    resolved_at = Column(DateTime, nullable=True)

    __table_args__ = (
        UniqueConstraint("low_user_id", "high_user_id", name="uq_spark_match_pair"),
    )


class SparkRoomMessage(Base):
    """Un message de Salle d'Entrée — vocal ou sticker, JAMAIS du texte.

    L'interdiction du texte n'est pas une contrainte esthétique : elle rend
    le copier-coller impossible, ce qui élimine d'un coup les messages
    d'approche recopiés et la plupart des faux profils, qui ne peuvent pas
    improviser cinq secondes de voix.
    """
    __tablename__ = "spark_room_messages"

    id = Column(Integer, primary_key=True, index=True)
    match_id = Column(Integer, ForeignKey("spark_matches.id", ondelete="CASCADE"), nullable=False, index=True)
    sender_id = Column(Integer, ForeignKey("users.id", ondelete="CASCADE"), nullable=False)
    kind = Column(String(8), nullable=False)  # VOICE | STICKER
    media_asset_id = Column(Integer, ForeignKey("media_assets.id"), nullable=True)
    sticker = Column(String(32), nullable=True)
    created_at = Column(DateTime, default=datetime.utcnow, nullable=False, index=True)

    media = relationship("MediaAsset")


class SparkWingmanVote(Base):
    """L'avis d'un ami sur un profil, avant la Salle.

    Le votant ne voit jamais le résultat des autres, et le concerné ne voit
    qu'un agrégat : « tes potes valident ». Montrer qui a voté rouge
    transformerait un service rendu en dispute entre amis.
    """
    __tablename__ = "spark_wingman_votes"

    id = Column(Integer, primary_key=True, index=True)
    owner_id = Column(Integer, ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True)
    candidate_id = Column(Integer, ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True)
    voter_id = Column(Integer, ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True)
    vote = Column(String(6), nullable=True)  # GREEN | RED, nul tant qu'on n'a pas voté
    created_at = Column(DateTime, default=datetime.utcnow, nullable=False)
    voted_at = Column(DateTime, nullable=True)

    __table_args__ = (
        UniqueConstraint("owner_id", "candidate_id", "voter_id", name="uq_spark_wingman"),
    )


class SparkDatePack(Base):
    """Une formule proposée par un commerçant.

    Le catalogue est tenu par l'ÉQUIPE, pas par les commerçants eux-mêmes :
    un pack est une promesse faite à deux personnes qui vont se déplacer, et
    une formule fantaisiste coûte un rendez-vous raté à quelqu'un.
    """
    __tablename__ = "spark_date_packs"

    id = Column(Integer, primary_key=True, index=True)
    merchant_id = Column(Integer, ForeignKey("users.id", ondelete="SET NULL"), nullable=True, index=True)
    title = Column(String(120), nullable=False)
    description = Column(String(500), nullable=True)
    venue_name = Column(String(120), nullable=False)
    venue_address = Column(String(255), nullable=True)
    latitude = Column(Float, nullable=True)
    longitude = Column(Float, nullable=True)
    price = Column(Integer, nullable=False)
    image_media_id = Column(Integer, ForeignKey("media_assets.id"), nullable=True)
    is_active = Column(Boolean, nullable=False, default=True, index=True)
    created_at = Column(DateTime, default=datetime.utcnow, nullable=False)

    image = relationship("MediaAsset")


class SparkDate(Base):
    """Un rendez-vous payé d'avance, et l'argent qui l'accompagne.

    C'est la table la plus délicate du module : elle tient de l'argent qui
    n'appartient plus à celui qui l'a versé et pas encore à celui qui le
    recevra. Chaque transition est donc horodatée et irréversible — un état
    qu'on peut réécrire est un état qu'on finira par réécrire.
    """
    __tablename__ = "spark_dates"

    id = Column(Integer, primary_key=True, index=True)
    match_id = Column(Integer, ForeignKey("spark_matches.id", ondelete="CASCADE"), nullable=False, index=True)
    pack_id = Column(Integer, ForeignKey("spark_date_packs.id", ondelete="RESTRICT"), nullable=False)
    payer_id = Column(Integer, ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True)
    guest_id = Column(Integer, ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True)
    payment_id = Column(Integer, ForeignKey("marketplace_payments.id", ondelete="SET NULL"), nullable=True)

    amount = Column(Integer, nullable=False)
    scheduled_at = Column(DateTime, nullable=False, index=True)

    #: PENDING (paiement ouvert) | HELD (encaissé, bloqué) | RELEASED (dû au
    #: commerçant) | REFUNDED (annulé à temps) | PENALIZED (lapin) |
    #: CANCELLED (annulé trop tard, sans lapin constaté)
    status = Column(String(12), nullable=False, default="PENDING", index=True)

    #: Le bon présenté au commerçant. Généré seulement à l'encaissement : un
    #: code émis avant le paiement serait un repas gratuit.
    voucher_code = Column(String(16), nullable=True, unique=True, index=True)
    voucher_used_at = Column(DateTime, nullable=True)

    payer_validated_at = Column(DateTime, nullable=True)
    guest_validated_at = Column(DateTime, nullable=True)

    #: Ce que l'application retient. Compté à la libération, et figé : le taux
    #: peut changer demain, pas pour un rendez-vous déjà réglé.
    platform_fee = Column(Integer, nullable=True)
    #: Ce qui est DÛ au commerçant. « Dû », pas « versé » — Pokou n'a pas
    #: encore de rail de virement sortant (voir VIP Room, Social Tax).
    merchant_due = Column(Integer, nullable=True)
    #: En cas de lapin : qui reçoit la pénalité, et combien.
    penalty_to_user_id = Column(Integer, ForeignKey("users.id", ondelete="SET NULL"), nullable=True)
    penalty_amount = Column(Integer, nullable=True)

    settled_at = Column(DateTime, nullable=True)
    created_at = Column(DateTime, default=datetime.utcnow, nullable=False)


class SparkSafetyContact(Base):
    """Le cercle de sécurité — qui est prévenu si ça tourne mal.

    Choisi par la personne, pas déduit de ses Wingmen : demander un avis sur
    un profil et confier sa position en direct sont deux choses différentes,
    et les confondre ferait partager une localisation à quelqu'un qu'on avait
    seulement consulté.
    """
    __tablename__ = "spark_safety_contacts"

    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True)
    contact_user_id = Column(Integer, ForeignKey("users.id", ondelete="CASCADE"), nullable=False)
    created_at = Column(DateTime, default=datetime.utcnow, nullable=False)

    __table_args__ = (
        UniqueConstraint("user_id", "contact_user_id", name="uq_spark_safety_contact"),
    )


class SparkSafetyAlert(Base):
    """Une alerte partie du cercle de sécurité.

    Jamais effacée, même résolue : c'est la seule trace de ce qui s'est passé
    un soir, et elle peut être demandée bien après.
    """
    __tablename__ = "spark_safety_alerts"

    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True)
    date_id = Column(Integer, ForeignKey("spark_dates.id", ondelete="SET NULL"), nullable=True, index=True)
    #: SAFE_WORD (déclenchée par la personne) | CHECKIN_MISSED (silence)
    kind = Column(String(16), nullable=False)
    latitude = Column(Float, nullable=True)
    longitude = Column(Float, nullable=True)
    resolved_at = Column(DateTime, nullable=True)
    created_at = Column(DateTime, default=datetime.utcnow, nullable=False, index=True)


class SparkCheckin(Base):
    """« Tout va bien ? », trente minutes après le début du rendez-vous.

    Posé à l'AVANCE, à la création du rendez-vous, et non au moment voulu :
    une question qui dépend d'une tâche de fond pour exister est une question
    qui ne sera pas posée le jour où cette tâche tombe en panne.
    """
    __tablename__ = "spark_checkins"

    id = Column(Integer, primary_key=True, index=True)
    date_id = Column(Integer, ForeignKey("spark_dates.id", ondelete="CASCADE"), nullable=False, index=True)
    user_id = Column(Integer, ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True)
    due_at = Column(DateTime, nullable=False, index=True)
    answered_at = Column(DateTime, nullable=True)
    #: PENDING | OK | ESCALATED
    status = Column(String(12), nullable=False, default="PENDING", index=True)
