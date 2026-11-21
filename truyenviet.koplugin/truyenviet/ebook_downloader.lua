-- Download and validate original ebook files.  Kept separate from the chapter
-- builder: an EPUB/PDF is never converted to an HTML chapter.
local Http = require("truyenviet/http_client")
local Util = require("truyenviet/helpers")

local Downloader = {}

local function formatFrom(content_type, name, bytes)
    content_type = tostring(content_type or ""):lower()
    name = tostring(name or ""):lower()
    if bytes:sub(1, 5) == "%PDF-" then return "pdf" end
    -- EPUB is a ZIP whose first member is the uncompressed mimetype record.
    if bytes:sub(1, 4) == "PK\003\004" and bytes:find("mimetypeapplication/epub+zip", 1, true) then return "epub" end
    -- MOBI / AZW3 (KF8) share the PalmDB header with "BOOKMOBI" at offset 60 (1-based 61..68).
    if #bytes >= 68 and bytes:sub(61, 68) == "BOOKMOBI" then
        return name:match("%.azw3$") and "azw3" or "mobi"
    end
    if content_type:find("application/pdf", 1, true) or name:match("%.pdf$") then return "pdf" end
    if content_type:find("epub", 1, true) or name:match("%.epub$") then return "epub" end
    if name:match("%.azw3$") then return "azw3" end
    if content_type:find("mobipocket", 1, true) or name:match("%.mobi$") then return "mobi" end
end

function Downloader.validate(bytes, headers, filename)
    if type(bytes) ~= "string" or #bytes == 0 then return nil, "Tệp tải về rỗng" end
    local content_type = headers and (headers["content-type"] or headers["Content-Type"])
    if tostring(content_type or ""):lower():find("text/html", 1, true) or bytes:match("^%s*<[!hH]") then
        return nil, "Máy chủ trả về HTML thay vì tệp ebook"
    end
    local format = formatFrom(content_type, filename, bytes)
    if not format then return nil, "Không nhận diện được EPUB/PDF hợp lệ" end
    if format == "pdf" and bytes:sub(1, 5) ~= "%PDF-" then return nil, "Tệp PDF không có chữ ký hợp lệ" end
    if format == "epub" and (bytes:sub(1, 4) ~= "PK\003\004" or not bytes:find("mimetypeapplication/epub+zip", 1, true)) then
        return nil, "Tệp EPUB không có cấu trúc hợp lệ"
    end
    if (format == "mobi" or format == "azw3") and (#bytes < 68 or bytes:sub(61, 68) ~= "BOOKMOBI") then
        return nil, "Tệp MOBI/AZW3 không có chữ ký hợp lệ"
    end
    return format
end

function Downloader.readPreview(path, max_bytes)
    local file, err = io.open(path, "rb")
    if not file then return nil, err end
    local bytes = file:read(max_bytes or 8192)
    file:close()
    return bytes
end

function Downloader.download(source, option, save_path)
    local url = type(option) == "table" and Util.absoluteUrl(source.base_url, option.url) or nil
    if not url or not url:match("^https?://") then
        return nil, "Link tải không hợp lệ"
    end
    local part = save_path .. ".part"
    os.remove(part)
    if type(Http.downloadToFile) ~= "function" then
        return nil, "Phiên bản HTTP hiện tại không hỗ trợ tải ebook dạng streaming"
    end
    local downloaded, err, headers = Http:downloadToFile(url, part, { Referer = source.base_url .. "/" })
    if not downloaded then return nil, err end
    local preview, preview_err = Downloader.readPreview(part)
    if not preview then os.remove(part); return nil, "Không thể kiểm tra tệp đã tải: " .. tostring(preview_err) end
    local format, validation_err = Downloader.validate(preview, headers, option.filename or save_path)
    if not format then os.remove(part); return nil, validation_err end
    local expected = (option.format or format):lower()
    if expected ~= format then os.remove(part); return nil, "Định dạng tệp tải về không khớp lựa chọn" end
    local renamed, rename_err = os.rename(part, save_path)
    if not renamed then os.remove(part); return nil, "Không thể hoàn tất lưu file: " .. tostring(rename_err) end
    return save_path, nil, format
end

return Downloader
