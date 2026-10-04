class_name PaintSplash
extends Node2D
## Expose's paint: a blotch of rainbow paint slapped onto an Essence. It splats out (grow 0 -> 1), drops fly off,
## then it fades away (fade 1 -> 0) to reveal the Any Essence underneath. Centred on its position.

var radius := 30.0
var grow := 0.0:
	set(v):
		grow = v
		queue_redraw()
var fade := 1.0:
	set(v):
		fade = v
		queue_redraw()
var _blobs: Array = []  # [offset (in radius units), size (radius units), colour]
var _drops: Array = []  # [direction, distance (radius units), size, colour]


func _ready() -> void:
	z_index = 160
	var g := RandomNumberGenerator.new()
	g.randomize()
	var hue0 := g.randf()
	# a fat core of overlapping blobs, each a different band of the rainbow, so the blotch is lumpy and colourful
	for k in 7:
		var ang := k * TAU / 7.0 + g.randf_range(-0.3, 0.3)
		var off := Vector2.from_angle(ang) * g.randf_range(0.25, 0.5) if k > 0 else Vector2.ZERO
		_blobs.append([off, g.randf_range(0.5, 0.75), AimCursor.rainbow(hue0 + k / 7.0)])
	# splatter flung outwards
	for k in 9:
		_drops.append([Vector2.from_angle(g.randf() * TAU), g.randf_range(1.05, 1.7), g.randf_range(0.08, 0.17), AimCursor.rainbow(hue0 + g.randf())])


## Splat, hold a moment, then fade out and free itself. `reveal` is called at the moment it fully covers the Essence.
func play(reveal: Callable) -> void:
	var tw := create_tween()
	tw.tween_property(self, "grow", 1.0, 0.14).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_callback(reveal)
	tw.tween_interval(0.22)
	tw.tween_property(self, "fade", 0.0, 0.55).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tw.tween_callback(queue_free)


func _draw() -> void:
	var r := radius * grow
	if r <= 0.5:
		return
	for b in _blobs:
		var col: Color = b[2]
		draw_circle(b[0] * r, b[1] * r * 1.08, Color(col.darkened(0.35), fade))
	for b in _blobs:
		var col: Color = b[2]
		draw_circle(b[0] * r, b[1] * r, Color(col, fade))
	for d in _drops:
		# drops land a little after the splat, at the end of a short streak
		var p: Vector2 = d[0] * d[1] * radius * grow
		var col: Color = d[3]
		draw_line(p * 0.75, p, Color(col, 0.7 * fade), maxf(1.5, d[2] * radius * 0.8), true)
		draw_circle(p, d[2] * radius, Color(col, fade))
	# a wet highlight
	draw_circle(Vector2(-r * 0.25, -r * 0.3), r * 0.16, Color(1, 1, 1, 0.45 * fade))
