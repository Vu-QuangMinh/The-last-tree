r"""The frames that used to be drawn in code (speech bubbles, callouts, help and tutorial boards, pills, empty card slots, round sockets), painted by ImageSet from
assets/Puppet/UI/Panels/frames_prompts.txt + frames_style.txt (the dialogue board's style, thin rims). Two sets, because a set has one aspect ratio: wide (16:9) and round (1:1).
Only the VIP accounts of ImageSet (accounts.json: "vip": true) are used. The raw pictures stay in ImageSet's output folders (output/Puppet Frames Wide, output/Puppet Frames Round);
tools/cut_frame_art.py turns them into the 9-slice pictures of UI/Panels.
Run with ImageSet's python:  "D:/GitHub Projects/ImageSet/.venv/Scripts/python.exe" tools/make_frame_art.py [Name ...]   (names: only those are made again)"""
import json
import os
import subprocess
import sys
import tempfile

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import paths
import asset_paths as AP

IMAGESET = paths.IMAGESET
DIR = os.path.join(AP.PUPPET, "UI", "Panels")
REF = os.path.join(AP.PUPPET, "UI", "Panels", "dialogue_panel.png")
SETS = [("Puppet Frames Wide", "16:9", ["Frame Bubble Dark", "Frame Plaque Cream", "Frame Pill", "Frame Card Slot"]),
        ("Puppet Frames Round", "1:1", ["Frame Round Socket"])]


def vip_accounts():
    acc = json.load(open(os.path.join(IMAGESET, "accounts.json"), encoding="utf-8"))["accounts"]
    return [a["id"] for a in acc if a.get("vip") and a.get("enabled")]


def objects():
    out = {}
    for line in open(os.path.join(DIR, "frames_prompts.txt"), encoding="utf-8").read().splitlines():
        if ":" in line.strip():
            name, prompt = line.split(":", 1)
            out[name.strip()] = prompt.strip()
    return out


def main():
    only = [a for a in sys.argv[1:] if not a.startswith("--")]
    prompts = objects()
    style = open(os.path.join(DIR, "frames_style.txt"), encoding="utf-8").read().strip()
    accounts = vip_accounts()
    print("VIP accounts:", accounts)
    for set_name, ratio, names in SETS:
        names = [n for n in names if not only or n in only]
        if not names:
            continue
        tag = ratio.replace(":", "x")
        status = os.path.join(tempfile.gettempdir(), "frames_%s_status.json" % tag)
        spec = {"set_name": set_name, "style": style, "style_ref": REF, "ratio": ratio, "status_path": status, "retries": 1, "accounts": accounts,
                "objects": [{"name": n, "prompt": prompts[n]} for n in names], "redo": names if only else []}
        spec_path = os.path.join(tempfile.gettempdir(), "frames_%s_spec.json" % tag)
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
