-- Syntax-check every Lua file shipped in the plugin.  Files are discovered
-- automatically so new modules/sources can never be skipped by mistake.
-- The vendored aeslua submodule is checked too, but only if it exists.
local root = arg[1] or "."

local files = {}
local handle = assert(io.popen('find "' .. root .. '/truyenviet.koplugin" -name "*.lua" -type f | sort'))
for path in handle:lines() do
    table.insert(files, path)
end
handle:close()

assert(#files > 0, "No Lua files found under truyenviet.koplugin")

local required = {
    "truyenviet/browser.lua",
    "truyenviet/bundle_exporter.lua",
    "truyenviet/epub_builder.lua",
    "truyenviet/html_bundle_builder.lua",
    "truyenviet/ebook_downloader.lua",
    "truyenviet/gdrive_downloader.lua",
    "truyenviet/sources/xtruyen.lua",
}
local found = {}
for _, path in ipairs(files) do
    for _, suffix in ipairs(required) do
        if path:sub(-#suffix) == suffix then found[suffix] = true end
    end
end
for _, suffix in ipairs(required) do
    assert(found[suffix], "Missing expected module: " .. suffix)
end

for _, path in ipairs(files) do
    local chunk, err = loadfile(path)
    if not chunk then
        error(string.format("%s: %s", path, tostring(err)))
    end
end

print(string.format("Lua compile tests passed: %d files", #files))
