"""2026-11-10: adds the HAND to every note of data/pianist_notes.json (the audio is NOT touched): the MIDI has the right hand on channel 0 and the left on channel 1.
Each note becomes [start, pitch, duration, hand] with hand 0 = right, 1 = left.   python tools/tag_pianist_hands.py"""
import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT / "tools"))
import render_pianist as R

SRC = ROOT / "assets" / "Global" / "Music" / "Pianist" / "_Source"
PIECES = {"turkish_march": ("KV331_3_RondoAllaTurca.mid", 1.0), "fur_elise": ("fur_Elise_WoO59.mid", 1.25)}
path = ROOT / "data" / "pianist_notes.json"
data = json.loads(path.read_text(encoding="utf-8"))
for key, (mid, stretch) in PIECES.items():
    left = {}
    for s, p, d, _ in R.parse_midi(SRC / mid, 1):
        left[(round(s * stretch, 3), p)] = left.get((round(s * stretch, 3), p), 0) + 1
    n_left = 0
    for n in data[key]["notes"]:
        k = (n[0], n[1])
        h = 1 if left.get(k, 0) > 0 else 0
        if h:
            left[k] -= 1
            n_left += 1
        del n[3:]
        n.append(h)
    print(key, len(data[key]["notes"]), "notes,", n_left, "left hand")
path.write_text(json.dumps(data, separators=(",", ":")), encoding="utf-8")
