class_name PauseMenu
extends Control
## The pause menu (the fight's and the map's ☰ Menu button): Resume, Settings, Main Menu, Quit to Desktop.
## Leaving asks first, in the same popup; `note` says what happens to the run ("Your run is saved: ...").
## The host frees it on `resumed`; Esc resumes too.

signal resumed
signal main_menu
signal settings_closed  # (the Show Hotkey setting may have changed: the host can refresh)

const SHOT_DIR := "D:/GitHub Projects/The-last-tree/scrshot"

var world_keep: Array = []  # nodes of the host that stay in a "Without UI" shot (the scenery is always kept)
var note_menu :="Abandon this run and return to the Main Menu?"
var note_quit := "Quit Behind the Curtain?"


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
	z_index = 400  # (over everything of the screen it opens on, e.g. the Puppet Stage's map, whose HUD sits at PuppetStage.CEILING_Z + 2)
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
	var board := UiSkin.box("board_pause_menu", [58, 58, 58, 58] if UiSkin.is_puppet() else [95, 90, 95, 94], [60, 56, 60, 56])
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
	var shot_box := VBoxContainer.new()  # (With UI / Without UI: shown under the Screenshot button once it is clicked)
	shot_box.add_theme_constant_override("separation", 12)
	shot_box.visible = false
	_add_button(v, "Screenshot", func(): shot_box.visible = not shot_box.visible)
	v.add_child(shot_box)
	_add_button(shot_box, "With UI", func(): _screenshot(true))
	_add_button(shot_box, "Without UI", func(): _screenshot(false))
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


## Takes a picture of the screen behind the menu and saves it in SHOT_DIR. The menu itself is hidden for the shot;
## "without UI" hides the host's other children too, except the scenery (backdrop, stage) and `world_keep`.
func _screenshot(with_ui: bool) -> void:
	var hidden: Array = []
	visible = false
	if not with_ui:
		for c in get_parent().get_children():
			if c == self or not (c is CanvasItem) or not c.visible:
				continue
			if c in world_keep or c is Backdrop or c is PuppetStage or c is StageLights:
				continue
			c.visible = false
			hidden.append(c)
	await get_tree().process_frame
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	for c in hidden:
		if is_instance_valid(c):
			c.visible = true
	visible = true
	DirAccess.make_dir_recursive_absolute(SHOT_DIR)
	var path := "%s/shot_%s_%s.png" % [SHOT_DIR, Time.get_datetime_string_from_system().replace(":", "-").replace("T", "_"), "ui" if with_ui else "no_ui"]
	if img.save_png(path) == OK:
		Events.toast.emit("Screenshot saved: " + path.get_file(), UiTheme.ACCENT)
	else:
		Events.toast.emit("Could not save the screenshot.", UiTheme.DANGER)


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
