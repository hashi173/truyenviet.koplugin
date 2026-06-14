local ButtonDialog = require("ui/widget/buttondialog")
local ConfirmBox = require("ui/widget/confirmbox")
local InfoMessage = require("ui/widget/infomessage")
local InputDialog = require("ui/widget/inputdialog")
local Menu = require("ui/widget/menu")
local NetworkMgr = require("ui/network/manager")
local Notification = require("ui/widget/notification")
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
local Version = require("truyenviet/version")

local ListView = Menu:extend{
    is_popout = false,
}

function ListView:init()
    self.width = Screen:getWidth()
    self.height = Screen:getHeight()
    Menu.init(self)
end

function ListView:onClose()
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

function ListView:onMenuHold(item)
    if item.hold_callback then
        item.hold_callback()
    end
    return true
end

local Browser = {}

local function showError(message, on_close)
    local text = "Truyện Việt\n\n"
        .. tostring(message or "Đã xảy ra lỗi không xác định")
    if not on_close then
        UIManager:show(InfoMessage:new{
            title = "Truyện Việt",
            text = text,
            icon = "notice-warning",
        })
        return
    end

    UIManager:show(ConfirmBox:new{
            title = "Truyện Việt",
            text = text,
        icon = "notice-warning",
        cancel_text = "Đóng",
        no_ok_button = true,
        dismissable = false,
        cancel_callback = function()
            UIManager:nextTick(on_close)
        end,
    })
end

local function closeAndRun(widget, callback)
    if widget then
        UIManager:close(widget)
    end
    if callback then
        UIManager:nextTick(callback)
    end
end

local function closeParentView(parent_view)
    if parent_view then
        UIManager:close(parent_view)
    end
end

local function showLoadingError(message, parent_view, on_return_callback)
    if parent_view then
        showError(message)
    else
        showError(message, on_return_callback)
    end
end

local function withLoading(message, callback)
    local loading = InfoMessage:new{
            title = "Truyện Việt",
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

local function toggleFavorite(story, refresh_callback)
    if Storage:isFavorite(story) then
        local removed, remove_err = Storage:removeFavorite(story)
        if not removed then
            showError(remove_err)
            return nil
        end
        local source = SourceRegistry:get(story.source_id)
        if source then
            local lfs = require("libs/libkoreader-lfs")
            local dir = Storage:getStoryDir(source, story)
            if lfs.attributes(dir, "mode") == "directory" then
                UIManager:show(ConfirmBox:new{
            title = "Truyện Việt",
            text = "Đã xóa khỏi tủ truyện.\nBạn có muốn xóa luôn các bản tải của truyện này khỏi máy không?",
                    ok_text = "Xóa bản tải",
                    ok_callback = function()
                        for file in lfs.dir(dir) do
                            if file ~= "." and file ~= ".." then
                                os.remove(dir .. "/" .. file)
                            end
                        end
                        os.remove(dir)
                        UIManager:show(InfoMessage:new{
            title = "Truyện Việt",
            text = "Đã xóa các chương đã tải." })
                    end,
                    cancel_text = "Giữ lại",
                })
            else
                UIManager:show(InfoMessage:new{
            title = "Truyện Việt",
            text = "Đã xóa khỏi tủ truyện." })
            end
        else
            UIManager:show(InfoMessage:new{
            title = "Truyện Việt",
            text = "Đã xóa khỏi tủ truyện." })
        end
        if refresh_callback then refresh_callback(false) end
        return false
    else
        local added, add_err = Storage:addFavorite(story)
        if not added then
            showError(add_err)
            return nil
        end
        UIManager:show(InfoMessage:new{
            title = "Truyện Việt",
            text = "Đã thêm vào tủ truyện." })
        if refresh_callback then refresh_callback(true) end
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
            showDetails({})
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
                        closeAndRun(dialog, function()
                            toggleFavorite(story, refresh_callback)
                        end)
                    end,
                },
            },
            {
                {
                    text = "Xem chi tiết truyện",
                    callback = function()
                        closeAndRun(dialog, function()
                            self:showStoryDetails(story, source)
                        end)
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
                self:showSearchDialog(nil, function()
                    self:showRoot()
                end, view)
                return true
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
                        return
                    end
                    closeAndRun(view, function()
                        self:showRoot()
                    end)
                    return
                end
                self:browseSource(current_source, nil, 1, function()
                        self:showRoot()
                    end, view)
                    return true
            end,
        })
    end
    table.insert(items, {
            text = "Lịch sử đọc",
            mandatory_func = function()
                return tostring(#Storage:getHistory())
            end,
            callback = function()
                closeAndRun(view, function()
                    self:showHistory(function()
                        self:showRoot()
                    end)
                end)
            end,
        })
    table.insert(items, {
            text = "Truyện đã tải",
            mandatory_func = function()
                return tostring(#Storage:listDownloadedStories())
            end,
            callback = function()
                closeAndRun(view, function()
                    self:showDownloaded(function()
                        self:showRoot()
                    end)
                end)
            end,
        })
    table.insert(items, {
            text = "Tủ truyện",
            mandatory_func = function()
                return tostring(#Storage:listFavorites())
            end,
            callback = function()
                closeAndRun(view, function()
                    self:showFavorites(function()
                        self:showRoot()
                    end)
                end)
            end,
        })
        table.insert(items, {
            text = "Quản lý nguồn",
            callback = function()
                closeAndRun(view, function()
                    self:showSourceManager(function()
                        self:showRoot()
                    end)
                end)
            end,
        })
        table.insert(items, {
            text = "Mở thư mục đã tải",
            callback = function()
                closeAndRun(view, function()
                    local FileManager = require("apps/filemanager/filemanager")
                    local ReaderUI = require("apps/reader/readerui")
                    if ReaderUI.instance then
                        ReaderUI.instance:onClose()
                    end
                    FileManager:showFiles(Storage:getRootDir())
                end)
            end,
        })
    table.insert(items, {
            text = "Xóa bộ nhớ đệm ảnh bìa",
            callback = function()
                if Storage:clearCoverCacheDir() then
                    UIManager:show(InfoMessage:new{
            title = "Truyện Việt",
            text = "Đã xóa bộ nhớ đệm ảnh bìa." })
                else
                    showError("Không thể xóa bộ nhớ đệm.")
                end
            end,
        })
        table.insert(items, {
            text = "Kiểm tra cập nhật",
            callback = function()
                local Http = require("truyenviet/http_client")
                runOnline(function()
                    local res, err = withLoading("Đang kiểm tra cập nhật...", function()
                        local response, req_err = Http:get("https://api.github.com/repos/hashi173/truyenviet.koplugin/releases/latest")
                        if not response then error(req_err or "Lỗi kết nối") end
                        return response
                    end)
                    if not res then
                        UIManager:show(ConfirmBox:new{
            title = "Truyện Việt",
            text = "Lỗi kết nối: " .. tostring(err),
                            ok_text = "Đóng",
                        })
                        return
                    end
                    local current_version = Version
                    local latest_version = res:match('"tag_name"%s*:%s*"v?([^"]+)"') or ""
                    
                    if latest_version ~= "" and latest_version ~= current_version then
                        UIManager:show(ConfirmBox:new{
            title = "Truyện Việt",
            text = string.format("Phiên bản mới: %s\nPhiên bản hiện tại: %s\n\nCó tải về và cài đặt cập nhật không?", latest_version, current_version),
                            ok_text = "Cập nhật",
                            ok_callback = function()
                                UIManager:nextTick(function()
                                    local asset_url = res:match('"browser_download_url"%s*:%s*"([^"]+%.zip)"')
                                    if not asset_url then
                                        UIManager:show(ConfirmBox:new{
            title = "Truyện Việt",
            text = "Không tìm thấy file cài đặt.",
                                            ok_text = "Đóng",
                                        })
                                        return
                                    end

                                    local dl_ok, dl_err = withLoading("Đang tải xuống bản cập nhật...", function()
                                        local body, download_err = Http:get(asset_url)
                                        if not body then
                                            return nil, download_err
                                        end

                                        local ffiutil = require("ffi/util")
                                        local zip_path = ffiutil.joinPath(
                                            Storage:getRootDir(),
                                            "update.zip"
                                        )
                                        local file, open_err = io.open(zip_path, "wb")
                                        if not file then
                                            return nil, open_err or "Không thể lưu file"
                                        end
                                        local written, write_err = file:write(body)
                                        file:close()
                                        if not written then
                                            os.remove(zip_path)
                                            return nil, write_err or "Không thể ghi file"
                                        end

                                        local DataStorage = require("datastorage")
                                        local plugins_dir = ffiutil.joinPath(
                                            DataStorage:getDataDir(),
                                            "plugins"
                                        )
                                        local command = string.format(
                                            "unzip -o %q -d %q",
                                            zip_path,
                                            plugins_dir
                                        )
                                        local status = os.execute(command)
                                        os.remove(zip_path)
                                        if status ~= 0 and status ~= true then
                                            return nil, "Không thể giải nén bản cập nhật"
                                        end
                                        return true
                                    end)

                                    if dl_ok then
                                        UIManager:show(ConfirmBox:new{
            title = "Truyện Việt",
            text = "Cập nhật thành công! Vui lòng khởi động lại KOReader.",
                                            ok_text = "Đóng",
                                        })
                                    else
                                        UIManager:show(ConfirmBox:new{
            title = "Truyện Việt",
            text = "Cập nhật thất bại: " .. tostring(dl_err),
                                            ok_text = "Đóng",
                                        })
                                    end
                                end)
                            end,
                            cancel_text = "Để sau",
                        })
                    else
                        UIManager:show(ConfirmBox:new{
            title = "Truyện Việt",
            text = "Bạn đang dùng phiên bản mới nhất (" .. current_version .. ")",
                            ok_text = "Đóng",
                        })
                    end
                end)
            end,
        })
    table.insert(items, {
            text = Storage.settings:readSetting("fast_mode", false) 
                and "Chế độ tải ảnh bìa: Tắt (Duyệt rất nhanh)" 
                or "Chế độ tải ảnh bìa: Bật (Tải chậm hơn)",
            callback = function()
                local is_fast = Storage.settings:readSetting("fast_mode", false)
                local ok, err = Storage:setFastMode(not is_fast)
                if not ok then
                    showError(err)
                    return
                end
                closeAndRun(view, function()
                    self:showRoot()
                end)
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

function Browser:showSearchDialog(source, on_return_callback, parent_view)
    local dialog
    dialog = InputDialog:new{
        title = source and ("Tìm trên " .. source.name) or "Tìm trên tất cả nguồn",
        input_hint = "Tên truyện",
        buttons = {
            {
                {
                    text = "Quay lại",
                    callback = function()
                        closeAndRun(dialog, function()
                            if not parent_view and on_return_callback then 
                                on_return_callback() 
                            end
                        end)
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
                        closeAndRun(dialog, function()
                            self:search(source, query, on_return_callback, parent_view)
                        end)
                    end,
                },
            },
        },
    }
    UIManager:show(dialog)
    dialog:onShowKeyboard()
end

function Browser:search(source, query, on_return_callback, parent_view)
    runOnline(function()
        local sources = source and { source } or SourceRegistry:listEnabled()
        if #sources == 0 then
            showLoadingError(
                "Chưa có nguồn nào được bật.",
                parent_view,
                on_return_callback
            )
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
            showError(err, function()
                self:showSearchDialog(source, on_return_callback, parent_view)
            end)
            return
        end
        local stories = search_result.stories
        if #stories == 0 then
            local message = "Không tìm thấy truyện phù hợp."
            if #search_result.errors > 0 then
                message = message .. "\n\n" .. table.concat(search_result.errors, "\n")
            end
            showError(message, function()
                self:showSearchDialog(source, on_return_callback, parent_view)
            end)
            return
        end

        self:showStories(
            source and (source.name .. ": " .. query) or query,
            stories,
            on_return_callback,
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
        closeParentView(parent_view)
    end)
end

function Browser:browseSource(source, genre, local_page, on_return_callback, parent_view)
    local ITEMS_PER_PAGE = 10
    self.chunks_per_page = self.chunks_per_page or {}
    local cpp = self.chunks_per_page[source.id] or 1
    
    local server_page = math.ceil(local_page / cpp)
    local chunk_index = ((local_page - 1) % cpp) + 1

    runOnline(function()
        local result, err
        local cache = self.cached_listing
        if cache and cache.source_id == source.id and cache.genre_name == (genre and genre.name or nil) and cache.server_page == server_page then
            result = cache.listing
        else
            result, err = withLoading(
                string.format(
                    "Đang tải %s...\nTrang %d",
                    genre and genre.name or "truyện đã hoàn thành",
                    server_page
                ),
                function()
                    local r, e
                    if genre then
                        r, e = source:getGenre(genre, server_page)
                    else
                        r, e = source:getCompleted(server_page)
                    end
                    return r, e
                end
            )
            if result then
                self.cached_listing = {
                    source_id = source.id,
                    genre_name = genre and genre.name or nil,
                    server_page = server_page,
                    listing = result,
                }
                cpp = math.max(1, math.ceil(#result.stories / ITEMS_PER_PAGE))
                self.chunks_per_page[source.id] = cpp
            end
        end

        if not result then
            showLoadingError(err, parent_view, on_return_callback)
            return
        end
        if #result.stories == 0 then
            showLoadingError(
                "Không có truyện ở trang này.",
                parent_view,
                on_return_callback
            )
            return
        end

        cpp = self.chunks_per_page[source.id]
        chunk_index = math.min(chunk_index, cpp)
        
        local start_idx = (chunk_index - 1) * ITEMS_PER_PAGE + 1
        local end_idx = math.min(chunk_index * ITEMS_PER_PAGE, #result.stories)
        
        local chunked_stories = {}
        for i = start_idx, end_idx do
            if result.stories[i] then
                table.insert(chunked_stories, result.stories[i])
            end
        end

        CoverCache:prefetch(chunked_stories, SourceRegistry)

        local local_total_pages = result.total_pages * cpp

        local function showCurrentListing()
            self:showStories(
                source.name .. " · " .. result.title,
                chunked_stories,
                on_return_callback,
                {
                    subtitle = string.format(
                        "Trang web %d/%d",
                        local_page,
                        local_total_pages
                    ),
                    server_page = local_page,
                    server_total_pages = local_total_pages,
                    on_search = function(return_to_listing, parent_view)
                        self:showSearchDialog(source, return_to_listing, parent_view)
                    end,
                    on_genres = function(return_to_listing, p_view)
                        self:showGenreMenu(
                            source,
                            result.genres,
                            return_to_listing,
                            p_view
                        )
                    end,
                    on_prev_page = local_page > 1 and function(parent)
                        self:browseSource(
                            source,
                            genre,
                            local_page - 1,
                            on_return_callback,
                            parent
                        )
                    end or nil,
                    on_next_page = local_page < local_total_pages and function(parent)
                        self:browseSource(
                            source,
                            genre,
                            local_page + 1,
                            on_return_callback,
                            parent
                        )
                    end or nil,
                }
            )
            closeParentView(parent_view)
            parent_view = nil
            UIManager:show(Notification:new{
                text = string.format("Đã chuyển tới trang %d", local_page)
            })
        end
        showCurrentListing()
    end)
end

function Browser:showGenreMenu(source, genres, on_return_callback, parent_view)
    local view
    local items = {}
    for _, genre in ipairs(genres or {}) do
        local current_genre = genre
        table.insert(items, {
            text = current_genre.name,
            callback = function()
                self:browseSource(source, current_genre, 1, function()
                    self:showGenreMenu(source, genres, on_return_callback)
                end, view)
                return true
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
        showError("Không có truyện khả dụng.", on_return_callback)
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
            options.on_search(function()
                self:showStories(title, stories, on_return_callback, options)
            end, view)
        end or nil,
        genres_callback = options.on_genres and function()
            closeAndRun(view, function()
                options.on_genres(function()
                    self:showStories(title, stories, on_return_callback, options)
                end)
            end)
        end or nil,
        server_page = options.server_page,
        server_total_pages = options.server_total_pages,
        server_prev_callback = options.on_prev_page and function()
            options.on_prev_page(view)
        end or nil,
        server_next_callback = options.on_next_page and function()
            options.on_next_page(view)
        end or nil,
        story_callback = function(story)
            if options.on_story_tap then
                options.on_story_tap(story, view)
                return
            end
            local source = SourceRegistry:get(story.source_id)
            if not source then
                showError("Nguồn truyện không còn khả dụng.")
                return
            end
            closeAndRun(view, function()
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
                    elseif options.downloads_only then
                        local downloaded = Storage:listDownloadedStories()
                        if #downloaded == 0 then
                            on_return_callback()
                        else
                            self:showStories(
                                title,
                                downloaded,
                                on_return_callback,
                                options
                            )
                        end
                    else
                        self:showStories(title, stories, on_return_callback, options)
                    end
                end)
            end)
        end,
        story_hold_callback = function(story)
            if options.on_story_hold then
                options.on_story_hold(story, view)
                return
            end
            local source = SourceRegistry:get(story.source_id)
            if not source then
                showError("Nguồn truyện không còn khả dụng.")
                return
            end
            self:showStoryActions(story, source, function(is_favorite)
                if options.favorites_only and not is_favorite then
                    view:removeStory(story)
                elseif options.downloads_only then
                    -- Usually hold action doesn't delete the download, but just refresh
                    view:refreshFavorites()
                else
                    view:refreshFavorites()
                end
            end)
        end,
    }
    UIManager:show(view)
end

function Browser:showDownloaded(on_return_callback)
    local downloaded = Storage:listDownloadedStories()
    if #downloaded == 0 then
        UIManager:show(InfoMessage:new{
            title = "Truyện Việt",
            text = "Chưa có truyện nào được tải." })
        on_return_callback()
        return
    end

    self:showStories("Truyện đã tải", downloaded, on_return_callback, { downloads_only = true })
end

function Browser:showFavorites(on_return_callback)
    self:showStories(
        "Tủ truyện",
        Storage:listFavorites(),
        on_return_callback,
        { favorites_only = true }
    )
end

function Browser:showHistory(on_return_callback)
    local history = Storage:getHistory()
    if #history == 0 then
        showError("Chưa có lịch sử đọc.", on_return_callback)
        return
    end

    local stories = {}
    local history_by_url = {}
    for _, item in ipairs(history) do
        table.insert(stories, item.story)
        history_by_url[item.story.source_id .. "|" .. item.story.url] = item
    end

    self:showStories(
        "Lịch sử đọc",
        stories,
        on_return_callback,
        {
            on_story_tap = function(story, view)
                local source = SourceRegistry:get(story.source_id)
                if not source then
                    showError("Nguồn truyện không còn khả dụng.")
                    return
                end
                local item = history_by_url[
                    story.source_id .. "|" .. story.url
                ]
                UIManager:show(ConfirmBox:new{
            title = "Truyện Việt",
            text = "Đọc tiếp: " .. item.chapter.title .. "?",
                    ok_text = "Đọc tiếp",
                    cancel_text = "Mục lục",
                    ok_callback = function()
                        closeAndRun(view, function()
                            self:loadStoryPage(story, source, 1, function()
                                self:showHistory(on_return_callback)
                            end, item.chapter)
                        end)
                    end,
                    cancel_callback = function()
                        closeAndRun(view, function()
                            self:loadStoryPage(story, source, 1, function()
                                self:showHistory(on_return_callback)
                            end)
                        end)
                    end,
                })
            end,
            on_story_hold = function(story, view)
                UIManager:show(ConfirmBox:new{
            title = "Truyện Việt",
            text = "Xóa khỏi lịch sử đọc?",
                    ok_text = "Xóa",
                    ok_callback = function()
                        Storage:removeHistory(story)
                        view:removeStory(story)
                        if #view.stories == 0 then
                            closeAndRun(view, on_return_callback)
                        end
                    end,
                })
            end,
        }
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
                local text = SourceRegistry:isEnabled(current_source.id) and "Đang bật" or "Đã tắt"
                if Storage:getCustomBaseUrl(current_source.id) then
                    text = text .. " (Tên miền tùy chỉnh)"
                end
                return text
            end,
            callback = function()
                local ok, err = SourceRegistry:setEnabled(
                    current_source.id,
                    not SourceRegistry:isEnabled(current_source.id)
                )
                if not ok then
                    showError(err)
                    return
                end
                closeAndRun(view, function()
                    self:showSourceManager(on_return_callback)
                end)
            end,
            hold_callback = function()
                closeAndRun(view, function()
                    local InputDialog = require("ui/widget/inputdialog")
                    local dialog
                    dialog = InputDialog:new{
                        title = "Đổi tên miền: " .. current_source.name,
                        input = Storage:getCustomBaseUrl(current_source.id) or current_source.base_url,
                        buttons = {
                            {
                                {
                                    text = "Mặc định",
                                    callback = function()
                                        local ok, err = Storage:setCustomBaseUrl(
                                            current_source.id,
                                            nil
                                        )
                                        if not ok then
                                            showError(err)
                                            return
                                        end
                                        closeAndRun(dialog, function()
                                            self:showSourceManager(on_return_callback)
                                        end)
                                    end,
                                },
                                {
                                    text = "Lưu",
                                    is_enter_default = true,
                                    callback = function()
                                        local new_url = dialog:getInputText()
                                        local ok, err = Storage:setCustomBaseUrl(
                                            current_source.id,
                                            new_url
                                        )
                                        if not ok then
                                            showError(err)
                                            return
                                        end
                                        closeAndRun(dialog, function()
                                            self:showSourceManager(on_return_callback)
                                        end)
                                    end,
                                },
                            },
                        },
                    }
                    UIManager:show(dialog)
                    dialog:onShowKeyboard()
                end)
            end,
        })
    end
    view = showView("Quản lý nguồn (giữ để đổi tên miền)", items, on_return_callback)
end

function Browser:getLocalChapters(story, source)
    local lfs = require("libs/libkoreader-lfs")
    local Storage = require("truyenviet/storage")
    local dir = Storage:getStoryDir(source, story)
    local chapters = {}
    local extension = source.kind == "comic" and ".cbz" or ".html"
    
    local ok = pcall(function()
        for file in lfs.dir(dir) do
            if file:sub(-#extension) == extension then
                local basename = file:sub(1, -(#extension + 1))
                table.insert(chapters, {
                    title = basename,
                    url = "local/" .. basename,
                    is_local = true,
                })
            end
        end
    end)
    
    if not ok or #chapters == 0 then
        return nil
    end
    
    table.sort(chapters, function(a, b)
        local function getLastNumber(s)
            local num
            for n in string.gmatch(s, "%d+") do
                num = tonumber(n)
            end
            return num
        end

        local num_a = getLastNumber(a.title)
        local num_b = getLastNumber(b.title)

        if num_a and num_b and num_a ~= num_b then
            return num_a < num_b
        end
        return a.title < b.title
    end)
    
    return chapters
end

function Browser:loadStoryPage(story, source, page, on_return_callback, auto_open_chapter)
    local function loadOnline()
        runOnline(function()
            local page_data, err = withLoading(
                string.format("Đang tải danh sách chương...\nTrang %d", page),
                function()
                    return source:getStoryPage(story, page)
                end
            )
            if not page_data then
                local local_chapters = self:getLocalChapters(story, source)
                if local_chapters then
                    page_data = {
                        story = story,
                        page = 1,
                        total_pages = 1,
                        chapters = local_chapters,
                    }
                    UIManager:show(InfoMessage:new{ text = "Đang hiển thị các chương ngoại tuyến." })
                else
                    showError(err, on_return_callback)
                    return
                end
            end
            Storage:updateFavorite(page_data.story)
            if auto_open_chapter then
                local chapter_to_open = type(auto_open_chapter) == "table" and auto_open_chapter or page_data.chapters[1]
                if chapter_to_open then
                    self:openChapter(nil, page_data, source, chapter_to_open, on_return_callback)
                else
                    self:showChapterList(page_data, source, on_return_callback)
                end
            else
                self:showChapterList(page_data, source, on_return_callback)
            end
        end)
    end

    local is_online = true
    if NetworkMgr and type(NetworkMgr.isWifiOn) == "function" then
        is_online = NetworkMgr:isWifiOn()
    elseif NetworkMgr and type(NetworkMgr.isWIFIOn) == "function" then
        is_online = NetworkMgr:isWIFIOn()
    elseif NetworkMgr and type(NetworkMgr.isOnline) == "function" then
        is_online = NetworkMgr:isOnline()
    end

    if not is_online then
        local local_chapters = self:getLocalChapters(story, source)
        if local_chapters then
            local page_data = {
                story = story,
                page = 1,
                total_pages = 1,
                chapters = local_chapters,
            }
            if auto_open_chapter then
                local chapter_to_open = type(auto_open_chapter) == "table" and auto_open_chapter or page_data.chapters[1]
                if chapter_to_open then
                    self:openChapter(nil, page_data, source, chapter_to_open, on_return_callback)
                else
                    self:showChapterList(page_data, source, on_return_callback)
                end
            else
                self:showChapterList(page_data, source, on_return_callback)
            end
            return
        end
    end

    loadOnline()
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
            UIManager:show(InfoMessage:new{
            title = "Truyện Việt",
            text = "Đã hủy tải các chương." })
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
        UIManager:show(InfoMessage:new{
            title = "Truyện Việt",
            text = message })
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
            title = "Truyện Việt",
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
            title = "Truyện Việt",
            text = warning,
        ok_text = "Tải các chương",
        ok_callback = function()
            UIManager:scheduleIn(0, function()
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
                toggleFavorite(story, function()
                    closeAndRun(view, function()
                        self:showChapterList(page_data, source, on_return_callback)
                    end)
                end)
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
                closeAndRun(view, function()
                    self:loadStoryPage(story, source, page_data.page - 1, on_return_callback)
                end)
            end,
        })
    end
    if page_data.page < page_data.total_pages then
        table.insert(items, {
            text = "Trang chương sau →",
            callback = function()
                closeAndRun(view, function()
                    self:loadStoryPage(story, source, page_data.page + 1, on_return_callback)
                end)
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

    local next_chapter
    for i, c in ipairs(page_data.chapters) do
        if c.url == chapter.url then
            if source.reversed_chapters then
                next_chapter = page_data.chapters[i - 1]
            else
                next_chapter = page_data.chapters[i + 1]
            end
            break
        end
    end

    local function on_next_chapter()
        if next_chapter then
            UIManager:show(Notification:new{ text = "Đang mở chương tiếp theo..." })
            UIManager:nextTick(function()
                self:openChapter(nil, page_data, source, next_chapter, on_return_callback)
            end)
        elseif source.reversed_chapters and page_data.page > 1 then
            UIManager:nextTick(function()
                self:loadStoryPage(story, source, page_data.page - 1, on_return_callback, true)
            end)
        elseif not source.reversed_chapters and page_data.page < page_data.total_pages then
            UIManager:nextTick(function()
                self:loadStoryPage(story, source, page_data.page + 1, on_return_callback, true)
            end)
        else
            UIManager:nextTick(function()
                UIManager:show(InfoMessage:new{
                title = "Truyện Việt",
                text = "Đã tới chương cuối cùng ở thời điểm hiện tại." })
            end)
        end
    end

    local existing = Builder:getExistingPath(source, story, chapter)
    if existing and not force then
        if view then UIManager:close(view) end
        Storage:saveHistory(story, chapter)
        Reader:show(existing, function()
            self:showChapterList(page_data, source, on_return_callback)
        end, on_next_chapter)
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
            if view then
                showError(fetch_err)
            else
                showError(fetch_err, function()
                    self:showChapterList(page_data, source, on_return_callback)
                end)
            end
            return
        end

        Storage:saveStoryMetadata(story)

        local action = source.kind == "comic" and "Đang tải ảnh và đóng gói CBZ..." or "Đang tạo tệp HTML..."
        local completed, path, build_err = Trapper:dismissableRunInSubprocess(
            function()
                return Builder:build(source, story, chapter, payload, force)
            end,
            action
        )

        if not completed then
            os.remove(Storage:getChapterPath(source, story, chapter) .. ".part")
            if view then
                UIManager:show(InfoMessage:new{
            title = "Truyện Việt",
            text = "Đã hủy tải chương." })
            else
                showError("Đã hủy tải chương.", function()
                    self:showChapterList(page_data, source, on_return_callback)
                end)
            end
            return
        end
        if not path then
            if view then
                showError(build_err)
            else
                showError(build_err, function()
                    self:showChapterList(page_data, source, on_return_callback)
                end)
            end
            return
        end

        if view then UIManager:close(view) end
        Storage:saveHistory(story, chapter)
        Reader:show(path, function()
            self:showChapterList(page_data, source, on_return_callback)
        end, on_next_chapter)
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
                    closeAndRun(dialog, function()
                        self:openChapter(
                            view,
                            page_data,
                            source,
                            chapter,
                            on_return_callback
                        )
                    end)
                end,
            },
        },
        {
            {
                text = "Tải lại chương",
                callback = function()
                    closeAndRun(dialog, function()
                        self:openChapter(
                            view,
                            page_data,
                            source,
                            chapter,
                            on_return_callback,
                            true
                        )
                    end)
                end,
            },
        },
    }
    if downloaded then
        table.insert(buttons, {
            {
                text = "Xóa bản đã tải",
                callback = function()
                    closeAndRun(dialog, function()
                        Storage:removeDownload(source, story, chapter)
                        view:updateItems()
                        UIManager:show(InfoMessage:new{
            title = "Truyện Việt",
            text = "Đã xóa bản tải." })
                    end)
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
