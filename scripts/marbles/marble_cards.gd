class_name MarbleCards
extends RefCounted
## The Marbles mode (2026-11-21): the user's new cards (docs/new_cards.xlsx -> data/HP_spell_new.json). Each card: its
## pattern (marbles, order counts; "F" Fire, "W" Water, "A" Wind), and its numbers at each level (0 base, 1 and 2 the
## two upgrades: finding the card again in a run). What the numbers do is coded in MarblesFight._effect.
##
## Keys of a level: d damage, hits, burn, shield, heal, weak, vuln, expose, stun, power, dodge, thorns, self (self
## damage), sburn (self Burn), svuln (self Vulnerable), next (marbles next turn), x / y (card-specific numbers), plus
## rep (Repeatable), dur (Durability per fight), cd (cooldown turns), at (charges to fire), all (every enemy).
## Card flags: t (needs a target), power (a Power: once cast, it works for the rest of the fight).

const PATH := "res://data/HP_spell_new.json"
const START := ["spark", "splash", "paper_cut"]  # (the user's starting cards, one 1-marble card of each colour: 2026-11-23, Paper Cut for Tail Wind)
const MAX_BACKPACK := 5
const INF := 99

## id -> {p: pattern, n: name, t, power, L: [level 0, level 1, level 2]}
const C := {
	# ---- list 1 (one per pattern)
	"flicker": {"p": "F", "n": "Flicker", "t": true, "L": [{"burn": 1, "rep": 2}, {"burn": 1, "rep": 4}, {"burn": 1, "rep": INF}]},
	"drop": {"p": "W", "n": "Drop", "L": [{"heal": 1, "rep": 2}, {"heal": 1, "rep": 3}, {"heal": 1, "rep": 5}]},
	"sharp_wind": {"p": "A", "n": "Sharp Wind", "t": true, "L": [{"expose": 1, "rep": 2}, {"expose": 1, "rep": 3}, {"expose": 1, "rep": 5}]},
	"spark": {"p": "F", "n": "Spark", "t": true, "L": [{"d": 3, "rep": 2}, {"d": 5, "rep": 2}, {"d": 7, "rep": 2}]},
	"steam_gun": {"p": "FW", "n": "Steam Gun", "t": true, "L": [{"x": 1}, {"x": 3}, {"x": 3}]},
	"firelance": {"p": "FA", "n": "Firelance", "t": true, "L": [{"burn": 3}, {"burn": 5}, {"burn": 7}]},
	"smoke_screen": {"p": "WF", "n": "Smoke Screen", "t": true, "L": [{"shield": 1, "weak": 1}, {"shield": 3, "weak": 1}, {"shield": 3, "weak": 3}]},
	"splash": {"p": "W", "n": "Splash", "L": [{"shield": 2, "rep": 2}, {"shield": 3, "rep": 2}, {"shield": 4, "rep": 2}]},
	"wave": {"p": "WA", "n": "Wave", "L": [{"x": 1}, {"x": 2}, {"x": 3}]},
	"heat_wave": {"p": "AF", "n": "Heat Wave", "L": [{"burn": 2, "all": true}, {"burn": 4, "all": true}, {"burn": 6, "all": true}]},
	"sea_sickness": {"p": "AW", "n": "Sea Sickness", "L": [{"weak": 1, "all": true}, {"weak": 2, "all": true}, {"weak": 3, "all": true}]},
	"paper_cut": {"p": "A", "n": "Paper Cut", "t": true, "L": [{"d": 1, "expose": 1, "rep": 2}, {"d": 2, "expose": 1, "rep": 2}, {"d": 2, "expose": 2, "rep": 2}]},
	"tail_wind": {"p": "AA", "n": "Tail Wind", "L": [{"next": 1, "rep": 2}, {"next": 2, "rep": 2}, {"next": 3, "rep": 2}]},
	"laser_beam": {"p": "FFF", "n": "Laser Beam", "t": true, "L": [{"d": 10, "self": 3}, {"d": 15, "self": 3}, {"d": 20, "self": 3}]},
	"steam_engine": {"p": "FFW", "n": "Steam Engine", "L": [{"x": 1, "cd": 1}, {"x": 1}, {"x": 2}]},
	"fire_storm": {"p": "FFA", "n": "Fire Storm", "t": true, "L": [{"x": 2}, {"x": 3}, {"x": 5}]},
	"geyser": {"p": "FWF", "n": "Geyser", "L": [{"d": 20, "at": 3}, {"d": 30, "at": 3}, {"d": 30, "at": 2}]},
	"hot_spring": {"p": "FWW", "n": "Hot Spring", "L": [{"heal": 3}, {"heal": 5}, {"heal": 7}]},
	"elemental_core": {"p": "FWA", "n": "Elemental Core", "t": true, "L": [{"d": 2, "shield": 2, "heal": 1}, {"d": 4, "shield": 4, "heal": 2}, {"d": 8, "shield": 8, "heal": 4}]},
	"pressure_cooker": {"p": "FAF", "n": "Pressure Cooker", "t": true, "L": [{"d": 3}, {"d": 6}, {"d": 9}]},
	"chosen_one": {"p": "FAW", "n": "Chosen One", "t": true, "L": [{"d": 3, "x": 3}, {"d": 3, "x": 5}, {"d": 3, "x": 10}]},
	"updraft": {"p": "FAA", "n": "Updraft", "L": [{"shield": 2, "next": 1}, {"shield": 4, "next": 1}, {"shield": 2, "next": 2}]},
	"alcohol": {"p": "WFF", "n": "Alcohol", "L": [{"power": 1, "sburn": 3}, {"power": 1, "sburn": 2}, {"power": 1}]},
	"cyclone": {"p": "WFW", "n": "Cyclone", "t": true, "L": [{"x": 2}, {"x": 3}, {"x": 4}]},
	"heat_armor": {"p": "WFA", "n": "Heat Armor", "L": [{"thorns": 2}, {"thorns": 3}, {"thorns": 4}]},
	"water_gun": {"p": "WWF", "n": "Water Gun", "t": true, "L": [{"x": 2}, {"x": 3}, {"x": 4}]},  # (2026-11-22: x damage, +x per card with Water cast before it this turn)
	"ocean": {"p": "WWW", "n": "Ocean", "L": [{"shield": 5}, {"shield": 7}, {"shield": 9}]},
	"rain": {"p": "WWA", "n": "Rain", "L": [{"shield": 2}, {"shield": 4}, {"shield": 6}]},
	"set_fire_to_the_rain": {"p": "WAF", "n": "Set Fire to the Rain", "L": [{"x": 1}, {"x": 2}, {"x": 3}]},
	"mist": {"p": "WAW", "n": "Mist", "L": [{"weak": 1, "shield": 2, "all": true}, {"weak": 1, "vuln": 1, "shield": 2, "all": true}, {"weak": 2, "vuln": 2, "shield": 2, "all": true}]},
	"hail": {"p": "WAA", "n": "Hail", "t": true, "L": [{"d": 3}, {"d": 5}, {"d": 7}]},
	"forest_fire": {"p": "AFF", "n": "Forest Fire", "t": true, "L": [{"burn": 1}, {"burn": 2}, {"burn": 3}]},
	"circle_of_life": {"p": "AFW", "n": "Circle of Life", "t": true, "L": [{"d": 10, "dur": 1}, {"d": 10, "dur": 3}, {"d": 10}]},
	"backdraft": {"p": "AFA", "n": "Backdraft", "t": true, "L": [{"x": 2, "cd": 2}, {"x": 2, "cd": 1}, {"x": 2}]},
	"heed_my_call": {"p": "AWF", "n": "Heed My Call", "power": true, "L": [{"x": 1}, {"x": 2}, {"x": 4}]},
	"stream": {"p": "AWW", "n": "Stream", "t": true, "L": [{"x": 1, "dur": 3}, {"x": 2, "dur": 3}, {"x": 3, "dur": 3}]},  # (Durability 3, the user 2026-11-22)
	"cold_feet": {"p": "AWA", "n": "Cold Feet", "t": true, "L": [{"stun": 1, "dur": 1, "svuln": 2}, {"stun": 1, "dur": 1, "svuln": 1}, {"stun": 1, "dur": 2}]},
	"snuffing_the_candle": {"p": "AAF", "n": "Snuffing the Candle", "t": true, "L": [{"d": 2, "x": 8}, {"d": 2, "x": 12}, {"d": 2, "x": 16}]},
	"refreshing_wind": {"p": "AAW", "n": "Refreshing Wind", "L": [{"x": 1, "dur": 1}, {"x": 2, "dur": 1}, {"x": 2, "dur": 2}]},
	"thousand_cuts": {"p": "AAA", "n": "Thousand Cuts", "t": true, "L": [{"d": 1, "hits": 4}, {"d": 1, "hits": 6}, {"d": 1, "hits": 8}]},
	"burn_them_all": {"p": "FFFF", "n": "Burn Them All", "L": [{"burn": 5, "dur": 1, "all": true}, {"burn": 7, "dur": 1, "all": true}, {"burn": 10, "dur": 1, "all": true}]},
	"primitive_engine": {"p": "FFFW", "n": "Primitive Engine", "L": [{"x": 1, "cd": 2}, {"x": 1, "cd": 1}, {"x": 1}]},
	"all_out": {"p": "FFFA", "n": "All-Out", "power": true, "L": [{"x": 30}, {"x": 40}, {"x": 60}]},
	"stick_and_carrot": {"p": "FFWW", "n": "Stick and Carrot", "t": true, "L": [{"d": 0}, {"d": 3}, {"d": 5}]},
	"adams_awakening": {"p": "FFAW", "n": "Adam's Awakening", "power": true, "L": [{}, {"burn": 1}, {"burn": 1, "power": 1}]},
	"flame_of_vengeance": {"p": "FWFW", "n": "Flame of Vengeance", "power": true, "L": [{"x": 5}, {"x": 4}, {"x": 3}]},
	"desperate_drop": {"p": "WFFF", "n": "Desperate Drop", "L": [{"burn": 3, "all": true}, {"burn": 5, "all": true}, {"burn": 7, "all": true}]},
	"fervor_of_the_first_apostle": {"p": "WFFW", "n": "Fervor of the First Apostle", "power": true, "L": [{}, {"thorns": 1}, {"thorns": 2}]},
	"implosion": {"p": "WFFA", "n": "Implosion", "t": true, "L": [{"x": 1}, {"x": 2}, {"x": 3}]},
	"gaze_of_the_princess": {"p": "WFWF", "n": "Gaze of the Princess", "t": true, "L": [{"stun": 1, "dur": 2}, {"stun": 1, "dur": 3}, {"stun": 1, "dur": 4}]},
	"carrot_and_stick": {"p": "WWFF", "n": "Carrot and Stick", "L": [{"shield": 0}, {"shield": 3}, {"shield": 7}]},
	"ludwigs_passion": {"p": "AFAF", "n": "Ludwig's Passion", "power": true, "L": [{"x": 30}, {"x": 50}, {"x": 75}]},
	"thunderstorm": {"p": "AWWA", "n": "Thunderstorm", "power": true, "L": [{"x": 1}, {"x": 2}, {"x": 3}]},
	"stoke_the_fire": {"p": "AAFF", "n": "Stoke the Fire", "t": true, "L": [{"x": 2, "dur": 1}, {"x": 3, "dur": 1}, {"x": 3, "dur": 2}]},
	"curse_of_the_night": {"p": "AAAW", "n": "Curse of the Night", "power": true, "L": [{}, {}, {}]},
	"aoles_last_wish": {"p": "AAAA", "n": "Aole's Last Wish", "power": true, "L": [{"next": 2}, {"next": 2}, {"next": 2}]},
	# ---- list 2 (patterns may repeat)
	"adams_finger": {"p": "F", "n": "Adam's Finger", "t": true, "power": true, "L": [{"burn": 1}, {"burn": 2}, {"burn": 3}]},
	"glass_half_full": {"p": "W", "n": "Glass Half Full", "t": true, "L": [{"d": 5, "self": 5}, {"d": 15, "self": 7}, {"d": 20, "self": 10}]},
	"air": {"p": "A", "n": "Air", "L": [{"x": 1, "dur": 2}, {"x": 1, "dur": 3}, {"x": 1, "dur": 5}]},
	"adams_fist": {"p": "FF", "n": "Adam's Fist", "t": true, "L": [{"burn": 1, "x": 2}, {"burn": 1, "x": 3}, {"burn": 1, "x": 4}]},
	"sadistic_nature": {"p": "FW", "n": "Sadistic Nature", "t": true, "L": [{"vuln": 1}, {"vuln": 2}, {"vuln": 2, "all": true}]},
	"warm_up": {"p": "FA", "n": "Warm Up", "t": true, "L": [{"x": 5}, {"x": 10}, {"x": 15}]},
	"elizes_hesitation": {"p": "WF", "n": "Elize's Hesitation", "L": [{"stun": 1, "at": 3, "dur": 3}, {"stun": 1, "at": 3, "dur": 6}, {"stun": 1, "at": 2, "dur": 6}]},
	"full_glass": {"p": "WW", "n": "Full Glass", "t": true, "L": [{"d": 5, "self": 1}, {"d": 7, "self": 2}, {"d": 10, "self": 3}]},
	"nilas_quickstep": {"p": "WA", "n": "Nila's Quickstep", "L": [{"dodge": 1, "power": 1, "dur": 1}, {"dodge": 1, "power": 2, "dur": 1}, {"dodge": 2, "power": 2, "dur": 2}]},
	"energize": {"p": "AF", "n": "Energize", "L": [{"x": 1}, {"x": 2}, {"x": 2, "y": 1}]},
	"freeze": {"p": "AW", "n": "Freeze!", "L": [{"stun": 1, "dur": 1, "y": 1}, {"stun": 1, "dur": 2, "y": 1}, {"stun": 1, "dur": 2}]},
	"aoles_magic": {"p": "AA", "n": "Aole's Magic", "L": [{"x": 1}, {"x": 1}, {"x": 1}]},
	"rain_of_pain": {"p": "FFF", "n": "Rain of Pain", "t": true, "L": [{"d": 1, "hits": 2, "x": 1}, {"d": 1, "hits": 2, "x": 2}, {"d": 1, "hits": 2, "x": 3}]},
	"pyrophiliac": {"p": "FFW", "n": "Pyrophiliac", "L": [{"heal": 1, "x": 1}, {"heal": 1, "x": 2}, {"heal": 1, "x": 3}]},
	"sun_burn": {"p": "FFA", "n": "Sun Burn", "t": true, "L": [{"expose": 2}, {"expose": 3}, {"expose": 3, "all": true}]},
	"might_of_the_first_apostle": {"p": "FWF", "n": "Might of the First Apostle", "t": true, "L": [{"burn": 3, "power": 1}, {"burn": 4, "power": 1}, {"burn": 5, "power": 1}]},
	"hot_blood": {"p": "FWW", "n": "Hot Blood", "power": true, "L": [{"x": 20}, {"x": 15}, {"x": 10}]},
	"glass_cannon": {"p": "FWA", "n": "Glass Cannon", "t": true, "L": [{"x": 3, "dur": 1}, {"x": 5, "dur": 1}, {"x": 5, "dur": 2}]},
	"ludwigs_inspiration": {"p": "FAF", "n": "Ludwig's Inspiration", "L": [{"x": 2, "dur": 1}, {"x": 4, "dur": 1}, {"x": 4, "dur": 2}]},
	"alchemy": {"p": "FAW", "n": "Alchemy", "L": [{"x": 1}, {"x": 2}, {"x": 3}]},
	"toxic_wind": {"p": "FAA", "n": "Toxic Wind", "L": [{"vuln": 1, "weak": 1, "expose": 1, "all": true, "cd": 1}, {"vuln": 1, "weak": 1, "expose": 1, "all": true}, {"vuln": 1, "weak": 1, "expose": 1, "all": true}]},
	"over_exertion": {"p": "WFF", "n": "Over Exertion", "L": [{"x": 3}, {"x": 2}, {"x": 1}]},
	"a_daughters_secret": {"p": "WFW", "n": "A Daughter's Secret", "t": true, "L": [{"stun": 1, "x": 20}, {"stun": 1, "x": 15}, {"stun": 1, "x": 10}]},
	"random_things_go": {"p": "WFA", "n": "Random Things Go!", "power": true, "L": [{"x": 1}, {"x": 2}, {"x": 3}]},
	"borrowed_warmth": {"p": "WWF", "n": "Borrowed Warmth", "t": true, "L": [{"x": 50, "dur": 1}, {"x": 100, "dur": 1}, {"x": 100, "dur": 2}]},
	"endless_well": {"p": "WWW", "n": "Endless Well", "power": true, "L": [{}, {}, {}]},
	"iron_maiden": {"p": "WWA", "n": "Iron Maiden", "t": true, "L": [{"thorns": 1, "x": 3}, {"thorns": 1, "x": 4}, {"thorns": 2, "x": 4}]},
	"embracing_the_pain": {"p": "WAF", "n": "Embracing the Pain", "L": [{"self": 2, "shield": 6}, {"self": 2, "shield": 9}, {"self": 2, "shield": 12}]},
	"nilas_blades": {"p": "WAW", "n": "Nila's Blades", "t": true, "L": [{"d": 5, "x": 1}, {"d": 5, "x": 2}, {"d": 5, "x": 3}]},
	"knivels_innocence": {"p": "WAA", "n": "Knivel's Innocence", "L": [{"x": 1, "dur": 3}, {"x": 2, "dur": 3}, {"x": 3, "dur": 3}]},
	"flagellum_of_the_first_apostle": {"p": "AFF", "n": "Flagellum of the First Apostle", "power": true, "L": [{}, {"thorns": 1}, {"thorns": 1, "power": 1}]},
	"a_brothers_cluelessness": {"p": "AFW", "n": "A Brother's Cluelessness", "L": [{"shield": 1, "dur": 2, "x": 10}, {"shield": 1, "dur": 2, "x": 10}, {"shield": 1, "dur": 2, "x": 10}]},
	"heat_center": {"p": "AFA", "n": "Heat Center", "t": true, "L": [{"dur": 1}, {"dur": 2}, {"dur": 3}]},
	"moth_to_flame": {"p": "AWF", "n": "Moth to Flame", "t": true, "L": [{"dur": 1}, {"burn": 1, "dur": 1}, {"burn": 1, "dur": 2}]},
	"still_lake": {"p": "AWW", "n": "Still Lake", "L": [{"x": 2}, {"x": 4}, {"x": 6}]},
	"aoles_grace": {"p": "AWA", "n": "Aole's Grace", "L": [{"x": 2}, {"x": 3}, {"x": 4}]},
	"focus_fire": {"p": "AAF", "n": "Focus Fire", "t": true, "L": [{"d": 1, "expose": 1, "cd": 1}, {"d": 1, "expose": 1}, {"d": 2, "expose": 1}]},
	"bite": {"p": "AAW", "n": "Bite", "t": true, "L": [{"d": 4, "heal": 2}, {"d": 6, "heal": 4}, {"d": 8, "heal": 6}]},
	"gone_like_the_wind": {"p": "AAA", "n": "Gone Like the Wind", "L": [{"dodge": 1, "dur": 1}, {"dodge": 2, "dur": 1}, {"dodge": 2, "dur": 2}]},
	"adams_resolve": {"p": "F", "n": "Adam's Resolve", "power": true, "L": [{"power": 1}, {"power": 1, "heal": 1}, {"power": 2, "heal": 2}]},
	"whim_of_the_pianist": {"p": "FA", "n": "Whim of the Pianist", "t": true, "L": [{"x": 4}, {"x": 5}, {"x": 6}]},
	"a_brothers_cleverness": {"p": "AFW", "n": "A Brother's Cleverness", "L": [{"dodge": 2, "dur": 2}, {"dodge": 2, "dur": 3}, {"dodge": 2, "dur": 4}]},
}

## Cards that apply Burn (Air makes their Burn bigger).
const BURN_CARDS := ["flicker", "firelance", "heat_wave", "fire_storm", "forest_fire", "burn_them_all", "desperate_drop",
	"adams_finger", "adams_fist", "might_of_the_first_apostle", "moth_to_flame"]
## Cards that deal damage (Chosen One: "the only damaging spell you have").
const DAMAGE_CARDS := ["spark", "paper_cut", "steam_gun", "wave", "laser_beam", "geyser", "elemental_core", "pressure_cooker", "chosen_one", "cyclone",
	"water_gun", "hail", "circle_of_life", "backdraft", "stream", "snuffing_the_candle", "thousand_cuts", "stick_and_carrot",
	"implosion", "thunderstorm", "glass_half_full", "adams_fist", "warm_up", "full_glass", "rain_of_pain", "glass_cannon",
	"iron_maiden", "nilas_blades", "focus_fire", "bite", "whim_of_the_pianist"]

static var _texts := {}
static var _rarity := {}


## A card's rarity: "common", "rare" or "legendary" (the Notes column of the user's sheet; Common when it says nothing).
## Every Power card is at least Rare (the user, 2026-11-22).
static func rarity(id: String) -> String:
	if _texts.is_empty():
		_load_texts()
	var r := String(_rarity.get(id, "common"))
	if r == "common" and bool(C.get(id, {}).get("power", false)):
		return "rare"
	return r


## A card as the fight and the screen use it: {id, name, pattern, level, power, t, p (its numbers), text}. `perm`: the
## run's growing numbers (card id -> n): a card's words show their current value ({x}).
static func card(id: String, level := 0, perm := {}) -> Dictionary:
	var c: Dictionary = C.get(id, {})
	if c.is_empty():
		return {}
	var lv: Array = c.L
	var k := clampi(level, 0, lv.size() - 1)
	return {"id": id, "name": String(c.n), "pattern": String(c.p), "level": k, "power": bool(c.get("power", false)),
		"t": bool(c.get("t", false)), "p": (lv[k] as Dictionary).duplicate(), "text": fill(text(id, k), id, perm), "rarity": rarity(id)}


## The words with the card's Durability as it is now ("Durability 3." -> "Durability 2." once worn; a card that had none
## and was made fragile gets it added). n < 0: none.
static func with_durability(words: String, n: int) -> String:
	if n < 0:
		return words
	var re := RegEx.create_from_string("Durability \\d+")
	if re.search(words) != null:
		return re.sub(words, "Durability %d" % n)
	return words.strip_edges() + " Durability %d." % n


## The words' {x}: the card's number as it is now (Knivel's Innocence: its Shield and heal, which grow for the run).
static func fill(words: String, id: String, perm: Dictionary) -> String:
	if not words.contains("{x}"):
		return words
	var x := int(perm.get(id, 0)) + 1 if id == "knivels_innocence" else int(perm.get(id, 0))
	return words.replace("{x}", str(x))


static func has(id: String) -> bool:
	return C.has(id)


## A card as the main game's spell list holds it (SpellDB.from_marbles; SpellCard draws it: its words are `desc`).
static func as_spell(id: String, level := 0, perm := {}) -> Dictionary:
	var c := card(id, level, perm)
	var p: Dictionary = c.get("p", {})
	var kind := "utility"
	if id in DAMAGE_CARDS or p.has("d") or p.has("burn"):
		kind = "damage"
	elif p.has("shield") or p.has("heal") or p.has("thorns") or p.has("dodge"):
		kind = "defense"
	var rar := String(c.get("rarity", "common"))
	if id in ["a_brothers_cleverness", "bite"]:
		rar = "unique"  # (never offered: Cluelessness becomes it; Curse of the Night makes Bites)
	return {"id": id, "name": String(c.name) + ("+".repeat(int(c.level))), "pattern": String(c.pattern), "kind": kind,
		"rarity": rar, "power": bool(c.power), "upgraded": int(c.level) > 0, "level": int(c.level), "desc": String(c.text),
		"effects": [], "marble": true, "targeted": bool(c.t), "size": String(c.pattern).length(), "starter": id in START}


## The card's words at a level, as the user wrote them (data/HP_spell_new.json).
static func text(id: String, level := 0) -> String:
	if _texts.is_empty():
		_load_texts()
	var t: Array = _texts.get(id, [])
	if t.is_empty():
		return ""
	return String(t[clampi(level, 0, t.size() - 1)])


static func _load_texts() -> void:
	var data = JSON.parse_string(FileAccess.get_file_as_string(PATH))
	if not (data is Dictionary):
		return
	for s in (data.get("spells", []) as Array) + (data.get("more_cards", []) as Array):
		var nm := String(s.get("name", ""))
		if nm == "":
			continue
		var base := String(s.get("text", ""))
		var ups: Array = s.get("upgrades", [])
		var lv := [base]
		for u in ups:
			lv.append(String(u))
		_texts[id_of(nm)] = lv
		var note := String(s.get("notes", "")).to_lower()
		if note.contains("legend") or note.contains("lengend"):
			_rarity[id_of(nm)] = "legendary"
		elif note.begins_with("rare"):
			_rarity[id_of(nm)] = "rare"


## The id of a card from the name the user gave it (typos fixed: the ids are the right spellings).
static func id_of(name: String) -> String:
	var fixed := {"lazer beam": "laser_beam", "flame of vengance": "flame_of_vengeance", "fevor of the first apostle": "fervor_of_the_first_apostle",
		"lugwid's inspiration": "ludwigs_inspiration", "knivel's innocent": "knivels_innocence", "all-out": "all_out"}
	var low := name.strip_edges().to_lower()
	if fixed.has(low):
		return String(fixed[low])
	var out := ""
	for ch in low.replace("'", ""):
		out += ch if (ch >= "a" and ch <= "z") or (ch >= "0" and ch <= "9") else "_"
	while out.contains("__"):
		out = out.replace("__", "_")
	return out.strip_edges(true, true).trim_prefix("_").trim_suffix("_")
