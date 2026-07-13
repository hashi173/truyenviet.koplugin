local http = require("socket.http")
local ltn12 = require("ltn12")
local socket = require("socket")
local socket_url = require("socket.url")
local socketutil = require("socketutil")
local ko_util = require("util")
local Debug = require("truyenviet/debugger")

local parse_url = socket_url.parse
local function parseProxy(proxy_str)
    if not proxy_str or proxy_str == "" then return nil end
    local host, port = proxy_str:match("^https?://([^:/]+):?(%d*)")
    if not host then
        host, port = proxy_str:match("^([^:/]+):?(%d*)")
    end
    port = tonumber(port) or 8080
    return host, port
end

local function parseTarget(url_str)
    local parsed = parse_url(url_str)
    if not parsed then return nil, 80 end
    local host = parsed.host
    local port = tonumber(parsed.port)
    if not port then
        if parsed.scheme == "https" then
            port = 443
        else
            port = 80
        end
    end
    return host, port
end

local function create_proxy_socket(proxy_host, proxy_port, target_host, target_port)
    return function()
        local conn = socket.tcp()
        conn:settimeout(socketutil.block_timeout or 15, "b")
        conn:settimeout(socketutil.total_timeout or 60, "t")
        
        local ok, err = conn:connect(proxy_host, proxy_port)
        if not ok then
            Debug.write(string.format("[PROXY CONNECT ERROR] Cannot connect to proxy %s:%d - %s", proxy_host, proxy_port, tostring(err)))
            return nil, err
        end
        
        -- Send CONNECT command
        local req = string.format("CONNECT %s:%d HTTP/1.1\r\nHost: %s:%d\r\n\r\n", target_host, target_port, target_host, target_port)
        conn:send(req)
        
        -- Read response
        local status_line, status_err = conn:receive("*l")
        if not status_line then
            conn:close()
            Debug.write("[PROXY CONNECT ERROR] Proxy closed connection during CONNECT handshake")
            return nil, status_err or "Proxy closed connection"
        end
        
        local code = status_line:match("HTTP/%d%.%d%s+(%d+)")
        if code ~= "200" then
            conn:close()
            Debug.write("[PROXY CONNECT ERROR] Proxy returned HTTP status code: " .. tostring(code))
            return nil, "Proxy returned HTTP " .. tostring(code)
        end
        
        -- Read headers
        while true do
            local line, hdr_err = conn:receive("*l")
            if not line or line == "" then
                break
            end
        end
        
        -- Mock connect to do nothing and return success
        conn.real_connect = conn.connect
        conn.connect = function(self, host, port)
            return 1
        end
        
        Debug.write(string.format("[PROXY CONNECT SUCCESS] Tunnel established to %s:%d", target_host, target_port))
        return conn
    end
end

if not http._original_request then
    http._original_request = http.request
    http.request = function(reqt, body)
        local is_table = (type(reqt) == "table")
        local url_str = is_table and reqt.url or reqt
        
        local old_proxy = http.PROXY
        local proxy_host, proxy_port = parseProxy(old_proxy)
        local is_https = url_str and url_str:lower():sub(1, 8) == "https://"
        
        Debug.write(string.format("[HTTP wrapper] request: %s, is_https: %s, proxy: %s", tostring(url_str), tostring(is_https), tostring(old_proxy)))
        
        if is_https and proxy_host then
            local target_host, target_port = parseTarget(url_str)
            if not is_table then
                reqt = {
                    url = url_str,
                    method = "GET",
                    source = body and ltn12.source.string(body) or nil,
                }
                is_table = true
            end
            
            reqt.create = create_proxy_socket(proxy_host, proxy_port, target_host, target_port)
            http.PROXY = nil
            
            local success, r1, r2, r3, r4 = pcall(http._original_request, reqt)
            http.PROXY = old_proxy
            if success then
                return r1, r2, r3, r4
            else
                error(r1)
            end
        else
            -- Direct connection or plain HTTP through proxy
            http.PROXY = nil
            if not is_https then
                http.PROXY = old_proxy
            end
            local success, r1, r2, r3, r4 = pcall(http._original_request, reqt, body)
            http.PROXY = old_proxy
            if success then
                return r1, r2, r3, r4
            else
                error(r1)
            end
        end
    end
end

local HttpClient = {
    connect_timeout = 15,
    total_timeout = 60,
    user_agent = "Mozilla/5.0 (Linux; Android 13) KOReader TruyenViet/0.1",
}

local function mergeHeaders(extra)
    local headers = {
        ["Accept"] = "text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8",
        ["Accept-Language"] = "vi-VN,vi;q=0.9,en-US;q=0.8,en;q=0.7",
        ["User-Agent"] = HttpClient.user_agent,
    }
    for key, value in pairs(extra or {}) do
        headers[key] = value
    end
    return headers
end

local function validateUrl(url)
    local parsed = socket_url.parse(url)
    return parsed and (parsed.scheme == "http" or parsed.scheme == "https")
end

-- isCloudflare/curlFallback ĐẶT Ở CẤP MODULE (không nằm trong bất kỳ hàm nào)
-- để cả HttpClient:request (sync) lẫn HttpClient:requestAsync (async, dùng để
-- tải cover/chapter) đều gọi được. Trước đây 2 hàm này bị dán nhầm vào NẰM
-- BÊN TRONG thân hàm HttpClient:request, nên requestAsync gọi tới sẽ coi
-- isCloudflare/curlFallback là biến global rỗng (nil) và luôn crash với lỗi
-- "attempt to call global 'isCloudflare' (a nil value)" — đây là nguyên nhân
-- khiến MỌI lần tải cover đều lỗi, làm việc vào 1 nguồn truyện "tải mãi
-- không xong".
-- Tìm ra nguyên nhân thật của lỗi "400 Problems parsing JSON" khi gửi báo lỗi
-- lên GitHub (13/07/2026): file log debug ghi thẳng NỘI DUNG NHỊ PHÂN THÔ của
-- response (ảnh .webp/.jpg...) vào file text log. Khi trích log để gửi báo
-- cáo, các byte điều khiển/UTF-8 hỏng lẫn trong đó phá vỡ cấu trúc JSON gửi
-- lên GitHub. Sửa tận gốc: không ghi thẳng bytes nhị phân vào log nữa, chỉ ghi
-- loại nội dung + kích thước nếu không phải text.
local function safeLogPreview(content, response_headers, max_len)
    max_len = max_len or 100
    local content_type = ""
    if response_headers then
        content_type = tostring(response_headers["content-type"] or ""):lower()
    end
    local is_text = content_type == ""
        or content_type:find("text/", 1, true)
        or content_type:find("json", 1, true)
        or content_type:find("xml", 1, true)
        or content_type:find("javascript", 1, true)
        or content_type:find("urlencoded", 1, true)
    if not is_text then
        return string.format("[nhị phân, %s, %d bytes - không ghi log]", content_type ~= "" and content_type or "?", #content)
    end
    return content:sub(1, max_len)
end

local function isCloudflare(content)
    if content and (content:find("window._cf_chl_opt", 1, true) or content:find('id="challenge%-error%-text"', 1, true) or content:find("<title>Just a moment...</title>", 1, true)) then
        return true
    end
    return false
end

local function curlFallback(method, url, request_headers)
    local function runCurl(extra_args)
        local curl_cmd = "curl -skSL" .. (extra_args and (" " .. extra_args) or "")
        if method and method:upper() ~= "GET" then
            curl_cmd = curl_cmd .. string.format(' -X %s', method)
        end
        if not request_headers or not request_headers["User-Agent"] then
            curl_cmd = curl_cmd .. string.format(' -H "User-Agent: %s"', HttpClient.user_agent)
        end
        for k, v in pairs(request_headers or {}) do
            curl_cmd = curl_cmd .. string.format(' -H "%s: %s"', k, tostring(v):gsub('"', '\\"'))
        end
        curl_cmd = curl_cmd .. string.format(" '%s'", url:gsub("'", "'\\''"))

        local f = io.popen(curl_cmd)
        if not f then return nil end
        local content = f:read("*a")
        f:close()
        return content
    end

    local content = runCurl()
    if not content or content == "" then
        content = runCurl("--ciphers DEFAULT@SECLEVEL=1")
    end
    if not content or content == "" then
        return nil
    end
    if isCloudflare(content) then
        Debug.write("[HTTP ERROR] Cloudflare challenge detected in curlFallback")
        return nil, "Bị chặn bởi Cloudflare (Anti-Bot)", {}, 403, content
    end
    return content, nil, {}, 200
end

function HttpClient:request(method, url, body, headers, options)
    if not validateUrl(url) then
        Debug.write(string.format("[HTTP ERROR] Invalid URL: %s", tostring(url)))
        return nil, "URL không hợp lệ: " .. tostring(url)
    end

    Debug.write(string.format("[HTTP request start] %s %s", method, url))
    Debug.write(string.format("  http.PROXY = %s", tostring(http.PROXY)))
    local request_headers = mergeHeaders(headers)
    for k, v in pairs(request_headers) do
        Debug.write(string.format("  Req Header: %s: %s", k, v))
    end
    if body then
        Debug.write(string.format("  Req Body (len=%d): %s", #body, tostring(body):sub(1, 200)))
    end

    local redirect = true
    if type(options) == "table" and options.redirect ~= nil then
        redirect = options.redirect
    end

    local max_retries = 3
    local delay = 2
    local ok, code, response_headers, status
    local result_code, result_headers, result_status
    local sink = {}

    socketutil:set_timeout(self.connect_timeout, self.total_timeout)
    for attempt = 1, max_retries + 1 do
        sink = {}
        ok, code, response_headers, status = pcall(function()
            local req_func = http.request
            if options and options.force_luasec and url:match("^https") then
                local https = require("ssl.https")
                req_func = https._original_request or https.request_sni or https.request
            end
            return socket.skip(1, req_func({
                url = url,
                method = method,
                headers = request_headers,
                source = body and ltn12.source.string(body) or nil,
                sink = ltn12.sink.table(sink),
                redirect = false,
            }))
        end)

        local retry = false
        if not ok then
            local err_str = tostring(code)
            if err_str:find("wantread") or err_str:find("timeout") or err_str:find("closed") then
                retry = true
            end
        elseif code == socketutil.TIMEOUT_CODE
                or code == socketutil.SSL_HANDSHAKE_CODE
                or code == socketutil.SINK_TIMEOUT_CODE then
            retry = true
        elseif response_headers ~= nil then
            local numeric_code = tonumber(code)
            if numeric_code == 429 then
                retry = true
            end
        end

        if retry and attempt <= max_retries then
            Debug.write(string.format("[HTTP] Retry attempt %d after error: %s", attempt, tostring(code)))
            socket.select(nil, nil, delay)
            delay = delay * 2
        else
            if ok and response_headers ~= nil then
                result_code = tonumber(code)
                result_headers = response_headers
                result_status = status
            end
            break
        end
    end

    socketutil:reset_timeout()

    if not ok or response_headers == nil or code == socketutil.SSL_HANDSHAKE_CODE or code == socketutil.TIMEOUT_CODE then
        local err_msg = not ok and tostring(code) or tostring(code)
        Debug.write(string.format("[HTTP request fail] %s %s -> %s", method, url, err_msg))
        
        Debug.write("[HTTP] Attempting curl fallback...")
        local content, err, headers, num_code = curlFallback(method, url, request_headers)
        if content then return content, err, headers, num_code end
        
        if not ok then
            return nil, err_msg
        end
    end
    
    if code == socketutil.TIMEOUT_CODE
            or code == socketutil.SSL_HANDSHAKE_CODE
            or code == socketutil.SINK_TIMEOUT_CODE then
        Debug.write(string.format("[HTTP request timeout/ssl] %s %s -> code: %s, status: %s", method, url, tostring(code), tostring(status)))
        return nil, "Kết nối bị gián đoạn: " .. tostring(status or code)
    end
    if response_headers == nil then
        Debug.write(string.format("[HTTP request fail - no headers] %s %s -> code: %s, status: %s", method, url, tostring(code), tostring(status)))
        return nil, "Không thể kết nối tới máy chủ"
    end

    local numeric_code = result_code
    Debug.write(string.format("[HTTP request respond] %s %s -> code: %s, numeric_code: %s", method, url, tostring(code), tostring(numeric_code)))
    for k, v in pairs(response_headers) do
        Debug.write(string.format("  Resp Header: %s: %s", k, tostring(v)))
    end

    if not numeric_code or numeric_code < 200 or numeric_code >= 300 then
        local error_body = table.concat(sink)
        Debug.write(string.format("  Resp Error Body (len=%d): %s", #error_body, safeLogPreview(error_body, response_headers, 500)))
        
        if redirect ~= false and numeric_code and numeric_code >= 300 and numeric_code < 400 and response_headers["location"] then
            local new_url = response_headers["location"]
            if not new_url:match("^https?://") then
                new_url = socket_url.absolute(url, new_url)
            end
            local redirect_count = (options and options.redirect_count or 0) + 1
            if redirect_count <= 5 then
                Debug.write(string.format("[HTTP] Redirecting to %s (attempt %d)", new_url, redirect_count))
                local new_opts = {}
                if options then for k,v in pairs(options) do new_opts[k] = v end end
                new_opts.redirect_count = redirect_count
                local new_method = method
                if numeric_code == 303 or numeric_code == 301 or numeric_code == 302 then
                    new_method = "GET"
                end
                return self:request(new_method, new_url, new_method == "GET" and nil or body, headers, new_opts)
            else
                Debug.write("[HTTP ERROR] Too many redirects")
                return nil, "Quá nhiều lần chuyển hướng", response_headers, numeric_code, error_body
            end
        end

        return nil, string.format("Máy chủ trả về HTTP %s", tostring(status or code)), response_headers, numeric_code, error_body
    end

    local content = table.concat(sink)
    if isCloudflare(content) then
        Debug.write("[HTTP ERROR] Cloudflare challenge detected in 200 OK response")
        return nil, "Bị chặn bởi Cloudflare (Anti-Bot)", response_headers, 403, content
    end

    Debug.write(string.format("  Resp Body (len=%d): %s", #content, safeLogPreview(content, response_headers, 100)))
    local content_length = tonumber(response_headers["content-length"])
    if content_length and #content ~= content_length then
        Debug.write(string.format("[HTTP ERROR] Incomplete body: expected %d, got %d", content_length, #content))
        return nil, "Dữ liệu tải về không đầy đủ"
    end

    return content, nil, response_headers, numeric_code
end

function HttpClient:get(url, headers, options)
    return self:request("GET", url, nil, headers, options)
end

function HttpClient:postJson(url, payload, headers)
    local body = ko_util.jsonEncode(payload)
    headers = mergeHeaders(headers)
    headers["Content-Type"] = "application/json"
    return self:request("POST", url, body, headers)
end

function HttpClient:requestAsync(method, url, body, headers, opts)
    if not validateUrl(url) then
        Debug.write(string.format("[HTTP Async ERROR] Invalid URL: %s", tostring(url)))
        return nil, "URL không hợp lệ: " .. tostring(url)
    end
    
    Debug.write(string.format("[HTTP Async request start] %s %s", method, url))
    local request_headers = mergeHeaders(headers)
    for k, v in pairs(request_headers) do
        Debug.write(string.format("  Req Header: %s: %s", k, v))
    end
    if body then
        Debug.write(string.format("  Req Body (len=%d): %s", #body, tostring(body):sub(1, 200)))
    end

    local copas_http = require("copas.http")
    local copas = require("copas")
    local sink = {}
    if body then
        request_headers["Content-Length"] = tostring(#body)
    end
    opts = opts or {}
    local req_timeout = opts.timeout or self.total_timeout
    
    local max_retries = 3
    local delay = 2
    local ok, result, code, response_headers, status
    local result_code, result_headers, result_status
    
    for attempt = 1, max_retries + 1 do
        sink = {}
        local reqt = {
            url = url,
            method = method,
            headers = request_headers,
            source = body and ltn12.source.string(body) or nil,
            sink = ltn12.sink.table(sink),
            redirect = false,
            timeout = req_timeout
        }
        ok, result, code, response_headers, status = pcall(function()
            return copas_http.request(reqt)
        end)

        local retry = false
        if not ok then
            local err_str = tostring(result)
            if err_str:find("wantread") or err_str:find("timeout") or err_str:find("closed") then
                retry = true
            end
        elseif not result then
            local err_str = tostring(code)
            if err_str:find("wantread") or err_str:find("timeout") or err_str:find("closed") then
                retry = true
            end
        elseif response_headers ~= nil then
            local numeric_code = tonumber(code)
            if numeric_code == 429 then
                retry = true
            end
        end

        if retry and attempt <= max_retries then
            Debug.write(string.format("[HTTP Async] Retry attempt %d after error: %s", attempt, tostring(result or code)))
            copas.sleep(delay)
            delay = delay * 2
        else
            if ok and result and response_headers ~= nil then
                result_code = tonumber(code)
                result_headers = response_headers
                result_status = status
            end
            break
        end
    end

    if not ok or response_headers == nil or code == socketutil.SSL_HANDSHAKE_CODE or code == socketutil.TIMEOUT_CODE then
        local err_msg = not ok and tostring(result) or tostring(code)
        Debug.write(string.format("[HTTP Async request fail] %s %s -> %s", method, url, err_msg))
        
        Debug.write("[HTTP Async] Attempting curl fallback...")
        local content, err, headers, num_code = curlFallback(method, url, request_headers)
        if content then return content, err, headers, num_code end
        
        if not ok then
            return nil, err_msg
        end
    end

    if not ok then
        Debug.write(string.format("[HTTP Async request exception] %s %s -> %s", method, url, tostring(result)))
        return nil, tostring(result)
    end
    if not result then
        Debug.write(string.format("[HTTP Async request failed] %s %s -> code: %s, status: %s", method, url, tostring(code), tostring(status)))
        return nil, tostring(code)
    end
    
    local numeric_code = result_code
    response_headers = result_headers
    code = result_code or result_status
    status = result_status
    Debug.write(string.format("[HTTP Async request respond] %s %s -> result: %s, code: %s, numeric_code: %s", method, url, tostring(result), tostring(code), tostring(numeric_code)))
    if response_headers then
        for k, v in pairs(response_headers) do
            Debug.write(string.format("  Resp Header: %s: %s", k, tostring(v)))
        end
    end

    if not numeric_code or numeric_code < 200 or numeric_code >= 300 then
        local error_body = table.concat(sink)
        Debug.write(string.format("  Resp Error Body (len=%d): %s", #error_body, safeLogPreview(error_body, response_headers, 500)))
        
        local redirect = true
        if type(opts) == "table" and opts.redirect ~= nil then
            redirect = opts.redirect
        end
        if redirect ~= false and numeric_code and numeric_code >= 300 and numeric_code < 400 and response_headers["location"] then
            local new_url = response_headers["location"]
            if not new_url:match("^https?://") then
                new_url = socket_url.absolute(url, new_url)
            end
            local redirect_count = (opts and opts.redirect_count or 0) + 1
            if redirect_count <= 5 then
                Debug.write(string.format("[HTTP Async] Redirecting to %s (attempt %d)", new_url, redirect_count))
                local new_opts = {}
                if opts then for k,v in pairs(opts) do new_opts[k] = v end end
                new_opts.redirect_count = redirect_count
                local new_method = method
                if numeric_code == 303 or numeric_code == 301 or numeric_code == 302 then
                    new_method = "GET"
                end
                return self:requestAsync(new_method, new_url, new_method == "GET" and nil or body, headers, new_opts)
            else
                Debug.write("[HTTP Async ERROR] Too many redirects")
                return nil, "Quá nhiều lần chuyển hướng"
            end
        end

        return nil, string.format("Máy chủ trả về HTTP %s", tostring(status or code))
    end
    
    local content = table.concat(sink)
    if isCloudflare(content) then
        Debug.write("[HTTP Async ERROR] Cloudflare challenge detected in 200 OK response")
        return nil, "Bị chặn bởi Cloudflare (Anti-Bot)"
    end

    Debug.write(string.format("  Resp Body (len=%d): %s", #content, safeLogPreview(content, response_headers, 100)))
    return content, nil, response_headers, numeric_code
end

function HttpClient:getJson(url, headers)
    headers = mergeHeaders(headers)
    headers["Accept"] = "application/json"
    return self:get(url, headers)
end

function HttpClient:postForm(url, fields, headers, options)
    local parts = {}
    for key, value in pairs(fields) do
        local encoded_key = ko_util.urlEncode(tostring(key)):gsub("%%20", "+")
        local encoded_value = ko_util.urlEncode(tostring(value)):gsub("%%20", "+")
        table.insert(parts, encoded_key .. "=" .. encoded_value)
    end
    table.sort(parts)

    headers = mergeHeaders(headers)
    headers["Content-Type"] = "application/x-www-form-urlencoded; charset=UTF-8"
    return self:request("POST", url, table.concat(parts, "&"), headers, options)
end

return HttpClient