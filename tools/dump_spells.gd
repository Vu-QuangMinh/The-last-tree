extends SceneTree
## Dumps every spell as the game shows it, to JSON (see dump_spells_impl.gd; tools/spell_sheet.py makes the sheet).
## Usage: godot --headless --path . -s tools/dump_spells.gd -- <out.json>


func _init() -> void:
	create_timer(60.0).timeout.connect(func(): print("TIMEOUT"); quit())
	await process_frame
	var impl = load("res://tools/dump_spells_impl.gd").new()
	await impl.run(self)
	quit()
