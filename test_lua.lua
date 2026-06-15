local f = io.open('test_anchor.txt', 'r')
local html = f:read('*a')
f:close()

local count = 0
for anchor_attrs, href, content in html:gmatch("<a([^>]*)href=\"(/doc%-truyen/[^\"]+)\"([^>]*)>([%s%S]-)</a>") do
    print("MATCHED!")
    print(href)
    count = count + 1
end
print("Total matches: " .. count)
