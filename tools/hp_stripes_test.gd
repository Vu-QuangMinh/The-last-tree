extends SceneTree
## godot --path . --position 6000,0 --no-focus -s tools/hp_stripes_test.gd : the stripe HP bar in states, pictures in C:/temp/hp_*.png (crops of the HP bar)


func _init() -> void:
	await process_frame
	await load("res://tools/hp_stripes_test_impl.gd").new().run(self)
