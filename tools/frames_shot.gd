extends SceneTree
## The painted frames that used to be drawn in code, in one still: godot --path . --position 6000,0 --no-focus --audio-driver Dummy -s tools/frames_shot.gd -- <out.png>


func _init() -> void:
	await process_frame
	await load("res://tools/frames_shot_impl.gd").new().run(self)
