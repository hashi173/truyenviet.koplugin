package.path = "truyenviet.koplugin/?.lua;" .. package.path
local hacc = dofile("truyenviet.koplugin/truyenviet/sources/haccbl.lua")
local html = io.open("test_hacc_story.html", "r"):read("*a")
local chapter_list = hacc:parseStoryPage(html)
if chapter_list and chapter_list.chapters then
    print("Found " .. #chapter_list.chapters .. " chapters")
    for i, ch in ipairs(chapter_list.chapters) do
        print(i, ch.title, ch.url)
    end
else
    print("No chapters found or error!")
end
