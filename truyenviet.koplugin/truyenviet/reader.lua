local Event = require("ui/event")
local ReaderUI = require("apps/reader/readerui")
local UIManager = require("ui/uimanager")
local WidgetContainer = require("ui/widget/container/widgetcontainer")
local logger = require("logger")
local Debug = require("truyenviet/debugger")

local Reader = {
    active = false,
    returning = false,
    on_return_callback = nil,
    on_next_chapter_callback = nil,
}

function Reader:show(path, on_return_callback, on_next_chapter_callback, from_reader)
    self.on_return_callback = on_return_callback
    self.on_next_chapter_callback = on_next_chapter_callback

    Debug.write("Reader:show path=" .. tostring(path) .. ", from_reader=" .. tostring(from_reader))

    if self.active and ReaderUI.instance then
        logger.info("TruyenViet: performing async switch with muted FileManager, from_reader=" .. tostring(from_reader))
        local current_ui = ReaderUI.instance
        local InfoMessage = require("ui/widget/infomessage")
        local FileManager = require("apps/filemanager/filemanager")
        
        local loading_msg = InfoMessage:new{
            text = "Đang chuyển chương...",
        }
        
        UIManager:nextTick(function()
            UIManager:show(loading_msg)
            
            -- Mute FileManager to prevent it from stealing focus
            local old_onCloseReader = nil
            if FileManager.instance and FileManager.instance.onCloseReader then
                old_onCloseReader = FileManager.instance.onCloseReader
                FileManager.instance.onCloseReader = function() end
            end
            
            if not from_reader and current_ui then
                current_ui:onClose()
            end
            
            -- Restore FileManager
            if FileManager.instance and old_onCloseReader then
                FileManager.instance.onCloseReader = old_onCloseReader
            end
            
            -- Wait for C engines to fully release file locks and memory
            UIManager:scheduleIn(0.6, function()
                UIManager:broadcastEvent(Event:new("SetupShowReader"))
                ReaderUI:showReader(path)
                UIManager:close(loading_msg)
            end)
        end)
    else
        UIManager:broadcastEvent(Event:new("SetupShowReader"))
        ReaderUI:showReader(path)
    end
    self.active = true
end

function Reader:initializeFromReaderUI(ui)
    ui.menu:registerToMainMenu(self)
    
    ui:registerPostInitCallback(function()
        local listener = WidgetContainer:new({})
        
        listener.onCloseWidget = function()
            self.active = false
        end

        listener.onEndOfBook = function()
            Debug.write("Reader:onEndOfBook triggered, has_callback=" .. tostring(self.on_next_chapter_callback ~= nil))
            if self.on_next_chapter_callback then
                -- signal that the callback is invoked from inside the Reader
                self.on_next_chapter_callback(true)
                Debug.write("Reader:onEndOfBook called on_next_chapter_callback (from_reader=true)")
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
    Debug.write("Reader:returnToPlugin called")
    if self.returning or not self.active then
        Debug.write("Reader:returnToPlugin early return, returning=" .. tostring(self.returning) .. ", active=" .. tostring(self.active))
        return
    end
    self.returning = true

    local callback = callback_override or self.on_return_callback
    self.active = false
    self.on_return_callback = nil
    self.on_next_chapter_callback = nil

    UIManager:nextTick(function()
        local FileManager = require("apps/filemanager/filemanager")
        Debug.write("Reader:returnToPlugin closing reader (if exists) and restoring FileManager")
        if ReaderUI.instance then
            Debug.write("Reader:returnToPlugin: ReaderUI.instance exists, calling onClose()")
            ReaderUI.instance:onClose()
        end
        if FileManager.instance then
            Debug.write("Reader:returnToPlugin: FileManager.instance.reinit()")
            FileManager.instance:reinit()
        else
            Debug.write("Reader:returnToPlugin: FileManager.showFiles()")
            FileManager:showFiles()
        end
        self.returning = false
        if callback then
            UIManager:nextTick(callback)
        end
    end)
end

return Reader
