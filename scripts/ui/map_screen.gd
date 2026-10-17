class_name MapScreen
extends Control
## The act's map on a parchment scroll, Slay the Spire style: rooms on a 7-column grid, dotted paths between them,
## the boss at the top. Scroll with the mouse wheel; click a glowing room to go there.

signal node_chosen(col: int)
signal codex_pressed
signal test_room_chosen(room: Dictionary)  # Dev Mode: Room Test
signal menu_requested  # Main Menu from the pause menu (the run is saved on the map)

## type -> [icon, name, ring colour, description]
const LOOK := {
	"fight": ["⚔", "Fight", Color(0.45, 0.36, 0.28), "A normal fight. Rewards: a spell and Leaves."],
	"elite": ["👹", "Elite", Color(0.75, 0.15, 0.12), "A tough fight. Rewards: a spell (better odds), an artifact and more Leaves."],
	"rest": ["🔥", "Campfire", Color(0.9, 0.5, 0.1), "Rest (heal 30%) or upgrade a spell."],
	"treasure": ["🎁", "Treasure", Color(0.85, 0.65, 0.1), "Pick an artifact. One of them is cursed."],
	"shop": ["🛒", "Merchant", Color(0.2, 0.55, 0.3), "Spend Leaves on spells, artifacts, an upgrade or a meal."],
	"event": ["❓", "Unknown", Color(0.45, 0.3, 0.65), "Usually a strange encounter with choices; sometimes a fight, a merchant or treasure."],
	"boss": ["👑", "Boss", Color(0.55, 0.1, 0.35), "The guardian of this act."],
}
## New theme: room type -> the painted ring / icon names (assets/New/Map/map_ring_<x>.png, map_icon_<x>.png)
const ART := {"fight": "normal", "elite": "elite", "rest": "campfire", "treasure": "treasure", "shop": "merchant", "event": "unknown", "boss": "boss"}
const ROW_H := 168.0  # (96 * 1.75: the map was stretched taller)
const COL_W := 138.0
const INK := Color(0.28, 0.2, 0.12)

var run: RunState
var test_rooms: Array = []  # Dev Mode Room Test: [{type, label, act, event}], laid out as a plain grid, no paths
var _content: Control
var _scroll: ScrollContainer
var sheet: PanelContainer  # the parchment (the tutorial points at it)
var legend: VBoxContainer
var _pause: PauseMenu
var _cx := 530.0  # x of the map's middle column (the painted scroll has a narrower paper)
var _map_w := 1060.0
var _col_w := COL_W
var _buttons := {}  # Vector2i(floor, col) -> the room's button
var _eaten := {}  # path dots the hero has walked over: "floor_col_nextcol_i" -> true
var _moving := false  # the hero is walking to the room you chose
## Puppet Stage: the map hangs in the stage itself. The boss's ring is tied to a rope that goes straight up behind the ceiling's valance, the paths between
## the rooms are ropes too, and the wheel moves the whole thing up and down (scroll up: the map sinks and more of the boss's rope shows).
var on_stage := false
var drop_delay := 0.0  # on the stage: seconds to wait before the map is let down (the drapes close first)
const VIEW_TOP := 130.0  # (on the stage: where the map's content starts on the screen when scrolled to the top; the bottom of the view is VIEW_TOP + VIEW_H)
const VIEW_H := 910.0
const WORLD_Z := -12  # (the map's world sits under the ceiling: this is relative to the MapScreen, which is PuppetStage.CEILING_Z + 2)
const ROPE_UP := 3000.0  # the boss's rope goes this far above the boss (out of the screen, whatever the scroll)
const CHALK := Color(0.96, 0.92, 0.78)
var _world: Control  # on the stage: holds _content, slides in and out
var _scroll_y := 0.0
var _scroll_to := 0.0
const DROP_FROM := -520.0  # where the map starts (above the screen), px
const DROP_G := 2300.0  # gravity, px/s^2
const DROP_K := 190.0  # the rope's stiffness once it is out to its length (about 2.2 swings a second)
const DROP_C := 5.5  # ... and how fast the bouncing dies out
const WOBBLE_END := 3.2  # seconds after landing the rooms stop swinging
var _drop := false
var _lowering := false  # the map is being pulled up
var _winch_snd: AudioStreamPlayer
var _wheel_ms := -10000  # when the wheel was last turned
const WHEEL_SOUND_MS := 140  # the winch is heard this long after each notch of the wheel, not while the map eases to a stop
var _drop_v := 0.0
var _land_t := -1.0  # seconds since the map first reached its place (-1 = not yet / over)
var _base := {}  # Vector2i(floor, col) -> the room button's own place


func setup(p_run: RunState) -> void:
	run = p_run


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = UiTheme.get_theme()
	if on_stage:
		mouse_filter = Control.MOUSE_FILTER_IGNORE  # (the stage's own buttons stay clickable around the board)
	else:
		var bd := Backdrop.new()
		bd.act = 1 if not test_rooms.is_empty() else run.act
		add_child(bd)
		var shade := ColorRect.new()
		shade.color = Color(0, 0, 0, 0.45)
		shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(shade)
	# the parchment scroll (not on the stage: there the rooms and ropes hang straight in the scene)
	_content = Control.new()
	var testing := not test_rooms.is_empty()
	var rows := _test_rows() if testing else run.map.size()
	if on_stage:
		_cx = 960.0
		_col_w = 140.0
		_world = Control.new()
		_world.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		_world.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_world.z_index = WORLD_Z
		_world.visible = false  # (hidden from the first frame: it is shown by rise(), when it is let down; before, it flashed for a frame at its place)
		add_child(_world)
		_content.custom_minimum_size = Vector2(1920, rows * ROW_H + 140)
		_content.size = _content.custom_minimum_size
		_content.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_content.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS  # (the big rope and knot pictures are shrunk a lot)
		_world.add_child(_content)
	else:
		sheet = PanelContainer.new()
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0.9, 0.83, 0.66)
		sb.border_color = Color(0.45, 0.32, 0.18)
		sb.set_border_width_all(4)
		sb.set_corner_radius_all(18)
		sb.shadow_color = Color(0, 0, 0, 0.5)
		sb.shadow_size = 12
		var scroll_art := UiSkin.box("map_scroll", [0, 122, 0, 122], [40, 132, 40, 128])  # New theme: the painted scroll (rollers top and bottom)
		if scroll_art != null:
			sheet.add_theme_stylebox_override("panel", scroll_art)
			_cx = 500.0
			_col_w = 124.0  # the painted paper is narrower: keep the rooms off its torn edges
			_map_w = 1000.0
		else:
			sheet.add_theme_stylebox_override("panel", sb)
		sheet.position = Vector2(420, 66)
		sheet.size = Vector2(1080, 1000)
		add_child(sheet)
		_scroll = ScrollContainer.new()
		_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		sheet.add_child(_scroll)
		_content.custom_minimum_size = Vector2(_map_w, _test_height() if testing else rows * ROW_H + 140)
		_scroll.add_child(_content)
	if not testing:
		_content.draw.connect(_draw_paths)
	var choices := [] if testing else run.choices()
	if testing:
		for i in test_rooms.size():
			_content.add_child(_test_button(i))
	else:
		for f in rows:
			for n in run.map[f]:
				if n == null:
					continue
				var nb := _node_button(f, n, choices)
				_buttons[Vector2i(f, n.col)] = nb
				_base[Vector2i(f, n.col)] = nb.position
				_content.add_child(nb)
	# left: title and legend
	var left := VBoxContainer.new()
	legend = left
	if on_stage:
		left.visible = false  # (the board has its own heading)
	left.position = Vector2(30, 80)
	left.size = Vector2(370, 900)
	left.add_theme_constant_override("separation", 10)
	add_child(left)
	if testing:
		left.add_child(UiTheme.label("Room Test", 40, Color.WHITE))
		left.add_child(UiTheme.label("Dev Mode", 24, Color(0.85, 1, 0.75)))
		left.add_child(UiTheme.label("Click any room to go straight in.", 18, UiTheme.MUTED))
		left.add_child(UiTheme.label("Every room has a Back to room map button.", 18, UiTheme.MUTED))
	else:
		left.add_child(UiTheme.label(["", "Act I", "Act II", "Act III"][run.act], 40, Color.WHITE))
	if not testing:
		left.add_child(UiTheme.label(["", "The Edge of the Wood", "The Rotting Hollow", "The Last Winter"][run.act], 24, Color(0.85, 1, 0.75)))
		left.add_child(UiTheme.label("Floor %d of %d, then the boss" % [maxi(0, run.floor_no()), MapGen.FLOORS], 18, UiTheme.MUTED))
		var gap := Control.new()
		gap.custom_minimum_size = Vector2(0, 14)
		left.add_child(gap)
		var counts := MapGen.counts(run.map)
		for t in ["fight", "elite", "event", "shop", "treasure", "rest", "boss"]:
			left.add_child(_legend_row(t, counts.get(t, 0)))
	var hud := HudBar.new()
	hud.setup(run)
	hud.codex_pressed.connect(func(): codex_pressed.emit())
	add_child(hud)
	var tip := UiTheme.label("Choose a glowing room. Scroll to look ahead.", 18, UiTheme.MUTED)
	tip.position = Vector2(30, 1030)
	if on_stage:
		tip = UiTheme.label("Act %s · %s · floor %d of %d: choose a glowing room, scroll to look ahead" % [["", "I", "II", "III"][run.act], ["", "The Edge of the Wood", "The Rotting Hollow", "The Last Winter"][run.act], maxi(0, run.floor_no()), MapGen.FLOORS], 20, CHALK)
		tip.add_theme_constant_override("outline_size", 5)
		tip.add_theme_color_override("font_outline_color", Color(0.12, 0.06, 0.03))
		tip.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		tip.size = Vector2(1920, 30)
		tip.position = Vector2(0, 1038)
		tip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(tip)
	# start with your position in view (the bottom of the map at the start of an act)
	await get_tree().process_frame
	await get_tree().process_frame  # (the scroll area has its real size only now)
	# your room always in view, a little below the middle so the rooms ahead show above it
	var py := _pos(0, 0).y if testing else _pos(maxi(0, run.row), maxi(0, run.col)).y
	if on_stage:
		_scroll_y = clampf(py - VIEW_H * 0.58, 0.0, _scroll_max())
		_scroll_to = _scroll_y
		_place_content()
	else:
		var view_h := _scroll.size.y
		_scroll.scroll_vertical = int(clampf(py - view_h * 0.58, 0.0, maxf(0.0, _content.custom_minimum_size.y - view_h)))
	# ☰ Menu (bottom right, as in fights): Resume, Settings, Main Menu, Quit. The run is saved on the map.
	if on_stage:
		rise()  # (the stage's own Menu button is there already)
		return
	var menu_btn := UiTheme.button("☰ Menu", _open_pause_menu, 18)
	menu_btn.custom_minimum_size = Vector2(130, 44)
	menu_btn.position = Vector2(1920 - 150, 1024)
	UiTheme.use_menu_style(menu_btn)
	UiTheme.use_heading_font(menu_btn)
	add_child(menu_btn)


## Puppet Stage: the map is let down from the ceiling on its rope: gravity pulls it down (free fall), then the rope stretches and it bounces a few times
## before it hangs in place (a spring around the right place); the rooms hang on the rope like weights, so the lower ones swing a little later and a
## little more (see _dy) ...
func rise() -> void:
	_world.position.y = DROP_FROM
	if drop_delay > 0.0:  # (the stage's drapes are being drawn together first)
		await get_tree().create_timer(drop_delay).timeout
	_world.visible = true
	_drop = true
	_drop_v = 0.0
	_land_t = -1.0


## ... and is pulled back up behind the valance once a room is chosen.
func lower() -> void:
	_lowering = true
	_drop = false
	_land_t = -1.0
	var tw := create_tween().set_parallel(true)
	tw.tween_property(_world, "position:y", -1200.0, 0.6).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	for c in get_children():
		if c is Label and c != null:
			tw.tween_property(c, "modulate:a", 0.0, 0.3)
	await tw.finished
	_lowering = false  # (the winch stops with the map)


func _scroll_max() -> float:
	return maxf(0.0, _content.custom_minimum_size.y - VIEW_H)


## The content's place on the screen for the current scroll.
func _place_content() -> void:
	_content.position = Vector2(0.0, VIEW_TOP - _scroll_y)


func _process(delta: float) -> void:
	if not on_stage or _content == null:
		return
	# the winch (sfx_cog_gear) runs only while the map is really moving: let down (until it reaches its place; the bouncing after is silent), pulled up, or scrolled
	_winch(_lowering or (_drop and _land_t < 0.0) or Time.get_ticks_msec() - _wheel_ms < WHEEL_SOUND_MS)
	if _drop:
		_step_drop(minf(delta, 0.033))
	if not is_equal_approx(_scroll_y, _scroll_to):
		_scroll_y = lerpf(_scroll_y, _scroll_to, 1.0 - exp(-12.0 * delta))
		if absf(_scroll_y - _scroll_to) < 0.3:
			_scroll_y = _scroll_to
		_place_content()


func _winch(on: bool) -> void:
	if on and (_winch_snd == null or not is_instance_valid(_winch_snd)):
		_winch_snd = Audio.play_held("sfx_cog_gear")
	elif not on and _winch_snd != null:
		Audio.stop_held(_winch_snd, 0.06)
		_winch_snd = null


func _exit_tree() -> void:
	_winch(false)


func _step_drop(dt: float) -> void:
	var y := _world.position.y
	if y < 0.0 and _land_t < 0.0:
		_drop_v += DROP_G * dt  # free fall until the rope is out to its length
	else:
		if _land_t < 0.0:
			_land_t = 0.0
		_drop_v += (-DROP_K * y - DROP_C * _drop_v) * dt  # then it is a spring around the right place
	y += _drop_v * dt
	if _land_t >= 0.0:
		_land_t += dt
		if _land_t > 0.4 and absf(y) < 0.3 and absf(_drop_v) < 8.0:
			y = 0.0
			_drop = false
	_world.position.y = y
	_wobble()
	if not _drop and _land_t > WOBBLE_END:
		_land_t = -1.0


## Every room swings on the rope: the same wave as the whole map's, later and bigger the further down it hangs (the boss, at the top, only follows the rope).
func _dy(f: int) -> float:
	if _land_t < 0.0 or _land_t > WOBBLE_END:
		return 0.0
	var top := run.map.size() - 1
	var depth := 1.0 - f / float(maxi(1, top))
	var t := maxf(0.0, _land_t - 0.05 * depth * top)
	return 16.0 * depth * exp(-2.2 * t) * sin(TAU * 2.0 * t)


func _wobble() -> void:
	for key in _buttons:
		var b: Control = _buttons[key]
		if _base.has(key):
			b.position.y = _base[key].y + _dy(key.x)
	_content.queue_redraw()


## The wheel moves the hanging map (the rooms are Buttons that ignore it, so it comes here).
func _unhandled_input(ev: InputEvent) -> void:
	if not on_stage or _pause != null or _moving or not ev is InputEventMouseButton or not ev.pressed:
		return
	var step := ROW_H * 1.3
	if ev.button_index == MOUSE_BUTTON_WHEEL_UP or ev.button_index == MOUSE_BUTTON_WHEEL_DOWN:
		_wheel_ms = Time.get_ticks_msec()
	if ev.button_index == MOUSE_BUTTON_WHEEL_UP:
		_scroll_to = clampf(_scroll_to - step, 0.0, _scroll_max())
	elif ev.button_index == MOUSE_BUTTON_WHEEL_DOWN:
		_scroll_to = clampf(_scroll_to + step, 0.0, _scroll_max())


func _open_pause_menu() -> void:
	if _pause != null:
		return
	var saved := "Your run is saved: Continue on the main menu brings you back to this map."
	_pause = PauseMenu.open(self, "Return to the Main Menu? " + saved, "Quit The Last Tree? " + saved)
	_pause.resumed.connect(func():
		_pause.queue_free()
		_pause = null)
	_pause.main_menu.connect(func(): menu_requested.emit())


func _unhandled_key_input(ev: InputEvent) -> void:
	if _pause == null and ev.pressed and not ev.echo and (ev as InputEventKey).keycode == KEY_ESCAPE:
		get_viewport().set_input_as_handled()
		_open_pause_menu()


func _legend_row(t: String, count: int) -> Control:
	var p := PanelContainer.new()
	var plate := UiSkin.box("legend_plate", [33, 0, 30, 0], [40, 8, 34, 8])  # New theme: the painted plaque
	p.add_theme_stylebox_override("panel", plate if plate != null else UiTheme.panel_box(0.8, 10))
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 10)
	p.add_child(h)
	var icon: Control = UiSkin.icon(_icon_name(t), 38)
	if icon == null:
		icon = UiTheme.label(LOOK[t][0], 26, Color.WHITE)
		icon.custom_minimum_size = Vector2(40, 0)
	h.add_child(icon)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 0)
	h.add_child(v)
	v.add_child(UiTheme.label("%s  ×%d" % [LOOK[t][1], count], 19, (LOOK[t][2] as Color).lightened(0.45)))
	var d := UiTheme.label(LOOK[t][3], 13, UiTheme.MUTED)
	d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	d.custom_minimum_size = Vector2(290, 0)
	v.add_child(d)
	return p


const TEST_COLS := 5
const TEST_ROW_H := 160.0
const TEST_COL_W := 190.0


func _test_rows() -> int:
	return ceili(test_rooms.size() / float(TEST_COLS))


## The five columns, spread evenly: the outer left one 10 px in from the full spread, the outer right one 5 px in.
func _test_x(c: int) -> float:
	var left := _cx - (TEST_COLS - 1) / 2.0 * TEST_COL_W + 10.0
	var right := _cx + (TEST_COLS - 1) / 2.0 * TEST_COL_W - 5.0
	return lerpf(left, right, c / float(TEST_COLS - 1))


func _test_height() -> float:
	return _test_rows() * TEST_ROW_H + 140.0


## Room Test: five rooms to a row, the first row at the bottom, climbing until every room is there.
func _test_button(i: int) -> Control:
	var room: Dictionary = test_rooms[i]
	var b: Button = _node_button(i / TEST_COLS, {"type": room.type, "col": i % TEST_COLS, "next": []}, [])
	b.disabled = false
	b.modulate = Color.WHITE
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	b.tooltip_text = room.label
	b.pressed.connect(func():
		Audio.play("map_node_select")
		test_room_chosen.emit(room))
	var l := UiTheme.label(room.label, 15, INK)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.size = Vector2(TEST_COL_W - 20.0, 44)
	l.position = Vector2((b.size.x - l.size.x) / 2.0, b.size.y + 2.0)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(l)
	return b


func _pos(f: int, c: int) -> Vector2:
	if not test_rooms.is_empty():
		return Vector2(_test_x(c), (_test_rows() - f) * TEST_ROW_H + 10.0)
	var rows := run.map.size()
	var y := (rows - f) * ROW_H + 10.0
	var x := _cx + (c - (MapGen.COLS - 1) / 2.0) * _col_w
	# a little wobble so it doesn't look like a grid
	if run.map[f].size() > c and run.map[f][c] != null and run.map[f][c].type != "boss":
		x += sin(f * 3.1 + c * 1.7) * 22.0
		y += cos(f * 1.3 + c * 2.9) * 12.0
	return Vector2(x, y)


## The painted icon of a room type (the merchant's is the small face if there is one, else the big portrait).
func _icon_name(t: String) -> String:
	if t == "shop" and UiSkin.tex("map_icon_merchant") == null:
		return "merchant_portrait"
	return "map_icon_" + str(ART.get(t, "normal"))


func _node_button(f: int, n: Dictionary, choices: Array) -> Control:
	var look: Array = LOOK.get(n.type, LOOK.fight)
	var boss: bool = n.type == "boss"
	var sz := 110.0 if boss else 66.0
	var b := Button.new()
	b.text = look[0]
	b.add_theme_font_size_override("font_size", 52 if boss else 30)
	b.custom_minimum_size = Vector2(sz, sz)
	b.size = Vector2(sz, sz)
	b.position = _pos(f, n.col) - Vector2(sz, sz) / 2.0
	b.focus_mode = Control.FOCUS_NONE
	b.tooltip_text = "%s
%s" % [look[1], look[3]]
	var testing := not test_rooms.is_empty()  # (Room Test: no visited / here look at all, run.row there is just the last test room)
	var here: bool = not testing and f == run.row and n.col == run.col
	var can: bool = f == run.row + 1 and n.col in choices
	var visited: bool = not testing and (f < run.row or here)
	# New theme: a painted ring, with the room's icon in it (a visited room is just its ring with a leaf; you are the sprout)
	var ring_name: String = "map_ring_" + str(ART.get(n.type, "normal"))
	var icon_name: String = _icon_name(n.type)
	if here:
		ring_name = "map_ring_you_are_here"
		icon_name = "map_icon_you_are_here"
	elif visited:
		ring_name = "map_ring_visited"
		icon_name = ""
	var ring := UiSkin.icon(ring_name, sz)
	if ring != null:
		b.text = ""
		for state in ["normal", "hover", "pressed", "disabled"]:
			var st := StyleBoxFlat.new()
			st.set_corner_radius_all(int(sz / 2))
			st.bg_color = Color(0, 0, 0, 0)
			if can and state != "disabled":  # a golden halo around the rooms you can go to
				st.shadow_color = Color(1.0, 0.8, 0.2, 0.75 if state == "hover" else 0.5)
				st.shadow_size = 14
			b.add_theme_stylebox_override(state, st)
		ring.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		b.add_child(ring)
		var frac := 0.8 if here else 0.66
		var icon: TextureRect = UiSkin.icon(icon_name, sz * frac) if icon_name != "" else null
		if icon != null:
			icon.position = (Vector2(sz, sz) - icon.custom_minimum_size) / 2.0 + (Vector2(0, -sz * 0.04) if here else Vector2.ZERO)
			icon.size = icon.custom_minimum_size
			b.add_child(icon)
		if not can and not visited:
			b.modulate = Color(0.88, 0.86, 0.8)
		elif visited and not here:
			b.modulate = Color.WHITE  # (a visited ring is solid)
	else:
		for state in ["normal", "hover", "pressed", "disabled"]:
			var st := StyleBoxFlat.new()
			st.set_corner_radius_all(int(sz / 2))
			st.bg_color = Color(0.96, 0.9, 0.76) if state != "hover" else Color(1, 0.97, 0.85)
			st.border_color = look[2] if not can else Color(1, 0.8, 0.2)
			st.set_border_width_all(6 if can else 4)
			if state == "disabled":
				st.bg_color = Color(0.86, 0.79, 0.63)
			b.add_theme_stylebox_override(state, st)
		if visited:
			b.modulate = Color(0.75, 0.75, 0.75, 0.75)
		if here:
			b.modulate = Color(0.7, 1, 0.7, 1)
			b.text = "✦"
			b.add_theme_color_override("font_disabled_color", Color(0.1, 0.5, 0.1))
	b.disabled = not can
	if can:
		b.pivot_offset = Vector2(sz, sz) / 2.0
		var tw := b.create_tween().set_loops()
		tw.tween_property(b, "scale", Vector2(1.12, 1.12), 0.55)
		tw.tween_property(b, "scale", Vector2.ONE, 0.55)
		var col: int = n.col
		b.pressed.connect(func():
			if _moving:
				return
			Audio.play("map_node_select")
			_walk_to(f, col))
	return b


## The sprout walks along the path to the chosen room, eating the ink dots on the way, then the room opens.
func _walk_to(f: int, col: int) -> void:
	_moving = true
	var to := _pos(f, col)
	var from := to + Vector2(0, ROW_H)  # (the start of the act: from just below the first row)
	var walk_edge := false
	if run.row >= 0:
		from = _pos(run.row, run.col)
		walk_edge = true
	var here_btn: Control = _buttons.get(Vector2i(run.row, run.col))
	if here_btn != null:  # the marker leaves it: the room it stood in turns into a visited one (its ring with the leaf), it does not just vanish
		var visited_ring := UiSkin.icon("map_ring_visited", here_btn.size.x)
		if visited_ring != null:
			for c in here_btn.get_children():
				c.queue_free()
			visited_ring.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			here_btn.add_child(visited_ring)
			here_btn.modulate = Color.WHITE
		else:
			here_btn.visible = false
	var sz := 66.0
	var marker := Control.new()
	marker.size = Vector2(sz, sz)
	marker.mouse_filter = Control.MOUSE_FILTER_IGNORE
	marker.z_index = 5
	var ring := UiSkin.icon("map_ring_you_are_here", sz)
	if ring != null:
		marker.add_child(ring)
		var hero := UiSkin.icon("map_icon_you_are_here", sz * 0.8)
		if hero != null:
			hero.position = (Vector2(sz, sz) - hero.custom_minimum_size) / 2.0 + Vector2(0, -sz * 0.04)
			hero.size = hero.custom_minimum_size
			marker.add_child(hero)
	else:
		var star := UiTheme.label("✦", 30, Color(0.1, 0.5, 0.1))
		star.position = Vector2(sz / 2.0 - 10, sz / 2.0 - 20)
		marker.add_child(star)
	marker.position = from - Vector2(sz, sz) / 2.0
	_content.add_child(marker)
	var steps := int(from.distance_to(to) / 14.0)
	var secs := clampf(from.distance_to(to) / 520.0, 0.45, 1.1)
	var tw := create_tween()
	tw.tween_method(func(p: float):
		marker.position = from.lerp(to, p) - Vector2(sz, sz) / 2.0
		if walk_edge and not on_stage:
			for i in steps:
				if i >= 3 and i <= steps - 4 and i / float(steps) <= p + 0.02:
					_eaten["%d_%d_%d_%d" % [run.row, run.col, col, i]] = true
		_content.queue_redraw(), 0.0, 1.0, secs).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await tw.finished
	node_chosen.emit(col)


func _draw_paths() -> void:
	var dot := UiSkin.tex("map_path_dot")
	for f in run.map.size() - 1:
		for n in run.map[f]:
			if n == null:
				continue
			for c in n.next:
				var from_here: bool = f == run.row and n.col == run.col
				var col := INK.lerp(Color(0.2, 0.5, 0.15), 0.8) if from_here else Color(INK, 0.55)
				var a := _pos(f, n.col) + Vector2(0.0, _dy(f))
				var b := _pos(f + 1, c) + Vector2(0.0, _dy(f + 1))
				if on_stage:  # a rope from room to room, tucked under the rings; the hero's walk leaves them whole
					MapRope.draw_between(_content, a, b, RING_R * 0.8, Color(0.75, 1.0, 0.6) if from_here else Color(1, 1, 1, 0.92), 8.0 if from_here else 6.5)
					continue
				var d := a.distance_to(b)
				var steps := int(d / 14.0)
				for i in steps:
					if i < 3 or i > steps - 4:
						continue  # leave room around the icons
					if _eaten.has("%d_%d_%d_%d" % [f, n.col, c, i]):
						continue  # the hero ate this one
					var p := a.lerp(b, i / float(steps))
					if dot != null:  # New theme: the painted ink dot (greener and bigger on the way out of your room)
						var ds := 11.0 if from_here else 8.5
						_content.draw_texture_rect(dot, Rect2(p - Vector2(ds, ds) / 2.0, Vector2(ds, ds)), false, Color(0.55, 1.0, 0.45, 0.95) if from_here else Color(1, 1, 1, 0.7))
					else:
						_content.draw_circle(p, 3.2 if from_here else 2.6, col)
	if on_stage:  # the boss's ring hangs from a rope that goes straight up behind the ceiling
		var last: int = run.map.size() - 1
		for n in run.map[last]:
			if n != null and n.type == "boss":
				var bp := _pos(last, n.col)
				MapRope.draw_between(_content, bp + Vector2(0, -BOSS_R * 0.7), bp + Vector2(0, -ROPE_UP), 0.0, Color.WHITE, 9.0)
				var knot := UiSkin.tex("map_rope_knot")  # the knot that ties the rope to the ring
				if knot != null:
					var ks := Vector2(KNOT_W, KNOT_W * knot.get_height() / knot.get_width())
					_content.draw_texture_rect(knot, Rect2(bp + Vector2(-ks.x / 2.0, -BOSS_R * 1.05 - ks.y * 0.52), ks), false)


const RING_R := 33.0  # (the room rings are 66 px)
const BOSS_R := 55.0
const KNOT_W := 56.0  # the picture of the knot is scaled to this width


## A rope drawn in code, so the sprite can come later: when a picture called "map_rope" is in the art folders (a tile of rope running UP-DOWN, any size; it is
## repeated along the rope and its width is scaled to the rope's) that is used, else the rope is a twisted cord drawn here.
class MapRope:
	const CORD := Color(0.72, 0.56, 0.34)
	const CORD_DARK := Color(0.36, 0.24, 0.12)
	const CORD_LIGHT := Color(0.88, 0.74, 0.5)

	## A rope from a to b, trimmed `trim` px off both ends (so it ends under the rings), `width` px thick, multiplied by `tint`.
	static func draw_between(ci: CanvasItem, a: Vector2, b: Vector2, trim: float, tint: Color, width: float) -> void:
		var dir := b - a
		var length := dir.length()
		if length <= trim * 2.0 + 1.0:
			return
		dir /= length
		a += dir * trim
		length -= trim * 2.0
		var art := UiSkin.tex("map_rope")
		if art != null:  # the tile, scaled to the rope's width, repeated down its length
			var s := width / art.get_width()
			ci.draw_set_transform(a, dir.angle() - PI / 2.0, Vector2(s, s))
			ci.draw_texture_rect(art, Rect2(-art.get_width() / 2.0, 0.0, art.get_width(), length / s), true, tint)
			ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
			return
		ci.draw_set_transform(a, dir.angle() - PI / 2.0, Vector2.ONE)  # (the rope runs along +y from here)
		ci.draw_rect(Rect2(-width / 2.0 - 1.5, 0.0, width + 3.0, length), Color(CORD_DARK, tint.a))  # (the outline)
		ci.draw_rect(Rect2(-width / 2.0, 0.0, width, length), CORD * tint)
		var step := width * 0.9
		var y := 0.0
		while y < length:  # the twist: slanted strands, a darker line and a lighter one on each
			var y2 := minf(length, y + step * 0.8)
			ci.draw_line(Vector2(-width / 2.0, y), Vector2(width / 2.0, y2), CORD_DARK * tint, 1.6)
			ci.draw_line(Vector2(-width / 2.0, y + step * 0.35), Vector2(width / 2.0, minf(length, y2 + step * 0.35)), CORD_LIGHT * tint, 1.4)
			y += step
		ci.draw_line(Vector2(-width / 2.0 + 0.8, 0.0), Vector2(-width / 2.0 + 0.8, length), Color(CORD_LIGHT, 0.35 * tint.a), 1.2)
		ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
