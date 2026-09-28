class_name SpellText
extends RefCounted
## Rules text for spells: short, plain sentences, one per effect. The same words go on the card face and
## in the tooltip (where each keyword is also explained). "Damage" always means knocking elements off an
## enemy's HP bar; the first HP is the leftmost element, the last HP the rightmost.

const WHO := {"target": "an enemy", "all": "every enemy", "random": "a random enemy", "self": "you"}
const WHOSE := {"target": "an enemy's", "all": "every enemy's", "random": "a random enemy's"}


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


static func _turns(n: int) -> String:
	return "%d turn%s" % [n, "" if n == 1 else "s"]


static func describe_op(e: Dictionary) -> String:
	var tg: String = e.get("target", "target")
	var t: String = WHO.get(tg, "an enemy")
	var ts: String = WHOSE.get(tg, "an enemy's")
	var n: int = int(e.get("n", 0))
	match e.op:
		"strike":
			var s := "deal %d damage to the %s HP of %s" % [n, "last" if e.from == "right" else "first", t]
			if e.has("min_hp"):
				s += " (only if it has %d+ HP)" % e.min_hp
			if e.has("bonus_if"):
				s += " (+1 if it has Burn)"
			return s
		"pluck":
			return "deal %d Targeted damage to %s" % [n, t]
		"burn":
			return "apply %d Burn to %s" % [n, t]
		"poison":
			return "apply %d Poison to %s" % [n, t]
		"stoke":
			return "double the Burn on %s" % t
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
			return "heal %d" % n
		"aegis":
			return "gain %d Aegis" % n
		"thorns":
			return "gain %d Thorns this turn" % n
		"draw":
			var what: String = ("%d random element%s" % [n, "s" if n > 1 else ""]) if e.get("el", "random") == "random" else "%d %s" % [n, _el(e.el)]
			return "gain %s%s %s" % [what, " (Conjured)" if e.get("temp", false) else "", "now" if e.when == "now" else "next turn"]
		"move":
			if n == 1:
				return "Move 1 of %s HP to any spot you choose" % ts
			return "Move %d of %s HP, one at a time, to any spots you choose" % [n, ts]
		"rotate":
			if e.get("dir", "left") == "left":
				return "move the first HP of %s to the end" % t
			return "move the last HP of %s to the front" % t
		"swap":
			return "swap the first two HP of %s" % t
		"convert":
			var where: String = {"first": "the first HP", "first2": "the first 2 HP", "last": "the last HP",
				"all": ("every %s HP" % _el(e.from)) if e.has("from") else "every HP"}[e.pos]
			return "turn %s of %s into %s" % [where, t, _el(e.to)]
		"purge":
			return "Purge up to %d %s from %s" % [n, _el(e.el), t]
		"shatter":
			return "break all Armour on %s" % t
		"insert":
			return "add a %s to the front of %s HP" % [_el(e.el), ts]
		"siphon":
			return "deal %d damage to the first HP of %s; you gain what it loses as Conjured elements next turn" % [n, t]
		"execute":
			return "Execute %s with %d HP or less (not bosses)" % [t, e.max]
		"transmute":
			return "turn %d of your elements into %s" % [n, _el(e.to)]
		"sacrifice":
			return "lose %d of your HP" % e.hp
		"amplify":
			return "Amplify %d: when the chant is Released this turn, every enemy it hits takes %d more damage to its last HP" % [n, n]
		"echo":
			return "Echo: the chant is Released twice this turn"
		"retain":
			return "after the Release, keep the chant's last %d element%s" % [n, "s" if n > 1 else ""]
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
			return "Infuse a %s into the chant" % _el(e.el)
		"duplicate":
			return "Resonate: one element of the chant becomes %d in a row" % e.times
		"summon_spells":
			return "add %d random spells from your spellbook to your active row" % n
		"passive":
			return {"burn_bonus": "your Burn applies +%d stack" % n,
				"thorns": "gain %d Thorns for the rest of the fight" % n,
				"strike_poison": "every enemy your Release hits gets %d Poison" % n,
				"strike_burn": "every enemy your Release hits gets %d Burn" % n,
				"echo_first": "the first spell you cast each turn triggers twice",
				"attune": "one of your draws each turn is always your most-used element",
				"chant_slots": "your chant can be %d elements longer" % n,
				"strike_bonus": "your spells deal +%d damage" % n}.get(e.key, e.key)
		"curse":
			return {"no_mend": "%s can never Mend" % t,
				"exposed": "%s is Exposed for the rest of the fight" % t,
				"weak25": "%s deals 25%% less damage for the rest of the fight" % t}.get(e.key, e.key)
		"each_turn":
			return "at the start of each of your turns: " + "; ".join(e.effects.map(func(x): return describe_op(x)))
	return e.op
