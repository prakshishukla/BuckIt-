# BuckIt AI API

A small FastAPI service that sits between the iOS app and Gemini. It holds the Gemini key and does six jobs:

- fills in the prompt templates in `prompts/`
- calls Gemini 3 Flash through `google-genai`
- validates the JSON that comes back
- applies the confidence threshold
- rate limits requests
- writes an audit log

See [../AI_SYSTEM.md](../AI_SYSTEM.md) for the full design.

## Run it

```sh
cd backend
python3 -m venv .venv
.venv/bin/pip install -r requirements-dev.txt
cp .env.example .env            # then set GEMINI_API_KEY (gitignored, never commit it)
.venv/bin/uvicorn app.main:app --reload --port 8000
```

The app reads the server's address from `BUCKIT_API_URL` in `Config/BuckIt.xcconfig`. It is `http://127.0.0.1:8000` by default, which the iOS Simulator can reach directly. On a real iPhone, run the server with `--host 0.0.0.0` and set `BUCKIT_API_URL` to your Mac's LAN IP in `Config/Secrets.xcconfig`.

Quick check: `curl 127.0.0.1:8000/health`. API docs are served at http://127.0.0.1:8000/docs.

## Endpoints

| Endpoint | In | Out |
|---|---|---|
| `GET /health` | nothing | status, model, fallbacks, threshold |
| `POST /verify` | item, criteria, JPEG (base64), timestamp | per-criterion verdict, confidence, `verified` |
| `POST /ideas` | list name, existing titles, city, season, mood | up to 6 validated item ideas |
| `POST /campaigns` | aggregate campaign stats | 3 campaign ideas |

Every response includes `meta` (`request_id`, `model`, `prompt_version`, `latency_ms`), which matches a line in `logs/audit.jsonl`.

## Layout

```
app/main.py      endpoints, token check, rate limit, threshold, criteria alignment
app/gemini.py    google-genai Interactions client, model fallback chain, JSON parsing
app/schemas.py   request/response models (Gemini output is validated against these)
app/prompts.py   loads prompts/*.md and versions them by hash
app/audit.py     JSONL audit log
prompts/         verify.md, ideas.md, campaigns.md
tests/           pytest with Gemini stubbed (no key or network needed)
```

## Tests

```sh
.venv/bin/python -m pytest
```
