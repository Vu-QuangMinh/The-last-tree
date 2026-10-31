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

const BEAR_PX := 300.0
const ROLL_SPEED := 900.0  # px a second while he rolls across
var mode := "meet"
var act := 1
var on_stage := false
var _feet := 607.0
var _bear: TextureRect
var _story: Label
var _buttons: HBoxContainer
var _x := 960.0
var _dir := 1.0
var _spin := 0.0  # radians of roll
var _rolling := false  # (meet: back and forth on his own while you decide)


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
	_bear.texture = Creature._puppet_tex("rolling_bear", 1)
	_bear.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_bear.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_bear.size = Vector2(BEAR_PX, BEAR_PX)
	_bear.pivot_offset = _bear.size / 2.0
	_bear.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_bear)
	var panel := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.08, 0.05, 0.04, 0.88)
	sb.border_color = Color(0.75, 0.58, 0.3)
	sb.set_border_width_all(3)
	sb.set_corner_radius_all(14)
	sb.set_content_margin_all(18)
	panel.add_theme_stylebox_override("panel", sb)
	panel.position = Vector2(360, 150)
	panel.custom_minimum_size = Vector2(1200, 0)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(panel)
	_story = UiTheme.label("", 26, Color(0.96, 0.93, 0.86))
	_story.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_story.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	panel.add_child(_story)
	_buttons = HBoxContainer.new()
	_buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	_buttons.add_theme_constant_override("separation", 30)
	_buttons.position = Vector2(0, 820)
	_buttons.size = Vector2(1920, 70)
	add_child(_buttons)
	if mode == "revenge":
		_revenge()
	else:
		_story.text = "Someone is rolling across the road, round and round, back and forth, and they are not stopping."
		_x = 500.0
		_rolling = true
		_offer([["Try to stop them", _stop], ["Get out of the way", _away]])


func _process(d: float) -> void:
	if _rolling:
		_x += _dir * ROLL_SPEED * 0.6 * d
		if _x > 1500.0 or _x < 420.0:
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
		var b := UiTheme.button(c[0], c[1], 24)
		b.custom_minimum_size = Vector2(320, 64)
		_buttons.add_child(b)


func _shake(n: float) -> void:
	var host := get_parent()
	if host != null and host.has_method("_shake"):
		host._shake(n)


## "Try to stop them": he rams into you in the middle of the stage, jerks to a stop and lies there upside down.
func _stop() -> void:
	_offer([])
	_rolling = false
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
	_spin = PI  # (the jerk: he stops dead, upside down)
	var jerk := create_tween()
	jerk.tween_property(self, "_x", 990.0, 0.06)
	jerk.tween_property(self, "_x", 950.0, 0.08)
	jerk.tween_property(self, "_x", 960.0, 0.1)
	_story.text = "They ram straight into you, and something in your chest goes crack. It's a rolling bear!"
	await get_tree().create_timer(1.2).timeout
	await _bubble("Thank you, stranger!", 1.4)
	await _bubble("Here, for your trouble.", 1.4)
	_story.text = "He presses 50 Leaves into your hand. Your ribs are less grateful: you lose 5 HP."
	_offer([["Continue", func(): chosen.emit("stop")]])


## "Get out of the way": he rolls on, off the stage to the left, wailing.
func _away() -> void:
	_offer([])
	_rolling = false
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
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.07, 0.06, 0.08, 0.96)  # (enemies speak in black bubbles)
	sb.border_color = Color(0.75, 0.7, 0.85)
	sb.set_border_width_all(3)
	sb.set_corner_radius_all(18)
	sb.content_margin_left = 16
	sb.content_margin_right = 16
	sb.content_margin_top = 6
	sb.content_margin_bottom = 6
	bubble.add_theme_stylebox_override("panel", sb)
	bubble.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bubble.z_index = 10
	var l := UiTheme.label(text, 30, Color(0.96, 0.94, 0.9))
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bubble.add_child(l)
	add_child(bubble)
	await get_tree().process_frame
	var head := func() -> Vector2: return Vector2(_x + BEAR_PX * 0.15, _feet - BEAR_PX - 10.0)
	bubble.position = head.call() - Vector2(0, bubble.size.y)
	bubble.pivot_offset = Vector2(0, bubble.size.y)
	bubble.scale = Vector2(0.3, 0.3)
	Audio.play("ui_click", -6.0, 0.8)
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
