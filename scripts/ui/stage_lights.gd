class_name StageLights
extends Control
## Puppet Stage: a spotlight over every enemy. A soft cone of warm light falls from the top of the stage on the puppet, and a pool of
## light lies on the floor under its feet (added to the dim stage, so it really brightens it). `feet` returns the enemies' feet, in this
## control's own coordinates (it sits at the screen's origin).

var feet: Callable
var _t := 0.0

const TOP_Y := 96.0  # where the beams start (the lower edge of the ceiling)
const WARM := Color(1.0, 0.92, 0.7)


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var m := CanvasItemMaterial.new()
	m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	material = m


func _process(d: float) -> void:
	_t += d
	queue_redraw()


func _draw() -> void:
	if not feet.is_valid():
		return
	for f in feet.call():
		var flicker := 1.0 + 0.04 * sin(_t * 3.1 + f.x * 0.01)
		# the cone: narrow at the lamp, wide at the floor, fading as it falls
		var top_half := 34.0
		var bot_half := 175.0
		var y_floor: float = f.y + 6.0
		var pts := PackedVector2Array([Vector2(f.x - top_half, TOP_Y), Vector2(f.x + top_half, TOP_Y), Vector2(f.x + bot_half, y_floor), Vector2(f.x - bot_half, y_floor)])
		var a_top := 0.2 * flicker
		var a_bot := 0.055 * flicker
		var cols := PackedColorArray([Color(WARM, a_top), Color(WARM, a_top), Color(WARM, a_bot), Color(WARM, a_bot)])
		draw_polygon(pts, cols)
		# the pool on the floor
		for k in 7:
			var u := 1.0 - k / 7.0
			draw_set_transform(Vector2(f.x, f.y), 0.0, Vector2(1.0, 0.24))
			draw_circle(Vector2.ZERO, 40.0 + 135.0 * u, Color(WARM, 0.05 * flicker))
		draw_set_transform(Vector2.ZERO)
