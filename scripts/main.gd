extends Node
## Screen flow: menu → starting relic → map → (loadout → fight → rewards | rest | treasure) → … → end.

## The rules live in the wiki (scripts/ui/wiki_screen.gd).

var screen_layer := CanvasLayer.new()
var overlay_layer := CanvasLayer.new()
var current: Control
var run: RunState


func _ready() -> void:
	overlay_layer.layer = 5
	add_child(screen_layer)
	add_child(overlay_layer)
	# your Amber, top-right on every screen while a run is going on
	var al := CanvasLayer.new()
	al.layer = 8
	var amber := AmberCounter.new()
	amber.get_run = func(): return run
	amber.position = Vector2(1920 - 24 - 140, 112)
	al.add_child(amber)
	add_child(al)
	var tl := CanvasLayer.new()
	tl.layer = 10
	var toasts: VBoxContainer = load("res://scripts/ui/toasts.gd").new()
	tl.add_child(toasts)
	add_child(tl)
	# New theme: every scroll area gets the painted, never-stretched thumb
	get_tree().node_added.connect(func(n: Node): if n is ScrollContainer: ScrollThumb.attach.call_deferred(n))
	show_menu()


## The room whose painted background the screens use (Backdrop.room): set when a room is entered, cleared on the map / menu.
var _room_bg := ""
const EVENT_BG := {"well": "event_whispering_well", "lost_sprite": "event_lost_sprite",
	"mushroom_ring": "event_mushroom_ring", "hollow_stump": "event_hollow_stump", "bard": "event_travelling_bard",
	"cursed_shrine": "event_cursed_shrine", "amber_vein": "event_golden_thicket", "old_tome": "event_old_spellbook",
	"squirrel": "event_squirrel_merchant", "tinker": "event_tinker_cart", "barterer": "event_barterer",
	"lost_camp": "event_abandoned_camp", "apothecary": "event_wandering_apothecary"}
const BOSS_BG := ["", "boss_woodcutter", "boss_blightmother", "boss_last_winter"]  # by act


func _swap(c: Control) -> void:
	Backdrop.room = _room_bg
	if is_instance_valid(current):
		current.queue_free()
	current = c
	screen_layer.add_child(c)


func show_menu() -> void:
	_room_bg = ""
	Audio.play_music("menu")
	var m := MenuScreen.new()
	m.play.connect(_new_run)
	m.continue_run.connect(continue_run)
	m.codex.connect(open_codex)
	m.unlocks.connect(func():
		Audio.play("ui_open_panel")
		var u := UnlockScreen.new()
		u.closed.connect(func(): u.queue_free(); show_menu())
		overlay_layer.add_child(u))
	m.how_to.connect(open_wiki)
	m.tutorial.connect(start_tutorial)
	m.test_mode.connect(open_test_mode)
	m.settings.connect(open_settings)
	_swap(m)


func open_settings() -> void:
	Audio.play("ui_open_panel")
	var s := SettingsScreen.new()
	s.closed.connect(s.queue_free)
	overlay_layer.add_child(s)


## Tutorial mode: one scripted fight with a coach.
func start_tutorial() -> void:
	run = null
	var t := TutorialScreen.new()
	t.done.connect(func(): show_menu.call_deferred())
	_swap(t)


func open_wiki() -> void:
	Audio.play("ui_open_panel")
	var w := WikiScreen.new()
	w.closed.connect(w.queue_free)
	overlay_layer.add_child(w)


# ------------------------------------------------------------------ pinned tooltips

var _pinned: CanvasLayer
var _pinned_owner: Control  # its hover tooltip is off while pinned
var _pinned_text := ""


## Right-click pins whatever tooltip is under the mouse; any click closes it again.
func _input(ev: InputEvent) -> void:
	if not (ev is InputEventMouseButton) or not ev.pressed:
		return
	if is_instance_valid(_pinned):
		_pinned.queue_free()
		_pinned = null
		if is_instance_valid(_pinned_owner):
			_pinned_owner.remove_meta("tip_pinned")
			# keyword text sets its own tooltip per hovered keyword, so it starts clean
			_pinned_owner.tooltip_text = "" if _pinned_owner is KeywordText else _pinned_text
		_pinned_owner = null
		if ev.button_index == MOUSE_BUTTON_RIGHT:
			get_viewport().set_input_as_handled()
			return
	if ev.button_index != MOUSE_BUTTON_RIGHT or _right_click_busy():
		return
	var c := get_viewport().gui_get_hovered_control()
	while c != null and c.tooltip_text == "":
		c = c.get_parent() as Control
	if c == null:
		return
	var content = c.call("_make_custom_tooltip", c.tooltip_text) if c.has_method("_make_custom_tooltip") else null
	if not (content is Control):
		content = Keywords.make_tooltip(Keywords.colorize(c.tooltip_text))
	_pin_tooltip(content)
	_pinned_owner = c
	_pinned_text = c.tooltip_text
	c.tooltip_text = ""
	c.set_meta("tip_pinned", true)  # keyword text checks this so hovering doesn't reopen its tooltip
	# close the hover tooltip that may already be showing: nudge the mouse so the viewport re-checks
	var m := get_viewport().get_mouse_position()
	get_viewport().warp_mouse(m + Vector2(1, 0))
	get_viewport().warp_mouse(m)
	get_viewport().set_input_as_handled()


## In a fight, right-click also means "put the spell back" / "skip": don't pin then.
func _right_click_busy() -> bool:
	var fs: FightScreen = null
	if current is FightScreen:
		fs = current
	elif current is TutorialScreen:
		fs = current.fs
	return fs != null and is_instance_valid(fs) and (fs.aiming or fs.move_view != null or fs.pick_view != null or fs.chant_mode != "")


func _pin_tooltip(content: Control) -> void:
	var layer := CanvasLayer.new()
	layer.layer = 30
	var p := PanelContainer.new()
	p.theme = UiTheme.get_theme()  # its layer is outside every screen: use the game's font, not Godot's default
	p.add_theme_stylebox_override("panel", UiTheme.get_theme().get_stylebox("panel", "TooltipPanel"))
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var v := VBoxContainer.new()
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_child(v)
	v.add_child(content)
	var hint := UiTheme.label("📌 Pinned · click anywhere to close", 15, UiTheme.MUTED)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	v.add_child(hint)
	layer.add_child(p)
	add_child(layer)
	_pinned = layer
	var at := get_viewport().get_mouse_position()
	p.position = at + Vector2(18, 18)
	await get_tree().process_frame
	if not is_instance_valid(p):
		return
	var vs := get_viewport().get_visible_rect().size
	p.position = Vector2(clampf(at.x + 18, 10, vs.x - p.size.x - 10), clampf(at.y + 18, 10, vs.y - p.size.y - 10))


func _unhandled_input(ev: InputEvent) -> void:
	if ev is InputEventKey and ev.pressed and not ev.echo and ev.keycode == KEY_F1:
		open_wiki()
		get_viewport().set_input_as_handled()


func open_codex() -> void:
	Audio.play("ui_open_panel")
	var c := CodexScreen.new()
	c.closed.connect(c.queue_free)
	overlay_layer.add_child(c)


func _message(title: String, body: String, buttons: Array, col := Color.WHITE, extra: Control = null) -> MessageScreen:
	var s := MessageScreen.new()
	s.extra = extra
	s.title = title
	s.body = body
	s.buttons = buttons
	s.title_color = col
	s.act = run.act if run else 1
	_swap(s)
	return s


# ------------------------------------------------------------------ run flow

## Test mode: the sandbox screen (your picks are kept between fights in _test_state). Nothing here touches the
## saved run, unlocks or stats.
var _test_state := {}


func open_test_mode() -> void:
	run = null
	_room_bg = ""
	Audio.play_music("menu")
	var t := TestModeScreen.new()
	t.setup(_test_state)
	t.back.connect(show_menu)
	t.fight_requested.connect(_test_fight)
	_swap(t)


## A test fight: the picked enemies against the picked spells, at full HP, then back to the test screen.
func _test_fight(ids: Array, spells: Array) -> void:
	var r := RunState.new()
	r.setup(GameData.db, [], [], 0)
	r.artifacts.clear()  # (no Seed of Life: it's a test)
	r.spellbook = spells.duplicate()
	r.loadout = spells.duplicate()
	var top_act := 1
	for id in ids:
		top_act = maxi(top_act, int(EnemyDefs.E[id].act))
	r.act = top_act
	r.row = 4
	r.encounter = ids.duplicate()
	r.encounter_extra = ids.map(func(id): return EnemyDefs.extra_for(id, top_act, r.depth(), r.rng, ids.size()))
	run = r
	var f := r.make_fight(ids)
	f.talk_free = true  # (test mode: a boss's talk costs no Essence)
	var fs := FightScreen.new()
	fs.setup(r, f)
	fs.finished.connect(func(_won): open_test_mode())
	fs.menu_requested.connect(open_test_mode)
	Audio.play_music("boss" if ids.any(func(id): return EnemyDefs.E[id].get("boss", false)) else "fight")
	_swap(fs)


## New run: the saved one (there's only ever one) is replaced, so ask first if there is one.
func _new_run() -> void:
	if not SaveManager.has_run():
		start_run()
		return
	var s := _message("Start a new run?", "You have a run in progress. Starting a new one replaces it: the saved run will be lost.", ["Start a new run", "Back"], UiTheme.DANGER)
	s.pressed.connect(func(i):
		if i == 0:
			SaveManager.clear_run()
			start_run()
		else:
			show_menu())


## Save the run where it stands (the map, or the start of a fight) so it can be continued later.
func _checkpoint(resume: String, ids: Array = []) -> void:
	if run == null or run.over:
		return
	SaveManager.save_run({"resume": resume, "ids": ids.duplicate(), "run": run.to_save()})


## Continue: the saved run, back where you left it (on the map, or at the start of the fight you were in).
func continue_run() -> void:
	var d := SaveManager.load_run()
	if d.is_empty():
		show_menu()
		return
	run = RunState.from_save(d.run, GameData.db)
	run.artifact_gained.connect(_on_artifact_found)
	if d.resume == "fight" and not d.ids.is_empty():
		_show_loadout(d.ids)
	else:
		show_map()


func start_run() -> void:
	_room_bg = ""
	run = RunState.new()
	run.artifact_gained.connect(_on_artifact_found)
	run.setup(GameData.db, SaveManager.unlocked_spells(), SaveManager.unlocked_artifacts())
	var offer := Artifacts.keepsakes(run.rng, 3)
	var ch := _choice("Choose a keepsake", "It stays with you for the whole run.", [], offer, false)
	ch.chosen.connect(func(i):
		run.gain_artifact(offer[i].id)
		show_map())


func show_map() -> void:
	_room_bg = ""
	_checkpoint("map")
	Audio.play_music("map")
	var m := MapScreen.new()
	m.setup(run)
	m.node_chosen.connect(_on_node)
	m.codex_pressed.connect(open_codex)
	m.menu_requested.connect(func(): run = null; show_menu())
	_swap(m)


func _on_node(col: int) -> void:
	var node := run.move_to(col)
	var kind: String = node.type
	if kind == "event":
		kind = run.resolve_unknown()
		if kind != "event":
			Events.toast.emit("The ? room holds… %s!" % MapScreen.LOOK[kind][1], Color(0.8, 0.7, 1))
	_enter_room(kind)


func _enter_room(kind: String) -> void:
	_room_bg = {"shop": "merchant_shop", "rest": "campfire_night", "treasure": "treasure_room"}.get(kind, "")
	match kind:
		"event":
			Audio.play("map_event_trigger")
			var ev := MapEvents.get_event(run.current_node().event)
			_room_bg = EVENT_BG.get(ev.get("id", ""), "")
			_show_event(ev)
		"shop":
			_show_shop(run.shop_stock())
		"rest":
			_show_rest()
		"treasure":
			var offer := run.treasure_offer()
			if offer.is_empty():
				_room_bg = "empty_hollow"
				var s := _message("An empty hollow", "Nothing left to find here.", ["Continue"])
				s.pressed.connect(func(_i): show_map())
				return
			var ch := _choice("Treasure", "Take one artifact. The red one is cursed: stronger, but it costs you.", [], offer, true)
			ch.chosen.connect(func(i):
				if i >= 0:
					run.gain_artifact(offer[i].id)
				show_map())
		_:
			_show_loadout(run.encounter_ids())


## A "?" event: its story and choices (options you can't afford are greyed out).
func _show_event(ev: Dictionary) -> void:
	var labels: Array = ev.options.map(func(o): return o.label)
	var s := _message(ev.title, ev.text, labels, Color(0.8, 0.7, 1))
	s.disabled = ev.options.map(func(o): return not run.can_choose(o))
	s.pressed.connect(func(i):
		match ev.options[i].get("do", ""):
			"upgrade_artifact":
				_tinker(ev.options[i])
				return
			"trade_artifacts":
				_barter()
				return
		var res: Dictionary = run.choose_event_option(ev.options[i])
		if run.player.is_dead():
			run.over = true
			_end_run()
			return
		var after := _message(ev.title, res.text, ["Fight!" if res.get("fight", false) else "Continue"], Color(0.8, 0.7, 1))
		after.pressed.connect(func(_k):
			if res.get("fight", false):
				run.current_node()["as"] = "fight"
				_show_loadout(run.encounter_ids())
			else:
				show_map()))


## The Tinker: pick an artifact (shown as it will be); pay and it becomes its + version. Skip: pay nothing.
## The Tinker: a random one of your artifacts becomes its + version.
func _tinker(opt: Dictionary) -> void:
	var ids := run.upgradable_artifacts()
	var id: String = ids[run.rng.randi() % ids.size()]
	run.amber -= opt.get("amber", 0)
	run.upgrade_artifact(id)
	var a := Artifacts.view(id, true)
	var done := _message("The Tinker's Cart", "The gnome tinkers with your %s.\n%s %s: %s" % [Artifacts.view(id).name, a.get("icon", ""), a.name, a.desc], ["Continue"], Color(0.8, 0.7, 1))
	done.pressed.connect(func(_i): show_map())


## The Barterer: pick two artifacts of the same tier, then one of 3 from the tier above. Skipping at any step
## cancels the trade.
func _barter() -> void:
	var first := run.tradeable_artifacts()
	var ch := _choice("Trade: first artifact", "Pick an artifact to give away. The second must be the same tier.", [], first.map(func(id): return Artifacts.view(id, id in run.artifacts_plus)), true)
	ch.chosen.connect(func(k):
		if k < 0 or k >= first.size():
			show_map()
			return
		var a: String = first[k]
		var tier: String = Artifacts.get_def(a).tier
		var second := run.tradeable_artifacts(tier).filter(func(id): return id != a)
		var ch2 := _choice("Trade: second artifact", "Pick a second %s artifact to give away." % Artifacts.TIER_NAMES[tier], [], second.map(func(id): return Artifacts.view(id, id in run.artifacts_plus)), true)
		ch2.chosen.connect(func(k2):
			if k2 < 0 or k2 >= second.size():
				show_map()
				return
			var b: String = second[k2]
			var offer := run.trade_offer(tier)
			var ch3 := _choice("Trade: your new artifact", "Take one. %s and %s go to the Barterer." % [Artifacts.get_def(a).name, Artifacts.get_def(b).name], [], offer, true)
			ch3.chosen.connect(func(k3):
				if k3 >= 0:
					run.trade_artifacts(a, b, offer[k3].id)
				show_map())))


func _show_shop(stock: Array) -> void:
	var sh := ShopScreen.new()
	sh.setup(run, stock)
	sh.leave.connect(show_map)
	sh.upgrade_requested.connect(func():
		var ids := run.upgradable()
		var cards := ids.map(func(id): return run.spell(id))
		var ch := _choice("A wax seal", "Choose a spell. Then choose which Essence of its pattern to seal: it won't be needed any more.", cards, [], false)
		ch.chosen.connect(func(k):
			if k < 0:
				_show_shop(stock)
				return
			var seal := SealScreen.new()
			seal.setup(run, ids[k])
			seal.done.connect(func(): _show_shop(stock))
			_swap(seal)))
	_swap(sh)


func _show_loadout(ids: Array) -> void:
	_room_bg = "screen_loadout"
	_checkpoint("fight", ids)
	var l := LoadoutScreen.new()
	l.setup(run, ids)
	l.confirmed.connect(func(): _start_fight(ids))
	l.codex_pressed.connect(open_codex)
	_swap(l)


var _last_ids: Array = []  # the current fight's enemies (the Seed of Life starts it over)


func _start_fight(ids: Array) -> void:
	var fight_kind := run.current_kind()
	_room_bg = "elite_arena" if fight_kind == "elite" else (BOSS_BG[clampi(run.act, 1, 3)] if fight_kind == "boss" else "")
	_last_ids = ids.duplicate()
	_checkpoint("fight", ids)  # (with the spells you just chose)
	var f := run.make_fight(ids)
	var fs := FightScreen.new()
	fs.setup(run, f)
	fs.run_saved = true
	fs.finished.connect(func(_won): _after_fight(f))
	fs.menu_requested.connect(func(): run = null; show_menu())
	Audio.play_music("boss" if run.current_kind() == "boss" else "fight")
	_swap(fs)


## An artifact was picked up: its card (frame and picture) pops up in the middle of the screen for a moment (click to dismiss).
func _on_artifact_found(id: String) -> void:
	var ov := Control.new()
	ov.size = Vector2(1920, 1080)
	ov.mouse_filter = Control.MOUSE_FILTER_STOP
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.55)
	dim.size = Vector2(1920, 1080)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ov.add_child(dim)
	var box := VBoxContainer.new()
	box.size = Vector2(1920, 1080)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 18)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ov.add_child(box)
	var title := UiTheme.heading("You found an artifact!", 40, Color(1, 0.9, 0.55))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(row)
	var card := ArtifactCard.make(Artifacts.view(id, false))
	card.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(card)
	if run != null and run.curse_note != "":
		var curse := UiTheme.label("CURSE: " + run.curse_note, 22, UiTheme.DANGER)
		curse.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		curse.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		curse.custom_minimum_size = Vector2(900, 0)
		curse.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		box.add_child(curse)
	var hint := UiTheme.label("Click to continue", 18, UiTheme.MUTED)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(hint)
	overlay_layer.add_child(ov)
	Audio.play("artifact_get")
	ov.modulate.a = 0.0
	card.pivot_offset = Vector2(ArtifactCard.W / 2.0, 120.0)
	card.scale = Vector2(0.7, 0.7)
	var pop := ov.create_tween().set_parallel(true)
	pop.tween_property(ov, "modulate:a", 1.0, 0.18)
	pop.tween_property(card, "scale", Vector2.ONE, 0.28).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	var close := func():
		if not is_instance_valid(ov) or ov.has_meta("closing"):
			return
		ov.set_meta("closing", true)
		var tw := ov.create_tween()
		tw.tween_property(ov, "modulate:a", 0.0, 0.2)
		tw.tween_callback(ov.queue_free)
	ov.gui_input.connect(func(ev: InputEvent): if ev is InputEventMouseButton and ev.pressed: close.call())
	card.clicked.connect(close)
	get_tree().create_timer(4.0).timeout.connect(close)


## Your HP bar (the one from fights) with the numbers beside it.
func _hp_box() -> Control:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 12)
	var heart := UiSkin.icon("icon_heart", 30)
	if heart != null:
		heart.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		h.add_child(heart)
	var bar := HpBar.new()
	bar.custom_minimum_size = Vector2(460, 26)
	bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	bar.set_values(run.player.hp, run.player.max_hp, 0.0)
	h.add_child(bar)
	h.add_child(UiTheme.label("%d / %d" % [run.player.hp, run.player.max_hp], 24, Color.WHITE))
	return h


## Campfire: rest to heal, or fuse two spells into one.
func _show_rest() -> void:
	_room_bg = "campfire_night"
	var heal := int(run.player.max_hp * RunState.REST_HEAL)
	var can_fuse := run.fusable().size() >= 2
	if UiSkin.tex("campfire_bg") != null:  # New theme: the painted campfire, where you click what you want to do
		var cs := CampfireScreen.new()
		cs.setup(run)
		cs.enabled = {"fuse": can_fuse, "rest": true}
		cs.hints = {  # (what the signboard's second board says: short, it is a small board)
			"rest": "Rest: heal %d HP\n(you have %d / %d)" % [heal, run.player.hp, run.player.max_hp],
			"fuse": "Fuse two spells into\none stronger spell" if can_fuse else "You need two\nspells to fuse",
		}
		cs.extra = _hp_box()
		cs.chosen.connect(func(which: String): _campfire_choice({"rest": 0, "fuse": 1}[which]))
		_swap(cs)
		return
	var s := _message("A campfire", "Rest (heal %d HP, you have %d / %d), or Fuse two of your spells into one stronger spell." % [heal, run.player.hp, run.player.max_hp], ["Rest  (+%d HP)" % heal, "Fuse two spells"], Color(1, 0.75, 0.45), _hp_box())
	s.disabled = [false, not can_fuse]
	s.pressed.connect(_campfire_choice)


## What you chose at the campfire: 0 rest, 1 fuse two spells.
func _campfire_choice(i: int) -> void:
	if i == 0:
		run.rest()
		Audio.play("rest_heal")
		show_map()
		return
	var fs := FuseScreen.new()
	fs.setup(run)
	_room_bg = "campfire_fuse"
	fs.back.connect(_show_rest)
	fs.fused.connect(func(_sp): show_map())  # (the fuse screen showed the new spell and its wax seal)
	_swap(fs)


## Rewards: normal fights 3 cards (70% common, 30% rare); elites 3 rares and an artifact;
## bosses 3 legendaries and a relic that raises your element income.
func _after_fight(f: Fight) -> void:
	_room_bg = "screen_reward"
	var kind := run.current_kind()
	if not (kind in ["fight", "elite", "boss"]):
		kind = "fight"
	for id in SaveManager.add_to_codex(f.defeated):
		Events.toast.emit("New Codex entry: %s" % EnemyDefs.get_def(id).name, Color(1, 0.9, 0.5))
	var act_before := run.act
	if not f.won and run.can_revive():
		# the Seed of Life: back to the start of this fight's preparation, as you were going in
		run.revive()
		Events.toast.emit("The Seed of Life gives you a second chance", Color(0.75, 1.0, 0.6))
		_show_loadout(_last_ids)
		return
	run.finish_fight(f)
	if run.over:
		_end_run()
		return
	if run.reward_bottle != "":
		var bd := Bottles.get_def(run.reward_bottle)
		Events.toast.emit("Found a bottle: %s %s" % [UiSkin.icon_token(run.reward_bottle, bd.icon), bd.name], Color(0.7, 0.95, 1))
	var steps: Array = []  # callables, each shows one screen and then calls the next
	var offer := run.spell_offer(3, kind)
	var title: String = {"fight": "Victory", "elite": "The elite falls: rare spells", "boss": "The boss falls: legendary spells"}.get(kind, "Victory")
	if not offer.is_empty():
		steps.append(func(go):
			var ch := _choice(title, "Learn one spell. It goes into your spellbook, and into your active row if there's room.", offer, [], true)
			ch.chosen.connect(func(i):
				if i >= 0:
					run.learn_spell(offer[i].id)
				go.call()))
	if kind == "elite":
		var ao := run.artifact_offer(3)
		if not ao.is_empty():
			steps.append(func(go):
				var ch := _choice("The elite dropped a relic", "Take one artifact.", [], ao, true)
				ch.chosen.connect(func(i):
					if i >= 0:
						run.gain_artifact(ao[i].id)
					go.call()))
	if kind == "boss":
		var relics := run.boss_relic_offer()
		if not relics.is_empty():
			steps.append(func(go):
				var ch := _choice("Legendary relic", "Only bosses drop these: more Essence every turn, or more spell slots.", [], relics, false)
				ch.chosen.connect(func(i):
					run.gain_artifact(relics[i].id)
					go.call()))
	if run.act != act_before:
		steps.append(func(go):
			var s := _message("Act %d cleared" % act_before, "You heal half your HP and press deeper into the wood.", ["Onward"], Color(0.9, 0.7, 1))
			s.pressed.connect(func(_i): go.call()))
	_run_steps(steps, 0)


func _run_steps(steps: Array, i: int) -> void:
	if i >= steps.size():
		show_map()
		return
	steps[i].call(func(): _run_steps.call_deferred(steps, i + 1))


func _choice(title: String, sub: String, spells: Array, arts: Array, can_skip: bool) -> ChoiceScreen:
	var c := ChoiceScreen.new()
	c.title = title
	c.subtitle = sub
	c.spells = spells
	c.artifacts = arts
	c.can_skip = can_skip
	c.act = run.act
	c.chosen.connect(func(i):
		if i >= 0:
			Audio.play("artifact_get" if not arts.is_empty() else "discovery_unlock"))
	_swap(c)
	return c


func _end_run() -> void:
	_room_bg = "" if run.won else "screen_defeat"  # (no victory picture yet: the act's)
	var seeds := run.final_seedlings()
	Audio.play("victory_fanfare" if run.won else "defeat_stinger")
	Audio.play("seedling_gain")
	Audio.stop_music()
	SaveManager.record_run(seeds, run.act, run.kills, run.won)
	SaveManager.clear_run()  # the run is over: nothing to continue
	var title := "The last tree stands!" if run.won else "The last tree has fallen"
	var body := "Act %d reached · %d enemies defeated · %d spells learned\n+%d Seedlings (spend them on Unlocks)." % [run.act, run.kills, run.spellbook.size() - 4, seeds]
	var s := _message(title, body, ["Play again", "Main menu"], Color(0.6, 1, 0.5) if run.won else UiTheme.DANGER)
	s.pressed.connect(func(i):
		if i == 0:
			start_run()
		else:
			run = null
			show_menu())
