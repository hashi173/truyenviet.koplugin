local Http = require("truyenviet/http_client")
local Util = require("truyenviet/helpers")
local GDrive = require("truyenviet/gdrive_downloader")
local EbookDownloader = require("truyenviet/ebook_downloader")
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

-- Danh mục sách đọc (EPUB / PDF) trên Dilib, ưu tiên các chuyên mục có tỷ lệ
-- sách còn link tải cao nhất lên đầu và loại bỏ các mục 100% bị gỡ bản quyền (DMCA).
local LIBRARY_CATEGORIES = {
    { name = "Thư Viện Sách Mới", url = "/thu-vien/" },
    { name = "Sách Truyện Ngắn - Tiểu Thuyết", url = "/thu-vien/truyen-ngan-tieu-thuyet/" },
    { name = "Sách Văn Học - Nghệ Thuật", url = "/thu-vien/van-hoc-nghe-thuat/" },
    { name = "Sách Tác Phẩm Kinh Điển", url = "/thu-vien/tac-pham-kinh-dien/" },
    { name = "Sách Lịch Sử - Quân Sự", url = "/thu-vien/lich-su-quan-su/" },
    { name = "Sách Nhân Vật Lịch Sử", url = "/thu-vien/nhan-vat-lich-su/" },
    { name = "Sách Tôn Giáo - Tâm Linh", url = "/thu-vien/ton-giao-tam-linh/" },
    { name = "Sách Triết Học - Lý Luận", url = "/thu-vien/triet-hoc-ly-luan/" },
    { name = "Sách Tử Vi - Phong Thủy", url = "/thu-vien/tu-vi-phong-thuy/" },
    { name = "Sách Khám Phá - Bí Ẩn", url = "/thu-vien/kham-pha-bi-an/" },
    { name = "Sách Văn Hóa - Xã Hội", url = "/thu-vien/van-hoa-xa-hoi/" },
    { name = "Sách Tài Liệu - Tham Khảo", url = "/thu-vien/tai-lieu-tham-khao/" },
    { name = "Sách Phát Triển Bản Thân", url = "/thu-vien/phat-trien-ban-than/" },
    { name = "Sách Khai Tâm - Mở Trí", url = "/thu-vien/khai-tam-mo-tri/" },
    { name = "Sách Cổ Tích - Thần Thoại", url = "/thu-vien/co-tich-than-thoai/" },
    { name = "Sách Kịch Bản - Sân Khấu", url = "/thu-vien/kich-ban-san-khau/" },
    { name = "Sách Yoga - Thiền", url = "/thu-vien/yoga-thien/" },
    { name = "Sách Âm Nhạc - Thơ Ca - Hội Họa", url = "/thu-vien/am-nhac-tho-ca-hoi-hoa/" },
    { name = "Sách Tâm Lý - Kỹ Năng", url = "/thu-vien/tam-ly-ky-nang/" },
    { name = "Sách Biên Khảo - Địa Lý", url = "/thu-vien/bien-khao-dia-ly/" },
    { name = "Sách Nuôi Dưỡng Tâm Hồn", url = "/thu-vien/nuoi-duong-tam-hon/" },
    { name = "Sách Trẻ Em - Thiếu Nhi", url = "/thu-vien/tre-em-thieu-nhi/" },
    { name = "Sách Giáo Dục - Đào Tạo", url = "/thu-vien/giao-duc-dao-tao/" },
    { name = "Sách Thư Viện Pháp Luật", url = "/thu-vien/thu-vien-phap-luat/" },
    { name = "Sách Tiếu Lâm - Hài Hước", url = "/thu-vien/tieu-lam-hai-huoc/" },
    { name = "Sách Khoa Học - Công Nghệ", url = "/thu-vien/khoa-hoc-cong-nghe/" },
    { name = "Sách Nông - Lâm - Ngư", url = "/thu-vien/nong-lam-ngu/" },
    { name = "Sách Y Học - Sức Khỏe", url = "/thu-vien/y-hoc-suc-khoe/" },
    { name = "Sách Hồi Ký - Tùy Bút", url = "/thu-vien/hoi-ky-tuy-but/" },
    { name = "Sách Self Help - Khởi Nghiệp", url = "/thu-vien/self-help-khoi-nghiep/" },
    { name = "Sách Tình Cảm - Gia Đình", url = "/thu-vien/tinh-cam-gia-dinh/" },
    { name = "Sách Truyện Dài Trọn Bộ", url = "/thu-vien/truyen-dai-tron-bo/" },
    { name = "Sách Quản Trị - Kinh Doanh", url = "/thu-vien/quan-tri-kinh-doanh/" },
    { name = "Sách Đường Lối - Chính Trị", url = "/thu-vien/duong-loi-chinh-tri/" },
    { name = "Sách Tuổi Học Trò", url = "/thu-vien/tuoi-hoc-tro/" },
    { name = "Tóm Tắt Sách", url = "/tom-tat-sach/" },
}

-- Danh mục Sách nói / Radio / Kịch truyền thanh còn hoạt động trên Dilib
local AUDIOBOOK_CATEGORIES = {
    { name = "Radio Truyện Ngắn (kèm PDF/EPUB)", url = "/radio/radio-truyen-ngan/" },
    { name = "Radio Truyện Dài Kỳ (kèm PDF/EPUB)", url = "/radio/radio-truyen-dai-ky/" },
    { name = "Kịch Truyền Thanh (kèm PDF/EPUB)", url = "/radio/kich-truyen-thanh/" },
    { name = "Radio Cho Tâm Hồn", url = "/radio/radio-cho-tam-hon/" },
    { name = "Radio Tình Yêu", url = "/radio/radio-tinh-yeu/" },
    { name = "Tản Mạn Radio", url = "/radio/tan-man-radio/" },
    { name = "Sách nói Tâm Lý - Kỹ Năng", url = "/sach-noi/tam-ly-ky-nang/" },
    { name = "Sách nói Tôn Giáo - Tâm Linh", url = "/sach-noi/ton-giao-tam-linh/" },
    { name = "Sách nói Truyện Ngắn - Tiểu Thuyết", url = "/sach-noi/truyen-ngan-tieu-thuyet/" },
    { name = "Sách nói Tác Phẩm Kinh Điển", url = "/sach-noi/tac-pham-kinh-dien/" },
    { name = "Sách nói Nhân Vật Lịch Sử", url = "/sach-noi/nhan-vat-lich-su/" },
    { name = "Sách nói Triết Học - Lý Luận", url = "/sach-noi/triet-hoc-ly-luan/" },
}

local STATIC_IGNORED_PATHS = {
    ["/thu-vien-sach-dien-tu-1066.html"] = true,
    ["/ban-quyen-1055.html"] = true,
}

function Source:getLibraryCategories()
    local categories = {}
    for _, cat in ipairs(LIBRARY_CATEGORIES) do
        table.insert(categories, {
            name = cat.name,
            url = self.base_url .. cat.url,
            is_audio = false,
        })
    end
    return categories
end

function Source:getAudioCategories()
    local categories = {}
    for _, cat in ipairs(AUDIOBOOK_CATEGORIES) do
        table.insert(categories, {
            name = "🔊 " .. cat.name,
            url = self.base_url .. cat.url,
            is_audio = true,
        })
    end
    return categories
end

function Source:getCategories()
    local categories = self:getLibraryCategories()
    for _, cat in ipairs(self:getAudioCategories()) do
        table.insert(categories, cat)
    end
    return categories
end

local function cleanBookTitle(raw_title)
    local title = Util.decodeHtml(Util.trim(raw_title or ""))
    local is_audio = title:match("^Audio") ~= nil or title:match("^Sách nói") ~= nil
    title = title:gsub("^Audio book%s+", "")
    title = title:gsub("^Đọc [Ss]ách%s+", "")
    title = title:gsub("^Đọc [Tt]ruyện [Tt]ranh%s+", "")
    title = title:gsub("^Truyện [Tt]ranh%s+", "")
    title = title:gsub("^Sách%s+", "")
    title = title:gsub("%s+PDF$", "")
    title = title:gsub("%s+EPUB$", "")
    return Util.trim(title), is_audio
end

-- Parse book listing page (scoped to #woo-main when present so sidebar widgets are excluded)
function Source:parseListing(html)
    local raw = tostring(html or "")
    local scope = raw:match('id="woo%-main"[^>]*>([%s%S]-)</main>')
        or raw:match('id="woo%-main"[^>]*>([%s%S]-)<aside')
        or raw:match('id="woo%-main"[^>]*>([%s%S]-)id="secondary"')
        or raw:match('id="woo%-main"[^>]*>([%s%S]-)<footer')
        or raw:match('id="woo%-main"[^>]*>([%s%S]*)$')
        or raw

    local books = {}
    local by_url = {}

    for anchor, inner in scope:gmatch("<a([^>]-)>([%s%S]-)</a>") do
        local href = Util.getAttribute(anchor, "href")
        local title_attr = Util.getAttribute(anchor, "title")
        local is_loop_product = anchor:find("woocommerce%-LoopProduct%-link") ~= nil

        local cover_url
        if inner:find("<img", 1, true) then
            cover_url = inner:match('<img[^>]-src="([^"]+)"')
            if not title_attr or title_attr == "" then
                title_attr = inner:match('<img[^>]-alt="([^"]+)"')
            end
        end

        local path_only = href and href:gsub("^https?://[^/]+", ""):gsub("[?#].*$", "") or nil
        if href and path_only and not STATIC_IGNORED_PATHS[path_only]
                and not href:match("^#") and not href:match("^javascript:")
                and path_only:match("%.html$") then
            if is_loop_product or (cover_url and path_only:match("%-%d+%.html$")) then
                local full_url = Util.absoluteUrl(self.base_url, path_only)
                local raw_title = title_attr
                if (not raw_title or raw_title == "") and not inner:find("<img", 1, true) then
                    raw_title = Util.stripTags(inner)
                end
                local clean_title, is_audio = cleanBookTitle(raw_title)

                -- Check if the text inside <h3><a>Title (Author)</a></h3> has author in parens
                local text_body = not inner:find("<img", 1, true) and Util.trim(Util.stripTags(inner)) or ""
                local paren_author = text_body:match("%(([^%(%)]+)%)%s*$")

                -- Check if thumbnail overlay has badge like "7 quyển: 05:25:48"
                local badge = inner:match("<div[^>]-background:#1e1e1e[^>]*>([^<]+)</div>")
                badge = badge and Util.trim(Util.decodeHtml(badge)) or nil

                if full_url and clean_title ~= "" then
                    local existing = by_url[full_url]
                    if not existing then
                        local entry = {
                            source_id = self.id,
                            title = clean_title,
                            url = full_url,
                            cover_url = cover_url and Util.absoluteUrl(self.base_url, cover_url) or nil,
                            kind = self.kind,
                            is_audio = is_audio,
                            author = paren_author,
                            badge = badge,
                        }
                        by_url[full_url] = entry
                        table.insert(books, entry)
                    else
                        if not existing.cover_url and cover_url then
                            existing.cover_url = Util.absoluteUrl(self.base_url, cover_url)
                        end
                        if not existing.author and paren_author then
                            existing.author = paren_author
                        end
                        if not existing.badge and badge then
                            existing.badge = badge
                        end
                    end
                end
            end
        end
    end

    return books
end

function Source:parseTotalPages(html, current_page)
    local total_pages = tonumber(current_page) or 1
    local raw = tostring(html or "")
    for total in raw:gmatch("<b>%s*Trang%s*</b>%s*%d+%s*/%s*(%d+)") do
        total_pages = math.max(total_pages, tonumber(total) or 1)
    end
    for p in raw:gmatch("/page/(%d+)") do
        local pn = tonumber(p)
        if pn and pn <= 100000 then
            total_pages = math.max(total_pages, pn)
        end
    end
    for p in raw:gmatch("[?&]page=(%d+)") do
        local pn = tonumber(p)
        if pn and pn <= 100000 then
            total_pages = math.max(total_pages, pn)
        end
    end
    return total_pages
end

function Source:getCategoryBooks(category, page)
    page = page or 1
    local base_cat_url = (category and category.url or (self.base_url .. "/thu-vien/")):gsub("/+$", "")
    local url = base_cat_url .. "/"
    if page > 1 then
        url = base_cat_url .. "/page/" .. page
    end

    local html, err = Http:get(url, self:getCoverHeaders())
    if not html then
        return nil, err
    end

    local books = self:parseListing(html)
    local total_pages = self:parseTotalPages(html, page)

    return {
        books = books,
        page = page,
        total_pages = total_pages,
        category = category,
    }
end

function Source:parseBookDetail(html, book)
    html = tostring(html or "")
    book = book or {}

    local title = html:match("<h1[^>]*>([^<]+)</h1>") or book.title or "Sách Dilib"
    local author = html:match('<b>Tác giả%s*:%s*</b>%s*<a[^>]*>([^<]+)</a>')
        or html:match('<b>Tác giả%s*:%s*</b>%s*([^<\n]+)')
    local narrator = html:match('<b>Giọng đọc%s*:%s*</b>%s*<a[^>]*>([^<]+)</a>')
        or html:match('<b>Giọng đọc%s*:%s*</b>%s*([^<\n]+)')
    local pages = html:match('<b>Số trang%s*:%s*</b>%s*(%d+)')
    local format_raw = html:match('<b>Định dạng%s*:%s*</b>%s*(.-)</p>')
        or html:match('<b>Định dạng%s*:%s*</b>%s*([^<\n]+)')
    local format_info = format_raw and Util.trim(Util.stripTags(format_raw):gsub("%s+", " ")) or nil
    local views = html:match('<b>Lượt xem/nghe%s*:%s*</b>%s*(%d+)')
    local size = html:match('<b>Kích thước%s*:%s*</b>%s*([^<\n]+)')
    local cover_url = html:match('class="border"[^>]-src="([^"]*)"')
        or html:match('src="([^"]*)"[^>]-class="border"')

    -- Parse all download links (/download/..., /download/epub/..., /download/mobi/..., etc.)
    local pdf_download_url
    local epub_download_url
    local mobi_download_url
    local azw3_download_url

    for dl_href in html:gmatch('href="(/download/[^"]+)"') do
        local lower = dl_href:lower()
        if lower:match("^/download/epub/") then
            epub_download_url = epub_download_url or dl_href
        elseif lower:match("^/download/mobi/") or lower:match("^/download/prc/") then
            mobi_download_url = mobi_download_url or dl_href
        elseif lower:match("^/download/azw3/") then
            azw3_download_url = azw3_download_url or dl_href
        else
            pdf_download_url = pdf_download_url or dl_href
        end
    end

    -- Parse read online link (/readbook/<code> redirects 301 to Google Drive PDF viewer)
    local read_online_url = html:match('href="(/readbook/[^"]+)"')

    -- Also check if main book area contains a direct Google Drive link
    local main_section = html:match("(<h1[^>]*>[%s%S]-)id=\"comment\"")
        or html:match("(<h1[^>]*>[%s%S]-)<footer")
        or html
    local direct_gdrive_url = main_section:match('(https?://drive%.google%.com/file/d/[^"\'%s<>]+)')
        or main_section:match('(https?://drive%.google%.com/uc%?[^"\'%s<>]+)')

    -- Smart fallback: if book has "Đọc Sách" (/readbook/...) or direct Google Drive link
    -- without a separate /download/... link, capture it as the PDF download source!
    local pdf_from_readbook = false
    if not pdf_download_url then
        if read_online_url then
            pdf_download_url = read_online_url
            pdf_from_readbook = true
        elseif direct_gdrive_url then
            pdf_download_url = direct_gdrive_url
            pdf_from_readbook = true
        end
    end

    local audio_download_url = html:match('href="(/audio/[^"]+)"')
    local audio_size = html:match('Sách Nói %(([^%)]+)%)')
    local audio_src = html:match('src="(/img/audio/[^"]+%.mp3)"')
        or html:match("src='(/img/audio/[^']+%.mp3)'")

    -- Parse audio chapters (supports both modern <div id="muclucN" onclick="jumptime('...')"> and legacy <li>)
    local audio_chapters = {}
    local seen_chapter_idx = {}
    local mucluc_scope = html:match('<fieldset[^>]-id="mucluc"[^>]*>([%s%S]-)</fieldset>') or html
    local pos = 1
    while true do
        local s, e, idx_str, ts_str = mucluc_scope:find(
            '<div[^>]-id="mucluc(%d+)"[^>]-onclick="jumptime%(\'([%d%.]+)\'%)[^"]*"[^>]*>',
            pos
        )
        if not s then break end
        local next_s = mucluc_scope:find('<div[^>]-id="mucluc%d+"', e + 1)
            or mucluc_scope:find("</fieldset>", e + 1, true)
            or (#mucluc_scope + 1)
        local chunk = mucluc_scope:sub(e + 1, next_s - 1)
        local idx = tonumber(idx_str) or #audio_chapters
        if not seen_chapter_idx[idx] then
            seen_chapter_idx[idx] = true
            local text = Util.trim(Util.stripTags(chunk):gsub("%s+", " "))
            text = Util.trim(text:gsub("^%d+:%d+:%d+%s*", ""))
            table.insert(audio_chapters, {
                index = idx,
                start_time = tonumber(ts_str) or 0,
                name = text ~= "" and text or ("Phần " .. (idx + 1)),
            })
        end
        pos = e + 1
    end
    table.sort(audio_chapters, function(a, b) return (a.index or 0) < (b.index or 0) end)

    if #audio_chapters == 0 then
        for timestamp, idx in html:gmatch('myaudio%.currentTime >= ([%d%.]+)[^}]*mouse_click%((%d+)%)') do
            table.insert(audio_chapters, {
                index = tonumber(idx),
                start_time = tonumber(timestamp),
            })
        end
        local toc_html = html:match('<fieldset[^>]-id="mucluc"[^>]*>([%s%S]-)</fieldset>')
            or html:match('<div[^>]-id="mucluc"[^>]*>([%s%S]-)</div>')
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
    end

    -- Parse genres/categories
    local genres = {}
    local seen_genre = {}
    local genre_fieldset = html:match('<fieldset[^>]-id="pdf"[^>]*>([%s%S]-)</fieldset>') or html
    for _, anchor_html in genre_fieldset:gmatch('<a[^>]-class="button2"[^>]*href="([^"]*)"[^>]*>([^<]*)</a>') do
        local name = Util.trim(Util.stripTags(anchor_html))
        if name ~= "" and not seen_genre[name] then
            seen_genre[name] = true
            table.insert(genres, name)
        end
    end

    -- Parse related / same-series books (Sách cùng bộ / cùng tác giả)
    local related_books = {}
    local self_path = tostring(book.url or ""):gsub("^https?://[^/]+", "")
    local seen_related = { [self_path] = true }
    for rel_href, rel_inner in main_section:gmatch('<a[^>]+href="(/[^"#%?]+%-%d+%.html)"[^>]*>([%s%S]-)</a>') do
        if not seen_related[rel_href] and not STATIC_IGNORED_PATHS[rel_href]
                and not rel_href:find("^/tom%-tat%-sach/")
                and not rel_href:find("^/truyen%-tranh/") then
            local rel_text = Util.trim(Util.stripTags(rel_inner):gsub("%s+", " "))
            -- Skip audio/music sidebar recommendations and empty image links
            if rel_text ~= "" and not rel_inner:find("<img", 1, true)
                    and not rel_text:find("^Sách nói:")
                    and not rel_text:find("^Audio") then
                seen_related[rel_href] = true
                table.insert(related_books, {
                    source_id = self.id,
                    title = Util.decodeHtml(rel_text),
                    url = Util.absoluteUrl(self.base_url, rel_href),
                    kind = self.kind,
                })
            end
        end
    end

    local description = Util.getMetaContent(html, "name", "description") or ""

    local abs_pdf = pdf_download_url and Util.absoluteUrl(self.base_url, pdf_download_url) or nil
    local abs_epub = epub_download_url and Util.absoluteUrl(self.base_url, epub_download_url) or nil
    local abs_mobi = mobi_download_url and Util.absoluteUrl(self.base_url, mobi_download_url) or nil
    local abs_azw3 = azw3_download_url and Util.absoluteUrl(self.base_url, azw3_download_url) or nil
    local abs_read = read_online_url and Util.absoluteUrl(self.base_url, read_online_url) or nil
    local abs_audio_dl = audio_download_url and Util.absoluteUrl(self.base_url, audio_download_url) or nil
    local abs_audio_src = audio_src and Util.absoluteUrl(self.base_url, audio_src) or nil

    local has_pdf = abs_pdf ~= nil
    local has_epub = abs_epub ~= nil
    local has_mobi = abs_mobi ~= nil
    local has_azw3 = abs_azw3 ~= nil
    local has_ebook = has_pdf or has_epub or has_mobi or has_azw3
    local has_audio = abs_audio_src ~= nil or abs_audio_dl ~= nil
    local is_dmca = html:find("Khiếu Nại Bản Quyền", 1, true) ~= nil and not has_ebook and not has_audio

    local clean_title = Util.decodeHtml(Util.trim(title))
    local formats = {}
    if abs_epub then
        table.insert(formats, {
            format = "epub",
            label = "EPUB (Khuyên dùng cho máy đọc sách)",
            filename = Util.safeName(clean_title, "book") .. ".epub",
            url = abs_epub,
        })
    end
    if abs_pdf then
        table.insert(formats, {
            format = "pdf",
            label = pdf_from_readbook and "PDF (Tự động bắt từ link Đọc Sách / Google Drive)" or "PDF",
            filename = Util.safeName(clean_title, "book") .. ".pdf",
            url = abs_pdf,
            fallback_url = (not pdf_from_readbook and abs_read ~= abs_pdf) and abs_read or nil,
        })
    end
    if abs_mobi then
        table.insert(formats, {
            format = "mobi",
            label = "MOBI",
            filename = Util.safeName(clean_title, "book") .. ".mobi",
            url = abs_mobi,
        })
    end
    if abs_azw3 then
        table.insert(formats, {
            format = "azw3",
            label = "AZW3",
            filename = Util.safeName(clean_title, "book") .. ".azw3",
            url = abs_azw3,
        })
    end

    local content_kind = "info_only"
    if has_ebook then
        content_kind = "ebook"
    elseif has_audio then
        content_kind = "audio_only"
    elseif is_dmca then
        content_kind = "dmca"
    end

    return {
        title = clean_title,
        author = author and Util.trim(Util.decodeHtml(author)) or book.author,
        narrator = narrator and Util.trim(Util.decodeHtml(narrator)) or nil,
        pages = pages,
        format = format_info,
        views = views,
        size = size and Util.trim(size) or nil,
        description = description,
        cover_url = cover_url and Util.absoluteUrl(self.base_url, cover_url) or book.cover_url,
        genres = genres,
        -- Download & format capabilities
        formats = formats,
        has_ebook = has_ebook,
        has_pdf = has_pdf,
        pdf_download_url = abs_pdf,
        pdf_from_readbook = pdf_from_readbook,
        has_epub = has_epub,
        epub_download_url = abs_epub,
        has_mobi = has_mobi,
        mobi_download_url = abs_mobi,
        has_azw3 = has_azw3,
        azw3_download_url = abs_azw3,
        has_audio = has_audio,
        audio_download_url = abs_audio_dl,
        audio_src = abs_audio_src,
        audio_size = audio_size,
        audio_chapters = #audio_chapters > 0 and audio_chapters or nil,
        read_online_url = abs_read,
        is_dmca = is_dmca,
        content_kind = content_kind,
        related_books = #related_books > 0 and related_books or nil,
    }
end

function Source:getBookDetail(book)
    local html, err = Http:get(book.url, self:getCoverHeaders())
    if not html then
        return nil, err
    end
    return self:parseBookDetail(html, book)
end

-- Download any ebook format (EPUB, PDF, MOBI, AZW3) via GDriveDownloader
function Source:downloadEbook(detail, format, save_path)
    format = tostring(format or "pdf"):lower()
    local target_url
    local fallback_url
    if format == "epub" then
        target_url = detail.epub_download_url
    elseif format == "mobi" then
        target_url = detail.mobi_download_url
    elseif format == "azw3" then
        target_url = detail.azw3_download_url
    else
        target_url = detail.pdf_download_url or detail.read_online_url
        if detail.pdf_download_url and detail.read_online_url and detail.read_online_url ~= detail.pdf_download_url then
            fallback_url = detail.read_online_url
        end
    end

    if not target_url then
        return nil, "Sách này không có bản " .. format:upper() .. " để tải"
    end

    Debug.write("[Dilib] Downloading " .. format:upper() .. ": " .. target_url)
    local saved, err = GDrive:download(target_url, save_path)
    if not saved and fallback_url then
        Debug.write("[Dilib] Primary PDF link failed (" .. tostring(err) .. "), retrying via readbook Google Drive link: " .. fallback_url)
        saved, err = GDrive:download(fallback_url, save_path)
    end
    return saved, err
end

function Source:downloadPdf(detail, save_path)
    return self:downloadEbook(detail, "pdf", save_path)
end

function Source:downloadEpub(detail, save_path)
    return self:downloadEbook(detail, "epub", save_path)
end

-- Download audio MP3 safely via streaming Http:downloadToFile / GDrive
function Source:downloadAudio(detail, save_path)
    local audio_url = detail.audio_src or detail.audio_download_url
    if not audio_url then
        return nil, "Sách này không có bản audio để tải"
    end

    Debug.write("[Dilib] Downloading audio: " .. audio_url)
    local part_path = save_path .. ".part"
    os.remove(part_path)

    if type(Http.downloadToFile) == "function" then
        local downloaded, dl_err, headers = Http:downloadToFile(audio_url, part_path, {
            ["Referer"] = self.base_url .. "/",
        })
        if downloaded then
            local preview = EbookDownloader.readPreview(part_path, 4096)
            local ct = tostring(headers and (headers["content-type"] or headers["Content-Type"]) or ""):lower()
            local is_html = ct:find("text/html", 1, true) ~= nil or (preview and preview:match("^%s*<[!hH]") ~= nil)
            if not is_html and preview and #preview > 0 then
                os.remove(save_path)
                local ok, rename_err = os.rename(part_path, save_path)
                if ok then
                    return save_path
                end
                os.remove(part_path)
                return nil, "Không thể lưu file: " .. tostring(rename_err)
            end
        end
        os.remove(part_path)
        if detail.audio_download_url then
            return GDrive:download(detail.audio_download_url, save_path)
        end
        return nil, dl_err or "Máy chủ không trả về tệp âm thanh hợp lệ"
    end

    return GDrive:download(audio_url, save_path)
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

    if detail.genres and #detail.genres > 0 then
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

function Source:parseSearchHtml(html)
    local stories = {}
    for anchor_attrs, anchor_content in tostring(html or ""):gmatch("<a([^>]*)>([%s%S]-)</a>") do
        local href = Util.getAttribute(anchor_attrs, "href")
        local title = Util.getAttribute(anchor_attrs, "title")
        local path_only = href and href:gsub("^https?://[^/]+", ""):gsub("[?#].*$", "") or nil
        if path_only and path_only:match("%-%d+%.html$") and not STATIC_IGNORED_PATHS[path_only]
                and title and title ~= "" then
            local cover_url = anchor_content:match('src="([^"]*)"')
            local author = anchor_content:match("Tác giả%s*:%s*([^\n<]+)")
            local fmt = anchor_content:match("Định dạng%s*:%s*([^\n<]+)")
            local clean_title, is_audio = cleanBookTitle(title)
            if clean_title ~= "" then
                table.insert(stories, {
                    source_id = self.id,
                    title = clean_title,
                    url = Util.absoluteUrl(self.base_url, path_only),
                    cover_url = cover_url and Util.absoluteUrl(self.base_url, cover_url) or nil,
                    kind = self.kind,
                    author = author and Util.trim(Util.decodeHtml(author)) or nil,
                    format = fmt and Util.trim(Util.decodeHtml(fmt)) or nil,
                    is_audio = is_audio,
                })
            end
        end
    end
    return Util.uniqueBy(stories, "url")
end

-- Search (AJAX API + full search fallback)
function Source:search(query)
    local trimmed = Util.trim(query)
    if trimmed == "" then
        return {}
    end
    local encoded = ko_util.urlEncode(trimmed)
    local url = self.base_url .. "/search/ajax-search.php?keyword=" .. encoded
    local html, err = Http:get(url, {
        ["Referer"] = self.base_url .. "/",
        ["X-Requested-With"] = "XMLHttpRequest",
    })
    local stories = html and self:parseSearchHtml(html) or {}

    if #stories == 0 then
        local page_html, page_err = Http:get(self.base_url .. "/tim-kiem/?keyword=" .. encoded, {
            ["Referer"] = self.base_url .. "/",
        })
        if page_html then
            stories = self:parseListing(page_html)
        elseif not html then
            return nil, err or page_err
        end
    end

    return Util.uniqueBy(stories, "url")
end

function Source:getCompleted(page)
    local result, err = self:getCategoryBooks({
        name = "Thư Viện Sách Mới",
        url = self.base_url .. "/thu-vien/",
    }, page or 1)
    if not result then
        return {
            stories = {},
            genres = {},
            page = 1,
            total_pages = 1,
            title = "Dilib Thư Viện Số",
        }, err
    end
    return {
        stories = result.books or {},
        genres = {},
        page = result.page or 1,
        total_pages = result.total_pages or 1,
        title = "Dilib Thư Viện Số",
    }
end

return Source
