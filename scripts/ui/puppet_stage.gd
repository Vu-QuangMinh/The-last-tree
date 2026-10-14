class_name PuppetStage
extends Control
## Wild-West puppet theatre: five flat pictures (back wall, floor, left and right wall, lower floor) are drawn as perspective quads,
## so the artwork stays flat and only the code tilts it. Wooden cut-outs (cloud, tree, sun) slide to and fro in front of the back wall,
## puppets (flat painted planks) stand on the floor; the ceiling (a valance) is not tilted at all, it is laid over the top of the screen on the
## highest z, and the front wall (upright too) hangs under the floor with the lower floor, tilted like the floor, below it. All geometry is in 1920 x 1080 design px.

## The pictures live in res://assets/Puppet/Stage/Act<n>/{Backdrop,Wall,Floor,Ceiling,Props}/ (an act that has none of its own yet uses Act 1's);
## the hanging sign, the same in every act, in Stage/Shared/.
const STAGE_FOLDERS := {"back_wall": "Backdrop", "wall_left": "Wall", "wall_right": "Wall", "front_wall": "Wall", "floor": "Floor",
	"lower_floor": "Floor", "ceiling_overlay": "Ceiling"}

## The corners of the pieces are named points; pieces that touch share a point. Names ending in _l / _r are mirror images of each other.
## All in 1920 x 1080 design px: the scene's points are relative to the scene (lowered by SCENE_DY), the lower floor's (low_*) are absolute.
## (They were tuned by hand on the running game; tools/import_puppet_stage.py reads the back wall's numbers from here.)
static func default_verts() -> Dictionary:
	return {
		"top_l": Vector2(-92, -72), "top_r": Vector2(2012, -72),  # the side walls' outer top corners
		"back_top_l": Vector2(130, -126), "back_top_r": Vector2(1790, -126),
		"back_bot_l": Vector2(130, 410), "back_bot_r": Vector2(1790, 410),  # where the back wall meets the floor
		"front_l": Vector2(-92, 562), "front_r": Vector2(2012, 562),  # the floor's front edge
		"low_top_l": Vector2(4, 876), "low_top_r": Vector2(1916, 876),  # the lower floor
		"low_bot_l": Vector2(-190, 1080), "low_bot_r": Vector2(2110, 1080),
	}


## The points R puts back for an act: assets/Puppet/Stage/perspective_defaults.json ("act1" ...), or default_verts() when the file or the act is missing.
static func act_defaults(act: int) -> Dictionary:
	var out := default_verts()
	var path := "res://assets/Puppet/Stage/perspective_defaults.json"
	if FileAccess.file_exists(path):
		var d = JSON.parse_string(FileAccess.get_file_as_string(path))
		if d is Dictionary and d.get("act%d" % act) is Dictionary:
			var a: Dictionary = d["act%d" % act]
			for k in out:
				if a.get(k) is Array and a[k].size() == 2:
					out[k] = Vector2(float(a[k][0]), float(a[k][1]))
	return out


## Each piece: its four corners, clockwise from the top left.
const QUADS := {
	"back_wall": ["back_top_l", "back_top_r", "back_bot_r", "back_bot_l"],
	"floor": ["back_bot_l", "back_bot_r", "front_r", "front_l"],
	"wall_left": ["top_l", "back_top_l", "back_bot_l", "front_l"],
	"wall_right": ["back_top_r", "top_r", "front_r", "back_bot_r"],
	"front_wall": ["front_l", "front_r", "low_top_r", "low_top_l"],  # (the upright wooden panel: hangs from the floor's front edge, down to the lower floor)
	"lower_floor": ["low_top_l", "low_top_r", "low_bot_r", "low_bot_l"],
}
const GRID := 24
## How much each picture is lit: a real stage is dim, the side walls and the ceiling most of all (the spotlights add the light back).
const TINT := {"back_wall": 0.80, "floor": 0.74, "lower_floor": 0.6, "wall_left": 0.5, "wall_right": 0.5, "front_wall": 0.8}
const STAGE_H := 1080.0
## The whole stage (back wall, side walls, floor, front wall, scenery) stands SCENE_DY lower than the numbers above say, so that the bottom of
## the front wall touches the lower floor; the ceiling, the sign and the lower floor stay where they are.
const SCENE_DY := 148.0
const FLOOR_SHADOW_DEPTH := 0.3  # how long a floor shadow is, against the height of what throws it
const FLOOR_SHADOW_SKEW := -0.6  # (it leans to the right: the key light is up on the left)
const DESIGN_W := 1920.0
const CEILING_Z := 100

## The shadow a standing piece throws on the wooden floor: its own silhouette, lying flat on the floor in front of its feet, softened and fading
## with the distance from the feet (the picture's bottom edge is where it touches the piece).
const FLOOR_SHADOW := """
shader_type canvas_item;
uniform float strength = 0.45;
uniform float radius = 0.03;
void fragment() {
	float a = texture(TEXTURE, UV).a;
	for (int i = 0; i < 8; i++) {
		float t = float(i) * 0.785398;
		a += texture(TEXTURE, UV + vec2(cos(t), sin(t)) * radius).a;
		a += texture(TEXTURE, UV + vec2(cos(t), sin(t)) * radius * 2.0).a;
	}
	a /= 17.0;
	COLOR = vec4(0.0, 0.0, 0.0, a * strength * mix(0.6, 1.0, UV.y));
}
"""
static var _floor_shadow_shader: Shader

var _sprites: Array[Dictionary] = []
var _anchored: Array[Dictionary] = []  # scenery placed by rule: {node, frac, dy, extra}
var _t := 0.0
var _scene: Control  # everything that was shifted down by SCENE_DY
var _ceiling: TextureRect  # the valance over the top of the screen
var _xs := 1.0  # sideways stretch of the props stations (set by fit)
var verts := {}  # point name -> Vector2 (see default_verts)
var _quads: Array[_Quad] = []


static func _load(path: String) -> Texture2D:
	if ResourceLoader.exists(path):
		return load(path) as Texture2D
	var img := Image.load_from_file(ProjectSettings.globalize_path(path))
	return ImageTexture.create_from_image(img) if img != null else null


var act_no := 1  # whose pictures the stage is made of


func _stage_path(name: String) -> String:
	var dir := UiSkin.theme_dir() + "Stage/"
	if name == "props/hanging_sign":
		return dir + "Shared/hanging_sign.png"
	var folder: String = "Props" if name.begins_with("props/") else String(STAGE_FOLDERS.get(name, ""))
	for a in [act_no, 1]:
		var p := "%sAct%d/%s/%s.png" % [dir, a, folder, name.get_file()]
		if ResourceLoader.exists(p):
			return p
	return ""


func _pic(name: String) -> Texture2D:
	var path := _stage_path(name)
	return _load(path) if path != "" else null


func _init(p_act := 1) -> void:
	act_no = p_act
	position = Vector2.ZERO
	size = Vector2(1920, STAGE_H)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = true
	_scene = Control.new()
	_scene.position = Vector2(0, SCENE_DY)
	_scene.size = Vector2(DESIGN_W, STAGE_H)
	_scene.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_scene)
	verts = act_defaults(act_no)
	_load_verts()
	_symmetrize()
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
	_ceiling = TextureRect.new()  # the ceiling: its own picture, as it is, over everything (the HUD text is raised above it)
	_ceiling.texture = _pic("ceiling_overlay")
	_ceiling.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_ceiling.stretch_mode = TextureRect.STRETCH_SCALE  # (stretched, never repeated: a repeated piece showed on the right of a wider screen)
	_ceiling.size = Vector2(DESIGN_W, _ceiling.texture.get_height())
	_ceiling.position = Vector2.ZERO
	_ceiling.z_index = CEILING_Z
	_ceiling.modulate = Color(0.86, 0.86, 0.86)
	_ceiling.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_ceiling)
	_refresh_quads()


## A wooden cut-out that stands at `pos` (its feet), `height` px tall, swaying on its base; `slide` is how far it travels left and
## right on its rail.
func add_prop(file: String, pos: Vector2, height: float, slide: float, speed: float, phase := 0.0, sway := 0.02, lit := 0.86, shadow := 0.0, on_floor := false) -> Sprite2D:
	var sp := Sprite2D.new()
	sp.texture = _pic(file)
	sp.centered = false
	sp.offset = Vector2(-sp.texture.get_width() / 2.0, -sp.texture.get_height())
	sp.scale = Vector2.ONE * (height / float(sp.texture.get_height()))
	sp.position = pos
	sp.modulate = Color(lit, lit, lit * 0.96)
	if on_floor and shadow > 0.0:  # it stands on the floor: its shadow lies on the planks behind it, not on the backdrop
		if _floor_shadow_shader == null:
			_floor_shadow_shader = Shader.new()
			_floor_shadow_shader.code = FLOOR_SHADOW
		var fs := Sprite2D.new()
		fs.texture = sp.texture
		fs.centered = false
		fs.offset = sp.offset
		fs.show_behind_parent = true
		fs.scale = Vector2(1.0, FLOOR_SHADOW_DEPTH)  # (squashed: lying on the floor, away from the viewer, behind it)
		fs.skew = FLOOR_SHADOW_SKEW
		var mat := ShaderMaterial.new()
		mat.shader = _floor_shadow_shader
		mat.set_shader_parameter("strength", shadow)
		fs.material = mat
		sp.add_child(fs)
	elif shadow > 0.0:  # the shadow it throws on the backdrop behind it: its own silhouette, a little lower and to the right
		var sh := Sprite2D.new()
		sh.texture = sp.texture
		sh.centered = false
		sh.offset = sp.offset
		sh.show_behind_parent = true
		sh.self_modulate = Color(0, 0, 0, shadow)
		sh.position = Vector2(18.0, 9.0) / sp.scale.x
		sp.add_child(sh)
	_scene.add_child(sp)
	_sprites.append({"node": sp, "x": pos.x, "slide": slide, "speed": speed, "phase": phase, "sway": sway, "grp": "prop", "off": _spawn_off})
	return sp


## Stretch the whole stage sideways to a screen that is wider than 1920 (the pictures are only tilted by code, so any width works).
func fit(width: float) -> void:
	width = maxf(width, DESIGN_W)
	_xs = width / DESIGN_W
	if _ceiling != null:
		_ceiling.size.x = width  # (a wider screen just repeats the picture)
	size = Vector2(width, STAGE_H)
	_scene.size.x = width
	for q in _quads:
		q.x_scale = _xs
		q.queue_redraw()
	_layout_handles()


## The wooden scenery in front of the back wall: far mountains stand still, clouds, sun and trees slide on rails and rock a little.
## Every map (every stage that is built) lays it out anew: which mountains, trees and tufts come, and where.
func add_default_props(rng_seed := 0) -> void:
	# every piece is placed by rule (see _place_props): `frac` is how far across the back wall it stands (0 = its left edge, 1 = its right
	# edge, the piece itself always staying inside the wall), `dy` how far below the seam between the back wall and the floor its feet are
	# (negative: above it, for the sky)
	var rng := RandomNumberGenerator.new()
	if rng_seed == 0:
		rng.randomize()
	else:
		rng.seed = rng_seed
	var mountains := [1, 2, 3, 4, 5]
	_shuffle(mountains, rng)
	for k in 4:  # (four of the five, spread over the wall with some jitter)
		_add_anchored("props/mountain_%d" % mountains[k], _spread(k, 4, rng), 0.0, rng.randf_range(115.0, 185.0), 0.0, 1.0, 0.0, 0.0, 0.78, 0.0)
	# (the sun first: what is added later is drawn over it, so the clouds pass in front of it)
	_add_anchored("props/sun", rng.randf_range(0.5, 0.95), -240.0, 130.0, 20, 0.3, 1.0, 0.03, 1.0, 0.18)
	var clouds := [1, 2, 3]
	_shuffle(clouds, rng)
	for k in 3:
		_add_anchored("props/cloud_%d" % clouds[k], _spread(k, 3, rng), -227.0 - rng.randf_range(0.0, 50.0), rng.randf_range(70.0, 105.0), rng.randf_range(35.0, 58.0), rng.randf_range(0.3, 0.55), rng.randf() * 5.0, 0.02, 0.9, 0.28)
	# the trees stand on the seam between the floor and the backdrop and rock on their trunks, like the puppets
	var trees := [1, 2, 3, 4, 5]
	_shuffle(trees, rng)
	for k in 5:
		_add_anchored("props/tree_%d" % trees[k], _spread(k, 5, rng), 6.0, rng.randf_range(205.0, 275.0), 0.0, rng.randf_range(0.8, 1.1), rng.randf() * 5.0, rng.randf_range(0.035, 0.045), 0.84, 0.95, true)
	# tufts of grass on the ground along the same seam, swaying a little
	var nb := rng.randi_range(7, 9)
	for i in nb:
		_add_anchored("props/bush_%d" % rng.randi_range(1, 6), _spread(i, nb, rng), 12.0 + (i % 3) * 5.0, rng.randf_range(48.0, 68.0), 0.0, rng.randf_range(1.2, 1.9), i * 1.3, 0.05, 0.86, 0.9, true)
	_place_props()


func _shuffle(a: Array, rng: RandomNumberGenerator) -> void:
	for i in range(a.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var t = a[i]
		a[i] = a[j]
		a[j] = t


## The k-th of n places along the wall (0..1), with some jitter, so that n pieces never bunch up.
func _spread(k: int, n: int, rng: RandomNumberGenerator) -> float:
	return clampf((k + rng.randf_range(0.1, 0.9)) / float(n), 0.0, 1.0)


func _add_anchored(file: String, frac: float, dy: float, height: float, slide: float, speed: float, phase: float, sway: float, lit: float, shadow: float, on_floor := false) -> void:
	var sp := add_prop(file, Vector2.ZERO, height, slide, speed, phase, sway, lit, shadow, on_floor)
	# the room this piece needs at its sides: its half width, how far it slides, its shadow (to the right), how far it leans
	var half := sp.texture.get_width() * sp.scale.x / 2.0
	var extra := slide + ((height * FLOOR_SHADOW_DEPTH * 0.6 if on_floor else 18.0) if shadow > 0.0 else 0.0) + height * sway
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
				sp.position.x = x * _xs + float(e["off"])  # (a prop made to be brought in is made off the screen: no frame shows it in place)


## The y (on screen) of the far edge and of the near edge of the floor (where the back wall meets it, and where the stage front begins).
func floor_range() -> Vector2:
	var top: float = (verts["back_bot_l"].y + verts["back_bot_r"].y) / 2.0 + SCENE_DY
	var bottom: float = (verts["front_l"].y + verts["front_r"].y) / 2.0 + SCENE_DY
	return Vector2(top, bottom)


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
	sp.position = Vector2(center_x, -31.0)  # (25 px higher than before: the ceiling covers its top)
	sp.modulate = Color(0.92, 0.92, 0.92)
	sp.z_index = 0  # (under the enemies' names, which can reach up to it)
	var sh := Sprite2D.new()  # (it throws a shadow on the backdrop, like the clouds)
	sh.texture = sp.texture
	sh.centered = false
	sh.offset = sp.offset
	sh.show_behind_parent = true
	sh.self_modulate = Color(0, 0, 0, 0.28)
	sh.position = Vector2(18.0, 9.0) / sp.scale.x
	sp.add_child(sh)
	add_child(sp)
	_sprites.append({"node": sp, "x": center_x, "slide": 0.0, "speed": 1.1, "phase": 0.7, "sway": 0.006, "grp": "fix", "off": 0.0})
	return sp


func _refresh_quads() -> void:
	for q in _quads:
		var c: Array = []
		for n in q.names:
			var v: Vector2 = verts[n]
			if _is_abs(n) and q.get_parent() == _scene:
				v.y -= SCENE_DY  # (the front wall is in the scene, the lower floor's points are absolute)
			c.append(v)
		q.corners = c
		q.queue_redraw()
	_place_props()


## ---- F4 perspective editor ----
## F4 shows the left half's corner points as square buttons; click one (it turns red) and nudge it with the arrow keys (Shift = 10 px).
## The right twin moves the opposite way sideways and the same way up and down, so any offset between the two sides is kept.
## P prints all points (and copies them), R puts the defaults back.
const EDIT_POINTS := ["top_l", "back_top_l", "back_bot_l", "front_l", "low_top_l", "low_bot_l"]
const EDIT_BTN := 20.0
var _edit_on := false
var _edit_sel := ""
var _edit_btns := {}  # point name -> Button
var _edit_info: Label
var _edit_layer: CanvasLayer  # (own layer: the enemy rows are Controls that would otherwise sit over the handles and eat their clicks)


## What F4 changed is kept per act in a file of its own (user://), so it survives closing the game; R deletes it and puts back the act's defaults
## (assets/Puppet/Stage/perspective_defaults.json; paste the numbers from P there to make a new set the defaults).
static var save_path := ""  # ("" = one file per act: user://puppet_stage_verts_act<N>.json; a test sets its own)


func _save_file() -> String:
	return save_path if save_path != "" else "user://puppet_stage_verts_act%d.json" % act_no


func _load_verts() -> void:
	if not FileAccess.file_exists(_save_file()):
		return
	var d = JSON.parse_string(FileAccess.get_file_as_string(_save_file()))
	if d is Dictionary:
		for k in d:
			if verts.has(k) and d[k] is Array and d[k].size() == 2:
				verts[k] = Vector2(float(d[k][0]), float(d[k][1]))


func _save_verts() -> void:
	if verts == act_defaults(act_no):
		if FileAccess.file_exists(_save_file()):
			DirAccess.remove_absolute(_save_file())
		return
	var d := {}
	for k in verts:
		d[k] = [verts[k].x, verts[k].y]
	var f := FileAccess.open(_save_file(), FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(d))


func _is_abs(n: String) -> bool:
	return n.begins_with("low_")  # (the lower floor is not lowered by SCENE_DY)


## Where a point is drawn on screen (kept inside the screen, so points that lie outside it still get a button).
func _point_screen(n: String) -> Vector2:
	var v: Vector2 = verts[n]
	var p := Vector2(v.x * _xs, v.y + (0.0 if _is_abs(n) else SCENE_DY))
	var h := EDIT_BTN / 2.0  # (the whole button stays on screen, or the stage's clipping would eat the click)
	return p.clamp(Vector2(h, h), Vector2(size.x - h, size.y - h))


func _layout_handles() -> void:
	for n in _edit_btns:
		var b: Button = _edit_btns[n]
		b.position = _point_screen(n) - Vector2(EDIT_BTN, EDIT_BTN) / 2.0
		b.visible = _edit_on
	_update_edit_info()


func _set_edit(on: bool) -> void:
	_edit_on = on
	if on and _edit_btns.is_empty():
		_edit_layer = CanvasLayer.new()
		_edit_layer.layer = 100
		add_child(_edit_layer)
		for n in EDIT_POINTS:
			var b := Button.new()
			b.custom_minimum_size = Vector2(EDIT_BTN, EDIT_BTN)
			b.size = Vector2(EDIT_BTN, EDIT_BTN)
			b.focus_mode = Control.FOCUS_NONE
			b.z_index = CEILING_Z + 5
			b.mouse_filter = Control.MOUSE_FILTER_STOP
			b.pressed.connect(_select_point.bind(n))
			_edit_layer.add_child(b)
			_edit_btns[n] = b
		_edit_info = Label.new()
		_edit_info.position = Vector2(220, 8)
		_edit_info.z_index = CEILING_Z + 6
		_edit_info.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_edit_info.add_theme_color_override("font_color", Color(1, 0.95, 0.4))
		_edit_info.add_theme_color_override("font_outline_color", Color.BLACK)
		_edit_info.add_theme_constant_override("outline_size", 6)
		_edit_info.add_theme_font_size_override("font_size", 20)
		_edit_layer.add_child(_edit_info)
	if _edit_info != null:
		_edit_info.visible = on
	_style_handles()
	_layout_handles()


func _style_handles() -> void:
	for n in _edit_btns:
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0.95, 0.15, 0.1) if n == _edit_sel else Color(1, 0.85, 0.1)
		sb.border_color = Color.BLACK
		sb.set_border_width_all(2)
		for s in ["normal", "hover", "pressed", "focus", "disabled"]:
			_edit_btns[n].add_theme_stylebox_override(s, sb)


func _select_point(n: String) -> void:
	_edit_sel = n
	_style_handles()
	_update_edit_info()


## The mirror image of a left-half point about the middle of the stage (x = DESIGN_W / 2), so the two sides can never differ by a few pixels.
func _mirror(v: Vector2) -> Vector2:
	return Vector2(DESIGN_W - v.x, v.y)


## Every _r point is the mirror of its _l point (the left ones are the truth): an old saved set with a pair that had drifted apart (a back wall
## whose right edge was 15 px short of its mirror, leaving a sliver of the right wall when the left wall was pulled out of sight) is made exact.
func _symmetrize() -> void:
	for k in verts.keys():
		if String(k).ends_with("_l") and verts.has(_twin(k)):
			verts[_twin(k)] = _mirror(verts[k])


func _twin(n: String) -> String:
	return n.trim_suffix("_l") + "_r"


func _update_edit_info() -> void:
	if _edit_info == null:
		return
	if _edit_sel == "":
		_edit_info.text = "F4: click a point, arrows move it (Shift = 10 px), P = print, R = reset"
	else:
		_edit_info.text = "%s %s   |   %s %s" % [_edit_sel, verts[_edit_sel], _twin(_edit_sel), verts[_twin(_edit_sel)]]


func _nudge(d: Vector2) -> void:
	var n := _edit_sel
	verts[n] = Vector2(verts[n]) + d
	verts[_twin(n)] = _mirror(verts[n])  # (an exact mirror about the middle of the screen, whatever the twin was before)
	_refresh_quads()
	_layout_handles()
	_save_verts()


func _dump_points() -> void:
	var s := ""
	for k in verts:
		var v: Vector2 = verts[k]
		s += '"%s": Vector2(%d, %d),\n' % [k, roundi(v.x), roundi(v.y)]
	print(s)
	DisplayServer.clipboard_set(s)


func _input(ev: InputEvent) -> void:
	if not (ev is InputEventKey) or not ev.pressed:
		return
	var k: int = ev.keycode
	if k == KEY_F4 and not ev.echo:
		_set_edit(not _edit_on)
		get_viewport().set_input_as_handled()
		return
	if not _edit_on:
		return
	var step := 10.0 if ev.shift_pressed else 1.0
	var d := Vector2.ZERO
	match k:
		KEY_LEFT: d = Vector2(-step, 0)
		KEY_RIGHT: d = Vector2(step, 0)
		KEY_UP: d = Vector2(0, -step)
		KEY_DOWN: d = Vector2(0, step)
		KEY_P:
			if not ev.echo:
				_dump_points()
			get_viewport().set_input_as_handled()
			return
		KEY_R:
			verts = act_defaults(act_no)  # (this act's saved defaults, not another act's)
			_refresh_quads()
			_layout_handles()
			_save_verts()
			get_viewport().set_input_as_handled()
			return
		_:
			return
	if _edit_sel != "":
		_nudge(d)
	get_viewport().set_input_as_handled()


## ---- Changing the set: the stage is cleared, then laid again ----
## Once the player is at the encounter board, the props are cleared away one by one (each leaves to the left at its own moment and speed, in a
## random order, the whole clearing taking CLEAR_TIME); when the fight begins the new set is brought in the same way from the right.
const CLEAR_TIME := 5.0
const BRING_TIME := 5.0
signal cleared
var _spawn_off := 0.0  # where a prop is made (sideways, off the screen when it is going to be brought in)
var _clearing := false
var _is_clear := false
var _stage_tw: Tween
var _sign: Node2D


func is_clearing() -> bool:
	return _clearing


## Nothing (but the hanging sign) stands on the stage any more.
func is_clear() -> bool:
	return _is_clear


## How far a prop has to move sideways to be wholly off the screen (`left`: to the left of it, else to the right of it).
func _off_distance(e: Dictionary, left: bool) -> float:
	var n: Sprite2D = e["node"]
	var half := n.texture.get_width() * n.scale.x / 2.0 + 40.0
	var x := float(e["x"]) * _xs
	var room := half + float(e["slide"]) + n.texture.get_height() * n.scale.y * float(e["sway"]) + 60.0
	return -(x + room) if left else (size.x - x) + room


## Tween every prop in `entries` from `from_off` to `to_off` (per prop: functions of the entry) in a random order, each with its own start and
## its own time, all done within `total` seconds.
func _stagger(entries: Array, total: float, left: bool, bringing: bool) -> Tween:
	var tw := create_tween().set_parallel(true)
	var order := entries.duplicate()
	order.shuffle()
	var n := order.size()
	for i in n:
		var e: Dictionary = order[i]
		var delay := total * 0.5 * float(i) / maxf(1.0, n - 1.0) + randf_range(0.0, total * 0.04)
		var dur := minf(randf_range(0.32, 0.5) * total, total - delay)
		var d := _off_distance(e, left)
		var a := 0.0 if not bringing else d
		var b := d if not bringing else 0.0
		if bringing:
			e["off"] = a
		tw.tween_method(func(v: float) -> void: e["off"] = v, a, b, dur).set_delay(delay).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	return tw


func _props() -> Array:
	return _sprites.filter(func(e: Dictionary) -> bool: return e["grp"] != "fix")


## Clear the stage: the props leave one by one over CLEAR_TIME. (Calling it again while it goes on, or once it is clear, does nothing.)
func clear_props() -> void:
	if _clearing or _is_clear:
		return
	_clearing = true
	lift_sign()
	var props := _props()
	if props.is_empty():
		_finish_clear()
		return
	if _stage_tw != null:
		_stage_tw.kill()
	_stage_tw = _stagger(props, CLEAR_TIME, true, false)
	_stage_tw.chain().tween_callback(_finish_clear)


func _finish_clear() -> void:
	_remove_props()
	_clearing = false
	_is_clear = true
	cleared.emit()


func _remove_props() -> void:
	var keep: Array[Dictionary] = []
	for e in _sprites:
		if e["grp"] == "fix":
			keep.append(e)
		else:
			e["node"].queue_free()
	_sprites = keep
	_anchored.clear()


## The new set comes in from the right over BRING_TIME, prop by prop. Returns the tween. (The stage must be clear: a stage that is still
## full is cleared at once.)
func bring_props(rng_seed := 0) -> Tween:
	if _clearing and _stage_tw != null:
		_stage_tw.kill()
		_clearing = false
	if not _is_clear:
		_remove_props()
	_is_clear = false
	_spawn_off = 100000.0  # (made off the screen, so that not one frame shows them in place)
	add_default_props(rng_seed)
	_spawn_off = 0.0
	if _stage_tw != null:
		_stage_tw.kill()
	_stage_tw = _stagger(_props(), BRING_TIME, false, true)
	return _stage_tw


## The sign that drops from behind the ceiling on its chains, with `text` on its plate (Victory!). It hangs there until lift_sign().
func drop_sign(text: String, col := Color(0.30, 0.17, 0.07), kind := "") -> Tween:
	lift_sign(true)
	var h := 500.0
	var sp := Sprite2D.new()
	var board: Texture2D = null  # (a result board painted with its own words: Stage/Shared/sign_<kind>.png; without it the plate gets the text in code)
	if kind != "":
		var bp := UiSkin.theme_dir() + "Stage/Shared/sign_%s.png" % kind
		board = _load(bp) if ResourceLoader.exists(bp) else null
	sp.texture = board if board != null else _pic("props/hanging_sign")
	if board != null:
		h = 400.0  # (the painted boards carry their chains: a little smaller than the old sign so they do not cover the enemies)
	sp.centered = false
	sp.offset = Vector2(-sp.texture.get_width() / 2.0, 0)
	sp.scale = Vector2.ONE * (h / float(sp.texture.get_height()))
	var holder := Node2D.new()
	holder.position = Vector2(size.x / 2.0, -h - 40.0)  # (above the screen: it falls in)
	holder.add_child(sp)
	var lb := Label.new()
	lb.text = "" if board != null else text
	lb.add_theme_font_size_override("font_size", 80 if text.length() <= 9 else 54)  # (a long line is written smaller to fit the plate)
	lb.add_theme_color_override("font_color", col)
	lb.add_theme_color_override("font_outline_color", Color(0.98, 0.84, 0.5, 0.55))
	lb.add_theme_constant_override("outline_size", 6)
	var f := UiTheme.cut("bold")
	if f != null:
		lb.add_theme_font_override("font", f)
	lb.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lb.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	var plate_w := sp.texture.get_width() * sp.scale.x * 0.86
	lb.size = Vector2(plate_w, 140)
	lb.position = Vector2(-plate_w / 2.0, h * 0.64 - 70.0)  # (the middle of the board)
	holder.add_child(lb)
	add_child(holder)
	_sign = holder
	var tw := create_tween()
	tw.tween_property(holder, "position:y", -31.0, 0.55).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_property(holder, "position:y", -31.0 - 38.0, 0.16).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)  # (the chains stretch, it bounces)
	tw.tween_property(holder, "position:y", -31.0, 0.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_property(holder, "position:y", -31.0 - 12.0, 0.1).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(holder, "position:y", -31.0, 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	return tw


## The sign goes back up behind the ceiling (instantly when `now`).
func lift_sign(now := false) -> void:
	if _sign == null or not is_instance_valid(_sign):
		_sign = null
		return
	var old := _sign
	_sign = null
	if now:
		old.queue_free()
		return
	var tw := create_tween()
	tw.tween_property(old, "position:y", -560.0, 0.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_callback(old.queue_free)


func _process(d: float) -> void:
	_t += d
	for s in _sprites:
		var sp: Sprite2D = s["node"]
		var w := sin(_t * float(s["speed"]) + float(s["phase"]))
		sp.position.x = float(s["x"]) * _xs + w * float(s["slide"]) + float(s["off"])
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
