extends SceneTree
## godot --path . --position 6000,0 --no-focus -s tools/f4_hit_test.gd : which control is under each F4 point button in a real fight?


func _init() -> void:
	await process_frame
	await load("res://tools/f4_hit_test_impl.gd").new().run(self)
