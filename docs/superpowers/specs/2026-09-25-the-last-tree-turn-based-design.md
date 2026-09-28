> **SUPERSEDED** by `2026-09-27-the-last-tree-chant-design.md` (chant patterns, encounters).

# The Last Tree — Turn-Based Design (v2)

**Date:** 2026-09-25. **Replaces** the real-time design (`2026-09-25-the-last-tree-design.md`) for everything about the run. The element system, recipe rules, spell data model and meta idea carry over.
**Engine:** Godot 4.6.2, GDScript, 1920×1080 base.
**Removed:** real-time loop, element bar, pickups, the spirit character and its 6 spells, spell slots, auto-cast, Q–Y keys, cooldowns, tree levels, exponential power, magic elements, Roots upgrades.

---

## 1. Board
- The tree sits at the centre of a top-down board: tree radius 55 px, then three rings, each 125 px wide.

  | Ring | Range | Distance from centre |
  |---|---|---|
  | Inner | 1 | 55–180 px |
  | Middle | 2 | 180–305 px |
  | Outer | 3 | 305–430 px |

- Units (enemies, summons, the fairy) stand at **free positions**. Their ring is derived from their distance to the centre.
- **Distances in rings:** 1 ring = 125 px. A unit with speed 1 moves up to 125 px per turn, and range *r* reaches *r* × 125 px (centre to centre). A unit attacks the tree if its ring ≤ its range.
- Units push apart so they don't overlap.

## 2. Turn order
1. **Player phase.** Income has arrived and intentions for the next round are shown. The player selects elements and queues spells (targeting when needed), then presses **End Turn**.
2. **Resolve the queue** top to bottom (with animation).
3. **Enemy phase.**
   - Damage over time ticks.
   - Each enemy follows its intention: it moves toward its target, then attacks if the target is in range. If it can't reach, it only moves.
   - If the intended target died or moved, the enemy retargets.
4. **Summon phase.** The same rules, for summons.
5. **Round end.**
   - Zones, traps, mines and auras tick.
   - The turn number goes up, and the wave and bosses enter at the outer ring. Fairy events happen here.
   - Income is granted, buff and status turns tick down, next turn's income is rolled, and all intentions are computed and shown.

**Aggro:** an enemy targets whatever is nearest among the tree (distance to its edge), summons and the fairy. **All summons draw aggro.**

**Intentions** show as icons above each unit (move, attack with its damage number, heal, shield). Hovering a unit draws a line to its target and shows a tooltip with HP, statuses and intention.

## 3. Elements and income
- Each run draws **4 random elements** out of 6. Only spells made purely of those elements exist that run.
- **Start:** 5 random fragments (of the run's 4 elements). **Base income:** +3 random fragments per turn.
- The **Income box** (top right) shows exactly what arrives next turn. Random income is pre-rolled, so it's shown as real elements.
- **Clicking the Income box** expands it. It lists every source (base, each growth effect with the turns it has left or "permanent", and artifacts) and the total per element. Random income is shown as a **rainbow "?"** symbol.
- **Queueing** a spell deducts its elements immediately. **Cancelling** it (the ✕ on the entry, or "Cancel all") refunds them.

## 4. Spells
- **Basic spells:** 3 generic spells. Each costs **any 2 of the same element**:
  - **Basic Offense:** 12 damage to a targeted enemy (range 3).
  - **Basic Defense:** a shield of 8 on a targeted ally for 1 turn.
  - **Basic Growth:** +1 of a random element per turn for 3 turns.
- **Mixed spells:** 132 in total (the 120 originals plus 12 summons; the 6 spirit spells were removed), plus the new tier-4 shield summon, **Aegis Sprite**. Tier = elements − 1.
- **Efficiency** is back to **1.0 / 1.3 / 1.45 / 1.6 / 1.75 / 1.9** for 1–6 elements.
- Durations are in **turns** and damage over time is **per turn**.
- **Targeting:**
  - Offensive spells and most defensive spells are aimed when queued, as follows:

    | Aim | Spells | How to target |
    |---|---|---|
    | enemy | single, multi, chain, Basic Offense | click an enemy |
    | point | burst, ball, star, heart, rain, zone, tornado, traps/mines; summon placement | click a spot within the spell's range |
    | direction | line, beams, cone, crescent (cast from the tree) | click to aim |
    | ally | shields, heals, regen, armor, Basic Defense | click the tree, a summon or the fairy |
    | none | rings and orbits around the tree; tree-only effects such as auras; **growth** | no targeting |

  - While aiming, a preview follows the cursor. Left-click confirms. Right-click or Esc cancels, and the elements stay unspent.
- **Range and preferred ring:** each offensive spell has a max range and a preferred ring. A hit on an enemy in the preferred ring deals **×1.5**, one ring away ×1.0, two rings away ×0.6.

  | Shape | Preferred ring |
  |---|---|
  | Cone, crescent, ring, spiral, orbit | inner |
  | Line, multi-line, burst, ball, star, heart, rain, zone, tornado, multi, chain | middle |
  | Single-target | outer |

- **Status effects in turns:**
  - Burn and poison deal damage per turn.
  - Slow gives −1 movement.
  - Stun means no move and no action.
  - A confused enemy moves randomly and doesn't attack.
  - A charmed enemy attacks the nearest other enemy.
  - Vulnerable, weaken and blind work as before, measured in turns.
  - Push and knockback move enemies outward by whole rings.
  - Teleport sends an enemy to the outer ring.
- **Growth spells** add income that lasts 1 turn, several turns, or is permanent, depending on tier. They always return more elements than they cost. Some also give a timed buff (damage, healing, crit, free-cast chance, duration), and buffs show as icons under the tree's HP with hover tooltips.
- **Summons** have HP and speed 1, and most are melee.
  - Each one attacks the nearest enemy, or heals or shields the nearest wounded ally.
  - You can steer one: **left-click it, then right-click a target** to override its target.
  - Summons act after enemies. They last N turns, and their HP bars and intentions are visible.
  - **Aegis Sprite (new, tier 4):** gives nearby allies a shield that blocks one hit.
- **Icons:** each spell has its own icon (element wedges plus a glyph), with a type badge in the top-left corner: **red sword** for offense, **blue shield** for defense, **green up-arrow** for growth.

## 5. Interface
| Area | Contents |
|---|---|
| Top-left | Tree HP and shield bar, "Turn N / 30", next boss, buff icons (with hover tooltips) |
| Top-right | Income box (click to expand the breakdown) |
| Centre-left | Board (rings, tree, units, intentions) |
| Right | **Scroll/parchment**. **Top half: the queue**, with ✕ per entry and **Cancel all**. **Bottom half: castable spells**, listing spells you know that fit the current selection and that you can afford. Clicking one fills the mixer with its recipe. |
| Under the scroll | **End Turn** |
| Bottom-centre | **Mixer**: 6 sockets plus **Cast** and **Clear**. **Resources row** underneath. Left-click an element to add it to the mixer; right-click an element (in the resources row or the mixer) to remove one. |
| Bottom-left | Spellbook button and the list of owned artifacts |

- **Cast** with a known recipe queues the spell, entering targeting first if the spell needs it. If the mixer holds a pair of the same element, a popup asks which basic to cast: Offense, Defense or Growth.
- **Blind mix:** Cast with an unknown recipe shows "Blind mixing is dangerous. If the elements don't bind, they are lost. Are you sure?" with a **Don't show this again** checkbox.
  - **Success:** the spell is unlocked permanently, the discovery cutscene plays, and the spell is queued (with targeting if needed).
  - **Failure:** the elements are consumed.

## 6. Run
- The run lasts 30 turns. **Bosses** arrive on turn 10 (Woodcutter), turn 20 (Blightmother) and turn 30 (The Last Winter).
- You **win** when the final boss dies. You **lose** when the tree's HP reaches 0.
- Every enemy wave enters at the outer ring. Wave size and the enemy mix grow with the turn number.

| Enemy | HP | Damage | Speed | Range | From turn |
|---|---|---|---|---|---|
| Gnawer | 10 | 1 | 1 | 1 | 1 |
| Skitter | 6 | 1 | 2 | 1 | 3 |
| Spitter | 14 | 2 | 1 | 2 | 5 |
| Brute | 40 | 4 | 1 | 1 | 7 |
| Splitter (splits into 2 Gnawers on death) | 25 | 2 | 1 | 1 | 12 |
| Lobber | 12 | 2 | 1 | 3 | 15 |
| Warden (15 barrier, regenerates after an untouched turn) | 20 | 2 | 1 | 1 | 17 |

- **Wave size:** 2 on turn 1, 3 on turn 2, then +1 every 3 turns (12 by turn 29).
- **Scaling:** HP × (1 + 0.035·(turn−1)); damage × (1 + 0.03·(turn−1)), rounded.
- **Bosses** (tuned by `tools/balance_sim.gd`):

  | Boss | HP | Damage | Range | Special |
  |---|---|---|---|---|
  | Woodcutter | 110 | 5 | 1 | throws an axe (range 3) every other turn |
  | Blightmother | 450 | 8 | 1 | halves healing near the tree; births 2 Splitters every 2 turns |
  | The Last Winter | 1,200 | 12 | 2 | calls a wave at 66% and 33% HP; freezes 2 of your elements (unusable) for a turn every 3 turns |

- **Fairy:** appears twice per run, on random turns between 4 and 26, at the outer ring.
  - She walks 1 ring per turn toward the tree and draws aggro from anything closer to her than to the tree.
  - A magic shield blocks the first hit; the next hit kills her. Your shields and heals work on her.
  - If she reaches the tree, you choose 1 of 3 artifacts.
- **Artifacts** last one run. Each boss kill offers a choice of 3 from your **unlocked pool**. There are 20 artifacts, and 12 are unlocked from the start.
- **Score → Seedlings** (score ÷ 100):

  | Source | Points |
  |---|---|
  | Kill | as before |
  | Boss | 250 / 750 / 2,000 |
  | Each turn survived | 20 |
  | Discovery | 300 |
  | Fairy saved | 150 |
  | Victory | 3,000 |

## 7. Meta
- **Starter book:** 18 mixed spells, 6 per category, tiers 1–3, with each element appearing equally often.
- **Seedlings** unlock spells at 10 / 20 / 35 / 55 / 80 by tier. In the shop, a locked spell shows its name, tier and effects but **not its recipe**. Blind mixing unlocks spells for free.
- **Seedlings** also unlock artifacts into the pool, for 25–60 each.
- The **Spellbook** shows known spells in full and unknown ones as "?". Spells whose elements aren't in the current run are greyed out.

## 8. Balance sim results (tools/balance_sim.gd, scripted player)
| Profile | Result over 10 seeds |
|---|---|
| New player (starter book only) | 0 wins. Dies around turn 10–11, before the Woodcutter. |
| Veteran (every spell known) | 0 wins. Average end turn 17.8 (range 11–32). |

These results are with 5 starting fragments and waves of 2, 3, then +1 every 3 turns (the user's playtest found the old opening too easy). With the previous settings (16 fragments, +1 every 5 turns) the veteran won 5 of 10 runs.

The scripted player leans on Basic Offense and places area spells naively, so a human should do better. The element draw causes large swings between runs.
