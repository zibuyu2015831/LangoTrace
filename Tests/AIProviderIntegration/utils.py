import os
import urllib.request
import urllib.error
import json

def load_dotenv(path: str = ".env"):
    """Simple parser for .env files to avoid external dependencies."""
    try:
        with open(path) as f:
            for line in f:
                line = line.strip()
                if line and not line.startswith('#') and '=' in line:
                    key, value = line.split('=', 1)
                    os.environ[key.strip()] = value.strip().strip("'\"")
    except FileNotFoundError:
        print(f"Warning: {path} not found. Ensure environment variables are set.")

def get_env_or_fail(key: str) -> str:
    value = os.environ.get(key)
    if not value:
        raise ValueError(f"Missing required environment variable: {key}")
    return value

def make_request(url: str, payload: dict, api_key: str) -> dict:
    """Helper to make a JSON POST request and return the JSON response."""
    data = json.dumps(payload).encode('utf-8')
    req = urllib.request.Request(
        url,
        data=data,
        headers={
            "Authorization": f"Bearer {api_key}",
            "Content-Type": "application/json",
            "Accept": "application/json"
        },
        method="POST"
    )
    
    try:
        with urllib.request.urlopen(req, timeout=30) as response:
            return json.loads(response.read().decode('utf-8'))
    except urllib.error.HTTPError as e:
        error_body = e.read().decode('utf-8')
        raise RuntimeError(f"HTTP Error {e.code}: {error_body}")
