local util = {
    getAttribute = function(html, attr)
        if not html then return nil end
        local pattern = attr .. '=["\']([^"\']+)["\']'
        return html:match(pattern)
    end,
    absoluteUrl = function(base, url)
        if not url then return nil end
        if url:find("^//") then return "https:" .. url end
        if url:find("^/") then return base:gsub("/$", "") .. url end
        return url
    end,
    stripTags = function(s) return s and s:gsub("<[^>]+>", "") or "" end,
    uniqueBy = function(t, key)
        local seen = {}
        local res = {}
        for _, v in ipairs(t) do
            if not seen[v[key]] then
                seen[v[key]] = true
                table.insert(res, v)
            end
        end
        return res
    end
}

local Source = { id = "cbunu", base_url = "https://cbunu.com", kind = "comic" }

local function isStoryUrl(href)
    return href
        and href:find("/truyen-tranh/", 1, true)
        and not href:find("%-chap%-")
        and not href:find("%.html")
end

local function parseStoryCards(html)
    local stories = {}
    for anchor_attrs, anchor_html in tostring(html or ""):gmatch(
        "<a([^>]*)>([%s%S]-)</a>"
    ) do
        local href = util.getAttribute(anchor_attrs, "href")
        if isStoryUrl(href) then
            local image_tag = anchor_html:match("(<img[^>]*>)")
            local title = util.getAttribute(anchor_attrs, "title")
                or util.getAttribute(image_tag, "alt")
                or util.stripTags(anchor_html)
            title = util.stripTags(title):gsub("%.%.%.$", "")
            
            table.insert(stories, {
                source_id = Source.id,
                title = title,
                url = util.absoluteUrl(Source.base_url, href),
                cover_url = util.absoluteUrl(
                    Source.base_url,
                    util.getAttribute(image_tag, "data-original")
                        or util.getAttribute(image_tag, "data-src")
                        or util.getAttribute(image_tag, "src")
                        or util.getAttribute(image_tag, "data-fb")
                ),
                kind = Source.kind,
            })
        end
    end
    return util.uniqueBy(stories, "url")
end

local html = io.open("cbunu_search.html", "r"):read("*a")
local stories = parseStoryCards(html)
for i, s in ipairs(stories) do
    print(i .. ": " .. s.title)
    print("  URL: " .. tostring(s.url))
    print("  COVER: " .. tostring(s.cover_url))
end
