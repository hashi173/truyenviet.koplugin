package.path = package.path .. ';/mnt/d/Project/truyenfull/truyenviet.koplugin/?.lua'
local tve4u = require('truyenviet/sources/tve4u')
local ok, err = tve4u:login('phamthithienha17032005@gmail.com', 'Thienh@17032005')
print('Login:', ok, err)
if ok then
    local html = tve4u:authGet('https://tve-4u.org/')
    local f = io.open('/mnt/d/Project/truyenfull/truyenviet.koplugin/tve4u_logged_in.html', 'w')
    f:write(html or '')
    f:close()
    print('Saved')
end
