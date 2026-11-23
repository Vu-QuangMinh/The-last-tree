extends RefCounted


func run(t: SceneTree) -> void:
	var args := OS.get_cmdline_user_args()
	var out: String = args[0] if args.size() > 0 else "user://bug_hunter_ref.png"
	var vp := SubViewport.new()
	vp.size = Vector2i(1024, 1024)
	vp.transparent_bg = false
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	t.root.add_child(vp)
	var bg := ColorRect.new()
	bg.color = Color.BLACK
	bg.size = Vector2(1024, 1024)
	vp.add_child(bg)
	var rs := RunState.new()
	var gd = t.root.get_node("GameData")
	rs.setup(gd.db, [], [], 42)
	var f := rs.make_fight(["bug_hunter"])
	var cr := Creature.new()
	cr.size = Vector2(1024, 1024)
	vp.add_child(cr)
	cr.setup(f.enemies[0])
	cr.bob = 0.0
	if args.has("strike"):
		cr.bell_t = 0.28
	await t.create_timer(0.5).timeout
	cr.bob = 0.0
	cr.set_process(false)
	cr.queue_redraw()
	await t.create_timer(0.3).timeout
	vp.get_texture().get_image().save_png(out)
	t.quit()
