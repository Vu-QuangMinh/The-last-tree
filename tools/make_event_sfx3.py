"""Event sounds redone with AnySFX (2026-11-02), in assets/Puppet/SFX/ (4 variants each kept in _Candidates, the best by make_spell_sfx's score is installed):
event_mushroom_bite (biting into something soft and juicy), event_stump_knock (knuckles knocking on wood), fish_spear_small / _medium / _big (a speargun shot under water that hits a fish),
event_skip_plink (a flat stone touching the lake: replaces the synthesized one).
Run with AnySFX's python:  "D:/GitHub Projects/AnySFX/backend/.venv/Scripts/python.exe" tools/make_event_sfx3.py [--redo] [name ...]
  ... --pick <name> <n>   install candidate n instead.  Then Godot --headless --editor --quit once."""
import os
import sys
import time

import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import make_spell_sfx as M

SOUNDS = {
    "event_mushroom_bite": ("a big wet bite into a juicy ripe fruit, crisp crunch and juicy squelch, chewing", 1.4),
    "event_stump_knock": ("knuckles knocking on a hollow wooden stump, three clunky hollow wood knocks", 1.6),
    "fish_count": ("a single short dry wooden block tap, one woody tick, clean", 0.6),
    "fish_go": ("a single bright hand bell ding, short clear ring, game start signal", 1.2),
    "event_skip_plink": ("a flat stone skipping on the surface of a still lake, a single light water plip", 0.8),
}
NEG = {"fish_count": "music, rhythm, multiple hits", "fish_go": "music, melody, multiple hits", "event_skip_plink": "splash, big splash, thunder", "event_stump_knock": "metal, drum, door"}
CHOSEN = {}


def path_of(name):
    return os.path.join(M.SFX, name + ".wav")


def main():
    args = [a for a in sys.argv[1:] if not a.startswith("--")]
    os.makedirs(M.POLISHED, exist_ok=True)
    if "--pick" in sys.argv:
        name, n = args[0], int(args[1])
        M.write(path_of(name), M.load(os.path.join(M.POLISHED, "%s_%d.wav" % (name, n))))
        M.log("%s: candidate %d chosen" % (name, n))
        return
    redo = "--redo" in sys.argv
    names = args or list(SOUNDS)
    proc = M.start_backend()
    try:
        for name in names:
            prompt, dur = SOUNDS[name]
            t0 = time.time()
            try:
                files = M.generate(prompt, dur, extra_negative=NEG.get(name, ""))
            except Exception as exc:
                M.log("%s FAILED: %s" % (name, exc))
                continue
            audios = [M.load(f) for f in files]
            scores = [M.score(a) for a in audios]
            best = int(np.argmax(scores))
            for n, a in enumerate(audios):
                M.write(os.path.join(M.CAND, "%s_%d.wav" % (name, n)), a)
                M.write(os.path.join(M.POLISHED, "%s_%d.wav" % (name, n)), M.polish(a))
            M.write(path_of(name), M.polish(audios[best]))
            M.log("%-22s pick %d of %s (%.0f s) %s" % (name, best, " ".join("%.2f" % s for s in scores), time.time() - t0, prompt))
    finally:
        if proc is not None:
            proc.terminate()


if __name__ == "__main__":
    main()
