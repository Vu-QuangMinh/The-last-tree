extends SceneTree
## Screenshots of the bottles, statuses, seals, fusing and loadout-drag screens (a visual check).
## Usage (windowed): godot --path . --resolution 1920x1080 -s tools/feature_shots.gd -- <out_dir>


func _init() -> void:
	create_timer(120.0).timeout.connect(func(): print("TIMEOUT"); quit())
	await process_frame
	var impl = load("res://tools/feature_shots_impl.gd").new()
	await impl.run(self)
	quit()
