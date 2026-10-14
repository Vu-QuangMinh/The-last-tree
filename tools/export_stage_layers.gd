extends SceneTree
## Renders the Puppet Stage fight screen layer by layer (transparent PNG, 2x) + layout.json, for tools/build_layout_pdf.py.
## godot --path . --position 6000,0 --no-focus -s tools/export_stage_layers.gd -- <out_dir>


func _init() -> void:
	await process_frame
	var impl = load("res://tools/export_stage_layers_impl.gd").new()
	await impl.run(self)
