# Behind the Curtain

A Godot 4.6 chanting roguelite (GL Compatibility renderer, also exported to the web). Three acts on a branching map, one encounter at a time, first person, enemies in front of you like puppets on a stage. Enemies' HP is a row of Fire, Water and Wind; you chant elements to break those rows and wake your spells.

## Play

Open the folder in Godot 4.6 and press F5, or:

```
"C:\Program Files\Godot\Godot.exe" --path .
```

New? Main menu → **Tutorial**. Rules: main menu "How to play · Wiki" or **F1** anywhere.

### The loop (the settled rules: see CLAUDE.md before changing any of them)
1. Build a chant (up to 8 elements) and press **Chant**. Every active spell whose pattern appears in the chant wakes up, one charge per separate match, never more than its pattern's length.
2. **No spell casts itself.** Click each awake spell to cast it (targeted spells ask for a target). Right-click / Esc puts back a *selected* spell before it is cast; a cast spell cannot be taken back.
3. When every spell is cast the **Release** button pulses: press it (E). Every enemy loses the longest start of its HP row found in the chant, element by element. Then the enemies act.

Cards are Common, Rare or Legendary. Campfires heal or fuse two spells. Elites give artifacts, bosses give Legendaries and talk before the fight.

## Numbers
214 spells in `data/spells.json` (the only source of spell data), 87 enemies in `scripts/core/enemy_defs.gd`, 7 bosses over 3 acts.

## Project layout
| Path | What |
|---|---|
| `scripts/core/` | Rules only, no UI (RefCounted): `fight.gd`, `chant.gd`, `run_state.gd`, `enemy_defs.gd`, `enemy_state.gd`, `player_state.gd`, `spell_db.gd`, `artifacts.gd`, `bottles.gd`, `map_gen.gd`, `map_events.gd`, `boss_talk.gd`, `fuse_rules.gd` |
| `scripts/ui/` | Screens and widgets, all built in code (`scenes/main.tscn` is the only scene). `fight_screen.gd` is the fight; `ui_skin.gd` finds art by name; `ui_theme.gd` fonts and boards |
| `scripts/autoload/` | `Events` (signal bus), `GameData` (spell DB), `SaveManager` (`user://save.json` + `save_run.txt`), `Audio` |
| `data/` | `spells.json`; the user's hand-placed layouts (`enemy_ropes.json`, `event_layout_overrides.json`, `shop_layout_overrides.json`): never delete |
| `assets/` | `Global/` shared, `New/` and `Puppet/` per theme, same shape inside: see `assets/README.md` |
| `tools/` | Godot test/screenshot scripts (`*_impl.gd` + 5-line wrapper) and Python art/sound pipelines: see `tools/README.md` |
| `tests/` | Headless unit tests of the core |
| `docs/` | `art_progress.md` (what is still to do), `changelog/` (what was done, by month), design notes, audit and plans |

## Verify a change (cheapest first)
```
# every script parses (warnings are errors: project.godot [debug])
"C:\Program Files\Godot\Godot.exe" --headless --path . --script res://tools/check_scripts.gd
# unit tests (-- filter narrows to tests whose "file:name" contains it)
"C:\Program Files\Godot\Godot.exe" --headless --path . --script res://tests/run_tests.gd
# balance sim, headless
"C:\Program Files\Godot\Godot.exe" --headless --path . --script res://tools/sim.gd -- 60 new
# screenshots of every screen (windowed, off screen, no sound): SHOT_THEME=new|puppet
"C:\Program Files\Godot\Godot.exe" --path . --position 6000,0 --no-focus --audio-driver Dummy --script res://tools/shots.gd -- <out_dir>
```
After adding a `class_name` file or new art, run the editor once headless so Godot imports it: `--headless --editor --quit`.

## Working here
Two people commit to this repo. Read `CLAUDE.md` first: the settled rules, the code map, what is locked and what is free, and the end-of-session routine. `docs/audit_2026-11-12.md` lists the known debts and the plan to pay them.
