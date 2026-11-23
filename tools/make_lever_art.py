"""The slot machine's lever in the NEW machine's materials (2026-11-12): same shape as the old lever (ball, stick, hub: assets/Puppet/UI/SlotMachine/slot_lever_*.png, 56x52 / 24x204 / 56x76 px), but made like the
NewUI Ver2 cabinet (UI/NewUiV2/slot_body.png): aged brass with a little green patina, rivets, deep red paint, walnut wood. ImageSet (Gemini, the user's quota) paints each part from two pictures: the OLD part
(only enlarged, as the shape to follow) and the cabinet (the material to copy). The stick is far longer than it is wide (8.5 : 1), so it is sent in a 9:16 frame with the stick filling its height
(the Gemini rule for long narrow things); the cut is trimmed only. The star watermark is reversed (gemini_star), the black is cut with key_cut (a solid part on black: no model), nothing is scaled.
Output: assets/Puppet/UI/NewUiV2/slot_lever_ball.png / slot_lever_stick.png / slot_lever_hub.png (the NewUI Ver2 theme looks there first; the other themes keep the old ones).
Run:  PYTHONIOENCODING=utf-8 "D:/GitHub Projects/Tachnen/.venv/Scripts/python.exe" tools/make_lever_art.py [--no-generate] [ball|stick|hub]"""
import glob
import json
import os
import subprocess
import sys
import tempfile

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import paths
import asset_paths as AP
import gemini_star
import import_newui2_art as ia

from PIL import Image

OLD = os.path.join(AP.PUPPET, "UI", "SlotMachine")
V2 = os.path.join(AP.PUPPET, "UI", "NewUiV2")
SET = "Slot Lever V2"
STYLE = ("Real physical parts of an antique steampunk slot machine, photographed straight on, soft even light from the upper left: aged hand-worked brass with fine scratches and a little green patina, "
         "small brass rivets, deep red lacquered paint worn at the edges, dark walnut wood. The same materials, wear and colours as the cabinet in the style reference. Isolated on a pure black seamless "
         "background (#000000): no table, no shadow, no reflection, no other objects, no text.")
PARTS = {
    "ball": ("Slot Lever Ball", "1:1", "slot_lever_ball.png", "A round lever knob: a perfectly round glossy deep red lacquered ball with a soft highlight, a little wider than it is tall (like the shape reference), with only a tiny flat dark brass base disc under it, as thin as a coin. No collar and no neck: just the ball and its tiny thin base."),
    "stick": ("Slot Lever Stick", "9:16", "slot_lever_stick.png", "A very long thin straight lever rod, perfectly vertical, standing in the middle of the frame and filling its whole height from the top edge to the bottom edge, a thin round rod of aged brass with a slightly darker wooden-brown wrap in the middle. The same shape as the shape reference: a long thin straight stick, about 8 times as long as it is wide."),
    "hub": ("Slot Lever Hub", "3:4", "slot_lever_hub.png", "The pivot housing of a slot machine lever: an UPRIGHT cylinder standing vertically (taller than it is wide, its axis pointing up and down, seen from the side), made of aged brass with a visible rivet ring, with a smaller stepped brass nub sticking out of its RIGHT side near the middle. The same shape as the shape reference: a tall upright cylinder with a small stepped nub on its right side."),
}


def only():
    return [a.lower() for a in sys.argv[1:] if not a.startswith("--")]


def shape_ref(key, tmp):
    """The old part, only ENLARGED (a reference for Gemini, not a game picture), centred in the frame it will be drawn in (stick: 9:16, filling the height)."""
    old = Image.open(os.path.join(OLD, PARTS[key][2])).convert("RGBA")
    ratio = {"1:1": (1, 1), "9:16": (9, 16), "3:4": (3, 4)}[PARTS[key][1]]
    H = 1024
    W = H * ratio[0] // ratio[1]
    k = (H * 0.92 / old.height) if key == "stick" else (H * 0.55 / max(old.size))
    old = old.resize((max(1, round(old.width * k)), max(1, round(old.height * k))), Image.LANCZOS)
    cv = Image.new("RGB", (W, H), (0, 0, 0))
    cv.paste(old, ((W - old.width) // 2, (H - old.height) // 2), old)
    p = os.path.join(tmp, "ref_%s.png" % key)
    cv.save(p)
    return p


def generate():
    tmp = tempfile.mkdtemp()
    cabinet = os.path.join(V2, "slot_body.png")
    for key, (name, ratio, _out, prompt) in PARTS.items():
        if only() and key not in only():
            continue
        refs = [{"label": "Shape", "kind": "character", "desc": "the exact SHAPE and proportions to keep (an old flat version of the part: keep the shape, change only the material)", "images": [shape_ref(key, tmp)]},
                {"label": "Style", "kind": "setting", "desc": "the cabinet whose MATERIALS (aged brass, rivets, red paint, patina) the new part is made of", "images": [cabinet]}]
        status = os.path.join(tempfile.gettempdir(), "lever_status.json")
        spec = {"set_name": SET, "style": STYLE, "ratio": ratio, "objects": [{"name": name, "prompt": prompt, "refs": refs}], "status_path": status, "retries": 1, "redo": [name]}
        spec_path = os.path.join(tempfile.gettempdir(), "lever_spec_%s.json" % key)
        json.dump(spec, open(spec_path, "w", encoding="utf-8"), ensure_ascii=False, indent=1)
        subprocess.call([os.path.join(paths.IMAGESET, ".venv", "Scripts", "python.exe"), "main.py", "--batch", spec_path, "--background"], cwd=paths.IMAGESET)
        st = json.load(open(status, encoding="utf-8"))
        print("ImageSet", name, ":", st.get("state"), st.get("done"), "/", st.get("total"), st.get("errors"), flush=True)


def newest(name):
    base = os.path.join(paths.IMAGESET_OUT + "/output", SET)
    found = sorted(glob.glob(os.path.join(glob.escape(base), glob.escape(name) + "_*.png")), key=os.path.getmtime)
    return found[-1] if found else None


def main():
    if "--no-generate" not in sys.argv:
        generate()
    for key, (name, _ratio, out, _prompt) in PARTS.items():
        if only() and key not in only():
            continue
        path = newest(name)
        if not path:
            print("MISSING:", name)
            continue
        raw = gemini_star.remove(Image.open(path).convert("RGBA"))
        im = ia.key_cut(raw)
        if im is None:
            print("  (not on black: key_cut refused)", name)
            continue
        im.save(os.path.join(V2, out))
        print("  %-18s -> NewUiV2/%s %s" % (name, out, im.size), flush=True)


if __name__ == "__main__":
    main()
