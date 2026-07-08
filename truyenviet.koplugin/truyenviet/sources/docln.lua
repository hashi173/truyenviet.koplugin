local Http = require("truyenviet/http_client")
local Util = require("truyenviet/helpers")
local Debug = require("truyenviet/debugger")
local ko_util = require("util")

local Source = {
    id = "docln",
    name = "DocLN (Hako)",
    kind = "text",
    base_url = "https://docln.sbs",
    max_concurrent = 2,
}

-- Login credentials
local LOGIN_USER = "nmdung3456"
local LOGIN_PASS = "nmdung3456"

-- Session cookie management
local session_cookie = nil
local session_cookie_time = 0
local COOKIE_TTL = 30 * 60 -- 30 minutes

local function parseCookiesFromHeader(raw, cookies_table)
    cookies_table = cookies_table or {}
    if not raw then return cookies_table end
    local list = {}
    if type(raw) == "table" then
        for _, v in ipairs(raw) do
            table.insert(list, v)
        end
    else
        for entry in tostring(raw):gmatch("([^,]+)") do
            table.insert(list, entry)
        end
    end
    for _, entry in ipairs(list) do
        local name, value = entry:match("^%s*([^;=]+)=([^;]*)")
        if name then
            name = name:gsub("^%s+", ""):gsub("%s+$", "")
            value = value:gsub("^%s+", ""):gsub("%s+$", "")
            local name_lower = name:lower()
            if name_lower ~= "expires" and name_lower ~= "max-age" and name_lower ~= "path"
               and name_lower ~= "domain" and name_lower ~= "secure" and name_lower ~= "httponly"
               and name_lower ~= "samesite" then
                cookies_table[name] = value
            end
        end
    end
    return cookies_table
end

local function buildCookieString(cookies_table)
    local parts = {}
    for k, v in pairs(cookies_table or {}) do
        table.insert(parts, k .. "=" .. v)
    end
    return table.concat(parts, "; ")
end

local cookies = {}

local function doLogin()
    Debug.write("[docln] Attempting login as " .. LOGIN_USER)

    -- Step 1: GET login page to get CSRF token and initial cookies
    local login_html, err, login_headers = Http:get(Source.base_url .. "/login", {
        ["Referer"] = Source.base_url .. "/",
    })
    if login_headers then
        local set_cookie = login_headers["set-cookie"] or login_headers["Set-Cookie"]
        parseCookiesFromHeader(set_cookie, cookies)
    end

    -- Extract CSRF token
    local csrf_token
    if login_html then
        csrf_token = login_html:match('name="_token"%s*value="([^"]+)"')
            or login_html:match('name="_token" value="([^"]+)"')
            or login_html:match('_token.-%s*value="([^"]+)"')
    end

    if not csrf_token and login_html then
        -- Try meta tag
        csrf_token = login_html:match('<meta name="csrf%-token" content="([^"]+)"')
    end

    Debug.write("[docln] CSRF token: " .. tostring(csrf_token and csrf_token:sub(1, 20) .. "..."))

    -- Step 2: POST login form
    local post_body_parts = {}
    if csrf_token then
        table.insert(post_body_parts, "_token=" .. ko_util.urlEncode(csrf_token))
    end
    table.insert(post_body_parts, "username=" .. ko_util.urlEncode(LOGIN_USER))
    table.insert(post_body_parts, "password=" .. ko_util.urlEncode(LOGIN_PASS))

    local post_body = table.concat(post_body_parts, "&")

    local cookie_str = buildCookieString(cookies)
    local post_headers = {
        ["Content-Type"] = "application/x-www-form-urlencoded",
        ["Referer"] = Source.base_url .. "/login",
        ["Origin"] = Source.base_url,
    }
    if cookie_str ~= "" then
        post_headers["Cookie"] = cookie_str
    end

    local html, post_err, resp_headers, status_code = Http:request(
        "POST", Source.base_url .. "/login", post_body, post_headers, { redirect = false }
    )

    Debug.write("[docln] Login POST status: " .. tostring(status_code))

    if resp_headers then
        local set_cookie = resp_headers["set-cookie"] or resp_headers["Set-Cookie"]
        parseCookiesFromHeader(set_cookie, cookies)
    end

    session_cookie = buildCookieString(cookies)
    session_cookie_time = os.time()

    if session_cookie ~= "" then
        Debug.write("[docln] Login successful, cookies obtained")
        return true
    else
        Debug.write("[docln] Login failed: no cookies")
        return false
    end
end

local function ensureSession()
    if not session_cookie or session_cookie == "" or (os.time() - session_cookie_time) > COOKIE_TTL then
        doLogin()
    end
    return session_cookie
end

local function requestHeaders(referer)
    local headers = {
        ["Referer"] = referer or Source.base_url .. "/",
    }
    local cookie = ensureSession()
    if cookie and cookie ~= "" then
        headers["Cookie"] = cookie
    end
    return headers
end

function Source:getCoverHeaders()
    return {
        ["Referer"] = self.base_url .. "/",
    }
end

-- ========================
-- SEARCH & LISTING
-- ========================

function Source:parseSearch(html)
    local stories = {}

    -- Parse thumb-item-flow cards (listing page)
    for block in html:gmatch('<div[^>]-class="[^"]*thumb%-item%-flow[^"]*"[^>]*>([\001-\255]-)</div>%s*$')  do
        -- fallback below
    end

    -- Parse series-title links paired with cover images
    -- Structure: <div class="thumb-wrapper"> ... <div data-bg="COVER_URL"> ... <div class="series-title"><a href="/truyen/..." title="TITLE">
    local position = 1
    while true do
        local wrapper_start = html:find('class="thumb%-wrapper', position, false)
        if not wrapper_start then break end

        -- Find the end of this thumb item (next thumb-item-flow or end)
        local next_item = html:find('class="thumb%-item%-flow', wrapper_start + 1, false) or #html

        local item_html = html:sub(wrapper_start, next_item - 1)

        -- Extract cover URL from data-bg attribute
        local cover_url = item_html:match('data%-bg="([^"]+)"')

        -- Extract series title link
        local series_title_block = item_html:match('<div[^>]-class="[^"]*series%-title[^"]*"[^>]*>([\001-\255]-)</div>')
        if series_title_block then
            local href = Util.getAttribute(series_title_block:match("(<a[^>]*>)"), "href")
            local title = Util.getAttribute(series_title_block:match("(<a[^>]*>)"), "title")
                or Util.stripTags(series_title_block)

            if href and title and title ~= "" then
                -- Only include /truyen/ links (truyện dịch)
                if href:find("/truyen/", 1, true) or href:find("/sang%-tac/") or href:find("/ai%-dich/") then
                    table.insert(stories, {
                        source_id = self.id,
                        title = Util.decodeHtml(title),
                        url = Util.absoluteUrl(self.base_url, href),
                        cover_url = cover_url,
                        kind = self.kind,
                    })
                end
            end
        end

        position = next_item
    end

    return Util.uniqueBy(stories, "url")
end

function Source:search(query)
    -- DocLN search: use the danh-sach page with search param
    local encoded = ko_util.urlEncode(query):gsub("%%20", "+")
    local html, err = Http:get(
        self.base_url .. "/tim-kiem?q=" .. encoded,
        requestHeaders()
    )
    if not html then
        return nil, err
    end
    return self:parseSearch(html)
end

function Source:parseListing(html, page)
    local stories = self:parseSearch(html)

    -- Parse genres from /the-loai/ links
    local genres = {}
    local seen = {}
    for anchor_attrs, anchor_html in html:gmatch("<a([^>]*)>([%s%S]-)</a>") do
        local href = Util.getAttribute(anchor_attrs, "href")
        if href and href:find("/the%-loai/", 1, false) then
            local name = Util.stripTags(anchor_html):gsub("^%s*", ""):gsub("%s*$", "")
            if name ~= "" and not seen[href] then
                seen[href] = true
                table.insert(genres, {
                    name = name,
                    url = Util.absoluteUrl(self.base_url, href),
                })
            end
        end
    end

    -- Parse pagination
    local max_page = page or 1
    for p_num in html:gmatch("[?&]page=(%d+)") do
        local n = tonumber(p_num)
        if n and n > max_page then
            max_page = n
        end
    end

    return {
        stories = stories,
        genres = genres,
        page = page or 1,
        total_pages = max_page,
    }
end

function Source:getCompleted(page)
    page = page or 1
    local url = self.base_url .. "/danh-sach?truyendich=1&hoanthanh=1&sapxep=capnhat"
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
    local url = genre.url:gsub("[?&]page=%d+", "")
    if page > 1 then
        if url:find("?") then
            url = url .. "&page=" .. page
        else
            url = url .. "?page=" .. page
        end
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

-- ========================
-- STORY DETAILS
-- ========================

function Source:parseStoryDetails(html)
    -- Description
    local description_html = html:match('<div[^>]-class="[^"]*summary%-content[^"]*"[^>]*>([%s%S]-)</div>')

    -- Author
    local author = html:match('Tác giả:[%s%S]-<a[^>]*>([%s%S]-)</a>')
    if author then author = Util.stripTags(author) end

    -- Status
    local status = html:match('Tình trạng:[%s%S]-<a[^>]*>([%s%S]-)</a>')
    if status then status = Util.stripTags(status) end

    -- Genres
    local genres = {}
    for anchor_html in (html:match('<div[^>]-class="[^"]*series%-gernes[^"]*"[^>]*>([%s%S]-)</div>') or ""):gmatch('<a[^>]-class="[^"]*series%-gerne%-item[^"]*"[^>]*>([%s%S]-)</a>') do
        local name = Util.stripTags(anchor_html):gsub("^%s*", ""):gsub("%s*$", "")
        if name ~= "" then
            table.insert(genres, name)
        end
    end

    return {
        description = Util.stripTags(description_html)
            ~= "" and Util.stripTags(description_html)
            or Util.getMetaContent(html, "name", "description"),
        author = author,
        status = status,
        genres = genres,
    }
end

function Source:getStoryDetails(story)
    local html, err = Http:get(story.url, requestHeaders())
    if not html then
        return nil, err
    end
    return self:parseStoryDetails(html)
end

-- ========================
-- CHAPTERS LIST
-- ========================

function Source:parseStoryPage(html, story, page)
    local chapters = {}

    -- Chapters are in <div class="chapter-name"><a href="...">TITLE</a></div>
    for block in html:gmatch('<div[^>]-class="[^"]*chapter%-name[^"]*"[^>]*>([%s%S]-)</div>') do
        local anchor = block:match("(<a[^>]*>)")
        if anchor then
            local href = Util.getAttribute(anchor, "href")
            local title = Util.stripTags(block)
            if href and href:find("/c%d+%-", 1, false) then
                table.insert(chapters, {
                    title = Util.trim(title),
                    url = Util.absoluteUrl(self.base_url, href),
                    source_id = self.id,
                    story_url = story.url,
                    kind = self.kind,
                })
            end
        end
    end

    -- DocLN shows all chapters on one page typically, no pagination for chapters
    story.details = self:parseStoryDetails(html)
    return {
        story = story,
        chapters = Util.uniqueBy(chapters, "url"),
        page = page or 1,
        total_pages = 1,
    }
end

function Source:getStoryPage(story, page)
    page = page or 1
    local html, err = Http:get(story.url, requestHeaders(story.url))
    if not html then
        return nil, err
    end
    return self:parseStoryPage(html, story, page)
end

-- ========================
-- XOR SHUFFLE DECRYPTION
-- ========================

local function base64_decode(data)
    local b = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/'
    data = data:gsub('[^' .. b .. '=]', '')
    return (data:gsub('.', function(x)
        if x == '=' then return '' end
        local r, f = '', (b:find(x) - 1)
        for i = 6, 1, -1 do
            r = r .. (f % 2 ^ i - f % 2 ^ (i - 1) > 0 and '1' or '0')
        end
        return r
    end):gsub('%d%d%d?%d?%d?%d?%d?%d?', function(x)
        if #x ~= 8 then return '' end
        local c = 0
        for i = 1, 8 do c = c + (x:sub(i, i) == '1' and 2 ^ (8 - i) or 0) end
        return string.char(c)
    end))
end

local function xorDecrypt(encrypted_bytes, key)
    local result = {}
    local key_len = #key
    for i = 1, #encrypted_bytes do
        local key_byte = string.byte(key, ((i - 1) % key_len) + 1)
        local enc_byte = string.byte(encrypted_bytes, i)
        -- XOR with bitwise operations
        local ok, bit = pcall(require, "bit")
        if ok then
            table.insert(result, string.char(bit.bxor(enc_byte, key_byte)))
        else
            -- Fallback XOR without bit library
            local xor_val = 0
            local p = 128
            while p > 0 do
                local a = enc_byte >= p
                local b = key_byte >= p
                if a then enc_byte = enc_byte - p end
                if b then key_byte = key_byte - p end
                if a ~= b then xor_val = xor_val + p end
                p = p / 2
            end
            table.insert(result, string.char(xor_val))
        end
    end
    return table.concat(result)
end

local function decryptChapterContent(data_k, data_c_json)
    -- data_c is a JSON array of base64 strings
    -- Each string starts with 4 chars = index (zero-padded), rest is base64 content
    -- Sort by index, concatenate, base64 decode, XOR with key

    -- Parse JSON array manually (simple case: array of strings)
    local chunks = {}
    for chunk in data_c_json:gmatch('"([^"]*)"') do
        -- Unescape HTML entities
        chunk = chunk:gsub("&quot;", '"'):gsub("&amp;", "&"):gsub("&lt;", "<"):gsub("&gt;", ">")
        table.insert(chunks, chunk)
    end

    if #chunks == 0 then
        Debug.write("[docln] No encrypted chunks found")
        return nil
    end

    -- Sort chunks by their 4-char index prefix
    table.sort(chunks, function(a, b)
        local idx_a = tonumber(a:sub(1, 4)) or 0
        local idx_b = tonumber(b:sub(1, 4)) or 0
        return idx_a < idx_b
    end)

    -- Decrypt each chunk separately (key index resets for each chunk)
    local decrypted_parts = {}
    for _, chunk in ipairs(chunks) do
        local encoded = chunk:sub(5)
        local encrypted = base64_decode(encoded)
        local decrypted = xorDecrypt(encrypted, data_k)
        table.insert(decrypted_parts, decrypted)
    end

    local final_decrypted = table.concat(decrypted_parts)
    Debug.write("[docln] Decrypted content length: " .. #final_decrypted)
    return final_decrypted
end

-- ========================
-- CHAPTER READING
-- ========================

function Source:parseChapter(html, chapter)
    -- Chapter title
    local volume_title = html:match('<h2[^>]-class="[^"]*title%-item[^"]*"[^>]*>([%s%S]-)</h2>')
    local chapter_title = html:match('<h4[^>]-class="[^"]*title%-item[^"]*"[^>]*>([%s%S]-)</h4>')
    local title = Util.stripTags(chapter_title) or chapter.title
    if volume_title then
        local vol = Util.stripTags(volume_title)
        if vol ~= "" then
            title = vol .. " - " .. title
        end
    end

    -- Try to find encrypted content first
    local data_s = html:match('id="chapter%-c%-protected"[^>]-data%-s="([^"]+)"')
    local data_k = html:match('id="chapter%-c%-protected"[^>]-data%-k="([^"]+)"')
    local data_c = html:match('id="chapter%-c%-protected"[^>]-data%-c="(%[.-%])"')

    local content

    if data_s and data_k and data_c then
        -- Unescape HTML entities in data_c
        data_c = data_c:gsub("&quot;", '"'):gsub("&amp;", "&"):gsub("&lt;", "<"):gsub("&gt;", ">")
        Debug.write("[docln] Found encrypted content: scheme=" .. data_s .. ", key=" .. data_k:sub(1, 8) .. "...")

        if data_s == "xor_shuffle" then
            content = decryptChapterContent(data_k, data_c)
        else
            Debug.write("[docln] Unknown encryption scheme: " .. data_s)
        end
    end

    -- Fallback: try plain chapter-content div
    if not content or content == "" then
        local start_at = html:find('id="chapter%-content"')
        if start_at then
            start_at = html:find(">", start_at, true)
            if start_at then
                local end_at = html:find('</div>%s*<section', start_at)
                    or html:find('</div>%s*<div[^>]-style="text%-align: center', start_at)
                    or html:find('</div>', start_at, true)
                if end_at then
                    content = html:sub(start_at + 1, end_at - 1)
                end
            end
        end
    end

    if not content or content == "" then
        return nil, "Không tìm thấy nội dung chương. Có thể cần đăng nhập và spam 5 comment trên web để mở khóa tài khoản."
    end

    -- Clean up content
    content = Util.sanitizeContentHtml(content)
    -- Remove hidden title paragraph
    content = content:gsub('<p style="display: none">[^<]*</p>', "")
    -- Remove banner images
    content = content:gsub('<a href="/truyen/%d+"[^>]*>.-</a>', "")

    -- Navigation: previous/next chapter
    local previous_url, next_url

    -- Navigation bar: <section class="rd-basic_icon">
    -- fa-backward = previous, fa-forward = next
    local nav_section = html:match('<section[^>]-class="[^"]*rd%-basic_icon[^"]*"[^>]*>([%s%S]-)</section>')
    if nav_section then
        for anchor_attrs in nav_section:gmatch("<a([^>]*)>") do
            local href = Util.getAttribute(anchor_attrs, "href")
            local inner = html:sub(html:find(anchor_attrs, 1, true) or 1)
            if href and href:find("/c%d+%-", 1, false) then
                if inner:find("fa%-backward", 1, true) then
                    previous_url = Util.absoluteUrl(self.base_url, href)
                elseif inner:find("fa%-forward", 1, true) then
                    next_url = Util.absoluteUrl(self.base_url, href)
                end
            end
        end
    end

    -- Fallback: parse all nav anchors with fa-backward/fa-forward
    if not previous_url and not next_url then
        for anchor_attrs, anchor_inner in html:gmatch('<a([^>]*)>([%s%S]-)</a>') do
            local href = Util.getAttribute(anchor_attrs, "href")
            if href and href:find("/c%d+%-", 1, false) then
                if anchor_inner:find("fa%-backward", 1, true) then
                    previous_url = Util.absoluteUrl(self.base_url, href)
                elseif anchor_inner:find("fa%-forward", 1, true) then
                    next_url = Util.absoluteUrl(self.base_url, href)
                end
            end
        end
    end

    return {
        title = title,
        content = content,
        previous_url = previous_url,
        next_url = next_url,
        url = chapter.url,
        kind = self.kind,
    }
end

function Source:getChapter(chapter)
    local html, err = Http:get(chapter.url, requestHeaders(chapter.story_url or chapter.url))
    if not html then
        return nil, err
    end
    return self:parseChapter(html, chapter)
end

local socket = require("socket")
local last_request_time = 0

local function applyRateLimit()
    local ok, copas = pcall(require, "copas")
    if ok and copas and copas.sleep then
        local now = socket.gettime()
        -- DocLN giới hạn rất nghiêm ngặt nếu tải số lượng lớn, cần delay tối thiểu 1.2s
        local next_allowed = last_request_time + 1.2 
        if now < next_allowed then
            last_request_time = next_allowed
            copas.sleep(next_allowed - now)
        else
            last_request_time = now
        end
    end
end

function Source:getChapterAsync(chapter)
    -- Xếp hàng giãn cách các request tải chương để tối ưu tốc độ, tránh 429
    applyRateLimit()

    local html, err = Http:requestAsync("GET", chapter.url, nil, requestHeaders(chapter.story_url or chapter.url))
    if not html then
        return nil, err
    end
    return self:parseChapter(html, chapter)
end

return Source
