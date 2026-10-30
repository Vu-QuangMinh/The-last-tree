extends RefCounted
## The merchant's quests on screen: the mark, his first favour, handing the blanket over, and him drunk with the picture.

func run(t: SceneTree) -> void:
	var root: Window = t.root
	var out: String = OS.get_cmdline_user_args()[0] if OS.get_cmdline_user_args().size() > 0 else "user://"
	var save = root.get_node("SaveManager")
	save.use_test_file("user://merchant_quest_shot.json")
	save.data.settings["theme"] = "puppet"
	var gd = root.get_node("GameData")
	var r := RunState.new()
	r.setup(gd.db, save.unlocked_spells(), save.unlocked_artifacts(), 3)
	r.amber = 300
	var q := {"done": 0, "open": false}
	var sh := ShopScreen.new()
	sh.setup(r, r.shop_stock())
	sh.quest = q
	root.add_child(sh)
	await t.create_timer(1.5).timeout
	root.get_texture().get_image().save_png(out + "/quest_1_mark.png")
	sh._talk()
	await t.create_timer(0.5).timeout
	root.get_texture().get_image().save_png(out + "/quest_2_ask.png")
	sh._dialog_next()
	sh._dialog_next()
	await t.create_timer(0.5).timeout
	root.get_texture().get_image().save_png(out + "/quest_3_choice.png")
	sh.queue_free()
	# the next visit, blanket in hand: hand it over, the spells are free
	r.row += 1
	r.gain_artifact("blanket")
	q.open = true
	var sh2 := ShopScreen.new()
	sh2.setup(r, r.shop_stock())
	sh2.quest = q
	root.add_child(sh2)
	await t.create_timer(1.5).timeout
	sh2._talk()
	sh2._dlg_choices[0][1].call()
	await t.create_timer(0.6).timeout
	root.get_texture().get_image().save_png(out + "/quest_4_thanks.png")
	sh2._close_dialog()
	await t.create_timer(0.6).timeout
	root.get_texture().get_image().save_png(out + "/quest_5_free.png")
	sh2.queue_free()
	# all three done, a later visit: drunk, the picture on the counter
	var q3 := {"done": 3, "open": false}
	MerchantQuests.visit(q3)
	r.row += 1
	var sh3 := ShopScreen.new()
	sh3.setup(r, r.shop_stock(MerchantQuests.DISCOUNT))
	sh3.quest = q3
	root.add_child(sh3)
	await t.create_timer(1.5).timeout
	root.get_texture().get_image().save_png(out + "/quest_6_drunk.png")
	t.quit()
