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
    for page in tostring(html or ""):gmatch("trang%-(%d+)") do
        max_page = math.max(max_page, tonumber(page) or 1)
    end
    for page in tostring(html or ""):gmatch("page=(%d+)") do
        max_page = math.max(max_page, tonumber(page) or 1)
    end
    return max_page
end

return Util
