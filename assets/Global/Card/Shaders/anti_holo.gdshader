shader_type canvas_item;
// Anti-spell cards, a negative like Balatro's: the LIGHTNESS of everything under this overlay is flipped (light
// parchment turns deep, dark ink turns bright) but each colour keeps its hue, so red stays red and gold stays gold.
// Colours get a little more vivid, the darks lean cool blue-violet, the hue drifts very slightly, and a faint
// shimmer slides across now and then. (The Essence orbs are drawn above this, in their true colours.)

uniform sampler2D screen_tex : hint_screen_texture, filter_linear;
uniform vec2 size = vec2(250.0, 196.0);
uniform float radius = 10.0;

float rounded_box(vec2 p, vec2 half_size, float r) {
	vec2 q = abs(p) - half_size + vec2(r);
	return length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - r;
}

vec3 rgb2hsl(vec3 c) {
	float mx = max(c.r, max(c.g, c.b));
	float mn = min(c.r, min(c.g, c.b));
	float l = (mx + mn) * 0.5;
	float d = mx - mn;
	if (d < 0.00001) {
		return vec3(0.0, 0.0, l);
	}
	float s = l > 0.5 ? d / (2.0 - mx - mn) : d / (mx + mn);
	float h;
	if (mx == c.r) {
		h = (c.g - c.b) / d + (c.g < c.b ? 6.0 : 0.0);
	} else if (mx == c.g) {
		h = (c.b - c.r) / d + 2.0;
	} else {
		h = (c.r - c.g) / d + 4.0;
	}
	return vec3(h / 6.0, s, l);
}

float hue2rgb(float p, float q, float t) {
	t = fract(t);
	if (t < 1.0 / 6.0) return p + (q - p) * 6.0 * t;
	if (t < 0.5) return q;
	if (t < 2.0 / 3.0) return p + (q - p) * (2.0 / 3.0 - t) * 6.0;
	return p;
}

vec3 hsl2rgb(vec3 hsl) {
	if (hsl.y < 0.00001) {
		return vec3(hsl.z);
	}
	float q = hsl.z < 0.5 ? hsl.z * (1.0 + hsl.y) : hsl.z + hsl.y - hsl.z * hsl.y;
	float p = 2.0 * hsl.z - q;
	return vec3(hue2rgb(p, q, hsl.x + 1.0 / 3.0), hue2rgb(p, q, hsl.x), hue2rgb(p, q, hsl.x - 1.0 / 3.0));
}

void fragment() {
	vec2 px = UV * size;
	float inside = 1.0 - smoothstep(-1.0, 0.5, rounded_box(px - size * 0.5, size * 0.5, radius));
	vec3 hsl = rgb2hsl(texture(screen_tex, SCREEN_UV).rgb);
	hsl.z = 1.0 - hsl.z;  // flip the lightness, keep the hue
	hsl.y = min(1.0, hsl.y * 1.2 + 0.04);  // a touch more vivid
	hsl.x = fract(hsl.x + 0.015 * sin(TIME * 0.6 + UV.y * 3.0));  // the hue drifts, barely
	vec3 col = hsl2rgb(hsl);
	// the darks (the flipped parchment) go completely black; bright text and the mid-tones (the name box) keep their
	// own colour
	float dark = 1.0 - hsl.z;
	col = mix(col, vec3(0.0), smoothstep(0.55, 0.8, dark));
	// a faint shimmer sliding across every few seconds
	float sweep = fract(TIME * 0.18) * 2.4 - 0.7;
	float sheen = smoothstep(0.1, 0.0, abs(UV.x * 0.85 - UV.y * 0.45 - sweep));
	col += sheen * vec3(0.10, 0.12, 0.2);
	COLOR = vec4(col, inside);
}
