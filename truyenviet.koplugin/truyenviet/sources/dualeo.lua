local Http = require("truyenviet/http_client")
local Util = require("truyenviet/helpers")
local ko_util = require("util")

local b64chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/'
local b64dec = {}
for i = 1, 64 do b64dec[b64chars:sub(i,i)] = i - 1 end
local function base64_decode(str)
    str = str:gsub('[^A-Za-z0-9+/=]', '')
    local len = #str
    local out = {}
    for i = 1, len, 4 do
        local c1, c2, c3, c4 = str:sub(i,i), str:sub(i+1,i+1), str:sub(i+2,i+2), str:sub(i+3,i+3)
        local n1, n2, n3, n4 = b64dec[c1], b64dec[c2], b64dec[c3] or 0, b64dec[c4] or 0
        local v = n1 * 262144 + n2 * 4096 + n3 * 64 + n4
        table.insert(out, string.char(math.floor(v / 65536) % 256))
        if c3 ~= '=' then table.insert(out, string.char(math.floor(v / 256) % 256)) end
        if c4 ~= '=' then table.insert(out, string.char(v % 256)) end
    end
    return table.concat(out)
end

local function decrypt_dualeo_url(url)
    local path, filename, ext = url:match("^(.-)/([^/%.]+)%.([^/%.]+)$")
    if not filename then return url end

    local base64 = filename:gsub("-", "+"):gsub("_", "/")
    local pad = (4 - (#base64 % 4)) % 4
    base64 = base64 .. string.rep("=", pad)
    
    local ok, decoded = pcall(base64_decode, base64)
    if not ok or not decoded then return url end

    local salt = "dualeo_salt_2025"
    local ok_bit, bit = pcall(require, "bit")
    if not ok_bit then return url end
    
    local decrypted = ""
    for i = 1, #decoded do
        local charCode = decoded:byte(i)
        local saltCode = salt:byte((i - 1) % #salt + 1)
        decrypted = decrypted .. string.char(bit.bxor(charCode, saltCode))
    end
    
    if decrypted:match("^[A-Za-z0-9%-]+$") then
        return path .. "/" .. decrypted .. "." .. ext
    end
    return url
end

local Source = {
    id = "dualeo",
    name = "Dưa Leo Truyện",
    kind = "comic",
    base_url = "https://dualeotruyenhn.com",
    reversed_chapters = true,
}

local function requestHeaders(referer)
    return {
        ["Referer"] = referer or (Source.base_url .. "/"),
        ["Accept-Language"] = "vi-VN,vi;q=0.9,en;q=0.7",
    }
end

function Source:getCoverHeaders()
    return requestHeaders()
end

function Source:parseSearch(html)
    local stories = {}
    local position = 1

    while true do
        local item_start = html:find('<div class="li_truyen"', position, true)
        if not item_start then
            break
        end
        local next_item = html:find('<div class="li_truyen"', item_start + 1, true)
        local item_html = html:sub(item_start, (next_item or (#html + 1)) - 1)
        position = next_item or (#html + 1)

        local anchor = item_html:match("(<a[^>]*>)")
        local href = Util.getAttribute(anchor, "href")
        local image_tag = item_html:match("(<img[^>]*>)")
        local title = item_html:match('<div[^>]-class="name"[^>]*>([%s%S]-)</div>')
        title = Util.stripTags(title) ~= "" and Util.stripTags(title)
            or Util.getAttribute(image_tag, "alt")

        if href and href:find("/truyen-tranh/", 1, true) and title and title ~= "" then
            local cover = Util.getAttribute(image_tag, "data-src")
                or Util.getAttribute(image_tag, "src")
            table.insert(stories, {
                source_id = self.id,
                title = Util.decodeHtml(title),
                url = Util.absoluteUrl(self.base_url, href),
                cover_url = Util.absoluteUrl(self.base_url, cover),
                kind = self.kind,
            })
        end
    end

    return Util.uniqueBy(stories, "url")
end

function Source:search(query)
    local encoded = ko_util.urlEncode(query):gsub("%%20", "+")
    local html, err = Http:get(
        self.base_url .. "/tim-kiem?key=" .. encoded,
        requestHeaders()
    )
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
    local url = self.base_url .. "/truyen-hoan-thanh"
    if page > 1 then
        url = url .. "?page=" .. page
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
    local url = genre.url:gsub("%?.*$", "")
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
    local description_html = html:match(
        '<div[^>]-class="[^"]*story%-detail%-info[^"]*"[^>]*>([%s%S]-)</div>'
    )
    local genre_html = html:match(
        '<ul[^>]-class="[^"]*list%-tag%-story[^"]*"[^>]*>([%s%S]-)</ul>'
    )
    local info_html = html:match(
        '<div[^>]-class="txt"[^>]*>([%s%S]-)</div>'
    )
    local info_text = Util.stripTags(info_html)

    return {
        description = Util.stripTags(description_html)
            ~= "" and Util.stripTags(description_html)
            or Util.getMetaContent(html, "name", "description"),
        translator = info_text:match("Nhóm dịch:%s*([^\n]+)"),
        status = info_text:match("Tình trạng:%s*([^\n]+)")
            or info_text:match("Tình trang:%s*([^\n]+)"),
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
    local chapter_prefix = story_url .. "/chapter-"
    local chapter_start = html:find('<div class="list-chapters"', 1, true)
    local chapter_html = chapter_start and html:sub(chapter_start) or ""

    if not story.cover_url then
        local cover = html:match(
            '<meta%s+property="og:image"%s+content="([^"]+)"'
        )
        story.cover_url = Util.absoluteUrl(self.base_url, cover)
    end

    for anchor_attrs, anchor_html in chapter_html:gmatch("<a([^>]*)>([%s%S]-)</a>") do
        local href = Util.getAttribute(anchor_attrs, "href")
        local chapter_url = Util.absoluteUrl(self.base_url, href)
        if chapter_url and chapter_url:sub(1, #chapter_prefix) == chapter_prefix then
            local title_html = anchor_html:match("^([%s%S]-)</div>") or anchor_html
            local title = Util.stripTags(title_html)
            table.insert(chapters, {
                title = title ~= "" and title
                    or Util.getAttribute(anchor_attrs, "title")
                    or Util.urlLeaf(chapter_url, "Chapter"),
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
    local start_at = html:find('<div class="content_view_chap"', 1, true)
    local end_at = start_at
        and html:find('<div class="control_bottom_content"', start_at, true)
    if not start_at then
        return nil, "Không tìm thấy vùng ảnh của chương"
    end

    local content = html:sub(start_at, (end_at or (#html + 1)) - 1)
    for image_tag in content:gmatch("(<img[^>]*>)") do
        local url = Util.getAttribute(image_tag, "data-img")
            or Util.getAttribute(image_tag, "data-src")
            or Util.getAttribute(image_tag, "src")
        if url and not url:find("^data:", 1, false) then
            url = Util.absoluteUrl(self.base_url, url)
            if url and not url:find("/avatar/") and not url:find("logo") then
                url = decrypt_dualeo_url(url)
                table.insert(images, { urls = { url } })
            end
        end
    end
    local unique_images = {}
    local seen = {}
    for _, image in ipairs(images) do
        local url = image.urls[1]
        if not seen[url] then
            seen[url] = true
            table.insert(unique_images, image)
        end
    end
    if #unique_images == 0 then
        return nil, "Không tìm thấy ảnh của chương"
    end

    local title = html:match("<title>([%s%S]-)</title>")
    title = title and Util.stripTags(title):gsub("%s*%-%s*DuaLeoTruyen%s*$", "")

    return {
        title = title ~= "" and title or chapter.title,
        images = unique_images,
        url = chapter.url,
        referer = chapter.url,
        kind = self.kind,
    }
end

function Source:getChapter(chapter)
    local html, err = Http:get(chapter.url, requestHeaders(chapter.story_url))
    if not html then
        return nil, err
    end
    return self:parseChapter(html, chapter)
end

function Source:getImageHeaders()
    return {
        ["Referer"] = self.base_url,
        ["Accept"] = "image/webp,image/apng,image/*,*/*;q=0.8",
        ["Accept-Language"] = "vi-VN,vi;q=0.9,en;q=0.7",
        ["Cache-Control"] = "no-cache",
    }
end

return Source
