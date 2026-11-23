extends SceneTree
## Headless: Godot --headless --audio-driver Dummy --path . --script res://tools/act1_turns.gd
## How many turns the Act 1 fights take: a bot plays whole Act 1 runs (tools/act1_turns_impl.gd).


func _init() -> void:
	create_timer(240).timeout.connect(quit)
	await process_frame
	load("res://tools/act1_turns_impl.gd").new().run()
	quit()
