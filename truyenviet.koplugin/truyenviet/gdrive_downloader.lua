local Http = require("truyenviet/http_client")
local Debug = require("truyenviet/debugger")

local GDriveDownloader = {}

-- Follow redirect chain to get final download URL
-- Dilib uses /download/<hash> which redirects to Google Drive
function GDriveDownloader:resolveUrl(url)
    Debug.write("[GDrive] Resolving URL: " .. url)

    -- First request with no redirect to capture Location header
    local content, err, headers, code, error_body = Http:request(
        "GET", url, nil, {
            ["User-Agent"] = "Mozilla/5.0 (Linux; Android 10) AppleWebKit/537.36 Chrome/122.0.0.0 Safari/537.36",
            ["Accept"] = "text/html,application/xhtml+xml,*/*",
        },
        { redirect = false }
    )

    -- Follow redirects manually
    local max_redirects = 10
    local current_url = url
    for i = 1, max_redirects do
        if not headers then break end
        local numeric_code = tonumber(code) or 0
        if numeric_code >= 300 and numeric_code < 400 then
            local location = headers["location"]
            if location then
                if not location:match("^https?://") then
                    local parsed = require("socket.url").parse(current_url)
                    location = parsed.scheme .. "://" .. parsed.host .. location
                end
                Debug.write("[GDrive] Redirect " .. i .. ": " .. location)
                current_url = location

                -- If it's a Google Drive URL, handle specially
                if location:match("drive%.google%.com") or location:match("docs%.google%.com") then
                    return self:resolveGDriveUrl(location)
                end

                content, err, headers, code = Http:request(
                    "GET", location, nil, {
                        ["User-Agent"] = "Mozilla/5.0 (Linux; Android 10) AppleWebKit/537.36 Chrome/122.0.0.0 Safari/537.36",
                    },
                    { redirect = false }
                )
            else
                break
            end
        else
            -- No more redirects - this is the final URL
            break
        end
    end

    -- If we got content directly, return it
    if content and #content > 1000 then
        return current_url, content
    end

    return current_url, nil
end

-- Handle Google Drive specific download pages
function GDriveDownloader:resolveGDriveUrl(gdrive_url)
    Debug.write("[GDrive] Resolving Google Drive URL: " .. gdrive_url)

    -- Extract file ID from various GDrive URL formats
    local file_id = gdrive_url:match("/file/d/([^/]+)")
        or gdrive_url:match("[?&]id=([^&]+)")
        or gdrive_url:match("/open%?id=([^&]+)")

    if not file_id then
        return gdrive_url, nil
    end

    -- Try direct download URL
    local download_url = "https://drive.google.com/uc?export=download&id=" .. file_id
    Debug.write("[GDrive] Trying direct download: " .. download_url)

    local content, err, headers, code = Http:request("GET", download_url, nil, {
        ["User-Agent"] = "Mozilla/5.0 (Linux; Android 10) AppleWebKit/537.36 Chrome/122.0.0.0 Safari/537.36",
    })

    if not content then
        return download_url, nil
    end

    -- Check for virus scan confirmation page
    if content:find("confirm=", 1, true) or content:find("download_warning", 1, true) then
        Debug.write("[GDrive] Virus scan confirmation page detected")
        -- Extract confirmation token
        local confirm_token = content:match('confirm=([^"&]+)')
            or content:match("confirm=([^'&]+)")
        if confirm_token then
            local confirmed_url = string.format(
                "https://drive.google.com/uc?export=download&confirm=%s&id=%s",
                confirm_token, file_id
            )
            Debug.write("[GDrive] Using confirmed URL: " .. confirmed_url)
            return confirmed_url, nil
        end

        -- Try extracting from form action
        local form_action = content:match('action="([^"]*)"')
        if form_action then
            if not form_action:match("^https?://") then
                form_action = "https://drive.google.com" .. form_action
            end
            return form_action, nil
        end
    end

    -- If content looks like a file (not HTML), return as-is
    if not content:find("<!DOCTYPE", 1, true) and not content:find("<html", 1, true) then
        return download_url, content
    end

    return download_url, nil
end

-- Download file from resolved URL to save_path
function GDriveDownloader:download(url, save_path)
    Debug.write("[GDrive] Downloading: " .. url .. " -> " .. save_path)

    local final_url, cached_content = self:resolveUrl(url)

    local content
    if cached_content and #cached_content > 1000 then
        content = cached_content
    else
        local err
        content, err = Http:get(final_url, {
            ["User-Agent"] = "Mozilla/5.0 (Linux; Android 10) AppleWebKit/537.36 Chrome/122.0.0.0 Safari/537.36",
        })
        if not content then
            return nil, "Không thể tải file: " .. tostring(err)
        end
    end

    -- Verify it's not an error page
    if #content < 500 and content:find("<html", 1, true) then
        return nil, "Nhận được trang lỗi thay vì file"
    end

    local temp_path = save_path .. ".part"
    local file, open_err = io.open(temp_path, "wb")
    if not file then
        return nil, "Không thể tạo file: " .. tostring(open_err)
    end
    local written, write_err = file:write(content)
    file:close()
    if not written then
        os.remove(temp_path)
        return nil, "Không thể ghi file: " .. tostring(write_err)
    end

    local ok, rename_err = os.rename(temp_path, save_path)
    if not ok then
        os.remove(temp_path)
        return nil, "Không thể lưu file: " .. tostring(rename_err)
    end

    Debug.write("[GDrive] Download complete: " .. save_path .. " (" .. #content .. " bytes)")
    return save_path
end

return GDriveDownloader
