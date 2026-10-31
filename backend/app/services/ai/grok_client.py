import json
import logging
from typing import Any, Dict, List, Optional

import httpx

from app.core.config import get_settings

logger = logging.getLogger(__name__)


class GrokError(Exception):
    """Erreur lors d'un appel à l'API Grok (xAI)."""


class GrokClient:
    """Client minimaliste pour l'API Grok (xAI), compatible OpenAI."""

    BASE_URL = "https://api.x.ai/v1"

    @staticmethod
    def _get_headers() -> Dict[str, str]:
        settings = get_settings()
        if not settings.grok_api_key:
            raise GrokError("GROK_API_KEY non configurée")
        return {
            "Authorization": f"Bearer {settings.grok_api_key}",
            "Content-Type": "application/json",
        }

    @staticmethod
    async def chat(
        messages: List[Dict[str, Any]],
        model: Optional[str] = None,
        temperature: Optional[float] = None,
        timeout: Optional[float] = None,
    ) -> str:
        settings = get_settings()
        target_model = model or settings.grok_model
        target_temperature = temperature if temperature is not None else settings.grok_temperature
        target_timeout = timeout if timeout is not None else settings.grok_timeout_seconds

        try:
            async with httpx.AsyncClient(timeout=target_timeout) as client:
                response = await client.post(
                    f"{GrokClient.BASE_URL}/chat/completions",
                    headers=GrokClient._get_headers(),
                    json={
                        "model": target_model,
                        "messages": messages,
                        "temperature": target_temperature,
                    },
                )
                response.raise_for_status()
                payload = response.json()

            choices = payload.get("choices") or []
            if not choices or not choices[0].get("message", {}).get("content"):
                raise GrokError("Réponse Grok vide")

            return str(choices[0]["message"]["content"]).strip()
        except httpx.HTTPStatusError as exc:
            detail = exc.response.text if exc.response else str(exc)
            raise GrokError(f"Appel Grok échoué ({exc.response.status_code if exc.response else 'HTTP'}): {detail}") from exc
        except GrokError:
            raise
        except Exception as exc:
            raise GrokError(f"Appel Grok échoué: {exc}") from exc

    @staticmethod
    async def chat_json(
        messages: List[Dict[str, Any]],
        model: Optional[str] = None,
        temperature: Optional[float] = None,
        timeout: Optional[float] = None,
    ) -> Dict[str, Any]:
        raw = await GrokClient.chat(messages, model=model, temperature=temperature, timeout=timeout)
        try:
            data = json.loads(raw)
        except json.JSONDecodeError as exc:
            raise GrokError(f"JSON invalide renvoyé par Grok: {exc}") from exc
        if not isinstance(data, dict):
            raise GrokError("Grok doit renvoyer un objet JSON")
        return data

    @staticmethod
    async def is_available() -> bool:
        settings = get_settings()
        if not settings.grok_enabled or not settings.grok_api_key:
            return False
        try:
            await GrokClient.chat([
                {"role": "system", "content": "ping"},
                {"role": "user", "content": "ping"},
            ], model=settings.grok_model, timeout=10)
            return True
        except Exception as exc:
            logger.warning("Grok API indisponible: %s", exc)
            return False
