extends SceneTree
## The Veiled Eyes carrying a card off (the pose of the theft): godot --path . --position 6000,0 --no-focus -s tools/steal_shot.gd -- <out folder>


func _init() -> void:
	await process_frame
	await load("res://tools/steal_shot_impl.gd").new().run(self)
