extends SceneTree
## Renders the element orbs (and the generic ? element) to PNGs for rich text: assets/icons/el_*.png
## Usage (windowed): godot --path . -s tools/make_icons.gd


func _init() -> void:
	await process_frame
	var vp := SubViewport.new()
	vp.size = Vector2i(64, 64)
	vp.transparent_bg = true
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(vp)
	for el in ["F", "W", "A", "?"]:
		for c in vp.get_children():
			c.queue_free()
		var icon: Control = load("res://scripts/ui/element_icon.gd").new()
		icon.el = el
		icon.size = Vector2(64, 64)
		vp.add_child(icon)
		for i in 4:
			await process_frame
		var img := vp.get_texture().get_image()
		var name: String = {"F": "fire", "W": "water", "A": "wind", "?": "any"}[el]
		img.save_png("res://assets/icons/el_%s.png" % name)
		print("saved ", name)
	quit()
