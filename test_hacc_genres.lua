package.path = "truyenviet.koplugin/?.lua;" .. package.path
local hacc = dofile("truyenviet.koplugin/truyenviet/sources/haccbl.lua")
local result = hacc:getListing()
if result and result.genres then
    print("Found " .. #result.genres .. " genres")
    for i, g in ipairs(result.genres) do
        print(i, g.name, g.url)
    end
else
    print("No genres found or error!")
end
