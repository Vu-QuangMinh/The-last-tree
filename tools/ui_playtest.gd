extends SceneTree
## Plays a full run through the real UI (sped up) and saves screenshots.
## Usage (windowed): godot --path . --resolution 1920x1080 -s tools/ui_playtest.gd -- <out_dir>


func _init() -> void:
	await process_frame
	var args := OS.get_cmdline_user_args()
	var out: String = args[0] if args.size() > 0 else "user://ui_playtest"
	var impl = load("res://tools/ui_playtest_impl.gd").new()
	await impl.run(self, out)
