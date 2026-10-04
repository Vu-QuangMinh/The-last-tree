class_name SpellDB
extends RefCounted
## Loads data/spells.json (chant patterns). Adds derived fields: size, rarity_name, targeted, kind.
## Rarity (common / rare / legendary) is set per spell in the JSON.

const RARITY_NAMES := {"common": "Common", "rare": "Rare", "legendary": "Legendary"}
const TARGETED_OPS := ["steal", "pluck", "move", "redirect", "strike", "burn", "poison", "weak", "freeze", "expose", "ethereal", "rotate", "swap",
	"convert", "purge", "shatter", "stoke", "siphon", "execute", "insert", "curse"]

## Every spell is in one of three categories: Offensive, Defensive, Utility (reward offers, card colour and tag).
const DAMAGE_OPS := ["steal", "pluck", "strike", "burn", "poison", "purge", "execute", "siphon", "amplify", "echo", "stoke", "expose", "annihilate", "barrage", "random_hit"]
const DEFENSE_OPS := ["shield", "heal", "aegis", "thorns", "weak", "freeze", "cleanse", "redirect"]
const DAMAGE_KEYS := ["burn_bonus", "strike_poison", "strike_burn", "strike_bonus"]
const DEFENSE_KEYS := ["thorns", "weak25"]
const KIND_NAMES := {"damage": "Offensive", "defense": "Defensive", "utility": "Utility"}

var all_spells: Array = []
var _by_id := {}


static func load_from(path: String) -> SpellDB:
	var db := SpellDB.new()
	var data = JSON.parse_string(FileAccess.get_file_as_string(path))
	assert(data is Dictionary, "spells.json failed to parse")
	for s in data.spells:
		s.size = s.pattern.length()
		s.rarity_name = RARITY_NAMES[s.rarity]
		s.power = s.get("power", false)
		s.starter = s.get("starter", false)
		s.targeted = _needs_target(s.effects)
		s.kind = kind_of(s.effects)
		s.upgraded = false
		db.all_spells.append(s)
		db._by_id[s.id] = s
	return db


## damage if anything removes elements or harms enemies, else defense if anything protects you, else utility.
static func kind_of(effects: Array) -> String:
	var flat := []
	for e in effects:
		if e.op == "each_turn":
			flat.append_array(e.effects)
		else:
			flat.append(e)
	var dmg := flat.any(func(e): return e.op in DAMAGE_OPS or (e.op in ["passive", "curse"] and e.key in DAMAGE_KEYS))
	if dmg:
		return "damage"
	var dfn := flat.any(func(e): return e.op in DEFENSE_OPS or (e.op in ["passive", "curse"] and e.key in DEFENSE_KEYS) or (e.op == "ethereal" and e.target == "self"))
	return "defense" if dfn else "utility"


## True if any effect asks the player to pick one enemy.
static func _needs_target(effects: Array) -> bool:
	for e in effects:
		if e.op in TARGETED_OPS and e.get("target", "") in ["target", "two"]:
			return true
		if e.op == "each_turn" and _needs_target(e.effects):
			return true
	return false


func get_spell(id: String) -> Dictionary:
	return _by_id.get(id, {})


## The + version of a spell (Rest: upgrade). Numbers go up; spells without numbers get +1 element next turn.
static func upgrade(spell: Dictionary) -> Dictionary:
	var s := spell.duplicate(true)
	if s.get("upgraded", false):
		return s
	s.upgraded = true
	s.name = s.name + "+"
	var improved := false
	for e in s.effects:
		var parts: Array = e.effects if e.op == "each_turn" else [e]
		for x in parts:
			if x.op in ["shield", "heal"]:
				x.n += 2
				improved = true
			elif x.op in ["steal", "strike", "burn", "poison", "purge", "siphon", "move", "pluck", "draw", "thorns", "amplify", "retain", "passive", "summon_spells", "expose"] and x.has("n"):
				x.n += 1
				improved = true
			elif x.op in ["weak", "freeze"]:
				x.turns += 1
				improved = true
			elif x.op == "execute":
				x.max += 1
				improved = true
			elif x.op == "aegis":
				x.n += 1
				improved = true
			elif x.op == "duplicate":
				x.times += 1
				improved = true
	if not improved:
		s.effects.append({"op": "draw", "n": 1, "when": "next", "el": "random"})
	return s


func starters() -> Array:
	return all_spells.filter(func(s): return s.starter)
