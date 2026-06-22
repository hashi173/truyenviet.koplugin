package.path = package.path .. ';/usr/lib/koreader/frontend/?.lua;/usr/lib/koreader/frontend/?/init.lua'
local ok, json = pcall(require, "json")
if not ok then
    print("No json")
    ok, json = pcall(require, "dkjson")
end
if ok and json and json.decode then
    print(type(json.decode('{"a": 1}')))
else
    print("Failed")
end
