extends SceneTree
## The merchant screen (Puppet): godot --path . --position 6000,0 --no-focus --audio-driver Dummy -s tools/shop_shot.gd -- <out folder>
func _init() -> void:
	await process_frame
	await load("res://tools/shop_shot_impl.gd").new().run(self)
