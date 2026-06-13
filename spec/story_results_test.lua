local root = "."
package.path = table.concat({
    root .. "/truyenviet.koplugin/?.lua",
    root .. "/truyenviet.koplugin/?/init.lua",
    package.path,
}, ";")

local empty_modules = {
    "ffi/blitbuffer",
    "ui/widget/button",
    "ui/widget/container/centercontainer",
    "ui/font",
    "ui/widget/container/framecontainer",
    "ui/geometry",
    "ui/gesturerange",
    "ui/widget/horizontalgroup",
    "ui/widget/horizontalspan",
    "ui/widget/iconwidget",
    "ui/widget/imagewidget",
    "ui/widget/container/leftcontainer",
    "ui/widget/listview",
    "ui/size",
    "ui/widget/textboxwidget",
    "ui/widget/textwidget",
    "ui/widget/titlebar",
    "ui/widget/verticalgroup",
    "ui/widget/verticalspan",
}

for _, module_name in ipairs(empty_modules) do
    package.preload[module_name] = function()
        return {}
    end
end

package.preload["device"] = function()
    return {
        screen = {},
        input = {},
    }
end

package.preload["ui/widget/container/inputcontainer"] = function()
    return {
        extend = function(_, definition)
            return definition
        end,
    }
end

local dirty_count = 0
package.preload["ui/uimanager"] = function()
    return {
        setDirty = function()
            dirty_count = dirty_count + 1
        end,
    }
end

package.preload["truyenviet/storage"] = function()
    return {}
end

local StoryResults = require("truyenviet/widgets/story_results")
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

local first = {
    source_id = "truyenfull",
    url = "https://example.test/first",
}
local second = {
    source_id = "truyenqq",
    url = "https://example.test/second",
}
local third = {
    source_id = "dualeo",
    url = "https://example.test/third",
}
local stories = { first, second, third }
local story_items = {
    { story = first },
    { story = second },
    { story = third },
}
local populate_count = 0
local list = {
    items = {
        story_items[1],
        story_items[2],
        story_items[3],
    },
    items_per_page = 2,
    show_page = 2,
}

function list:_populateItems()
    populate_count = populate_count + 1
    self.pages = math.ceil(#self.items / self.items_per_page)
end

local view = {
    stories = stories,
    story_items = story_items,
    list = list,
}

assertEqual(true, StoryResults.removeStory(view, third), "Removes story")
assertEqual(2, #view.stories, "Removes story data")
assertEqual(2, #view.story_items, "Removes story widget")
assertEqual(2, #view.list.items, "Removes list item")
assertEqual(1, view.list.show_page, "Clamps page after removing last page")

assertEqual(
    true,
    StoryResults.removeStory(view, {
        source_id = second.source_id,
        url = second.url,
    }),
    "Matches copied favorite record"
)
assertEqual(first, view.stories[1], "Preserves remaining story")
assertEqual(false, StoryResults.removeStory(view, third), "Ignores missing story")
assertEqual(2, populate_count, "Only refreshes after successful removal")

assertEqual(true, StoryResults.removeStory(view, first), "Removes final story")
assertEqual(0, #view.stories, "Allows empty favorites")
assertEqual(0, #view.list.items, "Clears final list item")
assertEqual(1, view.list.show_page, "Keeps valid page when empty")
assertEqual(3, dirty_count, "Repaints after each removal")

print(string.format("Story results tests passed: %d assertions", tests_run))
