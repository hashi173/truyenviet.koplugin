local ImageUtils = {}

local CONTENT_TYPE_EXTENSIONS = {
    ["image/gif"] = "gif",
    ["image/jpeg"] = "jpg",
    ["image/jpg"] = "jpg",
    ["image/png"] = "png",
    ["image/webp"] = "webp",
}

function ImageUtils:isSupported(headers, content)
    if type(content) ~= "string" then
        return false
    end
    return content:sub(1, 3) == "\255\216\255"
        or content:sub(1, 8) == "\137PNG\r\n\26\n"
        or (content:sub(1, 4) == "RIFF" and content:sub(9, 12) == "WEBP")
        or content:sub(1, 6) == "GIF87a"
        or content:sub(1, 6) == "GIF89a"
end

function ImageUtils:detectExtension(headers, content, url)
    if type(content) == "string" then
        if content:sub(1, 3) == "\255\216\255" then
            return "jpg"
        elseif content:sub(1, 8) == "\137PNG\r\n\26\n" then
            return "png"
        elseif content:sub(1, 4) == "RIFF" and content:sub(9, 12) == "WEBP" then
            return "webp"
        elseif content:sub(1, 6) == "GIF87a" or content:sub(1, 6) == "GIF89a" then
            return "gif"
        end
    end
    local ext = tostring(url):match("%.([%a%d]+)[%?#]")
        or tostring(url):match("%.([%a%d]+)$")
    if ext then
        ext = ext:lower()
        if ext == "jpeg" or ext == "jpg" then return "jpg"
        elseif ext == "png" then return "png"
        elseif ext == "webp" then return "webp"
        elseif ext == "gif" then return "gif"
        end
    end
    return "jpg"
end

return ImageUtils

