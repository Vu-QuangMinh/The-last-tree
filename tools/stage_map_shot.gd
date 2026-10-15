extends SceneTree
## The Puppet Stage map (ropes hanging from the ceiling): godot --path . --position 6000,0 --no-focus -s tools/stage_map_shot.gd -- <out_dir>


func _init() -> void:
	await process_frame
	var impl = load("res://tools/stage_map_shot_impl.gd").new()
	await impl.run(self)
