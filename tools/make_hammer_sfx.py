"""Synthesize the Hammer Hand's sounds into assets/sfx/:
- sfx_hammer_thump: a fist-on-a-door thump (low body resonance + a short wooden knock)
- sfx_glass_break:  a pane breaking (a bright noise crash + a spray of high glassy pings)
- sfx_glass_clank:  shards clinking down (a few small glass pings + a tiny low clank)
- sfx_dust:         an hourglass crumbling to dust (a soft sandy hiss that swells and blows away, with fine grains)
Usage: python tools/make_hammer_sfx.py
"""
import wave
from pathlib import Path

import numpy as np

SR = 44100
OUT = Path(__file__).resolve().parent.parent / "assets" / "sfx"
rng = np.random.default_rng(7)


def t_of(sec):
    return np.arange(int(SR * sec)) / SR


def lowpass(x, a):
    y = np.zeros_like(x)
    acc = 0.0
    for i, v in enumerate(x):
        acc += a * (v - acc)
        y[i] = acc
    return y


def ping(sec, freq, decay, start=0.0, amp=1.0, partials=(1.0, 2.76, 5.4)):
    t = t_of(sec)
    out = np.zeros_like(t)
    tt = t - start
    on = tt >= 0
    for k, p in enumerate(partials):
        out[on] += amp / (k + 1) * np.sin(2 * np.pi * freq * p * tt[on]) * np.exp(-tt[on] / (decay / (1 + k * 0.6)))
    return out


def save(name, x):
    x = x / (np.max(np.abs(x)) + 1e-9) * 0.7
    fade = int(SR * 0.01)
    x[-fade:] *= np.linspace(1, 0, fade)
    data = (x * 32767).astype(np.int16)
    with wave.open(str(OUT / f"{name}.wav"), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(data.tobytes())
    print("wrote", name, f"{len(x) / SR:.2f}s")


def thump():
    t = t_of(0.45)
    body = (np.sin(2 * np.pi * 68 * t) * 1.0 + np.sin(2 * np.pi * 103 * t) * 0.6 + np.sin(2 * np.pi * 157 * t) * 0.3)
    body *= np.exp(-t / 0.09)
    pitch_drop = np.sin(2 * np.pi * (140 - 60 * np.minimum(t / 0.03, 1)) * t) * np.exp(-t / 0.02) * 0.6
    knock = lowpass(rng.standard_normal(len(t)), 0.25) * np.exp(-t / 0.012) * 1.4  # the wooden contact
    return body + pitch_drop + knock


def glass_break():
    sec = 1.0
    t = t_of(sec)
    noise = rng.standard_normal(len(t))
    bright = noise - lowpass(noise, 0.15)  # high-passed: the crash
    crash = bright * (np.exp(-t / 0.07) * 1.2 + np.exp(-t / 0.25) * 0.25)
    pings = np.zeros_like(t)
    for _ in range(26):
        pings += ping(sec, rng.uniform(1800, 6500), rng.uniform(0.03, 0.14), rng.uniform(0.0, 0.45), rng.uniform(0.15, 0.5))
    return crash + pings * 0.6


def glass_clank():
    sec = 0.5
    t = t_of(sec)
    out = np.zeros_like(t)
    for _ in range(5):
        out += ping(sec, rng.uniform(2200, 5200), rng.uniform(0.04, 0.1), rng.uniform(0.0, 0.18), rng.uniform(0.3, 0.7))
    out += ping(sec, 820, 0.06, 0.0, 0.5, partials=(1.0, 1.63, 2.41))  # a small low clank
    tick = (rng.standard_normal(len(t)) - lowpass(rng.standard_normal(len(t)), 0.2)) * np.exp(-t / 0.006) * 0.5
    return out + tick


def dust():
    sec = 0.9
    t = t_of(sec)
    noise = rng.standard_normal(len(t))
    hiss = noise - lowpass(noise, 0.08)  # airy
    hiss = lowpass(hiss, 0.5)  # but soft
    env = np.minimum(t / 0.12, 1.0) * np.exp(-np.maximum(t - 0.3, 0) / 0.22)
    grains = np.zeros_like(t)
    for _ in range(220):  # fine sand ticks
        i = int(rng.uniform(0, 0.7) * SR)
        n = int(SR * 0.002)
        grains[i:i + n] += rng.uniform(0.2, 0.6) * np.exp(-np.arange(n) / (SR * 0.0005)) * rng.choice([-1, 1])
    grains = grains - lowpass(grains, 0.3)
    return hiss * env * 0.8 + grains * env * 0.9


if __name__ == "__main__":
    save("sfx_hammer_thump", thump())
    save("sfx_glass_break", glass_break())
    save("sfx_glass_clank", glass_clank())
    save("sfx_dust", dust())
