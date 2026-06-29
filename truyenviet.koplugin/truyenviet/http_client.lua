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
    user_agent = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36",
}

local function mergeHeaders(extra)
    local headers = {
        ["Accept"] = "*/*",
        ["Accept-Encoding"] = "identity",
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
            return socket.skip(1, http.request({
                url = url,
                method = method,
                headers = request_headers,
                source = body and ltn12.source.string(body) or nil,
                sink = ltn12.sink.table(sink),
                redirect = redirect,
            }))
        end)

        if not ok then
            break
        end
        if code == socketutil.TIMEOUT_CODE
                or code == socketutil.SSL_HANDSHAKE_CODE
                or code == socketutil.SINK_TIMEOUT_CODE then
            break
        end
        if response_headers == nil then
            break
        end

        local numeric_code = tonumber(code)
        if numeric_code == 429 and attempt <= max_retries then
            Debug.write(string.format("[HTTP 429] Retry attempt %d after %d seconds", attempt, delay))
            socket.select(nil, nil, delay)
            delay = delay * 2
        else
            result_code = numeric_code
            result_headers = response_headers
            result_status = status
            break
        end
    end
    socketutil:reset_timeout()

    if not ok then
        Debug.write(string.format("[HTTP request exception] %s %s -> %s", method, url, tostring(code)))
        return nil, tostring(code)
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
        Debug.write(string.format("  Resp Error Body (len=%d): %s", #error_body, error_body:sub(1, 500)))
        return nil, string.format("Máy chủ trả về HTTP %s", tostring(status or code)), response_headers, numeric_code, error_body
    end

    local content = table.concat(sink)
    if content:find("window._cf_chl_opt", 1, true) or content:find('id="challenge%-error%-text"', 1, true) or content:find("<title>Just a moment...</title>", 1, true) then
        Debug.write("[HTTP ERROR] Cloudflare challenge detected in 200 OK response")
        return nil, "Bị chặn bởi Cloudflare (Anti-Bot)", response_headers, 403, content
    end

    Debug.write(string.format("  Resp Body (len=%d): %s", #content, content:sub(1, 100)))
    local content_length = tonumber(response_headers["content-length"])
    if content_length and #content ~= content_length then
        Debug.write(string.format("[HTTP ERROR] Incomplete body: expected %d, got %d", content_length, #content))
        return nil, "Dữ liệu tải về không đầy đủ"
    end

    return content, nil, response_headers, numeric_code
end

function HttpClient:get(url, headers)
    return self:request("GET", url, nil, headers)
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
            redirect = true,
            timeout = req_timeout
        }
        ok, result, code, response_headers, status = pcall(function()
            return copas_http.request(reqt)
        end)

        if not ok or not result then
            break
        end

        local numeric_code = tonumber(code)
        if numeric_code == 429 and attempt <= max_retries then
            Debug.write(string.format("[HTTP Async 429] Retry attempt %d after %d seconds", attempt, delay))
            copas.sleep(delay)
            delay = delay * 2
        else
            result_code = numeric_code
            result_headers = response_headers
            result_status = status
            break
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
        Debug.write(string.format("  Resp Error Body (len=%d): %s", #error_body, error_body:sub(1, 500)))
        return nil, string.format("Máy chủ trả về HTTP %s", tostring(status or code))
    end
    
    local content = table.concat(sink)
    if content:find("window._cf_chl_opt", 1, true) or content:find('id="challenge%-error%-text"', 1, true) or content:find("<title>Just a moment...</title>", 1, true) then
        Debug.write("[HTTP Async ERROR] Cloudflare challenge detected in 200 OK response")
        return nil, "Bị chặn bởi Cloudflare (Anti-Bot)"
    end

    Debug.write(string.format("  Resp Body (len=%d): %s", #content, content:sub(1, 100)))
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
