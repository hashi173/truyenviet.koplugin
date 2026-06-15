import re
import os

with open("truyenviet.koplugin/truyenviet/browser.lua", "r", encoding="utf-8") as f:
    content = f.read()

# 1. Remove CoverCache:prefetch(stories, SourceRegistry)
content = re.sub(
    r'([ \t]*)CoverCache:prefetch\(stories, SourceRegistry\)\n',
    '',
    content
)

# 2. Remove CoverCache:prefetch(chunked_stories, SourceRegistry)
content = re.sub(
    r'([ \t]*)CoverCache:prefetch\(chunked_stories, SourceRegistry\)\n',
    '',
    content
)

# 3. Add prefetchAndRefresh before showStories
prefetch_func = """function Browser:prefetchAndRefresh(stories, view)
    local UIManager = require("ui/uimanager")
    
    local queue = {}
    for _, s in ipairs(stories) do
        if not CoverCache:get(s) then
            table.insert(queue, s)
        end
    end
    
    local function processNext()
        local story = table.remove(queue, 1)
        if not story then return end
        
        local source = SourceRegistry:get(story.source_id)
        if source then
            story.cover_path = CoverCache:download(story, source)
        end
        
        if view and view.story_items then
            for _, item in ipairs(view.story_items) do
                if item.story == story then
                    item:refreshCover()
                    UIManager:setDirty(item, "ui")
                    break
                end
            end
        end
        
        UIManager:scheduleIn(0.1, processNext)
    end
    
    UIManager:scheduleIn(0.1, processNext)
end

function Browser:showStories("""
content = content.replace("function Browser:showStories(", prefetch_func)

# 4. Return view from showStories
content = content.replace(
    "    UIManager:show(view)\nend",
    "    UIManager:show(view)\n    return view\nend",
    1 # Only the one in showStories
)

# 5. Call prefetchAndRefresh in search
content = content.replace(
    'self:showStories(\n            source and (source.name .. ": " .. query) or query,\n            stories,\n            on_return_callback,\n            {\n                search_callback = function()\n                    self:showSearchDialog(source, on_return_callback, parent_view)\n                end,\n                subtitle = source and ("Trang web " .. source.name)\n                    or string.format("%d kết quả", #stories),\n            }\n        )\n        closeParentView(parent_view)',
    'local view = self:showStories(\n            source and (source.name .. ": " .. query) or query,\n            stories,\n            on_return_callback,\n            {\n                search_callback = function()\n                    self:showSearchDialog(source, on_return_callback, parent_view)\n                end,\n                subtitle = source and ("Trang web " .. source.name)\n                    or string.format("%d kết quả", #stories),\n            }\n        )\n        self:prefetchAndRefresh(stories, view)\n        closeParentView(parent_view)'
)

# 6. Call prefetchAndRefresh in browseSource
content = content.replace(
    'local function showCurrentListing()\n            self:showStories(\n                source.name .. " · " .. result.title,',
    'local function showCurrentListing()\n            local view = self:showStories(\n                source.name .. " · " .. result.title,'
)
content = content.replace(
    '        showCurrentListing()\n    end)\nend',
    '        self:prefetchAndRefresh(chunked_stories, view)\n            closeParentView(parent_view)\n            parent_view = nil\n            UIManager:show(Notification:new{\n                text = string.format("Đã chuyển tới trang %d", local_page)\n            })\n        end\n        showCurrentListing()\n    end)\nend'
)
# Wait, the replace for browseSource is tricky. Let's use regex.
content = re.sub(
    r'(local function showCurrentListing\(\)\n[ \t]*)(self:showStories\(\n[ \t]*source\.name \.\. " · " \.\. result\.title,[\s\S]*?on_next_page = [^\n]*\n[ \t]*\n[ \t]*\}[ \t]*\n[ \t]*\)\n[ \t]*closeParentView\(parent_view\)\n[ \t]*parent_view = nil)',
    r'\1local view = \2\n            self:prefetchAndRefresh(chunked_stories, view)',
    content
)

# 7. Call prefetchAndRefresh in showDownloaded
content = re.sub(
    r'(self:showStories\("Truyện đã tải", downloaded, on_return_callback, \{[\s\S]*?\}\)\n)end',
    r'local view = \1    self:prefetchAndRefresh(downloaded, view)\nend',
    content
)

# 8. Call prefetchAndRefresh in showFavorites
content = re.sub(
    r'(self:showStories\("Tủ truyện", favorites, on_return_callback, \{[\s\S]*?\}\)\n)end',
    r'local view = \1    self:prefetchAndRefresh(favorites, view)\nend',
    content
)

# 9. Call prefetchAndRefresh in showHistory
content = re.sub(
    r'(self:showStories\(\n[ \t]*"Lịch sử đọc",\n[ \t]*stories,\n[ \t]*on_return_callback,\n[ \t]*\{[\s\S]*?\}\n[ \t]*\)\n)end',
    r'local view = \1    self:prefetchAndRefresh(stories, view)\nend',
    content
)

with open("truyenviet.koplugin/truyenviet/browser.lua", "w", encoding="utf-8") as f:
    f.write(content)
