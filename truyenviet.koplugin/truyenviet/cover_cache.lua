local Http = require("truyenviet/http_client")
local ImageUtils = require("truyenviet/image_utils")
local Storage = require("truyenviet/storage")
local Util = require("truyenviet/helpers")
local ffiutil = require("ffi/util")
local lfs = require("libs/libkoreader-lfs")

local CoverCache = {
    extensions = { "gif", "jpg", "png", "webp" },
    max_prefetch = 10,
}

function CoverCache:get(story)
    if not story.cover_url or story.cover_url == "" then
        return nil
    end
    local stem = Util.stableHash(story.cover_url)
    for _, extension in ipairs(self.extensions) do
        local path = ffiutil.joinPath(
            Storage:getCoverCacheDir(),
            stem .. "." .. extension
        )
        if lfs.attributes(path, "mode") == "file" then
            local file = io.open(path, "rb")
            if file then
                local content = file:read(12)
                file:close()
                if content and ImageUtils:isSupported(nil, content) then
                    return path
                else
                    os.remove(path)
                end
            else
                os.remove(path)
            end
        end
    end
end

function CoverCache:download(story, source)
    local existing = self:get(story)
    if existing then
        return existing
    end
    if not story.cover_url or story.cover_url == "" then
        return nil
    end

    local headers = source.getCoverHeaders and source:getCoverHeaders(story) or {
        ["Referer"] = source.base_url .. "/",
    }
    headers["Accept"] = "image/webp,image/apng,image/*,*/*;q=0.8"

    -- Một số nguồn (vd truyenc.com) trả cover_url có khoảng trắng chưa được
    -- encode (vd "...Phan 2-Quy-Co-Nu.jpg") -> server trả 400 Bad Request vì
    -- URL có khoảng trắng thô là không hợp lệ. Encode khoảng trắng thành %20
    -- trước khi gửi request (chỉ encode dấu cách, giữ nguyên phần còn lại vì
    -- URL này thường đã encode sẵn các ký tự khác).
    local request_url = story.cover_url:gsub(" ", "%%20")

    local content, err, response_headers = Http:requestAsync("GET", request_url, nil, headers)
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
    
    local limit = #stories
    
    local ok, copas = pcall(require, "copas")
    if ok and copas and copas.addthread then
        local active_downloads = 0
        local max_concurrent = 4
        
        for index = 1, limit do
            while active_downloads >= max_concurrent do
                copas.step()
            end
            
            active_downloads = active_downloads + 1
            copas.addthread(function()
                local story = stories[index]
                local source = registry:get(story.source_id)
                if source then
                    story.cover_path = self:download(story, source)
                end
                active_downloads = active_downloads - 1
            end)
        end
        
        while active_downloads > 0 do
            copas.step()
        end
    else
        for index = 1, #stories do
            local story = stories[index]
            local source = registry:get(story.source_id)
            if source then
                story.cover_path = self:download(story, source)
            end
            if index % 5 == 0 then
                collectgarbage("collect")
            end
        end
    end
    
    collectgarbage("collect")
    return stories
end

return CoverCache