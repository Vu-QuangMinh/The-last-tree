class_name Keywords
extends RefCounted
## Colours meaningful words and numbers in rules text (BBCode), and explains them in tooltips.

## keyword -> [colour on dark UI, colour on parchment, explanation]
const K := {
	"annihilate": [Color(1.0, 0.35, 0.5), Color(0.7, 0.05, 0.25), "Annihilate: pick Fire, Water or Air. All of it is removed from the enemies, Armour or not."],
	"conjure": [Color(0.75, 0.9, 1.0), Color(0.15, 0.4, 0.65), "Conjure N: the spell splits into N random Ephemeral spells. When they're gone, it comes back."],
	"ephemeral": [Color(0.85, 0.95, 1.0), Color(0.3, 0.45, 0.65), "Ephemeral: gone once cast, or at the end of your next turn."],
	"anti-spell": [Color(0.95, 0.5, 0.85), Color(0.55, 0.1, 0.45), "Anti-spell: fires on every chant, unless the chant contains its pattern. Also fires when you pass."],
	"fleeting": [Color(0.8, 0.85, 1.0), Color(0.3, 0.35, 0.6), "Fleeting: once cast, gone for the fight."],
	"curse": [Color(1.0, 0.45, 0.4), Color(0.7, 0.1, 0.08), "Curse: the price of a cursed artifact, for as long as you keep it."],
	"remove": [Color(1.0, 0.45, 0.4), Color(0.72, 0.12, 0.08), "Remove: knock Essence off an enemy. No Essence left: it's defeated."],
	"leftmost": [Color(0.45, 0.88, 0.85), Color(0.0, 0.45, 0.45), "Leftmost: the left end of an enemy's row."],
	"rightmost": [Color(0.45, 0.88, 0.85), Color(0.0, 0.45, 0.45), "Rightmost: the right end of an enemy's row."],
	"damage": [Color(1.0, 0.45, 0.4), Color(0.72, 0.12, 0.08), "Damage: each point knocks 1 Essence off an enemy, or 1 HP off you."],
	"essence": [Color(0.95, 0.75, 1.0), Color(0.5, 0.2, 0.6), "Essence: Fire, Water and Air. You chant yours; an enemy's row of Essence is its life."],
	"release": [Color(1.0, 0.85, 0.45), Color(0.6, 0.4, 0.0), "Release: the chant hits every enemy, left to right. Each loses the longest start of its row found in the chant."],
	"released": [Color(1.0, 0.85, 0.45), Color(0.6, 0.4, 0.0), "Release: the chant hits every enemy, left to right. Each loses the longest start of its row found in the chant."],
	"steal": [Color(0.45, 0.85, 1.0), Color(0.05, 0.4, 0.65), "Steal: take Essence off an enemy into your bag. An enemy that Steals takes from your bag."],
	"stolen": [Color(0.45, 0.85, 1.0), Color(0.05, 0.4, 0.65), "Steal: take Essence off an enemy into your bag. An enemy that Steals takes from your bag."],
	"fused": [Color(1.0, 0.7, 0.9), Color(0.6, 0.15, 0.45), "Fused: made from two spells at a campfire. Can't be fused again."],
	"fuse": [Color(1.0, 0.7, 0.9), Color(0.6, 0.15, 0.45), "Fuse: at a campfire, melt two spells into one that does both."],
	"refund": [Color(0.7, 0.95, 0.85), Color(0.1, 0.45, 0.35), "Refund: Essence in your chant goes back to your bag after the chant."],
	"snipe": [Color(1.0, 0.4, 0.35), Color(0.7, 0.1, 0.08), "Snipe N: remove N Essence of your choice, from any enemy. Walls don't stop it."],
	"targeted": [Color(1.0, 0.75, 0.3), Color(0.7, 0.35, 0.0), "Targeted: you pick which Essence to hit."],
	"infuse": [Color(0.95, 0.85, 0.5), Color(0.55, 0.4, 0.0), "Infuse: put Essence anywhere in this turn's chant. It can wake more spells."],
	"rearrange": [Color(0.95, 0.85, 0.5), Color(0.55, 0.4, 0.0), "Rearrange N: move an Essence of this turn's chant (N times). It can wake more spells."],
	"duplicate": [Color(0.95, 0.85, 0.5), Color(0.55, 0.4, 0.0), "Duplicate N: copy an Essence of this turn's chant N times, beside it."],
	"execute": [Color(1.0, 0.35, 0.35), Color(0.65, 0.05, 0.05), "Execute: kill an enemy with that many Essence or fewer (not bosses)."],
	"burn": [Color(1.0, 0.55, 0.2), Color(0.78, 0.3, 0.0), "Burn N: at the start of its turn the enemy loses N rightmost Essence, then Burn ends."],
	"poison": [Color(0.55, 0.9, 0.3), Color(0.25, 0.5, 0.05), "Poison N: grows by 1 each enemy turn. When it reaches the enemy's Essence left, it dies."],
	"shield": [Color(0.55, 0.8, 1.0), Color(0.1, 0.35, 0.7), "Shield: blocks attack damage until your next turn."],
	"aegis": [Color(1.0, 0.9, 0.5), Color(0.6, 0.45, 0.0), "Aegis: blocks one whole hit."],
	"thorns": [Color(0.75, 0.85, 0.4), Color(0.35, 0.45, 0.05), "Thorns: an enemy that hits you loses that many rightmost Essence."],
	"heal": [Color(0.45, 1.0, 0.55), Color(0.1, 0.5, 0.15), "Heal: restore HP, up to your max."],
	"weaken": [Color(0.75, 0.65, 0.95), Color(0.4, 0.25, 0.6), "Weaken N: the enemy deals 50% less for N turns."],
	"weakened": [Color(0.75, 0.65, 0.95), Color(0.4, 0.25, 0.6), "Weaken N: the enemy deals 50% less for N turns."],
	"freeze": [Color(0.6, 0.9, 1.0), Color(0.1, 0.45, 0.6), "Freeze N: the enemy skips N turns (not bosses). Frozen Essence of yours can't be used this turn."],
	"frozen": [Color(0.6, 0.9, 1.0), Color(0.1, 0.45, 0.6), "Freeze N: the enemy skips N turns (not bosses). Frozen Essence of yours can't be used this turn."],
	"expose": [Color(1.0, 0.45, 0.55), Color(0.7, 0.1, 0.25), "Expose N: turn N enemy Essence into Any Essence: any chanted Essence hits them."],
	"exposed": [Color(1.0, 0.45, 0.55), Color(0.7, 0.1, 0.25), "Expose N: turn N enemy Essence into Any Essence: any chanted Essence hits them."],
	"ethereal": [Color(0.8, 0.8, 1.0), Color(0.35, 0.35, 0.65), "Ethereal: attacks can't touch it this turn (an Ethereal enemy: your chant can't)."],
	"phased": [Color(0.8, 0.8, 1.0), Color(0.35, 0.35, 0.65), "Phased: your spells remove double from it this turn."],
	"armour": [Color(0.8, 0.82, 0.9), Color(0.35, 0.35, 0.42), "Armour: still counts for matching, but isn't removed this turn."],
	"armoured": [Color(0.8, 0.82, 0.9), Color(0.35, 0.35, 0.42), "Armour: still counts for matching, but isn't removed this turn."],
	"amplify": [Color(1.0, 0.7, 0.4), Color(0.7, 0.35, 0.05), "Amplify N: enemies your Release hits also lose N rightmost Essence."],
	"echo": [Color(0.9, 0.75, 1.0), Color(0.5, 0.3, 0.7), "Echo: your chant is Released twice this turn."],
	"overload": [Color(1.0, 0.5, 0.5), Color(0.65, 0.15, 0.15), "Overload N: N fewer Essence next turn."],
	"conjured": [Color(0.85, 0.95, 1.0), Color(0.3, 0.45, 0.6), "Conjured: temporary Essence. It fades at the end of the turn."],
	"power": [Color(1.0, 0.8, 0.4), Color(0.65, 0.4, 0.0), "Power: cast once; lasts the whole fight."],
	"bleed": [Color(1.0, 0.35, 0.4), Color(0.65, 0.05, 0.1), "Bleed: lose that much HP at the start of your turn, then Bleed drops by 1."],
	"confuse": [Color(0.85, 0.55, 1.0), Color(0.45, 0.15, 0.6), "Confused: your next chant is read backwards, with no preview."],
	"confused": [Color(0.85, 0.55, 1.0), Color(0.45, 0.15, 0.6), "Confused: your next chant is read backwards, with no preview."],
	"vulnerable": [Color(1.0, 0.5, 0.4), Color(0.72, 0.15, 0.08), "Vulnerable N: you take 50% more damage. Drops by 1 each turn."],
	"lasting": [Color(0.6, 0.85, 1.0), Color(0.1, 0.4, 0.7), "Lasting Shield: like Shield, but it stays until it's broken."],
	"stored": [Color(0.75, 0.9, 1.0), Color(0.2, 0.4, 0.65), "Stored: a spell you didn't cast before the Release. It's still awake: cast it after your next Chant."],
	"cooldown": [Color(0.7, 0.85, 1.0), Color(0.2, 0.35, 0.6), "Cooldown N: can't be cast for N turns after you cast it."],
	"brittle": [Color(0.6, 0.8, 1.0), Color(0.15, 0.35, 0.6), "Brittle N: your Shield is 25% smaller for N turns."],
	"frail": [Color(1.0, 0.5, 0.6), Color(0.65, 0.1, 0.25), "Frail: you take 25% more damage."],
	"blind": [Color(0.7, 0.7, 0.75), Color(0.3, 0.3, 0.35), "Blind: some enemy Essence show as ?. They still match."],
	"silence": [Color(0.85, 0.55, 1.0), Color(0.45, 0.15, 0.6), "Silenced: the spell can't fire for a few turns."],
	"disarmed": [Color(1.0, 0.6, 0.5), Color(0.7, 0.2, 0.1), "Disarmed: an enemy's attacks do nothing on its next turn. You, Disarmed: your Release does nothing this turn."],
	"ignited": [Color(1.0, 0.55, 0.2), Color(0.75, 0.3, 0.0), "Ignited: casting it this turn burns you for 5 HP."],
	"lock": [Color(1.0, 0.8, 0.4), Color(0.6, 0.4, 0.0), "Lock: the spell can't fire until your chant contains the lock's symbols."],
	"redirect": [Color(0.55, 1.0, 0.8), Color(0.05, 0.5, 0.35), "Redirect: the enemy's attack hits another enemy (or itself)."],
	"cleanse": [Color(0.6, 1.0, 0.9), Color(0.05, 0.5, 0.45), "Cleanse: remove your debuffs."],
	"cure": [Color(0.6, 1.0, 0.9), Color(0.05, 0.5, 0.45), "Cure: remove that debuff."],
	"mend": [Color(0.45, 1.0, 0.55), Color(0.1, 0.5, 0.15), "Mend: the enemy regrows Essence at the right end."],
	"sealed": [Color(0.85, 0.55, 1.0), Color(0.45, 0.15, 0.6), "Sealed: a wax seal covers 1 Essence of the pattern: it isn't needed any more."],
	"bottle": [Color(0.6, 0.95, 1.0), Color(0.1, 0.45, 0.6), "Bottle: a one-use item. Click it on your turn. You carry up to 3."],
	"purge": [Color(1.0, 0.6, 0.4), Color(0.7, 0.25, 0.05), "Purge: remove up to that many Essence of one kind from an enemy."],
	"fire": [Elements.COLORS["F"], Color(0.8, 0.25, 0.0), ""],
	"water": [Elements.COLORS["W"], Color(0.05, 0.35, 0.8), ""],
	"wind": [Elements.COLORS["A"], Color(0.05, 0.5, 0.35), ""],
	"air": [Elements.COLORS["A"], Color(0.05, 0.5, 0.35), ""],
	"random": [Color(0.95, 0.75, 1.0), Color(0.5, 0.2, 0.6), ""],  # ("Random": the any-Essence orb; "random": plain)
}
## The tri-colour "?" orb in a pattern. (Not a keyword: "any Essence" in rules text means something else.)
const ANY_ESSENCE := "Any Essence: the tri-colour orb. Fire, Water or Air fits that spot."
const NUMBER_DARK := Color(1.0, 0.88, 0.4)
const NUMBER_LIGHT := Color(0.55, 0.3, 0.0)

const LETTER_KEY := {"F": "fire", "W": "water", "A": "air"}
const ELEMENT_WORDS := {"Fire": "F", "Water": "W", "Air": "A", "Wind": "A", "Random": "?"}
const ELEMENT_ART := {"F": "essence_fire", "W": "essence_water", "A": "essence_wind", "?": "essence_any"}


## An element's bead picture for rich text ("" when there's none, or outside the running game: the UI skin needs the
## game's settings, which the headless tests don't load, so it's looked up only at run time).
static func _element_pic(el: String, px: int) -> String:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null or not tree.root.has_node("SaveManager"):
		return ""
	return load("res://scripts/ui/ui_skin.gd").inline(ELEMENT_ART[el], "", px)


## Does a capitalised word follow (so the element name is part of a name, like "Fire Ball")?
static func _starts_a_name(text: String, at: int) -> bool:
	return at + 1 < text.length() and text[at] == " " and text[at + 1] == text[at + 1].to_upper() and text[at + 1] != text[at + 1].to_lower()

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
## Element names written out (Fire, Water, Air) are shown as their bead pictures instead, icon_px tall; a name that
## starts a longer name (Fire Ball, Water Wall) stays a word.
static func colorize(text: String, on_parchment := false, links := false, icon_px := 22) -> String:
	var out := ""
	var last := 0
	for m in _regex().search_all(text):
		out += _escape(text.substr(last, m.get_start() - last))
		var word := m.get_string()
		var key := m.get_string(1).to_lower()
		var letter := m.get_string(2) + m.get_string(3) + m.get_string(4)
		if word in ELEMENT_WORDS and not _starts_a_name(text, m.get_end()):
			var pic := _element_pic(ELEMENT_WORDS[word], icon_px)
			if pic != "":
				out += pic
				last = m.get_end()
				continue
		if key == "random" and word != "Random":
			out += _escape(word)  # ("a random enemy": just a word)
			last = m.get_end()
			continue
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
	# (a keyword whose explanation IS the body, like a status badge's, isn't explained a second time)
	var gl := (glossary(body) + more_gloss).filter(func(g): return g.strip_edges() != body.strip_edges())
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
	# the tooltip's window is placed before its text has wrapped to its full height, so it can hang off the screen:
	# each time it changes size, push the window back inside the screen
	r.resized.connect(func(): _keep_on_screen.call_deferred(r))
	return r


## Moves the window holding `c` (a tooltip) back inside the visible screen, if any of it sticks out.
static func _keep_on_screen(c: Control) -> void:
	if not is_instance_valid(c) or not c.is_inside_tree():
		return
	var w := c.get_window()
	if w == null or w == c.get_tree().root:
		return
	var screen := c.get_tree().root.get_visible_rect().size
	var pos := Vector2(w.position)
	var sz := Vector2(w.size)
	pos.x = clampf(pos.x, 0.0, maxf(0.0, screen.x - sz.x))
	pos.y = clampf(pos.y, 0.0, maxf(0.0, screen.y - sz.y))
	if Vector2i(pos) != w.position:
		w.position = Vector2i(pos)


const ICON_PATH := {"{F}": "res://assets/icons/el_fire.png", "{W}": "res://assets/icons/el_water.png", "{A}": "res://assets/icons/el_wind.png", "{?}": "res://assets/icons/el_any.png"}


## Colour the text, then swap {F} {W} {A} {?} tokens for element orb images.
static func with_icons(text: String, on_parchment := false, px := 18) -> String:
	var out := colorize(text, on_parchment)
	for tok in ICON_PATH:
		out = out.replace(tok, "[img=%dx%d]%s[/img]" % [px, px, ICON_PATH[tok]])
	return out


static func _escape(s: String) -> String:
	return s.replace("[", "[lb]")
