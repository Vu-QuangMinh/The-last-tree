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
	var t := UiTheme.heading("The Last Tree · Wiki", 32, Color(0.85, 1, 0.75))
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(t)
	_search = LineEdit.new()
	_search.placeholder_text = "Search every rule…  (e.g. burn, armour, rest)"
	_search.custom_minimum_size = Vector2(460, 42)
	_search.add_theme_font_size_override("font_size", 18)
	_search.text_changed.connect(_on_search)
	top.add_child(_search)
	top.add_child(UiTheme.button(UiTheme.hk("Close", "Esc"), func(): closed.emit(), 20))
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
		["A turn, step by step", "1. You get new Essence (the top right shows what's coming next turn).\n2. Build a chant from your stock (as long as you like: only your bag limits it) and press Chant (Enter).\n3. Every active spell whose pattern appears in the chant comes alive. Cast the living spells, one charge at a time, in any order.\n4. When nothing is left to cast, the chant is Released by itself: its Essence fly at the enemies as comets, one by one from left to right.\n5. The enemies act, as their intents showed."],
		["Elements", "There are three: Fire {F}, Water {W} and Air {A}, written F, W and A for short. {?} on a card means any Essence. You start every fight with 5 random Essence and get 3 more each turn. Unused Essence are kept for later turns in the same fight."],
		["Enemy Essence", "An enemy's life is its Essence: a row of Essence, left to right. It dies when the row is empty. (Your own life is your HP.)"],
		["Controls", "F / W / A add an Essence to the chant · Backspace removes the last one · Enter: Chant · click a living spell (or 1–6) to cast it · Tab cycles targets and choices, Enter confirms · right-click or Esc puts a spell back · E: Release early (or Pass before you chant) · F1 opens this wiki."],
	]
	c["The chant"] = [
		["The Release", "When the chant is Released, every enemy loses the longest START of its Essence that appears unbroken anywhere in the chant.\nExample: enemies FFW and FWA both die to the chant FFWA. The chant FW leaves the first with FW (only its first F matched) and the second with A."],
		["Essence by Essence", "The Release reads the chant from left to right. Each chant Essence lifts off as a comet and flies into the enemy Essence it lines up with, knocking it off, so you can watch the Essence break in order."],
		["Spells come first", "All your spells are cast BEFORE the Release. Anything a spell does to an enemy (removing, moving or converting Essence, Expose, Armour breaks) changes what the Release will hit."],
		["Changing the chant", "Some spells change this turn's chant: Spark Word, Spring Word and Breath Word add an Essence anywhere you like; Resonance copies an Essence (×2), Triune Chant triples it (×3). Changes count straight away: new matches wake more spells (up to their limit)."],
		["One chant per turn", "You Chant once per turn. If you don't want to, press Pass (E) and keep your Essence."],
		["Armour", "Armoured Essence (grey ring) count for matching but are not removed that turn. F (F) W hit by FFW leaves F."],
		["Expose (paint)", "Expose N gives you a paint brush: paint N enemy Essence, on any enemies. Each becomes a rainbow Any Essence for the rest of the fight, and any Essence in your chant hits it."],
		["Confused and Blind", "Confused: your next chant is read backwards and the preview is off. Blind: some enemy Essence show as {?}; they still match normally."],
		["Warded and Ethereal enemies", "Warded enemies can only be struck by chants of 4 or more Essence. An Ethereal enemy can't be touched by the chant that turn."],
	]
	c["Spells"] = [
		["Patterns and charges", "A spell whose pattern (1–5 Essence) appears in the chant comes alive and triggers once that turn, however many times its pattern appears. A spell whose whole pattern is sealed (upgrades) wakes on every chant."],
		["Casting", "After you chant, every spell whose pattern appears comes alive (it glows and wobbles). Nothing casts itself: click each one you want. A spell that takes any Essence of your choice lets you click that Essence on any enemy; other targeted spells pull out an arrow. Right-click puts a selected spell back. Changed your mind after casting? Undo (the button under the chant, Ctrl+Z or Backspace) takes back the last spell. When you're done, press Release: the Release can't be undone."],
		["Lost?", "If you click around and nothing happens, a hint pops up explaining what's going on right now and what to click next."],
		["Your active row", "5 spells are active in a fight (never more than 8); the rest wait in your spellbook. Choose them before every encounter. Artifacts can add spell slots (the chant length never changes from artifacts)."],
		["Categories", "Every card is Offensive (red), Defensive (blue) or Utility (gold). Spell rewards always mix at least two categories."],
		["Rarity", "Cards are Common, Rare or Legendary; rarer cards are stronger for their pattern. After a normal fight each card offered is Common 70% of the time and Rare 30%. Elites always offer 3 Rare cards. Bosses offer 3 Legendary cards."],
		["Powers", "A Power fires once, then leaves your active row for the rest of the fight (the slot stays empty) and its effect lasts the whole fight. Open Grimoire adds 2 random spells from your spellbook to the row (net +1 spell)."],
		["Upgrades", "The merchant (and some events) can upgrade a spell: you choose one Essence of its pattern and a purple wax seal covers it. That Essence isn't needed any more, so the spell is easier to wake. The name stays the same. Seal every Essence of a spell and it wakes on every chant."],
		["Bottles", "One-use items for the fight you're in: Essence right now, healing, Shield, Burn, Poison, Freeze, stealing, even a spell from your spellbook. You carry up to 3 (the Bandolier gives 2 more slots). They sit under your HP bar in a fight: hover one to read it, click it on your turn to drink it. The merchant sells 2 at a time; fights and some events hand them out too."],
		["Reading a card", "The name box is coloured by category, the orbs under it are the pattern, and the rules are plain sentences. Spells Remove Essence from an enemy's Essence. \"The 3 rightmost Essence\" are the 3 Essence at the right end of its row; \"the 3 leftmost Essence\" are the 3 at the left end. Targeted lets you pick any Essence in it. Hover a card for the full explanation of every keyword on it."],
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
		["Move order", "Each enemy uses its moves in a fixed order, looping. Normal enemies mix attacks, defence (Armour, Mend) and tricks (buffs, debuffs on you). Bosses switch to a second, harsher list at half Essence."],
		["The Codex", "Defeat an enemy once and it goes into the Codex with its Essence and full move list. Until then its Essence shows as {?} on the preparation screen and its moves are unknown."],
	] + intents + passives
	var arts := []
	for a in Artifacts.ALL:
		var tag: String = " · %s%s" % [Artifacts.TIER_NAMES.get(a.tier, ""), " (boss only)" if a.pool == "boss" else ""]
		arts.append(["%s: %s%s" % [a.aspect, a.name, tag], a.desc])
	arts.sort_custom(func(a, b): return a[0] < b[0])
	c["Artifacts"] = [
		["Artifact tiers", "Artifacts are Common, Rare or Legendary. Keepsakes are always Common; elites, treasure and the merchant offer Common ones 75% of the time and Rare ones 25%; Legendary artifacts only drop from bosses. Anything that adds spell slots is Rare or Legendary, and you can never have more than 8 active spells."],
		["Artifacts", "Relics that last the whole run. You choose a keepsake at the start; elites and treasure rooms give more. Every boss gives a relic that adds Essence to every turn. Cursed artifacts (red) are stronger but come with a price: fewer starting Essence, fewer spell slots, less max HP, more damage taken…"],
	] + arts
	c["The run"] = [
		["The map", "Each act is a map of 12 floors and a boss, drawn like Slay the Spire: paths branch and merge, and you pick your way up one room at a time. Floor 1 is always fights, floor 6 is always treasure, and the floor before the boss is always a campfire. Elites and campfires never appear before floor 5, and the same special room never comes twice in a row on a path. ⚔ Fight · 👹 Elite · ❓ Unknown · 🛒 Merchant · 🎁 Treasure · 🔥 Campfire · 👑 Boss."],
		["Unknown rooms", "A ? room is usually an event: a little story with a choice (a gamble, a trade of HP or Leaves for spells, artifacts or upgrades). Sometimes it turns out to be a fight, a merchant or treasure instead."],
		["Leaves and the merchant", "Fights give Leaves (elites and bosses more). The merchant sells spells (Common 45, Rare 75, Legendary 140), artifacts (110, rare 170), 2 bottles (20–80, by strength), a wax seal for one of your spells (160) and a hot meal (heal 30%, 40)."],
		["Rewards", "Normal fight: pick 1 of 3 spells (70% Common, 30% Rare each). Elite: 1 of 3 Rare spells and an artifact. Boss: 1 of 3 Legendary spells and a relic that raises your Essence income; you also heal half your HP."],
		["Campfires", "Rest (heal 30% of max HP), or Fuse two spells into one."],
		["Fusing", "Fuse melts two spells into ONE spell that does everything both did. Its pattern is the first spell you picked followed by the whole of the second (nothing is lost). It gets a name of its own. You see the result before you confirm. Both spells are used up; fused spells can't be fused again, and Powers can't be fused. Before fusing you can look over all your other spells, and you're warned if the new pattern would break one of your anti-spells. Every fusion drips a drop of purple wax that seals one Essence of the new spell (you choose which)."],
		["The fusion's wax", "Every fusion drips one drop of purple wax onto the new spell: you choose which Essence of its pattern it seals, and that Essence isn't needed any more. (Fused anti-spells keep both patterns whole: no wax.)"],
		["Treasure", "Choose 1 of 3 artifacts. One of them is always cursed."],
		["Enemies grow", "Deeper floors add extra random Essence to the end of enemies' Essence, and later acts hit harder and send bigger groups."],
		["Seedlings and unlocks", "Every fight earns Seedlings (more for elites and bosses, a bonus for winning). Spend them in Unlocks to add spells and artifacts to future runs."],
	]
	return c
