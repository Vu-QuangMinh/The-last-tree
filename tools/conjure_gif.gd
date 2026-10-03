extends SceneTree
## Records the Conjure split / merge on a real fight screen (frames for a GIF).
## Usage (windowed): godot --path . --resolution 1920x1080 -s tools/conjure_gif.gd -- <out_prefix>


func _init() -> void:
	create_timer(60.0).timeout.connect(quit)
	await process_frame
	await load("res://tools/conjure_gif_impl.gd").new().run(self)
	quit()
