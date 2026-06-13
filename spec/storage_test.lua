local root = "."
package.path = table.concat({
    root .. "/truyenviet.koplugin/?.lua",
    root .. "/truyenviet.koplugin/?/init.lua",
    package.path,
}, ";")

local fail_flush = false
local settings = {
    data = {
        disabled_sources = {
            dualeo = true,
            truyenqq = true,
        },
    },
}

function settings:readSetting(key, default)
    if self.data[key] == nil then
        self.data[key] = default
    end
    return self.data[key]
end

function settings:saveSetting(key, value)
    self.data[key] = value
    return self
end

function settings:flush()
    if fail_flush then
        error("simulated write failure")
    end
    return self
end

package.preload["datastorage"] = function()
    return {
        getFullDataDir = function()
            return "data"
        end,
        getSettingsDir = function()
            return "settings"
        end,
    }
end

package.preload["luasettings"] = function()
    return {
        open = function()
            return settings
        end,
    }
end

package.preload["ffi/util"] = function()
    return {
        joinPath = function(left, right)
            return left .. "/" .. right
        end,
    }
end

package.preload["libs/libkoreader-lfs"] = function()
    return {
        attributes = function()
            return nil
        end,
    }
end

package.preload["util"] = function()
    return {
        makePath = function() end,
    }
end

package.preload["truyenviet/helpers"] = function()
    return {
        urlLeaf = function(_, fallback)
            return fallback
        end,
        safeName = function(_, fallback)
            return fallback
        end,
    }
end

local Storage = require("truyenviet/storage")
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

assertEqual(false, Storage:isSourceEnabled("dualeo"), "Reads disabled source")
assertEqual(false, Storage:isSourceEnabled("truyenqq"), "Reads second disabled source")

local ok = Storage:setSourceEnabled("dualeo", true)
assertEqual(true, ok, "Enables source")
assertEqual(true, Storage:isSourceEnabled("dualeo"), "Enabled state is immediate")
assertEqual(nil, settings.data.disabled_sources.dualeo, "Enabled source is removed")
assertEqual(true, settings.data.disabled_sources.truyenqq, "Other source is preserved")

ok = Storage:setSourceEnabled("dualeo", false)
assertEqual(true, ok, "Disables source")
assertEqual(false, Storage:isSourceEnabled("dualeo"), "Disabled state is immediate")

fail_flush = true
local failed, err = Storage:setSourceEnabled("dualeo", true)
assertEqual(nil, failed, "Reports write failure")
assertEqual(true, type(err) == "string", "Returns write error")
assertEqual(false, Storage:isSourceEnabled("dualeo"), "Rolls back failed write")

print(string.format("Storage tests passed: %d assertions", tests_run))
