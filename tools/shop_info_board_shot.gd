extends SceneTree
## The shop's info board (Test mode > Events > The Merchant): an artifact, a bottle and the candle are "hovered" by hand; the board slides out left of the shelf, then back in behind it.
## godot --path . --position 6000,0 --no-focus --audio-driver Dummy -s tools/shop_info_board_shot.gd -- <out folder>


func _init() -> void:
	await process_frame
	create_timer(90.0).timeout.connect(quit)
	var out: String = OS.get_cmdline_user_args()[0]
	var save = root.get_node("SaveManager")
	save.use_test_file("user://shop_info_board.json")
	save.data.settings["theme"] = "puppet"
	var main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await create_timer(1.5).timeout
	main._test_event("merchant")
	await create_timer(11.0).timeout
	var sh = main._overlay
	sh.set_process(false)  # (the mouse is faked)
	for kind in ["artifact", "bottle"]:
		for b in sh._boxes:
			if is_instance_valid(b) and b.has_meta("pic") and String(b.get_meta("kind")) == kind:
				var c: Vector2 = b.get_global_transform() * (b.size / 2.0)
				for k in 30:
					sh._hover_info = {}
					sh._items_tick(c, Time.get_ticks_msec())
					sh._info_update(0.03)
					await process_frame
				root.get_texture().get_image().save_png(out + "/info_%s.png" % kind)
				if kind == "artifact":  # half way back in
					for k in 4:
						sh._hover_info = {}
						sh._info_update(0.03)
						await process_frame
					root.get_texture().get_image().save_png(out + "/info_retracting.png")
				break
	for k in 40:
		sh._hover_info = {}
		sh._info_update(0.03)
		await process_frame
	print("info visible after the mouse left: ", sh._info.visible, "  t ", sh._info_t)
	root.get_texture().get_image().save_png(out + "/info_gone.png")
	sh._hover_info = {}
	var spr: TextureRect = sh._cart_good["upgrade"]
	for k in 30:
		sh._hover_info = {}
		sh._goods_tick(spr.get_global_transform() * (spr.size / 2.0))
		sh._info_update(0.03)
		await process_frame
	root.get_texture().get_image().save_png(out + "/info_candle.png")
	quit()
