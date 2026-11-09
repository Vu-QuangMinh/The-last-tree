"""2026-11-09 (second try): MuseSet --multi spec, the arm with the PURPLE LINE picture: the arm goes to the label 10 first, then slides left along the line to the label 1.
(The first try had no line and Muse swung the arm like a pendulum.)  python tools/make_muse_arm_spec_v2.py <spec out.json> <status.json>"""
import json
import sys

IMG = r"D:\GitHub Projects\The-last-tree\assets\Puppet\Enemies\Act2\pianist\back\muse_input_arm_line.png"
OUT = r"D:\GitHub Projects\The-last-tree\assets\Puppet\Enemies\Act2\pianist\pianist_arm2_%s.mp4"

COMMON = ("Locked static camera: no zoom, no pan, no tilt, no cuts, no camera shake. The flat teal background stays exactly the same plain colour in every frame "
          "(no gradient, no texture, no floor, no shadows). The image shows ONLY one carved wooden puppet's right arm floating in mid-air: a brass shoulder ball at the top, "
          "a black coat sleeve for the upper arm, a brass elbow ball, a black forearm sleeve with a white shirt cuff, and a pale carved wooden hand lying palm-down with the fingers pointing to the right. "
          "A thick purple horizontal line is drawn across the picture with the black number label '1' at its far left end and the black number label '10' at its far right end. "
          "The purple line, the labels and the teal background are completely static and never change; the purple line stays visible and unchanged the whole time. "
          "The tip of the hand's middle finger rides exactly ON the purple line. "
          "Do NOT add or show any body, torso, head, hat, legs, piano, keys, second hand, strings or any other object: only the arm. "
          "Keep the wood carving, the colours, the proportions and the size of the arm exactly as in the image (the arm must not grow, shrink, bend differently or change its look). ")

RIGID = ("The arm moves like a rigid object sliding sideways on a horizontal rail: the angle of the upper arm and the angle of the forearm stay exactly the same as in the image "
         "and the arm does NOT swing, rotate or tilt like a pendulum; the shoulder ball, the elbow ball and the hand all keep the same height and only travel horizontally together. ")

A = RIGID + ("Motion over exactly 10 seconds: during the first 1.5 seconds the arm slides to the right until the tip of the middle finger is exactly at the right end of the purple line, at the label '10'. "
             "Then, from second 1.5 to second 10, the arm slides to the left along the purple line at a perfectly steady speed, with the fingertip always on the line, "
             "and the fingertip arrives at the left end of the purple line, at the label '1', exactly at the very end. The hand stays palm-down and relaxed.")
B = RIGID + ("Motion over exactly 10 seconds: during the first 1.5 seconds the arm slides to the right until the tip of the middle finger is exactly at the right end of the purple line, at the label '10'. "
             "Then, from second 1.5 to second 10, the arm slides to the left along the purple line at a steady speed, with the fingertip always on the line, arriving at the label '1' exactly at the very end. "
             "While it slides, only the fingers move: they tap lightly up and down one after another in a quick natural piano-playing rhythm (about four taps per second); the palm stays facing down.")
C = ("The whole arm travels sideways along the horizontal purple line while keeping the same height; the upper arm and the forearm keep roughly the same angles, and the wrist and elbow flex only slightly and naturally, "
     "no pendulum swing. Motion over exactly 10 seconds: during the first 1.5 seconds the arm goes to the right until the tip of the middle finger is exactly at the label '10' at the right end of the purple line. "
     "Then, from second 1.5 to second 10, it moves to the left along the purple line at a slow steady speed, the fingertip always on the line, and reaches the label '1' at the left end exactly at the very end. "
     "The fingers press down softly now and then like touching piano keys.")

jobs = [{"name": "arm2_" + k, "image": IMG, "prompt": COMMON + v, "seconds": 10, "ratio": "16:9", "out": OUT % k, "timeout_s": 900}
        for k, v in (("A", A), ("B", B), ("C", C))]
spec = {"status_path": sys.argv[2], "accounts": ["main", "a2", "a3"], "max_attempts": 2, "jobs": jobs}
json.dump(spec, open(sys.argv[1], "w", encoding="utf-8"), ensure_ascii=False, indent=1)
print("spec:", sys.argv[1], [j["name"] for j in jobs])
