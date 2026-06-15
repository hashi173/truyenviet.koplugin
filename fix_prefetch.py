import re

with open("truyenviet.koplugin/truyenviet/cover_cache.lua", "r", encoding="utf-8") as f:
    text = f.read()

replacement = """function CoverCache:prefetch(stories, registry)
    local fast_mode = Storage.settings and Storage.settings:readSetting("fast_mode", false)
    if fast_mode then return stories end
    
    local limit = math.min(#stories, self.max_prefetch)
    
    local ok, copas = pcall(require, "copas")
    if ok and copas and copas.addthread then
        local active_downloads = 0
        local max_concurrent = 4
        
        for index = 1, limit do
            while active_downloads >= max_concurrent do
                copas.step()
            end
            
            active_downloads = active_downloads + 1
            copas.addthread(function()
                local story = stories[index]
                local source = registry:get(story.source_id)
                if source then
                    story.cover_path = self:download(story, source)
                end
                active_downloads = active_downloads - 1
            end)
        end
        
        while active_downloads > 0 do
            copas.step()
        end
    else
        for index = 1, limit do
            local story = stories[index]
            local source = registry:get(story.source_id)
            if source then
                story.cover_path = self:download(story, source)
            end
            if index % 5 == 0 then
                collectgarbage("collect")
            end
        end
    end
    
    collectgarbage("collect")
    return stories
end"""

text = re.sub(r"function CoverCache:prefetch\(stories, registry\).*?return stories\nend", replacement, text, flags=re.DOTALL)

with open("truyenviet.koplugin/truyenviet/cover_cache.lua", "w", encoding="utf-8") as f:
    f.write(text)
