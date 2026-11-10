"""2026-11-09: spec for MuseSet --multi: 3 clips of the Pianist's arm sweeping along the keyboard from position 1 to 10 (one per Muse account).
python tools/make_muse_arm_spec.py <spec out.json> <status.json>"""
import json
import sys

IMG = r"D:\GitHub Projects\The-last-tree\assets\Puppet\Enemies\Act2\pianist\back\muse_input_arm.png"
OUT = r"D:\GitHub Projects\The-last-tree\assets\Puppet\Enemies\Act2\pianist\pianist_arm_%s.mp4"

COMMON = ("Locked static camera: no zoom, no pan, no tilt, no cuts, no camera shake. The flat teal background stays exactly the same plain colour in every frame "
          "(no gradient, no texture, no floor, no shadows). The image shows ONLY one carved wooden puppet's right arm floating in mid-air: a brass shoulder ball at the top, "
          "a black coat sleeve, a brass elbow ball, a white shirt cuff and a pale carved wooden hand lying palm-down with the fingers pointing to the right. "
          "There are two black number labels fixed on the teal: '1' at the far left and '10' at the far right; they never move and never change. "
          "Imagine a straight horizontal line through the two labels at the height of the hand: the tip of the middle finger always stays on this line. "
          "Do NOT add or show any body, torso, head, hat, legs, piano, keys, second hand or any other object: only the arm. "
          "Keep the wood carving, the colours and the size of the arm exactly as in the image (the arm must not grow, shrink or change its look). ")

A = ("Motion over exactly 10 seconds: during the first 1.5 seconds the arm quickly glides to the left until the tip of the middle finger is exactly under the label '1'. "
     "Then, from second 1.5 to second 10, the arm glides to the right at a perfectly steady slow speed along the line, from the label '1' to the label '10', "
     "and the middle fingertip reaches the label '10' exactly at the very end. While it travels, the hand stays palm-down at the same height, the fingers keep a natural "
     "relaxed piano-playing shape, the wrist and the elbow flex a little in a natural way, and the whole arm including the shoulder ball moves together.")
B = ("Motion over exactly 10 seconds: during the first 1.5 seconds the arm quickly glides to the left until the tip of the middle finger is exactly under the label '1'. "
     "Then, from second 1.5 to second 10, the arm glides to the right at a steady slow speed along the line, from the label '1' to the label '10', "
     "reaching the label '10' exactly at the very end. All the way, the fingers tap lightly up and down one after another in a quick natural piano-playing rhythm "
     "(about four taps per second) while the palm stays facing down at the same height; the wrist and the elbow flex naturally, and the whole arm including the shoulder ball moves together.")
C = ("Motion over exactly 10 seconds: the hand visits ten evenly spaced positions along the line in order, position 1 under the label '1' and position 10 under the label '10'. "
     "First it moves quickly to position 1. At each position the hand lands, presses the fingers down once like pressing a piano key, lifts slightly, stays there for about "
     "half a second, then moves smoothly to the next position, one position per second, until it is under the label '10' at the end. The palm stays facing down at the same height, "
     "the wrist and the elbow flex naturally, and the whole arm including the shoulder ball moves together.")

jobs = [{"name": "arm_" + k, "image": IMG, "prompt": COMMON + v, "seconds": 10, "ratio": "16:9", "out": OUT % k, "timeout_s": 900}
        for k, v in (("A", A), ("B", B), ("C", C))]
spec = {"status_path": sys.argv[2], "accounts": ["main", "a2", "a3"], "max_attempts": 2, "jobs": jobs}
json.dump(spec, open(sys.argv[1], "w", encoding="utf-8"), ensure_ascii=False, indent=1)
print("spec:", sys.argv[1], [j["name"] for j in jobs])
