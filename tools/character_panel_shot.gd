extends SceneTree
## A still of the Puppet Stage fight with EVERYTHING in the Character panel (all statuses, 5 bottles, 24 artifacts, Leaves, Shield) and the
## artifact grid open: godot --path . --position 6000,0 --no-focus --resolution 1920x1080 -s tools/character_panel_shot.gd -- <out.png>


func _init() -> void:
	await process_frame
	var impl = load("res://tools/character_panel_shot_impl.gd").new()
	await impl.run(self)
