package.path = "truyenviet.koplugin/?.lua;" .. package.path
local util = require("truyenviet.helpers")
local http = require("truyenviet.http_client")
local cbunu = dofile("truyenviet.koplugin/truyenviet/sources/cbunu.lua")

local result = cbunu:getCompleted()
if result and result.stories then
    for i, s in ipairs(result.stories) do
        print(s.title)
        print("URL: " .. tostring(s.url))
        print("COVER: " .. tostring(s.cover_url))
        print("---")
    end
else
    print("No stories or error!")
end
