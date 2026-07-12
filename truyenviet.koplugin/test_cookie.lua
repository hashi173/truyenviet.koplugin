local headers = {
    ["set-cookie"] = "xf_user=235183%2C327b94d347307d701c349b67b2ea7aa262b3aab0; expires=Sat, 08-Aug-2026 05:59:40 GMT; Max-Age=2592000; path=/; secure; httponly, xf_session=c54aeb995eaaba59a45c45ba86c7d2d1; path=/; secure; httponly"
}

local cookies = {}
local set_cookie = headers["set-cookie"]

for name, value in set_cookie:gmatch("([%w_%-]+)=([^;]+)") do
    local l = name:lower()
    if l ~= "expires" and l ~= "path" and l ~= "max-age" and l ~= "secure" and l ~= "httponly" and l ~= "domain" and l ~= "samesite" then
        cookies[name] = value
    end
end

for k, v in pairs(cookies) do
    print(k, "=", v)
end
