class_name CampfireHot
extends TextureRect
## One of the things you can choose at the campfire: only its drawn (not transparent) pixels count as the mouse being on it.
## It glows when hovered; a disabled one is dimmed.

signal hovered(which: String, on: bool)
signal pressed(which: String)

const GLOW_SHADER := """
shader_type canvas_item;
uniform float glow : hint_range(0.0, 1.0) = 0.0;
void fragment() {
	vec4 c = texture(TEXTURE, UV);
	float pulse = 0.82 + 0.18 * sin(TIME * 6.0);
	c.rgb = c.rgb * (1.0 + 0.21 * glow * pulse) + vec3(0.17, 0.11, 0.035) * glow * pulse * c.a;  // (half the strength it first had)
	COLOR = c;
}
"""

var which := ""
var _bits: BitMap
var _mat: ShaderMaterial
var _tween: Tween
var _on := false
var _enabled := true
var _glow_v := 0.0
var _sel := false
## A part of the picture that counts as the choice although it is not drawn there (the fire, for the cauldron), in local pixels.
var extra_area := Rect2()


func setup(tex: Texture2D, p_which: String) -> void:
	which = p_which
	texture = tex
	expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	stretch_mode = TextureRect.STRETCH_SCALE
	mouse_filter = Control.MOUSE_FILTER_STOP
	var img := tex.get_image()
	if img != null:
		if img.is_compressed():
			img.decompress()
		_bits = BitMap.new()
		_bits.create_from_image_alpha(img, 0.12)
	var sh := Shader.new()
	sh.code = GLOW_SHADER
	_mat = ShaderMaterial.new()
	_mat.shader = sh
	material = _mat
	mouse_entered.connect(func(): _hover(true))
	mouse_exited.connect(func(): _hover(false))


func set_enabled(on: bool) -> void:
	_enabled = on
	modulate = Color.WHITE if on else Color(0.6, 0.6, 0.62)
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if on else Control.CURSOR_FORBIDDEN


func _has_point(point: Vector2) -> bool:
	if extra_area.has_area() and extra_area.has_point(point):
		return true
	if _bits == null or size.x <= 0.0 or size.y <= 0.0:
		return true
	var bs := _bits.get_size()
	var x := int(point.x / size.x * bs.x)
	var y := int(point.y / size.y * bs.y)
	return x >= 0 and y >= 0 and x < bs.x and y < bs.y and _bits.get_bit(x, y)


func _hover(on: bool) -> void:
	if on == _on:
		return
	_on = on
	hovered.emit(which, on)
	_refresh_glow()


## Lit while the mouse is on it, and while it is the chosen one.
func set_selected(on: bool) -> void:
	_sel = on
	_refresh_glow()


func _refresh_glow() -> void:
	if is_instance_valid(_tween):
		_tween.kill()
	_tween = create_tween()
	var to := 1.0 if ((_on or _sel) and _enabled) else 0.0
	_tween.tween_method(func(v: float):
		_glow_v = v
		_mat.set_shader_parameter("glow", v), _glow_v, to, 0.16)


func _gui_input(ev: InputEvent) -> void:
	if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
		accept_event()
		pressed.emit(which)
