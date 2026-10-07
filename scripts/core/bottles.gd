class_name Bottles
extends RefCounted
## Bottles: one-use panic buttons for the fight you're in. You carry up to 3 (more with the Bandolier); the
## merchant sells 2 at a time, and some events and fights hand them out. Using one works like casting a tiny
## spell: its effects go through the same rules as spell effects. No two bottles do the same thing, and the
## price follows how strong it is.

const BASE_SLOTS := 3

const ALL := [
	# ---- essence, right now
	{"id": "fire_flask", "color": Color(1.0, 0.42, 0.15), "name": "Fire Flask", "icon": "🔥", "price": 22, "desc": "Gain 2 Fire now.",
		"effects": [{"op": "draw", "n": 2, "el": "F", "when": "now"}]},
	{"id": "water_flask", "color": Color(0.25, 0.55, 1.0), "name": "Water Flask", "icon": "💧", "price": 22, "desc": "Gain 2 Water now.",
		"effects": [{"op": "draw", "n": 2, "el": "W", "when": "now"}]},
	{"id": "air_flask", "color": Color(0.4, 0.9, 0.72), "name": "Air Flask", "icon": "🌪", "price": 22, "desc": "Gain 2 Air now.",
		"effects": [{"op": "draw", "n": 2, "el": "A", "when": "now"}]},
	{"id": "prism_draught", "color": Color(0.95, 0.7, 1.0), "name": "Prism Draught", "icon": "🌈", "price": 28, "desc": "Gain 3 random Essence now.",
		"effects": [{"op": "draw", "n": 3, "el": "random", "when": "now"}]},
	# ---- you
	{"id": "healing_tonic", "color": Color(1.0, 0.3, 0.4), "name": "Healing Tonic", "icon": "❤", "price": 30, "desc": "Heal 10 HP.",
		"effects": [{"op": "heal", "n": 10}]},
	{"id": "iron_tonic", "color": Color(0.6, 0.72, 0.9), "name": "Iron Tonic", "icon": "🛡", "price": 26, "desc": "Gain 8 Shield.",
		"effects": [{"op": "shield", "n": 8}]},
	{"id": "aegis_elixir", "color": Color(1.0, 0.82, 0.3), "name": "Aegis Elixir", "icon": "✨", "price": 34, "desc": "Gain Aegis 1 (blocks one whole hit).",
		"effects": [{"op": "aegis", "n": 1}]},
	{"id": "thorn_oil", "color": Color(0.5, 0.8, 0.25), "name": "Thorn Oil", "icon": "🌵", "price": 20, "desc": "Gain 3 Thorns until your next turn.",
		"effects": [{"op": "thorns", "n": 3}]},
	{"id": "purifying_water", "color": Color(0.7, 1.0, 1.0), "name": "Purifying Water", "icon": "🫧", "price": 20, "desc": "Cleanse: remove every debuff on you.",
		"effects": [{"op": "cleanse"}]},
	# ---- enemies
	{"id": "liquid_fire", "color": Color(1.0, 0.6, 0.1), "name": "Liquid Fire", "icon": "🧨", "price": 36, "desc": "Burn 3 on an enemy.",
		"effects": [{"op": "burn", "n": 3, "target": "target"}]},
	{"id": "venom_vial", "color": Color(0.45, 0.95, 0.2), "name": "Venom Vial", "icon": "🐍", "price": 36, "desc": "Poison 2 on an enemy.",
		"effects": [{"op": "poison", "n": 2, "target": "target"}]},
	{"id": "thiefs_brew", "color": Color(0.6, 0.4, 0.9), "name": "Thief's Brew", "icon": "🫳", "price": 30, "desc": "Steal 1 Essence of your choice from an enemy.",
		"effects": [{"op": "steal", "n": 1, "el": "any", "target": "target"}]},
	{"id": "frost_phial", "color": Color(0.75, 0.93, 1.0), "name": "Frost Phial", "icon": "❄", "price": 44, "desc": "Freeze an enemy: it skips its next action (not bosses).",
		"effects": [{"op": "freeze", "turns": 1, "target": "target"}]},
	{"id": "smoke_bomb", "color": Color(0.6, 0.6, 0.65), "name": "Smoke Bomb", "icon": "💨", "price": 40, "desc": "Weaken 2 on all enemies.",
		"effects": [{"op": "weak", "turns": 2, "target": "all"}]},
	{"id": "acid_flask", "color": Color(0.8, 1.0, 0.25), "name": "Acid Flask", "icon": "🧪", "price": 42, "desc": "Remove 2 random Essence of an enemy.",
		"effects": [{"op": "random_hit", "n": 2, "target": "target"}]},
	{"id": "shatter_salts", "color": Color(0.92, 0.92, 0.85), "name": "Shatter Salts", "icon": "🔨", "price": 24, "desc": "All enemies lose their armour.",
		"effects": [{"op": "shatter", "target": "all"}]},
	{"id": "blast_flask", "color": Color(1.0, 0.35, 0.2), "name": "Blast Flask", "icon": "💣", "price": 52, "desc": "Remove 1 random Essence of all enemies.",
		"effects": [{"op": "random_hit", "n": 1, "target": "all"}]},
	# ---- spells
	{"id": "echo_draught", "color": Color(0.8, 0.55, 1.0), "name": "Echo Draught", "icon": "🔔", "price": 55, "desc": "The next spell you cast this fight is cast twice.",
		"effects": [{"op": "echo_next"}]},
	{"id": "hourglass_sand", "color": Color(0.95, 0.8, 0.45), "name": "Hourglass Sand", "icon": "⏳", "price": 48, "desc": "+1 Essence every turn for the rest of this fight.",
		"effects": [{"op": "passive", "key": "draw_bonus", "n": 1}]},
	{"id": "grimoire_ink", "color": Color(0.25, 0.25, 0.6), "name": "Grimoire Ink", "icon": "📜", "price": 80, "desc": "Choose a spell from your spellbook: it joins your active spells for this fight.",
		"effects": [{"op": "grimoire_pick"}]},
]


static func get_def(id: String) -> Dictionary:
	for b in ALL:
		if b.id == id:
			return b
	return {}


## The bottle as a tiny spell, so the fight can apply its effects the way it applies a spell's.
static func as_spell(id: String) -> Dictionary:
	var b := get_def(id)
	var s := {"id": "bottle_" + id, "name": b.get("name", id), "pattern": "", "effects": b.get("effects", []).duplicate(true),
		"power": false, "rarity": "common", "size": 0, "bottle": id}
	s.targeted = SpellDB._needs_target(s.effects)
	s.kind = SpellDB.kind_of(s.effects)
	return s


static func needs_target(id: String) -> bool:
	return SpellDB._needs_target(get_def(id).get("effects", []))


## n different random bottles (never two of the same in one offer).
static func random(rng: RandomNumberGenerator, n := 1) -> Array:
	var pool := ALL.duplicate()
	var out := []
	while out.size() < n and not pool.is_empty():
		var pick: Dictionary = pool[rng.randi() % pool.size()]
		out.append(pick.id)
		pool.erase(pick)
	return out
