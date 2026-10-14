extends SceneTree
## godot --path . --position 6000,0 --no-focus -s tools/stage_flow_test.gd : the whole stay-on-the-stage run flow, with pictures in C:/temp/sf_*.png


func _init() -> void:
	await process_frame
	await load("res://tools/stage_flow_test_impl.gd").new().run(self)
