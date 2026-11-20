class_name DiceMapView
extends Control
## Die on Stage (2026-11-16): the hex map (DiceMapGen.make_zoned). Tiles show rewards, not difficulty (enemies get
## harder the more moves you make: the top line says how hard they are now). (Old: tinted by zone, green easy,
## amber mid, red hard: patches all over the map, a key at the top right). Wooden hexagons. A fight with a bonus has it written on its tile:
## a die change (+1 / -1), a card, an artifact (those two are a mini boss or a double encounter). The tiles you can go to
## (forward only) have a gold rim. The boss stands at the far right; after DiceMapGen.BOSS_SPEED_EVERY moves it walks toward
## you, and when it reaches you its fight starts. Nothing ahead: "Wait for the boss".

signal chosen(r: int, c: int)
signal waited
signal quit

const HEX_R := 62.0
const LEVEL_W := HEX_R * 0.8660254
const LANE_H := HEX_R * 1.5
const HEX_WOOD := Color(0.6, 0.43, 0.27)
const ZONE_TINT := [Color(0.45, 0.62, 0.32), Color(0.85, 0.62, 0.2), Color(0.75, 0.2, 0.15)]
const ZONE_NAMES := ["Easy", "Medium", "Hard"]
const LOOK := {
	"fight": ["⚔", Color(0.45, 0.36, 0.28), "A fight: win a few coins."],
	"shop": ["🛒", Color(0.2, 0.55, 0.3), "The Merchant: moves, dice alterations, an artifact, a meal."],
	"rest": ["🔥", Color(0.9, 0.5, 0.1), "A campfire: rest (heal 30% of your max HP), or upgrade a move."],
	"event": ["❓", Color(0.45, 0.3, 0.6), "Something is happening here: a story, with choices."],
	"haste": ["»»", Color(0.55, 0.8, 0.85), "Haste: a free step. No fight, the move isn't counted, and the boss doesn't move."],
	"whirlpool": ["🌀", Color(0.2, 0.45, 0.8), "A whirlpool: dive in to come out at the other one (linked by the dotted line)."],
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
	# how hard the fights are now (top right): it grows with your moves
	var tier := DiceMapGen.fight_tier(run.turns + 1)
	var nxt := ""
	if tier + 1 < DiceMapGen.TIER_FROM_MOVE.size():
		var left: int = DiceMapGen.TIER_FROM_MOVE[tier + 1] - (run.turns + 1)
		nxt = "  (%s after %d more move%s)" % [ZONE_NAMES[tier + 1], left, "" if left == 1 else "s"] if left > 0 else "  (%s next move)" % ZONE_NAMES[tier + 1]
	var zl := _text("Enemies: %s%s" % [ZONE_NAMES[tier], nxt], 24, ZONE_TINT[tier].lightened(0.35))
	zl.position = Vector2(1300, 200)
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
			icon.position = at - Vector2(40, 34 if b != "" or n.type == "fight" else 25)
			var sub := ""
			var sub_col := Color.WHITE
			match b:
				"":  # (a plain fight: just coins)
					if n.type == "fight":
						sub = "🪙"
						sub_col = Color(1.0, 0.9, 0.5)
				"dice":  # (just a die: which mod it is, you see when you win it, 2026-11-17)
					sub = "🎲"
					sub_col = Color(1.0, 0.95, 0.8)
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
	var boss := "The boss starts moving in %d move%s" % [w, "" if w == 1 else "s"] if w > 0 else "The boss is coming for you! (%d tile%s a move, faster every %d moves)" % [maxi(1, run.boss_speed()), "" if run.boss_speed() <= 1 else "s", DiceMapGen.BOSS_SPEED_EVERY]
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
			var fill: Color = HEX_WOOD
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
	# the whirlpools: a dotted line between the pair
	for f in run.map.size():
		for n in run.map[f]:
			if n.type == "whirlpool" and n.has("link") and f < int(n.link[0]):
				cv.draw_dashed_line(_pos(f, n.col), _pos(int(n.link[0]), int(n.link[1])), Color(0.5, 0.8, 1.0, 0.75), 4.0, 14.0)
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
				var words: String = String(LOOK.get(n.type, LOOK.fight)[2])
				if n.type == "whirlpool":
					words += " It costs %d HP now, and 5 more each time." % run.whirl_cost()
				var b: String = n.get("bonus", "")
				if b != "":
					if b in ["card", "artifact"]:
						words += " A mini boss." if n.get("fight", "") == "elite" else " Two hard encounters at once."
					words += "  " + ("Win it: a dice mod (an adjustment, a painting or a carving; you see which when you win; the further right, the better)." if b == "dice" else BONUS_WORDS[b])
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
