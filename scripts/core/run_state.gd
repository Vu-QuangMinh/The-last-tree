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
## Spell reward odds, Slay the Spire's (their common / uncommon / rare = our Common / Rare / Legendary), per card:
## [Common, Rare, Legendary]. A boss always gives Legendary.
const ODDS := {"fight": [0.60, 0.37, 0.03], "elite": [0.50, 0.40, 0.10], "shop": [0.54, 0.37, 0.09]}
## Their hidden pity counter: the Legendary chance starts 5% lower, rises 1% with every Common you're shown, and drops
## back when a Legendary shows up.
const LEGENDARY_OFFSET_START := -0.05
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
var poison_next := 0  # the Whispering Well: Poison you start your next fight with
var fight_gift: Array = []  # Essence you start your next fight with (the Lost Sprite's 2 Air)
var due_events := {}  # event id -> how many events from now it comes, whatever the act (the Flying Turtle falling on you, the Rolling Bear's revenge)
var stun_next := 0  # turns you start your next fight Stunned (the Rolling Bear's revenge)
var encounter: Array = []  # the ids of the encounter being prepared
var encounter_name := ""  # its name (Act 1's hand-made encounters, e.g. "The Slime Trio"; "" otherwise)
var recent_encounters: Array = []  # names of the encounters met so far (an encounter never comes up twice in 3)
var encounter_extra: Array = []  # the extra Essence each of those enemies will have (rolled once)
var first_run := false  # the player's very first run (and the Anxious Armadillo not met yet): he waits in Act 2's 2nd fight
var fight_rooms: Array = []  # "act:row:col" of every normal fight room entered (to count Act 2's fights)
var fused := {}  # id -> spell dict, for spells forged at campfires ("fused_1", ...)
var inverted: Array = []  # spell ids inverted for the run (the Upside-Down Pool): a spell plays as an anti-spell, and back
var _fuse_count := 0
var over := false
var won := false
var reward_bottle := ""  # a bottle found after the last fight ("" if none)
var free_pick: Array = []  # the merchant's thanks: "spell" / "artifact": the next one of that kind you take from him is free
var merchant_talked := ""  # the room ("act:row:col") where you last talked with the merchant (one favour a visit)
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
	# spells removed from the game since this run was saved are dropped
	var known := func(id) -> bool: return r.fused.has(id) or not p_db.get_spell(id).is_empty()
	r.spellbook = r.spellbook.filter(known)
	r.loadout = r.loadout.filter(known)
	r.unlocked_spells = r.unlocked_spells.filter(known)
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
	n += artifacts.count("mystery_book")  # (+1 for every Mystery Book: they stack)
	if "withered_idol" in artifacts:
		n -= 1
	return clampi(n, 3, MAX_ACTIVE)


## The spell as you have it this run: sealed Essence (upgrades) are taken out of its pattern. The card still
## shows them, under a wax seal (full_pattern + seals).
func spell(id: String) -> Dictionary:
	var s: Dictionary = fused[id] if fused.has(id) else db.get_spell(id)
	if id in inverted and not s.is_empty():
		s = s.duplicate(true)
		s.anti = not s.get("anti", false)
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
	var key := "%d:%d:%d" % [act, row, col]
	if kind == "fight" and not (key in fight_rooms):
		fight_rooms.append(key)
	var act_fights := fight_rooms.filter(func(k): return String(k).begins_with("%d:" % act)).size()
	if first_run and act == 2 and kind == "fight" and act_fights == 2:
		ids = ["anxious_armadillo"]  # (once ever: main.gd records it when the fight starts)
		encounter_name = "The Anxious Armadillo"
	elif act == 1 and kind == "fight":
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


## Test mode: swap the encounter being prepared for these enemies (their extra Essence rolled the usual way).
func set_encounter(ids: Array) -> void:
	encounter = ids.duplicate()
	encounter_name = ""
	encounter_extra = ids.map(func(id): return EnemyDefs.extra_for(id, act, depth(), rng, ids.size()))


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
	if not enemy_ids.is_empty():
		# what an event left for this fight: Poison (the Whispering Well), Essence to start with (the Lost Sprite)
		if poison_next > 0:
			player.poison += poison_next
			poison_next = 0
		if stun_next > 0:
			player.stun_turns = maxi(player.stun_turns, stun_next)  # (the Rolling Bear knocked you silly)
			stun_next = 0
		for el in fight_gift:
			player.add_element(Elements.random(rng) if el == "random" else String(el))
		fight_gift.clear()
	return f


## After a won fight: seedlings, codex, healing. Returns ids newly defeated this run.
func finish_fight(f: Fight) -> void:
	var kind := current_kind()
	if not (kind in ["fight", "elite", "boss"]):
		kind = "fight"
	if not f.won:
		over = true
		return
	for id in f.exhausted:  # Exhausted spells: gone for the rest of the run
		spellbook.erase(id)
		loadout.erase(id)
	if f.trinity_formed:
		form_trinity()
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
	if "half_eaten_candy" in artifacts:
		player.heal(2.0)  # (the Half-Eaten Candy)
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
var legendary_offset := LEGENDARY_OFFSET_START  # (the pity counter, see ODDS)


## One card's rarity for a reward of this kind (fight, elite, shop, boss), moving the pity counter.
func _roll_rarity(kind: String) -> String:
	if kind == "boss":
		return "legendary"
	var o: Array = ODDS.get(kind, ODDS.fight)
	var leg := maxf(0.0, o[2] + (legendary_offset if kind != "shop" else 0.0))
	var r := rng.randf()
	if r < leg:
		if kind != "shop":
			legendary_offset = LEGENDARY_OFFSET_START
		return "legendary"
	if r < leg + o[1]:
		return "rare"
	if kind != "shop":
		legendary_offset += 0.01
	return "common"


func spell_offer(n := 3, kind := "fight") -> Array:
	if "scholar_quill" in artifacts:
		n += int(Artifacts.num("scholar_quill", "scholar_quill" in artifacts_plus)) - 3
	var by_rarity := {"common": [], "rare": [], "legendary": []}
	for id in unlocked_spells:
		if id in spellbook:
			continue
		var s := db.get_spell(id)
		if not s.is_empty() and not s.get("starter", false) and by_rarity.has(s.rarity):  # (never the starters, nor Unique ones)
			by_rarity[s.rarity].append(s)
	var out := []
	for i in n:
		var r := _roll_rarity(kind)
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
	if id in artifacts and not Artifacts.get_def(id).get("stack", false):
		return
	artifacts.append(id)
	if id == "mystery_book" and artifacts.count("mystery_book") >= 3 and not ("summoning_bill" in spellbook):
		learn_spell("summoning_bill")  # (three Mystery Books: their pages glow, and a spell writes itself into your mind)
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
	return not s.is_empty() and not s.get("power", false) and not s.get("fused", false) and not s.get("anti", false) and not s.get("no_fuse", false)


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
	if not (a.get("anti", false) and b.get("anti", false)):
		var key := [id_a, id_b]
		key.sort()
		effects = FuseRules.merge(effects, "|".join(key))  # (an override for this pair, if one was hand-made)
	var s := {
		"id": "fused_%d" % (_fuse_count + 1), "name": fusion_name(id_a, id_b, a.name, b.name),
		"pattern": "", "effects": effects, "rarity": rarity,
		"flavor": "Forged at a campfire from %s and %s." % [a.name, b.name],
		"fused": true, "fused_from": [a.name, b.name],
	}
	var cd := maxi(int(a.get("cooldown", 0)), int(b.get("cooldown", 0)))
	if cd > 0:
		s.cooldown = cd  # (both have one: the stricter, Cooldown 1 + Cooldown 2 = Cooldown 2; Durability keeps the lower)
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
	# Durability: a fused spell keeps the lowest Durability of the two (a spell without Durability doesn't count)
	var durs: Array[int] = []
	for x in [a, b]:
		var d := int(x.get("durability", 1 if x.get("fleeting", false) else 0))
		if d > 0:
			durs.append(d)
	if not durs.is_empty():
		s.durability = durs.min()
	s.size = s.pattern.length()
	s.rarity_name = SpellDB.RARITY_NAMES[rarity]
	s.power = false
	s.starter = false
	s.upgraded = false
	s.kind = SpellDB.kind_of(effects)
	s.targeted = SpellDB._needs_target(effects)
	return s


## The three Trinity Fragments became Trinity in a fight: it takes their place for the rest of the run (in the active
## row where the first of them was, if any was there).
func form_trinity() -> void:
	var at := -1
	for id in Fight.TRINITY_PARTS:
		var i := loadout.find(id)
		if i >= 0 and (at < 0 or i < at):
			at = i
		spellbook.erase(id)
		loadout.erase(id)
		upgraded.erase(id)
		seals.erase(id)
		burdens.erase(id)
	if not ("trinity" in spellbook):
		spellbook.append("trinity")
	if at >= 0 and not ("trinity" in loadout):
		loadout.insert(mini(at, loadout.size()), "trinity")


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
	if kind == "event" and not due_events.is_empty():
		# a promise kept (the Flying Turtle, the Rolling Bear): when its count runs out, this event is it, in any act
		var now := ""
		for id in due_events.keys():
			due_events[id] = int(due_events[id]) - 1
			if int(due_events[id]) <= 0 and now == "":
				now = id
		if now != "":
			due_events.erase(now)
			for id in due_events:
				due_events[id] = maxi(1, int(due_events[id]))  # (two due at once: the other waits for the next one)
			n["as"] = "event"
			n["event"] = now
			return "event"
	var can_meet := MapEvents.ALL.filter(func(e): return act in e.get("acts", [1, 2, 3]) and not e.get("hidden", false) and not (String(e.get("unless_artifact", "")) in artifacts))
	if kind == "event" and can_meet.is_empty():
		kind = "fight"  # (no events in this act yet: the room is a fight)
	n["as"] = kind
	if kind == "event":
		var pool := can_meet.filter(func(e): return not (e.id in seen_events))
		if pool.is_empty():
			pool = can_meet
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
	if opt.has("outcomes") or opt.has("next") or opt.has("minigame") or opt.has("by_water") or opt.has("by_kind") or opt.has("recycle") or opt.has("fuse"):
		# (the rewritten events: only a Leaves price, or having a bottle to throw, can grey an option out)
		if opt.has("recycle"):
			return not recyclable(String(opt.recycle)).is_empty()
		if opt.has("fuse"):
			return fusable().size() >= 2  # (two spells that can be fused)
		if waxable_spots() < int(opt.get("wax", 0)):
			return false  # (the Wax Witch: no Essence left to seal)
		if giftable_artifacts().size() < int(opt.get("pick_artifact", 0)):
			return false  # (the Mystery Shed wants two toys)
		return amber >= int(opt.get("amber", 0)) and (not opt.get("pick_bottle", false) or not player.bottles.is_empty()) \
			and (not opt.get("pick_spell", false) or spellbook.size() > 1 or opt.get("keep_spell", false))  # (you always keep at least one spell)
	if opt.get("do", "") == "upgrade_artifact" and upgradable_artifacts().is_empty():
		return false
	if opt.get("do", "") == "trade_artifacts" and tradeable_artifacts().is_empty():
		return false
	if opt.get("do", "") == "invert_spell" and (invertible_spells().is_empty() or player.hp < 2):
		return false
	if opt.get("do", "") == "note_swap" and (storable_spells().is_empty() or db.get_spell(note_spell_id()).is_empty()):
		return false
	if spellbook.size() <= opt.get("lose_spells", 0):
		return false  # (you always keep at least one spell)
	return amber >= opt.get("amber", 0) and player.hp > opt.get("hp", 0) and player.max_hp > opt.get("max_hp", 0) + 5


## A Note to Yourself: the spell waiting in the note (from the save; Aole's Blessing the first time).
var note_store: Object = null  # (where the note is kept: the SaveManager; a test sets its own)


func _notes() -> Object:
	if note_store != null:
		return note_store
	var tree := Engine.get_main_loop() as SceneTree
	return tree.root.get_node_or_null("SaveManager") if tree != null else null


func note_spell_id() -> String:
	var sm := _notes()
	return String(sm.call("note_spell")) if sm != null else "trade_winds"


## Spells you can leave in the note: your own, not fused ones (a fused spell only lives in this run). It's stored plain:
## its seals, curses and inversion stay behind.
func storable_spells() -> Array:
	return spellbook.filter(func(id): return not fused.has(id))


## Take the note's spell into your spellbook and leave `leave` in the note (it goes from your spellbook). Returns the
## id taken.
func note_swap(leave: String) -> String:
	var take := note_spell_id()
	learn_spell(take)
	if leave != take:
		spellbook.erase(leave)
		loadout.erase(leave)
		seals.erase(leave)
		burdens.erase(leave)
		inverted.erase(leave)
	var sm := _notes()
	if sm != null:
		sm.call("set_note_spell", leave)
	return take


## Spells the Upside-Down Pool can flip (not Powers).
func invertible_spells() -> Array:
	return spellbook.filter(func(id): return not spell(id).get("power", false))


## The Upside-Down Pool: pay half your HP (rounded down), and the spell plays inverted for the rest of the run.
func invert_spell(id: String) -> String:
	player.hp -= floorf(player.hp * 0.5)
	if id in inverted:
		inverted.erase(id)
	else:
		inverted.append(id)
	var s := spell(id)
	return "%s is %s now." % [s.name, "an anti-spell" if s.get("anti", false) else "a spell again"]


## An artifact found in an event that unlocks it ("unlock_by"): unlocked for good, so it can turn up anywhere later.
func _unlock_found(id: String) -> void:
	if Artifacts.get_def(id).get("unlock_by", "") == "":
		return
	var sm := _notes()
	if sm != null and sm.has_method("unlock_artifact"):
		sm.call("unlock_artifact", id)


## The Recycler: what you could give him of a kind ("spell" / "artifact" / "bottle"): only things he has 3 of the same
## kind and rarity to offer back for. (Not fused spells, curses or the Seed of Life.)
func recyclable(kind: String) -> Array:
	var have: Array
	match kind:
		"spell":
			have = spellbook.filter(func(id): return not fused.has(id))
		"artifact":
			have = artifacts.filter(func(id): return not Artifacts.is_curse(id) and not (id in ["seed_of_life", "broken_seed_of_life"]))
		_:
			have = player.bottles.duplicate()
	var out := []
	for id in have:
		if not (id in out) and recycle_offer(kind, id, true).size() >= 3:
			out.append(id)
	return out


## A bottle's "rarity", by its price: 0 cheap (under 30 Leaves), 1 middling (under 45), 2 dear.
static func bottle_band(id: String) -> int:
	var price := int(Bottles.get_def(id).get("price", 0))
	return 0 if price < 30 else (1 if price < 45 else 2)


## Three things of the same kind and rarity as `id` (that you don't have), for the Recycler to offer. `all`: every
## candidate (to know if there are enough), not just 3 picked at random.
func recycle_offer(kind: String, id: String, all := false) -> Array:
	var pool: Array
	match kind:
		"spell":
			var rarity: String = spell(id).get("rarity", "common")
			pool = unlocked_spells.filter(func(x): return not (x in spellbook) and not db.get_spell(x).get("starter", false) \
				and not db.get_spell(x).get("hidden", false) and db.get_spell(x).get("rarity", "") == rarity)
		"artifact":
			var a := Artifacts.get_def(id)
			pool = Artifacts.ALL.filter(func(x): return x.pool == a.pool and x.tier == a.tier and x.id != id and (x.id in unlocked_artifacts or x.starter) \
				and (not (x.id in artifacts) or x.get("stack", false))).map(func(x): return x.id)
		_:
			var band := bottle_band(id)
			pool = Bottles.ALL.filter(func(b): return not b.get("no_offer", false) and b.id != id and bottle_band(b.id) == band).map(func(b): return b.id)
	if all:
		return pool
	var out := []
	pool = pool.duplicate()
	while out.size() < 3 and not pool.is_empty():
		out.append(pool.pop_at(rng.randi() % pool.size()))
	return out


## The Recycler: `give` goes onto his cart, `take` is yours.
func recycle(kind: String, give: String, take: String) -> void:
	match kind:
		"spell":
			spellbook.erase(give)
			loadout.erase(give)
			seals.erase(give)
			burdens.erase(give)
			inverted.erase(give)
			learn_spell(take)
		"artifact":
			remove_artifact(give)
			gain_artifact(take)
		_:
			var at := player.bottles.find(give)
			if at >= 0:
				player.bottles[at] = take  # (into the same slot)


## Spells that can still take a wax seal, and how many seals there is room for in all.
func waxable_spells() -> Array:
	return upgradable().filter(func(id): return not sealable(id).is_empty())


func waxable_spots() -> int:
	var n := 0
	for id in waxable_spells():
		n += sealable(id).size()
	return n


## Artifacts you can give away as a toy (the Mystery Shed): not curses, not the Seed of Life.
func giftable_artifacts() -> Array:
	return artifacts.filter(func(id): return not Artifacts.is_curse(id) and not (id in ["seed_of_life", "broken_seed_of_life"]))


## A rewritten event's option: pay its Leaves (and give away the bottle at `bottle_at`, if it asks for one), roll
## one of its outcomes and do it. Returns {text (what the player reads), fight: {kind, ids?} (a fight starts),
## artifact: id (gained, to show), overflow: [bottle ids that didn't fit in your slots]}.
func event_outcome(opt: Dictionary, bottle_at := -1, spell_id := "") -> Dictionary:
	amber -= int(opt.get("amber", 0))
	if opt.get("pick_bottle", false) and bottle_at >= 0 and bottle_at < player.bottles.size():
		player.bottles.remove_at(bottle_at)
	var outs: Array = opt.get("outcomes", [])
	var out: Dictionary = outs[-1] if not outs.is_empty() else {}
	if opt.has("by_kind"):
		# the Overgrown Vine: the outcome follows the category of the spell you cast (you keep it)
		out = opt.by_kind.get(String(spell(spell_id).get("kind", "utility")), opt.by_kind.utility)
	elif opt.has("by_water"):
		# Climate Change: the outcome follows how many Water the spell you give has (its whole pattern, seals too)
		var sp := spell(spell_id)
		var waters := String(sp.get("full_pattern", sp.get("pattern", ""))).count("W")
		out = opt.by_water[mini(waters, opt.by_water.size() - 1)]
	else:
		var r := rng.randf()
		for o in outs:
			r -= float(o.get("chance", 1.0))
			if r < 0.0:
				out = o
				break
	var res := {"text": String(out.text), "overflow": []}
	if out.has("then"):
		res.then = out.then  # (a page of choices comes next, under these words)
	for d in out.get("do", []):
		match String(d.op):
			"lose_spell":
				# Far from Any Road: the spell you picked burns, for good
				res.text = String(res.text).replace("{spell}", spell(spell_id).get("name", "Your spell"))
				spellbook.erase(spell_id)
				loadout.erase(spell_id)
				seals.erase(spell_id)
				burdens.erase(spell_id)
				inverted.erase(spell_id)
			"bottles", "bottle_ids":
				var ids: Array = Bottles.random(rng, int(d.n)) if d.op == "bottles" else d.ids
				for b in ids:
					if not gain_bottle(b):
						res.overflow.append(b)
			"poison_next":
				poison_next += int(d.n)
			"grudge":
				due_events[String(d.event)] = int(d.n)
			"soak":
				# the Broken Bridge: a random active spell gets wet, and needs 1 more Water (at the end of its pattern)
				var pool := loadout.filter(func(x): return String(spell(x).get("pattern", "")) != "")
				if pool.is_empty():
					pool = spellbook.filter(func(x): return String(spell(x).get("pattern", "")) != "")
				if not pool.is_empty():
					var wet: String = pool[rng.randi() % pool.size()]
					burdens[wet] = String(burdens.get(wet, "")) + "W"
					res.text = String(res.text).replace("{spell}", spell(wet).name)
					res.spell = wet
				else:
					res.text = String(res.text).replace("{spell}", "a spell")
			"rest_half":
				var healed := player.heal(floorf(player.max_hp * REST_HEAL * 0.5))  # (half what a campfire's rest heals, rounded down)
				res.text = String(res.text).replace("{n}", str(int(healed)))
			"blood":
				# the Wax Witch: each drop is 20% of your max HP, rounded down (the second drop from what is left)
				var lost := 0
				for k in int(d.n):
					var drop := int(floor(player.max_hp * 0.2))
					player.max_hp = maxf(1.0, player.max_hp - drop)
					lost += drop
				player.hp = minf(player.hp, player.max_hp)
				res.text = String(res.text).replace("{n}", str(lost))
			"mystery_book":
				for toy in spell_id.split(",", false):
					remove_artifact(toy)  # (the toys you gave them: their ids come in as "a,b")
				gain_artifact("mystery_book")
				res.artifact = "mystery_book"
				_unlock_found("mystery_book")
				if "summoning_bill" in spellbook and artifacts.count("mystery_book") == 3:
					res.text = String(res.text) + "\n\nAs the third Mystery Book touches the other two, their pages begin to glow, and a spell writes itself into your mind: Summoning Bill."
					res.spell = "summoning_bill"
			"damage":
				var hurt := int(d.n) if d.has("n") else rng.randi_range(int(d.min), int(d.max))
				player.take_effect(float(hurt))  # (it can kill: the screen ends the run then)
				res.text = String(res.text).replace("{n}", str(hurt))
			"heal":
				player.heal(float(d.n))
			"max_hp":
				player.max_hp += float(d.n)
				player.heal(float(d.n))
			"amber":
				amber += int(d.n)
			"artifact":
				var a := Artifacts.offer(unlocked_artifacts, artifacts, rng, 1, String(d.get("pool", "normal")))
				if not a.is_empty():
					gain_artifact(a[0].id)
					res.artifact = a[0].id
			"gift":
				fight_gift.append_array(d.els)  # (Essence you start your next fight with: "random" is any element)
			"learn_spell":
				if String(d.id) in spellbook and d.get("else", "") == "heal_full":
					player.heal(player.max_hp)
					res.text = String(out.get("text_if_owned", res.text))
				else:
					learn_spell(String(d.id))
					res.spell = String(d.id)
			"artifact_tier":
				# a random normal artifact of that tier (another tier if none is left)
				var pool := Artifacts.ALL.filter(func(x): return x.pool == "normal" and (x.id in unlocked_artifacts or x.starter) and not (x.id in artifacts))
				var of_tier := pool.filter(func(x): return x.tier == String(d.tier))
				if of_tier.is_empty():
					of_tier = pool
				if not of_tier.is_empty():
					var pick: Dictionary = of_tier[rng.randi() % of_tier.size()]
					gain_artifact(pick.id)
					res.artifact = pick.id
			"artifact_id":
				if not (String(d.id) in artifacts):
					gain_artifact(String(d.id))
					res.artifact = String(d.id)
					_unlock_found(String(d.id))
			"fight":
				res.fight = {"kind": String(d.get("kind", "fight")), "ids": d.get("ids", [])}
				fight_gift.append_array(d.get("gift", []))
	return res


## They See Me Rolling: you stopped the bear (50 Leaves, 5 damage), or stepped aside (his revenge, 3 events later).
func bear_choice(what: String) -> void:
	if what == "stop":
		amber += 50
		player.take_effect(5.0)
	elif what == "away":
		due_events["bear_revenge"] = 3


## The Farmer's Farm, after the shooting: 1 Leaf a goblin, 5 a hobgoblin, -2 a fairy (your Leaves never go below
## 0). Returns {total, text}: the farmer's tally.
func farm_reward(goblins: int, hobgoblins: int, fairies: int) -> Dictionary:
	var total := goblins + 5 * hobgoblins - 2 * fairies
	amber = maxi(0, amber + total)
	var count := "The farmer counts on his fingers. \"Let's see: %d goblin%s, %d hobgoblin%s and... %d fair%s.\" " % [
		goblins, "" if goblins == 1 else "s", hobgoblins, "" if hobgoblins == 1 else "s", fairies, "y" if fairies == 1 else "ies"]
	var say := ""
	if total > 0:
		say = "\"That comes to %d Leaves. You've earned every one of them.\" He presses them into your hand." % total
	elif total == 0:
		say = "\"That comes to nothing at all. Well, thank you for trying, I suppose.\""
	else:
		say = "\"That's %d Leaves you owe me, I'm afraid. The fairies' families will need them more than you.\" He holds out his hat." % -total
	if fairies == 0 and goblins + hobgoblins > 0:
		say += " \"And not a single fairy hurt. Bless you.\""
	return {"total": total, "text": count + say}


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
			return {"text": "You learn %s." % db.get_spell(id).name, "spell": id}  # ("spell": the screen shows its card)
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

## What the merchant sells: 3 spells, 2 artifacts, an upgrade and a meal. `discount`: his 10% once he's drunk.
func shop_stock(discount := 0.0) -> Array:
	var items := []
	var spells := spell_offer(3, "shop")
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
	if "dollar_bill" in artifacts:
		discount = 1.0 - (1.0 - discount) * 0.8  # (the Dollar Bill: 20% off, on top of any other discount)
	if discount > 0.0:
		for it in items:
			it.price = int(round(it.price * (1.0 - discount)))
	return items


## What an item on his shelf costs you now: nothing if he owes you one of that kind (see free_pick).
func shop_price(it: Dictionary) -> int:
	return 0 if it.kind in free_pick else int(it.price)


## This room, as the merchant remembers it.
func room_key() -> String:
	return "%d:%d:%d" % [act, row, col]


## You hand over favour n (0, 1, 2): the item goes to him, and he pays you back on this visit's shelf.
func merchant_reward(n: int, stock: Array) -> void:
	remove_artifact(MerchantQuests.ITEMS[n])
	match n:
		0:
			free_pick.append("spell")
		1:
			free_pick.append("artifact")
		2:
			for it in stock:
				if it.kind == "bottle":
					it.price = 0  # (all his bottles: yours, as many as you have room for)


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
