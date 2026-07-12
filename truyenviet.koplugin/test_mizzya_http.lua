local Http = require("truyenviet/http_client")
local url = "https://mizzya.wordpress.com/2007/05/15/list-truy%e1%bb%87n/"
print("Testing Http:get without force_luasec...")
local html1, err1, hdrs1, code1 = Http:get(url)
print("Result 1:", html1 and #html1 or "nil", err1, code1)

print("Testing Http:get with force_luasec...")
local html2, err2, hdrs2, code2 = Http:get(url, nil, { force_luasec = true })
print("Result 2:", html2 and #html2 or "nil", err2, code2)
