#!/usr/bin/env python3
import os
import unittest
from utils import load_dotenv, get_env_or_fail, make_request

class TestTextInteraction(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        load_dotenv()
        cls.api_key = get_env_or_fail("AI_PROVIDER_API_KEY")
        cls.base_url = get_env_or_fail("AI_PROVIDER_BASE_URL").rstrip('/')
        cls.model = get_env_or_fail("AI_PROVIDER_TEXT_MODEL")
        cls.endpoint = f"{cls.base_url}/chat/completions"

    def test_basic_chat_completion(self):
        payload = {
            "model": self.model,
            "messages": [
                {"role": "user", "content": "Configuration test. Reply with OK only."}
            ],
            "temperature": 0.0,
            "max_tokens": 10
        }
        
        print(f"\n[Text Interaction] Requesting {self.endpoint} with model {self.model}...")
        response = make_request(self.endpoint, payload, self.api_key)
        
        self.assertIn("choices", response)
        self.assertTrue(len(response["choices"]) > 0)
        
        content = response["choices"][0].get("message", {}).get("content", "")
        self.assertTrue("OK" in content.upper(), f"Unexpected response: {content}")
        print(f"[Text Interaction] Success! Response: {content.strip()}")

if __name__ == '__main__':
    unittest.main()
