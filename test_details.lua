local Util = {
    stripTags = function(s) return s and s:gsub("<[^>]+>", ""):gsub("&nbsp;", " ") or "" end,
    getMetaContent = function(html, name, content) return "" end
}

local function parseStoryDetails(html)
    local description_html = html:match(
        '<div[^>]-class="[^"]*story%-content[^"]*"[^>]*>([%s%S]-)</div>'
    ) or html:match('<div[^>]-class="[^"]*entry%-content[^"]*"[^>]*>([%s%S]-)</div>')
    
    local author = html:match('Tác giả:[%s%S]-<a[^>]*>([%s%S]-)</a>')
        or html:match('<a[^>]-href="[^"]*/author/[^"]*"[^>]*>.-<span[^>]*>([%s%S]-)</span>')
    if author then author = Util.stripTags(author) end
    
    local status = html:match('Tình trạng:[%s%S]-<span[^>]*>([%s%S]-)</span>')
    if status then status = Util.stripTags(status) end

    local genre_html = html:match('<div[^>]-id="genre%-tags"[^>]*>([%s%S]-)</div>')
        or html:match('<div[^>]-class="[^"]*genres[^"]*"[^>]*>([%s%S]-)</div>')
    local genres = {}
    if genre_html then
        for anchor_html in genre_html:gmatch("<a[^>]*>([%s%S]-)</a>") do
            local clean_genre = Util.stripTags(anchor_html):gsub("^%s*", ""):gsub("%s*$", "")
            table.insert(genres, clean_genre)
        end
    end
    
    local cover_url = html:match('<meta property="og:image" content="([^"]+)"')

    return {
        description = Util.stripTags(description_html)
            ~= "" and Util.stripTags(description_html)
            or Util.getMetaContent(html, "name", "description"),
        author = author,
        status = status,
        genres = genres,
        cover_url = cover_url,
    }
end

local html = io.open('test_hacc_story.html'):read('*a')
local details = parseStoryDetails(html)
for k, v in pairs(details) do
    if type(v) == "table" then
        print(k, ":")
        for i, g in ipairs(v) do print("  -", g) end
    else
        print(k, ":", v)
    end
end
