class_name DiceGame
extends Control
## Die on Stage (2026-11-15): the whole mode, started from the main menu. The zoned hex map (DiceMapView); a fight on a
## fight tile, with its bonus after it (a dice mod, a move or an artifact: choose 1 of 3); the Merchant (moves, dice
## alterations, an artifact, a meal; in coins); a campfire (rest, or upgrade a move); the boss when it catches you (a move
## and a new die, a d4 or a d10, after it; then the next act). At most DiceCards.MAX_CARDS moves: a fifth replaces one
## of them (or is left). Not saved yet: leaving goes back to the menu and the run is gone.

signal quit

const REST_PCT := 0.3
const FIGHT_COINS := [1, 3]
const ELITE_COINS := 5
const MEAL_PRICE := 5
const MEAL_HP := 15

var run: DiceRun
var _view: Control


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	run = DiceRun.new()
	run.setup()
	show_map()


func _swap(c: Control) -> void:
	if is_instance_valid(_view):
		_view.queue_free()
	_view = c
	add_child(c)


func show_map() -> void:
	if run.won:
		_message("The curtain falls", "You beat all three acts. Bravo!", [["Back to the menu", func(): quit.emit()]])
		return
	if run.caught():
		_message("The boss has caught you", "Its fight begins.", [["Fight!", func(): _fight(run.encounter("boss"), "boss")]])
		return
	var m := DiceMapView.new()
	m.setup(run)
	m.chosen.connect(_on_tile)
	m.waited.connect(func():
		run.wait_turn()
		show_map())
	m.quit.connect(func(): quit.emit())
	_swap(m)
	Audio.play_music("map")


func _on_tile(r: int, c: int) -> void:
	var n := run.move_to(r, c)
	if run.caught():  # (you stepped onto the boss, or it reached you as it moved)
		show_map()
		return
	match String(n.type):
		"fight":
			var kind: String = n.get("fight", "fight")
			_fight(run.encounter(kind), kind, String(n.get("bonus", "")), n)
		"shop":
			_shop()
		"rest":
			_campfire()
		_:
			show_map()


func _fight(ids: Array, kind: String, bonus := "", tile := {}) -> void:
	var fv := DiceFightView.new()
	fv.setup(run, ids)
	fv.finished.connect(func(won: bool):
		if not won:
			_message("Defeat", "The curtain falls on you. Act %d." % run.act, [["Back to the menu", func(): quit.emit()]])
			return
		_rewards(kind, bonus, tile))
	_swap(fv)
	Audio.play_music("boss" if kind == "boss" else "fight")


## After a fight won: coins (more for a mini boss or a double encounter), what the artifacts give, then the tile's bonus.
func _rewards(kind: String, bonus: String, tile: Dictionary) -> void:
	var l := run.rng.randi_range(FIGHT_COINS[0], FIGHT_COINS[1]) if kind == "fight" else ELITE_COINS
	var words := ["+%d coin%s." % [l, "" if l == 1 else "s"]]
	run.leaves += l
	if run.has_artifact("coin_purse"):
		run.leaves += 2
		words.append("Coin Purse: +2 coins.")
	if run.has_artifact("healing_herb"):
		words.append("Healing Herb: +%d HP." % run.heal(3))
	var text := " ".join(words)
	if kind == "boss":
		_card_choice("The boss is beaten", text + " Choose a move.", run.card_offer(3), func():
			_new_die(func():
				run.next_act()
				show_map()))
		return
	match bonus:
		"dice":
			_message("Victory", text + "  " + mod_words(tile), [["Roll your dice", func(): _die_reward(tile)]])
		"card":
			_card_choice("Victory", text + " Choose a move.", run.card_offer(3), show_map)
		"artifact":
			_artifact_choice(text, run.artifact_offer(3))
		_:
			_message("Victory", text, [["Go on", show_map]])


## A boss's reward: one more die, a d4 or a d10 (your choice).
func _new_die(then: Callable) -> void:
	var o := _overlay("A new die", "Take one more die for the rest of the run.")
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 40)
	o.box.add_child(row)
	for sides in [4, 10]:
		row.add_child(UiTheme.button("A d%d  (1 to %d)" % [sides, sides], func():
			run.add_die(sides)
			o.root.queue_free()
			then.call(), 22))


## A campfire: rest (heal REST_PCT of your max HP), or upgrade one move (once each: DiceCards.card).
func _campfire() -> void:
	var o := _overlay("A campfire", "Rest by the fire, or work on one of your moves.")
	o.box.add_child(UiTheme.button("Rest: heal %d%%" % int(REST_PCT * 100), func():
		var h := run.heal(int(ceil(run.max_hp * REST_PCT)))
		o.root.queue_free()
		_message("A campfire", "You rest and heal %d HP." % h, [["Go on", show_map]]), 22))
	var can := run.cards.filter(func(id): return not run.upgrades.has(id))
	var up := UiTheme.button("Upgrade a move", func():
		o.root.queue_free()
		_pick_upgrade(), 22)
	up.disabled = can.is_empty()
	o.box.add_child(up)


func _pick_upgrade() -> void:
	var o := _overlay("Upgrade a move", "Each move can be upgraded once.")
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 30)
	o.box.add_child(row)
	for i in run.cards.size():
		var id: String = run.cards[i]
		var col := VBoxContainer.new()
		col.add_theme_constant_override("separation", 8)
		var cv := DiceCardView.new()
		cv.id = id
		cv.def = run.card_at(i)
		cv.mouse_filter = Control.MOUSE_FILTER_IGNORE
		col.add_child(cv)
		var texts: Array = DiceCards.upgrade_texts(id)
		if run.upgrades.has(id):
			col.add_child(UiTheme.label("Already upgraded", 18, Color(0.7, 0.7, 0.7)))
		else:
			for opt in [["boost", texts[0]], ["alt" if DiceCards.get_card(id).has("alt") else "slot", texts[1]]]:
				if String(opt[1]) == "":
					continue
				var how: String = opt[0]
				var b := UiTheme.button(String(opt[1]), func():
					run.upgrade(id, how)
					o.root.queue_free()
					_message("Upgraded", "%s is now %s." % [DiceCards.get_card(id).name, DiceCards.card(id, how).name], [["Go on", show_map]]), 16)
				b.custom_minimum_size = Vector2(240, 64)
				b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
				col.add_child(b)
		row.add_child(col)
	o.box.add_child(UiTheme.button("Back", func(): o.root.queue_free(); _campfire(), 20))


## Choose one of three artifacts (or none).
func _artifact_choice(words: String, ids: Array) -> void:
	var o := _overlay("Victory", words + " Choose an artifact.")
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 30)
	o.box.add_child(row)
	for id in ids:
		var a := DiceArtifacts.get_item(id)
		var b := Button.new()
		b.custom_minimum_size = Vector2(280, 220)
		b.text = "%s\n%s\n\n%s" % [a.icon, a.name, a.text]
		b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		b.add_theme_font_size_override("font_size", 22)
		for st in ["normal", "hover", "pressed"]:
			var sb := StyleBoxFlat.new()
			sb.bg_color = Color(0.3, 0.2, 0.12) if st == "normal" else Color(0.42, 0.3, 0.15)
			sb.border_color = Color(0.85, 0.65, 0.3)
			sb.set_border_width_all(3)
			sb.set_corner_radius_all(14)
			sb.set_content_margin_all(14)
			b.add_theme_stylebox_override(st, sb)
		b.pressed.connect(func():
			run.gain_artifact(id)
			o.root.queue_free()
			show_map())
		row.add_child(b)
	o.box.add_child(UiTheme.button("Skip", func(): o.root.queue_free(); show_map(), 20))


## A dice mod in words: "Adjustment +2", "Painting: Red", "Carving: Heart" (`mod`: a tile, or {dmod, die_mod / paint / carve}).
static func mod_words(mod: Dictionary) -> String:
	match String(mod.get("dmod", "adjust")):
		"paint":
			var p: Dictionary = DiceFace.PAINTS[mod.paint]
			return "Painting: %s (%s)" % [p.name, p.text]
		"carve":
			var c: Dictionary = DiceFace.CARVES[mod.carve]
			return "Carving: %s %s (%s)" % [c.sym, c.name, c.text]
	return "Adjustment %+d" % int(mod.get("die_mod", 0))


## A dice mod (a tile's, or the Merchant's adjustments): your dice are rolled; pick one, and the face that shows gets it
## for good (adjusted, painted or carved). Then `then` (the map by default).
func _die_reward(mod: Dictionary, then := Callable()) -> void:
	var after: Callable = then if then.is_valid() else show_map
	var kind := String(mod.get("dmod", "adjust"))
	var shown: Array = []  # [die, face index]
	for i in run.dice.size():
		shown.append([i, run.roll(i)])
	var o := _overlay("Your dice are rolled", "Pick one: the face that shows gets it for good.  " + mod_words(mod))
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 40)
	o.box.add_child(row)
	for s in shown:
		var f: Dictionary = run.face(s[0], s[1])
		var col := VBoxContainer.new()
		col.alignment = BoxContainer.ALIGNMENT_CENTER
		var d := DiceDieView.new()
		d.value = int(f.v)
		d.paint = String(f.paint)
		d.carve = String(f.carve)
		d.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var dc := CenterContainer.new()
		dc.add_child(d)
		col.add_child(dc)
		var faces: Array = run.dice[s[0]]
		col.add_child(UiTheme.label("Die %d: %s" % [s[0] + 1, "  ".join(faces.map(func(x): return DiceFace.short(x)))], 16, Color(0.9, 0.85, 0.75)))
		var label := ""
		match kind:
			"paint":
				label = "Paint this %d %s" % [int(f.v), DiceFace.PAINTS[mod.paint].name]
			"carve":
				label = "Carve %s on this %d" % [DiceFace.CARVES[mod.carve].sym, int(f.v)]
			_:
				label = "%d → %d" % [int(f.v), maxi(1, int(f.v) + int(mod.die_mod))]
		col.add_child(UiTheme.button(label, func():
			match kind:
				"paint":
					run.paint_face(s[0], s[1], String(mod.paint))
				"carve":
					run.carve_face(s[0], s[1], String(mod.carve))
				_:
					run.change_face(s[0], s[1], int(mod.die_mod))
			o.root.queue_free()
			after.call(), 20))
		row.add_child(col)


## The Merchant: 3 moves, 3 dice alterations (from -3 to +3), 1 artifact and a meal, in coins. What you buy is gone
## from the cart; the stock stays the same until you leave.
func _shop(stock: Array = []) -> void:
	if stock.is_empty():
		for id in run.card_offer(3):
			stock.append({"card": id})
		var alts: Array = DiceCards.ALTER_PRICE.keys()
		for k in 3:
			stock.append({"alter": int(alts.pop_at(run.rng.randi() % alts.size()))})
		for id in run.artifact_offer(1):
			stock.append({"artifact": id})
	var o := _overlay("The Merchant", "🪙 %d coins. Moves, dice alterations, an artifact, or a meal (+%d HP)." % [run.leaves, MEAL_HP])
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 22)
	o.box.add_child(row)
	var reopen := func(left: Array): _shop(left if not left.is_empty() else [{"empty": true}])
	for item in stock:
		if item.has("empty"):
			continue
		var col := VBoxContainer.new()
		col.alignment = BoxContainer.ALIGNMENT_END
		var price := 0
		if item.has("card"):
			price = DiceCards.price(String(item.card))
			var cv := DiceCardView.new()
			cv.id = item.card
			cv.mouse_filter = Control.MOUSE_FILTER_IGNORE
			col.add_child(cv)
		elif item.has("artifact"):
			price = DiceArtifacts.price(String(item.artifact))
			var a := DiceArtifacts.get_item(String(item.artifact))
			var al := UiTheme.label("%s\n%s\n%s" % [a.icon, a.name, a.text], 18, Color(1.0, 0.92, 0.75))
			al.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			al.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			al.custom_minimum_size = Vector2(200, 150)
			col.add_child(al)
		else:
			price = int(DiceCards.ALTER_PRICE[int(item.alter)])
			var tag := UiTheme.heading("%+d" % int(item.alter), 64, Color(0.55, 1.0, 0.5) if int(item.alter) > 0 else Color(1.0, 0.5, 0.45))
			tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			tag.custom_minimum_size = Vector2(150, 150)
			tag.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			col.add_child(tag)
			var what := UiTheme.label("Roll your dice, pick one:\nits face %+d for good" % int(item.alter), 16, Color(0.9, 0.85, 0.75))
			what.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			col.add_child(what)
		var left := stock.filter(func(x): return x != item)
		var buy := UiTheme.button("Buy · 🪙 %d" % price, func():
			if run.leaves < price:
				Audio.play("release_armour_block", -6.0)
				return
			run.leaves -= price
			o.root.queue_free()
			if item.has("card"):
				_take_card(String(item.card), reopen.bind(left))
			elif item.has("artifact"):
				run.gain_artifact(String(item.artifact))
				reopen.call(left)
			else:
				_die_reward({"dmod": "adjust", "die_mod": int(item.alter)}, reopen.bind(left)), 20)
		buy.disabled = run.leaves < price
		col.add_child(buy)
		row.add_child(col)
	var meal := UiTheme.button("A meal · 🪙 %d" % MEAL_PRICE, func():
		if run.leaves < MEAL_PRICE or run.hp >= run.max_hp:
			return
		run.leaves -= MEAL_PRICE
		run.heal(MEAL_HP)
		o.root.queue_free()
		_shop(stock), 20)
	meal.disabled = run.leaves < MEAL_PRICE or run.hp >= run.max_hp
	o.box.add_child(meal)
	o.box.add_child(UiTheme.button("Leave", func(): o.root.queue_free(); show_map(), 20))


## Choose one of `ids` (or none): it joins your cards.
func _card_choice(title: String, words: String, ids: Array, then: Callable) -> void:
	var o := _overlay(title, words)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 30)
	o.box.add_child(row)
	for id in ids:
		var cv := DiceCardView.new()
		cv.id = id
		cv.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		cv.gui_input.connect(func(ev: InputEvent):
			if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
				o.root.queue_free()
				_take_card(id, then))
		row.add_child(cv)
	o.box.add_child(UiTheme.button("Skip", func(): o.root.queue_free(); then.call(), 20))


## A card joins; with no room left (MAX_CARDS), you choose which one it replaces, or leave it.
func _take_card(id: String, then: Callable) -> void:
	if run.has_room():
		run.gain_card(id)
		then.call()
		return
	var o := _overlay("Your hands are full", "You can hold %d moves. %s takes the place of:" % [DiceCards.MAX_CARDS, DiceCards.get_card(id).name])
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 24)
	o.box.add_child(row)
	for i in run.cards.size():
		var cv := DiceCardView.new()
		cv.id = run.cards[i]
		cv.def = run.card_at(i)
		cv.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		var k := i
		cv.gui_input.connect(func(ev: InputEvent):
			if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
				run.gain_card(id, k)
				o.root.queue_free()
				then.call())
		row.add_child(cv)
	o.box.add_child(UiTheme.button("Keep my moves", func(): o.root.queue_free(); then.call(), 20))


func _message(title: String, words: String, buttons: Array) -> void:
	var o := _overlay(title, words)
	for b in buttons:
		var cb: Callable = b[1]
		o.box.add_child(UiTheme.button(String(b[0]), func(): o.root.queue_free(); cb.call(), 22))


## A dimmed screen with a title and a line, and a column to fill: {root, box}.
func _overlay(title: String, words: String) -> Dictionary:
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	root.z_index = PuppetStage.CEILING_Z + 50  # (over the map's words, which stand over the stage's valance)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.75)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(dim)
	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 22)
	box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(box)
	var t := UiTheme.heading(title, 44, Color(1.0, 0.88, 0.55))
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(t)
	var w := UiTheme.label(words, 24, Color(0.95, 0.9, 0.8))
	w.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	w.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	w.custom_minimum_size = Vector2(1300, 0)
	w.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	box.add_child(w)
	box.child_entered_tree.connect(func(n: Node):
		if n is Button:
			(n as Button).size_flags_horizontal = Control.SIZE_SHRINK_CENTER  # (a button is as wide as its words, not the screen)
			(n as Button).custom_minimum_size.x = maxf((n as Button).custom_minimum_size.x, 220.0))
	add_child(root)
	return {"root": root, "box": box}
