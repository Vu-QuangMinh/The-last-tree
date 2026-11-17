extends SceneTree
## Burn: the burning Essence fizzle out one by one at the start of the enemy's turn. Shots along the way.
## godot --path . --position 6000,0 --no-focus --audio-driver Dummy -s tools/burn_shot.gd -- <out_dir>


func _init() -> void:
	create_timer(90).timeout.connect(quit)
	await process_frame
	var impl = load("res://tools/burn_shot_impl.gd").new()
	await impl.run(self)
