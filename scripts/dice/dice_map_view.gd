class_name DiceMapView
extends Control
## Die on Stage (2026-11-16): the zoned hex map (DiceMapGen.make_zoned). Left to right: the easy, mid and hard zones,
## each with its name over it. Wooden hexagons; hollow tiles are holes. A fight with a bonus has it written on its tile:
## a die change (+1 / -1), a card, an artifact (those two are a mini boss or a double encounter). The tiles you can go to
## (forward only) have a gold rim. The boss stands at the far right; after DiceMapGen.BOSS_WAIT moves it walks toward
## you, and when it reaches you its fight starts. Nothing ahead: "Wait for the boss".

signal chosen(r: int, c: int)
signal waited
signal quit

const HEX_R := 62.0
const LEVEL_W := HEX_R * 0.8660254
const LANE_H := HEX_R * 1.5
const HEX_WOOD := Color(0.6, 0.43, 0.27)
const ZONE_TINT := [Color(0.45, 0.62, 0.32), Color(0.85, 0.62, 0.2), Color(0.75, 0.2, 0.15)]
const ZONE_NAMES := ["Easy", "Mid", "Hard"]
const LOOK := {
	"fight": ["⚔", Color(0.45, 0.36, 0.28), "A fight."],
	"shop": ["🛒", Color(0.2, 0.55, 0.3), "The Merchant: moves, dice alterations, an artifact, a meal."],
	"rest": ["🔥", Color(0.9, 0.5, 0.1), "A campfire: rest (heal 30% of your max HP), or upgrade a move."],
}
const BONUS_WORDS := {
	"card": "Win it: choose a move (1 of 3).",
	"artifact": "Win it: choose an artifact (1 of 3).",
}

var run: DiceRun
var _cx := 960.0
var _cy := 640.0
var _hover := Vector2i(-1, -1)
var _info: Label
var _board: Control


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
	_board = Control.new()
	_board.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_board.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_board.draw.connect(_draw_board)
	add_child(_board)
	# the zones' names over the map
	for z in DiceMapGen.ZONES.size():
		var lo: int = DiceMapGen.ZONES[z]
		var hi: int = (DiceMapGen.ZONES[z + 1] - 1) if z + 1 < DiceMapGen.ZONES.size() else run.map.size() - 1
		var x := (_cell_pos(Vector2i(lo, 3)).x + _cell_pos(Vector2i(hi, 3)).x) / 2.0
		var zl := _text(ZONE_NAMES[z], 30, ZONE_TINT[z].lightened(0.3))
		zl.size = Vector2(300, 40)
		zl.position = Vector2(x - 150.0, _cy - 3.6 * LANE_H - 40.0)
		zl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	# the tiles' marks
	for f in run.map.size():
		for n in run.map[f]:
			if n.type == "hollow":
				continue
			var at := _pos(f, n.col)
			var b: String = n.get("bonus", "")
			var main: String = LOOK.get(n.type, LOOK.fight)[0]
			if b == "card":
				main = "🃏"
			elif b == "artifact":
				main = "💎"
			var icon := _text(main, 30, Color.WHITE)
			icon.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			icon.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			icon.size = Vector2(80, 50)
			icon.position = at - Vector2(40, 34 if b != "" else 25)
			var sub := ""
			var sub_col := Color.WHITE
			match b:
				"dice":
					match String(n.get("dmod", "adjust")):
						"paint":
							sub = "🎨"
							sub_col = DiceFace.PAINTS[n.paint].col.lightened(0.25)
						"carve":
							sub = "🔪" + String(DiceFace.CARVES[n.carve].sym)
							sub_col = Color(1.0, 0.9, 0.6)
						_:
							sub = "🎲%+d" % int(n.die_mod)
							sub_col = Color(0.55, 1.0, 0.5) if int(n.die_mod) > 0 else Color(1.0, 0.55, 0.45)
				"card", "artifact":
					sub = "👹" if n.get("fight", "") == "elite" else "⚔⚔"
					sub_col = Color(1.0, 0.7, 0.6)
			if sub != "":
				var dm := _text(sub, 20, sub_col)
				dm.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
				dm.size = Vector2(90, 30)
				dm.position = at + Vector2(-45, 6)
	var y := 140.0
	for li in _head_lines().size():
		var head := _text(_head_lines()[li], 26 if li == 0 else 21, Color(1.0, 0.9, 0.7))
		head.position = Vector2(40, y)
		y += 36.0 if li == 0 else 30.0
	_info = _text("Choose a tile with a gold rim.", 22, Color(0.95, 0.85, 0.7))
	_info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_info.size = Vector2(1920, 40)
	_info.position = Vector2(0, 1020)
	var back := UiTheme.button("Menu", func(): quit.emit(), 18)
	back.position = Vector2(1780, 140)
	back.z_index = PuppetStage.CEILING_Z + 10
	add_child(back)
	if run.options().is_empty() and not run.caught():
		var wait := UiTheme.button("Wait for the boss", func(): waited.emit(), 22)
		wait.custom_minimum_size = Vector2(300, 60)
		wait.position = Vector2(810, 940)
		wait.z_index = PuppetStage.CEILING_Z + 10
		add_child(wait)
		_info.text = "Nothing ahead of you: wait for the boss."


func _text(t: String, px: int, col: Color) -> Label:
	var l := UiTheme.label(t, px, col)
	l.add_theme_constant_override("outline_size", 6)
	l.add_theme_color_override("font_outline_color", Color(0.1, 0.05, 0.02))
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.z_index = PuppetStage.CEILING_Z + 10  # (over the stage's valance)
	add_child(l)
	return l


func _head_lines() -> Array:
	var faces := run.dice.map(func(d): return "[" + "  ".join(d.map(func(f): return DiceFace.short(f))) + "]")
	var cards := []
	for ci in run.cards.size():
		cards.append(run.card_at(ci).name)
	var arts := run.artifacts.map(func(id): return DiceArtifacts.get_item(id).name)
	var w := run.boss_wait()
	var boss := "The boss starts moving in %d move%s" % [w, "" if w == 1 else "s"] if w > 0 else "The boss is coming for you!"
	return ["Die on Stage · Act %d    ❤ %d/%d    🪙 %d coins    %s" % [run.act, run.hp, run.max_hp, run.leaves, boss],
		"Dice: %s" % "  ".join(faces), "Moves: %s" % ", ".join(cards),
		"Artifacts: %s" % (", ".join(arts) if not arts.is_empty() else "none")]


## The middle of the tile at Vector2i(level, lane).
func _cell_pos(cell: Vector2i) -> Vector2:
	var rows := run.map.size()
	return Vector2(_cx + (cell.x - rows / 2.0) * LEVEL_W, _cy + float(cell.y - DiceMapGen.C_LANES / 2) * LANE_H)


func _pos(f: int, c: int) -> Vector2:
	return _cell_pos(Vector2i(f, int(run.map[f][c].lane)))


func _hex_points(c: Vector2, r: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in 6:
		var a := deg_to_rad(60.0 * i - 90.0)
		pts.append(c + Vector2(cos(a), sin(a)) * r)
	return pts


func _draw_board() -> void:
	var cv := _board
	var opts: Array = run.options()
	for f in run.map.size():
		for n in run.map[f]:
			var at := _pos(f, n.col)
			if n.type == "hollow":
				cv.draw_colored_polygon(_hex_points(at, HEX_R - 14.0), Color(0, 0, 0, 0.35))  # (a hole: no tile)
				continue
			var here: bool = f == run.row and n.col == run.col
			var can: bool = Vector2i(f, n.col) in opts
			var stood: bool = here or ("%d:%d" % [f, n.col]) in run.visited
			var behind: bool = not stood and f <= run.row
			var fill: Color = HEX_WOOD.lerp(ZONE_TINT[DiceMapGen.zone_of(f)], 0.18)
			fill = fill.lerp(LOOK.get(n.type, LOOK.fight)[1], 0.25)
			match String(n.get("bonus", "")):
				"card":
					fill = fill.lerp(Color(0.35, 0.45, 0.9), 0.35)
				"artifact":
					fill = fill.lerp(Color(0.85, 0.7, 0.2), 0.4)
			if can:
				fill = fill.lightened(0.28 if Vector2i(f, n.col) != _hover else 0.45)
			elif here:
				fill = Color(0.45, 0.62, 0.32)
			elif stood:
				fill = fill.lerp(Color(0.85, 0.8, 0.7), 0.45)
			elif behind:
				fill = fill.lerp(Color(0.25, 0.22, 0.2), 0.55)
			var outer := _hex_points(at, HEX_R - 2.0)
			cv.draw_colored_polygon(outer, fill.darkened(0.35))
			cv.draw_colored_polygon(_hex_points(at, HEX_R - 10.0), fill)
			var rim := Color(0.22, 0.13, 0.06)
			var rim_w := 3.0
			if can:
				rim = Color(1.0, 0.82, 0.25)
				rim_w = 7.0
			elif here:
				rim = Color(0.75, 1.0, 0.55)
				rim_w = 6.0
			outer.append(outer[0])
			cv.draw_polyline(outer, rim, rim_w, true)
	# the boss: a crimson hexagon with its crown, where it stands now
	var bp := _cell_pos(run.boss)
	var bh := _hex_points(bp, HEX_R * 1.05)
	cv.draw_colored_polygon(bh, Color(0.42, 0.08, 0.16))
	bh.append(bh[0])
	cv.draw_polyline(bh, Color(1.0, 0.75, 0.3), 5.0, true)
	var font: Font = ThemeDB.fallback_font
	cv.draw_string(font, bp + Vector2(-30, 16), "👑", HORIZONTAL_ALIGNMENT_CENTER, 60, 44)
	# you
	if run.row >= 0:
		var me := _pos(run.row, run.col)
		cv.draw_circle(me + Vector2(0, -HEX_R * 0.55), 12.0, Color(0.95, 0.95, 0.85))
		cv.draw_arc(me + Vector2(0, -HEX_R * 0.55), 12.0, 0, TAU, 20, Color(0.1, 0.05, 0.02), 3.0)


func _tile_at(p: Vector2) -> Vector2i:
	for f in run.map.size():
		for n in run.map[f]:
			if n.type != "hollow" and _pos(f, n.col).distance_to(p) < HEX_R * 0.85:
				return Vector2i(f, n.col)
	return Vector2i(-1, -1)


func _gui_input(ev: InputEvent) -> void:
	if ev is InputEventMouseMotion:
		var t := _tile_at(ev.position)
		if t != _hover:
			_hover = t
			_board.queue_redraw()
			if t.x >= 0:
				var n: Dictionary = run.map[t.x][t.y]
				var words: String = "%s zone. " % ZONE_NAMES[DiceMapGen.zone_of(t.x)] + String(LOOK.get(n.type, LOOK.fight)[2])
				var b: String = n.get("bonus", "")
				if b != "":
					if b in ["card", "artifact"]:
						words += " A mini boss." if n.get("fight", "") == "elite" else " Two hard encounters at once."
					words += "  " + ("Win it: your dice are rolled, and the face that shows gets it for good. " + DiceGame.mod_words(n) if b == "dice" else BONUS_WORDS[b])
				if Vector2i(t.x, int(n.lane)) == run.boss:
					words = "The boss is here: stepping on it starts its fight."
				_info.text = words
			elif not run.options().is_empty():
				_info.text = "Choose a tile with a gold rim."
	elif ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
		var t := _tile_at(ev.position)
		if t.x >= 0 and t in run.options():
			Audio.play("ui_click")
			chosen.emit(t.x, t.y)
