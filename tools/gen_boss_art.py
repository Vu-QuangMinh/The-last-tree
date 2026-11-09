"""2026-11-08: generate the RAW pictures (ImageSet / Gemini) for the new Act 2 bosses and mobs and the Pianist's pieces.
Only generates; tools/import_boss_art.py cuts and places them afterwards.
Run:  python tools/gen_boss_art.py <set> [name ...]      set = icons | artifacts | bosses | pianist
(plain python is enough: it only calls ImageSet's own python). Output goes to E:\\GitHub\\ImageSet\\output\\<set name>."""
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import make_missing_icons as M

SETS = {
    "icons": ("Puppet Intent Bosses", "Icon/Intent/intent_extra_style.txt", "Icon/Intent/boss_intents_prompts.txt", "1:1"),
    "artifacts": ("Puppet Artifact Piano", "Icon/Artifact/artifact_icons_style.txt", "Icon/Artifact/piano_artifacts_prompts.txt", "1:1"),
    "bosses": ("Act 2 Bosses", "Enemies/Act2/act2_bosses_style.txt", "Enemies/Act2/act2_bosses_prompts.txt", "1:1"),
    "pianist": ("Pianist Pieces", "Enemies/Act2/pianist_style.txt", "Enemies/Act2/pianist_prompts.txt", "1:1"),
}

if __name__ == "__main__":
    key = sys.argv[1]
    set_name, style, prompts, ratio = SETS[key]
    only = sys.argv[2:]
    objs = [o for o in M.objects(prompts) if not only or any(w.lower() in o["name"].lower() for w in only)]
    print(set_name, len(objs), "pictures", flush=True)
    M.generate(set_name, style, objs, ratio)
