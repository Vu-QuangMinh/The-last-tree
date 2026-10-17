# New Essence machine (Puppet Stage) — design and logic

Reference picture: `assets/Puppet/UI/MachineNew/reference.png` (the user's layout). Asset prompts: `assets/Puppet/UI/MachineNew/machine_new_{prompts,style}.txt`
(ImageSet set "New Machine"). The user re-fits the generated pieces by hand; the wiring comes after that.

## Parts (back to front)

| Part | Role |
|---|---|
| Top funnel (`Funnel Back` + `Funnel Front`) | Wooden hopper over the machine. Bonus Essence fly up into it: they pass *between* the back and the front layer, so they sink out of sight behind the front wall. |
| Machine body | Brass cabinet: a strip of 8 lamps on top, a dark reel window, lever mount on the right. |
| 3 reel drums (`Reel Drum`) | Sit in the window. While spinning they show a blurred strip of Essence faces (made in code from the Essence icons); when they stop each shows the Essence that is about to spawn. |
| 8 lamps (`Light On` / `Light Off`) | Chase left to right while the reels spin; all flash once when they stop. |
| Lever (`Lever Mount` + `Lever Arm`) | The arm turns about its brass hub: up (idle) → pulled down (spawn starts) → back up. |
| Bottom funnel (the same `Funnel Back` / `Funnel Front`, smaller) | Under the machine: what leaves the machine drops into it (same back/front trick). |
| Glass tube (`Tube Vertical`, `Tube Elbow`, `Tube Horizontal`, 2 `Tube Clamp`) | From the bottom funnel straight down, a quarter turn to the left, then left into the Bag panel. Essence roll through it, behind the clamps. |
| Bag port (`Bag Port` + `Bag Port Lip`) | The round slot in the Bag panel. Essence come up out of it from behind the lip and roll into the Bag. |

## Flow A — a normal spawn (the start of your turn, and the first draw of a fight)

1. The lever swings down (≈0.35 s). Lamps start chasing. SFX: lever (given later).
2. The three reels spin for **2.0 s** (looping spin SFX). They stop one after another near the end (e.g. at 1.4 / 1.7 / 2.0 s, a stop SFX each) and show the
   Essence that spawn this turn. All lamps flash once. The result is exactly the draw the game already rolled (`next_draw`, shown in "Coming next" today).
3. Each shown Essence drops out of the machine into the bottom funnel (one after another, ≈0.12 s apart), through the tube, up out of the Bag port, and rolls
   into its place in the Bag exactly like the balls do today (`_tube_launch` / `_roll_ball` / `_resort_bag`).
4. The lever swings back up.

## Flow B — a bonus Essence from any source (spell card, bottle, artifact, a power…) — no waiting for a spawn

1. The source item (the card, the bottle chip, the artifact) shoots an Essence up into the **top funnel** (an arc, behind the funnel's front wall at the end).
2. It falls through the machine (hidden behind the body), comes out into the **bottom funnel**, rolls down the glass tube, comes up out of the **Bag port**
   and rolls into the Bag at once. It does not wait for the next turn's spawn and does not touch the reels.
3. The tube holds a queue: several bonus Essence follow one another (≈0.15 s apart).

(Today those Essence wait hidden in the box until the next spawn: `_stash_flight` / `_pipe_step` / `_refund_flight`. That waiting goes away.)

## Rules and open questions (to confirm before wiring)

- Reels are 3 because the base draw is 3. A draw of 0–2 (Overload) leaves the other reels empty. A draw of more than 3 (artifacts, Attunement…): proposal =
  the reels show the first 3, the rest come out of the **top funnel** straight after the reels stop, as bonus Essence (flow B), so the machine never
  needs more than 3 reels.
- Effects that say "next turn" (e.g. Tailwind: gain 1 random Essence next turn) join the next spawn's draw (they are in `next_draw` already).
  Effects that give Essence *now* use flow B.
- The first draw of a fight (5 Essence): same lever + reels (3), the other 2 as flow-B Essence.
- Refunded Essence (a chant that gives some back, lens artifacts) are bonus Essence too → flow B.
- SFX (decided by the user, 2026-10-17): deliberately FEW sounds, the machine must not be noisy. Only: `sfx_lever_pull` (1 s, played once for the pull AND the return),
  the reel spin loop (2 s) and ONE `sfx_reel_stop` used for all three reels. No sounds for lamps, funnels, tube, bend or port: only the existing wooden ball
  sounds (roll / collide / hole / swap) when balls roll into the Bag. Do not add more.
- Layer order (z): bag/tube back, orb in tube, tube clamps/front, funnel back, orb, funnel front, machine body, reels, lamps, lever.

## Implemented (2026-10-17) — what the code does

- Art: `Slot_machine.pdf` -> `tools/export_slot_machine.py` (+ `tools/slot_pdf.py`) -> `assets/Puppet/UI/SlotMachine/slot_*.png` (2 x) and `scripts/ui/puppet_slot_machine.gd`
  (screen positions). Run it again after editing the PDF. The window well is painted dark by the exporter (the PDF has none); the port ring over the Essence is the second
  copy of the port picture; the lever's pulled place is a 90 deg clockwise turn about its hub.
- `SlotMachine` (scripts/ui/slot_machine.gd) builds two layers: `back` (tube, port hole) and `front` (funnels, cabinet, reels, lamps, lever, clamps, port ring); FightScreen puts
  the Essence (`_stock_row`) between them, so they hide behind the funnels and the cabinet, show in the tube and come up from under the ring.
- `FightScreen._puppet_launch`: spawn (turn start, first hand) = lever pull (`sfx_lever_pull`, one sound for pull and return) -> 2 s spin (`sfx_reel_stop` on each stop) ->
  the first three Essence drop out of the reels -> bottom funnel -> tube -> port -> roll to their places; any further Essence of the spawn and all bonus Essence use
  `_slot_route` (top funnel -> through the machine -> bottom funnel -> tube -> port). A bonus Essence flies from its source (`_bonus_from`: the card, the bottle, the chant slot
  of a refund) or pops up over the top funnel when the source is unknown. The machine waits while the HUD is still below the screen.
- "Next turn" Essence of a spell (`_stash_to_machine`): fly into the top funnel and stay in the machine. The reels show next turn's draw at rest (up to three,
  `_sync_reels`): the old globe's "what is coming" information is kept; blank reels if you prefer (remove the `_sync_reels` body).
- No other sounds: only `sfx_lever_pull`, `sfx_reel_stop` (a spin loop is not played) and the existing wooden ball sounds.
- Removed: the old globe/pipe/box machine code (`puppet_machine.gd`, `export_puppet_machine.py`); the old art in `UI/Machine/` is still there, unused.
- `tools/slot_shot.gd` takes frames of a spawn and of a bonus / stash Essence.
