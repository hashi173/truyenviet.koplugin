local Util = {
    getAttribute = function(html, attr)
        local pattern = attr .. '=["\']([^"\']+)["\']'
        return html:match(pattern)
    end,
    absoluteUrl = function(base, url)
        if not url then return nil end
        if url:find("^//") then return "https:" .. url end
        if url:find("^/") then return base:gsub("/$", "") .. url end
        return url
    end
}

local function parseChapter(html)
    local images = {}
    
    local content_html = html:match('<div[^>]-class="[^"]*story%-see%-content[^"]*"[^>]*>([%s%S]-)</div>')
    if not content_html then
        content_html = html
    end

    for image_tag in content_html:gmatch("(<img[^>]*>)") do
        local primary = Util.getAttribute(image_tag, "data-original")
            or Util.getAttribute(image_tag, "src")
        local class_name = Util.getAttribute(image_tag, "class") or ""
        
        if primary and (class_name:find("lazy") or primary:find("/chap/")) then
            local clean_urls = {}
            local seen = {}
            local candidates = {
                primary,
                Util.getAttribute(image_tag, "data-cdn"),
                Util.getAttribute(image_tag, "data-fb"),
            }
            for index = 1, 3 do
                local url = Util.absoluteUrl("https://cbunu.com", candidates[index])
                if url and not seen[url] then
                    seen[url] = true
                    table.insert(clean_urls, url)
                end
            end
            if #clean_urls > 0 then
                table.insert(images, { urls = clean_urls })
            end
        end
    end

    return images
end

local html = io.open('test_cbunu.html'):read('*a')
local images = parseChapter(html)
for i, img in ipairs(images) do
    print(i, img.urls[1])
end
