class_name RopeRig
extends Control
## The ropes the enemies of the Puppet Stage hang on (EnemyRopes, placed with the rope mode, see RopeEditor), drawn in a fight: every puppet that has a rivet
## gets a rope that goes straight up behind the ceiling, a little slack, and the rivet over the puppet. The top of a rope stays where it is while the
## puppet rocks, jolts, walks on or is thrown back, so the rivet drags the rope along. The ropes are drawn under the puppets (a node of their own, put
## between the scenery and the enemy row), the rivets over them; the ceiling's valance covers the tops of the ropes.

const RIVET_PX := 7.5
const ROPE_W := 4.5
const SEGMENTS := 14
const TOP_Y := -40.0  # the ropes end above the screen, behind the ceiling

var fs: FightScreen
var drag := {}  # (set by the rope mode) {id, i}: the rivet that is being dragged is drawn bigger
var t := 0.0
var _lines: RopeLines
var _shown := 0.0  # 0..1: the ropes fade in once the encounter board is gone (while it is up the drapes are shut and the enemies still walk on behind it)


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_as_relative = false
	z_index = PuppetStage.CEILING_Z - 1  # (over the puppets, under the ceiling)
	_lines = RopeLines.new()
	_lines.rig = self
	_lines.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_lines.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	fs.add_child.call_deferred(_lines)  # (the fight screen is still building itself: its stage and enemy row come after this node)
	_place_lines.call_deferred()


func _place_lines() -> void:
	if not is_instance_valid(fs):
		return
	if is_instance_valid(_lines) and _lines.get_parent() == fs and is_instance_valid(fs._enemy_row):
		fs.move_child(_lines, fs._enemy_row.get_index())  # (drawn after the stage, before the enemies)
	else:
		_place_lines.call_deferred()


func _exit_tree() -> void:
	if is_instance_valid(_lines):
		_lines.queue_free()


func _process(d: float) -> void:
	t += d
	if is_instance_valid(fs):
		_shown = move_toward(_shown, 0.0 if fs.hold_hud else 1.0, d * 2.0)
	modulate.a = _shown
	if is_instance_valid(_lines):
		_lines.modulate.a = _shown
		_lines.visible = _shown > 0.0
	visible = _shown > 0.0
	queue_redraw()


func _draw() -> void:
	if not is_instance_valid(fs):
		return
	for target in fs.rope_targets():
		var pts := EnemyRopes.points(target[0])
		for i in pts.size():
			var big: bool = not drag.is_empty() and drag.id == target[0] and drag.i == i
			var tex := _rivet_tex(int(ceil(RIVET_PX * (1.4 if big else 1.0))))
			draw_texture(tex, target[1].rope_point(pts[i]) - tex.get_size() * 0.5)  # (never snapped to whole pixels: the puppet moves smoothly and the rivet must move with it)


static var _rivet_cache := {}  # size in px -> the rivet picture made that small


## The rivet's picture shrunk (properly filtered) to `px` pixels: drawn straight from the big picture a rivet this small came out as a white speck.
static func _rivet_tex(px: int) -> Texture2D:
	if not _rivet_cache.has(px):
		var img: Image = (load("res://assets/Puppet/Enemies/rivet.png") as Texture2D).get_image()
		if img.is_compressed():
			img.decompress()
		img.resize(px, px, Image.INTERPOLATE_LANCZOS)
		_rivet_cache[px] = ImageTexture.create_from_image(img)
	return _rivet_cache[px]


## The ropes, under the puppets: a rope from its fixed top to the rivet, a little longer than the straight way, so it sags to the side the rivet has swung
## away from, and sways a little all the time.
class RopeLines extends Control:
	var rig: RopeRig

	func _process(_d: float) -> void:
		queue_redraw()

	func _draw() -> void:
		if rig == null or not is_instance_valid(rig.fs):
			return
		for target in rig.fs.rope_targets():
			var cr: Creature = target[1]
			var pts := EnemyRopes.points(target[0])
			for i in pts.size():
				var rest := cr.rope_point(pts[i], true)
				_rope(Vector2(rest.x, RopeRig.TOP_Y), cr.rope_point(pts[i]), float(i) * 1.7 + rest.x * 0.01)

	func _rope(top: Vector2, end: Vector2, phase: float) -> void:
		var bow := sin(rig.t * 0.9 + phase) * 3.0 + 4.0 - clampf((end.x - top.x) * 0.1, -16.0, 16.0)
		var prev := top
		for k in range(1, RopeRig.SEGMENTS + 1):
			var u := float(k) / RopeRig.SEGMENTS
			var q := top.lerp(end, u) + Vector2(sin(PI * u) * bow, 0.0)
			MapScreen.MapRope.draw_between(self, prev, q, 0.0, Color.WHITE, RopeRig.ROPE_W)
			prev = q
