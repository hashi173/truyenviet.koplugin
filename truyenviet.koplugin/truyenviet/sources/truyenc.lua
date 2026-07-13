local Http = require("truyenviet/http_client")
local Util = require("truyenviet/helpers")
local ko_util = require("util")

local Source = {
    id = "truyenc",
    name = "TruyenC",
    kind = "text",
    base_url = "https://truyenc.com",
}

local CATEGORIES = {
    { name = "Truyện ma", path = "/tim-truyen-ma" },
    { name = "Truyện 18+", path = "/tim-truyen-18" },
    { name = "Truyện cười", path = "/tim-truyen-cuoi" },
    { name = "Truyện audio", path = "/tim-truyen-audio" },
    { name = "Chưa phân loại", path = "/tim-truyen-chua-phan-loai" },
    { name = "Truyện cười vova", path = "/truyen-cuoi-vova" },
    { name = "Truyện cười 18+", path = "/truyen-cuoi-18" },
    { name = "Truyện cười tình yêu", path = "/truyen-cuoi-tinh-yeu" },
    { name = "Truyện trạng Quỳnh", path = "/truyen-trang-quynh" },
    { name = "Truyện cười dân gian", path = "/truyen-cuoi-dan-gian" },
    { name = "Truyên cười quốc tế", path = "/truyen-cuoi-quoc-te" },
    { name = "Truyện cười khác", path = "/truyen-cuoi-khac" },
    { name = "Truyện ma Việt Nam", path = "/truyen-ma-viet-nam" },
    { name = "Truyện ma Trung Quốc", path = "/truyen-ma-trung-quoc" },
    { name = "Truyện ma ngắn", path = "/truyen-ma-ngan" },
    { name = "Truyện ma dài kỳ", path = "/truyen-ma-dai-ky" },
    { name = "Truyện ma hay", path = "/truyen-ma-hay" },
    { name = "Truyện ma có thật", path = "/truyen-ma-co-that" },
    { name = "Truyện ma Nguyễn Ngọc Ngạn", path = "/truyen-ma-nguyen-ngoc-ngan" },
    { name = "Truyện kinh dị", path = "/truyen-kinh-di" },
    { name = "Truyện ma audio", path = "/truyen-ma-audio" },
    { name = "Truyện audio kiếm hiệp", path = "/truyen-audio-kiem-hiep" },
    { name = "Truyện audio ngôn tình", path = "/truyen-audio-ngon-tinh" },
    { name = "Đọc truyện đêm khuya", path = "/truyen-dem-khuya" },
    { name = "Truyện audio trinh thám", path = "/truyen-audio-trinh-tham" },
    { name = "Truyện audio ngắn", path = "/truyen-audio-ngan" },
    { name = "Truyện sắc hiệp", path = "/truyen-sac-hiep" },
    { name = "Truyện Sex", path = "/truyen-sex" },
    { name = "Truyện Sex Audio", path = "/truyen-sex-audio" },
    { name = "Truyện Voz", path = "/truyen-voz" },
    { name = "Truyện có thật", path = "/truyen-co-that" },
    { name = "Truyện dâm hiệp", path = "/truyen-dam-hiep" },
    { name = "Truyện kiếm hiệp", path = "/truyen-kiem-hiep" },
    { name = "Truyện H", path = "/truyen-h" },
}

local PATH_SET = {}
for _, cat in ipairs(CATEGORIES) do
    PATH_SET[cat.path] = true
end

local function stdHeaders(base_url)
    return {
        ["Referer"] = base_url .. "/",
    }
end

local function getGenreList()
    local genres = {}
    for _, cat in ipairs(CATEGORIES) do
        table.insert(genres, { name = cat.name, url = "https://truyenc.com" .. cat.path })
    end
    return genres
end

-- Cấu trúc thẻ truyện: xác nhận bằng fetch trực tiếp (11/07/2026) các URL
-- thật /tim-truyen-ma, /truyen/{slug}-{id}, ảnh https://i.truyenc.com/img/...
-- QUAN TRỌNG: công cụ fetch ở đây trả về nội dung đã được chuyển sang
-- Markdown, KHÔNG phải HTML gốc, nên tên class/id CSS dưới đây là suy đoán
-- theo mẫu theme WordPress tiếng Việt phổ biến (giống cấu trúc đã xác nhận
-- đúng ở aztruyen.lua: <h2><a href title></a></h2> đi kèm <a><img></a> bọc
-- ảnh bìa), CHƯA được xác nhận từng byte HTML thật. Cần test trên máy thật;
-- nếu 0 kết quả thì bật lại phần "Dự phòng" bên dưới hoặc báo lại để chỉnh.
local function parseStories(html, source_id)
    local stories = {}
    local seen = {}

    local cover_by_url = {}
    for url, cover in html:gmatch(
        '<a[^>]+href="(https?://truyenc%.com/truyen/[%w%-]+%-%d+)"[^>]*>%s*<img[^>]+src="(https?://i%.truyenc%.com/img/[^"]+)"'
    ) do
        cover_by_url[url] = cover
    end

    for url, title in html:gmatch(
        '<h2[^>]*>%s*<a[^>]+href="(https?://truyenc%.com/truyen/[%w%-]+%-%d+)"[^>]*title="([^"]+)"'
    ) do
        if not seen[url] then
            seen[url] = true
            table.insert(stories, {
                source_id = source_id,
                title = Util.decodeHtml(title),
                url = url,
                cover_url = cover_by_url[url],
                kind = "text",
            })
        end
    end

    -- Dự phòng: nếu <h2> không khớp, thử bắt trực tiếp theo cặp href+title
    -- bất kỳ trỏ tới /truyen/{slug}-{id} (không phụ thuộc thẻ bao quanh)
    if #stories == 0 then
        for href, title in html:gmatch(
            '<a[^>]+href="(https?://truyenc%.com/truyen/[%w%-]+%-%d+)"[^>]*title="([^"]+)"'
        ) do
            if not seen[href] and title ~= "Đọc truyện" then
                seen[href] = true
                table.insert(stories, {
                    source_id = source_id,
                    title = Util.decodeHtml(title),
                    url = href,
                    cover_url = cover_by_url[href],
                    kind = "text",
                })
            end
        end
    end

    return stories
end

function Source:search(query)
    -- LƯU Ý: chưa xác minh được truyenc.com có endpoint tìm kiếm URL-based
    -- hay không (không thấy ô tìm kiếm dùng GET query string khi fetch thật
    -- các trang danh mục). Thử /tim-kiem/{query} theo mẫu chung của các
    -- nguồn khác trong plugin; nếu sai cần bạn cho biết URL tìm kiếm thật.
    local encoded = ko_util.urlEncode(query)
    local url = self.base_url .. "/tim-kiem/" .. encoded
    local html, err = Http:get(url, stdHeaders(self.base_url))
    if not html then return nil, err end
    return parseStories(html, self.id)
end

function Source:getCompleted(page)
    page = page or 1
    -- Site không có khái niệm "truyện hoàn thành" riêng biệt đã xác nhận
    -- được; dùng mục an toàn đầu tiên (Truyện ma) làm danh sách mặc định,
    -- các mục còn lại truy cập qua "Thể loại" (safeGenreList).
    local first = CATEGORIES[1]
    local url = self.base_url .. first.path
    if page > 1 then url = url .. "?page=" .. page end
    local html, err = Http:get(url, stdHeaders(self.base_url))
    if not html then return nil, err end

    local total_pages = tonumber(html:match('trang%-(%d+)"[^>]*>Trang cuối'))
        or tonumber(html:match('%?page=(%d+)"[^>]*>»'))
        or page

    return {
        stories = parseStories(html, self.id),
        genres = getGenreList(),
        page = page,
        total_pages = total_pages,
        title = first.name,
    }
end

function Source:getGenre(genre, page)
    page = page or 1
    -- An toàn ở lớp thứ hai: chỉ cho phép fetch nếu path nằm trong danh sách
    -- SAFE_PATH_SET, kể cả khi genre.url bị truyền vào từ nơi khác trong
    -- code (ví dụ do lỗi lập trình sau này vô tình nối thêm mục ngoài ý muốn).
    local path = genre.url:gsub("^https?://truyenc%.com", "")
    if not PATH_SET[path] then
        return nil, "Thể loại này không được hỗ trợ trong TruyenC."
    end

    local url = genre.url
    if page > 1 then url = url .. "?page=" .. page end
    local html, err = Http:get(url, stdHeaders(self.base_url))
    if not html then return nil, err end

    local total_pages = tonumber(html:match('trang%-(%d+)"[^>]*>Trang cuối'))
        or tonumber(html:match('%?page=(%d+)"[^>]*>»'))
        or page

    return {
        stories = parseStories(html, self.id),
        genres = getGenreList(),
        page = page,
        total_pages = total_pages,
        title = genre.name,
    }
end

function Source:getStoryDetails(story)
    local html, err = Http:get(story.url, stdHeaders(self.base_url))
    if not html then return nil, err end

    local title = html:match('<h1[^>]*>([^<]+)</h1>')
    local author = html:match('Tác giả:%s*<[^>]+>%s*<strong>([^<]+)</strong>')
        or html:match('Tác giả:%s*<strong>([^<]+)</strong>')

    local status = html:match('Tình trạng:%s*([^<\n]+)')
    if status then status = Util.trim(status) end

    -- Thể loại: trang chi tiết thật có 1 dòng liệt kê nhiều link thể loại
    -- ngay dưới ảnh bìa (vd "Truyện ma · Truyện ma dài kỳ · Truyện kinh dị").
    local genres = {}
    for href, name in html:gmatch('<a[^>]+href="(https?://truyenc%.com/[%w%-]+)"[^>]*title="([^"]+)"') do
        local path = href:gsub("^https?://truyenc%.com", "")
        if PATH_SET[path] then
            table.insert(genres, Util.decodeHtml(name))
        end
    end

    local desc_block = html:match('<div class="content%-story"[^>]*>(.-)</div>%s*<div class="list%-chapter"')
        or html:match('<div class="desc%-text"[^>]*>(.-)</div>')
        or html:match('<div class="content%-story"[^>]*>(.-)</div>')

    local description = desc_block and Util.stripTags(desc_block) or nil
    if description then
        description = description:gsub("^%s+", ""):gsub("%s+$", "")
    end

    return {
        title = title and Util.decodeHtml(Util.trim(title)) or story.title,
        author = author and Util.trim(author) or nil,
        status = status,
        genres = genres,
        description = description,
    }
end

function Source:getStoryPage(story, page)
    page = page or 1
    local html, err = Http:get(story.url, stdHeaders(self.base_url))
    if not html then return nil, err end

    -- Chương thật dạng: https://truyenc.com/truyen/{slug}/chuong-{n}-{ten}-{id}
    -- (đã xác nhận qua fetch thật trang cam-tu-ky-bao-79). Site có vẻ liệt
    -- kê TOÀN BỘ chương trên 1 trang chi tiết (không phân trang danh sách
    -- chương riêng) — nên total_pages luôn = 1 trừ khi phát hiện phân trang
    -- thật khi test.
    local chapters = {}
    local seen = {}
    
    local story_slug = story.url:match("/truyen/([^/]+)")
    local base_slug = ""
    if story_slug then
        base_slug = story_slug:gsub("%-%d+$", "")
    end
    
    local pattern = 'href="(https?://truyenc%.com/truyen/[^"]+/chuong%-[^"]+)"'
    if base_slug ~= "" then
        pattern = 'href="(https?://truyenc%.com/truyen/' .. base_slug:gsub("%-", "%%-") .. '/[^"]+)"'
    end
    
    local all_matches = {}
    for anchor in html:gmatch('<a%s+[^>]*>') do
        local href = anchor:match(pattern)
        local title = anchor:match('title="([^"]+)"')
        if href and title then
            table.insert(all_matches, {href = href, title = title})
        end
    end

    local reversed_chapters = {}
    for i = #all_matches, 1, -1 do
        local href = all_matches[i].href
        if not seen[href] then
            seen[href] = true
            table.insert(reversed_chapters, {
                title = Util.trim(Util.decodeHtml(all_matches[i].title)),
                url = href,
                source_id = self.id,
                story_url = story.url,
                kind = self.kind,
            })
        end
    end

    for i = #reversed_chapters, 1, -1 do
        table.insert(chapters, reversed_chapters[i])
    end

    story.details = self:getStoryDetails(story)

    return {
        story = story,
        chapters = chapters,
        page = 1,
        total_pages = 1,
    }
end

-- CHƯA XÁC MINH ĐƯỢC: tên class/id thẻ bao nội dung chương thật (công cụ
-- fetch chỉ trả về text đã strip HTML). Thử theo thứ tự các tên phổ biến ở
-- theme truyện tiếng Việt; bắt buộc phải test trên máy thật và báo lại tên
-- đúng nếu cả 5 pattern dưới đây đều không khớp, để cập nhật lại cho chuẩn.
local CONTENT_PATTERNS = {
    '<div class="chapter%-content"[^>]*>(.-)</div>%s*<div',
    '<div class="content%-chap"[^>]*>(.-)</div>%s*<div',
    '<div class="box%-chap"[^>]*>(.-)</div>%s*<div',
    '<div id="chapter%-content"[^>]*>(.-)</div>',
    '<div class="reading%-content"[^>]*>(.-)</div>%s*<div',
}

local function extractChapterContent(html, chapter_title)
    -- Tìm nội dung giữa <div class="story-content">, <div class="chapter-content"> và thẻ đóng
    local start_idx, content_start = html:find('<div class="story%-content"[^>]*>')
    if not start_idx then
        start_idx, content_start = html:find('<div class="chapter%-content"[^>]*>')
    end
    if not start_idx then
        start_idx, content_start = html:find('<div id="chapter%-content"[^>]*>')
    end
    if not start_idx then
        start_idx, content_start = html:find('<div class="content%-chap"[^>]*>')
    end
    if not start_idx then
        start_idx, content_start = html:find('<div class="box%-chap"[^>]*>')
    end
    if not start_idx then
        start_idx, content_start = html:find('<div class="reading%-content"[^>]*>')
    end

    if content_start then
        local end_idx = html:find('<div class="row mt%-2">', content_start)
        if not end_idx then
            end_idx = html:find('<div class="d%-flex justify%-content%-between', content_start)
        end
        if not end_idx then
            end_idx = html:find('<div class="text%-center">', content_start)
        end
        
        if end_idx then
            local content = html:sub(content_start + 1, end_idx - 1)
            content = content:gsub('</div[^>]*>%s*$', '')
            if Util.trim(Util.stripTags(content)) ~= "" then
                return content
            end
        end
    end

    for _, pattern in ipairs(CONTENT_PATTERNS) do
        local content = html:match(pattern)
        if content and #Util.trim(Util.stripTags(content)) > 50 then
            return content
        end
    end

    if chapter_title and chapter_title ~= "" then
        local esc_title = chapter_title:gsub("([%(%)%.%%%+%-%*%?%[%]%^%$])", "%%%1")
        local menu_s = html:find("Danh mục", 1, true)
        if menu_s then
            local last_pos = nil
            local search_from = 1
            while true do
                local s, e = html:find(esc_title, search_from, true)
                if not s or s >= menu_s then break end
                last_pos = e
                search_from = e + 1
            end
            if last_pos then
                local candidate = html:sub(last_pos + 1, menu_s - 1)
                if #Util.trim(Util.stripTags(candidate)) > 50 then
                    return candidate
                end
            end
        end
    end

    return nil
end

function Source:getChapter(chapter)
    local html, err = Http:get(chapter.url, stdHeaders(self.base_url))
    if not html then return nil, err end

    local content = extractChapterContent(html, chapter.title)
    if not content then
        return nil, "Không tìm thấy nội dung chương (cần xác minh lại tên thẻ HTML thật trên máy)."
    end

    return Util.sanitizeContentHtml(content)
end

function Source:getChapterAsync(chapter)
    local html, err = Http:requestAsync("GET", chapter.url, nil, stdHeaders(self.base_url))
    if not html then return nil, err end

    local content = extractChapterContent(html, chapter.title)
    if not content then
        return nil, "Không tìm thấy nội dung chương (cần xác minh lại tên thẻ HTML thật trên máy)."
    end

    return Util.sanitizeContentHtml(content)
end

return Source