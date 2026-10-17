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
	# every artifact you've unlocked (the Magic Box can be played here)
	var arts: Array = Artifacts.ALL.filter(func(x): return x.id in SaveManager.unlocked_artifacts())
	for i in 3:
		grid.add_child(UiTheme.label("Artifacts" if i == 0 else "", 24, UiTheme.ACCENT))
	for a in arts:
		grid.add_child(_artifact_entry(a))
	for i in (3 - arts.size() % 3) % 3:
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
	lines.append("Moves: " + " → ".join(d.moves.map(func(m): return EnemyDefs.describe_move(m, 0, true)).filter(func(t): return t != "")))
	if d.has("moves2"):
		lines.append("Below half Essence: " + " → ".join(d.moves2.map(func(m): return EnemyDefs.describe_move(m))))
	lines.append("\"%s\"" % d.get("flavor", ""))
	var t := UiTheme.label("\n".join(lines), 15, UiTheme.MUTED)
	t.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	t.custom_minimum_size = Vector2(420, 0)
	v.add_child(t)
	return p


func _artifact_entry(a: Dictionary) -> Control:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", UiTheme.panel_box(0.9, 10))
	p.custom_minimum_size = Vector2(600, 150)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	p.add_child(v)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 10)
	var art := UiSkin.artifact_icon(a.id, 40)
	head.add_child(art if art != null else UiTheme.label(String(a.get("icon", "◆")), 30, Color.WHITE))
	head.add_child(UiTheme.label(a.name, 22, Color(1, 0.85, 0.5)))
	v.add_child(head)
	var d := UiTheme.label(a.desc, 15, UiTheme.MUTED)
	d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	d.custom_minimum_size = Vector2(560, 0)
	v.add_child(d)
	if a.has("flavor"):
		var fl := UiTheme.label("\"%s\"" % a.flavor, 15, Color(0.8, 0.75, 0.65))
		fl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		fl.custom_minimum_size = Vector2(560, 0)
		v.add_child(fl)
	if a.id == "magic_box":
		v.add_child(_magic_box())
	return p


## The Magic Box: six coloured buttons, each a note. Play the opening of Fur Elise on them and a row of six coloured
## squares appears under it (the colours in the order the tune first plays them), and stays.
const BOX_KEYS := [["red", Color(0.85, 0.2, 0.18), "B"], ["green", Color(0.25, 0.7, 0.3), "E"], ["white", Color(0.95, 0.95, 0.92), "A"],
	["black", Color(0.08, 0.08, 0.1), "Ds"], ["blue", Color(0.2, 0.45, 0.9), "C"], ["yellow", Color(0.95, 0.82, 0.2), "D"]]
const BOX_TUNE := ["E", "Ds", "E", "Ds", "E", "B", "D", "C", "A"]  # (the first bar of Fur Elise)
var _box_played: Array = []


func _magic_box() -> Control:
	var col := VBoxContainer.new()
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	col.add_child(row)
	var code := HBoxContainer.new()
	code.add_theme_constant_override("separation", 4)
	col.add_child(code)
	var show_code := func() -> void:
		for c in code.get_children():
			c.queue_free()
		var order: Array = []
		for n in BOX_TUNE:
			if not (n in order):
				order.append(n)
		for n in order:
			for k in BOX_KEYS:
				if k[2] == n:
					var sq := ColorRect.new()
					sq.color = k[1]
					sq.custom_minimum_size = Vector2(26, 26)
					code.add_child(sq)
	if SaveManager.setting("box_solved", false):
		show_code.call()
	for k in BOX_KEYS:
		var b := Button.new()
		b.custom_minimum_size = Vector2(52, 34)
		var sb := StyleBoxFlat.new()
		sb.bg_color = k[1]
		sb.set_corner_radius_all(6)
		sb.set_border_width_all(2)
		sb.border_color = Color(0.25, 0.18, 0.1)
		b.add_theme_stylebox_override("normal", sb)
		var hov := sb.duplicate()
		hov.bg_color = (k[1] as Color).lightened(0.2)
		b.add_theme_stylebox_override("hover", hov)
		b.add_theme_stylebox_override("pressed", hov)
		b.tooltip_text = k[0]
		var note: String = k[2]
		b.pressed.connect(func():
			Audio.play("box_note_" + note)
			_box_played.append(note)
			if _box_played.size() > BOX_TUNE.size():
				_box_played.pop_front()
			if _box_played == BOX_TUNE and not SaveManager.setting("box_solved", false):
				SaveManager.set_setting("box_solved", true)
				Audio.play("discovery_unlock")
				show_code.call())
		row.add_child(b)
	return col


func _unhandled_input(ev: InputEvent) -> void:
	if ev is InputEventKey and ev.pressed and ev.keycode == KEY_ESCAPE:
		closed.emit()
		get_viewport().set_input_as_handled()
