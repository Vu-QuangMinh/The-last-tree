class_name Artifacts
extends RefCounted
## Relics kept for the run.
##   tier: common / rare / legendary. Normal offers (keepsakes, elites, treasure, the merchant) are Common 75% of the
##         time and Rare 25%; Legendary artifacts only drop from bosses. An extra spell slot only ever comes from a
##         Legendary, cursed artifact (+1 each: the Hungry Satchel, the Broken Crown, the Tangled Grimoire).
##   pool "normal": keepsakes, elites, treasure and the merchant. starter = available from the first run.
##   pool "boss":   only from bosses: element income relics and the Legendary slot artifacts.
##   pool "curse":  stronger, but each one hurts you somehow. Treasure rooms offer one.
## aspect: which part of the game it helps (the wiki groups them by this).

const ALL := [
	# ---- elements you start a fight with
	{"id": "ember_charm", "name": "Ember Charm", "aspect": "Starting Essence", "desc": "Start each fight with 1 Fire.", "cost": 0, "starter": true, "pool": "normal", "tier": "common", "icon": "🕯"},
	{"id": "wind_chime", "name": "Wind Chime", "aspect": "Starting Essence", "desc": "Start each fight with 1 Random.", "cost": 0, "starter": true, "pool": "normal", "tier": "common", "icon": "🎐"},
	# ---- element income and refunds
	{"id": "fire_emblem", "name": "Fire Emblem", "aspect": "Essence income", "desc": "Turn 3 of each fight: gain 3 Fire.", "cost": 0, "starter": true, "pool": "normal", "tier": "common", "icon": "🔥"},
	{"id": "water_emblem", "name": "Water Emblem", "aspect": "Essence income", "desc": "Turn 3 of each fight: gain 3 Water.", "cost": 0, "starter": true, "pool": "normal", "tier": "common", "icon": "💧"},
	{"id": "wind_emblem", "name": "Air Emblem", "aspect": "Essence income", "desc": "Turn 3 of each fight: gain 3 Air.", "cost": 0, "starter": true, "pool": "normal", "tier": "common", "icon": "🌪"},
	{"id": "lucky_acorn", "name": "Lucky Acorn", "aspect": "Essence income", "desc": "Each turn: 25% chance of +1 Random.", "cost": 0, "starter": true, "pool": "normal", "tier": "rare", "icon": "🌰"},
	{"id": "second_wind", "name": "Second Wind", "aspect": "Essence income", "desc": "Below half HP: +1 Random each turn.", "cost": 45, "starter": false, "pool": "normal", "tier": "rare", "icon": "🌬"},
	{"id": "flame_lens", "name": "Flame Lens", "aspect": "Essence refund", "desc": "25% Refund for Fire.", "cost": 0, "starter": true, "pool": "normal", "tier": "common", "icon": "🔴"},
	{"id": "tide_lens", "name": "Tide Lens", "aspect": "Essence refund", "desc": "25% Refund for Water.", "cost": 0, "starter": true, "pool": "normal", "tier": "common", "icon": "🔵"},
	{"id": "gale_lens", "name": "Gale Lens", "aspect": "Essence refund", "desc": "25% Refund for Air.", "cost": 0, "starter": true, "pool": "normal", "tier": "common", "icon": "🟢"},
	{"id": "prism_shard", "name": "Prism Shard", "aspect": "Essence income", "desc": "Conjured Essence doesn't fade.", "cost": 35, "starter": false, "pool": "normal", "tier": "rare", "icon": "🔮"},
	# ---- spells
	{"id": "spell_pouch", "name": "Spell Pouch", "aspect": "Spell slots", "desc": "+1 spell slot.", "cost": 0, "starter": false, "pool": "none", "tier": "rare", "icon": "👝"},  # (retired: kept so old saves load)
	{"id": "spell_satchel", "name": "Hungry Satchel", "aspect": "Cursed", "desc": "+1 spell slot. CURSE: eats 2 random spells from your spellbook.", "cost": 0, "starter": true, "pool": "boss", "tier": "legendary", "icon": "🎒"},
	{"id": "chant_bell", "name": "Chant Bell", "aspect": "Spells", "desc": "Your first spell each turn is cast twice.", "cost": 50, "starter": false, "pool": "normal", "tier": "rare", "icon": "🔔"},
	{"id": "echo_shell", "name": "Echo Shell", "aspect": "Spells", "desc": "Every 10th spell charges it: the next spell is cast twice.", "cost": 0, "starter": true, "pool": "normal", "tier": "rare", "icon": "🐚"},
	{"id": "bandolier", "name": "Bandolier", "aspect": "Bottles", "desc": "+2 bottle slots, and 2 random bottles.", "cost": 0, "starter": true, "pool": "normal", "tier": "rare", "icon": "🎽"},
	{"id": "kindling_stone", "name": "Kindling Stone", "aspect": "Burn & Poison", "desc": "Every 3rd spell: Burn 1 on a random enemy.", "cost": 0, "starter": true, "pool": "normal", "tier": "common", "icon": "💥"},
	{"id": "venom_gland", "name": "Venom Gland", "aspect": "Burn & Poison", "desc": "Your Poison +1.", "cost": 25, "starter": false, "pool": "normal", "tier": "common", "icon": "🧪"},
	{"id": "lock_pick", "name": "Lock Pick", "aspect": "Debuffs", "desc": "Locks on your spells are 1 shorter.", "cost": 30, "starter": false, "pool": "normal", "tier": "common", "icon": "🗝"},
	{"id": "keen_eye", "name": "Keen Eye", "aspect": "Debuffs", "desc": "You can't be Blinded.", "cost": 25, "starter": false, "pool": "normal", "tier": "common", "icon": "👁"},
	{"id": "calm_stone", "name": "Calm Stone", "aspect": "Debuffs", "desc": "You can't be Confused.", "cost": 25, "starter": false, "pool": "normal", "tier": "common", "icon": "💠"},
	# ---- defence and health
	{"id": "rain_chalice", "name": "Rain Chalice", "aspect": "Defence", "desc": "Start each fight with 4 Lasting Shield.", "cost": 0, "starter": true, "pool": "normal", "tier": "common", "icon": "🏆"},
	{"id": "echo_chamber", "name": "Echo Chamber", "aspect": "Spells", "desc": "Chant 3 or fewer Essence: every spell this turn is cast twice.", "cost": 0, "starter": true, "pool": "normal", "tier": "rare", "icon": "🔊"},
	{"id": "shield_of_silence", "name": "Shield of Silence", "aspect": "Defence", "desc": "Passing your turn without chanting grants 5 Lasting Shield.", "cost": 0, "starter": true, "pool": "normal", "tier": "common", "icon": "🤫"},
	{"id": "ward_stone", "name": "Ward Stone", "aspect": "Defence", "desc": "Start each fight with 1 Aegis.", "cost": 35, "starter": false, "pool": "normal", "tier": "rare", "icon": "🛡"},
	{"id": "thornbark", "name": "Thornbark", "aspect": "Defence", "desc": "Thorns 1 every fight.", "cost": 0, "starter": true, "pool": "normal", "tier": "common", "icon": "🌵"},
	{"id": "iron_bark", "name": "Iron Bark", "aspect": "Defence", "desc": "Gain 1 Lasting Shield each turn.", "cost": 0, "starter": true, "pool": "normal", "tier": "common", "icon": "🌲"},
	{"id": "seed_of_life", "name": "Seed of Life", "aspect": "Health", "desc": "Lose a fight: it breaks, and the fight starts over. (Every run starts with it.)", "cost": 0, "starter": true, "pool": "none", "tier": "rare", "icon": "🌼"},
	{"id": "broken_seed_of_life", "name": "Broken Seed of Life", "aspect": "Health", "desc": "Spent. The merchant can mend it for 100 Leaves.", "cost": 0, "starter": true, "pool": "none", "tier": "rare", "icon": "🥀"},
	{"id": "healing_sap", "name": "Healing Sap", "aspect": "Health", "desc": "Heal 4 after each fight.", "cost": 0, "starter": true, "pool": "normal", "tier": "common", "icon": "🍯"},
	{"id": "hair_of_the_fairest", "name": "Hair of the Fairest", "aspect": "Essence refund", "desc": "1% Refund for Random.", "cost": 0, "starter": false, "pool": "none", "tier": "rare", "icon": "✨"},
	{"id": "deadly_chair", "name": "Deadly Chair", "aspect": "Health", "desc": "Lose 2 HP at the start of each fight.", "cost": 0, "starter": false, "pool": "none", "tier": "rare", "icon": "🪑"},
	{"id": "comfy_chair", "name": "Comfy Chair", "aspect": "Health", "desc": "Heal 8 before each fight.", "cost": 0, "starter": false, "pool": "none", "tier": "rare", "icon": "🛋"},
	{"id": "chair", "name": "Chair", "aspect": "Health", "desc": "Heal 4 before each fight.", "cost": 0, "starter": false, "pool": "none", "tier": "rare", "icon": "🪑"},
	{"id": "mending_moss", "name": "Mending Moss", "aspect": "Health", "desc": "Heal 1 each turn.", "cost": 40, "starter": false, "pool": "normal", "tier": "rare", "icon": "🌿"},
	# ---- rewards
	{"id": "scholar_quill", "name": "Scholar's Quill", "aspect": "Rewards", "desc": "Spell rewards: 4 choices.", "cost": 40, "starter": false, "pool": "normal", "tier": "rare", "icon": "✒"},
	{"id": "seedling_pouch", "name": "Seedling Pouch", "aspect": "Rewards", "desc": "+25% Seedlings this run.", "cost": 40, "starter": false, "pool": "normal", "tier": "common", "icon": "🌱"},
	# ---- boss relics: more elements every turn
	{"id": "heartwood_seed", "name": "Heartwood Seed", "aspect": "Essence income", "desc": "+1 Random each turn.", "cost": 0, "starter": true, "pool": "boss", "tier": "legendary", "icon": "🌳"},
	{"id": "ember_heart", "name": "Ember Heart", "aspect": "Essence income", "desc": "+1 Fire each turn.", "cost": 0, "starter": true, "pool": "boss", "tier": "legendary", "icon": "🧡"},
	{"id": "tide_heart", "name": "Tide Heart", "aspect": "Essence income", "desc": "+1 Water each turn.", "cost": 0, "starter": true, "pool": "boss", "tier": "legendary", "icon": "💙"},
	{"id": "gale_heart", "name": "Gale Heart", "aspect": "Essence income", "desc": "+1 Air each turn.", "cost": 0, "starter": true, "pool": "boss", "tier": "legendary", "icon": "💚"},
	# ---- cursed: strong, with a price
	{"id": "blood_pact", "name": "Blood Pact", "aspect": "Cursed", "desc": "+1 Random each turn. CURSE: -12 max HP.", "cost": 0, "starter": true, "pool": "curse", "tier": "rare", "icon": "🩸"},
	{"id": "broken_crown", "name": "Broken Crown", "aspect": "Cursed", "desc": "+1 spell slot. CURSE: -15 max HP.", "cost": 0, "starter": true, "pool": "boss", "tier": "legendary", "icon": "👑"},
	{"id": "tangled_grimoire", "name": "Tangled Grimoire", "aspect": "Cursed", "desc": "+1 spell slot. CURSE: 4 random spells need 1 more Essence.", "cost": 0, "starter": true, "pool": "boss", "tier": "legendary", "icon": "📖"},
	{"id": "glass_heart", "name": "Glass Heart", "aspect": "Cursed", "desc": "Your Release also removes 1 rightmost Essence of each enemy it hits. CURSE: you take 25% more damage.", "cost": 0, "starter": true, "pool": "curse", "tier": "rare", "icon": "💔"},
	{"id": "withered_idol", "name": "Withered Idol", "aspect": "Cursed", "desc": "+2 Random each turn. CURSE: -1 spell slot.", "cost": 0, "starter": true, "pool": "curse", "tier": "rare", "icon": "🗿"},
]


static func get_def(id: String) -> Dictionary:
	for a in ALL:
		if a.id == id:
			return a
	return {}


## Upgraded (+) artifacts: [its number, its + number, its + text]. Only these can be upgraded, once each
## (legendary boss relics, cursed artifacts and yes/no effects can't).
const PLUS := {
	"ember_charm": [1, 2, "Start each fight with 2 Fire."],
	"wind_chime": [1, 2, "Start each fight with 2 Random."],
	"fire_emblem": [3, 5, "Turn 3 of each fight: gain 5 Fire."],
	"water_emblem": [3, 5, "Turn 3 of each fight: gain 5 Water."],
	"wind_emblem": [3, 5, "Turn 3 of each fight: gain 5 Air."],
	"lucky_acorn": [0.25, 0.4, "Each turn: 40% chance of +1 Random."],
	"second_wind": [1, 2, "Below half HP: +2 Random each turn."],
	"flame_lens": [0.25, 0.4, "40% Refund for Fire."],
	"tide_lens": [0.25, 0.4, "40% Refund for Water."],
	"gale_lens": [0.25, 0.4, "40% Refund for Air."],
	"kindling_stone": [3, 2, "Every 2nd spell: Burn 1 on a random enemy."],
	"echo_shell": [10, 7, "Every 7th spell charges it: the next spell is cast twice."],
	"venom_gland": [1, 2, "Your Poison +2."],
	"lock_pick": [1, 2, "Locks on your spells are 2 shorter."],
	"rain_chalice": [4, 6, "Start each fight with 6 Lasting Shield."],
	"ward_stone": [1, 2, "Start each fight with 2 Aegis."],
	"echo_chamber": [3, 4, "Chant 4 or fewer Essence: every spell this turn is cast twice."],
	"shield_of_silence": [5, 8, "Passing your turn without chanting grants 8 Lasting Shield."],
	"thornbark": [1, 2, "Thorns 2 every fight."],
	"iron_bark": [1, 2, "Gain 2 Lasting Shield each turn."],
	"healing_sap": [4, 6, "Heal 6 after each fight."],
	"deadly_chair": [2, 2],
	"comfy_chair": [8, 8],
	"chair": [4, 8, "Heal 8 before each fight."],  # (its upgrade is the Comfy Chair: see view())
	"mending_moss": [1, 2, "Heal 2 each turn."],
	"scholar_quill": [4, 5, "Spell rewards: 5 choices."],
	"seedling_pouch": [0.25, 0.5, "+50% Seedlings this run."],
}


## The number an artifact works with: its + number when upgraded.
static func num(id: String, plus := false) -> float:
	if not PLUS.has(id):
		return 0.0
	return float(PLUS[id][1] if plus else PLUS[id][0])


static func can_upgrade(id: String) -> bool:
	return PLUS.has(id) and PLUS[id].size() > 2  # (just numbers, no upgraded text: the chairs, which can't be upgraded)


## How an artifact reads: an upgraded one gets a + on its name and its stronger text.
static func view(id: String, plus := false) -> Dictionary:
	var d := get_def(id).duplicate()
	if plus and id == "chair":
		d.name = "Comfy Chair"  # (the Handyman's best chair, upgraded: a name of its own, not "Chair+")
		d.desc = PLUS[id][2]
		d["plus"] = true
	elif plus and PLUS.has(id):
		d.name += "+"
		d.desc = PLUS[id][2]
		d["plus"] = true
	return d


## Artifacts that charge up: {id: [is it charged now, its progress text]} for the given player.
static func charge_state(id: String, p: PlayerState, plus := false) -> Array:
	match id:
		"kindling_stone":
			# it glows when the next spell you cast will set an enemy alight
			var every := int(num(id, plus))
			var ready := p.kindling_chants >= every - 1
			return [ready, "READY: your next spell puts 1 Burn on a random enemy." if ready else "%d / %d spells" % [p.kindling_chants, every]]
		"echo_chamber":
			# it shines while it's on (a short chant this turn)
			return [p.echo_chamber_on, "ON: every spell you cast this turn is cast twice." if p.echo_chamber_on else "Chant %d Essence or fewer to turn it on." % int(num(id, plus))]
		"echo_shell":
			return [p.echo_charged, "CHARGED: your next spell is cast twice." if p.echo_charged else "%d / %d spells" % [p.echo_casts, int(num(id, plus))]]
	return []


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
