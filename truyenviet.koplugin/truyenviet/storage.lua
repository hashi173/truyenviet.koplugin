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
    for source_id, disabled in pairs(
        self.settings:readSetting("disabled_sources", {}) or {}
    ) do
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
    return self.settings:readSetting("custom_url_" .. source_id)
end

function Storage:setCustomBaseUrl(source_id, url)
    self:initialize()
    if url and url ~= "" then
        url = url:gsub("/+$", "")
        self.settings:saveSetting("custom_url_" .. source_id, url)
    else
        self.settings:saveSetting("custom_url_" .. source_id, nil)
    end
    self.settings:flush()
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
    return self.settings:readSetting("favorites", {})
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
    local favorites = self:getFavorites()
    favorites[story.source_id .. "|" .. story.url] = favoriteRecord(story)
    self.settings:saveSetting("favorites", favorites)
    self.settings:flush()
end

function Storage:updateFavorite(story)
    if self:isFavorite(story) then
        self:addFavorite(story)
    end
end

function Storage:removeFavorite(story)
    local favorites = self:getFavorites()
    favorites[story.source_id .. "|" .. story.url] = nil
    self.settings:saveSetting("favorites", favorites)
    self.settings:flush()
end

function Storage:listFavorites()
    local result = {}
    for _, story in pairs(self:getFavorites()) do
        table.insert(result, story)
    end
    table.sort(result, function(left, right)
        return left.title:lower() < right.title:lower()
    end)
    return result
end

function Storage:getHistory()
    self:initialize()
    return self.settings:readSetting("history", {})
end

function Storage:saveHistory(story, chapter)
    local history = self:getHistory()
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
    
    self.settings:saveSetting("history", history)
    self.settings:flush()
end

function Storage:removeHistory(story)
    local history = self:getHistory()
    local existing_idx
    for i, item in ipairs(history) do
        if item.story.source_id == story.source_id and item.story.url == story.url then
            existing_idx = i
            break
        end
    end
    if existing_idx then
        table.remove(history, existing_idx)
        self.settings:saveSetting("history", history)
        self.settings:flush()
    end
end

return Storage
