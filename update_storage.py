import re

with open("truyenviet.koplugin/truyenviet/storage.lua", "r", encoding="utf-8") as f:
    text = f.read()

metadata_funcs = """function Storage:saveStoryMetadata(story)
    local dir = self:getStoryDir(SourceRegistry:get(story.source_id), story)
    local file_path = ffiutil.joinPath(dir, "metadata.json")
    local file = io.open(file_path, "w")
    if file then
        file:write(ko_util.jsonEncode(favoriteRecord(story)))
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
                                        local ok, decoded = pcall(ko_util.jsonDecode, content)
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

return Storage"""

# Add SourceRegistry required if not there
if "local SourceRegistry =" not in text:
    text = text.replace('local Util = require("truyenviet/helpers")', 'local Util = require("truyenviet/helpers")\nlocal SourceRegistry = require("truyenviet/source_registry")')

# Replace `return Storage` with the new functions
text = re.sub(r"return Storage\s*$", metadata_funcs, text, flags=re.MULTILINE)

with open("truyenviet.koplugin/truyenviet/storage.lua", "w", encoding="utf-8") as f:
    f.write(text)
