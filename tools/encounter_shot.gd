extends SceneTree
## A fight against these enemies, in Puppet, a few seconds in: godot --path . --position 6000,0 --no-focus --audio-driver Dummy -s tools/encounter_shot.gd -- <out.png> <id> [<id> ...]


func _init() -> void:
	create_timer(90).timeout.connect(quit)
	await process_frame
	var impl = load("res://tools/encounter_shot_impl.gd").new()
	await impl.run(self)
