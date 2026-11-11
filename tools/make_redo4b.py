"""The Ver2 check mark again, alone on black (the first one came with a painted plate behind it). See make_redo4.py."""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import make_redo2 as m

m.OUT = {"Ver2 Check Mark": [os.path.join(m.V2, "nu2_check_mark.png"), "trim"]}
m.BATCHES = [("Redo4b Check Mark", os.path.join(m.ACT2, "act2_redo2_star_style.txt"), os.path.join(m.MENU, "ver2_check_mark_prompts.txt"), "1:1", None, {})]
if __name__ == "__main__":
    m.main()
