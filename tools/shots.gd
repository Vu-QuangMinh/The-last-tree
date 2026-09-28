extends SceneTree
## Renders each screen to PNG for a visual check (the work is in shots_impl.gd, loaded after autoloads exist).
## Usage (windowed): godot --path . --resolution 1920x1080 -s tools/shots.gd -- <out_dir>


func _init() -> void:
	await process_frame
	var impl = load("res://tools/shots_impl.gd").new()
	await impl.run(self)
