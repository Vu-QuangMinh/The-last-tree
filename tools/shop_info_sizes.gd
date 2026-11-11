extends SceneTree
## The shop's info board with short and long artifact texts (Fire Emblem, Lucky Acorn, Echo Chamber): its size, a screenshot of each, and the slide back behind the shelf.
## godot --path . --position 6000,0 --no-focus --audio-driver Dummy -s tools/shop_info_sizes.gd -- <out folder>


func _init() -> void:
	await process_frame
	create_timer(90.0).timeout.connect(quit)
	await load("res://tools/shop_info_sizes_impl.gd").new().run(self)
