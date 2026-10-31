"""Client pour l'API Gemini (fallback cloud quand Ollama est indisponible)."""

from __future__ import annotations

import json
import logging
import re
from typing import Any, Dict, List, Optional

from google import genai
from google.genai import types

from app.core.config import get_settings

logger = logging.getLogger(__name__)


class GeminiError(Exception):
    """Erreur lors d'un appel à l'API Gemini."""


class GeminiClient:
    """Client minimaliste pour l'API Gemini, calqué sur l'interface OllamaClient."""

    _client_instance: Optional[genai.Client] = None

    @classmethod
    def _get_client(cls) -> genai.Client:
        """Instancie un client genai (lazy singleton)."""
        if cls._client_instance is None:
            settings = get_settings()
            if not settings.gemini_api_key:
                raise GeminiError("GEMINI_API_KEY non configurée")
            cls._client_instance = genai.Client(api_key=settings.gemini_api_key)
        return cls._client_instance

    @staticmethod
    async def chat(
        messages: List[Dict[str, str]],
        *,
        model: Optional[str] = None,
        json_mode: bool = True,
        temperature: Optional[float] = None,
    ) -> str:
        """Appel synchrone au SDK google-genai (wrappé pour l'interface async)."""
        settings = get_settings()
        client = GeminiClient._get_client()

        target_model = model or settings.gemini_model
        temp = temperature if temperature is not None else settings.gemini_temperature

        # Construire le contenu pour Gemini à partir des messages Ollama-style
        system_instruction = None
        contents: List[types.Content] = []

        for msg in messages:
            role = msg.get("role", "user")
            text = msg.get("content", "")
            if role == "system":
                system_instruction = text
            else:
                gemini_role = "model" if role == "assistant" else "user"
                contents.append(
                    types.Content(
                        role=gemini_role,
                        parts=[types.Part.from_text(text=text)],
                    )
                )

        # Configuration de génération
        gen_config = types.GenerateContentConfig(
            temperature=temp,
            system_instruction=system_instruction,
        )
        if json_mode:
            gen_config.response_mime_type = "application/json"

        try:
            response = client.models.generate_content(
                model=target_model,
                contents=contents,
                config=gen_config,
            )
        except Exception as exc:
            raise GeminiError(f"Appel Gemini échoué: {exc}") from exc

        content = response.text
        if not content or not content.strip():
            raise GeminiError("Réponse Gemini vide")
        return content.strip()

    @staticmethod
    def parse_json_content(content: str) -> Dict[str, Any]:
        text = content.strip()
        if text.startswith("```"):
            text = re.sub(r"^```(?:json)?\s*", "", text)
            text = re.sub(r"\s*```$", "", text)
        try:
            parsed = json.loads(text)
        except json.JSONDecodeError as exc:
            raise GeminiError(f"JSON invalide renvoyé par Gemini: {exc}") from exc
        if not isinstance(parsed, dict):
            raise GeminiError("Gemini doit renvoyer un objet JSON")
        return parsed

    @staticmethod
    async def chat_json(
        messages: List[Dict[str, str]],
        **kwargs: Any,
    ) -> Dict[str, Any]:
        content = await GeminiClient.chat(messages, json_mode=True, **kwargs)
        return GeminiClient.parse_json_content(content)

    @staticmethod
    async def health_check() -> bool:
        """Vérifie que l'API Gemini est joignable."""
        settings = get_settings()
        if not settings.gemini_enabled or not settings.gemini_api_key:
            return False
        try:
            client = GeminiClient._get_client()
            # Appel léger pour vérifier l'accès
            client.models.get(model=settings.gemini_model)
            return True
        except Exception:
            logger.warning("Gemini API indisponible")
            return False
