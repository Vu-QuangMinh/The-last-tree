class_name HudBar
extends PanelContainer
## Run info along the top of the map and loadout screens.

signal codex_pressed

var run: RunState
var _label: Label
var _arts: HBoxContainer


func setup(p_run: RunState) -> void:
	run = p_run


func _ready() -> void:
	add_theme_stylebox_override("panel", UiTheme.panel_box(0.9, 0))
	set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	custom_minimum_size = Vector2(1920, 56)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 24)
	add_child(h)
	_label = UiTheme.label("", 20, Color.WHITE)
	h.add_child(_label)
	_arts = HBoxContainer.new()
	_arts.add_theme_constant_override("separation", 8)
	_arts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(_arts)
	h.add_child(UiTheme.button("Codex", func(): codex_pressed.emit()))
	h.add_child(UiTheme.button("Wiki (F1)", func(): get_tree().root.get_node("Main").open_wiki() if get_tree().root.has_node("Main") else null))
	refresh()


func refresh() -> void:
	var p := run.player
	_label.text = "♥ %d / %d     Act %d     ◉ %d Amber     ✿ %d Seedlings     %d spells · %d slots" % [p.hp, p.max_hp, run.act, run.amber, run.seedlings, run.spellbook.size(), run.active_slots()]
	for c in _arts.get_children():
		c.queue_free()
	for id in run.artifacts:
		var a := Artifacts.get_def(id)
		var chip := UiTheme.label("◆ " + a.name, 16, Color(1, 0.85, 0.5))
		if id == "kindling_stone":
			chip.text += " (charged)" if p.kindling_charged else " (%d/3)" % p.kindling_chants
		chip.tooltip_text = a.name + "\n" + a.desc
		chip.mouse_filter = Control.MOUSE_FILTER_STOP
		_arts.add_child(chip)
