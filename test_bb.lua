local bb = require('ffi/blitbuffer')
local ok, b = pcall(bb.new, bb, 'cbunu_hoan_thanh.html')
if ok then
    print("Success! Size:", b:getWidth(), b:getHeight())
else
    print("Failed:", b)
end
