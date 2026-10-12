# Puppet stage (Wild-West wooden puppet theatre): how it is built

Theme id `puppet` ("Puppet Stage"). `UiSkin.is_puppet()`; `is_circus()` is true for it as well (it reuses the Cirus UI). Asset lookup order:
`assets/ui/puppet/` -> `assets/ui/circus/` -> `assets/ui/new/`.

## The stage (`scripts/ui/puppet_stage.gd`)
All numbers are 1920 x 1080 design px (the stage stretches sideways on wider windows, `fit()`).
- Pieces drawn on perspective quads (homography grid): back wall, floor, left wall, right wall, lower floor. Their corners are the named
  points of `default_verts()` (hand-tuned in the running game; touching pieces share points; `_l` / `_r` are mirror images).
- Not tilted: the ceiling valance (`ceiling_overlay.png`, on the top of the screen at `CEILING_Z` = 100; the HUD line, artifacts and sign are raised
  above it) and the front wall (`front_wall.png`, upright, from the floor's front edge down).
- The scene (everything but the ceiling, sign and lower floor) is lowered by `SCENE_DY` (148) so that the front wall touches the lower floor.
- Scenery: placed by rule in `_place_props()`: feet on the seam between the back wall and the floor (plus a per-piece dy), always between the back wall's
  two edges; trees and grass rock from their base, clouds and sun slide, each casts a silhouette shadow. Hanging sign (`add_hanging_sign`) carries
  the Act / Floor / Turn text (`_info` of the fight screen).
- Enemies: `FightScreen._place_enemies()` puts their feet on the middle of the floor (`floor_center_y()`); `StageLights` adds a spotlight per enemy;
  `Creature` draws the puppet, its rocking and its slanted cast shadow.

## Pictures and how they are made
| Source | Tool | Result |
|---|---|---|
| `assets/Room Background/Puppet/Act 1/*.png` (git-ignored) | `tools/import_puppet_stage.py` | back_wall / wall_left / wall_right (cut from `All side*.png` with the perspective's width and the picture's whole height), floor, lower_floor, front_wall, ceiling_overlay, props/* |
| `assets/ui/puppet/asset.pdf` | `tools/export_puppet_art.py` | enemies/<enemy id>.png (square, feet on the bottom edge) |
| `assets/ui/puppet/Chant UI for puppet.pdf` | `tools/export_puppet_chant.py` | panels/*, buttons/*, `scripts/ui/puppet_layout.gd` |
Run the importers, then `Godot --headless --editor --quit` once.

## Art prompts (ImageSet)
`puppet_stage_backdrop_prompts_import.txt` (+ `puppet_stage_backdrop_style.txt`), `puppet_stage_props_prompts_import.txt` and
`puppet_stage_enemies_prompts_import.txt` (+ `puppet_stage_cutout_style.txt`), `puppet_lottery_machine_prompts_import.txt` (+ `_style.txt`).
Two styles because one "puppet theatre" style made the AI put creatures into the floors; cut-outs are described as sawn, hand-painted plywood with a
tan edge band and no drawn outline, on a pure white background; ImageSet's widest ratio is 21:9.

## Chant / Bag strips and the lottery-ball machine
See `docs/art_progress.md` (Puppet Stage theme) and `scripts/ui/fight_screen.gd` (`_build_strips_puppet`, `_sync_globe`, `_puppet_launch`,
`_stash_flight`, `_pipe_step`).

## Hand-over for layout work
`tools/export_stage_layers.gd` renders the fight screen layer by layer (transparent 2x PNG + layout.json); `tools/build_layout_pdf.py` makes a layered PDF,
`tools/build_layout_psd.py` a layered PSD (needs `psd-tools`).
