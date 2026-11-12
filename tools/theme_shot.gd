extends SceneTree
## A still of a fight in any theme: godot --path . --position 6000,0 --no-focus --audio-driver Dummy -s tools/theme_shot.gd -- <out png> <theme id: puppet|new_ui|newui2|hud2|minhhud> [enemy id]


func _init() -> void:
	create_timer(120).timeout.connect(quit)
	await process_frame
	var impl = load("res://tools/theme_shot_impl.gd").new()
	await impl.run(self)
