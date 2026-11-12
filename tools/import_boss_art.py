"""2026-11-08: cut + place the raw ImageSet pictures of the new Act 2 enemies and the Pianist's pieces (made by tools/gen_boss_art.py).
  bosses : Rot Snake, The Corrector, Corrector Small Screen -> Enemies/Act2/<id>.png (FULL size, square canvas, feet on the bottom edge, like import_act2_mobs.py)
           Blue Sentinel = the existing blue-cored golem (sentinel.png) kept as blue_sentinel.png; sentinel.png becomes the same golem with a RED core (hue shift of the blue core only)
  pianist: the pieces -> Enemies/Act2/pianist/<piece>.png (trimmed to the piece, NOT squared: PianistRig measures them)
Each cut keeps only the largest blob (drops Gemini's sparkle mark and loose flies/dust).
Run:  "D:/GitHub Projects/Tachnen/.venv/Scripts/python.exe" tools/import_boss_art.py bosses|pianist|sentinel [name ...]
(then Godot --headless --editor --quit once)"""
import glob
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import paths
import asset_paths as AP

sys.path.insert(0, paths.TACHNEN)
import numpy as np
from PIL import Image
from scipy.ndimage import label

OUT = os.path.join(AP.PUPPET, "Enemies", "Act2")
SRC = os.path.join(AP.PUPPET, "Enemies", "_Source", "Act2")
RAW = (paths.IMAGESET_OUT + r"\output")
CUT_OPTS = {"model": "birefnet-general", "use_gpu": True, "gpu_mem_gb": 0, "alpha_matting": False, "am_fg": 240, "am_bg": 10,
            "am_erode": 10, "post_process_mask": True, "defringe": True, "alpha_cutoff": 0, "feather": 0.0, "bg_mode": "transparent",
            "bg_custom": "#00ff00", "trim": False, "pad": 0}
BOSSES = {"Puppet Rot Snake": "rot_snake", "Puppet The Corrector": "corrector", "Puppet Corrector Small Screen": "corrector_small_screen"}
PIECES = {"Pianist " + n: "pianist_" + n.lower().replace(" ", "_") for n in ["Body", "Arm Upper", "Arm Lower", "Thigh", "Shin", "Piano", "Keys", "Music Stand", "Sign"]}
_proc = None


def newest(set_name, name):
    files = [f for f in glob.glob(os.path.join(glob.escape(os.path.join(RAW, set_name)), glob.escape(name) + "_*.*"))
             if f.lower().endswith((".png", ".jpg", ".jpeg")) and os.path.splitext(os.path.basename(f)[len(name) + 1:])[0].replace("_", "").isdigit()]
    return max(files, key=os.path.getmtime) if files else None


def cut(path):
    global _proc
    if _proc is None:
        import tachnen_core as core
        _proc = core.Processor()
    return _proc.run(Image.open(path).convert("RGBA"), CUT_OPTS)


def largest(im):
    a = np.array(im)
    lab, n = label(a[:, :, 3] > 8)
    if n > 1:
        sizes = np.bincount(lab.ravel())[1:]
        a[:, :, 3] = np.where(lab == (1 + int(np.argmax(sizes))), a[:, :, 3], 0)
    return Image.fromarray(a)


def trim(im):
    return im.crop(im.getchannel("A").point(lambda v: 255 if v > 8 else 0).getbbox())


def square(im, pad=0.04):
    side = int(max(im.size) * (1 + pad * 2))
    c = Image.new("RGBA", (side, side), (0, 0, 0, 0))
    c.alpha_composite(im, ((side - im.width) // 2, side - im.height - int(side * pad * 0.5)))
    return c


def do_bosses(only):
    os.makedirs(SRC, exist_ok=True)
    for name, ident in BOSSES.items():
        if only and not any(w.lower() in name.lower() for w in only):
            continue
        f = newest("Act 2 Bosses", name)
        if f is None:
            print("  MISSING raw picture for", name)
            continue
        im = trim(largest(cut(f)))
        im.save(os.path.join(SRC, name + ".png"))
        out = im if ident == "corrector_small_screen" else square(im)  # (the small screen is a loose piece: trimmed only)
        out.save(os.path.join(OUT, ident + ".png"))
        print("  %-30s -> %s.png %s" % (name, ident, out.size), flush=True)


def do_pianist(only):
    d = os.path.join(OUT, "pianist")
    os.makedirs(d, exist_ok=True)
    for name, ident in PIECES.items():
        if only and not any(w.lower() in name.lower() for w in only):
            continue
        f = newest("Pianist Pieces", name)
        if f is None:
            print("  MISSING raw picture for", name)
            continue
        im = trim(largest(cut(f)))
        im.save(os.path.join(d, ident + ".png"))
        print("  %-18s -> pianist/%s.png %s" % (name, ident, im.size), flush=True)


ICONS = {"Intent " + n: ("Icon/Intent/intent_%s.png" % n.lower().replace(" ", "_"), 128) for n in ["Virus", "Burden", "Play", "Deflect", "Bottle", "Steal Spell", "Fireball", "Fireball Blast"]}
ARTIFACTS = {"Artifact Turkish March": ("Icon/Artifact/turkish_march.png", 128), "Artifact Fur Elise": ("Icon/Artifact/fur_elise.png", 128)}
STATUS_COPIES = {"Icon/Intent/intent_virus.png": "Icon/Effect/status_virus.png", "Icon/Intent/intent_burden.png": "Icon/Effect/status_burden.png"}


def do_icons(set_name, table, only):
    """Small icons: cut (Tachnen), trimmed, scaled so the longest edge is 128 px (like tools/make_missing_icons.py)."""
    import shutil
    for name, (rel, size) in table.items():
        if only and not any(w.lower() in name.lower() for w in only):
            continue
        f = newest(set_name, name)
        if f is None:
            print("  MISSING raw picture for", name)
            continue
        im = trim(largest(cut(f)))
        k = size / max(im.size)
        im = im.resize((max(1, round(im.width * k)), max(1, round(im.height * k))), Image.LANCZOS)
        im.save(os.path.join(AP.PUPPET, *rel.split("/")))
        print("  %-24s -> %s %s" % (name, rel, im.size), flush=True)
    for src, dst in STATUS_COPIES.items():
        if os.path.exists(os.path.join(AP.PUPPET, *src.split("/"))) and table is ICONS:
            shutil.copyfile(os.path.join(AP.PUPPET, *src.split("/")), os.path.join(AP.PUPPET, *dst.split("/")))


BACK = {"Pianist Back": {"Pianist Back A": "pianist_a", "Pianist Back B": "pianist_b", "Pianist Back Grand Piano": "piano_1", "Pianist Back Grand Piano 2": "piano_2", "Pianist Back Stool": "stool"},
        "Pianist Back Parts": {n: "part_" + n.lower().replace(" ", "_") for n in ["Back Torso A", "Back Torso B", "Back Head A", "Back Head B", "Forearm Tap A", "Forearm Tap B", "Forearm Point A", "Forearm Point B", "Forearm Fist A", "Forearm Fist B", "Empty Sleeve A", "Empty Sleeve B"]},
        "Pianist Back Props": {**{"Sheet Music %d" % k: "sheet_%d" % k for k in range(1, 5)}, "Silence Sign A": "sign_a", "Silence Sign B": "sign_b"}}


def keep_blobs(im, min_frac=0.004):
    """Keep every piece of the cut that is bigger than min_frac of the biggest one (the A-pose figure's arms may be loose pieces; Gemini's sparkle mark is tiny)."""
    a = np.array(im)
    lab, n = label(a[:, :, 3] > 8)
    if n > 1:
        sizes = np.bincount(lab.ravel())
        keep = [i for i in range(1, n + 1) if sizes[i] >= sizes[1:].max() * min_frac]
        a[:, :, 3] = np.where(np.isin(lab, keep), a[:, :, 3], 0)
    return Image.fromarray(a)


def do_back(only):
    """2026-11-09, the view from behind (the user's Pianist.pdf): full size, trimmed, into Enemies/Act2/pianist/back/ (the user cuts the A-pose figure by hand)."""
    d = os.path.join(OUT, "pianist", "back")
    os.makedirs(d, exist_ok=True)
    for set_name, table in BACK.items():
        for name, ident in table.items():
            if only and not any(w.lower() in name.lower() for w in only):
                continue
            f = newest(set_name, name)
            if f is None:
                print("  MISSING raw picture for", name)
                continue
            im = trim(keep_blobs(cut(f)))
            im.save(os.path.join(d, ident + ".png"))
            print("  %-28s -> pianist/back/%s.png %s" % (name, ident, im.size), flush=True)


def do_sentinel():
    """The existing golem has a BLUE core: keep it as the Blue Sentinel, and make the Red one by turning the blue pixels red."""
    blue = os.path.join(OUT, "blue_sentinel.png")
    sent = os.path.join(OUT, "sentinel.png")
    if not os.path.exists(blue):
        Image.open(sent).save(blue)  # (first run: the old picture becomes the blue one)
    im = Image.open(blue).convert("RGBA")
    hsv = np.array(im.convert("RGB").convert("HSV")).astype(np.int32)
    h, s, v = hsv[:, :, 0], hsv[:, :, 1], hsv[:, :, 2]
    mask = (h > 120) & (h < 175) & (s > 90) & (v > 60)  # blue (PIL hue 0..255: blue is about 170 = 240 deg; cyan 128)
    hsv[:, :, 0] = np.where(mask, (h - 150) % 256, h)  # blue -> red
    rgb = Image.fromarray(hsv.astype(np.uint8), "HSV").convert("RGB")
    out = np.array(im)
    out[:, :, :3] = np.array(rgb)
    Image.fromarray(out).save(sent)
    print("  red core pixels:", int(mask.sum()), "-> sentinel.png (red), blue_sentinel.png (blue)")


if __name__ == "__main__":
    what = sys.argv[1]
    rest = sys.argv[2:]
    if what == "icons":
        do_icons("Puppet Intent Bosses", ICONS, rest)
    elif what == "back":
        do_back(rest)
    elif what == "artifacts":
        do_icons("Puppet Artifact Piano", ARTIFACTS, rest)
    else:
        {"bosses": do_bosses, "pianist": do_pianist}.get(what, lambda o: do_sentinel())(rest)
