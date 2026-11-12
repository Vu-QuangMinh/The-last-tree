# tools/

Scripts that build, check and photograph the game. Python = art / sound pipelines and importers; Godot `.gd` = checks, simulations, screenshots.
Python deps: `tools/requirements.txt` (nothing is installed by the repo; use the Python of the app that owns the job: Tachnen's `.venv` for cutting, ReadAnyBook's `rvc_env` for voices).

## Conventions
1. A tool that reads outside this repo takes the folder from `paths.py` (Tachnen, ImageSet code, ImageSet output on E:, AnySFX, ReadAnyBook; each can be moved with an environment variable `BTC_*`). A tool that writes into `assets/` goes through `asset_paths.py`.
2. No `.resize(` / `.thumbnail(` on art. If a small reference picture is really needed, say so in the docstring and write it to a `_Refs` folder.
3. Godot scripts: `x.gd` is a 5-line wrapper, the work is in `x_impl.gd` (loaded after the autoloads exist). Always `quit()` at the end and start a `create_timer(60..240).timeout.connect(quit)` guard. Windowed ones run with `--position 6000,0 --no-focus --audio-driver Dummy`.
4. Run once, then done: name it `make_*` / `import_*` and put the date in its docstring.

## Decision: the ~120 Godot wrappers are not merged into one
The `_impl` scripts read `OS.get_cmdline_user_args()[0]` as their output path; one shared wrapper would have to pass parameters and every impl would change. Not worth it.

## Index
`kind`: `lib` = imported by other tools, `pipeline` = named in CLAUDE.md / assets/README.md / art_progress / changelog as a way to rebuild art, `one-off` = a batch that already ran (kept for reference), `check` = Godot script. `status`: `hard-coded paths` = still has a machine path in its code (older than 2026-11-01 ones were not moved to `paths.py`).

| file | kind | what it does | status |
|---|---|---|---|
| alpha_bleed.py | lib | 2026-11-10: no white outline on cut-out sprites. A sprite cut on a white page has WHITE colour in its transparent pixels and a white-ish matte in i... | live |
| asset_paths.py | lib | Where the exporters / importers put art now that assets/ is split into Global / New / Puppet (see assets/README.md). Every theme folder has the sam... | live |
| auto_rig_probe.py | one-off |  | live |
| build_layout_pdf.py | pipeline | Puppet Stage fight screen -> a layered PDF to edit the layout on (docs/puppet_fight_layout.pdf). Step 1 (Godot, renders each layer as a transparent... | live |
| build_layout_psd.py | pipeline | The layer PNGs of docs/puppet_fight_layout_layers/ -> docs/puppet_fight_layout.psd (one real Photoshop layer each, 3840 x 2160, bottom layer first)... | live |
| cut_dialogue_panel.py | one-off | Puppet Stage theme: the events' dialogue box, painted by ImageSet (set "Puppet Dialogue", prompts in assets/Puppet/UI/Panels/dialogue_prompts.txt +... | live |
| cut_frame_art.py | one-off | The frames painted by tools/make_frame_art.py (ImageSet's output folders "Puppet Frames Wide" / "Puppet Frames Round") -> assets/Puppet/UI/Panels/f... | live |
| defringe_edge.py | one-off | Edge colour sampling (2026-11-11): the cut-out's edge pixels carry light specks from the background removal. Every pixel of the edge band (the oute... | live |
| export_dragon2_rig.py | pipeline | Winter Wyvern rig (2026-10-28), from the user's Dragon2/Dragon.pdf (frost dragon drawn as separate pieces: head, jaw, throat, neck, body, open wing... | live |
| export_fight_ui.py | pipeline | Cuts the objects of assets/New/_Source/Fight UI.pdf into game-sized PNGs in assets/New/ (the "New" theme: UI, Icon, Card, Map, Stage...). Run: pyth... | live |
| export_handyman_face.py | pipeline | The Handyman's two faces: assets/Puppet/Enemies/Act1/handyman/Face.pdf holds his body twice (smiling, and crying). The smiling one is the same body... | live |
| export_handyman_rig.py | pipeline | The Handyman, as a rig: page 2 of assets/Puppet/Enemies/Act1/handyman/Handyman.pdf -> his body and six two-bone arms. The page holds six arms laid... | live |
| export_hp_bar.py | pipeline | Puppet Stage theme: the candy-cane HP bar of page 2 of assets/Puppet/_Source/Chant UI for puppet.pdf (page = 1920 x 1080 = the screen). The page dr... | live |
| export_hud2_art.py | pipeline | Theme "Puppet HUD ver 2": the pieces the user cut himself in assets/Puppet/UI/Hud2/Puppet HUD Nov.pdf (page 2 = the assembled screen, 2048 x 1152 p... | live |
| export_lever.py | one-off | Puppet Stage: the lever of the slot machine as page 2 of assets/Puppet/_Source/Chant UI for puppet.pdf draws it (right of the machine, side view).... | live |
| export_minhhud_frames.py | one-off | MinhHUD.pdf -> one flat "frame" picture per part (the layout the user drew: shape, proportions, where the sockets are), padded to the ratio of the... | live |
| export_new_ui_art.py | one-off | New UI theme: the HUD pieces painted in page 2 of assets/Puppet/_Source/Chant UI for puppet.pdf -> assets/Puppet/UI/NewUi/*.png (and the straight t... | live |
| export_puppet_art.py | pipeline | Puppet Stage puppets -> game files: assets/Puppet/_Source/asset.pdf (vector sheet of the Act 1 puppets; its sun, clouds, trees and mountains are no... | live |
| export_puppet_bars.py | pipeline | Puppet Stage theme: the Chant bar, the Bag bar, their buttons and the three Essence balls of assets/Puppet/_Source/Chant UI for puppet.pdf. Cuts, a... | live |
| export_puppet_chant.py | pipeline | Puppet Stage theme: the Chant strip, the Bag strip and the lottery-ball machine of assets/Puppet/_Source/Chant UI for puppet.pdf. Cuts, at the game... | live |
| export_puppet_hud.py | pipeline | Puppet Stage theme: the whole bottom HUD of assets/Puppet/_Source/Chant UI for puppet.pdf (a 1920 x 1080 page, 1 pt = 1 design px). Cuts into asset... | live |
| export_room_background.py | lib | Cuts assets/New/Map/Rooms/_Source/Room Background.pdf (one page per room; so far the Wandering Apothecary) into assets/New/Map/Rooms/Apothecary/<ro... | live |
| export_room_results.py | one-off | Page 2 of assets/New/Map/Rooms/_Source/Room Background.pdf: the pictures shown after a room's choice (so far the Wandering Apothecary: Snatch, Walk... | live |
| export_samurai_rig.py | one-off | The Samurai and his Retainer (2026-10-29), from the user's Act2/samurai/animation.pdf (ONE huge page, 23 distinct pictures placed again and again).... | live |
| export_slot_boards.py | one-off | Puppet Stage theme: the cream slot frame (Bottle Slot / Artifact Slot) of page 2 of assets/Puppet/_Source/Chant UI for puppet.pdf (page = 1920 x 10... | live |
| export_slot_machine.py | pipeline | Puppet Stage: the new Essence machine ("slot machine") of assets/Puppet/_Source/Slot_machine.pdf. The page is 1920 x 1080 pt = the screen, so every... | live |
| export_top_hud.py | pipeline | Puppet Stage theme: the TOP HUD of assets/Puppet/_Source/Chant UI for puppet.pdf (page = 1920 x 1080 = the screen, 1 pt = 1 design px). One wide fr... | live |
| export_ui_pdf.py | one-off | Exports a theme's fight HUD as a layered PDF (page 1 = the HUD parts placed where the game draws them, 1920 x 1080 pt, every picture its own named... | live |
| extract_newui2_pdf.py | pipeline | NewUI Ver2: takes the pictures the user placed in assets/Puppet/UI/NewUiV2/HUD.pdf (page 1 = the HUD layout, page 2 = the notes) out of the PDF AT... | live |
| extract_pianist_pdf.py | pipeline | 2026-11-10: reads the user's rig layout, assets/Puppet/Enemies/Act2/pianist/Pianist.pdf, and writes what the game needs: - the pictures of its piec... | hard-coded paths |
| gemini_star.py | lib | Takes the Gemini star (the little four-point watermark in the bottom-right corner) OUT of a picture by reversing its alpha blend, the way GeminiWat... | live |
| gen_boss_art.py | pipeline | 2026-11-08: generate the RAW pictures (ImageSet / Gemini) for the new Act 2 bosses and mobs and the Pianist's pieces. Only generates; tools/import_... | live |
| import_act1_fix.py | one-off | Act 1 enemy redo (2026-10-17): ImageSet's "Act 1 Enemies Fix" pictures -> assets/Puppet/Enemies/Act1/<enemy id>.png at FULL size. | hard-coded paths |
| import_act2_mobs.py | pipeline | Act 2 mob enemies (2026-11-06): ImageSet's "Act 2 Mobs" pictures -> assets/Puppet/Enemies/Act2/<enemy id>.png at FULL size. | live |
| import_boss_art.py | pipeline | 2026-11-08: cut + place the raw ImageSet pictures of the new Act 2 enemies and the Pianist's pieces (made by tools/gen_boss_art.py). bosses : Rot S... | live |
| import_event_art.py | lib | Event art (2026-11-01): ImageSet's "Puppet Events" pictures -> assets/Puppet/Events/<name>.png at FULL size. | live |
| import_fire_dragon.py | one-off | Effect pictures of the Winter Wyvern (Act 3 mini boss), 2026-10-27: ImageSet's set "Fire Dragon" (prompts + style: Act3/fire_dragon_{prompts,style}... | hard-coded paths |
| import_handyman_arrow.py | one-off | The Crossbow Hand's arrow: assets/Puppet/Enemies/Act1/handyman/Gemini_Generated_Image_*.png (newest) -> handyman/arrow.png. The white background is... | hard-coded paths |
| import_hud2_art.py | pipeline | Puppet HUD ver 2: ImageSet's raw pictures (tools/make_hud2_art.py) -> assets/Puppet/UI/Hud2/*.png. The background is cut with Tachnen's BiRefNet (r... | live |
| import_minhhud_art.py | one-off | Theme MinhHUD: ImageSet's raw pictures (tools/make_minhhud_art.py, sets "MinhHUD v3 ...") -> assets/Puppet/UI/MinhHUD/minhhud_*.png. The background... | live |
| import_misc_batch.py | pipeline | Puppet Stage, the 2026-10-14 batch of small art made with ImageSet (sets "Puppet Misc Icons 2", "Puppet Essence Unknown", "Puppet Slot Strips", "Pu... | hard-coded paths |
| import_new_ui_frames.py | one-off | New UI theme: ImageSet's raw frames (tools/make_new_ui_frames.py) -> the game-ready PNGs in assets/Puppet/UI/NewUi/ (lookup names nu_*). The white... | hard-coded paths |
| import_newui2_art.py | lib | Theme NewUI Ver2 ("newui2"): ImageSet's pictures (tools/make_newui_cabinet_art.py, sets "NewUI Cabinet <ratio>") -> assets/Puppet/UI/NewUiV2/<the N... | live |
| import_newui2_buttons.py | one-off | NewUI Ver2: ImageSet's buttons (tools/make_newui_buttons.py) -> assets/Puppet/UI/NewUiV2/button_<kind>_<state>.png. Cut with Tachnen (+ the solid-p... | live |
| import_newui2_plates.py | one-off | NewUI Ver2: ImageSet's plates (tools/make_newui_plates_art.py, sets "NewUI Plates <ratio>") -> assets/Puppet/UI/NewUiV2/. Cut with Tachnen (BiRefNe... | live |
| import_newui2_sheet.py | pipeline | NewUI Ver2: the user's sheet assets/Puppet/UI/NewUiV2/Buttons.png (4 columns Chant / Release / Clear / Pass, 3 rows Normal / Hover / Pressed, on bl... | live |
| import_pianist_frames.py | pipeline | 2026-11-10: the 12 frames of the Pianist's right hand (the user's hand-edited cut-outs, 1024 px, in right_hand_frames/source/No-piano) -> game spri... | hard-coded paths |
| import_puppet_enemies.py | lib | Puppet Stage enemies: assets/Puppet/Enemies/_Source/Act<n>/Puppet <Name>.png -> assets/Puppet/Enemies/Act<n>/<enemy id>.png (n = the first argument... | live |
| import_puppet_stage.py | pipeline | Puppet Stage pictures: assets/Puppet/Stage/Act<n>/_Source/*.png -> assets/Puppet/Stage/Act<n>/{Backdrop,Wall,Floor,Ceiling,Props}/ in the shape the... | live |
| import_puppet_ui.py | lib | Puppet Stage UI pieces: ImageSet's raw 2048 px pictures -> the small game-ready PNGs in assets/Puppet/UI/<folder>/. | live |
| import_room_backgrounds.py | pipeline | Turns the square 2048 px room backgrounds in assets/New/Map/Rooms/_Source/ into 16:9 game backgrounds assets/New/Map/Rooms/Backgrounds/room_<id>.jp... | live |
| import_underwater.py | one-off | The underwater stage and the fish of Elemental Fishing (2026-11-01), from ImageSet: set "Puppet Underwater Props" -> assets/Puppet/Stage/Act4/Props... | live |
| import_veiled_eyes.py | one-off | The Veiled Eyes (Act 2 boss, 2026-10-19): the user's cut pictures in Enemies/Act2/Veiled Eyes/ -> square canvases, bottom-aligned, in Enemies/Act2/... | live |
| loudness.py | lib | Make a recorded line (numpy array, samples x channels, float -1..1) louder without clipping: a gentle compressor (the loud syllables and the laughs... | live |
| make_act2_mob_sfx.py | pipeline | Sounds for the Act 2 mob fights (2026-11-06), cut from the Sonniss GDC libraries (E:\Soniss SFX) into assets/Puppet/SFX (44.1 kHz stereo, 16 bit).... | live |
| make_act2_mob_sfx_ai.py | pipeline | Act 2 mob sounds AnySFX made (2026-11-06; Soniss had nothing good): sfx_sentinel_wake, sfx_lamp_glow, sfx_stun_apply into assets/Puppet/SFX/ (4 can... | live |
| make_act2_redo.py | pipeline | 2026-11-11 redo of 10 Act 1/2 puppets (user's list): Headless Horseman (rearing horse, head in one hand, sabre in the other) + the same with the he... | live |
| make_act3_enemies.py | pipeline | Puppet Stage, Act 3 enemies, from the prompt + style files in assets/Puppet/Enemies/Act3/ (act3_enemies_prompts.txt, act3_enemies_style.txt): 1. Im... | hard-coded paths |
| make_billiard_sfx.py | pipeline | Synthesize the Cirus bag launcher's sounds into assets/Global/SFX/: - sfx_ball_clack: two billiard balls knocking (a very short, bright, hard "tok"... | live |
| make_boss_sfx_ai.py | pipeline | 2026-11-08: the sounds of the new Act 2 enemies, made with AnySFX (4 candidates each in SFX/_Candidates, the best by score is written to assets/Pup... | live |
| make_boss_voice.py | one-off | A boss's spoken lines (the boss's replies of scripts/core/boss_talk.gd) by Google Gemini TTS (the keys of the AnyVideo app's settings.json) into as... | live |
| make_cart_items.py | one-off | 2026-11-11: the merchant's cart redrawn from the user's sketch (Merchant/_Redo/cart_sketch.png) in the game's style, then split into: the cart WITH... | live |
| make_coin_box.py | one-off | 2026-11-11: the wooden savings box (coin slot on top, a blank cream label on the front where the Leaves number is written) that replaces the leathe... | live |
| make_dialogue_board.py | one-off | 2026-11-11: one plain cream dialogue board (light ivory card, thin honey-wood rim) for every dialogue box (events, boss talk, the merchant): it is... | live |
| make_essence_orbs.py | pipeline | Puppet Stage, the three Essence orbs (fire / water / wind) redone with the symbols standing up in raised brass relief on the ball, like the Air Emb... | hard-coded paths |
| make_event_merchant.py | one-off | The merchant of the Ruined Watchtower (2026-11-02): the whole group of the shop (the merchant, his cart and both wheels), put together the way Shop... | live |
| make_event_sfx2.py | pipeline | Small sounds for the older "?" events (2026-11-01), made from scratch (numpy) into assets/Puppet/SFX/: event_pop (a mushroom plops off), event_glas... | live |
| make_event_sfx3.py | pipeline | Event sounds redone with AnySFX (2026-11-02), in assets/Puppet/SFX/ (4 variants each kept in _Candidates, the best by make_spell_sfx's score is ins... | live |
| make_event_voice.py | pipeline | The voices of the "?" events (the Turtle, the Farmer, the priest of Church of Aole, the Wax Witch, the Rolling Bear, the pond spirit, the boy of th... | live |
| make_fish_sfx.py | one-off | Elemental Fishing sounds cut from the Sonniss libraries (E:\Soniss SFX), into assets/Puppet/SFX (2026-11-02): fish_spear_small / _medium / _big a c... | live |
| make_foot_frames.py | pipeline | 2026-11-09: frames of the Pianist's LEFT FOOT playing, from the Muse clip pianist_foot_A.mp4; ImageSet (Gemini) isolates the LEG alone on white (no... | hard-coded paths |
| make_frame_art.py | one-off | The frames that used to be drawn in code (speech bubbles, callouts, help and tutorial boards, pills, empty card slots, round sockets), painted by I... | live |
| make_fusion_names.py | one-off |  | live |
| make_game_title.py | pipeline | The Puppet Stage main menu title "Who is The Puppet": docs/_ref/title_reference.png (the user's lettering: black letters on grey) -> every letter b... | live |
| make_hammer_sfx.py | one-off | Synthesize the Hammer Hand's sounds into assets/Global/SFX/: - sfx_hammer_thump: a fist-on-a-door thump (low body resonance + a short wooden knock)... | live |
| make_hud2_art.py | pipeline | Puppet HUD ver 2: the pieces the page of "Puppet HUD Nov.pdf" asks to be made (round button, plate button, Essence tray, Essence hole), made by Ima... | live |
| make_letter_metrics.py | one-off | Measures the wooden alphabet in assets/Puppet/Fonts/Letters (full-size cut pictures upper_A.png / lower_a.png) and writes scripts/ui/letter_metrics... | live |
| make_merchant_dialogue_voice.py | one-off | Voices every line the merchant says in his favours (scripts/core/merchant_quests.gd) with Google Gemini TTS, the same voice as his greeting. | live |
| make_merchant_voice.py | lib | The merchant's greeting, spoken by Google Gemini TTS (the keys of the AnyVideo app's settings.json), into assets/Puppet/SFX/_Candidates/merchant_vo... | hard-coded paths |
| make_minhhud_art.py | one-off | Theme MinhHUD: sprites made by ImageSet from assets/Puppet/UI/MinhHUD/minhhud_prompts.txt (+ _pressed) and minhhud_style.txt. Read the layout from... | live |
| make_minhhud_cabinet.py | one-off | Theme MinhHUD: the artifact cabinet v2 (and, with the argument "bottle", the bottle cabinet in the same style: 1:1, layout = the existing bottle ca... | live |
| make_minhhud_tray.py | one-off | Theme MinhHUD: bottle trays (NOT a cabinet), 3 options each for a tray of 3 and a tray of 5 sockets, in the style of the approved artifact cabinet... | live |
| make_missing_icons.py | lib | Puppet Stage, the icons found missing by tools/icon_audit.gd (2026-10-18), made with ImageSet from the prompt + style files that sit beside the art... | live |
| make_muse_arm_input.py | one-off | 2026-11-09: the input picture for MuseSet's arm clips: the user's sample (pianist seen from behind, teal background, markers "1" and "10") with the... | live |
| make_muse_arm_spec.py | one-off | 2026-11-09: spec for MuseSet --multi: 3 clips of the Pianist's arm sweeping along the keyboard from position 1 to 10 (one per Muse account). python... | hard-coded paths |
| make_muse_arm_spec_v2.py | one-off | 2026-11-09 (second try): MuseSet --multi spec, the arm with the PURPLE LINE picture: the arm goes to the label 10 first, then slides left along the... | hard-coded paths |
| make_muse_arm_spec_v3.py | one-off | 2026-11-09 (third try): MuseSet --multi spec with the WHOLE scene (the pianist seen from behind at the grand piano, white background): only his RIG... | hard-coded paths |
| make_muse_arm_spec_v4.py | one-off | 2026-11-09 (fourth try): MuseSet --multi spec, TWO sets of 3 clips; the right hand plays EVERY key from the first key at the far LEFT to the last k... | hard-coded paths |
| make_muse_foot_spec.py | one-off | 2026-11-09: MuseSet --multi spec: the Pianist's LEFT FOOT plays the keyboard, from the lowest key (far left) to the highest keys (far right), 3 cli... | hard-coded paths |
| make_muse_set2_input.py | one-off | 2026-11-09: input picture for MuseSet "set 2": the grand piano ALONE (the clean piano_1 picture aligned onto the user's scene picture) plus the rig... | hard-coded paths |
| make_new_ui_frames.py | one-off | New UI theme: the thin iron-rimmed frames of the HUD (page 2 of "Chant UI for puppet.pdf"), made by ImageSet from assets/Puppet/UI/NewUi/new_ui_pro... | hard-coded paths |
| make_newui_buttons.py | pipeline | NewUI Ver2 buttons made from DESCRIPTION ONLY (no reference pictures: they washed the details out): Chant + Release (red, same description, only th... | live |
| make_newui_cabinet_art.py | one-off | Theme New UI redone in the style of the approved artifact cabinet v2 (circus showcase: walnut, brass, red velvet, red lacquer + gold scrollwork). S... | live |
| make_newui_plates_art.py | one-off | NewUI Ver2, the background plates the user cut out in assets/Puppet/UI/NewUiV2/HUD.pdf (page 2: five flat shapes) redone in the cabinet's style + t... | live |
| make_props.py | one-off | 2026-11-11: coin purse (a flat panel for the number), the merchant's "!" sign, one rarity corner each for Rare (green) and Legendary (gold) (the ot... | live |
| make_props2.py | one-off | 2026-11-11 pass 2: redo the merchant's "!" (ONE dot only), a "?" sign, the Water and Fire emblems (flat front view like the Wind emblem) and a 2-ti... | live |
| make_recycler_voice.py | one-off | The Recycler's two lines, spoken by Google Gemini TTS (the keys of the AnyVideo app's settings.json) -> assets/Puppet/SFX/recycler_reuse.wav / recy... | live |
| make_redo2.py | lib | 2026-11-11 second redo: Tree Dweller (clearer people, fuller crown), the stun star icon, and the NewUI Ver2 menu panels + buttons in the HUD's look... | live |
| make_redo3.py | one-off | 2026-11-11 third redo: REAL buttons for NewUI Ver2 (raised normal + pressed, five kinds; hover is the normal picture made lighter in code) and a sq... | live |
| make_redo4.py | one-off | 2026-11-11: the tick box and the check mark of NewUI Ver2 (Settings), ImageSet -> Gemini star reversed -> key cut (never scaled), into UI/NewUiV2/n... | live |
| make_redo4b.py | one-off | The Ver2 check mark again, alone on black (the first one came with a painted plate behind it). See make_redo4.py. | live |
| make_redo5.py | one-off | 2026-11-11: every bottle icon redone so its SHAPE shows its effect (Healing Tonic = clear red water, Echo Draught = a bell, Frost Phial = a snowfla... | live |
| make_redo6.py | one-off | 2026-11-11 second pass on nine bottles (Aegis Elixir = a medieval shield, Thorn Oil = a thorny branch, Purifying Water = a lotus, Liquid Fire = lav... | live |
| make_result_sfx.py | one-off | The end-of-fight sounds, cut from the Sonniss GDC libraries (E:\Soniss SFX) into assets/Puppet/SFX (44.1 kHz stereo, 16 bit). | live |
| make_right_hand_frames.py | pipeline | 2026-11-09: 12 frames of the Pianist playing with his RIGHT hand: cut from the Muse clip pianist_set1_A.mp4, then ImageSet (Gemini) edits each one:... | hard-coded paths |
| make_right_hand_nopiano.py | one-off | 2026-11-10: ImageSet (Gemini) removes ONLY the piano from the 12 right-hand frames (pianist/right_hand_frames/source/frame_NN.png, 720 px squares)... | hard-coded paths |
| make_rope_tile.py | one-off | Raw ImageSet picture of a straight vertical rope -> assets/Puppet/Map/map_rope.png, a tile that repeats seamlessly along its length (the game tiles... | live |
| make_shop_sfx.py | lib | The merchant's sounds, cut from the Sonniss GDC libraries (E:\Soniss SFX) into assets/Puppet/SFX (44.1 kHz stereo, 16 bit). | live |
| make_spell_sfx.py | lib | Sounds of what spells DO (Burn, Shield, Repaint ...), made with AnySFX (Stable Audio Open) from the short prompts in tools/spell_sfx_prompts.py (FX). | hard-coded paths |
| orphan_art_report.py | one-off | Orphan art report: every picture / sound under assets/ whose file name (or stem) appears nowhere in scripts/, tools/, tests/ or data/. REVIEW LIST... | live |
| paths.py | lib | Where the sister projects live on this machine. Every tool that reaches outside this repo imports these names; set the environment variable to poin... | hard-coded paths |
| pianist_flow_crop.py | pipeline | Crops the Pianist out of the frames tools/pianist_flow.gd writes and lays them out in one sheet: python tools/pianist_flow_crop.py <folder> [names...] | live |
| pianist_sign_crop.py | pipeline | Lays the stills of tools/pianist_sign_flow.gd out in one sheet: python tools/pianist_sign_crop.py <folder> | live |
| render_pianist.py | lib | The Pianist's two pieces, from public-domain MIDI (the Mutopia Project): Turkish March (Mozart, KV 331, Rondo alla Turca, Mutopia piece 108) and Fu... | live |
| set_icon_mipmaps.py | one-off | Turns mipmaps on in the .import files of the full-size icons (Icon/Bottle, Icon/Artifact seed_of_life): they are drawn at 28-150 px from 1000+ px p... | live |
| slot_pdf.py | lib | Helpers to take the pieces of assets/Puppet/_Source/Slot_machine.pdf apart (used by export_slot_machine.py). The page is 1920 x 1080 pt = the game'... | live |
| spell_report.py | one-off | Validate data/spells.json (chant patterns, v3) and render docs/spell-list.md + docs/spells.xlsx. | live |
| spell_sfx_prompts.py | lib | The sounds of what spells do, for tools/make_spell_sfx.py (see FX below). Prompts are short and only about the sound (the source, then one or two w... | live |
| spell_sheet.py | one-off | Make docs/spells.xlsx (and docs/spell-list.md) from the spells as the game shows them. | live |
| split_handyman_hits.py | one-off | The Handyman's grunts when he is hit (assets/Puppet/Voice/_Source/handyman/sfx_handy_got_hit.wav, one take) cut at its silences into assets/Puppet/... | live |
| split_handyman_voice.py | one-off | The Handyman's recorded lines (assets/Puppet/Voice/_Source/handyman/Handy_voice.wav, one long take) cut into one clip per line of his talk (scripts... | live |
| tag_pianist_hands.py | one-off | 2026-11-10: adds the HAND to every note of data/pianist_notes.json (the audio is NOT touched): the MIDI has the right hand on channel 0 and the lef... | live |
| aa_shot.gd | check |  | live |
| act_sign_check.gd | check | The Act sign of a Puppet fight drops at the start and goes back up after 10 s: godot --headless --path . --script res://tools/act_sign_check.gd | live |
| art_check.gd | check |  | live |
| asset_map.gd | check | Writes {name: md5 of the file UiSkin resolves it to} for every art name, for the theme in ASSET_THEME, to ASSET_OUT (a json). | live |
| asset_paths_check.gd | check | Every loader that does not go through UiSkin.path_of: enemies, stage pictures, card pieces, shaders, fonts, sounds, music. | live |
| ball_shot.gd | check | Frames of the Puppet Stage ball machine (Essence a Lens gives back / a spell sends for next turn): godot --path . --position 6000,0 --no-focus --au... | live |
| ball_stress.gd | check | One frame of watching: a ball that is rolling must move every frame (a hair of rest at its start delay is allowed). | live |
| bear_shot.gd | check | They See Me Rolling on the Puppet Stage: the bush, the hover tag, the click on the bear (shatter + coins). godot --path . --position 6000,0 --no-fo... | live |
| boss_reenter_test.gd | check | Quit a boss fight to the menu and Continue, three times: how many hands does the Handyman have each time? | live |
| boss_shot.gd | check | A still of one or more enemies in a real fight (Puppet theme): godot --path . --position 6000,0 --no-focus --audio-driver Dummy -s tools/boss_shot.... | live |
| boss_sign_shot.gd | check | The Victory / Boss Defeated board dropped on the stage: godot --path . --position 6000,0 --no-focus -s tools/boss_sign_shot.gd -- <out folder> | live |
| boss_talk_shot.gd | check | A boss's talk (BossTalk), one still after the first line and one after picking the first option: BOSS=handyman/invoker SHOT_THEME=puppet/new_ui god... | live |
| burn_check.gd | check |  | live |
| camp_fuse_test.gd | check | An Abandoned Camp on its stage (real main flow): the torch cursor, picking two spells, fusing in the cauldron, the new card + Continue. | live |
| card_fx_gif.gd | check | Records frames of anti-spell (negative) and Ephemeral (bad reception) cards, ending with one Ephemeral card | live |
| chant_click_test.gd | check |  | live |
| chant_drag_stress.gd | check | Dragging chant balls down to the Bag in every way a player can (godot --path . --position 6000,0 --no-focus --audio-driver Dummy -s tools/chant_dra... | live |
| chant_hit_test.gd | check | Which controls sit over each chant slot (a click on a slot that does nothing is a control in the way): godot --path . --position 6000,0 --no-focus... | live |
| character_panel_shot.gd | check | A still of the Puppet Stage fight with EVERYTHING in the Character panel (all statuses, 5 bottles, 24 artifacts, Leaves, Shield) and the | live |
| check_scripts.gd | check | Loads every script under res://scripts so parse errors surface. Usage: -s tools/check_scripts.gd | live |
| conjure_gif.gd | check | Records the Conjure split / merge on a real fight screen (frames for a GIF). | live |
| corrector_shot.gd | check | The Corrector after his reboot, with both screens' intents: godot --path . --position 6000,0 --no-focus --audio-driver Dummy -s tools/corrector_sho... | live |
| cursor_hand_shot.gd | check | The steal cursor (open hand, fist holding an Essence): godot --path . --position 6000,0 --no-focus --audio-driver Dummy -s tools/cursor_hand_shot.g... | live |
| curtain_map_shot.gd | check | The Curtain map on the stage: godot --path . --position 6000,0 --no-focus --audio-driver Dummy -s tools/curtain_map_shot.gd -- <out_dir> | live |
| curtain_sim.gd | check | The Curtain map: how many rooms a player gets through before the boss, for a few ways of playing. | live |
| debuff_shot.gd | check | The player's debuffs on screen: Ignite and Virus badges on cards, Burden's stone slots, Confuse's veil over the slot | live |
| dialogue_board_shot.gd | check | The cream dialogue board in the real flow: the merchant's conversation (Test mode > Events > The Merchant, click him) and an event's story box (The... | live |
| dragon_shot.gd | check | Winter Wyvern fight screenshots (Puppet Stage): godot --path . --position 6000,0 --no-focus --audio-driver Dummy -s tools/dragon_shot.gd -- <out fo... | live |
| dump_boss_talk.gd | check | The boss's lines to be spoken (id, reply, reply2) from BossTalk: godot --headless --path . --script res://tools/dump_boss_talk.gd -- out.json <boss... | live |
| dump_event_texts.gd | check | Every text of the given events (pages, outcomes) with the key the game plays its voice under: godot --headless --path . --script res://tools/dump_e... | live |
| dump_spells.gd | check | Writes every spell as the game shows it (its card text, from SpellText) to a JSON file, for tools/spell_sheet.py. | live |
| encounter_shot.gd | check | A fight against these enemies, in Puppet, a few seconds in: godot --path . --position 6000,0 --no-focus --audio-driver Dummy -s tools/encounter_sho... | live |
| event_batch2_flow.gd | check | The older "?" events through the REAL screens (main.gd): choose an option, see what the stage says and where Continue leads. | live |
| event_batch2_test.gd | check | The older "?" events' stage reactions (batch 2): every result word played once on its own stage, a still 1.3 s in (tweens, flights and sounds can't... | live |
| event_center_check.gd | check | Are the spells / items / buttons of every event with props centred on the screen? godot --headless --path . --script res://tools/event_center_check.gd | live |
| event_edit_test.gd | check | The F6 layout editor of the test room: select, move, arrows, scale, +/-, undo (real main flow, off-screen). | live |
| event_shots.gd | check | Every event that has props, on the Puppet Stage (a still each): godot --path . --position 6000,0 --no-focus --audio-driver Dummy -s tools/event_sho... | live |
| event_stage_test.gd | check | Every event with props: each option can be chosen (by `_choose`, like a click on its prop or button) and `picked` comes back with it. | live |
| export_stage_layers.gd | check | Renders the Puppet Stage fight screen layer by layer (transparent PNG, 2x) + layout.json, for tools/build_layout_pdf.py. | live |
| f4_hit_test.gd | check | godot --path . --position 6000,0 --no-focus -s tools/f4_hit_test.gd : which control is under each F4 point button in a real fight? | live |
| feature_shots.gd | check | Screenshots of the bottles, statuses, seals, fusing and loadout-drag screens (a visual check). | live |
| fight_cycle_test.gd | check | Two fights in a row on the Puppet Stage (the real flow: map, encounter board, Begin, fight, win, rewards, map, encounter board, Begin, fight): | live |
| fight_fx_test.gd | check |  | live |
| fish_no_test.gd | check | Fisher's Fish from its first page: the sea comes in as the fisherman appears (back wall down, props change sides), then the "No" answer (the box an... | live |
| fish_stage_test.gd | check | Elemental Fishing on its stage (real main flow): the fisherman and his flat stream, the sea (back wall + reefs, kelp, algae) while the game is on,... | live |
| font_shots.gd | check | The Settings screen and the main menu in each font of Settings > Font (a still each): godot --path . --position 6000,0 --no-focus --audio-driver Du... | live |
| fps_shot.gd | check | Show FPS: godot --path . --position 6000,0 --no-focus --audio-driver Dummy -s tools/fps_shot.gd -- <out folder> | live |
| frames_shot.gd | check | The painted frames that used to be drawn in code, in one still: godot --path . --position 6000,0 --no-focus --audio-driver Dummy -s tools/frames_sh... | live |
| fuse_audit.gd | check | Fuses every pair of spells that can be fused (with the fusion rules, FuseRules) and flags the fused spells that read | live |
| handy_hit_sound_test.gd | check | The Handyman's grunt on a hit (Creature.hit): godot --path . --position 6000,0 --no-focus --audio-driver Dummy -s tools/handy_hit_sound_test.gd | live |
| handyman_fall_shot.gd | check | The Handyman's new fight (hands fall to the floor, the next one grows, last stand): godot --path . --position 6000,0 --no-focus --audio-driver Dumm... | live |
| handyman_mix_check.gd | check | Test mode: the Handyman together with another enemy must not crash: godot --path . --position 6000,0 --no-focus --audio-driver Dummy -s tools/handy... | live |
| handyman_shot.gd | check | Handyman fight screenshots (Puppet Stage): godot --path . --position 6000,0 --no-focus -s tools/handyman_shot.gd -- <out folder> | live |
| handyman_turns_shot.gd | check | Real enemy turns of the Handyman fight (turn 1 vs turn 2): frames of the Sword Hand's attack and the Tweezer Hand's steal. | live |
| handyman_weapons_shot.gd | check | The Hammer Hand reaching a card and the Crossbow Hand's bolt: godot --path . --position 6000,0 --no-focus --audio-driver Dummy -s tools/handyman_we... | live |
| header_shots.gd | check | F7, the text inspector, on the main menu: pick the Play button, change its group, then Cancel (a still each): godot --path . --position 6000,0 --no... | live |
| hp_list.gd | check | Every enemy that is met in a run, with its Essence (and second-phase Essence): godot --headless --path . -s tools/hp_list.gd | live |
| hp_over_20.gd | check | Lists every enemy with more than 20 Essence in a phase (its own row or its second-phase row; nothing is added on top). | live |
| hp_stripes_test.gd | check | godot --path . --position 6000,0 --no-focus -s tools/hp_stripes_test.gd : the stripe HP bar in states, pictures in C:/temp/hp_*.png (crops of the H... | live |
| hud2_shot.gd | check | Puppet HUD ver 2, a fight: godot --path . --resolution 1920x1080 --position 6000,0 --no-focus --audio-driver Dummy -s tools/hud2_shot.gd -- <out dir> | live |
| icon_audit.gd | check | Which pictures the game asks for by name that do not exist (Puppet theme; "fallback" = only the older New art has it). | live |
| invoker_flow_check.gd | check | The Invoker in a real fight screen: a new set of spells buzzing in, then his rise into phase 2 (burst and reform). Saves frames. | live |
| invoker_real_flow.gd | check | The Invoker through real turns: your Release takes his last Essence (phase 2), his quiet turn, then his chanting turns. | live |
| keys_probe.gd | check | Real-input check of the InputMap actions: F1 opens the Wiki, F5 reaches rope mode (toast in a non-room), F7 opens the TextInspector. | live |
| leak_watch.gd | check | Plays runs through the real UI (sped up, see ui_playtest_impl.gd) and prints what the engine is holding every few | live |
| lever_shot.gd | check | The Act sign and the lever at 0 / 0.4 / 0.7 / 1 of its pull: godot --path . --resolution 1920x1080 --position 6000,0 --no-focus --audio-driver Dumm... | live |
| make_icons.gd | check | Renders the element orbs (and the generic ? element) to PNGs for rich text: assets/Global/Icon/Element/el_*.png | live |
| map_lower_check.gd | check | The stage map is pulled up all the way, however far it has sunk (scrolled up): godot --path . --position 6000,0 --no-focus --audio-driver Dummy -s... | live |
| marker_check.gd | check |  | live |
| menu_actors_test.gd | check | Headless: runs the menu puppets for 30 simulated minutes and counts the moments two of them overlap (they must not walk through each other). | live |
| menu_btn_test.gd | check | The Menu button on the stage's map and encounter screens. | live |
| menu_shot.gd | check | The Puppet Stage main menu: godot --path . --position 6000,0 --no-focus --audio-driver Dummy -s tools/menu_shot.gd -- <out folder> (menu_0.png ...... | live |
| merchant_event_flow.gd | check | Test mode > Events > The Merchant, through the real Main flow: the shop must come up OVER THE STAGE (cart rolls in), then Leave goes back to Test m... | live |
| merchant_quest_shot.gd | check | The merchant's quests on screen: the mark, his first favour, handing the blanket over, and him drunk with the picture. | live |
| music_play_test.gd | check | Music Edit: the listen button plays, the bar follows and seeks: godot --path . --position 6000,0 --no-focus --audio-driver Dummy -s tools/music_pla... | live |
| music_shots.gd | check | The Settings screen (cream buttons) and Settings > Music Edit (a still each): godot --path . --position 6000,0 --no-focus --audio-driver Dummy -s t... | live |
| new_run_test.gd | check | godot --path . --position 6000,0 --no-focus -s tools/new_run_test.gd : New run with a saved run: pop-up on the menu stage, drapes, keepsakes, map.... | live |
| new_ui_shot.gd | check | Samples the mean brightness of some static parts of the HUD every frame for `secs` seconds and prints the biggest jump between two frames (a flicke... | live |
| note_flow_shot.gd | check | A Note to Yourself through the real screens (Main._test_event): godot --path . --position 6000,0 --no-focus --audio-driver Dummy -s tools/note_flow... | live |
| nu_hit_main_check.gd | check | New UI through the real game flow (Test mode -> Fight!): an enemy hits hard and the HUD is sampled every frame (a vanishing HUD shows as a big jump). | live |
| nu_rise_shot.gd | check | New UI theme: the orbs of a spawn go down the tube, under the clamp, come up out of the hole and roll. godot --path . --position 6000,0 --no-focus... | live |
| offset_flow_test.gd | check | The Spellbook line moved with the F7 inspector, Saved, and the Loadout screen opened again through main's own flow: godot --path . --position 6000,... | live |
| offset_test.gd | check | A text moved by the F7 inspector keeps its place when it is made again (in a container, a text set after it was made...): godot --path . --headless... | live |
| perf_baseline.gd | check | An empty window, for comparing frame rates with perf_probe.gd (same window flags). | live |
| perf_probe.gd | check | Frame cost and pile-up check (see perf_probe.gd). Mode "cost": one fight, how long a frame takes. Mode "cycle": fight | live |
| pianist_engage_flow.gd | check | Engage through the real screens (see tools/pianist_engage_flow.gd). | live |
| pianist_flow.gd | check | The Pianist through the REAL screens (main.gd, Test mode fight): frames while he plays, the page turn (he points at the sign) and the last chord. | live |
| pianist_legs_flow.gd | check | The five leg pictures of the Pianist, one after the other, through the real screens (see tools/pianist_legs_flow.gd). | live |
| pianist_pose_shot.gd | check | Stills of the Pianist (seen from behind) in each of his animations: godot --path . --position 6000,0 --no-focus --audio-driver Dummy -s tools/piani... | live |
| pianist_shot.gd | check | The Pianist at his piano: godot --path . --position 6000,0 --no-focus --audio-driver Dummy -s tools/pianist_shot.gd -- <out folder> | live |
| pianist_sign_flow.gd | check | The Pianist's sign sequence through the REAL screens (Main -> Test fight): stills every 0.35 s while he points at the sign. | live |
| pianist_start_flow.gd | check | The Pianist from the moment the fight screen opens, through the real screens: a still every 0.5 s (start_00.png ...), to see the idle position befo... | live |
| puppet_fight_shot.gd | check | One fight screenshot in the Puppet Stage theme: godot --path . --position 6000,0 --no-focus -s tools/puppet_fight_shot.gd -- <out.png> | live |
| puppet_ui_shot.gd | check | Puppet UI pieces on one screen: godot --path . --position 6000,0 --no-focus -s tools/puppet_ui_shot.gd -- <out.png> | live |
| rearrange_flow_check.gd | check | Rearrange in a real fight screen: drags an Essence off one enemy onto another with real mouse events, saves frames. | live |
| refund_flight_test.gd | check | Puppet: an Essence given back by a Lens flies chant slot -> pipe -> box -> tube -> Bag: godot --path . --position 6000,0 --no-focus -s tools/refund... | live |
| room_test_shot.gd | check | The real Room Test flow, a boss room of a chosen act, one screenshot: godot --path . --position 6000,0 --no-focus --audio-driver Dummy -s tools/roo... | live |
| rope_set_audit.gd | check | How many enemies each Room Test rope set holds, and which enemy is in none: godot --headless --path . -s tools/rope_set_audit.gd | live |
| rope_shot.gd | check | Drives the real Main scene: Room Test -> Fight Act 1 -> F5 -> rivets (click, drag, right click) -> Next set -> F5 again. Prints what it sees and | live |
| rows_check.gd | check | Rows of a boss's Essence in every mode: godot --path . --position 6000,0 --no-focus -s tools/rows_check.gd | live |
| samurai_shot.gd | check | The Samurai and his Retainer on stage, and a frame of his Deflect: godot --path . --position 6000,0 --no-focus --audio-driver Dummy -s tools/samura... | live |
| shop_buy_flash.gd | check | Looks for a flash after a purchase in the stage shop: godot --path . --position 6000,0 --no-focus --audio-driver Dummy -s tools/shop_buy_flash.gd -... | live |
| shop_cart_flow.gd | check | screen point of a point of the cart picture (picture px) | live |
| shop_editor_flow.gd | check | Test mode > Events > The Merchant, then the F6 shelf editor driven with real input events: select + drag the shelf, resize it, select an artifact s... | live |
| shop_hover_perf.gd | check | Time of a spell card's hover magnifier in the stage shop: godot --path . --position 6000,0 --no-focus --audio-driver Dummy -s tools/shop_hover_perf.gd | live |
| shop_info_board_shot.gd | check | The shop's info board (Test mode > Events > The Merchant): an artifact, a bottle and the candle are "hovered" by hand; the board slides out left of... | live |
| shop_info_sizes.gd | check | see shop_info_sizes.gd | live |
| shop_shot.gd | check | The merchant screen (Puppet): godot --path . --position 6000,0 --no-focus --audio-driver Dummy -s tools/shop_shot.gd -- <out folder> | live |
| shop_stage_shot.gd | check | The merchant on the Puppet Stage (cart, merchant, goods): godot --path . --position 6000,0 --no-focus --audio-driver Dummy -s tools/shop_stage_shot... | live |
| shots.gd | check | Renders each screen to PNG for a visual check. | live |
| side_panels_test.gd | check | godot --path . --position 6000,0 --no-focus -s tools/side_panels_test.gd : artifacts + bottles frames and the Menu button, in a fight and between f... | live |
| sim.gd | check | Headless playtest: a scripted player plays full runs and reports what killed it. | live |
| skin_probe.gd | check |  | live |
| slot_shot.gd | check | The slot machine in a fight: godot --path . --resolution 1920x1080 --position 6000,0 --no-focus -s tools/slot_shot.gd -- <out dir> | live |
| slots_shot.gd | check |  | live |
| stage_encounter_test.gd | check | The Puppet Stage encounter flow: the new set and the enemies come in behind the encounter board; "Begin the fight" flies the chosen cards to the fi... | live |
| stage_flow_test.gd | check | godot --path . --position 6000,0 --no-focus -s tools/stage_flow_test.gd : the whole stay-on-the-stage run flow, with pictures in C:/temp/sf_*.png | live |
| stage_map_shot.gd | check | The Puppet Stage map (ropes hanging from the ceiling): godot --path . --position 6000,0 --no-focus -s tools/stage_map_shot.gd -- <out_dir> | live |
| stage_measure.gd | check | Sutherland-Hodgman: a polygon clipped to the screen rectangle. | live |
| stage_only_shot.gd | check | Only the stage (no HUD, no puppets), one screenshot: godot --path . --position 6000,0 --no-focus --audio-driver Dummy -s tools/stage_only_shot.gd -... | live |
| steal_drag_test.gd | check | The steal spell: cards shrink, hand cursor, drag an enemy Essence into the Bag (glow, straight in), fist while dragging your own: godot --path . --... | live |
| steal_flow_check.gd | check | The Veiled Eyes' whole theft in a real fight screen (timings + frames): godot --path . --position 6000,0 --no-focus -s tools/steal_flow_check.gd --... | live |
| steal_shot.gd | check | The Veiled Eyes carrying a card off (the pose of the theft): godot --path . --position 6000,0 --no-focus -s tools/steal_shot.gd -- <out folder> | live |
| talk_voice_test.gd | check | The Handyman's talk after "Begin the fight": nothing is said while the board is up, the first line starts when the scene and the HUD are in, its bu... | live |
| test_mode_shot.gd | check | Test mode fight (Auto-fill / Auto-ball buttons): godot --path . --position 6000,0 --no-focus --audio-driver Dummy -s tools/test_mode_shot.gd -- <ou... | live |
| test_puppet_edit.gd | check | Tests the F4 perspective editor: godot --headless --path . -s tools/test_puppet_edit.gd | live |
| top_hud_shot.gd | check | The top HUD: godot --path . --resolution 1920x1080 --position 6000,0 --no-focus -s tools/top_hud_shot.gd -- <out dir> | live |
| trinity_shot.gd | check | Frames of the Trinity cutscene (the three Fragments combine): godot --path . --position 6000,0 --no-focus --audio-driver Dummy -s tools/trinity_sho... | live |
| turn_timing.gd | check | Logs chant / cast / release / ball-launch timing: godot --headless --path . -s tools/turn_timing.gd -- <theme> | live |
| tutorial_check.gd | check | Plays the tutorial by doing exactly what Sprout asks, snapshotting every step. Fails loudly if a step stalls. | live |
| tweezer_revive_shot.gd | check | The tweezer hand over the HUD (only its lower stick climbs) and the Resurrecting intent (hand + hourglass): godot --path . --position 6000,0 --no-f... | live |
| ui_playtest.gd | check | Drives the real game screens like a player would, at high speed, and snapshots key moments. | live |
| unveil_shot.gd | check | The Veiled Eyes' unveiling, frame by frame: godot --path . --position 6000,0 --no-focus -s tools/unveil_shot.gd -- <out folder> | live |
| ver2_menu_shot.gd | check | NewUI Ver2 pause menu + family buttons + a panel: godot --path . --position 6000,0 --no-focus --audio-driver Dummy -s tools/ver2_menu_shot.gd -- <o... | live |
| vfx_demo.gd | check | Plays every spell effect's VFX in a staged fight and saves frames (for checking the effects by eye). | live |
| wyvern_flow.gd | check | Stills of the Winter Wyvern in the real flow: at rest (twice, a moment apart: the wings and tail must have moved) and with each intent shown. | live |
