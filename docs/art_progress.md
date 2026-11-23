# Art / UI: what is still to do

The record of what was done is `docs/changelog/` (one file per month, newest entry on top). This file only holds open items.
Art pipeline: ImageSet (prompts/styles live next to the art in `assets/**`), Tachnen cut at full size, importers in `tools/` (see `tools/README.md`). Never resize art.

## Art still missing
- Backgrounds: Treasure Room, Screen Victory (they fall back to the act's picture).
- Treasure chest closed / open, Treasure Card Frame Cursed (prompts in `treasure_art_prompts.txt`).
- Icons per room (see `map_room_art_prompts.txt` for what is already drawn): Fuse screen (title flame, eye "See all", warning, wake, arrow), Merchant (cart for the title, price tag, Buy coin), event cost/reward glyphs (Max HP, Leaves, artifact, spell, Legendary, Cursed, purple resin), tutorial pointing hands + Sprout box, Elite / Boss badges, Resin icon (no icon yet).
- Other rooms are still plain screens over their backgrounds (campfire is the only one rebuilt from separate objects).

## Code
- Fairy (Lost Sprite event): art and voice read female, text says "he / Help him" (`map_events.gd`, key in `event_stage.gd` + tests): pick one.
- Old unused 512 px `Enemies/Act2/briar_wall_{left,right}.png` and `Act1/briar_wall_right.png`: can be deleted.
- Step 2 of the emoji plan: headings / labels with emoji (fuse_screen, shop_screen "🛒", seal_screen, tutorial_screen, enemy_view skull, fight_screen close / undo / clear, settings play / stop, wiki map text). Needs a TextureRect beside the Label.
- Merchant text in ShopScreen still says "a badger", the art is a bearded man.
- Damage splat `float_damage` was dropped by Vu-QuangMinh ("no blood"): not restored.

## To check by eye
- Campfire: hover on the cauldron and the fire, flame / smoke / spark motion, the faint wood sliver under the CAMPFIRE board.
- Map walk animation (dots eaten along longer paths), scroll thumb on every screen, artifact pop-up in a real run, shop and menu after the Seedling change, act-3 leaf size.
- Room backgrounds: the crop (Y0) per picture may need tuning (the log along the bottom is cut off).

## Asking the artist
- The demo page has a brown placeholder plank at the top centre: left out of the scene. What is it for?

## Housekeeping
- `assets/Room Background/` (93 MB of 2048 px originals) is git-ignored; keep the sources outside the repo or in a release asset.
- Watch merges with Vu-QuangMinh: his commits are made from an older copy and have silently dropped this work before (card design, artifact slots, auto-cast). After every pull: diff against the last own commit.

