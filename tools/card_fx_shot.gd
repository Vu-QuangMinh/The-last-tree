extends SceneTree
## Frames of a few cards' own effects (CardFx) in a real marble fight, for judging by eye.
## Usage (windowed, off screen): godot --path . --position 6000,0 --no-focus --audio-driver Dummy -s tools/card_fx_shot.gd -- <out_dir> [id,id,...]


func _init() -> void:
	create_timer(240.0).timeout.connect(quit)
	await process_frame
	var impl = load("res://tools/card_fx_shot_impl.gd").new()
	await impl.run(self)
	quit()
