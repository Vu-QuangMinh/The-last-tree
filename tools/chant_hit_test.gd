extends SceneTree
## Which controls sit over each chant slot (a click on a slot that does nothing means a control is in the way):
## godot --path . --position 6000,0 --no-focus -s tools/chant_hit_test.gd -- <enemy,ids>


func _init() -> void:
	await process_frame
	await load("res://tools/chant_hit_test_impl.gd").new().run(self)
