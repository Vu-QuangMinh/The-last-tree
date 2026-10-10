# Art / UI progress (New theme)

Source of truth for art: `assets/ui/Fight UI.pdf`, cut into `assets/ui/new/<folder>/` by `python tools/export_fight_ui.py`
(about 5 minutes; then `Godot --headless --editor --quit` to import). Last update: 2026-10-05.

## Done
**Fight UI and shared pieces**
- Pause board (3x3, 9-slice), Grimoire Ink ribbon and Toast Strip (3-slice), Legend Plate and Map Scroll (3-slice), wood frame (3x3).
- Amber Coin (80%), Seedling icon (HUD, Unlocks, menu, hint panels, tutorial), Redirect and Mend intent icons, all player status badges, Essence Frozen Overlay.
- Leaf sets (act 1: 10, act 3: 11 snow-dusted) in `BackdropFx`; act 3 snow dots replaced.
- The user's template SpellCard restored (merge with Vu-QuangMinh's anti-spell / ephemeral features), artifact slot art, auto-cast (incl. anti-spells and a lone enemy), chant button shows its base, essence glow when a chant builds towards a spell, Perfect word 30 px lower.
- Scroll bars: `ScrollThumb` (fixed-size painted thumb that rides the track), attached to every ScrollContainer by `main.gd`.
- Art folders: `assets/ui/new/` is sorted by what things are (`folder_for()` in the exporter; `UiSkin.path_of()` finds a name in any folder).

**Map and rooms**
- Map: painted rings + icons, visited = ring only, hero marker, ink path dots, painted scroll and legend; the sprout walks to the chosen room eating the path dots; the map opens scrolled to your room; merchant node uses the face avatar `map_icon_merchant`.
- Room backgrounds: `assets/Room Background/*.png` -> `python tools/import_room_backgrounds.py` -> `assets/ui/new/backgrounds/room_<id>.jpg` (16:9 crop, Y0 default 230). `Backdrop.room` is set by `main.gd` (`_room_bg`) for the elite arena, 3 bosses (by act), loadout, reward, defeat, merchant, empty hollow, campfire / fuse and the 14 events.
- Merchant: the big portrait stands above "Leave the shop".
- Picking up an artifact pops up its card (`RunState.artifact_gained` -> `main._on_artifact_found`).
- Campfire room (pages 9-10 of the PDF): `CampfireScreen`, `CampfireHot`, `CampfireFlame`, `CampfireSparks`, layout generated into `scripts/ui/campfire_layout.gd`. Forest wind + act-1 leaves, wriggling smoke, big/small flame blended by noise with ground light, random sparks (behind the sign), hover glow (half strength). Signboard reads CAMPFIRE / SEAL / FUSE / REST; first click selects (post rises out of the grass, second board shows what it does, post + object stay lit), second click confirms, click elsewhere cancels; the fire counts as part of SEAL. Positions and z come from the demo page automatically (move things in the PDF, re-run the exporter).

**Cirus (circus) theme** (Settings -> Theme -> "Cirus"; `UiSkin.is_circus()`; art in `assets/ui/circus/`, any name missing there falls back to `assets/ui/new/`)
- Art comes from the user's own PDFs: `assets/ui/Circus UI.pdf` -> `EXPORT_THEME=circus python tools/export_fight_ui.py` (about 10 min), then `tools/export_circus_banners.py` (Victory / Defeat / Perfect are ONE picture each; the `*_text` and `perfect_word` layers are transparent placeholders), `tools/export_circus_hp.py` (HP bar frame + fill mask + 3 swatches), `tools/prune_circus_art.py` (drops pieces identical to New), then `Godot --headless --editor --quit`. `assets/ui/circus/Chant UI for Circus.pdf` -> `tools/export_circus_chant.py` (writes `scripts/ui/chant_layout.gd`; boxes cached in `tools/.circus_chant_boxes.json`, which is not committed: delete it to re-measure, about 4 min). After any re-export check the log's "slice margins" lines: Cirus 9-slice margins differ from New and are picked by `is_circus()` in `UiTheme.panel_box`, `toasts.gd`, `UiSkin.frame_behind`, scroll / slider tracks. Delete the junk the exporter makes for Cirus (`misc/blank.png`, `panels/hp_fill.png`, `panels/banner_slam_world.png`, `campfire_decor_fire_big.png`).
- Chant + Bag strips (`_build_strips_circus`): Chant strip with Clear / Pass in fixed slots (Undo takes Clear's slot after the chant, Pass goes; the main button is 192 px and never moves, the strip stays 1100 x 118). Bag strip = one row of Essence plus the launcher tube (back layer, Essence, glass layer, gear, plate, crank handle). The crank turns once, the gear twice, Essence roll out left like billiard balls (whole turns, a tok on each stop, the previous ball rocks). The tube holds next turn's draw and replaces the "Coming next turn" panel: empty for 2 s after a launch, then new balls spawn INSIDE the red block and roll out one by one; a spell that gives Essence for next turn (Tailwind) flies in under the glass, hides in the red block, then rolls in (`_stash_flight`, `_sync_tube`). Only brand-new Essence roll (`_bag_seen`); the chant being cast is hidden from the bag (`_cast_uids`). Freeze / Hex / Invert / Steal effects wait for rolling to stop (`_rolls_done`). Sounds are synthesized: `tools/make_billiard_sfx.py` (`sfx_ball_clack`, `sfx_ball_roll`, `sfx_crank_ratchet`).
- HP bar from two painted objects (`HpBar._draw_full`: a mask shader clips red HP / blue Shield / grey missing HP to the painted fill shape), Shield as its own small badge beside HP (the label can no longer stretch the panel), bottles only the ones you carry (64 / 52 / 44 px by count) with the shared frame following them, no faint outlines.
- Smaller fixes made on the way: shop Leave button pinned bottom-right (a tall item used to push it off screen), the fight's lower block stays hidden until `_fit_bottom` has placed it (no first-frame jump), combat log clipped and white, toasts last 5 s and hold while hovered (5 s more after the mouse leaves), silenced / locked / used card states show the PDF's Card Overlay pictures, Lost Sprite / Bard show the card you learned, loadout title moved under the top bar, enemy panels shorter, Cirus backdrop has no wind shader, pause title dark on the cream board.
- Prompts for ImageSet (not used for the final art, the user drew it): `docs/circus_ui_art_prompts.txt` + `docs/circus_ui_art_style.txt` (76), `docs/circus_loadout_art_prompts.txt` (6).

## To do
**Art still missing**
- Backgrounds: Treasure Room, Screen Victory (they fall back to the act's picture).
- Treasure chest closed / open, Treasure Card Frame Cursed (prompts in `treasure_art_prompts.txt`).
- Icons per room (see `map_room_art_prompts.txt` for what is already drawn): Fuse screen (title flame, eye "See all", warning, wake, arrow), Merchant (cart for the title, price tag, Buy coin), event cost/reward glyphs (Max HP, Leaves, artifact, spell, Legendary, Cursed, purple resin), tutorial pointing hands + Sprout box, Elite / Boss badges, Resin icon (still drawn in code: `ResinIcon`).
- Other rooms are still plain screens over their backgrounds (campfire is the only one rebuilt from separate objects).

**Code**
- Step 2 of the emoji plan: headings / labels with emoji (fuse_screen, shop_screen "🛒", seal_screen, tutorial_screen, enemy_view skull, fight_screen close / undo / clear, settings play / stop, wiki map text). Needs a TextureRect beside the Label.
- The Default theme keeps the old text-button campfire (by design); artifact / bottle `icon` emoji fields stay as its fallback.
- Merchant text in ShopScreen still says "a badger", the art is a bearded man.
- Damage splat `float_damage` was dropped by Vu-QuangMinh ("no blood"): not restored.

**To check by eye (only still pictures were looked at)**
- Campfire: hover on the cauldron and the fire, flame / smoke / spark motion, the faint wood sliver under the CAMPFIRE board.
- Map walk animation (dots eaten along longer paths), scroll thumb on every screen, artifact pop-up in a real run, shop and menu after the Seedling change, act-3 leaf size.
- Room backgrounds: the crop (Y0) per picture may need tuning (the log along the bottom is cut off).

**Asking the artist**
- The demo page has a brown placeholder plank at the top centre: left out of the scene. What is it for?

**Cirus theme, still open**
- Still New-theme art in Cirus: artifact / bottle single slots (hover, charged, upgraded), close X, game title (green), intent / status / artifact / bottle icons, campfire and room scenes, map scroll rollers + legend plate + treasure card frame (still wood-brown in the PDF).
- Waiting for art: loadout zones and slot (`docs/circus_loadout_art_prompts.txt`: Active Spell Zone (+Lit), Spellbook Zone (+Lit), Spell Slot Empty / Hover): then wire into `loadout_screen.gd` (`_zone`, the empty slot Panel).
- Cooldown and Broken card states are still words (no overlay picture in the PDF). The Perfect banner has no flickering PERFECT word any more (the banners are single pictures).
- To check by eye / by ear (only still pictures and logs were checked): the whole tube sequence in motion, its sounds, toast hover, the creep waiting for Essence to stop rolling, Tailwind-style spells in a real fight.
- Gotchas: the exporter for Cirus takes about 10 min; `tools/export_fight_ui.py` now reads `EXPORT_THEME`; GDScript `sort_custom` is not stable (tie-break by index); a tween lambda with arguments after it needs `.bind()`; in bash tool calls an apostrophe inside a heredoc breaks the call (write the file with the editor tool instead); test runs: `Godot --path . --resolution 1920x1080 --position 6000,0 --no-focus -s tools/<script>.gd -- <out>` (a Minimized window renders blank frames); never kill Godot by name (the editor may be open): stop only the PID you started.

**Housekeeping**
- `assets/Room Background/` (93 MB of 2048 px originals) is git-ignored; keep the sources outside the repo or in a release asset.
- Watch merges with Vu-QuangMinh: his commits are made from an older copy and have silently dropped this work before (card design, artifact slots, auto-cast). After every pull: diff against the last own commit.
