class_name Fight
extends RefCounted
## One encounter. UI-agnostic: the screen (or the balance sim) supplies these async callbacks:
##   chooser:     (spell, candidates: Array[int]) -> int        target enemy, when one wasn't given up front
##   mover:       (spell, enemy) -> [from, to]                   Move: rearrange an enemy's HP ([] skips)
##   picker:      (spell, enemy) -> int                          Pluck: which HP element to remove
##   redirector:  (spell, source, candidates) -> int             Misdirection: who the intent hits instead
##   placer:      (spell, el) -> int                             Infuse: where in the chant the element goes
##   chant_picker:(spell) -> int                                 Resonance: which chant element to copy
##   anim:        (event: Dictionary) -> void                    animation hook
##
## Your turn:
##   1. cast_chant(): the chant is spoken. Every spell whose pattern appears gains charges: one per separate
##      match, but never more than the length of its pattern (WW can trigger at most twice).
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
const AT_PLAYER := ["silence", "lock", "steal", "confuse", "blind", "bleed", "freeze", "toll", "invert", "hex", "mimic", "frail"]

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
var used := {}  # spell id -> triggers used this turn
var charges := {}  # spell id -> triggers left right now
var turn_ctx := {}  # {entries, amplify, echo, retain, last, cast_any}

var chooser: Callable
var mover: Callable
var picker: Callable
var redirector: Callable
var placer: Callable
var chant_picker: Callable
var anim: Callable


func _init(p_db: SpellDB, p_player: PlayerState) -> void:
	db = p_db
	player = p_player
	chooser = func(_s, cands): return cands[0]
	mover = func(_s, _e): return []
	picker = func(_s, e): return e.armor.find(false)
	redirector = func(_s, src, _cands): return enemies.find(src)
	placer = func(_s, _el): return chant.size()
	chant_picker = func(_s): return 0
	anim = func(_e): pass


func has_artifact(id: String) -> bool:
	return id in artifacts


# ------------------------------------------------------------------ setup

func start(enemy_ids: Array, p_act: int, p_depth: int) -> void:
	act = p_act
	depth = p_depth
	player.reset_fight()
	enemies.clear()
	for id in enemy_ids:
		_spawn(id)
	if has_artifact("thornbark"):
		player.passives["thorns"] = 1
	if has_artifact("venom_gland"):
		player.passives["poison_bonus"] = 1
	if has_artifact("chant_bell"):
		player.passives["echo_first"] = 1
	if has_artifact("rain_chalice"):
		player.shield += 4.0
	if has_artifact("iron_bark"):
		player.shield += 2.0
	if has_artifact("ward_stone"):
		player.aegis = 1
	player.dmg_taken_mult = 1.25 if has_artifact("glass_heart") else 1.0
	var start_n := PlayerState.START_ELEMENTS + (1 if has_artifact("wind_chime") else 0) - (2 if has_artifact("broken_crown") else 0)
	for i in maxi(1, start_n):
		player.add_element(_random_element())
	if has_artifact("ember_charm"):
		player.add_element("F")
	_roll_next_draw(2)
	turn = 1
	for e in enemies:
		_plan(e)
	_log("The fight begins.")


func _spawn(id: String) -> EnemyState:
	var d := EnemyDefs.get_def(id)
	var e := EnemyState.new()
	e.setup(d, EnemyDefs.extra_hp(act, depth, rng, d.get("boss", false)))
	e.dmg_bonus = EnemyDefs.attack_bonus(act) + (1 if has_artifact("withered_idol") else 0)
	enemies.append(e)
	return e


func alive() -> Array:
	return enemies.filter(func(e): return not e.is_dead())


func active_spells() -> Array:
	return loadout.filter(func(s): return not player.used_powers.has(s.id))


## Spells that can fire this turn (not silenced, not locked, not a spent Power).
func usable_spells() -> Array:
	return active_spells().filter(func(s): return not player.silenced.has(s.id) and not player.locks.has(s.id))


## The most times a spell can trigger in one turn: the length of its pattern (Powers: once).
func trigger_cap(spell: Dictionary) -> int:
	if spell.power:
		return 1
	return spell.size + (1 if has_artifact("hungry_tome") else 0)


func chant_string() -> String:
	return "".join(chant)


func _log(s: String) -> void:
	lines.append(s)


# ------------------------------------------------------------------ draws

## One random element, weighted by lenses (a lens doubles its element's odds).
func _random_element() -> String:
	var w := {"F": 1.0, "W": 1.0, "A": 1.0}
	for lens in LENSES:
		if has_artifact(lens):
			w[LENSES[lens]] += 1.0
	var r: float = rng.randf() * (w.F + w.W + w.A)
	for el in ["F", "W", "A"]:
		if r < w[el]:
			return el
		r -= w[el]
	return "A"


## Rolls the draw you receive at the start of turn `upcoming` (shown in "Coming next").
func _roll_next_draw(upcoming: int) -> void:
	player.next_draw.clear()
	if not script_draws.is_empty():
		for ch in String(script_draws.pop_front()):
			player.next_draw.append({"el": ch, "temp": false})
		return
	var n := PlayerState.BASE_DRAW - player.overload
	if has_artifact("second_wind") and player.hp < player.max_hp / 2.0:
		n += 1
	if has_artifact("heartwood_seed"):
		n += 1
	if has_artifact("blood_pact"):
		n += 2
	if has_artifact("withered_idol"):
		n += 1
	if has_artifact("lucky_acorn") and rng.randf() < 0.25:
		n += 1
	player.overload = 0
	var attune := player.passive("attune")
	for i in maxi(0, n):
		var el := _random_element()
		if i == 0 and attune > 0:
			el = player.passives.get("attune_el", el)
		player.next_draw.append({"el": el, "temp": false})
	for h in HEARTS:
		if has_artifact(h):
			player.next_draw.append({"el": HEARTS[h], "temp": false})
	if upcoming == 3:
		for em in EMBLEMS:
			if has_artifact(em):
				for i in 3:
					player.next_draw.append({"el": EMBLEMS[em], "temp": false})


## Start of your turn (not the first): bleed, receive the previewed draw, Powers tick.
func begin_player_turn() -> void:
	if player.bleed > 0:
		player.take_effect(player.bleed)
		_log("You bleed for %d." % player.bleed)
		player.bleed -= 1
		await anim.call({"type": "bleed_tick"})
	if has_artifact("mending_moss"):
		player.heal(1)
	player.shield = 0.0
	player.thorns_turn = 0
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
		var n: int = k - armored + (1 if e.is_exposed() else 0) + extra
		removed[e] = k
		if n >= e.size():
			dies.append(e)
	var spells := {}
	for s in usable_spells():
		var cnt: int = mini(Chant.occurrences(s.pattern, c).size(), trigger_cap(s)) - (used.get(s.id, 0) if not raw else 0)
		if cnt > 0:
			spells[s.id] = cnt
	return {"removed": removed, "dies": dies, "spells": spells}


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
	turn_ctx = {"entries": entries, "amplify": 0, "echo": 0, "retain": 0, "last": {}, "cast_any": false}
	if has_artifact("kindling_stone") and not player.kindling_charged:
		player.kindling_chants += 1
		if player.kindling_chants >= 3:
			player.kindling_chants = 0
			player.kindling_charged = true
			_log("Kindling Stone is charged: your next Burn is doubled.")
	await anim.call({"type": "chant", "chant": c})
	await _recount()
	if not charges.is_empty():
		await anim.call({"type": "charged"})


## Re-read the chant: locks it now contains break, and every spell's charges are counted again.
func _recount() -> void:
	var c := chant_string()
	for sid in player.locks.keys():
		if Chant.breaks_lock(player.locks[sid], c):
			player.locks.erase(sid)
			_log("A lock shatters!")
			await anim.call({"type": "unlock", "spell": sid})
	charges.clear()
	for sp in usable_spells():
		var n: int = mini(Chant.occurrences(sp.pattern, c).size(), trigger_cap(sp)) - used.get(sp.id, 0)
		if n > 0:
			charges[sp.id] = n


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
	var times := 1
	if not turn_ctx.get("cast_any", false) and player.passive("echo_first") > 0 and not spell.power:
		times = 2
	turn_ctx.cast_any = true
	for t in times:
		if over:
			break
		var tctx := {}
		if target_idx >= 0 and target_idx < enemies.size() and not enemies[target_idx].is_dead():
			tctx.target = enemies[target_idx]
		await _fire(spell, turn_ctx, tctx)
	await _recount()


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
			var pos := c.find(sp.pattern)
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
	if spoken and not chant.is_empty():
		var c := chant_string()
		last_chant = c
		if not charges.is_empty():
			_log("Unused charges fizzle.")
		charges.clear()
		var hit := await _strike(c)
		var amp: int = turn_ctx.get("amplify", 0)
		if amp > 0:
			for e in hit:
				if not e.is_dead():
					e.remove_right(amp)
			await anim.call({"type": "amplify"})
		for i in turn_ctx.get("echo", 0):
			if over:
				break
			_log("Echo! The chant is Released again.")
			await _strike(chant_string())
		var keep: int = turn_ctx.get("retain", 0)
		for el in chant.slice(maxi(0, chant.size() - keep)):
			player.add_element(el)
		_cleanup()
	if not over:
		await end_player_turn()


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
		var at := c.find("".join(e.elements.slice(0, k)))
		plans.append({"enemy": e, "k": k, "at": at})
	if plans.is_empty():
		return []
	for p in c.length():
		var hits := []
		for pl in plans:
			if p >= pl.at and p < pl.at + pl.k:
				hits.append([pl.enemy, p - pl.at])
		await anim.call({"type": "chant_step", "pos": p, "hits": hits, "chant": c})
	var hit := []
	var extra := 1 if has_artifact("glass_heart") else 0
	for pl in plans:
		var e: EnemyState = pl.enemy
		var before: int = e.size()
		var removed: Array = e.strike_prefix(pl.k)
		if e.is_exposed() and not e.is_dead():
			removed.append_array(e.remove_right(1))
		if extra > 0 and not e.is_dead():
			removed.append_array(e.remove_right(extra))
		e.struck_this_turn = true
		hit.append(e)
		if player.passive("strike_poison") > 0:
			e.poison += player.passive("strike_poison") + player.passive("poison_bonus")
		if player.passive("strike_burn") > 0:
			e.burn += _burn_amount(player.passive("strike_burn") + player.passive("burn_bonus"))
		if e.has_passive("burning_hide"):
			player.take_effect(1.0)
			_log("%s's burning hide scorches you." % e.name)
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
	e.def.split_done = true
	enemies.insert(enemies.find(e) + 1, twin)
	_plan(twin)
	_log("%s splits in two!" % e.name)
	anim.call({"type": "spawn", "enemy": twin})


func _fire(spell: Dictionary, ctx: Dictionary, tctx: Dictionary) -> void:
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
	if spell.power:
		player.used_powers[spell.id] = true
		_log("%s takes hold for the rest of the fight." % spell.name)
	ctx.last = spell
	_cleanup()


## Resolves one effect. tctx caches the chosen target for this spell.
func _apply(eff: Dictionary, spell: Dictionary, tctx: Dictionary, ctx := {}) -> void:
	var targets := await _targets(eff, spell, tctx)
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
				if eff.from == "right":
					e.remove_right(n)
				else:
					e.remove_left(n)
		"burn":
			var amount := _burn_amount(eff.n + player.passive("burn_bonus")) if not targets.is_empty() else 0
			for e in targets:
				e.burn += amount
		"poison":
			for e in targets:
				e.poison += eff.n + player.passive("poison_bonus")
		"stoke":
			for e in targets:
				e.burn *= 2
		"weak":
			for e in targets:
				e.weak_turns = maxi(e.weak_turns, eff.turns)
		"freeze":
			for e in targets:
				if not e.is_boss:
					e.freeze_turns = maxi(e.freeze_turns, eff.turns)
		"expose":
			for e in targets:
				e.expose_turns = maxi(e.expose_turns, eff.turns)
		"ethereal":
			if eff.target == "self":
				player.ethereal = true
			else:
				for e in targets:
					e.phased = true
		"shield":
			player.shield += eff.n
		"heal":
			player.heal(eff.n)
		"aegis":
			player.aegis += eff.n
		"thorns":
			player.thorns_turn += eff.n
		"draw":
			for i in eff.n:
				var el: String = _random_element() if eff.get("el", "random") == "random" else eff.el
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
		"transmute":
			var changed := 0
			for s in player.stock:
				if changed < eff.n and s.el != eff.to and not s.frozen:
					s.el = eff.to
					changed += 1
		"sacrifice":
			player.take_effect(eff.hp)
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
			if spoken:
				var pos: int = await placer.call(spell, eff.el)
				chant.insert(clampi(pos, 0, chant.size()), eff.el)
				_log("%s adds %s to the chant." % [spell.name, Elements.NAMES[eff.el]])
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
			player.passives[eff.key] = player.passive(eff.key) + eff.n
			if eff.key == "attune":
				player.passives["attune_el"] = _favourite_element()
		"curse":
			for e in targets:
				match eff.key:
					"no_mend":
						e.no_mend = true
					"exposed":
						e.expose_perm = true
					"weak25":
						e.weak25 = true
		"each_turn":
			player.each_turn.append({"spell": spell, "effects": eff.effects})
	await anim.call({"type": "effect", "op": eff.op, "targets": targets})


## Burn you apply; a charged Kindling Stone doubles it once (one whole effect, even if it hits every enemy).
func _burn_amount(n: int) -> int:
	if player.kindling_charged and has_artifact("kindling_stone"):
		player.kindling_charged = false
		_log("Kindling Stone flares: Burn doubled.")
		return n * 2
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
		"all":
			return live
		"random":
			return [live[rng.randi() % live.size()]]
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
			c[ch] += 1
	var best := "F"
	for el in c:
		if c[el] > c[best]:
			best = el
	return best


# ------------------------------------------------------------------ enemy phase

func end_player_turn() -> void:
	charges.clear()
	used.clear()
	turn_ctx = {}
	chant.clear()
	spoken = false
	for e in alive():
		if e.expose_turns > 0:
			e.expose_turns -= 1
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
	if player.blind_turns == 0:
		blind_masks.clear()
	await _enemy_phase()
	player.ethereal = false
	player.frail_turns = maxi(0, player.frail_turns - 1)
	if over:
		return
	turn += 1
	for e in alive():
		_plan(e)
	await anim.call({"type": "intents_shown"})
	await begin_player_turn()


func _enemy_phase() -> void:
	for e in enemies.duplicate():
		if over:
			return
		if e.is_dead():
			continue
		var ticks: Dictionary = e.begin_turn()
		if not ticks.burn.is_empty() or not ticks.poison.is_empty():
			await anim.call({"type": "dot", "enemy": e, "burn": not ticks.burn.is_empty(), "poison": not ticks.poison.is_empty()})
		if e.is_dead():
			_cleanup()
			continue
		if e.has_passive("overgrowth") and not e.struck_this_turn:
			e.append(_random_element())
			_log("%s grows." % e.name)
		if e.freeze_turns > 0:
			_log("%s is frozen." % e.name)
		else:
			await _do_move(e, e.intent)
			if e.has_passive("echo") and not over:
				await _do_move(e, e.intent)
		e.redirect_to = null
		if e.has_passive("gem_crown") and not e.armor.has(true) and e.size() > 1:
			e.set_armor(0)
		e.end_turn()
		_cleanup()
		_check_end()


## Moves are used strictly in the listed order, looping (a boss switches to its second list at half HP).
func _plan(e: EnemyState) -> void:
	var moves: Array = e.def.moves
	if e.is_boss and e.phase == 1 and e.size() <= int(e.def.hp.length() / 2):
		e.phase = 2
		e.move_index = 0
		_log("%s grows desperate!" % e.name)
		anim.call({"type": "boss_phase"})
	if e.phase == 2 and e.def.has("moves2"):
		moves = e.def.moves2
	e.intent = moves[e.move_index % moves.size()]
	e.move_index += 1


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
				var lost := player.take_attack(dmg)
				_log("%s attacks for %d." % [e.name, lost])
				await anim.call({"type": "attack", "enemy": e, "n": lost})
				var th := player.thorns_turn + player.passive("thorns")
				if th > 0 and not player.ethereal:
					e.remove_right(th)
					await anim.call({"type": "thorns_proc"})
				_check_end()
				if over or e.is_dead():
					break
		"armor":
			e.set_armor(mini(m.pos, e.size() - 1))
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
			for t in targets:
				for i in m.n:
					t.append(_random_element() if m.el == "random" else m.el)
			await anim.call({"type": "mend", "enemy": e})
		"shuffle":
			e.rotate_left()
		"silence":
			var cands := usable_spells()
			if not cands.is_empty():
				var s: Dictionary = cands[rng.randi() % cands.size()]
				player.silenced[s.id] = m.turns
				_log("%s silences %s." % [e.name, s.name])
				await anim.call({"type": "silence"})
		"lock":
			var cands := active_spells().filter(func(s): return not player.locks.has(s.id))
			if not cands.is_empty():
				var s: Dictionary = cands[rng.randi() % cands.size()]
				var n: int = m.len - (1 if has_artifact("lock_pick") else 0)
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
			_log("%s steals your elements onto its hide." % e.name)
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
		"freeze":
			var free := player.stock.filter(func(s): return not s.frozen)
			free.shuffle()
			for s in free.slice(0, m.n):
				s.frozen = true
			await anim.call({"type": "freeze_stock"})
		"ethereal":
			e.ethereal = true
		"empower":
			e.dmg_bonus += m.n
		"summon":
			for i in m.n:
				if alive().size() < MAX_ENEMIES:
					var add := _spawn(m.id)
					_plan(add)
					await anim.call({"type": "spawn", "enemy": add})
		"toll":
			player.toll = 2
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
	if m.has("also") and not over and not e.is_dead():
		await _do_move(e, m.also)


# ------------------------------------------------------------------ bookkeeping

func _cleanup() -> void:
	for e in enemies.duplicate():
		if e.is_dead():
			enemies.erase(e)
			if e.is_boss:
				anim.call({"type": "boss_defeat"})
			if not (e.id in defeated):
				defeated.append(e.id)
			if e.has_passive("last_gasp"):
				player.bleed += 2
				_log("%s bursts: you bleed." % e.name)
			_log("%s is defeated." % e.name)
	_check_end()


func _check_end() -> void:
	if over:
		return
	if player.is_dead():
		over = true
		won = false
	elif alive().is_empty():
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
