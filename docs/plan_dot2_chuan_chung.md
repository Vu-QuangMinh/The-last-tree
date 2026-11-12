# Đợt 2 — Chốt chuẩn chung (để hai người và mọi session làm giống nhau)

Kế hoạch thi hành cho một phiên Claude (Sonnet). Dựa trên `docs/audit_2026-11-12.md` mục 5, đợt 2. **Làm sau khi đợt 1 đã commit** (`docs/plan_dot1_don_kho.md`); nếu đợt 1 chưa xong, làm đợt 1 trước.
Luật chung = mục 0 của đợt 1 (tiếng Việt, không resize, một task một commit, không push, [HỎI] là dừng chờ, Edit tool/Python UTF-8, kiểm chứng bằng `check_scripts` + `run_tests_auto`).

Khác đợt 1: đợt này **có** sửa code ở 6 chỗ đích danh (T2.3 phím tắt) và có thể sửa nhiều file nếu T2.1 làm lộ warning. Mọi sửa code trong đợt này phải là **đổi cách viết, không đổi hành vi**; nếu một sửa warning buộc phải đổi hành vi (ví dụ biến "unused" hoá ra là bug), **không sửa**, ghi lại và báo.

Mẫu commit: `Conventions (đợt 2, T2.x): <một dòng>` + dòng Co-Authored-By.

---

## T2.1 Warning của GDScript thành lỗi, ghi trong `project.godot`

**Hiện trạng**: `CLAUDE.md` nói "warnings are errors" nhưng `project.godot` không có mục `[debug]` nào; `--check-only` headless **không in warning** (đã thử với file có biến không dùng: im lặng). Vậy luật hiện chỉ sống trong editor của người dùng, Minh và các phiên headless không bị chặn.

**Cách Godot 4.6 lưu**: section `[debug]`, khoá `gdscript/warnings/<tên>` với giá trị `0` = bỏ qua, `1` = cảnh báo, `2` = lỗi. Khi là lỗi, script **không parse được** → `check_scripts` sẽ in `BAD`. Đó chính là cách kiểm chứng headless. (Đã thử ngày 12/11 trên một project tạm với Godot 4.6.2: `--check-only` in `Parse Error: ... (Warning treated as error.)` và exit 1. Định dạng `[input]` ở T2.3 và các mã phím cũng đã thử cùng lúc: nạp đúng, `is_action_pressed` trả true.)

**Bước**
1. Thêm vào `project.godot`, ngay sau section `[autoload]` (giữ thứ tự section theo bảng chữ cái như Godot vẫn ghi: `application`, `autoload`, `debug`, `display`, `gui`, `rendering`):
   ```ini
   [debug]

   gdscript/warnings/enable=true
   gdscript/warnings/unused_variable=2
   gdscript/warnings/unused_local_constant=2
   gdscript/warnings/unused_private_class_variable=2
   gdscript/warnings/unused_parameter=2
   gdscript/warnings/unused_signal=2
   gdscript/warnings/unassigned_variable=2
   gdscript/warnings/unassigned_variable_op_assign=2
   gdscript/warnings/shadowed_variable=2
   gdscript/warnings/shadowed_variable_base_class=2
   gdscript/warnings/shadowed_global_identifier=2
   gdscript/warnings/unreachable_code=2
   gdscript/warnings/unreachable_pattern=2
   gdscript/warnings/standalone_expression=2
   gdscript/warnings/standalone_ternary=2
   gdscript/warnings/incompatible_ternary=2
   gdscript/warnings/redundant_await=2
   gdscript/warnings/static_called_on_instance=2
   gdscript/warnings/assert_always_true=2
   gdscript/warnings/assert_always_false=2
   gdscript/warnings/confusable_identifier=2
   gdscript/warnings/confusable_local_declaration=2
   gdscript/warnings/confusable_local_usage=2
   gdscript/warnings/inference_on_variant=2
   gdscript/warnings/native_method_override=2
   gdscript/warnings/get_node_default_without_onready=2
   gdscript/warnings/onready_with_export=2
   gdscript/warnings/unsafe_void_return=2
   ```
   **Không** đặt `integer_division`, `narrowing_conversion`, `return_value_discarded`, `untyped_declaration`, `unsafe_*` = 2: chúng rất ồn trong code UI; để mặc định.
2. Probe để chắc cơ chế hoạt động: tạo `tools/_warn_probe.gd`:
   ```gdscript
   extends RefCounted
   func f(unused_param: int) -> void:
   	var unused_local := 1
   ```
   Chạy `"<Godot>" --headless --path . --check-only --script res://tools/_warn_probe.gd`. **Kỳ vọng**: có dòng lỗi (`UNUSED_PARAMETER` / `UNUSED_VARIABLE`) và exit code ≠ 0. Nếu vẫn im lặng và exit 0 → khoá sai tên hoặc Godot không đọc; dừng, ghi lại, hỏi người dùng (không đoán tên khoá khác). Xoá probe (`rm tools/_warn_probe.gd tools/_warn_probe.gd.uid`) dù kết quả thế nào.
3. Chạy `check_scripts`. Mỗi dòng `BAD res://...` là một file có warning-nay-là-lỗi. Lấy chi tiết từng file bằng `--check-only --script res://<file>` (in dòng + tên warning).
4. **Ngưỡng quyết định**: đếm tổng số lỗi.
   - ≤ 40: sửa hết trong task này, theo quy tắc dưới.
   - > 40: **[HỎI]** gửi người dùng bảng `file | số lỗi | loại` và đề nghị: hoặc sửa dần theo nhóm file, hoặc hạ tạm các loại ồn nhất xuống `1`. Không tự sửa hàng loạt file khoá/permission (`fight.gd`, `fight_screen.gd`, `enemy_defs.gd`, `run_state.gd`, `main.gd`) khi chưa có đồng ý.
5. Quy tắc sửa (không đổi hành vi):
   - `unused_parameter`: thêm `_` trước tên tham số (`_delta`), **không** xoá tham số (signal/callback cần đúng số tham số).
   - `unused_variable`/`unused_local_constant`: xoá dòng khai báo nếu vế phải không có tác dụng phụ (không gọi hàm); nếu vế phải gọi hàm (`var _x := node.do_thing()`), đổi thành gọi trần `node.do_thing()`.
   - `shadowed_variable`: đổi tên biến cục bộ (thêm hậu tố `_l` hoặc tên rõ hơn), không đổi tên thành viên.
   - `unreachable_code`: xoá phần sau `return` chỉ khi chắc chắn là code chết; nếu là `return` thừa thì xoá `return`.
   - `redundant_await`: bỏ `await`.
   - `inference_on_variant` (`var x := dict.get(...)`): thêm kiểu rõ `var x: int = ...` theo đúng kiểu đang dùng ở dòng dưới; không ép kiểu khác với cách dùng.
   - Mọi loại khác: ghi lại, hỏi, không tự sửa.
6. Sau khi sạch: `check_scripts` 0 failed, `run_tests_auto` 189/0. Ghi vào `CLAUDE.md` mục Verify dòng 1: thay "warnings are errors" bằng "warnings are errors (`project.godot [debug] gdscript/warnings/* = 2`, so `check_scripts` fails on them)".

**Lùi lại**: bỏ section `[debug]` là mọi thứ như cũ; các sửa warning đã làm vẫn hợp lệ.

---

## T2.2 Một runner test duy nhất

**Hiện trạng**: `tests/run_tests.gd` (37 dòng, README/CLAUDE.md trỏ vào) và `tools/run_tests_auto.gd` (bản có `await process_frame` + timer 240 s, vì test gọi `Audio`/`SaveManager` phải có sau frame đầu). Ngày 12/11 bản `_auto` chạy pass 189/0.

**Bước**
1. Chạy bản cũ để biết nó có hỏng thật không:
   `"<Godot>" --headless --path . --script res://tests/run_tests.gd 2>&1 | tail -5`.
   Ghi kết quả (pass hay lỗi gì) vào báo cáo; dù pass hay không vẫn gộp (một runner là đủ).
2. Ghi đè `tests/run_tests.gd` bằng nội dung của `tools/run_tests_auto.gd` với sửa nhỏ: docstring đầu file thành
   ```gdscript
   extends SceneTree
   ## Headless unit-test runner (the only one). Starts after the first frame so the autoloads (Audio, SaveManager, GameData) exist.
   ##   "C:\Program Files\Godot\Godot.exe" --headless --path . --script res://tests/run_tests.gd [-- filter]
   ## filter = part of "test_file.gd:test_name". Exit 0 = all passed, 1 = a test failed, 2 = the 240 s guard fired.
   ```
   Phần thân giữ nguyên (`await process_frame`, timer, vòng lặp).
3. `git rm tools/run_tests_auto.gd tools/run_tests_auto.gd.uid`.
4. Thay mọi chỗ nhắc `run_tests_auto` → `tests/run_tests.gd`: `grep -rn "run_tests_auto" . --include=*.md --include=*.gd --include=*.py --include=*.yml` (gồm `CLAUDE.md`, `docs/plan_dot1_don_kho.md`, `docs/plan_dot2_chuan_chung.md`, memory không nằm trong repo nên bỏ qua).
5. README (T2.4) dùng lệnh mới.

**Kiểm chứng**: `"<Godot>" --headless --path . --script res://tests/run_tests.gd` → `189 tests, 0 failed`, exit 0; `--script res://tests/run_tests.gd -- test_chant` chạy ít test hơn (filter hoạt động).

---

## T2.3 Phím tắt qua InputMap, phím dev gate theo build

**Hiện trạng** (dòng chính xác, kiểm lại trước khi sửa vì Minh có thể đã dịch dòng):
| Phím | File:dòng | Làm gì | Gate hiện tại |
|---|---|---|---|
| F5 | `scripts/main.gd:140` (`_input`) | bật/tắt rope mode (editor dây treo) | **không gate**: người chơi bản export cũng bật được |
| F11 | `scripts/main.gd:218` | fullscreen | — |
| F1 | `scripts/main.gd:222` | mở Wiki | — |
| F7 | `scripts/main.gd:225` | bật TextInspector | không gate |
| F7/Esc | `scripts/ui/text_inspector.gd:199` | đóng TextInspector (cùng phím, cố ý: toggle) | — |
| F4 | `scripts/ui/puppet_stage.gd:636` | editor phối cảnh sân khấu | `_edit…` xem `puppet_stage.gd:474` (`not OS.has_feature("template")`) |
| F6 | `scripts/ui/event_stage.gd:2632` | editor layout event | `edit_allowed` (main đặt) |
| F6 | `scripts/ui/shop_screen.gd:1784, 1791` | editor layout shop | `edit_allowed` |
| F/W/A, 1–7, Enter… | `scripts/ui/fight_screen.gd:4392, 4484…` | gameplay trong trận | — |

Phím gameplay trong `fight_screen.gd` và `fish_game.gd` **không đụng** đợt này (đợt 3, cùng lúc tách fight_screen).

**Bước**
1. Thêm section `[input]` vào `project.godot` (sau `[gui]`, trước `[rendering]`). Keycode vật lý của Godot 4: F1 = 4194332, F4 = 4194335, F5 = 4194336, F6 = 4194337, F7 = 4194338, F11 = 4194342.
   ```ini
   [input]

   ui_wiki={
   "deadzone": 0.2,
   "events": [Object(InputEventKey,"resource_local_to_scene":false,"resource_name":"","device":-1,"window_id":0,"alt_pressed":false,"shift_pressed":false,"ctrl_pressed":false,"meta_pressed":false,"pressed":false,"keycode":0,"physical_keycode":4194332,"key_label":0,"unicode":0,"location":0,"echo":false,"script":null)
   ]
   }
   ui_fullscreen={
   "deadzone": 0.2,
   "events": [Object(InputEventKey,"resource_local_to_scene":false,"resource_name":"","device":-1,"window_id":0,"alt_pressed":false,"shift_pressed":false,"ctrl_pressed":false,"meta_pressed":false,"pressed":false,"keycode":0,"physical_keycode":4194342,"key_label":0,"unicode":0,"location":0,"echo":false,"script":null)
   ]
   }
   dev_stage_edit={
   "deadzone": 0.2,
   "events": [Object(InputEventKey,"resource_local_to_scene":false,"resource_name":"","device":-1,"window_id":0,"alt_pressed":false,"shift_pressed":false,"ctrl_pressed":false,"meta_pressed":false,"pressed":false,"keycode":0,"physical_keycode":4194335,"key_label":0,"unicode":0,"location":0,"echo":false,"script":null)
   ]
   }
   dev_rope_mode={
   "deadzone": 0.2,
   "events": [Object(InputEventKey,"resource_local_to_scene":false,"resource_name":"","device":-1,"window_id":0,"alt_pressed":false,"shift_pressed":false,"ctrl_pressed":false,"meta_pressed":false,"pressed":false,"keycode":0,"physical_keycode":4194336,"key_label":0,"unicode":0,"location":0,"echo":false,"script":null)
   ]
   }
   dev_layout_edit={
   "deadzone": 0.2,
   "events": [Object(InputEventKey,"resource_local_to_scene":false,"resource_name":"","device":-1,"window_id":0,"alt_pressed":false,"shift_pressed":false,"ctrl_pressed":false,"meta_pressed":false,"pressed":false,"keycode":0,"physical_keycode":4194337,"key_label":0,"unicode":0,"location":0,"echo":false,"script":null)
   ]
   }
   dev_text_inspector={
   "deadzone": 0.2,
   "events": [Object(InputEventKey,"resource_local_to_scene":false,"resource_name":"","device":-1,"window_id":0,"alt_pressed":false,"shift_pressed":false,"ctrl_pressed":false,"meta_pressed":false,"pressed":false,"keycode":0,"physical_keycode":4194338,"key_label":0,"unicode":0,"location":0,"echo":false,"script":null)
   ]
   }
   ```
2. Thêm một hàm tĩnh dùng chung cho gate dev. Đặt ở `scripts/ui/ui_skin.gd` (file tiện ích tĩnh đã có, mọi màn hình đều thấy) ngay sau `theme_id()`:
   ```gdscript
   ## Developer keys (F4 / F5 / F6 / F7 editors) work only when the game runs from the project, never in an exported build.
   static func dev_keys() -> bool:
   	return not OS.has_feature("template")
   ```
3. Sửa đúng 7 điều kiện, mỗi chỗ giữ nguyên thân hàm:
   - `main.gd:140` → `if ev.is_action_pressed("dev_rope_mode") and UiSkin.dev_keys():`
   - `main.gd:218` → `if ev.is_action_pressed("ui_fullscreen"):`
   - `main.gd:222` → `if ev.is_action_pressed("ui_wiki"):`
   - `main.gd:225` → `if ev.is_action_pressed("dev_text_inspector") and UiSkin.dev_keys():`
   - `text_inspector.gd:199` → `if ev.is_action_pressed("dev_text_inspector") or ev.is_action_pressed("ui_cancel"):` (`ui_cancel` là action mặc định của Godot cho Esc; nếu muốn chắc, giữ `(ev is InputEventKey and ev.pressed and not ev.echo and ev.keycode == KEY_ESCAPE)` cho vế Esc).
   - `puppet_stage.gd:636` → `if ev.is_action_pressed("dev_stage_edit"):` (dòng 631–633 phía trên đã lọc `InputEventKey` + `pressed`; `is_action_pressed` mặc định bỏ echo nên bỏ `and not ev.echo`).
   - `event_stage.gd:2632` → `if e.is_action_pressed("dev_layout_edit"):`
   - `shop_screen.gd:1784` → `if edit_allowed and _true_cart and ev.is_action_pressed("dev_layout_edit"):`; `:1791` tương tự với vế `on_stage and not _true_cart`.
   Lưu ý: `InputEvent.is_action_pressed(action, allow_echo := false)` đã loại echo và chỉ đúng khi `pressed`.
4. `CLAUDE.md` mục "Layout editors (Test mode)": thêm câu "Keys are InputMap actions `dev_*` in `project.godot`; they only work outside exported builds (`UiSkin.dev_keys()`)."

**Kiểm chứng**
- `check_scripts` + tests pass.
- Chạy thật một lần, cửa sổ ngoài màn hình, không focus, không tiếng, tự tắt: viết `tools/keys_probe_impl.gd` + wrapper theo mẫu `tools/aa_shot.gd` (5 dòng) làm: mở `FightScreen` như `aa_shot_impl.gd`, `await t.create_timer(2.0).timeout`, rồi bơm phím bằng
  ```gdscript
  var k := InputEventKey.new(); k.physical_keycode = KEY_F5; k.pressed = true; Input.parse_input_event(k)
  await t.process_frame
  k = InputEventKey.new(); k.physical_keycode = KEY_F5; k.pressed = false; Input.parse_input_event(k)
  ```
  và in `root.get_node("Main")._rope_mode` (đọc tên biến thật trong `main.gd:604 _toggle_rope_mode`) trước/sau; lặp cho F1 (kiểm `Main` có `WikiScreen` con sau khi bấm: `root.get_node("Main").overlay_layer.get_child_count()` hoặc tương đương, đọc `main.gd:124`). Chạy:
  `"<Godot>" --path . --position 6000,0 --no-focus --audio-driver Dummy --script res://tools/keys_probe.gd` ; script phải `quit()` ở cuối và có timer guard 60 s. Ghi PID, chỉ tắt PID đó nếu treo.
- Kỳ vọng: giá trị đổi sau mỗi phím. Nếu không đổi, kiểm `physical_keycode` (một số bàn phím/IME map khác) → thử `keycode` thay vì `physical_keycode` trong `[input]`.

**Lùi lại**: revert commit; không có dữ liệu nào thay đổi.

---

## T2.4 README.md viết lại

**Lý do**: README hiện mô tả luật **ngược** với "Settled game rules" (auto-cast, auto-release), đường dẫn máy Minh, số spell/enemy sai (thật: 214 spell, 87 enemy), lệnh test không chạy.

**Bước**: ghi đè `README.md` bằng bản dưới đây, rồi **điền 3 chỗ `<…>`** bằng cách đọc code (không đoán): số act/boss từ `EnemyDefs.BOSSES` (`enemy_defs.gd:474`), số spell `python -c "import json;print(len(json.load(open('data/spells.json',encoding='utf-8'))['spells']))"`, số enemy = số khoá cấp 1 trong `const E` của `enemy_defs.gd`.

````markdown
# Behind the Curtain

A Godot 4.6 chanting roguelite (GL Compatibility renderer, also exported to the web). Three acts on a branching map, one encounter at a time, first person, enemies in front of you like puppets on a stage. Enemies' HP is a row of Fire, Water and Wind; you chant elements to break those rows and wake your spells.

## Play

Open the folder in Godot 4.6 and press F5, or:

```
"C:\Program Files\Godot\Godot.exe" --path .
```

New? Main menu → **Tutorial**. Rules: main menu "How to play · Wiki" or **F1** anywhere.

### The loop (the settled rules: see CLAUDE.md before changing any of them)
1. Build a chant (up to 8 elements) and press **Chant**. Every active spell whose pattern appears in the chant wakes up, one charge per separate match, never more than its pattern's length.
2. **No spell casts itself.** Click each awake spell to cast it (targeted spells ask for a target). Right-click / Esc puts back a *selected* spell before it is cast; a cast spell cannot be taken back.
3. When every spell is cast the **Release** button pulses: press it (E). Every enemy loses the longest start of its HP row found in the chant, element by element. Then the enemies act.

Cards are Common, Rare or Legendary. Campfires heal or fuse two spells. Elites give artifacts, bosses give Legendaries and talk before the fight.

## Numbers
<N_SPELLS> spells in `data/spells.json` (the only source of spell data), <N_ENEMIES> enemies in `scripts/core/enemy_defs.gd`, <N_BOSSES> bosses over 3 acts.

## Project layout
| Path | What |
|---|---|
| `scripts/core/` | Rules only, no UI (RefCounted): `fight.gd`, `chant.gd`, `run_state.gd`, `enemy_defs.gd`, `enemy_state.gd`, `player_state.gd`, `spell_db.gd`, `artifacts.gd`, `bottles.gd`, `map_gen.gd`, `map_events.gd`, `boss_talk.gd`, `fuse_rules.gd` |
| `scripts/ui/` | Screens and widgets, all built in code (`scenes/main.tscn` is the only scene). `fight_screen.gd` is the fight; `ui_skin.gd` finds art by name; `ui_theme.gd` fonts and boards |
| `scripts/autoload/` | `Events` (signal bus), `GameData` (spell DB), `SaveManager` (`user://save.json` + `save_run.txt`), `Audio` |
| `data/` | `spells.json`; the user's hand-placed layouts (`enemy_ropes.json`, `event_layout_overrides.json`, `shop_layout_overrides.json`): never delete |
| `assets/` | `Global/` shared, `New/` and `Puppet/` per theme, same shape inside: see `assets/README.md` |
| `tools/` | Godot test/screenshot scripts (`*_impl.gd` + 5-line wrapper) and Python art/sound pipelines: see `tools/README.md` |
| `tests/` | Headless unit tests of the core |
| `docs/` | `art_progress.md` (what is still to do), `changelog/` (what was done, by month), design notes, audit and plans |

## Verify a change (cheapest first)
```
# every script parses (warnings are errors: project.godot [debug])
"C:\Program Files\Godot\Godot.exe" --headless --path . --script res://tools/check_scripts.gd
# unit tests (-- filter narrows to tests whose "file:name" contains it)
"C:\Program Files\Godot\Godot.exe" --headless --path . --script res://tests/run_tests.gd
# balance sim, headless
"C:\Program Files\Godot\Godot.exe" --headless --path . --script res://tools/sim.gd -- 60 new
# screenshots of every screen (windowed, off screen, no sound): SHOT_THEME=new|puppet
"C:\Program Files\Godot\Godot.exe" --path . --position 6000,0 --no-focus --audio-driver Dummy --script res://tools/shots.gd -- <out_dir>
```
After adding a `class_name` file or new art, run the editor once headless so Godot imports it: `--headless --editor --quit`.

## Working here
Two people commit to this repo. Read `CLAUDE.md` first: the settled rules, the code map, what is locked and what is free, and the end-of-session routine. `docs/audit_2026-11-12.md` lists the known debts and the plan to pay them.
````

**Kiểm chứng**: mọi lệnh trong README chạy được đúng như viết (chạy ít nhất `check_scripts` và `run_tests` bằng lệnh copy từ README). Không có từ "cast themselves", "Released by itself", "minhv", "godot_console" còn lại: `grep -n "cast themselves\|by itself\|minhv\|godot_console" README.md` rỗng.

---

## T2.5 Tài liệu tiến độ: `art_progress.md` chỉ còn việc chưa làm, lịch sử sang `docs/changelog/`

**Hiện trạng**: `docs/art_progress.md` 228 dòng. Dòng 1–4 là header **sai** (nói "New theme", `assets/ui/Fight UI.pdf`, "Last update 2026-10-05"). Dòng 6–77 = `## Done` (nhật ký, mới nhất ở trên). Dòng 78 `## To do`, trong đó chỉ 5 khối là to-do thật: `**Art still missing**` (79–84), `**Code**` (85–90), `**To check by eye…**` (91–95), `**Asking the artist**` (96–98), `**Housekeeping**` (122–125). Các khối còn lại từ 99 đến 228 (trừ 122–125) là nhật ký theo phiên (Cirus, Puppet Stage 2026-10-12/13, pass 3/4/5, 2026-10-17, 2026-10-18, HUD ver 2 round 3…).

**Bước**
1. `mkdir -p docs/changelog`. Tạo `docs/changelog/2026-10_11_art.md` với header:
   ```markdown
   # Art / UI changelog, October–November 2026
   Moved out of `docs/art_progress.md` on <ngày> (newest first). The live to-do list stays in `art_progress.md`.
   ```
   rồi dán **nguyên văn** (không sửa chữ): toàn bộ dòng 6–77 (bỏ dòng `## Done`), sau đó các khối nhật ký 99–121 và 126–228. Dùng Python đọc theo số dòng để cắt dán, không gõ tay. Số dòng phải kiểm lại bằng `grep -n "^## \|^\*\*" docs/art_progress.md` ngay trước khi cắt (Minh có thể đã thêm dòng).
2. `git mv docs/session_2026_10_17.md docs/changelog/2026-10-17_session.md` và sửa 2 chỗ trỏ tới nó (dòng cũ 163, 165, nay nằm trong changelog) thành đường dẫn mới.
3. Viết lại `docs/art_progress.md` còn:
   ```markdown
   # Art / UI: what is still to do

   The record of what was done is `docs/changelog/` (one file per month, newest entry on top). This file only holds open items.
   Art pipeline: ImageSet (prompts/styles live next to the art in `assets/**`), Tachnen cut at full size, importers in `tools/` (see `tools/README.md`). Never resize art.

   ## Art still missing
   <khối 79–84 nguyên văn>

   ## Code
   <khối 85–90, bỏ dòng về Default theme nếu Default đã không còn trong UiSkin.OPTIONS; kiểm bằng grep "Default" scripts/ui/ui_skin.gd>

   ## To check by eye
   <khối 91–95>

   ## Asking the artist
   <khối 96–98>

   ## Housekeeping
   <khối 122–125>
   ```
4. Sửa `CLAUDE.md` bước 2 của "Kết thúc phiên làm việc": "Record what was done in `docs/changelog/<YYYY-MM>_art.md` (new entry on top, create the month's file if missing) and what is still waiting in `docs/art_progress.md`".

**Kiểm chứng**: `wc -l docs/art_progress.md` ≈ 30–45; `grep -c "" docs/changelog/2026-10_11_art.md` ≈ 200 (= 72 + 23 + 103 dòng chuyển sang + vài dòng header); không mất nội dung: tổng dòng nội dung (trừ header mới) của hai file ≥ 224.

---

## T2.6 `CLAUDE.md`: sửa chỗ lệch thực tế

Sửa bằng Edit tool, từng chuỗi:
1. Dòng code map "Other screens: `map_screen`, `campfire_screen`, `shop_screen`, `apothecary_screen`, `fuse_screen`, …" → bỏ `apothecary_screen` (file đã xoá ở commit `23dd7d4`).
2. Câu "Themes: only `new` and `puppet` (the Default and Cirus looks were dropped; an old save that says so opens in New; the Cirus art is parked in `assets/_Archive/Circus`)" nằm **sau** câu liệt kê 5 theme → mâu thuẫn. Viết lại theo code: đọc `scripts/ui/ui_skin.gd:12–50` (`OPTIONS`, `roots()`, `theme_dir()`) và viết đúng một câu dạng "Settings offers `OPTIONS = [...]`; art roots per theme are `UiSkin.roots()`: <điền từ code>; `new` is a tools-only id (`set_theme("new")`); Default/Cirus were dropped, an old save naming them opens as <điền từ code `theme_id()`>." Nếu Circus đã xoá ở đợt 1, bỏ vế "parked in".
3. Mục Verify dòng 2 → `--headless --script res://tests/run_tests.gd` (đã đúng tên, nhưng thêm "(the only runner)").
4. Thêm vào cuối mục "Code map" một dòng: "Debts and plans: `docs/audit_2026-11-12.md`, `docs/plan_dot1_don_kho.md`, `docs/plan_dot2_chuan_chung.md`."
5. `.claude/skills/game-feel-vfx/SKILL.md` dòng 3: "for The Last Tree" → "for Behind the Curtain".

**Kiểm chứng**: `grep -n "apothecary\|The Last Tree" CLAUDE.md .claude/skills/game-feel-vfx/SKILL.md` rỗng (trừ nếu người dùng muốn giữ tên cũ ở đâu đó: hỏi nếu thấy chỗ khác).

---

## T2.7 Tools Python: một nơi cho đường dẫn, danh sách phụ thuộc, chỉ mục

**Hiện trạng**: 119 file `.py` phẳng trong `tools/`. 70 file hard-code đường dẫn máy này: `D:/GitHub Projects/Tachnen` (45 lần), `D:/GitHub Projects/ImageSet` (33), `E:/GitHub/ImageSet` (28, là thư mục **dữ liệu/output** của ImageSet trên ổ E), `D:/GitHub Projects/AnySFX` (8), `ReadAnyBook` (1), `AnyVideo` (1). Thư viện dùng: PIL, numpy, scipy, pymupdf, openpyxl, psd_tools, soundfile, `tachnen_core` (import từ thư mục Tachnen). 56 file import `asset_paths`; 10 file import `make_redo2` (nó là thư viện chung của các batch redo dù tên không nói vậy).

**7a. `tools/paths.py`** (file mới):
```python
"""Where the sister projects live on this machine. Every tool that reaches outside this repo imports these names;
set the environment variable to point elsewhere when a folder moves (e.g. BTC_IMAGESET_OUT=F:\\ImageSet)."""
import os


def _p(env: str, default: str) -> str:
    return os.path.normpath(os.environ.get(env, default))


TACHNEN = _p("BTC_TACHNEN_DIR", r"D:\GitHub Projects\Tachnen")          # background cutter (tachnen_core, its .venv python)
IMAGESET = _p("BTC_IMAGESET_DIR", r"D:\GitHub Projects\ImageSet")       # ImageSet code (main.py --batch)
IMAGESET_OUT = _p("BTC_IMAGESET_OUT", r"E:\GitHub\ImageSet")            # ImageSet data / outputs (the big pictures)
ANYSFX = _p("BTC_ANYSFX_DIR", r"D:\GitHub Projects\AnySFX")             # sound generator
READANYBOOK = _p("BTC_READANYBOOK_DIR", r"D:\GitHub Projects\ReadAnyBook")  # voices (its rvc_env python, Gemini TTS keys)
```
Trước khi ghi, **xác nhận ý nghĩa của hai đường dẫn ImageSet** bằng cách đọc 2 file dùng `E:/GitHub/ImageSet` (`grep -ln "E:/GitHub/ImageSet\|E:\\\\GitHub\\\\ImageSet" tools/*.py | head -2`) và 2 file dùng `D:/GitHub Projects/ImageSet`: cái nào gọi `main.py`/`multi.py` là code, cái nào đọc/ghi ảnh là output. Sửa comment cho đúng.

**7b. Chuyển sang `paths.py` chỉ những tool còn sống** = file sửa từ 2026-11-01 trở đi **và** có đường dẫn ngoài repo:
```
grep -lE "GitHub Projects|E:[\\/]+GitHub" $(find tools -maxdepth 1 -name '*.py' -newermt 2026-11-01) 
```
Với mỗi file trong danh sách: thay chuỗi đường dẫn bằng `paths.TACHNEN` / `paths.IMAGESET` / `paths.IMAGESET_OUT` / `paths.ANYSFX` (thêm `import paths` cạnh `import asset_paths`; giữ nguyên phần đuôi đường dẫn, ví dụ `os.path.join(paths.TACHNEN, ".venv", "Scripts", "python.exe")`). Mỗi file sửa xong: `python -c "import ast;ast.parse(open('<f>',encoding='utf-8').read())"`. **Không chạy** các tool đó (chúng gọi Gemini/Tachnen thật, tốn hạn mức). Tool cũ hơn 2026-11-01: để nguyên, chỉ ghi trong chỉ mục là "đường dẫn cứng".

**7c. `tools/requirements.txt`**:
```
# Python 3.12 (the same interpreter the exporters were written with). Tachnen's own .venv runs rembg/BiRefNet; ReadAnyBook's rvc_env runs the voice tools.
pillow
numpy
scipy
pymupdf
openpyxl
psd-tools
soundfile
```
Không cài gì trong task này (không có `.venv` của project; người dùng chạy bằng Python hệ thống/venv của app khác, giữ nguyên thói quen).

**7d. `tools/README.md`** (file mới): một bảng, mỗi tool một dòng, 4 cột `file | kind | what it does (from its docstring, one line) | status`. `kind` ∈ `lib` (được import bởi tool khác: `asset_paths`, `paths`, `make_redo2`, `make_merchant_voice`, `import_newui2_art`, `make_spell_sfx`, `make_shop_sfx`, `loudness`, `slot_pdf`, `import_puppet_ui`, `gemini_star`, `make_missing_icons`, `import_event_art`, `export_room_background`, `alpha_bleed`, `defringe_edge`), `pipeline` (được nhắc trong `CLAUDE.md`, `assets/README.md`, `docs/changelog/*` như bước tái tạo art), `one-off` (batch đã chạy xong, giữ để tra), `check` (Godot `.gd` kiểm tra/chụp). `status` ∈ `live`, `hard-coded paths`, `obsolete (see note)`. Lấy dòng mô tả từ docstring đầu file bằng script Python nhỏ (`ast.get_docstring`), đừng viết tay 119 dòng. Với `.gd` chỉ liệt kê các wrapper (không `_impl`), mô tả lấy từ comment `##` đầu file `_impl` nếu có, không thì để trống.
Đầu file README ghi 4 quy ước:
- Tool mới đọc đường dẫn ngoài repo qua `paths.py`, ghi vào `assets/` qua `asset_paths.py`.
- Không `.resize(`/`.thumbnail(` lên art; nếu cần ảnh tham chiếu nhỏ, nói rõ trong docstring và ghi ra thư mục `_Refs`.
- Script Godot: `x.gd` là wrapper 5 dòng, việc thật trong `x_impl.gd`; luôn `quit()` + timer guard; cửa sổ ở `--position 6000,0 --no-focus --audio-driver Dummy`.
- Chạy một lần rồi xong → đặt tên `make_*`/`import_*` và ghi ngày trong docstring.

**7e. Không gộp 120 wrapper `.gd` thành một** (mục 14 của audit): các `_impl` đọc `OS.get_cmdline_user_args()[0]` làm đường dẫn output, một wrapper chung sẽ phải đẩy tham số và sửa cả 120 impl → không đáng. Ghi quyết định này vào `tools/README.md`.

**Kiểm chứng**: `python -c "import sys;sys.path.insert(0,'tools');import paths,asset_paths;print(paths.TACHNEN)"`; mọi `.py` đã sửa parse được; `grep -c "" tools/README.md` ≈ 130–260.

---

## T2.8 Export preset: loại nguồn nặng khỏi gói — **[HỎI]** (vùng khoá: deploy)

**Hiện trạng**: cả preset "Windows Desktop" và "Web" có `export_filter="all_resources"`, `exclude_filter=""` → gói sẽ chứa mọi tài nguyên Godot import được, kể cả nhạc, ảnh nguồn không `.gdignore`, `docs/_ref`.

Đề nghị người dùng duyệt giá trị:
```
exclude_filter="docs/*, tools/*, shots*/*, screenshots/*, scrshot/*, *.pdf, *.psd, *.m4a, *.xlsx, assets/**/_Source/*, assets/**/_Refs/*, assets/**/_Backup*/*, assets/_Archive/*"
```
Nếu đồng ý, sửa 2 dòng `exclude_filter` trong `export_presets.cfg` (dòng 10 và 82). **Kiểm chứng** cần export template 4.6.2 đã cài (`%APPDATA%\Godot\export_templates\4.6.2.stable\`); nếu có: `"<Godot>" --headless --path . --export-release "Web" build/web/index.html` rồi `ls -la build/web/` và ghi kích thước `index.pck`; nếu không có template: ghi "chưa export thử" trong báo cáo, không cài template (tốn thời gian/dung lượng, không được yêu cầu).

---

## 9. Mẫu báo cáo cuối đợt

```
Đợt 2 — kết quả
- T2.1 warnings=errors: probe OK/không; N lỗi lộ ra trong M file; đã sửa K (liệt kê file); còn lại chờ: ...; commit <hash>.
- T2.2 một runner: bản cũ chạy ra ...; commit <hash>.
- T2.3 InputMap + dev gate: commit <hash>; keys_probe: F5 đổi rope_mode ✔/✘, F1 mở wiki ✔/✘.
- T2.4 README: commit <hash>; số điền: spells/enemies/bosses.
- T2.5 art_progress → changelog: commit <hash>; art_progress còn N dòng, changelog M dòng.
- T2.6 CLAUDE.md + skill: commit <hash>.
- T2.7 tools: paths.py, requirements, README; đã chuyển K tool sang paths.py (liệt kê); commit <hash>.
- T2.8 export filter: người dùng chọn ...; export thử: có/không, index.pck ... MB.
Chưa chạy thật: các tool Python đã sửa đường dẫn chưa chạy lại (gọi Gemini/Tachnen); bản export chưa thử nếu thiếu template.
Việc cho Minh: pull sau các commit này cần chạy `git lfs install` (nếu T1.5 chọn B) và biết F4–F7 nay là action `dev_*`.
```
