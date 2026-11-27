class_name TicketBar
extends Control
## Your tickets (see Tickets), top left during the whole run, over every screen: Tickets.SLOTS places, a faint
## outline each (the user's rule for slots: no painted box), your tickets in them. Click a ticket: it lifts and two
## buttons show under it, Use and Throw away (as in Balatro); click it again, or elsewhere, and they go. Use is greyed
## out where the ticket does not work (its hover says where it does). Main gives the callables.

const H := 58.0  # a ticket's height here
const GAP := 12.0

var get_run: Callable  # () -> RunState, or null
var get_where: Callable  # () -> "fight" / "shop" / "event" / "map" / "" (busy: nothing can be used now)
var on_use: Callable  # (slot: int, view: TicketView) -> void
var _shown := "?"
var _views: Array = []
var _menu: Control
var _sel := -1


func _ready() -> void:
	position = Vector2(24, 112)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	theme = UiTheme.get_theme()
	set_process(true)


func _process(_dt: float) -> void:
	var r: RunState = get_run.call() if get_run.is_valid() else null
	var key := "" if r == null else ",".join(r.tickets) + ("|D" if r.discount_ready else "")
	if key != _shown:
		_shown = key
		_rebuild(r)
	if _menu != null and is_instance_valid(_menu):
		_update_menu()


func _rebuild(r: RunState) -> void:
	for c in get_children():
		c.queue_free()
	_views.clear()
	_menu = null
	_sel = -1
	if r == null:
		return
	var w := H * TicketView.RATIO
	for i in Tickets.SLOTS:
		var at := Vector2(i * (w + GAP), 0)
		var outline := Control.new()  # (an empty slot: a faint outline of a ticket)
		outline.position = at
		outline.size = Vector2(w, H)
		outline.mouse_filter = Control.MOUSE_FILTER_IGNORE
		outline.draw.connect(func():
			outline.draw_polyline(_closed(TicketView._ticket_shape(Rect2(Vector2.ZERO, outline.size), H * 0.16, H * 0.07)), Color(1, 1, 1, 0.22), 1.5, true))
		add_child(outline)
		if i < r.tickets.size():
			var tv := TicketView.make(String(r.tickets[i]), H)
			tv.slot = i
			tv.position = at
			tv.pressed.connect(_on_pressed)
			add_child(tv)
			_views.append(tv)
	if r.discount_ready:  # (a Discount waits for the next price: a little % next to the slots)
		var d := UiTheme.label("% ready", 18, Color(1.0, 0.85, 0.4))
		d.position = Vector2(Tickets.SLOTS * (w + GAP), H * 0.3)
		d.add_theme_constant_override("outline_size", 5)
		d.add_theme_color_override("font_outline_color", Color(0.15, 0.05, 0.02))
		d.tooltip_text = "A Ticket of Discount: the next price (the shop, or an event) is cut."
		d.mouse_filter = Control.MOUSE_FILTER_STOP
		add_child(d)


static func _closed(p: PackedVector2Array) -> PackedVector2Array:
	var q := p.duplicate()
	q.append(p[0])
	return q


func _on_pressed(tv: TicketView) -> void:
	Audio.play("ui_click", -6.0)
	var was := _sel
	close_menu()
	if was == tv.slot:
		return
	_sel = tv.slot
	tv.set_selected(true)
	var r: RunState = get_run.call()
	var id := String(r.tickets[tv.slot])
	_menu = VBoxContainer.new()
	_menu.add_theme_constant_override("separation", 4)
	_menu.position = tv.position + Vector2(0, H + 2.0)
	_menu.z_index = 5
	var use := UiTheme.button("Use", func():
		var s := _sel
		var v := tv
		close_menu()
		on_use.call(s, v), 17)
	use.name = "Use"
	use.custom_minimum_size = Vector2(tv.size.x, 34)
	_menu.add_child(use)
	var drop := UiTheme.button("Throw away", func():
		var s := _sel
		close_menu()
		Audio.play("ui_click", -4.0)
		(get_run.call() as RunState).discard_ticket(s), 15)
	drop.custom_minimum_size = Vector2(tv.size.x, 30)
	drop.tooltip_text = "Throw this ticket away (to make room for another)."
	_menu.add_child(drop)
	add_child(_menu)
	_menu.set_meta("id", id)
	_update_menu()


## Use is greyed out where the ticket does not work, or while something else is going on.
func _update_menu() -> void:
	var use: Button = _menu.get_node_or_null("Use")
	if use == null:
		return
	var where: String = get_where.call() if get_where.is_valid() else "map"
	var id := String(_menu.get_meta("id"))
	var ok := where != "" and Tickets.usable_in(id, where)
	use.disabled = not ok
	use.tooltip_text = "" if ok else ("Not now." if where == "" else String(Tickets.USE_WORDS.get(String(Tickets.get_def(id).use), "Not here.")))


func close_menu() -> void:
	if _menu != null and is_instance_valid(_menu):
		_menu.queue_free()
	_menu = null
	if _sel >= 0:
		for v in _views:
			if is_instance_valid(v) and v.slot == _sel and v.selected:
				v.set_selected(false)
	_sel = -1


func _input(ev: InputEvent) -> void:
	# a click anywhere else closes the buttons
	if _menu == null or not is_instance_valid(_menu) or not (ev is InputEventMouseButton) or not ev.pressed:
		return
	var p: Vector2 = ev.position
	if _menu.get_global_rect().has_point(p):
		return
	for v in _views:
		if is_instance_valid(v) and v.get_global_rect().has_point(p):
			return
	close_menu()
