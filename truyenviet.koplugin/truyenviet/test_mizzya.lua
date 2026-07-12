local Source = require("sources.mizzya")

local function test()
    print("Testing getHome...")
    local list = Source:getHome()
    if not list or not list.stories or #list.stories == 0 then
        print("Failed to get stories")
        return
    end
    print("Found " .. #list.stories .. " stories.")
    local story = list.stories[1]
    print("Testing getStoryPage for " .. story.url)
    
    local page = Source:getStoryPage(story, 1)
    if not page or not page.chapters or #page.chapters == 0 then
        print("Failed to get chapters")
        return
    end
    print("Found " .. #page.chapters .. " chapters.")
    local chapter = page.chapters[2] or page.chapters[1]
    
    print("Testing getChapter for " .. chapter.url)
    local content, err = Source:getChapter(chapter)
    if not content then
        print("Failed to get chapter content: " .. tostring(err))
    else
        print("Got content, length: " .. string.len(content))
    end
end

test()
