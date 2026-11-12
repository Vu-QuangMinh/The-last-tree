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

var _h_talk := FightTalk.new(self)
var _h_machine := FightMachine.new(self)
var _h_hud := FightHud.new(self)
var _h_input := FightInput.new(self)
var _h_anim := FightAnim.new(self)
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
signal blocked(action: String)
var fight: Fight
var chant_idx: Array = []  # stock indices in chant order
var phase := "build"  # build: making the chant · spells: the chant is spoken, spells are alive
var chant_mode := ""  # "insert": placing an infused element · "arrange": Rearrange · "pick": choosing an element to copy
var chant_i := 0  # the gap / element highlighted in chant_mode
var chant_block := ""  # with chant_mode "pick" for a Repaint: the colour the brush paints; chant Essence already that colour can't be picked ("" = no limit)


func _chant_blocked(i: int) -> bool:
	return chant_mode == "pick" and chant_block != "" and i >= 0 and i < fight.chant.size() and fight.chant[i] == chant_block


## The next chant Essence a Repaint can pick, starting after `from` in direction `step` (or `from` itself when none else can be).
func _chant_next(from: int, step: int, count: int) -> int:
	var i := from
	for _k in count:
		i = (i + step + count) % count
		if not _chant_blocked(i):
			return i
	return from
@warning_ignore("unused_private_class_variable")
var _step_pos := -1  # during the Release: the chant element flying right now
@warning_ignore("unused_private_class_variable")
var _released := false  # the chant has been Released this turn: no more damage preview until the next turn
@warning_ignore("unused_private_class_variable")
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
@warning_ignore("unused_private_class_variable")
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
@warning_ignore("unused_private_class_variable")
var _heart: TextureRect
signal spellbook_pressed
@warning_ignore("unused_private_class_variable")
var _bottles_frame: NinePatchRect  # Puppet Stage: the painted frames of the bottles and of the artifacts (they follow their contents)
@warning_ignore("unused_private_class_variable")
var _arts_frame: NinePatchRect
var _puppet_hud := false  # Puppet Stage: the HUD of the Chant UI PDF (statuses as icons, artifacts in a row)
var _drag: ChantDrag  # the live, draggable chant while you place or rearrange elements
# building a chant by drag and drop: a press becomes a drag once the mouse moves a little, else it's a click
const DRAG_START := 8.0
var _press := {}  # {kind: "stock" / "chant", i, at}
var _bdrag: ChantDrag
@warning_ignore("unused_private_class_variable")
var _bdrag_src := {}
# Infuse: the new element waits on its spell's card until you drag it into the chant
@warning_ignore("unused_private_class_variable")
var _infuse_orb: ElementIcon
@warning_ignore("unused_private_class_variable")
var _infuse_el := ""
var _infuse_dragging := false
@warning_ignore("unused_private_class_variable")
var _chant_note: Label
var _chant_panel: PanelContainer
var _bag_panel: PanelContainer
@warning_ignore("unused_private_class_variable")
var _stock_row: Control  # the bag: its icons are placed by hand so they can glide into their spots
var _bag_icons := {}  # element uid -> its icon in the bag
@warning_ignore("unused_private_class_variable")
var _bag_target := {}  # element uid -> where its icon belongs (local to _stock_row)
@warning_ignore("unused_private_class_variable")
var _bag_delay := 0.0  # seconds the bag waits before closing a gap (an element is still on its way out)
@warning_ignore("unused_private_class_variable")
var _flying := {}  # element uid -> true while that element is in the air between the bag and the chant
const BAG_PX := 52.0
const BAG_GAP := 6.0
const BAG_W := 1060.0  # (the bag panel is as wide as the chant panel: 1100, minus its margins)
const FLY_TIME := 0.26  # an element jumping between the bag and the chant
const BAG_MOVE := 0.22  # the bag's icons closing up or making room
var _next_row: HBoxContainer
var _next_panel: PanelContainer
var _talk_pending := false  # a boss to talk to: _arrive starts it once everything is in place
@warning_ignore("unused_private_class_variable")
var _talking := false  # talking to a boss before the fight (BossTalk): only the boss, the backdrop and your bag
var _prompt: Label
var _info: Label
var _hp_bar: HpBar
@warning_ignore("unused_private_class_variable")
var _minh_disc: MinhParts.Disc  # MinhHUD: the round Chant / Pass button (flips into Release)
var _hp_label: Label
var _shield_box: HBoxContainer  # the Shield (and Lasting) amount, beside your HP
var _shield_label: Label
var _pstatus: RichTextLabel
var _status_row: Control  # your statuses, as bright badges above the HP bar
var _bottle_row: HBoxContainer  # your bottles, under the HP bar
var _arts: ArtifactBar
@warning_ignore("unused_private_class_variable")
var _bottle_from := Vector2.ZERO
var _picking_any := false  # every enemy's Essence is pickable (a spell that takes any Essence, anywhere)
var _picking_any_cancellable := true
var _steal_drag := {}  # while dragging a stolen Essence: {enemy, index, el, from, icon}
@warning_ignore("unused_private_class_variable")
var _aim_cursor: AimCursor
## Let go of a stolen Essence this close to the bag and it lands in it.
const BAG_DROP_MARGIN := 90.0  # where the bottle being drunk sits (its effects fly from there)
var _log: Label
@warning_ignore("unused_private_class_variable")
var _cast_btn: Button
@warning_ignore("unused_private_class_variable")
var _end_btn: Button
@warning_ignore("unused_private_class_variable")
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
	"overload": "sfx_overload", "cleanse": "sfx_cleanse", "passive": "spell_glow",
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
## The sound an enemy's move makes when it lands on you, by kind (those that have none of their own in the generic code)
const ENEMY_KIND_SFX := {"virus": "sfx_virus_apply", "vulnerable": "spellfx_vulnerable", "toll": "sfx_burden_apply"}
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
	fight.chooser = _h_input._choose_target
	fight.mover = _h_input._mover
	fight.picker = _h_input._picker
	fight.painter = _h_input._painter
	fight.placer = _h_input._placer
	fight.chant_picker = _h_input._chant_picker
	fight.wild_arranger = _h_input._wild_arranger
	fight.wild_painter = _h_input._wild_painter
	fight.element_chooser = _h_input._element_chooser
	fight.attune_chooser = _h_input._attune_chooser
	fight.arranger = _h_input._arranger
	fight.spell_chooser = _h_input._spell_chooser
	fight.anim = _h_anim._anim


func _ready() -> void:
	add_to_group("fight_screen")  # (the bars of the screens laid over it leave the artifacts to this one)
	_nu_ui = UiSkin.is_new_ui()
	if _nu_ui:
		NewUiLayout.use(UiSkin.is_hud2() or UiSkin.is_minhhud(), UiSkin.is_minhhud(), UiSkin.is_newui2())  # (Puppet HUD ver 2 and MinhHUD are the same HUD code with other numbers)
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
		lights.feet = _h_hud._enemy_feet
		add_child(lights)
	_info = UiTheme.label("", 22, Color.WHITE)
	_info.position = Vector2(30, 14)
	add_child(_info)
	_arts = _h_hud._make_arts()
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
	if not _h_hud._circus_strips():  # (Cirus: the Essence waiting in the launcher tube take its place)
		add_child(np)
	# enemies
	_enemy_row = HBoxContainer.new()
	_enemy_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_enemy_row.add_theme_constant_override("separation", 20)
	_enemy_row.position = Vector2(0, 90)
	_enemy_row.size = Vector2(1920, 480)
	add_child(_enemy_row)
	_h_hud._place_enemies()  # (Puppet Stage: they stand in the middle of the floor)
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
	if _h_hud._puppet_strips():
		_spell_row.z_index = 1  # (cards over the globe if there are so many that they reach it)
		_h_hud._build_strips_puppet()
	else:
		_h_hud._build_strips_classic()
	if test_mode and _chant_panel != null:
		_h_hud._build_test_buttons()
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
		_h_hud._rebuild_character_panel()
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
	_arrow.draw.connect(_h_anim._draw_arrow)
	add_child(_arrow)
	var menu_btn := UiTheme.button("☰ Menu", _h_input._open_pause_menu, 18)
	menu_btn.custom_minimum_size = Vector2(130, 44)
	menu_btn.position = Vector2(1920 - 150, 1024)
	if UiSkin.is_puppet():  # (its plate, at the place the HUD layout gives it)
		menu_btn.text = "Menu"
		menu_btn.custom_minimum_size = _h_hud._menu_rest().size
		menu_btn.size = _h_hud._menu_rest().size
		menu_btn.position = _h_hud._menu_rest().position  # (bottom left of the Chant frame, always)
		menu_btn.z_index = PuppetStage.CEILING_Z + 1  # (over the curtain at the top of the stage)
		_menu_btn = menu_btn
	UiTheme.use_menu_style(menu_btn)
	UiTheme.use_heading_font(menu_btn)
	if _nu_ui:
		_h_hud._style_nu_menu(menu_btn)
		if NewUiLayout.hud2 or NewUiLayout.v2:  # (NewUI Ver2: the Menu picture has its word too)
			_h_hud._style_hud2_menu(menu_btn)
		_top_layer.add_child(menu_btn)  # (it is part of the HUD: it sinks with it between fights, where the map has its own Menu button)
	else:
		add_child(menu_btn)
	if _nu_ui:  # (the HUD's own Menu sinks with it: between fights, on the map and the encounter screen, this plate stands where Puppet's does)
		_menu_low = UiTheme.button("Menu", _h_input._open_pause_menu, 18)
		_menu_low.custom_minimum_size = PuppetTopHud.MENU.size
		_menu_low.size = PuppetTopHud.MENU.size
		_menu_low.position = MENU_TOP_AT
		_menu_low.z_index = PuppetStage.CEILING_Z + 1
		UiTheme.use_menu_style(_menu_low)
		UiTheme.use_heading_font(_menu_low)
		_menu_low.visible = false
		add_child(_menu_low)
	_h_hud._build_spells()
	_h_hud._sync_views()
	_h_hud._refresh_all()
	_h_hud._fit_bottom.call_deferred()
	if _stage != null and not map_mode and not rope_mode:  # (Puppet Stage: the enemies hang on the ropes placed with the rope mode, see RopeRig)
		var ropes := RopeRig.new()
		ropes.fs = self
		add_child(ropes)
	if fight.talk_id != "" and not help_override.is_valid():
		if _stage != null and (map_mode or arrive):
			_talk_pending = true  # (Puppet Stage: he speaks once "Begin the fight" is pressed and the scene and the HUD are all in place, see _arrive)
		else:
			_h_talk._talk.call_deferred()  # (a boss to talk to first; not in the tutorial)
	tut.connect(func(_k, _d): note_progress())
	_machine_ready = not (_stage != null and (map_mode or arrive))
	if _stage != null and (map_mode or arrive):
		_h_hud._build_spellbook_button()
		_h_hud._start_down.call_deferred()
	else:
		_h_hud._show_act_sign.call_deferred(true)  # (a fight that simply starts: the sign drops now and goes up after 10 s)


# ------------------------------------------------------------------ Puppet Stage, between fights

## Everything of the HUD that sinks below the edge of the screen (the spell cards, the Chant and the Bag with the machine, HP and what hangs on
## it, the bottles, the artifacts).
func _hud_nodes() -> Array:
	var out: Array = []
	for n in [_spell_row, _chant_panel, _bag_panel, _top_layer]:  # (the Menu button and the Act sign stay where they are; the debuffs go up, see _set_hud_shift)
		if n != null and is_instance_valid(n):
			out.append(n)
	return out


func get_stage() -> PuppetStage:
	return _stage


var _peek := false  # map_mode: an event is on the stage and the player's HP, bottles and artifacts are up
var _peek_tw: Tween
var _peek_pending := false  # asked before the HUD has sunk (a stage made just now): it stays up when it does


## An event on the stage (map_mode): the player's own HUD (HP, bottles, artifacts, Menu) comes up from below, so it can be read while choosing; the
## spell row, Chant and Bag stay down. `peek_hud(true)` again just refreshes it (HP changed); `peek_hud(false)` sinks it.
func peek_hud(on: bool) -> void:
	if not map_mode or _top_layer == null or not is_instance_valid(_top_layer):
		return
	if on:
		_h_hud._refresh_all()
	if _hud_shift <= 1.0:
		_peek_pending = on
		return
	if on == _peek:
		return
	_peek = on
	_h_hud._sync_menu_low()
	if _peek_tw != null:
		_peek_tw.kill()
	_peek_tw = create_tween().set_parallel(true)
	# (relative to where the HUD is now: the same distance the game itself sinks it by, whatever the window's size does to its place)
	_peek_tw.tween_property(_top_layer, "position:y", -HUD_DOWN if on else HUD_DOWN, 0.45).as_relative().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	if _menu_btn != null and not _nu_ui:
		_peek_tw.tween_property(_menu_btn, "position", _h_hud._menu_rest().position if on else MENU_TOP_AT, 0.45)


## The Act / Floor / Turn line is as tall as the 19 px text it replaced (capital letters of that font are about 14 px).
const INFO_CAP := 14.0


## Loudness of the scene-preparation sounds, dB to add so that every one sits at about the same level (measured: RMS of each file brought to -26 dB).
const PREPARE_DB := {"sfx_scene_prepare": -6.6, "sfx_scene_prepare_short_1": 10.0, "sfx_scene_prepare_short_2": 0.9, "sfx_scene_prepare_short_3": 3.6, "sfx_scene_prepare_short_4": 6.6}
const ENEMY_UP := -1500.0  # how far above their places the enemies hang while they are out of sight (their ropes go straight up behind the ceiling)
const ENEMY_LET_DOWN := 0.55  # seconds of free fall before the ropes are out to their length (at ENEMY_SPEED 1)
const ENEMY_SPRING := 1.1  # seconds the puppets bob on their ropes after that
const ENEMY_SPEED := 0.5  # how fast the whole let-down goes: half of what it was
var _enemy_drop := 0.0  # how far the enemy row is lifted from its place (0 = standing)
## Rope mode: the enemies are pulled up on their ropes (the next set is let down).
func rope_leave() -> void:
	var tw := create_tween()
	tw.tween_method(_h_hud._set_enemy_drop, _enemy_drop, ENEMY_UP, 0.7).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
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
		_h_hud._fit_hud_frames()
	hud_released.emit()


## "Begin the fight": the spells chosen on the encounter board are the fight's spells now (they are rebuilt), and each card flies from where it lay on the board
## to its place in the fight's row, while the HUD comes up under it. `from`: [{id, rect (global)}] the active cards of the board.
func begin_with_spells(spells: Array, spellbook: Array, from: Array) -> void:
	fight.loadout = spells
	fight.spellbook = spellbook
	_h_hud._build_spells()
	_h_hud._refresh_all()
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
		_h_hud._hud_up(0.8, false)
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

## Cirus theme: the Chant strip and the Bag strip of "Chant UI for Circus.pdf" (cut by tools/export_circus_chant.py,
## laid out by ChantLayout). The Bag strip ends in the launcher tube: the Essence ride in it under a sheet of glass, and
## when a batch is released the crank turns once, the gear twice, and they roll out to their places (see _tube_launch).
const TUBE_BALL_STEP := 54.0

@warning_ignore("unused_private_class_variable")
var _launching := 0  # Essence rolling out of the tube right now
@warning_ignore("unused_private_class_variable")
var _bag_seen := {}  # uid -> true: Essence that have been in the bag before (only the brand new ones roll out of the tube)
@warning_ignore("unused_private_class_variable")
var _cast_uids := {}  # uid -> true: the Essence of the chant being cast right now (still in the stock for a moment, but gone)
@warning_ignore("unused_private_class_variable")
var _tube_icons: Array = []  # the Essence in the tube (next turn's draw), or waiting hidden in the red block (sent by a spell)
@warning_ignore("unused_private_class_variable")
var _direct_in := 0  # stolen Essence on their way into the Bag that skip the machine
@warning_ignore("unused_private_class_variable")
var _direct_until := 0  # ticks: after this a stolen one is no longer waited for
@warning_ignore("unused_private_class_variable")
var _direct_landed := false
@warning_ignore("unused_private_class_variable")
var _direct_wait: Array = []  # the Bag's balls waiting for the flying one to land
@warning_ignore("unused_private_class_variable")
var _bag_order: Array = []  # Puppet Stage: the uids of the Bag's balls in the order they stand now (new balls stack after them; a re-sort follows)
@warning_ignore("unused_private_class_variable")
var _resort := false  # (set while the sorted order is being walked into: its balls swap with a lift and one sound)
@warning_ignore("unused_private_class_variable")
var _resort_wait := false  # a launch just ended: the balls wait a moment before they swap into their types
@warning_ignore("unused_private_class_variable")
var _machine: SlotMachine  # Puppet Stage: the slot machine
var _nu_ui := false  # the New UI theme (NewUiLayout): the Puppet look, a HUD laid out as page 2 of the Chant UI PDF, no machine (fixed when the fight is built)
@warning_ignore("unused_private_class_variable")
var _cast_kind := "chant"  # Puppet HUD ver 2: which painted picture the main button wears
@warning_ignore("unused_private_class_variable")
var _nu_back: NewUiLayout.Back  # New UI: the dark blocks, the slots and the debuff circles
var _spawned_once := false  # the first launch of a fight counts as a spawn: the lever is pulled for it
@warning_ignore("unused_private_class_variable")
var _bonus_from := Vector2.INF  # where the next bonus Essence comes from (a screen point: the card, the bottle...); INF: it pops up over the top funnel
@warning_ignore("unused_private_class_variable")
var _reel_shown: Array = []  # the Essence the reels show (next turn's draw)
var _machine_ready := false  # the machine is on the screen (a fight on the stage builds its HUD below the screen first and lifts it later: nothing may spawn before)
@warning_ignore("unused_private_class_variable")
var _keep_bag_order := false  # after a bonus ball joined mid-turn: the Bag keeps its order (the new ball stands after the others) until the next spawn
@warning_ignore("unused_private_class_variable")
var _reels_armed := false  # the reels have rolled next turn's draw (the lever was pulled after the last spawn) and show it
@warning_ignore("unused_private_class_variable")
var _tube_prep := false  # a launch is being set up
@warning_ignore("unused_private_class_variable")
var _rolling_in := 0  # Essence rolling into the tube right now
@warning_ignore("unused_private_class_variable")
var _turn_batch_until := 0  # ticks: a new turn is starting, so the next new Essence come out of the tube


## Puppet Stage: the enemies' row, so that their feet are on the middle of the floor.
const ENEMY_FEET_DY := 480.0  # (from the top of the row to the feet of a puppet: it stands at the bottom of its box, name and Essence above it)
const ENEMY_LIFT := 0.0  # (how much higher than the middle of the floor they stand)


@warning_ignore("unused_private_class_variable")
var _lift_tween: Tween
@warning_ignore("unused_private_class_variable")
var _extra_lift := 0.0  # how much higher the enemies stand because their rows of Essence need more than one line above the spell cards


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
var _menu_low: Button  # New UI: the Menu button of the screens between fights (the HUD, and its Menu, are down)
@warning_ignore("unused_private_class_variable")
var _debuff_board: NinePatchRect  # Puppet Stage: the red board at the top left that holds the debuffs (it stretches to fit their icons)
var _top_layer: Control  # holds everything of the char panel (HP, bottles, artifacts): it sinks with the HUD between fights
@warning_ignore("unused_private_class_variable")
var _act_sign: Control  # Puppet Stage: the hanging sign with the Act / Floor / Turn line: it drops at the start of a fight and goes back up after a while
const STATUS_CHIP := 52.0  # as tall as an orb of the Bag
const STATUS_GAP := 4
const DEBUFF_PAD := 22.0


const PUPPET_RING_PX := 52.0


## ---- Puppet Stage: the slot machine (see SlotMachine and docs/new_machine_logic.md) -----------------------------------------------------------------
## A spawn (the start of a turn, the first hand of a fight): the lever is pulled, the three reels spin for 2 s and stop on the Essence that spawn, each of them drops into
## the bottom funnel, goes down the glass tube and comes up out of the port in the Bag strip, and rolls to its place. A bonus Essence (a spell, a bottle, an artifact,
## a refund, the ones of a spawn beyond the third) does not touch the reels: it flies from its source into the top funnel, falls through the machine, and takes the same
## way out. An Essence that a spell gives for NEXT turn materializes in the tray on top of the machine and lies there; at the next spawn it goes down with the others.
const SLOT_TUBE_SPEED := 470.0  # px/s of an Essence inside the machine and the tube
const NU_EMERGE_T := 0.14  # (NewUI Ver2: how long an Essence takes to come up out of the hole)
const NU_TUBE_SPEED := 620.0  # (New UI: the Essence run on along the Bag tray at this speed, see _nu_roll)
const SLOT_BALL_SCALE := 0.92  # an Essence is drawn this big inside the glass


## A spell gives Essence for next turn: a comet of light flies from the card to the tray on top of the machine (the top funnel), where it materializes into an
## Essence and lies there. At the next spawn the tray's Essence go down with the others: they drop into the funnel and take the usual way to the Bag (_puppet_launch).
const TRAY_SCALE := 0.72  # an Essence lying in the tray is drawn this big


const HUD2_HOLD := 0.4  # how long a ball that has come to rest waits before it is let go
const HUD2_GAP := 0.12  # at least this long between one ball being let go and the next
const HUD2_G := 2600.0  # px/s^2 falling down the tube
const HUD2_ACC := 3500.0  # px/s^2 getting up to speed on the way out
const HUD2_DT := 1.0 / 60.0


const NU_ROLL_SPEED := 820.0  # px/s of a rolling orb
const NU_ROLL_ACCEL := 0.18  # seconds it takes to get up to speed
const NU_ROLL_BRAKE := 150.0  # px: over the last stretch it slows smoothly to a stop


## The spell row. With many spells the cards shrink to fit the screen; hovering one brings it back to full size.
## The lower block (spell row, chant, bag, Keeper, log) is laid out from the top; once the panels have their real sizes,
## slide the whole block down together (keeping the gaps between its parts) until the bag sits BOTTOM_MARGIN above the
## screen's bottom edge.
const BOTTOM_MARGIN := 20.0


const ROW_WIDTH := 1860.0
const SPELL_ROW_LEFT := 20.0  # (Puppet: how far left a long spell row may reach)
const SPELL_ROW_FITS := 8  # the cards are sized so this many fit in a row
const SPELL_GAP := 12.0  # between two cards
const SPELL_MARGIN := 16.0  # between the row and the screen's edge


## A Handyman hand that has just been brought down but is not yet marked knocked out (that happens a moment later, in Fight._handyman_step):
## its view must not go away (and be built again, reaching out, a moment after).
@warning_ignore("unused_private_class_variable")
var _rally_hold := false  # the Handyman's last stand has begun but he has not pulled his hands up yet: they stay on the floor
const RALLY_QUAKE := 2.4  # seconds his body shakes before the hands are pulled up
const RALLY_GAP := 0.6  # seconds between one hand being pulled up and the next


## The gap between the enemies: as wide as the stage allows (up to ENEMY_GAP_MAX), so an intent bubble (it sits beside
## its enemy) never lands on its neighbour's model or cards (the Wizard's floating spells); 20 px when the row is full.
const ENEMY_GAP_MAX := 150.0
const SAMURAI_GAP := -110.0
const DUO_GAP := -236.0


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


const CHANT_RINGS := 8  # empty rings shown while the chant is short (the chant itself has no length limit)
const CHANT_RINGS_PUPPET := 10  # (the Puppet Stage strip has room for ten)
const CHANT_W := 700.0  # room for the chant: a longer chant squeezes its Essence together, even overlapping
const CHANT_W_CIRCUS := 540.0  # (the Cirus strip puts the buttons on the same row)


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
			_h_input._cancel()
			get_viewport().set_input_as_handled()
			return
	# steal: letting go of the Essence you're dragging
	if not _steal_drag.is_empty() and ev is InputEventMouseButton and ev.button_index == MOUSE_BUTTON_LEFT and not ev.pressed:
		_h_input._end_steal_drag(ev.global_position)
		return
	# Infuse: the element taken from the card follows the mouse; let go over the chant to place it
	if _infuse_dragging and is_instance_valid(_drag):
		if ev is InputEventMouseMotion:
			_drag.set_pointer(ev.global_position)
		elif ev is InputEventMouseButton and ev.button_index == MOUSE_BUTTON_LEFT and not ev.pressed:
			_h_input._infuse_drop()
		return
	# building the chant: a held press that moves becomes a drag; let go without moving and it's a click
	if not _press.is_empty():
		if ev is InputEventMouseMotion and is_instance_valid(_bdrag):
			_bdrag.set_pointer(ev.global_position)
		elif ev is InputEventMouseMotion and ev.global_position.distance_to(_press.at) > DRAG_START:
			_h_input._begin_build_drag(ev.global_position)
		elif ev is InputEventMouseButton and ev.button_index == MOUSE_BUTTON_LEFT and not ev.pressed:
			var p := _press
			_press = {}
			if is_instance_valid(_bdrag):
				_h_input._end_build_drag()
			elif p.kind == "stock":
				_h_input._toggle_stock(p.i)
			else:
				_h_input._remove_from_chant(p.i)
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
		_h_input._show_help()


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
		return "Rearranging: grab an enemy's Essence and drag it to another spot, in its row or onto another enemy. Right-click skips."
	if chant_mode == "insert":
		return "Place the new Essence: it's the glowing one in your chant. Drag it to where it should go (or Left / Right, then Enter)."
	if chant_mode == "arrange":
		return "Self-Rearrange: every Essence of your chant is glowing. Drag one to another spot to make new patterns; right-click keeps the chant as it is."
	if chant_mode == "pick":
		return "Pick an Essence of your chant to copy: click it (or Tab + Enter)."
	if phase == "build":
		if chant_idx.is_empty():
			return "Build a chant: click your Essence at the bottom (or press F, W, A). Every enemy will lose the longest START of its Essence found in your chant, and spells whose pattern appears in it come alive. Then press Chant."
		return "Your chant so far: %s. The crossed-out orbs on the enemies show what they'll lose. Add more Essence, click one in the chant to take it back, or press Chant (Enter) when you're happy." % " ".join(Array(_h_hud._chant_string().split("")))
	var alive := _cards.filter(func(c): return c.charges > 0)
	if not alive.is_empty():
		var names := alive.map(func(c): return c.spell.name)
		return "Your chant is spoken. These spells are alive (glowing): %s. Click one to cast it; if it needs a target it pulls out an arrow, then click an enemy. When you're done, press Release (E) to fire the chant." % ", ".join(names)
	return "Your spells are done. Press Release (E): the chant's Essence fly at the enemies and deal the damage."


func _unhandled_input(ev: InputEvent) -> void:
	if _h_hud._hud_hidden():
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
			_h_input._close_pause_menu()
			get_viewport().set_input_as_handled()
		return
	if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_RIGHT:
		if chant_mode == "arrange":
			_arrange_done.emit([])
			return
		_h_input._cancel()
		return
	if not (ev is InputEventKey) or not ev.pressed or ev.echo:
		return
	if _picking_any and ev.keycode == KEY_ESCAPE:
		_h_input._cancel()  # (a selected spell goes back, as with right-click)
		get_viewport().set_input_as_handled()
		return
	if aiming:
		match ev.keycode:
			KEY_TAB:
				aim_i = (aim_i + (-1 if ev.shift_pressed else 1) + aim_cands.size()) % aim_cands.size()
				Audio.play("ui_tab_target")
				_h_hud._refresh_all()
			KEY_ENTER, KEY_KP_ENTER, KEY_SPACE:
				if _allowed("target", aim_cands[aim_i]):
					_h_input._finish_aim(aim_cands[aim_i])
			KEY_ESCAPE:
				_h_input._cancel()
		get_viewport().set_input_as_handled()
		return
	if move_view != null:
		if ev.keycode == KEY_ESCAPE:
			_h_input._cancel()
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
				chant_i = _chant_next(chant_i, 1, count)
				Audio.play("ui_tab_target")
				_h_hud._refresh_chant()
			KEY_LEFT:
				chant_i = _chant_next(chant_i, -1, count)
				Audio.play("ui_tab_target")
				_h_hud._refresh_chant()
			KEY_ENTER, KEY_KP_ENTER, KEY_SPACE:
				_h_anim._emit_chant_done(chant_i)
		get_viewport().set_input_as_handled()
		return
	if pick_view != null:
		match ev.keycode:
			KEY_TAB:
				Audio.play("ui_tab_target")
				_h_input._cycle_pick(-1 if ev.shift_pressed else 1)
			KEY_ENTER, KEY_KP_ENTER, KEY_SPACE:
				if pick_view.pick_i >= 0 and _allowed("pick", pick_view.pick_i):
					_pick_done.emit(pick_view.pick_i)
		get_viewport().set_input_as_handled()
		return
	match ev.keycode:
		KEY_F:
			_h_input._add_element("F")
		KEY_W:
			_h_input._add_element("W")
		KEY_A:
			_h_input._add_element("A")
		KEY_1, KEY_2, KEY_3, KEY_4, KEY_5, KEY_6, KEY_7:
			var n: int = ev.keycode - KEY_1
			if phase == "spells" and n < _cards.size():
				_h_input._on_card_clicked(_cards[n])
			elif phase == "build" and n < 3:
				_h_input._add_element(["F", "W", "A"][n])
		KEY_BACKSPACE:
			if not busy and phase == "build" and not chant_idx.is_empty():
				_h_input._remove_from_chant(chant_idx.size() - 1)
		KEY_ENTER, KEY_KP_ENTER, KEY_SPACE:
			_h_input._on_cast()
		KEY_E:
			_h_input._on_end_turn()
		_:
			return
	get_viewport().set_input_as_handled()


## [text, colour, keyword] for each status you have: shown as bright badges above your HP bar.
## The picture names to try for each of your statuses (the first that exists is used; Puppet art first, the older intent pictures as a fallback).
const STATUS_ART_NAMES := {"shield": ["icon_armor_shield"], "thorns": ["status_thorns"], "silence": ["status_silenced"], "aegis": ["status_aegis"],
	"echo": ["status_echo_ready"], "overload": ["status_overload"], "ethereal": ["status_ethereal", "intent_ethereal"],
	"poison": ["status_poison", "intent_poison"], "bleed": ["status_bleed", "intent_bleed"], "confuse": ["status_confuse", "intent_confuse"], "blind": ["status_blind", "intent_blind"],
	"lock": ["status_burden", "status_toll", "intent_toll"], "vulnerable": ["status_vulnerable"], "stun": ["status_stunned", "intent_stunned"],
	"brittle": ["status_brittle"], "disarmed": ["status_disarmed"]}
## A Power's badge picture, by the theme of its dissolve (fire / water / wind use the Essence balls).
const POWER_ART_NAMES := {"fire": ["essence_fire"], "water": ["essence_water"], "wind": ["essence_wind"], "thorn": ["status_thorns"],
	"venom": ["status_poison", "intent_poison"], "leaf": ["icon_seedling"], "shadow": ["status_silenced"], "page": ["icon_spellbook"]}


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
	"cauterize": "fire", "stillness": "shadow", "frailty": "shadow", "grimoire": "page"}


static func power_theme(sp: Dictionary) -> Dictionary:
	var key: String = POWER_THEME_OF.get(sp.get("id", ""), "")
	if key == "":
		var p := String(sp.get("pattern", ""))
		var counts := {"F": p.count("F"), "W": p.count("W"), "A": p.count("A")}
		key = {"F": "fire", "W": "water", "A": "wind"}[counts.keys().reduce(func(a, b): return a if counts[a] >= counts[b] else b)]
	return POWER_THEMES[key]


## status keyword -> art by name (UiSkin looks in assets/New/ ...)
const STATUS_ART := {"shield": "icon_armor_shield", "thorns": "status_thorns", "silence": "status_silenced", "aegis": "status_aegis", "evasion": "status_aegis",
	"echo": "status_echo_ready", "overload": "status_overload", "ethereal": "intent_ethereal", "poison": "intent_poison", "bleed": "intent_bleed",
	"confuse": "intent_confuse", "blind": "intent_blind", "lock": "intent_toll"}


## Hovering an enemy's intent bubble explains what it's about to do; hovering the enemy itself (its sprite or its row
## of Essence) explains everything about it, and the sprite also says what it is about to do. Our own panel, shown after a short moment and kept beside the enemy;
## hidden while you're aiming or picking, so it never covers what you're clicking.
const HOVER_DELAY := 0.3
## Dragging: the Bag (or the Chant, for a steal into it) lights up while the Essence in your hand can be let go on it; the fist goes when the drag is over.
@warning_ignore("unused_private_class_variable")
var _glow_panel: Control
@warning_ignore("unused_private_class_variable")
var _grab_cursor: AimCursor
@warning_ignore("unused_private_class_variable")
var _test_pointer := Vector2(-1, -1)  # (a test's pointer: the real one cannot be moved from a script)


func _process(_d: float) -> void:
	if not rope_mode:
		_h_input._update_hover_info(_d)
	if _h_hud._puppet_strips():
		_h_input._drag_feedback()
	_h_anim._pulse_release()
	# what the artifacts give for next turn: once the HUD is up and no ball is moving, it flies to the tray (each once)
	if _h_hud._puppet_strips() and _machine_ready and not _h_hud._hud_hidden() and phase == "build" and not busy and _spawned_once 			and fight.player.next_draw.any(func(d): return d.has("from") and not d.get("shown", false)):
		_h_machine._stash_artifact_draws(fight.turn + 1)
	if _h_hud._puppet_strips():
		_h_hud._fit_enemy_lift()
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
					_h_hud._refresh_all()
		_arrow.queue_redraw()


## Rearrange: every enemy's row comes alive. Grab an Essence and drag it to another spot in its row (the others
## slide aside), or carry it onto another enemy's row and let go there (taking an enemy's last Essence defeats it).
## Tab + Left / Right + Enter works too (in the first row); Esc / right-click skips.
## (The Bramble Matron's row is split up while her walls stand: she sits it out.)
## Returns [from, to, from enemy index, to enemy index], or [] to skip.
var _edrag: ChantDrag  # the row the keyboard moves in


## Wild Repaint: the brush comes out over the enemies, and your chant's Essence can be clicked too. Returns
## ["chant", i], ["enemy", enemy index, i], or [] if nothing could be painted.
signal _wild_painted(got: Array)


## Animation hook from the fight.
## Every event of the fight, then: an enemy that has no Essence left breaks at once (not at the end of the turn).
@warning_ignore("unused_private_class_variable")
var _reforming := {}  # EnemyState -> PuppetShatter: a boss pulling itself back together (see "reform")


const ThrowFx := preload("res://scripts/ui/orphan_fx.gd")
@warning_ignore("unused_private_class_variable")
var _slot_w := {}  # EnemyState -> the width of its place
const EXTENSION_NAMES := ["Extension!", "Double Extension!", "Triple Extension!", "Quadruple Extension!", "Quintuple Extension!", "Sextuple Extension!", "Septuple Extension!", "Octuple Extension!"]  # (at most 8: one slam per spell an Extension wakes, and the active row holds 8 at most)
const SLAM_ANGLE := -35.0  # degrees: low on the left, high on the right


const WORD_COUNTS := ["double", "triple", "quadruple", "quintuple", "sextuple", "septuple", "octuple"]  # (UI/Banners/word_<name>.png: "Double" ... then "Extension" under it)


## New theme: the end-of-fight banner ("victory" / "perfect" / "defeat"), built from separate painted layers that all share
## one size, so they line up when laid on top of each other. The ribbon falls first and lands with a thud, then the
## lettering falls onto it. For "perfect" the word PERFECT then flickers on above it, in front. Returns false (and
## shows nothing) when the Theme is Default or the art is missing, so the caller falls back to the old slam text.
## How far PERFECT is lifted above its place in the art (it overlapped VICTORY by ~80 px there).
const PERFECT_RAISE := 60.0


var _choosing_el := false


## The Pianist: his piece starts now and runs in real time; at its end, The End.
@warning_ignore("unused_private_class_variable")
var _song: PianistSong
const PIANIST_LEAD_IN := 2.0  # (seconds between Engage and the first note)


const TALK_W := 980.0  # the conversation box
const TALK_PAD := 30.0


## A flat rounded panel (no picture: nothing to stretch or blur).
static func _talk_flat(bg: Color, border: Color, bw: int, radius: int, shadow := 0.0) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(bw)
	s.set_corner_radius_all(radius)
	s.set_content_margin_all(0)
	if shadow > 0.0:
		s.shadow_color = Color(0, 0, 0, 0.5)
		s.shadow_size = int(shadow)
		s.shadow_offset = Vector2(0, 4)
	return s


## The box the boss's talk is in: dark wood-brown, a thin brass rim.
static func _talk_box_style() -> StyleBoxFlat:
	var s := _talk_flat(Color(0.10, 0.07, 0.05, 0.94), Color(0.66, 0.48, 0.24), 2, 14, 16.0)
	s.content_margin_left = TALK_PAD
	s.content_margin_right = TALK_PAD
	s.content_margin_top = 20
	s.content_margin_bottom = 20
	return s


## An option (a dark plank that warms under the mouse) or Engage! (amber, the one thing that stands out).
static func _talk_skin(b: Button, amber: bool) -> void:
	if UiSkin.is_puppet() and UiSkin.tex("btn_primary") != null:  # (the painted plaques: gold for Engage!, walnut for what you say)
		UiTheme.skin_button(b, "primary" if amber else "default")
		return
	var look := {
		"normal": [Color(0.78, 0.52, 0.16), Color(1.0, 0.82, 0.45)] if amber else [Color(0.20, 0.14, 0.09), Color(0.45, 0.33, 0.18)],
		"hover": [Color(0.9, 0.62, 0.22), Color(1.0, 0.9, 0.6)] if amber else [Color(0.30, 0.21, 0.12), Color(0.72, 0.54, 0.28)],
		"pressed": [Color(0.66, 0.42, 0.12), Color(1.0, 0.8, 0.4)] if amber else [Color(0.14, 0.10, 0.06), Color(0.72, 0.54, 0.28)],
		"disabled": [Color(0.5, 0.36, 0.14), Color(0.7, 0.58, 0.35)] if amber else [Color(0.13, 0.10, 0.07), Color(0.28, 0.22, 0.14)],
		"focus": [Color(0, 0, 0, 0), Color(0, 0, 0, 0)],
	}
	for k in look:
		var st := _talk_flat(look[k][0], look[k][1], 2 if amber else 1, 9)
		st.content_margin_left = 16
		st.content_margin_right = 16
		b.add_theme_stylebox_override(k, st)
	for c in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_disabled_color"]:
		b.add_theme_color_override(c, Color(0.16, 0.09, 0.03) if amber else Color(0.97, 0.91, 0.78))


const SELF_OPS := ["shield", "heal", "aegis", "thorns", "cleanse", "sacrifice"]


## How much slower the spiders and their cocoons move than the rest (their durations are multiplied by this): half the speed.
const SPIDER_SLOW := 2.0
@warning_ignore("unused_private_class_variable")
var _spider_away: EnemyState  # the Veiled Eyes, pulled up with a stolen spell and waiting up there for the cocoon to be let down


## The enemy's action box sits here (top of the screen) while it acts, then fades away.
const TURN_BOX_Y := 14.0
const TURN_READ_TIME := 1.0
const ARROW_LEN := 210.0  # px on the screen (the picture is 420 long, head on the left)
const ARROW_STAY := 1.0  # seconds it stays stuck in the HP bar


## The Crossbow Hand fires: the bolt lies on the bow; the whole hand (arm, hand and bow) turns together with the bolt until it points at your HP bar, aims
## there for a second, then the bolt flies and sticks in the bar; a second later it is gone. Returns the point it hit (the caller plays the impact there).
const ARROW_NOCK := 70.0  # px from the hand along the bow: where the bolt lies
const SPEAR_TIP_LEN := 232.0  # px from the Spear Hand's hand to the point of its spear


# ------------------------------------------------------------------ forwarders (other files call these names; the code lives in the helpers)
func _set_hud_shift(v: float) -> void:
	_h_hud._set_hud_shift(v)


func _hud_hidden() -> bool:
	return _h_hud._hud_hidden()


func _hud_down(secs := 0.9) -> void:
	await _h_hud._hud_down(secs)


func _arrive() -> void:
	await _h_hud._arrive()


func _feet_y() -> float:
	return _h_hud._feet_y()


func _nu_menu_state(k: int) -> void:
	_h_hud._nu_menu_state(k)


func _puppet_strips() -> bool:
	return _h_hud._puppet_strips()


func _place(c: Control, r: Rect2) -> void:
	_h_machine._place(c, r)


func _roll_in(ic: ElementIcon, to_x: float, delay: float) -> void:
	await _h_machine._roll_in(ic, to_x, delay)


func _stash_flight(ev: Dictionary, from: Vector2) -> float:
	return _h_machine._stash_flight(ev, from)


func _refund_flight(ev: Dictionary) -> void:
	await _h_machine._refund_flight(ev)


func _slot_route(ic: ElementIcon, delay: float, mode: String, from_local := Vector2.ZERO) -> float:
	return _h_machine._slot_route(ic, delay, mode, from_local)


func _stash_to_machine(ev: Dictionary, from: Vector2) -> float:
	return _h_machine._stash_to_machine(ev, from)


func _build_spells() -> void:
	_h_hud._build_spells()


func _sync_views() -> void:
	_h_hud._sync_views()


func _chant_string() -> String:
	return _h_hud._chant_string()


func _refresh_all() -> void:
	_h_hud._refresh_all()


func _stock_index(uid: int) -> int:
	return _h_hud._stock_index(uid)


func _bag_center(uid: int) -> Vector2:
	return _h_hud._bag_center(uid)


func _bag_target_center(uid: int) -> Vector2:
	return _h_hud._bag_target_center(uid)


func _chant_px() -> float:
	return _h_hud._chant_px()


func _fly(s: Dictionary, from: Vector2, to: Vector2, from_px: float, to_px: float) -> void:
	_h_anim._fly(s, from, to, from_px, to_px)


func _land(uid: int) -> void:
	_h_anim._land(uid)


func _show_help() -> void:
	_h_input._show_help()


func _chant_changed() -> void:
	_h_hud._chant_changed()


func _press_element(kind: String, i: int) -> void:
	_h_input._press_element(kind, i)


func _begin_build_drag(pointer: Vector2) -> void:
	_h_input._begin_build_drag(pointer)


func _toggle_stock(i: int) -> void:
	_h_input._toggle_stock(i)


func _add_stock_index(i: int) -> void:
	_h_input._add_stock_index(i)


func _remove_from_chant(pos: int) -> void:
	_h_input._remove_from_chant(pos)


func _add_element(el: String) -> void:
	_h_input._add_element(el)


func _best_chant(counts: Dictionary, max_len: int, score_of: Callable) -> String:
	return _h_input._best_chant(counts, max_len, score_of)


func _auto_fill() -> void:
	await _h_input._auto_fill()


func _auto_ball() -> void:
	_h_input._auto_ball()


func _clear_chant() -> void:
	_h_input._clear_chant()


func _cancel() -> void:
	_h_input._cancel()


func _on_primary() -> void:
	_h_input._on_primary()


func _on_cast() -> void:
	await _h_input._on_cast()


func _on_card_clicked(card: SpellCard) -> void:
	await _h_input._on_card_clicked(card)


func _needs_pick(spell: Dictionary) -> bool:
	return _h_input._needs_pick(spell)


func _on_end_turn() -> void:
	await _h_input._on_end_turn()


func _damage_step() -> void:
	await _h_anim._damage_step()


func _finish() -> void:
	await _h_anim._finish()


func _on_bottle(chip: BottleChip) -> void:
	await _h_input._on_bottle(chip)


func _spell_chooser(spells: Array) -> int:
	return await _h_input._spell_chooser(spells)


func _open_pause_menu() -> void:
	_h_input._open_pause_menu()


func _close_pause_menu() -> void:
	_h_input._close_pause_menu()


func _card_point(card: SpellCard) -> Vector2:
	return _h_input._card_point(card)


func _finish_aim(idx: int) -> void:
	_h_input._finish_aim(idx)


func _on_enemy_clicked(v: EnemyView) -> void:
	_h_input._on_enemy_clicked(v)


func _update_hover_info(d: float, m := Vector2(-1, -1)) -> void:
	await _h_input._update_hover_info(d, m)


func _choose_target(spell: Dictionary, cands: Array) -> int:
	return await _h_input._choose_target(spell, cands)


func _mover(spell: Dictionary, _hint: EnemyState) -> Array:
	return await _h_input._mover(spell, _hint)


func _pick_any_essence(spell: Dictionary, cancellable: bool, only: EnemyState = null, style := "") -> Array:
	return await _h_input._pick_any_essence(spell, cancellable, only, style)


func _begin_steal_drag(v: EnemyView, index: int) -> void:
	_h_input._begin_steal_drag(v, index)


func _end_steal_drag(at: Vector2) -> void:
	_h_input._end_steal_drag(at)


func _on_hp_clicked(v: EnemyView, index: int) -> void:
	_h_input._on_hp_clicked(v, index)


func _emit_chant_done(i: int) -> void:
	_h_anim._emit_chant_done(i)


func _anim(ev: Dictionary) -> void:
	await _h_anim._anim(ev)


func _hop(ic: Control, height: float) -> void:
	_h_anim._hop(ic, height)


func _result_banner(kind: String) -> bool:
	return await _h_anim._result_banner(kind)


func _hammer_fx(ev: Dictionary) -> void:
	await _h_anim._hammer_fx(ev)


func _shatter_card(card: SpellCard) -> void:
	await _h_anim._shatter_card(card)


func _talk() -> void:
	await _h_talk._talk()


func _pianist_start() -> void:
	await _h_talk._pianist_start()


func _page_turn(e: EnemyState) -> void:
	await _h_talk._page_turn(e)


func _pianist_finale() -> void:
	await _h_talk._pianist_finale()


func _speech_bubble(head_at: Callable, text: String, hold := 1.0) -> void:
	await _h_talk._speech_bubble(head_at, text, hold)


func _armadillo_ending(e: EnemyState) -> void:
	await _h_talk._armadillo_ending(e)


func _dillo_say(at: Vector2, text: String, hold: float, hanging := false) -> void:
	await _h_talk._dillo_say(at, text, hold, hanging)


func _card_for(id: String) -> SpellCard:
	return _h_anim._card_for(id)


func _callout_panel(bbcode: String, col: Color) -> PanelContainer:
	return _h_anim._callout_panel(bbcode, col)


func _area(c: Control) -> Dictionary:
	return _h_anim._area(c)


func _retainer_yields(r: EnemyState) -> void:
	await _h_anim._retainer_yields(r)


func _player_point() -> Vector2:
	return _h_anim._player_point()


func _bell_strike(v: EnemyView, alarm: bool) -> void:
	await _h_anim._bell_strike(v, alarm)


func _enemy_attack(ev: Dictionary) -> void:
	await _h_anim._enemy_attack(ev)


func _arm_swing(c: Creature, power: float) -> void:
	_h_anim._arm_swing(c, power)


func _enemy_move_fx(ev: Dictionary) -> void:
	await _h_anim._enemy_move_fx(ev)


func _shake(amount: float) -> void:
	_h_anim._shake(amount)


func _release_step(ev: Dictionary) -> void:
	await _h_anim._release_step(ev)


func _deflect_comet(from: Vector2, target: Vector2, col: Color, who: EnemyState = null) -> void:
	_h_anim._deflect_comet(from, target, col, who)


func _wait(t: float) -> void:
	await _h_anim._wait(t)


func _float_text(text: String, pos: Vector2, col: Color) -> void:
	_h_anim._float_text(text, pos, col)


func _banner(text: String, col: Color, life := 1.2) -> void:
	_h_anim._banner(text, col, life)
