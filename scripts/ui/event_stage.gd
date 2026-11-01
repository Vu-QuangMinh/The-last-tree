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
			{"img": "event_scroll", "x": 0.47, "h": 64.0, "dy": -50.0, "from": "top", "delay": 0.35, "tag": "scroll", "opt": NOTE},
			{"img": "event_bush_exit", "x": 0.62, "h": 120.0, "from": "right", "opt": "Leave the note for another day"}],
		"outro": {0: "scroll_fly", 1: "lift"}},
	"farmer_farm": {"props": [{"img": "event_wheat_row", "x": 0.64, "h": 190.0, "from": "right"}, {"img": "event_farmer", "x": 0.34, "h": 330.0, "from": "left"}]},
	"cactus_maze": {"props": [], "forest": 20, "night": 0.62, "no_hud": true, "center": true, "result_on_stage": true,
		"result_how": {"Force your way": "shatter", "Follow the voice": "whisper"}},  # (casting a spell: no burning, the maze stays)
	"shrinking_pond": {"no_hud": true, "center": true, "props": [{"img": "event_pond_garden", "x": 0.5, "h": 330.0, "from": "right"},
			{"img": "event_bush_exit", "x": 0.67, "h": 130.0, "from": "right"}]},
	"church_of_aole": {"props": [{"img": "event_church", "x": 0.5, "h": 530.0, "dy": -20.0, "from": "right"},
			{"img": "event_priest", "x": 0.455, "h": 187.0, "dy": -18.0, "from": "left", "opt": "Stay awhile and listen"},
			{"img": "event_bush_exit", "x": 0.575, "h": 72.0, "dy": -16.0, "from": "right", "opt": "Walk away"}], "night": 0.62, "no_hud": true},
	"flying_turtle": {"result_how": {"Help him": "turtle_help"}, "no_hud": true, "center": true, "result_on_stage": true, "props": [{"img": "event_flying_turtle_front", "role": "turtle", "x": 0.5, "h": 200.0, "fly": true, "noflip": true, "opt": "Help him"},
			{"img": "event_bush_exit", "x": 0.7, "h": 130.0, "from": "right", "opt": "Walk away"}]},
	"turtle_falls": {"props": [], "center": true, "result_on_stage": true, "outro": {0: "shell_fall"}},
	"mystery_shack": {"offer_on_stage": true, "offer_keep_props": true, "items_center_x": true, "result_on_stage": true, "result_artifact": true, "item_tags": {"Give each of them a new toy, so they don't have to fight (give 2 artifacts)": "Give each a new toy"},
		"result_how": {"Side with the boy": "boy_wins", "Side with the girl": "girl_wins", "Give each": "toys"},
		"props": [{"img": "event_shed", "x": 0.5, "h": 430.0, "from": "top", "opt": "Give each of them a new toy, so they don't have to fight (give 2 artifacts)", "label": "Give each a new toy"},
			{"img": "event_boy", "role": "boy", "x": 0.34, "h": 260.0, "from": "left", "opt": "Side with the boy"},
			{"img": "event_girl", "role": "girl", "x": 0.66, "h": 260.0, "from": "right", "opt": "Side with the girl"}]},
	"wax_witch": {"voice_open": "witch_blood", "voice_next": true, "offer_grid": true, "center": true, "offer_on_stage": true, "offer_keep_props": true, "result_on_stage": true, "props": [{"img": "event_witch", "x": 0.5, "h": 530.0, "from": "top", "opt": "Give two drops of blood"},
			{"img": "event_cauldron", "x": 0.385, "h": 180.0, "dy": 10.0, "from": "left", "opt": "Give one drop of blood"},
			{"img": "event_bush_exit", "x": 0.62, "h": 120.0, "from": "right", "opt": "Walk away"}], "night": 0.62},
	"recycler": {"no_hud": true, "items_center_x": true, "item_tags": {"Give him a spell": "Trade this?", "Give him an artifact": "Trade this?", "Give him a bottle": "Trade this?"}, "props": [{"img": "event_recycler_happy", "role": "recycler", "x": 0.45, "h": 510.0, "from": "right", "slow": 5.0, "voice_in": "recycler_reuse", "sfx_in": "shop_cart_roll", "voice_arrive": "recycler_trade"},
			{"img": "event_bush_exit", "x": 0.68, "h": 150.0, "from": "right", "opt": "Give him nothing", "label": "Walk away"}]},
	"overgrown_vine": {"center": true, "cards_dy": -80.0, "result_on_stage": true, "item_tags": {"Cast a spell to help the tree": "Cast this spell to help the tree"}, "props": [{"img": "event_vine_tree", "role": "tree", "x": 0.42, "h": 530.0, "from": "left"},
			{"img": "event_bush_exit", "x": 0.53, "h": 120.0, "dy": 8.0, "from": "right", "opt": "Leave the tree to its fate"}]},
	"broken_bridge": {"night": 0.62, "result_on_stage": true, "props": [{"img": "event_bridge_stream", "role": "bridge", "x": 0.5, "h": 760.0, "floor_edge": true, "from": "top", "opt": "Jump over it"},
			{"img": "event_bush_exit", "role": "bush", "x": 0.72, "h": 110.0, "dy": 10.0, "from": "top", "opt": "Find a way around the thorny bushes", "label": "Find a way around"}]},
	# ---- the older "?" events (batch 2, 2026-11-01): the sheet is docs/events_batch2_plan.csv
	"well": {"voice_open": "well_whisper", "night": 0.35, "center": true, "result_on_stage": true,
		"voice_words": {"from": "well", "at": [[0.3, "Traveller..."], [1.5, "come closer..."], [3.3, "I am so hungry..."],
			[6.55, "feed me, and I will give you something nice..."], [10.85, "or jump in..."], [13.75, "jump in..."]]},
		"result_how": {"Toss in": "well_toss", "Drink from": "well_drink", "Jump in": "well_jump"},
		"props": [{"img": "event_well", "role": "well", "x": 0.43, "h": 400.0, "from": "top", "opt": "Jump in"},
			{"img": "event_leaf_pile", "role": "pile", "x": 0.24, "h": 120.0, "from": "left", "opt": "Toss in 50 Leaves"},
			{"img": "event_bucket", "role": "bucket", "x": 0.62, "h": 150.0, "from": "right", "opt": "Drink from it"}]},
	"lost_sprite": {"no_hud": true, "center": true, "result_on_stage": true, "result_how": {"Help him": "sprite_help", "Refuse": "sprite_sad"},
		"props": [{"img": "event_wind_sprite", "role": "sprite", "x": 0.42, "h": 300.0, "dy": -100.0, "from": "top", "bob": true},
			{"img": "event_bush_exit", "x": 0.64, "h": 120.0, "from": "right"}]},  # (no option on the props: Help him / Refuse to help are buttons in the box)
	"mushroom_ring": {"night": 0.5, "center": true, "result_on_stage": true, "glow": {"event_mushroom_ring": [0.55, 1.0, 0.75]},
		"result_how": {"Eat a mushroom": "mush"},
		"props": [{"img": "event_mushroom_ring", "role": "ring", "x": 0.43, "h": 250.0, "from": "top", "opt": "Eat a mushroom"},
			{"img": "event_bush_exit", "x": 0.66, "h": 120.0, "from": "right", "opt": "Walk away"}]},
	"hollow_stump": {"night": 0.3, "center": true, "result_on_stage": true, "item_tags": {"Throw in a bottle": "Throw this bottle in"},
		"result_how": {"Reach in": "reach", "Throw in a bottle": "throw"},
		"props": [{"img": "event_hollow_stump", "role": "stump", "x": 0.43, "h": 420.0, "from": "top", "opt": "Reach in"},
			{"img": "event_bush_exit", "x": 0.66, "h": 120.0, "from": "right", "opt": "Walk away"}]},
	"bard": {"music_open": "merry puppets", "center": true, "result_on_stage": true, "result_how": {"That is a weird": "bard_angry", "It is beautiful": "bard_song", "Pay 100": "bard_lute"},
		"props": [{"img": "event_deer", "role": "deer", "x": 0.25, "h": 330.0, "from": "left", "opt": "That is a weird looking item"},
			{"img": "event_bard", "role": "bard", "x": 0.43, "h": 420.0, "from": "top", "opt": "It is beautiful", "alt": {"Actually, I don't have that much": "Actually, I don't have that much"}},
			{"img": "event_lute", "role": "lute", "x": 0.6, "h": 300.0, "from": "right", "opt": "Can I have it?", "alt": {"Pay 100 Leaves": "Pay 100 Leaves"}}]},
	"cursed_shrine": {"night": 0.45, "center": true, "result_on_stage": true,
		"result_how": {"Pry the box": "idol_bite", "Take the leaves": "idol_leaves", "Put down": "idol_gift"},
		"props": [{"img": "event_idol", "role": "idol", "x": 0.43, "h": 350.0, "from": "top", "opt": "Pry the box from its mouth"},
			{"img": "event_leaf_pile", "role": "pile", "x": 0.24, "h": 110.0, "from": "left", "opt": "Take the leaves"},
			{"img": "event_offering_bowl", "role": "bowl", "x": 0.62, "h": 90.0, "from": "right", "opt": "Put down 100 more Leaves"}]},
	"lost_camp": {"opts_on_props": true, "night": 0.4, "no_hud": true, "center": true, "result_on_stage": true, "stage_fuse": true, "cursor": "event_torch", "outro": {0: "light"}, "result_how": {"Rest": "bed_toss"},
		"props": [{"img": "event_campfire_off", "role": "pit", "x": 0.37, "h": 420.0, "lit": 0.55, "from": "top", "opt": "Half cook some spells", "label": "Use torch to half cook some spells"},
			{"img": "event_tent", "role": "bed", "x": 0.6, "h": 175.0, "lit": 0.55, "from": "right", "opt": "Get some restless rest", "label": "Plant the torch to protect the tent"}]},
	"elemental_fishing": {"underwater_tail": true, "no_hud": true, "night": 0.3, "center": true, "result_on_stage": true,
		"props": [{"img": "event_stream", "x": 0.55, "h": 190.0, "from": "right", "opt": "Help him fish", "alt": {"Ready": "Ready"}},
			{"img": "event_fisherman", "x": 0.33, "h": 360.0, "from": "left", "opt": "Help him fish", "alt": {"Ready": "Ready"}},
			{"img": "event_bush_exit", "x": 0.7, "h": 120.0, "from": "right", "opt": "Walk away"}]},
	"mausoleum": {"night": 0.62, "center": true, "result_on_stage": true,
		"glow": {"event_orb_red": [1.0, 0.3, 0.25], "event_orb_blue": [0.3, 0.55, 1.0], "event_orb_green": [0.35, 1.0, 0.45]},
		"result_how": {"Touch the red": "orb_red", "Touch the blue": "orb_blue", "Touch the green": "orb_green"},
		"props": [{"img": "event_mausoleum", "x": 0.43, "h": 440.0, "from": "top"},
			{"img": "event_orb_red", "role": "orb_red", "x": 0.31, "h": 110.0, "dy": -190.0, "from": "top", "bob": true, "opt": "Touch the red ball"},
			{"img": "event_orb_blue", "role": "orb_blue", "x": 0.43, "h": 110.0, "dy": -250.0, "from": "top", "bob": true, "opt": "Touch the blue ball"},
			{"img": "event_orb_green", "role": "orb_green", "x": 0.55, "h": 110.0, "dy": -190.0, "from": "top", "bob": true, "opt": "Touch the green ball"}]},
	"watchtower": {"no_hud": true, "night": 0.3, "center": true, "result_on_stage": true,
		"result_how": {"Go East": "watch_camp", "Go North": "watch_monster", "Go West": "watch_cart"},
		# (the tower stands alone, up to the valance; what you spot from the top comes on once you have climbed it)
		"props": [{"img": "event_watchtower", "x": 0.5, "h": 540.0, "from": "top"},
			{"img": "event_tent", "role": "camp", "x": 0.2, "h": 300.0, "from": "left", "after_begin": true},
			{"img": "event_far_giant", "role": "giant", "x": 0.62, "h": 460.0, "from": "right", "after_begin": true},
			{"img": "event_merchant", "role": "cart", "x": 0.34, "h": 600.0, "dy": -8.0, "from": "left", "after_begin": true}]},
	"skipping_stones": {"no_hud": true, "center": true, "result_on_stage": true, "result_how": {"Skip": "skip"},
		"props": [{"img": "event_lake", "role": "lake", "x": 0.5, "h": 200.0, "wide": 2.0, "from": "right"},  # (the lake pulled out to twice its length)
			{"img": "event_bush_exit", "x": 0.77, "h": 120.0, "from": "right"}]},
}
## The maze's cacti, kept between its pages: [{img, x, h, dy, lit}]
static var _forest: Array = []

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
var _box: PanelContainer  # the story box at the front
var _box_col: VBoxContainer
var _btn_row: HFlowContainer  # the buttons in it
var _pages: Array = []
var _page_i := 0
var _page_last: Array = []
var _opt_tags: Dictionary = {}  # option -> its tag, always up over its prop (and the prop it stands over)
## Every event starts with its scene and its opening words, and a button to begin ("begin" in its data); only then do
## the voices start, the option tags come up and the props take clicks. (A later page of the event starts at once.)
var _begun := false
var _opt_buttons: Array = []
var _late_props: Array = []  # [node, home, from] of the props with "after_begin", until the event begins
var _item_row: Control  # the spells / artifacts / bottles an option asks for: up only after its button is pressed
var _dim: ColorRect
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
		"throw":
			return "throw_fight" if text.contains("coming out") else ("throw_quiet" if text.contains("shatter") else "throw_bottles")
	return how


const HINT_TEXT_W := 412.0
const CENTER_ZOOM := 0.806  # (center: the cards, 30 % bigger than the 0.62 they had)

## center: the item cards stand just under the floor (their top edge on the top edge of the front wall), the buttons under them.
func _center_cards_y() -> float:
	return BOX_TOP - SpellCard.H * CENTER_ZOOM - 24.0 + float(LAYOUTS.get(String(ev.get("id", "")), {}).get("cards_dy", 0.0))  # (just above the story box)
const HINT_W := HINT_TEXT_W + 36.0 + 34.0  # (the paper frame's margins, as in the fight's hint panel)
## Every event tells its story in one box at the front of the stage, where the fight's own UI stands (the HUD is down):
## the words twice the size they were, the choices as buttons in the box under them. Words that don't fit come in pages.
const BOX_TEXT_W := 1240.0
const BOX_PX := 36  # (twice the 18 the side panel used)
const BOX_LINES := 4  # (lines of words per page; more than that: "Go on..." pages)
const BOX_BOTTOM := 1062.0
const BOX_TOP := 712.0  # (the most the box ever reaches up: the item cards stand just above it)
const HINT_Y := 170.0
const HINT_X := 1920.0 - HINT_W + 6.0  # (flush with the right edge, like the fight's hint panel)


## The Seedling's hint panel (panel_paper_frame, the sprout and a heading): the box an event tells its story in. It stands where the fight's hint panel does,
## against the right edge under the Leaves' frame. Returns {panel, body}: `body` is the RichTextLabel (set its `text` to change the words).
static func hint_panel(title: String, text: String, px := 0, min_h := 0.0, text_w := HINT_TEXT_W) -> Dictionary:
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
	p.custom_minimum_size = Vector2(text_w + 36.0 + 34.0, min_h)
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
	var who := UiTheme.label(title, 22 if px <= 0 or px < 30 else 30, Color(0.2, 0.45, 0.15))
	who.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	who.mouse_filter = Control.MOUSE_FILTER_IGNORE
	head.add_child(who)
	var size_px := px if px > 0 else (18 if text.length() <= 350 else (16 if text.length() <= 650 else 15))  # (a long story is set smaller, so the board stays above the player's HUD)
	var r := RichTextLabel.new()
	r.bbcode_enabled = true
	r.fit_content = true
	r.scroll_active = false
	r.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	r.custom_minimum_size = Vector2(text_w - (28.0 if px > 0 else 0.0), 0)  # (a fixed small size leaves room round the words)
	r.add_theme_font_size_override("normal_font_size", size_px)
	r.add_theme_font_size_override("bold_font_size", size_px)
	r.add_theme_constant_override("line_separation", 2)
	r.add_theme_color_override("default_color", Color(0.14, 0.11, 0.08))
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	r.text = Keywords.colorize(text.replace("\n\n", "\n") if text.length() > 500 and px < 30 else text, true)
	v.add_child(r)
	return {"panel": p, "body": r, "col": v}


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
		node.size = Vector2(tex.get_width() * h / tex.get_height() * float(p.get("wide", 1.0)), h)  # ("wide": stretched sideways)
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
		# (the props are scenery: every choice is a button in the box, never a click on a prop; except a layout with
		# "opts_on_props", the Abandoned Camp, where the campfire and the tent are its two choices, tagged and clicked)
		var opt := _option_of(String(p.get("opt", ""))) if lay.get("opts_on_props", false) else -1
		_props.append({"node": node, "opt": opt, "label": String(p.get("label", p.get("opt", ""))), "img": null, "bob": p.get("bob", false), "glow": glow_node, "ei": ei, "home": home, "fly": p.get("fly", false),
			"noflip": p.get("noflip", false), "tag": String(p.get("tag", "")), "ph": randf() * TAU, "always": p.get("always", false), "tex": tex,
			"fi": int(p.get("fi", -1)), "lit": lit, "role": String(p.get("role", ""))})
		if not again and float(p.get("slow", 0.0)) > 0.0:
			_arrival_pending = true
			_roll_in(node, home, p)
		elif not again and p.get("after_begin", false) and not _begun:
			node.visible = false  # (it comes on when the event begins: _begin)
			_late_props.append([node, home, String(p.get("from", ""))])
		elif not again:
			_walk_on(node, home, String(p.get("from", "")), float(p.get("delay", 0.12 * delay_n if forest == 0 else randf() * 0.5)))
			delay_n += 1
	_build_text(lay)
	_build_items(lay)
	if lay.get("underwater_tail", false) and again and _stage != null and _stage.is_underwater():
		_owns_water = true
	if _begun:
		_take_cursor(lay)
		_start_voices(lay)
	if _arrival_pending:
		for n in _choice_ui:
			if is_instance_valid(n):
				n.visible = false  # (they come up when he has stopped)
	if not again and not _props.is_empty():
		Audio.play("sfx_scene_prepare_short_%d" % randi_range(1, 4), -4.0)
	if _begun:
		_make_opt_tags()
	if again and String(ev.get("id", "")) == "skipping_stones" and _skips_in(String(ev.get("text", ""))) > 0:
		_busy = true  # (the stone is still skipping: its count and the next throw wait for it)
		if is_instance_valid(_box):
			_box.modulate.a = 0.0
		await _skip_hops(_skips_in(String(ev.text)))
		if is_instance_valid(_box):
			_box.create_tween().tween_property(_box, "modulate:a", 1.0, 0.25)
		_busy = false


## The event begins (its button was pressed): the voices and the music start, the option tags come up, and the box
## shows the choices.
func _begin() -> void:
	if _begun:
		return
	_begun = true
	Audio.play("ui_click", -4.0)
	_take_cursor(LAYOUTS.get(String(ev.get("id", "")), {}))
	for k in _late_props.size():  # (the props that wait for the beginning walk on now)
		var lp: Array = _late_props[k]
		(lp[0] as Control).visible = true
		_walk_on(lp[0], lp[1], String(lp[2]), 0.15 * k)
	_late_props.clear()
	_start_voices(LAYOUTS.get(String(ev.get("id", "")), {}))
	_make_opt_tags()


## The event's own pointer (the camp's torch): only once the event has begun, not on its opening words.
func _take_cursor(lay: Dictionary) -> void:
	if String(lay.get("cursor", "")) != "":
		WoodCursor.override_name = String(lay.cursor)
		WoodCursor.override_owner = self
	_page_text(_choice_text(), _opt_buttons)


## The words over the choices: the event's question if it has one, else its story again.
func _choice_text() -> String:
	var q := String(ev.get("prompt", ""))
	return q if q != "" else String(ev.get("text", ""))
	if _opt_buttons.is_empty() and String(ev.get("prompt", "")) == "" and is_instance_valid(_box):
		_box.create_tween().tween_property(_box, "modulate:a", 0.0, 0.3)  # (every choice is a prop: nothing left to say in the box)


func _start_voices(lay: Dictionary) -> void:
	var say_in := String(lay.get("voice_open", ""))
	var voice_now: bool = again == lay.get("voice_next", false)  # ("voice_next": its voice is heard on its second page, the Wax Witch's words)
	if not again and String(lay.get("music_open", "")) != "":
		play_music(String(lay.music_open))
		_owns_tune = true
	if voice_now and say_in != "":
		say(say_in)  # (the witch's first words)
		if lay.has("voice_words"):
			_whisper_words(lay.voice_words)  # (the words of that voice rise out of what is speaking)
	elif String(ev.get("text", "")) != "":
		speak(String(ev.text))


func _make_opt_tags() -> void:
	for r: Dictionary in _props:
		if r.always:
			_show_tag(r)
	# what each prop does is written over it all the time (not only under the mouse)
	for k in _props.size():
		var r: Dictionary = _props[k]
		var o := int(r.opt)
		if o < 0 or _opt_tags.has(o) or r.always:
			continue
		var text := String(r.label)
		if disabled.size() > o and disabled[o]:
			text += " (can't afford)"
		var tag := make_tag(text)
		tag.z_index = 3900
		tag.modulate.a = 0.0
		add_child(tag)
		_opt_tags[o] = {"tag": tag, "k": k}
		tag.create_tween().tween_property(tag, "modulate:a", 1.0, 0.3)


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
		if is_instance_valid(n) and n != _btn_row:  # (the box's button row stays: the result's button goes in it)
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
		_hint_body.visible = true
		_fit_box.call_deferred()


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
		if is_instance_valid(n) and n != _btn_row:  # (the box's button row stays: the result's button goes in it)
			n.queue_free()
	_choice_ui.clear()
	for r: Dictionary in _item_views:
		if is_instance_valid(r.node):
			(r.node as Control).queue_free()
	_item_views.clear()
	_page_text(say, [])  # (his words; no Back now: the item is on his cart)
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
		var fan := (float(k) - float(_item_views.size() - 1) / 2.0)  # (-1, 0, 1: left, middle, right)
		o.tween_property(v, "position", home + Vector2(0.0, absf(fan) * 28.0), 0.55).set_delay(0.25 * k).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		o.tween_property(v, "rotation", fan * 0.09, 0.55).set_delay(0.25 * k).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
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
			var k2 := k if v is SpellCard else (1.15 if v is ArtifactCard else 1.7)
			var tw := create_tween().set_parallel(true)
			tw.tween_property(v, "scale", Vector2.ONE * k2, 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			tw.tween_property(v, "rotation", 0.0, 0.4)  # (out of the fan, straight)
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
	if items.is_empty() or (_offer_tag == "" and _only_opt < 0):
		return  # (an option's things come up only when its button is pressed: _open_items)
	var y := 664.0
	if _stage != null:
		y = _stage.floor_range().y + 10.0
	var centered: bool = lay.get("center", false)
	if centered:
		y = _center_cards_y()
	var only := _only_opt
	var shown: Array = items if only < 0 else items.filter(func(it: Dictionary) -> bool: return int(it.opt) == only)
	var spells: Array = shown.filter(func(it: Dictionary) -> bool: return it.kind == "spell")
	var others: Array = shown.filter(func(it: Dictionary) -> bool: return it.kind != "spell")
	var tags: Dictionary = lay.get("item_tags", {})
	var opts: Array = ev.get("options", [])
	# one row: the spell cards, a gap, then the artifacts and bottles (so the buttons of the other options keep their place under it)
	var row: Container = HBoxContainer.new()
	row.anchor_left = 0.0
	row.anchor_right = 0.0
	row.offset_left = 20.0
	row.offset_right = 1900.0  # (every row of items is centred on the screen, whatever the layout)
	row.offset_top = y
	(row as HBoxContainer).alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 8)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(row)
	_choice_ui.append(row)
	_item_row = row
	var grid: bool = _only_opt >= 0 or _offer_back or (_offer_tag != "" and lay.get("offer_grid", false))
	if grid:
		row.queue_free()  # (they fill the screen instead, everything else dimmed: see _grid_row)
		_choice_ui.erase(row)
		row = _grid_row(spells.size() + others.size(), 60.0 if _offer_back else 12.0)
		_item_row = row
	var zoom := clampf(((1300.0 if centered else 1400.0) - float(others.size()) * 100.0 - 40.0) / maxf(1.0, float(spells.size()) * (SpellCard.W + 8.0)), 0.4, CENTER_ZOOM if centered else 0.55)
	var k := 0
	if grid:
		zoom = _grid_zoom  # (at their own size, unless too many)
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
		elif grid and it.kind == "artifact":
			var ac := ArtifactCard.make(Artifacts.view(String(it.id), false))  # (on their own screen: the whole card, to be read)
			ac.clicked.connect(func(): _item_click(it))
			view = ac
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


## The Wax Witch's offer ("offer_grid"): every spell you could seal fills the screen above the box, at its own size
## (smaller only when there are too many to fit), and everything else dims.
var _grid_zoom := 1.0
var _offer_dim: ColorRect
var _only_opt := -1  # the option whose things are up (its button was pressed), or -1


func _grid_row(n: int, gap := 12.0) -> Container:
	var area := Vector2(1880.0, BOX_TOP - 150.0)
	_grid_zoom = 1.0
	while _grid_zoom > 0.4:
		var cols := maxi(1, int(area.x / (SpellCard.W * _grid_zoom + 12.0)))
		if ceilf(float(n) / float(cols)) * (SpellCard.H * _grid_zoom + 12.0) <= area.y:
			break
		_grid_zoom -= 0.05
	var flow := HFlowContainer.new()
	flow.alignment = FlowContainer.ALIGNMENT_CENTER
	flow.add_theme_constant_override("h_separation", int(gap))
	flow.add_theme_constant_override("v_separation", 12)
	flow.position = Vector2(20.0, 120.0)
	flow.size = Vector2(area.x, area.y)
	flow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if not is_instance_valid(_offer_dim):
		_offer_dim = ColorRect.new()
		_offer_dim.color = Color(0, 0, 0, 0.0)
		_offer_dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		_offer_dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(_offer_dim)
		if is_instance_valid(_box):
			move_child(_offer_dim, _box.get_index())  # (the box stays bright)
		_offer_dim.create_tween().tween_property(_offer_dim, "color:a", 0.6, 0.3)
	add_child(flow)
	_choice_ui.append(flow)
	return flow


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
	_drop_opt_tags()
	if is_instance_valid(_box) and _box.modulate.a < 1.0:
		_box.create_tween().tween_property(_box, "modulate:a", 1.0, 0.25)  # (back for the result's words)
	for n in _choice_ui:
		if is_instance_valid(n) and n != _btn_row:
			n.queue_free()
	_choice_ui.clear()
	for c in _btn_row.get_children():
		c.queue_free()
	# the stage dims; the box (and what the result shows) stays bright
	if is_instance_valid(_offer_dim):
		_offer_dim.queue_free()
	_dim = ColorRect.new()
	_dim.color = Color(0, 0, 0, 0.0)
	_dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_dim)
	move_child(_dim, _box.get_index())
	_dim.create_tween().tween_property(_dim, "color:a", 0.0 if how == "skip" else 0.55, 0.35)  # (a 20+ throw is told like any other throw)
	if not keep_items:
		for r: Dictionary in _item_views:
			if is_instance_valid(r.node):
				(r.node as Control).queue_free()
		_item_views.clear()
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
	if how == "skip" and is_instance_valid(_box):
		_box.modulate.a = 0.0  # (the count is told once the stone has stopped)
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
	var b := UiTheme.button(continue_label, func(): stop_voice(); continued.emit(), 28)
	b.custom_minimum_size = Vector2(0, 58)
	_page_text(text, [b])
	if is_instance_valid(_box) and _box.modulate.a < 1.0:
		_box.create_tween().tween_property(_box, "modulate:a", 1.0, 0.25)


## The Whispering Well's grudge, after its words have been read: one of your spells flies up from the bottom of the screen,
## a ball of light rises out of the well and splashes onto it, and becomes a Water in its cost (`before` -> `after`).
## Then only Next is left, under the dimmed stage. Await it: the caller connects `continued` once it returns.
func curse_card(before: Dictionary, after: Dictionary) -> void:
	for c in _btn_row.get_children():
		c.queue_free()
	_hint_body.visible = false
	if is_instance_valid(_box):
		_box.create_tween().tween_property(_box, "modulate:a", 0.0, 0.25)
	# 1. the card flies up from the bottom middle
	var card := SpellCard.make(before)
	card.zoom = CENTER_ZOOM
	card.set_anchors_preset(Control.PRESET_TOP_LEFT)
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.z_index = 50
	var home := Vector2(960.0 - SpellCard.W * CENTER_ZOOM / 2.0, 330.0)
	card.position = Vector2(home.x, 1120.0)
	add_child(card)
	Audio.play("sfx_card_hit", -6.0, 1.2)
	var up := create_tween()
	up.tween_property(card, "position", home, 0.6).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	await up.finished
	await get_tree().create_timer(0.35).timeout
	# 2. the card as it will be, measured where it stands (its new Water slot is the last of its pattern)
	var nc := SpellCard.make(after)
	nc.zoom = CENTER_ZOOM
	nc.set_anchors_preset(Control.PRESET_TOP_LEFT)
	nc.position = home
	nc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	nc.z_index = 50
	add_child(nc)
	await get_tree().process_frame
	await get_tree().process_frame
	nc.visible = false
	var slot: Control = nc._pat.get_child(nc._pat.get_child_count() - 1) if nc._pat != null and nc._pat.get_child_count() > 0 else null
	var to := slot.get_global_rect().get_center() if slot != null else nc.get_global_rect().get_center()
	var px := slot.size.x if slot != null and slot.size.x > 8.0 else 36.0
	# 3. a ball of light out of the well, up, then down onto the card, where it splashes and becomes the Water
	var well := _prop_role("well")
	var from := Vector2(960.0, 500.0)
	if not well.is_empty():
		var wn: TextureRect = well.node
		from = wn.position + Vector2(wn.size.x / 2.0, wn.size.y * 0.55)
	var ball := Panel.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(1.0, 0.97, 0.8)
	sb.set_corner_radius_all(64)
	sb.shadow_color = Color(1.0, 0.9, 0.5, 0.8)
	sb.shadow_size = 18
	ball.add_theme_stylebox_override("panel", sb)
	ball.size = Vector2(px, px)
	ball.pivot_offset = ball.size / 2.0
	ball.position = from - ball.size / 2.0
	ball.scale = Vector2.ONE * 0.3
	ball.z_index = 60
	ball.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(ball)
	Audio.play("elem_pickup", 0.0, 0.8)
	var rise := create_tween().set_parallel(true)
	rise.tween_property(ball, "position", from + Vector2(0.0, -200.0) - ball.size / 2.0, 0.6).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	rise.tween_property(ball, "scale", Vector2.ONE * 1.4, 0.6)
	await rise.finished
	var fall := create_tween().set_parallel(true)
	fall.tween_property(ball, "position", to - ball.size / 2.0, 0.55).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	fall.tween_property(ball, "scale", Vector2.ONE, 0.55)
	await fall.finished
	# the splash: a burst of light, the drops, and the Water is there
	Audio.play("wooden_ball_swap", -2.0)
	for k in 10:
		var drop := Panel.new()
		var ds := StyleBoxFlat.new()
		ds.bg_color = Color(0.75, 0.9, 1.0) if k % 2 == 0 else Color(1.0, 0.97, 0.8)
		ds.set_corner_radius_all(16)
		drop.add_theme_stylebox_override("panel", ds)
		drop.size = Vector2(10, 10)
		drop.position = to - drop.size / 2.0
		drop.z_index = 61
		drop.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(drop)
		var dir := Vector2.from_angle(TAU * k / 10.0 + randf_range(-0.2, 0.2)) * randf_range(50.0, 95.0)
		var dt := drop.create_tween().set_parallel(true)
		dt.tween_property(drop, "position", drop.position + dir, 0.45).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		dt.tween_property(drop, "modulate:a", 0.0, 0.45)
		dt.chain().tween_callback(drop.queue_free)
	nc.visible = true
	card.queue_free()
	ball.queue_free()
	var pop := create_tween()
	nc.pivot_offset = nc.size / 2.0
	pop.tween_property(nc, "scale", Vector2(1.08, 1.08), 0.1)
	pop.tween_property(nc, "scale", Vector2.ONE, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_item_views.append({"node": nc, "opt": -1, "id": "", "tw": null})
	await get_tree().create_timer(0.6).timeout
	# 4. only Next is left (the stage stays dim)
	if is_instance_valid(_box):
		_box.create_tween().tween_property(_box, "modulate:a", 1.0, 0.25)
	var b := UiTheme.button("Next", func(): stop_voice(); continued.emit(), 28)
	b.custom_minimum_size = Vector2(0, 58)
	_page_text("", [b])


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
		"turtle_help":  # you flip him over: he drops to the floor with a thud
			_land(_prop_role("turtle"))
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
	var pile := _prop_role("pile")
	var stump := _prop_role("stump")
	var idol := _prop_role("idol")
	var bard := _prop_role("bard")
	match how:
		"well_toss":  # the leaves go down the well, then two bottles float up and fly to you
			Audio.play("sfx_coin_bag_spill", -2.0)
			await _fly_icons("icon_amber", _center_of(pile), _center_of(well) + Vector2(0, -120), 9, 38.0)
			Audio.play("sfx_water_splash", 0.0)
			_shake_prop(well, 0.02, 4)
			await get_tree().create_timer(0.5).timeout
			Audio.play("sfx_draw_element", -2.0)
			await _fly_icons(_bottle_tex(), _center_of(well) + Vector2(0, -150), PuppetTopHud.TRAY.get_center(), 2, 60.0)
		"well_drink":  # it was not water
			var bucket := _prop_role("bucket")
			_shake_prop(bucket, 0.08, 6)
			_flash(bucket, Color(0.6, 1.3, 0.5))
			Audio.play("sfx_hurt_grunt", -4.0)
			_shake(6.0)
		"well_jump":  # a splash, a crack of bone, the cursed treasure
			_shake_prop(well, 0.03, 6)
			Audio.play("sfx_water_splash", 2.0)
			_shake(14.0)
			await get_tree().create_timer(0.6).timeout
			Audio.play("event_bite", -4.0, 0.7)
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
			Audio.play("event_lute_song", 0.0)
			_hop(bard, 4)
			await get_tree().create_timer(1.6).timeout
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
			Audio.play("event_lute_song", -4.0)
		"idol_bite", "idol_leaves":
			_shake_prop(idol, 0.05, 5)
			Audio.play("event_bite", 0.0)
			Audio.play("sfx_hurt_grunt", -3.0)
			_flash(idol, Color(1.5, 0.8, 0.8))
			_shake(14.0)
			if how == "idol_leaves":
				await get_tree().create_timer(0.5).timeout
				Audio.play("sfx_coin_bag_spill", 0.0)
				await _fly_icons("icon_amber", _center_of(pile), PuppetTopHud.TRAY.get_center(), 10, 36.0)
		"idol_gift":  # the leaves go into the bowl, and the jaw lets go
			var bowl := _prop_role("bowl")
			Audio.play("sfx_coin_bag_spill", 0.0)
			await _fly_icons("icon_amber", PuppetTopHud.TRAY.get_center(), _center_of(bowl), 10, 36.0)
			_flash(bowl, Color(1.5, 1.4, 0.8))
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
	Audio.play("sfx_water_splash", -8.0, 1.4)  # (it sinks, however far it went: nothing special for 20 or more)
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


## Whispers: the words of a voice line rise out of the prop that speaks it (the well), one phrase at a time as it is
## said: yellow, drifting slowly up and swaying, each letter bending on a wave (a lure), then fading away fast.
## `spec`: {from: the prop's role, at: [[seconds into the voice, words], ...]}.
const WHISPER_LIFE := 2.6  # seconds a phrase floats
const WHISPER_COL := Color(1.0, 0.86, 0.3)
var _whispers: Array = []  # {node, age, x0, y0, ph}


func _whisper_words(spec: Dictionary) -> void:
	var t0 := Time.get_ticks_msec()
	for w in spec.get("at", []):
		var due := int(float(w[0]) * 1000.0)
		while Time.get_ticks_msec() - t0 < due:
			await get_tree().process_frame
			if not is_inside_tree() or _busy:
				return  # (an option was chosen: the voice is cut, so are its words)
		var src := _prop_role(String(spec.get("from", "")))
		if src.is_empty():
			return
		var n: TextureRect = src.node
		var home: Vector2 = src.home  # (where it stands once it has come on: the first words come while it is still dropping in)
		_whisper(String(w[1]), Vector2(home.x + n.size.x / 2.0, home.y + n.size.y * 0.55))  # (out of its opening)


func _whisper(text: String, at: Vector2) -> void:
	var r := RichTextLabel.new()
	r.bbcode_enabled = true
	r.fit_content = true
	r.scroll_active = false
	r.autowrap_mode = TextServer.AUTOWRAP_OFF
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	r.add_theme_font_size_override("normal_font_size", 34)
	r.add_theme_color_override("default_color", WHISPER_COL)
	r.add_theme_constant_override("outline_size", 8)
	r.add_theme_color_override("font_outline_color", Color(0.25, 0.12, 0.0, 0.85))
	r.text = "[wave amp=26.0 freq=3.0 connected=1]%s[/wave]" % text  # (every letter bends on a slow wave)
	r.z_index = 3800
	r.modulate.a = 0.0
	add_child(r)
	await get_tree().process_frame
	if not is_instance_valid(r):
		return
	r.size = r.get_combined_minimum_size()
	r.pivot_offset = r.size / 2.0
	_whispers.append({"node": r, "age": 0.0, "x0": at.x, "y0": at.y, "ph": randf() * TAU})


## The whispers drift up out of the well, swaying and swelling, then fade away fast.
func _move_whispers(d: float) -> void:
	for k in range(_whispers.size() - 1, -1, -1):
		var w: Dictionary = _whispers[k]
		var r: RichTextLabel = w.node
		if not is_instance_valid(r):
			_whispers.remove_at(k)
			continue
		w.age = float(w.age) + d
		var a: float = w.age
		var ph: float = w.ph
		r.position = Vector2(float(w.x0) + sin(a * 2.1 + ph) * 34.0, float(w.y0) - a * 62.0) - r.size / 2.0  # (slowly up, swaying side to side)
		r.rotation = sin(a * 1.6 + ph) * 0.10  # (it leans one way, then the other)
		r.scale = Vector2.ONE * (0.85 + 0.25 * minf(a / WHISPER_LIFE, 1.0)) * Vector2(1.0 + 0.05 * sin(a * 3.3 + ph), 1.0 - 0.05 * sin(a * 3.3 + ph))  # (it swells, and breathes)
		var fade_in := minf(a / 0.35, 1.0)
		var fade_out := clampf((WHISPER_LIFE - a) / 0.55, 0.0, 1.0)  # (then it is gone, fast)
		r.modulate.a = fade_in * fade_out
		if a >= WHISPER_LIFE:
			r.queue_free()
			_whispers.remove_at(k)


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
	# the story is told in the box at the front of the stage (where the fight's UI stands); the choices are buttons in it
	var hp := hint_panel(String(ev.get("title", "")), "", BOX_PX, 0.0, BOX_TEXT_W)
	var panel: PanelContainer = hp.panel
	_hint_body = hp.body
	_box = panel
	_box_col = hp.col
	add_child(panel)
	panel.anchor_left = 0.5
	panel.anchor_right = 0.5
	panel.anchor_top = 0.0
	panel.anchor_bottom = 0.0
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_btn_row = HFlowContainer.new()
	_btn_row.alignment = FlowContainer.ALIGNMENT_CENTER
	_btn_row.add_theme_constant_override("h_separation", 40)
	_btn_row.add_theme_constant_override("v_separation", 10)
	_btn_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_box_col.add_child(_btn_row)
	_choice_ui.append(_btn_row)
	if not again:
		panel.modulate.a = 0.0
		create_tween().tween_property(panel, "modulate:a", 1.0, 0.4).set_delay(0.3)
	# every option is a button in the box; one that can't be taken (too few Leaves, no bottle to throw...) is silently left out
	var opts: Array = ev.get("options", [])
	var buttons: Array = []
	for i in opts.size():
		if hidden_opts.has(i) or (disabled.size() > i and disabled[i]) or _prop_for(i):
			continue
		buttons.append(_button(i, 0.0))
	_opt_buttons = buttons
	if again or String(ev.get("begin", "")) == "":
		_begun = true
		_page_text(String(ev.get("text", "")), buttons)
	else:
		var go := UiTheme.button(String(ev.begin), _begin, 28)
		go.custom_minimum_size = Vector2(0, 58)
		_page_text(String(ev.get("text", "")), [go])


func _prop_for(i: int) -> bool:
	for r: Dictionary in _props:
		if int(r.opt) == i:
			return true
	return false


func _button(i: int, w: float) -> Button:
	var opts: Array = ev.get("options", [])
	var label := String(opts[i].label)
	var b := UiTheme.button(label, _pressed_option.bind(i), 28)
	b.custom_minimum_size = Vector2(maxf(w, 0.0), 58)  # (as wide as its words)
	return b


## A button in the box: an option that asks for one of your things opens their row first, any other is chosen.
func _pressed_option(i: int) -> void:
	if _has_items(i):
		_open_items(i)
	else:
		await _choose(i)


## An option that asks for one of your things (a spell, an artifact, a bottle): its row comes up under the stage, the
## box says what to pick, and Back returns to the choices.
func _open_items(i: int) -> void:
	if _busy:
		return
	Audio.play("ui_click", -4.0)
	_drop_item_views()
	_only_opt = i
	_build_items(LAYOUTS.get(String(ev.get("id", "")), {}))
	var opts: Array = ev.get("options", [])
	var back := UiTheme.button("Back", _close_items, 28)
	back.custom_minimum_size = Vector2(0, 58)
	_page_text("%s: pick one below." % String(opts[i].label), [back])


func _drop_item_views() -> void:
	for r: Dictionary in _item_views:
		if is_instance_valid(r.node):
			(r.node as Control).queue_free()
	_item_views.clear()
	_item_picks.clear()
	if is_instance_valid(_item_row):
		_choice_ui.erase(_item_row)
		_item_row.queue_free()


func _close_items() -> void:
	if _busy:
		return
	Audio.play("ui_click", -4.0)
	_drop_item_views()
	_only_opt = -1
	if is_instance_valid(_offer_dim):
		_offer_dim.queue_free()
	_page_text(_choice_text() if String(ev.get("begin", "")) != "" else String(ev.get("text", "")), _opt_buttons)


## The words in the box, a page at a time (at most BOX_LINES lines a page); the last page has `last` under it (the choices, or
## the button after a result). The earlier pages have a "Go on..." button.
func _page_text(text: String, last: Array) -> void:
	_pages = _paginate(text)
	_page_i = 0
	_page_last = last
	_show_page()


func _show_page() -> void:
	for c in _btn_row.get_children():
		_btn_row.remove_child(c)
		if not (c in _page_last):
			c.queue_free()
	_hint_body.text = Keywords.colorize(String(_pages[_page_i]), true) if not _pages.is_empty() else ""
	_hint_body.visible = not _pages.is_empty() and String(_pages[_page_i]) != ""
	if _page_i < _pages.size() - 1:
		var more := UiTheme.button("Go on...", func():
			_page_i += 1
			Audio.play("ui_click", -6.0)
			_show_page(), 28)
		more.custom_minimum_size = Vector2(0, 58)
		_btn_row.add_child(more)
	else:
		for b in _page_last:
			if is_instance_valid(b):
				_btn_row.add_child(b)
		_even_buttons()
	await get_tree().process_frame
	_fit_box()


## The choices stand evenly: all as wide as the widest, when they fit on one line (otherwise each keeps its own width).
func _even_buttons() -> void:
	var bs: Array = _btn_row.get_children().filter(func(c: Node) -> bool: return c is Button)
	if bs.size() < 2:
		return
	var w := 0.0
	for b: Button in bs:
		b.custom_minimum_size.x = 0.0
		w = maxf(w, b.get_combined_minimum_size().x)
	w += 40.0  # (a little air around the words)
	var gap := float(_btn_row.get_theme_constant("h_separation"))
	if w * bs.size() + gap * (bs.size() - 1) > BOX_TEXT_W:
		return
	for b: Button in bs:
		b.custom_minimum_size.x = w


## The box keeps its bottom edge at the bottom of the screen and grows upwards with its words.
func _fit_box() -> void:
	if not is_instance_valid(_box):
		return
	_box.reset_size()
	_box.size.x = BOX_TEXT_W + 70.0
	_box.position = Vector2(960.0 - _box.size.x / 2.0, BOX_BOTTOM - _box.size.y)


## Splits words into pages of at most BOX_LINES lines at the box's size: by paragraph, then by sentence.
func _paginate(text: String) -> Array:
	if text.strip_edges() == "":
		return [""]
	var font: Font = _hint_body.get_theme_font("normal_font")
	var max_h := float(BOX_LINES) * (font.get_height(BOX_PX) + 2.0) + 4.0
	var fits := func(t: String) -> bool:
		return font.get_multiline_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, BOX_TEXT_W - 28.0, BOX_PX).y <= max_h
	var pieces: Array = []
	for para in text.split("\n", false):
		var re := RegEx.new()
		re.compile("[^.!?…]+[.!?…]+[\"'”’)]*\\s*|[^.!?…]+$")
		var sents: Array = []
		for m in re.search_all(String(para)):
			sents.append(m.get_string().strip_edges())
		if sents.is_empty():
			sents = [String(para)]
		pieces.append(sents)
	var pages: Array = []
	var cur := ""
	for p_i in pieces.size():
		var sents: Array = pieces[p_i]
		for s_i in sents.size():
			var s: String = sents[s_i]
			var join := ("\n" if s_i == 0 else " ") if cur != "" else ""
			var tryt: String = cur + join + s
			if cur != "" and not fits.call(tryt):
				pages.append(cur)
				cur = s
			else:
				cur = tryt
	if cur != "":
		pages.append(cur)
	return pages


func _exit_tree_cart() -> void:
	Audio.stop_held(_cart_snd, 0.1)


func _process(d: float) -> void:
	_t += d
	_move_whispers(d)
	for o in _opt_tags:  # (the option tags follow their props: they walk on, bob and fly)
		var e: Dictionary = _opt_tags[o]
		if is_instance_valid(e.tag) and int(e.k) < _props.size():
			var n: TextureRect = _props[int(e.k)].node
			var tg: Control = e.tag
			var at := Vector2(n.position.x + n.size.x / 2.0 - tg.size.x / 2.0, n.position.y - tg.size.y - 8.0)
			tg.position = Vector2(clampf(at.x, 10.0, 1910.0 - tg.size.x), maxf(at.y, 120.0))
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
		elif r.bob and not r.get("gone", false) and (_t > 1.6 or again):
			n.position.y = float(r.home.y) + sin(_t * 1.6 + float(r.ph)) * 14.0  # (floats: the sprite, the lights)
		elif int(r.opt) >= 0 or r.tag == "cactus":
			n.rotation = sin(_t * 1.3 + float(r.ph)) * 0.012  # (rocks a hair on its base, like the other puppets)


func _gui_input(e: InputEvent) -> void:
	if _edit:
		_edit_mouse(e)
		return
	if _busy or not _begun:
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
		if is_instance_valid(n) and n != _btn_row:  # (the box's button row stays: the result's button goes in it)
			n.queue_free()
	_choice_ui.clear()
	_fz_text = text
	_fz_ids = run_ref.fusable()
	_fz_slots = ["", ""]
	_fz_row.clear()
	_fz_zoom = clampf(1880.0 / (maxf(1.0, float(_fz_ids.size())) * (SpellCard.W + 8.0)), 0.3, 1.0)  # (native size; only a very long spellbook shrinks)
	# everything but the cards, the two boards and the box goes dim
	_fz_dim = ColorRect.new()
	_fz_dim.color = Color(0, 0, 0, 0.0)
	_fz_dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_fz_dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_fz_dim)
	if is_instance_valid(_box):
		move_child(_fz_dim, _box.get_index())
	_fz_dim.create_tween().tween_property(_fz_dim, "color:a", 0.55, 0.3)
	if _hint_body != null:
		_hint_body.text = Keywords.colorize("Click or drag two spells into the two boards. The pattern of the first one goes first. The new spell shows beside them.")
		_hint_body.visible = true
		_fit_box.call_deferred()
	var sw := SpellCard.W * FZ_SLOT_ZOOM + FZ_RIM * 2.0  # (a card at its own size on its board)
	var sh := SpellCard.H * FZ_SLOT_ZOOM + FZ_RIM * 2.0
	var cx := 960.0  # (the two boards: top middle of the screen)
	var top := 130.0
	_fz_prev_at = Vector2(cx + sw + 70.0, top + FZ_RIM)  # (the new spell stands to the right of the two, once both are in)
	_fz_slot_box.clear()
	for k in 2:
		var p := PanelContainer.new()
		p.custom_minimum_size = Vector2(sw, sh)
		p.size = Vector2(sw, sh)
		p.add_theme_stylebox_override("panel", board_box(int(FZ_RIM), int(FZ_RIM)))
		p.position = Vector2(cx - sw - 10.0 + float(k) * (sw + 20.0), top)
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
	_fz_btns.offset_top = FZ_ROW_Y + SpellCard.H * _fz_zoom + 20.0
	var back := UiTheme.button("Back", func(): _fuse_back(), 22)
	back.custom_minimum_size = Vector2(0, 52)
	_fz_btns.add_child(back)
	_fz_fuse = UiTheme.button("Fuse", func(): _fuse_go(), 22)
	_fz_fuse.custom_minimum_size = Vector2(0, 52)
	_fz_fuse.disabled = true
	_fz_btns.add_child(_fz_fuse)
	add_child(_fz_btns)
	_fuse_refresh()


const FZ_SLOT_ZOOM := 1.0
const FZ_PREVIEW_ZOOM := 1.0
const FZ_ROW_Y := 400.0  # the top of the row of spells, under the two boards
var _fz_dim: ColorRect
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
		card.position = Vector2(x0 + float(i) * (cw + gap), FZ_ROW_Y)
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
	for c in [_fz_prev, _fz_btns, _fz_dim]:
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
	if _opt_tags.has(int(r.opt)):
		return  # (its words are up already)
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


func _drop_opt_tags() -> void:
	for o in _opt_tags:
		var tg = _opt_tags[o].tag
		if is_instance_valid(tg):
			tg.queue_free()
	_opt_tags.clear()


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
	_drop_opt_tags()
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
