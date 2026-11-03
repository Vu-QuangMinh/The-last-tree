extends SceneTree
## A boss's talk (BossTalk), one still after the first line and one after picking the first option: BOSS=handyman|invoker SHOT_THEME=puppet|new_ui godot --path . --position 6000,0 --no-focus --audio-driver Dummy -s tools/boss_talk_shot.gd -- <out folder>


func _init() -> void:
	await process_frame
	await load("res://tools/boss_talk_shot_impl.gd").new().run(self)
