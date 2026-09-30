class_name FuseScreen
extends Control
## Campfire: fuse two spells into one. Pick two cards; the forged spell is shown before you commit.

signal fused(new_spell: Dictionary)
signal back

const RULES := "Fuse melts two of your spells into ONE spell that does everything both of them did.\n• Its pattern: the first spell you pick, then the whole of the second. Nothing is lost.\n• Both spells are used up, and the new one takes a single slot in your active row.\n• Fused spells can't be fused again, and Powers can't be fused."

var run: RunState
var _picked: Array = []  # ids, in the order chosen
var _preview: Dictionary = {}
var _grid: HFlowContainer
var _result_box: HBoxContainer
var _status: RichTextLabel
var _fuse_btn: Button


func setup(p_run: RunState) -> void:
	run = p_run


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = UiTheme.get_theme()
	var bd := Backdrop.new()
	bd.act = run.act
	add_child(bd)
	var shade := ColorRect.new()
	shade.color = Color(0, 0, 0, 0.55)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shade)
	var v := VBoxContainer.new()
	v.position = Vector2(50, 70)
	v.size = Vector2(1820, 1000)
	v.add_theme_constant_override("separation", 12)
	add_child(v)
	v.add_child(UiTheme.label("🔥 Fuse two spells", 38, Color(1, 0.8, 0.6)))
	var rules := RichTextLabel.new()
	rules.bbcode_enabled = true
	rules.fit_content = true
	rules.scroll_active = false
	rules.custom_minimum_size = Vector2(1100, 0)
	rules.add_theme_font_size_override("normal_font_size", 18)
	rules.add_theme_font_size_override("bold_font_size", 18)
	rules.add_theme_color_override("default_color", Color(0.9, 0.92, 0.86))
	rules.text = Keywords.colorize(RULES)
	v.add_child(rules)
	# the result, once two spells are picked
	var mid := HBoxContainer.new()
	mid.add_theme_constant_override("separation", 24)
	v.add_child(mid)
	_result_box = HBoxContainer.new()
	_result_box.add_theme_constant_override("separation", 16)
	_result_box.alignment = BoxContainer.ALIGNMENT_BEGIN
	_result_box.custom_minimum_size = Vector2(0, SpellCard.H)
	mid.add_child(_result_box)
	var side := VBoxContainer.new()
	side.add_theme_constant_override("separation", 10)
	mid.add_child(side)
	_status = RichTextLabel.new()
	_status.bbcode_enabled = true
	_status.fit_content = true
	_status.scroll_active = false
	_status.custom_minimum_size = Vector2(560, 0)
	_status.add_theme_font_size_override("normal_font_size", 19)
	_status.add_theme_font_size_override("bold_font_size", 19)
	_status.add_theme_color_override("default_color", Color(1, 0.9, 0.75))
	side.add_child(_status)
	_fuse_btn = UiTheme.button("Fuse them!", _commit, 24)
	_fuse_btn.custom_minimum_size = Vector2(260, 56)
	side.add_child(_fuse_btn)
	v.add_child(UiTheme.label("Your spells (click two):", 18, UiTheme.MUTED))
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.custom_minimum_size = Vector2(1820, 300)
	v.add_child(scroll)
	_grid = HFlowContainer.new()
	_grid.custom_minimum_size = Vector2(1800, 0)
	_grid.add_theme_constant_override("h_separation", 12)
	_grid.add_theme_constant_override("v_separation", 12)
	scroll.add_child(_grid)
	var bh := HBoxContainer.new()
	bh.position = Vector2(1500, 1000)
	add_child(bh)
	var back_btn := UiTheme.button("Back to the campfire", func(): back.emit(), 20)
	back_btn.custom_minimum_size = Vector2(300, 52)
	bh.add_child(back_btn)
	_refresh()


func _refresh() -> void:
	for c in _grid.get_children():
		c.queue_free()
	for id in run.spellbook:
		var s := run.spell(id)
		var card := SpellCard.make(s)
		var ok := run.can_fuse(id)
		card.selected = id in _picked
		if not ok:
			card.state = "used"
			card.state_text = "Can't fuse" if not s.get("fused", false) else "Already fused"
		# the rules again, right where the player is deciding
		card.set_meta("fuse_tip", "\n\n" + ("Fuse: pick this and one more spell to melt them into one." if ok else ("Powers can't be fused." if s.get("power", false) else "Fused spells can't be fused again.")))
		card.clicked.connect(func(_c): _toggle(id))
		_grid.add_child(card)
		if ok and id in _picked:
			card.modulate = Color(1.3, 1.2, 0.9)
	for c in _result_box.get_children():
		c.queue_free()
	_fuse_btn.disabled = _picked.size() < 2
	match _picked.size():
		0:
			_status.text = Keywords.colorize("Pick the first spell: its pattern goes first.")
		1:
			var a := run.spell(_picked[0])
			_status.text = Keywords.colorize("%s picked. Now pick the second spell: its pattern goes after." % a.name)
			_result_box.add_child(SpellCard.make(a))
		2:
			var a := run.spell(_picked[0])
			var b := run.spell(_picked[1])
			_result_box.add_child(SpellCard.make(a))
			_result_box.add_child(UiTheme.label("+", 48, Color.WHITE))
			_result_box.add_child(SpellCard.make(b))
			_result_box.add_child(UiTheme.label("→", 48, Color(1, 0.8, 0.4)))
			var out := SpellCard.make(_preview)
			_result_box.add_child(out)
			_status.text = ""


func _toggle(id: String) -> void:
	if not run.can_fuse(id):
		return
	if id in _picked:
		_picked.erase(id)
	elif _picked.size() < 2:
		_picked.append(id)
	else:
		_picked[1] = id
	_preview = run.fuse_preview(_picked[0], _picked[1]) if _picked.size() == 2 else {}
	_refresh.call_deferred()


func _commit() -> void:
	if _picked.size() < 2 or _preview.is_empty():
		return
	run.fuse_commit(_preview, _picked[0], _picked[1])
	fused.emit(_preview)
