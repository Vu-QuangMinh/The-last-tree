class_name Backdrop
extends Control
## Painted background: dusk sky, layered forest silhouettes, the last tree glowing in the middle.
## act changes the mood (1 dusk green, 2 rot purple, 3 winter blue).

var act := 1
## A room's own picture (assets/ui/new/room_<id>.jpg) instead of the act's: main.gd sets it before it shows a room's screens
## (and clears it on the map), so every screen of one room shares it. Empty, or a room without a picture: the act's.
static var room := ""
var tree_glow := true
var _t := 0.0

const SKY := {1: [Color(0.1, 0.16, 0.14), Color(0.28, 0.36, 0.26)], 2: [Color(0.12, 0.08, 0.14), Color(0.34, 0.22, 0.3)], 3: [Color(0.08, 0.1, 0.16), Color(0.4, 0.48, 0.58)]}


var _art_node: TextureRect  # New theme: the painted picture (with its wind shader)

## New theme: a gentle wind. Trees and bushes lean and flutter a little; the ground at the bottom (the log) stays put.
const WIND_SHADER := """
shader_type canvas_item;
uniform float amp = 0.0022;
uniform float ground = 0.80;
void fragment() {
	float w = 1.0 - smoothstep(0.42, ground, UV.y);
	float gust = sin(TIME * 1.05 + UV.x * 5.0 + UV.y * 2.0);
	float flutter = sin(TIME * 2.2 + UV.x * 17.0 + UV.y * 9.0) * 0.35;
	float sway = (gust + flutter) * amp * w;
	float lift = sin(TIME * 0.9 + UV.x * 7.0) * amp * 0.25 * w;
	COLOR = texture(TEXTURE, UV + vec2(sway, lift));
}
"""


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var room_art: Texture2D = UiSkin.tex("room_" + room) if room != "" else null
	var art: Texture2D = room_art if room_art != null else UiSkin.tex(ART.get(act, ""))
	if art != null:
		_art_node = TextureRect.new()
		_art_node.texture = art
		_art_node.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		_art_node.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		_art_node.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		_art_node.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var sh := Shader.new()
		sh.code = WIND_SHADER
		var mat := ShaderMaterial.new()
		mat.shader = sh
		_art_node.material = mat
		add_child(_art_node)
		if room_art == null:  # (leaves, fireflies and snow belong to the act's own painting)
			var fx := BackdropFx.new()
			fx.act = act
			add_child(fx)


func _process(d: float) -> void:
	_t += d
	queue_redraw()


## New theme: a painted picture for each act
const ART := {1: "bg_act1_dusk_forest", 2: "bg_act2_rot_swamp", 3: "bg_act3_winter_night"}


func _draw() -> void:
	var w := size.x
	var h := size.y
	if _art_node != null:
		return  # the painted picture is its own node
	var sky: Array = SKY.get(act, SKY[1])
	for i in 24:
		var y0 := h * i / 24.0
		draw_rect(Rect2(0, y0, w, h / 24.0 + 1), sky[0].lerp(sky[1], i / 23.0 * 0.9))
	# far hills and three layers of trees
	for layer in 3:
		var base := h * (0.52 + layer * 0.08)
		var col: Color = sky[0].lerp(Color.BLACK, 0.2 + layer * 0.25)
		var pts := PackedVector2Array([Vector2(0, h)])
		var n := 40 + layer * 10
		for i in n + 1:
			var x := w * i / float(n)
			var spike := (sin(i * 12.9898 + layer * 4.1) * 43758.5453)
			spike = spike - floorf(spike)
			var y := base - (20 + spike * (60 + layer * 30)) * (1.0 if i % 2 == 0 else 0.35)
			pts.append(Vector2(x, y))
		pts.append(Vector2(w, h))
		draw_colored_polygon(pts, col)
	# the last tree
	if tree_glow:
		var c := Vector2(w * 0.5, h * 0.62)
		draw_circle(c + Vector2(0, -h * 0.2), h * 0.22, Color(0.55, 0.9, 0.5, 0.05 + 0.02 * sin(_t)))
		draw_rect(Rect2(c.x - 18, c.y - h * 0.2, 36, h * 0.2), Color(0.12, 0.09, 0.07))
		for i in 7:
			var a := -PI / 2 + (i - 3) * 0.32
			var r := h * (0.16 + 0.03 * sin(i * 1.7))
			draw_circle(c + Vector2(0, -h * 0.24) + Vector2.from_angle(a) * r * 0.6, r * 0.55, Color(0.16, 0.3, 0.16, 0.95))
		for i in 12:
			var p := c + Vector2(sin(_t * 0.7 + i * 2.1) * h * 0.2, -h * 0.25 + cos(_t * 0.5 + i) * h * 0.12)
			draw_circle(p, 3, Color(0.75, 1, 0.6, 0.5 + 0.4 * sin(_t * 2 + i)))
	# ground
	draw_rect(Rect2(0, h * 0.8, w, h * 0.2), sky[0].lerp(Color.BLACK, 0.7))
