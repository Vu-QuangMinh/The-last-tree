extends RefCounted
const CASES := [
	["well", "well_toss", "The well seems pleased with your leaves."], ["well", "well_drink", "The well was not pleased."], ["well", "well_jump", "At the bottom you find a cursed artifact."],
	["lost_sprite", "sprite_help", "The monster is indeed very mean."], ["lost_sprite", "sprite_sad", "The wind sprite stops crying."],
	["mushroom_ring", "mush_bad", "It was poisonous."], ["mushroom_ring", "mush_good", "It was edible."], ["mushroom_ring", "mush_great", "It was miraculous!"],
	["hollow_stump", "reach_bottle", "Your fingers close around a little bottle."], ["hollow_stump", "reach_leaves", "30 Leaves."], ["hollow_stump", "reach_bite", "Something bites you."],
	["hollow_stump", "reach_artifact", "an artifact!"], ["hollow_stump", "throw_fight", "it is coming out"], ["hollow_stump", "throw_quiet", "You hear it shatter."], ["hollow_stump", "throw_bottles", "Three broken bottles."],
	["bard", "bard_angry", "He is furious."], ["bard", "bard_song", "He plays you a song."], ["bard", "bard_lute", "He hands you his lute."],
	["cursed_shrine", "idol_bite", "Its jaw snaps shut."], ["cursed_shrine", "idol_leaves", "The idol bites you."], ["cursed_shrine", "idol_gift", "The idol seems pleased."],
	["lost_camp", "bed_toss", "You toss and turn."],
	["mausoleum", "orb_red", "The red light."], ["mausoleum", "orb_blue", "The blue light."], ["mausoleum", "orb_green", "The green light."],
	["watchtower", "watch_camp", "A thin line of smoke."], ["watchtower", "watch_monster", "Something enormous."], ["watchtower", "watch_cart", "A familiar cart."],
	["skipping_stones", "skip", "Your stone skips 9 times across the water before it sinks."], ["skipping_stones", "skip", "Your stone skips 21 times, all the way to the far shore!"],
]


func run(t: SceneTree) -> void:
	var root: Window = t.root
	var args := OS.get_cmdline_user_args()
	var out: String = args[0] if args.size() > 0 else "user://"
	var only: Array = args.slice(1)
	var save = root.get_node("SaveManager")
	save.use_test_file("user://event_batch2_test.json")
	save.data.settings["theme"] = "puppet"
	var gd = root.get_node("GameData")
	var r := RunState.new()
	r.setup(gd.db, save.unlocked_spells(), save.unlocked_artifacts(), 3)
	var fs := FightScreen.new()
	fs.setup(r, r.make_fight([]))
	fs.stage_flow = true
	fs.map_mode = true
	root.add_child(fs)
	await t.create_timer(2.5).timeout
	var n := 0
	for c: Array in CASES:
		if not only.is_empty() and not (c[1] in only):
			continue
		var es := EventStage.new()
		es.ev = MapEvents.get_event(c[0])
		es.act = 2 if c[0] in ["mausoleum", "watchtower", "skipping_stones"] else 1
		es.on_stage = true
		es.z_index = PuppetStage.CEILING_Z + 2
		fs.add_child(es)
		fs.peek_hud(not EventStage.LAYOUTS[c[0]].get("no_hud", false))
		await t.create_timer(2.0).timeout
		es.show_result(c[2], c[1])
		await t.create_timer(1.3).timeout
		n += 1
		root.get_texture().get_image().save_png("%s/b2_%02d_%s.png" % [out, n, c[1]])
		await t.create_timer(2.6).timeout
		es.queue_free()
		await t.process_frame
	print("TEST DONE ", n)
	t.quit()
