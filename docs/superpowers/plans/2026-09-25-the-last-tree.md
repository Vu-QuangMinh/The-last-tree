# The Last Tree Implementation Plan

> **For agentic workers:** executed inline in this session (superpowers:executing-plans). Steps use checkbox (`- [ ]`) syntax for tracking. Pure-logic tasks are TDD with the headless runner; scene and UI tasks are verified by launching the game.

**Goal:** A playable Godot 4.6 build of *The Last Tree* matching `docs/superpowers/specs/2026-09-25-the-last-tree-design.md`.

**Architecture:**
- **Pure-logic classes** (`RefCounted`, `class_name`, no scene dependencies) hold all rules. They are unit-tested headless.
- **One `Run` node** owns a manual update loop: it calls `update(dt)` on every system, so pausing is simply not ticking, and the headless balance sim can step the same code.
- **UI** is built in code from small `Control` scripts that talk to the run through public methods and the `Events` bus.

**Tech Stack:** Godot 4.6.2 (GDScript), `C:\Tools\Godot\godot_console.exe` for headless runs, and Python 3.12 for `tools/spell_report.py`.

## Global Constraints
- Base resolution 1920×1080, stretch `canvas_items`, aspect `expand`.
- Everything is drawn in code (vector + particles). No image assets, no emoji in game text.
- `data/spells.json` is the only source of spell data. Cooldown and power formulas must match `tools/spell_report.py` (half-up rounding).
- Tree 100 HP (+10/level). Basic enemy 10 HP / 1 dmg. Final boss 5,000,000 HP / 50 dmg. All enemies attack once per second unless noted.
- Damage × P = 1.2^(level−1). Heal/shield/regen/lifesteal × maxHP/100.
- Space toggles pause. Mixing and slot assignment are allowed while paused.
- Save to `user://save.json`.

## File map
```
project.godot                      autoloads: Events, GameData, SaveManager
scripts/core/spell_math.gd         SpellMath: cooldown/power/round/format
scripts/core/spell_db.gd           SpellDB: load json, recipe index, lookups
scripts/core/element_odds.gd       ElementOdds: weights, affinity shift, roll
scripts/core/buff_state.gd         BuffState: timed buffs + share-rule queries
scripts/core/tree_state.gd         TreeState: hp/shield/armor/regen/xp/level/magic/power
scripts/core/status_set.gd         StatusSet: per-enemy burn/poison/slow/stun/…
scripts/core/shapes.gd             Shapes: point-in-shape geometry
scripts/core/targeting.gd          Targeting: best point / angle / top-N
scripts/core/slot_logic.gd         SlotLogic: cooldown, cost check, contingency hook
scripts/core/run_score.gd          RunScore: tallies + seeds
scripts/core/enemy_defs.gd         EnemyDefs: types, bosses, scaling
scripts/autoload/events.gd, game_data.gd, save_manager.gd
scripts/run/run.gd                 Run root: owns systems, update loop, pause
scripts/run/element_bank.gd        counts + spawn bar (uses ElementOdds)
scripts/run/enemy.gd, boss.gd      Enemy entities (draw + update)
scripts/run/director.gd            spawn schedule + bosses
scripts/run/spell_executor.gd      effects → hits / entities / statuses
scripts/run/spell_entities.gd      Projectile, Zone, Mine, Tornado, Orbit, Spiral, Marker
scripts/run/vfx.gd                 flashes, particles, floating numbers
scripts/run/tree_view.gd           draws the tree
scripts/ui/*.gd                    theme, element_icon, hud, spawn_bar, resources_panel,
                                   slot_bar, slot_menu, mixer, spellbook, learn_cutscene,
                                   pause_overlay, end_screen, main_menu, shop, toast
scenes/main.tscn                   Main (switches menu ↔ run)
tests/run_tests.gd + tests/test_*.gd
tools/balance_sim.gd               headless AI run → level/boss-kill timings
```

## Tasks

### Task 1: Scaffold, test runner, SpellMath, SpellDB
- [ ] Create `project.godot`, `scenes/main.tscn`, autoload stubs, `tests/run_tests.gd`. The runner discovers `tests/test_*.gd`, calls every `test_*` method, and exits with the failure count.
- [ ] Tests (`test_spell_math.gd`, `test_spell_db.gd`):
  - `cooldown` matches the Python script for Thermal Explosion (FFFW → 6.4), Sunstone Aegis (5.3) and Ember Bolt (1.6).
  - `power(6) == 180`, `power(1) == 10`.
  - `canon("WFFF") == "FFFW"`.
  - `find_recipe("WFFF").id == "thermal_explosion"`.
  - `basic("F","offense").id == "ember_bolt"`.
  - 120 spells and 18 basics.
  - `fmt_big(12400) == "12.4K"`, `fmt_big(5000000) == "5.0M"`.
- [ ] Implement until green: `godot_console --headless --path . -s tests/run_tests.gd`.

Interfaces: `SpellMath.cooldown(recipe:String, cd_mult:float) -> float`, `SpellMath.power(size:int) -> int`, `SpellMath.round1(x) -> float`, `SpellMath.fmt_big(x:float) -> String`; `SpellDB.load_from(path) -> SpellDB`, `.find_recipe(canon_key) -> Dictionary` (empty if none), `.get_spell(id)`, `.basic(el, cat)`, `.by_cat(cat) -> Array`, `.all_spells`, `.basics`, `static canon(recipe) -> String`.

### Task 2: ElementOdds + BuffState + TreeState
- Odds tests:
  - Initial odds are 1/6 each.
  - A level with 100% Fire XP gives Fire +10, Light/Air +5, Earth/Dark −5, Water −10.
  - Sum stays 1.0.
  - The 3% floor holds after repeated Fire levels.
  - `roll` respects the weights (seeded RNG, 6000 rolls, Fire ≈ its share ±3%).
- Buff tests:
  - Share rule: `elem_dmg {F:0.2}` gives FFFW ×1.15.
  - The universal +3%/slot applies.
  - The same spell refreshes, different spells stack.
  - Expiry after `dur`.
  - `cd_mult` combines generic and elemental (multiplicative with a floor of 0.2).
- Tree tests:
  - XP curve 20+8L.
  - Level-ups return XP-by-element for the odds shift.
  - Magic element every 5 levels.
  - `power()` at level 11 = 1.2^10.
  - Damage order armor → shield → hp.
  - Max HP 100+10/level plus permanent bonuses.
  - Heals are capped at max HP.

Interfaces: `ElementOdds.new()`, `.odds: Dictionary`, `.apply_level(xp_by_el: Dictionary)`, `.roll(rng, rate_bonus: Dictionary) -> String`. `BuffState.add(spell: Dictionary)`, `.tick(dt)`, `.cd_mult(recipe)`, `.dmg_mult(recipe)`, `.heal_mult(recipe)`, `.crit_bonus(recipe)`, `.refund_chance(recipe)`, `.duration_mult(recipe)`, `.spawn_mult()`, `.double_chance(el)`, `.rate_bonus() -> Dictionary`, `.xp_mult()`. `TreeState.add_xp(amount, by_el) -> Array[Dictionary]` (one entry per level gained: `{level, xp_by_el}`), `.take_damage(x) -> float`, `.heal(x) -> float`, `.add_shield(amount, dur)`, `.add_armor(pct, dur)`, `.add_regen(hps, dur, key)`, `.tick(dt)`, `.power() -> float`, `.max_hp`, `.hp`, `.level`, `.magic`, `.hp_scale() -> float`.

### Task 3: Shapes + Targeting + StatusSet
- Shapes tests: a point inside/outside for circle, line, multiline, cone, crescent, star, heart and ring.
- Targeting tests:
  - `best_point` picks the cluster over a lone enemy.
  - `best_angle` points at the cluster.
  - `top_n_by` orders correctly.
  - Bosses first for single.
- StatusSet tests:
  - Burn refresh keeps the higher value.
  - Poison stacks cap.
  - Strongest slow wins, capped at 80%.
  - Vulnerable is additive, capped at +100%.
  - Bosses: charm/confuse ignored, stun/slow halved.
  - `tick` returns DoT damage.
  - Combust returns the remaining burn × pct and clears it.

### Task 4: SlotLogic + RunScore + EnemyDefs
- Slot tests:
  - Not ready while cooling down.
  - Ready but unaffordable → `state == BLOCKED` (blink).
  - Contingency false → `WAITING`.
  - Cast resets the cooldown scaled by `cd_mult`.
  - Slot cost sequence 2, 3, 4.
- Score tests: the example tallies and seeds = floor(score/100 × (1 + keen)).
- EnemyDefs tests: HP scale 1.3^t, damage scale 1 + 0.08t, the spawn-rate curve, boss table values.

### Task 5: Run loop, world, enemies, director, tree view
- `Run` builds the world; tree at (960,540).
- The director spawns at edges.
- Enemies walk, attack each second, and die (with score).
- Bosses have their signatures.
- Spitter projectiles; Splitter splits; Warden barrier.
- Charm, confuse and blind behaviour.
- Victory and defeat detection.
- Verify: launch the game, watch enemies approach and hit the tree, and check that Space pauses.

### Task 6: ElementBank + SpellExecutor + entities + VFX
- Spawn bar with pre-rolled icons, doubling, and the 99 cap.
- Executor covers:
  - Every offensive shape.
  - Activations: delayed, mine and trap.
  - All modifiers, including instakill and combust.
  - Defensive self and area effects, auras and traps.
  - Growth XP, buffs and permanent HP.
  - Contingencies per spec §6.
- VFX per shape and floating numbers.
- Verify: put basic spells in the slots at startup and watch them cast.

### Task 7: UI
- The HUD.
- The resources panel (drag source, blinking).
- The slot bar with a click menu, the + slot button and drag-to-reorder.
- The mixer (drop targets, ownership rule, mix, 5 s lockout).
- The spellbook (3 tabs, ?/full/grey states, assign mode, base vs scaled values).
- The learn cutscene.
- Toasts, the pause overlay and the end screen.
- Verify by playing.

### Task 8: Meta: SaveManager, main menu, Roots shop
- Save/load round-trip test.
- Upgrades apply at run start.
- Seeds are awarded at run end.
- Discoveries are saved immediately.

### Task 9: Balance sim and tuning
- `tools/balance_sim.gd` runs the real systems headless at 4× steps with a scripted AI (it learns and slots a reasonable build), then prints level at 5/10/15/20 min and the boss kill times.
- Tune the XP curve and mid-boss HP (the user's fixed numbers stay) until the level at 20:00 is about 34 and the final boss dies in about 60–120 s.

### Task 10: Final verification
- Full test suite green.
- `spell_report.py` green.
- Manual checklist from spec §14.
