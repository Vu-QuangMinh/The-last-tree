class_name BossTalk
extends RefCounted
## Talking to a boss before the fight (written with the user: docs/dialogue/<boss>.md). Before you Engage, only the
## boss, the background and your bag are on screen. Each option you pick may cost an Essence from your starting bag
## (the fight gets harder) and may have an effect. There's no going back up the tree, and Engage! is always there.
##
## A node: {id, say (your line; "*...*" is an action), cost ("F" / "W" / "A" / ""), reply (the boss's line), note
## (narration after the reply), show (an artifact id to show, hover to read), effects: [...], options: [nodes]}.
## Effects: "artifact:<id>" (you get that artifact), "engage" (the fight starts).
## An option whose whole branch you've explored (in any run) gets a green tick: SaveManager setting "talk_seen".

## boss id -> its tree: {name, who (the option id that reveals its name), opening (narration), options: [nodes]}.
## (Empty for now: the boss conversations are being rewritten from scratch. A boss without a tree has no talk.)
const TREES := {}


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
