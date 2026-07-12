local Http = require("truyenviet/http_client")
local Util = require("truyenviet/helpers")

local Source = {
    id = "mizzya",
    name = "Mizzya",
    kind = "text",
    base_url = "https://mizzya.wordpress.com",
    max_concurrent = 3,
}

local function mizzyaHeaders()
    return {
        ["User-Agent"] = "Mozilla/5.0 (Linux; Android 10; K) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36",
        ["Accept"] = "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8",
        ["Accept-Language"] = "vi-VN,vi;q=0.9,en;q=0.5",
        ["Cache-Control"] = "no-cache",
    }
end

local function mizzyaGet(url)
    local html, err = Http:get(url, mizzyaHeaders(), { force_luasec = true })
    if not html then
        -- Fallback: retry without force_luasec (some Kobo TLS stacks behave differently)
        html, err = Http:get(url, mizzyaHeaders())
    end
    return html, err
end

function Source.getHome()
    local url = Source.base_url .. "/2007/05/15/list-truy%e1%bb%87n/"
    local html, err = mizzyaGet(url)
    if not html then
        return nil, "Không thể kết nối đến máy chủ: " .. tostring(err)
    end

    local items = {}
    local content = html:match('<div class="entry%-content">(.-)<footer') or
                    html:match('<div class="entry%-content">(.-)<div id="jp%-post%-flair"') or
                    html:match('<div class="entry%-content">(.-)</article>')

    if not content then
        return nil, "Không tìm thấy danh sách truyện"
    end

    for href, title in content:gmatch('<a[^>]+href="([^"]+)"[^>]*>([^<]+)</a>') do
        if href:find(Source.base_url, 1, true) and not title:find("<img") then
            title = Util.decodeHtml(title)
            title = Util.stripTags(title)
            if title ~= "" then
                table.insert(items, {
                    source_id = Source.id,
                    title = title,
                    url = href:gsub("#.*$", ""),
                    kind = Source.kind,
                    cover_url = "", -- Đã kiểm tra: trang list của Mizzya là text-only, không có ảnh bìa
                })
            end
        end
    end

    return {
        stories = items,
        genres = {},
        page = 1,
        total_pages = 1,
        title = "Mizzya - Đam Mỹ Hoàn",
    }
end

Source.getLatest = Source.getHome
Source.getCompleted = Source.getHome

function Source:getStoryPage(story, page)
    local html, err = mizzyaGet(story.url)
    if not html then
        return nil, "Không thể kết nối: " .. tostring(err)
    end

    local title = html:match('<h1 class="entry%-title">([^<]+)</h1>') or story.title
    title = Util.decodeHtml(title)
    
    local start_pos = html:find('<div class="entry%-content">')
    local content = ""
    if start_pos then
        local content_start = start_pos + string.len('<div class="entry-content">')
        local e1 = html:find('<div id="jp%-post%-flair"', content_start)
        local e2 = html:find('</div>%s*<!%-%- %.entry%-content %-%->', content_start)
        local e3 = html:find('</div>%s*<footer', content_start)
        local e4 = html:find('</div>%s*</article>', content_start)
        local e5 = html:find('<div class="sharedaddy', content_start)

        local end_pos = nil
        for _, pos in ipairs({e1, e2, e3, e4, e5}) do
            if pos and (not end_pos or pos < end_pos) then
                end_pos = pos
            end
        end

        if end_pos then
            content = html:sub(content_start, end_pos - 1)
        else
            content = html:sub(content_start)
        end
    end
    
    local description = Util.stripTags(content:match("<p>(.-)</p>")) or title
    if description == "" then
        description = title
    end

    local cover = content:match('<img[^>]+src="([^"]+)"')
    if cover then
        cover = Util.absoluteUrl(Source.base_url, cover)
    end

    local author = "Mizzya"
    local author_match = title:match("%s*[-–]%s*([^–-]+)$")
    if author_match then
        author = Util.trim(author_match)
    end

    story.details = {
        title = title,
        author = author,
        description = description,
        cover = cover
    }

    local chapters = {}
    for href, ctitle in content:gmatch('<a[^>]+href="([^"]+)"[^>]*>([^<]+)</a>') do
        if href:find(Source.base_url, 1, true) and not ctitle:find("<img") then
            local is_valid = not href:find("/category/", 1, true) and not href:find("/tag/", 1, true)
            if is_valid and href ~= story.url then
                table.insert(chapters, {
                    title = Util.decodeHtml(Util.stripTags(ctitle)),
                    url = href:gsub("#.*$", ""),
                    source_id = self.id,
                    story_url = story.url,
                    kind = self.kind,
                })
            end
        end
    end

    if #chapters == 0 then
        table.insert(chapters, {
            title = "Full",
            url = story.url,
            source_id = self.id,
            story_url = story.url,
            kind = self.kind,
        })
    end

    return {
        story = story,
        chapters = chapters,
        page = 1,
        total_pages = 1,
    }
end

local function parseChapter(html)
    local start_pos, end_match = html:find('<div[^>]*class="[^"]*entry%-content[^"]*"[^>]*>')
    if not start_pos then
        return nil, "Không tìm thấy nội dung chương"
    end
    
    local content_start = end_match + 1
    
    local e1 = html:find('<div id="jp%-post%-flair"', content_start)
    local e2 = html:find('</div>%s*<!%-%- %.entry%-content %-%->', content_start)
    local e3 = html:find('</div>%s*<footer', content_start)
    local e4 = html:find('</div>%s*</article>', content_start)
    local e5 = html:find('<div class="sharedaddy', content_start)

    local end_pos = nil
    for _, pos in ipairs({e1, e2, e3, e4, e5}) do
        if pos and (not end_pos or pos < end_pos) then
            end_pos = pos
        end
    end

    local content
    if end_pos then
        content = html:sub(content_start, end_pos - 1)
    else
        content = html:sub(content_start)
    end

    if not content or content == "" then
        return nil, "Không tìm thấy nội dung"
    end

    -- Remove extra trailing </div> if any
    content = content:gsub('</div>%s*$', "")
    content = content:gsub('<a[^>]+href="[^"]+"[^>]*>([^<]+)</a>', "%1")
    
    return Util.sanitizeContentHtml(content)
end

function Source:getChapter(chapter)
    local html, err = mizzyaGet(chapter.url)
    if not html then
        return nil, "Không thể kết nối: " .. tostring(err)
    end
    return parseChapter(html)
end

function Source:getChapterAsync(chapter)
    local html, err = Http:requestAsync("GET", chapter.url, nil, mizzyaHeaders())
    if not html then
        return nil, "Không thể kết nối: " .. tostring(err)
    end
    return parseChapter(html)
end

return Source
