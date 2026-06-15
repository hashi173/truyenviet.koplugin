package.path = package.path .. ";./?.lua"

local truyendich = require("truyenviet.koplugin.truyenviet.sources.truyendich")

print("Searching...")
local search_results, err = truyendich:search("phàm nhân")
if not search_results then
    print("Search error:", err)
    return
end

print("Found " .. #search_results .. " stories.")
if #search_results == 0 then return end

local story = search_results[1]
print("Fetching story: " .. story.url)

local page_data, err = truyendich:getStoryPage(story, 1)
if not page_data then
    print("Get story page error:", err)
    return
end

print("Found " .. #page_data.chapters .. " chapters.")
for i=1, math.min(5, #page_data.chapters) do
    print(" - " .. page_data.chapters[i].title .. " | " .. page_data.chapters[i].url)
end
