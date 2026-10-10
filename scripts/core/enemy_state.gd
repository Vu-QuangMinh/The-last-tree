class_name EnemyState
extends RefCounted
## One enemy in a fight. HP is a row of Essence (left to right); `armor[i]` marks Essence that can't be
## removed this turn (it still counts for matching).
## Burn N: at the start of its turn it loses its N rightmost Essence, then the Burn is gone.
## Poison N: grows by 1 every turn; it dies once Poison reaches the Essence it has left. Fire and venom ignore armour.

## Just summoned (or popped out mid-fight): it shows its intent first and only acts after a whole turn of yours.
var fresh := false
var keep_intent := false  # (it skipped its first enemy turn: keep the intent it showed, don't plan a new one)
var def: Dictionary
var id := ""
var name := ""
var elements: Array = []  # element letters
var armor: Array = []  # bool per element
var dmg_bonus := 0
var lit: Array = []  # (legacy, kept in step with elements; unused)
var acting_part := ""  # which part is acting right now ("L" / "R": one of her walls; "": the enemy itself)
var yin := ""  # the Yin Yang Beast's colour: "white" or "black" ("" for everyone else)
var charge_dmg := -1
var knocked := false
var lives := 2  # a Handyman hand: times it can be knocked down this phase (then it stays down until the next one)
var revive_in := 0  # a knocked-down hand: turns until it gets back up (0: it stays down)
var disarmed := 0  # Disarmed (your Deafening Blast): its attacks do nothing on its next turn
var invoke_all := false
var invoke_next := -1  # the Invoker: the spell he casts this turn, whatever you chant (one he hasn't cast yet, if he can)
var cast_ids: Array = []  # the Invoker's spells cast so far this fight  # the Invoker casts every one of his spells on his next turn (gold dust)  # a Handyman hand at 0 Essence: skips its action, back whole next turn
var opener: Array = []  # moves made once before its cycle starts (the Yin Yang Cubs' first flip)
var conjured: Array = []  # the Invoker's 3 spells this turn (their patterns already stripped)
var stripped: Array = []  # the Invoker's words so far: Essence gone from his spells' patterns  # a Charge in progress: the hit it will land (-1: not charging)
var power := 0  # Power: +1 damage per hit for each stack (her song; Empower)
var wall_step := {"L": 0, "R": 0}  # where each wall is in its attack pattern (a regrown wall starts over)
var parts: Array = []  # per Essence: "" = the enemy itself, "L" / "R" = a wall it stands behind (Bramble Matron)
var burn := 0
var poison := 0
var weak_turns := 0
var weak25 := false  # Stillness (permanent)
var freeze_turns := 0
var no_mend := false  # Cauterize
var ethereal := false  # from its own intent: your next chant can't touch it
var phased := false  # from your spell: your spells remove double from it this turn
var struck_this_turn := false
var move_index := 0
var intent := {}
var last_intent := {}
var is_boss := false
var is_elite := false
var phase := 1
var hexed_turns := 0
var redirect_to: EnemyState = null  # this turn's intent was redirected at this enemy


func setup(p_def: Dictionary, extra: Array = []) -> void:
	def = p_def
	id = def.id
	name = def.name
	for c in def.hp:
		elements.append(c)
	elements.append_array(extra)
	armor.resize(elements.size())
	armor.fill(false)
	lit.clear()
	_fix_lit()
	is_boss = def.get("boss", false)
	is_elite = def.get("elite", false)
	yin = def.get("yin", "")


func size() -> int:
	return elements.size()


## Dead: no Essence left, or Poison has caught up with the Essence it has left (armour doesn't help).
func is_dead() -> bool:
	if elements.is_empty() or poisoned_out():
		return true
	return has_passive("briar_walls") and not ("" in parts)


# ------------------------------------------------------------------ walls (Bramble Matron)

## Does a wall still stand in front of it?
func has_walls() -> bool:
	return "L" in parts or "R" in parts


## How many of its walls still stand (0 to 2).
func walls_standing() -> int:
	return int("L" in parts) + int("R" in parts)


## Remove n Essence from one part of the row (a wall, or "" for the enemy itself), from that part's right or left
## end (armour holds). Used when an effect hits every enemy: each part of the Matron is hit on its own.
func remove_in_part(part: String, n: int, from_right: bool) -> Array:
	_fix_lit()
	var removed := []
	while removed.size() < n:
		var k := -1
		for m in elements.size():
			var i: int = elements.size() - 1 - m if from_right else m
			if parts[i] == part and not armor[i]:
				k = i
				break
		if k < 0:
			break
		removed.append(_remove_at(k))
	return removed


## A random Essence for a random effect: a wall's while any wall stands. -1: none.
func random_pick(rng: RandomNumberGenerator) -> int:
	_fix_lit()
	var free := []
	for i in elements.size():
		if not armor[i] and (parts[i] != "" or not has_walls()):
			free.append(i)
	if free.is_empty():
		for i in elements.size():
			if not armor[i]:
				free.append(i)
	return free[rng.randi() % free.size()] if not free.is_empty() else -1


## Regrow a wall on this side: n new Essence (random), at the very edge of its row.
func grow_wall(side: String, els: Array) -> void:
	_fix_lit()
	for el in els:
		if side == "L":
			elements.push_front(el)
			armor.push_front(false)
			lit.push_front(false)
			parts.push_front("L")
		else:
			elements.append(el)
			armor.append(false)
			lit.append(false)
			parts.append("R")


## Poison as high as (or higher than) the Essence it has left: it dies at once.
func poisoned_out() -> bool:
	return poison > 0 and poison >= elements.size()


func hp_text() -> String:
	return "".join(elements)


## Will this Essence burn away at the start of its next turn? (The rightmost `burn` of them.)
func is_lit(i: int) -> bool:
	return i >= 0 and i < elements.size() and i >= elements.size() - burn


## (Poison doesn't eat Essence any more: it builds up until it kills, see poisoned_out. No Essence is marked.)
func is_poisoned(_i: int) -> bool:
	return false


## Keeps `lit` the same length as `elements` (anything new starts unlit).
func _fix_lit() -> void:
	while lit.size() < elements.size():
		lit.append(false)
	if lit.size() > elements.size():
		lit.resize(elements.size())
	while parts.size() < elements.size():
		parts.append("")
	if parts.size() > elements.size():
		parts.resize(elements.size())


## Burn: add n to its Burn. Returns n.
func ignite(n: int, _rng: RandomNumberGenerator = null) -> int:
	if has_passive("burn_immune"):
		return 0  # fireproof (Cinder Hound)
	n = maxi(0, n)
	burn += n
	return n


## Start of the enemy's turn (before it acts): Burn takes its `burn` rightmost Essence (armour doesn't stop
## fire), then the Burn is used up.
func burn_off() -> Array:
	var removed := []
	for i in mini(burn, elements.size()):
		removed.push_front(_remove_at(elements.size() - 1))
	burn = 0
	return removed


func has_passive(p: String) -> bool:
	return p in def.get("passives", [])


# ------------------------------------------------------------------ removal (armour-aware)

func _remove_at(i: int) -> String:
	_fix_lit()
	var el: String = elements[i]
	elements.remove_at(i)
	armor.remove_at(i)
	lit.remove_at(i)
	parts.remove_at(i)
	return el


## The chant strike: the first k elements are matched; armoured ones stay.
func strike_prefix(k: int) -> Array:
	var removed := []
	var i := 0
	var seen := 0
	while seen < k and i < elements.size():
		if armor[i]:
			i += 1
		else:
			removed.append(_remove_at(i))
		seen += 1
	return removed


func remove_right(n: int) -> Array:
	var removed := []
	var i := elements.size() - 1
	while removed.size() < n and i >= 0:
		if not armor[i]:
			removed.append(_remove_at(i))
		i -= 1
	return removed


func remove_left(n: int) -> Array:
	var removed := []
	var i := 0
	while removed.size() < n and i < elements.size():
		if armor[i]:
			i += 1
		else:
			removed.append(_remove_at(i))
	return removed


## Remove one chosen element (not armoured ones). Returns what was removed.
func pluck(i: int) -> String:
	if i < 0 or i >= elements.size() or armor[i]:
		return ""
	return _remove_at(i)


## Annihilate: every element of this kind is removed, armoured or not.
func remove_all(el: String) -> Array:
	var removed := []
	for i in range(elements.size() - 1, -1, -1):
		if elements[i] == el:
			removed.push_front(_remove_at(i))
	return removed


func purge(el: String, n: int) -> Array:
	var removed := []
	var i := 0
	while removed.size() < n and i < elements.size():
		if elements[i] == el and not armor[i]:
			removed.append(_remove_at(i))
		else:
			i += 1
	return removed


# ------------------------------------------------------------------ reshaping

func rotate_left() -> void:
	if elements.size() > 1:
		_fix_lit()
		elements.append(elements.pop_front())
		armor.append(armor.pop_front())
		lit.append(lit.pop_front())
		parts.append(parts.pop_front())


func rotate_right() -> void:
	if elements.size() > 1:
		_fix_lit()
		elements.push_front(elements.pop_back())
		armor.push_front(armor.pop_back())
		lit.push_front(lit.pop_back())
		parts.push_front(parts.pop_back())


func swap_first_two() -> void:
	if elements.size() > 1:
		var e: String = elements[0]
		elements[0] = elements[1]
		elements[1] = e
		var a: bool = armor[0]
		armor[0] = armor[1]
		armor[1] = a
		_fix_lit()
		var l: bool = lit[0]
		lit[0] = lit[1]
		lit[1] = l
		var pt: String = parts[0]
		parts[0] = parts[1]
		parts[1] = pt


func convert(pos: String, to: String, from := "") -> void:
	match pos:
		"first":
			if not elements.is_empty():
				elements[0] = to
		"last":
			if not elements.is_empty():
				elements[-1] = to
		"first2":
			for i in mini(2, elements.size()):
				elements[i] = to
		"all":
			for i in elements.size():
				if from == "" or elements[i] == from:
					elements[i] = to


## Take the element at `from` and put it so it ends up at index `to` (armour moves with it).
func move_element(from: int, to: int) -> void:
	if from < 0 or from >= elements.size():
		return
	_fix_lit()
	var el: String = elements[from]
	var ar: bool = armor[from]
	var li: bool = lit[from]
	elements.remove_at(from)
	armor.remove_at(from)
	lit.remove_at(from)
	var pa: String = parts[from]
	parts.remove_at(from)
	to = clampi(to, 0, elements.size())
	elements.insert(to, el)
	armor.insert(to, ar)
	lit.insert(to, li)
	parts.insert(to, pa)


func insert_front(el: String) -> void:
	_fix_lit()
	elements.push_front(el)
	armor.push_front(false)
	lit.push_front(false)
	parts.push_front("")


## Mend / steal: add an element at the end (blocked by Cauterize for mending).
func append(el: String, is_mend := true) -> bool:
	if is_mend and no_mend:
		return false
	_fix_lit()
	elements.append(el)
	armor.append(false)
	lit.append(false)
	parts.append("")
	return true


func set_armor(i: int) -> void:
	if i >= 0 and i < armor.size():
		armor[i] = true


func shatter() -> void:
	armor.fill(false)




func damage_mult() -> float:
	var m := 1.0
	if weak_turns > 0:
		m *= 0.5
	if weak25:
		m *= 0.75
	return m


## Start of the enemy's turn (after Burn): armour from last turn fades, then Poison bites.
func begin_turn(_rng: RandomNumberGenerator = null) -> Dictionary:
	armor.fill(false)
	ethereal = false
	var out := {"burn": [], "poison": []}
	if poison > 0 and not is_dead():
		poison += 1  # Poison grows by 1 every turn (and kills once it reaches the Essence left)
		out.poison = ["+1"]
	return out


## (Old Poison: ate its `poison` rightmost Essence, then dropped by 1. Unused now.)
func poison_bite(_rng: RandomNumberGenerator = null) -> Array:
	var removed := []
	for i in mini(poison, elements.size()):
		removed.push_front(_remove_at(elements.size() - 1))
	poison = maxi(0, poison - 1)
	return removed


## After its action: timed statuses count down.
## Back from 0 Essence with a new row (the Invoker's second wind): statuses on it are gone too.
func reset_hp(hp: String) -> void:
	elements.clear()
	for c in hp:
		elements.append(c)
	armor.resize(elements.size())
	armor.fill(false)
	lit.clear()
	_fix_lit()
	burn = 0
	poison = 0
	freeze_turns = 0


func end_turn() -> void:
	disarmed = maxi(0, disarmed - 1)
	weak_turns = maxi(0, weak_turns - 1)
	freeze_turns = maxi(0, freeze_turns - 1)
	phased = false
	struck_this_turn = false


func describe_statuses() -> Array:
	var out := []
	if knocked:
		out.append(("Down: resurrected in %d turn%s" % [revive_in, "" if revive_in == 1 else "s"]) if revive_in > 0 else "Down: it gets up only when every other hand is down too")
	if disarmed > 0:
		out.append("Disarmed (its next attack does nothing)")
	if power > 0:
		out.append("Power %d (+%d damage per hit)" % [power, power])
	if burn > 0:
		out.append("Burn %d (loses its %d rightmost Essence at the start of its turn, then the Burn is gone)" % [burn, burn])
	if poison > 0:
		out.append("Poison %d (+1 every turn; it dies once Poison reaches the Essence it has left)" % poison)
	if weak_turns > 0:
		out.append("Weakened %d turn%s (deals 50%% less)" % [weak_turns, "" if weak_turns == 1 else "s"])
	if weak25:
		out.append("Stillness (deals 25% less)")
	if freeze_turns > 0:
		out.append("Frozen (skips its next action)")
	if no_mend:
		out.append("Cauterized (can't mend)")
	if ethereal:
		out.append("Ethereal (your chant can't touch it)")
	if phased:
		out.append("Phased (your spells remove double)")
	return out
