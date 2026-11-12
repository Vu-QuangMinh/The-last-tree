"""Theme NewUI Ver2 ("newui2"): ImageSet's pictures (tools/make_newui_cabinet_art.py, sets "NewUI Cabinet <ratio>") -> assets/Puppet/UI/NewUiV2/<the New UI sprite's own name>.png.
The theme is the New UI HUD with these pictures found first (UiSkin.path_of looks in UI/NewUiV2 before the other folders), so a picture that is not here is the New UI's.
Each picture is cut from its black background with Tachnen's BiRefNet (the Gemini star in the corner is painted black first) and saved at FULL SIZE: NEVER resize (the user's rule, so the
pictures can still be edited by hand; the game scales them: slot_machine._strip_pic and UiTheme.puppet_button_styles know). The buttons' four states are tints of the normal one.
    "D:/GitHub Projects/Tachnen/.venv/Scripts/python.exe" tools/import_newui2_art.py [Name ...]
then Godot --headless --editor --quit once so it imports the new files."""
import glob
import os
import gemini_star
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import paths
import asset_paths as AP

sys.path.insert(0, paths.TACHNEN)
from PIL import Image, ImageDraw, ImageEnhance

UI = os.path.join(AP.PUPPET, "UI")
OUT = os.path.join(UI, "NewUiV2")
RAW = [(paths.IMAGESET_OUT + r"\output"), (paths.IMAGESET + r"\output")]
# part -> (ImageSet set folder, [output sprite names], old sprite it replaces (for the size), kind)
PIECES = {
    "Block Wide": ("NewUI Cabinet 21x9", ["nu_block_wide"], "NewUi/nu_block_wide", "plain"),
    "Block Left": ("NewUI Cabinet 21x9", ["nu_block_left"], "NewUi/nu_block_left", "plain"),
    "Slot Strip": ("NewUI Cabinet 21x9", ["nu_slot_strip"], "NewUi/nu_slot_strip", "plain"),
    "Bag Tray": ("NewUI Cabinet 21x9", ["nu_bag_tray"], "NewUi/nu_bag_tray", "plain"),
    "Machine Funnel": ("NewUI Cabinet 21x9", ["slot_funnel_top"], "SlotMachine/slot_funnel_top", "plain"),
    "Machine Tube": ("NewUI Cabinet 21x9", ["slot_tube_straight"], "SlotMachine/slot_tube_straight", "plain"),
    "Machine Body": ("NewUI Cabinet 4x3", ["slot_body"], "SlotMachine/slot_body", "plain"),
    "Debuff Ring": ("NewUI Cabinet 1x1", ["nu_debuff_ring"], "NewUi/nu_debuff_ring", "plain"),
    "Chant Socket": ("NewUI Cabinet 1x1", ["chant_slot_empty"], "Panels/chant_slot_empty", "plain"),
    "Chant Button": ("NewUI Cabinet 16x9", ["button_chant"], "Buttons/button_chant_normal", "button"),
    "Clear Button": ("NewUI Cabinet 16x9", ["button_clear"], "Buttons/button_clear_normal", "button"),
    "Pass Button": ("NewUI Cabinet 16x9", ["button_pass"], "Buttons/button_pass_normal", "button"),
}
CUT_OPTS = {"model": "birefnet-general", "use_gpu": True, "gpu_mem_gb": 0, "alpha_matting": False, "am_fg": 240, "am_bg": 10,
            "am_erode": 10, "post_process_mask": True, "defringe": True, "alpha_cutoff": 0, "feather": 0.0, "bg_mode": "transparent",
            "bg_custom": "#00ff00", "trim": True, "pad": 0}
_proc = None


def save_safe(im, path):
    """Saves a sprite WITHOUT destroying one that is already there: the old file is first copied to NewUiV2/_Backup/<name>_<time>.png (the user hand-edits these sprites: nothing of theirs is overwritten silently)."""
    import shutil
    import time
    if os.path.exists(path):
        bd = os.path.join(os.path.dirname(path), "_Backup")
        os.makedirs(bd, exist_ok=True)
        base, ext = os.path.splitext(os.path.basename(path))
        shutil.copy2(path, os.path.join(bd, "%s_%s%s" % (base, time.strftime("%m%d_%H%M%S"), ext)))
    im.save(path)


def newest(set_name, name):
    files = []
    for root in RAW:
        files += glob.glob(os.path.join(root, set_name, name + "_2*.png"))
    return max(files, key=os.path.getmtime) if files else None


SOLID = [n for n in PIECES if n not in ("Machine Tube", "Debuff Ring")]  # (the glass tube and the ring are see-through on purpose: no hole filling)


def run_model(im, model):
    return _proc.run(im.copy(), dict(CUT_OPTS, model=model, trim=False))


def key_cut(raw):
    """A solid part on a pure black background needs no model: the background is black, so the part is every pixel that is not black (the models bite chunks out of dark or red edges: a Chant button lost its
    bottom edge that way). The mask = pixels brighter than a small threshold, specks and the Gemini star's tips opened away, holes filled, the biggest piece kept; the edge gets a soft ramp. Nothing is resized.
    Returns None when the picture's border is not black (then the model cuts it)."""
    import numpy as np
    from scipy import ndimage as ndi
    a = np.asarray(raw.convert("RGB"))
    mx = a.max(axis=2)
    k = 24
    ring = np.concatenate([mx[:k, :k].ravel(), mx[:k, -k:].ravel(), mx[-k:, :k].ravel()])  # (three corners: a rounded part leaves them empty; the fourth holds the Gemini star)
    if np.percentile(ring, 98) > 14:
        return None
    m = mx > 14
    r = 8
    yy, xx = np.ogrid[-r:r + 1, -r:r + 1]
    m = ndi.binary_opening(np.pad(m, r), structure=(xx * xx + yy * yy) <= r * r)[r:-r, r:-r]
    m = ndi.binary_fill_holes(m)
    lab, n = ndi.label(m)
    if n == 0:
        return None
    m = lab == (1 + int(np.argmax(ndi.sum(m, lab, range(1, n + 1)))))
    soft = np.clip((mx.astype(np.float32) - 6.0) / 30.0, 0.0, 1.0)
    inner = ndi.binary_erosion(m, iterations=3)
    alpha = np.where(inner, 1.0, np.where(m, np.maximum(soft, 0.35), 0.0))
    im = Image.fromarray(np.dstack([a, (alpha * 255).astype(np.uint8)]), "RGBA")
    return im.crop(im.getchannel("A").point(lambda v: 255 if v > 8 else 0).getbbox())


def cut(path, name=None):
    """Cut with Tachnen's BiRefNet. Both models bite chunks out of the DARK parts (their dark wood looks like the black background), so the two cuts are joined and, for the solid parts, the
    notches in the edge are closed and the holes inside are filled; the colours of the filled places are the picture's own. Nothing is resized."""
    global _proc
    if _proc is None:
        import tachnen_core as core
        _proc = core.Processor()
    import numpy as np
    from scipy import ndimage as ndi
    raw = Image.open(path).convert("RGBA")
    w, h = raw.size
    raw = gemini_star.remove(raw)  # (the star is reversed out of the picture, not cut or painted over: see tools/gemini_star.py)
    if name in SOLID:
        keyed = key_cut(raw)
        if keyed is not None:
            return keyed
    a = run_model(raw, "birefnet-general")
    if name in SOLID:
        b = run_model(raw, "birefnet-general-lite")
        alpha = np.maximum(np.asarray(a.getchannel("A")), np.asarray(b.getchannel("A")))
        m = alpha > 8
        r = max(3, int(max(w, h) * 0.012))
        yy, xx = np.ogrid[-r:r + 1, -r:r + 1]
        m = ndi.binary_closing(np.pad(m, r), structure=(xx * xx + yy * yy) <= r * r)[r:-r, r:-r]
        m = ndi.binary_fill_holes(m)
        inner = ndi.binary_erosion(m, iterations=3)
        alpha = np.where(inner, 255, alpha).astype(np.uint8)
        rgb = np.where((np.asarray(a.getchannel("A")) > 8)[..., None], np.asarray(a.convert("RGB")), np.asarray(raw.convert("RGB")))
        im = Image.fromarray(np.dstack([rgb, alpha]).astype(np.uint8), "RGBA")
    else:
        im = a
    return im.crop(im.getchannel("A").point(lambda v: 255 if v > 8 else 0).getbbox())


def tinted(im, state):
    if state == "normal":
        return im
    rgb, a = im.convert("RGB"), im.getchannel("A")
    if state == "hover":
        rgb = ImageEnhance.Brightness(rgb).enhance(1.15)
    elif state == "pressed":
        rgb = ImageEnhance.Brightness(rgb).enhance(0.72)
    else:  # disabled
        rgb = ImageEnhance.Brightness(ImageEnhance.Color(rgb).enhance(0.45)).enhance(0.8)
    out = rgb.convert("RGBA")
    out.putalpha(a)
    return out


def main():
    only = [a for a in sys.argv[1:] if not a.startswith("--")]
    os.makedirs(OUT, exist_ok=True)
    for name, (set_name, outs, old, kind) in PIECES.items():
        if only and name not in only:
            continue
        src = newest(set_name, name)
        if src is None:
            print("no picture yet:", name)
            continue
        im = cut(src, name)
        size = im.size
        for o in outs:
            if kind == "button":
                for state in ("normal", "hover", "pressed", "disabled"):
                    tinted(im, state).save(os.path.join(OUT, "%s_%s.png" % (o, state)))
            else:
                im.save(os.path.join(OUT, o + ".png"))
        print("%-16s %s -> %s %s" % (name, os.path.basename(src), outs, size))


if __name__ == "__main__":
    main()
