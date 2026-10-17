class_name RopeSets
extends RefCounted
## The enemies of a room type and act, grouped in sets of four for the rope mode (RopeEditor): every normal enemy of the act for a fight room; the
## act's elites (a group such as the Triplet stays together) and the enemies they bring in, for an elite room; the bosses and what they summon, for a boss
## room. What a boss or an elite summons is left out when it is one of the act's normal enemies (those are done in the fight room).

const SET_SIZE := 4
const SOLO := ["handyman"]  # (his six hands fill the stage: he stands alone; the ropes go on his body, the hands are rigs)
## Enemies that come in two colours: the black one has its own picture, so it is a set member of its own, written "<id>@black".
const TWO_COLOURS := ["yin_yang_beast", "yin_yang_clone"]
## Enemies a passive brings into the fight (their summon moves are found by reading the moves).
const PASSIVE_SUMMONS := {"yinyang_split": ["yin_yang_clone"]}


static func build(kind: String, act: int) -> Array:
	var ids: Array = []
	match kind:
		"fight":
			ids = _normals(act)
		"elite":
			for g in EnemyDefs.ELITE_GROUPS:
				if EnemyDefs.ELITE_GROUPS[g].act == act:
					ids.append_array(EnemyDefs.ELITE_GROUPS[g].ids)
			for k in EnemyDefs.E:
				var d: Dictionary = EnemyDefs.E[k]
				if d.get("elite", false) and not d.get("member", false) and d.act == act:
					ids.append(k)
			ids = _with_summons(ids, act)
		"boss":
			ids = _with_summons(EnemyDefs.BOSSES.get(act, []), act)
	ids = ids.filter(func(id): return _has_art(id, act))
	var all: Array = []
	for id in ids:
		all.append(id)
		if id in TWO_COLOURS:
			all.append(id + "@black")
	ids = all
	var sets: Array = []
	var cur: Array = []
	for id in ids:
		if id in SOLO:
			if not cur.is_empty():
				sets.append(cur)
				cur = []
			sets.append([id])
			continue
		cur.append(id)
		if cur.size() == SET_SIZE:
			sets.append(cur)
			cur = []
	if not cur.is_empty():
		sets.append(cur)
	return sets


static func _with_summons(ids: Array, act: int) -> Array:
	var out: Array = ids.duplicate()
	var normals := _normals(act)
	for id in ids:
		for s in _summons_of(id):
			if not (s in out) and not (s in normals):
				out.append(s)
	return out


## Who an enemy can bring in: summon moves (either phase, also inside `also`), the passives that split it, the Invoker's summoning spell.
static func _summons_of(id: String) -> Array:
	var d: Dictionary = EnemyDefs.E[id]
	var out: Array = []
	for list in [d.get("moves", []), d.get("moves2", [])]:
		for m in list:
			_collect(m, out)
	for p in d.get("passives", []):
		out.append_array(PASSIVE_SUMMONS.get(p, []))
	if id == "invoker":
		for s in EnemyDefs.INVOKER_SPELLS:
			if s.has("cast"):
				_collect(s.cast, out)
	return out.filter(func(s): return EnemyDefs.E.has(s))


static func _collect(m: Dictionary, out: Array) -> void:
	if m.get("kind", "") == "summon":
		if m.has("id"):
			out.append(m.id)
		out.append_array(m.get("ids", []))
	if m.has("also"):
		_collect(m.also, out)


## Only an enemy with a picture of its own in the Puppet Stage can take ropes (a Handyman hand is a rig, not a picture).
static func _has_art(id: String, act: int) -> bool:
	for file in [Creature.PUPPET_FILES.get(id, id), id + "_white"]:
		if Creature.enemy_path(file + ".png", int(EnemyDefs.E[id].get("act", act))) != "":
			return true
	return false


## The act's normal enemies: the ones that come into a fight on their own (a "member" only ever arrives with a boss or an elite).
static func _normals(act: int) -> Array:
	return EnemyDefs.normals(act).filter(func(id): return not EnemyDefs.E[id].get("member", false))


## The enemy id of a set member ("yin_yang_beast@black" is the Yin Yang Beast, black).
static func real_id(token: String) -> String:
	return token.get_slice("@", 0)


static func is_black(token: String) -> bool:
	return token.ends_with("@black")


## The key the ropes of a set member are kept under (the black one has its own picture, so its own ropes).
static func rope_key(id: String, yin: String) -> String:
	return id if yin == "" else "%s_%s" % [id, yin]
