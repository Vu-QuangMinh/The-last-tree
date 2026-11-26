extends SceneTree
## Windowed: the Ghost carving (fades, a ghost flies to your Dodge) and Focus Fire (a yellow line per Wind, its effect
## per hit) on the main fight screen.
## godot --path . --position 6000,0 --no-focus --audio-driver Dummy -s tools/ghost_focus_shot.gd -- <out dir>


func _init() -> void:
	create_timer(120.0).timeout.connect(quit)
	await process_frame
	await load("res://tools/ghost_focus_shot_impl.gd").new().run(self)
	quit()
