extends SceneTree
## The Samurai and his Retainer on stage, and a frame of his Deflect: godot --path . --position 6000,0 --no-focus --audio-driver Dummy -s tools/samurai_shot.gd -- <out folder>


func _init() -> void:
	create_timer(150).timeout.connect(quit)
	await process_frame
	var impl = load("res://tools/samurai_shot_impl.gd").new()
	await impl.run(self)
