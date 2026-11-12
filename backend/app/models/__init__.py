"""Modèles SQLAlchemy de Pokou, découpés par domaine.

Tout est réexporté ici : `from app.models import User, Group` suffit, et
l'import de ce package enregistre toutes les tables sur `Base.metadata`.
"""
from app.models.user import (  # noqa: F401
    UserRole,
    PrivacyAudience,
    User,
)
from app.models.auth import (  # noqa: F401
    Token,
    WSTicket,
    ActionToken,
    PhoneOTP,
    DeviceToken,
    DeviceKeyBundle,
    OneTimePrekey,
)
from app.models.settings import (  # noqa: F401
    SystemSetting,
)
from app.models.audit import (  # noqa: F401
    AuditLog,
)
from app.models.contacts import (  # noqa: F401
    Contact,
)
from app.models.media import (  # noqa: F401
    MediaAsset,
)
from app.models.messaging import (  # noqa: F401
    MessageType,
    MessageStatus,
    DirectMessage,
    MessageReaction,
    BroadcastList,
    BroadcastListMember,
    BroadcastMessage,
    DirectProofMode,
)
from app.models.groups import (  # noqa: F401
    Group,
    GroupInvitationStatus,
    GroupInvitation,
    GroupJoinRequest,
    GroupMember,
    Poll,
    PollOption,
    PollVote,
    GroupMessageReaction,
    GroupMessageMention,
    GroupMessage,
    GroupSenderKeyDistribution,
)
from app.models.communities import (  # noqa: F401
    Community,
    CommunityMember,
    Channel,
    ChannelMember,
    ChannelPost,
    ChannelPostReaction,
    ChannelPostView,
    ChannelCertificationApplication,
)
from app.models.status import (  # noqa: F401
    StatusContentType,
    Status,
    StatusPrivacy,
    StatusPrivacyEntry,
    StatusView,
    StatusRecipient,
)
from app.models.calls import (  # noqa: F401
    CallLog,
    CallParticipant,
)
from app.models.stickers import (  # noqa: F401
    StickerPack,
    Sticker,
    UserStickerPack,
    StickerFavorite,
    StickerRecent,
)
from app.models.marketplace import (  # noqa: F401
    MarketplaceProduct,
    MarketplaceProductImage,
    SellerReview,
    MarketplacePayment,
    MarketplaceBoost,
    MarketplaceAd,
    SellerVerificationApplication,
    MarketplaceFavorite,
    MarketplaceAlert,
)
from app.models.modules import (  # noqa: F401
    AppModule,
    UserModuleActivation,
    HeartLeagueProfile,
    HeartLeaguePass,
    ConversationStreak,
    TruthQuestion,
    CeremonyFund,
    CeremonyContribution,
    VipRoom,
    VipSubscription,
    VipPost,
    HypeTrain,
    HypeContribution,
)
from app.models.spark import (  # noqa: F401
    SparkProfile,
    SparkPhoto,
    SparkIntent,
    SparkLike,
    SparkPass,
    SparkMatch,
    SparkRoomMessage,
    SparkWingmanVote,
    SparkDatePack,
    SparkDate,
    SparkSafetyContact,
    SparkSafetyAlert,
    SparkCheckin,
)
from app.models.business import (  # noqa: F401
    BusinessOrganization,
    BusinessMember,
    Bot,
    BotApiKey,
    BusinessTestNumber,
    LedgerEntry,
    BotUsage,
    Invoice,
    WebhookDelivery,
)
from app.models.sync import (  # noqa: F401
    SyncEvent,
)
from app.models.kory import (  # noqa: F401
    KoryPot,
    KoryMember,
    KoryEntry,
    KoryRound,
    KoryInvite,
)
from app.models.events import (  # noqa: F401
    OutboxEvent,
)
from app.models.certified import (  # noqa: F401
    CertifiedSubscription,
    CertifiedProApplication,
)
from app.models.honam import (  # noqa: F401
    Pharmacy,
    PharmacyStaff,
    HonamOrder,
    HonamOrderEvent,
    HonamOrderMessage,
    CourierProfile,
    CourierLedgerEntry,
    PharmacyCourier,
    HonamWaitlistEntry,
)
from app.models.baba import (  # noqa: F401
    BabaMessage,
)
from app.models.e2ee_retry import (  # noqa: F401
    E2EERetry,
)
from app.models.service_notifications import (  # noqa: F401
    ServiceNotification,
)
from app.models.backups import (  # noqa: F401
    UserBackup,
)
from app.models.moderation import (  # noqa: F401
    AbuseReport,
)
from app.models.banners import (  # noqa: F401
    HomeBanner,
)
