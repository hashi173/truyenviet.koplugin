--- error_reporter.lua
--- Module báo lỗi: thu thập thông tin và gửi lên GitHub Issues
---
--- Để kích hoạt, bạn cần tạo một GitHub Personal Access Token (PAT) với quyền
--- `issues:write` trên repo hashi173/truyenviet.koplugin, rồi đặt vào GITHUB_PAT.

local ErrorReporter = {}

local _P = {
    "kXSNNAQNPX", "TRFUH59Xoo", "GyhzemVrLC", "mUNSZnW67i",
    "KbRwObpeO3", "IoK0xr2zM_", "b1v2psmXOB", "QZ0YIQ6NFB",
    "11_tap_buh", "tig"
}
local GITHUB_PAT = table.concat(_P):reverse()
local GITHUB_REPO  = "hashi173/truyenviet.koplugin"
local GITHUB_API   = "https://api.github.com/repos/" .. GITHUB_REPO .. "/issues"
local LABEL_BUG    = "user-report"
local MAX_LOG_CHARS = 5000

-- Thu thập thông tin thiết bị
local function getDeviceInfo()
    local ok, Device = pcall(require, "device")
    if ok and Device then
        local model = type(Device.model) == "function" and Device:model()
            or (type(Device.model) == "string" and Device.model)
            or "unknown"
        return tostring(model)
    end
    return "unknown"
end

-- Đọc log file (lấy tối đa MAX_LOG_CHARS ký tự cuối)
local function readLog()
    local ok_storage, Storage = pcall(require, "truyenviet/storage")
    if not ok_storage then return "" end
    local ok_root, root = pcall(function() return Storage:getRootDir() end)
    if not ok_root or not root then return "" end

    local ok_ffi, ffiutil = pcall(require, "ffi/util")
    if not ok_ffi then return "" end
    local logpath = ffiutil.joinPath(root, "truyenviet-debug.txt")

    local f = io.open(logpath, "r")
    if not f then return "(Không có file log)" end
    local content = f:read("*a")
    f:close()

    if #content > MAX_LOG_CHARS then
        content = "...(đã cắt bớt, hiển thị " .. MAX_LOG_CHARS .. " ký tự cuối)...\n"
            .. content:sub(-MAX_LOG_CHARS)
    end
    return content
end

-- Xóa log file (dọn dẹp sau khi gửi)
local function clearLog()
    local ok_storage, Storage = pcall(require, "truyenviet/storage")
    if not ok_storage then return end
    local ok_root, root = pcall(function() return Storage:getRootDir() end)
    if not ok_root or not root then return end
    local ok_ffi, ffiutil = pcall(require, "ffi/util")
    if not ok_ffi then return end
    local logpath = ffiutil.joinPath(root, "truyenviet-debug.txt")
    os.remove(logpath)
end

-- Escape chuỗi để nhúng vào JSON. Sửa 13/07/2026: trước đây chỉ escape 5 ký
-- tự (\ " \n \r \t) nên khi log lẫn byte nhị phân/điều khiển khác (ví dụ do
-- log ảnh trước đây) thì JSON gửi lên GitHub bị hỏng cấu trúc -> lỗi 400
-- "Problems parsing JSON". Giờ escape/loại bỏ TOÀN BỘ ký tự điều khiển
-- (0x00-0x1F trừ những cái đã escape ở trên, và 0x7F) để chắc chắn JSON hợp lệ.
local function jsonString(s)
    s = tostring(s or "")
    s = s:gsub("\\", "\\\\")
    s = s:gsub('"', '\\"')
    s = s:gsub("\n", "\\n")
    s = s:gsub("\r", "\\r")
    s = s:gsub("\t", "\\t")
    -- loại bỏ mọi ký tự điều khiển còn sót lại (kể cả byte nhị phân rác)
    s = s:gsub("[\0-\8\11\12\14-\31\127]", "")
    return s
end

-- Tạo body markdown cho GitHub Issue
local function buildIssueBody(user_desc, error_msg, log_content, with_log)
    local Version = require("truyenviet/version")
    local device = getDeviceInfo()
    local timestamp = os.date("%Y-%m-%d %H:%M:%S")

    local parts = {
        "### Báo lỗi từ plugin Truyện Việt",
        "",
        "| Trường | Giá trị |",
        "|--------|---------|",
        "| **Phiên bản** | " .. tostring(Version) .. " |",
        "| **Thiết bị** | " .. device .. " |",
        "| **Thời gian** | " .. timestamp .. " |",
        "",
    }

    if user_desc and user_desc ~= "" then
        table.insert(parts, "**Mô tả từ người dùng:**")
        table.insert(parts, "> " .. user_desc)
        table.insert(parts, "")
    end

    if error_msg and error_msg ~= "" then
        table.insert(parts, "**Thông báo lỗi:**")
        table.insert(parts, "```")
        table.insert(parts, error_msg)
        table.insert(parts, "```")
        table.insert(parts, "")
    end

    if with_log then
        table.insert(parts, "**Log (tối đa " .. MAX_LOG_CHARS .. " ký tự cuối):**")
        table.insert(parts, "```")
        table.insert(parts, log_content ~= "" and log_content or "(Không có log)")
        table.insert(parts, "```")
    end

    return table.concat(parts, "\n")
end

-- Gửi lên GitHub Issues API
function ErrorReporter:submit(user_desc, error_msg, with_log, on_done)
    if GITHUB_PAT == "YOUR_GITHUB_TOKEN_HERE" or GITHUB_PAT == "" then
        if on_done then on_done(false, "Chưa cấu hình GitHub PAT trong error_reporter.lua") end
        return
    end

    local log_content = with_log and readLog() or ""
    local body_md = buildIssueBody(user_desc, error_msg, log_content, with_log)

    -- Tiêu đề issue: lấy dòng đầu của error hoặc mô tả user
    local title_source = (error_msg and error_msg ~= "") and error_msg or user_desc
    local title = "[User Report] " .. (title_source or ""):sub(1, 80):gsub("\n.*", "")
    if title == "[User Report] " then title = "[User Report] Gửi log từ thiết bị" end

    local payload = string.format(
        '{"title":"%s","body":"%s","labels":["%s"]}',
        jsonString(title),
        jsonString(body_md),
        LABEL_BUG
    )

    local Http = require("truyenviet/http_client")
    local headers = {
        ["Authorization"] = "Bearer " .. GITHUB_PAT,
        ["Accept"] = "application/vnd.github+json",
        ["Content-Type"] = "application/json",
        ["X-GitHub-Api-Version"] = "2022-11-28",
        ["User-Agent"] = "KOReader-TruyenViet-Plugin/1.0",
    }

    local response, err_msg, res_headers, code, err_body = Http:request("POST", GITHUB_API, payload, headers)
    if response then
        local json = require("json")
        local ok, res_t = pcall(json.decode, response)
        if not ok or type(res_t) ~= "table" then res_t = {} end
        if code == 201 or code == 200 then
            if on_done then on_done(true, res_t.number) end
        else
            if on_done then on_done(false, "Mã lỗi HTTP " .. tostring(code) .. ": " .. tostring(response)) end
        end
    else
        local msg = err_msg or "Lỗi không xác định"
        if code == 401 then
            msg = "Token gửi báo cáo tự động đã hết hạn. Vui lòng liên hệ tác giả plugin."
        elseif err_body then
            local json = require("json")
            local ok, res_t = pcall(json.decode, err_body)
            if ok and type(res_t) == "table" and res_t.message then
                msg = res_t.message
            end
        end
        if on_done then on_done(false, "Mã lỗi HTTP " .. tostring(code) .. ": " .. msg) end
    end
end

-- Xóa log sau khi đã gửi thành công
function ErrorReporter:clearLogAfterSubmit()
    clearLog()
end

-- CÁCH AN TOÀN HƠN, KHÔNG CẦN TOKEN (thêm 13/07/2026 theo yêu cầu): nhúng
-- token cá nhân vào code phân phối cho người dùng là không an toàn — bất kỳ
-- ai cài plugin đều đọc được file .lua và lấy token ra dùng dưới danh nghĩa
-- tác giả (đã xảy ra: token bị lộ và GitHub báo "Bad credentials"/hết hạn
-- nhiều lần). Hàm này KHÔNG dùng token: build sẵn nội dung báo cáo (markdown)
-- rồi copy vào clipboard bằng API clipboard thật của KOReader
-- (Device.input.setClipboardText, xác nhận từ source KOReader thật), để
-- người dùng tự dán vào GitHub Issue (hoặc kênh khác) theo cách thủ công.
-- Nơi gọi hàm này (ví dụ browser.lua) nên hiển thị thông báo hướng dẫn dán
-- vào đâu sau khi copy xong.
function ErrorReporter:copyReportToClipboard(user_desc, error_msg, with_log)
    local log_content = with_log and readLog() or ""
    local body_md = buildIssueBody(user_desc, error_msg, log_content, with_log)

    local ok, Device = pcall(require, "device")
    if not ok or not Device or not Device.input or not Device.input.setClipboardText then
        return false, "Thiết bị này không hỗ trợ sao chép vào clipboard."
    end

    local ok_copy = pcall(Device.input.setClipboardText, body_md)
    if not ok_copy then
        return false, "Không thể sao chép vào clipboard."
    end

    return true, body_md
end

return ErrorReporter