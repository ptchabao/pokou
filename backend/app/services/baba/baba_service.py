"""Baba — l'assistant IA de Pokou.

Baba répond avec les modèles de langage déjà branchés dans l'API (Gemini,
Groq, DeepSeek, Grok, Ollama), essayés dans cet ordre : le premier qui est
configuré ET répond gagne. Si aucun ne répond — pas de clé, panne, quota —
Baba répond quand même, à partir des questions fréquentes de l'aide
(REG-10). Un assistant muet serait pire qu'un assistant modeste.

Ce que reçoit le modèle : une consigne (qui est Baba, ce que fait Pokou,
ce qu'il ne doit jamais faire) et les derniers messages de CE fil. Jamais
les autres discussions de l'utilisateur.
"""
import logging
import unicodedata
from typing import Awaitable, Callable, Dict, List, Optional, Tuple

from app.core.config import get_settings

logger = logging.getLogger(__name__)

SYSTEM_PROMPT = """Tu es Baba, l'assistant de l'application Pokou, une messagerie africaine (Togo, Côte d'Ivoire) avec des services : Kory (cagnottes et tontines), Honam (ordonnances livrées par des pharmacies et des coursiers), Assimé (petites annonces), Pokou certifié (badge de nom vérifié et mode preuve).

Règles :
- Réponds en français simple, en tutoyant, en 1 à 4 phrases courtes. Si l'utilisateur écrit dans une autre langue, réponds dans sa langue.
- Pokou ne touche jamais l'argent : tout se paie de wallet à wallet (Mobile Money).
- Ne demande JAMAIS un code reçu par SMS, un code PIN, un mot de passe ou un paiement. Rappelle que Pokou ne le fait jamais.
- Tu ne lis pas les autres discussions de l'utilisateur, et tu le dis si on te le demande.
- Honam n'est pas un service d'urgence : en cas d'urgence médicale, oriente vers les numéros d'urgence locaux.
- Ne donne aucun conseil médical, juridique ou financier personnalisé.
- Si tu ne sais pas, dis-le et propose « Aide et support » dans Réglages.
"""

#: Repli sans modèle de langage : (mots-clés, réponse).
FAQ: List[Tuple[Tuple[str, ...], str]] = [
    (("argent", "payer", "paiement", "wallet", "mobile money", "touche"),
     "Pokou ne touche jamais ton argent : cagnottes, pharmacies et coursiers se paient de wallet à wallet."),
    (("preuve", "barre", "supprime"),
     "Le mode preuve, activé par un titulaire de Pokou certifié, garde visibles et barrés les messages supprimés ou modifiés. C'est toujours affiché en tête de la discussion."),
    (("sms", "code", "recu", "reçois", "otp"),
     "Vérifie ton numéro et ton réseau, puis attends la fin du compte à rebours pour redemander un code. Pokou ne te demandera jamais ce code."),
    (("pin",),
     "Le code PIN protège ton compte sur un nouveau téléphone. Si tu l'as oublié, touche « Code PIN oublié ? » : après 7 jours, le code SMS suffira."),
    (("coursier", "livrer", "livreur"),
     "Pour devenir coursier Honam, va dans Plus puis « Devenir coursier Honam ». Honam ouvre ville par ville."),
    (("arnaque", "escroc", "fraude", "inconnu", "bloquer"),
     "Méfie-toi de qui demande un code SMS, ton code PIN ou un paiement urgent : Pokou ne le fait jamais. Bloque et signale le contact depuis sa fiche."),
    (("kory", "cagnotte", "tontine"),
     "Kory sert aux cagnottes et tontines : crée-en une depuis un groupe, chacun envoie sa part depuis son wallet et le collecteur confirme."),
    (("honam", "pharmacie", "ordonnance", "medicament"),
     "Avec Honam, tu envoies la photo de ton ordonnance, une pharmacie te fait un devis, tu la paies de wallet à wallet et un coursier livre."),
    (("assime", "annonce", "vendre", "acheter"),
     "Assimé, ce sont les petites annonces près de chez toi : publie une annonce, et les acheteurs t'écrivent dans Discussions."),
    (("certifie", "badge", "verifie"),
     "Pokou certifié affiche un badge de nom vérifié et donne accès au mode preuve. Un mois d'essai est offert."),
    (("numero", "changer de numero", "puce"),
     "Pour changer de numéro, va dans Réglages, Compte et sécurité, puis « Changer de numéro » : ton compte et tes discussions te suivent."),
    (("supprimer", "compte"),
     "Tu peux supprimer ton compte dans Réglages, Compte et sécurité, « Supprimer mon compte ». C'est définitif."),
]

DEFAULT_REPLY = (
    "Je n'ai pas de réponse précise à ça pour l'instant. "
    "Tu peux consulter « Aide et support » dans Réglages, ou reformuler ta question."
)
GREETING_REPLY = (
    "Bonjour ! Moi, c'est Baba, l'assistant de Pokou. "
    "Pose-moi une question sur Pokou, Kory, Honam ou Assimé."
)


def _fold(text: str) -> str:
    text = unicodedata.normalize("NFD", text.lower())
    return "".join(c for c in text if unicodedata.category(c) != "Mn")


def faq_answer(question: str) -> str:
    q = _fold(question)
    if any(word in q.split() for word in ("bonjour", "salut", "bonsoir", "hello", "coucou")) and len(q) < 30:
        return GREETING_REPLY
    best, score = None, 0
    for keywords, answer in FAQ:
        hits = sum(1 for k in keywords if _fold(k) in q)
        if hits > score:
            best, score = answer, hits
    return best or DEFAULT_REPLY


def _providers() -> List[Tuple[str, Callable[[List[Dict[str, str]]], Awaitable[str]]]]:
    """Les fournisseurs configurés, dans l'ordre d'essai."""
    cfg = get_settings()
    chain: List[Tuple[str, Callable[[List[Dict[str, str]]], Awaitable[str]]]] = []
    if cfg.gemini_enabled and cfg.gemini_api_key:
        from app.services.ai.gemini_client import GeminiClient

        chain.append(("gemini", lambda m: GeminiClient.chat(m, json_mode=False, temperature=0.4)))
    if cfg.groq_enabled and cfg.groq_api_key:
        from app.services.ai.groq_client import GroqClient

        chain.append(("groq", lambda m: GroqClient.chat(m, temperature=0.4)))
    if cfg.deepseek_enabled and cfg.deepseek_api_key:
        from app.services.ai.deepseek_client import DeepSeekClient

        chain.append(("deepseek", lambda m: DeepSeekClient.chat(m, temperature=0.4)))
    if cfg.grok_enabled and cfg.grok_api_key:
        from app.services.ai.grok_client import GrokClient

        chain.append(("grok", lambda m: GrokClient.chat(m, temperature=0.4)))
    # Ollama n'a pas de clé : il ne compte que si une adresse a été donnée,
    # sinon chaque message attendrait un localhost qui n'existe pas en prod.
    if cfg.ollama_enabled and "localhost" not in cfg.ollama_base_url and "127.0.0.1" not in cfg.ollama_base_url:
        from app.services.ai.ollama_client import OllamaClient

        chain.append(("ollama", lambda m: OllamaClient.chat(m, json_mode=False, temperature=0.4)))
    return chain


def configured_providers() -> List[str]:
    return [name for name, _ in _providers()]


async def reply(history: List[Tuple[str, str]], question: str) -> Tuple[str, str]:
    """Répond à `question`. `history` : les derniers (direction, texte) du fil.

    Renvoie (réponse, fournisseur)."""
    messages: List[Dict[str, str]] = [{"role": "system", "content": SYSTEM_PROMPT}]
    for direction, body in history[-10:]:
        messages.append({"role": "user" if direction == "in" else "assistant", "content": body[:2000]})
    messages.append({"role": "user", "content": question[:2000]})

    for name, chat in _providers():
        try:
            text: Optional[str] = await chat(messages)
        except Exception:  # noqa: BLE001 — on passe au suivant
            logger.warning("Baba : %s n'a pas répondu", name, exc_info=True)
            continue
        text = (text or "").strip()
        if text:
            return text[:4000], name
    return faq_answer(question), "faq"
