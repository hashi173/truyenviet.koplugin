local Http = require("truyenviet/http_client")
local Util = require("truyenviet/helpers")
local ko_util = require("util")

local Source = {
    id = "dualeotruyenfull",
    name = "DualeoTruyenFull",
    kind = "text",
    base_url = "https://dualeotruyenfull.net",
}

local DUALEO_GENRES = {
    { name = "dammy", url = "bo-loc-nang-cao/?genre%5B0%5D=dammy&sort=updated" },
    { name = "caoh", url = "bo-loc-nang-cao/?genre%5B0%5D=caoh&sort=updated" },
    { name = "Đam Mỹ", url = "bo-loc-nang-cao/?genre%5B0%5D=dam-my&sort=updated" },
    { name = "hiendai", url = "bo-loc-nang-cao/?genre%5B0%5D=hiendai&sort=updated" },
    { name = "songtính", url = "bo-loc-nang-cao/?genre%5B0%5D=songtinh&sort=updated" },
    { name = "Sủng", url = "bo-loc-nang-cao/?genre%5B0%5D=sung&sort=updated" },
    { name = "danmei", url = "bo-loc-nang-cao/?genre%5B0%5D=danmei&sort=updated" },
    { name = "hvan", url = "bo-loc-nang-cao/?genre%5B0%5D=hvan&sort=updated" },
    { name = "Đô Thị", url = "bo-loc-nang-cao/?genre%5B0%5D=do-thi&sort=updated" },
    { name = "1x1", url = "bo-loc-nang-cao/?genre%5B0%5D=1x1&sort=updated" },
}

function Source:getGenres()
    return DUALEO_GENRES
end

local function stdHeaders(base_url)
    return {
        ["Referer"] = base_url .. "/",
    }
end

local function parseStories(html, source_id)
    local stories = {}
    local seen = {}
    -- In DualeoTruyenFull, story cards are under <div class="story-cover-wrap ...">
    -- or <div class="uk-width-1-3@m uk-width-1-2"> etc.
    for block in html:gmatch('<a class="uk%-link%-toggle" href="https?://dualeotruyenfull%.net/doc%-truyen/[^"]+".-</a>') do
        local url = block:match('href="(https?://dualeotruyenfull%.net/doc%-truyen/[^"]+)"')
        local cover = block:match('<img[^>]*src="([^"]+)"')
        local title = block:match('<strong[^>]*>([^<]+)</strong>') or block:match('<h3[^>]*>([^<]+)</h3>')
        
        if url and title and not seen[url] then
            seen[url] = true
            table.insert(stories, {
                source_id = source_id,
                title = Util.decodeHtml(Util.trim(title)),
                url = url,
                cover_url = cover,
                kind = "text",
            })
        end
    end
    if #stories == 0 then
        for block in html:gmatch('<div class="thumb">(.-)</div>') do
            local href = block:match('href="([^"]+)"')
            local cover = block:match('src="([^"]+)"')
            local title = block:match('title="([^"]+)"') or block:match('alt="([^"]+)"')
            if href and title then
                table.insert(stories, {
                    title = Util.trim(title),
                    url = Util.absoluteUrl("https://dualeotruyenfull.net", href),
                    cover_url = cover,
                    source_id = source_id,
                })
            end
        end
    end
    if #stories == 0 then
        for block in html:gmatch('<div class="manga%-item%-details(.-)</h2>') do
            local href = block:match('href="([^"]+)"')
            local cover = block:match('src="([^"]+)"')
            local title = block:match('<a class="uk%-link%-heading"[^>]*>([^<]+)')
            if href and title then
                table.insert(stories, {
                    title = Util.trim(title),
                    url = Util.absoluteUrl("https://dualeotruyenfull.net", href),
                    cover_url = cover,
                    source_id = source_id,
                })
            end
        end
    end
    return stories
end

function Source:search(query)
    local encoded = ko_util.urlEncode(query)
    local url = self.base_url .. "/?s=" .. encoded
    local html, err = Http:get(url, stdHeaders(self.base_url))
    if not html then return nil, err end
    return parseStories(html, self.id)
end

function Source:getCompleted(page)
    page = page or 1
    local url = self.base_url .. "/truyen-da-hoan-thanh/"
    if page > 1 then url = url .. "page/" .. page .. "/" end
    local html, err = Http:get(url, stdHeaders(self.base_url))
    
    local stories = html and parseStories(html, self.id) or {}
    local total_pages = html and (tonumber(html:match('page/(%d+)/"[^>]*>Cuối')) or page) or page

    if #stories == 0 then
        url = self.base_url
        if page > 1 then url = url .. "/page/" .. page .. "/" end
        html, err = Http:get(url, stdHeaders(self.base_url))
        if not html then return nil, err end
        stories = parseStories(html, self.id)
        total_pages = tonumber(html:match('page/(%d+)/"[^>]*>Cuối')) or page
    end

    return {
        stories = stories,
        genres = DUALEO_GENRES,
        page = page,
        total_pages = total_pages,
        title = "Truyện mới cập nhật"
    }
end

function Source:getGenre(genre, page)
    page = page or 1
    local url = self.base_url .. "/" .. genre.url
    if page > 1 then 
        if url:find("%?") then
            url = url:gsub("(%?)", "page/" .. page .. "/%1")
        else
            url = Util.withTrailingSlash(url) .. "page/" .. page .. "/"
        end
    end
    local html, err = Http:get(url, stdHeaders(self.base_url))
    if not html then return nil, err end
    
    local total_pages = tonumber(html:match('page/(%d+)/"[^>]*>Cuối')) 
        or tonumber(html:match('page=(%d+)"[^>]*>Cuối'))
        or page
    return {
        stories = parseStories(html, self.id),
        genres = DUALEO_GENRES,
        page = page,
        total_pages = total_pages,
        title = genre.name
    }
end

function Source:getStoryDetails(story)
    local html, err = Http:get(story.url, stdHeaders(self.base_url))
    if not html then return nil, err end
    
    local title = html:match('<h1[^>]*>([^<]+)</h1>')
        or html:match('<title>([^<]+)</title>')
    
    local author = html:match('Tác giả:[^<]*<a[^>]*>([^<]+)</a>')
        or html:match('Tác giả:.-([^<]+)</li>')
    
    local desc_block = html:match('<div class="story%-detail%-info[^"]*"[^>]*>(.-)</div>%s*<div')
        or html:match('<div class="uk%-panel uk%-margin%-top uk%-text%-justify[^"]*"[^>]*>(.-)</div>')
    
    local description = desc_block and Util.stripTags(desc_block) or nil
    if description then
        description = description:gsub("^%s+", ""):gsub("%s+$", "")
    end
    
    return {
        title = title and Util.decodeHtml(Util.trim(title)) or story.title,
        author = author and Util.trim(author) or nil,
        description = description,
    }
end

function Source:getStoryPage(story, ko_page)
    ko_page = ko_page or 1
    
    -- Step 1: Find total_pages if unknown
    if not story.total_pages then
        local url = Util.withTrailingSlash(story.url)
        local html, err = Http:get(url, stdHeaders(self.base_url))
        if not html then return nil, err end
        
        local tp = tonumber(html:match('page/(%d+)/"[^>]*>Cuối')) or 1
        if tp == 1 then
            for p in html:gmatch('chuong/page/(%d+)') do
                local pn = tonumber(p)
                if pn and pn > tp then tp = pn end
            end
        end
        story.total_pages = tp
    end
    
    -- Step 2: Map KOReader page to Website page (Website has newest chapters on page 1)
    local website_page = story.total_pages - ko_page + 1
    if website_page < 1 then website_page = 1 end
    
    local url = Util.withTrailingSlash(story.url)
    if website_page > 1 then url = url .. "chuong/page/" .. website_page .. "/" end
    
    local html, err = Http:get(url, stdHeaders(self.base_url))
    if not html then return nil, err end
    
    local chapters = {}
    local seen = {}
    local all_matches = {}
    for href, inner_html in html:gmatch('<a[^>]+href="(https?://dualeotruyenfull%.net/[^"]+chuong[^"]+)"[^>]*>(.-)</a>') do
        if not href:find("/page/") then
            local title = inner_html:match('<h3[^>]*>(.-)</h3>') or inner_html
            table.insert(all_matches, {href = href, title = Util.trim(Util.stripTags(title))})
        end
    end

    -- Reverse the matches because the website sorts chapters descending within a page
    for i = #all_matches, 1, -1 do
        local href = all_matches[i].href
        if not seen[href] then
            seen[href] = true
            table.insert(chapters, {
                title = Util.decodeHtml(all_matches[i].title),
                url = href,
                source_id = self.id,
                story_url = story.url,
                kind = self.kind,
            })
        end
    end
    
    story.details = self:getStoryDetails(story)
    
    return {
        story = story,
        chapters = chapters,
        page = ko_page,
        total_pages = story.total_pages,
    }
end

function Source:getChapter(chapter)
    local html, err = Http:get(chapter.url, stdHeaders(self.base_url))
    if not html then return nil, err end
    
    local content = html:match('<div id="chapter%-content"[^>]*>(.-)</div>%s*<div class="uk%-margin%-top"')
        or html:match('<div id="chapter%-content"[^>]*>(.-)</div>%s*<div')
    if not content then return nil, "Không tìm thấy nội dung chương" end
    
    -- Xoá quảng cáo
    content = content:gsub('<div id="ads%-chapter%-top"></div>', '')
    
    return Util.sanitizeContentHtml(content)
end

function Source:getChapterAsync(chapter)
    local html, err = Http:requestAsync("GET", chapter.url, nil, stdHeaders(self.base_url))
    if not html then return nil, err end
    
    local content = html:match('<div id="chapter%-content"[^>]*>(.-)</div>%s*<div class="uk%-margin%-top"')
        or html:match('<div id="chapter%-content"[^>]*>(.-)</div>%s*<div')
    if not content then return nil, "Không tìm thấy nội dung chương" end
    
    content = content:gsub('<div id="ads%-chapter%-top"></div>', '')
    
    return Util.sanitizeContentHtml(content)
end

return Source
