extends SceneTree
## New UI theme: the orbs of a spawn go down the tube, under the clamp, come up out of the hole and roll. godot --path . --position 6000,0 --no-focus --audio-driver Dummy -s tools/nu_rise_shot.gd -- <out folder>
## Writes rise_NNN.png (the right end of the Bag tray, every 4th frame from the Pass) and prints where the new orbs are while they are not resting.


func _init() -> void:
	await process_frame
	var impl = load("res://tools/nu_rise_shot_impl.gd").new()
	await impl.run(self)
