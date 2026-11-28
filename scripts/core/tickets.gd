class_name Tickets
extends RefCounted
## Tickets (the user, 2026-11-27): carnival tickets take the place of the bottles. You hold at most SLOTS; the
## merchant sells them, fixed events give a set one, and a won fight sometimes drops one (its own scene after the
## reward). A ticket has no words on it, only its picture (TicketView draws it); hovering it tells what it does.
##
## `use` says where it works: "any" (a fight, the map, the shop, an event), "fight" (only in a fight), "out" (only
## outside a fight), "rehearsal" (a fight or the shop), "pay" (the shop, or an event that asks a price).
## `sym`: what TicketView draws in its middle. What each one does: RunState.use_ticket_out / MarblesFight.use_ticket.

const SLOTS := 2
const DROP := {"fight": 0.25, "elite": 0.5, "boss": 1.0}  # the chance a won fight drops a ticket
const RARE_ODDS := 0.2  # a ticket that drops (or is on the shelf) is a Rare one this often
const PRICE := {"common": 35, "rare": 70}
const HEAL_PCT := 0.3
const SHIELD_PCT := 0.5

const ALL := [
	{"id": "health", "name": "Ticket of Health", "sym": "heart", "rarity": "common", "use": "any", "desc": "Heal 30% of your max HP."},
	{"id": "marble", "name": "Marble Ticket", "sym": "marble", "rarity": "common", "use": "any",
		"desc": "Permanently keep 1 of 3 marbles."},
	{"id": "shield", "name": "Ticket of Shield", "sym": "shield", "rarity": "common", "use": "fight", "desc": "Gain Shield equal to 50% of your max HP."},
	{"id": "greater_marble", "name": "Ticket of Greater Marble", "sym": "marbles", "rarity": "rare", "use": "any",
		"desc": "Permanently keep 2 of 5 marbles."},
	{"id": "duplication", "name": "Ticket of Duplication", "sym": "twins", "rarity": "common", "use": "any",
		"desc": "Duplicate a marble that you have."},
	{"id": "timeout", "name": "Ticket of Timeout", "sym": "hourglass", "rarity": "common", "use": "fight",
		"desc": "Only in a fight: Open your backpack. You can rearrange your cards."},
	{"id": "wax", "name": "Wax Ticket", "sym": "wax", "rarity": "common", "use": "any", "desc": "Add 1 wax seal to a spell."},
	{"id": "blessing", "name": "Ticket of Blessing", "sym": "halo", "rarity": "common", "use": "out", "desc": "Remove one curse from a spell."},
	{"id": "fixing", "name": "Ticket of Repair", "sym": "tools", "rarity": "common", "use": "fight", "desc": "Restore a spell to full Durability."},  # (the user, 2026-11-28)
	{"id": "money", "name": "Ticket of Money", "sym": "coins", "rarity": "rare", "use": "any", "desc": "Double your coins."},
	{"id": "discount", "name": "Ticket of Discount", "sym": "percent", "rarity": "common", "use": "pay",
		"desc": "Get a discount!"},
	{"id": "carving", "name": "Ticket of Carving", "sym": "chisel", "rarity": "common", "use": "out",
		"desc": "Carve a plain marble of your bag: choose 1 of 3 symbols."},
	{"id": "encore", "name": "Ticket of Echo", "sym": "masks", "rarity": "common", "use": "fight", "desc": "The next card you cast triggers a second time."},
	{"id": "rehearsal", "name": "Ticket of Rehearsal", "sym": "redo", "rarity": "common", "use": "rehearsal",
		"desc": "Discard and redraw all marbles not in the chant, and reroll the items in the shop."},  # (the user's words, 2026-11-28)
	{"id": "upgrade", "name": "Ticket of Upgrade", "sym": "star_up", "rarity": "rare", "use": "any", "desc": "Upgrade one of your cards by one level."},
	{"id": "removal", "name": "Ticket of Removal", "sym": "scissors", "rarity": "common", "use": "any",
		"desc": "Permanently remove a marble and draw another one."},
	{"id": "mystery", "name": "Mystery Ticket", "sym": "question", "rarity": "common", "use": "any", "desc": "Get 2 random tickets."},
]

## (The user's wording, 2026-11-28. Duplication: outside a fight, any marble of your bag; in a fight, one of the marbles
## out this turn, its copy going into your bag for good (shuffled into what is still to draw). Wax and Upgrade work in a
## fight too, without saying so. Timeout says "Only in a fight" in its own words, so no use line is added under it.)
const USE_WORDS := {"fight": "Only in a fight.", "out": "Only outside a fight.", "rehearsal": "In a fight or in the shop.",
	"pay": "In the shop, or when an event asks a price."}


static func get_def(id: String) -> Dictionary:
	for t in ALL:
		if t.id == id:
			return t
	return {}


static func ids() -> Array:
	return ALL.map(func(t): return String(t.id))


static func price(id: String) -> int:
	return int(PRICE.get(String(get_def(id).get("rarity", "common")), PRICE.common))


static func is_rare(id: String) -> bool:
	return String(get_def(id).get("rarity", "")) == "rare"


## A random ticket: a Rare one RARE_ODDS of the time. `but`: ids to leave out.
static func random(rng: RandomNumberGenerator, but: Array = []) -> String:
	var rare := rng.randf() < RARE_ODDS
	var pool: Array = ids().filter(func(id): return not (id in but) and is_rare(id) == rare)
	if pool.is_empty():
		pool = ids().filter(func(id): return not (id in but))
	return String(pool[rng.randi() % pool.size()])


## Where it can be used, as `where` says where you are: "fight", "shop", "event" (an event that asks a price), "map".
static func usable_in(id: String, where: String) -> bool:
	match String(get_def(id).get("use", "any")):
		"any":
			return true
		"fight":
			return where == "fight"
		"out":
			return where != "fight"
		"rehearsal":
			return where in ["fight", "shop"]
		"pay":
			return where in ["shop", "event"]
	return false


## What its hover says: its name (rarity colour, as artifacts do), what it does, and where it works.
static func tooltip(id: String) -> String:
	var d := get_def(id)
	if d.is_empty():
		return ""
	var col := "#5ec46a" if is_rare(id) else "#ffffff"
	var where: String = USE_WORDS.get(String(d.use), "")
	return "[color=%s][b]%s[/b][/color]\n%s%s" % [col, d.name, d.desc, ("\n[i]%s[/i]" % where) if where != "" else ""]
