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
##   wild_arranger:(spell) -> [from, to] (the chant) / [from, to, enemy] / []   Wild Rearrange: one move, anywhere
##   wild_painter: (spell) -> ["chant", i] / ["enemy", enemy, i] / []          Wild Repaint: one Essence, anywhere
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
const AT_PLAYER := ["disarm", "drain_essence", "invert_spells", "ignite_spell", "silence", "lock", "steal", "confuse", "blind", "poison", "freeze", "toll", "invert", "hex", "mimic", "frail", "brittle"]

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
var talk_id := ""  # a boss you can talk to before the fight (BossTalk): its id
var talk_free := false  # test mode: talking to a boss costs nothing
var talk_spent: Array = []
var talk_rewards: Array = []  # artifact ids the talk promised: yours (and unlocked for good) if you win  # the Essence the talk has cost you so far
var invoke_count := 3  # how many spells the Invoker conjures a turn
var hm := {}  # the Handyman fight: {phase, kills, body}
var cast_counts := {}  # spell id -> casts this fight (the Hammer goes for the most-cast)
var hammer_target := ""
var hammer_hits := {}  # spell id -> Hammer hits taken (3 break it)
var broken := {}  # spell id -> true: broken (worn out, or smashed by the Hammer), gone for the fight
var hammered := {}  # spell id -> true: smashed by the Hammer: it leaves the row for the rest of the fight
var exhausted: Array = []  # spell ids Exhausted this fight: gone for the rest of the run
const TRINITY_PARTS := ["trinity_first", "trinity_second", "trinity_third"]
var trinity_cast := {}  # Trinity Fragments cast this turn (base id -> true)
var trinity_formed := false  # the three became Trinity this fight (the run keeps it: see RunState.finish_fight)
var stored := {}  # spell id -> true: alive but not cast when you Released; it wakes again on your next Chant
var turn_ctx := {}  # {entries, amplify, echo, retain, last, cast_any}
var paint_to := "?"  # Repaint: what the brush paints right now (the painter skips Essence already that)
var pick_el := ""  # the picker may only take Essence of this kind ("": any): "remove up to 3 Fire" lets you choose which Fire

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
var wild_arranger: Callable
var wild_painter: Callable
var anim: Callable


func _init(p_db: SpellDB, p_player: PlayerState) -> void:
	db = p_db
	player = p_player
	chooser = func(_s, cands): return cands[0]
	mover = func(_s, _e): return []
	picker = func(_s, e):  # by default: the first one it may take
		for i in e.size():
			if not e.armor[i] and (pick_el == "" or e.elements[i] == pick_el):
				return i
		return -1
	painter = func(_s):  # by default: the first Essence that isn't the paint's colour yet
		for e in alive():
			var i: int = e.elements.find_custom(func(x): return x != paint_to)
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
	wild_arranger = func(_s): return []
	wild_painter = func(s):  # by default: an enemy Essence, as the painter would choose
		var got: Array = await painter.call(s)
		return ["enemy", got[0], got[1]] if got.size() == 2 else []
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
		if BossTalk.TREES.has(enemy_ids[i]):
			talk_id = enemy_ids[i]
		if enemy_ids[i] == "handyman":
			# the Handyman starts as two hands (he himself only shows up at the very end)
			hm = {"phase": 1, "kills": 0, "body": false}
			_spawn("hand_sword", [])
			_spawn("hand_tweezer", [])
			continue
		_spawn(enemy_ids[i], preset_extra[i] if i < preset_extra.size() else null)
	if has_artifact("thornbark"):
		player.passives["thorns"] = int(_an("thornbark"))
	if has_artifact("chant_bell"):
		player.passives["echo_first"] = 1
	if has_artifact("rain_chalice"):
		player.lasting += _an("rain_chalice")
	if has_artifact("iron_bark"):
		player.lasting += _an("iron_bark")  # (turn 1's; begin_player_turn gives the rest)
	if has_artifact("ward_stone"):
		player.aegis = int(_an("ward_stone"))
	if has_artifact("mysterious_hand"):
		# the Mysterious Hand: a random Essence of a random enemy, into your bag
		var pool := alive().filter(func(x): return x.armor.has(false))
		if not pool.is_empty():
			var e: EnemyState = pool[rng.randi() % pool.size()]
			var free := []
			for i in e.size():
				if not e.armor[i]:
					free.append(i)
			var el: String = e.pluck(free[rng.randi() % free.size()])
			if el != "":
				player.add_element(el if el != "?" else _random_element())
				_log("The Mysterious Hand steals a %s from %s." % [Elements.NAMES.get(el, "Essence"), e.name])
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
	e.dmg_bonus = 0 if d.get("no_bonus", false) else EnemyDefs.attack_bonus(act)
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
	return shown_spells().filter(func(s): return not player.used_powers.has(s.id) and not broken.has(s.id))


## The active row as you see it: a Conjure spell whose conjured spells are out isn't in it (they stand in its place).
func shown_spells() -> Array:
	# (broken ones too: they stay, cracked and grey; a Power you've cast leaves the row: it's a badge now, if it lasts)
	# (a spell the Hammer smashed is gone from the row altogether)
	return loadout.filter(func(s): return not conjuring.has(s.id) and not hammered.has(s.id) and not (s.get("power", false) and player.used_powers.has(s.id)))


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
	refund_slots.clear()
	for lens in LENSES:
		if not has_artifact(lens):
			continue
		for i in chanted.size():
			var el: String = chanted[i]
			if el == LENSES[lens] and rng.randf() < _an(lens):
				back.append(el)
				refund_slots.append(i)  # (which slot of the chant it leaves, for the animation)
	return back


var refund_slots: Array = []  # the chant slot each Essence of the last _lens_refunds came from


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


## Start of your turn (not the first): Poison bites, receive the previewed draw, Powers tick.
func begin_player_turn() -> void:
	if player.poison > 0:
		player.take_effect(player.poison)  # Poison: lose that much HP, then it drops by 1
		_log("Poison: you lose %d HP." % player.poison)
		player.poison -= 1
		await anim.call({"type": "poison_tick"})
	if has_artifact("mending_moss"):
		player.heal(_an("mending_moss"))
	player.thorns_turn = 0
	player.thorn_guard = false
	_hands_back()
	if has_artifact("iron_bark"):
		player.lasting += _an("iron_bark")  # Iron Bark: Lasting Shield every turn
	player.shield = 0.0  # Shield lasts until your next turn starts (it doesn't build up from turn to turn)
	for d in player.next_draw:
		player.add_element(d.el, d.temp)
	_roll_next_draw(turn + 1)
	for pw in player.each_turn:
		await _proc(pw.spell.id)
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
		elif n >= e.size():
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
		_log("Echo Chamber: a short chant. Your first spell this turn is cast twice.")
	anti_broken.clear()
	turn_ctx = {"entries": entries, "amplify": 0, "echo": 0, "retain": 0, "last": {}, "cast_any": false}
	await anim.call({"type": "chant", "chant": c})
	var woke: Array = await _recount()
	# always: the chant is read out note by note, even when it wakes no spell
	await anim.call({"type": "charged", "hits": woke})
	for k in player.passive("steal_each_chant"):
		if over or alive().is_empty():
			break
		await _proc("steal_each_chant")
		var knife := _find_spell("storm_crown")
		if knife.is_empty():
			knife = {"id": "storm_crown", "name": "Jaeler's Knife", "effects": []}
		await _apply({"op": "steal", "n": 1, "el": "any", "into": "chant", "target": "target"}, knife, {})
		var more: Array = await _recount()
		if not more.is_empty():
			await anim.call({"type": "extension", "hits": more})


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
	_wear(spell)  # (Durability: one cast, one point, however many times it's echoed)
	if has_artifact("magic_box"):
		player.box_casts += 1
		if player.box_casts % 6 == 0:
			# the Magic Box: this spell's pattern comes back to your bag after the Release
			if not turn_ctx.has("box_refund"):
				turn_ctx.box_refund = []
			for ch in String(spell.get("pattern", "")):
				turn_ctx.box_refund.append(ch if ch != "?" else _random_element())
			_log("The Magic Box plays a note: %s's Essence will come back after the Release." % spell.name)
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
		for eff in spell.effects:
			if eff.op == "heal_per_extension":
				player.heal(int(eff.n) * woke.size())
				_log("%s: %d Extension%s, heal %d." % [spell.name, woke.size(), "" if woke.size() == 1 else "s", int(eff.n) * woke.size()])


## Does this Power keep doing something for the rest of the fight (so it gets a badge)? Open Grimoire doesn't.
static func lasting_power(spell: Dictionary) -> bool:
	return spell.effects.any(func(e): return e.op in ["passive", "each_turn", "curse"])


## Durability N: a spell that wears out. Each cast takes 1; at 0 it's gone for the fight (the Handyman Power gives
## every such spell 1 more). Spells without Durability never wear out.
static func base_durability(spell: Dictionary) -> int:
	return int(spell.get("durability", 1 if spell.get("fleeting", false) else 0))  # ("fleeting": spells fused before)


func durability_left(spell: Dictionary) -> int:
	if player.durability.has(spell.id):
		return int(player.durability[spell.id])  # (worn, or set: Desperate Measure gives every spell Durability 1)
	var base := base_durability(spell)
	if base <= 0:
		return -1
	return int(player.durability.get(spell.id, base + player.passive("durability_bonus")))


## One point of Durability off (a cast, or a Hammer hit). Returns true if that broke it.
func _wear(spell: Dictionary) -> bool:
	if (base_durability(spell) <= 0 and not player.durability.has(spell.id)) or spell.has("bottle"):
		return false
	var left := durability_left(spell) - 1
	player.durability[spell.id] = left
	if left <= 0:
		_break(spell.id)
		_log("%s is worn out: broken for the rest of this fight." % spell.name)
		return true
	return false


## A spell broken for the fight (worn out, or smashed by the Hammer): it stays in the row, cracked and grey.
func _break(id: String) -> void:
	broken[id] = true
	stored.erase(id)
	charges.erase(id)


## Glue: one more point of Durability for a spell; a broken spell is mended (with 1 Durability).
func mend_spell(id: String) -> void:
	var sp := _find_spell(id)
	if broken.has(id):
		broken.erase(id)
		hammer_hits.erase(id)
		player.durability[id] = 1
	else:
		player.durability[id] = maxi(0, durability_left(sp)) + 1
	_log("%s is mended: %d Durability." % [sp.get("name", id), player.durability[id]])


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
		for i in turn_ctx.get("refund_at", []):
			if i < chant.size():
				var el: String = chant[i]
				player.add_element(el if el != "?" else _random_element())
		var back := _lens_refunds(chant)
		back.append_array(turn_ctx.get("box_refund", []))  # (the Magic Box)
		for k in player.passive("refund_air"):
			back.append("A")  # Storm Crown: Air comes back after every Release
			refund_slots.append(maxi(0, chant.size() - 1))
		var back_uids := []
		for el in back:
			player.add_element(el if el != "?" else _random_element())
			back_uids.append(player.stock.back().uid)
		if not back.is_empty():
			_log("Refunded to your bag: %s." % " ".join(back))
			await anim.call({"type": "refund", "els": back.duplicate(), "uids": back_uids, "slots": refund_slots.duplicate()})
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
			_wear(sp)
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
		if player.passive("strike_burn") > 0:
			await _proc("strike_burn")
			await _burned(1)
			e.ignite(_burn_amount(player.passive("strike_burn") + player.passive("burn_bonus")), rng)
		if e.has_passive("burning_hide") and not player.thorn_guard:
			player.take_effect(1.0)
			_log("%s's burning hide scorches you." % e.name)
		if e.thorns > 0 and not player.thorn_guard:
			player.take_effect(float(e.thorns))
			_log("%s's thorns prick you for %d." % [e.name, e.thorns])
		if e.has_passive("thorns") and not player.thorn_guard:
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
	if player.echo_chamber_on and not spell.has("bottle"):
		player.echo_chamber_on = false  # (the Echo Chamber echoes only the first spell of the turn)
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
	if spell.get("exhaust", false) and not spell.get("ephemeral", false):
		# Exhaust: gone from this fight, and from your spellbook for the rest of the run
		exhausted.append(String(spell.get("base_id", spell.id)))
		loadout = loadout.filter(func(s): return s.id != spell.id)
		_log("%s is Exhausted: gone for the rest of the run." % spell.name)
		await anim.call({"type": "loadout_changed"})
	var base_id := String(spell.get("base_id", spell.id))
	if base_id in TRINITY_PARTS and not trinity_formed and not spell.get("ephemeral", false):
		trinity_cast[base_id] = true
		if trinity_cast.size() == TRINITY_PARTS.size():
			await _form_trinity()
	ctx.last = spell
	_cleanup()


## The three Trinity Fragments were all cast this turn (any order): they combine into Trinity, in the row where the
## first of them was. It can't be cast until your next turn; the run keeps it in place of the three.
func _form_trinity() -> void:
	trinity_formed = true
	var parts := loadout.filter(func(s): return String(s.get("base_id", s.id)) in TRINITY_PARTS)
	var trinity := db.get_spell("trinity").duplicate(true)
	var at := loadout.size()
	for s in parts:
		at = mini(at, loadout.find(s))
	loadout = loadout.filter(func(s): return not (s in parts))
	loadout.insert(mini(at, loadout.size()), trinity)
	spellbook = spellbook.filter(func(s): return not (String(s.get("base_id", s.id)) in TRINITY_PARTS))
	spellbook.append(trinity)
	used[trinity.id] = 99  # (asleep for the rest of this turn, even if the chant has its pattern)
	_log("The three Fragments become Trinity!")
	await anim.call({"type": "trinity", "parts": parts, "result": trinity})


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
			var base: int = eff.n
			if eff.has("per_chant"):
				# Flare: Burn 1 for every 2 Fire in this turn's chant
				base = int(eff.n) * (chant.count(eff.per_chant) / maxi(1, int(eff.get("per", 1))))
				if base <= 0:
					targets = []
			var amount := _burn_amount(base + player.passive("burn_bonus")) if not targets.is_empty() else 0
			for e in targets:
				e.ignite(amount, rng)
			await _burned(targets.size())
		"stoke":
			for e in targets:
				e.ignite(e.burn, rng)
		"weak":
			for e in targets:
				if eff.get("if_attacking", false) and e.intent.get("kind", "") != "attack":
					continue  # (Against the Tide: only if it means to attack)
				e.weak_turns = maxi(e.weak_turns, eff.turns)
		"freeze":
			for e in targets:
				if eff.has("if_burn") and e.burn < int(eff.if_burn):
					continue  # (Frost Burn: only if it's burning that much)
				e.freeze_turns = maxi(e.freeze_turns, eff.turns)  # (bosses too)
		"expose":
			# Repaint: paint n Essence of your choice, on any enemies, into one colour (Any by default: "?") for good
			var to: String = eff.get("to", "?")
			for i in eff.n:
				if not alive().any(func(x): return x.elements.any(func(el): return el != to)):
					break
				paint_to = to
				var got: Array = await painter.call(spell)
				paint_to = "?"
				if got.size() < 2 or got[0] < 0 or got[0] >= enemies.size():
					break
				var e: EnemyState = enemies[got[0]]
				if e.is_dead() or got[1] >= e.size() or e.elements[got[1]] == to:
					continue
				var was: String = e.elements[got[1]]
				e.elements[got[1]] = to
				_log("%s repaints %s's %s: it's %s now." % [spell.name, e.name, Elements.NAMES.get(was, "Essence"), "an Any Essence" if to == "?" else Elements.NAMES[to]])
				await anim.call({"type": "paint", "enemy": e, "index": got[1], "was": was, "to": to})
		"wild_move":
			# Wild Rearrange: each move is either within an enemy's row or within this turn's chant (your pick)
			for k in int(eff.get("n", 1)):
				if over:
					break
				var mv: Array = await wild_arranger.call(spell)
				if mv.size() == 2 and spoken and chant.size() > 1:
					var from := clampi(int(mv[0]), 0, chant.size() - 1)
					var el: String = chant[from]
					chant.remove_at(from)
					chant.insert(clampi(int(mv[1]), 0, chant.size()), el)
					_log("%s moves a %s in the chant." % [spell.name, Elements.NAMES[el]])
					await anim.call({"type": "chant_changed"})
				elif mv.size() == 3 and int(mv[2]) >= 0 and int(mv[2]) < enemies.size():
					var e: EnemyState = enemies[int(mv[2])]
					e.move_element(int(mv[0]), int(mv[1]))
					_log("%s moves an Essence of %s." % [spell.name, e.name])
					await anim.call({"type": "effect", "op": "move", "targets": [e]})
				else:
					break
		"wild_repaint":
			# Wild Repaint: each paint is an enemy Essence or a chant Essence (your pick), into that colour
			var to: String = eff.get("to", "?")
			for k in int(eff.get("n", 1)):
				if over:
					break
				paint_to = to
				var got: Array = await wild_painter.call(spell)
				paint_to = "?"
				if got.size() == 2 and got[0] == "chant" and spoken and int(got[1]) >= 0 and int(got[1]) < chant.size():
					var i := int(got[1])
					if chant[i] != to:
						_log("%s repaints a %s in the chant: %s." % [spell.name, Elements.NAMES[chant[i]], Elements.NAMES[to]])
						chant[i] = to
						await anim.call({"type": "chant_changed"})
				elif got.size() == 3 and got[0] == "enemy" and int(got[1]) >= 0 and int(got[1]) < enemies.size():
					var e: EnemyState = enemies[int(got[1])]
					var i := int(got[2])
					if not e.is_dead() and i < e.size() and e.elements[i] != to:
						var was: String = e.elements[i]
						e.elements[i] = to
						_log("%s repaints %s's %s: it's %s now." % [spell.name, e.name, Elements.NAMES.get(was, "Essence"), "an Any Essence" if to == "?" else Elements.NAMES[to]])
						await anim.call({"type": "paint", "enemy": e, "index": i, "was": was, "to": to})
				else:
					break
		"self_repaint":
			# Self-Repaint: n Essence of this turn's chant, of your choice, become that colour (Any fits every pattern)
			var to: String = eff.get("to", "?")
			for k in int(eff.get("n", 1)):
				if not spoken or over or chant.is_empty() or not chant.any(func(x): return x != to):
					break
				var i: int = clampi(await chant_picker.call(spell), 0, chant.size() - 1)
				if chant[i] == to:
					continue
				_log("%s repaints a %s in the chant: %s." % [spell.name, Elements.NAMES[chant[i]], Elements.NAMES[to]])
				chant[i] = to
				await anim.call({"type": "chant_changed"})
		"ethereal":
			if eff.target == "self":
				player.ethereal = true
			else:
				for e in targets:
					e.phased = true
		"shield":
			_shield_gained(player.gain_shield(eff.n, eff.get("lasting", false)))
		"heal":
			var ok := true
			if eff.has("per_chant"):
				player.heal(int(eff.n) * chant.count(eff.per_chant))  # (Jaeler's Backup Plan: 1 per Water in the chant)
				ok = false
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
			# you choose which ones of that kind go (every other Essence is dimmed)
			for e in targets:
				for k in eff.n * (2 if e.phased else 1):
					var idx: int = await _pick_of(spell, e, eff.el)
					if idx < 0:
						break
					e.pluck(idx)
		"purge_all":
			for e in targets:
				var gone: Array = e.purge(eff.el, 999)
				_log("%s washes away %d %s from %s." % [spell.name, gone.size(), Elements.NAMES[eff.el], e.name])
		"shatter":
			for e in targets:
				var broke: int = e.armor.count(true)
				e.shatter()
				if int(eff.get("shield_per", 0)) > 0 and broke > 0:
					_shield_gained(player.gain_shield(broke * int(eff.shield_per)))  # Chill: Shield for each Armour broken
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
		"meteor_rain":
			# Chaos Meteor: Burn 1 on a random enemy, again and again
			for k in int(eff.n):
				var pool := alive()
				if pool.is_empty():
					break
				var t: EnemyState = pool[rng.randi() % pool.size()]
				await anim.call({"type": "meteor", "enemy": t})  # (one fireball at a time)
				t.ignite(1, rng)
				await _burned(1)
				anim.call({"type": "meteor_hit", "enemy": t})
			_log("%s rains fire: Burn 1, %d times." % [spell.name, eff.n])
		"disarm":
			for e in targets:
				e.disarmed = maxi(e.disarmed, int(eff.get("turns", 1)))
			_log("%s Disarms them." % spell.name)
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
			await _conjure(eff.n, spell, eff.get("kind", ""))
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
			# Refund N: pick N Essence of the chant; after the Release they go back to your bag
			if not ctx.has("refund_at"):
				ctx.refund_at = []
			for k in int(eff.n):
				if not spoken or ctx.refund_at.size() >= chant.size():
					break
				var i: int = clampi(await chant_picker.call(spell), 0, chant.size() - 1)
				if i in ctx.refund_at:
					for j in chant.size():  # (that one's taken already: the next free one)
						if not (j in ctx.refund_at):
							i = j
							break
				ctx.refund_at.append(i)
				_log("%s: the %s comes back after the Release." % [spell.name, Elements.NAMES[chant[i]]])
				await anim.call({"type": "chant_changed"})
		"mend_spell":
			var pool := shown_spells().filter(func(s): return broken.has(s.id) or base_durability(s) > 0)
			var k: int = await spell_chooser.call(pool)
			if k >= 0 and k < pool.size():
				mend_spell(pool[k].id)
				await anim.call({"type": "loadout_changed"})
		"overload":
			player.overload += eff.n
		"cleanse":
			var had := _debuff_kinds()
			_cleanse(eff.get("what", "all"))
			if int(eff.get("lasting_per", 0)) > 0 and had > 0:
				_shield_gained(player.gain_shield(had * int(eff.lasting_per), true))  # Purify: Lasting Shield per debuff
		"thorn_guard":
			player.thorn_guard = true
		"max_hp":
			player.max_hp += int(eff.n)
			player.hp += int(eff.n)
			_log("%s: +%d max HP." % [spell.name, eff.n])
		"all_fragile":
			# Desperate Measure: every spell's Durability is 1 for the rest of this fight (even ones that had none)
			for s in shown_spells():
				if not s.get("power", false) and not broken.has(s.id):
					player.durability[s.id] = 1
			_log("%s: every spell is down to 1 Durability." % spell.name)
			await anim.call({"type": "loadout_changed"})
		"daze":
			for e in targets:
				e.dazed += int(eff.n)
		"heal_per_extension":
			pass  # (resolve_spell heals once the chant's been re-read)
		"infuse_upcoming":
			# All In: next turn's Essence come now, into this turn's chant, wherever you put them (and not next turn)
			var coming: Array = player.next_draw.duplicate()
			player.next_draw.clear()
			for d in coming:
				if not spoken or over:
					player.next_draw.append(d)
					continue
				var pos: int = await placer.call(spell, d.el)
				chant.insert(clampi(pos, 0, chant.size()), d.el)
				_log("%s: %s goes into the chant now." % [spell.name, Elements.NAMES[d.el]])
				await anim.call({"type": "chant_changed"})
				await _disturb(d.el)
		"temp_seal":
			# Reforge: a purple seal on another spell for this fight (a random Essence of its pattern isn't needed)
			var pool := active_spells().filter(func(s): return s.id != spell.id and String(s.pattern).length() >= 2)
			var k: int = await spell_chooser.call(pool)
			if k >= 0 and k < pool.size():
				var sp: Dictionary = pool[k].duplicate(true)
				var full := String(sp.get("full_pattern", sp.pattern))
				var sl: Array = sp.get("seals", []).duplicate()
				var free := []
				for i in full.length():
					if not (i in sl):
						free.append(i)
				sl.append(free[rng.randi() % free.size()])
				var pat := ""
				for i in full.length():
					if not (i in sl):
						pat += full[i]
				sp.full_pattern = full
				sp.seals = sl
				sp.pattern = pat
				sp.size = pat.length()
				loadout[loadout.find(pool[k])] = sp
				_log("%s seals an Essence of %s for this fight." % [spell.name, sp.name])
				await anim.call({"type": "loadout_changed"})
		"unbind":
			# Unbind: cure Silence, Frozen and Ignited; heal for each of them you had
			var had := 0
			if not player.silenced.is_empty():
				had += 1
			if player.stock.any(func(s): return s.frozen):
				had += 1
			if not player.ignited.is_empty():
				had += 1
			player.silenced.clear()
			player.ignited.clear()
			for s in player.stock:
				s.frozen = false
			if had > 0 and int(eff.get("heal_per", 0)) > 0:
				player.heal(had * int(eff.heal_per))
			_log("%s cures %d debuff%s." % [spell.name, had, "" if had == 1 else "s"])
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
				await _disturb(el)
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
				for k in eff.times - 1:
					await _disturb(chant[i])
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
			# take elements out of the enemy's HP and into your elements (Instant Steal: into this turn's chant)
			for e in targets:
				var taken := []
				if eff.get("into", "") == "chant" and spoken:
					# Instant Steal: each one grabbed goes straight onto the end of the chant (an Any stays Any there)
					for i in eff.n:
						if e.is_dead() or not e.armor.has(false):
							break
						var idx: int
						if eff.get("el", "any") == "any":
							idx = await picker.call(spell, e)
						else:
							idx = await _pick_of(spell, e, eff.el)
						if idx < 0:
							break
						var got_el: String = e.pluck(idx)
						if got_el == "":
							break
						chant.append(got_el)
						_log("%s steals %s from %s into the chant." % [spell.name, Elements.NAMES[got_el], e.name])
						await anim.call({"type": "chant_changed"})
						await _disturb(got_el)
					continue
				if eff.get("el", "any") == "any":
					for i in eff.n:
						if e.is_dead() or not e.armor.has(false):
							break
						var idx: int = await picker.call(spell, e)
						var el: String = e.pluck(idx)
						if el != "":
							taken.append(el)
				else:
					for i in eff.n:  # (only that kind: you choose which)
						var idx: int = await _pick_of(spell, e, eff.el)
						if idx < 0:
							break
						taken.append(e.pluck(idx))
				for el in taken:
					var got: String = el if el != "?" else _random_element()  # a stolen Any Essence settles on one element
					if eff.get("when", "now") == "next":
						player.next_draw.append({"el": got, "temp": true})  # Soul Siphon: Conjured next turn
					else:
						player.add_element(got)
				if not taken.is_empty():
					_log("%s steals %s from %s." % [spell.name, ", ".join(taken.map(func(x): return Elements.NAMES[x])), e.name])
				await anim.call({"type": "stolen", "enemy": e, "els": taken})
		"pluck":
			for e in targets:
				for i in int(eff.n) + player.passive("snipe_bonus"):  # (Daedalus's Trigger: +1 to every Snipe)
					if e.is_dead() or not e.armor.has(false):
						break
					var idx: int
					if eff.has("el"):
						idx = await _pick_of(spell, e, eff.el)  # (Snipe 1 Fire: only Fire can be picked)
						if idx < 0:
							break
					else:
						idx = await picker.call(spell, e)
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
			if spell.get("power", false):
				player.passive_src[eff.key] = spell.id
			if eff.key == "chant_max":
				player.passives[eff.key] = eff.n if player.passive(eff.key) == eff.n * 2 else mini(player.passive(eff.key), eff.n)  # (a cap: it doesn't stack)
			if eff.key == "durability_bonus":
				for id in player.durability:  # (already worn spells get the point too)
					player.durability[id] += eff.n
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


## A Power does something: its badge shines (with a sound). By passive key, or by the Power's id.
func _proc(key: String) -> void:
	var id: String = player.passive_src.get(key, key)
	await anim.call({"type": "power_proc", "id": id})


## Steam Engine (a Power): each time you put Burn on an enemy, you gain Shield.
func _burned(times: int) -> void:
	var per := player.passive("shield_per_burn")
	if per <= 0 or times <= 0:
		return
	await _proc("shield_per_burn")
	_shield_gained(player.gain_shield(per * times))


## How many kinds of debuff you have right now (Purify's Shield counts them).
func _debuff_kinds() -> int:
	var n := 0
	for on in [player.blind_turns > 0, player.poison > 0, player.confuse_turns > 0, not player.silenced.is_empty(),
			player.frail_turns > 0, player.brittle_turns > 0, player.vulnerable > 0, player.stock.any(func(s): return s.frozen or s.hexed),
			not player.ignited.is_empty()]:
		if on:
			n += 1
	return n


## Disturbance (a Power): each Essence added to (or taken out of) the chant after you Chant knocks the same Essence
## off a random enemy that has one (an Any Essence: any Essence). Armour stops it.
func _disturb(el: String) -> void:
	if player.passive("disturbance") > 0 and not alive().is_empty():
		await _proc("disturbance")
	for k in player.passive("disturbance"):
		var cands := []
		for e in alive():
			for i in e.size():
				if not e.armor[i] and (el == "?" or e.elements[i] == el or e.elements[i] == "?"):
					cands.append([e, i])
		if cands.is_empty():
			return
		var pick: Array = cands[rng.randi() % cands.size()]
		var e: EnemyState = pick[0]
		var gone: String = e.pluck(pick[1])
		_log("Disturbance: %s loses a %s." % [e.name, Elements.NAMES.get(gone, "Essence")])
		await anim.call({"type": "strike", "enemy": e, "n": 1})
		_cleanup()


## The picker, allowed only Essence of this kind (and not armoured). -1: there's none left to take.
func _pick_of(spell: Dictionary, e: EnemyState, el: String) -> int:
	var ok := func(i: int) -> bool: return i >= 0 and i < e.size() and not e.armor[i] and e.elements[i] == el
	var any := false
	for i in e.size():
		if ok.call(i):
			any = true
			break
	if not any or e.is_dead():
		return -1
	pick_el = el
	var idx: int = await picker.call(spell, e)
	pick_el = ""
	if not ok.call(idx):
		for i in e.size():
			if ok.call(i):
				return i
	return idx


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
		"random2":
			# two different random enemies (just the one, if it's alone)
			var pool := live.duplicate()
			var out := []
			for k in mini(2, pool.size()):
				out.append(pool.pop_at(rng.randi() % pool.size()))
			return out
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
	if what in ["all", "poison"]:
		player.poison = 0
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
func _conjure(n: int, source: Dictionary, kind := "") -> void:
	if source.get("ephemeral", false) or conjuring.has(source.id):
		return
	var have := loadout.map(func(s): return String(s.get("base_id", s.id)))
	var pool: Array = db.all_spells.filter(func(s): return not s.power and not s.get("anti", false) and not (s.id in have) and not s.get("starter", false) \
		and not s.effects.any(func(e): return e.op == "conjure") and not s.get("hidden", false) and s.rarity != "unique" \
		and (kind == "" or s.kind == kind))  # (Conjure Flame: offensive spells only)
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
	trinity_cast.clear()
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
		if e.def.get("inert", false):
			continue  # (a cocoon: it just hangs there)
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
		if not ticks.burn.is_empty():
			await anim.call({"type": "dot", "enemy": e, "burn": true})
		if e.is_dead():
			_cleanup()
			continue
		if e.has_passive("overgrowth") and not e.struck_this_turn:
			e.append(_random_element())
			_log("%s grows." % e.name)
		if e.has_meta("say_first"):
			# (something it has to say before it acts: the Invoker's second wind)
			await anim.call({"type": "speech_lines", "enemy": e, "lines": e.get_meta("say_first")})
			e.remove_meta("say_first")
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
	if e.has_meta("pending_theft"):
		e.intent = e.def.moves2[0]  # the Veiled Eyes' veil just fell: the theft comes first, whatever else happened
		return
	if not e.opener.is_empty():
		e.intent = e.opener.pop_front()  # (a move it makes once, before its cycle: the Cubs' first flip)
		return
	var moves: Array = e.def.moves
	if e.is_boss and e.phase == 1 and e.size() <= int(e.def.hp.length() / 2) and not e.has_passive("yinyang_split") and not e.has_passive("hand") and not e.has_passive("handyman") and not e.has_passive("veil_falls"):
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
	for k in mini(invoke_count, pool.size()):
		var sp: Dictionary = pool.pop_at(rng.randi() % pool.size())
		sp.rarity = "rare"
		sp.rarity_name = "Rare"
		sp.power = false
		sp.effects = []
		sp.base = sp.pattern
		sp.rank = rng.randf()
		e.conjured.append(sp)
	_strip_conjured(e)
	_pick_next(e)
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
		# the card still shows his whole pattern; the Essence his words freed glow, and needn't be chanted
		sp.full_pattern = sp.base
		var lit := []
		for i in String(sp.base).length():
			if String(sp.base)[i] in e.stripped:
				lit.append(i)
		sp.lit = lit


## The spell the Invoker casts this turn whatever you chant: one he hasn't cast yet this fight (random among them), or
## any of them once he has cast them all.
func _pick_next(e: EnemyState) -> void:
	var fresh := []
	for i in e.conjured.size():
		if not (e.conjured[i].id in e.cast_ids):
			fresh.append(i)
	var pool: Array = fresh if not fresh.is_empty() else range(e.conjured.size())
	e.invoke_next = pool[rng.randi() % pool.size()] if not pool.is_empty() else -1


## Which of the Invoker's spells go off this turn: the one he chose (invoke_next), and every one your chant contains.
func invoke_picks(e: EnemyState, c: String) -> Array:
	var out := []
	for i in e.conjured.size():
		if i == e.invoke_next or _missing(String(e.conjured[i].pattern), c) == 0:
			out.append(i)
	return out


## His spell's text as it stands: its damage goes up with his Power (and down with Weaken).
static func invoker_desc(sp: Dictionary, e: EnemyState) -> String:
	if not sp.has("desc_fmt"):
		return String(sp.get("desc", ""))
	var nums := []
	for n in sp.dmg:
		nums.append(int(floorf((n + e.dmg_bonus) * e.damage_mult())))
	return String(sp.desc_fmt) % nums


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
	var picks := invoke_picks(e, heard)
	if e.invoke_all:
		e.invoke_all = false
		picks = range(e.conjured.size())  # (gold dust: all of them, whatever you chanted)
	for i in picks:
		if over or e.is_dead():
			return
		var sp: Dictionary = e.conjured[i]
		if not (sp.id in e.cast_ids):
			e.cast_ids.append(sp.id)
		_log("%s casts %s!" % [e.name, sp.name])
		await anim.call({"type": "invoke", "enemy": e, "idx": i})
		await _do_move(e, sp.cast)
	if m.has("word") and not over and not e.is_dead():
		e.stripped.append(m.word)
		_strip_conjured(e)
		_log("%s chants \"%s!\" His spells lose every %s." % [e.name, EnemyDefs.INVOKER_WORDS[m.word], Elements.NAMES[m.word]])
		await anim.call({"type": "speech", "enemy": e, "text": EnemyDefs.INVOKER_WORDS[m.word] + "!"})


## The Invoker at 0 Essence the first time: he rises again with his second row, and starts chanting.
## The Veiled Eyes at 0 Essence the first time: the veil falls and the spider underneath fights on, with its second row;
## its first move is the theft, straight away (this very enemy turn, if it fell during your Release).
func _rebirths() -> void:
	for e in enemies:
		if e.has_passive("veil_falls") and e.phase == 1 and e.is_dead():
			e.phase = 2
			e.reset_hp(String(e.def.hp2))
			e.intent = e.def.moves2[0]
			e.move_index = 1
			e.set_meta("pending_theft", true)  # (kept as its intent until the theft has happened: see _plan)
			_log("The veil falls away. Something underneath unfolds its legs.")
			anim.call({"type": "veil_falls", "enemy": e})
		if e.has_passive("invoker_rebirth") and e.phase == 1 and e.is_dead():
			e.phase = 2
			e.reset_hp(String(e.def.hp2))
			_log("%s rises again!" % e.name)
			anim.call({"type": "boss_phase"})
			e.set_meta("say_first", ["Very well, mortal.", "I have not been pushed this far in a while.", "Let me show you the pinnacle of Wizardry."])


## The Handyman: in every phase each hand has 2 lives. At 0 Essence a hand goes down: with a life left it lies there
## a turn and gets back up (the angel wings and an hourglass); out of lives it stays down. Once every hand is out of
## lives, two new hands join and the fallen ones get back up too, for the next phase. In his last stand, once every
## hand is out of lives, they go limp for good and he shows himself.
const HAND_DOWN := 2  # a fallen hand gets back up at the start of your turn after next (a turn's rest)


func _handyman_step() -> void:
	if hm.is_empty():
		return
	for e in enemies.duplicate():
		if not e.has_passive("hand") or not e.is_dead() or e.knocked:
			continue
		e.charge_dmg = -1
		e.knocked = true
		e.lives -= 1
		hm.kills += 1
		if e.lives > 0:
			_hand_down(e)
			_log("%s goes down. It will rise again." % e.name)
		else:
			e.revive_in = 0
			e.intent = {}
			_log("%s goes down, out of lives." % e.name)
	var hands := enemies.filter(func(x): return x.has_passive("hand"))
	if hm.phase < 3 and not hands.is_empty() and hands.all(func(x): return x.knocked and x.lives <= 0):
		for x in hands:
			x.lives = 2
			_hand_down(x)  # (they get back up for the next phase, after the usual rest)
		if hm.phase == 1:
			_hm_phase(2, ["hand_hammer", "hand_crossbow"], "The Handyman reaches out with two more hands!")
		else:
			_hm_phase(3, ["hand_spear", "hand_shield"], "Two last hands, a spear and a shield: the Handyman makes his last stand!")
	elif hm.phase >= 3 and not hands.is_empty() and hands.all(func(x): return x.knocked and x.lives <= 0):
		for x in hands:
			enemies.erase(x)  # (his last stand is over: they go limp for good)
		_log("Every hand goes limp for good.")
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


func _hand_down(e: EnemyState) -> void:
	e.revive_in = HAND_DOWN
	e.intent = {"kind": "revive", "left": HAND_DOWN}


## Start of your turn: fallen hands count down, and get back up whole (the Crossbow starts loading again).
func _hands_back() -> void:
	for e in enemies:
		if not e.knocked or e.revive_in <= 0:
			continue
		e.revive_in -= 1
		if e.revive_in > 0:
			e.intent = {"kind": "revive", "left": e.revive_in}
			continue
		e.knocked = false
		e.reset_hp(String(e.def.hp))
		e.move_index = 0
		_plan(e)
		_log("%s is resurrected." % e.name)
		anim.call({"type": "revive", "enemy": e})


## The Hammer Hand: it always goes for the spell it can break with the fewest hits (a tie: the one you've cast most
## this fight, then one at random). 3 hits break a spell; a spell with Durability loses 1 Durability per hit instead
## (at 0 it breaks). A smashed
## spell is removed from the fight: it leaves the row.
func _hammer(e: EnemyState) -> void:
	var cands := active_spells()
	if cands.is_empty():
		return
	var fewest := 999
	for s in cands:
		fewest = mini(fewest, _hits_to_break(s))
	var top := cands.filter(func(s): return _hits_to_break(s) == fewest)
	var most := 0
	for s in top:
		most = maxi(most, int(cast_counts.get(s.id, 0)))
	top = top.filter(func(s): return int(cast_counts.get(s.id, 0)) == most)
	if not top.any(func(s): return s.id == hammer_target):  # (a tie with the spell it's already hitting: it keeps at it)
		hammer_target = top[rng.randi() % top.size()].id
	var sp := _find_spell(hammer_target)
	var hits: int = hammer_hits.get(hammer_target, 0) + 1
	hammer_hits[hammer_target] = hits
	var smashed: bool = _wear(sp) if base_durability(sp) > 0 else hits >= 3
	if smashed:
		_break(hammer_target)
		hammered[hammer_target] = true
		_log("%s smashes %s to pieces! It's gone for the rest of the fight." % [e.name, sp.name])
	else:
		_log("%s hammers %s (%d)." % [e.name, sp.name, hits])
	await anim.call({"type": "hammer", "enemy": e, "id": hammer_target, "hits": hits, "broken": smashed})


## How many more Hammer hits break this spell: its Durability left, or 3 minus the hits it has taken.
func _hits_to_break(s: Dictionary) -> int:
	if base_durability(s) > 0 or player.durability.has(s.id):
		return maxi(1, durability_left(s))
	return maxi(1, 3 - int(hammer_hits.get(s.id, 0)))


## Talking to a boss: an option that costs an Essence takes one from your bag (the fight gets harder).
func talk_pay(cost: String) -> bool:
	if talk_free:
		return true
	if not can_talk_pay(cost):
		return false
	for el in cost:
		for s in player.stock:
			if s.el == el and not s.temp:
				player.stock.erase(s)
				talk_spent.append(el)
				break
	return true


func can_talk_pay(cost: String) -> bool:
	if talk_free:
		return true
	for el in ["F", "W", "A"]:
		if cost.count(el) > player.stock.filter(func(s): return s.el == el and not s.temp).size():
			return false
	return true


## An effect of something said (see BossTalk). None yet: the boss conversations are being rewritten.
func talk_effect(fx: String) -> void:
	if fx.begins_with("win_artifact:"):
		talk_rewards.append(fx.get_slice(":", 1))
		return
	push_warning("talk effect not implemented: %s" % fx)


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
	var taken_items: Array = []  # a steal: [{uid, el}] of the Essence it took from your bag (for the animation)
	match m.kind:
		"attack":
			if e.disarmed > 0:
				_log("%s is Disarmed: its attack does nothing." % e.name)
				await anim.call({"type": "mend", "enemy": e})
				return
			for h in m.get("hits", 1):
				if e.dazed > 0 and rng.randf() < 0.5:
					e.dazed -= 1  # Dazed: it misses (and is a little less dazed)
					_log("%s is Dazed and misses!" % e.name)
					await anim.call({"type": "attack", "enemy": e, "n": 0, "blocked": true, "part": e.acting_part})
					continue
				if player.passive("thorns_on_hit") > 0:
					player.passives["thorns"] = player.passive("thorns") + player.passive("thorns_on_hit")  # EleMantle
					await _proc("thorns_on_hit")
				var dmg: float = floorf((m.n + e.dmg_bonus) * e.damage_mult())
				if m.get("laser", false) and h == 0:
					await anim.call({"type": "laser", "enemy": e})  # (its eyes fire: the beam lands with the hit below)
				var shield_before := player.shield + player.lasting
				var aegis_before := player.aegis
				var lost := player.take_attack(dmg)
				var blocked := player.aegis < aegis_before or player.shield + player.lasting < shield_before
				_log("%s attacks for %d." % [e.name, lost])
				await anim.call({"type": "attack", "enemy": e, "n": lost, "blocked": blocked, "part": e.acting_part})
				if lost > 0.0 and e.has_passive("envenomed"):
					player.poison += 1  # Envenomed: only a hit that takes HP (Shield stopping it all doesn't count)
					_log("%s's venom gets in: Poison +1." % e.name)
				var th := player.thorns_turn + player.passive("thorns")
				if th > 0 and not player.ethereal:
					e.remove_right(th)
					await anim.call({"type": "thorns_proc"})
				_check_end()
				if over or e.is_dead():
					break
		"grow_thorns":
			e.thorns += int(m.n)
			_log("%s curls up tighter: Thorns %d." % [e.name, e.thorns])
			await anim.call({"type": "effect", "op": "thorns", "targets": [e]})
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
				taken_items.append({"uid": s.uid, "el": s.el})
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
		"poison":
			player.poison += m.n
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
		"steal_spell":
			e.remove_meta("pending_theft")
			await _steal_spell(e)
		"summon":
			for i in m.n:
				if alive().size() < MAX_ENEMIES:
					var sid: String = m.list[i % m.list.size()] if m.has("list") else (m.id if m.has("id") else m.ids[rng.randi() % m.ids.size()])
					var add := _spawn(sid)
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
		await anim.call({"type": "enemy_move", "enemy": e, "kind": m.kind, "move": m, "items": taken_items})
	if m.has("also") and not over and not e.is_dead():
		await _do_move(e, m.also)


## The Veiled Eyes' theft: it is pulled up out of sight, drops in front of you, takes one of your spells at random,
## is pulled up again and comes back with a cocoon (an enemy of its own, 3 Essence) with the spell wrapped inside.
## Break the cocoon and the spell comes back (where it was in your row); win the fight and it comes back anyway.
func _steal_spell(e: EnemyState) -> void:
	var cands := active_spells().filter(func(x): return not x.get("ephemeral", false))
	if cands.is_empty() or alive().size() >= MAX_ENEMIES:
		_log("%s reaches for your spells, but finds nothing to take." % e.name)
		return
	var sp: Dictionary = cands[rng.randi() % cands.size()]
	var at := loadout.find(sp)
	await anim.call({"type": "spider_steal", "enemy": e, "spell": sp})
	loadout.remove_at(at)
	charges.erase(sp.id)
	player.silenced.erase(sp.id)
	player.locks.erase(sp.id)
	var cocoon := _spawn("spider_cocoon")
	cocoon.set_meta("held", {"spell": sp, "at": at})
	cocoon.fresh = true
	_plan(cocoon)
	_log("%s steals %s and wraps it in a cocoon. Break the cocoon to get it back!" % [e.name, sp.name])
	await anim.call({"type": "loadout_changed"})
	await anim.call({"type": "spawn", "enemy": cocoon})
	await anim.call({"type": "spider_return", "enemy": e})  # (the cocoon is let down first, then the spider comes back down)


## A cocoon broken (or the fight won): its spell goes back into your row, where it was.
func _free_cocooned(c: EnemyState) -> void:
	if not c.has_meta("held"):
		return
	var h: Dictionary = c.get_meta("held")
	c.remove_meta("held")
	loadout.insert(clampi(int(h.at), 0, loadout.size()), h.spell)
	_log("The cocoon tears open: %s is yours again." % h.spell.name)
	anim.call({"type": "loadout_changed"})


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
		if e.is_dead() and e.has_passive("armadillo"):
			# the Anxious Armadillo stays on the list, beaten: the screen plays his ending before the victory
			if not (e.id in defeated):
				defeated.append(e.id)
				_log("%s is defeated." % e.name)
			continue
		if e.is_dead() and not e.knocked:
			enemies.erase(e)
			_free_cocooned(e)
			if e.has_passive("veil_falls") and e.phase == 2:
				# the spider is dead: its spiderlings scatter and its cocoons fall open (your spells come back)
				for x in enemies.duplicate():
					if x.id in ["spiderling_a", "spiderling_b", "spider_cocoon"]:
						_free_cocooned(x)
						x.elements.clear()
						x.armor.clear()
						enemies.erase(x)
				_log("With the spider dead, its brood scatters.")
			if e.is_boss:
				anim.call({"type": "boss_defeat"})
			if not (e.id in defeated):
				defeated.append(e.id)
			if e.has_passive("briar_walls") and not e.elements.is_empty():
				_log("The walls fall with her.")
			if e.has_passive("last_gasp"):
				player.poison += 2
				_log("%s bursts: you are poisoned." % e.name)
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
