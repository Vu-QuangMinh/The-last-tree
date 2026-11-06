"""Act 2 mob sounds AnySFX made (2026-11-06; Soniss had nothing good): sfx_sentinel_wake, sfx_lamp_glow, sfx_stun_apply into assets/Puppet/SFX/ (4 candidates each in _Candidates).
Run with AnySFX's python:  "D:/GitHub Projects/AnySFX/backend/.venv/Scripts/python.exe" tools/make_act2_mob_sfx_ai.py [--redo] [name ...]   ... --pick <name> <n>"""
import os
import sys
import time

import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import make_spell_sfx as M

SOUNDS = {
    "sfx_sentinel_wake": ("a huge stone golem waking up, deep grinding of heavy stone slabs shifting, a low rumble and a dull stony crack", 2.2),
    "sfx_lamp_glow": ("a soft magical lantern glowing brighter, a gentle rising shimmer with one soft glassy chime, calm and eerie", 1.4),
    "sfx_stun_apply": ("a cartoon dizzy daze, a dull wooden bonk followed by a short wobbly ringing whistle, comic", 1.2),
}
NEG = {"sfx_sentinel_wake": "music, voice, explosion", "sfx_lamp_glow": "music, melody, voice", "sfx_stun_apply": "music, voice, melody"}
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
