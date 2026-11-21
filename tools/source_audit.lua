-- Live source audit: runs the plugin's real adapters against the real
-- websites, one small request chain per source, and prints a status table.
--
-- Usage (WSL/Linux with KOReader installed):
--   cd /usr/lib/koreader && HOME=/tmp/tv-audit-home \
--     ./luajit /mnt/d/Project/truyenfull/tools/source_audit.lua [source_id ...]
--
-- It never retries around Cloudflare/CAPTCHA/login: such responses are
-- reported as BLOCKED.  It uses adapter default base URLs (isolated HOME), so
-- a user's custom domain settings are neither read nor modified.
local plugin_dir = (arg[0]:match("^(.*)/tools/[^/]+$") or ".") .. "/truyenviet.koplugin"

require("setupkoenv")
package.path = plugin_dir .. "/?.lua;" .. package.path

G_defaults = require("luadefaults"):open()
local DataStorage = require("datastorage")
local LuaSettings = require("luasettings")
G_reader_settings = LuaSettings:open(DataStorage:getDataDir() .. "/settings.reader.lua")

local Http = require("truyenviet/http_client")
local Registry = require("truyenviet/source_registry")

local SEARCH_QUERY = os.getenv("AUDIT_QUERY") or "tiên"
local MAX_CHAPTER_TRIES = 2

local IMAGE_MAGIC = {
    { "\255\216\255", "jpg" }, { "\137PNG", "png" }, { "GIF8", "gif" },
    { "RIFF", "webp" }, { "\0\0\0", "avif/heic" },
}
local function imageKind(bytes)
    if type(bytes) ~= "string" or #bytes < 12 then return nil end
    for _, m in ipairs(IMAGE_MAGIC) do
        if bytes:sub(1, #m[1]) == m[1] then return m[2] end
    end
end

local function classify(err)
    local text = tostring(err or "")
    if text:find("Cloudflare", 1, true) or text:find("403", 1, true) then return "BLOCKED" end
    if text:lower():find("đăng nhập", 1, true) or text:lower():find("login", 1, true) then return "LOGIN" end
    return "FAIL"
end

local function step(fn)
    local started = os.clock()
    local ok, a, b = pcall(fn)
    local elapsed = os.clock() - started
    if not ok then return nil, "lỗi Lua: " .. tostring(a), elapsed end
    return a, b, elapsed
end

local function firstStories(result)
    if type(result) ~= "table" then return {} end
    return result.stories or result.books or (result[1] and result) or {}
end

local function fetchImage(url, headers)
    if not url then return nil, "không có URL" end
    local body, err = Http:get(url, headers)
    if not body then return nil, err end
    local kind = imageKind(body)
    if not kind then return nil, "không phải ảnh (" .. #body .. " byte)" end
    return kind .. " " .. #body .. "B"
end

local function firstImageUrl(image)
    if type(image) == "string" then return image end
    if type(image) ~= "table" then return nil end
    return image.url or (image.urls and image.urls[1])
end

local function auditStorySource(source)
    local r = { id = source.id, kind = source.kind }

    -- 1. listing
    local listing, err
    if source.getCompleted then
        listing, err = step(function() return source:getCompleted(1) end)
    elseif source.getHome then
        listing, err = step(function() return source.getHome() end)
    end
    local stories = firstStories(listing)
    r.listing = #stories > 0 and ("OK " .. #stories) or (classify(err) .. ": " .. tostring(err or "0 truyện"))

    -- 2. search
    if source.search then
        local found, serr = step(function() return source:search(SEARCH_QUERY) end)
        local list = firstStories(found)
        r.search = #list > 0 and ("OK " .. #list) or (found and "EMPTY" or (classify(serr) .. ": " .. tostring(serr)))
        if #stories == 0 then stories = list end
    else
        r.search = "N/A"
    end

    local story = stories[1]
    if not story then
        r.detail, r.chapters, r.chapter, r.image = "SKIP", "SKIP", "SKIP", "SKIP"
        return r
    end
    r.sample = story.title

    -- 3. details
    if source.getStoryDetails then
        local details, derr = step(function() return source:getStoryDetails(story) end)
        if type(details) == "table" then
            story.details = details
            r.detail = "OK" .. (details.author and (" (" .. details.author .. ")") or "")
        else
            r.detail = classify(derr) .. ": " .. tostring(derr)
        end
    else
        r.detail = "N/A"
    end

    -- 4. chapter list (try up to 4 stories in listing if the first has 0 chapters)
    local page, perr
    local chapters = {}
    for sidx = 1, math.min(#stories, 4) do
        local cand = stories[sidx]
        page, perr = step(function() return source:getStoryPage(cand, 1) end)
        local list = type(page) == "table" and page.chapters or {}
        if #list > 0 then
            story = cand
            chapters = list
            r.sample = story.title
            break
        end
    end
    r.chapters = #chapters > 0 and ("OK " .. #chapters .. (page.total_pages and page.total_pages > 1
        and ("/" .. page.total_pages .. "tr") or "")) or (classify(perr) .. ": " .. tostring(perr or "0 chương"))

    -- 5. chapter content / images
    local payload, cerr
    for index = 1, math.min(#chapters, MAX_CHAPTER_TRIES) do
        payload, cerr = step(function() return source:getChapter(chapters[index]) end)
        if payload then break end
    end
    if type(payload) == "table" and payload.images then
        r.chapter = "OK " .. #payload.images .. " ảnh"
        local headers = source.getImageHeaders and source:getImageHeaders(payload) or
            (payload.referer and { Referer = payload.referer }) or nil
        local img, ierr = fetchImage(firstImageUrl(payload.images[1]), headers)
        r.image = img and ("OK " .. img) or (classify(ierr) .. ": " .. tostring(ierr))
    elseif payload then
        local content = type(payload) == "table" and payload.content or payload
        local text = tostring(content or ""):gsub("<[^>]+>", ""):gsub("%s+", " ")
        r.chapter = #text > 200 and ("OK " .. #text .. " ký tự") or ("NGẮN " .. #text .. " ký tự")
    elseif #chapters > 0 then
        r.chapter = classify(cerr) .. ": " .. tostring(cerr)
    else
        r.chapter = "SKIP"
    end

    -- 6. cover (listing first, then details), encoded like CoverCache does
    local cover_url = story.cover_url or (story.details and story.details.cover_url)
    if cover_url and cover_url ~= "" then
        local headers = source.getCoverHeaders and source:getCoverHeaders() or nil
        local img, ierr = fetchImage((cover_url:gsub(" ", "%%20")), headers)
        r.cover = img and ("OK " .. img) or (classify(ierr) .. ": " .. tostring(ierr))
    else
        r.cover = "không có"
    end
    return r
end

local function auditEbookSource(source)
    local r = { id = source.id, kind = source.kind, chapters = "N/A", chapter = "N/A", image = "N/A" }
    local listing, err
    if source.getCompleted then
        listing, err = step(function() return source:getCompleted(1) end)
    elseif source.getHome then
        listing, err = step(function() return source:getHome(1) end)
    end
    local books = firstStories(listing)
    if #books == 0 and source.getCategories and source.getCategoryBooks then
        local cats = step(function() return source:getCategories() end)
        if type(cats) == "table" and cats[1] then
            listing, err = step(function() return source:getCategoryBooks(cats[1], 1) end)
            books = firstStories(listing)
        end
    end
    r.listing = #books > 0 and ("OK " .. #books) or (classify(err) .. ": " .. tostring(err or "0 sách"))
    if source.search then
        local found, serr = step(function() return source:search(SEARCH_QUERY) end)
        local list = firstStories(found)
        r.search = #list > 0 and ("OK " .. #list) or (found and "EMPTY" or (classify(serr) .. ": " .. tostring(serr)))
        if #books == 0 then books = list end
    end
    local book = books[1]
    if book and source.getBookDetail then
        r.sample = book.title
        local detail, derr = step(function() return source:getBookDetail(book) end)
        if type(detail) == "table" then
            local formats = detail.formats or {}
            local has_pdf = detail.pdf_url or detail.pdf_download_url
            local has_audio = detail.audio_url or detail.audio_download_url
            r.detail = "OK" .. (#formats > 0 and (" " .. #formats .. " link") or "")
                .. (has_pdf and " pdf" or "") .. (has_audio and " audio" or "")
            if has_pdf and source.downloadPdf then
                local tmp_pdf = "/tmp/truyenviet-audit-" .. source.id .. ".pdf"
                os.remove(tmp_pdf)
                os.remove(tmp_pdf .. ".part")
                local saved, dl_err = step(function() return source:downloadPdf(detail, tmp_pdf) end)
                if saved then
                    local f = io.open(tmp_pdf, "rb")
                    local head = f and f:read(8) or ""
                    local sz = f and f:seek("end") or 0
                    if f then f:close() end
                    os.remove(tmp_pdf)
                    r.chapter = head:sub(1, 5) == "%PDF-" and ("OK PDF " .. math.floor(sz / 1024) .. "KB")
                        or ("BAD PDF: " .. head:gsub("[^%g ]", "?"))
                else
                    os.remove(tmp_pdf)
                    os.remove(tmp_pdf .. ".part")
                    r.chapter = classify(dl_err) .. ": " .. tostring(dl_err)
                end
            end
        else
            r.detail = classify(derr) .. ": " .. tostring(derr)
        end
    else
        r.detail = "SKIP"
    end
    if book and book.cover_url and book.cover_url ~= "" then
        local img, ierr = fetchImage(book.cover_url, source.getCoverHeaders and source:getCoverHeaders() or nil)
        r.cover = img and ("OK " .. img) or (classify(ierr) .. ": " .. tostring(ierr))
    else
        r.cover = "không có"
    end
    return r
end

local wanted = {}
for i = 1, #arg do wanted[arg[i]] = true end

local results = {}
for _, source in ipairs(Registry:listAll()) do
    if next(wanted) == nil or wanted[source.id] then
        io.stderr:write("auditing " .. source.id .. " (" .. source.base_url .. ")...\n")
        local ok, r = pcall(source.kind == "ebook" and auditEbookSource or auditStorySource, source)
        if not ok then r = { id = source.id, kind = source.kind, listing = "lỗi Lua: " .. tostring(r) } end
        r.base_url = source.base_url
        table.insert(results, r)
    end
end

local function cell(v) return (tostring(v or "-"):gsub("|", "/"):gsub("\n", " "):sub(1, 90)) end
print("| Nguồn | Loại | URL | Listing | Search | Chi tiết | DS chương | Nội dung | Ảnh chương | Bìa | Mẫu |")
print("|---|---|---|---|---|---|---|---|---|---|---|")
for _, r in ipairs(results) do
    print(string.format("| %s | %s | %s | %s | %s | %s | %s | %s | %s | %s | %s |",
        cell(r.id), cell(r.kind), cell(r.base_url), cell(r.listing), cell(r.search), cell(r.detail),
        cell(r.chapters), cell(r.chapter), cell(r.image), cell(r.cover), cell(r.sample or r.note)))
end
