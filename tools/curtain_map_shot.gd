extends SceneTree
## The Curtain map on the stage: godot --path . --position 6000,0 --no-focus --audio-driver Dummy -s tools/curtain_map_shot.gd -- <out_dir>


func _init() -> void:
	create_timer(90).timeout.connect(quit)
	await process_frame
	var impl = load("res://tools/curtain_map_shot_impl.gd").new()
	await impl.run(self)
