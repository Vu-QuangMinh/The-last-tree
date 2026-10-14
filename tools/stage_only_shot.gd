extends SceneTree
## Only the stage (no HUD, no puppets), one screenshot: godot --path . --position 6000,0 --no-focus --audio-driver Dummy -s tools/stage_only_shot.gd -- <act> <out.png>


func _init() -> void:
	create_timer(60.0).timeout.connect(quit)
	await process_frame
	await load("res://tools/stage_only_shot_impl.gd").new().run(self)
