class_name MarbleItems
extends RefCounted
## Marble mode (2026-11-21): bottles, artifacts and prices. A FIRST SET made up to fill the shop and the boss rewards
## (placeholders: the user designs the real ones).

const BOTTLE_SLOTS := 3
## id -> {name, icon, text, price, t (needs a target)}; what each does: MarblesFight.use_bottle.
const BOTTLES := {
	"healing_draught": {"name": "Healing Draught", "icon": "❤", "text": "Heal 10.", "price": 5},
	"fire_flask": {"name": "Fire Flask", "icon": "🔥", "text": "Deal 8 damage.", "price": 5, "t": true},
	"ember_jar": {"name": "Ember Jar", "icon": "🏺", "text": "Apply 4 Burn to all enemies.", "price": 6},
	"iron_tonic": {"name": "Iron Tonic", "icon": "🛡", "text": "Gain 8 Shield.", "price": 4},
	"marble_pouch": {"name": "Marble Pouch", "icon": "🔮", "text": "Draw 2 more marbles now.", "price": 6},
	"smoke_bomb": {"name": "Smoke Bomb", "icon": "💨", "text": "Gain 1 Dodge.", "price": 4},
	"weakening_salts": {"name": "Weakening Salts", "icon": "🧂", "text": "Apply 2 Weakened to all enemies.", "price": 5},
}
## id -> {name, icon, text, price}
const ARTIFACTS := {
	"whetstone": {"name": "Whetstone", "icon": "🗡", "text": "Your cards deal +1 damage per hit.", "price": 14},
	"leather_armor": {"name": "Leather Armor", "icon": "🦺", "text": "Each attack on you deals 1 less.", "price": 14},
	"healing_herb": {"name": "Healing Herb", "icon": "🌿", "text": "Heal 3 after each fight.", "price": 10},
	"coin_purse": {"name": "Coin Purse", "icon": "👛", "text": "+2 coins after each fight.", "price": 12},
	"marble_sack": {"name": "Marble Sack", "icon": "🎒", "text": "Get 1 more marble each turn.", "price": 20},
	"iron_ward": {"name": "Iron Ward", "icon": "🛡", "text": "Start each fight with 6 Shield.", "price": 12},
}

## Card prices by rarity; a marble's (plain / carved); a "bag" (choose 1 of 3) costs BAG_DISCOUNT of the normal price.
const CARD_PRICE := {"common": 6, "rare": 9, "legendary": 13}
const MARBLE_PRICE := {"plain": 3, "carved": 6}
const BAG_DISCOUNT := 0.6


static func bag_price(normal: int) -> int:
	return maxi(1, int(round(normal * BAG_DISCOUNT)))


static func bottle(id: String) -> Dictionary:
	return BOTTLES.get(id, {})


static func artifact(id: String) -> Dictionary:
	return ARTIFACTS.get(id, {})
