r"""The end-of-fight sounds, cut from the Sonniss GDC libraries (E:\Soniss SFX) into assets/Puppet/SFX (44.1 kHz stereo, 16 bit).

Run with D:\GitHub Projects\AnySFX\backend\.venv\Scripts\python.exe (it has numpy and soundfile); ffmpeg must be on the PATH.
    victory_fanfare.wav          Victory: a bright chime, a marimba flourish and a small theatre audience clapping
    perfect_victory_fanfare.wav  Perfect Victory: a harp glissando, the chime and the unlock sparkle, a toy xylophone run, a cheer and a bigger applause
    defeat_stinger.wav           Defeat: a small orchestra failing, then a lone piano falling away
"""
import sys
from pathlib import Path

import numpy as np
import soundfile as sf

sys.path.insert(0, str(Path(__file__).resolve().parent))
from make_shop_sfx import fade, find, load, mix, peak  # noqa: E402  (the shared helpers)

OUT = Path(__file__).resolve().parent.parent / "assets" / "Puppet" / "SFX"


def part(name, start=0.0, length=None, gain_db=0.0, fin=0.0, fout=0.0):
    a = fade(load(find(name), start, length), fin, fout)
    return a * (10 ** (gain_db / 20))


def save(name, audio):
    sf.write(OUT / name, peak(audio, -1.0), 44100, subtype="PCM_16")
    print(name, round(len(audio) / 44100, 2), "s")


# Victory
save("victory_fanfare.wav", mix([
    (part("Marimba Gliss Up Down Flourish Slow 04", length=3.0, gain_db=-3, fout=0.4), 0.0, 1.0),
    (part("Success 2a", gain_db=-1), 0.55, 1.0),
    (part("Audience applauding 28", length=4.5, gain_db=-8, fin=0.2, fout=1.8), 0.9, 1.0),
]))

# Perfect Victory
save("perfect_victory_fanfare.wav", mix([
    (part("Ascending Harp Glissando", length=4.5, gain_db=-3, fout=1.0), 0.0, 1.0),
    (part("Xylophone Gliss Up Down Flourish Slow 01", length=3.0, gain_db=-5, fout=0.5), 0.9, 1.0),
    (part("Success 2a", gain_db=-1), 1.2, 1.0),
    (part("sfx_unlock_level_02", gain_db=-3), 1.5, 1.0),
    (part("sfx_voice_woohoo_02", gain_db=-6), 1.9, 1.0),
    (part("Audience applauding 09", length=6.5, gain_db=-5, fin=0.2, fout=2.2), 1.4, 1.0),
]))

# Defeat
save("defeat_stinger.wav", mix([
    (part("Failure_01-10_Ensemble-Small_DRY", gain_db=-1), 0.0, 1.0),
    (part("Failure_05-01_Piano-A_DRY", gain_db=-4, fout=0.8), 1.0, 1.0),
]))
