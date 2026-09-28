class_name FightScreen
extends Control
## The encounter: enemies across the top, your spells, the chant line, your stock of elements.
## A turn: build a chant (F / W / A, Backspace) and speak it (Enter). Every spell it matched comes alive:
## click living spells to cast them in any order; targeted ones pull out an arrow (click an enemy, Tab + Enter,
## or right-click / Esc to put it back). Spells can change the chant, which can wake more spells.
## When nothing is left to cast, the chant is Released by itself: its elements fly at the enemies one by one,
## left to right, and then the enemies act. E Releases early (or passes, before you chant).

signal finished(won: bool)
## The player abandoned the run from the pause menu.
signal menu_requested
## For the tutorial: what just happened ("chant_changed", "chanted", "cast", "picked", "placed", "turn_start").
signal tut(kind: String, data)
signal _aim_done(idx: int)
signal _move_done(pair: Array)
signal _pick_done(idx: int)
signal _chant_done(idx: int)

var run: RunState
## The tutorial's gate: func(action: String, arg) -> bool. Actions: add (el), remove, clear, chant, cast (spell id),
## target (enemy index), cancel, pick (HP index), place (chant gap), release, pass. By default everything is allowed.
var gate: Callable = func(_a, _b): return true
## When nothing is left to cast, Release by itself (the tutorial turns this off so the player presses Release).
var auto_release := true
var fight: Fight
var chant_idx: Array = []  # stock indices in chant order
var phase := "build"  # build: making the chant · spells: the chant is spoken, spells are alive
var chant_mode := ""  # "insert": placing an infused element · "pick": choosing a chant element to copy
var chant_i := 0  # the gap / element highlighted in chant_mode
var _step_pos := -1  # during the Release: the chant element flying right now
var busy := false
var end_confirm := false
# aiming (the arrow)
var aiming := false
var aim_from := Vector2.ZERO
var aim_cands: Array = []
var aim_i := 0
var aim_cancellable := true
var aim_card: SpellCard
# moving an element
var move_view: EnemyView
var pick_view: EnemyView  # choosing which element a Pluck removes

var _backdrop: Backdrop
var _enemy_row: HBoxContainer
var _views := {}  # EnemyState -> EnemyView
var _spell_row: HBoxContainer
var _cards: Array = []
var _chant_row: HBoxContainer
var _chant_note: Label
var _stock_row: HFlowContainer
var _next_row: HBoxContainer
var _prompt: Label
var _info: Label
var _hp_bar: ProgressBar
var _hp_label: Label
var _pstatus: RichTextLabel
var _log: Label
var _cast_btn: Button
var _end_btn: Button
var _clear_btn: Button
var _fx: Control
var _arrow: Control
var _player_panel: PanelContainer
var _pause_overlay: Control

## op -> sfx name, for the generic {"type": "effect", "op": ...} events fired by every spell effect.
## Ops that already play their own sound elsewhere (strike-via-pluck, move, infuse/duplicate via
## "chant_changed", summon_spells via "loadout_changed") are left out so they don't double up.
const EFFECT_SFX := {
	"strike": "sfx_damage_hit", "burn": "sfx_burn_apply", "poison": "sfx_poison_apply",
	"stoke": "sfx_burn_apply", "weak": "sfx_weaken_apply", "freeze": "sfx_freeze_apply",
	"expose": "sfx_expose_apply", "ethereal": "sfx_ethereal_apply", "shield": "sfx_shield_up",
	"heal": "sfx_heal", "aegis": "sfx_aegis_up", "thorns": "sfx_shield_up", "draw": "sfx_draw_element",
	"rotate": "sfx_convert", "swap": "sfx_convert", "convert": "sfx_convert", "purge": "sfx_purge",
	"shatter": "sfx_lock_break", "insert": "sfx_mend", "siphon": "sfx_purge", "execute": "sfx_execute",
	"transmute": "sfx_convert", "sacrifice": "sfx_player_hit", "amplify": "sfx_amplify",
	"overload": "sfx_overload", "cleanse": "sfx_cleanse", "redirect": "sfx_redirect", "passive": "spell_glow",
	"curse": "sfx_weaken_apply",
}
## Element letter -> sfx name, comet leaving the chant (a whoosh) and comet landing on an enemy (an impact).
const LAUNCH_SFX := {"F": "element_fire", "W": "element_water", "A": "element_wind"}
const IMPACT_SFX := {"F": "fire", "W": "water", "A": "air"}


func setup(p_run: RunState, p_fight: Fight) -> void:
	run = p_run
	fight = p_fight
	fight.chooser = _choose_target
	fight.mover = _mover
	fight.picker = _picker
	fight.placer = _placer
	fight.chant_picker = _chant_picker
	fight.redirector = _redirector
	fight.anim = _anim


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = UiTheme.get_theme()
	_backdrop = Backdrop.new()
	_backdrop.act = run.act
	_backdrop.tree_glow = false
	add_child(_backdrop)
	_info = UiTheme.label("", 22, Color.WHITE)
	_info.position = Vector2(30, 20)
	add_child(_info)
	# top-right: coming next
	var np := PanelContainer.new()
	np.add_theme_stylebox_override("panel", UiTheme.panel_box(0.85, 10))
	np.position = Vector2(1560, 16)
	np.custom_minimum_size = Vector2(330, 0)
	var nv := VBoxContainer.new()
	np.add_child(nv)
	nv.add_child(UiTheme.label("Coming next turn", 16, UiTheme.MUTED))
	_next_row = HBoxContainer.new()
	_next_row.add_theme_constant_override("separation", 4)
	nv.add_child(_next_row)
	add_child(np)
	# enemies
	_enemy_row = HBoxContainer.new()
	_enemy_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_enemy_row.add_theme_constant_override("separation", 20)
	_enemy_row.position = Vector2(0, 40)
	_enemy_row.size = Vector2(1920, 480)
	add_child(_enemy_row)
	_prompt = UiTheme.label("", 22, Color(1, 0.9, 0.5))
	_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_prompt.position = Vector2(0, 492)
	_prompt.size = Vector2(1920, 32)
	_prompt.add_theme_constant_override("outline_size", 6)
	_prompt.add_theme_color_override("font_outline_color", Color.BLACK)
	add_child(_prompt)
	# spells
	_spell_row = HBoxContainer.new()
	_spell_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_spell_row.add_theme_constant_override("separation", 10)
	_spell_row.position = Vector2(0, 530)
	_spell_row.size = Vector2(1920, 170)
	add_child(_spell_row)
	# chant area: the slots, and the Chant / Release button right beside them
	var cp := PanelContainer.new()
	cp.add_theme_stylebox_override("panel", UiTheme.panel_box(0.9, 14))
	cp.position = Vector2(540, 742)
	cp.custom_minimum_size = Vector2(1100, 118)
	var chh := HBoxContainer.new()
	chh.add_theme_constant_override("separation", 14)
	cp.add_child(chh)
	var cv := VBoxContainer.new()
	cv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	chh.add_child(cv)
	var ch := HBoxContainer.new()
	cv.add_child(ch)
	var cl := UiTheme.label("Chant", 18, UiTheme.ACCENT)
	cl.custom_minimum_size = Vector2(70, 0)
	ch.add_child(cl)
	_chant_row = HBoxContainer.new()
	_chant_row.add_theme_constant_override("separation", 6)
	ch.add_child(_chant_row)
	_chant_note = UiTheme.label("", 14, UiTheme.MUTED)
	cv.add_child(_chant_note)
	var bv := VBoxContainer.new()
	bv.add_theme_constant_override("separation", 6)
	chh.add_child(bv)
	_cast_btn = UiTheme.button("Chant  (Enter)", _on_primary, 22)
	_cast_btn.custom_minimum_size = Vector2(250, 60)
	bv.add_child(_cast_btn)
	var small := HBoxContainer.new()
	small.add_theme_constant_override("separation", 6)
	bv.add_child(small)
	_clear_btn = UiTheme.button("Clear  (⌫)", _clear_chant, 15)
	_clear_btn.custom_minimum_size = Vector2(122, 34)
	small.add_child(_clear_btn)
	_end_btn = UiTheme.button("Pass  (E)", _on_end_turn, 15)
	_end_btn.custom_minimum_size = Vector2(122, 34)
	_end_btn.tooltip_text = "End your turn without chanting (you keep your elements)."
	small.add_child(_end_btn)
	add_child(cp)
	# stock
	var sp := PanelContainer.new()
	sp.add_theme_stylebox_override("panel", UiTheme.panel_box(0.8, 12))
	sp.position = Vector2(540, 872)
	sp.custom_minimum_size = Vector2(1100, 110)
	var sv := VBoxContainer.new()
	sp.add_child(sv)
	sv.add_child(UiTheme.label("Your elements  (click, or press F / W / A)", 15, UiTheme.MUTED))
	_stock_row = HFlowContainer.new()
	_stock_row.add_theme_constant_override("h_separation", 6)
	_stock_row.custom_minimum_size = Vector2(1070, 0)
	sv.add_child(_stock_row)
	add_child(sp)
	# player
	_player_panel = PanelContainer.new()
	_player_panel.add_theme_stylebox_override("panel", UiTheme.panel_box(0.9, 12))
	_player_panel.position = Vector2(24, 760)
	_player_panel.custom_minimum_size = Vector2(500, 0)
	var pv := VBoxContainer.new()
	_player_panel.add_child(pv)
	pv.add_child(UiTheme.label("The Keeper", 22, Color.WHITE))
	_hp_bar = ProgressBar.new()
	_hp_bar.custom_minimum_size = Vector2(460, 26)
	_hp_bar.show_percentage = false
	var fill := StyleBoxFlat.new()
	fill.bg_color = Color(0.75, 0.2, 0.2)
	fill.set_corner_radius_all(6)
	_hp_bar.add_theme_stylebox_override("fill", fill)
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.15, 0.08, 0.08)
	bg.set_corner_radius_all(6)
	_hp_bar.add_theme_stylebox_override("background", bg)
	pv.add_child(_hp_bar)
	_hp_label = UiTheme.label("", 18)
	pv.add_child(_hp_label)
	_pstatus = RichTextLabel.new()
	_pstatus.bbcode_enabled = true
	_pstatus.fit_content = true
	_pstatus.scroll_active = false
	_pstatus.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_pstatus.custom_minimum_size = Vector2(460, 0)
	_pstatus.add_theme_font_size_override("normal_font_size", 15)
	_pstatus.add_theme_font_size_override("bold_font_size", 15)
	_pstatus.add_theme_color_override("default_color", Color(0.85, 0.8, 1))
	pv.add_child(_pstatus)
	add_child(_player_panel)
	# the fight log, bottom right
	_log = UiTheme.label("", 14, UiTheme.MUTED)
	_log.position = Vector2(1660, 742)
	_log.size = Vector2(245, 240)
	_log.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_log.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	add_child(_log)
	_fx = Control.new()
	_fx.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_fx.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_fx)
	_arrow = Control.new()
	_arrow.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_arrow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_arrow.z_index = 50
	_arrow.draw.connect(_draw_arrow)
	add_child(_arrow)
	var menu_btn := UiTheme.button("☰ Menu", _open_pause_menu, 18)
	menu_btn.custom_minimum_size = Vector2(130, 44)
	menu_btn.position = Vector2(1920 - 150, 1024)
	add_child(menu_btn)
	_build_spells()
	_sync_views()
	_refresh_all()


# ------------------------------------------------------------------ building

func _build_spells() -> void:
	for c in _spell_row.get_children():
		c.queue_free()
	_cards.clear()
	for s in fight.loadout:
		var card := SpellCard.make(s)
		card.clicked.connect(_on_card_clicked)
		_spell_row.add_child(card)
		_cards.append(card)


func _sync_views() -> void:
	var live := fight.enemies.filter(func(e): return not e.is_dead())
	var same := live.size() == _views.size() and live.all(func(e): return _views.has(e))
	if same:
		for i in live.size():
			_enemy_row.move_child(_views[live[i]], i)
		return
	for c in _enemy_row.get_children():
		_enemy_row.remove_child(c)
		c.queue_free()
	_views.clear()
	for e in live:
		var v := EnemyView.new()
		v.setup(e, fight)
		v.clicked.connect(_on_enemy_clicked)
		v.hp_clicked.connect(_on_hp_clicked)
		_enemy_row.add_child(v)
		_views[e] = v


func _chant_string() -> String:
	var s := ""
	for i in chant_idx:
		s += fight.player.stock[i].el
	return s


func _refresh_all() -> void:
	var p := fight.player
	_info.text = "Act %d · Floor %d · Turn %d" % [run.act, run.floor_no(), fight.turn]
	_hp_bar.max_value = p.max_hp
	_hp_bar.value = maxf(0, p.hp)
	_hp_label.text = "HP %d / %d%s%s" % [maxf(0, p.hp), p.max_hp, ("   🛡 Shield %d" % p.shield) if p.shield > 0 else "", ("   Aegis %d" % p.aegis) if p.aegis > 0 else ""]
	var st := p.describe_statuses().filter(func(s): return not s.begins_with("Shield") and not s.begins_with("Aegis"))
	if "kindling_stone" in fight.artifacts:
		st.append("Kindling Stone: CHARGED (next Burn doubled)" if p.kindling_charged else "Kindling Stone: %d / 3 chants" % p.kindling_chants)
	_pstatus.text = Keywords.colorize("\n".join(st))
	for c in _next_row.get_children():
		c.queue_free()
	for d in p.next_draw:
		var ic := ElementIcon.make(d.el, 44)
		ic.temp = d.temp
		_next_row.add_child(ic)
	_refresh_chant()
	_refresh_stock()
	var chant := _chant_string()
	var pv := {}
	if p.confuse_turns <= 0:
		if phase == "build" and chant != "":
			pv = fight.preview(chant)
		elif phase == "spells" and _step_pos < 0:
			pv = fight.preview(fight.chant_string(), false)
	for e in _views:
		var v: EnemyView = _views[e]
		var idx := fight.enemies.find(e)
		v.targetable = aiming and idx in aim_cands
		v.targeted = aiming and aim_cands.size() > 0 and idx == aim_cands[aim_i]
		v.refresh(pv)
	for card in _cards:
		var s: Dictionary = card.spell
		card.state = ""
		card.state_text = ""
		if p.used_powers.has(s.id):
			card.state = "used"
			card.state_text = "Power in effect"
		elif p.silenced.has(s.id):
			card.state = "silenced"
			card.state_text = "SILENCED\n%d turn%s" % [p.silenced[s.id], "" if p.silenced[s.id] == 1 else "s"]
		elif p.locks.has(s.id):
			card.state = "locked"
			card.lock_pattern = p.locks[s.id]
		card.fires = pv.get("spells", {}).get(s.id, 0) if phase == "build" else 0
		card.charges = fight.charges.get(s.id, 0) if phase == "spells" else 0
		card.aiming = aiming and card == aim_card
		card.refresh()
	_log.text = "\n".join(fight.lines.slice(maxi(0, fight.lines.size() - 5)))
	# one main button: Chant while you build, then Release once the chant is spoken
	_clear_btn.visible = phase == "build"
	_end_btn.visible = phase == "build"
	_end_btn.disabled = busy
	if phase == "build":
		_cast_btn.text = "Chant  (Enter)"
		_cast_btn.disabled = busy or chant_idx.is_empty()
	else:
		_cast_btn.text = "Release  (E)" if not end_confirm else "Fizzle & Release  (E)"
		_cast_btn.disabled = busy or aiming or move_view != null or pick_view != null or chant_mode != ""
	var live_spells := fight.charges.size() > 0 and phase == "spells"
	if not aiming and not busy and move_view == null and pick_view == null and chant_mode == "":
		if phase == "build":
			_prompt.text = "" if chant != "" else "Build a chant: when it is Released, enemies lose the longest start of their HP found in it. Matching spells come alive."
		elif live_spells:
			_prompt.text = "Your spells are alive: click them to cast, in any order."
		else:
			_prompt.text = "Nothing left to cast." if auto_release else "Nothing left to cast: press Release!"


func _refresh_chant() -> void:
	var p := fight.player
	var slots := p.chant_slots()
	if chant_idx.size() > slots:
		chant_idx.resize(slots)
	for c in _chant_row.get_children():
		c.queue_free()
	var shown: Array = []  # element letters to draw
	if phase == "build":
		for i in chant_idx:
			shown.append(p.stock[i].el)
	else:
		shown = fight.chant.duplicate()
	var n := maxi(slots, shown.size())
	for i in n + 1:
		# gaps (for placing an infused element) sit before each slot and after the last one
		if chant_mode == "insert" and i <= shown.size():
			var gap := UiTheme.label("＋", 26, Color(1, 0.9, 0.4) if i == chant_i else Color(1, 1, 1, 0.35))
			gap.mouse_filter = Control.MOUSE_FILTER_STOP
			gap.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
			var gi := i
			gap.gui_input.connect(func(ev): if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT: _emit_chant_done(gi))
			_chant_row.add_child(gap)
		if i == n:
			break
		var slot := Panel.new()
		var px := 58 if n <= 10 else 46
		slot.custom_minimum_size = Vector2(px, px)
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0, 0, 0, 0.35)
		sb.border_color = Color(1, 0.9, 0.4) if (i == _step_pos or (chant_mode == "pick" and i == chant_i)) else Color(0.4, 0.5, 0.4, 0.8)
		sb.set_border_width_all(4 if i == _step_pos else 2)
		sb.set_corner_radius_all(px / 2)
		slot.add_theme_stylebox_override("panel", sb)
		if i < shown.size():
			var ic := ElementIcon.make(shown[i], px)
			if phase == "build":
				ic.temp = p.stock[chant_idx[i]].temp
				ic.hexed = p.stock[chant_idx[i]].hexed
				var idx := i
				slot.gui_input.connect(func(ev): if ev is InputEventMouseButton and ev.pressed: _remove_from_chant(idx))
			else:
				ic.highlight = i == _step_pos or (chant_mode == "pick" and i == chant_i)
				ic.dim = _step_pos >= 0 and i > _step_pos
				if chant_mode == "pick":
					var ci := i
					slot.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
					slot.gui_input.connect(func(ev): if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT: _emit_chant_done(ci))
			ic.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			slot.add_child(ic)
		_chant_row.add_child(slot)
	var note := "%d / %d slots" % [chant_idx.size(), slots]
	if phase == "spells":
		note = "Chanted (%d). It is Released when your spells are done." % shown.size()
	if p.toll > 0:
		note += " (Toll: -%d)" % p.toll
	if p.confuse_turns > 0 and phase == "build":
		note += "   ·   CONFUSED: this chant will be read backwards, and there is no preview"
	_chant_note.text = note


func _refresh_stock() -> void:
	var p := fight.player
	for c in _stock_row.get_children():
		c.queue_free()
	var order := range(p.stock.size())
	order.sort_custom(func(a, b): return "FWA".find(p.stock[a].el) < "FWA".find(p.stock[b].el) or ("FWA".find(p.stock[a].el) == "FWA".find(p.stock[b].el) and a < b))
	for i in order:
		var s: Dictionary = p.stock[i]
		var ic := ElementIcon.make(s.el, 52)
		ic.temp = s.temp
		ic.frozen = s.frozen
		ic.hexed = s.hexed
		ic.dim = i in chant_idx or phase != "build"
		ic.mouse_filter = Control.MOUSE_FILTER_STOP
		var tip: String = Elements.NAMES[s.el]
		if s.temp:
			tip += " (conjured: fades at the end of this turn)"
		if s.frozen:
			tip += " (frozen: can't be used this turn)"
		if s.hexed:
			tip += " (hexed: chanting it costs 2 HP)"
		ic.tooltip_text = tip
		var idx: int = i
		ic.gui_input.connect(func(ev): if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT: _toggle_stock(idx))
		_stock_row.add_child(ic)


# ------------------------------------------------------------------ chant input

func _allowed(action: String, arg = null) -> bool:
	return gate.call(action, arg)


func _chant_changed() -> void:
	_refresh_all()
	tut.emit("chant_changed", _chant_string())


func _toggle_stock(i: int) -> void:
	if busy or phase != "build":
		return
	if i in chant_idx:
		if not _allowed("remove"):
			return
		chant_idx.erase(i)
		Audio.play("elem_remove")
	elif not fight.player.stock[i].frozen and chant_idx.size() < fight.player.chant_slots():
		if not _allowed("add", fight.player.stock[i].el):
			return
		chant_idx.append(i)
		Audio.play("elem_pickup")
	_chant_changed()


func _remove_from_chant(pos: int) -> void:
	if busy or phase != "build" or pos >= chant_idx.size() or not _allowed("remove"):
		return
	chant_idx.remove_at(pos)
	Audio.play("elem_remove")
	_chant_changed()


func _add_element(el: String) -> void:
	if busy or phase != "build" or chant_idx.size() >= fight.player.chant_slots() or not _allowed("add", el):
		return
	var pick := -1
	for i in fight.player.stock.size():
		var s: Dictionary = fight.player.stock[i]
		if s.el != el or s.frozen or i in chant_idx:
			continue
		if pick == -1 or (s.temp and not fight.player.stock[pick].temp) or (fight.player.stock[pick].hexed and not s.hexed):
			pick = i
	if pick >= 0:
		chant_idx.append(pick)
		Audio.play("elem_pickup")
		_chant_changed()


func _clear_chant() -> void:
	if busy or phase != "build" or not _allowed("clear"):
		return
	chant_idx.clear()
	Audio.play("elem_remove")
	_chant_changed()


func _unhandled_input(ev: InputEvent) -> void:
	if _pause_overlay != null:
		if ev is InputEventKey and ev.pressed and ev.keycode == KEY_ESCAPE:
			_close_pause_menu()
			get_viewport().set_input_as_handled()
		return
	if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_RIGHT:
		_cancel()
		return
	if not (ev is InputEventKey) or not ev.pressed or ev.echo:
		return
	if aiming:
		match ev.keycode:
			KEY_TAB:
				aim_i = (aim_i + (-1 if ev.shift_pressed else 1) + aim_cands.size()) % aim_cands.size()
				Audio.play("ui_tab_target")
				_refresh_all()
			KEY_ENTER, KEY_KP_ENTER, KEY_SPACE:
				if _allowed("target", aim_cands[aim_i]):
					_finish_aim(aim_cands[aim_i])
			KEY_ESCAPE:
				_cancel()
		get_viewport().set_input_as_handled()
		return
	if move_view != null:
		if ev.keycode == KEY_ESCAPE:
			_cancel()
		get_viewport().set_input_as_handled()
		return
	if chant_mode != "":
		var count := fight.chant.size() + (1 if chant_mode == "insert" else 0)
		match ev.keycode:
			KEY_TAB, KEY_RIGHT:
				chant_i = (chant_i + 1) % count
				Audio.play("ui_tab_target")
				_refresh_chant()
			KEY_LEFT:
				chant_i = (chant_i - 1 + count) % count
				Audio.play("ui_tab_target")
				_refresh_chant()
			KEY_ENTER, KEY_KP_ENTER, KEY_SPACE:
				_emit_chant_done(chant_i)
		get_viewport().set_input_as_handled()
		return
	if pick_view != null:
		match ev.keycode:
			KEY_TAB:
				Audio.play("ui_tab_target")
				_cycle_pick(-1 if ev.shift_pressed else 1)
			KEY_ENTER, KEY_KP_ENTER, KEY_SPACE:
				if pick_view.pick_i >= 0 and _allowed("pick", pick_view.pick_i):
					_pick_done.emit(pick_view.pick_i)
		get_viewport().set_input_as_handled()
		return
	match ev.keycode:
		KEY_F:
			_add_element("F")
		KEY_W:
			_add_element("W")
		KEY_A:
			_add_element("A")
		KEY_1, KEY_2, KEY_3, KEY_4, KEY_5, KEY_6, KEY_7:
			var n: int = ev.keycode - KEY_1
			if phase == "spells" and n < _cards.size():
				_on_card_clicked(_cards[n])
			elif phase == "build" and n < 3:
				_add_element(["F", "W", "A"][n])
		KEY_BACKSPACE:
			if not busy and phase == "build" and not chant_idx.is_empty() and _allowed("remove"):
				chant_idx.pop_back()
				_chant_changed()
		KEY_ENTER, KEY_KP_ENTER, KEY_SPACE:
			_on_cast()
		KEY_E:
			_on_end_turn()
		_:
			return
	get_viewport().set_input_as_handled()


func _cancel() -> void:
	if not _allowed("cancel"):
		return
	if aiming and aim_cancellable:
		_finish_aim(-1)
	elif move_view != null:
		_move_done.emit([])


# ------------------------------------------------------------------ casting

func _on_primary() -> void:
	if phase == "build":
		_on_cast()
	else:
		_on_end_turn()


func _on_cast() -> void:
	if busy or phase != "build" or chant_idx.is_empty() or not _allowed("chant"):
		return
	busy = true
	end_confirm = false
	var idx := chant_idx.duplicate()
	chant_idx.clear()
	phase = "spells"
	_refresh_all()
	await fight.cast_chant(idx)
	_sync_views()
	busy = false
	_refresh_all()
	tut.emit("chanted", fight.chant_string())
	if fight.over:
		await _finish()
	elif not fight.has_valid_move() and auto_release:
		_banner("No spell matched", UiTheme.MUTED, 0.6)
		await _wait(0.4)
		await _damage_step()


func _on_card_clicked(card: SpellCard) -> void:
	if busy or aiming or phase != "spells" or card.charges <= 0 or not _allowed("cast", card.spell.id):
		return
	var spell: Dictionary = card.spell
	var target := -1
	if _needs_pick(spell):
		var cands := fight.target_candidates()
		if cands.size() == 1:
			target = cands[0]
		else:
			target = await _aim(card, _card_point(card), cands, "%s: choose a target  ·  click, or Tab + Enter  ·  right-click to put it back" % spell.name, true)
			if target < 0:
				return
	busy = true
	end_confirm = false
	await fight.resolve_spell(spell.id, target)
	_sync_views()
	busy = false
	_refresh_all()
	tut.emit("cast", spell.id)
	if fight.over:
		await _finish()
	elif not fight.has_valid_move() and auto_release:
		# nothing left to cast: the chant is Released by itself
		await _wait(0.3)
		await _damage_step()


## Does the player point this spell at an enemy before it resolves? (Effects aimed at "target".)
func _needs_pick(spell: Dictionary) -> bool:
	for e in spell.effects:
		if e.get("target", "") == "target":
			return true
	return false


func _on_end_turn() -> void:
	if busy or aiming or move_view != null or pick_view != null or chant_mode != "":
		return
	if not _allowed("release" if phase == "spells" else "pass"):
		return
	if phase == "spells" and fight.has_valid_move() and not end_confirm:
		end_confirm = true
		_refresh_all()
		_prompt.text = "%d spell charge%s still alive. Press Release again to let them fizzle." % [_charge_count(), "" if _charge_count() == 1 else "s"]
		return
	if phase == "spells":
		await _damage_step()
		return
	# before chanting: pass the turn and keep your elements
	busy = true
	chant_idx.clear()
	_prompt.text = "The enemies act…"
	_refresh_all()
	await fight.pass_turn()
	await _after_turn()


## Release: the chant flies at the enemies element by element, then they act and your next turn starts.
func _damage_step() -> void:
	if busy or fight.over:
		return
	busy = true
	end_confirm = false
	tut.emit("releasing", null)
	_prompt.text = "Release!"
	_refresh_all()
	await fight.finish_turn()
	await _after_turn()


func _after_turn() -> void:
	phase = "build"
	_step_pos = -1
	_sync_views()
	busy = false
	_refresh_all()
	if fight.over:
		await _finish()
	else:
		_banner("Your turn", Color(0.9, 0.95, 0.8), 0.7)
		tut.emit("turn_start", fight.turn)


func _charge_count() -> int:
	var n := 0
	for id in fight.charges:
		n += fight.charges[id]
	return n


func _finish() -> void:
	busy = true
	_banner("Victory!" if fight.won else "The last tree falls…", Color(0.6, 1, 0.5) if fight.won else UiTheme.DANGER)
	await get_tree().create_timer(1.4).timeout
	finished.emit(fight.won)


# ------------------------------------------------------------------ pause menu

func _open_pause_menu() -> void:
	if _pause_overlay != null:
		return
	var overlay := Control.new()
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.z_index = 100
	var shade := ColorRect.new()
	shade.color = Color(0, 0, 0, 0.6)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_child(shade)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_child(center)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UiTheme.panel_box(0.95, 16))
	panel.custom_minimum_size = Vector2(380, 0)
	center.add_child(panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	panel.add_child(v)
	v.add_child(UiTheme.label("Paused", 28, Color.WHITE))
	var resume_btn := UiTheme.button("Resume", _close_pause_menu, 20)
	resume_btn.custom_minimum_size = Vector2(320, 52)
	v.add_child(resume_btn)
	var settings_btn := UiTheme.button("Settings", func():
		var s := SettingsScreen.new()
		s.closed.connect(s.queue_free)
		overlay.add_child(s), 20)
	settings_btn.custom_minimum_size = Vector2(320, 52)
	v.add_child(settings_btn)
	var menu_btn := UiTheme.button("Main Menu", func(): _confirm_in(v, panel,
		"Abandon this run and return to the Main Menu?",
		func(): menu_requested.emit()), 20)
	menu_btn.custom_minimum_size = Vector2(320, 52)
	v.add_child(menu_btn)
	var quit_btn := UiTheme.button("Quit to Desktop", func(): _confirm_in(v, panel,
		"Quit The Last Tree?",
		func(): get_tree().quit()), 20)
	quit_btn.custom_minimum_size = Vector2(320, 52)
	v.add_child(quit_btn)
	add_child(overlay)
	_pause_overlay = overlay


func _close_pause_menu() -> void:
	if _pause_overlay == null:
		return
	_pause_overlay.queue_free()
	_pause_overlay = null


## Swaps a menu's buttons (v) for a Yes/Cancel confirmation, in the same popup (panel).
func _confirm_in(v: VBoxContainer, panel: PanelContainer, text: String, on_yes: Callable) -> void:
	v.hide()
	var cv := VBoxContainer.new()
	cv.add_theme_constant_override("separation", 12)
	panel.add_child(cv)
	var l := UiTheme.label(text, 19, UiTheme.DANGER)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(320, 0)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cv.add_child(l)
	var yes := UiTheme.button("Yes", on_yes, 20)
	yes.custom_minimum_size = Vector2(320, 48)
	cv.add_child(yes)
	var no := UiTheme.button("Cancel", func(): cv.queue_free(); v.show(), 20)
	no.custom_minimum_size = Vector2(320, 48)
	cv.add_child(no)


# ------------------------------------------------------------------ aiming (the arrow)

func _card_point(card: SpellCard) -> Vector2:
	return card.global_position + Vector2(card.size.x / 2.0, 10)


## Pull an arrow from `from` to the mouse until an enemy is chosen. Returns its index, or -1 if cancelled.
func _aim(card: SpellCard, from: Vector2, cands: Array, prompt: String, cancellable: bool) -> int:
	aiming = true
	tut.emit("aiming", null)
	aim_card = card
	aim_from = from
	aim_cands = cands
	aim_i = 0
	aim_cancellable = cancellable
	_prompt.text = prompt
	_refresh_all()
	var idx: int = await _aim_done
	return idx


func _finish_aim(idx: int) -> void:
	aiming = false
	aim_card = null
	_arrow.queue_redraw()
	_refresh_all()
	_aim_done.emit(idx)


func _on_enemy_clicked(v: EnemyView) -> void:
	if not aiming:
		return
	var idx := fight.enemies.find(v.enemy)
	if idx in aim_cands and _allowed("target", idx):
		_finish_aim(idx)


func _process(_d: float) -> void:
	if aiming:
		# the enemy under the mouse becomes the highlighted target
		var m := get_global_mouse_position()
		for e in _views:
			var v: EnemyView = _views[e]
			var idx := fight.enemies.find(e)
			if idx in aim_cands and Rect2(v.global_position, v.size).has_point(m):
				var pos := aim_cands.find(idx)
				if pos != aim_i:
					aim_i = pos
					_refresh_all()
		_arrow.queue_redraw()


func _draw_arrow() -> void:
	if not aiming:
		return
	var a := aim_from
	var b := get_global_mouse_position()
	var hover := false
	for e in _views:
		var v: EnemyView = _views[e]
		if fight.enemies.find(e) in aim_cands and Rect2(v.global_position, v.size).has_point(b):
			hover = true
	var col := Color(1, 0.85, 0.35) if not hover else Color(1, 0.45, 0.35)
	# soft upward curve, like a thrown spell
	var ctrl := (a + b) / 2.0 + Vector2(0, -maxf(80.0, a.distance_to(b) * 0.35))
	var pts := []
	var n := 40
	for i in n + 1:
		var t := i / float(n)
		pts.append(a.lerp(ctrl, t).lerp(ctrl.lerp(b, t), t))
	# dots every ~24px along the curve
	var acc := 0.0
	for i in range(1, pts.size() - 2):
		acc += pts[i].distance_to(pts[i - 1])
		if acc >= 24.0:
			acc = 0.0
			var r := 4.0 + 3.0 * (i / float(n))
			_arrow.draw_circle(pts[i], r + 2.0, Color(0, 0, 0, 0.5))
			_arrow.draw_circle(pts[i], r, col)
	var dir: Vector2 = (pts[n] - pts[n - 3]).normalized()
	var side := Vector2(-dir.y, dir.x)
	var head := PackedVector2Array([b + dir * 6.0, b - dir * 26.0 + side * 16.0, b - dir * 18.0, b - dir * 26.0 - side * 16.0])
	var outline := PackedVector2Array([b + dir * 10.0, b - dir * 30.0 + side * 20.0, b - dir * 20.0, b - dir * 30.0 - side * 20.0])
	_arrow.draw_colored_polygon(outline, Color(0, 0, 0, 0.55))
	_arrow.draw_colored_polygon(head, col)


# ------------------------------------------------------------------ fight callbacks

## The fight needs a target it wasn't given (a Power at the start of your turn, or the target died mid-spell).
func _choose_target(spell: Dictionary, cands: Array) -> int:
	if cands.size() == 1:
		return cands[0]
	var card: SpellCard = null
	for c in _cards:
		if c.spell.id == spell.id:
			card = c
	var from := _card_point(card) if card else _player_panel.global_position + Vector2(250, 0)
	return await _aim(card, from, cands, "%s: choose a target  ·  click, or Tab + Enter" % spell.name, false)


## Move one element of this enemy's HP: click it, then click where it goes. Esc / right-click skips.
func _mover(spell: Dictionary, e: EnemyState) -> Array:
	var v: EnemyView = _views.get(e)
	if v == null:
		return []
	move_view = v
	v.move_mode = true
	v.move_pick = -1
	_prompt.text = "%s: click an element of %s to pick it up  ·  right-click to skip" % [spell.name, e.name]
	_refresh_all()
	var pair: Array = await _move_done
	v.move_mode = false
	v.move_pick = -1
	move_view = null
	_refresh_all()
	return pair


## Pluck: choose which element of this enemy's HP to remove. Click it, or Tab through and Enter.
func _picker(spell: Dictionary, e: EnemyState) -> int:
	var v: EnemyView = _views.get(e)
	if v == null:
		return e.armor.find(false)
	pick_view = v
	tut.emit("picking", null)
	v.pick_mode = true
	v.pick_i = e.armor.find(false)
	_prompt.text = "%s: choose an element of %s to remove  ·  click it, or Tab + Enter" % [spell.name, e.name]
	_refresh_all()
	var idx: int = await _pick_done
	tut.emit("picked", idx)
	v.pick_mode = false
	v.pick_i = -1
	pick_view = null
	_refresh_all()
	return idx


func _cycle_pick(step: int) -> void:
	var e := pick_view.enemy
	var i := pick_view.pick_i
	for k in e.size():
		i = (i + step + e.size()) % e.size()
		if not e.armor[i]:
			break
	pick_view.pick_i = i
	pick_view.refresh({})


func _on_hp_clicked(v: EnemyView, index: int) -> void:
	if v == pick_view:
		if index < v.enemy.size() and _allowed("pick", index):
			_pick_done.emit(index)
		return
	if v != move_view:
		return
	if v.move_pick < 0:
		if index < v.enemy.size():
			v.move_pick = index
			_prompt.text = "Now click where it goes (it takes that spot), or ▸ for the end  ·  click it again to put it down"
			v.refresh({})
		return
	if index == v.move_pick:
		v.move_pick = -1
		_prompt.text = "Click an element to pick it up  ·  right-click to skip"
		v.refresh({})
		return
	_move_done.emit([v.move_pick, index])


func _emit_chant_done(i: int) -> void:
	if _allowed("place", i):
		_chant_done.emit(i)


## Infuse: choose the gap in the chant where the new element goes (click a ＋, or Tab / arrows + Enter).
func _placer(spell: Dictionary, el: String) -> int:
	chant_mode = "insert"
	tut.emit("placing", null)
	chant_i = fight.chant.size()
	_prompt.text = "%s: where should the %s go in the chant?  ·  click a ＋, or Tab + Enter" % [spell.name, Elements.NAMES[el]]
	_refresh_all()
	var i: int = await _chant_done
	chant_mode = ""
	_refresh_all()
	tut.emit("placed", i)
	return i


## Resonance: choose the chant element to copy.
func _chant_picker(spell: Dictionary) -> int:
	chant_mode = "pick"
	chant_i = 0
	_prompt.text = "%s: which element of the chant should be copied?  ·  click it, or Tab + Enter" % spell.name
	_refresh_all()
	var i: int = await _chant_done
	chant_mode = ""
	_refresh_all()
	return i


## Misdirection: pick who the enemy's intent hits instead (itself included).
func _redirector(spell: Dictionary, src: EnemyState, cands: Array) -> int:
	var v: EnemyView = _views.get(src)
	var from := v.anchor_point() if v else _player_panel.global_position
	return await _aim(null, from, cands, "%s: who should %s's intent hit instead? (it can be itself)  ·  right-click: nobody" % [spell.name, src.name], true)


## Animation hook from the fight.
func _anim(ev: Dictionary) -> void:
	match ev.type:
		"chant":
			_prompt.text = "Chanting " + " ".join(Array(ev.chant.split("")).map(func(c): return Elements.NAMES[c]))
			await _wait(0.25)
		"strike":
			_step_pos = -1
			var v: EnemyView = _views.get(ev.enemy)
			if v:
				v.hit_flash()
				_float_text("-%d" % ev.n, v.global_position + Vector2(150, 220), Color(1, 0.9, 0.6))
			Audio.play("sfx_damage_hit")
			_refresh_all()
			await _wait(0.3)
		"chant_step":
			await _release_step(ev)
		"chant_changed":
			Audio.play("elem_pickup")
			_refresh_all()
			await _wait(0.25)
		"loadout_changed":
			Audio.play("discovery_unlock")
			_build_spells()
			_refresh_all()
			await _wait(0.3)
		"charged":
			Audio.play("spell_glow")
			_refresh_all()
			_banner("Your spells come alive!", Color(1, 0.9, 0.55), 0.6)
			await _wait(0.2)
		"spell":
			Audio.play("spell_glow")
			_banner(ev.spell.name, GameData.spell_color(ev.spell.pattern).lightened(0.3), 0.5)
			await _wait(0.25)
		"effect":
			var snd: String = EFFECT_SFX.get(ev.op, "")
			if snd != "":
				Audio.play(snd)
			_sync_views()
			_refresh_all()
			await _wait(0.12)
		"attack":
			var v: EnemyView = _views.get(ev.enemy)
			if v:
				var tw := v.creature.create_tween()
				tw.tween_property(v.creature, "scale", Vector2(1.15, 1.15), 0.08)
				tw.tween_property(v.creature, "scale", Vector2.ONE, 0.12)
			Audio.play("sfx_player_hit" if ev.n > 0 else "release_armour_block")
			_float_text("-%d" % ev.n if ev.n > 0 else "Blocked", _player_panel.global_position + Vector2(200, 20), UiTheme.DANGER if ev.n > 0 else Color(0.7, 0.85, 1))
			var tw2 := _player_panel.create_tween()
			tw2.tween_property(_player_panel, "modulate", Color(1.6, 0.6, 0.6), 0.08)
			tw2.tween_property(_player_panel, "modulate", Color.WHITE, 0.25)
			_refresh_all()
			await _wait(0.4)
		"mend":
			Audio.play("sfx_mend")
			_sync_views()
			_refresh_all()
			await _wait(0.2)
		"unlock":
			Audio.play("sfx_lock_break")
			_refresh_all()
			await _wait(0.2)
		"dot":
			if ev.get("burn", false):
				Audio.play("sfx_burn_tick")
			if ev.get("poison", false):
				Audio.play("sfx_poison_tick")
			_sync_views()
			_refresh_all()
			await _wait(0.2)
		"thorns_proc":
			Audio.play("sfx_thorns_proc")
		"amplify":
			Audio.play("sfx_amplify")
			_sync_views()
			_refresh_all()
			await _wait(0.2)
		"boss_phase":
			Audio.play("boss_phase_change")
		"boss_defeat":
			Audio.play("boss_defeat")
		"spawn":
			Audio.play("enemy_spawn")
			_sync_views()
			_refresh_all()
			await _wait(0.25)
		"intents_shown":
			Audio.play("enemy_intent_show")
			_sync_views()
			_refresh_all()
			await _wait(0.1)
		"confuse":
			Audio.play("sfx_confuse_apply")
			_refresh_all()
			await _wait(0.15)
		"blind":
			Audio.play("sfx_blind_apply")
			_refresh_all()
			await _wait(0.15)
		"frail":
			Audio.play("sfx_frail_apply")
			_refresh_all()
			await _wait(0.15)
		"freeze_stock":
			Audio.play("sfx_freeze_apply")
			_refresh_all()
			await _wait(0.15)
		"silence":
			Audio.play("sfx_silence_apply")
			_refresh_all()
			await _wait(0.15)
		"bleed_tick":
			Audio.play("sfx_bleed_tick")
			_refresh_all()
			await _wait(0.15)
		_:
			_sync_views()
			_refresh_all()
			await _wait(0.2)


## One chant element lifts off as a comet and flies into every HP element it hits (or fizzles upward).
func _release_step(ev: Dictionary) -> void:
	_step_pos = ev.pos
	var slots := _chant_row.get_children().filter(func(c): return c is Panel)
	if ev.pos >= slots.size():
		return
	var slot: Panel = slots[ev.pos]
	var from := slot.global_position + slot.size / 2.0
	var el: String = ev.chant[ev.pos]
	var col: Color = Elements.COLORS[el]
	# the orb in the chant lights up, then empties as it leaves
	for c in slot.get_children():
		var tw := c.create_tween()
		tw.tween_property(c, "modulate", Color(2.2, 2.2, 2.0), 0.08)
		tw.tween_property(c, "modulate", Color(1, 1, 1, 0.25), 0.2)
	Audio.play(LAUNCH_SFX.get(el, "elem_pickup"))
	if ev.hits.is_empty():
		Comet.launch(_fx, from, from + Vector2(0, -170), col, true)
		await _wait(0.16)
		return
	var impact: String = IMPACT_SFX.get(el, "sfx_damage_hit")
	for h in ev.hits:
		var v: EnemyView = _views.get(h[0])
		if v == null:
			continue
		var comet := Comet.launch(_fx, from, v.hp_point(h[1]), col)
		var j: int = h[1]
		comet.arrived.connect(func():
			if is_instance_valid(v): v.pop(j)
			Audio.play(impact))
	await _wait(0.46)


func _wait(t: float) -> void:
	if is_inside_tree():
		await get_tree().create_timer(t).timeout


func _float_text(text: String, pos: Vector2, col: Color) -> void:
	var l := UiTheme.label(text, 34, col)
	l.add_theme_constant_override("outline_size", 8)
	l.add_theme_color_override("font_outline_color", Color.BLACK)
	l.position = pos
	_fx.add_child(l)
	var tw := l.create_tween()
	tw.set_parallel()
	tw.tween_property(l, "position:y", pos.y - 60, 0.8)
	tw.tween_property(l, "modulate:a", 0.0, 0.8).set_delay(0.3)
	tw.chain().tween_callback(l.queue_free)


func _banner(text: String, col: Color, life := 1.2) -> void:
	var l := UiTheme.label(text, 52, col)
	l.add_theme_constant_override("outline_size", 10)
	l.add_theme_color_override("font_outline_color", Color.BLACK)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.position = Vector2(0, 250)
	l.size = Vector2(1920, 70)
	_fx.add_child(l)
	var tw := l.create_tween()
	tw.tween_interval(life)
	tw.tween_property(l, "modulate:a", 0.0, 0.3)
	tw.tween_callback(l.queue_free)
