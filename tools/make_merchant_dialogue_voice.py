"""Voices every line the merchant says in his favours (scripts/core/merchant_quests.gd) with Google Gemini TTS, the same voice as his greeting.

Each spoken line becomes assets/Puppet/SFX/Merchant Voice/mv_<md5 of the line, 8 hex>.wav (ShopScreen plays the file named after the line it shows, see
ShopScreen._say). Lines that already have a file are skipped, so a run can be repeated after the daily quota of the keys is used up (free tier: ~10 requests a
day per model per key; the keys are the ones of the AnyVideo app's settings.json). Raw answers are kept in assets/Puppet/SFX/_Candidates/dialogue_raw/.
    python tools/make_merchant_dialogue_voice.py [--voice Gacrux] [--redo]
Needs ffmpeg on the PATH. The finished files are levelled to the same loudness (-20 LUFS) at 44.1 kHz stereo.
"""
import argparse
import hashlib
import json
import re
import subprocess
import sys
import time
import urllib.error
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import make_merchant_voice as V  # noqa: E402  (the API call and the key list live there)

ROOT = Path(__file__).resolve().parent.parent
SRC = ROOT / "scripts" / "core" / "merchant_quests.gd"
OUT = ROOT / "assets" / "Puppet" / "SFX" / "Merchant Voice"
RAW = ROOT / "assets" / "Puppet" / "SFX" / "_Candidates" / "dialogue_raw"

BASE = "An old travelling merchant: jolly, warm, a slightly raspy voice, speaking English at an easy pace. "
STYLES = {
    "ASK": "Wistful and earnest, an old man asking a favour of a friend. ",
    "ACCEPTED": "Moved and grateful, a little choked up. ",
    "SEE": "Astonished and delighted. ",
    "THANKS": "Deeply moved and grateful, warm, a little choked up. ",
    "REMIND": "Friendly, gently teasing. ",
    "LATER": "Friendly, gently teasing. ",
    "DRUNK": "Tipsy and cheerful, slurring a little, with a hiccup now and then. ",
}


def spoken(text: str) -> str:
    """What the voice should say: the stage directions go (the hiccup is spelled out)."""
    return re.sub(r"\*hic\*", "hic!", text).strip()


def lines() -> list:
    """[(group, text)] in the order of the file. Only the groups in STYLES are spoken (buttons and narration are not)."""
    src = SRC.read_text(encoding="utf-8")
    out = []
    for name in STYLES:
        m = re.search(r"^const %s := (.*?)(?=^const |^\n|\Z)" % name, src, re.S | re.M)
        if not m:
            sys.exit("not found in merchant_quests.gd: " + name)
        for s in re.findall(r'"((?:[^"\\]|\\.)*)"', m.group(1)):
            out.append((name, s.encode().decode("unicode_escape") if "\\" in s else s))
    return out


def key_of(text: str) -> str:
    return hashlib.md5(text.encode("utf-8")).hexdigest()[:8]  # (String.md5_text() in Godot is the md5 of the UTF-8 bytes)


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--voice", default="Gacrux")
    ap.add_argument("--redo", action="store_true")
    args = ap.parse_args()
    keys = json.loads(V.SETTINGS.read_text(encoding="utf-8")).get("google_api_keys", [])
    if isinstance(keys, str):
        keys = [k.strip() for k in keys.replace(",", "\n").split() if k.strip()]
    OUT.mkdir(parents=True, exist_ok=True)
    RAW.mkdir(parents=True, exist_ok=True)
    manifest = {}
    blocked = set()
    todo = lines()
    for n, (group, text) in enumerate(todo, 1):
        k = key_of(text)
        manifest[k] = text
        final = OUT / f"mv_{k}.wav"
        if final.exists() and not args.redo:
            continue
        done = False
        for i, key in enumerate(keys):
            if i in blocked:
                continue
            V.STYLE = BASE + STYLES[group]
            V.TEXT = spoken(text)
            try:
                raw, mime = V.speak(args.voice, key)
            except urllib.error.HTTPError as e:
                detail = e.read().decode("utf-8", "replace")
                print(f"[{n}/{len(todo)}] key {i + 1}: HTTP {e.code} {detail[:100]}")
                if e.code == 429 and "per day" in detail:
                    blocked.add(i)
                continue
            except Exception as e:  # noqa: BLE001
                print(f"[{n}/{len(todo)}] key {i + 1}: {e}")
                continue
            rate = 24000
            if raw[:4] != b"RIFF":
                if "rate=" in (mime or ""):
                    rate = int(mime.split("rate=")[1].split(";")[0])
                rawfile = RAW / f"mv_{k}.pcm"
                rawfile.write_bytes(raw)
                src_args = ["-f", "s16le", "-ar", str(rate), "-ac", "1", "-i", str(rawfile)]
            else:
                rawfile = RAW / f"mv_{k}.wav"
                rawfile.write_bytes(raw)
                src_args = ["-i", str(rawfile)]
            subprocess.run(["ffmpeg", "-v", "error", "-y", *src_args, "-ar", "44100", "-ac", "2",
                            "-af", "loudnorm=I=-20:TP=-3:LRA=9", str(final)], check=True)
            print(f"[{n}/{len(todo)}] {group} ok (key {i + 1}): {text[:50]}")
            done = True
            time.sleep(1.0)
            break
        if not done:
            print(f"[{n}/{len(todo)}] NOT DONE (every key is out of quota or failing): {text[:50]}")
    (OUT / "lines.json").write_text(json.dumps(manifest, indent=1, ensure_ascii=False), encoding="utf-8")
    have = sum(1 for k in manifest if (OUT / f"mv_{k}.wav").exists())
    print(f"{have}/{len(manifest)} lines have a voice")


if __name__ == "__main__":
    main()
