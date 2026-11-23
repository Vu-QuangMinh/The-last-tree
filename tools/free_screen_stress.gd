extends SceneTree
## Frees the FightScreen in the middle of its effects (what F5 in the test room does) and looks for "previously freed" errors in the log:
## godot --path . --position 6000,0 --no-focus --audio-driver Dummy -s tools/free_screen_stress.gd 2>&1 | grep -i "freed\|SCRIPT ERROR"


func _init() -> void:
	create_timer(300).timeout.connect(quit)
	await process_frame
	var impl = load("res://tools/free_screen_stress_impl.gd").new()
	await impl.run(self)
