extends RefCounted
## The Orphans (an Act 2 fight): what is seen of the children behind the bush. Stand-ins until there is art: a picture named
## throw_<item> is used when it exists, otherwise an emoji; the children are emoji too.

const ITEM_ICON := {"mud": "🟤", "stone": "🪨", "stick": "🥢", "brick": "🧱", "pot": "🍲", "shovel": "⛏", "sword": "🗡", "boulder": "🪨", "axe": "🪓", "head": "💀"}
const ITEM_PX := {"mud": 40, "stone": 44, "stick": 56, "brick": 56, "pot": 64, "shovel": 76, "sword": 88, "boulder": 120, "axe": 96, "head": 110}
const RUN_TIME := 1.5  # the children are off the stage after this
const WAIT := 2.3  # how long the fight waits for it all


static func _figure(text: String, px: int) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", px)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


## Something flies out from behind the bush in an arc, spinning, and lands at `to`.
static func throw_item(host: Control, from: Vector2, to: Vector2, item: String) -> void:
	var px: int = ITEM_PX.get(item, 48)
	var tex: Texture2D = UiSkin.tex("throw_" + item)
	var n: Control
	if tex != null:
		var r := TextureRect.new()
		r.texture = tex
		r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		r.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		r.size = Vector2(px, px)
		r.mouse_filter = Control.MOUSE_FILTER_IGNORE
		n = r
	else:
		n = _figure(String(ITEM_ICON.get(item, "🪨")), px)
	n.z_index = 200
	host.add_child(n)
	n.pivot_offset = Vector2(px, px) / 2.0
	n.global_position = from
	Audio.play("sfx_steal_miss", -6.0, 1.3)
	var tw := n.create_tween().set_parallel(true)
	tw.tween_method(func(v: float) -> void:
		n.global_position = from.lerp(to, v) + Vector2(0.0, -sin(v * PI) * 170.0) - Vector2(px, px) / 2.0, 0.0, 1.0, 0.5)
	tw.tween_property(n, "rotation", TAU * 2.0, 0.5)
	await tw.finished
	n.queue_free()


## A child's face comes up from behind the bush now and then, with a giggle written in the air.
static func peek_forever(bush: Control) -> void:
	while is_instance_valid(bush) and bush.is_inside_tree():
		await bush.get_tree().create_timer(randf_range(3.0, 7.0)).timeout
		if not is_instance_valid(bush) or not bush.is_inside_tree():
			return
		var face := _figure("🧒", 58)
		face.show_behind_parent = true
		bush.add_child(face)
		var x := randf_range(0.2, 0.7) * bush.size.x
		var low := bush.size.y * 0.2
		face.position = Vector2(x, low)
		var tw := face.create_tween()
		tw.tween_property(face, "position:y", low - 74.0, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_interval(randf_range(0.5, 1.1))
		tw.tween_property(face, "position:y", low, 0.2)
		tw.tween_callback(face.queue_free)


## The bush is dead: it is pulled up off the stage, and the three children behind it run away to the left, laughing.
static func run_away(host: Control, rect: Rect2, tex: Texture2D) -> void:
	var bush := TextureRect.new()
	bush.texture = tex
	bush.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bush.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	bush.size = rect.size
	bush.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bush.z_index = 201
	host.add_child(bush)
	bush.global_position = rect.position
	var feet := rect.end.y - 84.0
	for k in 3:
		var kid := _figure("🧒", 76)
		kid.z_index = 200
		host.add_child(kid)
		var at := Vector2(rect.position.x + rect.size.x * (0.2 + 0.25 * k), feet)
		kid.global_position = at
		var go := kid.create_tween()
		go.tween_interval(0.55 + 0.12 * k)
		go.tween_method(func(v: float) -> void:
			kid.global_position = Vector2(lerpf(at.x, -160.0, v), at.y - absf(sin(v * 22.0)) * 26.0), 0.0, 1.0, RUN_TIME)
		go.tween_callback(kid.queue_free)
		var haha := _figure("Hee hee!", 30)
		haha.z_index = 202
		host.add_child(haha)
		haha.global_position = at + Vector2(0.0, -46.0)
		haha.modulate.a = 0.0
		var say := haha.create_tween()
		say.tween_interval(0.5 + 0.25 * k)
		say.tween_property(haha, "modulate:a", 1.0, 0.15)
		say.tween_property(haha, "global_position:y", at.y - 110.0, 0.8)
		say.tween_property(haha, "modulate:a", 0.0, 0.2)
		say.tween_callback(haha.queue_free)
	var up := bush.create_tween()
	up.tween_property(bush, "rotation", 0.05, 0.08)
	up.tween_property(bush, "rotation", -0.05, 0.08)
	up.tween_property(bush, "rotation", 0.0, 0.06)
	up.tween_property(bush, "global_position:y", -rect.size.y - 60.0, 0.6).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	up.tween_callback(bush.queue_free)
