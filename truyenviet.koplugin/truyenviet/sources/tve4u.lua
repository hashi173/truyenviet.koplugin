local Http = require("truyenviet/http_client")
local Util = require("truyenviet/helpers")
local CredentialManager = require("truyenviet/credential_manager")
local Debug = require("truyenviet/debugger")
local ko_util = require("util")

local Source = {
    id = "tve4u",
    name = "TVE-4U Ebook",
    kind = "ebook",
    base_url = "https://tve-4u.org",
    requires_auth = true,
    _cookies = nil,
    _logged_in = false,
}

-- Cookie management
local function parseCookies(headers)
    local cookies = {}
    if not headers then return cookies end
    local set_cookie = headers["set-cookie"]
    if type(set_cookie) == "string" then
        for name, value in set_cookie:gmatch("([%w_%-]+)=([^;]+)") do
            local l = name:lower()
            if l ~= "expires" and l ~= "path" and l ~= "max-age" and l ~= "secure" and l ~= "httponly" and l ~= "domain" and l ~= "samesite" then
                cookies[name] = value
            end
        end
    elseif type(set_cookie) == "table" then
        for _, cookie_str in ipairs(set_cookie) do
            local name, value = cookie_str:match("^([^=]+)=([^;]*)")
            if name then
                cookies[name:match("^%s*(.-)%s*$")] = value
            end
        end
    end
    return cookies
end

local function mergeCookies(existing, new_cookies)
    existing = existing or {}
    for name, value in pairs(new_cookies) do
        existing[name] = value
    end
    return existing
end

local function cookieHeader(cookies)
    if not cookies then return nil end
    local parts = {}
    for name, value in pairs(cookies) do
        table.insert(parts, name .. "=" .. value)
    end
    if #parts == 0 then return nil end
    return table.concat(parts, "; ")
end

function Source:getHeaders()
    local headers = {
        ["Referer"] = self.base_url .. "/",
    }
    local cookie = cookieHeader(self._cookies)
    if cookie then
        headers["Cookie"] = cookie
    end
    return headers
end

function Source:authGet(url)
    local content, err, headers, code = Http:request("GET", url, nil, self:getHeaders())
    if headers then
        self._cookies = mergeCookies(self._cookies, parseCookies(headers))
    end
    return content, err, headers, code
end

function Source:authPost(url, body, extra_headers)
    local headers = self:getHeaders()
    for k, v in pairs(extra_headers or {}) do
        headers[k] = v
    end
    local content, err, resp_headers, code = Http:request("POST", url, body, headers)
    if resp_headers then
        self._cookies = mergeCookies(self._cookies, parseCookies(resp_headers))
    end
    return content, err, resp_headers, code
end

-- XenForo login
function Source:login(username, password)
    Debug.write("[TVE4U] Starting login for " .. username)
    -- Step 1: GET login page to get CSRF token
    local login_page, err = self:authGet(self.base_url .. "/login/")
    if not login_page then
        return nil, "Không thể tải trang đăng nhập: " .. tostring(err)
    end
    -- Parse _xfToken
    local xf_token = login_page:match('name="_xfToken"%s*value="([^"]*)"')
        or login_page:match("name='_xfToken'%s*value='([^']*)'")
        or login_page:match('_xfToken["\']%s*:%s*["\']([^"\']*)')
    if not xf_token then
        xf_token = ""
    end

    -- Step 2: POST login
    local form_data = string.format(
        "login=%s&matkhaune=%s&register=0&cookie_check=1&remember=1&_xfRedirect=%s&_xfToken=%s",
        ko_util.urlEncode(username),
        ko_util.urlEncode(password),
        ko_util.urlEncode(self.base_url .. "/"),
        ko_util.urlEncode(xf_token)
    )
    local result, post_err, resp_headers, code = self:authPost(
        self.base_url .. "/login/login",
        form_data,
        { ["Content-Type"] = "application/x-www-form-urlencoded" }
    )

    -- Check if login succeeded by looking for user cookie
    if self._cookies and self._cookies["xf_user"] then
        self._logged_in = true
        Debug.write("[TVE4U] Login successful")
        return true
    end

    -- Check error in response
    if result and result:find("lỗi", 1, true) then
        return nil, "Sai tên đăng nhập hoặc mật khẩu"
    end

    if code and (code == 303 or code == 302) then
        -- redirects happen even on failure, so only trust xf_user cookie
    end

    return nil, "Đăng nhập không thành công: " .. tostring(post_err or "không rõ lỗi")
end

function Source:ensureLoggedIn()
    if self._logged_in and self._cookies then
        return true
    end
    local cred = CredentialManager:getCredential(self.id)
    if not cred then
        return nil, "Chưa có thông tin đăng nhập. Vui lòng thiết lập tài khoản."
    end
    return self:login(cred.username, cred.password)
end

function Source:isLoggedIn()
    return self._logged_in == true
end

-- Forum browsing
function Source:getForumList()
    local ok, err = self:ensureLoggedIn()
    if not ok then
        return nil, err
    end

    local html, fetch_err = self:authGet(self.base_url .. "/")
    if not html then
        return nil, fetch_err
    end

    local forums = {}
    -- Parse forum nodes: <a href="forums/slug.id/">Title</a>
    for anchor_attrs, anchor_html in html:gmatch("<h3[^>]*>%s*<a([^>]*)>([%s%S]-)</a>%s*</h3>") do
        local href = Util.getAttribute(anchor_attrs, "href")
        if href and href:match("forums/[^/]+%.%d+/") then
            local name = Util.stripTags(anchor_html)
            if name ~= "" then
                table.insert(forums, {
                    name = Util.decodeHtml(name),
                    url = Util.absoluteUrl(self.base_url, href),
                })
            end
        end
    end

    -- Also try data-node-id pattern
    if #forums == 0 then
        for block in html:gmatch('<div[^>]-class="[^"]*node%-body[^"]*"[^>]*>(.-)</div>') do
            for anchor_attrs, anchor_html in block:gmatch("<a([^>]*)>([%s%S]-)</a>") do
                local href = Util.getAttribute(anchor_attrs, "href")
                if href and href:match("forums/[^/]+%.%d+/") then
                    local name = Util.stripTags(anchor_html)
                    if name ~= "" and not name:find("^RSS") then
                        table.insert(forums, {
                            name = Util.decodeHtml(name),
                            url = Util.absoluteUrl(self.base_url, href),
                        })
                    end
                end
            end
        end
    end

    -- Fallback: parse all forum links
    if #forums == 0 then
        for anchor_attrs in html:gmatch("<a([^>]*)>") do
            local href = Util.getAttribute(anchor_attrs, "href")
            if href and href:match("forums/[^/]+%.%d+/?$") then
                local title = Util.getAttribute(anchor_attrs, "title")
                    or Util.getAttribute(anchor_attrs, "data-xf-init")
                if not title or title == "" then
                    title = href:match("/forums/([^%.]+)")
                    if title then
                        title = title:gsub("%-", " ")
                        title = title:sub(1, 1):upper() .. title:sub(2)
                    end
                end
                if title and title ~= "" then
                    table.insert(forums, {
                        name = Util.decodeHtml(title),
                        url = Util.absoluteUrl(self.base_url, href),
                    })
                end
            end
        end
    end

    forums = Util.uniqueBy(forums, "url")
    return forums
end

function Source:getThreadList(forum, page)
    page = page or 1
    local ok, err = self:ensureLoggedIn()
    if not ok then
        return nil, err
    end

    local url = forum.url
    if page > 1 then
        url = url:gsub("/$", "") .. "/page-" .. page
    end

    local html, fetch_err = self:authGet(url)
    if not html then
        return nil, fetch_err
    end

    local threads = {}
    -- Parse thread entries
    for block in html:gmatch('<div[^>]-class="[^"]*structItem[^"]*"[^>]*>(.-)</div>%s*</div>') do
        local href, title
        for a_attrs, a_html in block:gmatch("<a([^>]*)>([%s%S]-)</a>") do
            local h = Util.getAttribute(a_attrs, "href")
            if h and h:match("threads/[^/]+%.%d+/") then
                href = h
                title = Util.stripTags(a_html)
                break
            end
        end
        if href and title and title ~= "" then
            table.insert(threads, {
                source_id = self.id,
                title = Util.decodeHtml(title),
                url = Util.absoluteUrl(self.base_url, href),
                kind = self.kind,
            })
        end
    end

    -- Fallback parsing
    if #threads == 0 then
        for anchor_attrs, anchor_html in html:gmatch("<a([^>]*)>([%s%S]-)</a>") do
            local href = Util.getAttribute(anchor_attrs, "href")
            if href and href:match("threads/[^/]+%.%d+/") and not href:match("members/") then
                local title = Util.stripTags(anchor_html)
                if title ~= "" and #title > 3 and not title:match("^%d+/%d+/%d+") then
                    table.insert(threads, {
                        source_id = self.id,
                        title = Util.decodeHtml(title),
                        url = Util.absoluteUrl(self.base_url, href),
                        kind = self.kind,
                    })
                end
            end
        end
    end

    threads = Util.uniqueBy(threads, "url")

    -- Parse pagination
    local total_pages = page
    for p in html:gmatch("/page%-(%d+)") do
        total_pages = math.max(total_pages, tonumber(p) or 1)
    end

    return {
        threads = threads,
        page = page,
        total_pages = total_pages,
        forum = forum,
    }
end

-- Thread detail + attachments
function Source:getThreadDetail(thread)
    local ok, err = self:ensureLoggedIn()
    if not ok then
        return nil, err
    end

    local html, fetch_err = self:authGet(thread.url)
    if not html then
        return nil, fetch_err
    end

    -- Parse posts
    local posts = {}
    local all_links = {}
    local all_attachments = {}
    
    for post_html in html:gmatch('<li[^>]*class="[^"]*message[^"]*"[^>]*>(.-)<div class="messageMeta') do
        local author = post_html:match('data%-author="([^"]+)"')
        if not author then
            author = post_html:match('class="username"[^>]*>([^<]+)</a>')
        end
        author = author and Util.trim(Util.stripTags(author)) or "Ẩn danh"
        
        local date = post_html:match('<span class="DateTime"[^>]*>([^<]+)</span>')
        if not date then
            date = post_html:match('data%-datestring="([^"]+)"')
        end
        date = date or ""
        
        local content = post_html:match('<blockquote class="messageText[^"]*">(.-)</blockquote>')
        
        if content then
            -- Extract external links (GDrive, Mega, Mediafire, etc)
            for href in content:gmatch('href="([^"]+)"') do
                local lower_href = href:lower()
                if lower_href:find("drive%.google%.com") or 
                   lower_href:find("mega%.nz") or 
                   lower_href:find("mediafire%.com") or
                   lower_href:find("fshare%.vn") or
                   lower_href:find("box%.com") or
                   lower_href:find("onedrive%.live") then
                    table.insert(all_links, {
                        url = href,
                        author = author
                    })
                end
            end
            
            -- Extract Xenforo attachments
            for anchor_attrs, anchor_html in content:gmatch("<a([^>]*)>([%s%S]-)</a>") do
                local href = Util.getAttribute(anchor_attrs, "href")
                if href and href:match("/attachments/[^/]+%.%d+/") then
                    local filename = Util.stripTags(anchor_html)
                    if filename == "" then
                        filename = href:match("/attachments/([^/]+)%.%d+/")
                        if filename then filename = filename:gsub("%-", " ") end
                    end
                    if filename and filename ~= "" then
                        local size = ""
                        local size_pattern = filename:gsub("[%(%)%.%%%+%-%*%?%[%]%^%$]", "%%%0")
                        local after = post_html:match(size_pattern .. "[^%d]*(%d[%d,%.]+%s*[KMG]?B)")
                        table.insert(all_attachments, {
                            filename = Util.decodeHtml(filename),
                            url = Util.absoluteUrl(self.base_url, href),
                            size = after or "",
                            author = author
                        })
                    end
                end
            end
            
            table.insert(posts, {
                author = author,
                date = date,
                content = content
            })
        end
    end

    all_attachments = Util.uniqueBy(all_attachments, "url")
    all_links = Util.uniqueBy(all_links, "url")

    return {
        thread = thread,
        posts = posts,
        attachments = all_attachments,
        external_links = all_links
    }
end

function Source:downloadAttachment(attachment, save_path)
    local ok, err = self:ensureLoggedIn()
    if not ok then
        return nil, err
    end

    Debug.write("[TVE4U] Downloading attachment: " .. attachment.url .. " -> " .. save_path)

    local content, fetch_err, headers = self:authGet(attachment.url)
    if not content then
        return nil, fetch_err
    end

    if #content < 100 and content:find("login", 1, true) then
        -- Re-login and retry
        self._logged_in = false
        self._cookies = nil
        ok, err = self:ensureLoggedIn()
        if not ok then
            return nil, "Cần đăng nhập lại: " .. tostring(err)
        end
        content, fetch_err = self:authGet(attachment.url)
        if not content then
            return nil, fetch_err
        end
    end

    local temp_path = save_path .. ".part"
    local file, open_err = io.open(temp_path, "wb")
    if not file then
        return nil, "Không thể tạo file: " .. tostring(open_err)
    end
    local written, write_err = file:write(content)
    file:close()
    if not written then
        os.remove(temp_path)
        return nil, "Không thể ghi file: " .. tostring(write_err)
    end

    local rename_ok, rename_err = os.rename(temp_path, save_path)
    if not rename_ok then
        os.remove(temp_path)
        return nil, "Không thể lưu file: " .. tostring(rename_err)
    end

    Debug.write("[TVE4U] Download complete: " .. save_path .. " (" .. #content .. " bytes)")
    return save_path
end

-- Search
function Source:search(query)
    local ok, err = self:ensureLoggedIn()
    if not ok then
        return nil, err
    end

    local encoded = ko_util.urlEncode(query):gsub("%%20", "+")
    local url = self.base_url .. "/search/search?keywords=" .. encoded .. "&type=thread&order=relevance"
    local html, fetch_err = self:authGet(url)
    if not html then
        return nil, fetch_err
    end

    local stories = {}
    for anchor_attrs, anchor_html in html:gmatch("<a([^>]*)>([%s%S]-)</a>") do
        local href = Util.getAttribute(anchor_attrs, "href")
        if href and href:match("/threads/[^/]+%.%d+/") then
            local title = Util.stripTags(anchor_html)
            if title ~= "" and #title > 3 and not title:match("^%d+/%d+") then
                table.insert(stories, {
                    source_id = self.id,
                    title = Util.decodeHtml(title),
                    url = Util.absoluteUrl(self.base_url, href),
                    kind = self.kind,
                })
            end
        end
    end

    return Util.uniqueBy(stories, "url")
end

-- Compatibility stubs for source_registry
function Source:getCoverHeaders()
    return { ["Referer"] = self.base_url .. "/" }
end

function Source:getCompleted(page)
    local forums = self:getForumList()
    if not forums then
        return { stories = {}, genres = {}, page = 1, total_pages = 1, title = "TVE-4U" }
    end
    -- Return forums as "genres" for browsing
    return {
        stories = {},
        genres = {},
        page = 1,
        total_pages = 1,
        title = "Diễn đàn TVE-4U",
    }
end

return Source
