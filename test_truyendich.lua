local http = require('socket.http')
local ltn12 = require('ltn12')
local sink = {}
local body, code, headers, status = http.request{
    url = 'https://truyendich.ai/danh-sach/truyen-full',
    method = 'GET',
    headers = {
        ['User-Agent'] = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36',
    },
    sink = ltn12.sink.table(sink)
}
print('Code:', code)
print('Status:', status)
