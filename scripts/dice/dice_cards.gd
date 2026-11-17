class_name DiceCards
extends RefCounted
## Die on Stage (2026-11-15, reworked 2026-11-16): the MOVES (the cards). A move has one to three dice slots; a die put
## in a slot must fit its rule ("" any, "min" N or more, "max" N or less, "odd", "same": all its slots the same value,
## "gte": the first die >= the second). When every slot is filled the move fires and the dice are spent. A repeatable
## move can take dice again in the same turn; any other is done for the turn once it fired. ("gt": the first > the second.) A "tweak" move (Hype Up,
## Calm Down, Switch Stance, Intuition) changes the die put in it and gives it back, `uses` times a turn. Fragile: gone
## from the fight once used (Focus). There is no healing move (the user's rule).
##
## Text: [d] the die (each die, for a move upgraded with an extra slot), [t] the total of its dice, [d1] / [d2] the first
## and the second. kind: the card's colour ("attack" orange, "defense" blue, "special" purple).
##
## Upgrades (at a campfire, once per move; DiceRun.upgrades): "boost" (the move works better, `boost`), "alt" (a second
## kind of boost where the move has one, `alt`: Arm Bar), or "slot":
## a move with a rule has it eased by one step instead (`relax`; SAME becomes MIN 4 in each slot); a one-die move with no
## rule (and Odd Jab) takes a second die, any value, and fires once for each die; a move of two dice with no rule takes a
## third, added to its total. `no_slot` / `no_boost`: that option isn't offered (Lariat: the boost only).

const CARDS := {
	"punch": {"name": "Punch", "kind": "attack", "slots": 1, "rule": "", "repeatable": true, "target": true,
		"text": "Deal [d] damage.", "boost": "Deal [d] + 2 damage."},
	"block": {"name": "Block", "kind": "defense", "slots": 1, "rule": "", "repeatable": true, "target": false,
		"text": "Gain [d] Shield.", "boost": "Gain [d] + 2 Shield."},
	"counter_attack": {"name": "Counter Attack", "kind": "attack", "slots": 1, "rule": "", "target": true, "price": 6,
		"text": "Against an attacking enemy: deal 10 - [d] damage.", "boost": "Against an attacking enemy: deal 12 - [d] damage."},
	"thousand_cuts": {"name": "Thousand Cuts", "kind": "attack", "slots": 1, "rule": "", "target": true, "price": 7,
		"text": "Deal 1 damage [d] times.", "boost": "Deal 1 damage [d] + 2 times."},
	"discombobulate": {"name": "Discombobulate", "kind": "special", "slots": 2, "rule": "same", "target": true, "price": 8,
		"text": "Deal 10 damage and apply 1 Stun.", "boost": "Deal 14 damage and apply 1 Stun.", "relax": {"rule": "min", "n": 4}},
	"high_knee": {"name": "High Knee", "kind": "attack", "slots": 1, "rule": "min", "n": 5, "target": true, "price": 7,
		"text": "Deal 2 x [d] damage.", "boost": "Deal 3 x [d] damage.", "relax": {"rule": "min", "n": 4}},
	"uppercut": {"name": "Uppercut", "kind": "attack", "slots": 1, "rule": "min", "n": 4, "target": true, "price": 6,
		"text": "Deal [d] + 4 damage.", "boost": "Deal [d] + 7 damage.", "relax": {"rule": "min", "n": 3}},
	"double_down": {"name": "Double Down", "kind": "attack", "slots": 2, "rule": "", "target": true, "price": 7,
		"text": "Deal [t] damage.", "boost": "Deal [t] + 4 damage."},
	"odd_jab": {"name": "Odd Jab", "kind": "attack", "slots": 1, "rule": "odd", "repeatable": true, "target": true, "price": 6,
		"text": "Deal [d] + 1 damage.", "boost": "Deal [d] + 3 damage.", "slot_ok": true},
	"parry": {"name": "Parry", "kind": "defense", "slots": 1, "rule": "", "target": true, "price": 5,
		"text": "Gain [d] - 2 Shield and apply 1 Weakened.", "boost": "Gain [d] - 2 Shield and apply 3 Weakened."},
	"haymaker": {"name": "Haymaker", "kind": "attack", "slots": 1, "rule": "min", "n": 6, "target": true, "price": 7,
		"text": "Deal 14 damage.", "boost": "Deal 20 damage.", "relax": {"rule": "min", "n": 5}},
	"firebrand": {"name": "Firebrand", "kind": "special", "slots": 1, "rule": "odd", "target": true, "price": 6,
		"text": "Apply [d] Burn.", "boost": "Apply [d] + 2 Burn."},
	"shield_bash": {"name": "Shield Bash", "kind": "defense", "slots": 1, "rule": "", "target": true, "price": 6,
		"text": "Gain 6 - [d] Shield, then deal damage equal to your Shield.", "boost": "Gain 8 - [d] Shield, then deal damage equal to your Shield."},
	"sweep": {"name": "Sweep", "kind": "attack", "slots": 1, "rule": "max", "n": 4, "target": false, "price": 8,
		"text": "Deal [d] damage to all enemies.", "boost": "Deal [d] + 2 damage to all enemies.", "relax": {"rule": "max", "n": 5}},
	"mirror_guard": {"name": "Mirror Guard", "kind": "defense", "slots": 2, "rule": "same", "target": false, "price": 6,
		"text": "Gain 2 x [t] Shield.", "boost": "Gain 3 x [t] Shield.", "relax": {"rule": "min", "n": 4}},
	# (2026-11-16)
	"burn_burn_burn": {"name": "Burn Burn Burn", "kind": "special", "slots": 1, "rule": "min", "n": 6, "target": false, "price": 9, "cooldown": 1,
		"text": "Apply [d] Burn to all enemies, then double their Burn. Cooldown 1.",
		"boost": "Apply [d] Burn to all enemies, then double their Burn. No cooldown.", "relax": {"rule": "min", "n": 5}},
	"self_immolate": {"name": "Self-Immolate", "kind": "special", "slots": 1, "rule": "", "target": true, "price": 6,
		"text": "Apply 2 x [d] Burn to an enemy and [d] Burn to yourself.", "boost": "Apply 3 x [d] Burn to an enemy and [d] Burn to yourself."},
	"flurry": {"name": "Flurry", "kind": "attack", "slots": 1, "rule": "", "target": false, "price": 8,
		"text": "This turn, each time an enemy takes damage, deal 3 - [d] more to it.", "boost": "This turn, each time an enemy takes damage, deal 4 - [d] more to it."},
	"freeze_burn": {"name": "Freeze Burn", "kind": "special", "slots": 1, "rule": "", "target": true, "price": 6,
		"text": "Apply 6 - [d] Burn to an enemy.", "boost": "Apply 8 - [d] Burn to an enemy."},
	"hype_up": {"name": "Hype Up", "kind": "special", "slots": 1, "rule": "", "target": false, "price": 5, "tweak": 1, "uses": 1,
		"text": "Add 1 to the die, and give it back.", "boost": "Add 1 to the die, and give it back. 2 uses a turn.", "no_slot": true},
	"calm_down": {"name": "Calm Down", "kind": "special", "slots": 1, "rule": "", "target": false, "price": 5, "tweak": -1, "uses": 1,
		"text": "Take 1 from the die, and give it back.", "boost": "Take 1 from the die, and give it back. 2 uses a turn.", "no_slot": true},
	"elbow": {"name": "Elbow", "kind": "attack", "slots": 1, "rule": "max", "n": 4, "target": true, "price": 6,
		"text": "Deal 2 x [d] damage.", "boost": "Deal 3 x [d] damage.", "relax": {"rule": "max", "n": 5}},
	"finger_pistol": {"name": "Finger Pistol", "kind": "attack", "slots": 1, "rule": "max", "n": 1, "target": true, "price": 7,
		"text": "Deal 10 damage.", "boost": "Deal 15 damage.", "relax": {"rule": "max", "n": 2}},
	"spirit_bomb": {"name": "Spirit Bomb", "kind": "attack", "slots": 3, "rule": "same", "target": true, "price": 10,
		"text": "Deal 3 x [t] damage.", "boost": "Deal 4 x [t] damage.", "relax": {"rule": "min", "n": 4}},
	"lariat": {"name": "Lariat", "kind": "attack", "slots": 2, "rule": "gte", "target": true, "price": 7,
		"text": "Deal 2 x ([d1] - [d2]) damage.", "boost": "Deal 3 x ([d1] - [d2]) damage.", "no_slot": true},
	"body_slam": {"name": "Body Slam", "kind": "attack", "slots": 1, "rule": "", "target": true, "price": 7,
		"text": "Take [d] damage, and deal 3 x [d] damage.", "boost": "Take [d] damage, and deal 4 x [d] damage."},
	"headbutt": {"name": "Headbutt", "kind": "special", "slots": 1, "rule": "", "target": true, "price": 6,
		"text": "Take 6 - [d] damage, and apply 1 Stun.", "boost": "Take 5 - [d] damage, and apply 1 Stun."},
	"eye_poke": {"name": "Eye Poke", "kind": "special", "slots": 1, "rule": "max", "n": 2, "target": false, "price": 7,
		"text": "Apply [d] Weakened to all enemies.", "boost": "Apply [d] + 1 Weakened to all enemies.", "relax": {"rule": "max", "n": 3}},
	# (2026-11-16, the user's)
	"flee": {"name": "Flee", "kind": "defense", "slots": 1, "rule": "", "target": false, "price": 7,
		"text": "Gain Ethereal. The die stays in this move for 2 turns.", "boost": "Gain Ethereal. The die stays in this move for 1 turn.", "no_slot": true},
	"jab": {"name": "Jab", "kind": "attack", "slots": 1, "rule": "max", "n": 3, "target": true, "price": 5,
		"text": "Deal [d] damage and apply 1 Vulnerable.", "boost": "Deal [d] damage and apply 2 Vulnerable.", "relax": {"rule": "max", "n": 4}},
	"roundhouse_kick": {"name": "Roundhouse Kick", "kind": "attack", "slots": 1, "rule": "min", "n": 4, "target": true, "price": 8, "cooldown": 1,
		"text": "Deal 2 x [d] damage; what's left after a kill hits the next enemy. Cooldown 1.",
		"boost": "Deal 3 x [d] damage; what's left after a kill hits the next enemy. Cooldown 1.", "relax": {"rule": "min", "n": 3}},
	"whirlwind_punches": {"name": "Whirlwind Punches", "kind": "attack", "slots": 1, "rule": "", "target": false, "price": 8,
		"text": "Deal 7 - [d] damage to all enemies.", "boost": "Deal 9 - [d] damage to all enemies.", "no_slot": true},
	"redirect": {"name": "Redirect", "kind": "special", "slots": 1, "rule": "min", "n": 6, "target": true, "price": 8,
		"text": "An attacking enemy attacks someone else instead.", "relax": {"rule": "min", "n": 5}, "no_boost": true},
	"arm_bar": {"name": "Arm Bar", "kind": "special", "slots": 2, "rule": "gt", "target": true, "price": 7,
		"text": "If it is Weakened, apply 3 Vulnerable. Then deal [d1] damage.",
		"boost": "If it is Weakened, apply 5 Vulnerable. Then deal [d1] damage.",
		"alt": "If it is Weakened, apply 3 Vulnerable. Then deal [d1] + [d2] damage."},
	"quick_feet": {"name": "Quick Feet", "kind": "defense", "slots": 1, "rule": "max", "n": 2, "target": false, "price": 6,
		"text": "Gain 1 Dodge.", "boost": "Gain [d] Dodge.", "relax": {"rule": "max", "n": 3}},
	"faceplant": {"name": "Faceplant", "kind": "defense", "slots": 1, "rule": "min", "n": 3, "target": false, "price": 5,
		"text": "Take [d] damage and gain 1 Dodge.", "boost": "Take [d] damage and gain 2 Dodge.", "relax": {"rule": "min", "n": 2}},
	"cover_up": {"name": "Cover Up", "kind": "defense", "slots": 2, "rule": "", "target": false, "price": 6,
		"text": "Gain [t] Shield.", "boost": "Gain [t] + 3 Shield."},
	"dance": {"name": "Dance", "kind": "defense", "slots": 1, "rule": "", "target": false, "price": 5,
		"text": "Gain 6 - [d] Shield.", "boost": "Gain 8 - [d] Shield."},
	"bear_hug": {"name": "Bear Hug", "kind": "special", "slots": 2, "rule": "gt", "target": true, "price": 8,
		"text": "Gain 2 x ([d1] - [d2]) Shield, and deal that much damage.", "boost": "Gain 3 x ([d1] - [d2]) Shield, and deal that much damage.", "relax": {"rule": "gte"}},
	"intuition": {"name": "Intuition", "kind": "special", "slots": 1, "rule": "", "target": false, "price": 6, "tweak": "intuition", "uses": 1,
		"text": "Turn the die into [x] (a new number each turn), and give it back.", "boost": "Turn the die into [x] (a new number each turn), and give it back. 2 uses a turn.", "no_slot": true},
	"focus": {"name": "Focus", "kind": "special", "slots": 1, "rule": "", "target": false, "price": 8, "fragile": true,
		"text": "Roll 3 more dice this turn. Fragile.", "boost": "Roll 4 more dice this turn. Fragile.", "no_slot": true},
	"switch_stance": {"name": "Switch Stance", "kind": "special", "slots": 1, "rule": "", "target": false, "price": 5, "tweak": "opposite", "uses": 2,
		"text": "Turn the die to its opposite face, and give it back. 2 uses a turn.", "boost": "Turn the die to its opposite face, and give it back. 4 uses a turn.", "no_slot": true},
	"revenge": {"name": "Revenge", "kind": "special", "slots": 1, "rule": "", "target": true, "price": 8,
		"text": "Next turn, deal this enemy 2 x the damage you take until then.", "boost": "Next turn, deal this enemy 3 x the damage you take until then.", "no_slot": true},
}
const STARTERS := ["punch", "block"]
const MAX_CARDS := 4
## The Merchant's dice alterations (coins): buy one, your dice are rolled, and the face of the one you pick changes by that much.
const ALTER_PRICE := {1: 3, 2: 5, 3: 7, -1: 3, -2: 5, -3: 7}


## A move as it is now: `up` "" (not upgraded), "boost" or "slot" (see the top). The name gets a "+" when upgraded.
static func card(id: String, up := "") -> Dictionary:
	var c: Dictionary = CARDS.get(id, {}).duplicate(true)
	if c.is_empty() or up == "":
		return c
	c.name = String(c.name) + "+"
	c.up = up
	if up == "alt":  # (a second kind of boost, instead of the extra slot: Arm Bar)
		c.text = c.get("alt", c.text)
	elif up == "boost":
		c.text = c.get("boost", c.text)
		if c.has("uses"):
			c.uses = int(c.uses) * 2
		if c.has("cooldown") and String(c.boost).contains("No cooldown"):
			c.erase("cooldown")
	elif up == "slot":
		if c.has("relax"):
			for k in c.relax:
				c[k] = c.relax[k]
		elif int(c.slots) == 1:
			c.slots = 2
			c.per_die = true  # (a second die, any value: it fires once for each)
			c.text = String(c.text) + " (Once for each die.)"
		else:
			c.slots = int(c.slots) + 1
			c.plain_extra = true  # (its last slot takes any die: added to the total)
	return c


## (the move as written in the data; the screens that don't know about upgrades)
static func get_card(id: String) -> Dictionary:
	return CARDS.get(id, {})


## Moves you can be offered (in a shop, after a mini boss or a boss): everything but the two you start with.
static func pool() -> Array:
	return CARDS.keys().filter(func(k): return not (k in STARTERS))


static func price(id: String) -> int:
	return int(CARDS.get(id, {}).get("price", 6))


## What each upgrade of a move does, in words (for the campfire): [boost, slot] ("" when it has none).
static func upgrade_texts(id: String) -> Array:
	var c: Dictionary = CARDS.get(id, {})
	var slot := ""
	if c.has("alt"):
		slot = String(c.alt)
	elif not c.get("no_slot", false) and not (c.get("repeatable", false) and not c.has("relax") and not c.get("slot_ok", false)):  # (a repeatable move takes dice again anyway)
		if c.has("relax"):
			var r: Dictionary = c.relax
			if String(c.rule) == "same":
				slot = "MIN 4 in each slot, instead of all the same."
			elif String(r.rule) == "":
				slot = "No more %s rule: any dice." % rule_of(c)
			else:
				slot = "Eased: %s instead of %s." % [rule_of(r), rule_of(c)]
		elif int(c.slots) == 1:
			slot = "A second slot, any die: it fires once for each die."
		else:
			slot = "A slot more, any die, added to the total."
	var boost := _plain(String(c.get("boost", "")))
	slot = _plain(slot)
	if c.get("no_boost", false):
		boost = ""
	return [boost, slot]


static func _plain(t: String) -> String:
	return t.replace("[d1]", "d1").replace("[d2]", "d2").replace("[t]", "the total").replace("[d]", "d").replace("[x]", "a number")


## The words in a slot: "MIN 5", "MAX 3", "ODD" ("" for any die; "same" and "gte" are written between the slots).
static func rule_of(c: Dictionary) -> String:
	match String(c.get("rule", "")):
		"min":
			return "MIN %d" % int(c.n)
		"max":
			return "MAX %d" % int(c.n)
		"odd":
			return "ODD"
		"same":
			return "SAME"
		"gte":
			return "≥"
		"gt":
			return ">"
		"exact":
			return "= %d" % int(c.n)
	return ""


## Can a die of this value go in slot `k` of move `c` (DiceCards.card), with `filled` already in its slots (null = empty)?
static func fits_card(c: Dictionary, value: int, k: int, filled: Array) -> bool:
	if c.is_empty() or k < 0 or k >= int(c.get("slots", 1)) or (k < filled.size() and filled[k] != null):
		return false
	if c.get("plain_extra", false) and k == int(c.slots) - 1:
		return true  # (an upgrade's extra slot: any die)
	if c.get("per_die", false) and k > 0:
		return true
	match String(c.get("rule", "")):
		"min":
			return value >= int(c.n)
		"max":
			return value <= int(c.n)
		"odd":
			return value % 2 == 1
		"same":
			for j in filled.size():
				if filled[j] != null and int(filled[j]) != value and not (c.get("plain_extra", false) and j == int(c.slots) - 1):
					return false
		"gte":
			if k == 0 and filled.size() > 1 and filled[1] != null:
				return value >= int(filled[1])
			if k == 1 and filled.size() > 0 and filled[0] != null:
				return int(filled[0]) >= value
		"gt":
			if k == 0 and filled.size() > 1 and filled[1] != null:
				return value > int(filled[1])
			if k == 1 and filled.size() > 0 and filled[0] != null:
				return int(filled[0]) > value
	return true


## (kept for older callers: the move as written, not upgraded)
static func fits(id: String, value: int, k: int, filled: Array) -> bool:
	return fits_card(get_card(id), value, k, filled)


## The move's text with its dice in it (none yet: boxes).
static func text_of(c: Dictionary, dice: Array) -> String:
	var t := String(c.get("text", ""))
	var vals := dice.filter(func(v): return v != null)
	var d: String = str(vals[0]) if not vals.is_empty() else "▢"
	var total := 0
	for v in vals:
		total += int(v)
	t = t.replace("[d1]", str(dice[0]) if dice.size() > 0 and dice[0] != null else "▢")
	t = t.replace("[d2]", str(dice[1]) if dice.size() > 1 and dice[1] != null else "▢")
	t = t.replace("[t]", str(total) if not vals.is_empty() else "▢")
	return t.replace("[d]", d).replace("[x]", "?")
