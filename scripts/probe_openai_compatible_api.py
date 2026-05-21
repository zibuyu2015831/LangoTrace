#!/usr/bin/env python3
"""Probe an OpenAI-compatible text model endpoint.

This script is a host-side development diagnostic tool. It sends a fixed,
synthetic request and never prints the API key, request body, or response body.
"""

from __future__ import annotations

import argparse
from dataclasses import dataclass
import json
import os
import socket
import sys
import time
from typing import Callable, Iterable, Optional
from urllib.error import HTTPError, URLError
from urllib.parse import urlsplit, urlunsplit
from urllib.request import Request, urlopen


Mode = str
OpenHandler = Callable[[Request, int], object]


@dataclass(frozen=True)
class ProbeResult:
    mode: Mode
    ok: bool
    category: str
    detail: str
    duration_ms: int


@dataclass(frozen=True)
class ProbeConfig:
    base_url: str
    api_key: str
    model: str
    mode: Mode
    timeout: int
    json_output: bool = False


def collect_interactive_config(
    *,
    input_fn: Callable[[str], str] = input,
) -> ProbeConfig:
    print("LangoTrace OpenAI-compatible API probe")
    print("No arguments detected. Please enter the Provider configuration.")
    base_url = input_fn("Base URL: ").strip()
    api_key = input_fn("API key: ").strip()
    model = input_fn("Model: ").strip()
    return ProbeConfig(
        base_url=base_url,
        api_key=api_key,
        model=model,
        mode="chat",
        timeout=30,
        json_output=False,
    )


def normalize_base_url(base_url: str) -> str:
    raw = base_url.strip()
    if not raw:
        raise ValueError("base URL is required")

    parsed = urlsplit(raw)
    if parsed.scheme not in {"http", "https"} or not parsed.netloc:
        raise ValueError("base URL must be an absolute http(s) URL")
    if parsed.query or parsed.fragment:
        raise ValueError("base URL must not include query or fragment")

    path = parsed.path.rstrip("/")
    if path.endswith("/v1"):
        path = path[:-3].rstrip("/")

    return urlunsplit((parsed.scheme, parsed.netloc, path, "", "")).rstrip("/")


def build_endpoint_url(base_url: str, mode: Mode) -> str:
    normalized = normalize_base_url(base_url)
    if mode == "chat":
        return f"{normalized}/v1/chat/completions"
    if mode == "responses":
        return f"{normalized}/v1/responses"
    raise ValueError(f"unsupported mode: {mode}")


def build_payload(model: str, mode: Mode) -> dict[str, object]:
    model_name = model.strip()
    if not model_name:
        raise ValueError("model is required")

    if mode == "chat":
        return {
            "model": model_name,
            "messages": [
                {
                    "role": "system",
                    "content": "You are a connectivity probe. Follow the user exactly.",
                },
                {"role": "user", "content": "Reply with exactly OK."},
            ],
            "temperature": 0,
            "max_tokens": 8,
        }
    if mode == "responses":
        return {
            "model": model_name,
            "input": "Reply with exactly OK.",
            "temperature": 0,
            "max_output_tokens": 8,
        }
    raise ValueError(f"unsupported mode: {mode}")


def build_request(
    *,
    base_url: str,
    api_key: str,
    model: str,
    mode: Mode,
    timeout_seconds: int,
) -> Request:
    del timeout_seconds
    secret = api_key.strip()
    if not secret:
        raise ValueError("API key is required")

    body = json.dumps(build_payload(model, mode), separators=(",", ":")).encode("utf-8")
    return Request(
        build_endpoint_url(base_url, mode),
        data=body,
        headers={
            "Authorization": f"Bearer {secret}",
            "Content-Type": "application/json",
            "Accept": "application/json",
            "User-Agent": "LangoTrace-openai-compatible-probe/1.0",
        },
        method="POST",
    )


def default_opener(request: Request, timeout_seconds: int) -> object:
    return urlopen(request, timeout=timeout_seconds)


def _load_json_response(response: object) -> dict[str, object]:
    status = int(getattr(response, "status", 0) or 0)
    if status < 200 or status >= 300:
        raise ValueError(f"unexpected HTTP status {status}")
    raw = response.read()
    if not raw:
        raise ValueError("empty response body")
    payload = json.loads(raw.decode("utf-8"))
    if not isinstance(payload, dict):
        raise ValueError("response JSON is not an object")
    return payload


def extract_text(payload: dict[str, object], mode: Mode) -> str:
    if mode == "chat":
        choices = payload.get("choices")
        if isinstance(choices, list) and choices:
            first = choices[0]
            if isinstance(first, dict):
                message = first.get("message")
                if isinstance(message, dict):
                    content = message.get("content")
                    if isinstance(content, str):
                        return content.strip()
        raise ValueError("chat response does not contain message content")

    if mode == "responses":
        output_text = payload.get("output_text")
        if isinstance(output_text, str):
            return output_text.strip()

        output = payload.get("output")
        if isinstance(output, list):
            chunks: list[str] = []
            for item in output:
                if not isinstance(item, dict):
                    continue
                content = item.get("content")
                if not isinstance(content, list):
                    continue
                for content_item in content:
                    if not isinstance(content_item, dict):
                        continue
                    text = content_item.get("text")
                    if isinstance(text, str):
                        chunks.append(text)
            if chunks:
                return "".join(chunks).strip()
        raise ValueError("responses API response does not contain output text")

    raise ValueError(f"unsupported mode: {mode}")


def _category_for_http_status(status: int) -> str:
    if status in {401, 403}:
        return "authentication_failed"
    if status == 404:
        return "unsupported_model_or_endpoint"
    if status == 408:
        return "timeout"
    if status == 429:
        return "rate_limited_or_quota"
    if 400 <= status < 500:
        return "provider_rejected"
    if 500 <= status < 600:
        return "provider_unavailable"
    return "http_error"


def _safe_http_error_detail(error: HTTPError) -> str:
    return f"HTTP {error.code} {error.reason or ''}".strip()


def run_probe(
    *,
    base_url: str,
    api_key: str,
    model: str,
    mode: Mode,
    timeout_seconds: int,
    opener: OpenHandler = default_opener,
) -> ProbeResult:
    started = time.monotonic()

    try:
        request = build_request(
            base_url=base_url,
            api_key=api_key,
            model=model,
            mode=mode,
            timeout_seconds=timeout_seconds,
        )
        with opener(request, timeout_seconds) as response:
            payload = _load_json_response(response)
        text = extract_text(payload, mode)
        if text != "OK":
            return _result(started, mode, False, "unexpected_model_output", "Model did not reply with exactly OK")
        return _result(started, mode, True, "success", "Model replied with OK")
    except HTTPError as error:
        return _result(started, mode, False, _category_for_http_status(error.code), _safe_http_error_detail(error))
    except socket.timeout:
        return _result(started, mode, False, "timeout", "Request timed out")
    except URLError as error:
        reason = getattr(error, "reason", error)
        return _result(started, mode, False, "network_unavailable", f"Network error: {reason}")
    except (json.JSONDecodeError, UnicodeDecodeError, ValueError) as error:
        return _result(started, mode, False, "invalid_response", str(error))


def _result(started: float, mode: Mode, ok: bool, category: str, detail: str) -> ProbeResult:
    return ProbeResult(
        mode=mode,
        ok=ok,
        category=category,
        detail=detail,
        duration_ms=int((time.monotonic() - started) * 1000),
    )


def modes_from_argument(mode: str) -> list[Mode]:
    if mode == "both":
        return ["chat", "responses"]
    if mode in {"chat", "responses"}:
        return [mode]
    raise ValueError(f"unsupported mode: {mode}")


def print_human_result(result: ProbeResult) -> None:
    icon = "PASS" if result.ok else "FAIL"
    print(f"[{icon}] {result.mode}: {result.category} ({result.duration_ms} ms)")
    print(f"      {result.detail}")


def print_json_results(results: Iterable[ProbeResult]) -> None:
    print(
        json.dumps(
            [
                {
                    "mode": result.mode,
                    "ok": result.ok,
                    "category": result.category,
                    "detail": result.detail,
                    "duration_ms": result.duration_ms,
                }
                for result in results
            ],
            ensure_ascii=False,
            indent=2,
        )
    )


def parser() -> argparse.ArgumentParser:
    argument_parser = argparse.ArgumentParser(
        description="Test whether an OpenAI-compatible API key, base URL, and model can answer a minimal text probe. Run without arguments for interactive input.",
    )
    argument_parser.add_argument("--base-url", default=os.environ.get("OPENAI_BASE_URL"), help="Provider base URL, for example https://api.openai.com or https://api.example.com/v1. Defaults to OPENAI_BASE_URL.")
    argument_parser.add_argument("--model", default=os.environ.get("OPENAI_MODEL"), help="Text model name. Defaults to OPENAI_MODEL.")
    argument_parser.add_argument("--api-key", default=os.environ.get("OPENAI_API_KEY"), help="API key. Defaults to OPENAI_API_KEY. The value is never printed.")
    argument_parser.add_argument("--mode", choices=["chat", "responses", "both"], default="chat", help="Endpoint to probe. Default: chat.")
    argument_parser.add_argument("--timeout", type=int, default=30, help="Request timeout in seconds. Default: 30.")
    argument_parser.add_argument("--json", action="store_true", help="Print machine-readable JSON result.")
    return argument_parser


def main(argv: Optional[list[str]] = None) -> int:
    actual_argv = sys.argv[1:] if argv is None else argv

    if not actual_argv:
        config = collect_interactive_config()
    else:
        args = parser().parse_args(actual_argv)
        config = ProbeConfig(
            base_url=args.base_url,
            api_key=args.api_key,
            model=args.model,
            mode=args.mode,
            timeout=args.timeout,
            json_output=args.json,
        )

    try:
        if config.timeout <= 0:
            raise ValueError("timeout must be greater than 0")
        if config.base_url is None:
            raise ValueError("base URL is required; pass --base-url or OPENAI_BASE_URL")
        if config.model is None:
            raise ValueError("model is required; pass --model or OPENAI_MODEL")
        if config.api_key is None:
            raise ValueError("API key is required; pass --api-key or OPENAI_API_KEY")

        results = [
            run_probe(
                base_url=config.base_url,
                api_key=config.api_key,
                model=config.model,
                mode=mode,
                timeout_seconds=config.timeout,
            )
            for mode in modes_from_argument(config.mode)
        ]
    except ValueError as error:
        print(f"error: {error}", file=sys.stderr)
        return 2

    if config.json_output:
        print_json_results(results)
    else:
        print("LangoTrace OpenAI-compatible API probe")
        print(f"Base URL: {normalize_base_url(config.base_url)}")
        print(f"Model: {config.model}")
        print("API key: <redacted>")
        for result in results:
            print_human_result(result)

    return 0 if all(result.ok for result in results) else 1


if __name__ == "__main__":
    raise SystemExit(main())
