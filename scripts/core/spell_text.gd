class_name SpellText
extends RefCounted
## Rules text for spells: short, plain sentences, one per effect. The same words go on the card face and
## in the tooltip (where each keyword is also explained). "Damage" always means knocking elements off an
## enemy's Essence (its row of elements). Positions are always "leftmost" / "rightmost" (never first / last):
## "remove the 3 rightmost Essence of an enemy" takes the 3 elements at its right end.

const WHO := {"target": "an enemy", "two": "2 different enemies", "all": "every enemy", "random": "a random enemy", "self": "you"}
const WHOSE := {"target": "an enemy's", "two": "2 different enemies'", "all": "every enemy's", "random": "a random enemy's"}


## One sentence per effect, each on its own line.
static func card_text(s: Dictionary) -> String:
	var lines := []
	for e in s.effects:
		lines.append(sentence(e))
	return "\n".join(lines)


## The same rules as one paragraph (tooltips, reports).
static func describe(s: Dictionary) -> String:
	var text := " ".join(s.effects.map(func(e): return sentence(e)))
	if s.get("power", false):
		text = "Power: " + text + " (Once cast, it leaves your active row and lasts the whole fight.)"
	return text


static func sentence(e: Dictionary) -> String:
	var t := describe_op(e)
	return t[0].to_upper() + t.substr(1) + "."


static func _el(c: String) -> String:
	return Elements.NAMES.get(c, c)


## "the 3 rightmost Essence of an enemy" / "the leftmost Essence of an enemy".
static func _ends(who: String, n: int, last: bool) -> String:
	var side := "rightmost" if last else "leftmost"
	if n == 1:
		return "the %s Essence of %s" % [side, who]
	return "the %d %s Essence of %s" % [n, side, who]


static func _a(word: String) -> String:
	return ("an " if word.substr(0, 1).to_lower() in ["a", "e", "i", "o", "u"] else "a ") + word


static func _turns(n: int) -> String:
	return "%d turn%s" % [n, "" if n == 1 else "s"]


static func describe_op(e: Dictionary) -> String:
	var tg: String = e.get("target", "target")
	var t: String = WHO.get(tg, "an enemy")
	var ts: String = WHOSE.get(tg, "an enemy's")
	var n: int = int(e.get("n", 0))
	match e.op:
		"strike":
			var s := "remove %s" % _ends(t, n, e.from == "right")
			if e.has("min_hp"):
				s += " (only if it has %d or more Essence)" % e.min_hp
			if e.has("bonus_if"):
				s += ". If it has Burn, remove 1 more"
			return s
		"pluck":
			if n == 1:
				return "Targeted: remove 1 Essence of your choice from %s" % t
			return "Targeted: remove %d Essence of your choice from %s, one at a time" % [n, t]
		"steal":
			if e.get("el", "any") == "any":
				return "Steal %d element%s of your choice from %s" % [n, "s" if n > 1 else "", t]
			return "Steal up to %d %s from %s" % [n, _el(e.el), t]
		"burn":
			if n == 1:
				return "Burn 1: set a random Essence of %s on fire" % t
			return "Burn %d: set %d random Essence of %s on fire" % [n, n, t]
		"poison":
			return "apply %d Poison to %s" % [n, t]
		"stoke":
			return "set as many more of %s Essence on fire as are Burning now" % ts
		"weak":
			return "Weaken %s for %s" % [t, _turns(e.turns)]
		"freeze":
			return "Freeze %s for %s" % [t, _turns(e.turns)]
		"expose":
			return "Expose %s for %s" % [t, _turns(e.turns)]
		"ethereal":
			return "you become Ethereal this turn" if tg == "self" else "make %s Phased this turn" % t
		"shield":
			return "gain %d Shield" % n
		"heal":
			if e.get("if_kill", false):
				return "if this defeats it, heal %d HP" % n
			return "heal %d HP" % n
		"aegis":
			return "gain %d Aegis" % n
		"thorns":
			return "gain %d Thorns this turn" % n
		"draw":
			var what: String = ("%d random element%s" % [n, "s" if n > 1 else ""]) if e.get("el", "random") == "random" else "%d %s" % [n, _el(e.el)]
			return "gain %s%s%s" % [what, " (Conjured)" if e.get("temp", false) else "", "" if e.when == "now" else " next turn"]
		"move":
			if n == 1:
				return "pick 1 element of %s Essence and move it to any spot in that row" % ts
			return "pick %d elements of %s Essence, one at a time, and move each to any spot in that row" % [n, ts]
		"rotate":
			if e.get("dir", "left") == "left":
				return "move the leftmost Essence of %s to the right end of its row" % t
			return "move the rightmost Essence of %s to the left end of its row" % t
		"swap":
			return "swap the 2 leftmost Essence of %s" % t
		"convert":
			if e.pos == "all":
				if e.has("from"):
					return "change every %s in %s Essence into %s" % [_el(e.from), ts, _el(e.to)]
				return "change every element of %s Essence into %s" % [ts, _el(e.to)]
			var where: String = {"first": "the leftmost Essence", "first2": "the 2 leftmost Essence",
				"last": "the rightmost Essence"}[e.pos]
			return "change %s of %s into %s" % [where, t, _el(e.to)]
		"purge":
			return "remove up to %d %s from %s Essence, wherever they are" % [n, _el(e.el), ts]
		"shatter":
			return "break all Armour on %s" % t
		"insert":
			return "add %s at the leftmost end of %s Essence" % [_a(_el(e.el)), ts]
		"siphon":
			return "remove %s. Next turn you gain the removed elements (Conjured)" % _ends(t, n, false)
		"execute":
			return "Execute %s with %d Essence or less (not bosses)" % [t, e.max]
		"transmute":
			return "change %d of your unused elements into %s" % [n, _el(e.to)]
		"sacrifice":
			return "lose %d of your HP" % e.hp
		"amplify":
			var more := "its rightmost Essence" if n == 1 else "its %d rightmost Essence" % n
			return "Amplify %d: when the chant is Released this turn, every enemy it hits also loses %s" % [n, more]
		"echo":
			return "Echo: the chant is Released twice this turn"
		"retain":
			if n == 1:
				return "after the Release, the rightmost element of your chant goes back to your elements, to use again"
			return "after the Release, the %d rightmost elements of your chant go back to your elements, to use again" % n
		"overload":
			return "Overload %d: gain %d fewer element%s next turn" % [n, n, "s" if n > 1 else ""]
		"cleanse":
			return {"all": "Cleanse all your debuffs", "blind": "Cure Blind", "bleed": "Cure Bleed", "confuse": "Cure Confuse",
				"silence": "Cure Silence on all your spells", "frozen": "thaw your Frozen elements",
				"lock": "break one Lock on your spells"}[e.get("what", "all")]
		"copy_last":
			return "repeat the last spell you cast this turn"
		"redirect":
			return "Redirect the intent of %s" % t
		"infuse":
			return "Infuse %s into the chant" % _a(_el(e.el))
		"rearrange":
			if n == 1:
				return "Rearrange 1: move one element of your chant to another spot"
			return "Rearrange %d: move %d elements of your chant, one at a time, to other spots" % [n, n]
		"duplicate":
			if e.times == 2:
				return "Resonate: pick an element of your chant and copy it in place (it becomes 2 in a row)"
			return "Resonate: pick an element of your chant and copy it %d times in place (it becomes %d in a row)" % [e.times - 1, e.times]
		"summon_spells":
			return "add %d random spells from your spellbook to your active row for this fight" % n
		"passive":
			return {"burn_bonus": "whenever you apply Burn, apply %d more" % n,
				"thorns": "gain %d Thorns for the rest of the fight" % n,
				"strike_poison": "every enemy your Release hits gets %d Poison" % n,
				"strike_burn": "every enemy your Release hits gets %d Burn" % n,
				"echo_first": "the first spell you cast each turn triggers twice",
				"attune": "one of your draws each turn is always your most-used element",
				"chant_slots": "your chant can be %d elements longer" % n,
				"strike_bonus": "your spells remove %d more Essence" % n}.get(e.key, e.key)
		"curse":
			return {"no_mend": "%s can never Mend" % t,
				"exposed": "%s is Exposed for the rest of the fight" % t,
				"weak25": "%s deals 25%% less damage for the rest of the fight" % t}.get(e.key, e.key)
		"each_turn":
			return "at the start of each of your turns: " + "; ".join(e.effects.map(func(x): return describe_op(x)))
	return e.op
