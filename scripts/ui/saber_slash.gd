class_name SaberSlash
extends Control
## An enemy's hit landing on you (replaces the three flat red lines): a couple of quick curved blade cuts like a light saber's, each a glowing crescent with a white-hot
## core that sweeps across in a tenth of a second and burns out, a glowing cut line that lingers a little longer, a flash of light, a shower of sparks that fly off the
## blade and fall, and a soft red vignette round the screen. Small and tight (about 150 px across), drawn additively so it lights up what is behind it.
## Blue and without the vignette when your Shield took the blow. A heavier blow is a little bigger and the vignette stronger.

const LIFE := 1.25
const SWEEP := 0.09  # seconds the blade takes to cross
const BURN := 0.5  # seconds a cut takes to burn out once it has crossed
const SEGMENTS := 26
const GRAVITY := 780.0

static var _glow: GradientTexture2D  # a soft round glow, made once

var at := Vector2.ZERO
var heavy := 1.0  # 0.8 .. 1.5: how big the cuts are
var blocked := false
var hurt := 0.0  # damage as a fraction of max HP: the vignette's strength
var _t := 0.0
var _cuts: Array = []  # {a, b, c (bezier points), delay, width}
var _sparks: Array = []  # {pos, vel, life, max, size}
var _emit := {}  # cut index -> sparks still owed (fractions)
var _rng := RandomNumberGenerator.new()
var _vignette: ColorRect
var _vmat: ShaderMaterial

const VIGNETTE := """
shader_type canvas_item;
uniform float amount = 0.0;
void fragment() {
	vec2 p = (UV - 0.5) * vec2(1.0, 0.9);
	float d = length(p) * 1.55;
	float v = smoothstep(0.5, 1.1, d);
	COLOR = vec4(0.95, 0.04, 0.03, v * amount);
}
"""


## `dmg` = the damage taken (0 when it was all blocked), `max_hp` = your max HP.
static func hit(parent: Control, p_at: Vector2, p_blocked: bool, dmg := 0.0, max_hp := 100.0) -> SaberSlash:
	var fx := SaberSlash.new()
	fx.at = p_at
	fx.blocked = p_blocked
	fx.heavy = clampf(0.85 + dmg / 25.0, 0.85, 1.5)
	fx.hurt = clampf(dmg / maxf(1.0, max_hp), 0.0, 1.0)
	fx.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fx.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	fx.z_index = 45
	parent.add_child(fx)
	return fx


static func _glow_tex() -> GradientTexture2D:
	if _glow == null:
		var g := Gradient.new()
		g.colors = PackedColorArray([Color(1, 1, 1, 1), Color(1, 1, 1, 0.35), Color(1, 1, 1, 0)])
		g.offsets = PackedFloat32Array([0.0, 0.35, 1.0])
		_glow = GradientTexture2D.new()
		_glow.gradient = g
		_glow.fill = GradientTexture2D.FILL_RADIAL
		_glow.fill_from = Vector2(0.5, 0.5)
		_glow.fill_to = Vector2(1.0, 0.5)
		_glow.width = 128
		_glow.height = 128
	return _glow


func _ready() -> void:
	_rng.randomize()
	var add := CanvasItemMaterial.new()
	add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	material = add  # (everything below lights up what is behind it)
	# the cuts: a long one down-and-across, a shorter one coming back the other way, and a small flick
	var base := _rng.randf_range(-10.0, 10.0)
	for spec in [[32.0 + base, 165.0, 0.0, 1.0, 0.22], [148.0 - base, 125.0, 0.07, 0.8, -0.25], [-6.0 + base, 75.0, 0.13, 0.55, 0.2]]:
		var dir := Vector2.from_angle(deg_to_rad(float(spec[0])))
		var length: float = float(spec[1]) * heavy * (0.8 if blocked else 1.0)
		# every cut passes through `at` in the middle of its curve (u = 0.5), so they all cross exactly there
		var off := dir.orthogonal() * length * float(spec[4])
		_cuts.append({"a": at - dir * length * 0.5 - off * 0.5, "b": at + dir * length * 0.5 - off * 0.5, "c": at + off * 0.5, "delay": float(spec[2]), "width": 17.0 * float(spec[3]) * heavy, "len": length})
		_emit[_cuts.size() - 1] = 0.0
	if not blocked:
		_vignette = ColorRect.new()
		_vignette.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		_vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_vmat = ShaderMaterial.new()
		var sh := Shader.new()
		sh.code = VIGNETTE
		_vmat.shader = sh
		_vignette.material = _vmat
		add_child(_vignette)


func _bez(c: Dictionary, u: float) -> Vector2:
	var a: Vector2 = c.a
	var b: Vector2 = c.b
	var p: Vector2 = c.c
	return a * ((1.0 - u) * (1.0 - u)) + p * (2.0 * (1.0 - u) * u) + b * (u * u)


func _tangent(c: Dictionary, u: float) -> Vector2:
	var a: Vector2 = c.a
	var b: Vector2 = c.b
	var p: Vector2 = c.c
	return ((p - a) * (2.0 * (1.0 - u)) + (b - p) * (2.0 * u)).normalized()


## How far the blade has crossed (0..1) and how far the burn-out has eaten the cut from its start (0..1).
func _head(c: Dictionary) -> float:
	var k := clampf((_t - float(c.delay)) / SWEEP, 0.0, 1.0)
	return 1.0 - pow(1.0 - k, 3.0)  # (it flies in fast and slows at the end)


func _tail(c: Dictionary) -> float:
	var k := clampf((_t - float(c.delay) - SWEEP * 0.6) / BURN, 0.0, 1.0)
	return k * k


func _process(d: float) -> void:
	_t += d
	for i in _cuts.size():
		var c: Dictionary = _cuts[i]
		var h := _head(c)
		var moving := _t >= float(c.delay) and _t < float(c.delay) + SWEEP + 0.03
		if moving:
			_emit[i] += d * 300.0
			while _emit[i] >= 1.0:
				_emit[i] -= 1.0
				_spawn_spark(c, h)
	for s in _sparks:
		s.pos += s.vel * d
		s.vel *= pow(0.12, d)  # (air drag)
		s.vel.y += GRAVITY * d
		s.life -= d
	_sparks = _sparks.filter(func(s): return s.life > 0.0)
	if _vmat != null:
		var k := clampf(_t / 0.07, 0.0, 1.0) * clampf(1.0 - (_t - 0.07) / 0.9, 0.0, 1.0)
		_vmat.set_shader_parameter("amount", k * (0.16 + hurt * 0.7))
	queue_redraw()
	if _t > LIFE:
		queue_free()


func _spawn_spark(c: Dictionary, h: float) -> void:
	var u := clampf(h * _rng.randf(), 0.0, 1.0)
	var pos := _bez(c, u)
	var tg := _tangent(c, u)
	var nrm := tg.orthogonal() * (1.0 if _rng.randf() < 0.5 else -1.0)
	var vel := tg * _rng.randf_range(60.0, 250.0) + nrm * _rng.randf_range(40.0, 290.0) + Vector2(0.0, _rng.randf_range(-170.0, 20.0))
	var life := _rng.randf_range(0.4, 1.0)
	_sparks.append({"pos": pos, "vel": vel, "life": life, "max": life, "size": _rng.randf_range(1.3, 2.8) * (0.8 + heavy * 0.3)})


func _draw() -> void:
	var hot := Color(0.55, 0.9, 1.0) if blocked else Color(1.0, 0.32, 0.18)  # (the glow's colour)
	var mid_col := Color(0.8, 0.97, 1.0) if blocked else Color(1.0, 0.62, 0.35)
	var gtex := _glow_tex()
	# the flash of light where it lands: bright for a moment, then gone
	var flash := clampf(1.0 - _t / 0.4, 0.0, 1.0)
	if flash > 0.0:
		var r := 88.0 * heavy * (0.6 + 0.4 * (1.0 - flash))
		draw_texture_rect(gtex, Rect2(at - Vector2(r, r), Vector2(r, r) * 2.0), false, Color(hot, flash * 0.5))
		var r2 := 30.0 * heavy
		draw_texture_rect(gtex, Rect2(at - Vector2(r2, r2), Vector2(r2, r2) * 2.0), false, Color(1, 1, 1, flash * flash * 0.55))
	for c in _cuts:
		_draw_cut(c, hot, mid_col, gtex)
	for s in _sparks:
		var a: float = s.life / s.max
		var tail: Vector2 = s.pos - (s.vel as Vector2) * 0.035
		draw_line(tail, s.pos, Color(hot.lightened(0.35), a * 0.9), s.size)
		draw_line(tail.lerp(s.pos, 0.5), s.pos, Color(1, 1, 1, a), maxf(1.0, s.size * 0.45))
		var gr: float = s.size * 5.0
		draw_texture_rect(gtex, Rect2(s.pos - Vector2(gr, gr), Vector2(gr, gr) * 2.0), false, Color(hot, a * 0.35))


func _draw_cut(c: Dictionary, hot: Color, mid_col: Color, gtex: GradientTexture2D) -> void:
	var h := _head(c)
	var tl := _tail(c)
	if h <= 0.0 or tl >= 1.0:
		return
	var life_fade := 1.0 - tl  # (the whole cut dims as it burns out)
	var w: float = c.width
	var prev := _bez(c, tl)
	for i in range(1, SEGMENTS + 1):
		var u := lerpf(tl, h, float(i) / SEGMENTS)
		var p := _bez(c, u)
		var s := (u - tl) / maxf(0.001, h - tl)  # 0 at the tail .. 1 at the head
		var along := sin(PI * clampf(u, 0.0, 1.0))  # (a crescent: thin at both ends of the whole cut, thick in the middle)
		var recency := lerpf(0.25, 1.0, s)  # (the head end is the brightest)
		var ww := w * along * lerpf(0.5, 1.0, s)
		draw_line(prev, p, Color(hot, 0.22 * recency * life_fade), ww * 2.6)  # (the glow round the blade)
		draw_line(prev, p, Color(mid_col, 0.7 * recency * life_fade), ww * 1.1)  # (the blade)
		draw_line(prev, p, Color(1, 1, 1, 0.95 * recency * life_fade), maxf(1.5, ww * 0.38))  # (the white-hot core)
		prev = p
	# the bright point of the blade at its head, while it is still crossing
	if h < 1.0:
		var hp := _bez(c, h)
		var gr: float = w * 2.4
		draw_texture_rect(gtex, Rect2(hp - Vector2(gr, gr), Vector2(gr, gr) * 2.0), false, Color(1.0, 0.9, 0.8, 0.55))
	# the cut line that stays a little longer: a thin hot crack, orange, then dark red, then gone
	var lingers := clampf(1.0 - (_t - float(c.delay) - SWEEP) / 0.85, 0.0, 1.0)
	if lingers > 0.0:
		var col := hot.lerp(Color(0.5, 0.05, 0.03), 1.0 - lingers)
		var pts := PackedVector2Array()
		for i in range(0, SEGMENTS + 1):
			pts.append(_bez(c, float(i) / SEGMENTS))
		draw_polyline(pts, Color(col, lingers * 0.55), maxf(1.5, w * 0.12), true)
