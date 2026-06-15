local Archiver = require("ffi/archiver")
local Http = require("truyenviet/http_client")
local ImageUtils = require("truyenviet/image_utils")
local Storage = require("truyenviet/storage")
local Util = require("truyenviet/helpers")
local lfs = require("libs/libkoreader-lfs")
local socket = require("socket")
local Debug = require("truyenviet/debugger")

local DocumentBuilder = {}

local function replaceFile(temp_path, final_path)
    local ok, err = os.rename(temp_path, final_path)
    if not ok then
        os.remove(temp_path)
        return nil, err
    end
    return final_path
end

function DocumentBuilder:getExistingPath(source, story, chapter)
    local path = Storage:getChapterPath(source, story, chapter)
    if lfs.attributes(path, "mode") == "file" then
        return path
    end
end

function DocumentBuilder:buildText(source, story, chapter, payload)
    local path = Storage:getChapterPath(source, story, chapter)
    local temp_path = path .. ".part"
    local file, err = io.open(temp_path, "wb")
    if not file then
        return nil, err
    end

    local title = payload.title or chapter.title
    local html = string.format([[
<!DOCTYPE html>
<html lang="vi">
<head>
  <meta charset="utf-8"/>
  <meta name="viewport" content="width=device-width, initial-scale=1"/>
  <title>%s</title>
  <style>
    body { line-height: 1.65; margin: 5%%; text-align: justify; }
    h1 { font-size: 1.35em; line-height: 1.3; text-align: center; }
    .source { color: #666; font-size: 0.8em; text-align: center; }
    img { height: auto; max-width: 100%%; }
  </style>
</head>
<body>
  <h1>%s</h1>
  <p class="source">%s</p>
  <hr/>
  <article>%s</article>
</body>
</html>
]],
        Util.escapeHtml(title),
        Util.escapeHtml(title),
        Util.escapeHtml(payload.url or chapter.url),
        payload.content
    )

    local ok, write_err = file:write(html)
    file:close()
    if not ok then
        os.remove(temp_path)
        return nil, write_err
    end

    return replaceFile(temp_path, path)
end

local function downloadImage(image, referer)
    local last_error
    for _, url in ipairs(image.urls) do
        local content, err, headers = Http:get(url, {
            ["Referer"] = referer,
            ["Accept"] = "image/avif,image/webp,image/apng,image/*,*/*;q=0.8",
        })
        if content then
            return content, headers, url
        end
        last_error = err
    end
    return nil, last_error
end

local function downloadImageWithRetry(image, referer, max_retries)
    max_retries = max_retries or 3
    local last_error
    local delay_ms = 500
    
    for attempt = 1, max_retries do
        for _, url in ipairs(image.urls) do
            local content, err, headers = Http:get(url, {
                ["Referer"] = referer,
                ["Accept"] = "image/avif,image/webp,image/apng,image/*,*/*;q=0.8",
            })
            if content then
                return content, headers, url
            end
            last_error = err
        end
        
        if attempt < max_retries then
            socket.sleep(delay_ms / 1000)
            delay_ms = math.min(delay_ms * 2, 5000)
        end
    end
    return nil, last_error
end

function DocumentBuilder:buildComic(source, story, chapter, payload)
    local path = Storage:getChapterPath(source, story, chapter)
    local temp_path = path .. ".part"
    os.remove(temp_path)

    local archive = Archiver.Writer:new()
    if not archive:open(temp_path, "zip") then
        return nil, archive.err or "Không thể tạo tệp CBZ"
    end
    archive:setZipCompression("store")

    local ok, result, result_err = pcall(function()
        local copas = require("copas")
        local active_downloads = 0
        local max_concurrent = source.id == "dualeo" and 1 or 4
        local has_error = false
        local archive_err = nil
        local failed_images = {}
        local downloaded_count = 0
        local max_retries = source.id == "dualeo" and 5 or 3

        for index, image in ipairs(payload.images) do
            while active_downloads >= max_concurrent do
                copas.step()
            end
            
            if has_error then break end

            active_downloads = active_downloads + 1
            copas.addthread(function()
                local last_error
                local content, headers, final_url
                
                for attempt = 1, max_retries do
                    for _, url in ipairs(image.urls) do
                        local req_headers = (type(source.getImageHeaders) == "function" and source:getImageHeaders()) or {
                            ["Referer"] = payload.referer or "",
                            ["Accept"] = "image/avif,image/webp,image/apng,image/*,*/*;q=0.8",
                        }
                        local c, e, h = Http:requestAsync("GET", url, nil, req_headers)
                        if c then
                            content = c
                            headers = h
                            final_url = url
                            break
                        end
                        last_error = e
                        Debug.write("DocumentBuilder:buildComic download failed idx=" .. tostring(index) .. " url=" .. tostring(url) .. " err=" .. tostring(e))
                    end
                    
                    if content then
                        break
                    end
                    
                    if attempt < max_retries then
                        socket.sleep(0.2 * attempt)
                    end
                end

                if content and ImageUtils:isSupported(headers, content) then
                    local extension = ImageUtils:detectExtension(headers, content, final_url)
                    local entry_name = string.format("%04d.%s", index, extension)
                    if not archive:addFileFromMemory(entry_name, content, os.time()) then
                        has_error = true
                        archive_err = archive.err or ("Không thể ghi " .. entry_name)
                    else
                        downloaded_count = downloaded_count + 1
                    end
                else
                    Debug.write("DocumentBuilder:buildComic unsupported/failed idx=" .. tostring(index) .. " final_url=" .. tostring(final_url) .. " last_error=" .. tostring(last_error))
                    table.insert(failed_images, index)
                end

                if source.id == "dualeo" then
                    socket.sleep(0.3)
                end
                active_downloads = active_downloads - 1
            end)
        end

        while active_downloads > 0 do
            copas.step()
        end

        if has_error then
            error(archive_err)
        end
        
        if #failed_images > 0 then
            error(string.format("Lỗi tải %d ảnh (thành công %d/%d)", 
                #failed_images, downloaded_count, #payload.images))
        end
        
        return true
    end)

    archive:close()
    collectgarbage()
    collectgarbage()

    if not ok then
        os.remove(temp_path)
        return nil, tostring(result)
    end
    if not result then
        os.remove(temp_path)
        return nil, result_err
    end

    return replaceFile(temp_path, path)
end

function DocumentBuilder:build(source, story, chapter, payload, force)
    if not force then
        local existing = self:getExistingPath(source, story, chapter)
        if existing then
            return existing
        end
    end
    if source.kind == "comic" then
        return self:buildComic(source, story, chapter, payload)
    end
    return self:buildText(source, story, chapter, payload)
end

return DocumentBuilder
