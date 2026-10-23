extends SceneTree
## The Veiled Eyes' unveiling, frame by frame: godot --path . --position 6000,0 --no-focus -s tools/unveil_shot.gd -- <out folder>


func _init() -> void:
	await process_frame
	await load("res://tools/unveil_shot_impl.gd").new().run(self)
