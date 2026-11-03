r"""A boss's spoken lines (the boss's replies of scripts/core/boss_talk.gd) by Google Gemini TTS (the keys of the AnyVideo app's settings.json) into
assets/Puppet/Voice/<boss>/<node id>.wav, or <id>_a.wav then <id>_b.wav when the node has a second reply (BossTalk.voice_paths finds them by those names).
First: godot --headless --path . --script res://tools/dump_boss_talk.gd -- <json> invoker
Then (any Python 3):  python tools/make_boss_voice.py <json> invoker [--redo]     (the Handyman has his own recorded take: tools/split_handyman_voice.py)
Run with a Python that has numpy + soundfile (D:\GitHub Projects\AnySFX\backend\.venv\Scripts\python.exe): every clip goes through loudness.loudify, like the Handyman's, so the voices sit at the same level.
Lines that already have a file are skipped. Free tier: ~10 requests a day per model per key; a 429 goes on to the next key."""
import json
import sys
import wave
import urllib.error
from pathlib import Path

import soundfile as sf

sys.path.insert(0, str(Path(__file__).resolve().parent))
import make_merchant_voice as mv
from loudness import loudify

ROOT = Path(__file__).resolve().parent.parent
SPEAKERS = {
    "invoker": ("Gacrux", "A weary, ancient, kindly wizard, a deep, tired, gravelly old man's voice, resigned and gentle, a little worried; slow, with a sigh now and then. Never shouting, except the first line, which is a firm, bellowing warning."),
}


def say(path: Path, text: str, boss: str, keys: list) -> bool:
    if path.exists() and "--redo" not in sys.argv:
        return True
    voice, style = SPEAKERS[boss]
    mv.TEXT = text
    mv.STYLE = style
    for key in keys:
        for v in (voice, "Algenib"):
            try:
                raw, mime = mv.speak(v, key)
            except urllib.error.HTTPError as e:
                print("   HTTP", e.code, "with", v)
                if e.code == 429:
                    break
                continue
            rate = int(mime.split("rate=")[1].split(";")[0]) if mime and "rate=" in mime else 24000
            if raw[:4] == b"RIFF":
                path.write_bytes(raw)
            else:
                with wave.open(str(path), "wb") as w:
                    w.setnchannels(1)
                    w.setsampwidth(2)
                    w.setframerate(rate)
                    w.writeframes(raw)
            clip, sr = sf.read(str(path), always_2d=True)
            sf.write(str(path), loudify(clip, sr), sr, subtype="PCM_16")
            print("ok ", path.name, "|", text[:60])
            return True
    print("FAILED", path.name)
    return False


def main() -> None:
    lines = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
    boss = sys.argv[2]
    keys = json.loads(mv.SETTINGS.read_text(encoding="utf-8")).get("google_api_keys", [])
    if isinstance(keys, str):
        keys = [k.strip() for k in keys.replace(",", "\n").split() if k.strip()]
    out = ROOT / "assets" / "Puppet" / "Voice" / boss
    out.mkdir(parents=True, exist_ok=True)
    bad = 0
    for ln in lines:
        if ln["reply2"]:
            jobs = [(out / (ln["id"] + "_a.wav"), ln["reply"]), (out / (ln["id"] + "_b.wav"), ln["reply2"])]
        else:
            jobs = [(out / (ln["id"] + ".wav"), ln["reply"])]
        for path, text in jobs:
            if not say(path, text, boss, keys):
                bad += 1
    print("done, %d failed" % bad)


if __name__ == "__main__":
    main()
