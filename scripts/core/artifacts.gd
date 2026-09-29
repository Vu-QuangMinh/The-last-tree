class_name Artifacts
extends RefCounted
## Relics kept for the run.
##   tier: common / rare / legendary. Normal offers (keepsakes, elites, treasure, the merchant) are Common 75% of the
##         time and Rare 25%; Legendary artifacts only drop from bosses. Anything that adds spell slots is Rare or
##         Legendary.
##   pool "normal": keepsakes, elites, treasure and the merchant. starter = available from the first run.
##   pool "boss":   only from bosses: element income relics and the Legendary slot artifacts.
##   pool "curse":  stronger, but each one hurts you somehow. Treasure rooms offer one.
## aspect: which part of the game it helps (the wiki groups them by this).

const ALL := [
	# ---- elements you start a fight with
	{"id": "ember_charm", "name": "Ember Charm", "aspect": "Starting elements", "desc": "Start every fight with 1 extra Fire.", "cost": 0, "starter": true, "pool": "normal", "tier": "common", "icon": "🕯"},
	{"id": "wind_chime", "name": "Wind Chime", "aspect": "Starting elements", "desc": "Start every fight with 1 extra random element.", "cost": 0, "starter": true, "pool": "normal", "tier": "common", "icon": "🎐"},
	# ---- element income and refunds
	{"id": "fire_emblem", "name": "Fire Emblem", "aspect": "Element income", "desc": "Gain 3 Fire on turn 3 of every fight.", "cost": 0, "starter": true, "pool": "normal", "tier": "common", "icon": "🔥"},
	{"id": "water_emblem", "name": "Water Emblem", "aspect": "Element income", "desc": "Gain 3 Water on turn 3 of every fight.", "cost": 0, "starter": true, "pool": "normal", "tier": "common", "icon": "💧"},
	{"id": "wind_emblem", "name": "Air Emblem", "aspect": "Element income", "desc": "Gain 3 Air on turn 3 of every fight.", "cost": 0, "starter": true, "pool": "normal", "tier": "common", "icon": "🌪"},
	{"id": "lucky_acorn", "name": "Lucky Acorn", "aspect": "Element income", "desc": "Each turn, a 25% chance to draw 1 extra element.", "cost": 0, "starter": true, "pool": "normal", "tier": "rare", "icon": "🌰"},
	{"id": "second_wind", "name": "Second Wind", "aspect": "Element income", "desc": "Draw 1 extra element each turn while below half HP.", "cost": 45, "starter": false, "pool": "normal", "tier": "rare", "icon": "🌬"},
	{"id": "flame_lens", "name": "Flame Lens", "aspect": "Element refund", "desc": "After each Release, every Fire in your chant has a 25% chance to come back to your elements.", "cost": 0, "starter": true, "pool": "normal", "tier": "common", "icon": "🔴"},
	{"id": "tide_lens", "name": "Tide Lens", "aspect": "Element refund", "desc": "After each Release, every Water in your chant has a 25% chance to come back to your elements.", "cost": 0, "starter": true, "pool": "normal", "tier": "common", "icon": "🔵"},
	{"id": "gale_lens", "name": "Gale Lens", "aspect": "Element refund", "desc": "After each Release, every Air in your chant has a 25% chance to come back to your elements.", "cost": 0, "starter": true, "pool": "normal", "tier": "common", "icon": "🟢"},
	{"id": "prism_shard", "name": "Prism Shard", "aspect": "Element income", "desc": "Conjured elements no longer fade at the end of the turn.", "cost": 35, "starter": false, "pool": "normal", "tier": "rare", "icon": "🔮"},
	# ---- spells
	{"id": "spell_pouch", "name": "Spell Pouch", "aspect": "Spell slots", "desc": "+1 active spell slot.", "cost": 0, "starter": true, "pool": "normal", "tier": "rare", "icon": "👝"},
	{"id": "spell_satchel", "name": "Spell Satchel", "aspect": "Spell slots", "desc": "+1 active spell slot.", "cost": 60, "starter": false, "pool": "boss", "tier": "legendary", "icon": "🎒"},
	{"id": "chant_bell", "name": "Chant Bell", "aspect": "Spells", "desc": "The first spell you cast each turn triggers twice.", "cost": 50, "starter": false, "pool": "normal", "tier": "rare", "icon": "🔔"},
	{"id": "kindling_stone", "name": "Kindling Stone", "aspect": "Burn & Poison", "desc": "Every 3rd chant charges it. While charged, the next Burn you apply is doubled.", "cost": 0, "starter": true, "pool": "normal", "tier": "common", "icon": "💥"},
	{"id": "venom_gland", "name": "Venom Gland", "aspect": "Burn & Poison", "desc": "Your Poison applies 1 extra stack.", "cost": 25, "starter": false, "pool": "normal", "tier": "common", "icon": "🧪"},
	{"id": "lock_pick", "name": "Lock Pick", "aspect": "Debuffs", "desc": "Locks on your spells have 1 fewer symbol.", "cost": 30, "starter": false, "pool": "normal", "tier": "common", "icon": "🗝"},
	{"id": "keen_eye", "name": "Keen Eye", "aspect": "Debuffs", "desc": "You can't be Blinded.", "cost": 25, "starter": false, "pool": "normal", "tier": "common", "icon": "👁"},
	{"id": "calm_stone", "name": "Calm Stone", "aspect": "Debuffs", "desc": "You can't be Confused.", "cost": 25, "starter": false, "pool": "normal", "tier": "common", "icon": "💠"},
	# ---- defence and health
	{"id": "rain_chalice", "name": "Rain Chalice", "aspect": "Defence", "desc": "Start every fight with 4 Shield.", "cost": 0, "starter": true, "pool": "normal", "tier": "common", "icon": "🏆"},
	{"id": "ward_stone", "name": "Ward Stone", "aspect": "Defence", "desc": "Start every fight with Aegis 1.", "cost": 35, "starter": false, "pool": "normal", "tier": "rare", "icon": "🛡"},
	{"id": "thornbark", "name": "Thornbark", "aspect": "Defence", "desc": "Thorns 1 in every fight.", "cost": 0, "starter": true, "pool": "normal", "tier": "common", "icon": "🌵"},
	{"id": "iron_bark", "name": "Iron Bark", "aspect": "Defence", "desc": "Start every fight with 2 Shield.", "cost": 0, "starter": true, "pool": "normal", "tier": "common", "icon": "🌲"},
	{"id": "healing_sap", "name": "Healing Sap", "aspect": "Health", "desc": "Heal 4 after every fight.", "cost": 0, "starter": true, "pool": "normal", "tier": "common", "icon": "🍯"},
	{"id": "mending_moss", "name": "Mending Moss", "aspect": "Health", "desc": "Heal 1 at the start of each of your turns.", "cost": 40, "starter": false, "pool": "normal", "tier": "rare", "icon": "🌿"},
	# ---- rewards
	{"id": "scholar_quill", "name": "Scholar's Quill", "aspect": "Rewards", "desc": "Spell rewards show 4 choices instead of 3.", "cost": 40, "starter": false, "pool": "normal", "tier": "rare", "icon": "✒"},
	{"id": "seedling_pouch", "name": "Seedling Pouch", "aspect": "Rewards", "desc": "+25% Seedlings from this run.", "cost": 40, "starter": false, "pool": "normal", "tier": "common", "icon": "🌱"},
	# ---- boss relics: more elements every turn
	{"id": "heartwood_seed", "name": "Heartwood Seed", "aspect": "Element income", "desc": "+1 random element every turn.", "cost": 0, "starter": true, "pool": "boss", "tier": "legendary", "icon": "🌳"},
	{"id": "ember_heart", "name": "Ember Heart", "aspect": "Element income", "desc": "+1 Fire every turn.", "cost": 0, "starter": true, "pool": "boss", "tier": "legendary", "icon": "🧡"},
	{"id": "tide_heart", "name": "Tide Heart", "aspect": "Element income", "desc": "+1 Water every turn.", "cost": 0, "starter": true, "pool": "boss", "tier": "legendary", "icon": "💙"},
	{"id": "gale_heart", "name": "Gale Heart", "aspect": "Element income", "desc": "+1 Air every turn.", "cost": 0, "starter": true, "pool": "boss", "tier": "legendary", "icon": "💚"},
	# ---- cursed: strong, with a price
	{"id": "blood_pact", "name": "Blood Pact", "aspect": "Cursed", "desc": "+1 element every turn. CURSE: −12 max HP.", "cost": 0, "starter": true, "pool": "curse", "tier": "rare", "icon": "🩸"},
	{"id": "broken_crown", "name": "Broken Crown", "aspect": "Cursed", "desc": "+2 active spell slots (up to the max of 8). CURSE: start every fight with 2 fewer elements.", "cost": 0, "starter": true, "pool": "boss", "tier": "legendary", "icon": "👑"},
	{"id": "glass_heart", "name": "Glass Heart", "aspect": "Cursed", "desc": "Your Release deals 1 extra damage to every enemy it hits. CURSE: you take 25% more damage.", "cost": 0, "starter": true, "pool": "curse", "tier": "rare", "icon": "💔"},
	{"id": "hungry_tome", "name": "Hungry Tome", "aspect": "Cursed", "desc": "Every spell can trigger 1 more time per turn. CURSE: −1 active spell slot.", "cost": 0, "starter": true, "pool": "curse", "tier": "rare", "icon": "📕"},
	{"id": "withered_idol", "name": "Withered Idol", "aspect": "Cursed", "desc": "+1 element every turn and heal 6 after every fight. CURSE: enemies hit 1 harder.", "cost": 0, "starter": true, "pool": "curse", "tier": "rare", "icon": "🗿"},
]


static func get_def(id: String) -> Dictionary:
	for a in ALL:
		if a.id == id:
			return a
	return {}


static func is_curse(id: String) -> bool:
	return get_def(id).get("aspect", "") == "Cursed"


const RARE_CHANCE := 0.25
const TIER_NAMES := {"common": "Common", "rare": "Rare", "legendary": "Legendary"}


## Up to n artifacts from a pool that you have unlocked and don't own. In the normal pool each pick is
## Rare 25% of the time (Common otherwise), falling back to whatever is left.
static func offer(unlocked: Array, owned: Array, rng: RandomNumberGenerator, n := 3, pool_name := "normal") -> Array:
	var pool := ALL.filter(func(a): return a.pool == pool_name and (a.id in unlocked or a.starter) and not (a.id in owned))
	var out := []
	while not pool.is_empty() and out.size() < n:
		var want := "rare" if rng.randf() < RARE_CHANCE else "common"
		var tiered := pool.filter(func(a): return a.tier == want)
		var from: Array = tiered if (pool_name == "normal" and not tiered.is_empty()) else pool
		var pick: Dictionary = from[rng.randi() % from.size()]
		out.append(pick)
		pool.erase(pick)
	return out


## Starting keepsakes: Common artifacts only.
static func keepsakes(rng: RandomNumberGenerator, n := 3) -> Array:
	var pool := ALL.filter(func(a): return a.pool == "normal" and a.tier == "common" and a.starter)
	var out := []
	while not pool.is_empty() and out.size() < n:
		var pick: Dictionary = pool[rng.randi() % pool.size()]
		out.append(pick)
		pool.erase(pick)
	return out
