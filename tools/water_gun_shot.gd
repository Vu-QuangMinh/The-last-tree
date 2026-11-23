extends SceneTree
## Windowed: Water Gun's live X on the main fight screen. godot --path . --position 6000,0 --no-focus --audio-driver Dummy -s tools/water_gun_shot.gd -- <out dir>


func _init() -> void:
	create_timer(120.0).timeout.connect(quit)
	await process_frame
	await load("res://tools/water_gun_shot_impl.gd").new().run(self)
	quit()
