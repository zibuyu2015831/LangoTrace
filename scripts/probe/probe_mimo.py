#!/usr/bin/env python3
"""Probe MIMO (Xiaomi MiMo) text and TTS endpoints.

MIMO differences from standard OpenAI-compatible APIs:
  - Auth: `api-key: KEY` header (NOT `Authorization: Bearer KEY`)
  - TTS:  POST /chat/completions with text in the `assistant` role (not `user`)
          Response is non-streaming JSON; audio base64 WAV at choices[0].message.audio.data

Supported TTS audio format:
  wav  — MIMO's TTS adapter hardcodes WAV output; no other format is offered by the API.

Copy scripts/probe/.env.example to scripts/probe/.env and fill in your keys.
Run: python3 scripts/probe/probe_mimo.py
"""

from __future__ import annotations

import base64
import datetime
import json
import os
import socket
import sys
import time
from pathlib import Path
from urllib.error import HTTPError, URLError
from urllib.request import Request, urlopen

_MIMO_BASE_URL = "https://api.xiaomimimo.com/v1"
_AUDIO_DIR = Path(__file__).parent / "audio" / "mimo"

# MIMO TTS only supports WAV output (hardcoded in both the API and the MimoTTSAdapter).
# No other audio.format values are accepted by the endpoint.
TTS_FORMATS: list[tuple[str, str]] = [
    ("wav", ".wav"),
]


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


def _mimo_headers(api_key: str) -> dict:
    return {
        "api-key": api_key,
        "Content-Type": "application/json",
    }


def probe_text(api_key: str, model: str) -> bool:
    url = _MIMO_BASE_URL + "/chat/completions"
    body = {
        "model": model,
        "messages": [{"role": "user", "content": "Reply with exactly OK."}],
        "max_tokens": 32,
        "temperature": 0,
    }
    started = time.monotonic()
    status, raw = _post(url, _mimo_headers(api_key), body)
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


def probe_tts(api_key: str, model: str, voice: str, fmt: str, ext: str) -> bool:
    """Test MIMO TTS for the given audio format.

    MIMO requires the TTS text in the `assistant` role. The response is non-streaming
    JSON with audio base64 at choices[0].message.audio.data; the API always returns WAV.
    """
    url = _MIMO_BASE_URL + "/chat/completions"
    body = {
        "model": model,
        "messages": [
            {"role": "user", "content": ""},
            {"role": "assistant", "content": "Today I wrote one short sentence for practice."},
        ],
        "audio": {"format": fmt, "voice": voice},
        "stream": False,
    }
    started = time.monotonic()
    status, raw = _post(url, _mimo_headers(api_key), body, timeout=60)
    elapsed = int((time.monotonic() - started) * 1000)
    if 200 <= status < 300:
        try:
            payload = json.loads(raw)
            b64 = payload["choices"][0]["message"]["audio"]["data"]
            audio = base64.b64decode(b64)
            ts = datetime.datetime.now().strftime("%Y%m%d-%H%M%S")
            out = _AUDIO_DIR / f"{ts}-{voice}{ext}"
            _AUDIO_DIR.mkdir(parents=True, exist_ok=True)
            out.write_bytes(audio)
            ok, label, detail = True, "PASS", f"received {len(audio)} bytes → {out.name}"
        except Exception as exc:
            ok, label, detail = False, "FAIL", f"audio decode error: {exc}"
    else:
        try:
            err_body = json.loads(raw).get("error", {}).get("message", raw[:120].decode(errors="replace"))
        except Exception:
            err_body = raw[:120].decode(errors="replace")
        ok, label, detail = False, "FAIL", f"HTTP {status}: {err_body}"
    print(f"[{label}] tts/{fmt:<5} ({elapsed:>5} ms): {detail}")
    return ok


def main() -> int:
    api_key = _require("MIMO_API_KEY")
    text_model = _require("MIMO_TEXT_MODEL")
    tts_model = _require("MIMO_TTS_MODEL")
    tts_voice = _require("MIMO_TTS_VOICE")

    print("MIMO probe")
    print(f"  base_url:    {_MIMO_BASE_URL}")
    print(f"  text_model:  {text_model}")
    print(f"  tts_model:   {tts_model}  voice: {tts_voice}")
    print(f"  tts_formats: {', '.join(fmt for fmt, _ in TTS_FORMATS)}  (only format supported by API)")
    print(f"  api_key:     <redacted>")
    print()

    results = []
    try:
        results.append(probe_text(api_key, text_model))
        for fmt, ext in TTS_FORMATS:
            results.append(probe_tts(api_key, tts_model, tts_voice, fmt, ext))
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
