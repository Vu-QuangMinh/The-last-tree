class_name MarblesRun
extends RefCounted
## Marble mode (2026-11-21): a run. The classic map (MarbleMapGen), the main game's enemy pools (EnemyDefs.POOLS), coins,
## artifacts and bottles (MarbleItems), a bag of marbles and the user's new cards (MarbleCards).
##
## `cards`: the active row (in order: "the card to the left / right" is read from it). `backpack`: the cards you carry
## but don't fight with, at most MarbleCards.MAX_BACKPACK. Finding a card you have upgrades it (twice at most).

const START_MARBLES := 3  # of each colour
const COLOURS := ["F", "W", "A"]
## A carved (upgraded) marble's symbol. Rare ones are found less often.
const SYMBOLS := ["sword", "shield", "coin", "heart", "star", "fist", "ghost", "spent", "skull", "wing"]
const RARE_SYMBOLS := ["skull", "wing"]
const CARVED_ODDS := 0.7  # (a marble found after a fight: carved this often)

const LAST_ACT := 3
const LEFT_OUT := ["mirror_knight"]  # (not in Marble mode for now)
## In reserve for later (the user: Cinder Hound and Yeti 2026-11-21): no fight has them. (The Winged Turtle is an Act 1
## mini boss since 2026-11-23.)
const RESERVE := ["cinder_hound", "yeti"]

var rng := RandomNumberGenerator.new()
var act := 1
var hp := 50
var max_hp := 50
var leaves := 0  # (coins)
var cards: Array = []  # the active row: card ids, in order
var map: Array = []
var row := -1
var col := 0
var visited: Array = []  # "row:col" of every room you stood in this act
var turns := 0  # rooms entered this act
var artifacts: Array = []  # MarbleItems.ARTIFACTS ids
var seen: Array = []  # enemies met (so the next fights prefer new ones)
var won := false
var patterns := {}  # card id -> its pattern when the main game's run changed it (wax seals, curses, a fusion)
var start := {}  # what the main game's events left for this fight: {burn, stun, shield, gift: [colours / "random"]}
var fused := {}  # fused card id -> {name, parts: [[card id, level], ...], text}: it does what each part does
var mods := {}  # card id -> the curses on it: {frag: Durability -n, cd: Cooldown +n, pain: casting it hurts you n}
var bag: Array = []  # every marble you own: {c: "F"/"W"/"A", sym: "" or one of SYMBOLS}
var backpack: Array = []  # card ids
var levels := {}  # card id -> 0, 1, 2
var perm := {}  # card id -> numbers that grow for the whole run (Circle of Life, Knivel's Innocence, A Brother's Cluelessness)
var bottles: Array = []  # MarbleItems.BOTTLES ids, at most MarbleItems.BOTTLE_SLOTS
var card_lean := 0.5  # (the reward after a fight: the chance of a card; each card makes marbles likelier, and the other way)


func setup(seed_value := 0) -> void:
	if seed_value != 0:
		rng.seed = seed_value
	else:
		rng.randomize()
	var p := PlayerState.new()
	max_hp = int(p.max_hp)
	hp = max_hp
	act = 1
	new_map()
	bag.clear()
	for c in COLOURS:
		for k in START_MARBLES:
			bag.append({"c": c, "sym": ""})
	cards = MarbleCards.START.duplicate()
	backpack.clear()
	levels.clear()
	perm.clear()
	bottles.clear()
	artifacts.clear()
	card_lean = 0.5
	leaves = 5


## The card in slot `ci` of the active row, at its level.
func card_at(ci: int) -> Dictionary:
	if ci >= 100:
		return {"name": "Bottle", "id": "", "p": {}, "t": true}  # (the fight screen aims a bottle as 100 + its slot)
	if ci < 0 or ci >= cards.size():
		return {}
	var id := String(cards[ci])
	var c := MarbleCards.card(id, int(levels.get(id, 0)), perm)
	if fused.has(id):
		var fz: Dictionary = fused[id]
		var p := {}
		var t := false
		for part in fz.parts:
			var pc := MarbleCards.card(String(part[0]), int(part[1]))
			t = t or bool(pc.get("t", false))
			if pc.p.has("dur"):
				p.dur = mini(int(p.get("dur", 99)), int(pc.p.dur))  # (the lower Durability of the two)
			if pc.p.has("cd"):
				p.cd = maxi(int(p.get("cd", 0)), int(pc.p.cd))  # (the longer Cooldown)
		c = {"id": id, "name": String(fz.name), "pattern": "", "level": 0, "power": false, "t": t, "p": p,
			"text": String(fz.get("text", "")), "rarity": "rare", "parts": fz.parts}
	if patterns.has(id) and not c.is_empty():
		c.pattern = String(patterns[id])
	if mods.has(id) and not c.is_empty():
		var m: Dictionary = mods[id]
		c.p = (c.p as Dictionary).duplicate()
		if m.has("frag"):
			c.p.dur = maxi(1, int(c.p.get("dur", 4)) - int(m.frag))  # (the Curse of Fragility: no Durability: 4 - 1)
		if m.has("cd"):
			c.p.cd = int(c.p.get("cd", 0)) + int(m.cd)
		if m.has("pain"):
			c.p.pain = int(m.pain)
		if m.has("frag") and not c.has("parts"):
			c.text = MarbleCards.with_durability(String(c.text), int(c.p.dur))  # (the curse's lower Durability, in its words)
	return c


func owns(id: String) -> bool:
	return id in cards or id in backpack


## Can this card still be upgraded (you have it, below its last level)?
func can_upgrade(id: String) -> bool:
	return owns(id) and int(levels.get(id, 0)) < 2


## A card found: one you have is upgraded; a new one goes into the active row if it has room, else the backpack (if the
## backpack is full, `drop` is the backpack index thrown away for it, or -1 to leave the new card behind).
func take_card(id: String, drop := -1) -> String:
	if owns(id):
		if can_upgrade(id):
			levels[id] = int(levels.get(id, 0)) + 1
			return "upgraded"
		return "max"
	if cards.size() < MAX_ACTIVE:
		cards.append(id)
		return "active"
	if backpack.size() < MarbleCards.MAX_BACKPACK:
		backpack.append(id)
		return "backpack"
	if drop >= 0 and drop < backpack.size():
		backpack[drop] = id
		return "swapped"
	return "left"


const MAX_ACTIVE := 5


## A marble found after a fight: carved CARVED_ODDS of the time (a rare symbol a quarter as often as the others).
func random_marble() -> Dictionary:
	var m := {"c": COLOURS[rng.randi() % COLOURS.size()], "sym": ""}
	if rng.randf() < CARVED_ODDS:
		m.sym = random_marble_symbol()
	return m


## A carving's symbol at random (a rare one a quarter as often as each of the others).
func random_marble_symbol() -> String:
	var pool := []
	for s in SYMBOLS:
		for k in (1 if s in RARE_SYMBOLS else 4):
			pool.append(s)
	return String(pool[rng.randi() % pool.size()])


func count_marbles(colour := "", carved_only := false) -> int:
	var n := 0
	for m in bag:
		if (colour == "" or m.c == colour) and (not carved_only or String(m.sym) != ""):
			n += 1
	return n


# ------------------------------------------------------------------ the map: the main game's classic map (no boss chase)

func new_map() -> void:
	map = MarbleMapGen.make(rng)
	row = -1
	col = 0
	visited.clear()
	turns = 0


func options() -> Array:
	return MarbleMapGen.reachable(map, row, col).map(func(c): return Vector2i(row + 1, int(c)))


func caught() -> bool:
	return false


func move_to(r: int, c: int) -> Dictionary:
	row = r
	col = c
	visited.append("%d:%d" % [r, c])
	turns += 1
	return current_node()


func current_node() -> Dictionary:
	if row < 0 or row >= map.size() or col >= map[row].size() or map[row][col] == null:
		return {}
	return map[row][col]


## The boss was beaten: the next act, or the run is won.
func next_act() -> void:
	if act >= LAST_ACT:
		won = true
		return
	act += 1
	hp = max_hp
	new_map()


func has_artifact(id: String) -> bool:
	return id in artifacts


func heal(n: int) -> int:
	var h := mini(n, max_hp - hp)
	hp += h
	return h


## The enemies of a fight: "fight" (easy, medium or hard by the floor), "elite" (a mini boss) or "boss". Only enemies
## that are one puppet each (no Handyman arms, no dragon parts).
func encounter(kind: String) -> Array:
	match kind:
		"boss":
			var bosses: Array = EnemyDefs.BOSSES.get(act, []).filter(func(id): return simple(id))
			if bosses.is_empty():
				bosses = ["giant_slime"]
			return [bosses[rng.randi() % bosses.size()]]
		"elite":
			var pool := EnemyDefs.elites(act).filter(func(id): return EnemyDefs.ids_of(id).all(func(x): return simple(x)))
			if pool.is_empty():
				return ["enraged_bear"]
			var fresh := pool.filter(func(id): return not (EnemyDefs.ids_of(id)[0] in seen))
			if not fresh.is_empty():
				pool = fresh
			var ids: Array = EnemyDefs.ids_of(pool[rng.randi() % pool.size()])
			seen.append_array(ids)
			return ids
	return _group(["easy", "medium", "hard"][MarbleMapGen.tier(maxi(0, row))])


func _group(tier: String) -> Array:
	var pools: Dictionary = EnemyDefs.POOLS.get(act, EnemyDefs.POOLS[1])
	var groups: Array = pools.get(tier, pools.get("medium", pools.values()[0]))
	groups = groups.filter(func(g): return g.ids.all(func(x): return simple(x)))
	groups = groups.filter(func(g): return not g.ids.all(func(x): return x in StageFight.LINGS) or g.ids.size() == 2)  # (spirits on their own come two at a time)
	if groups.is_empty():
		return ["ashling", "iceling"]
	var recent := seen.slice(maxi(0, seen.size() - 6))
	var fresh := groups.filter(func(g): return not g.ids.any(func(x): return x in recent))
	var from: Array = fresh if not fresh.is_empty() else groups
	var pick: Array = from[rng.randi() % from.size()].ids
	seen.append_array(pick)
	return pick.duplicate()


## Can this enemy be in a Marble mode fight (one puppet, not left out)?
static func simple(id: String) -> bool:
	var d: Dictionary = EnemyDefs.get_def(id)
	if d.is_empty():
		return false
	return not d.has("rig_part") and not d.has("dragon") and id != "handyman" and not HandymanRig.ARMS.has(id) and not (id in LEFT_OUT) 		and not (id in RESERVE)


func _roll_rarity(odds: Dictionary) -> String:
	var x := rng.randf()
	for k in odds:
		x -= float(odds[k])
		if x < 0.0:
			return k
	return String(odds.keys()[0])


# ------------------------------------------------------------------ rewards and the shop

const OFFER_ODDS := {"common": 0.6, "rare": 0.33, "legendary": 0.07}
const BOSS_ODDS := {"rare": 0.7, "legendary": 0.3}
const NEVER_OFFERED := ["a_brothers_cleverness", "bite"]  # (Cleverness: only by Cluelessness; Bite: Curse of the Night makes them, and it is its own card too)


## Cards to choose from: each gets a rarity first, then a card of it. A card you have can come (taking it upgrades
## yours) unless it is at its last level.
func card_offer(n := 3, from_boss := false) -> Array:
	var pool: Array = MarbleCards.C.keys().filter(func(id): return not (id in NEVER_OFFERED) and (not owns(id) or can_upgrade(id)))
	if count_marbles("", true) < 2:
		pool.erase("whim_of_the_pianist")  # (it only comes once you have 2 carved marbles)
	var out := []
	while out.size() < n and not pool.is_empty():
		var want := _roll_rarity(BOSS_ODDS if from_boss else OFFER_ODDS)
		var of := pool.filter(func(id): return MarbleCards.rarity(id) == want)
		if of.is_empty():
			of = pool
		var pick: String = of[rng.randi() % of.size()]
		out.append(pick)
		pool.erase(pick)
	return out


## After a normal fight: a card or marbles, a leaning 50/50 (what you got makes the other likelier next time).
func reward_kind() -> String:
	var card := rng.randf() < card_lean
	card_lean = clampf(card_lean + (-0.2 if card else 0.2), 0.1, 0.9)
	return "card" if card else "marble"


func marble_offer(n := 3) -> Array:
	var out := []
	for k in n:
		out.append(random_marble())
	return out


func card_price(id: String) -> int:
	return int(MarbleItems.CARD_PRICE.get(MarbleCards.rarity(id), 6))


func marble_price(m: Dictionary) -> int:
	return int(MarbleItems.MARBLE_PRICE["carved" if String(m.sym) != "" else "plain"])


func artifact_offer(n := 3) -> Array:
	var pool: Array = MarbleItems.ARTIFACTS.keys().filter(func(id): return not (id in artifacts))
	var out := []
	while out.size() < n and not pool.is_empty():
		out.append(pool.pop_at(rng.randi() % pool.size()))
	return out


func bottle_offer(n := 3) -> Array:
	var pool: Array = MarbleItems.BOTTLES.keys()
	var out := []
	for k in n:
		out.append(pool[rng.randi() % pool.size()])
	return out


func gain_bottle(id: String) -> bool:
	if bottles.size() >= MarbleItems.BOTTLE_SLOTS:
		return false
	bottles.append(id)
	return true


func gain_artifact(id: String) -> void:
	if not (id in artifacts):
		artifacts.append(id)


## The map's top lines (MarblesMapView asks).
func map_head_lines() -> Array:
	var names := []
	for ci in cards.size():
		names.append(String(card_at(ci).name))
	var arts := artifacts.map(func(id): return String(MarbleItems.artifact(id).get("name", id)))
	var carved := count_marbles("", true)
	return ["Marble mode · Act %d    ❤ %d/%d    %d coins" % [act, hp, max_hp, leaves],
		"Marbles: %d Fire, %d Water, %d Wind (%d carved)" % [count_marbles("F"), count_marbles("W"), count_marbles("A"), carved],
		"Cards: %s    Backpack: %d/%d" % [", ".join(names), backpack.size(), MarbleCards.MAX_BACKPACK],
		"Artifacts: %s" % (", ".join(arts) if not arts.is_empty() else "none")]
