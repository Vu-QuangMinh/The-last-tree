extends SceneTree
## The merchant's true cart (overview -> hover -> click zooms in -> hover an item -> buy -> Back): godot --path . --position 6000,0 --no-focus --audio-driver Dummy -s tools/shop_cart_flow.gd -- <out folder>
func _init() -> void:
	await process_frame
	await load("res://tools/shop_cart_flow_impl.gd").new().run(self)
