local socket_url = require("socket.url")
local ko_util = require("util")

local Util = {}

local VIETNAMESE_ASCII = {
    ["à"] = "a", ["á"] = "a", ["ạ"] = "a", ["ả"] = "a", ["ã"] = "a",
    ["â"] = "a", ["ầ"] = "a", ["ấ"] = "a", ["ậ"] = "a", ["ẩ"] = "a", ["ẫ"] = "a",
    ["ă"] = "a", ["ằ"] = "a", ["ắ"] = "a", ["ặ"] = "a", ["ẳ"] = "a", ["ẵ"] = "a",
    ["è"] = "e", ["é"] = "e", ["ẹ"] = "e", ["ẻ"] = "e", ["ẽ"] = "e",
    ["ê"] = "e", ["ề"] = "e", ["ế"] = "e", ["ệ"] = "e", ["ể"] = "e", ["ễ"] = "e",
    ["ì"] = "i", ["í"] = "i", ["ị"] = "i", ["ỉ"] = "i", ["ĩ"] = "i",
    ["ò"] = "o", ["ó"] = "o", ["ọ"] = "o", ["ỏ"] = "o", ["õ"] = "o",
    ["ô"] = "o", ["ồ"] = "o", ["ố"] = "o", ["ộ"] = "o", ["ổ"] = "o", ["ỗ"] = "o",
    ["ơ"] = "o", ["ờ"] = "o", ["ớ"] = "o", ["ợ"] = "o", ["ở"] = "o", ["ỡ"] = "o",
    ["ù"] = "u", ["ú"] = "u", ["ụ"] = "u", ["ủ"] = "u", ["ũ"] = "u",
    ["ư"] = "u", ["ừ"] = "u", ["ứ"] = "u", ["ự"] = "u", ["ử"] = "u", ["ữ"] = "u",
    ["ỳ"] = "y", ["ý"] = "y", ["ỵ"] = "y", ["ỷ"] = "y", ["ỹ"] = "y",
    ["đ"] = "d",
}

function Util.trim(value)
    if value == nil then
        return ""
    end
    return tostring(value):match("^%s*(.-)%s*$")
end

function Util.decodeHtml(value)
    if value == nil then
        return ""
    end
    return ko_util.htmlEntitiesToUtf8(value)
end

function Util.stripTags(value)
    if value == nil then
        return ""
    end

    value = value:gsub("<script[^>]*>[%s%S]-</script>", "")
    value = value:gsub("<style[^>]*>[%s%S]-</style>", "")
    value = value:gsub("<br%s*/?>", "\n")
    value = value:gsub("<BR%s*/?>", "\n")
    value = value:gsub("</p%s*>", "\n")
    value = value:gsub("</div%s*>", "\n")
    value = value:gsub("<[^>]+>", "")
    value = Util.decodeHtml(value)
    value = value:gsub("\r", "")
    value = value:gsub("[ \t]+\n", "\n")
    value = value:gsub("\n[ \t]+", "\n")
    value = value:gsub("\n\n\n+", "\n\n")
    return Util.trim(value)
end

function Util.getAttribute(tag, name)
    if tag == nil then
        return nil
    end

    local escaped_name = name:gsub("([^%w])", "%%%1")
    return tag:match(escaped_name .. '%s*=%s*"([^"]*)"')
        or tag:match(escaped_name .. "%s*=%s*'([^']*)'")
end

function Util.absoluteUrl(base_url, href)
    if not href or href == "" then
        return nil
    end
    href = Util.decodeHtml(href)
    if href:match("^https?://") then
        return href
    end
    if href:sub(1, 2) == "//" then
        return "https:" .. href
    end
    return socket_url.absolute(base_url, href)
end

function Util.withTrailingSlash(value)
    value = value:gsub("#.*$", ""):gsub("%?.*$", "")
    return value:sub(-1) == "/" and value or value .. "/"
end

function Util.safeName(value, fallback)
    value = Util.stripTags(value)
    value = ko_util.replaceAllInvalidChars(value)
    value = value:gsub("[%c]+", " ")
    value = value:gsub("%s+", " ")
    value = Util.trim(value)
    if value == "" then
        value = fallback or "item"
    end
    if #value > 100 then
        value = value:sub(1, 100)
    end
    return value
end

function Util.urlLeaf(value, fallback)
    if not value then
        return fallback or "item"
    end
    local clean = value:gsub("#.*$", ""):gsub("%?.*$", ""):gsub("/+$", "")
    return Util.safeName(clean:match("([^/]+)$"), fallback)
end

function Util.escapeHtml(value)
    value = tostring(value or "")
    value = value:gsub("&", "&amp;")
    value = value:gsub("<", "&lt;")
    value = value:gsub(">", "&gt;")
    value = value:gsub('"', "&quot;")
    return value
end

function Util.sanitizeContentHtml(value)
    value = value or ""
    value = value:gsub("<script[^>]*>[%s%S]-</script>", "")
    value = value:gsub("<iframe[^>]*>[%s%S]-</iframe>", "")
    value = value:gsub("<ins[^>]*>[%s%S]-</ins>", "")
    value = value:gsub("<div[^>]-id=[\"']ads[^>]*>[%s%S]-</div>", "")
    value = value:gsub("%s+on[%w%-]+%s*=%s*\"[^\"]*\"", "")
    value = value:gsub("%s+on[%w%-]+%s*=%s*'[^']*'", "")
    return value
end

function Util.normalizeSearch(value)
    value = ko_util.stringLower(Util.decodeHtml(Util.stripTags(value or "")))
    for accented, plain in pairs(VIETNAMESE_ASCII) do
        value = value:gsub(accented, plain)
    end
    value = value:gsub("[^%w]+", " ")
    value = value:gsub("%s+", " ")
    return Util.trim(value)
end

function Util.searchScore(query, title, source_position)
    local normalized_query = Util.normalizeSearch(query)
    local normalized_title = Util.normalizeSearch(title)
    if normalized_query == "" or normalized_title == "" then
        return 0
    end

    local score = math.max(0, 300 - (source_position or 1))
    if normalized_title == normalized_query then
        score = score + 10000
    elseif normalized_title:sub(1, #normalized_query) == normalized_query then
        score = score + 8000
    else
        local position = normalized_title:find(normalized_query, 1, true)
        if position then
            score = score + 6000 - math.min(position, 500)
        end
    end

    local matched_tokens = 0
    local token_count = 0
    for token in normalized_query:gmatch("%S+") do
        token_count = token_count + 1
        local position = normalized_title:find(token, 1, true)
        if position then
            matched_tokens = matched_tokens + 1
            score = score + 500 - math.min(position, 200)
            if normalized_title:find(" " .. token, 1, true) then
                score = score + 100
            end
        end
    end
    if token_count > 0 then
        score = score + math.floor(2500 * matched_tokens / token_count)
    end

    score = score - math.min(#normalized_title, 300)
    return score
end

function Util.stableHash(value)
    local hash = 5381
    value = tostring(value or "")
    for index = 1, #value do
        hash = (hash * 33 + value:byte(index)) % 4294967296
    end
    return string.format("%08x", hash)
end

function Util.uniqueBy(items, key)
    local seen = {}
    local result = {}
    for _, item in ipairs(items) do
        local value = item[key]
        if value and not seen[value] then
            seen[value] = true
            table.insert(result, item)
        end
    end
    return result
end

function Util.parseGenres(html, base_url)
    local genres = {}
    for anchor_attrs, anchor_html in tostring(html or ""):gmatch(
        "<a([^>]*)>([%s%S]-)</a>"
    ) do
        local href = Util.getAttribute(anchor_attrs, "href")
        if href and href:find("/the-loai/", 1, true) then
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

function Util.parseGenreNames(html)
    local names = {}
    local seen = {}
    for anchor_attrs, anchor_html in tostring(html or ""):gmatch(
        "<a([^>]*)>([%s%S]-)</a>"
    ) do
        local href = Util.getAttribute(anchor_attrs, "href")
        local name = Util.stripTags(anchor_html)
        if href and href:find("/the-loai/", 1, true)
                and name ~= ""
                and not seen[name] then
            seen[name] = true
            table.insert(names, name)
        end
    end
    return names
end

function Util.getMetaContent(html, attribute, value)
    for tag in tostring(html or ""):gmatch("(<meta%s+[^>]*>)") do
        if Util.getAttribute(tag, attribute) == value then
            return Util.decodeHtml(Util.getAttribute(tag, "content"))
        end
    end
end

function Util.maxPage(html, minimum)
    local max_page = minimum or 1
    local raw = tostring(html or "")
    local function consider(num_str)
        local n = tonumber(num_str)
        if n and n >= 1 and n <= 100000 and n > max_page then
            max_page = n
        end
    end
    for prefix, page in raw:gmatch("(.?)trang%-(%d+)") do
        if prefix ~= "-" then
            consider(page)
        end
    end
    for page in raw:gmatch("page=(%d+)") do
        consider(page)
    end
    for page in raw:gmatch("/page/(%d+)") do
        consider(page)
    end
    return max_page
end

function Util.decodeBase64(data)
    if type(data) ~= "string" or data == "" then
        return ""
    end
    local alphabet = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
    data = data:gsub("[^" .. alphabet .. "=]", "")
    return (data:gsub(".", function(x)
        if x == "=" then return "" end
        local r, f = "", (alphabet:find(x, 1, true) - 1)
        for i = 6, 1, -1 do
            r = r .. (f % 2^i - f % 2^(i - 1) > 0 and "1" or "0")
        end
        return r
    end):gsub("%d%d%d?%d?%d?%d?%d?%d?", function(x)
        if #x ~= 8 then return "" end
        local c = 0
        for i = 1, 8 do
            c = c + (x:sub(i, i) == "1" and 2^(8 - i) or 0)
        end
        return string.char(c)
    end))
end

function Util.decodeJson(value)
    if type(value) ~= "string" or value == "" then
        return nil
    end
    local ok_json, json = pcall(require, "json")
    -- KOReader's json.decode can be a callable table (__call), not a raw function.
    if ok_json and type(json) == "table" and json.decode ~= nil then
        local ok, decoded = pcall(json.decode, value)
        if ok then
            return decoded
        end
    end
    if ko_util.jsonDecode ~= nil then
        local ok, decoded = pcall(ko_util.jsonDecode, value)
        if ok then
            return decoded
        end
    end
    return nil
end

-- Parse WordPress InitPluginSuite Live Search (/wp-json/initlise/v1/search)
function Util.parseInitliseSearchJson(raw_json, source, transform_cover)
    local decoded = Util.decodeJson(raw_json)
    if type(decoded) ~= "table" then
        return {}
    end
    local stories = {}
    for _, item in ipairs(decoded) do
        if type(item) == "table" then
            local title = Util.trim(Util.stripTags(item.title):gsub("%s+", " "))
            local url = Util.absoluteUrl(source.base_url, item.url)
            if url and title ~= "" then
                local cover_url = Util.absoluteUrl(source.base_url, item.thumb)
                if cover_url and type(transform_cover) == "function" then
                    cover_url = transform_cover(cover_url)
                end
                table.insert(stories, {
                    source_id = source.id,
                    title = title,
                    url = url,
                    cover_url = cover_url,
                    kind = source.kind,
                })
            end
        end
    end
    return Util.uniqueBy(stories, "url")
end

return Util
