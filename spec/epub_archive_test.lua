local root = "."
package.path = table.concat({
    root .. "/truyenviet.koplugin/?.lua",
    root .. "/truyenviet.koplugin/?/init.lua",
    "/usr/lib/koreader/?.lua",
    "/usr/lib/koreader/common/?.lua",
    "/usr/lib/koreader/frontend/?.lua",
    package.path,
}, ";")
package.cpath = "/usr/lib/koreader/?.so;/usr/lib/koreader/common/?.so;" .. package.cpath

local path = "/tmp/truyenviet-epub-integration-test.epub"
os.remove(path)
os.remove(path .. ".part")

require("ffi/loadlib")
-- Smallest valid PNG (1x1) to exercise the cover path with real Archiver.
local cover_path = "/tmp/truyenviet-epub-integration-cover.png"
local png = "\137PNG\r\n\26\n\0\0\0\13IHDR\0\0\0\1\0\0\0\1\8\6\0\0\0\31\21\196\137"
    .. "\0\0\0\13IDATx\156c\248\15\0\0\1\1\0\5\24\216N\0\0\0\0IEND\174B`\130"
local cover = assert(io.open(cover_path, "wb")); cover:write(png); cover:close()

local Builder = require("truyenviet/epub_builder")
local builder, create_err = Builder.new(path, {
    title = "EPUB kiểm thử & <ký tự>",
    url = "https://example.test/story",
    details = { author = "Tác giả kiểm thử", description = "<p>Giới thiệu ngắn.</p>" },
}, { id = "test", base_url = "https://example.test" }, { cover_path = cover_path })
os.remove(cover_path)
assert(builder, create_err)
assert(builder:addChapter({ title = "Chương 1", url = "https://example.test/1" }, "<p>Nội dung chương một.</p>"))
assert(builder:addChapter({ title = "Chương 2", url = "https://example.test/2" }, "<p>Nội dung chương hai.</p>"))
local saved, finish_err = builder:finish()
assert(saved, finish_err)

local file = assert(io.open(path, "rb"))
local signature = file:read(4)
file:close()
assert(signature == "PK\003\004", "EPUB must be a ZIP archive")
print("EPUB archive integration test passed: " .. path)
