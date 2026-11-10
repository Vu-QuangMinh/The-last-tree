"""Theme MinhHUD: sprites made by ImageSet from assets/Puppet/UI/MinhHUD/minhhud_prompts.txt (+ _pressed) and minhhud_style.txt.
Read the layout from MinhHUD.pdf (one page, 1920x1080). NO style reference picture (the old Hud2 close button leaked into the results): style is text only, each part gets its own flat frame from _Frames as a layout reference. VIP accounts only.
Sets (one aspect ratio each): Wide 16:9 (cabinet, trays, base), Square 1:1 (bottle cabinet, chant/pass button, glass pipe, flask, hub, lever),
Pressed 1:1 (run AFTER Square: uses the raw Button Chant Pass picture as a reference).
The raw pictures stay in ImageSet's output folder (output/MinhHUD *); this script prints where.
Run with ImageSet's python:  "D:/GitHub Projects/ImageSet/.venv/Scripts/python.exe" tools/make_minhhud_art.py [Name ...]   (names: only those are made again)"""
import json
import os
import subprocess
import sys
import tempfile

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import asset_paths as AP

IMAGESET = r"D:\GitHub Projects\ImageSet"
DIR = os.path.join(AP.PUPPET, "UI", "MinhHUD")
FRAMES = os.path.join(DIR, "_Frames")  # tools/export_minhhud_frames.py: one flat layout frame per part (same name as the object)
SETS = [("MinhHUD v3 Wide", "16:9", ["Artifact Cabinet", "Chant Tray", "Glass Tray", "HUD Base"], "minhhud_prompts.txt"),
        ("MinhHUD v3 Square", "1:1", ["Bottle Cabinet", "Button Chant Pass", "Glass Pipe", "Glass Flask Disc", "Brass Hub"], "minhhud_prompts.txt"),
        ("MinhHUD v3 Tall", "9:16", ["Brass Lever"], "minhhud_prompts.txt"),
        ("MinhHUD v3 Pressed", "1:1", ["Button Chant Pressed", "Button Pass Pressed"], "minhhud_prompts_pressed.txt")]
FRAME_DESC = ("flat vector layout frame of this part from the author's drawing: copy its outline, proportions and the position of every sub-part "
              "exactly, but ignore its flat colours and thin outlines and paint real materials instead")


def vip_accounts():
    acc = json.load(open(os.path.join(IMAGESET, "accounts.json"), encoding="utf-8"))["accounts"]
    return [a["id"] for a in acc if a.get("vip") and a.get("enabled")]


def prompts(fname):
    out = {}
    for line in open(os.path.join(DIR, fname), encoding="utf-8").read().splitlines():
        if ":" in line.strip():
            name, prompt = line.split(":", 1)
            out[name.strip()] = prompt.strip()
    return out


def status_of(ratio):
    return os.path.join(tempfile.gettempdir(), "minhhud_%s_status.json" % ratio.replace(":", "x"))


def find_raw(set_name, obj):
    """Newest raw picture of an object in ImageSet's output folder (for the pressed-state reference)."""
    try:  # the status file of the Square set knows the real path (ImageSet output may be on E:)
        path = (json.load(open(status_of("1:1"), encoding="utf-8")).get("files") or {}).get(obj)
        if path and os.path.isfile(path):
            return path
    except (OSError, ValueError):
        pass
    for root in (os.path.join(IMAGESET, "output"), r"E:\GitHub\ImageSet\output"):
        folder = os.path.join(root, set_name)
        files = [os.path.join(folder, f) for f in os.listdir(folder) if f.startswith(obj + "_") and f.lower().endswith(".png")] if os.path.isdir(folder) else []
        if files:
            return max(files, key=os.path.getmtime)
    return None


def main():
    only = [a for a in sys.argv[1:] if not a.startswith("--")]
    style = open(os.path.join(DIR, "minhhud_style.txt"), encoding="utf-8").read().strip()
    accounts = vip_accounts()
    print("VIP accounts:", accounts)
    for set_name, ratio, names, fname in SETS:
        names = [n for n in names if not only or n in only]
        if not names:
            continue
        pr = prompts(fname)
        objects = []
        for n in names:
            o = {"name": n, "prompt": pr[n]}
            frame = os.path.join(FRAMES, n + " ref.png")  # the author's own picture wins over the exported frame
            if not os.path.isfile(frame):
                frame = os.path.join(FRAMES, n + ".png")
            if os.path.isfile(frame):
                o["refs"] = [{"label": "layout frame", "kind": "extra", "desc": FRAME_DESC, "images": [frame]}]
            if set_name == "MinhHUD v3 Pressed":
                raw = find_raw("MinhHUD v3 Square", "Button Chant Pass")
                if not raw:
                    print("  no raw 'Button Chant Pass' yet: run the Square set first; skipping", n)
                    continue
                o["refs"] = [{"label": "unpressed button", "kind": "extra", "desc": "the unpressed Chant/Pass button to keep identical", "images": [raw]}]
            objects.append(o)
        if not objects:
            continue
        status = status_of(ratio)
        spec = {"set_name": set_name, "style": style, "ratio": ratio, "status_path": status, "retries": 1, "accounts": accounts,
                "objects": objects, "redo": names if only else []}
        spec_path = os.path.join(tempfile.gettempdir(), "minhhud_%s_spec.json" % ratio.replace(":", "x"))
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
