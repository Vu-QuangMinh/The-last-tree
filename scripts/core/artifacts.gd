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
	{"id": "ember_charm", "name": "Ember Charm", "aspect": "Starting Essence", "desc": "Start every fight with 1 extra Fire.", "cost": 0, "starter": true, "pool": "normal", "tier": "common", "icon": "🕯"},
	{"id": "wind_chime", "name": "Wind Chime", "aspect": "Starting Essence", "desc": "Start every fight with 1 extra random Essence.", "cost": 0, "starter": true, "pool": "normal", "tier": "common", "icon": "🎐"},
	# ---- element income and refunds
	{"id": "fire_emblem", "name": "Fire Emblem", "aspect": "Essence income", "desc": "Gain 3 Fire on turn 3 of every fight.", "cost": 0, "starter": true, "pool": "normal", "tier": "common", "icon": "🔥"},
	{"id": "water_emblem", "name": "Water Emblem", "aspect": "Essence income", "desc": "Gain 3 Water on turn 3 of every fight.", "cost": 0, "starter": true, "pool": "normal", "tier": "common", "icon": "💧"},
	{"id": "wind_emblem", "name": "Air Emblem", "aspect": "Essence income", "desc": "Gain 3 Air on turn 3 of every fight.", "cost": 0, "starter": true, "pool": "normal", "tier": "common", "icon": "🌪"},
	{"id": "lucky_acorn", "name": "Lucky Acorn", "aspect": "Essence income", "desc": "Each turn, a 25% chance to draw 1 extra Essence.", "cost": 0, "starter": true, "pool": "normal", "tier": "rare", "icon": "🌰"},
	{"id": "second_wind", "name": "Second Wind", "aspect": "Essence income", "desc": "Draw 1 extra Essence each turn while below half HP.", "cost": 45, "starter": false, "pool": "normal", "tier": "rare", "icon": "🌬"},
	{"id": "flame_lens", "name": "Flame Lens", "aspect": "Essence refund", "desc": "After each Release, every Fire in your chant has a 25% chance to come back to your bag.", "cost": 0, "starter": true, "pool": "normal", "tier": "common", "icon": "🔴"},
	{"id": "tide_lens", "name": "Tide Lens", "aspect": "Essence refund", "desc": "After each Release, every Water in your chant has a 25% chance to come back to your bag.", "cost": 0, "starter": true, "pool": "normal", "tier": "common", "icon": "🔵"},
	{"id": "gale_lens", "name": "Gale Lens", "aspect": "Essence refund", "desc": "After each Release, every Air in your chant has a 25% chance to come back to your bag.", "cost": 0, "starter": true, "pool": "normal", "tier": "common", "icon": "🟢"},
	{"id": "prism_shard", "name": "Prism Shard", "aspect": "Essence income", "desc": "Conjured Essence no longer fades at the end of the turn.", "cost": 35, "starter": false, "pool": "normal", "tier": "rare", "icon": "🔮"},
	# ---- spells
	{"id": "spell_pouch", "name": "Spell Pouch", "aspect": "Spell slots", "desc": "+1 active spell slot.", "cost": 0, "starter": false, "pool": "none", "tier": "rare", "icon": "👝"},  # (retired: kept so old saves load)
	{"id": "spell_satchel", "name": "Hungry Satchel", "aspect": "Cursed", "desc": "+1 active spell slot. CURSE: when you take it, it eats 2 random spells from your spellbook.", "cost": 0, "starter": true, "pool": "boss", "tier": "legendary", "icon": "🎒"},
	{"id": "chant_bell", "name": "Chant Bell", "aspect": "Spells", "desc": "The first spell you cast each turn is cast twice.", "cost": 50, "starter": false, "pool": "normal", "tier": "rare", "icon": "🔔"},
	{"id": "echo_shell", "name": "Echo Shell", "aspect": "Spells", "desc": "Every 10th spell you cast charges it. While charged, the next spell you cast is cast twice.", "cost": 0, "starter": true, "pool": "normal", "tier": "rare", "icon": "🐚"},
	{"id": "bandolier", "name": "Bandolier", "aspect": "Bottles", "desc": "+2 bottle slots. When you take it, gain 2 random bottles.", "cost": 0, "starter": true, "pool": "normal", "tier": "rare", "icon": "🎽"},
	{"id": "kindling_stone", "name": "Kindling Stone", "aspect": "Burn & Poison", "desc": "Every 3rd spell you cast puts 1 Burn on a random enemy.", "cost": 0, "starter": true, "pool": "normal", "tier": "common", "icon": "💥"},
	{"id": "venom_gland", "name": "Venom Gland", "aspect": "Burn & Poison", "desc": "Your Poison applies 1 extra stack.", "cost": 25, "starter": false, "pool": "normal", "tier": "common", "icon": "🧪"},
	{"id": "lock_pick", "name": "Lock Pick", "aspect": "Debuffs", "desc": "Locks on your spells have 1 fewer symbol.", "cost": 30, "starter": false, "pool": "normal", "tier": "common", "icon": "🗝"},
	{"id": "keen_eye", "name": "Keen Eye", "aspect": "Debuffs", "desc": "You can't be Blinded.", "cost": 25, "starter": false, "pool": "normal", "tier": "common", "icon": "👁"},
	{"id": "calm_stone", "name": "Calm Stone", "aspect": "Debuffs", "desc": "You can't be Confused.", "cost": 25, "starter": false, "pool": "normal", "tier": "common", "icon": "💠"},
	# ---- defence and health
	{"id": "rain_chalice", "name": "Rain Chalice", "aspect": "Defence", "desc": "Start every fight with 4 Lasting Shield.", "cost": 0, "starter": true, "pool": "normal", "tier": "common", "icon": "🏆"},
	{"id": "echo_chamber", "name": "Echo Chamber", "aspect": "Spells", "desc": "If you Chant 3 Essence or fewer, every spell you cast this turn is cast twice (lengthening the chant later doesn't stop it).", "cost": 0, "starter": true, "pool": "normal", "tier": "rare", "icon": "🔊"},
	{"id": "shield_of_silence", "name": "Shield of Silence", "aspect": "Defence", "desc": "When you pass your turn without chanting, gain 5 Lasting Shield.", "cost": 0, "starter": true, "pool": "normal", "tier": "common", "icon": "🤫"},
	{"id": "ward_stone", "name": "Ward Stone", "aspect": "Defence", "desc": "Start every fight with Aegis 1.", "cost": 35, "starter": false, "pool": "normal", "tier": "rare", "icon": "🛡"},
	{"id": "thornbark", "name": "Thornbark", "aspect": "Defence", "desc": "Thorns 1 in every fight.", "cost": 0, "starter": true, "pool": "normal", "tier": "common", "icon": "🌵"},
	{"id": "iron_bark", "name": "Iron Bark", "aspect": "Defence", "desc": "Start every fight with 2 Lasting Shield.", "cost": 0, "starter": true, "pool": "normal", "tier": "common", "icon": "🌲"},
	{"id": "seed_of_life", "name": "Seed of Life", "aspect": "Health", "desc": "You start every run with it. A second chance: if you lose a fight, it breaks and that fight starts over from the beginning, with the HP and bottles you had going in.", "cost": 0, "starter": true, "pool": "none", "tier": "rare", "icon": "🌼"},
	{"id": "broken_seed_of_life", "name": "Broken Seed of Life", "aspect": "Health", "desc": "Cracked and spent: it gave you your second chance. The merchant can mend it for 100 Leaves.", "cost": 0, "starter": true, "pool": "none", "tier": "rare", "icon": "🥀"},
	{"id": "healing_sap", "name": "Healing Sap", "aspect": "Health", "desc": "Heal 4 after every fight.", "cost": 0, "starter": true, "pool": "normal", "tier": "common", "icon": "🍯"},
	{"id": "mending_moss", "name": "Mending Moss", "aspect": "Health", "desc": "Heal 1 at the start of each of your turns.", "cost": 40, "starter": false, "pool": "normal", "tier": "rare", "icon": "🌿"},
	# ---- rewards
	{"id": "scholar_quill", "name": "Scholar's Quill", "aspect": "Rewards", "desc": "Spell rewards show 4 choices instead of 3.", "cost": 40, "starter": false, "pool": "normal", "tier": "rare", "icon": "✒"},
	{"id": "seedling_pouch", "name": "Seedling Pouch", "aspect": "Rewards", "desc": "+25% Seedlings from this run.", "cost": 40, "starter": false, "pool": "normal", "tier": "common", "icon": "🌱"},
	# ---- boss relics: more elements every turn
	{"id": "heartwood_seed", "name": "Heartwood Seed", "aspect": "Essence income", "desc": "+1 random Essence every turn.", "cost": 0, "starter": true, "pool": "boss", "tier": "legendary", "icon": "🌳"},
	{"id": "ember_heart", "name": "Ember Heart", "aspect": "Essence income", "desc": "+1 Fire every turn.", "cost": 0, "starter": true, "pool": "boss", "tier": "legendary", "icon": "🧡"},
	{"id": "tide_heart", "name": "Tide Heart", "aspect": "Essence income", "desc": "+1 Water every turn.", "cost": 0, "starter": true, "pool": "boss", "tier": "legendary", "icon": "💙"},
	{"id": "gale_heart", "name": "Gale Heart", "aspect": "Essence income", "desc": "+1 Air every turn.", "cost": 0, "starter": true, "pool": "boss", "tier": "legendary", "icon": "💚"},
	# ---- cursed: strong, with a price
	{"id": "blood_pact", "name": "Blood Pact", "aspect": "Cursed", "desc": "+1 Essence every turn. CURSE: −12 max HP.", "cost": 0, "starter": true, "pool": "curse", "tier": "rare", "icon": "🩸"},
	{"id": "broken_crown", "name": "Broken Crown", "aspect": "Cursed", "desc": "+1 active spell slot. CURSE: −15 max HP.", "cost": 0, "starter": true, "pool": "boss", "tier": "legendary", "icon": "👑"},
	{"id": "tangled_grimoire", "name": "Tangled Grimoire", "aspect": "Cursed", "desc": "+1 active spell slot. CURSE: when you take it, 4 random spells each need 1 more Essence (a random one, added to the end of their pattern).", "cost": 0, "starter": true, "pool": "boss", "tier": "legendary", "icon": "📖"},
	{"id": "glass_heart", "name": "Glass Heart", "aspect": "Cursed", "desc": "Every enemy your Release hits also loses its rightmost Essence. CURSE: you take 25% more damage.", "cost": 0, "starter": true, "pool": "curse", "tier": "rare", "icon": "💔"},
	{"id": "withered_idol", "name": "Withered Idol", "aspect": "Cursed", "desc": "+2 Essence every turn. CURSE: −1 active spell slot.", "cost": 0, "starter": true, "pool": "curse", "tier": "rare", "icon": "🗿"},
]


static func get_def(id: String) -> Dictionary:
	for a in ALL:
		if a.id == id:
			return a
	return {}


## Upgraded (+) artifacts: [its number, its + number, its + text]. Only these can be upgraded, once each
## (legendary boss relics, cursed artifacts and yes/no effects can't).
const PLUS := {
	"ember_charm": [1, 2, "Start every fight with 2 extra Fire."],
	"wind_chime": [1, 2, "Start every fight with 2 extra random Essence."],
	"fire_emblem": [3, 5, "Gain 5 Fire on turn 3 of every fight."],
	"water_emblem": [3, 5, "Gain 5 Water on turn 3 of every fight."],
	"wind_emblem": [3, 5, "Gain 5 Air on turn 3 of every fight."],
	"lucky_acorn": [0.25, 0.4, "Each turn, a 40% chance to draw 1 extra Essence."],
	"second_wind": [1, 2, "Draw 2 extra Essence each turn while below half HP."],
	"flame_lens": [0.25, 0.4, "After each Release, every Fire in your chant has a 40% chance to come back to your bag."],
	"tide_lens": [0.25, 0.4, "After each Release, every Water in your chant has a 40% chance to come back to your bag."],
	"gale_lens": [0.25, 0.4, "After each Release, every Air in your chant has a 40% chance to come back to your bag."],
	"kindling_stone": [3, 2, "Every 2nd spell you cast puts 1 Burn on a random enemy."],
	"echo_shell": [10, 7, "Every 7th spell you cast charges it. While charged, the next spell you cast is cast twice."],
	"venom_gland": [1, 2, "Your Poison applies 2 extra stacks."],
	"lock_pick": [1, 2, "Locks on your spells have 2 fewer symbols."],
	"rain_chalice": [4, 6, "Start every fight with 6 Lasting Shield."],
	"ward_stone": [1, 2, "Start every fight with Aegis 2."],
	"echo_chamber": [3, 4, "If you Chant 4 Essence or fewer, every spell you cast this turn is cast twice (lengthening the chant later doesn't stop it)."],
	"shield_of_silence": [5, 8, "When you pass your turn without chanting, gain 8 Lasting Shield."],
	"thornbark": [1, 2, "Thorns 2 in every fight."],
	"iron_bark": [2, 3, "Start every fight with 3 Lasting Shield."],
	"healing_sap": [4, 6, "Heal 6 after every fight."],
	"mending_moss": [1, 2, "Heal 2 at the start of each of your turns."],
	"scholar_quill": [4, 5, "Spell rewards show 5 choices instead of 3."],
	"seedling_pouch": [0.25, 0.5, "+50% Seedlings from this run."],
}


## The number an artifact works with: its + number when upgraded.
static func num(id: String, plus := false) -> float:
	if not PLUS.has(id):
		return 0.0
	return float(PLUS[id][1] if plus else PLUS[id][0])


static func can_upgrade(id: String) -> bool:
	return PLUS.has(id)


## How an artifact reads: an upgraded one gets a + on its name and its stronger text.
static func view(id: String, plus := false) -> Dictionary:
	var d := get_def(id).duplicate()
	if plus and PLUS.has(id):
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
