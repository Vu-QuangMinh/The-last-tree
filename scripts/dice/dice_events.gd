class_name DiceEvents
extends RefCounted
## Die on Stage (2026-11-17): the "?" tiles play stories from the chant game (MapEvents.ALL), the ones whose choices
## only do things this mode has: lose or heal HP, more max HP, coins (the chant game's Leaves / 10), a random artifact,
## a fight. A choice that needs spells, bottles, Essence or a special scene is left out; an event needs at least
## MIN_OPTIONS choices left (and every page it opens too). Each event comes once a run (DiceRun.events_seen).

const OPS := ["damage", "heal", "max_hp", "amber", "artifact", "artifact_tier", "fight"]
const OPTION_BLOCKERS := ["pick_bottle", "pick_spell", "fuse", "minigame", "by_kind", "by_water", "scene", "then"]
const EVENT_BLOCKERS := ["scene", "hidden"]
const LEAVES_PER_COIN := 10
const MIN_OPTIONS := 2


## The events that can come, not met yet this run (`seen`: ids). (Any act's: this mode has few that fit; `_act` is
## kept for when it has more.)
static func pool(_act: int, seen: Array) -> Array:
	var out := []
	for e in MapEvents.ALL:
		if e.id in seen or EVENT_BLOCKERS.any(func(k): return e.has(k)):
			continue
		if options_of(e).size() >= MIN_OPTIONS:
			out.append(e)
	return out


## The choices of a page (an event, or an option's "next") that work here.
static func options_of(page: Dictionary) -> Array:
	return page.get("options", []).filter(func(o): return usable(o))


static func usable(o: Dictionary) -> bool:
	if OPTION_BLOCKERS.any(func(k): return o.has(k)):
		return false
	if o.get("do", null) is String:
		return o.do == "none"
	if o.has("next"):
		return options_of(o.next).size() >= MIN_OPTIONS
	var outs: Array = o.get("outcomes", [])
	if outs.is_empty():
		return false
	for oc in outs:
		if oc.get("curse_card", false) or oc.has("then"):
			return false
		for d in oc.get("do", []):
			if not ok_op(d):
				return false
	return true


static func ok_op(d: Dictionary) -> bool:
	if not (String(d.get("op", "")) in OPS):
		return false
	if d.op == "artifact" and d.get("pool", "normal") != "normal":
		return false  # (no cursed artifacts in this mode yet)
	if d.op == "fight" and d.has("ids"):
		return d.ids.all(func(id): return DiceRun._simple(id))
	return true


## The coins an option costs (its "amber", in Leaves).
static func cost(o: Dictionary) -> int:
	return int(ceil(float(o.get("amber", 0)) / LEAVES_PER_COIN))


## The chant game's words with its Leaves turned into coins ("50 Leaves" -> "5 coins").
static func words(t: String) -> String:
	var re := RegEx.new()
	re.compile("(\\d+) (more )?(golden )?[Ll]eaves")
	var out := t
	for m in re.search_all(t):
		var n := int(ceil(float(m.get_string(1)) / LEAVES_PER_COIN))
		out = out.replace(m.get_string(), "%d %scoin%s" % [n, m.get_string(2), "" if n == 1 else "s"])
	return out.replace("Leaves", "coins")


## One outcome of an option, rolled by its "chance".
static func roll(o: Dictionary, rng: RandomNumberGenerator) -> Dictionary:
	var outs: Array = o.get("outcomes", [])
	if outs.is_empty():
		return {"ok": String(o.get("ok", "Go on")), "text": "", "do": []}
	var r := rng.randf()
	for oc in outs:
		r -= float(oc.get("chance", 1.0))
		if r < 0.0:
			return oc
	return outs[outs.size() - 1]


## Does an outcome's effects on the run; returns a fight to start after it ({ids, kind}) or {}, and the artifacts
## gained (names) in "got".
static func apply(run: DiceRun, oc: Dictionary) -> Dictionary:
	var out := {"got": []}
	for d in oc.get("do", []):
		match String(d.op):
			"damage":
				run.hp = maxi(1, run.hp - int(d.n))  # (an event never kills you outright)
			"heal":
				run.heal(int(d.n))
			"max_hp":
				run.max_hp += int(d.n)
				run.heal(int(d.n))
			"amber":
				run.leaves = maxi(0, run.leaves + int(ceil(float(d.n) / LEAVES_PER_COIN)))
			"artifact", "artifact_tier":
				var ids := run.artifact_offer(1)
				if not ids.is_empty():
					run.gain_artifact(ids[0])
					out.got.append(DiceArtifacts.get_item(ids[0]).name)
			"fight":
				var kind := String(d.get("kind", "fight"))
				out["fight"] = {"ids": d.ids.duplicate() if d.has("ids") else run.encounter(kind), "kind": kind}
	return out
