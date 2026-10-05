# The Last Tree: rules for Claude

- Reply in Vietnamese (also set globally).
- Art pipeline: `assets/ui/Fight UI.pdf` -> `python tools/export_fight_ui.py` -> `assets/ui/new/<folder>/` (see `docs/art_progress.md`). Godot: `C:\Program Files\Godot\Godot.exe`; new `class_name` files need `--headless --editor --quit` once; warnings are errors; tests: `--headless --script res://tests/run_tests.gd`.
- **When the user chats "Kết thúc phiên làm việc" ("end the work session"), do all of this at once:**
  1. Commit the work (exclude `project.godot` when it only differs by line endings, `assets/Room Background/` and other untracked scratch files; end the message with the Co-Authored-By line).
  2. Record what was done and what is still waiting in `docs/art_progress.md` (Done / To do), and update the memory notes if something non-obvious was learned.
  3. Push to the user's fork branch: `git push origin Banana-Fork`.
  Then reply with a short report: the commit, what was recorded, what is still pending.
- Vu-QuangMinh also commits to this repo from an older copy and has dropped the user's work in merges before: after a pull, compare against the last commit by sonvtbatdan.
- Two people (and their Claude sessions) work here. Something that looks "lost in a merge" may be a deliberate design change by the other side: check the settled rules below and ask before restoring an older version. (Commit d661230 re-added auto-cast, the picture card, painted artifact slots, the green-cross Mend icon and the Chant button's dark base strip; all five had been removed on purpose and were taken out again.)

## Settled game rules (don't "restore" older versions of these)

- **No spell casts itself.** After Chant, every awake spell waits for the player's click, even one with nothing to aim at (shield, heal, a lone enemy). No `_auto_cast`.
- **The Release is manual.** When every spell is cast the Release button pulses; the player presses it (E). Undo (Ctrl+Z / Backspace / the button under the chant) takes back spells until then.
- **Spell cards have no picture.** Classic layout: name banner on top, pattern orbs under it, coloured rules text, and the "RARITY · CATEGORY" line written at the bottom (no icons there). Wax seals on sealed orbs; anti-spells use the dark holo look; a fused anti-spell shows its two patterns as two rows.
- **Artifact slots**: no painted box, just a faint outline (72 px in fights, 56 px in the top bar).
- **Mend intent**: a red heart with a green up-arrow (`MendIcon`), never a "+" sign.
- **Chant button**: the amber face only, without the art's dark base strip.
