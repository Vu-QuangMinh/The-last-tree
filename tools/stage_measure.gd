extends SceneTree
## Measures what the Puppet stage's pictures really are on screen (1920 x 1080), using the points the game has now (the user's F4 file included):
## godot --headless --path . --script res://tools/stage_measure.gd -- <act>        (no window, no sound)


func _init() -> void:
	create_timer(60.0).timeout.connect(quit)  # (a script error must never leave it hanging)
	await process_frame
	await load("res://tools/stage_measure_impl.gd").new().run(self)
