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
var _shown := false  # set once: entering a fight with missing HP isn't damage




func set_values(p_hp: float, p_max: float, p_shield: float) -> void:
	if not _shown:
		_shown = true
		hp = maxf(0.0, p_hp)
		_ghost = hp
		max_hp = maxf(1.0, p_max)
		shield = maxf(0.0, p_shield)
		return
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


## New theme: the bar is built from painted pieces, left to right: [left cap][body: HP | Shield | Blank][right cap].
## HP is red, the Shield (blue) covers the end of the HP it protects, and what's left of the bar is Blank (grey).
## The caps change with the state: left = HP, Shield (the shield reaches the left end) or Blank (no HP left);
## right = HP (full, no shield), Shield (full, with shield) or Blank (not full). The just-lost chunk shows pale.
func _draw_art() -> bool:
	var parts := {}
	for n in ["hp_body_hp", "hp_body_shield", "hp_body_blank", "hp_head_left_hp", "hp_head_left_shield", "hp_head_left_blank",
			"hp_head_right_hp", "hp_head_right_shield", "hp_head_right_blank"]:
		parts[n] = UiSkin.tex(n)
		if parts[n] == null:
			return false
	var w := size.x
	var h := size.y
	var ref: Texture2D = parts["hp_head_left_hp"]
	var cap: float = ref.get_width() * h / ref.get_height()
	var hw := w * clampf(hp / max_hp, 0, 1)
	var sw := minf(hw, w * shield / max_hp)
	var tint := Color(1, 1, 1).lerp(Color(1.7, 1.5, 1.5), _flash * 0.6)
	# body: only the stretch between the two caps (a segment is clipped to it, so nothing pokes out past a cap)
	var gw := w * clampf(_ghost / max_hp, 0, 1)
	_body(parts["hp_body_blank"], 0.0, w, cap, w, h, Color.WHITE)
	if gw > hw:
		_body(null, hw, gw, cap, w, h, Color(1.0, 0.85, 0.6))
	if hw - sw > 0.0:
		_body(parts["hp_body_hp"], 0.0, hw - sw, cap, w, h, tint)
	if sw > 0.0:
		_body(parts["hp_body_shield"], hw - sw, hw, cap, w, h, tint)
	# caps
	var left := "blank" if hp <= 0.0 else ("shield" if sw > 0.0 and hw - sw < cap * 0.5 else "hp")
	var right := "hp" if hw >= w - 0.5 and sw <= 0.0 else ("shield" if hw >= w - 0.5 else "blank")
	draw_texture_rect(parts["hp_head_left_" + left], Rect2(0, 0, cap, h), false, tint if left != "blank" else Color.WHITE)
	draw_texture_rect(parts["hp_head_right_" + right], Rect2(w - cap, 0, cap, h), false, tint if right != "blank" else Color.WHITE)
	if sw > 0.0 and _crack > 0.0:
		var c := Vector2(hw - sw / 2.0, h / 2.0)
		for k in 5:
			var a := k * TAU / 5.0 + 0.4
			draw_line(c, c + Vector2.from_angle(a) * h * 1.2, Color(1, 1, 1, _crack), 1.5)
	return true


## One stretch of the body from x0 to x1, kept between the caps (cap .. w - cap). tex null = a pale plain block.
func _body(tex: Texture2D, x0: float, x1: float, cap: float, w: float, h: float, tint: Color) -> void:
	x0 = maxf(x0, cap)
	x1 = minf(x1, w - cap)
	if x1 <= x0:
		return
	if tex == null:
		draw_rect(Rect2(x0, h * 0.22, x1 - x0, h * 0.56), tint)
	else:
		draw_texture_rect(tex, Rect2(x0, 0, x1 - x0, h), false, tint)


func _draw() -> void:
	if _draw_art():
		return
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
	_draw_shield(w, size.y, hw)
	draw_rect(r, Color(0, 0, 0, 0.6), false, 2.0)


## shield: blue glass over the end of the HP it covers
func _draw_shield(w: float, h: float, hw: float) -> void:
	if shield > 0.0 and hw > 0.0:
		var sw := minf(hw, w * shield / max_hp)
		var g := Rect2(hw - sw, -3, sw, h + 6)
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
