class_name DangerVignette
extends ColorRect
## Low HP: the edges of the screen darken and go red, from 30% HP (faint) to 5% (strongest), with a slow heartbeat
## pulse (the way many games show "you're nearly dead"). A hit also flashes it red for a moment, harder for bigger hits.

var target := 0.0  # 0..1 from your HP
var _k := 0.0
var _flash := 0.0
var _t := 0.0
var _mat: ShaderMaterial

const SHADER := """
shader_type canvas_item;
uniform float k = 0.0;      // low-HP strength, 0..1
uniform float flash = 0.0;  // a hit's red flash, 0..1
void fragment() {
	vec2 uv = (UV - 0.5) * vec2(1.0, 0.72);
	float d = length(uv) * 1.9;
	float edge = smoothstep(0.55, 1.2, d);
	float a = edge * (0.3 + 0.55 * k) * k + 0.07 * k;   // red edges, and the whole screen a little dimmer
	a += flash * (0.1 + 0.45 * edge);
	COLOR = vec4(mix(vec3(0.05, 0.0, 0.0), vec3(0.6, 0.0, 0.02), edge), clamp(a, 0.0, 0.92));
}
"""


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	color = Color.WHITE
	_mat = ShaderMaterial.new()
	var sh := Shader.new()
	sh.code = SHADER
	_mat.shader = sh
	material = _mat


## HP fraction -> strength: nothing above 30%, full at 5% and below.
static func strength(hp: float, max_hp: float) -> float:
	var f := hp / maxf(1.0, max_hp)
	return clampf((0.30 - f) / 0.25, 0.0, 1.0)


func flash(amount: float) -> void:
	_flash = maxf(_flash, clampf(amount, 0.0, 1.0))


func _process(d: float) -> void:
	_t += d
	_k = move_toward(_k, target, d * 1.5)
	_flash = maxf(0.0, _flash - d * 2.2)
	var beat := 0.85 + 0.15 * sin(_t * (3.0 + 3.0 * _k))  # the heartbeat quickens as you get closer to 0
	_mat.set_shader_parameter("k", _k * beat)
	_mat.set_shader_parameter("flash", _flash)
	visible = _k > 0.001 or _flash > 0.001
