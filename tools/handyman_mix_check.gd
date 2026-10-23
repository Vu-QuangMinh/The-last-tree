extends SceneTree
## Test mode: the Handyman together with another enemy must not crash: godot --path . --position 6000,0 --no-focus --audio-driver Dummy -s tools/handyman_mix_check.gd


func _init() -> void:
	await process_frame
	var impl = load("res://tools/handyman_mix_check_impl.gd").new()
	await impl.run(self)
