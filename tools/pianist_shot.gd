extends SceneTree
## The Pianist at his piano: godot --path . --position 6000,0 --no-focus --audio-driver Dummy -s tools/pianist_shot.gd -- <out folder>


func _init() -> void:
	create_timer(90).timeout.connect(quit)
	await process_frame
	var impl = load("res://tools/pianist_shot_impl.gd").new()
	await impl.run(self)
