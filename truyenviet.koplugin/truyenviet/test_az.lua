local Http = require("http_client")
local Util = require("helpers")

local function test()
    local html, err = Http:get("https://aztruyen.top/tim-kiem/nguoi")
    if not html then 
        print("ERR: ", err)
        return
    end
    print("HTML length: ", #html)
    -- Try to find stories
    for href, title in html:gmatch('<h3 class="story%-title"[^>]*>.-<a href="(https?://aztruyen%.top/truyen/[^"]+)"[^>]*>([^<]+)</a>') do
        print("FOUND:", href, Util.trim(title))
    end
    -- Or other pattern:
    for block in html:gmatch('<div class="story%-item".-</div>%s*</div>%s*</div>') do
        local href = block:match('href="(https?://aztruyen%.top/truyen/[^"]+)"')
        local title = block:match('title="([^"]+)"')
        local cover = block:match('<img[^>]+src="([^"]+)"')
        if href then
            print("BLOCK FOUND:", href, title, cover)
        end
    end
end

test()
