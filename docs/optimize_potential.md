# Optimize potential (nghiên cứu 2026-11-12)

Ghi chú các việc CÓ THỂ làm để game nhẹ hơn / gọn hơn. Chưa làm gì cả. Các con số tính từ file, chưa đo runtime (chưa đo FPS/VRAM thật).

Luật không đổi: KHÔNG resize ảnh (không dùng `process/size_limit`). Đổi kiểu import (nén VRAM, mipmap) không đụng PNG gốc nên được phép.

## 1. Texture (lợi nhất)

- Cả 1453 PNG (ngoài `_Source`...) đang import **Lossless** (`compress/mode=0`). Nạp vào GPU thành RGBA8 (4 byte/pixel): nếu nạp hết ≈ 4,5 GB; nén VRAM (BPTC/S3TC, 1 byte/pixel) ≈ 1,1 GB. Thực tế mỗi màn chỉ nạp một phần.
- Nhóm nặng (RGBA nếu nạp hết): Enemies/Act2 ~984 MB (170 ảnh), UI/NewUiV2 ~652 MB, UI/MinhHUD ~394 MB, Enemies/Act1 ~244 MB, Icon/Bottle ~168 MB.
- **Việc:** đổi ảnh lớn (enemies, stage, events, board UI) sang VRAM Compressed (BPTC); giữ Lossless cho icon nhỏ. Thử 5-10 ảnh trước, so bằng mắt (để ý banding ở nền đen/hào quang), rồi áp theo thư mục.
- `export_presets.cfg` chỉ bật `s3tc_bptc`; export Web/mobile phải bật thêm `etc2_astc`.
- **Mipmap:** 331/421 ảnh có cạnh > 1024 px không bật mipmap (~3,3 GB RGBA), dù vẽ ở 200-600 px. Code đã đặt `LINEAR_WITH_MIPMAPS` (`enemy_view.gd:97`, `fight_hud.gd:493`...) nhưng không có tác dụng nếu ảnh không bật `mipmaps/generate`. Bật cho ảnh lớn: hết răng cưa/nhấp nháy, đỡ băng thông (+33% bộ nhớ, vẫn rẻ hơn Lossless nếu kèm BPTC).
- **MSAA 2D** đang 4x (`msaa_2d=2`). Art chủ yếu là quad có texture nên ít lợi. Thêm tuỳ chọn Settings (Tắt/2x/4x), mặc định 2x; đo bằng Show FPS trước khi quyết.

## 2. Dung lượng

- 117 MP3 nhạc cũ 320 kbps = 405 MB (7,2 MB/file). Đổi sang OGG ~128-160 kbps → ~150-200 MB, hoặc bỏ 2 theme cũ ("anysong_nov02", "old") khỏi bản export. Chú ý: Music Edit ghim bài theo tên file có đuôi, đổi đuôi làm mất ghim (xem `plan_dot1_don_kho.md`, đoạn đọc `audio.gd:450-500`).
- `Pianist/fur_elise.wav`, `turkish_march.wav` giữ WAV (code nạp đích danh `.wav`, `pianist_song.gd:51`). `Puppet/SFX/Event Voice/merry puppets.wav` (17 MB) có thể đổi OGG.
- Ảnh trùng hệt ≈ 43 MB: `Cart.png` = `Cart_old.png` = `event_cart.png`; `UI/NewUiV2/btn_*.png` = `Btn/*.png`; `wall_left` = `wall_right`; `NewUiCabinet/_Original/Block*.png` = `NewUi/nu_block_*.png`; `Dragon2/head.png` = `dragon_rig/head.png`; `bush_1` = `event_bush`; `samurai_bottle` = `samurai_retainer_rig/bottle`; `chant_slot_empty` = `hud2_cup`. Gộp về một file (nhớ sửa chỗ tham chiếu).
- `docs/audit_2026-11-12.md` P2.6: ước lượng ~370 file / 670 MB không được tham chiếu theo tên (thô, kiểm lại trước khi xoá).
- `.git` 5,6 GB: đã nằm trong plan housekeeping, không lặp lại ở đây.

## 3. Code / runtime

- 108 chỗ `queue_redraw()`, 67 file có `_process`, chỉ 1 chỗ `set_process(false)`. Node vẽ lại mỗi frame dù không đổi/đang ẩn:
  - `backdrop_fx.gd` (lá/đom đóm/tuyết), `stage_lights.gd` (7 hình tròn mỗi đèn mỗi frame), `hp_bar.gd` (luôn `queue_redraw()`; chỉ cần khi `_ghost`/`_flash`/`_crack` còn chạy).
  - `spell_card.gd:700`: mỗi thẻ kiểm `get_global_rect().has_point(mouse)` mỗi frame → dùng `mouse_entered/exited`.
  - Cách sửa: chỉ redraw khi đổi; tắt `set_process` khi ẩn/không có gì chạy.
- Không có `ResourceLoader.load_threaded_request` nào: vào màn mới là giải nén ảnh 2-5 MB ngay trên luồng chính → giật khung đầu. Nạp trước ảnh trận kế tiếp lúc ở màn map.
- `Shader.new()` + `sh.code = ...` tạo cho từng instance (`hp_bar.gd:36`, `minh_parts.gd:43`, `campfire_screen.gd`...). Dùng chung một ShaderMaterial (static) hoặc file `.gdshader`, tránh biên dịch lại.
- Biên dịch trước shader (dissolve, holo, HP fill...) một lần ở menu để lần đầu chiếu hiệu ứng không giật.
- Hiệu ứng "chụp thẻ rồi tan" dùng `SubViewport` + `UPDATE_ALWAYS` + `get_image()` (`fight_anim.gd:1518-1672, 2627`): chỉ xem lại nếu thấy giật khi dùng Power; có thể `UPDATE_ONCE`.

## 4. Học từ Saltline (`Downloads\saltline_1.html`, 1,4 MB, three.js, không asset)

- Đẹp nhờ code: hình khối + ánh sáng + tone mapping + auto-exposure bằng shader, không texture. Art vẽ tay của mình không đi hết đường này.
- Tự điều chỉnh chất lượng: trần số pixel theo mức (low 1M / medium 1,5M / high 2,3M / ultra 3,7M), frame time cao thì giảm `scale`, chạm đáy thì hạ mức chất lượng, có thời gian chờ ổn định để không nhảy qua lại.
- `compileAsync` biên dịch shader trước; MSAA tắt ở renderer chính; dừng khi ẩn tab; pixel ratio tối đa 2.
- Áp dụng: mức chất lượng tự động (tắt dần MSAA → hiệu ứng nền lá/đom đóm/tuyết → đèn sân khấu khi frame time cao); biên dịch trước shader; thêm vignette/grain/color grading/additive glow bằng shader nhỏ thay vì thêm ảnh lớn (đã có `danger_vignette`, `black_hole`, `ephemeral_static`). SFX procedural thì để sau, dễ làm kém chất lượng.

## Thứ tự gợi ý

1. VRAM Compressed + mipmap thử trên vài ảnh, rồi áp theo thư mục.
2. Nạp trước ảnh bằng `load_threaded_request`.
3. Dọn `queue_redraw`/`_process` (hp_bar, backdrop_fx, stage_lights, spell_card).
4. Tuỳ chọn MSAA trong Settings (+ chất lượng tự động).
5. MP3 cũ → OGG hoặc tách khỏi export; gộp ảnh trùng.
