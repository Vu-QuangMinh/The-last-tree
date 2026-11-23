extends SceneTree
## Stills of the Bug Hunter in a real fight (Puppet theme): idle, the arm lowered, the blow with its rings of sound. godot --path . --position 6000,0 --no-focus --audio-driver Dummy -s tools/bug_hunter_shot.gd -- <out folder>


func _init() -> void:
	create_timer(120).timeout.connect(quit)
	await process_frame
	var impl = load("res://tools/bug_hunter_shot_impl.gd").new()
	await impl.run(self)
