class_name FightHud
extends RefCounted
## Building and fitting the HUD of every theme (moved out of fight_screen.gd, docs/plan_dot3_kien_truc.md L15): the code is unchanged except that FightScreen's own members are reached through `scr.`.

var scr: FightScreen


func _init(p_owner: FightScreen) -> void:
	scr = p_owner


var _test_btns: Array = []


var _book_btn: Button


var _coin_label: Label  # Puppet Stage: the Leaves in the Character panel


var _minh_lever: TextureRect  # MinhHUD: the lever on the hub


var _lasting_label: Label  # Puppet HUD: "Lasting N" under the HP bar


var _rack_upper: TextureRect  # NewUI Ver2: the rack's upper layer (its cup rims, over the bottles)


func _set_hud_shift(v: float) -> void:
	var d := v - scr._hud_shift
	scr._hud_shift = v
	for n in scr._hud_nodes():
		n.position.y += d
	var k_up := clampf(v / FightScreen.HUD_DOWN, 0.0, 1.0)
	for n in ([] if scr._nu_ui else [scr._status_row, scr._debuff_board]):  # (the debuffs leave over the top edge: they stand at the top left; New UI: they sink with the HUD)
		if n != null and is_instance_valid(n):
			n.position.y -= d / FightScreen.HUD_DOWN * FightScreen.DEBUFF_LIFT
	if scr._menu_btn != null:
		scr._menu_btn.position = _menu_rest().position if scr._nu_ui else _menu_rest().position.lerp(FightScreen.MENU_TOP_AT, k_up)
	_sync_menu_low()
	if _book_btn != null:
		var k := clampf(v / FightScreen.HUD_DOWN, 0.0, 1.0)
		_book_btn.visible = k > 0.02 and not scr.hold_hud
		_book_btn.modulate.a = clampf((k - 0.4) / 0.6, 0.0, 1.0)  # (it appears as the cards sink into it)
		_book_btn.mouse_filter = Control.MOUSE_FILTER_STOP if k > 0.95 else Control.MOUSE_FILTER_IGNORE


## Where the Menu button stands during a fight.
func _menu_rest() -> Rect2:
	return NewUiLayout.MENU_BTN if scr._nu_ui else PuppetTopHud.MENU


func _sync_menu_low() -> void:
	if scr._menu_low != null:
		scr._menu_low.visible = scr._hud_shift > 1.0 and not scr._peek


func _hud_hidden() -> bool:
	return scr.map_mode or scr._hud_shift > 1.0


func _start_down() -> void:
	scr.busy = true
	_set_hud_shift(FightScreen.HUD_DOWN)
	if scr._peek_pending and scr._top_layer != null:
		scr._peek_pending = false
		scr._peek = true
		_sync_menu_low()
		scr._top_layer.position.y -= FightScreen.HUD_DOWN
		if scr._menu_btn != null and not scr._nu_ui:
			scr._menu_btn.position = _menu_rest().position
	if scr.arrive:
		_arrive()


## The Act / Floor / Turn line: a Label, or (Puppet Stage) the wooden letters on the hanging sign, centred on the Label's old spot; the Label stays hidden
## unless the theme has no such art.
func _set_info(text: String) -> void:
	if NewUiLayout.v2:  # (NewUI Ver2: the Act / Floor / Turn line is three lines on the paper)
		scr._info.text = NewUi2Layout.info_text(text)
		if scr._nu_back != null:
			scr._nu_back.info = scr._info.text
			scr._nu_back.queue_redraw()
		return
	if scr._nu_ui:  # ("Act 1 · Floor 5\nTurn 2" -> "Act 1 - Floor 5 - Turn 2")
		scr._info.text = text.replace("\r", "").replace("\n", " - ").replace(" · ", " - ").replace("Act ", "Act")  # (as the page writes it: "Act1 - Floor 5 - Turn 2")
		scr._info.visible = true
		if NewUiLayout.hud2:  # (one line over the artifact tray: smaller if it would stick out of the tray's width)
			var fs := 18
			var f := scr._info.get_theme_font("font")
			while fs > 11 and f.get_string_size(scr._info.text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x > scr._info.size.x - 8.0:
				fs -= 1
			scr._info.add_theme_font_size_override("font_size", fs)
		return
	scr._info.text = text
	if UiSkin.is_puppet():
		scr._info.visible = scr._act_sign != null  # (it stands on the hanging sign)


## The HUD sinks, the Spellbook button comes up in the place of the HP bar.
func _hud_down(secs := 0.9) -> void:
	scr.busy = true
	_lift_act_sign(true)
	_set_info("Act %d · Floor %d" % [scr.run.act, scr.run.floor_no()])
	if _book_btn == null:
		_build_spellbook_button()
	var tw := scr.create_tween()
	tw.tween_method(_set_hud_shift, scr._hud_shift, FightScreen.HUD_DOWN, secs).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	await tw.finished


var _hud_tw: Tween


## The HUD comes up from below the screen. `free_input`: the fight can be played once it is up (false when it is raised early, while the stage is still being set).
func _hud_up(secs := 0.8, free_input := true) -> void:
	_show_act_sign()  # (the fight begins: the Act sign drops; _arrive starts its countdown once everything is out)
	if _hud_tw != null and _hud_tw.is_valid():
		_hud_tw.kill()
	_hud_tw = scr.create_tween()
	var tw := _hud_tw
	tw.tween_method(_set_hud_shift, scr._hud_shift, 0.0, secs).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	await tw.finished
	scr._machine_ready = true
	if free_input:
		scr.busy = false
		_fit_enemy_lift()


var _prepare_on := false


var _prepare_players: Array = []


func _play_prepare(p_name: String) -> void:
	var p := Audio.play_held(p_name, FightScreen.PREPARE_DB.get(p_name, 0.0), randf_range(0.97, 1.03))
	if p != null:
		_prepare_players.append(p)


## While the stage is made ready: the long sound once, then, for as long as that goes on, short ones picked at random, sometimes two overlapping.
func _prepare_sounds() -> void:
	_prepare_on = true
	_play_prepare("sfx_scene_prepare")
	var main_len := 6.0
	var s := Audio.get_sfx_length("sfx_scene_prepare")
	if s > 0.0:
		main_len = s
	await FightWait.seconds(scr, main_len)
	var last := 0
	while _prepare_on and scr.is_inside_tree():
		var k := randi_range(1, 4)
		if k == last:
			k = k % 4 + 1
		last = k
		_play_prepare("sfx_scene_prepare_short_%d" % k)
		if randf() < 0.4:  # (a second one overlapping the first)
			await FightWait.seconds(scr, randf_range(0.4, 1.1))
			if _prepare_on:
				_play_prepare("sfx_scene_prepare_short_%d" % (k % 4 + 1))
		await FightWait.seconds(scr, randf_range(1.2, 2.4))


## Walking on: the old props are cleared away first (that began at the encounter board; if the fight was begun early, it is waited for), then the
## new room's props and enemies come in from the right, and the HUD comes back up as the last of them settle.
func _arrive() -> void:
	_set_enemy_drop(FightScreen.ENEMY_UP)  # (they wait above the screen on their ropes while the old props are cleared; no first frame in their place)
	if scr.rope_mode:
		for e in scr._views:  # (the name would lie over the puppet and hide the spot to click)
			if is_instance_valid(scr._views[e]):
				scr._views[e].hide_name()
		await FightWait.seconds(scr, 0.15)
		_let_enemies_down()
		return
	_prepare_sounds()  # (the stage is being made ready: old props away, new ones and the enemies in)
	if scr._stage.is_clearing():
		await scr._stage.cleared
	var tw := scr._stage.bring_props()
	await FightWait.seconds(scr, 1.2)  # (the enemies are let down after the first props: the props walk on, the puppets hang from their ropes)
	_let_enemies_down()
	await FightWait.seconds(scr, PuppetStage.BRING_TIME - 1.2 - 1.0)
	_prepare_on = false
	for p in _prepare_players:
		Audio.stop_held(p, 0.4)
	_prepare_players.clear()
	if scr.hold_hud:  # (the encounter board is still up: the HUD waits for "Begin the fight")
		scr._arrival_ready = true
		scr.arrival_ready.emit()
		if scr.hold_hud:
			await scr.hud_released
	while _dropping and scr.is_inside_tree():  # (the HUD comes up once the enemies hang in their places)
		await FightWait.frame(scr)
	if scr._talk_pending:
		scr._talk_pending = false
		await _hud_up()
		if tw.is_running():
			await tw.finished
		_show_act_sign(true)
		await FightWait.seconds(scr, 0.6)  # (the cards have landed)
		scr._h_talk._talk()
		return
	_hud_up()
	if tw.is_running():
		await tw.finished
	_show_act_sign(true)  # (the props and the enemies are out: the sign goes up after 10 s)
	scr._h_talk._pianist_start()


var _dropping := false  # (the lift of the Essence rows leaves the row alone while it is let down)


func _set_enemy_drop(off: float) -> void:
	scr._enemy_drop = off
	if scr._enemy_row != null and scr._stage != null:
		scr._enemy_row.position.y = scr._stage.floor_center_y() - FightScreen.ENEMY_FEET_DY - FightScreen.ENEMY_LIFT - scr._extra_lift + off


## The enemies are let down on their ropes: straight down onto their places (the ropes' tops stay put, the rivets drag them), a short fall, then a
## few bobs on the stretched ropes. (The props walk on from the side; the puppets do not.)
func _let_enemies_down() -> void:
	_dropping = true
	var from := scr._enemy_drop
	var tw := scr.create_tween()
	tw.tween_method(func(t: float):
		var off := 0.0
		# (t is in seconds at normal speed)
		if t < FightScreen.ENEMY_LET_DOWN:
			var u := t / FightScreen.ENEMY_LET_DOWN
			off = from * (1.0 - u * u)  # gravity: slow at first, fast at the end
		else:
			var s := t - FightScreen.ENEMY_LET_DOWN
			off = 20.0 * exp(-4.5 * s) * sin(TAU * 1.8 * s)  # the rope stretches: a dip below the place, a bob back
		_set_enemy_drop(off), 0.0, FightScreen.ENEMY_LET_DOWN + FightScreen.ENEMY_SPRING, (FightScreen.ENEMY_LET_DOWN + FightScreen.ENEMY_SPRING) / FightScreen.ENEMY_SPEED)
	await tw.finished
	_set_enemy_drop(0.0)
	_dropping = false


## The Spellbook button (no art for it yet: a wooden plate with a book drawn on it) stands where the HP bar is while the HUD is down.
func _build_spellbook_button() -> void:
	if true:  # (no Spellbook button any more: the spells are arranged on the encounter board)
		return
	var r := PuppetLayout.HP_BAR
	_book_btn = Button.new()
	_book_btn.text = "Spellbook"
	_book_btn.focus_mode = Control.FOCUS_NONE
	_book_btn.position = Vector2(r.position.x, r.position.y - 6.0)
	_book_btn.size = Vector2(290, 64)
	_book_btn.custom_minimum_size = _book_btn.size
	UiTheme.use_heading_font(_book_btn)
	UiTheme.style_puppet_button(_book_btn, "chant", 22, false)
	_book_btn.alignment = HORIZONTAL_ALIGNMENT_CENTER
	_book_btn.text = "   Spellbook"  # (room for the book on the left)
	_book_btn.tooltip_text = "Your spells: the active row and the rest of the book."
	var book := FightScreen.SpellbookIcon.new()
	book.size = Vector2(46, 40)
	book.position = Vector2(16, 12)
	book.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_book_btn.add_child(book)
	_book_btn.pressed.connect(func(): scr.spellbook_pressed.emit())
	_book_btn.z_index = 3
	_book_btn.visible = false
	scr.add_child(_book_btn)


## The Chant and Bag panels of the Default and New themes.
func _build_strips_classic() -> void:
	# chant area: the slots, and the Chant / Release button right beside them
	var cp := PanelContainer.new()
	cp.add_theme_stylebox_override("panel", UiTheme.panel_box(0.9, 14))
	scr._chant_panel = cp
	cp.position = Vector2(540, 742)
	cp.custom_minimum_size = Vector2(1100, 118)
	var chh := HBoxContainer.new()
	chh.add_theme_constant_override("separation", 14)
	cp.add_child(chh)
	var cv := VBoxContainer.new()
	cv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	chh.add_child(cv)
	var ch := HBoxContainer.new()
	cv.add_child(ch)
	var cl := UiTheme.heading("Chant", 18, UiTheme.ACCENT)
	cl.custom_minimum_size = Vector2(70, 0)
	ch.add_child(cl)
	scr._chant_row = HBoxContainer.new()
	scr._chant_row.add_theme_constant_override("separation", 6)
	ch.add_child(scr._chant_row)
	scr._chant_note = UiTheme.label("", 14, UiTheme.MUTED)
	cv.add_child(scr._chant_note)
	var bv := VBoxContainer.new()
	bv.add_theme_constant_override("separation", 6)
	chh.add_child(bv)
	scr._cast_btn = UiTheme.button(UiTheme.hk("Chant", "Enter"), scr._h_input._on_primary, 22)
	UiTheme.use_heading_font(scr._cast_btn)
	scr._cast_btn.custom_minimum_size = Vector2(250, 60)
	var chant_art := UiTheme.chant_button_styles()
	for st in chant_art:
		scr._cast_btn.add_theme_stylebox_override(st, chant_art[st])
	bv.add_child(scr._cast_btn)
	var small := HBoxContainer.new()
	small.add_theme_constant_override("separation", 6)
	bv.add_child(small)
	scr._clear_btn = UiTheme.button(UiTheme.hk("Clear", "⌫"), scr._h_input._clear_chant, 15)
	UiTheme.use_heading_font(scr._clear_btn)
	scr._clear_btn.custom_minimum_size = Vector2(122, 34)
	small.add_child(scr._clear_btn)
	scr._end_btn = UiTheme.button(UiTheme.hk("Pass", "E"), scr._h_input._on_end_turn, 15)
	UiTheme.use_heading_font(scr._end_btn)
	scr._end_btn.custom_minimum_size = Vector2(122, 34)
	scr._end_btn.tooltip_text = "End your turn without chanting (you keep your Essence)."
	small.add_child(scr._end_btn)
	scr.add_child(cp)
	# stock
	var sp := PanelContainer.new()
	scr._bag_panel = sp
	sp.add_theme_stylebox_override("panel", UiTheme.panel_box(0.8, 12))
	sp.position = Vector2(540, 872)
	sp.custom_minimum_size = Vector2(1100, 110)
	var sv := VBoxContainer.new()
	sp.add_child(sv)
	sv.add_child(UiTheme.label("Your bag of Essence  (click or drag, or press F / W / A)" if UiTheme.show_hotkeys() else "Your bag of Essence  (click or drag)", 15, UiTheme.MUTED))
	# a plain Control, not a flow container: the icons are placed (and tweened) by hand in _refresh_stock, and a
	# container would keep re-flowing them in creation order (gaps, icons jumping or vanishing mid-glide)
	scr._stock_row = Control.new()
	scr._stock_row.mouse_filter = Control.MOUSE_FILTER_PASS
	scr._stock_row.custom_minimum_size = Vector2(FightScreen.BAG_W, FightScreen.BAG_PX)
	sv.add_child(scr._stock_row)
	scr.add_child(sp)


var _lift_turn := -1  # (the turn the lift was last allowed to shrink in)


func _place_enemies() -> void:
	if scr._stage != null and scr._enemy_row != null:
		scr._enemy_row.position.y = scr._stage.floor_center_y() - FightScreen.ENEMY_FEET_DY - FightScreen.ENEMY_LIFT - scr._extra_lift


## Puppet Stage: the Essence rows hang under the enemies' feet; when one needs two lines (or more) the whole row of enemies stands higher, so
## the lowest line ends just above the spell cards.
## The screen y of the feet of the lowest standing enemy (0 when none).
func _feet_y() -> float:
	var y := 0.0
	for e in scr._views:
		var v: EnemyView = scr._views[e]
		if is_instance_valid(v) and is_instance_valid(v.creature) and not e.is_dead() and not v.creature.has_rig():
			y = maxf(y, v.creature.global_position.y + v.creature.size.y)
	return y


var _lift_locked: Fight  # the fight whose enemy row has found its height: from then on it doesn't move


func _fit_enemy_lift() -> void:
	if scr._stage == null or scr._enemy_row == null or scr._spell_row == null or scr._spell_row.get_child_count() == 0:
		return
	if _lift_locked == scr.fight:
		return  # (their places are fixed for the fight: a Burn or a second line of Essence doesn't push them up)
	var bottom := 0.0
	for e in scr._views:
		var v: EnemyView = scr._views[e]
		if is_instance_valid(v) and not e.is_dead() and not v.creature.has_rig():  # (a Handyman hand's text stands where its rig puts it)
			bottom = maxf(bottom, v.below_feet_bottom())
	if bottom <= 0.0:
		return
	if Engine.get_process_frames() > _lights_from + 30 and scr.fight != null and scr.fight.turn >= 1:
		_lift_locked = scr.fight  # (this is its height now; this last fit still applies)
	# (they never stand higher than the far edge of the floor, 20 px in: a puppet pushed up by its own rows of Essence would leave the floor)
	var top_room := 130.0
	var feet := _feet_y()
	if feet > 0.0:
		top_room = clampf(feet + scr._extra_lift - (scr._stage.floor_range().x + 20.0), 0.0, 130.0)
	var need := clampf(bottom + scr._extra_lift - (scr._spell_row.global_position.y - 6.0), 0.0, top_room)
	# Within one turn the lift only ever grows: clicking an orb changes the preview (a skull wraps an Essence row onto a second line and takes
	# it off again), and the whole row of enemies used to jump up and down with every click.
	var turn: int = scr.fight.turn if scr.fight != null else 0
	if turn == _lift_turn:
		need = maxf(need, scr._extra_lift)
	else:
		_lift_turn = turn
	need = minf(need, top_room)  # (the floor's far edge is a hard limit: a lift kept from earlier in the turn must obey it too)
	if absf(need - scr._extra_lift) > 0.5:
		scr._extra_lift = need
		if scr._enemy_row != null and scr._stage != null and not _dropping and scr._enemy_drop == 0.0:  # (glide there instead of jumping; while they are let down the drop follows the new place itself)
			var y := scr._stage.floor_center_y() - FightScreen.ENEMY_FEET_DY - FightScreen.ENEMY_LIFT - scr._extra_lift
			if scr._lift_tween != null and scr._lift_tween.is_valid():
				scr._lift_tween.kill()
			scr._lift_tween = scr.create_tween()
			scr._lift_tween.tween_property(scr._enemy_row, "position:y", y, 0.2).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


var _act_sign_gen := 0  # (every drop and every lift counts: a countdown that belongs to an older one does nothing)


func _rebuild_character_panel() -> void:
	if scr._nu_ui:
		_rebuild_character_panel_nu()
		return
	scr._puppet_hud = true
	var old := scr._player_panel
	scr._player_panel = Control.new()
	scr._player_panel.position = PuppetTopHud.TRAY.position  # (the marker the heal / shield effects fly to is the HP tray itself)
	scr._player_panel.size = PuppetTopHud.TRAY.size
	scr._player_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	scr.add_child(scr._player_panel)
	old.queue_free()
	scr._bottles_frame = _nine_frame("slot_board", PuppetTopHud.BOTTLES, PuppetTopHud.SLOT_MARGINS)
	scr._bottles_frame.z_index = PuppetStage.CEILING_Z + 2
	scr._arts_frame = _nine_frame("slot_board", PuppetTopHud.ARTIFACTS, PuppetTopHud.SLOT_MARGINS)
	scr._arts_frame.z_index = PuppetStage.CEILING_Z + 2
	scr._hp_bar = StripeHpBar.new()  # (16 candy stripes in a bar that ends in a ring; the numbers stand in the ring)
	scr._hp_bar.custom_minimum_size = PuppetTopHud.TRAY.size
	scr._hp_bar.position = PuppetTopHud.TRAY.position
	scr._hp_bar.size = PuppetTopHud.TRAY.size
	scr._hp_bar.z_index = PuppetStage.CEILING_Z + 2
	scr.add_child(scr._hp_bar)
	var heart := UiSkin.icon("icon_heart", 24)
	if heart != null:
		heart.z_index = PuppetStage.CEILING_Z + 3
		heart.visible = false  # (the ring of the HP bar holds the numbers now)
		scr.add_child(heart)
		scr._heart = heart
	var hp_font := UiTheme.cut("bold")
	scr._hp_label = UiTheme.label("", PuppetTopHud.HP_PX, Color(0.831, 0.255, 0.153))
	if hp_font != null:
		scr._hp_label.add_theme_font_override("font", hp_font)
	scr._hp_label.size = PuppetTopHud.RING_TEXT
	scr._hp_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	scr._hp_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER  # (centred in the ring, top line)
	scr._hp_label.clip_text = true
	scr._hp_label.z_index = PuppetStage.CEILING_Z + 3
	scr.add_child(scr._hp_label)
	scr._shield_box = HBoxContainer.new()
	scr._shield_box.z_index = PuppetStage.CEILING_Z + 3
	scr._shield_box.custom_minimum_size = PuppetTopHud.RING_TEXT
	scr._shield_box.alignment = BoxContainer.ALIGNMENT_CENTER
	scr._shield_box.visible = false
	scr._shield_label = UiTheme.label("", PuppetTopHud.SHIELD_PX, Color(0.31, 0.49, 0.56))  # (the ring's second line: the Shield, blue-grey like the page's)
	if hp_font != null:
		scr._shield_label.add_theme_font_override("font", hp_font)
	scr._shield_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scr._shield_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	scr._shield_box.add_child(scr._shield_label)
	scr.add_child(scr._shield_box)
	_lasting_label = UiTheme.label("", PuppetTopHud.LASTING_PX, Color(0.698, 0.847, 0.953))  # (under the bar: "Lasting 4")
	if hp_font != null:
		_lasting_label.add_theme_font_override("font", hp_font)
	_lasting_label.z_index = PuppetStage.CEILING_Z + 3
	scr.add_child(_lasting_label)
	scr._bottle_row = HBoxContainer.new()
	scr._bottle_row.add_theme_constant_override("separation", 0)
	scr._bottle_row.z_index = PuppetStage.CEILING_Z + 3
	scr.add_child(scr._bottle_row)
	scr._debuff_board = NinePatchRect.new()
	scr._debuff_board.texture = UiSkin.tex("debuff_board")	
	for side in ["left", "top", "right", "bottom"]:
		scr._debuff_board.set("patch_margin_" + side, PuppetTopHud.DEBUFF_MARGIN)
	scr._debuff_board.mouse_filter = Control.MOUSE_FILTER_IGNORE
	scr.add_child(scr._debuff_board)
	scr.move_child(scr._debuff_board, scr._stage.get_index() + 1)
	scr._top_layer = Control.new()
	scr._top_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	scr.add_child(scr._top_layer)
	scr.move_child(scr._top_layer, scr._stage.get_index() + 1)
	for n in [scr._bottles_frame, scr._arts_frame, scr._hp_bar, scr._heart, scr._hp_label, scr._shield_box, _lasting_label, scr._bottle_row, scr._arts, scr._player_panel]:
		if n != null:
			n.reparent(scr._top_layer, false)
	_build_act_sign()
	scr._status_row = HFlowContainer.new()
	scr._status_row.add_theme_constant_override("h_separation", FightScreen.STATUS_GAP)
	scr._status_row.add_theme_constant_override("v_separation", FightScreen.STATUS_GAP)
	scr._status_row.z_index = 1
	scr.add_child(scr._status_row)
	_fit_debuff_board(0)
	scr._pstatus = RichTextLabel.new()  # (not shown: statuses are icons)


## New UI: the HUD of page 2 of the Chant UI PDF. Everything stands on the screen itself (in _top_layer, which sinks with the HUD between fights); `_player_panel` is
## only a marker the effects that land on you fly to.
func _rebuild_character_panel_nu() -> void:
	var L = NewUiLayout
	scr._puppet_hud = true
	var old := scr._player_panel
	scr._player_panel = Control.new()
	scr._player_panel.position = L.HP_BAR.position
	scr._player_panel.size = L.HP_BAR.size
	scr._player_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	scr.add_child(scr._player_panel)
	old.queue_free()
	scr._nu_back = L.Back.new()
	scr._nu_back.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS  # (big pictures drawn small stay smooth)
	scr._nu_back.size = Vector2(1920.0, 1080.0)  # (it draws on the whole screen: a Control of size 0 that is redrawn while its parent shakes drops out of the picture for a frame or two)
	scr.add_child(scr._nu_back)
	if L.minh:  # (MinhHUD: your HP is the red flask)
		scr._hp_bar = MinhHpFlask.new()
	else:
		scr._hp_bar = L.Bar.new()
	scr._hp_bar.position = L.HP_BAR.position
	scr._hp_bar.size = L.HP_BAR.size
	scr._hp_bar.custom_minimum_size = L.HP_BAR.size
	scr._hp_bar.z_index = 1
	scr.add_child(scr._hp_bar)
	var hp_font := UiTheme.cut("boldoblique")
	if hp_font == null:
		hp_font = UiTheme.cut("bold")
	scr._hp_label = UiTheme.label("", L.HP_PX, Color.WHITE)
	if hp_font != null:
		scr._hp_label.add_theme_font_override("font", hp_font)
	scr._hp_label.size = Vector2(110.0, L.HP_BAR.size.y)
	scr._hp_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	scr._hp_label.z_index = 2
	scr.add_child(scr._hp_label)
	scr._shield_box = HBoxContainer.new()
	scr._shield_box.z_index = 2
	scr._shield_box.custom_minimum_size = Vector2(60.0, L.HP_BAR.size.y)
	scr._shield_box.alignment = BoxContainer.ALIGNMENT_END
	scr._shield_box.visible = false
	scr._shield_label = UiTheme.label("", L.HP_PX, Color.WHITE)
	if hp_font != null:
		scr._shield_label.add_theme_font_override("font", hp_font)
	scr._shield_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scr._shield_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	scr._shield_box.add_child(scr._shield_label)
	scr.add_child(scr._shield_box)
	_lasting_label = UiTheme.label("", 14, Color(0.698, 0.847, 0.953))  # (under the bar, at its right end: "Lasting 4")
	if hp_font != null:
		_lasting_label.add_theme_font_override("font", hp_font)
	_lasting_label.z_index = 2
	scr.add_child(_lasting_label)
	scr._bottle_row = HBoxContainer.new()
	scr._bottle_row.add_theme_constant_override("separation", 0)
	scr._bottle_row.z_index = 2
	scr.add_child(scr._bottle_row)
	scr._top_layer = Control.new()
	scr._top_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	scr.add_child(scr._top_layer)
	scr.move_child(scr._top_layer, scr._stage.get_index() + 1)
	for n in [scr._nu_back, scr._hp_bar, scr._hp_label, scr._shield_box, _lasting_label, scr._bottle_row, scr._arts, scr._player_panel]:
		n.reparent(scr._top_layer, false)
	if L.minh:
		_build_minh_layers()
	scr._info.reparent(scr._top_layer, false)  # (no hanging sign: the Act / Floor / Turn line is written on the second tab of the HUD, always shown)
	scr._info.position = L.ACT_TEXT.position
	scr._info.size = L.ACT_TEXT.size
	scr._info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER if L.hud2 else HORIZONTAL_ALIGNMENT_LEFT
	scr._info.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	scr._info.autowrap_mode = TextServer.AUTOWRAP_OFF  # (Puppet HUD ver 2: one line centred over the artifact tray)
	scr._info.add_theme_font_size_override("font_size", 18)
	scr._info.add_theme_color_override("font_color", Color.WHITE)
	var oblique := UiTheme.cut("oblique")
	if oblique != null:
		scr._info.add_theme_font_override("font", oblique)
	scr._info.z_index = 4
	scr._info.visible = true
	if L.v2:  # (NewUI Ver2: the three lines on the paper are drawn by _nu_back; the two lamps of the artifact cabinet)
		scr._info.visible = false
		scr._nu_back.info = scr._info.text
		scr._top_layer.add_child(NewUi2Layout.Lights.new())
		_rack_upper = TextureRect.new()
		_rack_upper.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_rack_upper.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		_rack_upper.stretch_mode = TextureRect.STRETCH_SCALE
		_rack_upper.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		_rack_upper.z_index = 3  # (the bottles are at 2)
		scr._top_layer.add_child(_rack_upper)
		NewUi2Layout.place_rack_upper(_rack_upper, Bottles.BASE_SLOTS)
	scr._status_row = Control.new()  # (the debuff icons stand on the green circles of _nu_back, placed by _fit_debuff_board)
	scr._status_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	scr._status_row.position = L.DEBUFF_AT
	scr._status_row.size = Vector2(L.DEBUFF_COLS * L.DEBUFF_STEP, L.DEBUFF_PX)
	scr._status_row.z_index = 1
	scr._top_layer.add_child(scr._status_row)
	_fit_debuff_board(0)
	scr._pstatus = RichTextLabel.new()  # (not shown: statuses are icons)


## The artifact bar of the top frame (Puppet) or of the corner (the other themes).
func _make_arts() -> ArtifactBar:
	var bar := ArtifactBar.make(scr.fight.artifacts, scr.fight.artifact_plus)
	bar.position = Vector2(28, 52)
	if scr._nu_ui:  # (ten slots in two rows of five, as the page has them)
		bar.chip_px = NewUiLayout.ART_PX
		bar.row_width = NewUiLayout.ART_CELL.x * NewUiLayout.ART_COLS
		bar.slot_step = NewUiLayout.ART_CELL.x
		bar.per_row = NewUiLayout.ART_COLS
		bar.row_gap = NewUiLayout.ART_CELL.y - NewUiLayout.ART_PX
		bar.z_index = 3
	elif UiSkin.is_puppet():
		bar.chip_px = FightScreen.ART_PX
		bar.row_width = FightScreen.ART_STEP * (FightScreen.ART_ROW - 1) + FightScreen.ART_PX + 4.0  # (five to a row, the next ones wrap to a second row)
		bar.slot_step = FightScreen.ART_STEP
		bar.per_row = FightScreen.ART_ROW
		bar.z_index = PuppetStage.CEILING_Z + 3
	return bar


## A painted board of the HUD, 9 slices (margins: left, top, right, bottom).
func _nine_frame(tex_name: String, r: Rect2, m: Array) -> NinePatchRect:
	var f := NinePatchRect.new()
	f.texture = UiSkin.tex(tex_name)
	f.patch_margin_left = int(m[0])
	f.patch_margin_top = int(m[1])
	f.patch_margin_right = int(m[2])
	f.patch_margin_bottom = int(m[3])
	f.position = r.position
	f.size = r.size
	f.mouse_filter = Control.MOUSE_FILTER_IGNORE
	scr.add_child(f)
	scr.move_child(f, scr._stage.get_index() + 1)
	return f


## The bottle frame (one row of five) and the artifact frame (two rows of five) stand where the PDF has them, bottom left. A frame is only there when you carry something;
## a sixth bottle widens the bottle frame, a third row of artifacts makes the artifact frame taller (upwards: its bottom is the page's).
func _fit_hud_frames() -> void:
	if scr._nu_ui and scr._puppet_hud:
		_fit_hud_nu()
		return
	if not scr._puppet_hud or scr._bottles_frame == null:
		return
	var T = PuppetTopHud
	var nb: int = scr.fight.player.bottles.size()
	var na: int = scr._arts.artifacts.size()
	scr._bottles_frame.visible = nb > 0
	scr._bottle_row.visible = nb > 0
	if nb > 0:
		var b_w: float = maxf(T.BOTTLES.size.x, 2.0 * T.SLOT_PAD.x + nb * FightScreen.BOTTLE_STEP)
		scr._bottles_frame.position = T.BOTTLES.position
		scr._bottles_frame.size = Vector2(b_w, T.BOTTLES.size.y)
		scr._bottle_row.position = Vector2(T.BOTTLES.position.x + T.SLOT_PAD.x + (FightScreen.BOTTLE_STEP - FightScreen.BOTTLE_PX) / 2.0, T.BOTTLES.position.y + (T.BOTTLES.size.y - FightScreen.BOTTLE_PX) / 2.0)
	scr._arts_frame.visible = na > 0
	scr._arts.visible = na > 0
	if na > 0:
		var rows: int = ceili(float(na) / FightScreen.ART_ROW)
		var a_h: float = T.BOTTLES.size.y if rows <= 1 else T.ARTIFACTS.size.y + (rows - 2) * (FightScreen.ART_PX + FightScreen.ART_ROW_GAP)
		var a_y: float = T.ARTIFACTS.end.y - a_h if rows > 2 else T.ARTIFACTS.position.y
		scr._arts_frame.position = Vector2(T.ARTIFACTS.position.x, a_y)
		scr._arts_frame.size = Vector2(T.ARTIFACTS.size.x, a_h)
		var inner_h: float = rows * FightScreen.ART_PX + (rows - 1) * FightScreen.ART_ROW_GAP
		scr._arts.position = Vector2(T.ARTIFACTS.position.x + (T.ARTIFACTS.size.x - (FightScreen.ART_STEP * (FightScreen.ART_ROW - 1) + FightScreen.ART_PX)) / 2.0, a_y + (a_h - inner_h) / 2.0)
	scr._hp_bar.position = T.TRAY.position
	scr._player_panel.position = scr._hp_bar.position
	if scr._heart != null:
		scr._heart.position = T.HEART_AT
	scr._hp_label.position = T.RING_HP_AT
	scr._shield_box.position = T.RING_SHIELD_AT
	_lasting_label.position = T.LASTING_AT


## New UI: the Menu button is the word MENU on the first tab of the HUD: no plate of its own, the tab (drawn by NewUiLayout.Back) gets lighter under the mouse and darker when pressed.
func _style_nu_menu(b: Button) -> void:
	for st in ["normal", "hover", "pressed", "disabled", "focus"]:
		b.add_theme_stylebox_override(st, StyleBoxEmpty.new())
	b.text = "MENU"
	var bold := UiTheme.cut("bold")
	if bold != null:
		b.add_theme_font_override("font", bold)
	b.add_theme_font_size_override("font_size", 18)
	for c in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		b.add_theme_color_override(c, Color.WHITE)
	b.flat = true
	b.focus_mode = Control.FOCUS_NONE
	b.z_index = 4
	b.mouse_entered.connect(func() -> void: _nu_menu_state(1))
	b.mouse_exited.connect(func() -> void: _nu_menu_state(0))
	b.button_down.connect(func() -> void: _nu_menu_state(2))
	b.button_up.connect(func() -> void: _nu_menu_state(1 if b.is_hovered() else 0))


## Puppet HUD ver 2: the Menu button is the wooden plate of the HUD (drawn by Hud2Layout.draw, lighter under the mouse, darker pressed) with its word in the art's amber.
func _style_hud2_menu(b: Button) -> void:
	b.custom_minimum_size = Vector2.ZERO
	b.set_deferred("size", NewUiLayout.MENU_BTN.size)  # (deferred: the old 130 px minimum is still cached until the next frame and would clamp it)
	b.position = NewUiLayout.MENU_BTN.position
	b.text = ""  # (the word MENU is in the picture)
	b.alignment = HORIZONTAL_ALIGNMENT_CENTER
	for c in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		b.add_theme_color_override(c, Color(0.96, 0.72, 0.42))
	b.add_theme_color_override("font_outline_color", Color(0.17, 0.09, 0.05))
	b.add_theme_constant_override("outline_size", 3)
	var orig: Dictionary = b.get_meta("hg_orig", {})  # (the header styles put these back when the fonts are re-applied: let them put back the amber)
	if not orig.is_empty():
		orig.color = Color(0.96, 0.72, 0.42)
		orig.outline = 3
		orig.ocolor = Color(0.17, 0.09, 0.05)
		b.set_meta("hg_orig", orig)


func _nu_menu_state(k: int) -> void:
	if scr._nu_back != null:
		scr._nu_back.menu_state = k
		scr._nu_back.queue_redraw()


## New UI: the artifacts and bottles stand in their slots, the HP numbers on the bar (red = HP, blue = Shield and Lasting after it).
func _fit_hud_nu() -> void:
	var L = NewUiLayout
	scr._arts.visible = true
	scr._arts.position = L.ART_AT + (L.ART_CELL - Vector2.ONE * L.ART_PX) / 2.0
	scr._bottle_row.visible = true
	scr._bottle_row.position = L.BOTTLE_AT + (L.BOTTLE_CELL - Vector2.ONE * L.BOTTLE_PX) / 2.0
	if L.minh:  # (the numbers stand on the lower half of the flask, under the hub)
		var fc: Vector2 = L.HP_BAR.get_center()
		scr._hp_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		scr._hp_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		scr._hp_label.position = Vector2(fc.x - 55.0, fc.y + 34.0)
		scr._hp_label.size = Vector2(110.0, 24.0)
		scr._shield_box.alignment = BoxContainer.ALIGNMENT_CENTER
		scr._shield_box.custom_minimum_size = Vector2(80.0, 20.0)
		scr._shield_box.position = Vector2(fc.x - 40.0, fc.y + 58.0)
		scr._shield_box.size = scr._shield_box.custom_minimum_size
		_lasting_label.size = Vector2(160.0, 20.0)
		_lasting_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_lasting_label.position = Vector2(fc.x - 80.0, fc.y + 80.0)
		scr._player_panel.position = L.HP_BAR.position
		return
	var bar := scr._hp_bar as NewUiLayout.Bar
	var parts := bar.parts()
	var fill: Rect2 = Rect2(L.HP_BAR.position + L.HP_FILL.position, L.HP_FILL.size)  # (the pill the liquid is in, on the screen)
	scr._hp_label.position = fill.position + Vector2(8.0 if L.v2 else 30.0, 0.0)  # (clear of the left clamp)
	scr._hp_label.size = Vector2(110.0, fill.size.y)
	var end_x: float = fill.position.x + parts.x  # (the Shield lies over the end of the HP: its number stands at the end of the HP)
	scr._shield_box.custom_minimum_size = Vector2(60.0, fill.size.y)
	scr._shield_box.position = Vector2(maxf(end_x - 12.0 - 60.0, scr._hp_label.position.x + 80.0), fill.position.y)
	scr._shield_box.size = scr._shield_box.custom_minimum_size
	_lasting_label.size = Vector2(160.0, 20.0)
	_lasting_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_lasting_label.position = Vector2(L.HP_BAR.end.x - _lasting_label.size.x, L.HP_BAR.position.y - 22.0)  # (above the tube, its right end level with the tube's)
	scr._player_panel.position = L.HP_BAR.position


## The debuff board holds exactly the icons you have: it grows right from its corner at the top left as they come, and is gone when there are none.
func _fit_debuff_board(n: int) -> void:
	if scr._nu_ui:
		scr._nu_back.debuffs = n
		NewUiLayout.debuff_count = n
		scr._nu_back.queue_redraw()
		var rows := maxi(1, ceili(n / float(NewUiLayout.DEBUFF_COLS)))
		var k := 0
		for chip: Control in scr._status_row.get_children():
			if chip.is_queued_for_deletion():  # (the icons of the last refresh are still there until the end of the frame)
				continue
			chip.size = Vector2.ONE * NewUiLayout.DEBUFF_PX
			chip.position = NewUiLayout.debuff_slot(k, rows) - NewUiLayout.DEBUFF_AT
			k += 1
		return
	if scr._debuff_board == null:
		return
	scr._debuff_board.visible = n > 0
	scr._status_row.visible = n > 0
	if n <= 0:
		return
	var h: float = PuppetTopHud.DEBUFF_MIN.y  # (one row)
	var room: float = PuppetTopHud.DEBUFF_MAX_RIGHT - PuppetTopHud.DEBUFF_AT.x - 2.0 * FightScreen.DEBUFF_PAD
	var step := minf(FightScreen.STATUS_CHIP + FightScreen.STATUS_GAP, (room - FightScreen.STATUS_CHIP) / maxf(1.0, n - 1.0))  # (a very long row squeezes together)
	var inner_w := (n - 1) * step + FightScreen.STATUS_CHIP
	var w := maxf(2.0 * FightScreen.DEBUFF_PAD + inner_w, 64.0)
	scr._debuff_board.size = Vector2(w, h)
	var lift: float = -clampf(scr._hud_shift / FightScreen.HUD_DOWN, 0.0, 1.0) * FightScreen.DEBUFF_LIFT
	scr._debuff_board.position = PuppetTopHud.DEBUFF_AT + Vector2(0.0, lift)
	scr._status_row.add_theme_constant_override("h_separation", int(floor(step - FightScreen.STATUS_CHIP)))
	scr._status_row.custom_minimum_size = Vector2(inner_w, FightScreen.STATUS_CHIP)
	scr._status_row.size = Vector2(inner_w, FightScreen.STATUS_CHIP)
	scr._status_row.position = scr._debuff_board.position + Vector2((w - inner_w) / 2.0, (h - FightScreen.STATUS_CHIP) / 2.0)


## The hanging sign with the Act / Floor / Turn line (Stage/Shared/hanging_sign.png at the place the PDF gives it). It waits hidden above the screen, so the
## first frame never shows it in its place.
func _build_act_sign() -> void:
	var T = PuppetTopHud
	scr._act_sign = Control.new()
	scr._act_sign.mouse_filter = Control.MOUSE_FILTER_IGNORE
	scr._act_sign.position = T.ACT_SIGN.position + Vector2(0.0, -_act_sign_up())
	scr._act_sign.size = T.ACT_SIGN.size
	scr._act_sign.z_index = PuppetStage.CEILING_Z - 1  # (under the ceiling: its chains hang from behind the valance)
	var pic := TextureRect.new()
	pic.texture = load(UiSkin.theme_dir() + "Stage/Shared/hanging_sign.png")
	pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	pic.stretch_mode = TextureRect.STRETCH_SCALE
	pic.size = T.ACT_SIGN.size
	pic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	scr._act_sign.add_child(pic)
	scr._info.reparent(scr._act_sign, false)
	scr._info.position = T.ACT_TEXT.position - T.ACT_SIGN.position
	scr._act_sign.visible = false
	scr.add_child(scr._act_sign)


func _act_sign_up() -> float:
	return PuppetTopHud.ACT_SIGN.end.y + 20.0  # (far enough up that all of it is above the screen)


## The sign drops on its chains (a bounce, like the Victory sign). `from_arrival`: the props and the enemies are out, so it goes back up
## `PuppetTopHud.ACT_SHOWN` seconds from now (a drop that is only the fight starting leaves the countdown to the arrival).
func _show_act_sign(from_arrival := false) -> void:
	if scr._act_sign == null or scr.map_mode or not scr.is_inside_tree():
		return
	var rest: float = PuppetTopHud.ACT_SIGN.position.y
	if not scr._act_sign.visible:
		scr._act_sign.visible = true
		var tw := scr.create_tween()
		tw.tween_property(scr._act_sign, "position:y", rest, 0.55).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tw.tween_property(scr._act_sign, "position:y", rest - 38.0, 0.16).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.tween_property(scr._act_sign, "position:y", rest, 0.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tw.tween_property(scr._act_sign, "position:y", rest - 12.0, 0.1).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.tween_property(scr._act_sign, "position:y", rest, 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		_act_sign_gen += 1
	if from_arrival:
		var gen := _act_sign_gen
		await FightWait.seconds(scr, PuppetTopHud.ACT_SHOWN)
		if gen == _act_sign_gen and scr.is_inside_tree():
			_lift_act_sign()


## The sign goes back up behind the valance (at once when `now`).
func _lift_act_sign(now := false) -> void:
	if scr._act_sign == null or not scr._act_sign.visible:
		return
	_act_sign_gen += 1
	var up: float = PuppetTopHud.ACT_SIGN.position.y - _act_sign_up()
	if now:
		scr._act_sign.position.y = up
		scr._act_sign.visible = false
		return
	var gen := _act_sign_gen
	var tw := scr.create_tween()
	tw.tween_property(scr._act_sign, "position:y", up, 0.7).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	await tw.finished
	if gen == _act_sign_gen and is_instance_valid(scr._act_sign):
		scr._act_sign.visible = false


func _refresh_coin() -> void:
	if _coin_label != null and scr.run != null:
		_coin_label.text = str(scr.run.amber)


## Statuses as small icons: a coloured frame, the picture (or its emoji), the amount in the corner; hover for the words.
func _status_px() -> float:
	return NewUiLayout.DEBUFF_PX if scr._nu_ui else FightScreen.STATUS_CHIP


func _refresh_statuses_compact() -> void:
	for c in scr._status_row.get_children():
		c.queue_free()
	var shown := 0
	for b in _status_badges():
		var id := String(b[2])
		var chip := TipPanel.new()
		chip.custom_minimum_size = Vector2(_status_px(), _status_px())
		chip.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
		var holder := Control.new()
		holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
		chip.add_child(holder)
		var icon: Control = UiSkin.icon(_badge_art_name(b), _status_px())
		if icon != null:
			chip.hover_tex = icon.texture
			chip.hover_left = true  # (its board appears to the left of the icon: the Chant strip stays in view)
		if id.begins_with("attune_"):
			icon = ElementIcon.make(id.substr(7), _status_px() - 4.0)
		if icon == null:  # (no picture: the emoji that leads its words)
			var em := UiTheme.label(String(b[0]).get_slice(" ", 0), 24, Color.WHITE)
			em.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			em.mouse_filter = Control.MOUSE_FILTER_IGNORE
			icon = em
		icon.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		var sock := UiSkin.tex("nu_debuff_socket") if id == "thorns" else null
		if sock != null:  # (Thorns: the little thorny branch is lost on its own: it sits in the green socket of the HUD, like a picture in its frame)
			var bg := TextureRect.new()
			bg.texture = sock
			bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			bg.stretch_mode = TextureRect.STRETCH_SCALE
			bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
			holder.add_child(bg)
			var inset := _status_px() * 0.13
			icon.custom_minimum_size = Vector2.ZERO  # (else its own minimum size pushes it out of the inset)
			icon.offset_left = inset
			icon.offset_right = -inset
			icon.offset_top = inset
			icon.offset_bottom = -inset
		holder.add_child(icon)
		var digits := ""
		for ch in String(b[0]):
			if ch >= "0" and ch <= "9":
				digits += ch
			elif digits != "":
				break
		if digits != "":
			var n := UiTheme.label(digits, 20, Color.WHITE)
			n.add_theme_constant_override("outline_size", 6)
			n.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.95))
			n.mouse_filter = Control.MOUSE_FILTER_IGNORE
			n.position = Vector2(_status_px() - 8.0 - 12.0 * digits.length(), _status_px() - 30.0)
			holder.add_child(n)
		var tip: String = Keywords.K.get(id, [0, 0, ""])[2]
		chip.tooltip_text = b[3] if b.size() > 3 else (Keywords.tooltip(b[0], tip) if tip != "" else String(b[0]))
		if chip.hover_tex != null:  # (the board shows the picture big: the little emoji in front of the title goes)
			var lead := String(b[0]).get_slice(" ", 0)
			var at := chip.tooltip_text.find(lead + " ")
			if lead != "" and at >= 0 and lead.unicode_at(0) > 255:
				chip.tooltip_text = chip.tooltip_text.erase(at, lead.length() + 1)
		if b.size() > 4:
			chip.set_meta("power_id", b[4])
		chip.mouse_filter = Control.MOUSE_FILTER_STOP
		scr._status_row.add_child(chip)
		shown += 1
	_fit_debuff_board(shown)


## Where the enemies' feet are, for the spotlights. A light stays where its enemy stood once the stage was laid out: an enemy
## that moves, lunges or leans steps out of it, the light doesn't follow.
var _light_home := {}  # EnemyState -> the spot its light shines on


var _lights_from := 0  # the frame the enemy row was last rebuilt (its lights are measured a few frames later)


func _enemy_feet() -> Array:
	var out: Array = []
	var settled := Engine.get_process_frames() > _lights_from + 10
	for e in scr._views:
		var v: EnemyView = scr._views[e]
		if _light_home.has(e) and not e.is_dead():
			out.append(_light_home[e])
			continue
		if is_instance_valid(v) and is_instance_valid(v.creature) and not e.is_dead() and not v.creature.has_rig():  # (a hand hangs on his shoulder: no light at its feet)
			var at := v.creature.global_position + Vector2(v.creature.size.x / 2.0, v.creature.size.y + v.creature.ground_drop)
			if settled:
				_light_home[e] = at
			out.append(at)  # (a flyer: its light on the floor below it)
	if scr._hm_stage != null and is_instance_valid(scr._hm_stage):
		var body_feet = scr._hm_stage.body_feet()  # (his body, while it is only a picture)
		if body_feet != null:
			out.append(body_feet)
	return out


## Puppet Stage: the spell cards sit just above the line of text over the Chant strip.
func _place_spell_row() -> void:
	if not _puppet_strips() or scr._spell_row == null or scr._chant_panel == null or scr._spell_row.get_child_count() == 0:
		return
	var h := 0.0
	for c in scr._spell_row.get_children():
		h = maxf(h, maxf(c.custom_minimum_size.y, c.get_combined_minimum_size().y))  # (a wordy card is taller than its nominal height: it must not reach down over the chant)
	scr._spell_row.position.y = scr._chant_panel.position.y - 5.0 - h
	if scr._nu_ui:
		scr._spell_row.position.y = NewUiLayout.SPELL_BOTTOM - (SpellCard.H * float(scr._cards[0].base_scale) if not scr._cards.is_empty() else h) + scr._hud_shift  # (the cards' bottom edge is where the page has it; while the HUD is sunk below the screen the row sinks with it, and _set_hud_shift brings it up with the rest)


## Puppet Stage: the Bag's balls swap into their types (fire, water, wind) once a launch is over: first the new balls stack after the old
## ones, a moment later everybody slides to the right place, with a small lift and one wooden "swap".
func _resort_bag() -> void:
	if not _puppet_strips() or scr._resort_wait or scr._keep_bag_order:
		return
	scr._resort_wait = true
	await FightWait.seconds(scr, 0.45)
	scr._resort_wait = false
	if scr.fight == null or not scr.is_inside_tree() or scr._launching > 0 or scr._tube_prep:
		return  # (another launch has begun: it calls this again when it is over)
	scr._resort = true
	_refresh_stock()
	scr._resort = false


## Puppet Stage: the strips and the lottery-ball machine of "Chant UI for puppet.pdf" (cut by tools/export_puppet_chant.py, laid out by
## PuppetLayout). It shares everything else of the Cirus strips (the Essence roll along the Bag, the tube logic), so _circus_strips() is
## true for it too; only the building and the tube / machine functions look at _puppet_strips().


func _puppet_strips() -> bool:
	if not UiSkin.is_puppet() or UiSkin.tex("chant_frame") == null or UiSkin.tex("bag_frame") == null:
		return false
	return SlotMachine.available()


func _circus_strips() -> bool:
	if UiSkin.is_puppet():
		return _puppet_strips()
	return UiSkin.is_circus() and UiSkin.tex("chant_frame") != null and UiSkin.tex("bag_frame") != null and UiSkin.tex("tube_glass") != null \
		and UiSkin.tex("tube_back") != null and UiSkin.tex("tube_gear") != null and UiSkin.tex("crank_plate") != null and UiSkin.tex("crank_handle") != null


func _strip_art(tex_name: String, pos: Vector2) -> TextureRect:
	var r := TextureRect.new()
	r.texture = UiSkin.tex(tex_name)
	r.position = pos
	r.size = r.texture.get_size()
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return r


## The machine's glass sheets are blended with "Screen" (screen_blend.gdshader): they only lighten what is behind them, so the balls show
## through them. Without the shader file they fall back to plain 40 % opacity.
func _glass_art(tex_name: String, pos: Vector2) -> TextureRect:
	var r := _strip_art(tex_name, pos)
	var sh := load("res://assets/Global/Card/Shaders/screen_blend.gdshader") as Shader
	if sh != null:
		var m := ShaderMaterial.new()
		m.shader = sh
		m.set_shader_parameter("strength", 0.85)
		r.material = m
	else:
		r.modulate.a = 0.4
	return r


func _build_strips_puppet() -> void:
	var cap := PuppetLayout.CAP
	var margins := [int(cap.x), 0, int(cap.y), 0]  # (3 slices: a cap at each end, a plain middle, no stretch in height)
	var cp := PanelContainer.new()
	cp.add_theme_stylebox_override("panel", (StyleBoxEmpty.new() as StyleBox) if scr._nu_ui else UiSkin.box("chant_frame", margins))  # (New UI: the dark block of the page is the Chant strip)
	scr._chant_panel = cp
	cp.position = scr._h_machine._bag_at() + scr._h_machine._chant_at()
	cp.custom_minimum_size = PuppetLayout.FRAME_CHANT
	var cin := Control.new()
	cin.custom_minimum_size = PuppetLayout.FRAME_CHANT
	cin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cp.add_child(cin)
	# what the chant row says ("3 Essence", Toll, Hypnotized...): just above the strip
	scr._chant_note = UiTheme.label("", 15, Color.WHITE)
	scr._chant_note.position = Vector2(PuppetLayout.RING_X0, -26)
	if NewUiLayout.v2:  # (NewUI Ver2: the HP glass tube lies just over the sockets: the note stands above the tube's left end)
		scr._chant_note.position = Vector2(NewUi2Layout.HP_GLASS.position.x, 866.0) - (NewUiLayout.BAG_AT + NewUiLayout.CHANT_AT)
	scr._chant_note.z_index = 5  # (over the spell cards that now stand right on the strip)
	scr._chant_note.add_theme_constant_override("outline_size", 5)
	scr._chant_note.add_theme_color_override("font_outline_color", Color(0.1, 0.05, 0.03))
	scr._chant_note.mouse_filter = Control.MOUSE_FILTER_STOP
	cin.add_child(scr._chant_note)
	scr._chant_row = HBoxContainer.new()
	scr._chant_row.add_theme_constant_override("separation", 6)
	var ring_px := NewUiLayout.RING_PX if scr._nu_ui else FightScreen.PUPPET_RING_PX
	scr._chant_row.position = Vector2(PuppetLayout.RING_X0 + 26.0 - ring_px / 2.0, PuppetLayout.RING_CY - ring_px / 2.0)
	cin.add_child(scr._chant_row)
	scr._cast_btn = UiTheme.button("Chant", scr._h_input._on_primary, 15)
	UiTheme.use_heading_font(scr._cast_btn)
	scr._h_machine._place(scr._cast_btn, NewUiLayout.BTN_CHANT if scr._nu_ui else PuppetLayout.BTN_CHANT)
	UiTheme.style_puppet_button(scr._cast_btn, "chant", 18)
	scr._cast_kind = "chant"
	scr._cast_btn.tooltip_text = "Chant (Enter) / Release (E)"
	cin.add_child(scr._cast_btn)
	# Clear (Undo takes its place after the chant) and Pass each sit in a fixed slot
	var clear_slot := Control.new()
	scr._h_machine._place(clear_slot, NewUiLayout.BTN_CLEAR if scr._nu_ui else PuppetLayout.BTN_CLEAR)
	cin.add_child(clear_slot)
	scr._clear_btn = UiTheme.button("Clear", scr._h_input._clear_chant, 13)
	UiTheme.use_heading_font(scr._clear_btn)
	UiTheme.style_puppet_button(scr._clear_btn, "clear", 14)
	scr._clear_btn.tooltip_text = "Clear the chant (Backspace)."
	scr._clear_btn.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	clear_slot.add_child(scr._clear_btn)
	var pass_slot := Control.new()
	scr._h_machine._place(pass_slot, NewUiLayout.BTN_PASS if scr._nu_ui else PuppetLayout.BTN_PASS)
	cin.add_child(pass_slot)
	scr._end_btn = UiTheme.button("Pass", scr._h_input._on_end_turn, 13)
	UiTheme.use_heading_font(scr._end_btn)
	UiTheme.style_puppet_button(scr._end_btn, "pass", 14)
	scr._end_btn.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scr._end_btn.tooltip_text = "End your turn without chanting (you keep your Essence). (E)"
	pass_slot.add_child(scr._end_btn)
	_wire_minh_buttons()
	scr.add_child(cp)
	# the Bag strip, then the slot machine (Slot_machine.pdf, SlotMachine) on its right. Layers: the strip, the glass tube and the port's hole, every Essence
	# (in the strip, in the tube, hidden behind the funnels and the cabinet), then the funnels, the cabinet with its reels, lamps and lever, the tube's clamps
	# and the port's ring on top of them.
	var sp := PanelContainer.new()
	scr._bag_panel = sp
	sp.add_theme_stylebox_override("panel", (StyleBoxEmpty.new() as StyleBox) if scr._nu_ui else UiSkin.box("bag_frame", margins))  # (New UI: the Bag tray is drawn in NewUiLayout.Back)
	sp.position = scr._h_machine._bag_at()
	sp.custom_minimum_size = PuppetLayout.FRAME_BAG
	var inner := Control.new()
	inner.custom_minimum_size = PuppetLayout.FRAME_BAG
	inner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sp.add_child(inner)
	scr._machine = SlotMachine.new()
	if scr._nu_ui:  # (the same machine, bigger, at the right end of the Bag strip, with a straight tube: see NewUiLayout)
		scr._machine.xs = NewUiLayout.MACHINE_SCALE
		scr._machine.xp = NewUiLayout.MACHINE_POS
		scr._machine.straight = true
		scr._machine.spawn_c = Vector2(NewUiLayout.MOUTH_X, NewUiLayout.TUBE_ROW_Y)
		scr._machine.lever_shift = NewUiLayout.LEVER_SHIFT
		if NewUiLayout.v2:  # (NewUI Ver2: the page puts the funnel and the tube where the old machine does not)
			scr._machine.funnel_old = NewUi2Layout.funnel_old()
			scr._machine.tube_strip = NewUi2Layout.tube_strip()
			scr._machine.funnel_layers = NewUi2Layout.funnel_layers()
			scr._machine.mouth_strip = NewUi2Layout.funnel_mouth()
			scr._machine.connectors = NewUi2Layout.connectors_strip()
			scr._machine.drop_x = NewUi2Layout.MACHINE_TUBE.end.x - 6.0 - NewUiLayout.BAG_AT.x
		if NewUiLayout.hud2:  # (Puppet HUD ver 2 has no machine: the Essence come down the vertical tube)
			scr._machine.headless = true
			scr._machine.drop_at = NewUiLayout.DROP_AT
	scr._machine.build()
	if NewUiLayout.minh:
		_build_minh_pipe(inner)
	elif NewUiLayout.hud2:
		scr._h_machine._build_hud2_tube(inner)
	scr._machine.behind.show_behind_parent = true  # (the tube comes out from under the Bag strip)
	sp.add_child(scr._machine.behind)
	sp.move_child(scr._machine.behind, 0)
	inner.add_child(scr._machine.back)
	inner.add_child(scr._machine.funnel_back)  # (NewUI Ver2: the funnel's back layer, in strip px, under the Essence)
	scr._stock_row = Control.new()
	scr._stock_row.mouse_filter = Control.MOUSE_FILTER_PASS
	scr._stock_row.custom_minimum_size = Vector2(1100.0, PuppetLayout.FRAME_BAG.y)
	scr._stock_row.size = scr._stock_row.custom_minimum_size
	if NewUiLayout.minh:
		scr._stock_row.z_index = 60  # (the Essence rest and wait INSIDE the glass pipe: it is drawn under them (z 59) and faintly over them (61))
	inner.add_child(scr._stock_row)
	if scr._nu_ui:
		inner.add_child(scr._machine.over)  # (the tube's clamp, over the Essence)
	inner.add_child(scr._machine.front)
	scr.add_child(sp)


## MinhHUD: the layers of the PDF that stand over or between the cards of the HUD (children of the top layer, which is the HUD's own: they sink and fade with it). z: the Chant tray's front 1
## (over the rings that lie in it), the hub 2 (over the flask's glass), the glass over the artifacts and the bottles 4 (over the artifacts z 3 and the bottles z 2); the round button
## is under the real Buttons of the Chant strip.
func _build_minh_layers() -> void:
	var H = Hud2Layout
	scr._minh_disc = MinhParts.Disc.new()
	scr._top_layer.add_child(scr._minh_disc)
	scr._top_layer.add_child(MinhParts.Layer.new(1, [["Chant tray/Front tray", Rect2(969.797, 924.183, 584.032, 38.828)]]))
	scr._top_layer.add_child(MinhParts.Layer.new(2, [["minhhud_hub", MinhParts.HUB]]))
	scr._top_layer.add_child(MinhParts.Layer.new(4, [["Artifact Cabinet/Glass", Rect2(141.385, 852.717, 285.406, 180.444)], ["Artifact Cabinet/Side Glass", Rect2(155.698, 872.299, 256.78, 141.279)], ["Bottle cabinet/Front stand", Rect2(508.003, 986.671, 131.846, 20.376)]]))
	scr._top_layer.add_child(MinhParts.Layer.new(4, [["Bottle cabinet/Glass", H.M_BOT_BACK]], true))


## MinhHUD: the round button changes face (the chant is spoken: Chant / Pass flips into Release, and back): its picture flips, and the real Button that takes the clicks changes its size
## (Chant is the red upper part, Release is the whole face; Pass is hidden then by the fight screen).
func _minh_flip(kind: String) -> void:
	if scr._minh_disc == null:
		return
	scr._minh_disc.set_kind(kind, true)
	var r: Rect2 = Hud2Layout.M_CHANT_BTN if kind == "chant" else Hud2Layout.M_RELEASE_BTN
	scr._h_machine._place(scr._cast_btn, Rect2(r.position - (NewUiLayout.BAG_AT + NewUiLayout.CHANT_AT), r.size))


## MinhHUD: the looped glass pipe (the picture is opaque: once at z 59 under the Essence that wait and run in it, and once more at z 61 over them, faint, as the glass in front of them), the lever (63) and the hub's centre over its pivot (64). Children of the Bag strip like the hud2 tube, so they
## sink and fade with the HUD. The pipe is one picture drawn twice, as the page does: the whole of it right of x 1190, and again 94.3 px further right inside a box over the straight tube
## (the tube is as long as the page needs). The lever's pivot is the hub's centre (`_minh_lever` is kept for its animation: not made yet).
func _build_minh_pipe(holder: Control) -> void:
	var H = Hud2Layout
	var pipe := UiSkin.tex("minhhud_pipe")
	if pipe != null:
		var img := Rect2(854.436, 753.858, 1004.039, 332.926)
		for clip in [[Rect2(1189.958, 753.858, 668.516, 326.142), 0.0, 59, 1.0], [Rect2(948.757, 970.778, 241.214, 63.484), 94.321, 59, 1.0], [Rect2(1189.958, 753.858, 668.516, 326.142), 0.0, 61, H.M_PIPE_FRONT_ALPHA], [Rect2(948.757, 970.778, 241.214, 63.484), 94.321, 61, H.M_PIPE_FRONT_ALPHA]]:
			var box := Control.new()
			box.clip_contents = true
			box.mouse_filter = Control.MOUSE_FILTER_IGNORE
			box.position = clip[0].position - scr._h_machine._bag_at()
			box.size = clip[0].size
			box.z_index = clip[2]
			box.modulate.a = clip[3]
			var trect := TextureRect.new()
			trect.texture = pipe
			trect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			trect.stretch_mode = TextureRect.STRETCH_SCALE
			trect.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
			trect.mouse_filter = Control.MOUSE_FILTER_IGNORE
			trect.position = Vector2(img.position.x + clip[1], img.position.y) - clip[0].position
			trect.size = img.size
			box.add_child(trect)
			holder.add_child(box)
	var lever := UiSkin.tex("minhhud_lever")
	if lever != null:
		var lr := Rect2(1710.894, 753.503, 20.323, 148.617)
		var trect := TextureRect.new()
		trect.texture = lever
		trect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		trect.stretch_mode = TextureRect.STRETCH_SCALE
		trect.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		trect.position = lr.position - scr._h_machine._bag_at()
		trect.size = lr.size
		trect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		trect.z_index = 63
		trect.pivot_offset = H.M_LOOP_C - lr.position
		holder.add_child(trect)
		_minh_lever = trect
	var cap := MinhParts.Cap.new()
	cap.position = -scr._h_machine._bag_at()
	cap.z_index = 64
	holder.add_child(cap)


## MinhHUD: the round Chant / Pass button is one picture (MinhParts.Disc); its real Buttons (Chant = the red upper part, Pass = the plate under it; Release covers all of it) only take the
## clicks and tell the picture which part is pressed or under the mouse.
func _wire_minh_buttons() -> void:
	if not NewUiLayout.minh:
		return
	var set_disc := func(k: int) -> void:
		if scr._minh_disc != null:
			scr._minh_disc.set_press(k)
	for pair in [[scr._cast_btn, 2], [scr._end_btn, 3]]:
		var b: Button = pair[0]
		var down: int = pair[1]
		b.button_down.connect(func() -> void: set_disc.call(down))
		b.button_up.connect(func() -> void: set_disc.call(1 if b.is_hovered() else 0))
		b.mouse_entered.connect(func() -> void: set_disc.call(1))
		b.mouse_exited.connect(func() -> void: set_disc.call(0))


func _fit_bottom() -> void:
	if _puppet_strips():  # (the Puppet HUD is placed exactly as the PDF has it: nothing slides)
		_place_spell_row()
		return
	# (the panels are first laid out at their design spots and slid down once their real heights are known: keep them
	# invisible until then, or the first frame shows them too high)
	var movers := [scr._spell_row, scr._chant_panel, scr._bag_panel, scr._player_panel, scr._log]
	for n in movers:
		if n != null:
			n.modulate.a = 0.0
	await FightWait.frame(scr)
	if not is_instance_valid(scr._bag_panel):
		return
	var dy := (scr.size.y if scr.size.y > 0.0 else 1080.0) - FightScreen.BOTTOM_MARGIN - (scr._bag_panel.position.y + scr._bag_panel.size.y)
	var puppet := _puppet_strips()
	if puppet:  # (the Puppet strips are low: the Keeper's panel is the tallest part of the block, it sets the limit)
		dy = minf(dy, (scr.size.y if scr.size.y > 0.0 else 1080.0) - FightScreen.BOTTOM_MARGIN - (scr._player_panel.position.y + scr._player_panel.size.y))
	for n in movers:
		if n != null:
			if not (puppet and n == scr._spell_row):
				n.position.y += dy
			n.modulate.a = 1.0
	if scr._stage != null and puppet:
		_place_spell_row()  # the stage's front face reaches down to the top of the Chant strip
	scr._log.size.y = maxf(60.0, 1016.0 - scr._log.position.y)  # stop above the Menu button


func _build_spells() -> void:
	for c in scr._spell_row.get_children():  # (taken out at once: while the old holders still stand beside the new ones the row's minimum width doubles, the row grows and stays
		scr._spell_row.remove_child(c)  # wider, and its centred cards slide to the right: that was the bug after the second fight)
		c.queue_free()
	scr._spell_row.size.x = 1920.0
	scr._spell_row.position.x = 0.0
	scr._spell_row.alignment = BoxContainer.ALIGNMENT_CENTER
	scr._cards.clear()
	var n := scr.fight.shown_spells().size()
	var gap := FightScreen.SPELL_GAP
	var row_w := FightScreen.ROW_WIDTH
	if _puppet_strips():  # (Puppet: the row is centred, and its right end stops at the Chant strip's: the cards must not cover the lottery machine)
		row_w = minf(row_w, 2.0 * (scr._h_machine._bag_at().x + PuppetLayout.FRAME_CHANT.x - 960.0))
	if scr._nu_ui:  # (New UI: the row is centred where the page has it, as wide as the screen allows around that point)
		var right_end := 1795.0 if UiSkin.is_hud2() and not UiSkin.is_minhhud() else 1920.0 - FightScreen.SPELL_MARGIN  # (Puppet HUD ver 2: its glass tube stands up at the far right)
		row_w = 2.0 * minf(NewUiLayout.SPELL_CENTER_X - FightScreen.SPELL_MARGIN, right_end - NewUiLayout.SPELL_CENTER_X)
		scr._spell_row.position.x = NewUiLayout.SPELL_CENTER_X - 960.0
	# one size for every card, whatever their number: as big as SPELL_ROW_FITS cards side by side with a small gap between
	# them (fewer cards keep that size and gap, centred; only more than that shrink to fit)
	var fit := minf(1.0, (row_w - gap * (FightScreen.SPELL_ROW_FITS - 1)) / (FightScreen.SPELL_ROW_FITS * SpellCard.W))
	fit = minf(fit, (row_w - gap * maxf(0, n - 1)) / maxf(1.0, n * SpellCard.W))
	fit = floorf(SpellCard.W * fit) / SpellCard.W  # (a whole number of pixels wide: every gap comes out exactly the same)
	scr._spell_row.add_theme_constant_override("separation", roundi(gap))
	for s in scr.fight.shown_spells():
		var card := SpellCard.make(s)
		card.clicked.connect(scr._h_input._on_card_clicked)
		# each card sits in a holder of its shrunk size, so the row lays out correctly
		var holder := Control.new()
		holder.custom_minimum_size = Vector2(SpellCard.W, SpellCard.H) * fit
		holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.size = Vector2(SpellCard.W, SpellCard.H)
		card.base_scale = fit
		card.scale = Vector2(fit, fit)
		holder.add_child(card)
		scr._spell_row.add_child(holder)
		scr._cards.append(card)
	_place_spell_row()


func _hand_going_down(e: EnemyState) -> bool:
	return e.has_passive("hand") and scr.fight != null and not scr.fight.hm.is_empty() and int(scr.fight.hm.phase) < 2 and scr.fight.enemies.has(e)


func _sync_views() -> void:
	var live := scr.fight.enemies.filter(func(e): return not e.is_dead() or e.knocked or _hand_going_down(e) or e.has_passive("armadillo") or e.has_meta("yielded") or (e.has_passive("veil_falls") and e.phase == 1))  # (the Armadillo doesn't break: his ending plays; the Veiled Eyes do not break either: the veil falls and the same puppet unfolds)  # (a knocked-out hand stays in view)
	var hm := not scr.fight.hm.is_empty() and HandymanStage.available()  # (the Handyman fight with its art: hands on the body's shoulders)
	var same := live.size() == scr._views.size() and live.all(func(e): return scr._views.has(e))
	if same:
		return  # (the places are kept: see _row_order)
	for e in scr._views:  # (Puppet Stage: a puppet that was defeated breaks into pieces)
		var old: EnemyView = scr._views[e]
		if e.is_dead() and not e.knocked and not _hand_going_down(e) and is_instance_valid(old) and is_instance_valid(old.creature):
			if old.creature.has_rig():
				scr._h_anim._shatter_arm(old.creature)
			else:
				PuppetShatter.spawn(scr, old.creature)
	var had := scr._views.keys()
	var drops := {}  # hand -> how far down on the floor its arm was (the view is rebuilt, the fall goes on from there)
	for e in scr._views:
		var ov: EnemyView = scr._views[e]
		if is_instance_valid(ov) and is_instance_valid(ov.creature) and ov.creature.has_rig():
			drops[e] = ov.creature._drop_t
	if hm:
		if scr._hm_stage == null or not is_instance_valid(scr._hm_stage):
			for c in scr._enemy_row.get_children():
				scr._enemy_row.remove_child(c)
				c.queue_free()
			scr._hm_stage = HandymanStage.new()
			scr._hm_stage.setup()
			scr._enemy_row.add_child(scr._hm_stage)
		for c in scr._hm_stage.get_children():
			if c is EnemyView:
				scr._hm_stage.remove_child(c)
				c.queue_free()
		scr._hm_stage._ghosts.clear()
	else:
		for c in scr._enemy_row.get_children():
			scr._enemy_row.remove_child(c)
			c.queue_free()
	var widths := {}  # (the width each one took: a dead one's slot stays this wide)
	for e in scr._views:
		if is_instance_valid(scr._views[e]):
			widths[e] = maxf((scr._views[e] as Control).custom_minimum_size.x, (scr._views[e] as Control).size.x)  # (as wide as it really stood)
	scr._slot_w.merge(widths, true)
	if _row_fight != scr.fight:
		_row_fight = scr.fight
		_row_order.clear()
		scr._slot_w.clear()
	for i in live.size():  # (a newcomer stands next to the one before it in the fight: a split, a summon)
		if not (live[i] in _row_order):
			var at := _row_order.find(live[i - 1]) + 1 if i > 0 else 0
			_row_order.insert(at, live[i])
	scr._views.clear()
	_light_home.clear()  # (a new row: the lights are measured again once it has settled)
	_lights_from = Engine.get_process_frames()
	var body_out := false
	if not hm:
		for e in _row_order:
			if not (e in live):
				var gap_slot := Control.new()  # (an enemy that is gone: its place stays empty, nobody moves over)
				gap_slot.custom_minimum_size = Vector2(float(scr._slot_w.get(e, 300.0)), 1.0)
				gap_slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
				gap_slot.set_meta("slot", true)
				scr._enemy_row.add_child(gap_slot)
	for e in live:
		var v := EnemyView.new()
		v.setup(e, scr.fight)
		v.clicked.connect(scr._h_input._on_enemy_clicked)
		v.hp_clicked.connect(scr._h_input._on_hp_clicked)
		if not hm:
			scr._enemy_row.add_child(v)
			scr._enemy_row.move_child(v, _row_order.find(e))
		elif e.id == "handyman":
			scr._hm_stage.add_body(v)
			body_out = true
		elif HandymanRig.ARMS.has(e.id):
			scr._hm_stage.add_hand(e, v, not (e in had), float(drops.get(e, -1.0)))
			v.creature.drop_hold = scr._rally_hold
		else:  # (Test mode can put any enemy beside the Handyman: only his own hands hang on his shoulders, the others stand in the row)
			scr._enemy_row.add_child(v)
		scr._views[e] = v
		if e == scr._spider_away:
			scr._h_anim._hold_spider_up(v)
	if hm:
		scr._hm_stage.set_real(body_out or scr.fight.enemies.any(func(e): return e.id == "handyman" and e.is_dead()))  # (he is down for good: his plain picture must not stand there again after he has shattered)
		scr._hm_stage.sync_ghosts(live.map(func(e): return e.id), int(scr.fight.hm.phase), scr.fight)
	else:
		_space_enemy_row()


var _gap_fight: Fight  # the fight whose gap between enemies is set: it stays for the fight (a death must not move anyone)


func _space_enemy_row() -> void:
	if _gap_fight == scr.fight and scr.fight != null:
		return
	var views := scr._enemy_row.get_children().filter(func(c): return c is EnemyView)
	var places := scr._enemy_row.get_children().filter(func(c): return c is EnemyView or c.has_meta("slot"))
	if places.size() < 2:
		return
	var total := 0.0
	for v in places:
		total += (v as Control).custom_minimum_size.x
	var gap := clampf((1840.0 - total) / float(places.size() - 1), 20.0, FightScreen.ENEMY_GAP_MAX)
	if views.all(func(v): return v.enemy.has_passive("avenger") or v.enemy.has_passive("retainer")):
		gap = FightScreen.SAMURAI_GAP  # (the Samurai and his Retainer stand side by side, their puppets may overlap a little)
	if views.size() == 2 and views[0].enemy.has_passive("big_shield") and views[1].enemy.has_passive("behind_shield"):
		gap = FightScreen.DUO_GAP  # (the Undying Duo: the Necromancer stands right behind his Shield Bearer, a little to the right)
	scr._enemy_row.add_theme_constant_override("separation", int(gap))
	_gap_fight = scr.fight


func _chant_string() -> String:
	var s := ""
	for i in scr.chant_idx:
		s += scr.fight.player.stock[i].el
	return s


func _place_hp_texts() -> void:
	if not scr._puppet_hud or scr._heart == null:
		return
	scr._hp_label.size = PuppetTopHud.RING_TEXT  # (in the ring: see _fit_hud_frames)


func _refresh_all() -> void:
	var p := scr.fight.player
	_set_info(("Act %d · Floor %d" % [scr.run.act, scr.run.floor_no()]) if scr.map_mode else ("Act %d · Floor %d
Turn %d" % [scr.run.act, scr.run.floor_no(), scr.fight.turn]))  # (two lines on the sign)
	scr._hp_bar.set_values(p.hp, p.max_hp, p.shield + p.lasting)
	if scr._machine != null:
		scr._machine.set_veil(p.confuse_turns > 0)  # Confuse: a black veil over the slot machine's reels
	if scr._danger:
		scr._danger.target = DangerVignette.strength(p.hp, p.max_hp)
	scr._hp_label.text = ("%d/%d" if scr._puppet_hud else "HP %d / %d") % [maxf(0, p.hp), p.max_hp]
	if scr._puppet_hud:
		# the ring of the bar holds HP and Shield (blue stripes on the bar are Shield and Lasting together); "Lasting N" stands under the bar
		var total: float = p.shield + p.lasting
		scr._shield_label.text = "%d" % total
		scr._shield_box.visible = total > 0.0
		_lasting_label.text = "Lasting %d" % p.lasting
		_lasting_label.visible = p.lasting > 0.0
	else:
		# Shield isn't a status badge: it's the blue glass on the HP bar, and its amount goes beside your HP (its own small badge)
		var has_pic := scr._shield_box.get_child_count() > 1
		var shield_text := ""
		if p.shield > 0.0:
			shield_text = ("%d" if has_pic else "Shield %d") % p.shield
		if p.lasting > 0.0:
			shield_text += ("  Lasting %d" % p.lasting) if shield_text != "" else "Lasting %d" % p.lasting
		scr._shield_label.text = shield_text
		scr._shield_box.visible = shield_text != ""
	_place_hp_texts()
	_refresh_statuses()
	_refresh_bottles()
	_fit_hud_frames()
	_refresh_coin()
	scr._arts.update_charges(p)
	if not _circus_strips():
		for c in scr._next_row.get_children():
			c.queue_free()
		for d in p.next_draw:
			var ic := ElementIcon.make(d.el, 44)
			ic.temp = d.temp
			scr._next_row.add_child(ic)
	_refresh_chant()
	_refresh_stock()
	scr._h_machine._sync_tube()  # (after the stock: at a new turn the stock takes the waiting balls out first)
	var chant := _chant_string()
	var pv := {}
	if scr.phase == "build" and chant != "":
		pv = scr.fight.preview(chant)
	elif scr.phase == "spells" and scr._step_pos < 0 and not scr._released:
		pv = scr.fight.preview(scr.fight.chant_string(), false)
	if scr.phase == "build" and not pv.has("invoke"):
		# nothing chanted yet: the Invoker still shows which of his spells he'd cast (the closest)
		var inv := {}
		for e in scr.fight.alive():
			if e.def.get("invokes", false):
				inv[e] = scr.fight.invoke_picks(e, "")
		pv["invoke"] = inv
	for e in scr._views:
		var v: EnemyView = scr._views[e]
		var idx := scr.fight.enemies.find(e)
		v.targetable = scr.aiming and idx in scr.aim_cands
		v.targeted = scr.aiming and scr.aim_cands.size() > 0 and idx == scr.aim_cands[scr.aim_i]
		v.refresh(pv)
	for card in scr._cards:
		var s: Dictionary = card.spell
		var dl := scr.fight.durability_left(s)
		card.durability_left = maxi(0, dl) if dl >= 0 or Fight.base_durability(s) > 0 else -1  # (the card shows what's left)
		card.durability_max = scr.fight.durability_max(s)  # (out of how much: "Durability 2/3")
		card.state = ""
		card.state_text = ""
		card.ignited = p.ignited.has(s.id)
		card.virus = int(p.virus.get(s.id, 0))
		card.ignite_dmg = scr.fight.ignite_damage(s.id)
		card.cracks = 3 if scr.fight.broken.has(s.id) else scr.fight.hammer_hits.get(s.id, 0)
		if UiSkin.is_puppet() and card.cracks > 0 and card.get_meta("split_level", 0) != card.cracks:
			scr._h_anim._split_card(card, card.cracks, false)
		if scr.phase == "spells" and scr.fight.used.has(s.id) and scr.fight.charges.get(s.id, 0) <= 0 and not p.used_powers.has(s.id):
			card.state = "spent"  # cast this turn: dimmed until the turn is over
		if scr.fight.broken.has(s.id):
			card.state = "broken"
			card.state_text = "BROKEN"
		elif p.used_powers.has(s.id):
			card.state = "used"
			card.state_text = "Gone for this fight" if not s.get("power", false) else "Power in effect"
		elif p.cooldowns.has(s.id) and p.cooldowns[s.id] > 0 and not scr.fight.charges.has(s.id):
			# (the turn after it's cast counts as 1; the turn it's cast in shows the full wait)
			var wait: int = p.cooldowns[s.id] - (1 if scr.fight.used.has(s.id) else 0)
			card.state = "cooldown"
			card.state_text = "COOLDOWN\n%d turn%s" % [maxi(1, wait), "" if maxi(1, wait) == 1 else "s"]
		elif p.silenced.has(s.id):
			card.state = "silenced"
			card.state_text = "SILENCED\n%d turn%s" % [p.silenced[s.id], "" if p.silenced[s.id] == 1 else "s"]
		elif p.locks.has(s.id):
			card.state = "locked"
			card.lock_pattern = p.locks[s.id]
		card.fires = pv.get("spells", {}).get(s.id, 0) if scr.phase == "build" else 0
		card.charges = scr.fight.charges.get(s.id, 0) if scr.phase == "spells" else 0
		if scr.phase != "spells" and scr.fight.stored.has(s.id) and scr.fight.usable_spells().has(s):
			card.charges = 1  # stored: it always looks awake (wobbling, shining), even between turns; cast it after a Chant
		if s.get("anti", false):
			# an anti-spell comes alive with the chant, unless the chant contains its pattern (that breaks it)
			var broken: bool = card.fires > 0 if scr.phase == "build" else scr.fight.anti_broken.has(s.id)
			card.fires = 0
			if broken and card.state == "":
				card.state = "broken"
				card.state_text = "BROKEN\nthis turn"
		card.aiming = scr.aiming and card == scr.aim_card
		card.refresh()
	scr._log.text = "\n".join(scr.fight.lines.slice(maxi(0, scr.fight.lines.size() - 5)))
	scr._h_anim._light_patterns()
	# one main button: Chant while you build, then Release once the chant is spoken
	scr._clear_btn.visible = scr.phase == "build"
	scr._end_btn.visible = scr.phase == "build"
	scr._end_btn.disabled = scr.busy
	scr._clear_btn.text = "Clear" if _puppet_strips() else UiTheme.hk("Clear", "⌫")  # (the Puppet buttons are small: no "(key)")
	scr._end_btn.text = "Pass" if _puppet_strips() else UiTheme.hk("Pass", "E")
	if scr.phase == "build":
		scr._cast_btn.text = "Chant" if _puppet_strips() else UiTheme.hk("Chant", "Enter")
		scr._cast_btn.disabled = scr.busy or scr.chant_idx.is_empty() or scr.fight.player.stun_turns > 0
	else:
		scr._cast_btn.text = "Release" if _puppet_strips() else UiTheme.hk("Release", "E")
		scr._cast_btn.disabled = scr.busy or scr.aiming or scr.move_view != null or scr.pick_view != null or scr.chant_mode != ""
	if NewUiLayout.v2:  # (NewUI Ver2: Clear, Chant, Release and Pass have their words painted in)
		scr._clear_btn.text = ""
		scr._end_btn.text = ""
		scr._cast_btn.text = ""
		var kind2 := "chant" if scr.phase == "build" else "release"  # (two painted buttons of the same form: Chant, then Release)
		if scr._cast_kind != kind2:
			scr._cast_kind = kind2
			UiTheme.style_puppet_button(scr._cast_btn, kind2, 18)
	if NewUiLayout.hud2:  # (Puppet HUD ver 2: the words are painted in the buttons' pictures)
		scr._clear_btn.text = ""
		scr._end_btn.text = ""
		scr._cast_btn.text = ""
		scr._cast_btn.tooltip_text = "Chant (Enter)" if scr.phase == "build" else "Release (E)"
		var cast_kind := "chant" if scr.phase == "build" else "release"  # (two painted buttons: Chant, then Release)
		if scr._cast_kind != cast_kind:
			scr._cast_kind = cast_kind
			UiTheme.style_puppet_button(scr._cast_btn, cast_kind, 18)
			_minh_flip(cast_kind)
		if scr._minh_disc != null:
			scr._minh_disc.enabled = not scr._cast_btn.disabled
	for b in _test_btns:
		b.disabled = scr.busy or scr._auto_busy or scr.phase != "build" or scr.aiming or scr.move_view != null or scr.pick_view != null or scr.chant_mode != "" or scr.fight.over
	var live_spells := scr.fight.charges.size() > 0 and scr.phase == "spells"
	if not scr.aiming and not scr.busy and scr.move_view == null and scr.pick_view == null and scr.chant_mode == "":
		if scr.phase == "build" and scr.fight.player.stun_turns > 0:
			scr._prompt.text = "You are Stunned: your turn is skipped."
		elif scr.phase == "build":
			scr._prompt.text = "" if chant != "" else "Build a chant: when it is Released, enemies lose the longest start of their Essence found in it. Matching spells come alive."
		elif live_spells:
			scr._prompt.text = "Your spells are alive: click them to cast, in any order."
		else:
			scr._prompt.text = "Nothing left to cast." if scr.auto_release else "Nothing left to cast: press Release!"
	# every spell is cast: the Release button pulses so you know what to press next
	scr._release_glow = scr.phase == "spells" and not live_spells and not scr._cast_btn.disabled and not scr._released and not scr.fight.over


func _refresh_chant() -> void:
	var p := scr.fight.player
	var slots := p.chant_slots()
	if scr.chant_idx.size() > slots:
		scr.chant_idx.resize(slots)
	if is_instance_valid(scr._drag) or is_instance_valid(scr._bdrag):
		return
	for c in scr._chant_row.get_children():
		c.queue_free()
	var shown: Array = []  # element letters to draw
	if scr.phase == "build":
		for i in scr.chant_idx:
			shown.append(p.stock[i].el)
	else:
		shown = scr.fight.chant.duplicate()
	var n := maxi(_chant_rings(), shown.size())
	var lay := _chant_layout(shown.size())
	scr._chant_row.add_theme_constant_override("separation", int(lay.y))
	for i in n + 1:
		if i == n:
			break
		var slot := Panel.new()
		var px := int(lay.x)
		slot.custom_minimum_size = Vector2(px, px)
		var lit: bool = i == scr._step_pos or (scr.chant_mode == "pick" and i == scr.chant_i)
		var slot_art := UiSkin.box("chant_slot_empty")
		if slot_art != null:
			slot.add_theme_stylebox_override("panel", slot_art)
			slot.self_modulate = Color(1.7, 1.45, 0.7) if lit else Color.WHITE
		else:
			var sb := StyleBoxFlat.new()
			sb.bg_color = Color(0, 0, 0, 0.35)
			sb.border_color = Color(1, 0.9, 0.4) if lit else Color(0.4, 0.5, 0.4, 0.8)
			sb.set_border_width_all(4 if i == scr._step_pos else 2)
			sb.set_corner_radius_all(px / 2)
			slot.add_theme_stylebox_override("panel", sb)
		if i >= shown.size() and p.toll > 0 and i >= p.chant_slots():
			var stone := ElementIcon.make("stone", px)  # Burden: past the cap the slot is filled with a stone orb
			stone.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			stone.tooltip_text = "Burden: this slot is stone."
			slot.add_child(stone)
		if i < shown.size():
			var ic := ElementIcon.make(shown[i], px)
			if scr.phase == "build":
				ic.temp = p.stock[scr.chant_idx[i]].temp
				if scr._flying.has(p.stock[scr.chant_idx[i]].uid):
					ic.modulate.a = 0.0  # it lands here in a moment
				var idx := i
				slot.gui_input.connect(func(ev): if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT: scr._h_input._press_element("chant", idx))
				slot.mouse_default_cursor_shape = Control.CURSOR_DRAG
				slot.mouse_entered.connect(func():
					ic.set_hover(true)
					Audio.play("ui_hover", -8.0))
				slot.mouse_exited.connect(func(): ic.set_hover(false))
			else:
				ic.highlight = i == scr._step_pos or (scr.chant_mode == "pick" and i == scr.chant_i)
				ic.dim = scr._step_pos >= 0 and i > scr._step_pos
				if scr.chant_mode == "pick":
					if scr._chant_blocked(i):
						ic.dim = true  # (already the colour the brush paints)
					var ci := i
					slot.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
					slot.gui_input.connect(func(ev): if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT: scr._h_anim._emit_chant_done(ci))
			ic.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			slot.add_child(ic)
		scr._chant_row.add_child(slot)
	var note := "%d Essence" % scr.chant_idx.size()
	if _puppet_strips():
		note = ""  # (Puppet Stage: no plain count; only what needs saying: a Toll, the chant is spoken, Hypnotized)
	if p.toll > 0:
		note = "%d / %d Essence (Burden)" % [scr.chant_idx.size(), slots]
	if p.confuse_turns > 0 and scr.phase == "build":
		note += ("" if note == "" else "   ·   ") + "CONFUSED: you can't see what is coming next"
	scr._chant_note.text = note
	scr._chant_note.tooltip_text = note


## The bag holds the elements that are not in the chant. Each element keeps its own icon (found by its uid), so
## when the bag changes the icons glide to their new places instead of being rebuilt.
func _refresh_stock() -> void:
	var p := scr.fight.player
	var order := range(p.stock.size())
	order.sort_custom(func(a, b): return "FWA".find(p.stock[a].el) < "FWA".find(p.stock[b].el) or ("FWA".find(p.stock[a].el) == "FWA".find(p.stock[b].el) and a < b))
	var held_uid := -1  # an element being dragged out of the bag is in your hand, not in the bag
	if is_instance_valid(scr._bdrag) and scr._bdrag_src.get("kind", "") == "stock":
		held_uid = p.stock[scr._bdrag_src.i].uid
	var shown: Array = []
	var live := {}
	for i in order:
		if i in scr.chant_idx or p.stock[i].uid == held_uid or scr._cast_uids.has(p.stock[i].uid):
			continue
		shown.append(i)
		live[p.stock[i].uid] = true
	for uid in scr._bag_icons.keys():
		if not live.has(uid):
			scr._bag_icons[uid].queue_free()
			scr._bag_icons.erase(uid)
			scr._bag_target.erase(uid)
	var circus := _circus_strips()
	var per_row := maxi(1, int((FightScreen.BAG_W + FightScreen.BAG_GAP) / (FightScreen.BAG_PX + FightScreen.BAG_GAP)))
	var rows := maxi(1, ceili(float(shown.size()) / per_row))
	if not circus:
		scr._stock_row.custom_minimum_size.y = rows * (FightScreen.BAG_PX + FightScreen.BAG_GAP) - FightScreen.BAG_GAP
	var rolled: Array = []  # Cirus: the Essence that are new this time and roll out of the tube
	var arrange: Array = shown.map(func(i): return p.stock[i].uid)  # (left to right)
	if _puppet_strips():
		var newcomers := arrange.filter(func(u): return not scr._bag_icons.has(u) and not scr._bag_seen.has(u) and not scr._flying.has(u))
		if not newcomers.is_empty() or scr._launching > 0 or scr._tube_prep or scr._resort_wait or scr._keep_bag_order:
			# while balls are being fired the ones already there keep their places and the new ones stack after them (they swap into
			# their types only when the shooting is over: _resort_bag)
			var keep := scr._bag_order.filter(func(u): return arrange.has(u))
			arrange = keep + arrange.filter(func(u): return not keep.has(u))
		scr._bag_order = arrange
	var swapped := false
	var delay := scr._bag_delay
	scr._bag_delay = 0.0
	for k in shown.size():
		var s: Dictionary = p.stock[shown[k]]
		var uid: int = s.uid
		var target := scr._h_machine._bag_slot(arrange.find(uid) if _puppet_strips() else k, shown.size()) if circus else Vector2((k % per_row) * (FightScreen.BAG_PX + FightScreen.BAG_GAP), (k / per_row) * (FightScreen.BAG_PX + FightScreen.BAG_GAP))
		scr._bag_target[uid] = target
		var ic: ElementIcon = scr._bag_icons.get(uid)
		var fresh := ic == null
		if fresh:
			ic = ElementIcon.make(s.el, FightScreen.BAG_PX)
			ic.size = Vector2(FightScreen.BAG_PX, FightScreen.BAG_PX)
			ic.pivot_offset = Vector2(FightScreen.BAG_PX, FightScreen.BAG_PX) / 2.0
			ic.mouse_filter = Control.MOUSE_FILTER_STOP
			ic.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
			ic.gui_input.connect(func(ev): if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT: scr._h_input._press_element("stock", _stock_index(uid)))
			ic.mouse_entered.connect(func():
				ic.set_hover(true)
				Audio.play("ui_hover", -8.0))
			ic.mouse_exited.connect(func(): ic.set_hover(false))
			ic.position = target
			scr._stock_row.add_child(ic)
			scr._bag_icons[uid] = ic
		ic.el = s.el
		ic.temp = s.temp
		ic.frozen = s.frozen
		ic.freeze_n = int(s.get("freeze_n", 0))
		ic.dim = scr.phase != "build"
		if not ic.has_meta("rolling"):
			ic.modulate.a = 0.0 if scr._flying.has(uid) else 1.0
		var tip: String = Elements.NAMES[s.el]
		if s.temp:
			tip += " (conjured: fades at the end of this turn)"
		if s.frozen:
			tip += " (frozen for %d turn%s: can't be used)" % [maxi(1, int(s.get("freeze_n", 1))), "" if int(s.get("freeze_n", 1)) <= 1 else "s"]
		ic.tooltip_text = tip
		ic.queue_redraw()
		if fresh:
			var brand_new := not scr._bag_seen.has(uid)
			if not scr._flying.has(uid):
				if circus and brand_new and scr._direct_in > 0 and Time.get_ticks_msec() < scr._direct_until:
					scr._direct_in -= 1  # (a stolen Essence: it rests in its place, unseen until the one in the air has landed)
					ic.modulate.a = 1.0 if scr._direct_landed else 0.0
					if not scr._direct_landed:
						scr._direct_wait.append(ic)
				elif circus and brand_new:
					ic.modulate.a = 0.0
					ic.set_meta("rolling", true)  # (_tube_launch takes it from here)
					rolled.append([ic, target, uid])
				else:
					ic.scale = Vector2(0.3, 0.3)
					ic.create_tween().tween_property(ic, "scale", Vector2.ONE, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			scr._bag_seen[uid] = true
			ic.set_meta("goal", target)
		elif ic.get_meta("goal", Vector2(-1, -1)) != target:
			ic.set_meta("goal", target)
			if ic.has_meta("rolling"):
				continue  # (it is on its way: _roll_ball puts it on its final spot)
			if ic.has_meta("slide"):
				var old: Tween = ic.get_meta("slide")
				if old != null and old.is_valid():
					old.kill()
			var tw := ic.create_tween()
			if delay > 0.0:
				tw.tween_interval(delay)
			if scr._resort and absf(ic.position.x - target.x) > 1.0:  # (swapping into its type: up, across, down)
				swapped = true
				tw.tween_property(ic, "position", Vector2(ic.position.x, target.y - 12.0), 0.1).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
				tw.tween_property(ic, "position", Vector2(target.x, target.y - 12.0), FightScreen.BAG_MOVE).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
				tw.tween_property(ic, "position", target, 0.1).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
			else:
				tw.tween_property(ic, "position", target, FightScreen.BAG_MOVE).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
			ic.set_meta("slide", tw)
	if swapped:
		scr._h_anim._ball_sound("swap", -3.0)
	if not rolled.is_empty():
		scr._h_machine._tube_launch(rolled)


func _stock_index(uid: int) -> int:
	var st: Array = scr.fight.player.stock
	for i in st.size():
		if st[i].uid == uid:
			return i
	return -1


func _bag_center(uid: int) -> Vector2:
	var ic: Control = scr._bag_icons.get(uid)
	if ic != null and is_instance_valid(ic):
		return ic.global_position + Vector2(FightScreen.BAG_PX, FightScreen.BAG_PX) / 2.0
	return scr._stock_row.global_position + Vector2(FightScreen.BAG_PX, FightScreen.BAG_PX) / 2.0


## Where an element's icon will rest in the bag once it has settled.
func _bag_target_center(uid: int) -> Vector2:
	return scr._stock_row.global_position + scr._bag_target.get(uid, Vector2.ZERO) + Vector2(FightScreen.BAG_PX, FightScreen.BAG_PX) / 2.0


## How many empty rings to show: 8, or fewer under a Toll (its cap).
func _chant_rings() -> int:
	var cap := scr.fight.player.passive("chant_max") if scr.fight.player.passive("chant_max") > 0 else PlayerState.UNLIMITED  # (Burden: the rings stay, the last ones turn to stone)
	return mini(FightScreen.CHANT_RINGS_PUPPET if _puppet_strips() else FightScreen.CHANT_RINGS, cap)


## [orb size, gap between orbs] for a chant of `count` Essence. The gap goes negative (orbs overlap) when the
## chant is too long to fit.
func _chant_layout(count := -1) -> Vector2:
	if count < 0:
		count = scr.chant_idx.size() if scr.phase == "build" else scr.fight.chant.size()
	var n := maxi(_chant_rings(), count)
	var px := 58.0 if n <= 10 else 50.0
	if _puppet_strips():
		var step0 := NewUiLayout.RING_STEP if scr._nu_ui else PuppetLayout.RING_STEP
		var px0 := NewUiLayout.RING_PX if scr._nu_ui else FightScreen.PUPPET_RING_PX
		px = px0 if n <= 10 else px0 - 6.0
		var pstep := minf(step0, (step0 * 9.0 + px0 - px) / maxf(1.0, n - 1))
		return Vector2(px, pstep - px)
	var step := minf(px + 6.0, ((FightScreen.CHANT_W_CIRCUS if _circus_strips() else FightScreen.CHANT_W) - px) / maxf(1.0, n - 1))
	return Vector2(px, step - px)


func _chant_px() -> float:
	return _chant_layout().x


func _chant_slot_center(k: int) -> Vector2:
	var l := _chant_layout()
	return scr._chant_row.global_position + Vector2(k * (l.x + l.y) + l.x / 2.0, l.x / 2.0)


func _chant_changed() -> void:
	_refresh_all()
	scr.tut.emit("chant_changed", _chant_string())


# ------------------------------------------------------------------ building the chant by drag and drop


## ---- Test mode: Auto-fill and Auto-ball ------------------------------------------------------------------------------------
## Top left corner of the screen, side by side, so the rest of the screen stays exactly as in a real fight.
func _build_test_buttons() -> void:
	var specs := [
		["Auto-fill", scr._h_input._auto_fill, "Test mode: builds the chant that wakes as many of your spells as the Essence in your bag can."],
		["Auto-ball", scr._h_input._auto_ball, "Test mode: shoots new Essence out of the machine until the bag holds 10."]]
	for k in specs.size():
		var b := UiTheme.button(specs[k][0], specs[k][1], 15)
		if UiSkin.is_newui2() and UiSkin.tex("btn_teal") != null:  # (NewUI Ver2: the user's teal button, with the word on it)
			UiTheme.use_heading_font(b)
			for state in ["normal", "hover", "pressed", "disabled", "focus"]:
				var sb := UiSkin.scaled_box(["btn_teal"], 0.28, [8, 2, 8, 3])
				sb.modulate_color = {"hover": Color(1.25, 1.22, 1.15), "pressed": Color(0.62, 0.6, 0.58)}.get(state, Color.WHITE)
				b.add_theme_stylebox_override(state, sb)
			for c in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
				b.add_theme_color_override(c, Color(1.0, 0.95, 0.82))
			b.add_theme_color_override("font_outline_color", Color(0.05, 0.15, 0.13))
			b.add_theme_constant_override("outline_size", 3)
		elif _puppet_strips():
			UiTheme.use_heading_font(b)
			UiTheme.style_puppet_button(b, "clear", 15, false)
		b.tooltip_text = specs[k][2]
		b.custom_minimum_size = Vector2(112.0, 34.0)
		b.size = Vector2(112.0, 34.0)
		b.position = Vector2(8.0 + 120.0 * k, 8.0)
		b.z_index = 200  # (over the top HUD: this corner is the test buttons' only)
		scr.add_child(b)
		_test_btns.append(b)


## The name of the picture for a status badge (`b` is one entry of _status_badges), or "" when there is none.
func _badge_art_name(b: Array) -> String:
	var names: Array = []
	var id := String(b[2])
	if id == "" and b.size() > 4:  # a Power: by what it is made of
		var sp := scr.fight._find_spell(String(b[4]))
		var key: String = String(FightScreen.power_theme(sp).key)
		names = FightScreen.POWER_ART_NAMES.get(key, [])
	else:
		names = FightScreen.STATUS_ART_NAMES.get(id, [])
	for n in names:
		if UiSkin.tex(n) != null:
			return n
	return ""


func _status_badges() -> Array:
	var p := scr.fight.player
	var out := []
	if p.aegis > 0:
		out.append(["✨ Evasion %d" % p.aegis, Color(1.0, 0.8, 0.25), "evasion"])
	var th := p.thorns_turn + p.passive("thorns")
	if th > 0:
		out.append(["🌵 Thorns %d" % th, Color(0.5, 0.85, 0.25), "thorns"])
	if p.ethereal:
		out.append(["👻 Ethereal", Color(0.75, 0.7, 1.0), "ethereal"])
	if p.stun_turns > 0:
		out.append(["💫 Stunned", Color(1.0, 0.85, 0.3), "stun"])
	if p.echo_next:
		out.append(["🔔 Echo ready", Color(0.85, 0.6, 1.0), "echo"])
	if p.poison > 0:
		out.append(["🧪 Poison %d" % p.poison, Color(0.55, 0.9, 0.3), "poison"])
	if p.bleed > 0:
		out.append(["🩸 Bleed %d" % p.bleed, Color(0.95, 0.3, 0.3), "bleed"])
	if p.confuse_turns > 0:
		out.append(["🌀 Confused", Color(0.8, 0.4, 1.0), "confuse"])
	if p.blind_turns > 0:
		out.append(["🙈 Blind %d" % p.blind_turns, Color(0.7, 0.72, 0.78), "blind"])
	if p.vulnerable > 0:
		out.append(["🎯 Vulnerable %d" % p.vulnerable, Color(1.0, 0.45, 0.35), "vulnerable"])
	if p.brittle_turns > 0:
		out.append(["🧊 Brittle %d" % p.brittle_turns, Color(0.55, 0.75, 0.95), "brittle"])
	if p.toll > 0:
		out.append(["🪨 Burden %d" % p.toll, Color(0.75, 0.72, 0.68), "lock"])
	if p.overload > 0:
		out.append(["⚡ Overload %d" % p.overload, Color(1.0, 0.45, 0.3), "overload"])
	if p.disarmed_turns > 0:
		out.append(["🚫 Disarmed", Color(1.0, 0.55, 0.45), "disarmed"])
	if not p.silenced.is_empty():
		out.append(["🤐 Silenced", Color(0.8, 0.45, 1.0), "silence"])
	# every Power you've cast this fight: a badge for the rest of it (hover: what it does)
	for id in p.used_powers:
		var sp := scr.fight._find_spell(id)
		if id == "attunement" and p.passives.has("attune_el"):
			# its badge: the Essence you picked (hover: gain 1 of it each turn)
			var el: String = p.passives.attune_el
			out.append(["+%d each turn" % p.passive("attune"), Elements.COLORS[el], "attune_" + el,
				Keywords.tooltip(sp.name, "Gain %d %s each turn." % [p.passive("attune"), Elements.NAMES[el]], "[color=#9aa89a]Power: it lasts the whole fight.[/color]"), id])
		elif sp.get("power", false) and Fight.lasting_power(sp):  # (a one-off Power, like Open Grimoire: no badge)
			var pth := FightScreen.power_theme(sp)
			var badge: String = sp.get("badge_name", sp.name)  # (Cauterize shows as "Cauterizing")
			out.append(["%s %s" % [pth.icon, badge], pth.col, "", Keywords.tooltip(badge, SpellText.describe(sp), "[color=#9aa89a]Power: it lasts the whole fight.[/color]"), id])
	return out


func _refresh_statuses() -> void:
	if scr._puppet_hud:
		_refresh_statuses_compact()
		return
	for c in scr._status_row.get_children():
		c.queue_free()
	for b in _status_badges():
		var chip := TipPanel.new()  # its tooltip is rich text
		var col: Color = b[1]
		var pill := UiSkin.box("status_badge_pill", [17, 16, 17, 16], [14, 3, 14, 5])
		var icon: Control = UiSkin.icon(_badge_art_name(b), 24) if pill != null else null
		var text: String = b[0]
		if icon != null:
			text = text.substr(text.find(" ") + 1)  # the art replaces the leading emoji
		if String(b[2]).begins_with("attune_"):
			icon = ElementIcon.make(String(b[2]).substr(7), 24)  # (Attunement: the Essence you picked)
		if pill != null:
			pill.modulate_color = col.lightened(0.15)
			chip.add_theme_stylebox_override("panel", pill)
		else:
			var sb := StyleBoxFlat.new()
			sb.bg_color = col.darkened(0.35)
			sb.border_color = col.lightened(0.45)
			sb.set_border_width_all(2)
			sb.set_corner_radius_all(14)
			sb.shadow_color = Color(col, 0.55)
			sb.shadow_size = 7
			sb.content_margin_left = 10
			sb.content_margin_right = 10
			sb.content_margin_top = 2
			sb.content_margin_bottom = 2
			chip.add_theme_stylebox_override("panel", sb)
		var l := UiTheme.label(text, 19, Color.WHITE)
		l.add_theme_constant_override("outline_size", 5)
		l.add_theme_color_override("font_outline_color", col.darkened(0.7))
		l.mouse_filter = Control.MOUSE_FILTER_IGNORE
		if icon != null:
			var hb := HBoxContainer.new()
			hb.add_theme_constant_override("separation", 4)
			hb.mouse_filter = Control.MOUSE_FILTER_IGNORE
			hb.add_child(icon)
			hb.add_child(l)
			chip.add_child(hb)
		else:
			chip.add_child(l)
		var tip: String = Keywords.K.get(b[2], [0, 0, ""])[2]
		chip.tooltip_text = b[3] if b.size() > 3 else (Keywords.tooltip(b[0], tip) if tip != "" else "")
		if b.size() > 4:
			chip.set_meta("power_id", b[4])  # (a Power's badge: Echoed Voice echoes from it)
		chip.mouse_filter = Control.MOUSE_FILTER_STOP
		scr._status_row.add_child(chip)


func _refresh_bottles() -> void:
	for c in scr._bottle_row.get_children():
		c.queue_free()
	var bs: Array = scr.fight.player.bottles
	# painted themes: only the bottles you carry (the frame behind them grows and shrinks with them); Default shows the empty slots too
	var n_shown: int = bs.size() if UiSkin.is_new() else maxi(scr.run.bottle_slots() if scr.run else Bottles.BASE_SLOTS, bs.size())
	var chip_px := 64.0 if n_shown <= 3 else (52.0 if n_shown == 4 else 44.0)  # (five bottles must not push the frame out of the panel, nor squeeze the HP text)
	scr._bottle_row.add_theme_constant_override("separation", 6 if n_shown <= 3 else 0)
	if scr._nu_ui:  # (the five bottle slots of NewUiLayout)
		chip_px = NewUiLayout.BOTTLE_PX
		scr._bottle_row.add_theme_constant_override("separation", int(NewUiLayout.BOTTLE_CELL.x - NewUiLayout.BOTTLE_PX))
	elif scr._puppet_hud:  # (the bottle frame's five slots hold them 44 px each)
		chip_px = FightScreen.BOTTLE_PX
		scr._bottle_row.add_theme_constant_override("separation", int(FightScreen.BOTTLE_STEP - FightScreen.BOTTLE_PX))
	if NewUiLayout.v2:  # (NewUI Ver2: the rack holds 3 bottles, or 5 with the Bandolier: its cups are where the bottles stand)
		var slots: int = maxi(scr.run.bottle_slots() if scr.run else Bottles.BASE_SLOTS, bs.size())
		NewUi2Layout.set_rack(slots)
		chip_px = NewUiLayout.BOTTLE_PX
		scr._bottle_row.add_theme_constant_override("separation", int(NewUiLayout.BOTTLE_CELL.x - NewUiLayout.BOTTLE_PX))
		if _rack_upper != null:
			NewUi2Layout.place_rack_upper(_rack_upper, slots)
		if scr._nu_back != null:
			scr._nu_back.bottle_slots = slots
			scr._nu_back.queue_redraw()
		if scr._puppet_hud and scr._hp_bar != null and scr._arts != null:
			_fit_hud_nu()
	for i in n_shown:
		var chip := BottleChip.make(bs[i] if i < bs.size() else "", i, true, chip_px)
		chip.used.connect(scr._h_input._on_bottle)
		scr._bottle_row.add_child(chip)


var _row_order: Array = []  # every enemy of this fight in its place on the stage, the dead ones too (their places stay empty)


var _row_fight: Fight  # the fight _row_order belongs to


func _style_slam_label(l: Label, text: String, col: Color, outline: Color, font_px: int) -> void:
	l.text = text
	var f := SystemFont.new()
	f.font_names = PackedStringArray(["Impact", "Arial Black", "Segoe UI Black", "Arial"])
	f.font_weight = 900
	f.font_italic = true
	l.add_theme_font_override("font", UiTheme.with_fallbacks(f))
	l.add_theme_font_size_override("font_size", font_px)
	l.add_theme_color_override("font_color", col)
	l.add_theme_constant_override("outline_size", 22)
	l.add_theme_color_override("font_outline_color", outline)
	l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.6))
	l.add_theme_constant_override("shadow_offset_x", 8)
	l.add_theme_constant_override("shadow_offset_y", 10)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
