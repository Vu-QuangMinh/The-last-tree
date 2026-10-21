extends SceneTree
## godot --path . --position 6000,0 --no-focus -s tools/hp_blocks_test.gd : the block HP bar in states, pictures in C:/temp/hp_*.png (crops of the HP corner)


func _init() -> void:
	await process_frame
	await load("res://tools/hp_blocks_test_impl.gd").new().run(self)
