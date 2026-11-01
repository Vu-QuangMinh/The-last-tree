"""Small sounds for the older "?" events (2026-11-01), made from scratch (numpy) into assets/Puppet/SFX/:
event_pop (a mushroom plops off), event_glass_break (a bottle shatters), event_bite (jaws snap shut), event_lute_song (a plucked tune), event_lute_sour (a sour chord),
event_skip_plink (a stone touches the lake).  Run with any python that has numpy:  python tools/make_event_sfx2.py"""
import os
import wave

import numpy as np

SR = 44100
OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "assets", "Puppet", "SFX")
rng = np.random.default_rng(7)


def save(name, x, peak=0.8):
    x = x / max(1e-9, np.max(np.abs(x))) * peak
    with wave.open(os.path.join(OUT, name + ".wav"), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes((x * 32767).astype(np.int16).tobytes())
    print("  ", name, round(len(x) / SR, 2), "s")


def t_of(sec):
    return np.arange(int(SR * sec)) / SR


def lowpass(x, k):
    """A moving average of k samples (cheap low-pass)."""
    return np.convolve(x, np.ones(k) / k, mode="same")


def pluck(freq, sec, bright=0.5):
    """Karplus-Strong string: a burst of noise in a delay line that loses its highs each round."""
    n = int(SR * sec)
    period = int(SR / freq)
    buf = rng.uniform(-1, 1, period) * np.hanning(period + 2)[1:-1] ** 0.2
    out = np.zeros(n)
    for i in range(n):
        out[i] = buf[i % period]
        buf[i % period] = (buf[i % period] + buf[(i + 1) % period]) * (0.5 * (0.985 + 0.014 * bright))
    return out


def mix(parts, total):
    x = np.zeros(int(SR * total))
    for start, y in parts:
        i = int(SR * start)
        x[i:i + len(y)] += y[:len(x) - i]
    return x


def pop():
    t = t_of(0.18)
    f = 520 * np.exp(-t * 18) + 120
    x = np.sin(2 * np.pi * np.cumsum(f) / SR) * np.exp(-t * 22)
    x += lowpass(rng.uniform(-1, 1, len(t)), 6) * np.exp(-t * 60) * 0.5
    save("event_pop", x)


def glass():
    t = t_of(0.9)
    x = lowpass(rng.uniform(-1, 1, len(t)), 3) * np.exp(-t * 40) * 1.2  # the crack
    for _ in range(26):  # tinkling shards
        at = rng.uniform(0.0, 0.5)
        f = rng.uniform(2500, 7500)
        tt = t_of(0.25)
        x[int(at * SR):int(at * SR) + len(tt)] += np.sin(2 * np.pi * f * tt) * np.exp(-tt * rng.uniform(18, 40)) * rng.uniform(0.15, 0.5)
    save("event_glass_break", x)


def bite():
    t = t_of(0.35)
    knock = np.sin(2 * np.pi * 150 * t) * np.exp(-t * 28)  # wood on wood
    knock += lowpass(rng.uniform(-1, 1, len(t)), 5) * np.exp(-t * 55) * 0.9
    click = np.zeros_like(t)
    click[int(0.09 * SR):] = (np.sin(2 * np.pi * 330 * t[:len(t) - int(0.09 * SR)]) * np.exp(-t[:len(t) - int(0.09 * SR)] * 30)) * 0.7
    save("event_bite", knock + click)


def lute_song():
    notes = [(0.0, 392.0), (0.28, 440.0), (0.56, 494.0), (0.84, 587.0), (1.3, 494.0), (1.58, 440.0), (1.86, 392.0), (2.3, 330.0), (2.3, 392.0), (2.3, 494.0)]
    parts = [(at, pluck(f, 1.2, 0.7) * 0.8) for at, f in notes]
    save("event_lute_song", mix(parts, 3.6))


def lute_sour():
    parts = [(0.0, pluck(f, 1.0, 0.9)) for f in (233.1, 246.9, 349.2, 370.0)]  # a clash of semitones
    save("event_lute_sour", mix(parts, 1.2))


def plink():
    t = t_of(0.14)
    f = 900 * np.exp(-t * 14) + 380
    x = np.sin(2 * np.pi * np.cumsum(f) / SR) * np.exp(-t * 30)
    x += lowpass(rng.uniform(-1, 1, len(t)), 4) * np.exp(-t * 90) * 0.4
    save("event_skip_plink", x)


if __name__ == "__main__":
    for fn in (pop, glass, bite, lute_song, lute_sour, plink):
        fn()
