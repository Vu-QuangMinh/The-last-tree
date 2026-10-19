class_name StageCurtains
extends Control
## The red drapes of the Puppet Stage: on each side a fan of overlapping cloth panels (pictures curtain_1.png, curtain_2.png ... in Stage/Shared, full-size, scaled here)
## that are drawn together over the backdrop and the floor while the map is up, and pulled apart again when a room is entered. They live inside the stage, under
## its ceiling, and are masked to the shape of the back wall + the floor, so the side walls and the lower floor stay in front of them; the map, the events and the
## encounter's UI are laid over them. Without the pictures this does nothing.

const PER_SIDE := 5  # panels on each side
const Z := 3  # over the scenery and the floor (z 0), under the map (CEILING_Z - 12) and the ceiling (CEILING_Z)
const TOP := -34.0
const BOTTOM := 706.0  # (just over the floor's front edge, where the front wall begins)
const REACH := 1000.0  # how far past the middle (x = 960) the innermost panel of a side goes: they overlap there
const OUTER := -92.0  # the outer edge of the outermost panel of the left side (the floor's front corner)
const REST_SWAY := 0.003  # radians the cloth swings while it hangs still
const MOVE_SWAY := 0.015  # ... and while it is being pulled
const SWAY_EASE := 1.6  # how fast the swing's size follows (1 / s): about a second to settle
const STAGGER := 0.07  # of the whole move: how much later each panel further out starts

const SHADOW := """
shader_type canvas_item;
uniform sampler2D tex : filter_linear;
uniform vec2 psize;
uniform float margin;
uniform float radius;
uniform float strength;
float cover(vec2 p) {
	vec2 uv = p / psize;
	if (uv.x < 0.0 || uv.y < 0.0 || uv.x > 1.0 || uv.y > 1.0) return 0.0;
	return texture(tex, uv).a;
}
void fragment() {
	vec2 p = UV * (psize + vec2(2.0 * margin)) - vec2(margin);
	float a = cover(p);
	for (int i = 0; i < 8; i++) {
		float t = float(i) * 0.785398;
		vec2 d = vec2(cos(t), sin(t));
		a += cover(p + d * radius * 0.5);
		a += cover(p + d * radius);
	}
	a /= 17.0;
	COLOR = vec4(0.0, 0.0, 0.0, a * strength);
}
"""
const SHADOW_MARGIN := 70.0  # (the shadow's rectangle is this much bigger than the panel on every side, so the blur is not cut off)
const SHADOW_SHIFT := Vector2(26.0, 6.0)  # how far it falls to the outer side / down
const SHADOW_RADIUS := 34.0  # blur, px
const SHADOW_STRENGTH := 0.62
static var _shadow_shader: Shader

var _mask: Polygon2D
var _left: Array[TextureRect] = []
var _right: Array[TextureRect] = []
var _open_x: Dictionary = {}
var _shut_x: Dictionary = {}
var _amount := 0.0  # 0 = open (all panels off the sides of the screen), 1 = shut
var _t := 0.0
var _tween: Tween
var _xs := 1.0
var _warmed := false
var _sway := REST_SWAY  # the swing's size now: it eases between the resting and the pulled size (a sudden change was a visible jerk when the move ended)


## `poly` = the outline of the back wall and the floor together (the drapes only show inside it).
func setup(poly: PackedVector2Array) -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var arts: Array[Texture2D] = []
	var k := 1
	while UiSkin.tex("curtain_%d" % k) != null:
		arts.append(UiSkin.tex("curtain_%d" % k))
		k += 1
	if arts.is_empty():
		return
	_mask = Polygon2D.new()
	_mask.polygon = poly
	_mask.color = Color.WHITE
	_mask.clip_children = CanvasItem.CLIP_CHILDREN_ONLY
	_mask.z_index = Z
	add_child(_mask)
	var h := BOTTOM - TOP
	var order_l := [0, 2, 4, 1, 3]  # which picture each panel is, outermost first: curtain_1, 3, 5, 2, 4 (the right side is its mirror)
	var order_r := order_l
	for side in 2:
		var panels: Array[TextureRect] = _left if side == 0 else _right
		var order: Array = order_l if side == 0 else order_r
		for i in PER_SIDE:
			var tex: Texture2D = arts[order[i] % arts.size()]
			var w := h * tex.get_width() / tex.get_height()
			var r := TextureRect.new()
			r.texture = tex
			r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			r.stretch_mode = TextureRect.STRETCH_SCALE
			r.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
			r.mouse_filter = Control.MOUSE_FILTER_IGNORE
			r.size = Vector2(w, h)
			r.pivot_offset = Vector2(w / 2.0, 0.0)
			_mask.add_child(r)
			r.add_child(_shadow_of(r, tex, -1.0 if side == 0 else 1.0))
			panels.append(r)
	_layout()
	_apply()
	Audio.warm("sfx_curtain")  # (its first load, as the drapes start to move, was a hitch)


## The soft shadow a panel throws on the ones under it (further from the middle): its own silhouette, blurred, a little to the outer side and down. It is a child that draws
## behind its panel, so it lands on the neighbour that was drawn before. `dir`: -1 = outwards is left, 1 = outwards is right.
func _shadow_of(panel: TextureRect, tex: Texture2D, dir: float) -> ColorRect:
	if _shadow_shader == null:
		_shadow_shader = Shader.new()
		_shadow_shader.code = SHADOW
	var sh := ColorRect.new()
	sh.color = Color.WHITE
	sh.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sh.show_behind_parent = true
	sh.size = panel.size + Vector2(2.0 * SHADOW_MARGIN, 2.0 * SHADOW_MARGIN)
	sh.position = Vector2(-SHADOW_MARGIN + dir * SHADOW_SHIFT.x, -SHADOW_MARGIN + SHADOW_SHIFT.y)
	var mat := ShaderMaterial.new()
	mat.shader = _shadow_shader
	mat.set_shader_parameter("tex", tex)
	mat.set_shader_parameter("psize", panel.size)
	mat.set_shader_parameter("margin", SHADOW_MARGIN)
	mat.set_shader_parameter("radius", SHADOW_RADIUS)
	mat.set_shader_parameter("strength", SHADOW_STRENGTH)
	sh.material = mat
	return sh


func has_art() -> bool:
	return _mask != null


func is_shut() -> bool:
	return _amount >= 0.999


## True while the drapes are being drawn or pulled.
func is_moving() -> bool:
	return _tween != null


## Where each panel is shut and open. Left: the outermost panel's outer edge at OUTER, the innermost reaches REACH; the right side is its mirror.
func _layout() -> void:
	for side in 2:
		var panels: Array[TextureRect] = _left if side == 0 else _right
		var last := panels[PER_SIDE - 1]
		var span := REACH - OUTER - last.size.x  # (the innermost panel ends at REACH)
		var step := span / float(PER_SIDE - 1)
		for i in PER_SIDE:
			var p := panels[i]
			var shut_x := OUTER + step * i  # (left side)
			var open_x := -p.size.x - 80.0 - 14.0 * (PER_SIDE - 1 - i)  # off the left of the screen, a little spread
			if side == 1:  # mirror: x -> 1920 - x - w
				shut_x = 1920.0 - shut_x - p.size.x
				open_x = 1920.0 - open_x - p.size.x
			_shut_x[p] = shut_x
			_open_x[p] = open_x


func set_x_scale(xs: float) -> void:
	_xs = xs
	if _mask != null:
		_mask.scale.x = xs


## The panels' places for the current amount: the ones nearest the middle start first, the outer ones follow a little later.
func _apply() -> void:
	for side in 2:
		var panels: Array[TextureRect] = _left if side == 0 else _right
		for i in PER_SIDE:
			var p := panels[i]
			var k := clampf((_amount * (1.0 + STAGGER * (PER_SIDE - 1)) - STAGGER * (PER_SIDE - 1 - i)), 0.0, 1.0)
			k = ease(k, -2.0) if k < 1.0 else 1.0  # (a soft start, a quick finish)
			p.position = Vector2(lerpf(_open_x[p], _shut_x[p], k), TOP)


func _process(delta: float) -> void:
	if _mask == null or (_amount <= 0.0 and _tween == null):
		return
	_t += delta
	_sway = lerpf(_sway, MOVE_SWAY if _tween != null else REST_SWAY, 1.0 - exp(-SWAY_EASE * delta))
	for side in 2:
		var panels: Array[TextureRect] = _left if side == 0 else _right
		for i in PER_SIDE:
			# a heavy cloth hanging from its top edge: it swings a little all the time, and more while it is being pulled
			panels[i].rotation = sin(_t * 1.2 + i * 1.3 + side * 2.0) * _sway


func _go(to: float, secs: float) -> void:
	if _tween != null:
		_tween.kill()
	_tween = create_tween()
	_tween.tween_method(func(v: float):
		_amount = v
		_apply(), _amount, to, secs).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await _tween.finished
	_tween = null


## The panels (and their blurred shadows) are drawn once, shut and almost invisible (alpha just over the renderer's cut-off), before the first move: until then they
## wait off the screen and are never drawn, so the shadow shader was compiled and the big pictures uploaded in the middle of the first pull, which jerked.
func _warm() -> void:
	if _warmed:
		return
	_warmed = true
	var was := _amount
	_amount = 1.0
	_apply()
	modulate.a = 0.01
	await get_tree().process_frame
	await get_tree().process_frame
	modulate.a = 1.0
	_amount = was
	_apply()


## Draw the drapes together; returns when they have met.
func close(secs := 2.4) -> void:
	if _mask == null or is_shut():
		return
	await _warm()
	Audio.play("sfx_curtain")
	await _go(1.0, secs)


## Pull them apart.
func open(secs := 2.0) -> void:
	if _mask == null or _amount <= 0.0:
		return
	Audio.play("sfx_curtain")
	await _go(0.0, secs)


## Straight to shut / open, no move.
func set_shut(shut: bool) -> void:
	if _tween != null:
		_tween.kill()
		_tween = null
	_amount = 1.0 if shut else 0.0
	if _mask != null:
		_apply()
