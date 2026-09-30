class_name CardDrag
extends Control
## Before a fight: press and hold a spell in your active row and drag it to change the order. The card you hold
## tilts and wobbles in your hand; the others glide aside on a soft spring (overshooting a touch, leaning the way
## they slide), the same feel as moving elements in the chant. The screen feeds the pointer in and asks
## finish() when the button is let go.

var cards: Array = []  # SpellCard copies, in the row's order
var slots: Array = []  # top-left of each slot, local to this control
var _p: Array = []  # where each card is now
var _v: Array = []  # how fast it's moving (the spring)
var _held := -1
var _grab := Vector2.ZERO  # where on the held card the pointer took hold
var _pointer := Vector2.ZERO
var _gap := -1
var _t := 0.0


## spells: the active row's spells; slot_pos: each card's current top-left on screen; held: the one picked up.
func begin(spells: Array, slot_pos: Array, held: int, pointer: Vector2) -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	for i in spells.size():
		var c := SpellCard.make(spells[i])
		c.is_zoom_copy = true  # just a picture of the card: it never takes the mouse
		c.selected = true
		c.mouse_filter = Control.MOUSE_FILTER_IGNORE
		c.size = Vector2(SpellCard.W, SpellCard.H)
		c.pivot_offset = c.size / 2.0
		add_child(c)
		cards.append(c)
		var at: Vector2 = slot_pos[i] - global_position
		slots.append(at)
		_p.append(at)
		_v.append(Vector2.ZERO)
	_held = held
	_gap = held
	_pointer = pointer
	_grab = pointer - (slot_pos[held] as Vector2)
	Audio.play("elem_pickup")


func set_pointer(p: Vector2) -> void:
	_pointer = p
	var g := _nearest_slot(p - global_position - _grab + Vector2(SpellCard.W, SpellCard.H) / 2.0)
	if g != _gap:
		_gap = g
		Audio.play("ui_tab_target", -8.0)


## [from, to]: the held card's old place and where it lands.
func finish() -> Array:
	Audio.play("elem_remove")
	return [_held, _gap]


func _nearest_slot(center: Vector2) -> int:
	var best := 0
	var best_d := INF
	for i in slots.size():
		var d := center.distance_squared_to((slots[i] as Vector2) + Vector2(SpellCard.W, SpellCard.H) / 2.0)
		if d < best_d:
			best_d = d
			best = i
	return best


func _targets() -> Array:
	var out := []
	out.resize(cards.size())
	var k := 0
	for i in cards.size():
		if i == _held:
			continue
		if k == _gap:
			k += 1
		out[i] = slots[mini(k, slots.size() - 1)]
		k += 1
	out[_held] = _pointer - global_position - _grab
	return out


func _process(d: float) -> void:
	_t += d
	var tg := _targets()
	for i in cards.size():
		var c: SpellCard = cards[i]
		if i == _held:
			var before: Vector2 = _p[i]
			_p[i] = tg[i]
			_v[i] = ((_p[i] as Vector2) - before) / maxf(d, 0.001)
		else:
			# the soft spring: it glides to its spot, overshoots a touch and settles
			var a: Vector2 = 170.0 * ((tg[i] as Vector2) - (_p[i] as Vector2)) - 15.0 * (_v[i] as Vector2)
			_v[i] += a * d
			_p[i] += (_v[i] as Vector2) * d
		c.position = _p[i]
		var vx: float = (_v[i] as Vector2).x
		if i == _held:
			c.z_index = 10
			c.scale = Vector2.ONE * 1.08
			c.rotation = clampf(vx * 0.00035, -0.3, 0.3) + sin(_t * 14.0) * 0.03
			c.modulate = Color(1.12, 1.1, 1.0)
		else:
			c.z_index = 0
			c.scale = Vector2.ONE * (1.0 + 0.015 * sin(_t * 5.0 + i))
			# a gentle wiggle, and a lean in the direction it slides
			c.rotation = sin(_t * 7.0 + i * 1.7) * 0.025 + clampf(vx * 0.0006, -0.2, 0.2)
