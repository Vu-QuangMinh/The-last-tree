class_name RunState
extends RefCounted
## One run: 3 acts of branching maps. Pure logic (no autoloads) so the balance sim can drive it.

const ACTS := 3
const BASE_ACTIVE := 6
const SEEDLINGS := {"fight": 3, "elite": 8, "boss": 20}
const WIN_BONUS := 30
const REST_HEAL := 0.3
## Normal fights: each card is common 70% of the time, rare 30%. Elites: 3 rares. Bosses: 3 legendaries.
const RARE_CHANCE := 0.3
## Amber: the run's money, spent at merchants and in some events.
const START_AMBER := 30
const AMBER := {"fight": [14, 22], "elite": [28, 38], "boss": [60, 60]}
const PRICES := {"common": 45, "rare": 75, "legendary": 140, "artifact": 120, "upgrade": 60, "heal": 40}
## What a "?" room turns out to be.
const UNKNOWN_ODDS := {"fight": 0.15, "treasure": 0.08, "shop": 0.07}

var rng := RandomNumberGenerator.new()
var db: SpellDB
var player := PlayerState.new()
var spellbook: Array = []  # spell ids owned this run
var loadout: Array = []  # active spell ids (up to active_slots())
var artifacts: Array = []
var unlocked_spells: Array = []
var unlocked_artifacts: Array = []
var act := 1
var map: Array = []
var row := -1  # -1 = at the start of the act
var col := 1
var seedlings := 0
var kills := 0
var defeated_ids: Array = []
var met: Array = []  # enemy ids met this run, oldest first
var upgraded: Array = []  # spell ids upgraded at rests (their + version is used)
var amber := START_AMBER
var seen_events: Array = []
var over := false
var won := false


func setup(p_db: SpellDB, p_unlocked_spells: Array, p_unlocked_artifacts: Array, seed := 0) -> void:
	db = p_db
	unlocked_spells = p_unlocked_spells
	unlocked_artifacts = p_unlocked_artifacts
	if seed != 0:
		rng.seed = seed
	else:
		rng.randomize()
	for s in db.starters():
		spellbook.append(s.id)
		loadout.append(s.id)
	map = MapGen.generate(rng)


## Active spell slots: 6, changed by artifacts (never by the chant length).
func active_slots() -> int:
	var n := BASE_ACTIVE
	for a in ["spell_satchel", "spell_pouch"]:
		if a in artifacts:
			n += 1
	if "broken_crown" in artifacts:
		n += 2
	if "hungry_tome" in artifacts:
		n -= 1
	return n


## The spell as you have it this run (its + version once upgraded).
func spell(id: String) -> Dictionary:
	var s := db.get_spell(id)
	return SpellDB.upgrade(s) if id in upgraded else s


## Enemy strength within the act, 1-8, spread over the act's floors.
func depth() -> int:
	return clampi(int(ceil((row + 1) * 7.0 / MapGen.FLOORS)), 1, 8)


## The floor you're on (1-based; the boss is one past the last floor).
func floor_no() -> int:
	return row + 1


# ------------------------------------------------------------------ map

## Columns you can step to next.
func choices() -> Array:
	return MapGen.reachable(map, row, col)


func current_node() -> Dictionary:
	return map[row][col] if row >= 0 and map[row][col] != null else {}


## What the current room really is ("?" rooms are revealed when you enter).
func current_kind() -> String:
	var n := current_node()
	return n.get("as", n.get("type", ""))


func move_to(c: int) -> Dictionary:
	row += 1
	col = c
	return current_node()


## Enemy ids for the fight at the current node.
func encounter_ids() -> Array:
	var kind := current_kind()
	if not (kind in ["fight", "elite", "boss"]):
		kind = "fight"
	var ids := EnemyDefs.encounter(kind, act, depth(), rng, met)
	met.append_array(ids)
	return ids


# ------------------------------------------------------------------ fights

func make_fight(enemy_ids: Array) -> Fight:
	var f := Fight.new(db, player)
	f.rng.seed = rng.randi()
	f.artifacts = artifacts
	f.loadout = loadout.map(func(id): return spell(id))
	f.spellbook = spellbook.map(func(id): return spell(id))
	f.start(enemy_ids, act, depth())
	return f


## After a won fight: seedlings, codex, healing. Returns ids newly defeated this run.
func finish_fight(f: Fight) -> void:
	var kind := current_kind()
	if not (kind in ["fight", "elite", "boss"]):
		kind = "fight"
	if not f.won:
		over = true
		return
	kills += f.defeated.size()
	for id in f.defeated:
		if not (id in defeated_ids):
			defeated_ids.append(id)
	seedlings += SEEDLINGS.get(kind, 3)
	var am: Array = AMBER.get(kind, AMBER.fight)
	amber += rng.randi_range(am[0], am[1])
	if "healing_sap" in artifacts:
		player.heal(4)
	if "withered_idol" in artifacts:
		player.heal(6)
	if kind == "boss":
		player.heal(player.max_hp * 0.5)
		if act >= ACTS:
			over = true
			won = true
			seedlings += WIN_BONUS
		else:
			act += 1
			row = -1
			col = MapGen.COLS / 2
			map = MapGen.generate(rng)


func is_boss_node() -> bool:
	return current_node().get("type", "") == "boss"


# ------------------------------------------------------------------ rewards

## Spells you don't own yet. Normal fights: each card common (70%) or rare (30%). Elites: rares. Bosses: legendaries.
## The Scholar's Quill adds a 4th card. Offers always mix at least two categories.
func spell_offer(n := 3, kind := "fight") -> Array:
	if "scholar_quill" in artifacts:
		n += 1
	var by_rarity := {"common": [], "rare": [], "legendary": []}
	for id in unlocked_spells:
		if id in spellbook:
			continue
		var s := db.get_spell(id)
		if not s.is_empty():
			by_rarity[s.rarity].append(s)
	var out := []
	for i in n:
		var r := "common"
		match kind:
			"elite":
				r = "rare"
			"boss":
				r = "legendary"
			_:
				r = "rare" if rng.randf() < RARE_CHANCE else "common"
		var pool: Array = by_rarity[r]
		if pool.is_empty():  # nothing of that rarity left: fall back to the next one down
			for alt in ["rare", "common", "legendary"]:
				if not by_rarity[alt].is_empty():
					pool = by_rarity[alt]
					break
		if pool.is_empty():
			break
		var pick: Dictionary = pool[rng.randi() % pool.size()]
		pool.erase(pick)
		out.append(pick)
	# always offer at least two categories (offensive / defensive / utility)
	if out.size() >= 2 and out.all(func(s): return s.kind == out[0].kind):
		var want: String = out[-1].rarity
		var others: Array = by_rarity[want].filter(func(s): return s.kind != out[0].kind)
		if others.is_empty():
			for r in by_rarity:
				others.append_array(by_rarity[r].filter(func(s): return s.kind != out[0].kind))
		if not others.is_empty():
			out[out.size() - 1] = others[rng.randi() % others.size()]
	return out


func learn_spell(id: String) -> void:
	if id in spellbook:
		return
	spellbook.append(id)
	if loadout.size() < active_slots():
		loadout.append(id)


func artifact_offer(n := 3) -> Array:
	return Artifacts.offer(unlocked_artifacts, artifacts, rng, n)


## Treasure rooms: two normal artifacts and one cursed one.
func treasure_offer() -> Array:
	return Artifacts.offer(unlocked_artifacts, artifacts, rng, 2) + Artifacts.offer(unlocked_artifacts, artifacts, rng, 1, "curse")


## Bosses: pick one relic that raises your element income.
func boss_relic_offer() -> Array:
	return Artifacts.offer(unlocked_artifacts, artifacts, rng, 3, "boss")


func gain_artifact(id: String) -> void:
	if id in artifacts:
		return
	artifacts.append(id)
	if id == "blood_pact":
		player.max_hp -= 12
		player.hp = minf(player.hp, player.max_hp)
	while loadout.size() > active_slots():
		loadout.pop_back()


## Rest site, option 1: heal 30% of max HP.
func rest() -> float:
	return player.heal(player.max_hp * REST_HEAL)


## Rest site, option 2: upgrade a spell for the rest of the run.
func upgrade_spell(id: String) -> void:
	if id in spellbook and not (id in upgraded):
		upgraded.append(id)


func upgradable() -> Array:
	return spellbook.filter(func(id): return not (id in upgraded))


# ------------------------------------------------------------------ ? rooms and events

## Reveal a "?" room: sometimes a fight, treasure or a merchant, usually an event you haven't seen this run.
func resolve_unknown() -> String:
	var n := current_node()
	var r := rng.randf()
	var kind := "event"
	for k in UNKNOWN_ODDS:
		if r < UNKNOWN_ODDS[k]:
			kind = k
			break
		r -= UNKNOWN_ODDS[k]
	n["as"] = kind
	if kind == "event":
		var pool := MapEvents.ALL.filter(func(e): return not (e.id in seen_events))
		if pool.is_empty():
			pool = MapEvents.ALL
		var ev: Dictionary = pool[rng.randi() % pool.size()]
		seen_events.append(ev.id)
		n["event"] = ev.id
	return kind


## Can you take this event option (enough Amber / HP)?
func can_choose(opt: Dictionary) -> bool:
	return amber >= opt.get("amber", 0) and player.hp > opt.get("hp", 0) and player.max_hp > opt.get("max_hp", 0) + 5


## Do what an event option says. Returns {text, fight: bool}.
func choose_event_option(opt: Dictionary) -> Dictionary:
	amber -= opt.get("amber", 0)
	player.hp -= opt.get("hp", 0)
	if opt.has("max_hp"):
		player.max_hp -= opt.max_hp
		player.hp = minf(player.hp, player.max_hp)
	var n: int = opt.get("n", 0)
	match opt.do:
		"heal":
			return {"text": "You heal %d." % player.heal(n)}
		"amber":
			amber += n
			return {"text": "+%d Amber." % n}
		"max_hp":
			player.max_hp += n
			player.hp += n
			return {"text": "+%d max HP." % n}
		"upgrade":
			var names := []
			for i in n:
				var ids := upgradable()
				if ids.is_empty():
					break
				var id: String = ids[rng.randi() % ids.size()]
				upgrade_spell(id)
				names.append(spell(id).name)
			return {"text": "Upgraded: %s." % (", ".join(names) if not names.is_empty() else "nothing left to upgrade")}
		"spell":
			var pool := unlocked_spells.filter(func(id): return not (id in spellbook) and db.get_spell(id).get("rarity", "") == opt.rarity)
			if pool.is_empty():
				amber += opt.get("amber", 0)
				return {"text": "There was nothing left to learn. You keep your Amber."}
			var id: String = pool[rng.randi() % pool.size()]
			learn_spell(id)
			return {"text": "You learn %s." % db.get_spell(id).name}
		"artifact":
			var a := Artifacts.offer(unlocked_artifacts, artifacts, rng, 1, opt.get("pool", "normal"))
			if a.is_empty():
				return {"text": "It was empty."}
			gain_artifact(a[0].id)
			return {"text": "You gain %s: %s" % [a[0].name, a[0].desc]}
		"curse_amber":
			amber += n
			var c := Artifacts.offer(unlocked_artifacts, artifacts, rng, 1, "curse")
			if c.is_empty():
				return {"text": "+%d Amber." % n}
			gain_artifact(c[0].id)
			return {"text": "+%d Amber, and %s clings to you: %s" % [n, c[0].name, c[0].desc]}
		"gamble":
			if rng.randf() < 0.5:
				player.heal(player.max_hp)
				return {"text": "The mushrooms approve. You feel wonderful (healed to full)."}
			return {"text": "The mushrooms do not approve. Something jumps out!", "fight": true}
		"fight":
			return {"text": "It attacks!", "fight": true}
	return {"text": "You move on."}


# ------------------------------------------------------------------ the merchant

## What the merchant sells: 3 spells, 2 artifacts, an upgrade and a meal.
func shop_stock() -> Array:
	var items := []
	var spells := spell_offer(2, "fight") + spell_offer(1, "elite")
	if rng.randf() < 0.3:
		spells += spell_offer(1, "boss")
	var seen := {}
	for s in spells:
		if seen.has(s.id):
			continue
		seen[s.id] = true
		items.append({"kind": "spell", "spell": s, "price": PRICES[s.rarity]})
	for a in artifact_offer(2):
		items.append({"kind": "artifact", "artifact": a, "price": PRICES.artifact})
	items.append({"kind": "upgrade", "price": PRICES.upgrade})
	items.append({"kind": "heal", "price": PRICES.heal})
	return items


## Pay for an item (the caller applies it). Returns false if you can't afford it.
func pay(price: int) -> bool:
	if amber < price:
		return false
	amber -= price
	return true


## Seedlings banked at the end (the pouch adds a quarter).
func final_seedlings() -> int:
	var s := seedlings
	if "seedling_pouch" in artifacts:
		s = int(s * 1.25)
	return s


## Loadout editing (before each encounter).
func toggle_active(id: String) -> bool:
	if id in loadout:
		loadout.erase(id)
		return true
	if loadout.size() >= active_slots() or not (id in spellbook):
		return false
	loadout.append(id)
	return true
