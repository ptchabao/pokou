"""Sessions, codes de connexion, jetons et clés de chiffrement des appareils."""
from datetime import datetime

from sqlalchemy import Column, Integer, String, DateTime, Boolean, JSON, ForeignKey, UniqueConstraint
from sqlalchemy.orm import relationship

from app.core.database import Base


class Token(Base):
    __tablename__ = "tokens"
    
    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("users.id"), nullable=False)
    access_token = Column(String(500), nullable=False)
    refresh_token = Column(String(500), nullable=False)
    jti = Column(String(64), nullable=True, index=True)
    revoked_at = Column(DateTime, nullable=True)

    # ── La fenêtre de grâce à la rotation ────────────────────────────────
    #
    # Échanger un jeton de rafraîchissement le révoque aussitôt. Si la
    # RÉPONSE se perd — coupure au mauvais instant, ce qui est courant sur
    # un réseau mobile —, l'ancien jeton est mort et le client n'a jamais
    # reçu le nouveau. La session est alors définitivement perdue, sans que
    # personne n'ait rien fait de mal.
    #
    # `rotated_at` date l'échange. Pendant une minute après, l'ancien jeton
    # reste rejouable UNE fois, et `grace_used_at` interdit de recommencer.
    # `replaced_by_jti` garde la chaîne, pour qu'un incident se lise dans le
    # journal plutôt que de se deviner.
    rotated_at = Column(DateTime, nullable=True)
    replaced_by_jti = Column(String(64), nullable=True)
    grace_used_at = Column(DateTime, nullable=True)

    expires_at = Column(DateTime, nullable=False)
    created_at = Column(DateTime, default=datetime.utcnow, nullable=False)

    # Relationships
    user = relationship("User", back_populates="tokens")


class WSTicket(Base):
    """Un laissez-passer à usage unique pour ouvrir le WebSocket.

    Le jeton d'accès voyageait dans l'URL du WebSocket
    (`/api/v1/ws?token=eyJ...`). Une URL se retrouve partout : journal
    d'accès du serveur, reverse proxy, traces de supervision, historique.
    Quiconque en lisait une pouvait rejouer la session pendant trente
    minutes. Un filtre de rédaction coupait la fuite vers NOS journaux, mais
    pas vers ceux des autres.

    Un ticket règle le problème à la source : il ne vaut que quelques
    secondes, ne sert qu'UNE fois, et ne donne accès qu'à l'ouverture d'une
    socket — pas à l'API.

    On stocke son EMPREINTE, jamais le ticket. Même raisonnement que pour la
    table des sessions : un export de base ne doit pas livrer de quoi se
    connecter. L'empreinte suffit à vérifier un ticket présenté, et ne
    permet pas d'en fabriquer un.
    """

    __tablename__ = "ws_tickets"

    id = Column(Integer, primary_key=True, index=True)
    ticket_hash = Column(String(64), nullable=False, unique=True, index=True)
    user_id = Column(Integer, ForeignKey("users.id"), nullable=False, index=True)
    # Le `jti` de la session qui a demandé le ticket. Révoquer la session
    # depuis « Appareils connectés » doit fermer cette porte-là AUSSI, sinon
    # un ticket déjà émis survivrait à la révocation.
    jti = Column(String(64), nullable=True, index=True)
    expires_at = Column(DateTime, nullable=False)
    consumed_at = Column(DateTime, nullable=True)
    created_at = Column(DateTime, default=datetime.utcnow, nullable=False)


class ActionToken(Base):
    """Un laissez-passer à usage unique, porté par une notification push.

    Le problème qu'il résout : la couche native — Kotlin, Swift — doit
    pouvoir accepter un appel ou refuser depuis l'écran verrouillé, SANS que
    Flutter démarre. Or le jeton de session vit dans `FlutterSecureStorage`,
    côté Dart. Le lire depuis Kotlin reviendrait à dépendre de
    l'implémentation interne d'un greffon tiers ; le recopier dans un
    stockage natif dupliquerait un secret de session longue durée dans un
    second endroit.

    Le push vient du serveur : il peut donc porter lui-même le laissez-passer.
    Le natif n'a alors AUCUN secret à garder.

    Même modèle que `WSTicket` — empreinte, usage unique, courte durée, lié à
    la session — et c'est délibéré : deux mécanismes de laissez-passer
    finiraient par diverger sur la seule question qui compte, celle de la
    révocation.

    ── Le jeton EST la clé d'idempotence ─────────────────────────────────

    Android peut délivrer deux fois la même action : réseau lent, double
    appui, ou l'intent rejoué après un redémarrage du processus. Comme la
    consommation est une écriture conditionnelle en un seul ordre SQL, la
    seconde tentative ne produit aucun second effet — elle renvoie l'état
    courant. Il n'y a donc pas besoin d'un identifiant d'action séparé : le
    jeton porte les deux rôles, et un seul mécanisme vaut mieux que deux qui
    doivent rester d'accord.
    """

    __tablename__ = "action_tokens"

    id = Column(Integer, primary_key=True, index=True)
    token_hash = Column(String(64), nullable=False, unique=True, index=True)
    # À quoi CE jeton donne droit, et à rien d'autre.
    scope = Column(String(24), nullable=False)  # call_accept/call_decline/message_reply
    user_id = Column(Integer, ForeignKey("users.id"), nullable=False, index=True)
    # La cible : le salon d'un appel, ou l'interlocuteur d'une conversation.
    # Un jeton qui n'en porterait pas serait un passe-partout.
    room = Column(String(64), nullable=True, index=True)
    peer_user_id = Column(Integer, ForeignKey("users.id"), nullable=True)
    # La session du destinataire. Révoquer un appareil depuis « Appareils
    # connectés » doit invalider les jetons d'action qu'il a en attente.
    jti = Column(String(64), nullable=True, index=True)
    expires_at = Column(DateTime, nullable=False, index=True)
    consumed_at = Column(DateTime, nullable=True)
    created_at = Column(DateTime, default=datetime.utcnow, nullable=False)


class PhoneOTP(Base):
    """Pokou (app mobile) — code de vérification à usage unique pour
    l'inscription/connexion par numéro de téléphone (façon WhatsApp).
    Le code lui-même n'est jamais stocké en clair (même hash que les mots
    de passe, voir app/services/otp_service.py)."""
    __tablename__ = "phone_otps"

    id = Column(Integer, primary_key=True, index=True)
    phone = Column(String(32), nullable=False, index=True)
    code_hash = Column(String(255), nullable=False)
    attempts = Column(Integer, default=0, nullable=False)
    expires_at = Column(DateTime, nullable=False)
    consumed_at = Column(DateTime, nullable=True)
    created_at = Column(DateTime, default=datetime.utcnow, nullable=False)


class DeviceToken(Base):
    """Pokou — jeton FCM d'un appareil, pour les notifications push quand
    l'app est fermée/en arrière-plan (le WebSocket ne fonctionne que tant
    que l'app est ouverte). Un utilisateur peut avoir plusieurs appareils ;
    un jeton peut se réattacher à un autre compte après une réinstallation,
    d'où l'upsert par jeton plutôt que par (user_id, platform)."""
    __tablename__ = "device_tokens"

    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("users.id"), nullable=False, index=True)
    token = Column(String(255), unique=True, nullable=False, index=True)
    platform = Column(String(16), nullable=False, default="android")
    # Le `jti` de la session qui a enregistré cet appareil.
    #
    # Sans lui, « Appareils connectés » ne pouvait PAS tenir sa promesse :
    # supprimer une ligne coupait les notifications, et l'appareil gardait un
    # accès complet à l'API jusqu'à l'expiration de son jeton — sept jours en
    # passant par le rafraîchissement. Un écran qui dit « révoquer » doit
    # révoquer.
    session_jti = Column(String(64), nullable=True, index=True)
    # L'application de cet appareil construit ELLE-MÊME ses notifications de
    # message (groupées par conversation, avec le contenu qu'elle va
    # chercher). Elle reçoit alors un push de données ; les versions
    # antérieures, qui ne savent afficher qu'un push « notification »,
    # continuent de recevoir celui-là — sinon elles deviendraient muettes.
    rich_message_push = Column(Boolean, default=False, nullable=False)
    created_at = Column(DateTime, default=datetime.utcnow, nullable=False)
    updated_at = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow, nullable=False)

    user = relationship("User")


class DeviceKeyBundle(Base):
    """Pokou — le trousseau PUBLIC d'un appareil, pour le chiffrement de bout
    en bout.

    Ce que le serveur détient ici est exactement ce qu'il a le droit de
    détenir : des clés PUBLIQUES. Les clés privées sont générées sur
    l'appareil et ne le quittent jamais — c'est la seule chose qui distingue
    un chiffrement de bout en bout d'un chiffrement en transit.

    Le rôle du serveur se limite donc à un annuaire : publier son trousseau,
    et récupérer celui d'autrui pour lui ouvrir une session. Il ne peut
    déchiffrer aucun message, y compris ceux qu'il stocke.

    **Un seul trousseau actif par compte**, remplacé à chaque réinstallation.
    Le multi-appareil demanderait de chiffrer chaque message une fois par
    appareil du destinataire, donc une ligne de chiffré par appareil : c'est
    un changement de forme du message, pas un réglage, et il est laissé pour
    plus tard. Conséquence assumée et visible pour l'utilisateur : après une
    réinstallation, l'historique chiffré d'avant n'est plus lisible, et le
    correspondant voit un avertissement de changement de clé.
    """
    __tablename__ = "device_key_bundles"
    __table_args__ = (UniqueConstraint("user_id", name="uq_device_key_bundle_user"),)

    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True)
    #: Identifiant d'installation, généré par l'appareil. Sert à reconnaître
    #: qu'un trousseau a changé de machine plutôt que d'avoir été renouvelé.
    device_id = Column(String(64), nullable=False)
    #: X25519 — la clé d'identité à long terme, base de l'authentification.
    identity_key = Column(String(64), nullable=False)
    #: Ed25519 — sert UNIQUEMENT à signer la pré-clé ci-dessous. Une clé de
    #: signature distincte de la clé d'échange : réutiliser la même pour
    #: deux usages cryptographiques est une faute classique.
    signing_key = Column(String(64), nullable=False)
    #: X25519 — pré-clé signée, renouvelable. Elle permet d'ouvrir une
    #: session quand le destinataire est hors ligne, sans attendre.
    signed_prekey = Column(String(64), nullable=False)
    #: Signature Ed25519 de `signed_prekey` par `signing_key`. Sans elle, le
    #: serveur pourrait substituer sa propre pré-clé et lire la conversation :
    #: c'est ce qui rend l'annuaire non fiable par construction.
    signed_prekey_signature = Column(String(128), nullable=False)
    #: Ce que l'application de cet appareil sait chiffrer au-delà du texte —
    #: `media-v1` (pièces jointes), `call-v1` (appels). Un expéditeur ne
    #: chiffre une photo ou un appel que si le destinataire le sait : sinon
    #: il recevrait un bloc qu'il ne sait pas ouvrir. Republiée à chaque
    #: démarrage avec le trousseau, donc à jour dès la mise à jour de l'app.
    capabilities = Column(JSON, nullable=True)
    created_at = Column(DateTime, default=datetime.utcnow, nullable=False)
    updated_at = Column(DateTime, default=datetime.utcnow, nullable=False)

    one_time_prekeys = relationship(
        "OneTimePrekey", cascade="all, delete-orphan", back_populates="bundle"
    )


class OneTimePrekey(Base):
    """Une pré-clé à USAGE UNIQUE, consommée à l'ouverture d'une session.

    Son rôle est étroit et précis : sans elle, deux personnes qui ouvrent une
    session avec le même destinataire hors ligne dériveraient leur secret à
    partir des mêmes éléments, et une session rejouée resterait déchiffrable.
    Consommée une fois, elle rend chaque première poignée de main unique.

    Le serveur les distribue et les raye. Il n'en connaît que la partie
    publique — il ne peut donc pas s'en servir pour déchiffrer quoi que ce
    soit, seulement les épuiser, ce que le client surveille en les
    réapprovisionnant.
    """
    __tablename__ = "one_time_prekeys"
    __table_args__ = (
        UniqueConstraint("bundle_id", "key_id", name="uq_one_time_prekey"),
    )

    id = Column(Integer, primary_key=True, index=True)
    bundle_id = Column(
        Integer, ForeignKey("device_key_bundles.id", ondelete="CASCADE"), nullable=False, index=True
    )
    #: Numéro choisi par le client — c'est lui qu'un message de session cite
    #: pour dire laquelle il a utilisée.
    key_id = Column(Integer, nullable=False)
    public_key = Column(String(64), nullable=False)
    claimed_at = Column(DateTime, nullable=True, index=True)

    bundle = relationship("DeviceKeyBundle", back_populates="one_time_prekeys")
