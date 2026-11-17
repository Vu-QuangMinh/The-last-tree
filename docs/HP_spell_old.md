# HP_spell_old

Enemies have HP instead of a row of Essence orbs: **1 orb = 3 HP**. Every spell from `data/orb_spell_old.json`, in HP terms (`data/HP_spell_old.json`): a reference only. The new cards are made one by one in `data/HP_spell_new.json`. The game still runs on `data/spells.json` (the orb version) until the enemies are switched over.

201 spells: 85 converted, 100 unchanged (nothing in them counts orbs), 16 need a redesign (they act on the enemy's orbs).

## Need a redesign (no HP equivalent) (16)

| Spell | Pattern | Rarity | Old card text | In HP terms |
|---|---|---|---|---|
| Dab | F | common | Repaint 2 Random. Lose 2 HP. | expose (Repaint enemy Essence): no HP equivalent |
| Chill | WW | common | Break an enemy's Armour. Gain 3 Shield for each Armour broken. | shatter (break enemy Armour (armour on orbs)): no HP equivalent |
| Updraft | A | common | Rearrange 2. | move (Rearrange enemy Essence): no HP equivalent |
| Undertow | WA | common | Rearrange 2. | move (Rearrange enemy Essence): no HP equivalent |
| Annihilate | FWA?WF | legendary | Annihilate 1 kind of Essence on all enemies. Durability 1. | annihilate (wipe out one element from every enemy): no HP equivalent |
| Alchemy | FWA | rare | Turn every Water of an enemy into Fire. | convert (turn an enemy's Essence of one element into another): no HP equivalent |
| The Flood | WWWWW | legendary | Deal 1 damage to every Fire of an enemy. | purge_all (remove every Essence of one element from an enemy): no HP equivalent |
| Riptide | WA | common | Rearrange 1. Apply 2 Weaken to an enemy. | move (Rearrange enemy Essence): no HP equivalent |
| Stain | AWW | rare | Each turn: Repaint 1 Random. | expose (Repaint enemy Essence): no HP equivalent |
| Fleck | A | common | Repaint 1 Random. | expose (Repaint enemy Essence): no HP equivalent |
| Spatter | AF | common | Repaint 1 Random. | expose (Repaint enemy Essence): no HP equivalent |
| Daub | FF | rare | Repaint 2 Random. | expose (Repaint enemy Essence): no HP equivalent |
| Seasickness | WAW | common | Apply 2 Weaken to all enemies. Break all enemies' Armour. | shatter (break enemy Armour (armour on orbs)): no HP equivalent |
| Splotch | AAW | rare | Repaint 3 Random. | expose (Repaint enemy Essence): no HP equivalent |
| Dustdevil | AAF | common | Rearrange 2. | move (Rearrange enemy Essence): no HP equivalent |
| Frozen Tomb | WWAW | legendary | Apply 2 Stun to an enemy. Repaint 2 Random. Cooldown 2. | expose (Repaint enemy Essence): no HP equivalent |

## Converted (85)

| Spell | Pattern | Rarity | Old card text | In HP terms |
|---|---|---|---|---|
| Ember | F | common | Apply 1 Burn to an enemy. Lose 2 HP. | Burn 1 -> Burn 3 (loses that much HP at the start of its turn) |
| Fire Ball | FF | common | Deal 1 Right damage to an enemy. | 1 Right damage -> 3 damage |
| Arcane Barrage | WFA | common | Randomly deal 1 damage 3 times. | 3 hits of 1 -> 3 hits of 3 damage |
| Flare | FF | common | Apply 1 Burn to an enemy for every 2 Fire in your chant. | Burn 1 -> Burn 3 (loses that much HP at the start of its turn) |
| Gust | AF | common | Snipe 2. Gain 2 Vulnerable. | Snipe 2 -> 6 damage |
| Wildfire | FA | common | Apply 1 Burn to all enemies. | Burn 1 -> Burn 3 (loses that much HP at the start of its turn) |
| Blowtorch | FA | common | Deal 1 Right damage to an enemy. +1 if it has Burn. | 1 Right damage -> 3 damage |
| Scald | FW | common | Deal 1 Right damage and apply 1 Weaken to an enemy. | 1 Right damage -> 3 damage |
| Boil | FW | common | Wild Repaint 3 Fire. | Wild Repaint -> Self-Repaint (your chant only: enemies have no Essence to paint) |
| Inferno | F?F | rare | Deal 1 Right damage to all enemies. | 1 Right damage -> 3 damage |
| Thermal Burst | FFWF | rare | Deal 2 Left damage to 2 different enemies. | 2 Left damage -> 6 damage |
| Cataclysm | AF?FA | rare | Apply 3 Burn to all enemies. Cooldown 2. | Burn 3 -> Burn 9 (loses that much HP at the start of its turn) |
| Kindling Wind | FAF | rare | Amplify 1. | Amplify 1 -> Amplify 3 (HP) |
| Whirlpool | AWA | rare | Deal 1 Right damage and apply 1 Weaken to all enemies. Durability 3. | 1 Right damage -> 3 damage |
| Searing Mist | FFW | rare | Remove up to 3 Fire from an enemy. | remove up to 3 F -> 9 damage (no element on an HP bar) |
| Against the Tide | WWF | rare | Deal 2 Random damage to an enemy. If it's attacking, apply 1 Weaken to it. | 2 Random damage -> 6 damage |
| Vacuum | AAF | rare | Remove up to 3 Air from an enemy. | remove up to 3 A -> 9 damage (no element on an HP bar) |
| Storm Front | AWF | rare | Gain 5 Shield. Gain 2 Thorns this turn. | Thorns 2 -> Thorns 6 (HP) |
| Backdraft | AFF | rare | Deal 3 Right damage to an enemy. Durability 2. | 3 Right damage -> 9 damage |
| Meteor | FFFF | legendary | Deal 5 Right damage to an enemy. | 5 Right damage -> 15 damage |
| Paintress | WWWW | legendary | Wild Repaint 5 Random. | Wild Repaint -> Self-Repaint (your chant only: enemies have no Essence to paint) |
| Hurricane | AAAA | legendary | Deal 3 Right damage to all enemies. | 3 Right damage -> 9 damage |
| Pyromaniac | FFF | rare | Your Burn +1. Apply 1 Burn to all enemies. | passive burn_bonus 1 -> 3; Burn 1 -> Burn 3 (loses that much HP at the start of its turn) |
| Siphon | AWAWA | rare | Instant Steal 1. | Steal 1 -> deal 3 damage and gain 1 Essence (random element: there is no orb to take) |
| EleMantle | WFA | rare | Each time you are attacked, gain 1 Thorns for the whole fight. | passive thorns_on_hit 1 -> 3 |
| Graft | WF | common | Wild Repaint 2 Water. | Wild Repaint -> Self-Repaint (your chant only: enemies have no Essence to paint) |
| Ember Crown | FFW | rare | Each turn: apply 1 Burn to a random enemy. | Burn 1 -> Burn 3 (loses that much HP at the start of its turn) |
| Absorb | FAW | rare | Deal 2 Right damage to an enemy. If it dies, heal 5 HP. | 2 Right damage -> 6 damage |
| Devil's Hand | AFA? | rare | Steal 2 Essence from an enemy. Lose 5 HP. Durability 3. | Steal 2 -> deal 6 damage and gain 2 Essence (random element: there is no orb to take) |
| A Broken Clock | ????? | rare | Gain 1 Random next turn. Deal 1 Right damage to a random enemy. | 1 Right damage -> 3 damage |
| Pyromancy | FFFA | rare | Each turn: apply 1 Burn to a random enemy. | Burn 1 -> Burn 3 (loses that much HP at the start of its turn) |
| Ludwig's Knife | AAAFF | legendary | Each time you Chant: Instant Steal 1. | each Chant: Instant Steal 1 -> deal 3 damage and gain 1 Essence into your chant |
| Dranor's Avatar | FFFFA | legendary | Your Release applies 1 Burn to every enemy it hits. Lose 15 HP. | passive strike_burn 1 -> 3 |
| Ludwig's Hand | WAW? | legendary | Instant Steal 1. | Steal 1 -> deal 3 damage and gain 1 Essence (random element: there is no orb to take) |
| Siren's Call | WA?AW | rare | Steal 2 Essence from an enemy. | Steal 2 -> deal 6 damage and gain 2 Essence (random element: there is no orb to take) |
| Ludwig's Final Touch | WWA?WW | legendary | Steal 3 Essence from an enemy. | Steal 3 -> deal 9 damage and gain 3 Essence (random element: there is no orb to take) |
| Breeze | A | common | Gain 2 Thorns this turn. | Thorns 2 -> Thorns 6 (HP) |
| Tinder | F | common | Apply 1 Burn to a random enemy. | Burn 1 -> Burn 3 (loses that much HP at the start of its turn) |
| Ashfall | F | rare | Apply 1 Burn to all enemies. Cooldown 1. | Burn 1 -> Burn 3 (loses that much HP at the start of its turn) |
| Smolder | FFFFF | legendary | Deal 3 Right damage and apply 4 Burn to all enemies. Cooldown 3. | 3 Right damage -> 9 damage; Burn 4 -> Burn 12 (loses that much HP at the start of its turn) |
| Splash | W | common | Snipe 1 Fire. | Snipe 1 -> 3 damage |
| Flame Lash | FF | common | Apply 1 Burn to 2 different enemies. | Burn 1 -> Burn 3 (loses that much HP at the start of its turn) |
| Tide Ward | WW | common | Gain 3 Thorns this turn. | Thorns 3 -> Thorns 9 (HP) |
| Whirl | AA | common | Wild Rearrange 1. | Wild Rearrange -> Rearrange (your chant only) |
| Wild Flame | F?? | rare | Apply 3 Burn to an enemy. | Burn 3 -> Burn 9 (loses that much HP at the start of its turn) |
| Twin Comets | FF | rare | Apply 2 Burn to 2 different enemies. | Burn 2 -> Burn 6 (loses that much HP at the start of its turn) |
| Undercurrent | WW | rare | Steal up to 2 Water from an enemy. Durability 1. | Steal 2 -> deal 6 damage and gain 2 Essence (random element: there is no orb to take) |
| Cinder Rain | AF | rare | Randomly deal 1 damage 3 times. | 3 hits of 1 -> 3 hits of 3 damage |
| Phoenix Feather | F? | legendary | Apply 2 Burn to an enemy. | Burn 2 -> Burn 6 (loses that much HP at the start of its turn) |
| Adam's Fervor | FA | rare | Apply 1 Burn to all enemies. Double all enemies' Burn. Durability 2. | Burn 1 -> Burn 3 (loses that much HP at the start of its turn) |
| Thieving Wind | AA? | rare | Steal 1 Essence from an enemy. | Steal 1 -> deal 3 damage and gain 1 Essence (random element: there is no orb to take) |
| Updraft Lance | AF | common | Deal 1 Right damage to 2 random enemies. | 1 Right damage -> 3 damage |
| Heat Haze | FA | rare | Apply 1 Burn to all enemies. | Burn 1 -> Burn 3 (loses that much HP at the start of its turn) |
| Coal Toss | FF | common | Deal 2 Right damage to a random enemy. | 2 Right damage -> 6 damage |
| Daedalus's Trigger | FAF | legendary | Your Snipes deal 1 more damage. Snipe 1. | passive snipe_bonus 1 -> 3; Snipe 1 -> 3 damage |
| Frost Burn | FFW | rare | Apply 2 Burn to an enemy. Then if it has 4+ Burn, apply 1 Stun to it. | Burn 2 -> Burn 6 (loses that much HP at the start of its turn); its condition: 4+ Burn -> 12+ Burn |
| Ember Storm | FAF | common | Apply 1 Burn to all enemies. | Burn 1 -> Burn 3 (loses that much HP at the start of its turn) |
| Sky Lance | AAA | common | Snipe 2. | Snipe 2 -> 6 damage |
| Unholy Fire | F?F | legendary | Apply 4 Burn to an enemy. Lose 2 HP. | Burn 4 -> Burn 12 (loses that much HP at the start of its turn) |
| Molten Core | FWF | rare | Apply 1 Burn to a random enemy. | Burn 1 -> Burn 3 (loses that much HP at the start of its turn) |
| Gale Slash | AFFA | common | Deal 1 Left damage to an enemy. | 1 Left damage -> 3 damage |
| Wind Shear | AWF | common | Deal 2 Right damage to an enemy. | 2 Right damage -> 6 damage |
| Brimstone | FFF | rare | Apply 2 Burn to all enemies. | Burn 2 -> Burn 6 (loses that much HP at the start of its turn) |
| Ice Lance | WWA | common | Deal 3 Random damage and apply 1 Stun to an enemy. Durability 1. | 3 Random damage -> 9 damage |
| Glacial Spike | WFA | rare | Deal 2 Left damage to 2 different enemies. | 2 Left damage -> 6 damage |
| Daedalus's Barrel | FFFA | rare | Snipe 3. | Snipe 3 -> 9 damage |
| Storm Legion | AAAF | rare | Randomly deal 1 damage 4 times. | 4 hits of 1 -> 4 hits of 3 damage |
| Steam Titan | FWFW | legendary | Deal 3 Right damage to an enemy. Gain 5 Shield. Apply 2 Burn to it. | 3 Right damage -> 9 damage; Burn 2 -> Burn 6 (loses that much HP at the start of its turn) |
| Ludwig's Backup Plan | W?A | rare | Instant Steal 2. Lose 5 HP. | Steal 2 -> deal 6 damage and gain 2 Essence (random element: there is no orb to take) |
| Burn Burn Burn! | F?FA | rare | Apply 2 Burn to all enemies. Double all enemies' Burn. Durability 1. | Burn 2 -> Burn 6 (loses that much HP at the start of its turn) |
| Cyclone Edge | A?AF | rare | Deal 2 Left damage to all enemies. | 2 Left damage -> 6 damage |
| Forge Fire | FFWW | common | Gain 6 Shield. Gain 1 Thorns for the whole fight. | passive thorns 1 -> 3 |
| Sulfuric Pit | AFAF | common | Apply 2 Burn to all enemies. Cooldown 1. | Burn 2 -> Burn 6 (loses that much HP at the start of its turn) |
| Blood Moon | FWWF | rare | Deal 2 Right damage to all enemies. | 2 Right damage -> 6 damage |
| Solar Flare | FFAFF | legendary | Deal 3 Right damage and apply 3 Burn to all enemies. Durability 2. | 3 Right damage -> 9 damage; Burn 3 -> Burn 9 (loses that much HP at the start of its turn) |
| Elemental Fury | F?A?W | legendary | Randomly deal 1 damage 6 times. | 6 hits of 1 -> 6 hits of 3 damage |
| Surgical Burn | F?A?F | rare | Apply 6 Burn to an enemy. Durability 1. | Burn 6 -> Burn 18 (loses that much HP at the start of its turn) |
| Eclipse | FFWFF | rare | Deal 5 Right damage to an enemy. Durability 2. | 5 Right damage -> 15 damage |
| World's End | FWA?AW | legendary | Deal 5 Right damage and apply 3 Burn to all enemies. Durability 1. | 5 Right damage -> 15 damage; Burn 3 -> Burn 9 (loses that much HP at the start of its turn) |
| Thorn Dart | AW | common | Snipe 1. | Snipe 1 -> 3 damage |
| Daedalus's Scope | AFA | rare | Snipe 2. | Snipe 2 -> 6 damage |
| Daedalus's Perpetual Motion | FAAF | legendary | Each turn: snipe 1. | Snipe 1 -> 3 damage |
| Desperate Measure | AFA | legendary | Apply 6 Burn to an enemy. Heal 6 HP. Gain 6 max HP. All your spells have Durability 1 this fight. | Burn 6 -> Burn 18 (loses that much HP at the start of its turn) |
| Trinity - First Fragment | FF | common | Snipe 1. | Snipe 1 -> 3 damage |
| Trinity | FWA | legendary |  | Snipe 3 -> 9 damage |

## Unchanged (100)

| Spell | Pattern | Rarity | Old card text | In HP terms |
|---|---|---|---|---|
| Droplet | W | common | Gain 2 Shield. | same |
| Ripple | W | common | Self-Repaint 2 Water. | same |
| Whisper | A | common | Apply 1 Weaken to an enemy. | same |
| Water Wall | WW | common | Gain 4 Shield. | same |
| Tide Pool | WW | common | Heal 3 HP. | same |
| Frost Nova | WW | common | Apply 1 Weaken to all enemies. | same |
| Tailwind | AA | common | Gain 1 Random next turn. | same |
| Fan the Flames | FWF | common | Double an enemy's Burn. Durability 2. | same |
| All In | F | rare | Infuse your upcoming Essence. | same |
| Steam | WF | common | Gain 2 Shield. Apply 1 Weaken to an enemy. | same |
| Hot Spring | WF | common | Heal 2 HP. Gain 1 Shield. | same |
| Mist Veil | WA | common | Become Ethereal this turn. Gain 3 Vulnerable. Durability 1. | same |
| Rain | AW | common | Heal 2 HP. | same |
| Glacier | WWW | rare | Apply 1 Stun to an enemy. Durability 2. | same |
| Tempest | AAA | rare | Gain 2 Random next turn. Self-Rearrange 1. | same |
| Steam Cloud | WFW | rare | Apply 1 Dazed to all enemies. Gain 4 Shield. | same |
| Mistwalk | WAW | rare | Become Ethereal this turn. Heal 4 HP. Durability 2. | same |
| Recall | FAW | rare | Refund 2. | same |
| Steam Engine | FWFW | legendary | Each time you apply Burn to an enemy, gain 2 Shield. | same |
| Aurora | WAWA | rare | Heal 7 HP. Cleanse all your debuffs. Gain 5 Shield. | same |
| Ludwig's Boots | FAFA | rare | Gain 1 Evasion. | same |
| Damnation | ?W?F | legendary | Apply 3 Weaken and apply 2 Dazed to an enemy. Durability 1. | same |
| Clear Sight | F | common | Cure Blind. Cure Confuse. | same |
| Bandage | W | common | Cure Poison. Heal 1 HP. Enemy thorns don't hurt you this turn. | same |
| Borrowed Breath | A | common | Gain 1 Random next turn. | same |
| Conjure Flame | FA | common | Conjure 1 offensive spell. | same |
| Summon Rain | WW | common | Infuse 2 Water. | same |
| Steady Mind | AA | common | Cure Confuse. Gain 1 Air next turn. | same |
| Unbind | AW | common | Cure Silence, Frozen and Ignited. Heal 2 for each one cured. | same |
| Cauterize | FW | rare | Enemies can't Mend. | same |
| Alchemist's Breath | AF | common | Turn 2 unused Essence into Fire. | same |
| Blood Price | FF | rare | Lose 3 HP. Gain 3 Random. | same |
| Ward | WA | common | Gain 1 Evasion. Cooldown 2. | same |
| Gale Barrier | AA | common | Gain 3 Lasting Shield. | same |
| Spritz | WW | rare | Self-Repaint 2 Random. | same |
| Mimic | FW | rare | Your next spell this fight is cast twice. Cooldown 2. | same |
| Aole's Blessing | AAA | rare | Each turn: gain 1 Random. | same |
| Water Prison | WWW | rare | Each turn: gain 5 Lasting Shield. Your chant holds at most 6 Essence. | same |
| Echoed Voice | AWAF | legendary | Your first spell each turn is cast twice. | same |
| Aole's Love | FWA | legendary | Pick 1 Essence. Gain 1 of that Essence each turn. | same |
| Purify | WWA | rare | Cleanse all your debuffs. Gain 4 Lasting Shield for each one. | same |
| Reforge | WFF | rare | Seal 1 Essence of another spell for this fight. Durability 1. | same |
| Stillness | ? | rare | Apply 99 Weaken to all enemies. Durability 1. | same |
| Misdirection | AWAW | legendary | Gain 1 Evasion. | same |
| Aole's Avatar | WAWAW | legendary | Each turn: gain 1 Fire; gain 1 Water; gain 1 Air; lose 3 HP. | same |
| Spark Word | WA | common | Infuse 1 Fire. | same |
| Spring Word | AF | common | Infuse 1 Water. | same |
| Breath Word | FW | common | Infuse 1 Air. | same |
| Resonance | AFW | rare | Duplicate 1. Heal 3 HP for each Extension it causes. | same |
| Open Grimoire | WFWA | legendary | Add 2 random spells from your spellbook to this fight. | same |
| Drizzle | W | common | Heal 2 HP. | same |
| Spark Shower | F | common | Gain 1 Fire next turn. | same |
| Summoning Word | A | rare | Conjure 1 spell. | same |
| Calm Waters | W | legendary | Gain 5 Lasting Shield. | same |
| Still Air | A | legendary | Gain 1 Evasion. Heal 6 HP. Durability 1. | same |
| Wisp | A | common | Infuse 1 Random. | same |
| Steam Burst | FW | common | Gain 3 Shield. | same |
| Mist Step | WA | common | Infuse 1 Random. | same |
| Rain Song | AWA | common | Heal 2 HP. Gain 1 Water next turn. | same |
| Wellspring Rite | ?W | rare | Heal 3 HP. | same |
| Gale Call | A? | rare | Conjure 2 spells. | same |
| Crosswind | AA | rare | Apply 1 Weaken to all enemies. | same |
| Arctic Wind | WA | rare | Apply 1 Stun to an enemy. Durability 1. | same |
| Hailstone | AW | common | Apply 2 Weaken to an enemy. | same |
| Quiet Wind | AAWA | common | Gain 2 Shield. | same |
| Tidecaller | A?A | rare | Infuse 1 Water. Infuse 1 Any Essence. | same |
| Kindled Heart | FW | rare | Gain 1 Evasion. Cooldown 2. | same |
| Moonlight on a Still Lake | WW | legendary | Duplicate 2. | same |
| Fog of War | FW | rare | Apply 1 Dazed to all enemies. | same |
| Hush of Rain | AWW | common | Heal 2 HP. | same |
| Smoke Signal | AF | common | Conjure 1 spell. | same |
| Ripplewind | WA | common | Self-Repaint 3 Water. | same |
| Shadows in the Flame | FFA | rare | Conjure 2 spells. | same |
| Tsunami Ward | WWW | rare | Gain 6 Shield. | same |
| Frostbite | WAW | rare | Apply 1 Stun to an enemy. Cooldown 2. | same |
| Tempest Veil | AWA | rare | Gain 4 Lasting Shield. | same |
| Healing Rain | WWA | common | Heal 5 HP. | same |
| Deep Freeze | W?W | legendary | Apply 2 Stun to all enemies. Gain 10 Lasting Shield. Durability 1. | same |
| Silent Tide | WFW | rare | Gain 3 Shield. | same |
| Windless Night | AFA | common | Gain 3 Shield. | same |
| Cinder Shield | FWW | common | Gain 5 Shield. | same |
| Rainbow Bridge | FWA | legendary | Conjure 2 spells. Gain 3 Random next turn. | same |
| Hearth Song | FAW | rare | Heal 4 HP. | same |
| Soothing Mist | WAAF | common | Heal 1 HP. | same |
| Ashen Veil | FAA | rare | Become Ethereal this turn. Gain 2 Vulnerable. Durability 2. | same |
| Sunlit Grove | WAF | common | Heal 4 HP. | same |
| Maelstrom Ward | WWWA | rare | Gain 8 Shield. | same |
| Sky Sovereign | AAWA | legendary | Conjure 2 spells. Infuse 2 Random. | same |
| Moon Tide | W?WA | rare | Heal 7 HP. | same |
| Ember Chorus | FWAF | rare | Conjure 3 spells. | same |
| Panic Button | WAAW | common | Heal 5 HP. Apply 1 Stun to all enemies. Durability 1. | same |
| Heaven's Gale | AAWA | legendary | Conjure 3 spells. Gain 1 Evasion. | same |
| You Shall Not Pass | WAWA | legendary | Heal 5 HP. Gain 5 Shield. | same |
| Storm Sermon | A?W?A | rare | Apply 2 Stun to all enemies. Exhaust. | same |
| Handyman | FW | rare | Your spells with Durability get +1 Durability. | same |
| Disturbance | FWA | legendary | Whenever an Essence is added to or removed from your chant after you Chant, deal 1 damage to that Essence of a random enemy. | same |
| Braum's Resolve | AAA | rare | All your Shield is Lasting. | same |
| Trinity - Second Fragment | WW | common | Gain 1 Shield. | same |
| Trinity - Third Fragment | AA | common | Heal 1 HP. | same |
| Summoning Bill |  | unique |  | same |
