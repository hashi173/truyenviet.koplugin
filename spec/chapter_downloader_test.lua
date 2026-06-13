local root = "."
package.path = table.concat({
    root .. "/truyenviet.koplugin/?.lua",
    root .. "/truyenviet.koplugin/?/init.lua",
    package.path,
}, ";")

local downloaded = {
    existing = true,
}

package.preload["truyenviet/storage"] = function()
    return {
        isDownloaded = function(_, _, _, chapter)
            return downloaded[chapter.url] == true
        end,
        getChapterPath = function(_, _, _, chapter)
            return "unused-" .. chapter.url
        end,
    }
end

package.preload["truyenviet/document_builder"] = function()
    return {
        build = function(_, _, _, chapter)
            if chapter.url == "build-fail" then
                return nil, "build failed"
            end
            downloaded[chapter.url] = true
            return "downloaded-" .. chapter.url
        end,
    }
end

local ChapterDownloader = require("truyenviet/chapter_downloader")
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

local source = {
    getChapter = function(_, chapter)
        if chapter.url == "fetch-fail" then
            return nil, "fetch failed"
        end
        return { content = chapter.title }
    end,
}
local story = { title = "Demo", url = "story" }
local chapters = {
    { title = "Đã có", url = "existing" },
    { title = "Tải được", url = "success" },
    { title = "Lỗi tải", url = "fetch-fail" },
    { title = "Lỗi dựng", url = "build-fail" },
}

local pending = ChapterDownloader:listPending(source, story, chapters)
assertEqual(3, #pending, "Pending chapter count")

local result = ChapterDownloader:download(source, story, chapters)
assertEqual(1, result.downloaded, "Downloaded chapter count")
assertEqual(1, result.skipped, "Skipped chapter count")
assertEqual(2, #result.errors, "Failed chapter count")
assertEqual(true, downloaded.success, "Successful chapter is persisted")

print(string.format(
    "Chapter downloader tests passed: %d assertions",
    tests_run
))
