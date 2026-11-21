-- Unit tests for the shared whole-story export pipeline and HTML writer.
local root = "."
package.path = table.concat({
    root .. "/truyenviet.koplugin/?.lua",
    package.path,
}, ";")

package.preload["truyenviet/helpers"] = function()
    return {
        escapeHtml = function(value)
            return (tostring(value or ""):gsub("&", "&amp;"):gsub("<", "&lt;"):gsub(">", "&gt;"):gsub('"', "&quot;"))
        end,
        sanitizeContentHtml = function(value)
            return (tostring(value or ""):gsub("<script[^>]*>[%s%S]-</script>", ""))
        end,
    }
end

local BundleExporter = require("truyenviet/bundle_exporter")
local HtmlBundleBuilder = require("truyenviet/html_bundle_builder")

local tests_run = 0
local function assertEqual(expected, actual, message)
    tests_run = tests_run + 1
    if expected ~= actual then
        error(string.format("%s: expected %s, got %s", message, tostring(expected), tostring(actual)), 2)
    end
end

local function fakeWriter()
    local writer = { added = {}, finished = false, aborted = false }
    function writer:addChapter(chapter, payload, index)
        table.insert(self.added, { chapter = chapter, payload = payload, index = index })
        return true
    end
    function writer:finish() self.finished = true; return "/tmp/out.file" end
    function writer:abort() self.aborted = true end
    return writer
end

local source = {}
function source:getChapter(chapter)
    if chapter.mode == "throw" then error("network exploded") end
    if chapter.mode == "nil" then return nil, "HTTP 404" end
    if chapter.mode == "empty" then return { content = "   " } end
    return { content = "<p>" .. chapter.title .. "</p>" }
end

-- Mixed success/failure: errors are captured per chapter, export continues.
local writer = fakeWriter()
local progress = {}
local result = BundleExporter.run({
    source = source,
    chapters = {
        { title = "Một" },
        { title = "Hai", mode = "throw" },
        { title = "Ba", mode = "nil" },
        { title = "Bốn", mode = "empty" },
        { title = "Năm" },
    },
    writer = writer,
    progress = function(text) table.insert(progress, text) end,
})
assertEqual("/tmp/out.file", result.path, "Finishes with partial success")
assertEqual(2, result.successes, "Counts successful chapters")
assertEqual(3, result.failures, "Counts failed chapters")
assertEqual(3, #result.errors, "Reports failed chapters")
assertEqual(true, result.errors[1]:find("network exploded", 1, true) ~= nil, "Captures thrown errors")
assertEqual(true, result.errors[2]:find("HTTP 404", 1, true) ~= nil, "Captures returned errors")
assertEqual(5, #progress, "Reports progress for each chapter")
assertEqual(5, writer.added[2].index, "Keeps original chapter index")
assertEqual(true, writer.finished, "Finishes writer")
assertEqual(true, BundleExporter.summary(result, "EPUB"):find("2/5", 1, true) ~= nil, "Summary shows counts")

-- All chapters failing must not produce a file.
writer = fakeWriter()
result = BundleExporter.run({ source = source, chapters = { { title = "X", mode = "nil" } }, writer = writer })
assertEqual(true, result.error ~= nil, "Fails when nothing downloaded")
assertEqual(true, writer.aborted, "Aborts writer when nothing downloaded")
assertEqual(false, writer.finished, "Does not finish empty export")

-- Cancellation aborts and removes temporary output.
writer = fakeWriter()
local calls = 0
result = BundleExporter.run({
    source = source,
    chapters = { { title = "A" }, { title = "B" }, { title = "C" } },
    writer = writer,
    is_cancelled = function() calls = calls + 1; return calls > 1 end,
})
assertEqual(true, result.cancelled, "Reports cancellation")
assertEqual(true, writer.aborted, "Aborts on cancellation")
assertEqual(1, #writer.added, "Stops fetching after cancellation")

-- Writer failure stops the export immediately.
writer = fakeWriter()
function writer:addChapter() return nil, "disk full" end
result = BundleExporter.run({ source = source, chapters = { { title = "A" }, { title = "B" } }, writer = writer })
assertEqual("disk full", result.error, "Propagates writer error")
assertEqual(true, writer.aborted, "Aborts on writer error")

-- HTML writer: streams to .part, escapes metadata, renames on finish.
local out = "/tmp/truyenviet-html-bundle-test.html"
os.remove(out); os.remove(out .. ".part")
local html = assert(HtmlBundleBuilder.new(out, {
    title = "Truyện <&> thử",
    details = { author = "A & B", description = "Mô tả" },
}, { cover_filename = "cover.jpg" }))
local part = io.open(out .. ".part", "rb")
assertEqual(true, part ~= nil, "Writes to .part while building")
if part then part:close() end
assert(html:addChapter({ title = "Chương <1>" }, { content = "<p>Nội dung</p><script>bad()</script>" }, 1))
assertEqual(out, html:finish(), "Renames .part to final path")
local file = assert(io.open(out, "rb"))
local text = file:read("*a")
file:close()
assertEqual(true, text:find("Truyện &lt;&amp;&gt; thử", 1, true) ~= nil, "Escapes story title")
assertEqual(true, text:find("Chương &lt;1&gt;", 1, true) ~= nil, "Escapes chapter title")
assertEqual(false, text:find("bad()", 1, true) ~= nil, "Strips scripts")
assertEqual(true, text:find('src="cover.jpg"', 1, true) ~= nil, "References cover")
assertEqual(nil, io.open(out .. ".part", "rb"), "Removes .part after finish")
os.remove(out)

local aborted = assert(HtmlBundleBuilder.new(out, { title = "x" }))
aborted:abort()
assertEqual(nil, io.open(out .. ".part", "rb"), "Abort removes .part")
assertEqual(nil, io.open(out, "rb"), "Abort leaves no final file")

print(string.format("Bundle exporter tests passed: %d assertions", tests_run))
