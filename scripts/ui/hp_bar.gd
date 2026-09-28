class_name HpBar
extends Control
## Your HP bar. Damage drains in two stages (the lost part flashes pale, then slides away), and Shield is
## drawn as a sheet of blue glass laid over the end of the bar, as wide as the HP it protects.

var hp := 50.0
var max_hp := 50.0
var shield := 0.0
var _ghost := 50.0  # the pale "just lost" part slides down to hp
var _ghost_hold := 0.0
var _crack := 0.0  # glass crack flash (0..1)
var _flash := 0.0  # red flash on a hit
var _t := 0.0


func set_values(p_hp: float, p_max: float, p_shield: float) -> void:
	if p_hp < hp:
		_ghost_hold = 0.35  # keep the lost chunk visible for a moment before it drains
		_flash = 1.0
	elif p_hp > _ghost:
		_ghost = p_hp
	hp = maxf(0.0, p_hp)
	max_hp = maxf(1.0, p_max)
	shield = maxf(0.0, p_shield)
	if _ghost < hp:
		_ghost = hp


## Shield took a hit: the glass flashes and shows cracks for a moment.
func crack() -> void:
	_crack = 1.0


func _process(d: float) -> void:
	_t += d
	if _ghost_hold > 0.0:
		_ghost_hold -= d
	elif _ghost > hp:
		_ghost = maxf(hp, _ghost - max_hp * d * 0.9)
	_crack = maxf(0.0, _crack - d * 1.6)
	_flash = maxf(0.0, _flash - d * 3.0)
	queue_redraw()


func _draw() -> void:
	var r := Rect2(Vector2.ZERO, size)
	var w := size.x
	draw_rect(r, Color(0.15, 0.07, 0.07))
	# the part you just lost: pale, then it drains away
	var gw := w * clampf(_ghost / max_hp, 0, 1)
	draw_rect(Rect2(0, 0, gw, size.y), Color(1.0, 0.85, 0.6))
	# current HP
	var hw := w * clampf(hp / max_hp, 0, 1)
	var red := Color(0.78, 0.18, 0.18).lerp(Color(1, 0.9, 0.9), _flash * 0.6)
	draw_rect(Rect2(0, 0, hw, size.y), red)
	draw_rect(Rect2(0, 0, hw, size.y * 0.35), Color(1, 1, 1, 0.12))
	# shield: blue glass over the end of the HP it covers
	if shield > 0.0 and hw > 0.0:
		var sw := minf(hw, w * shield / max_hp)
		var g := Rect2(hw - sw, -3, sw, size.y + 6)
		var shimmer := 0.08 * sin(_t * 3.0)
		draw_rect(g, Color(0.55, 0.82, 1.0, 0.55 + shimmer + _crack * 0.3))
		draw_rect(g, Color(0.85, 0.95, 1.0, 0.95), false, 2.0)
		# glassy diagonal highlights
		var x := g.position.x + 6.0
		while x < g.end.x - 4.0:
			draw_line(Vector2(x, g.end.y - 3), Vector2(minf(x + 10.0, g.end.x - 2), g.position.y + 3), Color(1, 1, 1, 0.35), 2.0)
			x += 22.0
		if _crack > 0.0:
			var c := g.get_center()
			for k in 5:
				var a := k * TAU / 5.0 + 0.4
				draw_line(c, c + Vector2.from_angle(a) * g.size.y * 1.2, Color(1, 1, 1, _crack), 1.5)
	draw_rect(r, Color(0, 0, 0, 0.6), false, 2.0)
