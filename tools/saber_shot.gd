extends SceneTree
## The damage VFX (SaberSlash) in a real fight, at 6 moments: godot --path . --position 6000,0 --no-focus --audio-driver Dummy -s tools/saber_shot.gd -- <out folder> [blocked]  (sb_0..5.png)


func _init() -> void:
	create_timer(120).timeout.connect(quit)
	await process_frame
	var impl = load("res://tools/saber_shot_impl.gd").new()
	await impl.run(self)
