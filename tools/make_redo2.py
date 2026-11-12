"""2026-11-11 second redo: Tree Dweller (clearer people, fuller crown), the stun star icon, and the NewUI Ver2 menu panels + buttons in the HUD's
look (UI/NewUiV2/: found first by UiSkin only in that theme). ImageSet (Gemini, the user's quota) -> Tachnen BiRefNet cut (black background) -> trimmed,
NEVER scaled. Replaced pictures are backed up in Enemies/_Source/_Backup_redo_2026-11-11/.
Run:  "D:/GitHub Projects/Tachnen/.venv/Scripts/python.exe" tools/make_redo2.py [--no-generate]"""
import glob
import json
import os
import shutil
import subprocess
import sys
import tempfile

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import paths
import asset_paths as AP

sys.path.insert(0, paths.TACHNEN)
from PIL import Image

IMAGESET = paths.IMAGESET
OUTROOT = (paths.IMAGESET_OUT + "/output")
P = AP.PUPPET
ACT2 = os.path.join(P, "Enemies", "Act2")
V2 = os.path.join(P, "UI", "NewUiV2")
MENU = os.path.join(V2, "_Menu")
BACKUP = os.path.join(P, "Enemies", "_Source", "_Backup_redo_2026-11-11")
ACCOUNTS = ["main", "b", "a2"]
CUT_OPTS = {"model": "birefnet-general", "use_gpu": True, "gpu_mem_gb": 0, "alpha_matting": False, "am_fg": 240, "am_bg": 10,
            "am_erode": 10, "post_process_mask": True, "defringe": True, "alpha_cutoff": 0, "feather": 0.0, "bg_mode": "transparent",
            "bg_custom": "#00ff00", "trim": False, "pad": 0}
# name -> [file, "square" (feet on the bottom edge) or "trim"]
OUT = {"Puppet Tree Dweller": [os.path.join(ACT2, "tree_dweller.png"), "square"],
       "Puppet Stun Star": [os.path.join(P, "UI", "Fx", "stun_star.png"), "trim"],
       "Ver2 Pause Board": [os.path.join(V2, "board_pause_menu.png"), "trim"], "Ver2 Panel Frame": [os.path.join(V2, "panel_wood_frame.png"), "trim"],
       "Ver2 Button Primary": [os.path.join(V2, "btn_primary.png"), "trim"], "Ver2 Button Default": [os.path.join(V2, "btn_default.png"), "trim"],
       "Ver2 Button Danger": [os.path.join(V2, "btn_danger.png"), "trim"], "Ver2 Button Back": [os.path.join(V2, "btn_back.png"), "trim"],
       "Ver2 Button Buy": [os.path.join(V2, "btn_buy.png"), "trim"]}
STYLE_REFS = [{"label": "HUD style", "kind": "setting", "desc": "the look of the HUD plates: copy their materials, brass frame and ornaments",
               "images": [os.path.join(V2, "nu2_plate_red.png"), os.path.join(V2, "nu2_plate_small.png")]}]
BATCHES = [
    ("Redo2 Tree", os.path.join(ACT2, "act2_redo_std_style.txt"), os.path.join(ACT2, "act2_redo2_tree_prompts.txt"), "1:1", None,
     {"Puppet Tree Dweller": [{"label": "Tree", "kind": "character", "desc": "the same tree with the two people; make the two people and the crown much clearer", "images": [os.path.join(ACT2, "tree_dweller.png")]}]}),
    ("Redo2 Star", os.path.join(ACT2, "act2_redo2_star_style.txt"), os.path.join(ACT2, "act2_redo2_star_prompts.txt"), "1:1", None, {}),
    ("Redo2 Menu Tall", os.path.join(MENU, "ver2_menu_style.txt"), os.path.join(MENU, "ver2_menu_prompts.txt"), "3:4", ["Ver2 Pause Board"], {"Ver2 Pause Board": STYLE_REFS}),
    ("Redo2 Menu Wide", os.path.join(MENU, "ver2_menu_style.txt"), os.path.join(MENU, "ver2_menu_prompts.txt"), "4:3", ["Ver2 Panel Frame"], {"Ver2 Panel Frame": STYLE_REFS}),
    ("Redo2 Menu Buttons", os.path.join(MENU, "ver2_menu_style.txt"), os.path.join(MENU, "ver2_menu_prompts.txt"), "21:9",
     ["Ver2 Button Primary", "Ver2 Button Default", "Ver2 Button Danger", "Ver2 Button Back", "Ver2 Button Buy"], {n: STYLE_REFS for n in ["Ver2 Button Primary", "Ver2 Button Default", "Ver2 Button Danger", "Ver2 Button Back", "Ver2 Button Buy"]}),
]


def newest(set_name, names):
    base = os.path.join(OUTROOT, set_name)
    files = {}
    for n in names:
        found = sorted(glob.glob(os.path.join(glob.escape(base), glob.escape(n) + "_*.png")), key=os.path.getmtime)
        if found:
            files[n] = found[-1]
    return files


def run_batch(b):
    set_name, style, prompts, ratio, only, refs = b
    objs = []
    for line in open(prompts, encoding="utf-8").read().splitlines():
        if ":" in line.strip():
            name, prompt = line.split(":", 1)
            if only is None or name.strip() in only:
                o = {"name": name.strip(), "prompt": prompt.strip()}
                if name.strip() in refs:
                    o["refs"] = refs[name.strip()]
                objs.append(o)
    status = os.path.join(tempfile.gettempdir(), "imageset_%s_status.json" % set_name.replace(" ", "_"))  # (one status + .log per set: a later run no longer overwrites the log of an earlier one)
    spec = {"set_name": set_name, "style": open(style, encoding="utf-8").read().strip(), "ratio": ratio, "objects": objs, "status_path": status, "retries": 1, "accounts": ACCOUNTS}
    sp = os.path.join(tempfile.gettempdir(), "imageset_%s_spec.json" % set_name.replace(" ", "_"))
    json.dump(spec, open(sp, "w", encoding="utf-8"), ensure_ascii=False, indent=1)
    subprocess.call([os.path.join(IMAGESET, ".venv", "Scripts", "python.exe"), "main.py", "--batch", sp, "--background"], cwd=IMAGESET)
    st = json.load(open(status, encoding="utf-8"))
    print("ImageSet", set_name, ":", st.get("state"), st.get("done"), "/", st.get("total"), st.get("errors"), flush=True)
    return newest(set_name, [o["name"] for o in objs])


def main():
    files = {}
    for b in BATCHES:
        files.update(newest(b[0], [o for o in OUT]) if "--no-generate" in sys.argv else run_batch(b))
    print("missing:", [n for n in OUT if n not in files], flush=True)
    import tachnen_core as core
    import gemini_star
    import import_newui2_art as nu2
    proc = core.Processor()
    os.makedirs(BACKUP, exist_ok=True)
    for name, path in files.items():
        raw = gemini_star.remove(Image.open(path).convert("RGBA"))  # (the Gemini star is reversed out, never cut: tools/gemini_star.py)
        im = nu2.key_cut(raw) if name.startswith("Ver2") else None  # (solid parts on black: keyed, a model bites dark/red edges)
        if im is None:
            im = proc.run(raw, CUT_OPTS)
        im = im.crop(im.getchannel("A").point(lambda v: 255 if v > 8 else 0).getbbox())
        dest, mode = OUT[name]
        if mode == "square":
            side = int(max(im.size) * 1.08)
            sq = Image.new("RGBA", (side, side), (0, 0, 0, 0))
            sq.alpha_composite(im, ((side - im.width) // 2, side - im.height - int(side * 0.02)))
            im = sq
        if os.path.exists(dest) and not os.path.exists(os.path.join(BACKUP, os.path.basename(dest))):
            shutil.copy2(dest, os.path.join(BACKUP, os.path.basename(dest)))
        os.makedirs(os.path.dirname(dest), exist_ok=True)
        im.save(dest)
        print("  %-24s -> %s  %dx%d" % (name, os.path.relpath(dest, P), im.width, im.height), flush=True)


if __name__ == "__main__":
    main()
