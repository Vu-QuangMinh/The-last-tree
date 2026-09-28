class_name EnemyState
extends RefCounted
## One enemy in a fight. HP is a row of elements (left to right); `armor[i]` marks elements
## that can't be removed this turn (they still count for matching).

var def: Dictionary
var id := ""
var name := ""
var elements: Array = []  # element letters
var armor: Array = []  # bool per element
var dmg_bonus := 0
var burn := 0
var poison := 0
var weak_turns := 0
var weak25 := false  # Stillness (permanent)
var freeze_turns := 0
var expose_turns := 0
var expose_perm := false  # Frailty
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
var expose_fresh := false  # applied this turn: it doesn't tick down until your next chant has had its chance
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
	is_boss = def.get("boss", false)
	is_elite = def.get("elite", false)


func size() -> int:
	return elements.size()


func is_dead() -> bool:
	return elements.is_empty()


func hp_text() -> String:
	return "".join(elements)


func has_passive(p: String) -> bool:
	return p in def.get("passives", [])


# ------------------------------------------------------------------ removal (armour-aware)

func _remove_at(i: int) -> String:
	var el: String = elements[i]
	elements.remove_at(i)
	armor.remove_at(i)
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
		elements.append(elements.pop_front())
		armor.append(armor.pop_front())


func rotate_right() -> void:
	if elements.size() > 1:
		elements.push_front(elements.pop_back())
		armor.push_front(armor.pop_back())


func swap_first_two() -> void:
	if elements.size() > 1:
		var e: String = elements[0]
		elements[0] = elements[1]
		elements[1] = e
		var a: bool = armor[0]
		armor[0] = armor[1]
		armor[1] = a


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
	var el: String = elements[from]
	var ar: bool = armor[from]
	elements.remove_at(from)
	armor.remove_at(from)
	to = clampi(to, 0, elements.size())
	elements.insert(to, el)
	armor.insert(to, ar)


func insert_front(el: String) -> void:
	elements.push_front(el)
	armor.push_front(false)


## Mend / steal: add an element at the end (blocked by Cauterize for mending).
func append(el: String, is_mend := true) -> bool:
	if is_mend and no_mend:
		return false
	elements.append(el)
	armor.append(false)
	return true


func set_armor(i: int) -> void:
	if i >= 0 and i < armor.size():
		armor[i] = true


func shatter() -> void:
	armor.fill(false)


func is_exposed() -> bool:
	return expose_perm or expose_turns > 0


func damage_mult() -> float:
	var m := 1.0
	if weak_turns > 0:
		m *= 0.5
	if weak25:
		m *= 0.75
	return m


## Start of the enemy's turn: armour from last turn fades, then Burn and Poison bite.
func begin_turn() -> Dictionary:
	armor.fill(false)
	ethereal = false
	var out := {"burn": [], "poison": []}
	if burn > 0:
		out.burn = remove_left(1)
		burn -= 1
	if poison > 0 and not is_dead():
		out.poison = remove_right(1)
		poison -= 1
	return out


## After its action: timed statuses count down.
func end_turn() -> void:
	weak_turns = maxi(0, weak_turns - 1)
	freeze_turns = maxi(0, freeze_turns - 1)
	phased = false
	struck_this_turn = false


func describe_statuses() -> Array:
	var out := []
	if burn > 0:
		out.append("Burn %d (loses its first element each turn)" % burn)
	if poison > 0:
		out.append("Poison %d (loses its last element each turn)" % poison)
	if weak_turns > 0:
		out.append("Weakened %d turn%s (deals 50%% less)" % [weak_turns, "" if weak_turns == 1 else "s"])
	if weak25:
		out.append("Stillness (deals 25% less)")
	if freeze_turns > 0:
		out.append("Frozen (skips its next action)")
	if is_exposed():
		out.append("Exposed (your chant takes 1 extra)")
	if no_mend:
		out.append("Cauterized (can't mend)")
	if ethereal:
		out.append("Ethereal (your chant can't touch it)")
	if phased:
		out.append("Phased (your spells remove double)")
	return out
