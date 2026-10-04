class_name ResinIcon
extends Control
## A lump of purple resin (what a fusion drips): a glassy, faceted chunk like amber, purple and see-through, with a
## bubble trapped inside and a couple of bright glints. (Heated at a campfire it becomes a purple seal, which is the
## round stamped wax disc: ElementIcon with sealed = true.)

const DARK := Color(0.3, 0.08, 0.38)
const BODY := Color(0.62, 0.24, 0.78)
const LIGHT := Color(0.86, 0.6, 1.0)


static func make(px := 40.0) -> ResinIcon:
	var r := ResinIcon.new()
	r.custom_minimum_size = Vector2(px, px)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return r


func _draw() -> void:
	var c := size / 2.0
	var r := minf(size.x, size.y) / 2.0 - 1.0
	# the lump's outline: an irregular, slightly flattened pebble with a few straight facet edges
	var shape := [Vector2(-0.95, 0.15), Vector2(-0.7, -0.55), Vector2(-0.15, -0.88), Vector2(0.45, -0.72),
		Vector2(0.92, -0.2), Vector2(0.85, 0.42), Vector2(0.35, 0.82), Vector2(-0.4, 0.8)]
	var outer := PackedVector2Array()
	for p in shape:
		outer.append(c + p * r)
	draw_colored_polygon(outer, DARK)
	var inner := PackedVector2Array()
	for p in shape:
		inner.append(c + p * r * 0.86)
	draw_colored_polygon(inner, BODY)
	# facets: a lighter top-left face and a darker bottom-right one, so it reads as a chunky crystal
	draw_colored_polygon(PackedVector2Array([c + Vector2(-0.6, -0.47) * r, c + Vector2(-0.13, -0.75) * r,
		c + Vector2(0.38, -0.6) * r, c + Vector2(0.05, -0.1) * r, c + Vector2(-0.55, 0.05) * r]), Color(LIGHT, 0.55))
	draw_colored_polygon(PackedVector2Array([c + Vector2(0.05, -0.1) * r, c + Vector2(0.75, -0.15) * r,
		c + Vector2(0.7, 0.35) * r, c + Vector2(0.3, 0.68) * r, c + Vector2(-0.1, 0.4) * r]), Color(DARK, 0.45))
	# a bubble trapped inside
	draw_circle(c + Vector2(-0.3, 0.32) * r, r * 0.13, Color(1, 0.9, 1, 0.35))
	draw_arc(c + Vector2(-0.3, 0.32) * r, r * 0.13, 0, TAU, 16, Color(1, 0.95, 1, 0.7), maxf(1.0, r * 0.05), true)
	# glints
	draw_line(c + Vector2(-0.52, -0.38) * r, c + Vector2(-0.2, -0.6) * r, Color(1, 1, 1, 0.9), maxf(1.5, r * 0.09), true)
	draw_circle(c + Vector2(0.48, -0.35) * r, r * 0.07, Color(1, 1, 1, 0.85))
