extends Node
## Screen flow: menu → starting relic → map → (loadout → fight → rewards | rest | treasure) → … → end.

## The rules live in the wiki (scripts/ui/wiki_screen.gd).

var screen_layer := CanvasLayer.new()
var overlay_layer := CanvasLayer.new()
var current: Control
var run: RunState
var _test_mode := false  # Dev Mode "Room Test": a throwaway run, nothing is saved or recorded
var _back_layer := CanvasLayer.new()  # the "Back to room map" button of a test room
var _test_room := {}  # the Room Test room that was entered last ({type, act, ...})
var _rope_active := false  # Room Test, F5: the rope mode is up (see RopeEditor)
var _rope_sets: Array = []
var _rope_i := 0
var _rope_busy := false


func _ready() -> void:
	# the game starts full screen (F11 toggles it); a test or tool run keeps its own small window
	var args := OS.get_cmdline_args()
	if not ("-s" in args or "--script" in args or "--headless" in args or DisplayServer.get_name() == "headless"):
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	overlay_layer.layer = 5
	UiSkin.apply_clear_color()
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
	var cur := CanvasLayer.new()  # the Puppet Stage's wooden arrow pointer, over everything
	cur.layer = 128
	var wood_cursor := WoodCursor.new()
	wood_cursor.get_screen = func(): return current
	cur.add_child(wood_cursor)
	add_child(cur)
	var tl := CanvasLayer.new()
	tl.layer = 10
	var toasts: VBoxContainer = load("res://scripts/ui/toasts.gd").new()
	tl.add_child(toasts)
	add_child(tl)
	_back_layer.layer = 9
	_back_layer.visible = false
	var back := UiTheme.button("Back", func(): show_map(), 18)  # (to the room map, or to test mode's Events tab)
	back.theme = UiTheme.get_theme()  # (this layer is outside every screen)
	back.custom_minimum_size = Vector2(240, 44)
	back.position = Vector2(24, 120)
	_back_layer.add_child(back)
	add_child(_back_layer)
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
	_rope_active = _rope_active and c is FightScreen and c.rope_mode
	screen_layer.add_child(c)
	_back_layer.visible = _test_mode and not (c is MapScreen)


func show_menu() -> void:
	_test_mode = false
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
	m.room_test.connect(start_room_test)
	m.sfx_test.connect(open_sfx_test)
	_swap(m)


func open_settings() -> void:
	Audio.play("ui_open_panel")
	var s := SettingsScreen.new()
	var dev_before: bool = SaveManager.setting("dev_mode", false)
	s.closed.connect(func():
		s.queue_free()
		if current is MenuScreen and SaveManager.setting("dev_mode", false) != dev_before:
			show_menu())  # (the Dev buttons appear or go)
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
	if ev is InputEventKey and ev.pressed and not ev.echo and ev.keycode == KEY_F5:
		_toggle_rope_mode()
		get_viewport().set_input_as_handled()
		return
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
	if _rope_active:
		return true  # (right click takes a rivet away)
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
	p.add_theme_stylebox_override("panel", StyleBoxEmpty.new() if content.has_meta("bare") else UiTheme.get_theme().get_stylebox("panel", "TooltipPanel"))
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
	if ev is InputEventKey and ev.pressed and not ev.echo and ev.keycode == KEY_F11:
		var full := DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED if full else DisplayServer.WINDOW_MODE_FULLSCREEN)
		get_viewport().set_input_as_handled()
	if ev is InputEventKey and ev.pressed and not ev.echo and ev.keycode == KEY_F1:
		open_wiki()
		get_viewport().set_input_as_handled()


func open_codex() -> void:
	Audio.play("ui_open_panel")
	var c := CodexScreen.new()
	c.closed.connect(c.queue_free)
	overlay_layer.add_child(c)


## Puppet Stage: the run stays on the stage between fights. While the stage is up with its HUD sunk (after a fight, or in a map-mode screen) the
## rewards, the map board, the encounter and the spellbook are laid over it instead of replacing it.
var _overlay: Control
var _book_overlay: Control


func _stage_flow() -> bool:
	return UiSkin.is_puppet() and not _test_mode


func _on_stage() -> bool:
	return _stage_flow() and is_instance_valid(current) and current is FightScreen and (current.map_mode or current._hud_hidden())


func _set_overlay(c: Control) -> void:
	if is_instance_valid(_overlay):
		_overlay.queue_free()
	_overlay = c
	c.z_index = PuppetStage.CEILING_Z + 2  # (over the ceiling's valance)
	current.add_child(c)


## A screen of the run: on the stage if it is up, else a plain swap.
func _put(c: Control) -> void:
	if _on_stage():
		if "on_stage" in c:
			c.on_stage = true
		_set_overlay(c)
	else:
		_swap(c)


func _open_spellbook() -> void:
	if not (is_instance_valid(current) and current is FightScreen) or is_instance_valid(_book_overlay):
		return
	var l := LoadoutScreen.new()
	l.setup(run, [])
	l.on_stage = true
	l.book_only = true
	var under := _overlay  # (the map board or the rewards under it step aside while the book is open)
	if is_instance_valid(under):
		under.visible = false
	l.closed.connect(func():
		l.queue_free()
		if is_instance_valid(under):
			under.visible = true)
	l.codex_pressed.connect(open_codex)
	l.z_index = PuppetStage.CEILING_Z + 3
	current.add_child(l)
	_book_overlay = l


func _message(title: String, body: String, buttons: Array, col := Color.WHITE, extra: Control = null) -> MessageScreen:
	var s := MessageScreen.new()
	s.extra = extra
	s.title = title
	s.body = body
	s.buttons = buttons
	s.title_color = col
	s.act = run.act if run else 1
	_put(s)
	return s


# ------------------------------------------------------------------ run flow

## SFX Test (Dev Mode): the samples of each sound, one is chosen as the official one.
func open_sfx_test() -> void:
	run = null
	_room_bg = ""
	Audio.play_music("menu")
	var t := SfxTestScreen.new()
	t.back.connect(show_menu)
	_swap(t)


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
	t.event_requested.connect(_test_event)
	t.custom_requested.connect(_test_custom)
	_swap(t)


## Test mode's Events tab: a throwaway run goes straight into that event; afterwards, back to the test screen.
var _test_back_to_tabs := false


func _test_event(id: String) -> void:
	_test_mode = true
	_test_back_to_tabs = true
	run = RunState.new()
	run.artifact_gained.connect(_on_artifact_found)
	run.setup(GameData.db, SaveManager.unlocked_spells(), SaveManager.unlocked_artifacts())
	run.amber = 999  # (so every option can be tried)
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
func _test_fight(ids: Array, spells: Array, tweak := Callable()) -> void:
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
	if tweak.is_valid():
		tweak.call(f)
	var fs := FightScreen.new()
	fs.setup(r, f)
	fs.test_mode = true  # (Auto-fill and Auto-ball buttons)
	fs.finished.connect(func(_won): open_test_mode())
	fs.menu_requested.connect(open_test_mode)
	Audio.play_music("boss" if ids.any(func(id): return EnemyDefs.E[id].get("boss", false)) else "fight")
	_swap(fs)


## New run: the saved one (there's only ever one) is replaced, so ask first if there is one.
func _new_run() -> void:
	if not SaveManager.has_run():
		start_run()
		return
	var body := "You have a run in progress. Starting a new one replaces it: the saved run will be lost."
	if _stage_flow() and is_instance_valid(current) and current is MenuScreen:
		# Puppet Stage: the pop-up is laid over the menu's own stage (no screen of its own)
		var m := MessageScreen.new()
		m.title = "Start a new run?"
		m.body = body
		m.buttons = ["Start a new run", "Back"]
		m.title_color = UiTheme.DANGER
		m.on_stage = true
		m.small_buttons = true
		m.z_index = PuppetStage.CEILING_Z + 2
		current.add_child(m)
		m.pressed.connect(func(i):
			if i == 0:
				SaveManager.clear_run()
				start_run()  # (the menu is swapped out there)
			else:
				m.queue_free())
		return
	var s := _message("Start a new run?", body, ["Start a new run", "Back"], UiTheme.DANGER)
	s.pressed.connect(func(i):
		if i == 0:
			SaveManager.clear_run()
			start_run()
		else:
			show_menu())


## Save the run where it stands (the map, or the start of a fight) so it can be continued later.
func _checkpoint(resume: String, ids: Array = []) -> void:
	if _test_mode or run == null or run.over:
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
	run.first_run = int(SaveManager.data.stats.get("runs", 0)) == 0 and not SaveManager.setting("armadillo_met", false)
	var offer := Artifacts.keepsakes(run.rng, 3)
	if _stage_flow():
		# Puppet Stage: the drapes are drawn over the stage, the three keepsakes are laid on it, then the map is let down
		var fs := _new_fight_screen(run.make_fight([]))
		fs.map_mode = true
		_swap(fs)
		var st: PuppetStage = fs.get_stage()
		if st != null and st.curtains.has_art():
			await get_tree().process_frame  # (the stage was just built: the drapes start once that frame is over, or their move would jump)
			await get_tree().process_frame
			await st.curtains.close()
		if current != fs or run == null:  # (left for the menu meanwhile)
			return
	var ch := _choice("Choose a keepsake", "It stays with you for the whole run.", [], offer, false)
	ch.chosen.connect(func(i):
		_pick_artifact(offer[i].id)
		show_map())


func show_map() -> void:
	if _test_mode and _test_back_to_tabs:
		_test_back_to_tabs = false  # (an event from test mode's Events tab: back to it)
		_test_mode = false
		open_test_mode()
		return
	if _test_mode:
		show_room_test()
		return
	_room_bg = ""
	_checkpoint("map")
	Audio.play_music("map")
	if _stage_flow():
		_show_stage_map()
		return
	var m := MapScreen.new()
	m.setup(run)
	m.node_chosen.connect(_on_node)
	m.codex_pressed.connect(open_codex)
	m.menu_requested.connect(func(): run = null; show_menu())
	_swap(m)


## Puppet Stage: the map is a wooden board that rises over the stage (over the one of the fight that was just won, or over a fresh stage).
func _show_stage_map() -> void:
	if not _on_stage():
		var fs := _new_fight_screen(run.make_fight([]))
		fs.map_mode = true
		_swap(fs)
	var m := MapScreen.new()
	m.on_stage = true
	m.setup(run)
	var st: PuppetStage = current.get_stage() if is_instance_valid(current) and current is FightScreen else null
	var draw_drapes: bool = st != null and st.curtains.has_art() and not st.curtains.is_shut()  # (a new run: they were drawn for the keepsakes already)
	if draw_drapes:  # the red drapes are drawn together over the stage, and the map is let down in front of them
		m.drop_delay = 2.6  # (as long as the drapes take to close, and the two frames they wait)
	m.node_chosen.connect(func(col: int):
		await m.lower()  # (the map is pulled all the way up first, then the drapes are pulled apart)
		if st != null and is_instance_valid(st) and st.curtains.has_art():
			await st.curtains.open()
		_on_node(col))
	m.codex_pressed.connect(open_codex)
	m.menu_requested.connect(func(): run = null; show_menu())
	_set_overlay(m)
	if draw_drapes:  # (the map was just built, which takes a frame or two: the drapes start once that is over, or their move would jump)
		await get_tree().process_frame
		await get_tree().process_frame
		if is_instance_valid(st):
			st.curtains.close()


func _new_fight_screen(f: Fight) -> FightScreen:
	var fs := FightScreen.new()
	fs.setup(run, f)
	fs.run_saved = true
	fs.stage_flow = _stage_flow()
	fs.menu_requested.connect(func(): run = null; show_menu())
	fs.spellbook_pressed.connect(_open_spellbook)
	return fs


# ------------------------------------------------------------------ Dev Mode: Room Test

## Every room of the game, in the order they appear on the Room Test map.
func _test_rooms() -> Array:
	var out: Array = []
	for a in [1, 2, 3]:
		out.append({"type": "fight", "label": "Fight · Act %d" % a, "act": a, "row": 5})
	for a in [1, 2, 3]:
		out.append({"type": "elite", "label": "Elite · Act %d" % a, "act": a, "row": 8})
	for a in [1, 2, 3]:
		out.append({"type": "boss", "label": "Boss · Act %d" % a, "act": a, "row": MapGen.FLOORS})
	for t in [["rest", "Campfire"], ["treasure", "Treasure"], ["shop", "Merchant"]]:
		out.append({"type": t[0], "label": t[1], "act": 1, "row": 3})
	for ev in MapEvents.ALL:
		out.append({"type": "event", "label": ev.title, "act": 1, "row": 3, "event": ev.id})
	return out


func start_room_test() -> void:
	_test_mode = true
	run = RunState.new()
	run.artifact_gained.connect(_on_artifact_found)
	run.setup(GameData.db, SaveManager.unlocked_spells(), SaveManager.unlocked_artifacts())
	run.amber = 999  # (so shops and events can be tried)
	show_room_test()


func show_room_test() -> void:
	_room_bg = ""
	Audio.play_music("map")
	var m := MapScreen.new()
	m.setup(run)
	m.test_rooms = _test_rooms()
	m.test_room_chosen.connect(_enter_test_room)
	m.codex_pressed.connect(open_codex)
	m.menu_requested.connect(func(): run = null; show_menu())
	_swap(m)


## Go straight into a room: the run is put on a one-room map that holds just that room.
func _enter_test_room(room: Dictionary) -> void:
	_test_room = room
	run.over = false
	run.won = false
	run.player.hp = run.player.max_hp
	run.act = room.act
	var rows: Array = []
	for f in MapGen.FLOORS + 1:
		var r := []
		r.resize(MapGen.COLS)
		rows.append(r)
	rows[room.row][0] = {"type": room.type, "next": [], "col": 0, "event": room.get("event", "")}
	run.map = rows
	run.row = room.row
	run.col = 0
	_enter_room(room.type)


## F5 in a Room Test fight / elite / boss room (the Puppet Stage theme): the enemies of that room type and act stand on the stage in sets of four and
## can be hung from the ceiling on ropes (RopeEditor). F5 again goes back to the room map.
func _toggle_rope_mode() -> void:
	if not _test_mode or _rope_busy:
		return
	if _rope_active:
		show_room_test()
		return
	if not UiSkin.is_puppet() or not (_test_room.get("type", "") in ["fight", "elite", "boss"]):
		Events.toast.emit("F5 (rope mode) works in a Room Test fight, elite or boss room, in the Puppet theme.", Color(1, 0.85, 0.5))
		return
	if not (current is LoadoutScreen or current is FightScreen):
		return
	_rope_sets = RopeSets.build(_test_room.type, int(_test_room.act))
	if _rope_sets.is_empty():
		Events.toast.emit("No puppet with a picture in this room type.", Color(1, 0.85, 0.5))
		return
	_rope_i = 0
	_rope_active = true
	_show_rope_set()


func _show_rope_set() -> void:
	var ids: Array = _rope_sets[_rope_i]
	var kind: String = _test_room.type
	_room_bg = "elite_arena" if kind == "elite" else (BOSS_BG[clampi(run.act, 1, 3)] if kind == "boss" else "")
	var f := run.make_fight(ids.map(RopeSets.real_id))
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
	var fs := _new_fight_screen(f)
	fs.rope_mode = true
	fs.arrive = true
	if current is FightScreen and current.rope_mode and current.get_stage() != null:
		fs.stage_in = current.get_stage()  # (the same theatre and scenery: only the enemies change)
	var ed := RopeEditor.new()
	ed.setup(fs, _rope_i, _rope_sets.size(), ids, kind, int(_test_room.act))
	ed.next_pressed.connect(_next_rope_set)
	fs.add_child(ed)
	_rope_active = true
	_swap(fs)
	_rope_active = true  # (_swap looks at the screen before it is ready)


func _next_rope_set() -> void:
	if _rope_busy or not _rope_active or not (current is FightScreen):
		return
	_rope_busy = true
	await current.rope_leave()
	_rope_i = (_rope_i + 1) % _rope_sets.size()
	if _rope_active:
		_show_rope_set()
	_rope_busy = false


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
					_pick_artifact(offer[i].id)
				show_map())
		_:
			_show_loadout(run.encounter_ids())


## A "?" event: its story and choices (options you can't afford are greyed out).
func _show_event(ev: Dictionary) -> void:
	var labels: Array = ev.options.map(func(o): return o.label)
	var pick := func(i: int):
		match ev.options[i].get("do", ""):
			"upgrade_artifact":
				_tinker(ev.options[i])
				return
			"trade_artifacts":
				_barter()
				return
			"invert_spell":
				_invert_pick(ev)
				return
		var res: Dictionary = run.choose_event_option(ev.options[i])
		if run.player.is_dead():
			run.over = true
			_end_run()
			return
		if ev.get("id", "") == "apothecary" and i < 3:  # (what you chose is shown as a picture: pay, snatch, walk on)
			_room_bg = ["apothecary_pay", "apothecary_snatch", "apothecary_walk"][i]
		var learned: Control = SpellCard.make(run.spell(res.spell)) if res.has("spell") else null  # the spell you just learned, shown as its card
		var after := _message(ev.title, res.text, ["Fight!" if res.get("fight", false) else "Continue"], Color(0.8, 0.7, 1), learned)
		after.pressed.connect(func(_k):
			if res.get("fight", false):
				run.current_node()["as"] = "fight"
				_show_loadout(run.encounter_ids())
			else:
				show_map())
	if ev.get("id", "") == "apothecary" and UiSkin.tex("apothecary_bg") != null:
		_show_apothecary(ev, pick)  # (New theme: the painted clearing, where you click what you want to do)
		return
	var s := MessageScreen.new()  # (each option a card; the ones you can't afford greyed out)
	s.title = ev.title
	s.body = ev.text
	s.buttons = labels
	s.title_color = Color(0.8, 0.7, 1)
	s.act = run.act
	s.cards = true
	s.disabled = ev.options.map(func(o): return not run.can_choose(o))
	s.pressed.connect(pick)
	_put(s)


## The Upside-Down Pool: pick a spell from your spellbook; it pays half your HP and plays inverted for the run.
func _invert_pick(ev: Dictionary) -> void:
	var ids := run.invertible_spells()
	var ch := _choice("The Upside-Down Pool", "Choose a spell to invert. It costs half your HP (%d)." % int(floorf(run.player.hp * 0.5)), ids.map(func(id): return run.spell(id)), [], true)
	ch.chosen.connect(func(i):
		if i < 0:
			show_map()
			return
		var text := run.invert_spell(ids[i])
		var after := _message(ev.title, text, ["Continue"], Color(0.8, 0.7, 1), SpellCard.make(run.spell(ids[i])))
		after.pressed.connect(func(_k): show_map()))


## The Wandering Apothecary as a picture: the merchant (pay), the cart (a free sample), the signpost (walk on).
func _show_apothecary(ev: Dictionary, pick: Callable) -> void:
	var opts: Array = ev.options
	var sc := ApothecaryScreen.new()
	sc.setup(run)
	sc.enabled = {"pay": run.can_choose(opts[0]), "sample": run.can_choose(opts[1]), "walk": true}
	sc.hints = {  # (the plate's lines: text, colour, and whether the amber leaf follows)
		"pay": [{"t": "Pay: %d" % opts[0].amber, "c": ApothecaryScreen.GOLD, "coin": true}, {"t": "%d random bottles" % opts[0].n, "c": ApothecaryScreen.WHITE}],
		"sample": [{"t": "Snatch a bottle and run", "c": ApothecaryScreen.WHITE}, {"t": "Lose %d HP" % opts[1].hp, "c": UiTheme.DANGER}],
		"walk": [{"t": "Walk On", "c": ApothecaryScreen.WHITE}],
	}
	sc.extra = _hp_box()
	sc.chosen.connect(func(which: String): pick.call({"pay": 0, "sample": 1, "walk": 2}[which]))
	_swap(sc)


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
	if _stage_flow() and not _on_stage():  # (Continue from the menu lands here with no stage up: put the stage up first, as if you had come from the map)
		var base := _new_fight_screen(run.make_fight([]))
		base.map_mode = true
		_swap(base)
	_checkpoint("fight", ids)
	var l := LoadoutScreen.new()
	l.setup(run, ids)
	l.codex_pressed.connect(open_codex)
	if _on_stage() and current.get_stage() != null:
		_stage_encounter(ids, l)
		return
	l.confirmed.connect(func(): _start_fight(ids))
	if _test_mode and run.current_kind() in ["boss", "elite"]:
		_add_encounter_picker(l, ids)
	_put(l)


## Test mode, a boss or elite room: a dropdown on the preparation screen to face any boss / mini boss instead (every
## act's, this act's first). Picking one rebuilds the screen with it.
func _add_encounter_picker(l: LoadoutScreen, ids: Array) -> void:
	var kind := run.current_kind()
	var acts: Array = [run.act] + [1, 2, 3].filter(func(a): return a != run.act)
	var picks := []  # [label, ids]
	for a in acts:
		var pool: Array = EnemyDefs.BOSSES.get(a, []) if kind == "boss" else EnemyDefs.elites(a)
		for id in pool:
			picks.append(["Act %d · %s" % [a, EnemyDefs.name_of(id)], EnemyDefs.ids_of(id)])
	var box := PanelContainer.new()
	box.add_theme_stylebox_override("panel", UiTheme.panel_box(0.92, 10))
	box.position = Vector2(720, 80)  # (top centre: clear of the encounter panel and the Leaves in the corner)
	box.z_index = 50
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	box.add_child(row)
	row.add_child(UiTheme.label("Test: face", 18, Color(1, 0.85, 0.5)))
	var opt := OptionButton.new()
	opt.custom_minimum_size = Vector2(320, 40)
	for i in picks.size():
		opt.add_item(picks[i][0], i)
		if picks[i][1] == ids:
			opt.select(i)
	opt.item_selected.connect(func(i: int):
		var chosen: Array = picks[i][1]
		run.set_encounter(chosen)
		_show_loadout(chosen))
	row.add_child(opt)
	l.add_child(box)


## Puppet Stage: the fight is built as soon as the encounter board comes up. The old set of props is cleared away and the new one brought in, and the
## enemies walk on, behind the board while you choose your spells; "Begin the fight" only sends the chosen cards to their places and lifts the HUD.
func _stage_encounter(ids: Array, l: LoadoutScreen) -> void:
	var fight_kind := run.current_kind()
	_room_bg = "elite_arena" if fight_kind == "elite" else (BOSS_BG[clampi(run.act, 1, 3)] if fight_kind == "boss" else "")
	_last_ids = ids.duplicate()
	var f := run.make_fight(ids)
	var fs := _new_fight_screen(f)
	fs.finished.connect(func(_won): _after_fight(f))
	var stage: PuppetStage = current.get_stage()
	fs.stage_in = stage
	fs.arrive = true
	fs.hold_hud = true
	stage.clear_props()
	_swap(fs)
	l.on_stage = true
	l.confirmed.connect(func(): _begin_stage_fight(fs, f, ids, l))
	_set_overlay(l)


func _begin_stage_fight(fs: FightScreen, f: Fight, ids: Array, l: LoadoutScreen) -> void:
	if l.has_meta("begun"):
		return
	l.set_meta("begun", true)
	# The board goes at once, whatever the stage is doing: the chosen cards stay where they lay, the props and the enemies keep coming in, and when
	# they are in place the HUD comes up and the cards fly to their places (FightScreen.begin_with_spells waits for that itself).
	_checkpoint("fight", ids)  # (with the spells you just chose)
	var from := l.active_rects()
	var spells: Array = run.loadout.map(func(id): return run.spell(id))
	var book: Array = run.spellbook.map(func(id): return run.spell(id))
	Audio.play_music("boss" if run.current_kind() == "boss" else "fight")
	l.queue_free()
	_overlay = null
	fs.begin_with_spells(spells, book, from)


var _last_ids: Array = []  # the current fight's enemies (the Seed of Life starts it over)


func _start_fight(ids: Array) -> void:
	var fight_kind := run.current_kind()
	_room_bg = "elite_arena" if fight_kind == "elite" else (BOSS_BG[clampi(run.act, 1, 3)] if fight_kind == "boss" else "")
	_last_ids = ids.duplicate()
	if "anxious_armadillo" in ids:
		SaveManager.set_setting("armadillo_met", true)  # (he's met once, ever)
		run.first_run = false
	_checkpoint("fight", ids)  # (with the spells you just chose)
	var f := run.make_fight(ids)
	var fs := _new_fight_screen(f)
	fs.finished.connect(func(_won): _after_fight(f))
	if _stage_flow() and is_instance_valid(current) and current is FightScreen and current.get_stage() != null:
		fs.stage_in = current.get_stage()  # (the same theatre: its scenery slides away, the new room's slides in)
		fs.arrive = true
	Audio.play_music("boss" if run.current_kind() == "boss" else "fight")
	_swap(fs)


var _picked := false  # the artifact being gained was just chosen on a choice screen: no pop-up for it

## An artifact chosen from a choice screen (keepsake, treasure, elite, boss): the player already saw its card, so it
## goes straight on without the "You found an artifact!" pop-up (a curse still says what it did, in a toast).
func _pick_artifact(id: String) -> void:
	_picked = true
	run.gain_artifact(id)
	_picked = false


## An artifact was picked up: its card (frame and picture) pops up in the middle of the screen for a moment (click to dismiss).
func _on_artifact_found(id: String) -> void:
	if _picked:
		Audio.play("artifact_get")
		if run != null and run.curse_note != "":
			Events.toast.emit("CURSE: " + run.curse_note, UiTheme.DANGER)
		return
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
	for id in ([] if _test_mode else SaveManager.add_to_codex(f.defeated)):
		Events.toast.emit("New Codex entry: %s" % EnemyDefs.get_def(id).name, Color(1, 0.9, 0.5))
	if f.won:
		for aid in f.talk_rewards:  # (what a boss's talk promised: yours, and unlocked for good)
			run.gain_artifact(aid)
			if not _test_mode and SaveManager.unlock_artifact(aid):
				Events.toast.emit("%s unlocked" % Artifacts.get_def(aid).name, Color(1, 0.85, 0.4))
	for spell_name in ([] if _test_mode else SaveManager.boss_unlocks(f.defeated)):
		Events.toast.emit("New spell unlocked: %s" % spell_name, Color(1, 0.85, 0.4))
	var act_before := run.act
	if not f.won and run.can_revive():
		# the Seed of Life: back to the start of this fight's preparation, as you were going in
		run.revive()
		Events.toast.emit("The Seed of Life gives you a second chance", Color(0.75, 1.0, 0.6))
		_show_loadout(_last_ids)
		return
	run.finish_fight(f)
	if _test_mode:
		run.act = act_before  # (a boss would move on to the next act)
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
						_pick_artifact(ao[i].id)
					go.call()))
	if kind == "boss":
		var relics := run.boss_relic_offer()
		if not relics.is_empty():
			steps.append(func(go):
				var ch := _choice("Legendary relic", "Only bosses drop these: more Essence every turn, or more spell slots.", [], relics, false)
				ch.chosen.connect(func(i):
					_pick_artifact(relics[i].id)
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
	_put(c)
	return c


func _end_run() -> void:
	if _test_mode:  # (a lost test fight records nothing: back to the room map)
		run.over = false
		run.won = false
		run.player.hp = run.player.max_hp
		show_room_test()
		return
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
