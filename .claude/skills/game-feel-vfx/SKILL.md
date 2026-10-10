---
name: game-feel-vfx
description: How AAA games make effects feel powerful (layering, anticipation, hit-stop, trauma-based screen shake, flashes, additive glow, shockwaves, dissolve/noise/distortion shaders, sound sync, target reactions) and how to build them in Godot 4 2D for The Last Tree. Use this whenever the user asks for or complains about visual effects, "juice", game feel, impact, polish, spell/attack animations, fireballs, explosions, hits, deaths, screen shake, flashes, glow, light, particles, shaders, or says something "feels weak/flat/boring", even if they don't say "VFX".
---

# Game feel and VFX

AAA effects are rarely one fancy asset. They are many cheap pieces, timed carefully, reacting together.
When something "feels weak", the fix is almost always more layers, better timing, or a missing reaction,
not a better sprite. Use this as a checklist when designing or reviewing any effect.

## The project already has a toolkit: use it first

- `scripts/ui/vfx.gd` (`Vfx`): authored-up-front effects that free themselves. Particles (`part`, `burst`),
  `glow`, `flare`, shockwave `ring`, `beam` (with lightning `jag`), `slash`, magic-circle `sigil`, hex `dome`,
  screen `flash`, projectiles with trails (`move`), emitters (`emit`) and `shake`. Light is drawn additively
  on its own layer; smoke/shards/crystals are drawn normally underneath.
- `scripts/ui/spell_fx.gd` (`SpellFx`): one "show" per kind of spell effect. `play()` returns the time until
  impact, and the fight waits that long before applying the effect, so impact visuals and game state line up.
- `scripts/ui/impact_fx.gd`: enemy hits landing on the player (blue on Shield, red on HP).
- `scripts/ui/creature.gd`: enemy reactions (`hit()`: jolt, white blinks, hurt face).
- `fight_screen.gd` `_shake()`: whole-screen jolt.
- Shaders live inline as `shader_type canvas_item` strings (see `campfire_flame.gd`, `backdrop.gd`).

Extend these rather than adding a parallel system. Read the relevant file before changing an effect.

**Renderer limit:** the project uses `gl_compatibility` (it ships a Web build). There is no 2D HDR, so don't
rely on WorldEnvironment glow/bloom. Fake bloom with additive soft-circle sprites (`Vfx.glow`) and colours
pushed towards white. Keep shaders simple (no compute, few texture reads) so the web build stays smooth.

## The seven layers of a good effect

Run through these for every effect. Most weak effects are missing 2 or 3 of them.

1. **Anticipation** (0.1–0.25 s). A wind-up tells the eye where to look: energy gathers, a sigil draws in,
   the caster pulses. Skip it only for very fast, frequent actions.
2. **The travel** (if anything moves). Core + glow + trail + shed sparks. Arc it slightly, ease it in
   (accelerate), never constant speed.
3. **Impact: the moment that matters.** Stack several pieces on the same frame:
   - a 1–2 frame **flash** (white-hot core, or a full-screen additive flash for big hits)
   - **hit-stop**: freeze 40–120 ms (bigger hit = longer). The single highest-value trick.
   - **screen shake** scaled to the hit
   - a **shockwave ring** racing out
   - a **burst** of sparks in the hit direction, plus a few slower, bigger embers/debris
   - a short **glow** that swells and fades (fake light on the surroundings)
4. **Target reaction.** The thing that got hit must answer: white blink, knockback/jolt *away* from the
   source, squash then stretch back, a hurt face, the HP pips popping off with their own small burst.
5. **Aftermath** (0.3–1 s). Smoke drifting up, embers falling, a scorch or lingering status glow
   (burning, frozen). This is what makes the hit feel like it changed the world.
6. **Sound on the same frame** as the impact. Slight random pitch (±5–10%) so repeats don't grate.
   Big hits: a low thump under the crack.
7. **UI follow-through.** Numbers pop (scale up fast, settle), health bars drain with a delayed "ghost"
   chunk so the player sees how much they lost.

## Timing rules

- **Fast in, slow out.** Flashes appear in 1 frame and fade over 10–20. Rings expand with ease-out.
  Particles start fast and decelerate (drag). Linear motion looks cheap.
- **Overshoot and settle** for anything that pops in (cards, numbers, icons): `TRANS_BACK` / `TRANS_ELASTIC`.
- **Scale to importance.** A tiny chip gets a spark and a 2 px shake. A Release that kills three enemies gets
  hit-stop, flash, big shake, rings, and a beat of silence before the next thing. If everything is huge,
  nothing is.
- **Stagger, don't sync, multiple hits.** 40–80 ms between hits on several targets reads as a rhythm.
- **Never block input for juice.** Effects play on top; gameplay can continue (or the wait is deliberate,
  like `SpellFx.play()` returning the impact time).

## Colour and light

- Light (fire, magic, sparks) is additive; matter (smoke, rock, ice shards) is drawn normally. Mixing them
  up makes fire look like paint and smoke look like light.
- Glowing things go white in the core and keep their colour at the edges. Use a colour ramp over life:
  white → element colour → transparent (fire: white → yellow → orange → dark red smoke).
- Element colours come from `Elements.COLORS`; keep effects on-palette so players read the element instantly.
- A brief whole-screen tint sells big moments: red vignette on heavy damage, a dark dip before a boss move.

## Camera / screen shake

Good shake is *trauma-based* and *smooth*, not random jumps:
- Keep a `trauma` value 0..1. Hits add to it; it decays linearly (≈1.5/s).
- Offset = max_offset × trauma² × noise(t). Squaring makes small hits subtle and big hits violent.
- Use smooth noise (`FastNoiseLite`) sampled over time, not `randf()` every frame.
- Optional: a small rotation, and a directional kick away from the hit source.
See `references/godot-recipes.md` for the code.

## Shaders worth having (canvas_item)

- **Dissolve:** a noise texture vs. a threshold that rises over time; pixels below it vanish, a thin band
  above it glows in the element colour. Great for enemy deaths.
- **Scrolling noise fire/aura:** two noise samples scrolling at different speeds, multiplied, then a
  threshold and a colour ramp. Gives living fire/poison/void auras without drawn frames.
- **Hit flash:** `mix(tex.rgb, flash_col, amount)` keeping alpha. Modulate only multiplies, so it can
  brighten but can't turn a red sprite truly white; the shader can.
- **Distortion/heat haze:** offset `SCREEN_UV` by noise inside a mask. Use sparingly on web.
Code is in `references/godot-recipes.md`.

## How to work

1. Read the effect's current code and, if possible, take a screenshot or short capture first
   (the project has `tools/shots.gd`, `tools/vfx_demo_impl.gd`, `tools/card_fx_gif.gd`).
2. Name what's missing using the seven layers, and tell the user in plain words ("the fireball has no
   wind-up and nothing happens to the enemy when it lands").
3. Add the cheapest high-impact pieces first: hit-stop, impact flash + ring + burst, target reaction, shake.
4. Verify visually (screenshots at the impact frame, or a gif), running Godot with `--audio-driver Dummy`.
5. Keep the settled game rules in CLAUDE.md intact (e.g. no auto-cast; effects never trigger gameplay).
