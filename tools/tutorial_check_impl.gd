extends RefCounted
## Plays the tutorial by doing exactly what Sprout asks, snapshotting every step. Fails loudly if a step stalls.

var tree: SceneTree
var out := ""


func run(t: SceneTree, p_out: String) -> void:
	tree = t
	out = p_out
	DirAccess.make_dir_recursive_absolute(out)
	tree.root.get_node("SaveManager").use_test_file("user://tutorial_check_save.json")
	Engine.time_scale = 4.0
	var tut := TutorialScreen.new()
	var finished := [false]
	tut.done.connect(func(): finished[0] = true)
	tree.root.add_child(tut)
	var last := {}
	var n := 0
	var stall := 0
	while not finished[0] and stall < 900:
		await tree.process_frame
		var step: Dictionary = tut._step
		if step.is_empty():
			continue
		if step != last:
			last = step
			stall = 0
			n += 1
			for i in 12:
				await tree.process_frame
			var img := tree.root.get_texture().get_image()
			img.save_png("%s/step_%02d.png" % [out, n])
			print("step %02d: %s -> %s" % [n, step.then, step.say.left(70)])
		stall += 1
		var fs: FightScreen = tut.fs
		var then: String = step.then
		var kind := then.get_slice(":", 0)
		var arg := then.get_slice(":", 1) if then.contains(":") else ""
		if fs == null or fs.busy:
			if kind == "tap" and tut.coach.tap_mode:
				tut.coach.tapped.emit()
			continue
		match kind:
			"tap":
				tut.coach.tapped.emit()
			"chant":
				var cur := fs._chant_string()
				if cur.length() < arg.length():
					fs._add_element(arg[cur.length()])
			"chanted":
				fs._on_cast()
			"cast", "aiming", "picking", "placing":
				for c in fs._cards:
					if c.spell.id == arg:
						fs._on_card_clicked(c)
			"target":
				if fs.aiming:
					fs._on_enemy_clicked(fs._views[fs.fight.enemies[int(arg)]])
			"pick":
				if fs.pick_view:
					fs._on_hp_clicked(fs.pick_view, fs.pick_view.enemy.armor.find(false))
			"place":
				if fs.chant_mode == "insert":
					fs._emit_chant_done(int(arg))
			"clear":
				fs._clear_chant()
			"release":
				fs._on_end_turn()
			"win":
				# free play: chant everything that matches an enemy start, then cast what comes alive
				if fs.phase == "build":
					var e: EnemyState = fs.fight.alive()[0]
					for el in e.elements:
						fs._add_element(el)
					if fs.chant_idx.is_empty():
						fs._on_end_turn()
					else:
						fs._on_cast()
				else:
					var cast := false
					for c in fs._cards:
						if c.charges > 0:
							fs._on_card_clicked(c)
							cast = true
							break
					if not cast:
						fs._on_end_turn()
	print("TUTORIAL %s after %d steps" % ["FINISHED" if finished[0] else "STALLED", n])
	Engine.time_scale = 1.0
	tree.quit()
