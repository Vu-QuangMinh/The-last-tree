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
##   "pick"             pick an Essence element (any) — waits for the spell to finish
##   "cast:id"          cast spell id and let it finish
##   "placing:id"       start casting an Infuse spell   ·   "place:i" put the element in gap i
##   "release"          press Release
##   "turn"             watch the Release and the enemy turn play out
##   "clear"            clear the chant
##   "undo"             take back the last spell (Undo button, Ctrl+Z or Backspace)
##   "win"              free play until the fight is won

signal done

const LESSONS := [
	{
		"title": "Tutorial",
		"enemies": [
			{"id": "ashling", "hp": "FFWA", "moves": [{"kind": "attack", "n": 3}]},
			{"id": "gale_sprite", "hp": "FWAWFA", "moves": [{"kind": "attack", "n": 4}]},
		],
		# turn 1 has no spells: the chant alone does the damage. Spells arrive on turn 2.
		"spells": [], "stock": "FWFWAF", "draws": ["WWF", "WWA", "FFW"],
		"steps": [
			{"say": "Welcome, Keeper! I'm Sprout. The last tree is in danger, and you're the one who'll protect it. One fight, and you'll know the basics.", "focus": "none", "then": "tap"},
			{"say": "Everything runs on three Essence: Fire, Water and Air. To keep things short, we write them F, W and A.", "focus": "stock", "then": "tap"},
			{"say": "An enemy's life is its Essence: a row of Essence. This Ashling's Essence is F F W A. Knock them all off and it's gone.", "focus": "hp:0", "then": "tap"},
			{"say": "The Gale Sprite has F W A W F A.", "focus": "hp:1", "then": "tap"},
			{"say": "Above each enemy is its intent: what it will do on its turn. The Gale Sprite will attack you for 4. Hover any intent or portrait to learn more.", "focus": "intent:1", "then": "tap"},
			{"say": "Your CHANT is how you deal damage. One chant hits EVERY enemy at once: each enemy loses the longest START of its Essence that it can find in the chant. So the ORDER of your Essence matters.", "focus": "enemies", "then": "tap"},
			{"say": "Let's see. Build F W F: tap a Fire…", "focus": "stock_el:F", "then": "chant:F"},
			{"say": "…a Water…", "focus": "stock_el:W", "then": "chant:FW"},
			{"say": "…and a Fire.", "focus": "stock_el:F", "then": "chant:FWF"},
			{"say": "Look at the preview (the crossed-out Essence). The Ashling starts with F F, but F F isn't in F W F, so it only loses one F. The Gale Sprite starts with F W, and F W is there, so it loses F W.", "focus": "enemies", "then": "tap"},
			{"say": "Same Essence, better order. Tap Clear.", "focus": "clear_btn", "then": "clear"},
			{"say": "Now build F F W.", "focus": "stock", "then": "chant:FFW"},
			{"say": "Now the Ashling loses F F W (only A is left), and the Gale Sprite still loses F W. Same three Essence, much more damage, just from the order!", "focus": "enemies", "then": "tap"},
			{"say": "Tap Chant to speak it.", "focus": "chant_btn", "then": "chanted"},
			{"say": "Your chant is spoken, but nothing has been hit yet: its Essence wait in the chant until you Release them.", "focus": "chant", "then": "tap"},
			{"say": "Tap Release! Each Essence flies out, one by one from left to right, and knocks off the enemy Essence it lines up with, on every enemy at once.", "focus": "chant_btn", "then": "release"},
			{"say": "Watch the Essence fly! Then it's the enemies' turn: each one does what its intent said.", "focus": "none_clear", "then": "turn"},
			{"say": "Ouch! Attacks take your HP, and your HP carries over from fight to fight, so every point counts.", "focus": "player", "then": "tap"},
			{"say": "Every turn you get 3 more Essence (this box shows what's coming next turn). Essence you don't use is kept.", "focus": "next", "then": "tap"},
			{"say": "Now for the bonus: spells! The orbs on a card are its pattern. When your chant contains that pattern, IN THAT ORDER, the spell comes alive: an extra effect on top of the chant's damage.", "focus": "spells", "then": "tap", "action": "spells:fire_ball,water_wall"},
			{"say": "Build A W F W F W.", "focus": "stock", "then": "chant:AWFWFW"},
			{"say": "Look at the preview. The Ashling gets a skull (its only Essence left is A), but the Gale Sprite only loses A W F. Its rightmost Essence, A, survives, and it will hit you again. And your spells stay asleep: F F and W W never sit next to each other.", "focus": "enemies", "then": "tap"},
			{"say": "Tap Clear, and let's rearrange.", "focus": "clear_btn", "then": "clear"},
			{"say": "Build A W F F W W: the same Essence, but now F F and W W are together.", "focus": "stock", "then": "chant:AWFFWW"},
			{"say": "×1 on both spells! The chant still does its damage, and now Fire Ball can knock off the Gale Sprite's last A before the Release. Then A W F takes the rest, and it's gone. (The preview only counts the chant, so it won't show a skull until Fire Ball has landed.)", "focus": "spells", "then": "tap"},
			{"say": "That's the whole game: the chant is your main damage, and arranging it in the right order wakes spells that finish the job. The best keeper will know which order to chant to maximize their chances of success! (Each spell triggers once per turn.)", "focus": "none", "then": "tap"},
			{"say": "Tap Chant.", "focus": "chant_btn", "then": "chanted"},
			{"say": "Both spells are awake. Tap Water Wall to cast it.", "focus": "card:water_wall", "then": "cast:water_wall"},
			{"say": "4 Shield: the blue glass over your HP bar. Shield blocks attack damage, and it stays from turn to turn, building up until attacks use it up.", "focus": "player", "then": "tap"},
			{"say": "Fire Ball needs a target. Tap it: it pulls out an arrow.", "focus": "card:fire_ball", "then": "aiming:fire_ball"},
			{"say": "Let's make a mistake on purpose, so you can see how to fix one. Tap the Ashling (or press Tab to switch targets and Enter to confirm).", "focus": "enemy:0", "then": "target:0"},
			{"say": "Fire Ball knocked off the Ashling's last A… but the Ashling was going to die anyway: your chant starts with A, so the Release would have finished it. Now look at the Gale Sprite: A W F still leaves its last A, so it survives and hits you next turn. Fire Ball was wasted!", "focus": "enemies", "then": "tap"},
			{"say": "Good news: until you press Release, you can take back any spell you cast. Tap Undo (or press Ctrl+Z or Backspace).", "focus": "undo_btn", "then": "undo"},
			{"say": "Time rewound: the Ashling is back, and so is Fire Ball. Only Release is permanent. Tap Fire Ball again.", "focus": "card:fire_ball", "then": "aiming:fire_ball"},
			{"say": "This time, tap the Gale Sprite.", "focus": "enemy:1", "then": "target:1"},
			{"say": "Fire Ball knocked off the Gale Sprite's last A, and now the preview shows two skulls. Your spells are done: Release the chant!", "focus": "chant_btn", "then": "release"},
			{"say": "Here it goes!", "focus": "none_clear", "then": "win"},
		],
	},
]

## After the fight: the rest of a run, in a few words.
const END_STEPS := [
	{"say": "Well done! A run is 3 acts. Each act is a map you climb one room at a time: fights, elites, unknown rooms, a merchant, treasure and campfires, with a boss at the top.", "focus": "none", "then": "tap"},
	{"say": "After each fight you learn a new spell. Before each fight you choose which 5 spells to bring. Bosses give Legendary spells and relics that add Essence every turn.", "focus": "none", "then": "tap"},
	{"say": "There's more to discover: Burn and Poison, Armour, Targeted spells, spells that change your chant, cursed artifacts… Press F1 any time to open the Wiki: every rule is in there. Good luck, Keeper!", "focus": "none", "then": "tap"},
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
		e.lit.clear()
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
	fs.help_override = _help_text
	fs.blocked.connect(_on_blocked)
	coach.tapped.connect(func(): if is_instance_valid(fs): fs.note_progress())
	_layer.add_child(fs)
	await get_tree().process_frame
	var title := UiTheme.label(L.title, 26, Color(0.85, 1, 0.75))
	title.position = Vector2(30, 100)
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
	var action: String = step.get("action", "")
	if action.begins_with("spells:"):
		for id in action.get_slice(":", 1).split(","):
			fs.fight.loadout.append(db.get_spell(id))
		fs._build_spells()
		fs._refresh_all()
		await get_tree().process_frame
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
		"undo":
			await _wait_tut(func(k, _d): return k == "undone")
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
		"undo":
			return action == "undo"
	return false


# ------------------------------------------------------------------ helping a lost player

const DO_WHAT := {
	"tap": "Tap anywhere (or press Space) to continue.",
	"chant": "Tap the glowing Essence the hand points at to add it to your chant.",
	"chanted": "Tap the Chant button (or press Enter).",
	"aiming": "Tap the glowing spell card.",
	"picking": "Tap the glowing spell card.",
	"cast": "Tap the glowing spell card.",
	"target": "The arrow follows your mouse: tap the glowing enemy (or press Tab to switch and Enter to confirm).",
	"pick": "Tap one of the enemy's Essence orbs to choose it.",
	"place": "Drag the glowing Essence to the front of your chant.",
	"placing": "Tap the glowing spell card.",
	"release": "Tap the Release button (or press E).",
	"clear": "Tap the Clear button.",
	"undo": "Tap the Undo button under your chant (or press Ctrl+Z or Backspace).",
	"turn": "Nothing to do right now: watch the Essence fly and the enemies act.",
	"win": "",
}


## When the player clicks around lost: repeat what Sprout asked, and exactly how to do it.
func _help_text() -> String:
	var then: String = _step.get("then", "")
	var kind := then.get_slice(":", 0)
	if kind == "win":
		return ""  # free play: the normal explanation fits
	coach.nudge()
	return "Sprout says: %s\n\n👉 What to do: %s" % [_step.get("say", ""), DO_WHAT.get(kind, "")]


## A wrong tap: a gentle nudge right away, without waiting for frantic clicking.
func _on_blocked(_action: String) -> void:
	coach.nudge()


# ------------------------------------------------------------------ spotlights

func _focus_fn(name: String) -> Callable:
	return func(): return _focus_rect(name)


func _rect_of(c: Control) -> Rect2:
	if c == null or not is_instance_valid(c) or not c.is_inside_tree():
		return Rect2()
	return Rect2(c.global_position, c.size * c.get_global_transform().get_scale())


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
		"undo_btn":
			return _rect_of(fs._undo_btn)
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
