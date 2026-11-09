"""The Pianist's two pieces, from public-domain MIDI (the Mutopia Project): Turkish March (Mozart, KV 331, Rondo alla
Turca, Mutopia piece 108) and Fur Elise (Beethoven, WoO 59, Mutopia piece 931; the secret version, slowed with more
reverb). Reads the MIDI (a small parser of its own: no MIDI library needed), renders a synthesized piano, and writes
the notes his one arm follows.

    python tools/render_pianist.py <turca.mid> <elise.mid>

Writes assets/Global/Music/Pianist/{turkish_march,fur_elise}.wav and data/pianist_notes.json:
{"turkish_march": {"length": seconds, "notes": [[start, midi pitch, duration], ...]}, ...} (seconds, as played).
"""
import json
import struct
import sys
import wave
from pathlib import Path

import numpy as np

ROOT = Path(__file__).resolve().parent.parent
OUT_DIR = ROOT / "assets" / "Global" / "Music" / "Pianist"
SR = 32000


def read_vlq(b, i):
    v = 0
    while True:
        c = b[i]
        i += 1
        v = (v << 7) | (c & 0x7F)
        if not c & 0x80:
            return v, i


def parse_midi(path, only_channel=None):
    """[(start s, pitch, duration s, velocity)] from a type 0/1 MIDI file, tempo changes included. only_channel: keep just that MIDI channel (here channel 1 = the left hand, 0 = the right)."""
    b = Path(path).read_bytes()
    assert b[:4] == b"MThd"
    hl = struct.unpack(">I", b[4:8])[0]
    fmt, ntrk, div = struct.unpack(">HHH", b[8:14])
    assert not div & 0x8000, "SMPTE time not supported"
    i = 8 + hl
    events = []  # (tick, kind, a, b)
    tempos = [(0, 500000)]
    for _ in range(ntrk):
        assert b[i:i + 4] == b"MTrk"
        ln = struct.unpack(">I", b[i + 4:i + 8])[0]
        j = i + 8
        end = j + ln
        tick = 0
        status = 0
        while j < end:
            dt, j = read_vlq(b, j)
            tick += dt
            c = b[j]
            if c == 0xFF:
                typ = b[j + 1]
                ml, j = read_vlq(b, j + 2)
                if typ == 0x51:
                    tempos.append((tick, int.from_bytes(b[j:j + 3], "big")))
                j += ml
                continue
            if c in (0xF0, 0xF7):
                ml, j = read_vlq(b, j + 1)
                j += ml
                continue
            if c & 0x80:
                status = c
                j += 1
            hi = status & 0xF0
            if hi in (0xC0, 0xD0):
                j += 1
                continue
            d1, d2 = b[j], b[j + 1]
            j += 2
            if only_channel is not None and (status & 0x0F) != only_channel:
                continue
            if hi == 0x90 and d2 > 0:
                events.append((tick, "on", d1, d2))
            elif hi == 0x80 or (hi == 0x90 and d2 == 0):
                events.append((tick, "off", d1, 0))
        i = end
    tempos.sort()

    def secs(t):
        s = 0.0
        last_t, last_tempo = 0, 500000
        for tt, tempo in tempos:
            if tt >= t:
                break
            s += (tt - last_t) * last_tempo / 1e6 / div
            last_t, last_tempo = tt, tempo
        return s + (t - last_t) * last_tempo / 1e6 / div

    events.sort(key=lambda e: (e[0], e[1] == "on"))
    open_notes = {}
    notes = []
    for tick, kind, p, v in events:
        if kind == "on":
            open_notes.setdefault(p, []).append((tick, v))
        elif open_notes.get(p):
            t0, v0 = open_notes[p].pop(0)
            notes.append((secs(t0), p, max(0.05, secs(tick) - secs(t0)), v0))
    notes.sort()
    return notes


def piano(notes, stretch=1.0, reverb=0.25):
    length = max(s + d for s, _, d, _ in notes) * stretch + 2.5
    out = np.zeros(int(length * SR) + SR)
    rng = np.random.default_rng(7)
    for s, p, d, v in notes:
        s *= stretch
        d *= stretch
        f = 440.0 * 2 ** ((p - 69) / 12)
        ring = min(d + 0.35, 4.0)  # (held, then the damper: a short release)
        n = int(ring * SR)
        t = np.arange(n) / SR
        decay = 1.1 + f / 700.0
        env = np.exp(-decay * t) * np.minimum(1.0, t / 0.004)
        env *= np.where(t < d, 1.0, np.exp(-(t - d) * 14.0))  # (the key comes up: it dies quickly)
        tone = np.zeros(n)
        for k in range(1, 9):
            fk = k * f * np.sqrt(1 + 0.0004 * k * k)
            if fk > SR / 2.2:
                break
            tone += np.sin(2 * np.pi * fk * t + rng.random() * 6.28) * (1.0 / k ** 1.4) * np.exp(-k * 0.35 * t)
        hammer = rng.standard_normal(n) * np.exp(-t * 300) * 0.08
        sig = (tone + hammer) * env * (0.35 + 0.65 * v / 127.0)
        a = int(s * SR)
        out[a:a + n] += sig
    if reverb > 0:
        # a small room: a decaying noise tail, convolved (FFT)
        ir_n = int(1.6 * SR)
        ir = rng.standard_normal(ir_n) * np.exp(-np.arange(ir_n) / SR * 3.2)
        ir[0] = 0
        m = len(out) + ir_n
        size = 1 << (m - 1).bit_length()
        wet = np.fft.irfft(np.fft.rfft(out, size) * np.fft.rfft(ir, size), size)[:len(out)]
        out = out + wet / np.max(np.abs(wet)) * np.max(np.abs(out)) * reverb
    out /= np.max(np.abs(out)) * 1.12
    return out, length


def write_wav(path, x):
    path.parent.mkdir(parents=True, exist_ok=True)
    d = (np.clip(x, -1, 1) * 32767).astype(np.int16)
    with wave.open(str(path), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(d.tobytes())


def main():
    turca, elise = sys.argv[1], sys.argv[2]
    data = {}
    for key, path, stretch, rev in [("turkish_march", turca, 1.0, 0.22), ("fur_elise", elise, 1.25, 0.45)]:
        notes = parse_midi(path)
        audio, length = piano(notes, stretch, rev)
        write_wav(OUT_DIR / (key + ".wav"), audio)
        data[key] = {"length": round(length, 2), "notes": [[round(s * stretch, 3), p, round(d * stretch, 3)] for s, p, d, _ in notes]}
        print(key, len(notes), "notes,", round(length, 1), "s")
    (ROOT / "data" / "pianist_notes.json").write_text(json.dumps(data, separators=(",", ":")), encoding="utf-8")


if __name__ == "__main__":
    main()
