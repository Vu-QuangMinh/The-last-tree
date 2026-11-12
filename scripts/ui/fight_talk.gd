class_name FightTalk
extends RefCounted
## The talk before a fight, the Pianist's scenes and speech bubbles (moved out of fight_screen.gd, docs/plan_dot3_kien_truc.md L15): the code is unchanged except that FightScreen's own members are reached through `scr.`.

var scr: FightScreen


func _init(p_owner: FightScreen) -> void:
	scr = p_owner


var _hm_hold: Array = []  # the Handyman's new hands, kept off the stage while he speaks (ids)


## Talking to a boss before the fight (BossTalk). No fight UI at all: only the stage, the boss and the conversation
## (the HUD slides or fades away: spells, chant, bag and slot machine, HP, bottles, artifacts). The conversation box
## stands where the fight UI will be, under the stage; it shows what was said and the options (each with the Essence it costs, and a green tick at its right end once
## its whole branch has been explored, in any run). Engage! is always there. Then the fight's UI slides back in.
func _talk() -> void:
	var tree := BossTalk.tree_for(scr.fight.talk_id)
	if tree.is_empty():
		return
	scr._talking = true
	var old_gate := scr.gate
	scr.gate = func(_a, _b): return false  # (nothing in the fight can be touched while you talk)
	var away := {scr._player_panel: Vector2(-720, 0), scr._chant_panel: Vector2(0, 520), scr._next_panel: Vector2(520, 0),
		scr._log: Vector2(420, 0), scr._spell_row: Vector2(0, 640)}
	var homes := {}
	for n in away:
		homes[n] = n.position
		n.position += away[n]
	var faded: Array = [scr._bag_panel, scr._hp_bar, scr._hp_label, scr._player_panel, scr._arts, scr._arts_frame, scr._bottles_frame, scr._bottle_row, scr._status_row, scr._debuff_board].filter(func(n): return n != null and is_instance_valid(n))
	if scr._nu_ui and scr._top_layer != null:
		faded.append(scr._top_layer)  # (New UI: its dark blocks, tabs and Menu are all in this layer: the conversation never stands over a HUD)
	for n in faded:
		(n as CanvasItem).modulate.a = 0.0  # (gone while you talk: back once you Engage)
	for v in scr._views.values():
		v.set_talk(true, 0.0, BossTalk.speaker(tree) if v.enemy.is_boss and not v.enemy.has_passive("hand") else "")
	var box := PanelContainer.new()
	var cream := UiTheme.has_dialogue_board()  # (the same cream board as an event's words and the merchant's)
	var talk_art: StyleBox = UiTheme.dialogue_board([FightScreen.TALK_PAD, 22, FightScreen.TALK_PAD, 24]) if cream else UiSkin.box("dialogue_panel", [14, 14, 14, 14], [FightScreen.TALK_PAD, 20, FightScreen.TALK_PAD, 22])
	box.add_theme_stylebox_override("panel", talk_art if talk_art != null else FightScreen._talk_box_style())
	box.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	var c_name := "#8a4a0a" if cream else "#ffcf7a"  # (a speaker's name, the narration and "You:" are darker on the cream board)
	var c_note := "#6a5a44" if cream else "#c8bfa8"
	var c_you := "#1f559e" if cream else "#9ec9ff"
	box.custom_minimum_size = Vector2(FightScreen.TALK_W, 0)
	box.position = Vector2((1920.0 - FightScreen.TALK_W) / 2.0, 545)
	box.z_index = 30
	scr.add_child(box)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 8)
	box.add_child(col)
	var node: Dictionary = tree
	var first_meeting := not BossTalk.met_before(scr.fight.talk_id)  # (some narration only comes the very first time)
	BossTalk.meet(scr.fight.talk_id)
	var said := ""
	var prefix := ""  # (something he says before his answer: "You are a master of this element as well, I see.")
	var chosen := [null]
	var given: Array = []  # artifacts you were given while talking: you get them once the talk is over
	var returned: Array = []  # artifacts you gave back (the Pianist's hand): gone once the talk is over
	while true:
		for c in col.get_children():
			col.remove_child(c)  # (gone right away, so the box measures only what's new)
			c.queue_free()
		# what was said
		var text := RichTextLabel.new()
		text.bbcode_enabled = true
		text.fit_content = true
		text.scroll_active = false
		text.custom_minimum_size = Vector2(FightScreen.TALK_W - 2.0 * FightScreen.TALK_PAD, 0)
		if cream:
			text.add_theme_color_override("default_color", UiTheme.BOARD_INK)
		text.add_theme_font_size_override("normal_font_size", 21)
		text.add_theme_font_size_override("italics_font_size", 21)
		text.add_theme_font_size_override("bold_font_size", 21)
		var lines := []
		if node.has("opening"):
			lines.append("[i][color=#c8bfa8]%s[/color][/i]" % node.opening)
		if node.has("greeting"):
			lines.append("[color=#ffcf7a][b]%s:[/b][/color] \"%s\"" % [BossTalk.speaker(tree), node.greeting])
		if said != "":
			lines.append("[color=#9ec9ff]You:[/color] %s" % said)
		if node.has("first_note") and first_meeting:
			lines.append("[i][color=#c8bfa8]%s[/color][/i]" % node.first_note)
		if node.has("pre"):
			lines.append("[i][color=#c8bfa8]%s[/color][/i]" % node.pre)
		if node.has("reply"):
			lines.append("[color=#ffcf7a][b]%s:[/b][/color] \"%s%s\"%s" % [BossTalk.speaker(tree), prefix, node.reply, (" [i][color=#c8bfa8]%s[/color][/i]" % node.note) if node.has("note") else ""])
		elif node.has("note"):
			lines.append("[i][color=#c8bfa8]%s[/color][/i]" % node.note)
		if node.has("reply2"):
			lines.append("[color=#ffcf7a][b]%s:[/b][/color] \"%s\"%s" % [BossTalk.speaker(tree), node.reply2, (" [i][color=#c8bfa8]%s[/color][/i]" % node.note2) if node.has("note2") else ""])
		text.text = "\n".join(lines).replace("#ffcf7a", c_name).replace("#c8bfa8", c_note).replace("#9ec9ff", c_you)
		col.add_child(text)
		Audio.play_voice(BossTalk.voice_paths(tree, scr.fight.talk_id, node))  # (his recorded line, if there is one)
		if node.has("show"):
			# an artifact he's offering: hover it to read it
			var a := Artifacts.view(String(node.show))
			var chip := TipPanel.new()
			chip.add_theme_stylebox_override("panel", FightScreen._talk_flat(Color(0.2, 0.14, 0.08, 0.95), Color(0.7, 0.52, 0.26), 1, 8))
			chip.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
			chip.tooltip_text = ArtifactCard.tip(a)
			var al := UiTheme.label("%s %s" % [a.icon, a.name], 19, Color(1.0, 0.9, 0.7))
			al.mouse_filter = Control.MOUSE_FILTER_IGNORE
			chip.add_child(al)
			col.add_child(chip)
		# the options (none left after the last level), and Engage!
		var forced: bool = "engage" in node.get("effects", [])
		var seen_ids := BossTalk.seen()
		if not forced:
			for o in node.get("options", []):
				if o.has("requires") and not (o.requires in seen_ids):
					continue  # (it only comes up once you've heard what it refers to)
				if o.has("needs_artifact") and not scr.fight.has_artifact(String(o.needs_artifact)):
					continue  # (only if you carry it: the Pianist's hand)
				col.add_child(_talk_option(o, seen_ids, chosen))
		var go := Button.new()
		go.text = "Engage!"
		go.pressed.connect(func(): chosen[0] = {"engage": true})
		go.custom_minimum_size = Vector2(230, 46)
		go.size_flags_horizontal = Control.SIZE_SHRINK_END  # (a button the size of its word, at the right: not a bar across the box)
		FightScreen._talk_skin(go, true)
		UiTheme.use_heading_font(go)
		go.add_theme_font_size_override("font_size", 22)
		col.add_child(go)
		if node == tree and Audio.voice_busy():  # his first line: the buttons wait until he has said it (the later ones can be answered at once, which cuts him off)
			var lock: Array = []
			for b in col.find_children("*", "Button", true, false):
				if b == go:
					continue  # (Engage! is never locked: you may cut him off and fight at once)
				lock.append([b, b.disabled])
				b.disabled = true
			_unlock_after_voice(lock)
		await scr.get_tree().process_frame
		box.size = Vector2.ZERO
		box.reset_size()
		box.position = Vector2((1920.0 - box.size.x) / 2.0, maxf(650.0, 1050.0 - box.size.y))  # (under the stage, at the bottom; the HUD is out of the way while he talks)
		chosen[0] = null
		while chosen[0] == null:  # (a line that ends the talk: only Engage! is left, pressed when you've read it)
			await scr.get_tree().process_frame
		Audio.stop_voice()  # (you answered: he stops)
		if chosen[0].has("engage") or forced:
			break
		# you said it: pay, remember, apply, and on to its answer
		var o: Dictionary = chosen[0]
		if o.cost != "":
			scr.fight.talk_pay(o.cost)
			Audio.play("elem_pickup", -4.0)
		BossTalk.mark_seen(o.id)
		prefix = ""
		for fx in o.get("effects", []):
			var f := String(fx)
			if f.begins_with("artifact:"):
				given.append(f.get_slice(":", 1))  # (handed over when the talk is over, not mid-conversation)
			elif f.begins_with("return_artifact:"):
				returned.append(f.get_slice(":", 1))
			elif f == "engage":
				pass
			else:
				scr.fight.talk_effect(f)
		said = o.say
		node = o
		scr._h_hud._refresh_all()
		for v in scr._views.values():
			if v.enemy.is_boss and not v.enemy.has_passive("hand"):
				v.set_talk(true, 0.0, BossTalk.speaker(tree))
	# Engage!
	box.queue_free()
	Audio.play("enemy_intent_show")
	var i := 0
	for n in away:
		var back: Tween = (n as Node).create_tween()
		back.tween_interval(i * 0.06)
		back.tween_property(n, "position", homes[n], 0.5).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		i += 1
	for n in faded:
		if is_instance_valid(n):
			(n as CanvasItem).create_tween().tween_property(n, "modulate:a", 1.0, 0.5)
	for v in scr._views.values():
		v.set_talk(false, 0.5)
	await scr._h_anim._wait(0.6)
	scr.gate = old_gate
	scr._talking = false
	scr._h_hud._refresh_all()
	# what you gave back while talking: gone now
	for aid in returned:
		if scr.run != null:
			scr.run.remove_artifact(aid)
		Events.toast.emit("You gave back %s" % Artifacts.view(aid).name, Color(0.85, 0.85, 1.0))
	# what you were given while talking: yours now, at the end of the talk
	for aid in given:
		scr.run.gain_artifact(aid)
		Audio.play("artifact_get")
		Events.toast.emit("Got %s" % Artifacts.view(aid).name, UiTheme.ACCENT)
		if not scr.test_mode and Artifacts.get_def(aid).get("unlock_by", "") != "" and SaveManager.unlock_artifact(aid):
			Events.toast.emit("%s unlocked" % Artifacts.view(aid).name, Color(1, 0.85, 0.4))  # (and in the pool for good)
	if not given.is_empty() or not returned.is_empty():
		var old_bar := scr._arts
		scr._arts = scr._h_hud._make_arts()
		scr._arts.position = old_bar.position
		scr._top_layer.add_child(scr._arts)
		old_bar.queue_free()
		scr._h_hud._fit_hud_frames()
		scr._h_hud._refresh_all()
	_hypnotize_opening()
	_pianist_start()


func _pianist_start() -> void:
	if scr._song != null or scr.fight.over:
		return
	for v in scr._views.values():
		if v.enemy.has_passive("pianist"):
			Audio.stop_music()  # (no boss music: he is the music)
			scr._song = PianistSong.make(scr.fight.song)
			scr.fight.talk_rewards.append(scr.fight.song)  # (beat him: the score of the piece he played is yours, and unlocked)
			scr.add_child(scr._song)
			scr._song.ended.connect(_pianist_finale)
			if is_instance_valid(v.creature):
				v.creature.song = scr._song
				v.creature.pianist_warm_up()  # (he brings the leg and the hand to the first notes' places...)
			await scr.get_tree().create_timer(FightScreen.PIANIST_LEAD_IN).timeout  # (...and only then the music starts: otherwise the leg would jump)
			if is_instance_valid(scr._song) and not scr.fight.over:
				scr._song.play()
			return


## He turns the page: the hand leaves the keys, the page swings over, a moment of silence. (His turn: you wait.)
func _page_turn(e: EnemyState) -> void:
	var v: EnemyView = scr._views.get(e)
	if v == null or not is_instance_valid(v.creature):
		await scr._h_anim._wait(1.2)
		return
	# the music has stopped: he points at the sign, "Silence, please", three times (a knock on the wood each time: PianistBackRig.KNOCKS), and then turns the page (the paper's sound)
	var total: float = v.creature.pianist_point()
	var spent := 0.0
	for kt in PianistBackRig.KNOCKS:
		await scr.get_tree().create_timer(float(kt) - spent).timeout
		spent = float(kt)
		Audio.play("sfx_knock_wood")
	await scr.get_tree().create_timer(maxf(0.0, total - spent)).timeout
	Audio.play("page_flip")
	var tw := scr.create_tween()
	tw.tween_property(v.creature, "page_flip", 1.0, 1.1).from(0.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await tw.finished
	v.creature.page_flip = -1.0
	scr._h_hud._sync_views()
	scr._h_hud._refresh_all()
	await scr._h_anim._wait(0.5)


## A page of the Pianist's ran out during your turn (a spell, a bottle): your turn ends there, without a Release,
## and he turns the page.
func _page_turn_check() -> void:
	if scr.fight.page_turn_pending and not scr.fight.over:
		scr.busy = true
		scr.chant_idx.clear()
		scr._prompt.text = "He stops playing…"
		scr._h_hud._refresh_all()
		await scr.fight.pass_turn()
		await scr._h_anim._after_turn()


func _pianist_finale() -> void:
	if scr.fight.over:
		return
	for v in scr._views.values():
		if v.enemy.has_passive("pianist") and is_instance_valid(v.creature):
			v.creature.flash = 1.0
	Audio.play("piano_slam")
	for v in scr._views.values():
		if v.enemy.has_passive("pianist") and is_instance_valid(v.creature):
			v.creature.pianist_slam()
	scr._h_anim._shake(16.0)
	scr._h_anim._slam("The End", Color(0.95, 0.92, 0.85), Color(0.1, 0.05, 0.05), 150)
	scr.fight.song_ends()
	scr._h_hud._refresh_all()
	await scr.get_tree().create_timer(2.0).timeout
	if not scr.busy:
		await scr._h_anim._finish()  # (a turn in progress ends itself: it sees the fight is over)


## Violet Eyes: as the fight starts its human eyes shine brightly.
func _hypnotize_opening() -> void:
	for v in scr._views.values():
		if v.enemy.id == "veiled_eyes" and is_instance_valid(v.creature):
			v.creature.hypnotize()
			Audio.play("spell_glow")
			scr._h_anim._callout_beside(v, "[i]The beautiful eyes hypnotize you.[/i]", Color(0.75, 0.5, 1.0), 3.2)


func _unlock_after_voice(lock: Array) -> void:
	while Audio.voice_busy() and scr.is_inside_tree():
		await scr.get_tree().process_frame
	for l in lock:
		if is_instance_valid(l[0]):
			l[0].disabled = l[1]


## One thing you can say: its Essence cost on the left, the words, and a green tick at the right end once its whole
## branch has been explored. Greyed out when you don't have the Essence it costs.
func _talk_option(o: Dictionary, seen_ids: Array, chosen: Array) -> Button:
	var b := Button.new()
	b.disabled = not scr.fight.can_talk_pay(o.cost)
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN  # (as wide as its words, not a bar across the box)
	FightScreen._talk_skin(b, false)
	b.pressed.connect(func(): chosen[0] = o)
	var n_cost := 0 if scr.fight.talk_free else String(o.cost).length()
	var font := UiTheme.get_theme().get_default_font()
	var words_w := font.get_string_size(String(o.say), HORIZONTAL_ALIGNMENT_LEFT, -1, 20).x
	var w := 16.0 + (30.0 * n_cost + 10.0 if n_cost > 0 else 0.0) + words_w + 10.0 + 30.0 + 16.0
	b.custom_minimum_size = Vector2(clampf(w, 300.0, FightScreen.TALK_W - 2.0 * FightScreen.TALK_PAD), 44)
	var row := HBoxContainer.new()
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	row.offset_left = 16
	row.offset_right = -16
	row.add_theme_constant_override("separation", 10)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(row)
	var cost := HBoxContainer.new()  # (one icon per Essence it costs: "FF" is two Fire)
	cost.add_theme_constant_override("separation", 2)
	for ch in ("" if scr.fight.talk_free else String(o.cost)):  # (test mode: free, so no price shown)
		cost.add_child(ElementIcon.make(ch, 30))
	cost.custom_minimum_size = Vector2(30 * maxi(1, String(o.cost).length()), 30) if n_cost > 0 else Vector2.ZERO
	cost.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	cost.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(cost)
	var words := UiTheme.label(String(o.say), 20, Color(0.97, 0.91, 0.78) if not b.disabled else Color(0.55, 0.5, 0.45))
	words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	words.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	words.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(words)
	var tick := UiTheme.label("✔" if BossTalk.exhausted(o, seen_ids) else "", 24, Color(0.35, 0.9, 0.4))
	tick.custom_minimum_size = Vector2(30, 0)
	tick.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	tick.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	tick.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(tick)
	return b


## An enemy says something: a speech bubble over its head for a moment (the Invoker's Quas / Wex / Exort).
func _speech(e: EnemyState, text: String, hold := 1.0) -> void:
	var v: EnemyView = scr._views.get(e)
	if v == null or not is_instance_valid(v):
		return
	await _speech_bubble(func(): return v.creature.global_position + Vector2(v.creature.size.x * 0.75, 10.0), text, hold)


## The Handyman, his first two hands down: "Very well." "How about..." "THESE!" from his body, and only then do his
## next two hands burst out of his shoulders, the stage shaking as they unfold.
func _hm_new_hands(ids: Array, lines: Array) -> void:
	_hm_hold = ids.duplicate()
	scr._h_hud._sync_views()
	var head := func() -> Vector2:
		if scr._hm_stage != null and is_instance_valid(scr._hm_stage):
			var sq := scr._hm_stage.body_square()
			return scr._hm_stage.global_position + sq.position + Vector2(sq.size.x * 0.72, sq.size.y * 0.12)
		return Vector2(1060, 160)
	for line in lines:
		await _speech_bubble(head, line, 0.6 + String(line).split(" ").size() / 3.0)
	_hm_hold.clear()
	scr._h_hud._sync_views()
	scr._h_hud._refresh_all()
	Audio.play("boss_phase_change")
	scr._h_anim._shake(16.0)  # (the impact of the arms unfolding)
	await scr._h_anim._wait(0.18)
	scr._h_anim._shake(12.0)
	await scr._h_anim._wait(0.5)


## An enemy's black speech bubble at head_at() (asked once the bubble has its size), held `hold` seconds.
func _speech_bubble(head_at: Callable, text: String, hold := 1.0) -> void:
	var bubble := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.07, 0.06, 0.08, 0.96)  # (enemies speak in black bubbles)
	sb.border_color = Color(0.75, 0.7, 0.85)
	sb.set_border_width_all(3)
	sb.set_corner_radius_all(18)
	sb.content_margin_left = 16
	sb.content_margin_right = 16
	sb.content_margin_top = 6
	sb.content_margin_bottom = 6
	var bubble_art := UiSkin.frame("bubble_dark", 16, [20, 8, 20, 8])  # (the painted dark plaque; the flat box is only for a missing picture)
	bubble.add_theme_stylebox_override("panel", (bubble_art as StyleBox) if bubble_art != null else sb)
	bubble.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bubble.z_index = 90
	var l := UiTheme.label(text, 30, Color(0.96, 0.94, 0.9))
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bubble.add_child(l)
	scr._fx.add_child(bubble)
	await scr.get_tree().process_frame
	var head: Vector2 = head_at.call()
	bubble.global_position = head - Vector2(0, bubble.size.y)
	bubble.pivot_offset = Vector2(0, bubble.size.y)
	bubble.scale = Vector2(0.3, 0.3)
	var tw := bubble.create_tween()
	tw.tween_property(bubble, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_interval(hold)
	tw.tween_property(bubble, "modulate:a", 0.0, 0.3)
	tw.tween_callback(bubble.queue_free)
	Audio.play("enemy_intent_show")
	await scr._h_anim._wait(hold + 0.35)


## The Anxious Armadillo, beaten: he doesn't break. He turns sad and begs; he tries to hop away to the right like a
## doll on its stand (slowly); at 80% of the stage his string tugs him up a little, he says "Oh no.", and it yanks him up
## off the screen. From up there (out of sight) he keeps begging. Then silence, and the usual victory. The player can't
## do anything until it's over.
func _armadillo_ending(e: EnemyState) -> void:
	var v: EnemyView = scr._views.get(e)
	if v == null or not is_instance_valid(v):
		return
	var block := Control.new()  # (nothing can be clicked meanwhile)
	block.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	block.mouse_filter = Control.MOUSE_FILTER_STOP
	block.z_index = 200
	scr.add_child(block)
	await scr._h_anim._wait(0.6)
	# a stand-in we can move freely, exactly where he stands; his own view goes away
	var src := v.creature
	var doll := Creature.new()
	doll.setup(e)
	doll.size = src.size
	doll.z_index = 70
	doll.mouse_filter = Control.MOUSE_FILTER_IGNORE
	scr.add_child(doll)
	doll.global_position = src.global_position
	doll.pivot_offset = Vector2(doll.size.x / 2.0, doll.size.y)
	v.visible = false
	# sad (the sad picture when there is one; a placeholder: a cold, pale tint)
	doll.sad_forever = true
	doll.modulate = Color(0.72, 0.78, 1.0)
	for line in ["Stop, please.", "It hurts.", "I can't take this anymore."]:
		await _dillo_say(_dillo_head(doll), line, 3.0)
	# he tries to get away: little hops to the right, like a bouncing doll, slowly (about 10 s)
	var stage_w := scr.get_viewport_rect().size.x
	var goal := stage_w * 0.8 - doll.size.x / 2.0
	var hops := 20
	var dx := (goal - doll.global_position.x) / hops
	var floor_y := doll.global_position.y
	for k in hops:
		var tw := doll.create_tween()
		tw.set_parallel()
		tw.tween_property(doll, "global_position:x", doll.global_position.x + dx, 0.5)
		tw.tween_property(doll, "rotation", 0.09 if k % 2 == 0 else -0.09, 0.25).set_trans(Tween.TRANS_SINE)
		tw.chain().tween_property(doll, "rotation", 0.0, 0.25).set_trans(Tween.TRANS_SINE)
		var up := doll.create_tween()
		up.tween_property(doll, "global_position:y", floor_y - 20.0, 0.22).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		up.tween_property(doll, "global_position:y", floor_y, 0.28).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		Audio.play("sfx_card_hit", -14.0, randf_range(0.9, 1.15))
		await up.finished
	# his string (it hangs from above the screen to the top of his head)
	var string := Line2D.new()
	string.width = 3.0
	string.default_color = Color(0.92, 0.9, 0.82, 0.9)
	string.z_index = 69
	scr.add_child(string)
	var head := _dillo_head(doll)
	var drop := scr.create_tween()
	drop.tween_method(func(y: float): string.points = PackedVector2Array([Vector2(head.x, -40), Vector2(head.x, y)]), -40.0, head.y, 0.35)
	await drop.finished
	await scr._h_anim._wait(0.4)
	# a tug: up about 3 cm, then a pause
	var tug := doll.create_tween()
	tug.tween_property(doll, "global_position:y", floor_y - 110.0, 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	await _dillo_follow(string, doll, tug)
	Audio.play("sfx_card_hit", -6.0, 0.8)
	await scr._h_anim._wait(1.0)
	await _dillo_say(_dillo_head(doll), "Oh no.", 1.6)
	await _dillo_say(_dillo_head(doll), "Oh @##%#, @$%@ me, #@%$.", 2.2)  # (swearing, censored)
	await _dillo_say(_dillo_head(doll), "No no no NO!", 1.6)
	# the yank: very fast and violent, right off the top of the screen
	var top_x := _dillo_head(doll).x
	var yank := doll.create_tween().set_parallel()
	yank.tween_property(doll, "global_position:y", -doll.size.y - 400.0, 0.24).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN)
	yank.tween_property(doll, "rotation", randf_range(-0.7, 0.7), 0.24)
	scr._h_anim._shake(14.0)
	Audio.play("sfx_card_break", -2.0)
	await _dillo_follow(string, doll, yank)
	string.queue_free()
	doll.visible = false
	# from up there, out of sight, he keeps begging
	var up_there := Vector2(top_x, 20.0)
	for line in [["Please, let me go.", 2.6], ["I won't do it again.", 2.6], ["I swear.", 2.0], ["Please, have some mercy.", 2.8], ["Aaaagrggghrgh!", 2.6]]:
		await _dillo_say(up_there, line[0], line[1], true)
	await scr._h_anim._wait(5.0)
	doll.queue_free()
	block.queue_free()


## Where his bubbles start: the top middle of the picture (the painted part when it's a puppet).
func _dillo_head(doll: Creature) -> Vector2:
	var b := doll.puppet_bounds()
	if b.size == Vector2.ZERO:
		b = Rect2(Vector2(doll.size.x * 0.25, doll.size.y * 0.25), Vector2(doll.size.x * 0.5, doll.size.y * 0.6))
	return doll.global_position + Vector2(b.position.x + b.size.x / 2.0, b.position.y)


## The string follows him while a tween moves him.
func _dillo_follow(string: Line2D, doll: Creature, tw: Tween) -> void:
	while tw.is_running():
		var h := _dillo_head(doll)
		string.points = PackedVector2Array([Vector2(h.x, -40), h])
		await scr.get_tree().process_frame


## One of his lines: a black bubble at `at` (its tail corner), held `hold` seconds. `hanging`: it hangs down from there
## (he's above the screen).
func _dillo_say(at: Vector2, text: String, hold: float, hanging := false) -> void:
	var bubble := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.07, 0.06, 0.08, 0.96)
	sb.border_color = Color(0.75, 0.7, 0.85)
	sb.set_border_width_all(3)
	sb.set_corner_radius_all(18)
	sb.content_margin_left = 16
	sb.content_margin_right = 16
	sb.content_margin_top = 6
	sb.content_margin_bottom = 6
	var bubble_art := UiSkin.frame("bubble_dark", 16, [20, 8, 20, 8])  # (the painted dark plaque; the flat box is only for a missing picture)
	bubble.add_theme_stylebox_override("panel", (bubble_art as StyleBox) if bubble_art != null else sb)
	bubble.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bubble.z_index = 210
	var l := UiTheme.label(text, 30, Color(0.96, 0.94, 0.9))
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bubble.add_child(l)
	scr.add_child(bubble)
	await scr.get_tree().process_frame
	var w := bubble.size
	var pos := at + (Vector2(-w.x / 2.0, 0.0) if hanging else Vector2(10.0, -w.y))
	pos.x = clampf(pos.x, 16.0, scr.get_viewport_rect().size.x - w.x - 16.0)
	bubble.global_position = pos
	bubble.pivot_offset = Vector2(w.x / 2.0, 0.0) if hanging else Vector2(0, w.y)
	bubble.scale = Vector2(0.3, 0.3)
	var tw := bubble.create_tween()
	tw.tween_property(bubble, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_interval(maxf(0.2, hold - 0.5))
	tw.tween_property(bubble, "modulate:a", 0.0, 0.3)
	tw.tween_callback(bubble.queue_free)
	Audio.play("enemy_intent_show")
	await scr._h_anim._wait(hold)
