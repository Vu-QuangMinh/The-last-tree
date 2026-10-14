extends SceneTree
## Stress test of the Bag / Chant balls (Puppet Stage): rolling balls must never stall or overlap, a ball that is clicked or dragged at any moment (even
## while the others are still rolling) must obey, and at rest nothing may stay flagged "rolling".
## godot --path . --position 6000,0 --no-focus --audio-driver Dummy -s tools/ball_stress.gd


func _init() -> void:
	await process_frame
	var impl = load("res://tools/ball_stress_impl.gd").new()
	await impl.run(self)
