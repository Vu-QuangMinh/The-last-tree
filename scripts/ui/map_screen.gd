class_name MapScreen
extends Control
## The act's map on a parchment scroll, Slay the Spire style: rooms on a 7-column grid, dotted paths between them,
## the boss at the top. Scroll with the mouse wheel; click a glowing room to go there.

signal node_chosen(col: int)
signal codex_pressed
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
## New theme: room type -> the painted ring / icon names (assets/ui/new/map_ring_<x>.png, map_icon_<x>.png)
const ART := {"fight": "normal", "elite": "elite", "rest": "campfire", "treasure": "treasure", "shop": "merchant", "event": "unknown", "boss": "boss"}
const ROW_H := 168.0  # (96 * 1.75: the map was stretched taller)
const COL_W := 138.0
const INK := Color(0.28, 0.2, 0.12)

var run: RunState
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


func setup(p_run: RunState) -> void:
	run = p_run


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = UiTheme.get_theme()
	var bd := Backdrop.new()
	bd.act = run.act
	add_child(bd)
	var shade := ColorRect.new()
	shade.color = Color(0, 0, 0, 0.45)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shade)
	# the parchment scroll
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
	_content = Control.new()
	var rows := run.map.size()
	_content.custom_minimum_size = Vector2(_map_w, rows * ROW_H + 140)
	_content.draw.connect(_draw_paths)
	_scroll.add_child(_content)
	var choices := run.choices()
	for f in rows:
		for n in run.map[f]:
			if n == null:
				continue
			var nb := _node_button(f, n, choices)
			_buttons[Vector2i(f, n.col)] = nb
			_content.add_child(nb)
	# left: title and legend
	var left := VBoxContainer.new()
	legend = left
	left.position = Vector2(30, 80)
	left.size = Vector2(370, 900)
	left.add_theme_constant_override("separation", 10)
	add_child(left)
	var title := UiTheme.label(["", "Act I", "Act II", "Act III"][run.act], 40, Color.WHITE)
	left.add_child(title)
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
	add_child(tip)
	# start with your position in view (the bottom of the map at the start of an act)
	await get_tree().process_frame
	await get_tree().process_frame  # (the scroll area has its real size only now)
	# your room always in view, a little below the middle so the rooms ahead show above it
	var py := _pos(maxi(0, run.row), maxi(0, run.col)).y
	var view_h := _scroll.size.y
	_scroll.scroll_vertical = int(clampf(py - view_h * 0.58, 0.0, maxf(0.0, _content.custom_minimum_size.y - view_h)))
	# ☰ Menu (bottom right, as in fights): Resume, Settings, Main Menu, Quit. The run is saved on the map.
	var menu_btn := UiTheme.button("☰ Menu", _open_pause_menu, 18)
	menu_btn.custom_minimum_size = Vector2(130, 44)
	menu_btn.position = Vector2(1920 - 150, 1024)
	UiTheme.use_menu_style(menu_btn)
	UiTheme.use_heading_font(menu_btn)
	add_child(menu_btn)


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


func _pos(f: int, c: int) -> Vector2:
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
	var here: bool = f == run.row and n.col == run.col
	var can: bool = f == run.row + 1 and n.col in choices
	var visited: bool = f < run.row or here
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
			b.modulate = Color(1, 1, 1, 0.85)
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
	if here_btn != null:
		here_btn.visible = false  # the marker leaves it
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
		if walk_edge:
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
				var walked: bool = f < run.row and run.map[f + 1][c] != null
				var from_here: bool = f == run.row and n.col == run.col
				var col := INK.lerp(Color(0.2, 0.5, 0.15), 0.8) if from_here else Color(INK, 0.55)
				var a := _pos(f, n.col)
				var b := _pos(f + 1, c)
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
