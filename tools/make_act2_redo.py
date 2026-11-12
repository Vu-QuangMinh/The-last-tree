"""2026-11-11 redo of 10 Act 1/2 puppets (user's list): Headless Horseman (rearing horse, head in one hand, sabre in the other) + the same
with the head thrown, Maddened Soldier (Pindleskin look, drags a claymore, crazed grin), Tree Dweller (ONE tree, man left / woman right),
Bog Lantern (ONE angler fish with its lamp on the stalk in front), Hush Moth (big wings, small fierce head), and the FALLEN picture of every
flyer (Winged Tortoise, Leech Bat, Scavenger Vulture, Hush Moth).
ImageSet (Gemini, the user's quota) draws them in 3 stages (the last one uses stage 1/2 pictures as references); Tachnen's BiRefNet cuts the
black background; the cut picture is trimmed and put on a square canvas, feet on the bottom edge, NEVER scaled. Replaced pictures are backed
up in Enemies/_Source/_Backup_redo_2026-11-11/.
Run:  "D:/GitHub Projects/Tachnen/.venv/Scripts/python.exe" tools/make_act2_redo.py [--no-generate]   (then Godot --headless --editor --quit once)"""
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
ENEMIES = os.path.join(AP.PUPPET, "Enemies")
ACT2 = os.path.join(ENEMIES, "Act2")
REFS = os.path.join(ENEMIES, "_Source", "Act2", "redo_refs")
BACKUP = os.path.join(ENEMIES, "_Source", "_Backup_redo_2026-11-11")
ACCOUNTS = ["main", "b", "a2"]
CUT_OPTS = {"model": "birefnet-general", "use_gpu": True, "gpu_mem_gb": 0, "alpha_matting": False, "am_fg": 240, "am_bg": 10,
            "am_erode": 10, "post_process_mask": True, "defringe": True, "alpha_cutoff": 0, "feather": 0.0, "bg_mode": "transparent",
            "bg_custom": "#00ff00", "trim": False, "pad": 0}
# picture name -> file written (relative to Enemies/)
OUT = {"Puppet Headless Horseman": "Act2/headless_horseman.png", "Puppet Headless Horseman Thrown": "Act2/headless_horseman_thrown.png",
       "Puppet Maddened Soldier": "Act2/mad_soldier.png", "Puppet Tree Dweller": "Act2/tree_dweller.png",
       "Puppet Bog Lantern": "Act2/bog_fish.png", "Puppet Hush Moth": "Act1/hush_moth.png", "Puppet Hush Moth Fallen": "Act1/hush_moth_fallen.png",
       "Puppet Winged Tortoise Fallen": "Act1/winged_tortoise_fallen.png", "Puppet Leech Bat Fallen": "Act1/leech_bat_fallen.png",
       "Puppet Scavenger Vulture Fallen": "Act2/scav_vulture_fallen.png"}


def ref(label, desc, *images):
    return {"label": label, "kind": "character", "desc": desc, "images": list(images)}


def objects(prompts_file):
    out = []
    for line in open(os.path.join(ACT2, prompts_file), encoding="utf-8").read().splitlines():
        if ":" in line.strip():
            name, prompt = line.split(":", 1)
            out.append({"name": name.strip(), "prompt": prompt.strip()})
    return out


def run_batch(set_name, style_file, prompts_file, refs_by_name):
    objs = objects(prompts_file)
    for o in objs:
        if o["name"] in refs_by_name:
            o["refs"] = refs_by_name[o["name"]]
    status = os.path.join(tempfile.gettempdir(), "act2_redo_status.json")
    spec = {"set_name": set_name, "style": open(os.path.join(ACT2, style_file), encoding="utf-8").read().strip(), "ratio": "1:1",
            "objects": objs, "status_path": status, "retries": 1, "accounts": ACCOUNTS}
    spec_path = os.path.join(tempfile.gettempdir(), "act2_redo_spec.json")
    json.dump(spec, open(spec_path, "w", encoding="utf-8"), ensure_ascii=False, indent=1)
    code = subprocess.call([os.path.join(IMAGESET, ".venv", "Scripts", "python.exe"), "main.py", "--batch", spec_path, "--background"], cwd=IMAGESET)
    st = json.load(open(status, encoding="utf-8"))
    print("ImageSet", set_name, ":", st.get("state"), st.get("done"), "/", st.get("total"), st.get("errors"))
    return newest(set_name, [o["name"] for o in objs])


def newest(set_name, names):
    base = os.path.join((paths.IMAGESET_OUT + "/output"), set_name)  # (ImageSet writes its pictures on E:)
    files = {}
    for n in names:
        found = sorted(glob.glob(os.path.join(glob.escape(base), glob.escape(n) + "_*.png")), key=os.path.getmtime)
        if found:
            files[n] = found[-1]
    return files


def stages(generate):
    S = lambda *a: newest(*a)
    r = os.path.join
    if generate:
        resume = "--resume" in sys.argv  # (stages A and B are already drawn: only stage C is generated)
        a = newest("Act 2 Redo A", list(OUT)) if resume else run_batch("Act 2 Redo A", "act2_redo_std_style.txt", "act2_redo_std_prompts.txt", {
            "Puppet Maddened Soldier": [ref("Pose + outfit", "the dragging pose, ragged armour and skull-like head to copy in spirit", r(REFS, "soldier_pose.png")),
                                        ref("Grin", "the crazed wide grin and wrinkled forehead to copy in spirit", r(REFS, "soldier_grin.png"))]})
        b = newest("Act 2 Redo B", list(OUT)) if resume else run_batch("Act 2 Redo B", "act2_redo_pose_style.txt", "act2_redo_pose_prompts.txt", {
            "Puppet Headless Horseman": [ref("Pose", "the rearing horse and the rider holding his own head up", r(REFS, "horseman_pose.png"))],
            "Puppet Winged Tortoise Fallen": [ref("Winged tortoise", "the same creature", r(ENEMIES, "Act1", "winged_tortoise.png"))],
            "Puppet Leech Bat Fallen": [ref("Leech bat", "the same creature", r(ENEMIES, "Act1", "leech_bat.png"))],
            "Puppet Scavenger Vulture Fallen": [ref("Vulture", "the same creature", r(ACT2, "scav_vulture.png"))]})
        got = {**a, **b}
        c = run_batch("Act 2 Redo C", "act2_redo_pose_style.txt", "act2_redo_pose2_prompts.txt", {
            "Puppet Headless Horseman Thrown": [ref("Horseman", "the same rider and horse", got["Puppet Headless Horseman"])],
            "Puppet Hush Moth Fallen": [ref("Hush Moth", "the same moth", got["Puppet Hush Moth"])]})
        return {**got, **c}
    got = {}
    for s in ("Act 2 Redo A", "Act 2 Redo B", "Act 2 Redo C"):
        got.update(newest(s, list(OUT)))
    return got


def main():
    files = stages("--no-generate" not in sys.argv)
    missing = [n for n in OUT if n not in files]
    if missing:
        print("MISSING pictures (run again; the ones that exist are kept):", missing)
    import tachnen_core as core
    proc = core.Processor()
    os.makedirs(BACKUP, exist_ok=True)
    for name, path in files.items():
        im = proc.run(Image.open(path).convert("RGBA"), CUT_OPTS)
        im = im.crop(im.getchannel("A").point(lambda v: 255 if v > 8 else 0).getbbox())
        side = int(max(im.size) * 1.08)
        sq = Image.new("RGBA", (side, side), (0, 0, 0, 0))
        sq.alpha_composite(im, ((side - im.width) // 2, side - im.height - int(side * 0.02)))
        dest = os.path.join(ENEMIES, OUT[name])
        if os.path.exists(dest) and not os.path.exists(os.path.join(BACKUP, os.path.basename(dest))):
            shutil.copy2(dest, os.path.join(BACKUP, os.path.basename(dest)))
        sq.save(dest)
        im.save(os.path.join(ENEMIES, "_Source", "Act2", name + ".png"))
        print("  %-34s -> %s  %dx%d" % (name, OUT[name], sq.width, sq.height))


if __name__ == "__main__":
    main()
