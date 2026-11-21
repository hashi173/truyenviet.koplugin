-- Write a whole story into one HTML file, streaming chapter by chapter to a
-- `.part` file so memory use stays flat for long stories.
local Util = require("truyenviet/helpers")

local HtmlBundleBuilder = {}
HtmlBundleBuilder.__index = HtmlBundleBuilder

local STYLE = [[
body { font-family: serif; max-width: 800px; margin: auto; padding: 1em; }
.chapter { margin-bottom: 3em; padding-top: 1em; border-top: 1px solid #ccc; }
h2 { font-size: 1.2em; font-weight: bold; }
.cover { text-align: center; page-break-after: always; }
.cover img { max-width: 100%; height: auto; }
]]

local function esc(value)
    return Util.escapeHtml(value or "")
end

--- @param output_path final .html path
--- @param story       { title, details = { author, description } }
--- @param opts        { cover_filename = "cover.jpg" } (relative to output dir)
function HtmlBundleBuilder.new(output_path, story, opts)
    if type(output_path) ~= "string" or output_path == "" then
        return nil, "Đường dẫn HTML không hợp lệ"
    end
    opts = opts or {}
    story = story or {}
    local self = setmetatable({
        output_path = output_path,
        part_path = output_path .. ".part",
    }, HtmlBundleBuilder)

    os.remove(self.part_path)
    local file, err = io.open(self.part_path, "wb")
    if not file then
        return nil, "Không thể tạo tệp tạm: " .. tostring(err)
    end
    self.file = file

    local title = story.title or "Truyện Việt"
    local details = story.details or {}
    local parts = {
        '<!DOCTYPE html>\n<html lang="vi">\n<head>\n<meta charset="UTF-8">\n',
        "<title>", esc(title), "</title>\n<style>\n", STYLE, "</style>\n</head>\n<body>\n",
    }
    if opts.cover_filename then
        table.insert(parts, '<div class="cover"><img src="' .. esc(opts.cover_filename) .. '" alt=""/></div>\n')
    end
    table.insert(parts, "<h1>" .. esc(title) .. "</h1>\n")
    if details.author and details.author ~= "" then
        table.insert(parts, "<p><strong>Tác giả:</strong> " .. esc(details.author) .. "</p>\n")
    end
    if details.description and details.description ~= "" then
        table.insert(parts, "<div><strong>Giới thiệu:</strong><br/>"
            .. Util.sanitizeContentHtml(details.description) .. "</div><hr/>\n")
    end
    local ok, write_err = self:write(table.concat(parts))
    if not ok then
        self:abort()
        return nil, write_err
    end
    return self
end

function HtmlBundleBuilder:write(text)
    if not self.file then
        return nil, "Tệp HTML đã đóng"
    end
    local ok, err = self.file:write(text)
    if not ok then
        return nil, "Lỗi ghi tệp: " .. tostring(err)
    end
    return true
end

function HtmlBundleBuilder:addChapter(chapter, payload, index)
    local title = (type(payload) == "table" and payload.title) or (chapter and chapter.title)
        or ("Chương " .. tostring(index))
    local content = type(payload) == "table" and payload.content or payload
    return self:write(table.concat({
        '<div class="chapter">\n<h2>', esc(title), "</h2>\n",
        Util.sanitizeContentHtml(tostring(content or "")),
        "\n</div>\n",
    }))
end

function HtmlBundleBuilder:finish()
    local ok, err = self:write("</body>\n</html>\n")
    if not ok then
        self:abort()
        return nil, err
    end
    self.file:close()
    self.file = nil
    local renamed, rename_err = os.rename(self.part_path, self.output_path)
    if not renamed then
        -- Some filesystems refuse to rename over an existing file.
        os.remove(self.output_path)
        renamed, rename_err = os.rename(self.part_path, self.output_path)
    end
    if not renamed then
        os.remove(self.part_path)
        return nil, "Không thể hoàn tất HTML: " .. tostring(rename_err)
    end
    return self.output_path
end

function HtmlBundleBuilder:abort()
    if self.file then
        self.file:close()
        self.file = nil
    end
    os.remove(self.part_path)
end

return HtmlBundleBuilder
