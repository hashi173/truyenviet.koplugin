local Storage = require("truyenviet/storage")

local SourceRegistry = {}

local BUILTIN_SOURCES = {
    require("truyenviet/sources/truyenfull"),
    require("truyenviet/sources/truyenqq"),
    require("truyenviet/sources/dualeo"),
    require("truyenviet/sources/truyendich"),
    require("truyenviet/sources/haccbl"),
    require("truyenviet/sources/docln"),
    require("truyenviet/sources/dilib"),
    require("truyenviet/sources/mizzya"),
    require("truyenviet/sources/metruyenvn"),
    require("truyenviet/sources/aztruyen"),
    require("truyenviet/sources/dualeotruyenfull"),
    require("truyenviet/sources/truyenc"),
    require("truyenviet/sources/xtruyen"),
}

local SOURCES_BY_ID = {}
local DEFAULT_BASE_URLS = {}
for _, source in ipairs(BUILTIN_SOURCES) do
    SOURCES_BY_ID[source.id] = source
    DEFAULT_BASE_URLS[source.id] = source.base_url
end

local function isRetiredDefaultUrl(source, url)
    if type(url) ~= "string" or url == "" then
        return false
    end
    local clean = url:gsub("/+$", ""):lower()
    local default_url = DEFAULT_BASE_URLS[source.id]
    if default_url and clean == default_url:gsub("/+$", ""):lower() then
        return true
    end
    for _, legacy in ipairs(source.legacy_base_urls or {}) do
        if clean == legacy:gsub("/+$", ""):lower() then
            return true
        end
    end
    return false
end

local function applyBaseUrl(source)
    local custom = Storage:getCustomBaseUrl(source.id)
    if custom and isRetiredDefaultUrl(source, custom) then
        if type(Storage.setCustomBaseUrl) == "function" then
            pcall(Storage.setCustomBaseUrl, Storage, source.id, nil)
        end
        custom = nil
    end
    source.base_url = custom or DEFAULT_BASE_URLS[source.id]
    return source
end

function SourceRegistry:getDefaultBaseUrl(source_id)
    return source_id and DEFAULT_BASE_URLS[source_id] or nil
end

function SourceRegistry:get(source_id)
    if not source_id then return nil end
    local source = SOURCES_BY_ID[source_id]
    if source then
        applyBaseUrl(source)
    end
    return source
end

function SourceRegistry:listAll()
    local result = {}
    for _, source in ipairs(BUILTIN_SOURCES) do
        table.insert(result, applyBaseUrl(source))
    end
    return result
end

function SourceRegistry:listEnabled()
    local result = {}
    for _, source in ipairs(BUILTIN_SOURCES) do
        if Storage:isSourceEnabled(source.id, source.default_enabled) then
            table.insert(result, applyBaseUrl(source))
        end
    end
    return result
end

function SourceRegistry:isEnabled(source_id)
    local source = SOURCES_BY_ID[source_id]
    return source ~= nil and Storage:isSourceEnabled(source_id, source.default_enabled)
end

function SourceRegistry:setEnabled(source_id, enabled)
    local source = SOURCES_BY_ID[source_id]
    if not source then
        return nil, "Nguồn truyện không tồn tại"
    end
    return Storage:setSourceEnabled(source_id, enabled, source.default_enabled)
end

-- Short, user-facing warning for adapters known to be unreliable.  Adapters
-- declare `availability = { state = "blocked"|"stale", note = "..." }`.
function SourceRegistry:getAvailabilityNote(source)
    local availability = source and source.availability
    if type(availability) ~= "table" then
        return nil
    end
    return availability.note
end

return SourceRegistry
