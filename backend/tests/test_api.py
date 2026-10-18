"""API tests with Gemini stubbed out (no network, no key needed). Run: pytest (from backend/)."""

import base64
import dataclasses
import json

import pytest
from fastapi.testclient import TestClient

from app import audit, gemini, main

JPEG = base64.b64encode(b"\xff\xd8\xff\xe0fake-jpeg").decode()
ITEM = {"title": "Hike 5+ miles", "description": "Any trail", "location": "Seattle",
        "criteria": ["Photo shows a trail", "Looks like a real photo"]}


@pytest.fixture
def client(monkeypatch, tmp_path):
    test_settings = dataclasses.replace(main.settings, gemini_api_key="test", app_token="",
                                        confidence_threshold=0.7, audit_log_path=tmp_path / "audit.jsonl")
    monkeypatch.setattr(main, "settings", test_settings)
    monkeypatch.setattr(audit, "settings", test_settings)
    main._hits.clear()
    return TestClient(main.app)


def stub(monkeypatch, data):
    async def fake(prompt, jpeg=None):
        fake.prompt = prompt
        return gemini.GeminiResult(data=data, model="gemini-test", interaction_id="int_1", latency_ms=5, total_tokens=10)
    monkeypatch.setattr(gemini, "generate_json", fake)
    return fake


def verify(client, **overrides):
    return client.post("/verify", json={"item": ITEM, "photo_jpeg_base64": JPEG,
                                        "taken_at": "2026-10-17T10:00:00Z", **overrides})


def test_verify_passes_when_all_met_and_confident(client, monkeypatch, tmp_path):
    stub(monkeypatch, {"matches": True, "confidence": 0.92, "criteria": [
        {"criterion": "Photo shows a trail", "met": True, "why": "Dirt path through trees"},
        {"criterion": "Looks like a real photo", "met": True, "why": "Natural phone photo"}]})
    r = verify(client)
    assert r.status_code == 200
    body = r.json()
    assert body["verified"] is True and body["threshold"] == 0.7
    assert body["meta"]["model"] == "gemini-test"

    entry = json.loads((tmp_path / "audit.jsonl").read_text().splitlines()[-1])
    assert entry["endpoint"] == "/verify" and entry["status"] == "ok"
    assert "photo_sha256" in entry["inputs"] and JPEG not in json.dumps(entry)  # photo itself never logged


def test_verify_fails_below_confidence_threshold(client, monkeypatch):
    stub(monkeypatch, {"matches": True, "confidence": 0.55, "criteria": [
        {"criterion": c, "met": True, "why": "ok"} for c in ITEM["criteria"]]})
    assert verify(client).json()["verified"] is False


def test_verify_missing_criterion_counts_as_not_met(client, monkeypatch):
    stub(monkeypatch, {"matches": True, "confidence": 0.95, "criteria": [
        {"criterion": "Photo shows a trail", "met": True, "why": "ok"}]})
    body = verify(client).json()
    assert [c["met"] for c in body["criteria"]] == [True, False]
    assert body["verified"] is False


def test_verify_rejects_non_jpeg(client, monkeypatch):
    stub(monkeypatch, {})
    assert verify(client, photo_jpeg_base64=base64.b64encode(b"GIF89a").decode()).status_code == 422


def test_ideas_normalizes_and_drops_bad_rows(client, monkeypatch):
    fake = stub(monkeypatch, {"ideas": [
        {"title": "Ferry to Bainbridge", "description": "Walk on.", "location": "Pier 52",
         "category": "Small trips", "commitment": "Medium"},
        {"title": "Broken", "category": "outdoors"}]})
    r = client.post("/ideas", json={"list_name": "Summer", "city": "Seattle", "mood": "rainy day"})
    assert r.status_code == 200
    ideas = r.json()["ideas"]
    assert len(ideas) == 1 and ideas[0]["category"] == "smallTrips" and ideas[0]["commitment"] == "medium"
    assert "rainy day" in fake.prompt


def test_campaigns(client, monkeypatch):
    stub(monkeypatch, {"ideas": [{"title": "Sunrise Series", "challenge": "Catch a sunrise.",
                                  "audience": "≥60% Outdoors", "why": "Ballard leads."}]})
    r = client.post("/campaigns", json={"sponsor": "Patagonia", "current_challenge": "Hike 5+ miles",
                                        "target_category": "Outdoors", "threshold": 0.6, "marketed_to": 1000,
                                        "city_users": 5000, "added_to_list": 300, "waiting_for_coupon": 40,
                                        "redeemed": 90, "neighborhoods": ["Ballard"]})
    assert r.status_code == 200 and r.json()["ideas"][0]["title"] == "Sunrise Series"


def test_token_required_when_configured(client, monkeypatch):
    monkeypatch.setattr(main, "settings", dataclasses.replace(main.settings, app_token="secret"))
    stub(monkeypatch, {"ideas": []})
    assert client.post("/ideas", json={"list_name": "x"}).status_code == 401


def test_gemini_busy_maps_to_503(client, monkeypatch):
    async def busy(prompt, jpeg=None):
        raise gemini.GeminiUnavailable(503, "Gemini is busy right now.")
    monkeypatch.setattr(gemini, "generate_json", busy)
    assert client.post("/ideas", json={"list_name": "x"}).status_code == 503


def test_parse_json_strips_fences():
    assert gemini.parse_json('```json\n{"ok": true}\n```') == {"ok": True}
