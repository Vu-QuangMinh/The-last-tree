extends RefCounted
## Act 1 card balance simulation (the user, 2026-11-27): whole Act 1 runs in the real fight rules (MarblesFight), played
## by a scripted player, no screen. Each run starts with the three starter cards plus ONE test card (level 0), then takes
## random rewards (a random card of the 3 offered, or a marble), so which cards come later is chance and the test card
## is the only planned difference. Control runs have no test card. Per card: how far runs get (13 steps), the win
## rate, turns per fight and damage taken per fight, against the control.
## The player: each turn it builds the chant from the card patterns it can make with its marbles (the card with the
## longest pattern first, as many times as the card can wake), keeps the leftover marbles for next turn (chants them all
## when its row is nearly full), and casts every awake card (Powers first), each at the enemy with the least HP.
## No artifacts, tickets, shop or events: only cards, marbles, rests and fights.

## The settings: docs/sim/act1_sim_config.json (missing keys: these).
var cfg := {"runs_per_card": 150, "control_runs_x": 3, "sequence": ["easy", "easy", "easy", "medium", "elite", "medium", "rest", "medium", "hard", "elite", "hard", "rest", "boss"],
	"rest_heal": 0.3, "start_hp": 50, "test_card_level": 0, "reward_card_chance": 0.7, "max_turns": 30, "cards": [],
	"score_step": 1.0, "score_turn": 1.0, "score_hp": 0.2}
const CONFIG := "res://docs/sim/act1_sim_config.json"

var _pools := {}
var _elites: Array = []
var _bosses: Array = []
var _lings: Array = []


func run(t: SceneTree) -> void:
	var args := OS.get_cmdline_user_args()
	var loaded = JSON.parse_string(FileAccess.get_file_as_string(CONFIG)) if FileAccess.file_exists(CONFIG) else null
	if loaded is Dictionary:
		for k in loaded:
			if cfg.has(k):
				cfg[k] = loaded[k]
	var n := int(args[0]) if args.size() > 0 and int(args[0]) > 0 else int(cfg.runs_per_card)
	var out: String = args[1] if args.size() > 1 else "user://act1_sim.csv"
	print("SIM settings: %s" % JSON.stringify(cfg))
	for tier in ["easy", "medium", "hard"]:
		_pools[tier] = (EnemyDefs.POOLS[1][tier] as Array).map(func(g): return g.ids).filter(func(ids): return ids.all(func(x): return MarblesRun.simple(String(x))))
	for e in EnemyDefs.elites(1):
		var ids := EnemyDefs.ids_of(e)
		if ids.all(func(x): return MarblesRun.simple(String(x))):
			_elites.append(ids)
	_bosses = (EnemyDefs.BOSSES[1] as Array).filter(func(x): return MarblesRun.simple(String(x))).map(func(x): return [x])
	_lings = StageFight.LINGS
	print("SIM pools: easy %d, medium %d, hard %d, elites %s, bosses %s" % [_pools.easy.size(), _pools.medium.size(), _pools.hard.size(), str(_elites), str(_bosses)])
	var cards: Array = MarbleCards.C.keys().filter(func(id): return not (id in MarblesRun.NEVER_OFFERED) and not (id in MarbleCards.START))
	if not (cfg.cards as Array).is_empty():
		cards = (cfg.cards as Array).filter(func(id): return MarbleCards.has(String(id)))
	var rows := []
	var t0 := Time.get_ticks_msec()
	var seed_base := 7000
	var ctrl := _batch("", n * int(cfg.control_runs_x), seed_base)
	rows.append(_row("(control: starters only)", ctrl))
	print("SIM control: %s  (%.1f s)" % [_fmt(ctrl), (Time.get_ticks_msec() - t0) / 1000.0])
	for i in cards.size():
		var id: String = cards[i]
		var res := _batch(id, n, seed_base + 1000 * (i + 1))
		rows.append(_row(id, res))
		if i % 10 == 0:
			print("SIM %d/%d %s: %s  (%.0f s)" % [i + 1, cards.size(), id, _fmt(res), (Time.get_ticks_msec() - t0) / 1000.0])
		await t.process_frame
	var f := FileAccess.open(out, FileAccess.WRITE)
	f.store_line("card,name,rarity,pattern,runs,avg_steps,win_rate,turns_per_fight,damage_per_fight,steps_vs_control,turns_vs_control,damage_vs_control,score")
	var c0: Dictionary = rows[0].stats
	for r in rows:
		var s: Dictionary = r.stats
		var ds: float = s.steps - c0.steps
		var dt: float = s.turns - c0.turns
		var dd: float = s.dmg - c0.dmg
		r.score = ds * float(cfg.score_step) - dt * float(cfg.score_turn) - dd * float(cfg.score_hp)  # (by default: a step further, a turn shorter, 5 HP less taken: each worth 1)
		var cd := MarbleCards.card(String(r.id)) if MarbleCards.has(String(r.id)) else {}
		f.store_line("%s,\"%s\",%s,%s,%d,%.2f,%.3f,%.2f,%.2f,%.2f,%.2f,%.2f,%.2f" % [r.id, cd.get("name", r.id), cd.get("rarity", ""), cd.get("pattern", ""), s.runs, s.steps, s.win, s.turns, s.dmg, ds, dt, dd, r.score])
	f.close()
	rows.sort_custom(func(a, b): return float(a.score) > float(b.score))
	print("SIM done in %.0f s, %d cards x %d runs (%d steps a run). Written: %s" % [(Time.get_ticks_msec() - t0) / 1000.0, cards.size(), n, (cfg.sequence as Array).size(), out])
	for k in mini(15, rows.size()):
		print("SIM TOP %2d %-30s %s  score %.2f" % [k + 1, rows[k].id, _fmt(rows[k].stats), rows[k].score])
	for k in mini(10, rows.size()):
		var r = rows[rows.size() - 1 - k]
		print("SIM LOW %2d %-30s %s  score %.2f" % [k + 1, r.id, _fmt(r.stats), r.score])


func _row(id: String, s: Dictionary) -> Dictionary:
	return {"id": id, "stats": s, "score": 0.0}


func _fmt(s: Dictionary) -> String:
	return "steps %.2f/%d, win %3.0f%%, %.2f turns/fight, %.1f dmg/fight" % [s.steps, (cfg.sequence as Array).size(), s.win * 100.0, s.turns, s.dmg]


## n runs with this test card: averages.
func _batch(card: String, n: int, seed0: int) -> Dictionary:
	var steps := 0.0
	var wins := 0.0
	var turns := 0.0
	var dmg := 0.0
	var fights := 0.0
	for k in n:
		var r := _run_one(card, seed0 + k)
		steps += r.steps
		wins += 1.0 if r.won else 0.0
		turns += r.turns
		dmg += r.dmg
		fights += r.fights
	return {"runs": n, "steps": steps / n, "win": wins / n, "turns": turns / maxf(1.0, fights), "dmg": dmg / maxf(1.0, fights)}


func _run_one(card: String, seed_v: int) -> Dictionary:
	var r := MarblesRun.new()
	r.setup(seed_v)
	r.max_hp = int(cfg.start_hp)
	r.hp = r.max_hp
	if card != "":
		r.take_card(card)
		r.levels[card] = clampi(int(cfg.test_card_level), 0, 2)
	var out := {"steps": 0, "won": false, "turns": 0, "dmg": 0, "fights": 0}
	var fight_no := 0
	for node in cfg.sequence:
		if node == "rest":
			r.heal(int(r.max_hp * float(cfg.rest_heal)))
			out.steps += 1
			continue
		var ids: Array
		match node:
			"elite":
				ids = _elites[r.rng.randi() % _elites.size()].duplicate()
			"boss":
				ids = _bosses[r.rng.randi() % _bosses.size()].duplicate()
			_:
				var pool: Array = _pools[node]
				ids = pool[r.rng.randi() % pool.size()].duplicate()
				if fight_no == 0:
					ids = [_lings[r.rng.randi() % _lings.size()]]  # (the first fight: one spirit alone)
				elif ids.size() == 1 and String(ids[0]) in _lings:
					var others: Array = _lings.filter(func(x): return x != ids[0])
					ids.append(others[r.rng.randi() % others.size()])  # (spirits come two at a time)
		fight_no += 1
		var res := _fight(r, ids)
		out.turns += res.turns
		out.dmg += res.dmg
		out.fights += 1
		if not res.won:
			return out
		out.steps += 1
		if node == "elite" or node == "boss":
			var offer := r.card_offer(3, true)
			if not offer.is_empty():
				r.take_card(String(offer[r.rng.randi() % offer.size()]))
		elif r.rng.randf() < float(cfg.reward_card_chance):
			var offer2 := r.card_offer(3)
			if not offer2.is_empty():
				r.take_card(String(offer2[r.rng.randi() % offer2.size()]))
		else:
			r.bag.append(r.random_marble())
	out.won = true
	return out


## One fight. Returns {won, turns, dmg (HP lost, summed over every drop)}.
func _fight(r: MarblesRun, ids: Array) -> Dictionary:
	var f := MarblesFight.new()
	f.setup(r, ids)
	f.events.clear()
	var lost := 0
	var hp := r.hp
	while not f.over and f.turn <= int(cfg.max_turns):
		_chant(f)
		_cast_all(f)
		lost += maxi(0, hp - r.hp)
		hp = r.hp
		f.events.clear()
		if f.over:
			break
		f.end_turn()
		f.events.clear()
		lost += maxi(0, hp - r.hp)
		hp = r.hp
	var won := f.won and f.over
	f.finish()
	if not won:
		r.hp = 0
	return {"won": won, "turns": f.turn, "dmg": lost}


## The chant: the card patterns it can make from its marbles, the best (longest) first, each as many times as the card
## can wake; leftover marbles stay for next turn (all of them go in when the row is nearly full).
func _chant(f: MarblesFight) -> void:
	var free := []  # hand indices it may use
	for h in f.hand.size():
		if not bool(f.hand[h].get("frozen", false)):
			free.append(h)
	var budget := {}
	for ci in f.run.cards.size():
		if f.usable(ci):
			var c := f.card(ci)
			budget[ci] = int(c.p.get("rep", 1))
	var order := []  # hand indices, in chant order
	var left := free.duplicate()
	while true:
		var best := -1
		var best_use := []
		var best_v := -1.0
		for ci in budget:
			if int(budget[ci]) <= 0:
				continue
			var pat := String(f.card(ci).pattern)
			if pat == "":
				continue
			var use := _form(f, pat, left)
			if use.is_empty():
				continue
			var v := float(pat.length()) + randf() * 0.1  # (the longest pattern first; ties at random)
			if v > best_v:
				best_v = v
				best = ci
				best_use = use
		if best < 0 or order.size() + best_use.size() > MarblesFight.MAX_CHANT:
			break
		budget[best] = int(budget[best]) - 1
		for h in best_use:
			order.append(h)
			left.erase(h)
	if order.is_empty() or f.hand.size() >= MarblesFight.MAX_ROW - 2:
		for h in left:  # (nothing to make, or the row is filling up: everything goes in)
			if order.size() < MarblesFight.MAX_CHANT:
				order.append(h)
	if order.is_empty():
		return
	var uids := order.map(func(h): return f.hand[h].get("uid", -1))
	for u in uids:
		for h in f.hand.size():
			if f.hand[h].get("uid", -2) == u:
				f.put(h)
				break
	f.do_chant()


## The hand marbles (indices from `left`) that spell `pat`, in order (a star marble stands for any colour); [] if it can't.
func _form(f: MarblesFight, pat: String, left: Array) -> Array:
	var pool := left.duplicate()
	var use := []
	for ch in pat:
		var pick := -1
		for h in pool:
			if String(f.hand[h].get("sym", "")) != "star" and String(f.hand[h].c) == ch:
				pick = h
				break
		if pick < 0:
			for h in pool:
				if String(f.hand[h].get("sym", "")) == "star":
					pick = h
					break
		if pick < 0:
			return []
		use.append(pick)
		pool.erase(pick)
	return use


## Cast everything awake (Powers first), each at the enemy with the least HP.
func _cast_all(f: MarblesFight) -> void:
	for loop in 30:
		if f.over:
			return
		if f.pending_replace >= 0:
			f.replace_with(-1)
		while f.pending_infuse > 0:  # (Insight of the Pianist: a random marble of the bag)
			var ch := f.infuse_choices()
			f.infuse_pick(ch[randi() % ch.size()] if not ch.is_empty() else -1)
		var any := false
		var cis := range(f.run.cards.size())
		cis.sort_custom(func(a, b): return int(bool(f.card(a).get("power", false))) > int(bool(f.card(b).get("power", false))))
		for ci in cis:
			if f.over:
				return
			if f.can_cast(ci):
				var ts: Array = f.targets(ci)
				var tg := -1
				if not ts.is_empty():
					tg = ts[0]
					for x in ts:
						if f.foes[x].hp < f.foes[tg].hp:
							tg = x
				f.cast(ci, tg if f.needs_target(ci) else -1)
				any = true
				f.events.clear()
		if not any:
			return
