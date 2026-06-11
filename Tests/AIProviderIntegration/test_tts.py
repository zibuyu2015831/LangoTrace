#!/usr/bin/env python3
import os
import unittest
import urllib.request
import urllib.error
import json
from utils import load_dotenv, get_env_or_fail

class TestTTS(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        load_dotenv()
        cls.api_key = get_env_or_fail("AI_PROVIDER_API_KEY")
        cls.base_url = get_env_or_fail("AI_PROVIDER_BASE_URL").rstrip('/')
        cls.model = get_env_or_fail("AI_PROVIDER_TTS_MODEL")
        cls.voice = os.environ.get("AI_PROVIDER_TTS_VOICE", "alloy")
        cls.endpoint = f"{cls.base_url}/audio/speech"

    def test_tts_generation(self):
        payload = {
            "model": self.model,
            "input": "Today I wrote one short sentence for practice.",
            "voice": self.voice,
            "response_format": "mp3"
        }
        
        data = json.dumps(payload).encode('utf-8')
        req = urllib.request.Request(
            self.endpoint,
            data=data,
            headers={
                "Authorization": f"Bearer {self.api_key}",
                "Content-Type": "application/json"
            },
            method="POST"
        )
        
        print(f"\n[TTS] Requesting {self.endpoint} with model {self.model} and voice {self.voice}...")
        
        try:
            with urllib.request.urlopen(req, timeout=30) as response:
                self.assertEqual(response.status, 200)
                audio_data = response.read()
                self.assertTrue(len(audio_data) > 1000) # Ensure we got some bytes back
                
                # Verify basic MP3 magic number or just content type
                content_type = response.headers.get('Content-Type', '')
                self.assertTrue('audio' in content_type or 'mpeg' in content_type or 'octet-stream' in content_type)
                print(f"[TTS] Success! Received {len(audio_data)} bytes of audio data.")
        except urllib.error.HTTPError as e:
            error_body = e.read().decode('utf-8')
            self.fail(f"HTTP Error {e.code}: {error_body}")

if __name__ == '__main__':
    unittest.main()
