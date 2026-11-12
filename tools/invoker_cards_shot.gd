extends SceneTree
## The Good Ol' Wizard's three spell cards, then (second wind) upgraded: godot --path . --position 6000,0 --no-focus --audio-driver Dummy -s tools/invoker_cards_shot.gd -- <out_dir>


func _init() -> void:
	create_timer(90).timeout.connect(quit)
	await process_frame
	var impl = load("res://tools/invoker_cards_shot_impl.gd").new()
	await impl.run(self)
