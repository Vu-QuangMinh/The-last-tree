extends RefCounted
## Writes every spell as the game shows it (its card text, from SpellText) to a JSON file, for tools/spell_sheet.py.
## Usage: godot --headless --path . -s tools/dump_spells.gd -- <out.json>


func run(t: SceneTree) -> void:
	var out: String = OS.get_cmdline_user_args()[0]
	var db = t.root.get_node("GameData").db
	var rows := []
	for s in db.all_spells:
		rows.append({
			"id": s.id, "name": s.name, "pattern": s.pattern, "rarity": s.rarity,
			"category": SpellDB.KIND_NAMES[s.kind], "text": SpellText.card_text(s).replace("\n", " "),
			"anti": s.get("anti", false), "power": s.get("power", false), "fleeting": s.get("fleeting", false),
			"starter": s.get("starter", false), "cooldown": int(s.get("cooldown", 0)), "flavor": s.get("flavor", ""),
		})
	var f := FileAccess.open(out, FileAccess.WRITE)
	f.store_string(JSON.stringify(rows, " "))
	f.close()
	print("DUMPED %d spells" % rows.size())
