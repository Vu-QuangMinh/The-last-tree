"""Orphan art report: every picture / sound under assets/ whose file name (or stem) appears nowhere in scripts/, tools/, tests/ or data/.
REVIEW LIST ONLY: this script deletes nothing. Names built at run time (e.g. "sfx_handy_hit_%d") are matched by their prefix,
frame numbers (_01) and state suffixes (_hover) are stripped before matching, so the list errs on the side of "referenced".
Usage: python tools/orphan_art_report.py  -> docs/orphan_art_report.md"""
import os
import re

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SKIP_DIRS = ("_Source", "_Backup", "_Refs", "_Redo", "_Candidates", "_Archive", "redo_refs", ".git", ".godot")
EXTS = (".png", ".webp", ".jpg", ".jpeg", ".wav", ".ogg", ".mp3")
SUFFIX = re.compile(r"_(normal|hover|pressed|disabled|on|off|left|mid|right|top|bottom|s|big|small|front|back|open|closed)$")

text = []
for d in ("scripts", "tools", "tests", "data"):
    for dp, _dns, fs in os.walk(os.path.join(ROOT, d)):
        for f in fs:
            if f.endswith((".gd", ".py", ".json", ".txt")):
                with open(os.path.join(dp, f), encoding="utf-8", errors="ignore") as h:
                    text.append(h.read())
blob = "\n".join(text)
literals = set(re.findall(r'"([^"\n]{2,80})"', blob)) | set(re.findall(r"'([^'\n]{2,80})'", blob))
exact, prefixes = set(), set()
for s in literals:
    if "%" in s or "{" in s:
        p = re.split(r"%|\{", s)[0]
        if len(p) >= 3:
            prefixes.add(p)
    else:
        exact.add(s)
        exact.add(os.path.splitext(os.path.basename(s))[0])


def referenced(stem: str) -> bool:
    cands = {stem, re.sub(r"_\d+$", "", stem), SUFFIX.sub("", stem), SUFFIX.sub("", re.sub(r"_\d+$", "", stem))}
    for c in cands:
        if len(c) < 3:
            continue
        if c in exact or c in blob:
            return True
    return any(stem.startswith(p) for p in prefixes)


rows = []
for dp, dns, fs in os.walk(os.path.join(ROOT, "assets")):
    dns[:] = [x for x in dns if not x.startswith(SKIP_DIRS)]
    if os.path.relpath(dp, ROOT).replace("\\", "/").startswith("assets/Global/Music"):
        continue  # music is found by listing the folder (Audio.list_tracks), never by name
    for f in fs:
        if not f.lower().endswith(EXTS):
            continue
        if not referenced(os.path.splitext(f)[0]):
            p = os.path.join(dp, f)
            rows.append((os.path.getsize(p), os.path.relpath(p, ROOT).replace("\\", "/")))
rows.sort(reverse=True)
by_dir = {}
for size, p in rows:
    k = "/".join(p.split("/")[:3])
    by_dir.setdefault(k, [0, 0])
    by_dir[k][0] += 1
    by_dir[k][1] += size

out = ["# Orphan art report", "", "Files under `assets/` whose name is not found in `scripts/`, `tools/`, `tests/`, `data/`.",
       "**Review list: nothing was deleted.** A file here may still be used through a name built at run time: check before removing.", "",
       "## By folder", "", "| folder | files | MB |", "|---|---:|---:|"]
out += ["| %s | %d | %.0f |" % (k, v[0], v[1] / 2**20) for k, v in sorted(by_dir.items(), key=lambda kv: -kv[1][1])]
out += ["", "## Files (largest first)", "", "| MB | file |", "|---:|---|"]
out += ["| %.1f | %s |" % (s / 2**20, p) for s, p in rows]
out += ["", "Total: %d files, %.0f MB" % (len(rows), sum(s for s, _ in rows) / 2**20)]
dest = os.path.join(ROOT, "docs", "orphan_art_report.md")
with open(dest, "w", encoding="utf-8") as h:
    h.write("\n".join(out) + "\n")
print(dest, len(rows), "files")
