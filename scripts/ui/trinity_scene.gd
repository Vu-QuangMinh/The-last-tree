class_name TrinityScene
extends RefCounted
## The three Trinity Fragments, cast in the same turn, become Trinity: they rise to the corners of a triangle, its
## edges light up, they whirl into a black hole in its middle, and a white-hot ball cools into the new card.
## (The fuse cutscene's cousin: three cards in a triangle instead of two side by side, and no wax.)

const CORNER := 300.0  # px from the middle of the triangle to each card
const ANGLES := [-PI / 2.0, PI / 6.0, PI * 5.0 / 6.0]  # top, bottom right, bottom left
const SPIN := 2.2  # seconds of whirling into the hole


static func play(host: Control, parts: Array, froms: Array, result: Dictionary) -> void:
	var tree := host.get_tree()
	var stage := Control.new()
	stage.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	stage.mouse_filter = Control.MOUSE_FILTER_STOP
	stage.z_index = 90
	host.add_child(stage)
	var held := [null]  # (the effects layer frees itself when it goes quiet: made again when needed, as in the fuse)
	var fx := func() -> Vfx:
		if not is_instance_valid(held[0]) or held[0].is_queued_for_deletion():
			held[0] = Vfx.make(stage, 5)
		return held[0]
	var shade := ColorRect.new()
	shade.color = Color(0, 0, 0, 0)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stage.add_child(shade)
	stage.create_tween().tween_property(shade, "color:a", 0.85, 0.3)
	var view_size := host.get_viewport_rect().size
	var mid := Vector2(view_size.x / 2.0, 580)  # (low enough that the top card clears the HUD)
	var half := Vector2(SpellCard.W, SpellCard.H) / 2.0
	# the cards and the triangle live in a picture of their own (a SubViewport) so the black hole can bend it
	var vp := SubViewport.new()
	vp.size = Vector2i(view_size)
	vp.transparent_bg = true
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	stage.add_child(vp)
	var vroot := Control.new()
	vroot.theme = UiTheme.get_theme()
	vroot.size = view_size
	vp.add_child(vroot)
	var view := TextureRect.new()
	view.texture = vp.get_texture()
	view.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var hole_mat := ShaderMaterial.new()
	hole_mat.shader = load("res://assets/Global/Card/Shaders/black_hole.gdshader")
	hole_mat.set_shader_parameter("center", mid)
	hole_mat.set_shader_parameter("size", view_size)
	view.material = hole_mat
	stage.add_child(view)
	# each card's colour: the Essence its pattern is made of (Fire, Water, Air)
	var cols: Array = []
	for s in parts:
		cols.append(Elements.COLORS.get(String(s.get("pattern", "?")).left(1), Color.WHITE))
	# the triangle's three edges, behind the cards
	var edges: Array = []
	for k in 3:
		var ln := Line2D.new()
		ln.width = 0.0
		ln.begin_cap_mode = Line2D.LINE_CAP_ROUND
		ln.end_cap_mode = Line2D.LINE_CAP_ROUND
		var g := Gradient.new()
		g.set_color(0, cols[k])
		g.set_color(1, cols[(k + 1) % 3])
		ln.gradient = g
		ln.points = PackedVector2Array([mid, mid])
		vroot.add_child(ln)
		edges.append(ln)
	var cards: Array = []
	for k in parts.size():
		var c := SpellCard.make(parts[k])
		c.mouse_filter = Control.MOUSE_FILTER_IGNORE
		vroot.add_child(c)
		c.position = (froms[k] if k < froms.size() else mid) - stage.global_position
		cards.append(c)
	var corner := func(k: int, spin: float, r: float) -> Vector2:
		return mid + Vector2.from_angle(ANGLES[k] + spin) * r
	var place := func(spin: float, r: float) -> void:
		for k in cards.size():
			cards[k].position = corner.call(k, spin, r) - half
		for k in 3:
			edges[k].points = PackedVector2Array([corner.call(k, spin, r), corner.call((k + 1) % 3, spin, r)])
	# 1. they rise to the three corners
	var tw := stage.create_tween().set_parallel()
	for k in cards.size():
		tw.tween_property(cards[k], "position", corner.call(k, 0.0, CORNER) - half, 0.45).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	await tw.finished
	place.call(0.0, CORNER)
	# 2. the edges light up, one after another
	for k in 3:
		Audio.play("spell_glow", -4.0 + k * 2.0)
		var et := stage.create_tween()
		et.tween_property(edges[k], "width", 7.0, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		var p: Vector2 = corner.call(k, 0.0, CORNER)
		fx.call().burst(p, 14, cols[k], Vector2(120, 380), Vector2(0.3, 0.6), Vector2(3, 7), Vfx.SPARK)
		await tree.create_timer(0.26).timeout
	fx.call().glow(mid, 260, Color(1, 0.95, 0.85, 0.4), 0.6)
	await tree.create_timer(0.25).timeout
	# 3. the triangle spins faster and faster, shrinking into a black hole in its middle
	var t0 := Time.get_ticks_msec() / 1000.0
	while true:
		var t := clampf((Time.get_ticks_msec() / 1000.0 - t0) / SPIN, 0.0, 1.0)
		hole_mat.set_shader_parameter("hole", 46.0 * smoothstep(0.0, 0.25, t) * (1.0 - 0.55 * smoothstep(0.85, 1.0, t)))
		hole_mat.set_shader_parameter("twist", 14.0 * t * t)
		hole_mat.set_shader_parameter("pull", pow(t, 2.6))
		place.call(TAU * 1.6 * t * t, CORNER * (1.0 - 0.45 * t))
		if randf() < 0.8:
			var ang := randf() * TAU
			var far := randf_range(160.0, 400.0)
			var vel := (Vector2.from_angle(ang + PI / 2.0) * 0.9 - Vector2.from_angle(ang) * 0.6) * far * 2.2
			fx.call().part(mid + Vector2.from_angle(ang) * far, vel, cols[randi() % 3], 0.45, randf_range(3, 7), Vfx.SPARK)
		if t >= 1.0:
			break
		await tree.process_frame
	view.queue_free()
	vp.queue_free()
	# 4. a white-hot ball, ringed in the three colours
	Audio.play("discovery_unlock")
	fx.call().flash(Color(1, 1, 1, 0.8), 0.25)
	for k in 3:
		fx.call().ring(mid, 20, 260 + 60 * k, cols[k], 0.5 + 0.1 * k, 9.0, 0.05 * k)
	fx.call().burst(mid, 30, Color(1, 0.97, 0.88), Vector2(250, 750), Vector2(0.3, 0.7), Vector2(4, 9), Vfx.SPARK)
	var ball := FuseScreen.HotBall.new()
	ball.position = mid - stage.global_position
	stage.add_child(ball)
	var bt := stage.create_tween()
	bt.tween_property(ball, "radius", 70.0, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	await bt.finished
	await tree.create_timer(0.35).timeout
	# 5. the ball cools into Trinity
	var card := SpellCard.make(result)
	card.is_zoom_copy = true  # (only for show: no hover magnifier)
	card.scale = Vector2(0.15, 0.15)
	card.modulate = Color(6, 6, 6, 0)
	stage.add_child(card)
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	await tree.process_frame
	card.pivot_offset = card.size / 2.0
	card.position = mid - stage.global_position - card.size / 2.0
	var ct := stage.create_tween().set_parallel()
	ct.tween_property(card, "scale", Vector2(1.15, 1.15), 0.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	ct.tween_property(card, "modulate", Color(1, 1, 1, 1), 0.7).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	ct.tween_property(ball, "radius", 0.0, 0.4).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	await ct.finished
	var title := UiTheme.heading("United: %s!" % result.name, 34, Color(1, 0.85, 0.6))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.size = Vector2(1200, 50)
	title.position = Vector2(mid.x - 600, mid.y - 210) - stage.global_position  # (above the card, below the HUD)
	stage.add_child(title)
	var cont := UiTheme.button("Continue", func(): pass, 22)
	cont.custom_minimum_size = Vector2(240, 54)
	cont.position = Vector2(view_size.x - 300, 990) - stage.global_position
	stage.add_child(cont)
	await cont.pressed
	var out := stage.create_tween()
	out.tween_property(stage, "modulate:a", 0.0, 0.25)
	await out.finished
	stage.queue_free()
