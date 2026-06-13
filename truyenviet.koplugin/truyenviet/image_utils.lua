local ImageUtils = {}

local CONTENT_TYPE_EXTENSIONS = {
    ["image/avif"] = "avif",
    ["image/gif"] = "gif",
    ["image/jpeg"] = "jpg",
    ["image/jpg"] = "jpg",
    ["image/png"] = "png",
    ["image/webp"] = "webp",
}

local function normalizeContentType(headers)
    local content_type = headers and headers["content-type"]
    if type(content_type) ~= "string" then
        return nil
    end
    return content_type:match("^%s*([^;]+)"):lower()
end

function ImageUtils:isSupported(headers, content)
    if type(content) ~= "string" then
        return false
    end
    local content_type = normalizeContentType(headers)
    if content_type and CONTENT_TYPE_EXTENSIONS[content_type] then
        return true
    end
    return content:sub(1, 3) == "\255\216\255"
        or content:sub(1, 8) == "\137PNG\r\n\26\n"
        or (content:sub(1, 4) == "RIFF" and content:sub(9, 12) == "WEBP")
        or content:sub(1, 6) == "GIF87a"
        or content:sub(1, 6) == "GIF89a"
        or (
            content:sub(5, 8) == "ftyp"
            and (
                content:sub(9, 12) == "avif"
                or content:sub(9, 12) == "avis"
            )
        )
end

function ImageUtils:detectExtension(headers, content, url)
    local content_type = normalizeContentType(headers)
    if content_type and CONTENT_TYPE_EXTENSIONS[content_type] then
        return CONTENT_TYPE_EXTENSIONS[content_type]
    end
    if content:sub(1, 3) == "\255\216\255" then
        return "jpg"
    elseif content:sub(1, 8) == "\137PNG\r\n\26\n" then
        return "png"
    elseif content:sub(1, 4) == "RIFF" and content:sub(9, 12) == "WEBP" then
        return "webp"
    elseif content:sub(1, 6) == "GIF87a" or content:sub(1, 6) == "GIF89a" then
        return "gif"
    elseif content:sub(5, 8) == "ftyp" then
        return "avif"
    end
    return tostring(url):match("%.([%a%d]+)[%?#]")
        or tostring(url):match("%.([%a%d]+)$")
        or "jpg"
end

return ImageUtils
