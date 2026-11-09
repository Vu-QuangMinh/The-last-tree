"""2026-11-09: MuseSet --multi spec: the Pianist's LEFT FOOT plays the keyboard, from the lowest key (far left) to the highest keys (far right), 3 clips (3 Muse accounts).
Input picture: the user's own (pianist from behind, left leg raised onto the keys). python tools/make_muse_foot_spec.py <spec out.json> <status.json>"""
import json
import sys

DIR = r"D:\GitHub Projects\The-last-tree\assets\Puppet\Enemies\Act2\pianist"
IMG = DIR + r"\back\muse_input_foot.png"

BASE = ("Locked static camera: no zoom, no pan, no tilt, no cuts, no shake, the framing never changes; the background stays plain white. The picture shows a carved wooden puppet pianist seen from BEHIND, "
        "in a black tailcoat and a top hat, sitting on a stool at a black grand piano whose keyboard faces the camera. This puppet is ONE-ARMED: he has only his RIGHT arm (on the right side of the picture, resting on the keys "
        "at the right) and his left shoulder is bare; you must NEVER add a left arm or any other arm. His LEFT LEG is stretched out sideways from his hip: a jointed wooden leg with a thigh, a round knee ball and a lower leg "
        "that rises up to the keyboard on the left and ends in a black shoe standing on the keys at the very far left end of the keyboard. That left leg is the only thing that plays. "
        "EVERYTHING else stays perfectly frozen: the piano, the lid, the stool, the sheet music, the hat, the head, the torso, the tailcoat and the right arm and its hand never move, the torso does not lean or turn, "
        "no new arm, leg, hand or object ever appears, and nothing disappears. Keep the wood carving, colours and proportions exactly as in the picture; the leg keeps its length and its look. ")
PATH = ("Motion over exactly 10 seconds: the foot plays the keyboard from the LOWEST note to the HIGH notes. It starts on the very first key at the far LEFT end of the keyboard (the lowest note, where the shoe is now). "
        "From second 1 to second 10 the SAME single left leg, still joined to his hip, slides the shoe along the keys to the RIGHT at a perfectly steady speed, one key after another without skipping any key, "
        "until the shoe reaches the far RIGHT end of the keyboard (the highest notes) exactly at the end. While the shoe is in front of the middle of the keyboard the pianist's torso hides the leg from the camera; "
        "the leg is always the same single leg, never a second leg. ")
END = {"A": "The shoe stays flat on the keys and just glides.",
       "B": "While it travels the toe of the shoe taps down on every key it passes, in a quick natural rhythm, like a foot tapping the keys.",
       "C": "The shoe presses each key softly in turn as it passes over it, like a smooth glissando played with one foot."}
jobs = [{"name": "foot_" + k, "image": IMG, "prompt": BASE + PATH + END[k], "seconds": 10, "ratio": "16:9", "out": DIR + r"\pianist_foot_%s.mp4" % k, "timeout_s": 900} for k in "ABC"]
spec = {"status_path": sys.argv[2], "accounts": ["main", "a2", "a3"], "max_attempts": 2, "jobs": jobs}
json.dump(spec, open(sys.argv[1], "w", encoding="utf-8"), ensure_ascii=False, indent=1)
print("spec:", sys.argv[1], [j["name"] for j in jobs])
