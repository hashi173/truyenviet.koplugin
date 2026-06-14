local DataStorage = require("datastorage")
local LuaSettings = require("luasettings")
local ffiutil = require("ffi/util")
local lfs = require("libs/libkoreader-lfs")
local ko_util = require("util")
local Util = require("truyenviet/helpers")
local json = require("json")

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

function Storage:getFavorites()
    self:initialize()
    local favorites = self.settings:readSetting("favorites", {})
    return type(favorites) == "table" and favorites or {}
end

function Storage:isFavorite(story)
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

function Storage:saveStoryMetadata(story)
    local dir = self:getStoryDir({ id = story.source_id }, story)
    local file_path = ffiutil.joinPath(dir, "metadata.json")
    local file = io.open(file_path, "w")
    if file then
        file:write(json.encode(favoriteRecord(story)))
        file:close()
        return true
    end
    return false
end

function Storage:listDownloadedStories()
    self:initialize()
    local result = {}
    
    local ok = pcall(function()
        for source_id in lfs.dir(self.root_dir) do
            if source_id ~= "." and source_id ~= ".." and source_id ~= "cache" then
                local source_dir = ffiutil.joinPath(self.root_dir, source_id)
                if lfs.attributes(source_dir, "mode") == "directory" then
                    for story_folder in lfs.dir(source_dir) do
                        if story_folder ~= "." and story_folder ~= ".." then
                            local story_dir = ffiutil.joinPath(source_dir, story_folder)
                            if lfs.attributes(story_dir, "mode") == "directory" then
                                -- Check if it has downloaded chapters
                                local has_chapters = false
                                for chapter_file in lfs.dir(story_dir) do
                                    if chapter_file:match("%.html$") or chapter_file:match("%.cbz$") then
                                        has_chapters = true
                                        break
                                    end
                                end
                                
                                if has_chapters then
                                    local meta_path = ffiutil.joinPath(story_dir, "metadata.json")
                                    local meta_file = io.open(meta_path, "r")
                                    local story = nil
                                    if meta_file then
                                        local content = meta_file:read("*a")
                                        meta_file:close()
                                        local ok, decoded = pcall(json.decode, content)
                                        if ok and type(decoded) == "table" then
                                            story = decoded
                                        end
                                    end
                                    
                                    if not story then
                                        story = {
                                            title = story_folder:gsub("%-", " "),
                                            url = story_folder,
                                            source_id = source_id,
                                        }
                                    end
                                    table.insert(result, story)
                                end
                            end
                        end
                    end
                end
            end
        end
    end)
    
    table.sort(result, function(left, right)
        return (left.title or ""):lower() < (right.title or ""):lower()
    end)
    return result
end

function Storage:deleteDownloadedStory(story)
    local dir = self:getStoryDir({ id = story.source_id }, story)
    if lfs.attributes(dir, "mode") == "directory" then
        os.execute(string.format("rm -rf %q", dir))
    end
end

return Storage