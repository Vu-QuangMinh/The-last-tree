class_name EventStage
extends Control
## A "?" event played on the Puppet Stage (docs: the events sheet). The event's story sits in a panel at the bottom, and its props stand on the
## floor, behind the stage's valance: the ones tied to an option light up under the mouse (all the props of one option together), say what they do in
## a little tag, and a click chooses that option. Options that have no prop (and every option of an event with no art for it yet) are plain buttons
## under the story. The choice itself is made by the caller (`picked` carries the option's index); the page after it (a "next" page, or the same
## choices again) is a new EventStage with `again` set, so its props do not walk on a second time.
## A layout entry: props [{img, x (fraction of the width), h (px), opt (label of the option it stands for), label (the tag, if not the option's
## own words), from (left / right / top), dy (px, + = nearer), always (tag stays up), fly, tag}], btns [{opt, x, y}] (an option as a button beside the
## props), night (alpha of the night shade: the sun goes, the moon comes), spot (the picture that gets a light behind it), forest (a number of cacti,
## see _make_forest, moved about after every choice), no_hud (the player's HUD stays down), center (the items and buttons stand in the middle of the
## screen), (a prop with slow: it rolls in from the right over that many seconds, with voice_in and sfx_in playing, and says voice_arrive when it stops; the items wait for it), result_on_stage (what an option did is told in the hint panel, on this same stage, with a Continue button: see show_result), flame (an item card burns while the mouse is on it), item_sfx (played when one is chosen), outro {option index: scroll_fly / lift / shell_fall}.

signal picked(i: int)
signal traded(id: String)  # the Recycler: one of the three he gave back was chosen
signal fuse_cancelled  # (An Abandoned Camp: Back was pressed while picking the two spells)
signal continued  # the result is read and Continue is pressed (see show_result)
signal item_picked(opt: int, ids: Array)  # an item shown on the stage was chosen for option `opt` (as many ids as the option needs)

const FEET_DY := 35.0
const WORLD_Z := 20  # (the props stand on the stage: under the ceiling's valance, over the stage's own pieces)
const CACTI := {"event_cactus_1": 330.0, "event_cactus_2": 170.0, "event_cactus_3": 380.0, "event_cactus_4": 210.0, "event_cactus_5": 420.0}
const NOTE := "Take the spell in the note, and leave one of yours in it"
const LAYOUTS := {
	"note_to_self": {"no_hud": true, "offer_on_stage": true, "offer_keep_props": true, "item_tags": {"Take the spell in the note, and leave one of yours in it": "Leave this spell in the note"}, "props": [{"img": "event_tray", "x": 0.47, "h": 96.0, "from": "top", "opt": NOTE},
			{"img": "event_scroll", "x": 0.47, "h": 64.0, "dy": -50.0, "from": "top", "delay": 0.35, "tag": "scroll", "opt": NOTE}],
		"outro": {0: "scroll_fly", 1: "lift"}},
	"farmer_farm": {"props": [{"img": "event_wheat_row", "x": 0.64, "h": 190.0, "from": "right"}, {"img": "event_farmer", "x": 0.34, "h": 330.0, "from": "left"}]},
	"cactus_maze": {"props": [], "forest": 20, "night": 0.62, "no_hud": true, "center": true, "flame": true, "result_on_stage": true, "item_sfx": "sfx_card_ignite",
		"result_how": {"Ignite a spell": "burn", "Force your way": "shatter", "Follow the voice": "whisper"},
		"item_tags": {"Ignite a spell to burn a way out": "Ignite a spell to burn a way out"}},
	"shrinking_pond": {"no_hud": true, "center": true, "result_on_stage": true, "result_how": {"Give it a spell": "pond_give"}, "item_tags": {"Give it a spell": "Give it a spell"},
		"props": [{"img": "event_pond_dry", "role": "pond", "x": 0.45, "h": 210.0, "from": "right", "opt": "Give it a spell"},
			{"img": "event_water_wisp", "role": "wisp", "x": 0.45, "h": 95.0, "dy": -34.0, "from": "right", "bob": true, "opt": "Give it a spell"}]},
	"church_of_aole": {"props": [{"img": "event_church", "x": 0.5, "h": 530.0, "dy": -20.0, "from": "right"},
			{"img": "event_priest", "x": 0.455, "h": 187.0, "dy": -18.0, "from": "left", "opt": "Stay awhile and listen"}], "sky": true, "no_hud": true},
	"flying_turtle": {"result_how": {"Help him": "turtle_help"}, "no_hud": true, "center": true, "result_on_stage": true, "props": [{"img": "event_flying_turtle_flipped", "role": "turtle", "x": 0.45, "h": 200.0, "from": "top", "wriggle": true, "opt": "Help him"}]},
	"turtle_falls": {"props": [], "center": true, "result_on_stage": true, "outro": {0: "shell_fall"}},
	"mystery_shack": {"offer_on_stage": true, "offer_keep_props": true, "items_center_x": true, "result_on_stage": true, "result_artifact": true, "item_tags": {"Give each of them a new toy, so they don't have to fight (give 2 artifacts)": "Give each a new toy"},
		"result_how": {"Side with the boy": "boy_wins", "Side with the girl": "girl_wins", "Give each": "toys"},
		"props": [{"img": "event_shed", "x": 0.5, "h": 430.0, "from": "top", "opt": "Give each of them a new toy, so they don't have to fight (give 2 artifacts)", "label": "Give each a new toy"},
			{"img": "event_boy", "role": "boy", "x": 0.34, "h": 260.0, "from": "left", "opt": "Side with the boy"},
			{"img": "event_girl", "role": "girl", "x": 0.66, "h": 260.0, "from": "right", "opt": "Side with the girl"}]},
	"wax_witch": {"voice_open": "witch_blood", "center": true, "offer_on_stage": true, "offer_keep_props": true, "result_on_stage": true, "props": [{"img": "event_witch", "x": 0.5, "h": 530.0, "from": "top", "opt": "Give two drops of blood"},
			{"img": "event_cauldron", "x": 0.385, "h": 180.0, "dy": 10.0, "from": "left", "opt": "Give one drop of blood"}], "night": 0.62},
	"recycler": {"no_hud": true, "items_center_x": true, "item_tags": {"Give him a spell": "Trade this?", "Give him an artifact": "Trade this?", "Give him a bottle": "Trade this?"}, "props": [{"img": "event_recycler_happy", "role": "recycler", "x": 0.45, "h": 510.0, "from": "right", "slow": 5.0, "voice_in": "recycler_reuse", "sfx_in": "shop_cart_roll", "voice_arrive": "recycler_trade"}]},
	"overgrown_vine": {"center": true, "cards_dy": -80.0, "result_on_stage": true, "item_tags": {"Cast a spell to help the tree": "Cast this spell to help the tree"}, "props": [{"img": "event_vine_tree", "role": "tree", "x": 0.42, "h": 530.0, "from": "left"}]},
	"broken_bridge": {"night": 0.62, "result_on_stage": true, "props": [{"img": "event_bridge_stream", "role": "bridge", "x": 0.5, "h": 760.0, "floor_edge": true, "from": "top", "opt": "Jump over it"}]},
	# ---- the older "?" events (batch 2, 2026-11-01): the sheet is docs/events_batch2_plan.csv
	"well": {"voice_open": "well_whisper", "night": 0.35, "center": true, "result_on_stage": true,
		"result_how": {"Toss in": "well_toss", "Drink from": "well_drink", "Jump in": "well_jump"},
		"props": [{"img": "event_well", "role": "well", "x": 0.43, "h": 400.0, "from": "top", "opt": "Jump in"}]},
	"lost_sprite": {"voice_open": "sprite_help_me", "no_hud": true, "center": true, "result_on_stage": true, "result_how": {"Help him": "sprite_help", "Refuse": "sprite_sad"},
		"props": [{"img": "event_fairy", "role": "sprite", "x": 0.463, "h": 60.0, "from": "right", "opt": "Help him confront the monster"},
			{"img": "event_flower", "x": 0.47, "h": 170.0, "from": "right", "opt": "Help him confront the monster"}]},
	"mushroom_ring": {"night": 0.5, "center": true, "result_on_stage": true, "glow": {"event_mushroom_ring": [0.55, 1.0, 0.75]},
		"result_how": {"Eat a mushroom": "mush"},
		"props": [{"img": "event_mushroom_ring", "role": "ring", "x": 0.43, "h": 250.0, "from": "top", "opt": "Eat a mushroom"}]},
	"hollow_stump": {"night": 0.3, "center": true, "result_on_stage": true, "item_tags": {"Throw in a bottle": "Throw this bottle in"},
		"result_how": {"Reach in": "reach", "Throw in a bottle": "throw"},
		"props": [{"img": "event_hollow_stump", "role": "stump", "x": 0.43, "h": 420.0, "from": "top", "opt": "Reach in"}]},
	"bard": {"center": true, "result_on_stage": true, "result_how": {"That's animal": "bard_angry", "It is beautiful": "bard_song", "Pay 100": "bard_lute"},
		"props": [{"img": "event_bard", "role": "bard", "x": 0.43, "h": 300.0, "from": "top", "opt": "It is beautiful", "alt": {"Actually, I don't have that much": "Actually, I don't have that much"}}]},
	"cursed_shrine": {"night": 0.45, "center": true, "result_on_stage": true,
		"result_how": {"Pry the box": "idol_bite", "Take the leaves": "idol_leaves", "Put down": "idol_gift"},
		"props": [{"img": "event_idol_seat", "role": "idol", "x": 0.43, "h": 400.0, "from": "top", "opt": "Pry the box from its mouth"}]},
	"lost_camp": {"night": 0.4, "no_hud": true, "center": true, "result_on_stage": true, "stage_fuse": true, "cursor": "event_torch", "outro": {0: "light"}, "result_how": {"Rest": "bed_toss"},
		"props": [{"img": "event_campfire_off", "role": "pit", "x": 0.37, "h": 420.0, "lit": 0.55, "from": "top", "opt": "Half-cook some spells", "label": "Use torch to half-cook some spells"},
			{"img": "event_tent", "role": "bed", "x": 0.6, "h": 175.0, "lit": 0.55, "from": "right", "opt": "Rest restlessly", "label": "Plant the torch to protect the tent"}]},
	"elemental_fishing": {"underwater_tail": true, "no_hud": true, "night": 0.3, "center": true, "result_on_stage": true,
		"props": [{"img": "event_fisherman", "x": 0.33, "h": 290.0, "dy": -128.0, "from": "left", "opt": "Help him fish", "alt": {"Ready": "Ready"}},
			{"img": "event_stream_wide", "x": 0.5, "w": 1960.0, "h": 150.0, "from": "right", "opt": "Help him fish", "alt": {"Ready": "Ready"}}]},
	"mausoleum": {"night": 0.62, "center": true, "result_on_stage": true,
		"glow": {"event_orb_red": [1.0, 0.3, 0.25], "event_orb_blue": [0.3, 0.55, 1.0], "event_orb_green": [0.35, 1.0, 0.45]},
		"result_how": {"Touch the red": "orb_red", "Touch the blue": "orb_blue", "Touch the green": "orb_green"},
		"props": [{"img": "event_mausoleum_inside", "x": 0.43, "h": 560.0, "from": "top"},
			{"img": "event_orb_red", "role": "orb_red", "x": 0.355, "h": 90.0, "dy": -130.0, "from": "top", "bob": true, "opt": "Touch the red ball"},
			{"img": "event_orb_blue", "role": "orb_blue", "x": 0.43, "h": 90.0, "dy": -200.0, "from": "top", "bob": true, "opt": "Touch the blue ball"},
			{"img": "event_orb_green", "role": "orb_green", "x": 0.505, "h": 90.0, "dy": -130.0, "from": "top", "bob": true, "opt": "Touch the green ball"}]},
	"watchtower": {"no_hud": true, "night": 0.3, "center": true, "result_on_stage": true,
		"result_how": {"A camping": "watch_camp", "A towering": "watch_monster", "The merchant": "watch_cart"},
		"props": [{"img": "event_watchtower", "x": 0.43, "h": 470.0, "from": "top"},
			{"img": "event_tent", "role": "camp", "x": 0.2, "h": 150.0, "from": "left", "opt": "A camping site"},
			{"img": "event_far_giant", "role": "giant", "x": 0.62, "h": 230.0, "from": "right", "opt": "A towering monster"},
			{"img": "event_merchant", "role": "cart", "x": 0.34, "h": 300.0, "dy": -4.0, "from": "left", "opt": "The merchant"}]},
	"skipping_stones": {"no_hud": true, "center": true, "result_on_stage": true, "result_how": {"Skip": "skip"},
		"props": [{"img": "event_lake", "role": "lake", "x": 0.5, "h": 200.0, "from": "right", "opt": "Skip a stone", "alt": {"Skip another stone": "Skip a stone"}},
			{"img": "event_flat_stones", "role": "pile", "x": 0.2, "h": 90.0, "from": "left", "opt": "Skip a stone", "alt": {"Skip another stone": "Skip a stone"}}]},
}
## The maze's cacti, kept between its pages: [{img, x, h, dy, lit}]
static var _forest: Array = []
## Church of Aole: the day goes by one page at a time. Per page: [x, y (fractions of the screen), the shade's alpha, moon]
const SKY := [[0.10, 0.45, 0.0, false], [0.24, 0.24, 0.0, false], [0.42, 0.12, 0.06, false], [0.64, 0.17, 0.2, false],
		[0.84, 0.36, 0.38, false], [0.32, 0.2, 0.55, true], [0.55, 0.12, 0.64, true]]
static var _sky_step := 0
static var _sky_from := Vector2(-1, -1)  # (where the sun / moon stood on the page before, and its shade)
static var _sky_alpha := 0.0
static var _sky_moon := false

var ev: Dictionary = {}
## What the player can give (the options that ask for one of their spells, artifacts or bottles): [{opt, kind (spell / artifact / bottle), id, need, spell (the
## spell's data, for a card)}]. They stand on the stage, glowing; hovering one says what it is for, a click gives it.
var items: Array = []
var act := 1
var on_stage := false
var again := false  # the same event, its next page: the props are already there
var disabled: Array = []  # per option: true = can't be afforded
var _feet := 607.0 + FEET_DY
var _world: Control  # the props, the night, the moon: all under the stage's valance
var _props: Array = []  # {node, opt, label, img (Image for the alpha test), home (Vector2), fly, tag, ph, fi (forest index)}
var _tag: Control
var _hover := -1  # the option under the mouse
var _hover_k := -1  # the prop under the mouse
var _busy := false
var _t := 0.0
var _shell: TextureRect
var _stage: PuppetStage
var _moon: TextureRect
var _owns_night := false
var _owns_water := false  # (the fisherman's tally: the stage is still the sea, and goes back to the act when this page leaves)
var _card_node: SpellCard  # the card a result shows
var _card_after: Dictionary = {}  # what it becomes (the Water that soaks into it)
var _offered_opt := -1
var _offer_back := false  # the items on the stage are what the Recycler gives back: a click takes one
var hidden_opts: Array = []  # options that get no button (the Recycler: nothing to give of that kind)
var _arrival_pending := false
var _cart_snd: AudioStreamPlayer
var run_ref: RunState  # (An Abandoned Camp: the spells to half-cook come from here)
var _fz_ids: Array = []  # the spells on offer while the two to fuse are picked
var _fz_btns: HBoxContainer
var _fz_fuse: Button
var _fz_zoom := 0.62
var edit_allowed := false  # the test room: F6 turns the layout editor on (see _edit_toggle)
var _edit := false
var _sel := -1  # the prop being edited
var _undo: Array = []  # snapshots [{pos, size}] of every prop, before each change
var _drag := ""  # "", "move" or "scale"
var _drag_from := Vector2.ZERO
var _drag_start := {}  # {pos, size} of the selected prop when the drag began
var _edit_box: Control
var continue_label := "Continue"  # ("Fight!" when the result is followed by a fight)
var result_artifact := ""  # the artifact the result gives: its card is shown with the words
var _result_text := ""
var hard_lock := false  # nothing on the stage takes a click (the wax is being dropped)
var _props_locked := false  # the options are being answered with items: the props no longer take clicks
var _offer_tag := ""
var _hint_body: RichTextLabel
var _choice_ui: Array = []  # the buttons and item rows: they go when the result is told
var _item_picks: Dictionary = {}  # opt -> the ids chosen so far (an option can ask for several)
var _item_views: Array = []  # {node, opt, id, tw}


## The name a spoken line is kept under: assets/Puppet/SFX/Event Voice/evv_<first 8 of the md5 of the text shown>.wav (see tools/make_event_voice.py).
static func voice_key(text: String) -> String:
	return "evv_" + text.md5_text().substr(0, 8)


## Say the line that goes with `text` (if it has a voice): the one before is cut off.
static var _line: AudioStreamPlayer

static func speak(text: String) -> void:
	var key := voice_key(text)
	if Audio.has_sfx(key):
		say(key)
		return
	for line in SPOKEN_PARTS:  # (a page whose words change, but with one line in it that is always said: the fisherman's payment)
		if text.contains(line) and Audio.has_sfx(voice_key(line)):
			say(voice_key(line))
			return


## Lines said by their own voice file wherever they appear in a page (tools/make_event_voice.py makes them).
const SPOKEN_PARTS := ["Here, take them, you've earned them."]


## Cut off the line being said (an option was chosen, or Continue pressed: the words are skipped, so is the voice).
static func stop_voice() -> void:
	_cut_line()
	stop_music()


static func _cut_line() -> void:
	if is_instance_valid(_line):
		Audio.stop_held(_line, 0.05)
	_line = null


## A named voice (voice_open / voice_in / voice_arrive) said as the current line, so it can be cut like the others.
static func say(key: String) -> void:
	_cut_line()
	_line = Audio.play_held(key, 2.0)


## A tune that plays over and over from the start of the event (layout "music_open") until the words are skipped, an option is chosen or the stage goes.
static var _tune: AudioStreamPlayer
var _owns_tune := false

static func play_music(key: String) -> void:
	stop_music()
	var p: AudioStreamPlayer = Audio.play_held(key, -2.0)
	if p == null:
		return
	p.finished.disconnect(p.queue_free)  # (it is not freed at its end: it starts again)
	p.finished.connect(func():
		if _tune == p and is_instance_valid(p):
			p.play()
		elif is_instance_valid(p):
			p.queue_free())
	_tune = p


static func stop_music() -> void:
	if is_instance_valid(_tune):
		Audio.stop_held(_tune, 0.15)
	_tune = null


## How long the spoken line of `text` lasts (0: it has none).
static func voice_length(text: String) -> float:
	return Audio.get_sfx_length(voice_key(text))


static func has_layout(id: String) -> bool:
	return LAYOUTS.has(id)


## How the stage plays an option's result ("burn", "shatter", "boy_wins"...): by the first words of the option's label.
static func how_for(id: String, label: String) -> String:
	var table: Dictionary = LAYOUTS.get(id, {}).get("result_how", {})
	for k: String in table:
		if label.begins_with(k):
			return String(table[k])
	return ""


## How the stage plays an option that has several outcomes: the option's word (how_for) made exact by what the words say happened.
static func how_for_result(id: String, label: String, text: String) -> String:
	var how := how_for(id, label)
	match how:
		"mush":
			return "mush_bad" if text.contains("poisonous") else ("mush_great" if text.contains("miraculous") else "mush_good")
		"reach":
			if text.contains("bottle"):
				return "reach_bottle"
			if text.contains("Leaves"):
				return "reach_leaves"
			return "reach_bite" if text.contains("bites") else "reach_artifact"
		"pond_give":  # a spell with Water in its pattern fills the pond; one without leaves it dry
			return "pond_dry" if text.contains("not even WET") else "pond_wet"
		"throw":
			return "throw_fight" if text.contains("coming out") else ("throw_quiet" if text.contains("shatter") else "throw_bottles")
	return how


const HINT_TEXT_W := 412.0
const CENTER_ZOOM := 0.806  # (center: the cards, 30 % bigger than the 0.62 they had)

## center: the item cards stand just under the floor (their top edge on the top edge of the front wall), the buttons under them.
func _center_cards_y() -> float:
	return (_stage.floor_range().y if _stage != null else 654.0) + 100.0 + float(LAYOUTS.get(String(ev.get("id", "")), {}).get("cards_dy", 0.0))  # (100 px under the front wall's top edge)
const HINT_W := HINT_TEXT_W + 36.0 + 34.0  # (the paper frame's margins, as in the fight's hint panel)
const HINT_Y := 170.0
const HINT_X := 1920.0 - HINT_W + 6.0  # (flush with the right edge, like the fight's hint panel)


## The Seedling's hint panel (panel_paper_frame, the sprout and a heading): the box an event tells its story in. It stands where the fight's hint panel does,
## against the right edge under the Leaves' frame. Returns {panel, body}: `body` is the RichTextLabel (set its `text` to change the words).
static func hint_panel(title: String, text: String, px := 0, min_h := 0.0) -> Dictionary:
	var p := PanelContainer.new()
	var paper := UiSkin.box("panel_paper_frame", [46, 46, 46, 46], [36, 28, 34, 34])
	if paper != null:
		p.add_theme_stylebox_override("panel", paper)
	else:
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0.99, 0.95, 0.82)
		sb.border_color = Color(1, 0.75, 0.2)
		sb.set_border_width_all(3)
		sb.set_corner_radius_all(14)
		sb.set_content_margin_all(14)
		p.add_theme_stylebox_override("panel", sb)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.custom_minimum_size = Vector2(HINT_W, min_h)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 4)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_child(v)
	var head := HBoxContainer.new()
	head.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(head)
	var sprout: Control = UiSkin.icon("icon_seedling", 40)
	if sprout != null:
		head.add_child(sprout)
	var who := UiTheme.label(title, 22, Color(0.2, 0.45, 0.15))
	who.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	who.mouse_filter = Control.MOUSE_FILTER_IGNORE
	head.add_child(who)
	var size_px := px if px > 0 else (18 if text.length() <= 350 else (16 if text.length() <= 650 else 15))  # (a long story is set smaller, so the board stays above the player's HUD)
	var r := RichTextLabel.new()
	r.bbcode_enabled = true
	r.fit_content = true
	r.scroll_active = false
	r.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	r.custom_minimum_size = Vector2(HINT_TEXT_W - (28.0 if px > 0 else 0.0), 0)  # (a fixed small size leaves room round the words)
	r.add_theme_font_size_override("normal_font_size", size_px)
	r.add_theme_font_size_override("bold_font_size", size_px)
	r.add_theme_constant_override("line_separation", 2)
	r.add_theme_color_override("default_color", Color(0.14, 0.11, 0.08))
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	r.text = Keywords.colorize(text.replace("\n\n", "\n") if text.length() > 500 else text, true)
	v.add_child(r)
	return {"panel": p, "body": r}


## The game's own wooden panel frame (panel_wood_frame) as the background of a box drawn here; a flat dark box when the art is missing.
static func frame(pad_x := 22, pad_y := 12) -> StyleBox:
	var art := UiSkin.box("panel_wood_frame", [34, 34, 34, 34], [pad_x + 14, pad_y + 12, pad_x + 14, pad_y + 12])
	if art != null:
		return art
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.08, 0.05, 0.04, 0.95)
	sb.border_color = Color(0.75, 0.58, 0.3)
	sb.set_border_width_all(3)
	sb.set_corner_radius_all(14)
	sb.content_margin_left = pad_x
	sb.content_margin_right = pad_x
	sb.content_margin_top = pad_y
	sb.content_margin_bottom = pad_y
	return sb


## The red debuff board as the background of a little box (the hover plaques, the bear's speech).
static func board_box(pad_x := 22, pad_y := 10) -> StyleBox:  # (pads are inside the 24 px rim of the board)
	var m: int = PuppetTopHud.DEBUFF_MARGIN
	var red := UiSkin.box("debuff_board", [m, m, m, m], [pad_x, pad_y, pad_x, pad_y])
	return red if red != null else frame(6, 0)


## The words that tell what a prop does (a little wooden plaque, like the enemies' speech).
static func make_tag(text: String, board := true) -> PanelContainer:
	var bubble := PanelContainer.new()
	bubble.add_theme_stylebox_override("panel", board_box() if board else frame(6, 0))
	bubble.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var l := UiTheme.label(text, 26, Color(1, 0.93, 0.75))
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bubble.add_child(l)
	return bubble


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = UiTheme.get_theme()
	mouse_filter = Control.MOUSE_FILTER_STOP
	var lay: Dictionary = LAYOUTS.get(String(ev.get("id", "")), {})
	var host := get_parent()
	if on_stage and host != null and host.has_method("get_stage") and host.get_stage() != null:
		_stage = host.get_stage()
		_feet = _stage.floor_center_y() + FEET_DY
	if not on_stage:
		var bd := Backdrop.new()
		bd.act = act
		add_child(bd)
	_world = Control.new()
	_world.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_world.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if on_stage:
		_world.z_index = WORLD_Z - (PuppetStage.CEILING_Z + 2)
	add_child(_world)
	var night: float = lay.get("night", 0.0)
	if night > 0.0:
		_make_night(night)
	if lay.get("sky", false):
		_make_sky()
	var entries: Array = lay.get("props", [])
	var forest := int(lay.get("forest", 0))
	if forest > 0:
		if _forest.size() != forest or not again:
			_forest = _make_forest(forest)
		entries = []
		for fi in _forest.size():
			var f: Dictionary = _forest[fi]
			entries.append({"img": f.img, "x": f.x, "h": f.h, "dy": f.dy, "tag": "cactus", "fi": fi, "lit": f.lit})
	var delay_n := 0
	var saved: Dictionary = _saved_layout().get(String(ev.get("id", "")), {}) if forest == 0 else {}
	var ei := -1
	for p: Dictionary in entries:
		ei += 1
		if saved.has(str(ei)):  # (where the test room's editor left it: the new default)
			p = p.duplicate()
			p.merge(saved[str(ei)], true)
			p.erase("floor_edge")
		var tex: Texture2D = UiSkin.tex(String(p.img))
		if tex == null:
			continue  # (no art for it yet: its option shows as a button)
		var h: float = p.h
		var node := TextureRect.new()
		node.texture = tex
		node.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		node.stretch_mode = TextureRect.STRETCH_SCALE
		node.mouse_filter = Control.MOUSE_FILTER_IGNORE
		node.size = Vector2(tex.get_width() * h / tex.get_height() if not p.has("w") else float(p.w), h)  # (w: stretched to that width, a river that runs from edge to edge)
		node.pivot_offset = Vector2(node.size.x / 2.0, node.size.y)
		var lit: float = p.get("lit", 1.0)
		node.modulate = Color(lit, lit, lit)
		var home := Vector2(float(p.x) * 1920.0 - node.size.x / 2.0, _feet - h + float(p.get("dy", 0.0)))
		if p.get("floor_edge", false) and _stage != null:
			# the painted bottom edge of the picture (not its transparent margin) stands on the front edge of the floor
			var im: Image = tex.get_image()
			if im.is_compressed():
				im.decompress()
			var low := float(im.get_used_rect().end.y) / float(im.get_height()) * h
			home.y = _stage.floor_range().y - low
		node.position = home
		if String(lay.get("spot", "")) == String(p.img):
			_add_spot(home + node.size / 2.0, h)
		var glow_node: TextureRect = null
		if lay.get("glow", {}).has(String(p.img)):
			var gc: Array = lay.glow[String(p.img)]
			glow_node = _add_spot(home + node.size / 2.0, h, Color(gc[0], gc[1], gc[2], 0.55))
		_world.add_child(node)
		var opt := _option_of(String(p.get("opt", "")))
		var label := String(p.get("label", p.get("opt", "")))
		if opt < 0:  # (a later page of the event: the same prop stands for another option)
			for k: String in p.get("alt", {}):
				opt = _option_of(k)
				if opt >= 0:
					label = String(p.alt[k])
					break
		if _has_items(opt):
			opt = -1
		_props.append({"node": node, "opt": opt, "label": label, "img": null, "bob": p.get("bob", false), "glow": glow_node, "ei": ei, "home": home, "fly": p.get("fly", false),
			"noflip": p.get("noflip", false), "wriggle": p.get("wriggle", false), "tag": String(p.get("tag", "")), "ph": randf() * TAU, "always": p.get("always", false), "tex": tex,
			"fi": int(p.get("fi", -1)), "lit": lit, "role": String(p.get("role", ""))})
		if not again and float(p.get("slow", 0.0)) > 0.0:
			_arrival_pending = true
			_roll_in(node, home, p)
		elif not again:
			_walk_on(node, home, String(p.get("from", "")), float(p.get("delay", 0.12 * delay_n if forest == 0 else randf() * 0.5)))
			delay_n += 1
	_build_text(lay)
	_build_items(lay)
	if lay.get("underwater_tail", false) and again and _stage != null and _stage.is_underwater():
		_owns_water = true
	if String(lay.get("cursor", "")) != "":
		WoodCursor.override_name = String(lay.cursor)  # (the torch is the pointer in this event)
		WoodCursor.override_owner = self
	var say_in := String(lay.get("voice_open", ""))
	if not again and String(lay.get("music_open", "")) != "":
		play_music(String(lay.music_open))
		_owns_tune = true
	if not again and say_in != "":
		say(say_in)  # (the witch's first words)
	elif String(ev.get("text", "")) != "":
		speak(String(ev.text))
	if _arrival_pending:
		for n in _choice_ui:
			if is_instance_valid(n):
				n.visible = false  # (they come up when he has stopped)
	if not again and not _props.is_empty():
		Audio.play("sfx_scene_prepare_short_%d" % randi_range(1, 4), -4.0)
	for r: Dictionary in _props:
		if r.always:
			_show_tag(r)
	if again and String(ev.get("id", "")) == "skipping_stones" and _skips_in(String(ev.get("text", ""))) > 0:
		_busy = true  # (the stone is still skipping: the next throw waits for it)
		await _skip_hops(_skips_in(String(ev.text)))
		_busy = false


func _exit_tree() -> void:
	if _owns_tune:
		stop_music()
	if _owns_water and _stage != null and is_instance_valid(_stage):
		_stage.set_underwater(false)
	if WoodCursor.override_owner == self:
		WoodCursor.override_name = ""
		WoodCursor.override_owner = null
	_exit_tree_edit()
	_exit_tree_cart()
	if _owns_night and _stage != null and is_instance_valid(_stage):
		_stage.set_night(false)  # (the sun comes back; a page that follows has already taken the night over)


## The stage turns to evening: a bluish shade over it, the sun is put away and a moon rises where it was.
func _make_night(alpha: float) -> void:
	var shade := ColorRect.new()
	shade.color = Color(0.03, 0.05, 0.16, alpha)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_world.add_child(shade)
	if _stage == null:
		return
	for sib in get_parent().get_children():
		if sib is EventStage and sib != self:
			sib._owns_night = false  # (an earlier page of this event: the night is mine now)
	_owns_night = true
	_stage.set_night(true)
	var tex: Texture2D = UiSkin.tex("event_moon")
	if tex != null:
		_moon = TextureRect.new()
		_moon.texture = tex
		_moon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		_moon.stretch_mode = TextureRect.STRETCH_SCALE
		_moon.size = Vector2(tex.get_width() * 170.0 / tex.get_height(), 170.0)
		_moon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_world.add_child(_moon)
		_follow_sun()


## The priest talks from morning till night: on every page the sun climbs and sets and the moon comes, the shade deepens (the sun's own place on the stage is put away).
func _make_sky() -> void:
	_sky_step = _sky_step + 1 if again else 0
	var k: Array = SKY[mini(_sky_step, SKY.size() - 1)]
	var shade := ColorRect.new()
	shade.color = Color(0.03, 0.05, 0.16, _sky_alpha if again else 0.0)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_world.add_child(shade)
	create_tween().tween_property(shade, "color:a", float(k[2]), 1.4)
	var tex_name := "event_moon" if k[3] else "event_sun"
	var tex: Texture2D = UiSkin.tex(tex_name)
	if _stage != null:
		for sib in get_parent().get_children():
			if sib is EventStage and sib != self:
				sib._owns_night = false
		_owns_night = true
		var sun := _stage.sun_node()
		if tex == null and sun != null:
			tex = sun.texture
		_stage.set_night(true)
	if tex != null:
		var body := TextureRect.new()
		body.texture = tex
		body.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		body.stretch_mode = TextureRect.STRETCH_SCALE
		body.size = Vector2(tex.get_width() * 190.0 / tex.get_height(), 190.0)
		body.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var to := Vector2(float(k[0]) * 1920.0, float(k[1]) * 1080.0) - body.size / 2.0
		body.position = to if _sky_from.x < 0.0 or not again else _sky_from - body.size / 2.0
		_world.add_child(body)
		if again and _sky_from.x >= 0.0:
			var tw := create_tween()
			tw.tween_property(body, "position", to, 1.4).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		if k[3] and not _sky_moon and again:
			body.modulate.a = 0.0  # (the moon rises as the sun has gone)
			create_tween().tween_property(body, "modulate:a", 1.0, 1.4)
	_sky_from = Vector2(float(k[0]) * 1920.0, float(k[1]) * 1080.0)
	_sky_alpha = float(k[2])
	_sky_moon = k[3]


func _follow_sun() -> void:
	if _moon == null or _stage == null:
		return
	var sun := _stage.sun_node()
	if sun != null:
		_moon.position = sun.global_position + Vector2(0, -65.0) - _moon.size / 2.0


## A maze of cacti: `n` of the five, any size, some far back (smaller, darker) and some near, standing between one another. [{img, x, h, dy, lit}]
func _make_forest(n: int) -> Array:
	var near_dy := 30.0  # (feet never below the front edge of the floor, never above its far edge)
	var far_dy := -55.0
	if _stage != null:
		var fr := _stage.floor_range()
		far_dy = fr.x + 30.0 - _feet
		near_dy = fr.y - 14.0 - _feet
	var names: Array = CACTI.keys()
	var out: Array = []
	var xs: Array = []
	for i in n:
		xs.append(0.06 + 0.7 * (float(i) + randf_range(0.1, 0.9)) / float(n))  # (the hint panel stands on the right)
	xs.shuffle()
	for i in n:
		var img: String = names[i % names.size()]
		var depth := randf()  # 0 = far back, 1 = near
		var k := lerpf(0.62, 1.1, depth) * randf_range(0.85, 1.15)
		out.append({"img": img, "x": xs[i], "h": minf(float(CACTI[img]) * k, 480.0), "dy": lerpf(far_dy, near_dy, depth), "lit": lerpf(0.62, 1.0, depth)})
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a.dy) < float(b.dy))  # (far ones first: the near ones stand over them)
	return out


## The size of the item cards (the same in _build_items): as big as the row of them allows.
func _items_zoom(centered: bool) -> float:
	var n_spells := 0
	var n_others := 0
	for it: Dictionary in items:
		if it.kind == "spell":
			n_spells += 1
		else:
			n_others += 1
	return clampf(((1300.0 if centered else 1400.0) - float(n_others) * 100.0 - 40.0) / maxf(1.0, float(n_spells) * (SpellCard.W + 8.0)), 0.4, CENTER_ZOOM if centered else 0.55)


## An option that was chosen on a prop (the witch, the shed) now asks for an item: `entries` (the same as `items`) stand on the stage, glowing, and the
## props stop taking clicks. `tag` is what a hover says.
func offer_items(entries: Array, tag: String) -> void:
	_hide_tag()
	_hover = -1
	for n in _choice_ui:
		if is_instance_valid(n):
			n.queue_free()
	_choice_ui.clear()
	for r: Dictionary in _item_views:
		if is_instance_valid(r.node):
			(r.node as Control).queue_free()
	_item_views.clear()
	_item_picks.clear()
	items = entries
	_offer_tag = tag
	_props_locked = true
	_offered_opt = int(entries[0].opt) if not entries.is_empty() else -1
	_busy = false
	_build_items(LAYOUTS.get(String(ev.get("id", "")), {}))
	for r: Dictionary in _props:
		if is_instance_valid(r.node):
			(r.node as Control).modulate = Color(r.lit, r.lit, r.lit)
			(r.node as Control).scale = Vector2.ONE


## The words of the hint panel are changed (the wax: what to click, what is sealed).
func set_hint(text: String) -> void:
	if _hint_body != null:
		_hint_body.text = Keywords.colorize(text, true)


## The Recycler takes the item `give_id` (it shrinks into him), the other items fade, and he hands back the `offer` entries (they come out of him into the row):
## a click on one emits `traded`. The words of the hint panel become `say`.
func trade(give_id: String, offer: Array, say: String) -> void:
	_busy = true
	_hide_tag()
	var rec := _prop_role("recycler")
	var mouth := Vector2(960.0, 330.0)
	if not rec.is_empty():
		var n: TextureRect = rec.node
		mouth = n.position + Vector2(n.size.x * 0.5, n.size.y * 0.5)
	var given: Control = null
	for r: Dictionary in _item_views:
		if r.id == give_id and given == null:
			given = r.node
		else:
			var f := create_tween()
			f.tween_property(r.node, "modulate:a", 0.0, 0.4)
	if given != null:
		var gp := given.get_global_rect().get_center()
		var par := given.get_parent()
		if par != null:
			par.remove_child(given)
		add_child(given)
		given.z_index = 50
		given.pivot_offset = given.size / 2.0
		given.position = gp - given.size / 2.0
		given.mouse_filter = Control.MOUSE_FILTER_IGNORE
		Audio.play("sfx_port_pop", -2.0)
		var tw := create_tween().set_parallel(true)
		tw.tween_property(given, "position", mouth - given.size / 2.0, 0.6).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tw.tween_property(given, "scale", Vector2.ONE * 0.12, 0.6).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tw.tween_property(given, "modulate:a", 0.0, 0.25).set_delay(0.4)
		await tw.finished
	for n in _choice_ui:
		if is_instance_valid(n):
			n.queue_free()
	_choice_ui.clear()
	for r: Dictionary in _item_views:
		if is_instance_valid(r.node):
			(r.node as Control).queue_free()
	_item_views.clear()
	if _hint_body != null:
		_hint_body.text = Keywords.colorize(say, true)
	_hover = -1
	items = offer
	_offer_tag = "Take this one"
	_offer_back = true
	_props_locked = true
	_offered_opt = int(offer[0].opt) if not offer.is_empty() else -1
	_build_items(LAYOUTS.get(String(ev.get("id", "")), {}))
	await get_tree().process_frame
	await get_tree().process_frame
	var k := 0
	for r: Dictionary in _item_views:
		var v: Control = r.node
		var home := v.get_global_rect().position
		var par2 := v.get_parent()
		var final_scale := v.scale
		if par2 != null:
			par2.remove_child(v)
		add_child(v)
		v.z_index = 50
		v.pivot_offset = v.size / 2.0
		v.position = mouth - v.size / 2.0
		v.scale = Vector2.ONE * 0.12
		v.modulate.a = 0.0
		var o := create_tween().set_parallel(true)
		o.tween_callback(func(): Audio.play("shop_card_pop", -4.0)).set_delay(0.25 * k)
		o.tween_property(v, "position", home, 0.55).set_delay(0.25 * k).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		o.tween_property(v, "scale", final_scale, 0.55).set_delay(0.25 * k).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		o.tween_property(v, "modulate:a", 1.0, 0.2).set_delay(0.25 * k)
		k += 1
	await get_tree().create_timer(0.25 * k + 0.6).timeout
	_busy = false


## The Recycler's three: the one taken grows to the size a hovered card has and stays, the other two are gone.
func present(take_id: String) -> void:
	var k := minf(1.0 / _items_zoom(false), 2.2)
	var done := false
	for r: Dictionary in _item_views:
		var v: Control = r.node
		if not is_instance_valid(v):
			continue
		if r.id == take_id and not done:
			done = true
			if r.tw != null:
				(r.tw as Tween).kill()
			v.mouse_filter = Control.MOUSE_FILTER_IGNORE
			v.modulate = Color.WHITE
			v.z_index = 60
			if v is SpellCard and is_instance_valid((v as SpellCard)._zoom):
				(v as SpellCard)._zoom.queue_free()  # (its hover copy goes: this is the enlarged card itself)
			var k2 := k if v is SpellCard else 1.7
			var tw := create_tween().set_parallel(true)
			tw.tween_property(v, "scale", Vector2.ONE * k2, 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			tw.tween_property(v, "position:y", v.position.y - 40.0, 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		else:
			var f := create_tween()
			f.tween_property(v, "modulate:a", 0.0, 0.3)
			f.tween_callback(v.queue_free)


## The item cards go (while something is done on one of them) ...
func hide_items(on := true) -> void:
	for r: Dictionary in _item_views:
		if is_instance_valid(r.node):
			(r.node as Control).visible = not on


func _has_items(opt: int) -> bool:
	for it: Dictionary in items:
		if int(it.opt) == opt:
			return true
	return false


## The player's spells (cards), artifacts and bottles that the options of this page ask for, standing under the stage, glowing on and off. A hover tells what
## it is for, a click gives it.
func _build_items(lay: Dictionary) -> void:
	if items.is_empty():
		return
	var y := 664.0
	if _stage != null:
		y = _stage.floor_range().y + 10.0
	var centered: bool = lay.get("center", false)
	if centered:
		y = _center_cards_y()
	var spells: Array = items.filter(func(it: Dictionary) -> bool: return it.kind == "spell")
	var others: Array = items.filter(func(it: Dictionary) -> bool: return it.kind != "spell")
	var tags: Dictionary = lay.get("item_tags", {})
	var opts: Array = ev.get("options", [])
	# one row: the spell cards, a gap, then the artifacts and bottles (so the buttons of the other options keep their place under it)
	var row := HBoxContainer.new()
	row.anchor_left = 0.0
	row.anchor_right = 0.0
	row.offset_left = 20.0
	row.offset_right = 1900.0  # (every row of items is centred on the screen, whatever the layout)
	row.offset_top = y
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 8)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(row)
	_choice_ui.append(row)
	var zoom := clampf(((1300.0 if centered else 1400.0) - float(others.size()) * 100.0 - 40.0) / maxf(1.0, float(spells.size()) * (SpellCard.W + 8.0)), 0.4, CENTER_ZOOM if centered else 0.55)
	var k := 0
	var gap_done := others.is_empty() or spells.is_empty()
	for it: Dictionary in spells + others:
		if not gap_done and it.kind != "spell":
			var gap := Control.new()
			gap.custom_minimum_size = Vector2(32, 1)
			gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
			row.add_child(gap)
			gap_done = true
		var label := String(opts[int(it.opt)].label)
		var tag_text := _offer_tag if _offer_tag != "" else String(tags.get(label, label))
		var view: Control
		if it.kind == "spell":
			var card := SpellCard.make(it.spell)
			card.zoom = zoom
			card.clicked.connect(func(_c): _item_click(it))
			view = card
		else:
			view = _item_icon(it)
		row.add_child(view)
		view.mouse_entered.connect(func(): _item_hover(view, tag_text, true))
		view.mouse_exited.connect(func(): _item_hover(view, tag_text, false))
		if lay.get("flame", false) and view is SpellCard:
			view.mouse_entered.connect(func(): _burn_card(view, true))  # (the card's own hover has run first: its enlarged copy exists)
			view.mouse_exited.connect(func(): _burn_card(view, false))
		var rec := {"node": view, "opt": int(it.opt), "id": String(it.id), "tw": null}
		_item_views.append(rec)
		_pulse_item(rec, k)
		k += 1


## An artifact or a bottle as a small picture in a frame.
func _item_icon(it: Dictionary) -> Control:
	var box := Button.new()
	box.focus_mode = Control.FOCUS_NONE
	box.custom_minimum_size = Vector2(88, 88)
	box.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	box.add_theme_stylebox_override("normal", frame(4, 4))
	box.add_theme_stylebox_override("hover", frame(4, 4))
	box.add_theme_stylebox_override("pressed", frame(4, 4))
	box.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	var art: Control = UiSkin.artifact_icon(String(it.id), 72) if it.kind == "artifact" else UiSkin.icon(String(it.id), 72)
	if art != null:
		art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 10)
		box.add_child(art)
	else:
		box.text = String(it.id).replace("_", " ")
	box.pressed.connect(func(): _item_click(it))
	return box


## A card burns (the flame the enemies set on a spell, around the card and its enlarged copy) while the mouse is on it.
func _burn_card(card: SpellCard, on: bool) -> void:
	if not is_instance_valid(card) or card.ignited == on:
		return
	card.ignited = on
	card.refresh()
	if on and is_instance_valid(card._zoom):
		card._sync_zoom()


func _pulse_item(rec: Dictionary, k: int) -> void:
	var n: Control = rec.node
	var tw := n.create_tween().set_loops()
	tw.tween_property(n, "modulate", Color(1, 1, 1), 0.0).set_delay(0.12 * k)
	tw.tween_property(n, "modulate", Color(1.4, 1.32, 1.05), 0.55).set_trans(Tween.TRANS_SINE)
	tw.tween_property(n, "modulate", Color(1, 1, 1), 0.55).set_trans(Tween.TRANS_SINE)
	rec["tw"] = tw


func _item_hover(view: Control, text: String, on: bool) -> void:
	if _busy:
		return
	var rec := {}
	for r: Dictionary in _item_views:
		if r.node == view:
			rec = r
	_hide_tag()
	if rec.is_empty() or rec.get("taken", false):
		return
	if on:
		if rec.get("tw") != null:
			(rec.tw as Tween).kill()
		view.modulate = Color(1.5, 1.4, 1.1)
		Audio.play("ui_hover", -8.0)
		_tag = make_tag(text, true)
		_tag.z_index = 4000
		add_child(_tag)
		await get_tree().process_frame
		if is_instance_valid(_tag) and is_instance_valid(view):
			var src: Control = view  # (a spell card grows when it is hovered: the plaque stands above the enlarged copy, never under it)
			if view is SpellCard and is_instance_valid((view as SpellCard)._zoom):
				src = (view as SpellCard)._zoom
			var r := src.get_global_rect()
			if src != view:
				r = Rect2(src.position, src.size)  # (the enlarged copy's FINAL box: it is still growing, its scale is small this frame)
			_tag.position = Vector2(clampf(r.get_center().x - _tag.size.x / 2.0, 10.0, 1910.0 - _tag.size.x), maxf(r.position.y - _tag.size.y - 10.0, 6.0))
	else:
		_pulse_item(rec, 0)


func _item_click(it: Dictionary) -> void:
	if _busy:
		return
	if _offer_back:
		_busy = true
		_hide_tag()
		Audio.play("ui_click")
		traded.emit(String(it.id))
		return
	var opt := int(it.opt)
	var picks: Array = _item_picks.get(opt, [])
	for r: Dictionary in _item_views:
		if r.id == String(it.id) and r.opt == opt and not r.get("taken", false) and picks.size() < int(it.need):
			r["taken"] = true
			if r.tw != null:
				(r.tw as Tween).kill()
			(r.node as Control).modulate = Color(0.45, 0.45, 0.45)
			(r.node as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
			picks.append(String(it.id))
			break
	_item_picks[opt] = picks
	var lay: Dictionary = LAYOUTS.get(String(ev.get("id", "")), {})
	var sfx := String(lay.get("item_sfx", ""))
	Audio.play(sfx if sfx != "" else "ui_click")
	if picks.size() >= int(it.need):
		_busy = true
		stop_voice()
		_hide_tag()
		if sfx != "":
			await get_tree().create_timer(0.9).timeout  # (the card burns for a moment)
		item_picked.emit(opt, picks)


## What the chosen option did, told on the stage itself: the choices go, the words replace the hint panel's story, (how: the cacti burn away, or break to pieces), and
## a Continue button comes up. `how`: "burn" (the cacti catch fire) or "shatter" (they break to pieces). `continued` is emitted when it is pressed.
func show_result(text: String, how := "", keep_items := false, card := {}, card_before := {}) -> void:
	_busy = true
	_result_text = text
	_hide_tag()
	for n in _choice_ui:
		if is_instance_valid(n):
			n.queue_free()
	_choice_ui.clear()
	if not keep_items:
		for r: Dictionary in _item_views:
			if is_instance_valid(r.node):
				(r.node as Control).queue_free()
		_item_views.clear()
	if _hint_body != null:
		_hint_body.text = Keywords.colorize(text, true)
	speak(text)
	if not card.is_empty():  # (a spell you learned: its card stands where the items stood)
		var c := SpellCard.make(card_before if not card_before.is_empty() else card)  # (a card that is about to change shows how it was)
		c.zoom = CENTER_ZOOM
		c.set_anchors_preset(Control.PRESET_TOP_LEFT)
		c.position = Vector2(960.0 - SpellCard.W * CENTER_ZOOM / 2.0, _center_cards_y() - 150.0)  # (up, so Continue does not cover it)
		_card_node = c
		_card_after = card if not card_before.is_empty() else {}
		c.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(c)
		_item_views.append({"node": c, "opt": -1, "id": "", "tw": null})
	if how == "burn":
		await _burn_props()
	elif how == "shatter":
		Audio.play("sfx_hurt_grunt", 0.0)  # (the thorns hurt)
		await _shatter_props()
	elif how in ["boy_wins", "girl_wins", "toys"]:
		await _shed_scene(how)
	elif how.begins_with("vine_") or how.begins_with("bridge_") or how.begins_with("turtle_"):
		await _react(how)
	elif how != "":
		await _react_more(how)
	if result_artifact != "" and card.is_empty():  # (an artifact you were given: its card stands where the items stood)
		var ac := ArtifactCard.make(Artifacts.view(result_artifact, false))
		ac.set_anchors_preset(Control.PRESET_TOP_LEFT)
		ac.scale = Vector2.ONE * 0.8
		ac.position = Vector2(960.0 - ArtifactCard.W * 0.4, _center_cards_y() - 150.0)
		ac.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(ac)
		_item_views.append({"node": ac, "opt": -1, "id": "", "tw": null})
	var lay: Dictionary = LAYOUTS.get(String(ev.get("id", "")), {})
	var row := HBoxContainer.new()
	row.anchor_left = 0.0
	row.anchor_right = 1.0
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if lay.get("center", false):
		row.offset_top = _center_cards_y() + 40.0
	else:
		row.anchor_top = 1.0
		row.anchor_bottom = 1.0
		row.offset_bottom = -222.0
		row.grow_vertical = Control.GROW_DIRECTION_BEGIN
	var b := UiTheme.button(continue_label, func(): stop_voice(); continued.emit(), 22)
	b.custom_minimum_size = Vector2(0, 52)
	row.add_child(b)
	add_child(row)
	row.modulate.a = 0.0
	create_tween().tween_property(row, "modulate:a", 1.0, 0.3)


## The tree and the bridge react to what you did, right on the stage.
func _react(how: String) -> void:
	var tree := _prop_role("tree")
	var bridge := _prop_role("bridge")
	var bush := _prop_role("bush")
	match how:
		"vine_damage":  # a blast: the tree shakes, the vine is gone, and Leaves fall
			_shake_prop(tree, 0.07, 8)
			Audio.play("sfx_damage_hit", -2.0)
			_shake(8.0)
			await get_tree().create_timer(0.55).timeout
			_swap_pic(tree, "event_tree_free")
			_flash(tree, Color(1.5, 1.3, 0.9))
			Audio.play("sfx_coin_bag_spill", 0.0)  # (the same bag of coins as the bear's)
			_leaf_fall(tree, 14)
		"vine_defense":  # a barrier: the tree shakes, the vine is gone, and its fruit heals you (the hearts fly down to the HP bar)
			_shake_prop(tree, 0.04, 6)
			Audio.play("sfx_aegis_up", -2.0)
			await get_tree().create_timer(0.55).timeout
			_swap_pic(tree, "event_tree_free")
			_flash(tree, Color(0.8, 1.2, 1.5))
			_heal_flight(tree)
		"vine_utility":  # it does nothing: the tree does not move or change
			pass
		"turtle_help":  # you flip him over: he lands on his feet with a thud, shakes himself and flies off
			var tr := _prop_role("turtle")
			if not tr.is_empty():
				tr["gone"] = true
				var tn: TextureRect = tr.node
				_swap_pic(tr, "event_flying_turtle_front")
				tn.pivot_offset = tn.size / 2.0
				tn.rotation = PI
				var ttw := create_tween()
				ttw.tween_property(tn, "rotation", TAU, 0.55).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
				ttw.tween_callback(func():
					tn.rotation = 0.0
					Audio.play("wooden_ball_colide", 0.0, 0.7)
					_shake(10.0))
				ttw.tween_interval(0.6)
				ttw.tween_property(tn, "position", Vector2(1920.0 + 160.0, 80.0), 1.3).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
				await ttw.finished
		"bridge_ok":  # across: the bridge springs
			if not bridge.is_empty():
				var n2: TextureRect = bridge.node
				var tw2 := create_tween()
				tw2.tween_property(n2, "scale", Vector2(1.04, 0.97), 0.1)
				tw2.tween_property(n2, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			_flash(bridge, Color(1.3, 1.25, 0.9))
			Audio.play("sfx_draw_element", 0.0)  # (the game's own Essence reward sound)
			await _reward_flight(bridge)
		"bridge_fail":  # the bog: the bridge dips and the water splashes
			_shake_prop(bridge, 0.03, 6)
			if not bridge.is_empty():
				var n3: TextureRect = bridge.node
				var tw3 := create_tween()
				tw3.tween_property(n3, "position:y", n3.position.y + 26.0, 0.15)
				tw3.tween_property(n3, "position:y", n3.position.y, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			Audio.play("sfx_water_splash", 0.0)  # (into the bog)
			_shake(10.0)
			await get_tree().create_timer(0.8).timeout
			await _soak_flight(bridge)
		"bridge_around":  # the thorns: the bush rustles
			_shake_prop(bush, 0.08, 8)
			Audio.play("sfx_bleed_tick", -4.0)
	await get_tree().create_timer(1.3).timeout


## The older "?" events (batch 2) answer what you did on the stage itself: `how` is the stage's word for it (see LAYOUTS "result_how" and how_for_result).
func _react_more(how: String) -> void:
	var well := _prop_role("well")
	var stump := _prop_role("stump")
	var idol := _prop_role("idol")
	var bard := _prop_role("bard")
	match how:
		"well_toss":  # the leaves go down the well, then two bottles float up and fly to you
			Audio.play("sfx_coin_bag_spill", -2.0)
			await _fly_icons("icon_amber", PuppetTopHud.TRAY.get_center(), _center_of(well) + Vector2(0, -120), 9, 38.0)
			Audio.play("sfx_water_splash", 0.0)
			_shake_prop(well, 0.02, 4)
			await get_tree().create_timer(0.5).timeout
			Audio.play("sfx_draw_element", -2.0)
			await _fly_icons(_bottle_tex(), _center_of(well) + Vector2(0, -150), PuppetTopHud.TRAY.get_center(), 2, 60.0)
		"well_drink":  # it was not water
			_shake_prop(well, 0.04, 6)
			_flash(well, Color(0.6, 1.3, 0.5))
			Audio.play("sfx_hurt_grunt", -4.0)
			_shake(6.0)
		"well_jump":  # a splash, a crack of bone, the cursed treasure
			_shake_prop(well, 0.03, 6)
			Audio.play("sfx_water_splash", 2.0)
			_shake(14.0)
			await get_tree().create_timer(0.6).timeout
			Audio.play("event_bite", -4.0, 0.7)
		"pond_wet":  # the pond fills up and the wisp splashes about
			var pond := _prop_role("pond")
			_swap_pic(pond, "event_pond_full")
			Audio.play("sfx_water_splash", 0.0)
			_flash(pond, Color(0.8, 1.2, 1.5))
			_hop(_prop_role("wisp"), 3)
			await get_tree().create_timer(0.8).timeout
		"pond_dry":  # still dry: the wisp splutters
			_shake_prop(_prop_role("wisp"), 0.07, 8)
			Audio.play("sfx_hurt_grunt", -4.0, 1.3)
		"sprite_help":  # he shoots up, ready for a fight
			var sp := _prop_role("sprite")
			if not sp.is_empty():
				sp["gone"] = true
				var tw := create_tween().set_parallel(true)
				tw.tween_property(sp.node, "position:y", float((sp.node as Control).position.y) - 70.0, 0.5).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
				tw.tween_property(sp.node, "scale", Vector2.ONE * 1.25, 0.5)
			Audio.play("sfx_aegis_up", -2.0)
			_flash(sp, Color(1.4, 1.4, 1.6))
		"sprite_sad":  # he stops crying and drifts off, small and quiet
			var sp2 := _prop_role("sprite")
			if not sp2.is_empty():
				sp2["gone"] = true
				_run_off(sp2, 2.4, 6.0, true)
		"mush_bad", "mush_good", "mush_great":
			var ring := _prop_role("ring")
			Audio.play("event_mushroom_bite", -2.0)
			_shake_prop(ring, 0.03, 4)
			await get_tree().create_timer(0.35).timeout
			if how == "mush_bad":
				_flash(ring, Color(0.6, 1.2, 0.4))
				Audio.play("sfx_hurt_grunt", -4.0)
				_shake(8.0)
			else:
				_flash(ring, Color(1.5, 1.4, 0.8) if how == "mush_great" else Color(1.3, 1.25, 1.0))
				if how == "mush_great":
					Audio.play("sfx_aegis_up", 0.0)
				await _heal_flight(ring)
		"reach_bottle":
			Audio.play("event_stump_knock", -2.0)
			_shake_prop(stump, 0.03, 4)
			await get_tree().create_timer(0.4).timeout
			Audio.play("sfx_draw_element", -2.0)
			await _fly_icons(_bottle_tex(), _center_of(stump), PuppetTopHud.TRAY.get_center(), 1, 60.0)
		"reach_leaves":
			Audio.play("event_stump_knock", -2.0)
			_shake_prop(stump, 0.03, 4)
			Audio.play("sfx_coin_bag_spill", 0.0)
			_leaf_fall(stump, 12)
		"reach_bite":
			Audio.play("event_stump_knock", -2.0)
			_shake_prop(stump, 0.07, 8)
			_flash(stump, Color(1.5, 0.8, 0.8))
			Audio.play("event_bite", 0.0)
			Audio.play("sfx_hurt_grunt", -2.0)
			_shake(12.0)
		"reach_artifact":
			Audio.play("event_stump_knock", -2.0)
			_shake_prop(stump, 0.03, 4)
			_flash(stump, Color(1.5, 1.4, 0.8))
			Audio.play("sfx_aegis_up", 0.0)
		"throw_fight":  # something mean in there
			Audio.play("event_glass_break", -3.0)
			await get_tree().create_timer(0.35).timeout
			_shake_prop(stump, 0.08, 10)
			_flash(stump, Color(1.5, 0.7, 0.7))
			Audio.play("sfx_hurt_grunt", -2.0, 0.7)
			_shake(14.0)
		"throw_quiet":  # a long way down
			Audio.play("event_glass_break", -14.0, 0.8)
		"throw_bottles":  # three broken ones come flying back
			Audio.play("event_glass_break", -3.0)
			await get_tree().create_timer(0.4).timeout
			_shake_prop(stump, 0.05, 6)
			await _fly_icons(_bottle_tex(), _center_of(stump), PuppetTopHud.TRAY.get_center(), 3, 56.0, Color(0.7, 0.7, 0.7))
		"bard_angry":  # a sour chord
			Audio.play("event_lute_sour", 0.0)
			_shake_prop(bard, 0.07, 12)
			_flash(bard, Color(1.5, 0.8, 0.8))
			_shake(10.0)
		"bard_song":  # a little song
			_hop(bard, 2)
			await get_tree().create_timer(0.8).timeout
			await _heal_flight(bard)
		"bard_lute":  # the lute is yours
			var lute := _prop_role("lute")
			Audio.play("sfx_coin_bag_spill", 0.0)
			await _fly_icons("icon_amber", PuppetTopHud.TRAY.get_center(), _center_of(bard), 8, 36.0)
			if not lute.is_empty():
				lute["gone"] = true
				var tw2 := create_tween().set_parallel(true)
				tw2.tween_property(lute.node, "position", PuppetTopHud.TRAY.get_center() - (lute.node as Control).size / 2.0, 0.8).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
				tw2.tween_property(lute.node, "scale", Vector2.ONE * 0.3, 0.8)
				tw2.tween_property(lute.node, "modulate:a", 0.0, 0.3).set_delay(0.5)
		"idol_bite", "idol_leaves":
			_shake_prop(idol, 0.05, 5)
			Audio.play("event_bite", 0.0)
			Audio.play("sfx_hurt_grunt", -3.0)
			_flash(idol, Color(1.5, 0.8, 0.8))
			_shake(14.0)
			if how == "idol_leaves":
				await get_tree().create_timer(0.5).timeout
				Audio.play("sfx_coin_bag_spill", 0.0)
				await _fly_icons("icon_amber", _center_of(idol) + Vector2(0, 90), PuppetTopHud.TRAY.get_center(), 10, 36.0)
		"idol_gift":  # the leaves go into the bowl, and the jaw lets go
			Audio.play("sfx_coin_bag_spill", 0.0)
			await _fly_icons("icon_amber", PuppetTopHud.TRAY.get_center(), _center_of(idol) + Vector2(0, 90), 10, 36.0)
			await get_tree().create_timer(0.3).timeout
			_shake_prop(idol, 0.03, 4)
			_flash(idol, Color(1.4, 1.3, 0.9))
			Audio.play("wooden_ball_colide", 0.0, 1.2)
		"bed_toss":  # the torch is planted beside the tent (the pointer is the arrow again), and you sleep soundly
			_drop_torch_cursor()
			var bed := _prop_role("bed")
			_swap_pic(bed, "event_tent_torch")
			if not bed.is_empty():
				bed["lit"] = 1.0
				(bed.node as Control).modulate = Color(1.6, 1.4, 1.2)
				create_tween().tween_property(bed.node, "modulate", Color.WHITE, 0.6)
			Audio.play("wooden_ball_colide", 0.0, 0.8)
			_shake(6.0)
			Audio.play("sfx_cocoon_roll", -6.0)
			_shake_prop(bed, 0.015, 4)
			await get_tree().create_timer(0.6).timeout
			await _heal_flight(bed)
		"orb_red", "orb_blue", "orb_green":
			await _orb_touch(how)
		"watch_camp":  # smoke rises from the camp
			var camp := _prop_role("camp")
			_hop(camp, 2)
			_flash(camp, Color(1.3, 1.25, 1.0))
			Audio.play("sfx_scene_prepare_short_1", -3.0)
		"watch_monster":  # it has seen you
			var giant := _prop_role("giant")
			_shake_prop(giant, 0.03, 8)
			for i in 3:
				Audio.play("wooden_ball_colide", 2.0, 0.55)
				_shake(14.0)
				await get_tree().create_timer(0.4).timeout
		"watch_cart":  # the cart rolls over to you
			var cart := _prop_role("cart")
			if not cart.is_empty():
				cart["gone"] = true
				var snd := Audio.play_held("shop_cart_roll", -3.0)
				var tw3 := create_tween().set_parallel(true)
				tw3.tween_property(cart.node, "position:x", 960.0 - (cart.node as Control).size.x / 2.0, 1.2).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
				await tw3.finished
				Audio.stop_held(snd, 0.2)
		"skip":  # the last throw of the lake (20 skips or more: the spirit's gift)
			await _skip_hops(_skips_in(_result_text))
	await get_tree().create_timer(1.0).timeout


## The three lights: the one you touch flies into you and does its thing; the other two go out.
func _orb_touch(how: String) -> void:
	var mine := _prop_role(how)
	for r: Dictionary in _props:
		if String(r.role).begins_with("orb_"):
			r["gone"] = true
			if r.role != how:
				create_tween().tween_property(r.node, "modulate:a", 0.0, 0.6)
				if r.glow != null:
					create_tween().tween_property(r.glow, "modulate:a", 0.0, 0.6)
	if mine.is_empty():
		return
	var n: TextureRect = mine.node
	n.pivot_offset = n.size / 2.0
	if how == "orb_red":
		await _heal_flight(mine)
	elif how == "orb_blue":
		Audio.play("sfx_aegis_up", 0.0)
	else:
		Audio.play("sfx_draw_element", 0.0)
	var tw := create_tween().set_parallel(true)
	if mine.glow != null:
		tw.tween_property(mine.glow, "position", PuppetTopHud.TRAY.get_center() - (mine.glow as Control).size / 2.0, 0.9).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tw.tween_property(mine.glow, "modulate:a", 0.0, 0.9)
	var to := PuppetTopHud.TRAY.get_center() - n.size / 2.0
	tw.tween_property(n, "position", to, 0.9).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_property(n, "scale", Vector2.ONE * 0.3, 0.9)
	tw.tween_property(n, "modulate:a", 0.0, 0.25).set_delay(0.7)
	await tw.finished
	_shake(6.0)


func _center_of(r: Dictionary) -> Vector2:
	if r.is_empty():
		return Vector2(960, 500)
	var n: Control = r.node
	return n.position + n.size / 2.0


## A name of a bottle's picture that exists (the broken ones have none of their own).
func _bottle_tex() -> String:
	return "water_flask" if UiSkin.tex("water_flask") != null else "icon_heart"


## `n` small pictures fly one after another from `from` to `to` along a bent path (awaits the last of them).
func _fly_icons(tex_name: String, from: Vector2, to: Vector2, n: int, px: float, tint := Color.WHITE) -> void:
	var tex: Texture2D = UiSkin.tex(tex_name)
	if tex == null:
		return
	for i in n:
		var c := TextureRect.new()
		c.texture = tex
		c.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		c.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		c.size = Vector2(px, px)
		c.pivot_offset = c.size / 2.0
		c.mouse_filter = Control.MOUSE_FILTER_IGNORE
		c.z_index = 40
		c.modulate = Color(tint.r, tint.g, tint.b, 0.0)
		c.position = from - c.size / 2.0
		add_child(c)
		var bend := Vector2(randf_range(-140.0, 140.0), randf_range(-170.0, -40.0))
		var tw := create_tween()
		tw.tween_interval(0.1 * i)
		tw.tween_property(c, "modulate:a", 1.0, 0.06)
		tw.tween_method(func(v: float) -> void:
			var mid := (from + to) / 2.0 + bend
			c.position = from.lerp(mid, v).lerp(mid.lerp(to, v), v) - c.size / 2.0, 0.0, 1.0, 0.8).set_trans(Tween.TRANS_SINE)
		tw.tween_property(c, "modulate:a", 0.0, 0.1)
		tw.tween_callback(c.queue_free)
	await get_tree().create_timer(0.1 * n + 1.0).timeout


## How many times the stone skipped, from the lake's words (0: none told).
static func _skips_in(text: String) -> int:
	var m := RegEx.create_from_string("skips (\\d+) time").search(text)
	return int(m.get_string(1)) if m != null else 0


## Where the marks of star_end_skipping.png lie on the lake picture (fractions of its size): the stone first touches the water at SKIP_START_X and stops at SKIP_END_X, along SKIP_AT_Y.
const SKIP_START_X := 0.1363
const SKIP_END_X := 0.8620
const SKIP_AT_Y := 0.3805


## One of the three water splashes (Events/skip_splash_N) standing on the water at `at`, `h` px tall: it pops up and fades.
func _water_splash(at: Vector2, h: float) -> void:
	var tex: Texture2D = UiSkin.tex("skip_splash_%d" % randi_range(1, 3))
	if tex == null:
		return
	var sp := TextureRect.new()
	sp.texture = tex
	sp.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	sp.stretch_mode = TextureRect.STRETCH_SCALE
	sp.size = Vector2(tex.get_width() * h / tex.get_height(), h)
	sp.pivot_offset = Vector2(sp.size.x / 2.0, sp.size.y)  # (it grows from the water)
	sp.position = at - Vector2(sp.size.x / 2.0, sp.size.y * 0.92)
	sp.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sp.z_index = 29
	sp.scale = Vector2(0.4, 0.2)
	sp.modulate.a = 0.0
	add_child(sp)
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(sp, "scale", Vector2.ONE, 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(sp, "modulate:a", 1.0, 0.06)
	tw.chain().tween_property(sp, "modulate:a", 0.0, 0.32).set_delay(0.12)
	tw.chain().tween_callback(sp.queue_free)


## The stone leaves the pile and skips over the lake `n` times (a plink for each), then sinks (20 or more: it reaches the far shore).
func _skip_hops(n: int) -> void:
	var lake := _prop_role("lake")
	var from_pile := _prop_role("pile")
	var tex: Texture2D = UiSkin.tex("event_flat_stone")
	if n <= 0 or lake.is_empty() or tex == null:
		return
	var ln: Control = lake.node
	var stone := TextureRect.new()
	stone.texture = tex
	stone.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	stone.stretch_mode = TextureRect.STRETCH_SCALE
	stone.size = Vector2(tex.get_width() * 30.0 / tex.get_height(), 30.0)
	stone.pivot_offset = stone.size / 2.0
	stone.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stone.z_index = 30
	var surface := ln.position.y + ln.size.y * SKIP_AT_Y  # (the marks painted on star_end_skipping.png: where the stone first touches the water and where it ends)
	var x0 := _center_of(from_pile).x if not from_pile.is_empty() else ln.position.x
	var x1 := ln.position.x + ln.size.x * SKIP_END_X
	var start := Vector2(x0, (from_pile.node as Control).position.y if not from_pile.is_empty() else surface)
	stone.position = start - stone.size / 2.0
	add_child(stone)
	Audio.play("sfx_steal_miss", -8.0, 1.6)
	var hop_t := clampf(2.4 / float(n), 0.09, 0.32)
	var lx0 := ln.position.x + ln.size.x * SKIP_START_X
	for j in n:
		var a := Vector2(lerpf(lx0, x1, float(j) / float(n)), surface) if j > 0 else start
		var b := Vector2(lerpf(lx0, x1, float(j + 1) / float(n)), surface)
		var h := lerpf(70.0, 12.0, float(j) / float(maxi(1, n - 1)))
		var tw := create_tween()
		tw.tween_method(func(v: float) -> void:
			var p := a.lerp(b, v)
			stone.position = Vector2(p.x, p.y - sin(v * PI) * h) - stone.size / 2.0, 0.0, 1.0, hop_t)
		await tw.finished
		Audio.play("event_skip_plink", -6.0, lerpf(0.9, 1.5, float(j) / float(maxi(1, n - 1))))
		_water_splash(b, lerpf(48.0, 26.0, float(j) / float(maxi(1, n - 1))))
	if n >= 20:
		await get_tree().create_timer(0.4).timeout
	else:
		Audio.play("sfx_water_splash", -8.0, 1.4)
		create_tween().tween_property(stone, "modulate:a", 0.0, 0.4)
		await get_tree().create_timer(0.4).timeout
	stone.queue_free()


## The flying turtle drops to the floor (and stays there): a thud, a small bounce.
func _land(r: Dictionary) -> void:
	if r.is_empty():
		return
	r["landed"] = true
	var n: TextureRect = r.node
	n.rotation = 0.0
	var ground := _feet - n.size.y
	var tw := create_tween()
	tw.tween_property(n, "position:y", ground, 0.45).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_callback(func():
		Audio.play("wooden_ball_colide", 0.0, 0.7)  # (the "cộp")
		_shake(10.0))
	tw.tween_property(n, "position:y", ground - 26.0, 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(n, "position:y", ground, 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_callback(func(): Audio.play("wooden_ball_colide", -6.0, 0.9))


## Hearts fly from the prop down to the HP bar, one after the other; the heal sound comes as they arrive.
func _heal_flight(r: Dictionary) -> void:
	var tex: Texture2D = UiSkin.tex("icon_heart")
	if r.is_empty() or tex == null:
		Audio.play("sfx_heal", 0.0)
		return
	var src: TextureRect = r.node
	var from := src.position + Vector2(src.size.x * 0.5, src.size.y * 0.4)
	var to := PuppetTopHud.TRAY.get_center()
	for i in 7:
		var h := TextureRect.new()
		h.texture = tex
		h.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		h.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		h.size = Vector2(46, 46)
		h.pivot_offset = h.size / 2.0
		h.mouse_filter = Control.MOUSE_FILTER_IGNORE
		h.z_index = 40
		h.modulate.a = 0.0
		h.position = from - h.size / 2.0
		add_child(h)
		var bend := Vector2(randf_range(-160.0, 160.0), randf_range(-140.0, 40.0))
		var tw := create_tween()
		tw.tween_interval(0.12 * i)
		tw.tween_property(h, "modulate:a", 1.0, 0.08)
		tw.tween_method(func(v: float) -> void:
			var mid := (from + to) / 2.0 + bend
			var p := from.lerp(mid, v).lerp(mid.lerp(to, v), v)  # (a bent path)
			h.position = p - h.size / 2.0
			h.scale = Vector2.ONE * lerpf(1.0, 0.5, v), 0.0, 1.0, 0.8).set_trans(Tween.TRANS_SINE)
		tw.tween_property(h, "modulate:a", 0.0, 0.12)
		tw.tween_callback(h.queue_free)
	await get_tree().create_timer(0.12 * 7 + 0.6).timeout
	Audio.play("sfx_heal", 0.0)


## A drop of Water leaves the river of the picture, flies into the soaked card and settles in its new place at the end of the pattern.
## The middle of the painted river of the bridge picture (not of its transparent frame).
func _river_point(river: Dictionary) -> Vector2:
	var rn: TextureRect = river.node
	var im: Image = (river.tex as Texture2D).get_image()
	if im.is_compressed():
		im.decompress()
	var used := im.get_used_rect()
	var sx := rn.size.x / float(im.get_width())
	var sy := rn.size.y / float(im.get_height())
	return rn.position + Vector2((used.position.x + used.size.x * 0.5) * sx, (used.position.y + used.size.y * 0.74) * sy)


## The reward: an Any Essence leaves the river, flies straight up, swells and fades away.
func _reward_flight(river: Dictionary) -> void:
	if river.is_empty():
		return
	var from := _river_point(river)
	var orb := ElementIcon.make("?", 70.0)
	orb.size = Vector2(70, 70)
	orb.pivot_offset = orb.size / 2.0
	orb.z_index = 60
	orb.position = from - orb.size / 2.0
	orb.scale = Vector2.ONE * 0.5
	add_child(orb)
	var tw := create_tween().set_parallel(true)
	tw.tween_property(orb, "position", (from + Vector2(0.0, -330.0)) - orb.size / 2.0, 1.1).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(orb, "scale", Vector2.ONE * 3.2, 1.1).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(orb, "modulate:a", 0.0, 0.45).set_delay(0.65)
	await tw.finished
	orb.queue_free()


func _soak_flight(river: Dictionary) -> void:
	if _card_node == null or _card_after.is_empty() or river.is_empty():
		return
	var old := _card_node
	var nc := SpellCard.make(_card_after)
	nc.zoom = old.zoom
	nc.set_anchors_preset(Control.PRESET_TOP_LEFT)
	nc.position = old.position
	nc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(nc)
	await get_tree().process_frame
	await get_tree().process_frame
	nc.visible = false  # (shown when the Water arrives; its slot was measured while it was laid out)
	if not is_instance_valid(old) or not is_instance_valid(nc):
		return
	var slot: Control = nc._pat.get_child(nc._pat.get_child_count() - 1) if nc._pat != null and nc._pat.get_child_count() > 0 else null
	var to := slot.get_global_rect().get_center() if slot != null else nc.get_global_rect().get_center()
	var px := slot.size.x if slot != null and slot.size.x > 8.0 else 36.0
	var from := _river_point(river)
	var orb := ElementIcon.make("W", px * 1.5)
	orb.size = Vector2(px * 1.5, px * 1.5)
	orb.pivot_offset = orb.size / 2.0
	orb.z_index = 60
	orb.position = from - orb.size / 2.0
	orb.scale = Vector2.ONE * 0.4
	add_child(orb)
	Audio.play("elem_pickup", 0.0)
	# first straight up out of the river, growing; then across to its place in the card
	var top := from + Vector2(0.0, -230.0)
	var up := create_tween().set_parallel(true)
	up.tween_property(orb, "position", top - orb.size / 2.0, 0.55).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	up.tween_property(orb, "scale", Vector2.ONE * 1.3, 0.55)
	await up.finished
	var tw := create_tween().set_parallel(true)
	tw.tween_property(orb, "position", to - orb.size / 2.0, 0.7).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_property(orb, "scale", Vector2.ONE, 0.7)
	await tw.finished
	Audio.play("wooden_ball_swap", -2.0)
	nc.visible = true
	old.queue_free()
	_card_node = nc
	orb.queue_free()
	var pop := create_tween()
	nc.pivot_offset = nc.size / 2.0
	pop.tween_property(nc, "scale", Vector2(1.06, 1.06), 0.1)
	pop.tween_property(nc, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _flash(r: Dictionary, col: Color) -> void:
	if r.is_empty():
		return
	var n: TextureRect = r.node
	var tw := create_tween()
	tw.tween_property(n, "modulate", col, 0.12)
	tw.tween_property(n, "modulate", Color(r.lit, r.lit, r.lit), 0.5)


func _shake_prop(r: Dictionary, amp: float, times: int) -> void:
	if r.is_empty():
		return
	var n: TextureRect = r.node
	n.pivot_offset = Vector2(n.size.x / 2.0, n.size.y)
	var tw := create_tween()
	for i in times:
		tw.tween_property(n, "rotation", amp * (1.0 if i % 2 == 0 else -1.0), 0.05)
	tw.tween_property(n, "rotation", 0.0, 0.06)


## Leaves (the painted amber leaf) fall off a prop.
func _leaf_fall(r: Dictionary, n: int) -> void:
	var tex: Texture2D = UiSkin.tex("icon_amber")
	if r.is_empty() or tex == null:
		return
	var src: TextureRect = r.node
	for i in n:
		var c := TextureRect.new()
		c.texture = tex
		c.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		c.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		c.size = Vector2(34, 34)
		c.mouse_filter = Control.MOUSE_FILTER_IGNORE
		c.position = src.position + Vector2(randf_range(0.1, 0.9) * src.size.x, randf_range(0.05, 0.4) * src.size.y)
		_world.add_child(c)
		var tw := create_tween().set_parallel(true)
		var fall_to := _feet + randf_range(-6.0, 30.0)
		tw.tween_property(c, "position", Vector2(c.position.x + randf_range(-60.0, 60.0), fall_to), randf_range(0.7, 1.2)).set_delay(randf() * 0.4).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tw.tween_property(c, "rotation", randf_range(-6.0, 6.0), 1.0)
		tw.tween_property(c, "modulate:a", 0.0, 0.4).set_delay(1.4)


func _prop_role(role: String) -> Dictionary:
	for r: Dictionary in _props:
		if r.role == role:
			return r
	return {}


## A figure changes its picture (same height, same standing place).
func _swap_pic(r: Dictionary, img: String, flip := false) -> void:
	var tex: Texture2D = UiSkin.tex(img)
	if r.is_empty() or tex == null:
		return
	var n: TextureRect = r.node
	var cx := n.position.x + n.size.x / 2.0
	n.texture = tex
	n.size = Vector2(tex.get_width() * n.size.y / tex.get_height(), n.size.y)
	n.pivot_offset = Vector2(n.size.x / 2.0, n.size.y)
	n.position.x = cx - n.size.x / 2.0
	n.flip_h = flip


## A figure hops (or runs, bobbing) off the left edge of the stage.
func _run_off(r: Dictionary, secs: float, bob: float, right := false) -> void:
	if r.is_empty():
		return
	var n: TextureRect = r.node
	var x0 := n.position.x
	var y0 := n.position.y
	var x1 := 1920.0 + 80.0 if right else -n.size.x - 80.0
	var tw := create_tween()
	tw.tween_method(func(v: float) -> void:
		n.position = Vector2(lerpf(x0, x1, v), y0 - absf(sin(v * 16.0)) * bob), 0.0, 1.0, secs).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)


func _hop(r: Dictionary, times: int) -> void:
	if r.is_empty():
		return
	var n: TextureRect = r.node
	var y0 := n.position.y
	var tw := create_tween()
	for i in times:
		tw.tween_property(n, "position:y", y0 - 34.0, 0.14).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.tween_property(n, "position:y", y0, 0.14).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)


## The twins, as the story goes: the boy won (the girl runs off wailing, he is pleased), the girl won (the boy stomps off furious, she holds the candy out), or
## both are pleased with their toys.
func _shed_scene(how: String) -> void:
	var boy := _prop_role("boy")
	var girl := _prop_role("girl")
	match how:
		"boy_wins":  # (she cries and runs off to the right: the picture looks left, so it is flipped; he is pleased)
			_swap_pic(girl, "event_girl_crying", true)
			_swap_pic(boy, "event_boy_happy")
			Audio.play("sfx_scene_prepare_short_3", -4.0)
			_run_off(girl, 1.8, 22.0, true)
			_hop(boy, 3)
		"girl_wins":  # (he turns furious and stomps off to the left; she holds out the candy)
			_swap_pic(boy, "event_boy_angry")
			_swap_pic(girl, "event_girl_candy")
			Audio.play("sfx_scene_prepare_short_1", -4.0)
			_run_off(boy, 2.0, 12.0)
			_hop(girl, 2)
		_:
			_swap_pic(boy, "event_boy_happy")
			_swap_pic(girl, "event_girl_candy")  # (each has a toy: he is pleased, she holds her candy out)
			_hop(boy, 3)
			_hop(girl, 3)
	await get_tree().create_timer(2.1).timeout


## Forcing a way through: every cactus breaks into pieces (one after the other, left to right), the stage shakes.
func _shatter_props() -> void:
	var cacti := _props.filter(func(r: Dictionary) -> bool: return r.tag == "cactus")
	cacti.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a.home.x) < float(b.home.x))
	for r: Dictionary in cacti:
		var n: TextureRect = r.node
		n.pivot_offset = n.size / 2.0
		var tw := create_tween()
		tw.tween_property(n, "rotation", 0.08, 0.05)
		tw.tween_property(n, "rotation", -0.08, 0.05)
		PuppetShatter.spawn_picture(_world, n.texture, Rect2(n.position, n.size), n.position.y + n.size.y)
		n.visible = false
		_shake(8.0)
		await get_tree().create_timer(0.07).timeout
	await get_tree().create_timer(1.4).timeout


## Every cactus catches fire (one after the other), glows, chars and is gone, with flames rising off it.
func _burn_props() -> void:
	Audio.play("fire", -2.0)
	var g := GradientTexture2D.new()
	g.fill = GradientTexture2D.FILL_RADIAL
	g.fill_from = Vector2(0.5, 0.5)
	g.fill_to = Vector2(1.0, 0.5)
	g.width = 64
	g.height = 64
	var gg := Gradient.new()
	gg.colors = PackedColorArray([Color(1, 1, 1, 1), Color(1, 1, 1, 0)])
	g.gradient = gg
	var ramp := Gradient.new()
	ramp.colors = PackedColorArray([Color(1.0, 0.9, 0.35, 0.95), Color(1.0, 0.4, 0.08, 0.75), Color(0.25, 0.05, 0.0, 0.0)])
	var add := CanvasItemMaterial.new()
	add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	var cacti := _props.filter(func(r: Dictionary) -> bool: return r.tag == "cactus")
	cacti.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a.home.x) < float(b.home.x))  # (the fire runs across the maze)
	var tw := create_tween().set_parallel(true)
	var last := 0.0
	for k in cacti.size():
		var n: TextureRect = cacti[k].node
		var t0 := 0.07 * k
		var fl := CPUParticles2D.new()
		fl.emitting = false
		fl.amount = 34
		fl.lifetime = 0.8
		fl.texture = g
		fl.material = add
		fl.color_ramp = ramp
		fl.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
		fl.emission_rect_extents = Vector2(n.size.x * 0.32, 6.0)
		fl.direction = Vector2(0, -1)
		fl.spread = 22.0
		fl.gravity = Vector2(0, -240)
		fl.initial_velocity_min = 60.0
		fl.initial_velocity_max = 150.0
		fl.scale_amount_min = 0.7
		fl.scale_amount_max = 1.5
		fl.position = n.position + Vector2(n.size.x / 2.0, n.size.y * 0.8)
		_world.add_child(fl)
		tw.tween_callback(func(): fl.emitting = true).set_delay(t0)
		tw.tween_property(n, "modulate", Color(1.5, 0.75, 0.3), 0.35).set_delay(t0)
		tw.tween_property(n, "modulate", Color(0.12, 0.08, 0.08), 0.45).set_delay(t0 + 0.35)
		tw.tween_property(n, "modulate:a", 0.0, 0.45).set_delay(t0 + 0.8)
		tw.tween_callback(func(): fl.emitting = false).set_delay(t0 + 1.0)
		tw.tween_callback(fl.queue_free).set_delay(t0 + 1.9)
		last = maxf(last, t0 + 1.25)
	await get_tree().create_timer(last + 0.3).timeout


## The index of the option with these words, -1 if this page has none (the props of an earlier page stay, quietly).
func _option_of(label: String) -> int:
	if label == "":
		return -1
	var opts: Array = ev.get("options", [])
	for i in opts.size():
		if String(opts[i].label) == label:
			return i
	return -1


func _add_spot(at: Vector2, h: float, col := Color(1, 0.95, 0.75, 0.6)) -> TextureRect:
	var g := GradientTexture2D.new()
	g.fill = GradientTexture2D.FILL_RADIAL
	g.fill_from = Vector2(0.5, 0.5)
	g.fill_to = Vector2(1.0, 0.5)
	g.width = 256
	g.height = 256
	var grad := Gradient.new()
	grad.colors = PackedColorArray([col, Color(col.r, col.g, col.b, 0.0)])
	g.gradient = grad
	var s := TextureRect.new()
	s.texture = g
	s.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	var side := maxf(h * 1.6, 300.0)
	s.size = Vector2(side, side)
	s.position = at - s.size / 2.0
	s.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var m := CanvasItemMaterial.new()
	m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	s.material = m
	_world.add_child(s)
	return s


## A prop rolls in from the right edge, slowly, to its place: its first line is said and its cart rolls while it comes, its second when it stops. Then the items come up.
func _roll_in(node: Control, home: Vector2, p: Dictionary) -> void:
	node.position.x = 1920.0 + 40.0
	var secs := float(p.slow)
	var voice := String(p.get("voice_in", ""))
	if voice != "":
		say(voice)
	var cart := String(p.get("sfx_in", ""))
	if cart != "":
		_cart_snd = Audio.play_held(cart, -3.0)
	var tw := create_tween()
	tw.tween_property(node, "position:x", home.x, secs).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	await tw.finished
	if not is_inside_tree():
		return
	Audio.stop_held(_cart_snd, 0.3)
	_arrival_pending = false
	var arrive := String(p.get("voice_arrive", ""))
	if arrive != "":
		say(arrive)
	for n in _choice_ui:
		if is_instance_valid(n):
			n.visible = true


## A prop walks on from the side (or is let down from above) and settles, before the first frame it is already off its place.
func _walk_on(node: Control, home: Vector2, from: String, delay: float) -> void:
	match from:
		"left":
			node.position.x = -node.size.x - 40.0
		"right":
			node.position.x = 1920.0 + 40.0
		"top":
			node.position.y = -node.size.y - 60.0
		_:
			node.modulate.a = 0.0
			var f := create_tween()
			f.tween_property(node, "modulate:a", 1.0, 0.4).set_delay(delay)
			return
	var tw := create_tween()
	if from == "top":
		tw.tween_property(node, "position:y", home.y, 0.7).set_delay(delay).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	else:
		tw.tween_property(node, "position:x", home.x, 0.8).set_delay(delay).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


func _build_text(lay: Dictionary) -> void:
	# the story is told in the hint panel, at the right edge; the choices stay down below (and the player's HUD under them)
	var hp := hint_panel(String(ev.get("title", "")), String(ev.get("text", "")))
	var panel: PanelContainer = hp.panel
	_hint_body = hp.body
	add_child(panel)
	if again:
		panel.position = Vector2(HINT_X, HINT_Y)
	else:
		panel.position = Vector2(1960.0, HINT_Y)
		create_tween().tween_property(panel, "position:x", HINT_X, 0.4).set_delay(0.3).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	# the options that no prop on this page stands for: buttons (an event with art for it can put some of them beside its props)
	var shown := {}
	for it: Dictionary in items:
		shown[int(it.opt)] = true
	for r: Dictionary in _props:
		if int(r.opt) >= 0:
			shown[int(r.opt)] = true
	var opts: Array = ev.get("options", [])
	for h in hidden_opts:
		shown[int(h)] = true  # (no button, no prop: that option is not offered)
	var beside: Dictionary = {}
	for b: Dictionary in lay.get("btns", []):
		var i := _option_of(String(b.opt))
		if i >= 0 and not _props.is_empty():
			beside[i] = b
	var row := HBoxContainer.new()
	row.anchor_left = 0.0
	row.anchor_right = 0.0
	row.offset_left = 20.0
	row.offset_right = 1900.0
	if lay.get("center", false):
		row.anchor_top = 0.0
		row.anchor_bottom = 0.0
		row.offset_top = _center_cards_y() + (SpellCard.H * _items_zoom(true) + 20.0 if not items.is_empty() else 40.0)  # (no cards: where Continue will stand)
		row.offset_right = 1900.0
	else:
		row.anchor_top = 1.0
		row.anchor_bottom = 1.0
		row.offset_bottom = -222.0  # (above the player's HP, bottles and artifacts, which stand at the bottom)
		row.grow_vertical = Control.GROW_DIRECTION_BEGIN
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 20)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var loose := 0
	for i in opts.size():
		if shown.has(i):
			continue
		if beside.has(i):
			var bb: Dictionary = beside[i]
			var side := _button(i, clampf(float(String(opts[i].label).length()) * 11.0 + 80.0, 200.0, 380.0))
			side.position = Vector2(float(bb.x) * 1920.0 - side.custom_minimum_size.x / 2.0, _feet - 150.0 + float(bb.get("y", 0.0)))
			add_child(side)
			_choice_ui.append(side)
			continue
		row.add_child(_button(i, minf(420.0, 1400.0 / float(maxi(1, opts.size())) - 20.0)))
		loose += 1
	if loose > 0:
		add_child(row)
		_choice_ui.append(row)


func _button(i: int, w: float) -> Button:
	var opts: Array = ev.get("options", [])
	var label := String(opts[i].label)
	var b := UiTheme.button(label, func(): _choose(i), 22)
	if label.length() < 40:
		b.custom_minimum_size = Vector2(0, 52)  # (as wide as its words)
	else:
		b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		b.custom_minimum_size = Vector2(w, 96.0 if label.length() < 80 else 130.0)
	b.disabled = disabled.size() > i and disabled[i]
	return b


func _exit_tree_cart() -> void:
	Audio.stop_held(_cart_snd, 0.1)


func _process(d: float) -> void:
	_t += d
	if _hover_k >= 0 and _hover_k < _props.size() and is_instance_valid(_tag) and _props[_hover_k].fly:
		_place_tag(_props[_hover_k])  # (the flying turtle moves: his words follow him)
	_follow_sun()
	if _edit:
		return
	for r: Dictionary in _props:
		var n: TextureRect = r.node
		if _busy and not r.fly:
			continue
		if r.fly:
			if r.get("landed", false):
				continue
			var x: float = 780.0 + sin(_t * 0.55) * 400.0  # (clear of the hint panel on the right)
			n.flip_h = cos(_t * 0.55) < 0.0 and not bool(r.noflip)
			n.position = Vector2(x - n.size.x / 2.0, 250.0 + sin(_t * 1.7) * 28.0)
			n.rotation = sin(_t * 1.7) * 0.05
		elif r.wriggle and not r.get("gone", false):
			n.rotation = sin(_t * 7.0) * 0.16 + sin(_t * 2.9) * 0.07  # (on his back, legs kicking: he cannot get up)
		elif r.bob and not r.get("gone", false) and (_t > 1.6 or again):
			n.position.y = float(r.home.y) + sin(_t * 1.6 + float(r.ph)) * 14.0  # (floats: the sprite, the lights)
		elif int(r.opt) >= 0 or r.tag == "cactus":
			n.rotation = sin(_t * 1.3 + float(r.ph)) * 0.012  # (rocks a hair on its base, like the other puppets)


func _gui_input(e: InputEvent) -> void:
	if _edit:
		_edit_mouse(e)
		return
	if _busy:
		return
	if e is InputEventMouseMotion:
		var k := _prop_at(e.position)
		if _blocked(k):
			k = -1
		_set_hover(k)
	elif e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
		var i := _prop_at(e.position)
		if _blocked(i):
			return
		if i >= 0 and not _usable(i):
			Audio.play("ui_click", -10.0, 0.7)
		elif i >= 0:
			_choose(int(_props[i].opt))


# ---- An Abandoned Camp: pick two spells on the stage, they are fused in the cauldron
## Called when "Half-cook some spells" is chosen: two red frames hang above the campfire and your spells (the whole spellbook that can be fused) stand in a row; click a spell or drag it
## into a frame (the first one's pattern goes first, anti-spells only with anti-spells), the new spell shows in the preview frame on the left, Fuse melts them in the cauldron and the
## result stands in the middle with Continue. `text` is the camp's words about it.
func start_fuse(text: String) -> void:
	_busy = true
	_hide_tag()
	for n in _choice_ui:
		if is_instance_valid(n):
			n.queue_free()
	_choice_ui.clear()
	_fz_text = text
	_fz_ids = run_ref.fusable()
	_fz_slots = ["", ""]
	_fz_row.clear()
	_fz_zoom = clampf(1340.0 / (maxf(1.0, float(_fz_ids.size())) * (SpellCard.W + 8.0)), 0.3, CENTER_ZOOM)
	if _hint_body != null:
		_hint_body.text = Keywords.colorize("Click or drag two spells into the two boards above the fire. The pattern of the first one goes first. The new spell shows above them.")
	var sw := SpellCard.W * FZ_SLOT_ZOOM + FZ_RIM * 2.0  # (a small card on its debuff board)
	var sh := SpellCard.H * FZ_SLOT_ZOOM + FZ_RIM * 2.0
	var pw := SpellCard.W * FZ_PREVIEW_ZOOM
	var ph := SpellCard.H * FZ_PREVIEW_ZOOM
	var cx := 960.0
	var top := 142.0
	var pit := _prop_role("pit")
	if not pit.is_empty():
		var pn: Control = pit.node
		cx = pn.position.x + pn.size.x / 2.0
	_fz_prev_at = Vector2(cx - pw / 2.0, top)  # (the new spell stands above the two small ones, once both are in)
	_fz_slot_box.clear()
	for k in 2:
		var p := PanelContainer.new()
		p.custom_minimum_size = Vector2(sw, sh)
		p.size = Vector2(sw, sh)
		p.add_theme_stylebox_override("panel", board_box(int(FZ_RIM), int(FZ_RIM)))
		p.position = Vector2(cx - sw - 6.0 + float(k) * (sw + 12.0), top + ph + 8.0)
		p.z_index = 6
		p.set_drag_forwarding(Callable(), func(_at, d): return d is Dictionary and d.has("fuse"), func(_at, d): _fuse_drop(k, d))
		add_child(p)
		_fz_slot_box.append(p)
	_fz_btns = HBoxContainer.new()
	_fz_btns.add_theme_constant_override("separation", 24)
	_fz_btns.alignment = BoxContainer.ALIGNMENT_CENTER
	_fz_btns.anchor_left = 0.0
	_fz_btns.anchor_right = 0.0
	_fz_btns.offset_left = 20.0
	_fz_btns.offset_right = 1900.0
	_fz_btns.offset_top = _center_cards_y() + SpellCard.H * _fz_zoom + 30.0
	var back := UiTheme.button("Back", func(): _fuse_back(), 22)
	back.custom_minimum_size = Vector2(0, 52)
	_fz_btns.add_child(back)
	_fz_fuse = UiTheme.button("Fuse", func(): _fuse_go(), 22)
	_fz_fuse.custom_minimum_size = Vector2(0, 52)
	_fz_fuse.disabled = true
	_fz_btns.add_child(_fz_fuse)
	add_child(_fz_btns)
	_fuse_refresh()


const FZ_SLOT_ZOOM := 0.54
const FZ_PREVIEW_ZOOM := 0.744
const FZ_RIM := 10.5  # (air around the small card: the board is 20 % smaller than with 30; its painted rim reaches over the card edge a little)
var _fz_text := ""
var _fz_busy := false
var _fz_slots: Array = ["", ""]  # ids in the two red frames: the first one's pattern goes first
var _fz_row: Array = []  # the cards standing in the row
var _fz_slot_box: Array = []
var _fz_prev: SpellCard
var _fz_prev_at := Vector2.ZERO


## Can this spell go in a frame next to what is already in the other one? (Anti-spells only with anti-spells.)
func _fuse_fits(id: String, ignore_slot := -1) -> bool:
	for k in 2:
		if k != ignore_slot and _fz_slots[k] != "" and _fz_slots[k] != id and not run_ref.can_fuse_pair(String(_fz_slots[k]), id):
			return false
	return true


## A click on a spell of the row: it goes in the first free frame.
func _fuse_click(id: String) -> void:
	if _fz_busy:
		return
	var k := 0 if _fz_slots[0] == "" else (1 if _fz_slots[1] == "" else -1)
	if k < 0 or not _fuse_fits(id):
		Audio.play("ui_click", -10.0, 0.7)
		return
	_fz_slots[k] = id
	Audio.play("ui_click", -4.0)
	_fuse_refresh()


## A click on a spell in a frame: it goes back to the row.
func _fuse_unslot(k: int) -> void:
	if _fz_busy:
		return
	_fz_slots[k] = ""
	Audio.play("ui_click", -4.0)
	_fuse_refresh()


func _fuse_drop(k: int, d: Variant) -> void:
	if _fz_busy:
		return
	var id: String = d.fuse
	var from: int = d.from
	if from == k or not _fuse_fits(id, from if from >= 0 else k):
		return
	var old: String = _fz_slots[k]
	if from >= 0:
		_fz_slots[from] = old  # (dropped on the other frame: they swap)
	_fz_slots[k] = id
	Audio.play("ui_click", -4.0)
	_fuse_refresh()


func _fuse_begin_drag(card: SpellCard, id: String, from: int) -> Variant:
	var pv := Control.new()
	var c := SpellCard.make(run_ref.spell(id))
	c.zoom = 0.7
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.position = -Vector2(SpellCard.W, SpellCard.H) * 0.35
	pv.add_child(c)
	card.set_drag_preview(pv)
	return {"fuse": id, "from": from}


## The row, the two frames and the preview, as the picks stand now.
func _fuse_refresh() -> void:
	for c in _fz_row:
		if is_instance_valid(c):
			(c as Control).queue_free()
	_fz_row.clear()
	var shown: Array = _fz_ids.filter(func(id: String) -> bool: return not (id in _fz_slots) and _fuse_fits(id))
	var cw := SpellCard.W * _fz_zoom
	var gap := 8.0
	var x0 := 960.0 - (float(shown.size()) * (cw + gap) - gap) / 2.0
	for i in shown.size():
		var id: String = shown[i]
		var card := SpellCard.make(run_ref.spell(id))
		card.zoom = _fz_zoom
		card.set_anchors_preset(Control.PRESET_TOP_LEFT)
		card.position = Vector2(x0 + float(i) * (cw + gap), _center_cards_y())
		card.clicked.connect(func(_c): _fuse_click(id))
		card.set_drag_forwarding(func(_at): return _fuse_begin_drag(card, id, -1), Callable(), Callable())
		add_child(card)
		_fz_row.append(card)
	for k in 2:
		var box: PanelContainer = _fz_slot_box[k]
		for c in box.get_children():
			c.queue_free()
		var sid: String = _fz_slots[k]
		if sid == "":
			var hint := UiTheme.label("1st" if k == 0 else "2nd", 22, Color(1, 0.8, 0.75, 0.7))
			hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			hint.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
			box.add_child(hint)
		else:
			var sc := SpellCard.make(run_ref.spell(sid))
			sc.zoom = FZ_SLOT_ZOOM
			var slot := k
			sc.clicked.connect(func(_c): _fuse_unslot(slot))
			sc.set_drag_forwarding(func(_at): return _fuse_begin_drag(sc, sid, slot), Callable(), Callable())
			box.add_child(sc)
	var both: bool = _fz_slots[0] != "" and _fz_slots[1] != ""
	_fz_fuse.disabled = not both
	if is_instance_valid(_fz_prev):
		_fz_prev.queue_free()
	_fz_prev = null
	if both:  # (no frame: just the card)
		_fz_prev = SpellCard.make(run_ref.fuse_preview(String(_fz_slots[0]), String(_fz_slots[1])))
		_fz_prev.zoom = FZ_PREVIEW_ZOOM
		_fz_prev.set_anchors_preset(Control.PRESET_TOP_LEFT)
		_fz_prev.position = _fz_prev_at
		_fz_prev.z_index = 6
		add_child(_fz_prev)


func _drop_torch_cursor() -> void:
	if WoodCursor.override_owner == self:
		WoodCursor.override_name = ""
		WoodCursor.override_owner = null


func _fuse_clear() -> void:
	for c in _fz_row:
		if is_instance_valid(c):
			(c as Control).queue_free()
	_fz_row.clear()
	for c in _fz_slot_box:
		if is_instance_valid(c):
			(c as Control).queue_free()
	_fz_slot_box.clear()
	for c in [_fz_prev, _fz_btns]:
		if is_instance_valid(c):
			(c as Control).queue_free()


func _fuse_back() -> void:
	if _fz_busy:
		return
	_fuse_clear()
	fuse_cancelled.emit()


func _fuse_go() -> void:
	var ia: String = _fz_slots[0]
	var ib: String = _fz_slots[1]
	if _fz_busy or ia == "" or ib == "":
		return
	_fz_busy = true
	var a := run_ref.spell(ia)
	var b := run_ref.spell(ib)
	var from_a: Vector2 = (_fz_slot_box[0] as Control).global_position
	var from_b: Vector2 = (_fz_slot_box[1] as Control).global_position
	var preview := run_ref.fuse_preview(ia, ib)
	run_ref.fuse_commit(preview, ia, ib)
	_fuse_clear()
	var pit := _prop_role("pit")
	var at := Vector2(960, 400)
	if not pit.is_empty():
		var pn: Control = pit.node
		at = pn.position + Vector2(pn.size.x * 0.5, pn.size.y * 0.38)  # (the cauldron hangs in the upper middle of the picture)
	var fs := FuseScreen.new()
	fs.embedded = true
	fs.run = run_ref
	add_child(fs)
	await fs._play_fusion(a, b, from_a, from_b, preview, at)
	fs.queue_free()
	_fz_busy = false
	show_result(_fz_text, "", false, preview)


# ---- layout editor (test room only, F6): props stand still, click one to box it, drag / arrows to move, corners or + - to scale, Ctrl+Z to undo
const HANDLE := 16.0


func _input(e: InputEvent) -> void:
	if not edit_allowed or not (e is InputEventKey) or not e.pressed:
		return
	if e.keycode == KEY_F6 and not e.echo:
		_edit_toggle()
		get_viewport().set_input_as_handled()
		return
	if not _edit:
		return
	if e.keycode == KEY_Z and e.ctrl_pressed:
		_edit_undo()
	elif _sel >= 0 and e.keycode in [KEY_LEFT, KEY_RIGHT, KEY_UP, KEY_DOWN]:
		var step := 10.0 if e.shift_pressed else 1.0
		var d := Vector2(float(e.keycode == KEY_RIGHT) - float(e.keycode == KEY_LEFT), float(e.keycode == KEY_DOWN) - float(e.keycode == KEY_UP)) * step
		_edit_push()
		_edit_place(_sel, (_props[_sel].node as Control).position + d, (_props[_sel].node as Control).size)
	elif _sel >= 0 and e.keycode in [KEY_EQUAL, KEY_PLUS, KEY_KP_ADD, KEY_MINUS, KEY_KP_SUBTRACT]:
		_edit_push()
		_edit_scale(_sel, 1.05 if e.keycode in [KEY_EQUAL, KEY_PLUS, KEY_KP_ADD] else 1.0 / 1.05)
	else:
		return
	get_viewport().set_input_as_handled()


func _edit_toggle() -> void:
	_edit = not _edit
	_hide_tag()
	if _edit:
		for r: Dictionary in _props:  # (still: no rocking, no floating, nobody lit)
			var n: TextureRect = r.node
			n.rotation = 0.0
			n.scale = Vector2.ONE
			n.modulate = Color(r.lit, r.lit, r.lit)
			if r.bob:
				n.position.y = float(r.home.y)
		_edit_box = Control.new()
		_edit_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_edit_box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		_edit_box.z_index = 4000
		_edit_box.draw.connect(_edit_draw)
		add_child(_edit_box)
		mouse_default_cursor_shape = Control.CURSOR_ARROW
		print("EDITOR on: click a prop; drag / arrows (Shift = 10 px) move; corners or + - scale; Ctrl+Z undo; F6 off prints the layout values")
	else:
		var lines: PackedStringArray = []
		for r: Dictionary in _props:
			var n: TextureRect = r.node
			r["home"] = n.position
			var h := n.size.y
			lines.append('{"img": "%s", "x": %.3f, "h": %.1f, "dy": %.1f}' % [n.texture.resource_path.get_file().get_basename(), (n.position.x + n.size.x / 2.0) / 1920.0, h, n.position.y - (_feet - h)])
		print("EDITOR off, props of %s:\n%s" % [ev.get("id", ""), "\n".join(lines)])
		DisplayServer.clipboard_set("\n".join(lines))
		_edit_save()
		_sel = -1
		_drag = ""
		if is_instance_valid(_edit_box):
			_edit_box.queue_free()
		_edit_box = null


const SAVED_PATH := "res://data/event_layout_overrides.json"  # {event id: {prop index in its layout: {x, h, dy}}}: the user's own placing, never delete


static func _saved_layout() -> Dictionary:
	if not FileAccess.file_exists(SAVED_PATH):
		return {}
	var d = JSON.parse_string(FileAccess.get_file_as_string(SAVED_PATH))
	return d if d is Dictionary else {}


## The props as they stand now become the event's default (written to SAVED_PATH).
func _edit_save() -> void:
	var id := String(ev.get("id", ""))
	if int(LAYOUTS.get(id, {}).get("forest", 0)) > 0:
		return
	var all := _saved_layout()
	var mine: Dictionary = all.get(id, {})
	for r: Dictionary in _props:
		if r.fly or int(r.ei) < 0:
			continue
		var n: TextureRect = r.node
		mine[str(int(r.ei))] = {"x": snappedf((n.position.x + n.size.x / 2.0) / 1920.0, 0.0001), "h": snappedf(n.size.y, 0.1), "dy": snappedf(n.position.y - (_feet - n.size.y), 0.1)}
	all[id] = mine
	var f := FileAccess.open(SAVED_PATH, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(all, "\t"))
		f.close()
		print("EDITOR: saved the layout of %s to %s" % [id, SAVED_PATH])


func _exit_tree_edit() -> void:
	if _edit:
		_edit_save()  # (the stage went away with the editor still on)


func _edit_snapshot() -> Array:
	return _props.map(func(r: Dictionary) -> Dictionary: return {"pos": (r.node as Control).position, "size": (r.node as Control).size})


func _edit_push() -> void:
	_undo.append(_edit_snapshot())
	if _undo.size() > 200:
		_undo.pop_front()


func _edit_undo() -> void:
	if _undo.is_empty():
		return
	var snap: Array = _undo.pop_back()
	for k in mini(snap.size(), _props.size()):
		_edit_place(k, snap[k].pos, snap[k].size)


## Put prop `k` at `pos` with `size`; its home follows, so it stays there when the rocking and floating start again.
func _edit_place(k: int, pos: Vector2, size: Vector2) -> void:
	var r: Dictionary = _props[k]
	var n: TextureRect = r.node
	n.size = size
	n.pivot_offset = Vector2(size.x / 2.0, size.y)
	n.position = pos
	r["home"] = pos
	if _edit_box != null:
		_edit_box.queue_redraw()


func _edit_scale(k: int, f: float) -> void:
	var n: TextureRect = _props[k].node
	var c := n.position + n.size / 2.0
	var ns := n.size * clampf(f, 0.05, 20.0)
	_edit_place(k, c - ns / 2.0, ns)


func _edit_draw() -> void:
	if _sel < 0 or _sel >= _props.size():
		return
	var n: Control = _props[_sel].node
	var rc := Rect2(n.position, n.size)
	_edit_box.draw_rect(rc, Color(1, 0.9, 0.3), false, 2.0)
	for c: Vector2 in _edit_corners(rc):
		_edit_box.draw_rect(Rect2(c - Vector2(HANDLE, HANDLE) / 2.0, Vector2(HANDLE, HANDLE)), Color(1, 0.9, 0.3))
		_edit_box.draw_rect(Rect2(c - Vector2(HANDLE, HANDLE) / 2.0, Vector2(HANDLE, HANDLE)), Color(0.1, 0.1, 0.1), false, 2.0)


func _edit_corners(rc: Rect2) -> Array:
	return [rc.position, Vector2(rc.end.x, rc.position.y), rc.end, Vector2(rc.position.x, rc.end.y)]


func _edit_mouse(e: InputEvent) -> void:
	if e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT:
		if e.pressed:
			if _sel >= 0:
				var n: Control = _props[_sel].node
				for c: Vector2 in _edit_corners(Rect2(n.position, n.size)):
					if (e.position - c).length() <= HANDLE:
						_edit_push()
						_drag = "scale"
						_drag_from = e.position
						_drag_start = {"pos": n.position, "size": n.size}
						return
			var k := _prop_at(e.position, true)
			_sel = k
			if k >= 0:
				_edit_push()
				var n2: Control = _props[k].node
				_drag = "move"
				_drag_from = e.position
				_drag_start = {"pos": n2.position, "size": n2.size}
			if _edit_box != null:
				_edit_box.queue_redraw()
		else:
			_drag = ""
	elif e is InputEventMouseMotion and _drag != "" and _sel >= 0:
		var st: Dictionary = _drag_start
		if _drag == "move":
			_edit_place(_sel, st.pos + (e.position - _drag_from), st.size)
		else:
			var c: Vector2 = st.pos + st.size / 2.0  # (scaled about its middle, ratio kept)
			var d0 := maxf(1.0, (_drag_from - c).length())
			var f := clampf((e.position - c).length() / d0, 0.05, 20.0)
			var ns: Vector2 = st.size * f
			_edit_place(_sel, c - ns / 2.0, ns)


## A prop that takes no click now: once items are offered, every prop (the wax) or, where the layout keeps them, just the one whose option they answer (the shed).
func _blocked(k: int) -> bool:
	if k < 0:
		return false
	if hard_lock:
		return true
	if not _props_locked:
		return false
	var keep: bool = LAYOUTS.get(String(ev.get("id", "")), {}).get("offer_keep_props", false)
	return not keep or int(_props[k].opt) == _offered_opt


func _usable(i: int) -> bool:
	var o: int = _props[i].opt
	return o >= 0 and not (disabled.size() > o and disabled[o])


## The topmost prop (tied to an option) whose painted part is under `at`; -1 if none.
func _prop_at(at: Vector2, any := false) -> int:
	for k in range(_props.size() - 1, -1, -1):
		var r: Dictionary = _props[k]
		if int(r.opt) < 0 and not any:
			continue
		var n: TextureRect = r.node
		var rect := Rect2(n.position, n.size)
		if not rect.has_point(at):
			continue
		if r.img == null:
			var im: Image = (r.tex as Texture2D).get_image()
			if im.is_compressed():
				im.decompress()
			r.img = im
		var im2: Image = r.img
		var u := (at - n.position) / n.size
		if im2.get_pixel(clampi(int(u.x * im2.get_width()), 0, im2.get_width() - 1), clampi(int(u.y * im2.get_height()), 0, im2.get_height() - 1)).a > 0.15:
			return k
	return -1


## The mouse is over prop `k` (-1: none). Every prop of its option lights up together; the tag stands over the prop under the mouse.
func _set_hover(k: int) -> void:
	var o: int = _props[k].opt if k >= 0 else -1
	_hover_k = k
	if o == _hover:
		if k >= 0 and is_instance_valid(_tag):
			_place_tag(_props[k])
		return
	for j in _props.size():
		if _hover >= 0 and int(_props[j].opt) == _hover:
			_glow(j, false)
	if _hover >= 0 and not _any_always():
		_hide_tag()
	_hover = o
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if k >= 0 else Control.CURSOR_ARROW
	if k >= 0:
		for j in _props.size():
			if int(_props[j].opt) == o:
				_glow(j, true)
		_show_tag(_props[k])
		Audio.play("ui_hover", -8.0)


func _any_always() -> bool:
	for r: Dictionary in _props:
		if r.always:
			return true
	return false


func _glow(k: int, on: bool) -> void:
	var n: TextureRect = _props[k].node
	var tw := create_tween().set_parallel(true)
	var base: float = _props[k].lit
	var lit := Color(1.22, 1.16, 1.0) if _usable(k) else Color(0.7, 0.7, 0.7)
	tw.tween_property(n, "modulate", lit if on else Color(base, base, base), 0.1)
	tw.tween_property(n, "scale", Vector2.ONE * (1.05 if on else 1.0), 0.1)


func _show_tag(r: Dictionary) -> void:
	_hide_tag()
	var text: String = r.label
	var o: int = r.opt
	if o >= 0 and disabled.size() > o and disabled[o]:
		text += " (can't afford)"
	_tag = make_tag(text)
	_tag.z_index = 4000
	add_child(_tag)
	await get_tree().process_frame
	if is_instance_valid(_tag):
		_place_tag(r)


func _place_tag(r: Dictionary) -> void:
	var n: TextureRect = r.node
	var at := Vector2(n.position.x + n.size.x / 2.0 - _tag.size.x / 2.0, n.position.y - _tag.size.y - 8.0)
	_tag.position = Vector2(clampf(at.x, 10.0, 1910.0 - _tag.size.x), maxf(at.y, 120.0))


func _hide_tag() -> void:
	if is_instance_valid(_tag):
		_tag.queue_free()
	_tag = null


func _shake(n: float) -> void:
	var host := get_parent()
	if host != null and host.has_method("_shake"):
		host._shake(n)


## An option is chosen (by a prop or a button): its little farewell, then `picked`.
func _choose(i: int) -> void:
	if _busy:
		return
	_busy = true
	stop_voice()
	_hide_tag()
	var lay: Dictionary = LAYOUTS.get(String(ev.get("id", "")), {})
	var kind := String(lay.get("outro", {}).get(i, ""))
	if int(lay.get("forest", 0)) > 0:
		kind = "shuffle"
	if how_for(String(ev.get("id", "")), String(ev.get("options", [])[i].label)) == "whisper":
		Audio.play("sfx_cactus_whisper", 0.0)  # (every time the voice is followed: at the click, not after the cacti have moved)
	await _outro(kind)
	picked.emit(i)


func _outro(kind: String) -> void:
	var tw: Tween = null
	match kind:
		"scroll_fly":
			tw = create_tween().set_parallel(true)
			for r: Dictionary in _props:
				var n: TextureRect = r.node
				if r.tag == "scroll":
					n.pivot_offset = n.size / 2.0
					tw.tween_property(n, "position", Vector2(960.0, 1100.0) - n.size / 2.0, 0.7).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
					tw.tween_property(n, "scale", Vector2.ONE * 4.0, 0.7)
					tw.tween_property(n, "modulate:a", 0.0, 0.7).set_delay(0.3)
				else:
					tw.tween_property(n, "modulate:a", 0.0, 0.4)
			Audio.play("sfx_steal", -4.0)
		"light":  # the torch goes into the campfire: the pointer is the arrow again, the fire burns
			_drop_torch_cursor()
			var pit := _prop_role("pit")
			_swap_pic(pit, "event_campfire_lit")
			if not pit.is_empty():
				pit["lit"] = 1.0
				(pit.node as Control).modulate = Color(1.6, 1.4, 1.2)
				create_tween().tween_property(pit.node, "modulate", Color.WHITE, 0.6)
			Audio.play("sfx_card_ignite", -2.0)
			await get_tree().create_timer(0.8).timeout
			return
		"lift":
			tw = create_tween().set_parallel(true)
			for r: Dictionary in _props:
				var n: TextureRect = r.node
				tw.tween_property(n, "position:y", n.position.y - 1000.0, 0.6).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
			Audio.play("sfx_scene_prepare_short_2", -4.0)
		"shuffle":
			var cacti := _props.filter(func(r: Dictionary) -> bool: return r.tag == "cactus")
			for k in cacti.size():
				var n: TextureRect = cacti[k].node
				var sh := create_tween()
				for j in 6:
					sh.tween_property(n, "rotation", (0.07 if j % 2 == 0 else -0.07), 0.06)
				sh.tween_property(n, "rotation", 0.0, 0.05)
			var rustle := Audio.play_held("sfx_cocoon_roll", -6.0)  # (it is cut off when the cacti have stopped moving)
			await get_tree().create_timer(0.45).timeout
			var xs: Array = _forest.map(func(f: Dictionary) -> float: return float(f.x))
			xs.shuffle()  # (every cactus moves to another place)
			for fi in _forest.size():
				_forest[fi].x = xs[fi]
			tw = create_tween().set_parallel(true)
			for r: Dictionary in cacti:
				var n: TextureRect = r.node
				tw.tween_property(n, "position:x", float(_forest[int(r.fi)].x) * 1920.0 - n.size.x / 2.0, 0.4).set_trans(Tween.TRANS_SINE)
			await tw.finished
			Audio.stop_held(rustle, 0.08)
			tw = null
		"shell_fall":
			var tex: Texture2D = UiSkin.tex("event_turtle_shell")
			if tex != null:
				_shell = TextureRect.new()
				_shell.texture = tex
				_shell.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
				_shell.stretch_mode = TextureRect.STRETCH_SCALE
				_shell.size = Vector2(tex.get_width() * 170.0 / tex.get_height(), 170.0)
				_shell.pivot_offset = _shell.size / 2.0
				_shell.z_index = 20
				_shell.mouse_filter = Control.MOUSE_FILTER_IGNORE
				tw = create_tween().set_parallel(true)
				var tray := PuppetTopHud.TRAY
				var target := tray.get_center() - _shell.size / 2.0
				_shell.position = Vector2(target.x, -300.0)
				add_child(_shell)
				tw.tween_property(_shell, "position:y", target.y, 0.6).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
				tw.tween_property(_shell, "rotation", TAU, 0.6)
				await tw.finished
				Audio.play("sfx_player_hit", 2.0)
				Audio.play("wooden_ball_colide", 0.0, 0.7)
				_shake(22.0)
				var out := create_tween()
				out.tween_property(_shell, "modulate:a", 0.0, 0.3).set_delay(0.15)
				await out.finished
				_shell.queue_free()
			return
		_:
			return
	if tw != null:
		await tw.finished
