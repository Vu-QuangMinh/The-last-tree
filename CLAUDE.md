# The Last Tree: rules for Claude

- Reply in Vietnamese (also set globally).
- Art pipeline: `assets/New/_Source/Fight UI.pdf` -> `python tools/export_fight_ui.py` -> `assets/New/...` (layout of `assets/`: see `assets/README.md`; exporters write through `tools/asset_paths.py`) (see `docs/art_progress.md`). Godot: `C:\Program Files\Godot\Godot.exe`; new `class_name` files need `--headless --editor --quit` once; warnings are errors; tests: `--headless --script res://tests/run_tests.gd`.
- **When the user chats "Kết thúc phiên làm việc" ("end the work session"), do all of this at once:**
  1. Commit the work (exclude `project.godot` when it only differs by line endings, the `_Source` folders under `assets/` and other untracked scratch files; end the message with the Co-Authored-By line).
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

## Code map (read this before grepping)

- `scripts/core/` = game logic, no UI: `fight.gd` (turn/spell resolution, 2k lines), `run_state.gd` (run progress, rewards), `enemy_defs.gd`/`enemy_state.gd`, `player_state.gd`, `spell_db.gd` (+ `docs/spells.xlsx`, `tools/dump_spells.gd`), `artifacts.gd`, `bottles.gd`, `map_gen.gd`/`map_events.gd`, `chant.gd`.
- `scripts/ui/fight_screen.gd` is the 5k-line fight UI; read it by function (grep `func _`), never whole. Other screens: `map_screen`, `campfire_screen`, `shop_screen`, `apothecary_screen`, `fuse_screen`, `loadout_screen`, `settings_screen`, `tutorial_screen`.
- Look & theme: `ui_skin.gd` (art lookup, null when art is missing), `ui_theme.gd`, `backdrop.gd`/`backdrop_fx.gd`, `puppet_stage.gd` (+ generated `puppet_layout.gd`), `spell_card.gd`, `creature.gd`, `enemy_view.gd`, `spell_fx.gd`, `vfx.gd`.
- Autoloads: `audio.gd`, `save_manager.gd` (settings: theme / font / show_hotkeys), `game_data.gd`, `events.gd`. Entry: `scenes/main.tscn` + `scripts/main.gd`.
- Themes: only `new` and `puppet` (the Default and Cirus looks were dropped; an old save that says so opens in New; the Cirus art is parked in `assets/_Archive/Circus`). `UiSkin.is_circus()` is just `is_puppet()` (Puppet kept the layout first made for Cirus). Art is in `assets/{Global,New,Puppet}/`: see `assets/README.md`.

## Testing the game while the user is working: silent and out of the way

- Anything that only reads data or logic runs `--headless` (no window, no sound): `Godot.exe --headless --path . --script res://tools/<x>.gd`. A script run with `-s` / `--script` is also muted by the `Audio` autoload, so a test can never be heard.
- A test that needs real rendering (screenshots) uses a window: `--position 6000,0 --no-focus --audio-driver Dummy` (off screen, not focused, dummy sound driver), `Window` never topmost, closed at the end of the script (`quit()`), killed by its own PID only; a tool script always ends with `quit()` and starts a `create_timer(60..240).timeout.connect(quit)` guard so an error cannot leave a window hanging.
- Never touch the user's Godot editor or its game window.

## Verify (pick the cheapest that proves the change)

1. Parse: `"C:\Program Files\Godot\Godot.exe" --headless --path . --script res://tools/check_scripts.gd`. New `class_name` file -> run `--headless --editor --quit` once first. Untyped `:=` from a Variant is an error.
2. Logic: `--headless --script res://tests/run_tests.gd`.
3. Visual: `tools/shots.gd` / `tools/puppet_fight_shot.gd` (windowed; `SHOT_THEME=new|puppet`). Per global rules start it hidden/off-screen, kill only the PID you started, never the user's editor. A still shot cannot show tweens, sfx or shaders: say so.
4. Real flow bugs: drive the actual screen functions (see `tools/ui_playtest.gd`, `stage_flow_test.gd`), not an isolated widget.

## Traps

- Lambdas copy captured locals: re-read state inside the callback.
- `HFlowContainer` fights hand-placed children: use a plain `Control`.
- Edit `.gd` with the Edit tool or Python (UTF-8); PowerShell Get/Set-Content turns it into mojibake.
- Art exporters (`tools/export_*.py`) are slow (~100 s) and silently drop a piece when a PDF label is renamed: read their log.
