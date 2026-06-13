local root = "."
package.path = table.concat({
    root .. "/truyenviet.koplugin/?.lua",
    root .. "/truyenviet.koplugin/?/init.lua",
    package.path,
}, ";")

local output_path = "/tmp/truyenviet-document-builder-test.html"

package.preload["ffi/archiver"] = function()
    return {
        Writer = {
            new = function()
                return {
                    open = function()
                        return true
                    end,
                    setZipCompression = function() end,
                    addFileFromMemory = function()
                        return true
                    end,
                    close = function() end,
                }
            end,
        },
    }
end

package.preload["truyenviet/http_client"] = function()
    return {
        get = function()
            return "<html>blocked</html>", nil, {
                ["content-type"] = "text/html",
            }
        end,
    }
end

package.preload["truyenviet/storage"] = function()
    return {
        getChapterPath = function()
            return output_path
        end,
    }
end

package.preload["truyenviet/helpers"] = function()
    return {
        escapeHtml = function(value)
            return value
        end,
    }
end

package.preload["libs/libkoreader-lfs"] = function()
    return {
        attributes = function(path, attribute)
            local file = io.open(path, "rb")
            if not file then
                return nil
            end
            file:close()
            return attribute == "mode" and "file" or { mode = "file" }
        end,
    }
end

local Builder = require("truyenviet/document_builder")
local tests_run = 0

local function assertEqual(expected, actual, message)
    tests_run = tests_run + 1
    if expected ~= actual then
        error(string.format(
            "%s: expected %s, got %s",
            message,
            tostring(expected),
            tostring(actual)
        ))
    end
end

local function writeFile(path, content)
    local file = assert(io.open(path, "wb"))
    assert(file:write(content))
    file:close()
end

local function readFile(path)
    local file = assert(io.open(path, "rb"))
    local content = file:read("*a")
    file:close()
    return content
end

os.remove(output_path)
os.remove(output_path .. ".part")
writeFile(output_path, "old content")

local source = { kind = "text" }
local story = { title = "Story" }
local chapter = { title = "Chapter", url = "https://example.test/chapter" }

local existing = Builder:build(source, story, chapter, {
    title = "Ignored",
    content = "new content",
})
assertEqual(output_path, existing, "Returns existing chapter")
assertEqual("old content", readFile(output_path), "Keeps existing chapter")

local replaced = Builder:build(source, story, chapter, {
    title = "Updated",
    content = "new content",
}, true)
assertEqual(output_path, replaced, "Replaces chapter when forced")
assertEqual(
    true,
    readFile(output_path):find("new content", 1, true) ~= nil,
    "Writes replacement before swapping files"
)

os.remove(output_path)
local comic_path, comic_err = Builder:build(
    { kind = "comic" },
    story,
    chapter,
    {
        images = {
            { urls = { "https://example.test/page.jpg" } },
        },
        referer = "https://example.test/",
    }
)
assertEqual(nil, comic_path, "Rejects non-image comic payload")
assertEqual(
    true,
    tostring(comic_err):find("định dạng ảnh", 1, true) ~= nil,
    "Reports invalid comic image"
)

os.remove(output_path)
os.remove(output_path .. ".part")

print(string.format("Document builder tests passed: %d assertions", tests_run))
