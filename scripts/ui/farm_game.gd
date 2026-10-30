class_name FarmGame
extends Control
## The Farmer's Farm (an event): a shooting gallery in a row of wheat. Heads pop up out of the wheat and slowly sink
## back down within HEAD_TIME seconds; a click anywhere on a head shoots it. Goblins (red) and fairies (green) take
## one shot, a hobgoblin (a goblin twice the size, 1 in 10) takes three. Goblin +1 Leaf, hobgoblin +5, fairy -2.
## "Ready" is pressed on the page before: here a 3 s countdown, then GAME_TIME seconds (the clock on top blinks red
## in the last 5), then `finished` with how many of each you got. The pointer is the crosshair of the snipe spells.
## No art yet: everything here is drawn (placeholder shapes until the pictures exist).

signal finished(goblins: int, hobgoblins: int, fairies: int)

const GAME_TIME := 60.0
const COUNTDOWN := 3.0
const HEAD_TIME := 3.0  # a head is up and gone again within this
const POP := 0.18  # how fast it pops up (the rest of HEAD_TIME it sinks back, slowly)
const RATE_START := 1.0  # heads per second at the start ...
const RATE_END := 6.0  # ... and at the end
const FAIRY_START := 0.2  # of the heads, this many are fairies at the start ...
const FAIRY_END := 0.35  # ... and this many at the end
const HOB_SHARE := 0.1  # of the goblins, this many are hobgoblins
const SPOTS := 9
const FEET_Y := 607.0  # where the wheat stands when there is no stage to ask (the middle of the floor, like the enemies' feet)
const WHEAT_H := 210.0  # the wheat's height: a head fully down is hidden in it
var _feet := FEET_Y  # the bottom of the wheat: on the Puppet Stage, where the enemies' feet are
var _top := FEET_Y - WHEAT_H  # the top of the wheat
const HEAD_R := 42.0

var act := 1
var on_stage := false
var _t := -COUNTDOWN  # < 0: counting down; 0..GAME_TIME: playing; past it: over
var _spawn_acc := 0.0
var _heads: Array = []  # {kind: goblin / hobgoblin / fairy, spot, age, hp, hit_t, dead_t}
var _pops: Array = []  # floating "+1" / "-2": {at, text, col, age}
var _score := {"goblin": 0, "hobgoblin": 0, "fairy": 0}
var _cursor: AimCursor
var _last_tick := 99
var _rng := RandomNumberGenerator.new()
var _over := false
var _clock: Label
var _big: Label  # the countdown, and "Time's up!"
var _tally: Label


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = UiTheme.get_theme()
	mouse_filter = Control.MOUSE_FILTER_STOP
	_rng.randomize()
	var host := get_parent()
	if on_stage and host != null and host.has_method("get_stage") and host.get_stage() != null:
		_feet = host.get_stage().floor_center_y()  # (the wheat stands on the stage, where a fight's enemies stand)
	_top = _feet - WHEAT_H
	if not on_stage:
		var bd := Backdrop.new()
		bd.act = act
		bd.show_behind_parent = true  # (under the field, the heads and the wheat this screen draws itself)
		bd.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(bd)
	_clock = UiTheme.label("1:00", 56, Color.WHITE)
	_clock.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_clock.position = Vector2(0, 40)
	_clock.size = Vector2(1920, 70)
	add_child(_clock)
	_tally = UiTheme.label("", 26, Color(1, 0.9, 0.6))
	_tally.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_tally.position = Vector2(0, 112)
	_tally.size = Vector2(1920, 40)
	add_child(_tally)
	for l in [_clock, _tally]:  # (readable over the stage's red valance)
		l.add_theme_constant_override("outline_size", 10)
		l.add_theme_color_override("font_outline_color", Color(0.1, 0.05, 0.02))
	_big = UiTheme.label("3", 160, Color(1, 0.92, 0.6))
	_big.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_big.position = Vector2(0, 300)
	_big.size = Vector2(1920, 200)
	add_child(_big)
	_cursor = AimCursor.new()
	_cursor.mode = "shoot"
	add_child(_cursor)
	Input.mouse_mode = Input.MOUSE_MODE_HIDDEN
	Audio.play("ui_click", -4.0, 0.8)


func _exit_tree() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE  # (never leave the pointer hidden)


func _spot_x(i: int) -> float:
	return 300.0 + i * (1320.0 / (SPOTS - 1))


## Where a head's centre is now, and its radius.
func _head_at(h: Dictionary) -> Vector2:
	var a: float = h.age
	var up := 1.0
	if a < POP:
		up = a / POP
	else:
		up = 1.0 - pow((a - POP) / (HEAD_TIME - POP), 1.6)  # (slowly at first, then faster: back into the wheat)
	var r := _radius(h)
	var low := _top + 40.0 + r  # (fully down in the thick of the wheat)
	var high := _top - r * 0.9
	var x := _spot_x(h.spot)
	if h.hit_t > 0.0:
		x += sin(h.hit_t * 60.0) * 6.0 * h.hit_t / 0.25  # (it shakes when shot)
	return Vector2(x, lerpf(low, high, clampf(up, 0.0, 1.0)))


func _radius(h: Dictionary) -> float:
	return HEAD_R * (2.0 if h.kind == "hobgoblin" else 1.0)


func _process(d: float) -> void:
	if _over:
		return
	_t += d
	if _t < 0.0:
		var n := ceili(-_t)
		_big.text = str(n)
		if n != _last_tick:
			_last_tick = n
			Audio.play("ui_click", -2.0, 1.0)
	elif _t < GAME_TIME:
		if _big.text != "" and _t > 0.6:
			_big.text = ""
		elif _t < 0.6 and _big.text != "Go!":
			_big.text = "Go!"
			Audio.play("ui_click", 0.0, 1.5)
		var rate := lerpf(RATE_START, RATE_END, _t / GAME_TIME)
		_spawn_acc += rate * d
		while _spawn_acc >= 1.0:
			_spawn_acc -= 1.0
			_spawn()
		var left := ceili(GAME_TIME - _t)
		_clock.text = "%d:%02d" % [left / 60, left % 60]
		var hurry := left <= 5
		_clock.add_theme_color_override("font_color", Color(1, 0.2, 0.15) if hurry else Color.WHITE)
		_clock.modulate.a = (0.35 + 0.65 * absf(sin(_t * 6.0))) if hurry else 1.0
		if hurry and left != _last_tick:
			_last_tick = left
			Audio.play("sfx_burn_tick", 0.0, 1.3)
	else:
		_end()
		return
	for h in _heads:
		h.age += d
		h.hit_t = maxf(0.0, h.hit_t - d)
		if h.dead_t >= 0.0:
			h.dead_t += d
	_heads = _heads.filter(func(h): return h.age < HEAD_TIME and (h.dead_t < 0.0 or h.dead_t < 0.35))
	for p in _pops:
		p.age += d
	_pops = _pops.filter(func(p): return p.age < 0.9)
	_tally.text = "Goblins %d   ·   Hobgoblins %d   ·   Fairies %d" % [_score.goblin, _score.hobgoblin, _score.fairy] if _t >= 0.0 else ""
	queue_redraw()


func _spawn() -> void:
	var busy := {}
	for h in _heads:
		busy[h.spot] = true
	var free := []
	for i in SPOTS:
		if not busy.has(i):
			free.append(i)
	if free.is_empty():
		return
	var fairy_share := lerpf(FAIRY_START, FAIRY_END, clampf(_t / GAME_TIME, 0.0, 1.0))
	var kind := "fairy" if _rng.randf() < fairy_share else ("hobgoblin" if _rng.randf() < HOB_SHARE else "goblin")
	_heads.append({"kind": kind, "spot": free[_rng.randi() % free.size()], "age": 0.0, "hp": 3 if kind == "hobgoblin" else 1,
		"hit_t": 0.0, "dead_t": -1.0})


func _gui_input(ev: InputEvent) -> void:
	if not (ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT):
		return
	accept_event()
	if _t < 0.0 or _t >= GAME_TIME or _over:
		return
	Audio.play_gunshot(-6.0)
	_cursor.kick()
	# the head nearest the front (the latest to pop up) under the crosshair takes the shot
	for k in range(_heads.size() - 1, -1, -1):
		var h: Dictionary = _heads[k]
		if h.dead_t >= 0.0:
			continue
		var c := _head_at(h)
		if c.distance_to(ev.position) <= _radius(h):
			h.hp -= 1
			h.hit_t = 0.25
			if h.hp <= 0:
				h.dead_t = 0.0
				_score[h.kind] += 1
				var gain := {"goblin": "+1", "hobgoblin": "+5", "fairy": "-2"}[h.kind] as String
				_pops.append({"at": c, "text": gain, "col": Color(1, 0.4, 0.35) if h.kind == "fairy" else Color(1, 0.9, 0.35), "age": 0.0})
				Audio.play("sfx_damage_hit", -4.0, 1.4 if h.kind == "fairy" else 1.0)
			else:
				Audio.play("sfx_damage_hit", -8.0, 0.8)
			return


func _end() -> void:
	_over = true
	_clock.text = "0:00"
	_clock.modulate.a = 1.0
	_heads.clear()
	_big.text = "Time's up!"
	_big.add_theme_font_size_override("font_size", 110)
	Audio.play("ui_click", 0.0, 0.6)
	queue_redraw()
	await get_tree().create_timer(1.4).timeout
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	finished.emit(_score.goblin, _score.hobgoblin, _score.fairy)


# ------------------------------------------------------------------ drawing (placeholders until there is art)

func _draw() -> void:
	if not on_stage:
		draw_rect(Rect2(0, 0, 1920, 1080), Color(0, 0, 0, 0.3))  # (on the stage: nothing over it, like a fight)
	for h in _heads:
		_draw_head(h)
	_draw_wheat()  # (in front of the heads: they come up out of it)
	for p in _pops:
		var a: float = 1.0 - p.age / 0.9
		var f := get_theme_default_font()
		draw_string(f, p.at + Vector2(-30, -60 - 50.0 * p.age), p.text, HORIZONTAL_ALIGNMENT_CENTER, 60, 40, Color(p.col, a))


func _draw_wheat() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7  # (the same field every frame)
	var base := _feet
	# the thick of it first (it hides the heads that are down), then the stalks over it
	var body := PackedVector2Array()
	for k in 41:
		var x := 170.0 + k * (1580.0 / 40.0)
		body.append(Vector2(x, _top + 40.0 + 10.0 * sin(k * 1.9)))
	body.append(Vector2(1750, base))
	body.append(Vector2(170, base))
	draw_colored_polygon(body, Color(0.6, 0.46, 0.2))
	for k in 150:
		var x := 170.0 + k * (1580.0 / 149.0) + rng.randf_range(-4, 4)
		var top := _top + rng.randf_range(-6, 26)
		var sway := sin(Time.get_ticks_msec() / 700.0 + x * 0.02) * 4.0
		var stalk := Color(0.78, 0.62, 0.28).darkened(rng.randf_range(0.0, 0.25))
		draw_line(Vector2(x, base), Vector2(x + sway, top), stalk, 6.0, true)
		draw_line(Vector2(x + sway, top), Vector2(x + sway, top + 30.0), Color(0.95, 0.8, 0.4), 9.0, true)


func _draw_head(h: Dictionary) -> void:
	var c := _head_at(h)
	var r := _radius(h)
	var fade := 1.0
	if h.dead_t >= 0.0:
		fade = 1.0 - h.dead_t / 0.35
		r *= 1.0 + h.dead_t
	var flash: bool = h.hit_t > 0.15
	if h.kind == "fairy":
		var wing := Color(0.75, 1.0, 0.85, 0.7 * fade)
		var flap := 1.0 + 0.25 * sin(Time.get_ticks_msec() / 60.0)
		draw_colored_polygon(PackedVector2Array([c + Vector2(-r * 0.6, -r * 0.2), c + Vector2(-r * 1.7, -r * 1.1 * flap), c + Vector2(-r * 1.4, r * 0.4)]), wing)
		draw_colored_polygon(PackedVector2Array([c + Vector2(r * 0.6, -r * 0.2), c + Vector2(r * 1.7, -r * 1.1 * flap), c + Vector2(r * 1.4, r * 0.4)]), wing)
		var skin := Color.WHITE if flash else Color(0.45, 0.85, 0.4)
		draw_circle(c, r, Color(skin, fade))
		draw_circle(c + Vector2(-r * 0.35, -r * 0.1), r * 0.14, Color(0.1, 0.2, 0.1, fade))
		draw_circle(c + Vector2(r * 0.35, -r * 0.1), r * 0.14, Color(0.1, 0.2, 0.1, fade))
		draw_arc(c + Vector2(0, r * 0.2), r * 0.35, 0.3, PI - 0.3, 12, Color(0.1, 0.25, 0.1, fade), 3.0, true)
		return
	var hob: bool = h.kind == "hobgoblin"
	var skin := Color.WHITE if flash else (Color(0.62, 0.12, 0.1) if hob else Color(0.85, 0.22, 0.16))
	# ears, then horns
	draw_colored_polygon(PackedVector2Array([c + Vector2(-r * 0.8, -r * 0.1), c + Vector2(-r * 1.45, -r * 0.55), c + Vector2(-r * 0.85, r * 0.35)]), Color(skin, fade))
	draw_colored_polygon(PackedVector2Array([c + Vector2(r * 0.8, -r * 0.1), c + Vector2(r * 1.45, -r * 0.55), c + Vector2(r * 0.85, r * 0.35)]), Color(skin, fade))
	var horn := Color(0.95, 0.88, 0.7, fade)
	draw_colored_polygon(PackedVector2Array([c + Vector2(-r * 0.5, -r * 0.7), c + Vector2(-r * 0.75, -r * 1.35), c + Vector2(-r * 0.2, -r * 0.85)]), horn)
	draw_colored_polygon(PackedVector2Array([c + Vector2(r * 0.5, -r * 0.7), c + Vector2(r * 0.75, -r * 1.35), c + Vector2(r * 0.2, -r * 0.85)]), horn)
	draw_circle(c, r, Color(skin, fade))
	var eye := Color(1.0, 0.9, 0.2, fade)
	draw_circle(c + Vector2(-r * 0.35, -r * 0.15), r * 0.17, eye)
	draw_circle(c + Vector2(r * 0.35, -r * 0.15), r * 0.17, eye)
	draw_circle(c + Vector2(-r * 0.35, -r * 0.15), r * 0.07, Color(0, 0, 0, fade))
	draw_circle(c + Vector2(r * 0.35, -r * 0.15), r * 0.07, Color(0, 0, 0, fade))
	draw_arc(c + Vector2(0, r * 0.15), r * 0.45, 0.25, PI - 0.25, 14, Color(0.2, 0.0, 0.0, fade), 4.0 if hob else 3.0, true)
	if hob:
		for k in 3:  # (it shows how many shots it still takes: a pip per hit point)
			var on: bool = k < int(h.hp)
			draw_circle(c + Vector2((k - 1) * r * 0.35, -r * 1.25), 8.0, Color(1, 0.85, 0.3, fade) if on else Color(0.3, 0.2, 0.1, 0.6 * fade))
