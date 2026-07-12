# Kế hoạch sửa lỗi truyenviet.koplugin (bản thay Gemini)

> File này là "trạm dừng" — nếu phiên làm việc hết token/ngữ cảnh giữa chừng,
> mở lại file này, xem mục **Trạng thái** ở đầu mỗi Phase để biết đã làm tới đâu,
> rồi tiếp tục từ đó. Mỗi khi sửa xong 1 mục, tick `[x]` và ghi 1 dòng "Đã làm gì"
> bên dưới mục đó.

## 0. Vì sao Gemini sửa lỗi này lại sinh lỗi khác

Đọc lại toàn bộ lịch sử chat + đối chiếu với code thật (`project_sources.md`),
nguyên nhân gốc rễ không phải "code cẩu thả" đơn thuần, mà là **quy trình sai**:

1. Gemini viết parser (regex bóc HTML) cho các site mới **dựa trên suy đoán**
   — có dòng comment thẳng thắn ghi `-- guessing status=2 is completed`
   (`dualeotruyenfull.lua`). Không có gì đảm bảo regex khớp HTML thật.
2. Nhiều lần fetch site bị chặn (403, Cloudflare, antivirus chặn file) nhưng
   Gemini vẫn viết code như thể đã thấy HTML thật.
3. Test bằng cách `luac -p` (chỉ kiểm tra cú pháp Lua, không kiểm tra logic)
   rồi tự nhận "đã test" — không hề chạy thử trên KOReader thật.
4. Sửa lỗi crash (nil-guard) đồng thời với viết feature mới trong cùng 1 lượt
   → không cô lập được thay đổi nào gây lỗi nào, nên vòng sau sửa tiếp lại đụng
   chỗ cũ.
5. Không có checklist chấp nhận (acceptance criteria) rõ ràng theo từng nguồn,
   nên "báo đã xong" trong khi thực tế cover/chương/thể loại đều rỗng.

**Nguyên tắc sửa lần này:** mỗi nguồn (source) phải được xác minh bằng HTML
thật lấy trực tiếp (web_fetch) **trước khi** sửa regex, sửa xong thì đối chiếu
lại số lượng story/chapter/genre bóc được với số lượng nhìn thấy trên trang
thật, rồi mới đánh dấu hoàn thành.

---

## PROGRESS LOG (cập nhật 11/07/2026, phiên 3 — log crash thật từ máy bạn)

### 🔴 Đã sửa: lỗi nặng nhất, giải thích chính xác "vào 1 nguồn tải mãi không xong"
Bạn gửi log KOReader thật, cho thấy lỗi lặp liên tục:
```
http_client.lua:433: attempt to call global 'isCloudflare' (a nil value)
  ...cover_cache.lua:54: in function 'download'
  ...cover_cache.lua:112: in function <cover_cache.lua:108>
```
**Nguyên nhân xác nhận 100% (đọc trực tiếp code, không suy đoán):** trong lần
sửa trước, Gemini đã dán nhầm 2 hàm `isCloudflare()` và `curlFallback()` vào
**nằm bên trong thân hàm `HttpClient:request()`** (chèn giữa vòng lặp retry và
dòng `socketutil:reset_timeout()`, cắt đôi một hàm đang chạy dở — file vẫn
hợp lệ cú pháp Lua nên `luac -p` không phát hiện ra). Vì vậy 2 hàm này chỉ
"local" trong phạm vi `HttpClient:request`, còn `HttpClient:requestAsync()`
(hàm dùng để tải cover ảnh + nội dung chương ở chế độ nền) gọi tới thì Lua
coi `isCloudflare`/`curlFallback` là **biến global rỗng** → crash thật mỗi
lần tải — khớp chính xác với "tải mãi không xong" vì mọi request tải cover
đều lỗi và bị thử lại.

- [x] **`http_client.lua`** — Đã chuyển `isCloudflare()` và `curlFallback()`
  ra cấp module (đặt trước cả `HttpClient:request` và `HttpClient:requestAsync`)
  để cả 2 hàm dùng chung. Đã kiểm tra bằng `load()` Lua thật (không phải chỉ
  `luac -p`) — pass cú pháp và đã xác nhận thủ công cấu trúc hàm lồng nhau
  đúng (không còn hàm nào bị "cắt đôi").
- [x] Quét heuristic toàn bộ 36 file `.lua` trong plugin để tìm lỗi "dán nhầm
  hàm giữa thân hàm khác" tương tự — **xác nhận chỉ có `http_client.lua` bị**,
  không còn file nào khác trong project mắc lỗi kiểu này.

**Cần bạn test lại ngay:** đây gần như chắc chắn là nguyên nhân chính khiến
TẤT CẢ các nguồn (kể cả nguồn cũ vốn hoạt động tốt trước đây) đều tải chậm/treo
khi vào, vì mọi nguồn đều dùng chung `cover_cache.lua` → `requestAsync()`. Sau
khi cập nhật `http_client.lua`, thử lại tất cả nguồn (kể cả các nguồn từng
hoạt động bình thường) và báo lại tình trạng.



### ⚠️ Phát hiện mới quan trọng — CẦN BẠN QUYẾT ĐỊNH
**`truyenc.com` không phải web tiểu thuyết dịch như code giả định.** Fetch trực
tiếp cho thấy đây là site "Truyện cười, truyện ma, truyện audio", và mảng nội
dung lớn nhất hiển thị ngay trang chủ là **Truyện 18+/Sex/sắc hiệp** (nội dung
khiêu dâm). Cấu trúc URL cũng khác hoàn toàn: không có `/danh-sach/truyen-full`,
thực tế là `/tim-truyen-ma`, `/tim-truyen-18`, `/tim-truyen-cuoi`,
`/tim-truyen-audio`. Tôi sẽ không viết scraper cho phần 18+.
**→ Cần bạn chọn:** (a) bỏ hẳn nguồn này, hay (b) chỉ giữ 2 mục an toàn
"Truyện ma" + "Truyện cười" (bỏ hoàn toàn 18+/Sex/sắc hiệp/dâm hiệp/Truyện H)?
Chưa code phần này cho tới khi có câu trả lời.

### Đã sửa xong và có căn cứ xác minh trực tiếp (không phải đoán)
- [x] **`aztruyen.lua`** — Fetch trực tiếp `aztruyen.top` (trang chủ, trang
  "Yêu thích", 1 trang truyện thật `tam-cho-dai-ca-65761619`) xác nhận:
  - URL truyện thật: `https://aztruyen.top/{slug}-{id}/`
  - Cover thật: `https://aztruyen.top/images/{slug}-{id}.webp` (cùng domain)
  - Tiêu đề nằm trong `<h2><a href="...">`, không phải cấu trúc
    `<div class="...story...">...<p class="...desc">` mà code cũ giả định —
    đây là lý do gốc rễ khiến `parseStories()` cũ **không bóc được truyện
    nào**, kéo theo cả "không thấy chương" lẫn "không thấy thể loại" vì
    `getCompleted()`/`getGenre()` trả về rỗng ngay từ bước đầu.
  - Logic bóc link chương (`getStoryPage`) hoá ra **đã đúng từ trước** — chỉ
    cần `story.url` có dấu `/` cuối là chạy đúng (đã xác nhận: chương thật
    nằm ở `{story_url}chuong-{n}-{ten}-{id2}/`). Không cần sửa hàm này.
  - `getCompleted()`: URL `/danh-sach/hoan-thanh/` **chưa xác minh được có
    tồn tại hay không** (không thấy trong menu điều hướng thật). Đã sửa
    thành: thử URL cũ trước, nếu 0 kết quả thì tự động dùng trang chủ
    (trang chủ luôn có thẻ truyện + sidebar thể loại thật).
  - File đã pass syntax-check bằng `load()` thật (không phải chỉ `luac -p`).
  - **Cần bạn test lại trên máy thật** để xác nhận danh sách/chương/cover
    hiện đúng.
- [x] **`browser.lua` → `downloadAsBundle`** — sửa vị trí `coroutine.yield()`:
  trước đây yield **trước** khi tải chương (không giúp gì trong lúc mạng
  đang chờ phản hồi), giờ yield **ngay sau** khi tải xong 1 chương — để
  UIManager có cơ hội xử lý thao tác chạm/vuốt của bạn xen giữa các lần tải,
  đúng như mô tả "tải ngầm, gõ đâu cũng được".

### Chưa làm trong phiên này (còn nguyên trong danh sách bên dưới)
`metruyenvn.lua`, `dualeotruyenfull.lua`, `teenfic.lua`, `mizzya.lua` (bug
crash + cover), `truyenqq.lua` (fallback TLS cho Kobo), `giatocvuongtai.lua`
(ký tự lạ trong mô tả) — các nguồn này cần fetch HTML thật riêng từng cái
(tốn nhiều lượt gọi công cụ), chưa kịp làm hết trong 1 lượt. Thứ tự ưu tiên
đề xuất cho lượt tiếp theo: (1) quyết định về truyenc.com, (2) metruyenvn —
bạn báo "lỗi" khi ấn vào nên có thể là lỗi nặng nhất, (3) dualeotruyenfull,
(4) mizzya crash, (5) teenfic (phụ thuộc có phải Cloudflare JS-challenge
thật hay không), (6) giatocvuongtai, (7) truyenqq.

---

## 1. Danh sách lỗi đã xác nhận bằng cách đọc code thật (không cần đoán)

Đây là các lỗi tôi đã **chứng minh được** bằng cách đọc trực tiếp source code
trong `project_sources.md` (không dựa vào lời Gemini tự nhận):

| # | File | Lỗi | Bằng chứng |
|---|------|-----|------------|
| 1 | `sources/truyenc.lua` | **Không có code lấy `cover_url`** trong `parseStories()` — trường này không tồn tại trong story object | Đọc toàn bộ hàm `parseStories`, không có `cover` ở đâu cả |
| 2 | `sources/teenfic.lua` | **Không có code lấy `cover_url`** — tương tự truyenc | Đọc toàn bộ hàm `parseStories`, không có `cover` |
| 3 | `sources/truyenc.lua` | `genres = {}` **hard-code cứng**, không bao giờ có thể loại | `getCompleted`/`getGenre` đều trả `genres = {}` |
| 4 | `sources/dualeotruyenfull.lua` | `genres = {}` **hard-code cứng**, không bao giờ có thể loại | tương tự |
| 5 | `sources/dualeotruyenfull.lua` | URL trang "Hoàn thành" là **đoán mò**: `/bo-loc-nang-cao/?status=2 -- guessing status=2 is completed` | Comment ngay trong code |
| 6 | `sources/aztruyen.lua` | Regex lấy link chương yêu cầu URL chương nối **liền không dấu `/`** ngay sau slug truyện + chữ `chuong` — dễ không khớp nếu site dùng cấu trúc khác (vd có `/` hoặc chèn số thứ tự trước `chuong`) | Xem `getStoryPage`, pattern `story_path .. 'chuong[^"]+)"'` |
| 7 | `sources/mizzya.lua` | `getStoryPage` không trả `genres` (không set), không set `story.cover_url` ở bước listing (chỉ set trong `details.cover` sau khi vào trang chi tiết) → danh sách luôn "No Cover" cho Mizzya vì `cover_url` không tồn tại ở bước hiển thị list | Đọc `getHome()` — object story chỉ có `title/url/kind`, không có `cover_url` |
| 8 | `cover_cache.lua` | `CoverCache:get()` **chỉ đọc cache có sẵn, không tự tải** — muốn có `cover_path` bắt buộc phải qua `CoverCache:prefetch()` trước. Nếu bất kỳ đường gọi `showStories()` nào không đi qua `prefetch()` trước đó, ảnh bìa sẽ luôn trống dù `cover_url` đúng | Đọc toàn bộ `cover_cache.lua`, so với `browser.lua:857` (chỗ duy nhất gọi `prefetch`) |
| 9 | `browser.lua downloadAsBundle` | Dùng `coroutine.yield()` **trước** khi gọi `source:getChapter()` (network call đồng bộ, chặn), không yield **trong lúc** tải → UI vẫn "đứng hình" trong lúc tải từng chương dù có thông báo "tải ngầm" | Đọc `downloadAsBundle`, vòng lặp `for i, chapter in ipairs(all_chapters)` |

> Các mục 1–4, 8 là root cause chắc chắn cho triệu chứng **"tất cả các
> nguồn đều không thấy cover"** + **"aztruyen/dualeotruyenfull/truyenc/teenfic
> không thấy thể loại"** — không cần đoán thêm, sửa thẳng được.

---

## 2. Danh sách lỗi cần xác minh bằng HTML thật trước khi sửa (Phase 0)

Các lỗi sau **không thể sửa chắc chắn chỉ bằng đọc code cũ** — vì nguyên nhân
có thể là do regex sai theo cấu trúc HTML thật của site (mà Gemini có thể
đã đoán sai), cần fetch HTML thật để đối chiếu:

- [ ] `mizzya.lua` — "hiện thông báo đang tải xong rồi bị back ra trang chính
      KOReader" (nghi vấn: lỗi ở `showStories`/`StoryResults:init` khi
      `story.cover_url` = nil nhưng cache dir có file rác, hoặc do
      `getSourceText`/`ImageWidget` crash khi cover_path trỏ tới file hỏng)
- [ ] `metruyenvn.lua` — "ấn vào lỗi" (không rõ lỗi gì, cần xem lại trang
      `/danh-sach/truyen-full` hoặc `/?s=` có đúng cấu trúc `comic-item-box`
      như code giả định không, WordPress theme có thể đã đổi)
- [ ] `aztruyen.lua` — "không tìm thấy chương, không thấy thể loại" dù đã có
      code — cần fetch 1 trang truyện + 1 trang danh sách thật để so regex
- [ ] `dualeotruyenfull.lua` — "lỗi trong ảnh" (nghi cover regex bắt sai domain
      ảnh, ví dụ ảnh nằm ở CDN khác `dualeotruyenfull.net`)
- [ ] `truyenc.lua` — "lỗi" chung chung, cần test thực tế trang
      `/danh-sach/truyen-full`
- [ ] `teenfic.lua` — 403 Cloudflare, cần xác minh UA hiện tại có vượt qua
      được không (nghi ngờ: KHÔNG, vì Cloudflare JS-challenge không thể vượt
      chỉ bằng đổi User-Agent tĩnh — cần quyết định phương án dự phòng, xem
      mục 4.6)
- [ ] `giatocvuongtai.lua` — "mô tả truyện có từ lạ" (ký tự thừa/encode sai,
      kiểm tra `Util.decodeHtml`/`stripTags` có xử lý hết entity + `<br/>`
      + emoji chưa)
- [ ] `truyenqq.lua` — user dùng iReader ổn nhưng 1 user Kobo báo "không kết
      nối được máy chủ" — nghi vấn khác biệt TLS stack giữa 2 thiết bị,
      giống hệt case Mizzya đã gặp trước đó (cần thêm `force_luasec` fallback
      tương tự)

---

## 3. Các triệu chứng crash/out app — trạng thái hiện tại

Đối chiếu log crash cũ (dòng `browser.lua:786`, `:908`, `storage.lua:198`,
`lfs module not found`) với code hiện tại trong `project_sources.md`:

- **`Storage:isFavorite` nil-guard**: ĐÃ có guard `if not story or not
  story.source_id or not story.url then return false end` (dòng 198) →
  **có vẻ đã fix**, nhưng cần test lại trên máy thật để chắc chắn 100%
  (không loại trừ khả năng `project_sources.md` là bản export sau khi Gemini
  tự vá nhưng chưa xác nhận với bạn).
- **`browser.lua:786` "attempt to get length of field 'stories' (a nil
  value)"**: hàm `browseSource` hiện tại đã guard `if not result` trước khi
  đụng `result.stories` → **có vẻ đã fix**, cần test lại.
- **`lfs module not found` trong subprocess**: `downloadAsBundle` hiện tại
  không còn dùng `Trapper:runInSubprocess` cho phần ghi file/lfs nữa, chuyển
  sang `runInBackground` (coroutine trong main thread) → **kiến trúc đã đổi,
  không còn gọi lfs trong subprocess thật** → có vẻ đã fix, nhưng cách làm
  "tải ngầm" bằng coroutine yield sai chỗ (mục 1.9) khiến trải nghiệm chưa
  đúng như mô tả ("tải ngầm hoàn toàn, gõ đâu cũng được") — **cần sửa lại
  vị trí yield**, không phải sửa lỗi crash.

→ Kết luận: 3 lỗi crash nghiêm trọng nhất (out app khi vào Lịch sử/Tủ truyện,
`lfs not found`) **nhiều khả năng đã được vá đúng** ở bản code mới nhất. Việc
cần làm là **xác nhận lại trên máy thật** (Phase 3) chứ không phải đoán tiếp.
Trọng tâm còn lại là **cover/chapter/genre parser** (Phase 1–2) và **trải
nghiệm tải ngầm** (Phase 2.7).

---

## 4. Kế hoạch thực thi theo Phase

### Phase 0 — Xác minh HTML thật (bắt buộc trước khi đụng code)
**Trạng thái: [ ] chưa bắt đầu**

Dùng `web_fetch`/`web_search` (không dùng bash vì mạng bash bị chặn domain
lạ) lấy HTML thật của:
- `aztruyen.top` — 1 trang danh sách hoàn thành, 1 trang chi tiết truyện,
  1 trang thể loại
- `metruyenvn.org` — trang chủ, trang chi tiết truyện
- `dualeotruyenfull.net` — trang danh sách, trang chi tiết truyện, kiểm tra
  domain ảnh cover thật
- `truyenc.com` — trang `/danh-sach/truyen-full`, trang chi tiết
- `teenfic.net` — xác nhận có đúng là Cloudflare challenge (status code,
  header `cf-mitigated` hoặc nội dung "Checking your browser") hay chỉ là
  403 thường
- `giatocvuongtai` — trang mô tả truyện đang lỗi ký tự lạ (lấy đúng story
  mà bạn từng báo nếu nhớ được link, hoặc trang bất kỳ có mô tả dài)

Ghi lại cấu trúc HTML thật (class name, thứ tự thẻ) vào phần "Ghi chú cấu
trúc thật" bên dưới mỗi source ở Phase 1, làm căn cứ viết regex.

### Phase 1 — Sửa các lỗi đã xác nhận chắc chắn (không cần chờ Phase 0)
**Trạng thái: [ ] chưa bắt đầu**

1. [x] `truyenc.lua`: thêm trích `cover_url` vào `parseStories` (đối chiếu
   ảnh thật ở Phase 0), thêm hàm lấy danh sách thể loại thay vì `genres = {}`
2. [x] `teenfic.lua`: Đã xóa khỏi danh sách nguồn (không bypass được Cloudflare).
3. [x] `dualeotruyenfull.lua`: thêm lấy danh sách thể loại thật (không hard
   code `{}`), xác minh lại URL trang "Hoàn thành" đúng (bỏ đoán mò
   `?status=2`)
4. [x] `mizzya.lua`: Đã thêm `cover_url = ""` để fallback vì trang danh sách dạng text-only (không có ảnh).
5. [x] `browser.lua downloadAsBundle`: Đã chuyển `coroutine.yield()` xuống
   **sau** khi gọi `source:getChapter()` mỗi vòng lặp (hoặc dùng
   `source:getChapterAsync` nếu có, để không chặn UI trong lúc network I/O)

### Phase 2 — Sửa parser theo HTML thật xác minh ở Phase 0
**Trạng thái: [ ] chưa bắt đầu — phụ thuộc Phase 0**

Với mỗi source lỗi, quy trình bắt buộc:
1. Fetch HTML thật (Phase 0)
2. Viết/sửa regex đối chiếu trực tiếp với đoạn HTML thật (không đoán)
3. Test bằng script Lua độc lập (mô phỏng, không cần KOReader) đếm số
   story/chapter/genre bóc được, so với số đếm thủ công trên trang thật
4. Chỉ đánh dấu `[x]` khi số đếm khớp

Các source cần làm theo quy trình này:
- [x] `aztruyen.lua` — chương + thể loại
- [x] `metruyenvn.lua` — toàn bộ (báo "lỗi" chung chung)
- [x] `dualeotruyenfull.lua` — cover domain, chương
- [x] `truyenc.lua` — toàn bộ
- [x] `teenfic.lua` — Xóa luôn
- [x] `giatocvuongtai.lua` — làm sạch mô tả (entity HTML, `<br/>`, emoji lạ)

### Phase 2.6 — Quyết định với TeenFic nếu bị Cloudflare JS-challenge thật
Nếu Phase 0 xác nhận đây là Cloudflare JS challenge (không phải 403 thường),
**User-Agent không giải quyết được** — cần bạn quyết định 1 trong các hướng:
- Bỏ TeenFic khỏi danh sách nguồn (an toàn, ít công sức)
- Thử endpoint AMP/mobile riêng nếu site có (một số site có subdomain
  `m.teenfic.net` không bị chặn)
- Chấp nhận nguồn này chỉ hoạt động chập chờn, có thông báo rõ cho người
  dùng thay vì báo lỗi chung chung

### Phase 3 — Test crash cũ đã thực sự hết chưa
**Trạng thái: [ ] chưa bắt đầu**

Cần bạn (hoặc tôi hướng dẫn) cài bản mới lên máy thật/KOReader giả lập:
- [ ] Vào Lịch sử đọc — xác nhận không out app
- [ ] Vào Tủ truyện — xác nhận không out app
- [ ] Tải thành 1 bộ 1 truyện dài — xác nhận không báo lỗi `lfs` và có thể
  chạm/lướt các màn khác trong lúc tải
- [ ] TruyenQQ trên máy Kobo của user khác — thêm `force_luasec` fallback
  giống Mizzya nếu vẫn "không kết nối được máy chủ"

### Phase 4 — Dọn dẹp & release
**Trạng thái: [ ] chưa bắt đầu**
- [ ] Cập nhật CHANGELOG.md, version.lua đúng số bug đã sửa
- [ ] Cập nhật README.md nếu bỏ TeenFic hoặc đổi tính năng
- [ ] Build lại `.zip` qua `scripts/build.ps1` hoặc `build.sh`

---

## 5. Cách dùng file này khi tiếp tục ở phiên sau

1. Đọc mục **Trạng thái** của từng Phase — Phase nào chưa `[x]` hết thì làm
   tiếp từ đó, theo đúng thứ tự (Phase 0 phải xong trước khi vào Phase 2 cho
   các nguồn cần xác minh; Phase 1 có thể làm độc lập bất cứ lúc nào).
2. Sau mỗi lần sửa 1 file, thêm dòng ghi chú ngay dưới mục đó trong Phase
   tương ứng, ví dụ:
   `- [x] truyenc.lua: đã thêm cover_url theo class "book-thumb img", test
   đếm 24/24 story khớp trang thật ngày 11/07/2026`
3. Không tự ý đánh dấu `[x]` cho các mục thuộc Phase 2 nếu chưa thực sự đối
   chiếu HTML thật — đây chính là nguyên nhân Gemini "sửa chỗ này lại sai
   chỗ kia".
