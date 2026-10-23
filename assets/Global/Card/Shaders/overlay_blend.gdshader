shader_type canvas_item;
// Photoshop's "Overlay" blend: where what is behind it is dark the picture multiplies (2 * back * picture), where it is light it screens (1 - 2 * (1 - back) * (1 - picture)).
// The picture's own alpha says where it applies. Used for the liquid of the HP tube.

uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;
uniform float strength : hint_range(0.0, 1.0) = 1.0;

void fragment() {
	vec4 src = texture(TEXTURE, UV) * COLOR;
	vec3 dst = textureLod(screen_tex, SCREEN_UV, 0.0).rgb;
	vec3 lo = 2.0 * dst * src.rgb;
	vec3 hi = 1.0 - 2.0 * (1.0 - dst) * (1.0 - src.rgb);
	vec3 res = vec3(dst.r < 0.5 ? lo.r : hi.r, dst.g < 0.5 ? lo.g : hi.g, dst.b < 0.5 ? lo.b : hi.b);
	COLOR = vec4(mix(dst, res, src.a * strength), 1.0);
}
