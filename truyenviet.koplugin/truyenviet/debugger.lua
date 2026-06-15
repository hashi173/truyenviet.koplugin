local Storage = require("truyenviet/storage")
local ffiutil = require("ffi/util")

local Debug = {}

local function safe_write(path, text)
    local ok, f = pcall(function() return io.open(path, "a") end)
    if not ok or not f then return end
    f:write(text)
    f:close()
end

function Debug.write(msg)
    local ok, root = pcall(function() return Storage:getRootDir() end)
    if not ok or not root then return end
    local logpath = ffiutil.joinPath(root, "truyenviet-debug.txt")
    local line = os.date("%Y-%m-%d %H:%M:%S") .. " " .. tostring(msg) .. "\n"
    safe_write(logpath, line)
end

return Debug
