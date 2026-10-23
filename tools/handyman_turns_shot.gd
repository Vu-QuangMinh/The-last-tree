extends SceneTree
## godot --path . --position 6000,0 --no-focus --audio-driver Dummy -s tools/handyman_turns_shot.gd -- <out folder>


func _init() -> void:
	create_timer(170.0).timeout.connect(quit)  # (a guard: an error must not leave a window hanging)
	await process_frame
	var impl = load("res://tools/handyman_turns_shot_impl.gd").new()
	await impl.run(self)
