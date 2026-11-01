"""Event art (2026-11-01): ImageSet's "Puppet Events" pictures -> assets/Puppet/Events/<name>.png at FULL size.

The white background is cut with Tachnen's BiRefNet (run this with Tachnen's python) and the picture is trimmed to its outline, nothing is scaled.
"Event Church" becomes event_church.png; `UiSkin.tex("event_church")` finds it (Events is in UiSkin.FOLDERS).
Run:  "D:/GitHub Projects/Tachnen/.venv/Scripts/python.exe" tools/import_event_art.py [--force] [name ...]   (then Godot --headless --editor --quit once)"""
import glob
import os
import re
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import asset_paths as AP

TACHNEN = r"D:\GitHub Projects\Tachnen"
sys.path.insert(0, TACHNEN)
from PIL import Image

RAW = r"E:\GitHub\ImageSet\output\Puppet Events"
OUT = os.path.join(AP.PUPPET, "Events")
CUT_OPTS = {"model": "birefnet-general", "use_gpu": True, "gpu_mem_gb": 0, "alpha_matting": False, "am_fg": 240, "am_bg": 10,
            "am_erode": 10, "post_process_mask": True, "defringe": True, "alpha_cutoff": 0, "feather": 0.0, "bg_mode": "transparent",
            "bg_custom": "#00ff00", "trim": False, "pad": 0}
_proc = None
HAND_MADE = {"Event Bridge Stream"}  # (the user painted these over the generated picture: the importer must never write them again)


def newest(name):
    files = [f for f in glob.glob(os.path.join(glob.escape(RAW), glob.escape(name) + "_*.png"))
             if re.search(r"_\d{8}_\d{6}\.png$", f)]
    return max(files, key=os.path.getmtime) if files else None


def cut(path):
    global _proc
    if _proc is None:
        import tachnen_core as core
        _proc = core.Processor()
    return _proc.run(Image.open(path).convert("RGBA"), CUT_OPTS)


def decontaminate(im, band=3):
    """The cut leaves a white halo: the outermost pixels are blends of the picture and its white backdrop. The edge band takes the colour of the nearest pixel
    deeper inside (the same idea as AnyVideoPixel's pixelize.decontaminate), the alpha stays as cut, so the outline stays soft but is never white."""
    import numpy as np
    from scipy import ndimage as ndi
    a = np.asarray(im.convert("RGBA")).copy()
    solid = a[..., 3] >= 200
    core = ndi.binary_erosion(solid, iterations=band)
    if not core.any():
        core = solid
    iy, ix = ndi.distance_transform_edt(~core, return_distances=False, return_indices=True)
    a[..., :3] = np.where(core[..., None], a[..., :3], a[iy, ix, :3])
    a[a[..., 3] < 6] = 0
    return Image.fromarray(a, "RGBA")


def trim(im):
    return im.crop(im.getchannel("A").point(lambda v: 255 if v > 8 else 0).getbbox())


def main():
    args = sys.argv[1:]
    force = "--force" in args
    only = [a for a in args if not a.startswith("--")]
    os.makedirs(OUT, exist_ok=True)
    names = sorted({os.path.basename(f).rsplit("_", 2)[0] for f in glob.glob(os.path.join(glob.escape(RAW), "Event *_*.png"))})
    for name in names:
        if only and name not in only:
            continue
        dest = os.path.join(OUT, name.lower().replace(" ", "_") + ".png")
        if name in HAND_MADE and os.path.exists(dest):
            print("  (hand-made, never overwritten)", name)
            continue
        if os.path.exists(dest) and not force:
            print("  (have)", name)
            continue
        src = newest(name)
        if src is None:
            continue
        im = trim(decontaminate(cut(src)))
        im.save(dest)
        print("  ", name, "->", os.path.basename(dest), im.size)
        if name == "Event Mystery Book":  # (it is also the artifact's icon, like every artifact icon 128 px on its long edge)
            icon = im.copy()
            icon.thumbnail((128, 128), Image.LANCZOS)
            icon.save(os.path.join(AP.PUPPET, "Icon", "Artifact", "mystery_book.png"))


def artifacts():
    """ImageSet set "Puppet Event Artifacts": the Mystery Shed's two prizes become artifact icons (128 px on the long edge, like the others)."""
    raw = r"E:\GitHub\ImageSet\output\Puppet Event Artifacts"
    jobs = {"Artifact Half Eaten Candy": "half_eaten_candy", "Artifact Dollar Bill": "dollar_bill"}
    for name, art_id in jobs.items():
        files = [f for f in glob.glob(os.path.join(glob.escape(raw), glob.escape(name) + "_*.png")) if re.search(r"_\d{8}_\d{6}\.png$", f)]
        if not files:
            print("  (no picture yet)", name)
            continue
        im = trim(decontaminate(cut(max(files, key=os.path.getmtime))))
        im.thumbnail((128, 128), Image.LANCZOS)
        im.save(os.path.join(AP.PUPPET, "Icon", "Artifact", art_id + ".png"))
        print("  ", name, "->", art_id + ".png", im.size)


if __name__ == "__main__":
    if "--artifacts" in sys.argv:
        artifacts()
    else:
        main()
