class_name CampfireFlame
extends Control
## The campfire's flame: the big and the small flame shapes are blended one over the other by a smooth random noise (so it
## never repeats), the tongues sway at the top, the whole thing breathes in size and brightness, and a warm light pulses on
## the ground around it.

const SWAY_SHADER := """
shader_type canvas_item;
void fragment() {
	float h = 1.0 - UV.y;
	float s = sin(TIME * 9.0 + UV.y * 11.0) * 0.02 * h * h + sin(TIME * 5.3 + UV.y * 6.0) * 0.012 * h;
	COLOR = texture(TEXTURE, vec2(UV.x + s, UV.y));
}
"""

var _small: TextureRect
var _big: TextureRect
var _light: TextureRect
var _noise := FastNoiseLite.new()
var _t := 0.0
var boost := false  # the cauldron (its choice) is hovered or chosen: the fire burns a little brighter
var _boost_v := 0.0


func setup(small_tex: Texture2D, small_pos: Vector2, big_tex: Texture2D, big_pos: Vector2) -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_noise.seed = 31
	_noise.frequency = 1.0
	# the light on the ground (added on top of what is below)
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.45, 1.0])
	g.colors = PackedColorArray([Color(1.0, 0.62, 0.22, 0.85), Color(1.0, 0.45, 0.12, 0.28), Color(1.0, 0.4, 0.1, 0.0)])
	var gt := GradientTexture2D.new()
	gt.gradient = g
	gt.fill = GradientTexture2D.FILL_RADIAL
	gt.fill_from = Vector2(0.5, 0.5)
	gt.fill_to = Vector2(1.0, 0.5)
	gt.width = 256
	gt.height = 256
	_light = TextureRect.new()
	_light.texture = gt
	_light.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_light.stretch_mode = TextureRect.STRETCH_SCALE
	_light.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var add := CanvasItemMaterial.new()
	add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_light.material = add
	var base := Vector2(big_pos.x + big_tex.get_width() / 2.0, big_pos.y + big_tex.get_height())
	_light.size = Vector2(1000, 560)
	_light.position = base - Vector2(500, 330)
	add_child(_light)
	_small = _flame_rect(small_tex, small_pos)
	_big = _flame_rect(big_tex, big_pos)


func _flame_rect(tex: Texture2D, pos: Vector2) -> TextureRect:
	var r := TextureRect.new()
	r.texture = tex
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = TextureRect.STRETCH_SCALE
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	r.position = pos
	r.size = tex.get_size()
	r.pivot_offset = Vector2(r.size.x / 2.0, r.size.y)
	var sh := Shader.new()
	sh.code = SWAY_SHADER
	var m := ShaderMaterial.new()
	m.shader = sh
	r.material = m
	add_child(r)
	return r


func _process(d: float) -> void:
	_t += d
	var slow := _noise.get_noise_2d(_t * 2.6, 0.0)  # which shape it is leaning to
	var fast := _noise.get_noise_2d(_t * 8.5, 40.0)  # the quick shiver
	var mix := clampf(0.5 + 1.25 * slow, 0.0, 1.0)  # 0 = the small flame, 1 = the big one
	_big.modulate.a = mix
	_small.modulate.a = 1.0
	_big.scale = Vector2(1.0 + 0.025 * fast, 0.95 + 0.07 * mix + 0.035 * fast)
	_small.scale = Vector2(1.0 - 0.02 * fast, 1.0 + 0.04 * fast - 0.03 * mix)
	_boost_v = move_toward(_boost_v, 1.0 if boost else 0.0, d * 6.0)
	var b := 0.93 + 0.17 * (0.5 + 0.5 * fast) + 0.1 * _boost_v
	var tint := Color(b, b * 0.96, b * 0.88)
	_big.self_modulate = tint
	_small.self_modulate = tint
	_light.modulate.a = clampf(0.5 + 0.22 * mix + 0.1 * fast + 0.2 * _boost_v, 0.0, 1.0)
