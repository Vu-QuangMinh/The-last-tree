class_name DiceArtifacts
extends RefCounted
## Die on Stage (2026-11-16): the artifacts, an artifact tile's reward (choose 1 of 3). A first set made up to fill the
## artifact tiles (PLACEHOLDERS: the user designs the real ones; 10/10 is the user's). Each works for the rest of the run.
## The Merchant sells one too (`price`, coins: 10 to 20).

const ITEMS := {
	"loaded_die": {"name": "Loaded Die", "icon": "🎲", "text": "Each turn, your lowest die is rolled again once.", "price": 15},
	"whetstone": {"name": "Whetstone", "icon": "🗡", "text": "Your moves deal +1 damage.", "price": 14},
	"leather_armor": {"name": "Leather Armor", "icon": "🦺", "text": "Reduce the damage of each attack on you by 1.", "price": 14},
	"spare_die": {"name": "Spare Die", "icon": "🎲", "text": "You roll a fourth die.", "price": 20},
	"healing_herb": {"name": "Healing Herb", "icon": "🌿", "text": "Heal 3 HP after each fight.", "price": 10},
	"coin_purse": {"name": "Coin Purse", "icon": "👛", "text": "+2 coins after each fight.", "price": 12},
	"ten_ten": {"name": "10/10", "icon": "🔟", "text": "All your dice become D10s (faces 1 to 10). Their mods are gone.", "price": 20},
}


static func price(id: String) -> int:
	return int(ITEMS.get(id, {}).get("price", 15))


static func get_item(id: String) -> Dictionary:
	return ITEMS.get(id, {})
