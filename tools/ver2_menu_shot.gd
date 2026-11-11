extends SceneTree
## NewUI Ver2 pause menu + family buttons + a panel: godot --path . --position 6000,0 --no-focus --audio-driver Dummy -s tools/ver2_menu_shot.gd -- <out folder>


func _init() -> void:
	await process_frame
	var impl = load("res://tools/ver2_menu_shot_impl.gd").new()
	await impl.run(self)
