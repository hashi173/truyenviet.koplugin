# Phát triển Truyện Việt KOReader

## Phân chia trách nhiệm

| Module | Trách nhiệm |
|---|---|
| `sources/*.lua` | Mỗi website chỉ lấy và phân tích dữ liệu của chính nó. Khai báo `kind` (`text`/`comic`/`ebook`), tùy chọn `default_enabled = false` và `availability = { state, note }` cho nguồn đang bị chặn/không ổn định. |
| `source_registry.lua` | Danh sách nguồn, trạng thái bật/tắt, tên miền tùy chỉnh, ghi chú khả dụng. |
| `storage.lua` | Cài đặt và đường dẫn lưu. `disabled_sources[id]`: `true` = người dùng tắt, `false` = người dùng bật một nguồn mặc định tắt, `nil` = theo mặc định của adapter. |
| `http_client.lua` | HTTP, timeout, retry, phát hiện Cloudflare, `downloadToFile` (streaming). |
| `document_builder.lua` | Tạo HTML/CBZ cho **một** chương. |
| `bundle_exporter.lua` | Vòng lặp “tải cả truyện thành 1 tệp”: lấy chương, bắt lỗi từng chương, tiến trình, hủy. |
| `html_bundle_builder.lua` | Writer HTML gộp, ghi streaming xuống `.part`. |
| `epub_builder.lua` | Writer EPUB 3 qua `ffi/archiver` của KOReader (mimetype đầu tiên, không nén). |
| `ebook_downloader.lua` | Tải EPUB/PDF gốc của nguồn `ebook`, kiểm tra magic bytes. |
| `browser.lua` | Chỉ điều phối UI; không chứa logic parse hoặc ZIP. |

Writer cho `bundle_exporter` phải có `addChapter(chapter, payload, index)`,
`finish()` và `abort()`; ghi vào `<tệp>.part` và chỉ đổi tên trong `finish()`.

Nguồn `kind = "ebook"` không đi qua luồng chương truyện. DTV chỉ cung cấp EPUB/PDF
gốc; nó không phải nguồn để cào chương rồi đóng EPUB. Hiện DTV bị Cloudflare chặn
nên **mặc định tắt** (xem `docs/SOURCE_AUDIT_2026-10-22.md`).

## Chạy kiểm thử trong WSL

Dùng LuaJIT đi kèm KOReader, không dùng `lua` trong PATH:

```bash
cd /mnt/d/Project/truyenfull
bash spec/run_all.sh                 # toàn bộ unit test
bash spec/run_all.sh --integration   # + epub_archive (cần Archiver native của KOReader)
```

Từ PowerShell:

```powershell
wsl.exe -d Ubuntu -- bash /mnt/d/Project/truyenfull/spec/run_all.sh --integration
```

`compile_test.lua` tự tìm mọi tệp `.lua` trong plugin, nên module mới không bị
bỏ sót.

Kiểm tra cấu trúc một EPUB (mimetype, XML well-formed, manifest, dcterms):

```bash
/usr/lib/koreader/luajit spec/epub_archive_test.lua
python3 spec/check_epub.py /tmp/truyenviet-epub-integration-test.epub
rm -f /tmp/truyenviet-epub-*
```

## Tiêu chuẩn thay đổi

1. Thêm hoặc sửa nguồn phải có fixture/test parser cho listing, chi tiết và
   chương/tệp tải tương ứng.
2. Không báo nguồn hoạt động nếu kiểm tra thực tế nhận Cloudflare, CAPTCHA,
   đăng nhập hoặc HTTP lỗi. Không tìm cách vượt các cơ chế đó.
3. Tệp tải phải dùng `.part`, kiểm tra nội dung trước khi đổi tên, và dọn file
   tạm khi thất bại hoặc bị hủy.
4. Không tin `Content-Type` hoặc phần mở rộng file một mình: kiểm tra magic
   bytes/định dạng thực tế.
5. Không ghi đè im lặng: hỏi người dùng khi tệp đích đã tồn tại.
6. Không tự động ghi đè tên miền tùy chỉnh người dùng đã cấu hình.
7. Sau thay đổi UI, phải khởi động KOReader và thực hiện thao tác liên quan;
   unit test không thay thế runtime test.
