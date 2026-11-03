"""The voices of the "?" events (the Turtle, the Farmer, the priest of Church of Aole, the Wax Witch, the Rolling Bear, the pond spirit, the boy of the Mystery Shed), spoken by Google Gemini TTS (the keys of the
AnyVideo app's settings.json) into assets/Puppet/SFX/Event Voice/evv_<md5 of the text shown>.wav (EventStage.speak finds them by that name).
First run `godot --headless --path . --script res://tools/dump_event_texts.gd -- <json> flying_turtle turtle_falls farmer_farm church_of_aole` to get the texts.
Run with any Python 3: python tools/make_event_voice.py <texts.json> [--redo]    (free tier: ~10 requests a day per model per key; lines that already have a file are skipped)"""
import hashlib
import json
import re
import sys
import wave
import urllib.error
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import make_merchant_voice as mv

OUT = Path(__file__).resolve().parent.parent / "assets" / "Puppet" / "SFX" / "Event Voice"
SPEAKERS = {
    "turtle": ("Fenrir", "A grumpy, sarcastic, insulting old flying turtle, nasal and cranky, hamming it up like a cartoon curmudgeon; fast and snappy."),
    "farmer": ("Sadaltager", "A tired, sad, worn-out old farmer, soft and hoarse, pleading; a little hopeful when he asks for help."),
    "priest": ("Charon", "The oldest, frailest priest imaginable, a man a breath away from death: a thin, cracked, wheezing, quavering whisper of a voice with long shaky pauses to catch his breath, trembling and toothless, barely audible; still warm and proud when he tells his story, very slow, never strong or loud."),
    "sprite": ("Leda", "A tiny, delicate fairy, a small, high, thin, breathy and frightened voice, pleading, a little tearful; fairly slow."),
    "witch": ("Enceladus", "A mysterious witch whispering right into your mind: slow, breathy, eerie, raspy whisper."),
    "bear_angry": ("Algenib", "A huge bear, a deep, low, gravelly male voice, furious and menacing: a growling snarl full of rage, slow and heavy, spitting each word like a threat; no laughing, no cheerfulness."),
    "bear_deep": ("Algenib", "A huge, friendly old bear, a deep, low, warm, gravelly male voice; theatrical and emotional, grateful or hurt and sad as the line asks, slow and heavy; not angry, not shouting."),
    "fisher": ("Sadaltager", "A starving, ragged, skeletal old fisherman, thin and raspy, weak but eager, a little dark humour; slow."),
    "stump": ("Fenrir", "A grumpy little creature living inside a tree stump, a gruff hillbilly drawl, annoyed and shouting through a hole; fast, then calm at the end."),
    "spirit": ("Sulafat", "A small, vain, bubbly pond spirit, a wet, whiny, melodramatic voice: pleading, outraged when insulted, then delighted and gushing when pleased; fairly fast."),
    "boy": ("Puck", "A smug little boy, flat and bored, sneering with a pleased-with-himself drawl; short and dismissive."),
    "bear": ("Puck", "A big, dramatic, comical, tearful-then-furious round bear, theatrical and over the top."),
}
EVENT_SPEAKER = {"flying_turtle": "turtle", "turtle_falls": "turtle", "farmer_farm": "farmer", "church_of_aole": "priest", "elemental_fishing": "fisher", "hollow_stump": "stump", "shrinking_pond": "spirit", "mystery_shack": "boy"}
FISHER_LINES = ["Here, take them, you've earned them."]  # (EventStage.SPOKEN_PARTS: said inside the tally, whose other words change with the catch)
FARMER_LINES = ["And not a single fairy hurt. Bless you.", "You've earned every one of them.", "Well, thank you for trying, I suppose.", "The fairies' families will need them more than you."]  # (the fixed ends of his tally, whose numbers change: EventStage.SPOKEN_PARTS)
BEAR_ANGRY_LINES = ["Behold, heartless stranger!", "I have come for revenge!"]
BEAR_LINES = ["Thank you, stranger!", "Here, for your trouble.", "Why didn't you help me? Whyyyyyy..."]


def key_of(text: str) -> str:
    return "evv_" + hashlib.md5(text.encode("utf-8")).hexdigest()[:8]


def spoken(event: str, text: str) -> str:
    if event == "church_of_aole":
        if text.startswith("Then she lifted"):
            return text  # (the whole page is the priest telling his story)
        if text.startswith("The priest's eyes light up"):
            return text.split("\n\n", 1)[1]
    return " ".join(re.findall(r'"([^"]+)"', text))


def say(name: str, text: str, speaker: str, keys: list) -> bool:
    path = OUT / (name + ".wav")
    if path.exists() and "--redo" not in sys.argv:
        return True
    voice, style = SPEAKERS[speaker]
    mv.TEXT = text
    mv.STYLE = style
    for key in keys:
        for v in (voice, "Algenib"):
            try:
                raw, mime = mv.speak(v, key)
            except urllib.error.HTTPError as e:
                print("   HTTP", e.code, "with", v)
                if e.code == 429:
                    break  # (this key is out of requests: the next one)
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
            print("ok ", name, "|", text[:60].replace("\n", " "))
            return True
    print("FAILED", name)
    return False


def main() -> None:
    texts = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
    keys = json.loads(mv.SETTINGS.read_text(encoding="utf-8")).get("google_api_keys", [])
    if isinstance(keys, str):
        keys = [k.strip() for k in keys.replace(",", "\n").split() if k.strip()]
    OUT.mkdir(parents=True, exist_ok=True)
    jobs = []
    for t in texts:
        sp = EVENT_SPEAKER.get(t["event"])
        line = spoken(t["event"], t["text"]) if sp else ""
        if sp and line.strip():
            jobs.append((t["key"], line, sp))
    jobs.append(("sprite_help_me", "O mighty traveler. Please help me. A mean monster has taken over my grove, and I am too powerless to do anything about it.", "sprite"))
    jobs.append(("witch_blood", "A drop of blood for a drop of wax.", "witch"))
    jobs.append(("well_whisper", "Traveller... come closer... I am so hungry... feed me, and I will give you something nice... or jump in... jump in...", "witch"))
    for line in FISHER_LINES:
        jobs.append((key_of(line), line, "fisher"))
    for line in FARMER_LINES:
        jobs.append((key_of(line), line, "farmer"))
    for line in BEAR_LINES:
        jobs.append((key_of(line), line, "bear_deep"))
    for line in BEAR_ANGRY_LINES:
        jobs.append((key_of(line), line, "bear_angry"))
    bad = 0
    for name, line, sp in jobs:
        if not say(name, line, sp, keys):
            bad += 1
    print("done, %d failed" % bad)


if __name__ == "__main__":
    main()
