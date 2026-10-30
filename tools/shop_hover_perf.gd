extends SceneTree
## Time of a spell card's hover magnifier in the stage shop: godot --path . --position 6000,0 --no-focus --audio-driver Dummy -s tools/shop_hover_perf.gd
func _init() -> void:
	await process_frame
	await load("res://tools/shop_hover_perf_impl.gd").new().run(self)
