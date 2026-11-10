"""2026-11-08: the sounds of the new Act 2 enemies, made with AnySFX (4 candidates each in SFX/_Candidates, the best by score is written to assets/Puppet/SFX/):
  page_flip (the Pianist turns his page), sfx_virus_apply (a spell catches a virus), sfx_burden_apply (Burden: stone on your chant), sfx_snake_hiss (Rot Snake's moves)
Run with AnySFX's python:  "D:/GitHub Projects/AnySFX/backend/.venv/Scripts/python.exe" tools/make_boss_sfx_ai.py [name ...]   ... --pick <name> <n>"""
import os
import sys
import time

import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import make_spell_sfx as M

SOUNDS = {
    "page_flip": ("one big sheet of heavy paper being turned over on a music stand, a soft dry rustle and one gentle flap, quiet and close", 1.2),
    "sfx_virus_apply": ("a computer virus infecting something, a glitchy digital stutter with a sickly wet bubbling squelch, ominous and gross", 1.4),
    "sfx_burden_apply": ("a heavy stone weight dropping onto a wooden stage, one deep dull thud with a short rattle of an iron chain", 1.3),
    "sfx_knock_wood": ("one single short hard knock of a knuckle on a thick wooden sign board, dry, woody and close, a quick tok with a tiny hollow ring", 0.8),
    "sfx_snake_hiss": ("a huge snake hissing angrily then spitting a wet rotten splat, slimy and gross", 1.5),
}
NEG = {"page_flip": "music, voice, melody, loud", "sfx_virus_apply": "music, melody, voice", "sfx_burden_apply": "music, voice, melody",
       "sfx_snake_hiss": "music, melody, human voice", "sfx_knock_wood": "music, voice, melody, echo, reverb"}


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
