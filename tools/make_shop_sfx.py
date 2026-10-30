"""The merchant's sounds, cut from the Sonniss GDC libraries (E:\\Soniss SFX) into assets/Puppet/SFX (44.1 kHz stereo, 16 bit).

Run with D:\\GitHub Projects\\AnySFX\\backend\\.venv\\Scripts\\python.exe (it has numpy and soundfile); ffmpeg must be on the PATH.
    shop_card_pop.wav    a wooden card flips up off the floor (played three times at slightly different pitches)
    shop_frame_drop.wav  a frame is let down on its ropes: a rope whoosh, then the wood lands
    shop_cart_roll.wav   cart wheels clattering on stone and grit, 4.4 s, fading as the cart slows
    shop_step.wav / shop_step_2.wav   one boot on dirt (alternated)
    shop_buy.wav         a purchase: gold coins dropped on coins, and a pouch taking them
"""
import subprocess
import sys
from pathlib import Path

import numpy as np
import soundfile as sf

SONNISS = Path(r"E:\Soniss SFX")
OUT = Path(__file__).resolve().parent.parent / "assets" / "Puppet" / "SFX"
RATE = 44100


def find(pattern: str) -> Path:
    for p in SONNISS.rglob("*"):
        if p.is_file() and pattern in p.name and "__MACOSX" not in p.parts:
            return p
    sys.exit("not found in Soniss: " + pattern)


def load(path: Path, start=0.0, length=None) -> np.ndarray:
    """Stereo float32 at RATE (ffmpeg does the resampling and the mono -> stereo)."""
    cmd = ["ffmpeg", "-v", "error", "-ss", str(start)]
    if length:
        cmd += ["-t", str(length)]
    cmd += ["-i", str(path), "-f", "f32le", "-ac", "2", "-ar", str(RATE), "-"]
    raw = subprocess.run(cmd, capture_output=True, check=True).stdout
    return np.frombuffer(raw, dtype=np.float32).reshape(-1, 2).copy()


def fade(a: np.ndarray, fin=0.0, fout=0.0) -> np.ndarray:
    a = a.copy()
    n_in, n_out = int(fin * RATE), int(fout * RATE)
    if n_in:
        a[:n_in] *= np.linspace(0, 1, n_in)[:, None]
    if n_out:
        a[-n_out:] *= np.linspace(1, 0, n_out)[:, None] ** 1.5
    return a


def onset(a: np.ndarray, frac=0.1) -> int:
    m = np.abs(a).max(axis=1)
    return int(np.argmax(m > frac * m.max()))


def trim_to_hit(a: np.ndarray, length: float, pre=0.01) -> np.ndarray:
    i = max(0, onset(a) - int(pre * RATE))
    return a[i:i + int(length * RATE)]


def mix(parts) -> np.ndarray:
    """parts: [(audio, start seconds, gain)]"""
    n = max(int(s * RATE) + len(a) for a, s, _ in parts)
    out = np.zeros((n, 2), dtype=np.float32)
    for a, s, g in parts:
        i = int(s * RATE)
        out[i:i + len(a)] += a * g
    return out


def peak(a: np.ndarray, db: float) -> np.ndarray:
    return a * (10 ** (db / 20) / max(1e-6, float(np.abs(a).max())))


def steadiest(a: np.ndarray, length: float) -> int:
    """Start (samples) of the `length`-second window that is loud and the most even."""
    win = int(length * RATE)
    hop = RATE // 4
    best, best_i = None, 0
    env = np.sqrt(np.convolve((a ** 2).mean(axis=1), np.ones(RATE // 20) / (RATE // 20), "same"))
    level = np.median(env[env > 0])
    for i in range(0, len(a) - win, hop):
        seg = env[i:i + win]
        score = seg.std() / (seg.mean() + 1e-9) + (0.0 if seg.mean() > level else 1.0)
        if best is None or score < best:
            best, best_i = score, i
    return best_i


def save(name: str, a: np.ndarray) -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    sf.write(OUT / name, np.clip(a, -1, 1), RATE, subtype="PCM_16")
    print("wrote", name, f"{len(a) / RATE:.2f}s")


def main() -> None:
    # a wooden card flipping up: the crisp wooden crack
    pop = trim_to_hit(load(find("Impacts Soft - Short, Crack")), 0.45)
    save("shop_card_pop.wav", fade(peak(pop, -4), 0.0, 0.08))

    # a frame let down: rope whoosh, then the wooden panel lands where the fall ends (the fall is 0.55 s)
    whoosh = load(find("Swoosh_Rope_Whip_075"))
    whoosh = trim_to_hit(whoosh, 0.55, 0.0)
    thud = trim_to_hit(load(find("Dropping_WoodPanel_Multi_6")), 0.9)
    drop = mix([(fade(peak(whoosh, -14), 0.02, 0.15), 0.0, 1.0), (fade(peak(thud, -5), 0.0, 0.25), 0.5, 1.0)])
    save("shop_frame_drop.wav", peak(drop, -2))

    # the cart: wheels clattering on stone, grit under it; it slows as the cart does
    cart = load(find("Wood Cart Roll On Stone Pavement"))
    i = steadiest(cart, 4.4)
    cart = cart[i:i + int(4.4 * RATE)]
    grit = load(find("Pebbles Dust Tumbling"))
    j = steadiest(grit, 4.4)
    grit = grit[j:j + int(4.4 * RATE)]
    roll = mix([(peak(cart, -8), 0.0, 1.0), (peak(grit, -18), 0.0, 1.0)])
    save("shop_cart_roll.wav", peak(fade(roll, 0.2, 2.4), -4))

    # a purchase: coins clinking on coins, a leather pouch under them
    clink = trim_to_hit(load(find("262703 - Drop Couple of Gold Coins")), 0.9)
    pouch = trim_to_hit(load(find("Coins_Pouch_Leather_Drop_Into_Takes_3")), 0.5)
    buy = mix([(fade(peak(pouch, -10), 0.0, 0.2), 0.0, 1.0), (fade(peak(clink, -4), 0.0, 0.3), 0.06, 1.0)])
    save("shop_buy.wav", peak(buy, -3))

    # his boots on dirt
    for n, key in ((1, "Single_Step_Footstep_19"), (2, "Single_Step_Footstep_46")):
        step = trim_to_hit(load(find("PM_SDNG_" + key)), 0.4)
        save("shop_step.wav" if n == 1 else "shop_step_2.wav", fade(peak(step, -6), 0.0, 0.12))


if __name__ == "__main__":
    main()
