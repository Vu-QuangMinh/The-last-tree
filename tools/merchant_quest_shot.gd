extends SceneTree
## godot --path . --position 6000,0 --no-focus --audio-driver Dummy -s tools/merchant_quest_shot.gd -- <out dir>


func _init() -> void:
	create_timer(120).timeout.connect(quit)
	await process_frame
	var impl = load("res://tools/merchant_quest_shot_impl.gd").new()
	await impl.run(self)
