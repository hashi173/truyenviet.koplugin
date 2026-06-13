local Http = require("truyenviet/http_client")
local Storage = require("truyenviet/storage")
local Util = require("truyenviet/helpers")
local ffiutil = require("ffi/util")
local lfs = require("libs/libkoreader-lfs")

local CoverCache = {
    extensions = { "avif", "gif", "jpg", "png", "webp" },
    max_prefetch = 50,
}

local CONTENT_TYPE_EXTENSIONS = {
    ["image/avif"] = "avif",
    ["image/gif"] = "gif",
    ["image/jpeg"] = "jpg",
    ["image/jpg"] = "jpg",
    ["image/png"] = "png",
    ["image/webp"] = "webp",
}

local function detectExtension(headers, content, url)
    local content_type = headers and headers["content-type"]
    if content_type then
        content_type = content_type:match("^%s*([^;]+)")
        if CONTENT_TYPE_EXTENSIONS[content_type] then
            return CONTENT_TYPE_EXTENSIONS[content_type]
        end
    end
    if content:sub(1, 3) == "\255\216\255" then
        return "jpg"
    elseif content:sub(1, 8) == "\137PNG\r\n\26\n" then
        return "png"
    elseif content:sub(1, 4) == "RIFF" and content:sub(9, 12) == "WEBP" then
        return "webp"
    elseif content:sub(1, 6) == "GIF87a" or content:sub(1, 6) == "GIF89a" then
        return "gif"
    end
    return tostring(url):match("%.([%a%d]+)[%?#]")
        or tostring(url):match("%.([%a%d]+)$")
        or "jpg"
end

function CoverCache:get(story)
    if not story.cover_url then
        return nil
    end
    local stem = Util.stableHash(story.cover_url)
    for _, extension in ipairs(self.extensions) do
        local path = ffiutil.joinPath(
            Storage:getCoverCacheDir(),
            stem .. "." .. extension
        )
        if lfs.attributes(path, "mode") == "file" then
            return path
        end
    end
end

function CoverCache:download(story, source)
    local existing = self:get(story)
    if existing then
        return existing
    end
    if not story.cover_url then
        return nil
    end

    local headers = source.getCoverHeaders and source:getCoverHeaders(story) or {
        ["Referer"] = source.base_url .. "/",
    }
    headers["Accept"] = "image/avif,image/webp,image/apng,image/*,*/*;q=0.8"

    local content, err, response_headers = Http:get(story.cover_url, headers)
    if not content then
        return nil, err
    end
    local content_type = response_headers and response_headers["content-type"] or ""
    if not content_type:find("^image/") and content:sub(1, 4) == "<!DO" then
        return nil, "Máy chủ ảnh trả về HTML"
    end

    local extension = detectExtension(response_headers, content, story.cover_url)
    local path = ffiutil.joinPath(
        Storage:getCoverCacheDir(),
        Util.stableHash(story.cover_url) .. "." .. extension
    )
    local temp_path = path .. ".part"
    local file, open_err = io.open(temp_path, "wb")
    if not file then
        return nil, open_err
    end
    local ok, write_err = file:write(content)
    file:close()
    if not ok then
        os.remove(temp_path)
        return nil, write_err
    end
    os.remove(path)
    local renamed, rename_err = os.rename(temp_path, path)
    if not renamed then
        os.remove(temp_path)
        return nil, rename_err
    end
    return path
end

function CoverCache:prefetch(stories, registry)
    local limit = math.min(#stories, self.max_prefetch)
    for index = 1, limit do
        local story = stories[index]
        local source = registry:get(story.source_id)
        if source then
            story.cover_path = self:download(story, source)
        end
        -- Chạy thu gom rác sau mỗi 5 ảnh để tránh tràn bộ nhớ (Out of Memory)
        -- trên các máy đọc sách cũ có RAM hạn chế.
        if index % 5 == 0 then
            collectgarbage("collect")
        end
    end
    return stories
end

return CoverCache
