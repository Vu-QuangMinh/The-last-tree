class_name MarbleBridge
extends Fight
## The main game's fight screen (FightScreen) running the new rules (2026-11-22, the user: "the exact same physic and
## layout as the old main game mode, just with the new cards and new enemy behavior").
##
## The screen stays exactly as it was: the puppets on their ropes, the intent signs, the marbles rolling into the Bag
## strip, the chant rings, the cards, the spell effects and the hit reactions. Underneath, this Fight hands every action
## to MarblesFight (the new cards, the marbles' rules, the new enemies' moves) and plays what happened back to the
## screen as the old Fight's own events (spell, spell_effect, effect, enemy_turn, attack, enemy_move...). Each new event
## carries the numbers as they were at that moment (StageFight.snapshots), so every bar drops when its blow lands.
##
## Mirrors kept in step: player (HP, Shield, Burn...), player.stock (the marbles in the storage row, by their uid),
## enemies (each Foe's EnemyState, with "hp" / "max_hp" / "shield" / "statuses" metas: EnemyView draws an HP bar),
## loadout (one spell dict per card, its id unique), charges / used / cooldowns / silenced / broken.

var m: MarblesFight
var mrun: MarblesRun
var rs: RunState
var _sid: Array = []  # card index -> the spell id the screen knows it by
var _note_evs := {}  # chant place -> the events of that marble's carving (played when the screen reads it: on_note)
var _hold_text := false  # (while the chant's carvings play: a card's words change only when its boost line lands)


func _init(p_db: SpellDB, p_player: PlayerState) -> void:
	super(p_db, p_player)
	no_release = true  # (after the chant: cast the awake cards; the turn ends when they are all cast, or on Pass)


## Takes over from the old Fight the run made (its rng, artifacts) and starts the new fight.
func begin(p_rs: RunState, ids: Array, old: Fight) -> void:
	rs = p_rs
	rng.seed = old.rng.seed
	artifacts = old.artifacts
	artifact_plus = old.artifact_plus
	act = old.act
	depth = old.depth
	player.reset_fight()
	mrun = rs.marble_run()
	m = MarblesFight.new()
	m.snapshots = true
	m.setup(mrun, rs.marble_ids(ids))
	m.events.clear()
	turn = 1
	_build_loadout()
	_b_show(m.snap())
	_b_sync()


## The loadout board can change your active cards after the fight was made (main._begin_stage_fight): take them
## again before the first turn.
func reload_cards() -> void:
	var mr2 := rs.marble_run()
	for k in ["cards", "backpack", "levels", "perm", "fused", "patterns", "mods"]:
		mrun.set(k, mr2.get(k))
	_build_loadout()
	_b_sync()


func _build_loadout() -> void:
	loadout.clear()
	_sid.clear()
	var seen := {}
	for ci in mrun.cards.size():
		var c := m.card(ci)
		var d := MarbleCardView.spell_of(c)
		var id := String(d.id) if String(d.id) != "" else "card"
		while seen.has(id):
			id += "+"
		seen[id] = true
		d.id = id
		var fx := MarblesFight.fx_of(c)
		var tgt := "target" if m.needs_target(ci) else ("self" if String(fx.to) == "you" else "all")
		d.effects = [{"op": String(fx.op), "n": int(fx.n), "target": tgt}]
		d["ci"] = ci
		d["live_text"] = true  # (its words can change in the fight: Water Gun's X, Durability left...)
		_sid.append(id)
		loadout.append(d)
	spellbook = loadout.duplicate()


func _ci(id: String) -> int:
	return _sid.find(id)


# ------------------------------------------------------------------ mirrors

## The numbers of one moment (StageFight.snap) onto the player and the enemies the screen draws.
func _b_show(s: Dictionary) -> void:
	if s.is_empty():
		return
	player.hp = float(s.hp)
	player.max_hp = float(s.max_hp)
	player.shield = float(s.block)
	player.lasting = 0.0
	player.burn = int(s.burn)
	player.vulnerable = int(s.vulnerable)
	player.weak = int(s.get("weak", 0))
	player.stun_turns = int(s.stunned)
	var fs: Array = s.foes
	for i in mini(fs.size(), m.foes.size()):
		var f: StageFight.Foe = m.foes[i]
		var es: EnemyState = f.es
		if not (es in enemies):
			enemies.append(es)
		var d: Dictionary = fs[i]
		es.set_meta("hp", int(d.hp))
		es.set_meta("max_hp", int(d.max_hp))
		es.set_meta("shield", int(d.block))
		es.power = int(d.power)
		es.weak_turns = int(d.weak)
		es.stun_turns = int(d.stun)
		es.thorns = int(d.thorns)
		es.intent = (d.intent as Dictionary).duplicate(true) if int(d.hp) > 0 else {}
		es.set_meta("statuses", _status_words(d))


static func _status_words(d: Dictionary) -> Array:
	var out := []
	for pair in [["burn", "Burn %d"], ["weak", "Weakened %d"], ["vulnerable", "Vulnerable %d"], ["expose", "Expose %d"],
			["armor", "Armor %d"], ["thorns", "Thorns %d"], ["power", "Power %d"], ["dodge", "Dodge %d"]]:
		if int(d.get(pair[0], 0)) > 0:
			out.append(String(pair[1]) % int(d[pair[0]]))
	if int(d.get("fly", 0)) > 0:
		out.append("Flying %d (in the air every hit on it deals only 1; %d more hit%s and it falls)" % [int(d.fly), int(d.fly), "" if int(d.fly) == 1 else "s"])
	if int(d.get("stun", 0)) > 0:
		out.append("Stunned")
	if int(d.get("ethereal", 0)) > 0:
		out.append("Ethereal")
	return out


## Cards, the chant and your storage row as they are now.
func _b_sync() -> void:
	charges.clear()
	used.clear()
	player.cooldowns.clear()
	player.silenced.clear()
	player.used_powers.clear()
	broken.clear()
	hammer_hits.clear()
	for ci in _sid.size():
		var id: String = _sid[ci]
		var now_text := MarbleCards.with_durability(String(m.card(ci).get("text", "")), m.durability_left(ci) if m.card(ci).p.has("dur") else -1)
		if not _hold_text and not m.card(ci).has("parts") and now_text != "" and String(loadout[ci].desc) != now_text:
			loadout[ci].desc = now_text  # (a number on the card changed: Knivel's Innocence)
		if int(m.charges.get(ci, 0)) > 0:
			charges[id] = int(m.charges[ci])
		if int(m.casts.get(ci, 0)) > 0:
			used[id] = int(m.casts[ci])
		if m.cooldown.has(ci):
			player.cooldowns[id] = int(m.cooldown[ci])
		if m.silenced.has(ci) or m.cocooned.has(ci):
			player.silenced[id] = 1
		if m.power_used.has(ci):
			player.used_powers[id] = true
		if int(m.hammered.get(ci, 0)) > 0:
			hammer_hits[id] = int(m.hammered[ci])
		if int(m.hammered.get(ci, 0)) >= StageFight.HAMMER_BREAKS or m.durability_left(ci) == 0:
			broken[id] = true
	chant.clear()
	chant_syms.clear()
	for c in m.chant_letters():
		chant.append("?" if c == "*" else String(c))
	for cm in m.chant:
		chant_syms.append(String(cm.get("sym", "")))
	player.stock.clear()
	for mm in m.hand:
		var star := String(mm.get("sym", "")) == "star"
		# (the Mirror Fairy's Blind is an illusion on the slot machine only: what comes out is your own marbles, shown as
		# they are, the user 2026-11-22)
		player.stock.append({"el": "?" if star else String(mm.get("c", "F")), "sym": String(mm.get("sym", "")), "temp": false,
			"frozen": bool(mm.get("frozen", false)), "freeze_n": 0, "uid": int(mm.get("uid", 0)) + 100000})
	player.blind_turns = 1 if m.alive().any(func(x): return x.id in MarblesFight.BLINDERS) else 0  # (Blind: the reels show "?")
	player.bottles = mrun.bottles
	player.next_draw.clear()  # (next turn's marbles: the slot machine's reels show them)
	for nm in m.next_draw_known():
		player.next_draw.append({"el": "?" if String(nm.get("sym", "")) == "star" else String(nm.get("c", "F")), "sym": String(nm.get("sym", "")), "temp": false})
	turn = m.turn


# ------------------------------------------------------------------ the screen asks

func durability_left(spell: Dictionary) -> int:
	var ci := _ci(String(spell.get("id", "")))
	return m.durability_left(ci) if ci >= 0 else -1


func durability_max(spell: Dictionary) -> int:
	var ci := _ci(String(spell.get("id", "")))
	return int(m.card(ci).p.get("dur", -1)) if ci >= 0 else -1


func target_candidates() -> Array:
	var out := []
	for i in m.targets(-1):
		if int(i) < enemies.size():
			out.append(int(i))
	return out


func preview(c: String, _raw := true) -> Dictionary:
	var spells := {}
	for ci in _sid.size():
		if not m.usable(ci):
			continue
		var pat := String(loadout[ci].pattern)
		var n := Chant.occurrences(pat, c).size() if pat != "" else (1 if c != "" else 0)
		if n > 0:
			spells[_sid[ci]] = n
	return {"removed": {}, "dies": [], "spells": spells, "invoke": {}}


func has_valid_move() -> bool:
	return not over and not charges.is_empty()


# ------------------------------------------------------------------ your turn

func cast_chant(stock_indices: Array) -> void:
	if over or stock_indices.is_empty() or m.chanted:
		return
	var picked := []
	for i in stock_indices:
		if int(i) < m.hand.size():
			picked.append(m.hand[int(i)])
	for mm in picked:
		m.hand.erase(mm)
	m.chant.clear()
	m.chant.append_array(picked)
	m.do_chant()
	spoken = true
	var evs := []
	_note_evs.clear()
	for e in _b_take():
		if e.has("note"):  # (a carving: it plays when the reading gets to its marble)
			if not _note_evs.has(int(e.note)):
				_note_evs[int(e.note)] = []
			_note_evs[int(e.note)].append(e)
		else:
			evs.append(e)
	_hold_text = true
	_b_sync()
	# (the numbers carvings change show as each one is read: show the state before them first)
	if not _note_evs.is_empty():
		var first: Dictionary = _note_evs[_note_evs.keys().min()][0]
		if first.has("_snap"):
			_b_show(first._snap)
	await anim.call({"type": "chant", "chant": chant_string()})
	var hits := []
	for ci in _sid.size():
		var n := int(m.charges.get(ci, 0))
		if n <= 0:
			continue
		var pat := String(loadout[ci].pattern)
		var starts: Array = Chant.occurrences(pat, chant_string()) if pat != "" else []
		hits.append({"id": _sid[ci], "starts": starts.slice(0, n), "len": pat.length()})
	await anim.call({"type": "charged", "hits": hits})
	await _b_play(evs, false)
	_hold_text = false
	_b_after()


func resolve_spell(id: String, target_idx := -1) -> void:
	var ci := _ci(id)
	if ci < 0 or not m.can_cast(ci):
		return
	m.cast(ci, target_idx)
	if m.pending_replace >= 0:
		m.replace_with(-1)  # (Alchemy, Random Things Go!: it stays as it is for now)
	await _b_play(_b_take(), false)
	_b_sync()
	_b_after()


func use_bottle(i: int, target_idx := -1) -> void:
	if over or i < 0 or i >= mrun.bottles.size():
		return
	var it := MarbleItems.bottle(String(mrun.bottles[i]))
	m.use_bottle(i, target_idx)
	await anim.call({"type": "bottle", "bottle": {"name": String(it.get("name", "Bottle"))}})
	await _b_play(_b_take(), false)
	_b_sync()
	_b_after()


func pass_turn() -> void:
	await finish_turn()


## Your turn ends (Release / Pass): the enemies act one by one, then your next turn starts (new marbles roll in).
func finish_turn() -> void:
	if over:
		return
	var before := {}
	for es in enemies:
		before[es] = es.intent.duplicate(true)
	m.end_turn()
	await _b_play(_b_take(), true, before)
	_b_show(m.snap())
	_b_sync()
	spoken = false
	if not over:
		await anim.call({"type": "intents_shown"})
	_b_after()


## The screen reads the spoken chant left to right (FightScreen._sing): marble i is read now. Its carving works: the
## reading waits while it plays.
func on_note(i: int) -> void:
	if not _note_evs.has(i):
		return
	var evs: Array = _note_evs[i]
	_note_evs.erase(i)
	await _b_play(evs, false, {}, false)
	_b_show(_note_state(i))


## The numbers once marble i's carving has worked: the snapshot of the next carving's first event, or now's.
func _note_state(i: int) -> Dictionary:
	var later := _note_evs.keys().filter(func(k): return int(k) > i)
	if later.is_empty():
		return m.snap()
	var nxt: Dictionary = _note_evs[later.min()][0]
	return nxt.get("_snap", m.snap())


# ------------------------------------------------------------------ playing the new fight's events

func _b_take() -> Array:
	var evs := m.events.duplicate()
	m.events.clear()
	return evs


func _es(i: int) -> EnemyState:
	return m.foes[i].es if i >= 0 and i < m.foes.size() else null


## The state after event k (an attack is told before it lands: the next event's numbers, or now's).
func _after_snap(evs: Array, k: int) -> Dictionary:
	for j in range(k + 1, evs.size()):
		if evs[j].has("_snap"):
			return evs[j]._snap
	return m.snap()


func _b_play(evs: Array, enemy_phase: bool, intents := {}, finish := true) -> void:
	var cur: EnemyState = null
	var hit_no := 0
	for k in evs.size():
		var ev: Dictionary = evs[k]
		var t := String(ev.type)
		var s: Dictionary = ev.get("_snap", {})
		var foe := _es(int(ev.get("foe", -1))) if ev.has("foe") else null
		if enemy_phase and t == "your_turn":
			if cur != null:
				await anim.call({"type": "enemy_done", "enemy": cur})
				cur = null
			continue
		if enemy_phase and foe != null and foe != cur and t != "dies" and t != "spawn":
			if cur != null:
				await anim.call({"type": "enemy_done", "enemy": cur})
			cur = foe
			hit_no = 0
			await anim.call({"type": "enemy_turn", "enemy": cur, "move": intents.get(cur, cur.intent), "stunned": t == "foe_stunned"})
		match t:
			"cast":
				_b_show(s)
				var ci := int(ev.ci)
				var sp: Dictionary = loadout[ci]
				await anim.call({"type": "spell", "spell": sp})
				var fx: Dictionary = ev.get("fx", {})
				if not fx.is_empty():
					var targets := []
					match String(fx.to):
						"foe":
							var e := _es(int(ev.get("target", -1)))
							if e == null:
								var ts := m.targets(ci)
								e = _es(int(ts[0])) if not ts.is_empty() else null
							if e != null:
								targets.append(e)
						"all":
							targets = alive()
					var eff := {"op": String(fx.op), "n": int(fx.n), "target": "self" if String(fx.to) == "you" else "target"}
					var drawn := []
					if String(fx.op) == "draw":  # (the marbles it adds to next turn's draw: the real ones, from your bag)
						var nd := m.next_draw_known()
						for dk in mini(int(fx.n), nd.size()):
							var dm: Dictionary = nd[nd.size() - 1 - dk]
							var dsym := String(dm.get("sym", ""))
							drawn.append("?" if dsym == "star" else String(dm.get("c", "F")) + ("|" + dsym if dsym != "" else ""))
					await anim.call({"type": "spell_effect", "op": String(fx.op), "eff": eff, "targets": targets, "spell": sp, "from_artifact": "", "drawn": drawn})
			"hit", "redirected":
				_b_show(s)
				var e2 := _es(int(ev.get("to", ev.get("foe", -1))))
				if e2 != null:
					await anim.call({"type": "effect", "op": "strike", "eff": {"op": "strike", "n": int(ev.get("n", 0))}, "targets": [e2]})
			"foe_burn", "stun", "foe_weak", "foe_expose", "foe_vulnerable":
				_b_show(s)
				var op: String = {"foe_burn": "burn", "stun": "freeze", "foe_weak": "weak", "foe_expose": "expose", "foe_vulnerable": "expose"}[t]
				if foe != null and not enemy_phase:
					await anim.call({"type": "effect", "op": op, "eff": {"op": op, "n": int(ev.get("n", 1))}, "targets": [foe]})
				elif foe != null:
					await anim.call({"type": "dot", "enemy": foe, "burn": false})
			"burn":
				_b_show(s)
				if foe != null:
					await anim.call({"type": "dot", "enemy": foe, "burn": true})
			"block", "heal", "thorns", "dodge_up", "cleanse":
				_b_show(s)
				var op2: String = {"block": "shield", "heal": "heal", "thorns": "thorns", "dodge_up": "aegis", "cleanse": "cleanse"}[t]
				if not enemy_phase:
					await anim.call({"type": "effect", "op": op2, "eff": {"op": op2, "n": int(ev.get("n", 1))}, "targets": []})
			"attack":
				var hp0 := player.hp
				var sh0 := player.shield
				_b_show(_after_snap(evs, k))
				var lost := int(maxf(0.0, hp0 - player.hp))
				var e3: EnemyState = foe if foe != null else cur
				if e3 != null:
					await anim.call({"type": "attack", "enemy": e3, "n": lost, "blocked": sh0 > player.shield or lost == 0,
						"part": "", "throw": "", "hit": hit_no, "hits": int(e3.intent.get("hits", 1))})
				hit_no += 1
			"self_damage", "you_burn", "ignite_burns", "debuff", "you_stunned", "you_stunned_self":
				var hp1 := player.hp
				_b_show(_after_snap(evs, k) if t == "debuff" else s)
				if t == "you_burn":
					await anim.call({"type": "burn_tick"})
				elif hp1 != player.hp or t == "debuff":
					await anim.call({"type": "effect", "op": "curse", "eff": {"op": "curse", "n": int(ev.get("n", 0))}, "targets": []})
			"boost":  # (something raised something else: a line from the one to the other)
				var src := {"kind": String(ev.from), "k": int(ev.get("k", 0)), "id": _sid[int(ev.src)] if ev.has("src") and int(ev.src) < _sid.size() else ""}
				var cis: Array = ev.get("cis", [ev.ci] if ev.has("ci") else [])
				var dsts := []
				if String(ev.to) == "you":
					dsts.append({"kind": "you", "id": ""})
				for bci in cis:
					if int(bci) >= 0 and int(bci) < loadout.size():
						dsts.append({"kind": "card", "id": _sid[int(bci)]})
						# (its new number, shown when the line lands: FightScreen._boost_landed refreshes the card)
						var at_now: Dictionary = ev.get("texts", {})  # (the card's words at that moment of the count, else now)
						var words := String(at_now.get(int(bci), at_now.get(bci, m.card(int(bci)).text)))
						loadout[int(bci)].desc = MarbleCards.with_durability(words, m.durability_left(int(bci)) if m.card(int(bci)).p.has("dur") else -1)
				if not ev.has("note"):
					_b_show(s)
				if not dsts.is_empty():
					await anim.call({"type": "boost_line", "src": src, "dsts": dsts, "col": String(ev.get("col", "other"))})
			"spawn":
				_b_show(s)
				var e4 := _es(int(ev.get("foe", -1)))
				if e4 != null:
					if not (e4 in enemies):
						enemies.append(e4)
					await anim.call({"type": "spawn", "enemy": e4})
			"dies":
				_b_show(s)
				var e5 := _es(int(ev.get("foe", -1)))
				if e5 != null and not (e5.id in defeated):
					defeated.append(e5.id)
				await anim.call({"type": "sfx", "name": "enemy_defeat"})
			"foe_block", "foe_heal", "foe_power", "foe_thorns", "foe_dodge_up", "foe_regen", "foe_ethereal", "foe_takes_off", "foe_rests", "foe_cleansed", "foe_deflect", "casts", "charging", "phase2", "transform":
				_b_show(s)
				if foe != null:
					var mv: Dictionary = intents.get(foe, foe.intent)
					await anim.call({"type": "enemy_move", "enemy": foe, "kind": String(mv.get("kind", t)), "move": mv, "items": []})
			"foe_stunned", "dodged", "immune", "interrupted", "charge_cut", "deflected":
				_b_show(s)
				await anim.call({"type": "sfx", "name": "spell_glow" if t == "interrupted" else "ui_click"})
			_:
				_b_show(s)
	if cur != null:
		await anim.call({"type": "enemy_done", "enemy": cur})
	if finish:
		_b_show(m.snap())


## Over: the run takes back what changed (HP, coins, marbles), and the screen ends the fight.
func _b_after() -> void:
	_b_sync()
	if m.over and not over:
		over = true
		won = m.won
		for f: StageFight.Foe in m.foes:
			if f.dead() and not (f.id in defeated):
				defeated.append(f.id)
		m.finish()
		rs.take_back(mrun)
