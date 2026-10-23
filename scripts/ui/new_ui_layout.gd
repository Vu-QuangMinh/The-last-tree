class_name NewUiLayout
extends RefCounted
## The "New UI" theme's HUD (the HUD of the Puppet look, laid out again): page 2 of assets/Puppet/_Source/Chant UI for puppet.pdf (1920 x 1080 = the screen, 1 pt = 1 design px).
## The pictures of that page (three dark wood blocks, the artifact and bottle slots, the Bag tray, the tube's mouth, the two layers of the glass HP tube, the debuff ring) are cut out by
## tools/export_new_ui_art.py into assets/Puppet/UI/NewUi/ and drawn at the places the page gives them (Back, Bar below). The chant rings and buttons are the Puppet ones; the slot
## machine is the Puppet one, bigger (MACHINE_SCALE), at the right end of the Bag tray: its tube is straight and the Essence roll out of its mouth (MOUTH_X) into the tray.

const BAG_AT := Vector2(701.0, 970.0)  # the Bag strip's top-left on the screen (the Chant rings and the Essence rows are laid from it); the Chant strip is PuppetLayout.CHANT_AT above it
const MENU_BTN := Rect2(17.0, 917.0, 106.0, 26.0)  # the Menu button: the part of the first dark tab that shows above the artifact block (its word MENU stands on it)
const ACT_TEXT := Rect2(141.0, 918.0, 180.0, 28.0)  # "Act1 - Floor 5 - Turn 2" on the second tab: always shown
const MENU_HOVER := Color(1.35, 1.3, 1.25)  # the Menu tab under the mouse: lighter; pressed: darker
const MENU_DOWN := Color(0.55, 0.52, 0.5)
const ART_AT := Vector2(24.12, 962.4)  # the artifact slots: two strips of five (each 262.44 x 55.74 pt, 52.49 pt a slot, the rows 51.81 apart)
const ART_CELL := Vector2(52.49, 51.81)
const ART_COLS := 5
const ART_MAX := 10
const ART_PX := 44.0  # an artifact inside its slot
const BOTTLE_AT := Vector2(370.95, 989.23)  # the bottle slots: one strip of five
const BOTTLE_CELL := Vector2(52.49, 55.74)
const BOTTLE_MAX := 5
const BOTTLE_PX := 44.0
const HP_BAR := Rect2(342.25, 939.04, 319.84, 45.01)  # the glass tube: the lower layer, the liquid, the glass with its shine, the cap, the upper layer (the brass clamps)
const HP_FILL := Rect2(9.75, 2.96, 310.0, 32.0)  # "HP fill": the glass pill, flat at its left end and round at its right (from HP_BAR's top left): HP and Shield run inside it
const HP_CAP := Rect2(3.75, 1.96, 12.0, 33.0)  # "HP cap": the brass cap on the tube's left end (only decoration)
const HP_PX := 17
const DEBUFF_AT := Vector2(324.9, 866.6)  # the debuff circles: eight in a row, the next ones start a row above
const DEBUFF_STEP := 44.64
const DEBUFF_PX := 41.0
const DEBUFF_COLS := 8
## The Bag tray: the Essence rest in it from its left end to the tube's mouth.
const MOUTH_X := 802.0  # the middle of the tube's mouth, from the Bag strip's left (strip px): the Essence roll out of the tube there
const REST_END := 790.0  # the resting Essence end before this x (strip px): the mouth's flange
## The machine (Slot_machine pieces of the Puppet theme, drawn MACHINE_SCALE times bigger as the page has them): MACHINE_POS is where the old machine's origin (the Bag strip's
## corner of PuppetLayout) lands in strip px; the straight tube lies from the mouth to under the cabinet.
const MACHINE_SCALE := 1.44
const MACHINE_POS := Vector2(-374.4, 222.0)
const LEVER_SHIFT := Vector2(0.0, 1.5)  # in the old machine's px
const TUBE_AT := Vector2(810.0, -4.0)  # slot_tube_straight.png (2 px per pt) from the strip's corner
const TUBE_CLAMP_AT := Vector2(899.0, -4.0)  # slot_tube_clamp.png
const TUBE_ROW_Y := 45.0  # the row the Essence roll along

const BLOCKS := [  # [picture, where (, "menu")] in the order they are painted (each one over the one before): the two tabs first (the Menu button and the Act line), then the blocks
	["nu_block_wide", Rect2(7.91, 923.16, 704.62, 170.66), "menu"],
	["nu_block_wide", Rect2(115.73, 916.97, 704.62, 170.66)],
	["nu_block_left", Rect2(-0.52, 949.81, 540.57, 132.8)],
	["nu_block_wide", Rect2(305.53, 910.78, 704.62, 170.66)],
	["nu_block_wide", Rect2(668.89, 863.51, 899.77, 217.93)],
]
## The spell cards (page 2: eight card boxes 192.17 x 150.66 pt, 200.75 apart, the row from x 126.96 to 1725.54, the bottom edge at y 863.10): the cards are drawn at that size
## (SPELL_FIT of their own), 8.58 apart, the row centred on the page's row (fewer cards stand around the same middle).
const SPELL_FIT := 192.17 / 250.0
const SPELL_GAP := 8.58
const SPELL_BOTTOM := 863.1
const SPELL_CENTER_X := 926.25
const TRAY := Rect2(694.44, 969.2, 821.0, 88.94)
const MOUTH := Rect2(1495.22, 963.75, 15.43, 98.59)
const ART_STRIPS := [Vector2(24.12, 960.47), Vector2(24.12, 1012.28)]  # slot strips, 262.44 x 55.74
const BOTTLE_STRIP := Vector2(370.95, 989.23)
const STRIP_SIZE := Vector2(262.44, 55.74)

const DARK := Color(0.212, 0.152, 0.111)
const LIQUID_TRACK := Color(0.05, 0.03, 0.03, 0.45)  # the empty part of the tube
const HP_RED := Color(0.45, 0.01, 0.03)
const HP_BLUE := Color(0.04, 0.42, 0.95)


static func art_slot(i: int) -> Vector2:
	return ART_AT + Vector2((i % ART_COLS) * ART_CELL.x, (i / ART_COLS) * ART_CELL.y)


static func bottle_slot(i: int) -> Vector2:
	return BOTTLE_AT + Vector2(i * BOTTLE_CELL.x, 0.0)


## The debuff circle k of `rows` rows: its top-left. The first row is the top one and the bottom row always stands at DEBUFF_AT (more rows grow upwards).
static func debuff_slot(k: int, rows: int) -> Vector2:
	return DEBUFF_AT + Vector2((k % DEBUFF_COLS) * DEBUFF_STEP, (k / DEBUFF_COLS - (rows - 1)) * (DEBUFF_PX + 4.0))


## The blocks, the slots, the Bag tray, the HP groove and the debuff circles of the HUD (in screen px: put it at the screen's origin).
class Back extends Control:
	var debuffs := 0  # how many debuff icons there are (a ring for each)
	var menu_state := 0  # the Menu tab: 0 as it is, 1 under the mouse (lighter), 2 pressed (darker)

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _pic(tex_name: String, r: Rect2, mod := Color.WHITE) -> void:
		var tex := UiSkin.tex(tex_name)
		if tex != null:
			draw_texture_rect(tex, r, false, mod)
		else:
			draw_rect(r, NewUiLayout.DARK)

	func _draw() -> void:
		for b in NewUiLayout.BLOCKS:
			var mod := Color.WHITE
			if b.size() > 2 and b[2] == "menu":
				mod = [Color.WHITE, NewUiLayout.MENU_HOVER, NewUiLayout.MENU_DOWN][menu_state]
			_pic(b[0], b[1], mod)
		_pic("nu_bag_tray", NewUiLayout.TRAY)
		for at in NewUiLayout.ART_STRIPS:
			_pic("nu_slot_strip", Rect2(at, NewUiLayout.STRIP_SIZE))
		_pic("nu_slot_strip", Rect2(NewUiLayout.BOTTLE_STRIP, NewUiLayout.STRIP_SIZE))
		_pic("nu_tube_mouth", NewUiLayout.MOUTH)
		var rows := maxi(1, ceili(debuffs / float(NewUiLayout.DEBUFF_COLS)))
		var sock := UiSkin.tex("nu_debuff_ring")
		for k in debuffs:  # one ring for each debuff there is, none for the empty places
			var at := NewUiLayout.debuff_slot(k, rows)
			if sock != null:
				draw_texture_rect(sock, Rect2(at, Vector2.ONE * NewUiLayout.DEBUFF_PX), false)
			else:
				draw_arc(at + Vector2.ONE * NewUiLayout.DEBUFF_PX / 2.0, NewUiLayout.DEBUFF_PX / 2.0, 0.0, TAU, 32, Color(0.8, 0.6, 0.3), 1.5)


## Your HP: a glass tube. Bottom to top: the lower layer (the glass and the back of the clamps), the HP fill (the liquid: the HP in red, the Shield and Lasting in blue after it, the rest
## of the pill empty, all inside HP_FILL; blended with Overlay, see FILL_STRENGTH), the gloss (the glass's shine, over the liquid), the upper layer (the front of the brass clamps).
const FILL_STRENGTH := 0.8  # (the Multiply layer: how strongly the liquid colour tints the wood behind it)
const SOLID_ALPHA := 0.9  # the plain-colour copy of the liquid (Normal blend, 90 %)
const SLOSH_K := 90.0  # the liquid's spring: stiffness and damping (a little under critical: it overshoots about a third and rocks back twice)
const SLOSH_C := 7.0
const LIQUID_TOP_SHADE := 1.2  # the liquid is lighter at the top and darker at the bottom of the tube
const LIQUID_BOTTOM_SHADE := 0.75
const WAVE_AMP_REST := 1.0  # px: how much the surface ripples at rest, and how much more right after a hit
const WAVE_AMP_HIT := 2.4
const WAVE_SPEED_REST := 0.5  # how fast the waves run at rest (1 = the old speed), and how much faster right after a hit
const WAVE_SPEED_HIT := 1.8
const AGITATE_HOLD := 2.0  # seconds the waves stay at full strength after a hit
const AGITATE_FADE := 2.0  # ... then seconds they take to calm down to the gentle ripple
const WAVE_AMP_MAX := 3.0  # px: LIQUID_LEVEL minus this must stay clear of the 1.6 px the shine keeps inside the glass, plus half its width
const LIQUID_LEVEL := 7.0  # px: how far the liquid's surface lies below the top of the glass pill (room for the waves)
const GLOSS_STRENGTH := 0.55  # the gloss layer over the liquid (nu_hp_gloss = assets/Puppet/_Source/Asset 6.png, the new HP fill): Screen blend too
class Bar extends HpBar:
	var _fill: Control  # the HP fill layer: Screen blend at 50 %
	var _solid: Control  # a second copy of the liquid (same waves) in plain colour at 90 %: the body of the colour under the Overlay one
	var _gloss: Control  # the glass's gloss, just over the liquid and under the upper layer
	var _cap: Control  # the brass cap on the left end (decoration)
	var _upper: Control
	var _xr := 0.0  # where the red liquid ends right now (px of the pill): it follows its goal like a spring, so it overshoots and rocks
	var _vr := 0.0
	var _xs := 0.0  # where the Shield (blue) starts: it lies over the end of the red, from here to where the red ends
	var _vs := 0.0
	var _wave_t := 0.0  # the waves' own clock: it runs slowly at rest and fast just after a hit
	var _agit := 0.0  # 1 from a hit until AGITATE_HOLD is over, then it falls to 0 over AGITATE_FADE seconds (the liquid is calm again)
	var _hold := 0.0
	var _started := false

	## Screen blend at `strength`, done as Add (screen(a, b) = a + b - a*b is almost a + b over this dark wood): the Screen shader reads the screen behind the node, and two of them in a
	## row would both read it before either was drawn (the second erases the first).
	func _screen(c: Control, strength: float) -> void:
		var m := CanvasItemMaterial.new()
		m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		c.material = m
		c.modulate.a = strength * 0.8  # (Screen only adds src * (1 - dst), and this wood is about 0.2 bright: Add overshoots by 1 / 0.8)

	func _ready() -> void:
		# (the painted bars of the other themes are not used: no layer, no frame)
		_fill = Control.new()
		_fill.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var mul := CanvasItemMaterial.new()  # (Multiply: the dark wood shows through the colour; no shader reads the screen, see _poly)
		mul.blend_mode = CanvasItemMaterial.BLEND_MODE_MUL
		_fill.material = mul
		_fill.draw.connect(func() -> void: _draw_liquid(_fill))
		add_child(_fill)
		_solid = Control.new()
		_solid.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		_solid.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_solid.modulate.a = NewUiLayout.SOLID_ALPHA  # (Normal blend)
		_solid.draw.connect(func() -> void: _draw_liquid(_solid))
		add_child(_solid)
		_gloss = Control.new()
		_gloss.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		_gloss.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_screen(_gloss, NewUiLayout.GLOSS_STRENGTH)
		_gloss.draw.connect(func() -> void:
			var tex := UiSkin.tex("nu_hp_gloss")
			if tex != null:
				_gloss.draw_texture_rect(tex, NewUiLayout.HP_FILL, false))
		add_child(_gloss)
		_cap = Control.new()
		_cap.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		_cap.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_cap.draw.connect(func() -> void:
			var tex := UiSkin.tex("nu_hp_cap")
			if tex != null:
				_cap.draw_texture_rect(tex, NewUiLayout.HP_CAP, false))
		add_child(_cap)
		_upper = Control.new()
		_upper.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		_upper.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_upper.draw.connect(func() -> void:
			var tex := UiSkin.tex("nu_hp_upper")
			if tex != null:
				_upper.draw_texture_rect(tex, Rect2(Vector2.ZERO, size), false))
		add_child(_upper)

	func _process(d: float) -> void:
		super(d)
		var p := parts()
		if not _started:
			_started = true
			_xr = p.x
			_xs = p.x - p.y
		# the liquid is a mass on a spring: when its goal moves (you are hit, you heal, a shield is put up) it runs there, overshoots and rocks back (a little under critical damping)
		var dt := minf(d, 0.05)
		_vr += (-NewUiLayout.SLOSH_K * (_xr - p.x) - NewUiLayout.SLOSH_C * _vr) * dt
		_xr += _vr * dt
		_vs += (-NewUiLayout.SLOSH_K * (_xs - (p.x - p.y)) - NewUiLayout.SLOSH_C * _vs) * dt
		_xs += _vs * dt
		if _hold > 0.0:
			_hold -= dt
			_agit = 1.0
		else:
			_agit = maxf(0.0, _agit - dt / NewUiLayout.AGITATE_FADE)
		_wave_t += dt * (NewUiLayout.WAVE_SPEED_REST + NewUiLayout.WAVE_SPEED_HIT * _agit)
		_fill.queue_redraw()
		_solid.queue_redraw()
		_gloss.queue_redraw()
		_cap.queue_redraw()
		_upper.queue_redraw()

	## A hit that takes HP agitates the liquid (the Shield breaking does too: see crack).
	func set_values(p_hp: float, p_max: float, p_shield: float) -> void:
		if _started and p_hp < hp:
			_hit()
		super(p_hp, p_max, p_shield)

	func crack() -> void:
		super()
		_hit()

	func _hit() -> void:
		_agit = 1.0
		_hold = NewUiLayout.AGITATE_HOLD

	## The HP liquid's length and the Shield's, in px of the pill. The Shield lies OVER the end of the HP (it never makes the liquid longer): it is as long as the HP it covers,
	## at most the whole HP.
	func parts() -> Vector2:
		var iw := NewUiLayout.HP_FILL.size.x
		var hp_px := iw * clampf(hp / maxf(max_hp, 1.0), 0.0, 1.0)
		return Vector2(hp_px, minf(iw * clampf(shield / maxf(max_hp, 1.0), 0.0, 1.0), hp_px))

	## A wave of the liquid's surface at x (the glass's top is y = 0): a little all the time, bigger while the liquid is moving (`v`, px/s), travelling along the tube.
	func _surface_y(x: float, v: float) -> float:
		# `amp` is the highest the surface ever goes above or below its level (the three waves add up to at most 1.85, so the sum is divided by that): kept under WAVE_AMP_MAX so
		# the crest never reaches the top of the glass, where the shine would be cut off
		var amp := minf(NewUiLayout.WAVE_AMP_REST + NewUiLayout.WAVE_AMP_HIT * _agit + minf(absf(v) * 0.008, 0.8), NewUiLayout.WAVE_AMP_MAX)
		return NewUiLayout.LIQUID_LEVEL + amp * (sin(x * 0.085 + _wave_t * 3.4) + 0.55 * sin(x * 0.21 - _wave_t * 4.6) + 0.3 * sin(x * 0.043 + _wave_t * 1.7)) / 1.85

	## How far a free end of the liquid (its right end, the Shield's left end) is pushed sideways at height y: the same kind of wave, standing up.
	func _edge_dx(y: float, phase: float, v: float) -> float:
		var amp := 0.5 * (NewUiLayout.WAVE_AMP_REST + NewUiLayout.WAVE_AMP_HIT * _agit) + minf(absf(v) * 0.01, 1.0)
		return amp * (sin(y * 0.30 + _wave_t * 3.6 + phase) + 0.5 * sin(y * 0.71 - _wave_t * 5.3 + phase * 2.0)) * 0.7

	## The pill the liquid lies in: flat at the left end, round at the right (HP_FILL, from its own top left).
	func _pill() -> PackedVector2Array:
		var f: Rect2 = NewUiLayout.HP_FILL
		var r := f.size.y / 2.0
		var out := PackedVector2Array([Vector2(0, 0), Vector2(f.size.x - r, 0)])
		for k in range(1, 12):
			var a := -PI / 2.0 + PI * k / 12.0
			out.append(Vector2(f.size.x - r, r) + Vector2(cos(a), sin(a)) * r)
		out.append(Vector2(f.size.x - r, f.size.y))
		out.append(Vector2(0, f.size.y))
		return out

	## Fills a polygon (the pill's own coordinates) clipped to the pill. The colour is lighter at the top and darker at the bottom (a rounded body of liquid, not a flat sheet).
	func _poly(node: Control, pts: PackedVector2Array, col: Color, shaded := true) -> void:
		if pts.size() < 3:
			return
		if node == _fill:  # (Multiply ignores alpha: "strength" is how far the colour is from white)
			col = Color(1, 1, 1, 1).lerp(Color(col, 1.0), NewUiLayout.FILL_STRENGTH)
		var f: Rect2 = NewUiLayout.HP_FILL
		for part in Geometry2D.intersect_polygons(pts, _pill()):
			var moved := PackedVector2Array()
			var cols := PackedColorArray()
			for q in part:
				moved.append(q + f.position)
				var shade := lerpf(NewUiLayout.LIQUID_TOP_SHADE, NewUiLayout.LIQUID_BOTTOM_SHADE, clampf(q.y / f.size.y, 0.0, 1.0)) if shaded else 1.0
				cols.append(Color(col.r * shade, col.g * shade, col.b * shade, col.a))
			if moved.size() >= 3 and not Geometry2D.triangulate_polygon(moved).is_empty():  # (a polygon that crosses itself, e.g. a very short Shield in a wave, is skipped)
				node.draw_polygon(moved, cols)

	## One body of liquid from x0 to x1 (px of the pill): a wavy surface on top, a wavy free end on the side(s) that are not the pill's flat end, flat at the bottom.
	## `wave_l` / `wave_r`: whether its left / right end is a free end (it ripples), `ph_l` / `ph_r` the phase of that ripple, `vl` / `vr` how fast those ends move.
	func _liquid_body(x0: float, x1: float, wave_l: bool, ph_l: float, vl: float, wave_r: bool, ph_r: float, vr: float, v_surf: float) -> PackedVector2Array:
		var h: float = NewUiLayout.HP_FILL.size.y
		var top := NewUiLayout.LIQUID_LEVEL
		var pts := PackedVector2Array()
		var n := maxi(2, ceili((x1 - x0) / 6.0))
		for k in n + 1:  # the surface, left to right
			var x := lerpf(x0, x1, float(k) / n)
			pts.append(Vector2(x, _surface_y(x, v_surf)))
		for k in 9:  # the right end, down
			var y := lerpf(top, h, k / 8.0)
			pts.append(Vector2(x1 + (_edge_dx(y, ph_r, vr) if wave_r else 0.0), y))
		for k in 9:  # the left end, up
			var y := lerpf(h, top, k / 8.0)
			pts.append(Vector2(x0 + (_edge_dx(y, ph_l, vl) if wave_l else 0.0), y))
		return pts

	## The liquid drawn on `node`: the same shape (and the same waves) on both liquid layers. Only the plain layer (`_solid`) gets the shine: a bright line along the surface, a soft
	## light band just under it (the meniscus) and a few bubbles rising.
	func _draw_liquid(node: Control) -> void:
		var f: Rect2 = NewUiLayout.HP_FILL
		var iw := f.size.x
		var h := f.size.y
		var tint := Color.WHITE.lerp(Color(1.5, 1.3, 1.3), _flash * 0.7)
		var p := parts()
		_poly(node, _pill(), NewUiLayout.LIQUID_TRACK, false)
		var xr := clampf(_xr, 0.0, iw)
		var xs := clampf(_xs, 0.0, xr)
		var has_shield := xr - xs > 0.5
		var vsf := maxf(absf(_vr), absf(_vs))  # (one surface for the red and the Shield: it must not show the red under the blue)
		if xr > 0.5:
			_poly(node, _liquid_body(0.0, xr, false, 0.0, 0.0, true, 0.0, _vr, vsf), NewUiLayout.HP_RED * tint)
		if has_shield:  # the Shield lies over the end of the red; its right end is the red's, so it ripples in step with it
			_poly(node, _liquid_body(xs, xr, true, 1.7, _vs, true, 0.0, _vr, vsf), NewUiLayout.HP_BLUE * tint)
		if node != _solid or xr <= 0.5:
			return
		# the shine: a line along the surface (the red and the Shield each have their own), a soft band under it and a fainter reflection: all cut to the pill
		var clip_in := PackedVector2Array()
		for q in _pill():
			clip_in.append(q + f.position)
		var clips := Geometry2D.offset_polygon(clip_in, -1.6)  # (the lines are 1.4 px wide: their middle stays this far inside the glass so no edge of them pokes out)
		var clip: PackedVector2Array = clips[0] if not clips.is_empty() else clip_in
		var segs := [[0.0, xs if has_shield else xr, vsf]]
		if has_shield:
			segs.append([xs, xr, vsf])
		for sg in segs:
			var x0: float = sg[0] + (3.0 if sg[0] > 0.5 else 0.0)  # (a free end of the liquid ripples sideways: the shine stays clear of it)
			var x1: float = sg[1] - 3.0
			if x1 - x0 < 1.0:
				continue
			var n := maxi(2, ceili((x1 - x0) / 6.0))
			var tops := PackedVector2Array()
			var refl := PackedVector2Array()
			for k in n + 1:
				var x := lerpf(x0, x1, float(k) / n)
				var q := Vector2(x + f.position.x, _surface_y(x, sg[2]) + f.position.y)
				tops.append(q)
				refl.append(q + Vector2(0, 8.0))
			for part in Geometry2D.intersect_polyline_with_polygon(tops, clip):
				if part.size() >= 2:
					node.draw_polyline(part, Color(1, 1, 1, 0.55), 1.4, true)
			for part in Geometry2D.intersect_polyline_with_polygon(refl, clip):
				if part.size() >= 2:
					node.draw_polyline(part, Color(1, 1, 1, 0.14), 2.2, true)
			var band := PackedVector2Array(tops)  # the meniscus: light at the surface, gone 4 px under it
			for k in range(tops.size() - 1, -1, -1):
				band.append(tops[k] + Vector2(0, 4.0))
			for part in Geometry2D.intersect_polygons(band, clip):
				var cols := PackedColorArray()
				for q in part:
					var under := q.y - (_surface_y(q.x - f.position.x, sg[2]) + f.position.y)
					cols.append(Color(1, 1, 1, 0.30 * clampf(1.0 - under / 4.0, 0.0, 1.0)))
				if part.size() >= 3 and not Geometry2D.triangulate_polygon(part).is_empty():
					node.draw_polygon(part, cols)
		for i in 6:  # bubbles: rise slowly, drift a little, sway
			var life := fmod(_wave_t * (0.12 + 0.03 * i) + i * 0.173, 1.0)
			var bx := fmod(i * 0.381 + 0.07, 1.0) * maxf(xr - 6.0, 1.0) + 3.0 + 2.0 * sin(_wave_t * 1.3 + i * 2.1)
			var by := lerpf(h - 3.0, NewUiLayout.LIQUID_LEVEL + 4.0, life)
			if bx < xr - 3.0:
				node.draw_circle(Vector2(bx, by) + f.position, 0.9 + 0.5 * fmod(i * 0.37, 1.0), Color(1, 1, 1, 0.35 * sin(life * PI)))
		if _crack > 0.0 and has_shield:
			var c := Vector2(f.position.x + (xr + xs) / 2.0, f.position.y + h / 2.0)
			for k in 5:
				var a := k * TAU / 5.0 + 0.4
				node.draw_line(c, c + Vector2.from_angle(a) * h * 1.2, Color(1, 1, 1, _crack), 1.5)

	func _draw() -> void:
		var lower := UiSkin.tex("nu_hp_lower")
		if lower != null:
			draw_texture_rect(lower, Rect2(Vector2.ZERO, size), false)
