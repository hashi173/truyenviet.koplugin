# Changelog

## 3.0.1

- Cập nhật parser cho metruyenvn, aztruyen, truyenc, giatocvuongtai, và dualeotruyenfull.
- Thêm cờ force_luasec cho truyenqq để sửa lỗi HTTPS trên Kobo.
- Sửa lỗi crash liên quan đến check nil trong Storage:isFavorite.
- Sửa lỗi Cloudflare 403.

## 1.0.4

- Sửa vòng đời widget để Back, tìm kiếm, lịch sử và phân trang không tạo nhiều màn hình chồng nhau.
- Sửa luồng mở/thoát Reader và chuyển chương để không văng về FileManager.
- Giữ bản chương cũ nếu tải lại thất bại; chỉ thay file sau khi dựng bản mới thành công.
- Chặn ảnh bìa lỗi, kích thước danh sách không hợp lệ và exception khi ghi cài đặt.
- Khôi phục đúng tên miền mặc định sau khi xóa tên miền tùy chỉnh.

## 0.3.0

- Xóa truyện khỏi tủ sẽ cập nhật danh sách và phân trang ngay, không cần thoát ra vào lại.
- Sửa lỗi báo sai `Không thể lưu trạng thái nguồn` khi bật lại TruyenQQ hoặc Dưa Leo.
- Xác nhận gói plugin dùng chung trên KOReader Android, Kindle và Kobo.
- Thêm xem mô tả và thông tin truyện khi giữ một kết quả.
- Thêm tải hàng loạt các chương chưa có trong trang mục lục hiện tại.
- Sửa luồng bật lại nguồn đã tắt và luôn hiển thị trạng thái nguồn ở trang chính.
- Bỏ tích hợp danh mục VBook Extensions.

## 0.2.0

- Thêm nguồn truyện tranh Dưa Leo Truyện.
- Chạm vào từng nguồn để duyệt truyện đã hoàn thành, tìm riêng theo nguồn, lọc thể loại và chuyển trang.
- Thêm tìm kiếm đồng thời nhiều nguồn, chuẩn hóa tiếng Việt và xếp hạng kết quả.
- Hiển thị ảnh bìa, tên truyện và nguồn trong danh sách kết quả.
- Thêm cache ảnh bìa và giao diện kết quả có phân trang.
- Thêm quản lý bật/tắt nguồn và đồng bộ danh mục Darkrai9x/vbook-extensions.
- Bổ sung kiểm thử parser Dưa Leo và thuật toán tìm kiếm.

## 0.1.0

- Thêm nguồn truyện chữ TruyenFull.
- Thêm nguồn manga TruyenQQ.
- Thêm tìm kiếm, tủ truyện và danh sách chương.
- Thêm bộ dựng HTML và CBZ.
- Thêm tích hợp mở tài liệu bằng KOReader.
