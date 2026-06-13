local Archiver = require("ffi/archiver")
local Http = require("truyenviet/http_client")
local Storage = require("truyenviet/storage")
local Util = require("truyenviet/helpers")
local lfs = require("libs/libkoreader-lfs")

local DocumentBuilder = {}

local IMAGE_EXTENSIONS = {
    ["image/avif"] = "avif",
    ["image/gif"] = "gif",
    ["image/jpeg"] = "jpg",
    ["image/jpg"] = "jpg",
    ["image/png"] = "png",
    ["image/webp"] = "webp",
}

local function detectImageExtension(headers, content, url)
    local content_type = headers and headers["content-type"]
    if content_type then
        content_type = content_type:match("^%s*([^;]+)")
        if IMAGE_EXTENSIONS[content_type] then
            return IMAGE_EXTENSIONS[content_type]
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

    return url:match("%.([%a%d]+)[%?#]") or url:match("%.([%a%d]+)$") or "jpg"
end

local function replaceFile(temp_path, final_path)
    if lfs.attributes(final_path, "mode") == "file" then
        os.remove(final_path)
    end
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
        for index, image in ipairs(payload.images) do
            local content, headers_or_error, url = downloadImage(image, payload.referer)
            if not content then
                return nil, string.format(
                    "Không tải được ảnh %d/%d: %s",
                    index,
                    #payload.images,
                    tostring(headers_or_error)
                )
            end

            local extension = detectImageExtension(headers_or_error, content, url)
            local entry_name = string.format("%04d.%s", index, extension)
            if not archive:addFileFromMemory(entry_name, content, os.time()) then
                return nil, archive.err or ("Không thể ghi " .. entry_name)
            end

            if index % 8 == 0 then
                collectgarbage()
            end
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

function DocumentBuilder:build(source, story, chapter, payload)
    local existing = self:getExistingPath(source, story, chapter)
    if existing then
        return existing
    end
    if source.kind == "comic" then
        return self:buildComic(source, story, chapter, payload)
    end
    return self:buildText(source, story, chapter, payload)
end

return DocumentBuilder
