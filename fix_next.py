import re

with open("truyenviet.koplugin/truyenviet/browser.lua", "r", encoding="utf-8") as f:
    text = f.read()

pattern = r"local function on_next_chapter\(\)\s*if next_chapter then\s*self:openChapter\(nil, page_data, source, next_chapter, on_return_callback\)\s*elseif source\.reversed_chapters and page_data\.page > 1 then"
repl = """local function on_next_chapter()
        if next_chapter then
            UIManager:show(Notification:new{ text = "Đang mở chương tiếp theo..." })
            UIManager:nextTick(function()
                self:openChapter(nil, page_data, source, next_chapter, on_return_callback)
            end)
        elseif source.reversed_chapters and page_data.page > 1 then"""

text = re.sub(pattern, repl, text)

with open("truyenviet.koplugin/truyenviet/browser.lua", "w", encoding="utf-8") as f:
    f.write(text)
