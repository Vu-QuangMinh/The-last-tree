extends SceneTree
## godot --path . --position 6000,0 --no-focus -s tools/side_panels_test.gd : artifacts + bottles frames and the Menu button, in a fight and between fights. Pictures in C:/temp/sp_*.png


func _init() -> void:
	await process_frame
	await load("res://tools/side_panels_test_impl.gd").new().run(self)
