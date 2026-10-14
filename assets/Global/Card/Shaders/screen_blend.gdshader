shader_type canvas_item;
// Photoshop's "Screen" blend: result = 1 - (1 - picture) * (1 - what is behind it). The picture's own alpha says where it applies, so a sheet
// of glass keeps its see-through look and only ever lightens what is behind it (the balls show through). Used for the machine's glass.

uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;
uniform float strength : hint_range(0.0, 1.0) = 1.0;

void fragment() {
	vec4 src = texture(TEXTURE, UV) * COLOR;
	vec3 dst = textureLod(screen_tex, SCREEN_UV, 0.0).rgb;
	vec3 scr = 1.0 - (1.0 - src.rgb) * (1.0 - dst);
	COLOR = vec4(mix(dst, scr, src.a * strength), 1.0);
}
