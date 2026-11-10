class_name MinhHpFlask
extends HpBar
## Theme MinhHUD: your HP is the red glass flask (picture minhhud_flask, drawn by Hud2Layout in NewUiLayout.Back). This control lies over it and only paints what the flask is NOT
## full of: the empty top of the glass (dark), the part you have just lost (pale, then it slides away), the Shield (blue glass over the top end of the HP, as tall as the HP it
## covers), a wavy surface that rocks like a spring when the level changes, and the Shield's crack. Same interface as HpBar / NewUiLayout.Bar (set_values, crack, hp, max_hp, shield).

const GLASS_R := 0.455  # the liquid's radius, from the flask's size (the brass rim is outside it)
const SLOSH_K := 90.0
const SLOSH_C := 7.0
const EMPTY := Color(0.03, 0.015, 0.02, 0.86)
const SHIELD := Color(0.55, 0.82, 1.0, 0.5)
const LOST := Color(1.0, 0.85, 0.6, 0.55)

var _level := 1.0  # where the liquid's surface is (0..1 of the glass's height) right now: a mass on a spring following hp / max_hp
var _vel := 0.0
var _wave_t := 0.0
var _started := false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _process(d: float) -> void:
	super(d)
	var goal := clampf(hp / maxf(max_hp, 1.0), 0.0, 1.0)
	if not _started:
		_started = true
		_level = goal
	var dt := minf(d, 0.05)
	_vel += (-SLOSH_K * (_level - goal) - SLOSH_C * _vel) * dt
	_level += _vel * dt
	_wave_t += dt * (0.8 + minf(absf(_vel) * 6.0, 4.0))
	queue_redraw()


func _circle(c: Vector2, r: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	for k in 64:
		var a := TAU * k / 64.0
		out.append(c + Vector2(cos(a), sin(a)) * r)
	return out


## y of a level (0 = the bottom of the glass, 1 = the top).
func _y(c: Vector2, r: float, f: float) -> float:
	return c.y + r - 2.0 * r * clampf(f, 0.0, 1.0)


## A band of the glass between two levels (the lower one first), the upper edge wavy by `amp` px; clipped to the circle.
func _band(c: Vector2, r: float, lo: float, hi: float, amp: float, col: Color) -> void:
	if hi <= lo + 0.0005:
		return
	var y_hi := _y(c, r, hi)
	var y_lo := _y(c, r, lo)
	var pts := PackedVector2Array()
	for k in range(0, 17):
		var x := c.x - r - 2.0 + (2.0 * r + 4.0) * k / 16.0
		pts.append(Vector2(x, y_hi + amp * sin(x * 0.12 + _wave_t * 3.0)))
	pts.append(Vector2(c.x + r + 2.0, y_lo))
	pts.append(Vector2(c.x - r - 2.0, y_lo))
	for part in Geometry2D.intersect_polygons(pts, _circle(c, r)):
		if part.size() >= 3 and not Geometry2D.triangulate_polygon(part).is_empty():
			draw_colored_polygon(part, col)


func _draw() -> void:
	var c := size / 2.0
	var r := size.x * GLASS_R
	var frac_hp := clampf(_level, 0.0, 1.0)
	var amp := 1.2 + 2.0 * _flash + minf(absf(_vel) * 3.0, 2.5)
	# the empty top of the glass (everything over the surface)
	var top_pts := PackedVector2Array()
	var y_s := _y(c, r, frac_hp)
	for k in range(0, 17):
		var x := c.x - r - 2.0 + (2.0 * r + 4.0) * k / 16.0
		top_pts.append(Vector2(x, y_s + amp * sin(x * 0.12 + _wave_t * 3.0)))
	top_pts.append(Vector2(c.x + r + 2.0, c.y - r - 2.0))
	top_pts.append(Vector2(c.x - r - 2.0, c.y - r - 2.0))
	for part in Geometry2D.intersect_polygons(top_pts, _circle(c, r)):
		if part.size() >= 3 and not Geometry2D.triangulate_polygon(part).is_empty():
			draw_colored_polygon(part, EMPTY)
	# the part just lost, pale, between the surface and where it was
	var f_ghost := clampf(_ghost / maxf(max_hp, 1.0), 0.0, 1.0)
	if f_ghost > frac_hp:
		_band(c, r, frac_hp, f_ghost, 0.0, LOST)
	# the Shield: blue glass over the top end of the HP, as tall as the HP it covers (at most all of it)
	var f_sh := minf(frac_hp, clampf(shield / maxf(max_hp, 1.0), 0.0, 1.0))
	if f_sh > 0.002:
		var tint := SHIELD
		tint.a += _crack * 0.3
		_band(c, r, frac_hp - f_sh, frac_hp, amp, tint)
	# the surface line
	if frac_hp > 0.01 and frac_hp < 0.99:
		var half := sqrt(maxf(0.0, r * r - (y_s - c.y) * (y_s - c.y)))
		var line := PackedVector2Array()
		for k in range(0, 13):
			var x := c.x - half + 2.0 * half * k / 12.0
			line.append(Vector2(x, y_s + amp * sin(x * 0.12 + _wave_t * 3.0)))
		draw_polyline(line, Color(1, 1, 1, 0.55), 1.5, true)
	if shield > 0.0 and _crack > 0.0:
		var mid := Vector2(c.x, _y(c, r, frac_hp - f_sh / 2.0))
		for k in 5:
			var a := k * TAU / 5.0 + 0.4
			draw_line(mid, mid + Vector2.from_angle(a) * r * 0.5, Color(1, 1, 1, _crack), 1.5)
