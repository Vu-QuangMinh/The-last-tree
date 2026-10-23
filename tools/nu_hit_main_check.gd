extends SceneTree
## New UI, a heavy hit through the real flow: godot --path . --position 6000,0 --no-focus --audio-driver Dummy -s tools/nu_hit_main_check.gd -- <out folder>


func _init() -> void:
	await process_frame
	var impl = load("res://tools/nu_hit_main_check_impl.gd").new()
	await impl.run(self)
