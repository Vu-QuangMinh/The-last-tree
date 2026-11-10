class_name MinhParts
extends RefCounted
## Theme MinhHUD: the parts of the HUD that are not drawn by NewUiLayout.Back (they have to stand over or between other things of the screen). Places, sizes and the drawing order are page 2
## of assets/Puppet/UI/MinhHUD/MinhHUD.pdf; Hud2Layout holds the numbers of the rest.
##  Layer: pictures at fixed places of the screen on one z (the glass over the artifacts and the bottles, the front of the Chant tray, the hub).
##  Disc:  the round Chant / Pass button: one picture of the whole button (pressed on the Chant part, on the Pass part), and once the chant is spoken it FLIPS into the Release button: the
##         face is squashed to a thin ellipse on the black behind it and opens again with the other face, the brass rim stays.
##  Cap:   the hub's centre cut to a small circle, over the lever's pivot.

const BTN := Rect2(742.786, 839.401, 200.0, 199.793)  # the round button's pictures (they are all this size); its face is the circle inside the rim
const FACE_R := 0.4334  # the face's radius, in picture widths (86.68 of 200)
const FLIP_TIME := 0.42
const BLACK := Color(0.137, 0.122, 0.125)  # what is behind the face while it is turned
const HUB := Rect2(1688.539, 859.351, 65.032, 64.925)
const CAP_R := 6.74
const FOLDER := "Chant Button/"

## The bottle cabinet's glass is blended Soft Light over what it covers (the PDF's blend mode); Godot's canvas has no such blend, so a shader does it.
const SOFT_LIGHT := """shader_type canvas_item;
uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;
vec3 soft(vec3 cb, vec3 cs) {
	vec3 d = mix(sqrt(cb), ((16.0 * cb - 12.0) * cb + 4.0) * cb, step(cb, vec3(0.25)));
	return mix(cb + (2.0 * cs - 1.0) * (d - cb), cb - (1.0 - 2.0 * cs) * cb * (1.0 - cb), step(cs, vec3(0.5)));
}
void fragment() {
	vec4 s = texture(TEXTURE, UV);
	vec3 cb = texture(screen_tex, SCREEN_UV).rgb;
	COLOR = vec4(mix(cb, soft(cb, s.rgb), s.a * COLOR.a), 1.0);
}
"""


class Layer extends Control:
	var items: Array = []  # [picture name, Rect2 on the screen]

	func _init(z: int, list: Array, soft_light := false) -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		size = Vector2(1920.0, 1080.0)
		z_index = z
		items = list
		texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		if soft_light:
			var sh := Shader.new()
			sh.code = MinhParts.SOFT_LIGHT
			var m := ShaderMaterial.new()
			m.shader = sh
			material = m

	func _draw() -> void:
		for it in items:
			var t := UiSkin.tex(it[0])
			if t != null:
				draw_texture_rect(t, it[1], false)


class Cap extends Control:
	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		size = Vector2(1920.0, 1080.0)
		texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS

	func _draw() -> void:
		var t := UiSkin.tex("minhhud_hub")
		if t == null:
			return
		var c: Vector2 = Hud2Layout.M_LOOP_C
		var pts := PackedVector2Array()
		var uvs := PackedVector2Array()
		for k in 24:
			var p := c + Vector2.from_angle(TAU * k / 24.0) * MinhParts.CAP_R
			pts.append(p)
			uvs.append((p - MinhParts.HUB.position) / MinhParts.HUB.size)
		draw_polygon(pts, PackedColorArray([Color.WHITE]), uvs, t)


class Disc extends Control:
	var kind := "chant"  # which face it wears (the one it flips to once the flip is over)
	var press := 0  # 0 as it is, 1 under the mouse, 2 the Chant (or Release) part pressed, 3 the Pass part pressed
	var enabled := true:
		set(v):
			if v != enabled:
				enabled = v
				queue_redraw()
	var glow := 0.0  # 0..1: the Release pulse
	var _w := 1.0  # the face's width, 1 = whole, 0 = edge on
	var _shown := "chant"
	var _tw: Tween

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		size = Vector2(1920.0, 1080.0)
		texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS

	## Wear the face of `k` ("chant" or "release"): at once, or by flipping.
	func set_kind(k: String, flip := true) -> void:
		if k == kind:
			return
		var old := kind
		kind = k
		if _tw != null and _tw.is_valid():
			_tw.kill()
		if not flip or not is_inside_tree():
			_shown = k
			_w = 1.0
			queue_redraw()
			return
		_shown = old
		_tw = create_tween()
		_tw.tween_method(_flip_step, 0.0, 1.0, MinhParts.FLIP_TIME).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		_tw.tween_callback(_flip_end)

	func flipping() -> bool:
		return _tw != null and _tw.is_valid() and _tw.is_running()

	func _flip_step(t: float) -> void:
		_w = absf(cos(PI * t))
		_shown = kind if t >= 0.5 else _shown
		queue_redraw()

	func _flip_end() -> void:
		_w = 1.0
		_shown = kind
		queue_redraw()

	func set_press(k: int) -> void:
		if k != press:
			press = k
			queue_redraw()

	func _face() -> String:
		if _shown == "release":
			return MinhParts.FOLDER + ("release_button_pressed" if press >= 2 and _w >= 0.999 else "release_button_unpressed")
		if press == 2 and _w >= 0.999:
			return MinhParts.FOLDER + "Chant_button_pressed"
		if press == 3 and _w >= 0.999:
			return MinhParts.FOLDER + "Pass_button_unpressed"
		return MinhParts.FOLDER + "Chant_button_unpressed"

	func _draw() -> void:
		var t := UiSkin.tex(_face())
		if t == null:
			return
		var r := MinhParts.BTN
		var c := r.get_center()
		var fr := MinhParts.FACE_R * r.size.x
		var tint := Color.WHITE
		if press == 1:
			tint = Hud2Layout.tint_of("hover")
		if not enabled:
			tint = Hud2Layout.tint_of("disabled")
		tint = Color(tint.r * (1.0 + 0.45 * glow), tint.g * (1.0 + 0.38 * glow), tint.b * (1.0 + 0.15 * glow), 1.0)
		if _w < 0.999:
			draw_circle(c, fr, MinhParts.BLACK)
		var n := 48
		var pts := PackedVector2Array()
		var uvs := PackedVector2Array()
		var cols := PackedColorArray()
		for k in n:
			var a := TAU * k / n
			pts.append(c + Vector2(cos(a) * fr * _w, sin(a) * fr))
			uvs.append(Vector2(0.5 + cos(a) * MinhParts.FACE_R, 0.5 + sin(a) * MinhParts.FACE_R))
			cols.append(tint)
		if _w > 0.01:
			draw_polygon(pts, cols, uvs, t)
		# the rim: the picture's ring between the face's edge and its own edge
		var segs := 72
		var ro := r.size.x * 0.5
		for k in segs:
			var a0 := TAU * k / segs
			var a1 := TAU * (k + 1) / segs
			var d0 := Vector2(cos(a0), sin(a0))
			var d1 := Vector2(cos(a1), sin(a1))
			var q := PackedVector2Array([c + d0 * fr, c + d0 * ro, c + d1 * ro, c + d1 * fr])
			var qu := PackedVector2Array()
			for p in q:
				qu.append((p - r.position) / r.size)
			draw_polygon(q, PackedColorArray([tint, tint, tint, tint]), qu, t)
