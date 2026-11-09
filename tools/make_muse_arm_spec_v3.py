"""2026-11-09 (third try): MuseSet --multi spec with the WHOLE scene (the pianist seen from behind at the grand piano, white background): only his RIGHT hand moves,
along the keyboard from the key at the far right end to the key at the far left end.  python tools/make_muse_arm_spec_v3.py <spec out.json> <status.json>"""
import json
import sys

IMG = r"D:\GitHub Projects\The-last-tree\assets\Puppet\Enemies\Act2\pianist\back\muse_input_scene.png"
OUT = r"D:\GitHub Projects\The-last-tree\assets\Puppet\Enemies\Act2\pianist\pianist_arm3_%s.mp4"

COMMON = ("Locked static camera behind the pianist: no zoom, no pan, no tilt, no cuts, no camera shake, the framing never changes. The background stays plain white in every frame. "
          "The picture shows a carved wooden puppet pianist seen from BEHIND, wearing a black tailcoat and a top hat, sitting on a stool with his back to the camera in front of a black grand piano "
          "with its lid propped open and sheet music on the desk; the keyboard faces the camera. The pianist has only his RIGHT arm (the arm on the right side of the picture, with a pale carved wooden hand "
          "resting on the keys); he has no left arm and you must NOT add one. "
          "EVERYTHING stays perfectly still and frozen except that one right arm and hand: the piano, the stool, the lid, the sheet music, the hat, the head, the torso and the tailcoat never move, "
          "the torso does not lean or turn, no new objects appear, nothing is added or removed. Keep the wood carving, colours and proportions of everything exactly as in the picture. ")

PATH = ("Motion over exactly 10 seconds: the right hand plays along the keyboard in ONE straight steady sweep from the very last key at the far RIGHT end of the keyboard "
        "(the highest notes) to the very first key at the far LEFT end of the keyboard (the lowest notes). In the first 1 second the hand moves from where it is to the very last key at the right end. "
        "Then from second 1 to second 10 it travels at a perfectly steady speed along the keys, at the height of the keys, all the way to the leftmost key, and it is on the leftmost key exactly at the end. "
        "When the hand passes the middle of the keyboard it goes behind the pianist's torso (the torso hides it from the camera) and comes out again on the left side of his torso. "
        "The arm stretches naturally across the keyboard, the shoulder stays where it is. ")

A = PATH + "The hand stays flat and relaxed, palm facing down, the fingers resting on the keys."
B = PATH + "While it travels the fingers tap down lightly one after another on the keys in a quick natural piano-playing rhythm (about four taps per second), the palm facing down."
C = ("Motion over exactly 10 seconds: the right hand plays a slow descending run along the keyboard, from the very last key at the far RIGHT end (the highest notes) to the very first key at the far LEFT end "
     "(the lowest notes). It moves in about ten even steps, one step per second: at each step the hand lands on the keys, the fingers press down once like pressing a piano key, then the hand "
     "moves left to the next position. It starts at the far right end and is on the far left end exactly at the end. While it passes behind the pianist's torso (the torso hides it from the camera) "
     "it keeps moving and comes out on the left side of the torso. Only the right arm and hand move; the shoulder stays where it is. ")

jobs = [{"name": "arm3_" + k, "image": IMG, "prompt": COMMON + v, "seconds": 10, "ratio": "16:9", "out": OUT % k, "timeout_s": 900}
        for k, v in (("A", A), ("B", B), ("C", C))]
spec = {"status_path": sys.argv[2], "accounts": ["main", "a2", "a3"], "max_attempts": 2, "jobs": jobs}
json.dump(spec, open(sys.argv[1], "w", encoding="utf-8"), ensure_ascii=False, indent=1)
print("spec:", sys.argv[1], [j["name"] for j in jobs])
