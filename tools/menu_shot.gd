extends SceneTree
## The Puppet Stage main menu: godot --path . --position 6000,0 --no-focus --audio-driver Dummy -s tools/menu_shot.gd -- <out folder>   (menu_0.png ... every 4 s)


func _init() -> void:
	await process_frame
	var impl = load("res://tools/menu_shot_impl.gd").new()
	await impl.run(self)
