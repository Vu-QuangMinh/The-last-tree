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
## When the player clicks around a lot without anything happening, we explain the situation.
## help_override (tutorial): func() -> String; return "" to use the normal explanation.
var help_override: Callable = Callable()
var _clicks: Array = []  # times (s) of recent clicks that didn't move the game on
var _last_help := -99.0
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
static var _puppet_live := 0  # Puppet fight screens in the tree (a new one is made before the old one leaves: the counter must stay hidden)
var _counted := false
var test_mode := false  # Test mode: two more buttons, Auto-fill and Auto-ball (set by Main before the screen is added)
var _test_btns: Array = []
var _auto_busy := false
var _hm_stage: HandymanStage  # the Handyman fight (Puppet Stage): his body and the hands on his shoulders stand in this, inside _enemy_row
var _views := {}  # EnemyState -> EnemyView
var _spell_row: HBoxContainer
var _cards: Array = []
var _chant_row: HBoxContainer
var _stage: PuppetStage  # Puppet Stage theme: the theatre behind the fight
## Puppet Stage: the run stays on the stage between fights. `stage_in` is the theatre of the fight before (taken over, so its scenery can
## slide away); `stage_flow` makes a won fight end with the Victory sign and the HUD sinking below the screen; `map_mode` is the stage
## with no fight at all (the HUD is down, the map board is raised over it); `arrive` plays the walk to the next room.
var stage_in: PuppetStage
var stage_flow := false
var map_mode := false
var arrive := false
## Puppet Stage: the fight is built while the encounter board is still up (the new set of props and the enemies come in behind it). `hold_hud`: the
## HUD stays down after the arrival until `release_hud()` (the player pressed "Begin the fight"). `wait_arrival()` waits for that moment.
var hold_hud := false
## Rope mode (Room Test, F5; see RopeEditor): the enemies only stand on the stage, nothing is played. The HUD stays down, the stage keeps its scenery, and
## the enemies just walk on (and, with rope_leave, walk off).
var rope_mode := false
var _arrival_ready := false
signal arrival_ready
signal hud_released
const HUD_DOWN := 660.0  # how far the HUD sinks (the spell row stands highest, at about y 560)
var _hud_shift := 0.0
var _book_btn: Button
var _heart: TextureRect
signal spellbook_pressed
var _coin_label: Label  # Puppet Stage: the Leaves in the Character panel
var _bottles_frame: NinePatchRect  # Puppet Stage: the painted frames of the bottles and of the artifacts (they follow their contents)
var _arts_frame: NinePatchRect
var _puppet_hud := false  # Puppet Stage: the HUD of the Chant UI PDF (statuses as icons, artifacts in a row)
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
var _next_panel: PanelContainer
var _talk_pending := false  # a boss to talk to: _arrive starts it once everything is in place
var _talking := false  # talking to a boss before the fight (BossTalk): only the boss, the backdrop and your bag
var _prompt: Label
var _info: Label
var _info_row: Control  # Puppet Stage: the same line written in the wooden alphabet (UiSkin.letters)
var _info_text := ""
var _hp_bar: HpBar
var _hp_label: Label
var _shield_box: HBoxContainer  # the Shield (and Lasting) amount, beside your HP
var _shield_label: Label
var _lasting_label: Label  # Puppet HUD: "Lasting N" under the HP bar
var _pstatus: RichTextLabel
var _status_row: Control  # your statuses, as bright badges above the HP bar
var _bottle_row: HBoxContainer  # your bottles, under the HP bar
var _arts: ArtifactBar
var _bottle_from := Vector2.ZERO
var _picking_any := false  # every enemy's Essence is pickable (a spell that takes any Essence, anywhere)
var _picking_any_cancellable := true
var _prepicked := {}  # EnemyState -> the Essence already chosen for it (the picker hands it straight back)
var _pick_style := "shoot"  # "shoot": remove spells (a crosshair, you shoot the Essence off) · "hand": steal (drag it to your bag) · "brush": Expose (paint it Any)
var _pick_only: EnemyState = null  # picking again on the same enemy (a spell that takes several)
var _pick_el := ""  # only Essence of this kind can be picked right now (the rest are dimmed)
var _steal_into_chant := false  # Instant Steal: the stolen Essence is dropped into the chant, not the bag
var _infuse_at := -1  # Instant Steal: where in the chant it was dropped (the placer hands it straight back)
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
var _danger: DangerVignette  # the red edge at low HP, and the red flash of a hit
var _arrow: Control
var _player_panel: Control
var _pause_overlay: Control

## op -> sfx name, for the generic {"type": "effect", "op": ...} events fired by every spell effect.
## Ops that already play their own sound elsewhere (strike-via-pluck, move, infuse/duplicate via
## "chant_changed", summon_spells via "loadout_changed") are left out so they don't double up.
const EFFECT_SFX := {
	"strike": "sfx_damage_hit", "burn": "sfx_burn_apply",
	"stoke": "sfx_burn_apply", "weak": "sfx_weaken_apply", "freeze": "sfx_freeze_apply",
	"expose": "sfx_expose_apply", "ethereal": "sfx_ethereal_apply", "shield": "sfx_shield_up",
	"heal": "sfx_heal", "aegis": "sfx_aegis_up", "thorns": "sfx_shield_up", "draw": "sfx_draw_element",
	"rotate": "sfx_convert", "swap": "sfx_convert", "convert": "sfx_convert", "purge": "sfx_purge",
	"shatter": "sfx_lock_break", "insert": "sfx_mend", "siphon": "sfx_purge", "execute": "sfx_execute",
	"transmute": "sfx_convert", "sacrifice": "sfx_player_hit", "amplify": "sfx_amplify",
	"overload": "sfx_overload", "cleanse": "sfx_cleanse", "redirect": "sfx_redirect", "passive": "spell_glow",
	"curse": "sfx_weaken_apply",
	"barrage": "sfx_magic_hit",  # (a volley of arcane bolts: Arcane Barrage, Elemental Fury, ...)
}
## op -> the shared sound of what it does (SFX/Spell SFX/spellfx_<group>.wav, made by tools/make_spell_sfx.py, chosen in the SFX Test screen). Every effect of every card
## plays the sound of its group when it lands; when the group has no sound (Heal, or the game's older sound was chosen) the EFFECT_SFX sound above plays instead.
const EFFECT_FX := {
	"strike": "remove_essence", "random_hit": "remove_essence", "barrage": "magic_bolt", "pluck": "snipe",
	"burn": "burn", "stoke": "stoke", "weak": "weaken", "vulnerable": "vulnerable", "freeze": "freeze", "daze": "daze", "ethereal": "ethereal", "curse": "curse",
	"shield": "shield", "thorns": "thorns", "thorn_guard": "thorns", "aegis": "evasion",
	"max_hp": "max_hp", "cleanse": "cleanse", "unbind": "cleanse",
	"expose": "repaint", "wild_repaint": "repaint", "self_repaint": "repaint",
	"infuse": "infuse", "infuse_upcoming": "infuse", "rearrange": "rearrange", "wild_move": "rearrange", "move": "rearrange", "duplicate": "duplicate", "echo_next": "duplicate",
	"conjure": "conjure", "summon_spells": "conjure", "steal": "steal", "execute": "execute", "purge": "purge", "purge_all": "purge", "annihilate": "purge",
	"convert": "transmute", "transmute": "transmute", "draw": "gain_essence", "sacrifice": "lose_hp", "amplify": "amplify", "shatter": "break_armour", "temp_seal": "seal",
	"passive": "power", "each_turn": "power", "retain": "refund",
}
## The shots of a barrage: one sound each, a beat apart (a little different each, so that it does not sound like one sample played again and again), each enemy
## flinching as it is hit. Runs on its own while the step goes on.
func _volley(targets: Array, group: String, fallback: String) -> void:
	var step := 0.11
	for i in targets.size():
		if not is_inside_tree():
			return
		var sfx: String = ("spellfx_" + group) if group != "" else fallback
		if sfx != "":
			Audio.play(sfx, randf_range(-1.5, 0.5), randf_range(0.93, 1.1), 0.0, false)
		var v: EnemyView = _views.get(targets[i])
		if v != null and is_instance_valid(v):
			v.hit_flash()
		await get_tree().create_timer(step).timeout


## The sound of an effect group (SFX/Spell SFX/spellfx_<group>.wav); `fallback` plays when the group has none (or `group` is empty).
func _play_fx(group: String, fallback: String) -> void:
	if group != "" and Audio.has_sfx("spellfx_" + group):
		Audio.play("spellfx_" + group)
	elif fallback != "":
		Audio.play(fallback)


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
	fight.wild_arranger = _wild_arranger
	fight.wild_painter = _wild_painter
	fight.element_chooser = _element_chooser
	fight.attune_chooser = _attune_chooser
	fight.arranger = _arranger
	fight.redirector = _redirector
	fight.spell_chooser = _spell_chooser
	fight.anim = _anim


func _ready() -> void:
	add_to_group("fight_screen")  # (the bars of the screens laid over it leave the artifacts to this one)
	_nu_ui = UiSkin.is_new_ui()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = UiTheme.get_theme()
	_backdrop = Backdrop.new()
	_backdrop.act = run.act
	_backdrop.tree_glow = false
	add_child(_backdrop)
	if UiSkin.is_puppet():  # Puppet Stage: the theatre (five tilted flat pictures, sliding wooden cut-outs) behind everything
		if stage_in != null and is_instance_valid(stage_in) and stage_in.act_no == run.act:  # (a new act has a stage of its own pictures)
			_stage = stage_in
			if _stage.get_parent() != null:
				_stage.get_parent().remove_child(_stage)
			add_child(_stage)
		else:
			_stage = PuppetStage.new(run.act)
			add_child(_stage)
			_stage.add_default_props()
		_stage.fit(get_viewport_rect().size.x)
		get_viewport().size_changed.connect(func() -> void: _stage.fit(get_viewport_rect().size.x))
		var lights := StageLights.new()  # (a spotlight over every enemy)
		lights.feet = _enemy_feet
		add_child(lights)
	_info = UiTheme.label("", 22, Color.WHITE)
	_info.position = Vector2(30, 14)
	add_child(_info)
	_arts = _make_arts()
	add_child(_arts)
	if UiSkin.is_puppet():  # Puppet Stage: the Act / Floor / Turn line is written on the hanging sign (see _rebuild_character_panel)
		_info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_info.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_info.size = PuppetTopHud.ACT_TEXT.size
		_info.add_theme_font_size_override("font_size", PuppetTopHud.ACT_PX)
		_info.add_theme_color_override("font_color", Color(0.30, 0.17, 0.07))
		var bold := UiTheme.cut("bold")
		if bold != null:
			_info.add_theme_font_override("font", bold)
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
	_next_panel = np
	_next_row = HBoxContainer.new()
	_next_row.add_theme_constant_override("separation", 4)
	nv.add_child(_next_row)
	if not _circus_strips():  # (Cirus: the Essence waiting in the launcher tube take its place)
		add_child(np)
	# enemies
	_enemy_row = HBoxContainer.new()
	_enemy_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_enemy_row.add_theme_constant_override("separation", 20)
	_enemy_row.position = Vector2(0, 90)
	_enemy_row.size = Vector2(1920, 480)
	add_child(_enemy_row)
	_place_enemies()  # (Puppet Stage: they stand in the middle of the floor)
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
	if _puppet_strips():
		_spell_row.z_index = 1  # (cards over the globe if there are so many that they reach it)
		_build_strips_puppet()
	else:
		_build_strips_classic()
	if test_mode and _chant_panel != null:
		_build_test_buttons()
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
	under.custom_minimum_size = Vector2(0, 64)  # (the panel keeps its height whether or not you carry bottles)
	under.add_theme_constant_override("separation", 8)
	pv.add_child(under)
	_hp_label = UiTheme.label("", 18)
	var hp_font := UiTheme.cut("bold")  # "HP 50 / 50" in the bold cut of the chosen font
	if hp_font != null:
		_hp_label.add_theme_font_override("font", hp_font)
	_hp_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_hp_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_hp_label.clip_text = true  # (its text must never stretch the panel)
	var heart := UiSkin.icon("icon_heart", 28)
	if heart != null:
		heart.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		under.add_child(heart)
	under.add_child(_hp_label)
	_shield_box = HBoxContainer.new()
	_shield_box.add_theme_constant_override("separation", 3)
	_shield_box.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_shield_box.visible = false
	var shield_pic := UiSkin.icon("icon_armor_shield", 24)
	if shield_pic != null:
		_shield_box.add_child(shield_pic)
	_shield_label = UiTheme.label("", 18, Color(0.62, 0.86, 1.0))
	if hp_font != null:
		_shield_label.add_theme_font_override("font", hp_font)
	_shield_box.add_child(_shield_label)
	under.add_child(_shield_box)
	_bottle_row = HBoxContainer.new()
	_bottle_row.add_theme_constant_override("separation", 6)
	UiSkin.frame_behind(_bottle_row)  # New theme: one painted frame around all the bottles
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
	if UiSkin.is_puppet():
		_rebuild_character_panel()
		AmberCounter.off_in_fight = true  # (the Menu button stands where the counter is)
		_puppet_live += 1
		_counted = true
		for n in get_tree().get_nodes_in_group("amber_counter"):
			n.visible = false
	# the fight log, bottom right
	_log = UiTheme.label("", 14, UiTheme.MUTED)
	_log.position = Vector2(1660, 742)
	_log.size = Vector2(245, 240)
	_log.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_log.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	_log.clip_text = true  # (a long log is cut off at the top instead of growing down over the Menu button)
	_log.custom_minimum_size = Vector2(245, 60)
	_log.add_theme_color_override("font_color", Color.WHITE)
	var log_art := UiSkin.box("panel_log_translucent", [24, 24, 24, 24], [18, 12, 18, 12])
	if log_art != null:  # New theme: a wooden plaque behind the log
		_log.add_theme_stylebox_override("normal", log_art)
	add_child(_log)
	_log.visible = not UiSkin.is_puppet()  # (Puppet Stage: no fight log)
	_fx = Control.new()
	_fx.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_fx.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_fx)
	_danger = DangerVignette.new()
	_danger.z_index = 85
	add_child(_danger)
	_arrow = Control.new()
	_arrow.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_arrow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_arrow.z_index = 50
	_arrow.draw.connect(_draw_arrow)
	add_child(_arrow)
	var menu_btn := UiTheme.button("☰ Menu", _open_pause_menu, 18)
	menu_btn.custom_minimum_size = Vector2(130, 44)
	menu_btn.position = Vector2(1920 - 150, 1024)
	if UiSkin.is_puppet():  # (its plate, at the place the HUD layout gives it)
		menu_btn.text = "Menu"
		menu_btn.custom_minimum_size = _menu_rest().size
		menu_btn.size = _menu_rest().size
		menu_btn.position = _menu_rest().position  # (bottom left of the Chant frame, always)
		menu_btn.z_index = PuppetStage.CEILING_Z + 1  # (over the curtain at the top of the stage)
		_menu_btn = menu_btn
	UiTheme.use_menu_style(menu_btn)
	UiTheme.use_heading_font(menu_btn)
	if _nu_ui:
		_style_nu_menu(menu_btn)
		_top_layer.add_child(menu_btn)  # (it is part of the HUD: it sinks with it between fights, where the map has its own Menu button)
	else:
		add_child(menu_btn)
	_build_spells()
	_sync_views()
	_refresh_all()
	_fit_bottom.call_deferred()
	if _stage != null and not map_mode and not rope_mode:  # (Puppet Stage: the enemies hang on the ropes placed with the rope mode, see RopeRig)
		var ropes := RopeRig.new()
		ropes.fs = self
		add_child(ropes)
	if fight.talk_id != "" and not help_override.is_valid():
		if _stage != null and (map_mode or arrive):
			_talk_pending = true  # (Puppet Stage: he speaks once "Begin the fight" is pressed and the scene and the HUD are all in place, see _arrive)
		else:
			_talk.call_deferred()  # (a boss to talk to first; not in the tutorial)
	tut.connect(func(_k, _d): note_progress())
	_machine_ready = not (_stage != null and (map_mode or arrive))
	if _stage != null and (map_mode or arrive):
		_build_spellbook_button()
		_start_down.call_deferred()
	else:
		_show_act_sign.call_deferred(true)  # (a fight that simply starts: the sign drops now and goes up after 10 s)


# ------------------------------------------------------------------ Puppet Stage, between fights

## Everything of the HUD that sinks below the edge of the screen (the spell cards, the Chant and the Bag with the machine, HP and what hangs on
## it, the bottles, the artifacts).
func _hud_nodes() -> Array:
	var out: Array = []
	for n in [_spell_row, _chant_panel, _bag_panel, _top_layer]:  # (the Menu button and the Act sign stay where they are; the debuffs go up, see _set_hud_shift)
		if n != null and is_instance_valid(n):
			out.append(n)
	return out


func _set_hud_shift(v: float) -> void:
	var d := v - _hud_shift
	_hud_shift = v
	for n in _hud_nodes():
		n.position.y += d
	var k_up := clampf(v / HUD_DOWN, 0.0, 1.0)
	for n in ([] if _nu_ui else [_status_row, _debuff_board]):  # (the debuffs leave over the top edge: they stand at the top left; New UI: they sink with the HUD)
		if n != null and is_instance_valid(n):
			n.position.y -= d / HUD_DOWN * DEBUFF_LIFT
	if _menu_btn != null:
		_menu_btn.position = _menu_rest().position if _nu_ui else _menu_rest().position.lerp(MENU_TOP_AT, k_up)
	if _book_btn != null:
		var k := clampf(v / HUD_DOWN, 0.0, 1.0)
		_book_btn.visible = k > 0.02 and not hold_hud
		_book_btn.modulate.a = clampf((k - 0.4) / 0.6, 0.0, 1.0)  # (it appears as the cards sink into it)
		_book_btn.mouse_filter = Control.MOUSE_FILTER_STOP if k > 0.95 else Control.MOUSE_FILTER_IGNORE


## Where the Menu button stands during a fight.
func _menu_rest() -> Rect2:
	return NewUiLayout.MENU_BTN if _nu_ui else PuppetTopHud.MENU


func get_stage() -> PuppetStage:
	return _stage


func _hud_hidden() -> bool:
	return map_mode or _hud_shift > 1.0


func _start_down() -> void:
	busy = true
	_set_hud_shift(HUD_DOWN)
	if arrive:
		_arrive()


## The Act / Floor / Turn line: a Label, or (Puppet Stage) the wooden letters on the hanging sign, centred on the Label's old spot; the Label stays hidden
## unless the theme has no such art.
func _set_info(text: String) -> void:
	if _nu_ui:  # ("Act 1 · Floor 5\nTurn 2" -> "Act 1 - Floor 5 - Turn 2")
		_info.text = text.replace("\r", "").replace("\n", " - ").replace(" · ", " - ").replace("Act ", "Act")  # (as the page writes it: "Act1 - Floor 5 - Turn 2")
		_info.visible = true
		return
	_info.text = text
	if UiSkin.is_puppet():
		_info.visible = _act_sign != null  # (it stands on the hanging sign)


## The Act / Floor / Turn line is as tall as the 19 px text it replaced (capital letters of that font are about 14 px).
const INFO_CAP := 14.0


## The HUD sinks, the Spellbook button comes up in the place of the HP bar.
func _hud_down(secs := 0.9) -> void:
	busy = true
	_lift_act_sign(true)
	_set_info("Act %d · Floor %d" % [run.act, run.floor_no()])
	if _book_btn == null:
		_build_spellbook_button()
	var tw := create_tween()
	tw.tween_method(_set_hud_shift, _hud_shift, HUD_DOWN, secs).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	await tw.finished


var _hud_tw: Tween


## The HUD comes up from below the screen. `free_input`: the fight can be played once it is up (false when it is raised early, while the stage is still being set).
func _hud_up(secs := 0.8, free_input := true) -> void:
	_show_act_sign()  # (the fight begins: the Act sign drops; _arrive starts its countdown once everything is out)
	if _hud_tw != null and _hud_tw.is_valid():
		_hud_tw.kill()
	_hud_tw = create_tween()
	var tw := _hud_tw
	tw.tween_method(_set_hud_shift, _hud_shift, 0.0, secs).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	await tw.finished
	_machine_ready = true
	if free_input:
		busy = false
		_fit_enemy_lift()


## Loudness of the scene-preparation sounds, dB to add so that every one sits at about the same level (measured: RMS of each file brought to -26 dB).
const PREPARE_DB := {"sfx_scene_prepare": -6.6, "sfx_scene_prepare_short_1": 10.0, "sfx_scene_prepare_short_2": 0.9, "sfx_scene_prepare_short_3": 3.6, "sfx_scene_prepare_short_4": 6.6}
var _prepare_on := false
var _prepare_players: Array = []


func _play_prepare(name: String) -> void:
	var p := Audio.play_held(name, PREPARE_DB.get(name, 0.0), randf_range(0.97, 1.03))
	if p != null:
		_prepare_players.append(p)


## While the stage is made ready: the long sound once, then, for as long as that goes on, short ones picked at random, sometimes two overlapping.
func _prepare_sounds() -> void:
	_prepare_on = true
	_play_prepare("sfx_scene_prepare")
	var main_len := 6.0
	var s := Audio.get_sfx_length("sfx_scene_prepare")
	if s > 0.0:
		main_len = s
	await get_tree().create_timer(main_len).timeout
	var last := 0
	while _prepare_on and is_inside_tree():
		var k := randi_range(1, 4)
		if k == last:
			k = k % 4 + 1
		last = k
		_play_prepare("sfx_scene_prepare_short_%d" % k)
		if randf() < 0.4:  # (a second one overlapping the first)
			await get_tree().create_timer(randf_range(0.4, 1.1)).timeout
			if _prepare_on:
				_play_prepare("sfx_scene_prepare_short_%d" % (k % 4 + 1))
		await get_tree().create_timer(randf_range(1.2, 2.4)).timeout


## Walking on: the old props are cleared away first (that began at the encounter board; if the fight was begun early, it is waited for), then the
## new room's props and enemies come in from the right, and the HUD comes back up as the last of them settle.
func _arrive() -> void:
	_set_enemy_drop(ENEMY_UP)  # (they wait above the screen on their ropes while the old props are cleared; no first frame in their place)
	if rope_mode:
		for e in _views:  # (the name would lie over the puppet and hide the spot to click)
			if is_instance_valid(_views[e]):
				_views[e].hide_name()
		await get_tree().create_timer(0.15).timeout
		_let_enemies_down()
		return
	_prepare_sounds()  # (the stage is being made ready: old props away, new ones and the enemies in)
	if _stage.is_clearing():
		await _stage.cleared
	var tw := _stage.bring_props()
	await get_tree().create_timer(1.2).timeout  # (the enemies are let down after the first props: the props walk on, the puppets hang from their ropes)
	_let_enemies_down()
	await get_tree().create_timer(PuppetStage.BRING_TIME - 1.2 - 1.0).timeout
	_prepare_on = false
	for p in _prepare_players:
		Audio.stop_held(p, 0.4)
	_prepare_players.clear()
	if hold_hud:  # (the encounter board is still up: the HUD waits for "Begin the fight")
		_arrival_ready = true
		arrival_ready.emit()
		if hold_hud:
			await hud_released
	while _dropping and is_inside_tree():  # (the HUD comes up once the enemies hang in their places)
		await get_tree().process_frame
	if _talk_pending:
		_talk_pending = false
		await _hud_up()
		if tw.is_running():
			await tw.finished
		_show_act_sign(true)
		await get_tree().create_timer(0.6).timeout  # (the cards have landed)
		_talk()
		return
	_hud_up()
	if tw.is_running():
		await tw.finished
	_show_act_sign(true)  # (the props and the enemies are out: the sign goes up after 10 s)


const ENEMY_UP := -1500.0  # how far above their places the enemies hang while they are out of sight (their ropes go straight up behind the ceiling)
const ENEMY_LET_DOWN := 0.55  # seconds of free fall before the ropes are out to their length (at ENEMY_SPEED 1)
const ENEMY_SPRING := 1.1  # seconds the puppets bob on their ropes after that
const ENEMY_SPEED := 0.5  # how fast the whole let-down goes: half of what it was
var _enemy_drop := 0.0  # how far the enemy row is lifted from its place (0 = standing)
var _dropping := false  # (the lift of the Essence rows leaves the row alone while it is let down)


func _set_enemy_drop(off: float) -> void:
	_enemy_drop = off
	if _enemy_row != null and _stage != null:
		_enemy_row.position.y = _stage.floor_center_y() - ENEMY_FEET_DY - ENEMY_LIFT - _extra_lift + off


## The enemies are let down on their ropes: straight down onto their places (the ropes' tops stay put, the rivets drag them), a short fall, then a
## few bobs on the stretched ropes. (The props walk on from the side; the puppets do not.)
func _let_enemies_down() -> void:
	_dropping = true
	var from := _enemy_drop
	var tw := create_tween()
	tw.tween_method(func(t: float):
		var off := 0.0
		# (t is in seconds at normal speed)
		if t < ENEMY_LET_DOWN:
			var u := t / ENEMY_LET_DOWN
			off = from * (1.0 - u * u)  # gravity: slow at first, fast at the end
		else:
			var s := t - ENEMY_LET_DOWN
			off = 20.0 * exp(-4.5 * s) * sin(TAU * 1.8 * s)  # the rope stretches: a dip below the place, a bob back
		_set_enemy_drop(off), 0.0, ENEMY_LET_DOWN + ENEMY_SPRING, (ENEMY_LET_DOWN + ENEMY_SPRING) / ENEMY_SPEED)
	await tw.finished
	_set_enemy_drop(0.0)
	_dropping = false


## Rope mode: the enemies are pulled up on their ropes (the next set is let down).
func rope_leave() -> void:
	var tw := create_tween()
	tw.tween_method(_set_enemy_drop, _enemy_drop, ENEMY_UP, 0.7).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	await tw.finished


## Rope mode: [[enemy id, Creature]] of the puppets that stand on the stage and can take ropes.
func rope_targets() -> Array:
	var out: Array = []
	for e in _views:
		var v: EnemyView = _views[e]
		if is_instance_valid(v) and is_instance_valid(v.creature) and not e.is_dead() and v.creature.rope_ok():
			out.append([RopeSets.rope_key(e.id, e.yin, e.phase), v.creature])
	if _hm_stage != null and is_instance_valid(_hm_stage) and _hm_stage.rope_body() != null:  # (the Handyman's body before he steps out)
		out.append(["handyman", _hm_stage.rope_body()])
	return out


## The new set has come in (the props and the enemies stand on the stage): true once the HUD only waits to be released.
func wait_arrival() -> void:
	if not _arrival_ready:
		await arrival_ready


func release_hud() -> void:
	hold_hud = false
	if _puppet_hud:
		_fit_hud_frames()
	hud_released.emit()


## "Begin the fight": the spells chosen on the encounter board are the fight's spells now (they are rebuilt), and each card flies from where it lay on the board
## to its place in the fight's row, while the HUD comes up under it. `from`: [{id, rect (global)}] the active cards of the board.
func begin_with_spells(spells: Array, spellbook: Array, from: Array) -> void:
	fight.loadout = spells
	fight.spellbook = spellbook
	_build_spells()
	_refresh_all()
	var ghosts: Array = []
	for card in _cards:
		var src: Dictionary = {}
		for f in from:
			if f.id == card.spell.id:
				src = f
		if src.is_empty():
			continue
		var ghost := SpellCard.make(card.spell)
		ghost.is_zoom_copy = true
		ghost.mouse_filter = Control.MOUSE_FILTER_IGNORE
		ghost.z_index = PuppetStage.CEILING_Z + 6
		ghost.size = Vector2(SpellCard.W, SpellCard.H)
		ghost.pivot_offset = Vector2.ZERO
		add_child(ghost)
		ghost.global_position = (src.rect as Rect2).position
		card.modulate.a = 0.0  # (the real card shows once the picture has landed on it)
		card.mouse_filter = Control.MOUSE_FILTER_IGNORE  # (no hover while it travels)
		ghosts.append({"ghost": ghost, "card": card, "from": ghost.global_position, "scale": float(card.base_scale)})
	busy = true
	# "Begin the fight" pressed before the stage is ready (the old props still being cleared, the new ones and the enemies still coming in): the HUD and the cards
	# go to their places at once, and the fight waits for the stage (_arrive frees it when the set has come in).
	var early := not _arrival_ready
	release_hud()
	if early:
		_hud_up(0.8, false)
	var i := 0
	for g in ghosts:
		var gh: SpellCard = g.ghost
		var card: SpellCard = g.card
		var tw := create_tween()
		tw.tween_interval(0.05 * i)
		tw.tween_method(func(u: float) -> void:
			if is_instance_valid(gh) and is_instance_valid(card):
				var e := u * u * (3.0 - 2.0 * u)
				gh.global_position = (g.from as Vector2).lerp(card.global_position, e)  # (the target moves with the HUD that is coming up)
				gh.scale = Vector2.ONE * lerpf(1.0, float(g.scale), e), 0.0, 1.0, 0.85).set_ease(Tween.EASE_OUT)
		tw.tween_callback(func() -> void:
			if is_instance_valid(card):
				card.modulate.a = 1.0
				card.mouse_filter = Control.MOUSE_FILTER_STOP  # (it can be hovered again once it has landed)
			if is_instance_valid(gh):
				gh.queue_free())
		i += 1
		Audio.play("loadout_swap", -8.0, randf_range(0.95, 1.1))


## The Spellbook button (no art for it yet: a wooden plate with a book drawn on it) stands where the HP bar is while the HUD is down.
func _build_spellbook_button() -> void:
	if true:  # (no Spellbook button any more: the spells are arranged on the encounter board)
		return
	var r := PuppetLayout.HP_BAR
	_book_btn = Button.new()
	_book_btn.text = "Spellbook"
	_book_btn.focus_mode = Control.FOCUS_NONE
	_book_btn.position = Vector2(r.position.x, r.position.y - 6.0)
	_book_btn.size = Vector2(290, 64)
	_book_btn.custom_minimum_size = _book_btn.size
	UiTheme.use_heading_font(_book_btn)
	UiTheme.style_puppet_button(_book_btn, "chant", 22)
	_book_btn.alignment = HORIZONTAL_ALIGNMENT_CENTER
	_book_btn.text = "   Spellbook"  # (room for the book on the left)
	_book_btn.tooltip_text = "Your spells: the active row and the rest of the book."
	var book := SpellbookIcon.new()
	book.size = Vector2(46, 40)
	book.position = Vector2(16, 12)
	book.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_book_btn.add_child(book)
	_book_btn.pressed.connect(func(): spellbook_pressed.emit())
	_book_btn.z_index = 3
	_book_btn.visible = false
	add_child(_book_btn)


## A closed book drawn in code: brown cover, paper edge, a gold emblem.
class SpellbookIcon extends Control:
	func _draw() -> void:
		var w := size.x
		var h := size.y
		draw_rect(Rect2(4, 5, w - 6, h - 6), Color(0.15, 0.08, 0.04), true)  # shadow
		draw_rect(Rect2(2, 2, w - 6, h - 6), Color(0.94, 0.88, 0.7), true)  # the pages
		draw_rect(Rect2(0, 0, w - 8, h - 8), Color(0.45, 0.2, 0.12), true)  # the cover
		draw_rect(Rect2(0, 0, w - 8, h - 8), Color(0.98, 0.78, 0.4), false, 2.0)
		draw_rect(Rect2(0, 0, 8, h - 8), Color(0.32, 0.13, 0.08), true)  # the spine
		draw_circle(Vector2((w - 8) / 2.0 + 4, (h - 8) / 2.0), 6.5, Color(0.98, 0.78, 0.4))  # the emblem
		draw_circle(Vector2((w - 8) / 2.0 + 4, (h - 8) / 2.0), 3.0, Color(0.45, 0.2, 0.12))


# ------------------------------------------------------------------ building

## The Chant and Bag panels of the Default and New themes.
func _build_strips_classic() -> void:
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


## Cirus theme: the Chant strip and the Bag strip of "Chant UI for Circus.pdf" (cut by tools/export_circus_chant.py,
## laid out by ChantLayout). The Bag strip ends in the launcher tube: the Essence ride in it under a sheet of glass, and
## when a batch is released the crank turns once, the gear twice, and they roll out to their places (see _tube_launch).
const TUBE_BALL_STEP := 54.0

var _tube_gear: TextureRect
var _tube_plate: TextureRect
var _tube_handle: TextureRect
var _crank_tween: Tween
var _launching := 0  # Essence rolling out of the tube right now
var _bag_seen := {}  # uid -> true: Essence that have been in the bag before (only the brand new ones roll out of the tube)
var _cast_uids := {}  # uid -> true: the Essence of the chant being cast right now (still in the stock for a moment, but gone)
var _tube_icons: Array = []  # the Essence in the tube (next turn's draw), or waiting hidden in the red block (sent by a spell)
var _tube_hold_until := 0  # ticks: the tube rests, empty, until then (2 s after a launch)
var _tube_sync_pending := false
var _direct_in := 0  # stolen Essence on their way into the Bag that skip the machine
var _direct_until := 0  # ticks: after this a stolen one is no longer waited for
var _direct_landed := false
var _direct_wait: Array = []  # the Bag's balls waiting for the flying one to land
var _bag_order: Array = []  # Puppet Stage: the uids of the Bag's balls in the order they stand now (new balls stack after them; a re-sort follows)
var _resort := false  # (set while the sorted order is being walked into: its balls swap with a lift and one sound)
var _resort_wait := false  # a launch just ended: the balls wait a moment before they swap into their types
var _machine: SlotMachine  # Puppet Stage: the slot machine
var _nu_ui := false  # the New UI theme (NewUiLayout): the Puppet look, a HUD laid out as page 2 of the Chant UI PDF, no machine (fixed when the fight is built)
var _nu_back: NewUiLayout.Back  # New UI: the dark blocks, the slots and the debuff circles
var _spawned_once := false  # the first launch of a fight counts as a spawn: the lever is pulled for it
var _bonus_from := Vector2.INF  # where the next bonus Essence comes from (a screen point: the card, the bottle...); INF: it pops up over the top funnel
var _reel_shown: Array = []  # the Essence the reels show (next turn's draw)
var _machine_ready := false  # the machine is on the screen (a fight on the stage builds its HUD below the screen first and lifts it later: nothing may spawn before)
var _pending: Array = []  # balls a spell gave "for next turn": they lie in the tray on top of the machine; at the next spawn they go down with the others
var _keep_bag_order := false  # after a bonus ball joined mid-turn: the Bag keeps its order (the new ball stands after the others) until the next spawn
var _reels_armed := false  # the reels have rolled next turn's draw (the lever was pulled after the last spawn) and show it
var _tube_prep := false  # a launch is being set up
var _rolling_in := 0  # Essence rolling into the tube right now
var _turn_batch_until := 0  # ticks: a new turn is starting, so the next new Essence come out of the tube


## Puppet Stage: the enemies' row, so that their feet are on the middle of the floor.
const ENEMY_FEET_DY := 480.0  # (from the top of the row to the feet of a puppet: it stands at the bottom of its box, name and Essence above it)
const ENEMY_LIFT := 0.0  # (how much higher than the middle of the floor they stand)


var _lift_turn := -1  # (the turn the lift was last allowed to shrink in)
var _lift_tween: Tween
var _extra_lift := 0.0  # how much higher the enemies stand because their rows of Essence need more than one line above the spell cards


func _place_enemies() -> void:
	if _stage != null and _enemy_row != null:
		_enemy_row.position.y = _stage.floor_center_y() - ENEMY_FEET_DY - ENEMY_LIFT - _extra_lift


## Puppet Stage: the Essence rows hang under the enemies' feet; when one needs two lines (or more) the whole row of enemies stands higher, so
## the lowest line ends just above the spell cards.
## The screen y of the feet of the lowest standing enemy (0 when none).
func _feet_y() -> float:
	var y := 0.0
	for e in _views:
		var v: EnemyView = _views[e]
		if is_instance_valid(v) and is_instance_valid(v.creature) and not e.is_dead() and not v.creature.has_rig():
			y = maxf(y, v.creature.global_position.y + v.creature.size.y)
	return y


func _fit_enemy_lift() -> void:
	if _stage == null or _enemy_row == null or _spell_row == null or _spell_row.get_child_count() == 0:
		return
	var bottom := 0.0
	for e in _views:
		var v: EnemyView = _views[e]
		if is_instance_valid(v) and not e.is_dead() and not v.creature.has_rig():  # (a Handyman hand's text stands where its rig puts it)
			bottom = maxf(bottom, v.below_feet_bottom())
	if bottom <= 0.0:
		return
	# (they never stand higher than the far edge of the floor, 20 px in: a puppet pushed up by its own rows of Essence would leave the floor)
	var top_room := 130.0
	var feet := _feet_y()
	if feet > 0.0:
		top_room = clampf(feet + _extra_lift - (_stage.floor_range().x + 20.0), 0.0, 130.0)
	var need := clampf(bottom + _extra_lift - (_spell_row.global_position.y - 6.0), 0.0, top_room)
	# Within one turn the lift only ever grows: clicking an orb changes the preview (a skull wraps an Essence row onto a second line and takes
	# it off again), and the whole row of enemies used to jump up and down with every click.
	var turn: int = fight.turn if fight != null else 0
	if turn == _lift_turn:
		need = maxf(need, _extra_lift)
	else:
		_lift_turn = turn
	need = minf(need, top_room)  # (the floor's far edge is a hard limit: a lift kept from earlier in the turn must obey it too)
	if absf(need - _extra_lift) > 0.5:
		_extra_lift = need
		if _enemy_row != null and _stage != null and not _dropping and _enemy_drop == 0.0:  # (glide there instead of jumping; while they are let down the drop follows the new place itself)
			var y := _stage.floor_center_y() - ENEMY_FEET_DY - ENEMY_LIFT - _extra_lift
			if _lift_tween != null and _lift_tween.is_valid():
				_lift_tween.kill()
			_lift_tween = create_tween()
			_lift_tween.tween_property(_enemy_row, "position:y", y, 0.2).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


## ---- Puppet Stage: the left of the HUD, as laid out in "Chant UI for puppet.pdf" ---------------------------------------------
## HP bar with the heart / HP and Shield under it, the bottles' frame (up to 5), the artifacts' frame (ten slots), the Leaves under them, and
## the statuses (small icons, up to 22 at once: 14 kinds + 8 Powers, two rows) above the HP bar. Everything stands on the screen itself;
## `_player_panel` is only a marker the effects that land on you fly to.
const DEBUFF_LIFT := 400.0  # how far the debuff board is lifted (off the top of the screen) while the HUD is down
const MENU_TOP_AT := Vector2(1426.0, 1001.0)  # the Menu button between fights: level with Begin the fight, to its left
const BOTTLE_PX := 44.0  # a bottle / an artifact in its slot frame
const ART_PX := 44.0
const ART_STEP := 48.0  # the artifacts' slots are this far apart, five to a row
const ART_ROW := 5
const ART_ROW_GAP := 2.0
const BOTTLE_STEP := 50.2  # the bottles' slots: five fit the frame
var _menu_btn: Button
var _debuff_board: NinePatchRect  # Puppet Stage: the red board at the top left that holds the debuffs (it stretches to fit their icons)
var _top_layer: Control  # holds everything of the char panel (HP, bottles, artifacts): it sinks with the HUD between fights
var _act_sign: Control  # Puppet Stage: the hanging sign with the Act / Floor / Turn line: it drops at the start of a fight and goes back up after a while
var _act_sign_gen := 0  # (every drop and every lift counts: a countdown that belongs to an older one does nothing)


func _rebuild_character_panel() -> void:
	if _nu_ui:
		_rebuild_character_panel_nu()
		return
	_puppet_hud = true
	var old := _player_panel
	_player_panel = Control.new()
	_player_panel.position = PuppetTopHud.TRAY.position  # (the marker the heal / shield effects fly to is the HP tray itself)
	_player_panel.size = PuppetTopHud.TRAY.size
	_player_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_player_panel)
	old.queue_free()
	_bottles_frame = _nine_frame("slot_board", PuppetTopHud.BOTTLES, PuppetTopHud.SLOT_MARGINS)
	_bottles_frame.z_index = PuppetStage.CEILING_Z + 2
	_arts_frame = _nine_frame("slot_board", PuppetTopHud.ARTIFACTS, PuppetTopHud.SLOT_MARGINS)
	_arts_frame.z_index = PuppetStage.CEILING_Z + 2
	_hp_bar = StripeHpBar.new()  # (16 candy stripes in a bar that ends in a ring; the numbers stand in the ring)
	_hp_bar.custom_minimum_size = PuppetTopHud.TRAY.size
	_hp_bar.position = PuppetTopHud.TRAY.position
	_hp_bar.size = PuppetTopHud.TRAY.size
	_hp_bar.z_index = PuppetStage.CEILING_Z + 2
	add_child(_hp_bar)
	var heart := UiSkin.icon("icon_heart", 24)
	if heart != null:
		heart.z_index = PuppetStage.CEILING_Z + 3
		heart.visible = false  # (the ring of the HP bar holds the numbers now)
		add_child(heart)
		_heart = heart
	var hp_font := UiTheme.cut("bold")
	_hp_label = UiTheme.label("", PuppetTopHud.HP_PX, Color(0.831, 0.255, 0.153))
	if hp_font != null:
		_hp_label.add_theme_font_override("font", hp_font)
	_hp_label.size = PuppetTopHud.RING_TEXT
	_hp_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hp_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER  # (centred in the ring, top line)
	_hp_label.clip_text = true
	_hp_label.z_index = PuppetStage.CEILING_Z + 3
	add_child(_hp_label)
	_shield_box = HBoxContainer.new()
	_shield_box.z_index = PuppetStage.CEILING_Z + 3
	_shield_box.custom_minimum_size = PuppetTopHud.RING_TEXT
	_shield_box.alignment = BoxContainer.ALIGNMENT_CENTER
	_shield_box.visible = false
	_shield_label = UiTheme.label("", PuppetTopHud.SHIELD_PX, Color(0.31, 0.49, 0.56))  # (the ring's second line: the Shield, blue-grey like the page's)
	if hp_font != null:
		_shield_label.add_theme_font_override("font", hp_font)
	_shield_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_shield_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_shield_box.add_child(_shield_label)
	add_child(_shield_box)
	_lasting_label = UiTheme.label("", PuppetTopHud.LASTING_PX, Color(0.698, 0.847, 0.953))  # (under the bar: "Lasting 4")
	if hp_font != null:
		_lasting_label.add_theme_font_override("font", hp_font)
	_lasting_label.z_index = PuppetStage.CEILING_Z + 3
	add_child(_lasting_label)
	_bottle_row = HBoxContainer.new()
	_bottle_row.add_theme_constant_override("separation", 0)
	_bottle_row.z_index = PuppetStage.CEILING_Z + 3
	add_child(_bottle_row)
	_debuff_board = NinePatchRect.new()
	_debuff_board.texture = UiSkin.tex("debuff_board")
	for side in ["left", "top", "right", "bottom"]:
		_debuff_board.set("patch_margin_" + side, PuppetTopHud.DEBUFF_MARGIN)
	_debuff_board.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_debuff_board)
	move_child(_debuff_board, _stage.get_index() + 1)
	_top_layer = Control.new()
	_top_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_top_layer)
	move_child(_top_layer, _stage.get_index() + 1)
	for n in [_bottles_frame, _arts_frame, _hp_bar, _heart, _hp_label, _shield_box, _lasting_label, _bottle_row, _arts, _player_panel]:
		if n != null:
			n.reparent(_top_layer, false)
	_build_act_sign()
	_status_row = HFlowContainer.new()
	_status_row.add_theme_constant_override("h_separation", STATUS_GAP)
	_status_row.add_theme_constant_override("v_separation", STATUS_GAP)
	_status_row.z_index = 1
	add_child(_status_row)
	_fit_debuff_board(0)
	_pstatus = RichTextLabel.new()  # (not shown: statuses are icons)


## New UI: the HUD of page 2 of the Chant UI PDF. Everything stands on the screen itself (in _top_layer, which sinks with the HUD between fights); `_player_panel` is
## only a marker the effects that land on you fly to.
func _rebuild_character_panel_nu() -> void:
	var L = NewUiLayout
	_puppet_hud = true
	var old := _player_panel
	_player_panel = Control.new()
	_player_panel.position = L.HP_BAR.position
	_player_panel.size = L.HP_BAR.size
	_player_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_player_panel)
	old.queue_free()
	_nu_back = L.Back.new()
	_nu_back.size = Vector2(1920.0, 1080.0)  # (it draws on the whole screen: a Control of size 0 that is redrawn while its parent shakes drops out of the picture for a frame or two)
	add_child(_nu_back)
	_hp_bar = L.Bar.new()
	_hp_bar.position = L.HP_BAR.position
	_hp_bar.size = L.HP_BAR.size
	_hp_bar.custom_minimum_size = L.HP_BAR.size
	_hp_bar.z_index = 1
	add_child(_hp_bar)
	var hp_font := UiTheme.cut("boldoblique")
	if hp_font == null:
		hp_font = UiTheme.cut("bold")
	_hp_label = UiTheme.label("", L.HP_PX, Color.WHITE)
	if hp_font != null:
		_hp_label.add_theme_font_override("font", hp_font)
	_hp_label.size = Vector2(110.0, L.HP_BAR.size.y)
	_hp_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_hp_label.z_index = 2
	add_child(_hp_label)
	_shield_box = HBoxContainer.new()
	_shield_box.z_index = 2
	_shield_box.custom_minimum_size = Vector2(60.0, L.HP_BAR.size.y)
	_shield_box.alignment = BoxContainer.ALIGNMENT_END
	_shield_box.visible = false
	_shield_label = UiTheme.label("", L.HP_PX, Color.WHITE)
	if hp_font != null:
		_shield_label.add_theme_font_override("font", hp_font)
	_shield_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_shield_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_shield_box.add_child(_shield_label)
	add_child(_shield_box)
	_lasting_label = UiTheme.label("", 14, Color(0.698, 0.847, 0.953))  # (under the bar, at its right end: "Lasting 4")
	if hp_font != null:
		_lasting_label.add_theme_font_override("font", hp_font)
	_lasting_label.z_index = 2
	add_child(_lasting_label)
	_bottle_row = HBoxContainer.new()
	_bottle_row.add_theme_constant_override("separation", 0)
	_bottle_row.z_index = 2
	add_child(_bottle_row)
	_top_layer = Control.new()
	_top_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_top_layer)
	move_child(_top_layer, _stage.get_index() + 1)
	for n in [_nu_back, _hp_bar, _hp_label, _shield_box, _lasting_label, _bottle_row, _arts, _player_panel]:
		n.reparent(_top_layer, false)
	_info.reparent(_top_layer, false)  # (no hanging sign: the Act / Floor / Turn line is written on the second tab of the HUD, always shown)
	_info.position = L.ACT_TEXT.position
	_info.size = L.ACT_TEXT.size
	_info.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_info.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_info.autowrap_mode = TextServer.AUTOWRAP_OFF
	_info.add_theme_font_size_override("font_size", 18)
	_info.add_theme_color_override("font_color", Color.WHITE)
	var oblique := UiTheme.cut("oblique")
	if oblique != null:
		_info.add_theme_font_override("font", oblique)
	_info.z_index = 4
	_info.visible = true
	_status_row = Control.new()  # (the debuff icons stand on the green circles of _nu_back, placed by _fit_debuff_board)
	_status_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_status_row.position = L.DEBUFF_AT
	_status_row.size = Vector2(L.DEBUFF_COLS * L.DEBUFF_STEP, L.DEBUFF_PX)
	_status_row.z_index = 1
	_top_layer.add_child(_status_row)
	_fit_debuff_board(0)
	_pstatus = RichTextLabel.new()  # (not shown: statuses are icons)


## The artifact bar of the top frame (Puppet) or of the corner (the other themes).
func _make_arts() -> ArtifactBar:
	var bar := ArtifactBar.make(fight.artifacts, fight.artifact_plus)
	bar.position = Vector2(28, 52)
	if _nu_ui:  # (ten slots in two rows of five, as the page has them)
		bar.chip_px = NewUiLayout.ART_PX
		bar.row_width = NewUiLayout.ART_CELL.x * NewUiLayout.ART_COLS
		bar.slot_step = NewUiLayout.ART_CELL.x
		bar.per_row = NewUiLayout.ART_COLS
		bar.row_gap = NewUiLayout.ART_CELL.y - NewUiLayout.ART_PX
		bar.z_index = 3
	elif UiSkin.is_puppet():
		bar.chip_px = ART_PX
		bar.row_width = ART_STEP * (ART_ROW - 1) + ART_PX + 4.0  # (five to a row, the next ones wrap to a second row)
		bar.slot_step = ART_STEP
		bar.per_row = ART_ROW
		bar.z_index = PuppetStage.CEILING_Z + 3
	return bar


## A painted board of the HUD, 9 slices (margins: left, top, right, bottom).
func _nine_frame(tex_name: String, r: Rect2, m: Array) -> NinePatchRect:
	var f := NinePatchRect.new()
	f.texture = UiSkin.tex(tex_name)
	f.patch_margin_left = int(m[0])
	f.patch_margin_top = int(m[1])
	f.patch_margin_right = int(m[2])
	f.patch_margin_bottom = int(m[3])
	f.position = r.position
	f.size = r.size
	f.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(f)
	move_child(f, _stage.get_index() + 1)
	return f


## The bottle frame (one row of five) and the artifact frame (two rows of five) stand where the PDF has them, bottom left. A frame is only there when you carry something;
## a sixth bottle widens the bottle frame, a third row of artifacts makes the artifact frame taller (upwards: its bottom is the page's).
func _fit_hud_frames() -> void:
	if _nu_ui and _puppet_hud:
		_fit_hud_nu()
		return
	if not _puppet_hud or _bottles_frame == null:
		return
	var T = PuppetTopHud
	var nb: int = fight.player.bottles.size()
	var na: int = _arts.artifacts.size()
	_bottles_frame.visible = nb > 0
	_bottle_row.visible = nb > 0
	if nb > 0:
		var b_w: float = maxf(T.BOTTLES.size.x, 2.0 * T.SLOT_PAD.x + nb * BOTTLE_STEP)
		_bottles_frame.position = T.BOTTLES.position
		_bottles_frame.size = Vector2(b_w, T.BOTTLES.size.y)
		_bottle_row.position = Vector2(T.BOTTLES.position.x + T.SLOT_PAD.x + (BOTTLE_STEP - BOTTLE_PX) / 2.0, T.BOTTLES.position.y + (T.BOTTLES.size.y - BOTTLE_PX) / 2.0)
	_arts_frame.visible = na > 0
	_arts.visible = na > 0
	if na > 0:
		var rows: int = ceili(float(na) / ART_ROW)
		var a_h: float = T.BOTTLES.size.y if rows <= 1 else T.ARTIFACTS.size.y + (rows - 2) * (ART_PX + ART_ROW_GAP)
		var a_y: float = T.ARTIFACTS.end.y - a_h if rows > 2 else T.ARTIFACTS.position.y
		_arts_frame.position = Vector2(T.ARTIFACTS.position.x, a_y)
		_arts_frame.size = Vector2(T.ARTIFACTS.size.x, a_h)
		var inner_h: float = rows * ART_PX + (rows - 1) * ART_ROW_GAP
		_arts.position = Vector2(T.ARTIFACTS.position.x + (T.ARTIFACTS.size.x - (ART_STEP * (ART_ROW - 1) + ART_PX)) / 2.0, a_y + (a_h - inner_h) / 2.0)
	_hp_bar.position = T.TRAY.position
	_player_panel.position = _hp_bar.position
	if _heart != null:
		_heart.position = T.HEART_AT
	_hp_label.position = T.RING_HP_AT
	_shield_box.position = T.RING_SHIELD_AT
	_lasting_label.position = T.LASTING_AT


## New UI: the Menu button is the word MENU on the first tab of the HUD: no plate of its own, the tab (drawn by NewUiLayout.Back) gets lighter under the mouse and darker when pressed.
func _style_nu_menu(b: Button) -> void:
	for st in ["normal", "hover", "pressed", "disabled", "focus"]:
		b.add_theme_stylebox_override(st, StyleBoxEmpty.new())
	b.text = "MENU"
	var bold := UiTheme.cut("bold")
	if bold != null:
		b.add_theme_font_override("font", bold)
	b.add_theme_font_size_override("font_size", 18)
	for c in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		b.add_theme_color_override(c, Color.WHITE)
	b.flat = true
	b.focus_mode = Control.FOCUS_NONE
	b.z_index = 4
	b.mouse_entered.connect(func() -> void: _nu_menu_state(1))
	b.mouse_exited.connect(func() -> void: _nu_menu_state(0))
	b.button_down.connect(func() -> void: _nu_menu_state(2))
	b.button_up.connect(func() -> void: _nu_menu_state(1 if b.is_hovered() else 0))


func _nu_menu_state(k: int) -> void:
	if _nu_back != null:
		_nu_back.menu_state = k
		_nu_back.queue_redraw()


## New UI: the artifacts and bottles stand in their slots, the HP numbers on the bar (red = HP, blue = Shield and Lasting after it).
func _fit_hud_nu() -> void:
	var L = NewUiLayout
	_arts.visible = true
	_arts.position = L.ART_AT + (L.ART_CELL - Vector2.ONE * L.ART_PX) / 2.0
	_bottle_row.visible = true
	_bottle_row.position = L.BOTTLE_AT + (L.BOTTLE_CELL - Vector2.ONE * L.BOTTLE_PX) / 2.0
	var bar := _hp_bar as NewUiLayout.Bar
	var parts := bar.parts()
	var fill: Rect2 = Rect2(L.HP_BAR.position + L.HP_FILL.position, L.HP_FILL.size)  # (the pill the liquid is in, on the screen)
	_hp_label.position = fill.position + Vector2(30.0, 0.0)  # (clear of the left clamp)
	_hp_label.size = Vector2(110.0, fill.size.y)
	var end_x: float = fill.position.x + parts.x  # (the Shield lies over the end of the HP: its number stands at the end of the HP)
	_shield_box.custom_minimum_size = Vector2(60.0, fill.size.y)
	_shield_box.position = Vector2(maxf(end_x - 12.0 - 60.0, _hp_label.position.x + 80.0), fill.position.y)
	_shield_box.size = _shield_box.custom_minimum_size
	_lasting_label.size = Vector2(160.0, 20.0)
	_lasting_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_lasting_label.position = Vector2(L.HP_BAR.end.x - _lasting_label.size.x, L.HP_BAR.position.y - 22.0)  # (above the tube, its right end level with the tube's)
	_player_panel.position = L.HP_BAR.position


const STATUS_CHIP := 52.0  # as tall as an orb of the Bag
const STATUS_GAP := 4
const DEBUFF_PAD := 22.0


## The debuff board holds exactly the icons you have: it grows right from its corner at the top left as they come, and is gone when there are none.
func _fit_debuff_board(n: int) -> void:
	if _nu_ui:
		_nu_back.debuffs = n
		_nu_back.queue_redraw()
		var rows := maxi(1, ceili(n / float(NewUiLayout.DEBUFF_COLS)))
		var k := 0
		for chip: Control in _status_row.get_children():
			if chip.is_queued_for_deletion():  # (the icons of the last refresh are still there until the end of the frame)
				continue
			chip.size = Vector2.ONE * NewUiLayout.DEBUFF_PX
			chip.position = NewUiLayout.debuff_slot(k, rows) - NewUiLayout.DEBUFF_AT
			k += 1
		return
	if _debuff_board == null:
		return
	_debuff_board.visible = n > 0
	_status_row.visible = n > 0
	if n <= 0:
		return
	var h: float = PuppetTopHud.DEBUFF_MIN.y  # (one row)
	var room: float = PuppetTopHud.DEBUFF_MAX_RIGHT - PuppetTopHud.DEBUFF_AT.x - 2.0 * DEBUFF_PAD
	var step := minf(STATUS_CHIP + STATUS_GAP, (room - STATUS_CHIP) / maxf(1.0, n - 1.0))  # (a very long row squeezes together)
	var inner_w := (n - 1) * step + STATUS_CHIP
	var w := maxf(2.0 * DEBUFF_PAD + inner_w, 64.0)
	_debuff_board.size = Vector2(w, h)
	var lift: float = -clampf(_hud_shift / HUD_DOWN, 0.0, 1.0) * DEBUFF_LIFT
	_debuff_board.position = PuppetTopHud.DEBUFF_AT + Vector2(0.0, lift)
	_status_row.add_theme_constant_override("h_separation", int(floor(step - STATUS_CHIP)))
	_status_row.custom_minimum_size = Vector2(inner_w, STATUS_CHIP)
	_status_row.size = Vector2(inner_w, STATUS_CHIP)
	_status_row.position = _debuff_board.position + Vector2((w - inner_w) / 2.0, (h - STATUS_CHIP) / 2.0)


## The hanging sign with the Act / Floor / Turn line (Stage/Shared/hanging_sign.png at the place the PDF gives it). It waits hidden above the screen, so the
## first frame never shows it in its place.
func _build_act_sign() -> void:
	var T = PuppetTopHud
	_act_sign = Control.new()
	_act_sign.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_act_sign.position = T.ACT_SIGN.position + Vector2(0.0, -_act_sign_up())
	_act_sign.size = T.ACT_SIGN.size
	_act_sign.z_index = PuppetStage.CEILING_Z - 1  # (under the ceiling: its chains hang from behind the valance)
	var pic := TextureRect.new()
	pic.texture = load(UiSkin.theme_dir() + "Stage/Shared/hanging_sign.png")
	pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	pic.stretch_mode = TextureRect.STRETCH_SCALE
	pic.size = T.ACT_SIGN.size
	pic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_act_sign.add_child(pic)
	_info.reparent(_act_sign, false)
	_info.position = T.ACT_TEXT.position - T.ACT_SIGN.position
	_act_sign.visible = false
	add_child(_act_sign)


func _act_sign_up() -> float:
	return PuppetTopHud.ACT_SIGN.end.y + 20.0  # (far enough up that all of it is above the screen)


## The sign drops on its chains (a bounce, like the Victory sign). `from_arrival`: the props and the enemies are out, so it goes back up
## `PuppetTopHud.ACT_SHOWN` seconds from now (a drop that is only the fight starting leaves the countdown to the arrival).
func _show_act_sign(from_arrival := false) -> void:
	if _act_sign == null or map_mode or not is_inside_tree():
		return
	var rest: float = PuppetTopHud.ACT_SIGN.position.y
	if not _act_sign.visible:
		_act_sign.visible = true
		var tw := create_tween()
		tw.tween_property(_act_sign, "position:y", rest, 0.55).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tw.tween_property(_act_sign, "position:y", rest - 38.0, 0.16).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.tween_property(_act_sign, "position:y", rest, 0.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tw.tween_property(_act_sign, "position:y", rest - 12.0, 0.1).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.tween_property(_act_sign, "position:y", rest, 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		_act_sign_gen += 1
	if from_arrival:
		var gen := _act_sign_gen
		await get_tree().create_timer(PuppetTopHud.ACT_SHOWN).timeout
		if gen == _act_sign_gen and is_inside_tree():
			_lift_act_sign()


## The sign goes back up behind the valance (at once when `now`).
func _lift_act_sign(now := false) -> void:
	if _act_sign == null or not _act_sign.visible:
		return
	_act_sign_gen += 1
	var up: float = PuppetTopHud.ACT_SIGN.position.y - _act_sign_up()
	if now:
		_act_sign.position.y = up
		_act_sign.visible = false
		return
	var gen := _act_sign_gen
	var tw := create_tween()
	tw.tween_property(_act_sign, "position:y", up, 0.7).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	await tw.finished
	if gen == _act_sign_gen and is_instance_valid(_act_sign):
		_act_sign.visible = false


func _refresh_coin() -> void:
	if _coin_label != null and run != null:
		_coin_label.text = str(run.amber)


## Statuses as small icons: a coloured frame, the picture (or its emoji), the amount in the corner; hover for the words.
func _status_px() -> float:
	return NewUiLayout.DEBUFF_PX if _nu_ui else STATUS_CHIP


func _refresh_statuses_compact() -> void:
	for c in _status_row.get_children():
		c.queue_free()
	var shown := 0
	for b in _status_badges():
		var id := String(b[2])
		var chip := TipPanel.new()
		chip.custom_minimum_size = Vector2(_status_px(), _status_px())
		chip.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
		var holder := Control.new()
		holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
		chip.add_child(holder)
		var icon: Control = UiSkin.icon(_badge_art_name(b), _status_px())
		if icon != null:
			chip.hover_tex = icon.texture
			chip.hover_left = true  # (its board appears to the left of the icon: the Chant strip stays in view)
		if id.begins_with("attune_"):
			icon = ElementIcon.make(id.substr(7), _status_px() - 4.0)
		if icon == null:  # (no picture: the emoji that leads its words)
			var em := UiTheme.label(String(b[0]).get_slice(" ", 0), 24, Color.WHITE)
			em.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			em.mouse_filter = Control.MOUSE_FILTER_IGNORE
			icon = em
		icon.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		holder.add_child(icon)
		var digits := ""
		for ch in String(b[0]):
			if ch >= "0" and ch <= "9":
				digits += ch
			elif digits != "":
				break
		if digits != "":
			var n := UiTheme.label(digits, 20, Color.WHITE)
			n.add_theme_constant_override("outline_size", 6)
			n.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.95))
			n.mouse_filter = Control.MOUSE_FILTER_IGNORE
			n.position = Vector2(_status_px() - 8.0 - 12.0 * digits.length(), _status_px() - 30.0)
			holder.add_child(n)
		var tip: String = Keywords.K.get(id, [0, 0, ""])[2]
		chip.tooltip_text = b[3] if b.size() > 3 else (Keywords.tooltip(b[0], tip) if tip != "" else String(b[0]))
		if chip.hover_tex != null:  # (the board shows the picture big: the little emoji in front of the title goes)
			var lead := String(b[0]).get_slice(" ", 0)
			var at := chip.tooltip_text.find(lead + " ")
			if lead != "" and at >= 0 and lead.unicode_at(0) > 255:
				chip.tooltip_text = chip.tooltip_text.erase(at, lead.length() + 1)
		if b.size() > 4:
			chip.set_meta("power_id", b[4])
		chip.mouse_filter = Control.MOUSE_FILTER_STOP
		_status_row.add_child(chip)
		shown += 1
	_fit_debuff_board(shown)


## Where the enemies' feet are (the spotlights follow them).
func _enemy_feet() -> Array:
	var out: Array = []
	for e in _views:
		var v: EnemyView = _views[e]
		if is_instance_valid(v) and is_instance_valid(v.creature) and not e.is_dead() and not v.creature.has_rig():  # (a hand hangs on his shoulder: no light at its feet)
			out.append(v.creature.global_position + Vector2(v.creature.size.x / 2.0, v.creature.size.y))
	if _hm_stage != null and is_instance_valid(_hm_stage):
		var body_feet = _hm_stage.body_feet()  # (his body, while it is only a picture)
		if body_feet != null:
			out.append(body_feet)
	return out


## Puppet Stage: the spell cards sit just above the line of text over the Chant strip.
func _place_spell_row() -> void:
	if not _puppet_strips() or _spell_row == null or _chant_panel == null or _spell_row.get_child_count() == 0:
		return
	var h := 0.0
	for c in _spell_row.get_children():
		h = maxf(h, maxf(c.custom_minimum_size.y, c.get_combined_minimum_size().y))  # (a wordy card is taller than its nominal height: it must not reach down over the chant)
	_spell_row.position.y = _chant_panel.position.y - 5.0 - h
	if _nu_ui:
		_spell_row.position.y = NewUiLayout.SPELL_BOTTOM - (SpellCard.H * float(_cards[0].base_scale) if not _cards.is_empty() else h) + _hud_shift  # (the cards' bottom edge is where the page has it; while the HUD is sunk below the screen the row sinks with it, and _set_hud_shift brings it up with the rest)


## The sound of an Essence you move: "grab" (it leaves the bag / is picked up), "place" (it drops into the chant), "remove" (it goes back).
## The Puppet Stage plays only its wooden sounds (a grab is silent: the "hole" sounds when it lands in the chant, a return is the low "colide").
func _elem_sound(kind: String) -> void:
	if _puppet_strips():
		if kind == "place" or kind == "grab":  # (the recordings start with a little silence: skipped, so the sound is at the click)
			Audio.play("wooden_ball_hole", 0.0, 1.0, 0.06)
		elif kind == "remove":
			Audio.play("wooden_ball_colide", 0.0, 0.8, 0.1)  # (the same knock, 20% lower)
		return
	Audio.play("elem_remove" if kind == "remove" else "elem_pickup")


## The sounds of the balls: the Puppet Stage has wooden ones (wooden_ball_*), the other themes keep the old pair.
func _ball_sound(kind: String, volume_db := 0.0, pitch := 1.0) -> void:
	var names := {"roll": "sfx_ball_roll", "hit": "sfx_ball_clack", "hole": "sfx_ball_clack"}
	if _puppet_strips():
		names = {"roll": "wooden_ball_roll", "hit": "wooden_ball_colide", "hole": "wooden_ball_hole", "swap": "wooden_ball_swap"}
	if names.has(kind):
		Audio.play(names[kind], volume_db, pitch)


## Puppet Stage: the Bag's balls swap into their types (fire, water, wind) once a launch is over: first the new balls stack after the old
## ones, a moment later everybody slides to the right place, with a small lift and one wooden "swap".
func _resort_bag() -> void:
	if not _puppet_strips() or _resort_wait or _keep_bag_order:
		return
	_resort_wait = true
	await get_tree().create_timer(0.45).timeout
	_resort_wait = false
	if fight == null or not is_inside_tree() or _launching > 0 or _tube_prep:
		return  # (another launch has begun: it calls this again when it is over)
	_resort = true
	_refresh_stock()
	_resort = false


## Puppet Stage: the strips and the lottery-ball machine of "Chant UI for puppet.pdf" (cut by tools/export_puppet_chant.py, laid out by
## PuppetLayout). It shares everything else of the Cirus strips (the Essence roll along the Bag, the tube logic), so _circus_strips() is
## true for it too; only the building and the tube / machine functions look at _puppet_strips().


func _puppet_strips() -> bool:
	if not UiSkin.is_puppet() or UiSkin.tex("chant_frame") == null or UiSkin.tex("bag_frame") == null:
		return false
	return SlotMachine.available()


func _circus_strips() -> bool:
	if UiSkin.is_puppet():
		return _puppet_strips()
	return UiSkin.is_circus() and UiSkin.tex("chant_frame") != null and UiSkin.tex("bag_frame") != null and UiSkin.tex("tube_glass") != null \
		and UiSkin.tex("tube_back") != null and UiSkin.tex("tube_gear") != null and UiSkin.tex("crank_plate") != null and UiSkin.tex("crank_handle") != null


func _strip_art(tex_name: String, pos: Vector2) -> TextureRect:
	var r := TextureRect.new()
	r.texture = UiSkin.tex(tex_name)
	r.position = pos
	r.size = r.texture.get_size()
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return r


## The machine's glass sheets are blended with "Screen" (screen_blend.gdshader): they only lighten what is behind them, so the balls show
## through them. Without the shader file they fall back to plain 40 % opacity.
func _glass_art(tex_name: String, pos: Vector2) -> TextureRect:
	var r := _strip_art(tex_name, pos)
	var sh := load("res://assets/Global/Card/Shaders/screen_blend.gdshader") as Shader
	if sh != null:
		var m := ShaderMaterial.new()
		m.shader = sh
		m.set_shader_parameter("strength", 0.85)
		r.material = m
	else:
		r.modulate.a = 0.4
	return r


func _build_strips_puppet() -> void:
	var cap := PuppetLayout.CAP
	var margins := [int(cap.x), 0, int(cap.y), 0]  # (3 slices: a cap at each end, a plain middle, no stretch in height)
	var cp := PanelContainer.new()
	cp.add_theme_stylebox_override("panel", StyleBoxEmpty.new() if _nu_ui else UiSkin.box("chant_frame", margins))  # (New UI: the dark block of the page is the Chant strip)
	_chant_panel = cp
	cp.position = _bag_at() + PuppetLayout.CHANT_AT
	cp.custom_minimum_size = PuppetLayout.FRAME_CHANT
	var cin := Control.new()
	cin.custom_minimum_size = PuppetLayout.FRAME_CHANT
	cin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cp.add_child(cin)
	# what the chant row says ("3 Essence", Toll, Hypnotized...): just above the strip
	_chant_note = UiTheme.label("", 15, Color.WHITE)
	_chant_note.position = Vector2(PuppetLayout.RING_X0, -26)
	_chant_note.z_index = 5  # (over the spell cards that now stand right on the strip)
	_chant_note.add_theme_constant_override("outline_size", 5)
	_chant_note.add_theme_color_override("font_outline_color", Color(0.1, 0.05, 0.03))
	_chant_note.mouse_filter = Control.MOUSE_FILTER_STOP
	cin.add_child(_chant_note)
	_chant_row = HBoxContainer.new()
	_chant_row.add_theme_constant_override("separation", 6)
	_chant_row.position = Vector2(PuppetLayout.RING_X0, PuppetLayout.RING_CY - PUPPET_RING_PX / 2.0)
	cin.add_child(_chant_row)
	_cast_btn = UiTheme.button("Chant", _on_primary, 15)
	UiTheme.use_heading_font(_cast_btn)
	_place(_cast_btn, PuppetLayout.BTN_CHANT)
	UiTheme.style_puppet_button(_cast_btn, "chant", 18)
	_cast_btn.tooltip_text = "Chant (Enter) / Release (E)"
	cin.add_child(_cast_btn)
	# Clear (Undo takes its place after the chant) and Pass each sit in a fixed slot
	var clear_slot := Control.new()
	_place(clear_slot, PuppetLayout.BTN_CLEAR)
	cin.add_child(clear_slot)
	_clear_btn = UiTheme.button("Clear", _clear_chant, 13)
	UiTheme.use_heading_font(_clear_btn)
	UiTheme.style_puppet_button(_clear_btn, "clear", 14)
	_clear_btn.tooltip_text = "Clear the chant (Backspace)."
	_clear_btn.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	clear_slot.add_child(_clear_btn)
	var pass_slot := Control.new()
	_place(pass_slot, PuppetLayout.BTN_PASS)
	cin.add_child(pass_slot)
	_end_btn = UiTheme.button("Pass", _on_end_turn, 13)
	UiTheme.use_heading_font(_end_btn)
	UiTheme.style_puppet_button(_end_btn, "pass", 14)
	_end_btn.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_end_btn.tooltip_text = "End your turn without chanting (you keep your Essence). (E)"
	pass_slot.add_child(_end_btn)
	add_child(cp)
	# the Bag strip, then the slot machine (Slot_machine.pdf, SlotMachine) on its right. Layers: the strip, the glass tube and the port's hole, every Essence
	# (in the strip, in the tube, hidden behind the funnels and the cabinet), then the funnels, the cabinet with its reels, lamps and lever, the tube's clamps
	# and the port's ring on top of them.
	var sp := PanelContainer.new()
	_bag_panel = sp
	sp.add_theme_stylebox_override("panel", StyleBoxEmpty.new() if _nu_ui else UiSkin.box("bag_frame", margins))  # (New UI: the Bag tray is drawn in NewUiLayout.Back)
	sp.position = cp.position - PuppetLayout.CHANT_AT
	sp.custom_minimum_size = PuppetLayout.FRAME_BAG
	var inner := Control.new()
	inner.custom_minimum_size = PuppetLayout.FRAME_BAG
	inner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sp.add_child(inner)
	_machine = SlotMachine.new()
	if _nu_ui:  # (the same machine, bigger, at the right end of the Bag strip, with a straight tube: see NewUiLayout)
		_machine.xs = NewUiLayout.MACHINE_SCALE
		_machine.xp = NewUiLayout.MACHINE_POS
		_machine.straight = true
		_machine.spawn_c = Vector2(NewUiLayout.MOUTH_X, NewUiLayout.TUBE_ROW_Y)
		_machine.lever_shift = NewUiLayout.LEVER_SHIFT
	_machine.build()
	_machine.behind.show_behind_parent = true  # (the tube comes out from under the Bag strip)
	sp.add_child(_machine.behind)
	sp.move_child(_machine.behind, 0)
	inner.add_child(_machine.back)
	_stock_row = Control.new()
	_stock_row.mouse_filter = Control.MOUSE_FILTER_PASS
	_stock_row.custom_minimum_size = Vector2(1100.0, PuppetLayout.FRAME_BAG.y)
	_stock_row.size = _stock_row.custom_minimum_size
	inner.add_child(_stock_row)
	if _nu_ui:
		inner.add_child(_machine.over)  # (the tube's clamp, over the Essence)
	inner.add_child(_machine.front)
	add_child(sp)


## The Bag strip's top-left on the screen.
func _bag_at() -> Vector2:
	return NewUiLayout.BAG_AT if _nu_ui else PuppetLayout.BAG_AT


func _place(c: Control, r: Rect2) -> void:
	c.position = r.position
	c.custom_minimum_size = r.size
	c.size = r.size


const PUPPET_RING_PX := 52.0


## Where the k-th resting Essence of the bag sits (local to _stock_row) when there are n of them: Cirus lays them in one
## row from the strip's left end, squeezing together (even overlapping) when there are more than fit before the crank.
func _bag_slot(k: int, n: int) -> Vector2:
	if not _circus_strips():
		return Vector2(minf(_stock_row.size.x - BAG_PX, k * (BAG_PX + BAG_GAP)), 0)
	if _puppet_strips():
		var proom := (NewUiLayout.REST_END if _nu_ui else PuppetLayout.REST_END) - PuppetLayout.REST_X - BAG_PX
		var pstep := minf(PuppetLayout.RING_STEP, proom / maxf(1.0, n - 1))
		return Vector2(PuppetLayout.REST_X + minf(k * pstep, proom), PuppetLayout.AXIS_Y - BAG_PX / 2.0)
	var room := ChantLayout.REST_END - ChantLayout.REST_X - BAG_PX
	var step := minf(BAG_PX + 4.0, room / maxf(1.0, n - 1))
	return Vector2(ChantLayout.REST_X + minf(k * step, room), ChantLayout.AXIS_Y - BAG_PX / 2.0)


## The crank turns once and the gear twice (the same 0.9 s).
func _turn_crank(seconds := 0.9) -> void:
	if _puppet_strips():
		return  # (the slot machine's lever is pulled by _puppet_launch)
	if _tube_handle == null or not is_instance_valid(_tube_handle) or (_crank_tween != null and _crank_tween.is_valid()):
		return
	_tube_handle.rotation = 0.0
	_tube_gear.rotation = 0.0
	Audio.play("sfx_crank_ratchet", -6.0)
	_crank_tween = create_tween().set_parallel(true)
	_crank_tween.tween_property(_tube_handle, "rotation", TAU, seconds).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_crank_tween.tween_property(_tube_gear, "rotation", TAU * 2.0, seconds).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_crank_tween.chain().tween_callback(func():
		_tube_handle.rotation = 0.0
		_tube_gear.rotation = 0.0)


## Where the j-th of n Essence waiting in the tube sits (local to _stock_row): from the glass's left end, squeezing under
## the red block when there are many.
func _tube_pos(j: int, n: int) -> Vector2:
	var x0: float = ChantLayout.TUBE_GLASS.x + 28.0
	var step := minf(TUBE_BALL_STEP, (ChantLayout.TUBE_RIGHT - 8.0 - BAG_PX - x0) / maxf(1.0, n - 1))
	return Vector2(x0 + j * step, ChantLayout.AXIS_Y - BAG_PX / 2.0)


## Where an Essence enters the tube: wholly inside the red block (it must never poke out of the tube's right end), so it
## is hidden there until it rolls out of it into the glass.
func _tube_hidden() -> Vector2:
	return Vector2(minf(ChantLayout.TUBE_HIDE_X + 8.0, ChantLayout.TUBE_RIGHT - BAG_PX - 10.0), ChantLayout.AXIS_Y - BAG_PX / 2.0)


## A ball rolling left along the strip from where it is to to_x (spinning whole turns, so it ends upright); a soft tok at the
## end. Used for the Essence rolling into the tube.
func _roll_in(ic: ElementIcon, to_x: float, delay: float) -> void:
	_rolling_in += 1
	if delay > 0.0:
		await get_tree().create_timer(delay).timeout
	if not is_instance_valid(ic) or ic.is_queued_for_deletion():
		_rolling_in -= 1
		return
	var d := ic.position.x - to_x
	if d <= 1.0:
		ic.position.x = to_x
		_rolling_in -= 1
		return
	var t := 0.3 + d / 650.0
	var turns := roundf(d / (PI * BAG_PX))
	_ball_sound("roll", -7.0, randf_range(0.9, 1.1))
	ic.set_meta("tube_to", to_x)
	var from_x := ic.position.x
	var tw := ic.create_tween().set_parallel(true)
	tw.tween_method(func(u: float) -> void:
		if is_instance_valid(ic):
			var e := 1.0 - (1.0 - u) * (1.0 - u)
			ic.position.x = _no_overlap(ic, lerpf(from_x, to_x, e), _tube_icons.filter(func(c): return c != ic and is_instance_valid(c) and c.has_meta("tube_to") and float(c.get_meta("tube_to")) < to_x)), 0.0, 1.0, t)
	tw.tween_property(ic, "rotation", -TAU * turns, t).from(0.0).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	await tw.finished
	_rolling_in -= 1
	if not is_instance_valid(ic) or ic.is_queued_for_deletion():
		return
	ic.rotation = 0.0
	_ball_sound("hit", -5.0, randf_range(0.85, 1.0))


## A rolling ball may not go through the ones in front of it (smaller x, on the same row): it stays one ball's width behind the nearest.
func _no_overlap(ic: Control, x: float, ahead: Array, gap := -1.0) -> float:
	if gap < 0.0:
		gap = BAG_PX + 3.0
	for o in ahead:
		if is_instance_valid(o) and o.position.x < ic.position.x - 1.0:  # (strictly in front: balls that wait at the same spot do not count)
			x = maxf(x, o.position.x + gap)
	return x


## Cirus "coming next turn": the tube holds next turn's Essence (fight.player.next_draw), in the bag's order (fire, water,
## wind). New ones are spawned inside the red block and roll out of it one by one; the others slide along to make room. A
## ball a spell sent is already waiting in the red block and just rolls in. After a launch the tube stays empty for 2 s.
func _sync_tube() -> void:
	if not _circus_strips() or fight == null or _tube_prep:
		return
	if Time.get_ticks_msec() < _tube_hold_until:  # (the tube is resting after a launch)
		if not _tube_sync_pending:
			_tube_sync_pending = true
			get_tree().create_timer((_tube_hold_until - Time.get_ticks_msec()) / 1000.0 + 0.05).timeout.connect(func():
				_tube_sync_pending = false
				_sync_tube())
		return
	if _puppet_strips():
		_sync_reels()
		return
	var ranked: Array = []
	for i in fight.player.next_draw.size():
		var d: Dictionary = fight.player.next_draw[i]
		ranked.append([maxi(0, "FWA".find(d.el) + 1), i, d])
	ranked.sort_custom(func(a, b): return a[0] < b[0] or (a[0] == b[0] and a[1] < b[1]))
	var pool: Array = _tube_icons.filter(func(c): return is_instance_valid(c) and not c.is_queued_for_deletion())
	var now: Array = []
	for r in ranked:
		var d: Dictionary = r[2]
		var found := -1
		for k in pool.size():
			if pool[k].el == d.el and pool[k].temp == d.temp:
				found = k
				break
		if found >= 0:
			now.append(pool[found])
			pool.remove_at(found)
			continue
		var nb := ElementIcon.make(d.el, BAG_PX)
		nb.size = Vector2(BAG_PX, BAG_PX)
		nb.pivot_offset = nb.size / 2.0
		nb.temp = d.temp
		nb.mouse_filter = Control.MOUSE_FILTER_IGNORE
		nb.position = _tube_hidden()
		_stock_row.add_child(nb)
		now.append(nb)
	var keep: Array = []
	for c in pool:
		if c.has_meta("stash_until") and Time.get_ticks_msec() < int(c.get_meta("stash_until")):
			keep.append(c)  # (a spell's Essence that is still on its way in: the effect has not landed yet)
		else:
			c.queue_free()
	_tube_icons = now + keep
	var order := 0
	for j in now.size():
		var ic: ElementIcon = now[j]
		var to := _tube_pos(j, now.size())
		if ic.has_meta("slide"):
			var old: Tween = ic.get_meta("slide")
			if old != null and old.is_valid():
				old.kill()
		if ic.position.x >= ChantLayout.TUBE_HIDE_X - 2.0:  # still inside the red block: it rolls out of it, one after another
			_roll_in(ic, to.x, order * 0.15)
			order += 1
		elif absf(ic.position.x - to.x) > 1.0:
			var tw := ic.create_tween()
			tw.tween_property(ic, "position", to, 0.25).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
			ic.set_meta("slide", tw)


## Cirus: a spell that gives Essence for next turn. Each one flies from the card to the tube and slips in behind the red block
## (it is drawn under the tube's glass layer); once the effect has landed, _sync_tube rolls it into the tube.
func _stash_flight(ev: Dictionary, from: Vector2) -> float:
	if _puppet_strips():
		return _stash_to_machine(ev, from)
	var els: Array = ev.get("drawn", [])
	if els.is_empty():
		var el: String = ev.eff.get("el", "random")
		for i in int(ev.eff.get("n", 1)):
			els.append(["F", "W", "A"].pick_random() if el == "random" else el)
	var last := 0.0
	for i in els.size():
		var ic := ElementIcon.make(els[i], BAG_PX)
		ic.size = Vector2(BAG_PX, BAG_PX)
		ic.pivot_offset = ic.size / 2.0
		ic.temp = ev.eff.get("temp", false)
		ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var a := from - _stock_row.global_position - ic.size / 2.0
		var b := _tube_hidden()
		ic.position = a
		ic.scale = Vector2(0.4, 0.4)
		ic.modulate = Color(1.6, 1.6, 1.6, 0.0)
		ic.set_meta("stash_until", Time.get_ticks_msec() + 4000)
		_stock_row.add_child(ic)
		_tube_icons.append(ic)
		var delay: float = i * 0.14
		var tw := ic.create_tween()
		tw.tween_interval(delay)
		tw.tween_callback(func():
			Audio.play("spell_glow", -7.0, randf_range(1.15, 1.35))  # (it leaves the card: a bright whoosh)
			_ball_sound("hit", -6.0, 1.2))
		tw.tween_method(_stash_step.bind(ic, a, b), 0.0, 1.0, 0.62)
		tw.tween_callback(func():
			ic.rotation = 0.0
			ic.modulate = Color.WHITE
			ic.position = b)
		last = delay + 0.62
	return last + 0.1


## Puppet Stage: Essence a Lens (or the Storm Crown) gives back leave their chant slot, fly to the top funnel and come out of the port like any bonus Essence: the
## Bag's own ball (hidden until then) makes the whole trip. The one whose home is furthest left goes first (the balls cannot pass each other).
func _refund_flight(ev: Dictionary) -> void:
	if not _puppet_strips() or _stock_row == null:
		return
	var uids: Array = ev.uids
	_keep_bag_order = true  # (the refunded balls roll to the back of the Bag: nothing is placed ahead of time or sorted until the next spawn)
	for u in uids:
		_flying[u] = true
	_refresh_stock()
	var by_home: Array = range(mini(ev.els.size(), uids.size()))  # (never more than there are new Essence)
	by_home.sort_custom(func(x: int, y: int) -> bool: return float(_bag_target.get(uids[x], Vector2.ZERO).x) < float(_bag_target.get(uids[y], Vector2.ZERO).x))
	for k in by_home.size():
		var i: int = by_home[k]
		var uid: int = uids[i]
		var slot: int = clampi(int(ev.slots[i]) if i < ev.slots.size() else fight.chant.size() - 1, 0, maxi(0, fight.chant.size() - 1))
		_flying.erase(uid)
		var real: ElementIcon = _bag_icons.get(uid)
		if real != null and is_instance_valid(real):
			real.set_meta("rolling", true)
			real.modulate.a = 0.0
			_bonus_from = _chant_slot_center(slot)
			_tube_launch([[real, _bag_target.get(uid, real.position), uid]])
		else:
			_refresh_stock()
		await _wait(0.18)
	await _wait(0.5)


func _stash_step(u: float, ic: ElementIcon, a: Vector2, b: Vector2) -> void:
	if not is_instance_valid(ic):
		return
	var arc := Vector2(0, -150.0 * sin(u * PI))  # up and over, then down into the tube
	ic.position = a.lerp(b, u * u * (3.0 - 2.0 * u)) + arc
	ic.rotation = -u * TAU * 1.5
	ic.scale = Vector2.ONE * lerpf(0.4, 1.0, minf(1.0, u * 2.0))
	var al := minf(1.0, u * 14.0)
	ic.modulate = Color(1, 1, 1, al).lerp(Color(1.6, 1.6, 1.6, al), 1.0 - u)


## Wait until nothing is rolling any more (the Essence of a launch, or going into the tube): effects that land ON the Essence
## (Freeze, Hex...) start after that.
func _rolls_done() -> void:
	var t0 := Time.get_ticks_msec()
	while (_launching > 0 or _rolling_in > 0) and Time.get_ticks_msec() - t0 < 7000:
		await get_tree().process_frame


## A batch of new Essence rolls out of the tube. At the start of a turn these ARE the Essence that were waiting in the
## tube (they take their places); any others (the first hand of a fight, Essence conjured "now") roll in from the red block
## first. The crank turns once, the gear twice, and the balls roll out and left along the strip, like billiard balls, to
## their places, the first one going furthest. Each stop is a "tok", and the ball it hit rocks a little. 2 s after the last
## ball has left, the tube is loaded for the next turn. balls: [[icon, rest position (local to _stock_row), uid], ...].
func _tube_launch(balls: Array) -> void:
	if balls.is_empty():
		return
	if _puppet_strips():
		_puppet_launch(balls)
		return
	_launching += 1
	balls.sort_custom(func(a, b): return a[1].x < b[1].x)
	var n := balls.size()
	var from_tube := Time.get_ticks_msec() < _turn_batch_until
	_turn_batch_until = 0
	var pool: Array = _tube_icons.filter(func(c): return is_instance_valid(c) and not c.is_queued_for_deletion())
	pool.sort_custom(func(a, b): return a.position.x < b.position.x)
	var starts_x: Array = []
	var dropped := 0
	_tube_prep = true  # (the tube is not reloaded until we know when the last ball leaves)
	for j in n:
		var ic: ElementIcon = balls[j][0]
		ic.set_meta("rolling", true)
		ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var taken := -1
		if from_tube:
			for k in pool.size():
				if pool[k].el == ic.el and pool[k].temp == ic.temp:
					taken = k
					break
		if taken >= 0:  # the ball that was waiting in the tube becomes this one
			var waiting: ElementIcon = pool[taken]
			pool.remove_at(taken)
			ic.position = waiting.position
			ic.modulate.a = 1.0
			starts_x.append(waiting.position.x)
			waiting.queue_free()
		else:  # it rolls out of the red block into the glass first
			var at := _tube_pos(dropped, n)
			ic.modulate.a = 1.0
			ic.position = _tube_hidden()
			_roll_in(ic, at.x, dropped * 0.15)
			dropped += 1
			starts_x.append(at.x)
	_tube_icons = pool  # (whatever was not taken stays waiting)
	var load_wait := 0.1
	if dropped > 0:
		load_wait = 0.8 + (dropped - 1) * 0.15
	await get_tree().create_timer(load_wait).timeout
	_turn_crank()
	await get_tree().create_timer(0.3).timeout
	# when does each ball arrive? one after the other, 0.12 s apart, the first one furthest
	var travel: Array = []
	var starts: Array = []
	var arrive := 0.0
	var last_start := 0.0
	for j in n:
		var d: float = float(starts_x[j]) - balls[j][1].x
		var t := 0.25 + maxf(0.0, d) / 820.0
		travel.append(t)
		arrive = t if j == 0 else maxf(t, arrive + 0.12)
		starts.append(arrive - t)
		last_start = maxf(last_start, arrive - t)
	_tube_hold_until = Time.get_ticks_msec() + int((last_start + 2.0) * 1000.0)  # the tube reloads 2 s after the last ball is away
	_tube_prep = false
	for j in n:
		_roll_ball(balls, j, float(starts_x[j]), float(travel[j]), float(starts[j]))
	_launching -= 1
	_sync_tube()  # (it waits for _tube_hold_until)


## A ball rolling to its place: a steady speed, and only the last quarter of the trip slows to a stop. (The old quadratic ease-out slowed every ball
## down from the start; the ones behind were held back by the one in front, so the whole line seemed to stall on the way before it settled.)
func _roll_ease(u: float) -> float:
	var f := 0.25
	var c := 1.0 / (1.0 - f / 2.0)
	if u <= 1.0 - f:
		return c * u
	var w := 1.0 - u
	return c * (1.0 - f) + c * (f / 2.0 - w * w / (2.0 * f))


func _roll_ball(balls: Array, j: int, from_x: float, t: float, delay: float) -> void:
	if not is_instance_valid(balls[j][0]):
		return  # (freed before its turn to roll)
	var ic: ElementIcon = balls[j][0]
	var uid: int = balls[j][2]
	var turns := roundf(maxf(0.0, from_x - balls[j][1].x) / (PI * BAG_PX))  # whole turns, so it comes to rest the right way up
	_launching += 1
	await get_tree().create_timer(delay).timeout
	if not is_instance_valid(ic) or ic.is_queued_for_deletion():
		_launching -= 1
		return
	_ball_sound("roll", -8.0, randf_range(0.95, 1.05))
	var goal_x: float = _bag_target.get(uid, balls[j][1]).x
	# (with many balls in the Bag the places are closer than a ball is wide: the gap that ball keeps is never more than the distance between two places)
	var slot_gap := minf(BAG_PX + 3.0, absf(_bag_slot(1, maxi(2, _bag_order.size())).x - _bag_slot(0, maxi(2, _bag_order.size())).x))
	var others: Array = []
	for k in balls.size():
		if k != j:
			others.append(balls[k][0])
	if _stock_row != null:  # (the balls of another launch that are still rolling count too: a refund sends its balls one at a time)
		for c in _stock_row.get_children():
			if c is ElementIcon and c != ic and c.has_meta("rolling") and not others.has(c):
				others.append(c)
	var tw := ic.create_tween()
	tw.tween_method(func(u: float) -> void:
		if is_instance_valid(ic):
			var e := _roll_ease(u)  # (the same curve for the slide and the spin, so the ball really rolls instead of skidding)
			ic.position.x = _no_overlap(ic, lerpf(from_x, goal_x, e), others, slot_gap)
			ic.rotation = -TAU * turns * e, 0.0, 1.0, t)
	await tw.finished
	_launching -= 1
	if not is_instance_valid(ic) or ic.is_queued_for_deletion():
		return
	ic.rotation = 0.0
	ic.remove_meta("rolling")
	ic.mouse_filter = Control.MOUSE_FILTER_STOP
	ic.position = _bag_target.get(uid, ic.position)
	_ball_sound("hit", -3.0 if j > 0 else -8.0, randf_range(0.95, 1.08))
	if j > 0:  # the ball it hit rocks a little
		var prev = balls[j - 1][0]  # (untyped: the ball it hit may have been freed meanwhile, e.g. stolen out of the bag, and a typed variable cannot hold that)
		if is_instance_valid(prev) and not prev.has_meta("rolling"):
			var rock: Tween = prev.create_tween()
			rock.tween_property(prev, "position:x", prev.position.x - 4.0, 0.05).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
			rock.tween_property(prev, "position:x", prev.position.x, 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	if _launching == 0:
		_resort_bag()  # (Puppet Stage: the shooting is over, now the balls swap into their types)


## ---- Puppet Stage: the slot machine (see SlotMachine and docs/new_machine_logic.md) -----------------------------------------------------------------
## A spawn (the start of a turn, the first hand of a fight): the lever is pulled, the three reels spin for 2 s and stop on the Essence that spawn, each of them drops into
## the bottom funnel, goes down the glass tube and comes up out of the port in the Bag strip, and rolls to its place. A bonus Essence (a spell, a bottle, an artifact,
## a refund, the ones of a spawn beyond the third) does not touch the reels: it flies from its source into the top funnel, falls through the machine, and takes the same
## way out. An Essence that a spell gives for NEXT turn materializes in the tray on top of the machine and lies there; at the next spawn it goes down with the others.
const SLOT_TUBE_SPEED := 470.0  # px/s of an Essence inside the machine and the tube
const NU_TUBE_SPEED := 620.0  # (New UI: the Essence run on along the Bag tray at this speed, see _nu_roll)
const SLOT_BALL_SCALE := 0.92  # an Essence is drawn this big inside the glass


## The reels at rest show next turn's draw (in the Bag's order, three at most): what is about to spawn.
func _sync_reels() -> void:
	return  # (the faces on the reels are pictures of what was rolled at the lever: a bonus Essence never changes them)
	if _machine == null or _machine.busy or not _reels_armed:
		return
	var ranked: Array = []
	for i in fight.player.next_draw.size():
		var d: Dictionary = fight.player.next_draw[i]
		ranked.append([maxi(0, "FWA".find(d.el) + 1), i, d])
	ranked.sort_custom(func(a, b): return a[0] < b[0] or (a[0] == b[0] and a[1] < b[1]))
	var els: Array = []
	for r in ranked:
		if els.size() < 3:
			els.append(r[2].el)
	if els == _reel_shown:
		return
	_reel_shown = els.duplicate()
	_machine.set_faces(els, true)


func _path_point(pts: Array, at: float) -> Vector2:
	var acc := 0.0
	for i in pts.size() - 1:
		var seg: float = pts[i].distance_to(pts[i + 1])
		if at <= acc + seg or i == pts.size() - 2:
			return pts[i].lerp(pts[i + 1], clampf((at - acc) / maxf(seg, 0.001), 0.0, 1.0))
		acc += seg
	return pts[pts.size() - 1]


## An Essence's trip to the Bag, set up as one tween on the icon: it starts `delay` seconds from now, mode "reel" (it takes over from the Essence dropping out of a reel: it
## starts in the bottom funnel), "from" (it flies from `from_local` into the top funnel first), "tray" (it lay in the tray at `from_local` and slips into the funnel)
## or "pop" (it pops up over the top funnel), then it falls through the machine,
## goes down the tube, shrinks into the cap at the Bag strip's edge and comes up out of the port. Returns when it is up (seconds from now).
## New UI: how long an Essence's trip takes from the start of `mode` until it has come up out of the circle (see _slot_route).
func _slot_route_time(mode: String, from_local: Vector2) -> float:
	var m := _machine
	var pts: Array = [from_local, m.funnel_bottom_in()] if mode == "reel" else [m.funnel_top_mouth(), m.funnel_bottom_in()]
	if mode == "reel":
		pts = [from_local, Vector2(from_local.x, NewUiLayout.TUBE_ROW_Y)]
	pts.append_array(m.tube_path())
	var total := 0.0
	for i in pts.size() - 1:
		total += pts[i].distance_to(pts[i + 1])
	var fly: float = {"from": 0.5, "pop": 0.28, "tray": 0.2}.get(mode, 0.0)
	return fly + total / NU_TUBE_SPEED


func _slot_route(ic: ElementIcon, delay: float, mode: String, from_local := Vector2.ZERO) -> float:
	var m := _machine
	var half := ic.size / 2.0
	var row_y := PuppetLayout.AXIS_Y - BAG_PX / 2.0
	var pts: Array = [from_local, m.funnel_bottom_in()] if mode == "reel" else [m.funnel_top_mouth(), m.funnel_bottom_in()]
	if _nu_ui and mode == "reel":  # (New UI: straight down from its reel to the tube's row, so the three come to the tube in the order of the reels)
		pts = [from_local, Vector2(from_local.x, NewUiLayout.TUBE_ROW_Y)]
	pts.append_array(m.tube_path())
	var total := 0.0
	for i in pts.size() - 1:
		total += pts[i].distance_to(pts[i + 1])
	var dur := total / (NU_TUBE_SPEED if _nu_ui else SLOT_TUBE_SPEED)
	ic.position = Vector2(m.port_center().x + 400.0, row_y)  # (parked out of the way until its turn: it must not count as a ball in front of the others)
	ic.rotation = 0.0
	ic.modulate.a = 0.0
	ic.scale = Vector2.ONE * SLOT_BALL_SCALE
	var mouth := m.funnel_top_mouth()
	var tw := ic.create_tween()
	tw.tween_interval(delay)
	var fly := 0.0
	if mode == "from":
		fly = 0.5
		tw.tween_callback(func() -> void:
			if is_instance_valid(ic):
				ic.modulate.a = 1.0
				ic.scale = Vector2.ONE * 0.4)
		tw.tween_method(func(u: float) -> void:
			if is_instance_valid(ic):
				var e := u * u * (3.0 - 2.0 * u)
				ic.position = from_local.lerp(mouth, e) + Vector2(0.0, -110.0 * sin(u * PI)) - half
				ic.rotation = -u * TAU * 1.5
				ic.scale = Vector2.ONE * lerpf(0.4, SLOT_BALL_SCALE, minf(1.0, u * 2.0)), 0.0, 1.0, fly)
	elif mode == "pop":
		fly = 0.28
		tw.tween_callback(func() -> void:
			if is_instance_valid(ic):
				ic.modulate.a = 0.0
				ic.scale = Vector2.ONE * 0.3)
		tw.tween_method(func(u: float) -> void:
			if is_instance_valid(ic):
				ic.position = mouth + Vector2(0.0, lerpf(-80.0, 0.0, u * u)) - half
				ic.modulate.a = minf(1.0, u * 4.0)
				ic.scale = Vector2.ONE * lerpf(0.3, SLOT_BALL_SCALE, minf(1.0, u * 2.0)), 0.0, 1.0, fly)
	elif mode == "tray":  # (it lay in the tray at from_local: it slips off into the funnel's mouth)
		fly = 0.2
		tw.tween_callback(func() -> void:
			if is_instance_valid(ic):
				ic.modulate.a = 1.0
				ic.scale = Vector2.ONE * TRAY_SCALE
				ic.position = from_local - half)
		tw.tween_method(func(u: float) -> void:
			if is_instance_valid(ic):
				ic.position = from_local.lerp(mouth, u * u) - half
				ic.scale = Vector2.ONE * lerpf(TRAY_SCALE, SLOT_BALL_SCALE, u), 0.0, 1.0, fly)
	else:  # (mode "reel": it starts hidden behind the cabinet, where its reel is)
		tw.tween_callback(func() -> void:
			if is_instance_valid(ic):
				ic.position = pts[0] - half
				ic.modulate.a = 1.0)
	tw.tween_method(func(u: float) -> void:
		if is_instance_valid(ic):
			ic.position = _path_point(pts, u * total) - half
			ic.rotation = -u * TAU * maxf(1.0, roundf(total / (PI * BAG_PX)))
			ic.scale = Vector2.ONE * SLOT_BALL_SCALE, 0.0, 1.0, dur)
	# out of the tube it keeps rolling, straight into the Bag strip (no hole: one continuous roll), growing to its full size; _roll_ball takes over from there
	var tube_end: Vector2 = pts[pts.size() - 1]
	if _nu_ui:  # (the tube is straight: the Essence runs out of its mouth into the Bag tray, where _nu_roll takes it on at the same speed)
		return delay + fly + dur
	var entry := Vector2(m.port_center().x, row_y + half.y)
	var spin0 := -TAU * maxf(1.0, roundf(total / (PI * BAG_PX)))
	var out_t := maxf(0.05, tube_end.distance_to(entry) / SLOT_TUBE_SPEED)
	tw.tween_method(func(u: float) -> void:
		if is_instance_valid(ic):
			ic.position = tube_end.lerp(entry, u) - half
			ic.rotation = spin0 - u * TAU  # (one whole turn: it ends upright, where the roll along the Bag starts)
			ic.scale = Vector2.ONE * lerpf(SLOT_BALL_SCALE, 1.0, u), 0.0, 1.0, out_t)
	tw.tween_callback(func() -> void:
		if is_instance_valid(ic):
			ic.rotation = 0.0)
	return delay + fly + dur + out_t


## Pull the lever, spin the reels for 2 s and stop them on these Essence (they stay there: next turn they drop out). One sound covers the pull and the return.
func _roll_reels(els: Array) -> void:
	Audio.play("sfx_lever_pull", -2.0)
	_machine.lever_pull()
	await get_tree().create_timer(0.3).timeout
	await _machine.spin(els, 2.0)
	_machine.lever_return()
	_machine.busy = false
	_reel_shown = els.duplicate()
	_reels_armed = true


## Once the balls of a spawn are all in the Bag (`wait` seconds is when the last one comes up out of the port), the machine rolls next turn's draw: the lever is
## pulled, the reels spin for 2 s and stop on the Essence that will spawn next turn.
func _roll_next_on_reels(wait: float) -> void:
	await get_tree().create_timer(wait + 0.4).timeout
	var t0 := Time.get_ticks_msec()
	while _launching > 0 and Time.get_ticks_msec() - t0 < 8000 and is_inside_tree():
		await get_tree().process_frame
	await get_tree().create_timer(0.3).timeout
	if not is_inside_tree() or _machine == null or fight == null or fight.over or _machine.busy or _launching > 0 or Time.get_ticks_msec() < _turn_batch_until:
		return
	var ranked: Array = []
	for i in fight.player.next_draw.size():
		var d: Dictionary = fight.player.next_draw[i]
		ranked.append([maxi(0, "FWA".find(d.el) + 1), i, d])
	ranked.sort_custom(func(a, b): return a[0] < b[0] or (a[0] == b[0] and a[1] < b[1]))
	var els: Array = []
	for r in ranked:
		if els.size() < 3:
			els.append(r[2].el)
	await _roll_reels(els)


## A spell gives Essence for next turn: a comet of light flies from the card to the tray on top of the machine (the top funnel), where it materializes into an
## Essence and lies there. At the next spawn the tray's Essence go down with the others: they drop into the funnel and take the usual way to the Bag (_puppet_launch).
const TRAY_SCALE := 0.72  # an Essence lying in the tray is drawn this big


## The centre of the k-th Essence lying in the tray (local to the Bag strip): side by side over the funnel's mouth, three to a row, the next row on top.
func _tray_center(k: int) -> Vector2:
	var mouth := _machine.funnel_top_mouth()
	var step := BAG_PX * TRAY_SCALE * 0.82
	var row := floori(k / 3.0)
	var col := k % 3
	var x := mouth.x + (col - 1) * step + (step * 0.5 if row % 2 == 1 else 0.0)
	return Vector2(x, mouth.y - BAG_PX * TRAY_SCALE * 0.42 - row * step * 0.8)


## Artifacts that give Essence for next turn: each one shines up briefly, then a ball of light flies from it to the tray
## on top of the machine and materializes there (like a spell's "gain Essence next turn"). Shown once per Essence.
func _stash_artifact_draws(for_turn: int) -> void:
	if not _puppet_strips() or _stock_row == null or _arts == null:
		return
	var by_art := {}
	for d in fight.player.next_draw:
		if d.has("from") and not d.get("shown", false):
			d.shown = true
			if not by_art.has(d.from):
				by_art[d.from] = []
			by_art[d.from].append(d.el)
	for id in by_art:
		_arts.flash(id)
		var at = _arts.chip_center(id)
		if at == null:
			continue
		await _wait(0.25)  # (it shines up first)
		var before := _pending.size()
		_stash_to_machine({"drawn": by_art[id], "eff": {"op": "draw", "n": by_art[id].size(), "when": "next"}}, at)
		for k in range(before, _pending.size()):
			_pending[k].set_meta("for_turn", for_turn)
		await _wait(0.2)


func _stash_to_machine(ev: Dictionary, from: Vector2) -> float:
	var els: Array = ev.get("drawn", [])
	if els.is_empty():
		var el: String = ev.eff.get("el", "random")
		for i in int(ev.eff.get("n", 1)):
			els.append(["F", "W", "A"].pick_random() if el == "random" else el)
	var dests := []
	var base_k := _pending.size()
	for i in els.size():
		var ic := ElementIcon.make(els[i], BAG_PX)
		ic.size = Vector2(BAG_PX, BAG_PX)
		ic.pivot_offset = ic.size / 2.0
		ic.temp = ev.eff.get("temp", false)
		ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
		ic.scale = Vector2.ONE * TRAY_SCALE
		ic.modulate.a = 0.0  # (it shows when its comet lands)
		var c := _tray_center(base_k + i)
		ic.position = c - ic.size / 2.0
		_stock_row.add_child(ic)
		_pending.append(ic)
		dests.append({"body": _stock_row.global_position + c, "row": _stock_row.global_position + c, "el": els[i], "px": BAG_PX * TRAY_SCALE, "ghost": false})  # (no copy on top: the real one shows behind the tray's front wall)
		# (SpellFx._draw_fx: the i-th comet lands 0.13 s after the one before it, 0.6 s after it set off; it materializes there and this Essence takes over)
		var tw := ic.create_tween()
		tw.tween_interval(i * 0.13 + 0.62)
		tw.tween_callback(func() -> void: _ball_sound("hit", -9.0, randf_range(1.05, 1.2)))
		tw.tween_property(ic, "modulate:a", 1.0, 0.25)
	return SpellFx.play(_fx, "draw", ev.eff, from, dests, Color.WHITE, Vector2.ZERO, _shake, _hitstop)


## New balls of the Bag (rolled: [[icon, place, uid]]) come out of the machine. See the block comment above.
## The first hand of a fight: one Essence of each element is in the Bag already when the fight opens; only the rest come out of the machine.
func _puppet_launch(balls: Array) -> void:
	_launching += 1
	_tube_prep = true
	balls.sort_custom(func(a, b): return a[1].x < b[1].x)
	var first_hand := not _spawned_once
	var spawn := Time.get_ticks_msec() < _turn_batch_until or first_hand
	_keep_bag_order = not spawn  # (a spawn: when its balls are all in, the Bag sorts itself once; a bonus / refund: it keeps its order, the new balls stay at the back)
	_turn_batch_until = 0
	_spawned_once = true
	var from_pt := _bonus_from
	_bonus_from = Vector2.INF
	for b in balls:
		var hidden_ic: ElementIcon = b[0]
		hidden_ic.set_meta("rolling", true)
		hidden_ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
		hidden_ic.modulate.a = 0.0
		hidden_ic.position = Vector2(_machine.port_center().x + 400.0, PuppetLayout.AXIS_Y - BAG_PX / 2.0)  # (out of the way)
	# who is who. The first hand: one of each element is already in the Bag ("preset"). At a spawn, a ball whose twin lies in the tray (a spell gave it "for next
	# turn") comes from the tray ("tray"); the first three of the others come out of the reels ("reel"); the rest pop over the top funnel ("extra").
	var n := balls.size()
	var role: Array = []
	role.resize(n)
	role.fill("extra")
	if first_hand:
		for el in ["F", "W", "A"]:
			for j in n:
				if role[j] == "extra" and balls[j][0].el == el:
					role[j] = "preset"
					break
	var twin_of := {}
	if spawn:
		var pool: Array = _pending.filter(func(c): return is_instance_valid(c) and int(c.get_meta("for_turn", fight.turn)) <= fight.turn)  # (not the ones already lying there for the turn after)
		for j in n:
			if role[j] != "extra":
				continue
			for k in pool.size():
				if pool[k].el == balls[j][0].el:
					twin_of[j] = pool[k]
					pool.remove_at(k)
					role[j] = "tray"
					break
	var reel_of := {}  # ball index -> reel
	if spawn:
		var r_i := 0
		for j in n:
			if role[j] == "extra" and r_i < 3:
				role[j] = "reel"
				reel_of[j] = r_i
				r_i += 1
	# The balls come out of the port one after another and cannot pass each other: the first out gets the home furthest left, the next the next one, and so on. The
	# Essence already in the Bag take the first homes; then the reels' balls, then the tray's, then the rest (the order they come out in). Which Essence is which does
	# not change; the ones that swapped homes slide into their types after (_resort_bag).
	var homes: Array = balls.map(func(b): return b[1])
	homes.sort_custom(func(a: Vector2, b: Vector2) -> bool: return a.x < b.x)
	var slots_in_order: Array = []  # the places in _bag_order the batch holds
	var batch_uids: Array = balls.map(func(b): return b[2])
	for k in _bag_order.size():
		if _bag_order[k] in batch_uids:
			slots_in_order.append(k)
	var order: Array = []
	for want in ["preset", "reel", "tray", "extra"]:
		var group: Array = []
		for j in n:
			if role[j] == want:
				group.append(j)
		if want == "reel":
			group.sort_custom(func(a, b): return reel_of[a] < reel_of[b])
		order.append_array(group)
	for k in n:
		var j: int = order[k]
		var uid_j: int = balls[j][2]
		balls[j][1] = homes[k]
		_bag_target[uid_j] = homes[k]
		if is_instance_valid(balls[j][0]):
			(balls[j][0] as Control).set_meta("goal", homes[k])
		if k < slots_in_order.size():
			_bag_order[slots_in_order[k]] = uid_j
	# the first hand's one of each element: in its place at once, no trip through the machine
	for j in n:
		if role[j] == "preset" and is_instance_valid(balls[j][0]):
			var pic: ElementIcon = balls[j][0]
			pic.remove_meta("rolling")
			pic.mouse_filter = Control.MOUSE_FILTER_STOP
			pic.position = balls[j][1]
			pic.rotation = 0.0
			pic.scale = Vector2.ONE
			pic.modulate.a = 1.0
	# the machine is on the HUD: when the HUD is still below the screen (the fight is being set up) it waits
	while (_hud_hidden() or not _machine_ready) and is_inside_tree():
		await get_tree().process_frame
	if not is_inside_tree() or _machine == null:
		_launching -= 1
		_tube_prep = false
		return
	if spawn:
		var finals: Array = []
		for j in order:
			if role[j] == "reel":
				finals.append(balls[j][0].el)
		while _machine.busy and is_inside_tree():  # (the reels are still rolling next turn's draw: wait for them)
			await get_tree().process_frame
		if _reel_shown.is_empty():  # the first hand of a fight: nothing was rolled yet, so the lever is pulled now
			if not finals.is_empty():
				await _roll_reels(finals)
		elif finals != _reel_shown:  # (what spawns is not what the reels showed: they show what really spawns)
			_machine.set_faces(finals, true)
			await get_tree().create_timer(0.25).timeout
		_reel_shown = []
		_reels_armed = false
	var gap := 0.26 if _nu_ui else 0.2  # (New UI: the orbs run one after another, 160 px apart)
	var emerge: Array = []  # seconds from now until each ball comes up out of the port
	emerge.resize(n)
	emerge.fill(0.0)
	var tray_k := 0
	var extra_k := 0
	var n_tray := role.count("tray")
	# New UI: the balls come up out of the circle one after another, `gap` apart whatever way each one took (the next only starts when the one before has rolled away)
	var nu_next := [0.0]
	var pick_delay := func(default_d: float, mode: String, from_local: Vector2) -> float:
		if not _nu_ui:
			return default_d
		var rt := _slot_route_time(mode, from_local)
		var e: float = maxf(nu_next[0], rt)
		nu_next[0] = e + gap
		return e - rt
	for j in order:
		var ic = balls[j][0]  # (untyped: it may have been freed while the reels spun, e.g. the tutorial moved on)
		if not is_instance_valid(ic) or role[j] == "preset":
			continue
		if role[j] == "reel":  # (the real ball falls from behind the cabinet into the bottom funnel; the faces on the reels are only pictures and stay until the next roll)
			var rc: Vector2 = _machine.reel_center(reel_of[j])
			emerge[j] = _slot_route(ic, pick_delay.call(reel_of[j] * gap, "reel", rc), "reel", rc)
		elif role[j] == "tray":  # it goes down with the others: it slips off the tray into the funnel (the real ball takes over from the one lying there)
			var lying = twin_of[j]  # (untyped: it may have been freed meanwhile)
			_pending.erase(lying)
			var at: Vector2 = (lying.position + lying.size / 2.0) if is_instance_valid(lying) else _machine.funnel_top_mouth()
			var d: float = pick_delay.call(0.45 + tray_k * gap, "tray", at)
			tray_k += 1
			get_tree().create_timer(d).timeout.connect(func() -> void:
				if is_instance_valid(lying):
					lying.queue_free())
			emerge[j] = _slot_route(ic, d, "tray", at)
		else:
			var d0 := (0.45 + (n_tray + extra_k) * gap) if spawn else extra_k * gap
			extra_k += 1
			if from_pt != Vector2.INF and not spawn:
				var fl := from_pt - _stock_row.global_position
				emerge[j] = _slot_route(ic, pick_delay.call(d0, "from", fl), "from", fl)
			else:
				emerge[j] = _slot_route(ic, pick_delay.call(d0, "pop", Vector2.ZERO), "pop")
	var port_x: float = _machine.port_center().x - BAG_PX / 2.0
	var last_emerge := 0.0
	var rollers: Array = []  # (the balls that roll in; the ones already in the Bag don't)
	for j in order:
		if role[j] != "preset":
			rollers.append(balls[j])
	var nu_b := _nu_brake(port_x, rollers.map(func(b): return b[1])) if _nu_ui and not rollers.is_empty() else 0.0
	for r in rollers.size():
		var j: int = balls.find(rollers[r])
		last_emerge = maxf(last_emerge, float(emerge[j]))
		if _nu_ui:
			last_emerge = maxf(last_emerge, _nu_roll(rollers[r][0], rollers[r][1], float(emerge[j]), port_x, nu_b, NU_TUBE_SPEED))
			continue
		var dx := port_x - float(rollers[r][1].x)
		_roll_ball(rollers, r, port_x, 0.25 + maxf(0.0, dx) / 820.0, float(emerge[j]))
	_tube_hold_until = Time.get_ticks_msec() + int((last_emerge + 1.0) * 1000.0)  # the reels show the next draw again a second after the last ball is out
	_tube_prep = false
	_machine.busy = false  # (the faces of the reels are on their way out)
	_launching -= 1
	_sync_tube()  # (it waits for _tube_hold_until)
	if spawn:
		_roll_next_on_reels(last_emerge)  # (as soon as these balls are in the Bag, the lever is pulled for the next turn's draw)
	if rollers.is_empty():
		_resort_bag()  # (nothing rolled: nothing else will sort the Bag)


## ---- New UI: the Essence of the machine run straight out of the tube into the Bag tray ----------------------------------------------------------------------------
## The machine is the Puppet one (see SlotMachine, with `straight`): its Essence fall to the tube's row and run straight left through the tube; out of its mouth they go on along
## the Bag tray at the same speed and slow to a stop at their places (_nu_roll). The Bag is not re-sorted: new orbs stay after the ones that are there.

const NU_ROLL_SPEED := 820.0  # px/s of a rolling orb
const NU_ROLL_ACCEL := 0.18  # seconds it takes to get up to speed
const NU_ROLL_BRAKE := 150.0  # px: over the last stretch it slows smoothly to a stop


## How long the last stretch of a launch's rolls is (the same for all of them, see _nu_roll): never more than 1.6 times the shortest way.
func _nu_brake(from_x: float, homes: Array) -> float:
	var shortest := 99999.0
	for h in homes:
		shortest = minf(shortest, from_x - float(h.x))
	return clampf(shortest * 1.6, 24.0, NU_ROLL_BRAKE)


## One orb rolls from `from_x` to `home` (the places along the Bag strip, so only x changes), `delay` seconds from now. Its speed is a smooth start, a steady run and a
## smooth stop, and it spins by the distance it covers (whole turns, so it lies upright). The orbs of a launch all follow the same rule: x = home + soft(r), where r shrinks
## at the same pace for all of them and soft() never changes faster than r, so an orb that comes later can never get closer to the one before it than the time between them
## allows, and the Bag's places are further apart than an orb is wide. `b` = the length of the smooth stop (the same for the whole launch, see _nu_brake).
## Returns when it is in place (seconds from now).
func _nu_roll(ic: ElementIcon, home: Vector2, delay: float, from_x: float, b: float, v0 := 0.0) -> float:
	var r0 := from_x - home.x
	_launching += 1
	var tw := ic.create_tween()
	tw.tween_interval(delay)
	var dur := 0.0
	if r0 > 1.0:
		var v := v0 if v0 > 0.0 else NU_ROLL_SPEED  # (v0: it comes in already running at that speed, no start-up)
		var a := 0.0 if v0 > 0.0 else NU_ROLL_ACCEL
		var big := r0 + b / 2.0  # (where the "head" starts: soft(big) = r0, so the orb starts exactly where it stands)
		dur = big / v if a == 0.0 else ((a / 2.0 + big / v) if big >= v * a / 2.0 else sqrt(2.0 * a * big / v))
		var turns := roundf(r0 / (PI * BAG_PX))
		tw.tween_callback(func() -> void:
			if is_instance_valid(ic):
				ic.position.x = from_x
				_ball_sound("roll", -8.0, randf_range(0.95, 1.05)))
		tw.tween_method(func(u: float) -> void:
			if not is_instance_valid(ic):
				return
			var s := v * u if a == 0.0 else (v * u * u / (2.0 * a) if u < a else v * (u - a / 2.0))
			var r := maxf(0.0, big - s)
			var soft := r * r / (2.0 * b) if r < b else r - b / 2.0
			ic.position.x = home.x + soft
			ic.rotation = -TAU * turns * clampf(1.0 - soft / r0, 0.0, 1.0), 0.0, dur, dur)
	tw.tween_callback(func() -> void:
		_launching -= 1
		if is_instance_valid(ic):
			ic.rotation = 0.0
			ic.position = home
			ic.remove_meta("rolling")
			ic.mouse_filter = Control.MOUSE_FILTER_STOP
			_ball_sound("hit", -6.0, randf_range(0.95, 1.08))
		if _launching == 0:
			_resort_bag())
	return delay + dur


## The spell row. With many spells the cards shrink to fit the screen; hovering one brings it back to full size.
## The lower block (spell row, chant, bag, Keeper, log) is laid out from the top; once the panels have their real sizes,
## slide the whole block down together (keeping the gaps between its parts) until the bag sits BOTTOM_MARGIN above the
## screen's bottom edge.
const BOTTOM_MARGIN := 20.0


func _fit_bottom() -> void:
	if _puppet_strips():  # (the Puppet HUD is placed exactly as the PDF has it: nothing slides)
		_place_spell_row()
		return
	# (the panels are first laid out at their design spots and slid down once their real heights are known: keep them
	# invisible until then, or the first frame shows them too high)
	var movers := [_spell_row, _chant_panel, _bag_panel, _player_panel, _log]
	for n in movers:
		if n != null:
			n.modulate.a = 0.0
	await get_tree().process_frame
	if not is_instance_valid(_bag_panel):
		return
	var dy := (size.y if size.y > 0.0 else 1080.0) - BOTTOM_MARGIN - (_bag_panel.position.y + _bag_panel.size.y)
	var puppet := _puppet_strips()
	if puppet:  # (the Puppet strips are low: the Keeper's panel is the tallest part of the block, it sets the limit)
		dy = minf(dy, (size.y if size.y > 0.0 else 1080.0) - BOTTOM_MARGIN - (_player_panel.position.y + _player_panel.size.y))
	for n in movers:
		if n != null:
			if not (puppet and n == _spell_row):
				n.position.y += dy
			n.modulate.a = 1.0
	if _stage != null and puppet:
		_place_spell_row()  # the stage's front face reaches down to the top of the Chant strip
	_log.size.y = maxf(60.0, 1016.0 - _log.position.y)  # stop above the Menu button


const ROW_WIDTH := 1860.0
const SPELL_ROW_LEFT := 20.0  # (Puppet: how far left a long spell row may reach)


func _build_spells() -> void:
	for c in _spell_row.get_children():  # (taken out at once: while the old holders still stand beside the new ones the row's minimum width doubles, the row grows and stays
		_spell_row.remove_child(c)  # wider, and its centred cards slide to the right: that was the bug after the second fight)
		c.queue_free()
	_spell_row.size.x = 1920.0
	_spell_row.position.x = 0.0
	_spell_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_cards.clear()
	var n := fight.shown_spells().size()
	var gap := 10.0
	var row_w := ROW_WIDTH
	var full_w := n * SpellCard.W + gap * maxf(0, n - 1)
	if _puppet_strips():  # (Puppet: the row is centred, and its right end stops at the Chant strip's: the cards must not cover the lottery machine)
		row_w = minf(row_w, 2.0 * (_bag_at().x + PuppetLayout.FRAME_CHANT.x - 960.0))
	var fit := minf(1.0, (row_w - gap * maxf(0, n - 1)) / maxf(1.0, n * SpellCard.W))
	if _nu_ui:  # (New UI: the cards are the size the page draws them, 8.58 apart, around the middle of its row of eight; more than eight would shrink to fit)
		gap = NewUiLayout.SPELL_GAP
		fit = minf(NewUiLayout.SPELL_FIT, (ROW_WIDTH - gap * maxf(0, n - 1)) / maxf(1.0, n * SpellCard.W))
		_spell_row.position.x = NewUiLayout.SPELL_CENTER_X - 960.0
	_spell_row.add_theme_constant_override("separation", roundi(gap))
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
	_place_spell_row()


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


## A Handyman hand that has just been brought down but is not yet marked knocked out (that happens a moment later, in Fight._handyman_step):
## its view must not go away (and be built again, reaching out, a moment after).
var _rally_hold := false  # the Handyman's last stand has begun but he has not pulled his hands up yet: they stay on the floor
const RALLY_QUAKE := 2.4  # seconds his body shakes before the hands are pulled up
const RALLY_GAP := 0.6  # seconds between one hand being pulled up and the next


## The Handyman's last stand: every hand lies on the floor. He turns to the crying face and shakes his whole body hard, then his own
## Essence steps out and he sucks the six hands up to his shoulders.
func _hm_rally_scene() -> void:
	var hands := func() -> Array:
		return _views.values().filter(func(v): return is_instance_valid(v) and is_instance_valid(v.creature) and v.creature.has_rig())
	if _hm_stage == null or not is_instance_valid(_hm_stage):
		_sync_views()
		_refresh_all()
		return
	_rally_hold = true
	for v in hands.call():
		v.creature.drop_hold = true  # (the fight state already has them up: the arms wait on the floor)
	_quake_body(RALLY_QUAKE)
	_refresh_all()
	await _wait(1.0)
	_sync_views()  # (his body steps out, with its one Essence: the shake goes on)
	_refresh_all()
	_quake_body(RALLY_QUAKE - 1.0)
	await _wait(RALLY_QUAKE - 1.0)
	_rally_hold = false
	for v in hands.call():  # (he pulls the hands up one after another)
		v.creature.drop_hold = false
		_refresh_all()
		Audio.play("enemy_spawn")
		await _wait(RALLY_GAP)
	await _wait(1.0)


## His body shakes hard for `t` seconds, crying: the plain picture of it and, if it already stands there as an enemy, its view.
func _quake_body(t: float) -> void:
	if _hm_stage != null and is_instance_valid(_hm_stage):
		_hm_stage.rally_quake(t)
	for e in _views:
		var v: EnemyView = _views[e]
		if e.id == "handyman" and is_instance_valid(v) and is_instance_valid(v.creature):
			v.creature.sad_forever = true
			v.creature.quake = t


func _hand_going_down(e: EnemyState) -> bool:
	return e.has_passive("hand") and fight != null and not fight.hm.is_empty() and int(fight.hm.phase) < 2 and fight.enemies.has(e)


var _hm_hold: Array = []  # the Handyman's new hands, kept off the stage while he speaks (ids)


func _sync_views() -> void:
	var live := fight.enemies.filter(func(e): return not e.is_dead() or e.knocked or _hand_going_down(e) or e.has_passive("armadillo") or e.has_meta("yielded") or (e.has_passive("veil_falls") and e.phase == 1))  # (the Armadillo doesn't break: his ending plays; the Veiled Eyes do not break either: the veil falls and the same puppet unfolds)  # (a knocked-out hand stays in view)
	var hm := not fight.hm.is_empty() and HandymanStage.available()  # (the Handyman fight with its art: hands on the body's shoulders)
	var same := live.size() == _views.size() and live.all(func(e): return _views.has(e))
	if same:
		if not hm:
			for i in live.size():
				_enemy_row.move_child(_views[live[i]], i)
		return
	for e in _views:  # (Puppet Stage: a puppet that was defeated breaks into pieces)
		var old: EnemyView = _views[e]
		if e.is_dead() and not e.knocked and not _hand_going_down(e) and is_instance_valid(old) and is_instance_valid(old.creature):
			if old.creature.has_rig():
				_shatter_arm(old.creature)
			else:
				PuppetShatter.spawn(self, old.creature)
	var had := _views.keys()
	var drops := {}  # hand -> how far down on the floor its arm was (the view is rebuilt, the fall goes on from there)
	for e in _views:
		var ov: EnemyView = _views[e]
		if is_instance_valid(ov) and is_instance_valid(ov.creature) and ov.creature.has_rig():
			drops[e] = ov.creature._drop_t
	if hm:
		if _hm_stage == null or not is_instance_valid(_hm_stage):
			for c in _enemy_row.get_children():
				_enemy_row.remove_child(c)
				c.queue_free()
			_hm_stage = HandymanStage.new()
			_hm_stage.setup()
			_enemy_row.add_child(_hm_stage)
		for c in _hm_stage.get_children():
			if c is EnemyView:
				_hm_stage.remove_child(c)
				c.queue_free()
		_hm_stage._ghosts.clear()
	else:
		for c in _enemy_row.get_children():
			_enemy_row.remove_child(c)
			c.queue_free()
	_views.clear()
	var body_out := false
	for e in live:
		var v := EnemyView.new()
		v.setup(e, fight)
		v.clicked.connect(_on_enemy_clicked)
		v.hp_clicked.connect(_on_hp_clicked)
		if not hm:
			_enemy_row.add_child(v)
		elif e.id == "handyman":
			_hm_stage.add_body(v)
			body_out = true
		elif HandymanRig.ARMS.has(e.id):
			_hm_stage.add_hand(e, v, not (e in had), float(drops.get(e, -1.0)))
			v.creature.drop_hold = _rally_hold
		else:  # (Test mode can put any enemy beside the Handyman: only his own hands hang on his shoulders, the others stand in the row)
			_enemy_row.add_child(v)
		_views[e] = v
		if e == _spider_away:
			_hold_spider_up(v)
	if hm:
		_hm_stage.set_real(body_out or fight.enemies.any(func(e): return e.id == "handyman" and e.is_dead()))  # (he is down for good: his plain picture must not stand there again after he has shattered)
		_hm_stage.sync_ghosts(live.map(func(e): return e.id), int(fight.hm.phase), fight)
	else:
		_space_enemy_row()


## The gap between the enemies: as wide as the stage allows (up to ENEMY_GAP_MAX), so an intent bubble (it sits beside
## its enemy) never lands on its neighbour's model or cards (the Wizard's floating spells); 20 px when the row is full.
const ENEMY_GAP_MAX := 150.0


func _space_enemy_row() -> void:
	var views := _enemy_row.get_children().filter(func(c): return c is EnemyView)
	if views.size() < 2:
		return
	var total := 0.0
	for v in views:
		total += (v as Control).custom_minimum_size.x
	var gap := clampf((1840.0 - total) / float(views.size() - 1), 20.0, ENEMY_GAP_MAX)
	_enemy_row.add_theme_constant_override("separation", int(gap))


func _chant_string() -> String:
	var s := ""
	for i in chant_idx:
		s += fight.player.stock[i].el
	return s


## Puppet Stage: the heart + "HP 28 / 28" and the shield + its amount stand to the LEFT of the HP tray, their right edges against it.
## Which Essence the pointer is over, for the wooden arrow pointer: "bag" (one that lies in the Bag), "chant" (one in the chant), or "".
func cursor_zone(p: Vector2) -> String:
	if phase != "build" or busy:
		return ""
	for uid in _bag_icons:
		var ic: Control = _bag_icons[uid]
		if is_instance_valid(ic) and ic.is_visible_in_tree() and ic.modulate.a > 0.5 and ic.get_global_rect().grow(2.0).has_point(p):
			return "bag"
	if _chant_row != null:
		for slot in _chant_row.get_children():
			if slot is Panel and slot.get_child_count() > 0 and slot.get_global_rect().has_point(p):
				return "chant"
	return ""


func _place_hp_texts() -> void:
	if not _puppet_hud or _heart == null:
		return
	_hp_label.size = PuppetTopHud.RING_TEXT  # (in the ring: see _fit_hud_frames)


func _refresh_all() -> void:
	var p := fight.player
	_set_info(("Act %d · Floor %d" % [run.act, run.floor_no()]) if map_mode else ("Act %d · Floor %d
Turn %d" % [run.act, run.floor_no(), fight.turn]))  # (two lines on the sign)
	_hp_bar.set_values(p.hp, p.max_hp, p.shield + p.lasting)
	if _danger:
		_danger.target = DangerVignette.strength(p.hp, p.max_hp)
	_hp_label.text = ("%d/%d" if _puppet_hud else "HP %d / %d") % [maxf(0, p.hp), p.max_hp]
	if _puppet_hud:
		# the ring of the bar holds HP and Shield (blue stripes on the bar are Shield and Lasting together); "Lasting N" stands under the bar
		var total: float = p.shield + p.lasting
		_shield_label.text = "%d" % total
		_shield_box.visible = total > 0.0
		_lasting_label.text = "Lasting %d" % p.lasting
		_lasting_label.visible = p.lasting > 0.0
	else:
		# Shield isn't a status badge: it's the blue glass on the HP bar, and its amount goes beside your HP (its own small badge)
		var has_pic := _shield_box.get_child_count() > 1
		var shield_text := ""
		if p.shield > 0.0:
			shield_text = ("%d" if has_pic else "Shield %d") % p.shield
		if p.lasting > 0.0:
			shield_text += ("  Lasting %d" % p.lasting) if shield_text != "" else "Lasting %d" % p.lasting
		_shield_label.text = shield_text
		_shield_box.visible = shield_text != ""
	_place_hp_texts()
	_refresh_statuses()
	_refresh_bottles()
	_fit_hud_frames()
	_refresh_coin()
	_arts.update_charges(p)
	if not _circus_strips():
		for c in _next_row.get_children():
			c.queue_free()
		for d in p.next_draw:
			var ic := ElementIcon.make(d.el, 44)
			ic.temp = d.temp
			_next_row.add_child(ic)
	_refresh_chant()
	_refresh_stock()
	_sync_tube()  # (after the stock: at a new turn the stock takes the waiting balls out first)
	var chant := _chant_string()
	var pv := {}
	if phase == "build" and chant != "":
		pv = fight.preview(chant)
	elif phase == "spells" and _step_pos < 0 and not _released:
		pv = fight.preview(fight.chant_string(), false)
	if phase == "build" and not pv.has("invoke"):
		# nothing chanted yet: the Invoker still shows which of his spells he'd cast (the closest)
		var inv := {}
		for e in fight.alive():
			if e.def.get("invokes", false):
				inv[e] = fight.invoke_picks(e, "")
		pv["invoke"] = inv
	for e in _views:
		var v: EnemyView = _views[e]
		var idx := fight.enemies.find(e)
		v.targetable = aiming and idx in aim_cands
		v.targeted = aiming and aim_cands.size() > 0 and idx == aim_cands[aim_i]
		v.refresh(pv)
	for card in _cards:
		var s: Dictionary = card.spell
		var dl := fight.durability_left(s)
		card.durability_left = maxi(0, dl) if dl >= 0 or Fight.base_durability(s) > 0 else -1  # (the card shows what's left)
		card.durability_max = fight.durability_max(s)  # (out of how much: "Durability 2/3")
		card.state = ""
		card.state_text = ""
		card.ignited = p.ignited.has(s.id)
		card.cracks = 3 if fight.broken.has(s.id) else fight.hammer_hits.get(s.id, 0)
		if UiSkin.is_puppet() and card.cracks > 0 and card.get_meta("split_level", 0) != card.cracks:
			_split_card(card, card.cracks, false)
		if phase == "spells" and fight.used.has(s.id) and fight.charges.get(s.id, 0) <= 0 and not p.used_powers.has(s.id):
			card.state = "spent"  # cast this turn: dimmed until the turn is over
		if fight.broken.has(s.id):
			card.state = "broken"
			card.state_text = "BROKEN"
		elif p.used_powers.has(s.id):
			card.state = "used"
			card.state_text = "Gone for this fight" if not s.get("power", false) else "Power in effect"
		elif p.cooldowns.has(s.id) and p.cooldowns[s.id] > 0 and not fight.charges.has(s.id):
			# (the turn after it's cast counts as 1; the turn it's cast in shows the full wait)
			var wait: int = p.cooldowns[s.id] - (1 if fight.used.has(s.id) else 0)
			card.state = "cooldown"
			card.state_text = "COOLDOWN\n%d turn%s" % [maxi(1, wait), "" if maxi(1, wait) == 1 else "s"]
		elif p.silenced.has(s.id):
			card.state = "silenced"
			card.state_text = "SILENCED\n%d turn%s" % [p.silenced[s.id], "" if p.silenced[s.id] == 1 else "s"]
		elif p.locks.has(s.id):
			card.state = "locked"
			card.lock_pattern = p.locks[s.id]
		card.fires = pv.get("spells", {}).get(s.id, 0) if phase == "build" else 0
		card.charges = fight.charges.get(s.id, 0) if phase == "spells" else 0
		if phase != "spells" and fight.stored.has(s.id) and fight.usable_spells().has(s):
			card.charges = 1  # stored: it always looks awake (wobbling, shining), even between turns; cast it after a Chant
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
	# one main button: Chant while you build, then Release once the chant is spoken
	_clear_btn.visible = phase == "build"
	_end_btn.visible = phase == "build"
	_end_btn.disabled = busy
	_clear_btn.text = "Clear" if _puppet_strips() else UiTheme.hk("Clear", "⌫")  # (the Puppet buttons are small: no "(key)")
	_end_btn.text = "Pass" if _puppet_strips() else UiTheme.hk("Pass", "E")
	if phase == "build":
		_cast_btn.text = "Chant" if _puppet_strips() else UiTheme.hk("Chant", "Enter")
		_cast_btn.disabled = busy or chant_idx.is_empty()
	else:
		_cast_btn.text = "Release" if _puppet_strips() else UiTheme.hk("Release", "E")
		_cast_btn.disabled = busy or aiming or move_view != null or pick_view != null or chant_mode != ""
	for b in _test_btns:
		b.disabled = busy or _auto_busy or phase != "build" or aiming or move_view != null or pick_view != null or chant_mode != "" or fight.over
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
	if _puppet_strips():
		note = ""  # (Puppet Stage: no plain count; only what needs saying: a Toll, the chant is spoken, Hypnotized)
	if p.toll > 0:
		note = "%d / %d Essence (Toll)" % [chant_idx.size(), slots]
	if phase == "spells":
		note = "Chanted (%d). It is Released when your spells are done." % shown.size()
	if p.confuse_turns > 0 and phase == "build":
		note += ("" if note == "" else "   ·   ") + "HYPNOTIZED: you can't see what the enemies intend"
	_chant_note.text = note
	_chant_note.tooltip_text = note


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
		if i in chant_idx or p.stock[i].uid == held_uid or _cast_uids.has(p.stock[i].uid):
			continue
		shown.append(i)
		live[p.stock[i].uid] = true
	for uid in _bag_icons.keys():
		if not live.has(uid):
			_bag_icons[uid].queue_free()
			_bag_icons.erase(uid)
			_bag_target.erase(uid)
	var circus := _circus_strips()
	var per_row := maxi(1, int((BAG_W + BAG_GAP) / (BAG_PX + BAG_GAP)))
	var rows := maxi(1, ceili(float(shown.size()) / per_row))
	if not circus:
		_stock_row.custom_minimum_size.y = rows * (BAG_PX + BAG_GAP) - BAG_GAP
	var rolled: Array = []  # Cirus: the Essence that are new this time and roll out of the tube
	var arrange: Array = shown.map(func(i): return p.stock[i].uid)  # (left to right)
	if _puppet_strips():
		var newcomers := arrange.filter(func(u): return not _bag_icons.has(u) and not _bag_seen.has(u) and not _flying.has(u))
		if not newcomers.is_empty() or _launching > 0 or _tube_prep or _resort_wait or _keep_bag_order:
			# while balls are being fired the ones already there keep their places and the new ones stack after them (they swap into
			# their types only when the shooting is over: _resort_bag)
			var keep := _bag_order.filter(func(u): return arrange.has(u))
			arrange = keep + arrange.filter(func(u): return not keep.has(u))
		_bag_order = arrange
	var swapped := false
	var delay := _bag_delay
	_bag_delay = 0.0
	for k in shown.size():
		var s: Dictionary = p.stock[shown[k]]
		var uid: int = s.uid
		var target := _bag_slot(arrange.find(uid) if _puppet_strips() else k, shown.size()) if circus else Vector2((k % per_row) * (BAG_PX + BAG_GAP), (k / per_row) * (BAG_PX + BAG_GAP))
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
		if not ic.has_meta("rolling"):
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
			var brand_new := not _bag_seen.has(uid)
			if not _flying.has(uid):
				if circus and brand_new and _direct_in > 0 and Time.get_ticks_msec() < _direct_until:
					_direct_in -= 1  # (a stolen Essence: it rests in its place, unseen until the one in the air has landed)
					ic.modulate.a = 1.0 if _direct_landed else 0.0
					if not _direct_landed:
						_direct_wait.append(ic)
				elif circus and brand_new:
					ic.modulate.a = 0.0
					ic.set_meta("rolling", true)  # (_tube_launch takes it from here)
					rolled.append([ic, target, uid])
				else:
					ic.scale = Vector2(0.3, 0.3)
					ic.create_tween().tween_property(ic, "scale", Vector2.ONE, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			_bag_seen[uid] = true
			ic.set_meta("goal", target)
		elif ic.get_meta("goal", Vector2(-1, -1)) != target:
			ic.set_meta("goal", target)
			if ic.has_meta("rolling"):
				continue  # (it is on its way: _roll_ball puts it on its final spot)
			if ic.has_meta("slide"):
				var old: Tween = ic.get_meta("slide")
				if old != null and old.is_valid():
					old.kill()
			var tw := ic.create_tween()
			if delay > 0.0:
				tw.tween_interval(delay)
			if _resort and absf(ic.position.x - target.x) > 1.0:  # (swapping into its type: up, across, down)
				swapped = true
				tw.tween_property(ic, "position", Vector2(ic.position.x, target.y - 12.0), 0.1).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
				tw.tween_property(ic, "position", Vector2(target.x, target.y - 12.0), BAG_MOVE).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
				tw.tween_property(ic, "position", target, 0.1).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
			else:
				tw.tween_property(ic, "position", target, BAG_MOVE).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
			ic.set_meta("slide", tw)
	if swapped:
		_ball_sound("swap", -3.0)
	if not rolled.is_empty():
		_tube_launch(rolled)


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
const CHANT_RINGS_PUPPET := 10  # (the Puppet Stage strip has room for ten)
const CHANT_W := 700.0  # room for the chant: a longer chant squeezes its Essence together, even overlapping
const CHANT_W_CIRCUS := 540.0  # (the Cirus strip puts the buttons on the same row)


## How many empty rings to show: 8, or fewer under a Toll (its cap).
func _chant_rings() -> int:
	return mini(CHANT_RINGS_PUPPET if _puppet_strips() else CHANT_RINGS, fight.player.chant_slots())


## [orb size, gap between orbs] for a chant of `count` Essence. The gap goes negative (orbs overlap) when the
## chant is too long to fit.
func _chant_layout(count := -1) -> Vector2:
	if count < 0:
		count = chant_idx.size() if phase == "build" else fight.chant.size()
	var n := maxi(_chant_rings(), count)
	var px := 58.0 if n <= 10 else 50.0
	if _puppet_strips():
		px = PUPPET_RING_PX if n <= 10 else 46.0
		var pstep := minf(PuppetLayout.RING_STEP, (PuppetLayout.RING_STEP * 9.0 + PUPPET_RING_PX - px) / maxf(1.0, n - 1))
		return Vector2(px, pstep - px)
	var step := minf(px + 6.0, ((CHANT_W_CIRCUS if _circus_strips() else CHANT_W) - px) / maxf(1.0, n - 1))
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
		var gone: bool = card.state in ["silenced", "cooldown", "used"] or fight.broken.has(sp.id)  # (silenced etc.: as if it weren't there)
		if phase == "build" and c != "" and not sp.has("patterns") and not gone:
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
	SpellCard.hover_off = false  # (a steal may have been cut short)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE  # never leave the pointer hidden
	Engine.time_scale = 1.0  # never leave the game frozen by a hit-stop
	if _counted:
		_counted = false
		_puppet_live = maxi(0, _puppet_live - 1)
		if _puppet_live == 0:
			AmberCounter.off_in_fight = false
			if is_inside_tree():
				for n in get_tree().get_nodes_in_group("amber_counter"):  # (hidden during the fight)
					n.visible = true


func _input(ev: InputEvent) -> void:
	# a selected spell (its arrow out, or the crosshair / hand / brush over the enemies) goes back on right-click or Esc. Caught here, before the cards and
	# enemies under the pointer can swallow the click (and before a right-click pins a tooltip), so it works wherever the pointer is.
	if (aiming and aim_cancellable) or (_picking_any and _picking_any_cancellable):
		var back: bool = (ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_RIGHT) or (ev is InputEventKey and ev.pressed and not ev.echo and ev.keycode == KEY_ESCAPE)
		if back and _pause_overlay == null:
			_cancel()
			get_viewport().set_input_as_handled()
			return
	# steal: letting go of the Essence you're dragging
	if not _steal_drag.is_empty() and ev is InputEventMouseButton and ev.button_index == MOUSE_BUTTON_LEFT and not ev.pressed:
		_end_steal_drag(ev.global_position)
		return
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
	# 5 clicks in 3 seconds without the game moving on: the player is probably lost (the tutorial only: a normal fight has
	# no help popup)
	if help_override.is_valid() and _clicks.size() >= 5 and now - _last_help > 7.0:
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
		return "Rearranging %s: grab one of its Essence and drag it to another spot in its row. Right-click skips." % move_view.enemy.name
	if chant_mode == "insert":
		return "Place the new Essence: it's the glowing one in your chant. Drag it to where it should go (or Left / Right, then Enter)."
	if chant_mode == "arrange":
		return "Self-Rearrange: every Essence of your chant is glowing. Drag one to another spot to make new patterns; right-click keeps the chant as it is."
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
	var paper := UiSkin.box("panel_paper_frame", [46, 46, 46, 46] if UiSkin.is_puppet() else [24, 24, 24, 24], [36, 28, 34, 34] if UiSkin.is_puppet() else [24, 14, 22, 22])
	p.add_theme_stylebox_override("panel", paper if paper != null else sb)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.z_index = 99
	p.position = Vector2(24, 112)
	p.custom_minimum_size = Vector2(440, 0)
	var slide := _puppet_strips()  # (Puppet Stage: it slides in from the right edge of the screen, just under the Leaves' frame, and slides back out)
	var shown_x := 1920.0 - 24.0 - 440.0
	var hidden_x := 1920.0 + 40.0
	if slide:
		p.position = Vector2(hidden_x, 170.0)
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
	if slide:
		shown_x = 1920.0 - maxf(440.0, p.get_combined_minimum_size().x) + 6.0  # (flush with the right edge: the wooden rim hugs the screen)
	var bob := sprout.create_tween().set_loops(6)
	bob.tween_property(sprout, "position:y", -5.0, 0.35).set_trans(Tween.TRANS_SINE)
	bob.tween_property(sprout, "position:y", 0.0, 0.35).set_trans(Tween.TRANS_SINE)
	var tw := p.create_tween()
	if slide:
		tw.tween_property(p, "position:x", shown_x, 0.4).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)  # (no overshoot: it must not slide deeper into the screen)
		tw.tween_interval(25.0)
		tw.tween_property(p, "position:x", hidden_x, 0.45).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	else:
		p.modulate.a = 0.0
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
	if _puppet_strips() and UiSkin.tex("cursor_hand_fist") != null and not is_instance_valid(_grab_cursor):
		_grab_cursor = AimCursor.new()  # (the pointer is a fist round the Essence while you drag it)
		_grab_cursor.mode = "grab"
		add_child(_grab_cursor)
		Input.mouse_mode = Input.MOUSE_MODE_HIDDEN
	if not _puppet_strips():
		_elem_sound("grab")
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
			_elem_sound("place")
	elif res.inside:
		if res.to != src.i and _allowed("rearrange"):
			var k: int = chant_idx[src.i]
			chant_idx.remove_at(src.i)
			chant_idx.insert(clampi(res.to, 0, chant_idx.size()), k)
			_elem_sound("place")
	elif _allowed("remove"):
		back = p.stock[chant_idx[src.i]]
		chant_idx.remove_at(src.i)
		_elem_sound("remove")
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
	_elem_sound("grab")
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
	_elem_sound("remove")
	_flying[s.uid] = true
	_chant_changed()  # the bag makes room for it; its icon waits there, unseen, until this one lands
	_fly(s, from, _bag_target_center(s.uid), px, BAG_PX)


func _add_element(el: String) -> void:
	if busy or phase != "build" or chant_idx.size() >= fight.player.chant_slots() or not _allowed("add", el):
		return
	var pick := -1
	for i in fight.player.stock.size():
		var s: Dictionary = fight.player.stock[i]
		var rolling: Control = _bag_icons.get(s.uid)
		if s.el != el or s.frozen or i in chant_idx or (rolling != null and is_instance_valid(rolling) and rolling.has_meta("rolling")):
			continue
		if pick == -1 or (s.temp and not fight.player.stock[pick].temp) or (fight.player.stock[pick].hexed and not s.hexed):
			pick = i
	if pick >= 0:
		_add_stock_index(pick)
	elif el != "?":
		_add_element("?")  # (none of that left: an Any Essence fits as any element)


## ---- Test mode: Auto-fill and Auto-ball ------------------------------------------------------------------------------------
## Top left corner of the screen, side by side, so the rest of the screen stays exactly as in a real fight.
func _build_test_buttons() -> void:
	var specs := [
		["Auto-fill", _auto_fill, "Test mode: builds the chant that wakes as many of your spells as the Essence in your bag can."],
		["Auto-ball", _auto_ball, "Test mode: shoots new Essence out of the machine until the bag holds 10."]]
	for k in specs.size():
		var b := UiTheme.button(specs[k][0], specs[k][1], 15)
		if _puppet_strips():
			UiTheme.use_heading_font(b)
			UiTheme.style_puppet_button(b, "clear", 15)
		b.tooltip_text = specs[k][2]
		b.custom_minimum_size = Vector2(112.0, 34.0)
		b.size = Vector2(112.0, 34.0)
		b.position = Vector2(8.0 + 120.0 * k, 8.0)
		b.z_index = 200  # (over the top HUD: this corner is the test buttons' only)
		add_child(b)
		_test_btns.append(b)


## The Essence in the bag that can go into the chant now: their stock indices.
func _usable_stock() -> Array:
	var out: Array = []
	var st: Array = fight.player.stock
	for i in st.size():
		if not st[i].frozen and not st[i].hexed:
			out.append(i)
	return out


## The best chant the bag can make: of every ordering of the bag's letters (at most 3^10, `max_len` long) the one that wakes the most spells
## (a spell wakes once per turn, so the score is how many different spells have their pattern in the chant), cut back afterwards from both
## ends while it still wakes as many. `score_of` is a Callable(chant) -> int. Gives up looking after 2.5 s.
func _best_chant(counts: Dictionary, max_len: int, score_of: Callable) -> String:
	var found := ["", -1]  # [the best chant so far, its score]
	_dfs_step("", counts.duplicate(), counts.keys(), max_len, score_of, Time.get_ticks_msec(), found)
	var c: String = found[0]
	var sc: int = found[1]
	while c.length() > 1 and int(score_of.call(c.left(c.length() - 1))) >= sc:
		c = c.left(c.length() - 1)  # (the last letter is not needed)
	while c.length() > 1 and int(score_of.call(c.substr(1))) >= sc:
		c = c.substr(1)
	return c


func _dfs_step(cur: String, left: Dictionary, letters: Array, max_len: int, score_of: Callable, t0: int, found: Array) -> void:
	if Time.get_ticks_msec() - t0 > 2500:
		return
	if cur.length() == max_len:
		var sc: int = score_of.call(cur)
		if sc > int(found[1]):
			found[0] = cur
			found[1] = sc
		return
	for el in letters:
		if int(left[el]) > 0:
			left[el] = int(left[el]) - 1
			_dfs_step(cur + el, left, letters, max_len, score_of, t0, found)
			left[el] = int(left[el]) + 1


## Test mode: take the chant apart and rebuild it so that as many spells as possible are awake.
func _auto_fill() -> void:
	if busy or _auto_busy or phase != "build":
		return
	_auto_busy = true
	if not chant_idx.is_empty():
		_clear_chant()
		await _wait(0.45)
	var usable := _usable_stock()
	var counts := {}
	for i in usable:
		var el: String = fight.player.stock[i].el
		counts[el] = int(counts.get(el, 0)) + 1
	var spells: Array = fight.usable_spells()
	var max_len := mini(usable.size(), mini(fight.player.chant_slots(), 10))
	if max_len <= 0 or spells.is_empty():
		_auto_busy = false
		Events.toast.emit("Nothing to fill: no Essence in the bag or no spell that can fire.", UiTheme.DANGER)
		return
	var score_of := func(c: String) -> int:
		var n := 0
		for sp in spells:
			if not fight._occ(sp, c).is_empty():
				n += 1
		return n
	var chant := _best_chant(counts, max_len, score_of)
	var woken := 0
	for sp in spells:
		if not fight._occ(sp, chant).is_empty():
			woken += 1
	var taken: Array = []
	for k in chant.length():
		for i in _usable_stock():  # (looked up afresh for every Essence: the bag changes while this plays)
			if i < fight.player.stock.size() and not taken.has(i) and fight.player.stock[i].el == chant[k]:  # (the bag can shrink while this plays: the Tweezer Hand steals from it)
				taken.append(i)
				_add_stock_index(i)
				break
		await _wait(0.13)
	_auto_busy = false
	_refresh_all()
	Events.toast.emit("Auto-fill: %d of %d spells wake with %s" % [woken, spells.size(), " ".join(Array(chant.split("")))], Color(0.7, 0.95, 0.7))


## Test mode: new Essence come out of the machine until the bag holds 10.
func _auto_ball() -> void:
	if busy or _auto_busy or phase != "build":
		return
	_auto_busy = true  # (Auto-fill must not start while the new Essence are still rolling into the bag)
	get_tree().create_timer(0.8).timeout.connect(func(): _auto_busy = false)
	var p := fight.player
	var need := 10 - p.stock.size()
	if need <= 0:
		Events.toast.emit("The bag already holds %d Essence." % p.stock.size(), UiTheme.MUTED)
		return
	for i in need:
		p.add_element(fight._random_element())
	_refresh_all()  # (the newcomers roll out of the tube into the bag)


func _clear_chant() -> void:
	if busy or phase != "build" or not _allowed("clear"):
		return
	var going: Array = []
	var px := _chant_px()
	for k in chant_idx.size():
		going.append([fight.player.stock[chant_idx[k]], _chant_slot_center(k)])
	chant_idx.clear()
	_elem_sound("remove")
	for g in going:
		_flying[g[0].uid] = true
	_chant_changed()
	for g in going:
		_fly(g[0], g[1], _bag_target_center(g[0].uid), px, BAG_PX)


func _unhandled_input(ev: InputEvent) -> void:
	if _hud_hidden():
		return
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
	if _picking_any and ev.keycode == KEY_ESCAPE:
		_cancel()  # (a selected spell goes back, as with right-click)
		get_viewport().set_input_as_handled()
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
		elif is_instance_valid(_edrag):
			match ev.keycode:
				KEY_TAB:
					_edrag.key_cycle(-1 if ev.shift_pressed else 1)
				KEY_LEFT:
					_edrag.key_move(-1)
				KEY_RIGHT:
					_edrag.key_move(1)
				KEY_ENTER, KEY_KP_ENTER, KEY_SPACE:
					_edrag.key_drop()
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
	_cast_uids.clear()
	for i in idx:
		_cast_uids[fight.player.stock[i].uid] = true
	phase = "spells"
	_refresh_all()
	await fight.cast_chant(idx)
	_cast_uids.clear()
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
	if phase != "spells" and card.charges > 0 and not busy:
		# a stored spell: awake, but spells are cast after the chant
		_float_text("Chant first", card.global_position + Vector2(card.size.x * card.scale.x / 2.0 - 60, -10), Color(1, 0.9, 0.55))
		Audio.play("release_armour_block", -6.0)
		return
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
			if cands.size() <= _max_picks(spell):
				target = cands[0]  # (no more enemies than it picks: it hits them all, nothing to choose)
			else:
				target = await _aim(card, _card_point(card), cands, "%s: choose a target  ·  click, or Tab + Enter  ·  right-click to put it back" % spell.name, true)
				if target < 0:
					return
	busy = true
	end_confirm = false
	_casting = true
	await fight.resolve_spell(spell.id, target)
	_end_casting()
	if spell.get("power", false):
		_build_spells()  # (the Power left the row: the others close up)
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
	if phase == "spells":  # (spells still alive aren't lost: they're stored for your next chant)
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
	var dillo: Array = fight.enemies.filter(func(e): return e.has_passive("armadillo") and e.is_dead())
	_lift_act_sign()
	if fight.won and not dillo.is_empty():
		await _armadillo_ending(dillo[0])
	for r in fight.enemies.filter(func(e): return e.has_meta("yielded")):
		await _retainer_yields(r)
	if fight.won and stage_flow and _stage != null:  # Puppet Stage: the Victory sign drops from behind the ceiling, the HUD sinks
		await get_tree().create_timer(0.5).timeout
		var perfect_run: bool = fight.player.damage_taken <= 0.0
		var boss_win := fight.enemies.any(func(e): return e.def.get("boss", false))
		if not boss_win:  # (a boss fight already played its own "boss_defeat": two victory sounds on top of each other were too much)
			Audio.play("victory_fanfare")
		var sign_kind := "boss_defeated" if boss_win else ("perfect_victory" if perfect_run else "victory")  # (a boss always gets its own red board)
		var sign_text := "Boss Defeated!" if boss_win else ("Perfect Victory!" if perfect_run else "Victory!")
		await _stage.drop_sign(sign_text, Color(0.55, 0.08, 0.06) if boss_win else Color(0.30, 0.17, 0.07), sign_kind).finished
		await get_tree().create_timer(1.0).timeout
		await _hud_down()
		_stage.lift_sign()
		await get_tree().create_timer(0.5).timeout
	elif fight.won:
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
		if stage_flow and _stage != null and ResourceLoader.exists(UiSkin.theme_dir() + "Stage/Shared/sign_defeat.png"):  # Puppet Stage: the Defeat board drops in
			Audio.play("defeat_stinger")
			await _stage.drop_sign("Defeat", Color(0.3, 0.1, 0.08), "defeat").finished
			await get_tree().create_timer(1.8).timeout
		elif not await _result_banner("defeat"):
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
## The picture names to try for each of your statuses (the first that exists is used; Puppet art first, the older intent pictures as a fallback).
const STATUS_ART_NAMES := {"shield": ["icon_armor_shield"], "thorns": ["status_thorns"], "silence": ["status_silenced"], "aegis": ["status_aegis"],
	"echo": ["status_echo_ready"], "overload": ["status_overload"], "ethereal": ["status_ethereal", "intent_ethereal"],
	"poison": ["status_poison", "intent_poison"], "confuse": ["status_confuse", "intent_confuse"], "blind": ["status_blind", "intent_blind"],
	"frail": ["status_frail", "intent_frail"], "lock": ["status_toll", "intent_toll"], "vulnerable": ["status_vulnerable"],
	"brittle": ["status_brittle"], "disarmed": ["status_disarmed"]}
## A Power's badge picture, by the theme of its dissolve (fire / water / wind use the Essence balls).
const POWER_ART_NAMES := {"fire": ["essence_fire"], "water": ["essence_water"], "wind": ["essence_wind"], "thorn": ["status_thorns"],
	"venom": ["status_poison", "intent_poison"], "leaf": ["icon_seedling"], "shadow": ["status_silenced"], "page": ["icon_spellbook"]}


## The name of the picture for a status badge (`b` is one entry of _status_badges), or "" when there is none.
func _badge_art_name(b: Array) -> String:
	var names: Array = []
	var id := String(b[2])
	if id == "" and b.size() > 4:  # a Power: by what it is made of
		var sp := fight._find_spell(String(b[4]))
		var key: String = String(power_theme(sp).key)
		names = POWER_ART_NAMES.get(key, [])
	else:
		names = STATUS_ART_NAMES.get(id, [])
	for n in names:
		if UiSkin.tex(n) != null:
			return n
	return ""


func _status_badges() -> Array:
	var p := fight.player
	var out := []
	if p.aegis > 0:
		out.append(["✨ Evasion %d" % p.aegis, Color(1.0, 0.8, 0.25), "evasion"])
	var th := p.thorns_turn + p.passive("thorns")
	if th > 0:
		out.append(["🌵 Thorns %d" % th, Color(0.5, 0.85, 0.25), "thorns"])
	if p.ethereal:
		out.append(["👻 Ethereal", Color(0.75, 0.7, 1.0), "ethereal"])
	if p.echo_next:
		out.append(["🔔 Echo ready", Color(0.85, 0.6, 1.0), "echo"])
	if p.poison > 0:
		out.append(["🧪 Poison %d" % p.poison, Color(0.55, 0.9, 0.3), "poison"])
	if p.confuse_turns > 0:
		out.append(["🌀 Hypnotized %d" % p.confuse_turns, Color(0.8, 0.4, 1.0), "confuse"])
	if p.blind_turns > 0:
		out.append(["🙈 Blind %d" % p.blind_turns, Color(0.7, 0.72, 0.78), "blind"])
	if p.frail_turns > 0:
		out.append(["💔 Frail %d" % p.frail_turns, Color(1.0, 0.4, 0.55), "frail"])
	if p.vulnerable > 0:
		out.append(["🎯 Vulnerable %d" % p.vulnerable, Color(1.0, 0.45, 0.35), "vulnerable"])
	if p.brittle_turns > 0:
		out.append(["🧊 Brittle %d" % p.brittle_turns, Color(0.55, 0.75, 0.95), "brittle"])
	if p.toll > 0:
		out.append(["🔔 Toll %d" % p.toll, Color(1.0, 0.6, 0.2), "lock"])
	if p.overload > 0:
		out.append(["⚡ Overload %d" % p.overload, Color(1.0, 0.45, 0.3), "overload"])
	if p.disarmed_turns > 0:
		out.append(["🚫 Disarmed", Color(1.0, 0.55, 0.45), "disarmed"])
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
		elif sp.get("power", false) and Fight.lasting_power(sp):  # (a one-off Power, like Open Grimoire: no badge)
			var pth := power_theme(sp)
			out.append(["%s %s" % [pth.icon, sp.name], pth.col, "", Keywords.tooltip(sp.name, SpellText.describe(sp), "[color=#9aa89a]Power: it lasts the whole fight.[/color]"), id])
	return out


## How each Power dissolves into its status: the side it vanishes from first, its glowing edge and particles, and its
## badge icon. By spell id; anything else by its main element.
const POWER_THEMES := {
	"fire": {"key": "fire", "from": Vector2(0, 1), "col": Color(1.0, 0.55, 0.2), "shape": Vfx.SPARK, "icon": "🔥", "rise": -260.0},
	"water": {"key": "water", "from": Vector2(0, -1), "col": Color(0.35, 0.65, 1.0), "shape": Vfx.DROP, "icon": "💧", "rise": 40.0},
	"wind": {"key": "wind", "from": Vector2(-1, 0), "col": Color(0.6, 1.0, 0.8), "shape": Vfx.GLOW, "icon": "🌪", "rise": 120.0},
	"thorn": {"key": "thorn", "from": Vector2(0, 1), "col": Color(0.55, 0.8, 0.3), "shape": Vfx.THORN, "icon": "🌵", "rise": 60.0},
	"venom": {"key": "venom", "from": Vector2(0, 1), "col": Color(0.55, 0.95, 0.3), "shape": Vfx.BUBBLE, "icon": "🐍", "rise": -120.0},
	"leaf": {"key": "leaf", "from": Vector2(0, -1), "col": Color(0.45, 0.85, 0.35), "shape": Vfx.FLAKE, "icon": "🍃", "rise": 160.0},
	"shadow": {"key": "shadow", "from": Vector2(1, 0), "col": Color(0.75, 0.45, 1.0), "shape": Vfx.SMOKE, "icon": "🕯", "rise": 60.0},
	"page": {"key": "page", "from": Vector2(1, 0), "col": Color(1.0, 0.95, 0.8), "shape": Vfx.SHARD, "icon": "📜", "rise": 200.0},
}
const POWER_THEME_OF := {"kindle": "fire", "ember_crown": "fire", "pyromancy": "fire", "avatar_of_flame": "fire",
	"rising_tide": "water", "trade_winds": "wind", "storm_crown": "wind", "echo_chamber": "wind", "attunement": "wind",
	"thorn_mantle": "thorn", "world_tree_blessing": "leaf",
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
	mat.shader = load("res://assets/Global/Card/Shaders/power_dissolve.gdshader")
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


## status keyword -> art by name (UiSkin looks in assets/New/ ...)
const STATUS_ART := {"shield": "icon_armor_shield", "thorns": "status_thorns", "silence": "status_silenced", "aegis": "status_aegis", "evasion": "status_aegis",
	"echo": "status_echo_ready", "overload": "status_overload", "ethereal": "intent_ethereal", "poison": "intent_poison",
	"confuse": "intent_confuse", "blind": "intent_blind", "frail": "intent_frail", "lock": "intent_toll"}


func _refresh_statuses() -> void:
	if _puppet_hud:
		_refresh_statuses_compact()
		return
	for c in _status_row.get_children():
		c.queue_free()
	for b in _status_badges():
		var chip := TipPanel.new()  # its tooltip is rich text
		var col: Color = b[1]
		var pill := UiSkin.box("status_badge_pill", [17, 16, 17, 16], [14, 3, 14, 5])
		var icon: Control = UiSkin.icon(_badge_art_name(b), 24) if pill != null else null
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
	# painted themes: only the bottles you carry (the frame behind them grows and shrinks with them); Default shows the empty slots too
	var n_shown: int = bs.size() if UiSkin.is_new() else maxi(run.bottle_slots() if run else Bottles.BASE_SLOTS, bs.size())
	var chip_px := 64.0 if n_shown <= 3 else (52.0 if n_shown == 4 else 44.0)  # (five bottles must not push the frame out of the panel, nor squeeze the HP text)
	_bottle_row.add_theme_constant_override("separation", 6 if n_shown <= 3 else 0)
	if _nu_ui:  # (the five bottle slots of NewUiLayout)
		chip_px = NewUiLayout.BOTTLE_PX
		_bottle_row.add_theme_constant_override("separation", int(NewUiLayout.BOTTLE_CELL.x - NewUiLayout.BOTTLE_PX))
	elif _puppet_hud:  # (the bottle frame's five slots hold them 44 px each)
		chip_px = BOTTLE_PX
		_bottle_row.add_theme_constant_override("separation", int(BOTTLE_STEP - BOTTLE_PX))
	for i in n_shown:
		var chip := BottleChip.make(bs[i] if i < bs.size() else "", i, true, chip_px)
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
	_casting = true
	if UiSkin.tex(chip._art_name()) != null:  # it grows, shines and vaporises in a puff of smoke (a picture of its own: the real chip is gone as soon as the screen refreshes)
		BottleVapor.play(_fx, chip._art_name(), chip.get_global_rect().get_center() - _fx.global_position, chip.size.x)
		chip.modulate.a = 0.0
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
		"Quit Behind the Curtain? " + saved if run_saved else "Quit Behind the Curtain?")
	pm.world_keep = [_enemy_row, _fx]  # (a "Without UI" screenshot keeps the enemies and the effects on the stage)
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
	var avoid := Rect2()  # (the puppet it is about: the panel never covers it)
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
				avoid = v.puppet_global_rect()
				break
			# its HP: every status on it explained (Power, Burn, armour, passives...)
			if v.hp_hovered(m):
				key = "hp:%d" % v.get_instance_id()
				text = v.info_text()
				anchor = Rect2(m - Vector2(20, 20), Vector2(40, 40))
				avoid = v.puppet_global_rect()
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
	if avoid.has_area():  # on the puppet's left, where its intent bubble stands (on its right when the left side has no room): never over the puppet
		var left := avoid.position.x - 4.0 - p.size.x
		var ax := left if left >= 10.0 else avoid.end.x + 4.0
		p.position = Vector2(clampf(ax, 10.0, 1910.0 - p.size.x), clampf(avoid.get_center().y - p.size.y / 2.0, 10.0, 1070.0 - p.size.y))
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


## Dragging: the Bag (or the Chant, for a steal into it) lights up while the Essence in your hand can be let go on it; the fist goes when the drag is over.
var _glow_panel: Control
var _glow_tween: Tween
var _grab_cursor: AimCursor
var _test_pointer := Vector2(-1, -1)  # (a test's pointer: the real one cannot be moved from a script)


func _drag_feedback() -> void:
	if is_instance_valid(_grab_cursor) and not is_instance_valid(_bdrag):
		_grab_cursor.queue_free()
		_grab_cursor = null
		if not _picking_any:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var panel: Control = null
	if not _steal_drag.is_empty():
		var chant_drop := _steal_into_chant
		var r := (_chant_row if chant_drop else _stock_row).get_global_rect().grow(BAG_DROP_MARGIN * (0.6 if chant_drop else 1.0))
		if r.has_point(_test_pointer if _test_pointer.x >= 0.0 else get_global_mouse_position()):
			panel = _chant_panel if chant_drop else _bag_panel
	elif is_instance_valid(_bdrag) and _bdrag_src.get("kind", "") == "chant" and not _bdrag.external_result().inside:
		panel = _bag_panel  # (let go away from the chant: it goes home to the Bag)
	if panel == _glow_panel:
		return
	if is_instance_valid(_glow_panel):
		var tw0 := create_tween()
		tw0.tween_property(_glow_panel, "self_modulate", Color.WHITE, 0.15)
	_glow_panel = panel
	if panel != null:
		if _glow_tween != null and _glow_tween.is_valid():
			_glow_tween.kill()
		_glow_tween = create_tween()
		_glow_tween.tween_property(panel, "self_modulate", Color(1.6, 1.4, 0.85), 0.15)


func _process(_d: float) -> void:
	if not rope_mode:
		_update_hover_info(_d)
	if _puppet_strips():
		_drag_feedback()
	_pulse_release()
	# what the artifacts give for next turn: once the HUD is up and no ball is moving, it flies to the tray (each once)
	if _puppet_strips() and _machine_ready and not _hud_hidden() and phase == "build" and not busy and _spawned_once 			and fight.player.next_draw.any(func(d): return d.has("from") and not d.get("shown", false)):
		_stash_artifact_draws(fight.turn + 1)
	if _puppet_strips():
		_fit_enemy_lift()
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
	if cands.size() <= _max_picks(spell):
		return cands[0]  # (no more enemies than it picks: nothing to choose)
	var card: SpellCard = null
	for c in _cards:
		if c.spell.id == spell.id:
			card = c
	var from := _card_point(card) if card else _player_panel.global_position + Vector2(250, 0)
	var second: bool = spell.effects.any(func(x): return x.get("target", "") == "two")
	var what := "choose a SECOND, different enemy" if second else "choose a target"
	return await _aim(card, from, cands, "%s: %s  ·  click, or Tab + Enter" % [spell.name, what], false)


## Rearrange: grab an Essence of this enemy's row and drag it to another spot, the way you rearrange your chant
## (the others slide aside). Tab + Left / Right + Enter works too; Esc / right-click skips.
## (Behind walls, the Bramble Matron's row is split up: there it's click one, then click where it goes.)
var _edrag: ChantDrag  # the enemy row being rearranged


func _mover(spell: Dictionary, e: EnemyState) -> Array:
	var v: EnemyView = _views.get(e)
	if v == null:
		return []
	move_view = v
	v.move_mode = true
	v.move_pick = -1
	var walled := e.has_passive("briar_walls")
	_prompt.text = ("%s: click an Essence of %s to pick it up  ·  right-click to skip" if walled else
		"%s: grab an Essence of %s and drag it to another spot  ·  Tab + Left / Right + Enter  ·  right-click to skip") % [spell.name, e.name]
	_refresh_all()
	if not walled:
		await get_tree().process_frame  # (the row grows for the move: lay it out first)
		_edrag = v.begin_row_drag(self)
		_edrag.dropped.connect(func(from, to): _move_done.emit([from, to]))
	var pair: Array = await _move_done
	if is_instance_valid(_edrag):
		await _wait(0.25)  # (let the dropped one settle)
		_edrag.queue_free()
		v.end_row_drag()
	_edrag = null
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
		if not e.armor[i] and (fight.pick_el == "" or e.elements[i] == fight.pick_el):
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
	v.pick_el = fight.pick_el
	v.pick_i = free[0]
	_prompt.text = "%s: choose an Essence of %s to %s  ·  click it, or Tab + Enter" % [spell.name, e.name, verb]
	_callout("Choose an Essence of [b]%s[/b] to %s" % [e.name, verb], v.global_position + Vector2(v.size.x / 2.0, 120), Color(1, 0.85, 0.4), 2.5)
	_refresh_all()
	var idx: int = await _pick_done
	tut.emit("picked", idx)
	v.keep_big = v.keep_big or _casting
	v.pick_mode = false
	v.pick_el = ""
	v.pick_i = -1
	pick_view = null
	_refresh_all()
	return idx


func _cycle_pick(step: int) -> void:
	var e := pick_view.enemy
	var i := pick_view.pick_i
	for k in e.size():
		i = (i + step + e.size()) % e.size()
		if not e.armor[i] and (pick_view.pick_el == "" or e.elements[i] == pick_view.pick_el):
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


## Spells that take "an Essence of your choice" (Pluck, Steal any): the choice is the Essence itself, anywhere.
func _picks_any_essence(eff: Dictionary) -> bool:
	return eff.get("op", "") in ["pluck", "steal"] or (eff.get("op", "") == "purge" and eff.get("target", "") in ["target", "two"])


## A spell that takes only one kind of Essence ("remove up to 3 Fire", "steal up to 2 Water"): that kind, else "".
func _pick_kind(eff: Dictionary) -> String:
	if eff.get("op", "") == "purge" or (eff.get("op", "") == "steal" and eff.get("el", "any") != "any"):
		return String(eff.get("el", ""))
	return ""


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
	_pick_el = fight.pick_el if fight.pick_el != "" else _pick_kind(eff)
	_steal_into_chant = eff.get("into", "") == "chant"
	var greyed: Control = null
	if _pick_style == "hand":
		greyed = _chant_row if not _steal_into_chant else _stock_row
		greyed.modulate = Color(0.55, 0.55, 0.55, 0.6)
	_picking_any = true
	_picking_any_cancellable = cancellable
	if _pick_style == "hand":
		_shrink_cards(true)  # (the cards must not cover the enemies' rows of Essence)
	tut.emit("picking", null)
	for v in _views.values():
		v.pick_mode = (only == null or v.enemy == only) and not v.enemy.is_dead()  # (not a fallen hand)
		v.paint_mode = _pick_style == "brush"
		v.paint_to = fight.paint_to
		v.pick_el = _pick_el
		v.pick_i = -1
	# the pointer becomes a crosshair (remove), an open hand (steal) or a paint brush (Expose)
	_aim_cursor = AimCursor.new()
	_aim_cursor.mode = _pick_style
	add_child(_aim_cursor)
	Input.mouse_mode = Input.MOUSE_MODE_HIDDEN
	var what: String = Elements.NAMES.get(_pick_el, "Essence")  # (a spell that takes one kind names it: "an enemy's Fire")
	var paint: String = "an Any Essence" if fight.paint_to == "?" else Elements.NAMES[fight.paint_to]
	var how: String = {"hand": ("drag an enemy's %s down into your chant" if _steal_into_chant else "drag an enemy's %s down into your bag") % what, "brush": "paint an enemy's Essence: it becomes %s" % paint}.get(_pick_style, "shoot an enemy's %s off" % what)
	_prompt.text = "%s: %s%s" % [spell.name, how, "  ·  right-click to put it back" if cancellable else ""]
	_callout("[b]%s[/b]: %s" % [spell.name, how], Vector2(960, 150), Color(1, 0.85, 0.4), 2.0)
	_refresh_all()
	var got: Array = await _any_picked
	if greyed != null:
		greyed.modulate = Color.WHITE
	if _pick_style == "hand":
		_shrink_cards(false)
	_picking_any = false
	_pick_only = null
	_pick_el = ""
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
			v.pick_el = ""
			v.pick_i = -1
	_refresh_all()
	return got


var _cards_tween: Tween


## Steal: the spell row shrinks towards the chant (its bottom middle) and the cards stop magnifying under the mouse, so the enemies' Essence stay in view.
func _shrink_cards(on: bool) -> void:
	SpellCard.hover_off = on
	if on:
		for c in _cards:
			if is_instance_valid(c):
				c.drop_zoom()
	if _spell_row == null:
		return
	if _cards_tween != null and _cards_tween.is_valid():
		_cards_tween.kill()
	_spell_row.pivot_offset = Vector2(_spell_row.size.x / 2.0, _spell_row.size.y)
	_cards_tween = create_tween()
	_cards_tween.tween_property(_spell_row, "scale", Vector2.ONE * (0.5 if on else 1.0), 0.18).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


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
	fx.stopper = _hitstop
	# the tracer: a white-hot streak from below the screen straight into the Essence, gone in a blink
	var from := at + Vector2(randf_range(-120, 120), 900)
	var tracer := fx.beam(from, at, Color(1, 0.92, 0.7, 0.95), 0.09, 5.0)
	tracer.w0 = 2.0
	fx.beam(from, at, Color(col, 0.5), 0.14, 14.0)
	# the hit: muzzle-bright flash, a cross-shaped glint, a crack of shockwave
	fx.glow(at, 150, Color(1, 0.97, 0.85, 1.0), 0.1)
	fx.glow(at, 230, Color(col, 0.75), 0.4)
	fx.flare(at, 300, Color(1, 0.88, 0.5, 0.95), 0.16)
	fx.ring(at, 6, 95, Color(1, 0.95, 0.75), 0.22, 6.0)
	fx.ring(at, 10, 150, col, 0.38, 8.0, 0.03)
	fx.burst(at, 24, Color(1, 0.85, 0.4), Vector2(350, 900), Vector2(0.1, 0.25), Vector2(3, 6))
	var hole := fx.part(at, Vector2.ZERO, Color(0.05, 0.03, 0.03, 0.95), 0.7, 11.0, Vfx.SMOKE)
	hole.size1 = 11.0
	hole.hold = 0.6
	# the Essence breaks apart in its own colour, blown out the far side
	for s in fx.burst(at, 18, col, Vector2(200, 560), Vector2(0.5, 0.85), Vector2(6, 12), Vfx.SHARD, 0.0, PI * 0.9, -PI / 2.0):
		s.grav = Vector2(0, 1100)
		s.spin = randf_range(-14, 14)
		s.size1 = s.size0
	for i in 5:
		var sm := fx.part(at + Vector2(randf_range(-8, 8), 0), Vector2(randf_range(-40, 40), -randf_range(40, 110)), Color(0.12, 0.1, 0.1, 0.45), randf_range(0.6, 0.9), 8.0, Vfx.SMOKE)
		sm.size1 = 30.0
		sm.drag = 1.5
	fx.hitstop(0.07)
	fx.shake(9.0)
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
	if _steal_into_chant:
		bag = _chant_row.get_global_rect().grow(BAG_DROP_MARGIN * 0.6)  # (Instant Steal: it goes into the chant)
	var ghost := ElementIcon.make(d.el, 52)
	ghost.size = Vector2(52, 52)
	ghost.pivot_offset = ghost.size / 2.0
	ghost.z_index = 150
	ghost.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ghost.position = at + Vector2(0, -35.0) - ghost.size / 2.0 - _fx.global_position  # (where the hand held it)
	ghost.scale = Vector2.ONE * (34.0 / 52.0)  # (as small as in the hand)
	_fx.add_child(ghost)
	if bag.has_point(at):
		var to := _stock_row.global_position + _bag_slot(_bag_icons.size(), _bag_icons.size() + 1) - _fx.global_position
		if _steal_into_chant:
			# Instant Steal: like a Steal into the bag, it flies to the chant's next free spot
			var n := fight.chant.size()
			var slot: Control = _chant_row.get_child(n) if n < _chant_row.get_child_count() else null
			var end := (slot.get_global_rect().get_center() if slot != null else _chant_row.get_global_rect().end - Vector2(30, _chant_row.size.y / 2.0))
			to = end - ghost.size / 2.0 - _fx.global_position
		var direct := _puppet_strips() and not _steal_into_chant
		if direct:  # the Essence goes straight into the Bag (no machine, no show): the Bag's own ball shows up when this one has landed
			_direct_in += 1
			_direct_until = Time.get_ticks_msec() + 5000
			_direct_landed = false
			_direct_wait.clear()
			_keep_bag_order = true  # (it stays at the back; the Bag is sorted once at the next spawn)
			to = _stock_row.global_position + _bag_slot(_bag_icons.size(), _bag_icons.size() + 1) - _fx.global_position
		var tw := ghost.create_tween().set_parallel(true)
		tw.tween_property(ghost, "position", to, 0.28).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		tw.tween_property(ghost, "scale", Vector2.ONE, 0.28).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)  # (it grows to the size of your own Essence)
		tw.chain().tween_callback(func():
			if direct:
				_direct_landed = true
				for w in _direct_wait:
					if is_instance_valid(w):
						w.modulate.a = 1.0
				_direct_wait.clear()
				_ball_sound("hit", -4.0, randf_range(0.95, 1.08))
			ghost.queue_free())
		if not direct:
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
			if index < v.enemy.size() and v.enemy.elements[index] != fight.paint_to and _allowed("pick", index):
				if is_instance_valid(_aim_cursor):
					_aim_cursor.kick()  # the brush presses down
				_any_picked.emit([fight.enemies.find(v.enemy), index])
			return
		if index < v.enemy.size() and _pick_el != "" and v.enemy.elements[index] != _pick_el:
			return  # (dimmed: not the kind this spell takes)
		if index < v.enemy.size() and not v.enemy.armor[index] and _allowed("pick", index) and _steal_drag.is_empty():
			if _pick_style == "hand":
				_begin_steal_drag(v, index)  # the pick happens when it's dropped on the bag
			else:
				_fire_shot(v, index)
				_any_picked.emit([fight.enemies.find(v.enemy), index])
		return
	if v == pick_view:
		if index < v.enemy.size() and _allowed("pick", index) and not v.enemy.armor[index] and (v.pick_el == "" or v.enemy.elements[index] == v.pick_el):
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
	if _infuse_at >= 0:
		# Instant Steal: it was dropped straight onto its spot in the chant
		var at := clampi(_infuse_at, 0, fight.chant.size())
		_infuse_at = -1
		return at
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


## Wild Rearrange: your chant and every enemy row come alive at once; drag one Essence to another spot in its own
## row (chant or enemy). Returns [from, to] for the chant, [from, to, enemy index] for an enemy, [] to skip.
func _wild_arranger(spell: Dictionary) -> Array:
	chant_mode = "arrange"
	var in_chant: bool = fight.spoken and fight.chant.size() > 1
	if in_chant:
		var live := []
		for c in fight.chant:
			live.append(true)
		_show_drag(fight.chant.duplicate(), live, true)
		_drag.dropped.connect(func(from, to): _arrange_done.emit([from, to]))
	var rows := []
	for e in fight.alive():
		var v: EnemyView = _views.get(e)
		if v != null and e.size() > 1 and not e.has_passive("briar_walls"):
			v.move_mode = true
			rows.append(v)
	_prompt.text = "%s: drag an Essence to another spot, in your chant or in an enemy's row  ·  right-click: keep them" % spell.name
	_refresh_all()
	await get_tree().process_frame
	var drags := []
	for v in rows:
		var d: ChantDrag = v.begin_row_drag(self)
		var idx: int = fight.enemies.find(v.enemy)
		d.dropped.connect(func(from, to): _arrange_done.emit([from, to, idx]))
		drags.append(d)
	var mv: Array = await _arrange_done
	await _wait(0.25)
	for d in drags:
		d.queue_free()
	for v in rows:
		v.end_row_drag()
		v.move_mode = false
	if in_chant:
		await _hide_drag()
	chant_mode = ""
	_refresh_all()
	return mv


## Wild Repaint: the brush comes out over the enemies, and your chant's Essence can be clicked too. Returns
## ["chant", i], ["enemy", enemy index, i], or [] if nothing could be painted.
signal _wild_painted(got: Array)


func _wild_painter(spell: Dictionary) -> Array:
	var st := {"done": false}  # (shared by both handlers: the first pick wins)
	var on_chant := func(i: int) -> void:
		if not st.done:
			st.done = true
			_wild_painted.emit(["chant", i])
	var on_enemy := func(got: Array) -> void:
		if not st.done:
			st.done = true
			_wild_painted.emit(["enemy", got[0], got[1]] if got.size() == 2 else [])
	_chant_done.connect(on_chant)
	_any_picked.connect(on_enemy)
	if fight.spoken and not fight.chant.is_empty():
		chant_mode = "pick"
		chant_i = 0
	_pick_any_essence(spell, false, null, "brush")  # (it waits for an enemy pick on its own; a chant pick ends it)
	if chant_mode == "pick":
		_prompt.text = "%s: paint an enemy's Essence, or click one of your chant" % spell.name
		_refresh_chant()
	var got: Array = await _wild_painted
	_chant_done.disconnect(on_chant)
	_any_picked.disconnect(on_enemy)
	if got.size() == 2 and _picking_any:
		_any_picked.emit([])  # put the brush away
	chant_mode = ""
	_refresh_all()
	return got


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
	if fight.current_eff.get("op", "") == "retain":
		_prompt.text = "%s: which Essence of the chant comes back to your bag after the Release?  ·  click it, or Tab + Enter" % spell.name
		chant_mode = "pick"
		chant_i = 0
		_refresh_all()
		var r: int = await _chant_done
		chant_mode = ""
		_refresh_all()
		return r
	var self_paint: bool = fight.current_eff.get("op", "") == "self_repaint"
	var to: String = fight.current_eff.get("to", "?")
	_prompt.text = ("%s: which Essence of the chant should be repainted %s?  ·  click it, or Tab + Enter" % [spell.name, "Any" if to == "?" else Elements.NAMES[to]]) if self_paint else \
		"%s: which Essence of the chant should be duplicated?  ·  click it, or Tab + Enter" % spell.name
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
## Every event of the fight, then: an enemy that has no Essence left breaks at once (not at the end of the turn).
func _anim(ev: Dictionary) -> void:
	await _anim_event(ev)
	_cull_dead()


## Puppet Stage: the views of enemies that were defeated break into pieces and leave; the others stay as they are.
func _cull_dead() -> void:
	if _enemy_row == null:
		return
	for e in _views.keys():
		if e.is_dead() and not e.knocked and not _hand_going_down(e) and not e.has_passive("armadillo") and not e.has_meta("yielded") and not (e.has_passive("veil_falls") and e.phase == 1):  # (the Veiled Eyes at 0 Essence do not break: the veil falls and the same puppet unfolds)
			var old: EnemyView = _views[e]
			_views.erase(e)
			if is_instance_valid(old):
				if is_instance_valid(old.creature):
					if old.creature.has_rig():
						_shatter_arm(old.creature)
					else:
						PuppetShatter.spawn(self, old.creature)
				old.get_parent().remove_child(old)
				old.queue_free()


func _anim_event(ev: Dictionary) -> void:
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
		"refund":
			await _refund_flight(ev)
		"next_rolled":
			pass  # (what the artifacts gave flies to the tray once the balls of this turn are in: see _process)
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
				splash.el = String(ev.get("to", "?"))
				splash.radius = (ic.size.x if ic else 40.0) * 0.31  # (half the size it was)
				var at: Vector2 = ic.get_global_rect().get_center() if is_instance_valid(ic) and ic.is_inside_tree() else pv.hp_point(ev.index)  # (right on the Essence just painted)
				splash.position = at - _fx.global_position
				_fx.add_child(splash)
				_play_fx("repaint", "sfx_expose_apply")  # (the Repaint group: every brush stroke makes it)
				splash.play(_refresh_all)  # the icon underneath turns Any while the paint covers it
				await _wait(0.25)
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
			_play_fx(String(ev.get("fx", "")), "elem_pickup")  # (a repainted chant Essence: the Repaint group, not the pick-up click)
			_refresh_all()
			await _wait(0.35)
		"trinity":
			# the three Fragments rise into a triangle and whirl into Trinity
			var froms := []
			for s in ev.parts:
				var c := _card_for(s.id)
				froms.append(c.global_position if c else Vector2(960, 760))
				if c:
					c.modulate.a = 0.0
			await TrinityScene.play(self, ev.parts, froms, ev.result)
			_build_spells()
			_refresh_all()
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
		"power_proc":
			# a Power does something: its badge pops and shines, with a chime
			var pb := _power_badge(String(ev.id))
			if pb:
				pb.pivot_offset = pb.size / 2.0
				var tw := pb.create_tween()
				tw.tween_property(pb, "modulate", Color(2.0, 1.8, 1.3), 0.08)
				tw.parallel().tween_property(pb, "scale", Vector2(1.25, 1.25), 0.08)
				tw.tween_property(pb, "modulate", Color.WHITE, 0.35)
				tw.parallel().tween_property(pb, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK)
				var fx := Vfx.make(_fx, 75)
				var at := pb.global_position + pb.size / 2.0 - _fx.global_position + _fx.global_position
				fx.glow(at, 90, Color(1.0, 0.9, 0.5, 0.8), 0.35)
				fx.ring(at, 8, 60, Color(1.0, 0.9, 0.55), 0.3, 4.0)
			Audio.play("spell_glow")
			await _wait(0.3)
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
			if snd == "sfx_magic_hit" and not UiSkin.is_puppet():
				snd = "sfx_damage_hit"  # (the magic hit sound is Puppet art)
			var fx_group: String = EFFECT_FX.get(ev.op, "")
			if ev.op == "barrage" and ev.targets.size() > 1:  # a volley (Elemental Fury: 6 shots): every shot has its own sound, one after the other
				_volley(ev.targets, fx_group if Audio.has_sfx("spellfx_" + fx_group) else "", snd)
				snd = ""
				fx_group = ""
			if fx_group == "repaint":
				snd = ""
				fx_group = ""  # (every stroke of the brush made the Repaint sound already: it does not play once more at the end)
			if fx_group == "shield" and ev.get("eff", {}).get("lasting", false):
				fx_group = "lasting_shield"
			if fx_group != "" and Audio.has_sfx("spellfx_" + fx_group):
				Audio.play("spellfx_" + fx_group)
			elif snd != "":
				Audio.play(snd)
			_effect_landed(ev)
			_sync_views()
			_refresh_all()
			await _wait(maxf(0.3, 0.11 * ev.targets.size()) if ev.op == "barrage" else 0.3)  # (a volley lasts as long as its shots)
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
			if not ev.get("gains", []).is_empty():
				await _mend_light(ev.enemy, ev.gains)
			else:
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
		"laser":
			await _eye_laser(ev.enemy)
		"veil_falls":
			Audio.play("boss_phase_change")
			_sync_views()
			_refresh_all()
			_callout_beside(_views.get(ev.enemy), "[i]The veil falls away. Something underneath unfolds its legs.[/i]", Color(0.75, 0.5, 1.0), 2.4)
			await _wait(1.4)
			var vv: EnemyView = _views.get(ev.enemy)
			while vv != null and is_instance_valid(vv.creature) and vv.creature.unveiling():  # (the Veiled Eyes' unveiling plays out before anything else)
				await get_tree().process_frame
		"spider_steal":
			await _spider_steal(ev.enemy, ev.spell)
		"boss_phase":
			Audio.play("boss_phase_change")
		"boss_defeat":
			Audio.play("boss_defeat")
		"hm_rally":
			await _hm_rally_scene()
		"spawn":
			Audio.play("enemy_spawn")
			_sync_views()
			var cocoon_view: EnemyView = _views.get(ev.enemy) if ev.enemy.id == "spider_cocoon" else null
			if cocoon_view != null:
				cocoon_view.modulate.a = 0.0  # (no first frame in its place: it is let down from above)
			_refresh_all()
			if cocoon_view != null:
				var dropped := [false]
				(func():
					await _drop_view_in(cocoon_view)
					dropped[0] = true).call()
				if _spider_away != null:  # the spider follows the cocoon down a second after it
					await _wait(1.0)
					await _spider_return(_spider_away)
				while not dropped[0]:
					await get_tree().process_frame
			await _wait(0.25)
		"spider_return":
			await _spider_return(ev.enemy)
		"meteor":
			# Chaos Meteor: a fireball falls from the sky onto this enemy
			var mv: EnemyView = _views.get(ev.enemy)
			if mv != null:
				var to := mv.anchor_point() + Vector2(randf_range(-30, 30), -40)
				var from := to + Vector2(randf_range(-420, -260), -900)
				var fx := Vfx.make(_fx, 80)
				fx.move(from, to, 0.42, 0.0, Color(1.0, 0.55, 0.15), 16.0, 0.0,
					func(vx: Vfx, it, _dt):
						vx.part(it.pos, Vector2(randf_range(-30, 30), randf_range(-60, -10)), Color(1.0, randf_range(0.3, 0.7), 0.1), randf_range(0.25, 0.45), randf_range(8, 14)),
					func(vx: Vfx, at: Vector2):
						vx.glow(at, 160, Color(1.0, 0.6, 0.2), 0.3)
						vx.ring(at, 8, 110, Color(1.0, 0.5, 0.15), 0.3, 6.0)
						vx.burst(at, 18, Color(1.0, 0.65, 0.2), Vector2(150, 420), Vector2(0.3, 0.55), Vector2(4, 8))
						vx.shake(6.0))
				Audio.play("sfx_burn_apply")
				await _wait(0.45)
		"meteor_hit":
			_refresh_all()
		"revive":
			# a fallen hand gets back up: a golden flash as it rises
			var rv: EnemyView = _views.get(ev.enemy)
			_sync_views()
			_refresh_all()
			if rv != null:
				rv.modulate = Color(2.0, 1.8, 1.0)
				rv.create_tween().tween_property(rv, "modulate", Color.WHITE, 0.6)
			Audio.play("enemy_spawn")
		"intents_shown":
			_turn_batch_until = Time.get_ticks_msec() + 4000  # (Cirus: the Essence of the new turn come out of the tube)
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
			await _rolls_done()
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
		"hourglass_dust":
			await _hourglass_dust(ev.enemy)
		"hammer":
			await _hammer_fx(ev)
		"invoke":
			var iv: EnemyView = _views.get(ev.enemy)
			if iv:
				iv.flash_invoked(ev.idx)
			Audio.play("spell_glow")
			await _wait(0.45)
		"hm_new_hands":
			await _hm_new_hands(ev.ids, ev.lines)
		"speech":
			await _speech(ev.enemy, ev.text)
		"speech_lines":
			# a few sentences, one bubble each, held long enough to read (about 3 words a second, plus a moment)
			for line in ev.lines:
				await _speech(ev.enemy, line, 1.0 + String(line).split(" ").size() / 3.0)
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
		"poison_tick":
			Audio.play("sfx_poison_tick")
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
	var words: Array = ["extension"] if count == 1 else [WORD_COUNTS[count - 2], "extension"] if count - 2 < WORD_COUNTS.size() else []  # (the carved wooden lettering, when the theme has it)
	await _slam(text, Color(1.0, 0.86, 0.25), Color(0.4, 0.08, 0.0), 128 if count == 1 else 104, words)


const WORD_COUNTS := ["double", "triple", "quadruple", "quintuple"]  # (UI/Banners/word_<name>.png: "Double" ... then "Extension" under it)


## The carved lettering of a slam: one picture per word, stacked, centred in a box the size of the text it replaces (null when a picture is missing).
func _art_words(words: Array) -> Control:
	var texs: Array = words.map(func(w): return UiSkin.tex("word_" + w))
	if texs.has(null):
		return null
	var box := Control.new()
	var row_h := 190.0 if texs.size() == 1 else 125.0
	var total := row_h * texs.size()
	for i in texs.size():
		var t: Texture2D = texs[i]
		var r := TextureRect.new()
		r.texture = t
		r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		r.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		r.size = Vector2(row_h * t.get_width() / t.get_height(), row_h)
		r.position = Vector2(750.0 - r.size.x / 2.0, 100.0 - total / 2.0 + i * row_h)
		r.mouse_filter = Control.MOUSE_FILTER_IGNORE
		box.add_child(r)
	return box


## Big slanted words slapped onto the table (Extension!, Perfect!): they drop in huge, hit with a shake and a
## burst of sparks along their length, bounce, and fade.
func _slam(text: String, col: Color, outline: Color, font_px: int, words := []) -> void:
	var art: Control = _art_words(words) if not words.is_empty() else null
	var l: Control = art if art != null else Label.new()
	if art == null:
		_style_slam_label(l as Label, text, col, outline, font_px)
	await _slam_finish(l)


func _style_slam_label(l: Label, text: String, col: Color, outline: Color, font_px: int) -> void:
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


## The slam itself (shared by text and carved lettering): drops in huge, hits, bounces, fades.
func _slam_finish(l: Control) -> void:
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
## A charge goes off: its hourglass runs out and crumbles to dust (0.75 s), then the hit.
func _hourglass_dust(e: EnemyState) -> void:
	var v: EnemyView = _views.get(e)
	var chip: Control = v.intent_chip() if v else null
	if chip == null:
		return
	# a picture of the bubble (a copy, drawn on its own), which then turns to dust in its place (see DustCloud)
	var pad := Vector2(4, 4)
	var vp := SubViewport.new()
	vp.size = Vector2i(chip.size + pad * 2.0)
	vp.transparent_bg = true
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(vp)
	var copy := IntentChip.make(e)
	copy.position = pad
	copy.size = chip.size
	vp.add_child(copy)
	await get_tree().process_frame
	await get_tree().process_frame
	var img := vp.get_texture().get_image()
	vp.queue_free()
	chip.modulate.a = 0.0
	DustCloud.crumble(_fx, img, chip.global_position - pad * chip.get_global_transform().get_scale(), chip.get_global_transform().get_scale().x, 0.75)
	Audio.play("sfx_dust")
	await _wait(0.75)


## The Hammer Hand strikes a spell: a thump, the card jolts and cracks. On the last hit it's broken: cracked all over, grey.
func _hammer_fx(ev: Dictionary) -> void:
	var card := _card_for(ev.id)
	var v: EnemyView = _views.get(ev.enemy)
	var cr: Creature = v.creature if v else null
	var reached := card != null and cr != null and cr.has_rig() and Creature.POKE_TIP.has(ev.enemy.id)
	if reached:  # (the Hammer Hand's arm reaches over the screen and brings the hammer down ON the card)
		cr.tip_z = PuppetStage.CEILING_Z + 3
		cr.poke_target = card.global_position + card.size * card.scale / 2.0
		var reach := create_tween()
		reach.tween_property(cr, "poke", 1.0, 0.4).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		await reach.finished
		_hammer_retreat(cr)
	elif v and v.creature.has_rig():  # (no art to reach with: it swings in place)
		_arm_swing(v.creature, 1.0)
		await _wait(0.23)
	if card and v and not reached:
		var from := v.creature.global_position + v.creature.size / 2.0
		var to := card.global_position + card.size * card.scale / 2.0
		Comet.launch(_fx, from, to, Color(0.75, 0.62, 0.5))
		await _wait(0.4)
	if not UiSkin.is_puppet():  # (Puppet: sfx_card_hit / sfx_card_break play with the planks)
		Audio.play("sfx_hammer_thump")
	_shake(8.0)
	if card == null:
		return
	if ev.broken:
		# broken: it stays in the row, cracked all over and greyed out (it can't be cast for the rest of the fight)
		card.cracks = 3
		card.refresh()
		if UiSkin.is_puppet():
			await _split_card(card, 3, true)
			Audio.play("sfx_card_break")
		else:
			Audio.play("sfx_hammer_thump")
		_refresh_all()
		await _wait(0.3)
		return
	card.cracks = ev.hits
	card.refresh()
	if UiSkin.is_puppet():  # (the card is cut into planks that stay together: 1 hit 5, 2 hits 10)
		await _split_card(card, int(ev.hits), true)
		await _wait(0.2)
		return
	var home := card.position
	var tw := card.create_tween()
	tw.tween_property(card, "position", home + Vector2(0, 10), 0.05)
	tw.tween_property(card, "position", home, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	Vfx.make(_fx, 70).burst(card.global_position + card.size * card.scale / 2.0, 10, Color(0.9, 0.95, 1.0), Vector2(60, 200), Vector2(0.2, 0.45), Vector2(2, 4), Vfx.SHARD)
	await _wait(0.35)


## After the blow the hammer stays on the card a moment, then the arm goes back to its place.
func _hammer_retreat(cr: Creature) -> void:
	await _wait(0.5)
	if not is_instance_valid(cr):
		return
	var back := create_tween()
	back.tween_property(cr, "poke", 0.0, 0.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await back.finished
	if is_instance_valid(cr):
		cr.poke = 0.0
		cr.tip_z = 0


## A picture of a spell card (as it is, without cracks), with 8 px of margin: (texture, margin).
func _card_picture(card: SpellCard) -> Array:
	var pad := Vector2(8, 8)
	var vp := SubViewport.new()
	vp.size = Vector2i(Vector2(SpellCard.W, SpellCard.H) + pad * 2.0)
	vp.transparent_bg = true
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(vp)
	var copy := SpellCard.make(card.spell)
	copy.is_zoom_copy = true
	copy.position = pad
	vp.add_child(copy)
	await get_tree().process_frame
	await get_tree().process_frame
	var tex := ImageTexture.create_from_image(vp.get_texture().get_image())
	vp.queue_free()
	return [tex, pad]


## Puppet Stage: a card the Hammer Hand has hit `hits` times is cut into planks (CardSplit) that stay in place; `thump` plays the blow.
func _split_card(card: SpellCard, hits: int, thump: bool) -> void:
	if not is_instance_valid(card) or card.get_meta("split_level", 0) == hits:
		return
	card.set_meta("split_level", hits)
	var pic: Array = await _card_picture(card)
	if not is_instance_valid(card):
		return
	var old: Node = card.get_meta("split_node") if card.has_meta("split_node") else null  # (get_meta with a null default prints an error in Godot 4)
	if is_instance_valid(old):
		old.queue_free()
	var sp := CardSplit.make(pic[0], pic[1], Vector2(SpellCard.W, SpellCard.H), hits)
	card.add_child(sp)
	card.set_meta("split_node", sp)
	if thump:
		sp.thump()
		Audio.play("sfx_card_hit")


## Puppet Stage: the third blow. The card breaks like a puppet that dies (PuppetShatter): ten planks, but they only fall where they are.
func _break_card_wood(card: SpellCard) -> void:
	var pic: Array = await _card_picture(card)
	var pad: Vector2 = pic[1]
	var tex: Texture2D = pic[0]
	var sc := card.scale
	var rect := Rect2(card.global_position - pad * sc, tex.get_size() * sc)
	card.modulate.a = 0.0
	var old: Node = card.get_meta("split_node") if card.has_meta("split_node") else null  # (get_meta with a null default prints an error in Godot 4)
	if is_instance_valid(old):
		old.queue_free()
	PuppetShatter.spawn_picture(self, tex, rect, card.global_position.y + SpellCard.H * sc.y + 30.0, "sfx_card_break")
	await _wait(1.0)


## A spell card breaks like glass: a picture of it is cut into shards (a Delaunay triangulation, denser around the
## impact) that burst out, tumble and fall, then fade. The sound of breaking glass, then the pieces clinking down.
func _shatter_card(card: SpellCard) -> void:
	var size := Vector2(SpellCard.W, SpellCard.H)
	var pad := Vector2(8, 8)
	var vp := SubViewport.new()
	vp.size = Vector2i(size + pad * 2.0)
	vp.transparent_bg = true
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(vp)
	var copy := SpellCard.make(card.spell)
	copy.is_zoom_copy = true
	copy.cracks = 2
	copy.position = pad
	vp.add_child(copy)
	await get_tree().process_frame
	await get_tree().process_frame
	var tex := ImageTexture.create_from_image(vp.get_texture().get_image())
	vp.queue_free()
	var origin := card.global_position - pad * card.scale
	var sc := card.scale
	card.modulate.a = 0.0
	Audio.play("sfx_glass_break")
	# the cut: corners, edge points, and more points near the impact
	var impact := pad + size * Vector2(randf_range(0.35, 0.65), randf_range(0.35, 0.6))
	var pts := PackedVector2Array([pad, pad + Vector2(size.x, 0), pad + size, pad + Vector2(0, size.y)])
	for i in 6:
		pts.append(pad + Vector2(size.x * randf(), 0))
		pts.append(pad + Vector2(size.x * randf(), size.y))
	for i in 3:
		pts.append(pad + Vector2(0, size.y * randf()))
		pts.append(pad + Vector2(size.x, size.y * randf()))
	for i in 10:
		pts.append(pad + Vector2(randf() * size.x, randf() * size.y))
	for i in 8:
		pts.append(impact + Vector2.from_angle(randf() * TAU) * randf_range(8, 45))
	var tris := Geometry2D.triangulate_delaunay(pts)
	var shards := []
	for t in range(0, tris.size(), 3):
		var a := pts[tris[t]]
		var b := pts[tris[t + 1]]
		var c := pts[tris[t + 2]]
		var mid := (a + b + c) / 3.0
		var poly := Polygon2D.new()
		poly.texture = tex
		poly.polygon = PackedVector2Array([a - mid, b - mid, c - mid])
		poly.uv = PackedVector2Array([a, b, c])
		poly.position = origin + mid * sc
		poly.scale = sc
		poly.z_index = 60
		_fx.add_child(poly)
		var out := (mid - impact).normalized() if mid.distance_to(impact) > 1.0 else Vector2.UP
		shards.append({"n": poly, "p0": poly.position, "v": out * randf_range(90, 260) + Vector2(0, randf_range(-220, -60)),
			"w": randf_range(-9.0, 9.0)})
	var dur := 1.1
	var t0 := Time.get_ticks_msec() / 1000.0
	var clinks := [0.32, 0.5, 0.7]
	while true:
		var t := Time.get_ticks_msec() / 1000.0 - t0
		if not clinks.is_empty() and t >= clinks[0]:
			clinks.pop_front()
			Audio.play("sfx_glass_clank", -4.0, randf_range(0.85, 1.25))
		for sh in shards:
			var n: Polygon2D = sh.n
			n.position = sh.p0 + sh.v * t + Vector2(0, 900.0) * t * t * 0.5
			n.rotation = sh.w * t
			n.modulate.a = clampf((dur - t) / 0.4, 0.0, 1.0)
		if t >= dur:
			break
		await get_tree().process_frame
	for sh in shards:
		sh.n.queue_free()


## Talking to a boss before the fight (BossTalk). Everything but the boss, the backdrop and your bag slides away;
## a box shows what was said and the options (each with the Essence it costs, and a green tick at its right end once
## its whole branch has been explored, in any run). Engage! is always there. Then the fight's UI slides back in.
func _talk() -> void:
	var tree := BossTalk.tree_for(fight.talk_id)
	if tree.is_empty():
		return
	_talking = true
	var old_gate := gate
	gate = func(_a, _b): return false  # (nothing in the fight can be touched while you talk)
	var away := {_player_panel: Vector2(-720, 0), _chant_panel: Vector2(0, 520), _next_panel: Vector2(520, 0),
		_log: Vector2(420, 0), _spell_row: Vector2(0, 640)}
	var homes := {}
	for n in away:
		homes[n] = n.position
		n.position += away[n]
	for v in _views.values():
		v.set_talk(true, 0.0, BossTalk.speaker(tree) if v.enemy.is_boss and not v.enemy.has_passive("hand") else "")
	var box := PanelContainer.new()
	box.add_theme_stylebox_override("panel", UiTheme.panel_box(0.95, 14))
	box.custom_minimum_size = Vector2(1120, 0)
	box.position = Vector2(400, 545)
	box.z_index = 30
	add_child(box)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 8)
	box.add_child(col)
	var node: Dictionary = tree
	var first_meeting := not BossTalk.met_before(fight.talk_id)  # (some narration only comes the very first time)
	BossTalk.meet(fight.talk_id)
	var said := ""
	var prefix := ""  # (something he says before his answer: "You are a master of this element as well, I see.")
	var chosen := [null]
	var given: Array = []  # artifacts you were given while talking: you get them once the talk is over
	while true:
		for c in col.get_children():
			col.remove_child(c)  # (gone right away, so the box measures only what's new)
			c.queue_free()
		# what was said
		var text := RichTextLabel.new()
		text.bbcode_enabled = true
		text.fit_content = true
		text.scroll_active = false
		text.custom_minimum_size = Vector2(1080, 0)
		text.add_theme_font_size_override("normal_font_size", 21)
		text.add_theme_font_size_override("italics_font_size", 21)
		text.add_theme_font_size_override("bold_font_size", 21)
		var lines := []
		if node.has("opening"):
			lines.append("[i][color=#c8bfa8]%s[/color][/i]" % node.opening)
		if node.has("greeting"):
			lines.append("[color=#ffcf7a][b]%s:[/b][/color] \"%s\"" % [BossTalk.speaker(tree), node.greeting])
		if said != "":
			lines.append("[color=#9ec9ff]You:[/color] %s" % said)
		if node.has("first_note") and first_meeting:
			lines.append("[i][color=#c8bfa8]%s[/color][/i]" % node.first_note)
		if node.has("pre"):
			lines.append("[i][color=#c8bfa8]%s[/color][/i]" % node.pre)
		if node.has("reply"):
			lines.append("[color=#ffcf7a][b]%s:[/b][/color] \"%s%s\"%s" % [BossTalk.speaker(tree), prefix, node.reply, (" [i][color=#c8bfa8]%s[/color][/i]" % node.note) if node.has("note") else ""])
		elif node.has("note"):
			lines.append("[i][color=#c8bfa8]%s[/color][/i]" % node.note)
		if node.has("reply2"):
			lines.append("[color=#ffcf7a][b]%s:[/b][/color] \"%s\"%s" % [BossTalk.speaker(tree), node.reply2, (" [i][color=#c8bfa8]%s[/color][/i]" % node.note2) if node.has("note2") else ""])
		text.text = "\n".join(lines)
		col.add_child(text)
		Audio.play_voice(BossTalk.voice_paths(tree, fight.talk_id, node))  # (his recorded line, if there is one)
		if node.has("show"):
			# an artifact he's offering: hover it to read it
			var a := Artifacts.view(String(node.show))
			var chip := TipPanel.new()
			chip.add_theme_stylebox_override("panel", UiTheme.panel_box(0.8, 10))
			chip.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
			chip.tooltip_text = Keywords.tooltip(a.name, a.desc)
			var al := UiTheme.label("%s %s" % [a.icon, a.name], 19, Color(1.0, 0.9, 0.7))
			al.mouse_filter = Control.MOUSE_FILTER_IGNORE
			chip.add_child(al)
			col.add_child(chip)
		# the options (none left after the last level), and Engage!
		var forced: bool = "engage" in node.get("effects", [])
		var seen_ids := BossTalk.seen()
		if not forced:
			for o in node.get("options", []):
				if o.has("requires") and not (o.requires in seen_ids):
					continue  # (it only comes up once you've heard what it refers to)
				col.add_child(_talk_option(o, seen_ids, chosen))
		var go := UiTheme.button("Engage!", func(): chosen[0] = {"engage": true}, 22)
		go.custom_minimum_size = Vector2(1080, 50)
		UiTheme.use_heading_font(go)
		var amber := UiTheme.chant_button_styles()  # (the Chant button's amber face: it stands out from the talk)
		for st in amber:
			go.add_theme_stylebox_override(st, amber[st])
		col.add_child(go)
		if node == tree and Audio.voice_busy():  # his first line: the buttons wait until he has said it (the later ones can be answered at once, which cuts him off)
			var lock: Array = []
			for b in col.find_children("*", "Button", true, false):
				if b == go:
					continue  # (Engage! is never locked: you may cut him off and fight at once)
				lock.append([b, b.disabled])
				b.disabled = true
			_unlock_after_voice(lock)
		await get_tree().process_frame
		box.size = Vector2.ZERO
		box.reset_size()
		box.position.y = minf(545.0, 920.0 - box.size.y)  # (it stays clear of your bag)
		chosen[0] = null
		while chosen[0] == null:  # (a line that ends the talk: only Engage! is left, pressed when you've read it)
			await get_tree().process_frame
		Audio.stop_voice()  # (you answered: he stops)
		if chosen[0].has("engage") or forced:
			break
		# you said it: pay, remember, apply, and on to its answer
		var o: Dictionary = chosen[0]
		if o.cost != "":
			fight.talk_pay(o.cost)
			Audio.play("elem_pickup", -4.0)
		BossTalk.mark_seen(o.id)
		prefix = ""
		for fx in o.get("effects", []):
			var f := String(fx)
			if f.begins_with("artifact:"):
				given.append(f.get_slice(":", 1))  # (handed over when the talk is over, not mid-conversation)
			elif f == "engage":
				pass
			else:
				fight.talk_effect(f)
		said = o.say
		node = o
		_refresh_all()
		for v in _views.values():
			if v.enemy.is_boss and not v.enemy.has_passive("hand"):
				v.set_talk(true, 0.0, BossTalk.speaker(tree))
	# Engage!
	box.queue_free()
	Audio.play("enemy_intent_show")
	var i := 0
	for n in away:
		var back: Tween = (n as Node).create_tween()
		back.tween_interval(i * 0.06)
		back.tween_property(n, "position", homes[n], 0.5).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		i += 1
	for v in _views.values():
		v.set_talk(false, 0.5)
	await _wait(0.6)
	gate = old_gate
	_talking = false
	_refresh_all()
	# what you were given while talking: yours now, at the end of the talk
	for aid in given:
		run.gain_artifact(aid)
		Audio.play("artifact_get")
		Events.toast.emit("Got %s" % Artifacts.view(aid).name, UiTheme.ACCENT)
		if not test_mode and Artifacts.get_def(aid).get("unlock_by", "") != "" and SaveManager.unlock_artifact(aid):
			Events.toast.emit("%s unlocked" % Artifacts.view(aid).name, Color(1, 0.85, 0.4))  # (and in the pool for good)
	if not given.is_empty():
		var old_bar := _arts
		_arts = _make_arts()
		_arts.position = old_bar.position
		_top_layer.add_child(_arts)
		old_bar.queue_free()
		_fit_hud_frames()
		_refresh_all()
	_hypnotize_opening()


## Violet Eyes: as the fight starts its human eyes shine brightly.
func _hypnotize_opening() -> void:
	for v in _views.values():
		if v.enemy.id == "veiled_eyes" and is_instance_valid(v.creature):
			v.creature.hypnotize()
			Audio.play("spell_glow")
			_callout_beside(v, "[i]The beautiful eyes hypnotize you.[/i]", Color(0.75, 0.5, 1.0), 3.2)


func _unlock_after_voice(lock: Array) -> void:
	while Audio.voice_busy() and is_inside_tree():
		await get_tree().process_frame
	for l in lock:
		if is_instance_valid(l[0]):
			l[0].disabled = l[1]


## One thing you can say: its Essence cost on the left, the words, and a green tick at the right end once its whole
## branch has been explored. Greyed out when you don't have the Essence it costs.
func _talk_option(o: Dictionary, seen_ids: Array, chosen: Array) -> Button:
	var b := Button.new()
	b.custom_minimum_size = Vector2(1080, 46)
	b.disabled = not fight.can_talk_pay(o.cost)
	b.pressed.connect(func(): chosen[0] = o)
	var row := HBoxContainer.new()
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	row.offset_left = 14
	row.offset_right = -14
	row.add_theme_constant_override("separation", 10)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(row)
	var cost := HBoxContainer.new()  # (one icon per Essence it costs: "FF" is two Fire)
	cost.add_theme_constant_override("separation", 2)
	for ch in ("" if fight.talk_free else String(o.cost)):  # (test mode: free, so no price shown)
		cost.add_child(ElementIcon.make(ch, 30))
	cost.custom_minimum_size = Vector2(30 * maxi(1, String(o.cost).length()), 30)
	cost.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	cost.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(cost)
	var words := UiTheme.label(String(o.say), 20, Color(0.08, 0.06, 0.04) if not b.disabled else Color(0.45, 0.45, 0.45))  # (dark on the bright green: easy to read)
	words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	words.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	words.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(words)
	var tick := UiTheme.label("✔" if BossTalk.exhausted(o, seen_ids) else "", 24, Color(0.35, 0.9, 0.4))
	tick.custom_minimum_size = Vector2(30, 0)
	tick.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	tick.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	tick.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(tick)
	return b


## An enemy says something: a speech bubble over its head for a moment (the Invoker's Quas / Wex / Exort).
func _speech(e: EnemyState, text: String, hold := 1.0) -> void:
	var v: EnemyView = _views.get(e)
	if v == null or not is_instance_valid(v):
		return
	await _speech_bubble(func(): return v.creature.global_position + Vector2(v.creature.size.x * 0.75, 10.0), text, hold)


## The Handyman, his first two hands down: "Very well." "How about..." "THESE!" from his body, and only then do his
## next two hands burst out of his shoulders, the stage shaking as they unfold.
func _hm_new_hands(ids: Array, lines: Array) -> void:
	_hm_hold = ids.duplicate()
	_sync_views()
	var head := func() -> Vector2:
		if _hm_stage != null and is_instance_valid(_hm_stage):
			var sq := _hm_stage.body_square()
			return _hm_stage.global_position + sq.position + Vector2(sq.size.x * 0.72, sq.size.y * 0.12)
		return Vector2(1060, 160)
	for line in lines:
		await _speech_bubble(head, line, 0.6 + String(line).split(" ").size() / 3.0)
	_hm_hold.clear()
	_sync_views()
	_refresh_all()
	Audio.play("boss_phase_change")
	_shake(16.0)  # (the impact of the arms unfolding)
	await _wait(0.18)
	_shake(12.0)
	await _wait(0.5)


## An enemy's black speech bubble at head_at() (asked once the bubble has its size), held `hold` seconds.
func _speech_bubble(head_at: Callable, text: String, hold := 1.0) -> void:
	var bubble := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.07, 0.06, 0.08, 0.96)  # (enemies speak in black bubbles)
	sb.border_color = Color(0.75, 0.7, 0.85)
	sb.set_border_width_all(3)
	sb.set_corner_radius_all(18)
	sb.content_margin_left = 16
	sb.content_margin_right = 16
	sb.content_margin_top = 6
	sb.content_margin_bottom = 6
	bubble.add_theme_stylebox_override("panel", sb)
	bubble.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bubble.z_index = 90
	var l := UiTheme.label(text, 30, Color(0.96, 0.94, 0.9))
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bubble.add_child(l)
	_fx.add_child(bubble)
	await get_tree().process_frame
	var head: Vector2 = head_at.call()
	bubble.global_position = head - Vector2(0, bubble.size.y)
	bubble.pivot_offset = Vector2(0, bubble.size.y)
	bubble.scale = Vector2(0.3, 0.3)
	var tw := bubble.create_tween()
	tw.tween_property(bubble, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_interval(hold)
	tw.tween_property(bubble, "modulate:a", 0.0, 0.3)
	tw.tween_callback(bubble.queue_free)
	Audio.play("enemy_intent_show")
	await _wait(hold + 0.35)


## The Anxious Armadillo, beaten: he doesn't break. He turns sad and begs; he tries to hop away to the right like a
## doll on its stand (slowly); at 80% of the stage his string tugs him up a little, he says "Oh no.", and it yanks him up
## off the screen. From up there (out of sight) he keeps begging. Then silence, and the usual victory. The player can't
## do anything until it's over.
func _armadillo_ending(e: EnemyState) -> void:
	var v: EnemyView = _views.get(e)
	if v == null or not is_instance_valid(v):
		return
	var block := Control.new()  # (nothing can be clicked meanwhile)
	block.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	block.mouse_filter = Control.MOUSE_FILTER_STOP
	block.z_index = 200
	add_child(block)
	await _wait(0.6)
	# a stand-in we can move freely, exactly where he stands; his own view goes away
	var src := v.creature
	var doll := Creature.new()
	doll.setup(e)
	doll.size = src.size
	doll.z_index = 70
	doll.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(doll)
	doll.global_position = src.global_position
	doll.pivot_offset = Vector2(doll.size.x / 2.0, doll.size.y)
	v.visible = false
	# sad (the sad picture when there is one; a placeholder: a cold, pale tint)
	doll.sad_forever = true
	doll.modulate = Color(0.72, 0.78, 1.0)
	for line in ["Stop, please.", "It hurts.", "I can't take this anymore."]:
		await _dillo_say(_dillo_head(doll), line, 3.0)
	# he tries to get away: little hops to the right, like a bouncing doll, slowly (about 10 s)
	var stage_w := get_viewport_rect().size.x
	var goal := stage_w * 0.8 - doll.size.x / 2.0
	var hops := 20
	var dx := (goal - doll.global_position.x) / hops
	var floor_y := doll.global_position.y
	for k in hops:
		var tw := doll.create_tween()
		tw.set_parallel()
		tw.tween_property(doll, "global_position:x", doll.global_position.x + dx, 0.5)
		tw.tween_property(doll, "rotation", 0.09 if k % 2 == 0 else -0.09, 0.25).set_trans(Tween.TRANS_SINE)
		tw.chain().tween_property(doll, "rotation", 0.0, 0.25).set_trans(Tween.TRANS_SINE)
		var up := doll.create_tween()
		up.tween_property(doll, "global_position:y", floor_y - 20.0, 0.22).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		up.tween_property(doll, "global_position:y", floor_y, 0.28).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		Audio.play("sfx_card_hit", -14.0, randf_range(0.9, 1.15))
		await up.finished
	# his string (it hangs from above the screen to the top of his head)
	var string := Line2D.new()
	string.width = 3.0
	string.default_color = Color(0.92, 0.9, 0.82, 0.9)
	string.z_index = 69
	add_child(string)
	var head := _dillo_head(doll)
	var drop := create_tween()
	drop.tween_method(func(y: float): string.points = PackedVector2Array([Vector2(head.x, -40), Vector2(head.x, y)]), -40.0, head.y, 0.35)
	await drop.finished
	await _wait(0.4)
	# a tug: up about 3 cm, then a pause
	var tug := doll.create_tween()
	tug.tween_property(doll, "global_position:y", floor_y - 110.0, 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	await _dillo_follow(string, doll, tug)
	Audio.play("sfx_card_hit", -6.0, 0.8)
	await _wait(1.0)
	await _dillo_say(_dillo_head(doll), "Oh no.", 1.6)
	await _dillo_say(_dillo_head(doll), "Oh @##%#, @$%@ me, #@%$.", 2.2)  # (swearing, censored)
	await _dillo_say(_dillo_head(doll), "No no no NO!", 1.6)
	# the yank: very fast and violent, right off the top of the screen
	var top_x := _dillo_head(doll).x
	var yank := doll.create_tween().set_parallel()
	yank.tween_property(doll, "global_position:y", -doll.size.y - 400.0, 0.24).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN)
	yank.tween_property(doll, "rotation", randf_range(-0.7, 0.7), 0.24)
	_shake(14.0)
	Audio.play("sfx_card_break", -2.0)
	await _dillo_follow(string, doll, yank)
	string.queue_free()
	doll.visible = false
	# from up there, out of sight, he keeps begging
	var up_there := Vector2(top_x, 20.0)
	for line in [["Please, let me go.", 2.6], ["I won't do it again.", 2.6], ["I swear.", 2.0], ["Please, have some mercy.", 2.8], ["Aaaagrggghrgh!", 2.6]]:
		await _dillo_say(up_there, line[0], line[1], true)
	await _wait(5.0)
	doll.queue_free()
	block.queue_free()


## Where his bubbles start: the top middle of the picture (the painted part when it's a puppet).
func _dillo_head(doll: Creature) -> Vector2:
	var b := doll.puppet_bounds()
	if b.size == Vector2.ZERO:
		b = Rect2(Vector2(doll.size.x * 0.25, doll.size.y * 0.25), Vector2(doll.size.x * 0.5, doll.size.y * 0.6))
	return doll.global_position + Vector2(b.position.x + b.size.x / 2.0, b.position.y)


## The string follows him while a tween moves him.
func _dillo_follow(string: Line2D, doll: Creature, tw: Tween) -> void:
	while tw.is_running():
		var h := _dillo_head(doll)
		string.points = PackedVector2Array([Vector2(h.x, -40), h])
		await get_tree().process_frame


## One of his lines: a black bubble at `at` (its tail corner), held `hold` seconds. `hanging`: it hangs down from there
## (he's above the screen).
func _dillo_say(at: Vector2, text: String, hold: float, hanging := false) -> void:
	var bubble := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.07, 0.06, 0.08, 0.96)
	sb.border_color = Color(0.75, 0.7, 0.85)
	sb.set_border_width_all(3)
	sb.set_corner_radius_all(18)
	sb.content_margin_left = 16
	sb.content_margin_right = 16
	sb.content_margin_top = 6
	sb.content_margin_bottom = 6
	bubble.add_theme_stylebox_override("panel", sb)
	bubble.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bubble.z_index = 210
	var l := UiTheme.label(text, 30, Color(0.96, 0.94, 0.9))
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bubble.add_child(l)
	add_child(bubble)
	await get_tree().process_frame
	var w := bubble.size
	var pos := at + (Vector2(-w.x / 2.0, 0.0) if hanging else Vector2(10.0, -w.y))
	pos.x = clampf(pos.x, 16.0, get_viewport_rect().size.x - w.x - 16.0)
	bubble.global_position = pos
	bubble.pivot_offset = Vector2(w.x / 2.0, 0.0) if hanging else Vector2(0, w.y)
	bubble.scale = Vector2(0.3, 0.3)
	var tw := bubble.create_tween()
	tw.tween_property(bubble, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_interval(maxf(0.2, hold - 0.5))
	tw.tween_property(bubble, "modulate:a", 0.0, 0.3)
	tw.tween_callback(bubble.queue_free)
	Audio.play("enemy_intent_show")
	await _wait(hold)


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


## A callout about one enemy: it stands at the puppet's left, where its intent bubble is (on its right when there is no room), never over the puppet.
func _callout_beside(v: EnemyView, bbcode: String, col: Color, life := 1.0) -> void:
	if v == null or not is_instance_valid(v) or not v.puppet_global_rect().has_area():
		_callout(bbcode, Vector2(960, 600), col, life)
		return
	var p := _callout_panel(bbcode, col)
	await get_tree().process_frame
	if not is_instance_valid(p) or not is_instance_valid(v):
		return
	var r := v.puppet_global_rect()
	var left := r.position.x - 4.0 - p.size.x
	var x := left if left >= 10.0 else r.end.x + 4.0
	p.position = Vector2(clampf(x, 10.0, 1910.0 - p.size.x), clampf(r.get_center().y - p.size.y / 2.0, 10.0, 1070.0 - p.size.y))
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
		if _circus_strips() and ev.eff.get("when", "next") != "now":
			var stash_wait := _stash_flight(ev, from)  # (Cirus: the Essence slips in behind the tube)
			await _wait(stash_wait)
			return
		if _puppet_strips():  # (Puppet Stage: the new Essence leave their source for the top funnel and come out of the port, see _puppet_launch)
			_bonus_from = from
			await _wait(0.1)
			return
		dests = _draw_slots(ev)
	var player := _player_panel.get_global_rect().get_center()
	var wait := SpellFx.play(_fx, op, ev.eff, from, dests, col, player, _shake, _hitstop)
	if wait > 0.0:
		await _wait(wait)


## Gain Essence: one {body, el, px} per Essence gained, at the very slot it will appear in (the end of the
## "Coming next turn" row, or the end of your bag for "now").
func _draw_slots(ev: Dictionary) -> Array:
	var els: Array = ev.get("drawn", [])
	if els.is_empty():  # (no roll was passed along: show the element it names, or a random one)
		var el: String = ev.eff.get("el", "random")
		for i in int(ev.eff.get("n", 1)):
			els.append(["F", "W", "A"].pick_random() if el == "random" else el)
	var now: bool = ev.eff.get("when", "next") == "now"
	var out := []
	for i in els.size():
		var at: Vector2
		var px: float
		if now:
			px = BAG_PX
			var k := fight.player.stock.size() + i
			at = _stock_row.global_position + _bag_slot(k, k + 1) + Vector2(px, px) / 2.0
		else:
			px = 44.0
			var k := fight.player.next_draw.size() + i
			if _circus_strips():
				px = BAG_PX
				at = _stock_row.global_position + _tube_pos(k, k + 1) + Vector2(px, px) / 2.0
			else:
				at = _next_row.global_position + Vector2(k * (px + 4.0), 0) + Vector2(px, px) / 2.0
		out.append({"body": at, "row": at, "el": els[i], "px": px})
	return out


func _area(c: Control) -> Dictionary:
	var r := c.get_global_rect()
	return {"body": r.get_center(), "row": r.get_center(), "rect": r}


## Once an effect has landed: flash whatever it touched and say what changed.
func _effect_landed(ev: Dictionary) -> void:
	var eff: Dictionary = ev.get("eff", {})
	if eff.is_empty():
		return
	if eff.op == "ethereal":  # it flickers out of step with the world, half there
		for e in ev.targets:
			var ev_view: EnemyView = _views.get(e)
			if ev_view:
				var tw := ev_view.creature.create_tween()
				for a in [0.25, 0.8, 0.15, 0.7, 0.35, 1.0]:
					tw.tween_property(ev_view.creature, "modulate:a", a, 0.07)
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
		_float_text(text, _player_point() + Vector2(-40, -40), Color(0.6, 0.9, 1))


## The Samurai has fallen: his Retainer says so, kneels, and leaves the stage.
func _retainer_yields(r: EnemyState) -> void:
	await _speech(r, "I yield.", 1.6)
	var v: EnemyView = _views.get(r)
	if v != null and is_instance_valid(v):
		var tw := v.create_tween().set_parallel()
		tw.tween_property(v, "position:y", v.position.y + 40.0, 0.6).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
		tw.tween_property(v, "modulate:a", 0.0, 0.6)
		await tw.finished


## The Veiled Eyes' laser: a violet beam from its eyes to you (the hit lands right after).
func _eye_laser(e: EnemyState) -> void:
	var v: EnemyView = _views.get(e)
	if v == null or not is_instance_valid(v.creature):
		return
	var cr := v.creature
	var from := cr.global_position + Vector2(cr.size.x * 0.5, cr.size.y * (0.5 if e.phase < 2 else 0.4))
	if cr._puppet:
		from = cr.veil_eyes_point()  # (its purple eyes are at the same height in both phases)
	var to := _attack_point()
	Audio.play("spell_glow")
	var fx := Vfx.make(_fx, 80)
	fx.shaker = _shake
	for k in 2:  # (soft beams, like the glow of its eyes)
		var gap := Vector2(-22.0 if k == 0 else 22.0, 0)
		var beam := SoftBeam.new()
		beam.a = from + gap - _fx.global_position
		beam.b = to - _fx.global_position
		beam.color = Color(0.7, 0.35, 1.0)
		beam.width = 9.0
		beam.life = 0.42
		_fx.add_child(beam)
	fx.glow(from, 90, Color(0.75, 0.4, 1.0, 0.9), 0.35)
	fx.glow(to, 120, Color(0.75, 0.4, 1.0, 0.8), 0.3, 0.1)
	fx.shake(6.0, 0.1)
	await _wait(0.22)


## The theft: it is pulled up out of sight, drops on its thread right in front of you, picks one of your spells
## up, is pulled up again with it, and comes back down to its place (the cocoon appears next).
func _spider_steal(e: EnemyState, sp: Dictionary) -> void:
	var v: EnemyView = _views.get(e)
	var card := _card_for(sp.id)
	if v == null or not is_instance_valid(v.creature):
		return
	var cr := v.creature
	while is_instance_valid(cr) and cr.unveiling():  # (it is still coming out of its veil: the theft comes after)
		await get_tree().process_frame
	if not is_instance_valid(cr):
		return
	var z := cr.z_index
	var slow := SPIDER_SLOW
	cr.z_index = 120
	Audio.play("elem_pickup")
	var up := cr.create_tween()
	up.tween_property(cr, "global_position:y", -cr.size.y - 40.0, 0.35 * slow).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	await up.finished
	var grab := Vector2(960, 700)
	if card:
		grab = card.global_position + Vector2(card.size.x * card.scale.x / 2.0, 0)
	cr.global_position = Vector2(grab.x - cr.size.x / 2.0, -cr.size.y - 40.0)
	var down := cr.create_tween()
	down.tween_property(cr, "global_position:y", grab.y - cr.size.y * 0.85, 0.4 * slow).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	await down.finished
	cr.hit(0.4)  # (it snatches)
	# it changes its stance (the legs fold in and down) and the card is taken into them, in front of its fangs
	var pose := cr.create_tween().set_parallel()
	pose.tween_property(cr, "steal_pose", 1.0, 0.3 * slow).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	var ghost: SpellCard = null
	if card:
		ghost = SpellCard.make(sp)
		ghost.mouse_filter = Control.MOUSE_FILTER_IGNORE
		ghost.z_index = 119  # (behind the spider: its legs are over the card's edges)
		_fx.add_child(ghost)
		ghost.global_position = card.global_position
		ghost.scale = card.scale
		card.modulate.a = 0.0
		var spot: Array = cr.steal_card_spot()
		var want := float(spot[1]) / maxf(1.0, ghost.size.x)
		pose.tween_property(ghost, "global_position", spot[0], 0.3 * slow).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		pose.tween_property(ghost, "scale", Vector2(want, want), 0.3 * slow).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	Audio.play("elem_remove")
	await pose.finished
	await _wait(0.2 * slow)
	# it is pulled up with the card
	var off := cr.create_tween().set_parallel()
	var lift: float = (-cr.size.y - 300.0) - cr.global_position.y
	off.tween_property(cr, "global_position:y", -cr.size.y - 300.0, 0.45 * slow).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	if ghost:
		off.tween_property(ghost, "global_position:y", ghost.global_position.y + lift, 0.45 * slow).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)  # (the card rides up with it)
	await off.finished
	if ghost:
		ghost.queue_free()
	cr.steal_pose = 0.0
	cr.z_index = z
	_spider_away = e  # (it stays up there: the cocoon is let down first, then the spider comes back, see _spider_return)
	# up there, out of sight, it rolls the card into a cocoon: the rolling sound plays right through, and only then is the cocoon let down
	Audio.play("sfx_cocoon_roll")
	await _wait(maxf(1.0, Audio.get_sfx_length("sfx_cocoon_roll")))


## How much slower the spiders and their cocoons move than the rest (their durations are multiplied by this): half the speed.
const SPIDER_SLOW := 2.0
var _spider_away: EnemyState  # the Veiled Eyes, pulled up with a stolen spell and waiting up there for the cocoon to be let down


func _slow_of(e: EnemyState) -> float:
	return SPIDER_SLOW if e != null and (e.id == "veiled_eyes" or e.id.begins_with("spiderling") or e.id == "spider_cocoon") else 1.0


## The puppet of a view lifted by `off` px (0 = standing; ENEMY_UP = up in the ropes, out of sight). It moves the Creature's own edges, so the row's layout leaves it alone.
func _lift_creature(cr: Creature, off: float) -> void:
	if not cr.has_meta("base_edges"):
		cr.set_meta("base_edges", Vector2(cr.offset_top, cr.offset_bottom))
	var base: Vector2 = cr.get_meta("base_edges")
	cr.offset_top = base.x + off
	cr.offset_bottom = base.y + off


## A rebuilt view of the spider that is up in the ropes: out of sight, high above its place (it is let down by _spider_return).
func _hold_spider_up(v: EnemyView) -> void:
	v.modulate.a = 0.0
	_lift_creature(v.creature, ENEMY_UP)


## A puppet that arrives in the middle of a fight (the Silk Cocoon) is let down from above on its rope: a fall, then a few bobs. At the spiders' slow speed.
func _drop_view_in(v: EnemyView) -> void:
	if not is_instance_valid(v) or not is_instance_valid(v.creature):
		return
	var slow := _slow_of(v.enemy)
	var cr := v.creature
	_lift_creature(cr, ENEMY_UP)
	v.modulate.a = 1.0
	var tw := create_tween()
	tw.tween_method(func(t: float):
		if not is_instance_valid(cr):
			return
		var off := 0.0
		if t < ENEMY_LET_DOWN:
			var u := t / ENEMY_LET_DOWN
			off = ENEMY_UP * (1.0 - u * u)
		else:
			var sec := t - ENEMY_LET_DOWN
			off = 20.0 * exp(-4.5 * sec) * sin(TAU * 1.8 * sec)
		_lift_creature(cr, off), 0.0, ENEMY_LET_DOWN + ENEMY_SPRING, (ENEMY_LET_DOWN + ENEMY_SPRING) * slow)
	await tw.finished
	if is_instance_valid(cr):
		_lift_creature(cr, 0.0)


## The spider comes back down to its place after the cocoon has been let down.
func _spider_return(e: EnemyState) -> void:
	if e != _spider_away:
		return  # (it has come back already: the cocoon's drop called for it)
	_spider_away = null
	var v: EnemyView = _views.get(e)
	if v == null or not is_instance_valid(v.creature):
		return
	var cr := v.creature
	_lift_creature(cr, ENEMY_UP)
	v.modulate.a = 1.0
	var back := create_tween()
	back.tween_method(func(o: float):
		if is_instance_valid(cr):
			_lift_creature(cr, o), ENEMY_UP * 0.4, 0.0, 0.45 * SPIDER_SLOW).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	await back.finished
	if is_instance_valid(cr):
		_lift_creature(cr, 0.0)


## Mend: a ball of light flies from the enemy that mends to each new Essence (in its own or an ally's row), the same comet as
## a spell's "gain Essence next turn"; each new Essence appears as its ball lands.
func _mend_light(caster: EnemyState, gains: Array) -> void:
	var cv: EnemyView = _views.get(caster)
	if cv == null or not is_instance_valid(cv.creature):
		await _wait(0.2)
		return
	await get_tree().process_frame  # (the rows were just rebuilt: let them lay out first)
	var from := cv.creature.get_global_rect().get_center()
	var dests := []
	var i := 0
	for g in gains:
		var tv: EnemyView = _views.get(g.enemy)
		if tv == null or int(g.index) >= tv._hp_icons.size():
			continue
		var icon: Control = tv._hp_icons[int(g.index)]
		var at := tv.hp_point(int(g.index))
		dests.append({"body": at, "row": at, "el": g.el, "px": icon.size.x, "ghost": false})
		icon.modulate.a = 0.0  # (it shows when its ball lands)
		var tw := icon.create_tween()
		tw.tween_interval(i * 0.13 + 0.62)
		tw.tween_property(icon, "modulate:a", 1.0, 0.25)
		i += 1
	if dests.is_empty():
		await _wait(0.2)
		return
	var dur := SpellFx.play(_fx, "draw", {"op": "draw", "n": dests.size()}, from, dests, Color.WHITE, Vector2.ZERO, _shake, _hitstop)
	await _wait(maxf(dur, 0.62 + dests.size() * 0.13 + 0.25))


## How many different enemies a spell picks: 2 for "2 different enemies" (Glacial Spike), else 1. With no more enemies
## than that, it just hits them all: no aiming.
func _max_picks(spell: Dictionary) -> int:
	return 2 if spell.get("effects", []).any(func(e): return e.get("target", "") == "two") else 1


## Where what lands on you lands: the middle of the HP tray (Puppet), the Keeper's panel otherwise.
func _player_point() -> Vector2:
	if _puppet_hud:
		return _player_panel.get_global_rect().get_center()
	return _player_panel.global_position + Vector2(240, 50)


## Where the enemies' attacks land: the middle of your Chant bar (they used to go for the HP bar; the HP still drops, and its bar still cracks on a block).
func _attack_point() -> Vector2:
	if is_instance_valid(_chant_panel) and _chant_panel.is_inside_tree():
		return _chant_panel.get_global_rect().get_center()
	return _player_point()


func _effect_words(e: Dictionary) -> String:
	var n: int = int(e.get("n", 0))
	match e.op:
		"strike", "pluck", "purge", "siphon":
			return "-%d" % n
		"steal":
			return ""
		"burn":
			return "Burn %d" % n
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
			return "+Evasion"
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
	var target := _attack_point()
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
	elif v and v.creature.has_rig() and ev.enemy.id == "hand_spear":
		target = await _spear_stab(v, float(ev.n))  # (the spear thrusts up into your HP bar: the hit lands there)
	elif v and v.creature.has_rig() and ev.enemy.id == "hand_sword":
		target = await _sword_slash(v, float(ev.n))  # (the blade cuts across your HP bar: the hit lands there)
	elif v and v.creature.has_rig() and ev.enemy.id == "hand_crossbow" and _arrow_tex() != null:
		target = await _arrow_shot(v, float(ev.n))  # (the bolt flies up and sticks in your HP bar: the hit lands there)
	elif v and v.creature.has_rig():
		# a Handyman hand: the arm winds back and swings down at you (about its shoulder and its elbow)
		_arm_swing(v.creature, 1.0)
		await _wait(0.23)
	elif v:
		var c := v.creature
		var home := c.position
		var toward := (target - (c.global_position + c.size / 2.0)).normalized() * 70.0
		c.pivot_offset = c.size / 2.0
		var sl := _slow_of(ev.enemy)  # (the spiders move at half speed)
		var tw := c.create_tween()
		tw.tween_property(c, "position", home - toward * 0.3, 0.12 * sl)  # wind up
		tw.parallel().tween_property(c, "scale", Vector2(0.92, 0.92), 0.12 * sl)
		tw.tween_property(c, "position", home + toward, 0.09 * sl)  # lunge
		tw.parallel().tween_property(c, "scale", Vector2(1.3, 1.3), 0.09 * sl)
		tw.tween_interval(0.12 * sl)
		tw.tween_property(c, "position", home, 0.2 * sl)
		tw.parallel().tween_property(c, "scale", Vector2.ONE, 0.2 * sl)
		await _wait(0.2 * sl)
	var blocked: bool = ev.get("blocked", false)
	ImpactFx.burst(_fx, target, blocked and ev.n == 0)
	Audio.play("sfx_player_hit" if ev.n > 0 else "release_armour_block")
	if blocked:
		_hp_bar.crack()
	# bigger hits feel bigger: more shake, a red flash, and a moment's hit-stop on heavy blows
	var hurt: float = float(ev.n) / maxf(1.0, fight.player.max_hp)
	_shake(clampf(7.0 + ev.n * 0.9, 7.0, 30.0) if ev.n > 0 else 5.0)
	if ev.n > 0:
		_danger.flash(0.35 + hurt * 3.0)
		if ev.n >= 10:
			_hitstop(0.05 + minf(ev.n, 40) / 500.0)
	if ev.n > 0:
		_float_text("-%d" % ev.n, target + Vector2(-20, -70), UiTheme.DANGER)
		var tw2 := _player_panel.create_tween()
		tw2.tween_property(_player_panel, "modulate", Color(1.6, 0.6, 0.6), 0.08)
		tw2.tween_property(_player_panel, "modulate", Color.WHITE, 0.3)
	else:
		_float_text("Blocked!", target + Vector2(-40, -70), Color(0.6, 0.85, 1))
	_refresh_all()
	await _wait(0.6)


## The Sword Hand strikes: its arm reaches up over the screen to your HP bar, the blade held back at one side, then cuts across the part of the bar the
## hit takes away. Returns the point the blade lands on (the caller plays the impact and the damage there).
func _sword_slash(v: EnemyView, dmg: float) -> Vector2:
	var cr: Creature = v.creature
	var target := _hp_bar.get_global_rect().get_center() + Vector2(-20.0, 0.0)  # (the whole bar, not the part this hit took: that part moves with your HP, and so would the cut; 20 px to the left of the middle)
	cr.tip_z = PuppetStage.CEILING_Z + 3
	cr.poke_target = target + Vector2(-110.0, -45.0)  # (wound up: above and behind the bar)
	var reach := create_tween()
	reach.tween_property(cr, "poke", 1.0, 0.4).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	await reach.finished
	await _wait(0.15)
	var cut := create_tween()  # (the cut: fast, down and across the bar)
	cut.tween_property(cr, "poke_target", target + Vector2(110.0, 25.0), 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	await cut.finished
	_hammer_retreat(cr)
	return target


const ARROW_LEN := 210.0  # px on the screen (the picture is 420 long, head on the left)
const ARROW_STAY := 1.0  # seconds it stays stuck in the HP bar


func _arrow_tex() -> Texture2D:
	var path := Creature.enemy_path("handyman/arrow.png", 1)
	return load(path) as Texture2D if path != "" else null


## Where the bolt sticks in the HP bar: the middle of the part the hit has just taken away (HP is already down when the attack plays).
func _arrow_target(dmg: float) -> Vector2:
	var mx := maxf(1.0, fight.player.max_hp)
	var frac := clampf((clampf(fight.player.hp, 0.0, mx) + dmg * 0.5) / mx, 0.03, 0.97)
	if _hp_bar is StripeHpBar:
		return _hp_bar.point_at(frac)  # (the bar's window starts after the ring)
	var r := _hp_bar.get_global_rect()
	return Vector2(r.position.x + r.size.x * frac, r.position.y + r.size.y * 0.5)


## The Crossbow Hand fires: the bolt lies on the bow; the whole hand (arm, hand and bow) turns together with the bolt until it points at your HP bar, aims
## there for a second, then the bolt flies and sticks in the bar; a second later it is gone. Returns the point it hit (the caller plays the impact there).
const ARROW_NOCK := 70.0  # px from the hand along the bow: where the bolt lies
func _arrow_shot(v: EnemyView, dmg: float) -> Vector2:
	var tex := _arrow_tex()
	var cr: Creature = v.creature
	var sc := ARROW_LEN / float(tex.get_width())
	var arrow := Sprite2D.new()
	arrow.texture = tex
	arrow.z_as_relative = false
	arrow.z_index = 300
	arrow.modulate.a = 0.0
	var hand := cr.hand_global()
	var bow := float(Creature.AIM_BOW["hand_crossbow"])
	var rest_dir := float(cr._rig.theta2) + bow  # (where the bow points while it idles)
	var target := _arrow_target(dmg)
	var aim_dir := (target - hand).angle()
	arrow.global_position = hand + Vector2.from_angle(rest_dir) * ARROW_NOCK
	arrow.rotation = rest_dir + PI  # (the head is on the left of the picture)
	arrow.scale = Vector2(sc, sc) * 0.8
	add_child(arrow)
	var tw := arrow.create_tween()
	tw.tween_property(arrow, "modulate:a", 1.0, 0.2)
	tw.parallel().tween_property(arrow, "scale", Vector2(sc, sc), 0.2)
	await _wait(0.3)  # (it lies on the bow a moment)
	var fin := [rest_dir]  # (the direction the bolt ends up pointing in)
	var turn := create_tween()  # (arm, hand, bow and bolt turn as one, then hold the aim for a second, trembling a little)
	turn.tween_method(func(u: float) -> void:
		if not is_instance_valid(cr) or not is_instance_valid(arrow):
			return
		var k := smoothstep(0.0, 0.35, u)  # (0.35 s of turning, then the hold)
		cr.aim_dir = (target - cr.hand_global()).angle()  # (the hand moves as the arm turns: aim from where it is now)
		cr.aim = k
		var d := lerp_angle(rest_dir, cr.aim_dir, k) + (sin(u * 60.0) * 0.015 if u > 0.4 else 0.0)
		fin[0] = d
		arrow.global_position = cr.hand_global() + Vector2.from_angle(d) * ARROW_NOCK
		arrow.rotation = d + PI, 0.0, 1.35, 1.35)
	await _wait(1.35)
	aim_dir = cr.aim_dir
	var aim_rot: float = float(fin[0]) + PI
	var dir := Vector2.from_angle(aim_dir)
	var stuck := target + dir * 12.0 - dir * ARROW_LEN * 0.5  # (the head goes in a little past the surface)
	var from := arrow.global_position
	_arm_swing(cr, 0.4)  # (the bow kicks)
	var fly := arrow.create_tween()
	fly.tween_property(arrow, "global_position", from + (stuck - from), 0.3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	await _wait(0.3)
	var wob := arrow.create_tween()  # (it shudders in the wood)
	wob.tween_property(arrow, "rotation", aim_rot + 0.07, 0.05)
	wob.tween_property(arrow, "rotation", aim_rot - 0.05, 0.07)
	wob.tween_property(arrow, "rotation", aim_rot, 0.08)
	var gone := arrow.create_tween()
	gone.tween_interval(ARROW_STAY)
	gone.tween_property(arrow, "modulate:a", 0.0, 0.25)
	gone.tween_callback(arrow.queue_free)
	_aim_release(cr)
	return target


## The bow comes back from its aim.
func _aim_release(cr: Creature) -> void:
	await _wait(0.4)
	if not is_instance_valid(cr):
		return
	var back := create_tween()
	back.tween_property(cr, "aim", 0.0, 0.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await back.finished
	if is_instance_valid(cr):
		cr.aim = 0.0
		cr.aim_dir = INF


## The Spear Hand strikes: the spear reaches up below your HP bar, then thrusts up into the part of the bar the hit takes away.
func _spear_stab(v: EnemyView, dmg: float) -> Vector2:
	var cr: Creature = v.creature
	var target := _hp_bar.get_global_rect().get_center()
	cr.tip_z = PuppetStage.CEILING_Z + 3
	var turn := create_tween()  # (the arm turns until the point of the spear aims straight at the bar)
	turn.tween_method(func(u: float) -> void:
		if is_instance_valid(cr):
			cr.aim_dir = (target - (cr.hand_global() - cr.lunge)).angle()
			cr.aim = smoothstep(0.0, 1.0, u), 0.0, 1.0, 0.5)
	await turn.finished
	var dist := (target - (cr.hand_global() - cr.lunge)).length()
	var dir := Vector2.from_angle(cr.aim_dir)
	var far := maxf(0.0, dist - SPEAR_TIP_LEN + 15.0)  # (until the point is a little way in)
	var back := create_tween()  # (pulls back a little)
	back.tween_property(cr, "lunge", -dir * 40.0, 0.25).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	await back.finished
	await _wait(0.15)
	var stab := create_tween()  # (the thrust: fast, straight along the spear)
	stab.tween_property(cr, "lunge", dir * far, 0.1).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	await stab.finished
	_spear_back(cr)
	return target


const SPEAR_TIP_LEN := 232.0  # px from the Spear Hand's hand to the point of its spear


func _spear_back(cr: Creature) -> void:
	await _wait(0.5)
	if not is_instance_valid(cr):
		return
	var back := create_tween().set_parallel()
	back.tween_property(cr, "lunge", Vector2.ZERO, 0.4).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	back.tween_property(cr, "aim", 0.0, 0.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await back.finished
	if is_instance_valid(cr):
		cr.aim = 0.0
		cr.aim_dir = INF
		cr.tip_z = 0


## A Handyman hand that is down for good breaks like the other puppets. Its arm is not one picture, so the arm is drawn once, as it stands,
## into a picture of its own first (a SubViewport, like the spell cards that shatter), and that picture is broken into pieces.
func _shatter_arm(c: Creature) -> void:
	if not c.is_inside_tree() or c._enemy == null:
		return
	var vp_size := Vector2i(1500, 1000)
	var mid := c.global_position + c.size / 2.0  # (the hand marker)
	var enemy: EnemyState = c._enemy
	var reach := c.reach
	var reach_angle := c.reach_angle
	var csize := c.size
	var vp := SubViewport.new()
	vp.size = vp_size
	vp.transparent_bg = true
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(vp)
	var copy := Creature.new()
	copy.setup(enemy)
	copy.size = csize
	copy.reach = reach
	copy.reach_angle = reach_angle
	copy.position = Vector2(vp_size) / 2.0 - csize / 2.0
	vp.add_child(copy)
	await get_tree().process_frame
	await get_tree().process_frame
	var tex := ImageTexture.create_from_image(vp.get_texture().get_image())
	vp.queue_free()
	PuppetShatter.spawn_picture(self, tex, Rect2(mid - Vector2(vp_size) / 2.0, Vector2(vp_size)), mid.y + 90.0)


## A Handyman hand's swing: it winds up (a little the other way), strikes, holds a moment and settles back. `power` 1 is a full blow.
func _arm_swing(c: Creature, power: float) -> void:
	var tw := c.create_tween()
	tw.tween_property(c, "swing", -0.4 * power, 0.14).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.tween_property(c, "swing", power, 0.09).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_interval(0.14)
	tw.tween_property(c, "swing", 0.0, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## An enemy steals Essence from your bag (the Tweezer Hand): its arm pinches, the stolen Essence lift out of the bag one after another (a pick-up
## sound), fly over to the thief and drop onto its row of Essence (a clack), and a line says what was taken.
func _steal_fx(ev: Dictionary, v: EnemyView) -> void:
	var items: Array = ev.get("items", [])
	var thief := ev.enemy.name as String
	var to := (v.creature.global_position + v.creature.size / 2.0) if v else Vector2(960, 300)
	if v and v.creature.has_rig() and Creature.POKE_TIP.has(ev.enemy.id) and not items.is_empty():
		await _steal_poke(ev, v, items)  # (the Tweezer Hand reaches into the bag for each Essence)
		return
	if v and v.creature.has_rig() and Creature.POKE_TIP.has(ev.enemy.id) and items.is_empty():
		await _steal_nothing(thief, v)  # (the Tweezer Hand grabs at the empty bag three times)
		return
	if v and v.creature.has_rig():
		_arm_swing(v.creature, 0.6)
	if items.is_empty():
		_float_text("%s finds nothing to steal" % thief, _stock_row.global_position + Vector2(300, -30), Color(0.8, 0.8, 0.85))
		await _wait(0.6)
		_sync_views()
		_refresh_all()
		return
	await _wait(0.22)
	var names: Array = []
	for k in items.size():
		var it: Dictionary = items[k]
		names.append(Elements.NAMES.get(it.el, it.el))
		var from := _bag_center(it.uid)
		var bag_icon: Control = _bag_icons.get(it.uid)
		if bag_icon != null and is_instance_valid(bag_icon):
			bag_icon.modulate.a = 0.0  # (it has left the bag)
		_steal_orb(String(it.el), from, to, k * 0.2, v)
	_float_text("%s steals %s" % [thief, ", ".join(names)], _stock_row.global_position + Vector2(260, -40), Color(1, 0.55, 0.45))
	await _wait(0.2 * items.size() + 0.75)
	_sync_views()
	_refresh_all()


## The bag is empty: the Tweezer Hand reaches down into it and snaps at three different places, comes up with nothing, the Handyman's face cries, a line says
## so, and the arm goes back.
func _steal_nothing(thief: String, v: EnemyView) -> void:
	var cr: Creature = v.creature
	cr.tip_z = PuppetStage.CEILING_Z + 3
	var base := _stock_row.global_position
	var spots := [Vector2(140.0, 34.0), Vector2(380.0, 34.0), Vector2(260.0, 34.0)]
	for k in spots.size():
		if not is_instance_valid(cr):
			return
		cr.poke_target = base + spots[k]
		var reach := create_tween()
		reach.tween_property(cr, "poke", 1.0, 0.35 if k == 0 else 0.22).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		await reach.finished
		Audio.play("sfx_steal_miss" if Audio.has_sfx("sfx_steal_miss") else "elem_pickup", 0.0, randf_range(0.97, 1.03))  # (the tweezers snap shut on nothing: fx_evasion_2, once per grab)
		await _wait(0.2)
		if k < spots.size() - 1:
			var lift := create_tween()  # (up a little, and over to the next place)
			lift.tween_property(cr, "poke", 0.55, 0.16).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
			await lift.finished
	if is_instance_valid(cr):
		get_tree().call_group("handyman_body", "cry", 2.0)
	_float_text("%s finds nothing to steal" % thief, base + Vector2(300, -30), Color(0.8, 0.8, 0.85))
	await _wait(0.9)
	if is_instance_valid(cr):
		var back := create_tween()
		back.tween_property(cr, "poke", 0.0, 0.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		await back.finished
	if is_instance_valid(cr):
		cr.poke = 0.0
		cr.tip_z = 0
	_sync_views()
	_refresh_all()


## The Tweezer Hand steals: for every Essence the arm reaches out over the screen (over the chant, the bag...) and its tweezers close on that very Essence,
## the Essence comes away with the tip as the arm pulls back, and is dropped onto the thief's row.
func _steal_poke(ev: Dictionary, v: EnemyView, items: Array) -> void:
	var cr: Creature = v.creature
	var thief := ev.enemy.name as String
	cr.tip_z = PuppetStage.CEILING_Z + 3  # (the tweezers go over the HUD: only the lower stick, the upper one stays under the Handyman's body)
	var names: Array = items.map(func(it): return Elements.NAMES.get(it.el, it.el))
	_float_text("%s steals %s" % [thief, ", ".join(names)], _stock_row.global_position + Vector2(260, -40), Color(1, 0.55, 0.45))
	await _wait(0.12)
	# the stolen Essence already sit in the thief's row (the fight did that): show the row as it will be, the new ones still invisible, each shows up
	# when its Essence arrives
	var old_n: int = ev.enemy.elements.size() - items.size()
	v.refresh({})
	for j in range(old_n, old_n + items.size()):
		if j >= 0 and j < v._hp_icons.size():
			v._hp_icons[j].modulate.a = 0.0
	for k in items.size():
		var it: Dictionary = items[k]
		if not is_instance_valid(cr):
			break
		var from := _bag_center(it.uid)
		cr.poke_target = from
		var reach := create_tween()
		reach.tween_property(cr, "poke", 1.0, 0.3).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		await reach.finished
		if not is_instance_valid(cr):
			break
		# the tweezers close on it: it leaves the bag and hangs on the tip
		var bag_icon: Control = _bag_icons.get(it.uid)
		if bag_icon != null and is_instance_valid(bag_icon):
			bag_icon.modulate.a = 0.0
		Audio.play("sfx_steal" if UiSkin.is_puppet() else "elem_pickup", -3.0, randf_range(0.95, 1.05))
		var ic := ElementIcon.make(String(it.el), BAG_PX)
		ic.size = Vector2(BAG_PX, BAG_PX)
		ic.pivot_offset = ic.size / 2.0
		ic.z_index = PuppetStage.CEILING_Z + 5
		ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_fx.add_child(ic)
		ic.position = from - _fx.global_position - ic.size / 2.0
		await _wait(0.08)
		# the arm pulls back; the Essence rides on the tip first, then slides on to its place in the thief's row, arriving as the arm settles
		var slot := old_n + k
		var ratio := 0.6
		if slot >= 0 and slot < v._hp_icons.size() and is_instance_valid(v._hp_icons[slot]):
			ratio = float(v._hp_icons[slot].size.x) / BAG_PX
		var back := create_tween()
		back.tween_property(cr, "poke", 0.0, 0.55).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		back.parallel().tween_method(func(u: float) -> void:
			if is_instance_valid(ic) and is_instance_valid(cr):
				var w := smoothstep(0.3, 1.0, u)
				ic.position = cr.tool_tip().lerp(v.hp_point(slot), w) - _fx.global_position - ic.size / 2.0
				ic.scale = Vector2.ONE * lerpf(1.0, ratio, w), 0.0, 1.0, 0.55)
		await back.finished
		if is_instance_valid(ic):
			ic.queue_free()
		if slot >= 0 and slot < v._hp_icons.size() and is_instance_valid(v._hp_icons[slot]):
			v._hp_icons[slot].modulate.a = 1.0  # (it takes its place)
		if is_instance_valid(cr):
			cr.flash = 0.7
	if is_instance_valid(cr):
		cr.poke = 0.0
	if is_instance_valid(cr):
		cr.tip_z = 0
	_sync_views()
	_refresh_all()


## One stolen Essence: pops out of the bag, flies in an arc to `to` and lands on the thief (which flashes).
func _steal_orb(el: String, from: Vector2, to: Vector2, delay: float, v: EnemyView) -> void:
	var ic := ElementIcon.make(el, BAG_PX)
	ic.size = Vector2(BAG_PX, BAG_PX)
	ic.pivot_offset = ic.size / 2.0
	ic.z_index = 60
	ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ic.modulate = Color(1.5, 1.4, 1.3, 0.0)
	_fx.add_child(ic)
	ic.position = from - _fx.global_position - ic.size / 2.0
	var mid := (from + to) / 2.0 + Vector2(0, -120.0)
	var tw := create_tween()
	tw.tween_interval(delay)
	tw.tween_callback(func():
		Audio.play("sfx_steal" if UiSkin.is_puppet() else "elem_pickup", -3.0, randf_range(0.95, 1.05))
		if is_instance_valid(ic):
			ic.modulate.a = 1.0)
	tw.tween_method(func(t: float) -> void:
		if is_instance_valid(ic):
			var pt := from.lerp(mid, t).lerp(mid.lerp(to, t), t)
			ic.position = pt - _fx.global_position - ic.size / 2.0
			ic.rotation = -t * TAU
			ic.scale = Vector2.ONE * lerpf(1.0, 0.7, t), 0.0, 1.0, 0.6).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_callback(func():
		if not UiSkin.is_puppet():
			Audio.play("sfx_ball_clack", -4.0, randf_range(0.95, 1.1))
		if is_instance_valid(ic):
			ic.queue_free()
		if v != null and is_instance_valid(v):
			v.creature.flash = 0.7)


## Anything else an enemy does: debuffs fly at you, buffs glow on the enemy.
func _enemy_move_fx(ev: Dictionary) -> void:
	var v: EnemyView = _views.get(ev.enemy)
	var kind: String = ev.kind
	if kind in ["freeze", "hex", "invert", "steal", "drain_essence"]:
		await _rolls_done()  # (it lands on your Essence: wait until they have stopped rolling)
	if kind == "steal":
		await _steal_fx(ev, v)
		return
	if String(ev.get("move", {}).get("sfx", "")) == "gong":
		Audio.play("gong", -2.0)
	var look: Array = IntentChip.LOOK.get(kind, ["✦", Color.WHITE])
	var info: Array = IntentChip.INFO.get(kind, [kind.capitalize(), ""])
	if v and v.creature.has_rig():  # (a Handyman hand: its arm acts it out, a little gentler than a blow)
		_arm_swing(v.creature, 0.6)
		await _wait(0.23)
	if kind in Fight.AT_PLAYER and v:
		var from := v.creature.global_position + v.creature.size / 2.0
		var to := _attack_point()
		var comet := Comet.launch(_fx, from, to, (look[1] as Color).lightened(0.3))
		comet.rise = 60.0
		await _wait(0.45)
		_shake(4.0)
	elif v and v.creature.has_rig():
		v.creature.flash = 0.7  # (a hand of the Handyman that charges or buffs only glows: hit_flash would make it blink and his face cry as if it had been struck)
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


var _stop_until := 0  # (ticks msec) when the current hit-stop ends
var _stop_id := 0  # the latest hit-stop: only its own timer may end it

## Hit-stop: the game all but freezes for `sec` on a heavy impact. Overlapping stops don't add up: the later end wins.
func _hitstop(sec: float) -> void:
	if not is_inside_tree():
		return
	var until := Time.get_ticks_msec() + int(sec * 1000.0)
	if until <= _stop_until:
		return
	_stop_until = until
	_stop_id += 1
	Engine.time_scale = 0.02  # (not 0: nothing ever divides by a zero frame time)
	get_tree().create_timer(sec, true, false, true).timeout.connect(_end_hitstop.bind(_stop_id))


func _end_hitstop(id: int) -> void:
	if id == _stop_id:
		Engine.time_scale = 1.0


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
		if h.size() > 2 and h[2]:
			_deflect_comet(from, v.hp_point(h[1]), col)
			continue
		var comet := Comet.launch(_fx, from, v.hp_point(h[1]), col)
		var j: int = h[1]
		comet.arrived.connect(func():
			if is_instance_valid(v): v.pop(j)
			Audio.play(impact))
	await _wait(0.46)


## The Samurai's Deflect: the chant Essence flies at its target as usual, but an air slash (a pale crescent) flies out
## of his sword and meets it on the way: a clang, sparks, a tiny freeze and shake, and the ball bounces off it, mirrored
## about the slash as a real deflection would be.
func _deflect_comet(from: Vector2, target: Vector2, col: Color) -> void:
	var meet := from.lerp(target, 0.62)
	var comet := Comet.launch(_fx, from, meet, col)
	var sword := meet + Vector2(0, -260)
	for e in _views:
		if e.has_passive("avenger") and is_instance_valid(_views[e]):
			var r: Rect2 = _views[e].puppet_global_rect()
			sword = r.position + Vector2(r.size.x * 0.3, r.size.y * 0.4)
	CrescentSlash.launch(_fx, sword, meet, comet.dur)
	# where it bounces: its way in at the moment of impact (the end of the comet's curve), reflected about the slash's
	# face (the slash flies along its own normal)
	var ctrl := (from + meet) / 2.0 + Vector2(0, -comet.rise)
	var v_in := (meet - ctrl).normalized()
	var n := (meet - sword).normalized()
	var v_out := v_in - 2.0 * v_in.dot(n) * n
	var away := meet + v_out * 460.0
	comet.arrived.connect(func():
		Audio.play("sword_clang", -3.0, randf_range(0.92, 1.08))
		var fx := Vfx.make(_fx, 70)
		fx.burst(meet, 14, Color(1.0, 0.95, 0.75), Vector2(160, 420), Vector2(0.15, 0.35), Vector2(2, 5), Vfx.SPARK)
		fx.flash(Color(1, 1, 1, 0.12), 0.08)
		_hitstop(0.05)  # (light: a blink of a freeze and a small shake)
		_shake(3.0)
		var bounce := Comet.launch(_fx, meet, away, col)
		bounce.rise = 30.0
		bounce.dur = 0.5
		bounce.ease_out = true)


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
