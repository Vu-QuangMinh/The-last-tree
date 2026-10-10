class_name BottleChip
extends PanelContainer
## One bottle you carry: just the bottle (hover for what it does), in a faint outline of its square like the
## artifacts. In a fight you click it on your turn to drink it. An empty slot shows a faint flask outline.

signal used(chip: BottleChip)

var id := ""  # "" = an empty slot
var index := -1
var clickable := false
var _t := 0.0
var _box: StyleBoxFlat
var px := 64.0  # the square it sits in (the run bar on the map uses a smaller one)
const FAINT := Color(1, 1, 1, 0.14)
const FAINT_HOVER := Color(1, 1, 1, 0.32)

## New theme: a bottle without a painted picture of its own is shown as the nearest of five colour bottles
const ART := {
	"bottle_orange": Color(0.94, 0.35, 0.15), "bottle_green": Color(0.27, 0.7, 0.27), "bottle_purple": Color(0.7, 0.35, 0.65),
	"bottle_gray": Color(0.72, 0.7, 0.68), "bottle_blue": Color(0.3, 0.55, 0.8),
}


static func make(p_id: String, p_index := -1, p_clickable := false, p_px := 64.0) -> BottleChip:
	var c := BottleChip.new()
	c.id = p_id
	c.index = p_index
	c.clickable = p_clickable
	c.px = p_px
	return c


func _ready() -> void:
	custom_minimum_size = Vector2(px, px)
	# no box: just a soft, faint outline of the square it sits in (a touch brighter under the mouse)
	_box = StyleBoxFlat.new()
	_box.bg_color = Color(0, 0, 0, 0)
	var idle := Color(1, 1, 1, 0.0) if UiSkin.is_new() else FAINT  # (painted themes: no outline at all)
	var hover := Color(1, 1, 1, 0.0) if UiSkin.is_new() else FAINT_HOVER
	_box.border_color = idle
	_box.set_border_width_all(1)
	_box.set_corner_radius_all(10)
	_box.anti_aliasing = true
	add_theme_stylebox_override("panel", _box)
	if id == "":
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		tooltip_text = ""
		return
	var b := Bottles.get_def(id)
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if clickable else Control.CURSOR_ARROW
	var how := "Click it on your turn to drink it. It's gone once used." if clickable else "Drink it during a fight (click it on your turn)."
	tooltip_text = Keywords.tooltip(b.get("name", id), b.get("desc", ""), "[color=#9aa89a]Bottle · %d Amber · %s[/color]" % [b.get("price", 0), how], UiSkin.inline(id, b.get("icon", ""), 28))
	mouse_entered.connect(func(): _box.border_color = hover)
	mouse_exited.connect(func(): _box.border_color = idle)


func _art_name() -> String:
	if UiSkin.tex(id) != null:
		return id  # its own painted bottle (assets/ui/new/<id>.png)
	var col: Color = Bottles.get_def(id).get("color", Color.WHITE)
	var best := "bottle_gray"
	var best_d := 9.0
	for k in ART:
		var d := Vector2(col.r - ART[k].r, col.g - ART[k].g).length_squared() + pow(col.b - ART[k].b, 2)
		if d < best_d:
			best_d = d
			best = k
	return best


## A little glass flask: a round body with its liquid (the bottle's colour, gently sloshing), a neck, a cork,
## a glint on the glass, and its symbol small in the liquid.
func _draw() -> void:
	if id != "" and UiSkin.tex(_art_name()) != null:
		# New theme: the painted bottle, filling most of its square (bobbing gently when you can drink it)
		var bob := sin(_t * 2.4) * 1.5 if clickable else 0.0
		UiSkin.draw_fit(self, _art_name(), size / 2.0 + Vector2(0, bob), minf(size.x, size.y) * 0.86)
		return
	if id == "":
		# an empty slot: a faint flask outline
		var c0 := Vector2(size.x / 2.0, size.y * 0.62)
		draw_arc(c0, size.y * 0.27, 0, TAU, 24, Color(0.6, 0.85, 0.9, 0.25), 1.5)
		draw_rect(Rect2(c0.x - 4, size.y * 0.14, 8, size.y * 0.22), Color(0.6, 0.85, 0.9, 0.25), false, 1.5)
		return
	var b := Bottles.get_def(id)
	var col: Color = b.get("color", Color(0.6, 0.9, 1.0))
	var r := size.y * 0.28
	var c := Vector2(size.x / 2.0, size.y * 0.62)
	# glass body and neck
	draw_circle(c, r + 1.5, Color(0.85, 0.95, 1.0, 0.55))
	draw_circle(c, r, Color(0.1, 0.14, 0.18, 0.9))
	draw_rect(Rect2(c.x - r * 0.32, c.y - r * 1.75, r * 0.64, r * 0.9), Color(0.85, 0.95, 1.0, 0.55))
	draw_rect(Rect2(c.x - r * 0.22, c.y - r * 1.7, r * 0.44, r * 0.9), Color(0.1, 0.14, 0.18, 0.9))
	# cork
	draw_rect(Rect2(c.x - r * 0.3, c.y - r * 2.05, r * 0.6, r * 0.4), Color(0.7, 0.5, 0.3))
	# the liquid: a circle's lower part, its surface sloshing a little
	var level := -r * 0.25 + sin(_t * 2.6) * r * 0.06
	var pts := PackedVector2Array()
	var steps := 18
	var a0 := asin(clampf(level / r, -1.0, 1.0))
	for k in steps + 1:
		var a := lerpf(a0, PI - a0, float(k) / steps)
		pts.append(c + Vector2(cos(a), sin(a)) * (r - 1.5))
	if pts.size() >= 3:
		draw_colored_polygon(pts, col)
	draw_circle(c + Vector2(0, r * 0.25), r * 0.55, Color(col.lightened(0.35), 0.35))
	# glint
	draw_arc(c, r * 0.72, -2.5, -1.7, 8, Color(1, 1, 1, 0.7), 2.0)
	# its symbol, small, in the liquid
	var f := get_theme_default_font()
	var sym: String = b.get("icon", "")
	var fs := int(r * 0.95)
	var w := f.get_string_size(sym, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	draw_string(f, c + Vector2(-w / 2.0, r * 0.42), sym, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color.WHITE)


func _process(d: float) -> void:
	if id == "":
		return
	_t += d
	queue_redraw()


func _gui_input(ev: InputEvent) -> void:
	if clickable and id != "" and ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
		used.emit(self)
		accept_event()


func _make_custom_tooltip(for_text: String) -> Object:
	if for_text.strip_edges() == "":
		return null
	return Keywords.make_tooltip(for_text)
