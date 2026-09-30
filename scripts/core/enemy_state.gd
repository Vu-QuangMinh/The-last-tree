class_name EnemyState
extends RefCounted
## One enemy in a fight. HP is a row of Essence (left to right); `armor[i]` marks Essence that can't be
## removed this turn (it still counts for matching).
## Burn N: at the start of its turn it loses its N leftmost Essence, then Burn drops by 1.
## Poison N: at the start of its turn it loses its N rightmost Essence, then Poison drops by 1.
## Both stay until they run down (the Release doesn't clear them). Fire and venom ignore armour.

var def: Dictionary
var id := ""
var name := ""
var elements: Array = []  # element letters
var armor: Array = []  # bool per element
var dmg_bonus := 0
var lit: Array = []  # (legacy, kept in step with elements; unused)
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
	lit.clear()
	_fix_lit()
	is_boss = def.get("boss", false)
	is_elite = def.get("elite", false)


func size() -> int:
	return elements.size()


func is_dead() -> bool:
	return elements.is_empty()


func hp_text() -> String:
	return "".join(elements)


## Will this Essence burn away at the start of its next turn? (The leftmost `burn` of them.)
func is_lit(i: int) -> bool:
	return i >= 0 and i < mini(burn, elements.size())


## Will this Essence be eaten by Poison at the start of its next turn? (The rightmost `poison` of them.)
func is_poisoned(i: int) -> bool:
	return i < elements.size() and i >= elements.size() - poison and i >= 0


## Keeps `lit` the same length as `elements` (anything new starts unlit).
func _fix_lit() -> void:
	while lit.size() < elements.size():
		lit.append(false)
	if lit.size() > elements.size():
		lit.resize(elements.size())


## Burn: add n to its Burn. Returns n.
func ignite(n: int, _rng: RandomNumberGenerator = null) -> int:
	n = maxi(0, n)
	burn += n
	return n


## Start of the enemy's turn (before it acts): Burn takes its `burn` leftmost Essence (armour doesn't stop
## fire), then Burn drops by 1.
func burn_off() -> Array:
	var removed := []
	for i in mini(burn, elements.size()):
		removed.append(_remove_at(0))
	burn = maxi(0, burn - 1)
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


func rotate_right() -> void:
	if elements.size() > 1:
		_fix_lit()
		elements.push_front(elements.pop_back())
		armor.push_front(armor.pop_back())
		lit.push_front(lit.pop_back())


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
	to = clampi(to, 0, elements.size())
	elements.insert(to, el)
	armor.insert(to, ar)
	lit.insert(to, li)


func insert_front(el: String) -> void:
	_fix_lit()
	elements.push_front(el)
	armor.push_front(false)
	lit.push_front(false)


## Mend / steal: add an element at the end (blocked by Cauterize for mending).
func append(el: String, is_mend := true) -> bool:
	if is_mend and no_mend:
		return false
	_fix_lit()
	elements.append(el)
	armor.append(false)
	lit.append(false)
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


## Start of the enemy's turn (after Burn): armour from last turn fades, then Poison bites.
func begin_turn(_rng: RandomNumberGenerator = null) -> Dictionary:
	armor.fill(false)
	ethereal = false
	var out := {"burn": [], "poison": []}
	if poison > 0 and not is_dead():
		out.poison = poison_bite()
	return out


## Poison: it loses its `poison` rightmost Essence (armour doesn't stop it), then Poison drops by 1.
func poison_bite(_rng: RandomNumberGenerator = null) -> Array:
	var removed := []
	for i in mini(poison, elements.size()):
		removed.push_front(_remove_at(elements.size() - 1))
	poison = maxi(0, poison - 1)
	return removed


## After its action: timed statuses count down.
func end_turn() -> void:
	weak_turns = maxi(0, weak_turns - 1)
	freeze_turns = maxi(0, freeze_turns - 1)
	phased = false
	struck_this_turn = false


func describe_statuses() -> Array:
	var out := []
	if burn > 0:
		out.append("Burn %d (loses its %d leftmost Essence at the start of its turn, then Burn drops by 1)" % [burn, burn])
	if poison > 0:
		out.append("Poison %d (loses its %d rightmost Essence at the start of its turn, then Poison drops by 1)" % [poison, poison])
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
