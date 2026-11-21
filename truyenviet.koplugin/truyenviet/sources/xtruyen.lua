local Http = require("truyenviet/http_client")
local Util = require("truyenviet/helpers")
local ko_util = require("util")

local Source = {
    id = "xtruyen",
    name = "XTruyện",
    kind = "text",
    base_url = "https://xtruyen.vn",
    max_concurrent = 3,
}

local XTRUYEN_SRC_ALPHA = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_"
local XTRUYEN_DST_ALPHA = "flcTV7LmxO9NuBUqaCd+vjJt/rFz0o2QkXeyKS6MPA51shWYRgEDi3nIZ8GHw4pb"
local XTRUYEN_CHAR_MAP = {}
for i = 1, #XTRUYEN_SRC_ALPHA do
    XTRUYEN_CHAR_MAP[XTRUYEN_SRC_ALPHA:sub(i, i)] = XTRUYEN_DST_ALPHA:sub(i, i)
end

local function requestHeaders(referer)
    return {
        ["Referer"] = referer or (Source.base_url .. "/"),
    }
end

function Source:getCoverHeaders()
    return requestHeaders()
end

local function stripHtmlComments(html)
    return (tostring(html or ""):gsub("<!%-%-[%s%S]-%-%->", ""))
end

local function parseGenres(html, base_url)
    local genres = {}
    local clean = stripHtmlComments(html)
    for anchor_attrs, anchor_html in clean:gmatch("<a([^>]*)>([%s%S]-)</a>") do
        local href = Util.getAttribute(anchor_attrs, "href")
        if href and href:find("/theloai/", 1, true) then
            local name = Util.stripTags(anchor_html)
            if name ~= "" then
                table.insert(genres, {
                    name = name,
                    url = Util.absoluteUrl(base_url, href):gsub("%?.*$", ""),
                })
            end
        end
    end
    genres = Util.uniqueBy(genres, "url")
    table.sort(genres, function(left, right)
        return Util.normalizeSearch(left.name) < Util.normalizeSearch(right.name)
    end)
    return genres
end

function Source:parseSearch(html)
    local stories = {}
    local source_html = tostring(html or "")
    local position = 1

    while true do
        local item_start = source_html:find('class="popular-item-wrap"', position, true)
        if not item_start then
            break
        end
        local next_item = source_html:find('class="popular-item-wrap"', item_start + 1, true)
        local block = source_html:sub(item_start, (next_item or (#source_html + 1)) - 1)
        position = next_item or (#source_html + 1)

        local story_anchor, story_href, story_title
        for anchor_attrs, anchor_inner in block:gmatch("<a([^>]*)>([%s%S]-)</a>") do
            local href = Util.getAttribute(anchor_attrs, "href")
            if href and href:find("/truyen/", 1, true) and not href:find("/chuong%-", 1, false) then
                local title = Util.getAttribute(anchor_attrs, "title")
                if not title or Util.trim(title) == "" then
                    title = Util.stripTags(anchor_inner)
                end
                if title and Util.trim(title) ~= "" then
                    story_anchor = anchor_attrs
                    story_href = href
                    story_title = Util.decodeHtml(Util.trim(title))
                    break
                end
            end
        end

        if story_anchor and story_href and story_title and story_title ~= "" then
            local image_tag = block:match("(<img[^>]*>)")
            local cover = Util.getAttribute(image_tag, "data-src")
                or Util.getAttribute(image_tag, "src")
            table.insert(stories, {
                source_id = self.id,
                title = story_title,
                url = Util.absoluteUrl(self.base_url, story_href),
                cover_url = Util.absoluteUrl(self.base_url, cover),
                kind = self.kind,
            })
        end
    end

    return Util.uniqueBy(stories, "url")
end

function Source:search(query)
    local trimmed = Util.trim(query)
    if trimmed == "" then
        return {}
    end
    local encoded = ko_util.urlEncode(trimmed):gsub("%%20", "+")
    local url = self.base_url .. "/?s=" .. encoded .. "&post_type=wp-manga"
    local html, err = Http:get(url, requestHeaders())
    if not html then
        return nil, err
    end
    return self:parseSearch(html)
end

function Source:parseListing(html, page)
    page = page or 1
    return {
        stories = self:parseSearch(html),
        genres = parseGenres(html, self.base_url),
        page = page,
        total_pages = Util.maxPage(html, page),
    }
end

function Source:getCompleted(page)
    page = page or 1
    local url = self.base_url .. "/truyen/?status%5B%5D=end&m_orderby=latest"
    if page > 1 then
        url = url .. "&page=" .. page
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
    local url = Util.withTrailingSlash(genre.url)
    if page > 1 then
        url = url .. "?page=" .. page
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
    local clean = stripHtmlComments(html)
    local author_html = clean:match('<div[^>]-class="[^"]*author%-content[^"]*"[^>]*>([%s%S]-)</div>')
    local genres_html = clean:match('<div[^>]-class="[^"]*genres%-content[^"]*"[^>]*>([%s%S]-)</div>')
    local desc_html = clean:match('<div[^>]-class="[^"]*summary__content[^"]*"[^>]*>([%s%S]-)</div>')
        or clean:match('<div[^>]-class="[^"]*description%-summary[^"]*"[^>]*>([%s%S]-)</div>')
    local cover_html = clean:match('<div[^>]-class="[^"]*summary_image[^"]*"[^>]*>([%s%S]-)</div>')
    local cover_tag = cover_html and cover_html:match("(<img[^>]*>)")
    local cover = Util.getAttribute(cover_tag, "data-src")
        or Util.getAttribute(cover_tag, "src")
        or Util.getMetaContent(clean, "property", "og:image")

    local status_html = clean:match('Trạng thái%s*</h%d>%s*</div>%s*<div[^>]-class="[^"]*summary%-content[^"]*"[^>]*>([%s%S]-)</div>')
        or clean:match('Tình trạng%s*</h%d>%s*</div>%s*<div[^>]-class="[^"]*summary%-content[^"]*"[^>]*>([%s%S]-)</div>')

    local genres = {}
    if genres_html then
        for anchor_html in genres_html:gmatch("<a[^>]*>([%s%S]-)</a>") do
            local name = Util.trim(Util.stripTags(anchor_html))
            if name ~= "" then
                table.insert(genres, name)
            end
        end
    end

    local author = Util.trim(Util.stripTags(author_html))
    local status = Util.trim(Util.stripTags(status_html))
    local description = Util.stripTags(desc_html)
    if description == "" then
        description = Util.getMetaContent(clean, "name", "description") or ""
    end

    return {
        author = author ~= "" and author or nil,
        status = status ~= "" and status or nil,
        genres = genres,
        description = description,
        cover_url = Util.absoluteUrl(self.base_url, cover),
    }
end

function Source:getStoryDetails(story)
    local html, err = Http:get(story.url, requestHeaders())
    if not html then
        return nil, err
    end
    return self:parseStoryDetails(html)
end

function Source:parseChapterRangeJson(raw_json, story)
    local decoded = Util.decodeJson(raw_json)
    if type(decoded) ~= "table" then
        return {}
    end
    local chapters = {}
    local base_story_url = Util.withTrailingSlash(story.url)
    for _, item in ipairs(decoded) do
        if type(item) == "table" and item.s and tostring(item.s) ~= "" then
            local name = Util.trim(Util.decodeHtml(tostring(item.n or item.s))):gsub(":%s*$", "")
            local extra = Util.trim(Util.decodeHtml(tostring(item.e or "")))
            local title = extra ~= "" and (name .. " - " .. extra) or name
            table.insert(chapters, {
                title = title,
                url = base_story_url .. tostring(item.s) .. "/",
                source_id = self.id,
                story_url = story.url,
                kind = self.kind,
            })
        end
    end
    return Util.uniqueBy(chapters, "url")
end

function Source:parseStoryPage(html, story, page)
    local source_html = tostring(html or "")
    local chapters = {}

    for item_html in source_html:gmatch('<li[^>]-class="[^"]*wp%-manga%-chapter[^"]*"[^>]*>([%s%S]-)</li>') do
        local anchor = item_html:match("(<a[^>]*>)")
        local href = Util.getAttribute(anchor, "href")
        local title = Util.trim(Util.stripTags(item_html))
        if href and title ~= "" then
            table.insert(chapters, {
                title = title,
                url = Util.absoluteUrl(self.base_url, href),
                source_id = self.id,
                story_url = story.url,
                kind = self.kind,
            })
        end
    end

    local ranges = {}
    for li_attrs in source_html:gmatch("<li([^>]-class=\"[^\"]*has%-child[^\"]*\"[^>]*)>") do
        local range_val = Util.getAttribute(li_attrs, "data-value")
        local from_val, to_val
        if range_val then
            from_val, to_val = range_val:match("^([%w]+)%-to%-([%w]+)$")
        end
        if from_val and to_val then
            table.insert(ranges, {
                from = from_val,
                to = to_val,
                vol = Util.getAttribute(li_attrs, "data-vol") or "",
            })
        end
    end

    local manga_id = source_html:match('"manga_id"%s*:%s*"?(%d+)"?')
        or source_html:match('data%-id="(%d+)"')

    story._xtruyen_ranges = ranges
    story._xtruyen_manga_id = manga_id
    story.details = self:parseStoryDetails(source_html)
    if (not story.cover_url or story.cover_url == "") and story.details and story.details.cover_url then
        story.cover_url = story.details.cover_url
    end

    return {
        story = story,
        chapters = Util.uniqueBy(chapters, "url"),
        page = page or 1,
        total_pages = math.max(1, #ranges),
    }
end

function Source:getStoryPage(story, page)
    page = page or 1
    if page <= 1 or not story._xtruyen_ranges or not story._xtruyen_manga_id then
        local html, err = Http:get(story.url, requestHeaders())
        if not html then
            return nil, err
        end
        local first_page = self:parseStoryPage(html, story, 1)
        if page <= 1 and (#first_page.chapters > 0 or #(story._xtruyen_ranges or {}) == 0 or not story._xtruyen_manga_id) then
            return first_page
        end
    end

    local ranges = story._xtruyen_ranges or {}
    local range = ranges[page]
    if not range or not story._xtruyen_manga_id then
        return {
            story = story,
            chapters = {},
            page = page,
            total_pages = math.max(1, #ranges),
        }
    end

    local body, err = Http:postForm(self.base_url .. "/api/api-chapters.php", {
        manga_id = story._xtruyen_manga_id,
        from = range.from,
        to = range.to,
        vol = range.vol or "",
    }, {
        ["Referer"] = story.url,
        ["X-Requested-With"] = "XMLHttpRequest",
        ["X-Custom-Auth"] = "abC0000011111",
    })
    if not body then
        return nil, err
    end

    return {
        story = story,
        chapters = self:parseChapterRangeJson(body, story),
        page = page,
        total_pages = math.max(1, #ranges),
    }
end

local function zlibInflate(compressed)
    local ok_zlib, zlib = pcall(require, "ffi/zlib")
    if not ok_zlib or type(zlib) ~= "table" or type(zlib.zlib_uncompress) ~= "function" then
        return nil, "Thiếu thư viện ffi/zlib để giải nén nội dung chương"
    end
    local buf_size = math.max(#compressed * 8, 16384)
    while buf_size <= 4 * 1024 * 1024 do
        local ok, result = pcall(zlib.zlib_uncompress, compressed, buf_size)
        if ok and type(result) == "string" then
            return result
        end
        buf_size = buf_size * 2
    end
    return nil, "Không thể giải nén nội dung chương XTruyện"
end

function Source:decodeChapterPayload(encoded)
    if type(encoded) ~= "string" or encoded == "" then
        return nil, "Dữ liệu chương rỗng"
    end
    local standard_b64 = encoded:gsub("[A-Za-z0-9%-_]", function(ch)
        return XTRUYEN_CHAR_MAP[ch] or ch
    end)
    local compressed = Util.decodeBase64(standard_b64)
    if not compressed or #compressed < 2 then
        return nil, "Dữ liệu chương mã hóa không hợp lệ"
    end
    return zlibInflate(compressed)
end

local function cleanChapterHtml(content)
    content = tostring(content or "")
    content = content:gsub("^%s*<p>%s*(<p>)", "%1")
    content = content:gsub("(</p>)%s*</p>%s*$", "%1")
    content = content:gsub("</p>%s*<br%s*/?>%s*<p>", "</p><p>")
    return Util.sanitizeContentHtml(content)
end

function Source:parseChapter(html, chapter)
    local source_html = tostring(html or "")
    local content

    local encoded = source_html:match('encodedData%s*:%s*"([^"]+)"')
    if encoded and encoded ~= "" then
        local decoded, dec_err = self:decodeChapterPayload(encoded)
        if not decoded then
            return nil, dec_err
        end
        content = decoded
    else
        local container_open = source_html:match('(<div[^>]-id="chapter%-reading%-content"[^>]*>)')
        if container_open and not container_open:find('data%-seo%-preview="1"', 1, true) then
            local start_at = source_html:find(container_open, 1, true)
            if start_at then
                local body_start = start_at + #container_open
                local body_end = source_html:find("</div>", body_start, true)
                if body_end then
                    content = source_html:sub(body_start, body_end - 1)
                end
            end
        end
    end

    if not content or Util.stripTags(content) == "" then
        return nil, "Không tìm thấy nội dung chương"
    end

    local title = source_html:match("<h1[^>]-id=\"chapter%-heading\"[^>]*>[%s%S]-</h1>%s*<h2>([%s%S]-)</h2>")
        or source_html:match("<h2>([%s%S]-)</h2>")
    title = Util.trim(Util.stripTags(title))

    return {
        title = title ~= "" and title or chapter.title,
        content = cleanChapterHtml(content),
        url = chapter.url,
        kind = self.kind,
    }
end

function Source:getChapter(chapter)
    if type(chapter) ~= "table" or not chapter.url then
        return nil, "URL chương không hợp lệ"
    end
    local html, err = Http:get(chapter.url, requestHeaders(chapter.story_url))
    if not html then
        return nil, err
    end
    return self:parseChapter(html, chapter)
end

function Source:getChapterAsync(chapter)
    if type(chapter) ~= "table" or not chapter.url then
        return nil, "URL chương không hợp lệ"
    end
    local html, err = Http:requestAsync("GET", chapter.url, nil, requestHeaders(chapter.story_url))
    if not html then
        return nil, err
    end
    return self:parseChapter(html, chapter)
end

return Source
