class_name SfxTestScreen
extends Control
## SFX Test (Dev Mode): tabs for the groups of sounds (Spell Card, Spell SFX: what spells do, shared by many cards). Each spell card is listed with 4 play buttons under it, one for each sample the
## sound generator made (tools/make_spell_sfx.py keeps them in assets/Puppet/SFX/_Candidates/polished/). Clicking a sample plays it, turns its button orange and
## makes it the card's official sound (it is copied over assets/Puppet/SFX/Spell Card SFX/spell_<id>.wav, and plays in the game at once).
## Clicking the orange one again leaves no sample chosen: that card's sound has to be redone (the sound stays as it is meanwhile). Clicking the card turns it over:
## on its back you write why the sound has to be redone (kept in docs/sfx_redo_notes.json, next to the choices in _Candidates/chosen.json, -1 = to redo).

signal back

const SFX_DIR := "res://assets/Puppet/SFX/"
const GROUPS := ["Spell Card", "Spell SFX"]
const ORANGE := Color(1.0, 0.55, 0.12)
const CARD_ZOOM := 0.62
const SAMPLES := 4

var _tab := 0
var _search: LineEdit
var _body: Control
var _tab_buttons: Array = []
var _tiles := {}  # spell id -> tile (Control)
var _buttons := {}  # spell id -> [Button x4]
var _chosen := {}  # spell id -> number of the official sample (-1: none, it has to be redone)
var _notes := {}  # spell id -> why it has to be redone
var _names := {}  # key -> the card's / group's name
var _faces := {}  # spell id -> {holder, card, back, edit, mark, busy}
var _player: AudioStreamPlayer
var _note: Label


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = UiTheme.get_theme()
	var bg := ColorRect.new()
	bg.color = Color(0.07, 0.06, 0.05)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	_player = AudioStreamPlayer.new()
	add_child(_player)
	_chosen = _read_chosen()
	_notes = _read_notes()
	var root := VBoxContainer.new()
	root.position = Vector2(30, 20)
	root.size = Vector2(1860, 1040)
	root.add_theme_constant_override("separation", 10)
	add_child(root)
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 14)
	root.add_child(top)
	top.add_child(UiTheme.heading("SFX Test", 32, UiTheme.ACCENT))
	for k in GROUPS.size():
		var b := UiTheme.button(GROUPS[k], func(): _show_tab(k), 22)
		b.toggle_mode = true
		b.custom_minimum_size = Vector2(180, 46)
		top.add_child(b)
		_tab_buttons.append(b)
	_search = LineEdit.new()
	_search.placeholder_text = "search a card"
	_search.custom_minimum_size = Vector2(300, 0)
	_search.text_changed.connect(func(_t: String): _apply_filter())
	top.add_child(_search)
	_note = UiTheme.label("click a sample: it plays and becomes the card's official sound (orange = official)", 17, UiTheme.MUTED)
	_note.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(_note)
	top.add_child(UiTheme.button("Main menu", func(): back.emit(), 20))
	_body = Control.new()
	_body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_body.custom_minimum_size = Vector2(1860, 960)
	root.add_child(_body)
	_show_tab(0)


func _show_tab(k: int) -> void:
	_tab = k
	for i in _tab_buttons.size():
		_tab_buttons[i].set_pressed_no_signal(i == k)
		_tab_buttons[i].modulate = Color.WHITE if i == k else Color(0.6, 0.6, 0.6)
	for c in _body.get_children():
		c.queue_free()
	_tiles.clear()
	_buttons.clear()
	_faces.clear()
	match GROUPS[k]:
		"Spell Card":
			_build_spell_cards()
		"Spell SFX":
			_build_effect_groups()


func _candidates_dir() -> String:
	return ProjectSettings.globalize_path(SFX_DIR + "_Candidates/")


func _read_chosen() -> Dictionary:
	var path := _candidates_dir() + "chosen.json"
	if not FileAccess.file_exists(path):
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return parsed if parsed is Dictionary else {}


func _write_chosen() -> void:
	var f := FileAccess.open(_candidates_dir() + "chosen.json", FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(_chosen, " ", true))


func _notes_path() -> String:
	return ProjectSettings.globalize_path("res://docs/sfx_redo_notes.json")


func _read_notes() -> Dictionary:
	if not FileAccess.file_exists(_notes_path()):
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(_notes_path()))
	return parsed if parsed is Dictionary else {}


func _write_notes() -> void:
	var clean := {}
	for id in _notes:
		if String(_notes[id]).strip_edges() != "":
			clean[id] = _notes[id]
	var f := FileAccess.open(_notes_path(), FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(clean, " ", true))


## Where the official sound of a card (spell id) or of an effect group ("fx_<group>") is, and the name the game plays it by.
func _official_path(key: String) -> String:
	if key.begins_with("fx_"):
		return ProjectSettings.globalize_path(SFX_DIR + "Spell SFX/spellfx_%s.wav" % key.trim_prefix("fx_"))
	return ProjectSettings.globalize_path(SFX_DIR + "Spell Card SFX/spell_%s.wav" % key)


func _sound_name(key: String) -> String:
	return "spellfx_" + key.trim_prefix("fx_") if key.begins_with("fx_") else "spell_" + key


func _name_of(key: String) -> String:
	return String(_names.get(key, key))


func _sample_path(id: String, n: int) -> String:
	return _candidates_dir() + "polished/%s_%d.wav" % [id, n]


func _build_spell_cards() -> void:
	var items: Array = []
	for s in GameData.db.all_spells:
		items.append({"key": s.id, "name": s.name, "spell": s})
	_build_tiles(items)


## The effect groups (Burn, Shield, Heal ...): a plain panel with the group's name and what its sound is meant to be, in place of a card.
func _build_effect_groups() -> void:
	var items: Array = []
	for g in EFFECT_GROUPS:
		items.append({"key": "fx_" + g[0], "name": g[1], "text": g[2]})
	_build_tiles(items)


## [group id, name, what it sounds like] -- the same groups as FX in tools/spell_sfx_prompts.py.
const EFFECT_GROUPS := [
	["remove_essence", "Remove Essence", "sharp magical hit knocking a glass bead off"],
	["magic_bolt", "Magic Bolt", "a single quick arcane bolt (each shot of a volley)"],
	["snipe", "Snipe", "precise sniper shot"],
	["burn", "Burn", "flame igniting"],
	["stoke", "Double Burn", "flames flaring up doubled"],
	["weaken", "Weaken", "drained descending sigh"],
	["vulnerable", "Vulnerable", "brittle shell cracking"],
	["freeze", "Freeze", "freezing crackle, ice forming"],
	["daze", "Dazed", "dizzy ringing, woozy swirl"],
	["ethereal", "Ethereal", "ghostly shimmer, phasing whoosh"],
	["shield", "Shield", "magic shield forming"],
	["lasting_shield", "Lasting Shield", "heavy lasting barrier, deep hum"],
	["thorns", "Thorns", "thorny vines sprouting"],
	["evasion", "Evasion", "quick dodge swish"],
	["heal", "Heal", "warm healing chime"],
	["cleanse", "Cleanse", "bright cleansing sparkle"],
	["repaint", "Repaint", "wet paint brush stroke and splash"],
	["self_repaint", "Self-Repaint", "soft paint swish over own beads"],
	["infuse", "Infuse", "essence poured in, bubbling drop"],
	["rearrange", "Rearrange", "wooden beads sliding and swapping"],
	["duplicate", "Duplicate", "magical copy echo, double chime"],
	["conjure", "Conjure", "a spell conjured from nothing"],
	["steal", "Steal", "quick snatch, small pop"],
	["execute", "Execute", "final executioner blow"],
	["purge", "Purge Essence", "sweeping vacuum, big wipe"],
	["transmute", "Transmute", "alchemical transformation"],
	["gain_essence", "Gain Essence", "glowing orb appearing"],
	["lose_hp", "Lose HP", "dark sacrifice, heartbeat thump"],
	["max_hp", "Max HP", "vitality swell, rising chime"],
	["amplify", "Amplify", "power surge, rising hum"],
	["break_armour", "Break Armour", "armour breaking apart"],
	["seal", "Seal", "magic lock sealing, wax stamp"],
	["power", "Power", "passive power pulse"],
	["refund", "Refund", "coin returned, quick rewind"],
	["curse", "Curse", "dark curse whisper"],
]


## The tiles of a tab: each has a face (a card, or a plain panel), the 4 play buttons under it, and a back to write the reason for a redo on.
func _build_tiles(items: Array) -> void:
	if not items.any(func(i): return FileAccess.file_exists(_sample_path(i.key, 0))):
		var l := UiTheme.label("No samples here yet (run tools/make_spell_sfx.py).", 22, UiTheme.MUTED)
		_body.add_child(l)
		return
	var scroll := ScrollContainer.new()
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_body.add_child(scroll)
	var flow := HFlowContainer.new()
	flow.custom_minimum_size = Vector2(1830, 0)
	flow.add_theme_constant_override("h_separation", 12)
	flow.add_theme_constant_override("v_separation", 14)
	scroll.add_child(flow)
	for item in items:
		var id: String = item.key
		if not FileAccess.file_exists(_sample_path(id, 0)):
			continue
		_names[id] = String(item.name)
		var tile := VBoxContainer.new()
		tile.add_theme_constant_override("separation", 3)
		tile.set_meta("name", String(item.name).to_lower())
		var card: Control
		if item.has("spell"):
			var sc := SpellCard.make(item.spell)
			sc.zoom = CARD_ZOOM
			card = sc
		else:
			card = _effect_face(String(item.name), String(item.text))
		card.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var holder := Control.new()  # (the card and its back, one over the other: clicking turns it over)
		holder.custom_minimum_size = Vector2(SpellCard.W, SpellCard.H) * CARD_ZOOM
		holder.add_child(card)
		var catcher := Control.new()  # (over the card, whose own pieces would swallow the click: it takes it and turns the card over)
		catcher.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		catcher.mouse_filter = Control.MOUSE_FILTER_STOP
		catcher.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		catcher.tooltip_text = "click: turn the card over and write why its sound has to be redone"
		catcher.gui_input.connect(func(ev: InputEvent):
			if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
				_flip(id))
		holder.add_child(catcher)
		var back := _make_back(id, String(item.name), holder.custom_minimum_size)
		back.visible = false
		holder.add_child(back)
		var mark := Label.new()
		mark.position = Vector2(4, 2)
		mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
		mark.add_theme_font_size_override("font_size", 15)
		mark.add_theme_color_override("font_color", Color(1, 0.3, 0.25))
		mark.add_theme_color_override("font_outline_color", Color.BLACK)
		mark.add_theme_constant_override("outline_size", 5)
		holder.add_child(mark)
		tile.add_child(holder)
		_faces[id] = {"holder": holder, "card": card, "catcher": catcher, "back": back, "mark": mark, "busy": false}
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 3)
		var bs: Array = []
		for n in SAMPLES:
			var b := Button.new()
			b.text = "▶ %d" % (n + 1)
			b.focus_mode = Control.FOCUS_NONE
			b.custom_minimum_size = Vector2(SpellCard.W * CARD_ZOOM / SAMPLES - 3.0, 32)
			b.add_theme_font_size_override("font_size", 15)
			b.pressed.connect(func(): _clicked(id, n))
			row.add_child(b)
			bs.append(b)
		tile.add_child(row)
		flow.add_child(tile)
		_tiles[id] = tile
		_buttons[id] = bs
		_paint_buttons(id)
	_apply_filter()


## The face of an effect group: a plain painted board with its name and what its sound is meant to be.
func _effect_face(title: String, text: String) -> Control:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(SpellCard.W, SpellCard.H) * CARD_ZOOM
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.16, 0.2, 0.26)
	sb.border_color = Color(0.55, 0.65, 0.8)
	sb.set_border_width_all(3)
	sb.set_corner_radius_all(8)
	sb.set_content_margin_all(8)
	panel.add_theme_stylebox_override("panel", sb)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	panel.add_child(v)
	var h := UiTheme.label(title, 19, Color(1, 0.9, 0.6))
	h.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(h)
	var d := UiTheme.label(text, 14, Color(0.85, 0.88, 0.92))
	d.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(d)
	return panel


## The back of a card: a plain wooden board with a text box for why the sound has to be redone.
func _make_back(id: String, spell_name: String, size: Vector2) -> Control:
	var panel := PanelContainer.new()
	panel.size = size
	panel.custom_minimum_size = size
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.2, 0.13, 0.08)
	sb.border_color = Color(0.8, 0.5, 0.2)
	sb.set_border_width_all(3)
	sb.set_corner_radius_all(8)
	sb.set_content_margin_all(5)
	panel.add_theme_stylebox_override("panel", sb)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 3)
	panel.add_child(v)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 2)
	v.add_child(head)
	var title := UiTheme.label("%s: redo?" % spell_name, 14, Color(1, 0.85, 0.5))
	title.autowrap_mode = TextServer.AUTOWRAP_OFF
	title.clip_text = true
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	var turn := Button.new()
	turn.text = "↩"
	turn.tooltip_text = "turn the card back over"
	turn.focus_mode = Control.FOCUS_NONE
	turn.custom_minimum_size = Vector2(30, 24)
	turn.add_theme_font_size_override("font_size", 14)
	turn.pressed.connect(func(): _flip(id))
	head.add_child(turn)
	var edit := TextEdit.new()
	edit.placeholder_text = "why does this sound have to be redone?"
	edit.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	edit.size_flags_vertical = Control.SIZE_EXPAND_FILL
	edit.add_theme_font_size_override("font_size", 13)
	edit.text = String(_notes.get(id, ""))
	edit.text_changed.connect(func():
		_notes[id] = edit.text
		_write_notes()
		_paint_mark(id))
	v.add_child(edit)
	return panel


func _flip(id: String) -> void:
	var f: Dictionary = _faces[id]
	if f.busy:
		return
	f.busy = true
	var h: Control = f.holder
	h.pivot_offset = h.size / 2.0
	var tw := h.create_tween()
	tw.tween_property(h, "scale:x", 0.0, 0.11)
	tw.tween_callback(func():
		f.back.visible = not f.back.visible
		f.card.visible = not f.back.visible
		f.catcher.visible = not f.back.visible
		_paint_mark(id))
	tw.tween_property(h, "scale:x", 1.0, 0.11)
	tw.tween_callback(func(): f.busy = false)


## "REDO" on the card while no sample is chosen, and a pencil when it has a note.
func _paint_mark(id: String) -> void:
	var f: Dictionary = _faces[id]
	var text := ""
	if int(_chosen.get(id, -1)) < 0:
		text = "REDO"
	if String(_notes.get(id, "")).strip_edges() != "":
		text += " ✎"
	f.mark.text = text
	f.mark.visible = text != "" and not f.back.visible


func _apply_filter() -> void:
	var q := _search.text.strip_edges().to_lower() if _search != null else ""
	for id in _tiles:
		var t: Control = _tiles[id]
		t.visible = q == "" or String(t.get_meta("name")).contains(q) or String(id).contains(q)


## The orange one is the official sample of that card.
func _paint_buttons(id: String) -> void:
	_paint_mark(id)
	var official := int(_chosen.get(id, -1))
	for n in SAMPLES:
		var b: Button = _buttons[id][n]
		if n == official:
			var sb := StyleBoxFlat.new()
			sb.bg_color = ORANGE
			sb.set_corner_radius_all(6)
			for st in ["normal", "hover", "pressed", "focus"]:
				b.add_theme_stylebox_override(st, sb)
			for c in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
				b.add_theme_color_override(c, Color(0.15, 0.08, 0.0))
		else:
			for st in ["normal", "hover", "pressed", "focus"]:
				b.remove_theme_stylebox_override(st)
			for c in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
				b.remove_theme_color_override(c)


func _clicked(id: String, n: int) -> void:
	if int(_chosen.get(id, -1)) == n:  # the orange one again: no sample is chosen, this sound has to be redone (it stays as it is until then)
		_player.stop()
		_chosen[id] = -1
		_write_chosen()
		_paint_buttons(id)
		_note.text = "%s: no sample chosen, its sound has to be redone." % _name_of(id)
		return
	var stream := Audio.wav_from_file(_sample_path(id, n))
	if stream == null:
		return
	_player.stop()
	_player.stream = stream
	_player.volume_db = linear_to_db(maxf(0.001, Audio.sfx_level * Audio.overall_level))
	_player.play()
	# it becomes the official sound: the file is copied over the card's own sound, and the running game uses it at once
	var dest := _official_path(id)
	var err := DirAccess.copy_absolute(_sample_path(id, n), dest)
	if err != OK:
		_note.text = "Could not install the sample (error %d)." % err
		return
	_chosen[id] = n
	_write_chosen()
	Audio.set_override(_sound_name(id), stream)
	_paint_buttons(id)
	_note.text = "%s: sample %d is now the official sound." % [_name_of(id), n + 1]
