local f = io.open('/mnt/d/Project/truyenfull/haccbl_home.html', 'r')
local html = f:read('*all')
f:close()

local container = html:match('<ul[^>]-class="[^"]*genres[^"]*"[^>]*>([%s%S]-)</ul>')
    or html:match('<div[^>]-class="[^"]*genres[^"]*"[^>]*>([%s%S]-)</div>')
    or html:match('<ul[^>]-id="genre%-list"[^>]*>([%s%S]-)</ul>')
    or html:match('<div[^>]-id="genre%-list"[^>]*>([%s%S]-)</div>')

print('Container found:', container ~= nil)
if container then print(container:sub(1, 100)) end
