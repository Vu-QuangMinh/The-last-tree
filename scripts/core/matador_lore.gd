class_name MatadorLore
extends RefCounted
## The Crowned Matador's questions (docs/story.md, "The Crowned Matador's questions"): the game's lore master. Each one opens
## once you have found what it is about, in any run (the flags are kept in the save: SaveManager setting "lore_flags",
## plus what BossTalk already remembers). Asked once, a question can be asked again (it shows a tick).
##
## A question: {id, ask (what you say), needs (when it opens: see is_open), pre (narration before he answers), lines (his
## answer, a verse or a single line), post (narration after), choices (your answers to him, Q1 only)}.

const QUESTIONS := [
	{"id": "who_are_you", "ask": "Who are you?", "needs": "",
		"lines": ["Pulse in my vein, yet there is no heart.", "Always running, but never goes first.", "Keep picking bones, but found no spine.",
			"Less than a man, yet same blood and hide.", "What am I?"],
		"choices": ["A coward.", "A father.", "A king."]},
	{"id": "aole", "ask": "Who is Aole?", "needs": "aole",
		"lines": ["A child of heaven with a heart of gold,", "Kind beyond measure, or so we are told.", "But she never saw what the world hides within:",
			"The knife in the smile, the rot under the skin.", "She promised her faithful a heaven to dwell,", "And led all who followed her straight into hell."]},
	{"id": "merchant", "ask": "How do I help the merchant?", "needs": "merchant_quest",
		"lines": ["Help him you may, and show him your pity,", "But his heart is gone, drowned in misery.", "Far down below, in a depth with no sun,",
			"Locked away forever, his beloved only son.", "The first sinner, the first to be punished:", "Look down and learn, ye untarnished."]},
	{"id": "mask", "ask": "Why do you wear a mask?", "needs": "",
		"lines": ["Trust is a cruel and treacherous killer;", "Learn to trust no one, not even your father,", "As I have learned not to trust my creator.", "",
			"Love or duty, what will it be?", "What choice did I have? What could my eyes see?", ". . . . . . .", "And so I endure, with eternal guilt:",
			"My love was the culprit, and my heart was killed."]},
	{"id": "princess", "ask": "I saved the princess. What now?", "needs": "princess",
		"pre": "Bottomless guilt and sadness pour out of the orifice of his ever-smiling mask.",
		"lines": ["Fairest of the seven seas,", "Sweetest there could ever be.", "Her eyes, a pair of shining stars;", "Her gaze heals the deepest scars.",
			"A tragedy: her soul has gone,", "Nevertheless, the show goes on."]},
	{"id": "pianist", "ask": "What happened to the Pianist?", "needs": "pianist",
		"lines": ["Theirs was a love story in this tragedy.", "Comical, isn't it? For love must be free,", "But their stars were fixed and their fates sworn.",
			"Thus, a broken man and his lady forlorn.", "Foolish, those two, for one thing is certain:", "There is no happiness behind the curtain."]},
	{"id": "nila", "ask": "Who is Nila the Witch?", "needs": "",
		"lines": ["A witch, yes, but never wicked.", "Her only sin was defiance, and her name twisted.", "Danced to a tune, cast as evil,",
			"In her heart of gold, a hatred boiled.", "With her comrades, they rode to fight Fate:", "\"To death or to freedom. Ride, we ride with haste!\"",
			"Yet they were blinded by a coward's betrayal,", "And for our Nila, it's darkness eternal."]},
	{"id": "horsemen", "ask": "Who were the four horsemen?", "needs": "church_listened",
		"lines": ["There was once a group of four", "Smart and strong and mischief galore", "Come of age and they found love", "Love for freedom, for each other and more", "",
			"So in the shadow, a plan was hatched", "The sacred code, long lost, was snatched", "To keep it safe, the secret was quartered", "But it mattered not, for they were caught."]},
	{"id": "nivel", "ask": "What happened to Nivel?", "needs": "wizard_talk",
		"lines": ["Cruel was his fate, and he was but a kid.", "Imagine the worst that you can, and double it.", "An innocent: sinless and obedient,",
			"Yet his love punished him more than anyone.", "He found the one he sought, but she saw him not:", "A cold blade and a quick death was all he got."]},
	{"id": "wizard", "ask": "Why does the Wizard remember me?", "needs": "wizard_friend",
		"lines": ["\"Because you look just like Aole.\""], "post": "A deep hatred boils at the name."},
	{"id": "basement", "ask": "How do I go down to the basement?", "needs": "act2_end",
		"lines": ["There was once a group of four,", "Followed a god, they broke the floor.", "The right of passage, they did obtain", "And passed it down, so not in vain.",
			"There were numbers, a song and some colours,", "Trusted to the ones who were wiser.", "One was even trusted to me:", "Save the princess, and it passes to thee."]},
	{"id": "who_am_i", "ask": "Who am I?", "needs": "",
		"lines": ["A god from the outer world, passing through,", "Or one who stays for decades, as some gods do.", "You are the Chosen One, and yet you are many.",
			"A being of endless potential, be what you want to be.", "Yet if you have a shred of mercy,", "A saviour, I beg you, do not be."]},
]


static func _save() -> Node:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null or not tree.root.has_node("SaveManager"):
		return null
	return tree.root.get_node("SaveManager")


## Something about the story was found (kept across runs): "aole", "church_listened", "merchant_quest", "princess", "act2_end".
static func flag(id: String) -> void:
	var sm := _save()
	if sm == null:
		return
	var flags: Array = sm.setting("lore_flags", []).duplicate()
	if not (id in flags):
		flags.append(id)
		sm.set_setting("lore_flags", flags)


static func has_flag(id: String) -> bool:
	var sm := _save()
	return sm != null and id in sm.setting("lore_flags", [])


## Is this question open? (Some are told by what the bosses' talks remember: the Pianist met, the Wizard talked to.)
static func is_open(q: Dictionary) -> bool:
	match String(q.needs):
		"":
			return true
		"pianist":
			return BossTalk.met_before("pianist") and _save() != null
		"wizard_talk":
			return BossTalk.met_before("invoker") and _save() != null
		"wizard_friend":
			return "wiz_fine" in BossTalk.seen()
	return has_flag(String(q.needs))


static func open_questions() -> Array:
	return QUESTIONS.filter(func(q): return is_open(q))


static func asked(id: String) -> bool:
	var sm := _save()
	return sm != null and id in sm.setting("matador_asked", [])


static func mark_asked(id: String) -> void:
	var sm := _save()
	if sm == null:
		return
	var a: Array = sm.setting("matador_asked", []).duplicate()
	if not (id in a):
		a.append(id)
		sm.set_setting("matador_asked", a)
