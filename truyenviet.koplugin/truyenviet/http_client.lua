local http = require("socket.http")
local ltn12 = require("ltn12")
local socket = require("socket")
local socket_url = require("socket.url")
local socketutil = require("socketutil")
local ko_util = require("util")

local HttpClient = {
    connect_timeout = 15,
    total_timeout = 60,
    user_agent = "Mozilla/5.0 (Linux; Android 13) KOReader TruyenViet/0.1",
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

function HttpClient:request(method, url, body, headers)
    if not validateUrl(url) then
        return nil, "URL không hợp lệ: " .. tostring(url)
    end

    local sink = {}
    local request_headers = mergeHeaders(headers)
    if body then
        request_headers["Content-Length"] = tostring(#body)
    end

    socketutil:set_timeout(self.connect_timeout, self.total_timeout)
    local ok, code, response_headers, status = pcall(function()
        return socket.skip(1, http.request({
            url = url,
            method = method,
            headers = request_headers,
            source = body and ltn12.source.string(body) or nil,
            sink = socketutil.table_sink(sink),
            redirect = true,
        }))
    end)
    socketutil:reset_timeout()

    if not ok then
        return nil, tostring(code)
    end
    if code == socketutil.TIMEOUT_CODE
            or code == socketutil.SSL_HANDSHAKE_CODE
            or code == socketutil.SINK_TIMEOUT_CODE then
        return nil, "Kết nối bị gián đoạn: " .. tostring(status or code)
    end
    if response_headers == nil then
        return nil, "Không thể kết nối tới máy chủ"
    end

    local numeric_code = tonumber(code)
    if not numeric_code or numeric_code < 200 or numeric_code >= 300 then
        return nil, string.format("Máy chủ trả về HTTP %s", tostring(status or code))
    end

    local content = table.concat(sink)
    local content_length = tonumber(response_headers["content-length"])
    if content_length and #content ~= content_length then
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

function HttpClient:requestAsync(method, url, body, headers)
    if not validateUrl(url) then
        return nil, "URL không hợp lệ: " .. tostring(url)
    end
    local ok, copas_http = pcall(require, "copas.http")
    if not ok then
        return self:request(method, url, body, headers)
    end
    
    local sink = {}
    local request_headers = mergeHeaders(headers)
    if body then
        request_headers["Content-Length"] = tostring(#body)
    end
    local reqt = {
        url = url,
        method = method,
        headers = request_headers,
        source = body and ltn12.source.string(body) or nil,
        sink = ltn12.sink.table(sink),
        redirect = true,
        timeout = self.total_timeout
    }
    local ok, result, code, response_headers, status = pcall(function()
        return copas_http.request(reqt)
    end)
    if not ok then
        return nil, tostring(result)
    end
    if not result then
        return nil, tostring(code)
    end
    local numeric_code = tonumber(code)
    if not numeric_code or numeric_code < 200 or numeric_code >= 300 then
        return nil, string.format("Máy chủ trả về HTTP %s", tostring(status or code))
    end
    local content = table.concat(sink)
    return content, nil, response_headers, numeric_code
end

function HttpClient:getJson(url, headers)
    headers = mergeHeaders(headers)
    headers["Accept"] = "application/json"
    return self:get(url, headers)
end

function HttpClient:postForm(url, fields, headers)
    local parts = {}
    for key, value in pairs(fields) do
        local encoded_key = ko_util.urlEncode(tostring(key)):gsub("%%20", "+")
        local encoded_value = ko_util.urlEncode(tostring(value)):gsub("%%20", "+")
        table.insert(parts, encoded_key .. "=" .. encoded_value)
    end
    table.sort(parts)

    headers = mergeHeaders(headers)
    headers["Content-Type"] = "application/x-www-form-urlencoded; charset=UTF-8"
    return self:request("POST", url, table.concat(parts, "&"), headers)
end

return HttpClient
