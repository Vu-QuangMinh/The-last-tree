extends SceneTree
## The fight's row of spell cards with 5 and with 8 cards: godot --path . --position 6000,0 --no-focus --audio-driver Dummy -s tools/card_row_shot.gd -- <out_dir> [theme]


func _init() -> void:
	create_timer(90).timeout.connect(quit)
	await process_frame
	var impl = load("res://tools/card_row_shot_impl.gd").new()
	await impl.run(self)
