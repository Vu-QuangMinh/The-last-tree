# The Last Tree — Spell List (chant patterns)

Generated from `data/spells.json` by `tools/spell_report.py`. Edit the JSON, then re-run the script.

**222 spells.** Chant, then every spell whose pattern appears in the chant comes alive (once per turn). Cast them in any order; then the chant is Released and each enemy loses the longest start of its Essence found in it. ★ = starter.

**Keywords**
- **Burn N:** at the start of the enemy's turn, before it acts, it loses its N **leftmost** Essence (armour doesn't help), then Burn drops by 1. It lasts until it runs out.
- **Poison N:** at the start of the enemy's turn, it loses its N **rightmost** Essence (armour doesn't help), then Poison drops by 1. It lasts until it runs out.
- **Weaken:** the enemy deals 50% less damage.
- **Freeze:** the enemy skips its next action.
- **Expose:** whenever your Release hits this enemy, it also loses its rightmost Essence.
- **Ethereal (you):** take no damage from attacks this turn, but double damage from effects. **Ethereal (enemy):** your spells remove double from it this turn; enemies that go Ethereal as their intent can't be hit by your next Release.
- **Shield:** blocks damage until your next turn. **Aegis:** blocks one hit completely.
- **Thorns:** enemies that attack you lose their rightmost Essence.
- **Armour** (enemy ability): an armoured Essence can't be removed this turn, but it still counts for the chant's match.
- **Power:** cast once, then it leaves your active row (its slot stays empty) and its effect lasts the whole fight.
- **Conjured** Essence arrive next turn and vanish at the end of that turn if unused.
- **Siphon:** take Essence off an enemy's Essence. **Execute:** destroy an enemy that is small enough.
- **Amplify:** enemies your chant hit lose extra Essence. **Echo:** the chant strikes again after your spells. **Overload:** fewer Essence next turn.

## 1-Essence patterns (28)

| Name | Pattern | Rarity | Category | Effect | Flavor |
|---|---|---|---|---|---|
| **Borrowed Breath** | 🌪️ | Common | Utility | +1 conjured Air next turn. | *A breath that isn't yours to keep.* |
| **Breeze** | 🌪️ | Common | Defensive | Thorns 2 this turn. | *It brings something, and stings a little.* |
| **Siphon** | 🌪️ | Rare | Offensive | Remove the 2 leftmost Essence of the target; next turn you gain the removed Essence (conjured). | *Pull its leftmost Essence into your hand.* |
| **Still Air** | 🌪️ | Legendary | Defensive | **Anti-spell** (never cast; at the end of each of your turns it takes effect unless your chant contains its pattern): Gain Aegis (1 hit); heal 6. | *Hold your breath, and the world holds its blows.* |
| **Summoning Word** | 🌪️ | Rare | Utility | Conjure 1 (next turn, 1 random spell join your active row; each vanishes once cast: Ephemeral). | *Say it, and something answers.* |
| **Taint** | 🌪️ | Common | Offensive | Poison 1 on the target. | *Something foul rides the breeze.* |
| **Updraft** | 🌪️ | Common | Utility | Move 1 Essence of the target to any position you choose. | *Lift one Essence and set it down where you like.* |
| **Whisper** | 🌪️ | Common | Defensive | Weaken 1 on the target. | *A word in the ear, and its arm goes slack.* |
| **Wisp** | 🌪️ | Common | Utility | +1 conjured random Essence now. | *A little light that brings a little help.* |
| **Zephyr** | 🌪️ | Common | Offensive | Expose 1 on a random enemy. | *A gentle wind finds the gaps.* |
| **Ashfall** | 🔥 | Rare | Offensive | Burn 1 on all enemies. | *Grey snow that burns.* |
| **Cinder** | 🔥 | Common | Offensive | Expose 1 on the target. | *Glowing ash marks the weak spot.* |
| **Clear Sight** | 🔥 | Common | Defensive | Cure Blind. | *A flash of light burns the fog away.* |
| **Ember** | 🔥 | Common | Offensive | Burn 1 on the target. | *A single spark that won't go out.* |
| **Flicker** | 🔥 | Common | Offensive | Remove 1 random Essence from random enemies (the same enemy can be hit more than once). | *A spark that won't sit still.* |
| **Smolder** | 🔥 | Legendary | Offensive | **Anti-spell** (never cast; at the end of each of your turns it takes effect unless your chant contains its pattern): Remove the 3 rightmost Essence of all enemies; Burn 4 on all enemies. | *Never let it touch fire again, and it burns everything for you.* |
| **Spark** | 🔥 | Common | Offensive | Remove the rightmost Essence of the target (only if it has 4+ Essence). | *Only big things catch.* |
| **Spark Shower** | 🔥 | Common | Utility | +2 Fire next turn. | *Somewhere, something got singed.* |
| **Tinder** | 🔥 | Common | Offensive | Burn 1 on a random enemy. | *Small fires make big friends.* |
| **Bandage** | 💧 | Common | Defensive | Cure Bleed. | *Wash it, wrap it, keep going.* |
| **Calm Waters** | 💧 | Legendary | Defensive | **Anti-spell** (never cast; at the end of each of your turns it takes effect unless your chant contains its pattern): Gain 10 Shield; heal 4. | *Not a drop. Not one.* |
| **Chill** | 💧 | Common | Utility | Remove all Armour from the target. | *Cold makes armour brittle.* |
| **Dewdrop** | 💧 | Common | Defensive | Remove all your debuffs (frozen Essence, Blind, Confuse, Bleed, Silence). | *Morning clears every eye.* |
| **Drizzle** | 💧 | Common | Defensive | Heal 2. | *Soft rain, softer landing.* |
| **Droplet** | 💧 | Common | Defensive | Gain 2 Shield. | *Every drop helps.* |
| **Mist** | 💧 | Common | Defensive | Heal 1. | *Cool on the skin.* |
| **Ripple** | 💧 | Common | Utility | Turn the rightmost Essence of the target into Water. | *The end of it turns to water.* |
| **Splash** | 💧 | Common | Offensive | Remove the rightmost Essence of a random enemy. | *Mostly harmless. Mostly.* |

## 2-Essence patterns (77)

| Name | Pattern | Rarity | Category | Effect | Flavor |
|---|---|---|---|---|---|
| **Wellspring Rite** | ❔ 💧 | Rare | Defensive | Heal 4. | *Every spring starts somewhere.* |
| **Gale Call** | 🌪️ ❔ | Rare | Utility | Conjure 2 (next turn, 2 random spells join your active row; each vanishes once cast: Ephemeral). | *Whistle, and the wind brings a guest.* |
| **Crosswind** | 🌪️ 🌪️ | Rare | Defensive | Weaken 1 on all enemies. | *Hard to swing straight in this wind.* |
| **Cyclone** | 🌪️ 🌪️ | Common | Offensive | Remove the rightmost Essence of all enemies (only if it has 4+ Essence). | *Shaves the big ones down to size.* |
| **Gale Barrier** | 🌪️ 🌪️ | Common | Defensive | Gain 3 Shield; Thorns 1 this turn. | *A wall of wind that bites back.* |
| **Miasma** | 🌪️ 🌪️ | Common | Offensive | Poison 2 on the target. | *A choking cloud settles on it.* |
| **Steady Mind** | 🌪️ 🌪️ | Common | Defensive | Cure Confuse; +1 Air next turn. | *Breathe in, breathe out.* |
| **Tailwind** ★ | 🌪️ 🌪️ | Common | Utility | +1 random Essence next turn. | *The wind brings more.* |
| **Thieving Wind** | 🌪️ 🌪️ | Rare | Offensive | Steal 1 Essence of your choice from the target (they go to your bag). | *The breeze has sticky fingers.* |
| **Whirl** | 🌪️ 🌪️ | Common | Utility | Move the first Essence of the target to the end. | *Spin them round; front goes to the back.* |
| **Alchemist's Breath** | 🌪️ 🔥 | Common | Utility | Turn 2 of your stored Essence into Fire. | *Two of your stored Essence become Fire.* |
| **Cinder Rain** | 🌪️ 🔥 | Rare | Offensive | Remove 3 random Essence from random enemies (the same enemy can be hit more than once). | *Look up. Then don't.* |
| **Ember Gust** | 🌪️ 🔥 | Common | Offensive | Expose 2 on the target. | *Wind carries the sparks right into the cracks.* |
| **Fan the Flames** | 🌪️ 🔥 | Common | Offensive | Double the Burn on the target. | *Double the fire already there.* |
| **Gust** | 🌪️ 🔥 | Common | Offensive | Targeted: remove 1 Essence of your choice from the target. | *A precise gust plucks one piece away.* |
| **Smoke Signal** | 🌪️ 🔥 | Common | Utility | Conjure 1 (next turn, 1 random spell join your active row; each vanishes once cast: Ephemeral). | *Somebody saw it. Somebody's coming.* |
| **Spring Word** | 🌪️ 🔥 | Common | Utility | Put a Water anywhere you like in this turn's chant. | *A word that wells up.* |
| **Updraft Lance** | 🌪️ 🔥 | Common | Offensive | Remove the rightmost Essence of a random enemy. | *Thrown up, coming down somewhere.* |
| **Hailstone** | 🌪️ 💧 | Common | Defensive | Weaken 2 on the target. | *Bruises and bad moods.* |
| **Rain** | 🌪️ 💧 | Common | Defensive | Heal 2. | *Soft and steady.* |
| **Refresh** | 🌪️ 💧 | Common | Defensive | Remove all your debuffs (frozen Essence, Blind, Confuse, Bleed, Silence); +1 Water next turn. | *Wash the frost off.* |
| **Unbind** | 🌪️ 💧 | Common | Defensive | Cure Silence on all your spells. | *Your voice returns.* |
| **Phoenix Feather** | 🔥 ❔ | Legendary | Offensive | Heal 6; Burn 2 on all enemies. | *Warm enough to heal, hot enough to hurt.* |
| **Wild Flame** | 🔥 ❔ | Rare | Offensive | Burn 3 on the target. | *Any fuel will do.* |
| **Ash and Ember** | 🔥 🌪️ | Rare | Offensive | Burn 1 on all enemies; double the Burn on all enemies. | *Feed every fire at once.* |
| **Blowtorch** | 🔥 🌪️ | Common | Offensive | Remove the rightmost Essence of the target (+1 if it is burning). | *Hotter where it's already burning.* |
| **Conjure Flame** | 🔥 🌪️ | Common | Utility | +2 conjured Fire next turn. | *Two flames, borrowed for a turn.* |
| **Firefly** | 🔥 🌪️ | Common | Offensive | Burn 2 on a random enemy. | *A little light that bites.* |
| **Heat Haze** | 🔥 🌪️ | Rare | Offensive | **Anti-spell** (never cast; at the end of each of your turns it takes effect unless your chant contains its pattern): Burn 1 on all enemies. | *Shimmering air shows every weak spot, and singes it.* |
| **Phase Shift** | 🔥 🌪️ | Rare | Utility | Make the target Ethereal (your spells remove double from it this turn). | *Untouchable by chants, fragile to magic.* |
| **Thorn Mantle** | 🔥 🌪️ | Rare | Defensive | **Power** (leaves your active row for the rest of the fight): Thorns 1 for the rest of the fight. | *Anything that strikes you gets burned.* |
| **Wildfire** | 🔥 🌪️ | Common | Offensive | Burn 1 on all enemies. | *The wind spreads it everywhere.* |
| **Wildspark** | 🔥 🌪️ | Common | Offensive | Remove 2 random Essence from random enemies (the same enemy can be hit more than once). | *Two sparks, no aim.* |
| **Blood Price** | 🔥 🔥 | Rare | Utility | Lose 3 HP; +4 random Essence now. | *Pay in blood, gain in power.* |
| **Coal Toss** | 🔥 🔥 | Common | Offensive | Remove the 2 rightmost Essence of a random enemy. | *Underhand, still hot.* |
| **Fire Ball** ★ | 🔥 🔥 | Common | Offensive | Remove the rightmost Essence of the target. | *The classic.* |
| **Flame Lash** | 🔥 🔥 | Common | Offensive | Burn 1 on 2 different enemies (you pick both). | *A whip of fire, with a lingering sting.* |
| **Flare** | 🔥 🔥 | Common | Offensive | Remove the leftmost Essence of the target. | *Burn away the front line.* |
| **Searing Brand** | 🔥 🔥 | Rare | Offensive | Expose 2 on all enemies. | *Marked, then lit.* |
| **Snuff Out** | 🔥 🔥 | Rare | Offensive | If the target has 3 or fewer Essence, destroy it. | *Small flames are easy to pinch.* |
| **Twin Comets** | 🔥 🔥 | Rare | Offensive | Burn 2 on 2 different enemies (you pick both). | *One for you, one for your friend.* |
| **Twin Flames** | 🔥 🔥 | Common | Offensive | Burn 2 on the target. | *Two fires, one foe.* |
| **Boil** | 🔥 💧 | Common | Utility | Turn the rightmost Essence of the target into Fire. | *Water at the end turns to fire.* |
| **Breath Word** | 🔥 💧 | Common | Utility | Put a Air anywhere you like in this turn's chant. | *Exhale, and the wind answers.* |
| **Cauterize** | 🔥 💧 | Rare | Utility | **Power** (leaves your active row for the rest of the fight): The target can never heal or regrow Essence. | *Seal the wound so it never grows back.* |
| **Fog of War** | 🔥 💧 | Rare | Defensive | **Anti-spell** (never cast; at the end of each of your turns it takes effect unless your chant contains its pattern): Weaken 2 on all enemies. | *While it hangs, nobody swings straight.* |
| **Kindled Heart** | 🔥 💧 | Rare | Defensive | Gain Aegis (1 hit). | *A warm heart burns two ways.* |
| **Mimic** | 🔥 💧 | Rare | Utility | Repeat the previous spell that fired this cast. | *Do that again.* |
| **Scald** | 🔥 💧 | Common | Offensive | Remove the rightmost Essence of the target; Weaken 1 on the target. | *Boiling water, badly thrown.* |
| **Scalding Rain** | 🔥 💧 | Rare | Offensive | Poison 1 on all enemies. | *Hot, wet and vile.* |
| **Steam Burst** | 🔥 💧 | Common | Defensive | Gain 3 Shield. | *Hiss, pop, and a cloud to hide in.* |
| **Tidecaller** | 💧 ❔ | Rare | Utility | +2 conjured Water now. | *The water comes when called, for a turn.* |
| **Cold Snap** | 💧 🌪️ | Rare | Defensive | Freeze 1 on the target. | *Frozen mid-swing.* |
| **Mist Step** | 💧 🌪️ | Common | Utility | +1 conjured random Essence now. | *Step aside, into the fog.* |
| **Mist Veil** | 💧 🌪️ | Common | Defensive | You become Ethereal this turn. | *Blades pass through you. Curses don't.* |
| **Ripplewind** | 💧 🌪️ | Common | Utility | Turn the rightmost Essence of the target into Water. | *A ripple that rewrites the shore.* |
| **Riptide** | 💧 🌪️ | Common | Defensive | Move 1 Essence of the target to any position you choose; Weaken 1 on the target. | *Drags one piece out of place and knocks it off balance.* |
| **Sea Breeze** | 💧 🌪️ | Common | Defensive | Remove all your debuffs (frozen Essence, Blind, Confuse, Bleed, Silence). | *Salt air clears the head.* |
| **Spark Word** | 💧 🌪️ | Common | Utility | Put a Fire anywhere you like in this turn's chant. | *Say fire, and there is fire.* |
| **Spray** | 💧 🌪️ | Common | Offensive | Expose 1 on the target. | *Splash them, and see where they flinch.* |
| **Undertow** | 💧 🌪️ | Common | Utility | Move 2 Essence of the target to any position you choose. | *The current rearranges everything.* |
| **Ward** | 💧 🌪️ | Common | Defensive | Gain Aegis (1 hit). | *The next blow simply stops.* |
| **Graft** | 💧 🔥 | Common | Utility | Put a Water at the front of the target. | *Plant water at its leftmost end, then chant it away.* |
| **Hot Spring** | 💧 🔥 | Common | Defensive | Heal 2; gain 1 Shield. | *Warm water, warm heart.* |
| **Quench** | 💧 🔥 | Common | Defensive | Heal 3. | *Douse every burning trouble.* |
| **Steam** | 💧 🔥 | Common | Defensive | Gain 2 Shield; Weaken 1 on the target. | *Hide in the hiss.* |
| **Steam Vent** | 💧 🔥 | Rare | Offensive | **Anti-spell** (never cast; at the end of each of your turns it takes effect unless your chant contains its pattern): Poison 2 on all enemies. | *Keep the lid on and it seeps out.* |
| **Water Whip** | 💧 🔥 | Common | Offensive | Targeted: remove 1 Essence of your choice from the target. | *Snap off whatever you like.* |
| **Brine** | 💧 💧 | Common | Offensive | Poison 2 on the target. | *Salt in every wound.* |
| **Frost Nova** | 💧 💧 | Common | Defensive | Weaken 1 on all enemies. | *Every blade goes numb.* |
| **Mirror Pool** | 💧 💧 | Rare | Utility | Duplicate 1. | *Look closely: there are two of you.* |
| **Soak** | 💧 💧 | Rare | Offensive | Expose 2 on the target. | *Drenched and sagging.* |
| **Summon Rain** | 💧 💧 | Common | Utility | +2 conjured Water next turn. | *Two drops, gone by nightfall.* |
| **Tide Pool** | 💧 💧 | Common | Defensive | Heal 3. | *Rest in the shallows.* |
| **Tide Ward** | 💧 💧 | Common | Defensive | Thorns 3 this turn. | *The sea guards its own, with barnacles.* |
| **Undercurrent** | 💧 💧 | Rare | Offensive | Remove the 2 leftmost Essence of the target; next turn you gain the removed Essence (conjured). | *What it pulls under, it gives to you.* |
| **Water Wall** ★ | 💧 💧 | Common | Defensive | Gain 4 Shield. | *Stand behind the water.* |

## 3-Essence patterns (65)

| Name | Pattern | Rarity | Category | Effect | Flavor |
|---|---|---|---|---|---|
| **Stormcaller** | 🌪️ ❔ 🌪️ | Rare | Utility | Conjure 2 (next turn, 2 random spells join your active row; each vanishes once cast: Ephemeral). | *Two voices answer the storm.* |
| **Sky Lance** | 🌪️ 🌪️ 🌪️ | Common | Offensive | Remove the 3 rightmost Essence of the target. | *Down from the clouds, straight through.* |
| **Tempest** | 🌪️ 🌪️ 🌪️ | Rare | Utility | +2 random Essence next turn; Rearrange 1. | *The storm brings more, and moves what it touches.* |
| **Trade Winds** | 🌪️ 🌪️ 🌪️ | Rare | Utility | **Power** (leaves your active row for the rest of the fight): At the start of each of your turns: +2 random Essence now. | *The wind brings a little more, every turn.* |
| **Dustdevil** | 🌪️ 🌪️ 🔥 | Common | Utility | Move 2 Essence of the target to any position you choose. | *Spins things around, throws things about.* |
| **Gale Force** | 🌪️ 🌪️ 🔥 | Rare | Offensive | Remove up to 3 Air from the target. | *Two breaths torn out of it.* |
| **Thunderhead** | 🌪️ 🌪️ 🔥 | Rare | Offensive | Remove 3 random Essence from random enemies (the same enemy can be hit more than once). | *The cloud grumbles, then strikes.* |
| **Venom Coat** | 🌪️ 🌪️ 🔥 | Rare | Offensive | **Power** (leaves your active row for the rest of the fight): All enemies your Release hits get Poison 1. | *Every enemy your chant touches is poisoned.* |
| **Mistral** | 🌪️ 🌪️ 💧 | Rare | Offensive | Expose 1 on all enemies. | *A cold wind that finds everyone's weak side.* |
| **Soul Siphon** | 🌪️ 🔥 🌪️ | Rare | Offensive | Remove the 3 leftmost Essence of the target; next turn you gain the removed Essence (conjured). | *Pull its two leftmost Essence into your hand.* |
| **Windless Night** | 🌪️ 🔥 🌪️ | Common | Defensive | **Anti-spell** (never cast; at the end of each of your turns it takes effect unless your chant contains its pattern): Gain 2 Shield. | *Not a breath, not a blow.* |
| **Backdraft** | 🌪️ 🔥 🔥 | Rare | Offensive | Remove the 3 rightmost Essence of the target; Overload 1. | *Big blast, slow recovery.* |
| **Resonance** | 🌪️ 🔥 💧 | Rare | Utility | Duplicate 1. | *One note, sung twice.* |
| **Echo Chamber** | 🌪️ 💧 🌪️ | Rare | Utility | **Power** (leaves your active row for the rest of the fight): The first spell you trigger each turn fires twice. | *The first spell each turn rings twice.* |
| **Rain Song** | 🌪️ 💧 🌪️ | Common | Defensive | Heal 2; +1 Water next turn. | *Sing for the rain and it sings back.* |
| **Tempest Veil** | 🌪️ 💧 🌪️ | Rare | Defensive | Gain 5 Shield. | *Wrap yourself in the storm.* |
| **Whirlpool** | 🌪️ 💧 🌪️ | Rare | Offensive | Remove the rightmost Essence of all enemies; Weaken 1 on all enemies. | *Spins them off balance.* |
| **Storm Front** | 🌪️ 💧 🔥 | Rare | Defensive | Gain 5 Shield; Thorns 2 this turn. | *Touch it and get burned.* |
| **Wind Shear** | 🌪️ 💧 🔥 | Common | Offensive | Remove the 2 rightmost Essence of the target. | *Twist them round and cut the new tail.* |
| **Frailty** | 🌪️ 💧 💧 | Rare | Offensive | **Power** (leaves your active row for the rest of the fight): The target is permanently Exposed. | *It never recovers its guard.* |
| **Grave Wind** | 🌪️ 💧 💧 | Rare | Offensive | If the target has 3 or fewer Essence, destroy it. | *It carries away the weak.* |
| **Hush of Rain** | 🌪️ 💧 💧 | Common | Defensive | **Anti-spell** (never cast; at the end of each of your turns it takes effect unless your chant contains its pattern): Heal 2. | *Listen to the rain instead of speaking.* |
| **Inferno** | 🔥 ❔ 🔥 | Rare | Offensive | Remove the rightmost Essence of all enemies. | *Everything burns a little.* |
| **Witch Fire** | 🔥 ❔ 🔥 | Rare | Offensive | Burn 4 on the target. | *Green flames, foul smoke.* |
| **Ashen Veil** | 🔥 🌪️ 🌪️ | Rare | Defensive | You become Ethereal this turn. | *Become smoke. Smoke can't be hit.* |
| **Ember Storm** | 🔥 🌪️ 🔥 | Common | Offensive | Burn 1 on all enemies. | *Embers everywhere, all at once.* |
| **Kindling Wind** | 🔥 🌪️ 🔥 | Rare | Offensive | Amplify 1. | *Whatever your chant hit burns one Essence deeper.* |
| **Absorb** | 🔥 🌪️ 💧 | Rare | Offensive | Remove the 2 rightmost Essence of the target; if this defeats it, heal 5 HP. | *Take the last of it, and feel much better.* |
| **Hearth Song** | 🔥 🌪️ 💧 | Rare | Defensive | Heal 4. | *Home is wherever this is sung.* |
| **Recall** | 🔥 🌪️ 💧 | Rare | Utility | After the Release, the 2 rightmost Essence of your chant go back to your bag. | *Two of the chant's Essence come back.* |
| **Flamecaller** | 🔥 🔥 🌪️ | Rare | Utility | Conjure 2 (next turn, 2 random spells join your active row; each vanishes once cast: Ephemeral). | *Call the fire, and its friends.* |
| **Last Rites** | 🔥 🔥 🌪️ | Rare | Offensive | If the target has 4 or fewer Essence, destroy it. | *If it's already weak, end it.* |
| **Brimstone** | 🔥 🔥 🔥 | Rare | Offensive | Burn 2 on all enemies. | *It burns the caster too. Worth it.* |
| **Kindle** | 🔥 🔥 🔥 | Rare | Offensive | **Power** (leaves your active row for the rest of the fight): Whenever you apply Burn, apply 1 more; Burn 1 on all enemies. | *Every fire you light burns a little longer.* |
| **Ember Crown** | 🔥 🔥 💧 | Rare | Offensive | **Power** (leaves your active row for the rest of the fight): At the start of each of your turns: Burn 2 on a random enemy. | *A crown that sets something alight each turn.* |
| **Lava Flow** | 🔥 🔥 💧 | Rare | Offensive | Remove the 2 leftmost Essence of the target; Burn 2 on the target. | *Slow, glowing, unstoppable.* |
| **Searing Mist** | 🔥 🔥 💧 | Rare | Offensive | Remove up to 3 Fire from the target. | *Two of its fires go out.* |
| **Alchemy** | 🔥 💧 🌪️ | Rare | Utility | Turn every Water of the target into Fire. | *All its water becomes fire.* |
| **Attunement** | 🔥 💧 🌪️ | Rare | Utility | **Power** (leaves your active row for the rest of the fight): Choose an Essence: one of your draws each turn is always that Essence. | *Choose an Essence; one draw each turn is always it.* |
| **Rainbow Bridge** | 🔥 💧 🌪️ | Legendary | Defensive | Conjure 2 (next turn, 2 random spells join your active row; each vanishes once cast: Ephemeral); +3 random Essence next turn; heal 3. | *Every colour brings a gift.* |
| **Molten Core** | 🔥 💧 🔥 | Rare | Offensive | **Anti-spell** (never cast; at the end of each of your turns it takes effect unless your chant contains its pattern): Burn 1 on a random enemy. | *Leave it be and it erupts by itself.* |
| **Cinder Shield** | 🔥 💧 💧 | Common | Defensive | Gain 5 Shield. | *Hold it up and it smokes at them.* |
| **Deep Freeze** | 💧 ❔ 💧 | Legendary | Defensive | Freeze 2 on all enemies; gain 4 Shield. | *Everything stops. Even the clock.* |
| **Spirit Lantern** | 💧 🌪️ ❔ | Rare | Utility | Conjure 2 (next turn, 2 random spells join your active row; each vanishes once cast: Ephemeral). | *It lights the way for someone new.* |
| **Blight Wind** | 💧 🌪️ 🌪️ | Rare | Offensive | Poison 2 on all enemies. | *Sickness on the wind, for everyone.* |
| **Sunlit Grove** | 💧 🌪️ 🔥 | Common | Defensive | Heal 4. | *Light through leaves, and something to pick.* |
| **Frostbite** | 💧 🌪️ 💧 | Rare | Offensive | Freeze 1 on the target; Poison 2 on the target. | *It stops them, then it hurts.* |
| **Mistwalk** | 💧 🌪️ 💧 | Rare | Defensive | You become Ethereal this turn; heal 4. | *Step between the drops.* |
| **Tide Thief** | 💧 🌪️ 💧 | Rare | Offensive | Steal 1 Essence of your choice from the target (they go to your bag). | *The current takes what it likes and brings it to you.* |
| **Arcane Barrage** | 💧 🔥 🌪️ | Common | Offensive | Remove 3 random Essence from random enemies (the same enemy can be hit more than once). | *Three bolts, three guesses. Something will get hit.* |
| **Geyser** | 💧 🔥 🌪️ | Rare | Offensive | Expose 1 on all enemies. | *Blown wide open.* |
| **Glacial Spike** | 💧 🔥 🌪️ | Rare | Offensive | Remove the leftmost Essence of 2 different enemies (you pick both). | *Ice through one, frost on another.* |
| **Corrode** | 💧 🔥 🔥 | Rare | Offensive | Remove up to 3 Fire from the target. | *Eat the fire out of them.* |
| **Reforge** | 💧 🔥 🔥 | Rare | Utility | Turn the 2 leftmost Essence of the target into Fire. | *Its two leftmost Essence become Fire.* |
| **Silent Tide** | 💧 🔥 💧 | Rare | Defensive | **Anti-spell** (never cast; at the end of each of your turns it takes effect unless your chant contains its pattern): Gain 3 Shield. | *The sea rises when no one speaks.* |
| **Steam Cloud** | 💧 🔥 💧 | Rare | Defensive | Weaken 1 on all enemies; gain 4 Shield. | *Nobody can see to aim.* |
| **Healing Rain** | 💧 💧 🌪️ | Common | Defensive | Heal 5. | *Let it wash everything off.* |
| **Ice Lance** | 💧 💧 🌪️ | Common | Offensive | Remove the 2 leftmost Essence of the target. | *Clean, cold, and to the point.* |
| **Purify** | 💧 💧 🌪️ | Rare | Defensive | Remove all your debuffs (frozen Essence, Blind, Confuse, Bleed, Silence). | *Every curse washed away.* |
| **Boiling Tide** | 💧 💧 🔥 | Rare | Offensive | Remove up to 3 Water from the target. | *Two of its waters boil away.* |
| **Siren's Call** | 💧 💧 🔥 | Rare | Offensive | Steal up to 2 Fire from the target (they go to your bag). | *A song so sweet the fire walks into the water.* |
| **Undertow Grip** | 💧 💧 🔥 | Common | Defensive | Weaken 2 on the target. | *Pulled under and worn down.* |
| **Glacier** | 💧 💧 💧 | Rare | Defensive | Freeze 1 on the target. | *Frozen mid-swing.* |
| **Rising Tide** | 💧 💧 💧 | Rare | Defensive | **Power** (leaves your active row for the rest of the fight): At the start of each of your turns: gain 4 Shield. | *The water rises around you every turn.* |
| **Tsunami Ward** | 💧 💧 💧 | Rare | Defensive | Gain 6 Shield. | *A wall of sea with teeth.* |

## 4-Essence patterns (34)

| Name | Pattern | Rarity | Category | Effect | Flavor |
|---|---|---|---|---|---|
| **Cyclone Edge** | 🌪️ ❔ 🌪️ 🔥 | Rare | Offensive | Remove the 2 leftmost Essence of 2 different enemies (you pick both). | *Two spinning cuts, two open wounds.* |
| **Hurricane** | 🌪️ 🌪️ 🌪️ 🌪️ | Legendary | Offensive | Remove the 3 rightmost Essence of all enemies. | *The whole row is torn apart.* |
| **Storm Crown** | 🌪️ 🌪️ 🌪️ 🔥 | Rare | Utility | **Power** (leaves your active row for the rest of the fight): At the start of each of your turns: +2 conjured Air now. | *A conjured Wind every turn.* |
| **Storm Legion** | 🌪️ 🌪️ 🌪️ 🔥 | Rare | Offensive | Remove 4 random Essence from random enemies (the same enemy can be hit more than once). | *A hundred tiny lightnings, all late for something.* |
| **Gust Front** | 🌪️ 🌪️ 🔥 🔥 | Common | Offensive | Remove the rightmost Essence of all enemies. | *The wall of wind before the storm.* |
| **Long Chant** | 🌪️ 🌪️ 💧 🌪️ | Legendary | Utility | **Power** (leaves your active row for the rest of the fight): Your chant line gets +2 slots. | *Two more slots in your chant line.* |
| **Quiet Wind** | 🌪️ 🌪️ 💧 🌪️ | Common | Defensive | **Anti-spell** (never cast; at the end of each of your turns it takes effect unless your chant contains its pattern): Gain 2 Shield. | *Say nothing, and the wind keeps you.* |
| **Sky Sovereign** | 🌪️ 🌪️ 💧 🌪️ | Legendary | Offensive | Conjure 2 (next turn, 2 random spells join your active row; each vanishes once cast: Ephemeral); +2 conjured random Essence now; Amplify 1. | *The sky bows to no one, but sends gifts.* |
| **Gale Slash** | 🌪️ 🔥 🔥 🌪️ | Common | Offensive | Remove the leftmost Essence of all enemies. | *One sweep, everyone.* |
| **Misdirection** | 🌪️ 💧 🌪️ 💧 | Legendary | Defensive | Redirect the intent of the target: its attacks hit the enemy you choose (it can be itself), and anything aimed at you fizzles; gain Aegis (1 hit). | *Point its anger somewhere else. Anywhere else.* |
| **Eye of the Storm** | 🌪️ 💧 🔥 🌪️ | Legendary | Defensive | Freeze 2 on all enemies. | *For one moment, everything stops.* |
| **Wildfire Pact** | 🔥 ❔ 🔥 🌪️ | Rare | Offensive | Burn 2 on all enemies. | *Burn it all, and pay tomorrow.* |
| **Phoenix Rite** | 🔥 🌪️ 🔥 🌪️ | Rare | Defensive | Gain Aegis (1 hit); heal 5. | *Rise from the next blow untouched.* |
| **Phoenix Dive** | 🔥 🌪️ 🔥 🔥 | Rare | Offensive | Remove the 2 rightmost Essence of all enemies. | *Fall like fire, rise like it too.* |
| **Inferno Lance** | 🔥 🔥 🔥 🌪️ | Rare | Offensive | Remove the 4 rightmost Essence of the target. | *Through them, then all over them.* |
| **Pyromancy** | 🔥 🔥 🔥 🌪️ | Rare | Offensive | **Power** (leaves your active row for the rest of the fight): Your spells that remove Essence remove +1. | *Your spells tear out one Essence more.* |
| **Meteor** | 🔥 🔥 🔥 🔥 | Legendary | Offensive | Remove the 5 rightmost Essence of the target. | *Very big, very hot.* |
| **Thermal Burst** | 🔥 🔥 💧 🔥 | Rare | Offensive | Remove the 2 leftmost Essence of 2 different enemies (you pick both). | *Steam bursts two ways at once.* |
| **Forge Fire** | 🔥 🔥 💧 💧 | Common | Defensive | Gain 6 Shield. | *Hammer, quench, repeat.* |
| **Ember Chorus** | 🔥 💧 🌪️ 🔥 | Rare | Utility | Conjure 3 (next turn, 3 random spells join your active row; each vanishes once cast: Ephemeral). | *Fire sings in harmony.* |
| **Steam Engine** | 🔥 💧 🔥 💧 | Legendary | Offensive | Echo. | *The chant strikes again after your spells.* |
| **Steam Titan** | 🔥 💧 🔥 💧 | Legendary | Offensive | Remove the 3 rightmost Essence of the target; gain 5 Shield; Burn 2 on the target. | *Iron lungs, boiling fists.* |
| **Blood Moon** | 🔥 💧 💧 🔥 | Rare | Offensive | Remove the 2 rightmost Essence of all enemies. | *A red night asks for a red price.* |
| **Moon Tide** | 💧 ❔ 💧 🌪️ | Rare | Defensive | Heal 7. | *Silver water, washing clean.* |
| **Soothing Mist** | 💧 🌪️ 🌪️ 🔥 | Common | Defensive | **Anti-spell** (never cast; at the end of each of your turns it takes effect unless your chant contains its pattern): Heal 1. | *Breathe it in. Don't say a word.* |
| **Winter Gale** | 💧 🌪️ 🌪️ 💧 | Common | Defensive | Weaken 2 on all enemies. | *Too cold to hit hard.* |
| **Unshackle** | 💧 🌪️ 🔥 💧 | Rare | Defensive | Break one Lock on your spells. | *Break one lock on your spells.* |
| **Aurora** | 💧 🌪️ 💧 🌪️ | Rare | Defensive | Heal 7; remove all your debuffs (frozen Essence, Blind, Confuse, Bleed, Silence); gain 5 Shield. | *Light over still water.* |
| **Tidal Surge** | 💧 🌪️ 💧 💧 | Rare | Offensive | Remove the 2 leftmost Essence of all enemies; next turn you gain the removed Essence (conjured). | *The tide takes, the tide gives.* |
| **Open Grimoire** | 💧 🔥 💧 🌪️ | Legendary | Utility | **Power** (leaves your active row for the rest of the fight): Add 2 random spells from your spellbook to your active row for this fight. | *Two more pages fall open.* |
| **Frozen Tomb** | 💧 💧 🌪️ 💧 | Legendary | Offensive | Freeze 2 on the target; Expose 2 on the target; Poison 3 on the target. | *Sealed in, picked apart.* |
| **Maelstrom Ward** | 💧 💧 💧 🌪️ | Rare | Defensive | Gain 8 Shield. | *A whirlpool to stand in. Come closer.* |
| **Stillness** | 💧 💧 💧 💧 | Rare | Defensive | **Power** (leaves your active row for the rest of the fight): All enemies deal 25% less damage for the rest of the fight. | *Every enemy deals 25% less damage, for good.* |
| **Tidal Wave** | 💧 💧 💧 💧 | Legendary | Offensive | Remove the 2 leftmost Essence of all enemies; Weaken 3 on all enemies. | *Knock the leftmost off everything.* |

## 5-Essence patterns (16)

| Name | Pattern | Rarity | Category | Effect | Flavor |
|---|---|---|---|---|---|
| **Storm Sermon** | 🌪️ ❔ 💧 ❔ 🌪️ | Rare | Defensive | Weaken 3 on all enemies. | *A long sermon, and everyone's tired.* |
| **Heaven's Gale** | 🌪️ 🌪️ 💧 🌪️ 🌪️ | Legendary | Defensive | Conjure 3 (next turn, 3 random spells join your active row; each vanishes once cast: Ephemeral); gain Aegis (1 hit). | *The sky opens and spells fall out.* |
| **Firestorm** | 🌪️ 🔥 ❔ 🔥 🌪️ | Rare | Offensive | Burn 3 on all enemies. | *Burning rain on all of them.* |
| **Convergence** | 🌪️ 🔥 💧 🔥 🌪️ | Legendary | Offensive | Echo; Amplify 1. | *All three Essence sing as one.* |
| **Firestorm Herald** | 🔥 ❔ 🌪️ ❔ 🔥 | Rare | Offensive | Burn 4 on all enemies. | *It announces the fire. Loudly.* |
| **Triune Chant** | 🔥 🌪️ 💧 🌪️ 🔥 | Legendary | Utility | Duplicate 2. | *Three voices, one word.* |
| **Solar Flare** | 🔥 🔥 🌪️ 🔥 🔥 | Legendary | Offensive | Remove the 3 rightmost Essence of all enemies; Burn 3 on all enemies. | *The sun leans in for a closer look.* |
| **Avatar of Flame** | 🔥 🔥 🔥 🔥 🌪️ | Legendary | Offensive | **Power** (leaves your active row for the rest of the fight): All enemies your Release hits get Burn 1. | *Every enemy your chant touches catches fire.* |
| **Supernova** | 🔥 🔥 🔥 🔥 🔥 | Legendary | Offensive | Remove the 3 rightmost Essence of all enemies; Burn 4 on all enemies. | *A star dies on the battlefield.* |
| **Sunfall** | 🔥 🔥 💧 🔥 🔥 | Rare | Offensive | Remove the 5 rightmost Essence of the target. | *A piece of the sun, dropped on purpose.* |
| **Elemental Fury** | 🔥 💧 🌪️ ❔ 🔥 | Legendary | Offensive | Remove 6 random Essence from random enemies (the same enemy can be hit more than once); heal 4. | *Everything, everywhere, all angry.* |
| **Tide of Ages** | 💧 ❔ 🌪️ ❔ 💧 | Legendary | Defensive | Heal 8; remove all your debuffs (frozen Essence, Blind, Confuse, Bleed, Silence); gain 4 Shield. | *The oldest water remembers how to mend.* |
| **World Tree's Blessing** | 💧 🌪️ 💧 🌪️ 💧 | Legendary | Defensive | **Power** (leaves your active row for the rest of the fight): At the start of each of your turns: heal 7; +3 random Essence now. | *The Last Tree gives back, every turn.* |
| **Maelstrom Grasp** | 💧 💧 🌪️ 💧 💧 | Legendary | Offensive | Steal 2 Essence of your choice from the target (they go to your bag); gain 4 Shield. | *The whirlpool swallows their strength and spits it out at your feet.* |
| **Abyssal Tide** | 💧 💧 🔥 💧 💧 | Legendary | Offensive | Remove the 3 leftmost Essence of all enemies; next turn you gain the removed Essence (conjured); Freeze 1 on all enemies. | *From the deep, cold hands.* |
| **Deluge** | 💧 💧 💧 💧 💧 | Legendary | Defensive | Gain 14 Shield; heal 10; Freeze 2 on all enemies. | *The flood answers.* |
