#!/usr/bin/env python3
"""Probe OpenAI text (chat/completions) and TTS (audio/speech) endpoints.

TTS test covers all officially supported response_format values:
  mp3, opus, aac, flac, wav, pcm

Copy scripts/probe/.env.example to scripts/probe/.env and fill in your keys.
Run: python3 scripts/probe/probe_openai.py
"""

from __future__ import annotations

import datetime
import json
import os
import socket
import sys
import time
from pathlib import Path
from urllib.error import HTTPError, URLError
from urllib.request import Request, urlopen

_AUDIO_DIR = Path(__file__).parent / "audio" / "openai"

# All formats supported by the OpenAI /audio/speech endpoint.
TTS_FORMATS = ["mp3", "opus", "aac", "flac", "wav", "pcm"]


def load_dotenv(path: Path) -> None:
    if not path.exists():
        return
    for line in path.read_text(encoding="utf-8").splitlines():
        stripped = line.strip()
        if not stripped or stripped.startswith("#") or "=" not in stripped:
            continue
        key, _, value = stripped.partition("=")
        key = key.strip()
        value = value.strip().strip('"').strip("'")
        if key and key not in os.environ:
            os.environ[key] = value


load_dotenv(Path(__file__).parent / ".env")


def _post(url: str, headers: dict, body: dict, timeout: int = 30) -> tuple[int, bytes]:
    data = json.dumps(body, separators=(",", ":")).encode("utf-8")
    req = Request(url, data=data, headers=headers, method="POST")
    try:
        with urlopen(req, timeout=timeout) as resp:
            return resp.status, resp.read()
    except HTTPError as e:
        return e.code, e.read() or b""


def _require(key: str) -> str:
    val = os.environ.get(key, "").strip()
    if not val:
        print(f"error: {key} is not set — copy .env.example to .env and fill it in", file=sys.stderr)
        sys.exit(2)
    return val


def probe_text(base_url: str, api_key: str, model: str) -> bool:
    url = base_url.rstrip("/") + "/chat/completions"
    body = {
        "model": model,
        "messages": [{"role": "user", "content": "Reply with exactly OK."}],
        "max_tokens": 8,
        "temperature": 0,
    }
    headers = {
        "Authorization": f"Bearer {api_key}",
        "Content-Type": "application/json",
    }
    started = time.monotonic()
    status, raw = _post(url, headers, body)
    elapsed = int((time.monotonic() - started) * 1000)
    if 200 <= status < 300:
        try:
            payload = json.loads(raw)
            text = payload["choices"][0]["message"]["content"].strip()
            ok = text.rstrip(".,!?;: ").upper() == "OK"
            label = "PASS" if ok else "FAIL"
            detail = f"model replied {text!r}" if ok else f"unexpected reply: {text!r}"
        except Exception as exc:
            ok, label, detail = False, "FAIL", f"parse error: {exc}"
    else:
        ok, label, detail = False, "FAIL", f"HTTP {status}"
    print(f"[{label}] text        ({elapsed:>5} ms): {detail}")
    return ok


def probe_tts(base_url: str, api_key: str, model: str, voice: str, fmt: str) -> bool:
    """Test one TTS format against the /audio/speech endpoint."""
    url = base_url.rstrip("/") + "/audio/speech"
    body = {
        "model": model,
        "input": "Today I wrote one short sentence for practice.",
        "voice": voice,
        "response_format": fmt,
    }
    headers = {
        "Authorization": f"Bearer {api_key}",
        "Content-Type": "application/json",
    }
    started = time.monotonic()
    status, raw = _post(url, headers, body)
    elapsed = int((time.monotonic() - started) * 1000)
    if 200 <= status < 300 and raw:
        ts = datetime.datetime.now().strftime("%Y%m%d-%H%M%S")
        out = _AUDIO_DIR / f"{ts}-{voice}.{fmt}"
        _AUDIO_DIR.mkdir(parents=True, exist_ok=True)
        out.write_bytes(raw)
        ok, label, detail = True, "PASS", f"received {len(raw)} bytes → {out.name}"
    else:
        ok, label, detail = False, "FAIL", f"HTTP {status}" if status != 200 else "empty response body"
    print(f"[{label}] tts/{fmt:<5} ({elapsed:>5} ms): {detail}")
    return ok


def main() -> int:
    base_url = "https://api.openai.com/v1"
    api_key = _require("OPENAI_API_KEY")
    text_model = _require("OPENAI_TEXT_MODEL")
    tts_model = _require("OPENAI_TTS_MODEL")
    tts_voice = _require("OPENAI_TTS_VOICE")

    print("OpenAI probe")
    print(f"  base_url:   {base_url}")
    print(f"  text_model: {text_model}")
    print(f"  tts_model:  {tts_model}  voice: {tts_voice}")
    print(f"  tts_formats: {', '.join(TTS_FORMATS)}")
    print(f"  api_key:    <redacted>")
    print()

    results = []
    try:
        results.append(probe_text(base_url, api_key, text_model))
        for fmt in TTS_FORMATS:
            results.append(probe_tts(base_url, api_key, tts_model, tts_voice, fmt))
    except (socket.timeout, URLError) as exc:
        print(f"[FAIL] network error: {exc}", file=sys.stderr)
        return 1

    passed = sum(results)
    total = len(results)
    print()
    print(f"{'PASS' if all(results) else 'FAIL'} — {passed}/{total} checks passed")
    return 0 if all(results) else 1


if __name__ == "__main__":
    raise SystemExit(main())
