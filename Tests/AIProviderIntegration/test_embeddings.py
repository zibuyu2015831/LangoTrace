#!/usr/bin/env python3
import os
import unittest
from utils import load_dotenv, get_env_or_fail, make_request

class TestEmbeddings(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        load_dotenv()
        cls.api_key = get_env_or_fail("AI_PROVIDER_API_KEY")
        cls.base_url = get_env_or_fail("AI_PROVIDER_BASE_URL").rstrip('/')
        cls.model = get_env_or_fail("AI_PROVIDER_EMBEDDING_MODEL")
        cls.endpoint = f"{cls.base_url}/embeddings"

    def test_basic_embedding(self):
        payload = {
            "model": self.model,
            "input": "LangoTrace embedding configuration test."
        }
        
        print(f"\n[Embeddings] Requesting {self.endpoint} with model {self.model}...")
        response = make_request(self.endpoint, payload, self.api_key)
        
        self.assertIn("data", response)
        self.assertTrue(len(response["data"]) > 0)
        
        embedding = response["data"][0].get("embedding", [])
        self.assertTrue(isinstance(embedding, list))
        self.assertTrue(len(embedding) > 0)
        print(f"[Embeddings] Success! Received vector of length {len(embedding)}.")

if __name__ == '__main__':
    unittest.main()
