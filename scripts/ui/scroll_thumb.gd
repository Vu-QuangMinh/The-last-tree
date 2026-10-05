class_name ScrollThumb
extends Control
## New theme: the painted scroll-bar grabber. It keeps its drawn size (it is never stretched to the content, as the
## engine's own grabber is): it just rides the track, and a drag or a click on the track moves the view in proportion, so
## the longer the content, the faster the thumb scrolls it. The bar's own grabber is drawn empty (UiTheme), this sits on top.

const INSET := 4.0

var bar: VScrollBar
var tex: Texture2D
var _grab := -1.0  # while dragging: where on the thumb the mouse took hold (px from its top)


## Put the painted thumb on a ScrollContainer's vertical bar (once). Does nothing in the Default theme.
static func attach(sc: ScrollContainer) -> void:
	if not is_instance_valid(sc) or not UiSkin.is_new():
		return
	var t := UiSkin.tex("scroll_bar_grabber")
	if t == null:
		return
	var b := sc.get_v_scroll_bar()
	if b.has_node("ScrollThumb"):
		return
	var th := ScrollThumb.new()
	th.name = "ScrollThumb"
	th.bar = b
	th.tex = t
	th.mouse_filter = Control.MOUSE_FILTER_PASS  # the wheel and everything but the left button pass through
	b.add_child(th)
	th.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


func _process(_d: float) -> void:
	if bar != null and bar.is_visible_in_tree():
		queue_redraw()


func _range() -> float:
	return maxf(0.0, bar.max_value - bar.page)


func _travel() -> float:
	return maxf(1.0, size.y - tex.get_height() - 2.0 * INSET)


func _thumb() -> Rect2:
	var r := _range()
	if r <= 0.0:
		return Rect2()
	var y := INSET + clampf(bar.value / r, 0.0, 1.0) * _travel()
	return Rect2(Vector2((size.x - tex.get_width()) / 2.0, y), tex.get_size())


func _draw() -> void:
	var r := _thumb()
	if r.size != Vector2.ZERO:
		draw_texture_rect(tex, r, false)


func _move_to(mouse_y: float) -> void:
	bar.value = clampf((mouse_y - _grab - INSET) / _travel(), 0.0, 1.0) * _range()


func _gui_input(ev: InputEvent) -> void:
	if _range() <= 0.0:
		return
	if ev is InputEventMouseButton and ev.button_index == MOUSE_BUTTON_LEFT:
		if ev.pressed:
			var r := _thumb()
			_grab = ev.position.y - r.position.y if r.has_point(ev.position) else tex.get_height() / 2.0
			_move_to(ev.position.y)
		else:
			_grab = -1.0
		accept_event()
	elif ev is InputEventMouseMotion and _grab >= 0.0:
		_move_to(ev.position.y)
		accept_event()
