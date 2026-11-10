"""Theme New UI redone in the style of the approved artifact cabinet v2 (circus showcase: walnut, brass, red velvet, red lacquer + gold scrollwork).
Step 1 (extract): copies the HUD parts the New UI theme draws into assets/Puppet/UI/NewUiCabinet/_Original/<Name>.png and makes flat-on-black, enlarged layout references in _Refs/.
Step 2: ImageSet sets "NewUI Cabinet <ratio>" (VIP accounts, text style newui_style_cabinet.txt, refs = the old part + the approved cabinet v2 + bottle tray 3B).
Run with ImageSet's python:  "D:/GitHub Projects/ImageSet/.venv/Scripts/python.exe" tools/make_newui_cabinet_art.py [--extract-only] [Name ...]"""
import json
import os
import shutil
import subprocess
import sys
import tempfile

from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import asset_paths as AP

IMAGESET = r"D:\GitHub Projects\ImageSet"
OUT = r"E:\GitHub\ImageSet\output"
UI = os.path.join(AP.PUPPET, "UI")
DIR = os.path.join(UI, "NewUiCabinet")
PANEL = ("A wide flat HUD panel, a long trapezoid slightly narrower at the top, a single thick slab of dark stained walnut with rich visible grain, a thin polished aged-brass inlay line "
         "running all along its edge, tiny brass studs at its four corners, a plain empty surface")
# name -> (source picture under assets/Puppet/UI, ratio, prompt)
PARTS = {
    "Block Wide": ("NewUi/nu_block_wide", "21:9", PANEL),
    "Block Left": ("NewUi/nu_block_left", "21:9", PANEL),
    "Slot Strip": ("NewUi/nu_slot_strip", "21:9",
                   "A single row of exactly five identical square compartments in one walnut frame with thin polished brass divider strips and a brass-edged outer rim, the floor of every compartment lined "
                   "with deep red velvet, the back of each compartment dark walnut, all five compartments empty and open to the front"),
    "Bag Tray": ("NewUi/nu_bag_tray", "21:9",
                 "A very long low shallow trough seen from the front: a walnut tray with rounded ends and a recessed channel running along its whole length lined with deep red velvet, "
                 "a polished brass rim around the channel and small brass end caps, completely empty"),
    "Menu Button": ("Buttons/button_menu_normal", "21:9",
                    "A small wide rounded-rectangle push-button plaque: red lacquered face with a fine gold painted border, a polished brass rim all round and tiny brass screws at both ends, blank face"),
    "Machine Funnel": ("SlotMachine/slot_funnel_top", "21:9", "A small hopper funnel, a wide trapezoid wider at the top, made of aged brass with a walnut collar, empty"),
    "Machine Tube": ("SlotMachine/slot_tube_straight", "21:9",
                     "A straight thick clear glass tube lying horizontally, a flared polished brass flange at its right end and one aged-brass clamp band with two screws near the left third, empty and see-through"),
    "Chant Button": ("Buttons/button_chant_normal", "16:9",
                     "A small wide rounded-rectangle push-button: red lacquered face with a fine gold painted border, a thick polished brass rim, blank face"),
    "Clear Button": ("Buttons/button_clear_normal", "16:9", "A small wide rounded-rectangle push-button: dark stained walnut face, a polished brass rim, blank face"),
    "Pass Button": ("Buttons/button_pass_normal", "16:9", "ONLY a small wide rounded-rectangle push-button, nothing around it (no box, no frame, no plates, no velvet, no background parts): a smooth cream enamel face with a fine gold painted border, a thick polished brass rim, blank face"),
    "Machine Body": ("SlotMachine/slot_body", "4:3",
                     "A front view of a small machine casing: a walnut body with a brass frame and brass corner screws, a thin dark band across the top holding a row of exactly eight small round red lamps, "
                     "under it one large black rectangular window set in a thick polished brass frame, and a small brass ledge under the window, the window is plain black"),
    "Debuff Ring": ("NewUi/nu_debuff_ring", "1:1", "A single thin round ring of polished aged brass with a few tiny studs, hollow in the middle (the middle is empty black), plain, centred"),
    "Chant Socket": ("Panels/chant_slot_empty", "1:1",
                     "A single round shallow socket seen from the front: a walnut disc with a round recess lined with deep red velvet and a polished brass ring around the recess, empty"),
}


def extract():
    os.makedirs(os.path.join(DIR, "_Original"), exist_ok=True)
    os.makedirs(os.path.join(DIR, "_Refs"), exist_ok=True)
    for name, (src, _ratio, _p) in PARTS.items():
        s = os.path.join(UI, src + ".png")
        shutil.copy(s, os.path.join(DIR, "_Original", name + ".png"))
        im = Image.open(s).convert("RGBA")
        k = max(1.0, 1400.0 / max(im.size))
        big = im.resize((round(im.width * k), round(im.height * k)), Image.LANCZOS)
        flat = Image.new("RGB", big.size, (0, 0, 0))
        flat.paste(big, mask=big.split()[3])
        flat.save(os.path.join(DIR, "_Refs", name + ".png"))


def newest(folder, start):
    d = os.path.join(OUT, folder)
    return os.path.join(d, sorted(f for f in os.listdir(d) if f.startswith(start + "_"))[-1])


def main():
    only = [a for a in sys.argv[1:] if not a.startswith("--")]
    extract()
    if "--extract-only" in sys.argv:
        return
    acc = json.load(open(os.path.join(IMAGESET, "accounts.json"), encoding="utf-8"))["accounts"]
    accounts = [a["id"] for a in acc if a.get("vip") and a.get("enabled")]
    style = open(os.path.join(DIR, "newui_style_cabinet.txt"), encoding="utf-8").read().strip()
    shared = [{"label": "finished showcase", "kind": "extra", "desc": "the finished showcase of the new design: copy its walnut, brass, red velvet, red lacquer and gold scrollwork",
               "images": [newest("MinhHUD Cabinet v2", "Artifact Cabinet v2")]},
              {"label": "finished tray", "kind": "extra", "desc": "a finished tray of the new design: copy its red lacquer with gold scrollwork, brass corners and brass-rimmed velvet sockets",
               "images": [newest("MinhHUD Bottle Trays", "Bottle Tray 3B")]}]
    for ratio in sorted({v[1] for v in PARTS.values()}):
        objs = []
        for name, (src, r, prompt) in PARTS.items():
            if r != ratio or (only and name not in only):
                continue
            old = {"label": "old game picture", "kind": "extra",
                   "desc": "the old flat picture of this part: keep its outline, aspect, proportions and the number and position of its sub-parts exactly; the black around it is only the background",
                   "images": [os.path.join(DIR, "_Refs", name + ".png")]}
            objs.append({"name": name, "prompt": prompt, "refs": [old] + shared})
        if not objs:
            continue
        tag = ratio.replace(":", "x")
        status = os.path.join(tempfile.gettempdir(), "newui_cab_%s.json" % tag)
        spec = {"set_name": "NewUI Cabinet " + tag, "style": style, "ratio": ratio, "status_path": status, "retries": 1, "accounts": accounts,
                "objects": objs, "redo": [o["name"] for o in objs] if only else []}
        sp = os.path.join(tempfile.gettempdir(), "newui_cab_spec_%s.json" % tag)
        json.dump(spec, open(sp, "w", encoding="utf-8"), ensure_ascii=False, indent=1)
        subprocess.call([os.path.join(IMAGESET, ".venv", "Scripts", "python.exe"), "main.py", "--batch", sp, "--background"], cwd=IMAGESET)
        st = json.load(open(status, encoding="utf-8"))
        print(ratio, "->", st.get("state"), st.get("done"), "/", st.get("total"), st.get("errors"))
        for n, f in (st.get("files") or {}).items():
            print("  ", n, f)


if __name__ == "__main__":
    main()
