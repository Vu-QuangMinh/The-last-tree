class_name MapEvents
extends RefCounted
## "?" rooms. Stepping into one usually brings an event (a little story with choices), but it can also turn out
## to be a fight, a merchant or treasure. Each option: label, optional costs (amber / hp / max_hp), and what it does:
##   heal n · lose_hp n · max_hp n · amber n · upgrade n (random spells) · spell rarity · artifact pool
##   gamble (50%: heal to full, else an ambush fight) · fight · none

const ALL := [
	{"id": "well", "title": "The Whispering Well", "text": "A mossy well whispers your name. It sounds hungry, and a little bit greedy.",
		"options": [{"label": "Drop in 20 Amber (upgrade a random spell)", "amber": 20, "do": "upgrade", "n": 1},
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
		"options": [{"label": "Pay 35 Amber: learn a Legendary spell", "amber": 35, "do": "spell", "rarity": "legendary"},
			{"label": "Just listen for a while (heal 5)", "do": "heal", "n": 5}]},
	{"id": "cursed_shrine", "title": "A Cursed Shrine", "text": "A grinning idol sits on a pile of amber. The amber is lovely. The grin is not.",
		"options": [{"label": "Take the idol and the amber: a cursed artifact and 40 Amber", "do": "curse_amber", "n": 40},
			{"label": "Pray instead (heal 8)", "do": "heal", "n": 8}]},
	{"id": "amber_vein", "title": "An Amber Vein", "text": "Golden sap has hardened along a cliff face. It looks valuable and extremely sharp.",
		"options": [{"label": "Dig it out (lose 5 HP): +45 Amber", "hp": 5, "do": "amber", "n": 45},
			{"label": "Admire it and move on", "do": "none"}]},
	{"id": "old_tome", "title": "An Old Spellbook", "text": "A book lies open on a stone, its pages turning by themselves. Reading it would cost you something.",
		"options": [{"label": "Read it (lose 4 max HP): upgrade 2 random spells", "max_hp": 4, "do": "upgrade", "n": 2},
			{"label": "Close it gently", "do": "none"}]},
	{"id": "squirrel", "title": "A Squirrel Merchant", "text": "A squirrel in a tiny waistcoat offers you a very special acorn.",
		"options": [{"label": "Buy it for 25 Amber (+6 max HP)", "amber": 25, "do": "max_hp", "n": 6},
			{"label": "Politely decline", "do": "none"}]},
	{"id": "lost_camp", "title": "An Abandoned Camp", "text": "Someone left in a hurry. The fire is still warm, and there is a pouch by the bedroll.",
		"options": [{"label": "Rest by the fire (heal 10)", "do": "heal", "n": 10},
			{"label": "Search the pouch (+30 Amber)", "do": "amber", "n": 30}]},
]


static func get_event(id: String) -> Dictionary:
	for e in ALL:
		if e.id == id:
			return e
	return {}
