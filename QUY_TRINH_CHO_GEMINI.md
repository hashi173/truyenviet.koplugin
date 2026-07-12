# Quy trình bắt buộc khi sửa lỗi truyenviet.koplugin (đưa nguyên văn cho Gemini)

> Đưa file này cho Gemini đọc trước khi giao bất kỳ việc sửa lỗi nào. Nói rõ:
> "Làm đúng theo quy trình trong file này, không được bỏ bước nào, không được
> tự nhận là đã test nếu chưa thực sự test theo đúng nghĩa mô tả ở đây."

## Vì sao phải viết quy trình này

Toàn bộ lỗi tái diễn nhiều vòng vừa qua đều bắt nguồn từ **3 thói quen sai**:

1. Viết regex bóc HTML dựa trên suy đoán/trí nhớ về "web tiểu thuyết Trung Quốc
   thường có cấu trúc kiểu X" thay vì đọc HTML thật của đúng trang đang sửa.
2. Gọi `luac -p` rồi tự nhận "đã test" — lệnh này **chỉ kiểm tra cú pháp Lua**,
   không chạy code, không biết logic có đúng hay không, không phát hiện được
   lỗi kiểu biến scope sai (ví dụ vụ `isCloudflare` bị dán nhầm vào giữa hàm
   khác — file vẫn hợp lệ cú pháp 100% nhưng crash thật khi chạy).
3. Sửa nhiều thứ cùng lúc trong 1 lượt (vừa sửa bug vừa thêm feature vừa đổi
   kiến trúc) nên khi có lỗi mới, không biết thay đổi nào gây ra.

Quy trình dưới đây bắt buộc phải theo **đúng thứ tự**, không được nhảy bước.

---

## BƯỚC 0 — Xác nhận Gemini có xem được HTML thật hay không

Trước khi giao việc, hỏi thẳng Gemini: *"Bạn có thể tự mở URL và đọc HTML thật
ngay bây giờ không, hay bạn chỉ đang dựa vào trí nhớ?"*

- **Nếu Gemini có công cụ duyệt web/tìm kiếm thật** (Google Search grounding,
  URL context, browsing tool...): bắt Gemini phải **dán ra đúng đoạn HTML thô**
  nó vừa lấy được (không phải tóm tắt bằng lời) làm bằng chứng, trước khi được
  phép viết bất kỳ dòng regex nào.
- **Nếu Gemini KHÔNG có công cụ duyệt web thật** (nhiều bản Gemini miễn phí/API
  không có): **bạn phải tự lấy HTML thật rồi dán vào chat cho nó**, theo cách
  sau (làm trên điện thoại hoặc máy tính, không cần cài gì thêm):
  1. Mở trình duyệt (Chrome/Firefox/Edge), vào đúng URL cần sửa (trang danh
     sách truyện, trang chi tiết 1 truyện, trang danh sách chương...).
  2. Nhấn chuột phải → "View Page Source" (Xem mã nguồn trang) — **không phải
     "Inspect"/"Kiểm tra phần tử"**, vì Inspect hiển thị DOM đã bị trình duyệt
     chỉnh sửa qua JavaScript, không phải HTML gốc server trả về (quan trọng vì
     scraper Lua nhận đúng HTML gốc, không chạy JavaScript).
  3. Copy toàn bộ (Ctrl+A, Ctrl+C) và dán vào chat cho Gemini, kèm dòng chữ:
     *"Đây là HTML thật của trang X lấy lúc [giờ/ngày], hãy viết regex dựa
     đúng vào cấu trúc này, không được đoán thêm."*
  4. Nếu trang quá dài, chỉ cần copy phần chứa 3-5 thẻ truyện mẫu là đủ để
     Gemini nhìn ra pattern lặp lại.

**Không bao giờ cho phép Gemini viết code bóc dữ liệu mà không có HTML thật
làm căn cứ trong cùng cuộc hội thoại đó.**

---

## BƯỚC 1 — Với mỗi nguồn (source) cần sửa, lấy đủ 4 loại trang thật

Đừng chỉ lấy 1 trang rồi suy ra hết. Với mỗi site, cần tối thiểu:

1. **Trang danh sách/danh mục** (trang chủ hoặc trang "hoàn thành", trang thể
   loại...) — để lấy cấu trúc 1 "thẻ truyện" (link, tên, ảnh bìa).
2. **Trang chi tiết 1 truyện cụ thể** — để lấy cấu trúc mô tả, tác giả, danh
   sách chương, trạng thái (đang ra/hoàn thành).
3. **Trang 1 chương cụ thể** — để lấy cấu trúc nội dung chương (thẻ chứa văn
   bản, có quảng cáo/script rác cần loại bỏ không).
4. **1 trang thể loại bất kỳ** (nếu site có) — để xác nhận URL thể loại đúng
   định dạng gì, có phân trang không.

Ghi rõ **URL thật đã lấy** và **thời điểm lấy** vào comment trong code, ví dụ
(đây là cách tôi đã làm với `aztruyen.lua`, làm theo đúng mẫu này):

```lua
-- Cấu trúc thẻ truyện thật đã xác nhận bằng fetch trực tiếp aztruyen.top ngày 11/07/2026:
--   URL truyện dạng: https://aztruyen.top/{slug}-{id}/
--   Ảnh bìa dạng:    https://aztruyen.top/images/{slug}-{id}.webp
--   Tiêu đề nằm trong <h2><a href="...url..." title="Tên">Tên</a></h2>
```

Nếu Gemini viết code mà **không có comment dạng này ghi rõ nguồn bằng chứng**,
coi như chưa đạt yêu cầu, bắt viết lại.

---

## BƯỚC 2 — Viết regex bám sát cấu trúc THẬT, không bám theo tên class đoán mò

Nguyên tắc ưu tiên khi viết pattern bóc dữ liệu:

- **Ưu tiên 1: bám theo cấu trúc URL** (vì URL thường ổn định hơn tên class
  CSS — theme WordPress hay đổi class nhưng URL truyện/chương thường cố định).
  Ví dụ: nếu biết chắc URL truyện luôn có dạng `/{slug}-{số}/`, dùng
  `%-%d+/` làm mỏ neo thay vì dựa vào `class="story-item"` (dễ đổi).
- **Ưu tiên 2: nếu bắt buộc phải dùng class**, chỉ dùng phần class **đã thấy
  tận mắt trong HTML thật vừa fetch**, không suy ra bằng cách nhìn site khác
  "cùng kiểu".
- **Luôn viết kèm 1 lớp dự phòng (fallback)** đơn giản hơn, phòng khi site đổi
  cấu trúc — nhưng dự phòng phải rõ ràng ghi comment "dự phòng, ít tin cậy hơn
  pattern chính", không được để dự phòng thay thế hoàn toàn logic chính.

---

## BƯỚC 3 — Test thật, không phải test giả

**"Test" hợp lệ phải trả lời được câu hỏi: bóc ra bao nhiêu truyện/chương, và
con số đó có khớp với đếm tay trên trang thật không?**

Thứ tự bắt buộc:

1. **Syntax check bằng cách LOAD file thật**, không phải chỉ `luac -p`:
   ```lua
   local f = io.open('ten_file.lua', 'r')
   local s = f:read('*a')
   f:close()
   local chunk, err = load(s, 'ten_file.lua')
   print(chunk and 'OK' or ('LỖI: ' .. tostring(err)))
   ```
   (Có thể chạy bằng bất kỳ bản Lua nào, kể cả `texlua` nếu máy không có
   `lua`/`luac` cài sẵn — không được bỏ qua bước này chỉ vì "không có Lua".)

2. **Chạy thử hàm bóc dữ liệu (`parseStories`, `parseGenres`...) trực tiếp
   trên đúng đoạn HTML thật đã fetch ở Bước 1**, không phải HTML tưởng tượng.
   Viết 1 đoạn Lua nhỏ độc lập, `dofile`/`require` module cần test, nhồi
   chuỗi HTML thật vào, in ra kết quả bảng trả về (`table` số lượng, tên,
   URL...).

3. **Đếm tay số truyện/chương thật trên trang** (kéo trang, đếm bằng mắt),
   so với số Bước 2 in ra. **Chỉ được báo "đã sửa xong" khi 2 con số khớp.**
   Nếu không khớp, quay lại Bước 2, không được báo xong.

4. Với các thay đổi liên quan tới **luồng chạy/kiến trúc** (không phải
   regex) — ví dụ sửa `coroutine.yield`, sửa scope biến như vụ
   `isCloudflare` — **bắt buộc phải đọc lại TOÀN BỘ hàm bị đụng vào từ đầu
   đến `end` cuối cùng**, đếm số `function`/`end` cho khớp nhau, không được
   chỉ sửa đúng đoạn đang nhìn thấy trên màn hình rồi coi như xong. Đây
   chính xác là lỗi đã xảy ra: dán 2 hàm vào giữa thân 1 hàm khác mà không
   đọc lại toàn bộ hàm đó từ đầu đến cuối để kiểm tra.

---

## BƯỚC 4 — Sửa 1 việc / 1 lượt, báo cáo rõ ràng

- Mỗi lượt chỉ sửa **1 nguồn hoặc 1 bug cụ thể**, không gộp nhiều thay đổi
  không liên quan vào cùng 1 lần sửa (để nếu phát sinh lỗi mới, biết ngay
  thay đổi nào gây ra).
- Khi báo cáo đã sửa xong, **bắt buộc nêu rõ**:
  - Đã fetch HTML thật của URL nào, lúc nào (Bước 1).
  - Kết quả test đếm số Bước 3 khớp bao nhiêu/bao nhiêu.
  - Nếu **chưa** test được trên máy KOReader thật (chỉ test được logic bóc
    dữ liệu offline), phải nói rõ "chưa test trên KOReader thật, cần bạn cài
    thử" — không được nói "đã sửa xong, chắc chắn hoạt động" khi chưa thực sự
    chạy trên KOReader.
- Không được sửa 2 vấn đề khác nhau (vd: vừa sửa cover vừa sửa Cloudflare
  bypass) trong cùng 1 khối code mà không tách rõ bằng comment ranh giới.

---

## BƯỚC 5 — Trước khi giao lại code, tự rà lỗi cấu trúc kiểu "dán nhầm giữa hàm"

Đây là lỗi đã thực sự xảy ra (`http_client.lua`) và rất khó thấy bằng mắt khi
đọc lướt. Cách tự kiểm tra nhanh (không cần công cụ đặc biệt, chỉ cần đọc kỹ):

1. Mở file vừa sửa, tìm đúng khối code vừa thêm/sửa.
2. Kéo lên trên khối đó cho tới khi thấy dòng khai báo `function ... (` hoặc
   `local function ... (` **gần nhất phía trên**.
3. Kéo xuống dưới khối đó cho tới khi thấy `end` **đóng đúng hàm ấy** (không
   phải `end` của 1 `if`/`for` bên trong).
4. Tự hỏi: khối code mới thêm có đang nằm **lọt thỏm giữa 2 đoạn code vốn dĩ
   là 1 hàm liền mạch** hay không? Nếu đúng vậy — đó là dấu hiệu lỗi y hệt vụ
   `isCloudflare`. Phải dời khối mới ra ngoài (đặt trước hàm đó, ở cấp module)
   thay vì chèn vào giữa.

---

## Tóm tắt 1 câu cho Gemini

**"Không có HTML thật trong tay thì không được viết regex. Không đếm khớp số
liệu thật thì không được báo đã xong. Không đọc lại trọn vẹn cả hàm từ đầu
đến cuối thì không được sửa xong rồi báo cáo."**
