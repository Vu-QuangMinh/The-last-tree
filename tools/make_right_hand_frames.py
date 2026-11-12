r"""2026-11-09: 12 frames of the Pianist playing with his RIGHT hand: cut from the Muse clip pianist_set1_A.mp4, then ImageSet (Gemini) edits each one: the piano, the sheet music
and the extra arm that grew on the left of the picture are removed; only the pianist (with his right arm) and the stool stay, on plain white.
python tools/make_right_hand_frames.py extract   -> pianist/right_hand_frames/source/frame_NN.png
python tools/make_right_hand_frames.py generate  -> ImageSet batch (accounts main, b, a2), raw output on E:\GitHub\ImageSet\output\Pianist Right Hand"""
import paths
import glob
import os
import shutil
import subprocess
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
DIR = r"D:\GitHub Projects\The-last-tree\assets\Puppet\Enemies\Act2\pianist"
CLIP = os.path.join(DIR, "pianist_set1_A.mp4")
SRC = os.path.join(DIR, "right_hand_frames", "source")
# the right arm (black sleeve) travels from the middle to the far right between about 5.8 s and 9.6 s of the clip: 12 evenly spaced moments
TIMES = [5.8 + k * (9.6 - 5.8) / 11.0 for k in range(12)]

PROMPT = ("Edit image 2 (the source frame). REMOVE completely: the black grand piano (its case, lid, lid prop, keyboard, music desk and legs), the sheet music, and ANY pale bare wooden arm on the LEFT side of the picture "
          "(the pianist has only ONE arm: his right arm in the black coat sleeve on the right side of the picture; delete every other arm). "
          "KEEP exactly as in the source, unchanged: the carved wooden puppet pianist seen from behind (top hat, head, black tailcoat, belt, coat tails), his right arm with its black sleeve, brass joints and pale hand in exactly the same pose "
          "and position, and the wooden stool he sits on. Do not change the pose, size, proportions, colours or the wood carving of the pianist, his arm or the stool. "
          "The hand stays in the air at its exact place (the keys are gone). Plain pure white background everywhere else, no shadows, nothing new added. Same framing and same size as the source frame.")
STYLE = ("Photorealistic hand-carved wooden marionette puppet, matte milk-paint finish with visible chisel marks and wood grain, soft even light from the upper left, plain pure white seamless background, "
         "no cast shadows, no text.")


def extract():
    os.makedirs(SRC, exist_ok=True)
    ff = shutil.which("ffmpeg")
    for k, t in enumerate(TIMES, 1):
        out = os.path.join(SRC, "frame_%02d.png" % k)
        subprocess.run([ff, "-v", "error", "-y", "-ss", "%.3f" % t, "-i", CLIP, "-frames:v", "1", "-vf", "crop=720:720:290:0", out], check=True)
        print("frame %02d  t=%.2fs -> %s" % (k, t, out))


def redo(nums):
    """Frames that failed (Gemini gave no picture) or kept the extra left arm: a neighbouring moment of the clip (+0.15 s) and a stronger sentence about the left arm."""
    ff = shutil.which("ffmpeg")
    for n in nums:
        out = os.path.join(SRC, "frame_%02d.png" % n)
        subprocess.run([ff, "-v", "error", "-y", "-ss", "%.3f" % (TIMES[n - 1] + 0.15), "-i", CLIP, "-frames:v", "1", "-vf", "crop=720:720:290:0", out], check=True)
    generate(nums)


def generate(only=None):
    import json
    import tempfile
    objs = []
    for k in (only or range(1, 13)):
        objs.append({"name": "Right Hand %02d" % k, "prompt": PROMPT + ((" IMPORTANT: the final picture must contain NO pale bare wooden arm anywhere, in particular none on the left side of the pianist: "
                                                                          "erase it completely and show only the white background there.") if only else ""),
                     "refs": [{"label": "Source frame", "kind": "setting", "desc": "the frame to edit (the pianist at the piano, seen from behind)",
                               "images": [os.path.join(SRC, "frame_%02d.png" % k)]}]})
    status = os.path.join(tempfile.gettempdir(), "right_hand_status.json")
    if os.path.exists(status):
        os.remove(status)
    spec = {"set_name": "Pianist Right Hand", "style": STYLE, "ratio": "1:1", "objects": objs, "status_path": status, "retries": 1, "accounts": ["main", "b", "a2"]}
    if only:
        spec["redo"] = ["Right Hand %02d" % k for k in only]
    spec_path = os.path.join(tempfile.gettempdir(), "right_hand_spec.json")
    json.dump(spec, open(spec_path, "w", encoding="utf-8"), ensure_ascii=False, indent=1)
    imageset = paths.IMAGESET
    code = subprocess.call([os.path.join(imageset, ".venv", "Scripts", "python.exe"), "main.py", "--batch", spec_path, "--background"], cwd=imageset)
    st = json.load(open(status, encoding="utf-8"))
    print("ImageSet:", st.get("state"), st.get("done"), "/", st.get("total"), st.get("errors"), "exit", code, flush=True)


if __name__ == "__main__":
    if sys.argv[1] == "redo":
        redo([int(x) for x in sys.argv[2:]])
    else:
        {"extract": extract, "generate": generate}[sys.argv[1]]()
