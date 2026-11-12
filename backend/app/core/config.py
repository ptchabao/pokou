from functools import lru_cache
from pydantic_settings import BaseSettings, SettingsConfigDict

# Known weak defaults — app/core/startup_checks.py's startup guard refuses to boot in
# production if either is still in effect (see ensure_no_weak_secrets).
WEAK_DEFAULT_SECRET_KEY = "your-super-secret-key-change-in-production"
WEAK_DEFAULT_WEBHOOK_HMAC_SECRET = "your-webhook-hmac-secret"


class Settings(BaseSettings):
    # Database
    database_url: str = "sqlite:///./pokou.db"

    # Redis
    redis_url: str = "redis://localhost:6379/0"  # Optional for development

    # ── Pool de connexions PostgreSQL ────────────────────────────────────
    # Explicites plutôt que laissés aux défauts de SQLAlchemy : le calcul
    # `instances × workers × (pool_size + max_overflow)` doit pouvoir se
    # faire sans lire le code de la bibliothèque. Voir app/database.py.
    db_pool_size: int = 10
    db_max_overflow: int = 10
    # Court et explicite : sans lui, une saturation se manifeste par un gel
    # plutôt que par une erreur, et un gel ne se diagnostique pas.
    db_pool_timeout: int = 10
    # Même raison pour l'OUVERTURE d'une connexion. Sans délai, un hôte qui ne
    # répond pas (pare-feu qui jette les paquets au lieu de refuser, adresse
    # morte) laisse la migration suspendue : ni erreur, ni traceback, ni
    # redémarrage — la panne la plus longue à diagnostiquer de toutes.
    db_connect_timeout: int = 10

    # Security
    secret_key: str = WEAK_DEFAULT_SECRET_KEY
    algorithm: str = "HS256"
    access_token_expire_minutes: int = 30
    # ── La session ne périme plus d'elle-même ────────────────────────────
    #
    # Sept jours, c'est-à-dire : partir une semaine sans ouvrir Pokou, et
    # devoir refaire un SMS au retour. Un second téléphone, un voyage, une
    # hospitalisation suffisaient. Aucune messagerie ne demande ça.
    #
    # La rotation prolongeait bien l'échéance à chaque passage, mais elle ne
    # sert qu'à ceux qui ouvrent l'application. Ceux qui ne l'ouvrent pas
    # sont précisément ceux qu'on déconnectait.
    #
    # Dix ans revient à « jusqu'à révocation ». C'est le modèle des
    # messageries grand public, et il n'est acceptable QUE parce que la
    # révocation fonctionne vraiment :
    #
    # - chaque rafraîchissement échange le jeton et révoque l'ancien, donc
    #   un jeton volé cesse de servir dès que le vrai client se rafraîchit ;
    #   un rejeu hors fenêtre de grâce est refusé et journalisé ;
    # - « révoquer cet appareil » coupe la session (routes/devices.py), et
    #   depuis la rotation reporte `session_jti`, il coupe la BONNE ;
    # - la déconnexion révoque toutes les sessions du compte.
    #
    # Retirer l'une de ces trois garanties reviendrait à rendre cette durée
    # dangereuse. Elles se tiennent, et se lisent ensemble.
    refresh_token_expire_days: int = 3650

    # Webhook Security
    webhook_hmac_secret: str = WEAK_DEFAULT_WEBHOOK_HMAC_SECRET

    # WhatsApp gateway shared secret (see whatsapp/server.js — the gateway
    # rejects every request unless it carries this value in X-Gateway-Secret)
    whatsapp_gateway_secret: str = ""

    # Pokou — pièces jointes (notes vocales/documents/images/vidéos).
    # `media_storage_dir` reste le stockage de repli quand le stockage objet
    # n'est pas configuré (tests, poste de dev) et sert à relire les fichiers
    # déposés avant la bascule — voir media_assets.storage_backend.
    media_storage_dir: str = "./media_storage"
    media_max_size_mb: int = 25

    # Stockage objet S3-compatible (MinIO) pour ces pièces jointes. Activé
    # dès que endpoint + clés sont renseignés (voir object_storage.is_enabled)
    # — les valeurs vivent dans .env, jamais dans le code.
    s3_endpoint_url: str = ""
    s3_access_key: str = ""
    s3_secret_key: str = ""
    s3_bucket: str = "pokou-media"
    # MinIO ignore la région mais la signature v4 en exige une.
    s3_region: str = "us-east-1"

    # Pokou — appels audio/vidéo/de groupe via LiveKit Cloud (managé, rien à
    # héberger). Désactivé par défaut : nécessite un compte LiveKit Cloud et
    # ses clés, provisionnés par l'utilisateur (voir /calls/token).
    livekit_enabled: bool = False
    livekit_api_key: str = ""
    livekit_api_secret: str = ""
    livekit_url: str = ""  # ex. wss://<projet>.livekit.cloud — utilisé par le client mobile
    # Durée d'un jeton d'accès LiveKit. Il ne sert qu'à ENTRER dans la salle :
    # une fois connecté, le serveur LiveKit pousse lui-même des jetons
    # renouvelés au client (livekit_client les reprend pour se reconnecter),
    # donc une durée courte ne coupe pas un appel long. La bibliothèque met
    # six heures par défaut : de quoi rejoindre une salle bien après l'appel.
    livekit_token_ttl_minutes: int = 15
    # Au-delà, un groupe ne peut pas lancer d'appel qui fait sonner tout le
    # monde : chaque sonnerie coûte des écritures et un push dans la requête
    # même, et un très gros groupe faisait expirer l'appel côté client (20 s).
    # Limite PRUDENTE, à relever une fois la charge mesurée.
    call_max_group_ring: int = 32

    # Pokou — notifications push (Firebase Cloud Messaging), pour les
    # messages/appels reçus pendant que l'app est fermée/en arrière-plan (le
    # WebSocket ne fonctionne que tant qu'elle est ouverte). Désactivé par
    # défaut : nécessite un projet Firebase et sa clé de compte de service
    # (Project Settings → Service Accounts → Generate new private key).
    fcm_enabled: bool = False
    firebase_credentials_path: str = ""
    firebase_credentials_json: str = ""

    # ── Comptes de démonstration pour la revue des stores ────────────────────
    # Google Play (et l'App Store) exigent des identifiants de test quand
    # l'application est derrière une connexion. Pokou n'a pas de mot de passe :
    # on n'entre qu'avec un code SMS — et un relecteur à Mountain View ne peut
    # pas recevoir le SMS d'un numéro togolais. Ces deux réglages permettent
    # de désigner un numéro dont le code est FIXE et n'est pas envoyé par SMS.
    #
    # C'est une porte dérobée dans l'authentification, assumée comme telle et
    # tenue aussi étroite que possible :
    # - VIDE PAR DÉFAUT : sans configuration explicite, le flux normal
    #   s'applique à tout le monde, sans exception ;
    # - correspondance EXACTE sur des numéros listés un par un, jamais un
    #   motif ni un préfixe ;
    # - tout le reste du flux est inchangé (expiration 5 min, 5 essais max,
    #   3 demandes par 15 min, code à usage unique) : la seule différence est
    #   que le code est connu d'avance et qu'aucun SMS ne part ;
    # - chaque usage est journalisé en WARNING, pour que ça se voie ;
    # - la portée du risque est UN compte vide : connaître ce code ne donne
    #   accès à aucune donnée d'un autre utilisateur.
    #
    # À retirer de l'environnement dès la revue passée, ou à faire tourner.
    review_phone_numbers: str = ""
    review_otp_code: str = ""

    # CORS
    allowed_origins: list[str] = ["http://localhost:3000", "http://localhost:3001", "http://localhost:8000"]

    # TrustedHostMiddleware — "*" (no-op) by default for local dev;
    # override in production via ALLOWED_HOSTS (comma/JSON list env var).
    allowed_hosts: list[str] = ["*"]

    # Adresse publique de cette API, telle que la joignent les tiers : sert à
    # construire les URL de rappel des paiements (voir semoa_client).
    public_api_url: str = "https://api.pok.app"

    # Domaine public des invitations et liens profonds, servi par l'API.
    public_link_base_url: str = "https://apipokou.cabinet-p-et-associes.com"

    # API Configuration
    debug: bool = True
    log_level: str = "INFO"
    environment: str = "development"
    
    # ── Modèles de langage du Mode Bouclier ─────────────────────────────
    # Essayés dans cet ordre, le premier qui répond l'emporte (voir
    # services/privacy/shield_service.py). Ollama est local ; les autres sont
    # des secours cloud, inactifs tant qu'aucune clé n'est fournie.
    ollama_enabled: bool = True
    ollama_base_url: str = "http://localhost:11434"
    ollama_model: str = "gemma2"
    ollama_timeout_seconds: float = 180.0
    ollama_temperature: float = 0.1

    # Gemini API (fallback cloud si Ollama indisponible)
    gemini_enabled: bool = False
    gemini_api_key: str = ""
    # gemini-2.0-flash a été retiré par Google : chaque appel répondait 404
    # « no longer available », et Gemini était donc mort en production sans
    # que rien d'autre qu'un WARNING ne le signale.
    gemini_model: str = "gemini-3.6-flash"
    gemini_timeout_seconds: float = 60.0
    gemini_temperature: float = 0.1

    # DeepSeek API (fallback cloud supplémentaire)
    deepseek_enabled: bool = False
    deepseek_api_key: str = ""
    deepseek_model: str = "deepseek-chat"
    deepseek_timeout_seconds: float = 60.0
    deepseek_temperature: float = 0.1

    # Grok / xAI API (fallback cloud supplémentaire)
    grok_enabled: bool = False
    grok_api_key: str = ""
    grok_model: str = "grok-3-mini-fast"
    grok_timeout_seconds: float = 60.0
    grok_temperature: float = 0.1

    # Groq API (fallback cloud supplémentaire)
    groq_enabled: bool = False
    groq_api_key: str = ""
    # llama-3.3-70b-versatile n'existe plus côté Groq : chaque appel partait
    # en 404 puis retombait sur openai/gpt-oss-120b, qui répond. Autant
    # demander directement celui qui marche — le 404 systématique ajoutait un
    # aller-retour à CHAQUE évaluation du Mode Bouclier.
    groq_model: str = "openai/gpt-oss-120b"
    groq_timeout_seconds: float = 60.0
    groq_temperature: float = 0.1

    # Passerelle WhatsApp (second canal des codes de connexion)
    whatsapp_service_url: str = "http://localhost:4000"
    whatsapp_service_timeout_seconds: float = 30.0

    # Twilio : canal principal des SMS de code (voir sms_service), et
    # WhatsApp en option. Identifiants dans le .env, jamais dans le code.
    twilio_account_sid: str = ""
    twilio_auth_token: str = ""
    #: Expéditeur des SMS : un numéro Twilio (« +1415… ») ou un identifiant
    #: alphanumérique (« POKOU ») là où le pays l'accepte.
    twilio_sms_from: str = ""
    #: Ou un service de messagerie Twilio, qui choisit l'expéditeur par pays.
    twilio_messaging_service_sid: str = ""
    twilio_whatsapp_from: str = ""  # E.g. "whatsapp:+1415..."
    #: Twilio Verify pour les codes de connexion (services/auth/twilio_verify).
    #: Actif dès que le compte Twilio est configuré ; le service est retrouvé
    #: ou créé automatiquement si son SID n'est pas donné.
    twilio_verify_enabled: bool = True
    twilio_verify_service_sid: str = ""

    # Passerelle SMS NGH (canal principal des codes de connexion)
    ngh_api_key: str = ""
    ngh_api_secret: str = ""
    # Identifiant d'expéditeur affiché sur les SMS. Il doit être DÉCLARÉ chez
    # l'opérateur avant usage : un identifiant inconnu fait refuser l'envoi.
    sms_sender_id: str = "POKOU"

    # ── Kafka : le journal des évènements métier ─────────────────────────
    # Vide par défaut : sans Kafka, les évènements s'écrivent quand même
    # dans la table `outbox_events` (même transaction que la donnée), et le
    # relais (`python -m app.workers.outbox_relay`) ne démarre pas. Brancher
    # Kafka plus tard ne perd donc rien de ce qui s'est passé avant.
    kafka_bootstrap_servers: str = ""
    kafka_security_protocol: str = "PLAINTEXT"  # PLAINTEXT|SSL|SASL_SSL
    kafka_sasl_mechanism: str = ""  # SCRAM-SHA-512 avec Strimzi
    kafka_sasl_username: str = ""
    kafka_sasl_password: str = ""
    kafka_ssl_cafile: str = ""
    #: Le certificat de l'autorité Kafka EN CLAIR (PEM), pour les
    #: plateformes qui ne montent pas de fichier depuis un Secret (Kubero).
    #: Prioritaire sur `kafka_ssl_cafile`.
    kafka_ssl_ca_pem: str = ""
    kafka_topic_prefix: str = "pokou"
    #: Durée de conservation des lignes déjà publiées, en jours.
    outbox_retention_days: int = 7

    model_config = SettingsConfigDict(
        env_file=".env",
        case_sensitive=False,
        extra="allow",
    )


@lru_cache()
def get_settings() -> Settings:
    return Settings()
