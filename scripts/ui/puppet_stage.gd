class_name PuppetStage
extends Control
## Wild-West puppet theatre: five flat pictures (back wall, floor, left and right wall, lower floor) are drawn as perspective quads,
## so the artwork stays flat and only the code tilts it. Wooden cut-outs (cloud, tree, sun) slide to and fro in front of the back wall,
## puppets (flat painted planks) stand on the floor; the ceiling (a valance) is not tilted at all, it is laid over the top of the screen on the
## highest z, and the front wall (upright too) hangs under the floor with the lower floor, tilted like the floor, below it. All geometry is in 1920 x 1080 design px.

const DIR := "res://assets/ui/puppet/"

const WALL_FRONT_H := 174.0  # the upright front wall under the floor's front edge
## The corners of the pieces are named points; pieces that touch share a point. Names ending in _l / _r are mirror images of each other.
## All in 1920 x 1080 design px: the scene's points are relative to the scene (lowered by SCENE_DY), the lower floor's (low_*) are absolute.
## (They were tuned by hand on the running game; tools/import_puppet_stage.py reads the back wall's numbers from here.)
static func default_verts() -> Dictionary:
	return {
		"top_l": Vector2(-92, -72), "top_r": Vector2(2012, -72),  # the side walls' outer top corners
		"back_top_l": Vector2(130, -126), "back_top_r": Vector2(1775, -126),
		"back_bot_l": Vector2(130, 410), "back_bot_r": Vector2(1775, 410),  # where the back wall meets the floor
		"front_l": Vector2(-92, 562), "front_r": Vector2(2012, 562),  # the floor's front edge
		"low_top_l": Vector2(4, 876), "low_top_r": Vector2(1916, 876),  # the lower floor
		"low_bot_l": Vector2(-190, 1080), "low_bot_r": Vector2(2110, 1080),
	}


## Each piece: its four corners, clockwise from the top left.
const QUADS := {
	"back_wall": ["back_top_l", "back_top_r", "back_bot_r", "back_bot_l"],
	"floor": ["back_bot_l", "back_bot_r", "front_r", "front_l"],
	"wall_left": ["top_l", "back_top_l", "back_bot_l", "front_l"],
	"wall_right": ["back_top_r", "top_r", "front_r", "back_bot_r"],
	"lower_floor": ["low_top_l", "low_top_r", "low_bot_r", "low_bot_l"],
}
const GRID := 24
## How much each picture is lit: a real stage is dim, the side walls and the ceiling most of all (the spotlights add the light back).
const TINT := {"back_wall": 0.80, "floor": 0.74, "lower_floor": 0.6, "wall_left": 0.5, "wall_right": 0.5}
const STAGE_H := 1080.0
## The whole stage (back wall, side walls, floor, front wall, scenery) stands SCENE_DY lower than the numbers above say, so that the bottom of
## the front wall touches the lower floor; the ceiling, the sign and the lower floor stay where they are.
const SCENE_DY := 148.0
const DESIGN_W := 1920.0
const CEILING_Z := 100

var _sprites: Array[Dictionary] = []
var _anchored: Array[Dictionary] = []  # scenery placed by rule: {node, frac, dy, extra}
var _t := 0.0
var _scene: Control  # everything that was shifted down by SCENE_DY
var _wall: TextureRect  # the upright front wall
var _ceiling: TextureRect  # the valance over the top of the screen
var _xs := 1.0  # sideways stretch of the props stations (set by fit)
var verts := {}  # point name -> Vector2 (see default_verts)
var _quads: Array[_Quad] = []


static func _load(path: String) -> Texture2D:
	if ResourceLoader.exists(path):
		return load(path) as Texture2D
	var img := Image.load_from_file(ProjectSettings.globalize_path(path))
	return ImageTexture.create_from_image(img) if img != null else null


static func _pic(name: String) -> Texture2D:
	return _load(DIR + name + ".png")


func _init() -> void:
	position = Vector2.ZERO
	size = Vector2(1920, STAGE_H)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = true
	_scene = Control.new()
	_scene.position = Vector2(0, SCENE_DY)
	_scene.size = Vector2(DESIGN_W, STAGE_H)
	_scene.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_scene)
	verts = default_verts()
	for qn in QUADS:  # (built first, so props and puppets added later draw over them)
		var layer := _Quad.new()
		layer.tex = _pic(String(qn))
		layer.names = QUADS[qn]
		var lit: float = TINT.get(qn, 1.0)
		layer.tint = Color(lit, lit, lit * 0.96)
		_quads.append(layer)
		if qn == "lower_floor":
			add_child(layer)  # (it does not move: it is below the scene, absolute)
		else:
			_scene.add_child(layer)
	_wall = TextureRect.new()  # the front wall: upright, as it is, from the floor's front edge down
	_wall.texture = _pic("front_wall")
	_wall.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_wall.stretch_mode = TextureRect.STRETCH_SCALE
	_wall.position = Vector2(0, _front_y())
	_wall.size = Vector2(DESIGN_W, WALL_FRONT_H)
	_wall.modulate = Color(0.8, 0.8, 0.78)
	_wall.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_scene.add_child(_wall)
	_ceiling = TextureRect.new()  # the ceiling: its own picture, as it is, over everything (the HUD text is raised above it)
	_ceiling.texture = _pic("ceiling_overlay")
	_ceiling.stretch_mode = TextureRect.STRETCH_TILE
	_ceiling.size = Vector2(DESIGN_W, _ceiling.texture.get_height())
	_ceiling.position = Vector2.ZERO
	_ceiling.z_index = CEILING_Z
	_ceiling.modulate = Color(0.86, 0.86, 0.86)
	_ceiling.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_ceiling)
	_refresh_quads()


## A wooden cut-out that stands at `pos` (its feet), `height` px tall, swaying on its base; `slide` is how far it travels left and
## right on its rail.
func add_prop(file: String, pos: Vector2, height: float, slide: float, speed: float, phase := 0.0, sway := 0.02, lit := 0.86, shadow := 0.0) -> Sprite2D:
	var sp := Sprite2D.new()
	sp.texture = _pic(file)
	sp.centered = false
	sp.offset = Vector2(-sp.texture.get_width() / 2.0, -sp.texture.get_height())
	sp.scale = Vector2.ONE * (height / float(sp.texture.get_height()))
	sp.position = pos
	sp.modulate = Color(lit, lit, lit * 0.96)
	if shadow > 0.0:  # the shadow it throws on the backdrop behind it: its own silhouette, a little lower and to the right
		var sh := Sprite2D.new()
		sh.texture = sp.texture
		sh.centered = false
		sh.offset = sp.offset
		sh.show_behind_parent = true
		sh.self_modulate = Color(0, 0, 0, shadow)
		sh.position = Vector2(18.0, 9.0) / sp.scale.x
		sp.add_child(sh)
	_scene.add_child(sp)
	_sprites.append({"node": sp, "x": pos.x, "slide": slide, "speed": speed, "phase": phase, "sway": sway})
	return sp


## Stretch the whole stage sideways to a screen that is wider than 1920 (the pictures are only tilted by code, so any width works).
func fit(width: float) -> void:
	width = maxf(width, DESIGN_W)
	_xs = width / DESIGN_W
	if _ceiling != null:
		_ceiling.size.x = width  # (a wider screen just repeats the picture)
	size = Vector2(width, STAGE_H)
	if _wall != null:
		_wall.size.x = width
	_scene.size.x = width
	for q in _quads:
		q.x_scale = _xs
		q.queue_redraw()


## The wooden scenery in front of the back wall: far mountains stand still, clouds, sun and trees slide on rails and rock a little.
func add_default_props() -> void:
	# every piece is placed by rule (see _place_props): `frac` is how far across the back wall it stands (0 = its left edge, 1 = its right
	# edge, the piece itself always staying inside the wall), `dy` how far below the seam between the back wall and the floor its feet are
	# (negative: above it, for the sky)
	for m in [["mountain_3", 0.12, 125.0], ["mountain_4", 0.32, 150.0], ["mountain_5", 0.55, 175.0], ["mountain_1", 0.86, 165.0]]:
		_add_anchored("props/" + m[0], m[1], 0.0, m[2], 0.0, 1.0, 0.0, 0.0, 0.78, 0.0)
	_add_anchored("props/cloud_1", 0.17, -237.0, 90.0, 45, 0.45, 0.0, 0.02, 0.9, 0.28)
	_add_anchored("props/cloud_3", 0.62, -262.0, 100.0, 55, 0.35, 2.0, 0.02, 0.9, 0.28)
	_add_anchored("props/cloud_2", 0.94, -277.0, 70.0, 40, 0.5, 4.0, 0.02, 0.9, 0.28)
	_add_anchored("props/sun", 0.78, -190.0, 130.0, 20, 0.3, 1.0, 0.03, 1.0, 0.18)
	# the trees stand on the seam between the floor and the backdrop and rock on their trunks, like the puppets
	var trees := [["tree_1", 0.0, 270.0, 0.9, 0.0, 0.04], ["tree_2", 0.27, 230.0, 1.1, 1.0, 0.045], ["tree_3", 0.5, 210.0, 1.0, 5.0, 0.04],
		["tree_4", 0.77, 260.0, 0.8, 3.0, 0.04], ["tree_5", 1.0, 220.0, 1.0, 2.0, 0.045]]
	for t in trees:
		_add_anchored("props/" + t[0], t[1], 6.0, t[2], 0.0, t[3], t[4], t[5], 0.84, 0.3)
	# tufts of grass on the ground along the same seam, swaying a little
	var bushes := [[0.0, 1, 60.0], [0.14, 4, 54.0], [0.35, 2, 66.0], [0.55, 6, 52.0], [0.6, 3, 62.0], [0.79, 5, 56.0], [0.86, 1, 50.0], [1.0, 2, 64.0]]
	for i in bushes.size():
		var bu: Array = bushes[i]
		_add_anchored("props/bush_%d" % bu[1], bu[0], 12.0 + (i % 3) * 5.0, bu[2], 0.0, 1.2 + (i % 4) * 0.2, i * 1.3, 0.05, 0.86, 0.22)
	_place_props()


func _add_anchored(file: String, frac: float, dy: float, height: float, slide: float, speed: float, phase: float, sway: float, lit: float, shadow: float) -> void:
	var sp := add_prop(file, Vector2.ZERO, height, slide, speed, phase, sway, lit, shadow)
	# the room this piece needs at its sides: its half width, how far it slides, its shadow (to the right), how far it leans
	var half := sp.texture.get_width() * sp.scale.x / 2.0
	var extra := slide + (18.0 if shadow > 0.0 else 0.0) + height * sway
	_anchored.append({"node": sp, "frac": frac, "dy": dy, "half": half, "extra": extra})


## The seam between the back wall and the floor, and the back wall's left and right edges (scene coordinates).
func _seam() -> Dictionary:
	var bl: Vector2 = verts["back_bot_l"]
	var br: Vector2 = verts["back_bot_r"]
	return {"y": (bl.y + br.y) / 2.0, "l": bl.x, "r": br.x}


## Put the scenery by rule: feet on the seam (plus its dy), always between the back wall's two edges.
func _place_props() -> void:
	var sm := _seam()
	for a in _anchored:
		var lo: float = float(sm.l) + float(a.half) + float(a.extra)
		var hi: float = float(sm.r) - float(a.half) - float(a.extra)
		var x := (lo + hi) / 2.0 if lo > hi else lerpf(lo, hi, float(a.frac))
		var sp: Sprite2D = a.node
		sp.position = Vector2(x, float(sm.y) + float(a.dy))
		for e in _sprites:
			if e.node == sp:
				e.x = x


## The y (on screen) of the middle of the floor: the enemies stand there.
func floor_center_y() -> float:
	var bl: Vector2 = verts["back_bot_l"]
	var br: Vector2 = verts["back_bot_r"]
	return (bl.y + br.y + verts["front_l"].y + verts["front_r"].y) / 4.0 + SCENE_DY


## The hanging sign: it hangs from the ceiling on its chains (their tops are under the valance), `height` px tall, and swings a hair.
func add_hanging_sign(center_x: float, height: float) -> Sprite2D:
	var sp := Sprite2D.new()
	sp.texture = _pic("props/hanging_sign")
	sp.centered = false
	sp.offset = Vector2(-sp.texture.get_width() / 2.0, 0)
	sp.scale = Vector2.ONE * (height / float(sp.texture.get_height()))
	sp.position = Vector2(center_x, -6.0)
	sp.modulate = Color(0.92, 0.92, 0.92)
	sp.z_index = 5
	add_child(sp)
	_sprites.append({"node": sp, "x": center_x, "slide": 0.0, "speed": 1.1, "phase": 0.7, "sway": 0.006})
	return sp


func _front_y() -> float:
	var l: Vector2 = verts["front_l"]
	var r: Vector2 = verts["front_r"]
	return (l.y + r.y) / 2.0


func _refresh_quads() -> void:
	for q in _quads:
		var c: Array = []
		for n in q.names:
			c.append(verts[n])
		q.corners = c
		q.queue_redraw()
	if _wall != null:
		_wall.position.y = _front_y()
	_place_props()


func _process(d: float) -> void:
	_t += d
	for s in _sprites:
		var sp: Sprite2D = s["node"]
		var w := sin(_t * float(s["speed"]) + float(s["phase"]))
		sp.position.x = float(s["x"]) * _xs + w * float(s["slide"])
		sp.rotation = w * float(s["sway"])


## One flat picture drawn onto a perspective quad (grid-subdivided so the texture bends correctly).
class _Quad extends Control:
	var tex: Texture2D
	var names: Array = []  # the four corner names, looked up in the stage's verts
	var corners: Array = []
	var x_scale := 1.0
	var tint := Color.WHITE

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	func _draw() -> void:
		if tex == null:
			return
		var h := _homography()
		var n := PuppetStage.GRID
		for iy in n:
			for ix in n:
				var uv := [Vector2(ix, iy), Vector2(ix + 1, iy), Vector2(ix + 1, iy + 1), Vector2(ix, iy + 1)]
				var pts := PackedVector2Array()
				var uvs := PackedVector2Array()
				for c in uv:
					var u: Vector2 = c / float(n)
					pts.append(_map(h, u))
					uvs.append(u)
				draw_polygon(pts, PackedColorArray([tint, tint, tint, tint]), uvs, tex)

	## unit square -> quad (Heckbert)
	func _homography() -> Array:
		var p: Array = []
		for c in corners:
			p.append(Vector2(c.x * x_scale, c.y))
		var x0: float = p[0].x
		var y0: float = p[0].y
		var x1: float = p[1].x
		var y1: float = p[1].y
		var x2: float = p[2].x
		var y2: float = p[2].y
		var x3: float = p[3].x
		var y3: float = p[3].y
		var dx1 := x1 - x2
		var dx2 := x3 - x2
		var dy1 := y1 - y2
		var dy2 := y3 - y2
		var sx := x0 - x1 + x2 - x3
		var sy := y0 - y1 + y2 - y3
		var g := 0.0
		var hh := 0.0
		if absf(sx) > 0.0001 or absf(sy) > 0.0001:
			var den := dx1 * dy2 - dx2 * dy1
			g = (sx * dy2 - dx2 * sy) / den
			hh = (dx1 * sy - sx * dy1) / den
		return [x1 - x0 + g * x1, x3 - x0 + hh * x3, x0, y1 - y0 + g * y1, y3 - y0 + hh * y3, y0, g, hh]

	func _map(h: Array, u: Vector2) -> Vector2:
		var w: float = float(h[6]) * u.x + float(h[7]) * u.y + 1.0
		return Vector2((float(h[0]) * u.x + float(h[1]) * u.y + float(h[2])) / w, (float(h[3]) * u.x + float(h[4]) * u.y + float(h[5])) / w)
