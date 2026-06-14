local Builder = require("truyenviet/document_builder")
local Storage = require("truyenviet/storage")

local ChapterDownloader = {}

function ChapterDownloader:listPending(source, story, chapters)
    local pending = {}
    for _, chapter in ipairs(chapters or {}) do
        if not Storage:isDownloaded(source, story, chapter) then
            table.insert(pending, chapter)
        end
    end
    return pending
end

function ChapterDownloader:cleanupPartials(source, story, chapters)
    for _, chapter in ipairs(chapters or {}) do
        os.remove(Storage:getChapterPath(source, story, chapter) .. ".part")
    end
end

function ChapterDownloader:download(source, story, chapters)
    local result = {
        downloaded = 0,
        skipped = 0,
        errors = {},
    }

    for _, chapter in ipairs(chapters or {}) do
        if Storage:isDownloaded(source, story, chapter) then
            result.skipped = result.skipped + 1
        else
            local ok, payload, fetch_err = pcall(
                source.getChapter,
                source,
                chapter
            )
            if not ok then
                fetch_err = payload
                payload = nil
            end

            local path
            local build_err
            if payload then
                ok, path, build_err = pcall(
                    Builder.build,
                    Builder,
                    source,
                    story,
                    chapter,
                    payload
                )
                if not ok then
                    build_err = path
                    path = nil
                end
            end

            if path then
                result.downloaded = result.downloaded + 1
            else
                os.remove(Storage:getChapterPath(source, story, chapter) .. ".part")
                table.insert(result.errors, string.format(
                    "%s: %s",
                    chapter.title,
                    tostring(fetch_err or build_err or "lỗi không xác định")
                ))
            end
        end
        collectgarbage()
    end

    return result
end

return ChapterDownloader
