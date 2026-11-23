class_name MarbleCardView
extends Control
## A Marble mode card, drawn with the main mode's own card (SpellCard: name banner, pattern orbs, coloured rules text,
## the Rare / Legendary corner plate, no picture; 2026-11-21). This is only a holder that turns a MarbleCards card
## into the dictionary SpellCard reads, and passes its fight state on. Clicking it: `pressed`. `wiggle_shine`: a card
## you could upgrade by taking it (it wiggles and shines white; the user's rule).

signal pressed

const W := SpellCard.W
const H := SpellCard.H
const RARITY_COL := {"common": Color(0.55, 0.45, 0.35), "rare": Color(0.3, 0.6, 0.35), "legendary": Color(0.85, 0.62, 0.15)}

var card: Dictionary = {}
var charges := 0  # (awake: casts left this turn)
var state := ""  # SpellCard's state: "", "silenced", "cooldown", "used", "spent", "broken"
var state_text := ""  # written across it ("COOLDOWN 1"...)
var dim := false  # (chanted, not woken: greyed like a spent card)
var glow := false  # (aiming: its target arrow is out)
var extra := ""  # a live number under its words ("Now: 6")
var wiggle_shine := false
var spell_card: SpellCard
var _t := 0.0


## A MarbleCards card as the dictionary SpellCard draws.
static func spell_of(c: Dictionary, more := "") -> Dictionary:
	var p: Dictionary = c.get("p", {})
	var id := String(c.get("id", ""))
	var kind := "utility"
	if id in MarbleCards.DAMAGE_CARDS or p.has("d") or p.has("burn"):
		kind = "damage"
	elif p.has("shield") or p.has("heal") or p.has("thorns") or p.has("dodge"):
		kind = "defense"
	var desc := String(c.get("text", ""))
	if more != "":
		desc += "\n" + more
	return {"id": id, "name": String(c.get("name", "?")), "pattern": String(c.get("pattern", "")), "kind": kind,
		"rarity": String(c.get("rarity", "common")), "power": bool(c.get("power", false)),
		"upgraded": int(c.get("level", 0)) > 0, "desc": desc, "effects": []}


func _ready() -> void:
	custom_minimum_size = Vector2(W, H)
	size = custom_minimum_size
	if wiggle_shine:
		pivot_offset = size / 2.0  # (it wiggles about its middle; otherwise it scales from its top-left, like a card in its row)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	spell_card = SpellCard.make(spell_of(card, extra))
	spell_card.size = Vector2(W, H)
	spell_card.clicked.connect(func(_c: SpellCard): pressed.emit())
	add_child(spell_card)
	apply()
	set_process(wiggle_shine)


## Passes the fight state on to the card.
func apply() -> void:
	if spell_card == null:
		return
	spell_card.charges = charges
	spell_card.aiming = glow
	spell_card.selected = glow
	spell_card.state = state if state != "" else ("spent" if dim else "")
	spell_card.state_text = state_text
	spell_card.refresh()


func _process(dt: float) -> void:
	_t += dt
	rotation = sin(_t * 9.0) * 0.05 * (1.0 if fmod(_t, 1.6) < 0.6 else 0.0)  # (wiggle wiggle, then a rest)
	queue_redraw()


func _draw() -> void:
	if not wiggle_shine:
		return
	var a := 0.25 + 0.25 * sin(_t * 5.0)
	var sh := StyleBoxFlat.new()
	sh.draw_center = false
	sh.border_color = Color(1, 1, 1, a + 0.3)
	sh.set_border_width_all(7)
	sh.set_corner_radius_all(14)
	draw_style_box(sh, Rect2(Vector2(-6, -6), size + Vector2(12, 12)))
