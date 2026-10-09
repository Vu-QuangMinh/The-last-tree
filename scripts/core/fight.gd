class_name Fight
extends RefCounted
## One encounter. UI-agnostic: the screen (or the balance sim) supplies these async callbacks:
##   chooser:     (spell, candidates: Array[int]) -> int        target enemy, when one wasn't given up front
##   mover:       (spell, enemy) -> [from, to]                   Move: rearrange an enemy's HP ([] skips)
##   picker:      (spell, enemy) -> int                          Pluck: which HP element to remove
##   painter:     (spell) -> [enemy, index]                      Expose: which Essence becomes Any ([] = none left)
##   redirector:  (spell, source, candidates) -> int             Misdirection: who the intent hits instead
##   placer:      (spell, el) -> int                             Infuse: where in the chant the element goes
##   chant_picker:(spell) -> int                                 Resonance: which chant element to copy
##   element_chooser:(spell, counts {el: n}) -> String           Annihilate: which element to wipe out
##   attune_chooser:(spell) -> String                             Attunement: which Essence to gain every turn
##   arranger:    (spell) -> [from, to]                          Rearrange: move one chant element ([] = keep)
##   spell_chooser:(spells: Array) -> int                         Grimoire Ink: which spellbook spell joins (-1: none)
##   anim:        (event: Dictionary) -> void                    animation hook
##
## Your turn:
##   1. cast_chant(): the chant is spoken. Every spell whose pattern appears gains one charge (a spell triggers at
##      most once per turn). A spell whose whole pattern is sealed (upgrades) triggers on every chant.
##   2. resolve_spell(): you cast charges one at a time, in any order. Spells that change the chant re-count
##      the charges straight away, so they can bring other spells to life.
##   3. finish_turn(): the Release. The chant flies at the enemies element by element, left to right; then they act.

const MAX_ENEMIES := 5
const EMBLEMS := {"fire_emblem": "F", "water_emblem": "W", "wind_emblem": "A"}
const HEARTS := {"ember_heart": "F", "tide_heart": "W", "gale_heart": "A"}
const LENSES := {"flame_lens": "F", "tide_lens": "W", "gale_lens": "A"}
## A redirected attack removes 1 element per this much damage (rounded up, at least 1 per hit).
const REDIRECT_DMG_PER_ELEMENT := 3.0
## Moves aimed at you. When an intent is redirected, attacks hit the new target and these fizzle.
const IGNITE_DAMAGE := 5  # casting an Ignited spell burns you this much (the Ember Sprite)
const AT_PLAYER := ["disarm", "drain_essence", "invert_spells", "ignite_spell", "silence", "lock", "steal", "confuse", "blind", "bleed", "freeze", "toll", "invert", "hex", "mimic", "frail", "brittle"]

var rng := RandomNumberGenerator.new()
var db: SpellDB
var player: PlayerState
var enemies: Array = []  # EnemyState
var loadout: Array = []  # spell dicts in the active row
var spellbook: Array = []  # spell dicts you own (for Open Grimoire)
var artifacts: Array = []
var act := 1
var depth := 1
var turn := 0
var over := false
var won := false
var last_chant := ""
var defeated: Array = []  # enemy ids killed (for the codex)
var blind_masks := {}  # EnemyState -> Array[bool] hidden positions
var lines: Array = []
var script_draws: Array = []  # tutorial: fixed draws, one String per turn ("FFW"), used before any random ones
# this turn
var chant: Array = []  # element letters of the spoken chant; spells can change it
var spoken := false
var voice_echo := false  # Echoed Voice: the spell being cast is the turn's first, so each effect echoes
var echo_from := ""
var heard := ""  # what you chanted this turn ("" if you passed): the Invoker reads it  # an artifact repeating the effect being applied (its show starts from the artifact)
var used := {}  # spell id -> triggers used this turn
var current_eff := {}  # the effect being resolved right now (the screen's chooser looks at it)
var anti_broken := {}  # anti-spell id -> true: its pattern was chanted this turn, so it doesn't fire
var _conjured := 0  # for unique ids of Ephemeral (conjured) spells
## A Conjure spell turns into its conjured spells: conjuring[source id] = [their ids]. While any are out the source
## is gone from the row; when the last is cast or they expire, they merge back into it.
var conjuring := {}
var charges := {}  # spell id -> triggers left right now
var hm := {}  # the Handyman fight: {phase, kills, body}
var cast_counts := {}  # spell id -> casts this fight (the Hammer goes for the most-cast)
var hammer_target := ""
var hammer_hits := {}  # spell id -> Hammer hits taken (3 break it)
var broken := {}  # spell id -> true: smashed by the Hammer, gone for the fight
var stored := {}  # spell id -> true: alive but not cast when you Released; it wakes again on your next Chant
var turn_ctx := {}  # {entries, amplify, echo, retain, last, cast_any}

var chooser: Callable
var mover: Callable
var picker: Callable
var painter: Callable
var redirector: Callable
var placer: Callable
var chant_picker: Callable
var element_chooser: Callable
var attune_chooser: Callable
var arranger: Callable
var spell_chooser: Callable
var anim: Callable


func _init(p_db: SpellDB, p_player: PlayerState) -> void:
	db = p_db
	player = p_player
	chooser = func(_s, cands): return cands[0]
	mover = func(_s, _e): return []
	picker = func(_s, e): return e.armor.find(false)
	painter = func(_s):  # by default: the first Essence that isn't Any yet
		for e in alive():
			var i: int = e.elements.find_custom(func(x): return x != "?")
			if i >= 0:
				return [enemies.find(e), i]
		return []
	redirector = func(_s, src, _cands): return enemies.find(src)
	placer = func(_s, _el): return chant.size()
	chant_picker = func(_s): return 0
	attune_chooser = func(_s): return _favourite_element()
	element_chooser = func(_s, counts):  # by default: the element that removes the most
		var best := "F"
		for el in counts:
			if counts[el] > counts.get(best, 0):
				best = el
		return best
	arranger = func(_s): return []
	spell_chooser = func(spells): return 0 if not spells.is_empty() else -1
	anim = func(_e): pass


var artifact_plus: Array = []  # artifacts upgraded to their + version
var preset_extra: Array = []  # extra Essence already rolled for the starting enemies (shown before the fight)


func has_artifact(id: String) -> bool:
	return id in artifacts


## An artifact's number (its + number if upgraded).
func _an(id: String) -> float:
	return Artifacts.num(id, id in artifact_plus)


# ------------------------------------------------------------------ setup

func start(enemy_ids: Array, p_act: int, p_depth: int) -> void:
	act = p_act
	depth = p_depth
	player.reset_fight()
	enemies.clear()
	for i in enemy_ids.size():
		if enemy_ids[i] == "handyman":
			# the Handyman starts as two hands (he himself only shows up at the very end)
			hm = {"phase": 1, "kills": 0, "body": false}
			_spawn("hand_sword", [])
			_spawn("hand_tweezer", [])
			continue
		_spawn(enemy_ids[i], preset_extra[i] if i < preset_extra.size() else null)
	if has_artifact("thornbark"):
		player.passives["thorns"] = int(_an("thornbark"))
	if has_artifact("venom_gland"):
		player.passives["poison_bonus"] = int(_an("venom_gland"))
	if has_artifact("chant_bell"):
		player.passives["echo_first"] = 1
	if has_artifact("rain_chalice"):
		player.lasting += _an("rain_chalice")
	if has_artifact("iron_bark"):
		player.lasting += _an("iron_bark")
	if has_artifact("ward_stone"):
		player.aegis = int(_an("ward_stone"))
	player.dmg_taken_mult = 1.25 if has_artifact("glass_heart") else 1.0
	var start_n := PlayerState.START_ELEMENTS + (int(_an("wind_chime")) if has_artifact("wind_chime") else 0)
	# you always start with one of each element; the rest are random (in a random order)
	var hand := ["F", "W", "A"]
	while hand.size() < start_n:
		hand.append(_draw_element())
	for i in hand.size():
		var j := rng.randi_range(i, hand.size() - 1)
		var tmp: String = hand[i]
		hand[i] = hand[j]
		hand[j] = tmp
	for el in hand:
		player.add_element(el)
	if has_artifact("ember_charm"):
		for i in int(_an("ember_charm")):
			player.add_element("F")
	_roll_next_draw(2)
	turn = 1
	for e in enemies:
		_plan(e)
	_log("The fight begins.")


func _spawn(id: String, extra = null) -> EnemyState:
	var d := EnemyDefs.get_def(id)
	var e := EnemyState.new()
	e.setup(d, extra if extra is Array else EnemyDefs.extra_for(id, act, depth, rng))
	e.dmg_bonus = EnemyDefs.attack_bonus(act)
	if d.has("walls"):
		for side in ["L", "R"]:
			e.grow_wall(side, _wall_essence(int(d.walls)))
	e.move_index = int(d.get("start", 0))
	e.opener = d.get("opener", []).duplicate(true)  # (the Triplet: each starts its cycle at a different move)
	enemies.append(e)
	return e


## The Bramble Matron's walls: each one still standing attacks with its own next move (left, then right).
func _wall_turns(e: EnemyState) -> void:
	for side in ["L", "R"]:
		if over or e.is_dead() or not (side in e.parts):
			continue
		var m := wall_move(e, side)
		e.wall_step[side] += 1
		_log("%s's %s wall attacks." % [e.name, "left" if side == "L" else "right"])
		e.acting_part = side  # (the wall lunges, not her)
		await _do_move(e, m)
		e.acting_part = ""


## A wall's next move (its intent).
func wall_move(e: EnemyState, side: String) -> Dictionary:
	var moves: Array = e.def.get("wall_moves", [])
	return moves[int(e.wall_step[side]) % moves.size()] if not moves.is_empty() else {}


## A fresh hedge wall: n random Essence.
func _wall_essence(n: int) -> Array:
	var out := []
	for k in n:
		out.append(_random_element())
	return out


func alive() -> Array:
	return enemies.filter(func(e): return not e.is_dead())


func active_spells() -> Array:
	return shown_spells().filter(func(s): return not player.used_powers.has(s.id))


## The active row as you see it: a Conjure spell whose conjured spells are out isn't in it (they stand in its place).
func shown_spells() -> Array:
	return loadout.filter(func(s): return not conjuring.has(s.id) and not broken.has(s.id))


## Spells that can fire this turn (not silenced, not locked, not a spent Power).
func usable_spells() -> Array:
	return active_spells().filter(func(s): return not player.silenced.has(s.id) and not player.locks.has(s.id) and not player.cooldowns.has(s.id))


## The most times a spell can trigger in one turn: once.
func trigger_cap(_spell: Dictionary) -> int:
	return 1


## Where a spell's pattern appears in the chant. A fully sealed spell (empty pattern) is woken by any chant.
func _occ(sp: Dictionary, c: String) -> Array:
	if sp.has("patterns"):  # a fused anti-spell: any one of its patterns counts
		for p in sp.patterns:
			if not Chant.occurrences(p, c).is_empty():
				return [0]
		return []
	if String(sp.pattern) == "":
		return [0] if c != "" else []
	return Chant.occurrences(sp.pattern, c)


func chant_string() -> String:
	return "".join(chant)


func _log(s: String) -> void:
	lines.append(s)


# ------------------------------------------------------------------ draws

## One random element, each equally likely (enemies, and anything that isn't a draw of yours).
func _random_element() -> String:
	return ["F", "W", "A"][rng.randi() % 3]


## Your draws are pseudo-random: every draw an element misses adds DROUGHT_BOOST to its weight (from 1), and it
## drops back to 1 once it comes up. Over a fight the three even out, and long droughts of one element don't happen.
const DROUGHT_BOOST := 0.6
var drought := {"F": 0, "W": 0, "A": 0}  # draws in a row each element has missed (this fight)


func _draw_element() -> String:
	var total := 0.0
	for el in drought:
		total += 1.0 + DROUGHT_BOOST * drought[el]
	var r := rng.randf() * total
	var pick := "A"
	for el in drought:
		r -= 1.0 + DROUGHT_BOOST * drought[el]
		if r < 0.0:
			pick = el
			break
	for el in drought:
		drought[el] = 0 if el == pick else drought[el] + 1
	return pick


## Lenses: every chanted element of a lens's colour has a 25% chance to come back after the Release.
func _lens_refunds(chanted: Array) -> Array:
	var back := []
	for lens in LENSES:
		if not has_artifact(lens):
			continue
		for el in chanted:
			if el == LENSES[lens] and rng.randf() < _an(lens):
				back.append(el)
	return back


## Rolls the draw you receive at the start of turn `upcoming` (shown in "Coming next").
func _roll_next_draw(upcoming: int) -> void:
	player.next_draw.clear()
	if not script_draws.is_empty():
		for ch in String(script_draws.pop_front()):
			player.next_draw.append({"el": ch, "temp": false})
		return
	var n := PlayerState.BASE_DRAW - player.overload + player.passive("draw_bonus")
	if has_artifact("second_wind") and player.hp < player.max_hp / 2.0:
		n += int(_an("second_wind"))
	if has_artifact("heartwood_seed"):
		n += 1
	if has_artifact("blood_pact"):
		n += 1
	if has_artifact("withered_idol"):
		n += 2
	if has_artifact("lucky_acorn") and rng.randf() < _an("lucky_acorn"):
		n += 1
	player.overload = 0
	for i in maxi(0, n):
		player.next_draw.append({"el": _draw_element(), "temp": false})
	for i in player.passive("attune"):  # Attunement: 1 more of the Essence you picked, every turn
		player.next_draw.append({"el": player.passives.get("attune_el", "F"), "temp": false})
	for h in HEARTS:
		if has_artifact(h):
			player.next_draw.append({"el": HEARTS[h], "temp": false})
	if upcoming == 3:
		for em in EMBLEMS:
			if has_artifact(em):
				for i in int(_an(em)):
					player.next_draw.append({"el": EMBLEMS[em], "temp": false})


## Start of your turn (not the first): bleed, receive the previewed draw, Powers tick.
func begin_player_turn() -> void:
	if player.bleed > 0:
		player.take_effect(player.bleed)
		_log("You bleed for %d." % player.bleed)
		player.bleed -= 1
		await anim.call({"type": "bleed_tick"})
	if has_artifact("mending_moss"):
		player.heal(_an("mending_moss"))
	player.thorns_turn = 0
	_hands_back()
	player.shield = 0.0  # Shield lasts until your next turn starts (it doesn't build up from turn to turn)
	for d in player.next_draw:
		player.add_element(d.el, d.temp)
	_roll_next_draw(turn + 1)
	for pw in player.each_turn:
		for eff in pw.effects:
			await _apply(eff, pw.spell, {}, {})
	_check_end()


# ------------------------------------------------------------------ preview

## What the Release would do with this chant: {removed: {enemy: matched}, dies: [enemy], spells: {id: n}}.
## raw: the chant as built from your stock (Confuse reverses it); pass raw = false for an already spoken chant.
func preview(c: String, raw := true) -> Dictionary:
	if raw and player.confuse_turns > 0:
		c = c.reverse()
	var removed := {}
	var dies := []
	var extra: int = (1 if has_artifact("glass_heart") else 0) + turn_ctx.get("amplify", 0)
	for e in alive():
		if e.ethereal or (e.has_passive("warded") and c.length() < 4):
			continue
		var k := Chant.prefix_match(e.elements, c)
		if k == 0:
			continue
		var armored := 0
		for i in k:
			if e.armor[i]:
				armored += 1
		var n: int = k - armored + extra
		removed[e] = k
		if e.has_passive("briar_walls"):
			var own := 0
			for i in k:
				if e.parts[i] == "" and not e.armor[i]:
					own += 1
			if own >= e.parts.count(""):
				dies.append(e)
		elif n >= e.size() or (e.poison > 0 and e.size() - n <= e.poison):
			dies.append(e)
	var spells := {}
	for s in usable_spells():
		var cnt: int = mini(_occ(s, c).size(), trigger_cap(s)) - (used.get(s.id, 0) if not raw else 0)
		if cnt > 0:
			spells[s.id] = cnt
	var invoke := {}  # the Invoker's spells this chant would set off
	for e in alive():
		if e.def.get("invokes", false):
			invoke[e] = invoke_picks(e, c)
	return {"removed": removed, "dies": dies, "spells": spells, "invoke": invoke}


# ------------------------------------------------------------------ your turn

## Speak the chant made of these stock entries (in this order). Nothing is struck yet: matched spells gain charges.
func cast_chant(stock_indices: Array) -> void:
	if over or stock_indices.is_empty():
		return
	var entries := []
	for i in stock_indices:
		entries.append(player.stock[i])
	var sorted_idx := stock_indices.duplicate()
	sorted_idx.sort()
	sorted_idx.reverse()
	for i in sorted_idx:
		player.stock.remove_at(i)
	var c := ""
	for e in entries:
		c += e.el
		if e.hexed:
			player.take_effect(2.0)
			_log("The hex burns you for 2.")
	if player.confuse_turns > 0:
		c = c.reverse()
		_log("Confused: your chant is read backwards (%s)." % c)
	chant.clear()
	for ch in c:
		chant.append(ch)
	spoken = true
	used.clear()
	charges.clear()
	player.echo_chamber_on = has_artifact("echo_chamber") and chant.size() <= int(_an("echo_chamber"))
	if player.echo_chamber_on:
		_log("Echo Chamber: a short chant. Every spell this turn is cast twice.")
	anti_broken.clear()
	turn_ctx = {"entries": entries, "amplify": 0, "echo": 0, "retain": 0, "last": {}, "cast_any": false}
	await anim.call({"type": "chant", "chant": c})
	var woke: Array = await _recount()
	# always: the chant is read out note by note, even when it wakes no spell
	await anim.call({"type": "charged", "hits": woke})


## Re-read the chant: locks it now contains break, and every spell's charges are counted again.
## Returns the spells that gained charges, each with the chant positions that woke them:
## [{id, starts: [chant index of each new match], len}].
func _recount() -> Array:
	var c := chant_string()
	for sid in player.locks.keys():
		if Chant.breaks_lock(player.locks[sid], c):
			player.locks.erase(sid)
			_log("A lock shatters!")
			await anim.call({"type": "unlock", "spell": sid})
	var before := charges.duplicate()
	charges.clear()
	var woke := []
	for sp in usable_spells():
		if sp.get("anti", false):
			# an anti-spell comes alive with every chant, unless the chant contains its pattern (then it's broken for
			# the turn, and loses a charge it hadn't used yet)
			if not _occ(sp, c).is_empty():
				anti_broken[sp.id] = true
			elif c != "" and used.get(sp.id, 0) == 0:
				charges[sp.id] = 1
				if not before.has(sp.id):
					woke.append({"id": sp.id, "starts": [], "len": 0})
			continue
		var occ: Array = _occ(sp, c).slice(0, trigger_cap(sp))
		# once a spell is alive it stays alive: changing the chant afterwards (Infuse, Rearrange, Duplicate…) can
		# wake more spells, never put one back to sleep
		var n: int = maxi(occ.size() - used.get(sp.id, 0), before.get(sp.id, 0))
		if n > 0:
			charges[sp.id] = n
			var gained: int = n - before.get(sp.id, 0)
			if gained > 0:
				woke.append({"id": sp.id, "starts": occ.slice(occ.size() - gained), "len": sp.pattern.length()})
	# spells stored from an earlier turn wake on any chant (one charge: a match on top doesn't add a second)
	for sp in usable_spells():
		if stored.has(sp.id) and charges.get(sp.id, 0) == 0 and used.get(sp.id, 0) == 0:
			charges[sp.id] = 1
			if not before.has(sp.id):
				woke.append({"id": sp.id, "starts": [], "len": 0})
	return woke


## Released with spells still alive: they're stored, awake, until a later Chant (see `stored`).
func _store_unused() -> void:
	var kept := []
	for id in charges:
		if charges[id] > 0 and not stored.has(id):
			stored[id] = true
			kept.append(_find_spell(id).get("name", id))
	if not kept.is_empty():
		_log("Stored for your next chant: %s." % ", ".join(kept))


## Anything left to do this turn? (When not, the chant is Released by itself.)
func has_valid_move() -> bool:
	return not charges.is_empty() and not over


## Enemy indices a targeted spell can aim at.
func target_candidates() -> Array:
	var out := []
	for i in enemies.size():
		if not enemies[i].is_dead():
			out.append(i)
	return out


func _find_spell(id: String) -> Dictionary:
	for s in loadout:
		if s.id == id:
			return s
	return db.get_spell(id)


## Cast one charge of a living spell. target_idx: the enemy for "target" effects (-1: ask the chooser).
func resolve_spell(id: String, target_idx := -1) -> void:
	if over or charges.get(id, 0) <= 0:
		return
	var spell := _find_spell(id)
	used[id] = used.get(id, 0) + 1
	cast_counts[id] = cast_counts.get(id, 0) + 1
	stored.erase(id)  # (a stored spell is used up when it's cast)
	_start_cooldown(spell)
	charges[id] -= 1  # (the recount after the cast keeps the charges that are left)
	if charges[id] <= 0:
		charges.erase(id)
	var times := 1
	voice_echo = not turn_ctx.get("cast_any", false) and player.passive("echo_first") > 0 and not spell.power
	if voice_echo:
		_log("Echoed Voice: %s echoes." % spell.name)
	turn_ctx.cast_any = true
	_charge_react(spell)
	if player.ignited.has(id):
		# Ignited (the Ember Sprite): casting it burns you
		player.take_effect(IGNITE_DAMAGE)
		_log("%s is on fire: it burns you for %d." % [spell.name, IGNITE_DAMAGE])
		await anim.call({"type": "ignite_burn", "id": id})
		_cleanup()
		if over:
			return
	if player.echo_next:
		player.echo_next = false
		times += 1
		_log("Echo Draught: %s is cast twice." % spell.name)
	if has_artifact("echo_shell"):
		if player.echo_charged:
			player.echo_charged = false
			times += 1
			_log("Echo Shell: %s is cast twice." % spell.name)
			await anim.call({"type": "artifact_used", "id": "echo_shell"})
		else:
			player.echo_casts += 1
			if player.echo_casts >= int(_an("echo_shell")):
				player.echo_casts = 0
				player.echo_charged = true
				_log("Echo Shell is charged: your next spell is cast twice.")
	for t in times:
		if over:
			break
		var tctx := {}
		if target_idx >= 0 and target_idx < enemies.size() and not enemies[target_idx].is_dead():
			tctx.target = enemies[target_idx]
		await _fire(spell, turn_ctx, tctx)
	await _kindle()
	voice_echo = false
	# the chant may have changed (Infuse, Rearrange, Duplicate): spells it wakes now are an Extension
	var woke: Array = await _recount()
	if not woke.is_empty():
		await anim.call({"type": "extension", "hits": woke})


## Kindling Stone: every 3rd spell you cast (every 2nd for the + version) puts 1 Burn on a random enemy.
## (It counts across fights, like the Echo Shell.)
func _kindle() -> void:
	if not has_artifact("kindling_stone") or over:
		return
	player.kindling_chants += 1
	if player.kindling_chants < int(_an("kindling_stone")):
		return
	player.kindling_chants = 0
	var pool := alive()
	if pool.is_empty():
		return
	var e: EnemyState = pool[rng.randi() % pool.size()]
	e.ignite(1, rng)
	_log("Kindling Stone sets %s alight: Burn 1." % e.name)
	await anim.call({"type": "artifact_used", "id": "kindling_stone"})
	await anim.call({"type": "effect", "op": "burn", "eff": {"op": "burn", "n": 1}, "targets": [e]})


## Cast every charge automatically, earliest match first (the sim and tests; the player casts by hand).
func resolve_all() -> void:
	var guard := 0
	while has_valid_move() and guard < 60:
		guard += 1
		var c := chant_string()
		var best := ""
		var best_pos := 999
		for id in charges:
			var sp := _find_spell(id)
			var occ := _occ(sp, c)
			var pos: int = occ[0] if not occ.is_empty() else -1
			if pos >= 0 and pos < best_pos:
				best_pos = pos
				best = id
		if best == "":
			best = charges.keys()[0]
		await resolve_spell(best)


## The Release: the chant hits the enemies, then the turn ends and they act.
func finish_turn() -> void:
	if over:
		return
	heard = chant_string() if spoken else ""
	if spoken and not chant.is_empty():
		var c := chant_string()
		last_chant = c
		_store_unused()
		charges.clear()
		var hit := []
		if player.disarmed_turns > 0:
			_log("You are Disarmed: your Release does nothing.")
		else:
			hit = await _strike(c)
		var amp: int = turn_ctx.get("amplify", 0)
		if amp > 0:
			for e in hit:
				if not e.is_dead():
					e.remove_right(amp)
			await anim.call({"type": "amplify"})
		for i in turn_ctx.get("echo", 0):
			if over or player.disarmed_turns > 0:
				break
			_log("Echo! The chant is Released again.")
			await _strike(chant_string())
		var keep: int = turn_ctx.get("retain", 0)
		for el in chant.slice(maxi(0, chant.size() - keep)):
			player.add_element(el)
		var back := _lens_refunds(chant)
		for k in player.passive("refund_air"):
			back.append("A")  # Storm Crown: Air comes back after every Release
		for el in back:
			player.add_element(el)
		if not back.is_empty():
			_log("Refunded to your bag: %s." % " ".join(back))
		_cleanup()
	if not spoken:
		if has_artifact("shield_of_silence"):
			var got := player.gain_shield(_an("shield_of_silence"), true)
			_log("Shield of Silence: you held your tongue (+%d Lasting Shield)." % got)
			_shield_gained(got)
			await anim.call({"type": "artifact_used", "id": "shield_of_silence"})
		await _fire_anti_spells()  # no chant at all this turn: nothing broke them, and they still go off
	if not over:
		await end_player_turn()


## A turn passed without chanting: every anti-spell takes effect at its end (with a chant they come alive instead).
func _fire_anti_spells() -> void:
	for sp in usable_spells():
		if over:
			return
		if sp.get("anti", false) and not anti_broken.has(sp.id):
			_log("%s takes effect: you didn't chant it." % sp.name)
			_start_cooldown(sp)
			_charge_react(sp)
			await _fire(sp, {}, {})


## The whole turn at once: chant, every charge in chant order, the Release, the enemies.
func cast(stock_indices: Array) -> void:
	if over:
		return
	await cast_chant(stock_indices)
	await resolve_all()
	await finish_turn()


## End the turn without chanting (keep your elements).
func pass_turn() -> void:
	spoken = false
	chant.clear()
	await finish_turn()


## The Release, element by element from left to right: at each chant position, every enemy whose matched
## start lines up with it loses that element (armoured ones stay). Returns the enemies hit.
func _strike(c: String) -> Array:
	var plans := []
	for e in alive():
		if e.ethereal:
			continue
		if e.has_passive("warded") and c.length() < 4:
			continue
		var k := Chant.prefix_match(e.elements, c)
		if k == 0:
			continue
		var at := Chant.find_hp(e.elements.slice(0, k), c)
		plans.append({"enemy": e, "k": k, "at": at})
	if plans.is_empty():
		return []
	var last_hit := 0
	for pl in plans:
		last_hit = maxi(last_hit, pl.at + pl.k - 1)
	for p in c.length():
		var hits := []
		for pl in plans:
			if p >= pl.at and p < pl.at + pl.k:
				hits.append([pl.enemy, p - pl.at])
		# after the last element that hits anything, the rest of the chant has nothing left to fly at
		await anim.call({"type": "chant_step", "pos": p, "hits": hits, "chant": c, "leftover": p > last_hit})
	var hit := []
	var extra := 1 if has_artifact("glass_heart") else 0
	for pl in plans:
		var e: EnemyState = pl.enemy
		var before: int = e.size()
		var removed: Array = e.strike_prefix(pl.k)
		if extra > 0 and not e.is_dead():
			removed.append_array(e.remove_right(extra))
		e.struck_this_turn = true
		hit.append(e)
		if player.passive("strike_poison") > 0:
			e.poison += player.passive("strike_poison") + player.passive("poison_bonus")
		if player.passive("strike_burn") > 0:
			e.ignite(_burn_amount(player.passive("strike_burn") + player.passive("burn_bonus")), rng)
		if e.has_passive("burning_hide"):
			player.take_effect(1.0)
			_log("%s's burning hide scorches you." % e.name)
		if e.has_passive("thorns"):
			player.take_effect(2.0)
			_log("%s's thorns prick you." % e.name)
		_log("Your Release hits %s for %d." % [e.name, removed.size()])
		await anim.call({"type": "strike", "enemy": e, "n": removed.size()})
		if e.has_passive("split") and not e.is_dead() and not e.def.get("split_done", false) and e.size() >= 2 and before > e.size():
			_split(e)
	_cleanup()
	return hit


func _split(e: EnemyState) -> void:
	if enemies.size() >= MAX_ENEMIES:
		return
	var half := e.size() / 2
	var twin := EnemyState.new()
	var d := e.def.duplicate(true)
	d.split_done = true
	d.hp = "".join(e.elements.slice(half))
	twin.setup(d)
	twin.dmg_bonus = e.dmg_bonus
	e.elements = e.elements.slice(0, half)
	e.armor = e.armor.slice(0, half)
	e.lit = e.lit.slice(0, half)
	e.def.split_done = true
	enemies.insert(enemies.find(e) + 1, twin)
	twin.fresh = true
	_plan(twin)
	_log("%s splits in two!" % e.name)
	anim.call({"type": "spawn", "enemy": twin})


func _fire(spell: Dictionary, ctx: Dictionary, tctx: Dictionary) -> void:
	tctx["_alive_before"] = alive()  # for "if this defeats an enemy" effects
	await anim.call({"type": "spell", "spell": spell})
	for eff in spell.effects:
		if eff.op == "copy_last":
			var prev: Dictionary = ctx.get("last", {})
			if not prev.is_empty():
				_log("Mimic repeats %s." % prev.name)
				for e2 in prev.effects:
					await _apply(e2, prev, tctx, ctx)
			continue
		await _apply(eff, spell, tctx, ctx)
		if player.echo_chamber_on and not over and not spell.has("bottle"):
			await anim.call({"type": "echo_chamber"})  # (it shines, a short beat)
			echo_from = "echo_chamber"
			await _apply(eff, spell, tctx, ctx)
			echo_from = ""
		if voice_echo and not over:
			# Echoed Voice: the same effect again, from its badge under your HP
			await anim.call({"type": "echo_voice"})
			echo_from = "power:echo_chamber"
			await _apply(eff, spell, tctx, ctx)
			echo_from = ""
	if spell.get("ephemeral", false):
		# a conjured spell vanishes once cast; the last one of its group merges back into the spell that conjured it
		loadout = loadout.filter(func(s): return s.id != spell.id)
		var src: String = spell.get("conjured_by", "")
		var group: Array = conjuring.get(src, [])
		group.erase(spell.id)
		if conjuring.has(src) and group.is_empty():
			conjuring.erase(src)
			_log("%s fizzles back into %s." % [spell.name, _find_spell(src).get("name", "its spell")])
			await anim.call({"type": "conjure_merge", "source": src, "ids": [spell.id]})
		else:
			_log("%s fizzles away." % spell.name)
			await anim.call({"type": "ephemeral_gone", "ids": [spell.id]})
	elif spell.power:
		player.used_powers[spell.id] = true
		_log("%s takes hold for the rest of the fight." % spell.name)
	elif spell.get("fleeting", false):
		player.used_powers[spell.id] = true  # Fleeting: gone for the rest of the fight
		_log("%s fades away for the rest of this fight." % spell.name)
	ctx.last = spell
	_cleanup()


## Resolves one effect. tctx caches the chosen target for this spell.
func _apply(eff: Dictionary, spell: Dictionary, tctx: Dictionary, ctx := {}) -> void:
	# "if this defeats it" effects (Absorb) do nothing at all, not even their animation, when nothing was defeated
	if eff.get("if_kill", false) and not tctx.get("_alive_before", []).any(func(x): return x.is_dead()):
		return
	current_eff = eff
	var targets := await _targets(eff, spell, tctx)
	# Gain Essence: rolled before the show, so each orb flies in its own element's colour to its own slot
	var drawn: Array[String] = []
	if eff.op == "draw":
		for i in eff.n:
			drawn.append(_draw_element() if eff.get("el", "random") == "random" else String(eff.el))
	await anim.call({"type": "spell_effect", "op": eff.op, "eff": eff, "targets": targets, "spell": spell, "from_artifact": echo_from, "drawn": drawn})
	match eff.op:
		"strike":
			for e in targets:
				if eff.has("min_hp") and e.size() < eff.min_hp:
					continue
				var n: int = eff.n + player.passive("strike_bonus")
				if eff.get("bonus_if", "") == "burn" and e.burn > 0:
					n += 1
				if e.phased:
					n *= 2
				if eff.get("target", "") == "all" and e.has_walls():
					# hitting every enemy: her walls and herself are each hit on their own
					for part in ["L", "", "R"]:
						e.remove_in_part(part, n, eff.from == "right")
				elif eff.from == "right":
					e.remove_right(n)
				else:
					e.remove_left(n)
		"burn":
			var amount := _burn_amount(eff.n + player.passive("burn_bonus")) if not targets.is_empty() else 0
			for e in targets:
				e.ignite(amount, rng)
		"poison":
			for e in targets:
				e.poison += eff.n + player.passive("poison_bonus")
		"stoke":
			for e in targets:
				e.ignite(e.burn, rng)
		"weak":
			for e in targets:
				e.weak_turns = maxi(e.weak_turns, eff.turns)
		"freeze":
			for e in targets:
				if not e.is_boss:
					e.freeze_turns = maxi(e.freeze_turns, eff.turns)
		"expose":
			# paint n Essence of your choice, on any enemies: each becomes an Any Essence ("?") for the rest of the fight
			for i in eff.n:
				if not alive().any(func(x): return x.elements.any(func(el): return el != "?")):
					break
				var got: Array = await painter.call(spell)
				if got.size() < 2 or got[0] < 0 or got[0] >= enemies.size():
					break
				var e: EnemyState = enemies[got[0]]
				if e.is_dead() or got[1] >= e.size() or e.elements[got[1]] == "?":
					continue
				var was: String = e.elements[got[1]]
				e.elements[got[1]] = "?"
				_log("%s paints %s's %s: it's an Any Essence now." % [spell.name, e.name, Elements.NAMES.get(was, "Essence")])
				await anim.call({"type": "paint", "enemy": e, "index": got[1], "was": was})
		"ethereal":
			if eff.target == "self":
				player.ethereal = true
			else:
				for e in targets:
					e.phased = true
		"shield":
			_shield_gained(player.gain_shield(eff.n))
		"heal":
			var ok := true
			if eff.get("if_kill", false):
				ok = tctx.get("_alive_before", []).any(func(x): return x.is_dead())
			if ok:
				player.heal(eff.n)
		"aegis":
			player.aegis += eff.n
		"thorns":
			player.thorns_turn += eff.n
		"draw":
			for el in drawn:
				if eff.when == "now":
					player.add_element(el, eff.get("temp", false))
				else:
					player.next_draw.append({"el": el, "temp": eff.get("temp", false)})
		"rotate":
			for e in targets:
				if eff.get("dir", "left") == "right":
					e.rotate_right()
				else:
					e.rotate_left()
		"swap":
			for e in targets:
				e.swap_first_two()
		"convert":
			for e in targets:
				e.convert(eff.pos, eff.to, eff.get("from", ""))
		"purge":
			for e in targets:
				e.purge(eff.el, eff.n * (2 if e.phased else 1))
		"shatter":
			for e in targets:
				e.shatter()
		"insert":
			for e in targets:
				e.insert_front(eff.el)
		"siphon":
			for e in targets:
				for el in e.remove_left(eff.n):
					player.next_draw.append({"el": el, "temp": true})
		"execute":
			for e in targets:
				if e.size() <= eff.max and not e.is_boss:
					e.elements.clear()
					e.armor.clear()
					e.lit.clear()
		"transmute":
			var changed := 0
			for s in player.stock:
				if changed < eff.n and s.el != eff.to and not s.frozen:
					s.el = eff.to
					changed += 1
		"sacrifice":
			player.take_effect(eff.hp)
		"vulnerable":
			player.vulnerable = maxi(player.vulnerable, int(eff.n))  # (a self debuff: the price of the spell)
			_log("You are Vulnerable %d: you take 50%% more damage." % eff.n)
		"barrage", "random_hit":
			# Arcane Barrage: each hit picks an enemy at random (from _targets). Bottles: n random Essence of each target.
			var hits := targets if eff.op == "barrage" else []
			if eff.op == "random_hit":
				for e in targets:
					if eff.get("target", "") == "all" and e.has_walls():
						# every enemy: her walls and herself each lose n random Essence of their own
						for part in ["L", "", "R"]:
							for k in eff.n:
								var picks := []
								for i in e.size():
									if e.parts[i] == part and not e.armor[i]:
										picks.append(i)
								if not picks.is_empty():
									e.pluck(picks[rng.randi() % picks.size()])
						continue
					for k in eff.n:
						hits.append(e)
			for e in hits:
				var k: int = e.random_pick(rng)  # (a wall's Essence while any wall stands)
				if k >= 0:
					e.pluck(k)
		"echo_next":
			player.echo_next = true
		"conjure":
			await _conjure(eff.n, spell)
		"grimoire_pick":
			var ids := loadout.map(func(s): return s.id)
			var pool := spellbook.filter(func(s): return not (s.id in ids))
			var k: int = await spell_chooser.call(pool)
			if k >= 0 and k < pool.size():
				loadout.append(pool[k])
				_log("%s joins your active spells for this fight." % pool[k].name)
				await anim.call({"type": "loadout_changed"})
				if spoken:
					var woke: Array = await _recount()
					if not woke.is_empty():
						await anim.call({"type": "extension", "hits": woke})
		"amplify":
			ctx.amplify = ctx.get("amplify", 0) + eff.n
		"echo":
			ctx.echo = ctx.get("echo", 0) + eff.n
		"retain":
			ctx.retain = ctx.get("retain", 0) + eff.n
		"overload":
			player.overload += eff.n
		"cleanse":
			_cleanse(eff.get("what", "all"))
		"infuse":
			# put n Essence into the chant, one at a time, each where you like ("random": a random element each)
			for k in int(eff.get("n", 1)):
				if not spoken or over:
					break
				var el: String = _random_element() if eff.el == "random" else eff.el
				var pos: int = await placer.call(spell, el)
				chant.insert(clampi(pos, 0, chant.size()), el)
				_log("%s adds %s to the chant." % [spell.name, Elements.NAMES[el]])
				await anim.call({"type": "chant_changed"})
		"rearrange":
			if spoken and chant.size() > 1:
				for k in eff.n:
					var mv: Array = await arranger.call(spell)
					if mv.size() < 2:
						break
					var from := clampi(int(mv[0]), 0, chant.size() - 1)
					var el: String = chant[from]
					chant.remove_at(from)
					var to := clampi(int(mv[1]), 0, chant.size())
					chant.insert(to, el)
					if to != from:
						_log("%s moves a %s in the chant." % [spell.name, Elements.NAMES[el]])
					await anim.call({"type": "chant_changed"})
		"duplicate":
			if spoken and not chant.is_empty():
				var i: int = clampi(await chant_picker.call(spell), 0, chant.size() - 1)
				for k in eff.times - 1:
					chant.insert(i, chant[i])
				_log("%s: %s ×%d in the chant." % [spell.name, Elements.NAMES[chant[i]], eff.times])
				await anim.call({"type": "chant_changed"})
		"summon_spells":
			var ids := loadout.map(func(s): return s.id)
			var pool := spellbook.filter(func(s): return not (s.id in ids))
			pool.shuffle()
			for s in pool.slice(0, eff.n):
				loadout.append(s)
				_log("%s joins your active spells." % s.name)
			await anim.call({"type": "loadout_changed"})
		"move":
			for e in targets:
				for i in eff.n:
					if e.is_dead() or e.size() < 2:
						break
					var mv: Array = await mover.call(spell, e)
					if mv.size() == 2:
						e.move_element(mv[0], mv[1])
						await anim.call({"type": "effect", "op": "move", "targets": [e]})
		"steal":
			# take elements out of the enemy's HP and into your elements (not into this chant)
			for e in targets:
				var taken := []
				if eff.get("el", "any") == "any":
					for i in eff.n:
						if e.is_dead() or not e.armor.has(false):
							break
						var idx: int = await picker.call(spell, e)
						var el: String = e.pluck(idx)
						if el != "":
							taken.append(el)
				else:
					taken = e.purge(eff.el, eff.n)
				for el in taken:
					player.add_element(el if el != "?" else _random_element())  # a stolen Any Essence settles on one element
				if not taken.is_empty():
					_log("%s steals %s from %s." % [spell.name, ", ".join(taken.map(func(x): return Elements.NAMES[x])), e.name])
				await anim.call({"type": "stolen", "enemy": e, "els": taken})
		"pluck":
			for e in targets:
				for i in eff.n:
					if e.is_dead() or not e.armor.has(false):
						break
					var idx: int = await picker.call(spell, e)
					var el: String = e.pluck(idx)
					if el != "":
						_log("%s plucks %s from %s." % [spell.name, Elements.NAMES[el], e.name])
						await anim.call({"type": "strike", "enemy": e, "n": 1})
		"redirect":
			for e in targets:
				var cands := target_candidates()
				var to: int = await redirector.call(spell, e, cands)
				if to >= 0 and to < enemies.size():
					e.redirect_to = enemies[to]
					_log("%s's intent now points at %s." % [e.name, "itself" if enemies[to] == e else enemies[to].name])
		"passive":
			if eff.key == "attune":
				player.passives["attune_el"] = await attune_chooser.call(spell)
				_log("%s: you gain 1 %s each turn." % [spell.name, Elements.NAMES[player.passives.attune_el]])
				for k in eff.n:  # (next turn's draw is already rolled: it joins it right away)
					player.next_draw.append({"el": player.passives.attune_el, "temp": false})
			player.passives[eff.key] = player.passive(eff.key) + eff.n
			if eff.key == "draw_bonus":
				# next turn's draw is already rolled: the extra Essence joins it right away
				for k in eff.n:
					player.next_draw.append({"el": _draw_element(), "temp": false})
		"curse":
			for e in targets:
				match eff.key:
					"no_mend":
						e.no_mend = true
					"weak25":
						e.weak25 = true
		"each_turn":
			player.each_turn.append({"spell": spell, "effects": eff.effects})
		"annihilate":
			# choose Fire, Water or Air; every Essence of it is wiped from all enemies
			var counts := {"F": 0, "W": 0, "A": 0}
			for e in targets:
				for x in e.elements:
					if counts.has(x):
						counts[x] += 1
			var el: String = await element_chooser.call(spell, counts)
			await anim.call({"type": "annihilate", "el": el, "targets": targets})
			var gone := 0
			for e in targets:
				gone += e.remove_all(el).size()
			_log("%s annihilates every %s: %d Essence gone." % [spell.name, Elements.NAMES[el], gone])
	await anim.call({"type": "effect", "op": eff.op, "eff": eff, "targets": targets})


## Burn you apply.
func _burn_amount(n: int) -> int:
	return n


func _targets(eff: Dictionary, spell: Dictionary, tctx: Dictionary) -> Array:
	var t: String = eff.get("target", "")
	var live := alive()
	if live.is_empty():
		return []
	match t:
		"target":
			if not tctx.has("target") or tctx.target.is_dead():
				var cands := target_candidates()
				var idx: int = await chooser.call(spell, cands)
				tctx.target = enemies[idx]
			return [tctx.target]
		"two":
			# two different enemies: the first as usual, then a second one (if there is another)
			if not tctx.has("target") or tctx.target.is_dead():
				var idx: int = await chooser.call(spell, target_candidates())
				tctx.target = enemies[idx]
			if not tctx.has("second") or tctx.second.is_dead() or tctx.second == tctx.target:
				var rest := target_candidates().filter(func(i): return enemies[i] != tctx.target)
				if rest.is_empty():
					return [tctx.target]
				var idx2: int = await chooser.call(spell, rest)
				tctx.second = enemies[idx2]
			return [tctx.target, tctx.second]
		"all":
			return live
		"random":
			return [live[rng.randi() % live.size()]]
	if eff.op == "barrage":
		# Arcane Barrage: n hits, each on a random enemy that still has Essence it can lose (the same one can be hit again)
		var out := []
		var left := {}
		for e in live:
			left[e] = e.armor.count(false)
		for k in eff.n:
			var cands := live.filter(func(e): return left[e] > 0)
			if cands.is_empty():
				break
			var e: EnemyState = cands[rng.randi() % cands.size()]
			left[e] -= 1
			out.append(e)
		return out
	return []


func _cleanse(what: String) -> void:
	if what in ["all", "blind"]:
		player.blind_turns = 0
	if what in ["all", "bleed"]:
		player.bleed = 0
	if what in ["all", "confuse"]:
		player.confuse_turns = 0
	if what in ["all", "silence"]:
		player.silenced.clear()
	if what == "all":
		player.frail_turns = 0
		player.brittle_turns = 0
		player.vulnerable = 0
	if what in ["all", "frozen"]:
		for s in player.stock:
			s.frozen = false
			s.hexed = false
	if what == "lock" and not player.locks.is_empty():
		player.locks.erase(player.locks.keys()[0])


func _favourite_element() -> String:
	var c := {"F": 0, "W": 0, "A": 0}
	for s in loadout:
		for ch in s.pattern:
			if c.has(ch):
				c[ch] += 1
	var best := "F"
	for el in c:
		if c[el] > c[best]:
			best = el
	return best


## Conjure N: the conjuring spell splits into N random spells (not Powers, anti-spells or other Conjure spells, not
## ones already in your row), right where it was. They're Ephemeral: each vanishes once cast, and any left expire at
## the end of your next turn. When they're all gone, the conjuring spell comes back. (They're checked against this
## turn's chant at once, so some may wake straight away: see resolve_spell's re-count.)
func _conjure(n: int, source: Dictionary) -> void:
	if source.get("ephemeral", false) or conjuring.has(source.id):
		return
	var have := loadout.map(func(s): return String(s.get("base_id", s.id)))
	var pool: Array = db.all_spells.filter(func(s): return not s.power and not s.get("anti", false) and not (s.id in have) and not s.get("starter", false) \
		and not s.effects.any(func(e): return e.op == "conjure"))
	var made := []
	var at := loadout.find(source) + 1
	for i in n:
		if pool.is_empty():
			break
		var pick: Dictionary = pool[rng.randi() % pool.size()]
		pool.erase(pick)
		var s := pick.duplicate(true)
		_conjured += 1
		s.base_id = pick.id
		s.id = "%s~conjured%d" % [pick.id, _conjured]
		s.ephemeral = true
		s.conjured_by = source.id
		s.expires_turn = turn + 1
		loadout.insert(clampi(at + i, 0, loadout.size()), s)
		made.append(s)
	if made.is_empty():
		return
	conjuring[source.id] = made.map(func(s): return s.id)
	_log("%s splits into %s." % [source.name, ", ".join(made.map(func(s): return s.name))])
	await anim.call({"type": "conjure_split", "source": source.id, "ids": conjuring[source.id].duplicate()})


# ------------------------------------------------------------------ undo

## Everything a spell can change, so it can be undone before the Release: this fight's own state, every enemy's,
## yours, and the random generator (redoing a spell rolls the same).
func snapshot() -> Dictionary:
	return {
		"fight": _vars_of(self, ["db", "player", "enemies"]),
		"enemies": enemies.duplicate(),
		"enemy_states": enemies.map(func(e): return _vars_of(e, [])),
		"player": _vars_of(player, []),
		"rng": rng.state,
	}


func restore(snap: Dictionary) -> void:
	_set_vars(self, snap.fight)
	enemies = snap.enemies.duplicate()
	for i in enemies.size():
		_set_vars(enemies[i], snap.enemy_states[i])
	_set_vars(player, snap.player)
	rng.state = snap.rng


## An object's script variables, deep-copied (callables and the objects named in `skip` are left out).
static func _vars_of(o: Object, skip: Array) -> Dictionary:
	var out := {}
	for p in o.get_property_list():
		if not (p.usage & PROPERTY_USAGE_SCRIPT_VARIABLE) or p.name in skip:
			continue
		var v = o.get(p.name)
		if v is Callable or v is RandomNumberGenerator:
			continue
		out[p.name] = v.duplicate(true) if (v is Array or v is Dictionary) else v
	return out


static func _set_vars(o: Object, vars: Dictionary) -> void:
	for k in vars:
		var v = vars[k]
		o.set(k, v.duplicate(true) if (v is Array or v is Dictionary) else v)


# ------------------------------------------------------------------ bottles

## Drink the bottle in slot i (target_idx: the enemy, for bottles that need one). It's gone afterwards.
func use_bottle(i: int, target_idx := -1) -> void:
	if over or i < 0 or i >= player.bottles.size():
		return
	var b := Bottles.as_spell(player.bottles[i])
	player.bottles.remove_at(i)
	_log("You drink the %s." % b.name)
	var tctx := {"_alive_before": alive()}
	if target_idx >= 0 and target_idx < enemies.size() and not enemies[target_idx].is_dead():
		tctx.target = enemies[target_idx]
	await anim.call({"type": "bottle", "bottle": b})
	var ctx: Dictionary = turn_ctx if spoken else {}
	for eff in b.effects:
		if over:
			break
		await _apply(eff, b, tctx, ctx)
	_cleanup()


# ------------------------------------------------------------------ enemy phase

func end_player_turn() -> void:
	player.echo_chamber_on = false
	charges.clear()
	used.clear()
	anti_broken.clear()
	# conjured (Ephemeral) spells last until the end of the turn after they appear: those still here then expire, and
	# merge back into the spell that conjured them
	var expired := loadout.filter(func(s): return s.get("ephemeral", false) and int(s.get("expires_turn", 0)) <= turn)
	if not expired.is_empty():
		loadout = loadout.filter(func(s): return not (s in expired))
		var by_src := {}
		for s in expired:
			by_src[s.conjured_by] = by_src.get(s.conjured_by, []) + [s.id]
		for src in by_src:
			conjuring.erase(src)
			_log("The conjured spells merge back into %s." % _find_spell(src).get("name", "its spell"))
			await anim.call({"type": "conjure_merge", "source": src, "ids": by_src[src]})
	turn_ctx = {}
	chant.clear()
	spoken = false
	# conjured elements that weren't used fade (unless you hold the Prism Shard); frozen marks wear off
	if not has_artifact("prism_shard"):
		player.stock = player.stock.filter(func(s): return not s.temp)
	for s in player.stock:
		s.frozen = false
	player.confuse_turns = maxi(0, player.confuse_turns - 1)
	player.blind_turns = maxi(0, player.blind_turns - 1)
	player.toll = 0
	for s in player.silenced.keys():
		player.silenced[s] -= 1
		if player.silenced[s] <= 0:
			player.silenced.erase(s)
	for s in player.cooldowns.keys():
		player.cooldowns[s] -= 1
		if player.cooldowns[s] <= 0:
			player.cooldowns.erase(s)
	player.disarmed_turns = maxi(0, player.disarmed_turns - 1)
	for s in player.ignited.keys():
		player.ignited[s] -= 1
		if player.ignited[s] <= 0:
			player.ignited.erase(s)
	if player.blind_turns == 0:
		blind_masks.clear()
	await _enemy_phase()
	player.ethereal = false
	player.frail_turns = maxi(0, player.frail_turns - 1)
	player.vulnerable = maxi(0, player.vulnerable - 1)
	player.brittle_turns = maxi(0, player.brittle_turns - 1)
	if over:
		return
	turn += 1
	for e in alive():
		if e.fresh or e.keep_intent:
			# a newcomer keeps the intent it showed when it arrived (it acts on it next enemy turn)
			e.fresh = false
			e.keep_intent = false
			continue
		_plan(e)
	await anim.call({"type": "intents_shown"})
	await begin_player_turn()


func _enemy_phase() -> void:
	for e in enemies.duplicate():
		if over:
			return
		if e.is_dead():
			continue
		if e.fresh:
			# it arrived during your turn: this time it only shows what it's going to do
			e.fresh = false
			e.keep_intent = true
			continue
		# Burn: at the start of its turn, its burning Essence burns away (burned to nothing, it never acts)
		var gone: Array = e.burn_off()
		if not gone.is_empty():
			_log("%s's burning Essence (%s) burns away." % [e.name, " ".join(gone)])
			await anim.call({"type": "burn_off", "enemy": e, "n": gone.size()})
			if e.is_dead():
				_cleanup()
				_check_end()
				continue
		var ticks: Dictionary = e.begin_turn(rng)
		if not ticks.burn.is_empty() or not ticks.poison.is_empty():
			await anim.call({"type": "dot", "enemy": e, "burn": not ticks.burn.is_empty(), "poison": not ticks.poison.is_empty()})
		if e.is_dead():
			_cleanup()
			continue
		if e.has_passive("overgrowth") and not e.struck_this_turn:
			e.append(_random_element())
			_log("%s grows." % e.name)
		await anim.call({"type": "enemy_turn", "enemy": e, "move": e.intent, "frozen": e.freeze_turns > 0})
		if e.freeze_turns > 0:
			_log("%s is frozen." % e.name)
		else:
			if e.has_passive("briar_walls"):
				await _wall_turns(e)
			if not over and not e.is_dead():
				await _do_move(e, e.intent)
			if e.has_passive("echo") and not over:
				await _do_move(e, e.intent)
		await anim.call({"type": "enemy_done", "enemy": e})
		e.redirect_to = null
		if e.has_passive("gem_crown") and not e.armor.has(true) and e.size() > 1:
			e.set_armor(0)
		e.end_turn()
		_cleanup()
		_check_end()


## Moves are used strictly in the listed order, looping (a boss switches to its second list at half HP).
func _plan(e: EnemyState) -> void:
	if e.def.get("invokes", false):
		_invoker_plan(e)
		return
	if e.has_passive("briar_walls") and e.walls_standing() < 2:
		# a wall is down: she shows it, and regrows it on her next turn (the left one first)
		e.intent = {"kind": "regrow", "side": "L" if not ("L" in e.parts) else "R"}
		return
	if not e.opener.is_empty():
		e.intent = e.opener.pop_front()  # (a move it makes once, before its cycle: the Cubs' first flip)
		return
	var moves: Array = e.def.moves
	if e.is_boss and e.phase == 1 and e.size() <= int(e.def.hp.length() / 2) and not e.has_passive("yinyang_split") and not e.has_passive("hand") and not e.has_passive("handyman"):
		e.phase = 2
		e.move_index = 0
		_log("%s grows desperate!" % e.name)
		anim.call({"type": "boss_phase"})
	_rage_check(e)
	if e.phase == 2 and e.def.has("moves2"):
		moves = e.def.moves2
	e.intent = moves[e.move_index % moves.size()]
	e.move_index += 1
	if e.intent.kind == "charge" and e.intent.has("n"):
		e.charge_dmg = int(e.intent.n)  # a Charge starts: the spells you cast meanwhile change the hit


## One spell flipped by a Yin Yang Beast (or Cub). It goes back to its natural form first, then:
## - turned into an anti-spell: the beast absorbs 1 Essence of its pattern (at random) into its own row;
## - turned into a spell: 1 random Essence is added to its pattern (at a random place).
## That change lasts until it is flipped again (or the fight ends). A one-Essence pattern gives nothing up.
func _invert_spell(e: EnemyState, s: Dictionary) -> Dictionary:
	var natural: Dictionary = s.get("natural", s)
	var inv := natural.duplicate(true)
	inv.natural = natural
	inv.anti = not s.get("anti", false)
	if inv.has("patterns"):
		return inv  # (a fused anti-spell's two patterns stay as they are)
	var p := String(inv.pattern)
	if inv.anti:
		var spots := []
		for i in p.length():
			if p[i] in ["F", "W", "A"]:
				spots.append(i)
		if p.length() > 1 and not spots.is_empty():
			var i: int = spots[rng.randi() % spots.size()]
			var el := p[i]
			p = p.erase(i, 1)
			e.append(el)
			_log("%s absorbs a %s from %s." % [e.name, Elements.NAMES[el], inv.name])
	else:
		var el := _random_element()
		var at := rng.randi() % (p.length() + 1)
		p = p.insert(at, el)
		_log("%s comes back with an extra %s." % [inv.name, Elements.NAMES[el]])
	if p != String(inv.pattern):
		inv.pattern = p
		inv.size = p.length()
		inv.erase("full_pattern")  # (its seals no longer line up with the new pattern)
		inv.erase("seals")
	return inv


## The Yin Yang Beast's (soft) aim: it likes short spells as anti-spells and long ones as spells. Each pick is random,
## but weighted: a flip that moves a spell that way (a short spell turned anti, a long anti-spell turned back) is far
## likelier than one that undoes it. "Short" and "long" are against the average pattern length of what it can pick.
func _invert_pick(cands: Array) -> int:
	var avg := 0.0
	for s in cands:
		avg += String(s.pattern).length()
	avg /= maxf(1.0, cands.size())
	var weights := []
	var total := 0.0
	for s in cands:
		var plen := float(String(s.pattern).length())
		var gain := (plen - avg) if s.get("anti", false) else (avg - plen)  # >0: the flip goes its way
		var w := pow(4.0, clampf(gain, -3.0, 3.0))
		weights.append(w)
		total += w
	var r := rng.randf() * total
	for i in weights.size():
		r -= weights[i]
		if r <= 0.0:
			return i
	return weights.size() - 1


## Cooldown N: once cast, the spell can't be cast in your next N turns. (+1: the turn it's cast in ends first.)
func _start_cooldown(spell: Dictionary) -> void:
	var cd := int(spell.get("cooldown", 0))
	if cd > 0:
		player.cooldowns[spell.id] = cd + 1


## A spell is cast while a Yin Yang Beast charges: one of its own colour (white: a spell, black: an anti-spell) raises
## the hit by 5; one of the other colour leaves it as it is. The fight doesn't say so: you find out.
func _charge_react(spell: Dictionary) -> void:
	var col := "black" if spell.get("anti", false) else "white"
	for e in alive():
		if e.yin != "" and e.charge_dmg >= 0:
			if col == e.yin:
				e.charge_dmg += 5


## You gained Shield: an Enraged enemy gains Power +1 for each separate gain.
func _shield_gained(got: float) -> void:
	if got <= 0.0:
		return
	for e in alive():
		if e.has_passive("shield_rage"):
			e.power += 1
			e.dmg_bonus += 1
			_log("%s is enraged by your Shield: Power %d." % [e.name, e.power])


## The Invoker conjures 3 new spells (no repeats), stripped of the Essence his words took. In his second wind his
## intent also says the word he'll chant after casting (one he hasn't said yet).
func _invoker_plan(e: EnemyState) -> void:
	var pool := EnemyDefs.INVOKER_SPELLS.duplicate(true)
	e.conjured.clear()
	for k in 3:
		var sp: Dictionary = pool.pop_at(rng.randi() % pool.size())
		sp.rarity = "rare"
		sp.rarity_name = "Rare"
		sp.power = false
		sp.effects = []
		sp.base = sp.pattern
		sp.rank = rng.randf()  # (breaks ties for "closest": random, but the same in the preview and on his turn)
		e.conjured.append(sp)
	_strip_conjured(e)
	e.intent = {"kind": "invoke"}
	if e.phase == 2:
		var left := ["W", "A", "F"].filter(func(x): return not (x in e.stripped))
		if not left.is_empty():
			e.intent.word = left[rng.randi() % left.size()]


func _strip_conjured(e: EnemyState) -> void:
	for sp in e.conjured:
		var p := String(sp.base)
		for x in e.stripped:
			p = p.replace(x, "")
		sp.pattern = p


## Which of the Invoker's spells a chant sets off: every one it contains, or else the one it came closest to (fewest
## Essence of the pattern missing; ties broken by each spell's random rank).
func invoke_picks(e: EnemyState, c: String) -> Array:
	var full := []
	var best := -1
	for i in e.conjured.size():
		var miss := _missing(String(e.conjured[i].pattern), c)
		if miss == 0:
			full.append(i)
		elif best < 0 or miss < _missing(String(e.conjured[best].pattern), c) or (miss == _missing(String(e.conjured[best].pattern), c) and e.conjured[i].rank < e.conjured[best].rank):
			best = i
	if not full.is_empty():
		return full
	return [best] if best >= 0 else []


## How many Essence of a pattern the chant is short of: its length minus the longest piece of it found in the chant.
func _missing(p: String, c: String) -> int:
	var n := p.length()
	for k in range(n, 0, -1):
		for start in n - k + 1:
			if not Chant.occurrences(p.substr(start, k), c).is_empty():
				return n - k
	return n


## His turn: he casts what your chant set off, then (second wind) chants his word.
func _invoke(e: EnemyState, m: Dictionary) -> void:
	for i in invoke_picks(e, heard):
		if over or e.is_dead():
			return
		var sp: Dictionary = e.conjured[i]
		_log("%s casts %s!" % [e.name, sp.name])
		await anim.call({"type": "invoke", "enemy": e, "idx": i})
		await _do_move(e, sp.cast)
	if m.has("word") and not over and not e.is_dead():
		e.stripped.append(m.word)
		_strip_conjured(e)
		_log("%s chants \"%s!\" His spells lose every %s." % [e.name, EnemyDefs.INVOKER_WORDS[m.word], Elements.NAMES[m.word]])
		await anim.call({"type": "speech", "enemy": e, "text": EnemyDefs.INVOKER_WORDS[m.word] + "!"})


## The Invoker at 0 Essence the first time: he rises again with his second row, and starts chanting.
func _rebirths() -> void:
	for e in enemies:
		if e.has_passive("invoker_rebirth") and e.phase == 1 and e.is_dead():
			e.phase = 2
			e.reset_hp(String(e.def.hp2))
			_log("%s rises again, chanting!" % e.name)
			anim.call({"type": "boss_phase"})
			anim.call({"type": "speech", "enemy": e, "text": "Quas, Wex, Exort..."})


## The Handyman: hands at 0 Essence are knocked out, not killed (they count towards his next phase); new hands at 4
## and then 8 knockouts; in his last stand a knocked-out hand stays down, and with every hand down he shows himself.
func _handyman_step() -> void:
	if hm.is_empty():
		return
	for e in enemies.duplicate():
		if not e.has_passive("hand") or not e.is_dead() or e.knocked:
			continue
		e.charge_dmg = -1
		if hm.phase >= 3:
			enemies.erase(e)  # (his last stand: it stays down)
			_log("%s goes limp for good." % e.name)
		else:
			e.knocked = true
			e.intent = {"kind": "stunned"}
			hm.kills += 1
			_log("%s is knocked out (%d)." % [e.name, hm.kills])
	if hm.phase == 1 and hm.kills >= 4:
		_hm_phase(2, ["hand_hammer", "hand_crossbow"], "The Handyman reaches out with two more hands!")
	elif hm.phase == 2 and hm.kills >= 8:
		_hm_phase(3, ["hand_spear", "hand_shield"], "Two last hands, a spear and a shield: the Handyman makes his last stand!")
	if hm.phase == 3 and not hm.body and not enemies.any(func(x): return x.has_passive("hand")):
		hm.body = true
		var body := _spawn("handyman", [])
		body.reset_hp(_random_element())
		body.fresh = true
		_plan(body)
		_log("Out of hands, the Handyman shows himself!")
		anim.call({"type": "boss_phase"})
		anim.call({"type": "spawn", "enemy": body})


func _hm_phase(n: int, ids: Array, line: String) -> void:
	hm.phase = n
	hm.kills = 0
	for id in ids:
		var h := _spawn(id, [])
		h.fresh = true
		_plan(h)
		anim.call({"type": "spawn", "enemy": h})
	_log(line)
	anim.call({"type": "boss_phase"})


## Start of your turn: knocked-out hands come back whole (the Crossbow starts loading again from 2).
func _hands_back() -> void:
	for e in enemies:
		if e.knocked:
			e.knocked = false
			e.reset_hp(String(e.def.hp))
			e.move_index = 0
			_plan(e)
			_log("%s comes back." % e.name)


## The Hammer Hand: it picks the spell you've cast most this fight (a tie: one at random) and sticks to it until it
## breaks. 3 hits break a spell (a Fleeting one: the first); a broken spell is gone for the fight.
func _hammer(e: EnemyState) -> void:
	var cands := shown_spells().filter(func(s): return not player.used_powers.has(s.id))
	if cands.is_empty():
		return
	if hammer_target == "" or broken.has(hammer_target) or not cands.any(func(s): return s.id == hammer_target):
		var most := 0
		for s in cands:
			most = maxi(most, int(cast_counts.get(s.id, 0)))
		var top := cands.filter(func(s): return int(cast_counts.get(s.id, 0)) == most)
		hammer_target = top[rng.randi() % top.size()].id
	var sp := _find_spell(hammer_target)
	var hits: int = hammer_hits.get(hammer_target, 0) + 1
	hammer_hits[hammer_target] = hits
	var smashed: bool = hits >= 3 or sp.get("fleeting", false)
	if smashed:
		broken[hammer_target] = true
		stored.erase(hammer_target)
		charges.erase(hammer_target)
		_log("%s smashes %s to pieces!" % [e.name, sp.name])
	else:
		_log("%s hammers %s (%d)." % [e.name, sp.name, hits])
	await anim.call({"type": "hammer", "enemy": e, "id": hammer_target, "hits": hits, "broken": smashed})


## A support move's target: itself, or ("who": "random") any living enemy at random, itself included.
func _random_one(e: EnemyState, m: Dictionary) -> EnemyState:
	if m.get("who", "self") != "random":
		return e
	var pool := alive()
	return pool[rng.randi() % pool.size()] if not pool.is_empty() else e


func _do_move(e: EnemyState, m: Dictionary) -> void:
	var redirected: bool = e.redirect_to != null and is_instance_valid(e.redirect_to)
	if redirected and m.kind == "attack":
		var tgt: EnemyState = e.redirect_to
		for h in m.get("hits", 1):
			if tgt.is_dead():
				break
			var dmg: float = floorf((m.n + e.dmg_bonus) * e.damage_mult())
			var n := maxi(1, int(ceil(dmg / REDIRECT_DMG_PER_ELEMENT)))
			var lost := tgt.remove_right(n).size()
			_log("%s's attack is turned on %s: -%d." % [e.name, "itself" if tgt == e else tgt.name, lost])
			await anim.call({"type": "strike", "enemy": tgt, "n": lost})
		_cleanup()
		if m.has("also") and not over and not e.is_dead():
			await _do_move(e, m.also)
		return
	if redirected and m.kind in AT_PLAYER:
		_log("%s's %s is redirected and fizzles." % [e.name, m.kind])
		if m.has("also") and not over and not e.is_dead():
			await _do_move(e, m.also)
		return
	match m.kind:
		"attack":
			for h in m.get("hits", 1):
				var dmg: float = floorf((m.n + e.dmg_bonus) * e.damage_mult())
				var shield_before := player.shield + player.lasting
				var aegis_before := player.aegis
				var lost := player.take_attack(dmg)
				var blocked := player.aegis < aegis_before or player.shield + player.lasting < shield_before
				_log("%s attacks for %d." % [e.name, lost])
				await anim.call({"type": "attack", "enemy": e, "n": lost, "blocked": blocked, "part": e.acting_part})
				var th := player.thorns_turn + player.passive("thorns")
				if th > 0 and not player.ethereal:
					e.remove_right(th)
					await anim.call({"type": "thorns_proc"})
				_check_end()
				if over or e.is_dead():
					break
		"armor":
			var t := _random_one(e, m)  # (itself, or one of them at random)
			if m.pos < 0:  # the first Essence that isn't armoured yet (Ice Wall: several)
				for k in int(m.get("count", 1)):
					var free := t.armor.find(false)
					if free >= 0:
						t.set_armor(free)
			else:
				t.set_armor(mini(m.pos, t.size() - 1))
		"mend":
			var who: String = m.get("who", "self")
			var targets := [e]
			if who == "all":
				targets = alive()
			elif who == "ally":
				var others := alive().filter(func(x): return x != e)
				if not others.is_empty():
					others.sort_custom(func(a, b): return a.size() < b.size())
					targets = [others[0]]
			elif who == "random_hurt":
				# one of them at random, a hurt one (below the cap) if any is hurt
				var hurt := alive().filter(func(x): return x.size() < int(m.get("cap", 999)))
				var pool: Array = hurt if not hurt.is_empty() else alive()
				targets = [pool[rng.randi() % pool.size()]]
			elif who == "weakest":
				# the most hurt of them (itself included) that is still below the cap; nobody hurt: nothing
				var hurt := alive().filter(func(x): return x.size() < int(m.get("cap", 999)))
				hurt.sort_custom(func(a, b): return a.size() < b.size())
				targets = hurt.slice(0, 1)
			for t in targets:
				for i in m.n:
					if t.size() >= int(m.get("cap", 999)):
						break  # (healing: never past its starting Essence)
					var el: String = m.el
					if el == "random":
						el = _random_element()
					elif el == "own":
						el = t.def.hp[0]  # (its own element)
					t.append(el)
			await anim.call({"type": "mend", "enemy": e})
		"shuffle":
			e.rotate_left()
		"silence":
			var cands := usable_spells()
			for k in int(m.get("n", 1)):
				if cands.is_empty():
					break
				var s: Dictionary = cands.pop_at(rng.randi() % cands.size())
				player.silenced[s.id] = m.turns
				_log("%s silences %s." % [e.name, s.name])
			await anim.call({"type": "silence"})
		"invert_spells":
			# the Yin Yang Beast: some of your spells flip (spell <-> anti-spell) for the rest of the fight, and it turns
			# the other colour
			var cands := shown_spells().filter(func(s): return not s.get("power", false) and String(s.get("pattern", "")) != "" and not player.used_powers.has(s.id))
			var flipped := []
			for k in m.n:
				if cands.is_empty():
					break
				var s: Dictionary = cands.pop_at(_invert_pick(cands))
				var inv := _invert_spell(e, s)
				loadout[loadout.find(s)] = inv
				flipped.append(inv.name)
			e.yin = "black" if e.yin == "white" else "white"
			if not flipped.is_empty():
				_log("%s inverts %s." % [e.name, ", ".join(flipped)])
			await anim.call({"type": "invert_spells", "enemy": e})
		"invoke":
			await _invoke(e, m)
		"cleanse_self":
			e.burn = 0
			e.poison = 0
			e.weak_turns = 0
			e.weak25 = false
			e.freeze_turns = 0
			e.no_mend = false
			e.phased = false
			_log("%s cleanses himself." % e.name)
			await anim.call({"type": "mend", "enemy": e})
		"drain_essence":
			for k in m.n:
				if player.stock.is_empty():
					break
				player.stock.remove_at(rng.randi() % player.stock.size())
			_log("%s drains %d of your Essence." % [e.name, m.n])
			await anim.call({"type": "silence"})
		"disarm":
			player.disarmed_turns = maxi(player.disarmed_turns, m.turns)
			_log("%s Disarms you: your next Release does nothing." % e.name)
			await anim.call({"type": "frail"})
		"hammer_spell":
			await _hammer(e)
		"charge":
			if m.get("hit", false):
				var dmg: int = maxi(0, e.charge_dmg)
				e.charge_dmg = -1
				await anim.call({"type": "hourglass_dust", "enemy": e})  # (the hourglass runs out and crumbles first)
				if dmg > 0:
					await _do_move(e, {"kind": "attack", "n": dmg})
				else:
					_log("%s's charge fizzles out." % e.name)
			else:
				await anim.call({"type": "charge_tick", "enemy": e})
		"ignite_spell":
			var cands := usable_spells().filter(func(s): return not player.ignited.has(s.id))
			for k in int(m.get("n", 1)):
				if cands.is_empty():
					break
				var s: Dictionary = cands.pop_at(rng.randi() % cands.size())
				player.ignited[s.id] = m.turns
				_log("%s sets %s on fire: casting it next turn burns you for %d." % [e.name, s.name, IGNITE_DAMAGE])
			await anim.call({"type": "ignite_spell"})
		"lock":
			var cands := active_spells().filter(func(s): return not player.locks.has(s.id))
			if not cands.is_empty():
				var s: Dictionary = cands[rng.randi() % cands.size()]
				var n: int = m.len - (int(_an("lock_pick")) if has_artifact("lock_pick") else 0)
				var pat := ""
				for i in maxi(1, n):
					pat += Elements.random(rng)
				player.locks[s.id] = pat
				_log("%s locks %s. Chant %s to break it." % [e.name, s.name, pat])
		"steal":
			var owned := player.stock.filter(func(s): return not s.temp)
			for i in mini(m.n, owned.size()):
				var s: Dictionary = owned[i]
				player.stock.erase(s)
				e.append(s.el, false)
			_log("%s steals your Essence onto its hide." % e.name)
		"confuse":
			if not has_artifact("calm_stone"):
				player.confuse_turns = 1
				await anim.call({"type": "confuse"})
		"blind":
			if not has_artifact("keen_eye"):
				player.blind_turns = m.turns
				blind_masks.clear()
				await anim.call({"type": "blind"})
		"bleed":
			player.bleed += m.n
		"frail":
			player.frail_turns = maxi(player.frail_turns, m.turns)
			_log("%s makes you Frail: you take 25%% more damage." % e.name)
			await anim.call({"type": "frail"})
		"wall_attack":
			# each wall that still stands attacks
			var hits: int = m.get("hits", 1) * e.walls_standing()
			if hits > 0:
				await _do_move(e, {"kind": "attack", "n": m.n, "hits": hits})
		"regrow":
			var side: String = m.get("side", "L")
			if not (side in e.parts):
				e.grow_wall(side, _wall_essence(int(e.def.get("walls", 5))))
				e.wall_step[side] = 0  # a new wall starts its pattern over
				_log("%s regrows her %s wall." % [e.name, "left" if side == "L" else "right"])
		"sing":
			e.dmg_bonus += 1
			e.power += 1
			_log("%s sings: Power %d." % [e.name, e.power])
		"brittle":
			player.brittle_turns = maxi(player.brittle_turns, m.turns)
			_log("%s makes you Brittle: you gain 25%% less Shield." % e.name)
			await anim.call({"type": "frail"})
		"freeze":
			var free := player.stock.filter(func(s): return not s.frozen)
			free.shuffle()
			for s in free.slice(0, m.n):
				s.frozen = true
			await anim.call({"type": "freeze_stock"})
		"ethereal":
			e.ethereal = true
		"empower":
			var t := _random_one(e, m)
			t.dmg_bonus += m.n
			t.power += m.n
			if t != e:
				_log("%s empowers %s." % [e.name, t.name])
		"summon":
			for i in m.n:
				if alive().size() < MAX_ENEMIES:
					var add := _spawn(m.id if m.has("id") else m.ids[rng.randi() % m.ids.size()])
					add.fresh = true
					_plan(add)
					await anim.call({"type": "spawn", "enemy": add})
		"toll":
			player.toll = PlayerState.TOLL_CAP
		"invert":
			for s in player.stock:
				s.el = {"F": "W", "W": "F"}.get(s.el, s.el)
		"hex":
			var free := player.stock.filter(func(s): return not s.hexed)
			if not free.is_empty():
				free[rng.randi() % free.size()].hexed = true
		"mimic":
			if last_chant != "":
				var hp := last_chant.reverse().substr(0, 6)
				e.elements.clear()
				for ch in hp:
					e.elements.append(ch)
				e.armor.resize(e.elements.size())
				e.armor.fill(false)
				e.lit.clear()
	if m.kind != "attack":
		await anim.call({"type": "enemy_move", "enemy": e, "kind": m.kind, "move": m})
	if m.has("also") and not over and not e.is_dead():
		await _do_move(e, m.also)


# ------------------------------------------------------------------ bookkeeping

## Tomato Knight: at half its Essence or less it throws its shield away and goes all out (right away: its next
## move becomes the double attack).
func _rage_check(e: EnemyState) -> bool:
	if not e.has_passive("rage_at_half") or e.phase != 1 or e.is_dead() or e.size() > int(e.def.hp.length() / 2):
		return false
	e.phase = 2
	e.move_index = 0
	e.shatter()
	_log("%s throws away its shield!" % e.name)
	return true


func _cleanup() -> void:
	_rebirths()
	_handyman_step()
	for e in enemies:
		if _rage_check(e):
			_plan(e)
	for e in enemies.duplicate():
		if e.is_dead() and not e.knocked:
			enemies.erase(e)
			if e.is_boss:
				anim.call({"type": "boss_defeat"})
			if not (e.id in defeated):
				defeated.append(e.id)
			if e.has_passive("briar_walls") and not e.elements.is_empty():
				_log("The walls fall with her.")
			if not e.elements.is_empty() and e.poisoned_out():
				_log("%s succumbs to the poison." % e.name)
			if e.has_passive("last_gasp"):
				player.bleed += 2
				_log("%s bursts: you bleed." % e.name)
			if e.has_passive("yinyang_split"):
				# it splits into two cubs: one white, one black, out of step (one inverts first, the other roars)
				for k in 2:
					if alive().size() < MAX_ENEMIES:
						var cub := _spawn("yin_yang_clone")
						cub.yin = ["white", "black"][k]
						if k == 1:
							cub.def.moves = cub.def.moves_black  # (the black one silences first, then charges)
							cub.reset_hp(String(cub.def.hp_black))  # (a row unlike the white one's)
						cub.fresh = true
						_plan(cub)
						anim.call({"type": "spawn", "enemy": cub})
				_log("%s splits in two!" % e.name)
			if e.has_passive("slime_burst"):
				# two small slimes of different colours pop out
				var kinds := ["purple_slime", "green_slime", "yellow_slime"]
				kinds.remove_at(rng.randi() % 3)  # (the fight's own dice, so Undo and saved runs replay it the same)
				for k in kinds:
					if alive().size() < MAX_ENEMIES:
						var add := _spawn(k)
						add.fresh = true
						_plan(add)
						anim.call({"type": "spawn", "enemy": add})
				_log("%s bursts into smaller slimes!" % e.name)
			_log("%s is defeated." % e.name)
	_check_end()


func _check_end() -> void:
	_rebirths()
	_handyman_step()
	if over:
		return
	if player.is_dead():
		over = true
		won = false
	elif alive().is_empty() and not enemies.any(func(x): return x.knocked):
		over = true
		won = true


## For the UI: which positions of this enemy's HP are hidden by Blind.
func hidden_mask(e: EnemyState) -> Array:
	if player.blind_turns <= 0:
		return []
	if not blind_masks.has(e) or blind_masks[e].size() != e.size():
		var mask := []
		for i in e.size():
			mask.append(i % 2 == 1)
		blind_masks[e] = mask
	return blind_masks[e]
