# Godot 4 2D recipes (Compatibility renderer)

Small, copyable building blocks. Adapt names and style to the surrounding code (typed GDScript; warnings are
errors in this project, so annotate types on untyped Array/Dictionary values).

## Contents
1. Hit-stop
2. Trauma screen shake
3. Squash and stretch on a hit
4. Pop-in with overshoot
5. Delayed "ghost" health drain
6. Shader: hit flash
7. Shader: dissolve (deaths)
8. Shader: scrolling-noise fire / aura
9. Shader: heat haze / shockwave distortion
10. Sound with pitch variation

---

## 1. Hit-stop

Freeze the game for a few frames on impact. Timers must ignore time scale or they freeze too.

```gdscript
## Freeze everything for `ms` (bigger hits, longer: 40 chip, 80 normal, 120+ a kill).
func hit_stop(ms: float) -> void:
	Engine.time_scale = 0.0
	# process_always, process_in_physics = false, ignore_time_scale = true
	await get_tree().create_timer(ms / 1000.0, true, false, true).timeout
	Engine.time_scale = 1.0
```

Caveats: tweens/timers that should keep running during the freeze need `set_ignore_time_scale(true)`.
Don't stack overlapping hit-stops; keep the longest. In a turn-based game, a lighter alternative is to pause
only the effect layer and the target (stop their `_process` clocks) instead of the global time scale.

## 2. Trauma screen shake

Shake a Control (the fight screen root) or a Camera2D's `offset`.

```gdscript
var trauma := 0.0  # 0..1
var _noise := FastNoiseLite.new()
var _t := 0.0
const MAX_OFFSET := 18.0
const MAX_ROT := 0.02  # radians
const DECAY := 1.6  # trauma per second

func _ready() -> void:
	_noise.seed = randi()
	_noise.frequency = 0.9

## Add shake: 0.15 small hit, 0.35 big hit, 0.6 a kill or boss slam.
func add_trauma(amount: float) -> void:
	trauma = minf(1.0, trauma + amount)

func _process(d: float) -> void:
	if trauma <= 0.0:
		return
	_t += d * 60.0
	trauma = maxf(0.0, trauma - DECAY * d)
	var k := trauma * trauma
	position = Vector2(_noise.get_noise_2d(1.0, _t), _noise.get_noise_2d(50.0, _t)) * MAX_OFFSET * k
	rotation = _noise.get_noise_2d(100.0, _t) * MAX_ROT * k
	if trauma == 0.0:
		position = Vector2.ZERO
		rotation = 0.0
```

Directional kick: on top of the noise, tween `position` by `dir * 8` and back over ~0.12 s.
Respect a "screen shake" accessibility setting if one exists (scale MAX_OFFSET by it).

## 3. Squash and stretch on a hit

```gdscript
func squash(node: Control, dir := Vector2.RIGHT) -> void:
	node.pivot_offset = Vector2(node.size.x / 2.0, node.size.y)  # squash from the feet
	var tw := node.create_tween()
	tw.tween_property(node, "scale", Vector2(1.25, 0.75), 0.05)
	tw.tween_property(node, "scale", Vector2(0.9, 1.1), 0.08)
	tw.tween_property(node, "scale", Vector2.ONE, 0.15).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	var home := node.position
	var kb := node.create_tween()
	kb.tween_property(node, "position", home + dir * 14.0, 0.05)
	kb.tween_property(node, "position", home, 0.25).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
```

(Watch out for containers: they reset position/scale of children. Animate an inner node, or the drawing offset.)

## 4. Pop-in with overshoot

```gdscript
node.pivot_offset = node.size / 2.0
node.scale = Vector2(0.4, 0.4)
node.modulate.a = 0.0
var tw := node.create_tween().set_parallel(true)
tw.tween_property(node, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
tw.tween_property(node, "modulate:a", 1.0, 0.12)
```

## 5. Delayed "ghost" health drain

Two bars: the real one drops instantly; a pale one behind it waits ~0.35 s, then drains.

```gdscript
func set_hp(v: float) -> void:
	front.value = v
	if _ghost_tw: _ghost_tw.kill()
	_ghost_tw = create_tween()
	_ghost_tw.tween_interval(0.35)
	_ghost_tw.tween_property(ghost, "value", v, 0.4).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
```

## 6. Shader: hit flash

```glsl
shader_type canvas_item;
uniform vec4 flash_col : source_color = vec4(1.0);
uniform float amount : hint_range(0.0, 1.0) = 0.0;
void fragment() {
	vec4 t = texture(TEXTURE, UV) * COLOR;
	COLOR = vec4(mix(t.rgb, flash_col.rgb, amount), t.a);
}
```
Tween `material:shader_parameter/amount` 1 → 0 over ~0.15 s. For blinks, toggle it a few times.

## 7. Shader: dissolve (deaths)

```glsl
shader_type canvas_item;
uniform sampler2D noise : repeat_enable;  // a NoiseTexture2D (seamless)
uniform float progress : hint_range(0.0, 1.0) = 0.0;
uniform float edge = 0.06;
uniform vec4 edge_col : source_color = vec4(1.0, 0.6, 0.2, 1.0);
void fragment() {
	vec4 t = texture(TEXTURE, UV) * COLOR;
	float n = texture(noise, UV).r;
	if (n < progress) discard;
	float e = 1.0 - smoothstep(progress, progress + edge, n);
	COLOR = vec4(mix(t.rgb, edge_col.rgb * 1.6, e), t.a);
}
```
Tween `progress` 0 → 1 over 0.6–0.9 s with ease-in, and emit embers along the way (`Vfx.burst`).
For procedural `_draw()` creatures (no texture), put the creature inside a `SubViewport` or apply the
shader to a parent `CanvasGroup` so it samples the drawn result.

## 8. Shader: scrolling-noise fire / aura

```glsl
shader_type canvas_item;
render_mode blend_add;
uniform sampler2D noise : repeat_enable;
uniform vec4 hot : source_color = vec4(1.0, 0.95, 0.7, 1.0);
uniform vec4 cool : source_color = vec4(1.0, 0.3, 0.05, 1.0);
uniform float speed = 0.6;
void fragment() {
	float a = texture(noise, UV * vec2(1.0, 0.8) + vec2(0.0, TIME * speed)).r;
	float b = texture(noise, UV * 1.7 + vec2(TIME * 0.13, TIME * speed * 1.4)).r;
	float shape = (1.0 - UV.y) * smoothstep(0.0, 0.25, UV.x) * smoothstep(1.0, 0.75, UV.x);  // tall, fading up
	float f = clamp(a * b * 2.2 * shape, 0.0, 1.0);
	f = smoothstep(0.15, 0.6, f);
	COLOR = vec4(mix(cool.rgb, hot.rgb, f), f);
}
```
Put it on a ColorRect sized to the flame area. `campfire_flame.gd` already does a hand-tuned version.

## 9. Shader: heat haze / shockwave distortion

```glsl
shader_type canvas_item;
uniform sampler2D screen_tex : hint_screen_texture, filter_linear;
uniform sampler2D noise : repeat_enable;
uniform float strength = 0.006;
void fragment() {
	vec2 n = texture(noise, UV + vec2(0.0, TIME * 0.4)).rg - 0.5;
	float mask = 1.0 - length(UV - 0.5) * 2.0;  // soft circle
	COLOR = texture(screen_tex, SCREEN_UV + n * strength * clamp(mask, 0.0, 1.0));
}
```
Screen reading costs a copy of the screen on web: use for a short moment (a big explosion), not constantly.
For a shockwave, replace the noise with a ring: offset along the direction from the centre where
`abs(dist - radius) < width`, and tween `radius` outward.

## 10. Sound with pitch variation

```gdscript
var p := AudioStreamPlayer.new()
p.stream = stream
p.pitch_scale = randf_range(0.93, 1.07)
add_child(p)
p.play()
p.finished.connect(p.queue_free)
```
In this project, prefer the `Audio` autoload (`Audio.play("name")`); add a pitch option there if needed.
Fire the sound in the same frame as the visual impact, not when the projectile was launched.
