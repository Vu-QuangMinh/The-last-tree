class_name SlotMachine
extends RefCounted
## The Puppet Stage's Essence machine (a slot machine, from assets/Puppet/_Source/Slot_machine.pdf; the pieces are cut by tools/export_slot_machine.py and placed by
## PuppetSlotMachine). It is two layers that go on each side of the Essence (FightScreen puts them in the Bag strip):
##   back  = the glass tube and the hole of the port,   front = both funnels, the cabinet with its three reels and eight lamps, the lever, the tube's clamps and
##   the ring of the port.   The Essence themselves are drawn between the two, so they sink out of sight behind the funnels and the cabinet, travel down the tube
##   in front of the glass and come up out of the port from under its ring.
## Everything here is in the Bag strip's coordinates (screen position minus PuppetLayout.BAG_AT).
## A normal spawn: the lever is pulled down, the reels spin and stop one after another on the Essence that spawn (spin), each drops out into the bottom funnel
## (drop_front_orb), the lever goes back up. A bonus Essence just goes into the top funnel and comes out of the port (the route is FightScreen's).

const FACE_PX := 30.0  # an Essence shown on a reel
const SPIN_STEP := 36.0  # distance between two faces on a spinning reel
const SPIN_FACES := 14
const DROP_TIME := 0.36
const TUBE_R := 76.0  # radius of the tube's bend (the centre line of the glass)
const TUBE_X := 1769.2  # the centre line of the vertical part of the glass
const TUBE_Y := 1015.8  # the centre line of the horizontal part

var behind := Control.new()  # (under the Bag strip itself: FightScreen expects it; empty here until the layer's art is committed)
var back := Control.new()
var front := Control.new()
var busy := false  # a spin is going on: the preview must not touch the reels

var _lamps: Array = []
var _lamp_on: Texture2D
var _lamp_off: Texture2D
var _boxes: Array = []  # a clipping box over each reel
var _faces: Array = [null, null, null]  # the Essence icon standing on each reel
var _strips: Array = [null, null, null]
var _spin_tw: Array = [null, null, null]
var _lever: TextureRect
var _lever_tw: Tween
var _chase_tw: Tween
var _flash_tw: Tween
var _stopped := 0


static func local(p: Vector2) -> Vector2:
	return p - PuppetLayout.BAG_AT


static func available() -> bool:
	for n in ["slot_body", "slot_funnel_top", "slot_tube_glass_under", "slot_tube_glass", "slot_tube_metal", "slot_reel", "slot_lever", "slot_lamp_on", "slot_lamp_off",
			"slot_port", "slot_port_ring"]:
		if UiSkin.tex(n) == null:
			return false
	return true


static func _art(tex_name: String, r: Rect2) -> TextureRect:
	var t := TextureRect.new()
	t.texture = UiSkin.tex(tex_name)
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_SCALE
	t.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	t.position = local(r.position)
	t.size = r.size
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return t


## A soft dark shadow shaped like a rounded box (`r`, screen px) that fades out over `fall` px all round: one texture, stretched.
static func _shadow(r: Rect2, fall: float, strength: float) -> TextureRect:
	var side := 96
	var img := Image.create(side, side, false, Image.FORMAT_RGBA8)
	var core := side * 0.5 - fall * 0.5  # (half the size of the solid part, in texture px, the rest is the fall)
	for y in side:
		for x in side:
			var dx := maxf(absf(x + 0.5 - side * 0.5) - core * 0.55, 0.0)
			var dy := maxf(absf(y + 0.5 - side * 0.5) - core * 0.55, 0.0)
			var d := sqrt(dx * dx + dy * dy) / maxf(side * 0.5 - core * 0.55, 1.0)
			var a := clampf(1.0 - d, 0.0, 1.0)
			img.set_pixel(x, y, Color(0, 0, 0, pow(a, 0.7) * strength))
	var t := TextureRect.new()
	t.texture = ImageTexture.create_from_image(img)
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_SCALE
	t.position = local(r.position) - Vector2(fall, fall)
	t.size = r.size + Vector2(fall, fall) * 2.0
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return t


## Photoshop's Screen blend at 50 % opacity on a picture (it only lightens what is behind it; see assets/Global/Card/Shaders/screen_blend.gdshader).
static func _screen(t: TextureRect) -> TextureRect:
	var sh := load("res://assets/Global/Card/Shaders/screen_blend.gdshader") as Shader
	if sh != null:
		var m := ShaderMaterial.new()
		m.shader = sh
		m.set_shader_parameter("strength", 0.5)
		t.material = m
	else:
		t.modulate.a = 0.5
	return t


func build() -> void:
	for c in [behind, back, front]:
		c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# a plain soft shadow behind the cabinet and its funnel: the machine stands apart from the stage behind it
	var body: Rect2 = PuppetSlotMachine.BODY
	back.add_child(_shadow(body.grow(-2.0), 56.0, 1.0))
	var top: Rect2 = PuppetSlotMachine.FUNNEL_TOP
	back.add_child(_shadow(Rect2(top.position + Vector2(18.0, 8.0), top.size - Vector2(36.0, 16.0)), 40.0, 0.9))
	# the glass under the Essence: Screen at 50 %. (The real Screen shader reads the screen behind it and, drawn below the Essence, makes them vanish in
	# Compatibility; for these small bright patches over a dark floor "Add" at 50 % looks the same: screen(a, b) = a + b - a*b is almost a + b when b is small.)
	var under := _art("slot_tube_glass_under", PuppetSlotMachine.TUBE_GLASS_UNDER)
	var add := CanvasItemMaterial.new()
	add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	under.material = add
	under.modulate.a = 0.5
	back.add_child(under)
	# (no port hole in the Bag strip any more: the Essence roll straight out of the tube into the Bag)
	front.add_child(_art("slot_funnel_top", PuppetSlotMachine.FUNNEL_TOP))
	# the tube's glass over the Essence (Screen blend, 50 %: it only lightens, so they show through) and its metal (collars, clamps), under the cabinet
	front.add_child(_screen(_art("slot_tube_glass", PuppetSlotMachine.TUBE_GLASS)))
	front.add_child(_art("slot_tube_metal", PuppetSlotMachine.TUBE_METAL))
	front.add_child(_art("slot_body", PuppetSlotMachine.BODY))
	for i in 3:
		var at := Vector2(PuppetSlotMachine.REEL_X[i], PuppetSlotMachine.REEL_Y)
		front.add_child(_art("slot_reel", Rect2(at, PuppetSlotMachine.REEL_SIZE)))
		var box := Control.new()
		box.clip_contents = true
		box.position = local(at) + Vector2(2.0, 4.0)  # (only the face of the drum, not the shading around it: what spins must not spill out of the window)
		box.size = PuppetSlotMachine.REEL_SIZE - Vector2(4.0, 18.0)
		box.mouse_filter = Control.MOUSE_FILTER_IGNORE
		front.add_child(box)
		_boxes.append(box)
	_lamp_on = UiSkin.tex("slot_lamp_on")
	_lamp_off = UiSkin.tex("slot_lamp_off")
	for x in PuppetSlotMachine.LAMP_X:
		var l := TextureRect.new()
		l.texture = _lamp_off
		l.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		l.stretch_mode = TextureRect.STRETCH_SCALE
		l.size = PuppetSlotMachine.LAMP_SIZE
		l.position = local(Vector2(x, PuppetSlotMachine.LAMP_Y) - PuppetSlotMachine.LAMP_SIZE / 2.0)
		l.mouse_filter = Control.MOUSE_FILTER_IGNORE
		front.add_child(l)
		_lamps.append(l)
	_lever = _art("slot_lever", PuppetSlotMachine.LEVER)
	_lever.pivot_offset = PuppetSlotMachine.LEVER_HUB - PuppetSlotMachine.LEVER.position
	front.add_child(_lever)
	set_lamps(false)


# ------------------------------------------------------------------ places (Bag strip coordinates, centres)

func reel_center(i: int) -> Vector2:
	return local(Vector2(PuppetSlotMachine.REEL_X[i], PuppetSlotMachine.REEL_Y) + PuppetSlotMachine.REEL_SIZE / 2.0)


## The mouth of the top funnel: where a bonus Essence goes in.
func funnel_top_mouth() -> Vector2:
	var r: Rect2 = PuppetSlotMachine.FUNNEL_TOP
	return local(Vector2(r.position.x + r.size.x / 2.0, r.position.y + 14.0))


## Where an Essence enters the tube: just under the cabinet, still hidden behind it (there is no bottom funnel: the tube starts right under the cabinet).
func funnel_bottom_in() -> Vector2:
	var r: Rect2 = PuppetSlotMachine.BODY
	return local(Vector2(TUBE_X, r.end.y - 6.0))


## The centre line of the tube, from just under the funnel to the cap at the Bag strip's edge.
func tube_path() -> Array:
	var pts: Array = [local(Vector2(TUBE_X, PuppetSlotMachine.BODY.end.y + 2.0))]
	var c := Vector2(TUBE_X - TUBE_R, TUBE_Y - TUBE_R)  # centre of the bend
	pts.append(local(Vector2(TUBE_X, c.y)))
	for k in range(1, 9):  # a quarter circle, from straight down to straight left
		var a := PI / 2.0 * k / 8.0
		pts.append(local(c + Vector2(cos(a), sin(a)) * TUBE_R))
	pts.append(local(Vector2(1636.0, TUBE_Y)))
	return pts


func port_center() -> Vector2:
	return local(PuppetSlotMachine.PORT_C)


# ------------------------------------------------------------------ the lever

func lever_pull() -> void:
	if _lever_tw != null and _lever_tw.is_valid():
		_lever_tw.kill()
	_lever_tw = _lever.create_tween()
	_lever_tw.tween_property(_lever, "rotation", PuppetSlotMachine.LEVER_PULLED_ANGLE, 0.32).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)


func lever_return() -> void:
	if _lever_tw != null and _lever_tw.is_valid():
		_lever_tw.kill()
	_lever_tw = _lever.create_tween()
	_lever_tw.tween_property(_lever, "rotation", 0.0, 0.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


# ------------------------------------------------------------------ the lamps

func set_lamps(on: bool) -> void:
	for l in _lamps:
		l.texture = _lamp_on if on else _lamp_off


func _chase_start() -> void:
	_chase_stop()
	_chase_tw = front.create_tween().set_loops()
	for i in _lamps.size():
		_chase_tw.tween_callback(func() -> void:
			for k in _lamps.size():
				_lamps[k].texture = _lamp_on if k == i else _lamp_off)
		_chase_tw.tween_interval(0.07)


func _chase_stop() -> void:
	if _chase_tw != null and _chase_tw.is_valid():
		_chase_tw.kill()
	_chase_tw = null


## All the lamps flash twice.
func _flash() -> void:
	_chase_stop()
	if _flash_tw != null and _flash_tw.is_valid():
		_flash_tw.kill()
	_flash_tw = front.create_tween()
	for k in 2:
		_flash_tw.tween_callback(set_lamps.bind(true))
		_flash_tw.tween_interval(0.12)
		_flash_tw.tween_callback(set_lamps.bind(false))
		_flash_tw.tween_interval(0.1)


# ------------------------------------------------------------------ the reels

func _face(el: String, temp := false) -> ElementIcon:
	var ic := ElementIcon.make(el, FACE_PX)
	ic.size = Vector2(FACE_PX, FACE_PX)
	ic.pivot_offset = ic.size / 2.0
	ic.temp = temp
	ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return ic


func clear_face(i: int) -> void:
	if _faces[i] != null and is_instance_valid(_faces[i]):
		_faces[i].queue_free()
	_faces[i] = null


## Put these Essence on the reels, one each, left to right ("" or nothing leaves a reel empty). `bounce`: they pop in.
func set_faces(els: Array, bounce := false) -> void:
	for i in 3:
		clear_face(i)
		if i < els.size() and String(els[i]) != "":
			var ic := _face(String(els[i]))
			ic.position = (_boxes[i].size - ic.size) / 2.0
			_boxes[i].add_child(ic)
			_faces[i] = ic
			if bounce:
				ic.scale = Vector2(1.3, 1.3)
				ic.create_tween().tween_property(ic, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## The reels spin for `dur` seconds (the lamps chase) and stop one after another, the last at `dur`, each on its Essence of `finals`.
func spin(finals: Array, dur := 2.0) -> void:
	busy = true
	for i in 3:
		clear_face(i)
	var kinds := ["F", "W", "A"]
	for i in 3:
		var strip := Control.new()
		strip.size = Vector2(FACE_PX, SPIN_STEP * SPIN_FACES)
		strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		for k in SPIN_FACES:
			var ic := _face(kinds[(k + i * 2 + randi() % 2) % 3])
			ic.position = Vector2(0.0, k * SPIN_STEP)
			strip.add_child(ic)
		strip.modulate.a = 0.8
		strip.position = Vector2((_boxes[i].size.x - FACE_PX) / 2.0, -float(randi() % 6) * SPIN_STEP)
		_boxes[i].add_child(strip)
		_strips[i] = strip
		var y0 := strip.position.y
		var tw := strip.create_tween().set_loops()
		tw.tween_property(strip, "position:y", y0 + SPIN_STEP * 6.0, 0.28).from(y0)
		_spin_tw[i] = tw
	_chase_start()
	var stops := [maxf(0.1, dur - 0.6), maxf(0.1, dur - 0.3), dur]
	var t0 := Time.get_ticks_msec()
	for i in 3:
		var wait: float = stops[i] - (Time.get_ticks_msec() - t0) / 1000.0
		if wait > 0.0:
			await front.get_tree().create_timer(wait).timeout
		if not is_instance_valid(front) or not front.is_inside_tree():
			busy = false
			return
		if _spin_tw[i] != null and _spin_tw[i].is_valid():
			_spin_tw[i].kill()
		_spin_tw[i] = null
		if _strips[i] != null and is_instance_valid(_strips[i]):
			_strips[i].queue_free()
		_strips[i] = null
		if i < finals.size() and String(finals[i]) != "":
			set_faces_one(i, String(finals[i]))
		Audio.play("sfx_reel_stop", -2.0, randf_range(0.95, 1.05))
	_flash()
	await front.get_tree().create_timer(0.35).timeout


func set_faces_one(i: int, el: String) -> void:
	clear_face(i)
	var ic := _face(el)
	ic.position = (_boxes[i].size - ic.size) / 2.0
	_boxes[i].add_child(ic)
	_faces[i] = ic
	ic.scale = Vector2(1.3, 1.3)
	ic.create_tween().tween_property(ic, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## The Essence on reel i drops out of the machine (in front of the cabinet) and into the bottom funnel, starting `delay` seconds from now; from the funnel the real
## Essence takes over (behind it). `big`: the size of a real Essence. Returns how long the drop itself takes.
func drop_front_orb(i: int, el: String, big: float, delay := 0.0) -> float:
	var a := reel_center(i)
	var b := funnel_bottom_in()
	var tw := front.create_tween()
	var holder: Array = []
	tw.tween_interval(delay)
	tw.tween_callback(func() -> void:
		clear_face(i)
		var ic := _face(el)
		ic.position = a - ic.size / 2.0
		front.add_child(ic)
		holder.append(ic))
	tw.tween_method(func(u: float) -> void:
		if not holder.is_empty() and is_instance_valid(holder[0]):
			var ic: ElementIcon = holder[0]
			var down := u * u  # (it falls: slow at first)
			var across := smoothstep(0.0, 1.0, u)
			ic.position = Vector2(lerpf(a.x, b.x, across), lerpf(a.y, b.y, down)) - ic.size / 2.0
			ic.scale = Vector2.ONE * lerpf(1.0, big / FACE_PX, u)
			ic.rotation = u * TAU, 0.0, 1.0, DROP_TIME)
	tw.tween_callback(func() -> void:
		if not holder.is_empty() and is_instance_valid(holder[0]):
			holder[0].queue_free())
	return DROP_TIME
