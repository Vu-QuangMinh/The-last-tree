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

**Housekeeping**
- `assets/Room Background/` (93 MB of 2048 px originals) is git-ignored; keep the sources outside the repo or in a release asset.
- Watch merges with Vu-QuangMinh: his commits are made from an older copy and have silently dropped this work before (card design, artifact slots, auto-cast). After every pull: diff against the last own commit.
