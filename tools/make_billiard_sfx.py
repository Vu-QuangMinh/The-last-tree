"""Synthesize the Cirus bag launcher's sounds into assets/sfx/:
- sfx_ball_clack:  two billiard balls knocking (a very short, bright, hard "tok": glassy partials + a tiny low thud)
- sfx_ball_roll:   a ball rolling over a table (a low, soft rumble with a slow wobble as the ball turns)
- sfx_crank_ratchet: the crank and gear turning once (a fast run of small ratchet clicks that slows a little at the end)
Usage: python tools/make_billiard_sfx.py
"""
import wave
from pathlib import Path

import numpy as np

SR = 44100
OUT = Path(__file__).resolve().parent.parent / "assets" / "sfx"
rng = np.random.default_rng(11)


def t_of(sec):
    return np.arange(int(SR * sec)) / SR


def lowpass(x, a):
    y = np.zeros_like(x)
    acc = 0.0
    for i, v in enumerate(x):
        acc += a * (v - acc)
        y[i] = acc
    return y


def save(name, x, peak=0.7):
    x = x / (np.max(np.abs(x)) + 1e-9) * peak
    fade = int(SR * 0.01)
    x[-fade:] *= np.linspace(1, 0, fade)
    data = (x * 32767).astype(np.int16)
    with wave.open(str(OUT / f"{name}.wav"), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(data.tobytes())


def click(sec, start, freqs, decay, amp=1.0):
    """A hard, short strike: a few inharmonic partials with a very fast decay."""
    t = t_of(sec)
    out = np.zeros_like(t)
    tt = t - start
    on = tt >= 0
    for k, f in enumerate(freqs):
        out[on] += amp / (1 + 0.5 * k) * np.sin(2 * np.pi * f * tt[on]) * np.exp(-tt[on] / (decay / (1 + 0.35 * k)))
    return out


def clack():
    sec = 0.22
    t = t_of(sec)
    x = click(sec, 0.0, (2650, 4180, 6320, 8900), 0.011)
    x += 0.9 * click(sec, 0.0, (1240, 1890), 0.016)  # the body of the ball
    thud = np.sin(2 * np.pi * 310 * t) * np.exp(-t / 0.012) * 0.45  # a tiny low knock under it
    noise = lowpass(rng.standard_normal(len(t)), 0.5) * np.exp(-t / 0.0025) * 0.6  # the first instant
    return x + thud + noise


def roll():
    sec = 1.1
    t = t_of(sec)
    n = lowpass(rng.standard_normal(len(t)), 0.045) * 6.0  # low rumble
    n2 = lowpass(rng.standard_normal(len(t)), 0.12) * 1.6  # a little more grit
    wobble = 0.72 + 0.28 * np.sin(2 * np.pi * 7.5 * t)  # the ball turning
    env = np.minimum(1.0, t / 0.08) * np.minimum(1.0, (sec - t) / 0.35)
    return (n + n2) * wobble * env


def ratchet():
    sec = 0.95
    t = t_of(sec)
    out = np.zeros_like(t)
    when = 0.0
    gap = 0.026
    while when < sec - 0.06:
        out += click(sec, when, (1750, 2900, 4300), 0.006, 0.8) + 0.4 * click(sec, when, (420,), 0.01)
        gap = min(0.05, gap * 1.045)  # it slows a little as the turn ends
        when += gap
    return out


save("sfx_ball_clack", clack())
save("sfx_ball_roll", roll(), 0.5)
save("sfx_crank_ratchet", ratchet(), 0.55)
print("ok", [p.name for p in OUT.glob("sfx_ball*")] + [p.name for p in OUT.glob("sfx_crank*")])
