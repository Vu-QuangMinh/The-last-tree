"""New UI theme: the thin iron-rimmed frames of the HUD (page 2 of "Chant UI for puppet.pdf"), made by ImageSet from assets/Puppet/UI/NewUi/new_ui_prompts.txt + new_ui_style.txt.
The card frame (Puppet/Card/spell_card_frame.png) is the style reference. Only the VIP accounts of ImageSet (accounts.json: "vip": true) are used.
Two sets, because a set has one aspect ratio: wide frames (16:9) and single slots / sockets (1:1). The raw pictures stay in ImageSet's output folder
(output/Puppet New UI Wide, output/Puppet New UI Slots); this script only generates and prints where they are.
Run with ImageSet's python:  "D:/GitHub Projects/ImageSet/.venv/Scripts/python.exe" tools/make_new_ui_frames.py [Name ...]   (names: only those are made again)"""
import json
import os
import subprocess
import sys
import tempfile

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import asset_paths as AP

IMAGESET = r"D:\GitHub Projects\ImageSet"
DIR = os.path.join(AP.PUPPET, "UI", "NewUi")
REF = os.path.join(AP.PUPPET, "Card", "spell_card_frame.png")
SETS = [("Puppet New UI Wide", "16:9", ["HUD Block Dark", "HP Bar Frame"]),
        ("Puppet New UI Slots", "1:1", ["Artifact Slot", "Bottle Slot", "Debuff Socket", "Orb Well"])]


def vip_accounts():
    acc = json.load(open(os.path.join(IMAGESET, "accounts.json"), encoding="utf-8"))["accounts"]
    return [a["id"] for a in acc if a.get("vip") and a.get("enabled")]


def objects():
    out = {}
    for line in open(os.path.join(DIR, "new_ui_prompts.txt"), encoding="utf-8").read().splitlines():
        if ":" in line.strip():
            name, prompt = line.split(":", 1)
            out[name.strip()] = prompt.strip()
    return out


def main():
    only = [a for a in sys.argv[1:] if not a.startswith("--")]
    prompts = objects()
    style = open(os.path.join(DIR, "new_ui_style.txt"), encoding="utf-8").read().strip()
    accounts = vip_accounts()
    print("VIP accounts:", accounts)
    for set_name, ratio, names in SETS:
        names = [n for n in names if not only or n in only]
        if not names:
            continue
        status = os.path.join(tempfile.gettempdir(), "new_ui_%s_status.json" % ratio.replace(":", "x"))
        spec = {"set_name": set_name, "style": style, "style_ref": REF, "ratio": ratio, "status_path": status, "retries": 1, "accounts": accounts,
                "objects": [{"name": n, "prompt": prompts[n]} for n in names], "redo": names if only else []}
        spec_path = os.path.join(tempfile.gettempdir(), "new_ui_%s_spec.json" % ratio.replace(":", "x"))
        json.dump(spec, open(spec_path, "w", encoding="utf-8"), ensure_ascii=False, indent=1)
        code = subprocess.call([os.path.join(IMAGESET, ".venv", "Scripts", "python.exe"), "main.py", "--batch", spec_path, "--background"], cwd=IMAGESET)
        try:
            st = json.load(open(status, encoding="utf-8"))
        except (OSError, ValueError):
            st = {}
        print(set_name, "->", st.get("state"), st.get("done"), "/", st.get("total"), st.get("errors"))
        for n, f in (st.get("files") or {}).items():
            print("  ", n, f)
        if code != 0:
            print("ImageSet exit code", code)


if __name__ == "__main__":
    main()
