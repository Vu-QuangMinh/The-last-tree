class_name PauseMenu
extends Control
## The pause menu (the fight's and the map's ☰ Menu button): Resume, Settings, Main Menu, Quit to Desktop.
## Leaving asks first, in the same popup; `note` says what happens to the run ("Your run is saved: ...").
## The host frees it on `resumed`; Esc resumes too.

signal resumed
signal main_menu
signal settings_closed  # (the Show Hotkey setting may have changed: the host can refresh)

var note_menu := "Abandon this run and return to the Main Menu?"
var note_quit := "Quit The Last Tree?"


## Opens over `host`, full screen. note_menu / note_quit: the confirmation texts.
static func open(host: Control, p_note_menu: String, p_note_quit: String) -> PauseMenu:
	var p := PauseMenu.new()
	p.note_menu = p_note_menu
	p.note_quit = p_note_quit
	host.add_child(p)
	return p


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	z_index = 100
	var shade := ColorRect.new()
	shade.color = Color(0, 0, 0, 0.6)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shade)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)
	var panel := PanelContainer.new()
	var board := UiSkin.box("board_pause_menu", [95, 90, 95, 94], [60, 56, 60, 56])
	panel.add_theme_stylebox_override("panel", board if board != null else UiTheme.panel_box(0.95, 16))
	panel.custom_minimum_size = Vector2(420 if board != null else 380, 0)
	center.add_child(panel)
	_add_leaf.call_deferred(panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	panel.add_child(v)
	var paused := UiTheme.heading("Paused", 28, Color(0.24, 0.1, 0.16) if UiSkin.is_circus() else Color.WHITE)  # (the Cirus board is cream)
	paused.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER  # centred on the board
	v.add_child(paused)
	_add_button(v, "Resume", func(): resumed.emit())
	_add_button(v, "Settings", func():
		var s := SettingsScreen.new()
		s.closed.connect(func():
			s.queue_free()
			settings_closed.emit())
		add_child(s))
	_add_button(v, "Main Menu", func(): _confirm_in(v, panel, note_menu, func(): main_menu.emit()))
	_add_button(v, "Quit to Desktop", func(): _confirm_in(v, panel, note_quit, func(): get_tree().quit()))


func _unhandled_input(ev: InputEvent) -> void:
	if ev is InputEventKey and ev.pressed and not ev.echo and ev.keycode == KEY_ESCAPE:
		get_viewport().set_input_as_handled()
		resumed.emit()


func _add_button(v: VBoxContainer, text: String, on_press: Callable) -> void:
	var b := UiTheme.button(text, on_press, 20)
	b.custom_minimum_size = Vector2(320, 52)
	UiTheme.use_menu_style(b)
	v.add_child(b)


## New theme: the leaf that sits on the top edge of the pause board (once the board has its real size).
func _add_leaf(panel: Control) -> void:
	var leaf := UiSkin.icon("menu_leaf", 92)
	if leaf == null:
		return
	await get_tree().process_frame
	if not is_instance_valid(panel):
		leaf.free()
		return
	leaf.position = panel.global_position - global_position + Vector2(panel.size.x * 0.58, -58.0)
	add_child(leaf)


## Swaps the menu's buttons (v) for a Yes/Cancel confirmation, in the same popup (panel).
func _confirm_in(v: VBoxContainer, panel: PanelContainer, text: String, on_yes: Callable) -> void:
	v.hide()
	var cv := VBoxContainer.new()
	cv.add_theme_constant_override("separation", 12)
	panel.add_child(cv)
	var l := UiTheme.label(text, 19, UiTheme.DANGER)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(320, 0)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cv.add_child(l)
	var yes := UiTheme.button("Yes", on_yes, 20)
	yes.custom_minimum_size = Vector2(320, 48)
	cv.add_child(yes)
	var no := UiTheme.button("Cancel", func(): cv.queue_free(); v.show(), 20)
	no.custom_minimum_size = Vector2(320, 48)
	cv.add_child(no)
