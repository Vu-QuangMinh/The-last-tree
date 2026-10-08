class_name RunState
extends RefCounted
## One run: 3 acts of branching maps. Pure logic (no autoloads) so the balance sim can drive it.

const ACTS := 3
const BASE_ACTIVE := 5
const MAX_ACTIVE := 8
const SEEDLINGS := {"fight": 3, "elite": 8, "boss": 20}
const WIN_BONUS := 30
const REST_HEAL := 0.3
## Normal fights: each card is common 70% of the time, rare 30%. Elites: 3 rares. Bosses: 3 legendaries.
const RARE_CHANCE := 0.3
## Amber: the run's money, spent at merchants and in some events.
const START_AMBER := 30
const AMBER := {"fight": [14, 22], "elite": [28, 38], "boss": [60, 60]}
const PRICES := {"common": 45, "rare": 75, "legendary": 140, "artifact": 110, "artifact_rare": 170, "upgrade": 160, "heal": 40}
## What a "?" room turns out to be.
const UNKNOWN_ODDS := {"fight": 0.15, "treasure": 0.08, "shop": 0.07}

signal artifact_gained(id: String)

var rng := RandomNumberGenerator.new()
var db: SpellDB
var player := PlayerState.new()
var spellbook: Array = []  # spell ids owned this run
var loadout: Array = []  # active spell ids (up to active_slots())
var artifacts: Array = []
var artifacts_plus: Array = []  # artifacts upgraded to their + version (the Tinker)
var unlocked_spells: Array = []
var unlocked_artifacts: Array = []
var act := 1
var map: Array = []
var row := -1  # -1 = at the start of the act
var col := 1
var seedlings := 0
var kills := 0
var defeated_ids: Array = []
var met: Array = []  # enemy ids met this run, oldest first
var upgraded: Array = []  # (legacy: upgrades are wax seals now, see `seals`)
var burdens := {}  # spell id -> Essence added to the end of its pattern (the Tangled Grimoire's curse)
var curse_note := ""  # what the last cursed artifact just did (shown when it's found)
var seals := {}  # spell id -> [indices of its pattern sealed by upgrades]: those Essence are no longer needed
var amber := START_AMBER
var seen_events: Array = []
var encounter: Array = []  # the ids of the encounter being prepared
var encounter_name := ""  # its name (Act 1's hand-made encounters, e.g. "The Slime Trio"; "" otherwise)
var recent_encounters: Array = []  # names of the encounters met so far (an encounter never comes up twice in 3)
var encounter_extra: Array = []  # the extra Essence each of those enemies will have (rolled once)
var fused := {}  # id -> spell dict, for spells forged at campfires ("fused_1", ...)
var _fuse_count := 0
var over := false
var won := false
var reward_bottle := ""  # a bottle found after the last fight ("" if none)
var fight_snapshot := {}  # you as you went into the current fight (the Seed of Life puts it back)
const SEED_MEND_PRICE := 100
## Chance to find a bottle after winning a fight (if you have a free slot).
const BOTTLE_DROP := {"fight": 0.25, "elite": 0.5, "boss": 1.0}


func setup(p_db: SpellDB, p_unlocked_spells: Array, p_unlocked_artifacts: Array, seed := 0) -> void:
	db = p_db
	unlocked_spells = p_unlocked_spells
	unlocked_artifacts = p_unlocked_artifacts
	if seed != 0:
		rng.seed = seed
	else:
		rng.randomize()
	for s in db.starters():
		spellbook.append(s.id)
		loadout.append(s.id)
	artifacts.append("seed_of_life")  # every run starts with its second chance
	map = MapGen.generate(rng)


## Everything about the run, for the save file (see SaveManager.save_run): every variable of the run and of you,
## and where the random numbers had got to (so the next room comes out the same).
func to_save() -> Dictionary:
	var d := _vars_of(self, ["db", "rng", "player"])
	d.rng_seed = rng.seed
	d.rng_state = rng.state
	d.player = _vars_of(player, [])
	return d


static func from_save(d: Dictionary, p_db: SpellDB) -> RunState:
	var r := RunState.new()
	r.db = p_db
	for k in d:
		if not (k in ["rng_seed", "rng_state", "player"]) and k in r:
			r.set(k, d[k])
	r.rng.seed = d.rng_seed
	r.rng.state = d.rng_state
	for k in d.player:
		if k in r.player:
			r.player.set(k, d.player[k])
	return r


static func _vars_of(o: Object, skip: Array) -> Dictionary:
	var out := {}
	for p in o.get_property_list():
		if p.usage & PROPERTY_USAGE_SCRIPT_VARIABLE and not (p.name in skip):
			var v = o.get(p.name)
			out[p.name] = v.duplicate(true) if (v is Array or v is Dictionary) else v
	return out


## Active spell slots: 5, changed by artifacts (never by the chant length), at most 8.
func active_slots() -> int:
	var n := BASE_ACTIVE
	for a in ["spell_satchel", "broken_crown", "tangled_grimoire", "spell_pouch"]:  # (+1 each; the Pouch is retired)
		if a in artifacts:
			n += 1
	if "withered_idol" in artifacts:
		n -= 1
	return clampi(n, 3, MAX_ACTIVE)


## The spell as you have it this run: sealed Essence (upgrades) are taken out of its pattern. The card still
## shows them, under a wax seal (full_pattern + seals).
func spell(id: String) -> Dictionary:
	var s: Dictionary = fused[id] if fused.has(id) else db.get_spell(id)
	var extra: String = burdens.get(id, "")
	if extra != "" and not s.is_empty():
		s = s.duplicate(true)
		s.pattern = String(s.pattern) + extra  # cursed: it needs more Essence
		s.size = String(s.pattern).length()
		s.burden = extra
	var sl: Array = seals.get(id, [])
	if sl.is_empty() or s.is_empty():
		return s
	s = s.duplicate(true)
	s.full_pattern = s.pattern
	s.seals = sl.duplicate()
	var p := ""
	for i in String(s.full_pattern).length():
		if not (i in sl):
			p += s.full_pattern[i]
	s.pattern = p
	s.size = p.length()
	return s


# ------------------------------------------------------------------ bottles

func bottle_slots() -> int:
	return Bottles.BASE_SLOTS + (2 if "bandolier" in artifacts else 0)


## Take a bottle if there's a free slot. Returns false when you're full.
func gain_bottle(id: String) -> bool:
	if player.bottles.size() >= bottle_slots() or Bottles.get_def(id).is_empty():
		return false
	player.bottles.append(id)
	return true


## Enemy strength within the act, 1-8, spread over the act's floors.
func depth() -> int:
	return clampi(int(ceil((row + 1) * 7.0 / MapGen.FLOORS)), 1, 8)


## The floor you're on (1-based; the boss is one past the last floor).
func floor_no() -> int:
	return row + 1


# ------------------------------------------------------------------ map

## Columns you can step to next.
func choices() -> Array:
	return MapGen.reachable(map, row, col)


func current_node() -> Dictionary:
	return map[row][col] if row >= 0 and map[row][col] != null else {}


## What the current room really is ("?" rooms are revealed when you enter).
func current_kind() -> String:
	var n := current_node()
	return n.get("as", n.get("type", ""))


func move_to(c: int) -> Dictionary:
	row += 1
	col = c
	return current_node()


## Enemy ids for the fight at the current node.
func encounter_ids() -> Array:
	var kind := current_kind()
	if not (kind in ["fight", "elite", "boss"]):
		kind = "fight"
	var ids: Array
	encounter_name = ""
	if act == 1 and kind == "fight":
		# a hand-made, themed encounter of the tier this floor brings (see EnemyDefs.ENCOUNTERS_ACT1)
		var enc := EnemyDefs.act1_encounter(EnemyDefs.act1_tier(row), rng, recent_encounters)
		ids = enc.ids
		encounter_name = enc.name
		recent_encounters.append(enc.name)
	else:
		ids = EnemyDefs.encounter(kind, act, depth(), rng, met)
	met.append_array(ids)
	encounter = ids.duplicate()
	encounter_extra = ids.map(func(id): return EnemyDefs.extra_for(id, act, depth(), rng, ids.size()))
	return ids


## Exactly the Essence an enemy of this encounter will start the fight with.
func encounter_hp(i: int) -> Array:
	var hp: Array = Array(EnemyDefs.get_def(encounter[i]).hp.split(""))
	return hp + (encounter_extra[i] if i < encounter_extra.size() else [])


# ------------------------------------------------------------------ fights

func make_fight(enemy_ids: Array) -> Fight:
	fight_snapshot = {"hp": player.hp, "max_hp": player.max_hp, "bottles": player.bottles.duplicate(),
		"echo_casts": player.echo_casts, "echo_charged": player.echo_charged,
		"kindling_chants": player.kindling_chants, "kindling_charged": player.kindling_charged}
	var f := Fight.new(db, player)
	f.rng.seed = rng.randi()
	f.artifacts = artifacts
	f.artifact_plus = artifacts_plus
	f.loadout = loadout.map(func(id): return spell(id))
	f.spellbook = spellbook.map(func(id): return spell(id))
	if enemy_ids == encounter:
		f.preset_extra = encounter_extra  # the Essence the player was shown before the fight
	f.start(enemy_ids, act, depth())
	return f


## After a won fight: seedlings, codex, healing. Returns ids newly defeated this run.
func finish_fight(f: Fight) -> void:
	var kind := current_kind()
	if not (kind in ["fight", "elite", "boss"]):
		kind = "fight"
	if not f.won:
		over = true
		return
	kills += f.defeated.size()
	for id in f.defeated:
		if not (id in defeated_ids):
			defeated_ids.append(id)
	seedlings += SEEDLINGS.get(kind, 3)
	reward_bottle = ""
	if rng.randf() < BOTTLE_DROP.get(kind, 0.25):
		var b: String = Bottles.random(rng, 1)[0]
		if gain_bottle(b):
			reward_bottle = b
	var am: Array = AMBER.get(kind, AMBER.fight)
	amber += rng.randi_range(am[0], am[1])
	if "healing_sap" in artifacts:
		player.heal(Artifacts.num("healing_sap", "healing_sap" in artifacts_plus))
	if kind == "boss":
		player.heal(player.max_hp * 0.5)
		if act >= ACTS:
			over = true
			won = true
			seedlings += WIN_BONUS
		else:
			act += 1
			row = -1
			col = MapGen.COLS / 2
			map = MapGen.generate(rng)


## The Seed of Life: lose with it intact and the fight starts over.
func can_revive() -> bool:
	return "seed_of_life" in artifacts and not fight_snapshot.is_empty()


## Put you back as you were when the fight began; the Seed breaks.
func revive() -> void:
	for k in fight_snapshot:
		player.set(k, fight_snapshot[k] if not (fight_snapshot[k] is Array) else fight_snapshot[k].duplicate())
	var i := artifacts.find("seed_of_life")
	if i >= 0:
		artifacts[i] = "broken_seed_of_life"
	artifacts_plus.erase("seed_of_life")
	over = false


## The merchant mends a Broken Seed of Life.
func mend_seed() -> void:
	var i := artifacts.find("broken_seed_of_life")
	if i >= 0:
		artifacts[i] = "seed_of_life"


func is_boss_node() -> bool:
	return current_node().get("type", "") == "boss"


# ------------------------------------------------------------------ rewards

## Spells you don't own yet. Normal fights: each card common (70%) or rare (30%). Elites: rares. Bosses: legendaries.
## The Scholar's Quill adds a 4th card. Offers always mix at least two categories.
func spell_offer(n := 3, kind := "fight") -> Array:
	if "scholar_quill" in artifacts:
		n += int(Artifacts.num("scholar_quill", "scholar_quill" in artifacts_plus)) - 3
	var by_rarity := {"common": [], "rare": [], "legendary": []}
	for id in unlocked_spells:
		if id in spellbook:
			continue
		var s := db.get_spell(id)
		if not s.is_empty() and not s.get("starter", false):  # the starting spells are never offered again
			by_rarity[s.rarity].append(s)
	var out := []
	for i in n:
		var r := "common"
		match kind:
			"elite":
				r = "rare"
			"boss":
				r = "legendary"
			_:
				r = "rare" if rng.randf() < RARE_CHANCE else "common"
		var pool: Array = by_rarity[r]
		if pool.is_empty():  # nothing of that rarity left: fall back to the next one down
			for alt in ["rare", "common", "legendary"]:
				if not by_rarity[alt].is_empty():
					pool = by_rarity[alt]
					break
		if pool.is_empty():
			break
		var pick: Dictionary = pool[rng.randi() % pool.size()]
		pool.erase(pick)
		out.append(pick)
	# always offer at least two categories (offensive / defensive / utility)
	if out.size() >= 2 and out.all(func(s): return s.kind == out[0].kind):
		var want: String = out[-1].rarity
		var others: Array = by_rarity[want].filter(func(s): return s.kind != out[0].kind)
		if others.is_empty():
			for r in by_rarity:
				others.append_array(by_rarity[r].filter(func(s): return s.kind != out[0].kind))
		if not others.is_empty():
			out[out.size() - 1] = others[rng.randi() % others.size()]
	return out


func learn_spell(id: String) -> void:
	if id in spellbook:
		return
	spellbook.append(id)
	if loadout.size() < active_slots():
		loadout.append(id)


func artifact_offer(n := 3) -> Array:
	return Artifacts.offer(unlocked_artifacts, artifacts, rng, n)


## Treasure rooms: two normal artifacts and one cursed one.
func treasure_offer() -> Array:
	return Artifacts.offer(unlocked_artifacts, artifacts, rng, 2) + Artifacts.offer(unlocked_artifacts, artifacts, rng, 1, "curse")


## Bosses: pick one relic that raises your element income.
func boss_relic_offer() -> Array:
	return Artifacts.offer(unlocked_artifacts, artifacts, rng, 3, "boss")


func gain_artifact(id: String) -> void:
	if id in artifacts:
		return
	artifacts.append(id)
	curse_note = ""
	if id == "blood_pact":
		player.max_hp -= 12
		player.hp = minf(player.hp, player.max_hp)
	if id == "broken_crown":
		player.max_hp -= 15
		player.hp = minf(player.hp, player.max_hp)
		curse_note = "−15 max HP."
	if id == "spell_satchel":
		# it eats 2 random spells (you always keep at least one)
		var eaten := lose_random_spells(2)
		curse_note = "It ate %s." % " and ".join(eaten) if not eaten.is_empty() else ""
	if id == "tangled_grimoire":
		# 4 random spells each need 1 more Essence
		var hit := burden_random_spells(4)
		curse_note = "Now needing 1 more Essence: %s." % ", ".join(hit) if not hit.is_empty() else ""
	artifact_gained.emit(id)  # (the UI shows the artifact that was found, and what its curse did)
	if id == "bandolier":
		for b in Bottles.random(rng, 2):
			gain_bottle(b)
	while loadout.size() > active_slots():
		loadout.pop_back()


## Lose an artifact (traded away): what it gave or took goes with it.
func remove_artifact(id: String) -> void:
	artifacts.erase(id)
	artifacts_plus.erase(id)
	if id == "blood_pact":
		player.max_hp += 12
	if id == "broken_crown":
		player.max_hp += 15
	if id == "tangled_grimoire":
		burdens.clear()  # the curse lasts as long as you keep the artifact
	while player.bottles.size() > bottle_slots():
		player.bottles.pop_back()
	while loadout.size() > active_slots():
		loadout.pop_back()


## The Tinker: artifacts you own that have a + version you don't have yet.
func upgradable_artifacts() -> Array:
	return artifacts.filter(func(id): return Artifacts.can_upgrade(id) and not (id in artifacts_plus))


func upgrade_artifact(id: String) -> void:
	if id in artifacts and not (id in artifacts_plus):
		artifacts_plus.append(id)


## The Barterer: artifacts you could trade (another one of the same tier is needed, and a tier above).
const NEXT_TIER := {"common": "rare", "rare": "legendary"}


## (The Seed of Life, whole or broken, is never traded: it's the run's own second chance.)
const UNTRADEABLE := ["seed_of_life", "broken_seed_of_life"]


func tradeable_artifacts(tier := "") -> Array:
	return artifacts.filter(func(id):
		if id in UNTRADEABLE:
			return false
		var t: String = Artifacts.get_def(id).get("tier", "common")
		return NEXT_TIER.has(t) and (tier == "" or t == tier) and artifacts.filter(func(o): return not (o in UNTRADEABLE) and Artifacts.get_def(o).get("tier", "") == t).size() >= 2)


## Up to 3 artifacts of the tier above, not owned and not cursed.
func trade_offer(tier: String) -> Array:
	var want: String = NEXT_TIER.get(tier, "")
	var pool := Artifacts.ALL.filter(func(a): return a.tier == want and not (a.pool in ["curse", "none"]) and a.get("aspect", "") != "Cursed" and not (a.id in artifacts))
	var out := []
	while not pool.is_empty() and out.size() < 3:
		var pick: Dictionary = pool[rng.randi() % pool.size()]
		out.append(pick)
		pool.erase(pick)
	return out


func trade_artifacts(give_a: String, give_b: String, take: String) -> void:
	remove_artifact(give_a)
	remove_artifact(give_b)
	gain_artifact(take)


## Rest site, option 1: heal 30% of max HP.
func rest() -> float:
	return player.heal(player.max_hp * REST_HEAL)


# ------------------------------------------------------------------ fusing (campfires)

## A spell can be fused if it isn't a Power, an anti-spell (they can't be fused: they don't show up at the
## campfire) or fused already.
func can_fuse(id: String) -> bool:
	var s := spell(id)
	return not s.is_empty() and not s.get("power", false) and not s.get("fused", false) and not s.get("anti", false)


## Two spells can be fused together if both are anti-spells or neither is.
func can_fuse_pair(id_a: String, id_b: String) -> bool:
	return can_fuse(id_a) and can_fuse(id_b) and id_a != id_b and spell(id_a).get("anti", false) == spell(id_b).get("anti", false)


func fusable() -> Array:
	return spellbook.filter(func(id): return can_fuse(id))


static var _fusion_names := {}


## The fused spell's name: made up in advance for every pair of spells (data/fusion_names.json), and the same
## whichever order they are fused in.
static func fusion_name(id_a: String, id_b: String, name_a := "", name_b := "") -> String:
	if _fusion_names.is_empty():
		var data = JSON.parse_string(FileAccess.get_file_as_string("res://data/fusion_names.json"))
		_fusion_names = data if data is Dictionary else {"_": ""}
	var ids := [id_a, id_b]
	ids.sort()
	return _fusion_names.get("|".join(ids), "%s %s" % [name_a, name_b])


## Forge the fused spell from two spells (not yet committed): the first spell's pattern comes first and the
## second's follows it. (drop: an Essence taken out of it, by its index among the Essence still needed; -1 = none.
## Fusing at a campfire takes none out: a drop of purple wax seals one Essence of the new spell instead, see the
## FuseScreen.) Wax seals stay where they were: the sealed Essence are still shown
## (and still not needed). It does everything both did.
func fuse_preview(id_a: String, id_b: String, drop := -1) -> Dictionary:
	var a := spell(id_a)
	var b := spell(id_b)
	var order := ["common", "rare", "legendary"]
	var rarity: String = order[maxi(order.find(a.rarity), order.find(b.rarity))]
	var effects: Array = a.effects.duplicate(true) + b.effects.duplicate(true)
	var s := {
		"id": "fused_%d" % (_fuse_count + 1), "name": fusion_name(id_a, id_b, a.name, b.name),
		"pattern": "", "effects": effects, "rarity": rarity,
		"flavor": "Forged at a campfire from %s and %s." % [a.name, b.name],
		"fused": true, "fused_from": [a.name, b.name],
	}
	if a.get("anti", false) and b.get("anti", false):
		# the mirror of a spell fusion: a spell needs one pattern AND then the other; a fused anti-spell keeps both
		# patterns, one row each, and EITHER one in your chant breaks it. It does both effects. (Nothing to shoot.)
		s.anti = true
		s.patterns = [String(a.pattern), String(b.pattern)]
		s.pattern = a.pattern + b.pattern
	else:
		var full_a: String = a.get("full_pattern", a.pattern)
		var full: String = full_a + String(b.get("full_pattern", b.pattern))
		var sl: Array = a.get("seals", []).duplicate()
		for i in b.get("seals", []):
			sl.append(i + full_a.length())
		if drop >= 0:
			# the drop-th Essence that isn't sealed: take it out, and the seals after it move one to the left
			var live := -1
			for i in full.length():
				if i in sl:
					continue
				live += 1
				if live == drop:
					full = full.substr(0, i) + full.substr(i + 1)
					sl = sl.map(func(k): return k - 1 if k > i else k)
					break
		var p := ""
		for i in full.length():
			if not (i in sl):
				p += full[i]
		s.pattern = p
		if not sl.is_empty():
			s.full_pattern = full
			s.seals = sl
	s.size = s.pattern.length()
	s.rarity_name = SpellDB.RARITY_NAMES[rarity]
	s.power = false
	s.starter = false
	s.upgraded = false
	s.kind = SpellDB.kind_of(effects)
	s.targeted = SpellDB._needs_target(effects)
	return s


## Use up the two spells and add the fused one (into the active row if either of them was there).
func fuse_commit(new_spell: Dictionary, id_a: String, id_b: String) -> void:
	_fuse_count += 1
	var was_active := id_a in loadout or id_b in loadout
	for id in [id_a, id_b]:
		spellbook.erase(id)
		loadout.erase(id)
		upgraded.erase(id)
		seals.erase(id)
		burdens.erase(id)  # (a burdened spell's extra Essence is part of the fused pattern now)
	# kept like any spell: its whole pattern, with the seals on top (see spell())
	var stored := new_spell.duplicate(true)
	if stored.has("full_pattern"):
		stored.pattern = stored.full_pattern
		stored.size = stored.pattern.length()
		seals[stored.id] = stored.seals.duplicate()
		stored.erase("full_pattern")
		stored.erase("seals")
	fused[new_spell.id] = stored
	spellbook.append(new_spell.id)
	if was_active and loadout.size() < active_slots():
		loadout.append(new_spell.id)


## Upgrading (the merchant's study session and some events): a wax seal covers one Essence of a spell's
## pattern (index into its full pattern), which then isn't needed any more. A spell sealed down to nothing
## wakes on every chant.
func seal_spell(id: String, idx: int) -> void:
	if not (id in spellbook):
		return
	var full: String = spell(id).get("full_pattern", spell(id).pattern)
	var sl: Array = seals.get(id, [])
	if idx < 0 or idx >= full.length() or idx in sl:
		return
	sl.append(idx)
	sl.sort()
	seals[id] = sl


## Spells that still have an Essence left to seal.
func upgradable() -> Array:
	return spellbook.filter(func(id): return String(spell(id).pattern).length() > 0 and not spell(id).has("patterns"))


## Indices (into the full pattern) of a spell that can still be sealed.
func sealable(id: String) -> Array:
	var s := spell(id)
	var full: String = s.get("full_pattern", s.pattern)
	var out := []
	for i in full.length():
		if not (i in s.get("seals", [])):
			out.append(i)
	return out


# ------------------------------------------------------------------ ? rooms and events

## Reveal a "?" room: sometimes a fight, treasure or a merchant, usually an event you haven't seen this run.
func resolve_unknown() -> String:
	var n := current_node()
	var r := rng.randf()
	var kind := "event"
	for k in UNKNOWN_ODDS:
		if r < UNKNOWN_ODDS[k]:
			kind = k
			break
		r -= UNKNOWN_ODDS[k]
	n["as"] = kind
	if kind == "event":
		var pool := MapEvents.ALL.filter(func(e): return not (e.id in seen_events))
		if pool.is_empty():
			pool = MapEvents.ALL
		var total := 0.0
		for e in pool:
			total += float(e.get("weight", 1.0))
		var r2 := rng.randf() * total
		var ev: Dictionary = pool[-1]
		for e in pool:
			r2 -= float(e.get("weight", 1.0))
			if r2 < 0.0:
				ev = e
				break
		seen_events.append(ev.id)
		n["event"] = ev.id
	return kind


## Can you take this event option (enough Amber / HP)?
func can_choose(opt: Dictionary) -> bool:
	if opt.get("do", "") == "upgrade_artifact" and upgradable_artifacts().is_empty():
		return false
	if opt.get("do", "") == "trade_artifacts" and tradeable_artifacts().is_empty():
		return false
	if spellbook.size() <= opt.get("lose_spells", 0):
		return false  # (you always keep at least one spell)
	return amber >= opt.get("amber", 0) and player.hp > opt.get("hp", 0) and player.max_hp > opt.get("max_hp", 0) + 5


## Do what an event option says. Returns {text, fight: bool}.
func choose_event_option(opt: Dictionary) -> Dictionary:
	amber -= opt.get("amber", 0)
	player.hp -= opt.get("hp", 0)
	if opt.has("max_hp"):
		player.max_hp -= opt.max_hp
		player.hp = minf(player.hp, player.max_hp)
	var price := ""
	if opt.get("lose_spells", 0) > 0:
		price = "Gone: %s. " % ", ".join(lose_random_spells(opt.lose_spells))
	if opt.get("burden", 0) > 0:
		price = "Tangled (1 more Essence each): %s. " % ", ".join(burden_random_spells(opt.burden))
	var res := _do_event_option(opt)
	res.text = price + String(res.text)
	return res


## Take n random spells from your spellbook (you always keep at least one). Returns their names.
func lose_random_spells(n: int) -> Array:
	var names := []
	for k in n:
		if spellbook.size() <= 1:
			break
		var gone: String = spellbook[rng.randi() % spellbook.size()]
		names.append(spell(gone).name)
		spellbook.erase(gone)
		loadout.erase(gone)
		seals.erase(gone)
		burdens.erase(gone)
	return names


## n random spells each need 1 more Essence (a random one, added to the end of the pattern). Returns their names.
func burden_random_spells(n: int) -> Array:
	var pool := spellbook.duplicate()
	var names := []
	for k in mini(n, pool.size()):
		var sid: String = pool.pop_at(rng.randi() % pool.size())
		burdens[sid] = String(burdens.get(sid, "")) + Elements.random(rng)
		names.append(spell(sid).name)
	return names


func _do_event_option(opt: Dictionary) -> Dictionary:
	var n: int = opt.get("n", 0)
	match opt.do:
		"heal":
			return {"text": "You heal %d." % player.heal(n)}
		"amber":
			amber += n
			return {"text": "+%d Leaves." % n}
		"max_hp":
			player.max_hp += n
			player.hp += n
			return {"text": "+%d max HP." % n}
		"upgrade":
			var names := []
			for i in n:
				var ids := upgradable()
				if ids.is_empty():
					break
				var id: String = ids[rng.randi() % ids.size()]
				var free := sealable(id)
				seal_spell(id, free[rng.randi() % free.size()])
				names.append(spell(id).name)
			return {"text": "A purple seal: %s needs one Essence less." % (", ".join(names) if not names.is_empty() else "nothing left to upgrade")}
		"bottle":
			var got := []
			for b in Bottles.random(rng, maxi(1, n)):
				if gain_bottle(b):
					got.append(Bottles.get_def(b).name)
			if got.is_empty():
				amber += opt.get("amber", 0)
				return {"text": "Your bottle slots are full. You keep your Leaves."}
			return {"text": "You take: %s." % ", ".join(got)}
		"spell":
			var pool := unlocked_spells.filter(func(id): return not (id in spellbook) and db.get_spell(id).get("rarity", "") == opt.rarity and not db.get_spell(id).get("starter", false))
			if pool.is_empty():
				amber += opt.get("amber", 0)
				return {"text": "There was nothing left to learn. You keep your Leaves."}
			var id: String = pool[rng.randi() % pool.size()]
			learn_spell(id)
			return {"text": "You learn %s." % db.get_spell(id).name}
		"artifact":
			var a := Artifacts.offer(unlocked_artifacts, artifacts, rng, 1, opt.get("pool", "normal"))
			if a.is_empty():
				return {"text": "It was empty."}
			gain_artifact(a[0].id)
			return {"text": "You gain %s: %s" % [a[0].name, a[0].desc]}
		"curse_amber":
			amber += n
			var c := Artifacts.offer(unlocked_artifacts, artifacts, rng, 1, "curse")
			if c.is_empty():
				return {"text": "+%d Leaves." % n}
			gain_artifact(c[0].id)
			return {"text": "+%d Leaves, and %s clings to you: %s" % [n, c[0].name, c[0].desc]}
		"gamble":
			if rng.randf() < 0.5:
				player.heal(player.max_hp)
				return {"text": "The mushrooms approve. You feel wonderful (healed to full)."}
			return {"text": "The mushrooms do not approve. Something jumps out!", "fight": true}
		"fight":
			return {"text": "It attacks!", "fight": true}
	return {"text": "You move on."}


# ------------------------------------------------------------------ the merchant

## What the merchant sells: 3 spells, 2 artifacts, an upgrade and a meal.
func shop_stock() -> Array:
	var items := []
	var spells := spell_offer(2, "fight") + spell_offer(1, "elite")
	if rng.randf() < 0.3:
		spells += spell_offer(1, "boss")
	var seen := {}
	for s in spells:
		if seen.has(s.id):
			continue
		seen[s.id] = true
		items.append({"kind": "spell", "spell": s, "price": PRICES[s.rarity]})
	for a in artifact_offer(2):
		items.append({"kind": "artifact", "artifact": a, "price": PRICES.artifact_rare if a.tier == "rare" else PRICES.artifact})
	for b in Bottles.random(rng, 2):
		items.append({"kind": "bottle", "bottle": b, "price": Bottles.get_def(b).price})
	items.append({"kind": "upgrade", "price": PRICES.upgrade})
	if "broken_seed_of_life" in artifacts:
		items.append({"kind": "mend_seed", "price": SEED_MEND_PRICE})
	items.append({"kind": "heal", "price": PRICES.heal})
	return items


## Pay for an item (the caller applies it). Returns false if you can't afford it.
func pay(price: int) -> bool:
	if amber < price:
		return false
	amber -= price
	return true


## Seedlings banked at the end (the pouch adds a quarter).
func final_seedlings() -> int:
	var s := seedlings
	if "seedling_pouch" in artifacts:
		s = int(s * (1.0 + Artifacts.num("seedling_pouch", "seedling_pouch" in artifacts_plus)))
	return s


## Loadout order (press and hold a spell before the fight to move it): the spell at `from` goes to `to`.
func move_active(from: int, to: int) -> void:
	if from < 0 or from >= loadout.size():
		return
	var id: String = loadout[from]
	loadout.remove_at(from)
	loadout.insert(clampi(to, 0, loadout.size()), id)


## Loadout drag & drop (before each encounter): spell `id` is let go over the active row (to_active) or the
## spellbook, on top of spell `onto` ("" = empty space). Dropped on another spell, the two switch places (in the row,
## between the row and the book, or in the book's order). False when it can't go there (the active row is full).
func drop_spell(id: String, to_active: bool, onto := "") -> bool:
	if not (id in spellbook) or onto == id:
		return id in spellbook
	var from_active := id in loadout
	var onto_active := onto in loadout
	if to_active:
		if onto_active:
			var j := loadout.find(onto)
			if from_active:
				loadout[loadout.find(id)] = onto  # two active spells switch places
			loadout[j] = id  # (a spellbook spell takes its place: the other one goes back to the book)
			return true
		if from_active:
			loadout.erase(id)
			loadout.append(id)  # dropped on an empty slot: to the end of the row
			return true
		if loadout.size() >= active_slots():
			return false
		loadout.append(id)
		return true
	# over the spellbook
	if from_active:
		if onto != "" and onto in spellbook and not onto_active:
			loadout[loadout.find(id)] = onto  # it switches places with the spell it was dropped on
		else:
			loadout.erase(id)
		return true
	if onto != "" and onto in spellbook and not onto_active:
		var a := spellbook.find(id)
		var b := spellbook.find(onto)
		spellbook[a] = onto
		spellbook[b] = id
	return true


## Loadout editing (before each encounter).
func toggle_active(id: String) -> bool:
	if id in loadout:
		loadout.erase(id)
		return true
	if loadout.size() >= active_slots() or not (id in spellbook):
		return false
	loadout.append(id)
	return true
