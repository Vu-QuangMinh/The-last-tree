extends RefCounted
## Test mode > Events > The Merchant, through the real Main flow: the shop must come up OVER THE STAGE (cart rolls in), then Leave goes back to Test mode.
## godot --path . --position 6000,0 --no-focus --audio-driver Dummy -s tools/merchant_event_flow.gd -- <out folder>


func run(t: SceneTree) -> void:
	var root: Window = t.root
	var out: String = OS.get_cmdline_user_args()[0]
	var save = root.get_node("SaveManager")
	save.use_test_file("user://merchant_event_flow.json")
	save.data.settings["theme"] = "puppet"
	var main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await t.create_timer(1.5).timeout
	main._test_event("merchant")
	await t.create_timer(11.0).timeout
	print("overlay: ", main._overlay, " on_stage: ", main._on_stage(), " test_mode: ", main._test_mode)
	root.get_texture().get_image().save_png(out + "/merchant_1.png")
	var sh = main._overlay
	if sh != null and sh._cart_good.size() == 2:
		sh.set_process(false)  # (the mouse is faked: the candle, then the soup, are "hovered" by hand)
		for kind in ["upgrade", "heal"]:
			var spr: TextureRect = sh._cart_good[kind]
			var c: Vector2 = spr.get_global_transform() * (spr.size / 2.0)
			for k in 20:
				sh._goods_tick(c)
				await t.process_frame
			root.get_texture().get_image().save_png(out + "/merchant_hover_%s.png" % kind)
		for kind in ["artifact", "bottle"]:  # (an artifact on the rug, a bottle on the table: only the picture grows)
			for b in sh._boxes:
				if is_instance_valid(b) and b.has_meta("pic") and String(b.get_meta("kind")) == kind:
					var c2: Vector2 = b.get_global_transform() * (b.size / 2.0)
					for k in 20:
						sh._items_tick(c2, Time.get_ticks_msec())
						await t.process_frame
					root.get_texture().get_image().save_png(out + "/merchant_hover_%s.png" % kind)
					break
		for k in 20:
			sh._items_tick(Vector2(-100, -100), Time.get_ticks_msec())
			sh._goods_tick(Vector2(-100, -100))
			await t.process_frame
		sh.set_process(true)
	if sh != null:
		sh.leave.emit()
	await t.create_timer(1.5).timeout
	print("after leave: current ", main.current.get_class(), " stage_shop flag ", main._test_stage_shop, " test_mode ", main._test_mode)
	t.quit()
