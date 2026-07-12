local Util = require("helpers")

local html = [[
<a href="https://metruyenvn.org/the-loai/1v1/">1v1</a>
<a  href="https://metruyenvn.org/the-loai/18/">18 +</a>
]]

local genres = {}
for href, name in html:gmatch('<a[^>]+href="(https?://metruyenvn%.org/the%-loai/[^"]+)"[^>]*>([^<]+)</a>') do
    table.insert(genres, { name = Util.trim(name), url = href })
end

for _, g in ipairs(genres) do
    print(g.name, g.url)
    local url = Util.withTrailingSlash(g.url)
    print("withTrailingSlash:", url)
end
