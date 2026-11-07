extends SceneTree
## Puppet HUD ver 2, a fight: godot --path . --resolution 1920x1080 --position 6000,0 --no-focus --audio-driver Dummy -s tools/hud2_shot.gd -- <out dir>
## Env HUD_N = "artifacts,bottles,debuffs" (default 10,5,3), HUD_FRAMES = seconds between frames of the first spawn (default 0.3, 14 frames), HUD_THEME (default hud2).
## Writes h2_<k>.png for the frames of the first spawn (the Essence run from the reels under the HUD, up the tube, out of the hole and along the tray), then h2_end.png.


func _init() -> void:
	await process_frame
	var impl = load("res://tools/hud2_shot_impl.gd").new()
	await impl.run(self)
