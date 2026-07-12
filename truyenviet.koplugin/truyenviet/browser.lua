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
local Util = require("truyenviet/helpers")

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
                    text = "Gửi log",
                    callback = function()
                        local user_desc = dialog:getInputValue()
                        closeAndRun(dialog, function()
                            local res, err = withLoading("Đang gửi báo cáo...", function()
                                local success, result = false, nil
                                ErrorReporter:submit(user_desc, error_msg, true, function(ok, val)
                                    success = ok
                                    result = val
                                end)
                                -- Note: since we're using socket.http, it's blocking
                                if success then
                                    ErrorReporter:clearLogAfterSubmit()
                                    return result
                                else
                                    error(result)
                                end
                            end)
                            
                            if res then
                                UIManager:show(InfoMessage:new{
                                    text = "Đã gửi báo cáo thành công! Mã lỗi: #" .. tostring(res)
                                })
                            else
                                UIManager:show(InfoMessage:new{
                                    text = "Lỗi khi gửi báo cáo: " .. tostring(err)
                                })
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
                UIManager:show(TextViewer:new{
                    title = "Truyện Việt",
                    text = table.concat({
                        "Đọc truyện trực tuyến trong KOReader.",
                        "",
                        "Nguồn truyện chữ: https://truyenfull.today/",
                        "Nguồn truyện chữ: https://truyendich.vn/",
                        "Nguồn truyện tranh: https://truyenqqko.com/",
                        "Nguồn truyện tranh: https://dualeotruyenpt.com/",
                        "Nguồn truyện tranh: https://cbunu.com/",
                        "Nguồn truyện tranh: https://haccbl.xyz/",
                        "",
                        "Chương truyện được lưu vào thư mục truyenviet trong thư mục dữ liệu KOReader.",
                        "Nội dung và ảnh thuộc về các website nguồn và chủ sở hữu tương ứng.",
                    }, "\n"),
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
                if not SourceRegistry:isEnabled(current_source.id) then
                    return "Đã tắt · chạm để bật"
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
                    closeAndRun(view, function()
                        self:showSourceMenu(on_return_callback)
                    end)
                    return
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
                local chapter_to_open = type(auto_open_chapter) == "table" and auto_open_chapter or page_data.chapters[1]
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
                local chapter_to_open = type(auto_open_chapter) == "table" and auto_open_chapter or page_data.chapters[1]
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

local function runInBackground(task_name, task_func, on_complete)
    local indicator = FloatingProgress:new{
        text = "Đang tải ngầm: " .. task_name
    }
    UIManager:show(indicator)
    
    local co = coroutine.create(task_func)
    local final_result = nil
    local function tick()
        if coroutine.status(co) ~= "dead" then
            local ok, result = coroutine.resume(co)
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
                    indicator:setText(result)
                    indicator:bringToFront()
                end
                UIManager:scheduleIn(0.05, tick)
            end
        else
            UIManager:close(indicator)
            UIManager:show(Notification:new{
                text = "Tải ngầm hoàn tất: " .. task_name,
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
                            for p = 1, page_data.total_pages do
                                local p_data = source:getStoryPage(story, p)
                                if p_data and p_data.chapters then
                                    for _, c in ipairs(p_data.chapters) do
                                        table.insert(all_chapters, c)
                                    end
                                else
                                    if not p_data or not p_data.chapters or #p_data.chapters == 0 then
                                        break
                                    end
                                end
                            end
                            local Util = require("truyenviet/helpers")
                            all_chapters = Util.uniqueBy(all_chapters, "url")
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
                    local pending = ChapterDownloader:listPending(source, story, page_data.chapters)
                    local already_downloaded = #page_data.chapters - #pending
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

function Browser:confirmDownloadBundle(view, page_data, source)
    local story = page_data.story
    local warning = "Tiến hành tải toàn bộ chương và gom thành 1 file HTML duy nhất?\n\nQuá trình này có thể mất nhiều thời gian tuỳ thuộc vào số lượng chương."
    
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
                            for p = 1, page_data.total_pages do
                                local p_data = source:getStoryPage(story, p)
                                if p_data and p_data.chapters then
                                    for _, c in ipairs(p_data.chapters) do
                                        table.insert(all_chapters, c)
                                    end
                                else
                                    if not p_data or not p_data.chapters or #p_data.chapters == 0 then
                                        break
                                    end
                                end
                            end
                            local Util = require("truyenviet/helpers")
                            all_chapters = Util.uniqueBy(all_chapters, "url")
                            fetch_ok = true
                            return true
                        end)
                        if fetch_ok then
                            self:downloadAsBundle(story, source, all_chapters)
                        else
                            showError(err or "Lỗi khi lấy danh sách chương")
                        end
                    end)
                else
                    self:downloadAsBundle(story, source, page_data.chapters)
                end
            end)
        end,
    })
end

function Browser:downloadAsBundle(story, source, all_chapters)
    runOnline(function()
        local Storage = require("truyenviet/storage")
        local Util = require("truyenviet/helpers")
        local CoverCache = require("truyenviet/cover_cache")
        local lfs = require("libs/libkoreader-lfs")
        
        local story_dir = Storage:getStoryDir(source, story)
        local safe_title = story.title:gsub('[<>:"/\\|?*]', '_')
        local out_path = story_dir .. "/" .. safe_title .. ".html"
        
        local html_parts = {}
        table.insert(html_parts, "<!DOCTYPE html>\n<html lang=\"vi\">\n<head>\n<meta charset=\"UTF-8\">\n<title>" .. story.title .. "</title>\n")
        table.insert(html_parts, "<style>\nbody { font-family: serif; max-width: 800px; margin: auto; padding: 1em; }\n.chapter { margin-bottom: 3em; padding-top: 1em; border-top: 1px solid #ccc; }\nh2 { font-size: 1.2em; font-weight: bold; }\n</style>\n</head>\n<body>\n")
        
        -- Thêm cover image vào đầu trang HTML nếu có
        local cover_filename = nil
        if story.cover_url or story.cover_path then
            CoverCache:download(story, source)
            if story.cover_path and lfs.attributes(story.cover_path, "mode") == "file" then
                local ext = story.cover_path:match("%.([^%.]+)$") or "jpg"
                cover_filename = "cover." .. ext
                local dest_path = story_dir .. "/" .. cover_filename
                
                local inf = io.open(story.cover_path, "rb")
                if inf then
                    local data = inf:read("*a")
                    inf:close()
                    local outf = io.open(dest_path, "wb")
                    if outf then
                        outf:write(data)
                        outf:close()
                        table.insert(html_parts, '<div style="text-align: center; page-break-after: always;"><img src="' .. cover_filename .. '" style="max-width: 100%; height: auto;" /></div>\n')
                    end
                end
            end
        end

        table.insert(html_parts, "<h1>" .. story.title .. "</h1>\n")
        if story.details and story.details.author then
            table.insert(html_parts, "<p><strong>Tác giả:</strong> " .. story.details.author .. "</p>\n")
        end
        if story.details and story.details.description then
            table.insert(html_parts, "<div><strong>Giới thiệu:</strong><br/>" .. story.details.description .. "</div><hr/>\n")
        end

        runInBackground("Gom " .. #all_chapters .. " chương...", function()
            local total = #all_chapters
            local successes = 0
            for i, chapter in ipairs(all_chapters) do
                local progress = string.format("Đang gom %d/%d chương...", i, total)
                coroutine.yield(progress) -- Nhường lại UI loop NGAY TRƯỚC khi tải chương, để UI kịp render text
                local ch_data = source:getChapter(chapter)
                if ch_data then
                    table.insert(html_parts, "<div class=\"chapter\">\n<h2>" .. (chapter.title or "Chương " .. i) .. "</h2>\n")
                    table.insert(html_parts, ch_data.content or ch_data)
                    table.insert(html_parts, "\n</div>\n")
                    successes = successes + 1
                end
            end
            
            table.insert(html_parts, "</body>\n</html>")
            
            local f, err = io.open(out_path, "w")
            if not f then
                showError("Lỗi khi ghi tệp: " .. tostring(err))
                return
            end
            f:write(table.concat(html_parts))
            f:close()
            
            if G_reader_settings and G_reader_settings.addDocument then
                G_reader_settings:addDocument(out_path)
                G_reader_settings:flush()
            end
            
            UIManager:show(InfoMessage:new{
                title = "Truyện Việt",
                text = string.format("Đã lưu thành công %d/%d chương vào:\n%s\n\nBạn có thể mở tệp này bằng KOReader (trong Quản lý tệp tin).", successes, total, out_path)
            })
        end)
        
    end)
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
                text = "Tải thành 1 bộ (gom tất cả chương)",
                callback = function()
                    self:confirmDownloadBundle(view, page_data, source)
                end,
            })
        end
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
                                    false,
                                    from_reader
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
    if source.id == "tve4u" then
        self:browseTve4u(source, on_return_callback)
    elseif source.id == "dilib" then
        self:browseDilib(source, on_return_callback)
    else
        showError("Nguồn ebook không được hỗ trợ.", on_return_callback)
    end
end

-- ============ TVE-4U ============

function Browser:browseTve4u(source, on_return_callback)
    -- Check if login is needed
    if source.requires_auth and not source:isLoggedIn() then
        if CredentialManager:hasCredential(source.id) then
            -- Try auto-login
            runOnline(function()
                local result, err = withLoading("Đang đăng nhập TVE-4U...", function()
                    local ok, login_err = source:ensureLoggedIn()
                    if not ok then error(login_err or "Đăng nhập thất bại") end
                    return true
                end)
                if result then
                    self:showTve4uForumList(source, on_return_callback)
                else
                    showError(err, function()
                        self:showLoginDialog(source, function()
                            self:showTve4uForumList(source, on_return_callback)
                        end, on_return_callback)
                    end)
                end
            end)
        else
            self:showLoginDialog(source, function()
                self:showTve4uForumList(source, on_return_callback)
            end, on_return_callback)
        end
        return
    end

    self:showTve4uForumList(source, on_return_callback)
end

function Browser:showTve4uForumList(source, on_return_callback)
    runOnline(function()
        local forums, err = withLoading("Đang tải danh mục...", function()
            return source:getForumList()
        end)
        if not forums then
            showError(err, on_return_callback)
            return
        end

        local view
        local items = {
            {
                text = "Tìm kiếm trên TVE-4U",
                callback = function()
                    self:showSearchDialog(source, function()
                        self:showTve4uForumList(source, on_return_callback)
                    end, view)
                end,
            },
            {
                text = "Quản lý tài khoản",
                mandatory = CredentialManager:hasCredential(source.id) and "Đã lưu" or "",
                callback = function()
                    closeAndRun(view, function()
                        self:showTve4uAccountMenu(source, function()
                            self:showTve4uForumList(source, on_return_callback)
                        end)
                    end)
                end,
            },
        }

        for _, forum in ipairs(forums) do
            local current_forum = forum
            table.insert(items, {
                text = current_forum.name,
                callback = function()
                    closeAndRun(view, function()
                        self:showTve4uThreadList(source, current_forum, 1, function()
                            self:showTve4uForumList(source, on_return_callback)
                        end)
                    end)
                end,
            })
        end

        if #forums == 0 then
            table.insert(items, {
                text = "Không tìm thấy diễn đàn nào.",
                dim = true,
                select_enabled = false,
            })
        end

        view = showView("TVE-4U · Diễn đàn", items, on_return_callback)
    end)
end

function Browser:showTve4uAccountMenu(source, on_return_callback)
    local view
    local items = {}

    if CredentialManager:hasCredential(source.id) then
        local cred = CredentialManager:getCredential(source.id)
        table.insert(items, {
            text = "Tài khoản: " .. (cred and cred.username or "N/A"),
            dim = true,
            select_enabled = false,
        })
        table.insert(items, {
            text = "Đăng nhập lại",
            callback = function()
                closeAndRun(view, function()
                    source._logged_in = false
                    source._cookies = nil
                    self:showLoginDialog(source, on_return_callback, on_return_callback)
                end)
            end,
        })
        table.insert(items, {
            text = "Xóa tài khoản đã lưu",
            callback = function()
                CredentialManager:removeCredential(source.id)
                source._logged_in = false
                source._cookies = nil
                UIManager:show(InfoMessage:new{
                    title = "Truyện Việt",
                    text = "Đã xóa thông tin tài khoản.",
                })
                closeAndRun(view, on_return_callback)
            end,
        })
    else
        table.insert(items, {
            text = "Đăng nhập",
            callback = function()
                closeAndRun(view, function()
                    self:showLoginDialog(source, on_return_callback, on_return_callback)
                end)
            end,
        })
    end

    view = showView("TVE-4U · Tài khoản", items, on_return_callback)
end

function Browser:showTve4uThreadList(source, forum, page, on_return_callback)
    runOnline(function()
        local result, err = withLoading(
            string.format("Đang tải %s...\nTrang %d", forum.name, page),
            function()
                return source:getThreadList(forum, page)
            end
        )
        if not result then
            showError(err, on_return_callback)
            return
        end

        local view
        local items = {}

        if result.total_pages > 1 then
            table.insert(items, {
                text = string.format("Trang %d / %d", result.page, result.total_pages),
                dim = true,
                select_enabled = false,
            })
        end
        if page > 1 then
            table.insert(items, {
                text = "← Trang trước",
                callback = function()
                    closeAndRun(view, function()
                        self:showTve4uThreadList(source, forum, page - 1, on_return_callback)
                    end)
                end,
            })
        end

        for _, thread in ipairs(result.threads) do
            local current_thread = thread
            table.insert(items, {
                text = current_thread.title,
                callback = function()
                    closeAndRun(view, function()
                        self:showTve4uThreadDetail(source, current_thread, function()
                            self:showTve4uThreadList(source, forum, page, on_return_callback)
                        end)
                    end)
                end,
            })
        end

        if page < result.total_pages then
            table.insert(items, {
                text = "Trang sau →",
                callback = function()
                    closeAndRun(view, function()
                        self:showTve4uThreadList(source, forum, page + 1, on_return_callback)
                    end)
                end,
            })
        end

        if #result.threads == 0 then
            table.insert(items, {
                text = "Không có bài viết nào.",
                dim = true,
                select_enabled = false,
            })
        end

        view = showView(forum.name, items, on_return_callback)
    end)
end

function Browser:showTve4uThreadDetail(source, thread, on_return_callback)
    runOnline(function()
        local detail, err = withLoading("Đang tải chi tiết...", function()
            return source:getThreadDetail(thread)
        end)
        if not detail then
            showError(err, on_return_callback)
            return
        end

        local view
        local items = {}

        -- Read Thread Content
        if detail.posts and #detail.posts > 0 then
            table.insert(items, {
                text = "Đọc nội dung chủ đề",
                callback = function()
                    local text = {}
                    for i, post in ipairs(detail.posts) do
                        table.insert(text, "@ " .. post.author .. " (" .. post.date .. ")")
                        table.insert(text, string.rep("-", 40))
                        local plain = post.content:gsub("<br/?>", "\n"):gsub("</p>", "\n\n")
                        plain = Util.stripTags(plain)
                        table.insert(text, Util.trim(plain))
                        table.insert(text, "\n")
                    end
                    UIManager:show(TextViewer:new{
                        title = thread.title,
                        text = table.concat(text, "\n"),
                    })
                end,
            })
        end

        -- Attachments & Links
        local total_links = (detail.attachments and #detail.attachments or 0) + (detail.external_links and #detail.external_links or 0)
        if total_links > 0 then
            table.insert(items, {
                text = string.format("[Link] Tệp đính kèm & Link tải (%d)", total_links),
                callback = function()
                    local link_items = {}
                    
                    if detail.attachments then
                        for _, att in ipairs(detail.attachments) do
                            local current_att = att
                            local book_stub = { title = thread.title, url = thread.url }
                            local downloaded, existing_path = Storage:isEbookDownloaded(source, book_stub, current_att.filename)
                            table.insert(link_items, {
                                text = "[File] " .. current_att.filename,
                                mandatory = downloaded and "Đã tải" or (current_att.size ~= "" and current_att.size or "Tải về"),
                                callback = function()
                                    if downloaded then
                                        self:openEbookFile(existing_path, function() end)
                                    else
                                        self:downloadTve4uAttachment(source, book_stub, current_att, function() end)
                                    end
                                end,
                            })
                        end
                    end

                    if detail.external_links then
                        for _, lnk in ipairs(detail.external_links) do
                            local domain = lnk.url:match("://([^/]+)") or "Link ngoài"
                            table.insert(link_items, {
                                text = "[Web] " .. domain .. " (" .. lnk.author .. ")",
                                callback = function()
                                    UIManager:show(ConfirmBox:new{
                                        text = "Mở link sau trong thiết bị?\n" .. lnk.url,
                                        ok_text = "Mở",
                                        ok_callback = function()
                                            UIManager:show(TextViewer:new{
                                                title = "Link tải",
                                                text = lnk.url,
                                            })
                                        end,
                                    })
                                end,
                            })
                        end
                    end
                    
                    showView("Tệp đính kèm & Link", link_items, function()
                        -- Return to thread detail
                        self:showTve4uThreadDetail(source, thread, on_return_callback)
                    end)
                end,
            })
        else
            table.insert(items, {
                text = "Không tìm thấy link tải hay đính kèm nào.",
                dim = true,
                select_enabled = false,
            })
        end

        view = showView(thread.title, items, on_return_callback)
    end)
end

function Browser:downloadTve4uAttachment(source, book, attachment, on_complete)
    runOnline(function()
        local save_path = Storage:getEbookPath(source, book, attachment.filename)
        local result, err = withLoading(
            "Đang tải " .. attachment.filename .. "...",
            function()
                return source:downloadAttachment(attachment, save_path)
            end
        )
        if result then
            UIManager:show(ConfirmBox:new{
                title = "Truyện Việt",
                text = "Đã tải xong: " .. attachment.filename .. "\nMở file ngay?",
                ok_text = "Mở",
                ok_callback = function()
                    self:openEbookFile(save_path, on_complete)
                end,
                cancel_text = "Đóng",
                cancel_callback = on_complete,
            })
        else
            showError("Lỗi tải file: " .. tostring(err))
        end
    end)
end

-- ============ DILIB ============

function Browser:browseDilib(source, on_return_callback)
    local categories = source:getCategories()
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
            table.insert(items, {
                text = current_book.title,
                mandatory = current_book.author or "",
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
        local result, err = withLoading(
            string.format("Đang tải %s...\nTrang %d", category.name, page),
            function()
                return source:getCategoryBooks(category, page)
            end
        )
        if not result then
            showError(err, on_return_callback)
            return
        end

        local view
        local items = {}

        if result.total_pages > 1 then
            table.insert(items, {
                text = string.format("Trang %d / %d", result.page, result.total_pages),
                dim = true,
                select_enabled = false,
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

        for _, book in ipairs(result.books) do
            local current_book = book
            table.insert(items, {
                text = current_book.title,
                callback = function()
                    closeAndRun(view, function()
                        self:showDilibBookDetail(source, current_book, function()
                            self:showDilibBookList(source, category, page, on_return_callback)
                        end)
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

function Browser:showDilibBookDetail(source, book, on_return_callback)
    local Util = require("truyenviet/helpers")
    runOnline(function()
        local detail, err = withLoading("Đang tải chi tiết sách...", function()
            return source:getBookDetail(book)
        end)
        if not detail then
            showError(err, on_return_callback)
            return
        end

        local view
        local items = {}

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
        if #detail.genres > 0 then
            table.insert(info_lines, "Thể loại: " .. table.concat(detail.genres, ", "))
        end
        if detail.description and detail.description ~= "" then
            table.insert(info_lines, "")
            table.insert(info_lines, detail.description)
        end

        table.insert(items, {
            text = "Xem thông tin sách",
            callback = function()
                UIManager:show(TextViewer:new{
                    title = detail.title,
                    text = table.concat(info_lines, "\n"),
                })
            end,
        })

        -- PDF Download
        if detail.has_pdf then
            local book_stub = { title = detail.title, url = book.url }
            local pdf_name = Util.safeName(detail.title, "book") .. ".pdf"
            local downloaded, existing_path = Storage:isEbookDownloaded(source, book_stub, pdf_name)
            table.insert(items, {
                text = downloaded and "Mở sách PDF" or "Tải sách PDF",
                mandatory = downloaded and "Đã tải" or (detail.size or ""),
                callback = function()
                    if downloaded then
                        self:openEbookFile(existing_path, function()
                            closeAndRun(view, function()
                                self:showDilibBookDetail(source, book, on_return_callback)
                            end)
                        end)
                    else
                        closeAndRun(view, function()
                            self:downloadDilibPdf(source, book, detail, function()
                                self:showDilibBookDetail(source, book, on_return_callback)
                            end)
                        end)
                    end
                end,
            })
        end

        -- Audio Download
        if detail.has_audio then
            local book_stub = { title = detail.title, url = book.url }
            local audio_name = Util.safeName(detail.title, "audio") .. ".mp3"
            local downloaded, existing_path = Storage:isEbookDownloaded(source, book_stub, audio_name)

            table.insert(items, {
                text = downloaded and "Sách nói đã tải" or "Tải sách nói MP3",
                mandatory = downloaded and "Đã tải" or (detail.audio_size or ""),
                callback = function()
                    if downloaded then
                        UIManager:show(InfoMessage:new{
                            title = "Truyện Việt",
                            text = "File audio đã được lưu tại:\n" .. existing_path .. "\n\nVui lòng dùng ứng dụng phát nhạc để nghe.",
                        })
                    else
                        closeAndRun(view, function()
                            self:downloadDilibAudio(source, book, detail, function()
                                self:showDilibBookDetail(source, book, on_return_callback)
                            end)
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
                        closeAndRun(view, function()
                            self:showDilibBookDetail(source, book, on_return_callback)
                        end)
                    end)
                else
                    showError("Lỗi tạo trang: " .. tostring(build_err))
                end
            end,
        })

        view = showView(detail.title, items, on_return_callback)
    end)
end

function Browser:downloadDilibPdf(source, book, detail, on_complete)
    runOnline(function()
        local book_stub = { title = detail.title, url = book.url }
        local pdf_name = Util.safeName(detail.title, "book") .. ".pdf"
        local save_path = Storage:getEbookPath(source, book_stub, pdf_name)

        local result, run_err = withLoading("Đang tải PDF " .. detail.title .. "...", function()
            return source:downloadPdf(detail, save_path)
        end)

        if result then
            UIManager:show(ConfirmBox:new{
                title = "Truyện Việt",
                text = "Đã tải xong: " .. pdf_name .. "\nMở sách ngay?",
                ok_text = "Mở",
                ok_callback = function()
                    self:openEbookFile(save_path, on_complete)
                end,
                cancel_text = "Đóng",
                cancel_callback = on_complete,
            })
        else
            os.remove(save_path .. ".part")
            showError("Lỗi tải PDF: " .. tostring(run_err), on_complete)
        end
    end)
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
    local ext = file_path:match("%.([^%.]+)$")
    if ext then ext = ext:lower() end

    -- Check if KOReader can open this format
    local supported = { html = true, epub = true, pdf = true, mobi = true, txt = true, fb2 = true, cbz = true }
    if ext and supported[ext] then
        local FileManager = require("apps/filemanager/filemanager")
        local ReaderUI = require("apps/reader/readerui")
        if ReaderUI.instance then
            ReaderUI.instance:onClose()
        end
        ReaderUI:showReader(file_path)
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