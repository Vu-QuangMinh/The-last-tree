class_name BottleSwapScreen
extends Control
## More bottles than slots (an event handed you some while you were full): your slots on top, what you found under
## them. Drag a bottle onto another place to swap the two (or onto an empty one to move it); the bottles glide to
## their spots on the same soft spring as the Essence of the chant. "Done": you keep what is in your slots, and what
## is left below stays behind.

signal done(kept: Array)

var slots := 3  # how many bottles you can carry
var mine: Array = []  # the bottles you had (ids)
var found: Array = []  # the ones that didn't fit
var act := 1
var on_stage := false

const PX := 96.0  # a bottle's square
const GAP := 34.0
const SNAP := 110.0  # how close to a place a bottle must be let go to land there
var _places: Array = []  # [Vector2 centre, ...]: the slots first, then the found ones
var _hold: Array = []  # per place: the bottle chip in it, or null
var _chips: Array = []  # every bottle: {chip, pos, vel}
var _held := -1  # index in _chips of the bottle in your hand
var _from := -1  # the place it was picked up from
var _mouse := Vector2.ZERO
var _t := 0.0
var _rings: Control  # (drawn over the shade, under the bottles)


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = UiTheme.get_theme()
	if not on_stage:
		var bd := Backdrop.new()
		bd.act = act
		add_child(bd)
	var shade := ColorRect.new()
	shade.color = Color(0, 0, 0, 0.42 if on_stage else 0.45)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shade)
	_rings = Control.new()
	_rings.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_rings.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rings.draw.connect(_draw_rings)
	add_child(_rings)
	var t := UiTheme.label("Too many bottles", 48, Color(0.8, 0.7, 1))
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	t.position = Vector2(0, 170)
	t.size = Vector2(1920, 60)
	add_child(t)
	var sub := UiTheme.label("Your bag only holds %d. Drag bottles in and out to choose which ones you keep." % slots, 22, UiTheme.TEXT)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.position = Vector2(0, 240)
	sub.size = Vector2(1920, 40)
	add_child(sub)
	_row_label("Your bottles", 380)
	_row_label("Left behind", 620)
	for i in slots:
		_places.append(_row_x(i, slots, 470))
	for i in found.size():
		_places.append(_row_x(i, found.size(), 710))
	_hold.resize(_places.size())
	_hold.fill(null)
	var all := mine.duplicate()
	while all.size() < slots:
		all.append("")
	for i in _places.size():
		var id: String = all[i] if i < slots else found[i - slots]
		if id == "":
			continue
		var chip := BottleChip.make(id, -1, false, PX)
		chip.size = Vector2(PX, PX)
		chip.pivot_offset = Vector2(PX, PX) / 2.0
		add_child(chip)
		_chips.append({"chip": chip, "pos": _places[i], "vel": Vector2.ZERO})
		_hold[i] = _chips.size() - 1
	var btn := UiTheme.button("Done", func(): done.emit(kept()), 22)
	btn.custom_minimum_size = Vector2(240, 56)
	btn.position = Vector2(960 - 120, 860)
	add_child(btn)


func _row_label(text: String, y: float) -> void:
	var l := UiTheme.label(text, 24, Color(0.95, 0.85, 0.6))
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.position = Vector2(0, y)
	l.size = Vector2(1920, 34)
	add_child(l)


## The centre of place i of a row of n, at height y.
func _row_x(i: int, n: int, y: float) -> Vector2:
	var w := n * PX + (n - 1) * GAP
	return Vector2(960.0 - w / 2.0 + PX / 2.0 + i * (PX + GAP), y + PX / 2.0)


## The bottles in your slots, in order.
func kept() -> Array:
	var out := []
	for i in slots:
		if _hold[i] != null:
			out.append(_chips[_hold[i]].chip.id)
	return out


func _input(ev: InputEvent) -> void:
	if ev is InputEventMouseMotion:
		_mouse = ev.position
	elif ev is InputEventMouseButton and ev.button_index == MOUSE_BUTTON_LEFT:
		_mouse = ev.position
		if ev.pressed and _held < 0:
			for i in _places.size():
				if _hold[i] != null and (_chips[_hold[i]].pos as Vector2).distance_to(_mouse) < PX * 0.55:
					_held = _hold[i]
					_from = i
					Audio.play("ui_click", -10.0, 1.2)
					get_viewport().set_input_as_handled()
					return
		elif not ev.pressed and _held >= 0:
			_drop()
			get_viewport().set_input_as_handled()


## Let go: on the nearest place within reach (swapping with what is there), else back where it came from.
func _drop() -> void:
	var best := -1
	var best_d := SNAP
	for i in _places.size():
		var d: float = (_places[i] as Vector2).distance_to(_mouse)
		if d < best_d:
			best_d = d
			best = i
	if best >= 0 and best != _from:
		var other = _hold[best]
		_hold[best] = _held
		_hold[_from] = other
		Audio.play("ui_click", -8.0, 0.9)
	_held = -1
	_from = -1


func _process(d: float) -> void:
	_t += d
	for i in _places.size():
		if _hold[i] == null:
			continue
		var k: int = _hold[i]
		var c: Dictionary = _chips[k]
		var target: Vector2 = _mouse if k == _held else _places[i]
		if k == _held:
			c.vel = Vector2.ZERO  # (in your hand: it goes where the mouse goes)
			c.pos = target
		elif d > 0.0:
			# the chant's soft spring: it glides to its spot, overshoots a touch and settles
			var a: Vector2 = 170.0 * (target - c.pos) - 15.0 * c.vel
			c.vel += a * d
			c.pos += c.vel * d
		var chip: BottleChip = c.chip
		var sc := 1.18 if k == _held else 1.0
		var wig := sin(_t * 14.0) * 0.08 if k == _held else sin(_t * 4.0 + k * 1.7) * 0.05
		wig += clampf(c.vel.x * 0.0012, -0.25, 0.25)  # (it leans the way it slides)
		chip.position = c.pos - Vector2(PX, PX) / 2.0
		chip.rotation = wig
		chip.scale = Vector2(sc, sc)
		chip.z_index = 50 if k == _held else 1



## A faint ring at every place, brighter where your slots are.
func _draw_rings() -> void:
	for i in _places.size():
		var col := Color(1, 0.85, 0.5, 0.35) if i < slots else Color(1, 1, 1, 0.15)
		_rings.draw_arc(_places[i], PX * 0.55, 0.0, TAU, 40, col, 2.0, true)
