extends SceneTree
## Die on Stage: shots of the Slay the Spire map and a card offer with a card you have. Windowed:
## godot --path . --position 6000,0 --no-focus --audio-driver Dummy -s tools/dice_sts_shot.gd -- <out_dir>


func _init() -> void:
	create_timer(60).timeout.connect(quit)
	await process_frame
	var impl = load("res://tools/dice_sts_shot_impl.gd").new()
	await impl.run(self)
	quit()
