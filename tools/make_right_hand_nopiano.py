r"""2026-11-10: ImageSet (Gemini) removes ONLY the piano from the 12 right-hand frames (pianist/right_hand_frames/source/frame_NN.png, 720 px squares) and the results are
copied to right_hand_frames/source/No-piano/frame_NN.png.   python tools/make_right_hand_nopiano.py run [accounts...]   |   copy"""
import paths
import glob
import json
import os
import shutil
import subprocess
import sys
import tempfile

DIR = r"D:\GitHub Projects\The-last-tree\assets\Puppet\Enemies\Act2\pianist\right_hand_frames\source"
OUT = os.path.join(DIR, "No-piano")
RAW = (paths.IMAGESET_OUT + r"\output\Pianist Right Hand NoPiano")
PROMPT = ("Edit image 2 (the source frame). REMOVE ONLY the black grand piano: its case, lid, lid prop, keyboard with all the keys, music desk and legs, and the sheet music. "
          "KEEP EVERYTHING ELSE EXACTLY as it is in the source, unchanged: the carved wooden puppet pianist seen from behind (top hat, head, black tailcoat, belt, coat tails), his arm(s) and hand(s) "
          "and leg(s), and the wooden stool he sits on, in exactly the same pose, position, size, angle, colours and wood carving. "
          "Do not redraw, move, rotate or change the pianist, his arms, his legs or the stool in any way. Wherever the piano was, show plain pure white background (the hand stays in the air at its exact place). "
          "No shadows, nothing new added, same framing as the source.")
STYLE = ("Photorealistic hand-carved wooden marionette puppet, matte milk-paint finish with visible chisel marks and wood grain, soft even light from the upper left, plain pure white seamless background, "
         "no cast shadows, no text.")


def run(accounts):
    objs = [{"name": "NoPiano %02d" % k, "prompt": PROMPT,
             "refs": [{"label": "Source frame", "kind": "setting", "desc": "the frame to edit (the pianist at the piano, seen from behind)", "images": [os.path.join(DIR, "frame_%02d.png" % k)]}]} for k in range(1, 13)]
    status = os.path.join(tempfile.gettempdir(), "rh_nopiano_status.json")
    if os.path.exists(status):
        os.remove(status)
    spec = {"set_name": "Pianist Right Hand NoPiano", "style": STYLE, "ratio": "1:1", "objects": objs, "status_path": status, "retries": 1, "accounts": accounts}
    sp = os.path.join(tempfile.gettempdir(), "rh_nopiano_spec.json")
    json.dump(spec, open(sp, "w", encoding="utf-8"), ensure_ascii=False, indent=1)
    imageset = paths.IMAGESET
    code = subprocess.call([os.path.join(imageset, ".venv", "Scripts", "python.exe"), "main.py", "--batch", sp, "--background"], cwd=imageset)
    st = json.load(open(status, encoding="utf-8"))
    print("ImageSet:", st.get("state"), st.get("done"), "/", st.get("total"), st.get("errors"), "exit", code, flush=True)
    copy()


def copy():
    os.makedirs(OUT, exist_ok=True)
    for k in range(1, 13):
        fs = [f for f in glob.glob(os.path.join(RAW, "NoPiano %02d_*.png" % k)) if os.path.basename(f)[len("NoPiano 00_"):-4].replace("_", "").isdigit()]
        if fs:
            shutil.copyfile(max(fs, key=os.path.getmtime), os.path.join(OUT, "frame_%02d.png" % k))
            print("frame_%02d ok" % k)
        else:
            print("frame_%02d MISSING" % k)


if __name__ == "__main__":
    if sys.argv[1] == "run":
        run(sys.argv[2:] or ["a3", "a4", "a5"])
    else:
        copy()
