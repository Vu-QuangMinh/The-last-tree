r"""The "Extension!" sound (2026-11-12): a chant that wakes more spells after a Repaint slams the word onto the table. A reward that lands decisively, cut from the Sonniss GDC libraries
(E:\Soniss SFX) into assets/Puppet/SFX/sfx_extension.wav (44.1 kHz stereo, 16 bit). Layers:
    the IMPACT   "Impact,Sound Design,Hit,Chime,Resonant Hit,Chime Accent": a deep hit with a bright chime accent on top (the word lands), 2.4 s
    the REWARD   "sfx_unlock_level_02" (G4F Casual): a warm rising "unlocked!" (starts 0.05 s after the hit), and
    the SPARKLE  "Success 2a" (Chris Logsdon Ambient Puzzle): a high shimmer that rings out over the tail, quieter
Run with D:\GitHub Projects\AnySFX\backend\.venv\Scripts\python.exe (numpy + soundfile); ffmpeg must be on the PATH."""
import sys
from pathlib import Path

import numpy as np
import soundfile as sf

sys.path.insert(0, str(Path(__file__).resolve().parent))
from make_shop_sfx import RATE, fade, find, load, peak  # noqa: E402

OUT = Path(__file__).resolve().parent.parent / "assets" / "Puppet" / "SFX"


def put(mix, a, at, gain):
    i = int(at * RATE)
    mix[i:i + len(a)] += a[:len(mix) - i] * gain


mix = np.zeros((int(2.6 * RATE), 2), dtype=np.float32)
put(mix, fade(load(find("Resonant Hit,Chime Accent"), 0.0, 2.4), 0.0, 1.0), 0.0, 1.0)
put(mix, fade(load(find("sfx_unlock_level_02"), 0.0, 1.5), 0.0, 0.3), 0.05, 0.7)
put(mix, fade(load(find("Success 2a"), 0.0, 2.4), 0.0, 1.0), 0.1, 0.45)
sf.write(OUT / "sfx_extension.wav", peak(fade(mix, 0.0, 0.6), -2), RATE, subtype="PCM_16")
print("sfx_extension %.2f s" % (len(mix) / RATE))
