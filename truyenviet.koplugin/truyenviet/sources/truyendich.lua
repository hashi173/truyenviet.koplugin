local Http = require("truyenviet/http_client")
local Util = require("truyenviet/helpers")
local ko_util = require("util")

local Source = {
    id = "truyendich",
    name = "Truyendich",
    kind = "text",
    base_url = "https://truyendich.ai",
}

function Source:getCoverHeaders()
    return {
        ["Referer"] = self.base_url .. "/",
    }
end

function Source:parseSearch(html)
    local stories = {}
    for anchor_attrs, href, content in html:gmatch("<a([^>]*)href=\"(/doc%-truyen/[^\"]+)\"[^>]*>([%s%S]-)</a>") do
        local image_tag = content:match("(<img[^>]*>)")
        
        local title = Util.getAttribute(anchor_attrs, "title")
        if not title and image_tag then
            title = Util.getAttribute(image_tag, "alt")
            if title and title:find("Ảnh bìa truyện ") then
                title = title:gsub("Ảnh bìa truyện ", "")
            end
        end
        if not title then
            local h3 = content:match("<h3[^>]*>([%s%S]-)</h3>")
            if h3 then title = Util.stripTags(h3) end
        end

        if href and title and image_tag then
            table.insert(stories, {
                source_id = self.id,
                title = Util.decodeHtml(title),
                url = Util.absoluteUrl(self.base_url, href),
                cover_url = Util.absoluteUrl(
                    self.base_url,
                    Util.getAttribute(image_tag, "src") or Util.getAttribute(image_tag, "data-src")
                ),
                kind = self.kind,
            })
        end
    end
    return Util.uniqueBy(stories, "url")
end

function Source:search(query)
    local encoded = ko_util.urlEncode(query):gsub("%%20", "+")
    local html, err = Http:get(self.base_url .. "/tim-kiem?keyword=" .. encoded)
    if not html then
        return nil, err
    end
    return self:parseSearch(html)
end

function Source:parseListing(html, page)
    local total_pages = 1
    local max_page = html:match("<!%-%- %-%-> / %s*<!%-%- %-%->(%d+)")
    if max_page then
        total_pages = tonumber(max_page)
    else
        total_pages = Util.maxPage(html, page)
    end

    return {
        stories = self:parseSearch(html),
        genres = Util.parseGenres(html, self.base_url),
        page = page or 1,
        total_pages = total_pages,
    }
end

function Source:getCompleted(page)
    page = page or 1
    local url = self.base_url .. "/danh-sach/truyen-full"
    if page > 1 then
        url = url .. "?page=" .. page
    end
    local html, err = Http:get(url)
    if not html then
        return nil, err
    end
    local result = self:parseListing(html, page)
    result.title = "Truyện đã hoàn thành"
    return result
end

function Source:getGenre(genre, page)
    page = page or 1
    local url = genre.url:gsub("%?.*$", "")
    if page > 1 then
        url = url .. "?page=" .. page
    end
    local html, err = Http:get(url)
    if not html then
        return nil, err
    end
    local result = self:parseListing(html, page)
    result.title = genre.name
    result.genre = genre
    return result
end

function Source:parseStoryDetails(html)
    local description_html = html:match('<div[^>]-class="[^"]*desc%-text[^"]*"[^>]*>([%s%S]-)</div>')
    local author = html:match('<a[^>]-itemprop="author"[^>]*>([%s%S]-)</a>')
    
    return {
        description = Util.stripTags(description_html) ~= "" and Util.stripTags(description_html) or Util.getMetaContent(html, "name", "description"),
        author = Util.stripTags(author),
        status = Util.stripTags(html:match('Trạng thái:.-<span[^>]*>([%s%S]-)</span>')),
        genres = Util.parseGenreNames(html),
    }
end

function Source:getStoryDetails(story)
    local html, err = Http:get(story.url)
    if not html then
        return nil, err
    end
    return self:parseStoryDetails(html)
end

function Source:parseStoryPage(html, story, page)
    local chapters = {}
    local slug = story.url:match("([^/]+)$") or ""
    local start_at = html:find('Danh sách chương') or 1
    local chapter_html = html:sub(start_at)

    for anchor_attrs, anchor_html in chapter_html:gmatch("<a([^>]*)>([%s%S]-)</a>") do
        local href = Util.getAttribute(anchor_attrs, "href")
        if href and href:find("/chuong-", 1, true) and href:find(slug, 1, true) then
            local title = Util.stripTags(anchor_html)
            table.insert(chapters, {
                title = title ~= "" and title or Util.getAttribute(anchor_attrs, "title"),
                url = Util.absoluteUrl(self.base_url, href),
                source_id = self.id,
                story_url = story.url,
                kind = self.kind,
            })
        end
    end

    local total_pages = 1
    local max_page = html:match("<!%-%- %-%-> / %s*<!%-%- %-%->(%d+)")
    if max_page then
        total_pages = tonumber(max_page)
    else
        total_pages = Util.maxPage(html, page)
    end

    story.details = self:parseStoryDetails(html)
    return {
        story = story,
        chapters = Util.uniqueBy(chapters, "url"),
        page = page or 1,
        total_pages = total_pages,
    }
end

function Source:getStoryPage(story, page)
    page = page or 1
    local page_url = story.url:gsub("/trang%-%d+", ""):gsub("%?.*$", "")
    if page > 1 then
        page_url = page_url .. "/trang-" .. page
    end
    local html, err = Http:get(page_url)
    if not html then
        return nil, err
    end
    return self:parseStoryPage(html, story, page)
end

function Source:parseChapter(html, chapter)
    local chapter_title = Util.stripTags(html:match('<h2[^>]*chapter%-title[^>]*>([%s%S]-)</h2>'))

    local start_at = html:find('id="chapter%-c"')
    if not start_at then
        return nil, "Không tìm thấy nội dung chương"
    end
    start_at = html:find(">", start_at, true)

    local end_at = html:find('</div>', start_at) or #html
    local content = Util.sanitizeContentHtml(html:sub(start_at + 1, end_at - 1))

    return {
        title = chapter_title or chapter.title,
        content = content,
        url = chapter.url,
        kind = self.kind,
    }
end

function Source:getChapter(chapter)
    local html, err = Http:get(chapter.url)
    if not html then
        return nil, err
    end
    return self:parseChapter(html, chapter)
end

return Source
