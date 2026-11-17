class_name DiceFace
extends RefCounted
## Die on Stage (2026-11-16): a die's face is {v: its number, paint: a colour or "", carve: a symbol or ""}. Three kinds
## of dice mods change a face for good (the face that shows when your dice are rolled, on the die you pick):
##   adjustment: its number -3 to +3 (never below 0, no top limit);
##   painting: one of PAINTS (what it does when that face is used in a move, or when it shows: purple);
##   carving (rarer): one of CARVES (what it does every time that face is rolled).

const PAINTS := {
	"red": {"col": Color(0.85, 0.2, 0.18), "name": "Red", "text": "The move it is used in deals double damage."},
	"blue": {"col": Color(0.25, 0.45, 0.9), "name": "Blue", "text": "The move it is used in gives double Shield."},
	"yellow": {"col": Color(0.95, 0.8, 0.2), "name": "Yellow", "text": "Used in a move: gain 3 coins."},
	"black": {"col": Color(0.15, 0.13, 0.14), "name": "Black", "text": "Used in a move, it doesn't use the move up: the move can take dice again this turn (the die must still fit)."},
	"orange": {"col": Color(0.95, 0.5, 0.12), "name": "Orange", "text": "The move it is used in applies double Burn."},
	"purple": {"col": Color(0.55, 0.3, 0.75), "name": "Purple", "text": "When it shows, you may roll it again (once)."},
}
const CARVES := {
	"heart": {"sym": "♥", "name": "Heart", "text": "Every time it is rolled: heal 3 HP."},
	"dice": {"sym": "⚄", "name": "Dice", "text": "Every time it is rolled: roll one more d6 this turn."},
	"sword": {"sym": "🗡", "name": "Sword", "text": "Every time it is rolled: deal damage equal to the total of your dice to a random enemy."},
	"wing": {"sym": "🪽", "name": "Wing", "text": "Every time it is rolled: gain 1 Dodge (the next attack on you misses)."},
	"skull": {"sym": "☠", "name": "Skull", "text": "Every time it is rolled: your moves deal double damage this turn."},
	"shield": {"sym": "🛡", "name": "Shield", "text": "Every time it is rolled: your moves give double Shield this turn."},
}


static func make(v: int) -> Dictionary:
	return {"v": v, "paint": "", "carve": ""}


## A plain d6: six faces 1 to 6.
static func d6() -> Array:
	return dn(6)


## A plain die of `sides` faces, 1 to sides (a d4, a d10...).
static func dn(sides: int) -> Array:
	var out := []
	for v in range(1, sides + 1):
		out.append(make(v))
	return out


## A face in words, short: "4", "4 red", "4 ♥".
static func short(f: Dictionary) -> String:
	var s := str(int(f.v))
	if String(f.get("paint", "")) != "":
		s += " " + String(f.paint)
	if String(f.get("carve", "")) != "":
		s += " " + String(CARVES[f.carve].sym)
	return s


## What a face's mods do, in words (for tooltips and the reward screen).
static func describe(f: Dictionary) -> String:
	var out := []
	if String(f.get("paint", "")) != "":
		out.append("%s: %s" % [PAINTS[f.paint].name, PAINTS[f.paint].text])
	if String(f.get("carve", "")) != "":
		out.append("%s: %s" % [CARVES[f.carve].name, CARVES[f.carve].text])
	return "\n".join(out)
