local Http = require("truyenviet/http_client")
local Util = require("truyenviet/helpers")
local ko_util = require("util")

local Source = {
    id = "truyenfull",
    name = "TruyenFull",
    kind = "text",
    base_url = "https://truyenfull.today",
}

function Source:getCoverHeaders()
    return {
        ["Referer"] = self.base_url .. "/",
    }
end

function Source:parseSearch(html)
    local stories = {}
    local position = 1

    while true do
        local heading_start, heading_end, heading_attrs, heading_html =
            html:find("<h3([^>]*)>([%s%S]-)</h3>", position)
        if not heading_start then
            break
        end
        if heading_attrs:find("truyen-title", 1, true) then
            local anchor = heading_html:match("(<a[^>]*>)")
            local href = Util.getAttribute(anchor, "href")
            local title = Util.getAttribute(anchor, "title") or Util.stripTags(heading_html)
            if href and title ~= "" then
                local preceding = html:sub(position, heading_start - 1)
                local cover
                for image_url in preceding:gmatch('data%-image="([^"]+)"') do
                    cover = image_url
                end
                table.insert(stories, {
                    source_id = self.id,
                    title = Util.decodeHtml(title),
                    url = Util.absoluteUrl(self.base_url, href),
                    cover_url = Util.absoluteUrl(self.base_url, cover),
                    kind = self.kind,
                })
            end
        end
        position = heading_end + 1
    end

    return Util.uniqueBy(stories, "url")
end

function Source:search(query)
    local encoded = ko_util.urlEncode(query):gsub("%%20", "+")
    local html, err = Http:get(self.base_url .. "/tim-kiem/?tukhoa=" .. encoded)
    if not html then
        return nil, err
    end
    return self:parseSearch(html)
end

function Source:parseListing(html, page)
    return {
        stories = self:parseSearch(html),
        genres = Util.parseGenres(html, self.base_url),
        page = page or 1,
        total_pages = Util.maxPage(html, page),
    }
end

function Source:getCompleted(page)
    page = page or 1
    local url = self.base_url .. "/danh-sach/truyen-full/"
    if page > 1 then
        url = url .. "trang-" .. page .. "/"
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
    local url = Util.withTrailingSlash(genre.url)
    if page > 1 then
        url = url .. "trang-" .. page .. "/"
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
    local description_html = html:match(
        '<div[^>]-class="[^"]*desc%-text[^"]*"[^>]-itemprop="description"[^>]*>([%s%S]-)</div>'
    )
    local author
    for anchor_attrs, anchor_html in html:gmatch("<a([^>]*)>([%s%S]-)</a>") do
        if Util.getAttribute(anchor_attrs, "itemprop") == "author" then
            author = Util.stripTags(anchor_html)
            break
        end
    end

    local info_start = html:find('<div class="info">', 1, true)
    local info_end = info_start
        and html:find('<div class="col-xs-12 col-sm-8', info_start, true)
    local info_html = info_start
        and html:sub(info_start, (info_end or (#html + 1)) - 1)
        or ""

    return {
        description = Util.stripTags(description_html)
            ~= "" and Util.stripTags(description_html)
            or Util.getMetaContent(html, "name", "description"),
        author = author,
        status = Util.stripTags(
            info_html:match('<span[^>]-class="[^"]*text%-success[^"]*"[^>]*>([%s%S]-)</span>')
        ),
        genres = Util.parseGenreNames(info_html),
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
    local start_at = html:find('id="list%-chapter"')
    local end_at = start_at and html:find('id="truyen%-id"', start_at)
    local chapter_html = start_at and html:sub(start_at, (end_at or #html) - 1) or ""

    for anchor_attrs, anchor_html in chapter_html:gmatch("<a([^>]*)>([%s%S]-)</a>") do
        local href = Util.getAttribute(anchor_attrs, "href")
        if href and href:find("/chuong-", 1, true) then
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

    local total_pages = tonumber(html:match('id="total%-page"[^>]-value="(%d+)"')) or 1
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
    local story_url = Util.withTrailingSlash(story.url)
    local page_url = page > 1 and (story_url .. "trang-" .. page .. "/") or story_url
    local html, err = Http:get(page_url)
    if not html then
        return nil, err
    end
    return self:parseStoryPage(html, story, page)
end

function Source:parseChapter(html, chapter)
    local chapter_title
    for heading_html in html:gmatch("<h2[^>]*>([%s%S]-)</h2>") do
        if heading_html:find("chapter-title", 1, true) then
            chapter_title = Util.stripTags(heading_html)
            break
        end
    end

    local start_at = html:find('id="chapter%-c"')
    if not start_at then
        return nil, "Không tìm thấy nội dung chương"
    end
    start_at = html:find(">", start_at, true)

    local end_at = html:find('</div>%s*<div id="ads%-chapter%-bottom"', start_at)
        or html:find('</div>%s*<hr class="chapter%-end"', start_at)
    if not end_at then
        return nil, "Không xác định được điểm kết thúc chương"
    end

    local content = Util.sanitizeContentHtml(html:sub(start_at + 1, end_at - 1))
    content = content:gsub('<div id="ads%-chapter%-top"[^>]*></div>', "")

    local previous_url
    local next_url
    for anchor_attrs in html:gmatch("<a([^>]*)>") do
        local id = Util.getAttribute(anchor_attrs, "id")
        local href = Util.getAttribute(anchor_attrs, "href")
        if href and not href:find("^javascript:") then
            if id == "prev_chap" then
                previous_url = Util.absoluteUrl(self.base_url, href)
            elseif id == "next_chap" then
                next_url = Util.absoluteUrl(self.base_url, href)
            end
        end
    end

    return {
        title = chapter_title or chapter.title,
        content = content,
        previous_url = previous_url,
        next_url = next_url,
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

function Source:getChapterAsync(chapter)
    local html, err = Http:requestAsync("GET", chapter.url)
    if not html then
        return nil, err
    end
    return self:parseChapter(html, chapter)
end

return Source
