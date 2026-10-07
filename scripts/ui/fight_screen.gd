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
signal _arrange_done(move: Array)
signal _element_chosen(el: String)
signal _spell_chosen(idx: int)
signal _any_picked(choice: Array)  # [enemy index, Essence index], or [] when put back

var run: RunState
## The tutorial's gate: func(action: String, arg) -> bool. Actions: add (el), remove, clear, chant, cast (spell id),
## target (enemy index), cancel, pick (HP index), place (chant gap), release, pass. By default everything is allowed.
var gate: Callable = func(_a, _b): return true
## When nothing is left to cast, Release by itself (the tutorial turns this off so the player presses Release).
var run_saved := false  # a real run (saved at the start of this fight): leaving keeps it for Continue
var auto_release := false  # the Release always waits for the player now (it's the one thing that can't be undone)
## Undo: a snapshot of the fight is taken before each spell is cast; Undo (the button under the chant, Ctrl+Z or
## Backspace) puts the last one back. The Release (and drinking a bottle) clears it: those are for good.
var _undo: Array = []
var _undo_btn: Button
## When the player clicks around a lot without anything happening, we explain the situation.
## help_override (tutorial): func() -> String; return "" to use the normal explanation.
var help_override: Callable = Callable()
var _clicks: Array = []  # times (s) of recent clicks that didn't move the game on
var _last_help := -99.0
const IDLE_HELP := 15.0  # seconds with no click or key while the game waits for you
var _idle := 0.0
var _idle_helped := false
var _help_panel: Control
signal blocked(action: String)
var fight: Fight
var chant_idx: Array = []  # stock indices in chant order
var phase := "build"  # build: making the chant · spells: the chant is spoken, spells are alive
var chant_mode := ""  # "insert": placing an infused element · "arrange": Rearrange · "pick": choosing an element to copy
var chant_i := 0  # the gap / element highlighted in chant_mode
var _step_pos := -1  # during the Release: the chant element flying right now
var _released := false  # the chant has been Released this turn: no more damage preview until the next turn
var _release_glow := false  # nothing left to cast: the Release button pulses
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
var _drag: ChantDrag  # the live, draggable chant while you place or rearrange elements
# building a chant by drag and drop: a press becomes a drag once the mouse moves a little, else it's a click
const DRAG_START := 8.0
var _press := {}  # {kind: "stock" / "chant", i, at}
var _bdrag: ChantDrag
var _bdrag_src := {}
# Infuse: the new element waits on its spell's card until you drag it into the chant
var _infuse_orb: ElementIcon
var _infuse_el := ""
var _infuse_dragging := false
var _chant_note: Label
var _chant_panel: PanelContainer
var _bag_panel: PanelContainer
var _stock_row: Control  # the bag: its icons are placed by hand so they can glide into their spots
var _bag_icons := {}  # element uid -> its icon in the bag
var _bag_target := {}  # element uid -> where its icon belongs (local to _stock_row)
var _bag_delay := 0.0  # seconds the bag waits before closing a gap (an element is still on its way out)
var _flying := {}  # element uid -> true while that element is in the air between the bag and the chant
const BAG_PX := 52.0
const BAG_GAP := 6.0
const BAG_W := 1060.0  # (the bag panel is as wide as the chant panel: 1100, minus its margins)
const FLY_TIME := 0.26  # an element jumping between the bag and the chant
const BAG_MOVE := 0.22  # the bag's icons closing up or making room
var _next_row: HBoxContainer
var _prompt: Label
var _info: Label
var _hp_bar: HpBar
var _hp_label: Label
var _pstatus: RichTextLabel
var _status_row: HFlowContainer  # your statuses, as bright badges above the HP bar
var _bottle_row: HBoxContainer  # your bottles, under the HP bar
var _arts: ArtifactBar
var _bottle_from := Vector2.ZERO
var _picking_any := false  # every enemy's Essence is pickable (a spell that takes any Essence, anywhere)
var _picking_any_cancellable := true
var _prepicked := {}  # EnemyState -> the Essence already chosen for it (the picker hands it straight back)
var _pick_style := "shoot"  # "shoot": remove spells (a crosshair, you shoot the Essence off) · "hand": steal (drag it to your bag) · "brush": Expose (paint it Any)
var _pick_only: EnemyState = null  # picking again on the same enemy (a spell that takes several)
var _steal_drag := {}  # while dragging a stolen Essence: {enemy, index, el, from, icon}
var _aim_cursor: AimCursor
var _shot_fired := false  # the shot already showed the hit, so the spell's own fly-in is skipped
## Let go of a stolen Essence this close to the bag and it lands in it.
const BAG_DROP_MARGIN := 90.0  # where the bottle being drunk sits (its effects fly from there)
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
	fight.painter = _painter
	fight.placer = _placer
	fight.chant_picker = _chant_picker
	fight.element_chooser = _element_chooser
	fight.attune_chooser = _attune_chooser
	fight.arranger = _arranger
	fight.redirector = _redirector
	fight.spell_chooser = _spell_chooser
	fight.anim = _anim


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = UiTheme.get_theme()
	_backdrop = Backdrop.new()
	_backdrop.act = run.act
	_backdrop.tree_glow = false
	add_child(_backdrop)
	_info = UiTheme.label("", 22, Color.WHITE)
	_info.position = Vector2(30, 14)
	add_child(_info)
	_arts = ArtifactBar.make(fight.artifacts, fight.artifact_plus)
	_arts.position = Vector2(28, 52)
	add_child(_arts)
	# top-right: coming next
	var np := PanelContainer.new()
	np.add_theme_stylebox_override("panel", UiTheme.panel_box(0.85, 10))
	np.custom_minimum_size = Vector2(330, 0)
	# hugging the top and right edges of the screen (it grows leftwards and down)
	np.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	np.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	var nv := VBoxContainer.new()
	np.add_child(nv)
	nv.add_child(UiTheme.heading("Coming next turn", 16, UiTheme.MUTED))
	_next_row = HBoxContainer.new()
	_next_row.add_theme_constant_override("separation", 4)
	nv.add_child(_next_row)
	add_child(np)
	# enemies
	_enemy_row = HBoxContainer.new()
	_enemy_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_enemy_row.add_theme_constant_override("separation", 20)
	_enemy_row.position = Vector2(0, 90)
	_enemy_row.size = Vector2(1920, 480)
	add_child(_enemy_row)
	_prompt = UiTheme.label("", 22, Color(1, 0.9, 0.5))
	_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_prompt.position = Vector2(0, 492)
	_prompt.size = Vector2(1920, 32)
	_prompt.add_theme_constant_override("outline_size", 6)
	_prompt.add_theme_color_override("font_outline_color", Color.BLACK)
	_prompt.visible = false  # no standing hint line: the Seedling pops up when you seem idle or lost
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
	_chant_panel = cp
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
	var cl := UiTheme.heading("Chant", 18, UiTheme.ACCENT)
	cl.custom_minimum_size = Vector2(70, 0)
	ch.add_child(cl)
	_chant_row = HBoxContainer.new()
	_chant_row.add_theme_constant_override("separation", 6)
	ch.add_child(_chant_row)
	_chant_note = UiTheme.label("", 14, UiTheme.MUTED)
	cv.add_child(_chant_note)
	_undo_btn = UiTheme.button("↶ Undo last spell  (Ctrl+Z)", _undo_last, 15)
	_undo_btn.custom_minimum_size = Vector2(230, 32)
	_undo_btn.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	_undo_btn.tooltip_text = "Take back the last spell you cast this turn. (Pressing Release can't be undone.)"
	_undo_btn.visible = false
	cv.add_child(_undo_btn)
	var bv := VBoxContainer.new()
	bv.add_theme_constant_override("separation", 6)
	chh.add_child(bv)
	_cast_btn = UiTheme.button(UiTheme.hk("Chant", "Enter"), _on_primary, 22)
	UiTheme.use_heading_font(_cast_btn)
	_cast_btn.custom_minimum_size = Vector2(250, 60)
	var chant_art := UiTheme.chant_button_styles()
	for st in chant_art:
		_cast_btn.add_theme_stylebox_override(st, chant_art[st])
	bv.add_child(_cast_btn)
	var small := HBoxContainer.new()
	small.add_theme_constant_override("separation", 6)
	bv.add_child(small)
	_clear_btn = UiTheme.button(UiTheme.hk("Clear", "⌫"), _clear_chant, 15)
	UiTheme.use_heading_font(_clear_btn)
	_clear_btn.custom_minimum_size = Vector2(122, 34)
	small.add_child(_clear_btn)
	_end_btn = UiTheme.button(UiTheme.hk("Pass", "E"), _on_end_turn, 15)
	UiTheme.use_heading_font(_end_btn)
	_end_btn.custom_minimum_size = Vector2(122, 34)
	_end_btn.tooltip_text = "End your turn without chanting (you keep your Essence)."
	small.add_child(_end_btn)
	add_child(cp)
	# stock
	var sp := PanelContainer.new()
	_bag_panel = sp
	sp.add_theme_stylebox_override("panel", UiTheme.panel_box(0.8, 12))
	sp.position = Vector2(540, 872)
	sp.custom_minimum_size = Vector2(1100, 110)
	var sv := VBoxContainer.new()
	sp.add_child(sv)
	sv.add_child(UiTheme.label("Your bag of Essence  (click or drag, or press F / W / A)" if UiTheme.show_hotkeys() else "Your bag of Essence  (click or drag)", 15, UiTheme.MUTED))
	# a plain Control, not a flow container: the icons are placed (and tweened) by hand in _refresh_stock, and a
	# container would keep re-flowing them in creation order (gaps, icons jumping or vanishing mid-glide)
	_stock_row = Control.new()
	_stock_row.mouse_filter = Control.MOUSE_FILTER_PASS
	_stock_row.custom_minimum_size = Vector2(BAG_W, BAG_PX)
	sv.add_child(_stock_row)
	add_child(sp)
	# player: name, your statuses (bright badges) on top of the HP bar, your bottles under it
	_player_panel = PanelContainer.new()
	_player_panel.add_theme_stylebox_override("panel", UiTheme.panel_box(0.9, 12))
	_player_panel.position = Vector2(24, 742)
	_player_panel.custom_minimum_size = Vector2(500, 0)
	var pv := VBoxContainer.new()
	pv.add_theme_constant_override("separation", 6)
	_player_panel.add_child(pv)
	var keeper := UiTheme.heading("The Keeper", 22, Color.WHITE)
	var portrait := UiSkin.icon("portrait_keeper", 56)
	if portrait != null:  # New theme: the Keeper's face beside the name
		var who := HBoxContainer.new()
		who.add_theme_constant_override("separation", 10)
		keeper.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		who.add_child(portrait)
		who.add_child(keeper)
		pv.add_child(who)
	else:
		pv.add_child(keeper)
	_status_row = HFlowContainer.new()
	_status_row.add_theme_constant_override("h_separation", 6)
	_status_row.add_theme_constant_override("v_separation", 4)
	_status_row.custom_minimum_size = Vector2(460, 0)
	pv.add_child(_status_row)
	_hp_bar = HpBar.new()
	_hp_bar.custom_minimum_size = Vector2(460, 26)
	pv.add_child(_hp_bar)
	var under := HBoxContainer.new()
	under.add_theme_constant_override("separation", 8)
	pv.add_child(under)
	_hp_label = UiTheme.label("", 18)
	var hp_font := UiTheme.cut("bold")  # "HP 50 / 50" in the bold cut of the chosen font
	if hp_font != null:
		_hp_label.add_theme_font_override("font", hp_font)
	_hp_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_hp_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var heart := UiSkin.icon("icon_heart", 28)
	if heart != null:
		heart.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		under.add_child(heart)
	under.add_child(_hp_label)
	_bottle_row = HBoxContainer.new()
	_bottle_row.add_theme_constant_override("separation", 6)
	under.add_child(_bottle_row)
	_pstatus = RichTextLabel.new()
	_pstatus.bbcode_enabled = true
	_pstatus.fit_content = true
	_pstatus.scroll_active = false
	_pstatus.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_pstatus.custom_minimum_size = Vector2(460, 0)
	_pstatus.add_theme_font_size_override("normal_font_size", 15)
	_pstatus.add_theme_font_size_override("bold_font_size", 15)
	_pstatus.add_theme_color_override("default_color", Color(0.85, 0.8, 1))
	_pstatus.visible = false  # (statuses are badges now)
	pv.add_child(_pstatus)
	add_child(_player_panel)
	# the fight log, bottom right
	_log = UiTheme.label("", 14, UiTheme.MUTED)
	_log.position = Vector2(1660, 742)
	_log.size = Vector2(245, 240)
	_log.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_log.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	var log_art := UiSkin.box("panel_log_translucent", [24, 24, 24, 24], [18, 12, 18, 12])
	if log_art != null:  # New theme: a wooden plaque behind the log
		_log.add_theme_stylebox_override("normal", log_art)
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
	UiTheme.use_menu_style(menu_btn)
	UiTheme.use_heading_font(menu_btn)
	add_child(menu_btn)
	_build_spells()
	_sync_views()
	_refresh_all()
	_fit_bottom.call_deferred()
	tut.connect(func(_k, _d): note_progress())


# ------------------------------------------------------------------ building

## The spell row. With many spells the cards shrink to fit the screen; hovering one brings it back to full size.
## The lower block (spell row, chant, bag, Keeper, log) is laid out from the top; once the panels have their real sizes,
## slide the whole block down together (keeping the gaps between its parts) until the bag sits BOTTOM_MARGIN above the
## screen's bottom edge.
const BOTTOM_MARGIN := 20.0


func _fit_bottom() -> void:
	await get_tree().process_frame
	if not is_instance_valid(_bag_panel):
		return
	var dy := (size.y if size.y > 0.0 else 1080.0) - BOTTOM_MARGIN - (_bag_panel.position.y + _bag_panel.size.y)
	for n in [_spell_row, _chant_panel, _bag_panel, _player_panel, _log]:
		if n != null:
			n.position.y += dy
	_log.size.y = maxf(60.0, 1016.0 - _log.position.y)  # stop above the Menu button


const ROW_WIDTH := 1860.0


func _build_spells() -> void:
	for c in _spell_row.get_children():
		c.queue_free()
	_cards.clear()
	var n := fight.shown_spells().size()
	var gap := 10.0
	var fit := minf(1.0, (ROW_WIDTH - gap * maxf(0, n - 1)) / maxf(1.0, n * SpellCard.W))
	_spell_row.add_theme_constant_override("separation", int(gap))
	for s in fight.shown_spells():
		var card := SpellCard.make(s)
		card.clicked.connect(_on_card_clicked)
		# each card sits in a holder of its shrunk size, so the row lays out correctly
		var holder := Control.new()
		holder.custom_minimum_size = Vector2(SpellCard.W, SpellCard.H) * fit
		holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.size = Vector2(SpellCard.W, SpellCard.H)
		card.base_scale = fit
		card.scale = Vector2(fit, fit)
		holder.add_child(card)
		_spell_row.add_child(holder)
		_cards.append(card)


func _card_zoom(card: SpellCard, big: bool) -> void:
	if not is_instance_valid(card):
		return
	card.z_index = 20 if big else 0
	var fit := card.base_scale
	var s := 1.0 if big else fit
	# grow upwards and around its centre so it doesn't cover the chant area
	var off := Vector2(-(SpellCard.W * (s - fit)) / 2.0, -(SpellCard.H * (s - fit)))
	var tw := card.create_tween()
	tw.set_parallel()
	tw.tween_property(card, "scale", Vector2(s, s), 0.12)
	tw.tween_property(card, "position", off, 0.12)


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
	_hp_bar.set_values(p.hp, p.max_hp, p.shield)
	_hp_label.text = "HP %d / %d" % [maxf(0, p.hp), p.max_hp]
	_refresh_statuses()
	_refresh_bottles()
	_arts.update_charges(p)
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
		elif phase == "spells" and _step_pos < 0 and not _released:
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
		card.ignited = p.ignited.has(s.id)
		if p.used_powers.has(s.id):
			card.state = "used"
			card.state_text = "Gone for this fight" if s.get("fleeting", false) else "Power in effect"
		elif p.silenced.has(s.id):
			card.state = "silenced"
			card.state_text = "SILENCED\n%d turn%s" % [p.silenced[s.id], "" if p.silenced[s.id] == 1 else "s"]
		elif p.locks.has(s.id):
			card.state = "locked"
			card.lock_pattern = p.locks[s.id]
		card.fires = pv.get("spells", {}).get(s.id, 0) if phase == "build" else 0
		card.charges = fight.charges.get(s.id, 0) if phase == "spells" else 0
		if s.get("anti", false):
			# an anti-spell comes alive with the chant, unless the chant contains its pattern (that breaks it)
			var broken: bool = card.fires > 0 if phase == "build" else fight.anti_broken.has(s.id)
			card.fires = 0
			if broken and card.state == "":
				card.state = "broken"
				card.state_text = "BROKEN\nthis turn"
		card.aiming = aiming and card == aim_card
		card.refresh()
	_log.text = "\n".join(fight.lines.slice(maxi(0, fight.lines.size() - 5)))
	_light_patterns()
	if _undo_btn != null:
		_undo_btn.visible = phase == "spells" and not _released and not fight.over
		_undo_btn.disabled = _undo.is_empty() or busy or aiming or _picking_any
	# one main button: Chant while you build, then Release once the chant is spoken
	_clear_btn.visible = phase == "build"
	_end_btn.visible = phase == "build"
	_end_btn.disabled = busy
	_clear_btn.text = UiTheme.hk("Clear", "⌫")
	_end_btn.text = UiTheme.hk("Pass", "E")
	if phase == "build":
		_cast_btn.text = UiTheme.hk("Chant", "Enter")
		_cast_btn.disabled = busy or chant_idx.is_empty()
	else:
		_cast_btn.text = UiTheme.hk("Release" if not end_confirm else "Fizzle & Release", "E")
		_cast_btn.disabled = busy or aiming or move_view != null or pick_view != null or chant_mode != ""
	var live_spells := fight.charges.size() > 0 and phase == "spells"
	if not aiming and not busy and move_view == null and pick_view == null and chant_mode == "":
		if phase == "build":
			_prompt.text = "" if chant != "" else "Build a chant: when it is Released, enemies lose the longest start of their Essence found in it. Matching spells come alive."
		elif live_spells:
			_prompt.text = "Your spells are alive: click them to cast, in any order."
		else:
			_prompt.text = "Nothing left to cast." if auto_release else "Nothing left to cast: press Release!"
	# every spell is cast: the Release button pulses so you know what to press next
	_release_glow = phase == "spells" and not live_spells and not _cast_btn.disabled and not _released and not fight.over


func _refresh_chant() -> void:
	var p := fight.player
	var slots := p.chant_slots()
	if chant_idx.size() > slots:
		chant_idx.resize(slots)
	if is_instance_valid(_drag) or is_instance_valid(_bdrag):
		return
	for c in _chant_row.get_children():
		c.queue_free()
	var shown: Array = []  # element letters to draw
	if phase == "build":
		for i in chant_idx:
			shown.append(p.stock[i].el)
	else:
		shown = fight.chant.duplicate()
	var n := maxi(_chant_rings(), shown.size())
	var lay := _chant_layout(shown.size())
	_chant_row.add_theme_constant_override("separation", int(lay.y))
	for i in n + 1:
		if i == n:
			break
		var slot := Panel.new()
		var px := int(lay.x)
		slot.custom_minimum_size = Vector2(px, px)
		var lit: bool = i == _step_pos or (chant_mode == "pick" and i == chant_i)
		var slot_art := UiSkin.box("chant_slot_empty")
		if slot_art != null:
			slot.add_theme_stylebox_override("panel", slot_art)
			slot.self_modulate = Color(1.7, 1.45, 0.7) if lit else Color.WHITE
		else:
			var sb := StyleBoxFlat.new()
			sb.bg_color = Color(0, 0, 0, 0.35)
			sb.border_color = Color(1, 0.9, 0.4) if lit else Color(0.4, 0.5, 0.4, 0.8)
			sb.set_border_width_all(4 if i == _step_pos else 2)
			sb.set_corner_radius_all(px / 2)
			slot.add_theme_stylebox_override("panel", sb)
		if i < shown.size():
			var ic := ElementIcon.make(shown[i], px)
			if phase == "build":
				ic.temp = p.stock[chant_idx[i]].temp
				ic.hexed = p.stock[chant_idx[i]].hexed
				if _flying.has(p.stock[chant_idx[i]].uid):
					ic.modulate.a = 0.0  # it lands here in a moment
				var idx := i
				slot.gui_input.connect(func(ev): if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT: _press_element("chant", idx))
				slot.mouse_default_cursor_shape = Control.CURSOR_DRAG
				slot.mouse_entered.connect(func():
					ic.set_hover(true)
					Audio.play("ui_hover", -8.0))
				slot.mouse_exited.connect(func(): ic.set_hover(false))
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
	var note := "%d Essence" % chant_idx.size()
	if p.toll > 0:
		note = "%d / %d Essence (Toll)" % [chant_idx.size(), slots]
	if phase == "spells":
		note = "Chanted (%d). It is Released when your spells are done." % shown.size()
	if p.confuse_turns > 0 and phase == "build":
		note += "   ·   CONFUSED: this chant will be read backwards, and there is no preview"
	_chant_note.text = note


## The bag holds the elements that are not in the chant. Each element keeps its own icon (found by its uid), so
## when the bag changes the icons glide to their new places instead of being rebuilt.
func _refresh_stock() -> void:
	var p := fight.player
	var order := range(p.stock.size())
	order.sort_custom(func(a, b): return "FWA".find(p.stock[a].el) < "FWA".find(p.stock[b].el) or ("FWA".find(p.stock[a].el) == "FWA".find(p.stock[b].el) and a < b))
	var held_uid := -1  # an element being dragged out of the bag is in your hand, not in the bag
	if is_instance_valid(_bdrag) and _bdrag_src.get("kind", "") == "stock":
		held_uid = p.stock[_bdrag_src.i].uid
	var shown: Array = []
	var live := {}
	for i in order:
		if i in chant_idx or p.stock[i].uid == held_uid:
			continue
		shown.append(i)
		live[p.stock[i].uid] = true
	for uid in _bag_icons.keys():
		if not live.has(uid):
			_bag_icons[uid].queue_free()
			_bag_icons.erase(uid)
			_bag_target.erase(uid)
	var per_row := maxi(1, int((BAG_W + BAG_GAP) / (BAG_PX + BAG_GAP)))
	var rows := maxi(1, ceili(float(shown.size()) / per_row))
	_stock_row.custom_minimum_size.y = rows * (BAG_PX + BAG_GAP) - BAG_GAP
	var delay := _bag_delay
	_bag_delay = 0.0
	for k in shown.size():
		var s: Dictionary = p.stock[shown[k]]
		var uid: int = s.uid
		var target := Vector2((k % per_row) * (BAG_PX + BAG_GAP), (k / per_row) * (BAG_PX + BAG_GAP))
		_bag_target[uid] = target
		var ic: ElementIcon = _bag_icons.get(uid)
		var fresh := ic == null
		if fresh:
			ic = ElementIcon.make(s.el, BAG_PX)
			ic.size = Vector2(BAG_PX, BAG_PX)
			ic.pivot_offset = Vector2(BAG_PX, BAG_PX) / 2.0
			ic.mouse_filter = Control.MOUSE_FILTER_STOP
			ic.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
			ic.gui_input.connect(func(ev): if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT: _press_element("stock", _stock_index(uid)))
			ic.mouse_entered.connect(func():
				ic.set_hover(true)
				Audio.play("ui_hover", -8.0))
			ic.mouse_exited.connect(func(): ic.set_hover(false))
			ic.position = target
			_stock_row.add_child(ic)
			_bag_icons[uid] = ic
		ic.el = s.el
		ic.temp = s.temp
		ic.frozen = s.frozen
		ic.hexed = s.hexed
		ic.dim = phase != "build"
		ic.modulate.a = 0.0 if _flying.has(uid) else 1.0
		var tip: String = Elements.NAMES[s.el]
		if s.temp:
			tip += " (conjured: fades at the end of this turn)"
		if s.frozen:
			tip += " (frozen: can't be used this turn)"
		if s.hexed:
			tip += " (hexed: chanting it costs 2 HP)"
		ic.tooltip_text = tip
		ic.queue_redraw()
		if fresh:
			if not _flying.has(uid):
				ic.scale = Vector2(0.3, 0.3)
				ic.create_tween().tween_property(ic, "scale", Vector2.ONE, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			ic.set_meta("goal", target)
		elif ic.get_meta("goal", Vector2(-1, -1)) != target:
			ic.set_meta("goal", target)
			if ic.has_meta("slide"):
				var old: Tween = ic.get_meta("slide")
				if old != null and old.is_valid():
					old.kill()
			var tw := ic.create_tween()
			if delay > 0.0:
				tw.tween_interval(delay)
			tw.tween_property(ic, "position", target, BAG_MOVE).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
			ic.set_meta("slide", tw)


func _stock_index(uid: int) -> int:
	var st: Array = fight.player.stock
	for i in st.size():
		if st[i].uid == uid:
			return i
	return -1


func _bag_center(uid: int) -> Vector2:
	var ic: Control = _bag_icons.get(uid)
	if ic != null and is_instance_valid(ic):
		return ic.global_position + Vector2(BAG_PX, BAG_PX) / 2.0
	return _stock_row.global_position + Vector2(BAG_PX, BAG_PX) / 2.0


## Where an element's icon will rest in the bag once it has settled.
func _bag_target_center(uid: int) -> Vector2:
	return _stock_row.global_position + _bag_target.get(uid, Vector2.ZERO) + Vector2(BAG_PX, BAG_PX) / 2.0


const CHANT_RINGS := 8  # empty rings shown while the chant is short (the chant itself has no length limit)
const CHANT_W := 700.0  # room for the chant: a longer chant squeezes its Essence together, even overlapping


## How many empty rings to show: 8, or fewer under a Toll (its cap).
func _chant_rings() -> int:
	return mini(CHANT_RINGS, fight.player.chant_slots())


## [orb size, gap between orbs] for a chant of `count` Essence. The gap goes negative (orbs overlap) when the
## chant is too long to fit.
func _chant_layout(count := -1) -> Vector2:
	if count < 0:
		count = chant_idx.size() if phase == "build" else fight.chant.size()
	var n := maxi(_chant_rings(), count)
	var px := 58.0 if n <= 10 else 50.0
	var step := minf(px + 6.0, (CHANT_W - px) / maxf(1.0, n - 1))
	return Vector2(px, step - px)


func _chant_px() -> float:
	return _chant_layout().x


func _chant_slot_center(k: int) -> Vector2:
	var l := _chant_layout()
	return _chant_row.global_position + Vector2(k * (l.x + l.y) + l.x / 2.0, l.x / 2.0)


## An element in the air, jumping between the bag and the chant on a little arc, growing or shrinking to the size
## of its new home. Its real icon waits (invisible) at the other end and pops in when this one lands.
func _fly(s: Dictionary, from: Vector2, to: Vector2, from_px: float, to_px: float) -> void:
	var uid: int = s.uid
	var ic := ElementIcon.make(s.el, from_px)
	ic.size = Vector2(from_px, from_px)
	ic.pivot_offset = ic.size / 2.0
	ic.temp = s.temp
	ic.hexed = s.hexed
	ic.z_index = 60
	ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fx.add_child(ic)
	var mid := (from + to) / 2.0 + Vector2(0, -46.0)
	var grow := to_px / from_px
	var tw := create_tween()
	tw.tween_method(func(t: float):
		if not is_instance_valid(ic):
			return
		var pt := from.lerp(mid, t).lerp(mid.lerp(to, t), t)
		ic.position = pt - _fx.global_position - ic.size / 2.0
		ic.scale = Vector2.ONE * lerpf(1.0, grow, t), 0.0, 1.0, FLY_TIME).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_callback(func():
		if is_instance_valid(ic):
			ic.queue_free()
		_flying.erase(uid)
		_refresh_stock()
		_light_patterns()  # the Essence has landed: the spells it builds towards light up now
		if phase == "build":  # once the chant is spoken, its row belongs to the Release
			_refresh_chant()
		_land(uid))


## While you build the chant, every spell lights the orbs of its pattern that the chant is building towards, in
## order, as each Essence lands: FF lights its first orb on the first F, its second on the next. A full match lights
## them all; taking Essence back dims them again. (Essence still in the air don't count yet.)
var _lit := {}  # spell id -> how many of its orbs are lit


func _light_patterns() -> void:
	var c := ""
	if phase == "build":
		for i in chant_idx:
			var st: Dictionary = fight.player.stock[i]
			if _flying.has(st.uid):
				break
			c += st.el
	for card in _cards:
		if not is_instance_valid(card):
			continue
		var orbs: Array = card.live_orbs()
		var sp: Dictionary = card.spell
		var k := 0
		if phase == "build" and c != "" and not sp.has("patterns"):
			k = _pattern_progress(String(sp.pattern), c)
		k = mini(k, orbs.size())
		var before: int = _lit.get(sp.id, 0)
		for j in orbs.size():
			var on := j < k
			if orbs[j].highlight != on:
				orbs[j].highlight = on
				orbs[j].queue_redraw()
		for j in range(before, k):
			_pop_orb(orbs[j])
		_lit[sp.id] = k


## How far the chant has got towards this pattern: all of it if it appears anywhere, otherwise the longest start of
## the pattern that the chant ends with ("?" matches anything).
func _pattern_progress(pattern: String, c: String) -> int:
	if pattern == "":
		return 0
	if not Chant.occurrences(pattern, c).is_empty():
		return pattern.length()
	for k in range(mini(pattern.length() - 1, c.length()), 0, -1):
		if Chant.matches_at(pattern.substr(0, k), c, c.length() - k):
			return k
	return 0


## A small pop as an orb lights up.
func _pop_orb(ic: Control) -> void:
	if not is_instance_valid(ic):
		return
	ic.pivot_offset = ic.size / 2.0
	var tw := ic.create_tween()
	tw.tween_property(ic, "scale", Vector2(1.3, 1.3), 0.07).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(ic, "modulate", Color(1.8, 1.75, 1.5), 0.07)
	tw.tween_property(ic, "scale", Vector2.ONE, 0.14).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(ic, "modulate", Color.WHITE, 0.2)


## The element that just arrived gives a small bounce.
func _land(uid: int) -> void:
	var node: Control = _bag_icons.get(uid)
	if node == null:
		var pos := -1
		for k in chant_idx.size():
			if fight.player.stock[chant_idx[k]].uid == uid:
				pos = k
		var slots := _chant_row.get_children().filter(func(c): return c is Panel)
		if pos >= 0 and pos < slots.size() and slots[pos].get_child_count() > 0:
			node = slots[pos].get_child(0)
	if node != null and is_instance_valid(node):
		node.pivot_offset = node.custom_minimum_size / 2.0
		node.scale = Vector2(1.18, 1.18)
		node.create_tween().tween_property(node, "scale", Vector2.ONE, 0.12)


# ------------------------------------------------------------------ chant input

func _allowed(action: String, arg = null) -> bool:
	var ok: bool = gate.call(action, arg)
	if not ok:
		blocked.emit(action)
	return ok


# ------------------------------------------------------------------ "what's going on?" help

## Anything that moves the game on (a tut event) means the player knows what they're doing.
func note_progress() -> void:
	_clicks.clear()


func _exit_tree() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE  # never leave the pointer hidden


func _input(ev: InputEvent) -> void:
	# steal: letting go of the Essence you're dragging
	if not _steal_drag.is_empty() and ev is InputEventMouseButton and ev.button_index == MOUSE_BUTTON_LEFT and not ev.pressed:
		_end_steal_drag(ev.global_position)
		return
	if (ev is InputEventMouseButton or ev is InputEventKey) and ev.pressed:
		_idle = 0.0
		_idle_helped = false
	# Infuse: the element taken from the card follows the mouse; let go over the chant to place it
	if _infuse_dragging and is_instance_valid(_drag):
		if ev is InputEventMouseMotion:
			_drag.set_pointer(ev.global_position)
		elif ev is InputEventMouseButton and ev.button_index == MOUSE_BUTTON_LEFT and not ev.pressed:
			_infuse_drop()
		return
	# building the chant: a held press that moves becomes a drag; let go without moving and it's a click
	if not _press.is_empty():
		if ev is InputEventMouseMotion and is_instance_valid(_bdrag):
			_bdrag.set_pointer(ev.global_position)
		elif ev is InputEventMouseMotion and ev.global_position.distance_to(_press.at) > DRAG_START:
			_begin_build_drag(ev.global_position)
		elif ev is InputEventMouseButton and ev.button_index == MOUSE_BUTTON_LEFT and not ev.pressed:
			var p := _press
			_press = {}
			if is_instance_valid(_bdrag):
				_end_build_drag()
			elif p.kind == "stock":
				_toggle_stock(p.i)
			else:
				_remove_from_chant(p.i)
	if not (ev is InputEventMouseButton) or not ev.pressed:
		return
	var now := Time.get_ticks_msec() / 1000.0
	_clicks.append(now)
	_clicks = _clicks.filter(func(t): return now - t < 3.0)
	# 5 clicks in 3 seconds without the game moving on: the player is probably lost
	if _clicks.size() >= 5 and now - _last_help > 7.0:
		_last_help = now
		_clicks.clear()
		_show_help()


## What is happening right now, and what to do next.
func situation_help() -> String:
	if fight.over:
		return "The fight is over. Hang on a moment."
	if busy:
		if phase == "spells":
			return "Hold on: things are happening! Your chant's Essence are flying at the enemies (the Release), or the enemies are taking their turn. Watch the callouts; you'll be able to act again in a moment."
		return "Hold on: something is still playing out. You'll be able to act again in a moment."
	if aiming:
		return "You're aiming %s. Click an enemy to hit it (the arrow follows your mouse), or press Tab to switch targets and Enter to confirm. Right-click puts the spell back." % (aim_card.spell.name if aim_card else "a spell")
	if pick_view != null:
		return "Choose which of %s's Essence to knock off: click one of its orbs (or Tab to switch, Enter to confirm)." % pick_view.enemy.name
	if move_view != null:
		return "Moving an Essence of %s: click one of its orbs to pick it up, then click where it should go. Right-click skips." % move_view.enemy.name
	if chant_mode == "insert":
		return "Place the new Essence: it's the glowing one in your chant. Drag it to where it should go (or Left / Right, then Enter)."
	if chant_mode == "arrange":
		return "Rearrange: every Essence of your chant is glowing. Drag one to another spot to make new patterns; right-click keeps the chant as it is."
	if chant_mode == "pick":
		return "Pick an Essence of your chant to copy: click it (or Tab + Enter)."
	if phase == "build":
		if chant_idx.is_empty():
			return "Build a chant: click your Essence at the bottom (or press F, W, A). Every enemy will lose the longest START of its Essence found in your chant, and spells whose pattern appears in it come alive. Then press Chant."
		return "Your chant so far: %s. The crossed-out orbs on the enemies show what they'll lose. Add more Essence, click one in the chant to take it back, or press Chant (Enter) when you're happy." % " ".join(Array(_chant_string().split("")))
	var alive := _cards.filter(func(c): return c.charges > 0)
	if not alive.is_empty():
		var names := alive.map(func(c): return c.spell.name)
		return "Your chant is spoken. These spells are alive (glowing): %s. Click one to cast it; if it needs a target it pulls out an arrow, then click an enemy. When you're done, press Release (E) to fire the chant." % ", ".join(names)
	return "Your spells are done. Press Release (E): the chant's Essence fly at the enemies and deal the damage."


func _show_help() -> void:
	var text := ""
	if help_override.is_valid():
		text = help_override.call()
	if text == "":
		text = situation_help()
	if is_instance_valid(_help_panel):
		_help_panel.queue_free()
	# a box on the left side, under your artifacts: it covers nothing you need, and only its ✕ takes clicks
	var p := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.99, 0.95, 0.82)
	sb.border_color = Color(1, 0.75, 0.2)
	sb.set_border_width_all(3)
	sb.set_corner_radius_all(14)
	sb.content_margin_left = 16
	sb.content_margin_right = 12
	sb.content_margin_top = 8
	sb.content_margin_bottom = 14
	sb.shadow_color = Color(0, 0, 0, 0.35)
	sb.shadow_size = 6
	sb.shadow_offset = Vector2(4, 5)
	var paper := UiSkin.box("panel_paper_frame", [24, 24, 24, 24], [24, 14, 22, 22])
	p.add_theme_stylebox_override("panel", paper if paper != null else sb)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.z_index = 99
	p.position = Vector2(24, 112)
	p.custom_minimum_size = Vector2(440, 0)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 4)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_child(v)
	var head := HBoxContainer.new()
	head.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(head)
	var sprout: Control = UiSkin.icon("icon_seedling", 40)  # New theme: the painted Seedling instead of the 🌱 emoji
	if sprout == null:
		sprout = UiTheme.label("🌱", 34, Color.WHITE)
	sprout.mouse_filter = Control.MOUSE_FILTER_IGNORE
	head.add_child(sprout)
	var who := UiTheme.label("Seedling", 22, Color(0.2, 0.45, 0.15))
	who.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	who.mouse_filter = Control.MOUSE_FILTER_IGNORE
	head.add_child(who)
	var close := Button.new()
	close.text = "✕"
	close.flat = true
	close.focus_mode = Control.FOCUS_NONE
	close.tooltip_text = "Close"
	close.add_theme_font_size_override("font_size", 22)
	var close_art := UiSkin.box("button_close_x_normal")
	if close_art != null:  # New theme: the round painted button (its x is part of the picture), always a square 40 px
		close.flat = false
		close.text = ""
		close.custom_minimum_size = Vector2(40, 40)
		close.size_flags_horizontal = Control.SIZE_SHRINK_END
		close.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		close.add_theme_stylebox_override("normal", close_art)
		close.add_theme_stylebox_override("hover", UiSkin.box("button_close_x_hover"))
		close.add_theme_stylebox_override("pressed", UiSkin.box("button_close_x_pressed"))
	close.add_theme_color_override("font_color", Color(0.35, 0.28, 0.2))
	close.add_theme_color_override("font_hover_color", Color(0.8, 0.2, 0.15))
	close.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	close.pressed.connect(func(): if is_instance_valid(p): p.queue_free())
	head.add_child(close)
	var r := RichTextLabel.new()
	r.bbcode_enabled = true
	r.fit_content = true
	r.scroll_active = false
	r.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	r.custom_minimum_size = Vector2(412, 0)
	r.add_theme_font_size_override("normal_font_size", 18)
	r.add_theme_font_size_override("bold_font_size", 18)
	r.add_theme_color_override("default_color", Color(0.14, 0.11, 0.08))
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	r.text = Keywords.colorize(text, true)
	v.add_child(r)
	add_child(p)
	_help_panel = p
	var bob := sprout.create_tween().set_loops(6)
	bob.tween_property(sprout, "position:y", -5.0, 0.35).set_trans(Tween.TRANS_SINE)
	bob.tween_property(sprout, "position:y", 0.0, 0.35).set_trans(Tween.TRANS_SINE)
	p.modulate.a = 0.0
	var tw := p.create_tween()
	tw.tween_property(p, "modulate:a", 1.0, 0.2)
	tw.tween_interval(25.0)  # it stays a good while (or until you close it)
	tw.tween_property(p, "modulate:a", 0.0, 0.5)
	tw.tween_callback(p.queue_free)
	_pulse_next_thing()


## Make whatever the player should click next pulse.
func _pulse_next_thing() -> void:
	var targets: Array = []
	if busy or fight.over:
		return
	if phase == "build":
		targets = [_cast_btn] if not chant_idx.is_empty() else [_stock_row]
	elif not aiming and pick_view == null and chant_mode == "":
		var alive := _cards.filter(func(c): return c.charges > 0)
		targets = alive if not alive.is_empty() else [_cast_btn]
	for t in targets:
		var tw := (t as Control).create_tween().set_loops(3)
		tw.tween_property(t, "modulate", Color(1.6, 1.5, 1.0), 0.25)
		tw.tween_property(t, "modulate", Color.WHITE, 0.25)


func _chant_changed() -> void:
	_refresh_all()
	tut.emit("chant_changed", _chant_string())


# ------------------------------------------------------------------ building the chant by drag and drop

func _press_element(kind: String, i: int) -> void:
	if busy or phase != "build" or i < 0:
		return
	_press = {"kind": kind, "i": i, "at": get_global_mouse_position()}


## Pick the element up: the chant becomes a live row where it can land anywhere (the others slide aside).
func _begin_build_drag(pointer: Vector2) -> void:
	var src := _press.duplicate()
	var p := fight.player
	var els: Array = chant_idx.map(func(k): return p.stock[k].el)
	var held := -1
	if src.kind == "stock" and src.i in chant_idx:
		src = {"kind": "chant", "i": chant_idx.find(src.i)}  # it's already in the chant: move it
	if src.kind == "stock":
		if p.stock[src.i].frozen or chant_idx.size() >= p.chant_slots():
			_press = {}
			return
		els.append(p.stock[src.i].el)
		held = els.size() - 1
	else:
		held = src.i
	for c in _chant_row.get_children():
		c.queue_free()
	var d := ChantDrag.new()
	d.els = els
	var live := []
	for k in els.size():
		live.append(k == held)
	d.live = live
	d.slots = _chant_rings()
	var lay := _chant_layout(els.size())
	d.px = lay.x
	d.sep = lay.y
	_chant_row.add_child(d)
	d.begin_external(held, pointer)
	_bdrag = d
	_bdrag_src = src
	Audio.play("elem_pickup")
	_refresh_stock()


## Let go: over the chant it lands in the gap; away from the chant, a chant element goes back to your bag.
func _end_build_drag() -> void:
	var res: Dictionary = _bdrag.external_result()
	var src := _bdrag_src
	var held_at: Vector2 = _bdrag.held_center()
	var held_px: float = _bdrag.px
	_bdrag.queue_free()
	_bdrag = null
	var p := fight.player
	var back := {}  # a chant element let go away from the chant: it flies home to the bag
	if src.kind == "stock":
		if res.inside and chant_idx.size() < p.chant_slots() and _allowed("add", p.stock[src.i].el):
			# (the tutorial's scripted chant is built left to right, so there it always goes on the end)
			var at: int = res.to if gate.call("insert", null) else chant_idx.size()
			chant_idx.insert(clampi(at, 0, chant_idx.size()), src.i)
			Audio.play("elem_pickup")
	elif res.inside:
		if res.to != src.i and _allowed("rearrange"):
			var k: int = chant_idx[src.i]
			chant_idx.remove_at(src.i)
			chant_idx.insert(clampi(res.to, 0, chant_idx.size()), k)
			Audio.play("elem_pickup")
	elif _allowed("remove"):
		back = p.stock[chant_idx[src.i]]
		chant_idx.remove_at(src.i)
		Audio.play("elem_remove")
		_flying[back.uid] = true
	_chant_changed()
	if not back.is_empty():
		_fly(back, held_at, _bag_target_center(back.uid), held_px, BAG_PX)


func _toggle_stock(i: int) -> void:
	if busy or phase != "build" or i < 0:
		return
	if i in chant_idx:
		_remove_from_chant(chant_idx.find(i))
	elif not fight.player.stock[i].frozen and chant_idx.size() < fight.player.chant_slots():
		if not _allowed("add", fight.player.stock[i].el):
			return
		_add_stock_index(i)


## Take an element from the bag into the end of the chant: it jumps up, then the bag closes the gap.
func _add_stock_index(i: int) -> void:
	var s: Dictionary = fight.player.stock[i]
	var from := _bag_center(s.uid)
	chant_idx.append(i)
	Audio.play("elem_pickup")
	_flying[s.uid] = true
	_bag_delay = FLY_TIME * 0.4
	_chant_changed()
	_fly(s, from, _chant_slot_center(chant_idx.size() - 1), BAG_PX, _chant_px())


func _remove_from_chant(pos: int) -> void:
	if busy or phase != "build" or pos < 0 or pos >= chant_idx.size() or not _allowed("remove"):
		return
	var s: Dictionary = fight.player.stock[chant_idx[pos]]
	var from := _chant_slot_center(pos)
	var px := _chant_px()
	chant_idx.remove_at(pos)
	Audio.play("elem_remove")
	_flying[s.uid] = true
	_chant_changed()  # the bag makes room for it; its icon waits there, unseen, until this one lands
	_fly(s, from, _bag_target_center(s.uid), px, BAG_PX)


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
		_add_stock_index(pick)


func _clear_chant() -> void:
	if busy or phase != "build" or not _allowed("clear"):
		return
	var going: Array = []
	var px := _chant_px()
	for k in chant_idx.size():
		going.append([fight.player.stock[chant_idx[k]], _chant_slot_center(k)])
	chant_idx.clear()
	Audio.play("elem_remove")
	for g in going:
		_flying[g[0].uid] = true
	_chant_changed()
	for g in going:
		_fly(g[0], g[1], _bag_target_center(g[0].uid), px, BAG_PX)


func _unhandled_input(ev: InputEvent) -> void:
	if _choosing_el:
		if ev is InputEventKey and ev.pressed and not ev.echo:
			var el: String = {KEY_F: "F", KEY_W: "W", KEY_A: "A"}.get(ev.keycode, "")
			if el != "":
				_element_chosen.emit(el)
		get_viewport().set_input_as_handled()
		return
	if _pause_overlay != null:
		if ev is InputEventKey and ev.pressed and ev.keycode == KEY_ESCAPE:
			_close_pause_menu()
			get_viewport().set_input_as_handled()
		return
	if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_RIGHT:
		if chant_mode == "arrange":
			_arrange_done.emit([])
			return
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
	if is_instance_valid(_drag):
		match ev.keycode:
			KEY_TAB:
				if chant_mode == "arrange":
					_drag.key_cycle(-1 if ev.shift_pressed else 1)
			KEY_LEFT:
				_drag.key_move(-1)
			KEY_RIGHT:
				_drag.key_move(1)
			KEY_ENTER, KEY_KP_ENTER, KEY_SPACE:
				_drag.key_drop()
			KEY_ESCAPE:
				if chant_mode == "arrange":
					_arrange_done.emit([])
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
			if not busy and phase == "build" and not chant_idx.is_empty():
				_remove_from_chant(chant_idx.size() - 1)
			elif phase == "spells":
				_undo_last()
		KEY_Z:
			if ev.ctrl_pressed:
				_undo_last()
			else:
				return
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
	if _picking_any and _picking_any_cancellable:
		_any_picked.emit([])  # put the spell back
	elif aiming and aim_cancellable:
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
	_refresh_all()
	tut.emit("chanted", fight.chant_string())
	busy = false
	_refresh_all()
	if fight.over:
		await _finish()
	elif not fight.has_valid_move() and auto_release:
		await _wait(0.5)
		await _damage_step()


func _on_card_clicked(card: SpellCard) -> void:
	if busy or aiming or phase != "spells" or card.charges <= 0 or not _allowed("cast", card.spell.id):
		return
	var spell: Dictionary = card.spell
	var target := -1
	var first: Dictionary = spell.effects[0] if not spell.effects.is_empty() else {}
	if first.get("target", "") in ["target", "two"]:
		if _picks_any_essence(first):
			# no enemy to aim at: every enemy's Essence lights up under the cursor; one click picks enemy and Essence
			var got := await _pick_any_essence(spell, true)
			if got.is_empty():
				return
			target = got[0]
			_prepicked = {fight.enemies[got[0]]: got[1]}
		else:
			var cands := fight.target_candidates()
			if cands.size() == 1:
				target = cands[0]
			else:
				target = await _aim(card, _card_point(card), cands, "%s: choose a target  ·  click, or Tab + Enter  ·  right-click to put it back" % spell.name, true)
				if target < 0:
					return
	busy = true
	end_confirm = false
	_undo.append(fight.snapshot())  # so this spell can be taken back until the Release
	_casting = true
	await fight.resolve_spell(spell.id, target)
	_end_casting()
	_sync_views()
	_refresh_all()
	tut.emit("cast", spell.id)
	busy = false
	_refresh_all()
	if fight.over:
		await _finish()
	elif not fight.has_valid_move() and auto_release:
		# nothing left to cast: the chant is Released by itself
		await _wait(0.3)
		await _damage_step()


## No spell ever casts itself: every awake spell waits for the player's click, even one with nothing to aim at
## (the user's rule; an automatic cast was added once by mistake and taken out again).


## Does the player point this spell at an enemy before it resolves? (Effects aimed at "target".)
func _needs_pick(spell: Dictionary) -> bool:
	for e in spell.effects:
		if e.get("target", "") in ["target", "two"]:
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
	_undo.clear()  # the Release is for good
	end_confirm = false
	tut.emit("releasing", null)
	_prompt.text = "Release!"
	_refresh_all()
	await fight.finish_turn()
	await _after_turn()


func _after_turn() -> void:
	_undo.clear()
	phase = "build"
	_step_pos = -1
	_released = false
	_sync_views()
	busy = false
	_refresh_all()
	if fight.over:
		await _finish()
	else:
		tut.emit("turn_start", fight.turn)


func _charge_count() -> int:
	var n := 0
	for id in fight.charges:
		n += fight.charges[id]
	return n


func _finish() -> void:
	busy = true
	if fight.won:
		await get_tree().create_timer(0.3).timeout
		var perfect: bool = fight.player.damage_taken <= 0.0
		if not await _result_banner("perfect" if perfect else "victory"):
			if perfect:
				await _slam("Perfect Victory!", Color(0.55, 1.0, 0.75), Color(0.0, 0.3, 0.2), 120)
			else:
				await _slam("Victory!", Color(0.75, 1.0, 0.5), Color(0.1, 0.28, 0.05), 140)
		await get_tree().create_timer(0.5).timeout
	elif run != null and run.can_revive():
		await _seed_revival()
	else:
		if not await _result_banner("defeat"):
			_banner("The last tree falls…", UiTheme.DANGER, 1.6)
			await get_tree().create_timer(1.6).timeout
	finished.emit(fight.won)


## Losing with the Seed of Life: it shines on your artifact bar, flies to the middle of the screen growing as it goes,
## and bursts into a white flash; then the words, and the fight starts over (main.gd sends you back to the
## preparation of this same fight).
func _seed_revival() -> void:
	var from := Vector2(60, 70)
	for c in _arts.get_children():
		if c is ArtifactBar.ArtifactChip and c.id == "seed_of_life":
			from = c.get_global_rect().get_center()
	var seed := ArtifactBar.ArtifactChip.make("seed_of_life")
	seed.z_index = 90
	seed.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fx.add_child(seed)
	await get_tree().process_frame
	seed.pivot_offset = seed.size / 2.0
	seed.position = from - seed.size / 2.0 - _fx.global_position
	Audio.play("spell_glow")
	# it shines where it is
	var shine := seed.create_tween()
	for k in 3:
		shine.tween_property(seed, "modulate", Color(2.4, 2.4, 1.8), 0.12)
		shine.parallel().tween_property(seed, "scale", Vector2(1.35, 1.35), 0.12)
		shine.tween_property(seed, "modulate", Color(1.3, 1.3, 1.1), 0.12)
		shine.parallel().tween_property(seed, "scale", Vector2.ONE, 0.12)
	await shine.finished
	# then flies to the middle, growing
	var mid := Vector2(960, 470) - seed.size / 2.0 - _fx.global_position
	var fly := seed.create_tween().set_parallel(true)
	fly.tween_property(seed, "position", mid, 0.8).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	fly.tween_property(seed, "scale", Vector2(5, 5), 0.8).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	fly.tween_property(seed, "modulate", Color(2.0, 2.0, 1.6), 0.8)
	var v := Vfx.make(_fx, 85)
	v.shaker = _shake
	v.emit(Vector2(960, 470), 0.8, 0.0, func(vv: Vfx, it: Vfx.Item, _d: float) -> void:
		var p := seed.global_position + seed.size * seed.scale / 2.0 - _fx.global_position
		var g := vv.part(p + Vector2(randf_range(-20, 20), randf_range(-20, 20)), Vector2(randf_range(-60, 60), randf_range(-60, 60)), Color(0.8, 1.0, 0.7, 0.8), 0.5, 10.0, Vfx.STAR)
		g.spin = 4.0)
	await fly.finished
	# the white flash
	Audio.play("boss_phase_change")
	var at := Vector2(960, 470)
	v.flash(Color(1, 1, 1, 1.0), 1.4)
	v.glow(at, 500, Color(0.85, 1.0, 0.8, 0.9), 0.9)
	v.ring(at, 30, 700, Color(0.8, 1.0, 0.7), 0.9, 18.0)
	v.burst(at, 60, Color(0.85, 1.0, 0.75), Vector2(300, 1100), Vector2(0.5, 1.0), Vector2(6, 12), Vfx.STAR)
	v.shake(10.0)
	seed.queue_free()
	await _wait(0.5)
	_banner("The Seed of Life gives you a second chance", Color(0.75, 1.0, 0.6), 2.0)
	await _wait(2.2)


# ------------------------------------------------------------------ your statuses and bottles

## [text, colour, keyword] for each status you have: shown as bright badges above your HP bar.
func _status_badges() -> Array:
	var p := fight.player
	var out := []
	if p.shield > 0.0:
		out.append(["🛡 Shield %d" % p.shield, Color(0.3, 0.65, 1.0), "shield"])
	if p.aegis > 0:
		out.append(["✨ Aegis %d" % p.aegis, Color(1.0, 0.8, 0.25), "aegis"])
	var th := p.thorns_turn + p.passive("thorns")
	if th > 0:
		out.append(["🌵 Thorns %d" % th, Color(0.5, 0.85, 0.25), "thorns"])
	if p.ethereal:
		out.append(["👻 Ethereal", Color(0.75, 0.7, 1.0), "ethereal"])
	if p.echo_next:
		out.append(["🔔 Echo ready", Color(0.85, 0.6, 1.0), "echo"])
	if p.bleed > 0:
		out.append(["🩸 Bleed %d" % p.bleed, Color(1.0, 0.25, 0.3), "bleed"])
	if p.confuse_turns > 0:
		out.append(["🌀 Confused %d" % p.confuse_turns, Color(0.8, 0.4, 1.0), "confuse"])
	if p.blind_turns > 0:
		out.append(["🙈 Blind %d" % p.blind_turns, Color(0.7, 0.72, 0.78), "blind"])
	if p.frail_turns > 0:
		out.append(["💔 Frail %d" % p.frail_turns, Color(1.0, 0.4, 0.55), "frail"])
	if p.brittle_turns > 0:
		out.append(["🧊 Brittle %d" % p.brittle_turns, Color(0.55, 0.75, 0.95), "brittle"])
	if p.toll > 0:
		out.append(["🔔 Toll %d" % p.toll, Color(1.0, 0.6, 0.2), "lock"])
	if p.overload > 0:
		out.append(["⚡ Overload %d" % p.overload, Color(1.0, 0.45, 0.3), "overload"])
	if not p.silenced.is_empty():
		out.append(["🤐 Silenced", Color(0.8, 0.45, 1.0), "silence"])
	# every Power you've cast this fight: a badge for the rest of it (hover: what it does)
	for id in p.used_powers:
		var sp := fight._find_spell(id)
		if id == "attunement" and p.passives.has("attune_el"):
			# its badge: the Essence you picked (hover: gain 1 of it each turn)
			var el: String = p.passives.attune_el
			out.append(["+%d each turn" % p.passive("attune"), Elements.COLORS[el], "attune_" + el,
				Keywords.tooltip(sp.name, "Gain %d %s each turn." % [p.passive("attune"), Elements.NAMES[el]], "[color=#9aa89a]Power: it lasts the whole fight.[/color]"), id])
		elif sp.get("power", false):
			var pth := power_theme(sp)
			out.append(["%s %s" % [pth.icon, sp.name], pth.col, "", Keywords.tooltip(sp.name, SpellText.describe(sp), "[color=#9aa89a]Power: it lasts the whole fight.[/color]"), id])
	return out


## How each Power dissolves into its status: the side it vanishes from first, its glowing edge and particles, and its
## badge icon. By spell id; anything else by its main element.
const POWER_THEMES := {
	"fire": {"from": Vector2(0, 1), "col": Color(1.0, 0.55, 0.2), "shape": Vfx.SPARK, "icon": "🔥", "rise": -260.0},
	"water": {"from": Vector2(0, -1), "col": Color(0.35, 0.65, 1.0), "shape": Vfx.DROP, "icon": "💧", "rise": 40.0},
	"wind": {"from": Vector2(-1, 0), "col": Color(0.6, 1.0, 0.8), "shape": Vfx.GLOW, "icon": "🌪", "rise": 120.0},
	"thorn": {"from": Vector2(0, 1), "col": Color(0.55, 0.8, 0.3), "shape": Vfx.THORN, "icon": "🌵", "rise": 60.0},
	"venom": {"from": Vector2(0, 1), "col": Color(0.55, 0.95, 0.3), "shape": Vfx.BUBBLE, "icon": "🐍", "rise": -120.0},
	"leaf": {"from": Vector2(0, -1), "col": Color(0.45, 0.85, 0.35), "shape": Vfx.FLAKE, "icon": "🍃", "rise": 160.0},
	"shadow": {"from": Vector2(1, 0), "col": Color(0.75, 0.45, 1.0), "shape": Vfx.SMOKE, "icon": "🕯", "rise": 60.0},
	"page": {"from": Vector2(1, 0), "col": Color(1.0, 0.95, 0.8), "shape": Vfx.SHARD, "icon": "📜", "rise": 200.0},
}
const POWER_THEME_OF := {"kindle": "fire", "ember_crown": "fire", "pyromancy": "fire", "avatar_of_flame": "fire",
	"rising_tide": "water", "trade_winds": "wind", "storm_crown": "wind", "echo_chamber": "wind", "attunement": "wind",
	"thorn_mantle": "thorn", "venom_coat": "venom", "world_tree_blessing": "leaf",
	"cauterize": "shadow", "stillness": "shadow", "frailty": "shadow", "grimoire": "page"}


static func power_theme(sp: Dictionary) -> Dictionary:
	var key: String = POWER_THEME_OF.get(sp.get("id", ""), "")
	if key == "":
		var p := String(sp.get("pattern", ""))
		var counts := {"F": p.count("F"), "W": p.count("W"), "A": p.count("A")}
		key = {"F": "fire", "W": "water", "A": "wind"}[counts.keys().reduce(func(a, b): return a if counts[a] >= counts[b] else b)]
	return POWER_THEMES[key]


## A Power is cast: its card flies to the middle of the screen and dissolves in its own way (burning up, melting,
## blowing away...) into particles that stream down to your statuses, where it becomes a badge for the fight.
func _power_fly(sp: Dictionary) -> void:
	var th := power_theme(sp)
	Audio.play("spell_glow")
	var card := _card_for(sp.id)
	var view_size := get_viewport_rect().size
	var card_size := Vector2(SpellCard.W, SpellCard.H)
	var start: Vector2 = card.global_position if card else Vector2(view_size.x / 2.0, 700) - card_size / 2.0
	if card:
		card.modulate.a = 0.0  # (its copy flies; the card leaves the row once the Power is used)
	# a picture of the card (so the dissolve shader can eat it)
	var pad := Vector2(12, 12)
	var vp := SubViewport.new()
	vp.size = Vector2i(card_size + pad * 2.0)
	vp.transparent_bg = true
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(vp)
	var copy := SpellCard.make(sp)
	copy.is_zoom_copy = true
	copy.position = pad
	vp.add_child(copy)
	var pic := TextureRect.new()
	pic.texture = vp.get_texture()
	pic.size = card_size + pad * 2.0
	pic.pivot_offset = pic.size / 2.0
	pic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pic.z_index = 60
	var mat := ShaderMaterial.new()
	mat.shader = load("res://assets/card/power_dissolve.gdshader")
	mat.set_shader_parameter("from", th.from)
	mat.set_shader_parameter("edge_color", th.col)
	pic.material = mat
	_fx.add_child(pic)
	pic.global_position = start - pad
	# 1. it flies to the middle of the screen and swells, glowing
	var mid := Vector2(view_size.x / 2.0, 360.0)
	var tw := pic.create_tween().set_parallel()
	tw.tween_property(pic, "global_position", mid - pic.size / 2.0, 0.4).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(pic, "scale", Vector2(1.3, 1.3), 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	await tw.finished
	var fx := Vfx.make(_fx, 70)
	fx.glow(mid, 260, Color(th.col, 0.6), 0.5)
	fx.ring(mid, 40, 220, th.col, 0.45, 6.0)
	await _wait(0.25)
	# 2. it dissolves its own way, and what it dissolves into streams down to your statuses
	var target := _status_row.global_position + Vector2(_status_row.size.x + 40.0, 16.0)
	var half := card_size * 1.3 / 2.0
	var from: Vector2 = th.from
	var across := Vector2(-from.y, from.x)
	var dur := 0.95
	var t0 := Time.get_ticks_msec() / 1000.0
	Audio.play("discovery_unlock", -4.0)
	while true:
		var t := clampf((Time.get_ticks_msec() / 1000.0 - t0) / dur, 0.0, 1.0)
		mat.set_shader_parameter("progress", t * 1.12)
		# the front: from the side that goes first, sweeping across the card
		var reach := absf(from.x) * half.x + absf(from.y) * half.y
		var front := mid + from * reach - from * (2.0 * reach) * t
		for k in 3:
			var at := front + across * randf_range(-1.0, 1.0) * (absf(across.x) * half.x + absf(across.y) * half.y)
			fx.part(at, -from * randf_range(40, 120) + Vector2(randf_range(-30, 30), randf_range(-30, 30)), th.col.lightened(randf() * 0.4), randf_range(0.35, 0.7), randf_range(4, 9), th.shape)
			if randf() < 0.45:
				fx.move(at, target + Vector2(randf_range(-20, 20), randf_range(-8, 8)), randf_range(0.45, 0.75), th.rise * randf_range(0.6, 1.2), th.col, randf_range(4, 7), 0.0)
		if t >= 1.0:
			break
		await get_tree().process_frame
	pic.queue_free()
	vp.queue_free()
	await _wait(0.55)
	# 3. it arrives: a little burst where it becomes a status
	fx = Vfx.make(_fx, 70)
	fx.ring(target, 6, 60, th.col, 0.35, 5.0)
	fx.burst(target, 14, th.col.lightened(0.3), Vector2(80, 220), Vector2(0.2, 0.4), Vector2(3, 6), th.shape)
	Audio.play("artifact_get", -6.0)


## status keyword -> art in assets/ui/new/ (New theme only)
const STATUS_ART := {"shield": "icon_armor_shield", "thorns": "status_thorns", "silence": "status_silenced", "aegis": "status_aegis",
	"echo": "status_echo_ready", "overload": "status_overload", "ethereal": "intent_ethereal", "bleed": "intent_bleed",
	"confuse": "intent_confuse", "blind": "intent_blind", "frail": "intent_frail", "lock": "intent_toll"}


func _refresh_statuses() -> void:
	for c in _status_row.get_children():
		c.queue_free()
	for b in _status_badges():
		var chip := TipPanel.new()  # its tooltip is rich text
		var col: Color = b[1]
		var pill := UiSkin.box("status_badge_pill", [17, 16, 17, 16], [14, 3, 14, 5])
		var icon: Control = UiSkin.icon(STATUS_ART.get(b[2], ""), 24) if pill != null else null
		var text: String = b[0]
		if icon != null:
			text = text.substr(text.find(" ") + 1)  # the art replaces the leading emoji
		if String(b[2]).begins_with("attune_"):
			icon = ElementIcon.make(String(b[2]).substr(7), 24)  # (Attunement: the Essence you picked)
		if pill != null:
			pill.modulate_color = col.lightened(0.15)
			chip.add_theme_stylebox_override("panel", pill)
		else:
			var sb := StyleBoxFlat.new()
			sb.bg_color = col.darkened(0.35)
			sb.border_color = col.lightened(0.45)
			sb.set_border_width_all(2)
			sb.set_corner_radius_all(14)
			sb.shadow_color = Color(col, 0.55)
			sb.shadow_size = 7
			sb.content_margin_left = 10
			sb.content_margin_right = 10
			sb.content_margin_top = 2
			sb.content_margin_bottom = 2
			chip.add_theme_stylebox_override("panel", sb)
		var l := UiTheme.label(text, 19, Color.WHITE)
		l.add_theme_constant_override("outline_size", 5)
		l.add_theme_color_override("font_outline_color", col.darkened(0.7))
		l.mouse_filter = Control.MOUSE_FILTER_IGNORE
		if icon != null:
			var hb := HBoxContainer.new()
			hb.add_theme_constant_override("separation", 4)
			hb.mouse_filter = Control.MOUSE_FILTER_IGNORE
			hb.add_child(icon)
			hb.add_child(l)
			chip.add_child(hb)
		else:
			chip.add_child(l)
		var tip: String = Keywords.K.get(b[2], [0, 0, ""])[2]
		chip.tooltip_text = b[3] if b.size() > 3 else (Keywords.tooltip(b[0], tip) if tip != "" else "")
		if b.size() > 4:
			chip.set_meta("power_id", b[4])  # (a Power's badge: Echoed Voice echoes from it)
		chip.mouse_filter = Control.MOUSE_FILTER_STOP
		_status_row.add_child(chip)


func _refresh_bottles() -> void:
	for c in _bottle_row.get_children():
		c.queue_free()
	var bs: Array = fight.player.bottles
	for i in maxi(run.bottle_slots() if run else Bottles.BASE_SLOTS, bs.size()):
		var chip := BottleChip.make(bs[i] if i < bs.size() else "", i, true)
		chip.used.connect(_on_bottle)
		_bottle_row.add_child(chip)


## Drink a bottle: on your turn, when nothing else is going on. Bottles that need an enemy ask for one first.
func _on_bottle(chip: BottleChip) -> void:
	if busy or aiming or fight.over or chant_mode != "" or pick_view != null or move_view != null:
		return
	if not (phase in ["build", "spells"]) or _released:
		return
	var i := chip.index
	var id: String = fight.player.bottles[i] if i < fight.player.bottles.size() else ""
	if id == "":
		return
	_bottle_from = chip.get_global_rect().get_center()
	var target := -1
	var bfirst: Dictionary = Bottles.get_def(id).effects[0]
	if _picks_any_essence(bfirst):
		var got := await _pick_any_essence(Bottles.as_spell(id), true)
		if got.is_empty():
			return
		target = got[0]
		_prepicked = {fight.enemies[got[0]]: got[1]}
	elif Bottles.needs_target(id):
		var cands := fight.target_candidates()
		if cands.size() == 1:
			target = cands[0]
		else:
			target = await _aim(null, _bottle_from, cands, "%s: choose a target  ·  click, or Tab + Enter  ·  right-click to put it back" % Bottles.get_def(id).name, true)
			if target < 0:
				return
	busy = true
	_undo.clear()  # a bottle is drunk for good: nothing before it can be undone
	_casting = true
	await fight.use_bottle(i, target)
	_end_casting()
	_sync_views()
	busy = false
	_refresh_all()
	if fight.over:
		await _finish()


## Grimoire Ink: choose a spell from your spellbook (not already active). Returns its index, or -1.
func _spell_chooser(spells: Array) -> int:
	if spells.is_empty():
		return -1
	var overlay := Control.new()
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.z_index = 90
	var shade := ColorRect.new()
	shade.color = Color(0, 0, 0, 0.72)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_child(shade)
	var v := VBoxContainer.new()
	v.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_theme_constant_override("separation", 18)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_child(v)
	var t := UiTheme.heading("Grimoire Ink: choose a spell to join your active spells for this fight", 28, Color(1, 0.9, 0.55))
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var ribbon := UiSkin.box("banner_grimoire_ink", [184, 0, 174, 0], [110, 10, 110, 22])
	if ribbon != null:  # New theme: the title on a paper ribbon (dark ink, not gold)
		t.add_theme_color_override("font_color", Color(0.28, 0.16, 0.1))
		var rb := PanelContainer.new()
		rb.add_theme_stylebox_override("panel", ribbon)
		rb.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		rb.custom_minimum_size = Vector2(0, 110)  # the ribbon art is cut at this height: its end curls keep their shape
		rb.add_child(t)
		v.add_child(rb)
	else:
		v.add_child(t)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(1800, 470)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var flow := HFlowContainer.new()
	flow.alignment = FlowContainer.ALIGNMENT_CENTER
	flow.custom_minimum_size = Vector2(1780, 0)
	flow.add_theme_constant_override("h_separation", 12)
	flow.add_theme_constant_override("v_separation", 12)
	scroll.add_child(flow)
	var center := CenterContainer.new()
	center.add_child(scroll)
	v.add_child(center)
	for i in spells.size():
		var card := SpellCard.make(spells[i])
		var k := i
		card.clicked.connect(func(_c): _spell_chosen.emit(k))
		flow.add_child(card)
	var skip := UiTheme.button("Keep the ink (choose nothing)", func(): _spell_chosen.emit(-1), 20)
	skip.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	v.add_child(skip)
	add_child(overlay)
	var idx: int = await _spell_chosen
	overlay.queue_free()
	return idx


# ------------------------------------------------------------------ pause menu

func _open_pause_menu() -> void:
	if _pause_overlay != null:
		return
	var saved := "Your run is saved: Continue on the main menu starts this fight over."
	var pm := PauseMenu.open(self,
		"Return to the Main Menu? " + saved if run_saved else "Abandon this run and return to the Main Menu?",
		"Quit The Last Tree? " + saved if run_saved else "Quit The Last Tree?")
	pm.resumed.connect(_close_pause_menu)
	pm.settings_closed.connect(_refresh_all)
	pm.main_menu.connect(func(): menu_requested.emit())
	_pause_overlay = pm


func _close_pause_menu() -> void:
	if _pause_overlay == null:
		return
	_pause_overlay.queue_free()
	_pause_overlay = null


# ------------------------------------------------------------------ aiming (the arrow)

func _card_point(card: SpellCard) -> Vector2:
	return card.global_position + Vector2(card.size.x * card.scale.x / 2.0, 10)


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


## Hovering an enemy's intent bubble explains what it's about to do; hovering the enemy itself (its body or its row
## of Essence) explains everything about it. Our own panel, shown after a short moment and kept beside the enemy;
## hidden while you're aiming or picking, so it never covers what you're clicking.
const HOVER_DELAY := 0.3
var _hover_panel: PanelContainer
var _hover_key := ""
var _hover_t := 0.0


func _update_hover_info(d: float, m := Vector2(-1, -1)) -> void:
	if m.x < 0.0:
		m = get_global_mouse_position()
	var key := ""
	var text := ""
	var anchor := Rect2()
	if not (aiming or _picking_any or pick_view != null or move_view != null or chant_mode != "" or _pause_overlay != null):
		for e in _views:
			var v: EnemyView = _views[e]
			if not is_instance_valid(v):
				continue
			var chip := v.intent_chip()
			# only the intent bubble explains itself (hovering the enemy shows nothing more)
			if chip != null and chip.get_global_rect().has_point(m):
				key = "intent:%d" % v.get_instance_id()
				text = chip.get_meta("info", "")
				anchor = chip.get_global_rect()
				break
			# its HP: every status on it explained (Power, Burn, Poison, armour, passives...)
			if v.hp_hovered(m):
				key = "hp:%d" % v.get_instance_id()
				text = v.info_text()
				anchor = Rect2(m - Vector2(20, 20), Vector2(40, 40))
				break
	if key != _hover_key:
		_hover_key = key
		_hover_t = 0.0
		if is_instance_valid(_hover_panel):
			_hover_panel.queue_free()
		_hover_panel = null
	if key == "" or text == "":
		return
	_hover_t += d
	if _hover_t < HOVER_DELAY or is_instance_valid(_hover_panel):
		return
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", UiTheme.get_theme().get_stylebox("panel", "TooltipPanel"))
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.z_index = 120
	var body := Keywords.make_tooltip(text)
	body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_child(body)
	add_child(p)
	_hover_panel = p
	await get_tree().process_frame
	if not is_instance_valid(p):
		return
	# beside the enemy (right if there's room, else left), kept on screen
	var x := anchor.end.x + 12.0
	if x + p.size.x > 1910.0:
		x = anchor.position.x - p.size.x - 12.0
	p.position = Vector2(clampf(x, 10.0, 1910.0 - p.size.x), clampf(anchor.position.y, 10.0, 1070.0 - p.size.y))


## The Release button shines in a slow pulse (brighter and a touch bigger) while it's the thing to press.
func _pulse_release() -> void:
	if _cast_btn == null:
		return
	if _release_glow and not busy and not _cast_btn.disabled:
		var s := 0.5 + 0.5 * sin(Time.get_ticks_msec() / 1000.0 * TAU / 1.1)
		_cast_btn.modulate = Color(1.0 + 0.45 * s, 1.0 + 0.38 * s, 1.0 + 0.15 * s)
		_cast_btn.pivot_offset = _cast_btn.size / 2.0
		_cast_btn.scale = Vector2.ONE * (1.0 + 0.06 * s)
	elif _cast_btn.scale != Vector2.ONE or _cast_btn.modulate != Color.WHITE:
		_cast_btn.modulate = Color.WHITE
		_cast_btn.scale = Vector2.ONE


func _process(_d: float) -> void:
	_update_hover_info(_d)
	_pulse_release()
	# idle while it's your move: the Seedling pops up once to help (not in the tutorial, which has its coach)
	if not busy and not fight.over and not help_override.is_valid() and _pause_overlay == null:
		_idle += _d
		if _idle >= IDLE_HELP and not _idle_helped:
			_idle_helped = true
			_last_help = Time.get_ticks_msec() / 1000.0
			_show_help()
	else:
		_idle = 0.0
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
	if _picks_any_essence(fight.current_eff):
		# a later line of the spell takes any Essence, anywhere: pick it straight from the enemies
		var got := await _pick_any_essence(spell, false)
		if not got.is_empty():
			_prepicked = {fight.enemies[got[0]]: got[1]}
			return got[0]
	if cands.size() == 1:
		return cands[0]
	var card: SpellCard = null
	for c in _cards:
		if c.spell.id == spell.id:
			card = c
	var from := _card_point(card) if card else _player_panel.global_position + Vector2(250, 0)
	var second: bool = spell.effects.any(func(x): return x.get("target", "") == "two")
	var what := "choose a SECOND, different enemy" if second else "choose a target"
	return await _aim(card, from, cands, "%s: %s  ·  click, or Tab + Enter" % [spell.name, what], false)


## Move one element of this enemy's HP: click it, then click where it goes. Esc / right-click skips.
func _mover(spell: Dictionary, e: EnemyState) -> Array:
	var v: EnemyView = _views.get(e)
	if v == null:
		return []
	move_view = v
	v.move_mode = true
	v.move_pick = -1
	_prompt.text = "%s: click an Essence of %s to pick it up  ·  right-click to skip" % [spell.name, e.name]
	_refresh_all()
	var pair: Array = await _move_done
	v.move_mode = false
	v.move_pick = -1
	move_view = null
	_refresh_all()
	return pair


## Pluck: choose which element of this enemy's HP to remove. Click it, or Tab through and Enter.
func _picker(spell: Dictionary, e: EnemyState) -> int:
	if _prepicked.has(e):
		# chosen already, straight from the enemies' Essence
		var idx: int = _prepicked[e]
		_prepicked.erase(e)
		tut.emit("picked", idx)
		return idx
	var v: EnemyView = _views.get(e)
	if v == null:
		return e.armor.find(false)
	var verb := "steal" if spell.effects.any(func(x): return x.op == "steal") else "knock off"
	var free := []
	for i in e.size():
		if not e.armor[i]:
			free.append(i)
	if free.size() <= 1:
		# no real choice (e.g. its very last element): take it without asking
		tut.emit("picking", null)
		var only: int = free[0] if free.size() == 1 else -1
		tut.emit("picked", only)
		return only
	# another pick on this enemy: the crosshair / hand again, on it only
	var again := await _pick_any_essence(spell, false, e)
	if not again.is_empty():
		tut.emit("picked", again[1])
		return again[1]
	pick_view = v
	tut.emit("picking", null)
	v.pick_mode = true
	v.pick_i = e.armor.find(false)
	_prompt.text = "%s: choose an Essence of %s to %s  ·  click it, or Tab + Enter" % [spell.name, e.name, verb]
	_callout("Choose an Essence of [b]%s[/b] to %s" % [e.name, verb], v.global_position + Vector2(v.size.x / 2.0, 120), Color(1, 0.85, 0.4), 2.5)
	_refresh_all()
	var idx: int = await _pick_done
	tut.emit("picked", idx)
	v.keep_big = v.keep_big or _casting
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


## A spell (or bottle) is being cast: enemy rows enlarged for one of its picks stay enlarged until it's all done,
## instead of shrinking between picks (Expose 2, steals and removals of several Essence).
var _casting := false


func _end_casting() -> void:
	_casting = false
	var any := false
	for v in _views.values():
		if is_instance_valid(v) and v.keep_big:
			v.keep_big = false
			any = true
	if any:
		_refresh_all()


## Take back the last spell cast this turn: the fight goes back to exactly how it was before it.
func _undo_last() -> void:
	if busy or aiming or _picking_any or phase != "spells" or _released or fight.over or _undo.is_empty() or not _allowed("undo"):
		return
	fight.restore(_undo.pop_back())
	_prepicked.clear()
	end_confirm = false
	Audio.play("elem_remove")
	# a quick cool flash over the board: time rewound
	var v := Vfx.make(_fx, 70)
	v.flash(Color(0.6, 0.75, 1.0, 0.18), 0.3)
	_sync_views()
	_build_spells()
	_refresh_all()
	tut.emit("undone", null)


## Spells that take "an Essence of your choice" (Pluck, Steal any): the choice is the Essence itself, anywhere.
func _picks_any_essence(eff: Dictionary) -> bool:
	return eff.get("op", "") == "pluck" or (eff.get("op", "") == "steal" and eff.get("el", "any") == "any")


## Every enemy's Essence becomes pickable at once; the one under the cursor lights up. Returns
## [enemy index, Essence index], or [] if it was put back (right-click, when cancellable).
func _pick_any_essence(spell: Dictionary, cancellable: bool, only: EnemyState = null, style := "") -> Array:
	var eff: Dictionary = fight.current_eff if _picks_any_essence(fight.current_eff) else {}
	if eff.is_empty():
		for e2 in spell.effects:
			if _picks_any_essence(e2):
				eff = e2
				break
	_pick_style = style if style != "" else ("hand" if eff.get("op", "") == "steal" else "shoot")
	_pick_only = only
	_picking_any = true
	_picking_any_cancellable = cancellable
	tut.emit("picking", null)
	for v in _views.values():
		v.pick_mode = only == null or v.enemy == only
		v.paint_mode = _pick_style == "brush"
		v.pick_i = -1
	# the pointer becomes a crosshair (remove), an open hand (steal) or a paint brush (Expose)
	_aim_cursor = AimCursor.new()
	_aim_cursor.mode = _pick_style
	add_child(_aim_cursor)
	Input.mouse_mode = Input.MOUSE_MODE_HIDDEN
	var how: String = {"hand": "drag an enemy's Essence down into your bag", "brush": "paint an enemy's Essence: it becomes an Any Essence"}.get(_pick_style, "shoot an enemy's Essence off")
	_prompt.text = "%s: %s%s" % [spell.name, how, "  ·  right-click to put it back" if cancellable else ""]
	_callout("[b]%s[/b]: %s" % [spell.name, how], Vector2(960, 150), Color(1, 0.85, 0.4), 2.0)
	_refresh_all()
	var got: Array = await _any_picked
	_picking_any = false
	_pick_only = null
	_steal_drag = {}
	if is_instance_valid(_aim_cursor):
		_aim_cursor.queue_free()
	_aim_cursor = null
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	for v in _views.values():
		if is_instance_valid(v):
			v.keep_big = v.keep_big or (_casting and v.pick_mode)
			v.pick_mode = false
			v.paint_mode = false
			v.pick_i = -1
	_refresh_all()
	return got


## Expose: the brush comes out and you paint one enemy Essence (anywhere) into an Any Essence. Asked once per paint.
func _painter(spell: Dictionary) -> Array:
	return await _pick_any_essence(spell, false, null, "brush")


## Remove spells: BANG. A gunshot, a muzzle flash where you aimed, the crosshair kicks, and the Essence takes a bullet
## hole before it's knocked off.
func _fire_shot(v: EnemyView, index: int) -> void:
	var at := v.hp_point(index)
	Audio.play_gunshot()
	if is_instance_valid(_aim_cursor):
		_aim_cursor.kick()
	var col: Color = Elements.COLORS.get(v.enemy.elements[index], Color.WHITE)
	var fx := Vfx.make(_fx, 80)
	fx.shaker = _shake
	fx.glow(at, 90, Color(1, 0.95, 0.75, 1.0), 0.12)
	fx.flare(at, 180, Color(1, 0.85, 0.4, 0.95), 0.14)
	fx.burst(at, 16, Color(1, 0.8, 0.35), Vector2(250, 650), Vector2(0.1, 0.25), Vector2(3, 6))
	fx.ring(at, 6, 40, Color(1, 0.9, 0.6), 0.18, 4.0)
	var hole := fx.part(at, Vector2.ZERO, Color(0.05, 0.03, 0.03, 0.95), 0.7, 9.0, Vfx.SMOKE)
	hole.size1 = 9.0
	hole.hold = 0.6
	for s in fx.burst(at, 10, col.darkened(0.2), Vector2(120, 320), Vector2(0.4, 0.7), Vector2(4, 8), Vfx.SHARD):
		s.grav = Vector2(0, 900)
		s.spin = randf_range(-12, 12)
		s.size1 = s.size0
	fx.shake(6.0)
	_shot_fired = true


## Steal: you grip an Essence; it follows your hand on a tether until you let go.
func _begin_steal_drag(v: EnemyView, index: int) -> void:
	var icon: Control = v._hp_icons[index] if index < v._hp_icons.size() else null
	if icon != null:
		icon.modulate.a = 0.3
	_steal_drag = {"enemy": v.enemy, "index": index, "el": v.enemy.elements[index], "from": v.hp_point(index), "icon": icon}
	if is_instance_valid(_aim_cursor):
		_aim_cursor.holding = _steal_drag.el
		_aim_cursor.tether_from = _steal_drag.from
	Audio.play("elem_pickup")


## Let go near your bag: it lands at the end of the bag and the spell goes through. Anywhere else: it snaps back to
## the enemy as if nothing happened, and you can try again.
func _end_steal_drag(at: Vector2) -> void:
	var d := _steal_drag
	_steal_drag = {}
	if is_instance_valid(_aim_cursor):
		_aim_cursor.holding = ""
	var bag := _stock_row.get_global_rect().grow(BAG_DROP_MARGIN)
	var ghost := ElementIcon.make(d.el, 52)
	ghost.size = Vector2(52, 52)
	ghost.z_index = 150
	ghost.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ghost.position = at - ghost.size / 2.0 - _fx.global_position
	_fx.add_child(ghost)
	if bag.has_point(at):
		var to := _stock_row.global_position + Vector2(minf(_stock_row.size.x - 52.0, _bag_icons.size() * (BAG_PX + BAG_GAP)), 0) - _fx.global_position
		var tw := ghost.create_tween()
		tw.tween_property(ghost, "position", to, 0.2).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		tw.tween_callback(ghost.queue_free)
		Audio.play("elem_remove")
		_any_picked.emit([fight.enemies.find(d.enemy), d.index])
	else:
		var tw := ghost.create_tween()
		tw.tween_property(ghost, "position", d.from - ghost.size / 2.0 - _fx.global_position, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_callback(func():
			ghost.queue_free()
			if is_instance_valid(d.icon):
				d.icon.modulate.a = 1.0)


func _on_hp_clicked(v: EnemyView, index: int) -> void:
	if _picking_any:
		if _pick_only != null and v.enemy != _pick_only:
			return
		if _pick_style == "brush":
			if index < v.enemy.size() and v.enemy.elements[index] != "?" and _allowed("pick", index):
				if is_instance_valid(_aim_cursor):
					_aim_cursor.kick()  # the brush presses down
				_any_picked.emit([fight.enemies.find(v.enemy), index])
			return
		if index < v.enemy.size() and not v.enemy.armor[index] and _allowed("pick", index) and _steal_drag.is_empty():
			if _pick_style == "hand":
				_begin_steal_drag(v, index)  # the pick happens when it's dropped on the bag
			else:
				_fire_shot(v, index)
				_any_picked.emit([fight.enemies.find(v.enemy), index])
		return
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
		_prompt.text = "Click an Essence to pick it up  ·  right-click to skip"
		v.refresh({})
		return
	_move_done.emit([v.move_pick, index])


func _emit_chant_done(i: int) -> void:
	if _allowed("place", i):
		_chant_done.emit(i)


## Infuse: the new element appears at the end of the chant, shining; drag it where it should go
## (or Left / Right + Enter).
func _placer(spell: Dictionary, el: String) -> int:
	chant_mode = "insert"
	tut.emit("placing", null)
	chant_i = fight.chant.size()
	_prompt.text = "%s: drag the glowing %s from the card into your chant" % [spell.name, Elements.NAMES[el]]
	_refresh_all()
	_spawn_infuse_orb(spell, el)
	var i: int = await _chant_done
	_infuse_dragging = false
	if is_instance_valid(_infuse_orb):
		_infuse_orb.queue_free()
	_infuse_orb = null
	await _hide_drag()
	chant_mode = ""
	_refresh_all()
	tut.emit("placed", i)
	return i


## The infused element pops out of its spell's card and waits there, glowing and wiggling, to be grabbed.
func _spawn_infuse_orb(spell: Dictionary, el: String) -> void:
	var card := _card_for(spell.id)
	var at := (card.global_position + Vector2(card.size.x * card.scale.x / 2.0, -42)) if card else Vector2(960, 480)  # just above the card
	# first the spell's own elements twist together on the card and fuse into the new one
	var born := at
	if card:
		born = await _fuse_on_card(card, el)
		if chant_mode != "insert" or not is_inside_tree():
			return  # it was placed some other way (keyboard) while the elements were fusing
	var px := 64.0
	var orb := ElementIcon.make(el, px)
	orb.size = Vector2(px, px)
	orb.pivot_offset = orb.size / 2.0
	orb.position = born - orb.size / 2.0
	orb.create_tween().tween_property(orb, "position", at - orb.size / 2.0, 0.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT).set_delay(0.12)
	orb.z_index = 60
	orb.highlight = true
	orb.mouse_filter = Control.MOUSE_FILTER_STOP
	orb.mouse_default_cursor_shape = Control.CURSOR_DRAG
	orb.tooltip_text = "Drag me into your chant"
	orb.gui_input.connect(func(ev): if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT: _infuse_grab(ev.global_position))
	add_child(orb)
	_infuse_orb = orb
	_infuse_el = el
	orb.scale = Vector2(0.2, 0.2)
	var pop := orb.create_tween()
	pop.tween_property(orb, "scale", Vector2(1.15, 1.15), 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	pop.tween_property(orb, "scale", Vector2.ONE, 0.1)
	var wig := orb.create_tween().set_loops()
	wig.tween_property(orb, "rotation", 0.14, 0.18).set_trans(Tween.TRANS_SINE)
	wig.tween_property(orb, "rotation", -0.14, 0.18).set_trans(Tween.TRANS_SINE)
	var glow := orb.create_tween().set_loops()
	glow.tween_property(orb, "modulate", Color(1.5, 1.45, 1.2), 0.5).set_trans(Tween.TRANS_SINE)
	glow.tween_property(orb, "modulate", Color.WHITE, 0.5).set_trans(Tween.TRANS_SINE)
	Audio.play("spell_glow")


## The card's pattern elements lift off its face, spiral around each other while drawing together, spinning
## and brightening, then fuse in a flash where the new element is born. Returns that point (on the card).
func _fuse_on_card(card: SpellCard, el: String) -> Vector2:
	var icons := []
	var starts := []
	for o in card.live_orbs():
		if not (o is ElementIcon):
			continue
		var r: Rect2 = o.get_global_rect()
		var ic := ElementIcon.make(o.el, r.size.x)
		ic.size = r.size
		ic.pivot_offset = r.size / 2.0
		ic.position = r.position
		ic.z_index = 61
		ic.highlight = true
		ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(ic)
		icons.append(ic)
		starts.append(r.get_center())
	var center: Vector2 = card._pat.get_global_rect().get_center()
	if icons.is_empty():
		return center
	Audio.play("spell_glow")
	var dur := 1.1
	var twist := func(t: float) -> void:
		var e := t * t * (3.0 - 2.0 * t)
		for k in icons.size():
			var ic: ElementIcon = icons[k]
			if not is_instance_valid(ic):
				continue
			# spiral in: each keeps turning around the centre while its distance shrinks to nothing
			var off: Vector2 = starts[k] - center
			var lift := Vector2(0, -18.0 * sin(e * PI))
			ic.position = center + off.rotated(e * TAU * 1.4) * (1.0 - e) + lift - ic.size / 2.0
			ic.rotation = e * TAU * 1.5
			ic.scale = Vector2.ONE * (1.0 + 0.25 * sin(e * PI) - 0.3 * e)
			ic.modulate = Color.WHITE.lerp(Color(2.4, 2.3, 2.0), e)
	create_tween().tween_method(twist, 0.0, 1.0, dur)
	await _wait(dur)
	for ic in icons:
		if is_instance_valid(ic):
			ic.queue_free()
	# the flash of the fusion
	ShardBurst.burst(_fx, center, Elements.COLORS.get(el, Color.WHITE), 34.0)
	Audio.play("elem_pickup")
	_shake(4.0)
	return center


## Picked up from the card: the chant becomes a live row that opens a gap wherever you hold it.
func _infuse_grab(pointer: Vector2) -> void:
	if _infuse_dragging or not is_instance_valid(_infuse_orb):
		return
	_infuse_orb.visible = false
	var els: Array = fight.chant.duplicate()
	els.append(_infuse_el)
	var live := []
	for k in els.size():
		live.append(k == els.size() - 1)
	for c in _chant_row.get_children():
		c.queue_free()
	var d := ChantDrag.new()
	d.els = els
	d.live = live
	d.slots = _chant_rings()
	var lay := _chant_layout(els.size())
	d.px = lay.x
	d.sep = lay.y
	_chant_row.add_child(d)
	d.begin_external(els.size() - 1, pointer)
	_drag = d
	_infuse_dragging = true
	Audio.play("elem_pickup")


## Let go: over the chant it's placed there; anywhere else it floats back to the card to wait.
func _infuse_drop() -> void:
	var res: Dictionary = _drag.external_result()
	_infuse_dragging = false
	if res.inside and _allowed("place", res.to):
		_chant_done.emit(res.to)
		return
	_drag.queue_free()
	_drag = null
	_refresh_chant()
	if is_instance_valid(_infuse_orb):
		_infuse_orb.visible = true
		_infuse_orb.scale = Vector2(0.6, 0.6)
		_infuse_orb.create_tween().tween_property(_infuse_orb, "scale", Vector2.ONE, 0.15)


## Rearrange: every chant element comes alive; drag one to another spot (right-click keeps the chant as it is).
func _arranger(spell: Dictionary) -> Array:
	chant_mode = "arrange"
	var live := []
	for c in fight.chant:
		live.append(true)
	_show_drag(fight.chant.duplicate(), live, true)
	_prompt.text = "%s: grab any Essence of your chant and drag it to another spot  ·  Tab + Left / Right + Enter  ·  right-click: keep it" % spell.name
	_refresh_all()
	_drag.dropped.connect(func(from, to): _arrange_done.emit([from, to]))
	var mv: Array = await _arrange_done
	await _hide_drag()
	chant_mode = ""
	_refresh_all()
	return mv


func _show_drag(els: Array, live: Array, same_spot_is_no_move: bool) -> void:
	for c in _chant_row.get_children():
		c.queue_free()
	var d := ChantDrag.new()
	d.els = els
	d.live = live
	d.slots = _chant_rings()
	var lay := _chant_layout(els.size())
	d.px = lay.x
	d.sep = lay.y
	d.same_spot_is_no_move = same_spot_is_no_move
	_chant_row.add_child(d)
	_drag = d


## Let the dropped element settle for a moment, then hand the row back to the normal chant view.
func _hide_drag() -> void:
	await _wait(0.3)
	if is_instance_valid(_drag):
		_drag.queue_free()
	_drag = null


## Resonance: choose the chant element to copy.
func _chant_picker(spell: Dictionary) -> int:
	chant_mode = "pick"
	chant_i = 0
	_prompt.text = "%s: which Essence of the chant should be duplicated?  ·  click it, or Tab + Enter" % spell.name
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
		"conjure_split":
			# the conjuring spell glitches into static, then splits into its conjured spells, which slide into place
			var src := _card_for(ev.source)
			var from := src.global_position if src else Vector2(960, 560)
			Audio.play("spell_glow")
			if src:
				await src.static_up(0.3)
			_build_spells()
			await get_tree().process_frame
			for id in ev.ids:
				var c := _card_for(id)
				if c:
					c.static_in(from)
			Audio.play("elem_pickup")
			await _wait(0.5)
			_refresh_all()
		"conjure_merge":
			# the conjured spells still in the row (or the last one, just cast) glitch into static, slide together, and
			# settle back into the spell that conjured them
			var cards := []
			for id in ev.ids:
				var c := _card_for(id)
				if c:
					cards.append(c)
			var meet := Vector2(960, 560)
			if not cards.is_empty():
				meet = Vector2.ZERO
				for c in cards:
					meet += c.global_position
				meet /= cards.size()
				for c in cards:
					c.static_out_to(meet)
				Audio.play("elem_remove", -2.0)
				await _wait(0.4)
			_build_spells()
			await get_tree().process_frame
			var back := _card_for(ev.source)
			if back:
				Audio.play("spell_glow")
				await back.static_in(meet)
			_refresh_all()
		"ephemeral_gone":
			# like an old TV switching off: static, a bright line, a dot, gone
			var any := false
			for id in ev.ids:
				var card := _card_for(id)
				if card:
					card.fizzle_out()
					any = true
			if any:
				Audio.play("elem_remove", -2.0)
				await _wait(0.75)
			_build_spells()
			_refresh_all()
		"bottle":
			# the cork pops: a burst of light from the bottle
			Audio.play("elem_pickup")
			var v := Vfx.make(_fx)
			v.shaker = _shake
			v.glow(_bottle_from, 120, Color(0.6, 0.95, 1.0, 0.9), 0.35)
			v.ring(_bottle_from, 10, 90, Color(0.6, 0.95, 1.0), 0.4, 6.0)
			v.burst(_bottle_from, 18, Color(0.75, 1.0, 1.0), Vector2(120, 380), Vector2(0.3, 0.6), Vector2(4, 8), Vfx.STAR)
			_refresh_all()
			await _wait(0.3)
		"artifact_used":
			_arts.flash(ev.id)
			Audio.play("spell_glow")
		"chant":
			_prompt.text = "Chanting " + " ".join(Array(ev.chant.split("")).map(func(c): return Elements.NAMES[c]))
			await _wait(0.25)
		"paint":
			# Expose: a blotch of rainbow paint slaps onto the Essence, then fades away to reveal the Any Essence
			var pv: EnemyView = _views.get(ev.enemy)
			if pv:
				# the row just left pick mode: let it settle at its normal size before aiming at the orb
				await get_tree().process_frame
				await get_tree().process_frame
				var splash := PaintSplash.new()
				var ic: Control = pv._hp_icons[ev.index] if ev.index < pv._hp_icons.size() else null
				splash.radius = (ic.size.x if ic else 40.0) * 0.62
				splash.position = pv.hp_point(ev.index) - _fx.global_position
				_fx.add_child(splash)
				Audio.play("sfx_expose_apply")
				splash.play(_refresh_all)  # the icon underneath turns Any while the paint covers it
				await _wait(0.5)
			else:
				_refresh_all()
		"strike":
			_step_pos = -1
			var v: EnemyView = _views.get(ev.enemy)
			if v:
				v.hit_flash()  # it jolts, blinks and winces; the burst orbs show how much it lost
			Audio.play("sfx_damage_hit")
			_refresh_all()
			await _wait(0.35)
		"chant_step":
			await _release_step(ev)
		"chant_changed":
			Audio.play("elem_pickup")
			_refresh_all()
			await _wait(0.35)
		"loadout_changed":
			Audio.play("discovery_unlock")
			_build_spells()
			_refresh_all()
			await _wait(0.4)
		"charged":
			# every woken spell's chant elements light up and fly into its card, all at once
			_refresh_chant()  # the spoken chant must be on the table before its elements can fly
			await get_tree().process_frame
			var hits: Array = ev.get("hits", [])
			# read the whole chant, left to right, note by note
			var all := []
			for i in fight.chant.size():
				all.append(i)
			await _sing(all, hits)
			for h in hits:
				var card := _card_for(h.id)
				if card:
					card.charges = 0
					card.fires = 0
					card.refresh()
			await _wake_fx(hits, false)
			_refresh_all()
			await _wait(0.3)
		"extension":
			# the chant changed and woke more spells: the same flight (all at once), then an "Extension!" slam each.
			# Show the spell just cast as spent, but hold back the new charges until their elements land.
			_refresh_all()
			for h in ev.hits:
				var card := _card_for(h.id)
				if card:
					card.charges = fight.charges.get(h.id, 0) - h.starts.size()
					card.refresh()
			# sing again, but only the elements that woke these spells
			var used := {}
			for h in ev.hits:
				for st in h.starts:
					for k in h.len:
						used[st + k] = true
			var idx := used.keys()
			idx.sort()
			await _sing(idx, ev.hits)
			await _wake_fx(ev.hits, true)
			_refresh_all()
		"spell":
			if ev.spell.id == "attunement":
				# no dissolve: its Essence fly out of the card for you to pick one (_attune_chooser)
				var c := _card_for(ev.spell.id)
				if c:
					c.create_tween().tween_property(c, "modulate:a", 0.0, 0.25)
				Audio.play("spell_glow")
				return
			if ev.spell.get("power", false):
				await _power_fly(ev.spell)
				return
			Audio.play("spell_glow")
			# the card lifts and glows (its text is right there on the card)
			var card := _card_for(ev.spell.id)
			if card:
				var tw := card.create_tween()
				tw.tween_property(card, "modulate", Color(1.5, 1.4, 1.1), 0.12)
				tw.tween_property(card, "modulate", Color.WHITE, 0.4)
			await _wait(0.4)
		"spell_effect":
			await _spell_fly(ev)
		"echo_voice":
			# Echoed Voice: its badge flashes, and a beat later the effect fires again from it
			var badge := _power_badge("echo_chamber")
			if badge:
				var tw := badge.create_tween()
				tw.tween_property(badge, "modulate", Color(1.8, 1.6, 2.0), 0.08)
				tw.tween_property(badge, "modulate", Color.WHITE, 0.3)
			await _wait(0.25)
		"echo_chamber":
			# the Echo Chamber shines, and a beat later the same effect fires again from it
			_arts.flash("echo_chamber")
			await _wait(0.25)
		"effect":
			var snd: String = EFFECT_SFX.get(ev.op, "")
			if snd != "":
				Audio.play(snd)
			_effect_landed(ev)
			_sync_views()
			_refresh_all()
			await _wait(0.3)
		"enemy_turn":
			await _enemy_turn_start(ev)
		"enemy_done":
			for v in _views.values():
				v.modulate = Color.WHITE
			await _file_turn_box()
		"attack":
			await _enemy_attack(ev)
		"enemy_move":
			await _enemy_move_fx(ev)
		"dot":
			var v: EnemyView = _views.get(ev.enemy)
			if v:
				v.hit_flash()
			if ev.get("burn", false):
				Audio.play("sfx_burn_tick")
			if ev.get("poison", false):
				Audio.play("sfx_poison_tick")
			_refresh_all()
			await _wait(0.5)
		"annihilate":
			await _annihilate_enemies(ev.el, ev.targets)
		"burn_off":
			# the Essence that caught fire last turn burns away
			var v: EnemyView = _views.get(ev.enemy)
			if v:
				v.hit_flash()
				_float_text("-%d  Burned" % ev.n, v.global_position + Vector2(90, 200), Color(1, 0.6, 0.25))
			Audio.play("sfx_burn_tick")
			_sync_views()
			_refresh_all()
			await _wait(0.5)
		"mend":
			Audio.play("sfx_mend")
			_sync_views()
			_refresh_all()
			await _wait(0.2)
		"stolen":
			# the stolen orbs fly from the enemy into your elements
			var v: EnemyView = _views.get(ev.enemy)
			var from := (v.creature.global_position + v.creature.size / 2.0) if v else Vector2(960, 300)
			var to := _stock_row.global_position + Vector2(_stock_row.size.x * 0.4, 30)
			for el in ev.els:
				Comet.launch(_fx, from, to, Elements.COLORS[el])
			if not ev.els.is_empty():
				_float_text("Stolen: " + " ".join(ev.els), from + Vector2(-60, -40), Color(0.5, 0.9, 1))
			await _wait(0.5)
			_refresh_all()
		"unlock":
			Audio.play("sfx_lock_break")
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
		"invert_spells":
			# some of your spells flip (spell <-> anti-spell): the row is rebuilt with their new look
			Audio.play("sfx_silence_apply")
			_build_spells()
			_refresh_all()
			await _wait(0.6)
		"charge_tick":
			_refresh_all()
			await _wait(0.3)
		"ignite_spell":
			Audio.play("sfx_burn_apply")
			_refresh_all()
			await _wait(0.15)
		"ignite_burn":
			# the burning card scorches you
			Audio.play("sfx_burn_apply")
			var card := _card_for(ev.id)
			if card:
				var fx := Vfx.make(_fx, 70)
				fx.burst(card.global_position + card.size * card.scale / 2.0, 16, Color(1.0, 0.55, 0.2), Vector2(80, 240), Vector2(0.25, 0.5), Vector2(4, 8), Vfx.SPARK)
			_shake(5.0)
			_refresh_all()
			await _wait(0.25)
		"bleed_tick":
			Audio.play("sfx_bleed_tick")
			_refresh_all()
			await _wait(0.15)
		_:
			_sync_views()
			_refresh_all()
			await _wait(0.25)


## The chant elements that woke these spells all light up at once (an Extension's also wiggle), lift off together
## and fly into their cards; every card flashes and comes alive as they land. An element that feeds two spells
## sends a comet to each. For an Extension, the slams follow: "Extension!", "Double Extension!", ...
## The chant is read out: left to right, each element hops, shines and sings its note, and the orb it fills
## on every spell it helps wake shines at the same moment.
func _sing(indices: Array, hits: Array) -> void:
	for i in indices:
		if not is_inside_tree():
			return
		# looked up afresh for every note: the chant row or a card may have been rebuilt while we waited
		var slots := _chant_row.get_children().filter(func(c): return c is Panel and not c.is_queued_for_deletion())
		if i < slots.size():
			for ic in slots[i].get_children():
				if ic is ElementIcon:
					_hop(ic, 18.0)
					Audio.play_note(ic.el)
		for h in hits:
			var card := _card_for(h.id)
			if card == null or not is_instance_valid(card._pat):
				continue
			for st in h.starts:
				if i >= st and i < st + h.len:
					var orbs := card.live_orbs()
					if i - st < orbs.size():
						_hop(orbs[i - st], 10.0)
		await _wait(0.3)
	await _wait(0.2)


## One quick hop with a shine, then back to rest.
func _hop(ic: Control, height: float) -> void:
	if not is_instance_valid(ic):
		return
	ic.pivot_offset = ic.size / 2.0
	if ic is ElementIcon:
		ic.highlight = true
		ic.queue_redraw()
	var tw := ic.create_tween()
	tw.tween_property(ic, "position:y", ic.position.y - height, 0.11).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(ic, "modulate", Color(1.9, 1.85, 1.6), 0.11)
	tw.parallel().tween_property(ic, "scale", Vector2(1.22, 1.22), 0.11)
	tw.tween_property(ic, "position:y", ic.position.y, 0.22).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(ic, "modulate", Color.WHITE, 0.35)
	tw.parallel().tween_property(ic, "scale", Vector2.ONE, 0.22)
	tw.tween_callback(func():
		if is_instance_valid(ic) and ic is ElementIcon:
			ic.highlight = false
			ic.queue_redraw())


func _wake_fx(hits: Array, extension: bool) -> void:
	var slots := _chant_row.get_children().filter(func(c): return c is Panel)
	var flights := []  # [icon, card]
	var lit := {}
	for h in hits:
		var card := _card_for(h.id)
		if card == null:
			continue
		for st in h.starts:
			for k in h.len:
				var i: int = st + k
				if i >= slots.size():
					continue
				if not is_instance_valid(slots[i]):
					continue
				for ch in slots[i].get_children():
					if ch is ElementIcon:
						flights.append([ch, card])
						lit[ch] = true
	if flights.is_empty():
		for h in hits:
			var card := _card_for(h.id)
			if card:
				card.charges = fight.charges.get(h.id, 0)
				card.refresh()
				var fl := card.create_tween()
				fl.tween_property(card, "modulate", Color(2.0, 1.6, 2.0), 0.08)
				fl.tween_property(card, "modulate", Color.WHITE, 0.3)
		if not hits.is_empty():
			Audio.play("spell_glow")
			await _wait(0.3)
		return
	for ic in lit:
		ic.highlight = true
		ic.queue_redraw()
		ic.pivot_offset = ic.size / 2.0
		var tw: Tween = ic.create_tween()
		if extension:
			for w in 3:
				tw.tween_property(ic, "rotation", 0.35, 0.05)
				tw.tween_property(ic, "rotation", -0.35, 0.05)
			tw.tween_property(ic, "rotation", 0.0, 0.05)
		tw.tween_property(ic, "scale", Vector2(1.3, 1.3), 0.14)
		tw.tween_property(ic, "scale", Vector2.ONE, 0.22)
	Audio.play("spell_glow")
	await _wait(0.5 if extension else 0.35)
	# everything lifts off at once
	var sounds := {}
	for fl in flights:
		if not is_instance_valid(fl[0]) or not is_instance_valid(fl[1]):
			continue  # the chant row or the card was rebuilt meanwhile
		var ic: ElementIcon = fl[0]
		var card: SpellCard = fl[1]
		var to := card.global_position + card.size * card.scale / 2.0
		var cm := Comet.launch(_fx, ic.global_position + ic.size / 2.0, to, Elements.COLORS.get(ic.el, Color(1, 0.9, 0.4)))
		cm.dur = 0.55
		cm.rise = 110.0
		if not sounds.has(ic.el):
			sounds[ic.el] = true
			Audio.play(LAUNCH_SFX.get(ic.el, "elem_pickup"), -4.0)
	await _wait(0.58)
	for ic in lit:
		if is_instance_valid(ic):
			ic.highlight = false
			ic.queue_redraw()
	for h in hits:
		var card := _card_for(h.id)
		if card == null:
			continue
		card.charges = fight.charges.get(h.id, 0)
		card.refresh()
		var fl := card.create_tween()
		fl.tween_property(card, "modulate", Color(2.2, 2.0, 1.4), 0.07)
		fl.tween_property(card, "modulate", Color.WHITE, 0.3)
	Audio.play("spell_glow")
	if extension:
		for k in hits.size():
			await _extension_slam(k + 1)
			await _wait(0.15)
	else:
		await _wait(0.15)


const EXTENSION_NAMES := ["Extension!", "Double Extension!", "Triple Extension!", "Quadruple Extension!", "Quintuple Extension!"]
const SLAM_ANGLE := -35.0  # degrees: low on the left, high on the right


## "Extension!" slams onto the table at a slant (low left, high right): it drops in huge, hits with a shake and a
## burst of sparks along its length, and fades. The 2nd one this turn says "Double Extension!", and so on.
func _extension_slam(count := 1) -> void:
	var text: String = EXTENSION_NAMES[count - 1] if count <= EXTENSION_NAMES.size() else "%d× Extension!" % count
	await _slam(text, Color(1.0, 0.86, 0.25), Color(0.4, 0.08, 0.0), 128 if count == 1 else 104)


## Big slanted words slapped onto the table (Extension!, Perfect!): they drop in huge, hit with a shake and a
## burst of sparks along their length, bounce, and fade.
func _slam(text: String, col: Color, outline: Color, font_px: int) -> void:
	var l := Label.new()
	l.text = text
	var f := SystemFont.new()
	f.font_names = PackedStringArray(["Impact", "Arial Black", "Segoe UI Black", "Arial"])
	f.font_weight = 900
	f.font_italic = true
	l.add_theme_font_override("font", UiTheme.with_fallbacks(f))
	l.add_theme_font_size_override("font_size", font_px)
	l.add_theme_color_override("font_color", col)
	l.add_theme_constant_override("outline_size", 22)
	l.add_theme_color_override("font_outline_color", outline)
	l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.6))
	l.add_theme_constant_override("shadow_offset_x", 8)
	l.add_theme_constant_override("shadow_offset_y", 10)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.size = Vector2(1500, 200)
	l.position = Vector2(960 - 750, 330)
	l.pivot_offset = l.size / 2.0
	l.scale = Vector2(3.4, 3.4)
	l.rotation = deg_to_rad(SLAM_ANGLE - 12.0)
	l.modulate.a = 0.0
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.z_index = 60
	_fx.add_child(l)
	var tw := l.create_tween().set_parallel(true)
	tw.tween_property(l, "scale", Vector2.ONE, 0.16).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_property(l, "modulate:a", 1.0, 0.08)
	tw.tween_property(l, "rotation", deg_to_rad(SLAM_ANGLE), 0.16)
	await tw.finished
	# the hit
	_shake(16.0)
	Audio.play("boss_phase_change")
	var along := Vector2.from_angle(deg_to_rad(SLAM_ANGLE))
	for k in 4:
		ImpactFx.burst(_fx, l.position + l.size / 2.0 + along * randf_range(-420, 420), false)
	var bounce := l.create_tween()
	bounce.tween_property(l, "scale", Vector2(1.12, 0.9), 0.06)
	bounce.tween_property(l, "scale", Vector2(0.96, 1.05), 0.08)
	bounce.tween_property(l, "scale", Vector2.ONE, 0.1)
	await _wait(0.6)
	var out := l.create_tween().set_parallel(true)
	out.tween_property(l, "modulate:a", 0.0, 0.3)
	out.tween_property(l, "position:y", l.position.y - 60.0, 0.3)
	out.chain().tween_callback(l.queue_free)
	await _wait(0.15)


## New theme: the end-of-fight banner ("victory" / "perfect" / "defeat"), built from separate painted layers that all share
## one size, so they line up when laid on top of each other. The ribbon falls first and lands with a thud, then the
## lettering falls onto it. For "perfect" the word PERFECT then flickers on above it, in front. Returns false (and
## shows nothing) when the Theme is Default or the art is missing, so the caller falls back to the old slam text.
## How far PERFECT is lifted above its place in the art (it overlapped VICTORY by ~80 px there).
const PERFECT_RAISE := 60.0


func _result_banner(kind: String) -> bool:
	var ribbon := UiSkin.tex(kind + "_banner")
	var lettering := UiSkin.tex(kind + "_text")
	if ribbon == null or lettering == null:
		return false
	var word := UiSkin.tex("perfect_word") if kind == "perfect" else null
	var stage := Control.new()
	stage.size = ribbon.get_size()
	stage.position = Vector2(960.0 - stage.size.x / 2.0, 600.0 - stage.size.y)  # the ribbon's lower edge rests at y=600
	stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stage.z_index = 60
	_fx.add_child(stage)
	var layers := {}
	for part in ["banner", "text", "word"]:  # PERFECT last, so it sits in front of the ribbon and VICTORY
		var tex: Texture2D = {"word": word, "banner": ribbon, "text": lettering}[part]
		if tex == null:
			continue
		var r := TextureRect.new()
		r.texture = tex
		r.size = stage.size
		r.pivot_offset = stage.size / 2.0
		r.mouse_filter = Control.MOUSE_FILTER_IGNORE
		r.modulate.a = 0.0
		if part == "word":
			r.position.y = -PERFECT_RAISE  # above VICTORY instead of tucked behind it
		stage.add_child(r)
		layers[part] = r
	var drop := stage.size.y + 520.0
	var down := func(r: TextureRect, from_scale: float, fall: float) -> void:
		r.position.y = -drop
		r.scale = Vector2.ONE * from_scale
		r.modulate.a = 0.0
		var tw := r.create_tween().set_parallel(true)
		tw.tween_property(r, "position:y", 0.0, fall).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tw.tween_property(r, "scale", Vector2.ONE, fall).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tw.tween_property(r, "modulate:a", 1.0, fall * 0.4)
		await tw.finished
	var thud := func(r: TextureRect, shake_px: float, vol: float) -> void:
		_shake(shake_px)
		Audio.play("boss_phase_change", vol)
		for k in 3:
			ImpactFx.burst(_fx, stage.global_position + stage.size * Vector2(randf_range(0.15, 0.85), randf_range(0.35, 0.85)), false)
		var sq := r.create_tween()
		sq.tween_property(r, "scale", Vector2(1.05, 0.93), 0.06)
		sq.tween_property(r, "scale", Vector2(0.99, 1.03), 0.08)
		sq.tween_property(r, "scale", Vector2.ONE, 0.1)
	await down.call(layers["banner"], 1.12, 0.3)
	thud.call(layers["banner"], 18.0 if kind != "defeat" else 10.0, 0.0)
	await _wait(0.34)
	await down.call(layers["text"], 1.5, 0.22)
	thud.call(layers["text"], 12.0 if kind != "defeat" else 7.0, -5.0)
	await _wait(0.3)
	if word != null:  # PERFECT blinks on, above VICTORY
		var w: TextureRect = layers["word"]
		var fl := w.create_tween()
		for a in [1.0, 0.15, 1.0, 0.25, 1.0, 0.4, 1.0]:
			fl.tween_property(w, "modulate:a", a, 0.09)
		await fl.finished
		var glow := w.create_tween().set_loops(3)
		glow.tween_property(w, "modulate", Color(1.5, 1.3, 1.3), 0.25)
		glow.tween_property(w, "modulate", Color.WHITE, 0.25)
		await _wait(1.0)
	else:
		await _wait(0.9)
	var out := stage.create_tween().set_parallel(true)
	out.tween_property(stage, "modulate:a", 0.0, 0.3)
	out.tween_property(stage, "position:y", stage.position.y - 40.0, 0.3)
	out.chain().tween_callback(stage.queue_free)
	await _wait(0.15)
	return true


# ------------------------------------------------------------------ Annihilate

var _choosing_el := false


## The screen dims; Fire, Water and Air float softly out of the card and shine. Pick one (click, or F / W / A):
## the other two drift back into the card and vanish, and the chosen one shakes violently, cracks and shatters.
## Attunement: the screen dims, the card's Essence shine and fly to the middle; you click one, and it flies down to
## your statuses, where it becomes a badge (+1 of it each turn).
func _attune_chooser(spell: Dictionary) -> String:
	var card := _card_for(spell.id)
	var from := (card.global_position + card.size * card.scale / 2.0) if card else Vector2(960, 620)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	dim.z_index = 70
	add_child(dim)
	dim.create_tween().tween_property(dim, "color:a", 0.7, 0.35)
	var title := UiTheme.label("%s: pick an Essence to gain every turn" % spell.name, 34, Color(1.0, 0.92, 0.7))
	title.add_theme_constant_override("outline_size", 8)
	title.add_theme_color_override("font_outline_color", Color.BLACK)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.size = Vector2(1920, 50)
	title.position = Vector2(0, 250)
	title.z_index = 72
	title.modulate.a = 0.0
	add_child(title)
	title.create_tween().tween_property(title, "modulate:a", 1.0, 0.4)
	var els := []
	for ch in String(spell.get("pattern", "FWA")):
		if ch in ["F", "W", "A"] and not (ch in els):
			els.append(ch)
	if els.is_empty():
		els = ["F", "W", "A"]
	var orbs := {}
	var px := 120.0
	for i in els.size():
		var el: String = els[i]
		var ic := ElementIcon.make(el, px)
		ic.size = Vector2(px, px)
		ic.pivot_offset = ic.size / 2.0
		ic.position = from - ic.size / 2.0
		ic.scale = Vector2(0.3, 0.3)
		ic.z_index = 72
		ic.highlight = true
		ic.mouse_filter = Control.MOUSE_FILTER_STOP
		ic.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		add_child(ic)
		var to := Vector2(960 + (i - (els.size() - 1) / 2.0) * 260, 440) - ic.size / 2.0
		var tw := ic.create_tween().set_parallel(true)
		tw.tween_property(ic, "position", to, 0.8).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT).set_delay(i * 0.12)
		tw.tween_property(ic, "scale", Vector2.ONE, 0.8).set_trans(Tween.TRANS_SINE).set_delay(i * 0.12)
		var glow := ic.create_tween().set_loops()
		glow.tween_property(ic, "modulate", Color(1.7, 1.6, 1.4), 0.6).set_trans(Tween.TRANS_SINE)
		glow.tween_property(ic, "modulate", Color(1.2, 1.15, 1.05), 0.6).set_trans(Tween.TRANS_SINE)
		ic.gui_input.connect(func(ev): if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT: _element_chosen.emit(el))
		orbs[el] = ic
	Audio.play("spell_glow")
	_choosing_el = true
	var chosen: String = await _element_chosen
	_choosing_el = false
	title.create_tween().tween_property(title, "modulate:a", 0.0, 0.25)
	# the others fade away; the chosen one flies down to your statuses
	for el in orbs:
		var o: ElementIcon = orbs[el]
		o.mouse_filter = Control.MOUSE_FILTER_IGNORE
		if el != chosen:
			var gone := o.create_tween().set_parallel(true)
			gone.tween_property(o, "scale", Vector2(0.3, 0.3), 0.4)
			gone.tween_property(o, "modulate:a", 0.0, 0.4)
			gone.chain().tween_callback(o.queue_free)
	var ic: ElementIcon = orbs[chosen]
	var target := _status_row.global_position + Vector2(_status_row.size.x + 40.0, 16.0)
	var fly := ic.create_tween().set_parallel(true)
	fly.tween_property(ic, "position", target - ic.size / 2.0, 0.6).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN).set_delay(0.15)
	fly.tween_property(ic, "scale", Vector2(0.22, 0.22), 0.6).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN).set_delay(0.15)
	var fade := dim.create_tween()
	fade.tween_property(dim, "color:a", 0.0, 0.5)
	fade.tween_callback(dim.queue_free)
	await fly.finished
	ic.queue_free()
	title.queue_free()
	# it arrives: a little burst where it becomes a badge
	var col: Color = Elements.COLORS[chosen]
	var fx := Vfx.make(_fx, 70)
	fx.ring(target, 6, 60, col, 0.35, 5.0)
	fx.burst(target, 14, col.lightened(0.3), Vector2(80, 220), Vector2(0.2, 0.4), Vector2(3, 6), Vfx.GLOW)
	Audio.play("artifact_get", -6.0)
	return chosen


func _element_chooser(spell: Dictionary, counts: Dictionary) -> String:
	var card := _card_for(spell.id)
	var from := (card.global_position + card.size * card.scale / 2.0) if card else Vector2(960, 620)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	dim.z_index = 70
	add_child(dim)
	dim.create_tween().tween_property(dim, "color:a", 0.7, 0.35)
	var title := UiTheme.label("%s: choose an Essence to wipe out" % spell.name, 34, Color(1.0, 0.8, 0.85))
	title.add_theme_constant_override("outline_size", 8)
	title.add_theme_color_override("font_outline_color", Color.BLACK)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.size = Vector2(1920, 50)
	title.position = Vector2(0, 250)
	title.z_index = 72
	title.modulate.a = 0.0
	add_child(title)
	title.create_tween().tween_property(title, "modulate:a", 1.0, 0.4)
	var orbs := {}
	var els := ["F", "W", "A"]
	var px := 120.0
	for i in 3:
		var el: String = els[i]
		var ic := ElementIcon.make(el, px)
		ic.size = Vector2(px, px)
		ic.pivot_offset = ic.size / 2.0
		ic.position = from - ic.size / 2.0
		ic.scale = Vector2(0.3, 0.3)
		ic.z_index = 72
		ic.highlight = true
		ic.mouse_filter = Control.MOUSE_FILTER_STOP
		ic.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		add_child(ic)
		var n := UiTheme.label("−%d Essence" % counts.get(el, 0), 24, Color(1, 0.95, 0.85))
		n.add_theme_constant_override("outline_size", 6)
		n.add_theme_color_override("font_outline_color", Color.BLACK)
		n.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		n.size = Vector2(px + 80, 30)
		n.position = Vector2(-40, px + 12)
		n.mouse_filter = Control.MOUSE_FILTER_IGNORE
		ic.add_child(n)
		# float softly up out of the card, then keep shining
		var to := Vector2(960 + (i - 1) * 260, 440) - ic.size / 2.0
		var tw := ic.create_tween().set_parallel(true)
		tw.tween_property(ic, "position", to, 1.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT).set_delay(i * 0.12)
		tw.tween_property(ic, "scale", Vector2.ONE, 1.0).set_trans(Tween.TRANS_SINE).set_delay(i * 0.12)
		var glow := ic.create_tween().set_loops()
		glow.tween_property(ic, "modulate", Color(1.7, 1.6, 1.4), 0.6).set_trans(Tween.TRANS_SINE)
		glow.tween_property(ic, "modulate", Color(1.2, 1.15, 1.05), 0.6).set_trans(Tween.TRANS_SINE)
		ic.gui_input.connect(func(ev): if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT: _element_chosen.emit(el))
		orbs[el] = ic
	Audio.play("spell_glow")
	_choosing_el = true
	var chosen: String = await _element_chosen
	_choosing_el = false
	title.create_tween().tween_property(title, "modulate:a", 0.0, 0.25)
	# the other two drift back into the card and vanish
	for el in orbs:
		var o: ElementIcon = orbs[el]
		o.mouse_filter = Control.MOUSE_FILTER_IGNORE
		if el == chosen:
			continue
		var back := o.create_tween().set_parallel(true)
		back.tween_property(o, "position", from - o.size / 2.0, 0.8).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
		back.tween_property(o, "scale", Vector2(0.2, 0.2), 0.8)
		back.tween_property(o, "modulate:a", 0.0, 0.8)
		back.chain().tween_callback(o.queue_free)
	# the chosen one shakes violently and cracks, then shatters
	var ic: ElementIcon = orbs[chosen]
	for c in ic.get_children():
		c.queue_free()
	await _wait(0.35)
	await _crack_and_shatter(ic, 16.0, 1.6)
	var fade := dim.create_tween()
	fade.tween_property(dim, "color:a", 0.0, 0.35)
	fade.tween_callback(dim.queue_free)
	title.queue_free()
	return chosen


## Shake an orb hard while cracks spread across it, then burst it into sparks.
func _crack_and_shatter(ic: ElementIcon, strength: float, dur: float) -> void:
	var home := ic.position
	Audio.play("sfx_lock_break")
	var cr := ic.create_tween()
	cr.tween_property(ic, "cracked", 1.0, dur).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	_quake(dur, 20.0)
	var steps := int(dur / 0.035)
	var sh := ic.create_tween()
	for k in steps:
		var amp := strength * (0.4 + 0.6 * float(k) / steps)
		sh.tween_property(ic, "position", home + Vector2(randf_range(-amp, amp), randf_range(-amp, amp)), 0.035)
	var redraw := func(): if is_instance_valid(ic): ic.queue_redraw()
	for k in steps:
		get_tree().create_timer(k * 0.035).timeout.connect(redraw)
	await _wait(dur)
	if not is_instance_valid(ic):
		return
	ShardBurst.burst(_fx, ic.global_position + ic.size / 2.0, Elements.COLORS.get(ic.el, Color.WHITE), ic.size.x * ic.scale.x)
	_shake(strength * 0.6)
	var boom := ic.create_tween().set_parallel(true)
	boom.tween_property(ic, "scale", ic.scale * 1.6, 0.18)
	boom.tween_property(ic, "modulate:a", 0.0, 0.18)
	boom.chain().tween_callback(ic.queue_free)
	await _wait(0.45)


## Every Essence of that element on the enemies shakes, cracks and bursts, the same way.
func _annihilate_enemies(el: String, targets: Array) -> void:
	var icons := []
	for e in targets:
		var v: EnemyView = _views.get(e)
		if v == null:
			continue
		for ic in v._hp_icons:
			if is_instance_valid(ic) and ic.el == el:
				icons.append(ic)
	if icons.is_empty():
		return
	for ic in icons:
		ic.pivot_offset = ic.size / 2.0
		_crack_on_the_spot(ic)
	_quake(1.4, 18.0)
	await _wait(1.55)
	_shake(14.0)
	Audio.play("sfx_damage_hit")
	await _wait(0.2)


## Like _crack_and_shatter, for an orb that sits in a row (its container owns its position, so it shakes by
## rotation and a small nudge of its drawing instead).
func _crack_on_the_spot(ic: ElementIcon) -> void:
	var cr := ic.create_tween()
	cr.tween_property(ic, "cracked", 1.0, 1.4).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	var sh := ic.create_tween()
	for k in 40:
		var amp := 0.1 + 0.35 * k / 40.0
		sh.tween_property(ic, "rotation", randf_range(-amp, amp), 0.035)
	sh.tween_property(ic, "rotation", 0.0, 0.03)
	var boom := ic.create_tween()
	boom.tween_interval(1.42)
	boom.tween_callback(func(): if is_instance_valid(ic): ShardBurst.burst(_fx, ic.global_position + ic.size / 2.0, Elements.COLORS.get(ic.el, Color.WHITE), ic.size.x))
	boom.tween_property(ic, "scale", Vector2(1.5, 1.5), 0.15)
	boom.parallel().tween_property(ic, "modulate:a", 0.0, 0.15)


func _card_for(id: String) -> SpellCard:
	for c in _cards:
		if c.spell.id == id and is_instance_valid(c):
			return c
	return null


## A speech-bubble style callout that says what just happened, near whoever did it.
func _callout(bbcode: String, at: Vector2, col: Color, life := 1.0) -> void:
	var p := _callout_panel(bbcode, col)
	await get_tree().process_frame
	if not is_instance_valid(p):
		return
	p.position = Vector2(clampf(at.x - p.size.x / 2.0, 10, 1910 - p.size.x), clampf(at.y - p.size.y, 10, 1070 - p.size.y))
	p.modulate.a = 0.0
	var tw := p.create_tween()
	tw.tween_property(p, "modulate:a", 1.0, 0.12)
	tw.tween_interval(life)
	tw.tween_property(p, "modulate:a", 0.0, 0.25)
	tw.tween_callback(p.queue_free)


## The callout box itself (dark, with a coloured border), added to the effects layer but not placed yet.
func _callout_panel(bbcode: String, col: Color) -> PanelContainer:
	var p := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.05, 0.06, 0.05, 0.94)
	sb.border_color = col
	sb.set_border_width_all(3)
	sb.set_corner_radius_all(12)
	sb.content_margin_left = 14
	sb.content_margin_right = 14
	sb.content_margin_top = 8
	sb.content_margin_bottom = 8
	p.add_theme_stylebox_override("panel", sb)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.z_index = 60
	var r := RichTextLabel.new()
	r.bbcode_enabled = true
	r.fit_content = true
	r.scroll_active = false
	r.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	r.custom_minimum_size = Vector2(340, 0)
	r.add_theme_font_size_override("normal_font_size", 19)
	r.add_theme_font_size_override("bold_font_size", 21)
	r.add_theme_color_override("default_color", Color(0.93, 0.95, 0.9))
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	r.text = "[center]" + bbcode + "[/center]"
	p.add_child(r)
	_fx.add_child(p)
	return p


# ------------------------------------------------------------------ spells, visibly

const SELF_OPS := ["shield", "heal", "aegis", "thorns", "cleanse", "sacrifice"]


## A Power's badge under your HP (null if it isn't showing).
func _power_badge(id: String) -> Control:
	for c in _status_row.get_children():
		if c.get_meta("power_id", "") == id and not c.is_queued_for_deletion():
			return c
	return null


## Where an artifact sits on screen (its icon's middle), or `fallback`.
func _artifact_center(id: String, fallback: Vector2) -> Vector2:
	for c in _arts.get_children():
		if c is ArtifactBar.ArtifactChip and c.id == id:
			return c.global_position + c.size / 2.0
	return fallback


## Before a spell's effect lands, its own show plays out (see SpellFx): from the card to whatever it affects.
func _spell_fly(ev: Dictionary) -> void:
	if ev.op == "pluck" and _shot_fired:
		_shot_fired = false  # the gunshot was the hit
		return
	var card := _card_for(ev.spell.id)
	var from := (card.global_position + card.size * card.scale / 2.0) if card else Vector2(960, 620)
	var src: String = ev.get("from_artifact", "")
	if src.begins_with("power:"):
		var badge := _power_badge(src.substr(6))  # a Power repeats it: the show starts from its badge
		if badge:
			from = badge.global_position + badge.size / 2.0
	elif src != "":
		from = _artifact_center(src, from)  # an artifact repeats it: the show starts from the artifact
	var col := GameData.spell_color(ev.spell.get("full_pattern", ev.spell.pattern)).lightened(0.2)
	if ev.spell.has("bottle"):
		col = Color(0.6, 0.95, 1.0)
	if ev.spell.has("bottle"):
		from = _bottle_from
	var op: String = ev.op
	var targets: Array = ev.targets
	var dests := []
	if not targets.is_empty():
		for e in targets:
			var v: EnemyView = _views.get(e)
			if v == null:
				continue
			var body := v.creature.global_position + v.creature.size / 2.0
			var row := v.hp_point(e.size() / 2) if e.size() > 0 else body
			if op == "strike" and e.size() > 0:
				row = v.hp_point(e.size() - 1 if ev.eff.get("from", "right") == "right" else 0)
			dests.append({"body": body, "row": row})
	elif op in SELF_OPS or (op == "ethereal" and ev.eff.get("target", "") == "self"):
		dests.append(_area(_player_panel))
	elif op in SpellFx.CHANT_OPS:
		dests.append(_area(_chant_row))
	elif op == "draw":
		dests.append(_area(_next_row))
	var player := _player_panel.get_global_rect().get_center()
	var wait := SpellFx.play(_fx, op, ev.eff, from, dests, col, player, _shake)
	if wait > 0.0:
		await _wait(wait)


func _area(c: Control) -> Dictionary:
	var r := c.get_global_rect()
	return {"body": r.get_center(), "row": r.get_center(), "rect": r}


## Once an effect has landed: flash whatever it touched and say what changed.
func _effect_landed(ev: Dictionary) -> void:
	var eff: Dictionary = ev.get("eff", {})
	if eff.is_empty():
		return
	var text := _effect_words(eff)
	if text == "":
		return
	var targets: Array = ev.targets
	if not targets.is_empty():
		for e in targets:
			var v: EnemyView = _views.get(e)
			if v:
				v.hit_flash()
				if not (text.begins_with("-") and text.substr(1).is_valid_int()):  # no "-N" on enemies: they react instead
					_float_text(text, v.global_position + Vector2(110, 180), Color(1, 0.85, 0.5))
	else:
		_float_text(text, _player_panel.global_position + Vector2(200, 10), Color(0.6, 0.9, 1))


func _effect_words(e: Dictionary) -> String:
	var n: int = int(e.get("n", 0))
	match e.op:
		"strike", "pluck", "purge", "siphon":
			return "-%d" % n
		"steal":
			return ""
		"burn":
			return "Burn %d" % n
		"poison":
			return "Poison %d" % n
		"weak":
			return "Weakened"
		"freeze":
			return "Frozen"
		"expose":
			return ""  # the paint splashes say it
		"shield":
			return "+%d Shield" % n
		"heal":
			return "+%d HP" % n
		"aegis":
			return "+Aegis"
		"thorns":
			return "+%d Thorns" % n
		"draw":
			return "+%d next turn" % n if e.when == "next" else "+%d now" % n
		"stoke":
			return "Burn ×2"
		"execute":
			return "Executed!"
		"cleanse":
			return "Cleansed"
	return ""


# ------------------------------------------------------------------ enemies, visibly

## An enemy steps forward and says what it's about to do.
func _enemy_turn_start(ev: Dictionary) -> void:
	var actor: EnemyView = _views.get(ev.enemy)
	for v in _views.values():
		v.modulate = Color.WHITE if v == actor else Color(0.55, 0.55, 0.6)
	if actor == null:
		return
	var tw := actor.creature.create_tween()
	actor.creature.pivot_offset = actor.creature.size / 2.0
	tw.tween_property(actor.creature, "scale", Vector2(1.12, 1.12), 0.15)
	tw.tween_property(actor.creature, "scale", Vector2.ONE, 0.2)
	var m: Dictionary = ev.move
	var words := "❄ Frozen: it skips its turn." if ev.frozen else _move_words(m, ev.enemy)
	await _file_turn_box()  # (in case the last one is still up)
	# what it's about to do, in a box at the top of the screen; it stays up while the enemy acts
	var box := _callout_panel("[b]%s[/b]\n%s" % [ev.enemy.name, Keywords.colorize(words)], Color(1, 0.55, 0.4))
	box.custom_minimum_size.x = 420
	_turn_box = box
	await get_tree().process_frame
	if not is_instance_valid(box):
		return
	box.position = Vector2(960.0 - box.size.x / 2.0, TURN_BOX_Y)
	box.pivot_offset = box.size / 2.0
	box.modulate.a = 0.0
	box.scale = Vector2(0.85, 0.85)
	var pop := box.create_tween().set_parallel(true)
	pop.tween_property(box, "modulate:a", 1.0, 0.15)
	pop.tween_property(box, "scale", Vector2.ONE, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	await _wait(TURN_READ_TIME)  # a moment to read it before it happens


## The enemy's action box sits here (top of the screen) while it acts, then fades away.
const TURN_BOX_Y := 14.0
const TURN_READ_TIME := 1.0
var _turn_box: PanelContainer


## Once the enemy has acted, its box quietly fades away (its line is already in the log).
func _file_turn_box() -> void:
	var box := _turn_box
	_turn_box = null
	if box == null or not is_instance_valid(box):
		return
	var tw := box.create_tween()
	tw.tween_property(box, "modulate:a", 0.0, 0.3)
	tw.tween_callback(box.queue_free)
	await _wait(0.15)


func _move_words(m: Dictionary, e: EnemyState) -> String:
	var parts := []
	while not m.is_empty():
		var look: Array = IntentChip.LOOK.get(m.kind, ["", Color.WHITE])
		if m.kind == "attack":
			var hits: int = m.get("hits", 1)
			parts.append("%s Attack %d%s" % [look[0], IntentChip.attack_damage(m, e), (" × %d" % hits) if hits > 1 else ""])
		else:
			parts.append("%s %s" % [look[0], EnemyDefs.describe_move(IntentChip._single(m), e.dmg_bonus)])
		m = m.get("also", {})
	return " + ".join(parts)


## The attacker lunges at you: slash marks, a shake, and the HP bar (or the Shield glass) takes the hit.
func _enemy_attack(ev: Dictionary) -> void:
	var v: EnemyView = _views.get(ev.enemy)
	var target := _hp_bar.global_position + Vector2(_hp_bar.size.x * 0.6, _hp_bar.size.y / 2.0)
	var hedge: HedgeWall = v.hedges_by_side.get(ev.get("part", ""), null) if v else null
	if is_instance_valid(hedge):
		# one of the Matron's walls attacks: the hedge itself lunges
		var toward := (target - (hedge.global_position + hedge.size / 2.0)).normalized() * 60.0
		var tw := hedge.create_tween()
		tw.tween_property(hedge, "offset", -toward * 0.3, 0.12)
		tw.parallel().tween_property(hedge, "squash", 0.92, 0.12)
		tw.tween_property(hedge, "offset", toward, 0.09)
		tw.parallel().tween_property(hedge, "squash", 1.2, 0.09)
		tw.tween_interval(0.12)
		tw.tween_property(hedge, "offset", Vector2.ZERO, 0.2)
		tw.parallel().tween_property(hedge, "squash", 1.0, 0.2)
		await _wait(0.2)
	elif v:
		var c := v.creature
		var home := c.position
		var toward := (target - (c.global_position + c.size / 2.0)).normalized() * 70.0
		c.pivot_offset = c.size / 2.0
		var tw := c.create_tween()
		tw.tween_property(c, "position", home - toward * 0.3, 0.12)  # wind up
		tw.parallel().tween_property(c, "scale", Vector2(0.92, 0.92), 0.12)
		tw.tween_property(c, "position", home + toward, 0.09)  # lunge
		tw.parallel().tween_property(c, "scale", Vector2(1.3, 1.3), 0.09)
		tw.tween_interval(0.12)
		tw.tween_property(c, "position", home, 0.2)
		tw.parallel().tween_property(c, "scale", Vector2.ONE, 0.2)
		await _wait(0.2)
	var blocked: bool = ev.get("blocked", false)
	ImpactFx.burst(_fx, target, blocked and ev.n == 0)
	Audio.play("sfx_player_hit" if ev.n > 0 else "release_armour_block")
	if blocked:
		_hp_bar.crack()
	_shake(10.0 if ev.n > 0 else 5.0)
	if ev.n > 0:
		_float_text("-%d" % ev.n, target + Vector2(-20, -70), UiTheme.DANGER)
		var tw2 := _player_panel.create_tween()
		tw2.tween_property(_player_panel, "modulate", Color(1.6, 0.6, 0.6), 0.08)
		tw2.tween_property(_player_panel, "modulate", Color.WHITE, 0.3)
	else:
		_float_text("Blocked!", target + Vector2(-40, -70), Color(0.6, 0.85, 1))
	_refresh_all()
	await _wait(0.6)


## Anything else an enemy does: debuffs fly at you, buffs glow on the enemy.
func _enemy_move_fx(ev: Dictionary) -> void:
	var v: EnemyView = _views.get(ev.enemy)
	var kind: String = ev.kind
	var look: Array = IntentChip.LOOK.get(kind, ["✦", Color.WHITE])
	var info: Array = IntentChip.INFO.get(kind, [kind.capitalize(), ""])
	if kind in Fight.AT_PLAYER and v:
		var from := v.creature.global_position + v.creature.size / 2.0
		var to := _player_panel.global_position + Vector2(240, 50)
		var comet := Comet.launch(_fx, from, to, (look[1] as Color).lightened(0.3))
		comet.rise = 60.0
		await _wait(0.45)
		_shake(4.0)
	elif v:
		v.hit_flash()
	_sync_views()
	_refresh_all()
	await _wait(0.5)


## A violent, building earthquake: the whole screen shakes harder and harder for `dur` seconds.
func _quake(dur: float, amount: float) -> void:
	var tw := create_tween()
	var steps := int(dur / 0.03)
	for i in steps:
		var a := amount * (0.25 + 0.75 * float(i) / steps)
		tw.tween_property(self, "position", Vector2(randf_range(-a, a), randf_range(-a, a)), 0.03)
	tw.tween_property(self, "position", Vector2.ZERO, 0.05)


var _shake_tw: Tween


## A quick jolt of the whole screen. Shakes can overlap: each new one takes over and always settles back home.
func _shake(amount: float) -> void:
	if _shake_tw and _shake_tw.is_valid():
		_shake_tw.kill()
	_shake_tw = create_tween()
	for i in 5:
		var a := amount * (1.0 - i * 0.15)
		_shake_tw.tween_property(self, "position", Vector2(randf_range(-a, a), randf_range(-a, a)), 0.035)
	_shake_tw.tween_property(self, "position", Vector2.ZERO, 0.05)


## One chant element lifts off as a comet and flies into every HP element it hits (or fizzles upward).
func _release_step(ev: Dictionary) -> void:
	_step_pos = ev.pos
	_released = true
	var slots := _chant_row.get_children().filter(func(c): return c is Panel)
	if ev.pos >= slots.size():
		return
	var slot: Panel = slots[ev.pos]
	var from := slot.global_position + slot.size / 2.0
	var el: String = ev.chant[ev.pos]
	var col: Color = Elements.COLORS[el]
	if ev.get("leftover", false):
		# nothing left to hit: it just fades quietly out of the chant
		for c in slot.get_children():
			c.create_tween().tween_property(c, "modulate:a", 0.0, 0.25)
		await _wait(0.05)
		return
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
	# New theme: a plain "+3" heal rides on a painted green splat, in white digits (damage gets no splat: no blood)
	if text.length() > 1 and text[0] == "+" and text.substr(1).is_valid_int():
		var splat := UiSkin.tex("float_heal")
		var digits := UiSkin.number(text, 34, true) if splat != null else null
		if digits != null:
			var st := Control.new()
			st.size = splat.get_size() * 1.15
			st.position = pos - Vector2(st.size.x / 2.0 - 40.0, 10.0)
			st.mouse_filter = Control.MOUSE_FILTER_IGNORE
			var bg := TextureRect.new()
			bg.texture = splat
			bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			bg.stretch_mode = TextureRect.STRETCH_SCALE
			bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
			st.add_child(bg)
			var cc := CenterContainer.new()
			cc.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			cc.mouse_filter = Control.MOUSE_FILTER_IGNORE
			cc.add_child(digits)
			st.add_child(cc)
			_fx.add_child(st)
			var stw := st.create_tween()
			stw.set_parallel()
			stw.tween_property(st, "position:y", st.position.y - 60, 0.8)
			stw.tween_property(st, "modulate:a", 0.0, 0.8).set_delay(0.3)
			stw.chain().tween_callback(st.queue_free)
			return
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
