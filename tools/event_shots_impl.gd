extends RefCounted
func run(t: SceneTree) -> void:
	var root: Window = t.root
	var args := OS.get_cmdline_user_args()
	var out: String = args[0] if args.size() > 0 else "user://"
	var only: Array = args.slice(1)
	var save = root.get_node("SaveManager")
	save.use_test_file("user://event_shots.json")
	save.data.settings["theme"] = OS.get_environment("SHOT_THEME") if OS.get_environment("SHOT_THEME") != "" else "puppet"
	var gd = root.get_node("GameData")
	var r := RunState.new()
	r.setup(gd.db, save.unlocked_spells(), save.unlocked_artifacts(), 3)
	r.amber = 300
	var fs := FightScreen.new()
	fs.setup(r, r.make_fight([]))
	fs.stage_flow = true
	fs.map_mode = true
	root.add_child(fs)
	await t.create_timer(2.5).timeout
	for id in EventStage.LAYOUTS:
		if not only.is_empty() and not (id in only):
			continue
		var es := EventStage.new()
		es.ev = MapEvents.get_event(id)
		r.gain_artifact("thornbark")  # (something to give)
		for i in es.ev.options.size():
			if EventStage.LAYOUTS[id].get("offer_on_stage", false):
				break  # (those are offered after a click on a prop, see below)
			var o: Dictionary = es.ev.options[i]
			var kind := "spell" if (o.get("pick_spell", false) or o.get("recycle", "") == "spell") else ("artifact" if (o.get("recycle", "") == "artifact" or int(o.get("pick_artifact", 0)) > 0) else "")
			if kind == "spell":
				for sid in r.spellbook:
					es.items.append({"opt": i, "kind": "spell", "id": sid, "need": 1, "spell": r.spell(sid)})
			elif kind == "artifact":
				for aid in r.artifacts:
					es.items.append({"opt": i, "kind": "artifact", "id": aid, "need": 1, "spell": {}})
		es.act = 1
		es.on_stage = true
		es.z_index = PuppetStage.CEILING_Z + 2
		fs.add_child(es)
		if OS.get_environment("SHOT_DEBUG") != "":
			await t.create_timer(2.0).timeout
			for pr in es._props:
				print("PROP ", pr.node.texture.resource_path.get_file(), " pos ", pr.node.position, " size ", pr.node.size, " scale ", pr.node.scale, " feet ", es._feet, " tex ", pr.node.texture.get_size())
		fs.peek_hud(not EventStage.LAYOUTS[id].get("no_hud", false))
		if id == "recycler":
			es.hidden_opts = [2]
			await t.create_timer(2.5).timeout
			root.get_texture().get_image().save_png("%s/event_recycler_rolling.png" % out)
			await t.create_timer(3.6).timeout
		await t.create_timer(2.2).timeout
		root.get_texture().get_image().save_png("%s/event_%s.png" % [out, id])
		if not es._item_views.is_empty():  # (the mouse on the middle item: the plaque, the enlarged card, the flame)
			var v: Control = es._item_views[es._item_views.size() / 2].node
			v.mouse_entered.emit()
			await t.create_timer(0.6).timeout
			root.get_texture().get_image().save_png("%s/event_%s_hover.png" % [out, id])
		if id == "recycler":  # (a spell is traded: it goes into him, three come back)
			var back: Array = []
			for sid in ["ember_lash", "spark", "gust"]:
				if r.spell(sid).is_empty():
					continue
				back.append({"opt": 0, "kind": "spell", "id": sid, "need": 1, "spell": r.spell(sid)})
			if back.size() < 3:
				back = []
				for sid in ["fire_ball", "water_wall", "tailwind"]:
					back.append({"opt": 0, "kind": "spell", "id": sid, "need": 1, "spell": r.spell(sid)})
			es.trade(r.spellbook[0], back, "RECYCLE! Take one.")
			await t.create_timer(0.45).timeout
			root.get_texture().get_image().save_png("%s/event_recycler_trade_in.png" % out)
			await t.create_timer(2.2).timeout
			root.get_texture().get_image().save_png("%s/event_recycler_trade_out.png" % out)
			es.present("water_wall")
			es.show_result("The recycler hands you the spell.", "", true)
			await t.create_timer(1.0).timeout
			root.get_texture().get_image().save_png("%s/event_recycler_taken.png" % out)
		if id == "flying_turtle" and OS.get_environment("SHOT_HOW") != "":
			es.show_result("You flip the turtle back onto his feet.", OS.get_environment("SHOT_HOW"))
			await t.create_timer(0.9).timeout
			root.get_texture().get_image().save_png("%s/event_turtle_%s.png" % [out, OS.get_environment("SHOT_HOW")])
		if id == "broken_bridge" and OS.get_environment("SHOT_HOW") == "bridge_fail":  # (the soaked card: the Water flies in)
			var after: Dictionary = r.spell("fire_ball").duplicate(true)
			var before: Dictionary = after.duplicate(true)
			after.pattern = String(after.pattern) + "W"
			after.size = String(after.pattern).length()
			after.burden = "W"
			es.show_result("You land in the bog. Your spellbook is soaked through: Fire Ball now needs 1 more Water.", "bridge_fail", false, after, before)
			await t.create_timer(1.35).timeout
			root.get_texture().get_image().save_png("%s/event_bridge_card_before.png" % out)
			await t.create_timer(0.55).timeout
			root.get_texture().get_image().save_png("%s/event_bridge_card_flying.png" % out)
			await t.create_timer(2.2).timeout
			root.get_texture().get_image().save_png("%s/event_bridge_card_after.png" % out)
		elif id == "broken_bridge" and OS.get_environment("SHOT_HOW") == "bridge_ok":
			es.show_result("You make it across! 1 extra Essence next fight.", "bridge_ok")
			await t.create_timer(0.7).timeout
			root.get_texture().get_image().save_png("%s/event_bridge_ok_mid.png" % out)
			await t.create_timer(0.5).timeout
			root.get_texture().get_image().save_png("%s/event_bridge_ok_late.png" % out)
		elif id in ["overgrown_vine", "broken_bridge"] and OS.get_environment("SHOT_HOW") != "":
			es.show_result("A reaction, told in the hint panel.", OS.get_environment("SHOT_HOW"))
			await t.create_timer(0.5).timeout
			root.get_texture().get_image().save_png("%s/event_%s_mid.png" % [out, id])
			await t.create_timer(2.5).timeout
			root.get_texture().get_image().save_png("%s/event_%s_after.png" % [out, id])
		if id == "flying_turtle":  # (the mouse on the turtle: "Help him" follows him)
			var tn: TextureRect = es._props[0].node
			var mv := InputEventMouseMotion.new()
			mv.position = tn.position + tn.size / 2.0
			es._gui_input(mv)
			await t.create_timer(0.5).timeout
			root.get_texture().get_image().save_png("%s/event_turtle_hover.png" % out)
		if id == "note_to_self":  # (the scroll was clicked: your spells stand on the stage)
			var sp: Array = []
			for sid in r.spellbook:
				sp.append({"opt": 0, "kind": "spell", "id": sid, "need": 1, "spell": r.spell(sid)})
			es.offer_items(sp, "Leave this spell in the note")
			await t.create_timer(0.8).timeout
			root.get_texture().get_image().save_png("%s/event_note_offer.png" % out)
		if id == "wax_witch":  # (the witch's option was chosen: the cards stand there; then the wax is dropped on one, SealScreen laid over the stage)
			var entries: Array = []
			for sid in r.spellbook:
				entries.append({"opt": 0, "kind": "spell", "id": sid, "need": 1, "spell": r.spell(sid)})
			es.offer_items(entries, "A drop of wax on this spell (1 of 2)")
			await t.create_timer(0.8).timeout
			root.get_texture().get_image().save_png("%s/event_%s_cards.png" % [out, id])
			es.hide_items(true)
			var seal := SealScreen.new()
			seal.setup(r, r.spellbook[0])
			seal.embedded = true
			es.add_child(seal)
			await t.create_timer(0.8).timeout
			root.get_texture().get_image().save_png("%s/event_%s_seal.png" % [out, id])
			seal._seal(0, seal._orbs.get_child(0))
			await t.create_timer(1.6).timeout
			root.get_texture().get_image().save_png("%s/event_%s_sealed.png" % [out, id])
		if id == "mystery_shack":  # (the shed was clicked: the artifacts stand in the middle; the twins can still be clicked)
			var arts: Array = []
			for aid in r.artifacts:
				arts.append({"opt": 2, "kind": "artifact", "id": aid, "need": 2, "spell": {}})
			es.offer_items(arts, "Give each a new toy")
			await t.create_timer(0.6).timeout
			root.get_texture().get_image().save_png("%s/event_%s_offer.png" % [out, id])
			var mm := InputEventMouseMotion.new()
			mm.position = Vector2(0.34 * 1920.0, 500.0)
			es._gui_input(mm)
			await t.create_timer(0.4).timeout
			root.get_texture().get_image().save_png("%s/event_%s_offer_hover_boy.png" % [out, id])
		if id == "mystery_shack" and OS.get_environment("SHOT_HOW") != "":
			es.show_result("The girl bursts into tears and runs away. The boy, very pleased with himself, rewards you with a crumpled dollar bill.", OS.get_environment("SHOT_HOW"))
			await t.create_timer(0.9).timeout
			root.get_texture().get_image().save_png("%s/event_%s_%s_mid.png" % [out, id, OS.get_environment("SHOT_HOW")])
			await t.create_timer(2.6).timeout
			root.get_texture().get_image().save_png("%s/event_%s_%s.png" % [out, id, OS.get_environment("SHOT_HOW")])
		if id == "cactus_maze":  # (a spell is chosen: the cacti burn, the result is told in the hint panel, Continue)
			es.show_result("Tailwind goes up in flames, and the fire eats a path straight through the cactus. You walk out, smelling of smoke.", "burn" if OS.get_environment("SHOT_HOW") == "" else OS.get_environment("SHOT_HOW"))
			await t.create_timer(1.0).timeout
			root.get_texture().get_image().save_png("%s/event_%s_burning.png" % [out, id])
			await t.create_timer(3.0).timeout
			root.get_texture().get_image().save_png("%s/event_%s_result.png" % [out, id])
		es.queue_free()
		await t.process_frame
	t.quit()
