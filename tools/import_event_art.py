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
RAWS = [RAW, r"E:\GitHub\ImageSet\output\Puppet Events Act2", r"E:\GitHub\ImageSet\output\Puppet Events Fixes", r"E:\GitHub\ImageSet\output\Puppet Events Fixes Wide"]  # (the second act's pictures have their own set and style)
OUT = os.path.join(AP.PUPPET, "Events")
CUT_OPTS = {"model": "birefnet-general", "use_gpu": True, "gpu_mem_gb": 0, "alpha_matting": False, "am_fg": 240, "am_bg": 10,
            "am_erode": 10, "post_process_mask": True, "defringe": True, "alpha_cutoff": 0, "feather": 0.0, "bg_mode": "transparent",
            "bg_custom": "#00ff00", "trim": False, "pad": 0}
_proc = None
NO_CUT = {"Event Mausoleum Wall"}  # (a wall that fills its whole picture: kept as it is, no cut-out)
HAND_MADE = {"Event Bridge Stream"}  # (the user painted these over the generated picture: the importer must never write them again)


def newest(name):
    files = [f for raw in RAWS for f in glob.glob(os.path.join(glob.escape(raw), glob.escape(name) + "_*.png"))
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


SPARKLE = {"Event Mausoleum Frame": ((1219, 630), (0, -95)), "Event Mausoleum Wall": ((1255, 644), (-130, 0))}  # name: (star centre, where to copy from, as an offset)


def unmark(im, centre, shift, r=34):
    from PIL import ImageDraw, ImageFilter
    mask = Image.new("L", im.size, 0)
    ImageDraw.Draw(mask).ellipse((centre[0] - r, centre[1] - r, centre[0] + r, centre[1] + r), fill=255)
    mask = mask.filter(ImageFilter.GaussianBlur(5))
    src = Image.new("RGBA", im.size)
    src.paste(im, (-shift[0], -shift[1]))
    out = im.copy()
    out.paste(src, (0, 0), mask)
    return out


def inside():
    """The mausoleum seen from inside: the stone wall is put behind the opening of the frame (one picture, written as event_mausoleum_inside.png)."""
    import numpy as np
    frame = Image.open(os.path.join(OUT, "event_mausoleum_frame.png")).convert("RGBA")
    wall = Image.open(os.path.join(OUT, "event_mausoleum_wall.png")).convert("RGB")
    a = np.asarray(frame.getchannel("A"))
    h, w = a.shape
    row = a[int(h * 0.78)] < 128
    mid = w // 2
    x0 = mid
    while x0 > 0 and row[x0 - 1]:
        x0 -= 1
    x1 = mid
    while x1 < w - 1 and row[x1 + 1]:
        x1 += 1
    col = a[:, mid] < 128
    y0 = int(h * 0.37)  # (up under the beam: the frame hides the top of the wall)
    y1 = h
    print("   opening", x0, y0, x1, y1, "of", w, h)
    wall = wall.resize((x1 - x0 + 8, y1 - y0 + 8), Image.LANCZOS)
    out = Image.new("RGBA", frame.size, (0, 0, 0, 0))
    out.paste(wall.convert("RGBA"), (x0 - 4, y0 - 4))
    shade = Image.new("RGBA", frame.size, (20, 25, 45, 90))
    out.alpha_composite(shade, (0, 0)) if False else None
    out.alpha_composite(frame)
    out.save(os.path.join(OUT, "event_mausoleum_inside.png"))
    print("  event_mausoleum_inside.png", out.size)


def trim(im):
    return im.crop(im.getchannel("A").point(lambda v: 255 if v > 8 else 0).getbbox())


def main():
    args = sys.argv[1:]
    force = "--force" in args
    only = [a for a in args if not a.startswith("--")]
    os.makedirs(OUT, exist_ok=True)
    names = sorted({os.path.basename(f).rsplit("_", 2)[0] for raw in RAWS for f in glob.glob(os.path.join(glob.escape(raw), "Event *_*.png"))})
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
        im = Image.open(src).convert("RGBA") if name in NO_CUT else trim(decontaminate(cut(src)))
        if name in SPARKLE:  # (Gemini left its star on these two: patched over with a piece of the same surface)
            im = unmark(im, *SPARKLE[name])
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
    if "--inside" in sys.argv:
        inside()
    elif "--artifacts" in sys.argv:
        artifacts()
    else:
        main()
