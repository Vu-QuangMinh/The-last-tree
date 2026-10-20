class_name MessageScreen
extends Control
## A title, some text and a row of buttons. Used for campfires, events and the end of a run.

signal pressed(index: int)

var title := ""
var body := ""
var buttons: Array = ["Continue"]
var disabled: Array = []:  # per button: true = greyed out (set any time: it applies to the buttons already shown)
	set(v):
		disabled = v
		for i in _btns.size():
			_btns[i].disabled = disabled.size() > i and disabled[i]
var cards := false  # events: each option is a card (its words wrapped inside), all of them fitting across the screen
var _btns: Array[Button] = []
var act := 1
var on_stage := false  # Puppet Stage: laid over the stage (no backdrop of its own), the shade a little lighter
var title_color := Color.WHITE
var extra: Control = null  # shown between the text and the buttons (the campfire's HP bar)
var small_buttons := false  # the size of the Main Menu's buttons (170 x 42)


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
	var v := VBoxContainer.new()
	v.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_theme_constant_override("separation", 24)
	add_child(v)
	var t := UiTheme.label(title, 48, title_color)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(t)
	var b := UiTheme.label(body, 22, UiTheme.TEXT)
	b.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	b.custom_minimum_size = Vector2(900, 0)
	b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	v.add_child(b)
	if extra != null:
		extra.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		v.add_child(extra)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 24 if cards else 20)
	v.add_child(row)
	for i in buttons.size():
		var idx := i
		var btn: Button
		if cards:
			btn = _option_card(buttons[i], buttons.size())
			btn.pressed.connect(func(): pressed.emit(idx))
		else:
			btn = UiTheme.button(buttons[i], func(): pressed.emit(idx), MenuScreen.BTN_FONT if small_buttons else 22)
			btn.custom_minimum_size = MenuScreen.BTN if small_buttons else Vector2(240, 56)
		btn.disabled = disabled.size() > i and disabled[i]
		_btns.append(btn)
		row.add_child(btn)


## An event option as a card: what you do on top (bold), what you get under it ("Reach in and let it bite (lose 12 max
## HP): gain an artifact"), wrapped inside a parchment card. As wide as n of them allow across the screen (never clipped).
const CARD_MAX_W := 340.0
const ROW_W := 1800.0


func _option_card(text: String, n: int) -> Button:
	var w := minf(CARD_MAX_W, (ROW_W - 24.0 * (n - 1)) / float(n))
	var btn := Button.new()
	btn.custom_minimum_size = Vector2(w, 200)
	btn.focus_mode = Control.FOCUS_NONE
	btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	for state in ["normal", "hover", "pressed", "disabled", "focus"]:
		var sb := StyleBoxFlat.new()
		sb.bg_color = {"normal": SpellCard.PARCHMENT, "hover": SpellCard.PARCHMENT.lightened(0.12), "pressed": SpellCard.PARCHMENT.darkened(0.08),
			"disabled": SpellCard.PARCHMENT.darkened(0.45), "focus": Color(0, 0, 0, 0)}[state]
		sb.border_color = Color(1, 0.8, 0.3) if state == "hover" else Color(0.4, 0.26, 0.14)
		sb.set_border_width_all(4 if state == "hover" else 3)
		sb.set_corner_radius_all(14)
		sb.shadow_color = Color(0, 0, 0, 0.35)
		sb.shadow_size = 6
		if state == "focus":
			sb.draw_center = false
			sb.set_border_width_all(0)
			sb.shadow_size = 0
		btn.add_theme_stylebox_override(state, sb)
	var cut := text.find("):")
	var head := text.substr(0, cut + 1) if cut >= 0 else text
	var tail := text.substr(cut + 2).strip_edges() if cut >= 0 else ""
	if cut < 0 and text.contains(": "):
		head = text.get_slice(": ", 0)
		tail = text.substr(head.length() + 2)
	var col := VBoxContainer.new()
	col.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	col.offset_left = 16
	col.offset_right = -16
	col.offset_top = 14
	col.offset_bottom = -14
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", 10)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	btn.add_child(col)
	var h := UiTheme.label(head[0].to_upper() + head.substr(1), 21, Color(0.25, 0.14, 0.08))
	h.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	h.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(h)
	if tail != "":
		var g := UiTheme.label(tail[0].to_upper() + tail.substr(1), 20, Color(0.55, 0.12, 0.1))
		g.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		g.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		g.mouse_filter = Control.MOUSE_FILTER_IGNORE
		col.add_child(g)
	return btn
