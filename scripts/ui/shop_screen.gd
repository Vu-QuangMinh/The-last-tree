class_name ShopScreen
extends Control
## The merchant: spend Amber on spells, artifacts, bottles, an upgrade (a wax seal) or a hot meal.

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
	v.add_child(UiTheme.label("🛒 The Merchant", 40, Color.WHITE))
	v.add_child(UiTheme.label("A badger with a very large backpack. \"Everything's for sale, friend. Even the backpack. Not the badger.\"", 20, UiTheme.MUTED))
	_amber = UiTheme.label("", 26, Color(1, 0.8, 0.35))
	v.add_child(_amber)
	_grid = HFlowContainer.new()
	_grid.add_theme_constant_override("h_separation", 26)
	_grid.add_theme_constant_override("v_separation", 22)
	_grid.custom_minimum_size = Vector2(1800, 0)
	v.add_child(_grid)
	var leave_btn := UiTheme.button("Leave the shop", func(): leave.emit(), 22)
	leave_btn.custom_minimum_size = Vector2(260, 56)
	leave_btn.size_flags_horizontal = Control.SIZE_SHRINK_END
	v.add_child(leave_btn)
	var hud := HudBar.new()
	hud.setup(run)
	add_child(hud)
	_refresh()


func _refresh() -> void:
	_amber.text = "You have %d Amber" % run.amber
	for c in _grid.get_children():
		c.queue_free()
	for i in stock.size():
		var it: Dictionary = stock[i]
		var box := VBoxContainer.new()
		box.add_theme_constant_override("separation", 6)
		match it.kind:
			"spell":
				box.add_child(SpellCard.make(it.spell))
			"artifact":
				var a: Dictionary = it.artifact
				var p := PanelContainer.new()
				p.add_theme_stylebox_override("panel", UiTheme.panel_box(0.95, 12))
				p.custom_minimum_size = Vector2(SpellCard.W, SpellCard.H)
				var l := UiTheme.label("◆ %s\n%s · %s\n\n%s" % [a.name, Artifacts.TIER_NAMES[a.tier].to_upper(), a.aspect, a.desc], 18, Color(0.6, 0.8, 1) if a.tier == "rare" else Color(1, 0.88, 0.6))
				l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
				l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
				p.add_child(l)
				box.add_child(p)
			"bottle":
				var b := Bottles.get_def(it.bottle)
				var p := PanelContainer.new()
				p.add_theme_stylebox_override("panel", UiTheme.panel_box(0.95, 12))
				p.custom_minimum_size = Vector2(SpellCard.W, SpellCard.H)
				var bv := VBoxContainer.new()
				bv.alignment = BoxContainer.ALIGNMENT_CENTER
				p.add_child(bv)
				var ic := UiTheme.label(b.icon, 52, Color.WHITE)
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
				box.add_child(p)
			"upgrade", "heal":
				var p := PanelContainer.new()
				p.add_theme_stylebox_override("panel", UiTheme.panel_box(0.95, 12))
				p.custom_minimum_size = Vector2(SpellCard.W, SpellCard.H)
				var txt := "🟣 Wax seal\n\nSeal one Essence of a spell's pattern: that Essence isn't needed any more." if it.kind == "upgrade" else "🍲 A hot meal\n\nHeal %d HP." % int(run.player.max_hp * RunState.REST_HEAL)
				var l := UiTheme.label(txt, 19, Color(0.85, 1, 0.8))
				l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
				l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
				p.add_child(l)
				box.add_child(p)
		var sold: bool = it.get("sold", false)
		var full: bool = it.kind == "bottle" and run.player.bottles.size() >= run.bottle_slots()
		var none: bool = it.kind == "upgrade" and run.upgradable().is_empty()
		var label := "Sold" if sold else ("Bottle slots full" if full else ("Nothing to seal" if none else "Buy · %d Amber" % it.price))
		var btn := UiTheme.button(label, func(): _buy(i), 18)
		btn.disabled = sold or full or none or run.amber < it.price
		box.add_child(btn)
		_grid.add_child(box)


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
			Events.toast.emit("Got %s %s" % [Bottles.get_def(it.bottle).icon, Bottles.get_def(it.bottle).name], UiTheme.ACCENT)
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
