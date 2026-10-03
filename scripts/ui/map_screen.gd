class_name MapScreen
extends Control
## The act's map on a parchment scroll, Slay the Spire style: rooms on a 7-column grid, dotted paths between them,
## the boss at the top. Scroll with the mouse wheel; click a glowing room to go there.

signal node_chosen(col: int)
signal codex_pressed

## type -> [icon, name, ring colour, description]
const LOOK := {
	"fight": ["⚔", "Fight", Color(0.45, 0.36, 0.28), "A normal fight. Rewards: a spell (70% Common, 30% Rare) and Leaves."],
	"elite": ["👹", "Elite", Color(0.75, 0.15, 0.12), "A tough fight. Rewards: a Rare spell, an artifact and more Leaves."],
	"rest": ["🔥", "Campfire", Color(0.9, 0.5, 0.1), "Rest (heal 30%) or upgrade a spell."],
	"treasure": ["🎁", "Treasure", Color(0.85, 0.65, 0.1), "Pick an artifact. One of them is cursed."],
	"shop": ["🛒", "Merchant", Color(0.2, 0.55, 0.3), "Spend Leaves on spells, artifacts, an upgrade or a meal."],
	"event": ["❓", "Unknown", Color(0.45, 0.3, 0.65), "Usually a strange encounter with choices; sometimes a fight, a merchant or treasure."],
	"boss": ["👑", "Boss", Color(0.55, 0.1, 0.35), "The guardian of this act."],
}
const ROW_H := 96.0
const COL_W := 138.0
const INK := Color(0.28, 0.2, 0.12)

var run: RunState
var _content: Control
var _scroll: ScrollContainer
var sheet: PanelContainer  # the parchment (the tutorial points at it)
var legend: VBoxContainer


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
	sheet.add_theme_stylebox_override("panel", sb)
	sheet.position = Vector2(420, 66)
	sheet.size = Vector2(1080, 1000)
	add_child(sheet)
	_scroll = ScrollContainer.new()
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	sheet.add_child(_scroll)
	_content = Control.new()
	var rows := run.map.size()
	_content.custom_minimum_size = Vector2(1060, rows * ROW_H + 140)
	_content.draw.connect(_draw_paths)
	_scroll.add_child(_content)
	var choices := run.choices()
	for f in rows:
		for n in run.map[f]:
			if n == null:
				continue
			_content.add_child(_node_button(f, n, choices))
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
	var y := _pos(maxi(0, run.row), 0).y
	_scroll.scroll_vertical = int(clampf(y - 700, 0, _content.custom_minimum_size.y))


func _legend_row(t: String, count: int) -> Control:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", UiTheme.panel_box(0.8, 10))
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 10)
	p.add_child(h)
	var icon := UiTheme.label(LOOK[t][0], 26, Color.WHITE)
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
	var x := 530.0 + (c - (MapGen.COLS - 1) / 2.0) * COL_W
	# a little wobble so it doesn't look like a grid
	if run.map[f].size() > c and run.map[f][c] != null and run.map[f][c].type != "boss":
		x += sin(f * 3.1 + c * 1.7) * 22.0
		y += cos(f * 1.3 + c * 2.9) * 12.0
	return Vector2(x, y)


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
	b.tooltip_text = "%s\n%s" % [look[1], look[3]]
	var here: bool = f == run.row and n.col == run.col
	var can: bool = f == run.row + 1 and n.col in choices
	var visited: bool = f < run.row or here
	for state in ["normal", "hover", "pressed", "disabled"]:
		var st := StyleBoxFlat.new()
		st.set_corner_radius_all(int(sz / 2))
		st.bg_color = Color(0.96, 0.9, 0.76) if state != "hover" else Color(1, 0.97, 0.85)
		st.border_color = look[2] if not can else Color(1, 0.8, 0.2)
		st.set_border_width_all(6 if can else 4)
		if state == "disabled":
			st.bg_color = Color(0.86, 0.79, 0.63)
		b.add_theme_stylebox_override(state, st)
	b.disabled = not can
	if visited:
		b.modulate = Color(0.75, 0.75, 0.75, 0.75)
	if here:
		b.modulate = Color(0.7, 1, 0.7, 1)
		b.text = "✦"
		b.add_theme_color_override("font_disabled_color", Color(0.1, 0.5, 0.1))
	if can:
		b.pivot_offset = Vector2(sz, sz) / 2.0
		var tw := b.create_tween().set_loops()
		tw.tween_property(b, "scale", Vector2(1.12, 1.12), 0.55)
		tw.tween_property(b, "scale", Vector2.ONE, 0.55)
		var col: int = n.col
		b.pressed.connect(func():
			Audio.play("map_node_select")
			node_chosen.emit(col))
	return b


func _draw_paths() -> void:
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
					var p := a.lerp(b, i / float(steps))
					_content.draw_circle(p, 3.2 if from_here else 2.6, col)
