shader_type canvas_item;
// A Power card dissolving into its effect: it vanishes from one side to the other (`from` = the side that goes
// first), along a ragged, noisy front with a glowing edge in the power's colour (fire burns up from the bottom,
// water melts down from the top, wind blows away from the left...).

uniform float progress = 0.0;            // 0: whole .. ~1.1: gone
uniform vec2 from = vec2(0.0, 1.0);       // the side that goes first (UV direction from the centre)
uniform vec4 edge_color : source_color = vec4(1.0, 0.6, 0.2, 1.0);
uniform float raggedness = 0.35;          // how much noise bends the front
uniform float edge_width = 0.07;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	float t = 0.5 - dot(UV - vec2(0.5), normalize(from)) ;  // 0 on the side that goes first .. 1 on the other
	float n = noise(UV * 9.0) * 0.6 + noise(UV * 23.0) * 0.4;
	float d = t * (1.0 - raggedness) + n * raggedness;
	if (d < progress) {
		c.a = 0.0;
	} else if (d < progress + edge_width) {
		float k = 1.0 - (d - progress) / edge_width;  // 1 right at the front
		c.rgb = mix(c.rgb, edge_color.rgb * 1.6, k);
		c.a = max(c.a, k * edge_color.a);
	}
	COLOR = c;
}
