"""Prompt templates live in backend/prompts/*.md so they can be reviewed and versioned on their own.

Templates use $placeholders (string.Template), so the JSON examples inside them need no escaping.
Each prompt's version is the first 12 hex chars of its SHA-256, recorded in every audit log entry.
"""

import hashlib
from functools import cache
from pathlib import Path
from string import Template

PROMPTS_DIR = Path(__file__).resolve().parent.parent / "prompts"


@cache
def _load(name: str) -> tuple[Template, str]:
    text = (PROMPTS_DIR / f"{name}.md").read_text(encoding="utf-8")
    return Template(text), hashlib.sha256(text.encode()).hexdigest()[:12]


def render(name: str, **values: object) -> tuple[str, str]:
    """Returns (prompt text, prompt version)."""
    template, version = _load(name)
    return template.substitute({k: str(v) for k, v in values.items()}), version
