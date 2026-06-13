local Util = require("truyenviet/helpers")

local SearchService = {}

function SearchService:search(query, sources)
    local results = {}
    local errors = {}
    local seen = {}

    for source_index, source in ipairs(sources) do
        local ok, stories, err = pcall(source.search, source, query)
        if not ok then
            table.insert(errors, source.name .. ": " .. tostring(stories))
        elseif not stories then
            table.insert(errors, source.name .. ": " .. tostring(err or "lỗi không xác định"))
        else
            for result_index, story in ipairs(stories) do
                local key = story.source_id .. "|" .. story.url
                if not seen[key] then
                    seen[key] = true
                    story.source_name = source.name
                    story.search_score = Util.searchScore(
                        query,
                        story.title,
                        result_index + (source_index - 1) * 100
                    )
                    table.insert(results, story)
                end
            end
        end
    end

    table.sort(results, function(left, right)
        if left.search_score ~= right.search_score then
            return left.search_score > right.search_score
        end
        local left_title = Util.normalizeSearch(left.title)
        local right_title = Util.normalizeSearch(right.title)
        if left_title ~= right_title then
            return left_title < right_title
        end
        return left.source_id < right.source_id
    end)

    return results, errors
end

return SearchService
