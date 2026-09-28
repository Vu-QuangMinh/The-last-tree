extends Node
## Static game data: the spell database.

var db: SpellDB


func _init() -> void:
	db = SpellDB.load_from("res://data/spells.json")


func spell_color(pattern: String) -> Color:
	var c := Color(0, 0, 0, 0)
	for ch in pattern:
		c += Elements.COLORS[ch]
	c /= pattern.length()
	c.a = 1.0
	return c
