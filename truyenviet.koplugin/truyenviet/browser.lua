local ButtonDialog = require("ui/widget/buttondialog")
local ConfirmBox = require("ui/widget/confirmbox")
local InfoMessage = require("ui/widget/infomessage")
local InputDialog = require("ui/widget/inputdialog")
local Menu = require("ui/widget/menu")
local NetworkMgr = require("ui/network/manager")
local Screen = require("device").screen
local TextViewer = require("ui/widget/textviewer")
local Trapper = require("ui/trapper")
local UIManager = require("ui/uimanager")

local Builder = require("truyenviet/document_builder")
local ChapterDownloader = require("truyenviet/chapter_downloader")
local CoverCache = require("truyenviet/cover_cache")
local Reader = require("truyenviet/reader")
local SearchService = require("truyenviet/search_service")
local SourceRegistry = require("truyenviet/source_registry")
local Storage = require("truyenviet/storage")
local StoryResults = require("truyenviet/widgets/story_results")

local ListView = Menu:extend{
    is_popout = false,
}

function ListView:init()
    self.width = Screen:getWidth()
    self.height = Screen:getHeight()
    Menu.init(self)
end

function ListView:onClose()
    UIManager:close(self)
    if self.on_return_callback then
        self.on_return_callback()
    end
    return true
end

function ListView:onMenuHold(item)
    if item.hold_callback then
        item.hold_callback()
    end
    return true
end

local Browser = {}

local function showError(message)
    UIManager:show(InfoMessage:new{
        text = "Truyện Việt\n\n" .. tostring(message or "Đã xảy ra lỗi không xác định"),
        icon = "notice-warning",
    })
end

local function withLoading(message, callback)
    local loading = InfoMessage:new{
        text = message,
        dismissable = false,
    }
    UIManager:show(loading)
    UIManager:forceRePaint()

    local ok, result, err = pcall(callback)
    UIManager:close(loading)

    if not ok then
        return nil, tostring(result)
    end
    return result, err
end

local function runOnline(callback)
    NetworkMgr:runWhenOnline(function()
        Trapper:wrap(callback)
    end)
end

local function showView(title, items, on_return_callback)
    local view = ListView:new{
        title = title,
        item_table = items,
        on_return_callback = on_return_callback,
        covers_fullscreen = true,
    }
    UIManager:show(view)
    return view
end

local function toggleFavorite(story)
    if Storage:isFavorite(story) then
        Storage:removeFavorite(story)
        UIManager:show(InfoMessage:new{ text = "Đã xóa khỏi tủ truyện." })
        return false
    else
        Storage:addFavorite(story)
        UIManager:show(InfoMessage:new{ text = "Đã thêm vào tủ truyện." })
        return true
    end
end

local function formatStoryDetails(story, source, details)
    local lines = {
        source.name,
    }
    if details.author and details.author ~= "" then
        table.insert(lines, "Tác giả: " .. details.author)
    end
    if details.translator and details.translator ~= "" then
        table.insert(lines, "Nhóm dịch: " .. details.translator)
    end
    if details.status and details.status ~= "" then
        table.insert(lines, "Tình trạng: " .. details.status)
    end
    if details.genres and #details.genres > 0 then
        table.insert(lines, "Thể loại: " .. table.concat(details.genres, ", "))
    end
    table.insert(lines, "")
    table.insert(
        lines,
        details.description ~= "" and details.description
            or "Website không cung cấp mô tả cho truyện này."
    )
    table.insert(lines, "")
    table.insert(lines, story.url)
    return table.concat(lines, "\n")
end

function Browser:showStoryDetails(story, source)
    local function showDetails(details)
        story.details = details
        Storage:updateFavorite(story)
        UIManager:show(TextViewer:new{
            title = story.title,
            text = formatStoryDetails(story, source, details),
        })
    end

    if story.details then
        showDetails(story.details)
        return
    end

    runOnline(function()
        local details, err = withLoading(
            "Đang tải mô tả truyện...",
            function()
                return source:getStoryDetails(story)
            end
        )
        if not details then
            showError(err)
            return
        end
        showDetails(details)
    end)
end

function Browser:showStoryActions(story, source, refresh_callback)
    local dialog
    dialog = ButtonDialog:new{
        title = story.title,
        buttons = {
            {
                {
                    text = Storage:isFavorite(story)
                        and "Xóa khỏi tủ truyện"
                        or "Thêm vào tủ truyện",
                    callback = function()
                        UIManager:close(dialog)
                        local is_favorite = toggleFavorite(story)
                        if refresh_callback then
                            refresh_callback(is_favorite)
                        end
                    end,
                },
            },
            {
                {
                    text = "Xem chi tiết truyện",
                    callback = function()
                        UIManager:close(dialog)
                        self:showStoryDetails(story, source)
                    end,
                },
            },
        },
    }
    UIManager:show(dialog)
end

function Browser:showRoot()
    Storage:initialize()

    local view
    local items = {
        {
            text = "Tìm trên tất cả nguồn",
            mandatory_func = function()
                return tostring(#SourceRegistry:listEnabled())
            end,
            callback = function()
                UIManager:close(view)
                self:showSearchDialog(nil, function()
                    self:showRoot()
                end)
            end,
        },
    }
    for _, source in ipairs(SourceRegistry:listAll()) do
        local current_source = source
        table.insert(items, {
            text = current_source.name,
            mandatory_func = function()
                if not SourceRegistry:isEnabled(current_source.id) then
                    return "Đã tắt · chạm để bật"
                end
                return current_source.kind == "comic" and "CBZ" or "HTML"
            end,
            callback = function()
                if not SourceRegistry:isEnabled(current_source.id) then
                    local ok, err = SourceRegistry:setEnabled(current_source.id, true)
                    if not ok then
                        showError(err)
                    end
                    UIManager:close(view)
                    self:showRoot()
                    return
                end
                UIManager:close(view)
                self:browseSource(current_source, nil, 1, function()
                    self:showRoot()
                end)
            end,
        })
    end
    table.insert(items, {
            text = "Tủ truyện",
            mandatory_func = function()
                return tostring(#Storage:listFavorites())
            end,
            callback = function()
                UIManager:close(view)
                self:showFavorites(function()
                    self:showRoot()
                end)
            end,
        })
    table.insert(items, {
            text = "Quản lý nguồn",
            callback = function()
                UIManager:close(view)
                self:showSourceManager(function()
                    self:showRoot()
                end)
            end,
        })
    table.insert(items, {
            text = "Mở thư mục đã tải",
            callback = function()
                UIManager:close(view)
                local FileManager = require("apps/filemanager/filemanager")
                if FileManager.instance then
                    FileManager.instance:reinit(Storage:getRootDir())
                else
                    FileManager:showFiles(Storage:getRootDir())
                end
            end,
        })
    table.insert(items, {
            text = "Giới thiệu",
            callback = function()
                UIManager:show(TextViewer:new{
                    title = "Truyện Việt",
                    text = table.concat({
                        "Đọc truyện trực tuyến trong KOReader.",
                        "",
                        "Nguồn truyện chữ: https://truyenfull.today/",
                        "Nguồn truyện tranh: https://truyenqqko.com/",
                        "Nguồn truyện tranh: https://dualeotruyenbs.com/",
                        "",
                        "Chương truyện được lưu vào thư mục truyenviet trong thư mục dữ liệu KOReader.",
                        "Nội dung và ảnh thuộc về các website nguồn và chủ sở hữu tương ứng.",
                    }, "\n"),
                })
            end,
        })
    view = showView("Truyện Việt", items)
end

function Browser:showSearchDialog(source, on_return_callback)
    local dialog
    dialog = InputDialog:new{
        title = source and ("Tìm trên " .. source.name) or "Tìm trên tất cả nguồn",
        input_hint = "Tên truyện",
        buttons = {
            {
                {
                    text = "Quay lại",
                    callback = function()
                        UIManager:close(dialog)
                        on_return_callback()
                    end,
                },
                {
                    text = "Tìm",
                    is_enter_default = true,
                    callback = function()
                        local query = dialog:getInputText()
                        if query == "" then
                            return
                        end
                        UIManager:close(dialog)
                        self:search(source, query, on_return_callback)
                    end,
                },
            },
        },
    }
    UIManager:show(dialog)
    dialog:onShowKeyboard()
end

function Browser:search(source, query, on_return_callback)
    runOnline(function()
        local sources = source and { source } or SourceRegistry:listEnabled()
        if #sources == 0 then
            showError("Chưa có nguồn nào được bật.")
            on_return_callback()
            return
        end

        local search_result, err = withLoading(
            'Đang tìm và tải bìa cho "' .. query .. '"...',
            function()
                local stories, errors = SearchService:search(query, sources)
                CoverCache:prefetch(stories, SourceRegistry)
                return {
                    stories = stories,
                    errors = errors,
                }
            end
        )
        if not search_result then
            showError(err)
            self:showSearchDialog(source, on_return_callback)
            return
        end
        local stories = search_result.stories
        if #stories == 0 then
            local message = "Không tìm thấy truyện phù hợp."
            if #search_result.errors > 0 then
                message = message .. "\n\n" .. table.concat(search_result.errors, "\n")
            end
            showError(message)
            self:showSearchDialog(source, on_return_callback)
            return
        end

        self:showStories(
            source and (source.name .. ": " .. query) or query,
            stories,
            function()
                self:showSearchDialog(source, on_return_callback)
            end,
            {
                subtitle = #search_result.errors > 0
                    and string.format(
                        "%d kết quả, %d nguồn lỗi",
                        #stories,
                        #search_result.errors
                    )
                    or string.format("%d kết quả", #stories),
            }
        )
    end)
end

function Browser:browseSource(source, genre, page, on_return_callback)
    runOnline(function()
        local listing, err = withLoading(
            string.format(
                "Đang tải %s...\nTrang %d",
                genre and genre.name or "truyện đã hoàn thành",
                page
            ),
            function()
                local result, fetch_err
                if genre then
                    result, fetch_err = source:getGenre(genre, page)
                else
                    result, fetch_err = source:getCompleted(page)
                end
                if result then
                    CoverCache:prefetch(result.stories, SourceRegistry)
                end
                return result, fetch_err
            end
        )
        if not listing then
            showError(err)
            on_return_callback()
            return
        end
        if #listing.stories == 0 then
            showError("Không có truyện ở trang này.")
            on_return_callback()
            return
        end
        local function showCurrentListing()
            self:showStories(
                source.name .. " · " .. listing.title,
                listing.stories,
                on_return_callback,
                {
                    subtitle = string.format(
                        "Trang web %d/%d · vuốt để xem thêm",
                        listing.page,
                        listing.total_pages
                    ),
                    server_page = listing.page,
                    server_total_pages = listing.total_pages,
                    on_search = function(return_to_listing)
                        self:showSearchDialog(source, return_to_listing)
                    end,
                    on_genres = function(return_to_listing)
                        self:showGenreMenu(
                            source,
                            listing.genres,
                            return_to_listing
                        )
                    end,
                    on_prev_page = listing.page > 1 and function()
                        self:browseSource(
                            source,
                            genre,
                            listing.page - 1,
                            on_return_callback
                        )
                    end or nil,
                    on_next_page = listing.page < listing.total_pages and function()
                        self:browseSource(
                            source,
                            genre,
                            listing.page + 1,
                            on_return_callback
                        )
                    end or nil,
                }
            )
        end
        showCurrentListing()
    end)
end

function Browser:showGenreMenu(source, genres, on_return_callback)
    local view
    local items = {}
    for _, genre in ipairs(genres or {}) do
        local current_genre = genre
        table.insert(items, {
            text = current_genre.name,
            callback = function()
                UIManager:close(view)
                self:browseSource(source, current_genre, 1, function()
                    self:showGenreMenu(source, genres, on_return_callback)
                end)
            end,
        })
    end
    if #items == 0 then
        table.insert(items, {
            text = "Không đọc được danh sách thể loại.",
            dim = true,
            select_enabled = false,
        })
    end
    view = showView(source.name .. " · Thể loại", items, on_return_callback)
end

function Browser:showStories(title, stories, on_return_callback, options)
    options = options or {}
    if #stories == 0 then
        showError("Không có truyện khả dụng.")
        on_return_callback()
        return
    end

    local view
    for _, story in ipairs(stories) do
        local source = SourceRegistry:get(story.source_id)
        if source then
            story.source_name = source.name
            story.cover_path = story.cover_path or CoverCache:get(story)
        end
    end

    view = StoryResults:new{
        title = title,
        subtitle = options.subtitle,
        stories = stories,
        on_return_callback = on_return_callback,
        search_callback = options.on_search and function()
            UIManager:close(view)
            options.on_search(function()
                self:showStories(title, stories, on_return_callback, options)
            end)
        end or nil,
        genres_callback = options.on_genres and function()
            UIManager:close(view)
            options.on_genres(function()
                self:showStories(title, stories, on_return_callback, options)
            end)
        end or nil,
        server_page = options.server_page,
        server_total_pages = options.server_total_pages,
        server_prev_callback = options.on_prev_page and function()
            UIManager:close(view)
            options.on_prev_page()
        end or nil,
        server_next_callback = options.on_next_page and function()
            UIManager:close(view)
            options.on_next_page()
        end or nil,
        story_callback = function(story)
            local source = SourceRegistry:get(story.source_id)
            if not source then
                showError("Nguồn truyện không còn khả dụng.")
                return
            end
            UIManager:close(view)
            self:loadStoryPage(story, source, 1, function()
                if options.favorites_only then
                    local favorites = Storage:listFavorites()
                    if #favorites == 0 then
                        on_return_callback()
                    else
                        self:showStories(
                            title,
                            favorites,
                            on_return_callback,
                            options
                        )
                    end
                else
                    self:showStories(title, stories, on_return_callback, options)
                end
            end)
        end,
        story_hold_callback = function(story)
            local source = SourceRegistry:get(story.source_id)
            if not source then
                showError("Nguồn truyện không còn khả dụng.")
                return
            end
            self:showStoryActions(story, source, function(is_favorite)
                if options.favorites_only and not is_favorite then
                    view:removeStory(story)
                else
                    view:refreshFavorites()
                end
            end)
        end,
    }
    UIManager:show(view)
end

function Browser:showFavorites(on_return_callback)
    self:showStories(
        "Tủ truyện",
        Storage:listFavorites(),
        on_return_callback,
        { favorites_only = true }
    )
end

function Browser:showSourceManager(on_return_callback)
    local view
    local items = {}
    for _, source in ipairs(SourceRegistry:listAll()) do
        local current_source = source
        table.insert(items, {
            text = current_source.name,
            mandatory_func = function()
                return SourceRegistry:isEnabled(current_source.id) and "Đang bật" or "Đã tắt"
            end,
            callback = function()
                local ok, err = SourceRegistry:setEnabled(
                    current_source.id,
                    not SourceRegistry:isEnabled(current_source.id)
                )
                if not ok then
                    showError(err)
                end
                UIManager:close(view)
                self:showSourceManager(on_return_callback)
            end,
        })
    end
    view = showView("Quản lý nguồn", items, on_return_callback)
end

function Browser:loadStoryPage(story, source, page, on_return_callback)
    runOnline(function()
        local page_data, err = withLoading(
            string.format("Đang tải danh sách chương...\nTrang %d", page),
            function()
                return source:getStoryPage(story, page)
            end
        )
        if not page_data then
            showError(err)
            on_return_callback()
            return
        end
        Storage:updateFavorite(page_data.story)
        self:showChapterList(page_data, source, on_return_callback)
    end)
end

function Browser:downloadChapters(
    view,
    page_data,
    source,
    chapters,
    already_downloaded
)
    local story = page_data.story
    runOnline(function()
        local completed, result, run_err = Trapper:dismissableRunInSubprocess(
            function()
                return ChapterDownloader:download(source, story, chapters)
            end,
            string.format("Đang tải %d chương...", #chapters)
        )

        if not completed then
            ChapterDownloader:cleanupPartials(source, story, chapters)
            UIManager:show(InfoMessage:new{ text = "Đã hủy tải các chương." })
            return
        end
        if not result then
            ChapterDownloader:cleanupPartials(source, story, chapters)
            showError(run_err)
            return
        end

        view:updateItems()
        local message = string.format(
            "Đã tải %d chương.\nBỏ qua %d chương đã có.",
            result.downloaded,
            (already_downloaded or 0) + result.skipped
        )
        if #result.errors > 0 then
            local shown = {}
            for index = 1, math.min(#result.errors, 5) do
                table.insert(shown, result.errors[index])
            end
            message = message
                .. string.format("\nLỗi %d chương:\n", #result.errors)
                .. table.concat(shown, "\n")
        end
        UIManager:show(InfoMessage:new{ text = message })
    end)
end

function Browser:confirmDownloadChapters(view, page_data, source)
    local story = page_data.story
    local pending = ChapterDownloader:listPending(
        source,
        story,
        page_data.chapters
    )
    local already_downloaded = #page_data.chapters - #pending
    if #pending == 0 then
        UIManager:show(InfoMessage:new{
            text = "Các chương ở trang mục lục này đã được tải.",
        })
        return
    end

    local warning = string.format(
        "Tải %d chương chưa có ở trang mục lục hiện tại?",
        #pending
    )
    if source.kind == "comic" then
        warning = warning
            .. "\n\nTruyện tranh có thể tốn nhiều thời gian và dung lượng lưu trữ."
    end
    UIManager:show(ConfirmBox:new{
        text = warning,
        ok_text = "Tải các chương",
        ok_callback = function()
            UIManager:nextTick(function()
                self:downloadChapters(
                    view,
                    page_data,
                    source,
                    pending,
                    already_downloaded
                )
            end)
        end,
    })
end

function Browser:showChapterList(page_data, source, on_return_callback)
    local story = page_data.story
    local view
    local items = {
        {
            text = Storage:isFavorite(story)
                and "Xóa khỏi tủ truyện"
                or "Thêm vào tủ truyện",
            mandatory = source.name,
            callback = function()
                toggleFavorite(story)
                UIManager:close(view)
                self:showChapterList(page_data, source, on_return_callback)
            end,
        },
    }

    if #page_data.chapters > 0 then
        table.insert(items, {
            text = "Tải các chương ở trang này",
            mandatory_func = function()
                return string.format(
                    "%d chưa tải",
                    #ChapterDownloader:listPending(
                        source,
                        story,
                        page_data.chapters
                    )
                )
            end,
            callback = function()
                self:confirmDownloadChapters(view, page_data, source)
            end,
        })
    end

    if page_data.total_pages > 1 then
        table.insert(items, {
            text = string.format("Trang %d / %d", page_data.page, page_data.total_pages),
            dim = true,
            select_enabled = false,
        })
    end
    if page_data.page > 1 then
        table.insert(items, {
            text = "← Trang chương trước",
            callback = function()
                UIManager:close(view)
                self:loadStoryPage(story, source, page_data.page - 1, on_return_callback)
            end,
        })
    end
    if page_data.page < page_data.total_pages then
        table.insert(items, {
            text = "Trang chương sau →",
            callback = function()
                UIManager:close(view)
                self:loadStoryPage(story, source, page_data.page + 1, on_return_callback)
            end,
        })
    end

    for _, chapter in ipairs(page_data.chapters) do
        local current_chapter = chapter
        table.insert(items, {
            text = current_chapter.title,
            mandatory_func = function()
                return Storage:isDownloaded(source, story, current_chapter) and "Đã tải" or ""
            end,
            callback = function()
                self:openChapter(view, page_data, source, current_chapter, on_return_callback)
            end,
            hold_callback = function()
                self:showChapterActions(
                    view,
                    page_data,
                    source,
                    current_chapter,
                    on_return_callback
                )
            end,
        })
    end

    if #page_data.chapters == 0 then
        table.insert(items, {
            text = "Không tìm thấy chương ở trang này.",
            dim = true,
            select_enabled = false,
        })
    end

    view = showView(story.title, items, on_return_callback)
end

function Browser:openChapter(view, page_data, source, chapter, on_return_callback, force)
    local story = page_data.story
    if force then
        Storage:removeDownload(source, story, chapter)
    end

    local existing = Builder:getExistingPath(source, story, chapter)
    if existing then
        UIManager:close(view)
        Reader:show(existing, function()
            self:showChapterList(page_data, source, on_return_callback)
        end)
        return
    end

    runOnline(function()
        local payload, fetch_err = withLoading(
            "Đang lấy " .. chapter.title .. "...",
            function()
                return source:getChapter(chapter)
            end
        )
        if not payload then
            showError(fetch_err)
            return
        end

        local action = source.kind == "comic" and "Đang tải ảnh và đóng gói CBZ..." or "Đang tạo tệp HTML..."
        local completed, path, build_err = Trapper:dismissableRunInSubprocess(
            function()
                return Builder:build(source, story, chapter, payload)
            end,
            action
        )

        if not completed then
            os.remove(Storage:getChapterPath(source, story, chapter) .. ".part")
            UIManager:show(InfoMessage:new{ text = "Đã hủy tải chương." })
            return
        end
        if not path then
            showError(build_err)
            return
        end

        UIManager:close(view)
        Reader:show(path, function()
            self:showChapterList(page_data, source, on_return_callback)
        end)
    end)
end

function Browser:showChapterActions(view, page_data, source, chapter, on_return_callback)
    local story = page_data.story
    local downloaded = Storage:isDownloaded(source, story, chapter)
    local dialog
    local buttons = {
        {
            {
                text = "Mở chương",
                callback = function()
                    UIManager:close(dialog)
                    self:openChapter(view, page_data, source, chapter, on_return_callback)
                end,
            },
        },
        {
            {
                text = "Tải lại chương",
                callback = function()
                    UIManager:close(dialog)
                    self:openChapter(view, page_data, source, chapter, on_return_callback, true)
                end,
            },
        },
    }
    if downloaded then
        table.insert(buttons, {
            {
                text = "Xóa bản đã tải",
                callback = function()
                    UIManager:close(dialog)
                    Storage:removeDownload(source, story, chapter)
                    view:updateItems()
                    UIManager:show(InfoMessage:new{ text = "Đã xóa bản tải." })
                end,
            },
        })
    end

    dialog = ButtonDialog:new{
        title = chapter.title,
        buttons = buttons,
    }
    UIManager:show(dialog)
end

return Browser
