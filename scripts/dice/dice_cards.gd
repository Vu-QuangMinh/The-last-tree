class_name DiceCards
extends RefCounted
## Die on Stage (2026-11-15, reworked 2026-11-16): the MOVES (the cards). A move has one to three dice slots; a die put
## in a slot must fit its rule ("" any, "min" N or more, "max" N or less, "odd", "same": all its slots the same value,
## "gte": the first die >= the second). When every slot is filled the move fires and the dice are spent. A repeatable
## move can take dice again in the same turn; any other is done for the turn once it fired. ("gt": the first > the second.) A "tweak" move (Hype Up,
## Calm Down, Switch Stance, Intuition) changes the die put in it and gives it back, `uses` times a turn. Fragile: gone
## from the fight once used (Focus). A HIT is a move of yours striking an enemy, Shield or not (a Redirected attack too;
## Burn never): Fire Fist, Overwhelm, Smite and Flurry go off on it. There is no healing move (the user's rule).
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
		"text": "If it is about to attack, deal 10 - [d] damage.", "boost": "If it is about to attack, deal 12 - [d] damage."},
	"thousand_cuts": {"name": "Thousand Cuts", "kind": "attack", "slots": 1, "rule": "", "target": true, "price": 7,
		"text": "Deal 1 damage [d] times.", "boost": "Deal 1 damage [d] + 2 times."},
	"discombobulate": {"name": "Discombobulate", "kind": "special", "slots": 2, "rule": "same", "target": true, "price": 8,
		"text": "Deal 10 damage. Apply 1 Stun.", "boost": "Deal 14 damage. Apply 1 Stun.", "relax": {"rule": "min", "n": 4}},
	"high_knee": {"name": "High Knee", "kind": "attack", "slots": 1, "rule": "min", "n": 5, "target": true, "price": 7,
		"text": "Deal 2 x [d] damage.", "boost": "Deal 3 x [d] damage.", "relax": {"rule": "min", "n": 4}},
	"uppercut": {"name": "Uppercut", "kind": "attack", "slots": 1, "rule": "min", "n": 4, "target": true, "price": 6,
		"text": "Deal [d] + 4 damage.", "boost": "Deal [d] + 7 damage.", "relax": {"rule": "min", "n": 3}},
	"double_down": {"name": "Double Down", "kind": "attack", "slots": 2, "rule": "", "target": true, "price": 7,
		"text": "Deal [t] damage.", "boost": "Deal [t] + 4 damage."},
	"odd_jab": {"name": "Odd Jab", "kind": "attack", "slots": 1, "rule": "odd", "repeatable": true, "target": true, "price": 6,
		"text": "Deal [d] + 1 damage.", "boost": "Deal [d] + 3 damage.", "slot_ok": true},
	"parry": {"name": "Parry", "kind": "defense", "slots": 1, "rule": "", "target": true, "price": 5,
		"text": "Gain [d] - 2 Shield. Apply 1 Weakened.", "boost": "Gain [d] - 2 Shield. Apply 3 Weakened."},
	"haymaker": {"name": "Haymaker", "kind": "attack", "slots": 1, "rule": "min", "n": 6, "target": true, "price": 7,
		"text": "Deal 14 damage.", "boost": "Deal 20 damage.", "relax": {"rule": "min", "n": 5}},
	"firebrand": {"name": "Firebrand", "kind": "special", "slots": 1, "rule": "odd", "target": true, "price": 6,
		"text": "Apply [d] Burn.", "boost": "Apply [d] + 2 Burn."},
	"shield_bash": {"name": "Shield Bash", "kind": "defense", "slots": 1, "rule": "", "target": true, "price": 6,
		"text": "Gain 6 - [d] Shield. Deal damage equal to your Shield.", "boost": "Gain 8 - [d] Shield. Deal damage equal to your Shield."},
	"sweep": {"name": "Sweep", "kind": "attack", "slots": 1, "rule": "max", "n": 4, "target": false, "price": 8,
		"text": "Deal [d] damage to all enemies.", "boost": "Deal [d] + 2 damage to all enemies.", "relax": {"rule": "max", "n": 5}},
	"mirror_guard": {"name": "Mirror Guard", "kind": "defense", "slots": 2, "rule": "same", "target": false, "price": 6,
		"text": "Gain 2 x [t] Shield.", "boost": "Gain 3 x [t] Shield.", "relax": {"rule": "min", "n": 4}},
	# (2026-11-16)
	"burn_burn_burn": {"name": "Burn Burn Burn", "kind": "special", "slots": 1, "rule": "min", "n": 6, "target": false, "price": 9, "cooldown": 1,
		"text": "Apply [d] Burn to all enemies. Double all enemy Burn. Cooldown 1.",
		"boost": "Apply [d] Burn to all enemies. Double all enemy Burn. No cooldown.", "relax": {"rule": "min", "n": 5}},
	"self_immolate": {"name": "Self-Immolate", "kind": "special", "slots": 1, "rule": "", "target": true, "price": 6,
		"text": "Apply 2 x [d] Burn, and [d] Burn to yourself.", "boost": "Apply 3 x [d] Burn, and [d] Burn to yourself."},
	"flurry": {"name": "Flurry", "kind": "attack", "slots": 1, "rule": "", "target": false, "price": 8,
		"text": "This turn, each time you damage an enemy, deal 2 - [d] more to it.", "boost": "This turn, each time you damage an enemy, deal 3 - [d] more to it."},
	"freeze_burn": {"name": "Freeze Burn", "kind": "special", "slots": 1, "rule": "", "target": true, "price": 6,
		"text": "Apply 6 - [d] Burn.", "boost": "Apply 8 - [d] Burn."},
	"hype_up": {"name": "Hype Up", "kind": "special", "slots": 1, "rule": "", "target": false, "price": 5, "tweak": 1, "uses": 1,
		"text": "+1 to the die.", "boost": "+1 to the die. 2 uses a turn.", "no_slot": true},
	"calm_down": {"name": "Calm Down", "kind": "special", "slots": 1, "rule": "", "target": false, "price": 5, "tweak": -1, "uses": 1,
		"text": "-1 to the die.", "boost": "-1 to the die. 2 uses a turn.", "no_slot": true},
	"elbow": {"name": "Elbow", "kind": "attack", "slots": 1, "rule": "max", "n": 4, "target": true, "price": 6,
		"text": "Deal 2 x [d] damage.", "boost": "Deal 3 x [d] damage.", "relax": {"rule": "max", "n": 5}},
	"finger_pistol": {"name": "Finger Pistol", "kind": "attack", "slots": 1, "rule": "max", "n": 1, "target": true, "price": 7,
		"text": "Deal 10 damage.", "boost": "Deal 15 damage.", "relax": {"rule": "max", "n": 2}},
	"spirit_bomb": {"name": "Spirit Bomb", "kind": "attack", "slots": 3, "rule": "same", "target": true, "price": 10,
		"text": "Deal 3 x [t] damage.", "boost": "Deal 4 x [t] damage.", "relax": {"rule": "min", "n": 4}},
	"lariat": {"name": "Lariat", "kind": "attack", "slots": 2, "rule": "gte", "target": true, "price": 7,
		"text": "Deal 2 x ([d1] - [d2]) damage.", "boost": "Deal 3 x ([d1] - [d2]) damage.", "no_slot": true},
	"body_slam": {"name": "Body Slam", "kind": "attack", "slots": 1, "rule": "", "target": true, "price": 7,
		"text": "Lose [d] HP. Deal 3 x [d] damage.", "boost": "Lose [d] HP. Deal 4 x [d] damage."},
	"headbutt": {"name": "Headbutt", "kind": "special", "slots": 1, "rule": "", "target": true, "price": 6,
		"text": "Lose 6 - [d] HP. Apply 1 Stun.", "boost": "Lose 5 - [d] HP. Apply 1 Stun."},
	"eye_poke": {"name": "Eye Poke", "kind": "special", "slots": 1, "rule": "max", "n": 2, "target": false, "price": 7,
		"text": "Apply [d] Weakened to all enemies.", "boost": "Apply [d] + 1 Weakened to all enemies.", "relax": {"rule": "max", "n": 3}},
	# (2026-11-16, the user's)
	"flee": {"name": "Flee", "kind": "defense", "slots": 1, "rule": "", "target": false, "price": 7,
		"text": "Gain Ethereal. The die is held for 2 turns.", "boost": "Gain Ethereal. The die is held for 1 turn.", "no_slot": true},
	"jab": {"name": "Jab", "kind": "attack", "slots": 1, "rule": "max", "n": 3, "target": true, "price": 5,
		"text": "Deal [d] damage. Apply 1 Vulnerable.", "boost": "Deal [d] damage. Apply 2 Vulnerable.", "relax": {"rule": "max", "n": 4}},
	"roundhouse_kick": {"name": "Roundhouse Kick", "kind": "attack", "slots": 1, "rule": "min", "n": 4, "target": true, "price": 8, "cooldown": 1,
		"text": "Deal 2 x [d] damage. Overkill hits the next enemy. Cooldown 1.",
		"boost": "Deal 3 x [d] damage. Overkill hits the next enemy. Cooldown 1.", "relax": {"rule": "min", "n": 3}},
	"whirlwind_punches": {"name": "Whirlwind Punches", "kind": "attack", "slots": 1, "rule": "", "target": false, "price": 8,
		"text": "Deal 7 - [d] damage to all enemies.", "boost": "Deal 9 - [d] damage to all enemies.", "no_slot": true},
	"redirect": {"name": "Redirect", "kind": "special", "slots": 1, "rule": "min", "n": 6, "target": true, "price": 8,
		"text": "Redirect an enemy's attack to another target.", "relax": {"rule": "min", "n": 5}, "no_boost": true},
	"arm_bar": {"name": "Arm Bar", "kind": "special", "slots": 2, "rule": "gt", "target": true, "price": 7,
		"text": "If it is Weakened, apply 3 Vulnerable. Then deal [d1] damage.",
		"boost": "If it is Weakened, apply 5 Vulnerable. Then deal [d1] damage.",
		"alt": "If it is Weakened, apply 3 Vulnerable. Then deal [d1] + [d2] damage."},
	"quick_feet": {"name": "Quick Feet", "kind": "defense", "slots": 1, "rule": "max", "n": 2, "target": false, "price": 6,
		"text": "Gain 1 Dodge.", "boost": "Gain [d] Dodge.", "relax": {"rule": "max", "n": 3}},
	"faceplant": {"name": "Faceplant", "kind": "defense", "slots": 1, "rule": "min", "n": 3, "target": false, "price": 5,
		"text": "Lose [d] HP. Gain 1 Dodge.", "boost": "Lose [d] HP. Gain 2 Dodge.", "relax": {"rule": "min", "n": 2}},
	"cover_up": {"name": "Cover Up", "kind": "defense", "slots": 2, "rule": "", "target": false, "price": 6,
		"text": "Gain [t] Shield.", "boost": "Gain [t] + 3 Shield."},
	"dance": {"name": "Dance", "kind": "defense", "slots": 1, "rule": "", "target": false, "price": 5,
		"text": "Gain 6 - [d] Shield.", "boost": "Gain 8 - [d] Shield."},
	"bear_hug": {"name": "Bear Hug", "kind": "special", "slots": 2, "rule": "gt", "target": true, "price": 8,
		"text": "Gain 2 x ([d1] - [d2]) Shield and deal that much damage.", "boost": "Gain 3 x ([d1] - [d2]) Shield and deal that much damage.", "relax": {"rule": "gte"}},
	"intuition": {"name": "Intuition", "kind": "special", "slots": 1, "rule": "", "target": false, "price": 6, "tweak": "intuition", "uses": 1,
		"text": "Change the die to [x]. The number changes each turn.", "boost": "Change the die to [x]. The number changes each turn. 2 uses a turn.", "no_slot": true},
	"focus": {"name": "Focus", "kind": "special", "slots": 1, "rule": "", "target": false, "price": 8, "fragile": true,
		"text": "Roll 3 more dice this turn. Fragile.", "boost": "Roll 4 more dice this turn. Fragile.", "no_slot": true},
	"switch_stance": {"name": "Switch Stance", "kind": "special", "slots": 1, "rule": "", "target": false, "price": 5, "tweak": "opposite", "uses": 2,
		"text": "Flip the die to its opposite face. 2 uses a turn.", "boost": "Flip the die to its opposite face. 4 uses a turn.", "no_slot": true},
	"revenge": {"name": "Revenge", "kind": "special", "slots": 1, "rule": "", "target": true, "price": 8,
		"text": "Next turn, deal this enemy 2 x the HP you lose before then.", "boost": "Next turn, deal this enemy 3 x the HP you lose before then.", "no_slot": true},
	# (2026-11-17, the user's)
	"fire_starter": {"name": "Fire Starter", "kind": "special", "slots": 1, "rule": "max", "n": 3, "repeatable": true, "target": true, "price": 6,
		"text": "Apply [d] Burn.", "boost": "Apply [d] + 1 Burn.", "relax": {"rule": "max", "n": 4}},
	"ignite": {"name": "Ignite", "kind": "special", "slots": 1, "rule": "min", "n": 6, "target": true, "price": 8,
		"text": "Remove Burn from an enemy. Deal 2 damage for each Burn removed.",
		"boost": "Remove Burn from an enemy. Deal 3 damage for each Burn removed.", "relax": {"rule": "min", "n": 5}},
	"fan_the_flames": {"name": "Fan the Flames", "kind": "special", "slots": 1, "rule": "", "target": true, "price": 6, "needs_burn": true,
		"text": "Apply [d] Burn to a burning enemy.", "boost": "Apply [d] Burn."},
	"fire_fist": {"name": "Fire Fist", "kind": "special", "slots": 1, "rule": "max", "n": 1, "target": false, "price": 7, "boost_per_die": true,
		"text": "This turn, each time you damage an enemy, apply [d] Burn to it.",
		"boost": "This turn, each time you damage an enemy, apply [d] Burn to it.", "relax": {"rule": "max", "n": 2}},
	"smoke_screen": {"name": "Smoke Screen", "kind": "defense", "slots": 1, "rule": "", "target": false, "price": 6,
		"text": "Gain [d] Shield for each burning enemy.", "boost": "Gain [d] + 2 Shield for each burning enemy."},
	"smite": {"name": "Smite", "kind": "special", "slots": 1, "rule": "min", "n": 5, "target": true, "price": 7,
		"text": "Your next hit on this enemy also applies Burn equal to its damage.",
		"boost": "Your next hit on this enemy also applies Burn equal to 2 x its damage.", "relax": {"rule": "min", "n": 4}},
	"feint": {"name": "Feint", "kind": "defense", "slots": 1, "rule": "min", "n": 6, "target": false, "price": 6,
		"text": "Gain 1 Dodge. Until your next turn, attackers gain 1 Vulnerable.",
		"boost": "Gain 2 Dodge. Until your next turn, attackers gain 1 Vulnerable.", "relax": {"rule": "min", "n": 5}},
	"taunt": {"name": "Taunt", "kind": "special", "slots": 1, "rule": "min", "n": 4, "target": false, "price": 7,
		"text": "Remove all your Shield. You can't gain Shield this turn. Apply 3 Vulnerable to all enemies.",
		"boost": "Remove all your Shield. You can't gain Shield this turn. Apply 5 Vulnerable to all enemies.", "relax": {"rule": "min", "n": 3}},
	"grit": {"name": "Grit", "kind": "defense", "slots": 1, "rule": "", "target": false, "price": 6,
		"text": "Lose [d] HP. Gain 8 Shield.", "boost": "Lose [d] HP. Gain 11 Shield."},
	"overwhelm": {"name": "Overwhelm", "kind": "defense", "slots": 1, "rule": "max", "n": 2, "target": false, "price": 8,
		"text": "This turn, each time you damage an enemy, gain [d] Shield.",
		"boost": "This turn, each time you damage an enemy, gain [d] + 1 Shield.", "relax": {"rule": "max", "n": 3}},
	"stack": {"name": "Stack", "kind": "special", "slots": 2, "rule": "", "target": false, "price": 7, "merge": true, "uses": 1,
		"text": "Combine both dice into one: [t].", "boost": "Combine both dice into one: [t]. 2 uses a turn.", "no_slot": true},
	"reroll": {"name": "Reroll", "kind": "special", "slots": 1, "rule": "", "target": false, "price": 5, "tweak": "reroll", "uses": 2,
		"text": "Reroll the die. 2 uses a turn.", "boost": "Reroll the die. 4 uses a turn.", "no_slot": true},
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
		if c.get("boost_per_die", false):  # (Fire Fist: the boost is a second slot, same rule; it fires once for each die)
			c.slots = 2
			c.per_die = true
			c.per_die_rule = true
			c.text = String(c.text) + " (Once for each die.)"
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


## A move's rarity, from its price for now: "common" (5-6 coins), "uncommon" (7), "rare" (8-10).
static func rarity(id: String) -> String:
	var p := price(id)
	return "common" if p <= 6 else ("uncommon" if p <= 7 else "rare")


## The odds of each rarity in an offer (a shop, a treasure, a mini boss), and in a boss's (higher).
const OFFER_ODDS := {"common": 0.6, "uncommon": 0.33, "rare": 0.07}
const BOSS_ODDS := {"uncommon": 0.6, "rare": 0.4}


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
	if c.get("boost_per_die", false):
		boost = "A second slot, %s too: it fires once for each die." % rule_of(c)
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
	if c.get("per_die", false) and k > 0 and not c.get("per_die_rule", false):
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
