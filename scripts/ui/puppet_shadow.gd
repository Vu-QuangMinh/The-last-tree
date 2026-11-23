class_name PuppetShadow
extends Control
## The soft shadow a Puppet Stage enemy throws on the floor behind it: its own silhouette laid down on the boards, dark at the feet and fading towards the head,
## blurred by a shader (one pass, a ring of taps over the picture's alpha, so no outlines stack up). Creature keeps it as a child that draws BEHIND it, and
## feeds it the feet and the head every frame from the puppet's swing, so the shadow sways with the enemy.

const SHADER := """
shader_type canvas_item;
uniform float blur = 0.03;  // radius of the blur, in fractions of the picture
void fragment() {
	float a = 0.0;
	float n = 0.0;
	for (int ring = 0; ring < 3; ring++) {
		float r = blur * float(ring + 1) / 3.0;
		int taps = 6 + ring * 4;
		for (int i = 0; i < taps; i++) {
			float ang = 6.2831853 * (float(i) + 0.5 * float(ring)) / float(taps);
			a += texture(TEXTURE, UV + vec2(cos(ang), sin(ang)) * r).a;
			n += 1.0;
		}
	}
	a = (a + texture(TEXTURE, UV).a * 2.0) / (n + 2.0);
	COLOR = vec4(0.0, 0.0, 0.0, smoothstep(0.0, 0.85, a) * COLOR.a);
}
"""

static var _shader: Shader

var tex: Texture2D
var feet := Vector2.ZERO  # the middle of the feet, in the creature's coordinates
var head_dx := 0.0  # how far (px) the head's shadow lies to the right of the feet's
var side := 0.0  # the picture's width
var strength := 1.0


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	show_behind_parent = true
	if _shader == null:
		_shader = Shader.new()
		_shader.code = SHADER
	var m := ShaderMaterial.new()
	m.shader = _shader
	material = m


## Called by Creature (from its _draw) with where the puppet stands now.
func place(p_tex: Texture2D, p_feet: Vector2, p_head_dx: float, p_side: float, p_strength := 1.0) -> void:
	tex = p_tex
	feet = p_feet
	head_dx = p_head_dx
	side = p_side
	strength = p_strength
	visible = tex != null and side > 1.0
	queue_redraw()


func _draw() -> void:
	if tex == null or side <= 1.0:
		return
	var depth := side * 0.5  # how far back on the floor the head's shadow reaches
	var m := 0.05  # margin around the picture for the blur to fade out in
	var w := side * (1.0 + 2.0 * m)
	var d := depth * (1.0 + 2.0 * m)
	var lean := head_dx
	var near := Color(0, 0, 0, 0.55 * strength)  # (at the feet)
	var far := Color(0, 0, 0, 0.16 * strength)  # (at the head)
	var y0 := -d + depth * m  # (the head end, with its margin)
	var pts := PackedVector2Array([
		feet + Vector2(-w / 2.0 + lean, y0), feet + Vector2(w / 2.0 + lean, y0),
		feet + Vector2(w / 2.0, depth * m), feet + Vector2(-w / 2.0, depth * m)])
	var uv := PackedVector2Array([Vector2(-m, -m), Vector2(1.0 + m, -m), Vector2(1.0 + m, 1.0 + m), Vector2(-m, 1.0 + m)])
	draw_polygon(pts, PackedColorArray([far, far, near, near]), uv, tex)
