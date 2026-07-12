local Http = require("truyenviet/http_client")
local Util = require("truyenviet/helpers")
local ko_util = require("util")

-- MeTruyenVN — Đọc Truyện Đam Mỹ Hoàn (WordPress)
local Source = {
    id = "metruyenvn",
    name = "Mê Truyện VN",
    kind = "text",
    base_url = "https://metruyenvn.org",
}

local function stdHeaders(base_url)
    return {
        ["User-Agent"] = "Mozilla/5.0 (Linux; Android 10; K) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36",
        ["Referer"] = base_url .. "/",
    }
end

local function parseCards(html, source_id)
    local stories = {}
    local seen = {}
    local pos = 1
    while true do
        local block_s, block_e = html:find('<div class="comic-item-box">', pos, true)
        if not block_s then break end
        local block_end = html:find('<div class="comic-item-box">', block_e + 1, true) or #html
        local block = html:sub(block_s, block_end - 1)
        
        local href = block:match('href="(https?://metruyenvn%.org/truyen/[^"]+)"')
        local title = block:match('title="([^"]+)"')
        local cover = block:match('<img[^>]+src="([^"]+)"')
        
        if href and title and not seen[href] then
            seen[href] = true
            table.insert(stories, {
                source_id = source_id,
                title = Util.decodeHtml(title),
                url = href,
                cover_url = cover,
                kind = "text",
            })
        end
        pos = block_e + 1
    end
    return stories
end

local function parseListing(html, page, source_id, base_url)
    local stories = parseCards(html, source_id)
    local max_page = page or 1
    for n in html:gmatch('/page/(%d+)/') do
        local p = tonumber(n)
        if p and p > max_page then max_page = p end
    end
    local genres = {}
    for href, prefix, name in html:gmatch('<a[^>]+href="(https?://metruyenvn%.org/([^/]+)/[^"]+)"[^>]*>([^<]+)</a>') do
        if prefix == "the-loai" or prefix == "nhom" or prefix == "loai-truyen" or prefix == "tu-khoa" or prefix == "tags" or prefix == "tag" then
            table.insert(genres, { name = Util.trim(name), url = href })
        end
    end
    return {
        stories = stories,
        genres = genres,
        page = page or 1,
        total_pages = max_page,
        title = "Truyện mới nhất",
    }
end

function Source:search(query)
    local encoded = ko_util.urlEncode(query)
    local url = self.base_url .. "/?s=" .. encoded
    local html, err = Http:get(url, stdHeaders(self.base_url))
    if not html then return nil, err end
    return parseCards(html, self.id)
end

function Source:getCompleted(page)
    page = page or 1
    local url = self.base_url .. "/"
    if page > 1 then url = url .. "page/" .. page .. "/" end
    local html, err = Http:get(url, stdHeaders(self.base_url))
    if not html then return nil, err end
    local result = parseListing(html, page, self.id, self.base_url)
    result.title = "Truyện đam mỹ mới nhất"
    return result
end

function Source:getGenre(genre, page)
    page = page or 1
    local url = Util.withTrailingSlash(genre.url)
    if page > 1 then url = url .. "page/" .. page .. "/" end
    local html, err = Http:get(url, stdHeaders(self.base_url))
    if not html then return nil, err end
    local result = parseListing(html, page, self.id, self.base_url)
    result.title = genre.name
    return result
end

function Source:getStoryDetails(story)
    local html, err = Http:get(story.url, stdHeaders(self.base_url))
    if not html then return nil, err end
    
    local title = html:match('<meta property="og:title" content="([^"]+)%s*-%s*Mê Truyện')
        or html:match('<h2[^>]*class="[^"]*info%-title[^"]*"[^>]*>([^<]+)</h2>')
        or html:match('<meta itemprop="name" content="([^"]+)">')
    
    local author = html:match('<strong>Tác giả:</strong>%s*<span>%s*(.-)%s*</span>')
        or html:match('Tác giả[%s%S]-<a[^>]*>([^<]+)</a>')
    
    local desc_html = html:match('<div[^>]+class="[^"]*desc%-text[^"]*"[^>]*>(.-)</div>')
        or html:match('<div[^>]+itemprop="description"[^>]*>(.-)</div>')
    
    local description
    if desc_html then
        description = Util.stripTags(desc_html)
        description = description:gsub("^%s+", ""):gsub("%s+$", "")
    end
    
    local genres = {}
    local tags_html = html:match('<div class="tags[^"]*">(.-)</div>')
    if tags_html then
        for name in tags_html:gmatch('<a[^>]*>([^<]+)</a>') do
            table.insert(genres, Util.trim(name))
        end
    end

    local status_html = html:match('<strong>Tình trạng:</strong>%s*<span[^>]*>(.-)</span>')
    local is_completed = false
    if status_html and status_html:find("Trọn bộ") then
        is_completed = true
    end
    
    return {
        title = title and Util.decodeHtml(Util.trim(title)) or story.title,
        author = author and Util.trim(author) or nil,
        description = description,
        genres = genres,
        is_completed = is_completed,
    }
end

function Source:getStoryPage(story, page)
    page = page or 1
    local html, err = Http:get(story.url, stdHeaders(self.base_url))
    if not html then return nil, err end
    
    local chapters = {}
    local seen = {}
    
    -- Chapter format: <a href="https://metruyenvn.org/chuong-123/">...</a>
    for href, inner_html in html:gmatch('<a[^>]+href="(https?://metruyenvn%.org/chuong%-[^"]+)"[^>]*>([%s%S]-)</a>') do
        if not seen[href] then
            seen[href] = true
            local title = inner_html:match('<span class="hidden%-sm hidden%-xs">(.-)</span>')
            if not title then title = inner_html end
            title = Util.trim(Util.stripTags(title))
            table.insert(chapters, 1, {
                title = title,
                url = href,
                source_id = self.id,
                story_url = story.url,
                kind = self.kind,
            })
        end
    end
    
    if #chapters == 0 then
        for href, inner_html in html:gmatch('<a[^>]+class="[^"]*comic%-chapter[^"]*"[^>]+href="([^"]+)"[^>]*>([%s%S]-)</a>') do
            if href:find("^https?://") and not seen[href] then
                seen[href] = true
                local title = inner_html:match('<span class="hidden%-sm hidden%-xs">(.-)</span>')
                if not title then title = inner_html end
                title = Util.trim(Util.stripTags(title))
                table.insert(chapters, 1, {
                    title = title,
                    url = href,
                    source_id = self.id,
                    story_url = story.url,
                    kind = self.kind,
                })
            end
        end
    end
    
    story.details = self:getStoryDetails(story)
    
    return {
        story = story,
        chapters = chapters,
        page = page,
        total_pages = 1,
    }
end

function Source:getChapter(chapter)
    local html, err = Http:get(chapter.url, stdHeaders(self.base_url))
    if not html then return nil, err end
    
    local start_pos = html:find('<div[^>]*class="[^"]*view%-chapter[^"]*"[^>]*>')
        or html:find('<div[^>]*id="chapter%-content"[^>]*>')
        
    if not start_pos then
        return nil, "Không tìm thấy nội dung chương"
    end
    
    local content_start = html:find('>', start_pos)
    if not content_start then return nil, "Lỗi cú pháp HTML" end
    
    local end_pos = html:find('</div>%s*</div>%s*<section', content_start)
        or html:find('</div>%s*<div[^>]*class="margin%-bottom%-15px"', content_start)
        or html:find('</div>%s*<div', content_start)
        
    local content = end_pos and html:sub(content_start + 1, end_pos - 1) or html:sub(content_start + 1)
    
    return Util.sanitizeContentHtml(content)
end

function Source:getChapterAsync(chapter)
    local html, err = Http:requestAsync("GET", chapter.url, nil, stdHeaders(self.base_url))
    if not html then return nil, err end
    local start_pos = html:find('<div[^>]*class="[^"]*view%-chapter[^"]*"[^>]*>')
        or html:find('<div[^>]*id="chapter%-content"[^>]*>')
        
    if not start_pos then
        return nil, "Không tìm thấy nội dung chương"
    end
    
    local content_start = html:find('>', start_pos)
    if not content_start then return nil, "Lỗi cú pháp HTML" end
    
    local end_pos = html:find('</div>%s*</div>%s*<section', content_start)
        or html:find('</div>%s*<div[^>]*class="margin%-bottom%-15px"', content_start)
        or html:find('</div>%s*<div', content_start)
        
    local content = end_pos and html:sub(content_start + 1, end_pos - 1) or html:sub(content_start + 1)
    
    return Util.sanitizeContentHtml(content)
end

return Source

