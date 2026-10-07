class_name Hourglass
extends Control
## A charge's intent: an hourglass with the turns left inside it. Each time the number goes down it turns upside down.

const SIZE := 40.0
static var _last := {}  # enemy instance id -> the number it showed last (so it flips only when the number changes)

var left := 3
var _sand := Color(1.0, 0.8, 0.35)


static func make(p_left: int, e: Object) -> Hourglass:
	var h := Hourglass.new()
	h.left = p_left
	h.custom_minimum_size = Vector2(SIZE, SIZE)
	h.size = Vector2(SIZE, SIZE)
	h.pivot_offset = Vector2(SIZE, SIZE) / 2.0
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var key := e.get_instance_id()
	if _last.has(key) and _last[key] != p_left:
		h.set_meta("flip", true)
	_last[key] = p_left
	return h


func _ready() -> void:
	if get_meta("flip", false):
		rotation = -PI
		create_tween().tween_property(self, "rotation", 0.0, 0.6).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _draw() -> void:
	var w := SIZE
	var frame := Color(0.55, 0.35, 0.18)
	var glass := Color(0.85, 0.95, 1.0, 0.35)
	# the two bulbs
	var top := PackedVector2Array([Vector2(w * 0.18, w * 0.12), Vector2(w * 0.82, w * 0.12), Vector2(w * 0.5, w * 0.5)])
	var bot := PackedVector2Array([Vector2(w * 0.5, w * 0.5), Vector2(w * 0.82, w * 0.88), Vector2(w * 0.18, w * 0.88)])
	draw_colored_polygon(top, glass)
	draw_colored_polygon(bot, glass)
	# sand: less on top the fewer turns are left
	var k := clampf(left / 3.0, 0.0, 1.0)
	var ty := lerpf(w * 0.5, w * 0.16, k)
	draw_colored_polygon(PackedVector2Array([Vector2(w * 0.5 - (w * 0.5 - ty) * 0.84, ty), Vector2(w * 0.5 + (w * 0.5 - ty) * 0.84, ty), Vector2(w * 0.5, w * 0.5)]), _sand)
	var by := lerpf(w * 0.86, w * 0.6, 1.0 - k)
	draw_colored_polygon(PackedVector2Array([Vector2(w * 0.5 - (by - w * 0.5) * 0.84, by), Vector2(w * 0.5 + (by - w * 0.5) * 0.84, by), Vector2(w * 0.82, w * 0.88), Vector2(w * 0.18, w * 0.88)]), _sand)
	# the wooden caps
	draw_rect(Rect2(w * 0.1, w * 0.04, w * 0.8, w * 0.09), frame)
	draw_rect(Rect2(w * 0.1, w * 0.87, w * 0.8, w * 0.09), frame)
	draw_polyline(PackedVector2Array([top[0], top[2], bot[1]]), frame, 2.0)
	draw_polyline(PackedVector2Array([top[1], top[2], bot[2]]), frame, 2.0)
	# the number, in the middle
	var font := get_theme_default_font()
	var fs := 22
	var txt := str(left)
	var tw := font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs)
	var at := Vector2((w - tw.x) / 2.0, w * 0.5 + fs * 0.35)
	draw_string_outline(font, at, txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 6, Color(0.15, 0.08, 0.02))
	draw_string(font, at, txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color.WHITE)
