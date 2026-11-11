"""2026-11-11 third redo: REAL buttons for NewUI Ver2 (raised normal + pressed, five kinds; hover is the normal picture made lighter in code) and a square panel.
Same flow as make_redo2.py (ImageSet -> Gemini star reversed -> key cut, never scaled). The panel pictures made earlier are kept as the panel set (board_pause_menu = tall, panel_wood_frame = 4:3,
panel_banner = wide, panel_square = square): UiSkin picks the one whose proportions are nearest to the box, so nothing is stretched much.
Run:  "D:/GitHub Projects/Tachnen/.venv/Scripts/python.exe" tools/make_redo3.py [--no-generate]"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import make_redo2 as m

V2, MENU = m.V2, m.MENU
KINDS = ["Primary", "Default", "Danger", "Back", "Buy"]
m.OUT = {"Ver2 Panel Square": [os.path.join(V2, "panel_square.png"), "trim"]}
for k in KINDS:
    m.OUT["Ver2 Btn %s Normal" % k] = [os.path.join(V2, "btn_%s.png" % k.lower()), "trim"]
    m.OUT["Ver2 Btn %s Pressed" % k] = [os.path.join(V2, "btn_%s_pressed.png" % k.lower()), "trim"]
HUD_BTN = [{"label": "HUD buttons", "kind": "setting", "desc": "the look of the HUD's push buttons (they carry words: draw yours with none)",
            "images": [os.path.join(V2, "button_clear_normal.png"), os.path.join(V2, "button_clear_pressed.png"), os.path.join(V2, "button_pass_normal.png")]}]


_cache = {}
_run = m.run_batch
m.run_batch = lambda b: _cache.pop(b[0]) if b[0] in _cache else _run(b)  # (the Normal buttons are drawn once: their pictures are the references of the Pressed ones)


def batches(generate):
    out = [("Redo3 Panel Square", os.path.join(MENU, "ver2_menu_style.txt"), os.path.join(MENU, "ver2_panel_square_prompts.txt"), "1:1", None, {"Ver2 Panel Square": m.STYLE_REFS}),
           ("Redo3 Buttons Normal", os.path.join(MENU, "ver2_menu_style.txt"), os.path.join(MENU, "ver2_btn_normal_prompts.txt"), "21:9", None,
            {"Ver2 Btn %s Normal" % k: HUD_BTN for k in KINDS})]
    refs = {}
    if generate:
        got = m.run_batch(out[1])
        _cache[out[1][0]] = got
        for k in KINDS:
            n = "Ver2 Btn %s Normal" % k
            refs["Ver2 Btn %s Pressed" % k] = [{"label": "Button", "kind": "character", "desc": "this exact button, to draw pressed down", "images": [got[n]]}]
    out.append(("Redo3 Buttons Pressed", os.path.join(MENU, "ver2_menu_style.txt"), os.path.join(MENU, "ver2_btn_pressed_prompts.txt"), "21:9", None, refs))
    return out


if __name__ == "__main__":
    gen = "--no-generate" not in sys.argv
    bs = batches(gen)
    m.BATCHES = bs
    m.main()
