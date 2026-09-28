class_name TutorialScreen
extends Control
## Tutorial mode: one scripted fight that walks through how the game works. Sprout (the coach) spotlights one
## thing at a time and only lets you do the action being taught; explanations continue with a tap. After the
## fight, a few words about the rest of the run, and a pointer to the Wiki (F1) for everything else.
## A lesson: {title, enemies: [{id, hp, armor?: [i], moves}], spells, stock, draws: ["FWA", ...], steps}.
## A step: {say, focus, then} where then is one of:
##   "tap"              wait for a tap
##   "chant:FFW"        build exactly this chant (only the next right element can be added)
##   "chanted"          press Chant
##   "aiming:id"        start casting spell id (a targeted spell pulls out its arrow)
##   "target:i"         aim at enemy i
##   "picking:id"       start casting spell id, which asks for an element (for single-target spells)
##   "pick"             pick an HP element (any) — waits for the spell to finish
##   "cast:id"          cast spell id and let it finish
##   "placing:id"       start casting an Infuse spell   ·   "place:i" put the element in gap i
##   "release"          press Release
##   "turn"             watch the Release and the enemy turn play out
##   "clear"            clear the chant
##   "win"              free play until the fight is won

signal done

const LESSONS := [
	{
		"title": "Tutorial",
		"enemies": [
			{"id": "ashling", "hp": "FFW", "moves": [{"kind": "attack", "n": 3}]},
			{"id": "gale_sprite", "hp": "FWAWA", "moves": [{"kind": "attack", "n": 4}]},
		],
		"spells": ["fire_ball", "water_wall"], "stock": "WWFFWAA", "draws": ["WAF", "WWF", "AWW", "WFW"],
		"steps": [
			{"say": "Welcome, Keeper! I'm Sprout. The last tree is in danger, and you're the one who'll protect it. One fight, and you'll know the basics.", "focus": "none", "then": "tap"},
			{"say": "Everything runs on three elements: Fire, Water and Air. To keep things short, we write them F, W and A.", "focus": "stock", "then": "tap"},
			{"say": "An enemy's HP is a row of elements. This Ashling has F F W: Fire, Fire, Water. Knock them all off and it's gone.", "focus": "hp:0", "then": "tap"},
			{"say": "The Gale Sprite has F W A W A.", "focus": "hp:1", "then": "tap"},
			{"say": "These are your elements. You spend them to build a chant. You get 3 more every turn, and the ones you don't use are kept.", "focus": "stock", "then": "tap"},
			{"say": "These are your spells. The orbs under each name are its pattern: when the pattern appears in your chant, the spell comes alive.", "focus": "spells", "then": "tap"},
			{"say": "Above each enemy is its intent: what it will do on its turn. The Gale Sprite will attack you for 4. Hover any intent or portrait to learn more.", "focus": "intent:1", "then": "tap"},
			{"say": "Here's the big idea: ONE chant hits EVERY enemy at once. Each enemy checks the chant on its own and loses the longest START of its HP that it can find in it. A good chant damages several enemies at the same time.", "focus": "enemies", "then": "tap"},
			{"say": "Let's build a chant. Start with W W: that's Water Wall's pattern.", "focus": "stock_el:W", "then": "chant:W"},
			{"say": "…and the second W.", "focus": "stock_el:W", "then": "chant:WW"},
			{"say": "Now F F: Fire Ball's pattern!", "focus": "stock_el:F", "then": "chant:WWF"},
			{"say": "…F.", "focus": "stock_el:F", "then": "chant:WWFF"},
			{"say": "Finish with W and A.", "focus": "stock", "then": "chant:WWFFWA"},
			{"say": "Look at the preview: the crossed-out elements are what each enemy will lose. The Ashling's whole HP, F F W, is in the chant, so it gets a skull. The Gale Sprite's start F W A is in there too, so it loses F W A and keeps W A. One chant, two enemies hit!", "focus": "enemies", "then": "tap"},
			{"say": "×1 on both spells: each will come alive once. (A spell triggers at most as many times as its pattern is long.)", "focus": "spells", "then": "tap"},
			{"say": "Tap Chant to speak it.", "focus": "chant_btn", "then": "chanted"},
			{"say": "Your spells are alive: they glow and wiggle. Spells always go first. Tap Water Wall: 4 Shield blocks attack damage until your next turn.", "focus": "card:water_wall", "then": "cast:water_wall"},
			{"say": "Now tap Fire Ball. It pulls out an arrow: aim it at the Gale Sprite.", "focus": "card:fire_ball", "then": "aiming:fire_ball"},
			{"say": "Tap the Gale Sprite (or press Tab to switch targets and Enter to confirm).", "focus": "enemy:1", "then": "target:1"},
			{"say": "Fire Ball knocked off the Gale Sprite's last A. Your spells are done, but notice: your chant hasn't hurt anyone yet. Its elements are still waiting in the chant.", "focus": "chant", "then": "tap"},
			{"say": "Now you Release them. Each element flies out, one by one from left to right, and knocks off the enemy HP it lines up with, on every enemy at once. Tap Release!", "focus": "chant_btn", "then": "release"},
			{"say": "Watch the elements fly! Then the Gale Sprite attacks, and your Shield blocks it.", "focus": "none_clear", "then": "turn"},
			{"say": "The Ashling is gone, and the Gale Sprite lost F W A to the Release. Only one W left!", "focus": "hp:0", "then": "tap"},
			{"say": "A new turn and 3 new elements. This box shows what you'll get NEXT turn, so you can plan ahead.", "focus": "next", "then": "tap"},
			{"say": "Your HP. It carries over from fight to fight, so every point counts.", "focus": "player", "then": "tap"},
			{"say": "Finish it yourself: build a chant, tap Chant, cast any spells that come alive, then tap Release!", "focus": "none_clear", "then": "win"},
		],
	},
]

## After the fight: the rest of a run, in a few words.
const END_STEPS := [
	{"say": "Well done! A run is 3 acts. Each act is a map you climb one room at a time: fights, elites, unknown rooms, a merchant, treasure and campfires, with a boss at the top.", "focus": "none", "then": "tap"},
	{"say": "After each fight you learn a new spell. Before each fight you choose which 6 spells to bring. Bosses give Legendary spells and relics that add elements every turn.", "focus": "none", "then": "tap"},
	{"say": "There's more to discover: Burn and Poison, Armour, Targeted damage, spells that change your chant, cursed artifacts… Press F1 any time to open the Wiki: every rule is in there. Good luck, Keeper!", "focus": "none", "then": "tap"},
]

var db: SpellDB
var run: RunState
var fs: FightScreen
var coach: TutorialCoach
var _step: Dictionary = {}
var _layer: Control
var _progress := ""


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = UiTheme.get_theme()
	db = GameData.db
	run = RunState.new()
	run.setup(db, [], [], 77)
	run.row = 0
	_layer = Control.new()
	_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_layer)
	coach = TutorialCoach.new()
	add_child(coach)
	var skip := UiTheme.button("Skip tutorial", func(): _finish(), 15)
	skip.position = Vector2(1740, 1030)
	skip.z_index = 95
	add_child(skip)
	_play.call_deferred()


func _play() -> void:
	for i in LESSONS.size():
		_progress = LESSONS[i].title
		await _lesson(LESSONS[i])
		if not is_inside_tree():
			return
	for step in END_STEPS:
		_step = step
		coach.show_step(step.say, _focus_fn(step.focus), true, "Tutorial")
		await coach.tapped
	_finish()


func _finish() -> void:
	SaveManager.set_setting("tutorial_done", true)
	done.emit()


# ------------------------------------------------------------------ one lesson

func _lesson(L: Dictionary) -> void:
	for c in _layer.get_children():
		c.queue_free()
	var player := PlayerState.new()
	player.max_hp = 60.0
	player.hp = 60.0
	run.player = player
	var f := Fight.new(db, player)
	f.rng.seed = 11
	f.loadout = L.spells.map(func(id): return db.get_spell(id))
	f.start(L.enemies.map(func(e): return e.id), 1, 1)
	# fixed elements, fixed enemies, fixed moves
	player.stock.clear()
	for ch in L.stock:
		player.add_element(ch)
	player.next_draw.clear()
	var draws: Array = L.draws.duplicate()
	if not draws.is_empty():
		for ch in String(draws.pop_front()):
			player.next_draw.append({"el": ch, "temp": false})
	f.script_draws = draws
	for i in L.enemies.size():
		var spec: Dictionary = L.enemies[i]
		var e: EnemyState = f.enemies[i]
		e.elements.clear()
		for ch in spec.hp:
			e.elements.append(ch)
		e.armor.resize(e.elements.size())
		e.armor.fill(false)
		for a in spec.get("armor", []):
			e.set_armor(a)
		e.def.moves = spec.moves
		e.def.erase("passives")
		e.move_index = 0
		f._plan(e)
	fs = FightScreen.new()
	fs.setup(run, f)
	fs.gate = _gate
	fs.auto_release = false
	_layer.add_child(fs)
	await get_tree().process_frame
	var title := UiTheme.label(L.title, 26, Color(0.85, 1, 0.75))
	title.position = Vector2(30, 60)
	title.z_index = 95
	_layer.add_child(title)
	var steps: Array = L.steps
	for i in steps.size():
		await _do_step(steps[i])
		if not is_inside_tree():
			return
	# lessons end in a won fight (the last step waits for it); give the victory banner a moment
	await get_tree().create_timer(0.3).timeout


func _do_step(step: Dictionary) -> void:
	_step = step
	var then: String = step.then
	var kind := then.get_slice(":", 0)
	var arg := then.get_slice(":", 1) if then.contains(":") else ""
	var tap := kind == "tap"
	if step.focus == "none_clear":
		# watching a Release or playing freely: Sprout talks from the corner, nothing is dimmed or blocked
		_show_bubble_only(step.say)
	else:
		coach.show_step(step.say, _focus_fn(step.focus), tap, _progress)
	match kind:
		"tap":
			await coach.tapped
		"chant":
			await _wait_tut(func(k, d): return k == "chant_changed" and d == arg)
		"chanted":
			await _wait_tut(func(k, _d): return k == "chanted")
		"aiming":
			await _wait_tut(func(k, _d): return k == "aiming")
		"target":
			await _wait_tut(func(k, _d): return k == "picking" or k == "cast")
		"picking":
			await _wait_tut(func(k, _d): return k == "picking")
		"pick":
			await _wait_tut(func(k, _d): return k == "cast")
		"cast":
			await _wait_tut(func(k, d): return k == "cast" and d == arg)
		"placing":
			await _wait_tut(func(k, _d): return k == "placing")
		"place":
			await _wait_tut(func(k, _d): return k == "cast")
		"release":
			await _wait_tut(func(k, _d): return k == "releasing")
		"turn":
			await _wait_tut(func(k, _d): return k == "turn_start")
		"clear":
			await _wait_tut(func(k, d): return k == "chant_changed" and d == "")
		"win":
			await fs.finished


## During Releases and free play Sprout still talks, but nothing is dimmed or blocked.
func _show_bubble_only(text: String) -> void:
	coach.show_step(text, Callable(), false, _progress)
	coach.set_meta("no_dim", true)


func _wait_tut(pred: Callable) -> void:
	while true:
		var r: Array = await fs.tut
		if pred.call(r[0], r[1]):
			return


## What the player may do during the current step.
func _gate(action: String, arg) -> bool:
	var then: String = _step.get("then", "")
	var kind := then.get_slice(":", 0)
	var want := then.get_slice(":", 1) if then.contains(":") else ""
	match kind:
		"win":
			return true
		"chant":
			if action == "add":
				return want.begins_with(fs._chant_string() + str(arg))
			return action == "remove"
		"chanted":
			return action == "chant"
		"clear":
			return action == "clear" or action == "remove"
		"aiming", "picking", "cast", "placing":
			return action == "cast" and arg == want
		"target":
			return action == "target" and str(arg) == want
		"pick":
			return action == "pick"
		"place":
			return action == "place" and str(arg) == want
		"release":
			return action == "release"
	return false


# ------------------------------------------------------------------ spotlights

func _focus_fn(name: String) -> Callable:
	return func(): return _focus_rect(name)


func _rect_of(c: Control) -> Rect2:
	if c == null or not is_instance_valid(c) or not c.is_inside_tree():
		return Rect2()
	return Rect2(c.global_position, c.size)


func _focus_rect(name: String) -> Rect2:
	var what := name.get_slice(":", 0)
	var arg := name.get_slice(":", 1) if name.contains(":") else ""
	if fs == null or not is_instance_valid(fs):
		return Rect2()
	match what:
		"enemy", "hp", "intent":
			var i := int(arg)
			if i >= fs.fight.enemies.size():
				return Rect2()
			var v: EnemyView = fs._views.get(fs.fight.enemies[i])
			if v == null:
				return Rect2()
			if what == "hp":
				return _rect_of(v._hp_row)
			if what == "intent":
				return _rect_of(v._intent_slot)
			return _rect_of(v)
		"enemies":
			var r := Rect2()
			for v in fs._views.values():
				r = _rect_of(v) if r.size == Vector2.ZERO else r.merge(_rect_of(v))
			return r
		"stock":
			return _rect_of(fs._stock_row)
		"stock_el":
			for c in fs._stock_row.get_children():
				if c is ElementIcon and c.el == arg and not c.dim:
					return _rect_of(c)
			return _rect_of(fs._stock_row)
		"chant":
			return _rect_of(fs._chant_row)
		"chant_btn":
			return _rect_of(fs._cast_btn)
		"clear_btn":
			return _rect_of(fs._clear_btn)
		"spells":
			return _rect_of(fs._spell_row).grow_individual(0, 0, 0, 0) if fs._cards.is_empty() else _cards_rect()
		"card":
			for c in fs._cards:
				if c.spell.id == arg:
					return _rect_of(c)
		"next":
			return _rect_of(fs._next_row.get_parent().get_parent())
		"player":
			return _rect_of(fs._player_panel)
	return Rect2()


func _cards_rect() -> Rect2:
	var r := Rect2()
	for c in fs._cards:
		r = _rect_of(c) if r.size == Vector2.ZERO else r.merge(_rect_of(c))
	return r
