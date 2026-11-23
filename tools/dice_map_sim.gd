extends SceneTree
## Die on Stage: the zoned map with the boss chase, movement only (every fight won). 100 runs per policy; how many tiles,
## fights, dice mods, cards, artifacts before the boss catches you. godot --headless --path . -s tools/dice_map_sim.gd


func _init() -> void:
	create_timer(120).timeout.connect(quit)
	await process_frame
	var impl = load("res://tools/dice_map_sim_impl.gd").new()
	impl.run(self)
	quit()
