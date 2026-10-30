"""The merchant's greeting, spoken by Google Gemini TTS (the keys of the AnyVideo app's settings.json), into assets/Puppet/SFX/_Candidates/merchant_voice_<voice>.wav.
Each run asks the API once per voice (free tier: ~10 requests a day per model per key). Pick one by copying it to assets/Puppet/SFX/merchant_greeting.wav.
Run with any Python 3: python tools/make_merchant_voice.py [Voice ...]
"""
import base64
import json
import sys
import urllib.error
import urllib.request
import wave
from pathlib import Path

SETTINGS = Path(r"D:\GitHub Projects\AnyVideo\settings.json")
OUT = Path(__file__).resolve().parent.parent / "assets" / "Puppet" / "SFX" / "_Candidates"
MODEL = "gemini-3.8-flash-tts"
TEXT = "Greetings, my friend!"
STYLE = "A warm, jolly old travelling merchant with a slightly raspy voice; welcoming, with a little chuckle in it. Not too fast."
VOICES = ["Gacrux", "Algenib", "Achird", "Sulafat"]


def find_audio(node):
    if isinstance(node, dict):
        d = node.get("data")
        if isinstance(d, str) and len(d) > 1000:
            return d, node.get("mime_type") or node.get("mimeType")
        for v in node.values():
            f = find_audio(v)
            if f:
                return f
    elif isinstance(node, list):
        for v in node:
            f = find_audio(v)
            if f:
                return f
    return None


def speak(voice: str, key: str) -> bytes:
    body = {
        "model": MODEL,
        "input": [{"type": "user_input", "content": [
            {"type": "text", "text": TEXT, "annotations": [{"type": "speech_metadata", "style": STYLE}]}]}],
        "response_format": {"type": "audio"},
        "generation_config": {"speech_config": [{"voice": voice}], "temperature": 1.0},
    }
    req = urllib.request.Request("https://generativelanguage.googleapis.com/v1beta/interactions", json.dumps(body).encode(),
                                 {"x-goog-api-key": key, "Content-Type": "application/json"})
    with urllib.request.urlopen(req, timeout=240) as r:
        resp = json.load(r)
    found = find_audio(resp)
    if not found:
        raise RuntimeError("no audio in the answer")
    return base64.b64decode(found[0]), found[1]


def main() -> None:
    keys = json.loads(SETTINGS.read_text(encoding="utf-8")).get("google_api_keys", [])
    if isinstance(keys, str):
        keys = [k.strip() for k in keys.replace(",", "\n").split() if k.strip()]
    OUT.mkdir(parents=True, exist_ok=True)
    for voice in (sys.argv[1:] or VOICES):
        for i, key in enumerate(keys):
            try:
                raw, mime = speak(voice, key)
            except urllib.error.HTTPError as e:
                print(voice, "key", i + 1, "HTTP", e.code, e.read().decode("utf-8", "replace")[:120])
                continue
            path = OUT / f"merchant_voice_{voice}.wav"
            if raw[:4] == b"RIFF":
                path.write_bytes(raw)
            else:
                rate = 24000
                if "rate=" in (mime or ""):
                    rate = int(mime.split("rate=")[1].split(";")[0])
                with wave.open(str(path), "wb") as w:
                    w.setnchannels(1)
                    w.setsampwidth(2)
                    w.setframerate(rate)
                    w.writeframes(raw)
            print(voice, "ok with key", i + 1, "->", path.name)
            break
        else:
            print(voice, "FAILED with every key")


if __name__ == "__main__":
    main()
