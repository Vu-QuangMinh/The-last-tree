class_name DiceStsMapView
extends Control
## Die on Stage (2026-11-17): the Slay the Spire map (DiceMapGen.make_sts), drawn like the chant game's: a parchment
## scroll, the painted room rings and icons (UiSkin "map_ring_*" / "map_icon_*"; plain circles with a symbol when the
## art is missing), ink dots between them. Bottom to top, the boss on top. A fight shows its dice mod on a little tag
## (🎲 +2, 🎨 a colour, 🔪 a carving); hover a room for what it holds. The rooms you can go to pulse with a gold halo.

signal chosen(r: int, c: int)
signal quit

const ROW_H := 132.0
const COL_W := 110.0
const SHEET := Rect2(500, 70, 920, 1000)
const INK := Color(0.28, 0.2, 0.12)
const ART := {"fight": "normal", "elite": "elite", "rest": "campfire", "treasure": "treasure", "shop": "merchant", "boss": "boss"}
const LOOK := {
	"fight": ["⚔", "Fight", Color(0.45, 0.36, 0.28), "A fight. Win it: a dice mod for good."],
	"elite": ["👹", "Mini boss", Color(0.75, 0.15, 0.12), "A tough fight. Win it: choose a move (1 of 3)."],
	"rest": ["🔥", "Campfire", Color(0.9, 0.5, 0.1), "Rest (heal 30% of your max HP), or upgrade a move."],
	"treasure": ["🎁", "Treasure", Color(0.85, 0.65, 0.1), "Choose a move (1 of 3)."],
	"shop": ["🛒", "Merchant", Color(0.2, 0.55, 0.3), "Moves, dice alterations, an artifact, a meal."],
	"boss": ["👑", "Boss", Color(0.55, 0.1, 0.35), "The act's boss. Win it: a rarer move, an artifact and a new die."],
}

var run: DiceRun
var _content: Control
var _scroll: ScrollContainer
var _picked := false


func setup(p_run: DiceRun) -> void:
	run = p_run


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.color = Color(0.1, 0.06, 0.04)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	var stage := PuppetStage.new(run.act)
	stage.modulate = Color(0.35, 0.3, 0.3)
	stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(stage)
	stage.fit(1920.0)
	var sheet := PanelContainer.new()
	var art := UiSkin.box("map_scroll", [0, 122, 0, 122], [40, 132, 40, 128])
	if art != null:
		sheet.add_theme_stylebox_override("panel", art)
	else:
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0.9, 0.83, 0.66)
		sb.border_color = Color(0.45, 0.32, 0.18)
		sb.set_border_width_all(4)
		sb.set_corner_radius_all(18)
		sb.set_content_margin_all(24)
		sheet.add_theme_stylebox_override("panel", sb)
	sheet.position = SHEET.position
	sheet.size = SHEET.size
	sheet.z_index = PuppetStage.CEILING_Z + 5  # (over the stage's valance)
	add_child(sheet)
	_scroll = ScrollContainer.new()
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	sheet.add_child(_scroll)
	_content = Control.new()
	_content.custom_minimum_size = Vector2(SHEET.size.x - 90.0, run.map.size() * ROW_H + 120.0)
	_content.draw.connect(_draw_paths)
	_scroll.add_child(_content)
	var choices: Array = run.options()
	for f in run.map.size():
		for n in run.map[f]:
			if n != null:
				_content.add_child(_room(f, n, choices))
	# you: HP, coins, dice, moves, artifacts (left); the menu (right)
	var y := 120.0
	for li in _head_lines().size():
		var head := UiTheme.label(_head_lines()[li], 26 if li == 0 else 19, Color(1.0, 0.9, 0.7))
		head.add_theme_constant_override("outline_size", 6)
		head.add_theme_color_override("font_outline_color", Color(0.1, 0.05, 0.02))
		head.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		head.size = Vector2(440, 0)
		head.position = Vector2(40, y)
		head.z_index = PuppetStage.CEILING_Z + 10
		add_child(head)
		y += 44.0 if li == 0 else 30.0 * (1 + _head_lines()[li].length() / 44)
	var back := UiTheme.button("Menu", func(): quit.emit(), 18)
	back.position = Vector2(1780, 120)
	back.z_index = PuppetStage.CEILING_Z + 10
	add_child(back)
	await get_tree().process_frame  # (the scroll knows its size now: show where you are)
	var at := _pos(maxi(run.row, 0), run.col).y
	_scroll.scroll_vertical = int(clampf(at - SHEET.size.y * 0.6, 0.0, _content.custom_minimum_size.y))


func _head_lines() -> Array:
	var faces := run.dice.map(func(d): return "[" + " ".join(d.map(func(f): return DiceFace.short(f))) + "]")
	var cards := []
	for ci in run.cards.size():
		cards.append(run.card_at(ci).name)
	var arts := run.artifacts.map(func(id): return DiceArtifacts.get_item(id).name)
	return ["Act %d    ❤ %d/%d    🪙 %d" % [run.act, run.hp, run.max_hp, run.leaves],
		"Dice: %s" % " ".join(faces), "Moves: %s" % ", ".join(cards),
		"Artifacts: %s" % (", ".join(arts) if not arts.is_empty() else "none")]


func _pos(f: int, c: int) -> Vector2:
	var rows := run.map.size()
	var x := _content.custom_minimum_size.x / 2.0 + (c - (DiceMapGen.COLS - 1) / 2.0) * COL_W
	var y := (rows - f) * ROW_H - 30.0
	if run.map[f][c] != null and run.map[f][c].type != "boss":  # (a little wobble, so it isn't a grid)
		x += sin(f * 3.1 + c * 1.7) * 20.0
		y += cos(f * 1.3 + c * 2.9) * 11.0
	return Vector2(x, y)


func _room(f: int, n: Dictionary, choices: Array) -> Control:
	var t: String = n.type
	var look: Array = LOOK.get(t, LOOK.fight)
	var sz := 108.0 if t == "boss" else 66.0
	var here: bool = f == run.row and n.col == run.col
	var can: bool = Vector2i(f, n.col) in choices
	var visited: bool = f < run.row or here
	var b := Button.new()
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(sz, sz)
	b.size = Vector2(sz, sz)
	b.position = _pos(f, n.col) - Vector2(sz, sz) / 2.0
	var tip := "%s\n%s" % [look[1], look[3]]
	if t == "fight" and n.has("dmod"):
		tip += "\n" + DiceGame.mod_words(n)
	b.tooltip_text = tip
	for state in ["normal", "hover", "pressed", "disabled"]:
		var st := StyleBoxFlat.new()
		st.set_corner_radius_all(int(sz / 2))
		st.bg_color = Color(0, 0, 0, 0)
		if can and state != "disabled":
			st.shadow_color = Color(1.0, 0.8, 0.2, 0.75 if state == "hover" else 0.5)
			st.shadow_size = 14
		b.add_theme_stylebox_override(state, st)
	var ring_name: String = "map_ring_" + str(ART.get(t, "normal"))
	var icon_name: String = "map_icon_" + str(ART.get(t, "normal"))
	if t == "shop" and UiSkin.tex("map_icon_merchant") == null:
		icon_name = "merchant_portrait"
	if here:
		ring_name = "map_ring_you_are_here"
		icon_name = "map_icon_you_are_here"
	elif visited:
		ring_name = "map_ring_visited"
		icon_name = ""
	var ring := UiSkin.icon(ring_name, sz)
	if ring != null:
		ring.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(ring)
		var icon: TextureRect = UiSkin.icon(icon_name, sz * (0.8 if here else 0.66)) if icon_name != "" else null
		if icon != null:
			icon.position = (Vector2(sz, sz) - icon.custom_minimum_size) / 2.0
			icon.size = icon.custom_minimum_size
			icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
			b.add_child(icon)
	else:  # (no art: a plain disc with the room's symbol)
		var disc := StyleBoxFlat.new()
		disc.set_corner_radius_all(int(sz / 2))
		disc.bg_color = Color(0.96, 0.9, 0.76)
		disc.border_color = Color(1, 0.8, 0.2) if can else look[2]
		disc.set_border_width_all(5)
		b.add_theme_stylebox_override("normal", disc)
		b.add_theme_stylebox_override("disabled", disc)
		b.text = "✦" if here else String(look[0])
		b.add_theme_font_size_override("font_size", 48 if t == "boss" else 28)
	if not can and not visited:
		b.modulate = Color(0.88, 0.86, 0.8)
	if t == "fight" and n.has("dmod") and not visited:  # (its dice mod, on a little tag under it)
		b.add_child(_mod_tag(n, sz))
	b.disabled = not can
	if can:
		b.pivot_offset = Vector2(sz, sz) / 2.0
		var tw := b.create_tween().set_loops()
		tw.tween_property(b, "scale", Vector2(1.12, 1.12), 0.55)
		tw.tween_property(b, "scale", Vector2.ONE, 0.55)
		var col: int = n.col
		b.pressed.connect(func():
			if _picked:
				return
			_picked = true
			Audio.play("map_node_select")
			chosen.emit(f, col))
	return b


func _mod_tag(n: Dictionary, sz: float) -> Control:
	var words := ""
	var col := Color.WHITE
	match String(n.dmod):
		"paint":
			words = "🎨"
			col = DiceFace.PAINTS[n.paint].col
		"carve":
			words = "🔪" + String(DiceFace.CARVES[n.carve].sym)
		_:
			words = "🎲%+d" % int(n.die_mod)
			col = Color(0.3, 0.75, 0.25) if int(n.die_mod) > 0 else Color(0.85, 0.3, 0.25)
	var tag := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.2, 0.13, 0.08, 0.92)
	sb.border_color = col
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(9)
	sb.set_content_margin_all(2)
	sb.content_margin_left = 6
	sb.content_margin_right = 6
	tag.add_theme_stylebox_override("panel", sb)
	var l := UiTheme.label(words, 15, Color.WHITE)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tag.add_child(l)
	tag.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tag.position = Vector2(sz * 0.42, sz * 0.62)
	return tag


func _draw_paths() -> void:
	var dot := UiSkin.tex("map_path_dot")
	for f in run.map.size() - 1:
		for n in run.map[f]:
			if n == null:
				continue
			for c in n.next:
				var from_here: bool = f == run.row and n.col == run.col
				var a := _pos(f, n.col)
				var b := _pos(f + 1, c)
				var steps := int(a.distance_to(b) / 14.0)
				for i in steps:
					if i < 3 or i > steps - 4:
						continue  # (room around the rings)
					var p := a.lerp(b, i / float(steps))
					if dot != null:
						var ds := 11.0 if from_here else 8.5
						_content.draw_texture_rect(dot, Rect2(p - Vector2(ds, ds) / 2.0, Vector2(ds, ds)), false, Color(0.55, 1.0, 0.45, 0.95) if from_here else Color(1, 1, 1, 0.7))
					else:
						_content.draw_circle(p, 3.2 if from_here else 2.6, INK.lerp(Color(0.2, 0.5, 0.15), 0.8) if from_here else Color(INK, 0.55))
