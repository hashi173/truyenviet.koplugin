local Http = require("truyenviet/http_client")
local Util = require("truyenviet/helpers")
local GDrive = require("truyenviet/gdrive_downloader")
local Debug = require("truyenviet/debugger")
local ko_util = require("util")

local Source = {
    id = "dilib",
    name = "Dilib Thư Viện Số",
    kind = "ebook",
    base_url = "https://dilib.vn",
}

function Source:getCoverHeaders()
    return { ["Referer"] = self.base_url .. "/" }
end

-- Categories for browsing
local LIBRARY_CATEGORIES = {
    { name = "Thư Viện", url = "/thu-vien/" },
    { name = "Sách Bộ", url = "/sach-bo/" },
    { name = "Truyện Tranh", url = "/truyen-tranh/" },
    { name = "Truyện Tranh Manga", url = "/truyen-tranh/manga/" },
    { name = "Truyện Tranh Manhua", url = "/truyen-tranh/manhua/" },
    { name = "Truyện Tranh Manhwa", url = "/truyen-tranh/manhwa/" },
    { name = "Truyện Tranh Manga", url = "/truyen-tranh/manga/" },
    { name = "Truyện Tranh Manhua", url = "/truyen-tranh/manhua/" },
    { name = "Truyện Tranh Manhwa", url = "/truyen-tranh/manhwa/" },
    { name = "Truyện Tranh Action", url = "/truyen-tranh/action/" },
    { name = "Truyện Tranh Adventure", url = "/truyen-tranh/adventure/" },
    { name = "Truyện Tranh Comedy", url = "/truyen-tranh/comedy/" },
    { name = "Truyện Tranh Fantasy", url = "/truyen-tranh/fantasy/" },
    { name = "Truyện Tranh Shounen", url = "/truyen-tranh/shounen/" },
    { name = "Truyện Tranh Shoujo", url = "/truyen-tranh/shoujo/" },
    { name = "Truyện Tranh Supernatural", url = "/truyen-tranh/supernatural/" },
    { name = "Truyện Tranh Sci-Fi", url = "/truyen-tranh/sci-fi/" },
    { name = "Truyện Tranh Martial Arts", url = "/truyen-tranh/martial-arts/" },
    { name = "Truyện Tranh Seinen", url = "/truyen-tranh/seinen/" },
    { name = "Truyện Tranh Drama", url = "/truyen-tranh/drama/" },
    { name = "Truyện Tranh Mystery", url = "/truyen-tranh/mystery/" },
    { name = "Truyện Tranh Cooking", url = "/truyen-tranh/cooking/" },
    { name = "Truyện Tranh Harem", url = "/truyen-tranh/harem/" },
    { name = "Truyện Tranh Romance", url = "/truyen-tranh/romance/" },
    { name = "Truyện Tranh School Life", url = "/truyen-tranh/school-life/" },
    { name = "Truyện Tranh Historical", url = "/truyen-tranh/historical/" },
    { name = "Truyện Tranh Psychological", url = "/truyen-tranh/psychological/" },
    { name = "Truyện Tranh Tragedy", url = "/truyen-tranh/tragedy/" },
    { name = "Truyện Tranh Truyện Màu", url = "/truyen-tranh/truyen-mau/" },
    { name = "Truyện Tranh Horror", url = "/truyen-tranh/horror/" },
    { name = "Truyện Tranh Slice Of Life", url = "/truyen-tranh/slice-of-life/" },
    { name = "Truyện Tranh Adult (18+)", url = "/truyen-tranh/adult-18/" },
    { name = "Truyện Tranh Sports", url = "/truyen-tranh/sports/" },
    { name = "Truyện Tranh Ecchi", url = "/truyen-tranh/ecchi/" },
    { name = "Truyện Tranh Webtoon", url = "/truyen-tranh/webtoon/" },
    { name = "Truyện Tranh Mature", url = "/truyen-tranh/mature/" },
    { name = "Truyện Tranh Tu Tiên", url = "/truyen-tranh/tu-tien/" },
    { name = "Truyện Tranh Vampire", url = "/truyen-tranh/vampire/" },
    { name = "Truyện Tranh Josei", url = "/truyen-tranh/josei/" },
    { name = "Truyện Tranh Xuyên Không", url = "/truyen-tranh/xuyen-khong/" },
    { name = "Truyện Tranh Magic", url = "/truyen-tranh/magic/" },
    { name = "Truyện Tranh Monsters", url = "/truyen-tranh/monsters/" },
    { name = "Truyện Tranh Hệ Thống", url = "/truyen-tranh/he-thong/" },
    { name = "Phim Tài Liệu - Khoa Học", url = "/rap-chieu-phim/tai-lieu-khoa-hoc/" },
    { name = "Phim Tâm Linh - Tỉnh Thức", url = "/rap-chieu-phim/tam-linh-tinh-thuc/" },
    { name = "Phim Khám Phá Thế Giới", url = "/rap-chieu-phim/kham-pha-the-gioi/" },
    { name = "Phim Hoạt Hình - Anime", url = "/rap-chieu-phim/hoat-hinh-anime/" },
    { name = "Phim Võ Thuật - Hành Động", url = "/rap-chieu-phim/vo-thuat-hanh-dong/" },
    { name = "Phim Hình Sự - Trinh Thám", url = "/rap-chieu-phim/hinh-su-trinh-tham/" },
    { name = "Phim Tâm Lý - Tình Cảm", url = "/rap-chieu-phim/tam-ly-tinh-cam/" },
    { name = "Phim Phiêu Lưu - Sinh Tồn", url = "/rap-chieu-phim/phieu-luu-sinh-ton/" },
    { name = "Phim Khoa Học - Giả Tưởng", url = "/rap-chieu-phim/khoa-hoc-gia-tuong/" },
    { name = "Phim Chiến Tranh - Lịch Sử", url = "/rap-chieu-phim/chien-tranh-lich-su/" },
    { name = "Phim Cổ Trang - Kiếm Hiệp", url = "/rap-chieu-phim/co-trang-kiem-hiep/" },
    { name = "Phim Ma - Kinh Dị", url = "/rap-chieu-phim/phim-ma-kinh-di/" },
    { name = "Phim Hài - Vui Nhộn", url = "/rap-chieu-phim/phim-hai-vui-nhon/" },
    { name = "Phim Thuyết Minh - Lồng Tiếng", url = "/rap-chieu-phim/thuyet-minh-long-tieng/" },
    { name = "Nhạc Pop - Ballad", url = "/am-nhac/pop-ballad/" },
    { name = "Nhạc Dance - Edm", url = "/am-nhac/dance-edm/" },
    { name = "Nhạc Hip Hop - Rap", url = "/am-nhac/hip-hop-rap/" },
    { name = "Nhạc Thánh Ca", url = "/am-nhac/thanh-ca/" },
    { name = "Nhạc Phật Giáo", url = "/am-nhac/nhac-phat-giao/" },
    { name = "Nhạc Chữa Lành", url = "/am-nhac/nhac-chua-lanh/" },
    { name = "Nhạc Không Lời", url = "/am-nhac/nhac-khong-loi/" },
    { name = "Nhạc Thiền Định", url = "/am-nhac/nhac-thien-dinh/" },
    { name = "Nhạc Năng Lượng", url = "/am-nhac/nhac-nang-luong/" },
    { name = "Nhạc Tình Ca - Love Song", url = "/am-nhac/tinh-ca-love-song/" },
    { name = "Nhạc Audiophile", url = "/am-nhac/audiophile/" },
    { name = "Nhạc Giao Hưởng", url = "/am-nhac/giao-huong/" },
    { name = "Sách Tâm Lý - Kỹ Năng", url = "/thu-vien/tam-ly-ky-nang/" },
    { name = "Sách Tôn Giáo - Tâm Linh", url = "/thu-vien/ton-giao-tam-linh/" },
    { name = "Sách Khoa Học - Công Nghệ", url = "/thu-vien/khoa-hoc-cong-nghe/" },
    { name = "Sách Kiến Trúc - Xây Dựng", url = "/thu-vien/kien-truc-xay-dung/" },
    { name = "Sách Nông - Lâm - Ngư", url = "/thu-vien/nong-lam-ngu/" },
    { name = "Sách Y Học - Sức Khỏe", url = "/thu-vien/y-hoc-suc-khoe/" },
    { name = "Sách Lịch Sử - Quân Sự", url = "/thu-vien/lich-su-quan-su/" },
    { name = "Sách Nhân Vật Lịch Sử", url = "/thu-vien/nhan-vat-lich-su/" },
    { name = "Sách Hồi Ký - Tùy Bút", url = "/thu-vien/hoi-ky-tuy-but/" },
    { name = "Sách Quản Trị - Kinh Doanh", url = "/thu-vien/quan-tri-kinh-doanh/" },
    { name = "Sách Self Help - Khởi Nghiệp", url = "/thu-vien/self-help-khoi-nghiep/" },
    { name = "Sách Marketing - Bán Hàng", url = "/thu-vien/marketing-ban-hang/" },
    { name = "Sách Triết Học - Lý Luận", url = "/thu-vien/triet-hoc-ly-luan/" },
    { name = "Sách Đường Lối - Chính Trị", url = "/thu-vien/duong-loi-chinh-tri/" },
    { name = "Sách Thư Viện Pháp Luật", url = "/thu-vien/thu-vien-phap-luat/" },
    { name = "Sách Khai Tâm - Mở Trí", url = "/thu-vien/khai-tam-mo-tri/" },
    { name = "Sách Văn Hóa - Xã Hội", url = "/thu-vien/van-hoa-xa-hoi/" },
    { name = "Sách Văn Học - Nghệ Thuật", url = "/thu-vien/van-hoc-nghe-thuat/" },
    { name = "Sách Tác Phẩm Kinh Điển", url = "/thu-vien/tac-pham-kinh-dien/" },
    { name = "Sách Giáo Dục - Đào Tạo", url = "/thu-vien/giao-duc-dao-tao/" },
    { name = "Sách Tài Liệu - Tham Khảo", url = "/thu-vien/tai-lieu-tham-khao/" },
    { name = "Sách Công Nghệ Thông Tin", url = "/thu-vien/cong-nghe-thong-tin/" },
    { name = "Sách Thể Thao - Võ Thuật", url = "/thu-vien/the-thao-vo-thuat/" },
    { name = "Sách Yoga - Thiền", url = "/thu-vien/yoga-thien/" },
    { name = "Sách Phát Triển Bản Thân", url = "/thu-vien/phat-trien-ban-than/" },
    { name = "Sách Ẩm Thực - Nấu Ăn", url = "/thu-vien/am-thuc-nau-an/" },
    { name = "Sách Âm Nhạc - Thơ Ca - Hội Họa", url = "/thu-vien/am-nhac-tho-ca-hoi-hoa/" },
    { name = "Sách Nuôi Dưỡng Tâm Hồn", url = "/thu-vien/nuoi-duong-tam-hon/" },
    { name = "Sách Tình cảm - Gia Đình", url = "/thu-vien/tinh-cam-gia-dinh/" },
    { name = "Sách Trẻ Em - Thiếu Nhi", url = "/thu-vien/tre-em-thieu-nhi/" },
    { name = "Sách Tuổi Học Trò", url = "/thu-vien/tuoi-hoc-tro/" },
    { name = "Sách Tử Vi - Phong Thủy", url = "/thu-vien/tu-vi-phong-thuy/" },
    { name = "Sách Biên Khảo - Địa Lý", url = "/thu-vien/bien-khao-dia-ly/" },
    { name = "Sách Khám Phá - Bí Ẩn", url = "/thu-vien/kham-pha-bi-an/" },
    { name = "Sách Huyền Bí - Giả Tưởng", url = "/thu-vien/huyen-bi-gia-tuong/" },
    { name = "Sách Cổ Tích - Thần Thoại", url = "/thu-vien/co-tich-than-thoai/" },
    { name = "Sách Phiêu Lưu - Mạo Hiểm", url = "/thu-vien/phieu-luu-mao-hiem/" },
    { name = "Sách Trinh Thám - Hình Sự - Kinh Dị", url = "/thu-vien/trinh-tham-hinh-su-kinh-di/" },
    { name = "Sách Tiếu Lâm - Hài Hước", url = "/thu-vien/tieu-lam-hai-huoc/" },
    { name = "Sách Lãng Mạn - Ngôn Tình", url = "/thu-vien/lang-man-ngon-tinh/" },
    { name = "Sách Đam Mỹ - Bách Hợp", url = "/thu-vien/dam-my-bach-hop/" },
    { name = "Sách Người Lớn (18+)", url = "/thu-vien/nguoi-lon-18/" },
    { name = "Sách Truyện Ngắn - Tiểu Thuyết", url = "/thu-vien/truyen-ngan-tieu-thuyet/" },
    { name = "Sách Truyện Dài Trọn Bộ", url = "/thu-vien/truyen-dai-tron-bo/" },
    { name = "Sách Kịch Bản - Sân Khấu", url = "/thu-vien/kich-ban-san-khau/" },
    { name = "Sách Kiếm Hiệp - Tiên Hiệp", url = "/thu-vien/kiem-hiep-tien-hiep/" },
    { name = "Sách Huyền Huyễn - Phóng Tác", url = "/thu-vien/huyen-huyen-phong-tac/" },
    { name = "Sách Đang Cập Nhật", url = "/thu-vien/dang-cap-nhat/" },
    { name = "Xem Thêm Bình Luận", url = "/binh-luan/" },
}

local AUDIOBOOK_CATEGORIES = {
    { name = "Góc Suy Ngẫm", url = "/radio/goc-suy-ngam/" },
    { name = "Radio Tình Yêu", url = "/radio/radio-tinh-yeu/" },
    { name = "Radio Cho Tâm Hồn", url = "/radio/radio-cho-tam-hon/" },
    { name = "Radio Truyện Ngắn", url = "/radio/radio-truyen-ngan/" },
    { name = "Radio Truyện Dài Kỳ", url = "/radio/radio-truyen-dai-ky/" },
    { name = "Tản Mạn Radio", url = "/radio/tan-man-radio/" },
    { name = "Kịch Truyền Thanh", url = "/radio/kich-truyen-thanh/" },
    { name = "Tóm Tắt Sách", url = "/radio/tom-tat-sach/" },
    { name = "Sách nói Tâm Lý - Kỹ Năng", url = "/sach-noi/tam-ly-ky-nang/" },
    { name = "Sách nói Tôn Giáo - Tâm Linh", url = "/sach-noi/ton-giao-tam-linh/" },
    { name = "Sách nói Khoa Học - Công Nghệ", url = "/sach-noi/khoa-hoc-cong-nghe/" },
    { name = "Sách nói Kiến Trúc - Xây Dựng", url = "/sach-noi/kien-truc-xay-dung/" },
    { name = "Sách nói Nông - Lâm - Ngư", url = "/sach-noi/nong-lam-ngu/" },
    { name = "Sách nói Y Học - Sức Khỏe", url = "/sach-noi/y-hoc-suc-khoe/" },
    { name = "Sách nói Lịch Sử - Quân Sự", url = "/sach-noi/lich-su-quan-su/" },
    { name = "Sách nói Nhân Vật Lịch Sử", url = "/sach-noi/nhan-vat-lich-su/" },
    { name = "Sách nói Hồi Ký - Tùy Bút", url = "/sach-noi/hoi-ky-tuy-but/" },
    { name = "Sách nói Quản Trị - Kinh Doanh", url = "/sach-noi/quan-tri-kinh-doanh/" },
    { name = "Sách nói Self Help - Khởi Nghiệp", url = "/sach-noi/self-help-khoi-nghiep/" },
    { name = "Sách nói Marketing - Bán Hàng", url = "/sach-noi/marketing-ban-hang/" },
    { name = "Sách nói Triết Học - Lý Luận", url = "/sach-noi/triet-hoc-ly-luan/" },
    { name = "Sách nói Đường Lối - Chính Trị", url = "/sach-noi/duong-loi-chinh-tri/" },
    { name = "Sách nói Thư Viện Pháp Luật", url = "/sach-noi/thu-vien-phap-luat/" },
    { name = "Sách nói Khai Tâm - Mở Trí", url = "/sach-noi/khai-tam-mo-tri/" },
    { name = "Sách nói Văn Hóa - Xã Hội", url = "/sach-noi/van-hoa-xa-hoi/" },
    { name = "Sách nói Văn Học - Nghệ Thuật", url = "/sach-noi/van-hoc-nghe-thuat/" },
    { name = "Sách nói Tác Phẩm Kinh Điển", url = "/sach-noi/tac-pham-kinh-dien/" },
    { name = "Sách nói Giáo Dục - Đào Tạo", url = "/sach-noi/giao-duc-dao-tao/" },
    { name = "Sách nói Tài Liệu - Tham Khảo", url = "/sach-noi/tai-lieu-tham-khao/" },
    { name = "Sách nói Công Nghệ Thông Tin", url = "/sach-noi/cong-nghe-thong-tin/" },
    { name = "Sách nói Thể Thao - Võ Thuật", url = "/sach-noi/the-thao-vo-thuat/" },
    { name = "Sách nói Yoga - Thiền", url = "/sach-noi/yoga-thien/" },
    { name = "Sách nói Phát Triển Bản Thân", url = "/sach-noi/phat-trien-ban-than/" },
    { name = "Sách nói Ẩm Thực - Nấu Ăn", url = "/sach-noi/am-thuc-nau-an/" },
    { name = "Sách nói Âm Nhạc - Thơ Ca - Hội Họa", url = "/sach-noi/am-nhac-tho-ca-hoi-hoa/" },
    { name = "Sách nói Nuôi Dưỡng Tâm Hồn", url = "/sach-noi/nuoi-duong-tam-hon/" },
    { name = "Sách nói Tình cảm - Gia Đình", url = "/sach-noi/tinh-cam-gia-dinh/" },
    { name = "Sách nói Trẻ Em - Thiếu Nhi", url = "/sach-noi/tre-em-thieu-nhi/" },
    { name = "Sách nói Tuổi Học Trò", url = "/sach-noi/tuoi-hoc-tro/" },
    { name = "Sách nói Tử Vi - Phong Thủy", url = "/sach-noi/tu-vi-phong-thuy/" },
    { name = "Sách nói Biên Khảo - Địa Lý", url = "/sach-noi/bien-khao-dia-ly/" },
    { name = "Sách nói Khám Phá - Bí Ẩn", url = "/sach-noi/kham-pha-bi-an/" },
    { name = "Sách nói Huyền Bí - Giả Tưởng", url = "/sach-noi/huyen-bi-gia-tuong/" },
    { name = "Sách nói Cổ Tích - Thần Thoại", url = "/sach-noi/co-tich-than-thoai/" },
    { name = "Sách nói Phiêu Lưu - Mạo Hiểm", url = "/sach-noi/phieu-luu-mao-hiem/" },
    { name = "Sách nói Trinh Thám - Hình Sự - Kinh Dị", url = "/sach-noi/trinh-tham-hinh-su-kinh-di/" },
    { name = "Sách nói Tiếu Lâm - Hài Hước", url = "/sach-noi/tieu-lam-hai-huoc/" },
    { name = "Sách nói Lãng Mạn - Ngôn Tình", url = "/sach-noi/lang-man-ngon-tinh/" },
    { name = "Sách nói Đam Mỹ - Bách Hợp", url = "/sach-noi/dam-my-bach-hop/" },
    { name = "Sách nói Người Lớn (18+)", url = "/sach-noi/nguoi-lon-18/" },
    { name = "Sách nói Truyện Ngắn - Tiểu Thuyết", url = "/sach-noi/truyen-ngan-tieu-thuyet/" },
    { name = "Sách nói Truyện Dài Trọn Bộ", url = "/sach-noi/truyen-dai-tron-bo/" },
    { name = "Sách nói Kịch Bản - Sân Khấu", url = "/sach-noi/kich-ban-san-khau/" },
    { name = "Sách nói Kiếm Hiệp - Tiên Hiệp", url = "/sach-noi/kiem-hiep-tien-hiep/" },
    { name = "Sách nói Huyền Huyễn - Phóng Tác", url = "/sach-noi/huyen-huyen-phong-tac/" },
    { name = "Sách nói Đang Cập Nhật", url = "/sach-noi/dang-cap-nhat/" },
}

function Source:getCategories()
    local categories = {}
    for _, cat in ipairs(LIBRARY_CATEGORIES) do
        table.insert(categories, {
            name = cat.name,
            url = self.base_url .. cat.url,
            is_audio = false,
        })
    end
    for _, cat in ipairs(AUDIOBOOK_CATEGORIES) do
        table.insert(categories, {
            name = "🔊 " .. cat.name,
            url = self.base_url .. cat.url,
            is_audio = true,
        })
    end
    return categories
end

-- Parse book listing page
function Source:parseListing(html)
    local books = {}
    
    -- Pattern: <a title="..." href="/slug-id.html" class="woocommerce-LoopProduct-link">
    -- Hoặc các thẻ a có chứa hình ảnh.
    for anchor, inner in html:gmatch('<a([^>]-)>(.-)</a>') do
        local href = Util.getAttribute(anchor, "href")
        local title = Util.getAttribute(anchor, "title")
        local is_loop_product = anchor:find("woocommerce%-LoopProduct%-link")
        
        -- Nếu thẻ A không có title, thử tìm trong thẻ img
        local cover_url
        if inner:find("<img") then
            cover_url = inner:match('<img[^>]-src="([^"]+)"')
            if not title or title == "" then
                title = inner:match('<img[^>]-alt="([^"]+)"')
            end
        end
        
        -- Lọc link rác
        if href and title and title ~= "" and not href:match("^#") and not href:match("javascript:") and href:match("%.html$") then
            -- Bỏ qua các bài blog hoặc không phải truyện/sách (tuỳ vào class hoặc url)
            if is_loop_product or (cover_url and href:match("%-%d+%.html$")) then
                local is_audio = title:match("^Audio") ~= nil
                title = title:gsub("^Audio book ", "")
                title = title:gsub("^Sách ", "")
                title = title:gsub(" PDF$", "")
                
                table.insert(books, {
                    source_id = self.id,
                    title = Util.decodeHtml(title),
                    url = Util.absoluteUrl(self.base_url, href),
                    cover_url = cover_url and Util.absoluteUrl(self.base_url, cover_url) or nil,
                    kind = self.kind,
                    is_audio = is_audio,
                })
            end
        end
    end

    return Util.uniqueBy(books, "url")
end

function Source:getCategoryBooks(category, page)
    page = page or 1
    local url = category.url
    if page > 1 then
        url = url .. "?page=" .. page
    end

    local html, err = Http:get(url)
    if not html then
        return nil, err
    end

    local books = self:parseListing(html)

    -- Parse total pages
    local total_pages = page
    for p in html:gmatch('[?&]page=(%d+)') do
        total_pages = math.max(total_pages, tonumber(p) or 1)
    end

    return {
        books = books,
        page = page,
        total_pages = total_pages,
        category = category,
    }
end

-- Get book detail page
function Source:getBookDetail(book)
    local html, err = Http:get(book.url)
    if not html then
        return nil, err
    end

    -- Parse metadata
    local title = html:match("<h1[^>]*>([^<]+)</h1>") or book.title
    local author = html:match('<b>Tác giả :%s*</b>%s*<a[^>]*>([^<]+)</a>')
        or html:match('<b>Tác giả :</b>%s*([^<]+)')
    local narrator = html:match('<b>Giọng đọc :</b>%s*<a[^>]*>([^<]+)</a>')
    local pages = html:match('<b>Số trang :</b>%s*(%d+)')
    local format_info = html:match('<b>Định dạng :</b>%s*([^<]+)')
    local views = html:match('<b>Lượt xem/nghe :</b>%s*(%d+)')
    local size = html:match('<b>Kích thước :</b>%s*([^<]+)')
    local cover_url = html:match('class="border"[^>]-src="([^"]*)"')
        or html:match('src="([^"]*)"[^>]-class="border"')

    -- Parse download links
    local pdf_download_url = html:match('href="(/download/[^"]+)"')
    local audio_download_url = html:match('href="(/audio/[^"]+)"')
    local audio_size = html:match('Sách Nói %(([^%)]+)%)')

    -- Parse read online link
    local read_online_url = html:match('href="(/readbook/[^"]+)"')

    -- Parse audio source (direct MP3 URL)
    local audio_src = html:match('src="(/img/audio/[^"]+%.mp3)"')
        or html:match("src='(/img/audio/[^']+%.mp3)'")

    -- Parse audio chapters from JavaScript
    local audio_chapters = {}
    for timestamp, idx in html:gmatch('myaudio%.currentTime >= ([%d%.]+)[^}]*mouse_click%((%d+)%)') do
        table.insert(audio_chapters, {
            index = tonumber(idx),
            start_time = tonumber(timestamp),
        })
    end

    -- Parse chapter names from the page
    -- Look for ordered list or table of contents
    local toc_html = html:match('<fieldset[^>]-id="mucluc"[^>]*>(.-)</fieldset>')
        or html:match('<div[^>]-id="mucluc"[^>]*>(.-)</div>')
    if toc_html then
        local chapter_idx = 0
        for item in toc_html:gmatch("<li[^>]*>(.-)</li>") do
            chapter_idx = chapter_idx + 1
            local name = Util.stripTags(item)
            if name ~= "" then
                for _, ch in ipairs(audio_chapters) do
                    if ch.index == chapter_idx - 1 then
                        ch.name = name
                    end
                end
            end
        end
    end

    -- Parse genres/categories
    local genres = {}
    for anchor_attrs, anchor_html in html:gmatch('<a[^>]-class="button2"[^>]*href="([^"]*)"[^>]*>([^<]*)</a>') do
        local name = Util.stripTags(anchor_html)
        if name ~= "" then
            table.insert(genres, name)
        end
    end

    -- Description from meta
    local description = Util.getMetaContent(html, "name", "description") or ""

    local has_pdf = pdf_download_url ~= nil
    local has_audio = audio_src ~= nil or audio_download_url ~= nil

    return {
        title = Util.decodeHtml(Util.trim(title)),
        author = author and Util.trim(author) or nil,
        narrator = narrator and Util.trim(narrator) or nil,
        pages = pages,
        format = format_info and Util.trim(format_info) or nil,
        views = views,
        size = size and Util.trim(size) or nil,
        description = description,
        cover_url = cover_url and Util.absoluteUrl(self.base_url, cover_url) or book.cover_url,
        genres = genres,
        -- Download URLs
        has_pdf = has_pdf,
        pdf_download_url = pdf_download_url and Util.absoluteUrl(self.base_url, pdf_download_url) or nil,
        has_audio = has_audio,
        audio_download_url = audio_download_url and Util.absoluteUrl(self.base_url, audio_download_url) or nil,
        audio_src = audio_src and Util.absoluteUrl(self.base_url, audio_src) or nil,
        audio_size = audio_size,
        audio_chapters = #audio_chapters > 0 and audio_chapters or nil,
        read_online_url = read_online_url and Util.absoluteUrl(self.base_url, read_online_url) or nil,
    }
end

-- Download PDF (may go through Google Drive)
function Source:downloadPdf(detail, save_path)
    if not detail.pdf_download_url then
        return nil, "Sách này không có bản PDF để tải"
    end

    Debug.write("[Dilib] Downloading PDF: " .. detail.pdf_download_url)
    return GDrive:download(detail.pdf_download_url, save_path)
end

-- Download audio MP3
function Source:downloadAudio(detail, save_path)
    local audio_url = detail.audio_src or detail.audio_download_url
    if not audio_url then
        return nil, "Sách này không có bản audio để tải"
    end

    Debug.write("[Dilib] Downloading audio: " .. audio_url)

    -- Audio download link might also redirect through GDrive
    if audio_url:match("/audio/") then
        -- Try direct download first via curl
        local curl_cmd = string.format("curl -skSL --output '%s.part' --referer '%s' '%s'", 
            save_path:gsub("'", "'\\''"), 
            self.base_url .. "/", 
            audio_url:gsub("'", "'\\''"))
            
        local ok = os.execute(curl_cmd)
        if ok == 0 or ok == true then
            local rename_ok, rename_err = os.rename(save_path .. ".part", save_path)
            if rename_ok then
                return save_path
            else
                os.remove(save_path .. ".part")
            end
        end
        -- Fallback to GDrive handler
        return GDrive:download(audio_url, save_path)
    end

    -- Direct MP3 URL
    local curl_cmd = string.format("curl -skSL --output '%s.part' --referer '%s' '%s'", 
        save_path:gsub("'", "'\\''"), 
        self.base_url .. "/", 
        audio_url:gsub("'", "'\\''"))
        
    local ok = os.execute(curl_cmd)
    if ok ~= 0 and ok ~= true then
        return nil, "Không thể tải audio (curl failed)"
    end

    local rename_ok, rename_err = os.rename(save_path .. ".part", save_path)
    if not rename_ok then
        os.remove(save_path .. ".part")
        return nil, "Không thể lưu file: " .. tostring(rename_err)
    end

    Debug.write("[Dilib] Audio download complete via curl: " .. save_path)
    return save_path
end

-- Build an HTML info page for a book (readable on e-ink)
function Source:buildInfoPage(detail, save_path)
    local lines = {
        '<!DOCTYPE html>',
        '<html lang="vi">',
        '<head>',
        '  <meta charset="utf-8"/>',
        '  <meta name="viewport" content="width=device-width, initial-scale=1"/>',
        '  <title>' .. Util.escapeHtml(detail.title) .. '</title>',
        '  <style>',
        '    body { line-height: 1.65; margin: 5%; text-align: justify; }',
        '    h1 { font-size: 1.35em; line-height: 1.3; text-align: center; }',
        '    .meta { color: #666; font-size: 0.9em; }',
        '    .toc { margin-top: 1em; }',
        '    .toc li { margin: 0.3em 0; }',
        '    .time { color: #999; font-size: 0.85em; }',
        '  </style>',
        '</head>',
        '<body>',
        '  <h1>' .. Util.escapeHtml(detail.title) .. '</h1>',
    }

    if detail.author then
        table.insert(lines, '  <p class="meta">Tác giả: ' .. Util.escapeHtml(detail.author) .. '</p>')
    end
    if detail.narrator then
        table.insert(lines, '  <p class="meta">Giọng đọc: ' .. Util.escapeHtml(detail.narrator) .. '</p>')
    end
    if detail.format then
        table.insert(lines, '  <p class="meta">Định dạng: ' .. Util.escapeHtml(detail.format) .. '</p>')
    end
    if detail.pages then
        table.insert(lines, '  <p class="meta">Số trang: ' .. Util.escapeHtml(detail.pages) .. '</p>')
    end
    if detail.size then
        table.insert(lines, '  <p class="meta">Kích thước: ' .. Util.escapeHtml(detail.size) .. '</p>')
    end

    table.insert(lines, '  <hr/>')
    if detail.description and detail.description ~= "" then
        table.insert(lines, '  <p>' .. Util.escapeHtml(detail.description) .. '</p>')
    end

    if detail.audio_chapters and #detail.audio_chapters > 0 then
        table.insert(lines, '  <hr/>')
        table.insert(lines, '  <h2>Mục lục Audio</h2>')
        table.insert(lines, '  <ol class="toc">')
        for _, ch in ipairs(detail.audio_chapters) do
            local minutes = math.floor(ch.start_time / 60)
            local seconds = math.floor(ch.start_time % 60)
            local time_str = string.format("%d:%02d", minutes, seconds)
            local name = ch.name or ("Phần " .. (ch.index + 1))
            table.insert(lines, string.format(
                '    <li>%s <span class="time">[%s]</span></li>',
                Util.escapeHtml(name), time_str
            ))
        end
        table.insert(lines, '  </ol>')
    end

    if #detail.genres > 0 then
        table.insert(lines, '  <hr/>')
        table.insert(lines, '  <p class="meta">Thể loại: ' .. Util.escapeHtml(table.concat(detail.genres, ", ")) .. '</p>')
    end

    table.insert(lines, '</body>')
    table.insert(lines, '</html>')

    local file, err = io.open(save_path, "wb")
    if not file then
        return nil, err
    end
    file:write(table.concat(lines, "\n"))
    file:close()
    return save_path
end

-- Search (AJAX API)
function Source:search(query)
    local encoded = ko_util.urlEncode(query)
    local url = self.base_url .. "/search/ajax-search.php?keyword=" .. encoded
    local html, err = Http:get(url, {
        ["Referer"] = self.base_url .. "/",
        ["X-Requested-With"] = "XMLHttpRequest",
    })
    if not html then
        return nil, err
    end

    local stories = {}
    -- Parse search result items
    for block in html:gmatch('<a[^>]-href="([^"]*)"[^>]-title="([^"]*)"[^>]*>(.-)</a>') do
        -- block captures are href, title, inner
    end

    -- Better pattern for the AJAX response
    for anchor_attrs, anchor_content in html:gmatch("<a([^>]*)>(.-)</a>") do
        local href = Util.getAttribute(anchor_attrs, "href")
        local title = Util.getAttribute(anchor_attrs, "title")
        if href and href:match("%.html$") and title and title ~= "" then
            local cover_url = anchor_content:match('src="([^"]*)"')
            -- Extract author
            local author = anchor_content:match("Tác giả : ([^\n<]+)")

            table.insert(stories, {
                source_id = self.id,
                title = Util.decodeHtml(title),
                url = Util.absoluteUrl(self.base_url, href),
                cover_url = cover_url and Util.absoluteUrl(self.base_url, cover_url) or nil,
                kind = self.kind,
                author = author and Util.trim(author) or nil,
            })
        end
    end

    return Util.uniqueBy(stories, "url")
end

-- Compatibility: getCompleted returns categories for browsing
function Source:getCompleted(page)
    return {
        stories = {},
        genres = {},
        page = 1,
        total_pages = 1,
        title = "Dilib Thư Viện Số",
    }
end

return Source
