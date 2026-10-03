extends RefCounted


func run(t: SceneTree) -> void:
	var root := t.root
	var gd = root.get_node("GameData")
	var out: String = OS.get_cmdline_user_args()[0]
	var bg := ColorRect.new()
	bg.color = Color(0.1, 0.13, 0.11)
	bg.size = Vector2(1920, 1080)
	root.add_child(bg)
	var row := HBoxContainer.new()
	row.position = Vector2(40, 300)
	row.add_theme_constant_override("separation", 20)
	root.add_child(row)
	var cards := []
	# two anti-spells, two Ephemeral spells, and a normal spell for comparison
	for id in ["smolder", "fog_of_war", "flame_lash", "healing_rain", "fire_ball"]:
		var s: Dictionary = gd.db.get_spell(id).duplicate(true)
		if id in ["flame_lash", "healing_rain"]:
			s.ephemeral = true
		var c := SpellCard.make(s)
		c.theme = UiTheme.get_theme()
		row.add_child(c)
		cards.append(c)
	for i in 10:
		await t.process_frame
	var k := 0
	# about 4 seconds of them as they are (glitches come every 1-2 s), then one switches off
	for f in 120:
		await t.process_frame
		if f % 2 == 0:
			root.get_texture().get_image().save_png("%s_%03d.png" % [out, k])
			k += 1
	cards[2].fizzle_out()
	for f in 50:
		await t.process_frame
		if f % 2 == 0:
			root.get_texture().get_image().save_png("%s_%03d.png" % [out, k])
			k += 1
	print("FRAMES ", k)
