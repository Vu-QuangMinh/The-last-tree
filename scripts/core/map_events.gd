class_name MapEvents
extends RefCounted
## "?" rooms. Stepping into one usually brings an event (a little story with choices), but it can also turn out
## to be a fight, a merchant or treasure. Each option: label, optional costs (amber / hp / max_hp), and what it does:
##   heal n · lose_hp n · max_hp n · amber n · upgrade n (a wax seal on n random spells) · spell rarity · artifact pool
##   bottle n (n random bottles, if you have room)
##   gamble (50%: heal to full, else an ambush fight) · fight · none
##   upgrade_artifact (pick one: it becomes its + version) · trade_artifacts (give 2 of a tier, pick 1 of the next)

const ALL := [
	{"id": "well", "title": "The Whispering Well", "text": "A mossy well whispers your name. It sounds hungry, and a little bit greedy.",
		"options": [{"label": "Drop in 20 Leaves (a random spell needs 1 Essence less)", "amber": 20, "do": "upgrade", "n": 1},
			{"label": "Drink deeply (heal 12)", "do": "heal", "n": 12},
			{"label": "Walk on", "do": "none"}]},
	{"id": "lost_sprite", "title": "A Lost Sprite", "text": "A tiny wind sprite is crying under a leaf. It swears it knows a great spell, if you can get it home.",
		"options": [{"label": "Guide it home (lose 6 HP): learn a Rare spell", "hp": 6, "do": "spell", "rarity": "rare"},
			{"label": "Wish it luck and leave", "do": "none"}]},
	{"id": "mushroom_ring", "title": "The Mushroom Ring", "text": "Glowing mushrooms form a perfect circle. Folk tales are very clear about what happens if you dance in one. Unfortunately, they disagree.",
		"options": [{"label": "Dance! (half the time: heal to full; otherwise: an ambush)", "do": "gamble"},
			{"label": "Walk around it, very carefully", "do": "none"}]},
	{"id": "hollow_stump", "title": "The Hollow Stump", "text": "Something glints inside a hollow stump. Something else growls inside a hollow stump.",
		"options": [{"label": "Reach in anyway (lose 8 HP): gain an artifact", "hp": 8, "do": "artifact", "pool": "normal"},
			{"label": "Leave it be", "do": "none"}]},
	{"id": "bard", "title": "A Travelling Bard", "text": "A bard with a lute made of antlers offers to teach you a song of legend. For a fee, naturally.",
		"options": [{"label": "Pay 35 Leaves: learn a Legendary spell", "amber": 35, "do": "spell", "rarity": "legendary"},
			{"label": "Just listen for a while (heal 5)", "do": "heal", "n": 5}]},
	{"id": "cursed_shrine", "title": "A Cursed Shrine", "text": "A grinning idol sits on a heap of golden leaves. The leaves are lovely. The grin is not.",
		"options": [{"label": "Take the idol and the leaves: a cursed artifact and 40 Leaves", "do": "curse_amber", "n": 40},
			{"label": "Pray instead (heal 8)", "do": "heal", "n": 8}]},
	{"id": "amber_vein", "title": "A Golden Thicket", "text": "Golden leaves have drifted deep under a bramble. They look valuable, and the bramble looks extremely sharp.",
		"options": [{"label": "Reach in (lose 5 HP): +45 Leaves", "hp": 5, "do": "amber", "n": 45},
			{"label": "Admire it and move on", "do": "none"}]},
	{"id": "old_tome", "title": "An Old Spellbook", "text": "A book lies open on a stone, its pages turning by themselves. Reading it would cost you something.",
		"options": [{"label": "Read it (lose 10 max HP): 2 random spells need 1 Essence less", "max_hp": 10, "do": "upgrade", "n": 2},
			{"label": "Close it gently", "do": "none"}]},
	{"id": "squirrel", "title": "A Squirrel Merchant", "text": "A squirrel in a tiny waistcoat offers you a very special acorn.",
		"options": [{"label": "Buy it for 25 Leaves (+6 max HP)", "amber": 25, "do": "max_hp", "n": 6},
			{"label": "Politely decline", "do": "none"}]},
	{"id": "tinker", "title": "The Tinker's Cart", "text": "A gnome with a hundred tiny tools squints at your pack. \"I can make any of those better. For a price, naturally.\"",
		"options": [{"label": "Pay 40 Leaves: upgrade an artifact (it becomes its + version)", "amber": 40, "do": "upgrade_artifact"},
			{"label": "No thank you", "do": "none"}]},
	{"id": "barterer", "title": "The Barterer", "text": "An old tortoise wears a shell piled high with trinkets. \"Two of yours for one of mine. Mine are better. Mostly.\"",
		"options": [{"label": "Trade 2 artifacts of the same tier for 1 of the next tier", "do": "trade_artifacts"},
			{"label": "Keep what you have", "do": "none"}]},
	{"id": "lost_camp", "title": "An Abandoned Camp", "text": "Someone left in a hurry. The fire is still warm, and there is a pouch by the bedroll.",
		"options": [{"label": "Rest by the fire (heal 10)", "do": "heal", "n": 10},
			{"label": "Search the pouch (+30 Leaves)", "do": "amber", "n": 30},
			{"label": "Check the saddlebag (a random bottle)", "do": "bottle", "n": 1}]},
	{"id": "apothecary", "title": "A Wandering Apothecary", "text": "A mole in thick spectacles rattles a cart full of little glass bottles. \"Panic, bottled! Very reasonably priced.\"",
		"options": [{"label": "Pay 25 Leaves: 2 random bottles", "amber": 25, "do": "bottle", "n": 2},
			{"label": "Ask for a free sample (lose 3 HP): a random bottle", "hp": 3, "do": "bottle", "n": 1},
			{"label": "Walk on", "do": "none"}]},
]


static func get_event(id: String) -> Dictionary:
	for e in ALL:
		if e.id == id:
			return e
	return {}
