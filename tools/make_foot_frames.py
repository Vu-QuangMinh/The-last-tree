r"""2026-11-09: frames of the Pianist's LEFT FOOT playing, from the Muse clip pianist_foot_A.mp4; ImageSet (Gemini) isolates the LEG alone on white (no body, no piano, no stool, no arm),
so that the legs can be laid over the body frames of right_hand_frames without doubling the body.
python tools/make_foot_frames.py test      -> 2 test frames (0.6 s and 9.0 s)  [set "Pianist Foot Test"]
python tools/make_foot_frames.py all       -> the 12 frames                     [set "Pianist Foot"]
python tools/make_foot_frames.py redo NN.. -> redo frames (neighbouring moment +0.15 s)"""
import paths
import json
import os
import shutil
import subprocess
import sys
import tempfile

DIR = r"D:\GitHub Projects\The-last-tree\assets\Puppet\Enemies\Act2\pianist"
CLIP = os.path.join(DIR, "pianist_foot_A.mp4")
SRC = os.path.join(DIR, "foot_frames", "source")
# the leg is on the left of the keyboard (0..4.6 s) and on the right (7.4 s ..): 7 moments on the left, 5 on the right
TIMES = [0.2, 0.6, 1.0, 1.8, 2.6, 3.4, 4.2, 7.8, 8.2, 8.6, 9.0, 9.4]
TEST = [(1, 0.6), (2, 9.0)]
PROMPT = ("This is a precise ERASE-ONLY edit of image 2 (the source frame), NOT a redraw. Keep the pianist's LEFT LEG exactly as it is in the source: the jointed dark-brown wooden leg (thigh, round knee ball, lower leg) "
          "and the black shoe at its end, stretched out across the piano keys. Do NOT move, rotate, scale, straighten, recolour or redraw the leg: it must stay the same pixels, the same dark brown and black colours, the same size, "
          "the same angle and at the same place in the frame as in the source. Paint plain pure white over EVERYTHING else, so that only the leg remains: the black grand piano (case, lid, lid prop, keyboard, music desk, legs), "
          "the sheet music, the pianist's body, tailcoat, belt, hat and head, his right arm and its hand, the stool, and every shadow. Where the leg's hip end disappeared behind the pianist's body, just end the leg there with a clean cut; "
          "do not add anything. Result: the single leg alone, in the very same position as in the source, on a plain white background, same framing.")
STYLE = ("Photorealistic hand-carved wooden marionette puppet part, matte milk-paint finish with visible chisel marks and wood grain, soft even light from the upper left, plain pure white seamless background, "
         "no cast shadows, no text.")


def extract(pairs, plus=0.0):
    os.makedirs(SRC, exist_ok=True)
    ff = shutil.which("ffmpeg")
    for n, t in pairs:
        out = os.path.join(SRC, "frame_%02d.png" % n)
        subprocess.run([ff, "-v", "error", "-y", "-ss", "%.3f" % (t + plus), "-i", CLIP, "-frames:v", "1", "-vf", "crop=720:720:290:0", out], check=True)
        print("frame %02d t=%.2f -> %s" % (n, t + plus, out), flush=True)


def generate(set_name, nums, redo=False):
    objs = [{"name": "Foot %02d" % k, "prompt": PROMPT + (" IMPORTANT: the picture must contain only the leg; if anything else is left, remove it." if redo else ""),
             "refs": [{"label": "Source frame", "kind": "setting", "desc": "the frame to edit (the pianist at the piano, seen from behind)", "images": [os.path.join(SRC, "frame_%02d.png" % k)]}]} for k in nums]
    status = os.path.join(tempfile.gettempdir(), "foot_status.json")
    if os.path.exists(status):
        os.remove(status)
    spec = {"set_name": set_name, "style": STYLE, "ratio": "1:1", "objects": objs, "status_path": status, "retries": 1, "accounts": ["a3", "a4", "a5"]}  # (the three that were switched off: main, b and a2 had used up today's Gemini quota)
    if redo:
        spec["redo"] = ["Foot %02d" % k for k in nums]
    spec_path = os.path.join(tempfile.gettempdir(), "foot_spec.json")
    json.dump(spec, open(spec_path, "w", encoding="utf-8"), ensure_ascii=False, indent=1)
    imageset = paths.IMAGESET
    code = subprocess.call([os.path.join(imageset, ".venv", "Scripts", "python.exe"), "main.py", "--batch", spec_path, "--background"], cwd=imageset)
    st = json.load(open(status, encoding="utf-8"))
    print("ImageSet:", st.get("state"), st.get("done"), "/", st.get("total"), st.get("errors"), "exit", code, flush=True)


PROMPT_NOPIANO = ("Edit image 2 (the source frame). REMOVE ONLY the black grand piano: its case, lid, lid prop, keyboard with all the keys, music desk and legs, and the sheet music. "
                  "KEEP EVERYTHING ELSE EXACTLY as it is in the source, unchanged: the carved wooden puppet pianist seen from behind (top hat, head, black tailcoat, belt, coat tails), his right arm and hand, "
                  "his left leg with its black shoe stretched out sideways, and the wooden stool he sits on, in exactly the same pose, position, size, angle, colours and wood carving. "
                  "Do not redraw, move, rotate or change the pianist, his leg, his arm or the stool in any way. Wherever the piano was, show plain pure white background (the leg and the hand stay in the air at their exact places). "
                  "No shadows, nothing new added, same framing as the source.")


def user7(accounts, nopiano=False):
    """The 7 frames the user picked and prepared (foot_frames/source/1..7.png, 1280x720): square crops (the user's files are not touched) -> ImageSet, leg only."""
    from PIL import Image
    src_dir = os.path.join(DIR, "foot_frames", "user7_src")
    os.makedirs(src_dir, exist_ok=True)
    for k in range(1, 8):
        Image.open(os.path.join(DIR, "foot_frames", "source", "%d.png" % k)).convert("RGB").crop((290, 0, 1010, 720)).save(os.path.join(src_dir, "%d.png" % k))
    objs = [{"name": ("NoPiano %d" if nopiano else "Leg %d") % k, "prompt": PROMPT_NOPIANO if nopiano else PROMPT,
             "refs": [{"label": "Source frame", "kind": "setting", "desc": "the frame to edit (the pianist at the piano, seen from behind)", "images": [os.path.join(src_dir, "%d.png" % k)]}]} for k in range(1, 8)]
    status = os.path.join(tempfile.gettempdir(), "foot7_status.json")
    if os.path.exists(status):
        os.remove(status)
    spec = {"set_name": "Pianist Foot NoPiano" if nopiano else "Pianist Foot User", "style": STYLE, "ratio": "1:1", "objects": objs, "status_path": status, "retries": 1, "accounts": accounts}
    spec_path = os.path.join(tempfile.gettempdir(), "foot7_spec.json")
    json.dump(spec, open(spec_path, "w", encoding="utf-8"), ensure_ascii=False, indent=1)
    imageset = paths.IMAGESET
    code = subprocess.call([os.path.join(imageset, ".venv", "Scripts", "python.exe"), "main.py", "--batch", spec_path, "--background"], cwd=imageset)
    st = json.load(open(status, encoding="utf-8"))
    print("ImageSet:", st.get("state"), st.get("done"), "/", st.get("total"), st.get("errors"), "exit", code, flush=True)


if __name__ == "__main__":
    cmd = sys.argv[1]
    if cmd in ("user7", "nopiano7"):
        user7(sys.argv[2:] or ["a3", "a4", "a5"], nopiano=(cmd == "nopiano7"))  # (vanpc.tzone = "b" is not used until 20:00 by the user's order)
        sys.exit(0)
    if cmd == "test":
        extract(TEST)
        generate("Pianist Foot Test 2", [n for n, _ in TEST])
    elif cmd == "all":
        extract(list(enumerate(TIMES, 1)))
        generate("Pianist Foot", list(range(1, 13)))
    elif cmd == "redo":
        nums = [int(x) for x in sys.argv[2:]]
        extract([(n, TIMES[n - 1]) for n in nums], 0.15)
        generate("Pianist Foot", nums, redo=True)
