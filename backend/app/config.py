"""Settings, read from the environment (and backend/.env if present)."""

import os
from dataclasses import dataclass
from pathlib import Path

from dotenv import load_dotenv

BACKEND_DIR = Path(__file__).resolve().parent.parent
load_dotenv(BACKEND_DIR / ".env")


@dataclass(frozen=True)
class Settings:
    gemini_api_key: str
    gemini_model: str
    confidence_threshold: float
    app_token: str
    rate_limit_per_minute: int
    audit_log_path: Path

    @property
    def gemini_configured(self) -> bool:
        return bool(self.gemini_api_key) and self.gemini_api_key != "your-key-here"


def load_settings() -> Settings:
    audit = Path(os.getenv("AUDIT_LOG_PATH", "logs/audit.jsonl"))
    return Settings(
        gemini_api_key=os.getenv("GEMINI_API_KEY", "").strip(),
        gemini_model=os.getenv("GEMINI_MODEL", "").strip() or "gemini-3-flash-preview",
        confidence_threshold=float(os.getenv("CONFIDENCE_THRESHOLD", "0.7")),
        app_token=os.getenv("BUCKIT_APP_TOKEN", "").strip(),
        rate_limit_per_minute=int(os.getenv("RATE_LIMIT_PER_MINUTE", "30")),
        audit_log_path=audit if audit.is_absolute() else BACKEND_DIR / audit,
    )


settings = load_settings()
