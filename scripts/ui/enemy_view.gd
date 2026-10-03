class_name EnemyView
extends VBoxContainer
## An enemy on the fight screen: intent symbols on top (always drawn above the model), portrait, name,
## HP orbs (with preview ghosts), statuses. In move mode its HP orbs are clickable.

signal clicked(view: EnemyView)
signal hp_clicked(view: EnemyView, index: int)  # index == size() means "the end"

var enemy: EnemyState
var fight: Fight
var creature: Creature
var _intent_slot: Control
var _name: Label
var _hp_row: HFlowContainer
var _status: RichTextLabel
## How far down the model's box the intent bubble's top sits (it used to float in a row of its own, high above).
const INTENT_Y := 6.0
var _ring: Panel
var _marker: TextureRect  # New theme: the target reticle that replaces the ring
var targetable := false
var targeted := false
var move_mode := false
var move_pick := -1  # the element picked up in move mode
var pick_mode := false  # choosing an element to remove (Pluck)
var pick_i := -1
var _hp_icons: Array = []  # the orbs currently shown, left to right


func setup(e: EnemyState, f: Fight) -> void:
	enemy = e
	fight = f
	custom_minimum_size = Vector2(300, 470)
	alignment = BoxContainer.ALIGNMENT_END
	add_theme_constant_override("separation", 4)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_intent_slot = CenterContainer.new()
	_intent_slot.z_index = 10  # never hidden behind a model
	_intent_slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var holder := Control.new()
	holder.custom_minimum_size = Vector2(300, 230)
	holder.mouse_filter = Control.MOUSE_FILTER_PASS
	holder.clip_contents = false
	add_child(holder)
	_ring = Panel.new()
	var rb := StyleBoxFlat.new()
	rb.draw_center = false
	rb.border_color = Color(1, 0.9, 0.4)
	rb.set_border_width_all(3)
	rb.set_corner_radius_all(16)
	_ring.add_theme_stylebox_override("panel", rb)
	_ring.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(_ring)
	var stand := UiSkin.tex("enemy_stand")
	if stand != null:  # New theme: it stands on a painted stump (behind the creature)
		var sr := TextureRect.new()
		sr.texture = stand
		sr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		sr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		sr.position = Vector2(25, 105)
		sr.size = Vector2(250, 250.0 * stand.get_height() / stand.get_width())
		sr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		holder.add_child(sr)
	var reticle := UiSkin.tex("target_marker")
	if reticle != null:
		_ring.hide()
		_marker = TextureRect.new()
		_marker.texture = reticle
		_marker.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		_marker.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		_marker.size = Vector2(160, 160)
		_marker.position = Vector2(70, 62)
		_marker.pivot_offset = Vector2(80, 80)
		_marker.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_marker.visible = false
		holder.add_child(_marker)  # behind the creature: it stands in front of its reticle
	creature = Creature.new()
	creature.setup(e)
	creature.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	creature.offset_top = 22  # models stay below the intent bubble
	holder.add_child(creature)
	# the intent bubble sits low, just above the model's head (added after the model, so it's drawn over it)
	_intent_slot.position = Vector2(0, INTENT_Y)
	_intent_slot.size = Vector2(300, 46)
	holder.add_child(_intent_slot)
	_name = UiTheme.label(e.name, 20, Color.WHITE)
	_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(_name)
	_hp_row = HFlowContainer.new()
	_hp_row.alignment = FlowContainer.ALIGNMENT_CENTER
	_hp_row.add_theme_constant_override("h_separation", 2)
	_hp_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_hp_row)
	_status = RichTextLabel.new()
	_status.bbcode_enabled = true
	_status.fit_content = true
	_status.scroll_active = false
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status.custom_minimum_size = Vector2(290, 40)
	_status.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_status.add_theme_font_size_override("normal_font_size", 14)
	_status.add_theme_font_size_override("bold_font_size", 14)
	_status.add_theme_color_override("default_color", Color(0.85, 0.8, 1))
	add_child(_status)
	refresh({})


## "Burn 2" / "Poison 3" / "Frozen": in the New theme the painted icon goes in front of the word.
func _status_bbcode(text: String) -> String:
	var art: String = {"Burn": "intent_burn", "Poison": "intent_poison", "Frozen": "intent_freeze"}.get(text.get_slice(" ", 0), "")
	if art != "" and UiSkin.tex(art) != null:
		return "[img=22]%s%s.png[/img] %s" % [UiSkin.DIR, art, Keywords.colorize(text)]
	return Keywords.colorize(text)


func _gui_input(ev: InputEvent) -> void:
	if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
		clicked.emit(self)


## Where the arrow should point / start for this enemy (global coordinates).
func anchor_point() -> Vector2:
	return global_position + Vector2(size.x / 2.0, 170)


## preview: the dict from Fight.preview (or {} for none).
func refresh(preview: Dictionary) -> void:
	var e := enemy
	for c in _intent_slot.get_children():
		c.queue_free()
	if not e.intent.is_empty():
		var chip := IntentChip.make(e)
		# the fight screen shows our own hover panel instead of the built-in tooltip (see FightScreen._update_hover_info)
		chip.set_meta("info", chip.tooltip_text)
		chip.tooltip_text = ""
		_intent_slot.add_child(chip)
	for ch in _hp_row.get_children():
		ch.queue_free()
	_hp_icons.clear()
	var k: int = preview.get("removed", {}).get(e, 0)
	var ghosts := {}
	var seen := 0
	for i in e.size():
		if seen >= k:
			break
		if not e.armor[i]:
			ghosts[i] = true
		seen += 1
	if k > 0 and e.is_exposed():
		for i in range(e.size() - 1, -1, -1):
			if not ghosts.has(i) and not e.armor[i]:
				ghosts[i] = true
				break
	var mask := fight.hidden_mask(e)
	var px := 38.0 if e.size() <= 7 else 30.0
	if move_mode or pick_mode:
		px = 48.0 if e.size() <= 6 else 40.0
	for i in e.size():
		var hidden: bool = mask.size() > i and mask[i]
		var icon := ElementIcon.make("?" if hidden else e.elements[i], px)
		icon.armored = e.armor[i]
		icon.burning = e.is_lit(i)
		icon.poisoned = e.is_poisoned(i)
		icon.ghost = ghosts.has(i)
		if move_mode:
			icon.highlight = i == move_pick
			icon.dim = move_pick >= 0 and i != move_pick
			_make_clickable(icon, i)
		elif pick_mode:
			icon.highlight = i == pick_i
			icon.dim = e.armor[i]
			if not e.armor[i]:
				_make_clickable(icon, i)
				# the Essence under the cursor lights up
				icon.mouse_entered.connect(func(): icon.highlight = true; icon.queue_redraw())
				icon.mouse_exited.connect(func():
					icon.highlight = pick_i == i
					icon.queue_redraw())
		_hp_row.add_child(icon)
		_hp_icons.append(icon)
	if move_mode and move_pick >= 0:
		var end := UiTheme.label("▸", 30, Color(1, 0.9, 0.4))
		end.tooltip_text = "Put it at the end"
		_make_clickable(end, e.size() - 1)
		_hp_row.add_child(end)
		# the chant would finish it: a skull, the size of an Essence, at the end of its row of Essence
	if e in preview.get("dies", []):
		var sk := UiTheme.label("☠", int(px * 0.9), Color(1, 0.35, 0.3))
		sk.custom_minimum_size = Vector2(px, px)
		sk.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		sk.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		sk.add_theme_constant_override("outline_size", maxi(3, int(px * 0.12)))
		sk.add_theme_color_override("font_outline_color", Color.BLACK)
		sk.tooltip_text = "Your chant would defeat it."
		_hp_row.add_child(sk)
	var st := e.describe_statuses()
	for p in e.def.get("passives", []):
		st.append(EnemyDefs.PASSIVE_TEXT[p].get_slice(":", 0))
	_status.text = "[center]" + " · ".join(st.map(func(s): return _status_bbcode(s.get_slice(" (", 0)))) + "[/center]"
	tooltip_text = ""  # the fight screen's hover panel explains it (info_text)
	creature.tooltip_text = ""
	_ring.visible = (targetable or move_mode or pick_mode) and _marker == null
	_ring.modulate = Color(1, 1, 1, 1.0 if targeted or move_mode or pick_mode else 0.35)
	if _marker != null:
		var lit := targeted or move_mode or pick_mode
		_marker.visible = targetable or move_mode or pick_mode
		_marker.modulate.a = 1.0 if lit else 0.4
		_marker.scale = Vector2.ONE if lit else Vector2(0.85, 0.85)
	_name.add_theme_color_override("font_color", Color(1, 0.9, 0.4) if targeted else Color.WHITE)


func _make_clickable(c: Control, index: int) -> void:
	c.mouse_filter = Control.MOUSE_FILTER_STOP
	c.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	c.gui_input.connect(func(ev):
		if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
			hp_clicked.emit(self, index)
			c.accept_event())


## The intent bubble (null if it has none this turn).
func intent_chip() -> Control:
	for c in _intent_slot.get_children():
		if c is IntentChip and not c.is_queued_for_deletion():
			return c
	return null


## Everything about this enemy, for the hover panel: its Essence, every status (Burn and Poison say exactly which
## Essence they'll take), armour, its passives and its moves.
func info_text() -> String:
	var e := enemy
	var title := e.name + (" (Boss)" if e.is_boss else (" (Elite)" if e.is_elite else ""))
	var lines := []
	var names := e.elements.map(func(x): return Elements.NAMES.get(x, x))
	lines.append("Essence (%d), left to right: %s" % [e.size(), ", ".join(names)])
	var armoured := []
	for i in e.size():
		if e.armor[i]:
			armoured.append(str(i + 1))
	if not armoured.is_empty():
		lines.append("• Armour on Essence %s: it still counts for matching, but your chant can't remove it this turn." % ", ".join(armoured))
	if e.burn > 0:
		var gone := names.slice(0, mini(e.burn, e.size()))
		lines.append("• Burn %d: at the start of its turn it loses its %d leftmost Essence (%s), then Burn drops to %d." % [e.burn, gone.size(), ", ".join(gone), e.burn - 1])
	if e.poison > 0:
		var n := mini(e.poison, e.size())
		var gone := names.slice(e.size() - n)
		lines.append("• Poison %d: at the start of its turn it loses its %d rightmost Essence (%s), then Poison drops to %d." % [e.poison, n, ", ".join(gone), e.poison - 1])
	for s in e.describe_statuses():
		if s.begins_with("Burn") or s.begins_with("Poison"):
			continue
		lines.append("• " + s)
	for p in e.def.get("passives", []):
		lines.append("• " + EnemyDefs.PASSIVE_TEXT[p])
	if lines.size() == 1:
		lines.append("No effects on it right now.")
	# its moves, briefly (once it's in your Codex)
	lines.append("")
	if SaveManager.in_codex(e.id):
		var moves: Array = e.def.moves2 if (e.phase == 2 and e.def.has("moves2")) else e.def.moves
		lines.append("Moves, in order: " + "  →  ".join(moves.map(func(m): return EnemyDefs.describe_move(m, e.dmg_bonus))))
	else:
		lines.append("Moves unknown: defeat it once to record them in the Codex.")
	# its own lines already explain every effect, so no keyword glossary underneath (it stays compact)
	var flavor := "\n[i][color=#9aa89a]\"%s\"[/color][/i]" % e.def.get("flavor", "")
	return "[b][font_size=25]%s[/font_size][/b]\n%s%s" % [title, Keywords.colorize("\n".join(lines)), flavor]


func _tooltip() -> String:
	var e := enemy
	var title := e.name + (" (Boss)" if e.is_boss else (" (Elite)" if e.is_elite else ""))
	var lines := []
	lines.append("Essence: %d" % e.size())
	for s in e.describe_statuses():
		lines.append("• " + s)
	for p in e.def.get("passives", []):
		lines.append("• " + EnemyDefs.PASSIVE_TEXT[p])
	lines.append("Hover its portrait to see its moves.")
	var flavor := "[i][color=#9aa89a]\"%s\"[/color][/i]" % e.def.get("flavor", "")
	return Keywords.tooltip(title, "\n".join(lines), flavor)


func _make_custom_tooltip(for_text: String) -> Object:
	if for_text.strip_edges() == "":
		return null  # no text (e.g. its tooltip is pinned): no hover tooltip at all
	return Keywords.make_tooltip(for_text)


## Where HP element j sits on screen (comets fly here).
func hp_point(j: int) -> Vector2:
	if j >= 0 and j < _hp_icons.size():
		var ic: Control = _hp_icons[j]
		return ic.global_position + ic.size / 2.0
	return global_position + Vector2(size.x / 2.0, 330)


## The chant reaches HP element j: it bursts (armoured ones just clang).
func pop(j: int) -> void:
	if j < 0 or j >= _hp_icons.size():
		return
	var icon: ElementIcon = _hp_icons[j]
	icon.pivot_offset = icon.size / 2.0
	var tw := icon.create_tween()
	if icon.armored:
		tw.tween_property(icon, "modulate", Color(2, 2, 2), 0.06)
		tw.tween_property(icon, "modulate", Color.WHITE, 0.12)
		return
	tw.tween_property(icon, "scale", Vector2(1.5, 1.5), 0.07)
	tw.parallel().tween_property(icon, "modulate", Color(2.2, 2.0, 1.6), 0.07)
	tw.tween_property(icon, "scale", Vector2(0.1, 0.1), 0.12)
	tw.parallel().tween_property(icon, "modulate:a", 0.0, 0.12)
	creature.hit(0.6)


## Hurt: it jolts, blinks white and pulls a pained face (no blood).
func hit_flash() -> void:
	creature.hit(1.0)
