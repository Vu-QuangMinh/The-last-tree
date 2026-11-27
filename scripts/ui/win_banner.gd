class_name WinBanner
extends Control
## "You won a card!", "You won a Marble!", "And also a Ticket!" (the user, 2026-11-27): big words over a dimmed screen,
## a shining light spinning slowly behind them (soft rays and a glow). A click, or a moment, and it goes:
## `finished`. Use: `await WinBanner.play(parent, "You won a card!")`.

signal finished

const HOLD := 1.6  # seconds before it goes by itself

var text := ""
var col := Color(1.0, 0.9, 0.55)
var pic: Control  # (optional: shown big over the words, popping in: a carved marble, a ticket)
var _spin := 0.0
var _t := 0.0
var _done := false


static func play(parent: Node, words: String, colour := Color(1.0, 0.9, 0.55), p_pic: Control = null) -> void:
	var b := WinBanner.new()
	b.text = words
	b.col = colour
	b.pic = p_pic
	parent.add_child(b)
	await b.finished


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	size = Vector2(1920, 1080)
	mouse_filter = Control.MOUSE_FILTER_STOP
	z_index = 50
	theme = UiTheme.get_theme()
	var l := UiTheme.heading(text, 76, col)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.add_theme_constant_override("outline_size", 14)
	l.add_theme_color_override("font_outline_color", Color(0.25, 0.08, 0.02))
	l.size = Vector2(1920, 200)
	l.position = Vector2(0, 440 if pic == null else 600)
	if pic != null:
		pic.position = Vector2(960, 440) - pic.size / 2.0
		pic.pivot_offset = pic.size / 2.0
		pic.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(pic)
		pic.scale = Vector2(0.2, 0.2)
		pic.create_tween().tween_property(pic, "scale", Vector2.ONE, 0.45).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
		var fx := Vfx.make(self, 5)
		fx.glow(Vector2(960, 440), 260.0, Color(col, 0.9), 0.5)
		fx.glow(Vector2(960, 440), 90.0, Color(1, 1, 1, 0.95), 0.15)
		fx.ring(Vector2(960, 440), 20.0, 260.0, col, 0.45, 10.0)
		fx.burst(Vector2(960, 440), 30, col.lerp(Color.WHITE, 0.4), Vector2(200, 560), Vector2(0.4, 0.8), Vector2(4, 9))
	l.pivot_offset = l.size / 2.0
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(l)
	l.scale = Vector2(0.4, 0.4)
	l.modulate.a = 0.0
	var tw := l.create_tween().set_parallel()
	tw.tween_property(l, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(l, "modulate:a", 1.0, 0.2)
	Audio.play("spell_glow", -2.0)
	get_tree().create_timer(HOLD).timeout.connect(_end)


func _process(dt: float) -> void:
	_t += dt
	_spin += dt * 0.35
	queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, Vector2(1920, 1080)), Color(0, 0, 0, minf(0.72, _t * 3.0)))
	var c := Vector2(960, 540 if pic == null else 440)
	var grow := minf(1.0, _t * 3.0)
	var r := 760.0 * grow
	# the rays: soft wedges of light, turning slowly, brighter near the middle (a few rings of wedges, fading out)
	var rays := 18
	for ring in 4:
		var rr := r * (0.35 + ring * 0.22)
		var a_col := Color(1.0, 0.92, 0.6, 0.11 * (1.0 - ring * 0.2))
		for k in rays:
			var a0 := _spin + TAU * k / rays
			var a1 := a0 + TAU / rays * 0.45
			draw_colored_polygon(PackedVector2Array([c, c + Vector2.from_angle(a0) * rr, c + Vector2.from_angle(a1) * rr]), a_col)
	# the glow behind the words, gently pulsing
	var pulse := 1.0 + 0.06 * sin(_t * 4.0)
	for k in 6:
		draw_circle(c, (260.0 - k * 38.0) * grow * pulse, Color(1.0, 0.85, 0.45, 0.07))
	# sparkles drifting round it
	for k in 12:
		var a := -_spin * 1.6 + TAU * k / 12.0
		var p := c + Vector2.from_angle(a) * (330.0 + 30.0 * sin(_t * 2.0 + k)) * grow
		var s := 4.0 + 3.0 * sin(_t * 6.0 + k * 1.7)
		draw_circle(p, maxf(1.0, s), Color(1.0, 0.97, 0.8, 0.8))


func _gui_input(ev: InputEvent) -> void:
	if ev is InputEventMouseButton and ev.pressed and _t > 0.3:
		_end()
		accept_event()


func _end() -> void:
	if _done or not is_inside_tree():
		return
	_done = true
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 0.0, 0.2)
	await tw.finished
	finished.emit()
	queue_free()
