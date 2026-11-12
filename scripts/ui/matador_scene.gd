class_name MatadorScene
extends Control
## The Crowned Matador (an event, any act; docs/story.md): a matador with a kingly crown and a golden mask holds out a red
## cloth with 5 Essence. A dice game: only the slot machine and two rows of 5 slots show (no other HUD), centred. Five
## Essence roll into the bottom row; click them up into the top row (in that order) and back. Reroll (twice a game, once
## something is on top) throws the top row back into the machine and that many new ones roll out. Commit (all 5 on top)
## Releases them at the cloth: it loses the longest start of its row found in your 5 (the usual Release).
##   0: he laughs and challenges you (his fight: still to be designed). 1-2: sarcastic applause. 3-4: impressed, one
##   question. 5: excited, one question, then a boss of this act if you dare (you can't die in it).
## 20 Leaves per point of damage. The questions: MatadorLore. Drawn in code until he has art.

signal finished(result: String)  # "leave", or "boss" (the trial: a boss of this act)

const SLOTS := 5
const REROLLS := 2
const LEAVES_PER := 20
const ORB_PX := 64.0
const SLOT_GAP := 14.0
const TOP_Y := 690.0
const BOTTOM_Y := 790.0
const MAN_X := 1010.0  # his feet
const FEET_Y := 640.0
const CLOTH_ORB := 40.0

var run: RunState
var on_stage := false
var rng := RandomNumberGenerator.new()
var _cloth: Array = []  # its 5 Essence
var _cloth_left := 5
var _bag: Array = []  # the bottom row: Essence letters ("" = empty)
var _top: Array = []  # the top row, in the order put in
var _rerolls := REROLLS
var _busy := false
var _gone := false  # he fell into his vortex
var _man: _Matador
var _cloth_icons: Array = []
var _top_slots: Array = []
var _bag_slots: Array = []
var _reroll_btn: Button
var _commit_btn: Button
var _machine: SlotMachine
var _box: PanelContainer
var _box_v: VBoxContainer
var _game_layer: Control


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	theme = UiTheme.get_theme()
	rng.randomize()
	for i in SLOTS:
		_cloth.append(Elements.random(rng))
	_man = _Matador.new()
	_man.scene = self
	_man.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_man.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_man)
	_build_cloth()
	_box = PanelContainer.new()
	_box.add_theme_stylebox_override("panel", UiTheme.panel_box(0.94, 14))
	_box.custom_minimum_size = Vector2(1100, 0)
	_box.position = Vector2(410, 900)
	_box.z_index = 30
	add_child(_box)
	_box_v = VBoxContainer.new()
	_box_v.add_theme_constant_override("separation", 10)
	_box.add_child(_box_v)
	_say("A matador steps out onto the boards: a kingly crown on his head, a golden mask on his face, a red cloth in his hand. He bows.\n\"A game, Chosen One? Strike my cloth. The better you do, the more I tell.\"",
		[["Play", _start_game], ["Walk away", func(): finished.emit("leave")]])


# ------------------------------------------------------------------ the talk box (bottom of the screen)

## Words (narration in italics, his lines in quotes) and buttons [[label, callable], ...] under them.
func _say(text: String, buttons: Array, verse: Array = [], after := "") -> void:
	for c in _box_v.get_children():
		c.queue_free()
	if text != "":
		var l := RichTextLabel.new()
		l.bbcode_enabled = true
		l.fit_content = true
		l.scroll_active = false
		l.custom_minimum_size = Vector2(1060, 0)
		l.add_theme_font_size_override("normal_font_size", 22)
		l.add_theme_font_size_override("italics_font_size", 22)
		l.text = text
		_box_v.add_child(l)
	if not verse.is_empty():
		var v := RichTextLabel.new()
		v.bbcode_enabled = true
		v.fit_content = true
		v.scroll_active = false
		v.custom_minimum_size = Vector2(1060, 0)
		v.add_theme_font_size_override("italics_font_size", 23)
		v.text = "[center][i][color=#ffe6b0]" + "\n".join(verse) + "[/color][/i][/center]"
		_box_v.add_child(v)
	if after != "":
		var a := RichTextLabel.new()
		a.bbcode_enabled = true
		a.fit_content = true
		a.scroll_active = false
		a.custom_minimum_size = Vector2(1060, 0)
		a.add_theme_font_size_override("italics_font_size", 22)
		a.text = "[i]%s[/i]" % after
		_box_v.add_child(a)
	var row := HFlowContainer.new()
	row.add_theme_constant_override("h_separation", 12)
	row.add_theme_constant_override("v_separation", 8)
	row.alignment = FlowContainer.ALIGNMENT_END
	_box_v.add_child(row)
	for b in buttons:
		var btn := UiTheme.button(String(b[0]), b[1], 20)
		btn.custom_minimum_size = Vector2(0, 46)
		row.add_child(btn)
	await get_tree().process_frame
	_box.reset_size()
	_box.position.y = 1060.0 - _box.size.y


func _hide_box() -> void:
	for c in _box_v.get_children():
		c.queue_free()
	await get_tree().process_frame
	_box.reset_size()
	_box.position.y = 1080.0


# ------------------------------------------------------------------ the cloth

func _cloth_pos(i: int) -> Vector2:
	# the cloth hangs from his outstretched arm, to his right (our left): its 5 Essence in a row across it
	return Vector2(MAN_X - 330.0 + i * (CLOTH_ORB + 8.0), FEET_Y - 200.0 + absf(i - 2.0) * 6.0)


func _build_cloth() -> void:
	for i in SLOTS:
		var ic := ElementIcon.make(_cloth[i], CLOTH_ORB)
		ic.position = _cloth_pos(i) - Vector2(CLOTH_ORB, CLOTH_ORB) / 2.0
		ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
		ic.z_index = 5
		add_child(ic)
		_cloth_icons.append(ic)


# ------------------------------------------------------------------ the game

func _start_game() -> void:
	_hide_box()
	_game_layer = Control.new()
	_game_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_game_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_game_layer)
	var w := SLOTS * ORB_PX + (SLOTS - 1) * SLOT_GAP
	var x0 := 960.0 - w / 2.0
	for row in 2:
		for i in SLOTS:
			var slot := Panel.new()
			var art := UiSkin.box("chant_slot_empty")
			if art != null:
				slot.add_theme_stylebox_override("panel", art)
			slot.position = Vector2(x0 + i * (ORB_PX + SLOT_GAP), TOP_Y if row == 0 else BOTTOM_Y)
			slot.size = Vector2(ORB_PX, ORB_PX)
			slot.mouse_filter = Control.MOUSE_FILTER_STOP
			slot.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
			var idx := i
			if row == 0:
				slot.gui_input.connect(func(ev): if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT: _down(idx))
				_top_slots.append(slot)
			else:
				slot.gui_input.connect(func(ev): if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT: _up(idx))
				_bag_slots.append(slot)
			_game_layer.add_child(slot)
	_reroll_btn = UiTheme.button("Reroll", _reroll, 20)
	_reroll_btn.position = Vector2(x0 + w + 24.0, TOP_Y + 8.0)
	_reroll_btn.custom_minimum_size = Vector2(150, 48)
	_game_layer.add_child(_reroll_btn)
	_commit_btn = UiTheme.button("Commit", _commit, 20)
	_commit_btn.position = Vector2(x0 + w + 184.0, TOP_Y + 8.0)
	_commit_btn.custom_minimum_size = Vector2(150, 48)
	_game_layer.add_child(_commit_btn)
	# the slot machine, left of the rows (no tube: the Essence come straight out into the bottom row)
	if SlotMachine.available():
		_machine = SlotMachine.new()
		_machine.build()
		var holder := Control.new()
		holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var sc := 1.25
		var body: Rect2 = PuppetSlotMachine.BODY
		holder.scale = Vector2(sc, sc)
		holder.position = Vector2(x0 - 260.0, TOP_Y - 20.0) - (body.position - PuppetLayout.BAG_AT) * sc
		holder.add_child(_machine.back)
		holder.add_child(_machine.front)
		_game_layer.add_child(holder)
	_bag.resize(SLOTS)
	_bag.fill("")
	_refresh()
	await _roll(SLOTS)


## New Essence roll out of the machine into the empty slots of the bottom row.
func _roll(n: int) -> void:
	_busy = true
	_refresh()
	var els: Array = []
	for k in n:
		els.append(Elements.random(rng))
	if _machine != null:
		Audio.play("sfx_lever_pull", -2.0)
		_machine.lever_pull()
		await get_tree().create_timer(0.3).timeout
		var faces := els.slice(0, 3)
		while faces.size() < 3:
			faces.append(Elements.random(rng))  # (the reels always show three)
		await _machine.spin(faces, 1.2)
		_machine.lever_return()
		_machine.busy = false
	var k := 0
	for i in SLOTS:
		if _bag[i] == "" and k < els.size():
			_bag[i] = els[k]
			k += 1
			Audio.play("elem_pickup", -6.0, 1.0 + 0.05 * k)
			_refresh()
			await get_tree().create_timer(0.12).timeout
	_busy = false
	_refresh()


func _up(i: int) -> void:
	if _busy or _bag[i] == "" or _top.size() >= SLOTS:
		return
	_top.append(_bag[i])
	_bag[i] = ""
	Audio.play("elem_pickup", -4.0)
	_refresh()


func _down(i: int) -> void:
	if _busy or i >= _top.size():
		return
	var el: String = _top[i]
	_top.remove_at(i)
	_bag[_bag.find("")] = el
	Audio.play("elem_pickup", -6.0, 0.9)
	_refresh()


func _reroll() -> void:
	if _busy or _top.is_empty() or _rerolls <= 0:
		return
	_rerolls -= 1
	var n := _top.size()
	_top.clear()  # (thrown back into the machine)
	Audio.play("elem_remove", -4.0)
	await _roll(n)


func _refresh() -> void:
	if _game_layer == null:
		return
	for row in 2:
		var slots: Array = _top_slots if row == 0 else _bag_slots
		for i in SLOTS:
			var slot: Panel = slots[i]
			for c in slot.get_children():
				c.queue_free()
			var el: String = (_top[i] if i < _top.size() else "") if row == 0 else String(_bag[i])
			if el != "":
				var ic := ElementIcon.make(el, ORB_PX)
				ic.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
				ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
				slot.add_child(ic)
	_reroll_btn.disabled = _busy or _top.is_empty() or _rerolls <= 0
	_reroll_btn.text = "Reroll (%d)" % _rerolls
	_commit_btn.disabled = _busy or _top.size() < SLOTS


## The top row is Released at the cloth: it loses the longest start of its row found in your 5.
func _commit() -> void:
	if _busy or _top.size() < SLOTS:
		return
	_busy = true
	_refresh()
	var chant := "".join(_top)
	var k := Chant.prefix_match(_cloth, chant)
	var at := Chant.find_hp(_cloth.slice(0, k), chant) if k > 0 else -1
	for p in SLOTS:
		var from: Vector2 = _top_slots[p].global_position + Vector2(ORB_PX, ORB_PX) / 2.0
		if k > 0 and p >= at and p < at + k:
			var j := p - at
			var comet := Comet.launch(self, from, _cloth_pos(j), Elements.COLORS[_top[p]])
			comet.arrived.connect(func():
				Audio.play("sfx_damage_hit", -4.0)
				Vfx.make(self, 60).burst(_cloth_pos(j), 12, Elements.COLORS[_cloth[j]], Vector2(80, 260), Vector2(0.2, 0.45), Vector2(3, 7), Vfx.SPARK)
				if j < _cloth_icons.size() and is_instance_valid(_cloth_icons[j]):
					_cloth_icons[j].queue_free())
		else:
			Comet.launch(self, from, from + Vector2(0, -170), Elements.COLORS[_top[p]], true)
		await get_tree().create_timer(0.3).timeout
	await get_tree().create_timer(0.7).timeout
	_cloth_left = SLOTS - k
	_game_layer.queue_free()
	_game_layer = null
	_result(k)


# ------------------------------------------------------------------ the result

func _result(dmg: int) -> void:
	var gain := dmg * LEAVES_PER
	if gain > 0 and run != null:
		run.amber += gain
		Audio.play("shop_buy", -4.0)
	var leaves := "\n[color=#a8e07a](+%d Leaves)[/color]" % gain if gain > 0 else ""
	match dmg:
		0:
			_man.laugh()
			Audio.play("sfx_head_scream", -8.0, 0.6)
			_say("[i]He laughs in a booming voice.[/i]\n\"Defiance I see. Very good. I challenge thee.\"",
				[["Accept his challenge", _accept_duel], ["Refuse", _refuse_duel]])
		1, 2:
			_man.clap()
			_say("[i]He applauds your effort. Slowly. Sarcastically.[/i]" + leaves, [["Continue", func(): finished.emit("leave")]])
		3, 4:
			_say("[i]He is impressed by your effort.[/i]\n\"Well struck. Ask, and I shall answer. One question.\"" + leaves, [["Ask him", func(): _questions(false)]])
		_:
			_man.clap()
			_say("[i]He is visibly excited by your effort.[/i]\n\"Splendid! Magnificent! Ask, Chosen One. One question.\"" + leaves, [["Ask him", func(): _questions(true)]])


func _accept_duel() -> void:
	# (his own fight is still to be designed: until then he lets you go)
	_say("[i]He raises his cloth and takes his stance... then lowers it again.[/i]\n\"Another night, Chosen One. Another night.\"\n[color=#9aa89a](His fight is not in the game yet.)[/color]",
		[["Continue", func(): finished.emit("leave")]])


func _refuse_duel() -> void:
	_man.nod()
	_say("[i]He is visibly disappointed, but nods politely as you walk away.[/i]", [["Walk away", func(): finished.emit("leave")]])


## One question, from the ones that are open (a tick on the ones asked before).
func _questions(then_challenge: bool) -> void:
	var btns := []
	for q in MatadorLore.open_questions():
		var qq: Dictionary = q
		btns.append([("✓ " if MatadorLore.asked(qq.id) else "") + String(qq.ask), func(): _answer(qq, then_challenge)])
	_say("[i]He waits.[/i]", btns)


func _answer(q: Dictionary, then_challenge: bool) -> void:
	MatadorLore.mark_asked(String(q.id))
	var pre := "[i]%s[/i]" % q.pre if q.has("pre") else ""
	if q.has("choices"):
		# Who are you? He asks you back: whatever you say, he says "Correct." and falls into his hole of despair
		var btns := []
		for c in q.choices:
			btns.append([String(c), _correct])
		_say(pre, btns, q.lines)
		return
	var next := func() -> void:
		if then_challenge and not _gone:
			_challenge()
		else:
			finished.emit("leave")
	_say(pre, [["Continue", next]], q.lines, String(q.get("post", "")))


func _correct() -> void:
	_say("\"Correct.\"", [])
	await get_tree().create_timer(1.2).timeout
	await _hide_box()
	await _man.fall()
	_gone = true
	for ic in _cloth_icons:
		if is_instance_valid(ic):
			ic.queue_free()
	_say("[i]A black vortex opened beneath his feet, and he fell into his hole of despair.[/i]", [["Continue", func(): finished.emit("leave")]])


func _challenge() -> void:
	_say("\"Now then. Will you face your challenge head on?\"\n[color=#9aa89a](A boss of this act. You cannot die in it: lose, and you wake on the map at 1 HP.)[/color]",
		[["Yes", func(): finished.emit("boss")], ["Not today", func(): finished.emit("leave")]])


# ------------------------------------------------------------------ the Matador himself (drawn until he has art)

class _Matador extends Control:
	var scene: MatadorScene
	var _t := 0.0
	var clap_t := -1.0
	var laugh_t := -1.0
	var nod_t := -1.0
	var fall_t := -1.0  # 0..1: the vortex opens and he sinks into it

	func _process(d: float) -> void:
		_t += d
		for k in ["clap_t", "laugh_t", "nod_t"]:
			if get(k) >= 0.0:
				set(k, get(k) + d)
				if get(k) > 2.0:
					set(k, -1.0)
		queue_redraw()

	func clap() -> void:
		clap_t = 0.0

	func laugh() -> void:
		laugh_t = 0.0

	func nod() -> void:
		nod_t = 0.0

	func fall() -> void:
		Audio.play("sfx_lever_pull", -30.0)
		var tw := create_tween()
		tw.tween_property(self, "fall_t", 1.0, 2.2).from(0.0).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		await tw.finished

	func _draw() -> void:
		var feet := Vector2(MatadorScene.MAN_X, MatadorScene.FEET_Y)
		var s := 120.0
		if fall_t >= 0.0:
			# the vortex: a black whirl spreading under his feet
			var vr := s * 1.4 * minf(1.0, fall_t * 2.5)
			for k in 6:
				var u := float(k) / 6.0
				draw_circle(feet + Vector2(0, 6), vr * (1.0 - u * 0.15), Color(0.02, 0.0, 0.05, 0.25 + u * 0.12))
			for k in 4:
				var a0 := _t * 3.0 + k * PI / 2.0
				draw_arc(feet + Vector2(0, 6), vr * 0.7, a0, a0 + 1.4, 18, Color(0.35, 0.1, 0.5, 0.6), 3.0, true)
			if fall_t >= 1.0:
				return
		var sink := 0.0 if fall_t < 0.0 else smoothstep(0.3, 1.0, fall_t) * s * 3.2
		var shrink := 1.0 if fall_t < 0.0 else 1.0 - 0.5 * smoothstep(0.3, 1.0, fall_t)
		var lean := sin(laugh_t * 18.0) * 0.06 if laugh_t >= 0.0 else 0.0
		var nod_a := sin(nod_t * PI) * 0.18 if nod_t >= 0.0 and nod_t < 1.0 else 0.0
		draw_set_transform(feet + Vector2(0, sink), lean, Vector2(shrink, shrink))
		var suit := Color(0.12, 0.06, 0.08)
		var gold := Color(0.95, 0.75, 0.25)
		# legs, the short jacket of a traje de luces, gold braid
		draw_rect(Rect2(-s * 0.22, -s * 0.9, s * 0.16, s * 0.9), suit)
		draw_rect(Rect2(s * 0.06, -s * 0.9, s * 0.16, s * 0.9), suit)
		draw_colored_polygon(PackedVector2Array([Vector2(-s * 0.35, -s * 1.85), Vector2(s * 0.35, -s * 1.85), Vector2(s * 0.3, -s * 0.85), Vector2(-s * 0.3, -s * 0.85)]), Color(0.5, 0.08, 0.1))
		for k in 4:
			draw_line(Vector2(-s * 0.32, -s * (1.75 - k * 0.22)), Vector2(s * 0.32, -s * (1.75 - k * 0.22)), gold, 2.0, true)
		# the arm holding out the cloth (to our left), the cloth itself under the Essence
		var hand := Vector2(-s * 1.0, -s * 1.5)
		draw_line(Vector2(-s * 0.3, -s * 1.7), hand, Color(0.5, 0.08, 0.1), s * 0.1, true)
		var wave := sin(_t * 1.6) * 6.0
		if clap_t >= 0.0:
			wave = sin(clap_t * 30.0) * 10.0
		draw_colored_polygon(PackedVector2Array([hand + Vector2(-s * 2.4, -s * 0.15), hand + Vector2(s * 0.1, -s * 0.15),
			hand + Vector2(s * 0.05, s * 1.0 + wave), hand + Vector2(-s * 2.3, s * 1.1 - wave)]), Color(0.78, 0.06, 0.08))
		draw_circle(hand, s * 0.07, gold)
		# the head: a golden mask that always smiles, a kingly crown on top
		draw_set_transform(feet + Vector2(0, sink) + Vector2(0, -s * 2.05) * shrink, lean + nod_a, Vector2(shrink, shrink))
		draw_circle(Vector2.ZERO, s * 0.26, gold)
		draw_arc(Vector2(0, s * 0.02), s * 0.13, 0.2, PI - 0.2, 12, Color(0.35, 0.22, 0.05), 3.0, true)  # (the smile)
		for side in [-1.0, 1.0]:
			draw_colored_polygon(PackedVector2Array([Vector2(side * s * 0.16, -s * 0.06), Vector2(side * s * 0.05, -s * 0.09), Vector2(side * s * 0.07, -s * 0.02)]), Color(0.05, 0.03, 0.02))
		var crown := PackedVector2Array([Vector2(-s * 0.24, -s * 0.2), Vector2(-s * 0.26, -s * 0.48), Vector2(-s * 0.12, -s * 0.33), Vector2(0, -s * 0.52),
			Vector2(s * 0.12, -s * 0.33), Vector2(s * 0.26, -s * 0.48), Vector2(s * 0.24, -s * 0.2)])
		draw_colored_polygon(crown, Color(1.0, 0.82, 0.25))
		draw_circle(Vector2(0, -s * 0.3), s * 0.04, Color(0.8, 0.1, 0.15))
		draw_set_transform(Vector2.ZERO)
