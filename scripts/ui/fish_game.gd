class_name FishGame
extends Control
## Fisher's Fish (an Act 2 event): fish swim right to left across the top half of the stage, their Essence on
## their bodies. You line up a chant from three Essence that never run out (click one, or drag it down: a copy goes
## into the chant) and press Chant (or Enter / Space): every fish loses the longest start of its row that the chant
## contains, the fight's own rule (Chant.prefix_match). No turns: chant again at once. A fish with no Essence left is
## caught. 3 s countdown, then GAME_TIME seconds; `finished` with how many of each you caught. Fish that reach the
## left edge get away. No art yet: the fish are drawn (placeholders).

signal finished(big: int, medium: int, small: int)

const GAME_TIME := 60.0
const COUNTDOWN := 3.0
const SPAWN_EVERY := 6.0  # seconds between fish at the start (a little random) ...
const SPAWN_RAMP := 6.0  # ... and by the end, this many times as many fish (rising fast early on: see _process)
const CHANT_MAX := 10
const SPEED := 1.1  # every fish swims this much faster than its "cross" time says
## The size classes, by how many Essence orbs the fish carries (each fish rolls its count in "orbs"): small 3-5, medium 5-7, big 8 or more. The picture really is that size (w =
## the width of the picture, at most "max_h" tall), and the bigger, the slower ("cross": seconds to cross the stage) and the more Leaves.
const KINDS := {
	"small": {"orbs": [3, 5], "cross": 12.0, "leaves": 4, "w": 225.0, "max_h": 158.0, "col": Color(0.9, 0.6, 0.3), "share": 0.4},
	"medium": {"orbs": [5, 7], "cross": 16.0, "leaves": 6, "w": 375.0, "max_h": 158.0, "col": Color(0.4, 0.58, 0.85), "share": 0.4},
	"big": {"orbs": [8, 10], "cross": 24.0, "leaves": 10, "w": 570.0, "max_h": 202.0, "col": Color(0.3, 0.38, 0.55), "share": 0.2},
}
## The pictures (Events/event_fish_*.png) of each size class.
const ART := {
	"small": ["event_fish_clownfish", "event_fish_pufferfish", "event_fish_angelfish"],
	"medium": ["event_fish_swordfish", "event_fish_barracuda"],
	"big": ["event_fish_whale", "event_fish_shark"],
}
## Fish centres: the top half of the stage, under the clock and the tally. A lane can hold several fish, but a fish
## only comes in where it will never run into the one ahead of it (a fast one behind a slow one would catch it up).
const LANES := [250.0, 360.0, 470.0, 580.0]
const ORB := 46.0

var act := 1
var on_stage := false
var _t := -COUNTDOWN
var _spawn_in := 0.5
var _fish: Array = []  # {kind, lane, x, els: Array, icons: HBoxContainer, node: Control, dead_t}
var _pops: Array = []
var _score := {"big": 0, "medium": 0, "small": 0}
var _chant: Array = []
var _rng := RandomNumberGenerator.new()
var _over := false
var _last_tick := 99
var _clock: Label
var _tally: Label
var _big: Label
var _big_art: Control  # (the same words written in the wooden alphabet)
var _big_shown := ""
var _chant_row: HBoxContainer
var _tray: Array = []  # the three Essence you chant from: [{el, icon}]
var _drag_el := ""  # an Essence being dragged from the tray
var _drag_icon: ElementIcon
var _press_at := Vector2.ZERO


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = UiTheme.get_theme()
	mouse_filter = Control.MOUSE_FILTER_STOP
	_rng.randomize()
	if on_stage and get_parent() != null and get_parent().has_method("get_stage") and get_parent().get_stage() != null:
		get_parent().get_stage().set_underwater(true)  # (the sea: its own back wall, reefs, kelp and algae; the event's tally puts the stage back)
	if not on_stage:
		var bd := Backdrop.new()
		bd.act = act
		bd.show_behind_parent = true
		bd.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(bd)
	var bubbles := _Bubbles.new()  # (rising from the sea floor: the merchant's bubble pictures, as when he is drunk)
	bubbles.z_index = 49
	bubbles.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bubbles.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bubbles)
	_clock = _label("1:00", 56, Color.WHITE, Vector2(0, 40), Vector2(1920, 70))
	_tally = _label("", 26, Color(1, 0.9, 0.6), Vector2(0, 112), Vector2(1920, 40))
	for l in [_clock, _tally]:
		l.add_theme_constant_override("outline_size", 10)
		l.add_theme_color_override("font_outline_color", Color(0.1, 0.05, 0.02))
	_big = _label("3", 160, Color(1, 0.92, 0.6), Vector2(0, 300), Vector2(1920, 200))
	_big.add_theme_constant_override("outline_size", 14)
	_big.add_theme_color_override("font_outline_color", Color(0.1, 0.05, 0.02))
	# the chant: a row of empty rings, filled as you add Essence (click one to take it back out)
	var panel := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.1, 0.06, 0.04, 0.9)
	sb.border_color = Color(0.75, 0.58, 0.3)
	sb.set_border_width_all(3)
	sb.set_corner_radius_all(14)
	sb.set_content_margin_all(12)
	var board := UiSkin.frame("bubble_dark", 16, [16, 12, 16, 12])
	panel.add_theme_stylebox_override("panel", (board as StyleBox) if board != null else sb)
	panel.position = Vector2(560, 770)
	panel.custom_minimum_size = Vector2(800, 0)
	add_child(panel)
	_chant_row = HBoxContainer.new()
	_chant_row.add_theme_constant_override("separation", 8)
	_chant_row.custom_minimum_size = Vector2(0, ORB)
	panel.add_child(_chant_row)
	var go := UiTheme.button("Chant", _release, 24)
	go.custom_minimum_size = Vector2(180, 64)
	go.position = Vector2(1390, 770)
	go.focus_mode = Control.FOCUS_NONE
	add_child(go)
	var clear := UiTheme.button("Clear", func(): _chant.clear(); _show_chant(), 20)
	clear.custom_minimum_size = Vector2(120, 50)
	clear.position = Vector2(1590, 777)
	clear.focus_mode = Control.FOCUS_NONE
	add_child(clear)
	# the tray: Fire, Water, Air, never used up
	for k in 3:
		var el: String = ["F", "W", "A"][k]
		var ic := ElementIcon.make(el, 72.0)
		ic.position = Vector2(960 - 150 + k * 110 - 36, 890)
		ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(ic)
		_tray.append({"el": el, "icon": ic})
	_label("Click or drag Essence into the chant (F, W, A)  ·  Chant: Enter / Space  ·  Backspace: take one out", 20, Color(0.92, 0.88, 0.78), Vector2(0, 975), Vector2(1920, 30))
	_show_chant()
	Audio.play("ui_click", -4.0, 0.8)


func _label(text: String, px: int, col: Color, at: Vector2, sz: Vector2) -> Label:
	var l := UiTheme.label(text, px, col)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.position = at
	l.size = sz
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(l)
	return l


## The big words in the middle (3, 2, 1, Go, Time Up): in the wooden alphabet when the theme has it (it pops in, big to small), else the plain label with `plain` (default: `text`).
func _show_big(text: String, plain := "", cap := 200.0) -> void:
	_big_shown = text
	if is_instance_valid(_big_art):
		_big_art.queue_free()
	_big_art = null
	var art: Control = UiSkin.letters(text, cap) if text != "" else null
	_big.visible = art == null
	_big.text = (plain if plain != "" else text)
	_big.add_theme_font_size_override("font_size", 110 if cap < 200.0 else 160)
	if art == null:
		return
	art.position = Vector2((1920.0 - art.size.x) / 2.0, 300.0)
	art.pivot_offset = art.size / 2.0
	art.scale = Vector2(1.4, 1.4)
	art.z_index = 50  # (over the reef props of the sea)
	add_child(art)
	_big_art = art
	create_tween().tween_property(art, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _playing() -> bool:
	return _t >= 0.0 and _t < GAME_TIME and not _over


func _add(el: String) -> void:
	if not _playing() or _chant.size() >= CHANT_MAX:
		return
	_chant.append(el)
	Audio.play("ui_click", -8.0, 1.2)
	_show_chant()


func _show_chant() -> void:
	for f in _fish:
		_light(f)
	for c in _chant_row.get_children():
		c.queue_free()
	for i in CHANT_MAX:
		if i < _chant.size():
			var ic := ElementIcon.make(_chant[i], ORB)
			ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
			_chant_row.add_child(ic)
		else:
			var ring := Panel.new()
			ring.custom_minimum_size = Vector2(ORB, ORB)
			var rs := StyleBoxFlat.new()
			rs.bg_color = Color(0, 0, 0, 0.25)
			rs.border_color = Color(0.6, 0.48, 0.3, 0.7)
			rs.set_border_width_all(2)
			rs.set_corner_radius_all(int(ORB / 2.0))
			var socket := UiSkin.box("frame_round_socket")
			ring.add_theme_stylebox_override("panel", (socket as StyleBox) if socket != null else rs)
			ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
			_chant_row.add_child(ring)


## Chant: every fish loses the longest start of its row the chant contains; then the chant is empty again at once.
func _release() -> void:
	if not _playing() or _chant.is_empty():
		return
	var c := "".join(_chant)
	var any := false
	var killed := ""  # (the biggest kind of fish speared by this chant: its own sound)
	for f in _fish:
		if f.dead_t >= 0.0:
			continue
		var k := Chant.prefix_match(f.els, c)
		if k > 0:
			any = true
			f.els = f.els.slice(k)
			if f.els.is_empty():
				f.dead_t = 0.0
				if killed != "big" and (killed == "" or f.kind == "big" or (f.kind == "medium" and killed == "small")):
					killed = f.kind
				_score[f.kind] += 1
				_pops.append({"at": Vector2(f.x, LANES[f.lane] - 40.0), "text": "+%d" % int(KINDS[f.kind].leaves), "age": 0.0})
			_show_els(f)
	if killed != "":
		Audio.play("fish_spear_" + killed, -2.0)
	else:
		Audio.play("sfx_damage_hit" if any else "ui_click", -4.0, 1.0)
	_chant.clear()
	_show_chant()


func _spawn() -> void:
	var r := _rng.randf()
	var kind := "big"
	for k in KINDS:
		r -= float(KINDS[k].share)
		if r < 0.0:
			kind = k
			break
	var lanes := []
	var art_name := ""
	var w := 0.0
	var tries: Array = [kind]  # (that size first; no room for it: any other size that fits somewhere?)
	tries.append_array(KINDS.keys().filter(func(o): return o != kind))
	for cand: String in tries:
		var roll := _roll(cand)
		var room := range(LANES.size()).filter(func(l): return _fits(cand, float(roll.w), l))
		if not room.is_empty():
			kind = cand
			art_name = String(roll.art)
			w = float(roll.w)
			lanes = room
			break
	if lanes.is_empty():
		_spawn_in = 0.5  # (nowhere to put a fish: try again in a moment)
		return
	var lane: int = lanes[_rng.randi() % lanes.size()]
	var orbs: Array = KINDS[kind].orbs
	var els := []
	for i in _rng.randi_range(int(orbs[0]), int(orbs[1])):
		els.append(["F", "W", "A"][_rng.randi() % 3])
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 2)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(row)
	var f := {"kind": kind, "lane": lane, "art": art_name, "w": w, "x": 1920.0 + w / 2.0, "els": els, "icons": row, "dead_t": -1.0}
	_fish.append(f)
	_show_els(f)


## A fish of this size class: which picture it is and how wide, the class's width unless the picture would be taller than the class allows.
func _roll(kind: String) -> Dictionary:
	var k: Dictionary = KINDS[kind]
	var names: Array = ART[kind]
	var art: String = names[_rng.randi() % names.size()]
	var pic: Texture2D = UiSkin.tex(art)
	var w: float = k.w
	if pic != null:
		w = minf(w, float(k.max_h) * pic.get_width() / float(pic.get_height()))
	return {"art": art, "w": w}


## Can a fish of this size (and width) come in on this lane now without ever touching one already in it? It must start behind
## the last one, and if it swims faster, still be behind it when that one leaves the stage.
func _fits(kind: String, w: float, lane: int) -> bool:
	var k: Dictionary = KINDS[kind]
	var v: float = (1920.0 + w) / float(k.cross) * SPEED
	var tail := 1920.0  # where the new fish's nose starts (off the right edge; its body is still hidden)
	const GAP := 40.0
	for f in _fish:
		if f.lane != lane:
			continue
		var o: Dictionary = KINDS[f.kind]
		var ow: float = f.w
		var ov: float = (1920.0 + ow) / float(o.cross) * SPEED
		var o_back: float = f.x + ow * 0.62  # (the back of its tail)
		if tail < o_back + GAP:
			return false  # (not past it yet)
		if v > ov:
			var t_out: float = (o_back + ow) / ov  # (when it has swum off the left edge)
			if tail - v * t_out < o_back - ov * t_out + GAP:
				return false  # (faster: it would catch it up)
	return true


func _show_els(f: Dictionary) -> void:
	var row: HBoxContainer = f.icons
	for c in row.get_children():
		c.queue_free()
	for el in f.els:
		var ic := ElementIcon.make(el, 39.0)
		ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(ic)
	_light(f)


## The Essence of a fish your chant would take now are marked, like an enemy's in a fight (the chant preview).
func _light(f: Dictionary) -> void:
	var k := Chant.prefix_match(f.els, "".join(_chant)) if not _chant.is_empty() else 0
	var row: HBoxContainer = f.icons
	var i := 0
	for ic in row.get_children():
		if ic.is_queued_for_deletion():
			continue
		(ic as ElementIcon).ghost = i < k
		(ic as ElementIcon).queue_redraw()
		i += 1


func _process(d: float) -> void:
	queue_redraw()
	if _over:
		return
	_t += d
	if _t < 0.0:
		var n := ceili(-_t)
		if n != _last_tick:
			_last_tick = n
			_show_big(str(n))
			Audio.play("fish_count", -2.0, 1.0)
	elif _t < GAME_TIME:
		if _t < 0.6:
			if _big_shown != "Go":
				_show_big("Go", "Go!")
				Audio.play("fish_go", 0.0)
		elif _big_shown != "":
			_show_big("")
		_spawn_in -= d
		var alive := _fish.filter(func(f): return f.dead_t < 0.0)
		if alive.is_empty():  # (nothing swims on the screen: the next fish comes out at once)
			_spawn_in = 0.0
		if _spawn_in <= 0.0:
			_spawn_in = SPAWN_EVERY / lerpf(1.0, SPAWN_RAMP, pow(clampf(_t / GAME_TIME, 0.0, 1.0), 0.8)) * _rng.randf_range(0.7, 1.3)  # (more and more fish: the last 10 s twice as many as a straight 1x-to-3x rise)
			_spawn()
		var left := ceili(GAME_TIME - _t)
		_clock.text = "%d:%02d" % [left / 60, left % 60]
		var hurry := left <= 5
		_clock.add_theme_color_override("font_color", Color(1, 0.2, 0.15) if hurry else Color.WHITE)
		_clock.modulate.a = (0.35 + 0.65 * absf(sin(_t * 6.0))) if hurry else 1.0
		if hurry and left != _last_tick:
			_last_tick = left
			Audio.play("fish_timer_tick", 0.0)
	else:
		_end()
		return
	for f in _fish:
		var k: Dictionary = KINDS[f.kind]
		f.x -= (1920.0 + float(f.w)) / float(k.cross) * SPEED * d
		if f.dead_t >= 0.0:
			f.dead_t += d
		var row: HBoxContainer = f.icons
		row.position = Vector2(f.x - row.size.x / 2.0, LANES[f.lane] - 13.0)
		row.modulate.a = 1.0 if f.dead_t < 0.0 else 0.0
	var gone := _fish.filter(func(f): return f.x < -float(f.w) or f.dead_t > 0.5)
	for f in gone:
		(f.icons as Node).queue_free()
	_fish = _fish.filter(func(f): return not (f in gone))
	for p in _pops:
		p.age += d
	_pops = _pops.filter(func(p): return p.age < 0.9)
	_tally.text = "Big %d   ·   Medium %d   ·   Small %d" % [_score.big, _score.medium, _score.small] if _t >= 0.0 else ""
	if is_instance_valid(_drag_icon):
		_drag_icon.position = get_local_mouse_position() - Vector2(ORB, ORB) / 2.0
	queue_redraw()


func _gui_input(ev: InputEvent) -> void:
	if ev is InputEventMouseButton and ev.button_index == MOUSE_BUTTON_LEFT:
		if ev.pressed:
			_press_at = ev.position
			for t in _tray:
				var ic: ElementIcon = t.icon
				if Rect2(ic.position, ic.size).grow(6.0).has_point(ev.position):
					_drag_el = t.el
					_drag_icon = ElementIcon.make(t.el, ORB)
					_drag_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
					_drag_icon.z_index = 20
					add_child(_drag_icon)
					accept_event()
					return
			# a click on an Essence in the chant takes it back out
			for i in _chant_row.get_child_count():
				var c: Control = _chant_row.get_child(i)
				if i < _chant.size() and c.get_global_rect().has_point(get_global_mouse_position()):
					_chant.remove_at(i)
					_show_chant()
					accept_event()
					return
		elif _drag_el != "":
			# a click (no real drag) or a drop: either way a copy goes into the chant
			_add(_drag_el)
			_drag_el = ""
			if is_instance_valid(_drag_icon):
				_drag_icon.queue_free()
			accept_event()


func _unhandled_key_input(ev: InputEvent) -> void:
	if not (ev is InputEventKey and ev.pressed and not ev.echo):
		return
	match ev.keycode:
		KEY_F:
			_add("F")
		KEY_W:
			_add("W")
		KEY_A:
			_add("A")
		KEY_BACKSPACE:
			if not _chant.is_empty():
				_chant.pop_back()
				_show_chant()
		KEY_ENTER, KEY_KP_ENTER, KEY_SPACE:
			_release()
		_:
			return
	get_viewport().set_input_as_handled()


func _end() -> void:
	_over = true
	_clock.text = "0:00"
	_clock.modulate.a = 1.0
	for f in _fish:
		(f.icons as Node).queue_free()
	_fish.clear()
	_show_big("Time Up", "Time's up!", 130.0)
	Audio.play("ui_click", 0.0, 0.6)
	queue_redraw()
	await get_tree().create_timer(1.4).timeout
	finished.emit(_score.big, _score.medium, _score.small)


# ------------------------------------------------------------------ drawing (placeholders until there is art)

func _draw() -> void:
	if not on_stage:
		draw_rect(Rect2(0, 0, 1920, 1080), Color(0, 0, 0, 0.3))
	for f in _fish:
		_draw_fish(f)
	var font := get_theme_default_font()
	for p in _pops:
		var a: float = 1.0 - p.age / 0.9
		draw_string(font, p.at + Vector2(-30, -50.0 * p.age), p.text, HORIZONTAL_ALIGNMENT_CENTER, 60, 40, Color(1, 0.9, 0.35, a))


func _draw_fish(f: Dictionary) -> void:
	var k: Dictionary = KINDS[f.kind]
	var c := Vector2(f.x, LANES[f.lane])
	var pic: Texture2D = UiSkin.tex(String(f.get("art", "")))
	if pic != null:  # (the carved fish, a little wriggle as it swims)
		var pw: float = f.w
		var ph := pw * pic.get_height() / float(pic.get_width())
		var pfade := 1.0 if f.dead_t < 0.0 else maxf(0.0, 1.0 - f.dead_t / 0.5)
		draw_set_transform(c, sin(Time.get_ticks_msec() / 220.0 + f.x * 0.01) * 0.04, Vector2.ONE)
		draw_texture_rect(pic, Rect2(Vector2(-pw / 2.0, -ph / 2.0), Vector2(pw, ph)), false, Color(1, 1, 1, pfade))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		return
	var w: float = f.w
	var h: float = w * 0.35
	var fade := 1.0 if f.dead_t < 0.0 else maxf(0.0, 1.0 - f.dead_t / 0.5)
	var col := Color(k.col, fade)
	var wig := sin(Time.get_ticks_msec() / 150.0 + f.x * 0.01) * h * 0.12
	# tail (on the right: they swim left), body, eye
	draw_colored_polygon(PackedVector2Array([c + Vector2(w * 0.42, 0), c + Vector2(w * 0.62, -h * 0.55 + wig), c + Vector2(w * 0.62, h * 0.55 + wig)]), col.darkened(0.15))
	var body := PackedVector2Array()
	for i in 24:
		var a := TAU * i / 24.0
		body.append(c + Vector2(cos(a) * w * 0.46, sin(a) * h * 0.5))
	draw_colored_polygon(body, col)
	draw_circle(c + Vector2(-w * 0.3, -h * 0.15), h * 0.09, Color(1, 1, 1, fade))
	draw_circle(c + Vector2(-w * 0.31, -h * 0.15), h * 0.045, Color(0, 0, 0, fade))


## Bubbles float up through the water: one every so often from a random spot of the sea floor, each on a wobbling path of its own, a little bigger as it rises, fading out
## near the top. The pictures are the drunk merchant's (ShopScreen's bubble (1..4).png).
class _Bubbles extends Control:
	const FILES := ["bubble (1).png", "bubble (2).png", "bubble (3).png", "bubble (4).png"]
	const DIR := "res://assets/Puppet/UI/Characters/Merchant/"
	const EVERY := Vector2(0.12, 0.4)
	const SIZE := Vector2(12.0, 44.0)
	const LIFE := Vector2(3.5, 6.5)
	const RISE := Vector2(60.0, 140.0)
	var _tex: Array[Texture2D] = []
	var _list: Array = []
	var _next := 0.0

	func _ready() -> void:
		for f in FILES:
			if ResourceLoader.exists(DIR + f):
				_tex.append(load(DIR + f))
		for k in 14:  # (the sea is already bubbling when it comes in)
			_spawn(randf_range(0.0, 3.0))

	func _process(d: float) -> void:
		if _tex.is_empty():
			return
		_next -= d
		if _next <= 0.0:
			_next = randf_range(EVERY.x, EVERY.y)
			_spawn(0.0)
		for b in _list:
			b.t += d
		_list = _list.filter(func(b): return b.t < b.life)
		queue_redraw()

	func _spawn(age: float) -> void:
		if _tex.is_empty():
			return
		_list.append({
			"tex": _tex[randi() % _tex.size()],
			"from": Vector2(randf_range(40.0, 1880.0), randf_range(620.0, 860.0)),
			"size": randf_range(SIZE.x, SIZE.y),
			"vx": randf_range(-14.0, 14.0),
			"vy": -randf_range(RISE.x, RISE.y),
			"wob": randf_range(4.0, 14.0),
			"freq": randf_range(1.2, 3.0),
			"ph": randf() * TAU,
			"life": randf_range(LIFE.x, LIFE.y),
			"t": age,
		})

	func _draw() -> void:
		for b in _list:
			var u: float = b.t / b.life
			var pos: Vector2 = b.from + Vector2(b.vx * b.t + sin(b.t * b.freq + b.ph) * b.wob, b.vy * b.t)
			var alpha := minf(1.0, b.t / 0.4) * pow(1.0 - u, 0.8) * 0.85
			var sz: float = b.size * (0.85 + 0.3 * u)
			draw_texture_rect(b.tex, Rect2(pos - Vector2(sz, sz) * 0.5, Vector2(sz, sz)), false, Color(1, 1, 1, alpha))
