#!/usr/bin/env python3
import os
import unittest
import json
from utils import load_dotenv, get_env_or_fail, make_request

class TestJsonOutput(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        load_dotenv()
        cls.api_key = get_env_or_fail("AI_PROVIDER_API_KEY")
        cls.base_url = get_env_or_fail("AI_PROVIDER_BASE_URL").rstrip('/')
        cls.model = get_env_or_fail("AI_PROVIDER_TEXT_MODEL")
        cls.endpoint = f"{cls.base_url}/chat/completions"

    def test_json_output_mode(self):
        payload = {
            "model": self.model,
            "messages": [
                {"role": "user", "content": "Configuration test. Return a single JSON object with exactly one field named ok. The value must be the boolean true. Do not include markdown, code fences, or any other text."}
            ],
            "response_format": { "type": "json_object" },
            "temperature": 0.0
        }
        
        print(f"\n[JSON Output] Requesting {self.endpoint} with model {self.model} in JSON mode...")
        response = make_request(self.endpoint, payload, self.api_key)
        
        self.assertIn("choices", response)
        self.assertTrue(len(response["choices"]) > 0)
        
        content = response["choices"][0].get("message", {}).get("content", "")
        
        try:
            parsed = json.loads(content)
            self.assertIn("ok", parsed)
            self.assertEqual(parsed["ok"], True)
            print(f"[JSON Output] Success! Received valid JSON: {content.strip()}")
        except json.JSONDecodeError:
            self.fail(f"Model did not return valid JSON: {content}")

if __name__ == '__main__':
    unittest.main()
