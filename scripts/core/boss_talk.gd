class_name BossTalk
extends RefCounted
## Talking to a boss before the fight (written with the user: docs/dialogue/<boss>.md). Before you Engage, only the
## boss, the background and your bag are on screen. Each option you pick may cost an Essence from your starting bag
## (the fight gets harder) and may have an effect. There's no going back up the tree, and Engage! is always there.
##
## A node: {id, say (your line; "*...*" is an action), cost ("F" / "W" / "A" / ""), reply (the boss's line), note
## (narration after the reply), show (an artifact id to show, hover to read), effects: [...], options: [nodes]}.
## Effects: "refund_plus2" (every Essence the talk cost you comes back, + 2 random), "enrage" (the boss gains +1
## Power whenever you gain Shield), "weaken2" (Weaken 2 on the boss), "artifact:<id>", "engage" (the fight starts).
## An option whose whole branch you've explored (in any run) gets a green tick: SaveManager setting "talk_seen".

const TREES := {
	"handyman": {
		"name": "The Handyman", "who": "hm_who",
		"opening": "A stranger blocks the road, flexing more fingers than you can count.",
		"options": [
			{"id": "hm_who", "say": "Who are you?", "cost": "W", "reply": "Can't you see? I am the Handyman. I got HANDS.", "options": [
				{"id": "hm_who_count", "say": "How many hands have you got, exactly?", "cost": "",
					"reply": "Let me count. One, two... At least four. Is that too many? I don't know. I was created like this. Why don't you count for yourself?", "options": [
					{"id": "hm_who_count_do", "say": "*Count his hands.*", "cost": "", "note": "You only see 2 hands, but it seems he has more under his coat."},
					{"id": "hm_who_count_creator", "say": "Who created you?", "cost": "A",
						"reply": "The one with a twisted sense of humor. Do you understand how hard life is with so many hands? Of course you don't. You got off easy."},
					{"id": "hm_who_count_atleast", "say": "\"At least\"? You don't know how many hands you have?", "cost": "",
						"reply": "Who's got lots of thumbs and no brain? THIS guy! Muahahaha."},
				]},
				{"id": "hm_who_where", "say": "Where did you get all those hands?", "cost": "F",
					"reply": "From Fate, of course. Where else? Fate dictates everything, from your ugly face to my many hands. Hehehehe.", "options": [
					{"id": "hm_who_where_fate", "say": "Who is Fate?", "cost": "F",
						"reply": "Wow. Smart AND pretty. Fate made the world, genius. You too. You walk around in it every day and never asked? Must be nice under that rock."},
					{"id": "hm_who_where_face", "say": "Hey! My face is fine!", "cost": "",
						"reply": "No, it isn't. Hold still, I'll fix it.", "note": "His voice was gentle. The sword he pulled out was not."},
					{"id": "hm_who_where_sent", "say": "Did Fate send you here?", "cost": "W",
						"reply": "The Hands of Fate put me here. They put everything somewhere. Nobody asks where they'd like to go."},
				]},
				{"id": "hm_who_fix", "say": "Who do you fix things for?", "cost": "W", "reply": "Fix? Who said fix? These hands don't fix. They BREAK. WAARRGGGHH!!!", "options": [
					{"id": "hm_who_fix_what", "say": "What do you break?", "cost": "", "reply": "Your FACE! Gotcha dummy!"},
					{"id": "hm_who_fix_ok", "say": "Are you okay? I got some water for you.", "cost": "W",
						"reply": "Thank you for asking. Here, take this. No one has ever asked me that before. I would hate to break you here, Kind Heart.",
						"effects": ["refund_plus2"]},
				]},
			]},
			{"id": "hm_want", "say": "What do you want?", "cost": "F",
				"reply": "I wanted to create the most beautiful sculptures, or the comfiest chair. But these hands are too crude, too cruel.", "options": [
				{"id": "hm_want_cruel", "say": "Why are your hands so cruel?", "cost": "F",
					"reply": "I was made that way. If Fate had any sense of mercy, He would have given these cruel hands to a cruel soul. I guess I just need to be cruel.", "options": [
					{"id": "hm_want_cruel_dont", "say": "You don't have to be cruel.", "cost": "", "reply": "You know nothing, fool.", "effects": ["enrage", "engage"]},
					{"id": "hm_want_cruel_soul", "say": "Who decides what kind of soul you get?", "cost": "A",
						"reply": "Fate does. From beyond time and space, the Hands of Fate control everything. Even your very question just now is a part of their plan."},
					{"id": "hm_want_cruel_chairs", "say": "Then why do you dream of making chairs?", "cost": "",
						"reply": "I don't know. Maybe Fate made a mistake with me. Maybe I am the mistake.", "note": "For a moment, all his hands go still.", "effects": ["weaken2"]},
				]},
				{"id": "hm_want_chair", "say": "Have you ever tried to make a chair?", "cost": "A",
					"reply": "Too many. All of them turned out deadly. Here, have this one.", "show": "deadly_chair", "options": [
					{"id": "hm_want_chair_take", "say": "Take the chair.", "cost": "", "reply": "Enough talking. Time to get cruel.", "effects": ["artifact:deadly_chair"]},
					{"id": "hm_want_chair_refuse", "say": "Refuse the chair.", "cost": "", "reply": "Enough talking. Time to get cruel."},
				]},
				{"id": "hm_want_help", "say": "Maybe I could help you.", "cost": "", "reply": "Help? Me? Stop pitying me. Who are you to help anybody?", "options": [
					{"id": "hm_want_help_kind", "say": "I am Kind Heart, for my heart is kind. Here is some water for you.", "cost": "W",
						"reply": "...Thank you. I haven't met a kind heart in ages. Here. My best chair. The only one that never hurt anyone. Take care of it.",
						"effects": ["artifact:chair"]},
					{"id": "hm_want_help_comfy", "say": "Just someone who likes comfy chairs.", "cost": "",
						"reply": "Then you came to the wrong place. Don't worry. After this, you might never need to sit again."},
					{"id": "hm_want_help_nobody", "say": "Nobody. Forget I said anything.", "cost": "",
						"reply": "Exactly. Now hold still, nobody. Let me fix that face.", "note": "He pulled out a sword."},
				]},
			]},
			{"id": "hm_why", "say": "Why are you here?", "cost": "A", "reply": "I am here to stop you from going any further.", "options": [
				{"id": "hm_why_purpose", "say": "Why would you not want to let me go any further?", "cost": "W",
					"reply": "It is not what I want. It is my purpose. I have no say in this matter, and neither do you.", "options": [
					{"id": "hm_why_purpose_who", "say": "Who gave you this purpose?", "cost": "A", "reply": "My creator. Fate, He who exists beyond time and space."},
					{"id": "hm_why_purpose_say", "say": "Everyone has a say. Even you.", "cost": "", "reply": "Here is my say: Die, fool!"},
					{"id": "hm_why_purpose_sorry", "say": "Then I'm sorry it has to be this way.", "cost": "", "reply": "The feeling is mutual."},
				]},
				{"id": "hm_why_further", "say": "What lies further on?", "cost": "F",
					"reply": "Who knows? I have never travelled this road myself. But those who went... they all came back different. The same, but different.", "options": [
					{"id": "hm_why_further_how", "say": "Different how?", "cost": "F", "reply": "Like they finally knew where they were going."},
					{"id": "hm_why_further_who", "say": "Who came back?", "cost": "W", "reply": "The ones who couldn't understand the essence of Time and Space. So, most people."},
					{"id": "hm_why_further_same", "say": "Then I'll be the first to come back the same.", "cost": "",
						"reply": "If you stay the same, you would not come back. If you came back, you would not be the same. That was the rule."},
				]},
				{"id": "hm_why_past", "say": "Can't we just... walk past each other?", "cost": "",
					"reply": "Well, that would defeat the purpose of me being here, would it not?", "options": [
					{"id": "hm_why_past_fail", "say": "What happens if you fail your purpose?", "cost": "A",
						"reply": "I would be wiped out, and something much worse would take my place. You are lucky I am the one you met. The others are much trickier to deal with."},
					{"id": "hm_why_past_overrated", "say": "Purpose is overrated.", "cost": "", "reply": "Agreed, but no one can go against their purpose. Much less you and me."},
				]},
			]},
		],
	},
	"invoker": {
		"name": "The Invoker", "who": "inv_who",
		"opening": "A tall man in a ragged robe blocks the road.",
		"options": [
			{"id": "inv_who", "say": "Who are you?", "cost": "W", "reply": "I... am the Invoker: the Pinnacle of Wizards and Wizardry, the Master of the Elements.", "options": [
				{"id": "inv_who_prove", "say": "The Master of the Elements? Prove it.", "cost": "F", "reply": "Name any element.", "options": [
					{"id": "inv_who_prove_f", "say": "Fire.", "cost": "FF", "reply": "And now you can witness the Master of the Elements in action, mortal.", "effects": ["lens:F", "engage"]},
					{"id": "inv_who_prove_w", "say": "Water.", "cost": "WW", "reply": "And now you can witness the Master of the Elements in action, mortal.", "effects": ["lens:W", "engage"]},
					{"id": "inv_who_prove_a", "say": "Air.", "cost": "AA", "reply": "And now you can witness the Master of the Elements in action, mortal.", "effects": ["lens:A", "engage"]},
				]},
				{"id": "inv_who_teach", "say": "Who taught you magic?", "cost": "W",
					"reply": "Teachers, I have had many, but every one of them was destroyed, for a fatal mistake they all committed.", "options": [
					{"id": "inv_who_teach_why", "say": "What was their mistake?", "cost": "A", "reply": "They tried to stop me from obtaining the essence of Space and Time, from transcending Fate."},
					{"id": "inv_who_teach_me", "say": "Are you going to destroy me too?", "cost": "", "reply": "But of course. If not by the wish of Fate, then for my own amusement."},
				]},
				{"id": "inv_who_humble", "say": "Are you always this humble?", "cost": "",
					"reply": "You dare mock the Arch Wizard, mortal? I will give you but one chance. Apologize, now.", "options": [
					{"id": "inv_who_humble_sorry", "say": "I'm sorry, O Pinnacle of Wizardry.", "cost": "", "reply": "Very well, you have my forgiveness.", "effects": ["essence3"]},
					{"id": "inv_who_humble_no", "say": "No.", "cost": "", "reply": "So you have chosen... death.", "effects": ["engage"]},
					{"id": "inv_who_humble_laugh", "say": "*Laugh.*", "cost": "", "reply": "Inconceivable insolence! Behold: Wex Wex Wex!", "note": "A huge electrical explosion.", "effects": ["wexwexwex", "engage"]},
				]},
			]},
			{"id": "inv_want", "say": "What do you want?", "cost": "F", "reply": "To transcend my own fate and become the master of this universe.", "options": [
				{"id": "inv_want_mean", "say": "What do you mean, \"transcend your own fate\"?", "cost": "A",
					"reply": "A curious bug, aren't you, mortal? Very well. Seeing as you will be destroyed momentarily, I will entertain one of your questions.", "options": [
					{"id": "inv_want_mean_escape", "say": "How exactly does one escape Fate?", "cost": "A",
						"reply": "You cannot escape Fate, for He is the creator of this universe. You can only hope to defeat Him and become the new Fate. Only then will you be your own master."},
					{"id": "inv_want_mean_others", "say": "What happens to everyone else's fate?", "cost": "W", "reply": "I would be in control of their fates."},
					{"id": "inv_want_mean_colour", "say": "What's your favourite colour?", "cost": "",
						"reply": "The colour of my hair: golden, touched with silver, shining like the trees of a faraway land. Here, take one.",
						"show": "hair_of_the_fairest", "effects": ["artifact:hair_of_the_fairest"]},
				]},
				{"id": "inv_want_master", "say": "What would you do as master of the universe?", "cost": "W",
					"reply": "I will leave that to the wisdom of my future self. Only from the summit of the mountain can one see far, and from there, my wisdom will know no bounds.", "options": [
					{"id": "inv_want_master_fool", "say": "What if your future self is a fool?", "cost": "", "reply": "Your current self is a fool, for you have chosen death.", "effects": ["engage"]},
					{"id": "inv_want_master_never", "say": "And if you never reach the summit?", "cost": "F",
						"reply": "I am immortal, fool. Can you even conceive of it? 'Never' is not a word for an immortal. With boundless time comes boundless knowledge. Here, have a glimpse of immortality.",
						"effects": ["immortality", "forbidden_spells"]},
				]},
				{"id": "inv_want_enough", "say": "Isn't mastering the elements enough for you?", "cost": "", "reply": "It is never enough.", "options": [
					{"id": "inv_want_enough_what", "say": "What would be enough?", "cost": "",
						"reply": "Nothing. I was created this way. But our fight will be a worthy distraction for this endless life of mine."},
					{"id": "inv_want_enough_lonely", "say": "That sounds lonely.", "cost": "W",
						"reply": "It... is lonely. This thirst of mine can never be quenched. Perhaps, if I were master of my own soul, I could finally MAKE it be satisfied. You are kind, mortal. I shall bestow my wisdom upon you.",
						"effects": ["invoker_spells"]},
				]},
			]},
			{"id": "inv_why", "say": "Why are you here?", "cost": "A", "reply": "To stop mortals like you from walking the Path.", "options": [
				{"id": "inv_why_path", "say": "What is the Path?", "cost": "F",
					"reply": "The Path is the only path you could ever take. It matters not which way you turn or where you choose to stop; you are compelled to walk it.", "options": [
					{"id": "inv_why_path_lead", "say": "Where does the Path lead?", "cost": "A", "reply": "To the beginning and the end of everything. To the Hands of Fate, but not to Fate Himself."},
					{"id": "inv_why_path_stop", "say": "If I'm compelled to walk it, why try to stop me?", "cost": "",
						"reply": "As you are compelled to walk it, I am compelled to stop you. It has been written in our fates."},
					{"id": "inv_why_path_you", "say": "Do you walk a Path too?", "cost": "W",
						"reply": "I once walked a different Path, but the master of this universe brought me here and trapped me like a caged animal. But worry not, mortal, for soon I will transcend my own fate and bring this universe under my command."},
				]},
				{"id": "inv_why_before", "say": "Who walked the Path before me?", "cost": "W",
					"reply": "No one but you, in all conceivable universes. You alone can walk this Path.", "options": [
					{"id": "inv_why_before_me", "say": "Why me?", "cost": "F",
						"reply": "It was the will of Fate. Maybe the answer you seek lies at the end of this Path. Or maybe your journey ends here.",
						"note": "Fire, water and ice shards begin to swirl around his fingers."},
					{"id": "inv_why_before_back", "say": "Then who are the ones who came back different?", "cost": "W", "requires": "hm_why_further",
						"reply": "You. A newly reborn you, with more knowledge and purpose. There has only ever been one traveller on this Path."},
					{"id": "inv_why_before_pressure", "say": "That's a lot of pressure.", "cost": "",
						"reply": "Let me end your worries once and for all, mortal.", "note": "Fire, water and ice shards begin to swirl around his fingers."},
				]},
				{"id": "inv_why_scenic", "say": "Can I just take the scenic route?", "cost": "",
					"reply": "Your feeble wit amuses me not. I will entertain one last question before I turn you to dust.", "options": [
					{"id": "inv_why_scenic_after", "say": "What happens to me after the dust?", "cost": "A",
						"reply": "I applaud your foolish bravery in the face of great danger. Here, let us enjoy this occasion.",
						"note": "With a chant from a tongue long lost to time, the Invoker expands your mind and his.", "effects": ["mind", "choose2", "engage"]},
					{"id": "inv_why_scenic_mortal", "say": "Why do you call everyone \"mortal\"?", "cost": "",
						"reply": "For I am the immortal Invoker, and your insignificant existence does not deserve a name."},
					{"id": "inv_why_scenic_gold", "say": "Could you turn me into gold dust instead?", "cost": "", "reply": "Certainly,", "note": "he said, with a twisted grin.",
						"effects": ["gold_dust", "engage"]},
				]},
			]},
		],
	},
}


## The speaker's name: "???" until you've asked who they are (in any run; this very answer counts).
static func speaker(tree: Dictionary) -> String:
	return String(tree.get("name", "???")) if String(tree.get("who", "")) in seen() else "???"


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


## Explored all the way down (in any run): it gets the green tick.
static func exhausted(node: Dictionary, seen_ids: Array) -> bool:
	if not (node.get("id", "") in seen_ids):
		return false
	for o in node.get("options", []):
		if not exhausted(o, seen_ids):
			return false
	return true


## The Codex's Forbidden Knowledge page: all unreadable symbols at first; each Forbidden Knowledge spell cast (across
## runs) turns another third of its opening into words. The rest of the page stays symbols.
const FORBIDDEN_TEXT := "The Hands of Fate is merely a tool, a servant to Fate Himself. Defeating him would but reset your progress, unless you have obtained the essences of Time, Space and Perfection. To gather them, you mus"
const GLYPHS := "¤§¶†‡ÞþðÐæÆøØßµ±÷×¿¡«»©®°¬ƒ"


static func forbidden_text(cast_count: int) -> String:
	var rng := RandomNumberGenerator.new()
	rng.seed = 1337
	var readable := int(FORBIDDEN_TEXT.length() * clampi(cast_count, 0, 3) / 3.0)
	var out := ""
	for i in FORBIDDEN_TEXT.length():
		var ch := FORBIDDEN_TEXT[i]
		var glyph := GLYPHS[rng.randi() % GLYPHS.length()]
		out += ch if i < readable or ch == " " else glyph
	# and a whole page more of it, never readable
	for i in 1500:
		out += " " if rng.randf() < 0.17 else GLYPHS[rng.randi() % GLYPHS.length()]
	return out
