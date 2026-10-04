# Art / UI progress (New theme)

Source of truth for art: `assets/ui/Fight UI.pdf`, cut into `assets/ui/new/` by `python tools/export_fight_ui.py`
(then `Godot --headless --editor --quit` to import). Last update: 2026-10-04.

## Done
- Pause board cut as 3x3 pieces and 9-sliced (margins 95/90/95/94); Grimoire Ink ribbon and Toast Strip cut as 3 pieces and 3-sliced.
- Amber Coin icon in the amber counter (replaces the leaf drawn in code).
- Status icons: Aegis, Echo Ready, Overload added; all player status badges use art.
- Leaf sets: act 1 (10 leaves) and act 3 (11 snow-dusted leaves) in `BackdropFx`; act 3 snow dots replaced.
- Essence Frozen Overlay on frozen essence (replaces the code-drawn ice).
- Seed of Life / Broken Seed of Life art (treasure, artifact bar, shop), Seedling icon (HUD, Unlocks, menu), Redirect intent icon.
- Items 1-4 audit (artifacts 39/39, bottles 20/20, intents 19/19 + Redirect, statuses): nothing missing.
- Exporter: `near` gather mode, 3x3 grid join, label splitting, tight grouping for bottles, leaf-set export, slice-margin printout.

## To do
- Treasure Card Frame Cursed (prompt only in `treasure_art_prompts.txt`), treasure chest closed/open, map node treasure.
- Step 3: map room icons (fight, elite, campfire, treasure, merchant, unknown, boss) in `map_screen.gd` and the wiki "The map" text; no art or prompts yet.
- Step 2: headings/labels still using emoji (fuse_screen, shop_screen, seal_screen, tutorial_coach, tutorial_screen, enemy_view skull, fight_screen Sprout/close/undo/clear, settings play/stop). Needs a TextureRect beside the Label; new art for Fuse, Merchant cart, skull, pointing hands.
- Artifact/bottle `icon` emoji fields remain as Default-theme fallbacks (by design).
- `docs/missing_item_prompts.txt` prompts for Seed of Life, Broken Seed, Aegis, Echo Ready, Overload, Redirect are now drawn: can be retired.
- Not checked visually: shop screen and main menu after the Seedling icon change, act 3 leaf size after raising it to 48 px, motion of leaves.
