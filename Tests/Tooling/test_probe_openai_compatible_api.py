#!/usr/bin/env python3
"""Unit tests for scripts/probe_openai_compatible_api.py."""

from __future__ import annotations

import contextlib
import io
import importlib.util
import json
from pathlib import Path
import sys
import unittest


SCRIPT_PATH = Path(__file__).resolve().parents[2] / "scripts" / "probe_openai_compatible_api.py"
spec = importlib.util.spec_from_file_location("probe_openai_compatible_api", SCRIPT_PATH)
probe = importlib.util.module_from_spec(spec)
assert spec.loader is not None
sys.modules[spec.name] = probe
spec.loader.exec_module(probe)


class FakeHTTPResponse:
    def __init__(self, status: int, payload: dict[str, object]) -> None:
        self.status = status
        self._payload = payload

    def read(self) -> bytes:
        return json.dumps(self._payload).encode("utf-8")

    def __enter__(self) -> "FakeHTTPResponse":
        return self

    def __exit__(self, exc_type, exc, traceback) -> bool:
        return False


class ProbeOpenAICompatibleAPITests(unittest.TestCase):
    def test_normalizes_base_url_without_duplicate_v1(self) -> None:
        self.assertEqual(
            probe.build_endpoint_url("https://example.test", "chat"),
            "https://example.test/v1/chat/completions",
        )
        self.assertEqual(
            probe.build_endpoint_url("https://example.test/v1/", "responses"),
            "https://example.test/v1/responses",
        )

    def test_chat_request_uses_bearer_auth_without_printing_secret(self) -> None:
        request = probe.build_request(
            base_url="https://example.test",
            api_key="sk-secret",
            model="demo-model",
            mode="chat",
            timeout_seconds=20,
        )

        self.assertEqual(request.full_url, "https://example.test/v1/chat/completions")
        self.assertEqual(request.headers["Authorization"], "Bearer sk-secret")
        body = json.loads(request.data.decode("utf-8"))
        self.assertEqual(body["model"], "demo-model")
        self.assertNotIn("sk-secret", json.dumps(body))

    def test_embeddings_request_uses_fixed_low_sensitivity_payload(self) -> None:
        request = probe.build_request(
            base_url="https://example.test/v1",
            api_key="sk-secret",
            model="text-embedding-3-small",
            mode="embeddings",
            timeout_seconds=20,
        )

        self.assertEqual(request.full_url, "https://example.test/v1/embeddings")
        self.assertEqual(request.headers["Authorization"], "Bearer sk-secret")
        body = json.loads(request.data.decode("utf-8"))
        self.assertEqual(body["model"], "text-embedding-3-small")
        self.assertEqual(body["input"], "LangoTrace embedding configuration test.")
        self.assertEqual(body["encoding_format"], "float")
        self.assertNotIn("sk-secret", json.dumps(body))
        self.assertNotIn("life record", json.dumps(body))

    def test_chat_success_is_detected_from_message_content(self) -> None:
        calls = []

        def opener(request, timeout):
            calls.append((request.full_url, timeout))
            return FakeHTTPResponse(
                200,
                {"choices": [{"message": {"content": "OK"}}]},
            )

        result = probe.run_probe(
            base_url="https://example.test",
            api_key="sk-secret",
            model="demo-model",
            mode="chat",
            timeout_seconds=7,
            opener=opener,
        )

        self.assertTrue(result.ok)
        self.assertEqual(result.category, "success")
        self.assertEqual(calls, [("https://example.test/v1/chat/completions", 7)])
        self.assertNotIn("sk-secret", result.detail)

    def test_embeddings_success_reports_only_vector_length(self) -> None:
        calls = []

        def opener(request, timeout):
            calls.append((request.full_url, timeout))
            return FakeHTTPResponse(
                200,
                {"data": [{"embedding": [0.1, 0.2, 0.3]}]},
            )

        result = probe.run_probe(
            base_url="https://example.test",
            api_key="sk-secret",
            model="text-embedding-3-small",
            mode="embeddings",
            timeout_seconds=7,
            opener=opener,
        )

        self.assertTrue(result.ok)
        self.assertEqual(result.category, "success")
        self.assertEqual(result.vector_length, 3)
        self.assertEqual(calls, [("https://example.test/v1/embeddings", 7)])
        self.assertNotIn("sk-secret", result.detail)
        self.assertNotIn("0.1", result.detail)

    def test_json_output_for_embeddings_does_not_include_vector_or_secret(self) -> None:
        result = probe.ProbeResult(
            mode="embeddings",
            ok=True,
            category="success",
            detail="Embedding vector length: 3",
            duration_ms=12,
            vector_length=3,
        )
        output = io.StringIO()

        with contextlib.redirect_stdout(output):
            probe.print_json_results([result])

        rendered = output.getvalue()
        data = json.loads(rendered)
        self.assertEqual(data[0]["vector_length"], 3)
        self.assertNotIn("sk-secret", rendered)
        self.assertNotIn("[0.1", rendered)
        self.assertNotIn("embedding\":[", rendered)

    def test_http_401_is_classified_as_authentication_failed(self) -> None:
        def opener(request, timeout):
            raise probe.HTTPError(
                request.full_url,
                401,
                "Unauthorized",
                hdrs=None,
                fp=None,
            )

        result = probe.run_probe(
            base_url="https://example.test",
            api_key="sk-secret",
            model="demo-model",
            mode="chat",
            timeout_seconds=7,
            opener=opener,
        )

        self.assertFalse(result.ok)
        self.assertEqual(result.category, "authentication_failed")
        self.assertNotIn("sk-secret", result.detail)

    def test_default_opener_passes_timeout_as_keyword(self) -> None:
        calls = []
        original_urlopen = probe.urlopen

        def fake_urlopen(request, **kwargs):
            calls.append((request, kwargs))
            return FakeHTTPResponse(200, {"choices": [{"message": {"content": "OK"}}]})

        try:
            probe.urlopen = fake_urlopen
            request = probe.build_request(
                base_url="https://example.test",
                api_key="sk-secret",
                model="demo-model",
                mode="chat",
                timeout_seconds=3,
            )
            response = probe.default_opener(request, 3)
        finally:
            probe.urlopen = original_urlopen

        self.assertEqual(response.status, 200)
        self.assertEqual(calls, [(request, {"timeout": 3})])

    def test_interactive_config_prompts_for_required_values_with_visible_key_input(self) -> None:
        prompts = []
        answers = iter(["https://example.test/v1", "sk-secret", "demo-model"])

        def input_fn(prompt):
            prompts.append(prompt)
            return next(answers)

        with contextlib.redirect_stdout(io.StringIO()):
            config = probe.collect_interactive_config(
                input_fn=input_fn,
            )

        self.assertEqual(config.base_url, "https://example.test/v1")
        self.assertEqual(config.model, "demo-model")
        self.assertEqual(config.api_key, "sk-secret")
        self.assertEqual(config.mode, "chat")
        self.assertEqual(config.timeout, 30)
        self.assertIn("Base URL", prompts[0])
        self.assertEqual(prompts[1], "API key: ")
        self.assertIn("Model", prompts[2])


if __name__ == "__main__":
    unittest.main()
