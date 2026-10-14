extends SceneTree
## The Victory / Boss Defeated board dropped on the stage: godot --path . --position 6000,0 --no-focus -s tools/boss_sign_shot.gd -- <out folder>


func _init() -> void:
	await process_frame
	await load("res://tools/boss_sign_shot_impl.gd").new().run(self)
