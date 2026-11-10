class_name Hud2Layout
extends RefCounted
## Theme "Puppet HUD ver 2": the HUD of assets/Puppet/UI/Hud2/Puppet HUD Nov.pdf, page 2 (the assembled screen): the left board (ten artifact slots, six debuff squares, the HP tube, five bottle
## slots), the Chant and Pass buttons between the two boards, the right board (Essence cups, Clear, the Essence tray with its round hole) and the vertical glass tube at the far right that
## the Essence come down and wait in (three of them stand in it on the page: they show how the waiting Essence are laid out). There is no slot machine.
## The page is 2048 x 1152 pt and the game 1920 x 1080: one pt = K screen px. Every number below is in PDF pt; `apply()` turns them into the values of NewUiLayout (the fight screen's
## HUD code is the New UI one, it only reads the values), and `draw()` paints the HUD for NewUiLayout.Back.
## Art: assets/Puppet/UI/Hud2/ (tools/export_hud2_art.py: cup, hole, tube from the PDF; tools/make_hud2_art.py + import_hud2_art.py: boards, slot frame, buttons made by ImageSet).
## Theme MinhHUD shares this class: `minh` is true while its values are in (apply_minh() sets them, apply() puts these ones back), its page is the screen itself (K = 1) and `draw()` /
## `track_pts()` / `stack_pos()` branch on it. The page: page 2 of assets/Puppet/UI/MinhHUD/MinhHUD.pdf (the HUD assembled at the bottom of it; the pieces drawn above are the flip of the round button and the bottle cabinet's hint).
## (The page also has a second thin glass tube lying on the right board's top edge, no use named: not drawn.)

static var K := 0.9375

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
static var VTUBE_X := 1979.0  # the Essence column in it (the page's three examples stand at 1979, the lowest one turned to 1962 at the bend)
static var VTUBE_TOP := 814.5  # the highest a waiting Essence stands (its centre): just under the top ring
static var DROP_Y := 740.5  # an Essence comes in over the top ring and goes down into the tube
static var STACK_BEND := Vector2(1966.0, 1066.7)  # the lowest waiting Essence; the others stand 60 pt apart going up the tube
static var STACK_UP := Vector2(1979.0, 1006.7)  # the next one up
static var STACK_STEP := 60.0
static var BALL_PT := 60.0  # an Essence in the tube is 60 pt
static var RING_PX := 60.0  # the Chant rings (the Essence in the cups)


static var minh := false  # theme MinhHUD's values are in


## Puppet HUD ver 2's own values of the variables the fight screen reads (apply_minh changes them).
static func _hud2_values() -> void:
	minh = false
	K = 0.9375
	VTUBE_X = 1979.0
	VTUBE_TOP = 814.5
	DROP_Y = 740.5
	STACK_BEND = Vector2(1966.0, 1066.7)
	STACK_UP = Vector2(1979.0, 1006.7)
	STACK_STEP = 60.0
	BALL_PT = 60.0
	RING_PX = 60.0


static func s(r: Rect2) -> Rect2:
	return Rect2(r.position * K, r.size * K)


## Puts this HUD's values into NewUiLayout.
static func apply() -> void:
	_hud2_values()
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
	if minh:  # (MinhHUD: they wait one under the other in the pipe's column, the first at the top, the rest going down it and out of the screen)
		return (STACK_BEND + Vector2(0.0, STACK_STEP * k)) * K - NewUiLayout.BAG_AT
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
	if minh:
		_draw_minh(c)
		return
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


## ---- Theme MinhHUD -----------------------------------------------------------------------------------------------------------------------------------------------------
## The HUD assembled at the bottom of page 2 of assets/Puppet/UI/MinhHUD/MinhHUD.pdf (1920 x 1080 = the screen, so one pt = one px), every number below read off that page (the images'
## places and sizes, the clip paths, the drawing order = the z order). Left to right on a wooden base: the artifact cabinet (two shelves of five pedestals, a glass over them), the bottle
## cabinet (a stand of three, a glass over it), the round Chant / Pass button (flips into Release), the wooden Chant tray (ten sockets: the Chant rings lie in them), then the glass pipe:
## its left part is a straight tube (the Essence rest in it), an Essence is pushed up into the column from below the screen, waits there, and when it is let go runs over the top of the
## loop, down the right side and left along the bottom into the straight tube. The red glass flask in the loop's hole is your HP (and Shield); the brass hub and lever sit on it.
## The pictures are the user's: assets/Puppet/UI/MinhHUD/ (the folders are the PDF's parts); MinhParts (minh_parts.gd) holds the layers that sit over the cards of the HUD.
const M_BASE := Rect2(101.269, 814.298, 1483.035, 250.0)
const M_ART_CAB := Rect2(139.676, 853.856, 288.824, 178.165)  # the artifacts stand inside it (between this and its glass)
const M_BOT_CAB := Rect2(481.961, 852.717, 183.93, 180.444)
const M_BOT_BACK := Rect2(500.376, 870.369, 147.101, 145.139)
const M_BOT_BEHIND := Rect2(515.671, 982.586, 116.511, 5.227)  # the back edge of the stand, behind the bottles
const M_TRAY_BEHIND := Rect2(990.596, 915.206, 542.273, 11.863)  # the Chant tray's back, behind the rings (its front is over them: MinhParts)
const M_FLASK := Rect2(1635.894, 806.653, 170.323, 170.323)
const M_LOOP_C := Vector2(1721.055, 891.8)  # the loop's centre = the flask's and the hub's centre = the lever's pivot
const M_LOOP_R := 110.8  # the pipe's middle line: the column is M_LOOP_R left of the centre, the bottom leg M_LOOP_R under it (the tube is 54 wide)
const M_CHANT_BTN := Rect2(768, 866, 150, 100)  # the real Buttons over the round button: Chant (the red upper part), Pass (the plate under it) or, once the chant is spoken, Release (all of it)
const M_PASS_BTN := Rect2(785, 970, 115, 48)
const M_RELEASE_BTN := Rect2(768, 864, 150, 150)
const M_CLEAR_BTN := Rect2(1503, 829, 48, 48)  # (the page has no Clear: the Puppet HUD ver 2 picture goes between the Chant tray and the pipe, over the tray's right end)
const M_MENU_BTN := Rect2(10, 1043, 83, 36)  # (neither has the page a Menu: the Puppet HUD ver 2 picture at the base's left)
const M_CUP_C0 := Vector2(1029.797, 904.4)  # the first of the ten Chant rings (the PDF's balls: 49.77 wide, 50.92 apart)
const M_CUP_STEP := 50.92
const M_RING_PX := 49.77
const M_ART_C0 := 189.7  # x of the first artifact pedestal's middle (47.2 apart), y of the two shelves where the artifacts stand (their feet)
const M_ART_STEP := 47.2
const M_ART_FEET := [940.0, 1012.0]
const M_BOTTLE_C0 := Vector2(535.8, 967.3)  # the first bottle: where the page puts the Essence ball that shows a bottle's place; the stand's three sockets are 39.2 apart
const M_BOTTLE_STEP := 39.2
const M_REST0 := 1013.0  # the first resting Essence's middle in the pipe's straight tube
const M_TRAY_Y := 1002.5  # the straight tube's middle line
const M_PIPE_FRONT_ALPHA := 0.4  # the pipe's picture is opaque: it is drawn under the Essence, and again over them at this opacity (the glass in front); 1.0 is for a picture with its own transparency
const M_MOUTH_X := 1540.0  # the Essence rest in the straight tube from here (left of the column and its brass collar)


static func apply_minh() -> void:
	minh = true
	K = 1.0
	VTUBE_X = M_LOOP_C.x - M_LOOP_R
	VTUBE_TOP = M_LOOP_C.y
	DROP_Y = 1096.0
	STACK_BEND = Vector2(VTUBE_X, M_LOOP_C.y)
	STACK_UP = Vector2(VTUBE_X, M_LOOP_C.y + 70.0)
	STACK_STEP = 54.0
	BALL_PT = 50.0
	RING_PX = M_RING_PX
	var L = NewUiLayout
	L.BAG_AT = Vector2(M_REST0 - (PuppetLayout.REST_X + 26.0), M_TRAY_Y - PuppetLayout.AXIS_Y)
	L.RING_PX = RING_PX
	L.RING_STEP = M_CUP_STEP
	L.CHANT_AT = Vector2(M_CUP_C0.x - M_REST0, M_CUP_C0.y - PuppetLayout.RING_CY - L.BAG_AT.y)
	var chant_at: Vector2 = L.BAG_AT + L.CHANT_AT
	L.BTN_CHANT = Rect2(M_CHANT_BTN.position - chant_at, M_CHANT_BTN.size)
	L.BTN_PASS = Rect2(M_PASS_BTN.position - chant_at, M_PASS_BTN.size)
	L.BTN_CLEAR = Rect2(M_CLEAR_BTN.position - chant_at, M_CLEAR_BTN.size)
	L.MENU_BTN = M_MENU_BTN
	# artifacts: a 44 px artifact stands on each pedestal (five a row, the rows are the two shelves)
	L.ART_CELL = Vector2(M_ART_STEP, M_ART_FEET[1] - M_ART_FEET[0])
	L.ART_COLS = 5
	L.ART_PX = 44.0
	L.ART_AT = Vector2(M_ART_C0 - L.ART_PX / 2.0 - (L.ART_CELL.x - L.ART_PX) / 2.0, M_ART_FEET[0] - L.ART_PX - (L.ART_CELL.y - L.ART_PX) / 2.0)
	L.BOTTLE_CELL = Vector2(M_BOTTLE_STEP, 56.0)
	L.BOTTLE_PX = 39.0
	L.BOTTLE_AT = Vector2(M_BOTTLE_C0.x - L.BOTTLE_PX / 2.0 - (L.BOTTLE_CELL.x - L.BOTTLE_PX) / 2.0, M_BOTTLE_C0.y - L.BOTTLE_PX / 2.0 - (L.BOTTLE_CELL.y - L.BOTTLE_PX) / 2.0)
	L.HP_BAR = M_FLASK
	L.ACT_TEXT = Rect2(M_ART_CAB.position.x, 782.0, M_ART_CAB.size.x, 29.0)
	L.DEBUFF_AT = Vector2(M_CUP_C0.x - 21.0, 833.0)  # (a row of up to six over the Chant tray, 42 px each)
	L.DEBUFF_STEP = M_CUP_STEP
	L.DEBUFF_PX = 42.0
	L.DEBUFF_COLS = 6
	var mouth: Vector2 = Vector2(M_MOUTH_X, M_TRAY_Y) - L.BAG_AT
	L.MOUTH_X = mouth.x
	L.REST_END = mouth.x - 30.0
	L.TUBE_ROW_Y = PuppetLayout.AXIS_Y
	L.DROP_AT = Vector2(VTUBE_X, DROP_Y) - L.BAG_AT
	L.SPELL_BOTTOM = 771.0
	L.SPELL_CENTER_X = 960.0


## The way of an Essence in the pipe (page px): from below the screen up the column to the first waiting place, then (after STACK_BEND) round the loop clockwise: up and over the top,
## down the right side and left along the bottom leg (the caller adds the mouth). MinhHUD only; Puppet HUD ver 2's is [drop, STACK_UP, STACK_BEND].
static func track_pts() -> Array:
	if not minh:
		return [Vector2(VTUBE_X, DROP_Y), STACK_UP, STACK_BEND]
	var pts: Array = [Vector2(VTUBE_X, DROP_Y), STACK_UP, STACK_BEND]
	for k in range(1, 19):  # from 180 degrees (the column, level with the centre) round the top and the right to 450 (the bottom): 15 degrees a step
		var a := deg_to_rad(180.0 + 15.0 * k)
		pts.append(M_LOOP_C + Vector2(cos(a), sin(a)) * M_LOOP_R)
	return pts


## What MinhHUD draws on the Back (the layers under the cards, the bottles, the artifacts and the Chant rings); the ones over them are MinhParts.Layer, the round button MinhParts.Disc.
static func _draw_minh(c) -> void:
	_pic(c, "minhhud_base", M_BASE)
	_pic(c, "Artifact Cabinet/Cabinet", M_ART_CAB)
	_pic(c, "Bottle cabinet/Bottle Cabinet", M_BOT_CAB)
	_pic(c, "Bottle cabinet/Wooden back", M_BOT_BACK)
	_pic(c, "Bottle cabinet/Behind stand", M_BOT_BEHIND)
	_pic(c, "Chant tray/Behind tray", M_TRAY_BEHIND)
	_pic(c, "minhhud_flask", M_FLASK)
	_pic(c, "hud2_btn_menu_pressed" if c.menu_state == 2 else "hud2_btn_menu", M_MENU_BTN, tint_of("hover" if c.menu_state == 1 else "normal"))
	var sock := _tex("nu_debuff_ring")
	for k in c.debuffs:
		var at := NewUiLayout.debuff_slot(k, 1)
		if sock != null:
			c.draw_texture_rect(sock, Rect2(at, Vector2.ONE * NewUiLayout.DEBUFF_PX), false)
		else:
			c.draw_arc(at + Vector2.ONE * NewUiLayout.DEBUFF_PX / 2.0, NewUiLayout.DEBUFF_PX / 2.0, 0.0, TAU, 32, Color(0.8, 0.6, 0.3), 1.5)
