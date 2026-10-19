extends SceneTree
## Frames of the Trinity cutscene (the three Fragments combine): godot --path . --position 6000,0 --no-focus --audio-driver Dummy -s tools/trinity_shot.gd -- <out folder>


func _init() -> void:
	create_timer(90).timeout.connect(quit)
	await process_frame
	var impl = load("res://tools/trinity_shot_impl.gd").new()
	await impl.run(self)
