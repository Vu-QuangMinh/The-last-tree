class_name CurseSigil
extends Control
## A curse's red burning sigil (RunState.CURSES), drawn in code until there is art: a glowing ring with flames licking
## round it and the curse's own mark inside. Big when the curse is announced (CurseScene), small on the top right of a
## cursed spell card (SpellCard). `kind` is the curse; `r` the ring's radius (the control is 2.6 r square).

var kind := "burden"
var r := 14.0
var _t := 0.0


static func make(p_kind: String, p_r: float) -> CurseSigil:
	var s := CurseSigil.new()
	s.kind = p_kind
	s.r = p_r
	s.custom_minimum_size = Vector2(p_r, p_r) * 2.6
	s.size = s.custom_minimum_size
	s.pivot_offset = s.size / 2.0
	s.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return s


func _process(d: float) -> void:
	_t += d
	queue_redraw()


func _draw() -> void:
	draw_sigil(self, kind, size / 2.0, r, _t)


## Draws a sigil on any canvas item (also used straight onto a card).
static func draw_sigil(ci: CanvasItem, p_kind: String, c: Vector2, rr: float, t: float) -> void:
	var red := Color(1.0, 0.2, 0.08)
	var hot := Color(1.0, 0.65, 0.2)
	var w := maxf(1.5, rr * 0.13)
	# the burning: a soft glow, then flames all round the ring, each flickering on its own
	var pulse := 0.85 + 0.15 * sin(t * 6.0)
	for k in 4:
		ci.draw_circle(c, rr * (1.55 - k * 0.12) * pulse, Color(1.0, 0.25, 0.05, 0.07))
	var n := 14
	for k in n:
		var a := k * TAU / n + t * 0.6
		var flick := 0.6 + 0.4 * sin(t * 9.0 + k * 1.7)
		var base := c + Vector2.from_angle(a) * rr
		var tip := c + Vector2.from_angle(a) * rr * (1.0 + 0.35 * flick)
		var side := Vector2.from_angle(a + PI / 2.0) * rr * 0.12
		ci.draw_colored_polygon(PackedVector2Array([base - side, tip, base + side]), Color(1.0, 0.45 * flick, 0.05, 0.85))
	ci.draw_circle(c, rr, Color(0.12, 0.02, 0.01, 0.92))
	ci.draw_arc(c, rr, 0, TAU, 32, red, w, true)
	ci.draw_arc(c, rr * 0.8, 0, TAU, 32, Color(red, 0.5), w * 0.5, true)
	# the mark of the curse
	var m := rr * 0.55
	match p_kind:
		"burden":  # a weight hanging from a ring
			ci.draw_arc(c + Vector2(0, -m * 0.75), m * 0.25, 0, TAU, 12, hot, w, true)
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(-m * 0.45, -m * 0.4), c + Vector2(m * 0.45, -m * 0.4), c + Vector2(m * 0.8, m * 0.75), c + Vector2(-m * 0.8, m * 0.75)]), hot)
		"fragility":  # a crack running through
			ci.draw_polyline(PackedVector2Array([c + Vector2(-m * 0.2, -m), c + Vector2(m * 0.2, -m * 0.35), c + Vector2(-m * 0.25, m * 0.1), c + Vector2(m * 0.3, m * 0.55), c + Vector2(0, m)]), hot, w * 1.2, true)
		"pain":  # a thorn star
			var pts := PackedVector2Array()
			for k in 12:
				var a := k * TAU / 12.0 - PI / 2.0
				pts.append(c + Vector2.from_angle(a) * (m if k % 2 == 0 else m * 0.35))
			ci.draw_colored_polygon(pts, hot)
		"hesitation":  # an hourglass
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(-m * 0.6, -m * 0.8), c + Vector2(m * 0.6, -m * 0.8), c, ]), hot)
			ci.draw_colored_polygon(PackedVector2Array([c, c + Vector2(m * 0.6, m * 0.8), c + Vector2(-m * 0.6, m * 0.8)]), hot)
			ci.draw_line(c + Vector2(-m * 0.75, -m * 0.85), c + Vector2(m * 0.75, -m * 0.85), hot, w, true)
			ci.draw_line(c + Vector2(-m * 0.75, m * 0.85), c + Vector2(m * 0.75, m * 0.85), hot, w, true)
		"binding":  # two chain links
			ci.draw_arc(c + Vector2(-m * 0.3, -m * 0.25), m * 0.42, 0, TAU, 16, hot, w, true)
			ci.draw_arc(c + Vector2(m * 0.3, m * 0.25), m * 0.42, 0, TAU, 16, hot, w, true)
		"void":  # an empty eye: a ring round nothing
			ci.draw_arc(c, m * 0.75, 0, TAU, 20, hot, w, true)
			ci.draw_circle(c, m * 0.4, Color(0, 0, 0))
			ci.draw_arc(c, m * 0.4, 0, TAU, 16, Color(hot, 0.6), w * 0.5, true)
		"betrayal":  # a dagger, point down
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(-m * 0.15, -m * 0.3), c + Vector2(m * 0.15, -m * 0.3), c + Vector2(0, m)]), hot)
			ci.draw_line(c + Vector2(-m * 0.45, -m * 0.35), c + Vector2(m * 0.45, -m * 0.35), hot, w, true)
			ci.draw_line(c + Vector2(0, -m * 0.35), c + Vector2(0, -m * 0.85), hot, w * 1.3, true)
		"separation":  # a circle torn in two halves
			ci.draw_arc(c + Vector2(-m * 0.15, 0), m * 0.7, PI * 0.5, PI * 1.5, 14, hot, w, true)
			ci.draw_arc(c + Vector2(m * 0.15, 0), m * 0.7, -PI * 0.5, PI * 0.5, 14, hot, w, true)
			ci.draw_line(c + Vector2(0, -m), c + Vector2(0, m), Color(1, 0.9, 0.6), w * 0.6, true)
