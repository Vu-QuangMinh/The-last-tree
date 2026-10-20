extends SceneTree
## The Handyman's new fight (hands fall to the floor, the next one grows, last stand): godot --path . --position 6000,0 --no-focus --audio-driver Dummy -s tools/handyman_fall_shot.gd -- <out folder>
## Writes hf_*.png.


func _init() -> void:
	create_timer(120.0).timeout.connect(quit)  # (a guard: an error must not leave a window hanging)
	await process_frame
	var impl = load("res://tools/handyman_fall_shot_impl.gd").new()
	await impl.run(self)
