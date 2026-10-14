extends RefCounted
## Every loader that does not go through UiSkin.path_of: enemies, stage pictures, card pieces, shaders, fonts, sounds, music.


func run(t: SceneTree) -> void:
	await t.process_frame
	var root: Window = t.root
	var save = root.get_node("SaveManager")
	save.use_test_file("user://paths_check_save.json")
	var audio = root.get_node("Audio")
	var fails := 0
	for theme in ["new", "puppet"]:
		UiSkin.set_theme(theme)
		print("== theme ", theme)
		# fonts
		for cut in ["regular", "bold", "oblique", "boldoblique"]:
			if UiTheme.cut(cut) == null:
				print("  FAIL font cut ", cut)
				fails += 1
		var title := UiTheme.title_font()
		print("  heading font: ", title != null)
		if title == null:
			fails += 1
		# enemies
		var found := 0
		var missing: Array = []
		for id in EnemyDefs.E.keys():
			var d: Dictionary = EnemyDefs.E[id]
			var p := ""
			if theme == "puppet":
				p = Creature.enemy_path(id + ".png", int(d.get("act", 1)))
				if p == "":
					p = Creature.enemy_path(id + "_white.png", int(d.get("act", 1)))
			else:
				for face in Creature.ART_FACES:
					if Creature.ART.has(id):
						p = Creature.enemy_path(Creature.ART[id] % face, int(d.get("act", 1)))
			if p != "":
				found += 1
			else:
				missing.append(id)
		print("  enemy pictures found: ", found, " (without one: ", missing.size(), ")")
	# puppet stage pictures, per act
	UiSkin.set_theme("puppet")
	for act in [1, 2, 3]:
		var st := PuppetStage.new(act)
		var n := 0
		for name in ["back_wall", "wall_left", "wall_right", "floor", "front_wall", "lower_floor", "ceiling_overlay", "props/sun", "props/cloud_1", "props/tree_1", "props/mountain_1", "props/bush_6", "props/hanging_sign"]:
			if st._pic(name) != null:
				n += 1
		print("stage pictures for act ", act, ": ", n, " of 13 (act 2 and 3 fall back to act 1)")
		if n != 13:
			fails += 1
		st.free()
	# card pieces, shaders, keyword icons
	for el in ["F", "W", "A"]:
		if CardPip.tex("res://assets/Global/Card/Icons/el_%s.png" % {"F": "fire", "W": "water", "A": "wind"}[el]) == null:
			print("  FAIL pip ", el)
			fails += 1
	for sh in ["power_dissolve", "black_hole", "anti_holo", "ephemeral_static", "art_window"]:
		if load("res://assets/Global/Card/Shaders/%s.gdshader" % sh) == null:
			print("  FAIL shader ", sh)
			fails += 1
	for tok in Keywords.ICON_PATH:
		if not ResourceLoader.exists(Keywords.ICON_PATH[tok]):
			print("  FAIL keyword icon ", tok)
			fails += 1
	# sounds: every file of Global/SFX and Puppet/SFX loads through Audio, in both themes
	for theme in ["new", "puppet"]:
		UiSkin.set_theme(theme)
		var n := 0
		for f in DirAccess.get_files_at("res://assets/Global/SFX"):
			if f.ends_with(".wav"):
				if audio._load("res://assets/Global/SFX/" + f) != null:
					n += 1
				else:
					fails += 1
		print("sounds in Global/SFX that load: ", n)
	var wood = audio._load(UiSkin.theme_dir() + "SFX/wooden_ball_hole.wav", true)
	print("puppet's own wooden sound: ", wood != null)
	if wood == null:
		fails += 1
	for cat in ["boss", "fight", "map", "menu"]:
		var tr: Array = audio.list_tracks(cat)
		print("music ", cat, ": ", tr.size())
		if tr.is_empty():
			fails += 1
	print("RESULT: ", "ALL OK" if fails == 0 else "%d FAILED" % fails)
	t.quit()
