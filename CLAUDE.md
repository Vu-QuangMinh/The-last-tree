# The Last Tree: rules for Claude

- Reply in Vietnamese (also set globally).
- Art pipeline: `assets/ui/Fight UI.pdf` -> `python tools/export_fight_ui.py` -> `assets/ui/new/<folder>/` (see `docs/art_progress.md`). Godot: `C:\Program Files\Godot\Godot.exe`; new `class_name` files need `--headless --editor --quit` once; warnings are errors; tests: `--headless --script res://tests/run_tests.gd`.
- **When the user chats "Kết thúc phiên làm việc" ("end the work session"), do all of this at once:**
  1. Commit the work (exclude `project.godot` when it only differs by line endings, `assets/Room Background/` and other untracked scratch files; end the message with the Co-Authored-By line).
  2. Record what was done and what is still waiting in `docs/art_progress.md` (Done / To do), and update the memory notes if something non-obvious was learned.
  3. Push to the user's fork branch: `git push origin Banana-Fork`.
  Then reply with a short report: the commit, what was recorded, what is still pending.
- Vu-QuangMinh also commits to this repo from an older copy and has dropped the user's work in merges before: after a pull, compare against the last commit by sonvtbatdan.
