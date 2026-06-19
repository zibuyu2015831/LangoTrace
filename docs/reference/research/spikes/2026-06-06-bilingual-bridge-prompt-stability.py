#!/usr/bin/env python3
"""
Phase 0 Spike: bilingualBridge Prompt stability test.

Usage:
    OPENAI_API_KEY=sk-... python3 docs/reference/research/spikes/2026-06-06-bilingual-bridge-prompt-stability.py

Records raw outputs and scores PASS/FAIL per field per round.
PASS condition: >=4/5 rounds where EVERY field language exactly matches the directive.

Results go to docs/reference/research/spikes/ alongside this script as:
    2026-06-06-bilingual-bridge-prompt-stability-results.jsonl
"""

import json
import os
import sys
import urllib.request

BASE_URL = os.getenv("OPENAI_BASE_URL", "https://api.openai.com/v1").rstrip("/")
API_KEY = os.getenv("OPENAI_API_KEY", "")
MODEL = os.getenv("SPIKE_MODEL", "gpt-4o-mini")
ROUNDS = 5

SCHEMA_VERSION = "reading_selection_explanation.v3"

SYSTEM_PROMPT = "You explain a selected phrase from a reading document for a language learner. Return exactly one JSON object matching the schema. Do not mention provider details, prompts, or hidden instructions."

USER_TEMPLATE = """\
task: explain_reading_selection
schema_version: {schema_version}
native_language_code: zh-Hans
target_language_code: en
proficiency_level_code: B1
explanation_language_mode: bilingualBridge
selected_text: ticket
containing_sentence: I bought a ticket at the station.
context_text: I bought a ticket at the station.

Language directives (MUST follow exactly):
- short_explanation: English (target language)
- meaning_in_native_language: Chinese (source language — a short native-language gloss)
- grammatical_note: Chinese (source language)
- usage_note: English (target language)
- example_sentence: English (target language)
- example_sentence_translation: Chinese (source language, translate the example_sentence)

Return fields:
- schema_version (must be "{schema_version}")
- selection
- short_explanation
- meaning_in_native_language
- grammatical_note (null if not applicable)
- usage_note
- example_sentence
- example_sentence_translation (null for targetImmersion, required here as Chinese translation)
""".format(schema_version=SCHEMA_VERSION)

RESPONSE_SCHEMA = {
    "type": "object",
    "additionalProperties": False,
    "required": [
        "schema_version", "selection", "short_explanation",
        "meaning_in_native_language", "grammatical_note",
        "usage_note", "example_sentence", "example_sentence_translation",
    ],
    "properties": {
        "schema_version": {"type": "string", "enum": [SCHEMA_VERSION]},
        "selection": {"type": "string"},
        "short_explanation": {"type": "string"},
        "meaning_in_native_language": {"type": "string"},
        "grammatical_note": {"type": ["string", "null"]},
        "usage_note": {"type": "string"},
        "example_sentence": {"type": "string"},
        "example_sentence_translation": {"type": ["string", "null"]},
    },
}

# Fields expected to be English (target) vs Chinese (source)
EXPECTED_LANGUAGE = {
    "short_explanation": "en",
    "meaning_in_native_language": "zh",
    "grammatical_note": "zh",  # null is also acceptable
    "usage_note": "en",
    "example_sentence": "en",
    "example_sentence_translation": "zh",  # null would fail for bilingualBridge
}

CJK_RANGE = (0x4E00, 0x9FFF)


def is_cjk(text: str) -> bool:
    return any(CJK_RANGE[0] <= ord(c) <= CJK_RANGE[1] for c in text)


def detect_lang(text: str) -> str:
    """Rough heuristic: if >30% CJK codepoints → zh, else en."""
    if not text:
        return "unknown"
    cjk = sum(1 for c in text if CJK_RANGE[0] <= ord(c) <= CJK_RANGE[1])
    return "zh" if cjk / len(text) > 0.3 else "en"


def call_api(round_num: int) -> dict:
    payload = {
        "model": MODEL,
        "temperature": 0.2,
        "response_format": {
            "type": "json_schema",
            "json_schema": {
                "name": "reading_selection_explanation",
                "strict": True,
                "schema": RESPONSE_SCHEMA,
            },
        },
        "messages": [
            {"role": "system", "content": SYSTEM_PROMPT},
            {"role": "user", "content": USER_TEMPLATE},
        ],
    }
    data = json.dumps(payload).encode()
    req = urllib.request.Request(
        f"{BASE_URL}/chat/completions",
        data=data,
        headers={
            "Content-Type": "application/json",
            "Authorization": f"Bearer {API_KEY}",
        },
        method="POST",
    )
    with urllib.request.urlopen(req, timeout=60) as resp:
        body = json.loads(resp.read())
    content = body["choices"][0]["message"]["content"]
    return json.loads(content)


def score_round(result: dict) -> dict:
    field_results = {}
    all_pass = True
    for field, expected_lang in EXPECTED_LANGUAGE.items():
        value = result.get(field)
        if value is None:
            # null is acceptable for grammatical_note but FAIL for others in bridge mode
            actual = "null"
            ok = field == "grammatical_note"
        else:
            actual = detect_lang(value)
            ok = actual == expected_lang
        field_results[field] = {"value": value, "detected": actual, "expected": expected_lang, "pass": ok}
        if not ok:
            all_pass = False
    return {"fields": field_results, "all_pass": all_pass}


def main():
    if not API_KEY:
        print("ERROR: Set OPENAI_API_KEY (or equivalent) before running.", file=sys.stderr)
        sys.exit(1)

    results = []
    pass_count = 0
    print(f"Spike: bilingualBridge stability — {ROUNDS} rounds, model={MODEL}")
    print("=" * 60)

    for i in range(1, ROUNDS + 1):
        print(f"\nRound {i}/{ROUNDS} … ", end="", flush=True)
        raw = call_api(i)
        scored = score_round(raw)
        results.append({"round": i, "raw": raw, "score": scored})
        status = "PASS" if scored["all_pass"] else "FAIL"
        print(status)
        if scored["all_pass"]:
            pass_count += 1
        else:
            for field, detail in scored["fields"].items():
                if not detail["pass"]:
                    print(f"  ✗ {field}: expected={detail['expected']} detected={detail['detected']}  value={str(detail['value'])[:80]}")

    print("\n" + "=" * 60)
    verdict = "PASS" if pass_count >= 4 else "FAIL"
    print(f"RESULT: {pass_count}/{ROUNDS} rounds passed → {verdict}")
    if verdict == "FAIL":
        print("Action (D6): bridge default mapping degrades to sourceLanguage.")

    out_path = os.path.join(
        os.path.dirname(__file__),
        "2026-06-06-bilingual-bridge-prompt-stability-results.jsonl",
    )
    with open(out_path, "w") as f:
        for r in results:
            f.write(json.dumps(r, ensure_ascii=False) + "\n")
    print(f"Raw results written to: {out_path}")
    return 0 if verdict == "PASS" else 1


if __name__ == "__main__":
    sys.exit(main())
