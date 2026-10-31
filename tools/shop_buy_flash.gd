extends SceneTree
## Looks for a flash after a purchase in the stage shop: godot --path . --position 6000,0 --no-focus --audio-driver Dummy -s tools/shop_buy_flash.gd -- <out folder>
func _init() -> void:
	await process_frame
	await load("res://tools/shop_buy_flash_impl.gd").new().run(self)
