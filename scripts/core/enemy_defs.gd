class_name EnemyDefs
extends RefCounted
## Every enemy: Essence pattern (elements, left to right), moves (cycled in order), passives.
## Moves are used in the listed order, looping. Normal enemies mix offence, defence and utility.
## Move kinds: attack {n, hits}, armor {pos}, mend {el, n, who: self/ally/all}, shuffle, silence {turns}, frail {turns},
## lock {len}, steal {n}, confuse, blind {turns}, bleed {n}, freeze {n}, ethereal, empower {n}, brittle {turns},
## summon {id, n}, toll, invert, hex, mimic. A move may carry `also` (a second move done the same turn).

const E := {
	# ---------------- act 1: the Verdant Circle (druids, changed animals, elemental spirits). tier = how early in the
	# act it can show up (see ENCOUNTERS_ACT1); its Essence is exactly its pattern (no extra Essence on deeper floors).
	"ashling": {"name": "Ashling", "act": 1, "tier": 1.0, "hp": "FFA", "moves": [{"kind": "attack", "n": 3}],
		"flavor": "A small fire spirit."},
	"iceling": {"name": "Iceling", "act": 1, "tier": 1.0, "hp": "WWA", "moves": [{"kind": "attack", "n": 3}],
		"flavor": "A small ice spirit."},
	"zephling": {"name": "Zephling", "act": 1, "tier": 1.0, "hp": "AAW", "moves": [{"kind": "attack", "n": 3}],
		"flavor": "A small air spirit."},
	"purple_slime": {"name": "Purple Slime", "act": 1, "tier": 1.5, "hp": "WFWAW", "moves": [{"kind": "attack", "n": 4}],
		"flavor": "Wobbly, wet and purple."},
	"green_slime": {"name": "Green Slime", "act": 1, "tier": 1.5, "hp": "AWAFA", "moves": [{"kind": "attack", "n": 4}],
		"flavor": "Light as air, for a slime."},
	"yellow_slime": {"name": "Yellow Slime", "act": 1, "tier": 1.5, "hp": "FAFWF", "moves": [{"kind": "attack", "n": 4}],
		"flavor": "Warm to the touch. Don't touch it."},
	"bramble_back": {"name": "Bramble Back", "act": 1, "tier": 2.0, "hp": "FAFWFAF", "moves": [{"kind": "attack", "n": 5}], "passives": ["thorns"],
		"flavor": "An enraged porcupine on two legs."},
	"winged_tortoise": {"name": "Winged Tortoise", "act": 1, "tier": 2.0, "hp": "WAWWAWW", "moves": [{"kind": "armor", "pos": -1}, {"kind": "attack", "n": 5}],
		"flavor": "A shell that learned to fly."},
	"leech_bat": {"name": "Leech Bat", "act": 1, "tier": 2.5, "hp": "AFAWAFA", "moves": [{"kind": "attack", "n": 5, "also": {"kind": "mend", "el": "random", "n": 1, "who": "self"}}],
		"flavor": "Shiny fangs, and it feeds on every bite."},
	"hush_moth": {"name": "Hush Moth", "act": 1, "tier": 2.0, "hp": "AWAAWAW", "moves": [{"kind": "silence", "turns": 1}, {"kind": "attack", "n": 5}],
		"flavor": "Its wings steal your words."},
	"cinder_hound": {"name": "Cinder Hound", "act": 1, "tier": 2.5, "hp": "FFAFFWFFAF", "moves": [{"kind": "attack", "n": 6}], "passives": ["burn_immune"],
		"flavor": "Flame Essence burns under its skin like tattoos."},
	"mirror_fairy": {"name": "Mirror Fairy", "act": 1, "tier": 2.5, "hp": "AWFWAAWFWA", "moves": [{"kind": "confuse"}, {"kind": "attack", "n": 6}],
		"flavor": "A fairy's face in a mirror, her hands gripping it from behind."},
	"yeti": {"name": "Yeti", "act": 1, "tier": 2.5, "hp": "WWAWWAWWAWWA", "moves": [{"kind": "freeze", "n": 2}, {"kind": "attack", "n": 7}],
		"flavor": "Big, white and very cold."},
	"greenseer": {"name": "Greenseer", "act": 1, "tier": 3.0, "hp": "AWFAWAFWAWFAW", "moves": [{"kind": "summon", "ids": ["purple_slime", "green_slime", "yellow_slime"], "n": 1}, {"kind": "mend", "el": "random", "n": 2, "who": "self"}, {"kind": "attack", "n": 6}],
		"flavor": "A druid in moss clothes under a big mushroom hat."},
	"rolling_bear": {"name": "Rolling Bear", "act": 1, "tier": 3.0, "hp": "FWFAFWFAFWFAFWF", "moves": [{"kind": "attack", "n": 3, "also": {"kind": "empower", "n": 2}}],
		"flavor": "It rolls. It never stops rolling."},
	"giant_slime": {"name": "Giant Slime", "act": 1, "tier": 3.0, "hp": "FWAFWAFWAF", "moves": [{"kind": "attack", "n": 7}], "passives": ["slime_burst"],
		"flavor": "A giant rainbow slime."},
	"tomato_knight": {"name": "Tomato Knight", "act": 1, "tier": 3.0, "hp": "FFWFFAFFWFFAFFW", "moves": [{"kind": "armor", "pos": -1}, {"kind": "attack", "n": 7}],
		"moves2": [{"kind": "attack", "n": 4, "hits": 2}], "passives": ["rage_at_half"],
		"flavor": "Ripe, red and armoured."},
	# ---------------- in reserve (not in any act's pool for now; kept to reuse in later acts)
	"puddle_slime": {"name": "Puddle Slime", "act": 0, "hp": "WAW", "moves": [{"kind": "attack", "n": 3}, {"kind": "mend", "el": "W", "n": 1, "who": "self"}, {"kind": "frail", "turns": 1}],
		"flavor": "It keeps refilling itself."},
	"gale_sprite": {"name": "Gale Sprite", "act": 0, "hp": "AFA", "moves": [{"kind": "attack", "n": 3, "hits": 2}, {"kind": "armor", "pos": 0}, {"kind": "freeze", "n": 1}],
		"flavor": "Two quick jabs of wind."},
	"stone_knight": {"name": "Stone Knight", "act": 0, "hp": "FFW", "moves": [{"kind": "armor", "pos": 1}, {"kind": "attack", "n": 8}, {"kind": "frail", "turns": 1, "also": {"kind": "attack", "n": 3}}],
		"flavor": "Braces, then swings."},
	"tidecaller": {"name": "Tidecaller", "act": 0, "hp": "WAWA", "moves": [{"kind": "mend", "el": "W", "n": 1, "who": "self"}, {"kind": "attack", "n": 5}, {"kind": "freeze", "n": 1}],
		"flavor": "The tide always comes back."},
	"mirror_wisp": {"name": "Mirror Wisp", "act": 0, "hp": "AWF", "moves": [{"kind": "attack", "n": 4, "also": {"kind": "shuffle"}}, {"kind": "blind", "turns": 1}, {"kind": "armor", "pos": 0}],
		"flavor": "Never in the same order twice."},
	"frost_hex": {"name": "Frost Hex", "act": 0, "hp": "WWA", "moves": [{"kind": "freeze", "n": 1}, {"kind": "attack", "n": 4}, {"kind": "mend", "el": "W", "n": 1, "who": "self"}],
		"flavor": "Your fingers go numb."},
	"pickpocket_imp": {"name": "Pickpocket Imp", "act": 0, "hp": "AFA", "moves": [{"kind": "steal", "n": 1}, {"kind": "attack", "n": 4}, {"kind": "armor", "pos": 0}],
		"flavor": "It wears what it steals."},
	# ---------------- act 2
	"splitter_ooze": {"name": "Splitter Ooze", "act": 2, "hp": "WWFF", "moves": [{"kind": "attack", "n": 4}, {"kind": "mend", "el": "random", "n": 1, "who": "self"}, {"kind": "frail", "turns": 2}], "passives": ["split"],
		"flavor": "Hit it wrong and there are two."},
	"overgrowth_vine": {"name": "Overgrowth Vine", "act": 2, "hp": "FAWA", "moves": [{"kind": "attack", "n": 4}, {"kind": "armor", "pos": 0}, {"kind": "bleed", "n": 2}], "passives": ["overgrowth"],
		"flavor": "Ignore it and it grows."},
	"toll_keeper": {"name": "Toll Keeper", "act": 2, "hp": "WWAW", "moves": [{"kind": "toll"}, {"kind": "attack", "n": 5}, {"kind": "armor", "pos": 1}],
		"flavor": "Every word costs extra."},
	"hexer": {"name": "Hexer", "act": 2, "hp": "FWA", "moves": [{"kind": "hex"}, {"kind": "attack", "n": 4}, {"kind": "mend", "el": "random", "n": 1, "who": "ally"}],
		"flavor": "Marks your Essence with pain."},
	"shrine_maiden": {"name": "Shrine Maiden", "act": 2, "hp": "WAW", "moves": [{"kind": "mend", "el": "random", "n": 1, "who": "all"}, {"kind": "attack", "n": 3}, {"kind": "frail", "turns": 1}],
		"flavor": "She mends everyone but you."},
	"blinding_beetle": {"name": "Blinding Beetle", "act": 2, "hp": "FAF", "moves": [{"kind": "blind", "turns": 2}, {"kind": "attack", "n": 4}, {"kind": "empower", "n": 1}],
		"flavor": "A flash, and everything blurs."},
	# ---------------- act 3
	"inverter": {"name": "Inverter", "act": 3, "hp": "FWFW", "moves": [{"kind": "invert"}, {"kind": "attack", "n": 5}, {"kind": "armor", "pos": 0}],
		"flavor": "Fire becomes water, water becomes fire."},
	"warded_golem": {"name": "Warded Golem", "act": 3, "hp": "FFWWAA", "moves": [{"kind": "attack", "n": 5}, {"kind": "armor", "pos": 2}, {"kind": "frail", "turns": 1}], "passives": ["warded"],
		"flavor": "Short chants bounce off."},
	"echo_wraith": {"name": "Echo Wraith", "act": 3, "hp": "AWAF", "moves": [{"kind": "confuse"}, {"kind": "attack", "n": 2}, {"kind": "mend", "el": "random", "n": 1, "who": "self"}], "passives": ["echo"],
		"flavor": "Everything it does, it does twice."},
	"mimic_chest": {"name": "Mimic Chest", "act": 3, "hp": "FWAF", "moves": [{"kind": "mimic"}, {"kind": "attack", "n": 6}, {"kind": "armor", "pos": 0}],
		"flavor": "It becomes your last words, backwards."},
	"last_gasp_spore": {"name": "Last Gasp Spore", "act": 3, "hp": "AWW", "moves": [{"kind": "attack", "n": 3}, {"kind": "mend", "el": "W", "n": 1, "who": "self"}, {"kind": "bleed", "n": 1}], "passives": ["last_gasp"],
		"flavor": "Bursts when it dies."},
	"storm_imp": {"name": "Storm Imp", "act": 3, "hp": "AAF", "moves": [{"kind": "attack", "n": 1, "hits": 3}, {"kind": "ethereal"}, {"kind": "empower", "n": 1}],
		"flavor": "Flickers out of reach."},
	# ---------------- elites
	"storm_rider": {"name": "Storm Rider", "act": 2, "elite": true, "hp": "AAFAA", "moves": [{"kind": "attack", "n": 3, "hits": 2}, {"kind": "attack", "n": 2, "also": {"kind": "shuffle"}}],
		"flavor": "Fast, and hard to read."},
	"lockwarden": {"name": "Lockwarden", "act": 2, "elite": true, "hp": "WFWAF", "moves": [{"kind": "lock", "len": 2}, {"kind": "attack", "n": 5}, {"kind": "attack", "n": 5}],
		"flavor": "Chains your spells shut."},
	"tide_colossus": {"name": "Tide Colossus", "act": 3, "elite": true, "hp": "WWWWFW", "moves": [{"kind": "mend", "el": "W", "n": 2, "who": "self"}, {"kind": "attack", "n": 8}],
		"flavor": "A wave that stands up."},
	# The Triplet (a mini boss of three separate enemies): one spirit of each element, each with its own cycle of moves.
	# They START at different points of it ("start"); a stun or a death can bring them in step later, and that's fine.
	# Their support moves land on one of the three at random: the fire one gives Power +1, the air one Armour, and the
	# water one heals 1 Essence (that sprite's own element, never past 5), always on a hurt one if any is hurt.
	"triplet_fire": {"name": "Ember Sprite", "act": 1, "elite": true, "member": true, "start": 0, "hp": "FFFFF",
		"moves": [{"kind": "ignite_spell", "turns": 1}, {"kind": "attack", "n": 3}, {"kind": "empower", "n": 1, "who": "random"}],
		"flavor": "Sets your words on fire."},
	"triplet_water": {"name": "Ripple Sprite", "act": 1, "elite": true, "member": true, "start": 1, "hp": "WWWWW",
		"moves": [{"kind": "freeze", "n": 1}, {"kind": "attack", "n": 3}, {"kind": "mend", "el": "own", "n": 1, "who": "random_hurt", "cap": 5}],
		"flavor": "Freezes your Essence."},
	"triplet_air": {"name": "Zephyr Sprite", "act": 1, "elite": true, "member": true, "start": 2, "hp": "AAAAA",
		"moves": [{"kind": "silence", "turns": 1}, {"kind": "attack", "n": 3}, {"kind": "armor", "pos": -1, "who": "random"}],
		"flavor": "Steals your voice."},
	# Enraged Rolling Bear (a mini boss): bigger, red fur. It attacks every turn, and every time you gain Shield it
	# gains Power +1 (once per separate gain).
	"enraged_bear": {"name": "Enraged Rolling Bear", "act": 1, "elite": true, "hp": "FWFAFWFAFWFA", "passives": ["shield_rage"],
		"tint": Color(0.78, 0.16, 0.12), "size": 1.3,
		"moves": [{"kind": "attack", "n": 4}],
		"flavor": "Hide behind a shield and it only gets angrier."},
	"bramble_matron": {"name": "Bramble Matron", "act": 1, "elite": true, "hp": "WFAWFAW", "walls": 3, "passives": ["briar_walls"],
		# her own turn (planned when her intent shows): a wall down -> regrow it; both up -> sing / attack, in turn.
		# Each wall attacks on its own, in this pattern.
		"moves": [{"kind": "sing"}, {"kind": "attack", "n": 1, "hits": 2}],
		"wall_moves": [{"kind": "attack", "n": 2, "hits": 1}, {"kind": "attack", "n": 1, "hits": 2}, {"kind": "attack", "n": 1, "hits": 3}],
		"flavor": "A hedge that sings."},
	"mirror_knight": {"name": "Mirror Knight", "act": 2, "elite": true, "hp": "WAFWAF", "moves": [{"kind": "armor", "pos": 0, "also": {"kind": "attack", "n": 5}}, {"kind": "shuffle", "also": {"kind": "attack", "n": 7}}],
		"flavor": "Its guard is where you least expect."},
	"void_archon": {"name": "Void Archon", "act": 3, "elite": true, "hp": "AFWAFWA", "moves": [{"kind": "blind", "turns": 2, "also": {"kind": "attack", "n": 5}}, {"kind": "lock", "len": 2}, {"kind": "attack", "n": 4, "hits": 3}],
		"flavor": "It steals the light, then the words."},
	# ---------------- bosses (moves2 = second phase, at half HP)
	# The Yin Yang Beast (an Act 1 boss): black and white. Inversion (3 of your spells flip: spell <-> anti-spell, and it
	# turns the other colour) -> Roar (silence 2 spells, a small hit) -> a 3-turn Charge (an hourglass), then a big hit.
	# While it charges, each spell of the OTHER colour you cast (white: spells, black: anti-spells) lowers the hit by 5,
	# each of its own colour raises it by 5 (never below 0). None of that is told in the fight: the Codex explains it.
	# When it dies it splits into two clones (one white, one black, out of step) that do the same at a smaller size.
	"yin_yang_beast": {"name": "Yin Yang Beast", "act": 1, "boss": true, "hp": "FWAFWAFWAFWAFWAFWAFWAFWAFWAFWA", "yin": "white",
		"passives": ["yinyang_split"],
		"moves": [{"kind": "invert_spells", "n": 3}, {"kind": "silence", "turns": 1, "n": 2, "also": {"kind": "attack", "n": 5}},
			{"kind": "charge", "left": 3, "n": 30}, {"kind": "charge", "left": 2}, {"kind": "charge", "left": 1, "hit": true}],
		"flavor": "Two halves of one temper."},
	# The Cubs both flip a spell first. Then the white one charges while the black one roars every turn (silence 2,
	# hit for 2); once the white one's hit lands they swap, and so on.
	"yin_yang_clone": {"name": "Yin Yang Cub", "act": 1, "member": true, "hp": "FWAFWAFWAF", "yin": "white",
		"opener": [{"kind": "invert_spells", "n": 1}],
		"moves": [{"kind": "charge", "left": 3, "n": 10}, {"kind": "charge", "left": 2}, {"kind": "charge", "left": 1, "hit": true},
			{"kind": "silence", "turns": 1, "n": 2, "also": {"kind": "attack", "n": 2}},
			{"kind": "silence", "turns": 1, "n": 2, "also": {"kind": "attack", "n": 2}},
			{"kind": "silence", "turns": 1, "n": 2, "also": {"kind": "attack", "n": 2}}],
		"moves_black": [{"kind": "silence", "turns": 1, "n": 2, "also": {"kind": "attack", "n": 2}},
			{"kind": "silence", "turns": 1, "n": 2, "also": {"kind": "attack", "n": 2}},
			{"kind": "silence", "turns": 1, "n": 2, "also": {"kind": "attack", "n": 2}},
			{"kind": "charge", "left": 3, "n": 10}, {"kind": "charge", "left": 2}, {"kind": "charge", "left": 1, "hit": true}],
		"flavor": "Half a beast, all the temper."},
	# The Invoker (an Act 1 boss): he never attacks. Each turn he conjures 3 of his 10 spells (no repeats) as cards on his
	# side; on his turn he casts every one your chant matched, or else the one it came closest to (ties: random). At 0
	# Essence he rises again with 10 more, and from then on chants Quas / Wex / Exort, one a turn: that Essence is
	# stripped from his spells' patterns for the rest of the fight (they get easier to set off).
	"invoker": {"name": "The Invoker", "act": 1, "boss": true, "hp": "FWAFWAFWAFWAFWAFWAFW", "hp2": "AWFAWFAWFA",
		"invokes": true, "passives": ["invoker", "invoker_rebirth"], "tint": Color(0.5, 0.3, 0.72),
		"moves": [{"kind": "invoke"}],
		"flavor": "Ten spells, three words, no patience."},
	"forge_spirit": {"name": "Forge Spirit", "act": 1, "member": true, "hp": "FFF", "moves": [{"kind": "attack", "n": 3}],
		"flavor": "A spark of the Invoker's forge, with a temper to match."},
	"woodcutter": {"name": "The Woodcutter", "act": 0, "boss": true, "hp": "FWAFWAFFWAWFA",
		"moves": [{"kind": "attack", "n": 8}, {"kind": "summon", "id": "ashling", "n": 1}, {"kind": "armor", "pos": 0, "also": {"kind": "attack", "n": 4}}],
		"moves2": [{"kind": "attack", "n": 5, "hits": 2}, {"kind": "mend", "el": "random", "n": 1, "who": "self"}],
		"flavor": "He came for the last tree."},
	"blightmother": {"name": "The Blightmother", "act": 2, "boss": true, "hp": "WAWFWAAWFWAWFA",
		"moves": [{"kind": "bleed", "n": 2}, {"kind": "summon", "id": "puddle_slime", "n": 1}, {"kind": "attack", "n": 7}],
		"moves2": [{"kind": "lock", "len": 3}, {"kind": "mend", "el": "random", "n": 1, "who": "all"}, {"kind": "attack", "n": 5, "hits": 2}],
		"flavor": "Rot, and everything it feeds."},
	"last_winter": {"name": "The Last Winter", "act": 3, "boss": true, "hp": "WWAWFAWWAFAWWAFWAW",
		"moves": [{"kind": "freeze", "n": 2}, {"kind": "attack", "n": 8}, {"kind": "confuse"}, {"kind": "attack", "n": 7}],
		"moves2": [{"kind": "lock", "len": 3}, {"kind": "summon", "id": "storm_imp", "n": 2}, {"kind": "attack", "n": 6, "hits": 2}],
		"flavor": "The end of every season."},
}

const PASSIVE_TEXT := {
	"burning_hide": "Burning Hide: you take 1 damage whenever your Release hits it.",
	"split": "Split: struck but not killed, it splits its remaining Essence into two enemies (once).",
	"overgrowth": "Overgrowth: if not struck during your turn, it grows a random Essence.",
	"warded": "Warded: only chants of 4 or more Essence can strike it.",
	"last_gasp": "Last Gasp: gives you Bleed 2 when it dies.",
	"gem_crown": "Gem Crown: at the end of its turn, armours its first Essence if nothing is armoured (not when it has 1 left).",
	"echo": "Echo: repeats each action twice.",
	"briar_walls": "Briar Walls: she hides between two hedge walls (3 Essence each, the two ends of her row). They are part of her: leftmost and rightmost effects hit the ends of her row (a wall while it stands), random effects pick wall Essence first, and Snipe can reach anything. She regrows a fallen wall (she shows it first); with both up she sings (Power +1) or attacks. When her own Essence is gone, the walls fall with her.",
	"thorns": "Thorns 2: you lose 2 HP whenever your Release hits it.",
	"burn_immune": "Fireproof: Burn has no effect on it.",
	"slime_burst": "Burst: when it dies, two small slimes pop out.",
	"invoker": "Invoker: every turn he conjures 3 spells. On his turn he casts every one your chant matched, or else the one it came closest to.",
	"invoker_rebirth": "Second wind: at 0 Essence he rises again with 10 more, and starts chanting Quas, Wex or Exort, one a turn: each strips that Essence (Water, Air, Fire) from his spells for the rest of the fight.",
	"yinyang_split": "Split: when it dies, it splits into two Yin Yang Cubs (10 Essence each), one white and one black.",
	"shield_rage": "Enraged: every time you gain Shield, it gains Power +1 (its attacks deal 1 more damage).",
	"rage_at_half": "Shield Wall: above half its Essence it guards and strikes in turn. At half or below it drops its shield and attacks twice every turn.",
}

## Light-hearted descriptions for the preparation screen.
const BIOS := {
	"ashling": "A campfire spark that got ambitious. Bites like a toddler with a grudge.",
	"iceling": "A snowflake with an attitude. Small, cold, and surprisingly pointy.",
	"zephling": "A gust of wind that decided to have a face. Mostly harmless, mostly.",
	"purple_slime": "Wobbles. Squelches. Hits you. That's the whole personality.",
	"green_slime": "The lightest slime in the forest, and very proud of it.",
	"yellow_slime": "Warm, sticky, and a little bit angry about it.",
	"bramble_back": "A porcupine that stood up and got mad. Hitting it with your chant is a prickly business.",
	"winged_tortoise": "Slow to fly, quick to hide. Every other turn it tucks another Essence behind its shell.",
	"leech_bat": "Shiny fangs, zero shame. Every bite patches it back up.",
	"mirror_fairy": "She lives in the mirror and turns your words backwards. Read your chant from the right!",
	"yeti": "Huge, fluffy, and it freezes your Essence solid before punching you.",
	"greenseer": "The druid in the mushroom hat. Grows slimes, heals itself, and lets them do the fighting.",
	"rolling_bear": "Starts as a gentle roll and ends as an avalanche. It gets stronger every single turn.",
	"giant_slime": "A rainbow of wobble. Pop it and two smaller slimes come out to finish the job.",
	"tomato_knight": "Guards behind a big shield while it's healthy. Squish it past halfway and it throws the shield away and goes berserk.",
	"puddle_slime": "Technically a puddle. Emotionally, also a puddle. It keeps topping itself up so it never has to face the drain.",
	"gale_sprite": "Two jabs, no manners. Toughens up when you look at it funny, and loves freezing your fingers mid-spell.",
	"cinder_hound": "Good boy. Very hot boy. Flames run under its fur like tattoos, so Burn just tickles.",
	"stone_knight": "Spends a whole turn bracing, then swings like it gets paid by the bruise. Politely makes you fragile first.",
	"tidecaller": "Refills itself like a tide that refuses to go out. Also freezes things, because the ocean is petty.",
	"mirror_wisp": "Never in the same order twice. Blinds you, reshuffles itself, and giggles about it.",
	"frost_hex": "Freezes your Essence, then waits for you to complain. Mends itself with the same cold patience.",
	"pickpocket_imp": "Steals your Essence and wears them like jewellery. Surprisingly good fashion sense for a thief.",
	"splitter_ooze": "Hit it wrong and there are two of them. Hit it right and there are still two, just smaller and angrier.",
	"overgrowth_vine": "Ignore it for one turn and it grows. Basically a houseplant with a violence problem.",
	"toll_keeper": "Every word costs extra. Shortens your chant and charges admission in bruises.",
	"hexer": "Curses one of your Essence so chanting it hurts. Heals its friends, which is honestly the most annoying part.",
	"shrine_maiden": "Heals everyone except you. Very devout. Very inconvenient.",
	"hush_moth": "Its wings whisper \"shhh\" at one of your spells: it can't fire for a turn.",
	"blinding_beetle": "One shiny flash and suddenly everything is question marks. Gets stronger the longer you squint.",
	"inverter": "Fire becomes water, water becomes fire, and your plans become confetti.",
	"warded_golem": "Short chants bounce right off. Say something meaningful: at least four Essence long.",
	"echo_wraith": "Everything it does, it does twice. Everything it does, it does twice.",
	"mimic_chest": "Turns into your last words, backwards. Not the treasure you were hoping for.",
	"last_gasp_spore": "Mostly harmless until it dies. Then it sneezes on you, and you bleed about it.",
	"storm_imp": "Three tiny zaps, then it flickers out of reach. Hits harder every time it gets bored.",
	"storm_rider": "Fast, loud and hard to read. Imagine a thunderstorm that learned to ride a horse.",
	"lockwarden": "Chains your spells shut and expects you to guess the combination.",
	"tide_colossus": "A wave that stood up and decided to stay standing. Mends two at a time and swings like a tsunami.",
	"triplet_fire": "The hot-headed one of the Triplet. Touch a burning spell and you'll feel it.",
	"triplet_water": "The calm one of the Triplet. Calm like a frozen lake.",
	"triplet_air": "The quiet one of the Triplet. It prefers that you be quiet too.",
	"enraged_bear": "The Rolling Bear, but someone woke it up. Red-furred, huge, and it takes your shields personally.",
	"yin_yang_beast": "A beast of black and white that turns your words inside out, then charges.",
	"yin_yang_clone": "What's left when the Yin Yang Beast falls apart: two smaller, angrier halves.",
	"invoker": "A sorcerer who remembers every spell ever cast. He never swings a fist: he just reads your chant back at you.",
	"forge_spirit": "Hot, small, and very eager to prove itself.",
	"bramble_matron": "A druid wrapped in a living hedge. Her two walls do the fighting while she sings them stronger. Cut the walls, or Snipe her straight through them.",
	"mirror_knight": "Its guard is always exactly where you didn't aim. Rude, but fair.",
	"void_archon": "Steals the light, then your words, then your patience.",
	"woodcutter": "He came for the last tree, and he brought friends and an axe. Mostly the axe.",
	"blightmother": "Rot, and everything it feeds. She bleeds you, locks you, and calls in the slimes for moral support.",
	"last_winter": "The end of every season. Freezes your hands, scrambles your words, and calls a storm to finish the job.",
}

const BOSSES := {1: ["yin_yang_beast", "invoker"], 2: ["blightmother"], 3: ["last_winter"]}
## Passives the fight never tells you about (only the Codex does, once you've beaten it).
const HIDDEN_PASSIVES := ["yinyang_split", "invoker_rebirth"]

## The Invoker's spells (Dota 2's Invoker: Quas = Water, Wex = Air, Exort = Fire). Each one's "cast" is the move he makes
## when it goes off; "desc" is its card text.
const INVOKER_WORDS := {"W": "Quas", "A": "Wex", "F": "Exort"}
const INVOKER_SPELLS := [
	{"id": "inv_cold_snap", "name": "Cold Snap", "pattern": "WWW", "kind": "damage", "desc": "Deal 1 damage to you, 4 times.",
		"cast": {"kind": "attack", "n": 1, "hits": 4}},
	{"id": "inv_ghost_walk", "name": "Ghost Walk", "pattern": "WWA", "kind": "utility", "desc": "He cleanses all his debuffs.",
		"cast": {"kind": "cleanse_self"}},
	{"id": "inv_ice_wall", "name": "Ice Wall", "pattern": "WWF", "kind": "defense", "desc": "He Armours 3 of his Essence.",
		"cast": {"kind": "armor", "pos": -1, "count": 3}},
	{"id": "inv_emp", "name": "EMP", "pattern": "AAA", "kind": "utility", "desc": "You lose 2 random Essence from your bag, and take 2 damage.",
		"cast": {"kind": "drain_essence", "n": 2, "also": {"kind": "attack", "n": 2}}},
	{"id": "inv_tornado", "name": "Tornado", "pattern": "AAW", "kind": "damage", "desc": "Deal 3 damage to you and Silence 1 of your spells (1 turn).",
		"cast": {"kind": "attack", "n": 3, "also": {"kind": "silence", "n": 1, "turns": 1}}},
	{"id": "inv_alacrity", "name": "Alacrity", "pattern": "AAF", "kind": "utility", "desc": "He gains Power +2.",
		"cast": {"kind": "empower", "n": 2}},
	{"id": "inv_sun_strike", "name": "Sun Strike", "pattern": "FFF", "kind": "damage", "desc": "Deal 10 damage to you.",
		"cast": {"kind": "attack", "n": 10}},
	{"id": "inv_forge_spirit", "name": "Forge Spirit", "pattern": "FFW", "kind": "utility", "desc": "He summons a Forge Spirit (3 Essence, attacks for 3).",
		"cast": {"kind": "summon", "id": "forge_spirit", "n": 1}},
	{"id": "inv_chaos_meteor", "name": "Chaos Meteor", "pattern": "FFA", "kind": "damage", "desc": "Deal 2 damage to you, 3 times, and Ignite 3 of your spells.",
		"cast": {"kind": "attack", "n": 2, "hits": 3, "also": {"kind": "ignite_spell", "n": 3, "turns": 1}}},
	{"id": "inv_deafening_blast", "name": "Deafening Blast", "pattern": "WAF", "kind": "damage", "desc": "Deal 5 damage to you and Disarm you (your next Release does nothing).",
		"cast": {"kind": "attack", "n": 5, "also": {"kind": "disarm", "turns": 1}}},
]


static func get_def(id: String) -> Dictionary:
	var d: Dictionary = E[id].duplicate(true)
	d.id = id
	return d


static func normals(act: int) -> Array:
	return E.keys().filter(func(k): return E[k].act == act and not E[k].get("elite", false) and not E[k].get("boss", false))


static func elites(act: int) -> Array:
	var out := E.keys().filter(func(k): return E[k].get("elite", false) and not E[k].get("member", false) and E[k].act <= act and E[k].act >= act - 1)
	return out + ELITE_GROUPS.keys().filter(func(k): return ELITE_GROUPS[k].act <= act and ELITE_GROUPS[k].act >= act - 1)


## Mini bosses that are a group: always met together, left to right.
const ELITE_GROUPS := {
	"the_triplet": {"name": "The Triplet", "act": 1, "ids": ["triplet_fire", "triplet_water", "triplet_air"]},
}


## The enemies an id brings into a fight: a group's members, or just itself.
static func ids_of(id: String) -> Array:
	return ELITE_GROUPS[id].ids.duplicate() if ELITE_GROUPS.has(id) else [id]


static func name_of(id: String) -> String:
	return ELITE_GROUPS[id].name if ELITE_GROUPS.has(id) else E[id].name


## Act 1 normal fights, the Slay the Spire way: a fixed list of hand-made, themed encounters. Each one is always the
## same group of enemies and always the same tier (how far into the act it can appear); only WHICH encounter you meet
## is picked (by weight). A group of smaller enemies is worth one bigger one: the three slimes together are a tier-2.5
## fight, like a Yeti. tier -> [{name, ids (left to right), w}]
const ENCOUNTERS_ACT1 := {
	1.0: [
		{"name": "A Fire Spirit", "ids": ["ashling"], "w": 1.0},
		{"name": "An Ice Spirit", "ids": ["iceling"], "w": 1.0},
		{"name": "An Air Spirit", "ids": ["zephling"], "w": 1.0},
	],
	1.5: [
		{"name": "Purple Slime", "ids": ["purple_slime"], "w": 1.0},
		{"name": "Green Slime", "ids": ["green_slime"], "w": 1.0},
		{"name": "Yellow Slime", "ids": ["yellow_slime"], "w": 1.0},
		{"name": "Steam", "ids": ["ashling", "iceling"], "w": 1.0},
		{"name": "Wildfire", "ids": ["zephling", "ashling"], "w": 1.0},
		{"name": "Frost Wind", "ids": ["iceling", "zephling"], "w": 1.0},
	],
	2.0: [
		{"name": "Bramble Back", "ids": ["bramble_back"], "w": 1.0},
		{"name": "Winged Tortoise", "ids": ["winged_tortoise"], "w": 1.0},
		{"name": "Hush Moth", "ids": ["hush_moth"], "w": 1.0},
		{"name": "The Elemental Trio", "ids": ["ashling", "iceling", "zephling"], "w": 1.0},
		{"name": "Marsh", "ids": ["purple_slime", "iceling"], "w": 0.7},
		{"name": "Hot Puddle", "ids": ["yellow_slime", "ashling"], "w": 0.7},
		{"name": "Breezy Ooze", "ids": ["green_slime", "zephling"], "w": 0.7},
	],
	2.5: [
		{"name": "Cinder Hound", "ids": ["cinder_hound"], "w": 1.0},
		{"name": "Mirror Fairy", "ids": ["mirror_fairy"], "w": 1.0},
		{"name": "Yeti", "ids": ["yeti"], "w": 1.0},
		{"name": "Leech Bat", "ids": ["leech_bat"], "w": 1.0},
		{"name": "The Slime Trio", "ids": ["purple_slime", "green_slime", "yellow_slime"], "w": 1.0},
		{"name": "The Forest Floor", "ids": ["bramble_back", "winged_tortoise"], "w": 0.8},
	],
	3.0: [
		{"name": "The Greenseer's Garden", "ids": ["greenseer", "green_slime"], "w": 1.0},
		{"name": "Rolling Bear", "ids": ["rolling_bear"], "w": 1.0},
		{"name": "Giant Slime", "ids": ["giant_slime"], "w": 1.0},
		{"name": "Tomato Knight", "ids": ["tomato_knight"], "w": 1.0},
		{"name": "Hound and Embers", "ids": ["cinder_hound", "ashling"], "w": 0.7},
		{"name": "Blizzard", "ids": ["yeti", "iceling"], "w": 0.7},
		{"name": "Hall of Mirrors", "ids": ["mirror_fairy", "zephling"], "w": 0.7},
		{"name": "Night Wings", "ids": ["leech_bat", "hush_moth"], "w": 0.7},
	],
}


## Which tier of Act 1 fights a map row (0-based, 12 rows) brings.
static func act1_tier(row: int) -> float:
	if row <= 1:
		return 1.0
	if row <= 3:
		return 1.5
	if row <= 5:
		return 2.0
	if row <= 8:
		return 2.5
	return 3.0


## An Act 1 fight of this tier, weighted, and never one of the last two encounters met (like Slay the Spire).
## recent: the names of the encounters met so far this run.
static func act1_encounter(tier: float, rng: RandomNumberGenerator, recent: Array = []) -> Dictionary:
	var pool: Array = ENCOUNTERS_ACT1[tier]
	var last_two := recent.slice(maxi(0, recent.size() - 2))
	var fresh := pool.filter(func(enc): return not (enc.name in last_two))
	if fresh.is_empty():
		fresh = pool
	var total := 0.0
	for enc in fresh:
		total += enc.w
	var r := rng.randf() * total
	for enc in fresh:
		r -= enc.w
		if r < 0.0:
			return enc.duplicate(true)
	return fresh[-1].duplicate(true)


## Enemy ids for a node. floor is 1-based within the act. seen: ids met earlier this run (avoided when possible).
static func encounter(kind: String, act: int, floor: int, rng: RandomNumberGenerator, seen: Array = []) -> Array:
	match kind:
		"boss":
			var bosses: Array = BOSSES[act]
			return [bosses[rng.randi() % bosses.size()]]
		"elite":
			var pool := elites(act)
			var fresh := pool.filter(func(id): return not (ids_of(id)[0] in seen))
			if not fresh.is_empty():
				pool = fresh
			var out := ids_of(pool[rng.randi() % pool.size()])
			if act >= 2:
				# an elite brings 1 escort (sometimes 2 in act 3)
				var n := normals(act)
				for i in (2 if act >= 3 and rng.randf() < 0.4 else 1):
					out.append(n[rng.randi() % n.size()])
			return out
	var pool := normals(act)
	var count := group_size(act, floor, rng)
	var out := []
	for i in count:
		# prefer enemies not already in this fight or met recently
		var fresh := pool.filter(func(id): return not (id in out) and not (id in seen.slice(maxi(0, seen.size() - 6))))
		var from: Array = fresh if not fresh.is_empty() else pool
		out.append(from[rng.randi() % from.size()])
	return out


## How many enemies a normal fight has: 1 to 5, more likely to be big deeper in the run.
## [count, weight] per act (the first two floors of act 1 are always a single enemy).
const GROUP_ODDS := {
	1: [[1, 0.2], [2, 0.45], [3, 0.27], [4, 0.08]],
	2: [[2, 0.3], [3, 0.38], [4, 0.22], [5, 0.1]],
	3: [[2, 0.08], [3, 0.3], [4, 0.37], [5, 0.25]],
}


static func group_size(act: int, floor: int, rng: RandomNumberGenerator) -> int:
	if act == 1 and floor <= 2:
		return 1
	var odds: Array = GROUP_ODDS.get(act, GROUP_ODDS[3])
	var r := rng.randf()
	for o in odds:
		r -= o[1]
		if r < 0.0:
			return o[0]
	return odds[-1][0]


## Extra random elements added to the end of an enemy's Essence on deeper floors (act 2 and 3 bosses get a few too).
## Act 1 starts at 3 elements; act 2 enemies have 8 or more, act 3 ones 11 or more. The size of the group scales it:
## a lone enemy gets 2 more, and each enemy beyond the second takes 1 fewer from every enemy in the fight.
static func extra_hp(act: int, floor: int, rng: RandomNumberGenerator, boss := false, group := 2) -> Array:
	var n := 0
	if boss:
		n = [0, 0, 3, 5][act]  # the act 2 and 3 bosses come back tougher
	else:
		match act:
			1:
				n = 0 if floor <= 2 else (2 if floor <= 4 else 3)
			2:
				n = 5 if floor <= 3 else 6
			3:
				n = 8 if floor <= 4 else 9
		if group == 1 and not (act == 1 and floor <= 2):
			n += 2
		elif group > 2:
			n = maxi(0, n - (group - 2))
	var out := []
	for i in n:
		out.append(Elements.random(rng))
	return out


## The extra Essence this enemy gets: none for the tiered Act 1 enemies (their Essence is exactly as designed).
static func extra_for(id: String, act: int, floor: int, rng: RandomNumberGenerator, group := 2) -> Array:
	var d := get_def(id)
	if d.has("tier") or d.has("walls"):
		return []
	return extra_hp(act, floor, rng, d.get("boss", false), group)


static func attack_bonus(act: int) -> int:
	return [0, 0, 4, 6][act]


static func describe_move(m: Dictionary, bonus := 0, full := false) -> String:
	var s := ""
	match m.kind:
		"attack":
			var n: int = m.n + bonus
			s = "Attack %d" % n if m.get("hits", 1) == 1 else "Attack %d×%d" % [n, m.hits]
		"armor":
			s = "Armour its next Essence (the first one not armoured yet)" if m.pos < 0 else "Armour its %s Essence" % ["1st", "2nd", "3rd", "4th"][mini(m.pos, 3)]
			if m.get("who", "self") == "random":
				s = "Armour 1 Essence of one of them, at random"
		"mend":
			var el: String = "random Essence" if m.el == "random" else ("Essence" if m.el == "own" else Elements.NAMES[m.el])
			s = "Mend +%d %s%s" % [m.n, el, {"self": "", "ally": " on an ally", "all": " on every enemy", "weakest": " on the most hurt of them", "random_hurt": " on one of them at random (a hurt one first)"}[m.get("who", "self")]]
		"shuffle":
			s = "Shuffle its Essence"
		"silence":
			var many: int = m.get("n", 1)
			s = "Silence %s (%d turn%s)" % ["one of your spells" if many == 1 else "%d of your spells" % many, m.turns, "" if m.turns == 1 else "s"]
		"invert_spells":
			s = "Invert %d of your spell%s (a spell becomes an anti-spell, an anti-spell a spell)" % [m.n, "" if m.n == 1 else "s"]
			if full:
				s += ". A spell turned anti gives it 1 Essence of its pattern; one turned back gains 1 random Essence"
			if full:
				s += ", and it turns the other colour (white / black)"
		"invoke":
			s = "Cast one of his spells (every one your chant matched, or else the closest)"
			if m.has("word"):
				s += ", then chant %s: his spells lose every %s" % [INVOKER_WORDS[m.word], Elements.NAMES[m.word]]
		"cleanse_self":
			s = "Cleanse all its debuffs"
		"drain_essence":
			s = "You lose %d random Essence from your bag" % m.n
		"disarm":
			s = "Disarm you (your next Release does nothing)"
		"charge":
			if full and m.has("n"):
				s = "Charge for 3 turns (an hourglass), then hit for %d. While it charges, every spell of the other colour you cast (white: spells, black: anti-spells) lowers the hit by 5, and every one of its own colour raises it by 5 (never below 0)" % m.n
			elif full:
				s = ""
			else:
				s = "Charging: %d turn%s left" % [m.left, "" if m.left == 1 else "s"]
		"ignite_spell":
			s = "Ignite one of your spells for your next turn (casting it burns you for %d)" % Fight.IGNITE_DAMAGE
		"lock":
			s = "Lock one of your spells (%d symbols)" % m.len
		"steal":
			s = "Steal %d of your Essence" % m.n
		"confuse":
			s = "Confuse you (your next chant is read backwards)"
		"blind":
			s = "Blind you (%d turns)" % m.turns
		"bleed":
			s = "Bleed %d" % m.n
		"freeze":
			s = "Freeze %d of your Essence" % m.n
		"ethereal":
			s = "Go Ethereal (your next chant can't touch it)"
		"empower":
			s = "Empower +%d" % m.n + (" one of them, at random" if m.get("who", "self") == "random" else "")
		"summon":
			s = "Call %d %s" % [m.n, E[m.id].name] if m.has("id") else "Call %d random small slime%s" % [m.n, "" if m.n == 1 else "s"]
		"toll":
			s = "Toll: your next chant holds at most %d Essence" % PlayerState.TOLL_CAP
		"invert":
			s = "Invert: swap your Fire and Water"
		"hex":
			s = "Hex one of your Essence (chanting it costs 2 HP)"
		"mimic":
			s = "Mimic: its Essence becomes your last chant, backwards"
		"wall_attack":
			s = "Each wall attacks for %d%s" % [m.n + bonus, (" × %d hits" % m.hits) if m.get("hits", 1) > 1 else ""]
		"regrow":
			s = "Regrow her %s wall" % ("left" if m.get("side", "L") == "L" else "right")
		"sing":
			s = "Sing: Power +1 (her and her walls hit 1 harder)"
		"brittle":
			s = "Brittle %d: the Shield you gain is 25%% smaller" % m.turns
		"frail":
			s = "Frail you (%d turn%s: you take 25%% more damage)" % [m.turns, "" if m.turns == 1 else "s"]
	if m.has("also"):
		s += " + " + describe_move(m.also, bonus, full)
	return s
