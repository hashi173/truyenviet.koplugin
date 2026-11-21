-- Build a small, self-contained EPUB 3 from text chapters fetched by a source.
--
-- Source HTML is converted to escaped text paragraphs on purpose: markup from
-- the websites is inconsistent and would otherwise produce malformed XHTML.
-- The archive is written to `<output>.part` and renamed only by finish().
local Archiver = require("ffi/archiver")
local Util = require("truyenviet/helpers")

local EpubBuilder = {}
EpubBuilder.__index = EpubBuilder

local CONTAINER_XML = [[<?xml version="1.0" encoding="UTF-8"?>
<container version="1.0" xmlns="urn:oasis:names:tc:opendocument:xmlns:container">
  <rootfiles>
    <rootfile full-path="OEBPS/content.opf" media-type="application/oebps-package+xml"/>
  </rootfiles>
</container>]]

local STYLESHEET = [[body { line-height: 1.6; text-align: justify; }
h1 { text-align: center; page-break-after: avoid; }
p { margin: 0 0 0.85em; text-indent: 1.2em; }
.source { color: #666; font-size: 0.85em; text-align: center; text-indent: 0; }
.title-page { text-align: center; }
.title-page p { text-indent: 0; }
.cover { text-align: center; margin: 0; padding: 0; }
.cover img { max-width: 100%; max-height: 100%; }]]

-- Only EPUB 3 core media types; anything else (e.g. WebP on old readers) is
-- skipped rather than producing an archive some readers reject.
local IMAGE_TYPES = {
    { magic = "\255\216\255", ext = "jpg", media = "image/jpeg" },
    { magic = "\137PNG\r\n\26\n", ext = "png", media = "image/png" },
    { magic = "GIF87a", ext = "gif", media = "image/gif" },
    { magic = "GIF89a", ext = "gif", media = "image/gif" },
}
local MAX_COVER_BYTES = 5 * 1024 * 1024

-- XML 1.0 forbids most C0 control characters even when escaped.
local function stripInvalidXmlChars(value)
    return (value:gsub("[%z\1-\8\11\12\14-\31\127]", ""))
end

local function xml(value)
    return Util.escapeHtml(stripInvalidXmlChars(tostring(value or "")))
end

local function xhtmlDocument(title, body)
    return string.format([[<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE html>
<html xmlns="http://www.w3.org/1999/xhtml" xmlns:epub="http://www.idpf.org/2007/ops" xml:lang="vi" lang="vi">
  <head>
    <title>%s</title>
    <link rel="stylesheet" type="text/css" href="%s"/>
  </head>
  <body>
%s
  </body>
</html>]], xml(title), "../stylesheet.css", body)
end

local function textParagraphs(content)
    local paragraphs = {}
    local text = Util.stripTags(content or "")
    for paragraph in text:gmatch("[^\n]+") do
        paragraph = Util.trim(paragraph)
        if paragraph ~= "" then
            table.insert(paragraphs, "    <p>" .. xml(paragraph) .. "</p>")
        end
    end
    return paragraphs
end

local function chapterXhtml(title, source_url, content)
    local paragraphs = textParagraphs(content)
    if #paragraphs == 0 then
        table.insert(paragraphs, "    <p>(Nội dung chương trống.)</p>")
    end
    local body = { "    <h1>" .. xml(title) .. "</h1>" }
    if source_url and source_url ~= "" then
        table.insert(body, '    <p class="source">' .. xml(source_url) .. "</p>")
    end
    table.insert(body, table.concat(paragraphs, "\n"))
    return xhtmlDocument(title, table.concat(body, "\n"))
end

local function titlePageXhtml(story)
    local details = story.details or {}
    local body = {
        '    <section class="title-page" epub:type="titlepage">',
        "    <h1>" .. xml(story.title or "Truyện Việt") .. "</h1>",
    }
    if details.author and details.author ~= "" then
        table.insert(body, "    <p>Tác giả: " .. xml(details.author) .. "</p>")
    end
    table.insert(body, "    </section>")
    if details.description and details.description ~= "" then
        local paragraphs = textParagraphs(details.description)
        if #paragraphs > 0 then
            table.insert(body, table.concat(paragraphs, "\n"))
        end
    end
    return xhtmlDocument(story.title or "Truyện Việt", table.concat(body, "\n"))
end

local function coverXhtml(image_href)
    return xhtmlDocument("Bìa", string.format(
        '    <div class="cover"><img src="../%s" alt="Bìa"/></div>', image_href))
end

--- Detect a supported image type from its magic bytes.
function EpubBuilder.detectImage(bytes)
    if type(bytes) ~= "string" then return nil end
    for _, kind in ipairs(IMAGE_TYPES) do
        if bytes:sub(1, #kind.magic) == kind.magic then
            return kind
        end
    end
end

local function readCover(path)
    if type(path) ~= "string" or path == "" then return nil end
    local file = io.open(path, "rb")
    if not file then return nil end
    local bytes = file:read(MAX_COVER_BYTES + 1)
    file:close()
    if not bytes or #bytes == 0 or #bytes > MAX_COVER_BYTES then return nil end
    local kind = EpubBuilder.detectImage(bytes)
    if not kind then return nil end
    return bytes, kind
end

local function add(writer, path, content, mtime)
    if writer:addFileFromMemory(path, content, mtime) then
        return true
    end
    return nil, writer.err or ("Không thể ghi mục EPUB: " .. path)
end

--- Create a builder.
-- @param output_path final .epub path
-- @param story  { title, url, details = { author, description } }
-- @param source { id, base_url }
-- @param opts   { cover_path = local image file (optional) }
function EpubBuilder.new(output_path, story, source, opts)
    if type(output_path) ~= "string" or output_path == "" then
        return nil, "Đường dẫn EPUB không hợp lệ"
    end
    opts = opts or {}

    local self = setmetatable({
        output_path = output_path,
        part_path = output_path .. ".part",
        story = story or {},
        source = source or {},
        chapters = {},
        mtime = os.time(),
    }, EpubBuilder)
    os.remove(self.part_path)

    self.writer = Archiver.Writer:new{}
    if not self.writer:open(self.part_path, "epub") then
        local err = self.writer.err
        self:abort()
        return nil, err or "Không thể tạo tệp EPUB tạm"
    end

    local function fail(err)
        self:abort()
        return nil, err
    end

    -- OCF: "mimetype" must be the first entry and stored uncompressed.
    if not self.writer:setZipCompression("store") then
        return fail(self.writer.err or "Không thể đặt chế độ nén EPUB")
    end
    local ok, err = add(self.writer, "mimetype", "application/epub+zip", self.mtime)
    if not ok then return fail(err) end
    if not self.writer:setZipCompression("deflate") then
        return fail(self.writer.err or "Không thể đặt chế độ nén EPUB")
    end

    ok, err = add(self.writer, "META-INF/container.xml", CONTAINER_XML, self.mtime)
    if ok then ok, err = add(self.writer, "OEBPS/stylesheet.css", STYLESHEET, self.mtime) end
    if not ok then return fail(err) end

    local cover_bytes, cover_kind = readCover(opts.cover_path)
    if cover_bytes then
        local image_href = "images/cover." .. cover_kind.ext
        ok, err = add(self.writer, "OEBPS/" .. image_href, cover_bytes, self.mtime)
        if ok then ok, err = add(self.writer, "OEBPS/text/cover.xhtml", coverXhtml(image_href), self.mtime) end
        if not ok then return fail(err) end
        self.cover = { href = image_href, media = cover_kind.media }
    end

    ok, err = add(self.writer, "OEBPS/text/title.xhtml", titlePageXhtml(self.story), self.mtime)
    if not ok then return fail(err) end
    return self
end

function EpubBuilder:addChapter(chapter, payload, index)
    if not self.writer then
        return nil, "Trình tạo EPUB đã đóng"
    end
    index = index or (#self.chapters + 1)
    local title = (type(payload) == "table" and payload.title) or (chapter and chapter.title)
        or ("Chương " .. tostring(index))
    title = Util.stripTags(title)
    local content = type(payload) == "table" and payload.content or payload
    local source_url = (type(payload) == "table" and payload.url) or (chapter and chapter.url) or ""
    local filename = string.format("text/chapter-%04d.xhtml", index)
    local ok, err = add(self.writer, "OEBPS/" .. filename, chapterXhtml(title, source_url, content), self.mtime)
    if not ok then
        return nil, err
    end
    table.insert(self.chapters, { title = title, href = filename })
    return true
end

local function buildNavigation(chapters, title)
    local items = {}
    for _, chapter in ipairs(chapters) do
        table.insert(items, string.format('        <li><a href="%s">%s</a></li>', chapter.href, xml(chapter.title)))
    end
    return string.format([[<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE html>
<html xmlns="http://www.w3.org/1999/xhtml" xmlns:epub="http://www.idpf.org/2007/ops" xml:lang="vi" lang="vi">
  <head><title>Mục lục</title></head>
  <body>
    <nav epub:type="toc" id="toc">
      <h1>%s</h1>
      <ol>
%s
      </ol>
    </nav>
  </body>
</html>]], xml(title), table.concat(items, "\n"))
end

function EpubBuilder:buildPackage()
    local title = self.story.title or "Truyện Việt"
    local identifier = "urn:truyenviet:" .. Util.stableHash((self.story.url or title) .. "|" .. (self.source.id or ""))
    local modified = os.date("!%Y-%m-%dT%H:%M:%SZ", self.mtime)

    local manifest = {
        '    <item id="nav" href="nav.xhtml" media-type="application/xhtml+xml" properties="nav"/>',
        '    <item id="css" href="stylesheet.css" media-type="text/css"/>',
        '    <item id="title-page" href="text/title.xhtml" media-type="application/xhtml+xml"/>',
    }
    local spine = {}
    local cover_meta = ""
    if self.cover then
        table.insert(manifest, string.format(
            '    <item id="cover-image" href="%s" media-type="%s" properties="cover-image"/>',
            self.cover.href, self.cover.media))
        table.insert(manifest, '    <item id="cover" href="text/cover.xhtml" media-type="application/xhtml+xml"/>')
        table.insert(spine, '    <itemref idref="cover" linear="no"/>')
        -- EPUB 2 hint, still used by some readers for thumbnails.
        cover_meta = '\n    <meta name="cover" content="cover-image"/>'
    end
    table.insert(spine, '    <itemref idref="title-page"/>')
    for index, chapter in ipairs(self.chapters) do
        table.insert(manifest, string.format(
            '    <item id="chapter-%d" href="%s" media-type="application/xhtml+xml"/>', index, chapter.href))
        table.insert(spine, string.format('    <itemref idref="chapter-%d"/>', index))
    end

    return string.format([[<?xml version="1.0" encoding="UTF-8"?>
<package xmlns="http://www.idpf.org/2007/opf" unique-identifier="book-id" version="3.0" xml:lang="vi">
  <metadata xmlns:dc="http://purl.org/dc/elements/1.1/">
    <dc:identifier id="book-id">%s</dc:identifier>
    <dc:title>%s</dc:title>
    <dc:creator>%s</dc:creator>
    <dc:language>vi</dc:language>
    <dc:source>%s</dc:source>
    <dc:publisher>Truyện Việt (KOReader)</dc:publisher>
    <meta property="dcterms:modified">%s</meta>%s
  </metadata>
  <manifest>
%s
  </manifest>
  <spine>
%s
  </spine>
</package>]], xml(identifier), xml(title), xml((self.story.details or {}).author or "Không rõ"),
        xml(self.story.url or self.source.base_url or ""), modified, cover_meta,
        table.concat(manifest, "\n"), table.concat(spine, "\n"))
end

function EpubBuilder:finish()
    if not self.writer then
        return nil, "Trình tạo EPUB đã đóng"
    end
    if #self.chapters == 0 then
        self:abort()
        return nil, "Không có chương nào để đóng gói EPUB"
    end

    local title = self.story.title or "Truyện Việt"
    local ok, err = add(self.writer, "OEBPS/nav.xhtml", buildNavigation(self.chapters, title), self.mtime)
    if ok then ok, err = add(self.writer, "OEBPS/content.opf", self:buildPackage(), self.mtime) end
    self.writer:close()
    self.writer = nil
    if not ok then
        os.remove(self.part_path)
        return nil, err
    end

    local renamed, rename_err = os.rename(self.part_path, self.output_path)
    if not renamed then
        -- Some filesystems refuse to rename over an existing file; the caller
        -- has already confirmed overwriting at this point.
        os.remove(self.output_path)
        renamed, rename_err = os.rename(self.part_path, self.output_path)
    end
    if not renamed then
        os.remove(self.part_path)
        return nil, "Không thể hoàn tất EPUB: " .. tostring(rename_err)
    end
    return self.output_path
end

function EpubBuilder:abort()
    if self.writer then
        self.writer:close()
        self.writer = nil
    end
    os.remove(self.part_path)
end

return EpubBuilder
