local root = "."
package.path = table.concat({
    root .. "/truyenviet.koplugin/?.lua",
    root .. "/truyenviet.koplugin/?/init.lua",
    package.path,
}, ";")

package.preload["ui/event"] = function()
    return {
        new = function(_, name)
            return { name = name }
        end,
    }
end

local close_count = 0
local show_files_count = 0
local broadcast_count = 0
local show_reader_path
local switched_path

local ReaderUI = {
    instance = nil,
}
function ReaderUI:showReader(path)
    show_reader_path = path
end
package.preload["apps/reader/readerui"] = function()
    return ReaderUI
end

package.preload["apps/filemanager/filemanager"] = function()
    return {
        showFiles = function()
            show_files_count = show_files_count + 1
        end,
    }
end

package.preload["ui/uimanager"] = function()
    return {
        broadcastEvent = function()
            broadcast_count = broadcast_count + 1
        end,
        nextTick = function(_, callback)
            callback()
        end,
    }
end

package.preload["ui/widget/container/widgetcontainer"] = function()
    return {
        new = function(_, definition)
            return definition
        end,
    }
end

local Reader = require("truyenviet/reader")
local tests_run = 0

local function assertEqual(expected, actual, message)
    tests_run = tests_run + 1
    if expected ~= actual then
        error(string.format(
            "%s: expected %s, got %s",
            message,
            tostring(expected),
            tostring(actual)
        ))
    end
end

ReaderUI.instance = {
    switchDocument = function(_, path)
        switched_path = path
    end,
}
Reader:show("chapter-2.html", function() end, function() end)
assertEqual("chapter-2.html", switched_path, "Switches an active reader")
assertEqual(true, Reader.active, "Keeps plugin reader session active")

local normal_return_count = 0
ReaderUI.instance = {
    onClose = function()
        close_count = close_count + 1
        ReaderUI.instance = nil
    end,
}
Reader.on_return_callback = function()
    normal_return_count = normal_return_count + 1
end
Reader:returnToPlugin()
Reader:returnToPlugin()
assertEqual(1, close_count, "Closes reader once")
assertEqual(1, show_files_count, "Restores file manager once")
assertEqual(1, normal_return_count, "Runs return callback once")
assertEqual(false, Reader.active, "Ends reader session")

ReaderUI.instance = nil
Reader:show("chapter-1.html", function() end, function() end)
assertEqual(1, broadcast_count, "Prepares existing UI before opening reader")
assertEqual("chapter-1.html", show_reader_path, "Opens a new reader")

local normal_count = 0
local next_count = 0
Reader.active = true
Reader.on_return_callback = function()
    normal_count = normal_count + 1
end
ReaderUI.instance = {
    onClose = function()
        close_count = close_count + 1
        ReaderUI.instance = nil
    end,
}
Reader:returnToPlugin(function()
    next_count = next_count + 1
end)
assertEqual(0, normal_count, "Next chapter skips normal return callback")
assertEqual(1, next_count, "Runs next chapter callback")

print(string.format("Reader tests passed: %d assertions", tests_run))
