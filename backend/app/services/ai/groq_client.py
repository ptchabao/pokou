import asyncio
import json
import logging
import re
from typing import Any, Dict, List, Optional

import httpx

from app.core.config import get_settings

logger = logging.getLogger(__name__)


class GroqError(Exception):
    """Erreur lors d'un appel à l'API Groq."""


class GroqClient:
    """Client Groq compatible OpenAI avec fallback et retry."""

    BASE_URL = "https://api.groq.com/openai/v1"

    FALLBACK_MODELS = [
        "openai/gpt-oss-120b",
        "qwen/qwen3-32b",
        "llama-3.1-8b-instant",
    ]


    @staticmethod
    def _get_headers() -> Dict[str, str]:

        settings = get_settings()

        if not settings.groq_api_key:
            raise GroqError(
                "GROQ_API_KEY non configurée"
            )

        return {
            "Authorization": f"Bearer {settings.groq_api_key}",
            "Content-Type": "application/json",
        }



    @staticmethod
    def _get_models(
        model: Optional[str] = None
    ) -> List[str]:

        settings = get_settings()

        models = []

        if model:
            models.append(model)

        elif getattr(settings, "groq_model", None):
            models.append(settings.groq_model)


        for fallback in GroqClient.FALLBACK_MODELS:

            if fallback not in models:
                models.append(fallback)


        return models



    @staticmethod
    async def chat(
        messages: List[Dict[str, Any]],
        model: Optional[str] = None,
        temperature: Optional[float] = None,
        timeout: Optional[float] = None,
    ) -> str:


        settings = get_settings()


        target_temperature = (
            temperature
            if temperature is not None
            else settings.groq_temperature
        )


        target_timeout = (
            timeout
            if timeout is not None
            else settings.groq_timeout_seconds
        )


        models = GroqClient._get_models(model)


        last_error = None


        async with httpx.AsyncClient(
            timeout=target_timeout
        ) as client:


            for model_name in models:


                for attempt in range(3):

                    try:

                        logger.info(
                            "Appel Groq modèle=%s tentative=%s",
                            model_name,
                            attempt + 1
                        )


                        response = await client.post(

                            f"{GroqClient.BASE_URL}/chat/completions",

                            headers=GroqClient._get_headers(),

                            json={

                                "model": model_name,

                                "messages": messages,

                                "temperature": target_temperature,

                            },
                        )


                        response.raise_for_status()


                        payload = response.json()


                        content = (
                            payload
                            .get("choices", [{}])[0]
                            .get("message", {})
                            .get("content")
                        )


                        if not content:

                            raise GroqError(
                                "Réponse Groq vide"
                            )


                        return str(content).strip()



                    except httpx.HTTPStatusError as exc:


                        last_error = exc


                        status = exc.response.status_code


                        logger.warning(

                            "Groq erreur %s : %s",

                            status,

                            exc.response.text

                        )


                        if status in [
                            429,
                            500,
                            502,
                            503,
                            504
                        ]:

                            await asyncio.sleep(
                                2 ** attempt
                            )

                            continue


                        break



                    except Exception as exc:


                        last_error = exc


                        logger.warning(

                            "Erreur modèle %s : %s",

                            model_name,

                            exc

                        )


                        break



        raise GroqError(
            f"Tous les modèles Groq ont échoué : {last_error}"
        )




    @staticmethod
    async def chat_json(
        messages: List[Dict[str, Any]],
        model: Optional[str] = None,
        temperature: Optional[float] = None,
        timeout: Optional[float] = None,
    ) -> Dict[str, Any]:


        json_prompt = {

            "role": "system",

            "content": """
Tu dois répondre uniquement en JSON valide.

Format obligatoire :

{
  "response": "ta réponse utilisateur ici"
}

Ne mets aucun texte avant ou après le JSON.
"""
        }


        final_messages = [
            json_prompt,
            *messages
        ]


        raw = await GroqClient.chat(
            final_messages,
            model=model,
            temperature=temperature,
            timeout=timeout,
        )


        logger.info(
            "Réponse brute Groq JSON: %s",
            raw
        )


        # Nettoyage markdown éventuel

        raw = re.sub(
            r"```json|```",
            "",
            raw
        ).strip()



        try:

            data = json.loads(raw)


        except json.JSONDecodeError as exc:


            logger.error(

                "JSON Groq invalide : %s | %s",

                exc,

                raw

            )


            raise GroqError(
                "Groq a retourné un JSON invalide"
            ) from exc



        if not isinstance(data, dict):

            raise GroqError(
                "La réponse Groq doit être un objet JSON"
            )



        return data





    @staticmethod
    async def is_available() -> bool:


        settings = get_settings()


        if (
            not settings.groq_enabled
            or not settings.groq_api_key
        ):

            return False



        try:


            async with httpx.AsyncClient(
                timeout=10
            ) as client:


                response = await client.get(

                    f"{GroqClient.BASE_URL}/models",

                    headers=GroqClient._get_headers()

                )


                return response.status_code == 200



        except Exception as exc:


            logger.warning(

                "Groq indisponible : %s",

                exc

            )


            return False

