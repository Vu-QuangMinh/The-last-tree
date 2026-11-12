class_name ShopScreen
extends Control
## The merchant: spend Amber on spells, artifacts, bottles, a wax seal (it seals one Essence of a spell of yours) or a hot meal.

signal leave
signal upgrade_requested
signal quest_changed  # (his favours moved on: save them)

## Puppet Stage: laid over the stage (no backdrop). The curtains are already open: the cart rolls in, the merchant walks after it, the spell cards lie down on the
## floor and spring up, the artifacts and bottles are let down on ropes. All the numbers below are the places in Merchant.pdf (1920 x 1080) or knobs to tune.
var on_stage := false
var edit_allowed := false  # Test mode: F6 turns the shelf layout editor on (see _edit_toggle)
var intro := true  # (false: back from the wax seal screen, everything is already in place)

const ART_DIR := "res://assets/Puppet/UI/Characters/Merchant/"
## The PDF's ground line (the bottom of the cart's wheels) and its anchor: the whole group is scaled about this point and its ground is put on the stage's floor.
const PDF_GROUND := Vector2(1412.0, 706.0)
const SHOP_SCALE := 0.7  # (the cart and the merchant, against the PDF)
const FLOOR_MARGIN := 43.0  # (px above the floor's front edge: nothing hangs over the front wall)
const CART_RECT := Rect2(1064.3, 114.1, 696.0, 655.0)
## 2026-11-11: the cart redrawn from the user's sketch (cart_empty.png: no candle, no soup), placed to match the old cart's body (same width, same ground), and the two goods that stand on
## its shelves: the candle (the Wax seal, upper shelf) and the bowl of soup (A hot meal, lower shelf). Rects in PDF px: each good by the middle of its bottom edge and its height.
const CART_EMPTY_RECT := Rect2(1118.56, 205.41, 579.03, 441.57)
const CART_GOODS := {"upgrade": {"file": "candle.png", "foot": Vector2(1442.8, 430.6), "h": 84.0}, "heal": {"file": "soup.png", "foot": Vector2(1593.4, 514.5), "h": 50.0}}
const GOOD_GLOW := Color(1.55, 1.4, 1.25)  # (a good under the mouse lights up)
# ---- The true cart (Cart_true_empty.png): all the goods are laid on it; click it and the camera zooms in (see _zoom_in). Coordinates "picture px" = pixels of that picture.
const TRUE_CART := "Cart_true_empty.png"
const TC_BBOX := Rect2(167.0, 278.0, 1783.0, 1362.0)  # (the drawn part of the picture, picture px)
const TC_LEFT := 1070.0  # PDF px: where the drawn part's left side stands ...
const TC_W := 700.0  # ... how wide it is ...
const TC_GROUND := 1710.0  # ... and the picture row that stands on the ground: the bottom of the front wheel
const TC_WHEEL_BACK := Vector4(690.0, 1500.0, 360.0, 0.0)  # (centre x, centre y, diameter; picture px) the far wheel, behind the cart, under its left foot
const TC_WHEEL_FRONT := Vector4(1618.0, 1500.0, 420.0, 0.0)  # the near wheel, in front, under its right foot
const TC_CANOPY := Vector2(356.0, 283.0)  # the canopy's top-left corner (picture px): the camera's anchor
const TC_ZOOM_PX := 0.908  # zoomed in: screen px per picture px
const TC_ZOOM_AT := Vector2(330.0, 43.0)  # ... and the screen point the canopy's corner lands on (the cart is a little right of centre: the merchant's face fits on the left)
const TC_UP_FOOT := 964.0  # the upper plank: where the bottles, the candle and the soup stand
const TC_LOW_FOOT := 1232.0  # the cart's floor: where the artifacts stand
const TC_UP_X := [867.0, 1017.0, 1235.0, 1441.0, 1647.0]  # the 3 bottles, the wax (candle), the meal (soup)
const TC_LOW_X := [1173.0, 1403.0, 1616.0]  # the 3 artifacts
const TC_CARDS := [Vector2(622.0, 738.0), Vector2(622.0, 946.0), Vector2(622.0, 1150.0), Vector2(910.0, 1150.0)]  # the 4 spell cards (their middles)
const TC_MEND := Vector2(760.0, 480.0)  # (the Seed-mending offer, seldom there: on the canopy)
const TC_INFO := Vector2(1380.0, 500.0)  # the info board's middle: on the canopy, over no item and no card
const TC_GLOW := Color(1.45, 1.34, 1.2)  # the cart and everything on it light up together under the mouse
const TC_CAM_TIME := 0.9
const TC_COIN_K := 0.7  # the coin on a price box, against the old size
const TC_PRICE_INK := Color(0.98, 0.80, 0.32)  # the price's colour: the coin's gold
const TC_HOVER_BIG := 1.03  # an item or card under the mouse grows only this much
const TC_UP_L := 800.0  # the upper plank's usable width (picture px): the five items are spread evenly between these
const TC_UP_R := 1750.0
const TC_UP_SHIFT := 20.0  # the left bottle goes this much further left, the soup this much further right; the rest is spread evenly between them
const TC_ART_PX := 146.0  # an artifact's picture (picture px)
const TC_BOTTLE_PX := 205.0
const TC_WAX_H := 270.0
const TC_SOUP_H := 175.0
const CART_LAYOUT_PATH := "res://data/shop_cart_layout.json"  # the user's own sizes (F6 on the zoomed cart): never delete
const TC_PRICE_K := 1.9  # the price boxes are made this much bigger than the old ones: the goods are drawn in picture px, then shrunk by the camera
const WHEEL_BACK_RECT := Rect2(1217.1, 563.3, 142.7, 142.7)  # Layer 1 (the far wheel)
const WHEEL_FRONT_RECT := Rect2(1504.7, 527.9, 178.1, 178.1)  # Layer 2
const MERCHANT_RECT := Rect2(931.9, 330.1, 256.0, 387.0)  # (the pictures are cut to the figure: 0.2298 PDF px per picture px, boots as low as before)
## The drunk merchant (merchant_drunk.png) on his chair, where Merchant.pdf puts him: the picture's place, the PDF y of his boots, his mouth.
const DRUNK_RECT := Rect2(526.0, 344.3, 391.4, 384.2)
const DRUNK_FEET_Y := 713.0
const MOUTH_PDF := Vector2(725.5, 418.7)
## The bubbles that float up from his mouth while he is drunk (bubble (1..4).png). BUBBLE_SIZE: the smallest and the biggest bubble drawn in the PDF, in PDF px
## (the game's are those times SHOP_SCALE, each a little off).
const BUBBLE_SHIFT_X := -15.0  # (px: they leave beside his face, a little to its left)
const BUBBLE_FILES := ["bubble (1).png", "bubble (2).png", "bubble (3).png", "bubble (4).png"]
const BUBBLE_SIZE := Vector2(6.8, 13.3)
const BUBBLE_SIZE_JITTER := 0.1  # (each is made up to this much bigger or smaller)
const BUBBLE_EVERY := Vector2(0.35, 0.9)  # seconds between two bubbles (random in between)
const BUBBLE_LIFE := Vector2(1.6, 2.8)
const BUBBLE_RISE := Vector2(45.0, 95.0)  # px/s upward
const BUBBLE_DRIFT := Vector2(-28.0, 6.0)  # px/s sideways (they lean to the left, the way the PDF has them)
const MERCHANT_FEET := 0.934  # (of the picture's height: where his boots are, the pivot of his walk)
const CART_FROM := 900.0  # how far right of its place the cart starts (px): off the screen
const MERCHANT_FROM := 1400.0  # (his whole picture starts off the screen)
const CART_TIME := 4.0
const MERCHANT_TIME := 5.0
const MERCHANT_DELAY := 2.0  # he sets off this long after the cart does
const SPELL_X := [190.0, 470.0, 750.0]  # where the spell cards stand (centre) and the bottom of the Buy buttons (on the floor)
const SPELL_FOOT := [640.0, 640.0, 640.0]
const SPELL_SCALE := 1.3  # (the standing spell cards, against the old shop)
## A spell card is a hinged target, like the ducks of a shooting gallery: it lies face up on the floor with its top edge away from you, and swings up about
## its bottom edge. `LIE_DEPTH`: how much of the card's height the floor shows when it lies flat (the floor is seen at a slant); `LIE_NARROW`: how much narrower
## its far edge is than its near one (perspective).
const LIE_DEPTH := 0.38
const LIE_NARROW := 0.25
const LIE_ANGLE := 0.05  # (radians above the floor: flat, not quite)
const MESH_ROWS := 14
const POP_START := 1.0  # the cards lie still this long after the cart and the merchant are in place
const POP_TIME := 1.0
const POP_GAP := 0.6
const HANG_BIG := 1.3  # a hanging good under the mouse (or just clicked) grows to this much of its size
const HOLD_SECS := 3.0  # a click keeps a good big (a standing card's magnified copy up) for this long, even if the mouse leaves
const HANG_SCALE := 0.975  # (the artifacts and bottles hang a little smaller than the old grid's)
const ART_PX := 96  # an artifact: only its picture, on a string (no words: hover it for what it does)
const ART_X := [240.0, 610.0, 960.0]  # the artifacts' centres, along the top
const ART_TOP := [175.0, 200.0, 175.0]
const RIGHT_X := [1400.0, 1700.0]  # the bottles, the wax and the meal hang on the right, over the cart, never over the merchant
const RIGHT_ROW_Y := [130.0, 395.0]
const CARD_GAP := 300.0  # between the standing spell cards' centres, along the bottom of the screen
const CARD_FOOT := 1070.0  # where they stand (where the fight's panels are in a fight)
const CARD_SPAN := [40.0, 1400.0]  # the row of cards, left of the Menu and Leave buttons
const CONJURE_TIME := 0.6
const HANG_X0 := 165.0  # centre of the first item
const TRAY_W := 520.0  # the bottles stand together in one tray, hung in the middle, under the artifacts
const TRAY_CX := 600.0
const TRAY_TOP := 525.0
const TRAY_FLOOR := 0.62  # (of the tray picture's height: where the bottles' bottoms are, behind its front lip)
const TRAY_SLOTS := [0.2, 0.5, 0.8]
const BOTTLE_PX := 88.0
## 2026-11-11: no more ropes and trays. The 3 artifacts stand on a rug laid on the floor, the 3 bottles on a wooden table beside it. Positions in screen px (1920 wide); the rug and the table stand on `_ground`.
const SHELF_W := 620.0
const SHELF_CX := 580.0
const SHELF_UP := 0.465  # (of the shelf picture's height: where the bottles' bottoms stand on the upper plank)
const SHELF_LOW := 0.865  # (the artifacts' bottoms on the lower plank)
const SHELF_PRICE_UP := 0.482  # (the price buttons sit on each plank's front edge)
const SHELF_PRICE_LOW := 0.905
const ITEM_BIG := 1.28  # an item (not its price button) under the mouse grows to this much of its size
const CAMP_CX := 1715.0  # the campfire with its cauldron of wax, on the floor right of the cart: the meal over it, the wax under it
const CAMP_W := 265.0
const SWING_K := 9.0  # an artifact hangs on one string and swings on it like a puppet does (see Creature)
const SWING_DAMP := 1.1
const SWING_MAX := 0.22
const SWING_NUDGE := 0.35  # the push it gets when the mouse comes onto it, or when it lands
const HANG_DX := 165.0  # between centres (squeezed when there are many items)
const HANG_MAX_W := 940.0  # the row must end before the merchant
const HANG_ROW_Y := [188.0, 214.0]  # tops, in turn: the ropes differ in length, so the row is not a straight line
const HANG_FALL := 0.55
const HANG_GAP := 0.2
const HANG_START := 0.3  # after the last card has stood up
const ROPE_TOP := -40.0  # (behind the valance)
const STEP_K := 0.03  # merchant: radians of stride per px walked (one step per pi of it)
const SHADOW_SHIFT := Vector2(14.0, 11.0)  # a hanging frame's shadow on the back wall (the key light is up on the left)

var run: RunState
var stock: Array = []
var quest := {"done": 0, "open": false}  # his favours (see MerchantQuests), shared with the save
var _amber: Label
var _amber2: Label  # (the coin frame of the zoomed view)
var _true_cart := false  # Cart_true_empty.png exists: the goods lie on the cart and the camera zooms in on it
var _cart_pic: TextureRect
var _cart_items: Control  # the goods' parent: in picture px, so it scales with the cart
var _view := "overview"  # "overview" (the shop as it is) or "cart" (zoomed in)
var _zoomed := false  # fully zoomed in: the goods can be bought
var _cam_busy := false
var _cam_e := 0.0  # 0 = overview, 1 = zoomed
var _cam_tw: Tween
var _stage_rest := {}
var _mult := {"card": 1.0, "bottle": 1.0, "wax": 1.0, "soup": 1.0, "artifact": 1.0}  # the sizes set with F6 on the zoomed cart (1 = the default)
var _c_editing := false
var _c_sel := ""
var _c_undo: Array = []
var _c_label: Label
var _c_pending := false
var test_mouse := Vector2.INF  # (tests only: where the mouse is, when the real one cannot be moved)
var _leave_btn: Button
var _pill: Control
var _pill2: Control
var _back_btn: Button
var _grid: HFlowContainer
var _stage: PuppetStage
var _world: Control  # the scene itself: under the stage's ceiling, so the tops of the ropes go behind the valance
var _hang_layer: Control
var _spell_layer: Control
var _cart: Control  # the cart and its wheels, moved together
var _wheel_back: TextureRect
var _wheel_front: TextureRect
var _merchant: TextureRect
var _ropes: _HangRopes
var _shadows: _Shadows
var _spell_sh: Array[Dictionary] = []  # {cx, foot, w, a}: the shadows of the standing cards on the floor
var _stride := -1000  # which step the merchant is on (a new one is heard)
var _drunk := false  # he sits on his chair (the favours are done)
var _cur_rect := MERCHANT_RECT  # the picture he is drawn with now (standing or drunk), in the PDF
var _cur_feet := Vector2.ZERO  # ... and where his boots are, in the PDF
var _m_off := 0.0  # how far from his place he is now (px)
var _tex_stand: Texture2D
var _tex_drunk: Texture2D
var _bubble_tex: Array[Texture2D] = []
var _bubbles: _Bubbles
var _hang: Array[Dictionary] = []  # {box, rest: Vector2 (top left), phase, swing, on}
var _arrived := false  # the cart and the merchant are in place
var _intro_done := false  # ... and the goods are laid out: now they can be bought
var _gen := 0
var _ground := 650.0  # where the cart and the merchant stand (the floor's front edge, less the margin)
var _t := 0.0
signal _arrive
var _title_row: HBoxContainer
var _mark_pic: TextureRect  # the painted "!" sign: it stands in for the "!" text
var _mark_pic_q: TextureRect  # the painted "?" sign
var _mark: Label  # "!" a favour to ask, "?" one you can hand over: click it (or him) to talk
var _picture: Button  # (once he's drunk) his family picture on the counter
var _dlg: Control  # the conversation box, while it's open
var _dlg_lines: Array = []
var _dlg_choices: Array = []  # [[button text, Callable], ...] under the last line
var _dlg_i := 0
var _dlg_text: Label
var _dlg_row: HBoxContainer
var _voice: AudioStreamPlayer  # the line he is saying (see _say)


func setup(p_run: RunState, p_stock: Array) -> void:
	run = p_run
	stock = p_stock


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = UiTheme.get_theme()
	if on_stage:
		_ready_stage()
		return
	var bd := Backdrop.new()
	bd.act = run.act
	add_child(bd)
	var shade := ColorRect.new()
	shade.color = Color(0, 0, 0, 0.55)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shade)
	var v := VBoxContainer.new()
	v.position = Vector2(60, 70)
	v.size = Vector2(1800, 980)
	v.add_theme_constant_override("separation", 16)
	add_child(v)
	var portrait: TextureRect = UiSkin.icon("merchant_portrait", 64) if UiSkin.is_puppet() else null
	_title_row = HBoxContainer.new()
	_title_row.add_theme_constant_override("separation", 14)
	v.add_child(_title_row)
	if portrait != null:  # Puppet: his round portrait instead of the cart
		portrait.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		_title_row.add_child(portrait)
		_title_row.add_child(UiTheme.heading("The Merchant", 40, Color.WHITE))
	else:
		_title_row.add_child(UiTheme.heading("🛒 The Merchant", 40, Color.WHITE))
	v.add_child(UiTheme.label("A badger with a very large backpack. \"Everything's for sale, friend. Even the backpack. Not the badger.\"", 20, UiTheme.MUTED))
	_amber = UiTheme.label("", 26, Color(1, 0.8, 0.35))
	v.add_child(_amber)
	_grid = HFlowContainer.new()
	_grid.add_theme_constant_override("h_separation", 26)
	_grid.add_theme_constant_override("v_separation", 22)
	_grid.custom_minimum_size = Vector2(1800, 0)
	v.add_child(_grid)
	# the Leave button is pinned to the bottom-right corner of the screen, NOT the last row of the list: a tall item (a long
	# artifact text) makes the rows taller and used to push a button in the list off the bottom of the screen
	var leave_btn := _leave_button()
	leave_btn.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	leave_btn.offset_left = -320.0
	leave_btn.offset_right = -60.0
	leave_btn.offset_top = -86.0
	leave_btn.offset_bottom = -30.0
	add_child(leave_btn)
	var hud := HudBar.new()
	hud.setup(run)
	add_child(hud)
	_place_merchant.call_deferred(leave_btn, v)
	_refresh()


func _leave_button() -> Button:
	var leave_btn := UiTheme.button("Leave the shop", func(): leave.emit(), 22)
	leave_btn.custom_minimum_size = Vector2(260, 56)
	if UiSkin.is_puppet():
		UiTheme.use_play_style(leave_btn, true)  # (the orange one, like Continue on the main menu)
		for k in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
			leave_btn.add_theme_color_override(k, Color.WHITE)
		leave_btn.add_theme_color_override("font_outline_color", Color(0.35, 0.16, 0.05))
		leave_btn.add_theme_constant_override("outline_size", 4)
	return leave_btn


## New theme: the merchant himself stands above the Leave button (behind the goods, so they never get covered).
## Click him (or the mark over his head) to talk. Once he's drunk he sits on his chair: his own picture ("merchant_drunk").
func _place_merchant(leave_btn: Control, _behind: Control) -> void:
	var t := UiSkin.tex("merchant_full") if UiSkin.tex("merchant_full") != null else UiSkin.tex("merchant_portrait")  # (Puppet: the whole merchant)
	if MerchantQuests.is_drunk(quest) and UiSkin.tex("merchant_drunk") != null:
		t = UiSkin.tex("merchant_drunk")
	if t == null or not is_instance_valid(leave_btn):
		_add_talk(null)  # (no picture of him: the mark and a Talk button go by his name)
		return
	await get_tree().process_frame
	var r := TextureRect.new()
	r.texture = t
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var h := 400.0 if UiSkin.tex("merchant_full") != null else 300.0
	r.size = Vector2(h * t.get_width() / t.get_height(), h)
	var lb := leave_btn.get_global_rect()
	r.position = Vector2(lb.get_center().x - r.size.x / 2.0, lb.position.y - r.size.y - 6.0) - global_position  # (centred over the Leave button)
	add_child(r)  # (over the goods: nothing hides him; he stands in the free corner)
	_add_talk(r)


## The quest mark over his head (or by his name), clicking him to talk, and (once he's drunk) the picture on his counter.
func _add_talk(him: TextureRect, head := Vector2.INF) -> void:  # (`head`: the stage shop says where the mark goes)
	_mark = UiTheme.heading("!", 72, Color(1.0, 0.85, 0.2))
	_mark.add_theme_color_override("font_outline_color", Color(0.25, 0.12, 0.02))
	_mark.add_theme_constant_override("outline_size", 10)
	_mark.mouse_filter = Control.MOUSE_FILTER_STOP
	_mark.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_mark.gui_input.connect(_on_talk_click)
	for mk in ["exclaim", "question"]:
		var xt := _art("mark_%s.png" % mk)
		if xt == null:
			continue  # (the painted sign, 2026-11-11: the Label keeps the click area and the text when there is no picture)
		var mp := TextureRect.new()
		mp.texture = xt
		mp.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		mp.stretch_mode = TextureRect.STRETCH_SCALE
		mp.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		mp.mouse_filter = Control.MOUSE_FILTER_IGNORE
		mp.size = Vector2(MARK_H * float(xt.get_width()) / float(xt.get_height()), MARK_H)
		mp.visible = false
		_mark.add_child(mp)
		if mk == "exclaim":
			_mark_pic = mp
			_mark.custom_minimum_size = mp.size
		else:
			_mark_pic_q = mp
	if him != null:
		him.mouse_filter = Control.MOUSE_FILTER_STOP
		him.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		him.tooltip_text = "Talk to the merchant"
		him.gui_input.connect(_on_talk_click)
		_mark.position = head if head != Vector2.INF else Vector2(him.position.x + him.size.x / 2.0 + 40.0, him.position.y - 50.0 - (MARK_H - 90.0 if _mark_pic != null else 0.0))  # (by his head, clear of the goods above; the painted sign is taller than the old text)
		add_child(_mark)
		var y0 := _mark.position.y
		var bob := _mark.create_tween().set_loops()
		bob.tween_property(_mark, "position:y", y0 - 12.0, 0.5).set_trans(Tween.TRANS_SINE)
		bob.tween_property(_mark, "position:y", y0, 0.5).set_trans(Tween.TRANS_SINE)
	else:
		_title_row.add_child(UiTheme.button("Talk", _talk, 20))
		_title_row.add_child(_mark)
	if MerchantQuests.is_drunk(quest) and not ("family_picture" in run.artifacts):
		_picture = UiTheme.button("🖼", _picture_click, 34)
		_picture.tooltip_text = "A small framed picture"
		if him != null:
			_picture.position = Vector2(head.x - (275.0 if _drunk else 150.0), _ground - 70.0) if head != Vector2.INF else Vector2(him.position.x - 80.0, him.position.y + him.size.y - 90.0)
			add_child(_picture)
		else:
			_title_row.add_child(_picture)
	_update_mark()


func _on_talk_click(ev: InputEvent) -> void:
	if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
		_talk()


const MARK_H := 110.0  # the painted "!" sign's height


func _set_mark(m: String) -> void:
	if _mark == null:
		return
	var pic: TextureRect = _mark_pic if m == "!" else (_mark_pic_q if m == "?" else null)
	_mark.text = "" if pic != null else m
	_mark.visible = m != ""
	if _mark_pic != null:
		_mark_pic.visible = pic == _mark_pic
	if _mark_pic_q != null:
		_mark_pic_q.visible = pic == _mark_pic_q


func _update_mark() -> void:
	if _mark != null:
		_set_mark(MerchantQuests.mark(quest, run.artifacts, run.merchant_talked == run.room_key()))
	if _picture != null and "family_picture" in run.artifacts:
		_picture.queue_free()
		_picture = null


## Talking to him: one favour a visit, asked for or handed over (see MerchantQuests).
func _talk() -> void:
	if _dlg != null or _view != "overview" or _cam_busy:
		return
	var n := int(quest.get("done", 0))
	match MerchantQuests.mode(quest, run.artifacts, run.merchant_talked == run.room_key()):
		"ask":
			_dialog(MerchantQuests.ASK[n], [[MerchantQuests.ACCEPT[n], func():
				MerchantQuests.accept(quest)
				run.merchant_talked = run.room_key()
				quest_changed.emit()
				Audio.play("discovery_unlock")
				_dialog([MerchantQuests.ACCEPTED[n]])], [MerchantQuests.DECLINE, _close_dialog]])
		"return":
			_dialog(MerchantQuests.SEE[n], [[MerchantQuests.HAND_OVER[n], func():
				MerchantQuests.complete(quest)
				run.merchant_reward(n, stock)
				run.merchant_talked = run.room_key()
				quest_changed.emit()
				Audio.play("artifact_get")
				_refresh()
				_dialog(MerchantQuests.THANKS[n])], [MerchantQuests.KEEP, _close_dialog]])
		"remind":
			_dialog([MerchantQuests.REMIND[n]])
		"drunk":
			_dialog([MerchantQuests.DRUNK[randi() % MerchantQuests.DRUNK.size()]])
		_:
			_dialog([MerchantQuests.LATER])


## His drunken nap: the picture by his elbow.
func _picture_click() -> void:
	if _dlg != null or _view != "overview" or _cam_busy:
		return
	_dialog([MerchantQuests.PICTURE], [[MerchantQuests.STEAL, func():
		_close_dialog()
		run.gain_artifact("family_picture")  # (the "You found an artifact!" card shows it, back and all)
		_update_mark()], [MerchantQuests.LEAVE_IT, _close_dialog]])


## The conversation box: his lines one at a time (Next), then the choices under the last one (or Goodbye).
func _dialog(lines: Array, choices: Array = []) -> void:
	_close_dialog()
	_dlg_lines = lines
	_dlg_choices = choices
	_dlg_i = 0
	if _spell_layer != null:
		_spell_layer.visible = false  # (the spell cards are put away while he talks: a magnified one would cover the words)
	_dlg = Control.new()
	_dlg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_dlg.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_dlg)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.45)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_dlg.add_child(dim)
	var cream := UiTheme.has_dialogue_board()  # (the same cream board as the events' and the bosses' conversations)
	var p := PanelContainer.new()
	var board: StyleBox = UiTheme.dialogue_board([34, 24, 34, 26]) if cream else UiTheme.panel_box(0.97, 16)
	p.add_theme_stylebox_override("panel", board)
	p.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	p.position = Vector2(470, 690)
	p.custom_minimum_size = Vector2(980, 0)
	_dlg.add_child(p)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 12)
	p.add_child(vb)
	vb.add_child(UiTheme.heading("The Merchant", 28, UiTheme.BOARD_NAME if cream else Color(1, 0.85, 0.45)))
	_dlg_text = UiTheme.label("", 24, UiTheme.BOARD_INK if cream else Color.WHITE)
	_dlg_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_dlg_text.custom_minimum_size = Vector2(900, 0)
	vb.add_child(_dlg_text)
	_dlg_row = HBoxContainer.new()
	_dlg_row.alignment = BoxContainer.ALIGNMENT_END
	_dlg_row.add_theme_constant_override("separation", 16)
	vb.add_child(_dlg_row)
	_dialog_step()


## His voice for a line: the file named after the line (mv_ + the first 8 characters of its md5, made by tools/make_merchant_dialogue_voice.py). The line before it is cut off.
func _say(text: String) -> void:
	Audio.stop_held(_voice, 0.1)
	_voice = Audio.play_held("mv_" + text.md5_text().substr(0, 8))


func _dialog_step() -> void:
	_dlg_text.text = String(_dlg_lines[_dlg_i])
	_say(String(_dlg_lines[_dlg_i]))
	for c in _dlg_row.get_children():
		c.queue_free()
	if _dlg_i < _dlg_lines.size() - 1:
		_dlg_row.add_child(_dlg_button("Next", _dialog_next))
		return
	if _dlg_choices.is_empty():
		_dlg_row.add_child(_dlg_button("Goodbye", _close_dialog))
		return
	for ch in _dlg_choices:
		_dlg_row.add_child(_dlg_button(String(ch[0]), ch[1]))


## A button of the conversation: the gold plaque that goes with the cream board.
func _dlg_button(text: String, cb: Callable) -> Button:
	return UiTheme.gold_button(text, cb, 20) if UiTheme.has_dialogue_board() else UiTheme.button(text, cb, 20)


func _dialog_next() -> void:
	_dlg_i += 1
	_dialog_step()


func _close_dialog() -> void:
	Audio.stop_held(_voice, 0.15)
	_voice = null
	if _dlg != null:
		_dlg.queue_free()
		_dlg = null
	if _spell_layer != null:
		_spell_layer.visible = true  # (the cards are back once the conversation is over)
	_update_mark()

var _panels: Array = []  # the stretchable frames (everything but the spell cards)
var _boxes: Array = []  # each item: its picture or card, then its Buy button


## Once the text has laid out, every item gets the height of the tallest frame (cards keep their size and the Buy
## buttons sit level at the bottom).
func _equalize() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	var tallest := SpellCard.H
	for p in _panels:
		if is_instance_valid(p):
			tallest = maxf(tallest, p.get_combined_minimum_size().y)
	for b in _boxes:
		if is_instance_valid(b):
			var btn: Control = b.get_child(b.get_child_count() - 1)
			b.custom_minimum_size.y = tallest + b.get_theme_constant("separation") + btn.get_combined_minimum_size().y


func _refresh() -> void:
	_amber.text = str(run.amber) if on_stage else "You have %d Leaves" % run.amber
	if _amber2 != null:
		_amber2.text = str(run.amber)
	var K := TC_PRICE_K if _true_cart else 1.0  # (the size of the price boxes)
	var old: Array = []
	if on_stage:
		old = _boxes.duplicate()  # (they stay until the new ones are in place: no empty frames after a purchase)
	else:
		for c in _grid.get_children():
			c.queue_free()
	_boxes.clear()
	_panels.clear()
	for i in stock.size():
		var it: Dictionary = stock[i]
		# (the stage shop: an artifact or a bottle and its price are one hover zone, an invisible box round both)
		var tipped: bool = on_stage and (it.kind in ["artifact", "bottle"] or (_true_cart and it.kind in ["upgrade", "heal"]))
		var box: VBoxContainer = _TipBox.new() if tipped else VBoxContainer.new()
		if tipped:
			box.mouse_filter = Control.MOUSE_FILTER_PASS
			if HoverBoard.available():
				box.theme = HoverBoard.bare_theme()  # (the board is its own box)
		box.add_theme_constant_override("separation", 16 if _true_cart and it.kind == "artifact" else 6)  # (on the cart an artifact's price box is 10 px lower)
		match it.kind:
			"spell":
				var gap := Control.new()  # a card can't stretch: this soaks up the extra height ABOVE it, so its bottom is level with the frames' and the Buy button stays level
				gap.size_flags_vertical = Control.SIZE_EXPAND_FILL
				box.add_child(gap)
				box.add_child(SpellCard.make(it.spell))
			"artifact":
				var a: Dictionary = it.artifact
				var p := PanelContainer.new()
				p.add_theme_stylebox_override("panel", _frame())
				p.custom_minimum_size = Vector2(SpellCard.W, SpellCard.H)
				var col := Color(0.6, 0.8, 1) if a.tier == "rare" else Color(1, 0.88, 0.6)
				var art := UiSkin.artifact_icon(a.id, _art_px() if on_stage else 64)  # New theme: the painted artifact above its name
				if art != null and on_stage:
					# (the stage shop: no frame, only the picture, dangling on its string; what it is and does shows on hover)
					p.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
					p.custom_minimum_size = Vector2(_art_px(), _art_px())
					art.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
					art.size_flags_vertical = Control.SIZE_SHRINK_CENTER
					p.add_child(art)
					box.set_meta("sil", art)  # (its shadow on the wall is the picture's own)
					box.set_meta("pic", art)
					box.set_meta("pic_h", float(_art_px()))
					art.pivot_offset = Vector2(_art_px() / 2.0, _art_px())
					art.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
					box.set_meta("tip", ArtifactCard.tip(a))  # (shown on the info board that slides out of the shelf: see _info_update)
					box.set_meta("tip_tex", UiSkin.tex(UiSkin.ARTIFACT_ART.get(a.id, a.id)))
				elif art != null:
					var av := VBoxContainer.new()
					av.alignment = BoxContainer.ALIGNMENT_CENTER
					av.add_theme_constant_override("separation", 2)
					art.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
					av.add_child(art)
					av.add_child(_centered(UiTheme.heading(a.name, 22, col)))
					av.add_child(_centered(UiTheme.label("%s · %s" % [Artifacts.TIER_NAMES[a.tier].to_upper(), a.aspect], 14, UiTheme.MUTED)))
					var ad := _centered(UiTheme.label(a.desc, 16, Color(0.9, 0.92, 0.86)))
					ad.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
					ad.custom_minimum_size = Vector2(SpellCard.W - 28, 0)
					av.add_child(ad)
					p.add_child(av)
				else:
					var l := UiTheme.label("◆ %s\n%s · %s\n\n%s" % [a.name, Artifacts.TIER_NAMES[a.tier].to_upper(), a.aspect, a.desc], 18, col)
					l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
					l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
					p.add_child(l)
				p.size_flags_vertical = Control.SIZE_EXPAND_FILL  # the frames stretch to the tallest one
				_panels.append(p)
				box.add_child(p)
			"bottle" when on_stage:
				var b := Bottles.get_def(it.bottle)
				var bt := UiSkin.tex(b.id)
				var ic: Control
				var slot := Control.new()  # (a fixed square: the bottle stands on its bottom edge, whatever its shape)
				slot.custom_minimum_size = Vector2(_bottle_px(), _bottle_px())
				slot.mouse_filter = Control.MOUSE_FILTER_PASS
				if bt != null:
					var k := minf(_bottle_px() / float(bt.get_width()), _bottle_px() / float(bt.get_height()))
					var trect := TextureRect.new()
					trect.texture = bt
					trect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
					trect.stretch_mode = TextureRect.STRETCH_SCALE
					trect.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
					trect.size = Vector2(float(bt.get_width()), float(bt.get_height())) * k
					trect.position = Vector2((_bottle_px() - trect.size.x) / 2.0, _bottle_px() - trect.size.y)
					trect.pivot_offset = Vector2(trect.size.x / 2.0, trect.size.y)
					trect.mouse_filter = Control.MOUSE_FILTER_IGNORE
					slot.add_child(trect)
					ic = trect
				else:
					ic = UiTheme.label(b.icon, 64, Color.WHITE)
					ic.size = Vector2(_bottle_px(), _bottle_px())
					ic.pivot_offset = Vector2(_bottle_px() / 2.0, _bottle_px())
					slot.add_child(ic)
				box.set_meta("tip", Keywords.tooltip(b.name, b.desc))
				box.set_meta("tip_tex", bt)
				box.set_meta("pic", ic)
				box.set_meta("pic_w", ic.size.x if ic is TextureRect else _bottle_px())
				box.set_meta("pic_h", _bottle_px())
				box.add_child(slot)
			"bottle":
				var b := Bottles.get_def(it.bottle)
				var p := PanelContainer.new()
				p.add_theme_stylebox_override("panel", _frame())
				p.custom_minimum_size = Vector2(SpellCard.W, SpellCard.H)
				var bv := VBoxContainer.new()
				bv.alignment = BoxContainer.ALIGNMENT_CENTER
				p.add_child(bv)
				var ic: Control = UiSkin.icon(b.id, 72)  # New theme: painted art named after the item id, once it exists
				if ic != null:
					ic.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
				else:
					ic = UiTheme.label(b.icon, 52, Color.WHITE)
					ic.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
				bv.add_child(ic)
				var nm := UiTheme.label(b.name, 22, Color(0.6, 0.95, 1.0))
				nm.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
				bv.add_child(nm)
				var ds := RichTextLabel.new()
				ds.bbcode_enabled = true
				ds.fit_content = true
				ds.scroll_active = false
				ds.custom_minimum_size = Vector2(SpellCard.W - 24, 0)
				ds.add_theme_font_size_override("normal_font_size", 17)
				ds.add_theme_font_size_override("bold_font_size", 17)
				ds.text = "[center]" + Keywords.colorize(b.desc) + "\n[color=#9aa89a]Bottle · for one fight[/color][/center]"
				bv.add_child(ds)
				p.size_flags_vertical = Control.SIZE_EXPAND_FILL  # the frames stretch to the tallest one
				_panels.append(p)
				box.add_child(p)
			"mend_seed":
				var p := PanelContainer.new()
				p.add_theme_stylebox_override("panel", _frame())
				p.custom_minimum_size = Vector2(SpellCard.W, SpellCard.H)
				var l := UiTheme.label("🌼 Mend the Seed of Life\n\nThe badger seals its cracks: your second chance is back.", 19, Color(0.75, 1.0, 0.6))
				l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
				l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
				p.add_child(l)
				box.add_child(p)
			"upgrade", "heal" when _true_cart:
				# (the candle and the soup stand on the cart like the bottles do: the picture, its price under it)
				var gt := _art("candle.png" if it.kind == "upgrade" else "soup.png")
				var gh := TC_WAX_H * float(_mult["wax"]) if it.kind == "upgrade" else TC_SOUP_H * float(_mult["soup"])
				var gw := gh * float(gt.get_width()) / float(gt.get_height())
				var slot := Control.new()
				slot.custom_minimum_size = Vector2(gw, gh)
				slot.mouse_filter = Control.MOUSE_FILTER_PASS
				var trect := TextureRect.new()
				trect.texture = gt
				trect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
				trect.stretch_mode = TextureRect.STRETCH_SCALE
				trect.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
				trect.size = Vector2(gw, gh)
				trect.pivot_offset = Vector2(gw / 2.0, gh)
				trect.mouse_filter = Control.MOUSE_FILTER_IGNORE
				slot.add_child(trect)
				var nm := "A hot meal" if it.kind == "heal" else "Wax seal"
				box.set_meta("tip", Keywords.tooltip(nm, "Heal %d HP." % int(run.player.max_hp * RunState.REST_HEAL) if it.kind == "heal" else "Seal one Essence of a spell's pattern: it won't be needed any more."))
				box.set_meta("tip_tex", gt)
				box.set_meta("pic", trect)
				box.set_meta("pic_w", gw)
				box.set_meta("pic_h", gh)
				box.add_child(slot)
			"upgrade", "heal" when on_stage:
				var title :=UiTheme.heading("A hot meal" if it.kind == "heal" else "Wax seal", 26, Color(1.0, 0.93, 0.78))
				title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
				title.add_theme_constant_override("outline_size", 8)
				title.add_theme_color_override("font_outline_color", Color(0.12, 0.06, 0.02))
				title.mouse_filter = Control.MOUSE_FILTER_PASS
				box.set_meta("tip", Keywords.tooltip("A hot meal" if it.kind == "heal" else "Wax seal", "Heal %d HP." % int(run.player.max_hp * RunState.REST_HEAL) if it.kind == "heal" else "Seal one Essence of a spell's pattern: it won't be needed any more."))
				box.add_child(title)
			"upgrade", "heal":
				var p := PanelContainer.new()
				p.add_theme_stylebox_override("panel", _frame())
				p.custom_minimum_size = Vector2(SpellCard.W, SpellCard.H)
				var art := UiSkin.icon("shop_wax_seal" if it.kind == "upgrade" else "hot_meal", 72)  # New theme: painted art, once it exists
				if art != null:
					var uv := VBoxContainer.new()
					uv.alignment = BoxContainer.ALIGNMENT_CENTER
					art.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
					uv.add_child(art)
					var title := "Wax seal" if it.kind == "upgrade" else "A hot meal"
					var body := "Seal one Essence of a spell's pattern: it won't be needed any more." if it.kind == "upgrade" else "Heal %d HP." % int(run.player.max_hp * RunState.REST_HEAL)
					uv.add_child(_centered(UiTheme.heading(title, 22, Color(0.85, 1, 0.8))))
					var bd := _centered(UiTheme.label(body, 17, Color(0.85, 1, 0.8)))
					bd.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
					bd.custom_minimum_size = Vector2(SpellCard.W - 28, 0)
					uv.add_child(bd)
					p.add_child(uv)
				else:
					var txt := "🟣 Wax seal\n\nSeal one Essence of a spell's pattern: it won't be needed any more." if it.kind == "upgrade" else "🍲 A hot meal\n\nHeal %d HP." % int(run.player.max_hp * RunState.REST_HEAL)
					var l := UiTheme.label(txt, 19, Color(0.85, 1, 0.8))
					l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
					l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
					p.add_child(l)
				p.size_flags_vertical = Control.SIZE_EXPAND_FILL  # the frames stretch to the tallest one
				_panels.append(p)
				box.add_child(p)
		var sold: bool = it.get("sold", false)
		var full: bool = it.kind == "bottle" and run.player.bottles.size() >= run.bottle_slots()
		var none: bool = it.kind == "upgrade" and run.upgradable().is_empty()
		var price := run.shop_price(it)
		var label := "Sold" if sold else ("Bottle slots full" if full else ("Nothing to seal" if none else ("Free" if price == 0 else str(price))))
		var btn := UiTheme.button(label, func(): _buy(i), int(18.0 * K), "buy")
		for k in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color"]:
			btn.add_theme_color_override(k, Color(0.06, 0.05, 0.04))  # (the price in black ink)
		btn.add_theme_color_override("font_disabled_color", Color(0.06, 0.05, 0.04, 0.55))
		btn.add_theme_constant_override("outline_size", 0)
		btn.disabled = sold or full or none or run.amber < price
		var coin := UiSkin.tex("icon_amber")
		if on_stage and coin != null and label == str(price):
			# (the coin right before the price, the two centred together on the button)
			btn.custom_minimum_size = btn.get_combined_minimum_size()  # (its size with the price written in it)
			btn.text = ""
			var row := HBoxContainer.new()
			row.alignment = BoxContainer.ALIGNMENT_CENTER
			row.add_theme_constant_override("separation", int(6.0 * K))
			row.mouse_filter = Control.MOUSE_FILTER_IGNORE
			row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			var ci := TextureRect.new()
			ci.texture = coin
			ci.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			ci.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			var icon_px := 24.0 * (TC_COIN_K if _true_cart else 1.0)  # (on the cart the coin is 70% of what it was)
			ci.custom_minimum_size = Vector2(icon_px, icon_px) * K
			ci.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			ci.mouse_filter = Control.MOUSE_FILTER_IGNORE
			ci.modulate.a = 0.55 if btn.disabled else 1.0
			row.add_child(ci)
			var num := Label.new()
			num.text = label
			num.add_theme_font_size_override("font_size", int(18.0 * K))
			UiTheme.apply_header(num, "body", int(18.0 * K))
			var ink := TC_PRICE_INK if _true_cart else Color(0.06, 0.05, 0.04)  # (on the cart the price is written in the coin's gold)
			num.add_theme_color_override("font_color", Color(ink.r, ink.g, ink.b, 0.55 if btn.disabled else 1.0))
			num.add_theme_constant_override("outline_size", 0)
			num.mouse_filter = Control.MOUSE_FILTER_IGNORE
			if _true_cart:  # (3 px higher: the number sits in a holder and is lifted inside it)
				var nh := Control.new()
				nh.custom_minimum_size = num.get_combined_minimum_size()
				nh.mouse_filter = Control.MOUSE_FILTER_IGNORE
				num.position = Vector2(0.0, -3.0)
				nh.add_child(num)
				row.add_child(nh)
			else:
				row.add_child(num)
			# (the button is just big enough for the coin and the price, centred under its item)
			btn.custom_minimum_size = Vector2(num.get_combined_minimum_size().x + (icon_px + 6.0 + 22.0) * K, 30.0 * K)
			btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
			btn.add_child(row)
		if _true_cart and it.kind == "spell":
			# (the cards are stacked: the price box sits on the card's bottom edge, not under it, so it covers little of the next card)
			var holder := Control.new()
			holder.custom_minimum_size = Vector2(0.0, 1.0)
			holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
			var bs := btn.get_combined_minimum_size()
			btn.anchor_left = 0.5
			btn.anchor_right = 0.5
			btn.offset_left = -bs.x / 2.0
			btn.offset_right = bs.x / 2.0
			btn.offset_top = -30.0
			btn.offset_bottom = -30.0 + bs.y
			holder.add_child(btn)
			box.add_child(holder)
		else:
			box.add_child(btn)
		_boxes.append(box)
		if on_stage:
			box.set_meta("kind", it.kind)
			box.set_meta("idx", i)
			box.set_meta("sold", sold)
			box.set_meta("btn", btn)
			if it.kind == "spell":
				box.set_meta("spell", it.spell)
				box.set_meta("buy", label)
				box.set_meta("off", btn.disabled)
			box.modulate.a = 0.0  # (placed once it has its size)
			box.position = Vector2(-4000.0, 0.0)
			(_cart_items if _true_cart else (_spell_layer if it.kind == "spell" else _hang_layer)).add_child(box)
		else:
			_grid.add_child(box)
	if on_stage:
		if _tray != null and not _tray in _boxes and not _tray in old:
			_boxes.append(_tray)
		(_cart_layout if _true_cart else _stage_layout).call_deferred(old)
	else:
		_equalize.call_deferred()


## An item with its price under it, as one hover zone: anywhere over the box (the item, the price, the gap between)
## shows the item's tooltip, on the hover board with its picture.
class _TipBox extends VBoxContainer:
	var tip_tex: Texture2D

	func _make_custom_tooltip(for_text: String) -> Object:
		if for_text.strip_edges() == "":
			return null
		if HoverBoard.available():
			return HoverBoard.make(tip_tex, for_text)
		return Keywords.make_tooltip(for_text)


## The frame behind a goods panel: on the stage the dark brass-and-wood picture, whole (it shrinks with the panel); else the usual panel.
var _tray: Control  # the tray the bottles stand in (the stage shop)
var _camp: TextureRect  # the campfire the meal and the wax are sold by (only when the new cart pictures are missing)
var _shelf: TextureRect  # the 2-tier wooden shelf: bottles on the upper plank, artifacts on the lower one
var _good_name := {}  # "upgrade" / "heal" -> the Label with its name, shown over the candle / the soup while the mouse is on it
var _cart_good := {}  # "upgrade" / "heal" -> the TextureRect of the candle / the soup standing on the cart


func _tray_h() -> float:
	var t := UiSkin.tex("nu_bottle_tray")
	return TRAY_W * float(t.get_height()) / float(t.get_width()) if t != null else 96.0


## A new tray for this round of boxes (the old one goes with the old boxes).
func _bottle_tray(old: Array) -> Control:
	if _tray != null and is_instance_valid(_tray) and _tray in _boxes:
		return _tray
	if _tray != null and is_instance_valid(_tray) and not _tray in old:
		old.append(_tray)
	_tray = Control.new()
	_tray.set_meta("kind", "tray")
	_tray.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tray.modulate.a = 0.0
	_tray.position = Vector2(-4000.0, 0.0)
	var h := _tray_h()
	var t := UiSkin.tex("nu_bottle_tray")
	if t != null:
		var r := TextureRect.new()
		r.texture = t
		r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		r.stretch_mode = TextureRect.STRETCH_SCALE
		r.size = Vector2(TRAY_W, h)
		r.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_tray.add_child(r)
		_tray.set_meta("sil", r)
	_tray.custom_minimum_size = Vector2(TRAY_W, h)
	_hang_layer.add_child(_tray)
	_boxes.append(_tray)
	return _tray


func _frame() -> StyleBox:
	if on_stage:
		var b := UiSkin.box("Panel Frame Dark", [0, 0, 0, 0], [34, 30, 34, 30])
		if b != null:
			return b
	return UiTheme.panel_box(0.95, 12)


func _centered(l: Label) -> Label:
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return l


func _buy(i: int) -> void:
	if on_stage and not _intro_done:
		return
	var it: Dictionary = stock[i]
	if it.get("sold", false):
		return
	if it.kind == "bottle" and run.player.bottles.size() >= run.bottle_slots():
		return
	if not run.pay(run.shop_price(it)):
		return
	Audio.play("shop_buy", -2.0, randf_range(0.97, 1.03))  # (coins; the same for everything bought)
	run.free_pick.erase(it.kind)  # (his thanks for a favour: one free, then the usual prices)
	match it.kind:
		"spell":
			run.learn_spell(it.spell.id)
			Events.toast.emit("Learned %s" % it.spell.name, UiTheme.ACCENT)
			it.sold = true
		"artifact":
			run.gain_artifact(it.artifact.id)
			Events.toast.emit("Got %s" % it.artifact.name, UiTheme.ACCENT)
			it.sold = true
		"bottle":
			run.gain_bottle(it.bottle)
			Events.toast.emit("Got %s %s" % [UiSkin.icon_token(it.bottle, Bottles.get_def(it.bottle).icon), Bottles.get_def(it.bottle).name], UiTheme.ACCENT)
			it.sold = true
		"mend_seed":
			run.mend_seed()
			Events.toast.emit("The Seed of Life is whole again", Color(0.75, 1.0, 0.6))
			it.sold = true
		"heal":
			run.player.heal(run.player.max_hp * RunState.REST_HEAL)
			Audio.play("rest_heal")
			it.sold = true
		"upgrade":
			it.sold = true
			upgrade_requested.emit()
			return
	_refresh.call_deferred()


# ------------------------------------------------------------------ Puppet Stage

## A picture of the art folder (the file's case may differ: Windows does not mind, the project does).
func _art(file: String) -> Texture2D:
	for f in [file, file.to_lower()]:
		if ResourceLoader.exists(ART_DIR + f):
			return load(ART_DIR + f)
	return null


## A picture of the art folder placed at `r` (null if it is missing).
func _pic_rect(file: String, r: Rect2, parent: Control) -> TextureRect:
	var t := _art(file)
	if t == null:
		return null
	var trect := TextureRect.new()
	trect.texture = t
	trect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	trect.stretch_mode = TextureRect.STRETCH_SCALE
	trect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	trect.position = r.position
	trect.size = r.size
	trect.pivot_offset = r.size / 2.0
	parent.add_child(trect)
	return trect


func _ready_stage() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE  # (the stage's own buttons stay clickable around the goods)
	_true_cart = _art(TRUE_CART) != null
	if _true_cart:
		_load_cart_layout()
	if _true_cart:
		SpellCard.hover_off = true  # (the cards on the cart never magnify)
	var fs := get_parent() as FightScreen
	_stage = fs.get_stage() if fs != null else null
	_ground = _stage.floor_range().y - FLOOR_MARGIN if _stage != null else 650.0
	_world = Control.new()
	_world.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_world.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_world.z_as_relative = false
	_world.z_index = PuppetStage.CEILING_Z - 1  # (over the scenery, under the valance)
	add_child(_world)
	_shadows = _Shadows.new()
	_shadows.shop = self
	_shadows.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_shadows.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_world.add_child(_shadows)
	_ropes = _HangRopes.new()
	_ropes.shop = self
	_ropes.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_ropes.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_world.add_child(_ropes)
	var floor_props := _plain_layer()  # (the shelf stands on the floor under the goods)
	_load_layout()
	_info_layer = Control.new()  # (under the shelf: the info board slides out from behind it; it is CLIPPED at the shelf's left side, so the part that has gone behind the shelf is simply not drawn)
	_info_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if _true_cart:  # (the board is in screen px, on the canopy, over everything: see _cart_info_update)
		_info_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		_info_layer.z_as_relative = false
		_info_layer.z_index = 150
		add_child(_info_layer)
	else:
		_info_layer.clip_contents = true
		floor_props.add_child(_info_layer)
	var shelf_t := _art("shelf.png")
	if shelf_t != null and not _true_cart:
		var sh := _shelf_w() * float(shelf_t.get_height()) / float(shelf_t.get_width())
		_shelf = TextureRect.new()
		_shelf.texture = shelf_t
		_shelf.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		_shelf.stretch_mode = TextureRect.STRETCH_SCALE
		_shelf.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		_shelf.size = Vector2(_shelf_w(), sh)
		_shelf.position = Vector2(_shelf_cx() - _shelf_w() / 2.0, _ground + 12.0 + float(_lay["shelf"]["dy"]) - sh)
		_shelf.mouse_filter = Control.MOUSE_FILTER_IGNORE
		floor_props.add_child(_shelf)
	_hang_layer = _plain_layer()
	_spell_layer = _plain_layer()
	_cart = _plain_layer()
	if _true_cart:
		_build_true_cart(_art(TRUE_CART))
	elif _art("cart_empty.png") != null and _art("candle.png") != null and _art("soup.png") != null:
		_pic_rect("cart_empty.png", CART_EMPTY_RECT, _cart)
		for kind: String in CART_GOODS:
			var g: Dictionary = CART_GOODS[kind]
			var gt := _art(g.file)
			var gh: float = g.h
			var gw: float = gh * float(gt.get_width()) / float(gt.get_height())
			var spr := _pic_rect(g.file, Rect2(Vector2(g.foot.x - gw / 2.0, g.foot.y - gh), Vector2(gw, gh)), _cart)
			spr.pivot_offset = Vector2(gw / 2.0, gh)
			spr.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
			_cart_good[kind] = spr
	else:
		_pic_rect("Cart.png", CART_RECT, _cart)
	if _true_cart:
		_wheel_back = _true_wheel("Layer 1.png", TC_WHEEL_BACK)
		_wheel_back.z_index = 1  # (both wheels are in front of the cart: the left one, under the drawbar end, is the cart's FRONT wheel)
		_wheel_front = _true_wheel("Layer 2.png", TC_WHEEL_FRONT)
		_wheel_front.z_index = 1  # (over the cart, under the goods and their price boxes (2 and up))
	else:
		_wheel_back = _pic_rect("Layer 1.png", WHEEL_BACK_RECT, _cart)
		_wheel_front = _pic_rect("Layer 2.png", WHEEL_FRONT_RECT, _cart)
	_merchant = _pic_rect("merchant_full.png", MERCHANT_RECT, _world)
	if _merchant != null and _true_cart:
		_merchant.z_index = 10  # (over the whole cart group: the goods (2-8) and the wheels (1) never cover him; the Menu button is at 101 = world 99 + 2, never covered by the wheel)
	var fire := UiSkin.tex("event_campfire_lit") if _cart_good.is_empty() and not _true_cart else null  # (the campfire and its cauldron of wax: the meal is cooked on it, the wax melted in it; the new cart has the two goods on its shelves)
	if fire != null:
		var ch := CAMP_W * float(fire.get_height()) / float(fire.get_width())
		_camp = TextureRect.new()
		_camp.texture = fire
		_camp.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		_camp.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		_camp.size = Vector2(CAMP_W, ch)
		_camp.position = Vector2(CAMP_CX - CAMP_W / 2.0, _ground + 12.0 - ch)
		_camp.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_world.add_child(_camp)
	_world.move_child(_hang_layer, _world.get_child_count() - 1)  # (the hanging goods in front of the cart: on the right they hang over it)
	for f in BUBBLE_FILES:
		var bt := _art(f)
		if bt != null:
			_bubble_tex.append(bt)
	if _merchant != null:
		_tex_stand = _merchant.texture
		_tex_drunk = _art("merchant_drunk.png")
		_set_pose(false)
		if MerchantQuests.is_drunk(quest):
			_set_pose(true)  # (once the favours are done he sits on his chair for good)
		_bubbles = _Bubbles.new()
		_bubbles.shop = self
		_bubbles.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_bubbles.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		_world.add_child(_bubbles)
	_pill = _leaves_pill()
	add_child(_pill)
	if SaveManager.setting("dev_mode", false) and not _true_cart:  # (the row of pose buttons (Arrive, Cart in...) is hidden on the true cart)
		add_child(_pose_row())
	var leave_btn := _leave_button()
	_leave_btn = leave_btn
	leave_btn.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	leave_btn.offset_left = -320.0
	leave_btn.offset_right = -60.0
	leave_btn.offset_top = -86.0
	leave_btn.offset_bottom = -30.0
	add_child(leave_btn)
	if _true_cart:
		_build_cart_ui()
	# (everything is there at once: the cart, the merchant and the goods; only the goods show up, all together)
	var roll_in := _true_cart and intro  # (the cart on its wheels is pushed in, the merchant walks in after it: see _arrive_walk)
	if roll_in:
		_set_cart_x(CART_FROM)
		_set_merchant_x(MERCHANT_FROM if not _drunk else CART_FROM)
		_arrived = false
		_arrive_walk.call_deferred()
	else:
		_set_cart_x(0.0)
		_set_merchant_x(0.0)
		_arrived = true
	_add_talk_stage.call_deferred()
	if intro and not _drunk and not roll_in:
		Audio.play("merchant_greeting")
	_refresh()


## Your Leaves: a plaque (the full-size dark bubble frame, thin rim) with the wooden coin stack and the number, bottom right, standing on the Leave button.
const COIN_STACK := "res://assets/Puppet/UI/Icons/Icon Wooden Coin Stack_20261013_160743.png"


func _leaves_pill() -> Control:
	var big := UiSkin.tex("frame_bubble_dark_full")
	if big == null:
		return _leaves_pill_old()
	var pw := 200.0
	var ph := 70.0
	var root := Control.new()
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	root.offset_right = -190.0 + pw / 2.0  # (centred over the Leave button)
	root.offset_left = root.offset_right - pw
	root.offset_bottom = -92.0
	root.offset_top = root.offset_bottom - ph
	var sbx := ScaledBox.make([big], 0.11, [28, 16, 28, 18])
	sbx.corner_px = 18.0
	var panel := Panel.new()
	panel.add_theme_stylebox_override("panel", sbx)
	panel.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.size = Vector2(pw, ph)
	root.add_child(panel)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 10)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.position = Vector2(14.0, 8.0)
	row.size = Vector2(pw - 28.0, ph - 16.0)
	root.add_child(row)
	if ResourceLoader.exists(COIN_STACK):
		var ci := TextureRect.new()
		ci.texture = load(COIN_STACK)
		ci.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		ci.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		ci.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		ci.custom_minimum_size = Vector2(46.0, 46.0)
		ci.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		ci.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(ci)
	_amber = UiTheme.label("", 36, Color(1.0, 0.93, 0.78))
	_amber.add_theme_constant_override("outline_size", 0)
	_amber.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(_amber)
	return root


func _leaves_pill_old() -> Control:
	var pill := PanelContainer.new()
	var box := UiSkin.box("amber_counter_pill", [22, 20, 22, 20], [22, 6, 30, 8])
	if box != null:
		pill.add_theme_stylebox_override("panel", box)
	pill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pill.tooltip_text = ""
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pill.add_child(row)
	var coin: Control = UiSkin.icon("icon_amber", 38)
	if coin == null:
		coin = UiTheme.label("🍃", 30)
	coin.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(coin)
	_amber = UiTheme.label("", 32, Color(0.75, 1.0, 0.6))
	_amber.add_theme_constant_override("outline_size", 6)
	_amber.add_theme_color_override("font_outline_color", Color(0.05, 0.2, 0.04))
	_amber.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(_amber)
	pill.position = Vector2(48.0, 650.0)  # (over the floor's front edge: the spell cards take the bottom of the screen)
	return pill


func _plain_layer() -> Control:
	var c := Control.new()
	c.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_world.add_child(c)
	return c


## The cart is `off` px from its place (positive: right of it): its wheels turn as far as it has rolled and it jolts a little on the planks.
func _set_cart_x(off: float) -> void:
	var jolt := -absf(sin(off * 0.07)) * 2.0 if absf(off) > 1.0 else 0.0
	_cart.pivot_offset = PDF_GROUND
	_cart.scale = Vector2.ONE * SHOP_SCALE
	_cart.position = Vector2(off, _ground - PDF_GROUND.y + jolt)
	if _wheel_back != null:
		_wheel_back.rotation = off / (WHEEL_BACK_RECT.size.x * 0.5 * SHOP_SCALE)
	if _wheel_front != null:
		_wheel_front.rotation = off / (WHEEL_FRONT_RECT.size.x * 0.5 * SHOP_SCALE)


## The merchant is `off` px from his place: he steps (a hop and a rock on every stride) and settles as he stops.
func _set_merchant_x(off: float) -> void:
	if _merchant == null:
		return
	_m_off = off
	var ph := off * STEP_K
	var stride := int(floorf(ph / PI))
	if stride != _stride:
		if _stride != -1000 and not _drunk:
			_step_sound(off)
		_stride = stride
	var feet := _pdf_to_screen(_cur_feet, off)
	_merchant.scale = Vector2.ONE * SHOP_SCALE
	if _drunk:  # (he is carried in on his chair, not walking)
		_merchant.position = feet - _merchant.pivot_offset
		_merchant.rotation = sin(off * 0.02) * 0.012
		return
	_merchant.position = feet - _merchant.pivot_offset + Vector2(0.0, -absf(sin(ph)) * 8.0)
	_merchant.rotation = sin(ph) * 0.035


## A point of the drunk picture (PDF coordinates of Merchant.pdf) moved to where he really sits.
func _drunk_pdf(p: Vector2) -> Vector2:
	return p + Vector2(MERCHANT_RECT.position.x + MERCHANT_RECT.size.x / 2.0 - (DRUNK_RECT.position.x + DRUNK_RECT.size.x / 2.0), 0.0)


## A point of Merchant.pdf on the screen: scaled about the cart's ground point and put on the stage's floor. `off`: how far the group is from its place.
func _pdf_to_screen(p: Vector2, off := 0.0) -> Vector2:
	return Vector2(PDF_GROUND.x + (p.x - PDF_GROUND.x) * SHOP_SCALE + off, _ground - (PDF_GROUND.y - p.y) * SHOP_SCALE)


## Standing (merchant_full) or sitting drunk on his chair (merchant_drunk): the picture, its place and the pivot of his walk change.
func _set_pose(drunk: bool) -> void:
	if _merchant == null:
		return
	if drunk and _tex_drunk == null:
		Events.toast.emit("There is no picture of the drunk merchant yet (merchant_drunk.png)", Color(1, 0.8, 0.4))
		return
	_drunk = drunk
	_cur_rect = DRUNK_RECT if drunk else MERCHANT_RECT
	# (sitting, he is where he stands: the middle of his picture on the middle of the standing one)
	_cur_feet = Vector2(MERCHANT_RECT.position.x + MERCHANT_RECT.size.x / 2.0, DRUNK_FEET_Y if drunk else MERCHANT_RECT.position.y + MERCHANT_RECT.size.y * MERCHANT_FEET)
	_merchant.texture = _tex_drunk if drunk else _tex_stand
	_merchant.size = _cur_rect.size
	_merchant.pivot_offset = Vector2(_cur_rect.size.x / 2.0, _cur_feet.y - _cur_rect.position.y)
	_merchant.flip_h = false
	_set_merchant_x(_m_off)


# ---- Dev Mode: the row of buttons over the cart, to try every pose of the merchant

var _pose_tw: Tween


func _pose_row() -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 5)
	row.position = Vector2(1010.0, 146.0)
	for p in [["Arrive", _pose_arrive], ["Cart in", _pose_cart_in], ["Walk in", _pose_walk.bind(true)], ["Walk out", _pose_walk.bind(false)],
			["Stand", _pose_idle], ["Greet", _pose_greet], ["Talk", _pose_talk], ["Drunk", _pose_drunk.bind(true)], ["Sober", _pose_drunk.bind(false)],
			["!", _pose_mark.bind("!")], ["?", _pose_mark.bind("?")], ["No mark", _pose_mark.bind("")]]:
		var b := UiTheme.button(p[0], p[1], 15)
		b.focus_mode = Control.FOCUS_NONE
		row.add_child(b)
	return row


func _pose_reset() -> void:
	if _pose_tw != null and _pose_tw.is_valid():
		_pose_tw.kill()
	_pose_tw = null
	_stride = -1000  # (the first step of the next walk is not heard)
	Audio.stop_held(_voice, 0.05)


func _pose_idle() -> void:
	_pose_reset()
	_set_cart_x(0.0)
	_set_merchant_x(0.0)
	_stride = -1000


func _pose_arrive() -> void:
	_pose_reset()
	_set_cart_x(CART_FROM)
	_set_merchant_x(MERCHANT_FROM)
	_arrive_walk()


func _pose_cart_in() -> void:
	_pose_reset()
	_set_cart_x(CART_FROM)
	Audio.play("shop_cart_roll", -2.0)
	_pose_tw = create_tween()
	_pose_tw.tween_method(_set_cart_x, CART_FROM, 0.0, CART_TIME).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


func _pose_walk(coming: bool) -> void:
	_pose_reset()
	_set_merchant_x(MERCHANT_FROM if coming else 0.0)
	_pose_tw = create_tween()
	_pose_tw.tween_method(_set_merchant_x, MERCHANT_FROM if coming else 0.0, 0.0 if coming else MERCHANT_FROM, MERCHANT_TIME).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT if coming else Tween.EASE_IN)


func _pose_greet() -> void:
	_pose_reset()
	_set_merchant_x(0.0)
	Audio.play("merchant_greeting")
	var y0 := _merchant.position.y
	_pose_tw = create_tween()
	for _i in 2:
		_pose_tw.tween_property(_merchant, "position:y", y0 - 14.0, 0.14).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		_pose_tw.tween_property(_merchant, "position:y", y0, 0.14).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)


func _pose_talk() -> void:
	_dialog(MerchantQuests.ASK[0], [[MerchantQuests.ACCEPT[0], _close_dialog], [MerchantQuests.DECLINE, _close_dialog]])


func _pose_drunk(on: bool) -> void:
	_pose_reset()
	_set_pose(on)
	_arrived = true


func _pose_mark(m: String) -> void:
	_set_mark(m)


## Talking to him on the stage: he takes clicks, and the favour mark floats over his head.
func _add_talk_stage() -> void:
	if _merchant == null:
		return
	var top := _pdf_to_screen(_drunk_pdf(Vector2(753.0, DRUNK_RECT.position.y)) if _drunk else Vector2(_cur_feet.x, _cur_feet.y - MERCHANT_RECT.size.y * MERCHANT_FEET))  # (the top of his head)
	_add_talk(_merchant, top + (Vector2(40.0, -100.0) if _drunk else Vector2(-24.0, -100.0)))
	if _mark != null and not _arrived:
		_mark.modulate.a = 0.0  # (the sign over his head shows once he has walked in)


## One of his boots comes down: quieter while he is far off the screen, the two boot sounds alternate, never quite the same pitch twice.
func _step_sound(off: float) -> void:
	Audio.play("shop_step" if _stride % 2 == 0 else "shop_step_2", -4.0 - 12.0 * clampf(off / 900.0, 0.0, 1.0), randf_range(0.94, 1.06))


## The cart is pulled in, the merchant walks in after it.
func _arrive_walk() -> void:
	Audio.play("shop_cart_roll", -2.0)  # (4.4 s, fading out as the cart slows)
	var tw := create_tween().set_parallel(true)
	_pose_tw = tw
	tw.tween_method(_set_cart_x, CART_FROM, 0.0, CART_TIME).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	if _drunk:  # (he rides in on his chair, a little behind the cart, and says nothing: he is drunk)
		tw.tween_method(_set_merchant_x, CART_FROM, 0.0, CART_TIME).set_delay(0.25).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	else:
		tw.tween_method(_set_merchant_x, MERCHANT_FROM, 0.0, MERCHANT_TIME).set_delay(MERCHANT_DELAY).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	await tw.finished
	_arrived = true
	if _mark != null:
		_mark.modulate.a = 1.0
	if not _drunk:
		Audio.play("merchant_greeting")
	_arrive.emit()


## How much wider than the design the floor is at screen height `y` (it is a trapezoid: narrow at the back wall, wide at the front edge): what a card
## lying there is stretched by.
func _floor_stretch(y: float) -> float:
	if _stage == null:
		return 1.0
	var fr := _stage.floor_range()
	var wb: float = _stage.verts["back_bot_r"].x - _stage.verts["back_bot_l"].x
	var wf: float = _stage.verts["front_r"].x - _stage.verts["front_l"].x
	return lerpf(wb, wf, (y - fr.x) / maxf(1.0, fr.y - fr.x)) / PuppetStage.DESIGN_W


## Sizes every new box, puts it in its place and (the first time) plays the arrival of the goods, all at once; then the old boxes go.
## The spell cards stand along the bottom of the screen and are conjured up; the artifacts hang on the left, the bottles, the
## wax and the meal on the right (over the cart, never over the merchant), let down on their ropes.
func _stage_layout(old: Array) -> void:
	_gen += 1
	var gen := _gen
	for _i in 3:
		await get_tree().process_frame  # (the boxes get their sizes)
		if gen != _gen or not is_inside_tree():
			return
	var animate := not _intro_done and intro
	var spells_total := _boxes.filter(func(x): return is_instance_valid(x) and x.get_meta("kind") == "spell").size()
	var n_spell := 0
	var n_left := 0
	var n_right := 0
	var hang_new: Array[Dictionary] = []
	var sh_new: Array[Dictionary] = []
	var n_bottle := 0
	var camp_top := _ground - 230.0
	var camp_foot := _ground + 12.0
	if _camp != null:
		camp_top = _camp.position.y
		camp_foot = _camp.position.y + _camp.size.y
		sh_new.append({"cx": CAMP_CX + 6.0, "foot": camp_foot - 6.0, "w": CAMP_W * 0.75, "a": 1.0})
	for b in _boxes:
		if not is_instance_valid(b):
			continue
		b.size = b.get_combined_minimum_size()
		var w: float = b.size.x
		var h: float = b.size.y
		var kind := String(b.get_meta("kind"))
		if kind in ["bottle", "artifact"] and _shelf != null:
			# (bottles on the upper plank, artifacts on the lower one: the item's bottom on the plank, its price button on the plank's front edge; no string, no swing)
			var up: bool = kind == "bottle"
			var idx: int = n_bottle if up else n_left
			if up:
				n_bottle += 1
			else:
				n_left += 1
			b.pivot_offset = Vector2(w / 2.0, 0.0)
			b.scale = Vector2.ONE
			b.position = _slot_pos(up, idx, w)
			_fade_in(b, animate, 0.8 + 0.2 * (idx + 1))
			continue
		if kind == "tray":
			b.size = Vector2(TRAY_W, _tray_h())
			w = b.size.x
		if kind in ["upgrade", "heal"] and _cart_good.has(kind):
			b.visible = false  # (the candle / the soup stand on the cart: the box with the price shows under them, the name over them while the mouse is on them: see _goods_tick)
			for tc in b.get_children():
				if tc is Label:
					tc.visible = false
			if not _good_name.has(kind) or not is_instance_valid(_good_name[kind]):
				var nl := UiTheme.heading("A hot meal" if kind == "heal" else "Wax seal", 26, Color(1.0, 0.93, 0.78))
				nl.add_theme_constant_override("outline_size", 8)
				nl.add_theme_color_override("font_outline_color", Color(0.12, 0.06, 0.02))
				nl.mouse_filter = Control.MOUSE_FILTER_IGNORE
				nl.visible = false
				nl.z_index = 26
				nl.size = nl.get_combined_minimum_size()
				_hang_layer.add_child(nl)
				_good_name[kind] = nl
			b.modulate.a = 1.0
			b.scale = Vector2.ONE
			continue
		if kind in ["upgrade", "heal"] and _camp != null:
			# (by the campfire: the meal over it, the wax under it)
			b.pivot_offset = Vector2(w / 2.0, h / 2.0)
			b.position = Vector2(CAMP_CX - w / 2.0, camp_top - h + 6.0 if kind == "heal" else camp_foot + 2.0)
			b.scale = Vector2.ONE
			if animate:
				b.modulate.a = 0.0
				b.create_tween().tween_property(b, "modulate:a", 1.0, 0.5).set_delay(0.3)
			else:
				b.modulate.a = 1.0
			continue
		if kind == "spell":
			var cw := w * SPELL_SCALE
			var gap := (float(CARD_SPAN[1]) - float(CARD_SPAN[0]) - cw * spells_total) / maxf(1.0, spells_total - 1.0)
			var cx := float(CARD_SPAN[0]) + cw / 2.0 + float(n_spell) * (cw + minf(gap, 60.0)) + maxf(0.0, gap - 60.0) * (spells_total - 1) / 2.0
			var rest := Vector2(cx - w / 2.0, CARD_FOOT - h)  # (its box, unscaled: it is scaled about its bottom edge)
			n_spell += 1
			b.pivot_offset = Vector2(w / 2.0, h)
			b.position = rest
			b.scale = Vector2.ONE * SPELL_SCALE
			sh_new.append({"cx": cx, "foot": CARD_FOOT, "w": w * SPELL_SCALE, "a": 1.0})
			b.modulate.a = 1.0
			if animate:
				_conjure(b)
		else:
			var rest: Vector2
			if kind == "tray":
				rest = Vector2(TRAY_CX - w / 2.0, TRAY_TOP)
			elif kind == "artifact":
				var k := mini(n_left, ART_X.size() - 1)
				rest = Vector2(float(ART_X[k]) + 40.0 * float(n_left - k) - w / 2.0, float(ART_TOP[k]))
				n_left += 1
			else:
				rest = Vector2(float(RIGHT_X[n_right % 2]) - w / 2.0, float(RIGHT_ROW_Y[mini(n_right / 2, 1)]) + 26.0 * float(n_right % 2))
				n_right += 1
			b.pivot_offset = Vector2(w / 2.0, 0.0)
			b.scale = Vector2.ONE * HANG_SCALE
			b.position = rest
			if kind == "artifact" and b.has_meta("sil"):
				var art: TextureRect = b.get_meta("sil")
				b.set_meta("tie", art.get_parent().position + art.position + art.size / 2.0)  # (its string comes down behind it, to its middle: it swings about that)
			var d := {"box": b, "rest": rest, "phase": float(n_left + n_right) * 1.9, "swing": 0.0, "on": not animate,
					"one": kind == "artifact" and b.has_meta("sil"), "a": 0.0, "v": 0.0}  # (one: it hangs on one string, and swings on it)
			if kind == "tray":
				b.scale = Vector2.ONE
			if animate:
				b.modulate.a = 0.0
				_drop_in(d, 0.0)
			else:
				b.modulate.a = 1.0
				d.swing = 1.0
			hang_new.append(d)
	_hang = hang_new
	_spell_sh = sh_new
	for b in old:
		if is_instance_valid(b):
			b.queue_free()
	if animate:
		await get_tree().create_timer(HANG_FALL + 1.3).timeout
	_intro_done = true


## A good that stands on the rug or the table appears (fades in) once the merchant has arrived; no string, no fall.
func _fade_in(b: Control, animate: bool, delay: float) -> void:
	if animate:
		b.modulate.a = 0.0
		b.create_tween().tween_property(b, "modulate:a", 1.0, 0.5).set_delay(delay + CART_TIME * 0.5)
	else:
		b.modulate.a = 1.0


## A spell card is conjured up where it stands: it shows as static that settles into the card (the conjuring of a fight's
## spells), and its price fades in under it.
func _conjure(b: Control) -> void:
	Audio.play("spell_glow", -4.0)
	for c in b.get_children():
		if c is SpellCard:
			(c as SpellCard).static_in((c as Control).global_position, CONJURE_TIME)
			(c as SpellCard).warm_hover.call_deferred()  # (their magnified copy is made once, unseen, now: not on the first hover)
		elif c is Button:
			(c as Control).modulate.a = 0.0
			(c as Control).create_tween().tween_property(c, "modulate:a", 1.0, 0.3).set_delay(CONJURE_TIME * 0.6)


## A spell card lies face up on the floor (a picture of the box, drawn to a mesh in perspective: far edge higher and narrower, the whole stretched with the
## floor) and, after the pause, swings up about its bottom edge to stand, with a little overshoot and a hop. The real box takes its place at the end.
func _pop(b: Control, rest: Vector2, fx: float, delay: float, sh: Dictionary) -> void:
	var w: float = b.size.x
	var h: float = b.size.y
	var vp := SubViewport.new()
	vp.size = Vector2i(ceili(w * SPELL_SCALE), ceili(h * SPELL_SCALE))
	vp.transparent_bg = true
	vp.gui_disable_input = true
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	var col := VBoxContainer.new()
	col.theme = UiTheme.get_theme()  # (a viewport does not hand the theme down)
	col.add_theme_constant_override("separation", 6)
	col.add_child(SpellCard.make(b.get_meta("spell")))
	var btn := UiTheme.button(b.get_meta("buy"), func(): pass, 18, "buy")
	btn.disabled = b.get_meta("off")
	col.add_child(btn)
	col.size = Vector2(w, h)
	col.scale = Vector2.ONE * SPELL_SCALE
	vp.add_child(col)
	add_child(vp)
	var poly := Polygon2D.new()
	poly.texture = vp.get_texture()
	poly.modulate.a = 0.0
	_spell_layer.add_child(poly)
	var polys: Array = []
	for r in MESH_ROWS:
		polys.append(PackedInt32Array([2 * r, 2 * r + 1, 2 * r + 3, 2 * r + 2]))
	_pose(poly, rest, w, h, LIE_ANGLE, fx, 0.0)
	poly.polygons = polys
	for _i in 3:
		await get_tree().process_frame  # (the viewport draws its first picture)
	if not is_instance_valid(poly):
		return
	create_tween().tween_method(func(v: float): sh.a = v, 0.0, 1.0, 0.3)  # (its shadow comes with it)
	create_tween().tween_property(poly, "modulate:a", 1.0, 0.3)  # (it lies there as soon as the merchant has stopped, and springs up after the pause)
	await get_tree().create_timer(maxf(0.0, delay - 0.05)).timeout
	if not is_instance_valid(poly):
		return
	Audio.play("shop_card_pop", -2.0, randf_range(0.92, 1.08))
	var tw := create_tween()
	tw.tween_method(_swing.bind(poly, rest, w, h, fx), 0.0, 1.0, POP_TIME).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	await tw.finished
	if is_instance_valid(b):
		b.modulate.a = 1.0
	if is_instance_valid(poly):
		poly.queue_free()
	vp.queue_free()


func _swing(v: float, poly: Polygon2D, rest: Vector2, w: float, h: float, fx: float) -> void:
	if not is_instance_valid(poly):
		return
	var c := clampf(v, 0.0, 1.0)
	_pose(poly, rest, w, h, lerpf(LIE_ANGLE, PI / 2.0, v), lerpf(fx, 1.0, c), 46.0 * sin(PI * c))


## The card, tilted `a` radians up from the floor about its bottom edge, as a strip mesh: a point `d` px up the card is `d sin a` high and `d cos a` further
## from you, which lifts it on the screen by `LIE_DEPTH` of that and narrows it. `stretch`: how much the floor widens the card there.
func _pose(poly: Polygon2D, rest: Vector2, w: float, h: float, a: float, stretch: float, hop: float) -> void:
	var cw := w * SPELL_SCALE
	var ch := h * SPELL_SCALE
	var hinge := Vector2(rest.x + w / 2.0, rest.y + h - hop)
	var pts := PackedVector2Array()
	var uvs := PackedVector2Array()
	for r in MESH_ROWS + 1:
		var t := float(r) / MESH_ROWS  # (0: the top edge, 1: the bottom)
		var d := (1.0 - t) * ch
		var depth := d * cos(a)
		var y := hinge.y - d * sin(a) - depth * LIE_DEPTH
		var sc := stretch * clampf(1.0 - LIE_NARROW * depth / ch, 0.3, 1.5)
		pts.append(Vector2(hinge.x - cw / 2.0 * sc, y))
		pts.append(Vector2(hinge.x + cw / 2.0 * sc, y))
		uvs.append(Vector2(0.0, t * ch))
		uvs.append(Vector2(cw, t * ch))
	poly.polygon = pts
	poly.uv = uvs


## An item is let down on its two ropes: a short fall, then a few bobs on the stretched ropes.
func _drop_in(d: Dictionary, delay: float) -> void:
	var b: Control = d.box
	var rest: Vector2 = d.rest
	var from := rest.y + b.size.y * HANG_SCALE + 80.0
	b.position.y = rest.y - from
	await get_tree().create_timer(delay).timeout
	if not is_instance_valid(b):
		return
	b.modulate.a = 1.0
	d.on = true
	Audio.play("shop_frame_drop", -3.0, randf_range(0.95, 1.05))
	var tw := create_tween()
	tw.tween_method(_hang_step.bind(b, rest.y, from), 0.0, HANG_FALL + 1.3, HANG_FALL + 1.3)
	await tw.finished
	if is_instance_valid(b):
		b.position.y = rest.y
	d.swing = 1.0
	d.v = randf_range(-1.0, 1.0) * SWING_NUDGE


func _hang_step(t: float, b: Control, rest_y: float, from: float) -> void:
	if not is_instance_valid(b):
		return
	if t < HANG_FALL:
		var u := t / HANG_FALL
		b.position.y = rest_y - from * (1.0 - u * u)
	else:
		var s := t - HANG_FALL
		b.position.y = rest_y + 20.0 * exp(-4.5 * s) * sin(TAU * 1.8 * s)


func _process(delta: float) -> void:
	if not on_stage:
		return
	_t += delta
	var mp := test_mouse if test_mouse != Vector2.INF else get_global_mouse_position()
	var now := Time.get_ticks_msec()
	for d in _hang:
		var b: Control = d.box
		if is_instance_valid(b) and d.one and float(d.swing) >= 1.0:
			# (an artifact on its string: a pendulum from where the string comes down, as a puppet swings; a slow breeze of its own)
			var breeze := 0.045 * sin(_t * 0.8 + float(d.phase)) + 0.02 * sin(_t * 1.9 + float(d.phase) * 1.7)  # (it never quite stops swinging)
			d.v += (-SWING_K * (float(d.a) - breeze) - SWING_DAMP * float(d.v)) * delta
			d.a = clampf(float(d.a) + float(d.v) * delta, -SWING_MAX, SWING_MAX)
			var rest: Vector2 = d.rest
			var at: Vector2 = b.get_meta("tie", Vector2(b.size.x / 2.0, 0.0))  # (where the string is tied, on the picture)
			var hook := Vector2(rest.x + at.x, ROPE_TOP)
			var tie := hook + Vector2(-sin(float(d.a)), cos(float(d.a))) * (rest.y + at.y - ROPE_TOP)
			b.pivot_offset = at
			b.rotation = float(d.a)
			b.position = tie - b.pivot_offset
		elif is_instance_valid(b) and String(b.get_meta("kind", "")) == "tray":
			b.rotation = float(d.swing) * 0.008 * sin(_t * 1.1 + float(d.phase))
			if float(d.swing) >= 1.0:
				for k in b.get_children():
					if k is VBoxContainer:
						_grow(k, (_under(k, mp) or int(k.get_meta("hold", 0)) > now), 1.25)
		elif is_instance_valid(b):
			b.rotation = float(d.swing) * 0.012 * sin(_t * 1.1 + float(d.phase))
		if is_instance_valid(b) and String(b.get_meta("kind", "")) != "tray":
			if float(d.swing) >= 1.0:  # (landed: it grows under the mouse, and for a while after a click)
				var big: bool = _under(b, mp) or int(b.get_meta("hold", 0)) > now
				if big and not bool(b.get_meta("big", false)) and d.one:
					d.v += SWING_NUDGE * (1.0 if randf() < 0.5 else -1.0)  # (touched: it swings)
				if big != bool(b.get_meta("big", false)):
					b.set_meta("big", big)
					b.z_index = 20 if big else 0  # (over its neighbours while it is big)
					var old = b.get_meta("mag_tw", null)
					if old is Tween and old.is_valid():
						old.kill()
					var tw := b.create_tween()
					b.set_meta("mag_tw", tw)
					tw.tween_property(b, "scale", Vector2.ONE * HANG_SCALE * (HANG_BIG if big else 1.0), 0.14).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_hover_info = {}
	if _true_cart:
		_cart_tick(mp)
		_items_tick(mp, now)
		_cards_tick(mp, now)
		_cart_edit_tick()
		_cart_info_update(delta)
	else:
		_goods_tick(mp)
		_items_tick(mp, now)
		_info_update(delta)
	if _editing:
		_edit_follow()
	if _ropes != null:
		_ropes.queue_redraw()


## The candle and the soup on the cart: under the mouse (or under their price box) they light up and the box with the name and the price shows (the candle's above it, the soup's below it); a sold one is gone.
func _goods_tick(mp: Vector2) -> void:
	for kind: String in _cart_good:
		var spr: TextureRect = _cart_good[kind]
		var idx := _good_index(kind)
		var sold: bool = idx < 0 or stock[idx].get("sold", false)
		spr.visible = not sold
		var box: Control = null
		for b in _boxes:
			if is_instance_valid(b) and b.has_meta("kind") and b.get_meta("kind") == kind:
				box = b
		var hot: bool = _intro_done and not sold and (_under(spr, mp) or (box != null and _under(box, mp)))
		if hot and box != null and box.has_meta("tip"):
			_hover_info = {"key": kind, "text": String(box.get_meta("tip")), "tex": spr.texture}
		spr.modulate = spr.modulate.lerp(GOOD_GLOW if hot else Color.WHITE, 0.25)
		spr.scale = spr.scale.lerp(Vector2.ONE * (ITEM_BIG if hot else 1.0), 0.25)  # (only the picture grows: the price under it stays where it is)
		var gt := spr.get_global_transform()
		var rest_bottom: Vector2 = spr.get_parent().get_global_transform() * (spr.position + Vector2(spr.size.x / 2.0, spr.size.y))  # (the picture's foot, not grown)
		if box != null:
			box.scale = Vector2.ONE
			box.visible = _intro_done and not sold  # (the price shows all the time under the candle and the soup)
			box.size = box.get_combined_minimum_size()
			box.position = Vector2(rest_bottom.x - box.size.x / 2.0, rest_bottom.y + 3.0)
			box.z_index = 25
		var nm: Label = _good_name.get(kind)
		if nm != null:
			nm.visible = hot
			if hot:
				var top: Vector2 = gt * Vector2(spr.size.x / 2.0, 0.0)
				nm.position = Vector2(top.x - nm.size.x / 2.0, top.y - nm.size.y - 2.0)


## The info board: it slides out to the LEFT of the shelf (from behind it) while the mouse is on, or has just clicked, an item (artifact, bottle, the candle, the soup), shows what the
## item is and does, and slides back in behind the shelf when no item is hot. It never covers the goods.
var _info_layer: Control
var _info: Control
var _info_key := ""
var _info_t := 0.0  # 0 = tucked away behind the shelf, 1 = out
var _hover_info: Dictionary = {}  # set each frame by _goods_tick / _items_tick: {"key", "text", "tex"}


func _info_update(delta: float) -> void:
	if _info_layer == null:
		return
	var want := not _hover_info.is_empty() and not _editing
	if want and String(_hover_info["key"]) != _info_key:
		_info_key = String(_hover_info["key"])
		for c in _info_layer.get_children():
			c.queue_free()
		var tex: Texture2D = _hover_info["tex"] if _hover_info["tex"] is Texture2D else null
		var text := String(_hover_info["text"])
		var bd: Control = HoverBoard.make(tex, text, null, true, 330.0) if HoverBoard.available() else Keywords.make_tooltip(text)
		bd.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bd.z_index = 0
		_info_layer.add_child(bd)
		bd.reset_size()
		_info = bd
	_info_t = move_toward(_info_t, 1.0 if want else 0.0, delta * 4.5)
	if _info == null or not is_instance_valid(_info):
		return
	_info.visible = _info_t > 0.001
	if not _info.visible:
		_info_key = ""
		return
	var sh_rect := _shelf.get_rect() if _shelf != null else Rect2(500.0, 200.0, 600.0, 400.0)
	var w := _info.size.x
	var clip_x := sh_rect.position.x + 28.0  # (the DELETE POINT: the board is drawn only left of here, 28 px under the shelf's left side, so past it the board is gone, hidden behind the shelf)
	_info_layer.position = Vector2.ZERO
	_info_layer.size = Vector2(maxf(clip_x, 1.0), 1200.0)
	var out_x := maxf(6.0, clip_x - w)  # (out: its right end at the delete point)
	var e := 1.0 - pow(1.0 - _info_t, 3.0)
	_info.position = Vector2(lerpf(clip_x, out_x, e), sh_rect.position.y + sh_rect.size.y * 0.18)  # (in: its left end at the delete point: nothing of it is drawn any more)
	_info.modulate.a = 1.0


## An artifact on the rug or a bottle on the table: only its PICTURE grows under the mouse (the box with the price does not move or grow).
func _items_tick(mp: Vector2, now: int) -> void:
	for b in _boxes:
		if not is_instance_valid(b) or not b.has_meta("pic") or not b.has_meta("kind") or not String(b.get_meta("kind")) in ["artifact", "bottle", "upgrade", "heal"]:
			continue
		var pic: Control = b.get_meta("pic")
		if not is_instance_valid(pic):
			continue
		var hot: bool = _intro_done and (not _true_cart or _zoomed) and b.visible and (_under(b, mp) or int(b.get_meta("hold", 0)) > now)
		if hot and b.has_meta("tip") and (_hover_info.is_empty() or _under(b, mp)):  # (a clicked item stays on the board for a while; the one under the mouse wins)
			_hover_info = {"key": "%s%d" % [String(b.get_meta("kind")), b.get_instance_id()], "text": String(b.get_meta("tip")), "tex": b.get_meta("tip_tex", null)}
		pic.scale = pic.scale.lerp(Vector2.ONE * ((TC_HOVER_BIG if _true_cart else ITEM_BIG) if hot else 1.0), 0.3)
		b.z_index = 8 if hot and _true_cart else (20 if hot else (2 if _true_cart else 0))


func _good_index(kind: String) -> int:
	for i in stock.size():
		if stock[i].kind == kind:
			return i
	return -1


## A bottle in the tray grows (about its bottom) under the mouse.
func _grow(b: Control, big: bool, by: float) -> void:
	if big == bool(b.get_meta("big", false)):
		return
	b.set_meta("big", big)
	b.z_index = 20 if big else 0
	var old = b.get_meta("mag_tw", null)
	if old is Tween and old.is_valid():
		old.kill()
	var tw := b.create_tween()
	b.set_meta("mag_tw", tw)
	tw.tween_property(b, "scale", Vector2.ONE * (by if big else 1.0), 0.14).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


## Is the point (on the screen) over this control, whatever its scale and turn?
static func _under(c: Control, p: Vector2) -> bool:
	return Rect2(Vector2.ZERO, c.size).has_point(c.get_global_transform().affine_inverse() * p)


## A click on a good keeps it big for HOLD_SECS: a hanging one stays grown, a standing card keeps its magnified copy.
func _input(ev: InputEvent) -> void:
	if edit_allowed and _true_cart and ev.is_action_pressed("dev_layout_edit"):
		_cart_edit_toggle()
		get_viewport().set_input_as_handled()
		return
	if _c_editing and _cart_edit_input(ev):
		get_viewport().set_input_as_handled()
		return
	if edit_allowed and on_stage and not _true_cart and ev.is_action_pressed("dev_layout_edit"):
		_edit_toggle()
		get_viewport().set_input_as_handled()
		return
	if _editing and on_stage and _edit_input(ev):
		get_viewport().set_input_as_handled()
		return
	if _true_cart and _zoomed and ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_RIGHT:
		get_viewport().set_input_as_handled()
		_zoom_out()  # (a right click = Back)
		return
	if not on_stage or not (ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT):
		return
	var mp := get_global_mouse_position()
	if _true_cart:
		_cart_click(ev.position)
		return
	if _intro_done:
		for kind: String in _cart_good:  # (a click on the candle or the soup buys it, as the price button does)
			var spr: TextureRect = _cart_good[kind]
			var idx := _good_index(kind)
			if spr.visible and idx >= 0 and _under(spr, mp):
				get_viewport().set_input_as_handled()
				_buy(idx)
				return
	for b in _boxes:
		if not is_instance_valid(b) or not _under(b, mp):
			continue
		if b.has_meta("kind") and b.get_meta("kind") == "spell":
			for c in b.get_children():
				if c is SpellCard:
					c.hold_zoom(HOLD_SECS)
		else:
			b.set_meta("hold", Time.get_ticks_msec() + int(HOLD_SECS * 1000.0))


## The ropes the artifacts and bottles hang on: two to the top corners of each, going straight up behind the valance.
class _HangRopes extends Control:
	var shop: ShopScreen

	func _draw() -> void:
		for d in shop._hang:
			var b: Control = d.box
			if not is_instance_valid(b) or not d.on:
				continue
			var rest: Vector2 = d.rest
			var xf := b.get_transform()
			var ink := RopeRig.STRING_COLOR
			if d.one:
				var at: Vector2 = b.get_meta("tie", Vector2(b.size.x * 0.5, 8.0))
				var tie: Vector2 = xf * at
				draw_line(Vector2(rest.x + at.x, ShopScreen.ROPE_TOP), tie, ink, RopeRig.STRING_W, true)
				draw_circle(tie, RopeRig.STRING_W * 1.3, ink)
				continue
			var fracs := [0.04, 0.96] if String(b.get_meta("kind", "")) == "tray" else [0.16, 0.84]
			for frac in fracs:
				var end: Vector2 = xf * Vector2(b.size.x * frac, 6.0)
				var top_x: float = rest.x + b.size.x * 0.5 + (b.size.x * frac - b.size.x * 0.5) * b.scale.x  # (it grows about its top middle)
				draw_line(Vector2(top_x, ShopScreen.ROPE_TOP), end, ink, RopeRig.STRING_W, true)
				draw_circle(end, RopeRig.STRING_W * 1.3, ink)


## The shadows, drawn under everything else of the shop: a soft blob on the floor under the cart, the merchant and the standing cards, and a soft copy of each
## hanging frame on the back wall (down and to the right of it). Both are pictures made once with a smooth fall-off (a Gaussian), not stacked flat shapes, so
## they have no edges.
class _Shadows extends Control:
	const BOX_PX := 96  # the box shadow's picture (a rounded block with a blurred rim) ...
	const BOX_CORE := 30  # ... the rim is this wide on every side
	const BOX_SIGMA := 9.0
	var shop: ShopScreen
	static var _blob: Texture2D
	static var _box: StyleBoxTexture

	func _process(_d: float) -> void:
		queue_redraw()

	## A round soft spot: 1 in the middle, falling off smoothly to 0 at the edge.
	static func _blob_tex() -> Texture2D:
		if _blob == null:
			var n := 128
			var img := Image.create(n, n, false, Image.FORMAT_LA8)
			for y in n:
				for x in n:
					var r := Vector2(x + 0.5 - n / 2.0, y + 0.5 - n / 2.0).length() / (n / 2.0)
					var a := exp(-r * r * 3.2) * (1.0 - smoothstep(0.85, 1.0, r))
					img.set_pixel(x, y, Color(1, 1, 1, a))
			_blob = ImageTexture.create_from_image(img)
		return _blob

	## A soft-edged block that can be stretched to any size (9-slice): the middle is solid, the rim fades out smoothly.
	static func _box_style() -> StyleBoxTexture:
		if _box == null:
			var img := Image.create(BOX_PX, BOX_PX, false, Image.FORMAT_LA8)
			for y in BOX_PX:
				for x in BOX_PX:
					var dx := maxf(maxf(BOX_CORE - x - 0.5, x + 0.5 - (BOX_PX - BOX_CORE)), 0.0)
					var dy := maxf(maxf(BOX_CORE - y - 0.5, y + 0.5 - (BOX_PX - BOX_CORE)), 0.0)
					var d := sqrt(dx * dx + dy * dy)
					img.set_pixel(x, y, Color(1, 1, 1, exp(-d * d / (2.0 * BOX_SIGMA * BOX_SIGMA)) * (1.0 - smoothstep(BOX_CORE * 0.8, float(BOX_CORE), d))))
			_box = StyleBoxTexture.new()
			_box.texture = ImageTexture.create_from_image(img)
			_box.texture_margin_left = BOX_CORE
			_box.texture_margin_top = BOX_CORE
			_box.texture_margin_right = BOX_CORE
			_box.texture_margin_bottom = BOX_CORE
		return _box

	func _draw() -> void:
		var ground := shop._ground
		var cart_x: float = ShopScreen.PDF_GROUND.x + shop._cart.position.x
		_floor_shadow(Vector2(cart_x + 16.0, ground - 1.0), 250.0, 20.0, 0.6)
		if shop._merchant != null:
			var m := shop._merchant
			var fy: float = ground - (ShopScreen.PDF_GROUND.y - shop._cur_feet.y) * ShopScreen.SHOP_SCALE
			_floor_shadow(Vector2(m.position.x + m.pivot_offset.x + 14.0, fy), 125.0 if shop._drunk else 76.0, 14.0 if shop._drunk else 12.0, 0.55)
		for d in shop._spell_sh:
			_floor_shadow(Vector2(d.cx + 12.0, d.foot), d.w * 0.56, 15.0, 0.5 * float(d.a))
		var sb := _box_style()
		for d in shop._hang:
			var b: Control = d.box
			if not is_instance_valid(b) or not d.on:
				continue
			if b.has_meta("sil"):
				var sil: TextureRect = b.get_meta("sil")
				if is_instance_valid(sil) and sil.texture != null:
					draw_set_transform_matrix(Transform2D(0.0, ShopScreen.SHADOW_SHIFT) * get_global_transform().affine_inverse() * sil.get_global_transform())
					draw_texture_rect(sil.texture, Rect2(Vector2.ZERO, sil.size), false, Color(0, 0, 0, 0.4))  # (no frame: the shadow of the thing itself)
				continue
			draw_set_transform_matrix(Transform2D(0.0, ShopScreen.SHADOW_SHIFT) * b.get_transform())  # (the frame's own turn and scale, then the shift)
			var g := float(BOX_CORE) - 6.0
			sb.modulate_color = Color(0, 0, 0, 0.5)
			draw_style_box(sb, Rect2(-g, -g, b.size.x + 2.0 * g, b.size.y + 2.0 * g))
		draw_set_transform_matrix(Transform2D.IDENTITY)

	func _floor_shadow(c: Vector2, rx: float, ry: float, strength: float) -> void:
		if strength <= 0.01:
			return
		draw_texture_rect(_blob_tex(), Rect2(c.x - rx, c.y - ry, rx * 2.0, ry * 2.0), false, Color(0, 0, 0, strength))


## The drunk merchant's bubbles: one flies out of his mouth every so often, floats up on a path of its own (leaning left, wobbling), grows a little and fades out.
class _Bubbles extends Control:
	var shop: ShopScreen
	var _list: Array = []
	var _next := 0.6

	func _process(d: float) -> void:
		if shop._drunk and shop._arrived and not shop._bubble_tex.is_empty():
			_next -= d
			if _next <= 0.0:
				_next = randf_range(ShopScreen.BUBBLE_EVERY.x, ShopScreen.BUBBLE_EVERY.y)
				_spawn()
		for b in _list:
			b.t += d
		_list = _list.filter(func(b): return b.t < b.life)
		queue_redraw()

	func _spawn() -> void:
		var mouth := shop._pdf_to_screen(shop._drunk_pdf(ShopScreen.MOUTH_PDF), shop._m_off) + Vector2(ShopScreen.BUBBLE_SHIFT_X, 0.0)
		var px := randf_range(ShopScreen.BUBBLE_SIZE.x, ShopScreen.BUBBLE_SIZE.y) * ShopScreen.SHOP_SCALE * (1.0 + randf_range(-ShopScreen.BUBBLE_SIZE_JITTER, ShopScreen.BUBBLE_SIZE_JITTER))
		_list.append({
			"tex": shop._bubble_tex[randi() % shop._bubble_tex.size()],
			"from": mouth + Vector2(randf_range(-2.0, 2.0), randf_range(-2.0, 2.0)),
			"size": px,
			"vx": randf_range(ShopScreen.BUBBLE_DRIFT.x, ShopScreen.BUBBLE_DRIFT.y),
			"vy": -randf_range(ShopScreen.BUBBLE_RISE.x, ShopScreen.BUBBLE_RISE.y),
			"wob": randf_range(2.0, 7.0),
			"freq": randf_range(1.5, 3.5),
			"ph": randf() * TAU,
			"life": randf_range(ShopScreen.BUBBLE_LIFE.x, ShopScreen.BUBBLE_LIFE.y),
			"t": 0.0,
		})

	func _draw() -> void:
		for b in _list:
			var u: float = b.t / b.life
			var pos: Vector2 = b.from + Vector2(b.vx * b.t + sin(b.t * b.freq + b.ph) * b.wob * minf(1.0, b.t * 2.0), b.vy * b.t - 8.0 * b.t * b.t)
			var alpha := minf(1.0, b.t / 0.15) * pow(1.0 - u, 1.2)  # (pops out quickly, then fades the whole way up)
			var sz: float = b.size * (0.85 + 0.35 * u)  # (a little bigger as it rises)
			draw_texture_rect(b.tex, Rect2(pos - Vector2(sz, sz) * 0.5, Vector2(sz, sz)), false, Color(1, 1, 1, alpha))


# ---------------------------------------------------------------- the true cart: goods laid on it, the camera zooms in on it

func _tc_k() -> float:
	return TC_W / TC_BBOX.size.x


## Where the cart picture's top-left corner is, in PDF px.
func _tc_origin() -> Vector2:
	var k := _tc_k()
	return Vector2(TC_LEFT - TC_BBOX.position.x * k, PDF_GROUND.y - TC_GROUND * k)


func _build_true_cart(tt: Texture2D) -> void:
	var k := _tc_k()
	var o := _tc_origin()
	var sz := Vector2(tt.get_width(), tt.get_height())
	_cart_pic = _pic_rect(TRUE_CART, Rect2(o, sz * k), _cart)
	_cart_pic.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	_cart_items = Control.new()  # (everything that lies on the cart is a child of this: picture px, so it moves, glows and zooms with the cart)
	_cart_items.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_cart_items.position = o
	_cart_items.scale = Vector2.ONE * k
	_cart_items.size = sz
	_cart.add_child(_cart_items)


## A wheel of the true cart: `v` = (centre x, centre y, diameter) in picture px.
func _true_wheel(file: String, v: Vector4) -> TextureRect:
	var k := _tc_k()
	var c := _tc_origin() + Vector2(v.x, v.y) * k
	var d := v.z * k
	var w := _pic_rect(file, Rect2(c - Vector2(d, d) / 2.0, Vector2(d, d)), _cart)
	if w != null:
		w.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	return w


## The Back button and the coin frame of the zoomed view (hidden until the camera is in).
func _build_cart_ui() -> void:
	var a1 := _amber
	_pill2 = _leaves_pill()
	_amber2 = _amber
	_amber = a1
	var w := _pill2.offset_right - _pill2.offset_left
	var h := _pill2.offset_bottom - _pill2.offset_top
	_pill2.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_pill2.offset_left = 24.0
	_pill2.offset_top = 24.0
	_pill2.offset_right = 24.0 + w
	_pill2.offset_bottom = 24.0 + h
	_pill2.pivot_offset = Vector2.ZERO
	_pill2.scale = Vector2.ONE * 0.85
	_pill2.z_as_relative = false
	_pill2.z_index = 200
	_pill2.visible = false
	add_child(_pill2)
	_back_btn = UiTheme.button("Back", _zoom_out, 20, "back")
	_back_btn.custom_minimum_size = Vector2(120.0, 46.0)
	_back_btn.set_anchors_preset(Control.PRESET_TOP_LEFT)
	var bx := 24.0 + w * 0.85 + 16.0  # (right of the coin frame: never over it)
	_back_btn.offset_left = bx
	_back_btn.offset_top = 24.0 + (h * 0.85 - 46.0) / 2.0
	_back_btn.offset_right = bx + 120.0
	_back_btn.offset_bottom = _back_btn.offset_top + 46.0
	_back_btn.z_as_relative = false
	_back_btn.z_index = 200
	_back_btn.visible = false
	add_child(_back_btn)
	_amber2.text = str(run.amber)


## The camera: `e` 0 is the shop as it is, 1 is zoomed in on the cart. The stage (the theatre behind) and the world (the cart, the merchant, the goods) move together.
func _cam_target() -> Array:
	var k := _tc_k()
	var z := TC_ZOOM_PX / (k * SHOP_SCALE)
	var p := _pdf_to_screen(_tc_origin() + TC_CANOPY * k)
	return [z, TC_ZOOM_AT - p * z]


func _cam_apply(e: float) -> void:
	_cam_e = e
	if _stage_rest.is_empty() and _stage != null:
		_stage_rest = {"s": _stage.scale, "p": _stage.position}
	var t := _cam_target()
	var z: float = lerpf(1.0, float(t[0]), e)
	var pos: Vector2 = (t[1] as Vector2) * e
	if _stage != null and is_instance_valid(_stage):
		_stage.pivot_offset = Vector2.ZERO
		_stage.scale = (_stage_rest["s"] as Vector2) * z
		_stage.position = (_stage_rest["p"] as Vector2) + pos
	if _world != null:
		_world.pivot_offset = Vector2.ZERO
		_world.scale = Vector2.ONE * z
		_world.position = pos


## Is the mouse on the cart (its drawn part, not the empty corners of its picture) and not on the merchant?
func _cart_hot(mp: Vector2) -> bool:
	if _cart_items == null:
		return false
	if _merchant != null and _under(_merchant, mp):
		return false
	return TC_BBOX.has_point(_cart_items.get_global_transform().affine_inverse() * mp)


## The cart lights up (with all that lies on it, as one thing) while the mouse is on it and a click would zoom in.
func _cart_tick(mp: Vector2) -> void:
	var hot := _view == "overview" and not _cam_busy and _arrived and _intro_done and _dlg == null and _cart_hot(mp)
	_cart.modulate = _cart.modulate.lerp(TC_GLOW if hot else Color.WHITE, 0.25)


func _set_overview_ui(on: bool) -> void:
	for c in [_leave_btn, _pill, _picture]:
		if c != null and is_instance_valid(c):
			c.visible = on
	if _mark != null:
		_mark.modulate.a = 1.0 if on else 0.0
		_mark.mouse_filter = Control.MOUSE_FILTER_STOP if on else Control.MOUSE_FILTER_IGNORE
	if _merchant != null:
		_merchant.mouse_filter = Control.MOUSE_FILTER_STOP if on else Control.MOUSE_FILTER_IGNORE
		_merchant.flip_h = not on  # (zoomed, he turns to the cart)


func _set_prices(a: float, animate := true) -> void:
	for b in _boxes:
		if is_instance_valid(b) and b.has_meta("btn"):
			var btn: Control = b.get_meta("btn")
			if is_instance_valid(btn):
				if animate:
					btn.create_tween().tween_property(btn, "modulate:a", a, 0.3)
				else:
					btn.modulate.a = a


func _zoom_in() -> void:
	if _view != "overview" or _cam_busy or _dlg != null or not _intro_done or not _arrived:
		return
	_view = "cart"
	_cam_busy = true
	_set_overview_ui(false)
	_cam_tw = create_tween()
	_cam_tw.tween_method(_cam_apply, _cam_e, 1.0, TC_CAM_TIME).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await _cam_tw.finished
	if not is_inside_tree():
		return
	_zoomed = true
	_cam_busy = false
	_back_btn.visible = true
	_pill2.visible = true
	_set_prices(1.0)


func _zoom_out() -> void:
	if _view != "cart" or _cam_busy:
		return
	_view = "overview"
	_cam_busy = true
	_zoomed = false
	_back_btn.visible = false
	_pill2.visible = false
	_set_prices(0.0)
	_set_overview_ui(true)
	_cam_tw = create_tween()
	_cam_tw.tween_method(_cam_apply, _cam_e, 0.0, TC_CAM_TIME).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await _cam_tw.finished
	if not is_inside_tree():
		return
	_cam_busy = false


func _exit_tree() -> void:
	if _true_cart:
		SpellCard.hover_off = false
		if _stage != null and is_instance_valid(_stage) and not _stage_rest.is_empty():
			_stage.scale = _stage_rest["s"]
			_stage.position = _stage_rest["p"]


## The picture(s) of an item that count as "on the item" (not its price box): the card, or the slot its picture stands in.
func _item_parts(b: Control) -> Array:
	var out: Array = []
	if String(b.get_meta("kind", "")) == "spell":
		for c in b.get_children():
			if c is SpellCard:
				out.append(c)
	elif b.has_meta("pic"):
		var pic: Control = b.get_meta("pic")
		if is_instance_valid(pic) and pic.get_parent() != null:
			out.append(pic.get_parent())
	return out


## A card under the mouse (or just clicked) grows 3% and puts its keyword words on the info board; nothing magnifies it.
func _cards_tick(mp: Vector2, now: int) -> void:
	for b in _boxes:
		if not is_instance_valid(b) or String(b.get_meta("kind", "")) != "spell" or not b.visible:
			continue
		for card: Control in _item_parts(b):
			var hot: bool = _zoomed and (_under(card, mp) or int(b.get_meta("hold", 0)) > now)
			card.pivot_offset = card.size / 2.0
			card.scale = card.scale.lerp(Vector2.ONE * (TC_HOVER_BIG if hot else 1.0), 0.3)
			if hot and String(b.get_meta("tip", "")) != "" and (_hover_info.is_empty() or _under(card, mp)):
				_hover_info = {"key": "spell%d" % b.get_instance_id(), "text": String(b.get_meta("tip")), "tex": null}


# ---- F6 on the zoomed cart (Test mode): resize the goods by kind
func _load_cart_layout() -> void:
	if not FileAccess.file_exists(CART_LAYOUT_PATH):
		return
	var d: Variant = JSON.parse_string(FileAccess.get_file_as_string(CART_LAYOUT_PATH))
	if d is Dictionary and d.get("mult") is Dictionary:
		for k: String in _mult:
			if d["mult"].has(k):
				_mult[k] = clampf(float(d["mult"][k]), 0.3, 3.0)


func _save_cart_layout() -> void:
	var f := FileAccess.open(CART_LAYOUT_PATH, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify({"mult": _mult}, "\t"))
		f.close()


func _cat(kind: String) -> String:
	return {"spell": "card", "bottle": "bottle", "upgrade": "wax", "heal": "soup", "artifact": "artifact"}.get(kind, "")


func _cart_edit_toggle() -> void:
	if not _c_editing and not _zoomed:
		return
	_c_editing = not _c_editing
	if _c_editing:
		_c_sel = ""
		_c_undo.clear()
		if _c_label == null:
			_c_label = UiTheme.label("", 22, Color(1.0, 0.93, 0.6))
			_c_label.add_theme_constant_override("outline_size", 6)
			_c_label.add_theme_color_override("font_outline_color", Color(0.1, 0.05, 0.02))
			_c_label.position = Vector2(330.0, 12.0)
			_c_label.z_as_relative = false
			_c_label.z_index = 300
			_c_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
			add_child(_c_label)
		_c_label.visible = true
	else:
		_save_cart_layout()
		if _c_label != null:
			_c_label.visible = false
		Events.toast.emit("Cart sizes saved", UiTheme.ACCENT)
	_c_text()


func _c_text() -> void:
	if _c_label == null:
		return
	var sel := "click an item to choose its kind" if _c_sel == "" else "%s x%.2f  (wheel / + - : size, Shift: fine, Ctrl+Z: undo)" % [_c_sel, float(_mult[_c_sel])]
	_c_label.text = "F6 EDIT  -  " + sel + "  -  F6 again: save"


## Returns true when the event was used by the editor.
func _cart_edit_input(ev: InputEvent) -> bool:
	if ev is InputEventMouseButton and ev.pressed:
		var mp: Vector2 = ev.position
		if ev.button_index == MOUSE_BUTTON_LEFT:
			for b in _boxes:
				if not is_instance_valid(b) or not b.visible:
					continue
				var tag: Control = b.get_meta("btn", null)
				var hit: bool = tag != null and is_instance_valid(tag) and _under(tag, mp)
				for k in _item_parts(b):
					if _under(k, mp):
						hit = true
				if hit:
					_c_sel = _cat(String(b.get_meta("kind", "")))
					_c_text()
					return true
			return false  # (the Back button etc. still work)
		if ev.button_index == MOUSE_BUTTON_WHEEL_UP or ev.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			if _c_sel != "":
				_c_resize((0.01 if ev.shift_pressed else 0.05) * (1.0 if ev.button_index == MOUSE_BUTTON_WHEEL_UP else -1.0))
			return true
		return false
	if ev is InputEventKey and ev.pressed:
		var step := 0.01 if ev.shift_pressed else 0.05
		if ev.keycode == KEY_EQUAL or ev.keycode == KEY_KP_ADD:
			if _c_sel != "":
				_c_resize(step)
			return true
		if ev.keycode == KEY_MINUS or ev.keycode == KEY_KP_SUBTRACT:
			if _c_sel != "":
				_c_resize(-step)
			return true
		if ev.keycode == KEY_Z and ev.ctrl_pressed:
			if not _c_undo.is_empty():
				_mult = _c_undo.pop_back()
				_c_apply()
				_c_text()
			return true
	return false


func _c_resize(d: float) -> void:
	_c_undo.append(_mult.duplicate())
	_mult[_c_sel] = clampf(float(_mult[_c_sel]) + d, 0.3, 3.0)
	_c_apply()
	_c_text()


## The new sizes: cards scale at once, the other goods are made again (their pictures are sized when they are built) and laid out evenly again.
func _c_apply() -> void:
	for b in _boxes:
		if is_instance_valid(b) and String(b.get_meta("kind", "")) == "spell":
			b.scale = Vector2.ONE * float(_mult["card"])
	if not _c_pending:
		_c_pending = true
		(func():
			_c_pending = false
			_refresh()).call_deferred()


func _cart_edit_tick() -> void:
	for b in _boxes:
		if not is_instance_valid(b):
			continue
		var lit: bool = _c_editing and _c_sel != "" and _cat(String(b.get_meta("kind", ""))) == _c_sel
		for k in _item_parts(b):
			k.modulate = Color(1.35, 1.3, 1.0) if lit else Color.WHITE


## A click: on the cart (overview) it zooms in; zoomed in, a click on a good (the picture, the card, the price) buys it.
func _cart_click(mp: Vector2) -> void:
	if _cam_busy or _dlg != null or not _intro_done or not _arrived:
		return
	if _view == "overview":
		if _cart_hot(mp):
			get_viewport().set_input_as_handled()
			_zoom_in()
		return
	for b in _boxes:
		if not is_instance_valid(b) or not b.visible or not b.has_meta("idx"):
			continue
		var tag: Control = b.get_meta("btn", null)
		var on_tag: bool = tag != null and is_instance_valid(tag) and _under(tag, mp)
		var on_item := false
		for k in _item_parts(b):
			if _under(k, mp):
				on_item = true
		if not on_tag and not on_item:
			continue
		get_viewport().set_input_as_handled()
		var i := int(b.get_meta("idx"))
		if not on_tag:
			b.set_meta("hold", Time.get_ticks_msec() + int(HOLD_SECS * 1000.0))  # (a click on the item only shows its board, like hovering; buying is the green box's job)
			return
		var it: Dictionary = stock[i]
		if not it.get("sold", false):
			if it.kind == "bottle" and run.player.bottles.size() >= run.bottle_slots():
				Events.toast.emit("Your bottle slots are full", Color(1, 0.8, 0.4))
			elif run.amber < run.shop_price(it):
				Events.toast.emit("Not enough Leaves", Color(1, 0.8, 0.4))
		_buy(i)
		return


## Sizes every box, lays it on the cart (its place by kind), and the old boxes go. The cards stack on the left, the bottles, the candle and the soup stand on the upper plank,
## the artifacts on the cart's floor.
func _cart_layout(old: Array) -> void:
	_gen += 1
	var gen := _gen
	for _i in 3:
		await get_tree().process_frame  # (the boxes get their sizes)
		if gen != _gen or not is_inside_tree():
			return
	var n_spell := 0
	var n_art := 0
	# the upper plank: bottles, candle, soup spread EVENLY (equal gaps between the pictures, and at the two ends); the artifacts stand under the last three
	var ups: Array = []
	for b in _boxes:
		if is_instance_valid(b) and String(b.get_meta("kind", "")) in ["bottle", "upgrade", "heal"]:
			ups.append(b)
	var tot := 0.0
	for b in ups:
		tot += float(b.get_meta("pic_w", 120.0))
	var gap := (TC_UP_R - TC_UP_L - tot) / float(ups.size() + 1)
	var start := TC_UP_L + gap - TC_UP_SHIFT  # (the first picture 20 px further left ...)
	var end := TC_UP_R - gap + TC_UP_SHIFT  # (... the last one 20 px further right, the ones between spread evenly)
	var between := (end - start - tot) / float(maxi(ups.size() - 1, 1))
	var ux := start
	var up_x: Array[float] = []
	for b in ups:
		var pw := float(b.get_meta("pic_w", 120.0))
		b.set_meta("cx", ux + pw / 2.0)
		up_x.append(ux + pw / 2.0)
		ux += pw + between
	for b in _boxes:
		if not is_instance_valid(b):
			continue
		b.size = b.get_combined_minimum_size()
		b.scale = Vector2.ONE
		b.rotation = 0.0
		b.modulate.a = 1.0
		b.visible = not bool(b.get_meta("sold", false))
		var w: float = b.size.x
		var kind := String(b.get_meta("kind", ""))
		var ph: float = float(b.get_meta("pic_h", b.size.y))
		var at := Vector2.ZERO  # where the picture's bottom middle goes
		match kind:
			"spell":
				var c: Vector2 = TC_CARDS[mini(n_spell, TC_CARDS.size() - 1)]
				b.pivot_offset = Vector2(w / 2.0, SpellCard.H / 2.0)
				b.scale = Vector2.ONE * float(_mult["card"])  # (F6 size)
				b.position = c - Vector2(w / 2.0, SpellCard.H / 2.0)
				b.z_index = 5 - n_spell  # (each card's price box is over the card below it; all over the front wheel (1))
				var card: SpellCard = null
				for kid in b.get_children():
					if kid is SpellCard:
						card = kid
				if card != null and not b.has_meta("tip_done"):  # (its keyword words go to the info board, not to a tooltip next to the card)
					b.set_meta("tip_done", true)
					b.set_meta("tip", card.tooltip_text)
					card.set_meta("tip_pinned", true)
					card.tooltip_text = ""
				var btn: Control = b.get_meta("btn")
				var bs := btn.get_combined_minimum_size()
				if n_spell < 2:  # (the two top cards: the price box stands LEFT of the card, its bottom level with the card's)
					btn.anchor_left = 0.0
					btn.anchor_right = 0.0
					btn.offset_right = -8.0
					btn.offset_left = -8.0 - bs.x
					btn.offset_bottom = -6.0
					btn.offset_top = -6.0 - bs.y
				else:  # (the two lower cards: centred on the card, level with the artifacts' price boxes (their top is 1248 in picture px))
					btn.anchor_left = 0.5
					btn.anchor_right = 0.5
					btn.offset_left = -bs.x / 2.0
					btn.offset_right = bs.x / 2.0
					btn.offset_top = TC_LOW_FOOT + 16.0 - (b.position.y + float(btn.get_parent().position.y))
					btn.offset_bottom = btn.offset_top + bs.y
				n_spell += 1
				continue
			"artifact":
				var ax: float = TC_LOW_X[mini(n_art, TC_LOW_X.size() - 1)]
				if up_x.size() >= 3:
					ax = up_x[up_x.size() - 3 + mini(n_art, 2)]  # (in line with the last three of the upper row)
				at = Vector2(ax, TC_LOW_FOOT)
				n_art += 1
			"bottle", "upgrade", "heal":
				at = Vector2(float(b.get_meta("cx", TC_UP_X[0])), TC_UP_FOOT)
			_:
				b.position = TC_MEND - b.size / 2.0
				continue
		b.z_index = 2  # (over the front wheel (1), so the price boxes are never behind it)
		b.pivot_offset = Vector2(w / 2.0, ph)
		b.position = at - Vector2(w / 2.0, ph)
	_set_prices(1.0 if _zoomed else 0.0, false)
	for b in old:
		if is_instance_valid(b):
			b.queue_free()
	_hang = []
	_spell_sh = []
	_intro_done = true


## The info board of the zoomed view: it fades in on the cart's canopy (over no item and no card) while the mouse is on an item.
func _cart_info_update(delta: float) -> void:
	if _info_layer == null or _cart_items == null:
		return
	var want := _zoomed and not _hover_info.is_empty() and not _c_editing
	if want and String(_hover_info["key"]) != _info_key:
		_info_key = String(_hover_info["key"])
		for c in _info_layer.get_children():
			c.queue_free()
		var tex: Texture2D = _hover_info["tex"] if _hover_info["tex"] is Texture2D else null
		var text := String(_hover_info["text"])
		var bd: Control = HoverBoard.make(tex, text, null, true, 330.0) if HoverBoard.available() else Keywords.make_tooltip(text)
		bd.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_info_layer.add_child(bd)
		bd.reset_size()
		_info = bd
	_info_t = move_toward(_info_t, 1.0 if want else 0.0, delta * 6.0)
	if _info == null or not is_instance_valid(_info):
		return
	_info.visible = _info_t > 0.001
	if not _info.visible:
		_info_key = ""
		return
	var e := 1.0 - pow(1.0 - _info_t, 3.0)
	var c: Vector2 = _info_layer.get_global_transform().affine_inverse() * (_cart_items.get_global_transform() * TC_INFO)
	_info.position = c - _info.size / 2.0 + Vector2(0.0, (1.0 - e) * 16.0)
	_info.modulate.a = e


# ---------------------------------------------------------------- layout editor (Test mode, F6)
## F6: the shelf and the goods on it can be placed by hand. Click the shelf or an item to select it; drag to move; mouse wheel or + / - to resize
## (the shelf alone; or ALL artifacts together / ALL bottles together); arrows nudge (Shift = 10 px); Ctrl+Z undoes; F6 again saves
## to LAYOUT_PATH (the user's own placing: never delete). Clicks do not buy anything while the editor is on.
const LAYOUT_PATH := "res://data/shop_layout_overrides.json"
var _lay: Dictionary = _default_layout()
var _editing := false
var _sel := ""  # "", "shelf", "art:<slot>" or "bottle:<slot>"
var _dragging := false
var _drag_mp := Vector2.ZERO
var _drag_lay: Dictionary = {}
var _undo: Array = []
var _edit_frame: ReferenceRect
var _edit_label: Label


static func _default_layout() -> Dictionary:
	return {"shelf": {"cx": SHELF_CX, "w": SHELF_W, "dy": 0.0},
			"art": {"px": 96.0, "slots": [[0.23, SHELF_LOW], [0.5, SHELF_LOW], [0.77, SHELF_LOW]]},
			"bottle": {"px": 88.0, "slots": [[0.23, SHELF_UP], [0.5, SHELF_UP], [0.77, SHELF_UP]]}}


func _load_layout() -> void:
	_lay = _default_layout()
	if not FileAccess.file_exists(LAYOUT_PATH):
		return
	var d: Variant = JSON.parse_string(FileAccess.get_file_as_string(LAYOUT_PATH))
	if not d is Dictionary:
		return
	for k: String in ["shelf", "art", "bottle"]:
		if d.has(k) and d[k] is Dictionary:
			for kk: String in (d[k] as Dictionary):
				_lay[k][kk] = d[k][kk]


func _shelf_w() -> float:
	return float(_lay["shelf"]["w"])


func _shelf_cx() -> float:
	return float(_lay["shelf"]["cx"])


func _art_px() -> int:
	if _true_cart:
		return int(TC_ART_PX * float(_mult["artifact"]))  # (picture px: the goods lie on the cart, which is drawn in its own picture px)
	return int(float(_lay["art"]["px"]))


func _bottle_px() -> float:
	if _true_cart:
		return TC_BOTTLE_PX * float(_mult["bottle"])
	return float(_lay["bottle"]["px"])


## Where the box of the `idx`-th artifact / bottle goes: the item's bottom at the slot's point on the shelf, the box centred on it.
func _slot_pos(up: bool, idx: int, w: float) -> Vector2:
	var sl: Array = _lay["bottle" if up else "art"]["slots"]
	var sp: Array = sl[mini(idx, sl.size() - 1)]
	var item_h: float = _bottle_px() if up else float(_art_px())
	return Vector2(_shelf.position.x + _shelf.size.x * float(sp[0]) - w / 2.0, _shelf.position.y + _shelf.size.y * float(sp[1]) - item_h)


func _apply_shelf() -> void:
	if _shelf == null or _shelf.texture == null:
		return
	var sh := _shelf_w() * float(_shelf.texture.get_height()) / float(_shelf.texture.get_width())
	_shelf.size = Vector2(_shelf_w(), sh)
	_shelf.position = Vector2(_shelf_cx() - _shelf_w() / 2.0, _ground + 12.0 + float(_lay["shelf"]["dy"]) - sh)


## Puts the existing boxes of the artifacts and bottles on their slots again (after the shelf or a slot moved).
func _replace_items() -> void:
	if _shelf == null:
		return
	var n_art := 0
	var n_bot := 0
	for b in _boxes:
		if not is_instance_valid(b) or not b.has_meta("kind"):
			continue
		var kind := String(b.get_meta("kind"))
		if kind == "artifact" or kind == "bottle":
			var up := kind == "bottle"
			b.position = _slot_pos(up, n_bot if up else n_art, b.size.x)
			if up:
				n_bot += 1
			else:
				n_art += 1


func _edit_toggle() -> void:
	_editing = not _editing
	if _editing:
		_undo.clear()
		_sel = ""
		_edit_frame = ReferenceRect.new()
		_edit_frame.editor_only = false
		_edit_frame.border_color = Color(1.0, 0.9, 0.2)
		_edit_frame.border_width = 3.0
		_edit_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_edit_frame.z_as_relative = false
		_edit_frame.z_index = 4000
		_edit_frame.visible = false
		add_child(_edit_frame)
		_edit_label = Label.new()
		_edit_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_edit_label.z_as_relative = false
		_edit_label.z_index = 4001
		_edit_label.position = Vector2(240.0, 8.0)
		_edit_label.add_theme_font_size_override("font_size", 18)
		_edit_label.add_theme_color_override("font_color", Color(1.0, 0.95, 0.5))
		_edit_label.add_theme_color_override("font_outline_color", Color.BLACK)
		_edit_label.add_theme_constant_override("outline_size", 6)
		add_child(_edit_label)
		_edit_refresh_label()
		print("SHOP EDITOR on: click the shelf or an item; drag = move; wheel / + - = size; arrows nudge; Ctrl+Z undo; F6 off = save")
	else:
		_save_layout()
		_edit_frame.queue_free()
		_edit_label.queue_free()
		_dragging = false


func _save_layout() -> void:
	var f := FileAccess.open(LAYOUT_PATH, FileAccess.WRITE)
	if f == null:
		print("SHOP EDITOR: could not write ", LAYOUT_PATH)
		return
	f.store_string(JSON.stringify(_lay, "\t"))
	f.close()
	print("SHOP EDITOR: saved ", LAYOUT_PATH, "  ", JSON.stringify(_lay))


func _edit_refresh_label() -> void:
	var what := "nothing selected"
	if _sel == "shelf":
		what = "SHELF  width %d" % int(_shelf_w())
	elif _sel.begins_with("art:"):
		what = "ARTIFACT slot %s  (all artifacts: %d px)" % [_sel.substr(4), _art_px()]
	elif _sel.begins_with("bottle:"):
		what = "BOTTLE slot %s  (all bottles: %d px)" % [_sel.substr(7), int(_bottle_px())]
	_edit_label.text = "EDITOR (F6 = save and close): %s   |   drag move, wheel or + - size, arrows nudge, Ctrl+Z undo" % what


## The artifact / bottle boxes in slot order: [{"id": "art:0", "box": Control}, ...].
func _edit_slots() -> Array:
	var out: Array = []
	var n_art := 0
	var n_bot := 0
	for b in _boxes:
		if not is_instance_valid(b) or not b.has_meta("kind"):
			continue
		var kind := String(b.get_meta("kind"))
		if kind == "artifact":
			out.append({"id": "art:%d" % n_art, "box": b})
			n_art += 1
		elif kind == "bottle":
			out.append({"id": "bottle:%d" % n_bot, "box": b})
			n_bot += 1
	return out


## What is under the mouse: an artifact / bottle slot first, then the shelf.
func _edit_pick(mp: Vector2) -> String:
	var hit := ""
	for d: Dictionary in _edit_slots():
		if _under(d["box"], mp):
			hit = String(d["id"])
	if hit != "":
		return hit
	if _shelf != null and _shelf.get_global_rect().has_point(mp):
		return "shelf"
	return ""


func _edit_push_undo() -> void:
	_undo.append(_lay.duplicate(true))
	if _undo.size() > 100:
		_undo.pop_front()


## Resize what is selected by `f` (1.04 = 4% bigger): the shelf, or every artifact / every bottle together.
func _edit_resize(f: float) -> void:
	if _sel == "":
		return
	_edit_push_undo()
	if _sel == "shelf":
		_lay["shelf"]["w"] = clampf(_shelf_w() * f, 200.0, 1400.0)
		_apply_shelf()
		_replace_items()
	else:
		var g := "bottle" if _sel.begins_with("bottle") else "art"
		_lay[g]["px"] = clampf(float(_lay[g]["px"]) * f, 24.0, 400.0)
		_refresh()  # (the boxes are built again at the new size; _stage_layout puts them on their slots)


func _edit_nudge(d: Vector2) -> void:
	if _sel == "":
		return
	_edit_push_undo()
	_edit_move(d, _lay.duplicate(true))


## Moves the selection by `d` px from where it is in `base` (a layout dictionary).
func _edit_move(d: Vector2, base: Dictionary) -> void:
	if _sel == "shelf":
		_lay["shelf"]["cx"] = float(base["shelf"]["cx"]) + d.x
		_lay["shelf"]["dy"] = float(base["shelf"]["dy"]) + d.y
		_apply_shelf()
	elif _shelf != null:
		var g := "bottle" if _sel.begins_with("bottle") else "art"
		var i := int(_sel.get_slice(":", 1))
		var sp: Array = (base[g]["slots"] as Array)[i]
		_lay[g]["slots"][i] = [float(sp[0]) + d.x / _shelf.size.x, float(sp[1]) + d.y / _shelf.size.y]
	_replace_items()


## The editor's own input: returns true when it used the event (nothing else sees it: no purchase, no button).
func _edit_input(ev: InputEvent) -> bool:
	if ev is InputEventMouseButton:
		var mb := ev as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_WHEEL_UP or mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			if mb.pressed:
				_edit_resize(1.04 if mb.button_index == MOUSE_BUTTON_WHEEL_UP else 1.0 / 1.04)
				_edit_refresh_label()
			return true
		if mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed:
				_sel = _edit_pick(mb.position)
				_dragging = _sel != ""
				if _dragging:
					_edit_push_undo()
					_drag_mp = mb.position
					_drag_lay = _lay.duplicate(true)
				_edit_refresh_label()
			else:
				_dragging = false
		return true
	if ev is InputEventMouseMotion and _dragging:
		_edit_move((ev as InputEventMouseMotion).position - _drag_mp, _drag_lay)
		return true
	if ev is InputEventKey and ev.pressed:
		var k := ev as InputEventKey
		var step := 10.0 if k.shift_pressed else 1.0
		match k.keycode:
			KEY_LEFT:
				_edit_nudge(Vector2(-step, 0.0))
			KEY_RIGHT:
				_edit_nudge(Vector2(step, 0.0))
			KEY_UP:
				_edit_nudge(Vector2(0.0, -step))
			KEY_DOWN:
				_edit_nudge(Vector2(0.0, step))
			KEY_EQUAL, KEY_PLUS, KEY_KP_ADD:
				_edit_resize(1.04)
			KEY_MINUS, KEY_KP_SUBTRACT:
				_edit_resize(1.0 / 1.04)
			KEY_Z:
				if k.ctrl_pressed and not _undo.is_empty():
					_lay = _undo.pop_back()
					_apply_shelf()
					_refresh()
			_:
				return false
		_edit_refresh_label()
		return true
	return false


func _edit_follow() -> void:
	if _edit_frame == null:
		return
	var r := Rect2()
	var ok := false
	if _sel == "shelf" and _shelf != null:
		r = _shelf.get_global_rect()
		ok = true
	elif _sel != "":
		for d: Dictionary in _edit_slots():
			if String(d["id"]) == _sel:
				var b: Control = d["box"]
				var pic: Control = b.get_meta("pic") if b.has_meta("pic") else null
				r = pic.get_global_rect() if is_instance_valid(pic) else b.get_global_rect()
				ok = true
	_edit_frame.visible = ok
	if ok:
		_edit_frame.global_position = r.position
		_edit_frame.size = r.size
