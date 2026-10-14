shader_type canvas_item;
// The picture in a spell card's art window, with rounded corners.
// One spell: its art fills the (square) window.
// A fused spell: the window is split down the middle; the left half shows a vertical band of the first parent's
// art, the right half a band of the second parent's, each at full scale (nothing is squeezed) and centred on the
// part of the picture that matters (focus_a / focus_b, 0..1 across the picture). A soft seam joins them.
// Nothing is baked: the two pictures are only drawn together.

uniform float zoom = 1.0;
uniform float radius = 0.07; // as a fraction of the window's side
uniform bool fused = false;
uniform sampler2D tex_b : source_color, filter_linear, repeat_disable;
uniform float focus_a = 0.5;
uniform float focus_b = 0.5;
uniform float seam = 0.025;

void fragment() {
	if (fused) {
		float m = smoothstep(0.5 - seam, 0.5 + seam, UV.x);
		vec2 ua = vec2(focus_a - 0.25 + UV.x, UV.y);
		vec2 ub = vec2(focus_b - 0.25 + (UV.x - 0.5), UV.y);
		vec4 a = texture(TEXTURE, clamp(ua, vec2(0.0), vec2(1.0)));
		vec4 b = texture(tex_b, clamp(ub, vec2(0.0), vec2(1.0)));
		COLOR = mix(a, b, m);
		float line = 1.0 - smoothstep(0.0, 0.007, abs(UV.x - 0.5));
		COLOR.rgb = mix(COLOR.rgb, vec3(1.0, 0.93, 0.75), line * 0.55);
	} else {
		vec2 ts = vec2(textureSize(TEXTURE, 0));
		float ta = ts.x / ts.y;
		vec2 fit = ta < 1.0 ? vec2(1.0, ta) : vec2(1.0 / ta, 1.0);
		COLOR = texture(TEXTURE, 0.5 + (UV - 0.5) * fit / zoom);
	}
	vec2 q = abs(UV - 0.5) - (0.5 - radius);
	float d = length(max(q, vec2(0.0))) + min(max(q.x, q.y), 0.0) - radius;
	float aa = max(fwidth(d), 0.0001);
	COLOR.a *= clamp(0.5 - d / aa, 0.0, 1.0);
}
