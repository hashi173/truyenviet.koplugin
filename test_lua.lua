local b64chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/'
local b64dec = {}
for i = 1, 64 do b64dec[b64chars:sub(i,i)] = i - 1 end
local function base64_decode(str)
    str = str:gsub('[^A-Za-z0-9+/=]', '')
    local len = #str
    local out = {}
    for i = 1, len, 4 do
        local c1, c2, c3, c4 = str:sub(i,i), str:sub(i+1,i+1), str:sub(i+2,i+2), str:sub(i+3,i+3)
        local n1, n2, n3, n4 = b64dec[c1], b64dec[c2], b64dec[c3] or 0, b64dec[c4] or 0
        local v = n1 * 262144 + n2 * 4096 + n3 * 64 + n4
        table.insert(out, string.char(math.floor(v / 65536) % 256))
        if c3 ~= '=' then table.insert(out, string.char(math.floor(v / 256) % 256)) end
        if c4 ~= '=' then table.insert(out, string.char(v % 256)) end
    end
    return table.concat(out)
end

local function decrypt(url)
    local path, filename, ext = url:match("^(.-)/([^/%.]+)%.([^/%.]+)$")
    if not filename then return url end

    local base64 = filename:gsub("-", "+"):gsub("_", "/")
    local pad = (4 - (#base64 % 4)) % 4
    base64 = base64 .. string.rep("=", pad)
    
    local decoded = base64_decode(base64)
    local salt = "dualeo_salt_2025"
    local bit = require("bit")
    
    local decrypted = ""
    for i = 1, #decoded do
        local charCode = decoded:byte(i)
        local saltCode = salt:byte((i - 1) % #salt + 1)
        decrypted = decrypted .. string.char(bit.bxor(charCode, saltCode))
    end
    
    if decrypted:match("^[A-Za-z0-9-]+$") then
        return path .. "/" .. decrypted .. "." .. ext
    end
    return url
end

print(decrypt("https://cdn7.imgdualeo1.com/uploads/2026-05-16/VUJWVFxbb0FRXEVnBB0HB1VEVlRcWGs.webp"))
print(decrypt("https://cdn7.imgdualeo1.com/uploads/2026-05-16/1778940200179-776865929.webp"))
print(decrypt("https://img.imgdualeo1.com/avatar/-1725176167.jpg"))
