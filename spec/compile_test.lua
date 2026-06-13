local root = arg[1] or "."
local files = {
    "truyenviet.koplugin/main.lua",
    "truyenviet.koplugin/_meta.lua",
    "truyenviet.koplugin/truyenviet/browser.lua",
    "truyenviet.koplugin/truyenviet/chapter_downloader.lua",
    "truyenviet.koplugin/truyenviet/cover_cache.lua",
    "truyenviet.koplugin/truyenviet/document_builder.lua",
    "truyenviet.koplugin/truyenviet/helpers.lua",
    "truyenviet.koplugin/truyenviet/http_client.lua",
    "truyenviet.koplugin/truyenviet/image_utils.lua",
    "truyenviet.koplugin/truyenviet/reader.lua",
    "truyenviet.koplugin/truyenviet/search_service.lua",
    "truyenviet.koplugin/truyenviet/source_registry.lua",
    "truyenviet.koplugin/truyenviet/storage.lua",
    "truyenviet.koplugin/truyenviet/version.lua",
    "truyenviet.koplugin/truyenviet/sources/dualeo.lua",
    "truyenviet.koplugin/truyenviet/sources/truyendich.lua",
    "truyenviet.koplugin/truyenviet/sources/truyenfull.lua",
    "truyenviet.koplugin/truyenviet/sources/truyenqq.lua",
    "truyenviet.koplugin/truyenviet/widgets/story_results.lua",
}

for _, relative_path in ipairs(files) do
    local path = root .. "/" .. relative_path
    local chunk, err = loadfile(path)
    if not chunk then
        error(string.format("%s: %s", relative_path, tostring(err)))
    end
end

print(string.format("Lua compile tests passed: %d files", #files))
