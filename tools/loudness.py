"""Make a recorded line (numpy array, samples x channels, float -1..1) louder without clipping: a gentle compressor (the loud syllables and the laughs come down,
the quiet ones come up), a make-up gain that brings the speaking level (RMS of the parts that are not silence) to `target_db`, and a look-ahead limiter that keeps every
peak under `ceiling_db`. Used by split_handyman_voice.py and split_handyman_hits.py (the game's own sounds sit at about -17 to -6 dB)."""
import numpy as np


def _smooth(x, n):
    k = np.ones(n) / n
    return np.convolve(x, k, mode="same")


def loudify(clip, sr, target_db=-11.0, ceiling_db=-1.0, thresh_db=-24.0, ratio=3.0):
    clip = clip.astype(np.float64)
    mono = np.abs(clip).max(axis=1)
    # compressor: the level (peak envelope, 10 ms) over the threshold is divided by `ratio`
    env = _smooth(mono, int(0.010 * sr)) + 1e-9
    env_db = 20 * np.log10(env)
    over = np.maximum(env_db - thresh_db, 0.0)
    gain_db = -over * (1.0 - 1.0 / ratio)
    gain_db = _smooth(gain_db, int(0.020 * sr))  # (no zipper noise)
    out = clip * (10 ** (gain_db / 20.0))[:, None]
    # make-up: the speaking level to target_db
    m = out.mean(axis=1)
    act = np.abs(m) > 0.02 * np.abs(m).max()
    rms = np.sqrt((m[act] ** 2).mean()) if act.any() else 1e-6
    out *= 10 ** (target_db / 20.0) / rms
    # limiter: wherever a sample is over the ceiling, the gain comes down before it (5 ms look-ahead) and goes back slowly (60 ms)
    ceil = 10 ** (ceiling_db / 20.0)
    pk = np.abs(out).max(axis=1)
    need = np.minimum(1.0, ceil / np.maximum(pk, 1e-9))
    la = int(0.005 * sr)
    need = np.minimum.reduce([np.roll(need, -s) for s in range(0, la, max(1, la // 5))])  # (look ahead)
    need = np.minimum(need, 1.0)
    rel = _smooth(need, int(0.060 * sr))
    g = np.minimum(need, rel)  # (never above what a peak needs; smoothed where it is not)
    out *= g[:, None]
    out = np.clip(out, -ceil, ceil)
    return out.astype(np.float32)
