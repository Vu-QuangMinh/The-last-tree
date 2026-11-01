class_name BearRollScene
extends Control
## "They See Me Rolling" (an Act 1 event) and the Rolling Bear's revenge (any act, 3 events after you stepped aside),
## played on the Puppet Stage with the bear's own puppet: a line of narration on top, the choices under the stage, and
## whatever the bear says in a speech bubble over him.
##   meet:    he rolls back and forth across the stage. "Try to stop them": he rams into you, jerks to a stop and lies
##            there upside down ("Thank you, stranger..."). "Get out of the way": he rolls off the stage to the left,
##            wailing.
##   revenge: he rolls in from the right and slams into the middle of the stage (into you), rights himself, says his
##            line, and the fight starts.
## `chosen` is emitted with "stop", "away" or "fight" once its little scene is over and Continue / Fight! is pressed.

signal chosen(what: String)
signal hurt  # the bear rams you: the 5 HP are lost now
signal paid  # he cracks open: the 50 Leaves are yours

const BEAR_PX := 300.0
const ROLL_SPEED := 900.0  # px a second while he rolls across
var mode := "meet"
var act := 1
var on_stage := false
var _feet := 607.0
var _bear: TextureRect
var _story: RichTextLabel
var _buttons: HBoxContainer
var _x := 960.0
var _dir := 1.0
var _spin := 0.0  # radians of roll
var _rolling := false  # (meet: back and forth on his own while you decide)
var _bush: TextureRect  # (meet: "Get out of the way" is the bush on the right, "Try to stop them" the bear himself)
var _tag: Control
var _hover := ""  # "bear", "bush" or ""
var _locked := false  # a choice is made
var _roll_snd: AudioStreamPlayer
var _coins: Array = []  # {node, v (Vector2), age}


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = UiTheme.get_theme()
	mouse_filter = Control.MOUSE_FILTER_STOP
	var host := get_parent()
	if on_stage and host != null and host.has_method("get_stage") and host.get_stage() != null:
		_feet = host.get_stage().floor_center_y()  # (he stands where a fight's enemies stand)
	if not on_stage:
		var bd := Backdrop.new()
		bd.act = act
		add_child(bd)
	_bear = TextureRect.new()
	_bear.texture = Creature._puppet_tex("enraged_bear" if mode == "revenge" else "rolling_bear", 1)  # (the revenge: the red bear of the fight)
	_bear.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_bear.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_bear.size = Vector2(BEAR_PX, BEAR_PX)
	_bear.pivot_offset = _bear.size / 2.0
	_bear.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_bear)
	var hp := EventStage.hint_panel("They See Me Rolling" if mode == "meet" else "The Bear Comes Back", "")
	var panel: PanelContainer = hp.panel
	panel.position = Vector2(1960.0, EventStage.HINT_Y)
	add_child(panel)
	create_tween().tween_property(panel, "position:x", EventStage.HINT_X, 0.4).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_story = hp.body
	_buttons = HBoxContainer.new()
	_buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	_buttons.add_theme_constant_override("separation", 30)
	_buttons.position = Vector2(0, 780)
	_buttons.size = Vector2(1920, 70)
	add_child(_buttons)
	if mode == "revenge":
		_revenge()
	else:
		_story.text = "Someone is rolling across the road, round and round, back and forth, and they are not stopping."
		_x = 500.0
		_rolling = true
		var bush_tex: Texture2D = UiSkin.tex("event_bush_exit")
		if bush_tex != null:
			_bush = TextureRect.new()
			_bush.texture = bush_tex
			_bush.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			_bush.stretch_mode = TextureRect.STRETCH_SCALE
			_bush.size = Vector2(bush_tex.get_width() * 150.0 / bush_tex.get_height(), 150.0)
			_bush.pivot_offset = Vector2(_bush.size.x / 2.0, _bush.size.y)
			_bush.position = Vector2(1340.0 - _bush.size.x / 2.0, _feet - 150.0)
			_bush.mouse_filter = Control.MOUSE_FILTER_IGNORE
			add_child(_bush)
		else:
			_offer([["Try to stop them", _stop], ["Get out of the way", _away]])


func _gui_input(e: InputEvent) -> void:
	if _locked or mode != "meet" or _bush == null:
		return
	if e is InputEventMouseMotion:
		var at: Vector2 = e.position
		var now := ""
		if at.distance_to(Vector2(_x, _feet - BEAR_PX / 2.0)) < BEAR_PX * 0.5:
			now = "bear"
		elif Rect2(_bush.position, _bush.size).has_point(at):
			now = "bush"
		_set_hover(now)
	elif e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
		if _hover == "bear":
			_set_hover("")
			_stop()
		elif _hover == "bush":
			_set_hover("")
			Audio.play("getout")
			_away()


func _set_hover(now: String) -> void:
	if now == _hover:
		return
	_hover = now
	if is_instance_valid(_tag):
		_tag.queue_free()
	_tag = null
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if now != "" else Control.CURSOR_ARROW
	var tw := create_tween().set_parallel(true)
	tw.tween_property(_bear, "modulate", Color(1.22, 1.16, 1.0) if now == "bear" else Color.WHITE, 0.1)
	tw.tween_property(_bush, "modulate", Color(1.22, 1.16, 1.0) if now == "bush" else Color.WHITE, 0.1)
	if now == "":
		return
	Audio.play("ui_hover", -8.0)
	_tag = EventStage.make_tag("Try to stop them" if now == "bear" else "Get out of the way")
	_tag.z_index = 10
	add_child(_tag)


func _process(d: float) -> void:
	if _rolling and (_roll_snd == null or not is_instance_valid(_roll_snd)):
		_roll_snd = Audio.play_held("rolling", -6.0)  # (the sound ends, he is still rolling: again)
	if is_instance_valid(_tag):
		var top := Vector2(_x, _feet - BEAR_PX - 20.0) if _hover == "bear" else Vector2(_bush.position.x + _bush.size.x / 2.0, _bush.position.y - 10.0)
		_tag.position = Vector2(clampf(top.x - _tag.size.x / 2.0, 10.0, 1910.0 - _tag.size.x), maxf(top.y - _tag.size.y, 120.0))
	_move_coins(d)
	if _rolling:
		_x += _dir * ROLL_SPEED * 0.6 * d
		if _x > 1250.0 or _x < 420.0:
			_dir = -_dir
		_spin += _dir * ROLL_SPEED * 0.6 * d / (BEAR_PX * 0.45)
	_place()


func _place() -> void:
	_bear.position = Vector2(_x - BEAR_PX / 2.0, _feet - BEAR_PX)
	_bear.rotation = _spin


func _offer(choices: Array) -> void:
	for c in _buttons.get_children():
		c.queue_free()
	for c in choices:
		var b := UiTheme.button(c[0], c[1], 22)
		b.custom_minimum_size = Vector2(0, 52)  # (as wide as its words)
		_buttons.add_child(b)


func _shake(n: float) -> void:
	var host := get_parent()
	if host != null and host.has_method("_shake"):
		host._shake(n)


## "Try to stop them": he rams into you in the middle of the stage, jerks to a stop and lies there upside down.
func _stop() -> void:
	_offer([])
	_rolling = false
	_locked = true
	Audio.stop_held(_roll_snd, 0.1)
	var tw := create_tween()
	var dist: float = absf(960.0 - _x)
	var turns := dist / (BEAR_PX * 0.45)
	var spin_to := _spin + signf(960.0 - _x) * turns
	tw.set_parallel()
	tw.tween_property(self, "_x", 960.0, dist / ROLL_SPEED).set_trans(Tween.TRANS_LINEAR)
	tw.tween_property(self, "_spin", spin_to, dist / ROLL_SPEED)
	await tw.finished
	Audio.play("sfx_player_hit")
	Audio.play("wooden_ball_colide", 0.0, 0.8)
	_shake(18.0)
	hurt.emit()
	_spin = PI  # (the jerk: he stops dead, upside down)
	var jerk := create_tween()
	jerk.tween_property(self, "_x", 990.0, 0.06)
	jerk.tween_property(self, "_x", 950.0, 0.08)
	jerk.tween_property(self, "_x", 960.0, 0.1)
	_story.text = "They ram straight into you, and something in your chest goes crack: you lose 5 HP. It's a rolling bear!"
	await get_tree().create_timer(1.2).timeout
	await _bubble("Thank you, stranger!", 1.4)
	await _bubble("Here, for your trouble.", 1.4)
	# he cracks open like a piggy bank, and pays out
	_spin = 0.0
	_place()
	if is_instance_valid(_bear.texture):
		PuppetShatter.spawn_picture(self, _bear.texture, Rect2(_bear.position, _bear.size), _feet)
	_bear.visible = false
	_spray_coins(Vector2(_x, _feet - BEAR_PX * 0.5), 50)
	Audio.play("sfx_coin_bag_spill", 0.0)  # (with the breaking wood, which is played by the shatter)
	paid.emit()
	_shake(14.0)
	_story.text = "He cracks open like a piggy bank, and 50 Leaves pour out. Your ribs are less grateful."
	await get_tree().create_timer(2.2).timeout
	_offer([["Continue", func(): chosen.emit("stop")]])


## `n` coins thrown up out of `at`: they fall, bounce on the floor, lie there a moment and fade.
func _spray_coins(at: Vector2, n: int) -> void:
	var tex: Texture2D = UiSkin.tex("icon_amber")
	if tex == null:
		return
	Audio.play("sfx_card_hit", -4.0, 1.4)
	for i in n:
		var c := TextureRect.new()
		c.texture = tex
		c.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		c.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		c.size = Vector2(38, 38)
		c.pivot_offset = c.size / 2.0
		c.position = at - c.size / 2.0
		c.mouse_filter = Control.MOUSE_FILTER_IGNORE
		c.z_index = 5
		add_child(c)
		var ang := randf_range(-PI * 0.9, -PI * 0.1)
		_coins.append({"node": c, "v": Vector2.from_angle(ang) * randf_range(450.0, 1100.0), "age": 0.0, "floor": _feet + randf_range(-10.0, 50.0), "spin": randf_range(-8.0, 8.0)})


func _move_coins(d: float) -> void:
	for k in range(_coins.size() - 1, -1, -1):
		var c: Dictionary = _coins[k]
		var n: TextureRect = c.node
		c.age = float(c.age) + d
		var v: Vector2 = c.v
		v.y += 2300.0 * d
		n.position += v * d
		n.rotation += float(c.spin) * d
		if n.position.y + n.size.y / 2.0 > float(c.floor) and v.y > 0.0:
			v.y *= -0.45
			v.x *= 0.8
			n.position.y = float(c.floor) - n.size.y / 2.0
		c.v = v
		if float(c.age) > 2.6:
			n.modulate.a = clampf(1.0 - (float(c.age) - 2.6) / 0.5, 0.0, 1.0)
		if float(c.age) > 3.1:
			n.queue_free()
			_coins.remove_at(k)


## "Get out of the way": he rolls on, off the stage to the left, wailing.
func _away() -> void:
	_offer([])
	_rolling = false
	_locked = true
	_story.text = "You step aside, and let them roll on by."
	var tw := create_tween()
	var dist: float = _x + BEAR_PX
	tw.set_parallel()
	tw.tween_property(self, "_x", -BEAR_PX, dist / (ROLL_SPEED * 0.6))
	tw.tween_property(self, "_spin", _spin - dist / (BEAR_PX * 0.45), dist / (ROLL_SPEED * 0.6))
	_bubble("Why didn't you help me? Whyyyyyy...", 2.6, true)
	await tw.finished
	await get_tree().create_timer(0.8).timeout
	_story.text = "His cry fades as he rolls further and further away."
	_offer([["Continue", func(): chosen.emit("away")]])


## The revenge: in from the right, a slam into the middle (into you), up on his feet, his line, then the fight.
func _revenge() -> void:
	_story.text = "You hear something coming. It is fast. Too fast!"
	_x = 1920.0 + BEAR_PX
	_place()
	await get_tree().create_timer(1.0).timeout
	var dist: float = _x - 960.0
	var tw := create_tween()
	tw.set_parallel()
	tw.tween_property(self, "_x", 960.0, dist / (ROLL_SPEED * 1.3)).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_property(self, "_spin", -dist / (BEAR_PX * 0.45), dist / (ROLL_SPEED * 1.3)).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	await tw.finished
	# the slam: he hits you as if you were a wall, right in the middle of the stage
	Audio.play("sfx_player_hit", 2.0)
	Audio.play("wooden_ball_colide", 2.0, 0.6)
	_shake(28.0)
	var hit := create_tween()
	hit.tween_property(self, "_x", 1010.0, 0.08).set_ease(Tween.EASE_OUT)
	hit.tween_property(self, "_x", 960.0, 0.25).set_trans(Tween.TRANS_BOUNCE)
	_story.text = "A ball of fur and muscle slams into you!"
	await get_tree().create_timer(0.9).timeout
	# he rights himself up
	var up := create_tween()
	up.tween_property(self, "_spin", roundf(_spin / TAU) * TAU, 0.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	await up.finished
	await _bubble("Behold, heartless stranger!", 1.6)
	await _bubble("I have come for revenge!", 1.6)
	_story.text = "You are still seeing stars: you will be Stunned for the first turn."
	_offer([["Fight!", func(): chosen.emit("fight")]])


## A black speech bubble over the bear (his head, wherever he is). `follow`: it rides along with him and fades.
func _bubble(text: String, hold: float, follow := false) -> void:
	var bubble := PanelContainer.new()
	bubble.add_theme_stylebox_override("panel", EventStage.board_box(36, 24))
	bubble.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bubble.z_index = 10
	var l := UiTheme.label(text, 20, Color(0.96, 0.94, 0.9))
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bubble.add_child(l)
	add_child(bubble)
	await get_tree().process_frame
	var head := func() -> Vector2: return Vector2(_x + BEAR_PX * 0.15, _feet - BEAR_PX - 10.0)
	bubble.position = head.call() - Vector2(0, bubble.size.y)
	bubble.pivot_offset = Vector2(0, bubble.size.y)
	bubble.scale = Vector2(0.3, 0.3)
	Audio.play("ui_click", -6.0, 0.8)
	EventStage.speak(text)  # (his voice)
	hold = maxf(hold, EventStage.voice_length(text) + 0.25)  # (the next line waits until this one is said)
	var tw := bubble.create_tween()
	tw.tween_property(bubble, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	var t := 0.0
	while t < hold and is_instance_valid(bubble):
		await get_tree().process_frame
		t += get_process_delta_time()
		if follow:
			bubble.position = head.call() - Vector2(0, bubble.size.y)
			bubble.modulate.a = clampf(1.0 - t / hold, 0.0, 1.0)  # (his cry fades as he rolls away)
	if is_instance_valid(bubble):
		var out := bubble.create_tween()
		out.tween_property(bubble, "modulate:a", 0.0, 0.2)
		await out.finished
		bubble.queue_free()
