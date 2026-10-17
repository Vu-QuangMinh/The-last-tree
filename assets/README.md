# assets/

Two looks, one shared folder. `New/` and `Puppet/` have exactly the same shape, so a piece of art for one theme has a twin spot in the other;
`Global/` is for everything both themes use. Folders that are still empty hold a `.gitkeep`: copy the art in and delete it.

```
assets/
  Global/            used by both themes
    Card/Icons   element / rarity / kind pips        Card/Shaders   card and fight shaders
    Fonts/           every font so far (a theme can override one by putting a file of the same name in its own Fonts/)
    Icon/Element/    the Fire / Water / Wind / Any glyphs used inside rich text
    Music/{boss,fight,map,menu}                       SFX/   sounds both themes use           UI/   shared pieces (empty so far)
  New/  and  Puppet/   (same inside)
    Card/            card frames, overlays, kind / rarity pieces, wax seal;   Card/Treasure/  treasure card frame + tier medals
    Enemies/Act1..3/ enemy pictures (Puppet: <enemy id>.png, one cut-out each; New: ashling_<face>.webp...)   Enemies/_Source/  raw pictures
    Fonts/           this theme's own fonts
    Icon/            Artifact/ (<id>.png)   Bottle/ (<id>.png)   Effect/ (buffs AND debuffs: status_*)   Intent/ (intent_*: what an enemy will do)
    Map/             map rings, icons, path dot, scroll, legend plate;
      Rooms/Backgrounds   one 16:9 picture per room / event / screen (room_*.jpg)
      Rooms/Campfire      the layers of the campfire room        Rooms/Apothecary   the layers of the Wandering Apothecary
    SFX/             this theme's own sounds (Puppet: the wooden balls)
    Stage/Act1..3/   Backdrop/ (the back wall or the act's painting)   Wall/ (side walls, front wall)   Floor/ (floor, lower floor)
                     Ceiling/   Props/ (clouds, trees, mountains...)   Fx/ (falling leaves...)   _Source/ (raw pictures: not imported)
    Stage/Shared/    pieces the same in every act (the hanging sign)
    UI/              Panels/ (frames, slots, scroll bars, toasts)   Buttons/   Hp/ (the HP bar, or the HP blocks and their tray)
                     Machine/ (the orb launcher: globe, pipe, tube, box)   Hint/ (the Seedling's hint panel)   Numbers/   Banners/ (Victory,
                     Defeat, game title)   Essence/ (the orbs)   Icons/ (heart, shield, coin, seedling)   Fx/   Characters/   Misc/
  _Archive/Circus    the Cirus theme, taken out of the game (a .gdignore keeps Godot from importing it): delete it when you are sure
```

Folders called `_Source` (raw PDFs, PSDs and big pictures) carry a `.gdignore`: Godot does not import them, the `tools/` scripts read them.
The very big ones are ignored by git (see `.gitignore`).

## How the game finds things

- **UI art is found by name**, not by path (`UiSkin.tex("button_chant_normal")`): it looks in the theme folder first, then `New/` (Puppet only: a
  Puppet piece that is not drawn yet shows the New one), then `Global/`, in the sub-folders listed in `UiSkin.FOLDERS`. So a picture can be moved
  between those sub-folders freely; just keep names unique inside a theme. A new sub-folder must be added to `UiSkin.FOLDERS`.
- **Enemies**: `Creature.enemy_path()` looks in `<theme>/Enemies/Act<its act>/`, then the other acts.
- **Stage** (Puppet): `PuppetStage` takes the act's pictures from `Stage/Act<n>/...`; an act that has none yet uses Act 1's.
- **Sounds**: `<theme>/SFX/<name>.wav` first, then `Global/SFX/<name>.wav`. **Fonts**: `<theme>/Fonts/<file>` first, then `Global/Fonts/`.
- After copying new files in, run Godot once (`--headless --editor --quit`, or just open the editor) so it imports them.
- The exporters in `tools/` (`export_fight_ui.py`, `export_puppet_*.py`, `import_puppet_*.py`, `import_room_backgrounds.py`...) write to these
  folders through `tools/asset_paths.py`.

## Not in the structure yet (suggestions)

- `Global/Fx/` (particle and impact textures), `Global/Shaders/` (the shaders are under Card/Shaders because the cards use them most).
- `<theme>/UI/Title/` (logo and main-menu picture; today the game title lives in UI/Banners), `<theme>/UI/Cursor/` (the aiming cursor is drawn in code).
- `<theme>/Music/` if a theme gets its own tracks (music is Global for now).
- `<theme>/Map/Rooms/Shop`, `Boss` ... when a room gets its own set of layers like the campfire.
- Per-rarity card frames: `<theme>/Card/Frame/` once you add them (the card currently draws its frame in code).
