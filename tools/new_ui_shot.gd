extends SceneTree
## New UI theme, a fight: godot --path . --position 6000,0 --no-focus --audio-driver Dummy -s tools/new_ui_shot.gd -- <out folder>
## Writes nu_start.png, nu_bonus.png (a bonus orb flies into the Bag), nu_turn0.png / nu_turn1.png / nu_turn2.png (the Pass: next turn's orbs roll out of the blue circles).


func _init() -> void:
	await process_frame
	var impl = load("res://tools/new_ui_shot_impl.gd").new()
	await impl.run(self)
