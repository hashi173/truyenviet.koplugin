-- Shared pipeline for "download whole story as one file" exports.
--
-- It owns the chapter loop (fetch, per-chapter error capture, progress,
-- cancellation) and delegates file layout to a writer object:
--
--   writer:addChapter(chapter, payload, index) -> true | nil, err
--   writer:finish()                            -> path | nil, err
--   writer:abort()                             -- remove temporary output
--
-- Writers (HtmlBundleBuilder, EpubBuilder) must write to a `.part` file and
-- only rename on finish(), so an aborted export never leaves a broken file.
local BundleExporter = {}

local MAX_REPORTED_ERRORS = 5

local function chapterLabel(chapter, index)
    local title = type(chapter) == "table" and chapter.title or nil
    if type(title) == "string" and title ~= "" then
        return title
    end
    return "Chương " .. tostring(index)
end

local function hasContent(payload)
    if type(payload) == "string" then
        return payload:find("%S") ~= nil
    end
    if type(payload) == "table" and type(payload.content) == "string" then
        return payload.content:find("%S") ~= nil
    end
    return false
end

local function fetchChapter(source, chapter)
    local ok, payload, err = pcall(source.getChapter, source, chapter)
    if not ok then
        return nil, tostring(payload)
    end
    if not hasContent(payload) then
        return nil, err or "Nội dung chương trống"
    end
    return payload
end

--- Run an export.
-- @param opts.source    source adapter with getChapter(chapter)
-- @param opts.chapters  ordered list of chapters
-- @param opts.writer    writer object (see header)
-- @param opts.progress  optional function(text); called before each fetch so
--                       a coroutine driver can yield and repaint the UI
-- @param opts.is_cancelled optional function() -> boolean
-- @return result table:
--   { path, successes, failures, total, errors = {...} }   on success
--   { error = "...", cancelled = true|nil }                  on failure
function BundleExporter.run(opts)
    local source, chapters, writer = opts.source, opts.chapters or {}, opts.writer
    local total = #chapters
    local successes, failures = 0, 0
    local errors = {}

    for index, chapter in ipairs(chapters) do
        if opts.is_cancelled and opts.is_cancelled() then
            writer:abort()
            return { error = "Đã dừng theo yêu cầu", cancelled = true }
        end
        if opts.progress then
            opts.progress(string.format("Đang gom %d/%d chương...", index, total))
        end

        local payload, fetch_err = fetchChapter(source, chapter)
        if payload then
            local added, add_err = writer:addChapter(chapter, payload, index)
            if not added then
                -- A writer error means the archive itself is unusable.
                writer:abort()
                return { error = add_err or "Không thể ghi chương vào tệp" }
            end
            successes = successes + 1
        else
            failures = failures + 1
            if #errors < MAX_REPORTED_ERRORS then
                table.insert(errors, chapterLabel(chapter, index) .. ": " .. tostring(fetch_err))
            end
        end
    end

    if opts.is_cancelled and opts.is_cancelled() then
        writer:abort()
        return { error = "Đã dừng theo yêu cầu", cancelled = true }
    end
    if successes == 0 then
        writer:abort()
        local reason = errors[1] and ("\n" .. table.concat(errors, "\n")) or ""
        return { error = "Không tải được chương nào." .. reason }
    end

    local path, finish_err = writer:finish()
    if not path then
        return { error = finish_err or "Không thể hoàn tất tệp" }
    end
    return {
        path = path,
        successes = successes,
        failures = failures,
        total = total,
        errors = errors,
    }
end

--- Human readable summary for a successful result.
function BundleExporter.summary(result, label)
    local lines = {
        string.format("Đã tạo %s với %d/%d chương tại:", label, result.successes, result.total),
        result.path,
    }
    if result.failures > 0 then
        table.insert(lines, "")
        table.insert(lines, string.format("Không tải được %d chương:", result.failures))
        for _, line in ipairs(result.errors or {}) do
            table.insert(lines, line)
        end
        if result.failures > #(result.errors or {}) then
            table.insert(lines, "...")
        end
    end
    return table.concat(lines, "\n")
end

return BundleExporter
