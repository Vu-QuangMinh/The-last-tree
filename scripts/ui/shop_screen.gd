class_name ShopScreen
extends Control
## The merchant: spend Amber on spells, artifacts, bottles, a wax seal (it seals one Essence of a spell of yours) or a hot meal.

signal leave
signal upgrade_requested
signal quest_changed  # (his favours moved on: save them)

var run: RunState
var stock: Array = []
var quest := {"done": 0, "open": false}  # his favours (see MerchantQuests), shared with the save
var _amber: Label
var _grid: HFlowContainer
var _title_row: HBoxContainer
var _mark: Label  # "!" a favour to ask, "?" one you can hand over: click it (or him) to talk
var _picture: Button  # (once he's drunk) his family picture on the counter
var _dlg: Control  # the conversation box, while it's open
var _dlg_lines: Array = []
var _dlg_choices: Array = []  # [[button text, Callable], ...] under the last line
var _dlg_i := 0
var _dlg_text: Label
var _dlg_row: HBoxContainer


func setup(p_run: RunState, p_stock: Array) -> void:
	run = p_run
	stock = p_stock


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = UiTheme.get_theme()
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
	var leave_btn := UiTheme.button("Leave the shop", func(): leave.emit(), 22)
	leave_btn.custom_minimum_size = Vector2(260, 56)
	if UiSkin.is_puppet():
		UiTheme.use_play_style(leave_btn, true)  # (the orange one, like Continue on the main menu)
		for k in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
			leave_btn.add_theme_color_override(k, Color.WHITE)
		leave_btn.add_theme_color_override("font_outline_color", Color(0.35, 0.16, 0.05))
		leave_btn.add_theme_constant_override("outline_size", 4)
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


## New theme: the merchant himself stands above the Leave button (behind the goods, so they never get covered).
## Click him (or the mark over his head) to talk. Once he's drunk he sits on his chair: his own picture ("merchant_drunk").
func _place_merchant(leave_btn: Control, behind: Control) -> void:
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
func _add_talk(him: TextureRect) -> void:
	_mark = UiTheme.heading("!", 72, Color(1.0, 0.85, 0.2))
	_mark.add_theme_color_override("font_outline_color", Color(0.25, 0.12, 0.02))
	_mark.add_theme_constant_override("outline_size", 10)
	_mark.mouse_filter = Control.MOUSE_FILTER_STOP
	_mark.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_mark.gui_input.connect(_on_talk_click)
	if him != null:
		him.mouse_filter = Control.MOUSE_FILTER_STOP
		him.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		him.tooltip_text = "Talk to the merchant"
		him.gui_input.connect(_on_talk_click)
		_mark.position = Vector2(him.position.x + him.size.x / 2.0 + 40.0, him.position.y - 50.0)  # (by his head, clear of the goods above)
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
			_picture.position = Vector2(him.position.x - 80.0, him.position.y + him.size.y - 90.0)
			add_child(_picture)
		else:
			_title_row.add_child(_picture)
	_update_mark()


func _on_talk_click(ev: InputEvent) -> void:
	if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
		_talk()


func _update_mark() -> void:
	if _mark != null:
		var m := MerchantQuests.mark(quest, run.artifacts, run.merchant_talked == run.room_key())
		_mark.text = m
		_mark.visible = m != ""
	if _picture != null and "family_picture" in run.artifacts:
		_picture.queue_free()
		_picture = null


## Talking to him: one favour a visit, asked for or handed over (see MerchantQuests).
func _talk() -> void:
	if _dlg != null:
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
	if _dlg != null:
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
	_dlg = Control.new()
	_dlg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_dlg.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_dlg)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.45)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_dlg.add_child(dim)
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", UiTheme.panel_box(0.97, 16))
	p.position = Vector2(360, 700)
	p.custom_minimum_size = Vector2(1200, 220)
	_dlg.add_child(p)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 14)
	p.add_child(vb)
	vb.add_child(UiTheme.heading("The Merchant", 28, Color(1, 0.85, 0.45)))
	_dlg_text = UiTheme.label("", 24, Color.WHITE)
	_dlg_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_dlg_text.custom_minimum_size = Vector2(1160, 0)
	vb.add_child(_dlg_text)
	_dlg_row = HBoxContainer.new()
	_dlg_row.alignment = BoxContainer.ALIGNMENT_END
	_dlg_row.add_theme_constant_override("separation", 16)
	vb.add_child(_dlg_row)
	_dialog_step()


func _dialog_step() -> void:
	_dlg_text.text = String(_dlg_lines[_dlg_i])
	for c in _dlg_row.get_children():
		c.queue_free()
	if _dlg_i < _dlg_lines.size() - 1:
		_dlg_row.add_child(UiTheme.button("Next", _dialog_next, 20))
		return
	if _dlg_choices.is_empty():
		_dlg_row.add_child(UiTheme.button("Goodbye", _close_dialog, 20))
		return
	for ch in _dlg_choices:
		_dlg_row.add_child(UiTheme.button(String(ch[0]), ch[1], 20))


func _dialog_next() -> void:
	_dlg_i += 1
	_dialog_step()


func _close_dialog() -> void:
	if _dlg != null:
		_dlg.queue_free()
		_dlg = null
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
	_amber.text = "You have %d Leaves" % run.amber
	for c in _grid.get_children():
		c.queue_free()
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
				p.add_theme_stylebox_override("panel", UiTheme.panel_box(0.95, 12))
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
				p.add_theme_stylebox_override("panel", UiTheme.panel_box(0.95, 12))
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
				p.add_theme_stylebox_override("panel", UiTheme.panel_box(0.95, 12))
				p.custom_minimum_size = Vector2(SpellCard.W, SpellCard.H)
				var l := UiTheme.label("🌼 Mend the Seed of Life\n\nThe badger seals its cracks: your second chance is back.", 19, Color(0.75, 1.0, 0.6))
				l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
				l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
				p.add_child(l)
				box.add_child(p)
			"upgrade", "heal":
				var p := PanelContainer.new()
				p.add_theme_stylebox_override("panel", UiTheme.panel_box(0.95, 12))
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
		var label := "Sold" if sold else ("Bottle slots full" if full else ("Nothing to seal" if none else ("Take · free" if price == 0 else "Buy · %d Leaves" % price)))
		var btn := UiTheme.button(label, func(): _buy(i), 18)
		btn.disabled = sold or full or none or run.amber < price
		box.add_child(btn)
		_boxes.append(box)
		_grid.add_child(box)
	_equalize.call_deferred()


func _centered(l: Label) -> Label:
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return l


func _buy(i: int) -> void:
	var it: Dictionary = stock[i]
	if it.get("sold", false):
		return
	if it.kind == "bottle" and run.player.bottles.size() >= run.bottle_slots():
		return
	if not run.pay(run.shop_price(it)):
		return
	run.free_pick.erase(it.kind)  # (his thanks for a favour: one free, then the usual prices)
	match it.kind:
		"spell":
			run.learn_spell(it.spell.id)
			Audio.play("discovery_unlock")
			Events.toast.emit("Learned %s" % it.spell.name, UiTheme.ACCENT)
			it.sold = true
		"artifact":
			run.gain_artifact(it.artifact.id)
			Audio.play("artifact_get")
			Events.toast.emit("Got %s" % it.artifact.name, UiTheme.ACCENT)
			it.sold = true
		"bottle":
			run.gain_bottle(it.bottle)
			Audio.play("artifact_get")
			Events.toast.emit("Got %s %s" % [UiSkin.icon_token(it.bottle, Bottles.get_def(it.bottle).icon), Bottles.get_def(it.bottle).name], UiTheme.ACCENT)
			it.sold = true
		"mend_seed":
			run.mend_seed()
			Audio.play("artifact_get")
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
