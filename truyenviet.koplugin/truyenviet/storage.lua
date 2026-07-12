local DataStorage = require("datastorage")
local LuaSettings = require("luasettings")
local ffiutil = require("ffi/util")
local lfs = require("libs/libkoreader-lfs")
local ko_util = require("util")
local Util = require("truyenviet/helpers")

local Storage = {
    settings = nil,
    root_dir = nil,
    cache_dir = nil,
    disabled_sources = nil,
}

local function copyTable(value)
    local result = {}
    for key, item in pairs(type(value) == "table" and value or {}) do
        result[key] = item
    end
    return result
end

local function persistSetting(self, key, value)
    local previous = self.settings:readSetting(key)
    local ok, err = pcall(function()
        self.settings:saveSetting(key, value)
        self.settings:flush()
    end)
    if not ok then
        pcall(self.settings.saveSetting, self.settings, key, previous)
        return nil, tostring(err)
    end
    return true
end

function Storage:initialize()
    if self.settings then
        return
    end

    self.root_dir = ffiutil.joinPath(DataStorage:getFullDataDir(), "truyenviet")
    ko_util.makePath(self.root_dir)
    self.cache_dir = ffiutil.joinPath(self.root_dir, "cache")
    ko_util.makePath(self.cache_dir)
    self.settings = LuaSettings:open(
        ffiutil.joinPath(DataStorage:getSettingsDir(), "truyenviet.lua")
    )
    self.disabled_sources = {}
    local disabled_sources = self.settings:readSetting("disabled_sources", {})
    if type(disabled_sources) ~= "table" then
        disabled_sources = {}
    end
    for source_id, disabled in pairs(disabled_sources) do
        if disabled == true then
            self.disabled_sources[source_id] = true
        end
    end
end

function Storage:getRootDir()
    self:initialize()
    return self.root_dir
end

function Storage:getCoverCacheDir()
    self:initialize()
    local path = ffiutil.joinPath(self.cache_dir, "covers")
    ko_util.makePath(path)
    return path
end

function Storage:clearCoverCacheDir()
    local dir = self:getCoverCacheDir()
    local ok = pcall(function()
        for file in lfs.dir(dir) do
            if file ~= "." and file ~= ".." then
                local path = ffiutil.joinPath(dir, file)
                if lfs.attributes(path, "mode") == "file" then
                    os.remove(path)
                end
            end
        end
    end)
    return ok
end

function Storage:getCustomBaseUrl(source_id)
    self:initialize()
    local url = self.settings:readSetting("custom_url_" .. source_id)
    return type(url) == "string" and url ~= "" and url or nil
end

function Storage:setCustomBaseUrl(source_id, url)
    self:initialize()
    if url and url ~= "" then
        url = url:match("^%s*(.-)%s*$"):gsub("/+$", "")
        if url == "" then
            url = nil
        end
    end
    return persistSetting(self, "custom_url_" .. source_id, url)
end

function Storage:setFastMode(enabled)
    self:initialize()
    return persistSetting(self, "fast_mode", enabled == true)
end

function Storage:isSourceEnabled(source_id)
    self:initialize()
    return self.disabled_sources[source_id] ~= true
end

function Storage:setSourceEnabled(source_id, enabled)
    self:initialize()
    local was_disabled = self.disabled_sources[source_id] == true
    if enabled then
        self.disabled_sources[source_id] = nil
    else
        self.disabled_sources[source_id] = true
    end

    local saved = {}
    for id, disabled in pairs(self.disabled_sources) do
        if disabled == true then
            saved[id] = true
        end
    end

    local ok, err = pcall(function()
        self.settings:saveSetting("disabled_sources", saved)
        self.settings:flush()
    end)
    if not ok then
        self.disabled_sources[source_id] = was_disabled and true or nil
        return nil, tostring(err)
    end
    return true
end

function Storage:getStoryDir(source, story)
    self:initialize()
    local source_dir = ffiutil.joinPath(self.root_dir, source.id)
    local story_dir = ffiutil.joinPath(source_dir, Util.urlLeaf(story.url, "story"))
    ko_util.makePath(story_dir)
    return story_dir
end

function Storage:getChapterPath(source, story, chapter)
    local extension = source.kind == "comic" and ".cbz" or ".html"
    local filename = Util.urlLeaf(chapter.url, Util.safeName(chapter.title, "chapter"))
    return ffiutil.joinPath(self:getStoryDir(source, story), filename .. extension)
end

function Storage:isDownloaded(source, story, chapter)
    return lfs.attributes(self:getChapterPath(source, story, chapter), "mode") == "file"
end

function Storage:removeDownload(source, story, chapter)
    local path = self:getChapterPath(source, story, chapter)
    if lfs.attributes(path, "mode") == "file" then
        return os.remove(path)
    end
    return true
end

function Storage:removeAllDownloads()
    local path = self:getRootDir()
    if lfs.attributes(path, "mode") ~= "directory" then return true end

    local function rmdir_recursive(dir_path)
        for file in lfs.dir(dir_path) do
            if file ~= "." and file ~= ".." then
                local full_path = dir_path .. "/" .. file
                if lfs.attributes(full_path, "mode") == "directory" then
                    rmdir_recursive(full_path)
                else
                    os.remove(full_path)
                end
            end
        end
        lfs.rmdir(dir_path)
    end

    local ok, err = pcall(rmdir_recursive, path)
    -- Recreate the root directory after deletion
    lfs.mkdir(path)
    return ok, err
end

function Storage:getFavorites()
    self:initialize()
    local favorites = self.settings:readSetting("favorites", {})
    return type(favorites) == "table" and favorites or {}
end

function Storage:isFavorite(story)
    if not story or not story.source_id or not story.url then return false end
    return self:getFavorites()[story.source_id .. "|" .. story.url] ~= nil
end

local function favoriteRecord(story)
    return {
        source_id = story.source_id,
        title = story.title,
        url = story.url,
        cover_url = story.cover_url,
        kind = story.kind,
        details = story.details,
    }
end

function Storage:addFavorite(story)
    local favorites = copyTable(self:getFavorites())
    favorites[story.source_id .. "|" .. story.url] = favoriteRecord(story)
    return persistSetting(self, "favorites", favorites)
end

function Storage:updateFavorite(story)
    if self:isFavorite(story) then
        return self:addFavorite(story)
    end
    return true
end

function Storage:removeFavorite(story)
    local favorites = copyTable(self:getFavorites())
    favorites[story.source_id .. "|" .. story.url] = nil
    return persistSetting(self, "favorites", favorites)
end

-- Xóa tất cả file đã tải của một truyện (dùng cho xóa hết)
local function deleteStoryDownloads(self, story_record)
    local source_dir = ffiutil.joinPath(self.root_dir, story_record.source_id)
    local story_dir = ffiutil.joinPath(source_dir, Util.urlLeaf(story_record.url, "story"))
    if lfs.attributes(story_dir, "mode") ~= "directory" then return end
    local function rmdir(dir)
        for file in lfs.dir(dir) do
            if file ~= "." and file ~= ".." then
                local fp = dir .. "/" .. file
                if lfs.attributes(fp, "mode") == "directory" then
                    rmdir(fp)
                else
                    os.remove(fp)
                end
            end
        end
        lfs.rmdir(dir)
    end
    pcall(rmdir, story_dir)
end

function Storage:clearAllFavorites(with_downloads)
    self:initialize()
    if with_downloads then
        for _, story in pairs(self:getFavorites()) do
            if type(story) == "table" then
                pcall(deleteStoryDownloads, self, story)
            end
        end
    end
    return persistSetting(self, "favorites", {})
end

function Storage:listFavorites()
    local result = {}
    for _, story in pairs(self:getFavorites()) do
        if type(story) == "table"
                and type(story.title) == "string"
                and type(story.url) == "string"
                and type(story.source_id) == "string" then
            table.insert(result, story)
        end
    end
    table.sort(result, function(left, right)
        return left.title:lower() < right.title:lower()
    end)
    return result
end

function Storage:getHistory()
    self:initialize()
    local history = self.settings:readSetting("history", {})
    if type(history) ~= "table" then
        return {}
    end

    local valid_history = {}
    for _, item in ipairs(history) do
        if type(item) == "table"
                and type(item.story) == "table"
                and type(item.story.source_id) == "string"
                and type(item.story.title) == "string"
                and type(item.story.url) == "string"
                and type(item.chapter) == "table"
                and type(item.chapter.title) == "string"
                and type(item.chapter.url) == "string" then
            table.insert(valid_history, item)
        end
    end
    return valid_history
end

function Storage:saveHistory(story, chapter)
    local history = copyTable(self:getHistory())
    local existing_idx
    for i, item in ipairs(history) do
        if item.story.source_id == story.source_id and item.story.url == story.url then
            existing_idx = i
            break
        end
    end
    if existing_idx then
        table.remove(history, existing_idx)
    end
    
    local clean_story = favoriteRecord(story)
    table.insert(history, 1, {
        story = clean_story,
        chapter = {
            title = chapter.title,
            url = chapter.url,
        },
        time = os.time(),
    })
    
    while #history > 100 do
        table.remove(history)
    end
    
    return persistSetting(self, "history", history)
end

function Storage:removeHistory(story)
    local history = copyTable(self:getHistory())
    local existing_idx
    for i, item in ipairs(history) do
        if item.story.source_id == story.source_id and item.story.url == story.url then
            existing_idx = i
            break
        end
    end
    if existing_idx then
        table.remove(history, existing_idx)
        return persistSetting(self, "history", history)
    end
    return true
end

function Storage:clearAllHistory(with_downloads)
    self:initialize()
    if with_downloads then
        for _, item in ipairs(self:getHistory()) do
            if type(item) == "table" and type(item.story) == "table" then
                pcall(deleteStoryDownloads, self, item.story)
            end
        end
    end
    return persistSetting(self, "history", {})
end

-- Ebook storage methods for TVE-4U and Dilib sources

function Storage:getEbookDir(source, book)
    self:initialize()
    local source_dir = ffiutil.joinPath(self.root_dir, source.id)
    local book_slug = Util.urlLeaf(book.url, Util.safeName(book.title, "book"))
    local book_dir = ffiutil.joinPath(source_dir, book_slug)
    ko_util.makePath(book_dir)
    return book_dir
end

function Storage:getEbookPath(source, book, filename)
    return ffiutil.joinPath(self:getEbookDir(source, book), Util.safeName(filename, "file"))
end

function Storage:isEbookDownloaded(source, book, filename)
    local path = self:getEbookPath(source, book, filename)
    return lfs.attributes(path, "mode") == "file", path
end

function Storage:listEbookFiles(source, book)
    local dir = self:getEbookDir(source, book)
    local files = {}
    local ok = pcall(function()
        for file in lfs.dir(dir) do
            if file ~= "." and file ~= ".." then
                local path = ffiutil.joinPath(dir, file)
                local attr = lfs.attributes(path)
                if attr and attr.mode == "file" then
                    table.insert(files, {
                        name = file,
                        path = path,
                        size = attr.size,
                    })
                end
            end
        end
    end)
    return files
end

return Storage

