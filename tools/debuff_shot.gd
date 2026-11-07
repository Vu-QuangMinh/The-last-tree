extends SceneTree
## The player's debuffs on screen: Ignite and Virus badges on cards, Burden's stone slots, Confuse's veil over the slot
## machine. godot --path . --position 6000,0 --no-focus --audio-driver Dummy -s tools/debuff_shot.gd -- <out folder>


func _init() -> void:
	create_timer(90).timeout.connect(quit)
	await process_frame
	var impl = load("res://tools/debuff_shot_impl.gd").new()
	await impl.run(self)
