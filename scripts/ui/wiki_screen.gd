class_name WikiScreen
extends Control
## The rulebook: every rule of the game in tabs, with a search box that looks through all of them.
## Open it from the main menu (How to play / Wiki) or with F1 at any time.

signal closed

const TABS := ["How to play", "The chant", "Spells", "Keywords", "Enemies & intents", "Artifacts", "The run"]

var _tabs: TabContainer
var _search: LineEdit
var _results: VBoxContainer
var _results_scroll: ScrollContainer


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = UiTheme.get_theme()
	mouse_filter = Control.MOUSE_FILTER_STOP
	var bg := ColorRect.new()
	bg.color = Color(0.03, 0.05, 0.04, 0.98)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var v := VBoxContainer.new()
	v.position = Vector2(40, 20)
	v.size = Vector2(1840, 1040)
	v.add_theme_constant_override("separation", 10)
	add_child(v)
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 16)
	v.add_child(top)
	var t := UiTheme.label("The Last Tree · Wiki", 32, Color(0.85, 1, 0.75))
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(t)
	_search = LineEdit.new()
	_search.placeholder_text = "Search every rule…  (e.g. burn, armour, rest)"
	_search.custom_minimum_size = Vector2(460, 42)
	_search.add_theme_font_size_override("font_size", 18)
	_search.text_changed.connect(_on_search)
	top.add_child(_search)
	top.add_child(UiTheme.button("Close  (Esc)", func(): closed.emit(), 20))
	_tabs = TabContainer.new()
	_tabs.custom_minimum_size = Vector2(1840, 960)
	_tabs.add_theme_font_size_override("font_size", 19)
	v.add_child(_tabs)
	var content := _content()
	for name in TABS:
		var scroll := ScrollContainer.new()
		scroll.name = name
		scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		var col := VBoxContainer.new()
		col.custom_minimum_size = Vector2(1800, 0)
		col.add_theme_constant_override("separation", 14)
		scroll.add_child(col)
		for entry in content[name]:
			col.add_child(_entry(entry[0], entry[1]))
		_tabs.add_child(scroll)
	_results_scroll = ScrollContainer.new()
	_results_scroll.name = "Search results"
	_results_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_results = VBoxContainer.new()
	_results.custom_minimum_size = Vector2(1800, 0)
	_results.add_theme_constant_override("separation", 14)
	_results_scroll.add_child(_results)
	_tabs.add_child(_results_scroll)
	_tabs.set_tab_hidden(_tabs.get_tab_count() - 1, true)


func _entry(title: String, body: String) -> Control:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", UiTheme.panel_box(0.9, 10))
	var r := RichTextLabel.new()
	r.bbcode_enabled = true
	r.fit_content = true
	r.scroll_active = false
	r.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	r.custom_minimum_size = Vector2(1760, 0)
	r.add_theme_font_size_override("normal_font_size", 18)
	r.add_theme_font_size_override("bold_font_size", 18)
	r.add_theme_color_override("default_color", Color(0.9, 0.92, 0.86))
	r.text = "[font_size=22][b][color=#bfe8a8]%s[/color][/b][/font_size]\n%s" % [title, Keywords.with_icons(body, false, 20)]
	p.add_child(r)
	p.set_meta("search", (title + " " + body).to_lower())
	return p


func _on_search(q: String) -> void:
	q = q.strip_edges().to_lower()
	var last := _tabs.get_tab_count() - 1
	if q.length() < 2:
		_tabs.set_tab_hidden(last, true)
		if _tabs.current_tab == last:
			_tabs.current_tab = 0
		return
	for c in _results.get_children():
		c.queue_free()
	var content := _content()
	var hits := 0
	for name in TABS:
		for entry in content[name]:
			if (entry[0] + " " + entry[1]).to_lower().contains(q):
				_results.add_child(_entry("%s  ·  [color=#8c9a8c]%s[/color]" % [entry[0], name], entry[1]))
				hits += 1
	if hits == 0:
		_results.add_child(UiTheme.label("Nothing matches \"%s\"." % q, 20, UiTheme.MUTED))
	_tabs.set_tab_hidden(last, false)
	_tabs.set_tab_title(last, "Search: %d" % hits)
	_tabs.current_tab = last


func _unhandled_input(ev: InputEvent) -> void:
	if ev is InputEventKey and ev.pressed and ev.keycode == KEY_ESCAPE:
		closed.emit()
		get_viewport().set_input_as_handled()


# ------------------------------------------------------------------ the rules

## {tab: [[title, body], ...]}. Bodies use plain words (keywords and numbers get coloured) and {F} {W} {A} {?} orbs.
static func _content() -> Dictionary:
	var c := {}
	c["How to play"] = [
		["The goal", "Walk three acts of the forest and beat the boss at the end of each one. You have 50 HP for the whole run; it does not refill between fights."],
		["A turn, step by step", "1. You get new elements (the top right shows what's coming next turn).\n2. Build a chant of up to 8 elements from your stock and press Chant (Enter).\n3. Every active spell whose pattern appears in the chant comes alive. Cast the living spells, one charge at a time, in any order.\n4. When nothing is left to cast, the chant is Released by itself: its elements fly at the enemies as comets, one by one from left to right.\n5. The enemies act, as their intents showed."],
		["Elements", "There are three: Fire {F}, Water {W} and Air {A}, written F, W and A for short. {?} on a card means any element. You start every fight with 5 random elements and get 3 more each turn. Unused elements are kept for later turns in the same fight."],
		["Enemy HP", "An enemy's HP is a row of elements, left to right. It dies when the row is empty."],
		["Controls", "F / W / A add an element to the chant · Backspace removes the last one · Enter: Chant · click a living spell (or 1–6) to cast it · Tab cycles targets and choices, Enter confirms · right-click or Esc puts a spell back · E: Release early (or Pass before you chant) · F1 opens this wiki."],
	]
	c["The chant"] = [
		["The Release", "When the chant is Released, every enemy loses the longest START of its HP that appears unbroken anywhere in the chant.\nExample: enemies FFW and FWA both die to the chant FFWA. The chant FW leaves the first with FW (only its first F matched) and the second with A."],
		["Element by element", "The Release reads the chant from left to right. Each chant element lifts off as a comet and flies into the enemy HP it lines up with, knocking it off, so you can watch the HP break in order."],
		["Spells come first", "All your spells are cast BEFORE the Release. Anything a spell does to an enemy (removing, moving or converting elements, Expose, Armour breaks) changes what the Release will hit."],
		["Changing the chant", "Some spells change this turn's chant: Spark Word, Spring Word and Breath Word add an element anywhere you like; Resonance copies an element (×2), Triune Chant triples it (×3). Changes count straight away: new matches wake more spells (up to their limit)."],
		["One chant per turn", "You Chant once per turn. If you don't want to, press Pass (E) and keep your elements."],
		["Armour", "Armoured elements (grey ring) count for matching but are not removed that turn. F (F) W hit by FFW leaves F."],
		["Exposed", "An Exposed enemy loses 1 extra element from the back whenever your Release hits it. Expose lasts until the end of your turn for each turn it has."],
		["Confused and Blind", "Confused: your next chant is read backwards and the preview is off. Blind: some enemy elements show as {?}; they still match normally."],
		["Warded and Ethereal enemies", "Warded enemies can only be struck by chants of 4 or more elements. An Ethereal enemy can't be touched by the chant that turn."],
	]
	c["Spells"] = [
		["Patterns and charges", "A spell's pattern (1–5 elements) triggers once for each separate match in the chant, but never more times than its pattern is long: WW triggers at most twice, even if you chant six Water. One-element spells trigger once."],
		["Casting", "Living spells glow and tilt. Click one to cast a charge. Targeted spells pull out an arrow: click an enemy, or Tab through targets and press Enter. Spells that pick an element (Gust) or a place (Move, Infuse) work the same way: click, or Tab + Enter."],
		["Your active row", "6 spells are active in a fight; the rest wait in your spellbook. Choose them before every encounter. Artifacts can add spell slots (the chant length never changes from artifacts)."],
		["Categories", "Every card is Offensive (red), Defensive (blue) or Utility (gold). Spell rewards always mix at least two categories."],
		["Rarity", "Cards are Common, Rare or Legendary; rarer cards are stronger for their pattern. After a normal fight each card offered is Common 70% of the time and Rare 30%. Elites always offer 3 Rare cards. Bosses offer 3 Legendary cards."],
		["Powers", "A Power fires once, then leaves your active row for the rest of the fight (the slot stays empty) and its effect lasts the whole fight. Open Grimoire adds 2 random spells from your spellbook to the row (net +1 spell)."],
		["Upgrades", "At a rest site you can upgrade a spell instead of resting. Its + version (gold name box) has bigger numbers for the rest of the run."],
		["Reading a card", "The name box is coloured by category, the orbs under it are the pattern, and the rules are plain sentences. Damage knocks elements off an enemy's HP bar: \"the last HP\" is its rightmost element, \"the first HP\" its leftmost. Targeted damage lets you pick any element in the bar. Hover a card for the full explanation of every keyword on it."],
	]
	var kw := []
	for k in Keywords.K:
		var ex: String = Keywords.K[k][2]
		if ex == "" or kw.any(func(e): return e[1] == ex):
			continue
		kw.append([ex.get_slice(":", 0), ex.get_slice(":", 1).strip_edges()])
	kw.sort_custom(func(a, b): return a[0] < b[0])
	c["Keywords"] = kw
	var intents := []
	for kind in IntentChip.INFO:
		intents.append(["%s %s" % [IntentChip.LOOK[kind][0], IntentChip.INFO[kind][0]], IntentChip.INFO[kind][1]])
	intents.sort_custom(func(a, b): return a[0].substr(2) < b[0].substr(2))
	var passives := []
	for p in EnemyDefs.PASSIVE_TEXT:
		var txt: String = EnemyDefs.PASSIVE_TEXT[p]
		passives.append([txt.get_slice(":", 0), txt.get_slice(":", 1).strip_edges()])
	passives.sort_custom(func(a, b): return a[0] < b[0])
	c["Enemies & intents"] = [
		["Intents", "Above every enemy, symbols show what it will do on its turn (hover for details). Red = attack, blue = it helps itself, purple = aimed at you."],
		["Move order", "Each enemy uses its moves in a fixed order, looping. Normal enemies mix attacks, defence (Armour, Mend) and tricks (buffs, debuffs on you). Bosses switch to a second, harsher list at half HP."],
		["The Codex", "Defeat an enemy once and it goes into the Codex with its HP and full move list. Until then its HP shows as {?} on the preparation screen and its moves are unknown."],
	] + intents + passives
	var arts := []
	for a in Artifacts.ALL:
		var tag: String = {"boss": " (boss relic)", "curse": " (cursed)"}.get(a.pool, "")
		arts.append(["%s: %s%s" % [a.aspect, a.name, tag], a.desc])
	arts.sort_custom(func(a, b): return a[0] < b[0])
	c["Artifacts"] = [
		["Artifacts", "Relics that last the whole run. You choose a keepsake at the start; elites and treasure rooms give more. Every boss gives a relic that adds elements to every turn. Cursed artifacts (red) are stronger but come with a price: fewer starting elements, fewer spell slots, less max HP, more damage taken…"],
	] + arts
	c["The run"] = [
		["The map", "Each act is a map of 12 floors and a boss, drawn like Slay the Spire: paths branch and merge, and you pick your way up one room at a time. Floor 1 is always fights, floor 6 is always treasure, and the floor before the boss is always a campfire. Elites and campfires never appear before floor 5, and the same special room never comes twice in a row on a path. ⚔ Fight · 👹 Elite · ❓ Unknown · 🛒 Merchant · 🎁 Treasure · 🔥 Campfire · 👑 Boss."],
		["Unknown rooms", "A ? room is usually an event: a little story with a choice (a gamble, a trade of HP or Amber for spells, artifacts or upgrades). Sometimes it turns out to be a fight, a merchant or treasure instead."],
		["Amber and the merchant", "Fights give Amber (elites and bosses more). The merchant sells spells (Common 45, Rare 75, Legendary 140), artifacts (120), a spell upgrade (60) and a hot meal (heal 30%, 40)."],
		["Rewards", "Normal fight: pick 1 of 3 spells (70% Common, 30% Rare each). Elite: 1 of 3 Rare spells and an artifact. Boss: 1 of 3 Legendary spells and a relic that raises your element income; you also heal half your HP."],
		["Campfires", "Either rest (heal 30% of max HP) or upgrade one spell."],
		["Treasure", "Choose 1 of 3 artifacts. One of them is always cursed."],
		["Enemies grow", "Deeper floors add extra random elements to the end of enemies' HP, and later acts hit harder and send bigger groups."],
		["Seedlings and unlocks", "Every fight earns Seedlings (more for elites and bosses, a bonus for winning). Spend them in Unlocks to add spells and artifacts to future runs."],
	]
	return c
