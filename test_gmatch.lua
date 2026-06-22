local f = io.open('/mnt/d/Project/truyenfull/haccbl_home.html', 'r')
local html = f:read('*all')
f:close()

local c = 0
for h, l in html:gmatch('<a[^>]-href="([^"]+)"[^>]*>([%s%S]-)</a>') do
    if h:lower():find('/genre/', 1, true) then
        c = c + 1
        print(h, l:gsub('^%s*', ''):gsub('%s*$', ''))
    end
end
print('Found: ' .. c)
