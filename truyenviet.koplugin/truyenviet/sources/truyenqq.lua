local Http = require("truyenviet/http_client")
local Util = require("truyenviet/helpers")

local Source = {
    id = "truyenqq",
    name = "TruyenQQ",
    kind = "comic",
    base_url = "https://truyenqqko.com",
}

local function requestHeaders()
    return {
        ["Referer"] = Source.base_url .. "/",
        ["X-Requested-With"] = "XMLHttpRequest",
    }
end

function Source:getCoverHeaders()
    return requestHeaders()
end

function Source:parseSearch(html)
    local stories = {}

    for item_html in html:gmatch("<li[^>]*>([%s%S]-)</li>") do
        local anchor = item_html:match("(<a[^>]*>)")
        local href = Util.getAttribute(anchor, "href")
        local title = item_html:match('<p[^>]-class="name"[^>]*>([%s%S]-)</p>')
        local image_tag = item_html:match("(<img[^>]*>)")
        if href and title then
            table.insert(stories, {
                source_id = self.id,
                title = Util.stripTags(title),
                url = Util.absoluteUrl(self.base_url, href),
                cover_url = Util.absoluteUrl(
                    self.base_url,
                    Util.getAttribute(image_tag, "src")
                        or Util.getAttribute(image_tag, "data-fb")
                ),
                kind = self.kind,
            })
        end
    end

    return Util.uniqueBy(stories, "url")
end

function Source:search(query)
    local html, err = Http:postForm(
        self.base_url .. "/frontend/search/search",
        { search = query, type = 0 },
        requestHeaders()
    )
    if not html then
        return nil, err
    end
    return self:parseSearch(html)
end

function Source:parseListing(html, page)
    local stories = {}
    local list_start = html:find('<ul class="list_grid grid"', 1, true)
    local list_end = list_start and html:find("</ul>", list_start, true)
    local list_html = list_start
        and html:sub(list_start, (list_end or (#html + 1)) - 1)
        or ""

    for item_html in list_html:gmatch("<li[^>]*>([%s%S]-)</li>") do
        if item_html:find('class="book_avatar"', 1, true) then
            local name_html = item_html:match(
                '<div[^>]-class="book_name[^"]*"[^>]*>([%s%S]-)</div>'
            )
            local anchor = name_html and name_html:match("(<a[^>]*>)")
            local image_tag = item_html:match("(<img[^>]*>)")
            local href = Util.getAttribute(anchor, "href")
            local title = Util.getAttribute(anchor, "title")
                or Util.stripTags(name_html)
            if href and title and title ~= "" then
                table.insert(stories, {
                    source_id = self.id,
                    title = Util.decodeHtml(title),
                    url = Util.absoluteUrl(self.base_url, href),
                    cover_url = Util.absoluteUrl(
                        self.base_url,
                        Util.getAttribute(image_tag, "data-original")
                            or Util.getAttribute(image_tag, "src")
                            or Util.getAttribute(image_tag, "data-fb")
                    ),
                    kind = self.kind,
                })
            end
        end
    end

    return {
        stories = Util.uniqueBy(stories, "url"),
        genres = Util.parseGenres(html, self.base_url),
        page = page or 1,
        total_pages = Util.maxPage(html, page),
    }
end

function Source:getCompleted(page)
    page = page or 1
    local url = self.base_url .. "/truyen-hoan-thanh"
    if page > 1 then
        url = url .. "/trang-" .. page .. "?status=2"
    end
    local html, err = Http:get(url, requestHeaders())
    if not html then
        return nil, err
    end
    local result = self:parseListing(html, page)
    result.title = "Truyện đã hoàn thành"
    return result
end

function Source:getGenre(genre, page)
    page = page or 1
    local url = genre.url:gsub("/+$", "")
    if page > 1 then
        url = url .. "/trang-" .. page
    end
    local html, err = Http:get(url, requestHeaders())
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
        '<div[^>]-class="[^"]*story%-detail%-info[^"]*detail%-content[^"]*"[^>]*>([%s%S]-)</div>'
    )
    local author_html = html:match(
        '<li[^>]-class="[^"]*author[^"]*"[^>]*>([%s%S]-)</li>'
    )
    local status_html = html:match(
        '<li[^>]-class="[^"]*status[^"]*"[^>]*>([%s%S]-)</li>'
    )
    local genre_html = html:match(
        '<ul[^>]-class="[^"]*list01[^"]*"[^>]*>([%s%S]-)</ul>'
    )

    local author
    for paragraph in tostring(author_html or ""):gmatch("<p[^>]*>([%s%S]-)</p>") do
        author = Util.stripTags(paragraph)
    end
    local status
    for paragraph in tostring(status_html or ""):gmatch("<p[^>]*>([%s%S]-)</p>") do
        status = Util.stripTags(paragraph)
    end

    return {
        description = Util.stripTags(description_html)
            ~= "" and Util.stripTags(description_html)
            or Util.getMetaContent(html, "name", "description"),
        author = author,
        status = status,
        genres = Util.parseGenreNames(genre_html),
    }
end

function Source:getStoryDetails(story)
    local html, err = Http:get(story.url, requestHeaders())
    if not html then
        return nil, err
    end
    return self:parseStoryDetails(html)
end

function Source:parseStoryPage(html, story)
    local chapters = {}
    local story_url = story.url:gsub("/+$", "")
    local chapter_prefix = story_url .. "-chap-"

    for anchor_attrs, anchor_html in html:gmatch("<a([^>]*)>([%s%S]-)</a>") do
        local href = Util.getAttribute(anchor_attrs, "href")
        local chapter_url = Util.absoluteUrl(self.base_url, href)
        if chapter_url and chapter_url:sub(1, #chapter_prefix) == chapter_prefix then
            table.insert(chapters, {
                title = Util.stripTags(anchor_html),
                url = chapter_url,
                source_id = self.id,
                story_url = story.url,
                kind = self.kind,
            })
        end
    end

    story.details = self:parseStoryDetails(html)
    return {
        story = story,
        chapters = Util.uniqueBy(chapters, "url"),
        page = 1,
        total_pages = 1,
    }
end

function Source:getStoryPage(story)
    local html, err = Http:get(story.url, requestHeaders())
    if not html then
        return nil, err
    end
    return self:parseStoryPage(html, story)
end

function Source:parseChapter(html, chapter)
    local images = {}
    local position = 1

    while true do
        local open_start, open_end, div_attrs = html:find("<div([^>]*)>", position)
        if not open_start then
            break
        end
        position = open_end + 1

        local page_id = Util.getAttribute(div_attrs, "id") or ""
        local class_name = Util.getAttribute(div_attrs, "class") or ""
        if page_id:match("^page_%d+$")
                and class_name:find("page-chapter", 1, true) then
            local close_start, close_end = html:find("</div>", position, true)
            if not close_start then
                break
            end

            local div_html = html:sub(position, close_start - 1)
            position = close_end + 1
            for image_tag in div_html:gmatch("(<img[^>]*>)") do
                local primary = Util.getAttribute(image_tag, "data-original")
                    or Util.getAttribute(image_tag, "src")
                if primary then
                    local clean_urls = {}
                    local seen = {}
                    local candidates = {
                        primary,
                        Util.getAttribute(image_tag, "data-cdn"),
                        Util.getAttribute(image_tag, "data-fb"),
                    }
                    for index = 1, 3 do
                        local url = Util.absoluteUrl(self.base_url, candidates[index])
                        if url and not seen[url] then
                            seen[url] = true
                            table.insert(clean_urls, url)
                        end
                    end
                    table.insert(images, { urls = clean_urls })
                end
            end
        end
    end

    if #images == 0 then
        return nil, "Không tìm thấy ảnh của chương"
    end

    local title
    for heading_attrs, heading_html in html:gmatch("<h1([^>]*)>([%s%S]-)</h1>") do
        local class_name = Util.getAttribute(heading_attrs, "class") or ""
        if class_name:find("detail-title", 1, true) then
            title = Util.stripTags(heading_html)
            break
        end
    end

    return {
        title = title or chapter.title,
        images = images,
        url = chapter.url,
        referer = self.base_url .. "/",
        kind = self.kind,
    }
end

function Source:getChapter(chapter)
    local html, err = Http:get(chapter.url, requestHeaders())
    if not html then
        return nil, err
    end
    return self:parseChapter(html, chapter)
end

return Source
