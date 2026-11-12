r"""Sounds of the Bug Hunter (2026-11-12), cut from the Sonniss GDC libraries (E:\Soniss SFX) into assets/Puppet/SFX (44.1 kHz stereo, 16 bit).
Run with D:\GitHub Projects\AnySFX\backend\.venv\Scripts\python.exe (numpy + soundfile); ffmpeg must be on the PATH.
    bell_strike.wav   the striker hits the bell: a real church bell hit that rings out ("01_Campana_Iglesia", the first hit at 4.95 s, played 1.3x faster = a smaller bell, 3.1 s) + a little wooden knock
    bell_alarm.wav    the alarm: three such hits (the same recording at three pitches) 0.62 s apart, the rings running into each other (the animation's 3 blows)
    sfx_clock_tick.wav  the clock of the alarm ticking (Antique Clicker 2, one tick)
(The Puppet theme's SFX folder wins over assets/Global/SFX/bell_strike.wav and bell_alarm.wav, which stay as the other themes' sounds.)"""
import sys
from pathlib import Path

import numpy as np
import soundfile as sf

sys.path.insert(0, str(Path(__file__).resolve().parent))
from make_shop_sfx import RATE, fade, find, load, peak  # noqa: E402

OUT = Path(__file__).resolve().parent.parent / "assets" / "Puppet" / "SFX"
COW = "MODERN LP BELL COWBELL STRAIGHT MUTED STICK HITS"


def put(mix, a, at):
    i = int(at * RATE)
    mix[i:i + len(a)] += a[:len(mix) - i]


def save(name, a, db):
    sf.write(OUT / (name + ".wav"), peak(a, db), RATE, subtype="PCM_16")
    print("%-18s %.2f s" % (name, len(a) / RATE))


def pitch(a, rate):
    """Played back at `rate` (< 1: lower and longer), by resampling."""
    n = int(len(a) / rate)
    x = np.arange(n) * rate
    return np.stack([np.interp(x, np.arange(len(a)), a[:, c]) for c in (0, 1)], axis=1).astype(np.float32)


def ring_boost(a, target=0.2, top=25.0, rise=9.0):
    """Lifts the quiet ring after the hit (the recording rings out at -25 dB and sounds dry), so the bell sings on for seconds instead of ending with its hit.
    The gain wants to bring the level up to `target`; it can fall at once (the hit itself is never touched) but rises only `rise` per second (the ring swells in)."""
    env = np.abs(a).max(axis=1)
    k = int(0.03 * RATE)
    env = np.convolve(env, np.ones(k) / k, mode="same") + 1e-4
    want = np.clip(target / env, 1.0, top)
    g = np.empty_like(want)
    cur = 1.0
    step = rise / RATE
    for i in range(len(want)):
        cur = min(want[i], cur * (1.0 + step * 4.0) + step)
        g[i] = cur
    return (a * g[:, None]).astype(np.float32)


CHURCH = "01_Campana_Iglesia"  # a church bell struck again and again: the first hit (4.95 s) rings out alone for 4.4 s before the next stroke


def one_hit(at, rate, length=3.1):
    """One blow: a real bell hit, ringing out. The church bell is huge, so it is played faster (higher, shorter) to the size of a brass bell, and under it goes a
    little of the muted cowbell stick hit for the knock of the wooden striker."""
    bell = fade(pitch(load(find(CHURCH), at, length * rate + 0.2), rate)[:int(length * RATE)], 0.0, 1.4)
    knock = fade(load(find(COW), 7.66, 0.3), 0.0, 0.15) * 0.35
    mix = ring_boost(bell)
    mix[:len(knock)] += knock
    return mix


save("bell_strike", one_hit(4.93, 1.3), -2)
mix = np.zeros((int(5.0 * RATE), 2), dtype=np.float32)
for k, (src, rate, gain) in enumerate(((4.93, 1.36, 0.8), (4.93, 1.3, 0.9), (4.93, 1.24, 1.0))):
    put(mix, one_hit(src, rate) * gain, k * 0.62)
save("bell_alarm", fade(mix, 0.0, 2.0), -2)
save("sfx_clock_tick", fade(load(find("Antique Clicker 2"), 1.97, 0.4), 0.0, 0.12), -8)
