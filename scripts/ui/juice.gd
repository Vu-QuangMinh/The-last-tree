class_name Juice
extends RefCounted
## A burst of light for a moment that ends a screen (2026-11-27, the light-and-impact pass; see the game-feel-vfx skill):
## a reward picked, something bought, a ticket used. It plays on its own top layer, so the screen can close at once, and
## frees itself. Layers: a white-hot core, a coloured glow, a ring racing out, sparks, a few slow stars, a number popping.


static func pop(tree: SceneTree, at: Vector2, col: Color, text := "", big := false) -> void:
	if tree == null:
		return
	var layer := CanvasLayer.new()
	layer.layer = 30
	var host := Control.new()
	host.mouse_filter = Control.MOUSE_FILTER_IGNORE
	host.size = Vector2(1920, 1080)
	layer.add_child(host)
	tree.root.add_child(layer)
	var fx := Vfx.make(host, 5)
	var k := 1.4 if big else 1.0
	fx.glow(at, 80.0 * k, Color(1, 1, 1, 1.0), 0.14)
	fx.glow(at, 200.0 * k, col, 0.45)
	fx.ring(at, 14.0, 150.0 * k, col.lerp(Color.WHITE, 0.35), 0.4, 8.0)
	fx.ring(at, 8.0, 90.0 * k, Color(1, 1, 1, 0.85), 0.25, 4.0, 0.06)
	fx.burst(at, int(22 * k), col.lerp(Color.WHITE, 0.4), Vector2(180, 520), Vector2(0.35, 0.7), Vector2(3, 7))
	fx.burst(at, int(6 * k), col, Vector2(50, 160), Vector2(0.7, 1.1), Vector2(10, 16), Vfx.STAR)
	if text != "":
		var l := UiTheme.heading(text, 52 if big else 42, col.lerp(Color.WHITE, 0.25))
		l.add_theme_constant_override("outline_size", 11)
		l.add_theme_color_override("font_outline_color", Color(0.12, 0.05, 0.02))
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.size = Vector2(320, 80)
		l.position = at - l.size / 2.0 + Vector2(0, -50)
		l.pivot_offset = l.size / 2.0
		l.mouse_filter = Control.MOUSE_FILTER_IGNORE
		host.add_child(l)
		l.scale = Vector2.ONE * 0.3
		var tw := l.create_tween()
		tw.tween_property(l, "scale", Vector2.ONE * 1.25, 0.09)
		tw.tween_property(l, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_property(l, "position:y", l.position.y - 60.0, 0.7).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.parallel().tween_property(l, "modulate:a", 0.0, 0.4).set_delay(0.35)
	tree.create_timer(1.6, true, false, true).timeout.connect(layer.queue_free)


## The centre of a Control on the screen.
static func center(c: Control) -> Vector2:
	return c.get_global_rect().get_center() if is_instance_valid(c) else Vector2(960, 540)
