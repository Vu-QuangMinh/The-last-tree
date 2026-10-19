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
var _name: RichTextLabel  # (BBCode: "Enraged" is written in purple)
var _hp_row: HFlowContainer
var _status: RichTextLabel
## How far down the model's box the intent bubble's top sits (it used to float in a row of its own, high above).
const INTENT_Y := 6.0
const PUPPET_TOP := 50.0  # (Puppet Stage: how far the puppet's box rises above its holder, so the name and the Essence are not far above its head)
const PUPPET_BUBBLE_RIGHT := 70.0  # (Puppet Stage: x, in the puppet's box, where the intent bubble's pointer ends)
var _ring: Panel
var _marker: TextureRect  # New theme: the target reticle that replaces the ring
var targetable := false
var targeted := false
var move_mode := false
var move_pick := -1  # the element picked up in move mode
var pick_mode := false  # choosing an element to remove (Pluck)
var keep_big := false  # a spell that picks several Essence is still being cast: keep the row enlarged between picks
var paint_mode := false  # with pick_mode: Repaint's brush (armoured Essence can be painted, ones already its colour can't)
var paint_to := "?"
var pick_i := -1
var pick_el := ""  # with pick_mode: only Essence of this kind can be picked (the rest are dimmed)
var _spell_row: Control  # the Invoker's conjured spells: one in front of him, the others to his sides
var _spell_key := ""
var _spell_ids := ""
var _spell_cards: Array = []
var _holder: Control
var _px := 30.0  # the size of one Essence orb now
var _ghost := false  # a hand of the Handyman that is not in the fight yet: only its folded arm shows (HandymanStage)
var _rig_view := false  # a Handyman hand or his body (see _raise_text)
var _free_layout := false  # Puppet Stage: the name stands on the puppet's head and the Essence under its feet (see _layout_free)
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
	_intent_slot = Control.new() if UiSkin.is_puppet() else CenterContainer.new()  # (Puppet Stage: the bubble is placed by hand, left of the puppet)
	_intent_slot.z_index = 10  # never hidden behind a model
	_intent_slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var holder := Control.new()
	holder.custom_minimum_size = Vector2(300, 230)
	if UiSkin.is_puppet():  # (the puppet's box reaches PUPPET_TOP px above this one: its name and Essence stand that much lower, close above its head)
		holder.custom_minimum_size = Vector2(300, 230.0 - PUPPET_TOP)
	holder.size_flags_horizontal = Control.SIZE_SHRINK_CENTER  # (centred when the view is wider, e.g. the Matron's)
	holder.mouse_filter = Control.MOUSE_FILTER_PASS
	_holder = holder
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
		_marker.position = Vector2(70, 62.0 - (PUPPET_TOP if UiSkin.is_puppet() else 0.0))
		_marker.pivot_offset = Vector2(80, 80)
		_marker.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_marker.visible = false
		holder.add_child(_marker)  # behind the creature: it stands in front of its reticle
	creature = Creature.new()
	creature.setup(e)
	creature.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	creature.offset_top = -PUPPET_TOP if UiSkin.is_puppet() else 22  # models stay below the intent bubble (Puppet Stage: the bubble is at its side)
	holder.add_child(creature)
	if e.def.get("invokes", false):
		_spell_row = Control.new()
		_spell_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		holder.add_child(_spell_row)  # (in front of him; his intent bubble goes over them)
	# the intent bubble sits low, just above the model's head (added after the model, so it's drawn over it)
	if e.def.has("tool") and not UiSkin.is_puppet():  # (the Puppet Stage art already holds its tool)
		# a Handyman hand: its tool, held up in front of it
		var tool := UiTheme.label(e.def.tool, 54, Color.WHITE)
		tool.position = Vector2(170, 95)
		tool.rotation = -0.3
		tool.mouse_filter = Control.MOUSE_FILTER_IGNORE
		holder.add_child(tool)
	_intent_slot.position = Vector2(0, INTENT_Y - (INVOKER_LIFT + 60.0 if e.def.get("invokes", false) else 0.0))  # (the Invoker's: above his head)
	_intent_slot.size = Vector2(300, 46)
	if UiSkin.is_puppet():
		_intent_slot.position = Vector2.ZERO  # (the bubble is put by hand: _place_chip)
		_intent_slot.size = Vector2(300, 77)
	holder.add_child(_intent_slot)
	_name = RichTextLabel.new()
	_name.bbcode_enabled = true
	_name.fit_content = true
	_name.scroll_active = false
	_name.autowrap_mode = TextServer.AUTOWRAP_OFF
	_name.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_name.add_theme_font_size_override("normal_font_size", 20)
	_name.text = "[center]" + e.name.replace("Enraged", "[color=#b57bff]Enraged[/color]") + "[/center]"
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
	if UiSkin.is_puppet():  # the name and the Essence stand ABOVE the puppet (where the bubble used to be), the puppet last, at the bottom
		move_child(holder, get_child_count() - 1)
		if not enemy.has_passive("briar_walls"):  # (her hedges keep the old stacked layout)
			_free_layout = true
			for c in [_name, _hp_row, _status]:
				remove_child(c)
				holder.add_child(c)
			creature.resized.connect(func() -> void:
				_layout_free()
				_replace_chips())
			_hp_row.resized.connect(_layout_free)
			_status.resized.connect(_layout_free)
	if UiSkin.is_puppet() and (creature.has_rig() or e.id == "handyman"):
		_raise_text()  # (the Handyman's body and arms are layered over one another: what is written stands above all of them)
	refresh({})


## The Handyman fight: his arms and body overlap each other and their neighbours' views, so a hand's name, Essence and target marker are drawn
## above every layer (the intent bubble already is), and only the part of the view round them takes clicks (see _has_point).
func _raise_text() -> void:
	_rig_view = true
	_name.add_theme_font_size_override("normal_font_size", 17)
	for c in [_name, _hp_row, _status, _ring, _marker]:
		if c != null:
			c.z_index = 6
	_place_marker()


## A hand's target reticle: half the size, right on the hand marker (the middle of the Creature's box). Needs the box's real size: it is run again
## whenever the box changes (_layout_free).
func _place_marker() -> void:
	if _marker == null or creature == null or not UiSkin.is_puppet():
		return
	_marker.size = Vector2(42.0, 42.0)  # (small, as on the Handyman's hands, and on the enemy itself)
	_marker.z_index = 6  # (over the puppet)
	_marker.pivot_offset = _marker.size / 2.0
	if creature.has_rig():
		_marker.position = Vector2(creature.size.x / 2.0, creature.size.y / 2.0 - PUPPET_TOP) - _marker.size / 2.0
	else:
		_marker.position = _puppet_rect().get_center() - _marker.size / 2.0


## A hand of the Handyman that is not in the fight yet (HandymanStage.sync_ghosts): only its folded arm shows, no name, Essence, statuses, bubble or target
## marker, and it takes no clicks.
func make_ghost() -> void:
	_ghost = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if creature != null:
		creature.calm = true  # (it was never hurt: it lies folded and still, no creaking and trembling of the broken gears; Creature._draw_arm)
	for c in [_name, _hp_row, _status, _intent_slot, _ring, _marker]:
		if c != null:
			c.visible = false


func _has_point(p: Vector2) -> bool:
	if _ghost:
		return false
	if _rig_view and creature.has_rig():  # the arm's own middle, and the block of name, Essence and intent beside it
		var mid := _holder.position + creature.position + creature.size / 2.0
		var text := _puppet_rect()
		text.position += _holder.position
		return Rect2(mid - Vector2(70.0, 60.0), Vector2(140.0, 120.0)).has_point(p) or text.grow_individual(60.0, 34.0, 60.0, 110.0).has_point(p)
	return Rect2(Vector2.ZERO, size).has_point(p)


## "Burn 2" / "Poison 3" / "Frozen": in the New theme the painted icon goes in front of the word.
func _status_bbcode(text: String) -> String:
	# the picture for the status named first in `text` (Puppet art first, the older intent pictures as a fallback)
	var names: Array = {"Burn": ["status_burn", "intent_burn"], "Poison": ["status_poison", "intent_poison"],
		"Frozen": ["status_freeze", "intent_freeze"], "Weakened": ["status_weak"], "Stillness": ["status_weak"],
		"Ethereal": ["status_ethereal", "intent_ethereal"], "Power": ["intent_empower"]}.get(text.get_slice(" ", 0), [])
	for art in names:
		if UiSkin.tex(art) != null:
			return "[img=22]%s[/img] %s" % [UiSkin.path_of(art), Keywords.colorize(text)]
	return Keywords.colorize(text)


func _gui_input(ev: InputEvent) -> void:
	if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
		clicked.emit(self)


## Rearrange: a draggable copy of its row is laid over the real one (which hides meanwhile). Hidden (Blind) Essence
## stay hidden. The caller frees the copy and calls end_row_drag().
func begin_row_drag(screen: Control) -> ChantDrag:
	var d := ChantDrag.new()
	var mask := fight.hidden_mask(enemy)
	for i in enemy.size():
		d.els.append("hidden" if i < mask.size() and mask[i] else enemy.elements[i])
		d.live.append(true)
	d.slots = 0
	d.px = _hp_icons[0].size.x if not _hp_icons.is_empty() else 48.0
	d.sep = 2.0
	d.same_spot_is_no_move = true
	d.z_index = 60
	screen.add_child(d)
	var w := enemy.size() * (d.px + d.sep) - d.sep
	var row := _hp_row.get_global_rect()
	d.global_position = Vector2(row.get_center().x - w / 2.0, row.position.y - 8.0)
	_hp_row.modulate.a = 0.0
	return d


func end_row_drag() -> void:
	_hp_row.modulate.a = 1.0


## Where the arrow should point / start for this enemy (global coordinates).
func anchor_point() -> Vector2:
	if UiSkin.is_puppet() and creature != null:
		return creature.global_position + creature.size / 2.0
	return global_position + Vector2(size.x / 2.0, 170)


## preview: the dict from Fight.preview (or {} for none).
func refresh(preview: Dictionary) -> void:
	if _ghost:
		return
	creature.modulate = Color(1, 1, 1, 0.4) if enemy.knocked and not creature.has_rig() else Color.WHITE  # (a hand's arm fades and folds by itself: Creature._draw_arm)
	_hp_row.visible = not enemy.knocked  # (a fallen hand has no HP bar: it can't be targeted)
	if _spell_row != null:
		_refresh_invoked(preview.get("invoke", {}).get(enemy, []))
	var e := enemy
	for c in _intent_slot.get_children():
		c.queue_free()
	if not e.intent.is_empty() and not e.def.get("hidden_intent", false):  # (the Veiled Eyes hide theirs: only its eyes tell)
		var chip := IntentChip.make(e)
		# the fight screen shows our own hover panel instead of the built-in tooltip (see FightScreen._update_hover_info)
		chip.set_meta("info", chip.tooltip_text)
		chip.tooltip_text = ""
		_intent_slot.add_child(chip)
		if UiSkin.is_puppet():  # its right edge (the pointer) just touches the puppet, it grows to the left with its content
			chip.resized.connect(_place_chip.bind(chip))  # (it moves itself whenever its size changes; the signal goes with the chip)
			_place_chip(chip)
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
	if _rig_view and creature.has_rig():
		px = 30.0  # (the hands hang close to each other: their name and Essence are smaller)
	var walled := e.has_passive("briar_walls")
	if walled:
		px = 30.0
	if move_mode or pick_mode or keep_big:
		px = 48.0 if e.size() <= 6 else 40.0
		if _rig_view and creature.has_rig():
			px = 38.0
		if walled:
			px = 34.0
	_px = px
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
		icon.ghost = ghosts.has(i)
		if move_mode:
			icon.highlight = i == move_pick
			icon.dim = move_pick >= 0 and i != move_pick
			_make_clickable(icon, i)
		elif pick_mode:
			icon.highlight = i == pick_i
			var can: bool = (e.elements[i] != paint_to) if paint_mode else (not e.armor[i] and (pick_el == "" or e.elements[i] == pick_el))
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
		var sk: Control = UiSkin.icon("icon_skull", px)  # (Puppet: the carved wooden skull)
		if sk != null:
			sk.mouse_filter = Control.MOUSE_FILTER_PASS  # (so the tooltip shows)
		else:
			sk = UiTheme.label("💀", int(px * 0.9), Color.WHITE)  # white: the emoji keeps its own bright colors
			sk.custom_minimum_size = Vector2(px, px)
			sk.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			sk.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			sk.add_theme_constant_override("outline_size", maxi(3, int(px * 0.12)))
			sk.add_theme_color_override("font_outline_color", Color.BLACK)
		sk.tooltip_text = "Your chant would defeat it."
		(_link.skull_cell if walled else _hp_row).add_child(sk)
	var st := e.describe_statuses()
	for p in e.def.get("passives", []):
		if not (p in EnemyDefs.HIDDEN_PASSIVES) and p != "shield_rage" and not (p == "hand" and _rig_view):  # ("Enraged" is in its name, in purple; a hand's "A hand" line would only take room: hover its Essence)
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
	_name.add_theme_color_override("default_color", Color(1, 0.9, 0.4) if targeted else Color.WHITE)
	_place_marker()
	if _free_layout:
		_layout_free.call_deferred()


## Puppet Stage: where the painted puppet is, in the holder's coordinates (its whole box when it has no cut-out).
func _puppet_rect() -> Rect2:
	var b := creature.puppet_bounds()
	if b.size == Vector2.ZERO:
		b = Rect2(Vector2.ZERO, creature.size)
	b.position += Vector2(0.0, -PUPPET_TOP)  # (where it stands at rest: not where an attack has thrown it for a moment, which moves creature.position)
	return b


## Puppet Stage: the name sits right on the puppet's head, its Essence 5 px under its feet, its statuses under them.
func _layout_free() -> void:
	if not _free_layout or creature == null or not is_instance_valid(_name):
		return
	_place_marker()
	var b := _puppet_rect()
	var w := _holder.size.x
	var dx := b.get_center().x - w / 2.0 if creature.has_rig() else 0.0  # (a Handyman hand's text stands beside its arm: see the rig's `info`)
	var nh := _name.get_combined_minimum_size().y
	_name.size = Vector2(w, nh)
	_name.position = Vector2(dx, b.position.y - nh - 1.0)
	var top := b.end.y + 5.0
	var row_w := w  # (a long row of Essence, usually a boss's, is laid out wider so that it never takes more than two lines)
	var step := _px + 2.0
	var n := _hp_row.get_child_count()
	if n * step > 2.0 * w:
		row_w = ceilf(n / 2.0) * step + 4.0
	var row_x := (w - row_w) / 2.0 + dx
	if _hp_row.position != Vector2(row_x, top) or _hp_row.size.x != row_w:
		_hp_row.position = Vector2(row_x, top)
		_hp_row.size = Vector2(row_w, 0.0)
	var below := top + _hp_row.get_combined_minimum_size().y + 2.0
	_status.position = Vector2(5.0 + dx, below)
	_status.size.x = w - 10.0


## Puppet Stage: the intent bubble stands left of the puppet (its pointer 4 px off the painted part), centred on the puppet's height.
func _place_chip(chip: Control) -> void:
	if is_instance_valid(chip) and not chip.is_queued_for_deletion():
		var b := _puppet_rect()
		if _rig_view and creature.has_rig():  # (a hand: the names stand in a row, so the bubble goes above its hand, not beside it)
			var hand_y := creature.size.y / 2.0 - PUPPET_TOP  # (the hand marker: the bubble stands above it, clear of the reticle)
			chip.position = Vector2(b.get_center().x - chip.size.x / 2.0, hand_y - 28.0 - chip.size.y)
			return
		chip.position = Vector2(b.position.x - 4.0 - chip.size.x, b.get_center().y - chip.size.y / 2.0)


func _replace_chips() -> void:
	for c in _intent_slot.get_children():
		if not c.is_queued_for_deletion():
			_place_chip(c)


func _make_clickable(c: Control, index: int) -> void:
	c.mouse_filter = Control.MOUSE_FILTER_STOP
	c.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	c.gui_input.connect(func(ev):
		if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
			hp_clicked.emit(self, index)
			c.accept_event())


## The intent bubble (null if it has none this turn).
## The Invoker's spells, as big as yours: one at each side of him and one above his head (never in front of him), further ones
## lower at his sides. They hover, each drifting up and down on its own beat like his orbs. Plain cards (no conjured static): they
## appear, and fade away when cast or when the turn ends. The ones that will go off this turn glow gold. Their numbers follow his Power.
const INVOKER_LIFT := 150.0  # how far the Invoker's model sits above where models usually stand
const INVOKED_SPOTS := [Vector2(-290, -60), Vector2(340, -60), Vector2(25, -282), Vector2(-290, 150), Vector2(340, 150)]
var _float_t := 0.0


## The Invoker's cards hover: a slow drift up and down and a little sideways, each on its own beat (like the orbs over his hand).
func _process(d: float) -> void:
	if _spell_cards.is_empty():
		return
	_float_t += d
	for i in _spell_cards.size():
		var c = _spell_cards[i]  # (untyped: a card may have been freed)
		if is_instance_valid(c) and c.has_meta("home"):
			var ph := i * 2.1
			c.position = (c.get_meta("home") as Vector2) + Vector2(sin(_float_t * 1.4 + ph) * 2.5, sin(_float_t * 2.2 + ph) * 6.0)


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
			card.set_meta("home", card.position)
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


## Puppet Stage: the screen y of the bottom of what hangs under the feet (the Essence rows, then the statuses when it has any).
func below_feet_bottom() -> float:
	if not _free_layout or not is_instance_valid(_hp_row):
		return 0.0
	var b := _hp_row.global_position.y + _hp_row.get_combined_minimum_size().y
	if _status.text.strip_edges() != "[center][/center]" and _status.get_content_height() > 0:
		b = _status.global_position.y + _status.get_content_height()
	return b


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
