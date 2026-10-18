"""Thin wrapper around google-genai's Interactions API with a model fallback chain and strict JSON parsing."""

import base64
import json
import time
from dataclasses import dataclass

import httpx
from google import genai
from google.genai import errors

from .config import settings

FALLBACK_MODELS = ["gemini-3-flash-preview", "gemini-3.1-flash-lite", "gemini-3.5-flash"]
RETRYABLE = {404, 429, 500, 503}  # unavailable model, rate limit, overload


class GeminiUnavailable(Exception):
    """Every model in the chain failed. `status` is the last HTTP status (429 = rate limited)."""

    def __init__(self, status: int, message: str):
        super().__init__(message)
        self.status = status


class GeminiBadOutput(Exception):
    """The model answered, but not with the JSON we asked for."""


@dataclass
class GeminiResult:
    data: dict
    model: str
    interaction_id: str | None
    latency_ms: int
    total_tokens: int | None


_client: genai.Client | None = None


def _get_client() -> genai.Client:
    global _client
    if _client is None:
        _client = genai.Client(api_key=settings.gemini_api_key)
    return _client


def model_chain() -> list[str]:
    chain = [settings.gemini_model]
    chain += [m for m in FALLBACK_MODELS if m not in chain]
    return chain


def parse_json(text: str) -> dict:
    """Strips markdown fences / surrounding prose and parses the first JSON object."""
    cleaned = text.replace("```json", "").replace("```", "").strip()
    start, end = cleaned.find("{"), cleaned.rfind("}")
    if start != -1 and end > start:
        cleaned = cleaned[start : end + 1]
    try:
        data = json.loads(cleaned)
    except json.JSONDecodeError as e:
        raise GeminiBadOutput(f"Not valid JSON: {cleaned[:120]}") from e
    if not isinstance(data, dict):
        raise GeminiBadOutput("Expected a JSON object")
    return data


async def generate_json(prompt: str, jpeg: bytes | None = None) -> GeminiResult:
    content: list[dict] = [{"type": "text", "text": prompt}]
    if jpeg is not None:
        content.append({"type": "image", "data": base64.b64encode(jpeg).decode(), "mime_type": "image/jpeg"})

    last = GeminiUnavailable(503, "Gemini is busy right now. Try again in a moment.")
    for model in model_chain():
        started = time.monotonic()
        try:
            interaction = await _get_client().aio.interactions.create(model=model, input=content, timeout=30)
        except errors.APIError as e:
            if e.code in RETRYABLE:
                last = GeminiUnavailable(e.code, _friendly(e.code))
                continue
            raise
        except (httpx.TimeoutException, TimeoutError):
            last = GeminiUnavailable(504, "Gemini timed out. Try again in a moment.")
            continue

        text = interaction.output_text or ""
        if not text:
            raise GeminiBadOutput("Gemini returned no answer")
        usage = interaction.usage
        return GeminiResult(
            data=parse_json(text),
            model=model,
            interaction_id=interaction.id,
            latency_ms=int((time.monotonic() - started) * 1000),
            total_tokens=getattr(usage, "total_tokens", None),
        )
    raise last


def _friendly(code: int) -> str:
    if code == 429:
        return "Gemini's free-tier limit was hit. Wait a minute and try again."
    return "Gemini is busy right now. Try again in a moment."
