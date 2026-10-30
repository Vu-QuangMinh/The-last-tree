extends CanvasLayer
## "Show FPS" (Settings): the frame rate in the top-right corner, over every screen (only the wooden pointer is above it).

const REFRESH := 0.4  # seconds between two readings: a number that changes every frame cannot be read

var _label: Label
var _since := REFRESH


func _ready() -> void:
	layer = 127
	_label = Label.new()
	_label.theme = UiTheme.get_theme()  # (this layer is outside every screen)
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_label.add_theme_font_size_override("font_size", 22)
	_label.add_theme_color_override("font_color", Color(0.75, 1.0, 0.45))
	_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	_label.add_theme_constant_override("outline_size", 6)
	_label.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	_label.offset_left = -200.0
	_label.offset_right = -14.0
	_label.offset_top = 6.0
	_label.offset_bottom = 38.0
	add_child(_label)


func _process(delta: float) -> void:
	var on: bool = SaveManager.setting("show_fps", false)
	_label.visible = on
	if not on:
		_since = REFRESH
		return
	_since += delta
	if _since >= REFRESH:
		_since = 0.0
		_label.text = "%d FPS" % int(Engine.get_frames_per_second())
