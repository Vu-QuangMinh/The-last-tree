"""Puppet Stage UI pieces: ImageSet's raw 2048 px pictures -> the small game-ready PNGs in assets/Puppet/UI/<folder>/.

For every row of PIECES the newest raw picture "<ImageSet name>_YYYYMMDD_HHMMSS.png" is looked up in assets/Puppet/UI/_Source/<folder>/ (or, for the
rows that reuse a picture of another folder, in that folder), its white background is cut out, it is trimmed and scaled to the size the game's code
expects (the 9-slice margins in ui_theme.gd / ui_skin.gd are in pixels of THIS size), and it is written under its lookup name.
Buttons also get their hover / pressed / disabled states made from the one normal picture (brighter / darker and richer / washed out).

The background cut uses the Tachnen tool's rembg setup (BiRefNet, GPU), so run this with Tachnen's python:
    "D:/GitHub Projects/Tachnen/.venv/Scripts/python.exe" tools/import_puppet_ui.py [name ...]      (no name = every piece)
then run Godot once with --headless --editor --quit so it imports the new files.
The icon sets (Puppet/Icon/{Artifact,Bottle,Effect,Intent}) are cut in bulk:  ... import_puppet_ui.py artifact|bottle|effect|intent"""
import glob
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import asset_paths as AP

TACHNEN = r"D:\GitHub Projects\Tachnen"
sys.path.insert(0, TACHNEN)
import numpy as np
from PIL import Image, ImageEnhance

UI = os.path.join(AP.PUPPET, "UI")
SRC = os.path.join(UI, "_Source")
CUT_OPTS = {"model": "birefnet-general", "use_gpu": True, "gpu_mem_gb": 0, "alpha_matting": False, "am_fg": 240, "am_bg": 10,
            "am_erode": 10, "post_process_mask": True, "defringe": True, "alpha_cutoff": 0, "feather": 0.0, "bg_mode": "transparent",
            "bg_custom": "#00ff00", "trim": True, "pad": 0}

# lookup name: (folder it is written to, raw picture name, source folder (inside UI/_Source, or a UI folder for reused pictures), size, kind)
# size = the exact pixel size (w, h) or ("fit", n) = fit inside n x n on a square canvas; kind picks the extra processing
PIECES = {
    # Characters
    "merchant_portrait": ("Characters", "Portrait Merchant", "Characters", ("fit", 512), "plain"),
    "portrait_keeper": ("Characters", "Map Icon You Are Here", "@Map", ("fit", 256), "plain"),
    # Buttons (one normal picture; the other states are made from it)
    "button_small_normal": ("Buttons", "Button Small", "Buttons", (88, 36), "button4"),
    "button_menu_normal": ("Buttons", "Button Menu", "Buttons", (131, 46), "button3"),
    "button_play_hover": ("Buttons", "Button Play Hover", "Buttons", (141, 58), "plain"),
    # Essence
    "essence_fire": ("Essence", "Essence Fire", "Essence", ("fit", 128), "plain"),
    "essence_water": ("Essence", "Essence Water", "Essence", ("fit", 128), "plain"),
    "essence_wind": ("Essence", "Essence Wind", "Essence", ("fit", 128), "plain"),
    "essence_any": ("Essence", "Essence Any", "Essence", ("fit", 128), "ball"),
    # Fx
    "target_marker": ("Fx", "Fx Target Marker", "Fx", ("fit", 160), "ring"),
    "essence_frozen_overlay": ("Fx", "Fx Essence Frozen Overlay", "Fx", ("fit", 128), "frost"),
    "x_essence_overlay": ("Fx", "Fx X Essence Overlay", "Fx", ("fit", 128), "plain"),
    # Icons (the HUD's heart / shield / Leaves coin / Seedling: lookup names kept from the New theme)
    "icon_heart": ("Icons", "Icon Heart", "Icons", ("max", 128), "plain"),
    "icon_armor_shield": ("Icons", "Icon Shield", "Icons", ("max", 128), "plain"),
    "icon_amber": ("Icons", "Icon Wooden Coin", "Icons", ("max", 128), "plain"),
    "icon_seedling": ("Icons", "Icon Seedling", "Icons", ("max", 128), "plain"),
    "icon_spellbook": ("Icons", "Icon Spellbook", "Icons", ("max", 128), "plain"),
    "icon_skull": ("Icons", "Icon Skull", "Icons", ("fit", 128), "plain"),
    # HP blocks (already cut out: kind "nocut"; hp_tray is the user's own picture, an exact file name)
    "hp_block_red": ("Hp", "Wood Block Red", "Hp", ("fit", 96), "nocut"),
    "hp_block_blue": ("Hp", "Wood Block Blue", "Hp", ("fit", 96), "nocut"),
    "hp_shard_red_a": ("Hp", "Wood Block Red Shard A", "Hp", ("fit", 64), "nocut"),
    "hp_shard_red_b": ("Hp", "Wood Block Red Shard B", "Hp", ("fit", 64), "nocut"),
    "hp_shard_blue_a": ("Hp", "Wood Block Blue Shard A", "Hp", ("fit", 64), "nocut"),
    "hp_shard_blue_b": ("Hp", "Wood Block Blue Shard B", "Hp", ("fit", 64), "nocut"),
    "hp_tray": ("Hp", "HP Bar Frame.png", "Hp", (822, 174), "nocut"),
    # Spell card frame, treasure frames + medal rings, map rings (folder starting with "/" = relative to assets/Puppet)
    "spell_card_frame": ("/Card", "Spell Card Frame", "Card", (250, 200), "plain"),
    "treasure_card_frame": ("/Card/Treasure", "Treasure Card Frame", "Treasure", (140, 160), "plain"),
    "treasure_card_frame_hover": ("/Card/Treasure", "Treasure Card Frame Hover", "Treasure", (140, 160), "plain"),
    "treasure_card_frame_cursed": ("/Card/Treasure", "Treasure Card Frame Cursed", "Treasure", (140, 160), "plain"),
    "medal_ring_common": ("/Card/Treasure", "Medal Ring Common", "Treasure", ("fit", 128), "plain"),
    "medal_ring_rare": ("/Card/Treasure", "Medal Ring Rare", "Treasure", ("fit", 128), "plain"),
    "medal_ring_legendary": ("/Card/Treasure", "Medal Ring Legendary", "Treasure", ("fit", 128), "plain"),
    "medal_ring_cursed": ("/Card/Treasure", "Medal Ring Cursed", "Treasure", ("fit", 128), "plain"),
    "map_path_dot": ("/Map", "Map Path Dot", "MapRings", ("fit", 48), "plain"),
    "map_ring_normal": ("/Map", "Map Ring Normal", "MapRings", ("fit", 128), "plain"),
    "map_ring_elite": ("/Map", "Map Ring Elite", "MapRings", ("fit", 128), "plain"),
    "map_ring_boss": ("/Map", "Map Ring Boss", "MapRings", ("fit", 128), "plain"),
    "map_ring_campfire": ("/Map", "Map Ring Campfire", "MapRings", ("fit", 128), "plain"),
    "map_ring_merchant": ("/Map", "Map Ring Merchant", "MapRings", ("fit", 128), "plain"),
    "map_ring_treasure": ("/Map", "Map Ring Treasure", "MapRings", ("fit", 128), "plain"),
    "map_ring_unknown": ("/Map", "Map Ring Unknown", "MapRings", ("fit", 128), "plain"),
    "map_ring_visited": ("/Map", "Map Ring Visited", "MapRings", ("fit", 128), "ball"),
    "map_ring_you_are_here": ("/Map", "Map Ring You Are Here", "MapRings", ("fit", 128), "plain"),
    # The wooden arrow pointer (drawn pointing straight up; WoodCursor turns it)
    "cursor_arrow": ("Misc", "Cursor Arrow", "Misc", ("max", 128), "plain"),
    # Hint
    "panel_paper_frame": ("Hint", "Hint Panel", "Hint", (220, 165), "plain"),
    # Panels (the first five reuse frames that were already generated)
    "panel_wood_frame": ("Panels", "Panel Frame Dark", "Panels", (220, 165), "nocut"),
    "board_pause_menu": ("Panels", "Panel Frame Parchment", "Panels", (300, 300), "nocut"),
    "slot_strip": ("Panels", "Panel Frame Small Plaque", "Panels", (150, 54), "nocut"),
    "toast_strip": ("Panels", "Toast Strip", "Panels", (176, 48), "plain"),
    "status_badge_pill": ("Panels", "Status Badge Pill", "Panels", (98, 36), "plain"),
    "amber_counter_pill": ("Panels", "Counter Pill", "Panels", (137, 46), "plain"),
    "scroll_track": ("Panels", "Scroll Track", "Panels", (20, 80), "plain"),
    "scroll_bar_grabber": ("Panels", "Scroll Grabber", "Panels", (20, 38), "plain"),
    "volume_bar_grabber": ("Panels", "Volume Knob", "Panels", (28, 28), "plain"),
}
IMAGESET_OUT = r"D:\GitHub Projects\ImageSet\output"
FROM_SETS = {"Buttons": "Puppet Buttons", "Essence": "Puppet Essence", "Fx": "Puppet Fx", "Icons": "Puppet Icons Extra", "Hint": "Puppet Hint",
             "Panels": "Puppet Panel Parts", "Card": "Puppet Card", "Misc": "Puppet Cursor", "Treasure": "Puppet Treasure", "MapRings": "Puppet Map Rings"}  # UI folder -> ImageSet set whose output/ folder holds its raw pictures
_proc = None


def collect():
    """Copy the raw pictures ImageSet made (output/<set>/<name>_<stamp>.png) into UI/_Source/<folder>/ (what is already there is left alone)."""
    import shutil
    for folder, setname in FROM_SETS.items():
        dst = os.path.join(SRC, folder)
        os.makedirs(dst, exist_ok=True)
        for f in glob.glob(os.path.join(glob.escape(os.path.join(IMAGESET_OUT, setname)), "*_*.png")):
            t = os.path.join(dst, os.path.basename(f))
            if not os.path.exists(t):
                shutil.copy2(f, t)
                print("  copied", os.path.basename(f))


def newest(folder, raw):
    """The newest '<raw>_<stamp>.png' (not another piece whose name merely starts the same). Looked for in UI/_Source/<folder>, then UI/<folder>
    ("@Map" = assets/Puppet/Map)."""
    if raw.endswith(".png"):  # an exact file name, no stamp
        f = os.path.join(UI, folder, raw)
        return f if os.path.exists(f) else None
    bases = [os.path.join(AP.PUPPET, folder[1:])] if folder.startswith("@") else [os.path.join(SRC, folder), os.path.join(UI, folder)]
    files = []
    for base in bases:
        for f in glob.glob(os.path.join(glob.escape(base), glob.escape(raw) + "_*.png")):
            if os.path.basename(f)[len(raw) + 1:-4].replace("_", "").isdigit():
                files.append(f)
    return max(files, key=os.path.getmtime) if files else None


def cut(path):
    """White-background picture -> trimmed RGBA."""
    global _proc
    if _proc is None:
        import tachnen_core as core
        _proc = core.Processor()
    im = _proc.run(Image.open(path).convert("RGBA"), CUT_OPTS)
    return im.crop(im.getchannel("A").point(lambda v: 255 if v > 8 else 0).getbbox())


def cut_ball(path):
    """A white ball on a white background: the AI cut takes it for background, so find the ball by its soft shading and use a perfect circle."""
    from scipy.ndimage import binary_closing, binary_fill_holes, label
    im = Image.open(path).convert("RGBA")
    a = np.array(im)
    m = a[:, :, :3].min(axis=2) < 244
    m = binary_fill_holes(binary_closing(m, iterations=6))
    lab, n = label(m)
    if n == 0:
        return im
    sizes = np.bincount(lab.ravel())
    sizes[0] = 0
    m = lab == sizes.argmax()
    ys, xs = np.nonzero(m)
    cx, cy = (xs.min() + xs.max()) / 2.0, (ys.min() + ys.max()) / 2.0
    r = ((xs.max() - xs.min()) + (ys.max() - ys.min())) / 4.0
    yy, xx = np.mgrid[0:a.shape[0], 0:a.shape[1]]
    d = np.hypot(xx - cx, yy - cy)
    a[:, :, 3] = (np.clip(r - d + 0.5, 0.0, 1.0) * 255).astype(np.uint8)
    out = Image.fromarray(a, "RGBA")
    return out.crop((int(cx - r), int(cy - r), int(cx + r) + 1, int(cy + r) + 1))


def cut_light(path):
    """A light object on a white background (the white numerals): everything darker than the background, closed and filled, is the object."""
    from scipy.ndimage import binary_closing, binary_fill_holes, gaussian_filter, label
    im = Image.open(path).convert("RGBA")
    a = np.array(im)
    m = a[:, :, :3].min(axis=2) < 246
    m = binary_fill_holes(binary_closing(m, iterations=4))
    lab, n = label(m)
    if n:
        sizes = np.bincount(lab.ravel())
        sizes[0] = 0
        m = lab == sizes.argmax()
    a[:, :, 3] = (np.clip(gaussian_filter(m.astype(np.float32), 1.2) * 1.4 - 0.2, 0.0, 1.0) * 255).astype(np.uint8)
    return Image.fromarray(a, "RGBA")


def already_cut(path):
    """True when the picture has see-through corners (it went through the background cut already)."""
    a = Image.open(path).convert("RGBA")
    w, h = a.size
    return all(a.getpixel(p)[3] < 10 for p in ((0, 0), (w - 1, 0), (0, h - 1), (w - 1, h - 1)))


def fit_square(im, n):
    s = n / max(im.size)
    im = im.resize((max(1, round(im.width * s)), max(1, round(im.height * s))), Image.LANCZOS)
    c = Image.new("RGBA", (n, n), (0, 0, 0, 0))
    c.alpha_composite(im, ((n - im.width) // 2, (n - im.height) // 2))
    return c


def tone(im, bright=1.0, color=1.0, contrast=1.0):
    a = im.getchannel("A")
    rgb = im.convert("RGB")
    rgb = ImageEnhance.Brightness(ImageEnhance.Color(ImageEnhance.Contrast(rgb).enhance(contrast)).enhance(color)).enhance(bright)
    out = rgb.convert("RGBA")
    out.putalpha(a)
    return out


def hollow_ring(im):
    """Target marker: the cut leaves a stray scrap of the white background inside the ring's hollow; whatever is still near-white there goes."""
    a = np.array(im)
    h, w = a.shape[:2]
    yy, xx = np.mgrid[0:h, 0:w]
    inside = np.hypot(xx - w / 2.0, yy - h / 2.0) < min(w, h) * 0.40
    white = (a[:, :, :3].min(axis=2) > 215) & inside
    a[white, 3] = 0
    return Image.fromarray(a, "RGBA")


def frost(im):
    """Frozen overlay: the glass inside the rim lets the Essence under it show through (rim stays solid)."""
    a = np.array(im).astype(np.float32)
    h, w = a.shape[:2]
    yy, xx = np.mgrid[0:h, 0:w]
    r = np.hypot(xx - w / 2.0, yy - h / 2.0) / (min(w, h) / 2.0)
    glass = np.clip((0.74 - r) / 0.06, 0.0, 1.0)  # 1 inside the rim, 0 on the rim, soft edge
    a[:, :, 3] *= 1.0 - 0.58 * glass
    return Image.fromarray(a.clip(0, 255).astype(np.uint8), "RGBA")


def make(name, kinds):
    folder, raw, srcdir, size, kind = PIECES[name]
    src = newest(srcdir, raw)
    if src is None:
        print("  !! no raw picture for %s (%s)" % (name, raw))
        return
    if kind == "ball":
        im = cut_ball(src)
    elif kind == "nocut" or already_cut(src):
        im = Image.open(src).convert("RGBA")
        im = im.crop(im.getchannel("A").point(lambda v: 255 if v > 8 else 0).getbbox())
    else:
        im = cut(src)
    if kind == "ring":
        im = hollow_ring(im)
    if size[0] == "fit":
        im = fit_square(im, size[1])
    elif size[0] == "max":
        s = size[1] / max(im.size)
        im = im.resize((max(1, round(im.width * s)), max(1, round(im.height * s))), Image.LANCZOS)
    else:
        im = im.resize(size, Image.LANCZOS)
    if kind == "frost":
        im = frost(im)
    out_dir = os.path.join(AP.PUPPET, folder[1:]) if folder.startswith("/") else os.path.join(UI, folder)
    os.makedirs(out_dir, exist_ok=True)
    im.save(os.path.join(out_dir, name + ".png"))
    print("  %-26s <- %s  %s" % (name, os.path.basename(src), im.size))
    if kind in ("button3", "button4"):
        stem = name[:-len("_normal")]
        tone(im, 1.14, 1.05).save(os.path.join(out_dir, stem + "_hover.png"))
        tone(im, 0.80, 1.18, 1.1).save(os.path.join(out_dir, stem + "_pressed.png"))
        if kind == "button4":
            tone(im, 0.9, 0.3).save(os.path.join(out_dir, stem + "_disabled.png"))


# the sets of many icons: every raw picture "<prefix><Name>_<stamp>.png" in Puppet/Icon/<folder> -> <out prefix><id>.png (longest edge 128 px)
BULK = {"artifact": ("Artifact", "Artifact ", ""), "bottle": ("Bottle", "Bottle ", ""), "effect": ("Effect", "Effect ", "status_"),
        "intent": ("Intent", "Intent ", "intent_")}
BULK_IDS = {"Air Emblem": "wind_emblem", "Hungry Satchel": "spell_satchel", "Scholar's Quill": "scholars_quill"}  # name -> id where they differ


def bulk(which):
    import re
    folder, prefix, out_prefix = BULK[which]
    base = os.path.join(AP.PUPPET, "Icon", folder)
    newest_of = {}
    for f in glob.glob(os.path.join(glob.escape(base), prefix + "*_*.png")):
        m = re.match(r"(.+)_\d{8}_\d{6}\.png$", os.path.basename(f))
        if m and (m.group(1) not in newest_of or os.path.getmtime(f) > os.path.getmtime(newest_of[m.group(1)])):
            newest_of[m.group(1)] = f
    for full, f in sorted(newest_of.items()):
        name = full[len(prefix):]
        ident = BULK_IDS.get(name, re.sub(r"[^a-z0-9]+", "_", name.lower().replace("'", "")).strip("_"))
        im = Image.open(f).convert("RGBA")
        if not already_cut(f):
            im = cut(f)
        im = im.crop(im.getchannel("A").point(lambda v: 255 if v > 8 else 0).getbbox())
        k = 128.0 / max(im.size)
        im = im.resize((max(1, round(im.width * k)), max(1, round(im.height * k))), Image.LANCZOS)
        im.save(os.path.join(base, out_prefix + ident + ".png"))
        print("  %-30s -> %s%s.png %s" % (name, out_prefix, ident, im.size))


def numbers():
    """The big numerals (gold) and white ones: Number <d> / Number White <d> (+ Plus / Minus / Times / Divide) -> Puppet/UI/Numbers/num_<x> /
    numw_<x>.png. The pictures are already cut out; each is trimmed and scaled to 128 px tall (the signs the same as the digits), like the
    New theme's, because UiSkin.fill_number scales them as h / 128."""
    import re
    base = os.path.join(UI, "Numbers")
    names = {"Plus": "plus", "Minus": "minus", "Times": "times", "Divide": "divide"}
    newest_of = {}
    for f in glob.glob(os.path.join(glob.escape(base), "Number *_*.png")) + glob.glob(os.path.join(glob.escape(os.path.join(IMAGESET_OUT, "Puppet Numbers")), "Number *_*.png")):
        m = re.match(r"Number (White )?(\w+)_\d{8}_\d{6}\.png$", os.path.basename(f))
        if m:
            key = (bool(m.group(1)), m.group(2))
            rank = lambda g: (os.path.basename(g)[-19:-4], already_cut(g))  # (the newest stamp; of two copies the one that is already cut out)
            if key not in newest_of or rank(f) > rank(newest_of[key]):
                newest_of[key] = f
    for (white, what), f in sorted(newest_of.items()):
        ident = names.get(what, what)
        im = Image.open(f).convert("RGBA") if already_cut(f) else (cut_light(f) if white else cut(f))
        im = im.crop(im.getchannel("A").point(lambda v: 255 if v > 8 else 0).getbbox())
        k = 128.0 / im.height
        if ident == "minus" and im.width > im.height:  # (a flat bar: as wide as the plus, not as tall)
            k = 123.0 / im.width
        im = im.resize((max(1, round(im.width * k)), max(1, round(im.height * k))), Image.LANCZOS)
        out = ("numw_" if white else "num_") + ident + ".png"
        im.save(os.path.join(base, out))
        print("  %-18s -> %s %s" % (os.path.basename(f)[:22], out, im.size))


def make_slider_track():
    """The volume slider's track is the scroll bar's track turned on its side."""
    src = os.path.join(UI, "Panels", "scroll_track.png")
    if os.path.exists(src):
        Image.open(src).convert("RGBA").transpose(Image.ROTATE_90).save(os.path.join(UI, "Panels", "slider_track.png"))
        print("  slider_track               <- scroll_track turned 90 degrees")


def main():
    collect()
    if sys.argv[1:2] == ["numbers"]:
        numbers()
        return
    if sys.argv[1:2] and sys.argv[1] in BULK:
        bulk(sys.argv[1])
        return
    names = sys.argv[1:] or list(PIECES)
    for n in names:
        make(n, None)
    if "scroll_track" in names:
        make_slider_track()


if __name__ == "__main__":
    main()
