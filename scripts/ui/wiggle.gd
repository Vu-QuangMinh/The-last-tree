class_name Wiggle
extends Node
## Something you can choose (a reward card, a marble, a ticket) looks alive (the user, 2026-11-27): it sways and bobs
## gently, each with its own rhythm; under the mouse it wiggles harder, grows a little and is highlighted (a warm
## golden glow opens behind it, a bright rim round it, and it brightens). Attach it:
##   Wiggle.attach(card)            (hover read from the card itself)
##   Wiggle.attach(view, cell)      (hover read from another Control, e.g. the cell around it)
## A SpellCard's magnified hover copy (what shows while the mouse is on it) wiggles and glows instead.

const IDLE_DEG := 2.0  # sway when idle (degrees)
const HOVER_DEG := 3.5  # sway under the mouse (calmer, 2026-11-27: it shook too much)
const IDLE_SPEED := 2.3
const HOVER_SPEED := 4.5
const GLOW := Color(1.0, 0.85, 0.4)

var target: Control
var _t := 0.0
var _hot := 0.0  # 0 idle .. 1 hovered (eased)
var _over := false
var _phase := 0.0  # (the swing's own clock: it runs faster under the mouse but never jumps)
var _halo: Control
var _zoom_halo: Control


static func attach(c: Control, hover_from: Control = null) -> Wiggle:
	var w := Wiggle.new()
	w.target = c
	w._phase = randf() * TAU
	c.add_child(w)
	var src: Control = hover_from if hover_from != null else c
	src.mouse_entered.connect(func(): w._over = true)
	src.mouse_exited.connect(func(): w._over = false)
	w._halo = w._make_halo(c)
	return w


## The highlight: a soft glow behind the thing, a bright rim, both as strong as the hover.
func _make_halo(c: Control) -> Control:
	var h := Control.new()
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	h.draw.connect(func():
		if _hot <= 0.01:
			return
		var r := Rect2(-h.position, c.size)  # (the whole thing, even when a container fits this inside its margins)
		var round_thing := not (c is SpellCard or c is PanelContainer or c is TicketView) and absf(r.size.x - r.size.y) < 4.0  # (a marble: a round outline)
		var corner := minf(r.size.x, r.size.y) * 0.5 if round_thing else 6.0  # (a card: its own square corners, so the outline sits on its edge)
		for k in 5:  # (the glow: soft rings OUTSIDE its edge, wider and fainter: drawn over it, they never cover it)
			var g := 6.0 + k * 9.0
			var sb := StyleBoxFlat.new()
			sb.draw_center = false
			sb.border_color = Color(GLOW, 0.2 * _hot * (1.0 - k * 0.17))
			sb.set_border_width_all(int(g))
			sb.set_corner_radius_all(int(corner + g))
			h.draw_style_box(sb, r.grow(g))
		var rim := StyleBoxFlat.new()  # (the inner outline: right on the card's edge)
		rim.draw_center = false
		rim.border_color = Color(1.0, 0.95, 0.7, 0.9 * _hot)
		rim.set_border_width_all(3)
		rim.set_corner_radius_all(int(corner))
		h.draw_style_box(rim, r))
	c.add_child(h)
	return h


func _process(dt: float) -> void:
	if not is_instance_valid(target):
		return
	_t += dt
	var was := _hot
	_hot = move_toward(_hot, 1.0 if _over else 0.0, dt * 6.0)
	var amp := deg_to_rad(lerpf(IDLE_DEG, HOVER_DEG, _hot))
	var speed := lerpf(IDLE_SPEED, HOVER_SPEED, _hot)
	_phase += dt * speed  # (advanced, not t * speed: changing the speed then never makes the swing jump)
	var rot := sin(_phase) * amp
	var bob := 1.0 + 0.015 * sin(_t * IDLE_SPEED * 0.7) + 0.05 * _hot
	target.pivot_offset = target.size / 2.0
	target.rotation = rot
	target.scale = Vector2.ONE * bob
	target.self_modulate = Color.WHITE.lerp(Color(1.25, 1.2, 1.05), _hot)  # (it brightens: its own picture or frame, not its children)
	if was != _hot or _hot > 0.0:
		_halo.queue_redraw()
	if target is SpellCard:  # (its magnified copy shows while the mouse is on it: it wiggles and glows instead)
		var z = (target as SpellCard).get("_zoom")
		if z != null and is_instance_valid(z):
			var zc := z as Control
			zc.pivot_offset = zc.size / 2.0
			zc.rotation = rot
			if _zoom_halo == null or not is_instance_valid(_zoom_halo) or _zoom_halo.get_parent() != zc:
				_zoom_halo = _make_halo(zc)
			_zoom_halo.queue_redraw()
