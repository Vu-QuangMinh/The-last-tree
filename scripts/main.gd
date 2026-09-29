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
	Audio.play_music("menu")
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
	var offer := Artifacts.offer(Artifacts.ALL.filter(func(a): return a.starter).map(func(a): return a.id), [], run.rng, 3)
	var ch := _choice("Choose a keepsake", "It stays with you for the whole run.", [], offer, false)
	ch.chosen.connect(func(i):
		run.gain_artifact(offer[i].id)
		show_map())


func show_map() -> void:
	Audio.play_music("map")
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
		var ups := ids.map(func(id): return SpellDB.upgrade(run.db.get_spell(id)))
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
	Audio.play_music("boss" if run.current_kind() == "boss" else "fight")
	_swap(fs)


## Rest site: heal, or upgrade one spell for the rest of the run.
func _show_rest() -> void:
	var heal := int(run.player.max_hp * RunState.REST_HEAL)
	var s := _message("A quiet clearing", "Rest (heal %d HP, you have %d / %d), or spend the time studying one of your spells." % [heal, run.player.hp, run.player.max_hp], ["Rest  (+%d HP)" % heal, "Upgrade a spell"], Color(0.6, 1, 0.6))
	s.pressed.connect(func(i):
		if i == 0:
			run.rest()
			Audio.play("rest_heal")
			show_map()
			return
		var ids := run.upgradable()
		if ids.is_empty():
			run.rest()
			Audio.play("rest_heal")
			show_map()
			return
		var ups := ids.map(func(id): return SpellDB.upgrade(run.db.get_spell(id)))
		var ch := _choice("Upgrade a spell", "Its + version replaces it for the rest of the run.", ups, [], true)
		ch.chosen.connect(func(k):
			if k >= 0:
				run.upgrade_spell(ids[k])
				Events.toast.emit("%s upgraded" % ups[k].name, UiTheme.ACCENT)
			else:
				run.rest()
			show_map()))


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
				var ch := _choice("Heart of the boss", "A relic that gives you more elements every turn.", [], relics, false)
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
