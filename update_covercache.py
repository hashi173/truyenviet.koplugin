import re

with open('truyenviet.koplugin/truyenviet/cover_cache.lua', 'r', encoding='utf-8') as f:
    content = f.read()

prefetch_orig = """function CoverCache:prefetch(stories, registry)
    local fast_mode = Storage.settings and Storage.settings:readSetting("fast_mode", false)
    if fast_mode then return stories end
    
    local limit = #stories
    local ok_uimanager, UIManager = pcall(require, "ui/uimanager")
    
    local ok, copas = pcall(require, "copas")
    local ok_http = pcall(require, "copas.http")
    if ok and copas and copas.addthread and ok_http then
        local active_downloads = 0
        local max_concurrent = 4
        
        for index = 1, limit do
            while active_downloads >= max_concurrent do
                copas.step()
                if ok_uimanager then UIManager:yield() end
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
            if ok_uimanager then UIManager:yield() end
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
            if ok_uimanager then UIManager:yield() end
        end
    end
    
    collectgarbage("collect")
    return stories
end"""

prefetch_new = """function CoverCache:prefetch(stories, registry)
    local fast_mode = Storage.settings and Storage.settings:readSetting("fast_mode", false)
    if fast_mode then return stories end
    
    local limit = #stories
    local ok_uimanager, UIManager = pcall(require, "ui/uimanager")
    
    local has_curl = os.execute("curl --version >/dev/null 2>&1") == 0 or os.execute("curl --version >NUL 2>&1") == 0 or os.execute("curl --version") == true
    
    if has_curl then
        local batch_cmds = {}
        local ffiutil = require("ffi/util")
        local lfs = require("libs/libkoreader-lfs")
        local ImageUtils = require("truyenviet/image_utils")
        
        for index = 1, limit do
            local story = stories[index]
            local source = registry:get(story.source_id)
            if source and story.cover_url and story.cover_url ~= "" and not self:get(story) then
                local path = self:getPath(story)
                local tmp_path = path .. ".tmp"
                
                local headers = source.getCoverHeaders and source:getCoverHeaders(story) or {
                    ["Referer"] = source.base_url .. "/",
                }
                headers["Accept"] = "image/avif,image/webp,image/apng,image/*,*/*;q=0.8"
                
                local h_args = ""
                for k, v in pairs(headers) do
                    h_args = h_args .. string.format(" -H %q", k .. ": " .. v)
                end
                
                -- Download using curl
                local cmd = string.format("curl -sL --connect-timeout 5 -m 10 %s -o %q %q", h_args, tmp_path, story.cover_url)
                table.insert(batch_cmds, cmd)
            end
            
            if #batch_cmds >= 10 or (index == limit and #batch_cmds > 0) then
                local script
                if package.config:sub(1,1) == '\\\\' then
                    script = table.concat(batch_cmds, " & ")
                else
                    script = table.concat(batch_cmds, " & ") .. " & wait"
                end
                os.execute(script)
                batch_cmds = {}
                if ok_uimanager then UIManager:yield() end
            end
        end
        
        -- Validate tmp files and move to actual path
        for index = 1, limit do
            local story = stories[index]
            if not self:get(story) then
                local path = self:getPath(story)
                local tmp_path = path .. ".tmp"
                if lfs.attributes(tmp_path, "mode") == "file" then
                    local f = io.open(tmp_path, "rb")
                    if f then
                        local content = f:read("*a")
                        f:close()
                        if content and #content >= 12 and ImageUtils:isSupported(nil, content) then
                            local extension = ImageUtils:detectExtension(nil, content, story.cover_url)
                            local final_path = ffiutil.joinPath(
                                Storage:getCoverCacheDir(),
                                Util.stableHash(story.cover_url) .. "." .. extension
                            )
                            os.remove(final_path)
                            os.rename(tmp_path, final_path)
                        end
                    end
                    os.remove(tmp_path)
                end
                story.cover_path = self:get(story)
            end
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
            if ok_uimanager then UIManager:yield() end
        end
    end
    
    collectgarbage("collect")
    return stories
end"""

content = content.replace(prefetch_orig, prefetch_new)

with open('truyenviet.koplugin/truyenviet/cover_cache.lua', 'w', encoding='utf-8') as f:
    f.write(content)
print("Done CoverCache")
