import re

with open("truyenviet.koplugin/truyenviet/browser.lua", "r", encoding="utf-8") as f:
    text = f.read()

# Add showDownloaded function
show_downloaded = """function Browser:showDownloaded(on_return_callback)
    local downloaded = Storage:listDownloadedStories()
    if #downloaded == 0 then
        UIManager:show(InfoMessage:new{
            title = "Truyện Việt",
            text = "Chưa có truyện nào được tải." })
        on_return_callback()
        return
    end

    self:showStories("Truyện đã tải", downloaded, on_return_callback, { downloads_only = true })
end

"""

if "function Browser:showDownloaded" not in text:
    # Insert it before showFavorites
    text = text.replace("function Browser:showFavorites", show_downloaded + "function Browser:showFavorites")

# Add to menu
menu_item = """    table.insert(items, {
            text = "Truyện đã tải",
            mandatory_func = function()
                return tostring(#Storage:listDownloadedStories())
            end,
            callback = function()
                closeAndRun(view, function()
                    self:showDownloaded(function()
                        self:showRoot()
                    end)
                end)
            end,
        })
"""

if "text = \"Truyện đã tải\"" not in text:
    # Insert it after Tủ truyện
    target = """    table.insert(items, {
            text = "Tủ truyện","""
    
    replace = menu_item + target
    text = text.replace(target, replace)

with open("truyenviet.koplugin/truyenviet/browser.lua", "w", encoding="utf-8") as f:
    f.write(text)
