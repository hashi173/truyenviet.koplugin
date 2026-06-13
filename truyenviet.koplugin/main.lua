local Dispatcher = require("dispatcher")
local WidgetContainer = require("ui/widget/container/widgetcontainer")

local Browser = require("truyenviet/browser")
local Reader = require("truyenviet/reader")

local TruyenViet = WidgetContainer:extend{
    name = "truyenviet",
    is_doc_only = false,
    VERSION = "1.0.1",
}

function TruyenViet:init()
    if self.ui.name == "ReaderUI" then
        Reader:initializeFromReaderUI(self.ui)
    else
        self.ui.menu:registerToMainMenu(self)
    end

    Dispatcher:registerAction("start_truyenviet", {
        category = "none",
        event = "StartTruyenViet",
        title = "Truyện Việt",
        general = true,
    })
end

function TruyenViet:addToMainMenu(menu_items)
    menu_items.truyenviet = {
        text = "Truyện Việt",
        sorting_hint = "search",
        callback = function()
            Browser:showRoot()
        end,
    }
end

function TruyenViet:onStartTruyenViet()
    Browser:showRoot()
end

return TruyenViet
