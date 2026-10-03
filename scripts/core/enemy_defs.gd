class_name EnemyDefs
extends RefCounted
## Every enemy: Essence pattern (elements, left to right), moves (cycled in order), passives.
## Moves are used in the listed order, looping. Normal enemies mix offence, defence and utility.
## Move kinds: attack {n, hits}, armor {pos}, mend {el, n, who: self/ally/all}, shuffle, silence {turns}, frail {turns},
## lock {len}, steal {n}, confuse, blind {turns}, bleed {n}, freeze {n}, ethereal, empower {n},
## summon {id, n}, toll, invert, hex, mimic. A move may carry `also` (a second move done the same turn).

const E := {
	# ---------------- act 1
	"ashling": {"name": "Ashling", "act": 1, "hp": "FFW", "moves": [{"kind": "attack", "n": 5}, {"kind": "mend", "el": "F", "n": 1, "who": "self"}, {"kind": "bleed", "n": 1, "also": {"kind": "attack", "n": 2}}],
		"flavor": "A spark that learned to bite."},
	"puddle_slime": {"name": "Puddle Slime", "act": 1, "hp": "WAW", "moves": [{"kind": "attack", "n": 3}, {"kind": "mend", "el": "W", "n": 1, "who": "self"}, {"kind": "frail", "turns": 1}],
		"flavor": "It keeps refilling itself."},
	"gale_sprite": {"name": "Gale Sprite", "act": 1, "hp": "AFA", "moves": [{"kind": "attack", "n": 3, "hits": 2}, {"kind": "armor", "pos": 0}, {"kind": "freeze", "n": 1}],
		"flavor": "Two quick jabs of wind."},
	"cinder_hound": {"name": "Cinder Hound", "act": 1, "hp": "FFF", "moves": [{"kind": "attack", "n": 6}, {"kind": "armor", "pos": 0}, {"kind": "empower", "n": 1, "also": {"kind": "attack", "n": 3}}], "passives": ["burning_hide"],
		"flavor": "Touching it hurts."},
	"stone_knight": {"name": "Stone Knight", "act": 1, "hp": "FFW", "moves": [{"kind": "armor", "pos": 1}, {"kind": "attack", "n": 8}, {"kind": "frail", "turns": 1, "also": {"kind": "attack", "n": 3}}],
		"flavor": "Braces, then swings."},
	"tidecaller": {"name": "Tidecaller", "act": 1, "hp": "WAWA", "moves": [{"kind": "mend", "el": "W", "n": 1, "who": "self"}, {"kind": "attack", "n": 5}, {"kind": "freeze", "n": 1}],
		"flavor": "The tide always comes back."},
	"mirror_wisp": {"name": "Mirror Wisp", "act": 1, "hp": "AWF", "moves": [{"kind": "attack", "n": 4, "also": {"kind": "shuffle"}}, {"kind": "blind", "turns": 1}, {"kind": "armor", "pos": 0}],
		"flavor": "Never in the same order twice."},
	"frost_hex": {"name": "Frost Hex", "act": 1, "hp": "WWA", "moves": [{"kind": "freeze", "n": 1}, {"kind": "attack", "n": 4}, {"kind": "mend", "el": "W", "n": 1, "who": "self"}],
		"flavor": "Your fingers go numb."},
	"pickpocket_imp": {"name": "Pickpocket Imp", "act": 1, "hp": "AFA", "moves": [{"kind": "steal", "n": 1}, {"kind": "attack", "n": 4}, {"kind": "armor", "pos": 0}],
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
	"hush_moth": {"name": "Hush Moth", "act": 2, "hp": "AAW", "moves": [{"kind": "silence", "turns": 2}, {"kind": "attack", "n": 4}, {"kind": "armor", "pos": 0}],
		"flavor": "Its wings steal your words."},
	"blinding_beetle": {"name": "Blinding Beetle", "act": 2, "hp": "FAF", "moves": [{"kind": "blind", "turns": 2}, {"kind": "attack", "n": 4}, {"kind": "empower", "n": 1}],
		"flavor": "A flash, and everything blurs."},
	"leech_bat": {"name": "Leech Bat", "act": 2, "hp": "WFA", "moves": [{"kind": "bleed", "n": 2}, {"kind": "attack", "n": 3}, {"kind": "mend", "el": "random", "n": 1, "who": "self"}],
		"flavor": "Small bites that keep bleeding."},
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
	"gem_king": {"name": "Gem King", "act": 1, "elite": true, "hp": "FWAWF", "moves": [{"kind": "attack", "n": 6}, {"kind": "armor", "pos": 0, "also": {"kind": "attack", "n": 2}}], "passives": ["gem_crown"],
		"flavor": "Its crown hardens whatever it wears first."},
	"storm_rider": {"name": "Storm Rider", "act": 2, "elite": true, "hp": "AAFAA", "moves": [{"kind": "attack", "n": 3, "hits": 2}, {"kind": "attack", "n": 2, "also": {"kind": "shuffle"}}],
		"flavor": "Fast, and hard to read."},
	"lockwarden": {"name": "Lockwarden", "act": 2, "elite": true, "hp": "WFWAF", "moves": [{"kind": "lock", "len": 2}, {"kind": "attack", "n": 5}, {"kind": "attack", "n": 5}],
		"flavor": "Chains your spells shut."},
	"tide_colossus": {"name": "Tide Colossus", "act": 3, "elite": true, "hp": "WWWWFW", "moves": [{"kind": "mend", "el": "W", "n": 2, "who": "self"}, {"kind": "attack", "n": 8}],
		"flavor": "A wave that stands up."},
	"hollow_stag": {"name": "Hollow Stag", "act": 1, "elite": true, "hp": "AWFAWFAWFAWF", "moves": [{"kind": "attack", "n": 7}, {"kind": "empower", "n": 2, "also": {"kind": "attack", "n": 3}}],
		"flavor": "Every charge hits harder than the last."},
	"bramble_matron": {"name": "Bramble Matron", "act": 1, "elite": true, "hp": "WFWFA", "moves": [{"kind": "summon", "id": "ashling", "n": 1}, {"kind": "attack", "n": 4, "hits": 2}], "passives": ["burning_hide"],
		"flavor": "Her brood of sparks never stops coming."},
	"mirror_knight": {"name": "Mirror Knight", "act": 2, "elite": true, "hp": "WAFWAF", "moves": [{"kind": "armor", "pos": 0, "also": {"kind": "attack", "n": 5}}, {"kind": "shuffle", "also": {"kind": "attack", "n": 7}}],
		"flavor": "Its guard is where you least expect."},
	"void_archon": {"name": "Void Archon", "act": 3, "elite": true, "hp": "AFWAFWA", "moves": [{"kind": "blind", "turns": 2, "also": {"kind": "attack", "n": 5}}, {"kind": "lock", "len": 2}, {"kind": "attack", "n": 4, "hits": 3}],
		"flavor": "It steals the light, then the words."},
	# ---------------- bosses (moves2 = second phase, at half HP)
	"woodcutter": {"name": "The Woodcutter", "act": 1, "boss": true, "hp": "FWAFWAFFWAWFA",
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
}

## Light-hearted descriptions for the preparation screen.
const BIOS := {
	"ashling": "A campfire spark that got ambitious. Bites like a toddler with a grudge, then refuels on pure spite.",
	"puddle_slime": "Technically a puddle. Emotionally, also a puddle. It keeps topping itself up so it never has to face the drain.",
	"gale_sprite": "Two jabs, no manners. Toughens up when you look at it funny, and loves freezing your fingers mid-spell.",
	"cinder_hound": "Good boy. Very hot boy. Touching it with your chant WILL burn you, and it knows.",
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
	"hush_moth": "Its wings whisper \"shhh\" at one of your spells until it forgets how to work.",
	"blinding_beetle": "One shiny flash and suddenly everything is question marks. Gets stronger the longer you squint.",
	"leech_bat": "Tiny bites, lots of bleeding, zero shame. Patches itself up with your blood money.",
	"inverter": "Fire becomes water, water becomes fire, and your plans become confetti.",
	"warded_golem": "Short chants bounce right off. Say something meaningful: at least four Essence long.",
	"echo_wraith": "Everything it does, it does twice. Everything it does, it does twice.",
	"mimic_chest": "Turns into your last words, backwards. Not the treasure you were hoping for.",
	"last_gasp_spore": "Mostly harmless until it dies. Then it sneezes on you, and you bleed about it.",
	"storm_imp": "Three tiny zaps, then it flickers out of reach. Hits harder every time it gets bored.",
	"gem_king": "Its crown hardens whatever it wears first. Royal, sparkly, and extremely bad at sharing.",
	"storm_rider": "Fast, loud and hard to read. Imagine a thunderstorm that learned to ride a horse.",
	"lockwarden": "Chains your spells shut and expects you to guess the combination.",
	"tide_colossus": "A wave that stood up and decided to stay standing. Mends two at a time and swings like a tsunami.",
	"hollow_stag": "Every charge hits harder than the last. Antlers optional, ego mandatory.",
	"bramble_matron": "Her brood of sparks never stops coming, and hugging her is a mistake.",
	"mirror_knight": "Its guard is always exactly where you didn't aim. Rude, but fair.",
	"void_archon": "Steals the light, then your words, then your patience.",
	"woodcutter": "He came for the last tree, and he brought friends and an axe. Mostly the axe.",
	"blightmother": "Rot, and everything it feeds. She bleeds you, locks you, and calls in the slimes for moral support.",
	"last_winter": "The end of every season. Freezes your hands, scrambles your words, and calls a storm to finish the job.",
}

const BOSSES := {1: "woodcutter", 2: "blightmother", 3: "last_winter"}


static func get_def(id: String) -> Dictionary:
	var d: Dictionary = E[id].duplicate(true)
	d.id = id
	return d


static func normals(act: int) -> Array:
	return E.keys().filter(func(k): return E[k].act == act and not E[k].get("elite", false) and not E[k].get("boss", false))


static func elites(act: int) -> Array:
	return E.keys().filter(func(k): return E[k].get("elite", false) and E[k].act <= act and E[k].act >= act - 1)


## Enemy ids for a node. floor is 1-based within the act. seen: ids met earlier this run (avoided when possible).
static func encounter(kind: String, act: int, floor: int, rng: RandomNumberGenerator, seen: Array = []) -> Array:
	match kind:
		"boss":
			return [BOSSES[act]]
		"elite":
			var pool := elites(act)
			var fresh := pool.filter(func(id): return not (id in seen))
			if not fresh.is_empty():
				pool = fresh
			var out := [pool[rng.randi() % pool.size()]]
			if act >= 2:
				# an elite brings 1 escort (sometimes 2 in act 3)
				var n := normals(act)
				for i in (2 if act >= 3 and rng.randf() < 0.4 else 1):
					out.append(n[rng.randi() % n.size()])
			return out
	var pool := normals(act)
	if act == 1 and floor <= 2:
		pool = ["ashling", "puddle_slime", "gale_sprite", "frost_hex"]
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
	3: [[2, 0.18], [3, 0.35], [4, 0.3], [5, 0.17]],
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


## Extra random elements added to the end of an enemy's Essence on deeper floors (bosses excluded).
## Act 1 starts at 3 elements; by the middle of act 2 every enemy has 7 or more. The size of the group scales it:
## a lone enemy gets 2 more, and each enemy beyond the second takes 1 fewer from every enemy in the fight.
static func extra_hp(act: int, floor: int, rng: RandomNumberGenerator, boss := false, group := 2) -> Array:
	var n := 0
	if not boss:
		match act:
			1:
				n = 0 if floor <= 2 else (2 if floor <= 4 else 3)
			2:
				n = 3 if floor <= 3 else 4
			3:
				n = 5 if floor <= 4 else 6
		if group == 1 and not (act == 1 and floor <= 2):
			n += 2
		elif group > 2:
			n = maxi(0, n - (group - 2))
	var out := []
	for i in n:
		out.append(Elements.random(rng))
	return out


static func attack_bonus(act: int) -> int:
	return [0, 0, 2, 3][act]


static func describe_move(m: Dictionary, bonus := 0) -> String:
	var s := ""
	match m.kind:
		"attack":
			var n: int = m.n + bonus
			s = "Attack %d" % n if m.get("hits", 1) == 1 else "Attack %d×%d" % [n, m.hits]
		"armor":
			s = "Armour its %s Essence" % ["1st", "2nd", "3rd", "4th"][mini(m.pos, 3)]
		"mend":
			var el: String = "random Essence" if m.el == "random" else Elements.NAMES[m.el]
			s = "Mend +%d %s%s" % [m.n, el, {"self": "", "ally": " on an ally", "all": " on every enemy"}[m.get("who", "self")]]
		"shuffle":
			s = "Shuffle its Essence"
		"silence":
			s = "Silence one of your spells (%d turns)" % m.turns
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
			s = "Empower +%d" % m.n
		"summon":
			s = "Call %d %s" % [m.n, E[m.id].name]
		"toll":
			s = "Toll: your next chant holds at most %d Essence" % PlayerState.TOLL_CAP
		"invert":
			s = "Invert: swap your Fire and Water"
		"hex":
			s = "Hex one of your Essence (chanting it costs 2 HP)"
		"mimic":
			s = "Mimic: its Essence becomes your last chant, backwards"
		"frail":
			s = "Frail you (%d turn%s: you take 25%% more damage)" % [m.turns, "" if m.turns == 1 else "s"]
	if m.has("also"):
		s += " + " + describe_move(m.also, bonus)
	return s
