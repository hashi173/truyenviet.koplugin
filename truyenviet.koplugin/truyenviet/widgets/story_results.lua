local Blitbuffer = require("ffi/blitbuffer")
local Button = require("ui/widget/button")
local CenterContainer = require("ui/widget/container/centercontainer")
local Device = require("device")
local Font = require("ui/font")
local FrameContainer = require("ui/widget/container/framecontainer")
local Geom = require("ui/geometry")
local GestureRange = require("ui/gesturerange")
local HorizontalGroup = require("ui/widget/horizontalgroup")
local HorizontalSpan = require("ui/widget/horizontalspan")
local ImageWidget = require("ui/widget/imagewidget")
local InputContainer = require("ui/widget/container/inputcontainer")
local LeftContainer = require("ui/widget/container/leftcontainer")
local ListView = require("ui/widget/listview")
local Size = require("ui/size")
local TextBoxWidget = require("ui/widget/textboxwidget")
local TextWidget = require("ui/widget/textwidget")
local TitleBar = require("ui/widget/titlebar")
local UIManager = require("ui/uimanager")
local VerticalGroup = require("ui/widget/verticalgroup")
local VerticalSpan = require("ui/widget/verticalspan")

local Storage = require("truyenviet/storage")

local Screen = Device.screen
local Input = Device.input

local StoryItem = InputContainer:extend{
    width = nil,
    height = nil,
    story = nil,
    callback = nil,
    hold_callback = nil,
}

function StoryItem:init()
    self.dimen = Geom:new{ x = 0, y = 0, w = self.width, h = self.height }
    local padding = Size.padding.default
    local border = Size.border.thin
    local cover_height = math.max(self.height - (padding + border) * 2, 1)
    local cover_width = math.max(math.floor(cover_height * 0.68), 1)
    local text_width = math.max(
        self.width - cover_width - padding * 4 - border * 2,
        1
    )
    local source_height = math.min(
        Screen:scaleBySize(24),
        math.max(self.height - padding * 3, 1)
    )

    local cover_widget
    if self.story.cover_path then
        local lfs = require("libs/libkoreader-lfs")
        if lfs.attributes(self.story.cover_path, "mode") ~= "file" then
            self.story.cover_path = nil
        end
    end
    if self.story.cover_path then
        local ok
        ok, cover_widget = pcall(function()
            return ImageWidget:new{
                file = self.story.cover_path,
                width = cover_width,
                height = cover_height,
                scale_factor = 0,
            }
        end)
        if not ok or not cover_widget then
            cover_widget = nil
            os.remove(self.story.cover_path)
            self.story.cover_path = nil
        end
    end
    if not cover_widget then
        cover_widget = FrameContainer:new{
            width = cover_width,
            height = cover_height,
            CenterContainer:new{
                dimen = Geom:new{ w = cover_width, h = cover_height },
                TextWidget:new{
                    text = "No Cover",
                    face = Font:getFace("smallinfofont", 16),
                    max_width = cover_width,
                }
            }
        }
    end

    self.source_widget = TextWidget:new{
        text = self:getSourceText(),
        face = Font:getFace("xx_smallinfofont"),
        max_width = text_width,
    }

    local text_group = VerticalGroup:new{
        align = "left",
        TextWidget:new{
            text = self.story.title,
            face = Font:getFace("smallinfofont", 22),
            bold = true,
            max_width = text_width,
        },
        VerticalSpan:new{ width = padding },
        self.source_widget,
    }
    self[1] = FrameContainer:new{
        width = self.width,
        height = self.height,
        padding = padding,
        margin = 0,
        bordersize = border,
        background = Blitbuffer.COLOR_WHITE,
        HorizontalGroup:new{
            align = "center",
            CenterContainer:new{
                dimen = Geom:new{ w = cover_width, h = cover_height },
                cover_widget,
            },
            HorizontalSpan:new{ width = padding * 2 },
            LeftContainer:new{
                dimen = Geom:new{ w = text_width, h = cover_height },
                text_group,
            },
        },
    }

    if Device:isTouchDevice() then
        self.ges_events.TapSelect = {
            GestureRange:new{ ges = "tap", range = self.dimen },
        }
        self.ges_events.HoldSelect = {
            GestureRange:new{ ges = "hold", range = self.dimen },
        }
    end
end

function StoryItem:getSourceText()
    local favorite = Storage:isFavorite(self.story) and "  ★" or ""
    return tostring(self.story.source_name or self.story.source_id) .. favorite
end

function StoryItem:refreshFavorite()
    self.source_widget:setText(self:getSourceText())
end

function StoryItem:onTapSelect()
    if self.callback then
        self.callback()
    end
    return true
end

function StoryItem:onHoldSelect()
    if self.hold_callback then
        self.hold_callback()
    end
    return true
end

local StoryResults = InputContainer:extend{
    title = "",
    subtitle = nil,
    stories = nil,
    story_callback = nil,
    story_hold_callback = nil,
    on_return_callback = nil,
    search_callback = nil,
    genres_callback = nil,
    server_page = nil,
    server_total_pages = nil,
    server_prev_callback = nil,
    server_next_callback = nil,
}

function StoryResults:init()
    self.width = Screen:getWidth()
    self.height = Screen:getHeight()
    self.dimen = Geom:new{ x = 0, y = 0, w = self.width, h = self.height }
    self.story_items = {}

    self.title_bar = TitleBar:new{
        width = self.width,
        fullscreen = true,
        title = self.title,
        subtitle = self.subtitle,
        left_icon = "chevron.left",
        left_icon_tap_callback = function()
            self:onClose()
        end,
        right_icon = self.right_icon or (self.search_callback and "appbar.search" or nil),
        right_icon_tap_callback = function()
            if self.right_icon_tap_callback then
                self.right_icon_tap_callback(self)
            elseif self.search_callback then
                self.search_callback()
            end
        end,
        with_bottom_line = true,
    }

    if self.server_page then
        local genre_width = math.floor(self.width * 2 / 5)
        local control_width = math.floor((self.width - genre_width) / 3)
        self.genre_button = Button:new{
            text = "Thể loại",
            width = genre_width,
            callback = function()
                if self.genres_callback then
                    self.genres_callback()
                end
            end,
        }
        self.previous_button = Button:new{
            text = "‹",
            width = control_width,
            callback = function()
                if self.server_prev_callback then
                    self.server_prev_callback()
                end
            end,
        }
        self.page_button = Button:new{
            text = string.format(
                "%d/%d",
                self.server_page,
                self.server_total_pages or self.server_page
            ),
            width = control_width,
            enabled = false,
        }
        self.next_button = Button:new{
            text = "›",
            width = self.width - genre_width - control_width * 2,
            callback = function()
                if self.server_next_callback then
                    self.server_next_callback()
                end
            end,
        }
        self.previous_button:enableDisable(self.server_page > 1)
        self.next_button:enableDisable(
            self.server_page < (self.server_total_pages or self.server_page)
        )
        self.footer = HorizontalGroup:new{
            self.genre_button,
            self.previous_button,
            self.page_button,
            self.next_button,
        }
    else
        local button_width = math.floor(self.width / 4)
        self.previous_button = Button:new{
            text = "‹",
            width = button_width,
            callback = function()
                self.list:prevPage()
            end,
        }
        self.page_button = Button:new{
            text = "1 / 1",
            width = self.width - button_width * 2,
            enabled = false,
        }
        self.next_button = Button:new{
            text = "›",
            width = button_width,
            callback = function()
                self.list:nextPage()
            end,
        }
        self.footer = HorizontalGroup:new{
            self.previous_button,
            self.page_button,
            self.next_button,
        }
    end
    local list_height = self.height
        - self.title_bar:getSize().h
        - self.footer:getSize().h
    list_height = math.max(list_height, 1)
    local item_height = math.max(
        math.min(Screen:scaleBySize(116), list_height),
        1
    )

    local items = {}
    for _, story in ipairs(self.stories or {}) do
        local current_story = story
        local item
        item = StoryItem:new{
            width = self.width,
            height = item_height,
            story = current_story,
            callback = function()
                if self.story_callback then
                    self.story_callback(current_story)
                end
            end,
            hold_callback = function()
                if self.story_hold_callback then
                    self.story_hold_callback(current_story, item)
                end
            end,
        }
        table.insert(items, item)
        table.insert(self.story_items, item)
    end

    self.list = ListView:new{
        padding = 0,
        items = items,
        width = self.width,
        height = list_height,
        item_height = item_height,
        page_update_cb = function(current_page, total_pages)
            total_pages = math.max(total_pages, 1)
            if self.server_page then
                self.title_bar:setSubTitle(string.format(
                    "Trang web %d/%d · danh sách %d/%d",
                    self.server_page,
                    self.server_total_pages or self.server_page,
                    current_page,
                    total_pages
                ), true)
            else
                self.page_button:setText(
                    string.format("%d / %d", current_page, total_pages),
                    self.page_button.width
                )
                self.previous_button:enableDisable(current_page > 1)
                self.next_button:enableDisable(current_page < total_pages)
            end
            UIManager:setDirty(self, "ui")
        end,
    }

    self[1] = FrameContainer:new{
        padding = 0,
        margin = 0,
        bordersize = 0,
        background = Blitbuffer.COLOR_WHITE,
        VerticalGroup:new{
            self.title_bar,
            self.list,
            self.footer,
        },
    }

    if Device:hasKeys() then
        self.key_events.Close = { { Input.group.Back } }
        self.key_events.NextPage = { { Input.group.PgFwd } }
        self.key_events.PrevPage = { { Input.group.PgBack } }
    end
end

function StoryResults:refreshFavorites()
    for _, item in ipairs(self.story_items) do
        item:refreshFavorite()
    end
    UIManager:setDirty(self, "ui")
end

local function isSameStory(left, right)
    return left == right
        or (
            left
            and right
            and left.source_id == right.source_id
            and left.url == right.url
        )
end

function StoryResults:removeStory(story)
    local item_index
    for index, item in ipairs(self.story_items) do
        if isSameStory(item.story, story) then
            item_index = index
            break
        end
    end
    if not item_index then
        return false
    end

    table.remove(self.story_items, item_index)
    table.remove(self.list.items, item_index)
    for index, current_story in ipairs(self.stories) do
        if isSameStory(current_story, story) then
            table.remove(self.stories, index)
            break
        end
    end

    local total_pages = math.max(
        math.ceil(#self.list.items / self.list.items_per_page),
        1
    )
    self.list.show_page = math.min(self.list.show_page, total_pages)
    self.list:_populateItems()
    UIManager:setDirty(self, "ui")
    return true
end

function StoryResults:onNextPage()
    self.list:nextPage()
    return true
end

function StoryResults:onPrevPage()
    self.list:prevPage()
    return true
end

function StoryResults:onClose()
    if self._truyenviet_closed then
        return true
    end
    self._truyenviet_closed = true
    local callback = self.on_return_callback
    self.on_return_callback = nil
    UIManager:close(self)
    if callback then
        UIManager:nextTick(callback)
    end
    return true
end

return StoryResults
