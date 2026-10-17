extends SceneTree
## The steal cursor (open hand, fist holding an Essence): godot --path . --position 6000,0 --no-focus --audio-driver Dummy -s tools/cursor_hand_shot.gd -- <out.png>


func _init() -> void:
	await process_frame
	await load("res://tools/cursor_hand_shot_impl.gd").new().run(self)
