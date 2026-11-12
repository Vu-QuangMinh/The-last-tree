extends RefCounted
## see shop_info_sizes.gd


func run(t: SceneTree) -> void:
	var root: Window = t.root
	var out: String = OS.get_cmdline_user_args()[0]
	var save = root.get_node("SaveManager")
	save.use_test_file("user://shop_info_sizes.json")
	save.data.settings["theme"] = "puppet"
	var main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await t.create_timer(1.5).timeout
	main._test_event("merchant")
	await t.create_timer(11.0).timeout
	var sh = main._overlay
	sh.set_process(false)
	for id: String in ["fire_emblem", "lucky_acorn", "echo_chamber"]:
		var a: Dictionary = Artifacts.view(String(id))
		var key: String = "t_" + id
		for k in 25:
			sh._hover_info = {"key": key, "text": ArtifactCard.tip(a), "tex": UiSkin.tex(UiSkin.ARTIFACT_ART.get(id, id))}
			sh._info_update(0.03)
			await t.process_frame
		print(id, " board size ", sh._info.size, " at ", sh._info.position)
		root.get_texture().get_image().save_png(out + "/infosize_%s.png" % id)
		if id == "fire_emblem":
			for k in 4:
				sh._hover_info = {}
				sh._info_update(0.03)
				await t.process_frame
			root.get_texture().get_image().save_png(out + "/infosize_sliding.png")
			for k in 30:
				sh._hover_info = {}
				sh._info_update(0.03)
				await t.process_frame
			print("after slide: visible ", sh._info.visible, " clip ", sh._info_layer.size)
	t.quit()
