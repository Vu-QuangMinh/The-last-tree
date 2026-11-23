class_name Creature
extends Control
## Procedural enemy portrait: body shape picked from the enemy id, tinted by its HP elements.

var enemy_id := ""
var tint := Color(0.6, 0.6, 0.6)
var accent := Color(1, 1, 1)
var big := 1.0
const DRAWN_ONLY := []  # drawn in code until their new art comes (the Bug Hunter has its art now: BugHunterRig; _draw_bell_head stays as the fallback when its pieces are missing)
var ground_drop := 0.0  # a flyer: how far (px) below its picture the real ground is (its shadow lies there; set by EnemyView)
var flash := 0.0
var bob := 0.0
## Getting hit: it jolts (shake, decaying), blinks white a few times, and pulls a pained face for a moment.
var hurt := 0.0  # seconds of the pained face left
var _swing_a := 0.0  # Puppet Stage: how far it hangs off plumb on its rope (radians) ...
var _swing_v := 0.0  # ... and how fast that is changing
var _hurt_seen := 0.0
const SWING_K := 9.0  # the pull back to plumb (a long rope: about two seconds a swing)
const SWING_DAMP := 1.1  # the air: a push dies down over a few swings
const SWING_HIT := 0.8  # a hit knocks it back this hard (enough to see it register, not a big swing)
const SWING_MAX := 0.22
const ROPE_SWING := 0.3  # the swing, seen from the ceiling: the rope only moves a little, the puppet swings at its end
var _shake := 0.0  # pixels of jolt, decaying
var _blink := 0.0  # seconds of white blinking left
const HURT_TIME := 1.75  # long enough for the player to see the reaction
var shape := 0
var crown := false
var spikes := false
var dead := false
var _enemy: EnemyState = null  # for drawn art: how much Essence it has left picks the face
var _max_hp := 1  # Essence it started with (or the most it has had since)
var _yin_rot := 0.0  # the Yin Yang Beast's symbol: turned upside down (PI) when it is black
var _yin_target := 0.0
var _yin_last := ""
var _orbit_t := 0.0
var _orbs: Array = []  # the Invoker's words so far: their Essence orbit him for the rest of the fight
var _art_tip := 0.0  # the tilt the picture was last drawn with, and how far the jolt of a hit moved it sideways (for the rope mode's rivets)
var _art_shake_x := 0.0
var _art_xf := Transform2D.IDENTITY  # the puppet's own transform in this Control (its feet, its tip), for pieces drawn on their own
var _ret: RetainerRig  # the Retainer's front arm and what it carries (null: the finished pictures are used)
var _samurai: SamuraiRig  # the Samurai's pieces (null: the single picture is used)
var _bug: BugHunterRig  # the Bug Hunter's pieces (null: the single picture is used)
var _dragon: DragonRig  # the Winter Wyvern's pieces (null: the single picture is used)
var _floaters: Array = []  # [texture, centre fraction, phase] of the loose pieces hovering by the puppet (FLOATERS)
var _unveil_tex: Array = []  # [ball without its veil, head, left legs, right legs] of the Veiled Eyes' unveiling (see _draw_unveil)
var _unveil_t := -1.0  # -1: not playing; 0 .. UNVEIL_DUR: seconds into the unveiling
var _saw_veil1 := false  # it has been drawn as phase 1 (only then does phase 2 come with the animation)
var steal_pose := 0.0  # 0..1: the legs of the Veiled Eyes fold round a spell card it is carrying off (see _draw_steal_pose; tweened by FightScreen)
var _veil1_lit: Texture2D  # phase 1 with its eyes glowing (veiled_eyes_lit)
var _veil_tex: Array = []  # [phase 2, phase 2 with its eyes lit] of the Veiled Eyes (empty: drawn procedurally)
var _art := {}  # face name -> Texture2D, for enemies with drawn art (empty: drawn procedurally)

## Enemies with drawn art (New theme): one picture per face (angry: half its Essence or more; normal: low, under half; hurt: just hit).
## They live in New/Enemies/Act<n>/ (the file name has a %s for the face).
const ART := {"ashling": "ashling_%s.webp", "triplet_fire": "ashling_%s.webp"}
const ART_FACES := ["angry", "normal", "hurt"]
## Drawn art with two forms (the Yin Yang Beast and its Cubs): form 1 in its starting colour, form 2 once it has
## flipped (a black Cub is form 2 from the start). Each form has the three faces: path % [face, form].
const ART_FORMS := {"yin_yang_beast": "res://assets/enemies/yin_yang_%s_%d.webp", "yin_yang_clone": "res://assets/enemies/yin_yang_%s_%d.webp"}

## Puppet Stage: every enemy that has a cut-out in Puppet/Enemies/Act1..3/ (named after its id, or the PUPPET_FILES entry) is drawn from that
## one picture instead of its procedural body; it rocks on its base instead of bobbing, and tips back when hit.
const ENEMY_ACTS := [1, 2, 3]
const PUPPET_FILES := {"wyvern_head": "winter_wyvern", "wyvern_tail": "winter_wyvern", "wyvern_fireball": "dragon/fireball",  # (the wyvern's parts are drawn from DragonRig; the file only says it has art)
	"triplet_fire": "triplet_fire", "triplet_water": "triplet_water", "triplet_air": "triplet_air", "spiderling_a": "spiderling", "spiderling_b": "spiderling",
	"forge_spirit_b": "forge_spirit"}  # (the Wizard's second Forge Spirit: the same puppet)
## Loose pieces that hover next to a puppet instead of being painted on it: [file in Enemies/Act<n>/, centre as a fraction of the picture's square, phase].
## The Invoker's three orbs float above his open palm (cut off his hand by tools/import_act1_fix.py), each bobbing on its own beat.
const FLOATERS := {"invoker": [["invoker/orb_fire", Vector2(0.7274, 0.4508), 0.0], ["invoker/orb_water", Vector2(0.7640, 0.3995), 2.1], ["invoker/orb_wind", Vector2(0.7953, 0.4555), 4.2]]}

const SHAPES := {
	# act 1 (the Verdant Circle)
	"iceling": 1, "zephling": 1, "triplet_fire": 1, "triplet_water": 1, "triplet_air": 1, "purple_slime": 0, "green_slime": 0, "yellow_slime": 0, "giant_slime": 0,
	"bramble_back": 4, "winged_tortoise": 3, "yeti": 4, "rolling_bear": 4, "enraged_bear": 4, "mirror_fairy": 2, "tomato_knight": 2, "greenseer": 5,
	"puddle_slime": 0, "tide_colossus": 0, "last_gasp_spore": 0,
	"gale_sprite": 1, "mirror_wisp": 1, "storm_imp": 1, "hush_moth": 1, "leech_bat": 1, "echo_wraith": 1, "storm_rider": 1,
	"stone_knight": 2, "warded_golem": 2, "lockwarden": 2, "woodcutter": 2, "invoker": 2, "forge_spirit": 1, "yin_yang_beast": 4, "yin_yang_clone": 4, "inverter": 2, "mimic_chest": 3,
	"cinder_hound": 4, "bramble_matron": 5, "mirror_knight": 2, "void_archon": 1, "pickpocket_imp": 4, 
	"rot_snake": 4, "sentinel": 2, "blue_sentinel": 2, "headless_horseman": 4, "scav_rat": 4, "scav_hyena": 4, "scav_vulture": 1, "scav_beetle": 4, "mad_soldier": 2, "tree_dweller": 5, "bog_fish": 4, "bug_hunter": 2, "mob_pitchfork": 2, "mob_slingshot": 2, "mob_torch": 2, "shield_bearer": 2, "necromancer": 5,
	"tidecaller": 5, "frost_hex": 5, "ashling": 1, "last_winter": 1,
	"dragon_tail": 4, "dragon_head": 4, "dragon_fireball": 1, "wyvern_tail": 4, "wyvern_head": 4, "wyvern_fireball": 1,  # (the Fire Dragon and the Winter Wyvern: stand-ins until its pieces are drawn)
}


const THICKNESS := Color(0.2, 0.11, 0.05)  # (Puppet Stage: the colour of a plank's edge)
var _puppet := false  # Puppet Stage cut-out in use
## A Handyman hand in the Puppet Stage is not a picture but a two-bone wooden arm (HandymanRig.ARMS): it turns a little about its shoulder and
## its elbow all the time, swings hard when it attacks, and goes limp when it is knocked out. Its shoulder hangs on the Handyman's body (HandymanStage).
var _rig := {}  # the arm's entry of HandymanRig.ARMS ({} for everything else)
var _rig_tex: Array = []  # [upper, lower]
var swing := 0.0  # the attack, set by the fight screen: -0.4 wound up ... 1 struck
## A hand that reaches for something on the screen (the Tweezer Hand stealing Essence): `poke` 0 = hanging as usual ... 1 = the tip of its tool is on
## `poke_target` (a screen point), the sticks stretched to get there (see _poke_pose). Only the arms in POKE_TIP can do it.
var poke := 0.0
var poke_target := Vector2.ZERO
var _arm_tip := Vector2.ZERO  # where the tip of the tool was drawn last, in this Control's own coordinates
## The tip of the tool of an arm, in px of the arm's lower piece (the Tweezer: where the two prongs close).
const POKE_TIP := {"hand_tweezer": Vector2(432.5, 169.5), "hand_hammer": Vector2(535.0, 85.0), "hand_sword": Vector2(690.0, 52.0), "hand_spear": Vector2(640.0, 436.0)}  # (the spear: the point of its head)
## A hand that aims (the Crossbow Hand): the direction the weapon fires in, in the lower stick's picture (rad, the stick along +x).
const AIM_BOW := {"hand_crossbow": 0.588, "hand_spear": 0.94}  # (the spear: its point, seen from the lower stick)
var lunge := Vector2.ZERO  # the whole arm pushed this far (screen px): the Spear Hand thrusting
var aim := 0.0  # 0 -> 1: how far the lower arm has turned to aim_dir
var aim_dir := INF  # the direction (screen angle) the weapon is to point in  # (the hammer: the middle of the head's right face)  # (the lower prong's tip, since the 2026-10-20 Handyman.pdf: the tweezers point down)
var intro := 0.0  # 1 -> 0: the arm reaches out from the body when it first appears
var _fold_t := 0.0  # 0 -> 1 while the hand is knocked out (it folds away behind the Handyman's back), 1 -> 0 when it comes back
var _drop_t := 0.0  # 0 -> 1 when the hand is knocked off and falls to the floor, 1 -> 0 when he pulls it back up to his shoulder
var drop_hold := false  # (set by the fight screen) keep the arm on the floor although it is no longer knocked off: he has not pulled it up yet
var quake := 0.0  # seconds left of a hard shake of the whole picture (the Handyman's body in his last stand)
var _land := 0.0  # seconds since the arm hit the floor (a little bounce)
var _gear_t := 0.0  # the clock of the arm's jammed machinery (a knocked-out arm)
var _drive := 1.0  # 0..1: how much the broken gears pull right now (0 = stuck, it only trembles)
var _rig_phase := 0.0


## The picture of an enemy in the chosen theme's Enemies folder: its own act's folder first, then the others (null when there is none).
static func enemy_path(file: String, act := 1) -> String:
	var order: Array = [act] + ENEMY_ACTS.filter(func(a): return a != act)
	for a in order:
		var path: String = UiSkin.theme_dir() + "Enemies/Act%d/%s" % [a, file]
		if ResourceLoader.exists(path):
			return path
	return ""


static func _puppet_tex(file: String, act := 1) -> Texture2D:
	var path := enemy_path(file + ".png", act)
	return load(path) as Texture2D if path != "" else null


func setup(e: EnemyState) -> void:
	enemy_id = e.id
	_enemy = e
	_max_hp = maxi(1, maxi(e.size(), str(e.def.get("hp", "")).length()))
	_art.clear()
	if ART_FORMS.has(e.id):
		for form in [1, 2]:
			for face in ART_FACES:
				var fpath: String = ART_FORMS[e.id] % [face, form]
				if ResourceLoader.exists(fpath):
					_art["%s_%d" % [face, form]] = load(fpath)
	elif ART.has(e.id):
		for face in ART_FACES:
			var path := enemy_path(ART[e.id] % face, int(e.def.get("act", 1)))
			if path != "":
				_art[face] = load(path)
	_puppet = false
	if UiSkin.is_puppet():
		var file: String = PUPPET_FILES.get(e.id, e.id)
		if e.id in ["yin_yang_clone", "yin_yang_beast"]:  # (one picture per colour; _draw_art picks by its current colour)
			for c in ["white", "black"]:
				var tc := _puppet_tex(e.id + "_" + c, int(e.def.get("act", 1)))
				if tc != null:
					_art["yin_" + c] = tc
		var t := _puppet_tex(file, int(e.def.get("act", 1))) if not (e.id in DRAWN_ONLY) else null
		if t != null:
			_art = {"angry": t, "normal": t, "hurt": t}
		if e.id == "veiled_eyes":  # (phase 1 is the plain file; phase 2 the spider, and its twin with the eyes glowing: tools/import_veiled_eyes.py)
			_veil_tex = [_puppet_tex("veiled_eyes_2", 2), _puppet_tex("veiled_eyes_2_lit", 2)]
			_unveil_tex = [_puppet_tex("veiled_eyes_u_ball", 2), _puppet_tex("veiled_eyes_u_head", 2), _puppet_tex("veiled_eyes_u_legl", 2), _puppet_tex("veiled_eyes_u_legr", 2)]
			_veil1_lit = _puppet_tex("veiled_eyes_lit", 2)
			_saw_veil1 = false
			_unveil_t = -1.0
		_fall_tex = _puppet_tex(file + "_fallen") if e.def.get("flying", false) else null  # (a flyer knocked out of the air lies there stunned: its own picture)
		_thrown_tex = _puppet_tex("headless_horseman_thrown") if e.id == "headless_horseman" else null  # (the Horseman after he has thrown his head: the hand is empty)
		if e.id == "anxious_armadillo":
			_sad_tex = _puppet_tex("anxious_armadillo_sad", 2)
		_small_tv = _puppet_tex("corrector_small_screen", 2) if e.id == "corrector" else null
		_small_on = false
		_boot_t = -1.0
		_pose_tex = {}
		if e.id == "samurai":  # (one picture per stance: samurai_in_no_kamae / _ko_gasumi / _sha_no_kamae.png)
			for pose in SAMURAI_POSES:
				var pt := _puppet_tex("samurai_" + pose, 2)
				if pt != null:
					_pose_tex[pose] = pt
			if _art.is_empty() and not _pose_tex.is_empty():
				var any: Texture2D = _pose_tex.values()[0]
				_art = {"angry": any, "normal": any, "hurt": any}
		if e.id == "handyman":  # (his two faces: the smiling body above, and the crying one when a hand of his takes damage)
			_sad_tex = _puppet_tex("handyman_sad", 1)
			add_to_group("handyman_body")
		_puppet = not _art.is_empty()
		_floaters = []
		if _puppet and FLOATERS.has(e.id):
			for f in FLOATERS[e.id]:
				var ft := _puppet_tex(f[0], int(e.def.get("act", 1)))
				if ft != null:
					_floaters.append([ft, f[1], f[2]])
		_samurai = SamuraiRig.load_rig(2) if e.id == "samurai" and _puppet else null
		_bug = BugHunterRig.load_rig(2) if e.id == "bug_hunter" and _puppet else null
		_ret = RetainerRig.load_rig(2) if e.id == "samurai_retainer" and _puppet else null
		if e.id == "samurai_retainer":  # (his poses: one finished picture each; the one without a pose is the idle one)
			for p in RETAINER_POSES:
				var rt := _puppet_tex("samurai_retainer_" + p, 2)
				if rt != null:
					_pose_tex[p] = rt
		_dragon = DragonRig.for_part(e, self) if e.def.has("rig_part") and _puppet else null
		_rig = {}
		_rig_tex = []
		if HandymanRig.ARMS.has(e.id):
			var arm: Dictionary = HandymanRig.ARMS[e.id]
			var up := enemy_path(arm.upper, 1)
			var lo := enemy_path(arm.lower, 1)
			if up != "" and lo != "":
				_rig = arm
				_rig_tex = [load(up), load(lo)]
				_rig_phase = float(hash(e.id) % 628) / 100.0
	shape = SHAPES.get(e.id, hash(e.id) % 6)
	var counts := {"F": 0, "W": 0, "A": 0}
	for c in e.def.hp:
		counts[c] += 1
	var col := Color(0, 0, 0)
	var total := 0.0
	for k in counts:
		col += Elements.COLORS[k] * counts[k]
		total += counts[k]
	tint = (col / total).darkened(0.25)
	if e.def.has("tint"):
		tint = e.def.tint  # (a look of its own: the Enraged Rolling Bear's red fur)
	tint.a = 1.0
	accent = Elements.COLORS[e.def.hp[0]]
	big = 1.2 if e.is_boss else (1.1 if e.is_elite or e.id == "giant_slime" else 1.0)
	big = e.def.get("size", big)
	if e.id == "pianist":
		big = 2.7  # (the boss at his piano: a big stage of his own)
	crown = e.is_boss and not e.has_passive("hand")
	spikes = e.is_elite
	bob = randf() * TAU
	# hovering the portrait shows the enemy's moves (clicks still reach whatever holds it)
	mouse_filter = Control.MOUSE_FILTER_PASS
	tooltip_text = EnemyInfo.moves_tooltip(e.id, e.dmg_bonus)


func _make_custom_tooltip(for_text: String) -> Object:
	if for_text.strip_edges() == "":
		return null  # no text (e.g. its tooltip is pinned): no hover tooltip at all
	return Keywords.make_tooltip(for_text)


## Hit for `strength` (1 = a full hit, less for a single Essence knocked off).
## The Handyman's face cries for a moment (one of his hands was hurt).
func cry(sec: float) -> void:
	_sad_t = maxf(_sad_t, sec)


const HANDY_HIT_KO := 2  # sfx_handy_hit_2: only when a hand is knocked out or the Handyman himself dies
const HANDY_HITS := [3, 4, 5, 6, 7]  # the grunts of an ordinary hit (sfx_handy_hit_<n>, cut from the user's take by tools/split_handyman_hits.py; a file that is not there is skipped)
static var _handy_hit_at := -10000
static var _handy_hit_last := -1
var _ko_seen := false  # (the first frame only learns the state: a screen built with a hand already down says nothing)
var _was_knocked := false
var _was_dead := false


## The Handyman (his body or one of his hands) takes a hit: a grunt, never the same one twice running, and not more often than every half second (all the hands of a Release
## are hit together).
func _handy_grunt() -> void:
	if _enemy == null or not (_enemy.id == "handyman" or _enemy.id.begins_with("hand_")):
		return
	var now := Time.get_ticks_msec()
	if now - _handy_hit_at < 500:
		return
	if _enemy.knocked or _enemy.size() <= 0:
		return  # (the blow that puts it down: the knock-out sound takes it, see _handy_ko_watch)
	var pool: Array = HANDY_HITS.filter(func(n): return ResourceLoader.exists("res://assets/Puppet/SFX/sfx_handy_hit_%d.wav" % n))
	if pool.is_empty():
		return
	_handy_hit_at = now
	var k: int = pool.pick_random()
	if pool.size() > 1:
		while k == _handy_hit_last:
			k = pool.pick_random()
	_handy_hit_last = k
	Audio.play("sfx_handy_hit_%d" % k, 0.0, randf_range(0.97, 1.03))


## A hand of the Handyman is knocked out, or the Handyman himself falls: the one grunt kept for that (HANDY_HIT_KO).
func _handy_ko_watch() -> void:
	if _enemy == null or not (_enemy.id == "handyman" or _enemy.id.begins_with("hand_")):
		return
	var knocked_now := _enemy.knocked
	var ko_now := false
	if _enemy.has_meta("ko_fresh"):  # (Fight marks a hand the moment it is knocked off: the view of the hand is rebuilt at once when the next hand grows, so a view cannot see the change itself)
		_enemy.remove_meta("ko_fresh")
		ko_now = true
	if ko_now or (_ko_seen and dead and not _was_dead and _enemy.id == "handyman"):
		_handy_hit_at = Time.get_ticks_msec()
		Audio.play("sfx_handy_hit_%d" % HANDY_HIT_KO, 0.0, randf_range(0.98, 1.02))
	_was_knocked = knocked_now
	_was_dead = dead
	_ko_seen = true


func hit(strength := 1.0) -> void:
	_handy_grunt()
	if not _rig.is_empty() and is_inside_tree():  # (a hand of the Handyman took damage: his body cries)
		get_tree().call_group("handyman_body", "cry", 1.4)
	hurt = HURT_TIME
	_shake = maxf(_shake, 7.0 * strength + 3.0)
	_blink = maxf(_blink, 0.18 + 0.22 * strength)


func _process(d: float) -> void:
	if _enemy != null and _orbs.size() < _enemy.stripped.size():
		# he said a word: its Essence appears and joins the orbit (it stays)
		var orb := ElementIcon.make(_enemy.stripped[_orbs.size()], 34)
		orb.size = Vector2(34, 34)
		orb.pivot_offset = orb.size / 2.0
		orb.highlight = true
		orb.scale = Vector2.ZERO
		add_child(orb)
		orb.create_tween().tween_property(orb, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		_orbs.append(orb)
	if not _orbs.is_empty():
		_orbit_t += d
		var c := Vector2(size.x / 2.0, size.y * 0.5)
		var s := minf(size.x, size.y) * 0.34 * big
		for k in _orbs.size():
			# each on its own ring, tilted 60 degrees from the last (the atom picture), going round fast
			var a := _orbit_t * 3.4 + TAU * k / 3.0
			var tilt := PI * k / 3.0
			var p := Vector2(cos(a) * s * 1.45, sin(a) * s * 0.42).rotated(tilt)
			var orb: ElementIcon = _orbs[k]
			orb.position = c + p - orb.size / 2.0
			orb.show_behind_parent = sin(a) < 0  # (behind him on the far half of its ring)
			orb.z_index = 2 if sin(a) >= 0 else 0  # (the near half: in front of his spell cards too)
		queue_redraw()
	if _enemy != null and _enemy.yin != "":
		if _yin_last == "":
			_yin_rot = 0.0 if _enemy.yin == "white" else PI
			_yin_target = _yin_rot
		elif _enemy.yin != _yin_last:
			_yin_target += PI  # it inverted: the symbol spins half a turn
		_yin_last = _enemy.yin
		_yin_rot = move_toward(_yin_rot, _yin_target, d * TAU)
	bob += d * 2.0
	_spider_tick(d)
	if _samurai != null:
		_samurai.tick(d, _pose(), dead)
	if _bug != null:
		_bug.tick(d, dead)
	if _ret != null:
		_ret.tick(d, "fan" if _ret_key() == "fan" else "bottle")
	if _dragon != null:
		_dragon.tick(d)
	if not _rig.is_empty():
		var folded := _enemy != null and _enemy.knocked and not _enemy.fallen
		var lying := _enemy != null and (_enemy.fallen or drop_hold)
		var was := _drop_t
		_drop_t = move_toward(_drop_t, 1.0 if lying else 0.0, d / (0.5 if lying else 1.1))
		if lying and was < 1.0 and _drop_t >= 1.0:
			_land = 0.0
		_land += d
		_gear_t += d
		# knocked out: the arm creeps away behind the Handyman, but the gears inside are broken: it moves a little, jams, trembles, moves again
		_drive = clampf(sin(_gear_t * 2.1) + 0.6 * sin(_gear_t * 3.4 + 1.3) + 0.25, 0.0, 1.0)
		if folded:
			_fold_t = move_toward(_fold_t, 1.0, d * 0.5 * _drive)
		else:
			_fold_t = move_toward(_fold_t, 0.0, d * 1.8)  # (it reaches out again, smoothly)
	_handy_ko_watch()
	if quake > 0.0:
		quake -= d
		_shake = maxf(_shake, 26.0)  # (a hard shake, not a jolt that dies away)
	flash = maxf(0.0, flash - d * 3.0)
	if _puppet:
		# the swing: pulled back to plumb, slowed by the air, nudged by a slow breeze of its own, knocked back by a hit
		if hurt > _hurt_seen + 0.01:
			_swing_v -= SWING_HIT
		_hurt_seen = hurt
		var t := Time.get_ticks_msec() / 1000.0
		var breeze := 0.018 * sin(t * 0.8 + bob) + 0.01 * sin(t * 1.9 + bob * 1.7)
		_swing_v += (-SWING_K * (_swing_a - breeze) - SWING_DAMP * _swing_v) * d
		_swing_a = clampf(_swing_a + _swing_v * d, -SWING_MAX, SWING_MAX)
	hurt = maxf(0.0, hurt - d)
	_sad_t = maxf(0.0, _sad_t - d)
	_shake = maxf(0.0, _shake - d * 30.0)
	_blink = maxf(0.0, _blink - d)
	queue_redraw()


func _draw() -> void:
	_draw_rings()  # (the Invoker's rings: drawn first, so he stands in front of them)
	var c := Vector2(size.x / 2.0, size.y * 0.58 + (0.0 if enemy_id == "pianist" else sin(bob) * 4.0))  # (the Pianist and his whole stage stand still: no bobbing)
	if _enemy != null and _enemy.yin != "":
		tint = Color(0.92, 0.91, 0.88) if _enemy.yin == "white" else Color(0.13, 0.13, 0.15)  # black and white only
		accent = Color(0.5, 0.5, 0.5)
	if _shake > 0.0:  # the jolt of a hit
		c += Vector2(randf_range(-_shake, _shake), randf_range(-_shake, _shake) * 0.5)
	var s := minf(size.x, size.y) * 0.34 * big
	# white blinks while hit: on and off a few times (and the older soft flash)
	var blink_on := _blink > 0.0 and fmod(_blink, 0.12) > 0.05
	var body := tint.lerp(Color.WHITE, maxf(flash, 0.85 if blink_on else 0.0))
	if dead:
		body = Color(0.2, 0.2, 0.2, 0.4)
	# shadow (the New theme stands it on a painted stump instead)
	if UiSkin.tex("enemy_stand") == null and not UiSkin.is_puppet():
		draw_set_transform(Vector2(c.x, size.y * 0.93), 0, Vector2(1, 0.25))
		draw_circle(Vector2.ZERO, s * 0.9, Color(0, 0, 0, 0.35))
		draw_set_transform(Vector2.ZERO)
	if not _rig.is_empty():
		_draw_arm(blink_on)
		return
	if not _art.is_empty():
		_draw_art(blink_on)
		if not ART_FORMS.has(enemy_id):
			_draw_yinyang(c, s)  # (two-form art paints its own yin-yang)
		return
	if enemy_id == "veiled_eyes":
		_draw_veiled(c, s, body, blink_on)
		return
	if enemy_id.begins_with("spiderling"):
		_draw_spiderling(c, s * 0.75, body)
		return
	if enemy_id == "spider_cocoon":
		_draw_cocoon(c, s * 0.8)
		return
	if enemy_id == "pianist":
		_draw_pianist(c, s, body)
		return
	if enemy_id == "bug_hunter":
		_draw_bell_head(c, s)
		return
	var eye_y := -s * 0.15
	match shape:
		0:  # blob
			var pts := PackedVector2Array()
			for i in 33:
				var t := i / 32.0 * TAU
				var r := s * (1.0 + 0.06 * sin(t * 5.0 + bob))
				pts.append(c + Vector2(cos(t) * r * 1.1, sin(t) * r * (0.8 if sin(t) < 0 else 0.55)))
			draw_colored_polygon(pts, body)
		1:  # floating wisp with wings
			for side in [-1, 1]:
				var w := PackedVector2Array([c, c + Vector2(side * s * 1.5, -s * 0.9 + sin(bob * 2.0) * 8), c + Vector2(side * s * 1.2, s * 0.2)])
				draw_colored_polygon(w, Color(accent, 0.45))
			draw_circle(c, s * 0.75, body)
			var tail := PackedVector2Array([c + Vector2(-s * 0.5, s * 0.3), c + Vector2(s * 0.5, s * 0.3), c + Vector2(sin(bob) * s * 0.3, s * 1.3)])
			draw_colored_polygon(tail, body)
		2:  # armoured knight / golem
			var r := Rect2(c - Vector2(s * 0.75, s * 0.9), Vector2(s * 1.5, s * 1.8))
			draw_rect(r, body)
			draw_rect(Rect2(c - Vector2(s * 0.55, s * 1.35), Vector2(s * 1.1, s * 0.6)), body.darkened(0.2))
			draw_rect(Rect2(c + Vector2(-s * 1.05, -s * 0.6), Vector2(s * 0.3, s * 1.1)), body.darkened(0.3))
			draw_rect(Rect2(c + Vector2(s * 0.75, -s * 0.6), Vector2(s * 0.3, s * 1.1)), body.darkened(0.3))
			eye_y = -s * 1.05
		3:  # chest
			draw_rect(Rect2(c - Vector2(s, s * 0.5), Vector2(s * 2, s * 1.1)), body.darkened(0.2))
			var lid := PackedVector2Array([c + Vector2(-s, -s * 0.5), c + Vector2(s, -s * 0.5), c + Vector2(s * 0.9, -s * 1.1 - sin(bob) * 6), c + Vector2(-s * 0.9, -s * 1.1 - sin(bob) * 6)])
			draw_colored_polygon(lid, body)
			for i in 6:
				var x := -s * 0.8 + i * s * 0.32
				draw_colored_polygon(PackedVector2Array([c + Vector2(x, -s * 0.5), c + Vector2(x + s * 0.16, -s * 0.5), c + Vector2(x + s * 0.08, -s * 0.25)]), Color.WHITE)
			eye_y = -s * 0.85
		4:  # beast on legs
			draw_set_transform(c, 0, Vector2(1.3, 0.8))
			draw_circle(Vector2.ZERO, s * 0.8, body)
			draw_set_transform(Vector2.ZERO)
			for i in 4:
				var x := -s * 0.8 + i * s * 0.53
				draw_line(c + Vector2(x, s * 0.4), c + Vector2(x + sin(bob + i) * 5, s * 1.1), body.darkened(0.3), 6.0)
			draw_circle(c + Vector2(s * 0.95, -s * 0.35), s * 0.45, body)
			eye_y = -s * 0.4
			c.x += s * 0.95
		5:  # robed caster
			var robe := PackedVector2Array([c + Vector2(0, -s * 1.1), c + Vector2(s * 0.9, s * 1.0), c + Vector2(-s * 0.9, s * 1.0)])
			draw_colored_polygon(robe, body.darkened(0.15))
			draw_circle(c + Vector2(0, -s * 0.6), s * 0.45, body)
			draw_circle(c + Vector2(s * 1.0, -s * 0.2 + sin(bob) * 5), s * 0.18, Color(accent, 0.9))
			draw_line(c + Vector2(s * 1.0, -s * 0.05), c + Vector2(s * 0.95, s * 1.0), Color(0.45, 0.3, 0.2), 4.0)
			eye_y = -s * 0.65
	if spikes:
		for i in 5:
			var x := -s * 0.6 + i * s * 0.3
			draw_colored_polygon(PackedVector2Array([c + Vector2(x - 8, eye_y - s * 0.45), c + Vector2(x + 8, eye_y - s * 0.45), c + Vector2(x, eye_y - s * 0.85)]), accent.darkened(0.2))
	if crown:
		var cy := eye_y - s * 0.6
		var pts := PackedVector2Array([c + Vector2(-s * 0.45, cy), c + Vector2(-s * 0.45, cy - s * 0.35), c + Vector2(-s * 0.22, cy - s * 0.15),
			c + Vector2(0, cy - s * 0.45), c + Vector2(s * 0.22, cy - s * 0.15), c + Vector2(s * 0.45, cy - s * 0.35), c + Vector2(s * 0.45, cy)])
		draw_colored_polygon(pts, Color(1, 0.82, 0.3))
	if not dead and hurt > 0.0:
		_draw_pained_face(c, s, eye_y)
	elif not dead:
		for side in [-1, 1]:
			var ep := c + Vector2(side * s * 0.25, eye_y)
			draw_circle(ep, s * 0.13, Color(1, 1, 0.9))
			draw_circle(ep + Vector2(side * 2, 2), s * 0.06, Color(0.1, 0.05, 0.05))
	if enemy_id == "samurai" and not dead:
		_draw_sword_stance(c, s)


## Ouch: eyes squeezed shut into "> <", brows pulled up in the middle, a small round "o" of a mouth, and a bead of
## sweat. It fades back to the normal face as `hurt` runs out.
	_draw_yinyang(c, s)


## The Yin Yang Beast's symbol on its head: the white half up while it is white; it spins round each time it inverts.
## The Invoker's rings: faint ellipses his orbiting Essence travel along.
func _draw_rings() -> void:
	if _orbs.is_empty():
		return
	var c := Vector2(size.x / 2.0, size.y * 0.5)
	var s := minf(size.x, size.y) * 0.34 * big
	for k in _orbs.size():
		var pts := PackedVector2Array()
		for i in 49:
			var a := TAU * i / 48.0
			pts.append(c + Vector2(cos(a) * s * 1.45, sin(a) * s * 0.42).rotated(PI * k / 3.0))
		var col: Color = Elements.COLORS.get((_orbs[k] as ElementIcon).el, Color.WHITE)
		draw_polyline(pts, Color(col, 0.35), 2.0, true)


func _draw_yinyang(c: Vector2, s: float) -> void:
	if _enemy == null or _enemy.yin == "":
		return
	var r := s * 0.32
	var at := c + Vector2(0, -s * 1.05)
	var white := Color(0.97, 0.96, 0.92)
	var black := Color(0.08, 0.08, 0.1)
	draw_set_transform(at, _yin_rot)
	draw_circle(Vector2.ZERO, r + 2.0, Color(0.45, 0.45, 0.45))
	draw_circle(Vector2.ZERO, r, black)
	var top := PackedVector2Array()
	for k in 25:
		var t := PI + k / 24.0 * PI
		top.append(Vector2(cos(t), sin(t)) * r)
	draw_colored_polygon(top, white)
	draw_circle(Vector2(-r / 2.0, 0), r / 2.0, white)
	draw_circle(Vector2(r / 2.0, 0), r / 2.0, black)
	draw_circle(Vector2(-r / 2.0, 0), r / 6.0, black)
	draw_circle(Vector2(r / 2.0, 0), r / 6.0, white)
	draw_set_transform(Vector2.ZERO)


func _draw_pained_face(c: Vector2, s: float, eye_y: float) -> void:
	var ink := Color(0.1, 0.05, 0.05)
	var w := maxf(2.0, s * 0.07)
	for side in [-1, 1]:
		var ep := c + Vector2(side * s * 0.25, eye_y)
		var r := s * 0.12
		# a ">" on the left, a "<" on the right: both point at the nose
		draw_polyline(PackedVector2Array([ep + Vector2(-side * r, -r * 0.8), ep + Vector2(side * r * 0.6, 0), ep + Vector2(-side * r, r * 0.8)]), ink, w, true)
		# brows tilted up towards the middle
		draw_line(ep + Vector2(-side * r * 1.1, -r * 1.6), ep + Vector2(side * r * 0.9, -r * 2.3), ink, w * 0.8, true)
	var mouth := c + Vector2(0, eye_y + s * 0.32)
	draw_circle(mouth, s * 0.09, ink)
	draw_circle(mouth + Vector2(0, s * 0.02), s * 0.05, Color(0.75, 0.25, 0.3))
	# a sweat drop on the side of the head
	var sd := c + Vector2(s * 0.55, eye_y - s * 0.1)
	draw_circle(sd, s * 0.07, Color(0.6, 0.85, 1.0, 0.9))
	draw_colored_polygon(PackedVector2Array([sd + Vector2(-s * 0.06, -s * 0.02), sd + Vector2(0, -s * 0.16), sd + Vector2(s * 0.06, -s * 0.02)]), Color(0.6, 0.85, 1.0, 0.9))


## The Samurai without his pictures: a katana drawn over the stand-in body, held in the stance of his next move.
## In no kamae: raised high over the head; Ko gasumi: level at head height, across the face; Sha no kamae: low and
## trailing behind, ready to draw upward.
func _draw_sword_stance(c: Vector2, s: float) -> void:
	var hilt := c + Vector2(s * 0.35, -s * 0.2)
	var ang := -PI * 0.62
	match _pose():
		"in_no_kamae":
			hilt = c + Vector2(s * 0.15, -s * 0.95)
			ang = -PI * 0.58
		"ko_gasumi":
			hilt = c + Vector2(s * 0.75, -s * 0.5)
			ang = PI * 1.03
		"sha_no_kamae":
			hilt = c + Vector2(s * 0.45, s * 0.35)
			ang = PI * 0.2
	var dir := Vector2.from_angle(ang)
	draw_line(hilt - dir * s * 0.35, hilt, Color(0.15, 0.1, 0.1), maxf(4.0, s * 0.1), true)  # the grip
	draw_line(hilt - dir.orthogonal() * s * 0.1, hilt + dir.orthogonal() * s * 0.1, Color(0.75, 0.6, 0.25), maxf(3.0, s * 0.06), true)  # the guard
	draw_line(hilt, hilt + dir * s * 1.5, Color(0.85, 0.88, 0.92), maxf(3.0, s * 0.06), true)  # the blade
	draw_line(hilt + dir * s * 0.1, hilt + dir * s * 1.45, Color(1, 1, 1, 0.8), maxf(1.0, s * 0.02), true)  # its edge catching the light


## The Bug Hunter (drawn until it has art): a brass bell for a body, with a hanging loop on top and ONE big eye on its
## front, on two thin jointed legs, with two arms: the left holds a magnifying glass up by the eye, the right a striker.
## It attacks by striking its own bell: the striker swings up and hits the bell, which shakes as it rings (bell_t 0..1
## while it does; see FightScreen._bell_strike).
var bell_t := -1.0


func _draw_bell_head(c: Vector2, s: float) -> void:
	var brass := Color(0.78, 0.62, 0.3) if not dead else Color(0.2, 0.2, 0.2, 0.4)
	var dark := brass.darkened(0.45)
	var t := bell_t
	var hit_t := 0.28  # (when the striker meets the bell)
	var shake := 0.0
	if t >= hit_t:
		shake = sin((t - hit_t) * 70.0) * 0.09 * exp(-(t - hit_t) * 4.0)
	# the legs (thin, jointed), behind the bell
	for side in [-1.0, 1.0]:
		var hip := c + Vector2(side * s * 0.22, s * 0.2)
		var knee := c + Vector2(side * s * 0.28, s * 0.62)
		var foot := c + Vector2(side * s * 0.2, s * 0.95)
		draw_polyline(PackedVector2Array([hip, knee, foot]), dark, maxf(4.0, s * 0.09), true)
		draw_circle(knee, s * 0.06, brass)
		draw_rect(Rect2(foot - Vector2(s * 0.12, s * 0.03), Vector2(s * 0.24, s * 0.07)), dark)
	# the striker: at rest it hangs down and to the right; striking, it swings up and over onto the bell
	var shoulder_r := c + Vector2(s * 0.5, s * 0.08)
	var hand := c + Vector2(s * 0.62, s * 0.4)
	var rest := 0.75  # (radians: down and to the right)
	var up := -2.75  # (up and over, onto the bell below its eye)
	var a := rest
	if t >= 0.0:
		if t < hit_t:
			a = lerpf(rest, up, smoothstep(0.0, hit_t, t))
		else:
			a = lerpf(up, rest, smoothstep(hit_t, 1.0, t))
	var tip := hand + Vector2.from_angle(a) * s * 0.85
	# the bell: swings about its loop as it rings
	var pivot := c + Vector2(0, -s * 1.05)
	draw_set_transform(pivot, shake)
	var top := -s * 0.05
	var rim := s * 1.32
	var pts := PackedVector2Array()
	for k in 21:
		var u := float(k) / 20.0  # 0..1 down the left side
		var w := lerpf(s * 0.3, s * 0.62, pow(u, 1.6))
		pts.append(Vector2(-w, lerpf(top + s * 0.1, rim, u)))
	for k in 21:
		var u := 1.0 - float(k) / 20.0
		var w := lerpf(s * 0.3, s * 0.62, pow(u, 1.6))
		pts.append(Vector2(w, lerpf(top + s * 0.1, rim, u)))
	draw_colored_polygon(pts, brass)
	draw_circle(Vector2(0, top + s * 0.14), s * 0.3, brass)  # (the dome)
	draw_rect(Rect2(-s * 0.66, rim - s * 0.12, s * 1.32, s * 0.14), brass.darkened(0.15))  # (the rim)
	draw_line(Vector2(-s * 0.6, rim - s * 0.2), Vector2(s * 0.6, rim - s * 0.2), dark, 2.0, true)
	draw_arc(Vector2(0, top - s * 0.08), s * 0.09, 0, TAU, 16, dark, maxf(3.0, s * 0.05), true)  # (the hanging loop)
	draw_line(Vector2(-s * 0.4, top + s * 0.35), Vector2(-s * 0.36, rim * 0.85), Color(1, 0.95, 0.8, 0.3), maxf(3.0, s * 0.05), true)  # (a shine)
	# the one big eye: a heavy brass ring, the white, an amber iris, a slit pupil that follows the glass (and shrinks when hurt)
	var eye := Vector2(0, s * 0.58)
	var er := s * 0.27
	draw_circle(eye, er * 1.2, dark)
	draw_circle(eye, er * 1.08, brass.lightened(0.12))
	draw_circle(eye, er, Color(0.96, 0.94, 0.86) if not dead else Color(0.3, 0.3, 0.3, 0.4))
	if not dead:
		var look := Vector2(-0.3, -0.12) + Vector2(sin(bob * 0.7), cos(bob * 0.5)) * 0.06  # (towards the glass, never still)
		var iris := eye + look * er
		draw_circle(iris, er * 0.55, Color(0.86, 0.5, 0.1))
		draw_circle(iris, er * 0.4, Color(0.62, 0.28, 0.05))
		var pr := er * (0.1 if hurt > 0.0 else 0.17)
		draw_rect(Rect2(iris - Vector2(pr, er * 0.36), Vector2(pr * 2.0, er * 0.72)), Color(0.05, 0.03, 0.02))
		draw_circle(iris + Vector2(-er * 0.18, -er * 0.2), er * 0.1, Color(1, 1, 1, 0.9))
		draw_arc(eye, er, PI * 1.05, PI * 1.95, 20, dark, 3.0, true)  # (the upper lid's line)
	draw_polyline(PackedVector2Array([Vector2(s * 0.4, rim - s * 0.15), Vector2(s * 0.34, rim * 0.75), Vector2(s * 0.38, rim * 0.6)]), dark, 1.5, true)
	draw_set_transform(Vector2.ZERO)
	# the left arm: holds the magnifying glass up in front of the bell, by the eye
	var shoulder_l := c + Vector2(-s * 0.5, s * 0.08)
	var elbow_l := c + Vector2(-s * 0.8, s * 0.16 + sin(bob * 1.3) * s * 0.02)
	var hand_l := c + Vector2(-s * 0.72, -s * 0.08 + sin(bob * 1.3) * s * 0.02)
	var lens := hand_l + Vector2(s * 0.14, -s * 0.36)
	var lr := s * 0.25
	draw_polyline(PackedVector2Array([shoulder_l, elbow_l, hand_l]), dark, maxf(3.0, s * 0.07), true)
	draw_circle(elbow_l, s * 0.05, brass)
	draw_line(hand_l - (lens - hand_l).normalized() * s * 0.08, lens, Color(0.35, 0.22, 0.12), maxf(4.0, s * 0.07), true)  # (the handle)
	draw_circle(lens, lr, Color(0.7, 0.88, 0.95, 0.28 if not dead else 0.1))  # (the glass)
	draw_arc(lens, lr, 0, TAU, 28, brass.darkened(0.1), maxf(4.0, s * 0.07), true)  # (its brass rim)
	draw_arc(lens, lr * 0.72, PI * 1.1, PI * 1.55, 10, Color(1, 1, 1, 0.7), 2.5, true)  # (a glint)
	draw_circle(hand_l, s * 0.07, brass)
	# the right arm and the striker, in front of the bell (it comes down onto it)
	draw_polyline(PackedVector2Array([shoulder_r, shoulder_r + (hand - shoulder_r) * 0.5 + Vector2(s * 0.12, 0), hand]), dark, maxf(3.0, s * 0.07), true)
	draw_line(hand, tip, Color(0.55, 0.42, 0.22), maxf(3.0, s * 0.06), true)
	draw_circle(tip, s * 0.13, brass.lightened(0.1))
	draw_circle(hand, s * 0.07, brass)
	# the sound: rings spreading out from the bell while it rings
	if t >= hit_t and not dead:
		var k := (t - hit_t) / (1.0 - hit_t)
		for j in 3:
			var kk := fmod(k * 1.5 + j * 0.33, 1.0)
			draw_arc(pivot + Vector2(0, s * 0.6), s * (0.8 + kk * 0.9), -PI * 0.85, -PI * 0.15, 24, Color(1.0, 0.9, 0.5, 0.6 * (1.0 - kk) * (1.0 - k)), 3.0, true)


## The Pianist (drawn until he has art): tall and thin like Slender Man, black suit, white collar, a top hat, at a
## piano. One arm (the left hand was cut off): his hand slides along the keyboard to the highest note sounding, and a
## foot, up on the keys, to the lowest. No key presses: just the arm going back and forth with the music. A thin bar
## on the music stand shows how much of the piece is left; a little sign beside him says "Silence, please".
var song: PianistSong  # (set by the fight screen while he plays)
var _hand_x := 0.5  # 0..1 along the keyboard, eased towards the note
var page_flip := -1.0  # 0..1 while he turns the page (-1: not turning)
var _foot_x := 0.2


## The Corrector's head is a TV: the screen shows what he is about to do (the picture of the intent and its number, in teal light);
## after the reboot (phase 2) a second, smaller TV sits on top of the first and shows the weaker move he adds every turn.
const CORR_SCREEN := Rect2(0.3896, 0.1904, 0.152, 0.1087)  # the big screen, in fractions of the art square
const CORR_SMALL := Rect2(0.405, -0.04, 0.19, 0.19)  # the small TV on top of the head (its square), in fractions of the art square
const CORR_SMALL_SCREEN := Rect2(0.1123, 0.2694, 0.7589, 0.514)  # its screen, in fractions of its own picture
const CORR_GLOW := Color(0.55, 1.0, 0.85)
var _small_tv: Texture2D
var _small_on := false
var _boot_t := -1.0  # seconds since the small screen lit up (-1: not yet)


func _draw_corrector(c: Vector2, side: float, mod: Color) -> void:
	var origin := c - Vector2(side, side) * 0.5
	var phase2: bool = _enemy != null and _enemy.phase >= 2 and _small_tv != null
	if phase2 and not _small_on:
		_small_on = true
		_boot_t = 0.0
		var au := get_node_or_null("/root/Audio")  # (the second screen lights up: a boot-up chime; absent in a test script)
		if au != null and is_inside_tree():
			au.play("sfx_boot_up")
	elif not phase2:
		_small_on = false
		_boot_t = -1.0
	var big_r := Rect2(origin + CORR_SCREEN.position * side, CORR_SCREEN.size * side)
	_screen_show(big_r, _enemy.intent if _enemy != null else {}, mod, 1.0)
	if phase2:
		var k := 1.0
		if _boot_t >= 0.0:
			_boot_t += get_process_delta_time()
			k = clampf(_boot_t / 0.45, 0.0, 1.0)
			k = 1.0 + 2.70158 * pow(k - 1.0, 3) + 1.70158 * pow(k - 1.0, 2)  # (it pops up with a little overshoot)
		var sq := Rect2(origin + CORR_SMALL.position * side, CORR_SMALL.size * side)
		var pivot := Vector2(sq.get_center().x, sq.end.y)
		var fit := minf(sq.size.x / _small_tv.get_width(), sq.size.y / _small_tv.get_height()) * k
		var sz := Vector2(_small_tv.get_width(), _small_tv.get_height()) * fit
		var at := Vector2(pivot.x - sz.x * 0.5, pivot.y - sz.y)
		draw_texture_rect(_small_tv, Rect2(at, sz), false, mod)
		var scr := Rect2(at + CORR_SMALL_SCREEN.position * sz, CORR_SMALL_SCREEN.size * sz)
		_screen_show(scr, _enemy.intent2, mod, 0.8 * k)


## One TV screen: dark teal glass, scan lines, a flicker, and the move (its picture and number) glowing on it.
func _screen_show(r: Rect2, m: Dictionary, mod: Color, a: float) -> void:
	draw_rect(r, Color(0.02, 0.08, 0.08, a))
	var glow := 0.85 + 0.15 * sin(bob * 7.0) + (0.12 if fmod(bob, 5.3) < 0.08 else 0.0)  # (an old set: a steady hum, and now and then a flicker)
	if not m.is_empty():
		var kind := String(m.get("kind", ""))
		var tex: Texture2D = UiSkin.tex(IntentChip.ART.get(kind, ""))
		var label := ""
		if m.has("n") and kind != "mend":
			label = "%d" % int(m.n)
			if m.has("hits"):
				label += "x%d" % int(m.hits)
		elif kind == "mend":
			label = "+%d" % int(m.get("n", 1))
		elif m.has("len"):
			label = "%d" % int(m.len)
		elif m.has("turns"):
			label = "%d" % int(m.turns)
		var fs := int(r.size.y * 0.46)
		var icon_h := r.size.y * (0.62 if label != "" else 0.8)
		var col := Color(CORR_GLOW, a * glow)
		var font := ThemeDB.fallback_font
		var tw := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x if label != "" else 0.0
		var iw := icon_h if tex != null else 0.0
		var x0 := r.get_center().x - (iw + tw + (r.size.y * 0.05 if tex != null and label != "" else 0.0)) * 0.5
		if tex != null:
			draw_texture_rect(tex, Rect2(Vector2(x0, r.get_center().y - icon_h * 0.5), Vector2(icon_h, icon_h)), false, Color(1.0, 1.0, 1.0, a * glow) * mod)
			x0 += iw + r.size.y * 0.05
		elif label == "":
			label = "?"
			tw = font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
			x0 = r.get_center().x - tw * 0.5
		if label != "":
			draw_string(font, Vector2(x0, r.get_center().y + fs * 0.35), label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)
	var y := r.position.y
	while y < r.end.y:  # (scan lines)
		draw_line(Vector2(r.position.x, y), Vector2(r.end.x, y), Color(0.0, 0.0, 0.0, 0.22 * a), 1.0)
		y += maxf(3.0, r.size.y * 0.06)
	draw_rect(r, Color(CORR_GLOW, 0.07 * a * glow))


var _pianist_rig: PianistRig  # (his pieces seen from the front: the first set of pictures; kept as a fallback)
var _pianist_back: PianistBackRig  # (his pieces seen from behind, the user's design; used when its pictures exist)
var _bk_rh := 6.5  # the picture of the right hand now (0..11, walks towards its target) and of the left foot (0..4)
var _bk_lf := 0.0  # the left foot's place along the keys, 0..1
var _bk_rh_target := 6.5
var _bk_started := false  # the music has started once: from then on the figure is the frames, before it the idle position of the PDF
var _bk_idle := 1.0
var _bk_lf_target := 0.0
var _bk_up := 1.0  # the left foot: 1 = raised (so it does not touch the keys; also while it travels), 0 = down on the key (only as the note sounds)
var _bk_foot_on := 0.0
var _pt_t := -1.0  # seconds into the sign sequence (-1: not running)
var _bk_warm := false  # Engage was pressed but the music has not started yet: the leg and the hand are moving to the first notes' places
var _bk_slam := 0.0  # 0..1: the last chord (The End)
var _slam_on := false
var _pianist_tried := false


## The sign sequence of the Pianist (see PianistBackRig.SEQ): he raises his arm, points at the "Silence, please" board three times (the fight screen plays the knocks at PianistBackRig.KNOCKS),
## lowers it and goes back to playing. Returns how many seconds it takes.
func pianist_point(_sec := 0.0) -> float:
	_pt_t = 0.0
	return PianistBackRig.SEQ_TIME


## Engage: until the music starts (a couple of seconds) he takes the playing position: the leg goes onto the keys and the hand to where the first note is.
func pianist_warm_up() -> void:
	_bk_warm = true


## The last chord: both arms and his whole back come down on the keys.
func pianist_slam() -> void:
	_slam_on = true


## What PianistBackRig draws now: the hand and the foot jump to the key of the note being struck (PianistSong), tap as it is struck, and so on.
func _back_state() -> Dictionary:
	var d := get_process_delta_time()
	var playing_now: bool = song != null and song.playing()
	var tm: float = song.time() if song != null else 0.0
	var rt := _bk_rh_target  # (where the right hand wants to be: 0..11)
	var lt := _bk_lf_target  # (the same for the left foot: 0..1 along the keys)
	var want_up := 1.0  # (the foot stays raised, except for a short tap as each note of the left hand sounds)
	if playing_now:
		_bk_warm = false
	if _bk_warm and song != null:
		_bk_started = true
		var r0: Dictionary = song.first_at(0)
		if not r0.is_empty():
			rt = float(r0.rt) * float(PianistBackRig.FRAMES - 1)
		var l0: Dictionary = song.first_at(1)
		if not l0.is_empty():
			lt = float(l0.lt)
	if playing_now:
		_bk_started = true
		var rh: Dictionary = song.hand_at(0, tm)  # the right hand: the pitch of the note it struck last, between the lowest and the highest note of its part
		if not rh.is_empty():
			rt = float(rh.rt) * float(PianistBackRig.FRAMES - 1)
		var lh: Dictionary = song.hand_at(1, tm)  # the left foot: over the key of the left hand's last note; once that tap is over it already travels (raised) to the next note's key
		if not lh.is_empty():
			var age := tm - float(lh.t)
			lt = float(lh.lt)
			var nxt := float(lh.next_t)
			if nxt >= 0.0 and age >= 0.1 and nxt - tm < 0.35:
				lt = float(lh.next_lt)
			if age < 0.1 or (nxt >= 0.0 and nxt - tm < 0.05):
				want_up = 0.0  # (down on the key exactly as the note sounds, then up again)
	if _pt_t >= 0.0:
		rt = 6.5  # (the sign sequence starts from the picture that is nearest to its own first one: the hand out on the keys)
	elif _bk_slam > 0.3:
		rt = float(PianistBackRig.FRAMES - 3)  # (the last chord: right_hand_10: the arm stretched out)
		lt = 0.0  # (and the left foot: the lowest place, the bass of the chord)
		want_up = 0.0
	elif page_flip >= 0.0:
		rt = 0.0  # (the page turn: right_hand_01: the hand comes back to the body)
	_bk_rh_target = rt
	_bk_lf_target = lt
	# the pictures are walked through, not jumped to: a leap of the melody sweeps through the pictures in between (the figure's frames lie on each other, so it is smooth)
	_bk_rh = move_toward(_bk_rh, rt, d * (6.0 if _bk_warm else 70.0))  # (slowly while he gets into position)
	# the foot slides only while it is raised (it never drags over the keys); it comes down and goes up fast
	if _bk_up > 0.6:
		_bk_lf = move_toward(_bk_lf, lt, d * (0.8 if _bk_warm else 7.0))
	_bk_up = move_toward(_bk_up, want_up, d * 16.0)
	_bk_idle = 0.0 if _bk_started else 1.0  # (the idle position of the PDF until the music starts, then it fades into the frames)
	_bk_foot_on = move_toward(_bk_foot_on, 1.0 if (playing_now or _bk_warm or _bk_slam > 0.3) else 0.0, d * 5.0)
	if _pt_t >= 0.0:
		_pt_t += d
		if _pt_t >= PianistBackRig.SEQ_TIME:
			_pt_t = -1.0
	_bk_slam = move_toward(_bk_slam, 1.0 if _slam_on else 0.0, d * 9.0)
	return {"rh": _bk_rh, "foot_x": _bk_lf, "foot_up": _bk_up, "foot_on": _bk_foot_on, "page": page_flip, "pt": _pt_t, "idle": _bk_idle,
		"sheet": (maxi(1, _enemy.page) - 1) % 4 if _enemy != null else 0, "slam": _bk_slam,
		"left": clampf(tm / maxf(song.length, 1.0), 0.0, 1.0) if song != null else 0.0}


func _puppet_ok() -> bool:
	return UiSkin.is_puppet()


func _draw_pianist(c: Vector2, s: float, body: Color) -> void:
	var kx0 := c.x - s * 1.3
	var kw := s * 2.6
	var ky := c.y + s * 0.3  # the keyboard's top edge
	# where the hand and the foot want to be (they glide there)
	if song != null and song.playing():
		var hl: Array = song.hands_at(song.time())
		if int(hl[0]) >= 0:
			var span := float(PianistSong.HIGH - PianistSong.LOW)
			_hand_x = lerpf(_hand_x, clampf((int(hl[0]) - PianistSong.LOW) / span, 0.0, 1.0), 0.35)
			_foot_x = lerpf(_foot_x, clampf((int(hl[1]) - PianistSong.LOW) / span, 0.0, 0.45), 0.25)
	if not _pianist_tried:
		_pianist_tried = true
		_pianist_back = PianistBackRig.load_rig() if _puppet_ok() else null  # (the view from behind, if its pieces are there)
		_pianist_rig = null if _pianist_back != null else (PianistRig.load_rig() if _puppet_ok() else null)
	if _pianist_back != null:
		_pianist_back.draw(self, c, s, _back_state(), Color(0.35, 0.35, 0.35, 0.6) if dead else Color.WHITE.lerp(Color(2, 2, 2), maxf(flash, 0.0) * 0.5))
		return
	if _pianist_rig != null:
		var playing_now: bool = song != null and song.playing()
		_pianist_rig.draw(self, c, s, {"hand": _hand_x, "foot": _foot_x, "page": page_flip, "dead": dead,
			"press": (0.5 + 0.5 * sin(song.time() * 19.0)) if playing_now else 0.0,
			"left": clampf(song.time() / maxf(song.length, 1.0), 0.0, 1.0) if song != null else 0.0, "t": bob},
			Color(0.35, 0.35, 0.35, 0.6) if dead else Color.WHITE.lerp(Color(2, 2, 2), maxf(flash, 0.0) * 0.5))
		return
	var suit := Color(0.07, 0.07, 0.09) if not dead else body
	var skin := Color(0.88, 0.86, 0.82)
	# him, behind the piano: a long thin body, the collar, the head and its hat
	var tx := c.x + s * 0.15
	draw_rect(Rect2(tx - s * 0.22, c.y - s * 1.05, s * 0.44, s * 1.4), suit)
	draw_colored_polygon(PackedVector2Array([Vector2(tx - s * 0.13, c.y - s * 1.05), Vector2(tx + s * 0.13, c.y - s * 1.05), Vector2(tx, c.y - s * 0.78)]), Color.WHITE)
	draw_line(Vector2(tx, c.y - s * 1.0), Vector2(tx, c.y - s * 0.8), Color(0.05, 0.05, 0.05), maxf(2.0, s * 0.04))  # (a thin black tie)
	var head := Vector2(tx, c.y - s * 1.22)
	draw_circle(head, s * 0.17, skin)
	draw_rect(Rect2(head.x - s * 0.26, head.y - s * 0.17, s * 0.52, s * 0.05), suit)  # the hat's brim
	draw_rect(Rect2(head.x - s * 0.16, head.y - s * 0.52, s * 0.32, s * 0.36), suit)  # its crown
	draw_rect(Rect2(head.x - s * 0.16, head.y - s * 0.24, s * 0.32, s * 0.05), Color(0.35, 0.05, 0.08))  # a dark red band
	# the stump of the left arm: an empty sleeve, pinned up
	draw_line(Vector2(tx - s * 0.22, c.y - s * 0.95), Vector2(tx - s * 0.36, c.y - s * 0.62), suit, maxf(4.0, s * 0.11), true)
	# the piano: a black body, the keys, the music stand with the clock of the piece
	draw_rect(Rect2(kx0 - s * 0.08, ky - s * 0.05, kw + s * 0.16, s * 0.75), Color(0.04, 0.03, 0.04))
	draw_rect(Rect2(kx0, ky, kw, s * 0.16), Color(0.95, 0.94, 0.9))
	var keys := 28
	for k in keys:
		var x := kx0 + kw * k / keys
		draw_line(Vector2(x, ky), Vector2(x, ky + s * 0.16), Color(0.55, 0.55, 0.55), 1.0)
		if k % 7 in [0, 1, 3, 4, 5]:
			draw_rect(Rect2(x + kw / keys * 0.65, ky, kw / keys * 0.6, s * 0.1), Color(0.05, 0.05, 0.05))
	var stand := Rect2(c.x - s * 0.35, ky - s * 0.32, s * 0.7, s * 0.22)
	draw_rect(stand, Color(0.93, 0.9, 0.82))
	if page_flip >= 0.0:
		# the page swings over from right to left (it narrows to an edge in the middle, then opens on the other side)
		var k := absf(cos(page_flip * PI))
		var right := page_flip < 0.5
		var pw := stand.size.x * 0.5 * k
		var px0 := stand.get_center().x if right else stand.get_center().x - pw
		draw_rect(Rect2(px0, stand.position.y - s * 0.02 * (1.0 - k), pw, stand.size.y), Color(1.0, 0.98, 0.92))
		draw_rect(Rect2(px0, stand.position.y - s * 0.02 * (1.0 - k), pw, stand.size.y), Color(0.4, 0.35, 0.3), false, 1.0)
	if song != null:
		var done := clampf(song.time() / maxf(song.length, 1.0), 0.0, 1.0)
		draw_rect(Rect2(stand.position + Vector2(s * 0.04, stand.size.y * 0.7), Vector2((stand.size.x - s * 0.08) * done, s * 0.035)), Color(0.55, 0.08, 0.1))
	for k in 3:  # (staff lines)
		var y := stand.position.y + stand.size.y * (0.2 + 0.15 * k)
		draw_line(Vector2(stand.position.x + s * 0.04, y), Vector2(stand.end.x - s * 0.04, y), Color(0.3, 0.3, 0.3), 1.0)
	# the arm: shoulder, elbow out to the side, the hand on the keys
	var shoulder := Vector2(tx + s * 0.2, c.y - s * 0.95)
	var hand := Vector2(kx0 + kw * _hand_x, ky + s * 0.04)
	if page_flip >= 0.0:
		hand = Vector2(stand.get_center().x + stand.size.x * 0.5 * cos(page_flip * PI), stand.position.y + s * 0.05)  # (his hand turns the page)
	var mid := (shoulder + hand) / 2.0
	var elbow := mid + (hand - shoulder).orthogonal().normalized() * s * 0.22 * (1.0 if hand.x < shoulder.x else -1.0)
	draw_polyline(PackedVector2Array([shoulder, elbow, hand]), suit, maxf(4.0, s * 0.1), true)
	draw_circle(hand, s * 0.06, skin)
	# the foot, up on the keys (a long leg out from behind the piano)
	var hip := Vector2(tx - s * 0.1, c.y + s * 0.25)
	var foot := Vector2(kx0 + kw * _foot_x, ky + s * 0.02)
	draw_line(hip, foot, suit, maxf(4.0, s * 0.11), true)
	draw_rect(Rect2(foot - Vector2(s * 0.1, s * 0.04), Vector2(s * 0.2, s * 0.07)), Color(0.02, 0.02, 0.02))
	# the sign
	var sp := Vector2(c.x + s * 1.2, c.y - s * 0.55)
	draw_line(sp + Vector2(0, s * 0.2), sp + Vector2(0, s * 1.2), Color(0.35, 0.25, 0.15), maxf(2.0, s * 0.04))
	var sr := Rect2(sp - Vector2(s * 0.42, s * 0.1), Vector2(s * 0.84, s * 0.3))
	draw_rect(sr, Color(0.92, 0.88, 0.78))
	draw_rect(sr, Color(0.3, 0.2, 0.1), false, 2.0)
	var font := ThemeDB.fallback_font
	var px := int(maxf(9.0, s * 0.1))
	for k in 2:
		var txt: String = ["SILENCE", "PLEASE"][k]
		var w := font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x
		draw_string(font, Vector2(sr.get_center().x - w / 2.0, sr.position.y + sr.size.y * (0.45 + 0.4 * k)), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, px, Color(0.2, 0.1, 0.05))


## Puppet Stage: the side of the square the puppet's picture is drawn in. The Handyman's body is drawn at the size his arms were cut for.
func _art_side() -> float:
	if enemy_id == "handyman" and _puppet:
		return HandymanRig.BODY_PX * HandymanRig.SCALE
	return minf(size.x, size.y) * 0.88 * big * (RETAINER_BIG if enemy_id == "samurai_retainer" and _puppet else 1.0)


func has_rig() -> bool:
	return not _rig.is_empty()


## The two sticks of a hand's arm are drawn longer or shorter than they were cut: `reach` = (upper, lower) length in px of the art. HandymanStage
## sets it so that the hand lands where its name stands. (0, 0) = as cut.
var reach := Vector2.ZERO
var sad_forever := false  # the Handyman's body, once every hand is down: he keeps the crying face (Face.pdf)
var _sad_tex: Texture2D
var _fall_tex: Texture2D  # a flyer that has been knocked down
var head_gone := false  # the Horseman has thrown his head (set by the fight screen the moment it flies)
var _thrown_tex: Texture2D  # the Headless Horseman with his head thrown
const SAMURAI_POSES := ["in_no_kamae", "ko_gasumi", "sha_no_kamae"]
const SAMURAI_H := 1.725  # the Samurai's height (helmet to feet, idle), in art squares
const BUG_H := 0.92  # the Bug Hunter's height (loop to feet), in art squares
const RETAINER_BIG := 1.4  # his pictures are a square with a small man in it: drawn this much bigger than the other puppets' squares
const RETAINER_CANVAS := 1500  # (the finished pictures of the Retainer are this many layout px wide)
const RETAINER_POSES := ["gong", "gong2", "yield"]  # (finished pictures; the rest is RetainerRig)
var _ret_pose := ""  # the Retainer acting a move out: the picture shown (empty: the one of his intent)


## The Retainer acts his move out: the bottle held out, the fan waved, the gong struck (a script of [picture, seconds]). Returns how long it takes.
func retainer_play(kind: String) -> float:
	if _ret != null and kind == "bottle":
		_ret.play_throw()
		return RetainerRig.throw_time() + RetainerRig.BACK_TIME
	if _ret != null and kind == "mend":
		return _ret.play_fan()
	var script: Array = {"empower": [["gong", 0.45], ["gong2", 0.55]]}.get(kind, [])
	var total := 0.0
	for s in script:
		total += float(s[1])
	_run_ret_script(script)
	return total


func _run_ret_script(script: Array) -> void:
	for s in script:
		_ret_pose = s[0]
		await get_tree().create_timer(float(s[1])).timeout
		if not is_instance_valid(self):
			return
	_ret_pose = ""


## The picture the Retainer shows now: the one he is acting out, else the one of his intent.
func _ret_key() -> String:
	return _ret_pose if _ret_pose != "" else _pose()


## The bottle in his hand, for FightScreen to throw: [its place on the screen, its width there].
func retainer_bottle() -> Array:
	if _ret == null:
		return [global_position + size * 0.5, 60.0]
	return [get_global_transform() * _ret.bottle_center, _ret.bottle_px * get_global_transform().get_scale().x]


## The Retainer kneels: "I yield."
func retainer_yield() -> void:
	_ret_pose = "yield"


## The Samurai swings: returns the seconds until the blow lands (see SamuraiRig.strike).
func samurai_strike(hit_i: int, hits: int) -> float:
	return _samurai.strike(hit_i, hits) if _samurai != null else 0.0


## The Bug Hunter's striker: plays the strike (1 blow, or 3 for the alarm); returns the seconds until each blow lands ([] when it has no pieces).
func bug_strike(blows: int) -> Array:
	return _bug.strike(blows) if _bug != null else []


func has_bug() -> bool:
	return _bug != null


func has_samurai() -> bool:
	return _samurai != null
var _pose_tex := {}  # the Samurai: stance -> picture; he stands in the stance of the move he is about to make


## The stance of the move this enemy is about to make ("" when it has none).
func _pose() -> String:
	return String(_enemy.intent.get("pose", "")) if _enemy != null else ""
var _sad_t := 0.0  # seconds of crying left (a hand of his was hurt)
var calm := false  # a folded arm that was never hurt (a hand not summoned yet): it lies still, no creaking
var reach_angle := INF  # the lower stick's direction when it is not the rest one (INF: the rest one)
var reach_upper := INF  # the upper stick's direction when it is not the rest one (INF: the rest one)


## The hand marker, from the shoulder, in px of the art, with the sticks at `r` (upper, lower) length.
static func arm_hand(arm: Dictionary, r: Vector2, th2: float) -> Vector2:
	return Vector2.from_angle(arm.theta1) * r.x + Vector2.from_angle(th2) * r.y


## Draw one stick of an arm (its picture lies along +x, the joint it turns about at `pivot`): the stretch `slab` is made `extra` px longer.
## `ci`: the item to draw on (this Control, or the tip layer).
func _draw_stick(tex: Texture2D, pivot: Vector2, slab: Vector2, extra: float, mod: Color, ci: CanvasItem = null) -> void:
	if ci == null:
		ci = self
	var h := float(tex.get_height())
	var w := float(tex.get_width())
	extra = maxf(extra, -(slab.y - slab.x) * 0.9)
	ci.draw_texture_rect_region(tex, Rect2(-pivot.x, -pivot.y, slab.x + 1.0, h), Rect2(0.0, 0.0, slab.x + 1.0, h), mod)
	ci.draw_texture_rect_region(tex, Rect2(slab.y - pivot.x + extra - 1.0, -pivot.y, w - slab.y + 1.0, h), Rect2(slab.y - 1.0, 0.0, w - slab.y + 1.0, h), mod)
	ci.draw_texture_rect_region(tex, Rect2(slab.x - pivot.x - 0.5, -pivot.y, slab.y - slab.x + extra + 1.0, h), Rect2(slab.x, 0.0, slab.y - slab.x, h), mod)


## The tweezer hand reaches over the HUD: only its lower stick (elbow, hand and tweezers) is drawn on a layer of its own, high up (`tip_z`); the upper stick, the
## part that hangs on the Handyman's shoulder, stays where it was in the draw order, so it does not climb over his body.
var tip_z := 0  # 0 = off; else the z_index of the tip layer while the arm reaches
var _tip_layer: TipLayer
var _tip_args := {}


class TipLayer extends Control:
	var owner_arm: Creature
	var args := {}

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		z_as_relative = false
		set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	func _draw() -> void:
		if owner_arm == null or args.is_empty():
			return
		draw_set_transform_matrix(args.m)
		owner_arm._draw_stick(args.tex, args.pivot, args.slab, args.extra, args.mod, self)
		draw_set_transform_matrix(Transform2D.IDENTITY)


func _sync_tip_layer(on: bool) -> void:
	if on:
		if _tip_layer == null:
			_tip_layer = TipLayer.new()
			_tip_layer.owner_arm = self
			add_child(_tip_layer)
		_tip_layer.z_index = tip_z
		_tip_layer.args = _tip_args
		_tip_layer.queue_redraw()
	elif _tip_layer != null:
		_tip_layer.queue_free()
		_tip_layer = null


## The pose of a knocked-out arm at `f` (0 = as it hangs, 1 = away): {u: upper direction, l: lower direction, len: stick lengths, px of the art}.
## First half: the arm is lifted and pulled in behind the Handyman's back (written for a LEFT arm, angles clockwise from +x with y down; a right arm
## is its mirror image): the upper stick points inward, the lower one is doubled back along it. Second half: it goes to the pose drawn on page 4 of
## Handyman.pdf for that arm (rig: fold1 / fold2, the sticks at their cut length), turning the way that does not sweep past the ground.
const LIE_U := deg_to_rad(188.0)  # a LEFT arm lying on the floor: the shoulder end down, the upper stick going out and a little up to the elbow...
const LIE_L := deg_to_rad(168.0)  # ...and the lower stick coming down again to the hand (a right arm is the mirror image)
var floor_dy := 40.0  # px from the hand marker down to the floor (set by HandymanStage: the line his feet stand on)
const LIE_THICK := 16.0  # the stick's own half-thickness: it lies ON the floor
const LIE_SQUEEZE := 0.85  # a lying arm is a little shorter than a hanging one (a tidier heap)
const LIE_DEPTH := 10.0  # px of floor between the arms of one side (outermost at the back)
const FOLD_TUCK_UPPER := deg_to_rad(345.0)
const FOLD_TUCK_LOWER := deg_to_rad(165.0)


## The signed turn from `from` to `to` that does not go through "pointing down".
static func _sweep(from: float, to: float) -> float:
	var d := angle_difference(from, to)
	for way in 2:
		var ok := true
		for i in 9:
			if absf(angle_difference(from + d * i / 8.0, PI / 2.0)) < 0.5:
				ok = false
		if ok:
			return d
		d -= signf(d) * TAU
	return angle_difference(from, to)


func _fold_pose(f: float, th1: float, th2: float, sd: float, rest: Vector2) -> Dictionary:
	var mirror := sd > 0.0
	var p1 := fposmod(PI - th1 if mirror else th1, TAU)
	var p2 := fposmod(PI - th2 if mirror else th2, TAU)
	var tuck_len := rest * 0.55
	if f < 0.5:
		var s0 := smoothstep(0.0, 1.0, f / 0.5)
		var u := lerpf(p1, FOLD_TUCK_UPPER, s0)
		var l := lerpf(p2, FOLD_TUCK_LOWER, s0)
		return {"u": PI - u if mirror else u, "l": PI - l if mirror else l, "len": rest.lerp(tuck_len, s0)}
	var s := smoothstep(0.0, 1.0, (f - 0.5) / 0.5)
	var tu: float = PI - FOLD_TUCK_UPPER if mirror else FOLD_TUCK_UPPER
	var tl: float = PI - FOLD_TUCK_LOWER if mirror else FOLD_TUCK_LOWER
	var fu: float = _rig.fold1
	var fl: float = _rig.fold2
	return {"u": tu + _sweep(tu, fu) * s, "l": tl + _sweep(tl, fl) * s, "len": tuck_len.lerp(Vector2(_rig.l1, _rig.l2), s)}


## A Handyman hand: the upper arm turns about the shoulder, the lower arm (elbow, hand, tool) about the elbow, riding on the upper one. All the
## motion is angles, taken DOWN for a left arm with a negative turn and for a right arm with a positive one (`sd` carries that sign).
func _draw_arm(blink_on: bool) -> void:
	var sc: float = HandymanRig.SCALE
	var sd: float = _rig.side
	var h := 0.0 if dead else minf(hurt / 0.4, 1.0)  # (a hit throws it back up)
	# knocked out: see _fold_pose. The broken gears: while the arm is stuck it trembles a little, and a folded arm creaks
	var folding := _enemy != null and _enemy.knocked and not _enemy.fallen
	var th2: float = _rig.theta2 if is_inf(reach_angle) else reach_angle
	var a1 := sin(bob * 0.45 + _rig_phase) * 0.045  # idle: it hangs and drifts a little
	var a2 := sin(bob * 0.62 + _rig_phase * 1.7) * 0.075
	a1 += sd * (swing * 0.14 - h * 0.15 - intro * 1.1)
	a2 += sd * (swing * 0.26 - h * 0.25 - intro * 0.6)
	var up0: float = _rig.theta1 if is_inf(reach_upper) else reach_upper
	if not is_inf(reach_upper):  # (the upper stick points elsewhere than at rest: the lower one keeps its own direction)
		var b := angle_difference(float(_rig.theta1), reach_upper)
		a1 += b
		a2 -= b
	if aim > 0.0 and _enemy != null and AIM_BOW.has(_enemy.id) and not is_inf(aim_dir):  # (the lower arm turns the weapon toward aim_dir)
		a2 += aim * angle_difference(a1 + a2 + th2, aim_dir - float(AIM_BOW[_enemy.id]))
	var rest := reach if reach != Vector2.ZERO else Vector2(_rig.l1, _rig.l2)
	var r := rest
	var poked := poke > 0.0 and _enemy != null and POKE_TIP.has(_enemy.id)
	if _fold_t > 0.0:
		var pose := _fold_pose(_fold_t, float(_rig.theta1), th2, sd, rest)
		var fold1 := angle_difference(float(_rig.theta1), pose.u)
		a1 = a1 * (1.0 - _fold_t) + fold1
		a2 = a2 * (1.0 - _fold_t) + angle_difference(th2 + fold1, pose.l)
		r = pose.len  # (the sticks pull in as it folds)
		if folding:
			if not calm:  # (a hurt arm: its broken gears tremble while it is stuck)
				var stuck := 1.0 - _drive
				a1 += sin(_gear_t * 47.0) * 0.012 * stuck
				a2 += sin(_gear_t * 41.0 + 1.0) * 0.02 * stuck
			# a folded arm always drifts a little, slowly (a calm one, never hurt, only this: no trembling)
			a1 += sin(_gear_t * 0.9 + _rig_phase) * 0.012 * _fold_t
			a2 += sin(_gear_t * 1.3) * 0.03 * _fold_t
	if poked:  # (reaching for a point of the screen: both sticks turn and stretch to put the tip of its tool there)
		var pk := _poke_pose(size / 2.0 - (Vector2.from_angle(up0) * rest.x + Vector2.from_angle(th2) * rest.y) * sc, rest, th2, sc)
		a1 += angle_difference(a1, pk.a1) * poke
		a2 += angle_difference(a2, pk.a2) * poke
		r = r.lerp(pk.r, poke)
	# a stick cannot be shorter than its stretch allows: the elbow pin of the upper stick and the lower stick's must stay on one another
	var slab_u: Vector2 = _rig.upper_slab
	var slab_l: Vector2 = _rig.lower_slab
	r = Vector2(maxf(r.x, float(_rig.l1) - 0.9 * (slab_u.y - slab_u.x)), maxf(r.y, float(_rig.l2) - 0.9 * (slab_l.y - slab_l.x)))
	var origin := size / 2.0 - (Vector2.from_angle(up0) * rest.x + Vector2.from_angle(th2) * rest.y) * sc  # (the shoulder: the middle of the box is the hand marker at rest)
	if _drop_t > 0.0:  # knocked off: it comes away from the shoulder, falls and lies on the floor (and goes back the same way when he pulls it up)
		var u_t: float = PI - LIE_U if sd > 0.0 else LIE_U
		var l_t: float = PI - LIE_L if sd > 0.0 else LIE_L
		var rl := Vector2(maxf(float(_rig.l1) * LIE_SQUEEZE, float(_rig.l1) - 0.9 * (slab_u.y - slab_u.x)), maxf(float(_rig.l2) * LIE_SQUEEZE, float(_rig.l2) - 0.9 * (slab_l.y - slab_l.x)))
		var e_pt := Vector2.from_angle(u_t) * rl.x * sc
		var h_pt := e_pt + Vector2.from_angle(l_t) * rl.y * sc
		var depth := (int(_rig.layer) - 1) * LIE_DEPTH  # (the arms of one side lie a little behind one another)
		var lie := Vector2(size.x / 2.0 - h_pt.x / 2.0, size.y / 2.0 + floor_dy + depth - LIE_THICK - maxf(maxf(e_pt.y, h_pt.y), 0.0))
		var k := _drop_t * _drop_t
		var a1_t := angle_difference(float(_rig.theta1), u_t)
		a1 = lerpf(a1, a1_t, k)
		a2 = lerpf(a2, angle_difference(th2 + a1_t, l_t), k)
		r = r.lerp(rl, k)
		origin = origin.lerp(lie, k)
		if _drop_t >= 1.0:  # (the bounce as it lands)
			origin.y -= absf(sin(_land * 16.0)) * 14.0 * exp(-_land * 6.0)
	if lunge != Vector2.ZERO:  # (a thrust: the shoulder stays on the body and the lower arm keeps pointing where it aims; the hand goes `lunge` farther, so the upper stick stretches to put the elbow where the hand needs it)
		var low := a1 + a2 + th2  # (the lower arm's direction on the screen)
		var elb0 := origin + Vector2.from_angle(float(_rig.theta1) + a1) * r.x * sc
		var hand_t := elb0 + Vector2.from_angle(low) * r.y * sc + lunge
		var v := hand_t - Vector2.from_angle(low) * r.y * sc - origin
		a1 = v.angle() - float(_rig.theta1)
		a2 = low - a1 - th2
		r.x = maxf(v.length() / sc, float(_rig.l1) - 0.9 * (slab_u.y - slab_u.x))
	var elbow := Vector2.from_angle(_rig.theta1) * r.x
	if _shake > 0.0:
		origin += Vector2(randf_range(-_shake, _shake), randf_range(-_shake, _shake) * 0.5)
	var mod := Color.WHITE
	if dead:
		mod = Color(0.05, 0.05, 0.05, 0.4)
	elif blink_on or flash > 0.0:
		var b := 1.0 + 0.9 * maxf(flash, 1.0 if blink_on else 0.0)
		mod = Color(b, b, b)
	mod.a *= 1.0 - 0.6 * intro
	var m1 := Transform2D(a1, origin) * Transform2D(Vector2(sc, 0.0), Vector2(0.0, sc), Vector2.ZERO)
	var m2 := m1 * Transform2D(a2, elbow)
	draw_set_transform_matrix(m1 * Transform2D(_rig.theta1, Vector2.ZERO))
	_draw_stick(_rig_tex[0], _rig.upper_pivot, _rig.upper_slab, r.x - float(_rig.l1), mod)
	if tip_z != 0 and (poked or aim > 0.0):  # (the lower stick goes to the tip layer, over the HUD)
		_tip_args = {"m": m2 * Transform2D(th2, Vector2.ZERO), "tex": _rig_tex[1], "pivot": _rig.lower_pivot, "slab": _rig.lower_slab, "extra": r.y - float(_rig.l2), "mod": mod}
		_sync_tip_layer(true)
	else:
		_sync_tip_layer(false)
		draw_set_transform_matrix(m2 * Transform2D(th2, Vector2.ZERO))
		_draw_stick(_rig_tex[1], _rig.lower_pivot, _rig.lower_slab, r.y - float(_rig.l2), mod)
	draw_set_transform_matrix(Transform2D.IDENTITY)
	_hand_pt = (m2 * Transform2D(th2, Vector2.ZERO)) * Vector2(r.y, 0.0)  # (the hand marker: l2 along the lower stick from the elbow pin)
	if _enemy != null and POKE_TIP.has(_enemy.id):
		var tt: Vector2 = POKE_TIP[_enemy.id]
		var piv: Vector2 = _rig.lower_pivot
		_arm_tip = (m2 * Transform2D(th2, Vector2.ZERO)) * Vector2(tt.x - piv.x + (r.y - float(_rig.l2)), tt.y - piv.y)


var _hand_pt := Vector2.ZERO  # where the hand marker was drawn last, in this Control's own coordinates


## Where the arm's hand marker is on the screen (it moves when the lower arm turns).
func hand_global() -> Vector2:
	return get_global_transform() * _hand_pt


## Where the tip of the arm's tool is on the screen.
func tool_tip() -> Vector2:
	return get_global_transform() * _arm_tip


## The pose that puts the tip of the tool on `poke_target`: the hand has to be where the tip would leave it (the tool sticks out of the hand at a fixed
## angle to the lower stick), and the upper stick turns most of the way toward it, so the arm bends a little at the elbow. Returns the turn of the
## upper stick (a1) and of the lower one (a2) from their rest, and the two lengths (px of the art). `s`: the shoulder, in this Control's coordinates.
func _poke_pose(s: Vector2, rest: Vector2, th2: float, sc: float) -> Dictionary:
	var tt: Vector2 = POKE_TIP[_enemy.id]
	var piv: Vector2 = _rig.lower_pivot
	var off := Vector2(tt.x - (piv.x + float(_rig.l2)), tt.y - piv.y) * sc  # (tip relative to the hand marker, with the lower stick along +x)
	var t := get_global_transform().affine_inverse() * poke_target
	var th := (t - s).angle()
	var u := float(_rig.theta1)
	var h := t
	var e := s
	var l1 := rest.x * sc
	for k in 6:
		h = t - off.rotated(th)
		var d := h - s
		u = lerp_angle(float(_rig.theta1), d.angle(), 0.7)
		l1 = maxf(d.length() * 0.5, rest.x * sc)
		e = s + Vector2.from_angle(u) * l1
		th = (h - e).angle()
	var a1p := angle_difference(float(_rig.theta1), u)
	return {"a1": a1p, "a2": wrapf(th - a1p - th2, -PI, PI), "r": Vector2(l1 / sc, (h - e).length() / sc)}


## Drawn art instead of the procedural body: hurt for a moment after a hit, angry while it has at least half its
## Essence, the normal (worn-out) face below half. It bobs and jolts like the procedural ones and blinks bright when hit.
func _draw_art(blink_on: bool) -> void:
	var face := "angry"
	if _enemy != null:
		_max_hp = maxi(_max_hp, _enemy.size())
		if _enemy.size() * 2 < _max_hp:
			face = "normal"
	if hurt > 0.0 and not dead:
		face = "hurt"
	if ART_FORMS.has(enemy_id):
		# form 1 in its starting colour, form 2 once it has flipped to the other one
		var start: String = _enemy.def.get("yin", "white") if _enemy != null else "white"
		face += "_1" if _enemy == null or _enemy.yin == "" or _enemy.yin == start else "_2"
	var tex: Texture2D = _art.get(face, _art.values()[0])
	if _puppet and _enemy != null and _enemy.yin != "" and _art.has("yin_" + _enemy.yin):
		tex = _art["yin_" + _enemy.yin]
	if _pose_tex.has(_pose()):
		tex = _pose_tex[_pose()]
	if _ret_pose != "" and _pose_tex.has(_ret_pose):
		tex = _pose_tex[_ret_pose]  # (the Retainer acting a move out)
	if _sad_tex != null and (sad_forever or _sad_t > 0.0):
		tex = _sad_tex
	if _fall_tex != null and _enemy != null and not _enemy.flying:
		tex = _fall_tex
	if _thrown_tex != null and _enemy != null and (head_gone or (_enemy.has_meta("headless") and not _enemy.intent.get("head", false))):
		tex = _thrown_tex  # (the head is announced as his next move and thrown with it: after that his hand is empty)
	var veil2: bool = enemy_id == "veiled_eyes" and _veil_tex.size() == 2 and _veil_tex[0] != null and _enemy != null and _enemy.phase >= 2
	if veil2:
		tex = _veil_tex[0]
	if enemy_id == "veiled_eyes" and _puppet:
		if not veil2:
			_saw_veil1 = true
		elif _saw_veil1 and _unveil_t < 0.0 and _unveil_tex.size() == 4 and not _unveil_tex.has(null):
			_unveil_t = 0.0  # (it was phase 1 on this screen and now it is phase 2: the veil breaks and the spider comes out)
	var is_unveiling: bool = veil2 and _unveil_t >= 0.0
	var side := _art_side()
	var c := Vector2(size.x / 2.0, size.y - side * 0.5 + sin(bob) * 4.0)
	if _shake > 0.0:
		c += Vector2(randf_range(-_shake, _shake), randf_range(-_shake, _shake) * 0.5)
	_art_shake_x = c.x - size.x / 2.0
	# a flyer drifts in the air: a slow sway left and right, a quicker bob up and down (its shadow stays on the ground)
	var fly := Vector2.ZERO
	if ground_drop > 0.5 and not dead:
		var ft := Time.get_ticks_msec() / 1000.0 + float(hash(enemy_id) % 97) * 0.13
		fly = Vector2(sin(ft * 1.1) * 8.0, sin(ft * 2.3) * 10.0)
	if _puppet:  # a puppet doesn't bob: it hangs on its rope and swings from the top of it (see _process), and a hit knocks it back
		var tip := 0.0 if dead or enemy_id == "handyman" else _swing_a  # (the Handyman's body does not swing: six arms hang on it)
		if _dragon != null:
			tip = 0.0  # (the Wyvern's two halves share ONE body: each rocking on its own would tear it apart, and it is far too wide to tip)
		# (a pendulum: the rope hangs from the ceiling straight above where it is tied on and swings a little, and the puppet, the
		# weight at its end, swings with it; everything else is still measured from its feet)
		var tie := _rope_local(_pivot_frac(), side)
		var org := Vector2(c.x, size.y) + fly
		var hook := Vector2(org.x + tie.x, (get_global_transform().affine_inverse() * Vector2(0.0, RopeRig.TOP_Y)).y)
		tip *= ROPE_SWING
		_art_tip = tip
		_art_xf = Transform2D(tip, hook) * Transform2D(0.0, org - hook)  # (the rope's anchor rides along with a flyer's drift)
		draw_set_transform_matrix(_art_xf)
		# the shadow lies on the floor under the feet and follows the swing: the feet and the head are where the puppet's own transform puts them
		if not dead and steal_pose <= 0.0 and _dragon == null:  # (carrying a card it hangs in the air: no shadow over the card)
			var shadow_side := side * (1.0 - 0.15 * clampf(ground_drop / 80.0, 0.0, 1.0))  # (a flyer's shadow: on the floor below it, a little smaller)
			var feet_x := (_art_xf * Vector2.ZERO).x - fly.x * 0.5  # (a flyer's shadow follows only half its drift)
			var head_dx := (_art_xf * Vector2(0.0, -side)).x - (_art_xf * Vector2.ZERO).x  # (how far the swing carries the head sideways of the feet)
			_shadow_node().place(_unveil_tex[0] if is_unveiling and _unveil_t < UNVEIL_LEGS[0] else tex, Vector2(feet_x, size.y + ground_drop), side * 0.5 + head_dx * 0.9, shadow_side)  # (the spider's shadow only once its legs are out)
		elif _shadow != null:
			_shadow.visible = false
		c = Vector2(0, -side * 0.5)
		if veil2:
			c.y -= side * VEIL2_LIFT  # (the spider hangs higher: its purple eyes stay level with the eyes under the veil)
	var mod := Color.WHITE
	if dead:
		mod = Color(0.05, 0.05, 0.05, 0.4)  # an unknown silhouette (codex), like the procedural grey
	elif blink_on or flash > 0.0:
		var b := 1.0 + 0.9 * maxf(flash, 1.0 if blink_on else 0.0)
		mod = Color(b, b, b)
	if is_unveiling and _puppet and not dead:
		_draw_unveil(tex, c, side, mod)
	elif veil2 and steal_pose > 0.0 and _puppet and not dead and _unveil_tex.size() == 4 and not _unveil_tex.has(null):
		_draw_steal_pose(Rect2(c - Vector2(side, side) * 0.5, Vector2(side, side)), side, mod)
	elif enemy_id == "veiled_eyes" and _puppet and not dead and not veil2:
		_draw_curtain(tex, Rect2(c - Vector2(side, side) * 0.5, Vector2(side, side)), mod)  # (the veil of phase 1 sways like a curtain)
	elif _ret != null and _puppet and not (_ret_key() in RETAINER_POSES):
		var rk := side / float(RETAINER_CANVAS)  # (his pieces on the same ground line and body place as the finished pictures' square)
		_ret.draw(self, _art_xf * Transform2D(0.0, Vector2.ONE, 0.0, Vector2(10.0 * rk, -40.0 * rk)), rk, mod)
	elif _bug != null and _puppet:
		_bug.draw(self, _art_xf, side * BUG_H / _bug.height_px(), mod)  # (feet on the same line as the single picture's)
	elif _samurai != null and _puppet:
		_samurai.draw(self, _art_xf, side * SAMURAI_H / _samurai.height_px(), mod)  # (his pieces, feet on the same line as the single picture's)
	elif _dragon != null and _puppet:
		_dragon.draw_part(self, _art_xf, mod, _enemy.def.rig_part)  # (its part of the pieces, feet on the same line as the single picture's)
	else:
		draw_texture_rect(tex, Rect2(c - Vector2(side, side) * 0.5, Vector2(side, side)), false, mod)
	if enemy_id == "corrector" and _puppet and not dead:
		_draw_corrector(c, side, mod)
	if enemy_id == "veiled_eyes" and _puppet and not dead and not is_unveiling:
		_draw_veiled_eyes_art(c, side, mod, veil2)
	if _puppet and not dead:
		for fl in _floaters:  # (they hover: a slow drift up and down and a little sideways, each on its own beat)
			var ft: Texture2D = fl[0]
			var k := side / float(tex.get_width())
			var ph: float = fl[2]
			var at: Vector2 = c + (fl[1] - Vector2(0.5, 0.5)) * side + Vector2(sin(bob * 0.7 + ph) * side * 0.006, sin(bob * 1.1 + ph) * side * 0.014)
			draw_texture_rect(ft, Rect2(at - ft.get_size() * k * 0.5, ft.get_size() * k), false, mod)
	if _puppet:
		draw_set_transform(Vector2.ZERO)


## The Winter Wyvern acts its move out (the lunge, the slam, the roar): see DragonRig.play.
func dragon_fx() -> void:
	if _dragon != null:
		_dragon.play(_enemy)


## The Winter Wyvern's hovering Fireball, for FightScreen to fly into your HP bar: its place on the screen, its width there, its pictures; hide it when it leaves.
func dragon_ball_point() -> Vector2:
	return get_global_transform() * _dragon.ball_point() if _dragon != null else global_position


func dragon_ball_width() -> float:
	return _dragon.ball_width() * get_global_transform().get_scale().x if _dragon != null else 0.0


func dragon_fx_tex(p_name: String) -> Texture2D:
	return _dragon.fx_tex.get(p_name) if _dragon != null else null


func dragon_hide_ball() -> void:
	if _dragon != null:
		_dragon.hide_ball()


## Seconds from the start of the Winter Wyvern's attack until the blow lands (0: not the dragon).
func dragon_hit_time() -> float:
	return _dragon.hit_time(_enemy) if _dragon != null and _enemy != null else 0.0


## Puppet Stage: the shadow the spotlight throws on the floor: its own silhouette lying flat BEHIND the puppet (PuppetShadow: a soft, blurred child drawn behind it),
## dark at the feet, fading towards the head, leaning right and carried sideways by the puppet's swing.
var _shadow: PuppetShadow  # the soft shadow on the floor (a child that draws behind this Control)


func _shadow_node() -> PuppetShadow:
	if _shadow == null:
		_shadow = PuppetShadow.new()
		add_child(_shadow)
		move_child(_shadow, 0)
	return _shadow


## Puppet Stage: the whole square the picture is drawn in, on the screen, and the picture itself (for the pieces it breaks into).
func puppet_art_rect() -> Rect2:
	var side := _art_side()
	return Rect2(global_position + Vector2(size.x / 2.0 - side / 2.0, size.y - side - _veil_lift(side)), Vector2(side, side))


## How far up (px) the Veiled Eyes' second phase hangs, so that its eyes are where the eyes of phase 1 were (VEIL2_LIFT).
func _veil_lift(side: float) -> float:
	return side * VEIL2_LIFT if enemy_id == "veiled_eyes" and _puppet and _enemy != null and _enemy.phase >= 2 else 0.0


## Where the Veiled Eyes' eyes are on the screen (the laser starts there): the same height in both phases.
func veil_eyes_point() -> Vector2:
	var side := _art_side()
	return global_position + Vector2(size.x / 2.0, size.y - side + side * VEIL1_EYES[0][0].y)


func puppet_tex() -> Texture2D:
	if not _puppet or _art.is_empty():
		return null
	if _enemy != null and _enemy.yin != "" and _art.has("yin_" + _enemy.yin):
		return _art["yin_" + _enemy.yin]
	if enemy_id == "veiled_eyes" and _veil_tex.size() == 2 and _veil_tex[0] != null and _enemy != null and _enemy.phase >= 2:
		return _veil_tex[0]  # (the spider of phase 2)
	return _art.values()[0]


## ---- Rope mode (RopeEditor): points on the puppet's picture, given as fractions of its square (0..1 from the top left) --------------------------
## Only a plain Puppet Stage cut-out takes ropes (a Handyman hand is a rig and a dead puppet is a silhouette).
func rope_ok() -> bool:
	return _puppet and _rig.is_empty() and not dead and not _art.is_empty()


## Where a point of the picture is on the screen. `rest`: where it is while the puppet stands still (no rocking, no jolt): the top of its rope hangs over that.
func rope_point(frac: Vector2, rest := false) -> Vector2:
	var side := _art_side()
	var local := _rope_local(frac, side)
	if rest:
		return get_global_transform() * (Vector2(size.x / 2.0, size.y) + local)
	return get_global_transform() * (_art_xf * local)  # (the picture as it is drawn now: swinging about its rope's tie)


## A point of the picture (a fraction of its square), measured from its feet.
func _rope_local(frac: Vector2, side: float) -> Vector2:
	return Vector2(0.0, -side * 0.5 - _veil_lift(side)) + (frac - Vector2(0.5, 0.5)) * side


## Where its rope is tied on (the middle of them when it has more than one; the top of the picture when it has none yet): the
## point it hangs and swings from.
func _pivot_frac() -> Vector2:
	var pts: Array = EnemyRopes.points(enemy_id)
	if pts.is_empty():
		return Vector2(0.5, 0.0)
	var sum := Vector2.ZERO
	for p in pts:
		sum += Vector2(p[0], p[1]) if p is Array else (p as Vector2)
	return sum / float(pts.size())


## The point of the picture under a screen point (the inverse of rope_point; outside the square when the point is off the picture).
func rope_frac_at(g: Vector2) -> Vector2:
	var side := _art_side()
	var l := get_global_transform().affine_inverse() * g
	l = _art_xf.affine_inverse() * l
	return (l - Vector2(0.0, -side * 0.5)) / side + Vector2(0.5, 0.5)


static var _alpha_cache := {}  # texture path -> a small copy of its picture (only the opaque parts matter)


## How opaque the picture is at a point of it (0 outside the square or on a see-through part).
func rope_alpha(frac: Vector2) -> float:
	var tex := puppet_tex()
	if tex == null or frac.x < 0.0 or frac.y < 0.0 or frac.x >= 1.0 or frac.y >= 1.0:
		return 0.0
	var key := tex.resource_path
	if not _alpha_cache.has(key):
		var im := tex.get_image()
		if im.is_compressed():
			im.decompress()
		im.resize(128, 128, Image.INTERPOLATE_BILINEAR)
		_alpha_cache[key] = im
	var img: Image = _alpha_cache[key]
	return img.get_pixel(int(frac.x * img.get_width()), int(frac.y * img.get_height())).a


static var _bounds_cache := {}  # texture path -> Rect2 (the painted part of the picture, as fractions of its square)


## Puppet Stage: where the painted part of the puppet is, in this control's own coordinates (the picture is a square, its feet at the
## bottom edge: see _draw_art). Empty when it is not drawn as a puppet.
func puppet_bounds() -> Rect2:
	if not _rig.is_empty():  # (a hand: a small box on the hand marker of the art, the name stands right over it and the Essence right under it;)
		return Rect2(size / 2.0 + Vector2(0.0, 50.0) - Vector2(60.0, 6.0), Vector2(120.0, 12.0))  # (50 px lower than the hand: over the spell cards)
	if not _puppet or _art.is_empty():
		return Rect2()
	var tex: Texture2D = _art.values()[0]
	var key := tex.resource_path
	if not _bounds_cache.has(key):
		var img := tex.get_image()
		if img.is_compressed():
			img.decompress()
		var used := img.get_used_rect()
		_bounds_cache[key] = Rect2(Vector2(used.position) / Vector2(img.get_size()), Vector2(used.size) / Vector2(img.get_size()))
	var f: Rect2 = _bounds_cache[key]
	var side := _art_side()
	var origin := Vector2(size.x / 2.0 - side / 2.0, size.y - side)
	var r := Rect2(origin + f.position * side, f.size * side)
	if _enemy != null and _enemy.yin != "":  # (the Yin Yang Beast carries its symbol over its head: it counts as its head)
		var sym_top := size.y * 0.58 - minf(size.x, size.y) * 0.34 * big * 1.37 - 2.0
		if sym_top < r.position.y:
			r = Rect2(r.position.x, sym_top, r.size.x, r.end.y - sym_top)
	return r


# ------------------------------------------------------------------ the Veiled Eyes (drawn until it has art)

const VIOLET := Color(0.66, 0.32, 1.0)
const SILK := Color(0.95, 0.94, 0.9)
var _veil_drop := 0.0  # 0: the veil is on; 1: it has fallen away (it slides off when phase 2 starts)
var _hypno := 0.0  # seconds left of the human eyes' bright hypnotizing glow (the fight's opening)
var _look := Vector2.ZERO  # where the human eyes look, -1..1 (phase 2: they glance around)
var _look_to := Vector2.ZERO
var _look_t := 0.0


## The fight's opening: the human eyes shine brightly for a moment.
func hypnotize(sec := 2.2) -> void:
	_hypno = sec


func _spider_tick(d: float) -> void:
	if enemy_id != "veiled_eyes" or _enemy == null:
		return
	if _unveil_t >= 0.0:
		_unveil_t += d
		if _unveil_t >= UNVEIL_DUR:
			_unveil_t = -1.0
			_saw_veil1 = false
	if _enemy.phase >= 2:
		_veil_drop = move_toward(_veil_drop, 1.0, d * 0.7)
	_hypno = maxf(0.0, _hypno - d)
	_look_t -= d
	if _look_t <= 0.0:
		_look_t = randf_range(0.9, 2.2)  # (every so often they glance somewhere else)
		_look_to = Vector2(randf_range(-1, 1), randf_range(-0.7, 0.7))
	_look = _look.lerp(_look_to, minf(1.0, d * 6.0))
	queue_redraw()


## What its eyes say: phase 1 "both" / "left" / "right"; phase 2 how many dots (0..4) are lit.
func _eyes_cue() -> Variant:
	if _enemy == null or _enemy.intent.is_empty():
		return null
	return _enemy.intent.get("eyes", null)


func _draw_veiled(c: Vector2, s: float, body: Color, blink_on: bool) -> void:
	var phase2 := _enemy != null and _enemy.phase >= 2
	var top := Vector2(c.x, 0.0)
	if not phase2:
		var ball := c + Vector2(0, -s * 0.05)
		var r := s * 0.95
		draw_line(top, ball + Vector2(0, -r), SILK, 2.0, true)
		draw_circle(ball, r * 1.04, Color(0, 0, 0, 0.5))
		draw_circle(ball, r, body)
		draw_circle(ball + Vector2(-r * 0.35, -r * 0.4), r * 0.25, Color(1, 1, 1, 0.08))  # (a dull sheen)
		var eye_cue: Variant = _eyes_cue()
		var lit_l: bool = _hypno > 0.0 or eye_cue == "both" or eye_cue == "left"
		var lit_r: bool = _hypno > 0.0 or eye_cue == "both" or eye_cue == "right"
		for side in [-1, 1]:
			_human_eye(ball + Vector2(side * r * 0.4, -r * 0.12), r * 0.3, Vector2.ZERO, false, blink_on)
		_draw_veil(ball, r, 0.0)
		for side in [-1, 1]:  # a lit eye pierces right through the veil
			if lit_l if side < 0 else lit_r:
				_human_eye(ball + Vector2(side * r * 0.4, -r * 0.12), r * 0.3, Vector2.ZERO, true, blink_on)
		return
	# phase 2: the spider, hanging head-down on its thread
	var ab := c + Vector2(0, -s * 0.25)  # its back (the abdomen), where the human eyes are
	var head := c + Vector2(0, s * 0.55)
	draw_line(top, ab + Vector2(0, -s * 0.7), SILK, 2.0, true)
	var leg := Color(body.darkened(0.3), 1.0)
	for side in [-1, 1]:
		for k in 4:
			var root := c + Vector2(side * s * 0.35, -s * 0.15 + k * s * 0.24)
			var knee := root + Vector2(side * s * (0.7 + 0.08 * k), (-0.6 + k * 0.26) * s)
			var foot := knee + Vector2(side * s * 0.2, (0.45 + k * 0.05) * s)
			draw_polyline(PackedVector2Array([root, knee, foot]), Color(0, 0, 0, 0.6), s * 0.16, true)
			draw_polyline(PackedVector2Array([root, knee, foot]), leg, s * 0.11, true)
	draw_circle(ab, s * 0.72, Color(0, 0, 0, 0.5))
	draw_circle(ab, s * 0.68, body)
	draw_circle(head, s * 0.42, Color(0, 0, 0, 0.5))
	draw_circle(head, s * 0.38, body.lightened(0.05))
	for side in [-1, 1]:  # fangs
		draw_colored_polygon(PackedVector2Array([head + Vector2(side * s * 0.12, s * 0.28), head + Vector2(side * s * 0.2, s * 0.32),
			head + Vector2(side * s * 0.1, s * 0.58)]), SILK.darkened(0.2))
	# the human eyes on its back: they look around; before the laser they glow and stare straight at you
	var cue: Variant = _eyes_cue()
	var stare: bool = cue != null and typeof(cue) != TYPE_STRING and int(cue) == 0
	for side in [-1, 1]:
		var at := ab + Vector2(side * s * 0.3, -s * 0.12)
		_human_eye(at, s * 0.24, Vector2(0, 0.35) if stare else _look, stare or _hypno > 0.0, blink_on)
	# the 4 spider-eye dots on its head: as many light up as its count says
	var n_lit: int = int(cue) if cue != null and typeof(cue) != TYPE_STRING else 0
	var dots := [Vector2(-0.14, -0.12), Vector2(0.14, -0.12), Vector2(-0.16, 0.1), Vector2(0.16, 0.1)]
	for k in 4:
		var p: Vector2 = head + dots[k] * s
		if k < n_lit:
			draw_circle(p, s * 0.13, Color(VIOLET, 0.35))
			draw_circle(p, s * 0.075, Color(1.0, 0.55, 1.0))
			draw_circle(p, s * 0.035, Color(1, 1, 1))
		else:
			draw_circle(p, s * 0.06, Color(0.03, 0.02, 0.04))
			draw_circle(p + Vector2(-s * 0.015, -s * 0.015), s * 0.015, Color(1, 1, 1, 0.5))
	if _veil_drop < 1.0:
		_draw_veil(ab + Vector2(0, -s * 0.2), s * 0.95, _veil_drop)  # (falling away)


## The Veiled Eyes go from phase 1 to 2 (the user's storyboard, animation.pdf): the veil breaks and the bare face stays; the head of the spider peeks out from
## behind the ball (its fangs show under it), goes down and comes up in front of it; two sets of legs reach out from behind the ball; the finished phase 2 picture
## takes over. The pieces (tools/import_veiled_eyes.py) all lie on the canvas of the pictures at the place they have in phase 2.
const UNVEIL_DUR := 5.0
const UNVEIL_BREAK := [0.0, 1.0]  # the veil breaks (shakes and turns into the bare face) over 1 s
const UNVEIL_HEAD_DOWN := [3.0, 3.7]  # (the bare face stays alone for 2 s) the head slides down from behind the ball
const UNVEIL_HEAD_UP := [3.7, 4.2]  # and comes up in front of it
const UNVEIL_LEGS := [4.0, 4.8]  # the legs reach out (head and legs take 2 s together)
const UNVEIL_DONE := [4.8, 5.0]  # the finished picture fades in over the pieces
const VEIL2_LIFT := 0.336  # phase 2 hangs this much higher (fraction of the picture) than where its picture was cut: its eyes (0.461) land on the eyes of phase 1 (0.125)
const UNVEIL_HEAD_HIDDEN := Vector2(0.0, -0.15)  # the head's place behind the ball, from its place in phase 2 (in pictures): the fangs just show under the ball
const UNVEIL_HEAD_LOW := Vector2(0.0, 0.12)  # and below the ball
const UNVEIL_LEG_PIVOTS := [Vector2(0.37, 0.57), Vector2(0.63, 0.57)]  # where the legs join the body (left, right), as fractions of the picture


## The Veiled Eyes are coming out of their veil (phase 1 -> 2).
func unveiling() -> bool:
	return _unveil_t >= 0.0


func _unveil_span(span: Array) -> float:
	return clampf((_unveil_t - float(span[0])) / (float(span[1]) - float(span[0])), 0.0, 1.0)


func _draw_unveil(final: Texture2D, c: Vector2, side: float, mod: Color) -> void:
	var rect := Rect2(c - Vector2(side, side) * 0.5, Vector2(side, side))
	var brk := _unveil_span(UNVEIL_BREAK)
	var down := _unveil_span(UNVEIL_HEAD_DOWN)
	var up := _unveil_span(UNVEIL_HEAD_UP)
	var legs := _unveil_span(UNVEIL_LEGS)
	var done := _unveil_span(UNVEIL_DONE)
	var ease_io := func(x: float) -> float: return x * x * (3.0 - 2.0 * x)
	var back := func(x: float) -> float:  # (out, with a little overshoot)
		var t1 := x - 1.0
		return 1.0 + 2.2 * t1 * t1 * t1 + 1.2 * t1 * t1
	if brk > 0.0 and brk < 0.35:
		_shake = maxf(_shake, 6.0)
	# the legs, behind everything
	for k in 2:
		var pivot: Vector2 = c + (UNVEIL_LEG_PIVOTS[k] - Vector2(0.5, 0.5)) * side
		var e: float = back.call(legs)
		var sgn := -1.0 if k == 0 else 1.0
		var tuck := 1.0 - e
		var about := Transform2D(sgn * 0.8 * tuck, Vector2.ONE * (1.0 - 0.4 * tuck), 0.0, pivot) * Transform2D(0.0, -pivot)  # (folded in about the shoulder)
		var shift := Transform2D(0.0, Vector2(-sgn * 0.10, -0.05) * side * tuck)
		draw_set_transform_matrix(_art_xf * shift * about)
		draw_texture_rect(_unveil_tex[2 + k], rect, false, Color(mod, clampf(legs * 5.0, 0.0, 1.0)))
	draw_set_transform_matrix(_art_xf)
	var head_off := UNVEIL_HEAD_HIDDEN.lerp(UNVEIL_HEAD_LOW, ease_io.call(down)).lerp(Vector2.ZERO, ease_io.call(up)) * side
	var head_a := clampf(down * 8.0, 0.0, 1.0)  # (nothing of the head shows while the face stands alone)
	if up == 0.0:
		_draw_head(rect, head_off, Color(mod, head_a))  # (still behind the ball)
	# the ball: the picture with its veil turns into the bare face
	_draw_curtain(_art.values()[0], Rect2(rect.position + Vector2(0.0, side * VEIL2_LIFT), rect.size), Color(mod, 1.0 - brk))  # (the veil, where it stood in phase 1)
	draw_texture_rect(_unveil_tex[0], rect, false, Color(mod, brk))
	if up > 0.0:
		_draw_head(rect, head_off, Color(mod, head_a))  # (now in front of it)
	if done > 0.0:
		draw_texture_rect(final, rect, false, Color(mod, done))


## The veil of phase 1 hangs from its head and its folds sway like a curtain in a draught: the picture is drawn in a grid of small quads whose corners
## slide sideways, nothing at the top (where the eyes are) and more and more towards the hem, with a slow wave running down and a faster ripple across.
const CURTAIN_COLS := 10
const CURTAIN_ROWS := 36
const CURTAIN_SWAY := 0.022  # (the wide slow swing at the hem, as a fraction of the picture)
const CURTAIN_RIPPLE := 0.011  # (the ripple across the folds)


func _curtain_dx(u: float, v: float) -> float:
	var w := pow(clampf((v - 0.05) / 0.9, 0.0, 1.0), 1.7)
	var ph := bob * 0.45
	return w * (CURTAIN_SWAY * sin(ph * 0.8 + v * 2.6) + CURTAIN_RIPPLE * sin(ph * 1.9 - v * 6.0 + u * 5.0))


func _draw_curtain(tex: Texture2D, rect: Rect2, mod: Color) -> void:
	var cols := PackedColorArray([mod, mod, mod, mod])
	for j in CURTAIN_ROWS:
		var v0 := float(j) / CURTAIN_ROWS
		var v1 := float(j + 1) / CURTAIN_ROWS
		for i in CURTAIN_COLS:
			var u0 := float(i) / CURTAIN_COLS
			var u1 := float(i + 1) / CURTAIN_COLS
			var pts := PackedVector2Array([
				rect.position + Vector2((u0 + _curtain_dx(u0, v0)) * rect.size.x, v0 * rect.size.y),
				rect.position + Vector2((u1 + _curtain_dx(u1, v0)) * rect.size.x, v0 * rect.size.y),
				rect.position + Vector2((u1 + _curtain_dx(u1, v1)) * rect.size.x, v1 * rect.size.y),
				rect.position + Vector2((u0 + _curtain_dx(u0, v1)) * rect.size.x, v1 * rect.size.y)])
			draw_polygon(pts, cols, PackedVector2Array([Vector2(u0, v0), Vector2(u1, v0), Vector2(u1, v1), Vector2(u0, v1)]), tex)


## The Veiled Eyes carrying a spell card off (animation.pdf, the last pose): the same body, its two sets of legs swung in and down round the card
## ([pivot (the legs' top left corner in the picture), shift, turn in radians], all as fractions of the picture; read off the storyboard).
const STEAL_LEGS := [[Vector2(0.0378, 0.5424), Vector2(-0.0334, 0.2353), -0.836], [Vector2(0.6300, 0.5515), Vector2(0.0739, -0.0247), 0.524]]
## Where the card hangs in that pose: its top left corner and its width, as fractions of the picture.
const STEAL_CARD := [Vector2(0.1636, 0.876), 0.714]


func _draw_steal_pose(rect: Rect2, side: float, mod: Color) -> void:
	var e := steal_pose * steal_pose * (3.0 - 2.0 * steal_pose)
	for k in 2:
		var leg: Array = STEAL_LEGS[k]
		var pivot: Vector2 = rect.position + (leg[0] as Vector2) * side
		draw_set_transform_matrix(_art_xf * Transform2D(float(leg[2]) * e, Vector2.ONE, 0.0, pivot + (leg[1] as Vector2) * side * e) * Transform2D(0.0, -pivot))
		draw_texture_rect(_unveil_tex[2 + k], rect, false, mod)  # (the legs, behind the body)
	draw_set_transform_matrix(_art_xf)
	draw_texture_rect(_unveil_tex[0], rect, false, mod)
	draw_texture_rect(_unveil_tex[1], rect, false, mod)


## Where a card hangs in the carrying pose on the screen: [top left, width in px] (the picture's square, lifted as it is in phase 2).
func steal_card_spot() -> Array:
	var r := puppet_art_rect()
	return [r.position + (STEAL_CARD[0] as Vector2) * r.size.x, float(STEAL_CARD[1]) * r.size.x]


func _draw_head(rect: Rect2, off: Vector2, mod: Color) -> void:
	draw_texture_rect(_unveil_tex[1], Rect2(rect.position + off, rect.size), false, mod)


## The Veiled Eyes' drawn art: its eyes light up over the picture to tell what it does next (see _eyes_cue). The glow is not painted on: it is a patch of the
## picture with its eyes lit (veiled_eyes_2_lit: the same pose, so every eye is where it is in the other pictures), laid over the dull eye with soft edges.
## Phase 1: the human eyes glow through the veil. Phase 2: its human eyes stare / shine, and as many of its spider eyes as the cue counts light up.
const VEIL_EYES := [[Vector2(0.3665, 0.4590), 0.085], [Vector2(0.6398, 0.4625), 0.085]]  # [place, radius as a fraction of the picture] of the two human eyes (both phases)
const VEIL1_EYES := [[Vector2(0.4490, 0.1250), 0.0204], [Vector2(0.5420, 0.1250), 0.0204]]  # the same in phase 1 (the tall veil: its eyes are high and small)
const VEIL_DOTS := [[Vector2(0.4625, 0.7519), 0.034], [Vector2(0.5403, 0.7519), 0.034], [Vector2(0.4695, 0.7162), 0.026], [Vector2(0.5389, 0.7148), 0.026]]


func _draw_veiled_eyes_art(c: Vector2, side: float, mod: Color, phase2: bool) -> void:
	if _veil_tex.size() != 2 or _veil_tex[1] == null:
		return
	var pulse := 0.85 + 0.15 * sin(Time.get_ticks_msec() / 1000.0 * 9.0)
	var cue: Variant = _eyes_cue()
	var lit: Texture2D = _veil_tex[1] if phase2 else _veil1_lit
	if lit == null:
		return
	var eyes: Array = VEIL_EYES if phase2 else VEIL1_EYES
	var stare: bool = _hypno > 0.0 or (phase2 and cue != null and typeof(cue) != TYPE_STRING and int(cue) == 0)
	var side_cue: String = cue if typeof(cue) == TYPE_STRING else ""  # (phase 1 says "both" / "left" / "right"; phase 2 a number: comparing the two kinds is an error)
	var left: bool = stare or side_cue == "both" or side_cue == "left"
	var right: bool = stare or side_cue == "both" or side_cue == "right"
	for k in 2:
		if (left if k == 0 else right):
			_lit_patch(lit, c, side, eyes[k][0], side * float(eyes[k][1]) * (1.0 if phase2 else 2.2), pulse, mod)
	if phase2 and not stare and cue != null and typeof(cue) != TYPE_STRING:
		for k in mini(int(cue), VEIL_DOTS.size()):
			_lit_patch(lit, c, side, VEIL_DOTS[k][0], side * float(VEIL_DOTS[k][1]), pulse, mod)


## A round patch of `tex` (a picture of the same square as the puppet) around the point `frac`, its edge fading into what is under it.
func _lit_patch(tex: Texture2D, c: Vector2, side: float, frac: Vector2, r: float, amount: float, mod: Color) -> void:
	var centre := c + (frac - Vector2(0.5, 0.5)) * side
	var origin := c - Vector2(side, side) * 0.5
	var rings := [[0.03, 1.0], [0.55, 1.0], [0.8, 0.55], [1.0, 0.0]]  # [radius fraction, opacity]: solid in the middle, a soft edge
	var seg := 28
	for i in rings.size() - 1:
		for j in seg:
			var a0 := TAU * j / seg
			var a1 := TAU * (j + 1) / seg
			var pts := PackedVector2Array()
			var cols := PackedColorArray()
			var uvs := PackedVector2Array()
			var quad := [[i, a0], [i + 1, a0], [i + 1, a1], [i, a1]]
			for q in quad:
				var ring: Array = rings[q[0]]
				var p: Vector2 = centre + Vector2.from_angle(q[1]) * r * float(ring[0])
				pts.append(p)
				cols.append(Color(mod.r, mod.g, mod.b, float(ring[1]) * amount))
				uvs.append((p - origin) / side)
			draw_polygon(pts, cols, uvs, tex)


## A human eye: an almond of white with a violet iris; lit, it glows through anything over it.
func _human_eye(at: Vector2, w: float, look: Vector2, lit: bool, blink_on: bool) -> void:
	var pts := PackedVector2Array()
	for k in 24:
		var t := k / 23.0 * TAU
		pts.append(at + Vector2(cos(t) * w, sin(t) * w * 0.48 * (1.0 if sin(t) > 0 else 0.9)))
	if lit:
		var pulse := 0.8 + 0.2 * sin(Time.get_ticks_msec() / 1000.0 * 9.0)
		draw_circle(at, w * 1.9, Color(VIOLET, 0.16 * pulse))
		draw_circle(at, w * 1.3, Color(VIOLET, 0.28 * pulse))
	draw_colored_polygon(pts, Color(0.97, 0.95, 0.98) if not blink_on else Color.WHITE)
	var iris := at + Vector2(look.x * w * 0.35, look.y * w * 0.15)
	draw_circle(iris, w * 0.36, VIOLET.lightened(0.25) if lit else VIOLET)
	draw_circle(iris, w * 0.17, Color(0.05, 0.02, 0.08))
	draw_circle(iris + Vector2(-w * 0.1, -w * 0.1), w * 0.07, Color(1, 1, 1, 0.9))
	pts.append(pts[0])
	draw_polyline(pts, Color(0.05, 0.03, 0.06), maxf(1.5, w * 0.1), true)


## The thin black veil over its eyes (drop 0: on; up to 1: it slides down and fades away).
func _draw_veil(at: Vector2, r: float, drop: float) -> void:
	var a := 0.72 * (1.0 - drop)
	if a <= 0.01:
		return
	var off := Vector2(drop * r * 0.15, drop * r * 2.4)
	var pts := PackedVector2Array()
	for k in 13:
		var t := PI + k / 12.0 * PI  # the top half of the ball
		pts.append(at + off + Vector2(cos(t), sin(t)) * r * 1.03)
	for k in 13:  # a wavy hem, under the eyes
		var u := 1.0 - k / 12.0
		var x := lerpf(-r * 1.03, r * 1.03, u)
		pts.append(at + off + Vector2(x, r * (0.18 + 0.07 * sin(u * 18.0 + bob * 0.6))))
	draw_colored_polygon(pts, Color(0.02, 0.01, 0.03, a))


func _draw_spiderling(c: Vector2, s: float, body: Color) -> void:
	draw_line(Vector2(c.x, 0), c + Vector2(0, -s * 0.5), Color(SILK, 0.8), 1.5, true)
	var leg := body.darkened(0.3)
	for side in [-1, 1]:
		for k in 4:
			var root := c + Vector2(side * s * 0.25, -s * 0.1 + k * s * 0.13)
			var knee := root + Vector2(side * s * 0.55, (-0.4 + k * 0.22) * s)
			var foot := knee + Vector2(side * s * 0.2, (0.45 + k * 0.08) * s)
			draw_polyline(PackedVector2Array([root, knee, foot]), leg, s * 0.09, true)
	draw_circle(c, s * 0.48, body)
	draw_circle(c + Vector2(0, s * 0.5), s * 0.28, body.lightened(0.05))
	for side in [-1, 1]:
		draw_circle(c + Vector2(side * s * 0.1, s * 0.48), s * 0.07, Color(1.0, 0.45, 0.9))


func _draw_cocoon(c: Vector2, s: float) -> void:
	var sway := sin(bob * 0.7) * 0.08
	var at := c + Vector2(0, -s * 0.05)
	draw_line(Vector2(c.x, 0), at + Vector2(0, -s * 0.9), SILK, 2.0, true)
	draw_set_transform(at, sway, Vector2.ONE)
	var pts := PackedVector2Array()
	for k in 28:
		var t := k / 27.0 * TAU
		pts.append(Vector2(cos(t) * s * 0.55, sin(t) * s * 0.9))
	draw_colored_polygon(pts, SILK)
	for k in 7:  # silk wound round and round
		var y := -s * 0.75 + k * s * 0.25
		var half := s * 0.55 * sqrt(maxf(0.0, 1.0 - pow(y / (s * 0.9), 2)))
		draw_line(Vector2(-half, y - s * 0.05), Vector2(half, y + s * 0.07), SILK.darkened(0.15), 2.0, true)
	draw_rect(Rect2(Vector2(-s * 0.2, -s * 0.28), Vector2(s * 0.4, s * 0.56)), Color(0.55, 0.4, 0.75, 0.18))  # (a card, faintly, inside)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
