"""La preuve qu'un secret ne sort pas par un chemin détourné.

Deux chemins précis, tous deux constatés dans l'audit :

- le CODE DE CONNEXION écrit en clair dans les journaux du serveur, avec le
  numéro sur la même ligne. Quiconque lisait les logs pouvait se connecter à
  n'importe quel compte ;
- le CONTENU des messages envoyé à Firebase puis affiché sur un écran
  verrouillé, ce qui annule la confidentialité pour tout ce qui n'est pas
  chiffré — c'est-à-dire les groupes, les chaînes, et les 1:1 dès que le
  chiffrement échouait.

Ces tests regardent ce qui SORT, pas ce que le code a l'air de faire.
"""
import logging
from unittest.mock import MagicMock, patch

import pytest

from app.models import DirectMessage, MessageType
from app.api.v1.messaging.messages import _push_preview
from app.services.auth import otp_service


class _CapturingHandler(logging.Handler):
    """Retient tout ce qui passe par le journal, message rendu compris."""

    def __init__(self):
        super().__init__(level=logging.DEBUG)
        self.lines: list[str] = []

    def emit(self, record):
        self.lines.append(record.getMessage())


@pytest.fixture
def journal():
    handler = _CapturingHandler()
    root = logging.getLogger()
    previous = root.level
    root.setLevel(logging.DEBUG)
    root.addHandler(handler)
    yield handler
    root.removeHandler(handler)
    root.setLevel(previous)


def test_le_code_de_connexion_n_apparait_jamais_dans_les_journaux(journal):
    # On force un code connu, puis on lit TOUT ce qui a été journalisé.
    # Chercher la chaîne exacte plutôt que la ligne fautive : le jour où
    # quelqu'un la réécrit autrement, ce test doit tomber quand même.
    db = MagicMock()
    db.query.return_value.filter.return_value.count.return_value = 0
    # Aucun essai raté récent, aucun code encore en attente (verrou de 15 min
    # et délai de renvoi de 60 s, voir otp_service).
    db.query.return_value.filter.return_value.all.return_value = []
    db.query.return_value.filter.return_value.order_by.return_value.first.return_value = None

    with patch.object(otp_service.secrets, "randbelow", return_value=424242), \
         patch.object(otp_service.sms_service, "send_sms", return_value=True), \
         patch.object(otp_service, "_send_whatsapp_otp"):
        otp_service.generate_and_send_otp(db, "+22890000000", "sms")

    tout = "\n".join(journal.lines)
    assert "424242" not in tout, f"le code a fui dans les journaux :\n{tout}"


def test_les_journaux_disent_quand_meme_l_essentiel(journal):
    # Supprimer le log n'était pas la bonne correction : il faut encore
    # pouvoir diagnostiquer « je ne reçois rien ». Le numéro et le canal
    # suffisent — c'est le CODE qui n'a rien à faire là.
    db = MagicMock()
    db.query.return_value.filter.return_value.count.return_value = 0
    # Aucun essai raté récent, aucun code encore en attente (verrou de 15 min
    # et délai de renvoi de 60 s, voir otp_service).
    db.query.return_value.filter.return_value.all.return_value = []
    db.query.return_value.filter.return_value.order_by.return_value.first.return_value = None

    with patch.object(otp_service.sms_service, "send_sms", return_value=True), \
         patch.object(otp_service, "_send_whatsapp_otp"):
        otp_service.generate_and_send_otp(db, "+22890000000", "sms")

    tout = "\n".join(journal.lines)
    assert "+22890000000" in tout
    assert "sms" in tout


def _message(**kwargs):
    defaults = dict(
        id="msg-1",
        sender_id=1,
        recipient_id=2,
        message_type=MessageType.TEXT,
        content="Le code du coffre est 4412",
        encryption=None,
    )
    defaults.update(kwargs)
    return DirectMessage(**defaults)


def test_la_notification_ne_porte_jamais_le_texte_du_message():
    # Le défaut exact : un message NON chiffré partait en clair dans le corps
    # de la notification, donc chez Firebase puis sur l'écran verrouillé.
    apercu = _push_preview(_message())

    assert "4412" not in apercu
    assert "coffre" not in apercu.lower()


def test_un_message_chiffre_non_plus():
    apercu = _push_preview(_message(encryption="v1", content=None))

    assert apercu == "Nouveau message"


@pytest.mark.parametrize(
    "type_de_message",
    [m for m in MessageType],
)
def test_aucun_type_de_message_ne_laisse_filtrer_son_contenu(type_de_message):
    # Le type lui-même est une information : « [Audio] » dit qu'on a reçu un
    # vocal, ce qui suffit parfois à en dire trop. Une seule phrase pour
    # tous.
    apercu = _push_preview(_message(message_type=type_de_message))

    assert apercu == "Nouveau message"


def test_la_notification_porte_de_quoi_aller_chercher_le_contenu():
    # Le contenu ne part pas, donc le client doit pouvoir le récupérer
    # lui-même et le déchiffrer localement. Sans identifiant dans le payload,
    # la notification serait un cul-de-sac.
    import inspect

    from app.api.v1.messaging import messages

    source = inspect.getsource(messages._deliver)
    assert '"message_id"' in source


# ── La porte dérobée de revue des stores ──────────────────────────────────


class _Settings:
    """Juste ce que le garde-fou regarde."""

    def __init__(self, environment, numbers="", code=""):
        self.environment = environment
        self.review_phone_numbers = numbers
        self.review_otp_code = code
        self.secret_key = "une-vraie-cle"
        self.webhook_hmac_secret = "un-vrai-secret"


def test_la_porte_derobee_de_revue_empeche_de_demarrer_en_production():
    # REVIEW_PHONE_NUMBERS + REVIEW_OTP_CODE donnent un code de connexion
    # FIXE. Indispensable pour faire publier l'application, et à retirer
    # ensuite — or rien ne le rappelait. La porte se refermait par mémoire,
    # c'est-à-dire jamais.
    from app.main import ensure_no_review_backdoor

    with pytest.raises(RuntimeError, match="REVIEW_PHONE_NUMBERS"):
        ensure_no_review_backdoor(
            _Settings("production", numbers="+22890000000", code="123456")
        )


def test_une_moitie_de_configuration_oubliee_bloque_aussi():
    # `is_review_phone` exige les deux, donc une seule ne suffit pas à ouvrir
    # la porte. Mais la laisser traîner la rouvre au prochain déploiement, et
    # personne ne s'en souviendra.
    from app.main import ensure_no_review_backdoor

    with pytest.raises(RuntimeError, match="REVIEW_OTP_CODE"):
        ensure_no_review_backdoor(_Settings("production", code="123456"))


def test_hors_production_on_avertit_sans_bloquer(journal):
    # Une revue de store se prépare ailleurs qu'en production, et bloquer le
    # développement rendrait le garde-fou insupportable — donc contourné.
    from app.main import ensure_no_review_backdoor

    ensure_no_review_backdoor(
        _Settings("development", numbers="+22890000000", code="123456")
    )

    assert any("REVIEW_PHONE_NUMBERS" in line for line in journal.lines)


def test_une_production_propre_demarre():
    from app.main import ensure_no_review_backdoor

    ensure_no_review_backdoor(_Settings("production"))
