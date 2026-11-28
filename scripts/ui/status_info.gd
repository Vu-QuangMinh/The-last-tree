class_name StatusInfo
extends RefCounted
## Every status of the new fight (MarbleBridge), on you and on enemies, as a symbol (the user, 2026-11-27): a round chip
## with its picture (painted status art when there is some, else its emoji) and its number; hovering it shows ONE
## tooltip box with what it does, and nothing else. No words on the screen for statuses.

## id -> [name, emoji, colour, what it does (%d: its number), painted art names to try]
const DEFS := {
	"burn": ["Burn", "🔥", Color(1.0, 0.55, 0.2), "At the start of its turn it takes %d damage, then Burn drops by 1.", ["status_burn", "intent_burn"]],
	"weak": ["Weakened", "🥀", Color(0.8, 0.6, 1.0), "Deals 50% less damage. %d turn(s) left: it drops by 1 each turn.", []],
	"vulnerable": ["Vulnerable", "🎯", Color(1.0, 0.45, 0.35), "Takes 50% more damage. %d turn(s) left: it drops by 1 each turn.", ["status_vulnerable"]],
	"expose": ["Expose", "👁", Color(0.85, 0.6, 1.0), "Each hit on it deals %d more damage. It drops by 1 each turn.", []],
	"armor": ["Armor", "⛨", Color(0.75, 0.78, 0.85), "Each hit on it deals %d less damage.", ["icon_armor_shield"]],
	"thorns": ["Thorns", "🌵", Color(0.5, 0.85, 0.25), "Whoever hits it with an attack takes %d damage back, per hit.", ["status_thorns"]],
	"power": ["Power", "💪", Color(1.0, 0.6, 0.3), "+%d damage on every hit. It lasts the whole fight.", []],
	"dodge": ["Dodge", "🪽", Color(1.0, 0.9, 0.55), "Dodges the next %d attack(s) completely.", ["status_aegis"]],
	"stun": ["Stunned", "💫", Color(1.0, 0.85, 0.3), "Skips its next turn.", ["status_stunned", "intent_stunned"]],
	"flying": ["Flying", "🪶", Color(0.7, 0.9, 1.0), "In the air every hit on it deals only 1 damage. %d more hit(s) knock it down (Stunned, and +1 Power).", []],
	"ethereal": ["Ethereal", "👻", Color(0.75, 0.7, 1.0), "Takes no damage this turn.", ["status_ethereal", "intent_ethereal"]],
	"shield": ["Shield", "🛡", Color(0.5, 0.75, 1.0), "Blocks %d damage, until its next turn.", ["icon_armor_shield"]],
}


static func has(id: String) -> bool:
	return DEFS.has(id)


## The tooltip: its name and number, then what it does.
static func tip(id: String, n: int) -> String:
	var d: Array = DEFS.get(id, [id.capitalize(), "", Color.WHITE, "", []])
	var body := String(d[3])
	if body.contains("%d"):
		body = body.replace("%d", str(n))  # (not `%`: "50% less" is not a format)
	var title := String(d[0]) + (" %d" % n if n > 0 and String(d[3]).contains("%d") else "")
	return "[b][font_size=25]%s[/font_size][/b]\n%s" % [title, Keywords.colorize(body)]  # (no keyword glossary under it: its own line says it all)


## Its painted picture's name, or "".
static func art(id: String) -> String:
	for nm in (DEFS.get(id, ["", "", Color.WHITE, "", []]) as Array)[4]:
		if UiSkin.tex(String(nm)) != null:
			return String(nm)
	return ""


## A chip: its symbol in a soft disc of its colour, its number at the bottom right; hover = its one tooltip box.
static func chip(id: String, n: int, px := 34.0) -> TipPanel:
	var d: Array = DEFS.get(id, [id, "❔", Color.WHITE, "", []])
	var c := TipPanel.new()
	c.custom_minimum_size = Vector2(px, px)
	c.size_flags_vertical = Control.SIZE_SHRINK_CENTER  # (never stretched by a taller row: a circle, not an oval; the user 2026-11-28)
	c.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.08, 0.05, 0.04, 0.82)
	sb.border_color = (d[2] as Color).lightened(0.2)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(int(px / 2.0))
	c.add_theme_stylebox_override("panel", sb)
	c.mouse_filter = Control.MOUSE_FILTER_STOP
	var holder := Control.new()
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.add_child(holder)
	var pic := art(id)
	var icon: Control
	if pic != "":
		icon = UiSkin.icon(pic, px - 6.0)
	if icon == null:
		var l := UiTheme.label(String(d[1]), int(px * 0.55), Color.WHITE)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		icon = l
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	holder.add_child(icon)
	if n > 0 and String(d[3]).contains("%d"):
		var num := UiTheme.label(str(n), int(px * 0.42), Color.WHITE)
		num.add_theme_constant_override("outline_size", 5)
		num.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.95))
		num.mouse_filter = Control.MOUSE_FILTER_IGNORE
		num.position = Vector2(px - 6.0 - px * 0.24 * str(n).length(), px - px * 0.55)
		holder.add_child(num)
	c.tooltip_text = tip(id, n)
	return c
