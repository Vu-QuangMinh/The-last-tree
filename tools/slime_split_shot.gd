extends SceneTree
## The Giant Slime dies and its pieces fly into its two slimes: shots along the way. godot --path . --position 6000,0 --no-focus --audio-driver Dummy -s tools/slime_split_shot.gd -- <out_dir>


func _init() -> void:
	create_timer(90).timeout.connect(quit)
	await process_frame
	var impl = load("res://tools/slime_split_shot_impl.gd").new()
	await impl.run(self)
