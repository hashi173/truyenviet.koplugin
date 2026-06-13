local Http = require("truyenviet/http_client")
local ImageUtils = require("truyenviet/image_utils")
local Storage = require("truyenviet/storage")
local Util = require("truyenviet/helpers")
local ffiutil = require("ffi/util")
local lfs = require("libs/libkoreader-lfs")

local CoverCache = {
    extensions = { "avif", "gif", "jpg", "png", "webp" },
    max_prefetch = 8,
}

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
    if not ImageUtils:isSupported(response_headers, content) then
        return nil, "Máy chủ không trả về ảnh bìa hợp lệ"
    end

    local extension = ImageUtils:detectExtension(
        response_headers,
        content,
        story.cover_url
    )
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
    local fast_mode = Storage.settings and Storage.settings:readSetting("fast_mode", false)
    if fast_mode then return stories end
    
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
