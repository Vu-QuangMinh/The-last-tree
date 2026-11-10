"""Exports a theme's fight HUD as a layered PDF (page 1 = the HUD parts placed where the game draws them, 1920 x 1080 pt, every picture its own named layer; page 2 = a screenshot of the
real fight screen for reference). For editing by hand in an editor that reads PDF layers. Only pictures: the HP tube (drawn by code), the cards, the Essence, artifacts, bottles and texts are not in it.
Steps:
  1. godot --path . --resolution 1920x1080 --position 6000,0 --no-focus --audio-driver Dummy --script res://tools/hud2_shot.gd -- <out dir>   with env HUD_THEME=newui2 HUD_DUMP=<out dir>/hud_dump.json HUD_N=10,5,0
     (writes the dump of the pictures the real screen shows, and <out dir>/h2_end.png)
  2. python tools/export_ui_pdf.py <out dir> <result.pdf> [theme folder under assets/Puppet/UI, default NewUiV2]
The parts of NewUiLayout (blocks, Bag tray, slot strips) are the layout's constants (New UI values); the rest comes from the dump."""
import json
import os
import sys

import pymupdf

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import asset_paths as AP

UI = os.path.join(AP.PUPPET, "UI")
BLOCKS = [("nu_block_wide", (7.91, 923.16, 704.62, 170.66), "Block Menu tab"), ("nu_block_wide", (115.73, 916.97, 704.62, 170.66), "Block Act tab"),
          ("nu_block_left", (-0.52, 949.81, 540.57, 132.8), "Block Left"), ("nu_block_wide", (305.53, 910.78, 704.62, 170.66), "Block Middle"),
          ("nu_block_wide", (668.89, 863.51, 899.77, 217.93), "Block Bag")]
BACK = [("nu_bag_tray", (694.44, 969.2, 821.0, 88.94), "Bag Tray"),
        ("nu_slot_strip", (24.12, 960.47, 262.44, 55.74), "Artifact Strip 1"), ("nu_slot_strip", (24.12, 1012.28, 262.44, 55.74), "Artifact Strip 2"),
        ("nu_slot_strip", (370.95, 989.23, 262.44, 55.74), "Bottle Strip"), ("nu_tube_mouth", (1495.22, 963.75, 15.43, 98.59), "Tube Mouth")]


def find(theme, name):
    for d in (theme, "NewUi", "Panels", "Buttons", "SlotMachine"):
        p = os.path.join(UI, d, name + ".png")
        if os.path.isfile(p):
            return p
    return None


def main():
    out_dir, result = sys.argv[1], sys.argv[2]
    theme = sys.argv[3] if len(sys.argv) > 3 else "NewUiV2"
    dump = json.load(open(os.path.join(out_dir, "hud_dump.json"), encoding="utf-8"))
    doc = pymupdf.open()
    page = doc.new_page(width=1920, height=1080)
    page.draw_rect(pymupdf.Rect(0, 0, 1920, 1080), color=None, fill=(0.12, 0.09, 0.07))  # (a dark floor so the pictures can be judged; delete it if not wanted)
    n = 0

    def put(path, rect, label):
        nonlocal n
        n += 1
        oc = doc.add_ocg("%02d %s" % (n, label), on=True)
        page.insert_image(pymupdf.Rect(rect[0], rect[1], rect[0] + rect[2], rect[1] + rect[3]), filename=path, keep_proportion=False, oc=oc)

    tube = [d for d in dump if "slot_tube_straight" in d["tex"]]
    rest = sorted((d for d in dump if "slot_tube_straight" not in d["tex"]), key=lambda d: (d["z"], d["order"]))
    for d in tube:  # (the tube lies behind the Bag block)
        put(os.path.join(UI, d["tex"].split("/UI/")[1]), d["rect"], "Machine Tube")
    for name, rect, label in BLOCKS:
        put(find(theme, name), rect, label)
    for name, rect, label in BACK:
        put(find(theme, name), rect, label)
    for d in rest:
        base = os.path.splitext(os.path.basename(d["tex"]))[0]
        put(os.path.join(UI, d["tex"].split("/UI/")[1]), d["rect"], base)
    ref = os.path.join(out_dir, "h2_end.png")
    if os.path.isfile(ref):
        p2 = doc.new_page(width=1920, height=1080)
        p2.insert_image(pymupdf.Rect(0, 0, 1920, 1080), filename=ref)
    doc.save(result, deflate=True)
    print("saved", result, n, "layers")


if __name__ == "__main__":
    main()
