class_name FuseRules
extends RefCounted
## How a fused spell's effects melt together (the first spell's effects, then the second's):
## - All its damage on a single enemy becomes ONE damage effect: the amounts add up, and where the two disagree it
##   takes the LESS controlled option. Aim: an enemy you choose > a random enemy > a random enemy for each hit
##   (Barrage). Where on its row: the Essence you choose (Snipe) > an end (from the left / right) > a random spot (left
##   and right together: a random spot too). Damage to all enemies or to 2 of them is a different reach: it stays.
## - Two Executes become one, at the higher number ("then Execute at X" if either came after damage).
## - Its damage on ALL enemies adds up too (from the left and from the right together: at random spots).
## - Riders follow the damage: if it went random, a rider aimed at "an enemy" goes random too. After a Barrage, a
##   stackable rider (Burn, Poison) is scattered one at a time ("apply 1 Burn 6 times", randomly) and any other one lands on
##   a random enemy; after a hit on one random enemy, the rider lands on that same enemy.
## - The same rider on the same enemies adds up, wherever it is (Freeze 1 and Freeze 2 on it: Freeze 3).
## - A conditional rider ("if it has 4+ Burn, Freeze it", "if it's attacking, Weaken it") fused with something that
##   hits all enemies checks every enemy, at the end: "Then apply 1 Freeze to each one with 4+ Burn".
## - Losing HP and healing in the same spell cancel out (heal 6, lose 5: heal 1).
## - Order: what it does to ONE enemy first (you pick it first), then what it does to several or all of them, then a
##   "then Execute", then what it does for you (Shield, healing, Essence, ...).
## Hand-made exceptions: OVERRIDES["a_id|b_id"] (the two ids sorted) = the fused effects to use instead.

const AIM := ["target", "random", "barrage"]  # most control first
const WHERE := ["pick", "end", "random"]
const OVERRIDES := {}


## The fused effects (an override for this pair if there is one).
static func merge(effects: Array, pair_key := "") -> Array:
	if pair_key != "" and OVERRIDES.has(pair_key):
		return (OVERRIDES[pair_key] as Array).duplicate(true)
	var out := _merge_executes(_merge_all_damage(_merge_damage(effects)))
	out = _merge_riders(_widen_conditions(_follow_damage(out)))
	return _order(_net_hp(_dedupe(out)))


## Single-enemy damage: [aim, where]; [] for anything else (conditions like "if it has 3+" keep it apart too).
static func damage_kind(e: Dictionary) -> Array:
	if e.has("min_hp") or e.has("bonus_if"):
		return []
	var tg: String = e.get("target", "target")
	match e.op:
		"strike":
			if tg in ["target", "random"]:
				return [tg, "end"]
		"random_hit":
			if tg in ["target", "random"]:
				return [tg, "random"]
		"pluck":
			if not e.has("el"):
				return ["target", "pick"]
		"barrage":
			return ["barrage", "random"]
	return []


static func _merge_damage(effects: Array) -> Array:
	var dmg := []
	var first := -1
	for i in effects.size():
		if not damage_kind(effects[i]).is_empty():
			dmg.append(i)
			if first < 0:
				first = i
	if dmg.size() < 2:
		return effects
	var n := 0
	var aim := 0
	var where := 0
	var side := ""
	for i in dmg:
		var e: Dictionary = effects[i]
		var k := damage_kind(e)
		n += int(e.get("n", 1))
		aim = maxi(aim, AIM.find(k[0]))
		where = maxi(where, WHERE.find(k[1]))
		if k[1] == "end":
			var sd: String = e.get("from", "right")
			if side == "":
				side = sd
			elif side != sd:
				where = maxi(where, 2)  # (from the left and from the right: wherever)
	if AIM[aim] != "target" and WHERE[where] == "pick":
		where = 2  # (a random enemy can't have a chosen Essence)
	var one := {}
	if AIM[aim] == "barrage":
		one = {"op": "barrage", "n": n}
	elif WHERE[where] == "pick":
		one = {"op": "pluck", "n": n, "target": "target"}
	elif WHERE[where] == "random":
		one = {"op": "random_hit", "n": n, "target": AIM[aim]}
	else:
		one = {"op": "strike", "n": n, "from": side, "target": AIM[aim]}
	var out := []
	for i in effects.size():
		if i == first:
			out.append(one)
		if not (i in dmg):
			out.append(effects[i])
	return out


static func _merge_executes(effects: Array) -> Array:
	var ex := []
	for i in effects.size():
		if effects[i].op == "execute":
			ex.append(i)
	if ex.size() < 2:
		return effects
	var best := 0
	var then := false
	for i in ex:
		best = maxi(best, int(effects[i].max))
		then = then or effects[i].get("then", false)
	var one: Dictionary = (effects[ex[0]] as Dictionary).duplicate(true)
	one.max = best
	if then:
		one.then = true
	var out := []
	var at: int = ex[-1] if then else ex[0]  # ("then": after all the damage; on its own: where the first one was)
	for i in effects.size():
		if not (i in ex):
			out.append(effects[i])
		if i == at:
			out.append(one)
	return out


static func _merge_all_damage(effects: Array) -> Array:
	var idx := []
	for i in effects.size():
		var e: Dictionary = effects[i]
		if e.op in ["strike", "random_hit"] and e.get("target", "") == "all" and not e.has("min_hp") and not e.has("bonus_if"):
			idx.append(i)
	if idx.size() < 2:
		return effects
	var n := 0
	var side := ""
	var random := false
	for i in idx:
		var e: Dictionary = effects[i]
		n += int(e.get("n", 1))
		if e.op == "random_hit":
			random = true
		elif side == "":
			side = e.get("from", "right")
		elif side != e.get("from", "right"):
			random = true
	var one := {"op": "random_hit", "n": n, "target": "all"} if random else {"op": "strike", "n": n, "from": side, "target": "all"}
	var out := []
	for i in effects.size():
		if i == idx[0]:
			out.append(one)
		elif not (i in idx):
			out.append(effects[i])
	return out


## Where its damage went once merged: "barrage" (a random enemy each hit), "random" (one random enemy) or "".
static func _widen_conditions(effects: Array) -> Array:
	if not effects.any(func(e): return e.get("target", "") == "all" and not _is_self(e)):
		return effects
	var out := []
	for e in effects:
		var x: Dictionary = (e as Dictionary).duplicate(true)
		if (x.has("if_burn") or x.has("if_attacking")) and x.get("target", "target") == "target":
			x.target = "all"
			x.late = true  # (after everything else it does to them)
		out.append(x)
	return out


static func _damage_aim(effects: Array) -> String:
	for e in effects:
		if e.op == "barrage":
			return "barrage"
		if e.op in ["strike", "random_hit"] and e.get("target", "") == "random":
			return "random"
	return ""


const SCATTERS := {"burn": "burn", "poison": "poison"}  # (stackable riders that a Barrage scatters one at a time)


static func _follow_damage(effects: Array) -> Array:
	var aim := _damage_aim(effects)
	if aim == "":
		return effects
	var out := []
	for e in effects:
		var x: Dictionary = (e as Dictionary).duplicate(true)
		if x.get("target", "") == "target" and not (x.op == "execute" and x.get("then", false)):
			if aim == "barrage" and SCATTERS.has(x.op) and not x.has("per_chant") and not x.has("if_burn"):
				x = {"op": "meteor_rain", "n": int(x.get("n", 1)), "what": SCATTERS[x.op]}
			elif aim == "barrage" and (x.has("if_burn") or x.has("if_attacking")):
				x.target = "hit"  # (a condition: it checks each enemy the Barrage hit)
				x.hit_many = true
			else:
				x.target = "random" if aim == "barrage" else "hit"
		out.append(x)
	return out


## The number a rider carries ("n", or "turns" for Weaken / Freeze).
static func _amount_key(e: Dictionary) -> String:
	return "turns" if e.has("turns") and not e.has("n") else "n"


const RIDERS := ["burn", "poison", "weak", "freeze", "daze", "steal", "shield", "heal", "thorns", "aegis", "draw", "meteor_rain", "expose", "max_hp", "vulnerable"]


## Things that only happen once however often they're said (Ethereal twice is Ethereal), and a Cleanse of everything
## swallows the cure of one debuff.
static func _dedupe(effects: Array) -> Array:
	var out := []
	var cleanse_all := effects.any(func(e): return e.op == "cleanse" and e.get("what", "all") == "all")
	for e in effects:
		if e.op in ["ethereal", "thorn_guard", "echo_next", "all_fragile"] and out.any(func(o): return o == e):
			continue
		if cleanse_all and e.op == "cleanse" and e.get("what", "all") != "all":
			continue
		out.append(e)
	return out


static func _merge_riders(effects: Array) -> Array:
	var out := []
	for e in effects:
		var merged := false
		if e.op in RIDERS and not (e.get("target", "") in ["random", "random2"]):
			var key := _amount_key(e)
			for o in out:
				if o.op == e.op and _same_but(o, e, key):
					o[key] = int(o.get(key, 0)) + int(e.get(key, 0))
					merged = true
					break
		if not merged:
			out.append((e as Dictionary).duplicate(true))
	return out


static func _same_but(a: Dictionary, b: Dictionary, key: String) -> bool:
	var x := a.duplicate()
	var y := b.duplicate()
	x.erase(key)
	y.erase(key)
	for d in [x, y]:
		if d.get("target", "") == "self":
			d.erase("target")  # (on you: "target": "self" written out or not, the same thing)
	return x == y


static func _net_hp(effects: Array) -> Array:
	var lose := -1
	var heal := -1
	for i in effects.size():
		var e: Dictionary = effects[i]
		if e.op == "sacrifice" and lose < 0:
			lose = i
		elif e.op == "heal" and heal < 0 and not e.has("if_kill") and not e.has("per_chant"):
			heal = i
	if lose < 0 or heal < 0:
		return effects
	var net := int(effects[heal].n) - int(effects[lose].hp)
	var out := []
	for i in effects.size():
		if i == lose or i == heal:
			if i == mini(lose, heal) and net != 0:
				out.append({"op": "heal", "n": net} if net > 0 else {"op": "sacrifice", "hp": -net})
			continue
		out.append(effects[i])
	return out


## What a spell does for you (it goes after what it does to the enemies).
const SELF_OPS := ["shield", "heal", "aegis", "thorns", "draw", "sacrifice", "vulnerable", "max_hp", "all_fragile", "transmute",
	"cleanse", "unbind", "retain", "overload", "echo_next", "conjure", "passive", "rearrange", "infuse", "thorn_guard",
	"mend_spell", "temp_seal", "grimoire_pick", "summon_spells", "duplicate", "amplify", "echo", "heal_per_extension",
	"infuse_upcoming", "self_repaint"]


static func _is_self(e: Dictionary) -> bool:
	return e.op in SELF_OPS or (e.op == "ethereal" and e.get("target", "") == "self")


static func _order(effects: Array) -> Array:
	var one := []
	var wide := []
	var follow := []  # (riders on whoever the damage hit: right after that damage)
	var executes := []
	var mine := []
	for e in effects:
		if _is_self(e):
			mine.append(e)
		elif (e.op == "execute" and e.get("then", false)) or e.get("late", false):
			executes.append(e)
		elif e.get("target", "") == "hit":
			follow.append(e)
		elif e.get("target", "") in ["all", "two", "random2"] or e.op in ["barrage", "meteor_rain"]:
			wide.append(e)
		else:
			one.append(e)
	# each group of enemies together (all of them, then 2 of them, then random ones), its hits first in each group
	var grouped := []
	for scope in ["all", "two", "random2", ""]:
		var g := wide.filter(func(e): return e.get("target", "") == scope or (scope == "" and not (e.get("target", "") in ["all", "two", "random2"])))
		grouped += g.filter(func(e): return e.op in Fight.HIT_OPS) + g.filter(func(e): return not (e.op in Fight.HIT_OPS))
	wide = grouped
	if effects.any(func(e): return e.op == "barrage"):
		return one + wide + follow + executes + mine  # (what follows a Barrage comes after it)
	return one + follow + wide + executes + mine
