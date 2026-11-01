"""Elemental Fishing sounds cut from the Sonniss libraries (E:\Soniss SFX), into assets/Puppet/SFX (2026-11-02):
  fish_spear_small / _medium / _big   a crossbow bolt let go (muffled, as under water) + a rush of water + the bolt hitting; the size changes pitch, weight and splash
  fish_timer_tick                     one tick of a clock (the last seconds of the game)
Run with AnySFX's python (numpy, soundfile, scipy), ffmpeg on the PATH:  python tools/make_fish_sfx.py"""
import sys
from pathlib import Path

import numpy as np
from scipy import signal

sys.path.insert(0, str(Path(__file__).resolve().parent))
import make_shop_sfx as S

R = S.RATE


def lowpass(a, hz):
    sos = signal.butter(2, hz, "lowpass", fs=R, output="sos")
    return signal.sosfilt(sos, a, axis=0).astype(np.float32)


def speed(a, k):
    """Faster (k > 1: higher and shorter) or slower."""
    num = 1000
    return signal.resample_poly(a, num, int(num * k), axis=0).astype(np.float32)


def spear(size):
    shot = S.trim_to_hit(S.load(S.find("firing,loose,crossbow1,carbonbolt")), 0.5)
    rush = S.trim_to_hit(S.load(S.find("underwater_object_movement_quick_deep_15")), 0.6, 0.0)
    hit = S.trim_to_hit(S.load(S.find("Crossbow -Arrow Hit 2")), 0.6)
    splash = S.trim_to_hit(S.load(S.find("underwater_splash_large_06")), 0.9)
    k = {"small": 1.3, "medium": 1.0, "big": 0.8}[size]
    shot, rush, hit, splash = lowpass(shot, 2200), speed(rush, k), speed(hit, k), speed(splash, k)
    parts = [(S.fade(S.peak(shot, -6), 0.0, 0.15), 0.0, 1.0), (S.fade(S.peak(rush, -12), 0.01, 0.2), 0.03, 1.0)]
    at = 0.22 / k
    parts.append((S.fade(S.peak(lowpass(hit, 4000), {"small": -8, "medium": -5, "big": -2}[size]), 0.0, 0.2), at, 1.0))
    if size != "small":
        parts.append((S.fade(S.peak(splash, -14 if size == "medium" else -8), 0.0, 0.4), at + 0.02, 1.0))
    S.save("fish_spear_%s.wav" % size, S.peak(S.mix(parts), -3))


def main():
    for size in ("small", "medium", "big"):
        spear(size)
    tick = S.trim_to_hit(S.load(S.find("Clock-07_Ticking_Single-01")), 0.3)
    S.save("fish_timer_tick.wav", S.fade(S.peak(tick, -3), 0.0, 0.1))


if __name__ == "__main__":
    main()
