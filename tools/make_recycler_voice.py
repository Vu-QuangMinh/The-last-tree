"""The Recycler's two lines, spoken by Google Gemini TTS (the keys of the AnyVideo app's settings.json) -> assets/Puppet/SFX/recycler_reuse.wav / recycler_trade.wav.
Run with any Python 3: python tools/make_recycler_voice.py [Voice]   (free tier: ~10 requests a day per model per key, so the keys are tried in turn)"""
import sys
import wave
import urllib.error
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import make_merchant_voice as mv

OUT = Path(__file__).resolve().parent.parent / "assets" / "Puppet" / "SFX"
STYLE = "A cheerful, bubbly, energetic old junk collector, grinning from ear to ear, loud and merry like a street vendor shouting his wares, big smile in the voice."
LINES = {"recycler_reuse": "Reuse! Reduce! Recycle!", "recycler_trade": "Wanna trade something?"}


def main() -> None:
    voice = sys.argv[1] if len(sys.argv) > 1 else "Puck"
    keys = mv.json.loads(mv.SETTINGS.read_text(encoding="utf-8")).get("google_api_keys", [])
    if isinstance(keys, str):
        keys = [k.strip() for k in keys.replace(",", "\n").split() if k.strip()]
    mv.STYLE = STYLE
    for name, text in LINES.items():
        mv.TEXT = text
        for i, key in enumerate(keys):
            try:
                raw, mime = mv.speak(voice, key)
            except urllib.error.HTTPError as e:
                print(name, "key", i + 1, "HTTP", e.code)
                continue
            rate = int(mime.split("rate=")[1].split(";")[0]) if mime and "rate=" in mime else 24000
            path = OUT / (name + ".wav")
            if raw[:4] == b"RIFF":
                path.write_bytes(raw)
            else:
                with wave.open(str(path), "wb") as w:
                    w.setnchannels(1)
                    w.setsampwidth(2)
                    w.setframerate(rate)
                    w.writeframes(raw)
            print(name, "ok with key", i + 1)
            break


if __name__ == "__main__":
    main()
