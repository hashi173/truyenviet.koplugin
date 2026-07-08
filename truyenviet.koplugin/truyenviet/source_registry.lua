local Storage = require("truyenviet/storage")

local SourceRegistry = {}

local BUILTIN_SOURCES = {
    require("truyenviet/sources/truyenfull"),
    require("truyenviet/sources/truyenqq"),
    require("truyenviet/sources/dualeo"),
    require("truyenviet/sources/truyendich"),
    require("truyenviet/sources/cbunu"),
    require("truyenviet/sources/haccbl"),
    require("truyenviet/sources/giatocvuongtai"),
    require("truyenviet/sources/docln"),
}

local SOURCES_BY_ID = {}
local DEFAULT_BASE_URLS = {}
for _, source in ipairs(BUILTIN_SOURCES) do
    SOURCES_BY_ID[source.id] = source
    DEFAULT_BASE_URLS[source.id] = source.base_url
end

local function applyBaseUrl(source)
    source.base_url = Storage:getCustomBaseUrl(source.id)
        or DEFAULT_BASE_URLS[source.id]
    return source
end

function SourceRegistry:get(source_id)
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
        if Storage:isSourceEnabled(source.id) then
            table.insert(result, applyBaseUrl(source))
        end
    end
    return result
end

function SourceRegistry:isEnabled(source_id)
    return SOURCES_BY_ID[source_id] ~= nil and Storage:isSourceEnabled(source_id)
end

function SourceRegistry:setEnabled(source_id, enabled)
    if not SOURCES_BY_ID[source_id] then
        return nil, "Nguồn truyện không tồn tại"
    end
    return Storage:setSourceEnabled(source_id, enabled)
end

return SourceRegistry
