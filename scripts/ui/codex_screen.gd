class_name CodexScreen
extends Control
## Every enemy. Ones you've defeated show their Essence, passives and full move list; the rest are silhouettes.

signal closed


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
	v.add_child(top)
	var known := EnemyDefs.E.keys().filter(func(id): return SaveManager.in_codex(id)).size()
	var t := UiTheme.heading("Codex  ·  %d / %d enemies recorded" % [known, EnemyDefs.E.size()], 34, Color.WHITE)
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(t)
	top.add_child(UiTheme.button(UiTheme.hk("Close", "Esc"), func(): closed.emit(), 20))
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(1840, 960)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	v.add_child(scroll)
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 14)
	grid.add_theme_constant_override("v_separation", 14)
	scroll.add_child(grid)
	var sections := [["Act I", 1, "normal"], ["Act II", 2, "normal"], ["Act III", 3, "normal"], ["Elites", 0, "elite"], ["Bosses", 0, "boss"]]
	for sec in sections:
		var ids := EnemyDefs.E.keys().filter(func(id):
			var d: Dictionary = EnemyDefs.E[id]
			match sec[2]:
				"elite":
					return d.get("elite", false)
				"boss":
					return d.get("boss", false)
			return d.act == sec[1] and not d.get("elite", false) and not d.get("boss", false))
		for i in 3:
			var h := UiTheme.label(sec[0] if i == 0 else "", 24, UiTheme.ACCENT)
			grid.add_child(h)
		for id in ids:
			grid.add_child(_entry(id))
		for i in (3 - ids.size() % 3) % 3:
			grid.add_child(Control.new())


func _entry(id: String) -> Control:
	var d := EnemyDefs.get_def(id)
	var known := SaveManager.in_codex(id)
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", UiTheme.panel_box(0.9, 10))
	p.custom_minimum_size = Vector2(600, 190)
	var h := HBoxContainer.new()
	p.add_child(h)
	var e := EnemyState.new()
	e.setup(d)
	var cr := Creature.new()
	cr.setup(e)
	cr.dead = not known
	cr.custom_minimum_size = Vector2(150, 170)
	h.add_child(cr)
	var v := VBoxContainer.new()
	v.custom_minimum_size = Vector2(420, 0)
	h.add_child(v)
	if not known:
		v.add_child(UiTheme.label("???", 24, UiTheme.MUTED))
		v.add_child(UiTheme.label("Defeat it to record it here.", 16, UiTheme.MUTED))
		return p
	v.add_child(UiTheme.label(d.name, 22, Color.WHITE))
	var hp := HFlowContainer.new()
	for c in d.hp:
		hp.add_child(ElementIcon.make(c, 24))
	v.add_child(hp)
	var lines := []
	for ps in d.get("passives", []):
		lines.append(EnemyDefs.PASSIVE_TEXT[ps])
	lines.append("Moves: " + " → ".join(d.moves.map(func(m): return EnemyDefs.describe_move(m))))
	if d.has("moves2"):
		lines.append("Below half Essence: " + " → ".join(d.moves2.map(func(m): return EnemyDefs.describe_move(m))))
	lines.append("\"%s\"" % d.get("flavor", ""))
	var t := UiTheme.label("\n".join(lines), 15, UiTheme.MUTED)
	t.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	t.custom_minimum_size = Vector2(420, 0)
	v.add_child(t)
	return p


func _unhandled_input(ev: InputEvent) -> void:
	if ev is InputEventKey and ev.pressed and ev.keycode == KEY_ESCAPE:
		closed.emit()
		get_viewport().set_input_as_handled()
