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
	if int(s.get("cooldown", 0)) > 0:
		lines.append("Cooldown %d." % s.cooldown)
	return "\n".join(lines)


## The same rules as one paragraph (tooltips, reports).
static func describe(s: Dictionary) -> String:
	if s.has("desc"):
		return s.desc
	var text := " ".join(s.effects.map(func(e): return sentence(e)))
	if int(s.get("cooldown", 0)) > 0:
		text += " Cooldown %d." % s.cooldown
	if s.get("anti", false) and s.has("patterns"):
		text = "Anti-spell (either pattern breaks it): " + text
	elif s.get("anti", false):
		text = "Anti-spell: " + text
	elif s.get("power", false):
		text = "Power: " + text + " Lasts the whole fight."
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
			var side := "rightmost" if e.from == "right" else "leftmost"
			var s := "remove %s %s Essence" % [ts, side] if n == 1 else "remove %s %d %s Essence" % [ts, n, side]
			if tg == "two":
				s = "remove the %s Essence of 2 enemies" % side if n == 1 else "remove %d %s Essence of 2 enemies" % [n, side]
			if e.has("min_hp"):
				s += " (if it has %d+)" % e.min_hp
			if e.has("bonus_if"):
				s += ". +1 if it has Burn"
			return s
		"pluck":
			return "snipe %d" % n  # (you pick the Essence with the crosshair: see the Snipe keyword)
		"steal":
			if e.get("el", "any") == "any":
				if e.get("when", "now") == "next":
					return "Steal %d Essence from %s. Conjure %s next turn" % [n, t, "it" if n == 1 else "them"]
				return "Steal %d Essence from %s" % [n, t]
			return "Steal up to %d %s from %s" % [n, _el(e.el), t]
		"burn":
			return "Burn %d on %s" % [n, t]
		"poison":
			return "Poison %d on %s" % [n, t]
		"stoke":
			return "double %s Burn" % ts
		"weak":
			return "Weaken %d on %s" % [e.turns, t]
		"freeze":
			return "Freeze %d on %s" % [e.turns, t]
		"expose":
			return "Expose %d" % n
		"ethereal":
			return "become Ethereal this turn" if tg == "self" else "make %s Phased this turn" % t
		"shield":
			return "gain %d %sShield" % [n, "Lasting " if e.get("lasting", false) else ""]
		"heal":
			if e.get("if_kill", false):
				return "if it dies, heal %d HP" % n
			return "heal %d HP" % n
		"aegis":
			return "gain %d Aegis" % n
		"thorns":
			return "Thorns %d this turn" % n
		"draw":
			var what: String = ("%d Random" % n) if e.get("el", "random") == "random" else "%d %s" % [n, _el(e.el)]
			if e.get("temp", false) and e.when == "now":
				return "conjure %s" % what  # temporary Essence, right now: "Conjure 2 Water"
			return "gain %s%s%s" % [what, " (Conjured)" if e.get("temp", false) else "", "" if e.when == "now" else " next turn"]
		"move":
			return "move %d of %s Essence anywhere in its row" % [n, ts]
		"rotate":
			if e.get("dir", "left") == "left":
				return "move %s leftmost Essence to its right end" % ts
			return "move %s rightmost Essence to its left end" % ts
		"swap":
			return "swap %s 2 leftmost Essence" % ts
		"convert":
			if e.pos == "all":
				if e.has("from"):
					return "turn every %s of %s into %s" % [_el(e.from), t, _el(e.to)]
				return "turn all %s Essence into %s" % [ts, _el(e.to)]
			var where: String = {"first": "leftmost Essence", "first2": "2 leftmost Essence", "last": "rightmost Essence"}[e.pos]
			return "turn %s %s into %s" % [ts, where, _el(e.to)]
		"purge":
			return "remove up to %d %s from %s" % [n, _el(e.el), t]
		"shatter":
			return "break %s Armour" % ts
		"insert":
			return "add %s to the left end of %s row" % [_a(_el(e.el)), ts]
		"siphon":
			return "remove %s %s leftmost Essence; get %s next turn (Conjured)" % [ts, "" if n == 1 else str(n), "it" if n == 1 else "them"]
		"execute":
			return "Execute %s with %d or less Essence" % [t, e.max]
		"transmute":
			return "turn %d unused Essence into %s" % [n, _el(e.to)]
		"sacrifice":
			return "lose %d HP" % e.hp
		"vulnerable":
			return "Vulnerable %d on you" % n
		"meteor_rain":
			return "Burn 1 on a random enemy, %d times" % n
		"disarm":
			return "Disarm %s" % t
		"forbidden":
			return "it does nothing"
		"amplify":
			return "Amplify %d" % n
		"echo":
			return "Echo"
		"retain":
			return "Refund your chant's rightmost Essence" if n == 1 else "Refund your chant's %d rightmost Essence" % n
		"overload":
			return "Overload %d" % n
		"cleanse":
			return {"all": "Cleanse all your debuffs", "blind": "Cure Blind", "bleed": "Cure Bleed", "confuse": "Cure Confuse",
				"silence": "Cure Silence", "frozen": "thaw your Frozen Essence", "lock": "break 1 Lock"}[e.get("what", "all")]
		"copy_last":
			return "repeat your last spell this turn"
		"redirect":
			return "Redirect %s intent" % ts
		"infuse":
			if e.el == "random":
				return "Infuse %d Random" % maxi(1, n)
			return "Infuse %d %s" % [maxi(1, n), _el(e.el)]
		"annihilate":
			return "Annihilate 1 kind of Essence on %s" % t
		"barrage":
			return "remove %d random Essence from random enemies" % n
		"random_hit":
			return "remove %d random Essence of %s" % [n, t]
		"echo_next":
			return "your next spell this fight is cast twice"
		"conjure":
			return "conjure %d spell%s" % [n, "" if n == 1 else "s"]
		"grimoire_pick":
			return "add a spell from your spellbook to this fight"
		"rearrange":
			return "Rearrange %d" % n
		"duplicate":
			return "Duplicate %d" % (e.times - 1)
		"summon_spells":
			return "add %d random spells from your spellbook to this fight" % n
		"passive":
			return {"burn_bonus": "your Burn +%d" % n,
				"thorns": "Thorns %d all fight" % n,
				"strike_poison": "your Release puts Poison %d on what it hits" % n,
				"strike_burn": "your Release puts Burn %d on what it hits" % n,
				"refund_air": "Refund %d Air each chant" % n,
				"echo_first": "your first spell each turn is cast twice",
				"attune": "pick 1 Essence. Gain 1 of that Essence each turn",
				"chant_slots": "+%d chant slot%s" % [n, "" if n == 1 else "s"],
				"draw_bonus": "+%d Essence every turn" % n,
				"strike_bonus": "your spells remove %d more Essence" % n}.get(e.key, e.key)
		"curse":
			var many := tg == "all"
			return {"no_mend": "%s can't Mend" % t,
				"exposed": "%s %s Exposed all fight" % [t, "are" if many else "is"],
				"weak25": "%s %s 25%% less all fight" % [t, "deal" if many else "deals"]}.get(e.key, e.key)
		"each_turn":
			return "each turn: " + "; ".join(e.effects.map(func(x): return describe_op(x)))
	return e.op
