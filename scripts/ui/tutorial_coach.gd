class_name TutorialCoach
extends Control
## The tutorial's guide layer, mobile-game style: the screen dims except for a spotlight on what matters,
## a hand points at it, and Sprout explains in a speech bubble. In "tap" steps a tap anywhere continues;
## otherwise clicks pass through to the game (the tutorial's gate decides which actions are allowed).

signal tapped

var focus := Callable()  # func() -> Rect2 (global); an empty rect means no spotlight
var tap_mode := true
var _t := 0.0
var _bubble: PanelContainer
var _text: RichTextLabel
var _hint: Label
var _hand: Label
var _step_label: Label


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	z_index = 90
	theme = UiTheme.get_theme()
	_bubble = PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.97, 0.93, 0.8)
	sb.border_color = Color(0.35, 0.6, 0.25)
	sb.set_border_width_all(4)
	sb.set_corner_radius_all(18)
	sb.content_margin_left = 20
	sb.content_margin_right = 20
	sb.content_margin_top = 14
	sb.content_margin_bottom = 12
	sb.shadow_color = Color(0, 0, 0, 0.5)
	sb.shadow_size = 10
	_bubble.add_theme_stylebox_override("panel", sb)
	_bubble.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_bubble)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 14)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bubble.add_child(h)
	var face := UiTheme.label("🌱", 54, Color.WHITE)
	face.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(face)
	var v := VBoxContainer.new()
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(v)
	var name_row := HBoxContainer.new()
	name_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(name_row)
	var who := UiTheme.label("Sprout", 20, Color(0.25, 0.5, 0.15))
	who.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_row.add_child(who)
	_step_label = UiTheme.label("", 14, Color(0.45, 0.4, 0.3))
	name_row.add_child(_step_label)
	_text = RichTextLabel.new()
	_text.bbcode_enabled = true
	_text.fit_content = true
	_text.scroll_active = false
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text.custom_minimum_size = Vector2(620, 0)
	_text.add_theme_font_size_override("normal_font_size", 21)
	_text.add_theme_font_size_override("bold_font_size", 21)
	_text.add_theme_color_override("default_color", Color(0.12, 0.1, 0.07))
	_text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(_text)
	_hint = UiTheme.label("", 15, Color(0.35, 0.55, 0.2))
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(_hint)
	_hand = UiTheme.label("👆", 56, Color.WHITE)
	_hand.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hand.add_theme_constant_override("outline_size", 6)
	_hand.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.6))
	add_child(_hand)


## Show one step. text: plain words (keywords get coloured). p_tap: wait for a tap, else the player acts.
func show_step(text: String, p_focus: Callable, p_tap: bool, progress := "") -> void:
	set_meta("no_dim", false)
	focus = p_focus
	tap_mode = p_tap
	_text.text = Keywords.colorize(text, true)
	_hint.text = "Tap anywhere to continue ▸" if tap_mode else "Your turn: do it! ▸"
	_step_label.text = progress
	mouse_filter = Control.MOUSE_FILTER_STOP if tap_mode else Control.MOUSE_FILTER_IGNORE
	visible = true
	_bubble.modulate.a = 0.0
	var tw := _bubble.create_tween()
	tw.tween_property(_bubble, "modulate:a", 1.0, 0.2)


func _rect() -> Rect2:
	if focus.is_valid():
		var r = focus.call()
		if r is Rect2:
			return r
	return Rect2()


func _gui_input(ev: InputEvent) -> void:
	if tap_mode and ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
		accept_event()
		tapped.emit()


func _unhandled_input(ev: InputEvent) -> void:
	if visible and tap_mode and ev is InputEventKey and ev.pressed and not ev.echo and ev.keycode in [KEY_SPACE, KEY_ENTER, KEY_KP_ENTER]:
		get_viewport().set_input_as_handled()
		tapped.emit()


func _process(d: float) -> void:
	_t += d
	var r := _rect()
	var vs := get_viewport_rect().size
	# the bubble sits away from the spotlight: above it if the spotlight is low on screen, else below
	var bs := _bubble.get_combined_minimum_size()
	var bx := vs.x / 2.0 - bs.x / 2.0
	var by := vs.y / 2.0 - bs.y / 2.0
	var corner: bool = get_meta("no_dim", false)
	_text.custom_minimum_size.x = 440.0 if corner else 620.0
	_hint.visible = not corner
	if corner:
		bx = 20.0
		# use the bubble's real (laid-out) height so its bottom never runs off screen
		by = vs.y - maxf(bs.y, _bubble.size.y) - 28.0
	elif r.size != Vector2.ZERO:
		bx = clampf(r.get_center().x - bs.x / 2.0, 20, vs.x - bs.x - 20)
		if r.get_center().y > vs.y * 0.5:
			by = maxf(20, r.position.y - bs.y - 90)
		else:
			by = minf(vs.y - bs.y - 20, r.end.y + 90)
	by = clampf(by, 20.0, vs.y - maxf(bs.y, _bubble.size.y) - 20.0)
	_bubble.position = Vector2(bx, by)
	_bubble.reset_size()
	_hand.visible = r.size != Vector2.ZERO
	if _hand.visible:
		var bob := sin(_t * 6.0) * 10.0
		if r.get_center().y > vs.y * 0.5:
			# pointing down onto it from above
			_hand.text = "👇"
			_hand.position = Vector2(r.get_center().x - 26, r.position.y - 74 + bob)
		else:
			_hand.text = "👆"
			_hand.position = Vector2(r.get_center().x - 26, r.end.y + 6 - bob)
	queue_redraw()


func _draw() -> void:
	var vs := get_viewport_rect().size
	var r := _rect()
	var dim := Color(0, 0, 0, 0.62)
	if get_meta("no_dim", false):
		return
	if r.size == Vector2.ZERO:
		draw_rect(Rect2(Vector2.ZERO, vs), dim)
		return
	r = r.grow(12)
	# darken everything except the spotlight
	draw_rect(Rect2(0, 0, vs.x, r.position.y), dim)
	draw_rect(Rect2(0, r.end.y, vs.x, vs.y - r.end.y), dim)
	draw_rect(Rect2(0, r.position.y, r.position.x, r.size.y), dim)
	draw_rect(Rect2(r.end.x, r.position.y, vs.x - r.end.x, r.size.y), dim)
	var glow := 0.6 + 0.4 * sin(_t * 5.0)
	draw_rect(r, Color(1, 0.85, 0.3, glow), false, 4.0)
	draw_rect(r.grow(5), Color(1, 0.85, 0.3, glow * 0.35), false, 3.0)
