package.path = package.path .. ';./truyenviet.koplugin/?.lua;./truyenviet.koplugin/?/init.lua'
local Http = require("truyenviet/http_client")
local bit = require("bit")
local url = "https://haccbl.xyz/manga/nhan-vien-moi-zec/chapter-1/"

local function simpleHash(str)
    local hash = 0
    for i = 1, #str do
        local charCode = string.byte(str, i)
        hash = bit.tobit(bit.lshift(hash, 5) - hash + charCode)
    end
    return tostring(hash)
end

local path = url:match("https?://[^/]+(/.*)")
local pathClean = path:gsub("^/+", ""):gsub("/+$", "")
local pathId = simpleHash(pathClean)
local cookieName = "unlock_chap_" .. pathId
print("Cookie: " .. cookieName .. "=ok")

local headers = {
    ["Referer"] = "https://haccbl.xyz/",
    ["User-Agent"] = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36",
    ["Cookie"] = cookieName .. "=ok"
}

local html, err = Http:get(url, headers)
if not html then
    print("Error:", err)
else
    if html:find("InitMangaEncryptedChapter") then
        print("FAILED: Chapter is STILL encrypted")
    else
        print("SUCCESS: Chapter is UNENCRYPTED!")
        local imgs = {}
        for img in html:gmatch('<img[^>]-src="([^"]+)"') do
            if img:find("000") then
                table.insert(imgs, img)
            end
        end
        print("Found " .. #imgs .. " images")
        for i, img in ipairs(imgs) do print(i, img) end
    end
end
