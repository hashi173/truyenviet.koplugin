package.path = package.path .. ';./truyenviet.koplugin/?.lua;./truyenviet.koplugin/?/init.lua'
local Http = require('truyenviet/http_client')
local b, e = Http:get('https://api.mangadex.org/manga?limit=5')
print("BODY:", b and #b or "nil")
print("ERROR:", e)
