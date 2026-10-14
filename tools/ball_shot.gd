extends SceneTree
## Frames of the Puppet Stage ball machine (Essence a Lens gives back / a spell sends for next turn): godot --path . --position 6000,0 --no-focus --audio-driver Dummy -s tools/ball_shot.gd -- <out folder>
## Writes ball_000.png ... (the lower right of the screen every 0.15 s).


func _init() -> void:
	await process_frame
	var impl = load("res://tools/ball_shot_impl.gd").new()
	await impl.run(self)
