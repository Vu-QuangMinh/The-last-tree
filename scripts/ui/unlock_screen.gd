class_name UnlockScreen
extends Control
## Spend Seedlings to add spells and artifacts to the pool that runs can offer you.

signal closed

var _body: HFlowContainer
var _title: Label
var _seed_row: HBoxContainer  # New theme: the painted Seedling and the count, beside the title
var _seed_count: Label
var _tab := "spells"


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = UiTheme.get_theme()
	mouse_filter = Control.MOUSE_FILTER_STOP
	var bg := ColorRect.new()
	bg.color = Color(0.03, 0.05, 0.04, 0.97)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var v := VBoxContainer.new()
	v.position = Vector2(40, 24)
	v.size = Vector2(1840, 1030)
	v.add_theme_constant_override("separation", 12)
	add_child(v)
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 16)
	v.add_child(top)
	_title = UiTheme.heading("", 32, Color.WHITE)
	_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(_title)
	var seed_art := UiSkin.icon("icon_seedling", 40)
	if seed_art != null:
		_title.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		_seed_row = HBoxContainer.new()
		_seed_row.add_theme_constant_override("separation", 8)
		_seed_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_seed_row.add_child(seed_art)
		_seed_count = UiTheme.heading("", 32, Color.WHITE)
		_seed_row.add_child(_seed_count)
		top.add_child(_seed_row)
	top.add_child(UiTheme.button("Spells", func(): _tab = "spells"; _refresh(), 20))
	top.add_child(UiTheme.button("Artifacts", func(): _tab = "artifacts"; _refresh(), 20))
	top.add_child(UiTheme.button(UiTheme.hk("Close", "Esc"), func(): closed.emit(), 20))
	v.add_child(UiTheme.label("Unlocked spells and artifacts can show up as rewards in future runs.", 17, UiTheme.MUTED))
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(1840, 920)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	v.add_child(scroll)
	_body = HFlowContainer.new()
	_body.custom_minimum_size = Vector2(1820, 0)
	_body.add_theme_constant_override("h_separation", 12)
	_body.add_theme_constant_override("v_separation", 12)
	scroll.add_child(_body)
	_refresh()


func _refresh() -> void:
	if _seed_row != null:
		_title.text = "Unlocks  ·"
		_seed_count.text = "%d Seedlings" % SaveManager.data.seedlings
	else:
		_title.text = "Unlocks  ·  ✿ %d Seedlings" % SaveManager.data.seedlings
	for c in _body.get_children():
		c.queue_free()
	if _tab == "spells":
		var locked := GameData.db.all_spells.filter(func(s): return not SaveManager.is_unlocked(s.id))
		locked.sort_custom(func(a, b): return SaveManager.spell_cost(a) < SaveManager.spell_cost(b))
		if locked.is_empty():
			_body.add_child(UiTheme.label("Every spell is unlocked.", 22))
		for s in locked:
			var box := VBoxContainer.new()
			box.add_child(SpellCard.make(s))
			var cost := SaveManager.spell_cost(s)
			var b := UiTheme.button("Unlock  ✿ %d" % cost, func():
				if SaveManager.buy_spell(s):
					Audio.play("discovery_unlock")
					Events.toast.emit("%s unlocked" % s.name, UiTheme.ACCENT)
				_refresh.call_deferred())
			b.disabled = SaveManager.data.seedlings < cost
			UiSkin.seedling_button(b, "Unlock  %d" % cost, b.text)
			box.add_child(b)
			_body.add_child(box)
	else:
		var unlocked := SaveManager.unlocked_artifacts()
		for a in Artifacts.ALL:
			var p := PanelContainer.new()
			p.add_theme_stylebox_override("panel", UiTheme.panel_box(0.9, 10))
			p.custom_minimum_size = Vector2(440, 150)
			var v := VBoxContainer.new()
			p.add_child(v)
			var art := UiSkin.artifact_icon(a.id, 44)  # New theme: the painted artifact beside its name
			if art != null:
				var head := HBoxContainer.new()
				head.add_theme_constant_override("separation", 10)
				head.add_child(art)
				var nm := UiTheme.label(a.name, 22, Color(1, 0.85, 0.5))
				nm.size_flags_vertical = Control.SIZE_SHRINK_CENTER
				head.add_child(nm)
				v.add_child(head)
			else:
				v.add_child(UiTheme.label("◆ " + a.name, 22, Color(1, 0.85, 0.5)))
			var d := UiTheme.label(a.desc, 16, UiTheme.MUTED)
			d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			v.add_child(d)
			if a.id in unlocked:
				v.add_child(UiTheme.label("Unlocked", 16, UiTheme.ACCENT))
			else:
				var b := UiTheme.button("Unlock  ✿ %d" % a.cost, func():
					if SaveManager.buy_artifact(a.id):
						Audio.play("artifact_get")
						Events.toast.emit("%s unlocked" % a.name, UiTheme.ACCENT)
					_refresh.call_deferred())
				b.disabled = SaveManager.data.seedlings < a.cost
				UiSkin.seedling_button(b, "Unlock  %d" % a.cost, b.text)
				v.add_child(b)
			_body.add_child(p)


func _unhandled_input(ev: InputEvent) -> void:
	if ev is InputEventKey and ev.pressed and ev.keycode == KEY_ESCAPE:
		closed.emit()
		get_viewport().set_input_as_handled()
