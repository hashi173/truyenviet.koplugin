local Event = require("ui/event")
local ReaderUI = require("apps/reader/readerui")
local UIManager = require("ui/uimanager")
local WidgetContainer = require("ui/widget/container/widgetcontainer")

local Reader = {
    active = false,
    returning = false,
    switching_document = false,
    on_return_callback = nil,
    on_next_chapter_callback = nil,
}

function Reader:resetSession()
    self.active = false
    self.returning = false
    self.switching_document = false
    self.on_return_callback = nil
    self.on_next_chapter_callback = nil
end

function Reader:show(path, on_return_callback, on_next_chapter_callback)
    self.active = true
    self.returning = false
    self.on_return_callback = on_return_callback
    self.on_next_chapter_callback = on_next_chapter_callback

    if ReaderUI.instance then
        self.switching_document = true
        ReaderUI.instance:switchDocument(path)
        UIManager:nextTick(function()
            self.switching_document = false
        end)
    else
        UIManager:broadcastEvent(Event:new("SetupShowReader"))
        ReaderUI:showReader(path)
    end
end

function Reader:initializeFromReaderUI(ui)
    if not self.active then
        return
    end

    ui.menu:registerToMainMenu(self)
    ui:registerPostInitCallback(function()
        local listener = WidgetContainer:new({})
        listener.onCloseWidget = function()
            if not self.switching_document then
                self:resetSession()
            end
        end

        listener.onEndOfBook = function()
            if self.on_next_chapter_callback then
                self.on_next_chapter_callback()
                return true
            end
        end

        table.insert(ui, 2, listener)
    end)
end

function Reader:addToMainMenu(menu_items)
    menu_items.go_back_to_truyenviet = {
        text = "Quay lại Truyện Việt",
        sorting_hint = "main",
        callback = function()
            self:returnToPlugin()
        end,
    }
    if self.on_next_chapter_callback then
        menu_items.truyenviet_next_chapter = {
            text = "Chương tiếp theo",
            sorting_hint = "main",
            callback = function()
                if self.on_next_chapter_callback then
                    self.on_next_chapter_callback()
                end
            end,
        }
    end
end

function Reader:returnToPlugin(callback_override)
    if self.returning or not self.active then
        return
    end
    self.returning = true

    local callback = callback_override or self.on_return_callback
    self.active = false
    self.on_return_callback = nil
    self.on_next_chapter_callback = nil

    UIManager:nextTick(function()
        local FileManager = require("apps/filemanager/filemanager")
        if ReaderUI.instance then
            ReaderUI.instance:onClose()
        end
        FileManager:showFiles()
        self.returning = false
        if callback then
            UIManager:nextTick(callback)
        end
    end)
end

return Reader
