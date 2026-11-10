"""Theme MinhHUD: bottle trays (NOT a cabinet), 3 options each for a tray of 3 and a tray of 5 sockets, in the style of the approved artifact cabinet v2.
ImageSet set "MinhHUD Bottle Trays" (16:9, VIP accounts); refs = the approved cabinet v2 raw picture + the bottle cabinet v2 raw picture (its three brass-rimmed sockets), text style minhhud_style_tray.txt.
Run with ImageSet's python:  "D:/GitHub Projects/ImageSet/.venv/Scripts/python.exe" tools/make_minhhud_tray.py [Name ...]"""
import json
import os
import subprocess
import sys
import tempfile

IMAGESET = r"D:\GitHub Projects\ImageSet"
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import asset_paths as AP

DIR = os.path.join(AP.PUPPET, "UI", "MinhHUD")
OUT = r"E:\GitHub\ImageSet\output"


def newest(folder, start):
    d = os.path.join(OUT, folder)
    return os.path.join(d, sorted(f for f in os.listdir(d) if f.startswith(start + "_"))[-1])


KINDS = {
    "A": "a solid walnut stepped plinth: a low trapezoid block of dark walnut whose front face slopes back, its top covered with deep red velvet in which %s round brass-rimmed sockets are set in one row, evenly spaced, with a thin polished brass strip along the front edge of the top and a small blank brass plaque in the middle of the front face",
    "B": "a red lacquered wooden tray: a long low box with a deep red lacquered front and sides decorated with fine painted gold scrollwork and a thick walnut border, brass corner brackets with studs at its four lower corners, the walnut top has %s deep round recesses in one row, evenly spaced, each lined with red velvet and rimmed with a polished brass ring",
    "C": "a walnut rail with a raised velvet strip: a long low walnut base with rounded ends, on it a raised strip of deep red velvet with brass end caps, %s large round brass-rimmed sockets set in the velvet in one row, evenly spaced, and under every socket on the walnut base one small blank rectangular brass name-plate with two tiny screws",
}
COUNT = {3: "three", 5: "five"}


def main():
    only = [a for a in sys.argv[1:] if not a.startswith("--")]
    acc = json.load(open(os.path.join(IMAGESET, "accounts.json"), encoding="utf-8"))["accounts"]
    accounts = [a["id"] for a in acc if a.get("vip") and a.get("enabled")]
    style = open(os.path.join(DIR, "minhhud_style_tray.txt"), encoding="utf-8").read().strip()
    refs = [{"label": "finished showcase", "kind": "extra", "desc": "the approved finished showcase: copy its walnut, brass, red velvet, red lacquer and gold scrollwork exactly; the new object is only a small tray, not a showcase",
             "images": [newest("MinhHUD Cabinet v2", "Artifact Cabinet v2")]},
            {"label": "sockets", "kind": "extra", "desc": "the finished small showcase: copy its round brass-rimmed sockets set in red velvet exactly; the new object has no showcase around it",
             "images": [newest("MinhHUD Cabinet v2 Square", "Bottle Cabinet v2")]}]
    objects = []
    for n in (3, 5):
        for k, d in KINDS.items():
            name = "Bottle Tray %d%s" % (n, k)
            if only and name not in only:
                continue
            prompt = ("A real handmade tray for %d potion bottles, no case around it, " % n) + d % COUNT[n] + ". It is a wide low object, much wider than tall, completely empty: all sockets are empty"
            objects.append({"name": name, "prompt": prompt, "refs": refs})
    status = os.path.join(tempfile.gettempdir(), "minhhud_trays_status.json")
    spec = {"set_name": "MinhHUD Bottle Trays", "style": style, "ratio": "16:9", "status_path": status, "retries": 1, "accounts": accounts,
            "objects": objects, "redo": [o["name"] for o in objects] if only else []}
    sp = os.path.join(tempfile.gettempdir(), "minhhud_trays_spec.json")
    json.dump(spec, open(sp, "w", encoding="utf-8"), ensure_ascii=False, indent=1)
    subprocess.call([os.path.join(IMAGESET, ".venv", "Scripts", "python.exe"), "main.py", "--batch", sp, "--background"], cwd=IMAGESET)
    st = json.load(open(status, encoding="utf-8"))
    print(st.get("state"), st.get("done"), "/", st.get("total"), st.get("errors"))
    for n, f in (st.get("files") or {}).items():
        print(n, f)


if __name__ == "__main__":
    main()
