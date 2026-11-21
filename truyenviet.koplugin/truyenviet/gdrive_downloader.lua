local Http = require("truyenviet/http_client")
local Debug = require("truyenviet/debugger")
local EbookDownloader = require("truyenviet/ebook_downloader")
local socket_url = require("socket.url")

local GDriveDownloader = {}

local BROWSER_UA = "Mozilla/5.0 (Linux; Android 10) AppleWebKit/537.36 Chrome/122.0.0.0 Safari/537.36"

local function extractFileId(gdrive_url)
    if type(gdrive_url) ~= "string" then return nil end
    return gdrive_url:match("/file/d/([^/?#]+)")
        or gdrive_url:match("[?&]id=([^&]+)")
        or gdrive_url:match("/open%?id=([^&]+)")
end

local function isGDriveHost(url)
    return type(url) == "string"
        and (url:match("^https?://drive%.google%.com/")
            or url:match("^https?://docs%.google%.com/")
            or url:match("^https?://drive%.usercontent%.google%.com/")) ~= nil
end

local function toDirectGDriveUrl(url)
    local file_id = extractFileId(url)
    if not file_id then return url end
    return "https://drive.google.com/uc?export=download&id=" .. file_id
end

local function extractConfirmedUrl(html, fallback_url)
    if type(html) ~= "string" then return nil end
    local file_id = extractFileId(fallback_url)
        or html:match("https://drive%.google%.com/file/d/([A-Za-z0-9_%-]+)")
        or html:match("https://docs%.google%.com/file/d/([A-Za-z0-9_%-]+)")
        or html:match('"docid"%s*:%s*"([A-Za-z0-9_%-]+)"')
        or html:match("[?&]id=([A-Za-z0-9_%-]+)")
    if html:find("confirm=", 1, true) or html:find("download_warning", 1, true) or html:find("download%-form") then
        local confirm_token = html:match('confirm=([^"&%s<>]+)') or html:match("confirm=([^'&%s<>]+)")
        if confirm_token and file_id then
            return string.format(
                "https://drive.google.com/uc?export=download&confirm=%s&id=%s",
                confirm_token, file_id
            )
        end
        local form_tag, form_body = html:match("(<form[^>]*>)([%s%S]-)</form>")
        local form_action = (form_tag and form_tag:match('action="([^"]*)"')) or html:match('action="([^"]*)"')
        if form_action and form_action ~= "" then
            form_action = form_action:gsub("&amp;", "&")
            if not form_action:match("^https?://") then
                form_action = socket_url.absolute("https://drive.google.com/", form_action)
            end
            if form_action:match("^https?://") then
                if form_body and not form_action:find("?", 1, true) then
                    local params = {}
                    for input_tag in form_body:gmatch("<input[^>]*>") do
                        local name = input_tag:match('name="([^"]+)"') or input_tag:match("name='([^']+)'")
                        local val = input_tag:match('value="([^"]*)"') or input_tag:match("value='([^']*)'")
                        if name and val and name ~= "" then
                            table.insert(params, name .. "=" .. val)
                        end
                    end
                    if #params > 0 then
                        form_action = form_action .. "?" .. table.concat(params, "&")
                    end
                end
                return form_action
            end
        end
    end
    local direct_uc = html:match('(https://drive%.usercontent%.google%.com/download%?[^"\'<>%s]+)')
        or html:match('(https://drive%.google%.com/uc%?[^"\'<>%s]+)')
    if direct_uc then
        return (direct_uc:gsub("&amp;", "&"))
    end
    -- When a redirect (e.g. Dilib /readbook/...) lands on a Google Drive /file/d/<id>/view HTML page,
    -- convert the discovered file ID into a direct /uc?export=download URL.
    if file_id and not tostring(fallback_url or ""):find("uc%?export=download", 1, false) then
        return "https://drive.google.com/uc?export=download&id=" .. file_id
    end
    return nil
end

local function looksLikeHtml(bytes, headers)
    local content_type = headers and (headers["content-type"] or headers["Content-Type"])
    if tostring(content_type or ""):lower():find("text/html", 1, true) then
        return true
    end
    return type(bytes) == "string" and bytes:match("^%s*<[!hH]") ~= nil
end

-- Resolve redirect chain without buffering file payloads in RAM.
function GDriveDownloader:resolveUrl(url)
    if type(url) ~= "string" or not url:match("^https?://") then
        return nil, nil
    end
    local current_url = url
    if isGDriveHost(current_url) then
        return toDirectGDriveUrl(current_url), nil
    end
    for _ = 1, 10 do
        local _, _, headers, code = Http:request("HEAD", current_url, nil, {
            ["User-Agent"] = BROWSER_UA,
        }, { redirect = false })
        local numeric_code = tonumber(code) or 0
        if numeric_code >= 300 and numeric_code < 400 and headers and headers["location"] then
            local location = headers["location"]
            if not location:match("^https?://") then
                location = socket_url.absolute(current_url, location)
            end
            if not location or not location:match("^https?://") then
                return nil, nil
            end
            current_url = location
            if isGDriveHost(current_url) then
                return toDirectGDriveUrl(current_url), nil
            end
        else
            break
        end
    end
    return current_url, nil
end

-- Stream file from resolved URL to save_path via `.part`, validating payload before rename.
function GDriveDownloader:download(url, save_path)
    Debug.write("[GDrive] Downloading: " .. tostring(url) .. " -> " .. tostring(save_path))
    if type(Http.downloadToFile) ~= "function" then
        return nil, "Phiên bản HTTP hiện tại không hỗ trợ tải tệp dạng streaming"
    end

    local target_url = isGDriveHost(url) and toDirectGDriveUrl(url) or url
    if type(target_url) ~= "string" or not target_url:match("^https?://") then
        return nil, "Link tải không hợp lệ"
    end
    if not isGDriveHost(target_url) and type(Http.request) == "function" then
        local resolved = self:resolveUrl(target_url)
        if type(resolved) == "string" and resolved:match("^https?://") then
            target_url = resolved
        end
    end

    local temp_path = save_path .. ".part"
    local req_headers = { ["User-Agent"] = BROWSER_UA }

    for attempt = 1, 3 do
        os.remove(temp_path)
        local downloaded, err, headers = Http:downloadToFile(target_url, temp_path, req_headers)
        if not downloaded then
            os.remove(temp_path)
            return nil, "Không thể tải file: " .. tostring(err)
        end

        local preview, preview_err = EbookDownloader.readPreview(temp_path, 262144)
        if not preview or preview == "" then
            os.remove(temp_path)
            return nil, "Không thể kiểm tra tệp đã tải: " .. tostring(preview_err or "tệp rỗng")
        end

        if looksLikeHtml(preview, headers) then
            local confirmed = attempt < 3 and extractConfirmedUrl(preview, target_url) or nil
            if confirmed and confirmed ~= target_url then
                Debug.write("[GDrive] Retrying confirmed Google Drive URL: " .. confirmed)
                target_url = confirmed
            else
                os.remove(temp_path)
                return nil, "Máy chủ trả về HTML thay vì tệp hợp lệ"
            end
        else
            local lower_path = tostring(save_path):lower()
            local expected = lower_path:match("%.pdf$") and "pdf"
                or lower_path:match("%.epub$") and "epub"
                or lower_path:match("%.mobi$") and "mobi"
                or lower_path:match("%.azw3$") and "azw3"
            if expected then
                local format, validation_err = EbookDownloader.validate(preview, headers, save_path)
                if not format then
                    os.remove(temp_path)
                    return nil, validation_err
                end
                if format ~= expected then
                    os.remove(temp_path)
                    return nil, "Định dạng tệp tải về không khớp"
                end
            end

            local ok, rename_err = os.rename(temp_path, save_path)
            if not ok then
                os.remove(temp_path)
                return nil, "Không thể lưu file: " .. tostring(rename_err)
            end
            Debug.write("[GDrive] Download complete: " .. save_path)
            return save_path
        end
    end

    os.remove(temp_path)
    return nil, "Không thể tải tệp sau khi xác nhận liên kết"
end

return GDriveDownloader
