class_name Artifacts
extends RefCounted
## Relics kept for the run.
##   tier: common / rare / legendary. Normal offers (keepsakes, elites, treasure, the merchant) are Common 75% of the
##         time and Rare 25%; Legendary artifacts only drop from bosses. An extra spell slot only ever comes from a
##         Legendary, cursed artifact (+1 each: the Hungry Satchel, the Broken Crown, the Tangled Grimoire).
##   pool "normal": keepsakes, elites, treasure and the merchant. starter = available from the first run.
##   pool "boss":   only from bosses: element income relics and the Legendary slot artifacts.
##   pool "curse":  stronger, but picking one up curses one of your spells (RunState.curse). Treasure rooms offer one.
## aspect: which part of the game it helps (the wiki groups them by this).

const ALL := [
	# ---- elements you start a fight with
	{"id": "ember_charm", "name": "Ember Charm", "aspect": "Starting Essence", "desc": "Start each fight with 1 Fire.", "cost": 0, "starter": true, "pool": "none", "tier": "common", "icon": "🕯"},
	{"id": "wind_chime", "name": "Aole's Charm", "aspect": "Starting Essence", "desc": "Start each fight with 1 Random.", "cost": 0, "starter": true, "pool": "none", "tier": "common", "icon": "🎐"},
	# ---- element income and refunds
	{"id": "fire_emblem", "name": "Fire Emblem", "aspect": "Essence income", "desc": "Turn 3 of each fight: gain 3 Fire.", "cost": 0, "starter": true, "pool": "none", "tier": "common", "icon": "🔥"},
	{"id": "water_emblem", "name": "Water Emblem", "aspect": "Essence income", "desc": "Turn 3 of each fight: gain 3 Water.", "cost": 0, "starter": true, "pool": "none", "tier": "common", "icon": "💧"},
	{"id": "wind_emblem", "name": "Air Emblem", "aspect": "Essence income", "desc": "Turn 3 of each fight: gain 3 Air.", "cost": 0, "starter": true, "pool": "none", "tier": "common", "icon": "🌪"},
	{"id": "lucky_acorn", "name": "Lucky Acorn", "aspect": "Essence income", "desc": "Each turn: 25% chance of +1 Random.", "cost": 0, "starter": true, "pool": "none", "tier": "rare", "icon": "🌰"},
	{"id": "second_wind", "name": "Second Wind", "aspect": "Essence income", "desc": "Below half HP: +1 Random each turn.", "cost": 45, "starter": false, "pool": "none", "tier": "rare", "icon": "🌬"},
	{"id": "flame_lens", "name": "Flame Lens", "aspect": "Essence refund", "desc": "25% Refund for Fire.", "cost": 0, "starter": true, "pool": "none", "tier": "common", "icon": "🔴"},
	{"id": "tide_lens", "name": "Tide Lens", "aspect": "Essence refund", "desc": "25% Refund for Water.", "cost": 0, "starter": true, "pool": "none", "tier": "common", "icon": "🔵"},
	{"id": "gale_lens", "name": "Gale Lens", "aspect": "Essence refund", "desc": "25% Refund for Air.", "cost": 0, "starter": true, "pool": "none", "tier": "common", "icon": "🟢"},
	{"id": "prism_shard", "name": "Prism Shard", "aspect": "Essence income", "desc": "Conjured Essence doesn't fade.", "cost": 35, "starter": false, "pool": "none", "tier": "rare", "icon": "🔮"},
	# ---- spells
	{"id": "spell_pouch", "name": "Spell Pouch", "aspect": "Spell slots", "desc": "+1 spell slot.", "cost": 0, "starter": false, "pool": "none", "tier": "rare", "icon": "👝"},  # (retired: kept so old saves load)
	{"id": "spell_satchel", "name": "Hungry Satchel", "aspect": "Cursed", "desc": "+1 spell slot. Cursed: picking it up puts a curse on one of your spells.", "cost": 0, "starter": true, "pool": "none", "tier": "legendary", "icon": "🎒"},
	{"id": "bandolier", "name": "Bandolier", "aspect": "Bottles", "desc": "+2 bottle slots, and 2 random bottles.", "cost": 0, "starter": true, "pool": "none", "tier": "rare", "icon": "🎽"},
	{"id": "kindling_stone", "name": "Kindling Stone", "aspect": "Burn", "desc": "Every 3rd spell: apply 1 Burn to a random enemy.", "cost": 0, "starter": true, "pool": "none", "tier": "common", "icon": "💥"},
	{"id": "turkish_march", "name": "Turkish March", "aspect": "Burn", "desc": "Every time an Extension happens: apply 1 Burn to a random enemy.", "cost": 0, "starter": false, "pool": "none", "tier": "rare", "icon": "🎼", "unlock_by": "pianist", "flavor": "The score he played, every note of it."},
	{"id": "fur_elise", "name": "Für Elise", "aspect": "Heal", "desc": "Every time an Extension happens: heal 2.", "cost": 0, "starter": false, "pool": "none", "tier": "rare", "icon": "🎼", "unlock_by": "pianist", "flavor": "The piece he wrote for her."},
	{"id": "magic_box", "name": "Magic Box", "aspect": "Refund", "desc": "Every 6th spell you cast: Refund its pattern after the Release.", "cost": 0, "starter": false, "pool": "none", "tier": "rare", "icon": "🎵", "unlock_by": "invoker_talk", "flavor": "With the right tune, it may reveal a secret."},
	{"id": "nice_lute", "name": "A Nice Lute", "aspect": "Spells", "desc": "Every 10th spell you cast: apply 1 Weaken to all enemies.", "cost": 0, "starter": true, "pool": "none", "tier": "common", "icon": "🪕", "flavor": "The music it creates makes people weak in the knee."},
	{"id": "cactus_heart", "name": "Cactus Heart", "aspect": "Thorns", "desc": "Thorns 1. Heal 5 HP for each Essence your Thorns take.", "cost": 0, "starter": true, "pool": "none", "tier": "rare", "icon": "🌵", "flavor": "It still hums, if you hold it close."},
	{"id": "ever_thirsting", "name": "Ever Thirsting", "aspect": "Cursed", "desc": "Cursed: picking it up puts a curse on one of your spells.", "cost": 0, "starter": true, "pool": "none", "tier": "common", "icon": "🏜", "flavor": "The water spirit's parting gift. Your throat has been dry ever since."},
	{"id": "dollar_bill", "name": "Dollar Bill", "aspect": "Merchant", "desc": "The merchant's prices are 20% lower.", "cost": 0, "starter": false, "pool": "none", "tier": "common", "unlock_by": "mystery_shack", "icon": "💵", "flavor": "\"Wow, this is worthless.\""},
	{"id": "half_eaten_candy", "name": "Half-Eaten Candy", "aspect": "Health", "desc": "Heal 2 HP after each fight.", "cost": 0, "starter": false, "pool": "none", "tier": "common", "unlock_by": "mystery_shack", "icon": "🍬", "flavor": "Still a little sticky."},
	{"id": "mystery_book", "name": "Mystery Book", "aspect": "Spell slots", "desc": "+1 spell slot. You can carry more than one: they stack.", "cost": 0, "starter": false, "pool": "none", "tier": "rare", "stack": true, "unlock_by": "mystery_shack", "icon": "📕", "flavor": "A six-fingered hand on the cover. Inside, strange symbols, and a triangle that seems to be watching you."},
	{"id": "lock_pick", "name": "Lock Pick", "aspect": "Debuffs", "desc": "Locks on your spells are 1 shorter.", "cost": 30, "starter": false, "pool": "none", "tier": "common", "icon": "🗝"},
	{"id": "keen_eye", "name": "Keen Eye", "aspect": "Debuffs", "desc": "You can't be Blinded.", "cost": 25, "starter": false, "pool": "none", "tier": "common", "icon": "👁"},
	# ---- the merchant's quests (see MerchantQuests): never offered, only dropped (or stolen)
	{"id": "blanket", "name": "Blanket", "aspect": "Debuffs", "desc": "You can't be Frozen.", "cost": 0, "starter": false, "pool": "none", "tier": "rare", "icon": "🧣", "flavor": "Thick enough to warm a broken heart, but not to mend it."},
	{"id": "sake_bottle", "name": "Sake Bottle", "aspect": "Bottles", "desc": "Heal 5 HP every time you use a bottle.", "cost": 0, "starter": false, "pool": "none", "tier": "rare", "icon": "🍶", "flavor": "Can't fix your bond, but will numb your heart."},
	{"id": "family_picture", "name": "Family Picture", "aspect": "Story", "desc": "A father, a mother, and a son blacked out. On the back: \"Dad, don't look for me. But if you do: 093. Love, Adam.\"", "cost": 0, "starter": false, "pool": "none", "tier": "rare", "icon": "🖼"},
	# ---- defence and health
	{"id": "rain_chalice", "name": "Rain Chalice", "aspect": "Defence", "desc": "Start each fight with 4 Lasting Shield.", "cost": 0, "starter": true, "pool": "none", "tier": "common", "icon": "🏆"},
	{"id": "shield_of_silence", "name": "Shield of Silence", "aspect": "Defence", "desc": "Passing your turn without chanting grants 5 Lasting Shield.", "cost": 0, "starter": true, "pool": "none", "tier": "common", "icon": "🤫"},
	{"id": "ward_stone", "name": "Ward Stone", "aspect": "Defence", "desc": "Start each fight with 1 Evasion.", "cost": 35, "starter": false, "pool": "none", "tier": "rare", "icon": "🛡"},
	{"id": "thornbark", "name": "Thornbark", "aspect": "Defence", "desc": "Thorns 1 every fight.", "cost": 0, "starter": true, "pool": "none", "tier": "common", "icon": "🌵"},
	{"id": "iron_bark", "name": "Iron Bark", "aspect": "Defence", "desc": "Gain 1 Lasting Shield each turn.", "cost": 0, "starter": true, "pool": "none", "tier": "common", "icon": "🌲"},
	{"id": "seed_of_life", "name": "Seed of Life", "aspect": "Health", "desc": "Lose a fight: it breaks, and the fight starts over. (Every run starts with it.)", "cost": 0, "starter": true, "pool": "none", "tier": "rare", "icon": "🌼"},
	{"id": "broken_seed_of_life", "name": "Broken Seed of Life", "aspect": "Health", "desc": "Spent. The merchant can mend it for 100 Leaves.", "cost": 0, "starter": true, "pool": "none", "tier": "rare", "icon": "🥀"},
	{"id": "healing_sap", "name": "Healing Sap", "aspect": "Health", "desc": "Heal 4 after each fight.", "cost": 0, "starter": true, "pool": "none", "tier": "common", "icon": "🍯"},
	{"id": "mending_moss", "name": "Mending Moss", "aspect": "Health", "desc": "Heal 1 each turn.", "cost": 40, "starter": false, "pool": "none", "tier": "rare", "icon": "🌿"},
	# ---- rewards
	{"id": "scholar_quill", "name": "Scholar's Quill", "aspect": "Rewards", "desc": "Spell rewards: 4 choices.", "cost": 40, "starter": false, "pool": "none", "tier": "rare", "icon": "✒"},
	# ---- boss relics: more elements every turn
	{"id": "heartwood_seed", "name": "Heartwood Seed", "aspect": "Essence income", "desc": "+1 Random each turn.", "cost": 0, "starter": true, "pool": "none", "tier": "legendary", "icon": "🌳"},
	{"id": "ember_heart", "name": "Ember Heart", "aspect": "Essence income", "desc": "+1 Fire each turn.", "cost": 0, "starter": true, "pool": "none", "tier": "legendary", "icon": "🧡"},
	{"id": "tide_heart", "name": "Tide Heart", "aspect": "Essence income", "desc": "+1 Water each turn.", "cost": 0, "starter": true, "pool": "none", "tier": "legendary", "icon": "💙"},
	{"id": "gale_heart", "name": "Gale Heart", "aspect": "Essence income", "desc": "+1 Air each turn.", "cost": 0, "starter": true, "pool": "none", "tier": "legendary", "icon": "💚"},
	# ---- cursed: strong, with a price
	{"id": "broken_crown", "name": "Broken Crown", "aspect": "Cursed", "desc": "+1 spell slot. Cursed: picking it up puts a curse on one of your spells.", "cost": 0, "starter": true, "pool": "none", "tier": "legendary", "icon": "👑"},
	{"id": "tangled_grimoire", "name": "Tangled Grimoire", "aspect": "Cursed", "desc": "+1 spell slot. Cursed: picking it up puts a curse on one of your spells.", "cost": 0, "starter": true, "pool": "none", "tier": "legendary", "icon": "📖"},
	{"id": "glass_heart", "name": "Glass Heart", "aspect": "Cursed", "desc": "Your Release also removes 1 rightmost Essence of each enemy it hits. Cursed: picking it up puts a curse on one of your spells.", "cost": 0, "starter": true, "pool": "none", "tier": "rare", "icon": "💔"},
	{"id": "withered_idol", "name": "Withered Idol", "aspect": "Cursed", "desc": "+2 Random each turn. Cursed: picking it up puts a curse on one of your spells.", "cost": 0, "starter": true, "pool": "none", "tier": "rare", "icon": "🗿"},
	# ---- 2026-11-27, the user: every artifact above is retired (never offered again; kept so old saves and story items
	# still load). The carnival set: very effective artifacts. "fx": what its feedback shows when it works.
	{"id": "red_token", "name": "Red Token", "aspect": "Marbles", "desc": "Every 5 Fire marbles you chant: a temporary extra Fire marble next turn.", "cost": 0, "starter": true, "pool": "normal", "tier": "common", "icon": "🔴"},
	{"id": "blue_token", "name": "Blue Token", "aspect": "Marbles", "desc": "Every 5 Water marbles you chant: a temporary extra Water marble next turn.", "cost": 0, "starter": true, "pool": "normal", "tier": "common", "icon": "🔵"},
	{"id": "green_token", "name": "Green Token", "aspect": "Marbles", "desc": "Every 5 Wind marbles you chant: a temporary extra Wind marble next turn.", "cost": 0, "starter": true, "pool": "normal", "tier": "common", "icon": "🟢"},
	{"id": "rainbow_token", "name": "Rainbow Token", "aspect": "Marbles", "desc": "Every 7 marbles you chant: a temporary marble of any colour next turn.", "cost": 0, "starter": true, "pool": "normal", "tier": "rare", "icon": "🌈"},
	{"id": "thorn_heart", "name": "Thorn Heart", "aspect": "Thorns", "desc": "Heal 20% of the damage your Thorns deal.", "cost": 0, "starter": true, "pool": "normal", "tier": "common", "icon": "💗"},
	{"id": "carver", "name": "Carver", "aspect": "Marbles", "desc": "When you pick it up: carve 3 marbles. For each one you pick, 3 carvings are rolled for it: choose one.", "cost": 0, "starter": true, "pool": "normal", "tier": "rare", "icon": "🔪"},
	{"id": "collector", "name": "Collector", "aspect": "Marbles", "desc": "Your carvings are 50% stronger.", "cost": 0, "starter": true, "pool": "normal", "tier": "rare", "icon": "🧐"},
	{"id": "mysterious_hand", "name": "Mysterious Hand", "aspect": "Power", "desc": "Casting a spell whose pattern is 4 marbles or longer gives 1 Power (waxed spots don't count).", "cost": 0, "starter": false, "pool": "normal", "tier": "rare", "icon": "🖐", "unlock_by": "handyman_talk", "flavor": "It still twitches, now and then."},
	{"id": "golden_ticket", "name": "Golden Ticket", "aspect": "Tickets", "desc": "You get a random ticket after every fight.", "cost": 0, "starter": true, "pool": "normal", "tier": "rare", "icon": "🎫"},
	{"id": "bulwark", "name": "Bulwark", "aspect": "Shield", "desc": "At the start of your turn your Shield is halved instead of lost.", "cost": 0, "starter": true, "pool": "normal", "tier": "rare", "icon": "🛡"},
	{"id": "coal_heart", "name": "Coal Heart", "aspect": "Burn", "desc": "Each time you apply Burn, heal 2.", "cost": 0, "starter": true, "pool": "normal", "tier": "common", "icon": "❤‍🔥"},
	{"id": "candy_apple", "name": "Candy Apple", "aspect": "Health", "desc": "Heal 5 after each fight.", "cost": 0, "starter": true, "pool": "normal", "tier": "common", "icon": "🍎"},
	{"id": "dark_heart", "name": "Dark Heart", "aspect": "Health", "desc": "Heal 3 for each enemy you kill.", "cost": 0, "starter": true, "pool": "normal", "tier": "common", "icon": "🖤"},
	{"id": "halo", "name": "Halo", "aspect": "Curses", "desc": "You can't be cursed: a curse that would land on you is stopped by your halo.", "cost": 0, "starter": true, "pool": "normal", "tier": "rare", "icon": "😇"},
	{"id": "kunai", "name": "Kunai", "aspect": "Damage", "desc": "Every 3rd time you deal damage, deal 1 more (a hit of its own: Power, Expose and Vulnerable count; it doesn't count for the Kunai).", "cost": 0, "starter": true, "pool": "normal", "tier": "common", "icon": "🗡"},
	{"id": "hammer", "name": "Hammer", "aspect": "Damage", "desc": "Each turn you don't attack, your next attack deals 30% more (it stacks).", "cost": 0, "starter": true, "pool": "normal", "tier": "common", "icon": "🔨"},
	{"id": "glow_stick", "name": "Glow Stick", "aspect": "Burn", "desc": "The first time you take damage in a fight, apply 10 Burn to the attacker.", "cost": 0, "starter": true, "pool": "normal", "tier": "common", "icon": "🪄"},
	{"id": "cactus_plushie", "name": "Cactus Plushie", "aspect": "Thorns", "desc": "Your Thorns are doubled, but you can't gain Shield.", "cost": 0, "starter": true, "pool": "normal", "tier": "rare", "icon": "🌵"},
	{"id": "monochrome_prism", "name": "Monochrome Prism", "aspect": "Marbles", "desc": "A chant of one colour only makes every card it wakes 50% stronger.", "cost": 0, "starter": true, "pool": "normal", "tier": "rare", "icon": "🍧"},
	{"id": "shopping_list", "name": "Shopping List", "aspect": "Spells", "desc": "Your spells with a pattern of 3 marbles or longer get +1 Repeatable.", "cost": 0, "starter": true, "pool": "normal", "tier": "rare", "icon": "🧾"},
	{"id": "magician_hat", "name": "Magician Hat", "aspect": "Power", "desc": "+1 Power for each empty slot in your active row and each broken card.", "cost": 0, "starter": true, "pool": "normal", "tier": "rare", "icon": "🎩"},
	{"id": "leather_glove", "name": "Leather Glove", "aspect": "Spells", "desc": "Your cards with Durability get +1 Durability.", "cost": 0, "starter": true, "pool": "normal", "tier": "common", "icon": "🧤"},
	{"id": "blood_pact", "name": "Blood Pact", "aspect": "Power", "desc": "-10 max HP when you pick it up. Start each fight with 3 Power; lose 1 of it each time you take damage.", "cost": 0, "starter": true, "pool": "normal", "tier": "rare", "icon": "📜"},
	{"id": "switcheroo", "name": "Switcheroo", "aspect": "Spells", "desc": "The first of your spells that breaks in a fight replaces itself: choose a card from your backpack to take its place.", "cost": 0, "starter": true, "pool": "normal", "tier": "rare", "icon": "🔄"},
	{"id": "cursed_book", "name": "Cursed Book", "aspect": "Boss", "desc": "+1 spell slot and 1 more marble each turn. When you pick it up, a curse lands on 3 of your active spells.", "cost": 0, "starter": true, "pool": "boss", "tier": "legendary", "icon": "📕"},
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
	"kindling_stone": [3, 2, "Every 2nd spell: apply 1 Burn to a random enemy."],
	"lock_pick": [1, 2, "Locks on your spells are 2 shorter."],
	"rain_chalice": [4, 6, "Start each fight with 6 Lasting Shield."],
	"ward_stone": [1, 2, "Start each fight with 2 Evasion."],
	"shield_of_silence": [5, 8, "Passing your turn without chanting grants 8 Lasting Shield."],
	"thornbark": [1, 2, "Thorns 2 every fight."],
	"iron_bark": [1, 2, "Gain 2 Lasting Shield each turn."],
	"healing_sap": [4, 6, "Heal 6 after each fight."],
	"mending_moss": [1, 2, "Heal 2 each turn."],
	"scholar_quill": [4, 5, "Spell rewards: 5 choices."],
}


## The number an artifact works with: its + number when upgraded.
static func num(id: String, plus := false) -> float:
	if not PLUS.has(id):
		return 0.0
	return float(PLUS[id][1] if plus else PLUS[id][0])


static func can_upgrade(id: String) -> bool:
	return PLUS.has(id) and PLUS[id].size() > 2


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
			return [ready, "READY: your next spell applies 1 Burn to a random enemy." if ready else "%d / %d spells" % [p.kindling_chants, every]]
		"magic_box":
			var nth := p.box_casts % 6
			return [nth == 5, "READY: your next spell's pattern is Refunded after the Release." if nth == 5 else "%d / 6 spells" % nth]
		"nice_lute":
			var lute := p.lute_casts % 10
			return [lute == 9, "READY: your next spell plays a tune: 1 Weaken on all enemies." if lute == 9 else "%d / 10 spells" % lute]
	return []


static func is_curse(id: String) -> bool:
	return get_def(id).get("aspect", "") == "Cursed"


const RARE_CHANCE := 0.25
const TIER_NAMES := {"common": "Common", "rare": "Rare", "legendary": "Legendary"}


## Up to n artifacts from a pool that you have unlocked and don't own. In the normal pool each pick is
## Rare 25% of the time (Common otherwise), falling back to whatever is left.
static func offer(unlocked: Array, owned: Array, rng: RandomNumberGenerator, n := 3, pool_name := "normal") -> Array:
	var pool := ALL.filter(func(a): return a.pool == pool_name and (a.id in unlocked or a.starter) and (not (a.id in owned) or a.get("stack", false)))  # (a Mystery Book can come again)
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
