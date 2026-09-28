# The Last Tree — Spell List (chant patterns)

Generated from `data/spells.json` by `tools/spell_report.py`. Edit the JSON, then re-run the script.

**106 spells.** Chant, then every spell whose pattern appears in the chant comes alive: one charge per separate match, but never more than its pattern's length. Cast them in any order; then the chant is Released and each enemy loses the longest start of its HP found in it. ★ = starter.

**Keywords**
- **Burn N:** at the start of its turn, the enemy loses its **first** (leftmost) element, then Burn goes down by 1.
- **Poison N:** like Burn, but the enemy loses its **last** (rightmost) element.
- **Weaken:** the enemy deals 50% less damage.
- **Freeze:** the enemy skips its next action.
- **Expose:** whenever your Release hits this enemy, it also loses its last (rightmost) element.
- **Ethereal (you):** take no damage from attacks this turn, but double damage from effects. **Ethereal (enemy):** your spells remove double from it this turn; enemies that go Ethereal as their intent can't be hit by your next Release.
- **Shield:** blocks damage until your next turn. **Aegis:** blocks one hit completely.
- **Thorns:** enemies that attack you lose their rightmost element.
- **Armour** (enemy ability): an armoured element can't be removed this turn, but it still counts for the chant's match.
- **Power:** cast once, then it leaves your active row (its slot stays empty) and its effect lasts the whole fight.
- **Conjured** elements arrive next turn and vanish at the end of that turn if unused.
- **Siphon:** take elements off an enemy's HP into your stock. **Execute:** destroy an enemy that is small enough.
- **Amplify:** enemies your chant hit lose extra elements. **Echo:** the chant strikes again after your spells. **Overload:** fewer elements next turn.

## 1-element patterns (15)

| Name | Pattern | Rarity | Category | Effect | Flavor |
|---|---|---|---|---|---|
| **Borrowed Breath** | 🌪️ | Common | Utility | +1 conjured Air next turn. | *A breath that isn't yours to keep.* |
| **Siphon** | 🌪️ | Rare | Offensive | Take the first 2 elements of the target; you get them next turn as conjured. | *Pull its first element into your hand.* |
| **Taint** | 🌪️ | Common | Offensive | Poison 1 on the target. | *Something foul rides the breeze.* |
| **Updraft** | 🌪️ | Common | Utility | Move 1 element of the target to any position you choose. | *Lift one element and set it down where you like.* |
| **Whisper** | 🌪️ | Common | Defensive | Weaken the target for 1 turn. | *A word in the ear, and its arm goes slack.* |
| **Cinder** | 🔥 | Common | Offensive | Expose the target for 1 turn. | *Glowing ash marks the weak spot.* |
| **Clear Sight** | 🔥 | Common | Defensive | Cure Blind. | *A flash of light burns the fog away.* |
| **Ember** | 🔥 | Common | Offensive | Burn 1 on the target. | *A single spark that won't go out.* |
| **Kindle** | 🔥 | Rare | Offensive | **Power** (leaves your active row for the rest of the fight): Your Burn applies +1 stack. | *Every fire you light burns a little longer.* |
| **Spark** | 🔥 | Common | Offensive | Deal 1 damage to the last HP of the target (only if it has 4+ elements). | *Only big things catch.* |
| **Bandage** | 💧 | Common | Defensive | Cure Bleed. | *Wash it, wrap it, keep going.* |
| **Chill** | 💧 | Common | Utility | Remove all Armour from the target. | *Cold makes armour brittle.* |
| **Droplet** | 💧 | Common | Defensive | Gain 2 Shield. | *Every drop helps.* |
| **Mist** | 💧 | Common | Defensive | Heal 1. | *Cool on the skin.* |
| **Ripple** | 💧 | Common | Utility | Turn the last element of the target into Water. | *The end of it turns to water.* |

## 2-element patterns (40)

| Name | Pattern | Rarity | Category | Effect | Flavor |
|---|---|---|---|---|---|
| **Cyclone** | 🌪️ 🌪️ | Common | Offensive | Deal 1 damage to the last HP of every enemy (only if it has 4+ elements). | *Shaves the big ones down to size.* |
| **Gale Barrier** | 🌪️ 🌪️ | Common | Defensive | Gain 3 Shield; Thorns 1 this turn. | *A wall of wind that bites back.* |
| **Miasma** | 🌪️ 🌪️ | Common | Offensive | Poison 2 on the target. | *A choking cloud settles on it.* |
| **Steady Mind** | 🌪️ 🌪️ | Common | Defensive | Cure Confuse; +1 Air next turn. | *Breathe in, breathe out.* |
| **Tailwind** ★ | 🌪️ 🌪️ | Common | Utility | +1 random element next turn. | *The wind brings more.* |
| **Alchemist's Breath** | 🌪️ 🔥 | Common | Utility | Turn 2 of your stored elements into Fire. | *Two of your stored elements become Fire.* |
| **Fan the Flames** | 🌪️ 🔥 | Common | Offensive | Double the Burn on the target. | *Double the fire already there.* |
| **Gust** ★ | 🌪️ 🔥 | Common | Offensive | Deal 1 Targeted damage to the target (you pick which element). | *A precise gust plucks one piece away.* |
| **Spring Word** | 🌪️ 🔥 | Common | Utility | Put a Water anywhere you like in this turn's chant. | *A word that wells up.* |
| **Rain** | 🌪️ 💧 | Common | Defensive | Heal 2. | *Soft and steady.* |
| **Refresh** | 🌪️ 💧 | Common | Defensive | Remove all your debuffs (frozen elements, Blind, Confuse, Bleed, Silence); +1 Water next turn. | *Wash the frost off.* |
| **Unbind** | 🌪️ 💧 | Common | Defensive | Cure Silence on all your spells. | *Your voice returns.* |
| **Blowtorch** | 🔥 🌪️ | Common | Offensive | Deal 1 damage to the last HP of the target (+1 if it is burning). | *Hotter where it's already burning.* |
| **Conjure Flame** | 🔥 🌪️ | Common | Utility | +2 conjured Fire next turn. | *Two flames, borrowed for a turn.* |
| **Phase Shift** | 🔥 🌪️ | Rare | Utility | Make the target Ethereal (your spells remove double from it this turn). | *Untouchable by chants, fragile to magic.* |
| **Thorn Mantle** | 🔥 🌪️ | Rare | Defensive | **Power** (leaves your active row for the rest of the fight): Thorns 1 for the rest of the fight. | *Anything that strikes you gets burned.* |
| **Wildfire** | 🔥 🌪️ | Common | Offensive | Burn 1 on every enemy. | *The wind spreads it everywhere.* |
| **Blood Price** | 🔥 🔥 | Rare | Utility | Lose 3 HP; +4 random elements now. | *Pay in blood, gain in power.* |
| **Fire Ball** ★ | 🔥 🔥 | Common | Offensive | Deal 1 damage to the last HP of the target. | *The classic.* |
| **Flare** | 🔥 🔥 | Common | Offensive | Deal 1 damage to the first HP of the target. | *Burn away the front line.* |
| **Snuff Out** | 🔥 🔥 | Rare | Offensive | If the target has 3 or fewer elements, destroy it. | *Small flames are easy to pinch.* |
| **Twin Flames** | 🔥 🔥 | Common | Offensive | Burn 2 on the target. | *Two fires, one foe.* |
| **Boil** | 🔥 💧 | Common | Utility | Turn the last element of the target into Fire. | *Water at the end turns to fire.* |
| **Breath Word** | 🔥 💧 | Common | Utility | Put a Air anywhere you like in this turn's chant. | *Exhale, and the wind answers.* |
| **Cauterize** | 🔥 💧 | Rare | Utility | **Power** (leaves your active row for the rest of the fight): The target can never heal or regrow elements. | *Seal the wound so it never grows back.* |
| **Mimic** | 🔥 💧 | Rare | Utility | Repeat the previous spell that fired this cast. | *Do that again.* |
| **Scald** | 🔥 💧 | Common | Offensive | Deal 1 damage to the last HP of the target; Weaken the target for 1 turn. | *Boiling water, badly thrown.* |
| **Mist Veil** | 💧 🌪️ | Common | Defensive | You become Ethereal this turn. | *Blades pass through you. Curses don't.* |
| **Riptide** | 💧 🌪️ | Common | Defensive | Move 1 element of the target to any position you choose; Weaken the target for 1 turn. | *Drags one piece out of place and knocks it off balance.* |
| **Spark Word** | 💧 🌪️ | Common | Utility | Put a Fire anywhere you like in this turn's chant. | *Say fire, and there is fire.* |
| **Undertow** | 💧 🌪️ | Common | Utility | Move 2 elements of the target to any position you choose. | *The current rearranges everything.* |
| **Ward** | 💧 🌪️ | Common | Defensive | Gain Aegis (1 hit). | *The next blow simply stops.* |
| **Graft** | 💧 🔥 | Common | Utility | Put a Water at the front of the target. | *Plant water at its front, then chant it away.* |
| **Hot Spring** | 💧 🔥 | Common | Defensive | Heal 2; gain 1 Shield. | *Warm water, warm heart.* |
| **Steam** | 💧 🔥 | Common | Defensive | Gain 2 Shield; Weaken the target for 1 turn. | *Hide in the hiss.* |
| **Frost Nova** | 💧 💧 | Common | Defensive | Weaken every enemy for 1 turn. | *Every blade goes numb.* |
| **Soak** | 💧 💧 | Rare | Offensive | Expose the target for 2 turns. | *Drenched and sagging.* |
| **Summon Rain** | 💧 💧 | Common | Utility | +2 conjured Water next turn. | *Two drops, gone by nightfall.* |
| **Tide Pool** | 💧 💧 | Common | Defensive | Heal 3. | *Rest in the shallows.* |
| **Water Wall** ★ | 💧 💧 | Common | Defensive | Gain 4 Shield. | *Stand behind the water.* |

## 3-element patterns (31)

| Name | Pattern | Rarity | Category | Effect | Flavor |
|---|---|---|---|---|---|
| **Tempest** | 🌪️ 🌪️ 🌪️ | Rare | Utility | +3 random elements next turn; move 2 elements of the target to any position you choose. | *The storm brings more, and moves what it touches.* |
| **Trade Winds** | 🌪️ 🌪️ 🌪️ | Rare | Utility | **Power** (leaves your active row for the rest of the fight): At the start of each of your turns: +2 random elements now. | *The wind brings a little more, every turn.* |
| **Gale Force** | 🌪️ 🌪️ 🔥 | Rare | Offensive | Remove up to 3 Air from the target. | *Two breaths torn out of it.* |
| **Venom Coat** | 🌪️ 🌪️ 🔥 | Rare | Offensive | **Power** (leaves your active row for the rest of the fight): Every enemy your Release hits gets Poison 1. | *Every enemy your chant touches is poisoned.* |
| **Firestorm** | 🌪️ 🔥 🌪️ | Rare | Offensive | Burn 3 on every enemy. | *Burning rain on all of them.* |
| **Soul Siphon** | 🌪️ 🔥 🌪️ | Rare | Offensive | Take the first 3 elements of the target; you get them next turn as conjured. | *Pull its first two elements into your hand.* |
| **Backdraft** | 🌪️ 🔥 🔥 | Rare | Offensive | Deal 3 damage to the last HP of the target; Overload 1: 1 fewer element next turn. | *Big blast, slow recovery.* |
| **Resonance** | 🌪️ 🔥 💧 | Rare | Utility | Pick an element in this turn's chant: it becomes 2 in a row. | *One note, sung twice.* |
| **Echo Chamber** | 🌪️ 💧 🌪️ | Rare | Utility | **Power** (leaves your active row for the rest of the fight): The first spell you trigger each turn fires twice. | *The first spell each turn rings twice.* |
| **Whirlpool** | 🌪️ 💧 🌪️ | Rare | Offensive | Deal 1 damage to the last HP of every enemy; Weaken every enemy for 1 turn. | *Spins them off balance.* |
| **Storm Front** | 🌪️ 💧 🔥 | Rare | Defensive | Gain 5 Shield; Thorns 2 this turn. | *Touch it and get burned.* |
| **Frailty** | 🌪️ 💧 💧 | Rare | Offensive | **Power** (leaves your active row for the rest of the fight): The target is permanently Exposed. | *It never recovers its guard.* |
| **Kindling Wind** | 🔥 🌪️ 🔥 | Rare | Offensive | Amplify 1: when the chant is Released, every enemy it hits takes 1 more damage to its last HP. | *Whatever your chant hit burns one element deeper.* |
| **Leech** | 🔥 🌪️ 💧 | Rare | Offensive | Deal 2 damage to the last HP of the target; heal 4. | *Take a piece of it, feel better.* |
| **Recall** | 🔥 🌪️ 💧 | Rare | Utility | After casting, 2 of the chant's elements return to your stock. | *Two of the chant's elements come back.* |
| **Last Rites** | 🔥 🔥 🌪️ | Rare | Offensive | If the target has 4 or fewer elements, destroy it. | *If it's already weak, end it.* |
| **Inferno** | 🔥 🔥 🔥 | Rare | Offensive | Deal 1 damage to the last HP of every enemy. | *Everything burns a little.* |
| **Ember Crown** | 🔥 🔥 💧 | Rare | Offensive | **Power** (leaves your active row for the rest of the fight): At the start of each of your turns: Burn 2 on a random enemy. | *A crown that sets something alight each turn.* |
| **Searing Mist** | 🔥 🔥 💧 | Rare | Offensive | Remove up to 3 Fire from the target. | *Two of its fires go out.* |
| **Alchemy** | 🔥 💧 🌪️ | Rare | Utility | Turn every Water of the target into Fire. | *All its water becomes fire.* |
| **Attunement** | 🔥 💧 🌪️ | Rare | Utility | **Power** (leaves your active row for the rest of the fight): Choose an element: one of your draws each turn is always that element. | *Choose an element; one draw each turn is always it.* |
| **Thermal Burst** | 🔥 💧 🔥 | Rare | Offensive | Deal 2 damage to the first HP of the target; deal 2 damage to the last HP of the target. | *Both ends explode.* |
| **Blight Wind** | 💧 🌪️ 🌪️ | Rare | Offensive | Poison 2 on every enemy. | *Sickness on the wind, for everyone.* |
| **Mistwalk** | 💧 🌪️ 💧 | Rare | Defensive | You become Ethereal this turn; heal 4. | *Step between the drops.* |
| **Geyser** | 💧 🔥 🌪️ | Rare | Offensive | Expose every enemy for 1 turn. | *Blown wide open.* |
| **Reforge** | 💧 🔥 🔥 | Rare | Utility | Turn the first two elements of the target into Fire. | *Its first two elements become Fire.* |
| **Steam Cloud** | 💧 🔥 💧 | Rare | Defensive | Weaken every enemy for 1 turn; gain 4 Shield. | *Nobody can see to aim.* |
| **Purify** | 💧 💧 🌪️ | Rare | Defensive | Remove all your debuffs (frozen elements, Blind, Confuse, Bleed, Silence). | *Every curse washed away.* |
| **Boiling Tide** | 💧 💧 🔥 | Rare | Offensive | Remove up to 3 Water from the target. | *Two of its waters boil away.* |
| **Glacier** | 💧 💧 💧 | Rare | Defensive | Freeze the target for 1 turn. | *Frozen mid-swing.* |
| **Rising Tide** | 💧 💧 💧 | Rare | Defensive | **Power** (leaves your active row for the rest of the fight): At the start of each of your turns: gain 4 Shield. | *The water rises around you every turn.* |

## 4-element patterns (14)

| Name | Pattern | Rarity | Category | Effect | Flavor |
|---|---|---|---|---|---|
| **Hurricane** | 🌪️ 🌪️ 🌪️ 🌪️ | Legendary | Offensive | Deal 3 damage to the last HP of every enemy. | *The whole row is torn apart.* |
| **Storm Crown** | 🌪️ 🌪️ 🌪️ 🔥 | Rare | Utility | **Power** (leaves your active row for the rest of the fight): At the start of each of your turns: +2 conjured Air now. | *A conjured Wind every turn.* |
| **Long Chant** | 🌪️ 🌪️ 💧 🌪️ | Legendary | Utility | **Power** (leaves your active row for the rest of the fight): Your chant line gets +2 slots. | *Two more slots in your chant line.* |
| **Misdirection** | 🌪️ 💧 🌪️ 💧 | Legendary | Defensive | Redirect the intent of the target: its attacks hit the enemy you choose (it can be itself), and anything aimed at you fizzles; gain Aegis (1 hit). | *Point its anger somewhere else. Anywhere else.* |
| **Eye of the Storm** | 🌪️ 💧 🔥 🌪️ | Legendary | Defensive | Freeze every enemy for 2 turns. | *For one moment, everything stops.* |
| **Phoenix Rite** | 🔥 🌪️ 🔥 🌪️ | Rare | Defensive | Gain Aegis (1 hit); heal 5. | *Rise from the next blow untouched.* |
| **Pyromancy** | 🔥 🔥 🔥 🌪️ | Rare | Offensive | **Power** (leaves your active row for the rest of the fight): Your spells that remove elements remove +1. | *Your spells tear out one element more.* |
| **Meteor** | 🔥 🔥 🔥 🔥 | Legendary | Offensive | Deal 5 damage to the last HP of the target. | *Very big, very hot.* |
| **Steam Engine** | 🔥 💧 🔥 💧 | Legendary | Offensive | Echo: the chant is Released twice this turn. | *The chant strikes again after your spells.* |
| **Unshackle** | 💧 🌪️ 🔥 💧 | Rare | Defensive | Break one Lock on your spells. | *Break one lock on your spells.* |
| **Aurora** | 💧 🌪️ 💧 🌪️ | Rare | Defensive | Heal 7; remove all your debuffs (frozen elements, Blind, Confuse, Bleed, Silence); gain 5 Shield. | *Light over still water.* |
| **Open Grimoire** | 💧 🔥 💧 🌪️ | Legendary | Utility | **Power** (leaves your active row for the rest of the fight): Add 2 random spells from your spellbook to your active row for this fight. | *Two more pages fall open.* |
| **Stillness** | 💧 💧 💧 💧 | Rare | Defensive | **Power** (leaves your active row for the rest of the fight): Every enemy permanently deals 25% less damage. | *Every enemy deals 25% less damage, for good.* |
| **Tidal Wave** | 💧 💧 💧 💧 | Legendary | Offensive | Deal 2 damage to the first HP of every enemy; Weaken every enemy for 3 turns. | *Knock the front off everything.* |

## 5-element patterns (6)

| Name | Pattern | Rarity | Category | Effect | Flavor |
|---|---|---|---|---|---|
| **Convergence** | 🌪️ 🔥 💧 🔥 🌪️ | Legendary | Offensive | Echo: the chant is Released twice this turn; Amplify 1: when the chant is Released, every enemy it hits takes 1 more damage to its last HP. | *All three elements sing as one.* |
| **Triune Chant** | 🔥 🌪️ 💧 🌪️ 🔥 | Legendary | Utility | Pick an element in this turn's chant: it becomes 3 in a row. | *Three voices, one word.* |
| **Avatar of Flame** | 🔥 🔥 🔥 🔥 🌪️ | Legendary | Offensive | **Power** (leaves your active row for the rest of the fight): Every enemy your Release hits gets Burn 1. | *Every enemy your chant touches catches fire.* |
| **Supernova** | 🔥 🔥 🔥 🔥 🔥 | Legendary | Offensive | Deal 3 damage to the last HP of every enemy; Burn 4 on every enemy. | *A star dies on the battlefield.* |
| **World Tree's Blessing** | 💧 🌪️ 💧 🌪️ 💧 | Legendary | Defensive | **Power** (leaves your active row for the rest of the fight): At the start of each of your turns: heal 7; +3 random elements now. | *The Last Tree gives back, every turn.* |
| **Deluge** | 💧 💧 💧 💧 💧 | Legendary | Defensive | Gain 14 Shield; heal 10; Freeze every enemy for 2 turns. | *The flood answers.* |
