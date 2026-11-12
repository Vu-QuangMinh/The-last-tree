r"""The frames painted by tools/make_frame_art.py (ImageSet's output folders "Puppet Frames Wide" / "Puppet Frames Round") -> assets/Puppet/UI/Panels/frame_<name>.png, small 9-slice pictures.
The object is cut off its black background (reached from the corners), scaled to the width it will have on screen, and for the wide ones the uniform middle rows are taken out so
the painted rim keeps its proportions at the height wanted. The raw pictures are kept in assets/Puppet/_Source/Frames/.
Run: python tools/cut_frame_art.py   (needs pillow; then Godot --headless --path . --import --quit so the new files are imported)"""
import glob
import os
import shutil
import sys

from PIL import Image, ImageDraw, ImageFilter

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import paths
import asset_paths as AP

OUT = os.path.join(AP.PUPPET, "UI", "Panels")
SRC = os.path.join(AP.PUPPET, "_Source", "Frames")
RAW = (paths.IMAGESET_OUT + r"\output")  # (ImageSet keeps its pictures on E:)
# (ImageSet set, object name, file made, width, height; height 0 = keep the picture's own proportions)
PIECES = [
    ("Puppet Frames Wide", "Frame Bubble Dark", "frame_bubble_dark", 192, 80),
    ("Puppet Frames Wide", "Frame Plaque Cream", "frame_plaque_cream", 192, 88),
    ("Puppet Frames Wide", "Frame Pill", "frame_pill", 144, 48),
    ("Puppet Frames Wide", "Frame Card Slot", "frame_card_slot", 192, 88),
    ("Puppet Frames Round", "Frame Round Socket", "frame_round_socket", 128, 0),
]


def erase_star(im):
    """ImageSet's little Gemini star sits in the same place of every picture (bottom right, about 94-98% across and 89-96% down): that spot is smoothed over with a
    median, blended into what is around it."""
    w, h = im.size
    box = (int(w * 0.925), int(h * 0.875), int(w * 0.99), int(h * 0.975))
    patch = im.crop(box).filter(ImageFilter.MedianFilter(61)).filter(ImageFilter.GaussianBlur(3))
    mask = Image.new("L", patch.size, 0)
    ImageDraw.Draw(mask).rectangle((14, 14, patch.width - 15, patch.height - 15), fill=255)
    mask = mask.filter(ImageFilter.GaussianBlur(10))
    im.paste(patch, box[:2], mask)
    return im


def cut(im):
    """The object on the black background: crop to it, background (reached from the corners) transparent."""
    im = erase_star(im.convert("RGB"))
    mask = im.point(lambda v: 255 if v > 20 else 0).convert("L")
    # the object's box: the rows and columns it really fills (ImageSet's little Gemini star in the corner would stretch a plain bounding box)
    cols = mask.resize((mask.width, 1), Image.BOX)
    rows = mask.resize((1, mask.height), Image.BOX)
    xs = [x for x in range(mask.width) if cols.getpixel((x, 0)) > 0.2 * max(cols.tobytes())]
    ys = [y for y in range(mask.height) if rows.getpixel((0, y)) > 0.2 * max(rows.tobytes())]
    im = im.crop((xs[0], ys[0], xs[-1] + 1, ys[-1] + 1))
    dark = im.convert("L").point(lambda v: 255 if v <= 20 else 0)
    border = [(x, 0) for x in range(im.width)] + [(x, im.height - 1) for x in range(im.width)] + [(0, y) for y in range(im.height)] + [(im.width - 1, y) for y in range(im.height)]
    for pt in border:  # (the black reached from anywhere on the border is background; a round object has black at its corners only)
        if dark.getpixel(pt) == 255:
            ImageDraw.floodfill(dark, pt, 128)
    alpha = dark.point(lambda v: 0 if v == 128 else 255).filter(ImageFilter.GaussianBlur(0.8))
    out = im.convert("RGBA")
    out.putalpha(alpha)
    return out


def squash(im, out_h):
    """Take the uniform middle rows out so the picture is out_h high (the rim and corners keep their size)."""
    cut_rows = im.height - out_h
    if cut_rows <= 0:
        return im
    top = im.crop((0, 0, im.width, (im.height - cut_rows) // 2))
    bottom = im.crop((0, (im.height + cut_rows) // 2, im.width, im.height))
    out = Image.new("RGBA", (im.width, top.height + bottom.height))
    out.paste(top, (0, 0))
    out.paste(bottom, (0, top.height))
    return out


def latest(set_name, name):
    files = glob.glob(os.path.join(RAW, set_name, name + "_*.png"))
    return max(files, key=os.path.getmtime) if files else None


def main():
    os.makedirs(SRC, exist_ok=True)
    for set_name, name, outname, w, h in PIECES:
        f = latest(set_name, name)
        if f is None:
            print("missing:", set_name, name)
            continue
        shutil.copy(f, os.path.join(SRC, name + ".png"))
        im = cut(Image.open(f))
        if h:
            s = w / im.width
            im = im.resize((w, max(1, round(im.height * s))), Image.LANCZOS)
            im = squash(im, h)
        else:
            im = im.resize((w, w), Image.LANCZOS)
        im.save(os.path.join(OUT, outname + ".png"))
        print(outname, im.size)


if __name__ == "__main__":
    main()
