import re

with open('truyenviet.koplugin/truyenviet/browser.lua', 'r', encoding='utf-8') as f:
    content = f.read()

# Replace showFavorites
favorites_orig = """function Browser:showFavorites(on_return_callback)
    self:showStories(
        "Tủ truyện",
        Storage:listFavorites(),
        on_return_callback,
        { favorites_only = true }
    )
end"""

favorites_new = """function Browser:showFavorites(on_return_callback)
    local favorites = Storage:listFavorites()
    if #favorites == 0 then
        UIManager:show(InfoMessage:new{
            title = "Truyện Việt",
            text = "Tủ truyện trống." })
        on_return_callback()
        return
    end

    self:showStories("Tủ truyện", favorites, on_return_callback, {
        favorites_only = true,
        delete_all_callback = function(view)
            UIManager:show(ConfirmBox:new{
                title = "Truyện Việt",
                text = "Xóa TẤT CẢ truyện khỏi tủ truyện?",
                ok_text = "Xóa tất cả",
                ok_callback = function()
                    for _, story in ipairs(favorites) do
                        Storage:removeFavorite(story)
                    end
                    closeAndRun(view, on_return_callback)
                end,
            })
        end,
        on_story_hold = function(story, view)
            UIManager:show(ConfirmBox:new{
                title = "Truyện Việt",
                text = "Xóa truyện khỏi tủ truyện?",
                ok_text = "Xóa",
                ok_callback = function()
                    Storage:removeFavorite(story)
                    view:removeStory(story)
                    if #view.stories == 0 then
                        closeAndRun(view, on_return_callback)
                    end
                end,
            })
        end,
    })
end"""

content = content.replace(favorites_orig, favorites_new)

# Replace showHistory
history_orig = """function Browser:showHistory(on_return_callback)
    local history = Storage:getHistory()
    if #history == 0 then
        showError("Chưa có lịch sử đọc.", on_return_callback)
        return
    end

    local stories = {}
    local history_by_url = {}
    for _, item in ipairs(history) do
        table.insert(stories, item.story)
        history_by_url[item.story.source_id .. "|" .. item.story.url] = item
    end

    self:showStories(
        "Lịch sử đọc",
        stories,
        on_return_callback,
        {
            on_story_tap = function(story, view)"""

history_new = """function Browser:showHistory(on_return_callback)
    local history = Storage:getHistory()
    if #history == 0 then
        showError("Chưa có lịch sử đọc.", on_return_callback)
        return
    end

    local stories = {}
    local history_by_url = {}
    for _, item in ipairs(history) do
        table.insert(stories, item.story)
        history_by_url[item.story.source_id .. "|" .. item.story.url] = item
    end

    self:showStories(
        "Lịch sử đọc",
        stories,
        on_return_callback,
        {
            delete_all_callback = function(view)
                UIManager:show(ConfirmBox:new{
                    title = "Truyện Việt",
                    text = "Xóa TẤT CẢ lịch sử đọc?",
                    ok_text = "Xóa tất cả",
                    ok_callback = function()
                        for _, story in ipairs(stories) do
                            Storage:removeHistory(story)
                        end
                        closeAndRun(view, on_return_callback)
                    end,
                })
            end,
            on_story_hold = function(story, view)
                UIManager:show(ConfirmBox:new{
                    title = "Truyện Việt",
                    text = "Xóa truyện khỏi lịch sử đọc?",
                    ok_text = "Xóa",
                    ok_callback = function()
                        Storage:removeHistory(story)
                        view:removeStory(story)
                        if #view.stories == 0 then
                            closeAndRun(view, on_return_callback)
                        end
                    end,
                })
            end,
            on_story_tap = function(story, view)"""

content = content.replace(history_orig, history_new)

with open('truyenviet.koplugin/truyenviet/browser.lua', 'w', encoding='utf-8') as f:
    f.write(content)
print("Done")
