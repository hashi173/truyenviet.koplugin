local http = require("socket.http")
local ltn12 = require("ltn12")

local function request(url, body)
    local sink = {}
    local r, c, h, s = http.request({
        url = url,
        method = "POST",
        headers = {
            ["Content-Length"] = tostring(#body),
            ["Content-Type"] = "application/x-www-form-urlencoded",
            ["User-Agent"] = "Mozilla/5.0"
        },
        source = ltn12.source.string(body),
        sink = ltn12.sink.table(sink),
        redirect = false
    })
    print("Code:", c)
    if h then
        for k, v in pairs(h) do print(k, v) end
    end
end

request("http://cbunu.com/", "access_pass=2026")
request("https://cbunu.com/", "access_pass=2026")
