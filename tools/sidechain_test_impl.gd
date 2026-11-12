extends RefCounted


func _level(bus: int) -> float:
	var m := -200.0
	for i in 12:  # (the loudest of a short run of readings)
		m = maxf(m, AudioServer.get_bus_peak_volume_left_db(bus, 0))
	return m


func run(t: SceneTree) -> void:
	var au = t.root.get_node("Audio")
	var mb := AudioServer.get_bus_index("Music")
	var hb := AudioServer.get_bus_index("HitSfx")
	print("buses: ", AudioServer.bus_count, "  Music effects: ", AudioServer.get_bus_effect_count(mb), "  HitSfx effects: ", AudioServer.get_bus_effect_count(hb))
	au.play_music("fight")
	await t.create_timer(1.5).timeout
	print("music alone:            %.1f dB" % _level(mb))
	for name in ["sfx_extension", "bell_strike", "spell_glow"]:
		au.play(name)
		await t.create_timer(0.12).timeout
		var a := _level(mb)
		await t.create_timer(0.4).timeout
		var b := _level(mb)
		await t.create_timer(0.8).timeout
		var c := _level(mb)
		await t.create_timer(3.5).timeout
		var d := _level(mb)
		print("%-14s 0.1s %.1f  0.5s %.1f  1.3s %.1f  after %.1f dB" % [name, a, b, c, d])
	# the low-priority hit: alone, then together with an enemy sound
	au.stop_music()
	await t.create_timer(0.5).timeout
	au.play("sfx_player_hit")
	await t.create_timer(0.2).timeout
	var alone := _level(hb)
	await t.create_timer(2.0).timeout
	au.play("bell_strike")
	au.play("sfx_player_hit")
	await t.create_timer(0.2).timeout
	var together := _level(hb)
	print("sfx_player_hit alone: %.1f dB   with bell_strike at the same time: %.1f dB" % [alone, together])
	t.quit()
