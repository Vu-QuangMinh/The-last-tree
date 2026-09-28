# The Last Tree

A Godot 4.6 chanting roguelite. You travel through three acts on a branching map and fight one encounter at a time, first person, with the enemies in front of you. Enemies' HP is a row of Fire, Water and Wind. You chant elements to break those rows and trigger your spells.

## Play

Open the folder in Godot 4.6 and press **F5**, or run:

```
C:\Tools\Godot\godot.exe --path "C:\Users\minhv\Documents\The last tree"
```

### New? Play the Tutorial
Main menu → **Tutorial**: one scripted fight where Sprout walks you through elements, enemy HP, building a chant, the preview, spells, targeting, Shield, intents and the Release, then sums up the rest of a run.

### The rules
Everything is in the in-game **wiki** (main menu "How to play · Wiki", or **F1** anywhere): tabs for the basics, the chant, spells, keywords, enemies and intents, artifacts and the run, plus a search box.

In short: build a chant (up to 8 elements) and press Chant. Every active spell whose pattern appears comes alive, one charge per separate match but never more than its pattern's length (WW triggers at most twice). Cast the living spells in any order; spells that change the chant (Spark/Spring/Breath Word, Resonance, Triune Chant) can wake more spells. When nothing is left to cast, the chant is Released by itself: every enemy loses the longest start of its HP found in the chant, as the chant's elements fly at them one by one from left to right. Then the enemies act, using their moves in a fixed order.

Cards are Common, Rare or Legendary. Normal fights offer 70% Common / 30% Rare cards, elites 3 Rares plus an artifact, bosses 3 Legendaries plus a relic that adds elements every turn. Rest sites heal or upgrade a spell. Treasure always includes one cursed artifact.

## Project layout
| Path | What |
|---|---|
| `data/spells.json` | The 100 spells (16 Powers). The only source of spell data. |
| `docs/spells.xlsx`, `docs/spell-list.md` | Readable spell tables generated from the JSON (`python tools/spell_report.py`) |
| `docs/superpowers/specs/2026-09-27-the-last-tree-chant-design.md` | The design spec |
| `scripts/core/` | Pure rules: `chant.gd` (matching), `fight.gd` (resolution order and enemy phase), `enemy_state.gd`, `player_state.gd`, `enemy_defs.gd` (the 30 enemies, including elites and bosses), `artifacts.gd`, `map_gen.gd`, `run_state.gd`, `spell_text.gd` |
| `scripts/ui/` | Screens (menu, map, loadout, fight, choice, message, codex, unlocks) and widgets (element icons, spell cards, enemy views, procedural creatures and backdrop) |
| `scripts/autoload/` | `Events`, `GameData` (spell DB), `SaveManager` (`user://save.json`: Seedlings, unlocks, codex, stats) |

## Tools
```
# unit tests
godot_console --headless --path . -s tests/run_tests.gd
# parse-check every script
godot_console --headless --path . -s tools/check_scripts.gd
# balance sim: scripted player, full runs (modes: new = default unlocks, vet = everything unlocked)
godot_console --headless --path . -s tools/sim.gd -- 60 new
# spell strength: starters + one extra spell, per spell
godot_console --headless --path . -s tools/sim.gd -- 12 spells
# a full run played through the real UI, with screenshots (windowed)
godot --path . --resolution 1920x1080 -s tools/ui_playtest.gd -- <out_dir>
# static screenshots of every screen
godot --path . --resolution 1920x1080 -s tools/shots.gd -- <out_dir>
```
