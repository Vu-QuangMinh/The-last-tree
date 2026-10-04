class_name Keywords
extends RefCounted
## Colours meaningful words and numbers in rules text (BBCode), and explains them in tooltips.

## keyword -> [colour on dark UI, colour on parchment, explanation]
const K := {
	"annihilate": [Color(1.0, 0.35, 0.5), Color(0.7, 0.05, 0.25), "Annihilate: choose Fire, Water or Air. Every Essence of that kind is removed from the enemies, armoured or not."],
	"conjure": [Color(0.75, 0.9, 1.0), Color(0.15, 0.4, 0.65), "Conjure N: the spell splits into N random spells, right away, in its place. They're Ephemeral. When they're all gone, it comes back."],
	"ephemeral": [Color(0.85, 0.95, 1.0), Color(0.3, 0.45, 0.65), "Ephemeral: a conjured spell. It vanishes once cast, or at the end of your next turn if you don't cast it."],
	"anti-spell": [Color(0.95, 0.5, 0.85), Color(0.55, 0.1, 0.45), "Anti-spell: the opposite of a spell. Every time you chant, it comes alive and is cast like any other spell, UNLESS the chant contains its pattern: that breaks it for the turn. (Pass without chanting and it still goes off at the end of your turn.)"],
	"fleeting": [Color(0.8, 0.85, 1.0), Color(0.3, 0.35, 0.6), "Fleeting: once you cast it, the spell is gone for the rest of the fight."],
	"curse": [Color(1.0, 0.45, 0.4), Color(0.7, 0.1, 0.08), "Curse: the price of a cursed artifact. It lasts as long as you keep the artifact."],
	"remove": [Color(1.0, 0.45, 0.4), Color(0.72, 0.12, 0.08), "Remove: knock Essence off an enemy, one per point. When its Essence is all gone, it's defeated."],
	"leftmost": [Color(0.45, 0.88, 0.85), Color(0.0, 0.45, 0.45), "Leftmost: the left end of the enemy's Essence row. \"The 3 leftmost Essence\" are the 3 at its left end."],
	"rightmost": [Color(0.45, 0.88, 0.85), Color(0.0, 0.45, 0.45), "Rightmost: the right end of the enemy's Essence row. \"The 3 rightmost Essence\" are the 3 at its right end."],
	"damage": [Color(1.0, 0.45, 0.4), Color(0.72, 0.12, 0.08), "Damage: against an enemy, each point knocks off one of its Essence. Against you, it lowers your HP."],
	"essence": [Color(0.95, 0.75, 1.0), Color(0.5, 0.2, 0.6), "Essence: Fire, Water and Air. Yours sit in your bag until you chant them; an enemy's life is a row of Essence: knock it all off and it's defeated. (Your own life is your HP.)"],
	"release": [Color(1.0, 0.85, 0.45), Color(0.6, 0.4, 0.0), "Release: once your spells are cast, the chant flies at the enemies Essence by Essence, left to right; each enemy loses the longest start of its Essence found in the chant."],
	"released": [Color(1.0, 0.85, 0.45), Color(0.6, 0.4, 0.0), "Release: once your spells are cast, the chant flies at the enemies Essence by Essence, left to right; each enemy loses the longest start of its Essence found in the chant."],
	"steal": [Color(0.45, 0.85, 1.0), Color(0.05, 0.4, 0.65), "Steal: take Essence off an enemy and put it in your bag, ready for a later chant. When an enemy Steals, it takes Essence from your bag and adds it to its own."],
	"stolen": [Color(0.45, 0.85, 1.0), Color(0.05, 0.4, 0.65), "Steal: take Essence off an enemy and put it in your bag, ready for a later chant. When an enemy Steals, it takes Essence from your bag and adds it to its own."],
	"fused": [Color(1.0, 0.7, 0.9), Color(0.6, 0.15, 0.45), "Fused: forged from two spells at a campfire. It does everything both did, and can't be fused again."],
	"fuse": [Color(1.0, 0.7, 0.9), Color(0.6, 0.15, 0.45), "Fuse: at a campfire, melt two spells into one that does everything both did. Its pattern is the first spell's pattern followed by the whole of the second's."],
	"targeted": [Color(1.0, 0.75, 0.3), Color(0.7, 0.35, 0.0), "Targeted: you pick which Essence to hit, anywhere in the enemy's row (click it, or Tab + Enter)."],
	"infuse": [Color(0.95, 0.85, 0.5), Color(0.55, 0.4, 0.0), "Infuse: put the Essence anywhere you like in this turn's chant. It counts at once, so it can wake more spells."],
	"rearrange": [Color(0.95, 0.85, 0.5), Color(0.55, 0.4, 0.0), "Rearrange N: grab an Essence of this turn's chant and drag it to another spot (N times). It counts at once, so it can wake more spells."],
	"duplicate": [Color(0.95, 0.85, 0.5), Color(0.55, 0.4, 0.0), "Duplicate N: pick an Essence of this turn's chant; N copies of it appear right beside it. They count at once, so they can wake more spells."],
	"execute": [Color(1.0, 0.35, 0.35), Color(0.65, 0.05, 0.05), "Execute: destroy the enemy outright if its Essence is low enough (not bosses)."],
	"burn": [Color(1.0, 0.55, 0.2), Color(0.78, 0.3, 0.0), "Burn N: at the start of the enemy's turn, before it acts, it loses its N leftmost Essence (armour doesn't help), then Burn drops by 1. It stays until it runs out. If it burns away completely, it's defeated before it can attack."],
	"poison": [Color(0.55, 0.9, 0.3), Color(0.25, 0.5, 0.05), "Poison N: at the start of the enemy's turn, it loses its N rightmost Essence (armour doesn't help), then Poison drops by 1. It stays until it runs out."],
	"shield": [Color(0.55, 0.8, 1.0), Color(0.1, 0.35, 0.7), "Shield: blocks that much attack damage until your next turn."],
	"aegis": [Color(1.0, 0.9, 0.5), Color(0.6, 0.45, 0.0), "Aegis: blocks one whole enemy hit, whatever its size."],
	"thorns": [Color(0.75, 0.85, 0.4), Color(0.35, 0.45, 0.05), "Thorns: when an enemy hits you, it loses that many of its rightmost Essence."],
	"heal": [Color(0.45, 1.0, 0.55), Color(0.1, 0.5, 0.15), "Heal: restore HP, up to your maximum."],
	"weaken": [Color(0.75, 0.65, 0.95), Color(0.4, 0.25, 0.6), "Weaken N: for N turns, the enemy deals 50% less damage."],
	"weakened": [Color(0.75, 0.65, 0.95), Color(0.4, 0.25, 0.6), "Weaken N: for N turns, the enemy deals 50% less damage."],
	"freeze": [Color(0.6, 0.9, 1.0), Color(0.1, 0.45, 0.6), "Freeze N: the enemy skips its actions for N turns. Frozen Essence of yours can't be used this turn. Bosses can't be frozen."],
	"frozen": [Color(0.6, 0.9, 1.0), Color(0.1, 0.45, 0.6), "Freeze N: the enemy skips its actions for N turns. Frozen Essence of yours can't be used this turn. Bosses can't be frozen."],
	"expose": [Color(1.0, 0.45, 0.55), Color(0.7, 0.1, 0.25), "Expose N: paint N enemy Essence of your choice, on any enemies. Each becomes an Any Essence for the rest of the fight: any Essence in your chant hits it."],
	"exposed": [Color(1.0, 0.45, 0.55), Color(0.7, 0.1, 0.25), "Expose N: paint N enemy Essence of your choice, on any enemies. Each becomes an Any Essence for the rest of the fight: any Essence in your chant hits it."],
	"ethereal": [Color(0.8, 0.8, 1.0), Color(0.35, 0.35, 0.65), "Ethereal: takes no damage from attacks this turn. An Ethereal enemy can't be touched by your chant."],
	"phased": [Color(0.8, 0.8, 1.0), Color(0.35, 0.35, 0.65), "Phased: your spells remove double from it this turn."],
	"armour": [Color(0.8, 0.82, 0.9), Color(0.35, 0.35, 0.42), "Armour: an armoured Essence still counts for matching, but isn't removed that turn."],
	"armoured": [Color(0.8, 0.82, 0.9), Color(0.35, 0.35, 0.42), "Armour: an armoured Essence still counts for matching, but isn't removed that turn."],
	"amplify": [Color(1.0, 0.7, 0.4), Color(0.7, 0.35, 0.05), "Amplify N: when the chant is Released this turn, every enemy it hits also loses its N rightmost Essence."],
	"echo": [Color(0.9, 0.75, 1.0), Color(0.5, 0.3, 0.7), "Echo: this turn your chant is Released a second time."],
	"overload": [Color(1.0, 0.5, 0.5), Color(0.65, 0.15, 0.15), "Overload N: you get N fewer Essence next turn."],
	"conjured": [Color(0.85, 0.95, 1.0), Color(0.3, 0.45, 0.6), "Conjured: a temporary Essence. It fades at the end of the turn if you don't use it."],
	"power": [Color(1.0, 0.8, 0.4), Color(0.65, 0.4, 0.0), "Power: fires once, then leaves your active row; its effect lasts the whole fight."],
	"bleed": [Color(1.0, 0.35, 0.4), Color(0.65, 0.05, 0.1), "Bleed: at the start of your turn you lose that much HP, then Bleed goes down by 1."],
	"confuse": [Color(0.85, 0.55, 1.0), Color(0.45, 0.15, 0.6), "Confused: your next chant is read backwards, and there's no preview."],
	"confused": [Color(0.85, 0.55, 1.0), Color(0.45, 0.15, 0.6), "Confused: your next chant is read backwards, and there's no preview."],
	"frail": [Color(1.0, 0.5, 0.6), Color(0.65, 0.1, 0.25), "Frail: you take 25% more attack damage."],
	"blind": [Color(0.7, 0.7, 0.75), Color(0.3, 0.3, 0.35), "Blind: some enemy Essence show as ?. They still match normally."],
	"silence": [Color(0.85, 0.55, 1.0), Color(0.45, 0.15, 0.6), "Silenced: that spell can't fire for a few turns."],
	"lock": [Color(1.0, 0.8, 0.4), Color(0.6, 0.4, 0.0), "Lock: the spell can't fire until your chant contains the lock's symbols, unbroken."],
	"redirect": [Color(0.55, 1.0, 0.8), Color(0.05, 0.5, 0.35), "Redirect: the enemy's attack hits another enemy of your choice (or itself); anything aimed at you fizzles."],
	"cleanse": [Color(0.6, 1.0, 0.9), Color(0.05, 0.5, 0.45), "Cleanse: remove your debuffs."],
	"cure": [Color(0.6, 1.0, 0.9), Color(0.05, 0.5, 0.45), "Cure: remove that debuff from you."],
	"mend": [Color(0.45, 1.0, 0.55), Color(0.1, 0.5, 0.15), "Mend: the enemy regrows Essence at the right end of its row."],
	"sealed": [Color(0.85, 0.55, 1.0), Color(0.45, 0.15, 0.6), "Sealed: an upgrade. A wax seal covers one Essence of the spell's pattern: that Essence isn't needed any more. A spell sealed down to nothing wakes on every chant."],
	"bottle": [Color(0.6, 0.95, 1.0), Color(0.1, 0.45, 0.6), "Bottle: a one-use item for the fight you're in. Click it on your turn to drink it. You carry up to 3."],
	"purge": [Color(1.0, 0.6, 0.4), Color(0.7, 0.25, 0.05), "Purge: remove up to that many Essence of one type from an enemy."],
	"fire": [Elements.COLORS["F"], Color(0.8, 0.25, 0.0), ""],
	"water": [Elements.COLORS["W"], Color(0.05, 0.35, 0.8), ""],
	"wind": [Elements.COLORS["A"], Color(0.05, 0.5, 0.35), ""],
	"air": [Elements.COLORS["A"], Color(0.05, 0.5, 0.35), ""],
}
## The tri-colour "?" orb in a pattern. (Not a keyword: "any Essence" in rules text means something else.)
const ANY_ESSENCE := "Any Essence: the tri-colour ? orb in a pattern. Fire, Water or Air, any one of them fits that spot."
const NUMBER_DARK := Color(1.0, 0.88, 0.4)
const NUMBER_LIGHT := Color(0.55, 0.3, 0.0)

const LETTER_KEY := {"F": "fire", "W": "water", "A": "air"}

static var _re: RegEx


static func _regex() -> RegEx:
	if _re == null:
		_re = RegEx.new()
		var words := K.keys()
		words.sort_custom(func(a, b): return a.length() > b.length())
		# keywords (any case) · element letters F / W / A standing alone (a capital A followed by a lowercase
		# word is the English "A", unless it follows another element letter, as in "F W A is") · numbers
		_re.compile("(?i)\\b(" + "|".join(words) + ")s?\\b|(?-i:\\b([FW])\\b|\\b(A)\\b(?! [a-z])|(?<=[FWA] |[FWA], |[FWA] and )(A)\\b)|[+\\-×]?\\b\\d+%?")
	return _re


## BBCode with keywords, element letters (F W A) and numbers coloured. on_parchment picks the darker palette.
## links: keywords become [url] links, so a KeywordText can show each one's explanation on hover.
static func colorize(text: String, on_parchment := false, links := false) -> String:
	var out := ""
	var last := 0
	for m in _regex().search_all(text):
		out += _escape(text.substr(last, m.get_start() - last))
		var word := m.get_string()
		var key := m.get_string(1).to_lower()
		var letter := m.get_string(2) + m.get_string(3) + m.get_string(4)
		if letter != "":
			key = LETTER_KEY[letter]
		var col: Color
		if key != "" and K.has(key):
			col = K[key][1] if on_parchment else K[key][0]
		else:
			col = NUMBER_LIGHT if on_parchment else NUMBER_DARK
		var piece := "[color=#%s][b]%s[/b][/color]" % [col.to_html(false), _escape(word)]
		if links and letter == "" and key != "" and K.has(key) and K[key][2] != "":
			piece = "[url=%s]%s[/url]" % [key, piece]
		out += piece
		last = m.get_end()
	return out + _escape(text.substr(last))


## A keyword's own tooltip: its name as the title, then what it means.
static func keyword_tip(key: String) -> String:
	if not K.has(key) or K[key][2] == "":
		return ""
	var parts: PackedStringArray = String(K[key][2]).split(":", true, 1)
	return "[b][font_size=25][color=#%s]%s[/color][/font_size][/b]\n%s" % [K[key][0].to_html(false), _escape(parts[0]), colorize(parts[1].strip_edges() if parts.size() > 1 else parts[0])]


## Explanations for the keywords that appear in the text (each once).
static func glossary(text: String) -> Array:
	var seen := {}
	var out := []
	for m in _regex().search_all(text):
		var key := m.get_string(1).to_lower()
		if key == "" or not K.has(key):
			continue
		var expl: String = K[key][2]
		if expl == "" or seen.has(expl):
			continue
		seen[expl] = true
		out.append(expl)
	return out


## A tooltip body: title, coloured rules text, then what its keywords mean.
static func tooltip(title: String, body: String, extra := "", icon := "", more_gloss := []) -> String:
	var s := "[b][font_size=25]%s%s[/font_size][/b]\n%s" % [(icon + " ") if icon != "" else "", _escape(title), colorize(body)]
	if extra != "":
		s += "\n" + extra
	var gl := glossary(body) + more_gloss
	if not gl.is_empty():
		s += "\n[color=#8c9a8c]────────────[/color]"
		for g in gl:
			var parts: PackedStringArray = g.split(":", true, 1)
			s += "\n" + colorize(parts[0]) + "[color=#b8c2b8]:" + _escape(parts[1]) + "[/color]"
	return s


## The custom tooltip control: BBCode rendered in a fixed-width rich label.
static func make_tooltip(bbcode: String) -> Control:
	var r := RichTextLabel.new()
	r.bbcode_enabled = true
	r.fit_content = true
	r.scroll_active = false
	r.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	r.custom_minimum_size = Vector2(560, 0)
	r.add_theme_font_size_override("normal_font_size", 21)
	r.add_theme_font_size_override("bold_font_size", 21)
	r.add_theme_color_override("default_color", Color(0.9, 0.92, 0.86))
	r.text = bbcode
	return r


const ICON_PATH := {"{F}": "res://assets/icons/el_fire.png", "{W}": "res://assets/icons/el_water.png", "{A}": "res://assets/icons/el_wind.png", "{?}": "res://assets/icons/el_any.png"}


## Colour the text, then swap {F} {W} {A} {?} tokens for element orb images.
static func with_icons(text: String, on_parchment := false, px := 18) -> String:
	var out := colorize(text, on_parchment)
	for tok in ICON_PATH:
		out = out.replace(tok, "[img=%dx%d]%s[/img]" % [px, px, ICON_PATH[tok]])
	return out


static func _escape(s: String) -> String:
	return s.replace("[", "[lb]")
