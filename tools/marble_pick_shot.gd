extends SceneTree
## The reward marble choice (Main._marble_choice) with plain and carved marbles, for checking the layout by eye.
## Usage (windowed, off screen): godot --path . --position 6000,0 --no-focus --audio-driver Dummy -s tools/marble_pick_shot.gd -- <out_dir>


func _init() -> void:
	create_timer(60.0).timeout.connect(quit)
	await process_frame
	var impl = load("res://tools/marble_pick_shot_impl.gd").new()
	await impl.run(self)
	quit()
