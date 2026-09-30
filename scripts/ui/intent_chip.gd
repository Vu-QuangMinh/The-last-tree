class_name IntentChip
extends PanelContainer
## An enemy intent as symbols: a coloured chip per move part (icon + number). Words live in the tooltip.

const RED := Color(0.85, 0.22, 0.2)
const BLUE := Color(0.25, 0.5, 0.85)
const GREEN := Color(0.25, 0.65, 0.35)
const PURPLE := Color(0.55, 0.3, 0.8)
const GREY := Color(0.45, 0.47, 0.52)

## kind -> [glyph, colour]
const LOOK := {
	"attack": ["⚔", RED], "armor": ["🛡", GREY], "mend": ["✚", GREEN], "shuffle": ["🔀", BLUE],
	"silence": ["🔇", PURPLE], "lock": ["🔒", PURPLE], "steal": ["✋", PURPLE], "confuse": ["🌀", PURPLE],
	"blind": ["🙈", PURPLE], "bleed": ["🩸", PURPLE], "freeze": ["❄", PURPLE], "ethereal": ["👻", BLUE],
	"empower": ["💪", BLUE], "summon": ["👤+", BLUE], "toll": ["⛓", PURPLE], "invert": ["🔄", PURPLE],
	"hex": ["🕯", PURPLE], "mimic": ["🎭", PURPLE], "frail": ["💔", PURPLE],
}


## kind -> [name, explanation]
const INFO := {
	"attack": ["Attack", "Deals this much damage to you (per hit). Shield and Aegis block it."],
	"armor": ["Armour", "Armours one of its Essence: it still counts for matching, but isn't removed this turn."],
	"mend": ["Mend", "Regrows Essence at the right end of its row."],
	"shuffle": ["Shuffle", "Moves its first Essence to the end."],
	"silence": ["Silence", "One of your spells can't fire for a few turns."],
	"lock": ["Lock", "Locks one of your spells. Chant the lock's symbols, unbroken, to break it."],
	"steal": ["Steal", "Takes Essence from your bag and adds it to its own."],
	"confuse": ["Confuse", "Your next chant is read backwards, and there's no preview."],
	"blind": ["Blind", "Some enemy Essence show as ?. They still match normally."],
	"bleed": ["Bleed", "At the start of your turn you lose that much HP, then Bleed goes down by 1."],
	"freeze": ["Freeze", "Freezes some of your Essence: they can't be used next turn."],
	"ethereal": ["Ethereal", "Your next chant can't touch it."],
	"empower": ["Empower", "Its attacks deal more damage from now on."],
	"summon": ["Summon", "Calls more enemies into the fight."],
	"toll": ["Toll", "Your next chant has 2 fewer slots."],
	"invert": ["Invert", "Swaps all your Fire and Water Essence."],
	"hex": ["Hex", "Marks one of your Essence: chanting it costs 2 HP."],
	"mimic": ["Mimic", "Its Essence becomes your last chant, backwards."],
	"frail": ["Frail", "You take 25% more attack damage for a few turns."],
}


static func make(e: EnemyState) -> IntentChip:
	var c := IntentChip.new()
	c.build(e)
	return c


func build(e: EnemyState) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.04, 0.05, 0.05, 0.92)
	sb.set_corner_radius_all(12)
	sb.set_border_width_all(2)
	sb.border_color = Color(1, 1, 1, 0.15)
	sb.content_margin_left = 8
	sb.content_margin_right = 8
	sb.content_margin_top = 4
	sb.content_margin_bottom = 4
	add_theme_stylebox_override("panel", sb)
	mouse_filter = Control.MOUSE_FILTER_STOP
	size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(row)
	if e.freeze_turns > 0:
		row.add_child(_part("❄", "", Color(0.5, 0.8, 1.0)))
		row.add_child(_word("skips", Color(0.7, 0.9, 1)))
		tooltip_text = "[b][font_size=25]Frozen[/font_size][/b]\n❄ " + Keywords.colorize("Frozen: it skips its next action.")
		return
	var m := e.intent
	var lines := ["[b][font_size=25]%s intends to…[/font_size][/b]" % e.name]
	while not m.is_empty():
		_add_move(row, m, e)
		var look: Array = LOOK.get(m.kind, ["?", GREY])
		var info: Array = INFO.get(m.kind, [m.kind.capitalize(), ""])
		var what := EnemyDefs.describe_move(_single(m), e.dmg_bonus) if m.kind != "attack" else _attack_words(m, e)
		lines.append("%s [color=#%s][b]%s[/b][/color]: %s\n[color=#b8c2b8]%s[/color]" % [look[0], (look[1] as Color).lightened(0.35).to_html(false), info[0], Keywords.colorize(what), info[1]])
		m = m.get("also", {})
	if e.redirect_to != null and is_instance_valid(e.redirect_to):
		var who := "itself" if e.redirect_to == e else e.redirect_to.name
		row.add_child(_word("↪ " + who, Color(0.6, 1, 0.8)))
		lines.append("↪ " + Keywords.colorize("Redirected: its attacks hit %s, and anything aimed at you fizzles." % who))
	tooltip_text = "\n".join(lines)


## One move without its "also" part (for describing each part on its own).
static func _single(m: Dictionary) -> Dictionary:
	var c := m.duplicate()
	c.erase("also")
	return c


func _make_custom_tooltip(for_text: String) -> Object:
	if for_text.strip_edges() == "":
		return null  # no text (e.g. its tooltip is pinned): no hover tooltip at all
	return Keywords.make_tooltip(for_text)


static func attack_damage(m: Dictionary, e: EnemyState) -> int:
	return int(floorf((m.n + e.dmg_bonus) * e.damage_mult()))


func _attack_words(m: Dictionary, e: EnemyState) -> String:
	var hits: int = m.get("hits", 1)
	return "Attack for %d%s" % [attack_damage(m, e), (" × %d hits" % hits) if hits > 1 else ""]


func _add_move(row: HBoxContainer, m: Dictionary, e: EnemyState) -> void:
	var look: Array = LOOK.get(m.kind, ["?", GREY])
	var num := ""
	match m.kind:
		"attack":
			var hits: int = m.get("hits", 1)
			num = str(attack_damage(m, e)) + (("×%d" % hits) if hits > 1 else "")
		"mend":
			num = "+%d" % m.n
		"bleed", "freeze", "steal", "summon":
			num = str(m.n)
		"empower":
			num = "+%d" % m.n
		"lock":
			num = str(m.len)
		"blind", "silence", "frail":
			num = str(m.turns)
		"toll":
			num = "-2"
	row.add_child(_part(look[0], num, look[1]))
	if m.kind == "mend" and m.el != "random":
		row.add_child(ElementIcon.make(m.el, 22))


func _part(glyph: String, num: String, col: Color) -> Control:
	var p := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = col.darkened(0.25)
	sb.set_corner_radius_all(9)
	sb.content_margin_left = 6
	sb.content_margin_right = 8
	sb.content_margin_top = 1
	sb.content_margin_bottom = 1
	p.add_theme_stylebox_override("panel", sb)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 3)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_child(h)
	var g := UiTheme.label(glyph, 20, Color.WHITE)
	g.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(g)
	if num != "":
		var n := UiTheme.label(num, 22, Color.WHITE)
		n.add_theme_constant_override("outline_size", 4)
		n.add_theme_color_override("font_outline_color", Color.BLACK)
		n.mouse_filter = Control.MOUSE_FILTER_IGNORE
		h.add_child(n)
	return p


func _word(t: String, col: Color) -> Label:
	var l := UiTheme.label(t, 16, col)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l
