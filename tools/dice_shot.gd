extends SceneTree
## Die on Stage: shots of the map, a fight (with a die placed), and the Merchant. Windowed:
## godot --path . --position 6000,0 --no-focus --audio-driver Dummy -s tools/dice_shot.gd -- <out_dir>


func _init() -> void:
	create_timer(90).timeout.connect(quit)
	await process_frame
	var impl = load("res://tools/dice_shot_impl.gd").new()
	await impl.run(self)
