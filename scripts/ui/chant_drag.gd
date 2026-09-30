class_name ChantDrag
extends Control
## The chant while you place elements in it (Infuse, Rearrange). The elements you may move come alive: they
## shine and wiggle. Grab one and drag it; the others slide softly aside, with a little wobble, to open a gap
## where it will land. Keyboard: Tab picks another element, Left / Right move the gap, Enter drops.
## External mode (building a chant): the element was grabbed elsewhere (from your bag, or from the chant) and
## follows the mouse anywhere on screen; the fight screen asks external_result() when the button is let go.

## from = its index in `els`, to = where it lands (its index once the others close up). (-1, -1) = skipped.
signal dropped(from: int, to: int)

var els: Array = []  # element letters, in order
var live: Array = []  # per element: can it be grabbed
var slots := 8  # empty rings drawn after the elements, so the chant keeps its size
var px := 58.0
var sep := 6.0
## (to: int) -> bool. A drop the game doesn't allow (tutorial) floats back instead.
var allowed: Callable = func(_to: int) -> bool: return true
## Rearrange: dropping an element back where it was isn't a move, so the player can try again.
var same_spot_is_no_move := false

var _icons: Array = []
var _x: Array = []  # current x of each icon's slot
var _v: Array = []  # its speed, for the soft springy slide
var _held := -1
var _grab_dx := 0.0
var _mouse := Vector2.ZERO
var _gap := -1
var _keyboard := false
var _key_i := 0
var _t := 0.0
var external := false
var _pointer := Vector2.ZERO  # the mouse, in screen coordinates (fed by the fight screen as it moves)


func begin_external(held: int, pointer: Vector2) -> void:
	external = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_keyboard = false
	_held = held
	_grab_dx = px / 2.0
	_pointer = pointer
	_update_external()


func set_pointer(p: Vector2) -> void:
	_pointer = p


## inside: dropped over the chant (to = where it lands). Outside: let go away from the chant.
func external_result() -> Dictionary:
	return {"inside": _gap >= 0, "to": _gap}


func _update_external() -> void:
	_mouse = _pointer - global_position
	var zone := Rect2(Vector2(-px * 0.6, -px * 1.3), size + Vector2(px * 1.2, px * 2.6))
	if zone.has_point(_mouse):
		_gap = _gap_at(_mouse.x - _grab_dx)
	else:
		_gap = -1  # away from the chant: the others close up


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	var n := maxi(slots, els.size())
	custom_minimum_size = Vector2(n * (px + sep) - sep, px + 16)
	for i in els.size():
		var ic := ElementIcon.make(els[i], px)
		ic.size = Vector2(px, px)
		ic.pivot_offset = Vector2(px, px) / 2.0
		add_child(ic)
		_icons.append(ic)
		_x.append(_slot_x(i))
		_v.append(0.0)
	_key_i = live.find(true)
	_place_icons(0.0)


func _slot_x(i: int) -> float:
	return i * (px + sep)


## Where every icon should be right now: the held one follows the mouse, the rest close up around the gap.
func _targets() -> Array:
	var out := []
	out.resize(els.size())
	var k := 0
	for i in els.size():
		if i == _held:
			continue
		if k == _gap:
			k += 1
		out[i] = _slot_x(k)
		k += 1
	if _held >= 0:
		out[_held] = _slot_x(_gap) if _keyboard else clampf(_mouse.x - _grab_dx, -px * 0.3, _slot_x(els.size() - 1) + px * 0.3)
	return out


func _process(d: float) -> void:
	_t += d
	if external and _held >= 0:
		_update_external()
	_place_icons(d)
	queue_redraw()


func _place_icons(d: float) -> void:
	var target := _targets()
	for i in _icons.size():
		var ic: ElementIcon = _icons[i]
		if i == _held and not _keyboard:
			_x[i] = target[i]
			_v[i] = 0.0
		elif d > 0.0:
			# a soft spring: it glides to its spot, overshoots a touch and settles
			var a: float = 170.0 * (target[i] - _x[i]) - 15.0 * _v[i]
			_v[i] += a * d
			_x[i] += _v[i] * d
		var lift := -10.0 if i == _held else 0.0
		ic.position = Vector2(_x[i], 8.0 + lift)
		if external and i == _held:
			ic.position = _mouse - Vector2(px, px) / 2.0  # in your hand, wherever the mouse goes
			ic.modulate.a = 1.0 if _gap >= 0 else 0.65  # fainter away from the chant: letting go there takes it back
		var wig := 0.0
		var sc := 1.0
		if i == _held:
			sc = 1.18
			wig = sin(_t * 14.0) * 0.08
		elif live[i]:
			# alive: a gentle wiggle and a breathing size
			wig = sin(_t * 7.0 + i * 1.7) * 0.13
			sc = 1.0 + 0.05 * sin(_t * 5.0 + i)
		# the others lean a little in the direction they slide
		wig += clampf(_v[i] * 0.0012, -0.25, 0.25)
		ic.rotation = wig
		ic.scale = Vector2(sc, sc)
		ic.z_index = (50 if external else 1) if i == _held else 0  # the one in your hand passes over everything
		ic.highlight = live[i] and (i == _held or (_held < 0 and i == _key_i and _keyboard))


func _draw() -> void:
	# empty rings for the unused chant slots
	for s in range(els.size(), maxi(slots, els.size())):
		draw_arc(Vector2(_slot_x(s) + px / 2.0, 8.0 + px / 2.0), px / 2.0 - 2.0, 0, TAU, 32, Color(0.4, 0.5, 0.4, 0.8), 2.0)
	# a shining glow behind each element you may move
	for i in els.size():
		if not live[i]:
			continue
		var c: Vector2 = _icons[i].position + Vector2(px, px) / 2.0
		var pulse := 0.5 + 0.5 * sin(_t * 4.0 + i)
		var strength := 1.6 if i == _held else 1.0
		for k in 4:
			var r := px * (0.55 + 0.09 * k + 0.04 * pulse)
			draw_circle(c, r, Color(1.0, 0.88, 0.45, (0.10 - 0.02 * k) * strength))
		# a little sparkle orbiting it
		var sp := c + Vector2.from_angle(_t * 2.5 + i * 2.0) * px * 0.56
		draw_circle(sp, 2.5 + pulse, Color(1, 1, 0.85, 0.85))


func _index_at(p: Vector2) -> int:
	for i in els.size():
		if live[i] and Rect2(Vector2(_x[i], 8.0), Vector2(px, px)).grow(4.0).has_point(p):
			return i
	return -1


func _gap_at(x: float) -> int:
	return clampi(roundi(x / (px + sep)), 0, els.size() - 1)


func _gui_input(ev: InputEvent) -> void:
	if ev is InputEventMouseButton and ev.button_index == MOUSE_BUTTON_LEFT:
		if ev.pressed and _held < 0:
			var i := _index_at(ev.position)
			if i >= 0:
				_keyboard = false
				_held = i
				_grab_dx = ev.position.x - _x[i]
				_mouse = ev.position
				_gap = i
				Audio.play("elem_pickup")
				accept_event()
		elif not ev.pressed and _held >= 0 and not _keyboard:
			_drop()
			accept_event()
	elif ev is InputEventMouseMotion and _held >= 0 and not _keyboard:
		_mouse = ev.position
		var g := _gap_at(_mouse.x - _grab_dx)
		if g != _gap:
			_gap = g
			Audio.play("ui_tab_target", -8.0)
		accept_event()
	elif ev is InputEventMouseMotion:
		mouse_default_cursor_shape = Control.CURSOR_DRAG if _index_at(ev.position) >= 0 else Control.CURSOR_ARROW


func _drop() -> void:
	var from := _held
	var to := _gap
	if same_spot_is_no_move and to == from:
		_held = -1
		return
	if not allowed.call(to):
		_held = -1  # it floats back to where it was
		return
	# settle the order visually: the dropped element takes the gap
	var el: String = els[from]
	var ic = _icons[from]
	var x: float = _x[from]
	var lv: bool = live[from]
	for arr in [els, _icons, _x, _v, live]:
		arr.remove_at(from)
	els.insert(to, el)
	_icons.insert(to, ic)
	_x.insert(to, x)
	_v.insert(to, 0.0)
	live.insert(to, lv)
	_held = -1
	_gap = -1
	Audio.play("elem_remove")
	dropped.emit(from, to)


# ------------------------------------------------------------------ keyboard

## Tab: pick up another element you may move.
func key_cycle(dir := 1) -> void:
	if _held >= 0 and _keyboard:
		_held = -1
	var n := els.size()
	for k in n:
		_key_i = (_key_i + dir + n) % n
		if live[_key_i]:
			break
	_keyboard = true
	_held = _key_i
	_gap = _key_i


## Left / Right: slide the held element's landing spot.
func key_move(dir: int) -> void:
	if _held < 0:
		_keyboard = true
		_held = maxi(_key_i, 0)
		_gap = _held
	_gap = clampi(_gap + dir, 0, els.size() - 1)


## Enter: drop it where the gap is.
func key_drop() -> void:
	if _held < 0:
		key_move(0)
		return
	_drop()
