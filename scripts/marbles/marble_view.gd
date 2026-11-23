class_name MarbleView
extends Control
## One marble: a plain coloured ball (Fire red-orange, Water blue, Wind pale green); a carved one has its symbol drawn
## on it. "?" while you are Blind; a frosty rim when Frozen. A Star marble is just the any-colour marble (no colour, no
## stamp: the user 2026-11-23). Click: `pressed`.

signal pressed

const COLS := {"F": Color(0.92, 0.36, 0.18), "W": Color(0.25, 0.55, 0.95), "A": Color(0.62, 0.86, 0.6)}
const SYM := {"sword": "🗡", "shield": "🛡", "coin": "🪙", "heart": "❤", "skull": "💀", "wing": "🪽", "star": "⭐",
	"fist": "✊", "ghost": "👻"}
## What each carving does when a card's pattern counts its marble (2026-11-22: not when the chant is spoken).
const SYM_WORDS := {"sword": "Sword: the card that counts it deals +3 damage per hit this turn",
	"shield": "Shield: the card that counts it gives +3 Shield this turn", "coin": "Coin: +1 coin when it is counted",
	"heart": "Heart: heal 2 when it is counted", "skull": "Skull: the card that counts it deals x1.5 damage this turn (one Skull a card)",
	"wing": "Wing: the card that counts it gives x1.5 Shield this turn (one Wing a card)", "star": "Star: counts as any colour",
	"fist": "Fist: +1 Power for the fight when it is counted", "ghost": "Ghost: +1 Dodge when it is counted"}

var colour := "F"
var sym := ""
var veiled := false
var frozen := false
var px := 56.0
var hot := false  # (can be clicked now: a light rim)


static func make(m: Dictionary, size_px := 56.0) -> MarbleView:
	var v := MarbleView.new()
	v.colour = String(m.get("c", "F"))
	v.sym = String(m.get("sym", ""))
	v.veiled = bool(m.get("hidden", false))
	v.frozen = bool(m.get("frozen", false))
	v.px = size_px
	v.custom_minimum_size = Vector2(size_px, size_px)
	v.size = v.custom_minimum_size
	return v


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	if veiled:
		tooltip_text = "Blind: you can't see this marble's colour."
	elif sym == "star":
		tooltip_text = "Any-colour marble: it counts as any colour."
	elif sym != "":
		tooltip_text = "%s marble, carved. %s" % [{"F": "Fire", "W": "Water", "A": "Wind"}[colour], SYM_WORDS.get(sym, sym)]
	else:
		tooltip_text = {"F": "Fire", "W": "Water", "A": "Wind"}.get(colour, "") + " marble"


func _draw() -> void:
	var c := size / 2.0
	var r := px / 2.0 - 3.0
	var col: Color = Color(0.45, 0.45, 0.5) if veiled else (Color(0.95, 0.85, 0.4) if sym == "star" else COLS.get(colour, Color.GRAY))
	# the main mode's Essence art (2026-11-21: Marble mode looks like the main mode); the plain ball when the art is missing
	var star := sym == "star" and not veiled
	var art: Texture2D = null if veiled else UiSkin.tex("essence_any" if star else String(ElementIcon.ART.get(colour, "")))
	if art != null:
		draw_texture_rect(art, Rect2(Vector2.ZERO, size), false)
	else:
		draw_circle(c + Vector2(2, 3), r, Color(0, 0, 0, 0.35))
		draw_circle(c, r, col.darkened(0.25))
		draw_circle(c - Vector2(r * 0.08, r * 0.08), r * 0.86, col)
		draw_circle(c - Vector2(r * 0.35, r * 0.35), r * 0.22, Color(1, 1, 1, 0.45))
	var font: Font = ThemeDB.fallback_font
	if veiled:
		draw_string(font, c + Vector2(-r, r * 0.38), "?", HORIZONTAL_ALIGNMENT_CENTER, r * 2.0, int(r * 1.1), Color.WHITE)
	elif star:
		if art == null:  # (no art: a "?" on the ball, like the fight's any-colour marble)
			draw_string(font, c + Vector2(-r, r * 0.38), "?", HORIZONTAL_ALIGNMENT_CENTER, r * 2.0, int(r * 1.1), Color.WHITE)
	elif sym != "":
		var at := c + Vector2(-r, r * 0.36)
		var fs := int(r * 0.95)
		draw_string_outline(font, at, String(SYM.get(sym, "")), HORIZONTAL_ALIGNMENT_CENTER, r * 2.0, fs, 6, Color(0, 0, 0, 0.7))
		draw_string(font, at, String(SYM.get(sym, "")), HORIZONTAL_ALIGNMENT_CENTER, r * 2.0, fs, Color.WHITE)
	if frozen:
		draw_arc(c, r + 1.0, 0.0, TAU, 32, Color(0.75, 0.92, 1.0), 4.0, true)
	if hot:
		draw_arc(c, r + 2.0, 0.0, TAU, 32, Color(1.0, 0.9, 0.5, 0.9), 3.0, true)


var _down := false  # (pressed and not dragged away yet: the click lands on release, so a drag is not also a click)


func _gui_input(ev: InputEvent) -> void:
	if ev is InputEventMouseButton and ev.button_index == MOUSE_BUTTON_LEFT:
		if ev.pressed:
			_down = true
		elif _down:
			_down = false
			pressed.emit()
		accept_event()


func _notification(what: int) -> void:
	if what == NOTIFICATION_DRAG_BEGIN:
		_down = false
