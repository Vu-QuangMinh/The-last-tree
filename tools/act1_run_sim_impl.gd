extends RefCounted
## Act 1 run simulation (the user, 2026-11-27): many whole Act 1 runs in the real rules (RunState for the run, MarblesFight
## for each fight), played by a scripted player, no screen. Which cards and artifacts do better or worse than the rest.
##
## A run: a random keepsake (1 of the 3 offered), then the average number of fights an Act 1 path holds (measured on the
## real maps first), in the real fight plan (easy, medium, hard), with one elite (rare cards + an artifact) in the middle,
## one shop (a carved marble and a card, at random) after it, one rest (heals 30%) and the boss. No events, no tickets.
## After a normal fight: the real reward roll (a card or a marble, RunState.reward_kind), a random pick of the 3 offered.
## Before each fight the active row is drawn at random from the cards you own, so every card you have gets to fight.
## The player: see tools/act1_sim_impl.gd (it builds the chant from the patterns it can make, longest first, keeps the
## leftover marbles, casts everything awake at the weakest enemy). Artifacts that need a choice choose at random.
##
## Measured per fight: turns, damage taken (every HP drop), died. A card's numbers are its fights against the SAME
## encounters without it (so a card only ever met in the hard fights is not blamed for them): for each encounter,
## (mean with the card) - (mean without), weighed by how often the card fought it. Same for artifacts.

const MAX_TURNS := 30

var db: SpellDB
var _lings: Array = []
var _elites: Array = []
var _bosses: Array = []
var _avg_fights := 6
var _enc := {}  # encounter key -> [n, turns, dmg, deaths]
var _card := {}  # card id -> {encounter key -> [n, turns, dmg, deaths]}
var _art := {}  # artifact id -> {encounter key -> [n, turns, dmg, deaths]}
var _runs := 0
var _wins := 0
var _steps := 0
var _sim := preload("res://tools/act1_sim_impl.gd")
var _bot: RefCounted


func run(t: SceneTree) -> void:
	var args := OS.get_cmdline_user_args()
	var total := int(args[0]) if args.size() > 0 else 1000
	var prefix: String = args[1] if args.size() > 1 else "res://docs/sim/act1_run_sim"
	db = t.root.get_node("GameData").db
	_bot = _sim.new()
	_lings = StageFight.LINGS
	for e in EnemyDefs.elites(1):
		var ids := EnemyDefs.ids_of(e)
		if ids.all(func(x): return MarblesRun.simple(String(x))):
			_elites.append(ids)
	_bosses = (EnemyDefs.BOSSES[1] as Array).filter(func(x): return MarblesRun.simple(String(x)))
	_avg_fights = _measure_map()
	var seq := _sequence()
	print("RUNSIM a run: %s" % " > ".join(seq))
	var t0 := Time.get_ticks_msec()
	for k in total:
		_one_run(9000 + k, seq)
		if (k + 1) % 1000 == 0:
			print("RUNSIM %d/%d runs, won %.1f%%, %.1f steps of %d  (%.0f s)" % [k + 1, total, 100.0 * _wins / _runs, float(_steps) / _runs, seq.size(), (Time.get_ticks_msec() - t0) / 1000.0])
		if (k + 1) % 5000 == 0 or k + 1 == total:
			_write(prefix, seq)
			await t.process_frame
	print("RUNSIM done: %d runs in %.0f s" % [total, (Time.get_ticks_msec() - t0) / 1000.0])


## How many fights a path through an Act 1 map holds, on average (2000 random paths on real maps). Events and the
## rest are not fights; the elites and the shop on the path are left out too (the run has its own one of each).
func _measure_map() -> int:
	var rng := RandomNumberGenerator.new()
	rng.seed = 4242
	var fights := 0.0
	var kinds := {}
	var walks := 2000
	for w in walks:
		var rows := MapGen.generate(rng)
		var r := -1
		var c := 0
		while r + 1 < rows.size():
			var nxt: Array = MapGen.reachable(rows, r, c)
			if nxt.is_empty():
				break
			c = int(nxt[rng.randi() % nxt.size()])
			r += 1
			var n = rows[r][c]
			if n == null:
				break
			var ty := String(n.type)
			kinds[ty] = int(kinds.get(ty, 0)) + 1
			if ty == "fight":
				fights += 1.0
	var avg := fights / walks
	var per := {}
	for k in kinds:
		per[k] = snappedf(float(kinds[k]) / walks, 0.01)
	print("RUNSIM map: an Act 1 path holds on average %s -> %d fights" % [str(per), roundi(avg)])
	return maxi(3, roundi(avg))


## The run's steps: the fights, the elite in the middle, the shop after it, the rest before the boss.
func _sequence() -> Array:
	var seq := []
	var mid := _avg_fights / 2
	for i in _avg_fights:
		seq.append("fight")
		if i == mid - 1:
			seq.append("elite")
			seq.append("shop")
	seq.append("rest")
	seq.append("boss")
	return seq


func _one_run(seed_v: int, seq: Array) -> void:
	var rs := RunState.new()
	var arts := Artifacts.ALL.filter(func(a): return a.pool != "none").map(func(a): return String(a.id))
	rs.setup(db, db.all_spells.map(func(s): return String(s.id)), arts, seed_v)
	var keep := Artifacts.keepsakes(rs.rng, 3)
	if not keep.is_empty():
		_gain_artifact(rs, String(keep[rs.rng.randi() % keep.size()].id))
	var plan := EnemyDefs.roll_fight_plan(1, rs.rng, MarblesRun.simple)
	var fight_no := 0
	var steps := 0
	_runs += 1
	for node in seq:
		match node:
			"rest":
				rs.player.heal(floorf(rs.player.max_hp * RunState.REST_HEAL))
				steps += 1
				continue
			"shop":
				var m := {"c": ["F", "W", "A"][rs.rng.randi() % 3], "sym": ""}
				var syms := rs.carving_offer(3)
				m.sym = String(syms[rs.rng.randi() % syms.size()])
				rs.marble_bag.append(m)
				_take_card(rs, rs.spell_offer(1, "shop"))
				steps += 1
				continue
		var ids: Array
		var key := ""
		match node:
			"elite":
				ids = _elites[rs.rng.randi() % _elites.size()].duplicate()
				key = "elite:" + ",".join(ids)
			"boss":
				ids = [_bosses[rs.rng.randi() % _bosses.size()]]
				key = "boss:" + ",".join(ids)
			_:
				var enc: Dictionary = plan[mini(fight_no, plan.size() - 1)]
				ids = (enc.ids as Array).duplicate()
				if fight_no > 0 and ids.size() == 1 and String(ids[0]) in _lings:  # (spirits come two at a time, but the first)
					var others: Array = _lings.filter(func(x): return x != ids[0])
					ids.append(others[rs.rng.randi() % others.size()])
				key = "fight%d:%s" % [mini(fight_no, 3), ",".join(ids)]  # (the place in the plan matters: what you own grows)
				fight_no += 1
		var res := _fight(rs, ids)
		_record(key, res, rs)
		if not res.won:
			_steps += steps
			return
		steps += 1
		if "candy_apple" in rs.artifacts:
			rs.player.heal(5.0)
		match node:
			"boss":
				pass
			"elite":
				_take_card(rs, rs.spell_offer(3, "elite"))
				var ao := rs.artifact_offer(3)
				if not ao.is_empty():
					_gain_artifact(rs, String(ao[rs.rng.randi() % ao.size()].id))
			_:
				if rs.reward_kind() == "card":
					_take_card(rs, rs.spell_offer(3, "fight"))
				else:
					var ms := rs.marble_offer(3)
					rs.marble_bag.append(ms[rs.rng.randi() % ms.size()])
	_steps += steps
	_wins += 1


func _take_card(rs: RunState, offer: Array) -> void:
	if offer.is_empty():
		return
	var id := String(offer[rs.rng.randi() % offer.size()].id)
	if not rs.has_room(id):
		var back := rs.backpack()
		if back.is_empty():
			return
		rs.throw_away(String(back[rs.rng.randi() % back.size()]))
	rs.learn_spell(id)


func _gain_artifact(rs: RunState, id: String) -> void:
	rs.gain_artifact(id)
	rs.pending_curses.clear()
	if id == "carver":  # (3 marbles carved, each with 1 of the 3 carvings rolled for it, at random)
		for k in 3:
			if rs.marble_bag.is_empty():
				break
			var m: Dictionary = rs.marble_bag[rs.rng.randi() % rs.marble_bag.size()]
			var syms := rs.carving_offer(3)
			m.sym = String(syms[rs.rng.randi() % syms.size()])


## One fight: the active row drawn at random from the cards you own.
func _fight(rs: RunState, ids: Array) -> Dictionary:
	var own: Array = rs.spellbook.filter(func(x): return MarbleCards.has(String(x)))
	own.shuffle()
	rs.loadout = own.slice(0, mini(own.size(), rs.active_slots()))
	var mr := rs.marble_run()
	var f := MarblesFight.new()
	f.setup(mr, ids)
	f.events.clear()
	var lost := 0
	var hp := mr.hp
	while not f.over and f.turn <= MAX_TURNS:
		_bot._chant(f)
		_bot._cast_all(f)
		lost += maxi(0, hp - mr.hp)
		hp = mr.hp
		f.events.clear()
		if f.over:
			break
		f.end_turn()
		f.events.clear()
		lost += maxi(0, hp - mr.hp)
		hp = mr.hp
	var won := f.won and f.over
	f.finish()
	var row: Array = rs.loadout.duplicate()
	rs.take_back(mr)
	return {"won": won, "turns": f.turn, "dmg": lost, "row": row}


func _record(key: String, res: Dictionary, rs: RunState) -> void:
	var v := [1, int(res.turns), int(res.dmg), 0 if res.won else 1]
	_add(_enc, key, v)
	for id in res.row:
		if not _card.has(id):
			_card[id] = {}
		_add(_card[id], key, v)
	for a in rs.artifacts:
		if Artifacts.get_def(String(a)).get("pool", "") == "none":
			continue
		if not _art.has(a):
			_art[a] = {}
		_add(_art[a], key, v)


static func _add(d: Dictionary, key: String, v: Array) -> void:
	if not d.has(key):
		d[key] = [0, 0, 0, 0]
	var s: Array = d[key]
	for i in 4:
		s[i] = int(s[i]) + int(v[i])


## Per card / artifact: its fights against each encounter, minus the same encounter's fights without it.
func _effects(table: Dictionary) -> Array:
	var out := []
	for id in table:
		var n := 0.0
		var dt := 0.0
		var dd := 0.0
		var dx := 0.0
		for key in table[id]:
			var w: Array = table[id][key]
			var all: Array = _enc[key]
			var n_wo := float(int(all[0]) - int(w[0]))
			if n_wo < 5.0 or int(w[0]) < 1:
				continue
			var nw := float(w[0])
			dt += nw * (float(w[1]) / nw - (float(all[1]) - float(w[1])) / n_wo)
			dd += nw * (float(w[2]) / nw - (float(all[2]) - float(w[2])) / n_wo)
			dx += nw * (float(w[3]) / nw - (float(all[3]) - float(w[3])) / n_wo)
			n += nw
		if n < 30.0:
			continue
		dt /= n
		dd /= n
		dx /= n
		# (a combined score: a turn shorter = 1, 5 HP less taken = 1, 1% fewer deaths = 1)
		out.append({"id": id, "fights": int(n), "turns": dt, "dmg": dd, "death": dx, "score": -dt - dd / 5.0 - dx * 100.0})
	out.sort_custom(func(a, b): return float(a.score) > float(b.score))
	return out


func _write(prefix: String, seq: Array) -> void:
	for which in ["cards", "artifacts"]:
		var rows := _effects(_card if which == "cards" else _art)
		var f := FileAccess.open("%s_%s.csv" % [prefix, which], FileAccess.WRITE)
		f.store_line("rank,id,name,rarity,fights_in,turns_vs_without,damage_vs_without,death_rate_vs_without_pct,score")
		for i in rows.size():
			var r: Dictionary = rows[i]
			var nm := String(MarbleCards.card(String(r.id)).get("name", r.id)) if which == "cards" and MarbleCards.has(String(r.id)) else String(Artifacts.get_def(String(r.id)).get("name", r.id))
			var rar := MarbleCards.rarity(String(r.id)) if which == "cards" else String(Artifacts.get_def(String(r.id)).get("tier", ""))
			f.store_line("%d,%s,\"%s\",%s,%d,%.3f,%.3f,%.2f,%.3f" % [i + 1, r.id, nm, rar, r.fights, r.turns, r.dmg, r.death * 100.0, r.score])
		f.close()
	var g := FileAccess.open("%s_summary.txt" % prefix, FileAccess.WRITE)
	g.store_line("runs %d, won %.1f%%, average steps %.2f of %d (%s)" % [_runs, 100.0 * _wins / maxi(1, _runs), float(_steps) / maxi(1, _runs), seq.size(), " > ".join(seq)])
	var keys := _enc.keys()
	keys.sort()
	for key in keys:
		var s: Array = _enc[key]
		g.store_line("%-45s fights %6d  turns %.2f  dmg %.2f  death %.2f%%" % [key, int(s[0]), float(s[1]) / int(s[0]), float(s[2]) / int(s[0]), 100.0 * int(s[3]) / int(s[0])])
	g.close()
