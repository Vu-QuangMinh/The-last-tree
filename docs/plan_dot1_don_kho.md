# Đợt 1 — Dọn kho (không đụng logic game)

Kế hoạch thi hành cho một phiên Claude (Sonnet). Dựa trên `docs/audit_2026-11-12.md` mục 5, đợt 1.
Mọi số liệu trong file này đo ngày 2026-11-12 trên nhánh `Banana-Fork`, HEAD `dd384d3`. Nếu thực tế khác (file không còn, số khác xa), **dừng task đó và báo**, không đoán.

## 0. Luật chung cho cả đợt (đọc hết trước khi gõ lệnh đầu tiên)

1. Đọc `CLAUDE.md` của project và `~/.claude/CLAUDE.md` trước. Trả lời bằng tiếng Việt.
2. Đợt này **không sửa một dòng logic nào** trong `scripts/core`, `scripts/ui`, `scripts/main.gd`, `scripts/autoload` (trừ đúng 2 chỗ được nêu đích danh: T1.4 đổi đường dẫn trong 2 tool Python, T1.6 xoá 5 file lớp chết). Không "tiện tay" sửa gì khác.
3. **Không resize, không nén, không "tối ưu" ảnh.** Nhạc được phép chuyển định dạng (T1.3) vì không phải art.
4. Mỗi task = một commit riêng, ngay sau khi kiểm chứng xong. Mẫu message:
   ```
   Housekeeping (đợt 1, T1.x): <một dòng nói làm gì>

   Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>
   ```
   (Nếu system-reminder của phiên đưa dòng Co-Authored-By khác thì dùng dòng của phiên.)
5. **Không push.** Chỉ push khi người dùng nói "Kết thúc phiên làm việc" hoặc yêu cầu đích danh.
6. Task có đánh dấu **[HỎI]** = phải dừng, trình bày lựa chọn cho người dùng, chờ trả lời rồi mới làm. Các task khác tự làm.
7. Sửa file có tiếng Việt hoặc file `.gd`: dùng Edit tool hoặc Python (UTF-8). **Không dùng** PowerShell `Get-Content`/`Set-Content`.
8. Di chuyển/xoá file đã track: luôn `git mv` / `git rm` để giữ lịch sử. File chưa track thì `mv`/`rm` thường.
9. Kiểm chứng tối thiểu sau mỗi task có đụng file trong `res://` (asset, script):
   ```
   "C:\Program Files\Godot\Godot.exe" --headless --path . --script res://tools/check_scripts.gd
   "C:\Program Files\Godot\Godot.exe" --headless --path . --script res://tests/run_tests.gd
   ```
   Kỳ vọng: `CHECK: 139 scripts, 0 failed` (134 sau T1.6) và `189 tests, 0 failed`. Khác là dừng.
10. Không bao giờ tắt Godot editor của người dùng. Không mở cửa sổ game trong đợt này (không cần).
11. Cuối đợt: báo cáo theo mẫu ở mục 9 cuối file.

## 0.1 Trạng thái xuất phát phải khớp

Chạy `git status --short` và `git log --oneline -1`. Kỳ vọng HEAD là `dd384d3` hoặc commit mới hơn của sonvtbatdan trên `Banana-Fork`. Nếu có file **đã track** bị sửa (dòng bắt đầu bằng ` M`) ngoài `tools/__pycache__/*.pyc`, dừng và hỏi: đó là việc dở của người dùng.

Danh sách untracked được biết trước (bình thường, không đụng trừ khi task nói): `assets/Puppet/Enemies/_Source/Act2/*`, `assets/Puppet/Enemies/_Source/_Backup_redo_2026-11-11/`, `assets/Puppet/UI/Characters/Merchant/_Redo/`, `assets/Puppet/UI/NewUiV2/*` (nhiều file), `shots15/ shots16/ shots17/`, `tools/__pycache__/*`.

---

## T1.1 `.gitignore` + bỏ track file rác

**Mục tiêu**: repo không còn `.pyc`, thư mục screenshot, file backup; các thư mục nháp của art được ignore trước khi ai đó `git add -A`.

**Số liệu**: 16 file `tools/__pycache__/*.pyc` đang được track (1 file đang hiện ` M`). `shots15/16/17` = 162 file, 146 MB, chưa track. `scrshot/` 3 file track (13 MB), `screenshots/` 8 file track (18 MB).

**Bước**
1. Thêm vào cuối `.gitignore` (giữ nguyên phần cũ):
   ```gitignore

   # ---- 2026-11 housekeeping (docs/plan_dot1_don_kho.md T1.1)
   # Python bytecode of the tools
   __pycache__/
   *.pyc
   # screenshot folders written by tools/*_shot.gd and by hand (never part of the game)
   shots*/
   scrshot/
   screenshots/
   # hand backups next to data files (the real file is the one without .bak)
   *.bak.json
   # scratch folders beside the cut art: backups, references, redo batches (the game never reads them)
   assets/**/_Backup*/
   assets/**/_Refs/
   assets/**/_Redo/
   assets/**/redo_refs/
   # .m4a cannot be imported by Godot; keep such files outside the repo
   *.m4a
   *.m4a.txt
   ```
2. Bỏ track nhưng giữ file trên đĩa:
   ```
   git rm -r --cached tools/__pycache__
   git rm -r --cached scrshot screenshots
   git rm --cached data/enemy_ropes.bak.json
   ```
   `scrshot/` và `screenshots/` vẫn nằm trên đĩa (người dùng có thể còn cần xem); chỉ repo không giữ nữa.
3. `git status --short`: không còn dòng nào bắt đầu bằng `??` cho `shots15/`, `shots16/`, `shots17/`, `tools/__pycache__/`, `assets/Puppet/Enemies/_Source/_Backup_redo_2026-11-11/`, `assets/Puppet/UI/Characters/Merchant/_Redo/`, `assets/Puppet/UI/NewUiV2/_Backup/`, `assets/Puppet/UI/NewUiV2/_Refs/`, `assets/Puppet/Enemies/_Source/Act2/redo_refs/`.

**Kiểm chứng**: `git check-ignore -v shots15/x.png tools/__pycache__/a.pyc "assets/Puppet/UI/NewUiV2/_Refs/x.png"` in ra 3 dòng khớp rule. `git ls-files | grep -c "\.pyc$"` = 0.

**Lùi lại**: `git checkout -- .gitignore && git reset` (trước commit) hoặc `git revert <commit>`.

**Không làm**: không xoá `data/enemy_ropes.bak.json` trên đĩa (dữ liệu tay của người dùng), chỉ bỏ track.

---

## T1.2 `.gitattributes`

**Mục tiêu**: hết lỗi "project.godot chỉ khác line ending"; file nhị phân không bị Git thử normalize/diff.

**Bước**: thay toàn bộ nội dung `.gitattributes` (hiện chỉ có `* text=auto`) bằng:
```gitattributes
# Default: let git decide text/binary, normalise text to LF in the repo
* text=auto

# Godot and code files are always LF (Godot writes LF; the editor on Windows otherwise flips project.godot back and forth)
*.gd        text eol=lf
*.tscn      text eol=lf
*.tres      text eol=lf
*.godot     text eol=lf
*.cfg       text eol=lf
*.gdshader  text eol=lf
*.json      text eol=lf
*.md        text eol=lf
*.py        text eol=lf
*.txt       text eol=lf
*.uid       text eol=lf
*.import    text eol=lf
*.gitignore text eol=lf
*.gitattributes text eol=lf

# Binary: never normalise, never textual diff
*.png   binary
*.jpg   binary
*.jpeg  binary
*.webp  binary
*.gif   binary
*.psd   binary
*.pdf   binary
*.wav   binary
*.ogg   binary
*.mp3   binary
*.m4a   binary
*.mid   binary
*.ttf   binary
*.TTF   binary
*.otf   binary
*.OTF   binary
*.xlsx  binary
*.exe   binary
*.dll   binary
```
Sau đó renormalize một lần để kho và cây làm việc khớp:
```
git add --renormalize .
git status --short | head -40
```
**Kỳ vọng**: `git status` chỉ liệt kê file text đổi CRLF→LF (nếu có). Nếu danh sách > 100 file, vẫn ổn (một lần duy nhất) nhưng ghi số lượng vào báo cáo. `git diff --cached --stat | tail -1` phải cho thấy số dòng thêm = số dòng xoá cho từng file (chỉ đổi EOL). Nếu có file mà thêm ≠ xoá: dừng, xem file đó.

**Kiểm chứng**: `git ls-files --eol project.godot scripts/main.gd` cho `i/lf w/lf attr/text eol=lf`. Chạy check_scripts + tests (mục 0.9).

**Lưu ý cho Minh**: sau khi commit này lên, lần pull đầu của Minh có thể thấy nhiều file "đổi" chỉ vì EOL. Ghi vào báo cáo cuối để người dùng báo Minh.

---

## T1.3 Nhạc — **[HỎI]** trước khi làm 3b và 3c

**Hiện trạng** (đo thật):
- `assets/Global/Music/<slot>/`: 38 file `Suno Nov 03 *.wav` = **1 206 MB**, là theme nhạc **đang bật mặc định** (`Audio.music_theme = "suno_nov03"`, `audio.gd:67`); mỗi slot có thêm 1–14 MP3 của theme "anysong_nov02"/"old".
- `assets/Global/Music/Pianist/fur_elise.wav`, `turkish_march.wav` (27 MB): nạp đích danh `.wav` ở `scripts/ui/pianist_song.gd:51` → **giữ nguyên WAV**.
- Gốc project: `fur_elise_6_notes.wav`, `fur_elise_opening.wav` (0,6 MB, được track) → không file nào trong `scripts/ tools/ tests/ docs/` nhắc tên → **rác**.
- `assets/Puppet/Music/`: 74 file `.m4a` + 74 `.m4a.txt` = **232 MB**, được track. Godot không import `.m4a`; `audio.gd` chỉ tìm `.wav/.ogg/.mp3` trong `Global/Music`. Không code nào nhắc `Puppet/Music`. → Vô dụng trong repo.
- `ffmpeg` có sẵn trên máy (8.0.1, trong PATH).

**3a (tự làm, không hỏi)**: xoá 2 file WAV ở gốc.
```
git rm fur_elise_6_notes.wav fur_elise_opening.wav
rm -f fur_elise_6_notes.wav.import fur_elise_opening.wav.import
```
Kiểm chứng: `grep -rn "fur_elise_6_notes\|fur_elise_opening" scripts tools tests` rỗng (đã kiểm ngày 12/11, kiểm lại cho chắc).

**3b [HỎI] chuyển 38 WAV Suno sang OGG** (tiết kiệm ~1,1 GB repo + ~1,1 GB cache `.godot`). Trình bày cho người dùng:
- Lợi: repo nhẹ, clone nhanh, web build khả thi. OGG q6 (~192 kbps) nghe không khác WAV trong game.
- Hại: file nhạc gốc không còn trong repo (đề nghị người dùng chép 38 WAV sang `E:\` trước, ví dụ `E:\GitHub\The-last-tree_music_wav\`). Lịch sử git vẫn giữ bản WAV cũ nên repo trên đĩa không nhỏ đi cho đến khi làm T1.5.
- Ảnh hưởng save: Music Edit ghi bài đã ghim vào settings dạng `music_pick_<theme>_<slot> = "<tên file có đuôi>"` (`audio.gd:457–498`). Sau khi đổi đuôi, ghim cũ sẽ không khớp. Trước khi chuyển, **đọc `audio.gd:450–500`** và trả lời: khi tên ghim không có trong `list_tracks` thì code làm gì? Nếu nó tự về random/đầu danh sách thì chấp nhận được (ghi vào báo cáo); nếu nó crash/im lặng không phát thì phải báo người dùng, chưa chuyển.

Nếu người dùng đồng ý, chạy script (Bash tool, chạy từ gốc project):
```bash
cd "/d/GitHub Projects/The-last-tree"
mkdir -p "/e/GitHub/The-last-tree_music_wav"
find assets/Global/Music -name 'Suno Nov 03*.wav' -print0 | while IFS= read -r -d '' f; do
  out="${f%.wav}.ogg"
  ffmpeg -nostdin -loglevel error -y -i "$f" -map_metadata -1 -c:a libvorbis -q:a 6 "$out" || { echo "FAIL $f"; exit 1; }
  cp -n "$f" "/e/GitHub/The-last-tree_music_wav/"
done
echo converted $(find assets/Global/Music -name 'Suno Nov 03*.ogg' | wc -l)
```
Kỳ vọng `converted 38`. Nghe thử 1 file bằng lệnh không mở cửa sổ? Không có cách nghe không tiếng; thay bằng kiểm tra `ffprobe -v error -show_entries format=duration -of csv=p=0 "<ogg>"` ≈ duration của WAV tương ứng (lệch < 0,1 s) cho 3 file bất kỳ.
Rồi:
```bash
find assets/Global/Music -name 'Suno Nov 03*.wav' -print0 | xargs -0 git rm -q
find assets/Global/Music -name 'Suno Nov 03*.wav.import' -delete
git add assets/Global/Music
"C:/Program Files/Godot/Godot.exe" --headless --path . --editor --quit   # import các .ogg mới (chạy 1–3 phút)
```
Kiểm chứng: `"<Godot>" --headless --path . --script res://tests/run_tests.gd` pass; `ls assets/Global/Music/menu/` có `Suno Nov 03 Step Right Up.ogg` và `.ogg.import`. `Audio.track_theme()` nhận theme theo **tiền tố tên** nên `.ogg` vẫn thuộc theme `suno_nov03` (xác nhận bằng cách đọc `audio.gd:394–400`).

**3c [HỎI] `assets/Puppet/Music/*.m4a`**: đề nghị người dùng chọn: (A) chuyển cả thư mục ra `E:\GitHub\The-last-tree_music_m4a\` và `git rm -r assets/Puppet/Music`; (B) giữ trên đĩa nhưng bỏ track (`git rm -r --cached assets/Puppet/Music` + thêm `.gdignore` vào thư mục đó để Godot không quét). Khuyên (A). `.gitignore` ở T1.1 đã có `*.m4a` nên về sau không lọt lại.

**Lùi lại**: mọi bước đều là `git rm`/`git mv` nên `git revert` commit là đủ; bản WAV còn trong `E:\...` và trong lịch sử.

---

## T1.4 Media nguồn trong `docs/` → về đúng chỗ

**Hiện trạng**: `docs/dialogue/Handy_voice.wav` (20 MB) và `docs/dialogue/sfx_handy_got_hit.wav` (4 MB) là **nguồn** để cắt giọng Handyman, được 2 tool đọc: `tools/split_handyman_voice.py:22` và `tools/split_handyman_hits.py:12` (cả hai dựng đường dẫn từ `ROOT, 'docs', 'dialogue', ...`). `docs/dialogue/handy_voice_words.json` là input của tool thứ nhất. `assets/Puppet/Voice/` đã có `handyman/`, `invoker/` (file đã cắt).

**Bước**
1. ```
   mkdir -p "assets/Puppet/Voice/_Source/handyman"
   printf '' > "assets/Puppet/Voice/_Source/.gdignore"
   git mv docs/dialogue/Handy_voice.wav docs/dialogue/sfx_handy_got_hit.wav docs/dialogue/handy_voice_words.json assets/Puppet/Voice/_Source/handyman/
   rm -f docs/dialogue/*.wav.import
   git add assets/Puppet/Voice/_Source/.gdignore
   ```
2. Sửa 2 tool bằng Edit tool, đúng 2 dòng + docstring:
   - `tools/split_handyman_voice.py:22`: `SRC = os.path.join(ROOT, "assets", "Puppet", "Voice", "_Source", "handyman", "Handy_voice.wav")`; dòng mặc định `words.json` trong docstring (dòng 8) và chỗ code đọc mặc định `docs/dialogue/handy_voice_words.json` (tìm bằng `grep -n handy_voice_words tools/split_handyman_voice.py`) → đường dẫn mới.
   - `tools/split_handyman_hits.py:12`: `SRC = os.path.join(ROOT, 'assets', 'Puppet', 'Voice', '_Source', 'handyman', 'sfx_handy_got_hit.wav')`; sửa docstring dòng 1.
3. `docs/dialogue/handyman.md`, `pianist.md`, `handyman_voice.txt` (text) **giữ nguyên chỗ**.
4. Ảnh và PDF tham chiếu trong `docs/` (`character_panel_v1.png`, `enemy_hp_2_rows.png`, `enemy_hp_over_20.png`, `invoker_reform_frames.png`, `title_reference.png`, `Card Template.pdf`): `git mv` vào `docs/_ref/` và xoá `.png.import` đi kèm. Không có code nào đọc chúng (đã grep `docs/` trong scripts/tools: chỉ comment). Thêm `.gdignore` rỗng vào `docs/` nếu chưa có (`ls -a docs | grep gdignore`), để Godot thôi import ảnh/âm thanh trong docs.

**Kiểm chứng**: `python -c "import ast,sys;[ast.parse(open(f,encoding='utf-8').read()) for f in ['tools/split_handyman_voice.py','tools/split_handyman_hits.py']];print('ok')"`; `grep -rn "docs/dialogue" tools scripts` chỉ còn trong comment nếu có. Không chạy 2 tool đó (cần `rvc_env` của ReadAnyBook và sẽ ghi đè SFX đã cắt).

---

## T1.5 Git LFS / lịch sử nặng — **[HỎI]**, chỉ trình bày, không tự làm

**Hiện trạng**: 4,68 GB nội dung được track, không LFS (`git lfs version` = 3.6.0 có sẵn). Trong lịch sử còn blob đã xoá: `assets/ui/puppet/Chant…` 115 MB, `Handyman.pdf` 75 MB × 3 bản, `assets/sfx/music_*.wav` 65 MB × 4, `MinhHUD.pdf` 61 MB. Remote là repo của Minh (`Vu-QuangMinh/The-last-tree`), hai người cùng đẩy.

Trình bày đúng 2 lựa chọn, khuyên B:

**A. Viết lại lịch sử bằng `git lfs migrate import --include="*.wav,*.pdf,*.psd,*.mp3,*.m4a" --everything`.** Repo nhỏ đi thật, nhưng **mọi commit đổi hash** → phải `push --force` cả `main` và `Banana-Fork`, Minh phải clone lại, mọi PR/so sánh cũ đứt. Chỉ làm khi Minh đồng ý và cả hai không có việc dở.

**B. Không viết lại lịch sử; từ nay file nặng mới đi qua LFS.** Thêm vào `.gitattributes`:
```gitattributes
*.wav  filter=lfs diff=lfs merge=lfs -text
*.pdf  filter=lfs diff=lfs merge=lfs -text
*.psd  filter=lfs diff=lfs merge=lfs -text
```
rồi `git lfs install` (một lần mỗi máy, Minh cũng phải chạy). File cũ vẫn là blob thường. Lợi: không ai phải clone lại. Hại: repo hiện tại không nhỏ đi; GitHub LFS có hạn mức 1 GB free (người dùng phải biết).

Ghi câu trả lời của người dùng vào báo cáo. Nếu chọn A, **không làm trong đợt này**, mở một việc riêng có Minh tham gia.

---

## T1.6 Xoá 5 lớp chết

**Hiện trạng** (đã grep toàn bộ `scripts tests tools docs scenes CLAUDE.md README.md`, chỉ file tự nó và audit nhắc tới): `scripts/ui/card_drag.gd` (`CardDrag`), `firefly_field.gd` (`FireflyField`), `ink_backdrop.gd` (`InkBackdrop`), `kind_glyph.gd` (`KindGlyph`), `resin_icon.gd` (`ResinIcon`). `ResinIcon` được nhắc trong `docs/art_progress.md:83` chỉ là ghi chú to-do ("Resin icon still drawn in code").

**Bước**
1. Grep lại lần cuối, phải rỗng (trừ chính file đó và `docs/audit_2026-11-12.md`):
   ```
   grep -rwn "CardDrag\|FireflyField\|InkBackdrop\|KindGlyph\|ResinIcon\|card_drag\|firefly_field\|ink_backdrop\|kind_glyph\|resin_icon" scripts tests tools scenes CLAUDE.md README.md
   ```
   Nếu có kết quả mới (Minh có thể vừa dùng): bỏ file đó khỏi danh sách xoá.
2. ```
   git rm scripts/ui/card_drag.gd scripts/ui/card_drag.gd.uid scripts/ui/firefly_field.gd scripts/ui/firefly_field.gd.uid scripts/ui/ink_backdrop.gd scripts/ui/ink_backdrop.gd.uid scripts/ui/kind_glyph.gd scripts/ui/kind_glyph.gd.uid scripts/ui/resin_icon.gd scripts/ui/resin_icon.gd.uid
   ```
3. Làm mới cache class của Godot (bắt buộc khi thêm/xoá `class_name`):
   ```
   "C:\Program Files\Godot\Godot.exe" --headless --path . --editor --quit
   ```
4. Sửa `docs/art_progress.md:83`: bỏ cụm "(still drawn in code: `ResinIcon`)" → "(no icon yet)".

**Kiểm chứng**: check_scripts → `134 scripts, 0 failed`; tests pass. `grep -c "ResinIcon\|KindGlyph" .godot/global_script_class_cache.cfg` = 0.

---

## T1.7 Di tích trong `data/` và `docs/`

**Bước** (tất cả `git mv`, không xoá, trừ khi ghi rõ):
1. `mkdir -p docs/_archive && git mv "docs/old prompts" docs/_archive/old_prompts && git mv docs/story_backup_before_reorg.md docs/_archive/ && git mv data/archive/spells_turnbased_v2.json docs/_archive/ && rmdir data/archive`
   (`data/archive` được track chỉ 1 file; sau `git mv` thư mục rỗng tự biến mất.)
2. `git mv docs/auto_rig_probe.py tools/auto_rig_probe.py` (script không thuộc docs; nó chỉ là probe, không ai import: `grep -rn auto_rig_probe tools scripts` phải rỗng).
3. `docs/session_2026_10_17.md`: **giữ**, vì `docs/art_progress.md:163,165` trỏ tới; sẽ gom vào changelog ở đợt 2.
4. `data/new_spell_ids.txt`: **giữ**, `tools/spell_report.py:279` đọc nó.
5. `assets/_Archive/Circus` (33 file, 34 MB, có `.gdignore`): **[HỎI]** "Cirus đã bỏ từ tháng 10, assets/README.md nói 'delete it when you are sure'. Xoá khỏi repo chưa?" Nếu đồng ý: `git rm -r assets/_Archive/Circus`; nếu không: để nguyên.
6. Thư mục nháp chưa có `.gdignore` (Godot đang quét và import chúng vô ích): tạo file `.gdignore` rỗng trong từng thư mục:
   `assets/Global/Music/Pianist/_Source`, `assets/Puppet/Enemies/_Source/_Backup_redo_2026-11-11`, `assets/Puppet/UI/Characters/Merchant/_Redo`, `assets/Puppet/UI/NewUiCabinet/_Refs`, `assets/Puppet/UI/NewUiV2/_Backup`, `assets/Puppet/UI/NewUiV2/_Refs`.
   Chỉ `Pianist/_Source/.gdignore` được `git add` (thư mục đó đang track); các thư mục còn lại đã bị ignore ở T1.1 nên `.gdignore` chỉ nằm trên đĩa.
7. `assets/Puppet/UI/NewUiV2/` có file lẻ chưa track mà `docs/art_progress.md` (khối NewUI Ver2) ghi rõ là **obsolete**: `repaint.png`, `repaint rectangle.png`, `repaint yellow.png`, `repaint done.png`(chú ý: `repaint done.png` = "long plate" đang **dùng**, không xoá), `Asset 3.png`, `nu2_plate_right*`, `nu2_bottle_tray*`. **[HỎI]** liệt kê đúng tên + kích thước cho người dùng, xoá cái nào do người dùng quyết. Trước khi hỏi, grep từng tên (không đuôi) trong `scripts/`: tên nào có mặt thì **đang dùng**, loại khỏi danh sách hỏi.

**Kiểm chứng**: check_scripts + tests; `python tools/spell_report.py --help` hoặc đơn giản `python -c "import ast;ast.parse(open('tools/spell_report.py',encoding='utf-8').read())"` (không chạy thật vì nó ghi `docs/spells.xlsx`).

---

## T1.8 Báo cáo art mồ côi (chỉ lập danh sách, không xoá gì)

**Mục tiêu**: một file `docs/orphan_art_report.md` để người dùng duyệt tay. Ước lượng sơ bộ ngày 12/11: ~370 file ≈ 670 MB trong `assets/Puppet/*` không có tên trong code.

**Bước**: tạo `tools/orphan_art_report.py` với nội dung sau (chép nguyên văn), chạy `python tools/orphan_art_report.py`, commit cả script lẫn báo cáo.

```python
"""Orphan art report: every picture / sound under assets/ whose file name (or stem) appears nowhere in scripts/, tools/, tests/ or data/.
REVIEW LIST ONLY: this script deletes nothing. Names built at run time (e.g. "sfx_handy_hit_%d") are matched by their prefix,
frame numbers (_01) and state suffixes (_hover) are stripped before matching, so the list errs on the side of "referenced".
Usage: python tools/orphan_art_report.py  -> docs/orphan_art_report.md"""
import os
import re

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SKIP_DIRS = ("_Source", "_Backup", "_Refs", "_Redo", "_Candidates", "_Archive", "redo_refs", ".git", ".godot")
EXTS = (".png", ".webp", ".jpg", ".jpeg", ".wav", ".ogg", ".mp3")
SUFFIX = re.compile(r"_(normal|hover|pressed|disabled|on|off|left|mid|right|top|bottom|s|big|small|front|back|open|closed)$")

text = []
for d in ("scripts", "tools", "tests", "data"):
    for dp, _dns, fs in os.walk(os.path.join(ROOT, d)):
        for f in fs:
            if f.endswith((".gd", ".py", ".json", ".txt")):
                with open(os.path.join(dp, f), encoding="utf-8", errors="ignore") as h:
                    text.append(h.read())
blob = "\n".join(text)
literals = set(re.findall(r'"([^"\n]{2,80})"', blob)) | set(re.findall(r"'([^'\n]{2,80})'", blob))
exact, prefixes = set(), set()
for s in literals:
    if "%" in s or "{" in s:
        p = re.split(r"%|\{", s)[0]
        if len(p) >= 3:
            prefixes.add(p)
    else:
        exact.add(s)
        exact.add(os.path.splitext(os.path.basename(s))[0])


def referenced(stem: str) -> bool:
    cands = {stem, re.sub(r"_\d+$", "", stem), SUFFIX.sub("", stem), SUFFIX.sub("", re.sub(r"_\d+$", "", stem))}
    for c in cands:
        if len(c) < 3:
            continue
        if c in exact or c in blob:
            return True
    return any(stem.startswith(p) for p in prefixes)


rows = []
for dp, dns, fs in os.walk(os.path.join(ROOT, "assets")):
    dns[:] = [x for x in dns if not x.startswith(SKIP_DIRS)]
    for f in fs:
        if not f.lower().endswith(EXTS):
            continue
        if not referenced(os.path.splitext(f)[0]):
            p = os.path.join(dp, f)
            rows.append((os.path.getsize(p), os.path.relpath(p, ROOT).replace("\\", "/")))
rows.sort(reverse=True)
by_dir = {}
for size, p in rows:
    k = "/".join(p.split("/")[:3])
    by_dir.setdefault(k, [0, 0])
    by_dir[k][0] += 1
    by_dir[k][1] += size

out = ["# Orphan art report", "", "Files under `assets/` whose name is not found in `scripts/`, `tools/`, `tests/`, `data/`.",
       "**Review list: nothing was deleted.** A file here may still be used through a name built at run time: check before removing.", "",
       "## By folder", "", "| folder | files | MB |", "|---|---:|---:|"]
out += ["| %s | %d | %.0f |" % (k, v[0], v[1] / 2**20) for k, v in sorted(by_dir.items(), key=lambda kv: -kv[1][1])]
out += ["", "## Files (largest first)", "", "| MB | file |", "|---:|---|"]
out += ["| %.1f | %s |" % (s / 2**20, p) for s, p in rows]
out += ["", "Total: %d files, %.0f MB" % (len(rows), sum(s for s, _ in rows) / 2**20)]
dest = os.path.join(ROOT, "docs", "orphan_art_report.md")
with open(dest, "w", encoding="utf-8") as h:
    h.write("\n".join(out) + "\n")
print(dest, len(rows), "files")
```

**Kiểm chứng tính đúng của báo cáo** (bắt buộc, chọn 5 file bất kỳ trong danh sách): với mỗi file, `grep -rn "<stem>" scripts tools` phải rỗng. Chọn thêm 3 file **không** nằm trong danh sách và đang dùng chắc chắn (`button_chant_normal.png`, một enemy trong `assets/Puppet/Enemies/Act1/`, `sfx_wooden_ball_roll.wav` nếu tồn tại): chúng không được xuất hiện. Nếu một file đang dùng lọt vào danh sách: sửa script (thường là thiếu một hậu tố trong `SUFFIX`), chạy lại, ghi vào báo cáo.

**Sau đó**: báo người dùng tổng số và 10 file lớn nhất, nói rõ "chưa xoá gì; duyệt xong nói tôi xoá nhóm nào". Không tự xoá trong đợt này.

---

## 9. Mẫu báo cáo cuối đợt

```
Đợt 1 — kết quả
- T1.1 .gitignore + untrack: commit <hash>. Bỏ track N file.
- T1.2 .gitattributes + renormalize: commit <hash>. M file đổi EOL. (Báo Minh: lần pull đầu sẽ thấy nhiều file đổi.)
- T1.3a xoá 2 wav gốc: commit <hash>. 3b/3c: người dùng chọn ... / chưa trả lời.
- T1.4 media docs → Voice/_Source + docs/_ref: commit <hash>.
- T1.5 LFS: người dùng chọn A/B/chưa; nếu B đã thêm .gitattributes LFS: commit <hash>.
- T1.6 xoá 5 lớp chết: commit <hash>; check_scripts 134/0, tests 189/0.
- T1.7 di tích: commit <hash>; Circus: giữ/xoá; NewUiV2 file lẻ: danh sách đã gửi.
- T1.8 orphan report: commit <hash>; N file, M MB; 10 file lớn nhất: ...
Chưa làm / bị chặn: ...
Chưa chạy thật: game chưa được mở cửa sổ trong đợt này (không cần cho các thay đổi trên); 2 tool cắt giọng Handyman chưa chạy lại.
```
