"""2026-11-11: the tick box and the check mark of NewUI Ver2 (Settings), ImageSet -> Gemini star reversed -> key cut (never scaled), into UI/NewUiV2/nu2_check_box.png and nu2_check_mark.png.
Run:  "D:/GitHub Projects/Tachnen/.venv/Scripts/python.exe" tools/make_redo4.py [--no-generate]"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import make_redo2 as m

m.OUT = {"Ver2 Check Box": [os.path.join(m.V2, "nu2_check_box.png"), "trim"], "Ver2 Check Mark": [os.path.join(m.V2, "nu2_check_mark.png"), "trim"]}
m.BATCHES = [("Redo4 Check", os.path.join(m.MENU, "ver2_menu_style.txt"), os.path.join(m.MENU, "ver2_check_prompts.txt"), "1:1", None,
              {"Ver2 Check Box": m.STYLE_REFS})]
if __name__ == "__main__":
    m.main()
