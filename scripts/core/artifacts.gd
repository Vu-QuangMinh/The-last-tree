class_name Artifacts
extends RefCounted
## Relics kept for the run.
##   pool "normal": keepsakes, elites and treasure. starter = available from the first run, else unlocked with Seedlings.
##   pool "boss":   only from bosses; each raises your element income.
##   pool "curse":  stronger, but each one hurts you somehow. Treasure rooms offer one.
## aspect: which part of the game it helps (the wiki groups them by this).

const ALL := [
	# ---- elements you start a fight with
	{"id": "ember_charm", "name": "Ember Charm", "aspect": "Starting elements", "desc": "Start every fight with 1 extra Fire.", "cost": 0, "starter": true, "pool": "normal"},
	{"id": "wind_chime", "name": "Wind Chime", "aspect": "Starting elements", "desc": "Start every fight with 1 extra random element.", "cost": 0, "starter": true, "pool": "normal"},
	# ---- element income and odds
	{"id": "fire_emblem", "name": "Fire Emblem", "aspect": "Element income", "desc": "Gain 3 Fire on turn 3 of every fight.", "cost": 0, "starter": true, "pool": "normal"},
	{"id": "water_emblem", "name": "Water Emblem", "aspect": "Element income", "desc": "Gain 3 Water on turn 3 of every fight.", "cost": 0, "starter": true, "pool": "normal"},
	{"id": "wind_emblem", "name": "Air Emblem", "aspect": "Element income", "desc": "Gain 3 Air on turn 3 of every fight.", "cost": 0, "starter": true, "pool": "normal"},
	{"id": "lucky_acorn", "name": "Lucky Acorn", "aspect": "Element income", "desc": "Each turn, a 25% chance to draw 1 extra element.", "cost": 0, "starter": true, "pool": "normal"},
	{"id": "second_wind", "name": "Second Wind", "aspect": "Element income", "desc": "Draw 1 extra element each turn while below half HP.", "cost": 45, "starter": false, "pool": "normal"},
	{"id": "flame_lens", "name": "Flame Lens", "aspect": "Element odds", "desc": "Fire is twice as likely in your draws.", "cost": 0, "starter": true, "pool": "normal"},
	{"id": "tide_lens", "name": "Tide Lens", "aspect": "Element odds", "desc": "Water is twice as likely in your draws.", "cost": 0, "starter": true, "pool": "normal"},
	{"id": "gale_lens", "name": "Gale Lens", "aspect": "Element odds", "desc": "Air is twice as likely in your draws.", "cost": 0, "starter": true, "pool": "normal"},
	{"id": "prism_shard", "name": "Prism Shard", "aspect": "Element income", "desc": "Conjured elements no longer fade at the end of the turn.", "cost": 35, "starter": false, "pool": "normal"},
	# ---- spells
	{"id": "spell_pouch", "name": "Spell Pouch", "aspect": "Spell slots", "desc": "+1 active spell slot.", "cost": 0, "starter": true, "pool": "normal"},
	{"id": "spell_satchel", "name": "Spell Satchel", "aspect": "Spell slots", "desc": "+1 active spell slot.", "cost": 60, "starter": false, "pool": "normal"},
	{"id": "chant_bell", "name": "Chant Bell", "aspect": "Spells", "desc": "The first spell you cast each turn triggers twice.", "cost": 50, "starter": false, "pool": "normal"},
	{"id": "kindling_stone", "name": "Kindling Stone", "aspect": "Burn & Poison", "desc": "Every 3rd chant charges it. While charged, the next Burn you apply is doubled.", "cost": 0, "starter": true, "pool": "normal"},
	{"id": "venom_gland", "name": "Venom Gland", "aspect": "Burn & Poison", "desc": "Your Poison applies 1 extra stack.", "cost": 25, "starter": false, "pool": "normal"},
	{"id": "lock_pick", "name": "Lock Pick", "aspect": "Debuffs", "desc": "Locks on your spells have 1 fewer symbol.", "cost": 30, "starter": false, "pool": "normal"},
	{"id": "keen_eye", "name": "Keen Eye", "aspect": "Debuffs", "desc": "You can't be Blinded.", "cost": 25, "starter": false, "pool": "normal"},
	{"id": "calm_stone", "name": "Calm Stone", "aspect": "Debuffs", "desc": "You can't be Confused.", "cost": 25, "starter": false, "pool": "normal"},
	# ---- defence and health
	{"id": "rain_chalice", "name": "Rain Chalice", "aspect": "Defence", "desc": "Start every fight with 4 Shield.", "cost": 0, "starter": true, "pool": "normal"},
	{"id": "ward_stone", "name": "Ward Stone", "aspect": "Defence", "desc": "Start every fight with Aegis 1.", "cost": 35, "starter": false, "pool": "normal"},
	{"id": "thornbark", "name": "Thornbark", "aspect": "Defence", "desc": "Thorns 1 in every fight.", "cost": 0, "starter": true, "pool": "normal"},
	{"id": "iron_bark", "name": "Iron Bark", "aspect": "Defence", "desc": "Start every fight with 2 Shield.", "cost": 0, "starter": true, "pool": "normal"},
	{"id": "healing_sap", "name": "Healing Sap", "aspect": "Health", "desc": "Heal 4 after every fight.", "cost": 0, "starter": true, "pool": "normal"},
	{"id": "mending_moss", "name": "Mending Moss", "aspect": "Health", "desc": "Heal 1 at the start of each of your turns.", "cost": 40, "starter": false, "pool": "normal"},
	# ---- rewards
	{"id": "scholar_quill", "name": "Scholar's Quill", "aspect": "Rewards", "desc": "Spell rewards show 4 choices instead of 3.", "cost": 40, "starter": false, "pool": "normal"},
	{"id": "seedling_pouch", "name": "Seedling Pouch", "aspect": "Rewards", "desc": "+25% Seedlings from this run.", "cost": 40, "starter": false, "pool": "normal"},
	# ---- boss relics: more elements every turn
	{"id": "heartwood_seed", "name": "Heartwood Seed", "aspect": "Element income", "desc": "+1 random element every turn.", "cost": 0, "starter": true, "pool": "boss"},
	{"id": "ember_heart", "name": "Ember Heart", "aspect": "Element income", "desc": "+1 Fire every turn.", "cost": 0, "starter": true, "pool": "boss"},
	{"id": "tide_heart", "name": "Tide Heart", "aspect": "Element income", "desc": "+1 Water every turn.", "cost": 0, "starter": true, "pool": "boss"},
	{"id": "gale_heart", "name": "Gale Heart", "aspect": "Element income", "desc": "+1 Air every turn.", "cost": 0, "starter": true, "pool": "boss"},
	# ---- cursed: strong, with a price
	{"id": "blood_pact", "name": "Blood Pact", "aspect": "Cursed", "desc": "+2 elements every turn. CURSE: −12 max HP.", "cost": 0, "starter": true, "pool": "curse"},
	{"id": "broken_crown", "name": "Broken Crown", "aspect": "Cursed", "desc": "+2 active spell slots. CURSE: start every fight with 2 fewer elements.", "cost": 0, "starter": true, "pool": "curse"},
	{"id": "glass_heart", "name": "Glass Heart", "aspect": "Cursed", "desc": "Your Release deals 1 extra damage to every enemy it hits. CURSE: you take 25% more damage.", "cost": 0, "starter": true, "pool": "curse"},
	{"id": "hungry_tome", "name": "Hungry Tome", "aspect": "Cursed", "desc": "Every spell can trigger 1 more time per turn. CURSE: −1 active spell slot.", "cost": 0, "starter": true, "pool": "curse"},
	{"id": "withered_idol", "name": "Withered Idol", "aspect": "Cursed", "desc": "+1 element every turn and heal 6 after every fight. CURSE: enemies hit 1 harder.", "cost": 0, "starter": true, "pool": "curse"},
]


static func get_def(id: String) -> Dictionary:
	for a in ALL:
		if a.id == id:
			return a
	return {}


static func is_curse(id: String) -> bool:
	return get_def(id).get("pool", "") == "curse"


## Up to n artifacts from a pool that you have unlocked and don't own.
static func offer(unlocked: Array, owned: Array, rng: RandomNumberGenerator, n := 3, pool_name := "normal") -> Array:
	var pool := ALL.filter(func(a): return a.pool == pool_name and (a.id in unlocked or a.starter) and not (a.id in owned))
	var out := []
	while not pool.is_empty() and out.size() < n:
		var i := rng.randi() % pool.size()
		out.append(pool[i])
		pool.remove_at(i)
	return out
