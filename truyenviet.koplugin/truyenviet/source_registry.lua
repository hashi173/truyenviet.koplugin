local Storage = require("truyenviet/storage")

local SourceRegistry = {}

local BUILTIN_SOURCES = {
    require("truyenviet/sources/truyenfull"),
    require("truyenviet/sources/truyenqq"),
    require("truyenviet/sources/dualeo"),
}

local SOURCES_BY_ID = {}
for _, source in ipairs(BUILTIN_SOURCES) do
    SOURCES_BY_ID[source.id] = source
end

function SourceRegistry:get(source_id)
    return SOURCES_BY_ID[source_id]
end

function SourceRegistry:listAll()
    local result = {}
    for _, source in ipairs(BUILTIN_SOURCES) do
        table.insert(result, source)
    end
    return result
end

function SourceRegistry:listEnabled()
    local result = {}
    for _, source in ipairs(BUILTIN_SOURCES) do
        if Storage:isSourceEnabled(source.id) then
            table.insert(result, source)
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
