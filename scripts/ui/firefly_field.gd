class_name FireflyField
extends Control
## Fireflies wandering through a wood: each one drifts on its own slow loop and blinks on and off. Drawn as soft sprites
## (a bright core inside a wide halo, both fading smoothly to nothing), added onto what is below.

var count := 40
var seed_value := 11
var top := 0.06  # the band they live in, as fractions of this control's height
var bottom := 0.78
var tint := Color(0.86, 1.0, 0.5)

var _t := 0.0
var _bits: Array = []
var _glow: Texture2D


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var add := CanvasItemMaterial.new()
	add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	material = add
	var g := Gradient.new()  # (a soft fall-off: no visible edge)
	g.offsets = PackedFloat32Array([0.0, 0.18, 0.5, 1.0])
	g.colors = PackedColorArray([Color(1, 1, 1, 1.0), Color(1, 1, 1, 0.55), Color(1, 1, 1, 0.12), Color(1, 1, 1, 0.0)])
	var gt := GradientTexture2D.new()
	gt.gradient = g
	gt.fill = GradientTexture2D.FILL_RADIAL
	gt.fill_from = Vector2(0.5, 0.5)
	gt.fill_to = Vector2(1.0, 0.5)
	gt.width = 128
	gt.height = 128
	_glow = gt
	var r := RandomNumberGenerator.new()
	r.seed = seed_value
	for i in count:
		_bits.append({
			"x": r.randf(), "y": r.randf(),
			"speed": r.randf_range(0.6, 1.4), "phase": r.randf() * TAU,
			"size": r.randf_range(0.7, 1.4), "warm": r.randf(),
		})


func _process(d: float) -> void:
	_t += d
	queue_redraw()


func _draw() -> void:
	var w := size.x
	var h := size.y
	if w <= 0.0:
		return
	for b in _bits:
		var pos := Vector2(
			(b.x + sin(_t * 0.11 * b.speed + b.phase) * 0.05 + sin(_t * 0.27 * b.speed + b.phase * 1.7) * 0.012) * w,
			(top + b.y * (bottom - top) + cos(_t * 0.15 * b.speed + b.phase * 2.0) * 0.04 + cos(_t * 0.31 * b.speed + b.phase) * 0.01) * h)
		var blink := clampf(0.5 + 0.62 * sin(_t * (1.1 + b.speed) + b.phase * 3.0), 0.0, 1.0)
		blink *= blink  # (it spends more of its time dim, and flares up briefly)
		if blink < 0.02:
			continue
		var c := tint.lerp(Color(1.0, 0.95, 0.55), b.warm)
		var s: float = b.size
		draw_texture_rect(_glow, Rect2(pos - Vector2(34, 34) * s, Vector2(68, 68) * s), false, Color(c, 0.32 * blink))
		draw_texture_rect(_glow, Rect2(pos - Vector2(9, 9) * s, Vector2(18, 18) * s), false, Color(1.0, 1.0, 0.85, 0.95 * blink))
