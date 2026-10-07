shader_type canvas_item;
// Fusion: a black hole swallows the two cards. Shown over a picture of the cards (a SubViewport): every pixel looks
// up where it came from. Near the centre things spin much faster than far away (the twist falls off with 1 / r), so a
// card is sheared into a long thin strand wound in a spiral (spaghettified); `pull` drags everything inwards; inside
// `hole` it's black, with a glowing ring at the edge (the event horizon).

uniform vec2 center = vec2(960.0, 430.0);  // in pixels of the picture
uniform vec2 size = vec2(1920.0, 1080.0);  // the picture's size in pixels
uniform float pull = 0.0;   // 0: as it is .. 1: all of it gone into the hole
uniform float twist = 0.0;  // how far it's wound up
uniform float hole = 0.0;   // radius of the black hole, in pixels

void fragment() {
	vec2 p = UV * size;
	vec2 d = p - center;
	float r = length(d);
	float a = atan(d.y, d.x);
	// where this pixel came from: further out (pulled in), and turned back along the spiral
	float s = max(0.015, 1.0 - pull);
	float src_r = r / s + pull * hole * 0.8;
	float src_a = a - twist * 180.0 / (r + 24.0);
	vec2 suv = (center + vec2(cos(src_a), sin(src_a)) * src_r) / size;
	vec4 col = vec4(0.0);
	if (suv.x >= 0.0 && suv.x <= 1.0 && suv.y >= 0.0 && suv.y <= 1.0) {
		col = texture(TEXTURE, suv);
	}
	// the closer to the hole, the hotter it burns (stretched light), fading as it crosses in
	float heat = hole > 1.0 ? exp(-max(0.0, r - hole) / (hole * 1.2)) : 0.0;
	col.rgb = mix(col.rgb, vec3(1.0, 0.85, 1.0), heat * 0.55 * col.a);
	col.a *= smoothstep(hole * 0.95, hole * 1.35, r);
	// the event horizon: a thin bright ring, purple outside and white-hot at the edge
	if (hole > 1.0) {
		float w = hole * 0.18 + 2.0;
		float ring = exp(-pow((r - hole * 1.08) / w, 2.0));
		float flicker = 0.85 + 0.15 * sin(a * 7.0 + TIME * 12.0);
		vec3 ring_col = mix(vec3(0.6, 0.35, 1.0), vec3(1.0, 0.96, 0.9), ring);
		col.rgb = mix(col.rgb, ring_col, ring * flicker);
		col.a = max(col.a, ring * flicker);
		float disk = 1.0 - smoothstep(hole * 0.92, hole, r);
		col = mix(col, vec4(0.0, 0.0, 0.0, 1.0), disk);
	}
	COLOR = col;
}
