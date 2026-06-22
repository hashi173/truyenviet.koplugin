package.path = '/mnt/d/Project/truyenfull/truyenviet.koplugin/?.lua;' .. package.path
local Http = require('truyenviet.http_client')

local url = 'https://cbunu.com/truyen-tranh/end-scoop-199-chap-78.html'
local body = 'access_pass=12345'
local post_headers = {
    ['Content-Type'] = 'application/x-www-form-urlencoded',
    ['Referer'] = 'https://cbunu.com/',
    ['Origin'] = 'https://cbunu.com',
}

local html, err, headers, code, resp_body = Http:request('POST', url, body, post_headers, { redirect = false })
print('CODE:', code)
if headers then
    for k, v in pairs(headers) do print(k, v) end
end
