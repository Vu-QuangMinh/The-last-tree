extends Node
## Persistent progress: Seedlings, unlocked spells and artifacts, the codex, settings, stats.

const VERSION := 3
const SPELL_COST := {"common": 15, "rare": 30, "legendary": 60}
const POWER_EXTRA := 10
## Unlocked from the first run (plus the four starters): commons, some rares, and enough legendaries for the bosses.
const DEFAULT_SPELLS := ["ember", "spark", "droplet", "mist", "whisper", "updraft", "twin_flames", "flare",
	"tide_pool", "cyclone", "fan_the_flames", "steam", "scald", "mist_veil", "rain", "inferno", "glacier",
	"tempest", "thermal_burst", "whirlpool", "alchemy", "clear_sight", "bandage", "kindle",
	"spark_word", "spring_word", "breath_word", "firestorm", "storm_front", "leech", "searing_mist", "blight_wind",
	"resonance", "steam_cloud",
	"meteor", "tidal_wave", "hurricane", "supernova", "deluge", "grimoire", "triune_chant"]

var path := "user://save.json"  # tests point this elsewhere
var data := {}


func _init() -> void:
	load_game()


func _default() -> Dictionary:
	return {"version": VERSION, "seedlings": 0, "spells": [], "artifacts": [], "codex": [],
		"settings": {}, "stats": {"runs": 0, "wins": 0, "best_act": 0, "kills": 0}}


## Redirects saving to another file with fresh data (used by the headless tests and the sim).
func use_test_file(p: String) -> void:
	path = p
	if FileAccess.file_exists(p):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(p))
	data = _default()


func load_game() -> void:
	data = _default()
	if not FileAccess.file_exists(path):
		return
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not (parsed is Dictionary):
		return
	if int(parsed.get("version", 1)) < VERSION:
		# older designs: keep the Seedlings, reset unlocks (the spells are different now)
		data.seedlings = int(parsed.get("seedlings", parsed.get("seeds", 0)))
		return
	for k in parsed:
		data[k] = parsed[k]


func save_game() -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(data, "\t"))


# ------------------------------------------------------------------ spells

func unlocked_spells() -> Array:
	var out: Array = GameData.db.starters().map(func(s): return s.id)
	for id in DEFAULT_SPELLS + Array(data.spells):
		if not (id in out):
			out.append(id)
	return out


func is_unlocked(id: String) -> bool:
	return id in unlocked_spells()


func spell_cost(spell: Dictionary) -> int:
	return SPELL_COST.get(spell.rarity, 30) + (POWER_EXTRA if spell.power else 0)


func buy_spell(spell: Dictionary) -> bool:
	var cost := spell_cost(spell)
	if is_unlocked(spell.id) or data.seedlings < cost:
		return false
	data.seedlings -= cost
	data.spells.append(spell.id)
	save_game()
	return true


# ------------------------------------------------------------------ artifacts

func unlocked_artifacts() -> Array:
	var out: Array = Artifacts.ALL.filter(func(a): return a.starter).map(func(a): return a.id)
	for id in data.artifacts:
		if not (id in out):
			out.append(id)
	return out


func buy_artifact(id: String) -> bool:
	var a := Artifacts.get_def(id)
	if a.is_empty() or id in unlocked_artifacts() or data.seedlings < a.cost:
		return false
	data.seedlings -= a.cost
	data.artifacts.append(id)
	save_game()
	return true


# ------------------------------------------------------------------ codex

func in_codex(enemy_id: String) -> bool:
	return enemy_id in data.codex


## Adds defeated enemies; returns the ids that are new.
func add_to_codex(ids: Array) -> Array:
	var fresh := []
	for id in ids:
		if not (id in data.codex):
			data.codex.append(id)
			fresh.append(id)
	if not fresh.is_empty():
		save_game()
	return fresh


# ------------------------------------------------------------------ settings & stats

func setting(key: String, default = null):
	return data.settings.get(key, default)


func set_setting(key: String, value) -> void:
	data.settings[key] = value
	save_game()


func record_run(seedlings: int, act_reached: int, kills: int, victory: bool) -> void:
	data.seedlings += seedlings
	data.stats.runs += 1
	if victory:
		data.stats.wins += 1
	data.stats.best_act = maxi(int(data.stats.get("best_act", 0)), act_reached)
	data.stats.kills = int(data.stats.get("kills", 0)) + kills
	save_game()
