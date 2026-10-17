extends SceneTree
## godot --path . --position 6000,0 --no-focus -s tools/new_run_test.gd : New run with a saved run: pop-up on the menu stage, drapes, keepsakes, map. Pictures in C:/temp/nr_*.png


func _init() -> void:
	await process_frame
	await load("res://tools/new_run_test_impl.gd").new().run(self)
