"""Spell card sound effects (2026-10-19): one sound per spell card, made with AnySFX (Stable Audio Open) from the short prompts in tools/spell_sfx_prompts.py.

For each spell id: POST /api/generate (4 variants of one prompt), pick the best variant by a few simple measures (_score), clean it up (_polish: trim silence, fades,
loudness matched to the game's own sounds, peak limited) and write it to  assets/Puppet/SFX/Spell Card SFX/spell_<id>.wav.  All 4 variants are kept in
assets/Puppet/SFX/_Candidates/<id>_<n>.wav (a .gdignore keeps Godot from importing them), so another variant can be chosen later without generating again.

Run with AnySFX's python (it has numpy / soundfile / scipy), with the AnySFX backend running on port 8890 (this script starts it itself when it is not running, and stops
only the process it started):
  "D:/GitHub Projects/AnySFX/backend/.venv/Scripts/python.exe" tools/make_spell_sfx.py [--redo] [id ...]
  ... --pick <id> <n>      use candidate n of <id> instead (polished again, nothing generated)
Done spells are skipped (unless --redo). Progress: tools/_spell_sfx_log.txt. Then Godot --headless --editor --quit once, to import the new sounds."""
import json
import os
import subprocess
import sys
import time
import urllib.parse
import urllib.request

import numpy as np
import soundfile as sf
from scipy import signal

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
ROOT = os.path.normpath(os.path.join(HERE, ".."))
SFX = os.path.join(ROOT, "assets", "Puppet", "SFX")
OUT = os.path.join(SFX, "Spell Card SFX")
CAND = os.path.join(SFX, "_Candidates")
ANYSFX = r"D:\GitHub Projects\AnySFX"
BATCHES = os.path.join(ANYSFX, "outputs", "batches")
URL = "http://127.0.0.1:8890"
SR = 44100
NEGATIVE = "music, melody, speech, voice, vocals, singing, noise, static, low quality, silence"
LOG = os.path.join(HERE, "_spell_sfx_log.txt")
TARGET_PEAK_DB = -1.0


def log(msg):
    line = time.strftime("%H:%M:%S ") + msg
    print(line, flush=True)
    with open(LOG, "a", encoding="utf-8") as f:
        f.write(line + "\n")


# ------------------------------------------------------------------ the backend
def backend_up():
    try:
        urllib.request.urlopen(URL + "/api/health", timeout=3).read()
        return True
    except Exception:
        return False


def start_backend():
    """Starts AnySFX's backend hidden; returns the Popen (None when it was already running)."""
    if backend_up():
        return None
    log("starting the AnySFX backend")
    backend = os.path.join(ANYSFX, "backend")
    proc = subprocess.Popen([os.path.join(backend, ".venv", "Scripts", "python.exe"), "-m", "uvicorn", "app:app", "--host", "127.0.0.1", "--port", "8890"],
                            cwd=backend, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, creationflags=0x08000000)  # (no console window)
    for _ in range(120):
        if backend_up():
            return proc
        time.sleep(1)
    proc.kill()
    sys.exit("the AnySFX backend did not come up")


def generate(prompt, duration, steps=100):
    data = urllib.parse.urlencode({"prompt": prompt, "negative_prompt": NEGATIVE, "duration": duration, "steps": steps}).encode()
    job = json.loads(urllib.request.urlopen(urllib.request.Request(URL + "/api/generate", data=data), timeout=60).read())["job_id"]
    while True:
        time.sleep(2)
        st = json.loads(urllib.request.urlopen(URL + "/api/jobs/" + job, timeout=60).read())
        if st["status"] == "succeeded":
            return [os.path.join(BATCHES, r["filename"]) for r in st["results"]]
        if st["status"] == "failed":
            raise RuntimeError(st.get("error"))


# ------------------------------------------------------------------ choosing and cleaning
def load(path):
    a, sr = sf.read(path, dtype="float32", always_2d=True)
    a = a.mean(axis=1)
    if sr != SR:
        a = signal.resample_poly(a, SR, sr).astype(np.float32)
    return a


def db(x):
    return 20.0 * np.log10(max(float(x), 1e-9))


def envelope(a, win=0.01):
    n = int(SR * win)
    pad = (-len(a)) % n
    e = np.sqrt(np.mean(np.pad(a, (0, pad)).reshape(-1, n) ** 2, axis=1))
    return e


def active_span(a, floor_db=-45.0):
    """Start and end sample of the part of the sound above floor_db (relative to its peak)."""
    peak = np.max(np.abs(a)) + 1e-9
    e = envelope(a)
    live = np.nonzero(20 * np.log10(e / peak + 1e-9) > floor_db)[0]
    if len(live) == 0:
        return 0, len(a)
    n = int(SR * 0.01)
    return live[0] * n, min(len(a), (live[-1] + 1) * n)


def score(a):
    """Higher is better: it starts at once, has body, ends softly, does not clip and does not hiss."""
    peak = np.max(np.abs(a)) + 1e-9
    if peak < 0.02:
        return -99.0
    s, e = active_span(a)
    dur = len(a) / SR
    lead = s / SR
    env = envelope(a)
    envdb = 20 * np.log10(env / peak + 1e-9)
    activity = float(np.mean(envdb > -35.0))
    clip = float(np.mean(np.abs(a) > 0.99))
    tail = float(np.mean(env[-max(1, len(env) // 12):]) / (np.max(env) + 1e-9))  # (loud right up to the cut = bad)
    spec = np.abs(np.fft.rfft(a[s:e] if e - s > 2048 else a)) ** 2
    freqs = np.fft.rfftfreq(len(a[s:e] if e - s > 2048 else a), 1.0 / SR)
    hiss = float(spec[freqs > 12000].sum() / (spec.sum() + 1e-9))
    crest = peak / (np.sqrt(np.mean(a ** 2)) + 1e-9)
    return activity * 1.2 - lead * 2.0 - clip * 20.0 - tail * 1.5 - hiss * 2.0 + min(crest, 10.0) / 10.0 * 0.6 - (0.0 if dur >= 0.3 else 1.0)


_ref_rms = None


def reference_rms_db():
    """The usual loudness (RMS of the active part, dBFS) of the game's own short sounds: the new ones are matched to it."""
    global _ref_rms
    if _ref_rms is not None:
        return _ref_rms
    vals = []
    for folder in [os.path.join(SFX), os.path.join(ROOT, "assets", "Global", "SFX")]:
        for f in os.listdir(folder):
            if f.endswith(".wav"):
                try:
                    a = load(os.path.join(folder, f))
                except Exception:
                    continue
                if 0.15 < len(a) / SR < 6.0 and np.max(np.abs(a)) > 0.02:
                    s, e = active_span(a)
                    seg = a[s:e]
                    vals.append(db(np.sqrt(np.mean(seg ** 2))))
    _ref_rms = float(np.median(vals)) if vals else -20.0
    return _ref_rms


def polish(a):
    """Trim the silence at both ends, fade, match the loudness of the game's sounds, and limit the peaks."""
    sos = signal.butter(2, 30, "highpass", fs=SR, output="sos")
    a = signal.sosfilt(sos, a).astype(np.float32)
    s, e = active_span(a, -50.0)
    a = a[max(0, s - int(0.004 * SR)):min(len(a), e + int(0.02 * SR))]
    fin = int(0.003 * SR)
    fout = int(min(0.08, max(0.02, len(a) / SR * 0.12)) * SR)
    a[:fin] *= np.linspace(0, 1, fin)
    a[-fout:] *= np.linspace(1, 0, fout) ** 1.5
    rms = np.sqrt(np.mean(a ** 2)) + 1e-9
    a = a * (10 ** ((min(reference_rms_db(), -16.0) - db(rms)) / 20.0))  # (loudness matched to the game's own sounds, never above -16 dBFS RMS)
    ceiling = 10 ** (TARGET_PEAK_DB / 20.0)
    over = np.abs(a) > ceiling * 0.7
    if over.any():  # a soft limiter: nothing goes above the ceiling, the peaks are squeezed, not cut
        knee = ceiling * 0.7
        mag = np.abs(a)
        a = np.where(over, np.sign(a) * (knee + (ceiling - knee) * np.tanh((mag - knee) / (ceiling - knee))), a)
    return a.astype(np.float32)


def write(path, a):
    sf.write(path, a, SR, subtype="PCM_16")  # (16 bit: half the size of the 32-bit float the engine writes)


# ------------------------------------------------------------------ main
def main():
    args = [x for x in sys.argv[1:] if not x.startswith("--")]
    from spell_sfx_prompts import PROMPTS
    os.makedirs(OUT, exist_ok=True)
    os.makedirs(CAND, exist_ok=True)
    gd = os.path.join(CAND, ".gdignore")
    if not os.path.exists(gd):
        open(gd, "w").close()
    if "--pick" in sys.argv:
        sid, n = args[0], int(args[1])
        write(os.path.join(OUT, "spell_%s.wav" % sid), polish(load(os.path.join(CAND, "%s_%d.wav" % (sid, n)))))
        log("%s: candidate %d chosen" % (sid, n))
        return
    redo = "--redo" in sys.argv
    ids = args or list(PROMPTS)
    todo = [i for i in ids if redo or not os.path.exists(os.path.join(OUT, "spell_%s.wav" % i))]
    log("%d to make (%d already done)" % (len(todo), len(ids) - len(todo)))
    proc = start_backend()
    try:
        for k, sid in enumerate(todo):
            prompt, dur = PROMPTS[sid]
            t0 = time.time()
            try:
                files = generate(prompt, dur)
            except Exception as exc:
                log("%s FAILED: %s" % (sid, exc))
                continue
            audios = [load(f) for f in files]
            scores = [score(a) for a in audios]
            best = int(np.argmax(scores))
            for n, a in enumerate(audios):
                write(os.path.join(CAND, "%s_%d.wav" % (sid, n)), a)
            write(os.path.join(OUT, "spell_%s.wav" % sid), polish(audios[best]))
            log("[%d/%d] %-24s pick %d of %s  (%.0f s)  %s" % (k + 1, len(todo), sid, best, " ".join("%.2f" % x for x in scores), time.time() - t0, prompt))
    finally:
        if proc is not None:
            log("stopping the AnySFX backend")
            proc.terminate()


if __name__ == "__main__":
    main()
