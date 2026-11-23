# Đợt 3 — Kiến trúc (làm từng lát nhỏ, có kiểm chứng; lập 2026-11-12)

Dựa trên `docs/audit_2026-11-12.md` mục 5 đợt 3 (hạng mục 15–21). Luật chung = mục 0 của `docs/plan_dot1_don_kho.md` (tiếng Việt, một lát một commit, không push trừ khi người dùng bảo, Edit tool / Python UTF-8, `[HỎI]` là dừng chờ). Mọi lát phải **không đổi hành vi**: sau mỗi lát `check_scripts` 134+/0 và `tests/run_tests.gd` 0 failed; lát đụng UI thêm ảnh trước/sau ≥ 2 theme (windowed, `--position 6000,0 --no-focus --audio-driver Dummy`, xem `tools/shots.gd`).

## Trạng thái

| Hạng mục | Trạng thái |
|---|---|
| 20. Test | **Xong**: `test_map_gen`, `test_fuse_rules`, `test_save_manager`, `test_run_state`; runner coi lỗi engine là test hỏng. Chưa làm: tách `test_fight.gd` (3k dòng) theo act/boss. |
| 21. Smoke UI | **Xong**: `tools/smoke_flow.gd` (5 theme). `tools/ui_playtest.gd` hỏng từ trước (kẹt `busy` ở trận 1, luồng stage mới), chưa sửa. |
| 19. Core bỏ tra SaveManager | **Xong**: `BossTalk.store`, `RunState.default_store`. |
| 18. Tách `main.gd` | **Xong**: `event_flow.gd`, `test_flow.gd` (1695 -> 935 dòng). |
| 15. Tách `fight_screen.gd` | **Xong một phần**: 9299 -> 1587 dòng, 5 helper. Chưa đạt: còn 7 chỗ `is_puppet()`/`is_newui2()` trong file chính (theme chưa chọn một lần ở `_ready`). |
| 16. `LayoutSet` | **Chưa làm** (~200 chỗ gọi `NewUiLayout.X`, ít lợi ích hành vi; nếu làm: chụp giá trị mọi static var từng theme trước/sau và so từng byte). |
| 17. Enemy sang JSON | **Chưa làm, cần Minh đồng ý** (JSON làm mất kiểu int/float và các ghi chú trong `enemy_defs.gd`; nên dùng `var_to_str` hoặc cast khi nạp). |

## Thứ tự đề nghị

1. L20b — test thêm (rủi ro thấp, chỉ thêm file trong `tests/`).
2. L21 — smoke UI headless (thêm tool, không đụng game).
3. L19 — core bỏ `get_node("SaveManager")`.
4. L18 — tách `main.gd`.
5. L16 — `LayoutSet` thay static var layout.
6. L15 — tách `fight_screen.gd` (lớn nhất, làm cuối, nhiều lát).
7. L17 — enemy/artifact/event sang JSON, **chỉ sau khi Minh đồng ý**.

Trước L15/L16/L18, **báo Minh pull và nhờ họ đừng sửa file đó trong lúc tách** (conflict). `fight.gd`, `fight_screen.gd`, `main.gd`, `ui_skin.gd`, `new_ui_layout.gd`, toàn `scripts/core` là vùng khoá: hỏi người dùng cho phép một lần ở đầu mỗi lát.

---

## L20b Test thêm (không [HỎI])
- `tests/test_run_state.gd`: `RunState.setup` + `make_fight`, phần thưởng sau trận (đọc `run_state.gd` tìm hàm rewards; test: số lựa chọn, không trùng, tôn trọng unlocked), save/load run (`SaveManager.save_run/load_run` round trip với `use_test_file`).
- Tách `tests/test_fight.gd` (~3 000 dòng) thành `test_fight_core.gd` (cơ chế chung) và một file mỗi act/boss (`test_fight_act1.gd`, `test_fight_act2.gd`, `test_fight_act3.gd`…) bằng cách **chuyển nguyên hàm**, không sửa nội dung; helper dùng chung (`_fight`, `_set_hp`, `_all`) chuyển vào lớp cha `tests/fight_case.gd` (`extends TestCase`). Kiểm chứng: tổng số test không đổi (trừ test mới), 0 failed.

## L21 Smoke UI một lệnh
`tools/smoke_flow.gd` + `smoke_flow_impl.gd` (mẫu `aa_shot`): với mỗi theme trong `UiSkin.OPTIONS`, `SaveManager.use_test_file`, đặt theme, mở `Main`, đi menu → bắt đầu run → map → vào một trận → thắng bằng cách tiêu diệt kẻ địch qua API thật (xem `tools/stage_flow_test.gd`, `ui_playtest.gd` để mượn đúng hàm) → về map. Chỉ assert: không có `push_error`/`SCRIPT ERROR` trong log, node `Main` còn sống, số trận đúng. Cửa sổ ngoài màn hình, không tiếng, `quit()` + timer guard 120 s. Ghi lệnh vào `README.md` mục Verify. Không gắn vào workflow deploy.

## L19 Core không gọi `get_node("SaveManager")` [vùng khoá: hỏi]
`grep -rn "get_node(\"SaveManager\")\|/root/SaveManager" scripts/core` → với mỗi chỗ (`BossTalk`, `RunState`…) đổi thành một biến `store` được `main.gd` tiêm (mẫu: `note_store` đã có). Mặc định `store = null` cho test; hàm cần store phải chịu được null. Kiểm chứng: tests + keys_probe + một trận qua `tools/stage_flow_test.gd`.

## L18 Tách `main.gd` [vùng khoá: hỏi]
- `scripts/event_flow.gd`: `_show_event`, `_event_result`, `_event_recycle`, `_bear_scene` và hàm phụ chỉ chúng dùng.
- `scripts/test_flow.gd`: room test, rope editor, test fight (`_test_mode`, `_toggle_rope_mode`, `show_room_test`…).
- Cách làm: lớp `RefCounted` giữ tham chiếu `main`, hàm ở `main.gd` chỉ còn chuyển tiếp một dòng; **không đổi tên hàm công khai** mà màn khác gọi (`grep` trước). Mỗi lát một nhóm hàm, chạy `check_scripts` + tests + `tools/keys_probe.gd` + `tools/stage_flow_test.gd`.

## L16 `LayoutSet` thay static var [vùng khoá: hỏi]
`NewUiLayout`/`Hud2Layout` đang giữ static var (`use()`, `apply_minh()`). Tạo `LayoutSet` (RefCounted) chứa các giá trị đó; `use()`/`apply_minh()` trở thành hàm tạo; HUD nhận LayoutSet lúc tạo. Làm từng theme một (hud2 → minhhud → newui2), mỗi theme có ảnh trước/sau. Ngưng nếu ảnh khác dù 1 px.

## L15 Tách `fight_screen.gd` (5k dòng) [vùng khoá: hỏi; làm cuối]
Trục tách có sẵn theo tên hàm: HUD Puppet (`fight_hud_puppet.gd`), HUD New UI chung cho new_ui/newui2/hud2/minhhud (`fight_hud_newui.gd`), animation (`fight_anim.gd`: `_anim_event` ~510 dòng → bảng `op → hàm`), input (`fight_input.gd`, phím trong trận). Mục tiêu: file chính < 2 000 dòng, không còn `is_puppet()` trong file chính (theme chọn một lần lúc `_ready`). **Chỉ chuyển code, không sửa nội dung hàm.** Mỗi lát một nhóm, ảnh trước/sau 2 theme (`tools/puppet_fight_shot.gd`, `SHOT_THEME=new|puppet`), tests, `tools/ui_playtest.gd`. Đọc file theo hàm (`grep -n "func _"`), không đọc cả file.

## L17 Enemy/artifact/event sang JSON [HỎI: cần Minh]
Giữ nguyên schema dict của `enemy_defs.gd`; `data/enemies.json` + loader; `tools/dump_enemies.gd` đối chiếu trước/sau (dump cũ và mới phải giống từng byte). Mục tiêu giảm conflict `enemy_defs.gd`. Làm sau khi Minh đồng ý và hai bên thống nhất ai sửa file nào trong thời gian chuyển.

## Nguyên tắc sau đợt 3 (ghi vào CLAUDE.md khi xong)
- PR đụng `scripts/core` phải có test mới hoặc sửa trong `tests/`.
- PR đụng `fight_screen`/`ui_skin`/`ui_theme`/`*_layout` phải có ảnh trước/sau ≥ 2 theme.
- Không thêm `static var` mới trong `scripts/ui` trừ cache bất biến (texture, font).
