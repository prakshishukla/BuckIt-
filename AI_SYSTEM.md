# BuckIt AI system

This document describes every place BuckIt uses AI: which model it uses, what goes in and what comes out, how people stay in control, what data is involved, and how each call can be audited.

## Architecture

```
iOS app ──HTTPS/JSON──▶ BuckIt AI API (backend/, FastAPI) ──google-genai──▶ Gemini
           no key            holds the key, prompts, threshold,         Interactions API
                             validation, rate limit, audit log
```

- The app never talks to Gemini directly and never contains the Gemini API key. The key lives only in the server's environment (`backend/.env`, gitignored).
- Prompts are plain files in [`backend/prompts/`](backend/prompts/). The server sends each prompt's version (the first 12 characters of its SHA-256) back with every response and records it in the audit log.
- Every answer from Gemini is parsed as JSON and checked against a strict schema ([`backend/app/schemas.py`](backend/app/schemas.py)) before it reaches the app. Malformed answers are dropped or rejected, never passed through.

## Models

| | |
|---|---|
| Primary model | **Gemini 3 Flash** (`gemini-3-flash-preview`), multimodal (text + vision) |
| Fallbacks | `gemini-3.1-flash-lite`, then `gemini-3.5-flash`. Used only if the primary returns 404, 429, 500 or 503, or times out. |
| API | Gemini Interactions API through the official `google-genai` Python SDK |
| Config | `GEMINI_MODEL` in `backend/.env`. `GET /health` reports the active model, the fallbacks and the threshold. |

Each response's `meta.model` field says which model actually answered.

## Use cases

### 1. Photo verification (`POST /verify`)

When someone completes a bucket-list item, they post a photo as proof. Gemini vision judges whether the photo shows the item.

**Input**
- The photo: a JPEG re-encoded on the phone at 1024 px or smaller. Re-encoding strips EXIF, so no GPS travels with it.
- The item's title, description and place name.
- The item's criteria. Sponsored items use the sponsor's criteria. Other items get "Photo shows: \<item\>" and "Looks like a real photo taken there, not a screenshot".
- When the photo was taken and how that was determined ("photo timestamp" or "capture time").

**Output** (strict JSON, validated)
```json
{
  "matches": true,
  "criteria": [{ "criterion": "Shows the outdoors", "met": true, "why": "Forests and mountains visible" }],
  "confidence": 0.95,
  "threshold": 0.7,
  "verified": true,
  "meta": { "request_id": "…", "model": "gemini-3-flash-preview", "prompt_version": "f4d082e5602b", "latency_ms": 6200 }
}
```

**Decision rule.** The server sets `verified = true` only if all three hold:
- Gemini says `matches`.
- Every requested criterion is `met`. If Gemini skips or garbles a criterion, it counts as not met.
- `confidence` is at least the **confidence threshold, 0.7 by default** (`CONFIDENCE_THRESHOLD`).

The app then adds two checks that run on the phone and never call AI:
- **Taken recently:** the photo is less than 7 days old.
- **Taken near the item:** the photo was taken within 150 km of Seattle, or 400 km for Big trips. This uses the photo's EXIF GPS or the phone's location.

Coordinates are compared on the phone and never sent to the server or to Gemini. A post counts as verified only if Gemini's verdict and both on-device checks pass.

**Prompt safeguards.** Gemini is told to judge only what is visible, to accept casual phone photos without being gullible, and to ignore any text in the photo that tries to tell it what to answer.

### 2. List-item ideas (`POST /ideas`)

In **Add item → ✨ Ideas**, someone types a mood ("rainy day", "cheap eats"). Gemini suggests items for that list.

- **Input:** the list's name, the titles already on it (up to 40), the city, the season and the mood text.
- **Output:** up to 6 ideas, each `{title, description, location, category, commitment}`. `category` must be one of the app's 8 activity types and `commitment` must be low, medium or high. The server normalizes labels ("Big trips" becomes `bigTrips`) and drops any idea that doesn't validate.
- **Human in the loop:** nothing is added automatically. The person ticks the ideas they want and taps **Add**.

### 3. Sponsor campaign ideas (`POST /campaigns`)

In **Sponsor View → Suggest campaigns**, Gemini proposes the next sponsored challenge for a brand.

- **Input:** aggregate numbers only:
  - sponsor name and current challenge
  - target activity type and threshold
  - reach: marketed-to count and city user count
  - funnel counts: added to a list, submitted, redeemed
  - top neighborhood names

  No individual users, names or photos are included.
- **Output:** 3 ideas, each `{title, challenge, audience, why}`. The `why` must cite the data.
- **Human in the loop:** these are suggestions shown to the sponsor. Nothing is launched automatically.

## Human oversight

- **Every verification step is visible.** The verification screen shows each criterion, Gemini's one-line reason, a ✓ or ✗, and the confidence. Nothing is decided behind the scenes.
- **The person decides what happens after a failed check.** When verification fails, they choose:
  - **Retake photo.**
  - **Post anyway.** On sponsored items this button reads **Post without reward**.

  Either way, an unverified post never unlocks a sponsor coupon. AI can block a reward, but it can't stop anyone from sharing their own photo.
- **Generated content needs a person's choice.** AI ideas, both list ideas and campaign ideas, are only ever suggestions. A person picks which ones to use.
- **Settings show the active mode.** **Profile → Settings → Photo check** shows whether checks go through Gemini (and which server) or run in offline demo mode.

## Fallback modes

| Situation | Behavior |
|---|---|
| Primary model busy, rate limited or unavailable | The server tries the fallback models in order. |
| Every model fails | The server returns 503 (or 429 for rate limits) with a plain-language message. The verification screen shows it with **Retake** / **Post anyway**. |
| Server unreachable | Photo check: shows "Can't reach the BuckIt AI server" with **Retake** / **Post anyway**. Ideas: switch to curated offline ideas, clearly labeled "Offline demo ideas". |
| No server configured (`BUCKIT_API_URL` empty) | Offline demo mode: the photo criteria pass automatically, labeled "Offline demo: not checked by Gemini". The on-device time and location checks still run for real. |
| `FORCE_VERIFY = YES` (stage safety net, off by default) | Verification passes even if Gemini says no or can't be reached. Results from this mode are labeled "Demo", not "Gemini". |

## Data handled

| Data | Where it goes | Kept? |
|---|---|---|
| **Proof photo** | Sent to the server and Gemini for `/verify` only, re-encoded without EXIF. | Stored on the phone (app Documents folder). The server doesn't store it; the audit log records only its SHA-256 hash and size. |
| **EXIF GPS and timestamp** (library photos) | Read on the phone. Only the timestamp is sent, as an ISO date. GPS stays on the phone and is used for the "Taken near" check. | On the phone, with the post. |
| **Phone location** (camera photos) | Used on the phone for the "Taken near" check. Never sent. | On the phone. |
| **Selfie** (optional second photo on a post) | Never sent to the server or to Gemini. | On the phone, with the post. |
| **Friends' names and tags** | Never sent to the server or to Gemini. Ideas and campaign requests contain no people. | On the phone. All friends in this demo are fictional seed data. |
| **List names, item titles, mood text** | Sent to `/ideas`. | Recorded in the audit log. |
| **Campaign aggregates** | Sent to `/campaigns`. | Recorded in the audit log. |

Gemini also processes what it receives under Google's Gemini API terms. On the free tier, Google may use inputs to improve its products, so a production deployment should use a paid tier, which doesn't.

## Audit trail

Every AI call, successful or failed, appends one JSON line to `backend/logs/audit.jsonl`, which is gitignored. Each line records:

```
ts, request_id, endpoint, status (ok | unavailable | bad_output), model, prompt_version,
latency_ms, total_tokens, interaction_id (Gemini's id), inputs (summary), output (validated JSON)
```

- The same `request_id` comes back to the app in `meta`, so you can match any verdict on screen to its log line.
- Photo bytes and GPS coordinates are never logged.

## Security

- **The key stays on the server.** The Gemini key is only in `backend/.env`, which is gitignored, and has never been committed. The app's `Info.plist` holds only the server URL.
- **The server checks every request:**
  - **Rate limit:** 30 requests per minute per client IP.
  - **Size limit:** photos up to about 4.5 MB.
  - **Format check:** photos must be JPEG.
  - **Validation:** every field is checked against a schema.
- **The app token is a speed bump, not real security.** The optional shared token (`BUCKIT_APP_TOKEN`) stops casual misuse, but it ships in the app and can be extracted. Production would replace it with real user auth plus Apple App Attest, and serve the API over HTTPS. The demo uses plain HTTP to localhost.

## Known limitations

- **Gemini can be wrong.** That is why it shows its reasons, why there is a confidence threshold, and why the final choice to post stays with the person.
- **A photo can't prove everything.** A photo can't show that someone hiked 5 miles, only that they were on a trail. Sponsors should write criteria a photo can actually show.
- **Location and time come from the phone.** The on-device checks use the phone's own location and time, which a determined user can spoof.
- **Confidence is the model's own estimate, not a calibrated probability.** The 0.7 threshold was picked by hand on demo photos.

## Testing

- `cd backend && pytest` runs the API tests with Gemini stubbed out, so they need no key or network. They cover the threshold rule, missing criteria counting as not met, non-JPEG rejection, idea normalization, token checks, mapping busy errors to 503, and making sure photos never appear in the audit log.
- In a debug build, the `-geminiSelfTest` launch argument runs a real verification and idea request through the server and prints the results to the Xcode console.
