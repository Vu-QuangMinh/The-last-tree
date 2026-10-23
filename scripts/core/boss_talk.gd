class_name BossTalk
extends RefCounted
## Talking to a boss before the fight (written with the user: docs/dialogue/<boss>.md). Before you Engage, only the
## boss, the background and your bag are on screen. Each option you pick may cost an Essence from your starting bag
## (the fight gets harder) and may have an effect. There's no going back up the tree, and Engage! is always there.
##
## A node: {id, say (your line; "*...*" is an action), cost ("F" / "W" / "A" / ""), reply (the boss's line), note
## (narration after the reply), show (an artifact id to show, hover to read), effects: [...], options: [nodes]}.
## Effects: "artifact:<id>" (you get that artifact now), "win_artifact:<id>" (you get it, and it's unlocked for
## good, if you win this fight), "engage" (the fight starts).
## An option whose whole branch you've explored (in any run) gets a green tick: SaveManager setting "talk_seen".

## boss id -> its tree: {name, who (the option id that reveals its name), opening (narration), options: [nodes]}.
## pre: narration before the boss's reply ("Without looking at you, his voice bellows:"). first_note: narration after
## your line, only the first time you ever meet this boss ("You lied straight to his face.").
## greeting: what the boss says right after the opening. A node may also have reply2 / note2: more of the boss's
## answer after its narration ("He unfolds the Tweezer Hand." and then he goes on). A boss without a tree has no talk.
const TREES := {
	# (no words yet: just its entrance, then Engage! Its name stays "???": nothing ever reveals it before the fight)
	"veiled_eyes": {
		"name": "Violet Eyes", "who": "veiled_eyes_never",
		"opening": "Two haunting violet eyes pierce through a thin black veil. They look at you in desperation.",
		"options": [],
	},
	"handyman": {
		"name": "The Handyman", "who": "", "voice_greeting": "hm_greeting",
		"opening": "A tall figure with an unsettling smile blocked the road.",
		"greeting": "Hello there, weary traveler. You seem burdened. Would you like me to give you A HAND? Hehe, hehehe.",
		"options": [
			{"id": "hm_sure", "say": "Sure, please give me a hand.", "cost": "",
				"reply": "How about MORE than just A hand? Muahahahah!", "note": "He laughs maniacally as his impossibly long arms start to unfold.", "effects": ["engage"]},
			{"id": "hm_creepy", "say": "You are creeping me out. Stop that.", "cost": "",
				"reply": "Thank you for your compliment. Let's see how you feel about this! Muahahahah!", "note": "He laughs maniacally as his impossibly long arms start to unfold.", "effects": ["engage"]},
			{"id": "hm_why", "say": "Why are you here?", "cost": "F", "reply": "Fate put me here to, uhm, fix you up. Hehe, hehe.", "options": [
				{"id": "hm_why_end", "say": "Alright, let's put an end to that creepy laugh of yours.", "cost": "", "effects": ["engage"]},
				{"id": "hm_why_chance", "say": "You mean, like, you're here by accident? By chance? Can you let me go, then?", "cost": "A",
					"reply": "Oh no, my Chosen One, it was written. You were destined to walk this Path and be... HANDLED by me. Hehe, you will get that soon enough. Hehehehe.",
					"options": [
					{"id": "hm_why_chance_show", "say": "Show me.", "cost": "", "reply": "With pleasure! Muahahahah!", "note": "He laughs maniacally as his impossibly long arms start to unfold.", "effects": ["engage"]},
					{"id": "hm_why_chance_hands", "say": "OK, so there's something special about your hands, isn't there? Mind telling me what it is?", "cost": "W",
						"reply": "My hands are a gift from God. They are so wonderful. Here, take a look at this one.", "note": "He unfolds the Tweezer Hand.",
						"reply2": "This used to belong to a great artist, but it is MINE now. I will show you the rest, in due time. Hahahahaha.",
						"note2": "He laughs maniacally as his impossibly long arms start to unfold.", "effects": ["win_artifact:mysterious_hand", "engage"]},
				]},
			]},
		],
	},
	"invoker": {
		"name": "Good Ol' Wizard", "who": "",
		"opening": "A troubled man with an impossibly old face sat on the side of the road. He was not aware of your approach.",
		"options": [
			{"id": "wiz_sneak", "say": "*Try to sneak past him.*", "cost": "", "pre": "Without looking at you, his voice bellows:",
				"reply": "Not so fast, scoundrel. This old man still has a job to do.", "effects": ["engage"]},
			{"id": "wiz_warmth", "say": "Hi there, stranger. You look troubled. Care for some warmth?", "cost": "F",
				"reply": "Thank you, Chosen One. But why call me a stranger? Oh, never mind, never mind.",
				"note": "He hushed quickly, as if he were afraid someone could hear what he said.", "options": [
				{"id": "wiz_first", "say": "Well, this is my first time meeting you, so...", "cost": "",
					"reply": "Of course, of course. Pardon this ol' fool. Time has not been kind to me, you see. Oh well, time to start.",
					"note": "He stands up and dusts off his robes. He faces you with unmistakable resignation.", "effects": ["engage"]},
				{"id": "wiz_messing", "say": "Oh, I'm just messing with you. How are you doing, man? Why do you look so down?", "cost": "A",
					"first_note": "You lied straight to his face.",
					"reply": "I am still worried about Knivel. He has been gone for 273 years already. He said he would be back soon, but at this point, I think something bad may have happened to him.",
					"options": [
					{"id": "wiz_fine", "say": "Nah, I think he'll be fine. Stop being so worried all the time and enjoy life a little!", "cost": "",
						"reply": "Thank you, ol' friend. Now, let's start this dance that we are compelled to have.", "effects": ["engage"]},
					{"id": "wiz_find", "say": "Why don't you tell me where you last saw him, and I'll find him for you?", "cost": "W",
						"reply": "You would? Thank you, Chosen One. The last time I talked to Knivel, he headed out to find Nila. You remember Nila? The Darkblade? She was always trouble. I am afraid she might have hurt him. Anyway, Knivel gave me this box, saying it would help him find Nila, but he needed to find something else first. It was... Oh well, no marbles left in this ol' jar of mine. Here.",
						"note": "He gives you the Magic Box.", "reply2": "Oh well, time to start this dance that we are compelled to have.",
						"effects": ["artifact:magic_box", "engage"]},
				]},
			]},
		],
	},
}


## The recorded clips of a node (assets/Puppet/Voice/<boss>/<id>.wav, cut by tools/split_handyman_voice.py): the greeting of the tree's root, or the boss's
## reply of a node (<id>.wav, or <id>_a.wav then <id>_b.wav when the reply is split in two by a bit of narration). Only the files that exist.
static func voice_paths(tree: Dictionary, boss_id: String, node: Dictionary) -> Array:
	var base := "res://assets/Puppet/Voice/%s/" % boss_id
	var ids: Array = []
	if node.has("greeting") and tree.has("voice_greeting"):
		ids.append(String(tree.voice_greeting))
	if node.has("id") and node.has("reply"):
		if ResourceLoader.exists(base + String(node.id) + ".wav"):
			ids.append(String(node.id))
		else:
			ids.append(String(node.id) + "_a")
			ids.append(String(node.id) + "_b")
	return ids.map(func(i): return base + i + ".wav").filter(func(p): return ResourceLoader.exists(p))


## The speaker's name: "???" until you've asked who they are (in any run; this very answer counts).
static func speaker(tree: Dictionary) -> String:
	var who := String(tree.get("who", ""))
	return String(tree.get("name", "???")) if who == "" or who in seen() else "???"  # (no "who": named from the start)


## The conversation for this fight, or {} (the first enemy that has one: a boss, before its hands are out).
static func tree_for(boss_id: String) -> Dictionary:
	return TREES.get(boss_id, {})


static func seen() -> Array:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null or not tree.root.has_node("SaveManager"):
		return []
	return tree.root.get_node("SaveManager").setting("talk_seen", [])


static func mark_seen(id: String) -> void:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null or not tree.root.has_node("SaveManager"):
		return
	var sm = tree.root.get_node("SaveManager")
	var s: Array = sm.setting("talk_seen", []).duplicate()
	if not (id in s):
		s.append(id)
		sm.set_setting("talk_seen", s)


## Have you ever met this boss before (in any run)? Asked when the talk starts; meet() then records it.
static func met_before(boss_id: String) -> bool:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null or not tree.root.has_node("SaveManager"):
		return true
	return boss_id in tree.root.get_node("SaveManager").setting("bosses_met", [])


static func meet(boss_id: String) -> void:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null or not tree.root.has_node("SaveManager"):
		return
	var sm = tree.root.get_node("SaveManager")
	var met: Array = sm.setting("bosses_met", []).duplicate()
	if not (boss_id in met):
		met.append(boss_id)
		sm.set_setting("bosses_met", met)


## Explored all the way down (in any run): it gets the green tick.
static func exhausted(node: Dictionary, seen_ids: Array) -> bool:
	if not (node.get("id", "") in seen_ids):
		return false
	for o in node.get("options", []):
		if not exhausted(o, seen_ids):
			return false
	return true
