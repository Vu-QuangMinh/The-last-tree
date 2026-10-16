class_name SpellText
extends RefCounted
## Rules text for spells: short, plain sentences, one per effect. The same words go on the card face and
## in the tooltip (where each keyword is also explained). Everything Fire / Water / Air is "Essence": yours
## (in your bag and chant) and the enemies' (their HP row). Positions are always "leftmost" / "rightmost"
## (never first / last): "remove the 3 rightmost Essence of an enemy" takes the 3 at its right end.

const WHO := {"target": "an enemy", "two": "2 different enemies", "all": "all enemies", "random": "a random enemy", "random2": "2 random enemies", "self": "you"}
const WHOSE := {"target": "an enemy's", "two": "2 different enemies'", "all": "all enemies'", "random": "a random enemy's", "random2": "2 random enemies'"}


## One sentence per effect, each on its own line.
static func card_text(s: Dictionary) -> String:
	if s.has("desc"):
		return s.desc  # (the Invoker's spells: written out)
	var lines := _sentences(s.effects)
	if int(s.get("cooldown", 0)) > 0:
		lines.append("Cooldown %d." % s.cooldown)
	if Fight.base_durability(s) > 0 or s.has("durability_left"):
		lines.append("Durability %d." % int(s.get("durability_left", Fight.base_durability(s))))
	if s.get("exhaust", false):
		lines.append("Exhaust.")
	return "\n".join(lines)


## The same rules as one paragraph (tooltips, reports).
static func describe(s: Dictionary) -> String:
	if s.has("desc"):
		return s.desc
	var text := " ".join(_sentences(s.effects))
	if int(s.get("cooldown", 0)) > 0:
		text += " Cooldown %d." % s.cooldown
	if s.get("anti", false) and s.has("patterns"):
		text = "Anti-spell (either pattern breaks it): " + text
	elif s.get("anti", false):
		text = "Anti-spell: " + text
	elif s.get("power", false):
		text = "Power: " + text + " Lasts the whole fight."
	elif Fight.base_durability(s) > 0:
		text += " Durability %d." % int(s.get("durability_left", Fight.base_durability(s)))
	if s.get("exhaust", false):
		text += " Exhaust."
	if s.get("ephemeral", false):
		text += " Ephemeral."
	return text


static func sentence(e: Dictionary, same := false) -> String:
	var t := describe_op(e, same)
	return t[0].to_upper() + t.substr(1) + "."


## One sentence per effect. Once an effect has picked "an enemy", later ones on that same enemy say "it" / "its"
## ("Remove an enemy's rightmost Essence. Apply 1 Weaken to it.").
static func _sentences(effects: Array) -> Array:
	var out := []
	var picked := false
	for e in effects:
		var mine: bool = e.get("target", "") == "target"
		out.append(sentence(e, picked and mine))
		picked = picked or (mine and not (e.op in ["move", "pluck"]))  # (keyword-only text, "Rearrange 1", names no enemy)
	return out


static func _el(c: String) -> String:
	return Elements.NAMES.get(c, c)


## "the 3 rightmost Essence of an enemy" / "the leftmost Essence of an enemy".
static func _ends(who: String, n: int, last: bool) -> String:
	var side := "rightmost" if last else "leftmost"
	if n == 1:
		return "the %s Essence of %s" % [side, who]
	return "the %d %s Essence of %s" % [n, side, who]


## The colour a Repaint paints, as a word the card turns into its orb ("Random": the tri-colour Any orb).
static func _paint(to: String) -> String:
	return "Random" if to == "?" else _el(to)


static func _a(word: String) -> String:
	return ("an " if word.substr(0, 1).to_lower() in ["a", "e", "i", "o", "u"] else "a ") + word


static func _turns(n: int) -> String:
	return "%d turn%s" % [n, "" if n == 1 else "s"]


static func describe_op(e: Dictionary, same := false) -> String:
	var tg: String = e.get("target", "target")
	var t: String = "it" if same else WHO.get(tg, "an enemy")
	var ts: String = "its" if same else WHOSE.get(tg, "an enemy's")
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
			if e.has("el"):
				return "snipe %d %s" % [n, _el(e.el)]  # (only that kind)
			return "snipe %d" % n  # (you pick the Essence with the crosshair: see the Snipe keyword)
		"steal":
			if e.get("into", "") == "chant":
				return ("Instant Steal %d" % n) if e.get("el", "any") == "any" else "Instant Steal up to %d %s" % [n, _el(e.el)]
			if e.get("el", "any") == "any":
				if e.get("when", "now") == "next":
					return "Steal %d Essence from %s. Conjure %s next turn" % [n, t, "it" if n == 1 else "them"]
				return "Steal %d Essence from %s" % [n, t]
			return "Steal up to %d %s from %s" % [n, _el(e.el), t]
		"burn":
			if e.has("per_chant"):
				return "apply %d Burn to %s for every %d %s in your chant" % [n, t, int(e.get("per", 1)), _el(e.per_chant)]
			return "apply %d Burn to %s" % [n, t]
		"poison":
			return "apply %d Poison to %s" % [n, t]
		"stoke":
			return "double %s Burn" % ts
		"weak":
			if e.get("if_attacking", false):
				return "if it intends to attack, apply %d Weaken to it" % e.turns
			return "apply %d Weaken to %s" % [e.turns, t]
		"freeze":
			if e.has("if_burn"):
				return "then if it has %d or more Burn, apply %d Freeze to it" % [int(e.if_burn), e.turns]
			return "apply %d Freeze to %s" % [e.turns, t]
		"expose":
			return "Repaint %d %s" % [n, _paint(e.get("to", "?"))]
		"wild_move":
			return "Wild Rearrange %d" % n
		"wild_repaint":
			return "Wild Repaint %d %s" % [n, _paint(e.get("to", "?"))]
		"self_repaint":
			return "Self-Repaint %d %s" % [n, _paint(e.get("to", "?"))]
		"ethereal":
			return "become Ethereal this turn" if tg == "self" else "make %s Phased this turn" % t
		"shield":
			return "gain %d %sShield" % [n, "Lasting " if e.get("lasting", false) else ""]
		"heal":
			if e.get("if_kill", false):
				return "if it dies, heal %d HP" % n
			if e.has("per_chant"):
				return "heal %d HP for each %s in your chant" % [n, _el(e.per_chant)]
			return "heal %d HP" % n
		"aegis":
			return "gain %d Evasion" % n
		"thorns":
			return "gain %d Thorns this turn" % n
		"draw":
			var what: String = ("%d Random" % n) if e.get("el", "random") == "random" else "%d %s" % [n, _el(e.el)]
			if e.get("temp", false) and e.when == "now":
				return "conjure %s" % what  # temporary Essence, right now: "Conjure 2 Water"
			return "gain %s%s%s" % [what, " (Conjured)" if e.get("temp", false) else "", "" if e.when == "now" else " next turn"]
		"move":
			return "Rearrange %d" % n  # (an enemy's row: see the keyword)
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
			if int(e.get("shield_per", 0)) > 0:
				return "break %s Armour. Gain %d Shield for each Armour broken" % [ts, int(e.shield_per)]
			return "break %s Armour" % ts
		"insert":
			return "add %s to the left end of %s row" % [_a(_el(e.el)), ts]
		"siphon":
			return "remove %s %s leftmost Essence; get %s next turn (Conjured)" % [ts, "" if n == 1 else str(n), "it" if n == 1 else "them"]
		"execute":
			if e.get("then", false):
				return "then if it has %d or fewer Essence, Execute it" % e.max
			return "Execute %s with %d or less Essence" % [t, e.max]
		"transmute":
			return "turn %d unused Essence into %s" % [n, _el(e.to)]
		"sacrifice":
			return "lose %d HP" % e.hp
		"vulnerable":
			return "apply %d Vulnerable to yourself" % n
		"meteor_rain":
			return "apply 1 Burn to a random enemy, %d times" % n
		"disarm":
			return ("Disarm %s for %d turns" % [t, int(e.turns)]) if int(e.get("turns", 1)) > 1 else "Disarm %s" % t
		"amplify":
			return "Amplify %d" % n
		"echo":
			return "Echo"
		"retain":
			return "Refund %d" % n
		"overload":
			return "Overload %d" % n
		"purge_all":
			return "remove every %s from %s" % [_el(e.el), t]
		"mend_spell":
			return "give 1 Durability to a spell (a broken one is mended)"
		"daze":
			return "apply %d Dazed to %s" % [n, t]
		"poison_retort":
			return "each time you're hit until your next turn, apply %d Poison to all enemies" % n
		"heal_per_extension":
			return "heal %d HP for each Extension it causes" % n
		"infuse_upcoming":
			return "Infuse your upcoming Essence"
		"temp_seal":
			return "seal 1 Essence of another spell for this fight"
		"max_hp":
			return "gain %d max HP" % n
		"all_fragile":
			return "all your spells have Durability 1 this fight"
		"thorn_guard":
			return "enemy thorns don't hurt you this turn"
		"unbind":
			return "cure Silence, Frozen and Ignited. Heal %d for each one cured" % int(e.get("heal_per", 0))
		"cleanse":
			if int(e.get("lasting_per", 0)) > 0:
				return "Cleanse all your debuffs. Gain %d Lasting Shield for each one cleansed" % int(e.lasting_per)
			return {"all": "Cleanse all your debuffs", "blind": "Cure Blind", "bleed": "Cure Bleed", "confuse": "Cure Confuse",
				"silence": "Cure Silence", "frozen": "thaw your Frozen Essence", "lock": "break 1 Lock"}[e.get("what", "all")]
		"copy_last":
			return "repeat your last spell this turn"
		"redirect":
			return "Redirect %s intent" % ts
		"infuse":
			if e.el == "random":
				return "Infuse %d Random" % maxi(1, n)
			if e.el == "?":
				return "Infuse %d Any Essence" % maxi(1, n)
			return "Infuse %d %s" % [maxi(1, n), _el(e.el)]
		"annihilate":
			return "Annihilate 1 kind of Essence on %s" % t
		"barrage":
			return "remove 1 random enemy Essence, %d times" % n
		"random_hit":
			return "remove %d random Essence of %s" % [n, t]
		"echo_next":
			return "your next spell this fight is cast twice"
		"conjure":
			if e.get("kind", "") != "":
				return "conjure %d %s spell%s" % [n, SpellDB.KIND_NAMES[e.kind].to_lower(), "" if n == 1 else "s"]
			return "conjure %d spell%s" % [n, "" if n == 1 else "s"]
		"grimoire_pick":
			return "add a spell from your spellbook to this fight"
		"rearrange":
			return "Self-Rearrange %d" % n  # (your chant)
		"duplicate":
			return "Duplicate %d" % (e.times - 1)
		"summon_spells":
			return "add %d random spells from your spellbook to this fight" % n
		"passive":
			return {"burn_bonus": "your Burn +%d" % n,
				"thorns": "gain %d Thorns for the whole fight" % n,
				"strike_poison": "your Release applies %d Poison to every enemy it hits" % n,
				"strike_burn": "your Release applies %d Burn to every enemy it hits" % n,
				"refund_air": "Refund %d Air each chant" % n,
				"echo_first": "your first spell each turn is cast twice",
				"attune": "pick 1 Essence. Gain 1 of that Essence each turn",
				"chant_slots": "+%d chant slot%s" % [n, "" if n == 1 else "s"],
				"draw_bonus": "+%d Essence every turn" % n,
				"durability_bonus": "your spells with Durability get +%d Durability" % n,
				"thorns_on_hit": "each time you are attacked, gain %d Thorns for the whole fight" % n,
				"chant_max": "your chant holds at most %d Essence" % n,
				"steal_each_chant": "each time you Chant: Instant Steal %d" % n,
				"snipe_bonus": "your Snipes remove %d more" % n,
				"shield_per_burn": "each time you apply Burn to an enemy, gain %d Shield" % n,
				"all_lasting": "all your Shield is Lasting",
				"disturbance": "whenever an Essence is added to or removed from your chant after you Chant, remove the same Essence from a random enemy",
				"strike_bonus": "your spells remove %d more Essence" % n}.get(e.key, e.key)
		"curse":
			var many := tg == "all"
			return {"no_mend": "prevent %s from Mending" % t,
				"exposed": "%s %s Exposed all fight" % [t, "are" if many else "is"],
				"weak25": "%s %s 25%% less all fight" % [t, "deal" if many else "deals"]}.get(e.key, e.key)
		"each_turn":
			return "each turn: " + "; ".join(e.effects.map(func(x): return describe_op(x)))
	return e.op
