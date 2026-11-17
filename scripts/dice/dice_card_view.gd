class_name DiceCardView
extends Control
## Die on Stage: a card. Its title on a band at the top, the dice slot(s) in the middle (a dashed, hatched square; its
## rule written in it: MIN 5, MAX 3, ODD, SAME), what it does at the bottom, and "Repeatable" under that when it is.
## Drop a die on a slot (click a die in a half-full card to take it back). A card that fired and isn't repeatable is
## greyed out.

signal slot_dropped(ci: int, k: int, r: int)
signal slot_clicked(ci: int, k: int)

const W := 240.0
const H := 290.0
const SLOT := 92.0
const COLORS := {"attack": Color(0.93, 0.5, 0.16), "defense": Color(0.2, 0.5, 0.85), "special": Color(0.55, 0.32, 0.78)}

var id := ""
var def: Dictionary = {}  # (a card that isn't in DiceCards.CARDS: Good Ol' Wizard's spells)
var ci := -1  # its index in DiceRun.cards
var filled: Array = []  # what is in its slots now (null = empty)
var faces: Array = []  # the dice in its slots, as rolled ({paint, carve}...; {} = empty): their colour and carving
var spent := false
var glow := false  # ready, waiting for its target: a gold rim
var state := ""  # written across it: "SILENCED", "BROKEN" (the Hammer), "🔨 1/3"
var accept: Callable  # (r, k) -> bool: can that die go in that slot (DiceFight.can_place)
var hover_k := -1


func _ready() -> void:
	custom_minimum_size = Vector2(W, H)
	size = custom_minimum_size


func _card() -> Dictionary:
	return def if not def.is_empty() else DiceCards.get_card(id)


## Rejected: a die that doesn't fit bounces off (a shake from side to side and the error sound).
func shake() -> void:
	Audio.play("release_armour_block", -2.0)
	var home := position
	var tw := create_tween()
	for k in 6:
		tw.tween_property(self, "position", home + Vector2(14.0 if k % 2 == 0 else -14.0, 0), 0.04)
	tw.tween_property(self, "position", home, 0.05)


func _slots() -> int:
	return int(_card().get("slots", 1))


## The slots side by side (smaller when there are three); a "same" / "gte" move has a sign between them.
func slot_rect(k: int) -> Rect2:
	var n := _slots()
	var gap := 30.0 if _between() != "" else 14.0
	var sz := minf(SLOT, (W - 28.0 - (n - 1) * gap) / n)
	var total := n * sz + (n - 1) * gap
	return Rect2(Vector2((W - total) / 2.0 + k * (sz + gap), 62.0 + (SLOT - sz) / 2.0), Vector2(sz, sz))


## The sign written between the slots: "=" (all the same), "≥" (the first at least the second), or "".
func _between() -> String:
	match String(_card().get("rule", "")):
		"same":
			return "="
		"gte":
			return "≥"
		"gt":
			return ">"
	return ""


## How many of the slots the sign joins (an upgrade's extra slot stands apart, any die).
func _joined() -> int:
	var c := _card()
	return _slots() - (1 if c.get("plain_extra", false) or c.get("per_die", false) else 0)


func _slot_at(p: Vector2) -> int:
	for k in _slots():
		if slot_rect(k).grow(6.0).has_point(p):
			return k
	return -1


func _draw() -> void:
	var c := _card()
	var col: Color = COLORS.get(String(c.get("kind", "attack")), COLORS.attack)
	if spent:
		col = col.lerp(Color(0.35, 0.33, 0.32), 0.7)
	var body := StyleBoxFlat.new()
	body.bg_color = col
	body.set_corner_radius_all(18)
	body.border_color = col.darkened(0.45)
	body.set_border_width_all(4)
	body.shadow_color = Color(0, 0, 0, 0.4)
	body.shadow_size = 6
	draw_style_box(body, Rect2(Vector2.ZERO, size))
	if glow:
		var rim := StyleBoxFlat.new()
		rim.draw_center = false
		rim.border_color = Color(1.0, 0.85, 0.3)
		rim.set_border_width_all(6)
		rim.set_corner_radius_all(20)
		draw_style_box(rim, Rect2(Vector2(-6, -6), size + Vector2(12, 12)))
	var inner := StyleBoxFlat.new()
	inner.bg_color = col.darkened(0.12)
	inner.set_corner_radius_all(12)
	draw_style_box(inner, Rect2(Vector2(10, 48), Vector2(W - 20, H - 58)))
	var font: Font = UiTheme.cut("bold") if UiTheme.cut("bold") != null else ThemeDB.fallback_font
	var title := String(c.get("name", id)).to_upper()
	var tfs := 24 if title.length() <= 12 else 19
	draw_string(font, Vector2(0, 36), title, HORIZONTAL_ALIGNMENT_CENTER, W, tfs, Color.WHITE)
	var between := _between()
	var rule := "" if between != "" else DiceCards.rule_of(c)  # (MIN / MAX / ODD: written in the slot itself)
	for k in _slots():
		if between != "" and k > 0 and k < _joined():  # (= or ≥ between the slots it joins)
			var prev := slot_rect(k - 1)
			var mid := Vector2((prev.end.x + slot_rect(k).position.x) / 2.0, prev.get_center().y)
			draw_string(font, mid + Vector2(-20, 9), between, HORIZONTAL_ALIGNMENT_CENTER, 40, 24, Color.WHITE)
		var r := slot_rect(k)
		var has: bool = k < filled.size() and filled[k] != null
		if has:
			var fc: Dictionary = faces[k] if k < faces.size() else {}
			DiceDieView.draw_die(self, r.grow(-6.0), int(filled[k]), false, String(fc.get("paint", "")), String(fc.get("carve", "")))
			continue
		var line := Color(1, 1, 1, 0.9) if k != hover_k else Color(1.0, 0.95, 0.5)
		for i in range(-8, 9):  # (the hatch: thin diagonal lines inside the slot)
			var a := r.position + Vector2(i * 12.0, 0)
			var b := a + Vector2(r.size.y, r.size.y)
			var seg := _clip(a, b, r)
			if not seg.is_empty():
				draw_line(seg[0], seg[1], Color(1, 1, 1, 0.12), 3.0)
		_dashed_rect(r, line)
		var extra: bool = (c.get("plain_extra", false) and k == _slots() - 1) or (c.get("per_die", false) and k > 0)
		if rule != "" and not extra:
			var rfs := clampi(int(18.0 * r.size.x / SLOT), 11, 18)  # (smaller in a small slot: three of them)
			draw_string(font, r.position + Vector2(0, r.size.y / 2.0 + rfs * 0.45), rule, HORIZONTAL_ALIGNMENT_CENTER, r.size.x, rfs, Color.WHITE)
	var words := DiceCards.text_of(c, filled)
	var lines := _wrap(font, words, W - 32, 19)
	var y := 62.0 + SLOT + 34.0
	for ln in lines:
		draw_string(font, Vector2(16, y), ln, HORIZONTAL_ALIGNMENT_CENTER, W - 32, 19, Color.WHITE)
		y += 24.0
	if state != "":
		var band := Rect2(Vector2(0, H * 0.42), Vector2(W, 40))
		draw_rect(band, Color(0.1, 0.06, 0.12, 0.85))
		draw_string(font, band.position + Vector2(0, 28), state, HORIZONTAL_ALIGNMENT_CENTER, W, 22, Color(1.0, 0.8, 0.95))
	if bool(c.get("repeatable", false)):
		draw_string(font, Vector2(0, H - 16), "REPEATABLE", HORIZONTAL_ALIGNMENT_CENTER, W, 15, Color(1, 1, 1, 0.75))


func _dashed_rect(r: Rect2, col: Color) -> void:
	var pts := [r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y), r.position]
	for i in 4:
		draw_dashed_line(pts[i], pts[i + 1], col, 3.0, 9.0)


## The part of segment a-b inside rect r (for the hatch), or [] when none.
func _clip(a: Vector2, b: Vector2, r: Rect2) -> Array:
	var t0 := 0.0
	var t1 := 1.0
	var d := b - a
	for axis in 2:
		var lo: float = r.position[axis]
		var hi: float = r.end[axis]
		if absf(d[axis]) < 0.0001:
			if a[axis] < lo or a[axis] > hi:
				return []
			continue
		var ta: float = (lo - a[axis]) / d[axis]
		var tb: float = (hi - a[axis]) / d[axis]
		t0 = maxf(t0, minf(ta, tb))
		t1 = minf(t1, maxf(ta, tb))
	if t0 >= t1:
		return []
	return [a + d * t0, a + d * t1]


func _wrap(font: Font, s: String, w: float, fs: int) -> Array:
	var out := []
	var cur := ""
	for word in s.split(" "):
		var t := word if cur == "" else cur + " " + word
		if font.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x > w and cur != "":
			out.append(cur)
			cur = word
		else:
			cur = t
	if cur != "":
		out.append(cur)
	return out


func _can_drop_data(at: Vector2, data: Variant) -> bool:
	var k := _slot_at(at)
	var ok: bool = k >= 0 and data is Dictionary and data.has("die") and not spent and accept.is_valid() and bool(accept.call(int(data.die), k))
	if hover_k != (k if ok else -1):
		hover_k = k if ok else -1
		queue_redraw()
	return ok


func _drop_data(at: Vector2, data: Variant) -> void:
	hover_k = -1
	queue_redraw()
	slot_dropped.emit(ci, _slot_at(at), int(data.die))


func _notification(what: int) -> void:
	if what == NOTIFICATION_DRAG_END or what == NOTIFICATION_MOUSE_EXIT:
		if hover_k != -1:
			hover_k = -1
			queue_redraw()


func _gui_input(ev: InputEvent) -> void:
	if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
		var k := _slot_at(ev.position)
		if k >= 0:
			slot_clicked.emit(ci, k)
