class_name SpellText
extends RefCounted
## Rules text for spells: short, plain sentences, one per effect. The same words go on the card face and
## in the tooltip (where each keyword is also explained). Everything Fire / Water / Air is "Essence": yours
## (in your bag and chant) and the enemies' (their HP row). Positions are always "leftmost" / "rightmost"
## (never first / last): "remove the 3 rightmost Essence of an enemy" takes the 3 at its right end.

const WHO := {"target": "an enemy", "two": "2 different enemies", "all": "all enemies", "random": "a random enemy", "self": "you"}
const WHOSE := {"target": "an enemy's", "two": "2 different enemies'", "all": "all enemies'", "random": "a random enemy's"}


## One sentence per effect, each on its own line.
static func card_text(s: Dictionary) -> String:
	if s.has("desc"):
		return s.desc  # (the Invoker's spells: written out)
	var lines := []
	for e in s.effects:
		lines.append(sentence(e))
	return "\n".join(lines)


## The same rules as one paragraph (tooltips, reports).
static func describe(s: Dictionary) -> String:
	if s.has("desc"):
		return s.desc
	var text := " ".join(s.effects.map(func(e): return sentence(e)))
	if s.get("anti", false) and s.has("patterns"):
		text = "Anti-spell: it comes alive with every chant, unless the chant contains EITHER of its patterns: " + text
	elif s.get("anti", false):
		text = "Anti-spell: it comes alive with every chant, unless the chant contains its pattern: " + text
	elif s.get("power", false):
		text = "Power: " + text + " (Once cast, it leaves your active row and lasts the whole fight.)"
	elif s.get("fleeting", false):
		text += " Fleeting."
	if s.get("ephemeral", false):
		text += " Ephemeral."
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
			return "snipe %d" % n  # (you pick the Essence with the crosshair: see the Snipe keyword)
		"steal":
			if e.get("el", "any") == "any":
				return "Steal %d Essence of your choice from %s" % [n, t]
			return "Steal up to %d %s from %s" % [n, _el(e.el), t]
		"burn":
			return "Burn %d on %s" % [n, t]
		"poison":
			return "Poison %d on %s" % [n, t]
		"stoke":
			return "double the Burn on %s" % t
		"weak":
			return "Weaken %d on %s" % [e.turns, t]
		"freeze":
			return "Freeze %d on %s" % [e.turns, t]
		"expose":
			return "Expose %d" % n
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
			var what: String = ("%d random Essence" % n) if e.get("el", "random") == "random" else "%d %s" % [n, _el(e.el)]
			if e.get("temp", false) and e.when == "now":
				return "conjure %s" % what  # temporary Essence, right now: "Conjure 2 Water"
			return "gain %s%s%s" % [what, " (Conjured)" if e.get("temp", false) else "", "" if e.when == "now" else " next turn"]
		"move":
			if n == 1:
				return "pick 1 of %s Essence and move it to any spot in that row" % ts
			return "pick %d of %s Essence, one at a time, and move each to any spot in that row" % [n, ts]
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
				return "change all of %s Essence into %s" % [ts, _el(e.to)]
			var where: String = {"first": "the leftmost Essence", "first2": "the 2 leftmost Essence",
				"last": "the rightmost Essence"}[e.pos]
			return "change %s of %s into %s" % [where, t, _el(e.to)]
		"purge":
			return "remove up to %d %s from %s Essence" % [n, _el(e.el), ts]
		"shatter":
			return "break all Armour on %s" % t
		"insert":
			return "add %s at the leftmost end of %s Essence" % [_a(_el(e.el)), ts]
		"siphon":
			return "remove %s. Next turn you gain the removed Essence (Conjured)" % _ends(t, n, false)
		"execute":
			return "Execute %s with %d Essence or less (not bosses)" % [t, e.max]
		"transmute":
			return "change %d of your unused Essence into %s" % [n, _el(e.to)]
		"sacrifice":
			return "lose %d of your HP" % e.hp
		"amplify":
			return "Amplify %d" % n
		"echo":
			return "Echo"
		"retain":
			if n == 1:
				return "after the Release, the rightmost Essence of your chant goes back to your bag, to use again"
			return "after the Release, the %d rightmost Essence of your chant go back to your bag, to use again" % n
		"overload":
			return "Overload %d" % n
		"cleanse":
			return {"all": "Cleanse all your debuffs", "blind": "Cure Blind", "bleed": "Cure Bleed", "confuse": "Cure Confuse",
				"silence": "Cure Silence on all your spells", "frozen": "thaw your Frozen Essence",
				"lock": "break one Lock on your spells"}[e.get("what", "all")]
		"copy_last":
			return "repeat the last spell you cast this turn"
		"redirect":
			return "Redirect the intent of %s" % t
		"infuse":
			if e.el == "random":
				return "Infuse %s into the chant" % ("a random Essence" if n <= 1 else "%d random Essence" % n)
			return "Infuse %s into the chant" % (_a(_el(e.el)) if n <= 1 else "%d %s" % [n, _el(e.el)])
		"annihilate":
			return "Annihilate 1 kind of Essence on %s" % t
		"barrage":
			return "remove %d random Essence from random enemies" % n
		"random_hit":
			return "remove %d random Essence of %s" % [n, t]
		"echo_next":
			return "the next spell you cast this fight is cast twice"
		"conjure":
			return "conjure %d spell%s" % [n, "" if n == 1 else "s"]
		"grimoire_pick":
			return "choose a spell from your spellbook: it joins your active spells for this fight"
		"rearrange":
			return "Rearrange %d" % n
		"duplicate":
			return "Duplicate %d" % (e.times - 1)
		"summon_spells":
			return "add %d random spells from your spellbook to your active row for this fight" % n
		"passive":
			return {"burn_bonus": "whenever you apply Burn, apply %d more" % n,
				"thorns": "gain %d Thorns for the rest of the fight" % n,
				"strike_poison": "all enemies your Release hits get Poison %d" % n,
				"strike_burn": "all enemies your Release hits get Burn %d" % n,
				"refund_air": "refund %d Air each chant" % n,
				"echo_first": "the first spell you cast each turn is cast twice",
				"attune": "pick 1 Essence. Gain 1 of that Essence each turn",
				"chant_slots": "+%d chant slot%s" % [n, "" if n == 1 else "s"],
				"draw_bonus": "+%d Essence every turn" % n,
				"strike_bonus": "your spells remove %d more Essence" % n}.get(e.key, e.key)
		"curse":
			var many := tg == "all"
			return {"no_mend": "%s can never Mend" % t,
				"exposed": "%s %s Exposed for the rest of the fight" % [t, "are" if many else "is"],
				"weak25": "%s %s 25%% less damage for the rest of the fight" % [t, "deal" if many else "deals"]}.get(e.key, e.key)
		"each_turn":
			return "at the start of each of your turns: " + "; ".join(e.effects.map(func(x): return describe_op(x)))
	return e.op
