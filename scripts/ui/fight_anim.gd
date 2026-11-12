class_name FightAnim
extends RefCounted
## Animations and effects (moved out of fight_screen.gd, docs/plan_dot3_kien_truc.md L15): the code is unchanged except that FightScreen's own members are reached through `scr.`.

var scr: FightScreen


func _init(p_owner: FightScreen) -> void:
	scr = p_owner


var _shot_fired := false  # the shot already showed the hit, so the spell's own fly-in is skipped


## The sound of an Essence you move: "grab" (it leaves the bag / is picked up), "place" (it drops into the chant), "remove" (it goes back).
## The Puppet Stage plays only its wooden sounds (a grab is silent: the "hole" sounds when it lands in the chant, a return is the low "colide").
func _elem_sound(kind: String) -> void:
	if scr._h_hud._puppet_strips():
		if kind == "place" or kind == "grab":  # (the recordings start with a little silence: skipped, so the sound is at the click)
			Audio.play("wooden_ball_hole", 0.0, 1.0, 0.06)
		elif kind == "remove":
			Audio.play("wooden_ball_colide", 0.0, 0.8, 0.1)  # (the same knock, 20% lower)
		return
	Audio.play("elem_remove" if kind == "remove" else "elem_pickup")


## The sounds of the balls: the Puppet Stage has wooden ones (wooden_ball_*), the other themes keep the old pair.
func _ball_sound(kind: String, volume_db := 0.0, pitch := 1.0) -> void:
	var names := {"roll": "sfx_ball_roll", "hit": "sfx_ball_clack", "hole": "sfx_ball_clack"}
	if scr._h_hud._puppet_strips():
		names = {"roll": "wooden_ball_roll", "hit": "wooden_ball_colide", "hole": "wooden_ball_hole", "swap": "wooden_ball_swap"}
	if names.has(kind):
		Audio.play(names[kind], volume_db, pitch)


func _card_zoom(card: SpellCard, big: bool) -> void:
	if not is_instance_valid(card):
		return
	card.z_index = 20 if big else 0
	var fit := card.base_scale
	var s := 1.0 if big else fit
	# grow upwards and around its centre so it doesn't cover the chant area
	var off := Vector2(-(SpellCard.W * (s - fit)) / 2.0, -(SpellCard.H * (s - fit)))
	var tw := card.create_tween()
	tw.set_parallel()
	tw.tween_property(card, "scale", Vector2(s, s), 0.12)
	tw.tween_property(card, "position", off, 0.12)


## The Handyman's last stand: every hand lies on the floor. He turns to the crying face and shakes his whole body hard, then his own
## Essence steps out and he sucks the six hands up to his shoulders.
func _hm_rally_scene() -> void:
	var hands := func() -> Array:
		return scr._views.values().filter(func(v): return is_instance_valid(v) and is_instance_valid(v.creature) and v.creature.has_rig())
	if scr._hm_stage == null or not is_instance_valid(scr._hm_stage):
		scr._h_hud._sync_views()
		scr._h_hud._refresh_all()
		return
	scr._rally_hold = true
	for v in hands.call():
		v.creature.drop_hold = true  # (the fight state already has them up: the arms wait on the floor)
	_quake_body(FightScreen.RALLY_QUAKE)
	scr._h_hud._refresh_all()
	await _wait(1.0)
	scr._h_hud._sync_views()  # (his body steps out, with its one Essence: the shake goes on)
	scr._h_hud._refresh_all()
	_quake_body(FightScreen.RALLY_QUAKE - 1.0)
	await _wait(FightScreen.RALLY_QUAKE - 1.0)
	scr._rally_hold = false
	for v in hands.call():  # (he pulls the hands up one after another)
		v.creature.drop_hold = false
		scr._h_hud._refresh_all()
		Audio.play("enemy_spawn")
		await _wait(FightScreen.RALLY_GAP)
	await _wait(1.0)


## His body shakes hard for `t` seconds, crying: the plain picture of it and, if it already stands there as an enemy, its view.
func _quake_body(t: float) -> void:
	if scr._hm_stage != null and is_instance_valid(scr._hm_stage):
		scr._hm_stage.rally_quake(t)
	for e in scr._views:
		var v: EnemyView = scr._views[e]
		if e.id == "handyman" and is_instance_valid(v) and is_instance_valid(v.creature):
			v.creature.sad_forever = true
			v.creature.quake = t


## An element in the air, jumping between the bag and the chant on a little arc, growing or shrinking to the size
## of its new home. Its real icon waits (invisible) at the other end and pops in when this one lands.
func _fly(s: Dictionary, from: Vector2, to: Vector2, from_px: float, to_px: float) -> void:
	var uid: int = s.uid
	var ic := ElementIcon.make(s.el, from_px)
	ic.size = Vector2(from_px, from_px)
	ic.pivot_offset = ic.size / 2.0
	ic.temp = s.temp
	ic.z_index = 60
	ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	scr._fx.add_child(ic)
	var mid := (from + to) / 2.0 + Vector2(0, -46.0)
	var grow := to_px / from_px
	var tw := scr.create_tween()
	tw.tween_method(func(t: float):
		if not is_instance_valid(ic):
			return
		var pt := from.lerp(mid, t).lerp(mid.lerp(to, t), t)
		ic.position = pt - scr._fx.global_position - ic.size / 2.0
		ic.scale = Vector2.ONE * lerpf(1.0, grow, t), 0.0, 1.0, FightScreen.FLY_TIME).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_callback(func():
		if is_instance_valid(ic):
			ic.queue_free()
		scr._flying.erase(uid)
		scr._h_hud._refresh_stock()
		_light_patterns()  # the Essence has landed: the spells it builds towards light up now
		if scr.phase == "build":  # once the chant is spoken, its row belongs to the Release
			scr._h_hud._refresh_chant()
		_land(uid))


## While you build the chant, every spell lights the orbs of its pattern that the chant is building towards, in
## order, as each Essence lands: FF lights its first orb on the first F, its second on the next. A full match lights
## them all; taking Essence back dims them again. (Essence still in the air don't count yet.)
var _lit := {}  # spell id -> how many of its orbs are lit


func _light_patterns() -> void:
	var c := ""
	if scr.phase == "build":
		for i in scr.chant_idx:
			var st: Dictionary = scr.fight.player.stock[i]
			if scr._flying.has(st.uid):
				break
			c += st.el
	for card in scr._cards:
		if not is_instance_valid(card):
			continue
		var orbs: Array = card.live_orbs()
		var sp: Dictionary = card.spell
		var k := 0
		var gone: bool = card.state in ["silenced", "cooldown", "used"] or scr.fight.broken.has(sp.id)  # (silenced etc.: as if it weren't there)
		if scr.phase == "build" and c != "" and not sp.has("patterns") and not gone:
			k = _pattern_progress(String(sp.pattern), c)
		k = mini(k, orbs.size())
		var before: int = _lit.get(sp.id, 0)
		for j in orbs.size():
			var on := j < k
			if orbs[j].highlight != on:
				orbs[j].highlight = on
				orbs[j].queue_redraw()
		for j in range(before, k):
			_pop_orb(orbs[j])
		_lit[sp.id] = k


## How far the chant has got towards this pattern: all of it if it appears anywhere, otherwise the longest start of
## the pattern that the chant ends with ("?" matches anything).
func _pattern_progress(pattern: String, c: String) -> int:
	if pattern == "":
		return 0
	if not Chant.occurrences(pattern, c).is_empty():
		return pattern.length()
	for k in range(mini(pattern.length() - 1, c.length()), 0, -1):
		if Chant.matches_at(pattern.substr(0, k), c, c.length() - k):
			return k
	return 0


## A small pop as an orb lights up.
func _pop_orb(ic: Control) -> void:
	if not is_instance_valid(ic):
		return
	ic.pivot_offset = ic.size / 2.0
	var tw := ic.create_tween()
	tw.tween_property(ic, "scale", Vector2(1.3, 1.3), 0.07).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(ic, "modulate", Color(1.8, 1.75, 1.5), 0.07)
	tw.tween_property(ic, "scale", Vector2.ONE, 0.14).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(ic, "modulate", Color.WHITE, 0.2)


## The element that just arrived gives a small bounce.
func _land(uid: int) -> void:
	var node: Control = scr._bag_icons.get(uid)
	if node == null:
		var pos := -1
		for k in scr.chant_idx.size():
			if scr.fight.player.stock[scr.chant_idx[k]].uid == uid:
				pos = k
		var slots := scr._chant_row.get_children().filter(func(c): return c is Panel)
		if pos >= 0 and pos < slots.size() and slots[pos].get_child_count() > 0:
			node = slots[pos].get_child(0)
	if node != null and is_instance_valid(node):
		node.pivot_offset = node.custom_minimum_size / 2.0
		node.scale = Vector2(1.18, 1.18)
		node.create_tween().tween_property(node, "scale", Vector2.ONE, 0.12)


# ------------------------------------------------------------------ chant input


## Make whatever the player should click next pulse.
func _pulse_next_thing() -> void:
	var targets: Array = []
	if scr.busy or scr.fight.over:
		return
	if scr.phase == "build":
		targets = [scr._cast_btn] if not scr.chant_idx.is_empty() else [scr._stock_row]
	elif not scr.aiming and scr.pick_view == null and scr.chant_mode == "":
		var alive := scr._cards.filter(func(c): return c.charges > 0)
		targets = alive if not alive.is_empty() else [scr._cast_btn]
	for t in targets:
		var tw := (t as Control).create_tween().set_loops(3)
		tw.tween_property(t, "modulate", Color(1.6, 1.5, 1.0), 0.25)
		tw.tween_property(t, "modulate", Color.WHITE, 0.25)


## Release: the chant flies at the enemies element by element, then they act and your next turn starts.
func _damage_step() -> void:
	if scr.busy or scr.fight.over:
		return
	scr.busy = true
	scr.end_confirm = false
	scr.tut.emit("releasing", null)
	scr._prompt.text = "Release!"
	scr._h_hud._refresh_all()
	await scr.fight.finish_turn()
	await _after_turn()


func _after_turn() -> void:
	scr.phase = "build"
	scr._step_pos = -1
	scr._released = false
	scr._h_hud._sync_views()
	scr.busy = false
	scr._h_hud._refresh_all()
	if scr.fight.over:
		await _finish()
	else:
		scr.tut.emit("turn_start", scr.fight.turn)
		if scr.fight.player.stun_turns > 0:
			await _stunned_turn()


## Stunned: the turn is skipped whole. A beat to see it, then the enemies act (you still got your Essence).
func _stunned_turn() -> void:
	scr.busy = true
	_banner("Stunned!", Color(1.0, 0.85, 0.3), 1.0)
	Audio.play("sfx_stun_apply")
	scr._h_hud._refresh_all()
	await scr.get_tree().create_timer(1.4).timeout
	if scr.fight.over or not scr.is_inside_tree():
		return
	scr.chant_idx.clear()
	scr._prompt.text = "Stunned: the enemies act…"
	scr._h_hud._refresh_all()
	await scr.fight.pass_turn()
	await _after_turn()


func _charge_count() -> int:
	var n := 0
	for id in scr.fight.charges:
		n += scr.fight.charges[id]
	return n


func _finish() -> void:
	scr.busy = true
	var dillo: Array = scr.fight.enemies.filter(func(e): return e.has_passive("armadillo") and e.is_dead())
	scr._h_hud._lift_act_sign()
	if scr.fight.won and not dillo.is_empty():
		await scr._h_talk._armadillo_ending(dillo[0])
	for r in scr.fight.enemies.filter(func(e): return e.has_meta("yielded")):
		await _retainer_yields(r)
	if scr.fight.won and scr.stage_flow and scr._stage != null:  # Puppet Stage: the Victory sign drops from behind the ceiling, the HUD sinks
		await scr.get_tree().create_timer(0.5).timeout
		var perfect_run: bool = scr.fight.player.damage_taken <= 0.0
		var boss_win := scr.fight.enemies.any(func(e): return e.def.get("boss", false))
		if not boss_win:  # (a boss fight already played its own "boss_defeat": two victory sounds on top of each other were too much)
			Audio.result_sting("perfect_victory_fanfare" if perfect_run else "victory_fanfare")  # (the fight's music fades, the sound plays, then the map's music)
		else:
			Audio.fade_out_music()
			Audio.play_music_after("map", minf(Audio.get_sfx_length("boss_defeat"), 4.0))
		var sign_kind := "boss_defeated" if boss_win else ("perfect_victory" if perfect_run else "victory")  # (a boss always gets its own red board)
		var sign_text := "Boss Defeated!" if boss_win else ("Perfect Victory!" if perfect_run else "Victory!")
		await scr._stage.drop_sign(sign_text, Color(0.55, 0.08, 0.06) if boss_win else Color(0.30, 0.17, 0.07), sign_kind).finished
		await scr.get_tree().create_timer(1.0).timeout
		await scr._h_hud._hud_down()
		scr._stage.lift_sign()
		await scr.get_tree().create_timer(0.5).timeout
	elif scr.fight.won:
		await scr.get_tree().create_timer(0.3).timeout
		var perfect: bool = scr.fight.player.damage_taken <= 0.0
		if not await _result_banner("perfect" if perfect else "victory"):
			if perfect:
				await _slam("Perfect Victory!", Color(0.55, 1.0, 0.75), Color(0.0, 0.3, 0.2), 120)
			else:
				await _slam("Victory!", Color(0.75, 1.0, 0.5), Color(0.1, 0.28, 0.05), 140)
		await scr.get_tree().create_timer(0.5).timeout
	elif scr.run != null and scr.run.can_revive():
		await _seed_revival()
	else:
		if scr.stage_flow and scr._stage != null and ResourceLoader.exists(UiSkin.theme_dir() + "Stage/Shared/sign_defeat.png"):  # Puppet Stage: the Defeat board drops in
			Audio.result_sting("defeat_stinger", "")  # (the music fades; no music follows: the end screen)
			scr.set_meta("result_sfx", true)
			await scr._stage.drop_sign("Defeat", Color(0.3, 0.1, 0.08), "defeat").finished
			await scr.get_tree().create_timer(1.8).timeout
		elif not await _result_banner("defeat"):
			_banner("The last tree falls…", UiTheme.DANGER, 1.6)
			await scr.get_tree().create_timer(1.6).timeout
	scr.finished.emit(scr.fight.won)


## Losing with the Seed of Life: it shines on your artifact bar, flies to the middle of the screen growing as it goes,
## and bursts into a white flash; then the words, and the fight starts over (main.gd sends you back to the
## preparation of this same fight).
func _seed_revival() -> void:
	var from := Vector2(60, 70)
	for c in scr._arts.get_children():
		if c is ArtifactBar.ArtifactChip and c.id == "seed_of_life":
			from = c.get_global_rect().get_center()
	var seed_chip := ArtifactBar.ArtifactChip.make("seed_of_life")
	seed_chip.z_index = 90
	seed_chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	scr._fx.add_child(seed_chip)
	await scr.get_tree().process_frame
	seed_chip.pivot_offset = seed_chip.size / 2.0
	seed_chip.position = from - seed_chip.size / 2.0 - scr._fx.global_position
	Audio.play("spell_glow")
	# it shines where it is
	var shine := seed_chip.create_tween()
	for k in 3:
		shine.tween_property(seed_chip, "modulate", Color(2.4, 2.4, 1.8), 0.12)
		shine.parallel().tween_property(seed_chip, "scale", Vector2(1.35, 1.35), 0.12)
		shine.tween_property(seed_chip, "modulate", Color(1.3, 1.3, 1.1), 0.12)
		shine.parallel().tween_property(seed_chip, "scale", Vector2.ONE, 0.12)
	await shine.finished
	# then flies to the middle, growing
	var mid := Vector2(960, 470) - seed_chip.size / 2.0 - scr._fx.global_position
	var fly := seed_chip.create_tween().set_parallel(true)
	fly.tween_property(seed_chip, "position", mid, 0.8).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	fly.tween_property(seed_chip, "scale", Vector2(5, 5), 0.8).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	fly.tween_property(seed_chip, "modulate", Color(2.0, 2.0, 1.6), 0.8)
	var v := Vfx.make(scr._fx, 85)
	v.shaker = _shake
	v.emit(Vector2(960, 470), 0.8, 0.0, func(vv: Vfx, _it: Vfx.Item, _d: float) -> void:
		var p := seed_chip.global_position + seed_chip.size * seed_chip.scale / 2.0 - scr._fx.global_position
		var g := vv.part(p + Vector2(randf_range(-20, 20), randf_range(-20, 20)), Vector2(randf_range(-60, 60), randf_range(-60, 60)), Color(0.8, 1.0, 0.7, 0.8), 0.5, 10.0, Vfx.STAR)
		g.spin = 4.0)
	await fly.finished
	# the white flash
	Audio.play("boss_phase_change")
	var at := Vector2(960, 470)
	v.flash(Color(1, 1, 1, 1.0), 1.4)
	v.glow(at, 500, Color(0.85, 1.0, 0.8, 0.9), 0.9)
	v.ring(at, 30, 700, Color(0.8, 1.0, 0.7), 0.9, 18.0)
	v.burst(at, 60, Color(0.85, 1.0, 0.75), Vector2(300, 1100), Vector2(0.5, 1.0), Vector2(6, 12), Vfx.STAR)
	v.shake(10.0)
	seed_chip.queue_free()
	await _wait(0.5)
	_banner("The Seed of Life gives you a second chance", Color(0.75, 1.0, 0.6), 2.0)
	await _wait(2.2)


# ------------------------------------------------------------------ your statuses and bottles


## A Power is cast: its card flies to the middle of the screen and dissolves in its own way (burning up, melting,
## blowing away...) into particles that stream down to your statuses, where it becomes a badge for the fight.
func _power_fly(sp: Dictionary) -> void:
	var th := FightScreen.power_theme(sp)
	Audio.play("spell_glow")
	var card := _card_for(sp.id)
	var view_size := scr.get_viewport_rect().size
	var card_size := Vector2(SpellCard.W, SpellCard.H)
	var start: Vector2 = card.global_position if card else Vector2(view_size.x / 2.0, 700) - card_size / 2.0
	if card:
		card.modulate.a = 0.0  # (its copy flies; the card leaves the row once the Power is used)
	# a picture of the card (so the dissolve shader can eat it)
	var pad := Vector2(12, 12)
	var vp := SubViewport.new()
	vp.size = Vector2i(card_size + pad * 2.0)
	vp.transparent_bg = true
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	scr.add_child(vp)
	var copy := SpellCard.make(sp)
	copy.is_zoom_copy = true
	copy.position = pad
	vp.add_child(copy)
	var pic := TextureRect.new()
	pic.texture = vp.get_texture()
	pic.size = card_size + pad * 2.0
	pic.pivot_offset = pic.size / 2.0
	pic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pic.z_index = 60
	var mat := ShaderMaterial.new()
	mat.shader = load("res://assets/Global/Card/Shaders/power_dissolve.gdshader")
	mat.set_shader_parameter("from", th.from)
	mat.set_shader_parameter("edge_color", th.col)
	pic.material = mat
	scr._fx.add_child(pic)
	pic.global_position = start - pad
	# 1. it flies to the middle of the screen and swells, glowing
	var mid := Vector2(view_size.x / 2.0, 360.0)
	var tw := pic.create_tween().set_parallel()
	tw.tween_property(pic, "global_position", mid - pic.size / 2.0, 0.4).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(pic, "scale", Vector2(1.3, 1.3), 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	await tw.finished
	var fx := Vfx.make(scr._fx, 70)
	fx.glow(mid, 260, Color(th.col, 0.6), 0.5)
	fx.ring(mid, 40, 220, th.col, 0.45, 6.0)
	await _wait(0.25)
	# 2. it dissolves its own way, and what it dissolves into streams down to your statuses
	var target := scr._status_row.global_position + Vector2(scr._status_row.size.x + 40.0, 16.0)
	var half := card_size * 1.3 / 2.0
	var from: Vector2 = th.from
	var across := Vector2(-from.y, from.x)
	var dur := 0.95
	var t0 := Time.get_ticks_msec() / 1000.0
	Audio.play("discovery_unlock", -4.0)
	while true:
		var t := clampf((Time.get_ticks_msec() / 1000.0 - t0) / dur, 0.0, 1.0)
		mat.set_shader_parameter("progress", t * 1.12)
		# the front: from the side that goes first, sweeping across the card
		var reach := absf(from.x) * half.x + absf(from.y) * half.y
		var front := mid + from * reach - from * (2.0 * reach) * t
		for k in 3:
			var at := front + across * randf_range(-1.0, 1.0) * (absf(across.x) * half.x + absf(across.y) * half.y)
			fx.part(at, -from * randf_range(40, 120) + Vector2(randf_range(-30, 30), randf_range(-30, 30)), th.col.lightened(randf() * 0.4), randf_range(0.35, 0.7), randf_range(4, 9), th.shape)
			if randf() < 0.45:
				fx.move(at, target + Vector2(randf_range(-20, 20), randf_range(-8, 8)), randf_range(0.45, 0.75), th.rise * randf_range(0.6, 1.2), th.col, randf_range(4, 7), 0.0)
		if t >= 1.0:
			break
		await scr.get_tree().process_frame
	pic.queue_free()
	vp.queue_free()
	await _wait(0.55)
	# 3. it arrives: a little burst where it becomes a status
	fx = Vfx.make(scr._fx, 70)
	fx.ring(target, 6, 60, th.col, 0.35, 5.0)
	fx.burst(target, 14, th.col.lightened(0.3), Vector2(80, 220), Vector2(0.2, 0.4), Vector2(3, 6), th.shape)
	Audio.play("artifact_get", -6.0)


## The Release button shines in a slow pulse (brighter and, but for Puppet HUD ver 2, a touch bigger) while it's the thing to press.
func _pulse_release() -> void:
	if scr._cast_btn == null:
		return
	if scr._release_glow and not scr.busy and not scr._cast_btn.disabled:
		var s := 0.5 + 0.5 * sin(Time.get_ticks_msec() / 1000.0 * TAU / 1.1)
		scr._cast_btn.modulate = Color(1.0 + 0.45 * s, 1.0 + 0.38 * s, 1.0 + 0.15 * s)
		if scr._minh_disc != null:  # (MinhHUD: the picture is the round button's, not the Button's)
			scr._minh_disc.glow = s
			scr._minh_disc.queue_redraw()
		# (the Release button only blinks brighter: it NEVER grows, in any theme)
	elif scr._cast_btn.scale != Vector2.ONE or scr._cast_btn.modulate != Color.WHITE or (scr._minh_disc != null and scr._minh_disc.glow != 0.0):
		if scr._minh_disc != null:
			scr._minh_disc.glow = 0.0
			scr._minh_disc.queue_redraw()
		scr._cast_btn.modulate = Color.WHITE
		scr._cast_btn.scale = Vector2.ONE


func _draw_arrow() -> void:
	if not scr.aiming:
		return
	var a := scr.aim_from
	var b := scr.get_global_mouse_position()
	var hover := false
	for e in scr._views:
		var v: EnemyView = scr._views[e]
		if scr.fight.enemies.find(e) in scr.aim_cands and Rect2(v.global_position, v.size).has_point(b):
			hover = true
	var col := Color(1, 0.85, 0.35) if not hover else Color(1, 0.45, 0.35)
	# soft upward curve, like a thrown spell
	var ctrl := (a + b) / 2.0 + Vector2(0, -maxf(80.0, a.distance_to(b) * 0.35))
	var pts := []
	var n := 40
	for i in n + 1:
		var t := i / float(n)
		pts.append(a.lerp(ctrl, t).lerp(ctrl.lerp(b, t), t))
	# dots every ~24px along the curve
	var acc := 0.0
	for i in range(1, pts.size() - 2):
		acc += pts[i].distance_to(pts[i - 1])
		if acc >= 24.0:
			acc = 0.0
			var r := 4.0 + 3.0 * (i / float(n))
			scr._arrow.draw_circle(pts[i], r + 2.0, Color(0, 0, 0, 0.5))
			scr._arrow.draw_circle(pts[i], r, col)
	var dir: Vector2 = (pts[n] - pts[n - 3]).normalized()
	var side := Vector2(-dir.y, dir.x)
	var head := PackedVector2Array([b + dir * 6.0, b - dir * 26.0 + side * 16.0, b - dir * 18.0, b - dir * 26.0 - side * 16.0])
	var outline := PackedVector2Array([b + dir * 10.0, b - dir * 30.0 + side * 20.0, b - dir * 20.0, b - dir * 30.0 - side * 20.0])
	scr._arrow.draw_colored_polygon(outline, Color(0, 0, 0, 0.55))
	scr._arrow.draw_colored_polygon(head, col)


# ------------------------------------------------------------------ fight callbacks


var _cards_tween: Tween


## Steal: the spell row shrinks towards the chant (its bottom middle) and the cards stop magnifying under the mouse, so the enemies' Essence stay in view.
func _shrink_cards(on: bool) -> void:
	SpellCard.hover_off = on
	if on:
		for c in scr._cards:
			if is_instance_valid(c):
				c.drop_zoom()
	if scr._spell_row == null:
		return
	if _cards_tween != null and _cards_tween.is_valid():
		_cards_tween.kill()
	scr._spell_row.pivot_offset = Vector2(scr._spell_row.size.x / 2.0, scr._spell_row.size.y)
	_cards_tween = scr.create_tween()
	_cards_tween.tween_property(scr._spell_row, "scale", Vector2.ONE * (0.5 if on else 1.0), 0.18).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


## Remove spells: BANG. A gunshot, a muzzle flash where you aimed, the crosshair kicks, and the Essence takes a bullet
## hole before it's knocked off.
func _fire_shot(v: EnemyView, index: int) -> void:
	var at := v.hp_point(index)
	Audio.play_gunshot()
	if is_instance_valid(scr._aim_cursor):
		scr._aim_cursor.kick()
	var col: Color = Elements.COLORS.get(v.enemy.elements[index], Color.WHITE)
	var fx := Vfx.make(scr._fx, 80)
	fx.shaker = _shake
	fx.stopper = _hitstop
	# the tracer: a white-hot streak from below the screen straight into the Essence, gone in a blink
	var from := at + Vector2(randf_range(-120, 120), 900)
	var tracer := fx.beam(from, at, Color(1, 0.92, 0.7, 0.95), 0.09, 5.0)
	tracer.w0 = 2.0
	fx.beam(from, at, Color(col, 0.5), 0.14, 14.0)
	# the hit: muzzle-bright flash, a cross-shaped glint, a crack of shockwave
	fx.glow(at, 150, Color(1, 0.97, 0.85, 1.0), 0.1)
	fx.glow(at, 230, Color(col, 0.75), 0.4)
	fx.flare(at, 300, Color(1, 0.88, 0.5, 0.95), 0.16)
	fx.ring(at, 6, 95, Color(1, 0.95, 0.75), 0.22, 6.0)
	fx.ring(at, 10, 150, col, 0.38, 8.0, 0.03)
	fx.burst(at, 24, Color(1, 0.85, 0.4), Vector2(350, 900), Vector2(0.1, 0.25), Vector2(3, 6))
	var hole := fx.part(at, Vector2.ZERO, Color(0.05, 0.03, 0.03, 0.95), 0.7, 11.0, Vfx.SMOKE)
	hole.size1 = 11.0
	hole.hold = 0.6
	# the Essence breaks apart in its own colour, blown out the far side
	for s in fx.burst(at, 18, col, Vector2(200, 560), Vector2(0.5, 0.85), Vector2(6, 12), Vfx.SHARD, 0.0, PI * 0.9, -PI / 2.0):
		s.grav = Vector2(0, 1100)
		s.spin = randf_range(-14, 14)
		s.size1 = s.size0
	for i in 5:
		var sm := fx.part(at + Vector2(randf_range(-8, 8), 0), Vector2(randf_range(-40, 40), -randf_range(40, 110)), Color(0.12, 0.1, 0.1, 0.45), randf_range(0.6, 0.9), 8.0, Vfx.SMOKE)
		sm.size1 = 30.0
		sm.drag = 1.5
	fx.hitstop(0.07)
	fx.shake(9.0)
	_shot_fired = true


func _emit_chant_done(i: int) -> void:
	if scr._allowed("place", i):
		scr._chant_done.emit(i)


## The infused element pops out of its spell's card and waits there, glowing and wiggling, to be grabbed.
func _spawn_infuse_orb(spell: Dictionary, el: String) -> void:
	var card := _card_for(spell.id)
	var at := (card.global_position + Vector2(card.size.x * card.scale.x / 2.0, -42)) if card else Vector2(960, 480)  # just above the card
	# first the spell's own elements twist together on the card and fuse into the new one
	var born := at
	if card:
		born = await _fuse_on_card(card, el)
		if scr.chant_mode != "insert" or not scr.is_inside_tree():
			return  # it was placed some other way (keyboard) while the elements were fusing
	var px := 64.0
	var orb := ElementIcon.make(el, px)
	orb.size = Vector2(px, px)
	orb.pivot_offset = orb.size / 2.0
	orb.position = born - orb.size / 2.0
	orb.create_tween().tween_property(orb, "position", at - orb.size / 2.0, 0.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT).set_delay(0.12)
	orb.z_index = 60
	orb.highlight = true
	orb.mouse_filter = Control.MOUSE_FILTER_STOP
	orb.mouse_default_cursor_shape = Control.CURSOR_DRAG
	orb.tooltip_text = "Drag me into your chant"
	orb.gui_input.connect(func(ev): if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT: scr._h_input._infuse_grab(ev.global_position))
	scr.add_child(orb)
	scr._infuse_orb = orb
	scr._infuse_el = el
	orb.scale = Vector2(0.2, 0.2)
	var pop := orb.create_tween()
	pop.tween_property(orb, "scale", Vector2(1.15, 1.15), 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	pop.tween_property(orb, "scale", Vector2.ONE, 0.1)
	var wig := orb.create_tween().set_loops()
	wig.tween_property(orb, "rotation", 0.14, 0.18).set_trans(Tween.TRANS_SINE)
	wig.tween_property(orb, "rotation", -0.14, 0.18).set_trans(Tween.TRANS_SINE)
	var glow := orb.create_tween().set_loops()
	glow.tween_property(orb, "modulate", Color(1.5, 1.45, 1.2), 0.5).set_trans(Tween.TRANS_SINE)
	glow.tween_property(orb, "modulate", Color.WHITE, 0.5).set_trans(Tween.TRANS_SINE)
	Audio.play("spell_glow")


## The card's pattern elements lift off its face, spiral around each other while drawing together, spinning
## and brightening, then fuse in a flash where the new element is born. Returns that point (on the card).
func _fuse_on_card(card: SpellCard, el: String) -> Vector2:
	var icons := []
	var starts := []
	for o in card.live_orbs():
		if not (o is ElementIcon):
			continue
		var r: Rect2 = o.get_global_rect()
		var ic := ElementIcon.make(o.el, r.size.x)
		ic.size = r.size
		ic.pivot_offset = r.size / 2.0
		ic.position = r.position
		ic.z_index = 61
		ic.highlight = true
		ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
		scr.add_child(ic)
		icons.append(ic)
		starts.append(r.get_center())
	var center: Vector2 = card._pat.get_global_rect().get_center()
	if icons.is_empty():
		return center
	Audio.play("spell_glow")
	var dur := 1.1
	var twist := func(t: float) -> void:
		var e := t * t * (3.0 - 2.0 * t)
		for k in icons.size():
			var ic: ElementIcon = icons[k]
			if not is_instance_valid(ic):
				continue
			# spiral in: each keeps turning around the centre while its distance shrinks to nothing
			var off: Vector2 = starts[k] - center
			var lift := Vector2(0, -18.0 * sin(e * PI))
			ic.position = center + off.rotated(e * TAU * 1.4) * (1.0 - e) + lift - ic.size / 2.0
			ic.rotation = e * TAU * 1.5
			ic.scale = Vector2.ONE * (1.0 + 0.25 * sin(e * PI) - 0.3 * e)
			ic.modulate = Color.WHITE.lerp(Color(2.4, 2.3, 2.0), e)
	scr.create_tween().tween_method(twist, 0.0, 1.0, dur)
	await _wait(dur)
	for ic in icons:
		if is_instance_valid(ic):
			ic.queue_free()
	# the flash of the fusion
	ShardBurst.burst(scr._fx, center, Elements.COLORS.get(el, Color.WHITE), 34.0)
	Audio.play("elem_pickup")
	_shake(4.0)
	return center


func _anim(ev: Dictionary) -> void:
	await _anim_event(ev)
	_cull_dead()
	if scr._orphans_running:
		scr._orphans_running = false
		await _wait(FightScreen.OrphanFx.WAIT)  # (the fight ends once the children have run off)


## The Necromancer acts: he leans further out from behind his Shield Bearer, then back.
func _necro_peek(e: EnemyState) -> void:
	var v: EnemyView = scr._views.get(e)
	if v == null or not e.has_passive("behind_shield") or not is_instance_valid(v.creature):
		return
	v.creature.pivot_offset = Vector2(v.creature.size.x / 2.0, v.creature.size.y)  # (he leans from his feet)
	var tw := v.creature.create_tween()
	tw.tween_property(v.creature, "rotation", EnemyView.PEEK_TILT_ACT, 0.45).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_interval(1.1)
	tw.tween_property(v.creature, "rotation", EnemyView.PEEK_TILT, 0.6).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


## Puppet Stage: the views of enemies that were defeated break into pieces and leave; the others stay as they are.
func _cull_dead() -> void:
	if scr._enemy_row == null:
		return
	for e in scr._views.keys():
		if e.is_dead() and not e.knocked and not scr._h_hud._hand_going_down(e) and not e.has_passive("armadillo") and not e.has_meta("yielded") and not (e.has_passive("veil_falls") and e.phase == 1) and not (e.has_passive("invoker_rebirth") and e.phase == 1) and not (e.has_passive("yy_rebirth") and e.phase == 1):  # (the Veiled Eyes at 0 Essence do not break: the veil falls and the same puppet unfolds; the Invoker rises again: his own burst-and-reform plays)
			var old: EnemyView = scr._views[e]
			scr._views.erase(e)
			if is_instance_valid(old):
				if is_instance_valid(old.creature):
					if e.has_passive("thrown_junk"):
						FightScreen.OrphanFx.run_away(scr, old.creature.get_global_rect(), Creature._puppet_tex("orphan_bush", 2))
						scr._orphans_running = true
					elif old.creature.has_rig():
						_shatter_arm(old.creature)
					else:
						PuppetShatter.spawn(scr, old.creature)
				var par := old.get_parent()
				var at := old.get_index()
				var w := maxf(old.custom_minimum_size.x, old.size.x)
				scr._slot_w[e] = w
				par.remove_child(old)
				old.queue_free()
				if par == scr._enemy_row:
					var gap_slot := Control.new()  # (its place stays empty: nobody moves over)
					gap_slot.custom_minimum_size = Vector2(w, 1.0)
					gap_slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
					gap_slot.set_meta("slot", true)
					scr._enemy_row.add_child(gap_slot)
					scr._enemy_row.move_child(gap_slot, at)


func _anim_event(ev: Dictionary) -> void:
	match ev.type:
		"conjure_split":
			# the conjuring spell glitches into static, then splits into its conjured spells, which slide into place
			var src := _card_for(ev.source)
			var from := src.global_position if src else Vector2(960, 560)
			Audio.play("spell_glow")
			if src:
				await src.static_up(0.3)
			scr._h_hud._build_spells()
			await scr.get_tree().process_frame
			for id in ev.ids:
				var c := _card_for(id)
				if c:
					c.static_in(from)
			Audio.play("elem_pickup")
			await _wait(0.5)
			scr._h_hud._refresh_all()
		"conjure_merge":
			# the conjured spells still in the row (or the last one, just cast) glitch into static, slide together, and
			# settle back into the spell that conjured them
			var cards := []
			for id in ev.ids:
				var c := _card_for(id)
				if c:
					cards.append(c)
			var meet := Vector2(960, 560)
			if not cards.is_empty():
				meet = Vector2.ZERO
				for c in cards:
					meet += c.global_position
				meet /= cards.size()
				for c in cards:
					c.static_out_to(meet)
				Audio.play("elem_remove", -2.0)
				await _wait(0.4)
			scr._h_hud._build_spells()
			await scr.get_tree().process_frame
			var back := _card_for(ev.source)
			if back:
				Audio.play("spell_glow")
				await back.static_in(meet)
			scr._h_hud._refresh_all()
		"ephemeral_gone":
			# like an old TV switching off: static, a bright line, a dot, gone
			var any := false
			for id in ev.ids:
				var card := _card_for(id)
				if card:
					card.fizzle_out()
					any = true
			if any:
				Audio.play("elem_remove", -2.0)
				await _wait(0.75)
			scr._h_hud._build_spells()
			scr._h_hud._refresh_all()
		"bottle":
			# the cork pops: a burst of light from the bottle
			Audio.play("elem_pickup")
			var v := Vfx.make(scr._fx)
			v.shaker = _shake
			v.glow(scr._bottle_from, 120, Color(0.6, 0.95, 1.0, 0.9), 0.35)
			v.ring(scr._bottle_from, 10, 90, Color(0.6, 0.95, 1.0), 0.4, 6.0)
			v.burst(scr._bottle_from, 18, Color(0.75, 1.0, 1.0), Vector2(120, 380), Vector2(0.3, 0.6), Vector2(4, 8), Vfx.STAR)
			scr._h_hud._refresh_all()
			await _wait(0.3)
		"refund":
			await scr._h_machine._refund_flight(ev)
		"next_rolled":
			pass  # (what the artifacts gave flies to the tray once the balls of this turn are in: see _process)
		"artifact_used":
			scr._arts.flash(ev.id)
			Audio.play("spell_glow")
		"mirror_shine":
			# the Mirror Fairy turns your spell away: her mirror flares white for a moment
			var mv: EnemyView = scr._views.get(ev.enemy)
			Audio.play("spell_glow")
			if mv != null and is_instance_valid(mv.creature):
				var cr := mv.creature
				var fx := Vfx.make(scr._fx, 70)
				fx.burst(cr.global_position + cr.size / 2.0, 24, Color(0.9, 0.97, 1.0), Vector2(120, 380), Vector2(0.25, 0.5), Vector2(4, 9), Vfx.SPARK)
				var tw := cr.create_tween()
				tw.tween_property(cr, "modulate", Color(2.6, 2.6, 2.8), 0.08)
				tw.tween_property(cr, "modulate", Color.WHITE, 0.45)
				await tw.finished
		"chant":
			scr._prompt.text = "Chanting " + " ".join(Array(ev.chant.split("")).map(func(c): return Elements.NAMES[c]))
			await _wait(0.25)
		"paint":
			# Expose: a blotch of rainbow paint slaps onto the Essence, then fades away to reveal the Any Essence
			var pv: EnemyView = scr._views.get(ev.enemy)
			if pv:
				# the row just left pick mode: let it settle at its normal size before aiming at the orb
				await scr.get_tree().process_frame
				await scr.get_tree().process_frame
				var splash := PaintSplash.new()
				var ic: Control = pv._hp_icons[ev.index] if ev.index < pv._hp_icons.size() else null
				splash.el = String(ev.get("to", "?"))
				splash.radius = (ic.size.x if ic else 40.0) * 0.31  # (half the size it was)
				var at: Vector2 = ic.get_global_rect().get_center() if is_instance_valid(ic) and ic.is_inside_tree() else pv.hp_point(ev.index)  # (right on the Essence just painted)
				splash.position = at - scr._fx.global_position
				scr._fx.add_child(splash)
				scr._play_fx("repaint", "sfx_expose_apply")  # (the Repaint group: every brush stroke makes it)
				splash.play(scr._h_hud._refresh_all)  # the icon underneath turns Any while the paint covers it
				await _wait(0.25)
			else:
				scr._h_hud._refresh_all()
		"strike":
			scr._step_pos = -1
			var v: EnemyView = scr._views.get(ev.enemy)
			if v:
				v.hit_flash()  # it jolts, blinks and winces; the burst orbs show how much it lost
			Audio.play("sfx_damage_hit")
			scr._h_hud._refresh_all()
			await _wait(0.35)
		"chant_step":
			await _release_step(ev)
		"chant_changed":
			scr._play_fx(String(ev.get("fx", "")), "elem_pickup")  # (a repainted chant Essence: the Repaint group, not the pick-up click)
			scr._h_hud._refresh_all()
			await _wait(0.35)
		"trinity":
			# the three Fragments rise into a triangle and whirl into Trinity
			var froms := []
			for s in ev.parts:
				var c := _card_for(s.id)
				froms.append(c.global_position if c else Vector2(960, 760))
				if c:
					c.modulate.a = 0.0
			await TrinityScene.play(scr, ev.parts, froms, ev.result)
			scr._h_hud._build_spells()
			scr._h_hud._refresh_all()
		"loadout_changed":
			Audio.play("discovery_unlock")
			scr._h_hud._build_spells()
			scr._h_hud._refresh_all()
			await _wait(0.4)
		"charged":
			# every woken spell's chant elements light up and fly into its card, all at once
			scr._h_hud._refresh_chant()  # the spoken chant must be on the table before its elements can fly
			await scr.get_tree().process_frame
			var hits: Array = ev.get("hits", [])
			# read the whole chant, left to right, note by note
			var all := []
			for i in scr.fight.chant.size():
				all.append(i)
			await _sing(all, hits)
			for h in hits:
				var card := _card_for(h.id)
				if card:
					card.charges = 0
					card.fires = 0
					card.refresh()
			await _wake_fx(hits, false)
			scr._h_hud._refresh_all()
			await _wait(0.3)
		"extension":
			# the chant changed and woke more spells: the same flight (all at once), then an "Extension!" slam each.
			# Show the spell just cast as spent, but hold back the new charges until their elements land.
			scr._h_hud._refresh_all()
			for h in ev.hits:
				var card := _card_for(h.id)
				if card:
					card.charges = scr.fight.charges.get(h.id, 0) - h.starts.size()
					card.refresh()
			# sing again, but only the elements that woke these spells
			var used := {}
			for h in ev.hits:
				for st in h.starts:
					for k in h.len:
						used[st + k] = true
			var idx := used.keys()
			idx.sort()
			await _sing(idx, ev.hits)
			await _wake_fx(ev.hits, true)
			scr._h_hud._refresh_all()
		"spell":
			if ev.spell.id == "attunement":
				# no dissolve: its Essence fly out of the card for you to pick one (_attune_chooser)
				var c := _card_for(ev.spell.id)
				if c:
					c.create_tween().tween_property(c, "modulate:a", 0.0, 0.25)
				Audio.play("spell_glow")
				return
			if ev.spell.get("power", false):
				await _power_fly(ev.spell)
				return
			Audio.play("spell_glow")
			# the card lifts and glows (its text is right there on the card)
			var card := _card_for(ev.spell.id)
			if card:
				var tw := card.create_tween()
				tw.tween_property(card, "modulate", Color(1.5, 1.4, 1.1), 0.12)
				tw.tween_property(card, "modulate", Color.WHITE, 0.4)
			await _wait(0.4)
		"spell_effect":
			await _spell_fly(ev)
		"power_proc":
			# a Power does something: its badge pops and shines, with a chime
			var pb := _power_badge(String(ev.id))
			if pb:
				pb.pivot_offset = pb.size / 2.0
				var tw := pb.create_tween()
				tw.tween_property(pb, "modulate", Color(2.0, 1.8, 1.3), 0.08)
				tw.parallel().tween_property(pb, "scale", Vector2(1.25, 1.25), 0.08)
				tw.tween_property(pb, "modulate", Color.WHITE, 0.35)
				tw.parallel().tween_property(pb, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK)
				var fx := Vfx.make(scr._fx, 75)
				var at := pb.global_position + pb.size / 2.0 - scr._fx.global_position + scr._fx.global_position
				fx.glow(at, 90, Color(1.0, 0.9, 0.5, 0.8), 0.35)
				fx.ring(at, 8, 60, Color(1.0, 0.9, 0.55), 0.3, 4.0)
			Audio.play("spell_glow")
			await _wait(0.3)
		"echo_voice":
			# Echoed Voice: its badge flashes, and a beat later the effect fires again from it
			var badge := _power_badge("echo_chamber")
			if badge:
				var tw := badge.create_tween()
				tw.tween_property(badge, "modulate", Color(1.8, 1.6, 2.0), 0.08)
				tw.tween_property(badge, "modulate", Color.WHITE, 0.3)
			await _wait(0.25)
		"echo_chamber":
			# the Echo Chamber shines, and a beat later the same effect fires again from it
			scr._arts.flash("echo_chamber")
			await _wait(0.25)
		"effect":
			var snd: String = FightScreen.EFFECT_SFX.get(ev.op, "")
			if snd == "sfx_magic_hit" and not UiSkin.is_puppet():
				snd = "sfx_damage_hit"  # (the magic hit sound is Puppet art)
			var fx_group: String = FightScreen.EFFECT_FX.get(ev.op, "")
			if ev.op == "barrage" and ev.targets.size() > 1:  # a volley (Elemental Fury: 6 shots): every shot has its own sound, one after the other
				scr._volley(ev.targets, fx_group if Audio.has_sfx("spellfx_" + fx_group) else "", snd)
				snd = ""
				fx_group = ""
			if fx_group == "repaint":
				snd = ""
				fx_group = ""  # (every stroke of the brush made the Repaint sound already: it does not play once more at the end)
			if fx_group == "shield" and ev.get("eff", {}).get("lasting", false):
				fx_group = "lasting_shield"
			if fx_group != "" and Audio.has_sfx("spellfx_" + fx_group):
				Audio.play("spellfx_" + fx_group)
			elif snd != "":
				Audio.play(snd)
			_effect_landed(ev)
			scr._h_hud._sync_views()
			scr._h_hud._refresh_all()
			await _wait(maxf(0.3, 0.11 * ev.targets.size()) if ev.op == "barrage" else 0.3)  # (a volley lasts as long as its shots)
		"enemy_turn":
			_necro_peek(ev.enemy)
			await _enemy_turn_start(ev)
		"enemy_done":
			for v in scr._views.values():
				v.modulate = Color.WHITE
			await _file_turn_box()
		"attack":
			await _enemy_attack(ev)
		"sfx":  # (a sound that goes with something the rules did and that has no picture of its own: the Sentinel waking, the lamp glowing...)
			Audio.play(String(ev.name))
			scr._h_hud._refresh_all()
			await _wait(0.25)
		"enemy_move":
			await _enemy_move_fx(ev)
		"dot":
			var v: EnemyView = scr._views.get(ev.enemy)
			if v:
				v.hit_flash()
			if ev.get("burn", false):
				Audio.play("sfx_burn_tick")
			scr._h_hud._refresh_all()
			await _wait(0.5)
		"annihilate":
			await _annihilate_enemies(ev.el, ev.targets)
		"burn_off":
			# the Essence that caught fire last turn burns away
			var v: EnemyView = scr._views.get(ev.enemy)
			if v:
				v.hit_flash()
				_float_text("-%d  Burned" % ev.n, v.global_position + Vector2(90, 200), Color(1, 0.6, 0.25))
			Audio.play("sfx_burn_tick")
			scr._h_hud._sync_views()
			scr._h_hud._refresh_all()
			await _wait(0.5)
		"mend":
			Audio.play("sfx_mend")
			scr._h_hud._sync_views()
			scr._h_hud._refresh_all()
			if not ev.get("gains", []).is_empty():
				await _mend_light(ev.enemy, ev.gains)
			else:
				await _wait(0.2)
		"stolen":
			# the stolen orbs fly from the enemy into your elements
			var v: EnemyView = scr._views.get(ev.enemy)
			var from := (v.creature.global_position + v.creature.size / 2.0) if v else Vector2(960, 300)
			var to := scr._stock_row.global_position + Vector2(scr._stock_row.size.x * 0.4, 30)
			for el in ev.els:
				Comet.launch(scr._fx, from, to, Elements.COLORS[el])
			if not ev.els.is_empty():
				_float_text("Stolen: " + " ".join(ev.els), from + Vector2(-60, -40), Color(0.5, 0.9, 1))
			await _wait(0.5)
			scr._h_hud._refresh_all()
		"unlock":
			Audio.play("sfx_lock_break")
			scr._h_hud._refresh_all()
			await _wait(0.2)
		"thorns_proc":
			Audio.play("sfx_thorns_proc")
		"amplify":
			Audio.play("sfx_amplify")
			scr._h_hud._sync_views()
			scr._h_hud._refresh_all()
			await _wait(0.2)
		"laser":
			await _eye_laser(ev.enemy)
		"veil_falls":
			Audio.play("boss_phase_change")
			scr._h_hud._sync_views()
			scr._h_hud._refresh_all()
			_callout_beside(scr._views.get(ev.enemy), "[i]The veil falls away. Something underneath unfolds its legs.[/i]", Color(0.75, 0.5, 1.0), 2.4)
			await _wait(1.4)
			var vv: EnemyView = scr._views.get(ev.enemy)
			while vv != null and is_instance_valid(vv.creature) and vv.creature.unveiling():  # (the Veiled Eyes' unveiling plays out before anything else)
				await scr.get_tree().process_frame
		"spider_steal":
			await _spider_steal(ev.enemy, ev.spell)
		"boss_phase":
			Audio.play("boss_phase_change")
		"boss_defeat":
			Audio.play("boss_defeat")
		"hm_rally":
			await _hm_rally_scene()
		"spawn":
			Audio.play("enemy_spawn")
			scr._h_hud._sync_views()
			var cocoon_view: EnemyView = scr._views.get(ev.enemy) if ev.enemy.id == "spider_cocoon" else null
			if cocoon_view != null:
				cocoon_view.modulate.a = 0.0  # (no first frame in its place: it is let down from above)
			scr._h_hud._refresh_all()
			if cocoon_view != null:
				var dropped := [false]
				(func():
					await _drop_view_in(cocoon_view)
					dropped[0] = true).call()
				if scr._spider_away != null:  # the spider follows the cocoon down a second after it
					await _wait(1.0)
					await _spider_return(scr._spider_away)
				while not dropped[0]:
					await scr.get_tree().process_frame
			await _wait(0.25)
		"spider_return":
			await _spider_return(ev.enemy)
		"meteor":
			# Chaos Meteor: a fireball falls from the sky onto this enemy
			var mv: EnemyView = scr._views.get(ev.enemy)
			if mv != null:
				var to := mv.anchor_point() + Vector2(randf_range(-30, 30), -40)
				var from := to + Vector2(randf_range(-420, -260), -900)
				var fx := Vfx.make(scr._fx, 80)
				fx.move(from, to, 0.42, 0.0, Color(1.0, 0.55, 0.15), 16.0, 0.0,
					func(vx: Vfx, it, _dt):
						vx.part(it.pos, Vector2(randf_range(-30, 30), randf_range(-60, -10)), Color(1.0, randf_range(0.3, 0.7), 0.1), randf_range(0.25, 0.45), randf_range(8, 14)),
					func(vx: Vfx, at: Vector2):
						vx.glow(at, 160, Color(1.0, 0.6, 0.2), 0.3)
						vx.ring(at, 8, 110, Color(1.0, 0.5, 0.15), 0.3, 6.0)
						vx.burst(at, 18, Color(1.0, 0.65, 0.2), Vector2(150, 420), Vector2(0.3, 0.55), Vector2(4, 8))
						vx.shake(6.0))
				Audio.play("sfx_burn_apply")
				await _wait(0.45)
		"meteor_hit":
			scr._h_hud._refresh_all()
		"revive":
			# a fallen hand gets back up: a golden flash as it rises
			var rv: EnemyView = scr._views.get(ev.enemy)
			scr._h_hud._sync_views()
			scr._h_hud._refresh_all()
			if rv != null:
				rv.modulate = Color(2.0, 1.8, 1.0)
				rv.create_tween().tween_property(rv, "modulate", Color.WHITE, 0.6)
			Audio.play("enemy_spawn")
		"intents_shown":
			scr._turn_batch_until = Time.get_ticks_msec() + 4000  # (Cirus: the Essence of the new turn come out of the tube)
			Audio.play("enemy_intent_show")
			scr._h_hud._sync_views()
			scr._h_hud._refresh_all()
			await _wait(0.1)
		"confuse":
			Audio.play("sfx_confuse_apply")
			scr._h_hud._refresh_all()
			await _wait(0.15)
		"blind":
			Audio.play("sfx_blind_apply")
			scr._h_hud._refresh_all()
			await _wait(0.15)
		"frail":
			Audio.play("sfx_frail_apply")
			scr._h_hud._refresh_all()
			await _wait(0.15)
		"freeze_stock":
			await scr._h_machine._rolls_done()
			Audio.play("sfx_freeze_apply")
			scr._h_hud._refresh_all()
			await _wait(0.15)
		"silence":
			var head_v: EnemyView = scr._views.get(ev.get("enemy"))
			if ev.get("head", false) and head_v:
				Audio.play("sfx_head_scream")
				await scr.get_tree().create_timer(0.55).timeout  # (he screams first, then it flies)
				head_v.creature.head_gone = true  # (the picture with the empty hand and no pumpkin, from the moment it leaves him)
				await FightScreen.OrphanFx.throw_item(scr, head_v.creature.global_position + Vector2(head_v.creature.size.x * 0.5, 40.0), _attack_point(), "head")
			Audio.play("sfx_silence_apply")
			scr._h_hud._refresh_all()
			await _wait(0.15)
		"invert_spells":
			# some of your spells flip (spell <-> anti-spell): the row is rebuilt with their new look
			Audio.play("sfx_silence_apply")
			scr._h_hud._build_spells()
			scr._h_hud._refresh_all()
			await _wait(0.6)
		"charge_tick":
			scr._h_hud._refresh_all()
			await _wait(0.3)
		"hourglass_dust":
			await _hourglass_dust(ev.enemy)
		"hammer":
			await _hammer_fx(ev)
		"invoke":
			var iv: EnemyView = scr._views.get(ev.enemy)
			if iv:
				iv.flash_invoked(ev.idx)
			Audio.play("spell_glow")
			await _wait(0.45)
		"hm_new_hands":
			await scr._h_talk._hm_new_hands(ev.ids, ev.lines)
		"song_pause":
			if scr._song != null:
				scr._song.pause()
		"song_resume":
			if scr._song != null:
				scr._song.resume()
		"page_turn":
			await scr._h_talk._page_turn(ev.enemy)
		"speech":
			await scr._h_talk._speech(ev.enemy, ev.text, float(ev.get("hold", 1.5)))
		"invoker_summon":
			# a new set of spells: his line, and the cards buzz in out of him (see EnemyView._refresh_invoked)
			Audio.play("spell_glow")
			scr._h_hud._refresh_all()
			await scr._h_talk._speech(ev.enemy, ev.line, 1.5)
		"reform":
			# rising for his second phase: he bursts into pieces and they are pulled back into him along the same paths
			var rv: EnemyView = scr._views.get(ev.enemy)
			if ev.has("delay") and rv != null and is_instance_valid(rv.creature):
				rv.creature.visible = false  # (a Yin Yang Cub: hidden until the pieces have flown together into it)
				await _wait(float(ev.delay))
			if rv != null and is_instance_valid(rv.creature):
				var fx := PuppetShatter.spawn_reform(scr, rv.creature)
				if fx != null:
					rv.creature.visible = false
					scr._reforming[ev.enemy] = fx
					await fx.reformed
					scr._reforming.erase(ev.enemy)
					if is_instance_valid(rv) and is_instance_valid(rv.creature):
						rv.creature.visible = true
		"speech_lines":
			if is_instance_valid(scr._reforming.get(ev.enemy)):
				await scr._reforming[ev.enemy].reformed  # (he speaks once he is whole again)
			# a few sentences, one bubble each, held long enough to read (about 3 words a second, plus a moment)
			for line in ev.lines:
				await scr._h_talk._speech(ev.enemy, line, 1.0 + String(line).split(" ").size() / 3.0)
		"virus_hit":
			Audio.play("sfx_poison_apply")
			var vc := _card_for(ev.id)
			if vc:
				var vfx := Vfx.make(scr._fx, 70)
				vfx.burst(vc.global_position + vc.size * vc.scale / 2.0, 16, Color(0.55, 0.95, 0.3), Vector2(80, 240), Vector2(0.25, 0.5), Vector2(4, 8), Vfx.SPARK)
			scr._h_hud._refresh_all()
			await _wait(0.3)
		"ignite_spell":
			Audio.play("sfx_burn_apply")
			scr._h_hud._refresh_all()
			await _wait(0.15)
		"ignite_burn":
			# the burning card scorches you
			Audio.play("sfx_burn_apply")
			var card := _card_for(ev.id)
			if card:
				var fx := Vfx.make(scr._fx, 70)
				fx.burst(card.global_position + card.size * card.scale / 2.0, 16, Color(1.0, 0.55, 0.2), Vector2(80, 240), Vector2(0.25, 0.5), Vector2(4, 8), Vfx.SPARK)
			_shake(5.0)
			scr._h_hud._refresh_all()
			await _wait(0.25)
		"poison_tick":
			Audio.play("sfx_poison_tick")
			scr._h_hud._refresh_all()
			await _wait(0.15)
		"bleed_tick":
			Audio.play("sfx_bleed_tick")
			scr._h_hud._refresh_all()
			await _wait(0.15)
		_:
			scr._h_hud._sync_views()
			scr._h_hud._refresh_all()
			await _wait(0.25)


## The chant elements that woke these spells all light up at once (an Extension's also wiggle), lift off together
## and fly into their cards; every card flashes and comes alive as they land. An element that feeds two spells
## sends a comet to each. For an Extension, the slams follow: "Extension!", "Double Extension!", ...
## The chant is read out: left to right, each element hops, shines and sings its note, and the orb it fills
## on every spell it helps wake shines at the same moment.
func _sing(indices: Array, hits: Array) -> void:
	for i in indices:
		if not scr.is_inside_tree():
			return
		# looked up afresh for every note: the chant row or a card may have been rebuilt while we waited
		var slots := scr._chant_row.get_children().filter(func(c): return c is Panel and not c.is_queued_for_deletion())
		if i < slots.size():
			for ic in slots[i].get_children():
				if ic is ElementIcon:
					_hop(ic, 18.0)
					Audio.play_note(ic.el)
		for h in hits:
			var card := _card_for(h.id)
			if card == null or not is_instance_valid(card._pat):
				continue
			for st in h.starts:
				if i >= st and i < st + h.len:
					var orbs := card.live_orbs()
					if i - st < orbs.size():
						_hop(orbs[i - st], 10.0)
		await _wait(0.3)
	await _wait(0.2)


## One quick hop with a shine, then back to rest.
func _hop(ic: Control, height: float) -> void:
	if not is_instance_valid(ic):
		return
	ic.pivot_offset = ic.size / 2.0
	if ic is ElementIcon:
		ic.highlight = true
		ic.queue_redraw()
	var tw := ic.create_tween()
	tw.tween_property(ic, "position:y", ic.position.y - height, 0.11).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(ic, "modulate", Color(1.9, 1.85, 1.6), 0.11)
	tw.parallel().tween_property(ic, "scale", Vector2(1.22, 1.22), 0.11)
	tw.tween_property(ic, "position:y", ic.position.y, 0.22).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(ic, "modulate", Color.WHITE, 0.35)
	tw.parallel().tween_property(ic, "scale", Vector2.ONE, 0.22)
	tw.tween_callback(func():
		if is_instance_valid(ic) and ic is ElementIcon:
			ic.highlight = false
			ic.queue_redraw())


func _wake_fx(hits: Array, extension: bool) -> void:
	var slots := scr._chant_row.get_children().filter(func(c): return c is Panel)
	var flights := []  # [icon, card]
	var lit := {}
	for h in hits:
		var card := _card_for(h.id)
		if card == null:
			continue
		for st in h.starts:
			for k in h.len:
				var i: int = st + k
				if i >= slots.size():
					continue
				if not is_instance_valid(slots[i]):
					continue
				for ch in slots[i].get_children():
					if ch is ElementIcon:
						flights.append([ch, card])
						lit[ch] = true
	if flights.is_empty():
		for h in hits:
			var card := _card_for(h.id)
			if card:
				card.charges = scr.fight.charges.get(h.id, 0)
				card.refresh()
				var fl := card.create_tween()
				fl.tween_property(card, "modulate", Color(2.0, 1.6, 2.0), 0.08)
				fl.tween_property(card, "modulate", Color.WHITE, 0.3)
		if not hits.is_empty():
			Audio.play("spell_glow")
			await _wait(0.3)
		return
	for ic in lit:
		ic.highlight = true
		ic.queue_redraw()
		ic.pivot_offset = ic.size / 2.0
		var tw: Tween = ic.create_tween()
		if extension:
			for w in 3:
				tw.tween_property(ic, "rotation", 0.35, 0.05)
				tw.tween_property(ic, "rotation", -0.35, 0.05)
			tw.tween_property(ic, "rotation", 0.0, 0.05)
		tw.tween_property(ic, "scale", Vector2(1.3, 1.3), 0.14)
		tw.tween_property(ic, "scale", Vector2.ONE, 0.22)
	Audio.play("spell_glow")
	await _wait(0.5 if extension else 0.35)
	# everything lifts off at once
	var sounds := {}
	for fl in flights:
		if not is_instance_valid(fl[0]) or not is_instance_valid(fl[1]):
			continue  # the chant row or the card was rebuilt meanwhile
		var ic: ElementIcon = fl[0]
		var card: SpellCard = fl[1]
		var to := card.global_position + card.size * card.scale / 2.0
		var cm := Comet.launch(scr._fx, ic.global_position + ic.size / 2.0, to, Elements.COLORS.get(ic.el, Color(1, 0.9, 0.4)))
		cm.dur = 0.55
		cm.rise = 110.0
		if not sounds.has(ic.el):
			sounds[ic.el] = true
			Audio.play(FightScreen.LAUNCH_SFX.get(ic.el, "elem_pickup"), -4.0)
	await _wait(0.58)
	for ic in lit:
		if is_instance_valid(ic):
			ic.highlight = false
			ic.queue_redraw()
	for h in hits:
		var card := _card_for(h.id)
		if card == null:
			continue
		card.charges = scr.fight.charges.get(h.id, 0)
		card.refresh()
		var fl := card.create_tween()
		fl.tween_property(card, "modulate", Color(2.2, 2.0, 1.4), 0.07)
		fl.tween_property(card, "modulate", Color.WHITE, 0.3)
	Audio.play("spell_glow")
	if extension:
		for k in hits.size():
			await _extension_slam(k + 1)
			await _wait(0.15)
	else:
		await _wait(0.15)


## "Extension!" slams onto the table at a slant (low left, high right): it drops in huge, hits with a shake and a
## burst of sparks along its length, and fades. The 2nd one this turn says "Double Extension!", and so on.
func _extension_slam(count := 1) -> void:
	var text: String = FightScreen.EXTENSION_NAMES[count - 1] if count <= FightScreen.EXTENSION_NAMES.size() else "%d× Extension!" % count
	var words: Array = ["extension"] if count == 1 else [FightScreen.WORD_COUNTS[count - 2], "extension"] if count - 2 < FightScreen.WORD_COUNTS.size() else []  # (the carved wooden lettering, when the theme has it)
	await _slam(text, Color(1.0, 0.86, 0.25), Color(0.4, 0.08, 0.0), 128 if count == 1 else 104, words)


## The carved lettering of a slam: one picture per word, stacked, centred in a box the size of the text it replaces (null when a picture is missing).
func _art_words(words: Array) -> Control:
	var texs: Array = words.map(func(w): return UiSkin.tex("word_" + w))
	if texs.has(null):
		return null
	var box := Control.new()
	var row_h := 190.0 if texs.size() == 1 else 125.0
	var total := row_h * texs.size()
	for i in texs.size():
		var t: Texture2D = texs[i]
		var r := TextureRect.new()
		r.texture = t
		r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		r.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		r.size = Vector2(row_h * t.get_width() / t.get_height(), row_h)
		r.position = Vector2(750.0 - r.size.x / 2.0, 100.0 - total / 2.0 + i * row_h)
		r.mouse_filter = Control.MOUSE_FILTER_IGNORE
		box.add_child(r)
	return box


## Big slanted words slapped onto the table (Extension!, Perfect!): they drop in huge, hit with a shake and a
## burst of sparks along their length, bounce, and fade.
func _slam(text: String, col: Color, outline: Color, font_px: int, words := []) -> void:
	var art: Control = _art_words(words) if not words.is_empty() else null
	var l: Control = art if art != null else Label.new()
	if art == null:
		scr._h_hud._style_slam_label(l as Label, text, col, outline, font_px)
	await _slam_finish(l)


## The slam itself (shared by text and carved lettering): drops in huge, hits, bounces, fades.
func _slam_finish(l: Control) -> void:
	l.size = Vector2(1500, 200)
	l.position = Vector2(960 - 750, 330)
	l.pivot_offset = l.size / 2.0
	l.scale = Vector2(3.4, 3.4)
	l.rotation = deg_to_rad(FightScreen.SLAM_ANGLE - 12.0)
	l.modulate.a = 0.0
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.z_index = 60
	scr._fx.add_child(l)
	var tw := l.create_tween().set_parallel(true)
	tw.tween_property(l, "scale", Vector2.ONE, 0.16).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_property(l, "modulate:a", 1.0, 0.08)
	tw.tween_property(l, "rotation", deg_to_rad(FightScreen.SLAM_ANGLE), 0.16)
	await tw.finished
	# the hit
	_shake(16.0)
	Audio.play("boss_phase_change")
	var along := Vector2.from_angle(deg_to_rad(FightScreen.SLAM_ANGLE))
	for k in 4:
		ImpactFx.burst(scr._fx, l.position + l.size / 2.0 + along * randf_range(-420, 420), false)
	var bounce := l.create_tween()
	bounce.tween_property(l, "scale", Vector2(1.12, 0.9), 0.06)
	bounce.tween_property(l, "scale", Vector2(0.96, 1.05), 0.08)
	bounce.tween_property(l, "scale", Vector2.ONE, 0.1)
	await _wait(0.6)
	var out := l.create_tween().set_parallel(true)
	out.tween_property(l, "modulate:a", 0.0, 0.3)
	out.tween_property(l, "position:y", l.position.y - 60.0, 0.3)
	out.chain().tween_callback(l.queue_free)
	await _wait(0.15)


func _result_banner(kind: String) -> bool:
	var ribbon := UiSkin.tex(kind + "_banner")
	var lettering := UiSkin.tex(kind + "_text")
	if ribbon == null or lettering == null:
		return false
	var word := UiSkin.tex("perfect_word") if kind == "perfect" else null
	var stage := Control.new()
	stage.size = ribbon.get_size()
	stage.position = Vector2(960.0 - stage.size.x / 2.0, 600.0 - stage.size.y)  # the ribbon's lower edge rests at y=600
	stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stage.z_index = 60
	scr._fx.add_child(stage)
	var layers := {}
	for part in ["banner", "text", "word"]:  # PERFECT last, so it sits in front of the ribbon and VICTORY
		var tex: Texture2D = {"word": word, "banner": ribbon, "text": lettering}[part]
		if tex == null:
			continue
		var r := TextureRect.new()
		r.texture = tex
		r.size = stage.size
		r.pivot_offset = stage.size / 2.0
		r.mouse_filter = Control.MOUSE_FILTER_IGNORE
		r.modulate.a = 0.0
		if part == "word":
			r.position.y = -FightScreen.PERFECT_RAISE  # above VICTORY instead of tucked behind it
		stage.add_child(r)
		layers[part] = r
	var drop := stage.size.y + 520.0
	var down := func(r: TextureRect, from_scale: float, fall: float) -> void:
		r.position.y = -drop
		r.scale = Vector2.ONE * from_scale
		r.modulate.a = 0.0
		var tw := r.create_tween().set_parallel(true)
		tw.tween_property(r, "position:y", 0.0, fall).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tw.tween_property(r, "scale", Vector2.ONE, fall).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tw.tween_property(r, "modulate:a", 1.0, fall * 0.4)
		await tw.finished
	var thud := func(r: TextureRect, shake_px: float, vol: float) -> void:
		_shake(shake_px)
		Audio.play("boss_phase_change", vol)
		for k in 3:
			ImpactFx.burst(scr._fx, stage.global_position + stage.size * Vector2(randf_range(0.15, 0.85), randf_range(0.35, 0.85)), false)
		var sq := r.create_tween()
		sq.tween_property(r, "scale", Vector2(1.05, 0.93), 0.06)
		sq.tween_property(r, "scale", Vector2(0.99, 1.03), 0.08)
		sq.tween_property(r, "scale", Vector2.ONE, 0.1)
	await down.call(layers["banner"], 1.12, 0.3)
	thud.call(layers["banner"], 18.0 if kind != "defeat" else 10.0, 0.0)
	await _wait(0.34)
	await down.call(layers["text"], 1.5, 0.22)
	thud.call(layers["text"], 12.0 if kind != "defeat" else 7.0, -5.0)
	await _wait(0.3)
	if word != null:  # PERFECT blinks on, above VICTORY
		var w: TextureRect = layers["word"]
		var fl := w.create_tween()
		for a in [1.0, 0.15, 1.0, 0.25, 1.0, 0.4, 1.0]:
			fl.tween_property(w, "modulate:a", a, 0.09)
		await fl.finished
		var glow := w.create_tween().set_loops(3)
		glow.tween_property(w, "modulate", Color(1.5, 1.3, 1.3), 0.25)
		glow.tween_property(w, "modulate", Color.WHITE, 0.25)
		await _wait(1.0)
	else:
		await _wait(0.9)
	var out := stage.create_tween().set_parallel(true)
	out.tween_property(stage, "modulate:a", 0.0, 0.3)
	out.tween_property(stage, "position:y", stage.position.y - 40.0, 0.3)
	out.chain().tween_callback(stage.queue_free)
	await _wait(0.15)
	return true


# ------------------------------------------------------------------ Annihilate


## The screen dims; Fire, Water and Air float softly out of the card and shine. Pick one (click, or F / W / A):
## the other two drift back into the card and vanish, and the chosen one shakes violently, cracks and shatters.
## A charge goes off: its hourglass runs out and crumbles to dust (0.75 s), then the hit.
func _hourglass_dust(e: EnemyState) -> void:
	var v: EnemyView = scr._views.get(e)
	var chip: Control = v.intent_chip() if v else null
	if chip == null:
		return
	# a picture of the bubble (a copy, drawn on its own), which then turns to dust in its place (see DustCloud)
	var pad := Vector2(4, 4)
	var vp := SubViewport.new()
	vp.size = Vector2i(chip.size + pad * 2.0)
	vp.transparent_bg = true
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	scr.add_child(vp)
	var copy := IntentChip.make(e)
	copy.position = pad
	copy.size = chip.size
	vp.add_child(copy)
	await scr.get_tree().process_frame
	await scr.get_tree().process_frame
	var img := vp.get_texture().get_image()
	vp.queue_free()
	chip.modulate.a = 0.0
	DustCloud.crumble(scr._fx, img, chip.global_position - pad * chip.get_global_transform().get_scale(), chip.get_global_transform().get_scale().x, 0.75)
	Audio.play("sfx_dust")
	await _wait(0.75)


## The Hammer Hand strikes a spell: a thump, the card jolts and cracks. On the last hit it's broken: cracked all over, grey.
func _hammer_fx(ev: Dictionary) -> void:
	var card := _card_for(ev.id)
	var v: EnemyView = scr._views.get(ev.enemy)
	var cr: Creature = v.creature if v else null
	var reached := card != null and cr != null and cr.has_rig() and Creature.POKE_TIP.has(ev.enemy.id)
	if reached:  # (the Hammer Hand's arm reaches over the screen and brings the hammer down ON the card)
		cr.tip_z = PuppetStage.CEILING_Z + 3
		cr.poke_target = card.global_position + card.size * card.scale / 2.0
		var reach := scr.create_tween()
		reach.tween_property(cr, "poke", 1.0, 0.4).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		await reach.finished
		_hammer_retreat(cr)
	elif v and v.creature.has_rig():  # (no art to reach with: it swings in place)
		_arm_swing(v.creature, 1.0)
		await _wait(0.23)
	if card and v and not reached:
		var from := v.creature.global_position + v.creature.size / 2.0
		var to := card.global_position + card.size * card.scale / 2.0
		Comet.launch(scr._fx, from, to, Color(0.75, 0.62, 0.5))
		await _wait(0.4)
	if not UiSkin.is_puppet():  # (Puppet: sfx_card_hit / sfx_card_break play with the planks)
		Audio.play("sfx_hammer_thump")
	_shake(8.0)
	if card == null:
		return
	if ev.broken:
		# broken: it stays in the row, cracked all over and greyed out (it can't be cast for the rest of the fight)
		card.cracks = 3
		card.refresh()
		if UiSkin.is_puppet():
			await _split_card(card, 3, true)
			Audio.play("sfx_card_break")
		else:
			Audio.play("sfx_hammer_thump")
		scr._h_hud._refresh_all()
		await _wait(0.3)
		return
	card.cracks = ev.hits
	card.refresh()
	if UiSkin.is_puppet():  # (the card is cut into planks that stay together: 1 hit 5, 2 hits 10)
		await _split_card(card, int(ev.hits), true)
		await _wait(0.2)
		return
	var home := card.position
	var tw := card.create_tween()
	tw.tween_property(card, "position", home + Vector2(0, 10), 0.05)
	tw.tween_property(card, "position", home, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	Vfx.make(scr._fx, 70).burst(card.global_position + card.size * card.scale / 2.0, 10, Color(0.9, 0.95, 1.0), Vector2(60, 200), Vector2(0.2, 0.45), Vector2(2, 4), Vfx.SHARD)
	await _wait(0.35)


## After the blow the hammer stays on the card a moment, then the arm goes back to its place.
func _hammer_retreat(cr: Creature) -> void:
	await _wait(0.5)
	if not is_instance_valid(cr):
		return
	var back := scr.create_tween()
	back.tween_property(cr, "poke", 0.0, 0.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await back.finished
	if is_instance_valid(cr):
		cr.poke = 0.0
		cr.tip_z = 0


## A picture of a spell card (as it is, without cracks), with 8 px of margin: (texture, margin).
func _card_picture(card: SpellCard) -> Array:
	var pad := Vector2(8, 8)
	var vp := SubViewport.new()
	vp.size = Vector2i(Vector2(SpellCard.W, SpellCard.H) + pad * 2.0)
	vp.transparent_bg = true
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	scr.add_child(vp)
	var copy := SpellCard.make(card.spell)
	copy.is_zoom_copy = true
	copy.position = pad
	vp.add_child(copy)
	await scr.get_tree().process_frame
	await scr.get_tree().process_frame
	var tex := ImageTexture.create_from_image(vp.get_texture().get_image())
	vp.queue_free()
	return [tex, pad]


## Puppet Stage: a card the Hammer Hand has hit `hits` times is cut into planks (CardSplit) that stay in place; `thump` plays the blow.
func _split_card(card: SpellCard, hits: int, thump: bool) -> void:
	if not is_instance_valid(card) or card.get_meta("split_level", 0) == hits:
		return
	card.set_meta("split_level", hits)
	var pic: Array = await _card_picture(card)
	if not is_instance_valid(card):
		return
	var old: Node = card.get_meta("split_node") if card.has_meta("split_node") else null  # (get_meta with a null default prints an error in Godot 4)
	if is_instance_valid(old):
		old.queue_free()
	var sp := CardSplit.make(pic[0], pic[1], Vector2(SpellCard.W, SpellCard.H), hits)
	card.add_child(sp)
	card.set_meta("split_node", sp)
	if thump:
		sp.thump()
		Audio.play("sfx_card_hit")


## Puppet Stage: the third blow. The card breaks like a puppet that dies (PuppetShatter): ten planks, but they only fall where they are.
func _break_card_wood(card: SpellCard) -> void:
	var pic: Array = await _card_picture(card)
	var pad: Vector2 = pic[1]
	var tex: Texture2D = pic[0]
	var sc := card.scale
	var rect := Rect2(card.global_position - pad * sc, tex.get_size() * sc)
	card.modulate.a = 0.0
	var old: Node = card.get_meta("split_node") if card.has_meta("split_node") else null  # (get_meta with a null default prints an error in Godot 4)
	if is_instance_valid(old):
		old.queue_free()
	PuppetShatter.spawn_picture(scr, tex, rect, card.global_position.y + SpellCard.H * sc.y + 30.0, "sfx_card_break")
	await _wait(1.0)


## A spell card breaks like glass: a picture of it is cut into shards (a Delaunay triangulation, denser around the
## impact) that burst out, tumble and fall, then fade. The sound of breaking glass, then the pieces clinking down.
func _shatter_card(card: SpellCard) -> void:
	var card_size := Vector2(SpellCard.W, SpellCard.H)
	var pad := Vector2(8, 8)
	var vp := SubViewport.new()
	vp.size = Vector2i(card_size + pad * 2.0)
	vp.transparent_bg = true
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	scr.add_child(vp)
	var copy := SpellCard.make(card.spell)
	copy.is_zoom_copy = true
	copy.cracks = 2
	copy.position = pad
	vp.add_child(copy)
	await scr.get_tree().process_frame
	await scr.get_tree().process_frame
	var tex := ImageTexture.create_from_image(vp.get_texture().get_image())
	vp.queue_free()
	var origin := card.global_position - pad * card.scale
	var sc := card.scale
	card.modulate.a = 0.0
	Audio.play("sfx_glass_break")
	# the cut: corners, edge points, and more points near the impact
	var impact := pad + card_size * Vector2(randf_range(0.35, 0.65), randf_range(0.35, 0.6))
	var pts := PackedVector2Array([pad, pad + Vector2(card_size.x, 0), pad + card_size, pad + Vector2(0, card_size.y)])
	for i in 6:
		pts.append(pad + Vector2(card_size.x * randf(), 0))
		pts.append(pad + Vector2(card_size.x * randf(), card_size.y))
	for i in 3:
		pts.append(pad + Vector2(0, card_size.y * randf()))
		pts.append(pad + Vector2(card_size.x, card_size.y * randf()))
	for i in 10:
		pts.append(pad + Vector2(randf() * card_size.x, randf() * card_size.y))
	for i in 8:
		pts.append(impact + Vector2.from_angle(randf() * TAU) * randf_range(8, 45))
	var tris := Geometry2D.triangulate_delaunay(pts)
	var shards := []
	for t in range(0, tris.size(), 3):
		var a := pts[tris[t]]
		var b := pts[tris[t + 1]]
		var c := pts[tris[t + 2]]
		var mid := (a + b + c) / 3.0
		var poly := Polygon2D.new()
		poly.texture = tex
		poly.polygon = PackedVector2Array([a - mid, b - mid, c - mid])
		poly.uv = PackedVector2Array([a, b, c])
		poly.position = origin + mid * sc
		poly.scale = sc
		poly.z_index = 60
		scr._fx.add_child(poly)
		var out := (mid - impact).normalized() if mid.distance_to(impact) > 1.0 else Vector2.UP
		shards.append({"n": poly, "p0": poly.position, "v": out * randf_range(90, 260) + Vector2(0, randf_range(-220, -60)),
			"w": randf_range(-9.0, 9.0)})
	var dur := 1.1
	var t0 := Time.get_ticks_msec() / 1000.0
	var clinks := [0.32, 0.5, 0.7]
	while true:
		var t := Time.get_ticks_msec() / 1000.0 - t0
		if not clinks.is_empty() and t >= clinks[0]:
			clinks.pop_front()
			Audio.play("sfx_glass_clank", -4.0, randf_range(0.85, 1.25))
		for sh in shards:
			var n: Polygon2D = sh.n
			n.position = sh.p0 + sh.v * t + Vector2(0, 900.0) * t * t * 0.5
			n.rotation = sh.w * t
			n.modulate.a = clampf((dur - t) / 0.4, 0.0, 1.0)
		if t >= dur:
			break
		await scr.get_tree().process_frame
	for sh in shards:
		sh.n.queue_free()


## Shake an orb hard while cracks spread across it, then burst it into sparks.
func _crack_and_shatter(ic: ElementIcon, strength: float, dur: float) -> void:
	var home := ic.position
	Audio.play("sfx_lock_break")
	var cr := ic.create_tween()
	cr.tween_property(ic, "cracked", 1.0, dur).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	_quake(dur, 20.0)
	var steps := int(dur / 0.035)
	var sh := ic.create_tween()
	for k in steps:
		var amp := strength * (0.4 + 0.6 * float(k) / steps)
		sh.tween_property(ic, "position", home + Vector2(randf_range(-amp, amp), randf_range(-amp, amp)), 0.035)
	var redraw := func(): if is_instance_valid(ic): ic.queue_redraw()
	for k in steps:
		scr.get_tree().create_timer(k * 0.035).timeout.connect(redraw)
	await _wait(dur)
	if not is_instance_valid(ic):
		return
	ShardBurst.burst(scr._fx, ic.global_position + ic.size / 2.0, Elements.COLORS.get(ic.el, Color.WHITE), ic.size.x * ic.scale.x)
	_shake(strength * 0.6)
	var boom := ic.create_tween().set_parallel(true)
	boom.tween_property(ic, "scale", ic.scale * 1.6, 0.18)
	boom.tween_property(ic, "modulate:a", 0.0, 0.18)
	boom.chain().tween_callback(ic.queue_free)
	await _wait(0.45)


## Every Essence of that element on the enemies shakes, cracks and bursts, the same way.
func _annihilate_enemies(el: String, targets: Array) -> void:
	var icons := []
	for e in targets:
		var v: EnemyView = scr._views.get(e)
		if v == null:
			continue
		for ic in v._hp_icons:
			if is_instance_valid(ic) and ic.el == el:
				icons.append(ic)
	if icons.is_empty():
		return
	for ic in icons:
		ic.pivot_offset = ic.size / 2.0
		_crack_on_the_spot(ic)
	_quake(1.4, 18.0)
	await _wait(1.55)
	_shake(14.0)
	Audio.play("sfx_damage_hit")
	await _wait(0.2)


## Like _crack_and_shatter, for an orb that sits in a row (its container owns its position, so it shakes by
## rotation and a small nudge of its drawing instead).
func _crack_on_the_spot(ic: ElementIcon) -> void:
	var cr := ic.create_tween()
	cr.tween_property(ic, "cracked", 1.0, 1.4).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	var sh := ic.create_tween()
	for k in 40:
		var amp := 0.1 + 0.35 * k / 40.0
		sh.tween_property(ic, "rotation", randf_range(-amp, amp), 0.035)
	sh.tween_property(ic, "rotation", 0.0, 0.03)
	var boom := ic.create_tween()
	boom.tween_interval(1.42)
	boom.tween_callback(func(): if is_instance_valid(ic): ShardBurst.burst(scr._fx, ic.global_position + ic.size / 2.0, Elements.COLORS.get(ic.el, Color.WHITE), ic.size.x))
	boom.tween_property(ic, "scale", Vector2(1.5, 1.5), 0.15)
	boom.parallel().tween_property(ic, "modulate:a", 0.0, 0.15)


func _card_for(id: String) -> SpellCard:
	for c in scr._cards:
		if c.spell.id == id and is_instance_valid(c):
			return c
	return null


## A speech-bubble style callout that says what just happened, near whoever did it.
func _callout(bbcode: String, at: Vector2, col: Color, life := 1.0) -> void:
	var p := _callout_panel(bbcode, col)
	await scr.get_tree().process_frame
	if not is_instance_valid(p):
		return
	p.position = Vector2(clampf(at.x - p.size.x / 2.0, 10, 1910 - p.size.x), clampf(at.y - p.size.y, 10, 1070 - p.size.y))
	p.modulate.a = 0.0
	var tw := p.create_tween()
	tw.tween_property(p, "modulate:a", 1.0, 0.12)
	tw.tween_interval(life)
	tw.tween_property(p, "modulate:a", 0.0, 0.25)
	tw.tween_callback(p.queue_free)


## A callout about one enemy: it stands at the puppet's left, where its intent bubble is (on its right when there is no room), never over the puppet.
func _callout_beside(v: EnemyView, bbcode: String, col: Color, life := 1.0) -> void:
	if v == null or not is_instance_valid(v) or not v.puppet_global_rect().has_area():
		_callout(bbcode, Vector2(960, 600), col, life)
		return
	var p := _callout_panel(bbcode, col)
	await scr.get_tree().process_frame
	if not is_instance_valid(p) or not is_instance_valid(v):
		return
	var r := v.puppet_global_rect()
	var left := r.position.x - 4.0 - p.size.x
	var x := left if left >= 10.0 else r.end.x + 4.0
	p.position = Vector2(clampf(x, 10.0, 1910.0 - p.size.x), clampf(r.get_center().y - p.size.y / 2.0, 10.0, 1070.0 - p.size.y))
	p.modulate.a = 0.0
	var tw := p.create_tween()
	tw.tween_property(p, "modulate:a", 1.0, 0.12)
	tw.tween_interval(life)
	tw.tween_property(p, "modulate:a", 0.0, 0.25)
	tw.tween_callback(p.queue_free)


## The callout box itself (dark, with a coloured border), added to the effects layer but not placed yet.
func _callout_panel(bbcode: String, col: Color) -> PanelContainer:
	var p := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.05, 0.06, 0.05, 0.94)
	sb.border_color = col
	sb.set_border_width_all(3)
	sb.set_corner_radius_all(12)
	sb.content_margin_left = 14
	sb.content_margin_right = 14
	sb.content_margin_top = 8
	sb.content_margin_bottom = 8
	var callout_art := UiSkin.frame("bubble_dark", 16, [18, 10, 18, 10], col.lerp(Color.WHITE, 0.7))  # (a little of the callout's colour on the painted plaque)
	p.add_theme_stylebox_override("panel", (callout_art as StyleBox) if callout_art != null else sb)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.z_index = 60
	var r := RichTextLabel.new()
	r.bbcode_enabled = true
	r.fit_content = true
	r.scroll_active = false
	r.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	r.custom_minimum_size = Vector2(340, 0)
	r.add_theme_font_size_override("normal_font_size", 19)
	r.add_theme_font_size_override("bold_font_size", 21)
	r.add_theme_color_override("default_color", Color(0.93, 0.95, 0.9))
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	r.text = "[center]" + bbcode + "[/center]"
	p.add_child(r)
	scr._fx.add_child(p)
	return p


# ------------------------------------------------------------------ spells, visibly


## A Power's badge under your HP (null if it isn't showing).
func _power_badge(id: String) -> Control:
	for c in scr._status_row.get_children():
		if c.get_meta("power_id", "") == id and not c.is_queued_for_deletion():
			return c
	return null


## Where an artifact sits on screen (its icon's middle), or `fallback`.
func _artifact_center(id: String, fallback: Vector2) -> Vector2:
	for c in scr._arts.get_children():
		if c is ArtifactBar.ArtifactChip and c.id == id:
			return c.global_position + c.size / 2.0
	return fallback


## Before a spell's effect lands, its own show plays out (see SpellFx): from the card to whatever it affects.
func _spell_fly(ev: Dictionary) -> void:
	if ev.op == "pluck" and _shot_fired:
		_shot_fired = false  # the gunshot was the hit
		return
	var card := _card_for(ev.spell.id)
	var from := (card.global_position + card.size * card.scale / 2.0) if card else Vector2(960, 620)
	var src: String = ev.get("from_artifact", "")
	if src.begins_with("power:"):
		var badge := _power_badge(src.substr(6))  # a Power repeats it: the show starts from its badge
		if badge:
			from = badge.global_position + badge.size / 2.0
	elif src != "":
		from = _artifact_center(src, from)  # an artifact repeats it: the show starts from the artifact
	var col := GameData.spell_color(ev.spell.get("full_pattern", ev.spell.pattern)).lightened(0.2)
	if ev.spell.has("bottle"):
		col = Color(0.6, 0.95, 1.0)
	if ev.spell.has("bottle"):
		from = scr._bottle_from
	var op: String = ev.op
	var targets: Array = ev.targets
	var dests := []
	if not targets.is_empty():
		for e in targets:
			var v: EnemyView = scr._views.get(e)
			if v == null:
				continue
			var body := v.creature.global_position + v.creature.size / 2.0
			var row := v.hp_point(e.size() / 2) if e.size() > 0 else body
			if op == "strike" and e.size() > 0:
				row = v.hp_point(e.size() - 1 if ev.eff.get("from", "right") == "right" else 0)
			dests.append({"body": body, "row": row})
	elif op in FightScreen.SELF_OPS or (op == "ethereal" and ev.eff.get("target", "") == "scr"):
		dests.append(_area(scr._player_panel))
	elif op in SpellFx.CHANT_OPS:
		dests.append(_area(scr._chant_row))
	elif op == "draw":
		if scr._h_hud._circus_strips() and ev.eff.get("when", "next") != "now":
			var stash_wait := scr._h_machine._stash_flight(ev, from)  # (Cirus: the Essence slips in behind the tube)
			await _wait(stash_wait)
			return
		if scr._h_hud._puppet_strips():  # (Puppet Stage: the new Essence leave their source for the top funnel and come out of the port, see _puppet_launch)
			scr._bonus_from = from
			await _wait(0.1)
			return
		dests = _draw_slots(ev)
	var player := scr._player_panel.get_global_rect().get_center()
	var wait := SpellFx.play(scr._fx, op, ev.eff, from, dests, col, player, _shake, _hitstop)
	if wait > 0.0:
		await _wait(wait)


## Gain Essence: one {body, el, px} per Essence gained, at the very slot it will appear in (the end of the
## "Coming next turn" row, or the end of your bag for "now").
func _draw_slots(ev: Dictionary) -> Array:
	var els: Array = ev.get("drawn", [])
	if els.is_empty():  # (no roll was passed along: show the element it names, or a random one)
		var el: String = ev.eff.get("el", "random")
		for i in int(ev.eff.get("n", 1)):
			els.append(["F", "W", "A"].pick_random() if el == "random" else el)
	var now: bool = ev.eff.get("when", "next") == "now"
	var out := []
	for i in els.size():
		var at: Vector2
		var px: float
		if now:
			px = FightScreen.BAG_PX
			var k := scr.fight.player.stock.size() + i
			at = scr._stock_row.global_position + scr._h_machine._bag_slot(k, k + 1) + Vector2(px, px) / 2.0
		else:
			px = 44.0
			var k := scr.fight.player.next_draw.size() + i
			if scr._h_hud._circus_strips():
				px = FightScreen.BAG_PX
				at = scr._stock_row.global_position + scr._h_machine._tube_pos(k, k + 1) + Vector2(px, px) / 2.0
			else:
				at = scr._next_row.global_position + Vector2(k * (px + 4.0), 0) + Vector2(px, px) / 2.0
		out.append({"body": at, "row": at, "el": els[i], "px": px})
	return out


func _area(c: Control) -> Dictionary:
	var r := c.get_global_rect()
	return {"body": r.get_center(), "row": r.get_center(), "rect": r}


## Once an effect has landed: flash whatever it touched and say what changed.
func _effect_landed(ev: Dictionary) -> void:
	var eff: Dictionary = ev.get("eff", {})
	if eff.is_empty():
		return
	if eff.op == "ethereal":  # it flickers out of step with the world, half there
		for e in ev.targets:
			var ev_view: EnemyView = scr._views.get(e)
			if ev_view:
				var tw := ev_view.creature.create_tween()
				for a in [0.25, 0.8, 0.15, 0.7, 0.35, 1.0]:
					tw.tween_property(ev_view.creature, "modulate:a", a, 0.07)
	var text := _effect_words(eff)
	if text == "":
		return
	var targets: Array = ev.targets
	if not targets.is_empty():
		for e in targets:
			var v: EnemyView = scr._views.get(e)
			if v:
				v.hit_flash()
				if not (text.begins_with("-") and text.substr(1).is_valid_int()):  # no "-N" on enemies: they react instead
					_float_text(text, v.global_position + Vector2(110, 180), Color(1, 0.85, 0.5))
	else:
		_float_text(text, _player_point() + Vector2(-40, -40), Color(0.6, 0.9, 1))


## The Retainer's support moves: the hand goes down and comes up fast and the bottle flies to the Samurai, the fan waves, the gong is struck (see Creature.retainer_play).
func _retainer_acts(v: EnemyView, ev: Dictionary) -> void:
	var wait := v.creature.retainer_play(String(ev.kind))
	if ev.kind == "bottle":
		await _wait(RetainerRig.release_time())  # (the hand goes down, stops, and starts to come up: the bottle leaves it now)
		_throw_bottle(v)
		wait -= RetainerRig.release_time()
	await _wait(maxf(0.1, wait - 0.5))


## The bottle leaves the Retainer's hand and curves over to the Samurai (an arc, as if thrown).
func _throw_bottle(v: EnemyView) -> void:
	var target: EnemyView = null
	for e in scr._views:
		if is_instance_valid(scr._views[e]) and e.has_passive("avenger") and not e.is_dead():
			target = scr._views[e]
	var path := Creature.enemy_path("samurai_bottle.png", 2)
	if target == null or path == "":
		return
	var held: Array = v.creature.retainer_bottle()
	var from: Vector2 = held[0]
	var to := target.creature.global_position + target.creature.size * Vector2(0.5, 0.4)
	var bottle := Sprite2D.new()
	bottle.texture = load(path)
	var k: float = float(held[1]) / float(bottle.texture.get_width())
	bottle.scale = Vector2.ONE * k
	bottle.global_position = from
	scr._fx.add_child(bottle)
	var arc := maxf(70.0, absf(from.x - to.x) * 0.25)
	var tw := scr.create_tween()
	tw.tween_method(func(q: float): bottle.global_position = from.lerp(to, q) + Vector2(0.0, -arc * sin(q * PI)), 0.0, 1.0, 0.65)
	tw.parallel().tween_property(bottle, "rotation", -TAU * 1.5, 0.65)
	await tw.finished
	bottle.queue_free()


## The Samurai has fallen: his Retainer says so, kneels, and leaves the stage.
func _retainer_yields(r: EnemyState) -> void:
	var rv: EnemyView = scr._views.get(r)
	if rv != null and is_instance_valid(rv):
		rv.creature.retainer_yield()
	await scr._h_talk._speech(r, "I yield.", 1.6)
	await scr._h_talk._speech(r, "You defeated my master honorably. Cheers to you.", 2.6)  # (and his sake is yours: Fight.drops)
	var v: EnemyView = scr._views.get(r)
	if v != null and is_instance_valid(v):
		var tw := v.create_tween().set_parallel()
		tw.tween_property(v, "position:y", v.position.y + 40.0, 0.6).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
		tw.tween_property(v, "modulate:a", 0.0, 0.6)
		await tw.finished


## The Veiled Eyes' laser: a violet beam from its eyes to you (the hit lands right after).
func _eye_laser(e: EnemyState) -> void:
	var v: EnemyView = scr._views.get(e)
	if v == null or not is_instance_valid(v.creature):
		return
	var cr := v.creature
	var from := cr.global_position + Vector2(cr.size.x * 0.5, cr.size.y * (0.5 if e.phase < 2 else 0.4))
	if cr._puppet:
		from = cr.veil_eyes_point()  # (its purple eyes are at the same height in both phases)
	var to := _attack_point()
	Audio.play("spell_glow")
	var fx := Vfx.make(scr._fx, 80)
	fx.shaker = _shake
	for k in 2:  # (soft beams, like the glow of its eyes)
		var gap := Vector2(-22.0 if k == 0 else 22.0, 0)
		var beam := SoftBeam.new()
		beam.a = from + gap - scr._fx.global_position
		beam.b = to - scr._fx.global_position
		beam.color = Color(0.7, 0.35, 1.0)
		beam.width = 9.0
		beam.life = 0.42
		scr._fx.add_child(beam)
	fx.glow(from, 90, Color(0.75, 0.4, 1.0, 0.9), 0.35)
	fx.glow(to, 120, Color(0.75, 0.4, 1.0, 0.8), 0.3, 0.1)
	fx.shake(6.0, 0.1)
	await _wait(0.22)


## The theft: it is pulled up out of sight, drops on its thread right in front of you, picks one of your spells
## up, is pulled up again with it, and comes back down to its place (the cocoon appears next).
func _spider_steal(e: EnemyState, sp: Dictionary) -> void:
	var v: EnemyView = scr._views.get(e)
	var card := _card_for(sp.id)
	if v == null or not is_instance_valid(v.creature):
		return
	var cr := v.creature
	while is_instance_valid(cr) and cr.unveiling():  # (it is still coming out of its veil: the theft comes after)
		await scr.get_tree().process_frame
	if not is_instance_valid(cr):
		return
	var z := cr.z_index
	var slow := FightScreen.SPIDER_SLOW
	cr.z_index = 120
	Audio.play("elem_pickup")
	var up := cr.create_tween()
	up.tween_property(cr, "global_position:y", -cr.size.y - 40.0, 0.35 * slow).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	await up.finished
	var grab := Vector2(960, 700)
	if card:
		grab = card.global_position + Vector2(card.size.x * card.scale.x / 2.0, 0)
	cr.global_position = Vector2(grab.x - cr.size.x / 2.0, -cr.size.y - 40.0)
	var down := cr.create_tween()
	down.tween_property(cr, "global_position:y", grab.y - cr.size.y * 0.85, 0.4 * slow).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	await down.finished
	cr.hit(0.4)  # (it snatches)
	# it changes its stance (the legs fold in and down) and the card is taken into them, in front of its fangs
	var pose := cr.create_tween().set_parallel()
	pose.tween_property(cr, "steal_pose", 1.0, 0.3 * slow).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	var ghost: SpellCard = null
	if card:
		ghost = SpellCard.make(sp)
		ghost.mouse_filter = Control.MOUSE_FILTER_IGNORE
		ghost.z_index = 119  # (behind the spider: its legs are over the card's edges)
		scr._fx.add_child(ghost)
		ghost.global_position = card.global_position
		ghost.scale = card.scale
		card.modulate.a = 0.0
		var spot: Array = cr.steal_card_spot()
		var want := float(spot[1]) / maxf(1.0, ghost.size.x)
		pose.tween_property(ghost, "global_position", spot[0], 0.3 * slow).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		pose.tween_property(ghost, "scale", Vector2(want, want), 0.3 * slow).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	Audio.play("elem_remove")
	await pose.finished
	await _wait(0.2 * slow)
	# it is pulled up with the card
	var off := cr.create_tween().set_parallel()
	var lift: float = (-cr.size.y - 300.0) - cr.global_position.y
	off.tween_property(cr, "global_position:y", -cr.size.y - 300.0, 0.45 * slow).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	if ghost:
		off.tween_property(ghost, "global_position:y", ghost.global_position.y + lift, 0.45 * slow).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)  # (the card rides up with it)
	await off.finished
	if ghost:
		ghost.queue_free()
	cr.steal_pose = 0.0
	cr.z_index = z
	scr._spider_away = e  # (it stays up there: the cocoon is let down first, then the spider comes back, see _spider_return)
	# up there, out of sight, it rolls the card into a cocoon: the rolling sound plays right through, and only then is the cocoon let down
	Audio.play("sfx_cocoon_roll")
	await _wait(maxf(1.0, Audio.get_sfx_length("sfx_cocoon_roll")))


func _slow_of(e: EnemyState) -> float:
	return FightScreen.SPIDER_SLOW if e != null and (e.id == "veiled_eyes" or e.id.begins_with("spiderling") or e.id == "spider_cocoon") else 1.0


## The puppet of a view lifted by `off` px (0 = standing; ENEMY_UP = up in the ropes, out of sight). It moves the Creature's own edges, so the row's layout leaves it alone.
func _lift_creature(cr: Creature, off: float) -> void:
	if not cr.has_meta("base_edges"):
		cr.set_meta("base_edges", Vector2(cr.offset_top, cr.offset_bottom))
	var base: Vector2 = cr.get_meta("base_edges")
	cr.offset_top = base.x + off
	cr.offset_bottom = base.y + off


## A rebuilt view of the spider that is up in the ropes: out of sight, high above its place (it is let down by _spider_return).
func _hold_spider_up(v: EnemyView) -> void:
	v.modulate.a = 0.0
	_lift_creature(v.creature, FightScreen.ENEMY_UP)


## A puppet that arrives in the middle of a fight (the Silk Cocoon) is let down from above on its rope: a fall, then a few bobs. At the spiders' slow speed.
func _drop_view_in(v: EnemyView) -> void:
	if not is_instance_valid(v) or not is_instance_valid(v.creature):
		return
	var slow := _slow_of(v.enemy)
	var cr := v.creature
	_lift_creature(cr, FightScreen.ENEMY_UP)
	v.modulate.a = 1.0
	var tw := scr.create_tween()
	tw.tween_method(func(t: float):
		if not is_instance_valid(cr):
			return
		var off := 0.0
		if t < FightScreen.ENEMY_LET_DOWN:
			var u := t / FightScreen.ENEMY_LET_DOWN
			off = FightScreen.ENEMY_UP * (1.0 - u * u)
		else:
			var sec := t - FightScreen.ENEMY_LET_DOWN
			off = 20.0 * exp(-4.5 * sec) * sin(TAU * 1.8 * sec)
		_lift_creature(cr, off), 0.0, FightScreen.ENEMY_LET_DOWN + FightScreen.ENEMY_SPRING, (FightScreen.ENEMY_LET_DOWN + FightScreen.ENEMY_SPRING) * slow)
	await tw.finished
	if is_instance_valid(cr):
		_lift_creature(cr, 0.0)


## The spider comes back down to its place after the cocoon has been let down.
func _spider_return(e: EnemyState) -> void:
	if e != scr._spider_away:
		return  # (it has come back already: the cocoon's drop called for it)
	scr._spider_away = null
	var v: EnemyView = scr._views.get(e)
	if v == null or not is_instance_valid(v.creature):
		return
	var cr := v.creature
	_lift_creature(cr, FightScreen.ENEMY_UP)
	v.modulate.a = 1.0
	var back := scr.create_tween()
	back.tween_method(func(o: float):
		if is_instance_valid(cr):
			_lift_creature(cr, o), FightScreen.ENEMY_UP * 0.4, 0.0, 0.45 * FightScreen.SPIDER_SLOW).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	await back.finished
	if is_instance_valid(cr):
		_lift_creature(cr, 0.0)


## Mend: a ball of light flies from the enemy that mends to each new Essence (in its own or an ally's row), the same comet as
## a spell's "gain Essence next turn"; each new Essence appears as its ball lands.
func _mend_light(caster: EnemyState, gains: Array) -> void:
	var cv: EnemyView = scr._views.get(caster)
	if cv == null or not is_instance_valid(cv.creature):
		await _wait(0.2)
		return
	await scr.get_tree().process_frame  # (the rows were just rebuilt: let them lay out first)
	var from := cv.creature.get_global_rect().get_center()
	var dests := []
	var i := 0
	for g in gains:
		var tv: EnemyView = scr._views.get(g.enemy)
		if tv == null or int(g.index) >= tv._hp_icons.size():
			continue
		var icon: Control = tv._hp_icons[int(g.index)]
		var at := tv.hp_point(int(g.index))
		dests.append({"body": at, "row": at, "el": g.el, "px": icon.size.x, "ghost": false})
		icon.modulate.a = 0.0  # (it shows when its ball lands)
		var tw := icon.create_tween()
		tw.tween_interval(i * 0.13 + 0.62)
		tw.tween_property(icon, "modulate:a", 1.0, 0.25)
		i += 1
	if dests.is_empty():
		await _wait(0.2)
		return
	var dur := SpellFx.play(scr._fx, "draw", {"op": "draw", "n": dests.size()}, from, dests, Color.WHITE, Vector2.ZERO, _shake, _hitstop)
	await _wait(maxf(dur, 0.62 + dests.size() * 0.13 + 0.25))


## Where what lands on you lands: the middle of the HP tray (Puppet), the Keeper's panel otherwise.
func _player_point() -> Vector2:
	if scr._puppet_hud:
		return scr._player_panel.get_global_rect().get_center()
	return scr._player_panel.global_position + Vector2(240, 50)


## Where the enemies' attacks land: the middle of your Chant bar (they used to go for the HP bar; the HP still drops, and its bar still cracks on a block).
func _attack_point() -> Vector2:
	if is_instance_valid(scr._chant_panel) and scr._chant_panel.is_inside_tree():
		return scr._chant_panel.get_global_rect().get_center()
	return _player_point()


func _effect_words(e: Dictionary) -> String:
	var n: int = int(e.get("n", 0))
	match e.op:
		"strike", "pluck", "purge", "siphon":
			return "-%d" % n
		"steal":
			return ""
		"burn":
			return "Burn %d" % n
		"weak":
			return "Weakened"
		"freeze":
			return "Frozen"
		"expose":
			return ""  # the paint splashes say it
		"shield":
			return "+%d Shield" % n
		"heal":
			return "+%d HP" % n
		"aegis":
			return "+Evasion"
		"thorns":
			return "+%d Thorns" % n
		"draw":
			return "+%d next turn" % n if e.when == "next" else "+%d now" % n
		"stoke":
			return "Burn ×2"
		"execute":
			return "Executed!"
		"cleanse":
			return "Cleansed"
	return ""


# ------------------------------------------------------------------ enemies, visibly


## An enemy steps forward and says what it's about to do.
func _enemy_turn_start(ev: Dictionary) -> void:
	var actor: EnemyView = scr._views.get(ev.enemy)
	for v in scr._views.values():
		v.modulate = Color.WHITE if v == actor else Color(0.55, 0.55, 0.6)
	if actor == null:
		return
	if not ev.enemy.has_passive("behind_shield"):  # (the Necromancer doesn't step forward: he leans out, see _necro_peek)
		var tw := actor.creature.create_tween()
		actor.creature.pivot_offset = actor.creature.size / 2.0
		tw.tween_property(actor.creature, "scale", Vector2(1.12, 1.12), 0.15)
		tw.tween_property(actor.creature, "scale", Vector2.ONE, 0.2)
	var m: Dictionary = ev.move
	var words := "❄ Frozen: it skips its turn." if ev.frozen else _move_words(m, ev.enemy)
	await _file_turn_box()  # (in case the last one is still up)
	# what it's about to do, in a box at the top of the screen; it stays up while the enemy acts
	var box := _callout_panel("[b]%s[/b]\n%s" % [ev.enemy.name, Keywords.colorize(words)], Color(1, 0.55, 0.4))
	box.custom_minimum_size.x = 420
	_turn_box = box
	await scr.get_tree().process_frame
	if not is_instance_valid(box):
		return
	box.position = Vector2(960.0 - box.size.x / 2.0, FightScreen.TURN_BOX_Y)
	box.pivot_offset = box.size / 2.0
	box.modulate.a = 0.0
	box.scale = Vector2(0.85, 0.85)
	var pop := box.create_tween().set_parallel(true)
	pop.tween_property(box, "modulate:a", 1.0, 0.15)
	pop.tween_property(box, "scale", Vector2.ONE, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	await _wait(FightScreen.TURN_READ_TIME)  # a moment to read it before it happens


var _turn_box: PanelContainer


## Once the enemy has acted, its box quietly fades away (its line is already in the log).
func _file_turn_box() -> void:
	var box := _turn_box
	_turn_box = null
	if box == null or not is_instance_valid(box):
		return
	var tw := box.create_tween()
	tw.tween_property(box, "modulate:a", 0.0, 0.3)
	tw.tween_callback(box.queue_free)
	await _wait(0.15)


func _move_words(m: Dictionary, e: EnemyState) -> String:
	var parts := []
	while not m.is_empty():
		var look: Array = IntentChip.LOOK.get(m.kind, ["", Color.WHITE])
		if m.kind == "attack":
			var hits: int = m.get("hits", 1)
			parts.append("%s Attack %d%s" % [look[0], IntentChip.attack_damage(m, e), (" × %d" % hits) if hits > 1 else ""])
		else:
			parts.append("%s %s" % [look[0], EnemyDefs.describe_move(IntentChip._single(m), e.dmg_bonus)])
		m = m.get("also", {})
	return " + ".join(parts)


## The attacker lunges at you: slash marks, a shake, and the HP bar (or the Shield glass) takes the hit.
func _enemy_attack(ev: Dictionary) -> void:
	var v: EnemyView = scr._views.get(ev.enemy)
	var target := _attack_point()
	var hedge: HedgeWall = v.hedges_by_side.get(ev.get("part", ""), null) if v else null
	if is_instance_valid(hedge):
		# one of the Matron's walls attacks: the hedge itself lunges
		var toward := (target - (hedge.global_position + hedge.size / 2.0)).normalized() * 60.0
		var tw := hedge.create_tween()
		tw.tween_property(hedge, "offset", -toward * 0.3, 0.12)
		tw.parallel().tween_property(hedge, "squash", 0.92, 0.12)
		tw.tween_property(hedge, "offset", toward, 0.09)
		tw.parallel().tween_property(hedge, "squash", 1.2, 0.09)
		tw.tween_interval(0.12)
		tw.tween_property(hedge, "offset", Vector2.ZERO, 0.2)
		tw.parallel().tween_property(hedge, "squash", 1.0, 0.2)
		await _wait(0.2)
	elif v and String(ev.get("throw", "")) != "":
		target = await FightScreen.OrphanFx.throw_item(scr, v.creature.global_position + Vector2(v.creature.size.x * 0.5, 40.0), target, String(ev.throw))  # (the hit shows where it lands)
	elif v and v.creature.has_rig() and ev.enemy.id == "hand_spear":
		target = await _spear_stab(v, float(ev.n))  # (the spear thrusts up into your HP bar: the hit lands there)
	elif v and v.creature.has_rig() and ev.enemy.id == "hand_sword":
		target = await _sword_slash(v, float(ev.n))  # (the blade cuts across your HP bar: the hit lands there)
	elif v and v.creature.has_rig() and ev.enemy.id == "hand_crossbow" and _arrow_tex() != null:
		target = await _arrow_shot(v, float(ev.n))  # (the bolt flies up and sticks in your HP bar: the hit lands there)
	elif v and v.creature.has_samurai():
		await _wait(v.creature.samurai_strike(int(ev.get("hit", 0)), int(ev.get("hits", 1))))  # (the swing plays; the blow lands when his sword comes down)
	elif v and v.creature.has_rig():
		# a Handyman hand: the arm winds back and swings down at you (about its shoulder and its elbow)
		_arm_swing(v.creature, 1.0)
		await _wait(0.23)
	elif v:
		v.creature.dragon_fx()
		var c := v.creature
		var home := c.position
		var toward := (target - (c.global_position + c.size / 2.0)).normalized() * 70.0
		c.pivot_offset = c.size / 2.0
		var sl := _slow_of(ev.enemy)  # (the spiders move at half speed)
		var tw := c.create_tween()
		tw.tween_property(c, "position", home - toward * 0.3, 0.12 * sl)  # wind up
		tw.parallel().tween_property(c, "scale", Vector2(0.92, 0.92), 0.12 * sl)
		tw.tween_property(c, "position", home + toward, 0.09 * sl)  # lunge
		tw.parallel().tween_property(c, "scale", Vector2(1.3, 1.3), 0.09 * sl)
		tw.tween_interval(0.12 * sl)
		tw.tween_property(c, "position", home, 0.2 * sl)
		tw.parallel().tween_property(c, "scale", Vector2.ONE, 0.2 * sl)
		await _wait(maxf(0.2 * sl, c.dragon_hit_time()))  # (the Winter Wyvern's bite or slam takes longer to land)
	var was_blocked: bool = ev.get("blocked", false)
	ImpactFx.burst(scr._fx, target, was_blocked and ev.n == 0)
	Audio.play("sfx_player_hit" if ev.n > 0 else "release_armour_block")
	if was_blocked:
		scr._hp_bar.crack()
	# bigger hits feel bigger: more shake, a red flash, and a moment's hit-stop on heavy blows
	var hurt: float = float(ev.n) / maxf(1.0, scr.fight.player.max_hp)
	_shake(clampf(7.0 + ev.n * 0.9, 7.0, 30.0) if ev.n > 0 else 5.0)
	if ev.n > 0:
		scr._danger.flash(0.35 + hurt * 3.0)
		if ev.n >= 10:
			_hitstop(0.05 + minf(ev.n, 40) / 500.0)
	if ev.n > 0:
		_float_text("-%d" % ev.n, target + Vector2(-20, -70), UiTheme.DANGER)
		var tw2 := scr._player_panel.create_tween()
		tw2.tween_property(scr._player_panel, "modulate", Color(1.6, 0.6, 0.6), 0.08)
		tw2.tween_property(scr._player_panel, "modulate", Color.WHITE, 0.3)
	else:
		_float_text("Blocked!", target + Vector2(-40, -70), Color(0.6, 0.85, 1))
	scr._h_hud._refresh_all()
	await _wait(0.6)


## The Winter Wyvern's Fireball leaves its hover, curves across the stage into your HP bar and bursts there. Returns the point it burst at.
func _fireball_fly(v: EnemyView) -> Vector2:
	var cr: Creature = v.creature
	var target := scr._hp_bar.get_global_rect().get_center()
	var ft: Texture2D = cr.dragon_fx_tex("fireball")
	var from := cr.dragon_ball_point()
	var sc0 := cr.dragon_ball_width() / float(ft.get_width())
	cr.dragon_hide_ball()
	var ball := Sprite2D.new()
	ball.texture = ft
	ball.z_as_relative = false
	ball.z_index = 300
	ball.global_position = from
	ball.scale = Vector2(sc0, sc0)
	scr.add_child(ball)
	Audio.play(FightScreen.LAUNCH_SFX.get("F", "elem_pickup"))
	var mid := (from + target) * 0.5 + Vector2(0.0, -140.0)  # (it arcs up and over, then drops on the bar)
	var tw := scr.create_tween()
	tw.tween_method(func(u: float) -> void:
		if not is_instance_valid(ball):
			return
		var k := u * u * (3.0 - 2.0 * u) * 0.35 + u * 0.65  # (slow to leave, quick to land)
		var p := from.lerp(mid, k).lerp(mid.lerp(target, k), k)
		var dir := (p - ball.global_position)
		if dir.length() > 0.5:
			ball.rotation = dir.angle() + PI  # (its flame tail is on the right of the picture)
		ball.global_position = p
		ball.scale = Vector2(sc0, sc0) * (1.0 + 0.4 * k), 0.0, 1.0, 0.62)
	await _wait(0.62)
	if is_instance_valid(ball):
		ball.queue_free()
	var bt: Texture2D = cr.dragon_fx_tex("burst")
	if bt != null:
		var star := Sprite2D.new()
		star.texture = bt
		star.z_as_relative = false
		star.z_index = 300
		star.global_position = target
		var s0 := 150.0 / float(bt.get_width())
		star.scale = Vector2(s0, s0)
		scr.add_child(star)
		var tb := star.create_tween()
		tb.tween_property(star, "scale", Vector2(s0, s0) * 2.6, 0.4).set_ease(Tween.EASE_OUT)
		tb.parallel().tween_property(star, "modulate:a", 0.0, 0.4)
		tb.tween_callback(star.queue_free)
	Audio.play(FightScreen.IMPACT_SFX.get("F", "sfx_damage_hit"))
	return target


## The Sword Hand strikes: its arm reaches up over the screen to your HP bar, the blade held back at one side, then cuts across the part of the bar the
## hit takes away. Returns the point the blade lands on (the caller plays the impact and the damage there).
func _sword_slash(v: EnemyView, _dmg: float) -> Vector2:
	var cr: Creature = v.creature
	var target := scr._hp_bar.get_global_rect().get_center() + Vector2(-20.0, 0.0)  # (the whole bar, not the part this hit took: that part moves with your HP, and so would the cut; 20 px to the left of the middle)
	cr.tip_z = PuppetStage.CEILING_Z + 3
	cr.poke_target = target + Vector2(-110.0, -45.0)  # (wound up: above and behind the bar)
	var reach := scr.create_tween()
	reach.tween_property(cr, "poke", 1.0, 0.4).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	await reach.finished
	await _wait(0.15)
	var cut := scr.create_tween()  # (the cut: fast, down and across the bar)
	cut.tween_property(cr, "poke_target", target + Vector2(110.0, 25.0), 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	await cut.finished
	_hammer_retreat(cr)
	return target


func _arrow_tex() -> Texture2D:
	var path := Creature.enemy_path("handyman/arrow.png", 1)
	return load(path) as Texture2D if path != "" else null


## Where the bolt sticks in the HP bar: the middle of the part the hit has just taken away (HP is already down when the attack plays).
func _arrow_target(dmg: float) -> Vector2:
	var mx := maxf(1.0, scr.fight.player.max_hp)
	var frac := clampf((clampf(scr.fight.player.hp, 0.0, mx) + dmg * 0.5) / mx, 0.03, 0.97)
	if scr._hp_bar is StripeHpBar:
		return scr._hp_bar.point_at(frac)  # (the bar's window starts after the ring)
	var r := scr._hp_bar.get_global_rect()
	return Vector2(r.position.x + r.size.x * frac, r.position.y + r.size.y * 0.5)


func _arrow_shot(v: EnemyView, dmg: float) -> Vector2:
	var tex := _arrow_tex()
	var cr: Creature = v.creature
	var sc := FightScreen.ARROW_LEN / float(tex.get_width())
	var arrow := Sprite2D.new()
	arrow.texture = tex
	arrow.z_as_relative = false
	arrow.z_index = 300
	arrow.modulate.a = 0.0
	var hand := cr.hand_global()
	var bow := float(Creature.AIM_BOW["hand_crossbow"])
	var rest_dir := float(cr._rig.theta2) + bow  # (where the bow points while it idles)
	var target := _arrow_target(dmg)
	var aim_dir := (target - hand).angle()
	arrow.global_position = hand + Vector2.from_angle(rest_dir) * FightScreen.ARROW_NOCK
	arrow.rotation = rest_dir + PI  # (the head is on the left of the picture)
	arrow.scale = Vector2(sc, sc) * 0.8
	scr.add_child(arrow)
	var tw := arrow.create_tween()
	tw.tween_property(arrow, "modulate:a", 1.0, 0.2)
	tw.parallel().tween_property(arrow, "scale", Vector2(sc, sc), 0.2)
	await _wait(0.3)  # (it lies on the bow a moment)
	var fin := [rest_dir]  # (the direction the bolt ends up pointing in)
	var turn := scr.create_tween()  # (arm, hand, bow and bolt turn as one, then hold the aim for a second, trembling a little)
	turn.tween_method(func(u: float) -> void:
		if not is_instance_valid(cr) or not is_instance_valid(arrow):
			return
		var k := smoothstep(0.0, 0.35, u)  # (0.35 s of turning, then the hold)
		cr.aim_dir = (target - cr.hand_global()).angle()  # (the hand moves as the arm turns: aim from where it is now)
		cr.aim = k
		var d := lerp_angle(rest_dir, cr.aim_dir, k) + (sin(u * 60.0) * 0.015 if u > 0.4 else 0.0)
		fin[0] = d
		arrow.global_position = cr.hand_global() + Vector2.from_angle(d) * FightScreen.ARROW_NOCK
		arrow.rotation = d + PI, 0.0, 1.35, 1.35)
	await _wait(1.35)
	aim_dir = cr.aim_dir
	var aim_rot: float = float(fin[0]) + PI
	var dir := Vector2.from_angle(aim_dir)
	var stuck := target + dir * 12.0 - dir * FightScreen.ARROW_LEN * 0.5  # (the head goes in a little past the surface)
	var from := arrow.global_position
	_arm_swing(cr, 0.4)  # (the bow kicks)
	var fly := arrow.create_tween()
	fly.tween_property(arrow, "global_position", from + (stuck - from), 0.3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	await _wait(0.3)
	var wob := arrow.create_tween()  # (it shudders in the wood)
	wob.tween_property(arrow, "rotation", aim_rot + 0.07, 0.05)
	wob.tween_property(arrow, "rotation", aim_rot - 0.05, 0.07)
	wob.tween_property(arrow, "rotation", aim_rot, 0.08)
	var gone := arrow.create_tween()
	gone.tween_interval(FightScreen.ARROW_STAY)
	gone.tween_property(arrow, "modulate:a", 0.0, 0.25)
	gone.tween_callback(arrow.queue_free)
	scr._h_input._aim_release(cr)
	return target


## The Spear Hand strikes: the spear reaches up below your HP bar, then thrusts up into the part of the bar the hit takes away.
func _spear_stab(v: EnemyView, _dmg: float) -> Vector2:
	var cr: Creature = v.creature
	var target := scr._hp_bar.get_global_rect().get_center()
	cr.tip_z = PuppetStage.CEILING_Z + 3
	var turn := scr.create_tween()  # (the arm turns until the point of the spear aims straight at the bar)
	turn.tween_method(func(u: float) -> void:
		if is_instance_valid(cr):
			cr.aim_dir = (target - (cr.hand_global() - cr.lunge)).angle()
			cr.aim = smoothstep(0.0, 1.0, u), 0.0, 1.0, 0.5)
	await turn.finished
	var dist := (target - (cr.hand_global() - cr.lunge)).length()
	var dir := Vector2.from_angle(cr.aim_dir)
	var far := maxf(0.0, dist - FightScreen.SPEAR_TIP_LEN + 15.0)  # (until the point is a little way in)
	var back := scr.create_tween()  # (pulls back a little)
	back.tween_property(cr, "lunge", -dir * 40.0, 0.25).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	await back.finished
	await _wait(0.15)
	var stab := scr.create_tween()  # (the thrust: fast, straight along the spear)
	stab.tween_property(cr, "lunge", dir * far, 0.1).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	await stab.finished
	_spear_back(cr)
	return target


func _spear_back(cr: Creature) -> void:
	await _wait(0.5)
	if not is_instance_valid(cr):
		return
	var back := scr.create_tween().set_parallel()
	back.tween_property(cr, "lunge", Vector2.ZERO, 0.4).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	back.tween_property(cr, "aim", 0.0, 0.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await back.finished
	if is_instance_valid(cr):
		cr.aim = 0.0
		cr.aim_dir = INF
		cr.tip_z = 0


## A Handyman hand that is down for good breaks like the other puppets. Its arm is not one picture, so the arm is drawn once, as it stands,
## into a picture of its own first (a SubViewport, like the spell cards that shatter), and that picture is broken into pieces.
func _shatter_arm(c: Creature) -> void:
	if not c.is_inside_tree() or c._enemy == null:
		return
	var vp_size := Vector2i(1500, 1000)
	var mid := c.global_position + c.size / 2.0  # (the hand marker)
	var enemy: EnemyState = c._enemy
	var reach := c.reach
	var reach_angle := c.reach_angle
	var csize := c.size
	var vp := SubViewport.new()
	vp.size = vp_size
	vp.transparent_bg = true
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	scr.add_child(vp)
	var copy := Creature.new()
	copy.setup(enemy)
	copy.size = csize
	copy.reach = reach
	copy.reach_angle = reach_angle
	copy.position = Vector2(vp_size) / 2.0 - csize / 2.0
	vp.add_child(copy)
	await scr.get_tree().process_frame
	await scr.get_tree().process_frame
	var tex := ImageTexture.create_from_image(vp.get_texture().get_image())
	vp.queue_free()
	PuppetShatter.spawn_picture(scr, tex, Rect2(mid - Vector2(vp_size) / 2.0, Vector2(vp_size)), mid.y + 90.0)


## A Handyman hand's swing: it winds up (a little the other way), strikes, holds a moment and settles back. `power` 1 is a full blow.
func _arm_swing(c: Creature, power: float) -> void:
	var tw := c.create_tween()
	tw.tween_property(c, "swing", -0.4 * power, 0.14).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.tween_property(c, "swing", power, 0.09).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_interval(0.14)
	tw.tween_property(c, "swing", 0.0, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## An enemy steals Essence from your bag (the Tweezer Hand): its arm pinches, the stolen Essence lift out of the bag one after another (a pick-up
## sound), fly over to the thief and drop onto its row of Essence (a clack), and a line says what was taken.
func _steal_fx(ev: Dictionary, v: EnemyView) -> void:
	var items: Array = ev.get("items", [])
	var thief := ev.enemy.name as String
	var to := (v.creature.global_position + v.creature.size / 2.0) if v else Vector2(960, 300)
	if v and v.creature.has_rig() and Creature.POKE_TIP.has(ev.enemy.id) and not items.is_empty():
		await _steal_poke(ev, v, items)  # (the Tweezer Hand reaches into the bag for each Essence)
		return
	if v and v.creature.has_rig() and Creature.POKE_TIP.has(ev.enemy.id) and items.is_empty():
		await _steal_nothing(thief, v)  # (the Tweezer Hand grabs at the empty bag three times)
		return
	if v and v.creature.has_rig():
		_arm_swing(v.creature, 0.6)
	if items.is_empty():
		_float_text("%s finds nothing to steal" % thief, scr._stock_row.global_position + Vector2(300, -30), Color(0.8, 0.8, 0.85))
		await _wait(0.6)
		scr._h_hud._sync_views()
		scr._h_hud._refresh_all()
		return
	await _wait(0.22)
	var names: Array = []
	for k in items.size():
		var it: Dictionary = items[k]
		names.append(Elements.NAMES.get(it.el, it.el))
		var from := scr._h_hud._bag_center(it.uid)
		var bag_icon: Control = scr._bag_icons.get(it.uid)
		if bag_icon != null and is_instance_valid(bag_icon):
			bag_icon.modulate.a = 0.0  # (it has left the bag)
		_steal_orb(String(it.el), from, to, k * 0.2, v)
	_float_text("%s steals %s" % [thief, ", ".join(names)], scr._stock_row.global_position + Vector2(260, -40), Color(1, 0.55, 0.45))
	await _wait(0.2 * items.size() + 0.75)
	scr._h_hud._sync_views()
	scr._h_hud._refresh_all()


## The bag is empty: the Tweezer Hand reaches down into it and snaps at three different places, comes up with nothing, the Handyman's face cries, a line says
## so, and the arm goes back.
func _steal_nothing(thief: String, v: EnemyView) -> void:
	var cr: Creature = v.creature
	cr.tip_z = PuppetStage.CEILING_Z + 3
	var base := scr._stock_row.global_position
	var spots := [Vector2(140.0, 34.0), Vector2(380.0, 34.0), Vector2(260.0, 34.0)]
	for k in spots.size():
		if not is_instance_valid(cr):
			return
		cr.poke_target = base + spots[k]
		var reach := scr.create_tween()
		reach.tween_property(cr, "poke", 1.0, 0.35 if k == 0 else 0.22).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		await reach.finished
		Audio.play("sfx_steal_miss" if Audio.has_sfx("sfx_steal_miss") else "elem_pickup", 0.0, randf_range(0.97, 1.03))  # (the tweezers snap shut on nothing: fx_evasion_2, once per grab)
		await _wait(0.2)
		if k < spots.size() - 1:
			var lift := scr.create_tween()  # (up a little, and over to the next place)
			lift.tween_property(cr, "poke", 0.55, 0.16).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
			await lift.finished
	if is_instance_valid(cr):
		scr.get_tree().call_group("handyman_body", "cry", 2.0)
	_float_text("%s finds nothing to steal" % thief, base + Vector2(300, -30), Color(0.8, 0.8, 0.85))
	await _wait(0.9)
	if is_instance_valid(cr):
		var back := scr.create_tween()
		back.tween_property(cr, "poke", 0.0, 0.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		await back.finished
	if is_instance_valid(cr):
		cr.poke = 0.0
		cr.tip_z = 0
	scr._h_hud._sync_views()
	scr._h_hud._refresh_all()


## The Tweezer Hand steals: for every Essence the arm reaches out over the screen (over the chant, the bag...) and its tweezers close on that very Essence,
## the Essence comes away with the tip as the arm pulls back, and is dropped onto the thief's row.
func _steal_poke(ev: Dictionary, v: EnemyView, items: Array) -> void:
	var cr: Creature = v.creature
	var thief := ev.enemy.name as String
	cr.tip_z = PuppetStage.CEILING_Z + 3  # (the tweezers go over the HUD: only the lower stick, the upper one stays under the Handyman's body)
	var names: Array = items.map(func(it): return Elements.NAMES.get(it.el, it.el))
	_float_text("%s steals %s" % [thief, ", ".join(names)], scr._stock_row.global_position + Vector2(260, -40), Color(1, 0.55, 0.45))
	await _wait(0.12)
	# the stolen Essence already sit in the thief's row (the fight did that): show the row as it will be, the new ones still invisible, each shows up
	# when its Essence arrives
	var old_n: int = ev.enemy.elements.size() - items.size()
	v.refresh({})
	for j in range(old_n, old_n + items.size()):
		if j >= 0 and j < v._hp_icons.size():
			v._hp_icons[j].modulate.a = 0.0
	for k in items.size():
		var it: Dictionary = items[k]
		if not is_instance_valid(cr):
			break
		var from := scr._h_hud._bag_center(it.uid)
		cr.poke_target = from
		var reach := scr.create_tween()
		reach.tween_property(cr, "poke", 1.0, 0.3).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		await reach.finished
		if not is_instance_valid(cr):
			break
		# the tweezers close on it: it leaves the bag and hangs on the tip
		var bag_icon: Control = scr._bag_icons.get(it.uid)
		if bag_icon != null and is_instance_valid(bag_icon):
			bag_icon.modulate.a = 0.0
		Audio.play("sfx_steal" if UiSkin.is_puppet() else "elem_pickup", -3.0, randf_range(0.95, 1.05))
		var ic := ElementIcon.make(String(it.el), FightScreen.BAG_PX)
		ic.size = Vector2(FightScreen.BAG_PX, FightScreen.BAG_PX)
		ic.pivot_offset = ic.size / 2.0
		ic.z_index = PuppetStage.CEILING_Z + 5
		ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
		scr._fx.add_child(ic)
		ic.position = from - scr._fx.global_position - ic.size / 2.0
		await _wait(0.08)
		# the arm pulls back; the Essence rides on the tip first, then slides on to its place in the thief's row, arriving as the arm settles
		var slot := old_n + k
		var ratio := 0.6
		if slot >= 0 and slot < v._hp_icons.size() and is_instance_valid(v._hp_icons[slot]):
			ratio = float(v._hp_icons[slot].size.x) / FightScreen.BAG_PX
		var back := scr.create_tween()
		back.tween_property(cr, "poke", 0.0, 0.55).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		back.parallel().tween_method(func(u: float) -> void:
			if is_instance_valid(ic) and is_instance_valid(cr):
				var w := smoothstep(0.3, 1.0, u)
				ic.position = cr.tool_tip().lerp(v.hp_point(slot), w) - scr._fx.global_position - ic.size / 2.0
				ic.scale = Vector2.ONE * lerpf(1.0, ratio, w), 0.0, 1.0, 0.55)
		await back.finished
		if is_instance_valid(ic):
			ic.queue_free()
		if slot >= 0 and slot < v._hp_icons.size() and is_instance_valid(v._hp_icons[slot]):
			v._hp_icons[slot].modulate.a = 1.0  # (it takes its place)
		if is_instance_valid(cr):
			cr.flash = 0.7
	if is_instance_valid(cr):
		cr.poke = 0.0
	if is_instance_valid(cr):
		cr.tip_z = 0
	scr._h_hud._sync_views()
	scr._h_hud._refresh_all()


## One stolen Essence: pops out of the bag, flies in an arc to `to` and lands on the thief (which flashes).
func _steal_orb(el: String, from: Vector2, to: Vector2, delay: float, v: EnemyView) -> void:
	var ic := ElementIcon.make(el, FightScreen.BAG_PX)
	ic.size = Vector2(FightScreen.BAG_PX, FightScreen.BAG_PX)
	ic.pivot_offset = ic.size / 2.0
	ic.z_index = 60
	ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ic.modulate = Color(1.5, 1.4, 1.3, 0.0)
	scr._fx.add_child(ic)
	ic.position = from - scr._fx.global_position - ic.size / 2.0
	var mid := (from + to) / 2.0 + Vector2(0, -120.0)
	var tw := scr.create_tween()
	tw.tween_interval(delay)
	tw.tween_callback(func():
		Audio.play("sfx_steal" if UiSkin.is_puppet() else "elem_pickup", -3.0, randf_range(0.95, 1.05))
		if is_instance_valid(ic):
			ic.modulate.a = 1.0)
	tw.tween_method(func(t: float) -> void:
		if is_instance_valid(ic):
			var pt := from.lerp(mid, t).lerp(mid.lerp(to, t), t)
			ic.position = pt - scr._fx.global_position - ic.size / 2.0
			ic.rotation = -t * TAU
			ic.scale = Vector2.ONE * lerpf(1.0, 0.7, t), 0.0, 1.0, 0.6).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_callback(func():
		if not UiSkin.is_puppet():
			Audio.play("sfx_ball_clack", -4.0, randf_range(0.95, 1.1))
		if is_instance_valid(ic):
			ic.queue_free()
		if v != null and is_instance_valid(v):
			v.creature.flash = 0.7)


## Anything else an enemy does: debuffs fly at you, buffs glow on the enemy.
func _enemy_move_fx(ev: Dictionary) -> void:
	var v: EnemyView = scr._views.get(ev.enemy)
	var kind: String = ev.kind
	if kind in ["freeze", "hex", "invert", "steal", "drain_essence"]:
		await scr._h_machine._rolls_done()  # (it lands on your Essence: wait until they have stopped rolling)
	if kind == "steal":
		await _steal_fx(ev, v)
		return
	var move_sfx := String(ev.get("move", {}).get("sfx", ""))
	if move_sfx == "gong":
		Audio.play("gong", -2.0)
	elif move_sfx != "":
		Audio.play(move_sfx)  # (a sound of the move's own: the Rot Snake's hiss)
	elif FightScreen.ENEMY_KIND_SFX.has(kind):
		Audio.play(FightScreen.ENEMY_KIND_SFX[kind])
	var look: Array = IntentChip.LOOK.get(kind, ["✦", Color.WHITE])
	if v and v.creature.has_rig():  # (a Handyman hand: its arm acts it out, a little gentler than a blow)
		_arm_swing(v.creature, 0.6)
		await _wait(0.23)
	if (kind in Fight.AT_PLAYER or kind in ["virus", "vulnerable"]) and v:
		var from := v.creature.global_position + v.creature.size / 2.0
		var to := _attack_point()
		var comet := Comet.launch(scr._fx, from, to, (look[1] as Color).lightened(0.3))
		comet.rise = 60.0
		await _wait(0.45)
		_shake(4.0)
	elif v and v.creature.has_rig():
		v.creature.flash = 0.7  # (a hand of the Handyman that charges or buffs only glows: hit_flash would make it blink and his face cry as if it had been struck)
	elif v and ev.enemy.id == "samurai_retainer":
		await _retainer_acts(v, ev)
	elif v:
		v.hit_flash()
		v.creature.dragon_fx()  # (the Winter Wyvern's Fireball / roar)
	scr._h_hud._sync_views()
	scr._h_hud._refresh_all()
	await _wait(0.5)


## A violent, building earthquake: the whole screen shakes harder and harder for `dur` seconds.
func _quake(dur: float, amount: float) -> void:
	var tw := scr.create_tween()
	var steps := int(dur / 0.03)
	for i in steps:
		var a := amount * (0.25 + 0.75 * float(i) / steps)
		tw.tween_property(scr, "position", Vector2(randf_range(-a, a), randf_range(-a, a)), 0.03)
	tw.tween_property(scr, "position", Vector2.ZERO, 0.05)


var _shake_tw: Tween


## A quick jolt of the whole screen. Shakes can overlap: each new one takes over and always settles back home.
func _shake(amount: float) -> void:
	if _shake_tw and _shake_tw.is_valid():
		_shake_tw.kill()
	_shake_tw = scr.create_tween()
	for i in 5:
		var a := amount * (1.0 - i * 0.15)
		_shake_tw.tween_property(scr, "position", Vector2(randf_range(-a, a), randf_range(-a, a)), 0.035)
	_shake_tw.tween_property(scr, "position", Vector2.ZERO, 0.05)


var _stop_until := 0  # (ticks msec) when the current hit-stop ends


var _stop_id := 0  # the latest hit-stop: only its own timer may end it


## Hit-stop: the game all but freezes for `sec` on a heavy impact. Overlapping stops don't add up: the later end wins.
func _hitstop(sec: float) -> void:
	if not scr.is_inside_tree():
		return
	var until := Time.get_ticks_msec() + int(sec * 1000.0)
	if until <= _stop_until:
		return
	_stop_until = until
	_stop_id += 1
	Engine.time_scale = 0.02  # (not 0: nothing ever divides by a zero frame time)
	scr.get_tree().create_timer(sec, true, false, true).timeout.connect(_end_hitstop.bind(_stop_id))


func _end_hitstop(id: int) -> void:
	if id == _stop_id:
		Engine.time_scale = 1.0


## One chant element lifts off as a comet and flies into every HP element it hits (or fizzles upward).
func _release_step(ev: Dictionary) -> void:
	scr._step_pos = ev.pos
	scr._released = true
	var slots := scr._chant_row.get_children().filter(func(c): return c is Panel)
	if ev.pos >= slots.size():
		return
	var slot: Panel = slots[ev.pos]
	var from := slot.global_position + slot.size / 2.0
	var el: String = ev.chant[ev.pos]
	var col: Color = Elements.COLORS[el]
	if ev.get("leftover", false):
		# nothing left to hit: it just fades quietly out of the chant
		for c in slot.get_children():
			c.create_tween().tween_property(c, "modulate:a", 0.0, 0.25)
		await _wait(0.05)
		return
	# the orb in the chant lights up, then empties as it leaves
	for c in slot.get_children():
		var tw := c.create_tween()
		tw.tween_property(c, "modulate", Color(2.2, 2.2, 2.0), 0.08)
		tw.tween_property(c, "modulate", Color(1, 1, 1, 0.25), 0.2)
	Audio.play(FightScreen.LAUNCH_SFX.get(el, "elem_pickup"))
	if ev.hits.is_empty():
		Comet.launch(scr._fx, from, from + Vector2(0, -170), col, true)
		await _wait(0.16)
		return
	var impact: String = FightScreen.IMPACT_SFX.get(el, "sfx_damage_hit")
	for h in ev.hits:
		var v: EnemyView = scr._views.get(h[0])
		if v == null:
			continue
		if h.size() > 2 and h[2]:
			_deflect_comet(from, v.hp_point(h[1]), col, h[0])
			continue
		var comet := Comet.launch(scr._fx, from, v.hp_point(h[1]), col)
		var j: int = h[1]
		comet.arrived.connect(func():
			if is_instance_valid(v): v.pop(j)
			Audio.play(impact))
	await _wait(0.46)


## The Samurai's Deflect: the chant Essence flies at its target as usual, but an air slash (a pale crescent) flies out
## of his sword and meets it on the way: a clang, sparks, a tiny freeze and shake, and the ball bounces off it, mirrored
## about the slash as a real deflection would be.
func _deflect_comet(from: Vector2, target: Vector2, col: Color, who: EnemyState = null) -> void:
	var meet := from.lerp(target, 0.62)
	var comet := Comet.launch(scr._fx, from, meet, col)
	var sword := meet + Vector2(0, -260)
	var guard: EnemyState = who
	if who != null and who.has_passive("retainer"):
		guard = null  # (the Retainer is guarded by his lord's sword)
	for e in scr._views:
		if (e == guard or (guard == null and e.has_passive("avenger"))) and is_instance_valid(scr._views[e]):
			var r: Rect2 = scr._views[e].puppet_global_rect()
			sword = r.position + Vector2(r.size.x * 0.3, r.size.y * 0.4)
	CrescentSlash.launch(scr._fx, sword, meet, comet.dur)
	# where it bounces: its way in at the moment of impact (the end of the comet's curve), reflected about the slash's
	# face (the slash flies along its own normal)
	var ctrl := (from + meet) / 2.0 + Vector2(0, -comet.rise)
	var v_in := (meet - ctrl).normalized()
	var n := (meet - sword).normalized()
	var v_out := v_in - 2.0 * v_in.dot(n) * n
	var away := meet + v_out * 460.0
	comet.arrived.connect(func():
		Audio.play("sword_clang", -3.0, randf_range(0.92, 1.08))
		var fx := Vfx.make(scr._fx, 70)
		fx.burst(meet, 14, Color(1.0, 0.95, 0.75), Vector2(160, 420), Vector2(0.15, 0.35), Vector2(2, 5), Vfx.SPARK)
		fx.flash(Color(1, 1, 1, 0.12), 0.08)
		_hitstop(0.05)  # (light: a blink of a freeze and a small shake)
		_shake(3.0)
		var bounce := Comet.launch(scr._fx, meet, away, col)
		bounce.rise = 30.0
		bounce.dur = 0.5
		bounce.ease_out = true)


func _wait(t: float) -> void:
	if scr.is_inside_tree():
		await scr.get_tree().create_timer(t).timeout


func _float_text(text: String, pos: Vector2, col: Color) -> void:
	# New theme: a plain "+3" heal rides on a painted green splat, in white digits (damage gets no splat: no blood)
	if text.length() > 1 and text[0] == "+" and text.substr(1).is_valid_int():
		var splat := UiSkin.tex("float_heal")
		var digits := UiSkin.number(text, 34, true) if splat != null else null
		if digits != null:
			var st := Control.new()
			st.size = splat.get_size() * 1.15
			st.position = pos - Vector2(st.size.x / 2.0 - 40.0, 10.0)
			st.mouse_filter = Control.MOUSE_FILTER_IGNORE
			var bg := TextureRect.new()
			bg.texture = splat
			bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			bg.stretch_mode = TextureRect.STRETCH_SCALE
			bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
			st.add_child(bg)
			var cc := CenterContainer.new()
			cc.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			cc.mouse_filter = Control.MOUSE_FILTER_IGNORE
			cc.add_child(digits)
			st.add_child(cc)
			scr._fx.add_child(st)
			var stw := st.create_tween()
			stw.set_parallel()
			stw.tween_property(st, "position:y", st.position.y - 60, 0.8)
			stw.tween_property(st, "modulate:a", 0.0, 0.8).set_delay(0.3)
			stw.chain().tween_callback(st.queue_free)
			return
	var l := UiTheme.label(text, 34, col)
	l.add_theme_constant_override("outline_size", 8)
	l.add_theme_color_override("font_outline_color", Color.BLACK)
	l.position = pos
	scr._fx.add_child(l)
	var tw := l.create_tween()
	tw.set_parallel()
	tw.tween_property(l, "position:y", pos.y - 60, 0.8)
	tw.tween_property(l, "modulate:a", 0.0, 0.8).set_delay(0.3)
	tw.chain().tween_callback(l.queue_free)


func _banner(text: String, col: Color, life := 1.2) -> void:
	var l := UiTheme.label(text, 52, col)
	l.add_theme_constant_override("outline_size", 10)
	l.add_theme_color_override("font_outline_color", Color.BLACK)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.position = Vector2(0, 250)
	l.size = Vector2(1920, 70)
	scr._fx.add_child(l)
	var tw := l.create_tween()
	tw.tween_interval(life)
	tw.tween_property(l, "modulate:a", 0.0, 0.3)
	tw.tween_callback(l.queue_free)
