# Việc cần làm: T2.1 — bật cảnh báo GDScript thành lỗi (cho model Fable)

Bối cảnh: `docs/plan_dot2_chuan_chung.md` mục T2.1. Ngày lập: 2026-11-12. Số liệu đo trên HEAD sau T2.7. Luật chung = mục 0 của `docs/plan_dot1_don_kho.md` (tiếng Việt, một task một commit, không push, Edit tool / Python UTF-8, không đổi hành vi).

## Quyết định của người dùng
- Người dùng muốn model Fable chạy việc này để an toàn. **Chưa** đồng ý rõ cho việc sửa 5 file khoá (`fight.gd`, `fight_screen.gd`, `enemy_defs.gd`, `run_state.gd`, `main.gd`): bước 0 dưới đây phải hỏi.
- Phương án đề nghị (b): bật `[debug]` ngay, hạ `incompatible_ternary` và `unused_signal` xuống `1` (19 + 8 chỗ ồn, sửa thường đổi cách viết nhiều), sửa hết phần còn lại.

## Bước 0 — hỏi một lần trước khi làm
Hỏi người dùng: (1) chốt phương án (a) sửa dần / (b) hạ 2 loại xuống 1 / (c) để nguyên; (2) có cho sửa 5 file khoá bằng các sửa cơ học dưới đây không (họ có thể nói chỉ sửa file không khoá). Không đoán.

## Bước 1 — chuẩn bị
1. `git status --short`: không có file đã track bị sửa. HEAD là commit Conventions T2.7 (`ea6fa68`) hoặc mới hơn.
2. Thêm vào `project.godot` (section `[debug]`, đặt giữa `[autoload]` và `[display]`) khối trong plan_dot2 T2.1 bước 1. Nếu phương án (b): đặt `gdscript/warnings/incompatible_ternary=1` và `gdscript/warnings/unused_signal=1`.
3. Lấy danh sách lỗi: `"C:\Program Files\Godot\Godot.exe" --headless --path . --script res://tools/check_scripts.gd > out.txt 2>&1` (ghi ra scratchpad), rồi `grep -B0 -A2 "treated as error" out.txt`; mỗi lỗi kèm dòng `at: GDScript::reload (res://file:dòng)`. Bảng dưới là số liệu ngày 12/11, dòng có thể lệch nếu Minh đã sửa.

## Quy tắc sửa (không đổi hành vi) — nhắc lại từ plan_dot2
- `unused_parameter`: thêm `_` trước tên (`_delta`); KHÔNG xoá tham số.
- `unused_variable`: xoá dòng nếu vế phải không có tác dụng phụ; nếu vế phải gọi hàm thì chỉ giữ lời gọi trần.
- "declared below in the parent block" (biến cục bộ trùng tên với biến khai báo sau trong scope cha): đổi tên biến cục bộ (hậu tố `_l` hoặc tên rõ hơn), sửa mọi chỗ dùng trong đúng block đó.
- `same name as a built-in` (`seed`, `len`): đổi tên biến cục bộ.
- `shadowed_variable`: đổi tên biến cục bộ, không đổi tên thành viên.
- `Unreachable code`: xoá phần sau `return` chỉ khi chắc chắn là code chết; nếu `return` thừa thì xoá `return`. Nghi ngờ: ghi lại, hỏi.
- `ternary operator values not mutually compatible` (nếu không hạ xuống 1): ép kiểu cùng một nhánh cho khớp cách dùng ở dòng dưới, KHÔNG đổi giá trị trả về.
- `Standalone ternary`: biến thành `if/else` giữ nguyên hiệu ứng.
- Mọi loại khác, hoặc sửa nào buộc phải đổi hành vi (biến "unused" hoá ra là bug): KHÔNG sửa, ghi vào báo cáo.

## Bước 2 — sửa theo nhóm, mỗi nhóm một commit
Thứ tự: (A) file nhỏ không khoá (mọi file có ≤ 3 lỗi và không nằm trong 5 file khoá); (B) `audio.gd`, `creature.gd`, `ink.gd`, `event_stage.gd`, `shop_screen.gd`, `fuse_screen.gd`; (C) 4 file khoá còn lại (`main.gd`, `enemy_defs.gd`, `fight.gd`, `run_state.gd`) nếu được phép; (D) `fight_screen.gd` (29 lỗi, đọc theo hàm bằng `grep -n "func _"`, không đọc cả file). Sau mỗi nhóm: `check_scripts` (chỉ được còn lỗi của nhóm chưa làm) + `tests/run_tests.gd` (189 tests, 0 failed).
Mẫu commit: `Conventions (đợt 2, T2.1): sửa cảnh báo nhóm X` + dòng Co-Authored-By của phiên.

## Bước 3 — kết thúc
1. `check_scripts` → `134 scripts, 0 failed` (file có ghi chú đã hạ xuống 1 thì không tính). `run_tests.gd` → `189 tests, 0 failed`.
2. Chạy lại `tools/keys_probe.gd` (lệnh trong tools/README.md; cửa sổ ngoài màn hình, không tiếng) để chắc F1/F5/F7 vẫn chạy.
3. `CLAUDE.md`, mục Verify dòng 1: thay "warnings are errors" bằng "warnings are errors (`project.godot [debug] gdscript/warnings/* = 2`, so `check_scripts` fails on them)" (nếu hạ 2 loại xuống 1: nói rõ hai loại đó).
4. Báo cáo: số lỗi đã sửa theo loại, file nào bỏ qua và vì sao, commit.

## Số liệu ngày 2026-11-12 (136 lỗi, 42 file)

Theo loại: unused_parameter 48, unused_variable 26, declared_below 20, ternary 20, other 9, unused_signal 8, shadow 3, unreachable 2

| file | dòng | loại | thông báo |
|---|---:|---|---|
| scripts/ui/fight_screen.gd | 128 | other | The class variable "_info_row" is declared but never used in the class. |
| scripts/ui/fight_screen.gd | 129 | other | The class variable "_info_text" is declared but never used in the class. |
| scripts/ui/fight_screen.gd | 641 | unused_parameter | The local function parameter "name" is shadowing an already-declared property in the base class "Node". |
| scripts/ui/fight_screen.gd | 950 | other | The class variable "_tube_plate" is declared but never used in the class. |
| scripts/ui/fight_screen.gd | 1696 | ternary | Values of the ternary operator are not mutually compatible. |
| scripts/ui/fight_screen.gd | 1752 | ternary | Values of the ternary operator are not mutually compatible. |
| scripts/ui/fight_screen.gd | 1837 | unused_variable | The local variable "tr" is shadowing an already-declared method in the base class "Object". |
| scripts/ui/fight_screen.gd | 1850 | unused_variable | The local variable "tr" is shadowing an already-declared method in the base class "Object". |
| scripts/ui/fight_screen.gd | 1894 | unused_variable | The local variable "tr" is shadowing an already-declared method in the base class "Object". |
| scripts/ui/fight_screen.gd | 2241 | unused_variable | The local variable "arrive" is shadowing an already-declared variable at line 80 in the current class. |
| scripts/ui/fight_screen.gd | 2340 | unreachable | Unreachable code (statement after return) in function "_sync_reels()". |
| scripts/ui/fight_screen.gd | 3119 | unused_variable | The local variable "full_w" is declared but never used in the block. If this is intended, prefix it with an un |
| scripts/ui/fight_screen.gd | 4005 | ternary | Values of the ternary operator are not mutually compatible. |
| scripts/ui/fight_screen.gd | 4738 | shadow | The variable "seed" has the same name as a built-in function. |
| scripts/ui/fight_screen.gd | 4762 | unused_parameter | The parameter "it" is never used in the function "<anonymous lambda>()". If this is intended, prefix it with a |
| scripts/ui/fight_screen.gd | 5253 | declared_below | The variable "body" is declared below in the parent block. |
| scripts/ui/fight_screen.gd | 5500 | declared_below | The variable "idx" is declared below in the parent block. |
| scripts/ui/fight_screen.gd | 6038 | declared_below | The variable "got" is declared below in the parent block. |
| scripts/ui/fight_screen.gd | 7160 | unused_variable | The local variable "size" is shadowing an already-declared property in the base class "Control". |
| scripts/ui/fight_screen.gd | 7658 | ternary | Values of the ternary operator are not mutually compatible. |
| scripts/ui/fight_screen.gd | 7795 | ternary | Values of the ternary operator are not mutually compatible. |
| scripts/ui/fight_screen.gd | 7850 | declared_below | The variable "ic" is declared below in the parent block. |
| scripts/ui/fight_screen.gd | 7928 | declared_below | The variable "ic" is declared below in the parent block. |
| scripts/ui/fight_screen.gd | 8107 | ternary | Values of the ternary operator are not mutually compatible. |
| scripts/ui/fight_screen.gd | 8667 | unused_signal | The local variable "blocked" is shadowing an already-declared signal at line 39 in the current class. |
| scripts/ui/fight_screen.gd | 8741 | unused_parameter | The parameter "dmg" is never used in the function "_sword_slash()". If this is intended, prefix it with an und |
| scripts/ui/fight_screen.gd | 8849 | unused_parameter | The parameter "dmg" is never used in the function "_spear_stab()". If this is intended, prefix it with an unde |
| scripts/ui/fight_screen.gd | 9116 | unused_variable | The local variable "info" is declared but never used in the block. If this is intended, prefix it with an unde |
| scripts/ui/fight_screen.gd | 9221 | unused_variable | The local variable "target" is declared but never used in the block. If this is intended, prefix it with an un |
| scripts/autoload/audio.gd | 115 | unused_parameter | The local function parameter "name" is shadowing an already-declared property in the base class "Node". |
| scripts/autoload/audio.gd | 165 | unused_parameter | The local function parameter "name" is shadowing an already-declared property in the base class "Node". |
| scripts/autoload/audio.gd | 202 | unused_parameter | The local function parameter "name" is shadowing an already-declared property in the base class "Node". |
| scripts/autoload/audio.gd | 250 | unused_parameter | The local function parameter "name" is shadowing an already-declared property in the base class "Node". |
| scripts/autoload/audio.gd | 262 | unused_parameter | The local function parameter "name" is shadowing an already-declared property in the base class "Node". |
| scripts/autoload/audio.gd | 267 | unused_parameter | The local function parameter "name" is shadowing an already-declared property in the base class "Node". |
| scripts/autoload/audio.gd | 306 | unused_parameter | The local function parameter "name" is shadowing an already-declared property in the base class "Node". |
| scripts/autoload/audio.gd | 321 | unused_parameter | The local function parameter "name" is shadowing an already-declared property in the base class "Node". |
| scripts/autoload/audio.gd | 346 | unused_parameter | The local function parameter "name" is shadowing an already-declared property in the base class "Node". |
| scripts/autoload/audio.gd | 365 | unused_parameter | The local function parameter "name" is shadowing an already-declared property in the base class "Node". |
| scripts/ui/creature.gd | 602 | unused_variable | The local variable "big" is shadowing an already-declared variable at line 8 in the current class. |
| scripts/ui/creature.gd | 663 | other | The class variable "_bk_hand" is declared but never used in the class. |
| scripts/ui/creature.gd | 664 | other | The class variable "_bk_foot" is declared but never used in the class. |
| scripts/ui/creature.gd | 922 | unused_parameter | The local function parameter "hit" is shadowing an already-declared function at line 291 in the current class. |
| scripts/ui/creature.gd | 1030 | declared_below | The variable "s" is declared below in the parent block. |
| scripts/ui/creature.gd | 1214 | unused_variable | The local variable "unveiling" is shadowing an already-declared function at line 1561 in the current class. |
| scripts/ui/creature.gd | 1295 | unused_parameter | The local function parameter "name" is shadowing an already-declared property in the base class "Node". |
| scripts/ui/creature.gd | 1404 | declared_below | The variable "img" is declared below in the parent block. |
| scripts/ui/creature.gd | 1429 | declared_below | The variable "r" is declared below in the parent block. |
| scripts/ui/creature.gd | 1494 | declared_below | The variable "cue" is declared below in the parent block. |
| scripts/main.gd | 754 | declared_below | The variable "res" is declared below in the parent block. |
| scripts/main.gd | 758 | declared_below | The variable "after" is declared below in the parent block. |
| scripts/main.gd | 781 | declared_below | The variable "after" is declared below in the parent block. |
| scripts/main.gd | 1112 | unused_parameter | The parameter "ev" is never used in the function "_recycle_on_stage()". If this is intended, prefix it with an |
| scripts/main.gd | 1183 | ternary | Values of the ternary operator are not mutually compatible. |
| scripts/main.gd | 1297 | unused_parameter | The parameter "ev" is never used in the function "_note_done()". If this is intended, prefix it with an unders |
| scripts/main.gd | 1413 | unused_parameter | The parameter "f" is never used in the function "_begin_stage_fight()". If this is intended, prefix it with an |
| scripts/ui/event_stage.gd | 336 | unused_parameter | The local function parameter "size" is shadowing an already-declared property in the base class "Control". |
| scripts/ui/event_stage.gd | 522 | unreachable | Unreachable code (statement after return) in function "_choice_text()". |
| scripts/ui/event_stage.gd | 743 | unused_parameter | The local function parameter "say" is shadowing an already-declared function at line 204 in the current class. |
| scripts/ui/event_stage.gd | 1268 | unused_variable | The local variable "tr" is shadowing an already-declared method in the base class "Object". |
| scripts/ui/event_stage.gd | 2107 | unused_parameter | The parameter "lay" is never used in the function "_build_text()". If this is intended, prefix it with an unde |
| scripts/ui/event_stage.gd | 2743 | unused_parameter | The local function parameter "size" is shadowing an already-declared property in the base class "Control". |
| scripts/ui/ink.gd | 22 | unused_parameter | The function parameter "seed" has the same name as a built-in function. |
| scripts/ui/ink.gd | 47 | unused_parameter | The function parameter "seed" has the same name as a built-in function. |
| scripts/ui/ink.gd | 64 | unused_parameter | The function parameter "seed" has the same name as a built-in function. |
| scripts/ui/ink.gd | 82 | unused_parameter | The function parameter "seed" has the same name as a built-in function. |
| scripts/ui/ink.gd | 97 | unused_parameter | The function parameter "seed" has the same name as a built-in function. |
| scripts/ui/ink.gd | 137 | shadow | The variable "seed" has the same name as a built-in function. |
| scripts/ui/shop_screen.gd | 276 | unused_parameter | The parameter "behind" is never used in the function "_place_merchant()". If this is intended, prefix it with  |
| scripts/ui/shop_screen.gd | 596 | unused_variable | The local variable "tr" is shadowing an already-declared method in the base class "Object". |
| scripts/ui/shop_screen.gd | 665 | unused_variable | The local variable "tr" is shadowing an already-declared method in the base class "Object". |
| scripts/ui/shop_screen.gd | 929 | unused_variable | The local variable "tr" is shadowing an already-declared method in the base class "Object". |
| scripts/ui/shop_screen.gd | 1364 | unused_variable | The local variable "bottles_total" is declared but never used in the block. If this is intended, prefix it wit |
| scripts/ui/fuse_screen.gd | 144 | ternary | Values of the ternary operator are not mutually compatible. |
| scripts/ui/fuse_screen.gd | 584 | declared_below | The variable "at" is declared below in the parent block. |
| scripts/ui/fuse_screen.gd | 594 | declared_below | The variable "at" is declared below in the parent block. |
| scripts/ui/fuse_screen.gd | 626 | unused_signal | The local variable "back" is shadowing an already-declared signal at line 8 in the current class. |
| scripts/autoload/events.gd | 4 | unused_signal | The signal "toast" is declared but never explicitly used in the class. |
| scripts/autoload/events.gd | 5 | unused_signal | The signal "screen_requested" is declared but never explicitly used in the class. |
| scripts/autoload/events.gd | 6 | unused_signal | The signal "codex_changed" is declared but never explicitly used in the class. |
| scripts/core/enemy_defs.gd | 706 | unused_parameter | The function parameter "floor" has the same name as a built-in function. |
| scripts/core/enemy_defs.gd | 712 | declared_below | The variable "pool" is declared below in the parent block. |
| scripts/core/enemy_defs.gd | 737 | unused_parameter | The function parameter "floor" has the same name as a built-in function. |
| scripts/core/fight.gd | 1772 | declared_below | The variable "e" is declared below in the parent block. |
| scripts/core/fight.gd | 2286 | unused_variable | The local variable "lines" is shadowing an already-declared variable at line 50 in the current class. |
| scripts/core/fight.gd | 2339 | other | The local "for" iterator variable "start" is shadowing an already-declared function at line 155 in the current |
| scripts/ui/vfx.gd | 144 | unused_parameter | The local function parameter "size" is shadowing an already-declared property in the base class "Control". |
| scripts/ui/vfx.gd | 161 | unused_parameter | The local function parameter "size" is shadowing an already-declared property in the base class "Control". |
| scripts/ui/vfx.gd | 174 | unused_parameter | The local function parameter "size" is shadowing an already-declared property in the base class "Control". |
| scripts/ui/intent_chip.gd | 270 | ternary | Values of the ternary operator are not mutually compatible. |
| scripts/ui/intent_chip.gd | 343 | declared_below | The variable "h" is declared below in the parent block. |
| scripts/ui/intent_chip.gd | 368 | ternary | Values of the ternary operator are not mutually compatible. |
| scripts/ui/sfx_test_screen.gd | 238 | unused_signal | The local variable "back" is shadowing an already-declared signal at line 9 in the current class. |
| scripts/ui/sfx_test_screen.gd | 302 | unused_parameter | The local function parameter "size" is shadowing an already-declared property in the base class "Control". |
| scripts/ui/sfx_test_screen.gd | 411 | unused_variable | The local variable "name" is shadowing an already-declared property in the base class "Node". |
| scripts/core/run_state.gd | 84 | unused_parameter | The function parameter "seed" has the same name as a built-in function. |
| scripts/core/run_state.gd | 1256 | declared_below | The variable "id" is declared below in the parent block. |
| scripts/ui/ui_skin.gd | 179 | unused_parameter | The local function parameter "frame" is shadowing an already-declared function at line 165 in the current clas |
| scripts/ui/ui_skin.gd | 352 | unused_variable | The local variable "icon" is shadowing an already-declared function at line 201 in the current class. |
| scripts/ui/spell_fx.gd | 491 | unused_parameter | The parameter "from" is never used in the function "_execute()". If this is intended, prefix it with an unders |
| scripts/ui/spell_fx.gd | 647 | unused_variable | The local variable "tr" is shadowing an already-declared method in the base class "Object". |
| scripts/ui/amber_counter.gd | 28 | ternary | Values of the ternary operator are not mutually compatible. |
| scripts/ui/amber_counter.gd | 55 | shadow | The variable "len" has the same name as a built-in function. |
| scripts/ui/keyword_text.gd | 9 | unused_parameter | The local function parameter "text" is shadowing an already-declared property in the base class "RichTextLabel |
| scripts/ui/keyword_text.gd | 29 | unused_parameter | The local function parameter "text" is shadowing an already-declared property in the base class "RichTextLabel |
| scripts/ui/spell_card.gd | 83 | ternary | Values of the ternary operator are not mutually compatible. |
| scripts/ui/spell_card.gd | 769 | unused_variable | The local variable "n" is declared but never used in the block. If this is intended, prefix it with an undersc |
| scripts/ui/puppet_stage.gd | 102 | unused_parameter | The local function parameter "name" is shadowing an already-declared property in the base class "Node". |
| scripts/ui/puppet_stage.gd | 114 | unused_parameter | The local function parameter "name" is shadowing an already-declared property in the base class "Node". |
| scripts/ui/codex_screen.gd | 96 | declared_below | The variable "t" is declared below in the parent block. |
| scripts/ui/codex_screen.gd | 117 | ternary | Values of the ternary operator are not mutually compatible. |
| scripts/ui/enemy_view.gd | 183 | ternary | Values of the ternary operator are not mutually compatible. |
| scripts/ui/enemy_view.gd | 439 | unused_signal | The local variable "hidden" is shadowing an already-declared signal in the base class "CanvasItem". |
| scripts/ui/fish_game.gd | 94 | ternary | Values of the ternary operator are not mutually compatible. |
| scripts/ui/fish_game.gd | 187 | ternary | Values of the ternary operator are not mutually compatible. |
| scripts/ui/test_mode_screen.gd | 64 | unused_parameter | The local function parameter "size" is shadowing an already-declared property in the base class "Control". |
| scripts/ui/test_mode_screen.gd | 426 | unused_variable | The local variable "tr" is shadowing an already-declared method in the base class "Object". |
| scripts/ui/tutorial_screen.gd | 336 | unused_parameter | The local function parameter "name" is shadowing an already-declared property in the base class "Node". |
| scripts/ui/tutorial_screen.gd | 346 | unused_parameter | The local function parameter "name" is shadowing an already-declared property in the base class "Node". |
| scripts/ui/wiki_screen.gd | 47 | other | The local "for" iterator variable "name" is shadowing an already-declared property in the base class "Node". |
| scripts/ui/wiki_screen.gd | 99 | other | The local "for" iterator variable "name" is shadowing an already-declared property in the base class "Node". |
| scripts/ui/artifact_bar.gd | 89 | unused_parameter | The local function parameter "id" is shadowing an already-declared variable at line 79 in the current class. |
| scripts/ui/ui_theme.gd | 435 | ternary | Values of the ternary operator are not mutually compatible. |
| scripts/ui/bottle_vapor.gd | 39 | unused_parameter | The local function parameter "name" is shadowing an already-declared property in the base class "Node". |
| scripts/ui/campfire_screen.gd | 202 | unused_variable | The local variable "size" is shadowing an already-declared property in the base class "Control". |
| scripts/ui/dragon_rig.gd | 306 | unused_variable | The local variable "tr" is shadowing an already-declared method in the base class "Object". |
| scripts/ui/farm_game.gd | 295 | declared_below | The variable "skin" is declared below in the parent block. |
| scripts/ui/hud2_layout.gd | 97 | unused_variable | The local variable "tr" is shadowing an already-declared method in the base class "Object". |
| scripts/ui/hud_bar.gd | 65 | ternary | Standalone ternary operator (the return value is being discarded). |
| scripts/ui/pause_menu.gd | 81 | unused_signal | The local variable "hidden" is shadowing an already-declared signal in the base class "CanvasItem". |
| scripts/ui/menu_actors.gd | 135 | unused_variable | The local variable "r" is declared but never used in the block. If this is intended, prefix it with an undersc |
| scripts/ui/message_screen.gd | 104 | ternary | Values of the ternary operator are not mutually compatible. |
| scripts/ui/new_ui_layout.gd | 401 | unused_variable | The local variable "p" is declared but never used in the block. If this is intended, prefix it with an undersc |
| scripts/ui/slot_machine.gd | 64 | other | The class variable "_stopped" is declared but never used in the class. |
| scripts/ui/stripe_hp_bar.gd | 43 | unused_parameter | The local function parameter "shield" is shadowing an already-declared variable at line 8 in the base class "H |
| scripts/ui/tutorial_coach.gd | 37 | ternary | Values of the ternary operator are not mutually compatible. |
