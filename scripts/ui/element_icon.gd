class_name ElementIcon
extends Control
## One element: a white disc with a coloured rim and the element's picture (flame, drop, swirl), or a tri-colour orb for "?" (any / hidden).

var el := "F"
var armored := false
var ghost := false  # will be removed by the current chant (preview)
var temp := false  # conjured: fades at end of turn
var frozen := false
var hexed := false
var burning := false  # will burn away (Burn takes the leftmost): flickering flames around it
var poisoned := false  # will be eaten by Poison (it takes the rightmost): green venom bubbling on it
var sealed := false  # upgraded away: a purple wax seal covers it (this Essence isn't needed any more)
var cracked := 0.0  # 0..1: fractures spreading across it, white light blazing out (Annihilate)
var _cracks: Array = []  # fracture lines, in orb units (centre 0,0, radius 1): each a PackedVector2Array
var _sparks: Array = []  # light spewing out of the cracks: [pos, vel, life] in pixels from the centre
var highlight := false
var dim := false
var hover_lift := 0.0  # px the icon floats up while the mouse is on it
var _lift_tween: Tween

## New theme: the bead art for each element (anything else, "?" included, is the wildcard bead)
const ART := {"F": "essence_fire", "W": "essence_water", "A": "essence_wind"}


static func make(p_el: String, px := 40.0) -> ElementIcon:
	var i := ElementIcon.new()
	i.el = p_el
	i.custom_minimum_size = Vector2(px, px)
	i.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return i


func refresh() -> void:
	queue_redraw()


## The mouse is over this element (or has left): it floats up 3 px and drops back.
func set_hover(on: bool) -> void:
	if is_instance_valid(_lift_tween):
		_lift_tween.kill()
	_lift_tween = create_tween()
	_lift_tween.tween_method(func(v: float):
		hover_lift = v
		queue_redraw(), hover_lift, 3.0 if on else 0.0, 0.08)


func _process(d: float) -> void:
	if burning or poisoned:
		queue_redraw()  # the flames flicker, the venom bubbles
	if cracked > 0.0 or not _sparks.is_empty():
		_spew(d)
		queue_redraw()


## Its own random fracture pattern: a few jagged lines wandering out from near the middle, some branching.
func _make_cracks() -> void:
	var g := RandomNumberGenerator.new()
	g.seed = get_instance_id()
	for i in g.randi_range(4, 6):
		var p := Vector2(g.randf_range(-0.2, 0.2), g.randf_range(-0.2, 0.2))
		var ang := g.randf() * TAU
		var path := PackedVector2Array([p])
		for s in 14:
			# wander, but keep heading outwards so it reaches the rim
			var outward := p.angle() if p.length() > 0.05 else ang
			ang = lerp_angle(ang, outward, 0.35) + g.randf_range(-0.8, 0.8)
			p += Vector2.from_angle(ang) * g.randf_range(0.12, 0.24)
			path.append(p)
			if p.length() > 1.0:
				break
		_cracks.append(path)
		if path.size() > 2 and g.randf() < 0.75:
			var q: Vector2 = path[g.randi_range(1, path.size() - 2)]
			var ba := ang + g.randf_range(0.7, 1.7) * (1.0 if g.randf() < 0.5 else -1.0)
			var branch := PackedVector2Array([q])
			for s in g.randi_range(2, 4):
				ba += g.randf_range(-0.7, 0.7)
				q += Vector2.from_angle(ba) * g.randf_range(0.08, 0.2)
				branch.append(q)
			_cracks.append(branch)


## The part of a fracture that has opened so far (they grow outward as `cracked` rises).
func _open_part(path: PackedVector2Array, r: float, c: Vector2) -> PackedVector2Array:
	var want := cracked * (path.size() - 1)
	var out := PackedVector2Array()
	for i in path.size():
		if i <= want:
			out.append(c + path[i] * r)
		else:
			out.append(c + path[i - 1].lerp(path[i], want - (i - 1)) * r)
			break
	return out


## Sparks of light spray out of the cracks, more and faster as it's about to break.
func _spew(d: float) -> void:
	var r := minf(size.x, size.y) / 2.0 - 2.0
	if cracked > 0.05 and not _cracks.is_empty():
		var n := int(cracked * cracked * 90.0 * d) + (1 if randf() < cracked * 60.0 * d else 0)
		for k in n:
			var path: PackedVector2Array = _cracks[randi() % _cracks.size()]
			var at: Vector2 = path[mini(path.size() - 1, randi() % path.size())] * r
			var dir := at.normalized() if at.length() > 0.01 else Vector2.from_angle(randf() * TAU)
			dir = dir.rotated(randf_range(-0.6, 0.6))
			_sparks.append([at, dir * randf_range(60.0, 220.0) * (0.5 + cracked), 1.0])
	for s in _sparks:
		s[0] += s[1] * d
		s[1] *= 0.93
		s[2] -= d * 2.2
	_sparks = _sparks.filter(func(s): return s[2] > 0.0)


## A blob of purple sealing wax pressed over the orb: a wobbly rim where the wax spread, a pressed ring and a
## tree sigil stamped in the middle, with a glossy highlight. It hides the element underneath.
func _draw_seal(c: Vector2, r: float) -> void:
	var g := RandomNumberGenerator.new()
	g.seed = hash(el) + 7
	var rim := PackedVector2Array()
	var n := 22
	for k in n:
		var a := k * TAU / n
		rim.append(c + Vector2.from_angle(a) * r * (1.08 + g.randf_range(-0.06, 0.1)))
	draw_colored_polygon(rim, Color(0.3, 0.08, 0.36))
	var body := PackedVector2Array()
	for p in rim:
		body.append(c + (p - c) * 0.9)
	draw_colored_polygon(body, Color(0.55, 0.2, 0.62))
	draw_circle(c, r * 0.7, Color(0.46, 0.14, 0.52))
	draw_arc(c, r * 0.7, 0, TAU, 28, Color(0.72, 0.42, 0.8), maxf(1.0, r * 0.07))
	# the stamped sigil: a little tree (the last tree)
	var ink := Color(0.3, 0.06, 0.34)
	var w := maxf(1.2, r * 0.09)
	draw_line(c + Vector2(0, r * 0.42), c + Vector2(0, -r * 0.3), ink, w)
	for k in 3:
		var y := -r * 0.3 + k * r * 0.22
		var span := r * (0.18 + k * 0.1)
		draw_line(c + Vector2(0, y - r * 0.08), c + Vector2(-span, y + r * 0.1), ink, w)
		draw_line(c + Vector2(0, y - r * 0.08), c + Vector2(span, y + r * 0.1), ink, w)
	# gloss
	draw_circle(c + Vector2(-r * 0.38, -r * 0.42), r * 0.16, Color(1, 0.85, 1, 0.35))


func _draw() -> void:
	draw_set_transform(Vector2(0, -hover_lift), 0.0, Vector2.ONE)
	var r := minf(size.x, size.y) / 2.0 - 2.0
	var c := size / 2.0
	if sealed:
		_draw_seal(c, r)
		return
	var a := 1.0
	if ghost:
		a = 0.28
	elif dim:
		a = 0.45
	if highlight:
		draw_circle(c, r + 3.0, Color(1, 1, 1, 0.9))
	if UiSkin.draw_fit(self, ART.get(el, "essence_any"), c, r * 2.0 + 2.0, Color(1, 1, 1, a)):
		pass  # the New theme's art
	elif CardPip.ICON.has(el):
		CardPip.draw_pip(self, c, r, el, a)
	else:
		# any element / hidden: a white disc with the three colours blended inside
		draw_circle(c, r, Color(1, 1, 1, a), true, -1.0, true)
		_tri_blend(c, r * 0.9, a)
		draw_arc(c, r - 1.0, 0.0, TAU, 40, Color(0.3, 0.32, 0.4, a), maxf(1.5, r * 0.1), true)
		var f := get_theme_default_font()
		var fs := int(r * 1.35)
		draw_string_outline(f, c + Vector2(-fs * 0.28, fs * 0.36), "?", HORIZONTAL_ALIGNMENT_LEFT, -1, fs, maxi(2, int(r * 0.18)), Color(0, 0, 0, 0.55 * a))
		draw_string(f, c + Vector2(-fs * 0.28, fs * 0.36), "?", HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(1, 1, 1, 0.95 * a))
	if armored:
		draw_arc(c, r + 1.0, 0, TAU, 32, Color(0.85, 0.85, 0.9, a), 4.0)
		_mini_shield(c + Vector2(r * 0.62, -r * 0.62), r * 0.38, a)
	if temp:
		for i in 12:
			var t0 := i * TAU / 12.0
			draw_arc(c, r + 1.5, t0, t0 + TAU / 24.0, 4, Color(1, 1, 1, 0.9), 2.0)
	if frozen:
		draw_circle(c, r, Color(0.7, 0.9, 1.0, 0.55))
		for k in 3:
			var d := Vector2.from_angle(k * PI / 3.0) * r * 0.7
			draw_line(c - d, c + d, Color(1, 1, 1, 0.95), 2.0)
	if burning:
		# a flickering ring of fire, and flame tongues licking up around the top
		var t := Time.get_ticks_msec() / 1000.0
		draw_arc(c, r + 1.5, 0, TAU, 32, Color(1.0, 0.45, 0.1, 0.95), 3.0)
		for k in 5:
			var ang := -PI / 2.0 + (k - 2) * 0.5
			var h := r * (0.45 + 0.18 * sin(t * 11.0 + k * 1.9))
			var base := c + Vector2.from_angle(ang) * (r - 1.0)
			var tip := c + Vector2.from_angle(ang) * (r + h)
			var side := Vector2.from_angle(ang + PI / 2.0) * r * 0.18
			draw_colored_polygon(PackedVector2Array([base - side, tip, base + side]), Color(1.0, 0.55 + 0.25 * sin(t * 9.0 + k), 0.1, 0.95))
	if poisoned:
		# a sickly green ring, venom dripping down and bubbles popping
		var t := Time.get_ticks_msec() / 1000.0
		draw_arc(c, r + 1.5, 0, TAU, 32, Color(0.45, 0.95, 0.2, 0.95), 3.0)
		draw_circle(c, r, Color(0.35, 0.9, 0.15, 0.22 + 0.08 * sin(t * 5.0)))
		for k in 3:
			var ph := fmod(t * 0.9 + k * 0.33, 1.0)
			var x := (k - 1) * r * 0.55
			draw_circle(c + Vector2(x, r * (0.6 + ph * 0.9)), r * 0.13 * (1.0 - ph * 0.5), Color(0.5, 1.0, 0.25, 1.0 - ph))
		for k in 2:
			var ph := fmod(t * 1.3 + k * 0.5, 1.0)
			draw_arc(c + Vector2((k - 0.5) * r * 0.8, -r * (0.2 + ph * 0.6)), r * 0.14 * (0.5 + ph), 0, TAU, 12, Color(0.7, 1.0, 0.45, 1.0 - ph), 1.5)
	if cracked > 0.0:
		if _cracks.is_empty():
			_make_cracks()
		var t := Time.get_ticks_msec() / 1000.0
		var flick := 0.8 + 0.2 * sin(t * 37.0)
		# the whole orb swells with light as it's about to break
		draw_circle(c, r * (1.0 + 0.5 * cracked), Color(1.0, 0.95, 0.7, 0.25 * cracked * flick))
		draw_circle(c, r * 0.95, Color(1.0, 0.98, 0.88, 0.6 * cracked * cracked * flick))
		for path in _cracks:
			var pts := _open_part(path, r, c)
			if pts.size() < 2:
				continue
			# glow around the fracture, its dark edge, then the white-hot light inside
			draw_polyline(pts, Color(1.0, 0.92, 0.6, 0.35 * flick), maxf(8.0, r * 0.55))
			draw_polyline(pts, Color(1.0, 0.97, 0.8, 0.55 * flick), maxf(5.0, r * 0.3))
			draw_polyline(pts, Color(0.1, 0.05, 0.02, 0.8), maxf(2.5, r * 0.14))
			draw_polyline(pts, Color(1.0, 1.0, 0.95, 1.0), maxf(2.0, r * (0.07 + 0.06 * cracked)))
			# where a fracture reaches the rim, a beam of light bursts out
			var end: Vector2 = pts[pts.size() - 1]
			var out := end - c
			if out.length() > r * 0.8:
				var dir := out.normalized()
				var side := dir.orthogonal() * r * 0.2
				var reach := r * (0.6 + 1.6 * cracked) * flick
				draw_colored_polygon(PackedVector2Array([end - side, end + dir * reach, end + side]), Color(1.0, 0.95, 0.7, 0.4 + 0.4 * cracked))
				draw_colored_polygon(PackedVector2Array([end - side * 0.4, end + dir * reach * 0.8, end + side * 0.4]), Color(1, 1, 0.95, 0.9))
		for s in _sparks:
			draw_circle(c + s[0], (2.0 + 3.0 * s[2]) * maxf(1.0, r / 40.0), Color(1.0, 0.97, 0.8, s[2]))
	if hexed:
		draw_arc(c, r + 1.0, 0, TAU, 32, Color(0.75, 0.3, 0.95), 3.0)
		draw_circle(c + Vector2(-r * 0.62, -r * 0.62), r * 0.22, Color(0.75, 0.3, 0.95))
	if ghost:
		if not UiSkin.draw_fit(self, "x_essence_overlay", c, r * 1.5):  # New theme: the painted X
			var d := r * 0.55
			draw_line(c + Vector2(-d, -d), c + Vector2(d, d), Color(1, 0.35, 0.3, 0.9), 3.0)
			draw_line(c + Vector2(d, -d), c + Vector2(-d, d), Color(1, 0.35, 0.3, 0.9), 3.0)


## Three curved wedges, Fire / Water / Air, blending into each other around the orb.
func _tri_blend(c: Vector2, r: float, a: float) -> void:
	var cols := [Elements.COLORS["F"], Elements.COLORS["W"], Elements.COLORS["A"]]
	var rr := r * 0.86
	var steps := 48
	for i in steps:
		var t0 := i / float(steps)
		var t1 := (i + 1) / float(steps)
		# blend between neighbouring colours so the edges melt together
		var seg := t0 * 3.0
		var k := int(seg) % 3
		var col: Color = cols[k].lerp(cols[(k + 1) % 3], smoothstep(0.55, 1.0, seg - floorf(seg)))
		var a0 := t0 * TAU - PI / 2.0 + 0.35
		var a1 := t1 * TAU - PI / 2.0 + 0.35
		var pts := PackedVector2Array([c, c + Vector2.from_angle(a0) * rr, c + Vector2.from_angle(a1) * rr])
		draw_colored_polygon(pts, Color(col.darkened(0.05), a))
	draw_circle(c, rr * 0.45, Color(1, 1, 1, 0.12 * a))


func _mini_shield(p: Vector2, s: float, a: float) -> void:
	var pts := PackedVector2Array([p + Vector2(-s, -s * 0.8), p + Vector2(s, -s * 0.8), p + Vector2(s, 0), p + Vector2(0, s), p + Vector2(-s, 0)])
	draw_colored_polygon(pts, Color(0.8, 0.82, 0.9, a))
	pts.append(pts[0])
	draw_polyline(pts, Color(0.2, 0.2, 0.25, a), 1.5)
