> **SUPERSEDED** by `2026-09-25-the-last-tree-turn-based-design.md` (the game is now turn-based). Kept for the element, recipe and spell-balance rules it defines.

# The Last Tree — Design Spec

**Date:** 2026-09-25
**Engine:** Godot 4.6.2 (GDScript), `C:\Tools\Godot\godot.exe`
**Target:** Desktop, 1920×1080 base, scales with window (canvas_items stretch, keep aspect)
**Visual style:** Stylized vector + particles, all drawn in code (`_draw()`, `CPUParticles2D`, shaders optional). No sprite assets.
**Spell data:** `data/spells.json` is the single source of truth. `tools/spell_report.py` validates it and generates `docs/spell-list.md` and the spreadsheet `docs/spells.xlsx`.

---

## 1. Core loop

A tree stands at the centre of a top-down 360° arena. Hordes come in from every edge. The tree produces elements on its own, and the player's only jobs are **economy and build decisions**:

1. Assign spells to **spell slots**. Slots cast by themselves on cooldown and use elements.
2. Discover new spells by combining elements in the **mixer**.
3. Balance offense, defense and growth. Growth levels up the tree, which gives more HP, faster element production and **magic elements**.

A run lasts **20 minutes** of game time. Bosses come at 5, 10 and 15 minutes, and the final boss at 20. Killing the final boss is a **victory**. The tree's HP reaching 0 is a **defeat**. Either way you get a score, which converts into **Seeds** for permanent upgrades.

**Space** pauses and unpauses at any time. While paused, the player **can** still drag elements into the mixer, mix, and assign slots (planning is allowed; nothing casts).

## 2. Elements

Six basic elements: 🔥 Fire (F), 💧 Water (W), 🪨 Earth (E), 🌪️ Air (A), ☀️ Light (L), 🌑 Dark (D).

### 2.1 Spawn bar (top right)
- A horizontal bar fills over the **spawn interval**. When it's full, **3 elements** are rolled at random from the current odds. Their icons pop out at the end of the bar and fly into the resources panel.
- Base interval **15 s** (user decision), multiplied by 0.96 per tree level above 1, floored at 5 s. The first set arrives after 5 s. Buffs (`spawn`) and meta upgrades reduce it further.
- **Each fragment is worth 3** of its element when picked up. Growth buffs can make a fragment worth more (§5.4).
- Each element is capped at 99.

### 2.1b Collecting elements (the spirit)
- Produced elements do **not** go straight into the resources panel. Each one **flies out of the tree** (0.6 s arc) and lands 90–300 px away.
- The player controls the **tree's spirit**: **right-click** moves it there, and **holding right-click** makes it follow the cursor. It moves at 330 px/s and collects any landed element within 34 px. A collected element flies into the resources panel.
- Uncollected elements blink for their last 5 s and fade after **30 s**.
- Enemies ignore the spirit (it can't be hurt).
- The balance sim drives the spirit with a nearest-element autopilot and keeps up at the late-game rate of about 6 elements/s.

### 2.2 Odds and affinity
All odds start at 1/6. Affinity table (symmetric):

| Element | Close | Far | Opposite |
|---|---|---|---|
| Light | Fire, Water | Earth, Air | Dark |
| Dark | Earth, Air | Fire, Water | Light |
| Fire | Light, Air | Earth, Dark | Water |
| Water | Light, Earth | Air, Dark | Fire |
| Earth | Water, Dark | Fire, Light | Air |
| Air | Fire, Dark | Water, Light | Earth |

**Odds shift: DISABLED for now** (user decision after the balance sims). Odds stay at 1/6 each, changed only by `elem_rate` buffs. The rule below is kept in code (`ElementOdds.apply_level`, with its tests) but is not called.

~~**Odds shift:**~~ growth XP is tagged by element. A basic growth spell gives all its XP to its element, and a mixed growth spell splits its XP evenly across the recipe's elements (so FFFL gives ¾ Fire and ¼ Light). **On every tree level-up**, each element's share of the XP for that level scales a shift of **+10% self, +5% each close, −5% each far, −10% opposite** (absolute percentage points). The shift is zero-sum per element, so the total stays at 100%. After a shift, every element is floored at **3%** and the odds are renormalised. The resources panel shows the current odds under each element.

*Example:* a level earned 100% from Fire moves Fire +10, Light +5, Air +5, Earth −5, Dark −5, Water −10.

## 3. The Tree

| Stat | Value |
|---|---|
| Max HP | **100** × 1.1^(level − 1), compounding (≈260 at Lv 11, 610 at Lv 20, 2,300 at Lv 34), plus permanent bonuses from growth spells and meta |
| XP to next level | 20 + 8 × current level |
| Magic element | +1 every 5 levels (levels 5, 10, 15, …) |
| **Power** | **P = 1.2^(level − 1)**, compounding (Lv 10 ≈ 5.2×, Lv 20 ≈ 32×, Lv 30 ≈ 198×, Lv 35 ≈ 493×) |

- The tree has no attack of its own. Every effect comes from slots.
- Damage taken is reduced by armor (%), then absorbed by the shield, then taken from HP.

### 3.1 Exponential power growth
The game grows in big numbers, like an incremental game. The final boss has **5,000,000 HP**.
- **Everything that deals damage** is multiplied by **P**: hit damage, burn, poison, zones, tornadoes, orbits and thorns. It's then multiplied by `dmg` buffs, vulnerable and crit.
- **Everything that restores the tree** (heal, regen, shield, lifesteal) is multiplied by **maxHP / 100** instead of P, so defensive spells keep pace with the tree's own HP rather than exploding. Lifesteal is calculated on damage *before* P, then scaled like a heal.
- Spell data stores **base values** (level 1, 100 HP tree). The spellbook shows the base values and the current scaled values side by side.
- Big numbers are displayed abbreviated (12.4K, 3.1M).
- Intended curve: about level 10 at 5:00, 18 at 10:00, 26 at 15:00 and 34 or more at 20:00 for a player investing steadily in growth. Skipping growth leaves you far behind the enemy HP curve. That's the core tension.
- **Balance sim results** (`tools/balance_sim.gd`, a scripted player using mostly basic spells): a balanced-growth player reaches Lv 17 at 5:00, 26 at 10:00, 31 at 15:00 and 35 at 18:00, and beats the first three bosses. A single-element player dies around 9:00. The final-boss check (`tools/boss_check.gd`, strong endgame build) kills the Last Winter in about 40 s at Lv 30 and 20 s at Lv 34.

## 4. Spell slots (bottom left)

**Slots auto-cast by default.** Pause (Space) and **right-click a slot** to switch it to **manual**. Manual slots are cast with **Q W E R T Y** (slots 1–6, left to right), so there are at most 6 slots. A key press casts if the slot is off cooldown, the recipe is affordable, and there is something to act on. Otherwise missing elements flash red, or "no target" appears.
Auto slots use the contingency and targeting rules below (§4.1 and §6). Manual slots show "MANUAL" and cast on the key press. The "+ slot" button sits above the row.

- A run starts with **3 slots**. A "+" button buys another slot for **2 magic elements**, then 3, 4, and so on (no hard cap; the UI allows up to 8).
- **Clicking a slot** opens a short vertical menu: *Offensive / Defensive / Growth / (Clear)*. Choosing a category opens the **spellbook on that tab**, showing the 6 basic spells plus any mixed spells learned **this run**. Clicking one assigns it.
- **Basic elements** can go in any category (each element has one basic spell per category, 18 in total). **Mixed spells** can only go in their own category.
- The same spell may occupy more than one slot.
- Each slot shows the spell's icon, a radial cooldown sweep and the recipe cost.

### 4.1 Casting rules
When a slot's cooldown is ready, it checks, in order:
1. **Contingency:** the spell's `should_cast` rule (§6) must pass. If it doesn't, the slot waits quietly, with no blink and no cost.
2. **Cost:** the tree must hold the full recipe. If it doesn't, the slot **blinks red**, the missing element icons in the resources panel blink red, and the slot re-checks every frame (it doesn't cast partially). Checking the contingency first means red only ever means "I want to cast but can't afford it."
3. Cast: the cost is deducted (unless a `refund` roll succeeds), the effect executes, and the cooldown restarts.

When several slots are ready in the same frame, **lower slot index goes first** (slot 1 has priority). The player can reorder priority by dragging slots.

## 4.2 Tiers
Spells are **tiered by recipe size**: Basic = 1 element, then **Tier 1–5 = 2–6 elements**. The spellbook groups each category by tier.

## 5. Spell model (Approach A: data-driven effect modules)

Every spell, basic and mixed, is one JSON entry: `id, name, recipe, cat, cd_mult?, flavor, effects`. There is no per-spell code. The engine carries a fixed set of effect modules, and each spell is a combination of them.

### 5.1 Derived values
- **Cooldown** = `BASE_CD[size] × average(SPEED[element]) × cd_mult`
  - BASE_CD: 1→2.0, 2→3.5, 3→5.0, 4→6.5, 5→8.0, 6→10.0 s
  - SPEED: Air 0.7, Fire 0.8, Light 1.0, Dark 1.0, Water 1.2, Earth 1.35 (lower is faster)
- **Cost per cast** = the recipe.
- **Power budget** (efficiency guide for balancing, and the growth XP per cast) = `10 × size × EFF[size]`, where EFF is **1.0 / 1.4 / 1.8 / 2.2 / 2.6 / 3.0** for 1–6 elements. Bigger recipes are much more efficient per element: a 6-element spell is worth 3× its cost in basic casts. Spell flat values (damage, DoT, heal, shield, regen, thorns, max HP) are authored in line with this curve.
- **Element balance rule:** across all 120 recipes, each element makes up 16.7% ± 0.5% of recipe slots. Within each category, every element stays between **8% and 25%** of that category's recipe slots, so categories may lean on an element (Fire and Air in Offense, Water and Dark in Defense) but never monopolise or abandon it. `spell_report.py` prints this breakdown and fails if either rule breaks.

### 5.2 Offensive modules
`shape` (required), which decides who gets hit:

| type | params | behavior |
|---|---|---|
| single | – | one target |
| multi | count | N distinct targets hit directly (no area) |
| ball | radius | projectile flies to a point and explodes |
| circle | radius | instant burst at a point |
| line | width, length | beam from the tree, pierces |
| multiline | count, spread, width, length | N beams fanned over `spread` degrees |
| cone | angle, length | wedge from the tree |
| crescent | radius, angle | arc slash centred on the tree |
| star | points, length, width | N rays radiating from a point |
| heart | size | heart-shaped burst at a point |
| ring | radius | expanding ring from the tree |
| chain | bounces, falloff | jumps between nearest enemies; damage × falloff each jump |
| rain | count, radius, area | N impacts scattered inside `area` around a point |
| tornado | radius, dur, speed | a moving zone that steers toward the densest enemies; `damage` is per second |
| zone | radius, dur | a stationary ground zone; `damage` is per second |
| spiral | arms, length, turns | rotating beams from the tree, sweeping `turns` rotations |
| orbit | count, radius, dur | orbs circling the tree; `damage` is per hit (0.5 s per-enemy hit cooldown) |

Modifiers: `damage`, `burn {dps,dur}` (refresh, keeps the higher), `poison {dps,dur,stacks}` (stacks up to N), `chill {pct,dur}` (slow applied on hit), `vulnerable {pct,dur}` (the target takes +pct damage from all sources, additive, capped at +100%), `weaken {pct,dur}` (the target deals −pct damage), `crit {chance,mult}`, `lifesteal` (% of damage dealt heals the tree), `bonus_boss` (+% vs bosses), `knockback` (px), `stun` (s), `pierce`,
`instakill` (chance per target hit to kill a non-boss outright; at most one roll per enemy per cast; Dark spells),
`combust` (fraction; applied **before** this spell's own burn: the target's current burn is removed and it immediately takes `combust × dps × remaining duration`; big Fire spells).
`activation` (optional, same as defense): `delayed {delay}` (a telegraphed impact), `mine {dur}` (placed on the best approach point; bursts once, with its shape, when an enemy enters; expires unused after `dur`), `trap {dur}` (a persistent zone in the shape; `damage` is per second, ticking every 0.5 s).

### 5.3 Defensive modules
`target` (required): `self`, or any area/targeting shape from 5.2: single, multi, circle, cone, line, crescent, star, ring, rain or heart.
Effects: `heal`, `regen {hps,dur}`, `shield {amount,dur}` (doesn't stack; takes the higher), `armor {pct,dur}`, `thorns {dmg,dur}` (hits each attacker), `slow {pct,dur}`, `stun` s, `confuse` s (the enemy wanders randomly), `charm` s (the enemy attacks the nearest other enemy, and other enemies may hit it back), `push` px (away from the tree), `teleport` (moved to a random point on the arena edge), `blind {pct,dur}` (attacks miss by pct), `weaken`.
`activation` (optional): `instant` (default), `delayed {delay}`, `trap {dur}` (a ground zone that applies its effects to every enemy inside, every 0.5 s), `aura {dur, radius}` (centred on the tree, pulses every 0.5 s).

### 5.4 Growth modules
Every growth cast gives **XP = power budget** (basic = 10), tagged by element for the odds shift.
`buff {dur, …}` stats, timed and refreshed on recast (same spell doesn't stack; different spells do):
`cd` (−% all cooldowns), `elem_cd {el: pct}` (−% cooldown on spells containing that element), `elem_rate {el: pct}` (+% weight on that element's spawn roll, applied on top of the odds), `spawn` (−% spawn interval), `double` (chance a spawned element counts twice), `dmg`, `heal` (+% healing and shields), `crit` (+crit chance for all offensive spells, including ones without a crit module, which use ×1.5), `xp` (+% growth XP), `refund` (chance a cast costs nothing), `duration` (+% to all timed effects the player applies).
**Every buff type exists in a general form, an element-specific form, or both on the same spell**, spread across the 40 growth spells so players can build around an element or around a stat:

| General | Element-specific | What the element version affects |
|---|---|---|
| `dmg` | `elem_dmg` | damage of spells containing the element |
| `cd` | `elem_cd` | cooldown of spells containing the element |
| `heal` | `elem_heal` | heals and shields from spells containing the element |
| `crit` | `elem_crit` | crit chance of spells containing the element |
| `refund` | `elem_refund` | free-cast chance of spells containing the element |
| `duration` | `elem_duration` | timed effects of spells containing the element |
| `spawn` | `elem_rate` | spawn roll weight for that element |
| `xp` | `elem_xp` | growth XP from growth casts containing the element |

Every family has at least one general-only, one element-only and one "both" spell, and damage, cooldown and production buffs exist for all six elements (checked by the generation script).
**Share rule:** an element-specific bonus applies to a spell in proportion to that element's share of the spell's recipe. For example, `elem_dmg {F: 0.20}` gives Fire, Fire, Fire, Water +15% and a basic Fire spell +20%.
General and element-specific bonuses add together, except cooldown, where the general and element reductions multiply: (1 − cd) × (1 − share-weighted elem_cd), floored at 0.2.
**Fragment bonus (every growth spell):** a chance that a picked-up fragment is worth extra, scaled by tier (t = 1–5):
- **Any element:** (4% + 2%·t) chance for +t.
- **Certain element** (the recipe's dominant element): (8% + 4%·t) chance for +t.
- Spells that used to have double-spawn stats get ×1.5 chances.
- Basic growth spells: 10% chance for +1 on their own element.
- Every active buff rolls independently when a fragment is collected.

**Basic growth spells** (1 element) give 10 XP plus a small buff that suits the element, lasting 10 s and refreshing on recast:
- Fire: +5% damage
- Water: +10% healing
- Earth: +1 permanent max HP
- Air: −5% cooldowns
- Light: +10% growth XP
- Dark: 5% free-cast chance
`perm {maxhp}`: permanent max HP added on every cast (the current HP rises by the same amount).

### 5.5 Status rules
- **Bosses** are immune to charm, confuse and teleport. Stun and slow durations are halved on them. Push and knockback are ×0.25.
- Slow effects don't stack. The strongest active one applies, with a cap of 80%.
- Charmed enemies don't damage the tree and are ignored by the tree's own offensive targeting. They attack the nearest other enemy once per second for 25% of their own max HP.

### 5.5b Summons (18 new spells added 2026-09-25; 138 mixed spells in total)
The `summon` module: `{role, look, count, hp, dur, speed, taunt, atk{interval, damage, range, radius, cone, targets, burn, slow, stun, vulnerable, instakill}, heal, push, rebirth}`.
- **HP** scales like heals (× tree max HP / 100 × healing buffs). **Attacks** use the spell's power and damage mods.
- **Taunt:** an enemy within `taunt` of a summon attacks that summon instead of the tree (this applies to bosses too). Summons with taunt 0 never draw aggro.

| Role | Behaviour | Inspiration |
|---|---|---|
| fighter | hunts enemies within 480 px of the tree | Kingdom Rush barracks/reinforcements |
| stalker | hunts the lowest-HP enemy, never taunts | Dota/WC3 assassins |
| ranged | circles the tree at 120 px and shoots (optionally a cone breath) | Bloons monkeys, WC3 Wisps |
| healer | heals the tree and summons each second | Dota/WC3 healing wards |
| blocker | holds the busiest approach, slams everything in range | Kingdom Rush soldiers, WC3 Treants |
| pusher | circles the tree at 170 px, knocking enemies back | Bloons "Tornado" |
| grabber | seizes up to N nearby enemies (damage + stun) | Dota Kraken / Tidehunter |
| bomber | runs into the densest cluster and explodes | PvZ Cherry Bomb, WC3 Goblin Sappers |

`rebirth`: the summon revives once at full HP. Auto-cast doesn't resummon while this spell's summons are still out.

### 5.5c Spirit spells
The `spirit` module: `{dur, trail{life, radius, …}, aura{radius, …}, speed, magnet}`, applied to the player's spirit.
- **Trail:** leaves patches every 0.12 s while the spirit moves.
- **Aura:** pulses around the spirit.
- Both tick every 0.5 s. Damage parts are per second; crowd-control parts apply slow, confuse and so on.
- **Speed** multiplies movement speed, and **magnet** adds pickup radius.
- Inspirations: Vampire Survivors (Garlic aura, Wings, Attractorb), Hades (trail/Frost boons).

## 6. Smart targeting & contingencies

| Spell kind | should_cast | target choice |
|---|---|---|
| Offense (any) | at least 1 enemy alive and in range (arena) | see below |
| single | – | highest effective HP (current HP × (1 − vulnerable)); bosses first |
| multi | – | top-N by current HP |
| ball / circle / rain / heart / star / zone | – | sample candidate centres (every enemy position plus pairwise midpoints, capped at 64) and pick the one with the highest summed HP inside the shape |
| line / multiline / cone / crescent | – | sample 36 angles and pick the angle hitting the highest summed HP |
| ring / spiral / orbit | at least 3 enemies within radius (or any boss within radius) | the tree |
| chain | – | starts at the enemy nearest the tree |
| tornado | – | spawns at the densest cluster and re-steers every 0.5 s |
| Heal | missing HP ≥ 50% of the (buffed) heal amount | self |
| Regen | HP < 90% and the same regen isn't active | self |
| Shield / armor / thorns | an enemy is within 350 px and the current shield < 50% of this one | self |
| CC (slow/stun/confuse/charm/push/teleport/blind) | enemies inside the would-be area | threat score = damage × (1 + 600/distance); for multi, pick the top-N by threat; area shapes pick the placement with the highest summed threat; charm prefers high-damage enemies near other enemies |
| Trap | enemies within 500 px | the densest approach point, 150–400 px from the tree |
| Aura | enemies within the aura radius | self |
| Growth | always (when affordable) | – |

## 7. Mixer (bottom centre)

- **6 sockets** and **Mix** / **Clear** buttons. Magic elements are shown next to the Mix button.
- The player drags element icons from the resources panel into sockets, in any order. **The player must hold at least as many of that element as the mixer contains** (they are not consumed). Right-clicking a socket empties it.
- **Mix** is disabled with 0 magic elements or with fewer than 2 filled sockets.
- Recipe lookup uses a canonical key (sorted element letters).
  - **Match, not yet learned this run:** 1 magic element is spent, and the **learn cutscene** plays: the game pauses, a black veil at 75% covers the screen, the spell card pops in centre (icon, name, category, recipe), then shrinks and flies to the spellbook button at the bottom right, which pulses. The spell is added to this run's learned list and permanently recorded in the spellbook save.
  - **Match, already learned this run:** "Already known" toast, with no cost.
  - **No match:** a fizzle (smoke puff), a "The elements refuse to bind…" toast, and the **mixer locks for 5 s** (shown as a countdown on the Mix button). No cost.
- The sockets keep their contents after a mix (so you can re-mix quickly); Clear empties them.

## 8. Spellbook (bottom right button)

- A full-screen overlay (pauses the game when opened outside slot assignment). **3 tabs:** Offensive, Defensive, Growth. Each tab is a grid of 6 basic spells plus 40 mixed spells.
- Card states:
  - **Unknown** (never learned in any run): a "?" silhouette in the category colour, no info.
  - **Learned this run:** full colour, and hovering or clicking shows name, icon, recipe, cooldown, cost, effects and flavor.
  - **Learned in a past run only:** the full info shown **greyed out** (desaturated, "Not learned this run"). The recipe is visible, so the player can re-mix it.
- In **assignment mode** (opened from a slot) only full-colour cards are clickable.
- A counter reads "Discovered 37 / 120".

## 9. Enemies & director

### 9.1 Enemy types (vector shapes, colour-coded)
**All enemies attack once per second unless noted.** They damage the tree on contact (or with a projectile, for Spitters).

| Type | Base HP | Speed | Damage per attack | Unlocks | Notes |
|---|---|---|---|---|---|
| Gnawer (basic) | **10** | 60 | **1** | 0:00 | basic swarm |
| Skitter (fast) | 6 | 120 | 1 | 1:30 | |
| Brute | 60 | 35 | 4 | 3:00 | |
| Spitter (ranged) | 18 | 55 | 1 | 4:00 | stops at 260 px and shoots a projectile each attack |
| Splitter | 30 | 50 | 2 | 7:00 | splits into 3 Gnawers on death |
| Warden (shielded) | 25 | 45 | 2 | 11:00 | a barrier worth 40 × HP-scale that regenerates after 4 s out of combat |

**Scaling at t minutes (continuous):** HP × **1.34^t** (≈4.3× at 5:00, 19× at 10:00, 81× at 15:00, 260× at 19:00). Damage × (1 + 0.08·t) (2.5× at 19:00), rounded to one decimal place. Bosses use the fixed values below and do **not** get time scaling.
**Spawn rate:** 0.12 enemies/s at 0:00, curving up (exponent 1.4) to 1.0/s at 19:00 (≈0.26/s at 5:00, 0.48/s at 10:00, 0.75/s at 15:00). This was retuned for the 15 s element bar. Enemies are spawned in small groups (1–5) at random points on the arena edge. The type mix is weighted toward newer unlocks as time goes on.

### 9.2 Bosses
| Time | Boss | HP | Damage per attack (1/s) | Signature |
|---|---|---|---|---|
| 5:00 | **Woodcutter** | 5,000 | 8 | Slow; an axe throw at the tree every 6 s (8 dmg, range); calls 4 Skitters every 10 s |
| 10:00 | **Blightmother** | 60,000 | 15 | A poison aura shrinks the tree's regen/heal by 50% within 300 px; births Splitters |
| 15:00 | **Ashen Colossus** | 500,000 | 30 | Immune to burn; a stomp every 8 s knocks out the spawn bar progress |
| 20:00 | **The Last Winter** | **5,000,000** | **50** | 3 phases (100/66/33%); freezes a random slot for 5 s every 12 s; summons waves between phases |

Sized so that a player on the intended power curve (§3.1) kills each boss in about 30–90 s.

- When a boss spawns, normal spawning drops to 50% while it lives. The 20:00 boss **stops the timer**, and the run ends when it dies or the tree falls.
- A boss HP bar appears at the top centre.

## 10. Score, Seeds, permanent upgrades

### 10.1 Run score
| Source | Points |
|---|---|
| Kill | Gnawer/Skitter 1, Spitter 2, Splitter/Warden 3, Brute 5 |
| Boss kill | 250 / 500 / 750 / 2,000 |
| Time survived | 5 per second |
| Tree level reached | 25 per level |
| Spell learned this run | 100 each |
| **First-ever discovery** (new spellbook entry) | 300 each |
| Distinct spells cast this run | 50 each |
| Flawless boss (tree took no damage while that boss was alive) | +200 |
| Victory | +3,000 |

**Seeds earned = floor(score / 100)**, which gives about 100–200 Seeds for a strong winning run. Seeds persist between runs.

### 10.2 Meta shop (main menu → "Roots")
| Upgrade | Effect per rank | Ranks | Cost (per rank) |
|---|---|---|---|
| Deep Roots | +10% starting max HP | 5 | 20, 40, 60, 80, 100 |
| Fertile Soil | −4% spawn interval | 5 | 25, 50, 75, 100, 125 |
| Seed Pouch | start with +2 of each element | 3 | 15, 30, 45 |
| Old Wisdom | start with +1 magic element | 2 | 60, 120 |
| Fourth Branch | start with 4 slots | 1 | 150 |
| Quick Study | −1 s failed-mix lockout | 3 | 10, 20, 30 |
| Bark Skin | −5% damage taken | 3 | 30, 60, 90 |
| Keen Harvest | +10% Seeds earned | 3 | 40, 80, 120 |

## 11. Screen layout (1920×1080)

```
┌──────────────────────────────────────────────────────────────────────┐
│ [Tree HP ███ Lv 7 XP ▓▓░]     [ 12:34 ]        [spawn bar ▓▓▓▓░ 🔥💧☀️]│
│ ┌──────────┐                  [boss bar]                              │
│ │RESOURCES │                                                          │
│ │🔥 12 18% │                                                          │
│ │💧  4 15% │                     🌳 (tree, centre)                    │
│ │🪨  9 17% │                                                          │
│ │🌪️  7 16% │                                                          │
│ │☀️  3 20% │                                                          │
│ │🌑 11 14% │                                                          │
│ │✨ magic 1│                                                          │
│ └──────────┘                                                          │
│ [slot1][slot2][slot3][+2✨]    [ ◻ ◻ ◻ ◻ ◻ ◻  MIX  CLEAR ]     [📖]   │
└──────────────────────────────────────────────────────────────────────┘
```
The panels are semi-transparent overlays, and the arena spans the full screen behind them.

## 12. Persistence (`user://save.json`)
```json
{ "version": 1, "seeds": 0, "upgrades": {"deep_roots": 0, ...},
  "discovered": ["thermal_explosion", ...],
  "stats": {"runs": 0, "wins": 0, "best_score": 0, "best_time": 0} }
```
The file is written at run end and after each discovery (so a crash doesn't lose discoveries).

## 13. Architecture (Godot)

```
project.godot
data/spells.json
scenes/ main_menu.tscn, run.tscn, (ui sub-scenes)
scripts/
  autoload/ game_data.gd     – loads spells.json, canonical recipe index, derived cd/power
            save_manager.gd  – save/load user://save.json
            events.gd        – signal bus
  core/     element_bank.gd  – counts, odds, affinity shift, spawn bar timer
            tree_core.gd     – HP, shield, armor, level/XP, magic elements, buffs
            buff_state.gd    – aggregates active growth buffs into query functions
            spell_slot.gd    – cooldown, cost check, contingency, cast
            spell_executor.gd– turns an effects dict into hits/zones/statuses
            targeting.gd     – pure functions: pick target/point/angle for a shape
            shapes.gd        – pure geometry: is point inside shape X
            status.gd        – per-enemy status container (burn, poison, slow, …)
            enemy_director.gd– spawn schedule, scaling, bosses
            run_score.gd     – tallies score, computes seeds
  entities/ enemy.gd, boss.gd, projectile.gd, zone.gd, tornado.gd, orbit.gd
  vfx/      spell_vfx.gd (per-shape drawing), element_icons.gd (vector icons)
  ui/       resources_panel, spawn_bar, slot_bar, slot_menu, mixer, spellbook,
            learn_cutscene, hud, pause_overlay, end_screen, meta_shop
tests/      run_tests.gd (headless runner), test_*.gd
tools/      spell_report.py
```

**Boundaries:** `targeting.gd`, `shapes.gd`, the element odds maths, recipe lookup, the cooldown formula, XP/level curves and score are **pure functions** with no scene dependencies, so they are unit-tested headless. The UI talks to the core only through `events.gd` signals and public methods.

## 14. Testing
- **Headless unit tests** (`godot --headless -s tests/run_tests.gd`), a small custom runner with no addon: recipe canonicalisation and lookup, the affinity shift (zero-sum, 3% floor, renormalisation), the cooldown formula matching `spell_report.py`, the XP curve and magic element grants, slot costs (2, 3, 4…), targeting picks (single → highest HP, area → densest), heal contingency (the 50% rule), status stacking rules, and the score → Seeds conversion.
- **Data validation:** `python tools/spell_report.py` (uniqueness, size distribution, banned recipes, required modules) plus a Godot-side check that every effect key in the JSON is known to the executor.
- **Manual playtest checklist:** mix success/fail/lockout, cutscene, spellbook states across two runs, pause behaviour, boss spawns, victory/defeat, Seeds and shop.

## 15. Out of scope (for now)
Audio (hooks only, silent), controller support, localisation, difficulty settings, endless mode, achievements.
