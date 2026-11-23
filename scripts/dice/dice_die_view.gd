class_name DiceDieView
extends Control
## Die on Stage: one rolled die in the tray. Drag it onto a card's slot. Pips for 1 to 6, the number past that (a face
## raised by an adjustment). A painted face is that colour (DiceFace.PAINTS); a carved one shows its symbol in the
## corner (DiceFace.CARVES). A purple face that hasn't been rolled again this turn has a small ↻ to roll it again.

signal reroll_pressed(r: int)

const SIZE := 84.0
const REROLL_R := 15.0

var r := -1  # its index in DiceFight.rolled
var value := 1
var paint := ""
var carve := ""
var used := false
var can_reroll := false
var frozen := false  # (Freeze: it was rolled, but can't be used this turn)
var face_down := false  # (Confuse: face down; you see it once you place it)
var ghost := false  # (a handle over a 3D die on the stage, Dice3D: only its ↻ and ❄ are drawn; the die is the 3D one)


static func draw_die(ci: CanvasItem, rect: Rect2, v: int, dim := false, p_paint := "", p_carve := "") -> void:
	var body := Color(0.97, 0.94, 0.86)
	if p_paint != "" and DiceFace.PAINTS.has(p_paint):
		body = DiceFace.PAINTS[p_paint].col
	if dim:
		body = body.lerp(Color(0.5, 0.48, 0.45), 0.6)
	var sb := StyleBoxFlat.new()
	sb.bg_color = body
	sb.set_corner_radius_all(int(rect.size.x * 0.18))
	sb.border_color = Color(0.25, 0.16, 0.1)
	sb.set_border_width_all(3)
	sb.shadow_color = Color(0, 0, 0, 0.35)
	sb.shadow_size = 4
	ci.draw_style_box(sb, rect)
	var pip := Color(0.15, 0.08, 0.05) if body.get_luminance() > 0.45 else Color(0.97, 0.94, 0.86)
	var c := rect.get_center()
	var o := rect.size.x * 0.26
	var pr := rect.size.x * 0.085
	var spots := {1: [Vector2.ZERO], 2: [Vector2(-1, -1), Vector2(1, 1)], 3: [Vector2(-1, -1), Vector2.ZERO, Vector2(1, 1)],
		4: [Vector2(-1, -1), Vector2(1, -1), Vector2(-1, 1), Vector2(1, 1)],
		5: [Vector2(-1, -1), Vector2(1, -1), Vector2.ZERO, Vector2(-1, 1), Vector2(1, 1)],
		6: [Vector2(-1, -1), Vector2(1, -1), Vector2(-1, 0), Vector2(1, 0), Vector2(-1, 1), Vector2(1, 1)]}
	var font := ThemeDB.fallback_font
	if spots.has(v):
		for s in spots[v]:
			ci.draw_circle(c + s * o, pr, pip)
	else:
		var fs := int(rect.size.x * 0.5)
		var w := font.get_string_size(str(v), HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		ci.draw_string(font, c + Vector2(-w / 2.0, fs * 0.35), str(v), HORIZONTAL_ALIGNMENT_LEFT, -1, fs, pip)
	if p_carve != "" and DiceFace.CARVES.has(p_carve):  # (the carving: a little badge in the bottom-left corner)
		var bc := rect.position + Vector2(rect.size.x * 0.2, rect.size.y * 0.8)
		ci.draw_circle(bc, rect.size.x * 0.17, Color(0.2, 0.12, 0.06))
		var sym: String = DiceFace.CARVES[p_carve].sym
		var fs2 := int(rect.size.x * 0.2)
		var w2 := font.get_string_size(sym, HORIZONTAL_ALIGNMENT_LEFT, -1, fs2).x
		ci.draw_string(font, bc + Vector2(-w2 / 2.0, fs2 * 0.35), sym, HORIZONTAL_ALIGNMENT_LEFT, -1, fs2, Color(1.0, 0.9, 0.6))


func _ready() -> void:
	custom_minimum_size = Vector2(SIZE, SIZE)
	size = custom_minimum_size
	pivot_offset = size / 2.0
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var words := DiceFace.describe({"v": value, "paint": paint, "carve": carve})
	if words != "":
		tooltip_text = words


func _draw() -> void:
	if ghost:
		if frozen:
			draw_string(ThemeDB.fallback_font, Vector2(0, 26), "❄", HORIZONTAL_ALIGNMENT_RIGHT, size.x - 4, 24, Color.WHITE)
		_draw_reroll()
		return
	if used:
		draw_rect(Rect2(Vector2(6, 6), size - Vector2(12, 12)), Color(0, 0, 0, 0.25), false, 2.0)
		return
	if face_down:
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0.25, 0.2, 0.3)
		sb.set_corner_radius_all(15)
		sb.border_color = Color(0.7, 0.6, 0.85)
		sb.set_border_width_all(3)
		draw_style_box(sb, Rect2(Vector2(4, 4), size - Vector2(8, 8)))
		draw_string(ThemeDB.fallback_font, Vector2(0, size.y / 2.0 + 16), "?", HORIZONTAL_ALIGNMENT_CENTER, size.x, 46, Color(0.95, 0.9, 1.0))
	else:
		draw_die(self, Rect2(Vector2(4, 4), size - Vector2(8, 8)), value, false, paint, carve)
	if frozen:  # (an icy sheet over it)
		draw_rect(Rect2(Vector2(4, 4), size - Vector2(8, 8)), Color(0.6, 0.85, 1.0, 0.55))
		draw_string(ThemeDB.fallback_font, Vector2(0, 26), "❄", HORIZONTAL_ALIGNMENT_RIGHT, size.x - 8, 22, Color.WHITE)
	_draw_reroll()


func _draw_reroll() -> void:
	if can_reroll:
		var at := Vector2(size.x - REROLL_R + 2.0, REROLL_R - 2.0)
		draw_circle(at, REROLL_R, Color(0.55, 0.3, 0.75))
		draw_arc(at, REROLL_R, 0, TAU, 20, Color(1, 1, 1, 0.9), 2.0)
		draw_string(ThemeDB.fallback_font, at + Vector2(-8, 7), "↻", HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color.WHITE)


func _get_drag_data(_at: Vector2) -> Variant:
	if used or frozen:
		return null
	var prev := DiceDieView.new()
	prev.face_down = face_down
	prev.value = value
	prev.paint = paint
	prev.carve = carve
	prev.modulate.a = 0.85
	var holder := Control.new()
	holder.add_child(prev)
	prev.position = -Vector2(SIZE, SIZE) / 2.0
	set_drag_preview(holder)
	return {"die": r}


func _gui_input(ev: InputEvent) -> void:
	if can_reroll and ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
		if ev.position.distance_to(Vector2(size.x - REROLL_R + 2.0, REROLL_R - 2.0)) <= REROLL_R + 3.0:
			reroll_pressed.emit(r)
			accept_event()
