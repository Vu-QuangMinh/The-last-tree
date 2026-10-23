extends SceneTree
## The Hammer Hand reaching a card and the Crossbow Hand's bolt: godot --path . --position 6000,0 --no-focus --audio-driver Dummy -s tools/handyman_weapons_shot.gd -- <out folder>


func _init() -> void:
	create_timer(120.0).timeout.connect(quit)  # (a guard: an error must not leave a window hanging)
	await process_frame
	var impl = load("res://tools/handyman_weapons_shot_impl.gd").new()
	await impl.run(self)
