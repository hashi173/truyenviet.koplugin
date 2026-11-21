local root = "."
package.path = table.concat({
    root .. "/truyenviet.koplugin/?.lua",
    root .. "/truyenviet.koplugin/?/init.lua",
    package.path,
}, ";")

local output_path = "/tmp/truyenviet-epub-builder-test.epub"
local calls = {}

package.preload["ffi/archiver"] = function()
    return {
        Writer = {
            new = function()
                local writer = {}
                function writer:open(path)
                    self.path = path
                    local file = assert(io.open(path, "wb"))
                    file:write("temporary archive")
                    file:close()
                    return true
                end
                function writer:setZipCompression(method)
                    table.insert(calls, { type = "compression", method = method })
                    return true
                end
                function writer:addFileFromMemory(path, content)
                    table.insert(calls, { type = "file", path = path, content = content })
                    return true
                end
                function writer:close() end
                return writer
            end,
        },
    }
end

package.preload["truyenviet/helpers"] = function()
    return {
        trim = function(value)
            return tostring(value or ""):match("^%s*(.-)%s*$")
        end,
        escapeHtml = function(value)
            return tostring(value or ""):gsub("&", "&amp;"):gsub("<", "&lt;"):gsub(">", "&gt;"):gsub('"', "&quot;")
        end,
        stripTags = function(value)
            return tostring(value or "")
                :gsub("<script[^>]*>[%s%S]-</script>", "")
                :gsub("<[^>]+>", "")
                :gsub("&amp;", "&")
        end,
        stableHash = function()
            return "deadbeef"
        end,
    }
end

local Builder = require("truyenviet/epub_builder")
local tests_run = 0

local function assertEqual(expected, actual, message)
    tests_run = tests_run + 1
    if expected ~= actual then
        error(string.format("%s: expected %s, got %s", message, tostring(expected), tostring(actual)))
    end
end

local function findFile(path)
    for _, call in ipairs(calls) do
        if call.type == "file" and call.path == path then
            return call.content
        end
    end
end

os.remove(output_path)
os.remove(output_path .. ".part")

local builder, create_err = Builder.new(output_path, {
    title = "Truyện & thử nghiệm",
    url = "https://example.test/story",
    details = { author = "Tác giả" },
}, { id = "example", base_url = "https://example.test" })
assert(builder, create_err)
assertEqual("store", calls[1].method, "Stores mimetype without compression")
assertEqual("mimetype", calls[2].path, "Writes mimetype first")
assertEqual("application/epub+zip", calls[2].content, "Writes EPUB mimetype")
assertEqual("deflate", calls[3].method, "Enables compression after mimetype")

local added, add_err = builder:addChapter({
    title = "Chương 1",
    url = "https://example.test/chapter-1",
}, "<p>Nội dung &amp; an toàn<script>bad()</script></p>")
assert(added, add_err)

local saved, finish_err = builder:finish()
assertEqual(output_path, saved, finish_err or "Saves EPUB")
local chapter = findFile("OEBPS/text/chapter-0001.xhtml")
assert(chapter, "Adds chapter XHTML")
assertEqual(false, chapter:find("script", 1, true) ~= nil, "Removes script markup")
assertEqual(true, chapter:find("Nội dung &amp; an toàn", 1, true) ~= nil, "Escapes chapter text")
assert(findFile("OEBPS/nav.xhtml"), "Adds EPUB navigation")
local opf = findFile("OEBPS/content.opf")
assert(opf, "Adds EPUB package metadata")
assertEqual(true, opf:find('<meta property="dcterms:modified">%d%d%d%d%-%d%d%-%d%dT%d%d:%d%d:%d%dZ</meta>') ~= nil,
    "Has required dcterms:modified")
assertEqual(true, opf:find("<dc:language>vi</dc:language>", 1, true) ~= nil, "Declares Vietnamese")
assertEqual(true, opf:find("Truyện &amp; thử nghiệm", 1, true) ~= nil, "Escapes title in OPF")
assert(findFile("OEBPS/text/title.xhtml"), "Adds title page")
assertEqual(nil, findFile("OEBPS/text/cover.xhtml"), "No cover page without cover")

-- Control characters are invalid in XML 1.0 and must be removed.
calls = {}
builder = assert(Builder.new(output_path, { title = "T" }, {}))
assert(builder:addChapter({ title = "C\1" }, "<p>a\2b</p>", 1))
assert(builder:finish())
chapter = findFile("OEBPS/text/chapter-0001.xhtml")
assertEqual(false, chapter:find("[\1\2]") ~= nil, "Strips XML-invalid control chars")

-- Cover: accepted only when magic bytes identify a supported image.
local cover_path = "/tmp/truyenviet-epub-cover-test.bin"
local function writeCover(bytes)
    local f = assert(io.open(cover_path, "wb")); f:write(bytes); f:close()
end
writeCover("\137PNG\r\n\26\n" .. string.rep("x", 32))
calls = {}
builder = assert(Builder.new(output_path, { title = "T" }, {}, { cover_path = cover_path }))
assert(builder:addChapter({ title = "C" }, "<p>x</p>", 1))
assert(builder:finish())
assert(findFile("OEBPS/images/cover.png"), "Adds PNG cover image")
assert(findFile("OEBPS/text/cover.xhtml"), "Adds cover page")
opf = findFile("OEBPS/content.opf")
assertEqual(true, opf:find('properties="cover-image"', 1, true) ~= nil, "Marks cover-image in manifest")

writeCover("<html>not an image</html>")
calls = {}
builder = assert(Builder.new(output_path, { title = "T" }, {}, { cover_path = cover_path }))
assert(builder:addChapter({ title = "C" }, "<p>x</p>", 1))
assert(builder:finish())
assertEqual(nil, findFile("OEBPS/text/cover.xhtml"), "Rejects non-image cover")
os.remove(cover_path)

-- finish() without chapters must not leave files behind.
calls = {}
builder = assert(Builder.new(output_path .. ".empty", { title = "T" }, {}))
assertEqual(nil, (builder:finish()), "Refuses empty EPUB")
assertEqual(nil, io.open(output_path .. ".empty.part", "rb"), "Removes .part for empty EPUB")

os.remove(output_path)
os.remove(output_path .. ".part")

print(string.format("EPUB builder tests passed: %d assertions", tests_run))
