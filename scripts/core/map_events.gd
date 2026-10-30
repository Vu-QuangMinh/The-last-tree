class_name MapEvents
extends RefCounted
## "?" rooms. Stepping into one usually brings an event (a little story with choices), but it can also turn out
## to be a fight, a merchant or treasure. Each option: label, optional costs (amber / hp / max_hp), and what it does:
## Extra prices an option can ask: lose_spells n (n random spells, gone) · burden n (n random spells need 1 more
## Essence). An event's "weight" (default 1) makes it rarer or commoner among the "?" rooms.
##   heal n · lose_hp n · max_hp n · amber n · upgrade n (a wax seal on n random spells) · spell rarity · artifact pool
##   bottle n (n random bottles, if you have room)
##   gamble (50%: heal to full, else an ambush fight) · fight · none
##   upgrade_artifact (a random one becomes its + version) · trade_artifacts (give 2 of a tier, pick 1 of the next)

const ALL := [
	# ---- rewritten from docs/events.xlsx (the user's notes are canon). An option's "label" is all the player sees
	# before choosing (a Leaves price is on it; HP is never shown: a surprise, and it can kill). After the choice one
	# outcome is rolled ("chance"; they add up to 1) and only its "text" is shown: the text itself says what happened.
	# Outcome effects ("do"): bottles n (random) · bottle_ids [...] · poison_next n · damage n · heal n
	# · max_hp n (and heal as much) · amber n · artifact pool (normal / curse) · artifact_id id
	# · fight {kind: fight / elite, ids?, gift: [Essence you start it with]}.
	# An option can also "pick_bottle" (you choose a bottle to give away first; greyed out with none) or open a
	# "next" page of options.
	{"id": "well", "acts": [1], "title": "The Whispering Well", "text": "A mossy well whispers your name. It sounds hungry, and a little bit greedy.",
		"options": [
			{"label": "Toss in 50 Leaves", "amber": 50, "outcomes": [
				{"chance": 1.0, "text": "The well seems pleased with your leaves. Two bottles float up to the surface for you.", "do": [{"op": "bottles", "n": 2}]}]},
			{"label": "Drink from it", "outcomes": [
				{"chance": 1.0, "text": "The well was not pleased with that. Your stomach turns, and it will still be turning when your next fight starts.", "do": [{"op": "poison_next", "n": 3}]}]},
			{"label": "Jump in", "outcomes": [
				{"chance": 1.0, "text": "At the bottom you find a cursed artifact, at the price of a broken leg.", "do": [{"op": "damage", "n": 15}, {"op": "artifact", "pool": "curse"}]}]}]},
	{"id": "lost_sprite", "acts": [1], "title": "A Lost Sprite", "text": "A tiny wind sprite is crying under a leaf. He says a mean monster has taken over his house, and he begs you for help.",
		"options": [
			{"label": "Help him confront the monster", "outcomes": [
				{"chance": 1.0, "text": "The monster is indeed very mean. Your new friend tries his best to help you, which is not much: a little breeze, 2 Air to start the fight.", "do": [{"op": "fight", "kind": "elite", "gift": ["A", "A"]}]}]},
			{"label": "Refuse to help", "outcomes": [
				{"chance": 1.0, "text": "The wind sprite stops crying. He understands that it would do him no good, and that no one is going to help him.", "do": []}]}]},
	{"id": "mushroom_ring", "acts": [1], "title": "The Mushroom Ring", "text": "Glowing mushrooms form a perfect circle. They look pretty edible, and you are hungry.",
		"options": [
			{"label": "Eat a mushroom", "outcomes": [
				{"chance": 0.5, "text": "It was poisonous. You lose 5 HP.", "do": [{"op": "damage", "n": 5}]},
				{"chance": 0.49, "text": "It was edible, and quite tasty. You heal 5 HP.", "do": [{"op": "heal", "n": 5}]},
				{"chance": 0.01, "text": "It was miraculous! You feel stronger than ever: +20 max HP, and you heal 20.", "do": [{"op": "max_hp", "n": 20}]}]},
			{"label": "Walk away", "outcomes": [
				{"chance": 1.0, "text": "You leave the mushrooms for someone hungrier.", "do": []}]}]},
	{"id": "hollow_stump", "acts": [1], "title": "The Hollow Stump", "text": "Something glints inside a hollow stump. Something else growls inside a hollow stump.",
		"weight": 0.4,
		"options": [
			{"label": "Reach in", "outcomes": [
				{"chance": 0.5, "text": "Your fingers close around a little bottle.", "do": [{"op": "bottles", "n": 1}]},
				{"chance": 0.25, "text": "You pull out a handful of golden leaves: 30 Leaves.", "do": [{"op": "amber", "n": 30}]},
				{"chance": 0.2, "text": "Something bites you, hard. You lose 5 HP.", "do": [{"op": "damage", "n": 5}]},
				{"chance": 0.05, "text": "Deep inside, something old and precious: an artifact!", "do": [{"op": "artifact", "pool": "normal"}]}]},
			{"label": "Throw in a bottle", "pick_bottle": true, "outcomes": [
				{"chance": 0.5, "text": "Your bottle hits something mean. It is coming out, and it is not happy.", "do": [{"op": "fight", "kind": "fight"}]},
				{"chance": 0.1, "text": "You hear it shatter somewhere deep down. Then nothing at all.", "do": []},
				{"chance": 0.4, "text": "\"Hey! Y'all quit chuckin' things in here! Here, take 'em back!\" Three broken bottles come flyin' out of the stump. \"Now leave us alone. Git!\"", "do": [{"op": "bottle_ids", "ids": ["broken_bottle", "broken_bottle", "broken_bottle"]}]}]},
			{"label": "Walk away", "outcomes": [
				{"chance": 1.0, "text": "Whatever lives in there can keep its shiny thing.", "do": []}]}]},
	{"id": "bard", "acts": [1], "unless_artifact": "nice_lute", "title": "A Travelling Bard", "text": "A bard with a lute made of antlers asks you what you think of his lute.",
		"options": [
			{"label": "That's animal cruelty!", "outcomes": [
				{"chance": 1.0, "text": "He is furious, and plays his lute furiously. The racket wakes up an Enraged Rolling Bear!", "do": [{"op": "fight", "kind": "elite", "ids": ["enraged_bear"]}]}]},
			{"label": "It is beautiful", "outcomes": [
				{"chance": 1.0, "text": "The bard is pleased with the compliment and plays you a beautiful song. You heal 10 HP.", "do": [{"op": "heal", "n": 10}]}]},
			{"label": "Can I have it?", "next": {"text": "The bard says yes. For a price, of course: 100 Leaves.",
				"options": [
					{"label": "Pay 100 Leaves", "amber": 100, "outcomes": [
						{"chance": 1.0, "text": "He hands you his lute with a little sigh. It is yours now: A Nice Lute.", "do": [{"op": "artifact_id", "id": "nice_lute"}]}]},
					{"label": "Actually, I don't have that much", "outcomes": [
						{"chance": 1.0, "text": "He seems disappointed, but nods at you politely.", "do": []}]}]}}]},
	{"id": "cursed_shrine", "acts": [1], "title": "A Cursed Shrine", "text": "A grinning idol sits on a heap of golden leaves. Inside its mouth hides a black box.",
		"weight": 0.4,
		"options": [
			{"label": "Pry the box from its mouth", "outcomes": [
				{"chance": 1.0, "text": "Its jaw snaps shut on your hand as you pull the box free. You lose 10 HP. Inside the box: a cursed artifact.", "do": [{"op": "damage", "n": 10}, {"op": "artifact", "pool": "curse"}]}]},
			{"label": "Take the leaves", "outcomes": [
				{"chance": 1.0, "text": "The idol bites you as you scoop up the leaves. You lose 10 HP, and gain 50 Leaves.", "do": [{"op": "damage", "n": 10}, {"op": "amber", "n": 50}]}]},
			{"label": "Put down 100 more Leaves", "amber": 100, "outcomes": [
				{"chance": 1.0, "text": "The idol seems pleased, and drops the box from its jaw. Inside: an artifact.", "do": [{"op": "artifact", "pool": "normal"}]}]}]},
	{"id": "amber_vein", "acts": [1], "title": "A Golden Thicket", "text": "Golden leaves have drifted deep under a bramble. They look valuable, and the bramble looks extremely sharp.",
		"options": [{"label": "Reach in (lose 5 HP): +45 Leaves", "hp": 5, "do": "amber", "n": 45},
			{"label": "Admire it and move on", "do": "none"}]},
	{"id": "old_tome", "acts": [1], "title": "An Old Spellbook", "text": "A book lies open on a stone, its pages turning by themselves. Reading it would cost you something.",
		"options": [{"label": "Read it (lose 10 max HP): 2 random spells need 1 Essence less", "max_hp": 10, "do": "upgrade", "n": 2},
			{"label": "Close it gently", "do": "none"}]},
	{"id": "squirrel", "acts": [1], "title": "A Squirrel Merchant", "text": "A squirrel in a tiny waistcoat offers you a very special acorn.",
		"options": [{"label": "Buy it for 25 Leaves (+6 max HP)", "amber": 25, "do": "max_hp", "n": 6},
			{"label": "Politely decline", "do": "none"}]},
	{"id": "tinker", "acts": [1], "title": "The Tinker's Cart", "text": "A gnome with a hundred tiny tools squints at your pack. \"I can make any of those better. For a price, naturally.\"",
		"options": [{"label": "Pay 40 Leaves: upgrade a random artifact", "amber": 40, "do": "upgrade_artifact"},
			{"label": "No thank you", "do": "none"}]},
	{"id": "barterer", "acts": [1], "title": "The Barterer", "text": "An old tortoise wears a shell piled high with trinkets. \"Two of yours for one of mine. Mine are better. Mostly.\"",
		"options": [{"label": "Trade 2 artifacts of the same tier for 1 of the next tier", "do": "trade_artifacts"},
			{"label": "Keep what you have", "do": "none"}]},
	{"id": "lost_camp", "acts": [1], "title": "An Abandoned Camp", "text": "Someone left in a hurry. The fire is still warm, and there is a pouch by the bedroll.",
		"options": [{"label": "Rest by the fire (heal 10)", "do": "heal", "n": 10},
			{"label": "Search the pouch (+30 Leaves)", "do": "amber", "n": 30},
			{"label": "Check the saddlebag (a random bottle)", "do": "bottle", "n": 1}]},
	{"id": "inverted_pool", "acts": [1], "title": "The Upside-Down Pool", "text": "A still pool shows your spells upside down. It whispers that it could make one of them so, for good, if you let it drink.",
		"options": [{"label": "Let it drink half your HP: invert a spell (a spell becomes an anti-spell, an anti-spell a spell)", "hp_pct": 0.5, "do": "invert_spell"},
			{"label": "Step back from the edge", "do": "none"}]},
	{"id": "apothecary", "acts": [1], "title": "A Wandering Apothecary", "text": "A mole in thick spectacles rattles a cart full of little glass bottles. \"Panic, bottled! Very reasonably priced.\"",
		"options": [{"label": "Pay 25 Leaves: 2 random bottles", "amber": 25, "do": "bottle", "n": 2},
			{"label": "Ask for a free sample (lose 3 HP): a random bottle", "hp": 3, "do": "bottle", "n": 1},
			{"label": "Walk on", "do": "none"}]},
	{"id": "note_to_self", "acts": [1], "title": "A Note to Yourself", "text": "A folded note is pinned to a tree, in handwriting you know very well. \"Thought you might need this. Leave one for next time.\"",
		"options": [{"label": "Take the spell in the note, and leave one of yours in it", "do": "note_swap"},
			{"label": "Leave the note for another day", "do": "none"}]},
	{"id": "farmer_farm", "acts": [1], "title": "The Farmer's Farm",
		"text": "Once upon a time, at the edge of the old wood, there was a farm that had seen far better days. Its fences leaned, its barn sagged, and its wheat rustled with goblins, giggling as they nibbled the harvest away. In the middle of it all sat the farmer, hat in his hands, as worn and sad as his fields.\n\n\"Traveller,\" he says, \"you look like someone who could help an old man. Will you?\"",
		"options": [
			{"label": "Of course", "next": {"text": "\"Bless you!\" The farmer is on his feet at once. \"They're goblins. They pop up out of the wheat to nibble the ears, then duck back down. Shoot every one you see and I'll give you a Leaf a head. The big ones are hobgoblins: they take three shots, but they're worth 5 apiece. But mind the green ones! Those are the fairies who look after my fields, and every one you shoot will cost you 2 Leaves. You've got one minute before they eat the lot.\"",
				"options": [{"label": "Ready", "minigame": "farm"}]}},
			{"label": "No way! I'm too busy to deal with peasants' problems", "outcomes": [
				{"chance": 1.0, "text": "\"I see,\" says the farmer quietly, and goes back to staring at his wheat. You walk on.", "do": []}]}]},
]


static func get_event(id: String) -> Dictionary:
	for e in ALL:
		if e.id == id:
			return e
	return {}
