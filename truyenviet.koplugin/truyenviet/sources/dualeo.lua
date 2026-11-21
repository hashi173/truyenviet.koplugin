local Http = require("truyenviet/http_client")
local Util = require("truyenviet/helpers")
local ko_util = require("util")

local function decrypt_dualeo_url(url)
    local path, filename, ext = url:match("^(.-)/([^/%.]+)%.([^/%.]+)$")
    if not filename then return url end

    local base64 = filename:gsub("-", "+"):gsub("_", "/")
    local pad = (4 - (#base64 % 4)) % 4
    base64 = base64 .. string.rep("=", pad)

    local ok, decoded = pcall(Util.decodeBase64, base64)
    if not ok or not decoded or decoded == "" then return url end

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
    -- Verified canonical active domain on 2026-11-21 (REST JSON API).
    -- SourceRegistry still honours any user-selected custom domain.
    base_url = "https://dualeotruyenbg.com",
    legacy_base_urls = {
        "https://dualeotruyenhn.com",
        "https://dualeotruyenpt.com",
        "https://dualeotruyenbs.com",
        "https://dualeotruyenpet.com",
        "https://dualeotruyen.net",
    },
    reversed_chapters = true,
}

local function normalizeUrl(self, url)
    if type(url) ~= "string" or url == "" then
        return url
    end
    for _, legacy in ipairs(self.legacy_base_urls or {}) do
        if url:sub(1, #legacy):lower() == legacy:lower() then
            return self.base_url:gsub("/+$", "") .. url:sub(#legacy + 1)
        end
    end
    return url
end

local function requestHeaders(referer)
    return {
        ["Referer"] = referer or (Source.base_url .. "/"),
        ["Accept-Language"] = "vi-VN,vi;q=0.9,en;q=0.7",
    }
end

local function extractSlug(story_or_url)
    if type(story_or_url) == "table" and story_or_url.slug and story_or_url.slug ~= "" then
        return story_or_url.slug
    end
    local url = type(story_or_url) == "table" and story_or_url.url or story_or_url
    if type(url) ~= "string" then return nil end
    local clean = url:gsub("#.*$", ""):gsub("%?.*$", ""):gsub("/+$", "")
    return clean:match("/truyen%-tranh/([^/]+)")
end

local function extractChapterSlugs(chapter)
    local story_slug = chapter.slug or extractSlug(chapter.story_url) or extractSlug(chapter.url)
    local chap_slug = chapter.chapter_slug
    if (not chap_slug or chap_slug == "") and type(chapter.url) == "string" then
        local clean = chapter.url:gsub("#.*$", ""):gsub("%?.*$", ""):gsub("/+$", "")
        chap_slug = clean:match("/chapter%-([^/]+)$")
    end
    return story_slug, chap_slug
end

function Source:getCoverHeaders()
    return requestHeaders()
end

-- ============ JSON API PARSERS (dualeotruyenbg.com) ============

function Source:parseApiGenres(raw_json)
    local decoded = Util.decodeJson(raw_json)
    if type(decoded) ~= "table" then
        return {}
    end
    local genres = {}
    for _, item in ipairs(decoded) do
        local name = type(item) == "table" and item.genre or (type(item) == "string" and item)
        name = Util.trim(name)
        if name ~= "" then
            table.insert(genres, {
                name = name,
                genre_key = name,
                url = self.base_url .. "/api/comics?genre=" .. ko_util.urlEncode(name),
            })
        end
    end
    table.sort(genres, function(left, right)
        return Util.normalizeSearch(left.name) < Util.normalizeSearch(right.name)
    end)
    return genres
end

local function mapApiStories(source, list)
    local stories = {}
    if type(list) ~= "table" then
        return stories
    end
    for _, item in ipairs(list) do
        if type(item) == "table" and item.slug and item.slug ~= "" then
            local title = Util.decodeHtml(Util.trim(item.title or ""))
            if title ~= "" then
                table.insert(stories, {
                    source_id = source.id,
                    title = title,
                    slug = item.slug,
                    url = source.base_url .. "/truyen-tranh/" .. item.slug,
                    cover_url = Util.absoluteUrl(source.base_url, item.cover_url),
                    kind = source.kind,
                })
            end
        end
    end
    return Util.uniqueBy(stories, "url")
end

function Source:parseApiListing(raw_json, page, genres)
    local decoded = Util.decodeJson(raw_json)
    if type(decoded) ~= "table" or type(decoded.data) ~= "table" then
        return nil
    end
    return {
        stories = mapApiStories(self, decoded.data),
        genres = genres or {},
        page = tonumber(decoded.page) or page or 1,
        total_pages = tonumber(decoded.pages) or page or 1,
    }
end

function Source:parseApiSearch(raw_json)
    local decoded = Util.decodeJson(raw_json)
    if type(decoded) ~= "table" then
        return nil
    end
    local list = type(decoded.data) == "table" and decoded.data or decoded
    return mapApiStories(self, list)
end

function Source:parseApiStory(raw_json, story)
    local decoded = Util.decodeJson(raw_json)
    if type(decoded) ~= "table" or not decoded.slug then
        return nil
    end
    local slug = decoded.slug
    story.slug = slug
    if (not story.cover_url or story.cover_url == "") and decoded.cover_url then
        story.cover_url = Util.absoluteUrl(self.base_url, decoded.cover_url)
    end
    local genres = {}
    if type(decoded.genres) == "table" then
        for _, g in ipairs(decoded.genres) do
            local name = Util.trim(type(g) == "table" and g.genre or g)
            if name ~= "" then
                table.insert(genres, name)
            end
        end
    end
    story.details = {
        description = Util.stripTags(decoded.description or ""),
        translator = decoded.team_name and Util.trim(decoded.team_name) or nil,
        status = decoded.status and Util.trim(decoded.status) or nil,
        genres = genres,
        cover_url = Util.absoluteUrl(self.base_url, decoded.cover_url),
    }

    local chapters = {}
    for _, ch in ipairs(decoded.chapters or {}) do
        if type(ch) == "table" and not ch.locked and ch.chapter_slug and tostring(ch.chapter_slug) ~= "" then
            local cslug = tostring(ch.chapter_slug)
            local raw_title = tostring(ch.title or ("Chapter " .. cslug))
            local clean_title = Util.trim(Util.decodeHtml(raw_title:gsub("[\r\n].*$", "")))
            if clean_title == "" then
                clean_title = "Chapter " .. cslug
            end
            table.insert(chapters, {
                title = clean_title,
                url = self.base_url .. "/truyen-tranh/" .. slug .. "/chapter-" .. cslug,
                slug = slug,
                chapter_slug = cslug,
                source_id = self.id,
                story_url = story.url,
                kind = self.kind,
            })
        end
    end

    return {
        story = story,
        chapters = Util.uniqueBy(chapters, "url"),
        page = 1,
        total_pages = 1,
    }
end

function Source:parseApiChapter(raw_json, chapter)
    local decoded = Util.decodeJson(raw_json)
    if type(decoded) ~= "table" then
        return nil, "Không đọc được danh sách ảnh chương"
    end
    local entries = {}
    for idx, item in ipairs(decoded) do
        if type(item) == "table" then
            table.insert(entries, {
                order = tonumber(item.page_index) or idx,
                image_url = item.image_url,
                src = item.src,
            })
        elseif type(item) == "string" then
            table.insert(entries, { order = idx, image_url = item })
        end
    end
    table.sort(entries, function(a, b) return a.order < b.order end)

    local images = {}
    local seen = {}
    for _, entry in ipairs(entries) do
        local urls = {}
        local primary = Util.absoluteUrl(self.base_url, entry.image_url)
        local fallback = Util.absoluteUrl(self.base_url, entry.src)
        if primary and not seen[primary] then
            seen[primary] = true
            table.insert(urls, primary)
        end
        if fallback and fallback ~= primary then
            table.insert(urls, fallback)
        end
        if #urls > 0 then
            table.insert(images, { urls = urls })
        end
    end

    if #images == 0 then
        return nil, "Chương này hiện chưa có ảnh"
    end

    return {
        title = chapter.title,
        images = images,
        url = chapter.url,
        referer = self.base_url .. "/",
        kind = self.kind,
    }
end

function Source:fetchApiGenres()
    if self._cached_genres and self._cached_genres_base == self.base_url then
        return self._cached_genres
    end
    local body = Http:getJson(self.base_url .. "/api/genres", requestHeaders())
    local genres = body and self:parseApiGenres(body) or {}
    if #genres > 0 then
        self._cached_genres = genres
        self._cached_genres_base = self.base_url
    end
    return genres
end

-- ============ LEGACY HTML PARSERS (custom mirrors & fixtures) ============

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
    local trimmed = Util.trim(query)
    if trimmed == "" then
        return {}
    end
    local encoded_q = ko_util.urlEncode(trimmed)
    local api_body, api_err = Http:getJson(
        self.base_url .. "/api/comics/search?q=" .. encoded_q .. "&limit=20",
        requestHeaders()
    )
    if api_body then
        local parsed = self:parseApiSearch(api_body)
        if parsed then
            return parsed
        end
    end

    local encoded = encoded_q:gsub("%%20", "+")
    local html, err = Http:get(
        self.base_url .. "/tim-kiem?key=" .. encoded,
        requestHeaders()
    )
    if not html then
        return nil, err or api_err
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
    local api_url = self.base_url .. "/api/comics/latest?page=" .. page .. "&limit=20&status=Full"
    local api_body, api_err = Http:getJson(api_url, requestHeaders())
    if api_body then
        local result = self:parseApiListing(api_body, page, self:fetchApiGenres())
        if result then
            result.title = "Truyện đã hoàn thành"
            return result
        end
    end

    local url = self.base_url .. "/truyen-hoan-thanh"
    if page > 1 then
        url = url .. "?page=" .. page
    end
    local html, err = Http:get(url, requestHeaders())
    if not html then
        return nil, err or api_err
    end
    local result = self:parseListing(html, page)
    result.title = "Truyện đã hoàn thành"
    return result
end

function Source:getGenre(genre, page)
    page = page or 1
    if genre and (genre.genre_key or (genre.url and genre.url:find("/api/comics", 1, true))) then
        local gname = genre.genre_key or genre.name
        local api_url = self.base_url .. "/api/comics?page=" .. page .. "&limit=20&genre=" .. ko_util.urlEncode(gname)
        local api_body, api_err = Http:getJson(api_url, requestHeaders())
        if api_body then
            local result = self:parseApiListing(api_body, page, self:fetchApiGenres())
            if result then
                result.title = genre.name
                result.genre = genre
                return result
            end
        end
        return nil, api_err
    end

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
    if type(story) == "table" and type(story.details) == "table" and story.details.description then
        return story.details
    end
    local slug = extractSlug(story)
    if slug then
        local api_body = Http:getJson(self.base_url .. "/api/comics/" .. ko_util.urlEncode(slug), requestHeaders())
        if api_body then
            local parsed = self:parseApiStory(api_body, story)
            if parsed and parsed.story and parsed.story.details then
                return parsed.story.details
            end
        end
    end

    local html, err = Http:get(normalizeUrl(self, story.url), requestHeaders())
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
    local slug = extractSlug(story)
    if slug then
        local api_body, api_err = Http:getJson(
            self.base_url .. "/api/comics/" .. ko_util.urlEncode(slug),
            requestHeaders()
        )
        if api_body then
            local parsed = self:parseApiStory(api_body, story)
            if parsed then
                return parsed
            end
        end
        if api_err and api_err:find("Cloudflare", 1, true) then
            return nil, api_err
        end
    end

    story.url = normalizeUrl(self, story.url)
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
    local story_slug, chap_slug = extractChapterSlugs(chapter)
    if story_slug and chap_slug then
        local api_url = self.base_url .. "/api/images/"
            .. ko_util.urlEncode(story_slug) .. "/" .. ko_util.urlEncode(chap_slug)
        local api_body, api_err = Http:getJson(api_url, requestHeaders(chapter.story_url))
        if api_body then
            local payload, parse_err = self:parseApiChapter(api_body, chapter)
            if payload then
                return payload
            end
            if parse_err == "Chương này hiện chưa có ảnh" then
                return nil, parse_err
            end
        end
        if api_err and api_err:find("Cloudflare", 1, true) then
            return nil, api_err
        end
    end

    chapter.url = normalizeUrl(self, chapter.url)
    local html, err = Http:get(chapter.url, requestHeaders(chapter.story_url))
    if not html then
        return nil, err
    end
    return self:parseChapter(html, chapter)
end

function Source:getImageHeaders()
    return {
        ["Referer"] = self.base_url .. "/",
        ["Accept"] = "image/webp,image/apng,image/*,*/*;q=0.8",
        ["Accept-Language"] = "vi-VN,vi;q=0.9,en;q=0.7",
        ["Cache-Control"] = "no-cache",
    }
end

return Source
