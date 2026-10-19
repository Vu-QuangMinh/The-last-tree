"""The Handyman's grunts when he is hit (docs/dialogue/sfx_handy_got_hit.wav, one take) cut at its silences into assets/Puppet/SFX/sfx_handy_hit_<n>.wav
(played by Creature.hit). Run with ReadAnyBook's python (numpy + soundfile):  rvc_env/Scripts/python.exe tools/split_handyman_hits.py"""
import os
import sys
import soundfile as sf
import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from loudness import loudify

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(ROOT, 'docs', 'dialogue', 'sfx_handy_got_hit.wav')
OUT = os.path.join(ROOT, 'assets', 'Puppet', 'SFX') + os.sep
d, sr = sf.read(SRC, dtype='float32', always_2d=True)
m = np.abs(d).max(axis=1)
w = int(0.05 * sr)
segs = []
cur = None
for i in range(0, len(m), w):
    v = float(m[i:i + w].max())
    t = i / sr
    if v > 0.03:
        if cur is None:
            cur = [t, t + 0.05]
        else:
            cur[1] = t + 0.05
    elif cur is not None and t - cur[1] >= 0.3:
        segs.append(cur)
        cur = None
if cur:
    segs.append(cur)
segs = [s for s in segs if s[1] - s[0] > 0.2]  # (a 50 ms blip at the very end is noise)
DROP = {1}  # the user threw the first one away (it was no good): it is not made again
for k, (a, b) in enumerate(segs, 1):
    if k in DROP:
        continue
    a = max(0.0, a - 0.06)
    b = min(len(d) / sr, b + 0.12)
    clip = d[int(a * sr):int(b * sr)].copy()
    f = int(0.006 * sr)
    clip[:f] *= np.linspace(0, 1, f)[:, None]
    n = int(0.03 * sr)
    clip[-n:] *= np.linspace(1, 0, n)[:, None]
    clip = loudify(clip, sr, target_db=-10.5)  # (the grunts are short: a touch louder than the voice, as a hit sound should be)
    sf.write(OUT + 'sfx_handy_hit_%d.wav' % k, clip, sr, subtype='PCM_16')
    print(k, '%.2f-%.2f (%.2f s) peak %.2f' % (a, b, b - a, float(np.abs(clip).max())))
