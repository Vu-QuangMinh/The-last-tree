extends SceneTree
## The stage map is pulled up all the way, however far it has sunk (scrolled up): godot --path . --position 6000,0 --no-focus --audio-driver Dummy -s tools/map_lower_check.gd


func _init() -> void:
	await process_frame
	var impl = load("res://tools/map_lower_check_impl.gd").new()
	await impl.run(self)
