extends SceneTree
## Records frames of anti-spell (negative) and Ephemeral (bad reception) cards, ending with one Ephemeral card
## switching off, for a GIF. Usage (windowed): godot --path . --resolution 1920x1080 -s tools/card_fx_gif.gd -- <out_prefix>


func _init() -> void:
	create_timer(60.0).timeout.connect(quit)
	await process_frame
	await load("res://tools/card_fx_gif_impl.gd").new().run(self)
	quit()
