"""Theme MinhHUD: the artifact cabinet v2 (and, with the argument "bottle", the bottle cabinet in the same style: 1:1, layout = the existing bottle cabinet sprite, design refs = the approved cabinet v2 raw picture + the mood picture), made by ImageSet from the user's layout (assets/Puppet/UI/MinhHUD/Artifact Cabinet/cabinet v2.pdf, rendered to _Frames/Artifact Cabinet v2.png)
and the user's mood picture (_Frames/Artifact Cabinet v2 mood.png: circus showcase), with minhhud_style_cabinet.txt. VIP accounts only. 16:9.
Run with ImageSet's python:  "D:/GitHub Projects/ImageSet/.venv/Scripts/python.exe" tools/make_minhhud_cabinet.py [--redo]"""
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
FR = os.path.join(DIR, "_Frames")
NAME = "Artifact Cabinet v2"
PROMPT = ("A real handmade wooden display showcase for collectibles, seen from the front and slightly from above like the layout frame: a trapezoid case, narrower at the top, "
          "outer frame of dark stained walnut with polished aged brass corner brackets and small brass studs, a slim wooden cornice on top, the two side walls slanting inward are clear glass panes set in the wooden frame, "
          "a dark wooden back wall, two stepped tiers (risers) each covered with deep red velvet with a thin brass-edged lip, and on the front face of each tier a row of exactly five small identical empty rectangular brass name-plates, evenly spaced "
          "(the plates are blank), below the glass a deep red lacquered front panel with a thick wooden border, fine painted gold scrollwork trim and one larger blank brass plaque in the middle. "
          "The front of the case is open (no glass pane across it) so the inside is clearly visible, and the shelves are completely empty")


BOTTLE_NAME = "Bottle Cabinet v2"
BOTTLE_PROMPT = ("A small real handmade wooden display showcase for three potion bottles, the little brother of the attached finished artifact showcase and in exactly the same style, seen from the front and slightly from above: "
                 "a near-square case with a slightly narrower top, outer frame of dark stained walnut with polished aged brass corner brackets and small brass studs, a slim wooden cornice, clear glass side panes set in the wooden frame, a dark wooden back wall, "
                 "ONE low tier at the bottom covered with deep red velvet with a thin brass-edged lip, holding exactly three identical round shallow brass-rimmed sockets in one row, evenly spaced, for bottles to stand in (the sockets are empty), "
                 "below the glass a deep red lacquered front panel with a thick wooden border, fine painted gold scrollwork trim and one small blank brass plaque in the middle. "
                 "The front of the case is open (no glass pane across it) and the whole case is completely empty, so there is a lot of empty dark wall above the tier")


def main():
    acc = json.load(open(os.path.join(IMAGESET, "accounts.json"), encoding="utf-8"))["accounts"]
    accounts = [a["id"] for a in acc if a.get("vip") and a.get("enabled")]
    style = open(os.path.join(DIR, "minhhud_style_cabinet.txt"), encoding="utf-8").read().strip()
    bottle = "bottle" in sys.argv
    if bottle:
        raw = [f for f in os.listdir(r"E:\GitHub\ImageSet\output\MinhHUD Cabinet v2") if f.startswith(NAME + "_")]
        raw = os.path.join(r"E:\GitHub\ImageSet\output\MinhHUD Cabinet v2", sorted(raw)[-1])
        o = {"name": BOTTLE_NAME, "prompt": BOTTLE_PROMPT, "refs": [
            {"label": "layout frame", "kind": "extra", "desc": "the old bottle cabinet: keep its near-square proportions and the single stand of three sockets at the bottom, with a lot of empty back wall above; ignore its materials, build the new one like the finished showcase",
             "images": [os.path.join(DIR, "Bottle cabinet", "Bottle Cabinet.png")]},
            {"label": "finished style", "kind": "extra", "desc": "the finished artifact showcase: copy its materials, colours, brass corners, velvet, scrollwork and plaque exactly, but this case is smaller, has one tier of three round sockets and no name-plates",
             "images": [raw]},
            {"label": "design to reach", "kind": "extra", "desc": "the original circus showcase picture the finished one was made from: same design language; do not copy the objects on its shelves",
             "images": [os.path.join(FR, NAME + " mood.png")]}]}
    else:
      o = {"name": NAME, "prompt": PROMPT, "refs": [
        {"label": "layout frame", "kind": "extra", "desc": "flat vector layout frame of this showcase: copy its outline, proportions and the position of every tier, name-plate, glass side and the lower panel exactly; the light blue strips are the clear glass side panes; ignore its flat colours and thin outlines",
         "images": [os.path.join(FR, NAME + ".png")]},
        {"label": "design to reach", "kind": "extra", "desc": "the finished look to reach (circus showcase): same design, colours, brass corners, velvet tiers and trim; do not copy the objects on its shelves",
         "images": [os.path.join(FR, NAME + " mood.png")]}]}
    status = os.path.join(tempfile.gettempdir(), "minhhud_cabinet_status%s.json" % ("_bottle" if bottle else ""))
    spec = {"set_name": "MinhHUD Cabinet v2 Square" if bottle else "MinhHUD Cabinet v2", "style": style, "ratio": "1:1" if bottle else "16:9", "status_path": status, "retries": 1,
            "accounts": accounts, "objects": [o], "redo": [o["name"]] if "--redo" in sys.argv else []}
    sp = os.path.join(tempfile.gettempdir(), "minhhud_cabinet_spec.json")
    json.dump(spec, open(sp, "w", encoding="utf-8"), ensure_ascii=False, indent=1)
    subprocess.call([os.path.join(IMAGESET, ".venv", "Scripts", "python.exe"), "main.py", "--batch", sp, "--background"], cwd=IMAGESET)
    st = json.load(open(status, encoding="utf-8"))
    print(st.get("state"), st.get("done"), "/", st.get("total"), st.get("errors"))
    for n, f in (st.get("files") or {}).items():
        print(n, f)


if __name__ == "__main__":
    main()
