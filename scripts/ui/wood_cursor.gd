class_name WoodCursor
extends Control
## Puppet Stage: the mouse pointer is a carved wooden arrow (UI art "cursor_arrow", drawn pointing straight up, its tip is the hotspot).
## It always lies slanted (pointing up-left, like a normal pointer); it no longer turns over the Essences of the Bag and the chant (2026-10-20).
## The real pointer is made see-through while this shows
## (and given back when the theme changes, or while a spell's own aim cursor hides the pointer).

const SIZE_PX := 46.0
const SLANT := -PI / 4.0  # up-left
const UP := 0.0
const DOWN := PI

## () -> the screen on show (not used for the angle any more: the arrow does not turn).
var get_screen: Callable
var _angle := SLANT
var _hidden_os := false
var _blank: ImageTexture


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var img := Image.create(2, 2, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	_blank = ImageTexture.create_from_image(img)


func _active() -> bool:
	return UiSkin.is_puppet() and UiSkin.tex("cursor_arrow") != null and Input.mouse_mode == Input.MOUSE_MODE_VISIBLE


func _hide_os(on: bool) -> void:
	if on == _hidden_os:
		return
	_hidden_os = on
	for shape in range(Input.CURSOR_ARROW, Input.CURSOR_HELP + 1):
		Input.set_custom_mouse_cursor(_blank if on else null, shape as Input.CursorShape)


func _process(d: float) -> void:
	var on := _active()
	_hide_os(UiSkin.is_puppet() and UiSkin.tex("cursor_arrow") != null)
	visible = on
	if not on:
		return
	_angle = lerp_angle(_angle, SLANT, clampf(d * 16.0, 0.0, 1.0))
	queue_redraw()


func _draw() -> void:
	var t := UiSkin.tex("cursor_arrow")
	if t == null:
		return
	var h := SIZE_PX
	var w := h * t.get_width() / float(t.get_height())
	draw_set_transform(get_local_mouse_position(), _angle, Vector2.ONE)
	draw_texture_rect(t, Rect2(Vector2(-w / 2.0, -2.0), Vector2(w, h)), false)  # (tip at the origin: the pointer's hotspot)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _exit_tree() -> void:
	_hide_os(false)
