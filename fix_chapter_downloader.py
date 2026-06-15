import re

with open("truyenviet.koplugin/truyenviet/chapter_downloader.lua", "r", encoding="utf-8") as f:
    text = f.read()

new_download = """function ChapterDownloader:download(source, story, chapters)
    local result = {
        downloaded = 0,
        skipped = 0,
        errors = {},
    }

    local pending = {}
    for _, chapter in ipairs(chapters or {}) do
        if Storage:isDownloaded(source, story, chapter) then
            result.skipped = result.skipped + 1
        else
            table.insert(pending, chapter)
        end
    end

    local Http = require("truyenviet/http_client")
    local old_get = Http.get

    local function downloadOne(chapter)
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
        collectgarbage()
    end

    local ok, copas = pcall(require, "copas")
    if source.kind ~= "comic" and ok and copas and copas.addthread then
        Http.get = function(self, url, headers)
            return self:requestAsync("GET", url, nil, headers)
        end

        local active_downloads = 0
        local max_concurrent = 4
        
        for _, chapter in ipairs(pending) do
            while active_downloads >= max_concurrent do
                copas.step()
            end
            
            active_downloads = active_downloads + 1
            copas.addthread(function()
                downloadOne(chapter)
                active_downloads = active_downloads - 1
            end)
        end
        
        while active_downloads > 0 do
            copas.step()
        end
        
        Http.get = old_get
    else
        for _, chapter in ipairs(pending) do
            downloadOne(chapter)
        end
    end

    return result
end"""

text = re.sub(r"function ChapterDownloader:download\(source, story, chapters\).*?return result\nend", new_download, text, flags=re.DOTALL)

with open("truyenviet.koplugin/truyenviet/chapter_downloader.lua", "w", encoding="utf-8") as f:
    f.write(text)
