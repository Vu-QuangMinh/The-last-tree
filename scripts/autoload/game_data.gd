extends Node
## Static game data: the spell database.

var db: SpellDB


func _init() -> void:
	db = SpellDB.from_marbles()  # (the new cards, 2026-11-21; data/spells.json: the old 200 spells, tests only)


func spell_color(pattern: String) -> Color:
	if pattern.is_empty():
		return Color(1.0, 0.85, 0.4)
	var c := Color(0, 0, 0, 0)
	for ch in pattern:
		c += Elements.COLORS.get(ch, Color(0.6, 0.6, 0.6))
	c /= pattern.length()
	c.a = 1.0
	return c
