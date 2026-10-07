class_name FuseScreen
extends Control
## Campfire: fuse two spells into one. Drag two cards onto the fuse slots (or click them); the forged spell is shown
## before you commit. A card dropped on a full slot pushes the old card back down to the list; a card dragged out of a
## slot (or clicked there) runs back down too.

signal fused(new_spell: Dictionary)
signal back

const RULES := "Melt two spells into one that does everything both did."

var run: RunState
var _slots: Array = ["", ""]  # ids in the two fuse slots: the first one's pattern goes first
var _preview: Dictionary = {}
var _grid: HFlowContainer
var _slot_box: Array = []  # the two drop targets
var _result_box: HBoxContainer
var _drag := {}  # the card being dragged: {id, from} (from = slot index, or -1 for the list)
var _fly: Array = []  # [{id, from: Vector2}] cards that run from a slot back down to the list
var _status: RichTextLabel
var _fuse_btn: Button
var _out: SpellCard  # the fused spell's card, once both slots are full
var _busy := false  # the fusion is playing
var _others: Control  # the "your other spells" overlay, while it's open


func setup(p_run: RunState) -> void:
	run = p_run


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
	v.position = Vector2(50, 70)
	v.size = Vector2(1820, 1000)
	v.add_theme_constant_override("separation", 12)
	add_child(v)
	v.add_child(UiTheme.heading("🔥 Fuse two spells", 38, Color(1, 0.8, 0.6)))
	var rules := RichTextLabel.new()
	rules.bbcode_enabled = true
	rules.fit_content = true
	rules.scroll_active = false
	rules.custom_minimum_size = Vector2(1100, 0)
	rules.add_theme_font_size_override("normal_font_size", 18)
	rules.add_theme_font_size_override("bold_font_size", 18)
	rules.add_theme_color_override("default_color", Color(0.9, 0.92, 0.86))
	rules.text = Keywords.colorize(RULES)
	v.add_child(rules)
	# the two fuse slots, then the result
	var mid := HBoxContainer.new()
	mid.add_theme_constant_override("separation", 24)
	v.add_child(mid)
	for k in 2:
		var slot := _make_slot(k)
		_slot_box.append(slot)
		mid.add_child(slot)
		if k == 0:
			mid.add_child(UiTheme.label("+", 48, Color.WHITE))
	mid.add_child(UiTheme.label("→", 48, Color(1, 0.8, 0.4)))
	_result_box = HBoxContainer.new()
	_result_box.custom_minimum_size = Vector2(SpellCard.W, SpellCard.H)
	mid.add_child(_result_box)
	var side := VBoxContainer.new()
	side.add_theme_constant_override("separation", 10)
	mid.add_child(side)
	_status = RichTextLabel.new()
	_status.bbcode_enabled = true
	_status.fit_content = true
	_status.scroll_active = false
	_status.custom_minimum_size = Vector2(420, 0)
	_status.add_theme_font_size_override("normal_font_size", 19)
	_status.add_theme_font_size_override("bold_font_size", 19)
	_status.add_theme_color_override("default_color", Color(1, 0.9, 0.75))
	side.add_child(_status)
	_fuse_btn = UiTheme.button("Fuse them!", _commit, 24)
	_fuse_btn.custom_minimum_size = Vector2(260, 56)
	side.add_child(_fuse_btn)
	var see := UiTheme.button("👁 See all your other spells", _show_others, 18)
	see.tooltip_text = "Look over every spell you own before you fuse: check the new pattern doesn't break an anti-spell, and plan the order with your other spells."
	side.add_child(see)
	v.add_child(UiTheme.label("Your spells (drag two onto the slots, or click them):", 18, UiTheme.MUTED))
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.custom_minimum_size = Vector2(1820, 300)
	scroll.set_drag_forwarding(Callable(), _can_drop_list, _drop_list)  # drop a slot's card here: it goes back down
	v.add_child(scroll)
	_grid = HFlowContainer.new()
	_grid.custom_minimum_size = Vector2(1800, 0)
	_grid.add_theme_constant_override("h_separation", 12)
	_grid.add_theme_constant_override("v_separation", 12)
	scroll.add_child(_grid)
	var bh := HBoxContainer.new()
	bh.position = Vector2(1500, 1000)
	add_child(bh)
	var back_btn := UiTheme.button("Back to the campfire", func(): back.emit(), 20)
	back_btn.custom_minimum_size = Vector2(300, 52)
	bh.add_child(back_btn)
	_refresh()


func _make_slot(k: int) -> PanelContainer:
	var p := PanelContainer.new()
	p.custom_minimum_size = Vector2(SpellCard.W, SpellCard.H)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0, 0, 0, 0.35)
	sb.border_color = Color(1, 0.8, 0.5, 0.6)
	sb.set_border_width_all(3)
	sb.set_corner_radius_all(12)
	p.add_theme_stylebox_override("panel", sb)
	p.set_drag_forwarding(Callable(), func(_at, d): return _can_drop_slot(d), func(_at, d): _drop_slot(k, d))
	return p


func _refresh() -> void:
	for c in _grid.get_children():
		c.queue_free()
	# only the spells that can be fused are shown at all: once a slot is filled, only its kind (anti-spells go with
	# anti-spells, spells with spells)
	for id in run.fusable():
		if id in _slots or not _fits(id):
			continue  # it sits in a fuse slot, or can't go with what's there
		var card := SpellCard.make(run.spell(id))
		# the rules again, right where the player is deciding
		card.set_meta("fuse_tip", "\n\nFuse: drag this onto a slot (or click it) to melt it with another spell.")
		card.set_meta("fuse_id", id)
		card.clicked.connect(func(_c): _click_list(id))
		card.set_drag_forwarding(func(_at): return _begin_drag(card, id, -1), Callable(), Callable())
		_grid.add_child(card)
	for k in 2:  # the slots
		var box: PanelContainer = _slot_box[k]
		for c in box.get_children():
			c.queue_free()
		var id: String = _slots[k]
		if id == "":
			var hint := UiTheme.label("1st spell\nits pattern goes first" if k == 0 else "2nd spell\nits pattern goes after", 20, Color(1, 0.9, 0.75, 0.7))
			hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			hint.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
			box.add_child(hint)
		else:
			var card := SpellCard.make(run.spell(id))
			var slot := k
			card.clicked.connect(func(_c): _unslot(slot))
			card.set_drag_forwarding(func(_at): return _begin_drag(card, id, slot), Callable(), Callable())
			box.add_child(card)
	for c in _result_box.get_children():
		c.queue_free()
	_out = null
	_fuse_btn.disabled = _slots[0] == "" or _slots[1] == ""
	if _slots[0] != "" and _slots[1] != "":
		_preview = run.fuse_preview(_slots[0], _slots[1])
		_out = SpellCard.make(_preview)
		_result_box.add_child(_out)
		_status.text = _pattern_notes(_preview)
	else:
		_preview = {}
		var first: String = _slots[0] if _slots[0] != "" else _slots[1]
		if first == "":
			_status.text = Keywords.colorize("Drag the first spell onto the left slot: its pattern goes first.")
		elif run.spell(first).get("anti", false):
			_status.text = Keywords.colorize("Now another anti-spell: drag it onto the empty slot. Either pattern will break the new one.")
		else:
			_status.text = Keywords.colorize("Now the other spell: drag it onto the empty slot.")
	if not _fly.is_empty():
		_run_fly.call_deferred()


## A card runs from where it was (a slot) down to its place in the spell list.
func _run_fly() -> void:
	await get_tree().process_frame
	var jobs := _fly.duplicate()
	_fly.clear()
	for j in jobs:
		for c in _grid.get_children():
			if c.get_meta("fuse_id", "") != j.id or c.is_queued_for_deletion():
				continue
			var ghost := SpellCard.make(run.spell(j.id))
			ghost.mouse_filter = Control.MOUSE_FILTER_IGNORE
			ghost.z_index = 50
			add_child(ghost)
			ghost.global_position = j.from
			c.modulate.a = 0.0
			var tw := create_tween()
			tw.tween_property(ghost, "global_position", c.global_position, 0.3).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
			tw.tween_callback(func():
				if is_instance_valid(c):
					c.modulate.a = 1.0
				ghost.queue_free())
			break


func _begin_drag(card: SpellCard, id: String, from: int) -> Variant:
	_drag = {"id": id, "from": from}
	var pv := Control.new()
	var c := SpellCard.make(run.spell(id))
	c.zoom = 0.7
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.position = -Vector2(SpellCard.W, SpellCard.H) * 0.35
	pv.add_child(c)
	card.set_drag_preview(pv)
	return {"fuse": id, "from": from}


## Can this spell go in a slot next to what's already in the slots? (Anti-spells only with anti-spells.)
func _fits(id: String, ignore_slot := -1) -> bool:
	for k in 2:
		if k != ignore_slot and _slots[k] != "" and _slots[k] != id and not run.can_fuse_pair(_slots[k], id):
			return false
	return true


func _can_drop_slot(d: Variant) -> bool:
	return d is Dictionary and d.has("fuse")


func _drop_slot(k: int, d: Variant) -> void:
	var id: String = d.fuse
	var from: int = d.from
	if from == k:
		return
	if from < 0 and not _fits(id, k):
		return  # an anti-spell can't go with a spell (or the other way round)
	var old: String = _slots[k]
	if from >= 0:
		_slots[from] = old  # slot to slot: the two swap
	elif old != "":
		_push_back(k)  # the card that was there runs back down
	_slots[k] = id
	_drag = {}
	_refresh.call_deferred()


func _can_drop_list(_at: Vector2, d: Variant) -> bool:
	return d is Dictionary and d.has("fuse") and d.from >= 0


func _drop_list(_at: Vector2, d: Variant) -> void:
	_unslot(d.from)
	_drag = {}


## Take the card out of slot k: it runs down to the list.
func _unslot(k: int) -> void:
	if _slots[k] == "":
		return
	_push_back(k)
	_slots[k] = ""
	_refresh.call_deferred()


func _push_back(k: int) -> void:
	var box: PanelContainer = _slot_box[k]
	_fly.append({"id": _slots[k], "from": box.global_position})


func _click_list(id: String) -> void:
	if not run.can_fuse(id):
		return
	var k := 0 if _slots[0] == "" else 1  # the first empty slot; both full: the second one gives way
	if not _fits(id, k):
		return
	if _slots[k] != "":
		_push_back(k)
	_slots[k] = id
	_refresh.call_deferred()


## A card dragged out of a slot and let go anywhere that isn't a slot leaves it too.
func _notification(what: int) -> void:
	if what == NOTIFICATION_DRAG_END:
		if not _drag.is_empty() and _drag.from >= 0 and not get_viewport().gui_is_drag_successful():
			_unslot(_drag.from)
		_drag = {}


func _commit() -> void:
	if _busy or _slots[0] == "" or _slots[1] == "" or _preview.is_empty():
		return
	_busy = true
	var a := run.spell(_slots[0])
	var b := run.spell(_slots[1])
	var from_a: Vector2 = _slot_box[0].global_position
	var from_b: Vector2 = _slot_box[1].global_position
	run.fuse_commit(_preview, _slots[0], _slots[1])
	await _play_fusion(a, b, from_a, from_b, _preview)
	fused.emit(_preview)


# ------------------------------------------------------------------ your other spells

## Every spell you own except the two being fused: the active row first (in its order), then the rest.
func _other_ids() -> Array:
	var out: Array = run.loadout.filter(func(id): return not (id in _slots))
	for id in run.spellbook:
		if not (id in _slots) and not (id in out):
			out.append(id)
	return out


## What the new pattern means for your other spells: an anti-spell whose pattern is inside it would be broken
## every time you cast the new spell; an active spell whose pattern is inside it wakes along with it. (BBCode.)
func _pattern_notes(sp: Dictionary) -> String:
	var p: String = sp.get("pattern", "")
	var lines := [Keywords.colorize("The new spell is ready. Fuse them when you're happy, or swap a spell out.")]
	for id in _other_ids():
		var o := run.spell(id)
		if o.get("anti", false):
			for pat in o.get("patterns", [o.pattern]):
				if String(pat) != "" and not Chant.occurrences(String(pat), p).is_empty():
					lines.append("[color=#ff7a6b]⚠ Its pattern contains %s's pattern: chanting it would break %s.[/color]" % [o.name.xml_escape(), o.name.xml_escape()])
					break
		elif id in run.loadout and String(o.pattern) != "" and not Chant.occurrences(String(o.pattern), p).is_empty():
			lines.append(Keywords.colorize("✦ Chanting it also wakes %s." % o.name))
	return "\n".join(lines)


## An overlay with all your other spells, so you can plan the fusion around them. Click anywhere (or Esc) to close.
func _show_others() -> void:
	if _others != null:
		return
	_others = Control.new()
	_others.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_others.mouse_filter = Control.MOUSE_FILTER_STOP
	_others.z_index = 80
	var shade := ColorRect.new()
	shade.color = Color(0.03, 0.04, 0.03, 0.96)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_others.add_child(shade)
	var v := VBoxContainer.new()
	v.position = Vector2(60, 50)
	v.size = Vector2(1800, 980)
	v.add_theme_constant_override("separation", 10)
	_others.add_child(v)
	v.add_child(UiTheme.heading("Your other spells", 34, Color(1, 0.85, 0.6)))
	var sub := "Anti-spells are marked: make sure the new pattern doesn't contain theirs. Click anywhere or press Esc to close."
	if not _preview.is_empty():
		sub = "The new pattern: %s.   %s" % [" ".join(Array(String(_preview.pattern).split("")).map(func(c): return Elements.NAMES.get(c, c))), sub]
	var sl := UiTheme.label(sub, 18, UiTheme.MUTED)
	sl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(sl)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(scroll)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 10)
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(col)
	var ids := _other_ids()
	var active: Array = ids.filter(func(id): return id in run.loadout)
	var rest: Array = ids.filter(func(id): return not (id in run.loadout))
	for group in [["Active row, in order (left to right)", active], ["Spellbook", rest]]:
		if group[1].is_empty():
			continue
		col.add_child(UiTheme.label(group[0], 20, Color(1, 0.9, 0.7)))
		var flow := HFlowContainer.new()
		flow.add_theme_constant_override("h_separation", 12)
		flow.add_theme_constant_override("v_separation", 12)
		col.add_child(flow)
		for id in group[1]:
			var sp := run.spell(id)
			var cell := VBoxContainer.new()
			cell.add_child(SpellCard.make(sp))
			if sp.get("anti", false):
				var tag := UiTheme.label("ANTI-SPELL", 16, Color(1, 0.45, 0.4))
				tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
				cell.add_child(tag)
			flow.add_child(cell)
	_others.gui_input.connect(func(ev):
		if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
			_close_others())
	add_child(_others)


func _close_others() -> void:
	if _others != null:
		_others.queue_free()
		_others = null


func _unhandled_key_input(ev: InputEvent) -> void:
	if _others != null and ev.pressed and (ev as InputEventKey).keycode == KEY_ESCAPE:
		get_viewport().set_input_as_handled()
		_close_others()


# ------------------------------------------------------------------ the fusion

## The two cards twist into each other in a tightening spiral, flaring white, and collapse into a white-hot ball.
## The ball becomes the new card, and a drop of purple wax seals one Essence of it (you choose which).
func _play_fusion(a: Dictionary, b: Dictionary, from_a: Vector2, from_b: Vector2, result: Dictionary) -> void:
	var stage := Control.new()
	stage.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	stage.mouse_filter = Control.MOUSE_FILTER_STOP
	stage.z_index = 90
	add_child(stage)
	var shade := ColorRect.new()
	shade.color = Color(0, 0, 0, 0)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stage.add_child(shade)
	create_tween().tween_property(shade, "color:a", 0.85, 0.3)
	var view_size := get_viewport_rect().size
	var mid := Vector2(view_size.x / 2.0, 430)  # the middle of the screen (it can be wider than 1920)
	var half := Vector2(SpellCard.W, SpellCard.H) / 2.0
	# the two cards live in a picture of their own (a SubViewport) so the black hole can bend the picture
	var vp := SubViewport.new()
	vp.size = Vector2i(view_size)
	vp.transparent_bg = true
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	stage.add_child(vp)
	var vroot := Control.new()
	vroot.theme = UiTheme.get_theme()
	vroot.size = view_size
	vp.add_child(vroot)
	var view := TextureRect.new()
	view.texture = vp.get_texture()
	view.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var hole_mat := ShaderMaterial.new()
	hole_mat.shader = load("res://assets/card/black_hole.gdshader")
	hole_mat.set_shader_parameter("center", mid)
	hole_mat.set_shader_parameter("size", view_size)
	view.material = hole_mat
	stage.add_child(view)
	var cards: Array = []
	for k in 2:
		var c := SpellCard.make(a if k == 0 else b)
		c.mouse_filter = Control.MOUSE_FILTER_IGNORE
		vroot.add_child(c)
		c.position = (from_a if k == 0 else from_b) - stage.global_position
		cards.append(c)
	# 1. they rise to either side of the middle
	var tw := create_tween().set_parallel()
	for k in 2:
		tw.tween_property(cards[k], "position", mid - half + Vector2(-260 if k == 0 else 260, 0), 0.4).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	await tw.finished
	Audio.play("spell_glow")
	# 2. a black hole opens between them and swallows them: they stretch into long strands, wound in a spiral,
	# drawn faster and faster into the dark (spaghettified), while sparks spiral in after them
	var dur := 1.9
	var t0 := Time.get_ticks_msec() / 1000.0
	while true:
		var t := clampf((Time.get_ticks_msec() / 1000.0 - t0) / dur, 0.0, 1.0)
		hole_mat.set_shader_parameter("hole", 46.0 * smoothstep(0.0, 0.25, t) * (1.0 - 0.55 * smoothstep(0.85, 1.0, t)))
		hole_mat.set_shader_parameter("twist", 14.0 * t * t)
		hole_mat.set_shader_parameter("pull", pow(t, 2.6))
		for k in 2:  # they drift in a little too, so the strands wrap round the hole
			var c: SpellCard = cards[k]
			c.position = mid - half + Vector2(-260 if k == 0 else 260, 0) * (1.0 - 0.35 * t)
		if randf() < 0.7:
			var col := Color(1, 0.95, 0.85) if randf() < 0.5 else Color(0.75, 0.5, 1.0)
			var ang := randf() * TAU
			var far := randf_range(160.0, 380.0)
			var p := mid + Vector2.from_angle(ang) * far
			var vel := (Vector2.from_angle(ang + PI / 2.0) * 0.9 - Vector2.from_angle(ang) * 0.6) * far * 2.2
			_vfx(stage).part(p, vel, col, 0.45, randf_range(3, 7), Vfx.SPARK)
		if t >= 1.0:
			break
		await get_tree().process_frame
	view.queue_free()
	vp.queue_free()
	# 3. a white-hot ball
	Audio.play("discovery_unlock")
	_vfx(stage).flash(Color(1, 1, 1, 0.8), 0.25)
	_vfx(stage).ring(mid, 20, 320, Color(1, 0.95, 0.85), 0.5, 10.0)
	_vfx(stage).burst(mid, 30, Color(1, 0.97, 0.88), Vector2(250, 750), Vector2(0.3, 0.7), Vector2(4, 9), Vfx.SPARK)
	var ball := HotBall.new()
	ball.position = mid - stage.global_position
	stage.add_child(ball)
	var bt := create_tween()
	bt.tween_property(ball, "radius", 70.0, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	await bt.finished
	await get_tree().create_timer(0.35).timeout
	# 4. the ball cools into the new spell
	var card := SpellCard.make(result)
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.scale = Vector2(0.15, 0.15)
	card.modulate = Color(6, 6, 6, 0)
	stage.add_child(card)
	await get_tree().process_frame
	# centred on the screen. (Its plain position: setting global_position on a scaled card would place its scaled
	# corner there, and it grows around its centre from the wrong spot.)
	card.pivot_offset = card.size / 2.0
	card.position = mid - stage.global_position - card.size / 2.0
	var ct := create_tween().set_parallel()
	ct.tween_property(card, "scale", Vector2(1.15, 1.15), 0.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	ct.tween_property(card, "modulate", Color(1, 1, 1, 1), 0.7).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	ct.tween_property(ball, "radius", 0.0, 0.4).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	await ct.finished
	var title := UiTheme.heading("Forged: %s!" % result.name, 34, Color(1, 0.85, 0.6))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.size = Vector2(1200, 50)
	title.position = Vector2(mid.x - 600, 70) - stage.global_position
	stage.add_child(title)
	var cont := UiTheme.button("Continue", func(): pass, 22)
	cont.custom_minimum_size = Vector2(240, 54)
	cont.position = Vector2(view_size.x - 300, 990) - stage.global_position
	stage.add_child(cont)
	# 5. a drop of purple wax gathers above the new spell: you click the Essence it seals (a fused anti-spell keeps
	# both its patterns whole, so there is nothing to seal)
	if result.id in run.upgradable():
		cont.disabled = true
		card = await _wax_seal(stage, card, result.id, mid)
	await cont.pressed
	await get_tree().create_timer(0.2).timeout


## The fusion's drop of purple wax: it hangs above the new card, swelling, until you click one of its Essence; then
## it falls onto that Essence, splashes, and seals it (that Essence isn't needed any more). Returns the new card.
func _wax_seal(stage: Control, card: SpellCard, id: String, mid: Vector2) -> SpellCard:
	var top := card.get_global_rect().position.y
	var drop := WaxDrop.new()
	drop.position = Vector2(mid.x, top - 70.0) - stage.global_position
	stage.add_child(drop)
	create_tween().tween_property(drop, "swell", 1.0, 0.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	var hint := UiTheme.label("A drop of purple wax! Click an Essence of the new spell to seal it: it won't be needed any more.", 22, Color(0.9, 0.75, 1.0))
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.size = Vector2(900, 60)
	hint.position = Vector2(mid.x - 450, card.get_global_rect().end.y + 30.0) - stage.global_position
	stage.add_child(hint)
	# pick an Essence: the one under the mouse lights up, a click seals it
	var picked := [-1]
	var orb_at := func(at: Vector2) -> int:
		var orbs := card.live_orbs()
		for k in orbs.size():
			if (orbs[k] as Control).get_global_rect().grow(4.0).has_point(at):
				return k
		return -1
	var on_input := func(ev: InputEvent):
		if picked[0] >= 0:
			return
		if ev is InputEventMouseMotion:
			var over: int = orb_at.call(ev.global_position)
			var orbs := card.live_orbs()
			for k in orbs.size():
				orbs[k].highlight = k == over
				orbs[k].queue_redraw()
			drop.position.x = (orbs[over].get_global_rect().get_center().x if over >= 0 else mid.x) - stage.global_position.x
			stage.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if over >= 0 else Control.CURSOR_ARROW
		elif ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
			picked[0] = orb_at.call(ev.global_position)
	stage.gui_input.connect(on_input)
	while picked[0] < 0:
		await get_tree().process_frame
	stage.gui_input.disconnect(on_input)
	stage.mouse_default_cursor_shape = Control.CURSOR_ARROW
	hint.queue_free()
	# it falls onto that Essence...
	var orb: Control = card.live_orbs()[picked[0]]
	var at := orb.get_global_rect().get_center()
	drop.position.x = at.x - stage.global_position.x
	var ft := create_tween()
	ft.tween_property(drop, "position:y", at.y - 26.0 - stage.global_position.y, 0.28).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	await ft.finished
	drop.queue_free()
	# ...splash, and the seal is pressed in
	Audio.play("sfx_lock_break")
	var fx := _vfx(stage)
	fx.glow(at, 160, Color(0.8, 0.45, 1.0, 0.8), 0.45)
	fx.ring(at, 20, 120, Color(0.8, 0.5, 1.0), 0.4, 8.0)
	for d in fx.burst(at, 18, Color(0.62, 0.25, 0.7), Vector2(120, 360), Vector2(0.4, 0.7), Vector2(4, 8), Vfx.DROP):
		d.grav = Vector2(0, 1000)
		d.size1 = d.size0 * 0.6
	run.seal_spell(id, run.sealable(id)[picked[0]])
	var sealed := SpellCard.make(run.spell(id))
	sealed.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stage.add_child(sealed)
	sealed.pivot_offset = card.pivot_offset
	sealed.position = card.position
	sealed.scale = card.scale
	card.queue_free()
	var sq := sealed.create_tween()
	sq.tween_property(sealed, "scale", card.scale * Vector2(1.06, 0.95), 0.07)
	sq.tween_property(sealed, "scale", card.scale, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	var left := String(run.spell(id).pattern).length()
	var done := UiTheme.label(("Sealed! It now needs %d Essence." % left) if left > 0 else "Sealed! It now wakes on every chant.", 22, Color(0.9, 0.75, 1.0))
	done.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	done.size = Vector2(900, 30)
	done.position = Vector2(mid.x - 450, sealed.get_global_rect().end.y + 30.0) - stage.global_position
	stage.add_child(done)
	for c in stage.get_children():
		if c is Button:
			c.disabled = false
	return sealed


## The fusion's effects layer (a Vfx frees itself once it has nothing left to draw: make a new one then).
var _fxv: Vfx


func _vfx(stage: Control) -> Vfx:
	if not is_instance_valid(_fxv) or _fxv.is_queued_for_deletion():
		_fxv = Vfx.make(stage, 5)
	return _fxv


## The white-hot ball the two cards collapse into: a pulsing core with a soft halo.
class HotBall extends Node2D:
	var radius := 0.0:
		set(v):
			radius = v
			queue_redraw()

	func _process(_d: float) -> void:
		queue_redraw()

	func _draw() -> void:
		if radius <= 0.5:
			return
		var pulse := 1.0 + 0.06 * sin(Time.get_ticks_msec() / 1000.0 * 18.0)
		var r := radius * pulse
		for k in 6:
			var u := 1.0 - k / 6.0
			draw_circle(Vector2.ZERO, r * (1.0 + 1.6 * u), Color(1.0, 0.92, 0.75, 0.07))
		draw_circle(Vector2.ZERO, r, Color(1.0, 0.97, 0.9))
		draw_circle(Vector2.ZERO, r * 0.7, Color(1, 1, 1))


## The drop of purple wax: a teardrop that swells, then falls onto the Essence you chose.
class WaxDrop extends Node2D:
	var swell := 0.0:
		set(v):
			swell = v
			queue_redraw()

	func _draw() -> void:
		var r := 6.0 + 8.0 * swell
		var tail := 8.0 + 18.0 * swell
		var pts := PackedVector2Array()
		for k in 20:
			var a := PI / 2.0 + (k - 10) / 10.0 * PI * 0.92
			pts.append(Vector2(cos(a), sin(a)) * r + Vector2(0, tail))
		pts.append(Vector2.ZERO)
		draw_colored_polygon(pts, Color(0.48, 0.16, 0.6))
		draw_circle(Vector2(-r * 0.3, tail - r * 0.1), r * 0.25, Color(0.85, 0.6, 1.0, 0.8))
