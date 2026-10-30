class_name ShopScreen
extends Control
## The merchant: spend Amber on spells, artifacts, bottles, a wax seal (it seals one Essence of a spell of yours) or a hot meal.

signal leave
signal upgrade_requested

## Puppet Stage: laid over the stage (no backdrop). The curtains are already open: the cart rolls in, the merchant walks after it, the spell cards lie down on the
## floor and spring up, the artifacts and bottles are let down on ropes. All the numbers below are the places in Merchant.pdf (1920 x 1080) or knobs to tune.
var on_stage := false
var intro := true  # (false: back from the wax seal screen, everything is already in place)

const ART_DIR := "res://assets/Puppet/UI/Characters/Merchant/"
## The PDF's ground line (the bottom of the cart's wheels) and its anchor: the whole group is scaled about this point and its ground is put on the stage's floor.
const PDF_GROUND := Vector2(1412.0, 706.0)
const SHOP_SCALE := 0.7  # (the cart and the merchant, against the PDF)
const FLOOR_MARGIN := 43.0  # (px above the floor's front edge: nothing hangs over the front wall)
const CART_RECT := Rect2(1064.3, 114.1, 696.0, 655.0)
const WHEEL_BACK_RECT := Rect2(1217.1, 563.3, 142.7, 142.7)  # Layer 1 (the far wheel)
const WHEEL_FRONT_RECT := Rect2(1504.7, 527.9, 178.1, 178.1)  # Layer 2
const MERCHANT_RECT := Rect2(817.7, 267.9, 470.7, 470.7)
const MERCHANT_FEET := 0.9  # (of the picture's height: where his boots are, the pivot of his walk)
const CART_FROM := 900.0  # how far right of its place the cart starts (px): off the screen
const MERCHANT_FROM := 1400.0  # (his whole picture starts off the screen)
const CART_TIME := 4.0
const MERCHANT_TIME := 5.0
const MERCHANT_DELAY := 2.0  # he sets off this long after the cart does
const SPELL_X := [190.0, 470.0, 750.0]  # where the spell cards stand (centre) and the bottom of the Buy buttons (on the floor)
const SPELL_FOOT := [640.0, 640.0, 640.0]
const SPELL_SCALE := 0.8  # (the standing spell cards, against the old shop)
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
const HANG_SCALE := 0.65  # (the artifacts and bottles hang smaller than the old grid's: tune)
const HANG_X0 := 112.0  # centre of the first item
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
var _amber: Label
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
var _hang: Array[Dictionary] = []  # {box, rest: Vector2 (top left), phase, swing, on}
var _arrived := false  # the cart and the merchant are in place
var _intro_done := false  # ... and the goods are laid out: now they can be bought
var _gen := 0
var _ground := 650.0  # where the cart and the merchant stand (the floor's front edge, less the margin)
var _t := 0.0
signal _arrive


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
	if portrait != null:  # Puppet: his round portrait instead of the cart
		var title_row := HBoxContainer.new()
		title_row.add_theme_constant_override("separation", 14)
		portrait.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		title_row.add_child(portrait)
		title_row.add_child(UiTheme.heading("The Merchant", 40, Color.WHITE))
		v.add_child(title_row)
	else:
		v.add_child(UiTheme.heading("🛒 The Merchant", 40, Color.WHITE))
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
func _place_merchant(leave_btn: Control, behind: Control) -> void:
	var t := UiSkin.tex("merchant_full") if UiSkin.tex("merchant_full") != null else UiSkin.tex("merchant_portrait")  # (Puppet: the whole merchant)
	if t == null or not is_instance_valid(leave_btn):
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
		var box := VBoxContainer.new()
		box.add_theme_constant_override("separation", 6)
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
				var art := UiSkin.artifact_icon(a.id, 64)  # New theme: the painted artifact above its name
				if art != null:
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
		var label := "Sold" if sold else ("Bottle slots full" if full else ("Nothing to seal" if none else "Buy · %d Leaves" % it.price))
		var btn := UiTheme.button(label, func(): _buy(i), 18)
		btn.disabled = sold or full or none or run.amber < it.price
		box.add_child(btn)
		_boxes.append(box)
		if on_stage:
			box.set_meta("kind", it.kind)
			if it.kind == "spell":
				box.set_meta("spell", it.spell)
				box.set_meta("buy", label)
				box.set_meta("off", btn.disabled)
			box.modulate.a = 0.0  # (placed once it has its size)
			box.position = Vector2(-4000.0, 0.0)
			(_spell_layer if it.kind == "spell" else _hang_layer).add_child(box)
		else:
			_grid.add_child(box)
	if on_stage:
		_stage_layout.call_deferred(old)
	else:
		_equalize.call_deferred()


## The frame behind a goods panel: on the stage the dark brass-and-wood picture, whole (it shrinks with the panel); else the usual panel.
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
	if not run.pay(it.price):
		return
	Audio.play("shop_buy", -2.0, randf_range(0.97, 1.03))  # (coins; the same for everything bought)
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

## A picture of the art folder placed at `r` (null if it is missing).
func _pic_rect(file: String, r: Rect2, parent: Control) -> TextureRect:
	var t: Texture2D = load(ART_DIR + file) if ResourceLoader.exists(ART_DIR + file) else null
	if t == null:
		return null
	var tr := TextureRect.new()
	tr.texture = t
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_SCALE
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tr.position = r.position
	tr.size = r.size
	tr.pivot_offset = r.size / 2.0
	parent.add_child(tr)
	return tr


func _ready_stage() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE  # (the stage's own buttons stay clickable around the goods)
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
	_hang_layer = _plain_layer()
	_spell_layer = _plain_layer()
	_cart = _plain_layer()
	_pic_rect("Cart.png", CART_RECT, _cart)
	_wheel_back = _pic_rect("Layer 1.png", WHEEL_BACK_RECT, _cart)
	_wheel_front = _pic_rect("Layer 2.png", WHEEL_FRONT_RECT, _cart)
	_merchant = _pic_rect("merchant_full.png", MERCHANT_RECT, _world)
	if _merchant != null:
		_merchant.pivot_offset = Vector2(MERCHANT_RECT.size.x / 2.0, MERCHANT_RECT.size.y * MERCHANT_FEET)
	add_child(_leaves_pill())
	var leave_btn := _leave_button()
	leave_btn.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	leave_btn.offset_left = -320.0
	leave_btn.offset_right = -60.0
	leave_btn.offset_top = -86.0
	leave_btn.offset_bottom = -30.0
	add_child(leave_btn)
	_set_cart_x(CART_FROM if intro else 0.0)
	_set_merchant_x(MERCHANT_FROM if intro else 0.0)
	if intro:
		_arrive_walk()
	else:
		_arrived = true
	_refresh()


## Your Leaves: the painted pill, the coin (the amber leaf) and the number, bottom left.
func _leaves_pill() -> Control:
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
	pill.position = Vector2(48.0, 985.0)
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
	var ph := off * STEP_K
	var stride := int(floorf(ph / PI))
	if stride != _stride:
		if _stride != -1000:
			_step_sound(off)
		_stride = stride
	var feet_pdf := Vector2(MERCHANT_RECT.position.x + MERCHANT_RECT.size.x / 2.0, MERCHANT_RECT.position.y + MERCHANT_RECT.size.y * MERCHANT_FEET)
	var feet := Vector2(PDF_GROUND.x + (feet_pdf.x - PDF_GROUND.x) * SHOP_SCALE + off, _ground - (PDF_GROUND.y - feet_pdf.y) * SHOP_SCALE)
	_merchant.scale = Vector2.ONE * SHOP_SCALE
	_merchant.position = feet - _merchant.pivot_offset + Vector2(0.0, -absf(sin(ph)) * 8.0)
	_merchant.rotation = sin(ph) * 0.035


## One of his boots comes down: quieter while he is far off the screen, the two boot sounds alternate, never quite the same pitch twice.
func _step_sound(off: float) -> void:
	Audio.play("shop_step" if _stride % 2 == 0 else "shop_step_2", -4.0 - 12.0 * clampf(off / 900.0, 0.0, 1.0), randf_range(0.94, 1.06))


## The cart is pulled in, the merchant walks in after it.
func _arrive_walk() -> void:
	Audio.play("shop_cart_roll", -2.0)  # (4.4 s, fading out as the cart slows)
	var tw := create_tween().set_parallel(true)
	tw.tween_method(_set_cart_x, CART_FROM, 0.0, CART_TIME).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.tween_method(_set_merchant_x, MERCHANT_FROM, 0.0, MERCHANT_TIME).set_delay(MERCHANT_DELAY).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	await tw.finished
	_arrived = true
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


## Sizes every new box, puts it in its place and (the first time) plays the arrival of the goods; then the old boxes go.
func _stage_layout(old: Array) -> void:
	_gen += 1
	var gen := _gen
	for _i in 3:
		await get_tree().process_frame  # (the boxes get their sizes)
		if gen != _gen or not is_inside_tree():
			return
	var animate := not _intro_done and intro
	if animate and not _arrived:
		await _arrive
		if gen != _gen or not is_inside_tree():
			return
	var n_spell := 0
	var n_hang := 0
	var spells_total := _boxes.filter(func(x): return is_instance_valid(x) and x.get_meta("kind") == "spell").size()
	var pop_end := POP_START + float(maxi(spells_total - 1, 0)) * POP_GAP + POP_TIME  # (the hanging goods come down after the last card stands)
	var hang_new: Array[Dictionary] = []
	var sh_new: Array[Dictionary] = []
	for b in _boxes:
		if not is_instance_valid(b):
			continue
		b.size = b.get_combined_minimum_size()
		var w: float = b.size.x
		var h: float = b.size.y
		if b.get_meta("kind") == "spell":
			var k := mini(n_spell, SPELL_X.size() - 1)
			var foot: float = SPELL_FOOT[k]
			var rest := Vector2(SPELL_X[k] - w / 2.0, foot - h)  # (its box, unscaled: it is scaled about its bottom edge)
			n_spell += 1
			b.pivot_offset = Vector2(w / 2.0, h)
			b.position = rest
			b.scale = Vector2.ONE * SPELL_SCALE
			var sh := {"cx": SPELL_X[k], "foot": foot, "w": w * SPELL_SCALE, "a": 0.0 if animate else 1.0}
			sh_new.append(sh)
			for c in b.get_children():
				if c is SpellCard and animate:
					c.warm_hover.call_deferred()  # (their magnified copy is made once, unseen, now: not on the first hover)
			if animate:
				b.modulate.a = 0.0  # (a flat picture of it lies there instead, see _pop)
				_pop(b, rest, _floor_stretch(foot), POP_START + float(k) * POP_GAP, sh)
			else:
				b.modulate.a = 1.0
		else:
			var cx := HANG_X0 + n_hang * minf(HANG_DX, HANG_MAX_W / float(maxi(1, _boxes.size() - spells_total)))
			var rest := Vector2(cx - w / 2.0, HANG_ROW_Y[n_hang % 2])
			n_hang += 1
			b.pivot_offset = Vector2(w / 2.0, 0.0)
			b.scale = Vector2.ONE * HANG_SCALE
			b.position = rest
			var d := {"box": b, "rest": rest, "phase": float(n_hang) * 1.9, "swing": 0.0, "on": not animate}
			if animate:
				b.modulate.a = 0.0
				_drop_in(d, pop_end + HANG_START + float(n_hang - 1) * HANG_GAP)
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
		await get_tree().create_timer(pop_end + HANG_START + float(n_hang) * HANG_GAP + HANG_FALL + 1.3).timeout
	_intro_done = true


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
	var btn := UiTheme.button(b.get_meta("buy"), func(): pass, 18)
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
	for d in _hang:
		var b: Control = d.box
		if is_instance_valid(b):
			b.rotation = float(d.swing) * 0.012 * sin(_t * 1.1 + float(d.phase))
	if _ropes != null:
		_ropes.queue_redraw()


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
			for frac in [0.16, 0.84]:
				var end: Vector2 = xf * Vector2(b.size.x * frac, 6.0)
				var top_x: float = rest.x + b.size.x * 0.5 + (b.size.x * frac - b.size.x * 0.5) * ShopScreen.HANG_SCALE
				MapScreen.MapRope.draw_between(self, Vector2(top_x, ShopScreen.ROPE_TOP), end, 0.0, Color.WHITE, RopeRig.ROPE_W)
				var rv := RopeRig._rivet_tex(int(ceil(RopeRig.RIVET_PX)))
				draw_texture(rv, end - rv.get_size() * 0.5)


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
			var fy: float = ground - (ShopScreen.PDF_GROUND.y - (ShopScreen.MERCHANT_RECT.position.y + ShopScreen.MERCHANT_RECT.size.y * ShopScreen.MERCHANT_FEET)) * ShopScreen.SHOP_SCALE
			_floor_shadow(Vector2(m.position.x + m.pivot_offset.x + 14.0, fy), 76.0, 12.0, 0.55)
		for d in shop._spell_sh:
			_floor_shadow(Vector2(d.cx + 12.0, d.foot), d.w * 0.56, 15.0, 0.5 * float(d.a))
		var sb := _box_style()
		for d in shop._hang:
			var b: Control = d.box
			if not is_instance_valid(b) or not d.on:
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
