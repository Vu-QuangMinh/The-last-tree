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
	var tl := CanvasLayer.new()
	tl.layer = 10
	var toasts: VBoxContainer = load("res://scripts/ui/toasts.gd").new()
	tl.add_child(toasts)
	add_child(tl)
	show_menu()


func _swap(c: Control) -> void:
	if is_instance_valid(current):
		current.queue_free()
	current = c
	screen_layer.add_child(c)


func show_menu() -> void:
	Audio.play_music("music_menu")
	var m := MenuScreen.new()
	m.play.connect(start_run)
	m.codex.connect(open_codex)
	m.unlocks.connect(func():
		Audio.play("ui_open_panel")
		var u := UnlockScreen.new()
		u.closed.connect(func(): u.queue_free(); show_menu())
		overlay_layer.add_child(u))
	m.how_to.connect(open_wiki)
	m.tutorial.connect(start_tutorial)
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


func _message(title: String, body: String, buttons: Array, col := Color.WHITE) -> MessageScreen:
	var s := MessageScreen.new()
	s.title = title
	s.body = body
	s.buttons = buttons
	s.title_color = col
	s.act = run.act if run else 1
	_swap(s)
	return s


# ------------------------------------------------------------------ run flow

func start_run() -> void:
	run = RunState.new()
	run.setup(GameData.db, SaveManager.unlocked_spells(), SaveManager.unlocked_artifacts())
	var offer := Artifacts.keepsakes(run.rng, 3)
	var ch := _choice("Choose a keepsake", "It stays with you for the whole run.", [], offer, false)
	ch.chosen.connect(func(i):
		run.gain_artifact(offer[i].id)
		show_map())


func show_map() -> void:
	Audio.play_music("music_map")
	var m := MapScreen.new()
	m.setup(run)
	m.node_chosen.connect(_on_node)
	m.codex_pressed.connect(open_codex)
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
	match kind:
		"event":
			Audio.play("map_event_trigger")
			_show_event(MapEvents.get_event(run.current_node().event))
		"shop":
			_show_shop(run.shop_stock())
		"rest":
			_show_rest()
		"treasure":
			var offer := run.treasure_offer()
			if offer.is_empty():
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


func _show_shop(stock: Array) -> void:
	var sh := ShopScreen.new()
	sh.setup(run, stock)
	sh.leave.connect(show_map)
	sh.upgrade_requested.connect(func():
		var ids := run.upgradable()
		var ups := ids.map(func(id): return SpellDB.upgrade(run.spell(id)))
		var ch := _choice("Upgrade a spell", "Its + version replaces it for the rest of the run.", ups, [], false)
		ch.chosen.connect(func(k):
			if k >= 0:
				run.upgrade_spell(ids[k])
			_show_shop(stock)))
	_swap(sh)


func _show_loadout(ids: Array) -> void:
	var l := LoadoutScreen.new()
	l.setup(run, ids)
	l.confirmed.connect(func(): _start_fight(ids))
	l.codex_pressed.connect(open_codex)
	_swap(l)


func _start_fight(ids: Array) -> void:
	var f := run.make_fight(ids)
	var fs := FightScreen.new()
	fs.setup(run, f)
	fs.finished.connect(func(_won): _after_fight(f))
	fs.menu_requested.connect(func(): run = null; show_menu())
	Audio.play_music("music_boss" if run.current_kind() == "boss" else "music_fight")
	_swap(fs)


## Campfire: rest to heal, or fuse two spells into one.
func _show_rest() -> void:
	var heal := int(run.player.max_hp * RunState.REST_HEAL)
	var can_fuse := run.fusable().size() >= 2
	var s := _message("A campfire", "Rest (heal %d HP, you have %d / %d), or Fuse two of your spells into one stronger spell." % [heal, run.player.hp, run.player.max_hp], ["Rest  (+%d HP)" % heal, "Fuse two spells"], Color(1, 0.75, 0.45))
	s.disabled = [false, not can_fuse]
	s.pressed.connect(func(i):
		if i == 0:
			run.rest()
			Audio.play("rest_heal")
			show_map()
			return
		var fs := FuseScreen.new()
		fs.setup(run)
		fs.back.connect(_show_rest)
		fs.fused.connect(func(sp):
			Events.toast.emit("Forged %s" % sp.name, Color(1, 0.8, 0.5))
			show_map())
		_swap(fs))


## Rewards: normal fights 3 cards (70% common, 30% rare); elites 3 rares and an artifact;
## bosses 3 legendaries and a relic that raises your element income.
func _after_fight(f: Fight) -> void:
	var kind := run.current_kind()
	if not (kind in ["fight", "elite", "boss"]):
		kind = "fight"
	for id in SaveManager.add_to_codex(f.defeated):
		Events.toast.emit("New Codex entry: %s" % EnemyDefs.get_def(id).name, Color(1, 0.9, 0.5))
	var act_before := run.act
	run.finish_fight(f)
	if run.over:
		_end_run()
		return
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
				var ch := _choice("Legendary relic", "Only bosses drop these: more elements every turn, or more spell slots.", [], relics, false)
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
	var seeds := run.final_seedlings()
	Audio.play("victory_fanfare" if run.won else "defeat_stinger")
	Audio.play("seedling_gain")
	Audio.stop_music()
	SaveManager.record_run(seeds, run.act, run.kills, run.won)
	var title := "The last tree stands!" if run.won else "The last tree has fallen"
	var body := "Act %d reached · %d enemies defeated · %d spells learned\n+%d Seedlings (spend them on Unlocks)." % [run.act, run.kills, run.spellbook.size() - 4, seeds]
	var s := _message(title, body, ["Play again", "Main menu"], Color(0.6, 1, 0.5) if run.won else UiTheme.DANGER)
	s.pressed.connect(func(i):
		if i == 0:
			start_run()
		else:
			run = null
			show_menu())
