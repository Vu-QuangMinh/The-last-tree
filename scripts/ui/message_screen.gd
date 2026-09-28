class_name MessageScreen
extends Control
## A title, some text and a row of buttons. Used for campfires, events and the end of a run.

signal pressed(index: int)

var title := ""
var body := ""
var buttons: Array = ["Continue"]
var disabled: Array = []  # per button: true = greyed out
var act := 1
var title_color := Color.WHITE


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = UiTheme.get_theme()
	var bd := Backdrop.new()
	bd.act = act
	add_child(bd)
	var shade := ColorRect.new()
	shade.color = Color(0, 0, 0, 0.45)
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
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 20)
	v.add_child(row)
	for i in buttons.size():
		var idx := i
		var btn := UiTheme.button(buttons[i], func(): pressed.emit(idx), 22)
		btn.custom_minimum_size = Vector2(240, 56)
		btn.disabled = disabled.size() > i and disabled[i]
		row.add_child(btn)
