"""2026-11-09 (fourth try): MuseSet --multi spec, TWO sets of 3 clips; the right hand plays EVERY key from the first key at the far LEFT to the last key at the far RIGHT.
  set 1 = the whole scene (pianist from behind), the prompt says over and over that he is one-armed and must never grow a left arm.
  set 2 = the piano alone + the arm only (no body): pictures from tools/make_muse_set2_input.py.
python tools/make_muse_arm_spec_v4.py <spec out.json> <status.json>"""
import json
import sys

DIR = r"D:\GitHub Projects\The-last-tree\assets\Puppet\Enemies\Act2\pianist"
IMG1 = DIR + r"\back\muse_input_scene.png"
IMG2 = DIR + r"\back\muse_input_set2.png"

ONE_ARM = ("This wooden puppet pianist is permanently ONE-ARMED. His LEFT arm was cut off long ago, so his left shoulder (the left side of his back in the picture) is BARE and stays "
           "bare and EMPTY in every single frame of the video: no left arm, no left hand, no empty sleeve, no stump, nothing grows or appears there, ever. "
           "He has exactly ONE arm in the whole video: his RIGHT arm (on the right side of the picture), a black coat sleeve with a white cuff, brass shoulder and elbow balls and a pale carved wooden hand. "
           "There is never a second arm and never a second hand. ")
STILL1 = ("Locked static camera: no zoom, no pan, no tilt, no cuts, no shake, the framing never changes; the background stays plain white. The picture shows the carved wooden puppet pianist seen from BEHIND "
          "in a black tailcoat and a top hat, sitting on a stool at a black grand piano whose keyboard faces the camera. EVERYTHING stays perfectly frozen except his one right arm and hand: the piano, the stool, "
          "the lid, the sheet music, the hat, the head, the torso and the tailcoat never move, the torso does not lean or turn, and nothing is added or removed. Keep the wood carving, colours and proportions exactly as in the picture. ")
PATH1 = ("Motion over exactly 10 seconds: the right hand plays EVERY key of the keyboard in order, from the very FIRST key at the far LEFT end of the keyboard (the lowest note) to the very LAST key at the far RIGHT end "
         "(the highest note), without skipping a single key. In the first 1.5 seconds the same right arm reaches across, in front of the pianist's body, to the first key at the far left end. "
         "From second 1.5 to second 10 the hand moves to the right at a perfectly steady speed, key by key, and lands on the very last key at the far right end exactly at the end. "
         "While the hand is in front of the middle of the keyboard the pianist's torso hides it from the camera; it is always the SAME single right arm, still joined to his right shoulder, with its black sleeve "
         "and its size unchanged, and the left shoulder stays bare. ")
STILL2 = ("Locked static camera: no zoom, no pan, no tilt, no cuts, no shake, the framing never changes; the background stays plain white. The picture shows a black grand piano seen from the front with its keyboard "
          "facing the camera, and ONE single carved wooden puppet arm floating just above the keyboard: a brass shoulder ball at the top, a black coat sleeve, a brass elbow ball, a white shirt cuff and a pale carved wooden hand "
          "touching the keys. There is NO pianist: no body, no torso, no head, no hat, no stool, no legs, and you must not add any. There is exactly ONE arm in every frame: never a second arm, never a left arm, never a second hand, "
          "nothing else appears. The piano (keys, case, music desk) and the white background never change. Keep the wood carving, colours and size of the arm exactly as in the picture; the arm does not grow, shrink or change its look. ")
PATH2 = ("Motion over exactly 10 seconds: the floating arm, with its shoulder ball, travels sideways as one piece along the keyboard and its hand plays EVERY key in order, from the very FIRST key at the far LEFT end of the keyboard "
         "(the lowest note) to the very LAST key at the far RIGHT end (the highest note), without skipping a single key. In the first 1.5 seconds the arm moves to the left until the hand is on the first key at the far left end. "
         "From second 1.5 to second 10 it moves to the right at a perfectly steady speed, key by key, and the hand is on the very last key at the far right end exactly at the end. The hand stays at the height of the keys, palm facing down, "
         "the elbow and wrist flex a little and naturally while the arm travels. ")
END = {"A": "The hand stays relaxed and flat, the fingers resting on the keys as they pass.",
       "B": "While it travels the fingers tap down lightly one after another on every key as it passes, in a quick natural piano-playing rhythm.",
       "C": "The fingertips press each key softly in turn as the hand passes over it, like a smooth glissando played with one hand."}

jobs = []
for k in "ABC":
    jobs.append({"name": "set1_" + k, "image": IMG1, "prompt": STILL1 + ONE_ARM + PATH1 + END[k], "seconds": 10, "ratio": "16:9", "out": DIR + r"\pianist_set1_%s.mp4" % k, "timeout_s": 900})
for k in "ABC":
    jobs.append({"name": "set2_" + k, "image": IMG2, "prompt": STILL2 + PATH2 + END[k], "seconds": 10, "ratio": "16:9", "out": DIR + r"\pianist_set2_%s.mp4" % k, "timeout_s": 900})
spec = {"status_path": sys.argv[2], "accounts": ["main", "a2", "a3"], "max_attempts": 2, "jobs": jobs}
json.dump(spec, open(sys.argv[1], "w", encoding="utf-8"), ensure_ascii=False, indent=1)
print("spec:", sys.argv[1], [j["name"] for j in jobs])
