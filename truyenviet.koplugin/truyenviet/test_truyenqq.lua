package.path = package.path .. ";./?.lua;./libs/?.lua"
local Source = require("sources/truyenqq")
local f = io.open("truyenqq_home.html", "r")
local html = f:read("*a")
f:close()

local res = Source:parseListing(html, 1)
print("Stories found: " .. (res and res.stories and #res.stories or 0))
if res and res.stories and #res.stories > 0 then
    print(res.stories[1].title)
    print(res.stories[1].url)
    print(res.stories[1].cover_url)
end
