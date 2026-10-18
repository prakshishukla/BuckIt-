"""Append-only JSONL audit log: one line per AI call.

Logged: request id, endpoint, model, prompt version, latency, token count, Gemini's interaction id,
a summary of the inputs and the validated output. Never logged: photo bytes (only a SHA-256 and size)
or the user's GPS coordinates (the app doesn't send them).
"""

import json
import sys
import threading
from datetime import datetime, timezone
from typing import Any

from .config import settings

_lock = threading.Lock()


def record(entry: dict[str, Any]) -> None:
    entry = {"ts": datetime.now(timezone.utc).isoformat(timespec="milliseconds"), **entry}
    path = settings.audit_log_path
    path.parent.mkdir(parents=True, exist_ok=True)
    line = json.dumps(entry, ensure_ascii=False, default=str)
    with _lock:
        with path.open("a", encoding="utf-8") as f:
            f.write(line + "\n")
        # Also to stdout, so hosted deploys (whose disks are wiped on restart) keep the trail in their logs.
        print("AUDIT " + line, file=sys.stdout, flush=True)
