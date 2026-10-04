class_name Elements
extends RefCounted
## The three elements. Letters are used everywhere: F = Fire, W = Water, A = Air.

const ALL: Array[String] = ["F", "W", "A"]
const NAMES := {"F": "Fire", "W": "Water", "A": "Air", "?": "Any"}
const COLORS := {"F": Color(1.0, 0.45, 0.2), "W": Color(0.3, 0.62, 1.0), "A": Color(0.55, 0.95, 0.78), "?": Color(0.6, 0.6, 0.6)}


static func random(rng: RandomNumberGenerator) -> String:
	return ALL[rng.randi() % ALL.size()]


static func pattern_text(p: String) -> String:
	return " ".join(Array(p.split("")).map(func(c): return NAMES.get(c, c)))
