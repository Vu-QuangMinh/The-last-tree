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
var keep_big := false  # a spell that picks several Essence is still being cast: keep the row enlarged between picks
var paint_mode := false  # with pick_mode: Expose's brush (armoured Essence can be painted, Any ones can't)
var pick_i := -1
var pick_el := ""  # with pick_mode: only Essence of this kind can be picked (the rest are dimmed)
var _spell_row: Control  # the Invoker's conjured spells: one in front of him, the others to his sides
var _spell_key := ""
var _spell_ids := ""
var _spell_cards: Array = []
var _hp_icons: Array = []  # the orbs currently shown, left to right


func setup(e: EnemyState, f: Fight) -> void:
	enemy = e
	fight = f
	custom_minimum_size = Vector2(300, 470)
	if enemy != null and enemy.has_passive("briar_walls"):
		custom_minimum_size.x = 640.0  # room for her two hedges beside her own Essence
	if enemy != null and enemy.def.get("invokes", false):
		custom_minimum_size.x = 860.0  # room for his spell cards on either side of him
	alignment = BoxContainer.ALIGNMENT_END
	add_theme_constant_override("separation", 4)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_intent_slot = CenterContainer.new()
	_intent_slot.z_index = 10  # never hidden behind a model
	_intent_slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var holder := Control.new()
	holder.custom_minimum_size = Vector2(300, 230)
	holder.size_flags_horizontal = Control.SIZE_SHRINK_CENTER  # (centred when the view is wider, e.g. the Matron's)
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
	if e.def.get("invokes", false):
		creature.offset_top -= INVOKER_LIFT  # (the Invoker floats up above his middle card)
		creature.offset_bottom -= INVOKER_LIFT
	holder.add_child(creature)
	if e.def.get("invokes", false):
		_spell_row = Control.new()
		_spell_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		holder.add_child(_spell_row)  # (in front of him; his intent bubble goes over them)
	# the intent bubble sits low, just above the model's head (added after the model, so it's drawn over it)
	if e.def.has("tool"):
		# a Handyman hand: its tool, held up in front of it
		var tool := UiTheme.label(e.def.tool, 54, Color.WHITE)
		tool.position = Vector2(170, 95)
		tool.rotation = -0.3
		tool.mouse_filter = Control.MOUSE_FILTER_IGNORE
		holder.add_child(tool)
	_intent_slot.position = Vector2(0, INTENT_Y - (INVOKER_LIFT + 60.0 if e.def.get("invokes", false) else 0.0))  # (the Invoker's: above his head)
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
	creature.modulate = Color(1, 1, 1, 0.4) if enemy.knocked else Color.WHITE
	_hp_row.visible = not enemy.knocked  # (a fallen hand has no HP bar: it can't be targeted)
	if _spell_row != null:
		_refresh_invoked(preview.get("invoke", {}).get(enemy, []))
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
	var mask := fight.hidden_mask(e)
	var px := 38.0 if e.size() <= 7 else 30.0
	var walled := e.has_passive("briar_walls")
	if walled:
		px = 30.0
	if move_mode or pick_mode or keep_big:
		px = 48.0 if e.size() <= 6 else 40.0
		if walled:
			px = 34.0
	e._fix_lit()
	# an enemy behind walls (Bramble Matron): each wall is a hedge with its own Essence under it, hers stack in a
	# framed block in the middle. Still one row, in order: left wall, her, right wall.
	var place: Array = _wall_layout(e, px) if walled else []  # (walled: where each Essence goes, by index)
	for i in e.size():
		var hidden: bool = mask.size() > i and mask[i]
		var icon := ElementIcon.make("hidden" if hidden else e.elements[i], px)
		icon.armored = e.armor[i]
		icon.wall = e.parts[i] != ""
		icon.burning = e.is_lit(i)
		icon.poisoned = e.is_poisoned(i)
		icon.ghost = ghosts.has(i)
		if move_mode:
			icon.highlight = i == move_pick
			icon.dim = move_pick >= 0 and i != move_pick
			_make_clickable(icon, i)
		elif pick_mode:
			icon.highlight = i == pick_i
			var can: bool = (e.elements[i] != "?") if paint_mode else (not e.armor[i] and (pick_el == "" or e.elements[i] == pick_el))
			icon.dim = not can
			if can:
				_make_clickable(icon, i)
				# the Essence under the cursor lights up
				icon.mouse_entered.connect(func(): icon.highlight = true; icon.queue_redraw())
				icon.mouse_exited.connect(func():
					icon.highlight = pick_i == i
					icon.queue_redraw())
		(place[i] if walled else _hp_row).add_child(icon)
		_hp_icons.append(icon)
	if move_mode and move_pick >= 0:
		var end := UiTheme.label("▸", 30, Color(1, 0.9, 0.4))
		end.tooltip_text = "Put it at the end"
		_make_clickable(end, e.size() - 1)
		_hp_row.add_child(end)
		# the chant would finish it: a skull, the size of an Essence, at the end of its row of Essence
	if e in preview.get("dies", []):
		var sk := UiTheme.label("💀", int(px * 0.9), Color.WHITE)  # white: the emoji keeps its own bright colors
		sk.custom_minimum_size = Vector2(px, px)
		sk.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		sk.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		sk.add_theme_constant_override("outline_size", maxi(3, int(px * 0.12)))
		sk.add_theme_color_override("font_outline_color", Color.BLACK)
		sk.tooltip_text = "Your chant would defeat it."
		(_link.skull_cell if walled else _hp_row).add_child(sk)
	var st := e.describe_statuses()
	for p in e.def.get("passives", []):
		if not (p in EnemyDefs.HIDDEN_PASSIVES):
			st.append(EnemyDefs.PASSIVE_TEXT[p].get_slice(":", 0))
	_status.text = "[center]" + " · ".join(st.map(func(s): return _status_bbcode(s.get_slice(" (", 0)))) + "[/center]"
	tooltip_text = ""  # (in a fight only the intent bubble explains anything: see FightScreen._update_hover_info)
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
## The Invoker's spells, as big as yours: the first in front of him (just above his Essence row), the others to his
## sides, higher up. Plain cards (no conjured static): they appear, and fade away when cast or when the turn ends.
## The ones that will go off this turn glow gold. Their numbers follow his Power.
const INVOKER_LIFT := 150.0  # how far the Invoker's model sits above where models usually stand
const INVOKED_SPOTS := [Vector2(25, 34), Vector2(-280, -80), Vector2(330, -80), Vector2(-280, 130), Vector2(330, 130)]


func _refresh_invoked(picks: Array) -> void:
	for sp in enemy.conjured:
		sp.desc = Fight.invoker_desc(sp, enemy)
	var key := ",".join(enemy.conjured.map(func(s): return s.id + ":" + s.pattern + ":" + s.desc))
	if key != _spell_key:
		var ids := ",".join(enemy.conjured.map(func(s): return s.id))
		var fresh := ids != _spell_ids  # (new spells, not just new numbers or a shorter pattern)
		_spell_ids = ids
		_spell_key = key
		for c in _spell_cards:
			if is_instance_valid(c):
				c.queue_free()
		_spell_cards.clear()
		for k in enemy.conjured.size():
			var card := SpellCard.make(enemy.conjured[k])
			card.size = Vector2(SpellCard.W, SpellCard.H)
			card.position = INVOKED_SPOTS[mini(k, INVOKED_SPOTS.size() - 1)]
			_spell_row.add_child(card)
			_spell_cards.append(card)
	for i in _spell_cards.size():
		var card: SpellCard = _spell_cards[i]
		card.fires = 1 if i in picks else 0
		card.refresh()


## The Invoker casts one of his spells: its card flares and fizzles away.
func flash_invoked(i: int) -> void:
	if i < 0 or i >= _spell_cards.size() or not is_instance_valid(_spell_cards[i]):
		return
	var card: SpellCard = _spell_cards[i]
	var tw := card.create_tween()
	tw.tween_property(card, "modulate", Color(2.0, 1.8, 1.2), 0.12)
	tw.tween_property(card, "modulate", Color(1, 1, 1, 0), 0.3)


## Talking to a boss: only the creature shows (no intent, no Essence row, no statuses) until you Engage.
func set_talk(on: bool, fade := 0.0, talk_name := "") -> void:
	# its name: what you know of it so far ("???" until you've asked who it is), its real name once you Engage
	if _name != null:
		_name.text = talk_name if on and talk_name != "" else enemy.name
	for n in [_intent_slot, _hp_row, _status, _link, _spell_row]:
		if n == null or not is_instance_valid(n):
			continue
		if fade > 0.0:
			n.create_tween().tween_property(n, "modulate:a", 0.0 if on else 1.0, fade)
		else:
			n.modulate.a = 0.0 if on else 1.0


func intent_chip() -> Control:
	for c in _intent_slot.get_children():
		if c is IntentChip and not c.is_queued_for_deletion():
			return c
	return null


## Everything about this enemy, for the hover panel: its Essence, every status (Burn and Poison say exactly which
## Essence they'll take), armour, its passives and its moves.

## The Matron's row: the left wall's Essence on one line beside her first row, the right wall's beside her second
## row, a hedge above each wall, and a thin line running through every Essence in order (left wall, her rows, right
## wall), so you can read it as one row. Returns where each Essence goes, by its index in the row.
func _wall_layout(e: EnemyState, px: float) -> Array:
	var full := int(e.def.get("walls", 5))
	var gap := 3.0
	var wall_w := full * px + (full - 1) * gap
	var body_w := 6 * px + 5 * gap
	var nb := e.parts.count("")
	var rows_n := maxi(1, ceili(nb / 6.0))  # (6 or fewer of her own: one line, walls on each side)
	_link = LinkedRows.new()
	_link.add_theme_constant_override("separation", 4)
	_link.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hp_row.add_child(_link)
	# the hedges, above their walls
	var hedges := _row_of(wall_w, body_w)
	for side in ["L", "R"]:
		var cell: Control = hedges[0 if side == "L" else 2]
		var col := VBoxContainer.new()
		col.alignment = BoxContainer.ALIGNMENT_END
		col.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cell.add_child(col)
		if side in e.parts and fight != null:
			# the wall's own intent, over its head (its tooltip says just what it's about to do)
			var chip := IntentChip.make(e, fight.wall_move(e, side))
			col.add_child(chip)
		var hedge := HedgeWall.make(e.parts.count(side) / float(full), side == "R", Vector2(wall_w, 90))
		col.add_child(hedge)
		hedges_by_side[side] = hedge
	var rows := []
	for r in rows_n:
		rows.append(_row_of(wall_w, body_w))
	var out := []
	var k := 0
	for i in e.size():
		match e.parts[i]:
			"L":
				out.append(rows[0][0])
			"R":
				out.append(rows[mini(1, rows_n - 1)][2])
			_:
				out.append(rows[mini(k / 6, rows_n - 1)][1])
				k += 1
	_link.skull_cell = rows[maxi(0, ceili(nb / 6.0) - 1)][1]
	_link.icons = _hp_icons
	_link.parts = e.parts.duplicate()
	return out


## One line of the Matron's row: [left cell][her cell][right cell], each a fixed width so the lines stay aligned.
func _row_of(wall_w: float, body_w: float) -> Array:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 12)
	h.alignment = BoxContainer.ALIGNMENT_CENTER
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_link.add_child(h)
	var cells := []
	for k in 3:
		var w: float = body_w if k == 1 else wall_w
		var c := HBoxContainer.new()
		c.custom_minimum_size = Vector2(w, 0)
		c.add_theme_constant_override("separation", 3)
		# (the left wall's Essence keep to her side, so the line through them never jumps a gap)
		# (the left wall's Essence keep to her side, the right wall's too; hers stay centred under her)
		c.alignment = [BoxContainer.ALIGNMENT_END, BoxContainer.ALIGNMENT_CENTER, BoxContainer.ALIGNMENT_BEGIN][k]
		c.mouse_filter = Control.MOUSE_FILTER_IGNORE
		h.add_child(c)
		cells.append(c)
	return cells


var _link: LinkedRows
var hedges_by_side := {}  # "L" / "R" -> the HedgeWall drawn for that wall (the Matron)


## The rows of the Matron's Essence, with a thin line drawn behind them through every Essence in order, and a faint
## frame behind her own.
class LinkedRows extends VBoxContainer:
	var icons: Array = []
	var parts: Array = []
	var skull_cell: Control

	func _process(_d: float) -> void:
		queue_redraw()

	func _draw() -> void:
		var pts := PackedVector2Array()
		var body := Rect2()
		for i in icons.size():
			var ic: Control = icons[i]
			if not is_instance_valid(ic) or not ic.is_inside_tree():
				continue
			var r := Rect2(ic.global_position - global_position, ic.size)
			pts.append(r.get_center())
			if i < parts.size() and parts[i] == "":
				body = r if body.size == Vector2.ZERO else body.merge(r)
		if body.size != Vector2.ZERO:
			var sb := StyleBoxFlat.new()
			sb.bg_color = Color(0.25, 0.15, 0.3, 0.4)
			sb.border_color = Color(0.8, 0.6, 1.0, 0.7)
			sb.set_border_width_all(2)
			sb.set_corner_radius_all(10)
			draw_style_box(sb, body.grow(5))
		if pts.size() >= 2:
			draw_polyline(pts, Color(0.1, 0.06, 0.03, 0.55), 4.0, true)
			draw_polyline(pts, Color(0.95, 0.88, 0.7, 0.75), 1.6, true)

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
		var gone := names.slice(e.size() - mini(e.burn, e.size()))
		lines.append("• Burn %d: at the start of its turn it loses its %d rightmost Essence (%s), then the Burn is gone." % [e.burn, gone.size(), ", ".join(gone)])
	if e.poison > 0:
		lines.append("• Poison %d: it grows by 1 every turn. Once it reaches the Essence left (%d), it dies, armour or not." % [e.poison, e.size()])
	for s in e.describe_statuses():
		if s.begins_with("Burn") or s.begins_with("Poison"):
			continue
		lines.append("• " + s)
	for p in e.def.get("passives", []):
		if not (p in EnemyDefs.HIDDEN_PASSIVES):
			lines.append("• " + EnemyDefs.PASSIVE_TEXT[p])
	if lines.size() == 1:
		lines.append("No effects on it right now.")
	# its own lines already explain every effect, so no keyword glossary underneath (it stays compact)
	return "[b][font_size=25]%s[/font_size][/b]\n%s" % [title, Keywords.colorize("\n".join(lines))]


## Is the mouse over its HP (its Essence row, or the status line under it)? Hovering there shows info_text().
func hp_hovered(m: Vector2) -> bool:
	for c in [_hp_row, _link, _status]:
		if c != null and is_instance_valid(c) and c.is_visible_in_tree() and c.get_global_rect().has_point(m):
			return true
	return false


func _tooltip() -> String:
	var e := enemy
	var title := e.name + (" (Boss)" if e.is_boss else (" (Elite)" if e.is_elite else ""))
	var lines := []
	lines.append("Essence: %d" % e.size())
	for s in e.describe_statuses():
		lines.append("• " + s)
	for p in e.def.get("passives", []):
		if not (p in EnemyDefs.HIDDEN_PASSIVES):
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
