# The Last Tree — Chant Design (v3)

**Date:** 2026-09-27. **Replaces** the turn-based ring design. The spirit, rings, range, scroll, mixer, summons and the 133-spell data are gone. The old spells are archived in `data/archive/`.
**Engine:** Godot 4.6, landscape 1920×1080. **References:** Dicey Elementalist (card layout, first-person fights), Darkest Dungeon and Slay the Spire (runs on a map of encounters).

## 1. Elements and the chant
- There are **3 elements: Fire (F), Water (W) and Wind (A).**
- **A fight starts with 5 random elements; each turn adds 3 more.** Unused elements are stored for later turns in the same fight. Your stock empties when a fight ends.
- Draws are random, but **next turn's 3 elements are shown in advance** in the **Coming next** box at the top right.
- **The chanting area** is a line of up to **8 slots.** Click an element in your stock to add it to the next slot, right-click a slot to take it back, and drag to reorder.
- You cast **one chant per turn.** Casting uses up every element in the chant, then the enemies act.

## 2. Resolving a cast
1. **The chant strikes first.** Each enemy loses the **longest start of its HP that appears unbroken anywhere in the chant.**
   - *Example:* enemies F F W and F W E are both killed by the chant F F W E (the second enemy by the F W E it contains). The chant F W leaves the first enemy with F W and the second with E.
   - **Armoured** elements count toward the match but aren't removed this turn. *Example:* F (F) W struck by F F W leaves F.
   - **Exposed** enemies also lose their rightmost element when struck.
   - Enemies that went **Ethereal** as their intent can't be struck.
2. **Then spells fire.** Each active spell fires **once per non-overlapping occurrence** of its pattern in the chant, in the order the matches appear, left to right.
   - Targeted spells ask for a target as they resolve. **Tab** cycles through enemies (starting from the leftmost), and click or Enter confirms.
   - **Amplify n:** every enemy the chant hit this turn loses n more elements from the right.
   - **Echo:** after your spells, the chant strikes again.
3. An enemy with no elements left dies.

**Live preview while you build the chant:**
- elements the strike would remove fade to 30%
- a skull marks enemies that would die
- spell cards light up with ×N

## 3. Spells (`data/spells.json`, 100 spells, 16 of them Powers)
- A spell is a **pattern of 1–5 elements** (any of the three) plus a list of effects. The pattern length gives its rarity:

  | Length | Rarity | Spells |
  |---|---|---|
  | 1 | Common | 15 |
  | 2 | Common | 37 |
  | 3 | Uncommon | 30 |
  | 4 | Rare | 13 |
  | 5 | Legendary | 5 |

- **Starters:**
  - **Fire Ball** (F F): remove the target's rightmost element.
  - **Water Wall** (W W): gain 4 Shield.
  - **Tailwind** (A A): +1 random element next turn.
  - **Gust** (A F): move the target's first element to the end.
- The **spellbook** has no size limit, but only **6 spells are active.** You change the active six on the map, between fights.
- **Effect operations:**

  | Group | Operations |
  |---|---|
  | Remove elements | strike (from left or right, n, optional conditions), purge (up to 2 of one element from one enemy) |
  | Reshape HP | convert (first, last, or all of one element), rotate, swap, shatter armour |
  | Statuses | burn, poison, stoke, weaken, freeze, expose, ethereal |
  | Protect yourself | shield, heal, aegis, thorns |
  | Economy | draw (now or next turn, a specific or random element), retain, overload, cleanse |
  | Chant modifiers | amplify, echo |

- **Keywords** (see `docs/spell-list.md`):
  - **Burn N** stacks. At the start of its turn, the enemy loses its **first** element, then Burn goes down by 1.
  - **Poison N** works the same way from the back: the enemy loses its **last** element.
  - **Weaken** means the enemy deals 50% less damage.
  - **Freeze** means the enemy skips its next action.
  - **Expose** means the next time your chant strikes this enemy, it also loses its rightmost element.
  - **Ethereal**, on you: no damage from attacks this turn. On an enemy (from your spell): your spells remove double from it this turn. As an enemy intent: your next chant can't touch it, but spells still remove double.

### 3.1 Powers (like Slay the Spire)
A **Power** fires once, then **leaves your active row for the rest of the fight**. Its slot stays empty, and it's back next fight. Its effect lasts the whole fight:
- **Buffs for you:** passives (Burn bonus, Thorns, poison or burn on every chant strike, echo the first spell each turn, Attunement, +2 chant slots, +1 on spell removals) and start-of-turn effects (draws, Shield, conjured Wind, heal).
- **Curses on enemies:** can never mend, permanently Exposed, or every enemy deals 25% less damage.

### 3.2 Cures, conjured elements and other tools
- **Cures:** Clear Sight (Blind), Bandage (Bleed), Steady Mind (Confuse), Unbind (Silence), Purify (everything except Locks) and **Unshackle** (breaks one Lock; rare).
- **Conjured elements** arrive next turn with a ghostly look and vanish at the end of that turn if unused.
- **Siphon:** take an enemy's first elements into your stock.
- **Execute:** destroy an enemy with that many elements or fewer.
- **Graft:** insert an element at an enemy's front to set up a match.
- **Transmute:** turn your stored elements into another element.
- **Blood Price:** pay HP for elements.
- **Mimic:** repeat the previous spell that fired.

## 4. You
- You have **40 HP**, which carries between fights (rest sites heal).
- **Shield** lasts until your next turn. **Aegis** blocks one hit completely.
- Enemy **curses** can freeze stored elements (unusable for a turn) or hit you with effect damage.

## 5. Enemies (first draft)
Each enemy has an **HP bar of elements**, shows its **intent** for its next action, and may have a **passive**.

**Intents and abilities:**
- **Attack** N, or multi-hit N×k.
- **Armour** one element: it can't be removed this turn, but still counts for matching.
- **Mend:** regrow an element on itself, or on **another enemy** (healers).
- **Shuffle:** rotate its own HP.
- **Silence:** one of your spells is disabled for 2 turns (greyed out with a timer). Unbind cures it.
- **Lock:** permanent. A padlock with **2 symbols** (bosses: **3**) covers one of your spells. **Break it by chanting those symbols unbroken, in order.** Those elements still count toward the strike and your spells. Unshackle also breaks one.
- **Steal** (rare): takes 1–2 elements from your stock and **adds them to its own HP bar**. You get them back by chanting them off (Siphon returns them to your stock).
- **Confuse** (on you): this turn your chant is read **right to left**, and the live preview (fading, skull, spell glow) is **off**.
- **Blind** (on you): some enemy HP elements show as **?** for a few turns.
- **Bleed** (on you): lose N HP at the start of your turn, then Bleed goes down by 1.
- **Freeze elements:** 1–2 of your stored elements can't be used next turn.
- **Ethereal:** your next chant can't touch it (spells still remove double).
- **Empower:** +1 damage. **Call** a minion (bosses).

**More enemy ideas (to pick from):**
- **Splitter:** when struck but not killed, it splits its remaining HP into two smaller enemies.
- **Overgrowth:** if not struck this turn, it regrows an element, which pushes you to hit everything.
- **Mimic:** its HP rewrites itself into your last chant, reversed.
- **Toll Keeper:** your chant line has 2 fewer slots next turn.
- **Inverter:** swaps Fire and Water in your stock.
- **Warded:** can only be struck by chants of 4+ elements.
- **Last Gasp:** when it dies, you get Bleed 2.
- **Hexer:** marks one of your stored elements; chanting it costs 2 HP.
- **Echo Wraith:** repeats its previous intent twice in a row.

| Enemy | HP | Pattern of actions | Passive |
|---|---|---|---|
| Ashling | F F W | attack 3 | – |
| Puddle Slime | W W | attack 2 / regrow W | – |
| Gale Sprite | A F | attack 2×2 | – |
| Cinder Hound | F F F | attack 4 | Burning Hide: you take 1 when your chant strikes it |
| Stone Knight | F F W | armour 2nd / attack 5 | – |
| Tidecaller | W A W A | regrow W / attack 3 | – |
| Mirror Wisp | A W F | shuffle + attack 2 | – |
| Frost Hex | W W A | curse / attack 2 | – |
| **Gem King** (elite) | F W A W F | attack 4 / armour first | Gem Crown: armours its first element at the end of every turn in which it has no armour |
| **Storm Rider** (elite) | A A F A A | attack 3×2 / shuffle | – |
| **The Woodcutter** (boss) | 10 elements (F, W, A mix) | attack 6 / regrow 2 / armour / call a minion | phase change at half HP |

Scaling: deeper floors add 1 element to HP bars every few floors, and attack values rise by +1 every 4 floors.

## 6. Run
- A **branching map** of 12 floors plus a boss. Node types:

  | Node | Share of the map |
  |---|---|
  | fight | 55% |
  | elite | 15% |
  | rest (heal 30%, or change spells) | 15% |
  | treasure (an artifact) | 10% |
  | event | 5% (later) |

- **After a fight:** choose 1 of 3 spells from the unlocked pool (weighted by rarity) or skip. Elites also give an artifact.
- **Win** by defeating the boss. **Lose** when your HP reaches 0.
- **Seedlings** come from floors cleared, elites, the boss and new spells picked.

## 7. Meta
- Seedlings **unlock spells and artifacts** into the reward pools. A new save starts with the 4 starters plus about 24 common and uncommon spells unlocked.
- Playable characters will come later.

## 8. Code plan
- **Kept:** `ui_theme`, `toasts`, `vfx`, `save_manager` (adapted), `SpellMath` (only element names are still used), and the test runner and tools.
- **New pure logic, unit tested:**
  - `chant.gd`: matching, pattern occurrence counting, preview
  - `enemy_hp.gd`: element bar, armour, strike, convert, rotate
  - spell resolution
  - `draw_pool.gd`: element stock, draws, freezes
  - the map generator
  - enemy definitions and intents
- **New scenes:** map, fight (first-person enemy row, spell cards, chant line, stock, player bar), reward screen, rest, spellbook and loadout.
