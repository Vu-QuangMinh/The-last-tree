shader_type canvas_item;
// Ephemeral (conjured) cards, "bad reception": what's under this overlay (the card, drawn a little see-through)
// gets faint rolling scanlines, and every second or two a short glitch: bands of the picture jump sideways, the
// colours split into red / green / blue fringes and a burst of static flickers over it. `fizzle` (0..1) is the
// static taking over when the card disappears. Corners are rounded like the card's (size / radius in pixels).

uniform sampler2D screen_tex : hint_screen_texture, filter_linear;
uniform vec2 size = vec2(250.0, 196.0);
uniform float radius = 10.0;
uniform float seed = 0.0;  // so cards don't glitch in step
uniform float fizzle = 0.0;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float rounded_box(vec2 p, vec2 half_size, float r) {
	vec2 q = abs(p) - half_size + vec2(r);
	return length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - r;
}

void fragment() {
	vec2 px = UV * size;
	float inside = 1.0 - smoothstep(-1.0, 0.5, rounded_box(px - size * 0.5, size * 0.5, radius));
	float t = TIME + seed * 13.7;
	// a glitch for a moment in every ~1.6 s (a little irregular), stronger while fizzling
	float cyc = fract(t / 1.6 + hash(vec2(floor(t / 1.6), seed)) * 0.3);
	float g = max(step(cyc, 0.09), fizzle);
	// bands of the picture jump sideways
	float band = floor(px.y / 9.0);
	float frame = floor(t * 24.0);
	float jump = (hash(vec2(band, frame)) - 0.5) * 14.0 * g * step(0.55, hash(vec2(band * 3.1, frame + 7.0)));
	vec2 base = SCREEN_UV + vec2(jump, 0.0) * SCREEN_PIXEL_SIZE;
	// red / green / blue split
	float split = (0.8 + 3.5 * g) * SCREEN_PIXEL_SIZE.x;
	vec3 col;
	col.r = texture(screen_tex, base + vec2(split, 0.0)).r;
	col.g = texture(screen_tex, base).g;
	col.b = texture(screen_tex, base - vec2(split, 0.0)).b;
	// faint scanlines rolling down
	col *= 0.9 + 0.1 * sin((px.y - t * 30.0) * 1.3);
	// static: a hint always, a burst while glitching, all of it as it fizzles away
	float n = hash(px + vec2(frame * 1.7, frame * 3.3));
	col = mix(col, vec3(n), clamp(0.05 + 0.4 * g * (1.0 - fizzle) + fizzle * 0.95, 0.0, 1.0));
	COLOR = vec4(col, inside);
}
