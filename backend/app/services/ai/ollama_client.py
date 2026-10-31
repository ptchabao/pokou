"""Client HTTP pour l'API Ollama (Gemma et autres modèles locaux)."""

from __future__ import annotations

import json
import logging
import re
from typing import Any, Dict, List, Optional

import httpx

from app.core.config import get_settings

logger = logging.getLogger(__name__)


class OllamaError(Exception):
    """Erreur lors d'un appel à l'API Ollama."""


class OllamaClient:
    @staticmethod
    def _base_url() -> str:
        return get_settings().ollama_base_url.rstrip("/")

    @staticmethod
    async def chat(
        messages: List[Dict[str, str]],
        *,
        model: Optional[str] = None,
        json_mode: bool = True,
        temperature: Optional[float] = None,
    ) -> str:
        settings = get_settings()
        payload: Dict[str, Any] = {
            "model": model or settings.ollama_model,
            "messages": messages,
            "stream": False,
            "options": {
                "temperature": (
                    temperature if temperature is not None else settings.ollama_temperature
                ),
            },
        }
        if json_mode:
            payload["format"] = "json"

        url = f"{OllamaClient._base_url()}/api/chat"
        timeout = httpx.Timeout(settings.ollama_timeout_seconds)

        try:
            async with httpx.AsyncClient(timeout=timeout) as client:
                response = await client.post(url, json=payload)
                response.raise_for_status()
                data = response.json()
        except httpx.TimeoutException as exc:
            raise OllamaError(
                f"Délai dépassé après {settings.ollama_timeout_seconds}s "
                f"(augmentez OLLAMA_TIMEOUT_SECONDS si le modèle est lent au démarrage)"
            ) from exc
        except httpx.HTTPStatusError as exc:
            if exc.response.status_code == 404:
                raise OllamaError(
                    f"Modèle Ollama introuvable ou endpoint indisponible "
                    f"(modèle={payload['model']}, vérifiez OLLAMA_MODEL et `ollama list`)"
                ) from exc
            raise OllamaError(f"Appel Ollama échoué ({url}): {exc}") from exc
        except httpx.HTTPError as exc:
            raise OllamaError(f"Appel Ollama échoué ({url}): {exc}") from exc

        message = data.get("message") or {}
        content = message.get("content")
        if not content or not str(content).strip():
            raise OllamaError("Réponse Ollama vide")
        return str(content).strip()

    @staticmethod
    def parse_json_content(content: str) -> Dict[str, Any]:
        text = content.strip()
        if text.startswith("```"):
            text = re.sub(r"^```(?:json)?\s*", "", text)
            text = re.sub(r"\s*```$", "", text)
        try:
            parsed = json.loads(text)
        except json.JSONDecodeError as exc:
            raise OllamaError(f"JSON invalide renvoyé par le modèle: {exc}") from exc
        if not isinstance(parsed, dict):
            raise OllamaError("Le modèle doit renvoyer un objet JSON")
        return parsed

    @staticmethod
    async def chat_json(
        messages: List[Dict[str, str]],
        **kwargs: Any,
    ) -> Dict[str, Any]:
        content = await OllamaClient.chat(messages, json_mode=True, **kwargs)
        return OllamaClient.parse_json_content(content)

    @staticmethod
    async def health_check() -> bool:
        settings = get_settings()
        if not settings.ollama_enabled:
            return False
        url = f"{OllamaClient._base_url()}/api/tags"
        timeout = httpx.Timeout(min(settings.ollama_timeout_seconds, 10.0))
        try:
            async with httpx.AsyncClient(timeout=timeout) as client:
                response = await client.get(url)
                response.raise_for_status()
                return True
        except httpx.HTTPError:
            logger.warning("Ollama indisponible sur %s", url)
            return False
