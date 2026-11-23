class_name DiceRun
extends RefCounted
## Die on Stage (2026-11-15): one run. Three dice (each a list of six faces; the "+1" / "-1" rewards change a face for
## good), up to DiceCards.MAX_CARDS cards, artifacts (DiceArtifacts), HP as in the chant game, coins, three acts on
## the zoned hex map (DiceMapGen.make_zoned: easy, mid, hard from left to right; forward moves only; after
## DiceMapGen.BOSS_SPEED_EVERY moves the boss comes for you, faster and faster (DiceMapGen.boss_speed), and when it reaches you its fight starts).

const START_DICE := 3
const START_COINS := 5
const LAST_ACT := 3
const LEFT_OUT := ["mirror_knight"]  # (not in Die on Stage for now, the user 2026-11-16)
## The map: "sts" (2026-11-17: the Slay the Spire map, DiceMapGen.make_sts; no boss chase) or "zoned" (the hex map with
## the boss chase, DiceMapGen.make_zoned).
const MAP_STYLE := "zoned"  # (back to the hex map, the user 2026-11-17)

var rng := RandomNumberGenerator.new()
var act := 1
var hp := 50
var max_hp := 50
var leaves := 0  # (shown as coins: the money of this mode, 2026-11-16)
var upgrades := {}  # move id -> "boost" or "slot" (a campfire upgrade, once per move: DiceCards.card)
var dice: Array = []  # one Array of 6 faces per die (DiceFace: {v, paint, carve})
var cards: Array = []  # card ids, at most DiceCards.MAX_CARDS
var map: Array = []
var row := -1
var col := 0
var visited: Array = []  # "row:col" of every tile you stood on this act
var turns := 0  # moves made this act (the boss's speed grows with it: DiceMapGen.boss_speed)
var boss := Vector2i.ZERO  # where the boss stands: Vector2i(level, lane) (DiceMapGen.boss_home at the start of an act)
var artifacts: Array = []  # DiceArtifacts ids
var seen: Array = []  # enemies met (so the next fights prefer new ones)
var whirl_uses := 0  # (whirlpool dives this run: each costs WHIRL_HP more than the one before)
var events_seen: Array = []  # "?" stories met this run (DiceEvents: each comes once)
var won := false


func setup(seed_value := 0) -> void:
	if seed_value != 0:
		rng.seed = seed_value
	else:
		rng.randomize()
	var p := PlayerState.new()
	max_hp = int(p.max_hp)
	hp = max_hp
	leaves = START_COINS
	dice.clear()
	for i in START_DICE:
		dice.append(DiceFace.d6())
	cards = DiceCards.STARTERS.duplicate()
	act = 1
	new_map()


func new_map() -> void:
	map = DiceMapGen.make_sts(rng) if MAP_STYLE == "sts" else DiceMapGen.make_zoned(rng)
	row = -1
	col = 0
	visited.clear()
	turns = 0
	boss = DiceMapGen.boss_home(map)


func current_node() -> Dictionary:
	if row < 0 or row >= map.size() or col >= map[row].size():
		return {}
	return map[row][col]


## Roll one die: the index of the face that shows.
func roll(i: int) -> int:
	return rng.randi() % (dice[i] as Array).size()


func face(i: int, k: int) -> Dictionary:
	return dice[i][k]


# ------------------------------------------------------------------ the map: forward moves, the boss chase

## The tiles you can go to next, as Vector2i(row, col): forward only, hollows left out.
func options() -> Array:
	if MAP_STYLE == "sts":
		return DiceMapGen.reachable(map, row, col).map(func(c): return Vector2i(row + 1, int(c)))
	return DiceMapGen.forward(map, row, col)


## Where you stand, as the boss sees it: Vector2i(level, lane) (before the start: nowhere).
func my_cell() -> Vector2i:
	if row < 0:
		return Vector2i(-9, -9)
	return Vector2i(row, int(map[row][col].lane))


## Has the boss reached you?
func caught() -> bool:
	if MAP_STYLE == "sts":
		return false  # (no chase: the boss waits at the top)
	return row >= 0 and boss == my_cell()


## Moves the boss would still wait before it starts coming (0: it is coming).
func boss_wait() -> int:
	return maxi(0, DiceMapGen.BOSS_SPEED_EVERY - turns)


## Tiles the boss walks after each of your moves right now.
func boss_speed() -> int:
	return DiceMapGen.boss_speed(turns)


## Step onto a tile (you can step onto the boss: that is its fight). Then the boss moves, once it has waited long enough.
## Returns the tile.
func move_to(r: int, c: int) -> Dictionary:
	row = r
	col = c
	visited.append("%d:%d" % [r, c])
	if String(map[r][c].type) != "haste":  # (a haste tile: a free step: not counted, the boss stays)
		_after_move()
	return current_node()


## A whirlpool dive costs this much HP now (5, then 10, 15...).
const WHIRL_HP := 5


func whirl_cost() -> int:
	return WHIRL_HP * (whirl_uses + 1)


func can_dive() -> bool:
	return current_node().has("link") and hp > whirl_cost()


## Dive into the whirlpool you stand on: lose its HP, come out at the other one (no move counted, the boss stays).
func dive() -> void:
	if not can_dive():
		return
	hp -= whirl_cost()
	whirl_uses += 1
	var l: Array = current_node().link
	row = int(l[0])
	col = int(l[1])
	visited.append("%d:%d" % [row, col])


## Nothing ahead: you wait, and the boss comes.
func wait_turn() -> void:
	_after_move()


func _after_move() -> void:
	turns += 1
	if MAP_STYLE == "sts":
		return
	if caught():
		return
	for k in DiceMapGen.boss_speed(turns):
		boss = DiceMapGen.boss_step(map, boss, my_cell())
		if caught():
			return


## The boss was beaten: the next act, or the run is won.
func next_act() -> void:
	if act >= LAST_ACT:
		won = true
		return
	act += 1
	hp = max_hp  # (a new act: healed, as after a boss in the chant game)
	new_map()


# ------------------------------------------------------------------ fights

## The enemies of a fight here: "fight" (a normal one, easy, medium or hard by how many moves you have made this act: DiceMapGen.fight_tier),
## "double" (two of the act's hardest normal fights at once, at most 4 enemies), "elite" (a mini boss) or "boss".
## Only enemies that are one puppet each (no Handyman arms, no dragon parts).
func encounter(kind: String) -> Array:
	match kind:
		"boss":
			var bosses: Array = EnemyDefs.BOSSES.get(act, []).filter(func(id): return _simple(id))
			if bosses.is_empty():
				bosses = ["giant_slime"]
			return [bosses[rng.randi() % bosses.size()]]
		"elite":
			var pool := EnemyDefs.elites(act).filter(func(id): return EnemyDefs.ids_of(id).all(func(x): return _simple(x)))
			if pool.is_empty():
				return ["enraged_bear"]
			var fresh := pool.filter(func(id): return not (EnemyDefs.ids_of(id)[0] in seen))
			if not fresh.is_empty():
				pool = fresh
			var ids: Array = EnemyDefs.ids_of(pool[rng.randi() % pool.size()])
			seen.append_array(ids)
			return ids
		"double":
			var a := _group("hard")
			var b := _group("hard")
			return (a + b).slice(0, 4)
	var tier := DiceMapGen.sts_tier(maxi(0, row)) if MAP_STYLE == "sts" else DiceMapGen.fight_tier(turns)
	return _group(["easy", "medium", "hard"][tier])


func _group(tier: String) -> Array:
	var pools: Dictionary = EnemyDefs.POOLS.get(act, EnemyDefs.POOLS[1])
	var groups: Array = pools.get(tier, pools.get("medium", pools.values()[0]))
	groups = groups.filter(func(g): return g.ids.all(func(x): return _simple(x)))
	groups = groups.filter(func(g): return not g.ids.all(func(x): return x in DiceFight.LINGS) or g.ids.size() == 2)  # (spirits on their own come two at a time, 2026-11-17)
	if groups.is_empty():
		return ["ashling"]
	var fresh2 := groups.filter(func(g): return not g.ids.any(func(x): return x in seen.slice(maxi(0, seen.size() - 6))))
	var from: Array = fresh2 if not fresh2.is_empty() else groups
	var pick: Array = from[rng.randi() % from.size()].ids
	seen.append_array(pick)
	return pick.duplicate()


static func _simple(id: String) -> bool:
	var d: Dictionary = EnemyDefs.get_def(id)
	if d.is_empty():
		return false
	return not d.has("rig_part") and not d.has("dragon") and id != "handyman" and not HandymanRig.ARMS.has(id) and not (id in LEFT_OUT)


# ------------------------------------------------------------------ cards and dice

## Three different cards (for a shop, a treasure, a mini boss; `from_boss`: a boss's, of higher rarity). Each is first
## given a rarity (DiceCards.OFFER_ODDS; a boss's: BOSS_ODDS), then a card of it. A card you already have can be offered (taking
## it upgrades yours), unless yours is already upgraded.
func card_offer(n := 3, from_boss := false) -> Array:
	var pool := DiceCards.pool().filter(func(id): return not upgrades.has(id))
	var out := []
	while out.size() < n and not pool.is_empty():
		var want := _roll_rarity(DiceCards.BOSS_ODDS if from_boss else DiceCards.OFFER_ODDS)
		var of := pool.filter(func(id): return DiceCards.rarity(id) == want)
		if of.is_empty():
			of = pool.filter(func(id): return DiceCards.rarity(id) != "common") if from_boss else pool
		if of.is_empty():
			of = pool
		var pick: String = of[rng.randi() % of.size()]
		out.append(pick)
		pool.erase(pick)
	return out


func _roll_rarity(odds: Dictionary) -> String:
	var x := rng.randf()
	for k in odds:
		x -= float(odds[k])
		if x < 0.0:
			return k
	return "common"


func has_room() -> bool:
	return cards.size() < DiceCards.MAX_CARDS


## A card joins (replace_i >= 0: it takes the place of that card).
func gain_card(id: String, replace_i := -1) -> void:
	if replace_i >= 0 and replace_i < cards.size():
		cards[replace_i] = id
	elif has_room():
		cards.append(id)


## The dice mods, on face `face_i` of die `i`, for good. Adjustment: its number changes by `by` (never below 0; no
## top limit).
func change_face(i: int, face_i: int, by: int) -> void:
	var f: Dictionary = dice[i][face_i]
	f.v = maxi(0, int(f.v) + by)


## Painting: the face takes this colour (DiceFace.PAINTS), over any it had.
func paint_face(i: int, face_i: int, colour: String) -> void:
	dice[i][face_i].paint = colour


## Carving: the face takes this symbol (DiceFace.CARVES), over any it had.
func carve_face(i: int, face_i: int, sym: String) -> void:
	dice[i][face_i].carve = sym


## Three artifacts you don't have (an artifact tile's reward).
func artifact_offer(n := 3) -> Array:
	var pool := DiceArtifacts.ITEMS.keys().filter(func(id): return not (id in artifacts))
	var out := []
	while out.size() < n and not pool.is_empty():
		out.append(pool.pop_at(rng.randi() % pool.size()))
	return out


func gain_artifact(id: String) -> void:
	if id in artifacts:
		return
	artifacts.append(id)
	if id == "spare_die":
		dice.append(DiceFace.d6())  # (a fourth die, for good)
	if id == "ten_ten":  # (10/10: every die a plain D10, its mods gone)
		for i in dice.size():
			dice[i] = DiceFace.dn(10)


## The move in slot `ci` as it is now (upgraded or not: DiceCards.card).
func card_at(ci: int) -> Dictionary:
	return DiceCards.card(String(cards[ci]), String(upgrades.get(cards[ci], "")))


## A campfire upgrade: once per move.
func upgrade(id: String, how: String) -> void:
	if not upgrades.has(id):
		upgrades[id] = how


## A boss's reward: one more die, a d4 or a d10.
func add_die(sides: int) -> void:
	dice.append(DiceFace.dn(sides))


func has_artifact(id: String) -> bool:
	return id in artifacts


func heal(n: int) -> int:
	var h := mini(n, max_hp - hp)
	hp += h
	return h
