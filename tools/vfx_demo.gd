extends SceneTree
## Plays every spell effect's VFX in a staged fight and saves frames (for checking the effects by eye).
## Usage (windowed): godot --path . --resolution 1920x1080 -s tools/vfx_demo.gd -- <out_dir> [op,op,...]


func _init() -> void:
	create_timer(240.0).timeout.connect(quit)
	await process_frame
	var impl = load("res://tools/vfx_demo_impl.gd").new()
	await impl.run(self)
	quit()
