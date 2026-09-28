extends SceneTree
## Headless playtest: a scripted player plays full runs and reports what killed it.
## Usage: godot_console --headless --path . -s tools/sim.gd -- [runs] [new|vet] [seed]

const BEAM := 40
const TURN_CAP := 40

var db: SpellDB
var deaths := {}  # encounter label -> count
var dmg_by_enemy := {}  # id -> [total damage, fights]
var turns_by_kind := {"fight": [], "elite": [], "boss": []}
var hp_after := {"fight": [], "elite": [], "boss": []}
var picks := {}
var forced := ""  # spells mode: always active, and no other spells are learned


func _init() -> void:
	await process_frame
	var args := OS.get_cmdline_user_args()
	var runs := int(args[0]) if args.size() > 0 else 20
	var mode: String = args[1] if args.size() > 1 else "new"
	var seed0 := int(args[2]) if args.size() > 2 else 1000
	db = SpellDB.load_from("res://data/spells.json")
	var save_script: GDScript = load("res://scripts/autoload/save_manager.gd")
	var spells: Array = db.starters().map(func(s): return s.id) + Array(save_script.DEFAULT_SPELLS)
	var arts: Array = Artifacts.ALL.filter(func(a): return a.starter).map(func(a): return a.id)
	if mode == "vet":
		spells = db.all_spells.map(func(s): return s.id)
		arts = Artifacts.ALL.map(func(a): return a.id)
	if mode == "spells":
		await _spell_strength(runs, seed0, spells + db.all_spells.map(func(s): return s.id), arts)
		quit()
		return
	var wins := 0
	var acts := {1: 0, 2: 0, 3: 0}
	var fights_total := 0
	for r in runs:
		var res := await _play_run(seed0 + r, spells, arts)
		fights_total += res.fights
		if res.won:
			wins += 1
		else:
			acts[res.act] += 1
		print("run %d: %s act %d floor %d hp %d fights %d  %s" % [r, "WIN " if res.won else "LOSS", res.act, res.floor, res.hp, res.fights, res.cause])
	print("\n=== %s: %d/%d wins. Deaths by act: %s. Avg fights/run %.1f" % [mode, wins, runs, acts, fights_total / float(runs)])
	for k in turns_by_kind:
		if turns_by_kind[k].size() > 0:
			print("%-6s avg turns %.1f, avg HP after %.1f (n=%d)" % [k, _avg(turns_by_kind[k]), _avg(hp_after[k]), turns_by_kind[k].size()])
	var pk := picks.keys()
	pk.sort_custom(func(a, b): return picks[a] > picks[b])
	print("\nMost picked: ", ", ".join(pk.slice(0, 25).map(func(k): return "%s %d" % [k, picks[k]])))
	print("\nDeaths:")
	for k in deaths:
		print("  %s: %d" % [k, deaths[k]])
	print("\nAvg damage dealt to you per fight, by enemy:")
	var ids := dmg_by_enemy.keys()
	ids.sort_custom(func(a, b): return dmg_by_enemy[a][0] / dmg_by_enemy[a][1] > dmg_by_enemy[b][0] / dmg_by_enemy[b][1])
	for id in ids:
		print("  %-18s %.1f  (%d fights)" % [id, dmg_by_enemy[id][0] / dmg_by_enemy[id][1], dmg_by_enemy[id][1]])
	quit()


## Starter spells + one extra spell, no rewards: how far does each extra spell carry a run?
func _spell_strength(runs: int, seed0: int, spells: Array, arts: Array) -> void:
	var results := []
	var ids: Array = [""] + db.all_spells.filter(func(s): return not s.starter).map(func(s): return s.id)
	for id in ids:
		forced = id
		var total := 0.0
		for r in runs:
			var res := await _play_run(seed0 + r, spells, arts)
			total += res.fights + (res.act - 1) * 2
		results.append([id if id != "" else "(starters only)", total / runs])
		printraw(".")
	results.sort_custom(func(a, b): return a[1] > b[1])
	print("
Progress score (fights won + act bonus), starters + one spell, %d runs each:" % runs)
	for r in results:
		var sp := db.get_spell(r[0])
		print("  %-22s %5.2f  %s" % [r[0], r[1], ("%s%s" % [sp.pattern, " P" if sp.power else ""]) if not sp.is_empty() else ""])


func _avg(a: Array) -> float:
	var t := 0.0
	for x in a:
		t += x
	return t / maxf(1, a.size())


func _play_run(seed: int, spells: Array, arts: Array) -> Dictionary:
	var run := RunState.new()
	run.setup(db, spells, arts, seed)
	if forced == "" and not _spells_mode():
		var start: Array = Artifacts.keepsakes(run.rng, 3)
		if not start.is_empty():
			run.gain_artifact(start[0].id)
	if forced != "":
		run.learn_spell(forced)
	var fights := 0
	var cause := ""
	while not run.over:
		var node := run.move_to(_pick_path(run))
		var kind0: String = node.type
		if kind0 == "event":
			kind0 = run.resolve_unknown()
		if kind0 == "event":
			var ev := MapEvents.get_event(node.event)
			var low := run.player.hp < run.player.max_hp * 0.5
			var pick: Dictionary = ev.options[-1]
			for o in ev.options:
				if not run.can_choose(o):
					continue
				if low and o.do == "heal":
					pick = o
					break
				if not low and o.get("hp", 0) <= 8 and o.do != "gamble" and o.do != "curse_amber":
					pick = o
					break
			var res := run.choose_event_option(pick)
			if run.player.is_dead():
				run.over = true
				break
			if not res.get("fight", false):
				continue
			node["as"] = "fight"
			kind0 = "fight"
		if kind0 == "shop":
			for it in run.shop_stock():
				if it.kind == "spell" and it.spell.rarity != "common" and run.pay(it.price):
					run.learn_spell(it.spell.id)
				elif it.kind == "heal" and run.player.hp < run.player.max_hp * 0.5 and run.pay(it.price):
					run.player.heal(run.player.max_hp * RunState.REST_HEAL)
			continue
		match kind0:
			"rest":
				# heal when hurt, otherwise upgrade the best active spell
				var fz := run.fusable().filter(func(id): return id in run.loadout)
				if run.player.hp < run.player.max_hp * 0.6 or fz.size() < 2:
					run.rest()
				else:
					fz.sort_custom(func(a, b): return _spell_value(run.spell(a)) > _spell_value(run.spell(b)))
					run.fuse_commit(run.fuse_preview(fz[0], fz[1]), fz[0], fz[1])
			"treasure":
				var offer := run.treasure_offer().filter(func(a): return a.aspect != "Cursed")
				if not offer.is_empty():
					run.gain_artifact(offer[0].id)
			_:
				fights += 1
				var ids := run.encounter_ids()
				_pick_loadout(run)
				var hp0 := run.player.hp
				var f := run.make_fight(ids)
				f.chooser = func(s, cands): return _choose_target(f, cands)
				f.mover = func(s, e): return _pick_move(f, e)
				f.picker = func(s, e): return _pick_pluck(f, e)
				f.placer = func(s, el): return _best_insert(f, el)
				f.chant_picker = func(s): return _best_duplicate(f, s)
				var turns := 0
				while not f.over and turns < TURN_CAP:
					turns += 1
					var idx := _best_chant(f)
					if idx.is_empty():
						await f.pass_turn()
					else:
						await f.cast(idx)
				if not f.over:
					f.over = true
					f.won = false
				var kind: String = run.current_kind()
				var per := (hp0 - run.player.hp) / ids.size()
				for id in ids:
					if not dmg_by_enemy.has(id):
						dmg_by_enemy[id] = [0.0, 0]
					dmg_by_enemy[id][0] += per
					dmg_by_enemy[id][1] += 1
				if f.won:
					turns_by_kind[kind].append(turns)
					hp_after[kind].append(run.player.hp)
				else:
					cause = "%s (A%d F%d)" % [", ".join(ids), run.act, run.depth()]
					var label := "A%d %s" % [run.act, kind if kind != "fight" else ", ".join(ids)]
					deaths[label] = deaths.get(label, 0) + 1
				var was_boss := kind == "boss"
				run.finish_fight(f)
				if f.won and was_boss and not _spells_mode():
					var relics := run.boss_relic_offer()
					if not relics.is_empty():
						run.gain_artifact(relics[0].id)
				if f.won and not run.over and not _spells_mode():
					var offer := run.spell_offer(3, kind)
					if not offer.is_empty():
						var best: Dictionary = offer[0]
						for s in offer:
							if _spell_value(s) > _spell_value(best):
								best = s
						run.learn_spell(best.id)
						picks[best.id] = picks.get(best.id, 0) + 1
					if kind == "elite":
						var ao := run.artifact_offer(3)
						if not ao.is_empty():
							run.gain_artifact(ao[0].id)
	return {"won": run.won, "act": run.act, "floor": run.depth(), "hp": run.player.hp, "fights": fights, "cause": cause}


func _spells_mode() -> bool:
	var a := OS.get_cmdline_user_args()
	return a.size() > 1 and a[1] == "spells"


func _pick_path(run: RunState) -> int:
	var opts := run.choices()
	var best: int = opts[0]
	var best_score := -99.0
	var low := run.player.hp < run.player.max_hp * 0.5
	for c in opts:
		var t: String = run.map[run.row + 1][c].type
		var s: float = {"fight": 2.0, "elite": 1.0 if not low else -3.0, "rest": 3.0 if low else 0.0, "treasure": 2.5, "boss": 0.0, "event": 1.8, "shop": 1.0 + run.amber / 60.0}[t]
		s += randf() * 0.5
		if s > best_score:
			best_score = s
			best = c
	return best


## Keep the six most valuable spells active.
func _pick_loadout(run: RunState) -> void:
	var book := run.spellbook.map(func(id): return run.spell(id))
	book.sort_custom(func(a, b): return _spell_value(a) > _spell_value(b))
	run.loadout = book.slice(0, run.active_slots()).map(func(s): return s.id)
	if forced != "" and not (forced in run.loadout):
		run.loadout[-1] = forced


func _spell_value(s: Dictionary) -> float:
	var v := 0.0
	for e in s.effects:
		v += _effect_value(e)
	# long patterns fire less often
	return v * [1.0, 1.0, 0.95, 0.7, 0.4, 0.25][int(s.size)]


func _effect_value(e: Dictionary) -> float:
	match e.op:
		"strike":
			return e.n * (1.6 if e.get("target", "") == "all" else 1.0)
		"purge":
			return e.n * 0.8
		"burn", "poison":
			return e.n * (0.9 if e.get("target", "") != "all" else 1.5)
		"shield", "heal":
			return e.n * 0.25
		"draw":
			return e.n * 0.6
		"aegis":
			return 1.5
		"weak", "freeze":
			return 1.2
		"execute":
			return 2.0
		"move":
			return 0.6 * e.n
		"pluck":
			return 1.2 * e.n
		"steal":
			return 1.5 * e.n
		"infuse":
			return 1.0
		"duplicate":
			return 0.8 * e.times
		"summon_spells":
			return 2.0
		"redirect":
			return 2.5
		"sacrifice":
			return -e.hp * 0.6
		"overload":
			return -0.6
		"curse":
			return 0.4
		"passive", "each_turn":
			return 1.5
	return 0.5


## Move an armoured element to the end; otherwise bring forward an element you hold plenty of.
func _pick_move(f: Fight, e: EnemyState) -> Array:
	var i := e.armor.find(true)
	if i >= 0 and i < e.size() - 1:
		return [i, e.size() - 1]
	var best := ""
	for el in Elements.ALL:
		if best == "" or f.player.count_usable(el) > f.player.count_usable(best):
			best = el
	var j := e.elements.find(best, 1)
	if j > 0 and e.elements[0] != best:
		return [j, 0]
	return []


## Pluck the element that most blocks your chant: the first one you can't cover from your stock.
func _pick_pluck(f: Fight, e: EnemyState) -> int:
	var have := {"F": f.player.count_usable("F"), "W": f.player.count_usable("W"), "A": f.player.count_usable("A")}
	for i in e.size():
		if e.armor[i]:
			continue
		var el: String = e.elements[i]
		if have.get(el, 0) <= 0:
			return i
		have[el] -= 1
	return e.armor.find(false)


## Where an infused element helps most: the spot whose chant scores best.
func _best_insert(f: Fight, el: String) -> int:
	var best := f.chant.size()
	var best_s := -999.0
	for i in f.chant.size() + 1:
		var c := f.chant.duplicate()
		c.insert(i, el)
		var sc := _score_spoken(f, "".join(c))
		if sc > best_s:
			best_s = sc
			best = i
	return best


func _best_duplicate(f: Fight, spell: Dictionary) -> int:
	var times: int = 2
	for e in spell.effects:
		if e.op == "duplicate":
			times = e.times
	var best := 0
	var best_s := -999.0
	for i in f.chant.size():
		var c := f.chant.duplicate()
		for k in times - 1:
			c.insert(i, c[i])
		var sc := _score_spoken(f, "".join(c))
		if sc > best_s:
			best_s = sc
			best = i
	return best


func _score_spoken(f: Fight, c: String) -> float:
	var p := f.preview(c, false)
	var s := 0.0
	for e in p.removed:
		s += p.removed[e]
	s += p.dies.size() * 3.0
	for id in p.spells:
		s += p.spells[id] * _spell_value(db.get_spell(id))
	return s


func _choose_target(f: Fight, cands: Array) -> int:
	var best: int = cands[0]
	for i in cands:
		if f.enemies[i].size() < f.enemies[best].size():
			best = i
	return best


## Beam search over chants built from the stock; scores with the fight's own preview.
func _best_chant(f: Fight) -> Array:
	var avail := {"F": 0, "W": 0, "A": 0}
	for s in f.player.stock:
		if not s.frozen:
			avail[s.el] += 1
	var slots := f.player.chant_slots()
	var beam := [""]
	var best := ""
	var best_score := 0.0
	for depth in slots:
		var nxt := []
		for c in beam:
			for el in Elements.ALL:
				if c.count(el) < avail[el]:
					nxt.append(c + el)
		if nxt.is_empty():
			break
		var scored := []
		for c in nxt:
			scored.append([_score(f, c), c])
		scored.sort_custom(func(a, b): return a[0] > b[0])
		beam = []
		for i in mini(BEAM, scored.size()):
			beam.append(scored[i][1])
			if scored[i][0] > best_score:
				best_score = scored[i][0]
				best = scored[i][1]
	if best == "":
		return []
	# map the chant to stock indices (conjured first, avoid hexed)
	var chant := best
	var used := {}
	var out := []
	for ch in chant:
		var pick := -1
		for i in f.player.stock.size():
			var s: Dictionary = f.player.stock[i]
			if used.has(i) or s.frozen or s.el != ch:
				continue
			if pick == -1 or (s.temp and not f.player.stock[pick].temp) or (f.player.stock[pick].hexed and not s.hexed):
				pick = i
		used[pick] = true
		out.append(pick)
	return out


func _score(f: Fight, chant: String) -> float:
	var p := f.preview(chant)
	var s := 0.0
	for e in p.removed:
		s += p.removed[e]
	s += p.dies.size() * 3.0
	for id in p.spells:
		s += p.spells[id] * _spell_value(db.get_spell(id)) * 1.1
	# keep some elements for later when the gain is equal
	return s - chant.length() * 0.05
