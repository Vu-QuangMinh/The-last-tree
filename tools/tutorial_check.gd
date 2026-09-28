extends SceneTree
## Runs the tutorial automatically and saves a screenshot of every step (windowed).
## Usage: godot --path . --resolution 1920x1080 -s tools/tutorial_check.gd -- <out_dir>


func _init() -> void:
	await process_frame
	var args := OS.get_cmdline_user_args()
	var impl = load("res://tools/tutorial_check_impl.gd").new()
	await impl.run(self, args[0] if args.size() > 0 else "user://tutorial_check")
