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
local CredentialManager = require("truyenviet/credential_manager")
local Reader = require("truyenviet/reader")
local SearchService = require("truyenviet/search_service")
local SourceRegistry = require("truyenviet/source_registry")
local Storage = require("truyenviet/storage")
local StoryResults = require("truyenviet/widgets/story_results")
local Version = require("truyenviet/version")
local Debug = require("truyenviet/debugger")
local EpubBuilder = require("truyenviet/epub_builder")
local HtmlBundleBuilder = require("truyenviet/html_bundle_builder")
local BundleExporter = require("truyenviet/bundle_exporter")
local Util = require("truyenviet/helpers")
local lfs = require("libs/libkoreader-lfs")

local ListView = Menu:extend{
    is_popout = false,
    title_bar_left_icon = "chevron.left",
}

function ListView:init()
    self.width = Screen:getWidth()
    self.height = Screen:getHeight()
    Menu.init(self)
end

function ListView:onLeftButtonTap()
    self:onClose()
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
    
    local dialog
    local buttons = {
        {
            {
                text = "Đóng",
                callback = function()
                    UIManager:close(dialog)
                    if on_close then UIManager:nextTick(on_close) end
                end,
            },
        }
    }
    
    local ErrorReporter = require("truyenviet/error_reporter")
    table.insert(buttons, 1, {
        {
            text = "Báo lỗi",
            callback = function()
                UIManager:close(dialog)
                Browser:showErrorReportDialog(tostring(message), on_close)
            end,
        }
    })

    dialog = ButtonDialog:new{
        title = "Thông báo lỗi",
        text = text,
        buttons = buttons,
    }
    UIManager:show(dialog)
end

local function closeAndRun(widget, callback)
    if widget then
        UIManager:close(widget)
    end
    if callback then
        UIManager:nextTick(callback)
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
            showError(err)
            return
        end
        showDetails(details)
    end)
end

function Browser:showErrorReportDialog(error_msg, on_close)
    local ErrorReporter = require("truyenviet/error_reporter")
    local dialog
    dialog = InputDialog:new{
        title = "Gửi báo lỗi",
        input_hint = "Mô tả lỗi bạn gặp phải (tùy chọn)",
        buttons = {
            {
                {
                    text = "Đóng",
                    callback = function()
                        closeAndRun(dialog, on_close)
                    end,
                },
                {
                    text = "Chép log",
                    callback = function()
                        local user_desc = dialog:getInputValue()
                        closeAndRun(dialog, function()
                            local ok, msg = ErrorReporter:copyReportToClipboard(user_desc, error_msg, true)
                            if ok then
                                ErrorReporter:clearLogAfterSubmit()
                                UIManager:show(require("ui/widget/infomessage"):new({
                                    text = msg,
                                }))
                            else
                                UIManager:show(require("ui/widget/infomessage"):new({
                                    text = "Lỗi chép log: " .. tostring(msg),
                                }))
                            end
                            if on_close then UIManager:nextTick(on_close) end
                        end)
                    end,
                }
            }
        }
    }
    UIManager:show(dialog)
end

function Browser:showStoryActions(story, source, refresh_callback)
    local dialog
    local buttons = {
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
        {
            {
                text = "Mở thư mục truyện",
                callback = function()
                    closeAndRun(dialog, function()
                        local Storage = require("truyenviet/storage")
                        local story_dir = Storage:getStoryDir(source, story)
                        local FileManager = require("apps/filemanager/filemanager")
                        local ReaderUI = require("apps/reader/readerui")
                        if ReaderUI.instance then
                            ReaderUI.instance:onClose()
                        end
                        FileManager:showFiles(story_dir)
                    end)
                end,
            },
        },
    }

    if Storage:isFavorite(story) then
        table.insert(buttons, 2, {
            {
                text = "Tải lại ảnh bìa",
                callback = function()
                    closeAndRun(dialog, function()
                        if story.cover_path then
                            os.remove(story.cover_path)
                            story.cover_path = nil
                        end
                        withLoading("Đang tải lại ảnh bìa...", function()
                            local CoverCache = require("truyenviet/cover_cache")
                            CoverCache:download(story, source)
                        end)
                        if refresh_callback then refresh_callback(true) end
                    end)
                end,
            }
        })
    end

    dialog = ButtonDialog:new{
        title = story.title,
        buttons = buttons,
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
    table.insert(items, {
        text = "Đọc truyện",
        mandatory_func = function()
            return tostring(#SourceRegistry:listEnabled()) .. " nguồn"
        end,
        callback = function()
            closeAndRun(view, function()
                self:showSourceMenu(function()
                    self:showRoot()
                end)
            end)
        end,
    })
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
            text = "Xóa tất cả Lịch sử đọc",
            callback = function()
                local ConfirmBox = require("ui/widget/confirmbox")
                UIManager:show(ConfirmBox:new{
                    text = "Bạn có chắc chắn muốn xóa TẤT CẢ Lịch sử đọc không?",
                    ok_text = "Xóa",
                    cancel_text = "Hủy",
                    ok_callback = function()
                        Storage:clearAllHistory(false)
                        UIManager:show(InfoMessage:new{
                            title = "Truyện Việt",
                            text = "Đã xóa toàn bộ lịch sử đọc."
                        })
                    end,
                })
            end,
        })
        table.insert(items, {
            text = "Xóa tất cả Tủ truyện",
            callback = function()
                local ConfirmBox = require("ui/widget/confirmbox")
                UIManager:show(ConfirmBox:new{
                    text = "Bạn có chắc chắn muốn xóa TẤT CẢ truyện khỏi Tủ truyện không?",
                    ok_text = "Xóa",
                    cancel_text = "Hủy",
                    ok_callback = function()
                        Storage:clearAllFavorites(false)
                        UIManager:show(InfoMessage:new{
                            title = "Truyện Việt",
                            text = "Đã xóa toàn bộ tủ truyện."
                        })
                    end,
                })
            end,
        })
        table.insert(items, {
            text = "Xóa tất cả truyện đã tải",
            callback = function()
                local ConfirmBox = require("ui/widget/confirmbox")
                UIManager:show(ConfirmBox:new{
                    text = "Bạn có chắc chắn muốn xóa TẤT CẢ truyện đã tải không?\nThao tác này không thể hoàn tác.",
                    ok_text = "Xóa",
                    cancel_text = "Hủy",
                    ok_callback = function()
                        local ok, err = Storage:removeAllDownloads()
                        if ok then
                            UIManager:show(InfoMessage:new{
                                title = "Truyện Việt",
                                text = "Đã xóa toàn bộ truyện tải về."
                            })
                        else
                            showError("Lỗi khi xóa: " .. tostring(err))
                        end
                    end,
                })
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
        text = "Gửi báo lỗi / Xem log",
        callback = function()
            closeAndRun(view, function()
                self:showErrorReportDialog("", function()
                    self:showRoot()
                end)
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
                local lines = {
                    "Đọc truyện và tải ebook trực tuyến trong KOReader.",
                    "",
                }
                for _, src in ipairs(SourceRegistry:listAll()) do
                    local kind_label = src.kind == "ebook" and "Ebook"
                        or (src.kind == "comic" and "Truyện tranh" or "Truyện chữ")
                    table.insert(lines, string.format("- %s (%s): %s", src.name, kind_label, tostring(src.base_url)))
                end
                table.insert(lines, "")
                table.insert(lines, "Chương truyện và ebook được lưu vào thư mục truyenviet trong thư mục dữ liệu KOReader.")
                table.insert(lines, "Nội dung và ảnh thuộc về các website nguồn và chủ sở hữu tương ứng.")
                UIManager:show(TextViewer:new{
                    title = "Truyện Việt",
                    text = table.concat(lines, "\n"),
                })
            end,
        })
    view = showView("Truyện Việt", items)
end

function Browser:showSourceMenu(on_return_callback)
    local view
    local items = {}
    for _, source in ipairs(SourceRegistry:listAll()) do
        local current_source = source
        table.insert(items, {
            text = current_source.name,
            mandatory_func = function()
                local note = SourceRegistry:getAvailabilityNote(current_source)
                if not SourceRegistry:isEnabled(current_source.id) then
                    return note and (note .. " · Đã tắt") or "Đã tắt · chạm để bật"
                end
                if note then
                    return note
                end
                if current_source.kind == "ebook" then
                    return "EBOOK"
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
                    current_source = SourceRegistry:get(current_source.id) or current_source
                end
                closeAndRun(view, function()
                    if current_source.kind == "ebook" then
                        self:browseEbookSource(current_source, function()
                            self:showSourceMenu(on_return_callback)
                        end)
                    else
                        self:browseSource(current_source, nil, 1, function()
                            self:showSourceMenu(on_return_callback)
                        end)
                    end
                end)
            end,
        })
    end

    view = showView("Đọc truyện", items, on_return_callback)
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
            showError("Chưa có nguồn nào được bật.", on_return_callback)
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

        if parent_view and type(parent_view.onClose) == "function" then
            UIManager:close(parent_view)
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
    end)
end

function Browser:browseSource(source, genre, local_page, on_return_callback)
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
                    genre and genre.name or (source.id == "docln" and "truyện dịch" or "truyện đã hoàn thành"),
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
                result.stories = result.stories or {}
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
            showError(err, on_return_callback)
            return
        end
        if #result.stories == 0 then
            local ConfirmBox = require("ui/widget/confirmbox")
            UIManager:show(ConfirmBox:new{
                title = "Truyện Việt",
                text = "Không có truyện ở trang này.",
                ok_text = "Đóng",
                ok_callback = function()
                    if on_return_callback then
                        UIManager:nextTick(on_return_callback)
                    end
                end,
            })
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
            UIManager:show(Notification:new{
                text = string.format("Đã chuyển tới trang %d", local_page)
            })
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
                    on_genres = function(return_to_listing)
                        self:showGenreMenu(
                            source,
                            result.genres,
                            return_to_listing
                        )
                    end,
                    on_prev_page = local_page > 1 and function()
                        self:browseSource(
                            source,
                            genre,
                            local_page - 1,
                            on_return_callback
                        )
                    end or nil,
                    on_next_page = local_page < local_total_pages and function()
                        self:browseSource(
                            source,
                            genre,
                            local_page + 1,
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
                closeAndRun(view, function()
                    self:browseSource(source, current_genre, 1, function()
                        self:showGenreMenu(source, genres, on_return_callback)
                    end)
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
        local ConfirmBox = require("ui/widget/confirmbox")
        UIManager:show(ConfirmBox:new{
            title = title,
            text = "Không có truyện khả dụng.",
            ok_text = "Đóng",
            ok_callback = function()
                if on_return_callback then
                    UIManager:nextTick(on_return_callback)
                end
            end,
        })
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
            closeAndRun(view, options.on_prev_page)
        end or nil,
        server_next_callback = options.on_next_page and function()
            closeAndRun(view, options.on_next_page)
        end or nil,
        right_icon = options.right_icon,
        right_icon_tap_callback = options.right_icon_tap_callback,
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
            local function returnToCurrentStories()
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
            end
            closeAndRun(view, function()
                if source.kind == "ebook" then
                    self:openEbookItem(source, story, returnToCurrentStories)
                else
                    self:loadStoryPage(story, source, 1, returnToCurrentStories)
                end
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
            if source.kind == "ebook" then
                closeAndRun(view, function()
                    self:openEbookItem(source, story, function()
                        self:showStories(title, stories, on_return_callback, options)
                    end)
                end)
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
    local favorites = Storage:listFavorites()
    
    self:showStories(
        "Tủ truyện",
        favorites,
        on_return_callback,
        {
            favorites_only = true,
        }
    )
end

function Browser:showHistory(on_return_callback)
    local history = Storage:getHistory()
    if #history == 0 then
        local ConfirmBox = require("ui/widget/confirmbox")
        UIManager:show(ConfirmBox:new{
            title = "Truyện Việt",
            text = "Chưa có lịch sử đọc.",
            ok_text = "Đóng",
            ok_callback = function()
                if on_return_callback then
                    UIManager:nextTick(on_return_callback)
                end
            end,
        })
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
            -- No right icon
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
                local note = SourceRegistry:getAvailabilityNote(current_source)
                if note then
                    text = text .. " · " .. note
                end
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
        local num_a = tonumber(string.match(a.title, "%d+"))
        local num_b = tonumber(string.match(b.title, "%d+"))
        if num_a and num_b and num_a ~= num_b then
            return num_a < num_b
        end
        return a.title < b.title
    end)

    if source.reversed_chapters then
        local rev = {}
        for i = #chapters, 1, -1 do
            table.insert(rev, chapters[i])
        end
        chapters = rev
    end

    return chapters
end

function Browser:openEbookItem(source, item, on_return_callback)
    if not source then
        showError("Nguồn ebook không khả dụng.", on_return_callback)
        return
    end
    if source.id == "dilib" then
        self:showDilibBookDetail(source, item, on_return_callback)
    else
        self:browseEbookSource(source, on_return_callback)
    end
end

function Browser:showPageJumpDialog(current_page, total_pages, on_select_page)
    local dialog
    dialog = InputDialog:new{
        title = string.format("Nhảy tới trang (1 - %d)", total_pages),
        input = tostring(current_page or 1),
        input_hint = string.format("Nhập số trang từ 1 đến %d", total_pages),
        input_type = "number",
        buttons = {
            {
                {
                    text = "Hủy",
                    callback = function()
                        UIManager:close(dialog)
                    end,
                },
                {
                    text = "Đi tới",
                    is_enter_default = true,
                    callback = function()
                        local target = tonumber(dialog:getInputText())
                        UIManager:close(dialog)
                        if target and target >= 1 and target <= total_pages then
                            on_select_page(math.floor(target))
                        else
                            showError(string.format("Số trang không hợp lệ (cần từ 1 đến %d).", total_pages))
                        end
                    end,
                },
            },
        },
    }
    UIManager:show(dialog)
    dialog:onShowKeyboard()
end

local function resolveAutoOpenChapter(source, page_data, auto_open_chapter)
    if type(auto_open_chapter) == "table" then
        return auto_open_chapter
    end
    local chapters = page_data and page_data.chapters or {}
    if source and source.reversed_chapters then
        return chapters[#chapters]
    end
    return chapters[1]
end

function Browser:loadStoryPage(story, source, page, on_return_callback, auto_open_chapter, from_reader)
    local function loadOnline()
        runOnline(function()
            local page_data, err = withLoading(
                string.format("Đang tải danh sách chương...\nTrang %d", page),
                function()
                    return source:getStoryPage(story, page)
                end
            )
            if not page_data then
                showError(err, on_return_callback)
                return
            end
            Storage:updateFavorite(page_data.story)
            if auto_open_chapter then
                local chapter_to_open = resolveAutoOpenChapter(source, page_data, auto_open_chapter)
                if chapter_to_open then
                    self:openChapter(nil, page_data, source, chapter_to_open, on_return_callback, false, from_reader)
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
                local chapter_to_open = resolveAutoOpenChapter(source, page_data, auto_open_chapter)
                if chapter_to_open then
                    self:openChapter(nil, page_data, source, chapter_to_open, on_return_callback, false, from_reader)
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

local Widget = require("ui/widget/widget")
local FloatingProgress = Widget:extend{
    text = "",
    init = function(self)
        local TextWidget = require("ui/widget/textwidget")
        local FrameContainer = require("ui/widget/container/framecontainer")
        local Size = require("ui/size")
        local Font = require("ui/font")
        local Blitbuffer = require("ffi/blitbuffer")
        
        self.text_w = TextWidget:new{
            text = self.text,
            face = Font:getFace("infofont", 18),
            fgcolor = Blitbuffer.COLOR_BLACK,
        }
        
        self.frame = FrameContainer:new{
            padding = Size.padding.small,
            margin = 0,
            bordersize = 2,
            background = Blitbuffer.COLOR_WHITE,
            self.text_w
        }
        self:updateGeom()
    end,
    updateGeom = function(self)
        local Screen = require("device").screen
        local Geom = require("ui/geometry")
        
        if self.frame.freeSizing then self.frame:freeSizing() end
        local size = self.frame:getSize()
        
        self.w = size.w
        self.h = size.h
        self.x = 10
        self.y = Screen:getHeight() - self.h - 10
        
        self.dimen = Geom:new{ x = self.x, y = self.y, w = self.w, h = self.h }
    end,
    paintTo = function(self, b, x, y)
        self.frame.dimen = self.dimen
        self.frame:paintTo(b, self.x, self.y)
    end,
    -- The indicator is the top window while a task runs, so it receives taps.
    -- Cancellable tasks set `on_tap`; others keep the previous behaviour.
    onGesture = function(self, ges)
        if self.on_tap and ges and ges.ges == "tap" and ges.pos and self.dimen
                and ges.pos:intersectWith(self.dimen) then
            self.on_tap()
            return true
        end
    end,
    setText = function(self, text)
        if self.text == text then return end
        self.text = text
        local old_dim = { x = self.dimen.x, y = self.dimen.y, w = self.dimen.w, h = self.dimen.h }
        
        self.text_w:setText(text)
        self:updateGeom()
        
        local UIManager = require("ui/uimanager")
        local Geom = require("ui/geometry")
        
        local min_x = math.min(old_dim.x, self.dimen.x)
        local min_y = math.min(old_dim.y, self.dimen.y)
        local max_right = math.max(old_dim.x + old_dim.w, self.dimen.x + self.dimen.w)
        local max_bottom = math.max(old_dim.y + old_dim.h, self.dimen.y + self.dimen.h)
        
        local dirty_region = Geom:new{
            x = min_x,
            y = min_y,
            w = max_right - min_x,
            h = max_bottom - min_y
        }
        UIManager:setDirty(nil, "ui", dirty_region)
    end,
    bringToFront = function(self)
        local UIManager = require("ui/uimanager")
        UIManager:close(self)
        UIManager:show(self)
        local Geom = require("ui/geometry")
        UIManager:setDirty(nil, "ui", Geom:new{ x = self.dimen.x, y = self.dimen.y, w = self.dimen.w, h = self.dimen.h })
    end
}

-- Run `task_func(ctx)` as a coroutine driven by the UI loop.  The task yields
-- progress strings.  With `opts.cancellable`, tapping the indicator asks for
-- confirmation and sets ctx.isCancelled(); the task must check it and clean up.
local function runInBackground(task_name, task_func, on_complete, opts)
    opts = opts or {}
    local ctx = { cancelled = false }
    function ctx.isCancelled() return ctx.cancelled end

    local indicator = FloatingProgress:new{
        text = "Đang tải ngầm: " .. task_name
    }
    local confirm_open = false
    if opts.cancellable then
        indicator.on_tap = function()
            if confirm_open or ctx.cancelled then return end
            confirm_open = true
            UIManager:show(ConfirmBox:new{
                title = "Truyện Việt",
                text = "Dừng tác vụ đang chạy?\n" .. task_name,
                ok_text = "Dừng",
                cancel_text = "Tiếp tục",
                ok_callback = function()
                    confirm_open = false
                    ctx.cancelled = true
                    indicator:setText("Đang dừng...")
                end,
                cancel_callback = function()
                    confirm_open = false
                end,
            })
        end
    end
    UIManager:show(indicator)
    
    local co = coroutine.create(task_func)
    local final_result = nil
    local function tick()
        if coroutine.status(co) ~= "dead" then
            local ok, result = coroutine.resume(co, ctx)
            if not ok then
                UIManager:close(indicator)
                UIManager:show(InfoMessage:new{
                    title = "Truyện Việt - Lỗi tải",
                    text = "Lỗi khi chạy tải ngầm:\n" .. tostring(result),
                })
            else
                if coroutine.status(co) == "dead" then
                    final_result = result
                elseif type(result) == "string" then
                    local hint = opts.cancellable and not ctx.cancelled and " (chạm để dừng)" or ""
                    indicator:setText(result .. hint)
                    -- Do not cover the cancel confirmation dialog.
                    if not confirm_open then
                        indicator:bringToFront()
                    end
                end
                UIManager:scheduleIn(0.05, tick)
            end
        else
            UIManager:close(indicator)
            UIManager:show(Notification:new{
                text = (ctx.cancelled and "Đã dừng: " or "Tải ngầm hoàn tất: ") .. task_name,
            })
            if on_complete then on_complete(final_result) end
        end
    end
    UIManager:scheduleIn(0, tick)
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
        runInBackground(string.format("Tải %d chương...", #chapters), function()
            return ChapterDownloader:download(source, story, chapters)
        end, function(result)
            if type(result) ~= "table" then
                ChapterDownloader:cleanupPartials(source, story, chapters)
                showError("Lỗi tải chương không mong muốn")
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
    end)
end

local function orderChaptersForReading(source, chapters)
    if not (source and source.reversed_chapters) or type(chapters) ~= "table" then
        return chapters or {}
    end
    local ordered = {}
    for i = #chapters, 1, -1 do
        table.insert(ordered, chapters[i])
    end
    return ordered
end

local function fetchAllChaptersInReadingOrder(source, story, total_pages)
    local all_chapters = {}
    for p = 1, total_pages do
        local p_data = source:getStoryPage(story, p)
        if p_data and p_data.chapters and #p_data.chapters > 0 then
            for _, c in ipairs(p_data.chapters) do
                table.insert(all_chapters, c)
            end
        else
            break
        end
    end
    all_chapters = Util.uniqueBy(all_chapters, "url")
    return orderChaptersForReading(source, all_chapters)
end

function Browser:confirmDownloadChapters(view, page_data, source)
    local story = page_data.story
    local warning = "Tiến hành tải tất cả các chương chưa có của truyện này?"
    if source.kind == "comic" then
        warning = warning .. "\n\nTruyện tranh có thể tốn nhiều thời gian và dung lượng lưu trữ."
    end
    UIManager:show(ConfirmBox:new{
        title = "Truyện Việt",
        text = warning,
        ok_text = "Tải các chương",
        ok_callback = function()
            UIManager:scheduleIn(0, function()
                if page_data.total_pages > 1 then
                    runOnline(function()
                        local all_chapters = {}
                        local fetch_ok = false
                        local _, err = withLoading("Đang lấy danh sách toàn bộ chương...", function()
                            all_chapters = fetchAllChaptersInReadingOrder(source, story, page_data.total_pages)
                            fetch_ok = true
                            return true
                        end)
                        if fetch_ok then
                            local pending = ChapterDownloader:listPending(source, story, all_chapters)
                            local already_downloaded = #all_chapters - #pending
                            if #pending == 0 then
                                UIManager:show(InfoMessage:new{
                                    title = "Truyện Việt",
                                    text = "Tất cả các chương đã được tải.",
                                })
                                return
                            end
                            self:downloadChapters(view, {story = story, chapters = all_chapters, page = 1, total_pages = 1}, source, pending, already_downloaded)
                        else
                            showError(err or "Lỗi khi lấy danh sách chương")
                        end
                    end)
                else
                    local ordered = orderChaptersForReading(source, page_data.chapters)
                    local pending = ChapterDownloader:listPending(source, story, ordered)
                    local already_downloaded = #ordered - #pending
                    if #pending == 0 then
                        UIManager:show(InfoMessage:new{
                            title = "Truyện Việt",
                            text = "Tất cả các chương đã được tải.",
                        })
                        return
                    end
                    self:downloadChapters(view, page_data, source, pending, already_downloaded)
                end
            end)
        end,
    })
end

function Browser:confirmDownloadBundle(view, page_data, source, format)
    local story = page_data.story
    format = format or "html"
    local label = format == "epub" and "EPUB" or "HTML"
    local warning = "Tiến hành tải toàn bộ chương và đóng gói thành 1 file " .. label .. "?\n\nQuá trình này có thể mất nhiều thời gian tuỳ thuộc vào số lượng chương."

    local function download(chapters)
        if format == "epub" then
            self:downloadAsEpub(story, source, chapters)
        else
            self:downloadAsBundle(story, source, chapters)
        end
    end
    
    UIManager:show(ConfirmBox:new{
        title = "Truyện Việt",
        text = warning,
        ok_text = "Tải thành 1 bộ",
        ok_callback = function()
            UIManager:scheduleIn(0, function()
                if page_data.total_pages > 1 then
                    runOnline(function()
                        local all_chapters = {}
                        local fetch_ok = false
                        local _, err = withLoading("Đang lấy danh sách toàn bộ chương...", function()
                            all_chapters = fetchAllChaptersInReadingOrder(source, story, page_data.total_pages)
                            fetch_ok = true
                            return true
                        end)
                        if fetch_ok then
                            download(all_chapters)
                        else
                            showError(err or "Lỗi khi lấy danh sách chương")
                        end
                    end)
                else
                    download(orderChaptersForReading(source, page_data.chapters))
                end
            end)
        end,
    })
end

function Browser:downloadAsEpub(story, source, all_chapters)
    self:exportBundle(story, source, all_chapters, "epub")
end

function Browser:downloadAsBundle(story, source, all_chapters)
    self:exportBundle(story, source, all_chapters, "html")
end

-- Shared "whole story as one file" export.  File layout lives in
-- HtmlBundleBuilder / EpubBuilder; the chapter loop in BundleExporter.
function Browser:exportBundle(story, source, all_chapters, format)
    local label = format == "epub" and "EPUB" or "HTML"
    if type(all_chapters) ~= "table" or #all_chapters == 0 then
        showError("Không có chương nào để tải.")
        return
    end
    local story_dir = Storage:getStoryDir(source, story)
    local out_path = story_dir .. "/" .. Util.safeName(story.title, "truyen") .. "." .. format

    local function start()
        runOnline(function()
            runInBackground(string.format("Đóng %s %d chương", label, #all_chapters), function(ctx)
                local cover_path = self:prepareBundleCover(story, source)
                local writer, create_err
                if format == "epub" then
                    writer, create_err = EpubBuilder.new(out_path, story, source, { cover_path = cover_path })
                else
                    local cover_filename
                    if cover_path then
                        cover_filename = self:copyCoverNextTo(cover_path, story_dir)
                    end
                    writer, create_err = HtmlBundleBuilder.new(out_path, story, { cover_filename = cover_filename })
                end
                if not writer then
                    return { error = create_err }
                end
                return BundleExporter.run({
                    source = source,
                    chapters = all_chapters,
                    writer = writer,
                    progress = function(text) coroutine.yield(text) end,
                    is_cancelled = ctx and ctx.isCancelled,
                })
            end, function(result)
                if type(result) ~= "table" then
                    showError("Không nhận được kết quả khi tạo " .. label)
                elseif result.cancelled then
                    UIManager:show(Notification:new{ text = "Đã dừng tạo " .. label .. ", không lưu tệp." })
                elseif result.error then
                    showError(result.error)
                else
                    if G_reader_settings and G_reader_settings.addDocument then
                        G_reader_settings:addDocument(result.path)
                        G_reader_settings:flush()
                    end
                    UIManager:show(ConfirmBox:new{
                        title = "Truyện Việt",
                        text = BundleExporter.summary(result, label),
                        ok_text = "Mở",
                        cancel_text = "Đóng",
                        ok_callback = function()
                            self:openEbookFile(result.path)
                        end,
                    })
                end
            end, { cancellable = true })
        end)
    end

    if lfs.attributes(out_path, "mode") == "file" then
        UIManager:show(ConfirmBox:new{
            title = "Truyện Việt",
            text = "Tệp đã tồn tại:\n" .. out_path .. "\n\nGhi đè bằng bản mới?",
            ok_text = "Ghi đè",
            cancel_text = "Hủy",
            ok_callback = start,
        })
    else
        start()
    end
end

-- Returns a local cover image path when the story has a usable cover.
function Browser:prepareBundleCover(story, source)
    if not (story.cover_url or story.cover_path) then
        return nil
    end
    pcall(CoverCache.download, CoverCache, story, source)
    if story.cover_path and lfs.attributes(story.cover_path, "mode") == "file" then
        return story.cover_path
    end
end

-- HTML bundles reference the cover by relative path next to the HTML file.
function Browser:copyCoverNextTo(cover_path, dir)
    local ext = (cover_path:match("%.([%w]+)$") or "jpg"):lower()
    local filename = "cover." .. ext
    local inf = io.open(cover_path, "rb")
    if not inf then return nil end
    local data = inf:read("*a")
    inf:close()
    local outf = io.open(dir .. "/" .. filename, "wb")
    if not outf then return nil end
    outf:write(data)
    outf:close()
    return filename
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
            text = "Tải tất cả các chương",
            callback = function()
                self:confirmDownloadChapters(view, page_data, source)
            end,
        })
        if source.kind == "text" then
            table.insert(items, {
                text = "Tải thành HTML (gom tất cả chương)",
                callback = function()
                    self:confirmDownloadBundle(view, page_data, source, "html")
                end,
            })
            table.insert(items, {
                text = "Tải thành EPUB (gom tất cả chương)",
                callback = function()
                    self:confirmDownloadBundle(view, page_data, source, "epub")
                end,
            })
        end
    end

    if page_data.total_pages > 1 then
        table.insert(items, {
            text = string.format("Trang %d / %d (chạm để nhảy trang)", page_data.page, page_data.total_pages),
            callback = function()
                self:showPageJumpDialog(page_data.page, page_data.total_pages, function(target_page)
                    closeAndRun(view, function()
                        self:loadStoryPage(story, source, target_page, on_return_callback)
                    end)
                end)
            end,
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
    if source.reversed_chapters and page_data.total_pages > 1 then
        if page_data.page < page_data.total_pages then
            table.insert(items, {
                text = "↓ Tới trang cuối (Chương đầu)",
                callback = function()
                    closeAndRun(view, function()
                        self:loadStoryPage(story, source, page_data.total_pages, on_return_callback)
                    end)
                end,
            })
        end
        if page_data.page > 1 then
            table.insert(items, {
                text = "↑ Tới trang đầu (Chương mới nhất)",
                callback = function()
                    closeAndRun(view, function()
                        self:loadStoryPage(story, source, 1, on_return_callback)
                    end)
                end,
            })
        end
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

function Browser:openChapter(view, page_data, source, chapter, on_return_callback, force, from_reader)
    local story = page_data.story

    local logger = require("logger")
    logger.info("TruyenViet: openChapter called: url=" .. tostring(chapter.url) .. ", from_reader=" .. tostring(from_reader))
    Debug.write("Browser: openChapter called: url=" .. tostring(chapter.url) .. ", from_reader=" .. tostring(from_reader))

    local next_chapter
    for i, c in ipairs(page_data.chapters) do
        local match = false
        if c.url == chapter.url then
            match = true
        elseif c.is_local and chapter.is_local and c.title == chapter.title then
            match = true
        elseif c.is_local and not chapter.is_local then
            if c.title == chapter.title or c.url == ("local/" .. chapter.title) then
                match = true
            end
        end
        
        if match then
            if source.reversed_chapters then
                next_chapter = page_data.chapters[i - 1]
            else
                next_chapter = page_data.chapters[i + 1]
            end
            break
        end
    end

    local function on_next_chapter(called_from_reader)
        local from_reader_flag = (called_from_reader ~= nil) and called_from_reader or from_reader
        Debug.write("Browser:on_next_chapter triggered, next_chapter=" .. tostring(next_chapter ~= nil) .. ", from_reader=" .. tostring(from_reader_flag))
        UIManager:nextTick(function()
            if next_chapter then
                    if from_reader_flag then
                        -- Return to plugin UI first, then open next chapter from plugin context
                        Reader:returnToPlugin(function()
                            self:openChapter(nil, page_data, source, next_chapter, on_return_callback, false, from_reader_flag)
                        end)
                    else
                        self:openChapter(nil, page_data, source, next_chapter, on_return_callback, false, from_reader_flag)
                    end
                elseif page_data.total_pages > 1 then
                    if source.reversed_chapters and page_data.page > 1 then
                        if from_reader_flag then
                            Reader:returnToPlugin(function()
                                self:loadStoryPage(story, source, page_data.page - 1, on_return_callback, true, from_reader_flag)
                            end)
                        else
                            self:loadStoryPage(story, source, page_data.page - 1, on_return_callback, true, from_reader_flag)
                        end
                    elseif not source.reversed_chapters and page_data.page < page_data.total_pages then
                        if from_reader_flag then
                            Reader:returnToPlugin(function()
                                self:loadStoryPage(story, source, page_data.page + 1, on_return_callback, true, from_reader_flag)
                            end)
                        else
                            self:loadStoryPage(story, source, page_data.page + 1, on_return_callback, true, from_reader_flag)
                        end
                    else
                        UIManager:show(InfoMessage:new{
                        title = "Truyện Việt",
                        text = "Đã tới chương cuối cùng ở thời điểm hiện tại." })
                    end
                else
                    UIManager:show(InfoMessage:new{
                    title = "Truyện Việt",
                    text = "Đã tới chương cuối cùng ở thời điểm hiện tại." })
                end
            end)
        end

    local existing = Builder:getExistingPath(source, story, chapter)
    if existing and not force then
        if view then UIManager:close(view) end
        Storage:saveHistory(story, chapter)
        Debug.write("Browser:existing found, calling Reader:show existing=" .. tostring(existing) .. ", from_reader=" .. tostring(from_reader))
        Reader:show(existing, function()
            self:showChapterList(page_data, source, on_return_callback)
            end, on_next_chapter, from_reader)
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

        local action = source.kind == "comic" and "Đang tải ảnh và đóng gói CBZ..." or "Đang tạo tệp HTML..."
        local completed, path, build_err = Trapper:dismissableRunInSubprocess(
            function()
                return Builder:build(source, story, chapter, payload, force, true)
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
        Debug.write("Browser:build completed, path=" .. tostring(path) .. ", from_reader=" .. tostring(from_reader))
        Reader:show(path, function()
            self:showChapterList(page_data, source, on_return_callback)
        end, on_next_chapter, from_reader)
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
                            on_return_callback,
                            false
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

-- ============================
-- EBOOK SOURCE BROWSING (TVE-4U, Dilib)
-- ============================

function Browser:showLoginDialog(source, on_success, on_cancel)
    local dialog
    local existing = CredentialManager:getCredential(source.id)
    dialog = InputDialog:new{
        title = "Đăng nhập " .. source.name,
        input = existing and existing.username or "",
        input_hint = "Email / Tên đăng nhập",
        buttons = {
            {
                {
                    text = "Quay lại",
                    callback = function()
                        closeAndRun(dialog, on_cancel)
                    end,
                },
                {
                    text = "Đăng nhập",
                    is_enter_default = true,
                    callback = function()
                        local username = dialog:getInputText()
                        if username == "" then return end
                        closeAndRun(dialog, function()
                            self:showPasswordDialog(source, username, on_success, on_cancel)
                        end)
                    end,
                },
            },
        },
    }
    UIManager:show(dialog)
    dialog:onShowKeyboard()
end

function Browser:showPasswordDialog(source, username, on_success, on_cancel)
    local dialog
    dialog = InputDialog:new{
        title = "Mật khẩu cho " .. username,
        input_hint = "Mật khẩu",
        text_type = "password",
        buttons = {
            {
                {
                    text = "Quay lại",
                    callback = function()
                        closeAndRun(dialog, function()
                            self:showLoginDialog(source, on_success, on_cancel)
                        end)
                    end,
                },
                {
                    text = "Đăng nhập",
                    is_enter_default = true,
                    callback = function()
                        local password = dialog:getInputText()
                        if password == "" then return end
                        closeAndRun(dialog, function()
                            runOnline(function()
                                local result, err = withLoading("Đang đăng nhập...", function()
                                    local ok, login_err = source:login(username, password)
                                    if not ok then
                                        error(login_err or "Đăng nhập thất bại")
                                    end
                                    -- Save credentials on success
                                    CredentialManager:saveCredential(source.id, username, password)
                                    return true
                                end)
                                if result then
                                    UIManager:show(Notification:new{
                                        text = "Đăng nhập thành công!",
                                    })
                                    if on_success then
                                        UIManager:nextTick(on_success)
                                    end
                                else
                                    showError(err, function()
                                        self:showLoginDialog(source, on_success, on_cancel)
                                    end)
                                end
                            end)
                        end)
                    end,
                },
            },
        },
    }
    UIManager:show(dialog)
    dialog:onShowKeyboard()
end

function Browser:browseEbookSource(source, on_return_callback)
    if source.id == "dilib" then
        self:browseDilib(source, on_return_callback)
    else
        showError("Nguồn ebook không được hỗ trợ.", on_return_callback)
    end
end

-- ============ DILIB ============

function Browser:browseDilib(source, on_return_callback)
    local categories = source.getLibraryCategories and source:getLibraryCategories() or source:getCategories()
    local audio_categories = source.getAudioCategories and source:getAudioCategories() or {}
    local view
    local items = {
        {
            text = "Tìm kiếm trên Dilib",
            callback = function()
                self:showDilibSearchDialog(source, function()
                    self:browseDilib(source, on_return_callback)
                end, view)
            end,
        },
    }

    if #audio_categories > 0 then
        table.insert(items, {
            text = "🔊 Sách nói & Radio (chỉ nghe MP3)",
            mandatory = tostring(#audio_categories) .. " mục",
            callback = function()
                closeAndRun(view, function()
                    self:browseDilibAudio(source, function()
                        self:browseDilib(source, on_return_callback)
                    end)
                end)
            end,
        })
    end

    for _, cat in ipairs(categories) do
        local current_cat = cat
        table.insert(items, {
            text = current_cat.name,
            callback = function()
                closeAndRun(view, function()
                    self:showDilibBookList(source, current_cat, 1, function()
                        self:browseDilib(source, on_return_callback)
                    end)
                end)
            end,
        })
    end

    view = showView("Dilib · Thư Viện Số", items, on_return_callback)
end

function Browser:browseDilibAudio(source, on_return_callback)
    local audio_categories = source.getAudioCategories and source:getAudioCategories() or {}
    local view
    local items = {}
    for _, cat in ipairs(audio_categories) do
        local current_cat = cat
        table.insert(items, {
            text = current_cat.name,
            callback = function()
                closeAndRun(view, function()
                    self:showDilibBookList(source, current_cat, 1, function()
                        self:browseDilibAudio(source, on_return_callback)
                    end)
                end)
            end,
        })
    end
    view = showView("Dilib · Sách nói & Radio", items, on_return_callback)
end

function Browser:showDilibSearchDialog(source, on_return_callback, parent_view)
    local dialog
    dialog = InputDialog:new{
        title = "Tìm sách trên Dilib",
        input_hint = "Tên sách hoặc tác giả",
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
                        if query == "" then return end
                        closeAndRun(dialog, function()
                            self:searchDilib(source, query, on_return_callback, parent_view)
                        end)
                    end,
                },
            },
        },
    }
    UIManager:show(dialog)
    dialog:onShowKeyboard()
end

function Browser:searchDilib(source, query, on_return_callback, parent_view)
    runOnline(function()
        local results, err = withLoading(
            'Đang tìm "' .. query .. '"...',
            function()
                return source:search(query)
            end
        )
        if not results then
            showError(err, function()
                self:showDilibSearchDialog(source, on_return_callback, parent_view)
            end)
            return
        end
        if #results == 0 then
            showError("Không tìm thấy sách phù hợp.", function()
                self:showDilibSearchDialog(source, on_return_callback, parent_view)
            end)
            return
        end

        if parent_view and type(parent_view.onClose) == "function" then
            UIManager:close(parent_view)
        end

        local view
        local items = {}
        for _, book in ipairs(results) do
            local current_book = book
            local meta = current_book.format or current_book.author or ""
            if current_book.format and current_book.author and current_book.author ~= "" then
                meta = current_book.format .. " · " .. current_book.author
            end
            table.insert(items, {
                text = current_book.title,
                mandatory = meta,
                callback = function()
                    closeAndRun(view, function()
                        self:showDilibBookDetail(source, current_book, function()
                            self:searchDilib(source, query, on_return_callback, nil)
                        end)
                    end)
                end,
            })
        end

        view = showView(
            string.format("Dilib: %s (%d)", query, #results),
            items,
            on_return_callback
        )
    end)
end

function Browser:showDilibBookList(source, category, page, on_return_callback)
    runOnline(function()
        self._dilib_cat_cache = self._dilib_cat_cache or {}
        local cache_key = tostring(category and category.url or "") .. "#p" .. tostring(page or 1)
        local result = self._dilib_cat_cache[cache_key]
        local err
        if not result then
            result, err = withLoading(
                string.format("Đang tải %s...\nTrang %d", category.name, page),
                function()
                    return source:getCategoryBooks(category, page)
                end
            )
            if result then
                self._dilib_cat_cache[cache_key] = result
            end
        end
        if not result then
            showError(err, on_return_callback)
            return
        end

        local view
        local items = {}

        if result.total_pages > 1 then
            table.insert(items, {
                text = string.format("Trang %d / %d (chạm để nhảy trang)", result.page, result.total_pages),
                callback = function()
                    self:showPageJumpDialog(result.page, result.total_pages, function(target_page)
                        closeAndRun(view, function()
                            self:showDilibBookList(source, category, target_page, on_return_callback)
                        end)
                    end)
                end,
            })
        end
        if page > 1 then
            table.insert(items, {
                text = "← Trang trước",
                callback = function()
                    closeAndRun(view, function()
                        self:showDilibBookList(source, category, page - 1, on_return_callback)
                    end)
                end,
            })
        end
        if page < result.total_pages then
            table.insert(items, {
                text = "Trang sau →",
                callback = function()
                    closeAndRun(view, function()
                        self:showDilibBookList(source, category, page + 1, on_return_callback)
                    end)
                end,
            })
        end

        for _, book in ipairs(result.books) do
            local current_book = book
            table.insert(items, {
                text = current_book.title,
                mandatory_func = function()
                    if current_book._is_dmca then
                        return "Đã gỡ BQ"
                    end
                    return current_book.badge or current_book.author or ""
                end,
                callback = function()
                    local detail = current_book._cached_detail
                    local load_err
                    if not detail then
                        detail, load_err = withLoading("Đang tải chi tiết sách...", function()
                            return source:getBookDetail(current_book)
                        end)
                        if detail then
                            current_book._cached_detail = detail
                        end
                    end
                    if not detail then
                        showError(load_err)
                        return
                    end
                    if detail.is_dmca and not (detail.related_books and #detail.related_books > 0) then
                        current_book._is_dmca = true
                        if view and type(view.updateItems) == "function" then
                            view:updateItems()
                        end
                        UIManager:show(InfoMessage:new{
                            title = "Truyện Việt",
                            text = "⚠️ \"" .. tostring(detail.title or current_book.title) .. "\" đã bị gỡ link đọc/tải trên Dilib (Khiếu Nại Bản Quyền).",
                        })
                        return
                    end
                    closeAndRun(view, function()
                        self:showDilibBookDetail(source, current_book, function()
                            self:showDilibBookList(source, category, page, on_return_callback)
                        end, detail)
                    end)
                end,
            })
        end

        if page < result.total_pages and #result.books > 6 then
            table.insert(items, {
                text = "Trang sau →",
                callback = function()
                    closeAndRun(view, function()
                        self:showDilibBookList(source, category, page + 1, on_return_callback)
                    end)
                end,
            })
        end

        if #result.books == 0 then
            table.insert(items, {
                text = "Không có sách nào.",
                dim = true,
                select_enabled = false,
            })
        end

        view = showView(category.name, items, on_return_callback)
    end)
end

function Browser:showDilibBookDetail(source, book, on_return_callback, preloaded_detail)
    local Util = require("truyenviet/helpers")
    runOnline(function()
        local detail = preloaded_detail or (book and book._cached_detail)
        local err
        if not detail then
            detail, err = withLoading("Đang tải chi tiết sách...", function()
                return source:getBookDetail(book)
            end)
            if detail and type(book) == "table" then
                book._cached_detail = detail
            end
        end
        if not detail then
            showError(err, on_return_callback)
            return
        end

        local view
        local items = {}
        local refresh_detail = function()
            self:showDilibBookDetail(source, book, on_return_callback, detail)
        end

        -- Book info
        local info_lines = { source.name }
        if detail.author then
            table.insert(info_lines, "Tác giả: " .. detail.author)
        end
        if detail.narrator then
            table.insert(info_lines, "Giọng đọc: " .. detail.narrator)
        end
        if detail.format then
            table.insert(info_lines, "Định dạng: " .. detail.format)
        end
        if detail.pages then
            table.insert(info_lines, "Số trang: " .. detail.pages)
        end
        if detail.size then
            table.insert(info_lines, "Kích thước: " .. detail.size)
        end
        if detail.genres and #detail.genres > 0 then
            table.insert(info_lines, "Thể loại: " .. table.concat(detail.genres, ", "))
        end
        if detail.description and detail.description ~= "" then
            table.insert(info_lines, "")
            table.insert(info_lines, detail.description)
        end

        table.insert(items, {
            text = "Xem thông tin sách",
            mandatory = detail.format or "",
            callback = function()
                UIManager:show(TextViewer:new{
                    title = detail.title,
                    text = table.concat(info_lines, "\n"),
                })
            end,
        })

        -- Status banner if DMCA or Audio-only
        if detail.is_dmca then
            table.insert(items, {
                text = "⚠️ Sách đã bị gỡ link đọc/tải trên Dilib (Khiếu Nại Bản Quyền)",
                callback = function()
                    UIManager:show(InfoMessage:new{
                        title = "Truyện Việt",
                        text = "Trang Dilib hiện hiển thị \"Khiếu Nại Bản Quyền\" cho cuốn sách này và đã gỡ toàn bộ liên kết đọc/tải file PDF & EPUB.",
                    })
                end,
            })
        elseif detail.content_kind == "audio_only" then
            table.insert(items, {
                text = "🔊 Mục này là Sách nói / Radio (chỉ có MP3, không có bản chữ)",
                callback = function()
                    UIManager:show(InfoMessage:new{
                        title = "Truyện Việt",
                        text = "Mục này trên Dilib chỉ cung cấp file âm thanh MP3 (Radio / Kịch truyền thanh / Sách nói), không có file PDF hay EPUB để đọc chữ.",
                    })
                end,
            })
        end

        -- EPUB Download (Preferred format on KOReader!)
        if detail.has_epub then
            local book_stub = { title = detail.title, url = book.url }
            local epub_name = Util.safeName(detail.title, "book") .. ".epub"
            local downloaded, existing_path = Storage:isEbookDownloaded(source, book_stub, epub_name)
            table.insert(items, {
                text = downloaded and "Mở sách EPUB" or "Tải và đọc sách EPUB (Khuyên dùng)",
                mandatory = downloaded and "Đã tải" or "EPUB",
                callback = function()
                    if downloaded then
                        self:openEbookFile(existing_path, function()
                            closeAndRun(view, refresh_detail)
                        end)
                    else
                        closeAndRun(view, function()
                            self:downloadDilibEbook(source, book, detail, "epub", refresh_detail)
                        end)
                    end
                end,
            })
        end

        -- PDF Download (from /download/ or smartly captured from /readbook/ Google Drive!)
        if detail.has_pdf then
            local book_stub = { title = detail.title, url = book.url }
            local pdf_name = Util.safeName(detail.title, "book") .. ".pdf"
            local downloaded, existing_path = Storage:isEbookDownloaded(source, book_stub, pdf_name)
            local pdf_note = detail.size or "PDF"
            if detail.pdf_from_readbook then
                pdf_note = "Google Drive PDF"
            end
            table.insert(items, {
                text = downloaded and "Mở sách PDF" or (detail.pdf_from_readbook and "Tải và đọc sách PDF (từ link Đọc Sách)" or "Tải và đọc sách PDF"),
                mandatory = downloaded and "Đã tải" or pdf_note,
                callback = function()
                    if downloaded then
                        self:openEbookFile(existing_path, function()
                            closeAndRun(view, refresh_detail)
                        end)
                    else
                        closeAndRun(view, function()
                            self:downloadDilibEbook(source, book, detail, "pdf", refresh_detail)
                        end)
                    end
                end,
            })
        end

        -- MOBI / AZW3 if present
        for _, extra_fmt in ipairs({ "mobi", "azw3" }) do
            if detail["has_" .. extra_fmt] then
                local book_stub = { title = detail.title, url = book.url }
                local fname = Util.safeName(detail.title, "book") .. "." .. extra_fmt
                local downloaded, existing_path = Storage:isEbookDownloaded(source, book_stub, fname)
                table.insert(items, {
                    text = downloaded and ("Mở sách " .. extra_fmt:upper()) or ("Tải sách " .. extra_fmt:upper()),
                    mandatory = downloaded and "Đã tải" or extra_fmt:upper(),
                    callback = function()
                        if downloaded then
                            self:openEbookFile(existing_path, function()
                                closeAndRun(view, refresh_detail)
                            end)
                        else
                            closeAndRun(view, function()
                                self:downloadDilibEbook(source, book, detail, extra_fmt, refresh_detail)
                            end)
                        end
                    end,
                })
            end
        end

        -- Audio Download
        if detail.has_audio then
            local book_stub = { title = detail.title, url = book.url }
            local audio_name = Util.safeName(detail.title, "audio") .. ".mp3"
            local downloaded, existing_path = Storage:isEbookDownloaded(source, book_stub, audio_name)

            table.insert(items, {
                text = downloaded and "Sách nói MP3 đã tải" or "Tải sách nói MP3",
                mandatory = downloaded and "Đã tải" or (detail.audio_size or "MP3"),
                callback = function()
                    if downloaded then
                        UIManager:show(InfoMessage:new{
                            title = "Truyện Việt",
                            text = "File audio đã được lưu tại:\n" .. existing_path .. "\n\nVui lòng dùng ứng dụng phát nhạc để nghe.",
                        })
                    else
                        closeAndRun(view, function()
                            self:downloadDilibAudio(source, book, detail, refresh_detail)
                        end)
                    end
                end,
            })
        end

        -- Audio chapters info
        if detail.audio_chapters and #detail.audio_chapters > 0 then
            table.insert(items, {
                text = "Xem mục lục audio (" .. #detail.audio_chapters .. " phần)",
                callback = function()
                    local toc_lines = {}
                    for _, ch in ipairs(detail.audio_chapters) do
                        local minutes = math.floor(ch.start_time / 60)
                        local seconds = math.floor(ch.start_time % 60)
                        local name = ch.name or ("Phần " .. (ch.index + 1))
                        table.insert(toc_lines, string.format(
                            "%s  [%d:%02d]", name, minutes, seconds
                        ))
                    end
                    UIManager:show(TextViewer:new{
                        title = detail.title .. " · Mục lục",
                        text = table.concat(toc_lines, "\n"),
                    })
                end,
            })
        end

        -- Related / Same-series books (Sách cùng bộ / cùng tác giả)
        if detail.related_books and #detail.related_books > 0 then
            table.insert(items, {
                text = string.format("📚 Sách cùng bộ / cùng tác giả (%d)", #detail.related_books),
                callback = function()
                    closeAndRun(view, function()
                        local rel_view
                        local rel_items = {}
                        for _, rel_book in ipairs(detail.related_books) do
                            local current_rel = rel_book
                            table.insert(rel_items, {
                                text = current_rel.title,
                                callback = function()
                                    closeAndRun(rel_view, function()
                                        self:showDilibBookDetail(source, current_rel, refresh_detail)
                                    end)
                                end,
                            })
                        end
                        rel_view = showView("Cùng bộ / tác giả: " .. detail.title, rel_items, refresh_detail)
                    end)
                end,
            })
        end

        -- Build info HTML page
        table.insert(items, {
            text = "Tạo trang thông tin (đọc offline)",
            callback = function()
                local book_stub = { title = detail.title, url = book.url }
                local info_name = Util.safeName(detail.title, "info") .. ".html"
                local save_path = Storage:getEbookPath(source, book_stub, info_name)
                local result, build_err = source:buildInfoPage(detail, save_path)
                if result then
                    self:openEbookFile(save_path, function()
                        closeAndRun(view, refresh_detail)
                    end)
                else
                    showError("Lỗi tạo trang: " .. tostring(build_err))
                end
            end,
        })

        view = showView(detail.title, items, on_return_callback)
    end)
end

function Browser:downloadDilibEbook(source, book, detail, format, on_complete)
    format = tostring(format or "pdf"):lower()
    local label = format:upper()
    runOnline(function()
        local book_stub = { title = detail.title, url = book.url }
        local file_name = Util.safeName(detail.title, "book") .. "." .. format
        local save_path = Storage:getEbookPath(source, book_stub, file_name)

        local result, run_err = withLoading("Đang tải " .. label .. " " .. detail.title .. "...", function()
            if type(source.downloadEbook) == "function" then
                return source:downloadEbook(detail, format, save_path)
            end
            return source:downloadPdf(detail, save_path)
        end)

        if result then
            UIManager:show(ConfirmBox:new{
                title = "Truyện Việt",
                text = "Đã tải xong: " .. file_name .. "\nMở sách ngay?",
                ok_text = "Mở",
                ok_callback = function()
                    self:openEbookFile(save_path, on_complete)
                end,
                cancel_text = "Đóng",
                cancel_callback = on_complete,
            })
        else
            os.remove(save_path .. ".part")
            showError("Lỗi tải " .. label .. ": " .. tostring(run_err), on_complete)
        end
    end)
end

function Browser:downloadDilibPdf(source, book, detail, on_complete)
    return self:downloadDilibEbook(source, book, detail, "pdf", on_complete)
end

function Browser:downloadDilibAudio(source, book, detail, on_complete)
    runOnline(function()
        local book_stub = { title = detail.title, url = book.url }
        local audio_name = Util.safeName(detail.title, "audio") .. ".mp3"
        local save_path = Storage:getEbookPath(source, book_stub, audio_name)

        local result, run_err = withLoading("Đang tải sách nói " .. detail.title .. "...\n" .. (detail.audio_size or ""), function()
            return source:downloadAudio(detail, save_path)
        end)

        if result then
            -- Also build info page
            local info_name = Util.safeName(detail.title, "info") .. ".html"
            local info_path = Storage:getEbookPath(source, book_stub, info_name)
            source:buildInfoPage(detail, info_path)

            UIManager:show(ConfirmBox:new{
                title = "Truyện Việt",
                text = "Đã tải sách nói: " .. audio_name .. "\n\nFile đã lưu tại:\n" .. save_path .. "\n\nVui lòng dùng ứng dụng phát nhạc để nghe.",
                ok_text = "Đóng",
            })
            if on_complete then UIManager:nextTick(on_complete) end
        else
            os.remove(save_path .. ".part")
            showError("Lỗi tải audio: " .. tostring(run_err), on_complete)
        end
    end)
end

-- ============ SHARED EBOOK UTILS ============

function Browser:openEbookFile(file_path, on_return_callback)
    local lfs = require("libs/libkoreader-lfs")
    if not file_path or lfs.attributes(file_path, "mode") ~= "file" then
        showError("Không tìm thấy tệp ebook tại:\n" .. tostring(file_path), on_return_callback)
        return
    end
    local ext = file_path:match("%.([^%.]+)$")
    if ext then ext = ext:lower() end

    -- Check if KOReader can open this format
    local supported = { html = true, epub = true, pdf = true, mobi = true, azw3 = true, txt = true, fb2 = true, cbz = true }
    if ext and supported[ext] then
        local ReaderUI = require("apps/reader/readerui")
        if ReaderUI.instance then
            ReaderUI.instance:onClose()
        end
        local ok, err = pcall(ReaderUI.showReader, ReaderUI, file_path)
        if not ok then
            showError("Không thể mở ebook: " .. tostring(err), on_return_callback)
        end
    elseif ext == "rar" or ext == "zip" or ext == "7z" then
        UIManager:show(InfoMessage:new{
            title = "Truyện Việt",
            text = "File nén (" .. ext:upper() .. ") cần được giải nén trước khi đọc.\n\nĐường dẫn file:\n" .. file_path,
        })
    elseif ext == "mp3" or ext == "m4a" or ext == "ogg" then
        UIManager:show(InfoMessage:new{
            title = "Truyện Việt",
            text = "File audio (" .. ext:upper() .. ") không thể phát trên máy đọc sách.\n\nĐường dẫn file:\n" .. file_path,
        })
    else
        -- Try opening anyway
        local ReaderUI = require("apps/reader/readerui")
        if ReaderUI.instance then
            ReaderUI.instance:onClose()
        end
        local ok = pcall(ReaderUI.showReader, ReaderUI, file_path)
        if not ok then
            UIManager:show(InfoMessage:new{
                title = "Truyện Việt",
                text = "Không thể mở file này.\n\nĐường dẫn:\n" .. file_path,
            })
        end
    end
end

return Browser
