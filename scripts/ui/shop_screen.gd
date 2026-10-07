class_name ShopScreen
extends Control
## The merchant: spend Amber on spells, artifacts, bottles, a wax seal (it seals one Essence of a spell of yours) or a hot meal.

signal leave
signal upgrade_requested

var run: RunState
var stock: Array = []
var _amber: Label
var _grid: HFlowContainer


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
	v.add_child(UiTheme.heading("🛒 The Merchant", 40, Color.WHITE))
	v.add_child(UiTheme.label("A badger with a very large backpack. \"Everything's for sale, friend. Even the backpack. Not the badger.\"", 20, UiTheme.MUTED))
	_amber = UiTheme.label("", 26, Color(1, 0.8, 0.35))
	v.add_child(_amber)
	_grid = HFlowContainer.new()
	_grid.add_theme_constant_override("h_separation", 26)
	_grid.add_theme_constant_override("v_separation", 22)
	_grid.custom_minimum_size = Vector2(1800, 0)
	v.add_child(_grid)
	var bottom := HBoxContainer.new()
	bottom.add_theme_constant_override("separation", 16)
	bottom.size_flags_horizontal = Control.SIZE_SHRINK_END
	v.add_child(bottom)
	var leave_btn := UiTheme.button("Leave the shop", func(): leave.emit(), 22)
	leave_btn.custom_minimum_size = Vector2(260, 56)
	bottom.add_child(leave_btn)
	var hud := HudBar.new()
	hud.setup(run)
	add_child(hud)
	_place_merchant.call_deferred(leave_btn, v)
	_refresh()


## New theme: the merchant himself stands above the Leave button (behind the goods, so they never get covered).
func _place_merchant(leave_btn: Control, behind: Control) -> void:
	var t := UiSkin.tex("merchant_portrait")
	if t == null or not is_instance_valid(leave_btn):
		return
	await get_tree().process_frame
	var r := TextureRect.new()
	r.texture = t
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var h := 340.0
	r.size = Vector2(h * t.get_width() / t.get_height(), h)
	var lb := leave_btn.get_global_rect()
	r.position = Vector2(lb.end.x - r.size.x, lb.position.y - r.size.y - 4.0) - global_position
	add_child(r)
	move_child(r, behind.get_index())  # just under the goods

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
				box.add_child(SpellCard.make(it.spell))
				var gap := Control.new()  # a card can't stretch: this soaks up the extra height so the Buy button stays level
				gap.size_flags_vertical = Control.SIZE_EXPAND_FILL
				box.add_child(gap)
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
				var art := UiSkin.icon("wax_seal" if it.kind == "upgrade" else "hot_meal", 72)  # New theme: painted art, once it exists
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
	if not run.pay(it.price):
		return
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
