"""BuckIt AI API: the only place that talks to Gemini.

The iOS app sends structured requests here; this service fills in the prompt templates, calls Gemini,
validates the JSON it returns, applies the confidence threshold, and writes an audit log entry.
The Gemini API key lives only in this service's environment and never ships in the app.

Run: uvicorn app.main:app --reload --port 8000   (from backend/)
"""

import base64
import binascii
import hashlib
import hmac
import time
import uuid
from collections import defaultdict, deque

from fastapi import Depends, FastAPI, Header, HTTPException, Request
from pydantic import ValidationError

from . import audit, gemini, prompts
from .config import settings
from .schemas import (
    CATEGORIES,
    CampaignIdea,
    CampaignsRequest,
    CampaignsResponse,
    Criterion,
    Idea,
    IdeasRequest,
    IdeasResponse,
    Meta,
    VerifyRequest,
    VerifyResponse,
)

app = FastAPI(title="BuckIt AI API", version="1.0.0")

CATEGORY_LABELS = ["Outdoors", "Big trips", "Small trips", "Food", "Local events", "Culture", "Entertainment", "With friends"]


# MARK: - Guards


def require_token(x_buckit_token: str | None = Header(default=None)) -> None:
    """Shared app token, if BUCKIT_APP_TOKEN is set. A speed bump for a demo, not real auth (see AI_SYSTEM.md)."""
    if settings.app_token and not hmac.compare_digest(x_buckit_token or "", settings.app_token):
        raise HTTPException(401, "Missing or wrong X-BuckIt-Token")


_hits: dict[str, deque[float]] = defaultdict(deque)


def rate_limit(request: Request) -> None:
    """Sliding one-minute window per client IP, so a leaked token can't drain the Gemini quota."""
    now = time.monotonic()
    window = _hits[request.client.host if request.client else "?"]
    while window and now - window[0] > 60:
        window.popleft()
    if len(window) >= settings.rate_limit_per_minute:
        raise HTTPException(429, "Too many requests. Wait a minute and try again.")
    window.append(now)


def require_gemini() -> None:
    if not settings.gemini_configured:
        raise HTTPException(503, "The server has no Gemini key. Set GEMINI_API_KEY in backend/.env.")


guards = [Depends(require_token), Depends(rate_limit), Depends(require_gemini)]


async def call_gemini(endpoint: str, request_id: str, prompt: str, version: str, inputs: dict, jpeg: bytes | None = None):
    """Calls Gemini and turns failures into HTTP errors. Failures are audited too."""
    try:
        return await gemini.generate_json(prompt, jpeg)
    except gemini.GeminiUnavailable as e:
        audit.record({"request_id": request_id, "endpoint": endpoint, "prompt_version": version,
                      "inputs": inputs, "status": "unavailable", "error": str(e)})
        raise HTTPException(429 if e.status == 429 else 503, str(e))
    except gemini.GeminiBadOutput as e:
        audit.record({"request_id": request_id, "endpoint": endpoint, "prompt_version": version,
                      "inputs": inputs, "status": "bad_output", "error": str(e)})
        raise HTTPException(502, "Gemini's answer wasn't in the expected format. Try again.")


def meta(request_id: str, result: gemini.GeminiResult, version: str) -> Meta:
    return Meta(request_id=request_id, model=result.model, prompt_version=version, latency_ms=result.latency_ms)


def log_success(endpoint: str, request_id: str, result: gemini.GeminiResult, version: str, inputs: dict, output: dict) -> None:
    audit.record({"request_id": request_id, "endpoint": endpoint, "status": "ok", "model": result.model,
                  "prompt_version": version, "latency_ms": result.latency_ms, "total_tokens": result.total_tokens,
                  "interaction_id": result.interaction_id, "inputs": inputs, "output": output})


# MARK: - Endpoints


@app.get("/health")
def health() -> dict:
    return {"ok": True, "gemini_configured": settings.gemini_configured, "model": settings.gemini_model,
            "fallbacks": gemini.model_chain()[1:], "confidence_threshold": settings.confidence_threshold,
            "token_required": bool(settings.app_token)}


@app.post("/verify", response_model=VerifyResponse, dependencies=guards)
async def verify(body: VerifyRequest) -> VerifyResponse:
    """Photo + item + criteria in, a per-criterion verdict out."""
    request_id = uuid.uuid4().hex
    try:
        jpeg = base64.b64decode(body.photo_jpeg_base64, validate=True)
    except (binascii.Error, ValueError):
        raise HTTPException(422, "photo_jpeg_base64 isn't valid base64")
    if not jpeg.startswith(b"\xff\xd8"):
        raise HTTPException(422, "Photo must be a JPEG")

    prompt, version = prompts.render(
        "verify",
        title=body.item.title,
        description=body.item.description or "(none)",
        location=body.item.location or "anywhere",
        taken_at=body.taken_at.isoformat(timespec="minutes"),
        date_source=body.date_source,
        criteria="\n".join(f"- {c}" for c in body.item.criteria),
    )
    inputs = {"item": body.item.title, "criteria": body.item.criteria, "taken_at": body.taken_at.isoformat(),
              "photo_sha256": hashlib.sha256(jpeg).hexdigest(), "photo_bytes": len(jpeg)}
    result = await call_gemini("/verify", request_id, prompt, version, inputs, jpeg)

    criteria = align_criteria(body.item.criteria, result.data.get("criteria"))
    try:
        confidence = min(1.0, max(0.0, float(result.data.get("confidence", 0))))
    except (TypeError, ValueError):
        confidence = 0.0
    matches = result.data.get("matches") is True
    verified = matches and all(c.met for c in criteria) and confidence >= settings.confidence_threshold

    response = VerifyResponse(matches=matches, criteria=criteria, confidence=confidence,
                              threshold=settings.confidence_threshold, verified=verified,
                              meta=meta(request_id, result, version))
    log_success("/verify", request_id, result, version, inputs, response.model_dump(exclude={"meta"}))
    return response


def align_criteria(requested: list[str], returned: object) -> list[Criterion]:
    """One result per requested criterion, in order. Anything Gemini skipped or mangled counts as not met."""
    rows = [r for r in returned if isinstance(r, dict)] if isinstance(returned, list) else []
    by_text = {str(r.get("criterion", "")).strip().lower(): r for r in rows}
    out = []
    for i, text in enumerate(requested):
        row = by_text.get(text.strip().lower()) or (rows[i] if i < len(rows) else None)
        if row is None:
            out.append(Criterion(criterion=text, met=False, why="Gemini didn't judge this one"))
        else:
            out.append(Criterion(criterion=text, met=row.get("met") is True, why=str(row.get("why", ""))[:140]))
    return out


@app.post("/ideas", response_model=IdeasResponse, dependencies=guards)
async def ideas(body: IdeasRequest) -> IdeasResponse:
    """List name, city, season and mood in; 6 bucket-list item ideas out."""
    request_id = uuid.uuid4().hex
    prompt, version = prompts.render(
        "ideas",
        city=body.city,
        season=body.season.lower(),
        list_name=body.list_name,
        mood_line=f"They're in the mood for: {body.mood}." if body.mood.strip() else "",
        existing="; ".join(body.existing_titles[:40]) or "(nothing yet)",
        categories=", ".join(CATEGORIES),
    )
    inputs = body.model_dump()
    result = await call_gemini("/ideas", request_id, prompt, version, inputs)

    valid = []
    for raw in result.data.get("ideas") or []:
        if not isinstance(raw, dict):
            continue
        raw = {**raw, "category": normalize_category(raw.get("category")),
               "commitment": str(raw.get("commitment", "medium")).lower()}
        try:
            valid.append(Idea.model_validate(raw))
        except ValidationError:
            continue  # drop malformed ideas rather than failing the whole request
    if not valid:
        raise HTTPException(502, "Gemini didn't return any usable ideas. Try again.")

    response = IdeasResponse(ideas=valid, meta=meta(request_id, result, version))
    log_success("/ideas", request_id, result, version, inputs, response.model_dump(exclude={"meta"}))
    return response


def normalize_category(value: object) -> str:
    """Accepts the raw value ("bigTrips") or the label ("Big trips"); unknown values become outdoors."""
    text = str(value or "").strip()
    if text in CATEGORIES:
        return text
    for raw, label in zip(CATEGORIES, CATEGORY_LABELS):
        if text.lower() in (raw.lower(), label.lower()):
            return raw
    return "outdoors"


@app.post("/campaigns", response_model=CampaignsResponse, dependencies=guards)
async def campaigns(body: CampaignsRequest) -> CampaignsResponse:
    """Aggregate campaign stats in (no individual users); 3 sponsored-challenge ideas out."""
    request_id = uuid.uuid4().hex
    prompt, version = prompts.render(
        "campaigns",
        sponsor=body.sponsor,
        current_challenge=body.current_challenge,
        threshold_pct=round(body.threshold * 100),
        target_category=body.target_category,
        marketed_to=body.marketed_to,
        city_users=body.city_users,
        added_to_list=body.added_to_list,
        waiting_for_coupon=body.waiting_for_coupon,
        redeemed=body.redeemed,
        neighborhoods=", ".join(body.neighborhoods) or "(unknown)",
        categories=", ".join(CATEGORY_LABELS),
    )
    inputs = body.model_dump()
    result = await call_gemini("/campaigns", request_id, prompt, version, inputs)

    valid = []
    for raw in result.data.get("ideas") or []:
        try:
            valid.append(CampaignIdea.model_validate(raw))
        except ValidationError:
            continue
    if not valid:
        raise HTTPException(502, "Gemini didn't return any usable ideas. Try again.")

    response = CampaignsResponse(ideas=valid, meta=meta(request_id, result, version))
    log_success("/campaigns", request_id, result, version, inputs, response.model_dump(exclude={"meta"}))
    return response
