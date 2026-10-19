class_name SpellText
extends RefCounted
## Rules text for spells: short, plain sentences, one per effect. The same words go on the card face and
## in the tooltip (where each keyword is also explained). Everything Fire / Water / Air is "Essence": yours
## (in your bag and chant) and the enemies' (their HP row). Knocking an enemy's Essence off is "damage": each point
## takes 1 Essence. Right damage takes it from the right end of its row, Left damage from the left end (keywords: the
## hover box explains them), Random damage from random spots of its row.
## Condensed (fused spells stack two spells' effects): back-to-back damage on the same enemy is one sentence
## ("Deal 1 Right damage and 1 damage at a random spot to an enemy"), and back-to-back copies of the same effect add
## up ("Gain 4 Shield" twice: "Gain 8 Shield"). Effects aimed at random enemies are never merged (they may land apart).

const WHO := {"hit": "it", "target": "an enemy", "two": "2 different enemies", "all": "all enemies", "random": "a random enemy", "random2": "2 random enemies", "self": "you"}
const WHOSE := {"hit": "its", "target": "an enemy's", "two": "2 different enemies'", "all": "all enemies'", "random": "a random enemy's", "random2": "2 random enemies'"}


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
	if s.get("trinity", false):
		lines.append("Trinity.")
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
	if s.get("trinity", false):
		text += " Trinity."
	return text


static func sentence(e: Dictionary, same := false) -> String:
	var t := describe_op(e, same)
	return t[0].to_upper() + t.substr(1) + "."


## One sentence per effect (condensed: see the top). Once an effect has picked "an enemy", later ones on that same
## enemy say "it" / "its" ("Deal 1 Right damage to an enemy. Apply 1 Weaken to it.").
static func _sentences(effects: Array) -> Array:
	var out := []
	var picked := false
	var i := 0
	while i < effects.size():
		var e: Dictionary = effects[i]
		var mine: bool = e.get("target", "") == "target"
		var same := picked and mine
		var j := i + 1
		var one_all := _one_then_all(effects, i, same)
		if not one_all.is_empty():
			# one enemy first (you pick it), then everyone: "Deal 3 damage and apply 2 Burn to an enemy, then 5 damage
			# and 3 Burn to all"; "Apply 6 Burn to an enemy, then 3 more to all"
			out.append(one_all[0])
			picked = picked or mine
			i = one_all[1]
			continue
		if _simple(e) and e.get("target", "") == "all" and j < effects.size() and _simple(effects[j]) and effects[j].get("target", "") == "all":
			# several things to all of them: "Deal 5 Right damage and apply 3 Burn to all enemies"
			var run := [e]
			while j < effects.size() and _simple(effects[j]) and effects[j].get("target", "") == "all":
				run.append(effects[j])
				j += 1
			var text := _and(run.map(func(x): return _verb(x))) + " to all enemies"
			out.append(text[0].to_upper() + text.substr(1) + ".")
			i = j
			continue
		if _plain_damage(e):
			# damage, then more damage on the same enemy (or the same group): one sentence
			var parts := [[int(e.get("n", 1)), e]]  # [damage, an effect saying where it lands]
			while j < effects.size() and _plain_damage(effects[j]) and _same_target(e, effects[j]):
				if _how(parts[-1][1]) == _how(effects[j]):
					parts[-1][0] += int(effects[j].get("n", 1))  # (1 from the right, then 1 more from the right: 2)
				else:
					parts.append([int(effects[j].get("n", 1)), effects[j]])
				j += 1
			var who: String = "it" if same else WHO.get(e.get("target", "target"), "an enemy")
			var text := ""
			if parts.size() == 1:
				text = "Deal %s to %s%s" % [_dmg(parts[0][1], parts[0][0]), who, _tail(parts[0][1], parts[0][0])]
			else:
				text = "Deal %s to %s" % [_and(parts.map(func(pt): return _dmg_full(pt[1], pt[0]))), who]
			out.append(text + ".")
		elif e.op == "barrage" and j < effects.size() and effects[j].op == "meteor_rain":
			# random hits and random Burn: "Randomly deal 1 damage 3 times and apply 1 Burn 6 times"
			var r: Dictionary = effects[j]
			out.append("Randomly deal 1 damage %d times and apply 1 %s %d times." % [int(e.n), "Poison" if r.get("what", "burn") == "poison" else "Burn", int(r.n)])
			j += 1
		elif e.op == "shield" and j < effects.size() and effects[j].op == "shield":
			# "Gain 10 Lasting Shield and 5 Shield"
			var parts := ["%d %sShield" % [int(e.n), "Lasting " if e.get("lasting", false) else ""]]
			while j < effects.size() and effects[j].op == "shield":
				parts.append("%d %sShield" % [int(effects[j].n), "Lasting " if effects[j].get("lasting", false) else ""])
				j += 1
			out.append("Gain " + _and(parts) + ".")
		else:
			var total := int(e.get("n", 0))
			while j < effects.size() and _adds_up(e, effects[j]):
				total += int(effects[j].get("n", 0))
				j += 1
			var shown := e
			if j > i + 1:
				shown = e.duplicate(true)
				shown.n = total
			out.append(sentence(shown, same))
		picked = picked or (mine and not (e.op in ["move", "pluck"]))  # (keyword-only text, "Rearrange 1", names no enemy)
		i = j
	return out


## Damage and plain riders that can share a "one enemy, then all" sentence (no conditions on them).
const ONE_ALL := ["strike", "random_hit", "burn", "poison", "weak", "freeze", "daze"]


static func _simple(e: Dictionary) -> bool:
	return e.op in ONE_ALL and not (e.has("min_hp") or e.has("bonus_if") or e.has("if_attacking") or e.has("if_burn") or e.has("per_chant"))


static func _amount(e: Dictionary) -> int:
	return int(e.get("n", e.get("turns", 0)))


## What it does to the one enemy, as a verb: "deal 3 Right damage" / "apply 2 Burn".
static func _verb(e: Dictionary) -> String:
	if e.op in ["strike", "random_hit"]:
		return "deal " + _dmg_full(e, _amount(e))
	return "apply %d %s" % [_amount(e), {"burn": "Burn", "poison": "Poison", "weak": "Weaken", "freeze": "Freeze", "daze": "Dazed"}[e.op]]


## The same for everyone, as a noun: "5 Right damage" / "3 Burn".
static func _noun(e: Dictionary) -> String:
	return _verb(e).trim_prefix("deal ").trim_prefix("apply ")


static func _and(parts: Array) -> String:
	if parts.size() <= 1:
		return "".join(parts)
	return ", ".join(parts.slice(0, parts.size() - 1)) + " and " + parts[-1]


## A run of effects on one enemy followed by a run on all of them: [the sentence, where the next effect starts], or [].
static func _one_then_all(effects: Array, i: int, same: bool) -> Array:
	var one := []
	var k := i
	while k < effects.size() and _simple(effects[k]) and effects[k].get("target", "target") in ["target", "random", "hit"] \
			and (one.is_empty() or effects[k].get("target", "target") == one[0].get("target", "target")):
		one.append(effects[k])
		k += 1
	var all := []
	while k < effects.size() and _simple(effects[k]) and effects[k].get("target", "target") == "all":
		all.append(effects[k])
		k += 1
	if one.is_empty() or (all.is_empty() and one.size() < 2):
		return []
	if all.is_empty():
		# several things to one enemy: "Deal 3 Right damage and apply 2 Burn to an enemy"
		var tg1: String = one[0].get("target", "target")
		var who1: String = "it" if same or tg1 == "hit" else WHO.get(tg1, "an enemy")
		var only := _and(one.map(func(e): return _verb(e))) + " to " + who1
		return [only[0].to_upper() + only.substr(1) + ".", k]
	var tg: String = one[0].get("target", "target")
	var who: String = "it" if same or tg == "hit" else WHO.get(tg, "an enemy")
	var first := _and(one.map(func(e): return _verb(e))) + " to " + who
	if one.size() == 1 and one[0].op in ["strike", "random_hit"]:
		first = "deal %s to %s%s" % [_dmg(one[0], _amount(one[0])), who, _tail(one[0], _amount(one[0]))]  # (one hit: "at random spots" goes last)
	var then := ""
	if one.size() == 1 and all.size() == 1 and one[0].op == all[0].op and _how(one[0], 2) == _how(all[0], 2):
		then = "%d more" % _amount(all[0])  # (the same thing on everyone: "then 3 more to all")
	else:
		then = _and(all.map(func(e): return _noun(e)))
	return [first[0].to_upper() + first.substr(1) + ", then " + then + " to all.", k]


## Damage that is only damage (no "if it has 3+" or "+1 if it has Burn"): it can share a sentence.
static func _plain_damage(e: Dictionary) -> bool:
	return e.op in ["strike", "random_hit"] and not e.has("min_hp") and not e.has("bonus_if")


## "Deal 3 Right damage to an enemy" / "Deal 3 Left damage to an enemy" / "Deal 2 damage to an enemy at random spots":
## the damage as a noun ("3 Right damage") and what goes after its target (" at random spots", or "").
static func _dmg(e: Dictionary, n: int) -> String:
	if e.op == "random_hit":
		return "%d Random damage" % n  # (at random spots of its row)
	return "%d %s damage" % [n, "Right" if e.get("from", "right") == "right" else "Left"]


static func _tail(_e: Dictionary, _n: int) -> String:
	return ""  # (Right / Left / Random damage say it all now)


## The damage with where it lands, for a list: "3 Right damage" / "2 damage at random spots".
static func _dmg_full(e: Dictionary, n: int) -> String:
	return _dmg(e, n) + _tail(e, n)


## Where the damage lands on its row (to tell two hits apart): "from the right" / "from the left" / "at a random spot"
## (n of them: "at random spots").
static func _how(e: Dictionary, n := 1) -> String:
	if e.op == "random_hit":
		return "at a random spot" if n == 1 else "at random spots"
	return "from the right" if e.get("from", "right") == "right" else "from the left"


## The same enemy (or the very same group) for both: never random ones, which may land on different enemies.
static func _same_target(a: Dictionary, b: Dictionary) -> bool:
	var t: String = a.get("target", "target")
	return t == b.get("target", "target") and t in ["target", "all", "two"]


const ADDS_UP := ["shield", "heal", "burn", "poison", "thorns", "aegis", "draw", "pluck", "steal", "amplify", "retain",
	"overload", "daze", "meteor_rain", "barrage", "expose", "siphon", "random_hit"]


## Two copies of the same effect in a row whose numbers just add up (everything else about them the same).
static func _adds_up(a: Dictionary, b: Dictionary) -> bool:
	if a.op != b.op or not (a.op in ADDS_UP) or a.get("target", "target") in ["random", "random2"]:
		return false
	var ka := a.duplicate()
	var kb := b.duplicate()
	ka.erase("n")
	kb.erase("n")
	return ka == kb


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
			var s := "deal %s to %s%s" % [_dmg(e, n), t, _tail(e, n)]
			if e.has("min_hp"):
				s += " (each one with %d+)" % e.min_hp if tg in ["all", "two", "random2"] else " (if it has %d+)" % e.min_hp
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
		"stoke":
			return "double %s Burn" % ts
		"weak":
			if e.get("if_attacking", false):
				if e.get("hit_many", false):
					return "then apply %d Weaken to each one hit that's attacking" % e.turns
				if tg == "all":
					return "then apply %d Weaken to each one that's attacking" % e.turns
				return "if it's attacking, apply %d Weaken to it" % e.turns
			return "apply %d Weaken to %s" % [e.turns, t]
		"freeze":
			if e.has("if_burn"):
				if e.get("hit_many", false):
					return "then apply %d Freeze to each one hit with %d+ Burn" % [e.turns, int(e.if_burn)]
				if tg == "all":
					return "then apply %d Freeze to each one with %d+ Burn" % [e.turns, int(e.if_burn)]
				return "then if it has %d+ Burn, apply %d Freeze to it" % [int(e.if_burn), e.turns]
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
			return "deal up to %d damage to %s %s" % [n, ts, _el(e.el)]
		"shatter":
			if int(e.get("shield_per", 0)) > 0:
				return "break %s Armour. Gain %d Shield for each Armour broken" % [ts, int(e.shield_per)]
			return "break %s Armour" % ts
		"insert":
			return "add %s to the left end of %s row" % [_a(_el(e.el)), ts]
		"siphon":
			return "deal %d Left damage to %s; get %s next turn (Conjured)" % [n, t, "it" if n == 1 else "them"]
		"execute":
			if e.get("then", false):
				return "then Execute at %d" % e.max  # (every enemy its damage hit)
			return "Execute %s at %d" % [t, e.max]
		"transmute":
			return "turn %d unused Essence into %s" % [n, _el(e.to)]
		"sacrifice":
			return "lose %d HP" % e.hp
		"vulnerable":
			return "gain %d Vulnerable" % n
		"meteor_rain":
			return "randomly apply 1 %s %d times" % ["Poison" if e.get("what", "burn") == "poison" else "Burn", n]
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
			return "deal 1 damage to every %s of %s" % [_el(e.el), t]
		"mend_spell":
			return "give 1 Durability to a spell (a broken one is mended)"
		"daze":
			return "apply %d Dazed to %s" % [n, t]
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
				return "Cleanse all your debuffs. Gain %d Lasting Shield for each one" % int(e.lasting_per)
			return {"all": "Cleanse all your debuffs", "blind": "Cure Blind", "poison": "Cure Poison", "confuse": "Cure Confuse",
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
			return "randomly deal 1 damage %d times" % n
		"random_hit":
			return "deal %s to %s%s" % [_dmg(e, n), t, _tail(e, n)]
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
				"snipe_bonus": "your Snipes deal %d more damage" % n,
				"shield_per_burn": "each time you apply Burn to an enemy, gain %d Shield" % n,
				"all_lasting": "all your Shield is Lasting",
				"disturbance": "whenever an Essence is added to or removed from your chant after you Chant, deal 1 damage to that Essence of a random enemy",
				"strike_bonus": "your spells deal %d more damage" % n}.get(e.key, e.key)
		"curse":
			var many := tg == "all"
			return {"no_mend": "prevent %s from Mending" % t,
				"exposed": "%s %s Exposed all fight" % [t, "are" if many else "is"],
				"weak25": "%s %s 25%% less all fight" % [t, "deal" if many else "deals"]}.get(e.key, e.key)
		"each_turn":
			return "each turn: " + "; ".join(e.effects.map(func(x): return describe_op(x)))
	return e.op
