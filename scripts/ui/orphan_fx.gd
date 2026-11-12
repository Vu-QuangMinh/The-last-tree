extends RefCounted
## Something thrown at you from the stage (the Headless Horseman's head): a picture named throw_<item> when it exists,
## otherwise an emoji. (The file is named after the Orphans, who are gone: they threw things first.)

const ITEM_ICON := {"head": "💀"}
const ITEM_PX := {"head": 110}


static func _figure(text: String, px: int) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", px)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


## Something flies out and comes at you, at the screen: it grows as it comes closer, faster and faster,
## on a smooth curve like a curveball: it leaves within 45 degrees either side of straight at you and breaks sideways on the
## way. Returns where it lands (where the hit is shown).
static func throw_item(host: Control, from: Vector2, to: Vector2, item: String) -> Vector2:
	var px: int = ITEM_PX.get(item, 48)
	var tex: Texture2D = UiSkin.tex("throw_" + item)
	var n: Control
	if tex != null:
		var r := TextureRect.new()
		r.texture = tex
		r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		r.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		r.size = Vector2(px, px)
		r.mouse_filter = Control.MOUSE_FILTER_IGNORE
		n = r
	else:
		n = _figure(String(ITEM_ICON.get(item, "🪨")), px)
	n.z_index = 200
	host.add_child(n)
	n.pivot_offset = Vector2(px, px) / 2.0
	var ang := randf_range(-PI / 4.0, PI / 4.0)  # (0: straight at you, down the screen)
	var depth := maxf(to.y - from.y, 260.0)
	var end := Vector2(clampf(from.x + tan(ang) * depth, 140.0, 1780.0), to.y)
	var side := -1.0 if ang > 0.0 else 1.0  # (the break goes against its direction, so it bends back in: a curveball)
	var bend := (from + end) / 2.0 + Vector2(side * randf_range(110.0, 190.0), -150.0)  # (and it rises out of the bush first)
	var grow := minf(3.2, 280.0 / float(px))  # (big as it reaches you, never filling the screen)
	Audio.play("sfx_throw_whoosh", -2.0, randf_range(0.9, 1.15))
	var tw := n.create_tween()
	tw.tween_method(func(v: float) -> void:
		var t := v * v * 0.45 + v * 0.55  # (it speeds up as it comes closer)
		var p := from.lerp(bend, t).lerp(bend.lerp(end, t), t)
		n.scale = Vector2.ONE * lerpf(0.35, grow, t * t)
		n.global_position = p - Vector2(px, px) / 2.0, 0.0, 1.0, 0.7)
	tw.tween_property(n, "modulate:a", 0.0, 0.08)
	await tw.finished
	n.queue_free()
	return end
