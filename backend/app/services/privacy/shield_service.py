"""Pokou — Mode Bouclier (Shield Mode). Filtre les appels/messages entrants
pendant une conversation "sérieuse" pour ne pas déranger l'utilisateur avec
du bruit (voir le cahier des charges Shield Mode).

Confidentialité : le texte reçu ici est censé être déjà anonymisé côté
client (entités nommées remplacées par des balises génériques) avant
l'envoi — voir mobile/lib/features/shield/data/local_redaction.dart. Rien
n'est journalisé ni persisté ici : tout est traité en mémoire pour la
durée de la requête et disparaît avec elle.

L'étape 3 (matrice de décision, evaluate_event) est délibérément
déterministe plutôt que confiée à un LLM — la grille du cahier des charges
est une suite de règles fixes (mots-clés, tags de contact, taille de
groupe), pas un jugement qui bénéficierait d'un modèle de langage, et ça
évite tout risque de dépasser la cible de <500ms ou d'envoyer du texte à
un fournisseur cloud pour une décision qui n'en a pas besoin."""
import logging
from typing import Any, Dict, List, Optional

from app.core.config import get_settings
from app.services.ai.deepseek_client import DeepSeekClient
from app.services.ai.gemini_client import GeminiClient
from app.services.ai.grok_client import GrokClient
from app.services.ai.groq_client import GroqClient
from app.services.ai.ollama_client import OllamaClient

logger = logging.getLogger(__name__)

PRIORITY_TAGS = {"BUSINESS", "FOURNISSEUR", "CLIENT", "BOSS"}

_WHITELIST_KEYWORDS = (
    "URGENT", "ACCIDENT", "INCENDIE", "HOPITAL", "HÔPITAL", "POLICE", "DANGER", "SOS", "SECOURS",
)

# Edge case #2 du cahier des charges : au-delà de ce nombre de messages par
# minute, on force un ALLOW — quelqu'un qui spamme autant a probablement
# besoin d'attention immédiate, même hors contexte business.
_SPAM_MESSAGE_COUNT_THRESHOLD = 10

# Edge case du cahier des charges : pas d'urgence individuelle dans un grand groupe.
_GROUP_SIZE_DEFER_THRESHOLD = 20

_CONTEXT_ACTIVATION_THRESHOLD = 7


async def _call_llm_json(messages: List[Dict[str, str]]) -> Optional[Dict[str, Any]]:
    cfg = get_settings()
    for provider_name, enabled, has_key, chat_fn in [
        ("ollama", cfg.ollama_enabled, True, lambda m: OllamaClient.chat_json(m)),
        ("gemini", cfg.gemini_enabled, bool(cfg.gemini_api_key), lambda m: GeminiClient.chat_json(m)),
        ("deepseek", cfg.deepseek_enabled, bool(cfg.deepseek_api_key), lambda m: DeepSeekClient.chat_json(m)),
        ("grok", cfg.grok_enabled, bool(cfg.grok_api_key), lambda m: GrokClient.chat_json(m)),
        ("groq", cfg.groq_enabled, bool(cfg.groq_api_key), lambda m: GroqClient.chat_json(m)),
    ]:
        if not (enabled and has_key):
            continue
        try:
            data = await chat_fn(messages)
            if isinstance(data, dict):
                return data
        except Exception as exc:
            logger.warning("[SHIELD] Fournisseur %s indisponible : %s", provider_name, exc)
    return None


async def evaluate_context(recent_messages: List[str]) -> int:
    """Étape 1 — score de focus (1-10) à partir des derniers messages déjà
    anonymisés de la conversation active. Si aucun fournisseur LLM ne
    répond, on renvoie 1 (bouclier non activé) plutôt que 10 : en cas de
    doute, la conception privilégie ne pas déranger à tort plutôt que
    risquer de mettre en attente un message important par erreur (même
    philosophie que le failsafe ALLOW de l'étape 3)."""
    if not recent_messages:
        return 1

    messages = [
        {
            "role": "system",
            "content": (
                "Tu évalues si une conversation est \"sérieuse\" (business, négociation, "
                "urgence, problème technique) ou \"normale\" (famille, amis, anodine), à "
                "partir de messages déjà anonymisés (noms/montants/lieux remplacés par des "
                "balises génériques comme [NOM]/[MONTANT]/[LIEU]). Réponds uniquement en "
                "JSON strict : {\"focus_score\": <entier de 1 à 10>}. 1-6 = normale. "
                "7-10 = critique."
            ),
        },
        {"role": "user", "content": "\n".join(recent_messages[-5:])},
    ]

    data = await _call_llm_json(messages)
    if not data:
        return 1

    try:
        score = int(data.get("focus_score", 1))
    except (TypeError, ValueError):
        return 1
    return max(1, min(10, score))


def evaluate_event(
    *,
    context_score: int,
    event_type: str,
    sender_tag: Optional[str],
    hashed_text: Optional[str],
    sender_known: bool,
    group_size: Optional[int],
    sender_message_count_last_minute: Optional[int],
) -> str:
    """Étape 3 — matrice de décision. Retourne "ALLOW" ou "DEFER"."""
    if context_score < _CONTEXT_ACTIVATION_THRESHOLD:
        return "ALLOW"

    text_upper = (hashed_text or "").upper()
    if any(keyword in text_upper for keyword in _WHITELIST_KEYWORDS):
        return "ALLOW"

    if sender_tag and sender_tag.upper() in PRIORITY_TAGS:
        return "ALLOW"

    if sender_message_count_last_minute is not None and sender_message_count_last_minute > _SPAM_MESSAGE_COUNT_THRESHOLD:
        return "ALLOW"

    if event_type == "call" and not sender_known:
        return "DEFER"

    if group_size is not None and group_size > _GROUP_SIZE_DEFER_THRESHOLD:
        return "DEFER"

    return "DEFER"
