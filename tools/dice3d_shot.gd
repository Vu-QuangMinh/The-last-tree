extends SceneTree
## Die on Stage: the 3D dice throw, in frames. Windowed:
## godot --path . --position 6000,0 --no-focus --audio-driver Dummy -s tools/dice3d_shot.gd -- <out_dir>


func _init() -> void:
	create_timer(60).timeout.connect(quit)
	await process_frame
	var impl = load("res://tools/dice3d_shot_impl.gd").new()
	await impl.run(self)
	quit()
