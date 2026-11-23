class_name TestFlow
extends RefCounted
## Moved out of scripts/main.gd (docs/plan_dot3_kien_truc.md): the code is unchanged except that main's own members are reached through `main.`.

var main: Main


func _init(p_main: Main) -> void:
	main = p_main


var _test_room := {}  # the Room Test room that was entered last ({type, act, ...})
var _rope_sets: Array = []
var _rope_i := 0
var _rope_busy := false
## Test mode: the sandbox screen (your picks are kept between fights in _test_state). Nothing here touches the
## saved run, unlocks or stats.
var _test_state := {}
func open_test_mode() -> void:
	main.run = null
	main._room_bg = ""
	Audio.play_music("menu")
	var t := TestModeScreen.new()
	t.setup(_test_state)
	t.back.connect(main.show_menu)
	t.fight_requested.connect(func(ids, spells, artifacts, bottles): _test_fight(ids, spells, Callable(), artifacts, bottles))
	t.event_requested.connect(_test_event)
	t.custom_requested.connect(_test_custom)
	main._swap(t)


func _test_event(id: String) -> void:
	main._test_mode = true
	main._test_back_to_tabs = true
	main.run = RunState.new()
	main.run.artifact_gained.connect(main._on_artifact_found)
	main.run.setup(GameData.db, SaveManager.unlocked_spells(), SaveManager.unlocked_artifacts())
	main.run.amber = 999  # (so every option can be tried)
	for a in ["thornbark", "wind_chime", "ember_charm"]:  # (and something to give away: the Mystery Shed, the Recycler)
		if not (a in main.run.artifacts):
			main.run.artifacts.append(a)
	if id == "merchant":  # (the merchant is a room, not one of the "?" events: Test mode lists him with them; as on the real map, over the stage)
		main._test_stage_shop = UiSkin.is_puppet()
		if main._test_stage_shop:
			var base := main._new_fight_screen(main.run.make_fight([]))
			base.map_mode = true
			main._swap(base)
		_enter_test_room({"type": "shop", "act": 1, "row": 3})
		return
	_enter_test_room({"type": "event", "act": 1, "row": 3, "event": id})


## Test mode's Custom tab: hand-made test scenes.
func _test_custom(id: String) -> void:
	var spells: Array = _test_state.get("spells", ["fire_ball", "water_wall", "tailwind"])
	match id:
		"armadillo_fight":
			_test_fight(["anxious_armadillo"], spells)
		"armadillo_end":
			# he starts with a single Essence: one chant, and his ending plays
			_test_fight(["anxious_armadillo"], spells, func(f: Fight): f.enemies[0].reset_hp("F"))


## A test fight: the picked enemies against the picked spells, at full HP, then back to the test screen.
func _test_fight(ids: Array, spells: Array, tweak := Callable(), artifacts := [], bottles := []) -> void:
	var r := RunState.new()
	r.setup(GameData.db, [], [], 0)
	r.artifacts = artifacts.duplicate()  # (no Seed of Life unless picked: it's a test)
	r.player.bottles = bottles.duplicate()
	r.spellbook = spells.duplicate()
	r.loadout = spells.duplicate()
	var top_act := 1
	for id in ids:
		top_act = maxi(top_act, int(EnemyDefs.E[id].act))
	r.act = top_act
	r.row = 4
	r.encounter = ids.duplicate()
	r.encounter_extra = ids.map(func(id): return EnemyDefs.extra_for(id, top_act, r.depth(), r.rng, ids.size()))
	main.run = r
	var f := r.make_fight(ids)
	f.talk_free = true  # (test mode: a boss's talk costs no Essence)
	if tweak.is_valid():
		tweak.call(f)
	var fs := FightScreen.new()
	fs.setup(r, f)
	fs.test_mode = true  # (Auto-fill and Auto-ball buttons)
	fs.finished.connect(func(_won): open_test_mode())
	fs.menu_requested.connect(open_test_mode)
	Audio.play_music(main._fight_music(ids))
	main._swap(fs)


## Every room of the game, in the order they appear on the Room Test map.
func _test_rooms() -> Array:
	var out: Array = []
	for a in [1, 2, 3]:
		out.append({"type": "fight", "label": "Fight · Act %d" % a, "act": a, "row": 5})
	for a in [1, 2, 3]:
		out.append({"type": "elite", "label": "Elite · Act %d" % a, "act": a, "row": 8})
	for a in [1, 2, 3]:
		out.append({"type": "boss", "label": "Boss · Act %d" % a, "act": a, "row": MapGen.FLOORS})
	for t in [["treasure", "Treasure"], ["shop", "Merchant"]]:
		out.append({"type": t[0], "label": t[1], "act": 1, "row": 3})
	for ev in MapEvents.ALL:
		out.append({"type": "event", "label": ev.title, "act": 1, "row": 3, "event": ev.id})
	return out


func start_room_test() -> void:
	main._test_mode = true
	main.run = RunState.new()
	main.run.artifact_gained.connect(main._on_artifact_found)
	main.run.setup(GameData.db, SaveManager.unlocked_spells(), SaveManager.unlocked_artifacts())
	main.run.amber = 999  # (so shops and events can be tried)
	show_room_test()


func show_room_test() -> void:
	main._room_bg = ""
	Audio.play_music("map")
	var m := MapScreen.new()
	m.setup(main.run)
	m.test_rooms = _test_rooms()
	m.test_room_chosen.connect(_enter_test_room)
	m.codex_pressed.connect(main.open_codex)
	m.menu_requested.connect(func(): main.run = null; main.show_menu())
	main._swap(m)


## Go straight into a room: the run is put on a one-room map that holds just that room.
func _enter_test_room(room: Dictionary) -> void:
	_test_room = room
	main.run.over = false
	main.run.won = false
	main.run.player.hp = main.run.player.max_hp
	main.run.act = room.act
	var rows: Array = []
	for f in MapGen.FLOORS + 1:
		var r := []
		r.resize(MapGen.COLS)
		rows.append(r)
	rows[room.row][0] = {"type": room.type, "next": [], "col": 0, "event": room.get("event", "")}
	main.run.map = rows
	main.run.row = room.row
	main.run.col = 0
	main._enter_room(room.type)


## F5 in a Room Test fight / elite / boss room (the Puppet Stage theme): the enemies of that room type and act stand on the stage in sets of four and
## can be hung from the ceiling on ropes (RopeEditor). F5 again goes back to the room map.
func _toggle_rope_mode() -> void:
	if not main._test_mode or _rope_busy:
		return
	if main._rope_active:
		show_room_test()
		return
	if not UiSkin.is_puppet() or not (_test_room.get("type", "") in ["fight", "elite", "boss"]):
		Events.toast.emit("F5 (rope mode) works in a Room Test fight, elite or boss room, in the Puppet theme.", Color(1, 0.85, 0.5))
		return
	if not (main.current is LoadoutScreen or main.current is FightScreen):
		return
	_rope_sets = RopeSets.build(_test_room.type, int(_test_room.act))
	if _rope_sets.is_empty():
		Events.toast.emit("No puppet with a picture in this room type.", Color(1, 0.85, 0.5))
		return
	_rope_i = 0
	main._rope_active = true
	_show_rope_set()


func _show_rope_set() -> void:
	var ids: Array = _rope_sets[_rope_i]
	var kind: String = _test_room.type
	main._room_bg = "elite_arena" if kind == "elite" else (main.BOSS_BG[clampi(main.run.act, 1, 3)] if kind == "boss" else "")
	var f := main.run.make_fight(ids.map(RopeSets.real_id))
	var painted := []  # (a black Yin Yang Beast / Cub of the set: the first white one of that id turns black, before its picture is chosen)
	for k in ids.size():
		if RopeSets.is_black(ids[k]):
			for e in f.enemies:
				if e.id == RopeSets.real_id(ids[k]) and e.yin == "white" and not (e in painted):
					e.yin = "black"
					painted.append(e)
					break
	var phased := []  # (the Veiled Eyes' second phase: the first of that id stands as the spider)
	for k in ids.size():
		if RopeSets.is_phase2(ids[k]):
			for e in f.enemies:
				if e.id == RopeSets.real_id(ids[k]) and e.phase < 2 and not (e in phased):
					e.phase = 2
					phased.append(e)
					break
	var fs := main._new_fight_screen(f)
	fs.rope_mode = true
	fs.arrive = true
	if main.current is FightScreen and main.current.rope_mode and main.current.get_stage() != null:
		fs.stage_in = main.current.get_stage()  # (the same theatre and scenery: only the enemies change)
	var ed := RopeEditor.new()
	ed.setup(fs, _rope_i, _rope_sets.size(), ids, kind, int(_test_room.act))
	ed.next_pressed.connect(_next_rope_set)
	fs.add_child(ed)
	main._rope_active = true
	main._swap(fs)
	main._rope_active = true  # (_swap looks at the screen before it is ready)


func _next_rope_set() -> void:
	if _rope_busy or not main._rope_active or not (main.current is FightScreen):
		return
	_rope_busy = true
	await main.current.rope_leave()
	_rope_i = (_rope_i + 1) % _rope_sets.size()
	if main._rope_active:
		_show_rope_set()
	_rope_busy = false
