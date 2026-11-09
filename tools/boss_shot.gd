extends SceneTree
## A still of one or more enemies in a real fight (Puppet theme): godot --path . --position 6000,0 --no-focus --audio-driver Dummy -s tools/boss_shot.gd -- <out folder> <id,id,...> [phase2]
## (window off screen, no sound: see CLAUDE.md "Testing the game"). Writes <out folder>/shot_<first id>.png


func _init() -> void:
	create_timer(120).timeout.connect(quit)
	await process_frame
	var impl = load("res://tools/boss_shot_impl.gd").new()
	await impl.run(self)
