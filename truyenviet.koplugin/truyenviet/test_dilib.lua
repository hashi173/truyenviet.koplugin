local Http = require("http_client")
local source = dofile("sources/dilib.lua")
local cat = {url = "https://dilib.vn/thu-vien/tam-ly-ky-nang/"}
local res, err = source:getCategoryBooks(cat, 1)
if err then
    print("Error:", err)
else
    print("Found books:", res and res.books and #res.books or 0)
    for i, b in ipairs(res.books or {}) do
        print(i, b.title, b.url, b.cover_url)
    end
end
