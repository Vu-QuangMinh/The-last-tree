class_name Hud2Layout
extends RefCounted
## Theme "Puppet HUD ver 2": the HUD of assets/Puppet/UI/Hud2/Puppet HUD Nov.pdf, page 2 (the assembled screen): the left board (ten artifact slots, six debuff squares, the HP tube, five bottle
## slots), the Chant and Pass buttons between the two boards, the right board (Essence cups, Clear, the Essence tray with its round hole) and the vertical glass tube at the far right that
## the Essence come down and wait in (three of them stand in it on the page: they show how the waiting Essence are laid out). There is no slot machine.
## The page is 2048 x 1152 pt and the game 1920 x 1080: one pt = K screen px. Every number below is in PDF pt; `apply()` turns them into the values of NewUiLayout (the fight screen's
## HUD code is the New UI one, it only reads the values), and `draw()` paints the HUD for NewUiLayout.Back.
## Art: assets/Puppet/UI/Hud2/ (tools/export_hud2_art.py: cup, hole, tube from the PDF; tools/make_hud2_art.py + import_hud2_art.py: boards, slot frame, buttons made by ImageSet).
## (The page also has a second thin glass tube lying on the right board's top edge, no use named: not drawn.)

const K := 0.9375

const BOARD_LEFT := Rect2(206, 907, 735, 213)
const BOARD_RIGHT := Rect2(1112, 907, 838, 213)
const ART_TRAY := Rect2(236.5, 948.6, 350.9, 140.4)  # the artifact tray picture (hud2_art_tray.png: brass frame, ten painted slots)
const ART_SLOT_AT := Vector2(236.8, 952.5)  # the first of the ten slots (cell); five to a row: 70 pt apart across, 66 down
const ART_CELL := Vector2(70, 66)
const DEBUFF_SQ := Rect2(620, 923, 46.7, 46.7)  # the first of six debuff squares, 46.8 pt apart
const DEBUFF_STEP := 46.8
const DEBUFF_N := 6
const HP_TUBE := Rect2(592, 973, 336, 48)
const BOTTLE_TRAY := Rect2(603.7, 1027.3, 300.0, 63.4)  # the bottle tray picture (hud2_bottle_tray.png, always five slots)
const BOTTLE_SLOT_AT := Vector2(606.0, 1031.0)  # the first slot (cell), the five are 58.5 pt apart
const BOTTLE_SLOT := 56.0
const BOTTLE_STEP := 58.5
const CUP_C0 := Vector2(1160.6, 968.8)  # the first cup's centre; the ten are 74 pt apart; the cup sprite is a 64 pt disc
const CUP_STEP := 74.05
const CUP_N := 10
const CUP_D := 64.0
const TRAY := Rect2(1128, 1030, 807, 74)
const HOLE_C := Vector2(1896.0, 1066.7)  # the round hole at the tray's right end: the Essence come out of it (a 64 pt disc)
const HOLE_D := 64.0
const CLEAR_BTN := Rect2(1870.7, 935.7, 64.8, 64.8)  # the three buttons are the visible sprites of the PDF (page 2), their painted words included
const CHANT_BTN := Rect2(953.5, 913.4, 141.0, 141.2)
const PASS_BTN := Rect2(981.1, 1019.3, 85.8, 85.8)
const MENU_BTN := Rect2(69.0, 1059.8, 82.8, 53.3)
const TUBE_UPPER := Rect2(1893.6, 702.7, 147.2, 406.8)  # the vertical tube in two pictures: the front (glass, brass rings, hud2_tube_upper.png: over the Essence) ...
const TUBE_LOWER := Rect2(1927.9, 763.2, 86.9, 290.9)  # ... and the back (the far lip of the glass at both rings, hud2_tube_lower.png: under the Essence); its rims sit on the front's rings
const BOARD_COVER_X := 1936.0  # the right board is over the tube: from here to the board's right edge the board is drawn again over the Essence and the tube's front
const VTUBE_X := 1979.0  # the Essence column in it (the page's three examples stand at 1979, the lowest one turned to 1962 at the bend)
const VTUBE_TOP := 814.5  # the highest a waiting Essence stands (its centre): just under the top ring
const DROP_Y := 740.5  # an Essence comes in over the top ring and goes down into the tube
const STACK_BEND := Vector2(1966.0, 1066.7)  # the lowest waiting Essence; the others stand 60 pt apart going up the tube
const STACK_UP := Vector2(1979.0, 1006.7)  # the next one up
const STACK_STEP := 60.0
const BALL_PT := 60.0  # an Essence in the tube is 60 pt
const RING_PX := 60.0  # the Chant rings (the Essence in the cups)


static func s(r: Rect2) -> Rect2:
	return Rect2(r.position * K, r.size * K)


## Puts this HUD's values into NewUiLayout.
static func apply() -> void:
	var L = NewUiLayout
	var cup0: Vector2 = CUP_C0 * K  # (the first cup's centre: the first Chant ring and the first resting Essence stand there)
	var tray_mid := (TRAY.position.y + TRAY.size.y / 2.0) * K
	L.BAG_AT = Vector2(cup0.x - (PuppetLayout.REST_X + 26.0), tray_mid - PuppetLayout.AXIS_Y)
	L.RING_PX = RING_PX
	L.RING_STEP = CUP_STEP * K
	L.CHANT_AT = Vector2(0.0, cup0.y - PuppetLayout.RING_CY - L.BAG_AT.y)
	var chant_at: Vector2 = L.BAG_AT + L.CHANT_AT
	L.BTN_CHANT = Rect2(CHANT_BTN.position * K - chant_at, CHANT_BTN.size * K)
	L.BTN_PASS = Rect2(PASS_BTN.position * K - chant_at, PASS_BTN.size * K)
	L.BTN_CLEAR = Rect2(CLEAR_BTN.position * K - chant_at, CLEAR_BTN.size * K)
	L.MENU_BTN = s(MENU_BTN)
	L.ART_CELL = ART_CELL * K
	L.ART_COLS = 5
	L.ART_PX = 52.0
	L.ART_AT = ART_SLOT_AT * K
	L.BOTTLE_CELL = Vector2(BOTTLE_STEP, BOTTLE_SLOT) * K
	L.BOTTLE_AT = BOTTLE_SLOT_AT * K
	L.BOTTLE_PX = 46.0
	var hp_c := (HP_TUBE.position + HP_TUBE.size / 2.0) * K
	L.HP_BAR = Rect2(hp_c - Vector2(319.84, 45.01) / 2.0, Vector2(319.84, 45.01))
	var tr := s(ART_TRAY)
	L.ACT_TEXT = Rect2(tr.position.x, BOARD_LEFT.position.y * K, tr.size.x, tr.position.y - BOARD_LEFT.position.y * K)  # (the line "Act - Floor - Turn" is centred over the artifact tray, in the strip of the board above it)
	L.DEBUFF_AT = DEBUFF_SQ.position * K + (DEBUFF_SQ.size * K - Vector2.ONE * 42.0) / 2.0
	L.DEBUFF_STEP = DEBUFF_STEP * K
	L.DEBUFF_PX = 42.0
	L.DEBUFF_COLS = DEBUFF_N
	# the Essence: they come in at the top of the vertical tube, fall down it, turn left into the tray's hole and roll along the tray (strip px)
	var hole_s: Vector2 = HOLE_C * K - L.BAG_AT
	L.MOUTH_X = hole_s.x
	L.REST_END = hole_s.x - HOLE_D / 2.0 * K - 4.0
	L.TUBE_ROW_Y = PuppetLayout.AXIS_Y
	L.DROP_AT = Vector2(VTUBE_X, DROP_Y) * K - L.BAG_AT
	L.SPELL_BOTTOM = BOARD_RIGHT.position.y * K - 8.0
	L.SPELL_CENTER_X = 960.0


## Where the k-th waiting Essence stands in the vertical tube (strip px): the first at the bend, the next ones going up the tube 60 pt apart, as the page shows three of them.
static func stack_pos(k: int) -> Vector2:
	var first := STACK_BEND.distance_to(STACK_UP)
	var d := STACK_STEP * k
	var p: Vector2
	if d <= first:
		p = STACK_BEND.lerp(STACK_UP, d / first)
	else:
		p = Vector2(VTUBE_X, STACK_UP.y - (d - first))
	p.y = maxf(p.y, VTUBE_TOP)
	return p * K - NewUiLayout.BAG_AT


## The way of a new Essence (bonus, roll) from the top of the vertical tube down to its waiting place `k` (strip px): straight down the tube, round the bend when it is the lowest.
static func fall_path(k: int) -> Array:
	var pts: Array = [Vector2(VTUBE_X, DROP_Y) * K - NewUiLayout.BAG_AT]
	if k <= 0:
		pts.append(STACK_UP * K - NewUiLayout.BAG_AT)
	pts.append(stack_pos(k))
	return pts


## The way of an Essence that waits at `from` (strip px) to the hole: on down the tube, round the bend (the hole itself is the last point the caller adds).
static func exit_path(from: Vector2) -> Array:
	var pts: Array = [from]
	for p in [STACK_UP, STACK_BEND]:
		var q: Vector2 = p * K - NewUiLayout.BAG_AT
		if q.y > from.y + 0.5:
			pts.append(q)
	return pts


static func _tex(name: String) -> Texture2D:
	return UiSkin.tex(name)


static func _pic(c: Control, name: String, r: Rect2, mod := Color.WHITE) -> void:
	var t := _tex(name)
	if t != null:
		c.draw_texture_rect(t, r, false, mod)
	else:
		c.draw_rect(r, NewUiLayout.DARK)


## A picture cut into three along its width: both end caps (`cap` source px, scaled like the picture's height) keep their shape, the middle stretches.
static func _hslice(c: Control, name: String, dst: Rect2, cap: float) -> void:
	var t := _tex(name)
	if t == null:
		c.draw_rect(dst, NewUiLayout.DARK)
		return
	var w := float(t.get_width())
	var h := float(t.get_height())
	var cap_dst := cap * dst.size.y / h  # (the picture is scaled to the height it is drawn at: the caps keep their shape)
	c.draw_texture_rect_region(t, Rect2(dst.position, Vector2(cap_dst, dst.size.y)), Rect2(0, 0, cap, h))
	c.draw_texture_rect_region(t, Rect2(dst.position.x + cap_dst, dst.position.y, dst.size.x - 2.0 * cap_dst, dst.size.y), Rect2(cap, 0, w - 2.0 * cap, h))
	c.draw_texture_rect_region(t, Rect2(dst.end.x - cap_dst, dst.position.y, cap_dst, dst.size.y), Rect2(w - cap, 0, cap, h))


## The tint of a button's state (one picture each; the states are tints).
static func tint_of(state: String) -> Color:
	return {"normal": Color.WHITE, "hover": Color(1.15, 1.1, 1.02), "pressed": Color(0.72, 0.68, 0.64), "disabled": Color(0.6, 0.56, 0.55)}[state]


## Draws the HUD on `c` (a NewUiLayout.Back, at the screen's origin): back to front the left board with its artifact slots, the bottle board with its five slots, the right board with its
## cups, the tray and its hole, the vertical tube, the Menu button and the debuff circles. (Chant / Pass / Clear are real Buttons of the fight screen.)
static func draw(c) -> void:
	_pic(c, "hud2_board_left", s(BOARD_LEFT))
	_pic(c, "hud2_art_tray", s(ART_TRAY))
	_pic(c, "hud2_bottle_tray", s(BOTTLE_TRAY))
	_pic(c, "hud2_board_right", s(BOARD_RIGHT))
	for k in CUP_N:
		_pic(c, "hud2_cup", s(Rect2(CUP_C0 + Vector2(CUP_STEP * k, 0.0) - Vector2.ONE * CUP_D / 2.0, Vector2.ONE * CUP_D)))
	_hslice(c, "hud2_tray", s(TRAY), 170.0)
	_pic(c, "hud2_hole", s(Rect2(HOLE_C - Vector2.ONE * HOLE_D / 2.0, Vector2.ONE * HOLE_D)))
	_pic(c, "hud2_btn_menu_pressed" if c.menu_state == 2 else "hud2_btn_menu", s(MENU_BTN), tint_of("hover" if c.menu_state == 1 else "normal"))
	var sock := _tex("nu_debuff_ring")
	for k in c.debuffs:
		var at := NewUiLayout.debuff_slot(k, 1)
		if sock != null:
			c.draw_texture_rect(sock, Rect2(at, Vector2.ONE * NewUiLayout.DEBUFF_PX), false)
		else:
			c.draw_arc(at + Vector2.ONE * NewUiLayout.DEBUFF_PX / 2.0, NewUiLayout.DEBUFF_PX / 2.0, 0.0, TAU, 32, Color(0.8, 0.6, 0.3), 1.5)
