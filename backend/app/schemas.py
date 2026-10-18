"""Request and response shapes. Gemini's JSON is validated against these before it reaches the app."""

from datetime import datetime
from typing import Literal

from pydantic import BaseModel, Field

CATEGORIES = ["outdoors", "bigTrips", "smallTrips", "food", "localEvents", "culture", "entertainment", "withFriends"]
Category = Literal["outdoors", "bigTrips", "smallTrips", "food", "localEvents", "culture", "entertainment", "withFriends"]
Commitment = Literal["low", "medium", "high"]


class Meta(BaseModel):
    """Returned with every response so the app (and an auditor) can see what produced it."""

    request_id: str
    model: str
    prompt_version: str
    latency_ms: int


# /verify


class VerifyItem(BaseModel):
    title: str = Field(max_length=120)
    description: str = Field(default="", max_length=600)
    location: str | None = Field(default=None, max_length=160)
    criteria: list[str] = Field(min_length=1, max_length=8)


class VerifyRequest(BaseModel):
    item: VerifyItem
    photo_jpeg_base64: str = Field(max_length=6_000_000)  # ~4.5 MB of JPEG
    taken_at: datetime
    date_source: str = Field(default="capture time", max_length=40)


class Criterion(BaseModel):
    criterion: str
    met: bool
    why: str


class VerifyResponse(BaseModel):
    matches: bool
    criteria: list[Criterion]
    confidence: float = Field(ge=0, le=1)
    threshold: float
    verified: bool = Field(description="matches AND every criterion met AND confidence >= threshold")
    meta: Meta


# /ideas


class IdeasRequest(BaseModel):
    list_name: str = Field(max_length=80)
    existing_titles: list[str] = Field(default_factory=list, max_length=200)
    city: str = Field(default="Seattle", max_length=80)
    season: str = Field(default="summer", max_length=20)
    mood: str = Field(default="", max_length=200)


class Idea(BaseModel):
    title: str
    description: str
    location: str | None = None
    category: Category
    commitment: Commitment


class IdeasResponse(BaseModel):
    ideas: list[Idea]
    meta: Meta


# /campaigns


class CampaignsRequest(BaseModel):
    sponsor: str = Field(max_length=80)
    current_challenge: str = Field(max_length=160)
    target_category: str = Field(max_length=40)
    threshold: float = Field(ge=0, le=1)
    marketed_to: int = Field(ge=0)
    city_users: int = Field(ge=0)
    added_to_list: int = Field(ge=0)
    waiting_for_coupon: int = Field(ge=0)
    redeemed: int = Field(ge=0)
    neighborhoods: list[str] = Field(default_factory=list, max_length=20)


class CampaignIdea(BaseModel):
    title: str
    challenge: str
    audience: str
    why: str


class CampaignsResponse(BaseModel):
    ideas: list[CampaignIdea]
    meta: Meta

