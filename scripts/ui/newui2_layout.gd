class_name NewUi2Layout
extends RefCounted
## Theme NewUI Ver2 ("newui2"): the New UI HUD (same code path, NewUiLayout.use(false, false, true)) laid out as page 1 of assets/Puppet/UI/NewUiV2/HUD.pdf (1920 x 1080 = the screen, one pt = one px);
## page 2 of that PDF holds the user's notes (what each picture does).
## Every number below was read off the PDF: the place, size and turn of each picture (its matrix: a picture can be mirrored or turned) and the drawing order (= the z order). The pictures are the
## user's (assets/Puppet/UI/NewUiV2/, FULL size, never resized: the game scales them when it draws them; tools/extract_newui2_pdf.py takes them out of the PDF).
## Back to front on the page: the stage, two plates under the machine and the cabinet, the left brass hose, the long white plate, the left wooden plate, the right hose, the HP glass tube,
## the machine's tube (mirrored) with its two connectors, the funnel, the machine body, the ten Chant sockets, Clear / Chant / Pass, the artifact cabinet, the Bag tray with its hole, the bottle rack
## (3 or 5 bottles), Menu, the paper with the Act / Floor / Turn lines, and the debuff rings (as many as there are debuffs).

# [a, b, c, d, e, f]: the matrix that puts the picture's unit square on the page (a plain picture is [w, 0, 0, h, x, y])
const M_PLATE_A := [376.2, 0.0, 0.0, -209.97, -4.4, 1085.19]  # (the small blue plate in the left corner, turned upside down)
const M_PLATE_B := [-376.2, 0.0, 0.0, -209.97, 1924.26, 1085.19]  # (the same plate mirrored, in the right corner under the cabinet)
const PLATE_RED := Rect2(1235.8, 923.64, 357.07, 185.91)  # the red plate under the machine
const M_HOSE_LEFT := [0.0, -123.97, 45.9, 0.0, 596.79, 1020.42]
const M_PLATE_LONG := [-1036.67, 0.0, 0.0, 202.64, 1272.64, 877.91]  # (mirrored)
const M_HOSE_RIGHT := [123.97, 0.0, 0.0, 45.9, 1227.51, 885.23]
const M_PAPER := [-12.01, -149.24, 83.3, -6.71, 27.12, 1031.17]  # (turned a quarter turn and a bit)
const ART_CABINET := Rect2(1575.74, 887.37, 328.04, 182.96)
const BAG_TRAY := Rect2(584.42, 1000.2, 604.34, 65.47)
const TUBE_HOLE := Rect2(1121.38, 1007.28, 51.3, 51.3)  # the hole at the tray's right end: the Essence come up out of it
const RACK5 := Rect2(61.08, 909.27, 276.32, 148.05)
const RACK3 := Rect2(132.36, 909.27, 205.05, 148.05)
const MENU := Rect2(19.19, 1002.87, 92.39, 62.38)
const CLEAR := Rect2(1178.6, 946.8, 51.2, 51.3)
const CHANT := Rect2(476.5, 1001.6, 83.5, 60.8)
const PASS := Rect2(390.8, 1001.6, 60.7, 60.8)
const HP_SPRITE := Rect2(627.76, 825.05, 632.67, 176.44)  # the HP glass tube's picture (the glass itself is a thin strip in the middle of it)
const HP_BAR_VISIBLE := Rect2(633.6, 892.95, 613.86, 40.43)  # the part of that picture that is not clear: the node of the HP bar stands there (the rest would block the mouse)
const HP_GLASS := Rect2(666.26, 898.95, 548.6, 29.4)  # the glass between the two brass caps: the liquid lies in it
const SOCKET0 := Vector2(600.49, 946.77)  # the first Chant socket's top left (51.43 wide, 57.862 apart)
const SOCKET_PX := 51.43
const SOCKET_STEP := 57.862
const REST0 := 626.2  # the first resting Essence's middle in the Bag tray (the tray's row y 1032.93 = the machine tube's)
const ROW_Y := 1032.93
const MOUTH_X_ABS := 1147.03  # the hole's middle
const MACHINE_BODY := Rect2(1305.57, 927.04, 204.85, 152.96)
const MACHINE_FUNNEL := Rect2(1403.51, 896.42, 86.39, 34.3)  # the funnel's lower layer (under the Essence)
const FUNNEL_UPPER := Rect2(1403.5, 900.5, 86.4, 30.3)  # its upper layer (over the Essence: they sink in between)
const FUNNEL_MARK := Vector2(1458.25, 908.15)  # the middle of the example Essence the user put in the funnel: where a bonus Essence flies to
const MACHINE_TUBE := Rect2(1195.84, 1008.59, 92.9, 48.67)  # drawn mirrored (flange on the left)
const CONNECTORS := [[Rect2(1285.93, 1005.46, 23.23, 52.45), false]]  # the tube's end at the machine [place, mirrored] (over the Essence)
const M_CONNECTOR_BAG := [-23.23, 0.0, 0.0, 52.45, 1200.37, 1005.46]  # its end at the Bag: lies UNDER the Bag tray (drawn by Back before it)
const BAG_EDGE_X := 1188.76  # the Bag tray's right end: the Essence go in under it from the tube and come up out of the hole
const ART_FEET := [964.6, 1010.6]  # the cabinet's two steps: where an artifact's feet stand (y); the first artifact's middle (x) and the step between two
const ART_C0 := 1652.5
const ART_STEP := 43.9
const ART_PX_V2 := 34.0
const LAMPS := [Vector2(1700.2, 901.5), Vector2(1789.7, 901.5)]  # the two lamps inside the cabinet's top (they shine down on the artifacts)
const RACK3_C0 := 174.96  # a rack's first bottle (middle x) and the step; the bottles stand in the cups, their middles at this y
const RACK3_STEP := 61.0
const RACK5_C0 := 100.46
const RACK5_STEP := 50.0
const BOTTLE_CY := 1005.0  # (2026-11-11: bigger bottles standing on the lower yellow tray, their necks at the upper tray)
const BOTTLE_PX_V2 := 54.0
const DEBUFF0 := Vector2(377.26, 937.23)  # the debuff rings: four to a row, the first row (the lower one) is filled first, the next goes up
const DEBUFF_STEP_X := 36.24
const DEBUFF_STEP_Y := 35.88
const DEBUFF_RING := 33.3
const INFO_ANGLE := -6.3  # the lines of the paper (degrees), their font and colour
const INFO_ORIGIN := Vector2(45.4, 937.9)  # the first line's left end on its baseline
const INFO_SIZE := 15
const INFO_LINE := 18.3
const INFO_COLOR := Color(0.2, 0.173, 0.161)


static func apply() -> void:
	var L = NewUiLayout
	L.BAG_AT = Vector2(REST0 - (PuppetLayout.REST_X + 26.0), ROW_Y - PuppetLayout.AXIS_Y)
	L.CHANT_AT = Vector2(SOCKET0.x + SOCKET_PX / 2.0 - (PuppetLayout.RING_X0 + 26.0) - L.BAG_AT.x, SOCKET0.y + SOCKET_PX / 2.0 - PuppetLayout.RING_CY - L.BAG_AT.y)
	L.RING_PX = SOCKET_PX
	L.RING_STEP = SOCKET_STEP
	var origin: Vector2 = L.BAG_AT + L.CHANT_AT
	L.BTN_CHANT = Rect2(CHANT.position - origin, CHANT.size)
	L.BTN_CLEAR = Rect2(CLEAR.position - origin, CLEAR.size)
	L.BTN_PASS = Rect2(PASS.position - origin, PASS.size)
	L.MENU_BTN = MENU
	L.ACT_TEXT = Rect2(INFO_ORIGIN.x - 2.0, INFO_ORIGIN.y - INFO_SIZE - 4.0, 76.0, 3.0 * INFO_LINE + 8.0)
	L.ART_CELL = Vector2(ART_STEP, ART_FEET[1] - ART_FEET[0])
	L.ART_COLS = 5
	L.ART_PX = ART_PX_V2
	L.ART_AT = Vector2(ART_C0 - L.ART_PX / 2.0 - (L.ART_CELL.x - L.ART_PX) / 2.0, ART_FEET[0] - L.ART_PX - (L.ART_CELL.y - L.ART_PX) / 2.0)
	set_rack(Bottles.BASE_SLOTS)
	L.HP_BAR = HP_BAR_VISIBLE
	L.HP_FILL = Rect2(HP_GLASS.position - HP_BAR_VISIBLE.position, HP_GLASS.size)
	L.HP_CAP = Rect2(0.0, 0.0, 0.0, 0.0)
	L.DEBUFF_AT = DEBUFF0
	L.DEBUFF_STEP = DEBUFF_STEP_X
	L.DEBUFF_ROW = DEBUFF_STEP_Y
	L.DEBUFF_AREA_ROWS = 2
	L.DEBUFF_PX = DEBUFF_RING
	L.DEBUFF_COLS = 4
	L.MOUTH_X = MOUTH_X_ABS - L.BAG_AT.x
	L.REST_END = L.MOUTH_X - 28.0
	L.TUBE_ROW_Y = PuppetLayout.AXIS_Y
	# the machine: the old machine's px scaled so its body is as wide as the page's, then moved so the body lands on the page's
	L.MACHINE_SCALE = MACHINE_BODY.size.x / PuppetSlotMachine.BODY.size.x
	var body_local: Vector2 = PuppetSlotMachine.BODY.position + PuppetLayout.MACHINE_SHIFT - PuppetLayout.BAG_AT
	L.MACHINE_POS = MACHINE_BODY.position - L.BAG_AT - body_local * L.MACHINE_SCALE
	L.LEVER_SHIFT = Vector2(0.0, 1.5)
	L.SPELL_BOTTOM = 863.1
	L.SPELL_CENTER_X = 926.25


## The bottle rack in use: the three-bottle one, or the five-bottle one when a fifth slot is carried (Bandolier). Moves the bottle slots to its cups.
static func set_rack(slots: int) -> void:
	var L = NewUiLayout
	var five := slots > 3
	var step: float = RACK5_STEP if five else RACK3_STEP
	var c0: float = RACK5_C0 if five else RACK3_C0
	L.BOTTLE_CELL = Vector2(step, 44.0)
	L.BOTTLE_PX = minf(BOTTLE_PX_V2, step - 2.0)
	L.BOTTLE_AT = Vector2(c0 - L.BOTTLE_PX / 2.0 - (L.BOTTLE_CELL.x - L.BOTTLE_PX) / 2.0, BOTTLE_CY - L.BOTTLE_PX / 2.0 - (L.BOTTLE_CELL.y - L.BOTTLE_PX) / 2.0)


## The rack's upper layer (the user's picture of the same rack with only what lies over the bottles): on the rack in use.
static func place_rack_upper(t: TextureRect, slots: int) -> void:
	var five := slots > 3
	t.texture = UiSkin.tex("nu2_rack5_upper" if five else "nu2_rack3_upper")
	var r: Rect2 = RACK5 if five else RACK3
	t.position = r.position
	t.size = r.size


## The funnel and the tube in the machine's own (old) px / in strip px, for SlotMachine.
static func funnel_old() -> Rect2:
	var L = NewUiLayout
	var s: float = L.MACHINE_SCALE
	var shift: Vector2 = PuppetLayout.MACHINE_SHIFT - PuppetLayout.BAG_AT
	return Rect2(((MACHINE_FUNNEL.position - L.BAG_AT) - L.MACHINE_POS) / s - shift, MACHINE_FUNNEL.size / s)


## The funnel's two layers for SlotMachine (strip px), and the place a bonus Essence goes into it.
static func funnel_layers() -> Array:
	var b: Vector2 = NewUiLayout.BAG_AT
	return [["slot_funnel_top", Rect2(MACHINE_FUNNEL.position - b, MACHINE_FUNNEL.size), "behind"], ["slot_funnel_upper", Rect2(FUNNEL_UPPER.position - b, FUNNEL_UPPER.size), "over"]]


static func funnel_mouth() -> Vector2:
	return FUNNEL_MARK - NewUiLayout.BAG_AT


static func tube_strip() -> Rect2:
	return Rect2(MACHINE_TUBE.position - NewUiLayout.BAG_AT, MACHINE_TUBE.size)


## The tube's two connectors in strip px: [[Rect2, mirrored], ...]
static func connectors_strip() -> Array:
	var out := []
	for c in CONNECTORS:
		out.append([Rect2(c[0].position - NewUiLayout.BAG_AT, c[0].size), c[1]])
	return out


static func _pic(c: Control, name: String, r: Rect2, mod := Color.WHITE) -> void:
	var t := UiSkin.tex(name)
	if t != null:
		c.draw_texture_rect(t, r, false, mod)
	else:
		c.draw_rect(r, NewUiLayout.DARK)


## A picture put on the page by its PDF matrix (it may be mirrored or turned).
static func _pic_m(c: Control, name: String, m: Array) -> void:
	var t := UiSkin.tex(name)
	if t == null:
		return
	c.draw_set_transform_matrix(Transform2D(Vector2(m[0], m[1]), Vector2(m[2], m[3]), Vector2(m[4], m[5])))
	c.draw_texture_rect(t, Rect2(0.0, 0.0, 1.0, 1.0), false)
	c.draw_set_transform_matrix(Transform2D.IDENTITY)


## What Back draws (the layers under the HP glass tube, the artifacts, the bottles, the Chant sockets and the buttons; the machine, the sockets and the buttons are nodes of their own).
static func draw(c) -> void:
	_pic(c, "nu2_plate_red", PLATE_RED)
	_pic_m(c, "nu2_hose", M_HOSE_LEFT)
	_pic_m(c, "nu2_plate_long", M_PLATE_LONG)
	_pic_m(c, "nu2_hose", M_HOSE_RIGHT)
	_pic_m(c, "nu2_plate_small", M_PLATE_A)
	_pic_m(c, "nu2_plate_small", M_PLATE_B)
	_pic(c, "nu2_art_cabinet", ART_CABINET)
	_pic_m(c, "nu2_connector", M_CONNECTOR_BAG)
	_pic(c, "nu_bag_tray", BAG_TRAY)
	_pic(c, "nu2_tube_hole", TUBE_HOLE)
	if c.bottle_slots > 3:
		_pic(c, "nu2_rack5", RACK5)
	else:
		_pic(c, "nu2_rack3", RACK3)
	_pic(c, "nu2_menu", MENU, [Color.WHITE, NewUiLayout.MENU_HOVER, NewUiLayout.MENU_DOWN][c.menu_state])
	_pic_m(c, "nu2_paper", M_PAPER)
	var rows := maxi(1, ceili(c.debuffs / float(NewUiLayout.DEBUFF_COLS)))
	var sock := UiSkin.tex("nu_debuff_ring")
	for k in c.debuffs:
		var at := NewUiLayout.debuff_slot(k, rows)
		if sock != null:
			c.draw_texture_rect(sock, Rect2(at, Vector2.ONE * NewUiLayout.DEBUFF_PX), false)
		else:
			c.draw_arc(at + Vector2.ONE * NewUiLayout.DEBUFF_PX / 2.0, NewUiLayout.DEBUFF_PX / 2.0, 0.0, TAU, 32, Color(0.8, 0.6, 0.3), 1.5)


## The HP glass tube, over the liquid (`origin` = where the bar's node stands on the page): the glass shows the liquid through it, the brass caps hide the liquid's ends.
static func draw_tube(c: Control, origin: Vector2) -> void:
	var t := UiSkin.tex("nu_hp_lower")
	if t != null:
		c.draw_texture_rect(t, Rect2(HP_SPRITE.position - origin, HP_SPRITE.size), false)


## The Act / Floor / Turn lines on the paper: plain Labels (no text style of the game touches them) of a node of their own, turned as the paper is, in the page's font and colour;
## the first line's left end on its baseline is INFO_ORIGIN.
class PaperText extends Control:
	var text := "":
		set(v):
			text = v
			_rebuild()

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		position = NewUi2Layout.INFO_ORIGIN
		rotation = deg_to_rad(NewUi2Layout.INFO_ANGLE)
		texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR

	func _rebuild() -> void:
		for c in get_children():
			c.queue_free()
			remove_child(c)
		var f := load("res://assets/Global/Fonts/SVN-Desire.otf") as Font
		if f == null or text == "":
			return
		var lines := text.split("\n")
		for i in lines.size():
			var l := Label.new()
			l.text = lines[i]
			l.mouse_filter = Control.MOUSE_FILTER_IGNORE
			l.add_theme_font_override("font", f)
			l.add_theme_font_size_override("font_size", NewUi2Layout.INFO_SIZE)
			l.add_theme_color_override("font_color", NewUi2Layout.INFO_COLOR)
			l.add_theme_constant_override("outline_size", 0)
			l.position = Vector2(0.0, i * NewUi2Layout.INFO_LINE - f.get_ascent(NewUi2Layout.INFO_SIZE))
			add_child(l)


## The paper's text: the game's one-line info ("Act 1 · Floor 2 - Turn 1") as separate lines.
static func info_text(text: String) -> String:
	return text.replace(" · ", "\n").replace(" - ", "\n").replace("\r", "")


## The two lamps of the artifact cabinet: a soft warm light that falls from each lamp down over the artifacts (a shader: smooth cone, gentle halo at the lamp, a faint glow where it lands, a very slow breathing).
## Added on top (additive): it only brightens, and it stays inside the cabinet's rectangle.
class Lights extends ColorRect:
	const SHADER := """
shader_type canvas_item;
render_mode blend_add;
uniform vec2 lamp0 = vec2(0.0);
uniform vec2 lamp1 = vec2(0.0);
uniform vec2 origin = vec2(0.0);
uniform vec2 area = vec2(1.0);
uniform float reach = 135.0;
uniform float floor_y = 1010.0;
uniform vec3 tint : source_color = vec3(1.0, 0.76, 0.42);
uniform float strength = 0.55;

float one(vec2 p, vec2 l, float seed) {
	vec2 d = p - l;
	float breath = 1.0 + 0.05 * sin(TIME * 0.9 + seed) + 0.025 * sin(TIME * 2.3 + seed * 3.1);
	float t = clamp(d.y / reach, 0.0, 1.0);
	float below = smoothstep(-2.0, 6.0, d.y);
	float w = mix(7.0, 58.0, pow(t, 0.8));
	float cone = exp(-2.2 * (d.x * d.x) / (w * w)) * pow(1.0 - t, 1.4) * below;
	float halo = exp(-length(d * vec2(1.0, 1.25)) / 13.0);
	float land = exp(-(d.x * d.x) / (2.0 * 42.0 * 42.0) - pow((p.y - floor_y) / 13.0, 2.0)) * 0.55;
	return (cone * 0.8 + halo * 0.9 + land) * breath;
}

void fragment() {
	vec2 p = origin + UV * area;
	float v = one(p, lamp0, 0.0) + one(p, lamp1, 2.0);
	COLOR = vec4(tint * v * strength, 1.0);
}
"""

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		var r: Rect2 = NewUi2Layout.ART_CABINET
		position = r.position
		size = r.size
		color = Color.WHITE
		z_index = 4  # (over the artifacts, which are at 3)
		var sh := Shader.new()
		sh.code = SHADER
		var m := ShaderMaterial.new()
		m.shader = sh
		m.set_shader_parameter("origin", r.position)
		m.set_shader_parameter("area", r.size)
		m.set_shader_parameter("lamp0", NewUi2Layout.LAMPS[0])
		m.set_shader_parameter("lamp1", NewUi2Layout.LAMPS[1])
		m.set_shader_parameter("floor_y", NewUi2Layout.ART_FEET[1])
		material = m
