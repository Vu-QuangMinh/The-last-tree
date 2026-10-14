extends SceneTree
## Writes {name: md5 of the file UiSkin resolves it to} for every art name, for the theme in ASSET_THEME (roots in ASSET_ROOTS, output ASSET_OUT).
## Run before and after moving assets around: the files must be equal (same names -> same pictures).


func _init() -> void:
	await process_frame
	await load("res://tools/asset_map_impl.gd").new().run(self)
