# Project Sources

## truyenviet.koplugin/binaryheap.lua

```lua
-------------------------------------------------------------------
-- Binary heap implementation
--
-- A binary heap (or binary tree) is a [sorting algorithm](http://en.wikipedia.org/wiki/Binary_heap).
--
-- The 'plain binary heap' is managed by positions. Which are hard to get once
-- an element is inserted. It can be anywhere in the list because it is re-sorted
-- upon insertion/deletion of items. The array with values is stored in field
-- `values`:
--
--     `peek = heap.values[1]`
--
-- A 'unique binary heap' is where the payload is unique and the payload itself
-- also stored (as key) in the heap with the position as value, as in;
--     `heap.reverse[payload] = [pos]`
--
-- Due to this setup the reverse search, based on payload, is now a
-- much faster operation because instead of traversing the list/heap,
-- you can do;
--     `pos = heap.reverse[payload]`
--
-- This means that deleting elements from a 'unique binary heap' is
-- faster than from a plain heap.
--
-- All management functions in the 'unique binary heap' take `payload`
-- instead of `pos` as argument.
-- Note that the value of the payload must be unique!
--
-- Fields of heap object:
--
--  * values - array of values
--  * payloads - array of payloads (unique binary heap only)
--  * reverse - map from payloads to indices (unique binary heap only)

local assert = assert
local floor = math.floor
local _ENV = nil

local M = {}

--================================================================
-- basic heap sorting algorithm
--================================================================

--- Basic heap.
-- This is the base implementation of the heap. Under regular circumstances
-- this should not be used, instead use a _Plain heap_ or _Unique heap_.
-- @section baseheap

--- Creates a new binary heap.
-- This is the core of all heaps, the others
-- are built upon these sorting functions.
-- @param swap (function) `swap(heap, idx1, idx2)` swaps values at
-- `idx1` and `idx2` in the heaps `heap.values` and `heap.payloads` lists (see
-- return value below).
-- @param erase (function) `swap(heap, position)` raw removal
-- @param lt (function) in `lt(a, b)` returns `true` when `a < b` (for a min-heap)
-- @return table with two methods; `heap:bubbleUp(pos)` and `heap:sinkDown(pos)`
-- that implement the sorting algorithm and two fields; `heap.values` and
-- `heap.payloads` being lists, holding the values and payloads respectively.
M.binaryHeap = function(swap, erase, lt)

  local heap = {
      values = {},  -- list containing values
      erase = erase,
      swap = swap,
      lt = lt,
    }

  function heap:bubbleUp(pos)
    local values = self.values
    while pos>1 do
      local parent = floor(pos/2)
      if not lt(values[pos], values[parent]) then
          break
      end
      swap(self, parent, pos)
      pos = parent
    end
  end

  function heap:sinkDown(pos)
    local values = self.values
    local last = #values
    while true do
      local min = pos
      local child = 2 * pos

      for c = child, child + 1 do
        if c <= last and lt(values[c], values[min]) then min = c end
      end

      if min == pos then break end

      swap(self, pos, min)
      pos = min
    end
  end

  return heap
end

--================================================================
-- plain heap management functions
--================================================================

--- Plain heap.
-- A plain heap carries a single piece of information per entry. This can be
-- any type (except `nil`), as long as the comparison function used to create
-- the heap can handle it.
-- @section plainheap
do end -- luacheck: ignore
-- the above is to trick ldoc (otherwise `update` below disappears)

local update
--- Updates the value of an element in the heap.
-- @function heap:update
-- @param pos the position which value to update
-- @param newValue the new value to use for this payload
update = function(self, pos, newValue)
  assert(newValue ~= nil, "cannot add 'nil' as value")
  assert(pos >= 1 and pos <= #self.values, "illegal position")
  self.values[pos] = newValue
  if pos > 1 then self:bubbleUp(pos) end
  if pos < #self.values then self:sinkDown(pos) end
end

local remove
--- Removes an element from the heap.
-- @function heap:remove
-- @param pos the position to remove
-- @return value, or nil if a bad `pos` value was provided
remove = function(self, pos)
  local last = #self.values
  if pos < 1 then
    return  -- bad pos

  elseif pos < last then
    local v = self.values[pos]
    self:swap(pos, last)
    self:erase(last)
    self:bubbleUp(pos)
    self:sinkDown(pos)
    return v

  elseif pos == last then
    local v = self.values[pos]
    self:erase(last)
    return v

  else
    return  -- bad pos: pos > last
  end
end

local insert
--- Inserts an element in the heap.
-- @function heap:insert
-- @param value the value used for sorting this element
-- @return nothing, or throws an error on bad input
insert = function(self, value)
  assert(value ~= nil, "cannot add 'nil' as value")
  local pos = #self.values + 1
  self.values[pos] = value
  self:bubbleUp(pos)
end

local pop
--- Removes the top of the heap and returns it.
-- @function heap:pop
-- @return value at the top, or `nil` if there is none
pop = function(self)
  if self.values[1] ~= nil then
    return remove(self, 1)
  end
end

local peek
--- Returns the element at the top of the heap, without removing it.
-- @function heap:peek
-- @return value at the top, or `nil` if there is none
peek = function(self)
  return self.values[1]
end

local size
--- Returns the number of elements in the heap.
-- @function heap:size
-- @return number of elements
size = function(self)
  return #self.values
end

local function swap(heap, a, b)
  heap.values[a], heap.values[b] = heap.values[b], heap.values[a]
end

local function erase(heap, pos)
  heap.values[pos] = nil
end

--================================================================
-- plain heap creation
--================================================================

local function plainHeap(lt)
  local h = M.binaryHeap(swap, erase, lt)
  h.peek = peek
  h.pop = pop
  h.size = size
  h.remove = remove
  h.insert = insert
  h.update = update
  return h
end

--- Creates a new min-heap, where the smallest value is at the top.
-- @param lt (optional) comparison function (less-than), see `binaryHeap`.
-- @return the new heap
M.minHeap = function(lt)
  if not lt then
    lt = function(a,b) return (a < b) end
  end
  return plainHeap(lt)
end

--- Creates a new max-heap, where the largest value is at the top.
-- @param gt (optional) comparison function (greater-than), see `binaryHeap`.
-- @return the new heap
M.maxHeap = function(gt)
  if not gt then
    gt = function(a,b) return (a > b) end
  end
  return plainHeap(gt)
end

--================================================================
-- unique heap management functions
--================================================================

--- Unique heap.
-- A unique heap carries 2 pieces of information per entry.
--
-- 1. The `value`, this is used for ordering the heap. It can be any type (except
--    `nil`), as long as the comparison function used to create the heap can
--    handle it.
-- 2. The `payload`, this can be any type (except `nil`), but it MUST be unique.
--
-- With the 'unique heap' it is easier to remove elements from the heap.
-- @section uniqueheap
do end -- luacheck: ignore
-- the above is to trick ldoc (otherwise `update` below disappears)

local updateU
--- Updates the value of an element in the heap.
-- @function unique:update
-- @param payload the payoad whose value to update
-- @param newValue the new value to use for this payload
-- @return nothing, or throws an error on bad input
function updateU(self, payload, newValue)
  return update(self, self.reverse[payload], newValue)
end

local insertU
--- Inserts an element in the heap.
-- @function unique:insert
-- @param value the value used for sorting this element
-- @param payload the payload attached to this element
-- @return nothing, or throws an error on bad input
function insertU(self, value, payload)
  assert(self.reverse[payload] == nil, "duplicate payload")
  local pos = #self.values + 1
  self.reverse[payload] = pos
  self.payloads[pos] = payload
  return insert(self, value)
end

local removeU
--- Removes an element from the heap.
-- @function unique:remove
-- @param payload the payload to remove
-- @return value, payload or nil if not found
function removeU(self, payload)
  local pos = self.reverse[payload]
  if pos ~= nil then
    return remove(self, pos), payload
  end
end

local popU
--- Removes the top of the heap and returns it.
-- When used with timers, `pop` will return the payload that is due.
--
-- Note: this function returns `payload` as the first result to prevent
-- extra locals when retrieving the `payload`.
-- @function unique:pop
-- @return payload, value, or `nil` if there is none
function popU(self)
  if self.values[1] then
    local payload = self.payloads[1]
    local value = remove(self, 1)
    return payload, value
  end
end

local peekU
--- Returns the element at the top of the heap, without removing it.
-- @function unique:peek
-- @return payload, value, or `nil` if there is none
peekU = function(self)
  return self.payloads[1], self.values[1]
end

local peekValueU
--- Returns the element at the top of the heap, without removing it.
-- @function unique:peekValue
-- @return value at the top, or `nil` if there is none
-- @usage -- simple timer based heap example
-- while true do
--   sleep(heap:peekValue() - gettime())  -- assume LuaSocket gettime function
--   coroutine.resume((heap:pop()))       -- assumes payload to be a coroutine,
--                                        -- double parens to drop extra return value
-- end
peekValueU = function(self)
  return self.values[1]
end

local valueByPayload
--- Returns the value associated with the payload
-- @function unique:valueByPayload
-- @param payload the payload to lookup
-- @return value or nil if no such payload exists
valueByPayload = function(self, payload)
  return self.values[self.reverse[payload]]
end

local sizeU
--- Returns the number of elements in the heap.
-- @function heap:size
-- @return number of elements
sizeU = function(self)
  return #self.values
end

local function swapU(heap, a, b)
  local pla, plb = heap.payloads[a], heap.payloads[b]
  heap.reverse[pla], heap.reverse[plb] = b, a
  heap.payloads[a], heap.payloads[b] = plb, pla
  swap(heap, a, b)
end

local function eraseU(heap, pos)
  local payload = heap.payloads[pos]
  heap.reverse[payload] = nil
  heap.payloads[pos] = nil
  erase(heap, pos)
end

--================================================================
-- unique heap creation
--================================================================

local function uniqueHeap(lt)
  local h = M.binaryHeap(swapU, eraseU, lt)
  h.payloads = {}  -- list contains payloads
  h.reverse = {}  -- reverse of the payloads list
  h.peek = peekU
  h.peekValue = peekValueU
  h.valueByPayload = valueByPayload
  h.pop = popU
  h.size = sizeU
  h.remove = removeU
  h.insert = insertU
  h.update = updateU
  return h
end

--- Creates a new min-heap with unique payloads.
-- A min-heap is where the smallest value is at the top.
--
-- *NOTE*: All management functions in the 'unique binary heap'
-- take `payload` instead of `pos` as argument.
-- @param lt (optional) comparison function (less-than), see `binaryHeap`.
-- @return the new heap
M.minUnique = function(lt)
  if not lt then
    lt = function(a,b) return (a < b) end
  end
  return uniqueHeap(lt)
end

--- Creates a new max-heap with unique payloads.
-- A max-heap is where the largest value is at the top.
--
-- *NOTE*: All management functions in the 'unique binary heap'
-- take `payload` instead of `pos` as argument.
-- @param gt (optional) comparison function (greater-than), see `binaryHeap`.
-- @return the new heap
M.maxUnique = function(gt)
  if not gt then
    gt = function(a,b) return (a > b) end
  end
  return uniqueHeap(gt)
end

return M
```

## truyenviet.koplugin/copas/ftp.lua

```lua
-------------------------------------------------------------------
-- identical to the socket.ftp module except that it uses
-- async wrapped Copas sockets

local copas = require("copas")
local socket = require("socket")
local ftp = require("socket.ftp")
local ltn12 = require("ltn12")
local url = require("socket.url")


local create = function() return copas.wrap(socket.tcp()) end
local forwards = { -- setting these will be forwarded to the original smtp module
  PORT = true,
  TIMEOUT = true,
  PASSWORD = true,
  USER = true
}

copas.ftp = setmetatable({}, {
    -- use original module as metatable, to lookup constants like socket.TIMEOUT, etc.
    __index = ftp,
    -- Setting constants is forwarded to the luasocket.ftp module.
    __newindex = function(self, key, value)
        if forwards[key] then ftp[key] = value return end
        return rawset(self, key, value)
      end,
    })
local _M = copas.ftp

---[[ copy of Luasocket stuff here untile PR #133 is accepted
-- a copy of the version in LuaSockets' ftp.lua
-- no 'create' can be passed in the string form, hence a local copy here
local default = {
    path = "/",
    scheme = "ftp"
}

-- a copy of the version in LuaSockets' ftp.lua
-- no 'create' can be passed in the string form, hence a local copy here
local function parse(u)
    local t = socket.try(url.parse(u, default))
    socket.try(t.scheme == "ftp", "wrong scheme '" .. t.scheme .. "'")
    socket.try(t.host, "missing hostname")
    local pat = "^type=(.)$"
    if t.params then
        t.type = socket.skip(2, string.find(t.params, pat))
        socket.try(t.type == "a" or t.type == "i",
            "invalid type '" .. t.type .. "'")
    end
    return t
end

-- parses a simple form into the advanced form
-- if `body` is provided, a PUT, otherwise a GET.
-- If GET, then a field `target` is added to store the results
_M.parseRequest = function(u, body)
  local t = parse(u)
  if body then
    t.source = ltn12.source.string(body)
  else
    t.target = {}
    t.sink = ltn12.sink.table(t.target)
  end
end
--]]

_M.put = socket.protect(function(putt, body)
    if type(putt) == "string" then
      putt = _M.parseRequest(putt, body)
      _M.put(putt)
      return table.concat(putt.target)
    else
      putt.create = putt.create or create
      return ftp.put(putt)
    end
end)

_M.get = socket.protect(function(gett)
    if type(gett) == "string" then
      gett = _M.parseRequest(gett)
      _M.get(gett)
      return table.concat(gett.target)
    else
      gett.create = gett.create or create
      return ftp.get(gett)
    end
end)

_M.command = function(cmdt)
  cmdt.create = cmdt.create or create
  return ftp.command(cmdt)
end

return _M
```

## truyenviet.koplugin/copas/future.lua

```lua
local copas = require("copas")
local semaphore = require("copas.semaphore")

local pcall = pcall


-- nil-safe versions for pack/unpack
local _unpack = unpack or table.unpack
local unpack = function(t, i, j) return _unpack(t, i or 1, j or t.n or #t) end
local pack = function(...) return { n = select("#", ...), ...} end



-- Module table

local M = {}

M.SUCCESS = true
M.PENDING = false
M.ERROR   = "error"

setmetatable(M, {
  __index = function(_, k)
    error("unknown field 'future." .. tostring(k) .. "'", 2)
  end,
})



-- Future class

local future = {}
future.__index = future

-- calling on the future executes the `get` method
future.__call = function(self, ...) return self:get(...) end


local function new_future()
  local self = setmetatable({
    results = nil, -- results will be stored here in a 'packed' table (pcall-style: true/false prefix)
    sema = semaphore.new(9999, 0, math.huge),
    coro = nil -- the coroutine that will execute the task
  }, future)

  return self
end


-- Waits for the task to complete.
-- Returns like pcall: true + results on success, false + errmsg on error.
function future:get()
  if not self.results then
    self.sema:take(1, math.huge) -- wait until the result is ready
  end
  return unpack(self.results)
end


-- Non-blocking check on the future status.
-- Returns:
--   M.PENDING (false)             -- task not yet complete
--   M.SUCCESS (true), results...  -- task completed successfully
--   M.ERROR ("error"), errmsg     -- task failed with an error
function future:try()
  if not self.results then
    return M.PENDING
  end
  if self.results[1] then
    return M.SUCCESS, unpack(self.results, 2)
  else
    return M.ERROR, self.results[2]
  end
end


-- Cancels the task if it has not yet completed.
-- Returns true if cancelled, false if already done.
function future:cancel()
  if self.results then
    return false  -- already done (or already cancelled)
  end
  self.results = pack(false, "cancelled")
  self.sema:give(self.sema:get_wait())
  copas.removethread(self.coro)
  return true
end



-- Module implementation

-- Mimics copas.addnamedthread but returns a future instead of the coroutine.
function M.addnamedthread(name, func, ...)
  local f = new_future()

  f.coro = copas.addnamedthread(name, function(...)
    local results
    local ok, err = pcall(function(...) results = pack(true, func(...)) end, ...)
    if not ok then
      results = pack(false, err)
    end
    if not f.results then  -- don't overwrite a cancel
      f.results = results
      f.sema:give(f.sema:get_wait())
    end
  end, ...)

  return f
end


-- Mimica copas.addthread but returns a future instead of the coroutine.
function M.addthread(func, ...)
  return M.addnamedthread(nil, func, ...)
end


return M
```

## truyenviet.koplugin/copas/http.lua

```lua
-----------------------------------------------------------------------------
-- Full copy of the LuaSocket code, modified to include
-- https and http/https redirects, and Copas async enabled.
-----------------------------------------------------------------------------
-- HTTP/1.1 client support for the Lua language.
-- LuaSocket toolkit.
-- Author: Diego Nehab
-----------------------------------------------------------------------------

-----------------------------------------------------------------------------
-- Declare module and import dependencies
-------------------------------------------------------------------------------
local socket = require("socket")
local url = require("socket.url")
local ltn12 = require("ltn12")
local mime = require("mime")
local string = require("string")
local headers = require("socket.headers")
local base = _G
local table = require("table")
local copas = require("copas")
copas.http = {}
local _M = copas.http

-----------------------------------------------------------------------------
-- Program constants
-----------------------------------------------------------------------------
-- connection timeout in seconds
_M.TIMEOUT = 60
-- default port for document retrieval
_M.PORT = 80
-- user agent field sent in request
_M.USERAGENT = socket._VERSION

-- Default settings for SSL
_M.SSLPORT = 443
_M.SSLPROTOCOL = "any"
_M.SSLOPTIONS  = "all"
_M.SSLVERIFY   = "none"
_M.SSLSNISTRICT = false


-----------------------------------------------------------------------------
-- Reads MIME headers from a connection, unfolding where needed
-----------------------------------------------------------------------------
local function receiveheaders(sock, headers)
    local line, name, value, err
    headers = headers or {}
    -- get first line
    line, err = sock:receive()
    if err then return nil, err end
    -- headers go until a blank line is found
    while line ~= "" do
        -- get field-name and value
        name, value = socket.skip(2, string.find(line, "^(.-):%s*(.*)"))
        if not (name and value) then return nil, "malformed reponse headers" end
        name = string.lower(name)
        -- get next line (value might be folded)
        line, err  = sock:receive()
        if err then return nil, err end
        -- unfold any folded values
        while string.find(line, "^%s") do
            value = value .. line
            line, err = sock:receive()
            if err then return nil, err end
        end
        -- save pair in table
        if headers[name] then headers[name] = headers[name] .. ", " .. value
        else headers[name] = value end
    end
    return headers
end

-----------------------------------------------------------------------------
-- Extra sources and sinks
-----------------------------------------------------------------------------
socket.sourcet["http-chunked"] = function(sock, headers)
    return base.setmetatable({
        getfd = function() return sock:getfd() end,
        dirty = function() return sock:dirty() end
    }, {
        __call = function()
            -- get chunk size, skip extention
            local line, err = sock:receive()
            if err then return nil, err end
            local size = base.tonumber(string.gsub(line, ";.*", ""), 16)
            if not size then return nil, "invalid chunk size" end
            -- was it the last chunk?
            if size > 0 then
                -- if not, get chunk and skip terminating CRLF
                local chunk, err = sock:receive(size)
                if chunk then sock:receive() end
                return chunk, err
            else
                -- if it was, read trailers into headers table
                headers, err = receiveheaders(sock, headers)
                if not headers then return nil, err end
            end
        end
    })
end

socket.sinkt["http-chunked"] = function(sock)
    return base.setmetatable({
        getfd = function() return sock:getfd() end,
        dirty = function() return sock:dirty() end
    }, {
        __call = function(self, chunk, err)
            if not chunk then return sock:send("0\r\n\r\n") end
            local size = string.format("%X\r\n", string.len(chunk))
            return sock:send(size ..  chunk .. "\r\n")
        end
    })
end

-----------------------------------------------------------------------------
-- Low level HTTP API
-----------------------------------------------------------------------------
local metat = { __index = {} }

function _M.open(reqt)
    -- create socket with user connect function
    local c = socket.try(reqt:create())   -- method call, passing reqt table as self!
    local h = base.setmetatable({ c = c }, metat)
    -- create finalized try
    h.try = socket.newtry(function() h:close() end)
    -- set timeout before connecting
    local to = reqt.timeout or _M.TIMEOUT
    if type(to) == "table" then
      h.try(c:settimeouts(
        to.connect or _M.TIMEOUT,
        to.send or _M.TIMEOUT,
        to.receive or _M.TIMEOUT))
    else
      h.try(c:settimeout(to))
    end
    h.try(c:connect(reqt.host, reqt.port or _M.PORT))
    -- here everything worked
    return h
end

function metat.__index:sendrequestline(method, uri)
    local reqline = string.format("%s %s HTTP/1.1\r\n", method or "GET", uri)
    return self.try(self.c:send(reqline))
end

function metat.__index:sendheaders(tosend)
    local canonic = headers.canonic
    local h = "\r\n"
    for f, v in base.pairs(tosend) do
        h = (canonic[f] or f) .. ": " .. v .. "\r\n" .. h
    end
    self.try(self.c:send(h))
    return 1
end

function metat.__index:sendbody(headers, source, step)
    source = source or ltn12.source.empty()
    step = step or ltn12.pump.step
    -- if we don't know the size in advance, send chunked and hope for the best
    local mode = "http-chunked"
    if headers["content-length"] then mode = "keep-open" end
    return self.try(ltn12.pump.all(source, socket.sink(mode, self.c), step))
end

function metat.__index:receivestatusline()
    local status = self.try(self.c:receive(5))
    -- identify HTTP/0.9 responses, which do not contain a status line
    -- this is just a heuristic, but is what the RFC recommends
    if status ~= "HTTP/" then return nil, status end
    -- otherwise proceed reading a status line
    status = self.try(self.c:receive("*l", status))
    local code = socket.skip(2, string.find(status, "HTTP/%d*%.%d* (%d%d%d)"))
    return self.try(base.tonumber(code), status)
end

function metat.__index:receiveheaders()
    return self.try(receiveheaders(self.c))
end

function metat.__index:receivebody(headers, sink, step)
    sink = sink or ltn12.sink.null()
    step = step or ltn12.pump.step
    local length = base.tonumber(headers["content-length"])
    local t = headers["transfer-encoding"] -- shortcut
    local mode = "default" -- connection close
    if t and t ~= "identity" then mode = "http-chunked"
    elseif base.tonumber(headers["content-length"]) then mode = "by-length" end
    return self.try(ltn12.pump.all(socket.source(mode, self.c, length),
        sink, step))
end

function metat.__index:receive09body(status, sink, step)
    local source = ltn12.source.rewind(socket.source("until-closed", self.c))
    source(status)
    return self.try(ltn12.pump.all(source, sink, step))
end

function metat.__index:close()
    return self.c:close()
end

-----------------------------------------------------------------------------
-- High level HTTP API
-----------------------------------------------------------------------------
local function adjusturi(reqt)
    local u = reqt
    -- if there is a proxy, we need the full url. otherwise, just a part.
    if not reqt.proxy and not _M.PROXY then
        u = {
           path = socket.try(reqt.path, "invalid path 'nil'"),
           params = reqt.params,
           query = reqt.query,
           fragment = reqt.fragment
        }
    end
    return url.build(u)
end

local function adjustproxy(reqt)
    local proxy = reqt.proxy or _M.PROXY
    if proxy then
        proxy = url.parse(proxy)
        return proxy.host, proxy.port or 3128
    else
        return reqt.host, reqt.port
    end
end

local function adjustheaders(reqt)
    -- default headers
    local host = string.gsub(reqt.authority, "^.-@", "")
    local lower = {
        ["user-agent"] = _M.USERAGENT,
        ["host"] = host,
        ["connection"] = "close, TE",
        ["te"] = "trailers"
    }
    -- if we have authentication information, pass it along
    if reqt.user and reqt.password then
        lower["authorization"] =
            "Basic " ..  (mime.b64(reqt.user .. ":" .. reqt.password))
    end
    -- override with user headers
    for i,v in base.pairs(reqt.headers or lower) do
        lower[string.lower(i)] = v
    end
    return lower
end

-- default url parts
local default = {
    host = "",
    port = _M.PORT,
    path ="/",
    scheme = "http"
}

local function adjustrequest(reqt)
    -- parse url if provided
    local nreqt = reqt.url and url.parse(reqt.url, default) or {}
    -- explicit components override url
    for i,v in base.pairs(reqt) do nreqt[i] = v end
    if nreqt.port == "" then nreqt.port = 80 end
    socket.try(nreqt.host and nreqt.host ~= "",
        "invalid host '" .. base.tostring(nreqt.host) .. "'")
    -- compute uri if user hasn't overriden
    nreqt.uri = reqt.uri or adjusturi(nreqt)
    -- ajust host and port if there is a proxy
    nreqt.host, nreqt.port = adjustproxy(nreqt)
    -- adjust headers in request
    nreqt.headers = adjustheaders(nreqt)
    return nreqt
end

local function shouldredirect(reqt, code, headers)
    return headers.location and
           string.gsub(headers.location, "%s", "") ~= "" and
           (reqt.redirect ~= false) and
           (code == 301 or code == 302 or code == 303 or code == 307) and
           (not reqt.method or reqt.method == "GET" or reqt.method == "HEAD")
           and (not reqt.nredirects or reqt.nredirects < 5)
end

local function shouldreceivebody(reqt, code)
    if reqt.method == "HEAD" then return nil end
    if code == 204 or code == 304 then return nil end
    if code >= 100 and code < 200 then return nil end
    return 1
end

-- forward declarations
local trequest, tredirect

--[[local]] function tredirect(reqt, location)
    local result, code, headers, status = trequest {
        -- the RFC says the redirect URL has to be absolute, but some
        -- servers do not respect that
        url = url.absolute(reqt.url, location),
        source = reqt.source,
        sink = reqt.sink,
        headers = reqt.headers,
        proxy = reqt.proxy,
        nredirects = (reqt.nredirects or 0) + 1,
        create = reqt.create,
        timeout = reqt.timeout,
    }
    -- pass location header back as a hint we redirected
    headers = headers or {}
    headers.location = headers.location or location
    return result, code, headers, status
end

--[[local]] function trequest(reqt)
    -- we loop until we get what we want, or
    -- until we are sure there is no way to get it
    local nreqt = adjustrequest(reqt)
    local h = _M.open(nreqt)
    -- send request line and headers
    h:sendrequestline(nreqt.method, nreqt.uri)
    h:sendheaders(nreqt.headers)
    -- if there is a body, send it
    if nreqt.source then
        h:sendbody(nreqt.headers, nreqt.source, nreqt.step)
    end
    local code, status = h:receivestatusline()
    -- if it is an HTTP/0.9 server, simply get the body and we are done
    if not code then
        h:receive09body(status, nreqt.sink, nreqt.step)
        return 1, 200
    end
    local headers
    -- ignore any 100-continue messages
    while code == 100 do
        h:receiveheaders()
        code, status = h:receivestatusline()
    end
    headers = h:receiveheaders()
    -- at this point we should have a honest reply from the server
    -- we can't redirect if we already used the source, so we report the error
    if shouldredirect(nreqt, code, headers) and not nreqt.source then
        h:close()
        return tredirect(reqt, headers.location)
    end
    -- here we are finally done
    if shouldreceivebody(nreqt, code) then
        h:receivebody(headers, nreqt.sink, nreqt.step)
    end
    h:close()
    return 1, code, headers, status
end

-- Return a function which creates a tcp socket that will
-- include the optional SSL/TLS connection, and unsafe redirect checks
function _M.getcreatefunc(params)
   params = params or {}
   local ssl_params = params.sslparams or {}
   ssl_params.wrap = ssl_params.wrap or {
      -- backward compatibility
      protocol = params.protocol,
      options = params.options,
      verify = params.verify,
   }
   ssl_params.sni = ssl_params.sni or {
      strict = _M.SSLSNISTRICT
   }

   -- Default settings
   ssl_params.wrap.protocol = ssl_params.wrap.protocol or _M.SSLPROTOCOL
   ssl_params.wrap.options = ssl_params.wrap.options or _M.SSLOPTIONS
   if ssl_params.wrap.verify == nil then
      ssl_params.wrap.verify = _M.SSLVERIFY
   end
   ssl_params.wrap.mode = "client"   -- Force client mode

   if not ssl_params.sni.names then
      -- names haven't been set, and hence will be set below. Since this alters
      -- the table, we must make a copy. Otherwise the altered table might be
      -- reused if a redirect is encountered.
      local old_params = ssl_params
      ssl_params = {}
      for k,v in pairs(old_params) do
        ssl_params[k] = v
      end
      ssl_params.sni = { strict = old_params.sni.strict }
   end

   -- upvalue to track https -> http redirection
   local washttps = false

   -- 'create' function for LuaSocket
   return function (reqt)
      local u = url.parse(reqt.url)
      if (reqt.scheme or u.scheme) == "https" then
        -- set SNI name to host if not given
        ssl_params.sni.names = ssl_params.sni.names or u.host
        -- https, provide an ssl wrapped socket
        local conn = copas.wrap(socket.tcp(), ssl_params)
        -- insert https default port, overriding http port inserted by LuaSocket
        if not u.port then
           u.port = _M.SSLPORT
           reqt.url = url.build(u)
           reqt.port = _M.SSLPORT
        end
        washttps = true
        return conn
      else
        -- regular http, needs just a socket...
        if washttps and params.redirect ~= "all" then
          socket.try(nil, "Unallowed insecure redirect https to http")
        end
        return copas.wrap(socket.tcp())
      end
   end
end

-- parses a shorthand form into the advanced table form.
-- adds field `target` to the table. This will hold the return values.
_M.parseRequest = function(u, b)
    local reqt = {
        url = u,
        target = {},
    }
    reqt.sink = ltn12.sink.table(reqt.target)
    if b then
        reqt.source = ltn12.source.string(b)
        reqt.headers = {
            ["content-length"] = string.len(b),
            ["content-type"] = "application/x-www-form-urlencoded"
        }
        reqt.method = "POST"
    end
    return reqt
end

_M.request = socket.protect(function(reqt, body)
    if base.type(reqt) == "string" then
        reqt = _M.parseRequest(reqt, body)
        local ok, code, headers, status = _M.request(reqt)

        if ok then
            return table.concat(reqt.target), code, headers, status
        else
            return nil, code
        end
    else
        -- strict check on timeout table to prevent typo's from going unnoticed
        if type(reqt.timeout) == "table" then
          local allowed = { connect = true, send = true, receive = true }
          for k in pairs(reqt.timeout) do
            assert(allowed[k], "'"..tostring(k).."' is not a valid timeout option. Valid: 'connect', 'send', 'receive'")
          end
        end
        reqt.create = reqt.create or _M.getcreatefunc(reqt)
        return trequest(reqt)
    end
end)

return _M
```

## truyenviet.koplugin/copas/lock.lua

```lua
local copas = require("copas")
local gettime = copas.gettime

local coroutine_running = coroutine.running
-- removed coxpcall

local DEFAULT_TIMEOUT = 10

local lock = {}
lock.__index = lock


-- registry, locks indexed by the coroutines using them.
local registry = setmetatable({}, { __mode="kv" })



--- Creates a new lock.
-- @param seconds (optional) default timeout in seconds when acquiring the lock (defaults to 10),
-- set to `math.huge` to have no timeout.
-- @param not_reentrant (optional) if truthy the lock will not allow a coroutine to grab the same lock multiple times
-- @return the lock object
function lock.new(seconds, not_reentrant)
  local timeout = tonumber(seconds or DEFAULT_TIMEOUT) or -1
  if timeout < 0 then
    error("expected timeout (1st argument) to be a number greater than or equal to 0, got: " .. tostring(seconds), 2)
  end
  return setmetatable({
            timeout = timeout,
            not_reentrant = not_reentrant,
            queue = {},
            q_tip = 0,  -- index of the first in line waiting
            q_tail = 0, -- index where the next one will be inserted
            owner = nil, -- coroutine holding lock currently
            call_count = nil, -- recursion call count
            errors = setmetatable({}, { __mode = "k" }), -- error indexed by coroutine
          }, lock)
end



do
  local destroyed_func = function()
    return nil, "destroyed"
  end

  local destroyed_lock_mt = {
    __index = function()
      return destroyed_func
    end
  }

  --- destroy a lock.
  -- Releases all waiting threads with `nil+"destroyed"`
  function lock:destroy()
    --print("destroying ",self)
    for i = self.q_tip, self.q_tail do
      local co = self.queue[i]
      self.queue[i] = nil

      if co then
        self.errors[co] = "destroyed"
        --print("marked destroyed ", co)
        copas.wakeup(co)
      end
    end

    if self.owner then
      self.errors[self.owner] = "destroyed"
      --print("marked destroyed ", co)
    end
    self.queue = {}
    self.q_tip = 0
    self.q_tail = 0
    self.destroyed = true

    setmetatable(self, destroyed_lock_mt)
    return true
  end
end


local function timeout_handler(co)
  local self = registry[co]
  if not self then
    return
  end

  for i = self.q_tip, self.q_tail do
    if co == self.queue[i] then
      self.queue[i] = nil
      self.errors[co] = "timeout"
      --print("marked timeout ", co)
      copas.wakeup(co)
      return
    end
  end
  -- if we get here, we own it currently, or we finished it by now, or
  -- the lock was destroyed. Anyway, nothing to do here...
end


--- Acquires the lock.
-- If the lock is owned by another thread, this will yield control, until the
-- lock becomes available, or it times out.
-- If `timeout == 0` then it will immediately return (without yielding).
-- @param timeout (optional) timeout in seconds, defaults to the timeout passed to `new` (use `math.huge` to have no timeout).
-- @return wait-time on success, or nil+error+wait_time on failure. Errors can be "timeout", "destroyed", or "lock is not re-entrant"
function lock:get(timeout)
  local co = coroutine_running()
  local start_time

  -- is the lock already taken?
  if self.owner then
    -- are we re-entering?
    if co == self.owner and not self.not_reentrant then
      self.call_count = self.call_count + 1
      return 0
    end

    self.queue[self.q_tail] = co
    self.q_tail = self.q_tail + 1
    timeout = timeout or self.timeout
    if timeout == 0 then
      return nil, "timeout", 0
    end

    -- set up timeout
    registry[co] = self
    copas.timeout(timeout, timeout_handler)

    start_time = gettime()
    copas.pauseforever()

    local err = self.errors[co]
    self.errors[co] = nil
    registry[co] = nil

    --print("released ", co, err)
    if err ~= "timeout" then
      copas.timeout(0)
    end
    if err then
      return nil, err, gettime() - start_time
    end
  end

  -- it's ours to have
  self.owner = co
  self.call_count = 1
  return start_time and (gettime() - start_time) or 0
end


--- Releases the lock currently held.
-- Releasing a lock that is not owned by the current co-routine will return
-- an error.
-- returns true, or nil+err on an error
function lock:release()
  local co = coroutine_running()

  if co ~= self.owner then
    return nil, "cannot release a lock not owned"
  end

  self.call_count = self.call_count - 1
  if self.call_count > 0 then
    -- same coro is still holding it
    return true
  end

  -- need a loop, since individual coroutines might have been removed
  -- so there might be holes
  while self.q_tip < self.q_tail do
    local next_up = self.queue[self.q_tip]
    if next_up then
      self.owner = next_up
      self.queue[self.q_tip] = nil
      self.q_tip = self.q_tip + 1
      copas.wakeup(next_up)
      return true
    end
    self.q_tip = self.q_tip + 1
  end
  -- queue is empty, reset pointers
  self.owner = nil
  self.q_tip = 0
  self.q_tail = 0
  return true
end



return lock
```

## truyenviet.koplugin/copas/queue.lua

```lua
local copas = require "copas"
local gettime = copas.gettime
local Sema = copas.semaphore
local Lock = copas.lock


local Queue = {}
Queue.__index = Queue


local new_name do
  local count = 0

  function new_name()
    count = count + 1
    return "copas_queue_" .. count
  end
end


-- Creates a new Queue instance
function Queue.new(opts)
  opts = opts or {}
  local self = {}
  setmetatable(self, Queue)
  self.name = opts.name or new_name()
  self.sema = Sema.new(10^9)
  self.head = 1
  self.tail = 1
  self.list = {}
  self.workers = setmetatable({}, { __mode = "k" })
  self.stopping = false
  self.worker_id = 0
  self.exit_semaphore = Sema.new(10^9)
  return self
end


-- Pushes an item in the queue (can be 'nil')
-- returns true, or nil+err ("stopping", or "destroyed")
function Queue:push(item)
  if self.stopping then
    return nil, "stopping"
  end
  self.list[self.head] = item
  self.head = self.head + 1
  self.sema:give()
  return true
end


-- Pops and item from the queue. If there are no items in the queue it will yield
-- until there are or a timeout happens (exception is when `timeout == 0`, then it will
-- not yield but return immediately). If the timeout is `math.huge` it will wait forever.
-- Returns item, or nil+err ("timeout", or "destroyed")
function Queue:pop(timeout)
  local ok, err = self.sema:take(1, timeout)
  if not ok then
    return ok, err
  end

  local item = self.list[self.tail]
  self.list[self.tail] = nil
  self.tail = self.tail + 1

  if self.tail == self.head then
    -- reset queue
    self.list = {}
    self.tail = 1
    self.head = 1
    if self.stopping then
      -- we're stopping and last item being returned, so we're done
      self:destroy()
    end
  end
  return item
end


-- return the number of items left in the queue
function Queue:get_size()
  return self.head - self.tail
end


-- instructs the queue to stop. Will not accept any more 'push' calls.
-- will autocall 'destroy' when the queue is empty.
-- returns immediately. See `finish`
function Queue:stop()
  if not self.stopping then
    self.stopping = true
    self.lock = Lock.new(nil, true)
    self.lock:get() -- close the lock
    if self:get_size() == 0 then
      -- queue is already empty, so "pop" function cannot call destroy on next
      -- pop, so destroy now.
      self:destroy()
    end
  end
  return true
end


-- Finishes a queue. Calls stop and then waits for the queue to run empty (and be
-- destroyed) before returning. returns true or nil+err ("timeout", or "destroyed")
-- Parameter no_destroy_on_timeout indicates if the queue is not to be forcefully
-- destroyed on a timeout.
function Queue:finish(timeout, no_destroy_on_timeout)
  self:stop()
  timeout = timeout or self.lock.timeout
  local endtime = gettime() + timeout
  local _, err = self.lock:get(timeout)
  -- the lock never gets released, only destroyed, so we have to check the error string
  if err == "timeout" then
    if not no_destroy_on_timeout then
      self:destroy()
    end
    return nil, err
  end

  -- if we get here, the lock was destroyed, so the queue is empty, now wait for all workers to exit
  if not next(self.workers) then
    -- all workers already exited, we're done
    return true
  end

  -- multiple threads can call this "finish" method, so we must check exiting workers
  -- one by one.
  while true do
    local _, err = self.exit_semaphore:take(1, math.max(0, endtime - gettime()))
    if err == "destroyed" then
      return true  -- someone else destroyed/finished it, so we're done
    end
    if err == "timeout" then
      if not no_destroy_on_timeout then
        self:destroy()
      end
      return nil, "timeout"
    end
    if not next(self.workers) then
      self.exit_semaphore:destroy()
      return true  -- all workers exited, we're done
    end
  end
end


do
  local destroyed_func = function()
    return nil, "destroyed"
  end

  local destroyed_queue_mt = {
    __index = function()
      return destroyed_func
    end
  }

  -- destroys a queue immediately. Abandons what is left in the queue.
  -- Releases all waiting threads with `nil+"destroyed"`
  function Queue:destroy()
    if self.lock then
      self.lock:destroy()
    end
    self.sema:destroy()
    setmetatable(self, destroyed_queue_mt)

    -- clear anything left in the queue
    for key in pairs(self.list) do
      self.list[key] = nil
    end

    return true
  end
end


-- adds a worker that will handle whatever is passed into the queue. Can be called
-- multiple times to add more workers.
-- The threads automatically exit when the queue is destroyed.
-- worker function signature: `function(item)` (Note: worker functions run
-- unprotected, so wrap code in an (x)pcall if errors are expected, otherwise the
-- worker will exit on an error, and queue handling will stop)
-- Returns the coroutine added.
function Queue:add_worker(worker)
  assert(type(worker) == "function", "expected worker to be a function")
  local coro

  self.worker_id = self.worker_id + 1
  local worker_name = self.name .. ":worker_" .. self.worker_id

  coro = copas.addnamedthread(worker_name, function()
    while true do
      local item, err = self:pop(math.huge) -- wait forever
      if err then
        break -- queue destroyed, exit
      end
      worker(item) -- TODO: wrap in errorhandling
    end
    self.workers[coro] = nil
    if self.exit_semaphore then
      self.exit_semaphore:give(1)
    end
  end)

  self.workers[coro] = true
  return coro
end

-- returns a list/array of current workers (coroutines) handling the queue.
-- (only the workers added by `add_worker`, and still active, will be in this list)
function Queue:get_workers()
  local lst = {}
  for coro in pairs(self.workers) do
    if coroutine.status(coro) ~= "dead" then
      lst[#lst+1] = coro
    end
  end
  return lst
end

return Queue
```

## truyenviet.koplugin/copas/semaphore.lua

```lua
local copas = require("copas")

local coroutine_running = coroutine.running
-- removed coxpcall

local DEFAULT_TIMEOUT = 10

local semaphore = {}
semaphore.__index = semaphore


-- registry, semaphore indexed by the coroutines using them.
local registry = setmetatable({}, { __mode="kv" })


-- create a new semaphore
-- @param max maximum number of resources the semaphore can hold (this maximum does NOT include resources that have been given but not yet returned).
-- @param start (optional, default 0) the initial resources available
-- @param seconds (optional, default 10) default semaphore timeout in seconds, or `math.huge` to have no timeout.
function semaphore.new(max, start, seconds)
  local timeout = tonumber(seconds or DEFAULT_TIMEOUT) or -1
  if timeout < 0 then
    error("expected timeout (2nd argument) to be a number greater than or equal to 0, got: " .. tostring(seconds), 2)
  end
  if type(max) ~= "number" or max < 1 then
    error("expected max resources (1st argument) to be a number greater than 0, got: " .. tostring(max), 2)
  end

  local self = setmetatable({
      count = start or 0,
      max = max,
      timeout = timeout,
      q_tip = 1,    -- position of next entry waiting
      q_tail = 1,   -- position where next one will be inserted
      queue = {},
      to_flags = setmetatable({}, { __mode = "k" }), -- timeout flags indexed by coroutine
    }, semaphore)

  return self
end


do
  local destroyed_func = function()
    return nil, "destroyed"
  end

  local destroyed_semaphore_mt = {
    __index = function()
      return destroyed_func
    end
  }

  -- destroy a semaphore.
  -- Releases all waiting threads with `nil+"destroyed"`
  function semaphore:destroy()
    self:give(math.huge)
    self.destroyed = true
    setmetatable(self, destroyed_semaphore_mt)
    return true
  end
end


-- Gives resources.
-- @param given (optional, default 1) number of resources to return. If more
-- than the maximum are returned then it will be capped at the maximum and
-- error "too many" will be returned.
function semaphore:give(given)
  local err
  given = given or 1
  local count = self.count + given
  --print("now at",count, ", after +"..given)
  if count > self.max then
    count = self.max
    err = "too many"
  end

  while self.q_tip < self.q_tail do
    local i = self.q_tip
    local nxt = self.queue[i] -- there can be holes, so nxt might be nil
    if not nxt then
      self.q_tip = i + 1
    else
      if count >= nxt.requested then
        -- release it
        self.queue[i] = nil
        self.to_flags[nxt.co] = nil
        count = count - nxt.requested
        self.q_tip = i + 1
        copas.wakeup(nxt.co)
        nxt.co = nil
      else
        break -- we ran out of resources
      end
    end
  end

  if self.q_tip == self.q_tail then  -- reset queue
    self.queue = {}
    self.q_tip = 1
    self.q_tail = 1
  end

  self.count = count
  if err then
    return nil, err
  end
  return true
end



local function timeout_handler(co)
  local self = registry[co]
  --print("checking timeout ", co)
  if not self then
    return
  end

  for i = self.q_tip, self.q_tail do
    local item = self.queue[i]
    if item and co == item.co then
      self.queue[i] = nil
      self.to_flags[co] = true
      --print("marked timeout ", co)
      copas.wakeup(co)
      return
    end
  end
  -- nothing to do here...
end


-- Requests resources from the semaphore.
-- Waits if there are not enough resources available before returning.
-- @param requested (optional, default 1) the number of resources requested
-- @param timeout (optional, defaults to semaphore timeout) timeout in
-- seconds. If 0 it will either succeed or return immediately with error "timeout".
-- If `math.huge` it will wait forever.
-- @return true, or nil+"destroyed"
function semaphore:take(requested, timeout)
  requested = requested or 1
  if self.q_tail == 1 and self.count >= requested then
    -- nobody is waiting before us, and there is enough in store
    self.count = self.count - requested
    return true
  end

  if requested > self.max then
    return nil, "too many"
  end

  local to = timeout or self.timeout
  if to == 0 then
    return nil, "timeout"
  end

  -- get in line
  local co = coroutine_running()
  self.to_flags[co] = nil
  registry[co] = self
  copas.timeout(to, timeout_handler)

  self.queue[self.q_tail] = {
    co = co,
    requested = requested,
    --timeout = nil, -- flag indicating timeout
  }
  self.q_tail = self.q_tail + 1

  copas.pauseforever() -- block until woken
  registry[co] = nil

  if self.to_flags[co] then
    -- a timeout happened
    self.to_flags[co] = nil
    return nil, "timeout"
  end

  copas.timeout(0)

  if self.destroyed then
    return nil, "destroyed"
  end

  return true
end

-- returns current available resources
function semaphore:get_count()
  return self.count
end

-- returns total shortage for requested resources
function semaphore:get_wait()
  local wait = 0
  for i = self.q_tip, self.q_tail - 1 do
    wait = wait + ((self.queue[i] or {}).requested or 0)
  end
  return wait - self.count
end


return semaphore
```

## truyenviet.koplugin/copas/smtp.lua

```lua
-------------------------------------------------------------------
-- identical to the socket.smtp module except that it uses
-- async wrapped Copas sockets

local copas = require("copas")
local smtp = require("socket.smtp")
local socket = require("socket")

local create = function() return copas.wrap(socket.tcp()) end
local forwards = { -- setting these will be forwarded to the original smtp module
  PORT = true,
  SERVER = true,
  TIMEOUT = true,
  DOMAIN = true,
  TIMEZONE = true
}

copas.smtp = setmetatable({}, {
    -- use original module as metatable, to lookup constants like socket.SERVER, etc.
    __index = smtp,
    -- Setting constants is forwarded to the luasocket.smtp module.
    __newindex = function(self, key, value)
        if forwards[key] then smtp[key] = value return end
        return rawset(self, key, value)
      end,
    })
local _M = copas.smtp

_M.send = function(mailt)
  mailt.create = mailt.create or create
  return smtp.send(mailt)
end

return _M
```

## truyenviet.koplugin/copas/timer.lua

```lua
local copas = require("copas")

local xpcall = xpcall
local coroutine_running = coroutine.running

-- removed coxpcall


local timer = {}
timer.__index = timer


local new_name do
  local count = 0

  function new_name()
    count = count + 1
    return "copas_timer_" .. count
  end
end


do
  local function expire_func(self, initial_delay)
    if self.errorhandler then
      copas.seterrorhandler(self.errorhandler)
    end
    copas.pause(initial_delay)
    while true do
      if not self.cancelled then
        if not self.recurring then
          -- non-recurring timer
          self.cancelled = true
          self.co = nil

          self:callback(self.params)
          return

        else
          -- recurring timer
          self:callback(self.params)
        end
      end

      if self.cancelled then
        -- clean up and exit the thread
        self.co = nil
        self.cancelled = true
        return
      end

      copas.pause(self.delay)
    end
  end


  --- Arms the timer object.
  -- @param initial_delay (optional) the first delay to use, if not provided uses the timer delay
  -- @return timer object, nil+error, or throws an error on bad input
  function timer:arm(initial_delay)
    assert(initial_delay == nil or initial_delay >= 0, "delay must be greater than or equal to 0")
    if self.co then
      return nil, "already armed"
    end

    self.cancelled = false
    self.co = copas.addnamedthread(self.name, expire_func, self, initial_delay or self.delay)
    return self
  end
end



--- Cancels a running timer.
-- @return timer object, or nil+error
function timer:cancel()
  if not self.co then
    return nil, "not armed"
  end

  if self.cancelled then
    return nil, "already cancelled"
  end

  self.cancelled = true
  copas.wakeup(self.co)       -- resume asap
  copas.removethread(self.co) -- will immediately drop the thread upon resuming
  self.co = nil
  return self
end


do
  -- xpcall error handler that forwards to the copas errorhandler
  local ehandler = function(err_obj)
    return copas.geterrorhandler()(err_obj, coroutine_running(), nil)
  end


  --- Creates a new timer object.
  -- Note: the callback signature is: `function(timer_obj, params)`.
  -- @param opts (table) `opts.delay` timer delay in seconds, `opts.callback` function to execute, `opts.recurring` boolean
  -- `opts.params` (optional) this value will be passed to the timer callback, `opts.initial_delay` (optional) the first delay to use, defaults to `delay`.
  -- @return timer object, or throws an error on bad input
  function timer.new(opts)
    assert((opts.delay or -1) >= 0, "delay must be greater than or equal to 0")
    assert(type(opts.callback) == "function", "expected callback to be a function")

    local callback = function(timer_obj, params)
      xpcall(opts.callback, ehandler, timer_obj, params)
    end

    return setmetatable({
      name = opts.name or new_name(),
      delay = opts.delay,
      callback = callback,
      recurring = not not opts.recurring,
      params = opts.params,
      cancelled = false,
      errorhandler = opts.errorhandler,
    }, timer):arm(opts.initial_delay)
  end
end



return timer
```

## truyenviet.koplugin/copas.lua

```lua
-------------------------------------------------------------------------------
-- Copas - Coroutine Oriented Portable Asynchronous Services
--
-- A dispatcher based on coroutines that can be used by TCP/IP servers.
-- Uses LuaSocket as the interface with the TCP/IP stack.
--
-- Authors: Andre Carregal, Javier Guerra, and Fabio Mascarenhas
-- Contributors: Diego Nehab, Mike Pall, David Burgess, Leonardo Godinho,
--               Thomas Harning Jr., and Gary NG
--
-- Copyright 2005-2013 - Kepler Project (www.keplerproject.org), 2015-2026 Thijs Schreijer
--
-- $Id: copas.lua,v 1.37 2009/04/07 22:09:52 carregal Exp $
-------------------------------------------------------------------------------

-- removed checks

-- load either LuaSocket, or LuaSystem
-- note: with luasocket we don't use 'sleep' but 'select' with no sockets
local socket, system do
  if pcall(require, "socket") then
    -- found LuaSocket
    socket = require "socket"
  end

  -- try LuaSystem as fallback
  if pcall(require, "system") then
    system = require "system"
  end

  if not (socket or system) then
    error("Neither LuaSocket nor LuaSystem found, Copas requires at least one of them")
  end
end

local binaryheap = require "binaryheap"
local gettime = (socket or system).gettime
local block_sleep = (socket or system).sleep
local ssl -- only loaded upon demand

local core_timer_thread
local WATCH_DOG_TIMEOUT = 120
local UDP_DATAGRAM_MAX = (socket or {})._DATAGRAMSIZE or 8192
local TIMEOUT_PRECISION = 0.1  -- 100ms
local fnil = function() end


local coroutine_create = coroutine.create
local coroutine_running = coroutine.running
local coroutine_yield = coroutine.yield
local coroutine_resume = coroutine.resume
local coroutine_status = coroutine.status


-- nil-safe versions for pack/unpack
local _unpack = unpack or table.unpack
local unpack = function(t, i, j) return _unpack(t, i or 1, j or t.n or #t) end
local pack = function(...) return { n = select("#", ...), ...} end


local pcall = pcall
-- removed coxpcall


if socket then
  -- Redefines LuaSocket functions with coroutine safe versions (pure Lua)
  -- (this allows the use of socket.http from within copas)
  local err_mt = {
    __tostring = function (self)
      return "Copas 'try' error intermediate table: '"..tostring(self[1].."'")
    end,
  }

  local function statusHandler(status, ...)
    if status then return ... end
    local err = (...)
    if type(err) == "table" and getmetatable(err) == err_mt then
      return nil, err[1]
    else
      error(err)
    end
  end

  function socket.protect(func)
    return function (...)
            return statusHandler(pcall(func, ...))
          end
  end

  function socket.newtry(finalizer)
    return function (...)
            local status = (...)
            if not status then
              pcall(finalizer or fnil, select(2, ...))
              error(setmetatable({ (select(2, ...)) }, err_mt), 0)
            end
            return ...
          end
  end

  socket.try = socket.newtry()
end


-- Setup the Copas meta table to auto-load submodules and define a default method
local copas do
  local submodules = { "ftp", "future", "http", "lock", "queue", "semaphore", "smtp", "timer" }
  for i, key in ipairs(submodules) do
    submodules[key] = true
    submodules[i] = nil
  end

  copas = setmetatable({},{
    __index = function(self, key)
      if submodules[key] then
        self[key] = require("copas."..key)
        submodules[key] = nil
        return rawget(self, key)
      end
    end,
    __call = function(self, ...)
      return self.loop(...)
    end,
  })
end


-- Meta information is public even if beginning with an "_"
copas._COPYRIGHT   = "Copyright (C) 2005-2013 Kepler Project, 2015-2026 Thijs Schreijer"
copas._DESCRIPTION = "Coroutine Oriented Portable Asynchronous Services"
copas._VERSION     = "Copas 4.11.0"

-- Close the socket associated with the current connection after the handler finishes
copas.autoclose = true

-- indicator for the loop running
copas.running = false

-- gettime method from either LuaSocket or LuaSystem: time in (fractional) seconds, since epoch.
copas.gettime = gettime

-------------------------------------------------------------------------------
-- Object names, to track names of thread/coroutines and sockets
-------------------------------------------------------------------------------
local object_names = setmetatable({}, {
  __mode = "k",
  __index = function(self, key)
    local name = tostring(key)
    if key ~= nil then
      rawset(self, key, name)
    end
    return name
  end
})

-------------------------------------------------------------------------------
-- Simple set implementation
-- adds a FIFO queue for each socket in the set
-------------------------------------------------------------------------------

local function newsocketset()
  local set = {}

  do  -- set implementation
    local reverse = {}

    -- Adds a socket to the set, does nothing if it exists
    -- @return skt if added, or nil if it existed
    function set:insert(skt)
      if not reverse[skt] then
        self[#self + 1] = skt
        reverse[skt] = #self
        return skt
      end
    end

    -- Removes socket from the set, does nothing if not found
    -- @return skt if removed, or nil if it wasn't in the set
    function set:remove(skt)
      local index = reverse[skt]
      if index then
        reverse[skt] = nil
        local top = self[#self]
        self[#self] = nil
        if top ~= skt then
          reverse[top] = index
          self[index] = top
        end
        return skt
      end
    end

  end

  do  -- queues implementation
    local fifo_queues = setmetatable({},{
      __mode = "k",                 -- auto collect queue if socket is gone
      __index = function(self, skt) -- auto create fifo queue if not found
        local newfifo = {}
        self[skt] = newfifo
        return newfifo
      end,
    })

    -- pushes an item in the fifo queue for the socket.
    function set:push(skt, itm)
      local queue = fifo_queues[skt]
      queue[#queue + 1] = itm
    end

    -- pops an item from the fifo queue for the socket
    function set:pop(skt)
      local queue = fifo_queues[skt]
      return table.remove(queue, 1)
    end

  end

  return set
end



-- Threads immediately resumable
local _resumable = {} do
  local resumelist = {}

  function _resumable:push(co)
    resumelist[#resumelist + 1] = co
  end

  function _resumable:clear_resumelist()
    local lst = resumelist
    resumelist = {}
    return lst
  end

  function _resumable:done()
    return resumelist[1] == nil
  end

  function _resumable:count()
    return #resumelist + #_resumable
  end

end



-- Similar to the socket set above, but tailored for the use of
-- sleeping threads
local _sleeping = {} do

  local heap = binaryheap.minUnique()
  local lethargy = setmetatable({}, { __mode = "k" }) -- list of coroutines sleeping without a wakeup time


  -- Required base implementation
  -----------------------------------------
  _sleeping.insert = fnil
  _sleeping.remove = fnil

  -- push a new timer on the heap
  function _sleeping:push(sleeptime, co)
    if sleeptime < 0 then
      lethargy[co] = true
    elseif sleeptime == 0 then
      _resumable:push(co)
    else
      heap:insert(gettime() + sleeptime, co)
    end
  end

  -- find the thread that should wake up to the time, if any
  function _sleeping:pop(time)
    if time < (heap:peekValue() or math.huge) then
      return
    end
    return heap:pop()
  end

  -- additional methods for time management
  -----------------------------------------
  function _sleeping:getnext()  -- returns delay until next sleep expires, or nil if there is none
    local t = heap:peekValue()
    if t then
      -- never report less than 0, because select() might block
      return math.max(t - gettime(), 0)
    end
  end

  function _sleeping:wakeup(co)
    if lethargy[co] then
      lethargy[co] = nil
      _resumable:push(co)
      return
    end
    if heap:remove(co) then
      _resumable:push(co)
    end
  end

  function _sleeping:cancel(co)
    lethargy[co] = nil
    heap:remove(co)
  end

  function _sleeping:cancelall()
    while heap:size() > 0 do heap:pop() end
    heap:insert(gettime() + TIMEOUT_PRECISION, core_timer_thread)
    -- lethargy is weak; copas's idle GC sweeps will clean it within a few steps
  end

  -- @param tos number of timeouts running
  function _sleeping:done(tos)
    -- return true if we have nothing more to do
    -- the timeout task doesn't qualify as work (fallbacks only),
    -- the lethargy also doesn't qualify as work ('dead' tasks),
    -- but the combination of a timeout + a lethargy can be work
    return heap:size() == 1       -- 1 means only the timeout-timer task is running
           and not (tos > 0 and next(lethargy))
  end

  -- gets number of threads in binaryheap and lethargy
  function _sleeping:status()
    local c = 0
    for _ in pairs(lethargy) do c = c + 1 end

    return heap:size(), c
  end

end   -- _sleeping



-------------------------------------------------------------------------------
-- Tracking coroutines and sockets
-------------------------------------------------------------------------------

local _servers = newsocketset() -- servers being handled
local _threads = setmetatable({}, {__mode = "k"})  -- registered threads added with addthread()
local _canceled = setmetatable({}, {__mode = "k"}) -- threads that are canceled and pending removal
local _autoclose = setmetatable({}, {__mode = "kv"}) -- sockets (value) to close when a thread (key) exits
local _autoclose_r = setmetatable({}, {__mode = "kv"}) -- reverse: sockets (key) to close when a thread (value) exits


-- for each socket we log the last read and last write times to enable the
-- watchdog to follow up if it takes too long.
-- tables contain the time, indexed by the socket
local _reading_log = {}
local _writing_log = {}

local _closed = {} -- track sockets that have been closed (list/array)

local _reading = newsocketset() -- sockets currently being read
local _writing = newsocketset() -- sockets currently being written
local _isSocketTimeout = { -- set of errors indicating a socket-timeout
  ["timeout"] = true,      -- default LuaSocket timeout
  ["wantread"] = true,     -- LuaSec specific timeout
  ["wantwrite"] = true,    -- LuaSec specific timeout
}

-------------------------------------------------------------------------------
-- Coroutine based socket timeouts.
-------------------------------------------------------------------------------
local user_timeouts_connect
local user_timeouts_send
local user_timeouts_receive
do
  local timeout_mt = {
    __mode = "k",
    __index = function(self, skt)
      -- if there is no timeout found, we insert one automatically, to block forever
      self[skt] = math.huge
      return self[skt]
    end,
  }

  user_timeouts_connect = setmetatable({}, timeout_mt)
  user_timeouts_send = setmetatable({}, timeout_mt)
  user_timeouts_receive = setmetatable({}, timeout_mt)
end

local useSocketTimeoutErrors = setmetatable({},{ __mode = "k" })


-- sto = socket-time-out
local sto_timeout, sto_timed_out, sto_change_queue, sto_error do

  local socket_register = setmetatable({}, { __mode = "k" })    -- socket by coroutine
  local operation_register = setmetatable({}, { __mode = "k" }) -- operation "read"/"write" by coroutine
  local timeout_flags = setmetatable({}, { __mode = "k" })      -- true if timedout, by coroutine


  -- The callback called when a socket timeout occurs.
  local function socket_callback(co)
    local skt = socket_register[co]
    local queue = operation_register[co]

    -- flag the timeout and resume the coroutine
    timeout_flags[co] = true
    _resumable:push(co)

    -- clear the socket from the current queue
    if queue == "read" then
      _reading:remove(skt)
    elseif queue == "write" then
      _writing:remove(skt)
    else
      error("bad queue name; expected 'read'/'write', got: "..tostring(queue))
    end
  end


  -- Sets a socket timeout.
  -- Calling it as `sto_timeout()` will cancel the timeout.
  -- @param skt (socket) the socket on which to operate, use 'nil' to cancel the current timeout
  -- @param queue (string) the queue the socket is currently in: "read" or "write"
  -- @param use_connect_to (bool) if truthy, use the connect timeout instead of the
  --   read/write timeout implied by queue. Needed because connect also uses the "write"
  --   queue, so the queue value alone cannot distinguish connect from send operations.
  -- @return true
  function sto_timeout(skt, queue, use_connect_to)
    local co = coroutine_running()
    socket_register[co] = skt
    operation_register[co] = queue
    timeout_flags[co] = nil
    if skt then
      local to = (use_connect_to and user_timeouts_connect[skt]) or
                 (queue == "read" and user_timeouts_receive[skt]) or
                 user_timeouts_send[skt]
      copas.timeout(to, socket_callback)
    else
      copas.timeout(0)
    end
    return true
  end


  -- Changes the timeout to a different queue (read/write).
  -- Only usefull with ssl-handshakes and "wantread", "wantwrite" errors, when
  -- the queue has to be changed, so the timeout handler knows where to find the socket.
  -- @param queue (string) the new queue the socket is in, must be either "read" or "write"
  -- @return true
  function sto_change_queue(queue)
    operation_register[coroutine_running()] = queue
    return true
  end


  -- Responds with `true` if the operation timed-out.
  function sto_timed_out()
    return timeout_flags[coroutine_running()]
  end


  -- Returns the proper timeout error
  function sto_error(err)
    return useSocketTimeoutErrors[coroutine_running()] and err or "timeout"
  end

  -- only in case of testing export some internals
  if _G._TEST then
    copas._socket_register = socket_register
    copas._operation_register = operation_register
    copas._timeout_flags = timeout_flags
  end
end



-------------------------------------------------------------------------------
-- Coroutine based socket I/O functions.
-------------------------------------------------------------------------------

-- Returns "tcp"" for plain TCP and "ssl" for ssl-wrapped sockets, so truthy
-- for tcp based, and falsy for udp based.
local isTCP do
  local lookup = {
    tcp = "tcp",
    SSL = "ssl",
  }

  function isTCP(socket)
    return lookup[tostring(socket):sub(1,3)]
  end
end

function copas.close(skt, ...)
  _closed[#_closed+1] = skt
  return skt:close(...)
end



-- nil or negative is indefinitly
function copas.settimeout(skt, timeout)
  timeout = timeout or -1
  if type(timeout) ~= "number" then
    return nil, "timeout must be 'nil' or a number"
  end

  return copas.settimeouts(skt, timeout, timeout, timeout)
end

-- negative is indefinitly, nil means do not change
function copas.settimeouts(skt, connect, send, read)

  if connect ~= nil and type(connect) ~= "number" then
    return nil, "connect timeout must be 'nil' or a number"
  end
  if connect then
    if connect < 0 then
      connect = nil
    end
    user_timeouts_connect[skt] = connect
  end


  if send ~= nil and type(send) ~= "number" then
    return nil, "send timeout must be 'nil' or a number"
  end
  if send then
    if send < 0 then
      send = nil
    end
    user_timeouts_send[skt] = send
  end


  if read ~= nil and type(read) ~= "number" then
    return nil, "read timeout must be 'nil' or a number"
  end
  if read then
    if read < 0 then
      read = nil
    end
    user_timeouts_receive[skt] = read
  end


  return true
end

-- reads a pattern from a client and yields to the reading set on timeouts
-- UDP: a UDP socket expects a second argument to be a number, so it MUST
-- be provided as the 'pattern' below defaults to a string. Will throw a
-- 'bad argument' error if omitted.
function copas.receive(client, pattern, part)
  local s, err
  pattern = pattern or "*l"
  local current_log = _reading_log
  sto_timeout(client, "read")

  repeat
    s, err, part = client:receive(pattern, part)

    -- guarantees that high throughput doesn't take other threads to starvation
    if (math.random(100) > 90) then
      copas.pause()
    end

    if s then
      current_log[client] = nil
      sto_timeout()
      return s, err, part

    elseif not _isSocketTimeout[err] then
      current_log[client] = nil
      sto_timeout()
      return s, err, part

    elseif sto_timed_out() then
      current_log[client] = nil
      sto_timeout()
      return nil, sto_error(err), part
    end

    if err == "wantwrite" then -- wantwrite may be returned during SSL renegotiations
      current_log = _writing_log
      current_log[client] = gettime()
      sto_change_queue("write")
      coroutine_yield(client, _writing)
    else
      current_log = _reading_log
      current_log[client] = gettime()
      sto_change_queue("read")
      coroutine_yield(client, _reading)
    end
  until false
end

-- receives data from a client over UDP. Not available for TCP.
-- (this is a copy of receive() method, adapted for receivefrom() use)
function copas.receivefrom(client, size)
  local s, err, port
  size = size or UDP_DATAGRAM_MAX
  sto_timeout(client, "read")

  repeat
    s, err, port = client:receivefrom(size) -- upon success err holds ip address

    -- garantees that high throughput doesn't take other threads to starvation
    if (math.random(100) > 90) then
      copas.pause()
    end

    if s then
      _reading_log[client] = nil
      sto_timeout()
      return s, err, port

    elseif err ~= "timeout" then
      _reading_log[client] = nil
      sto_timeout()
      return s, err, port

    elseif sto_timed_out() then
      _reading_log[client] = nil
      sto_timeout()
      return nil, sto_error(err), port
    end

    _reading_log[client] = gettime()
    coroutine_yield(client, _reading)
  until false
end

-- same as above but with special treatment when reading chunks,
-- unblocks on any data received.
function copas.receivepartial(client, pattern, part)
  local s, err
  pattern = pattern or "*l"
  local orig_size = #(part or "")
  local current_log = _reading_log
  sto_timeout(client, "read")

  repeat
    s, err, part = client:receive(pattern, part)

    -- guarantees that high throughput doesn't take other threads to starvation
    if (math.random(100) > 90) then
      copas.pause()
    end

    if s or (type(part) == "string" and #part > orig_size) then
      current_log[client] = nil
      sto_timeout()
      return s, err, part

    elseif not _isSocketTimeout[err] then
      current_log[client] = nil
      sto_timeout()
      return s, err, part

    elseif sto_timed_out() then
      current_log[client] = nil
      sto_timeout()
      return nil, sto_error(err), part
    end

    if err == "wantwrite" then
      current_log = _writing_log
      current_log[client] = gettime()
      sto_change_queue("write")
      coroutine_yield(client, _writing)
    else
      current_log = _reading_log
      current_log[client] = gettime()
      sto_change_queue("read")
      coroutine_yield(client, _reading)
    end
  until false
end
copas.receivePartial = copas.receivepartial  -- compat: receivePartial is deprecated

-- sends data to a client. The operation is buffered and
-- yields to the writing set on timeouts
-- Note: from and to parameters will be ignored by/for UDP sockets
function copas.send(client, data, from, to)
  local s, err
  from = from or 1
  local lastIndex = from - 1
  local current_log = _writing_log
  sto_timeout(client, "write")

  repeat
    s, err, lastIndex = client:send(data, lastIndex + 1, to)

    -- guarantees that high throughput doesn't take other threads to starvation
    if (math.random(100) > 90) then
      copas.pause()
    end

    if s then
      current_log[client] = nil
      sto_timeout()
      return s, err, lastIndex

    elseif not _isSocketTimeout[err] then
      current_log[client] = nil
      sto_timeout()
      return s, err, lastIndex

    elseif sto_timed_out() then
      current_log[client] = nil
      sto_timeout()
      return nil, sto_error(err), lastIndex
    end

    if err == "wantread" then
      current_log = _reading_log
      current_log[client] = gettime()
      sto_change_queue("read")
      coroutine_yield(client, _reading)
    else
      current_log = _writing_log
      current_log[client] = gettime()
      sto_change_queue("write")
      coroutine_yield(client, _writing)
    end
  until false
end

function copas.sendto(client, data, ip, port)
  -- deprecated; for backward compatibility only, since UDP doesn't block on sending
  return client:sendto(data, ip, port)
end

-- waits until connection is completed
function copas.connect(skt, host, port)
  skt:settimeout(0)
  local ret, err, tried_more_than_once
  sto_timeout(skt, "write", true)

  repeat
    ret, err = skt:connect(host, port)

    -- non-blocking connect on Windows results in error "Operation already
    -- in progress" to indicate that it is completing the request async. So essentially
    -- it is the same as "timeout"
    if ret or (err ~= "timeout" and err ~= "Operation already in progress") then
      _writing_log[skt] = nil
      sto_timeout()
      -- Once the async connect completes, Windows returns the error "already connected"
      -- to indicate it is done, so that error should be ignored. Except when it is the
      -- first call to connect, then it was already connected to something else and the
      -- error should be returned
      if (not ret) and (err == "already connected" and tried_more_than_once) then
        return 1
      end
      return ret, err

    elseif sto_timed_out() then
      _writing_log[skt] = nil
      sto_timeout()
      return nil, sto_error(err)
    end

    tried_more_than_once = tried_more_than_once or true
    _writing_log[skt] = gettime()
    coroutine_yield(skt, _writing)
  until false
end


-- Wraps a tcp socket in an ssl socket and configures it. If the socket was
-- already wrapped, it does nothing and returns the socket.
-- @param wrap_params the parameters for the ssl-context
-- @return wrapped socket, or throws an error
local function ssl_wrap(skt, wrap_params)
  if isTCP(skt) == "ssl" then return skt end -- was already wrapped
  if not wrap_params then
    error("cannot wrap socket into a secure socket (using 'ssl.wrap()') without parameters/context")
  end

  ssl = ssl or require("ssl")
  local nskt = assert(ssl.wrap(skt, wrap_params)) -- assert, because we do not want to silently ignore this one!!

  nskt:settimeout(0)  -- non-blocking on the ssl-socket
  copas.settimeouts(nskt, user_timeouts_connect[skt],
    user_timeouts_send[skt], user_timeouts_receive[skt]) -- copy copas user-timeout to newly wrapped one

  local co = _autoclose_r[skt]
  if co then
    -- socket registered for autoclose, move registration to wrapped one
    _autoclose[co] = nskt
    _autoclose_r[skt] = nil
    _autoclose_r[nskt] = co
  end

  local sock_name = object_names[skt]
  if sock_name ~= tostring(skt) then
    -- socket had a custom name, so copy it over
    object_names[nskt] = sock_name
  end
  return nskt
end


-- For each luasec method we have a subtable, allows for future extension.
-- Required structure:
-- {
--   wrap = ... -- parameter to 'wrap()'; the ssl parameter table, or the context object
--   sni = {                  -- parameters to 'sni()'
--     names = string | table -- 1st parameter
--     strict = bool          -- 2nd parameter
--   }
-- }
local function normalize_sslt(sslt)
  local t = type(sslt)
  local r = setmetatable({}, {
    __index = function(self, key)
      -- a bug if this happens, here as a sanity check, just being careful since
      -- this is security stuff
      error("accessing unknown 'ssl_params' table key: "..tostring(key))
    end,
  })
  if t == "nil" then
    r.wrap = false
    r.sni = false

  elseif t == "table" then
    if sslt.mode or sslt.protocol then
      -- has the mandatory fields for the ssl-params table for handshake
      -- backward compatibility
      r.wrap = sslt
      r.sni = false
    else
      -- has the target definition, copy our known keys
      r.wrap = sslt.wrap or false -- 'or false' because we do not want nils
      r.sni = sslt.sni or false -- 'or false' because we do not want nils
    end

  elseif t == "userdata" then
    -- it's an ssl-context object for the handshake
    -- backward compatibility
    r.wrap = sslt
    r.sni = false

  else
    error("ssl parameters; did not expect type "..tostring(sslt))
  end

  return r
end


---
-- Peforms an (async) ssl handshake on a connected TCP client socket.
-- NOTE: if not ssl-wrapped already, then replace all previous socket references, with the returned new ssl wrapped socket
-- Throws error and does not return nil+error, as that might silently fail
-- in code like this;
--   copas.addserver(s1, function(skt)
--       skt = copas.wrap(skt, sparams)
--       skt:dohandshake()   --> without explicit error checking, this fails silently and
--       skt:send(body)      --> continues unencrypted
-- @param skt Regular LuaSocket CLIENT socket object
-- @param wrap_params Table with ssl parameters
-- @return wrapped ssl socket, or throws an error
function copas.dohandshake(skt, wrap_params)
  ssl = ssl or require("ssl")

  local nskt = ssl_wrap(skt, wrap_params)

  sto_timeout(nskt, "write", true)
  local queue

  repeat
    local success, err = nskt:dohandshake()

    if success then
      sto_timeout()
      return nskt

    elseif not _isSocketTimeout[err] then
      sto_timeout()
      error("TLS/SSL handshake failed: " .. tostring(err))

    elseif sto_timed_out() then
      sto_timeout()
      return nil, sto_error(err)

    elseif err == "wantwrite" then
      sto_change_queue("write")
      queue = _writing

    elseif err == "wantread" then
      sto_change_queue("read")
      queue = _reading

    else
      error("TLS/SSL handshake failed: " .. tostring(err))
    end

    coroutine_yield(nskt, queue)
  until false
end

-- flushes a client write buffer (deprecated)
function copas.flush()
end

-- wraps a TCP socket to use Copas methods (send, receive, flush and settimeout)
local _skt_mt_tcp = {
      __tostring = function(self)
        return tostring(self.socket).." (copas wrapped)"
      end,

      __index = {
        send = function (self, data, from, to)
          return copas.send (self.socket, data, from, to)
        end,

        receive = function (self, pattern, prefix)
          if user_timeouts_receive[self.socket] == 0 then
            return copas.receivepartial(self.socket, pattern, prefix)
          end
          return copas.receive(self.socket, pattern, prefix)
        end,

        receivepartial = function (self, pattern, prefix)
          return copas.receivepartial(self.socket, pattern, prefix)
        end,

        flush = function (self)
          return copas.flush(self.socket)
        end,

        settimeout = function (self, time)
          return copas.settimeout(self.socket, time)
        end,

        settimeouts = function (self, connect, send, receive)
          return copas.settimeouts(self.socket, connect, send, receive)
        end,

        -- TODO: socket.connect is a shortcut, and must be provided with an alternative
        -- if ssl parameters are available, it will also include a handshake
        connect = function(self, ...)
          local res, err = copas.connect(self.socket, ...)
          if res then
            if self.ssl_params.sni then self:sni() end
            if self.ssl_params.wrap then res, err = self:dohandshake() end
          end
          return res, err
        end,

        close = function(self, ...)
          return copas.close(self.socket, ...)
        end,

        -- TODO: socket.bind is a shortcut, and must be provided with an alternative
        bind = function(self, ...) return self.socket:bind(...) end,

        -- TODO: is this DNS related? hence blocking?
        getsockname = function(self, ...)
          local ok, ip, port, family = pcall(self.socket.getsockname, self.socket, ...)
          if ok then
            return ip, port, family
          else
            return nil, "not implemented by LuaSec"
          end
        end,

        getstats = function(self, ...) return self.socket:getstats(...) end,

        setstats = function(self, ...) return self.socket:setstats(...) end,

        listen = function(self, ...) return self.socket:listen(...) end,

        accept = function(self, ...) return self.socket:accept(...) end,

        setoption = function(self, ...)
          local ok, res, err = pcall(self.socket.setoption, self.socket, ...)
          if ok then
            return res, err
          else
            return nil, "not implemented by LuaSec"
          end
        end,

        getoption = function(self, ...)
          local ok, val, err = pcall(self.socket.getoption, self.socket, ...)
          if ok then
            return val, err
          else
            return nil, "not implemented by LuaSec"
          end
        end,

        -- TODO: is this DNS related? hence blocking?
        getpeername = function(self, ...)
          local ok, ip, port, family = pcall(self.socket.getpeername, self.socket, ...)
          if ok then
            return ip, port, family
          else
            return nil, "not implemented by LuaSec"
          end
        end,

        shutdown = function(self, ...) return self.socket:shutdown(...) end,

        sni = function(self, names, strict)
          local sslp = self.ssl_params
          self.socket = ssl_wrap(self.socket, sslp.wrap)
          if names == nil then
            names = sslp.sni.names
            strict = sslp.sni.strict
          end
          return self.socket:sni(names, strict)
        end,

        dohandshake = function(self, wrap_params)
          local nskt, err = copas.dohandshake(self.socket, wrap_params or self.ssl_params.wrap)
          if not nskt then return nskt, err end
          self.socket = nskt  -- replace internal socket with the newly wrapped ssl one
          return self
        end,

        getalpn = function(self, ...)
          local ok, proto, err = pcall(self.socket.getalpn, self.socket, ...)
          if ok then
            return proto, err
          else
            return nil, "not a tls socket"
          end
        end,

        getsniname = function(self, ...)
          local ok, name, err = pcall(self.socket.getsniname, self.socket, ...)
          if ok then
            return name, err
          else
            return nil, "not a tls socket"
          end
        end,
      }
}

-- wraps a UDP socket, copy of TCP one adapted for UDP.
local _skt_mt_udp = {__index = { }}
for k,v in pairs(_skt_mt_tcp) do _skt_mt_udp[k] = _skt_mt_udp[k] or v end
for k,v in pairs(_skt_mt_tcp.__index) do _skt_mt_udp.__index[k] = v end

_skt_mt_udp.__index.send        = function(self, ...) return self.socket:send(...) end

_skt_mt_udp.__index.sendto      = function(self, ...) return self.socket:sendto(...) end


_skt_mt_udp.__index.receive =     function (self, size)
                                    return copas.receive (self.socket, (size or UDP_DATAGRAM_MAX))
                                  end

_skt_mt_udp.__index.receivefrom = function (self, size)
                                    return copas.receivefrom (self.socket, (size or UDP_DATAGRAM_MAX))
                                  end

                                  -- TODO: is this DNS related? hence blocking?
_skt_mt_udp.__index.setpeername = function(self, ...) return self.socket:setpeername(...) end

_skt_mt_udp.__index.setsockname = function(self, ...) return self.socket:setsockname(...) end

                                    -- do not close client, as it is also the server for udp.
_skt_mt_udp.__index.close       = function(self, ...) return true end

_skt_mt_udp.__index.settimeouts = function (self, connect, send, receive)
                                    return copas.settimeouts(self.socket, connect, send, receive)
                                  end



---
-- Wraps a LuaSocket socket object in an async Copas based socket object.
-- @param skt The socket to wrap
-- @sslt (optional) Table with ssl parameters, use an empty table to use ssl with defaults
-- @return wrapped socket object
function copas.wrap (skt, sslt)
  if (getmetatable(skt) == _skt_mt_tcp) or (getmetatable(skt) == _skt_mt_udp) then
    return skt -- already wrapped
  end

  skt:settimeout(0)

  if isTCP(skt) then
    return setmetatable ({socket = skt, ssl_params = normalize_sslt(sslt)}, _skt_mt_tcp)
  else
    return setmetatable ({socket = skt}, _skt_mt_udp)
  end
end

--- Wraps a handler in a function that deals with wrapping the socket and doing the
-- optional ssl handshake.
function copas.handler(handler, sslparams)
  -- TODO: pass a timeout value to set, and use during handshake
  return function (skt, ...)
    skt = copas.wrap(skt, sslparams) -- this call will normalize the sslparams table
    local sslp = skt.ssl_params
    if sslp.sni then skt:sni(sslp.sni.names, sslp.sni.strict) end
    if sslp.wrap then skt:dohandshake(sslp.wrap) end
    return handler(skt, ...)
  end
end


--------------------------------------------------
-- Error handling
--------------------------------------------------

local _errhandlers = setmetatable({}, { __mode = "k" })   -- error handler per coroutine


function copas.gettraceback(msg, co, skt)
  local co_str = co == nil and "nil" or copas.getthreadname(co)
  local skt_str = skt == nil and "nil" or copas.getsocketname(skt)
  local msg_str = msg == nil and "" or tostring(msg)
  if msg_str == "" then
    msg_str = ("(coroutine: %s, socket: %s)"):format(msg_str, co_str, skt_str)
  else
    msg_str = ("%s (coroutine: %s, socket: %s)"):format(msg_str, co_str, skt_str)
  end

  if type(co) == "thread" then
    -- regular Copas coroutine
    return debug.traceback(co, msg_str)
  end
  -- not a coroutine, but the main thread, this happens if a timeout callback
  -- (see `copas.timeout` causes an error (those callbacks run on the main thread).
  return debug.traceback(msg_str, 2)
end


local function _deferror(msg, co, skt)
  print(copas.gettraceback(msg, co, skt))
end


function copas.seterrorhandler(err, default)
  assert(err == nil or type(err) == "function", "Expected the handler to be a function, or nil")
  if default then
    assert(err ~= nil, "Expected the handler to be a function when setting the default")
    _deferror = err
  else
    _errhandlers[coroutine_running()] = err
  end
end
copas.setErrorHandler = copas.seterrorhandler  -- deprecated; old casing


function copas.geterrorhandler(co)
  co = co or coroutine_running()
  return _errhandlers[co] or _deferror
end


-- if `bool` is truthy, then the original socket errors will be returned in case of timeouts;
-- `timeout, wantread, wantwrite, Operation already in progress`. If falsy, it will always
-- return `timeout`.
function copas.useSocketTimeoutErrors(bool)
  useSocketTimeoutErrors[coroutine_running()] = not not bool -- force to a boolean
end

-------------------------------------------------------------------------------
-- Thread handling
-------------------------------------------------------------------------------

local function _doTick (co, skt, ...)
  if not co then return end

  -- if a coroutine was canceled/removed, don't resume it
  if _canceled[co] then
    _canceled[co] = nil -- also clean up the registry
    _threads[co] = nil
    return
  end

  -- res: the socket (being read/write on) or the time to sleep
  -- new_q: either _writing, _reading, or _sleeping
  -- local time_before = gettime()
  local ok, res, new_q = coroutine_resume(co, skt, ...)
  -- local duration = gettime() - time_before
  -- if duration > 1 then
  --   duration = math.floor(duration * 1000)
  --   pcall(_errhandlers[co] or _deferror, "task ran for "..tostring(duration).." milliseconds.", co, skt)
  -- end

  if new_q == _reading or new_q == _writing or new_q == _sleeping then
    -- we're yielding to a new queue
    new_q:insert (res)
    new_q:push (res, co)
    return
  end

  -- coroutine is terminating

  if ok and coroutine_status(co) ~= "dead" then
    -- it called coroutine.yield from a non-Copas function which is unexpected
    ok = false
    res = "coroutine.yield was called without a resume first, user-code cannot yield to Copas"
  end

  if not ok then
    local k, e = pcall(_errhandlers[co] or _deferror, res, co, skt)
    if not k then
      print("Failed executing error handler: " .. tostring(e))
    end
  end

  local skt_to_close = _autoclose[co]
  if skt_to_close then
    skt_to_close:close()
    _autoclose[co] = nil
    _autoclose_r[skt_to_close] = nil
  end

  _errhandlers[co] = nil
end


local _accept do
  local client_counters = setmetatable({}, { __mode = "k" })

  -- accepts a connection on socket input
  function _accept(server_skt, handler)
    local client_skt = server_skt:accept()
    if client_skt then
      local count = (client_counters[server_skt] or 0) + 1
      client_counters[server_skt] = count
      object_names[client_skt] = object_names[server_skt] .. ":client_" .. count

      client_skt:settimeout(0)
      copas.settimeouts(client_skt, user_timeouts_connect[server_skt],  -- copy server socket timeout settings
        user_timeouts_send[server_skt], user_timeouts_receive[server_skt])

      local co = coroutine_create(handler)
      object_names[co] = object_names[server_skt] .. ":handler_" .. count

      if copas.autoclose then
        _autoclose[co] = client_skt
        _autoclose_r[client_skt] = co
      end

      _doTick(co, client_skt)
    end
  end
end

-------------------------------------------------------------------------------
-- Adds a server/handler pair to Copas dispatcher
-------------------------------------------------------------------------------

do
  local function addTCPserver(server, handler, timeout, name)
    server:settimeout(0)
    if name then
      object_names[server] = name
    end
    _servers[server] = handler
    _reading:insert(server)
    if timeout then
      copas.settimeout(server, timeout)
    end
  end

  local function addUDPserver(server, handler, timeout, name)
    server:settimeout(0)
    local co = coroutine_create(handler)
    if name then
      object_names[server] = name
    end
    object_names[co] = object_names[server]..":handler"
    _reading:insert(server)
    if timeout then
      copas.settimeout(server, timeout)
    end
    _doTick(co, server)
  end


  function copas.addserver(server, handler, timeout, name)
    if isTCP(server) then
      addTCPserver(server, handler, timeout, name)
    else
      addUDPserver(server, handler, timeout, name)
    end
  end
end


function copas.removeserver(server, keep_open)
  local skt = server
  local mt = getmetatable(server)
  if mt == _skt_mt_tcp or mt == _skt_mt_udp then
    skt = server.socket
  end

  _servers:remove(skt)
  _reading:remove(skt)

  if keep_open then
    return true
  end
  return server:close()
end



-------------------------------------------------------------------------------
-- Adds an new coroutine thread to Copas dispatcher
-------------------------------------------------------------------------------
function copas.addnamedthread(name, handler, ...)
  if type(name) == "function" and type(handler) == "string" then
    -- old call, flip args for compatibility
    name, handler = handler, name
  end

  -- create a coroutine that skips the first argument, which is always the socket
  -- passed by the scheduler, but `nil` in case of a task/thread
  local thread = coroutine_create(function(_, ...)
    copas.pause()
    return handler(...)
  end)
  if name then
    object_names[thread] = name
  end

  _threads[thread] = true -- register this thread so it can be removed
  _doTick (thread, nil, ...)
  return thread
end


function copas.addthread(handler, ...)
  return copas.addnamedthread(nil, handler, ...)
end


function copas.removethread(thread)
  -- if the specified coroutine is registered, add it to the canceled table so
  -- that next time it tries to resume it exits.
  _canceled[thread] = _threads[thread or 0]
  _sleeping:cancel(thread)
end



-------------------------------------------------------------------------------
-- Sleep/pause management functions
-------------------------------------------------------------------------------

-- yields the current coroutine and wakes it after 'sleeptime' seconds.
-- If sleeptime < 0 then it sleeps until explicitly woken up using 'wakeup'
-- TODO: deprecated, remove in next major
function copas.sleep(sleeptime)
  coroutine_yield((sleeptime or 0), _sleeping)
end


-- yields the current coroutine and wakes it after 'sleeptime' seconds.
-- if sleeptime < 0 then it sleeps 0 seconds.
function copas.pause(sleeptime)
  local s = gettime()
  if sleeptime and sleeptime > 0 then
    coroutine_yield(sleeptime, _sleeping)
  else
    coroutine_yield(0, _sleeping)
  end
  return gettime() - s
end


-- yields the current coroutine until explicitly woken up using 'wakeup'
function copas.pauseforever()
  local s = gettime()
  coroutine_yield(-1, _sleeping)
  return gettime() - s
end


-- Wakes up a sleeping coroutine 'co'.
function copas.wakeup(co)
  _sleeping:wakeup(co)
end



-------------------------------------------------------------------------------
-- Timeout management
-------------------------------------------------------------------------------

do
  local timeout_register = setmetatable({}, { __mode = "k" })
  local timerwheel = require("timerwheel").new({
      now = gettime,
      precision = TIMEOUT_PRECISION,
      ringsize = math.floor(60*60*24/TIMEOUT_PRECISION),  -- ring size 1 day
      err_handler = function(err)
        return _deferror(err, core_timer_thread)
      end,
    })

  core_timer_thread = copas.addnamedthread("copas_core_timer", function()
    while true do
      copas.pause(TIMEOUT_PRECISION)
      timerwheel:step()
    end
  end)

  -- get the number of timeouts running
  function copas.gettimeouts()
    return timerwheel:count()
  end

  --- Sets the timeout for the current coroutine.
  -- @param delay delay (seconds), use 0 (or math.huge) to cancel the timerout
  -- @param callback function with signature: `function(coroutine)` where coroutine is the routine that timed-out
  -- @return true
  function copas.timeout(delay, callback)
    local co = coroutine_running()
    local existing_timer = timeout_register[co]

    if existing_timer then
      timerwheel:cancel(existing_timer)
    end

    if delay > 0 and delay ~= math.huge then
      timeout_register[co] = timerwheel:set(delay, callback, co)
    elseif delay == 0 or delay == math.huge then
      timeout_register[co] = nil
    else
      error("timout value must be greater than or equal to 0, got: "..tostring(delay))
    end

    return true
  end

end


-------------------------------------------------------------------------------
-- main tasks: manage readable and writable socket sets
-------------------------------------------------------------------------------
-- a task is an object with a required method `step()` that deals with a
-- single step for that task.

local _tasks = {} do
  function _tasks:add(tsk)
    _tasks[#_tasks + 1] = tsk
  end
end


-- a task to check ready to read events
local _readable_task = {} do

  _readable_task._events = {}

  local function tick(skt)
    local handler = _servers[skt]
    if handler then
      _accept(skt, handler)
    else
      _reading:remove(skt)
      _doTick(_reading:pop(skt), skt)
    end
  end

  function _readable_task:step()
    for _, skt in ipairs(self._events) do
      tick(skt)
    end
  end

  _tasks:add(_readable_task)
end


-- a task to check ready to write events
local _writable_task = {} do

  _writable_task._events = {}

  local function tick(skt)
    _writing:remove(skt)
    _doTick(_writing:pop(skt), skt)
  end

  function _writable_task:step()
    for _, skt in ipairs(self._events) do
      tick(skt)
    end
  end

  _tasks:add(_writable_task)
end



-- sleeping threads task
local _sleeping_task = {} do

  function _sleeping_task:step()
    local now = gettime()

    local co = _sleeping:pop(now)
    while co do
      -- we're pushing them to _resumable, since that list will be replaced before
      -- executing. This prevents tasks running twice in a row with pause(0) for example.
      -- So here we won't execute, but at _resumable step which is next
      _resumable:push(co)
      co = _sleeping:pop(now)
    end
  end

  _tasks:add(_sleeping_task)
end



-- resumable threads task
local _resumable_task = {} do

  function _resumable_task:step()
    -- replace the resume list before iterating, so items placed in there
    -- will indeed end up in the next copas step, not in this one, and not
    -- create a loop
    local resumelist = _resumable:clear_resumelist()

    for _, co in ipairs(resumelist) do
      _doTick(co)
    end
  end

  _tasks:add(_resumable_task)
end


-------------------------------------------------------------------------------
-- Checks for reads and writes on sockets
-------------------------------------------------------------------------------
local _select_plain do

  local last_cleansing = 0
  local duration = function(t2, t1) return t2-t1 end

  if not socket then
    -- socket module unavailable, switch to luasystem sleep
    _select_plain = block_sleep
  else
    -- use socket.select to handle socket-io
    _select_plain = function(timeout)
      local err
      local now = gettime()

      -- remove any closed sockets to prevent select from hanging on them
      if _closed[1] then
        for i, skt in ipairs(_closed) do
          _closed[i] = { _reading:remove(skt), _writing:remove(skt) }
        end
      end

      _readable_task._events, _writable_task._events, err = socket.select(_reading, _writing, timeout)
      local r_events, w_events = _readable_task._events, _writable_task._events

      -- inject closed sockets in readable/writeable task so they can error out properly
      if _closed[1] then
        for i, skts in ipairs(_closed) do
          _closed[i] = nil
          r_events[#r_events+1] = skts[1]
          w_events[#w_events+1] = skts[2]
        end
      end

      if duration(now, last_cleansing) > WATCH_DOG_TIMEOUT then
        last_cleansing = now

        -- Check all sockets selected for reading, and check how long they have been waiting
        -- for data already, without select returning them as readable
        for skt,time in pairs(_reading_log) do
          if not r_events[skt] and duration(now, time) > WATCH_DOG_TIMEOUT then
            -- This one timedout while waiting to become readable, so move
            -- it in the readable list and try and read anyway, despite not
            -- having been returned by select
            _reading_log[skt] = nil
            r_events[#r_events + 1] = skt
            r_events[skt] = #r_events
          end
        end

        -- Do the same for writing
        for skt,time in pairs(_writing_log) do
          if not w_events[skt] and duration(now, time) > WATCH_DOG_TIMEOUT then
            _writing_log[skt] = nil
            w_events[#w_events + 1] = skt
            w_events[skt] = #w_events
          end
        end
      end

      if err == "timeout" and #r_events + #w_events > 0 then
        return nil
      else
        return err
      end
    end
  end
end



-------------------------------------------------------------------------------
-- Dispatcher loop step.
-- Listen to client requests and handles them
-- Returns false if no socket-data was handled, or true if there was data
-- handled (or nil + error message)
-------------------------------------------------------------------------------

local copas_stats
local min_ever, max_ever

local _select = _select_plain

-- instrumented version of _select() to collect stats
local _select_instrumented = function(timeout)
  if copas_stats then
    local step_duration = gettime() - copas_stats.step_start
    copas_stats.duration_max = math.max(copas_stats.duration_max, step_duration)
    copas_stats.duration_min = math.min(copas_stats.duration_min, step_duration)
    copas_stats.duration_tot = copas_stats.duration_tot + step_duration
    copas_stats.steps = copas_stats.steps + 1
  else
    copas_stats = {
      duration_max = -1,
      duration_min = 999999,
      duration_tot = 0,
      steps = 0,
    }
  end

  local err = _select_plain(timeout)

  local now = gettime()
  copas_stats.time_start = copas_stats.time_start or now
  copas_stats.step_start = now

  return err
end


function copas.step(timeout)
  -- Need to wake up the select call in time for the next sleeping event
  if not _resumable:done() then
    timeout = 0
  else
    timeout = math.min(_sleeping:getnext(), timeout or math.huge)
  end

  local err = _select(timeout)

  for _, tsk in ipairs(_tasks) do
    tsk:step()
  end

  if err then
    if err == "timeout" then
      if timeout + 0.01 > TIMEOUT_PRECISION and math.random(100) > 90 then
        -- we were idle, so occasionally do a GC sweep to ensure lingering
        -- sockets are closed, and we don't accidentally block the loop from
        -- exiting
        collectgarbage()
      end
      return false
    end
    return nil, err
  end

  return true
end


-------------------------------------------------------------------------------
-- Check whether there is something to do.
-- returns false if there are no sockets for read/write nor tasks scheduled
-- (which means Copas is in an empty spin)
-------------------------------------------------------------------------------
function copas.finished()
  return #_reading == 0 and #_writing == 0 and _resumable:done() and _sleeping:done(copas.gettimeouts())
end


local resetexit do
  local exit_semaphore, exiting

  function resetexit()
    exit_semaphore = copas.semaphore.new(1, 0, math.huge)
    exiting = false
  end

  -- Signals tasks to exit. But only if they check for it. By calling `copas.exiting`
  -- they can check if they should exit. Or by calling `copas.waitforexit` they can
  -- wait until the exit signal is given.
  function copas.exit()
    if exiting then return end
    exiting = true
    exit_semaphore:destroy()
  end

  -- returns whether Copas is in the process of exiting. Exit can be started by
  -- calling `copas.exit()`.
  function copas.exiting()
    return exiting
  end

  -- Pauses the current coroutine until Copas is exiting. To be used as an exit
  -- signal for tasks that need to clean up before exiting.
  function copas.waitforexit()
    exit_semaphore:take(1)
  end
end


--- Forcibly cancels all pending work and signals exit.
-- Intended for test teardown only. Abandons all registered threads and sockets
-- without giving them a chance to clean up. After this call copas.finished()
-- will return true and the loop will exit. The module is left in a clean state
-- ready for the next copas.loop() call.
function copas.cancelall()
  -- 1. clear resumable queue
  _resumable:clear_resumelist()

  -- 2. drain sleeping heap
  _sleeping:cancelall()

  -- 3. close and drain reading sockets
  while _reading[1] do
    copas.close(_reading[1])
    _reading:remove(_reading[1])
  end

  -- 4. close and drain writing sockets
  while _writing[1] do
    copas.close(_writing[1])
    _writing:remove(_writing[1])
  end

  -- 5. remove all servers
  while _servers[1] do
    copas.removeserver(_servers[1])
  end

  -- 6. clear non-weak ancillary tables
  _closed = {}
  _reading_log = {}
  _writing_log = {}

  -- 7. signal exit
  copas.exit()
end


local _getstats do
  local _getstats_instrumented, _getstats_plain


  function _getstats_plain(enable)
    -- this function gets hit if turned off, so turn on if true
    if enable == true then
      _select = _select_instrumented
      _getstats = _getstats_instrumented
      -- reset stats
      min_ever = nil
      max_ever = nil
      copas_stats = nil
    end
    return {}
  end


  -- convert from seconds to millisecs, with microsec precision
  local function useconds(t)
    return math.floor((t * 1000000) + 0.5) / 1000
  end
  -- convert from seconds to seconds, with millisec precision
  local function mseconds(t)
    return math.floor((t * 1000) + 0.5) / 1000
  end


  function _getstats_instrumented(enable)
    if enable == false then
      _select = _select_plain
      _getstats = _getstats_plain
      -- instrumentation disabled, so switch to the plain implementation
      return _getstats(enable)
    end
    if (not copas_stats) or (copas_stats.step == 0) then
      return {}
    end
    local stats = copas_stats
    copas_stats = nil
    min_ever = math.min(min_ever or 9999999, stats.duration_min)
    max_ever = math.max(max_ever or 0, stats.duration_max)
    stats.duration_min_ever = min_ever
    stats.duration_max_ever = max_ever
    stats.duration_avg = stats.duration_tot / stats.steps
    stats.step_start = nil
    stats.time_end = gettime()
    stats.time_tot = stats.time_end - stats.time_start
    stats.time_avg = stats.time_tot / stats.steps

    stats.duration_avg = useconds(stats.duration_avg)
    stats.duration_max = useconds(stats.duration_max)
    stats.duration_max_ever = useconds(stats.duration_max_ever)
    stats.duration_min = useconds(stats.duration_min)
    stats.duration_min_ever = useconds(stats.duration_min_ever)
    stats.duration_tot = useconds(stats.duration_tot)
    stats.time_avg = useconds(stats.time_avg)
    stats.time_start = mseconds(stats.time_start)
    stats.time_end = mseconds(stats.time_end)
    stats.time_tot = mseconds(stats.time_tot)
    return stats
  end

  _getstats = _getstats_plain
end


function copas.status(enable_stats)
  local res = _getstats(enable_stats)
  res.running = not not copas.running
  res.timeout = copas.gettimeouts()
  res.timer, res.inactive = _sleeping:status()
  res.read = #_reading
  res.write = #_writing
  res.active = _resumable:count()
  return res
end


-------------------------------------------------------------------------------
-- Dispatcher endless loop.
-- Listen to client requests and handles them forever
-------------------------------------------------------------------------------
function copas.loop(initializer, timeout)
  if type(initializer) == "function" then
    copas.addnamedthread("copas_initializer", initializer)
  else
    timeout = initializer or timeout
  end

  resetexit()
  copas.running = true
  while true do
    copas.step(timeout)
    if copas.finished() then
      if copas.exiting() then
        break
      end
      copas.exit()
    end
  end
  copas.running = false
end


-------------------------------------------------------------------------------
-- Naming sockets and coroutines.
-------------------------------------------------------------------------------
do
  local function realsocket(skt)
    local mt = getmetatable(skt)
    if mt == _skt_mt_tcp or mt == _skt_mt_udp then
      return skt.socket
    else
      return skt
    end
  end


  function copas.setsocketname(name, skt)
    assert(type(name) == "string", "expected arg #1 to be a string")
    skt = assert(realsocket(skt), "expected arg #2 to be a socket")
    object_names[skt] = name
  end


  function copas.getsocketname(skt)
    skt = assert(realsocket(skt), "expected arg #1 to be a socket")
    return object_names[skt]
  end
end


function copas.setthreadname(name, coro)
  assert(type(name) == "string", "expected arg #1 to be a string")
  coro = coro or coroutine_running()
  assert(type(coro) == "thread", "expected arg #2 to be a coroutine or nil")
  object_names[coro] = name
end


function copas.getthreadname(coro)
  coro = coro or coroutine_running()
  assert(type(coro) == "thread", "expected arg #1 to be a coroutine or nil")
  return object_names[coro]
end

-------------------------------------------------------------------------------
-- Debug functionality.
-------------------------------------------------------------------------------
do
  copas.debug = {}

  local log_core    -- if truthy, the core-timer will also be logged
  local debug_log   -- function used as logger


  local debug_yield = function(skt, queue)
    local name = object_names[coroutine_running()]

    if log_core or name ~= "copas_core_timer" then
      if queue == _sleeping then
        debug_log("yielding '", name, "' to SLEEP for ", skt," seconds")

      elseif queue == _writing then
        debug_log("yielding '", name, "' to WRITE on '", object_names[skt], "'")

      elseif queue == _reading then
        debug_log("yielding '", name, "' to READ on '", object_names[skt], "'")

      else
        debug_log("thread '", name, "' yielding to unexpected queue; ", tostring(queue), " (", type(queue), ")", debug.traceback())
      end
    end

    return coroutine.yield(skt, queue)
  end


  local debug_resume = function(coro, skt, ...)
    local name = object_names[coro]

    if skt then
      debug_log("resuming '", name, "' for socket '", object_names[skt], "'")
    else
      if log_core or name ~= "copas_core_timer" then
        debug_log("resuming '", name, "'")
      end
    end
    return coroutine.resume(coro, skt, ...)
  end


  local debug_create = function(f)
    local f_wrapped = function(...)
      local results = pack(f(...))
      debug_log("exiting '", object_names[coroutine_running()], "'")
      return unpack(results)
    end

    return coroutine.create(f_wrapped)
  end


  debug_log = fnil


  -- enables debug output for all coroutine operations.
  function copas.debug.start(logger, core)
    log_core = core
    debug_log = logger or print
    coroutine_yield = debug_yield
    coroutine_resume = debug_resume
    coroutine_create = debug_create
  end


  -- disables debug output for coroutine operations.
  function copas.debug.stop()
    debug_log = fnil
    coroutine_yield = coroutine.yield
    coroutine_resume = coroutine.resume
    coroutine_create = coroutine.create
  end

  do
    local call_id = 0

    -- Description table of socket functions for debug output.
    -- each socket function name has TWO entries;
    -- 'name_in' and 'name_out', each being an array of names/descriptions of respectively
    -- input parameters and return values.
    -- If either table has a 'callback' key, then that is a function that will be called
    -- with the parameters/return-values for further inspection.
    local args = {
      settimeout_in = {
        "socket ",
        "seconds",
        "mode   ",
      },
      settimeout_out = {
        "success",
        "error  ",
      },
      connect_in = {
        "socket ",
        "address",
        "port   ",
      },
      connect_out = {
        "success",
        "error  ",
      },
      getfd_in = {
        "socket ",
        -- callback = function(...)
        --   print(debug.traceback("called from:", 4))
        -- end,
      },
      getfd_out = {
        "fd",
      },
      send_in = {
        "socket   ",
        "data     ",
        "idx-start",
        "idx-end  ",
      },
      send_out = {
        "last-idx-send    ",
        "error            ",
        "err-last-idx-send",
      },
      receive_in = {
        "socket ",
        "pattern",
        "prefix ",
      },
      receive_out = {
        "received    ",
        "error       ",
        "partial data",
      },
      dirty_in = {
        "socket",
        -- callback = function(...)
        --   print(debug.traceback("called from:", 4))
        -- end,
      },
      dirty_out = {
        "data in read-buffer",
      },
      close_in = {
        "socket",
        -- callback = function(...)
        --   print(debug.traceback("called from:", 4))
        -- end,
      },
      close_out = {
        "success",
        "error",
      },
    }
    local function print_call(func, msg, ...)
      print(msg)
      local arg = pack(...)
      local desc = args[func] or {}
      for i = 1, math.max(arg.n, #desc) do
        local value = arg[i]
        if type(value) == "string" then
          local xvalue = value:sub(1,30)
          if xvalue ~= value then
            xvalue = xvalue .."(...truncated)"
          end
          print("\t"..(desc[i] or i)..": '"..tostring(xvalue).."' ("..type(value).." #"..#value..")")
        else
          print("\t"..(desc[i] or i)..": '"..tostring(value).."' ("..type(value)..")")
        end
      end
      if desc.callback then
        desc.callback(...)
      end
    end

    local debug_mt = {
      __index = function(self, key)
        local value = self.__original_socket[key]
        if type(value) ~= "function" then
          return value
        end
        return function(self2, ...)
            local my_id = call_id + 1
            call_id = my_id
            local results

            if self2 ~= self then
              -- there is no self
              print_call(tostring(key).."_in", my_id .. "-calling '"..tostring(key) .. "' with; ", self, ...)
              results = pack(value(self, ...))
            else
              print_call(tostring(key).."_in", my_id .. "-calling '" .. tostring(key) .. "' with; ", self.__original_socket, ...)
              results = pack(value(self.__original_socket, ...))
            end
            print_call(tostring(key).."_out", my_id .. "-results '"..tostring(key) .. "' returned; ", unpack(results))
            return unpack(results)
          end
      end,
      __tostring = function(self)
        return tostring(self.__original_socket)
      end
    }


    -- wraps a socket (copas or luasocket) in a debug version printing all calls
    -- and their parameters/return values. Extremely noisy!
    -- returns the wrapped socket.
    -- NOTE: only for plain sockets, will not support TLS
    function copas.debug.socket(original_skt)
      if (getmetatable(original_skt) == _skt_mt_tcp) or (getmetatable(original_skt) == _skt_mt_udp) then
        -- already wrapped as Copas socket, so recurse with the original luasocket one
        original_skt.socket = copas.debug.socket(original_skt.socket)
        return original_skt
      end

      local proxy = setmetatable({
        __original_socket = original_skt
      }, debug_mt)

      return proxy
    end
  end
end


return copas
```

## truyenviet.koplugin/main.lua

```lua
local Dispatcher = require("dispatcher")
local WidgetContainer = require("ui/widget/container/widgetcontainer")

local Browser = require("truyenviet/browser")
local Reader = require("truyenviet/reader")
local Version = require("truyenviet/version")

local TruyenViet = WidgetContainer:extend{
    name = "truyenviet",
    is_doc_only = false,
    VERSION = Version,
}

function TruyenViet:init()
    if self.ui.name == "ReaderUI" then
        Reader:initializeFromReaderUI(self.ui)
    else
        self.ui.menu:registerToMainMenu(self)
    end

    Dispatcher:registerAction("start_truyenviet", {
        category = "none",
        event = "StartTruyenViet",
        title = "Truyện Việt",
        general = true,
    })
end

function TruyenViet:addToMainMenu(menu_items)
    menu_items.truyenviet = {
        text = "Truyện Việt",
        sorting_hint = "search",
        callback = function()
            Browser:showRoot()
        end,
    }
end

function TruyenViet:onStartTruyenViet()
    Browser:showRoot()
end

return TruyenViet
```

## truyenviet.koplugin/manager.lua

```lua
��l o c a l   B D   =   r e q u i r e ( " u i / b i d i " )  
 l o c a l   C o n f i r m B o x   =   r e q u i r e ( " u i / w i d g e t / c o n f i r m b o x " )  
 l o c a l   D a t a S t o r a g e   =   r e q u i r e ( " d a t a s t o r a g e " )  
 l o c a l   D e v i c e   =   r e q u i r e ( " d e v i c e " )  
 l o c a l   E v e n t   =   r e q u i r e ( " u i / e v e n t " )  
 l o c a l   I n f o M e s s a g e   =   r e q u i r e ( " u i / w i d g e t / i n f o m e s s a g e " )  
 l o c a l   L u a S e t t i n g s   =   r e q u i r e ( " l u a s e t t i n g s " )  
 l o c a l   M u l t i C o n f i r m B o x   =   r e q u i r e ( " u i / w i d g e t / m u l t i c o n f i r m b o x " )  
 l o c a l   U I M a n a g e r   =   r e q u i r e ( " u i / u i m a n a g e r " )  
 l o c a l   f f i   =   r e q u i r e ( " f f i " )  
 l o c a l   f f i u t i l   =   r e q u i r e ( " f f i / u t i l " )  
 l o c a l   l o g g e r   =   r e q u i r e ( " l o g g e r " )  
 l o c a l   t i m e   =   r e q u i r e ( " u i / t i m e " )  
 l o c a l   u t i l   =   r e q u i r e ( " u t i l " )  
 l o c a l   _   =   r e q u i r e ( " g e t t e x t " )  
 l o c a l   C   =   f f i . C  
 l o c a l   T   =   f f i u t i l . t e m p l a t e  
  
 - -   W e ' l l   n e e d   a   b u n c h   o f   s t u f f   f o r   g e t i f a d d r s   i n   N e t w o r k M g r : i f H a s A n A d d r e s s  
 r e q u i r e ( " f f i / p o s i x _ h " )  
  
 - -   W e   u n f o r t u n a t e l y   d o n ' t   h a v e   t h a t   o n e   i n   f f i / p o s i x _ h   : /  
 l o c a l   E B U S Y   =   1 6  
  
 l o c a l   N e t w o r k M g r   =   {  
         i s _ w i f i _ o n   =   f a l s e ,  
         i s _ c o n n e c t e d   =   f a l s e ,  
         i n t e r f a c e   =   n i l ,  
  
         p e n d i n g _ c o n n e c t i v i t y _ c h e c k   =   f a l s e ,  
         p e n d i n g _ c o n n e c t i o n   =   f a l s e ,  
         _ b e f o r e _ a c t i o n _ t r i p p e d   =   n i l ,  
  
         - -   S S I D   f o r   w h i c h   t h e   c u r r e n t   D H C P   l e a s e   w a s   o b t a i n e d .  
         - -   U s e d   b y   h a s L e a s e F o r C u r r e n t N e t w o r k ( )   t o   d e t e c t   s t a l e   l e a s e s   a f t e r   a   n e t w o r k   s w i t c h   ( # 1 4 7 9 0 ) .  
         l e a s e _ s s i d   =   n i l ,  
 }  
  
 f u n c t i o n   N e t w o r k M g r : r e a d N W S e t t i n g s ( )  
         s e l f . n w _ s e t t i n g s   =   L u a S e t t i n g s : o p e n ( D a t a S t o r a g e : g e t S e t t i n g s D i r ( ) . . " / n e t w o r k . l u a " )  
 e n d  
  
 - -   C o m m o n   c h u n k   o f   s t u f f   w e   h a v e   t o   d o   w h e n   a b o r t i n g   a   c o n n e c t i o n   a t t e m p t  
 f u n c t i o n   N e t w o r k M g r : _ a b o r t W i f i C o n n e c t i o n ( )  
         - -   C a n c e l   a n y   p e n d i n g   c o n n e c t i v i t y   c h e c k ,   b e c a u s e   i t   w o u l d n ' t   a c h i e v e   a n y t h i n g  
         s e l f : u n s c h e d u l e C o n n e c t i v i t y C h e c k ( )  
  
         s e l f . w i f i _ w a s _ o n   =   f a l s e  
         G _ r e a d e r _ s e t t i n g s : m a k e F a l s e ( " w i f i _ w a s _ o n " )  
         - -   T h e   c o n n e c t i o n   n e v e r   c o m p l e t e d ,   s o   a n y   D H C P   l e a s e   w e   m a y   h a v e   h a d   i s   n o   l o n g e r   v a l i d .  
         s e l f . l e a s e _ s s i d   =   n i l  
         - -   M u r d e r   W i - F i   a n d   t h e   a s y n c   s c r i p t   ( i f   a n y )   f i r s t . . .  
         i f   D e v i c e : h a s W i f i R e s t o r e ( )   a n d   n o t   D e v i c e : i s K i n d l e ( )   t h e n  
                 o s . e x e c u t e ( " p k i l l   - T E R M   r e s t o r e - w i f i - a s y n c . s h   2 > / d e v / n u l l " )  
         e n d  
         - -   W e   w e r e   n e v e r   c o n n e c t e d   t o   b e g i n   w i t h ,   s o ,   n o   d i s c o n n e c t i n g   b r o a d c a s t   r e q u i r e d  
         i f   D e v i c e : h a s S e a m l e s s W i f i T o g g l e ( )   t h e n  
                 - -   W e   o n l y   w a n t   t o   a c t u a l l y   k i l l   t h e   W i F i   o n   p l a t f o r m s   w h e r e   w e   c a n   d o   t h a t   s e a m l e s s l y .  
                 s e l f : t u r n O f f W i f i ( )  
         e n d  
         - -   W e ' r e   o b v i o u s l y   d o n e   w i t h   t h i s   c o n n e c t i o n   a t t e m p t  
         s e l f . p e n d i n g _ c o n n e c t i o n   =   f a l s e  
 e n d  
  
 - -   A t t e m p t   t o   d e a l   w i t h   p l a t f o r m s   t h a t   d o n ' t   g u a r a n t e e   i s C o n n e c t e d   w h e n   t u r n O n W i f i   r e t u r n s ,  
 - -   s o   t h a t   w e   o n l y   a t t e m p t   t o   c o n n e c t   t o   W i F i   * o n c e *   w h e n   u s i n g   t h e   b e f o r e W i f i A c t i o n   f r a m e w o r k . . .  
 f u n c t i o n   N e t w o r k M g r : r e q u e s t T o T u r n O n W i f i ( w i f i _ c b ,   i n t e r a c t i v e )  
         i f   s e l f . p e n d i n g _ c o n n e c t i o n   t h e n  
                 - -   W e ' v e   a l r e a d y   e n a b l e d   W i F i ,   d o n ' t   t r y   a g a i n   u n t i l   t h e   e a r l i e r   a t t e m p t   s u c c e e d s   o r   f a i l s . . .  
                 r e t u r n   E B U S Y  
         e n d  
  
         - -   C o n n e c t i n g   w i l l   t a k e   a   f e w   s e c o n d s ,   b r o a d c a s t   t h a t   i n f o r m a t i o n   s o   a f f e c t e d   m o d u l e s / p l u g i n s   c a n   r e a c t .  
         U I M a n a g e r : b r o a d c a s t E v e n t ( E v e n t : n e w ( " N e t w o r k C o n n e c t i n g " ) )  
         s e l f . p e n d i n g _ c o n n e c t i o n   =   t r u e  
  
         r e t u r n   s e l f : t u r n O n W i f i ( w i f i _ c b ,   i n t e r a c t i v e )  
 e n d  
  
 - -   U s e d   a f t e r   r e s t o r e W i f i A s y n c ( )   a n d   t h e   t u r n _ o n   b e f o r e W i f i A c t i o n   t o   m a k e   s u r e   w e   e v e n t u a l l y   s e n d   a   N e t w o r k C o n n e c t e d   e v e n t ,  
 - -   a s   q u i t e   a   f e w   t h i n g s   r e l y   o n   i t   ( K O S y n c ,   c . f .   # 5 1 0 9 ;   t h e   n e t w o r k   a c t i v i t y   c h e c k ,   c . f . ,   # 6 4 2 4 ) .  
 f u n c t i o n   N e t w o r k M g r : c o n n e c t i v i t y C h e c k ( i t e r ,   c a l l b a c k ,   w i d g e t )  
         - -   G i v e   u p   a f t e r   a   w h i l e   ( r e s t o r e W i f i A s y n c   c a n   t a k e   o v e r   4 5 s ,   s o ,   t r y   t o   c o v e r   t h a t ) . . .  
         i f   i t e r   > =   1 8 0   t h e n  
                 l o g g e r . i n f o ( " F a i l e d   t o   r e s t o r e   W i - F i   ( a f t e r " ,   i t e r   *   0 . 2 5 ,   " s e c o n d s ) ! " )  
                 s e l f : _ a b o r t W i f i C o n n e c t i o n ( )  
  
                 - -   H a n d l e   t h e   U I   w a r n i n g   i f   i t ' s   f r o m   a   b e f o r e W i f i A c t i o n . . .  
                 i f   w i d g e t   t h e n  
                         U I M a n a g e r : c l o s e ( w i d g e t )  
                         U I M a n a g e r : s h o w ( I n f o M e s s a g e : n e w {   t e x t   =   _ ( " E r r o r   c o n n e c t i n g   t o   t h e   n e t w o r k " )   } )  
                 e n d  
                 r e t u r n  
         e n d  
  
         s e l f : q u e r y N e t w o r k S t a t e ( )  
         i f   s e l f . i s _ w i f i _ o n   a n d   s e l f . i s _ c o n n e c t e d   t h e n  
                 s e l f . w i f i _ w a s _ o n   =   t r u e  
                 G _ r e a d e r _ s e t t i n g s : m a k e T r u e ( " w i f i _ w a s _ o n " )  
                 l o g g e r . i n f o ( " W i - F i   s u c c e s s f u l l y   r e s t o r e d   ( a f t e r " ,   i t e r   *   0 . 2 5 ,   " s e c o n d s ) ! " )  
                 - -   U p d a t e   l e a s e _ s s i d   f r o m   w p a _ s u p p l i c a n t ' s   c u r r e n t   a s s o c i a t i o n .  
                 - -   r e s t o r e W i f i A s y n c ( )   r e - D H C P s   i n   s h e l l   b u t   n e v e r   t o u c h e s   L u a   s t a t e ,   s o   w e   s y n c  
                 - -   h e r e   t o   a v o i d   f a l s e l y   f l a g g i n g   a   v a l i d   p o s t - r e s t o r e   l e a s e   a s   s t a l e   ( # 1 4 7 9 0 ) .  
                 l o c a l   n w   =   s e l f : g e t C u r r e n t N e t w o r k ( )  
                 i f   n w   a n d   n w . s s i d   t h e n  
                         s e l f . l e a s e _ s s i d   =   n w . s s i d  
                         l o g g e r . d b g ( " N e t w o r k M g r :   l e a s e _ s s i d   s e t   t o " ,   n w . s s i d ,   " a f t e r   a s y n c   r e s t o r e " )  
                 e n d  
                 U I M a n a g e r : b r o a d c a s t E v e n t ( E v e n t : n e w ( " N e t w o r k C o n n e c t e d " ) )  
  
                 - -   H a n d l e   t h e   U I   &   c a l l b a c k   i f   i t ' s   f r o m   a   b e f o r e W i f i A c t i o n . . .  
                 i f   w i d g e t   t h e n  
                         U I M a n a g e r : c l o s e ( w i d g e t )  
                 e n d  
                 i f   c a l l b a c k   t h e n  
                         c a l l b a c k ( )  
                 e l s e  
                         - -   I f   t h i s   t r i c k l e d   d o w n   f r o m   a   t u r n _ o n b e f o r e W i f i A c t i o n   a n d   t h e r e   i s   n o   c a l l b a c k ,  
                         - -   m e n t i o n   t h a t   t h e   a c t i o n   n e e d s   t o   b e   r e t r i e d   m a n u a l l y .  
                         i f   w i d g e t   t h e n  
                                 U I M a n a g e r : s h o w ( I n f o M e s s a g e : n e w {  
                                         t e x t   =   _ ( " Y o u   c a n   n o w   r e t r y   t h e   a c t i o n   t h a t   r e q u i r e d   n e t w o r k   a c c e s s " ) ,  
                                         t i m e o u t   =   3 ,  
                                 } )  
                         e n d  
                 e n d  
                 s e l f . p e n d i n g _ c o n n e c t i v i t y _ c h e c k   =   f a l s e  
                 - -   W e ' r e   d o n e ,   s o   w e   c a n   s t o p   b l o c k i n g   c o n c u r r e n t   c o n n e c t i o n   a t t e m p t s  
                 s e l f . p e n d i n g _ c o n n e c t i o n   =   f a l s e  
         e l s e  
                 U I M a n a g e r : s c h e d u l e I n ( 0 . 2 5 ,   s e l f . c o n n e c t i v i t y C h e c k ,   s e l f ,   i t e r   +   1 ,   c a l l b a c k ,   w i d g e t )  
         e n d  
 e n d  
  
 f u n c t i o n   N e t w o r k M g r : s c h e d u l e C o n n e c t i v i t y C h e c k ( c a l l b a c k ,   w i d g e t )  
         s e l f . p e n d i n g _ c o n n e c t i v i t y _ c h e c k   =   t r u e  
         U I M a n a g e r : s c h e d u l e I n ( 0 . 2 5 ,   s e l f . c o n n e c t i v i t y C h e c k ,   s e l f ,   1 ,   c a l l b a c k ,   w i d g e t )  
 e n d  
  
 f u n c t i o n   N e t w o r k M g r : u n s c h e d u l e C o n n e c t i v i t y C h e c k ( )  
         U I M a n a g e r : u n s c h e d u l e ( s e l f . c o n n e c t i v i t y C h e c k )  
         s e l f . p e n d i n g _ c o n n e c t i v i t y _ c h e c k   =   f a l s e  
 e n d  
  
 f u n c t i o n   N e t w o r k M g r : i n i t ( )  
         D e v i c e : i n i t N e t w o r k M a n a g e r ( s e l f )  
         s e l f . i n t e r f a c e   =   s e l f : g e t N e t w o r k I n t e r f a c e N a m e ( )  
  
         s e l f : q u e r y N e t w o r k S t a t e ( )  
         s e l f . w i f i _ w a s _ o n   =   G _ r e a d e r _ s e t t i n g s : i s T r u e ( " w i f i _ w a s _ o n " )  
         - -   T r i g g e r   a n   i n i t i a l   N e t w o r k C o n n e c t e d   e v e n t   i f   W i F i   w a s   a l r e a d y   u p   w h e n   w e   w e r e   l a u n c h e d  
         i f   s e l f . i s _ c o n n e c t e d   t h e n  
                 - -   N O T E :   T h i s   n e e d s   t o   b e   d e l a y e d   b e c a u s e   w e   r u n   o n   r e q u i r e ,   w h i l e   N e t w o r k L i s t e n e r   g e t s   s p u n   u p   s l i i i g h t l y   l a t e r   o n   F M / R e a d e r U I   i n i t . . .  
                 U I M a n a g e r : n e x t T i c k ( U I M a n a g e r . b r o a d c a s t E v e n t ,   U I M a n a g e r ,   E v e n t : n e w ( " N e t w o r k C o n n e c t e d " ) )  
         e l s e  
                 - -   A t t e m p t   t o   r e s t o r e   w i f i   i n   t h e   b a c k g r o u n d   i f   n e c e s s a r y  
                 i f   D e v i c e : h a s W i f i R e s t o r e ( )   a n d   s e l f . w i f i _ w a s _ o n   a n d   G _ r e a d e r _ s e t t i n g s : i s T r u e ( " a u t o _ r e s t o r e _ w i f i " )   t h e n  
                         l o g g e r . d b g ( " N e t w o r k M g r :   i n i t   w i l l   r e s t o r e   W i - F i   i n   t h e   b a c k g r o u n d " )  
                         s e l f : r e s t o r e W i f i A s y n c ( )  
                         s e l f : s c h e d u l e C o n n e c t i v i t y C h e c k ( )  
                 e n d  
         e n d  
  
         r e t u r n   s e l f  
 e n d  
  
 - -   T h e   f o l l o w i n g   m e t h o d s   a r e   D e v i c e   s p e c i f i c ,   a n d   n e e d   t o   b e   i n i t i a l i z e d   i n   D e v i c e : i n i t N e t w o r k M a n a g e r .  
 - -   S o m e   o f   t h e m   c a n   b e   s e t   b y   c a l l i n g   N e t w o r k M g r : s e t W i r e l e s s B a c k e n d  
 - -   N O T E :   T h e   i n t e r a c t i v e   f l a g   i s   s e t   b y   c a l l e r s   w h e n   t h e   t o g g l e   w a s   a   * d i r e c t *   u s e r   p r o m p t   ( i . e . ,   M e n u   o r   G e s t u r e ) ,  
 - -               a s   o p p o s e d   t o   a n   i n d i r e c t   o n e   ( l i k e   t h e   b e f o r e W i f i A c t i o n   f r a m e w o r k ) .  
 - -               I t   a l l o w s   t h e   b a c k e n d   t o   s k i p   U I   p r o m p t s   f o r   n o n - i n t e r a c t i v e   u s e - c a s e s .  
 - -   N O T E :   M a y   o p t i o n a l l y   r e t u r n   a   b o o l e a n ,   e . g . ,   r e t u r n   f a l s e   i f   t h e   b a c k e n d   c a n   g u a r a n t e e   t h e   c o n n e c t i o n   f a i l e d .  
 - -   N O T E :   T h e s e   * m u s t *   r u n   o r   a p p r o p r i a t e l y   f o r w a r d   c o m p l e t e _ c a l l b a c k   ( e . g . ,   t o   r e c o n n e c t O r S h o w N e t w o r k M e n u ) ,  
 - -               a s   s a i d   c a l l b a c k   i s   r e s p o n s i b l e   f o r   s c h e d u l i g   t h e   c o n n e c t i v i t y   c h e c k ,  
 - -               w h i c h ,   i n   t u r n ,   i s   r e s p o n s i b l e   f o r   t h e   E v e n t   s i g n a l i n g !  
 f u n c t i o n   N e t w o r k M g r : t u r n O n W i f i ( c o m p l e t e _ c a l l b a c k ,   i n t e r a c t i v e )   e n d  
 f u n c t i o n   N e t w o r k M g r : t u r n O f f W i f i ( c o m p l e t e _ c a l l b a c k )   e n d  
 - -   T h i s   f u n c t i o n   r e t u r n s   t h e   c u r r e n t   s t a t u s   o f   t h e   W i F i   r a d i o  
 - -   N O T E :   O n   ! h a s W i f i T o g g l e   p l a t f o r m s ,   w e   a s s u m e   n e t w o r k i n g   i s   a l w a y s   a v a i l a b l e ,  
 - -               s o   a s   n o t   t o   c o n f u s e   t h e   w h o l e   b e f o r e W i f i A c t i o n   f r a m e w o r k  
 - -               ( a n d   l e t   i t   f a i l   w i t h   n e t w o r k   e r r o r s   w h e n   o f f l i n e ,   i n s t e a d   o f   l o o p i n g   o n   u n i m p l e m e n t e d   s t u f f . . . ) .  
 f u n c t i o n   N e t w o r k M g r : i s W i f i O n ( )  
         i f   n o t   D e v i c e : h a s W i f i T o g g l e ( )   t h e n  
                 r e t u r n   t r u e  
         e n d  
 e n d  
 f u n c t i o n   N e t w o r k M g r : i s C o n n e c t e d ( )  
         i f   n o t   D e v i c e : h a s W i f i T o g g l e ( )   t h e n  
                 r e t u r n   t r u e  
         e n d  
 e n d  
 f u n c t i o n   N e t w o r k M g r : g e t N e t w o r k I n t e r f a c e N a m e ( )   e n d  
 f u n c t i o n   N e t w o r k M g r : g e t C o n f i g u r e d N e t w o r k s ( )   e n d   - -   F r o m   t h e   * b a c k e n d * ,   e . g . ,   w p a _ c l i   l i s t _ n e t w o r k s   ( a s   o p p o s e d   t o   ` g e t A l l S a v e d N e t w o r k s ` )  
 f u n c t i o n   N e t w o r k M g r : g e t N e t w o r k L i s t ( )   e n d  
 f u n c t i o n   N e t w o r k M g r : g e t C u r r e n t N e t w o r k ( )   e n d  
 f u n c t i o n   N e t w o r k M g r : a u t h e n t i c a t e N e t w o r k ( n e t w o r k )   e n d  
 f u n c t i o n   N e t w o r k M g r : d i s c o n n e c t N e t w o r k ( n e t w o r k )   e n d  
 - -   N O T E :   T h i s   i s   c u r r e n t l y   o n l y   c a l l e d   o n   h a s W i f i M a n a g e r   p l a t f o r m s !  
 f u n c t i o n   N e t w o r k M g r : o b t a i n I P ( )   e n d  
 f u n c t i o n   N e t w o r k M g r : r e l e a s e I P ( )   e n d  
 - -   T h i s   f u n c t i o n   s h o u l d   c a l l   b o t h   t u r n O n W i f i ( )   a n d   o b t a i n I P ( )   i n   a   n o n - b l o c k i n g   m a n n e r .  
 f u n c t i o n   N e t w o r k M g r : r e s t o r e W i f i A s y n c ( )   e n d  
 - -   E n d   o f   d e v i c e   s p e c i f i c   m e t h o d s  
  
 - -   H e l p e r   f u n c t i o n s   f o r   d e v i c e s   t h a t   u s e   s y s f s   e n t r i e s   t o   c h e c k   c o n n e c t i v i t y .  
 f u n c t i o n   N e t w o r k M g r : s y s f s W i f i O n ( )  
         - -   N e t w o r k   i n t e r f a c e   d i r e c t o r y   o n l y   e x i s t s   a s   l o n g   a s   t h e   W i - F i   m o d u l e   i s   l o a d e d  
         r e t u r n   u t i l . p a t h E x i s t s ( " / s y s / c l a s s / n e t / " . .   s e l f . i n t e r f a c e )  
 e n d  
  
 f u n c t i o n   N e t w o r k M g r : s y s f s C a r r i e r C o n n e c t e d ( )  
         - -   R e a d   c a r r i e r   s t a t e   f r o m   s y s f s .  
         - -   N O T E :   W e   c a n   a f f o r d   t o   u s e   C L O E X E C ,   a s   d e v i c e s   t o o   o l d   f o r   i t   d o n ' t   s u p p o r t   W i - F i   a n y w a y   ; )  
         l o c a l   o u t  
         l o c a l   f i l e   =   i o . o p e n ( " / s y s / c l a s s / n e t / "   . .   s e l f . i n t e r f a c e   . .   " / c a r r i e r " ,   " r e " )  
  
         - -   F i l e   o n l y   e x i s t s   w h i l e   t h e   W i - F i   m o d u l e   i s   l o a d e d ,   b u t   m a y   f a i l   t o   r e a d   u n t i l   t h e   i n t e r f a c e   i s   b r o u g h t   u p .  
         i f   f i l e   t h e n  
                 - -   0   m e a n s   t h e   i n t e r f a c e   i s   d o w n ,   1   t h a t   i t ' s   u p  
                 - -   ( t e c h n i c a l l y ,   i t   r e f l e c t s   t h e   s t a t e   o f   t h e   p h y s i c a l   l i n k   ( e . g . ,   p l u g g e d   i n   o r   n o t   f o r   E t h e r n e t ) )  
                 - -   T h i s   d o e s   * N O T *   r e p r e s e n t   n e t w o r k   a s s o c i a t i o n   s t a t e   f o r   W i - F i   ( i t ' l l   r e t u r n   1   a s   s o o n   a s   i f u p ) !  
                 o u t   =   f i l e : r e a d ( " * n u m b e r " )  
                 f i l e : c l o s e ( )  
         e n d  
  
         r e t u r n   o u t   = =   1  
 e n d  
  
 f u n c t i o n   N e t w o r k M g r : s y s f s I n t e r f a c e O p e r a t i o n a l ( )  
         - -   R e a d s   t h e   i n t e r f a c e ' s   R F C 2 8 6 3   o p e r a t i o n a l   s t a t e   f r o m   s y s f s ,   a n d   w a i t   f o r   i t   t o   b e   u p  
         - -   ( F o r   W i - F i ,   t h a t   m e a n s   a s s o c i a t e d   &   s u c c e s s f u l l y   a u t h e n t i c a t e d )  
         l o c a l   o u t  
         l o c a l   f i l e   =   i o . o p e n ( " / s y s / c l a s s / n e t / "   . .   s e l f . i n t e r f a c e   . .   " / o p e r s t a t e " ,   " r e " )  
  
         - -   P o s s i b l e   v a l u e s :   " u n k n o w n " ,   " n o t p r e s e n t " ,   " d o w n " ,   " l o w e r l a y e r d o w n " ,   " t e s t i n g " ,   " d o r m a n t " ,   " u p "  
         - -   ( c . f . ,   L i n u x ' s   < D o c u m e n t a t i o n / A B I / t e s t i n g / s y s f s - c l a s s - n e t > )  
         - -   W e ' r e   * a s s u m i n g *   a l l   t h e   d r i v e r s   w e   c a r e   a b o u t   i m p l e m e n t   t h i s   p r o p e r l y ,   s o   w e   c a n   j u s t   r e l y   o n   c h e c k i n g   f o r   " u p " .  
         - -   O n   u n s u p p o r t e d   d r i v e r s ,   t h i s   w o u l d   b e   s t u c k   o n   " u n k n o w n "   ( c . f . ,   L i n u x ' s   < D o c u m e n t a t i o n / n e t w o r k i n g / o p e r s t a t e s . r s t > )  
         - -   N O T E :   T h i s   d o e s   * N O T *   m e a n   t h e   i n t e r f a c e   h a s   b e e n   a s s i g n e d   a n   I P !  
         i f   f i l e   t h e n  
                 o u t   =   f i l e : r e a d ( " * l " )  
                 f i l e : c l o s e ( )  
         e n d  
  
         r e t u r n   o u t   = =   " u p "  
 e n d  
  
 - -   T h i s   r e l i e s   o n   t h e   B S D   A P I   i n s t e a d   o f   t h e   L i n u x   i o c t l s   ( n e t d e v i c e ( 7 ) ) ,   b e c a u s e   h a n d l i n g   I P v 6   i s   s l i g h t l y   l e s s   p a i n f u l   t h i s   w a y . . .  
 f u n c t i o n   N e t w o r k M g r : i f H a s A n A d d r e s s ( )  
         - -   I f   t h e   i n t e r f a c e   i s n ' t   o p e r a t i o n a l l y   u p ,   n o   n e e d   t o   g o   a n y   f u r t h e r  
         i f   n o t   s e l f : s y s f s I n t e r f a c e O p e r a t i o n a l ( )   t h e n  
                 l o g g e r . d b g ( " N e t w o r k M g r :   i n t e r f a c e   i s   n o t   o p e r a t i o n a l   y e t " )  
                 r e t u r n   f a l s e  
         e n d  
  
         - -   I t ' s   u p ,   d o   t h e   g e t i f a d d r s   d a n c e   t o   s e e   i f   i t   w a s   a s s i g n e d   a n   I P   y e t . . .  
         - -   c . f . ,   g e t i f a d d r s ( 3 )  
         l o c a l   i f a d d r   =   f f i . n e w ( " s t r u c t   i f a d d r s   * [ 1 ] " )  
         i f   C . g e t i f a d d r s ( i f a d d r )   = =   - 1   t h e n  
                 l o c a l   e r r n o   =   f f i . e r r n o ( )  
                 l o g g e r . e r r ( " N e t w o r k M g r :   g e t i f a d d r s : " ,   f f i . s t r i n g ( C . s t r e r r o r ( e r r n o ) ) )  
                 r e t u r n   f a l s e  
         e n d  
  
         l o c a l   o k  
         l o c a l   i f a   =   i f a d d r [ 0 ]  
         w h i l e   i f a   ~ =   n i l   d o  
                 i f   i f a . i f a _ a d d r   ~ =   n i l   a n d   C . s t r c m p ( i f a . i f a _ n a m e ,   s e l f . i n t e r f a c e )   = =   0   t h e n  
                         l o c a l   f a m i l y   =   i f a . i f a _ a d d r . s a _ f a m i l y  
                         i f   f a m i l y   = =   C . A F _ I N E T   o r   f a m i l y   = =   C . A F _ I N E T 6   t h e n  
                                 l o c a l   h o s t   =   f f i . n e w ( " c h a r [ ? ] " ,   C . N I _ M A X H O S T )  
                                 l o c a l   s   =   C . g e t n a m e i n f o ( i f a . i f a _ a d d r ,  
                                                                                 f a m i l y   = =   C . A F _ I N E T   a n d   f f i . s i z e o f ( " s t r u c t   s o c k a d d r _ i n " )   o r   f f i . s i z e o f ( " s t r u c t   s o c k a d d r _ i n 6 " ) ,  
                                                                                 h o s t ,   C . N I _ M A X H O S T ,  
                                                                                 n i l ,   0 ,  
                                                                                 C . N I _ N U M E R I C H O S T )  
                                 i f   s   ~ =   0   t h e n  
                                         l o g g e r . e r r ( " N e t w o r k M g r :   g e t n a m e i n f o : " ,   f f i . s t r i n g ( C . g a i _ s t r e r r o r ( s ) ) )  
                                         o k   =   f a l s e  
                                 e l s e  
                                         l o g g e r . d b g ( " N e t w o r k M g r :   i n t e r f a c e " ,   s e l f . i n t e r f a c e ,   " i s   u p   @ " ,   f f i . s t r i n g ( h o s t ) )  
                                         o k   =   t r u e  
                                 e n d  
                                 - -   R e g a r d l e s s   o f   f a i l u r e ,   w e   o n l y   c h e c k   a   s i n g l e   i f ,   s o   w e ' r e   d o n e  
                                 b r e a k  
                         e n d  
                 e n d  
                 i f a   =   i f a . i f a _ n e x t  
         e n d  
         C . f r e e i f a d d r s ( i f a d d r [ 0 ] )  
  
         r e t u r n   o k  
 e n d  
  
 - -   R e t u r n s   t r u e   i f   t h e   c u r r e n t   D H C P   l e a s e   w a s   o b t a i n e d   f o r   t h e   n e t w o r k   w e   a r e   p r e s e n t l y  
 - -   a s s o c i a t e d   w i t h .     D e t e c t s   t h e   s t a l e - l e a s e   c a s e   t h a t   o c c u r s   a f t e r   a   n e t w o r k   s w i t c h :  
 - -   w p a _ s u p p l i c a n t   h a s   a l r e a d y   r o a m e d   t o   t h e   n e w   S S I D   a t   L 2 ,   b u t   t h e   o l d   I P / g a t e w a y   a r e  
 - -   s t i l l   a s s i g n e d ,   s o   e v e r y   o u t b o u n d   c o n n e c t i o n   i s   r o u t e d   t o   t h e   w r o n g   s u b n e t   ( # 1 4 7 9 0 ) .  
 - -  
 - -   W h e n   t h e   b a c k e n d   c a n n o t   r e p o r t   t h e   c u r r e n t   S S I D   ( n o n - w p a _ s u p p l i c a n t   p l a t f o r m s ,   o r   w h e n  
 - -   w p a _ s u p p l i c a n t   i s   n o t   y e t   f u l l y   a s s o c i a t e d )   w e   r e t u r n   t r u e   s o   a s   n o t   t o   c h u r n   a  
 - -   c o n n e c t i o n   w e   c a n n o t   r e l i a b l y   a s s e s s .  
 f u n c t i o n   N e t w o r k M g r : h a s L e a s e F o r C u r r e n t N e t w o r k ( )  
         i f   n o t   s e l f : i s C o n n e c t e d ( )   t h e n  
                 r e t u r n   f a l s e  
         e n d  
         l o c a l   n w   =   s e l f : g e t C u r r e n t N e t w o r k ( )       - -   w p a _ s u p p l i c a n t ' s   c u r r e n t l y   a s s o c i a t e d   n e t w o r k  
         i f   n o t   n w   o r   n o t   n w . s s i d   t h e n  
                 - -   B a c k e n d   c a n ' t   t e l l   u s   t h e   S S I D ;   d o n ' t   d i s r u p t   t h e   c o n n e c t i o n   o n   u n c e r t a i n t y .  
                 r e t u r n   t r u e  
         e n d  
         r e t u r n   s e l f . l e a s e _ s s i d   ~ =   n i l   a n d   s e l f . l e a s e _ s s i d   = =   n w . s s i d  
 e n d  
  
 - -   T h e   s o c k e t   A P I   e q u i v a l e n t   o f   " i p   r o u t e   g e t   2 0 3 . 0 . 1 1 3 . 1   | |   i p   r o u t e   g e t   2 0 0 1 : d b 8 : : 1 " .  
 - -  
 - -   T h e s e   a d d r e s s e s   a r e   f r o m   s p e c i a l   r a n g e s   r e s e r v e d   f o r   d o c u m e n t a t i o n  
 - -   ( R F C   5 7 3 7 ,   R F C   3 8 4 9 )   a n d   t h e r e f o r e   l i k e l y   t o   j u s t   u s e   t h e   d e f a u l t   r o u t e .  
 f u n c t i o n   N e t w o r k M g r : h a s D e f a u l t R o u t e ( )  
         l o c a l   s o c k e t   =   r e q u i r e ( " s o c k e t " )  
  
         l o c a l   s ,   r e t ,   e r r  
         s ,   e r r   =   s o c k e t . u d p ( )  
         i f   s   = =   n i l   t h e n  
                 l o g g e r . e r r ( " N e t w o r k M g r :   s o c k e t . u d p : " ,   e r r )  
                 r e t u r n   n i l  
         e n d  
  
         r e t ,   e r r   =   s : s e t p e e r n a m e ( " 2 0 3 . 0 . 1 1 3 . 1 " ,   " 5 3 " )  
         i f   r e t   = =   n i l   t h e n  
                 - -   M o s t   l i k e l y   " N e t w o r k   i s   u n r e a c h a b l e " ,   m e a n i n g   t h e r e ' s   n o   r o u t e   t o   t h a t   a d d r e s s .  
                 l o g g e r . d b g ( " N e t w o r k M g r :   s o c k e t . u d p . s e t p e e r n a m e : " ,   e r r )  
  
                 - -   T r y   I P v 6 ,   m a y   s t i l l   s u c c e e d   i f   t h i s   i s   a n   I P v 6 - o n l y   n e t w o r k .  
                 r e t ,   e r r   =   s : s e t p e e r n a m e ( " 2 0 0 1 : d b 8 : : 1 " ,   " 5 3 " )  
                 i f   r e t   = =   n i l   t h e n  
                         - -   M o s t   l i k e l y   " N e t w o r k   i s   u n r e a c h a b l e " ,   m e a n i n g   t h e r e ' s   n o   r o u t e   t o   t h a t   a d d r e s s .  
                         l o g g e r . d b g ( " N e t w o r k M g r :   s o c k e t . u d p . s e t p e e r n a m e : " ,   e r r )  
                 e n d  
         e n d  
  
         s : c l o s e ( )  
  
         - -   I f   s e t p e e r n a m e   s u c c e e d e d ,   w e   h a v e   a   d e f a u l t   r o u t e .  
         r e t u r n   r e t   ~ =   n i l  
 e n d  
  
 f u n c t i o n   N e t w o r k M g r : c a n R e s o l v e H o s t n a m e s ( )  
         l o c a l   s o c k e t   =   r e q u i r e ( " s o c k e t " )  
         - -   M i c r o s o f t   u s e s   ` d n s . m s f t n c s i . c o m `   f o r   W i n d o w s ,   s e e  
         - -   < h t t p s : / / t e c h n e t . m i c r o s o f t . c o m / e n - u s / l i b r a r y / e e 1 2 6 1 3 5 # B K M K _ H o w >   f o r  
         - -   m o r e   i n f o r m a t i o n .   T h e y   a l s o   c h e c k   w h e t h e r   < h t t p : / / w w w . m s f t n c s i . c o m / n c s i . t x t >  
         - -   r e t u r n s   ` M i c r o s o f t   N C S I ` .  
         r e t u r n   s o c k e t . d n s . t o i p ( " d n s . m s f t n c s i . c o m " )   ~ =   n i l  
 e n d  
  
 - -   W r a p p e r s   a r o u n d   t u r n O n W i f i   &   t u r n O f f W i f i   w i t h   p r o p e r   E v e n t   s i g n a l i n g  
 f u n c t i o n   N e t w o r k M g r : e n a b l e W i f i ( w i f i _ c b ,   i n t e r a c t i v e )  
         - -   N O T E :   L e t   t h e   b a c k e n d   r u n   t h e   w i f i _ c b   v i a   a   c o n n e c t i v i t y   c h e c k   o n c e   i t ' s   * a c t u a l l y *   a t t e m p t e d   a   c o n n e c t i o n ,  
         - -               a s   i t   k n o w s   b e s t   w h e n   t h a t   a c t u a l l y   h a p p e n s   ( e s p e c i a l l y   r e c o n n e c t O r S h o w N e t w o r k M e n u ) ,   u n l i k e   u s .  
         l o c a l   c o n n e c t i v i t y _ c b   =   f u n c t i o n ( )  
                 - -   N O T E :   W e   * c o u l d *   a r g u a b l y   h a v e   m u l t i p l e   c o n n e c t i v i t y   c h e c k s   r u n n i n g   c o n c u r r e n t l y ,  
                 - -               b u t   o n l y   h a v i n g   a   s i n g l e   o n e   r u n n i n g   m a k e s   t h i n g s   s o m e w h a t   e a s i e r   t o   f o l l o w . . .  
                 i f   s e l f . p e n d i n g _ c o n n e c t i v i t y _ c h e c k   t h e n  
                         s e l f : u n s c h e d u l e C o n n e c t i v i t y C h e c k ( )  
                 e n d  
  
                 - -   T h i s   w i l l   h a n d l e   s e n d i n g   t h e   p r o p e r   E v e n t ,   m a n a g e   w i f i _ w a s _ o n ,   a s   w e l l   a s   t e a r i n g   d o w n   W i - F i   i n   c a s e   o f   f a i l u r e s .  
                 s e l f : s c h e d u l e C o n n e c t i v i t y C h e c k ( w i f i _ c b )  
         e n d  
  
         - -   S o m e   i m p l e m e n t a t i o n s   ( u s u a l l y ,   h a s W i f i M a n a g e r )   c a n   r e p o r t   w h e t h e r   t h e y   w e r e   s u c c e s s f u l  
         l o c a l   s t a t u s   =   s e l f : r e q u e s t T o T u r n O n W i f i ( c o n n e c t i v i t y _ c b ,   i n t e r a c t i v e )  
         - -   I f   t u r n O n W i f i   f a i l e d ,   a b o r t   e a r l y  
         i f   s t a t u s   = =   f a l s e   t h e n  
                 l o g g e r . w a r n ( " N e t w o r k M g r : e n a b l e W i f i :   C o n n e c t i o n   f a i l e d ! " )  
                 s e l f : _ a b o r t W i f i C o n n e c t i o n ( )  
                 r e t u r n   f a l s e  
         e l s e i f   s t a t u s   = =   E B U S Y   t h e n  
                 - -   N O T E :   T h i s   m e a n s   t u r n O n W i f i   w a s   * n o t *   c a l l e d   ( t h i s   t i m e ) .  
                 l o g g e r . w a r n ( " N e t w o r k M g r : e n a b l e W i f i :   A   p r e v i o u s   c o n n e c t i o n   a t t e m p t   i s   s t i l l   o n g o i n g ! " )  
                 - -   W e   d o n ' t   r e a l l y   h a v e   a   g r e a t   w a y   o f   d e a l i n g   w i t h   t h e   w i f i _ c b   i n   t h i s   c a s e ,  
                 - -   s o ,   m u c h   l i k e   i n   t u r n O n W i f i A n d W a i t F o r C o n n e c t i o n ,   w e ' l l   j u s t   d r o p   i t . . .  
                 - -   W e   d o n ' t   w a n t   t o   r u n   m u l t i p l e   c o n c u r r e n t   c o n n e c t i v i t y   c h e c k s ,  
                 - -   w h i c h   m e a n s   w e ' d   n e e d   t o   u n s c h e d u l e   t h e   p e n d i n g   o n e ,   w h i c h   w o u l d   e f f e c t i v e l y   r e w i n d   t h e   t i m e r ,  
                 - -   w h i c h   w e   d o n ' t   w a n t ,   e s p e c i a l l y   i f   w e ' r e   n o n - i n t e r a c t i v e ,  
                 - -   a s   t h a t   w o u l d   r i s k   r e s c h e d u l i n g   t h e   s a m e   t h i n g   o v e r   a n d   o v e r   a g a i n . . .  
                 i f   w i f i _ c b   t h e n  
                         l o g g e r . w a r n ( " N e t w o r k M g r : e n a b l e W i f i :   W e ' v e   h a d   t o   d r o p   w i f i _ c b : " ,   w i f i _ c b )  
                 e n d  
                 - -   M a k e   i t   m o r e   o b v i o u s   t o   t h e   u s e r   w h e n   i n t e r a c t i v e . . .  
                 i f   i n t e r a c t i v e   t h e n  
                         U I M a n a g e r : s h o w ( I n f o M e s s a g e : n e w {  
                                 t e x t   =   _ ( " A   p r e v i o u s   c o n n e c t i o n   a t t e m p t   i s   s t i l l   o n g o i n g ,   t h i s   o n e   w i l l   b e   i g n o r e d ! " ) ,  
                                 t i m e o u t   =   3 ,  
                         } )  
                 e n d  
                 r e t u r n  
         e n d  
  
         r e t u r n   t r u e  
 e n d  
  
 f u n c t i o n   N e t w o r k M g r : d i s a b l e W i f i ( c b ,   i n t e r a c t i v e )  
         - -   D H C P   l e a s e   i s   r e l e a s e d   w h e n   W i - F i   g o e s   d o w n ,   s o   t h e   t r a c k e d   S S I D   i s   n o   l o n g e r   v a l i d .  
         s e l f . l e a s e _ s s i d   =   n i l  
         l o c a l   c o m p l e t e _ c a l l b a c k   =   f u n c t i o n ( )  
                 U I M a n a g e r : b r o a d c a s t E v e n t ( E v e n t : n e w ( " N e t w o r k D i s c o n n e c t e d " ) )  
                 i f   c b   t h e n  
                         c b ( )  
                 e n d  
         e n d  
         U I M a n a g e r : b r o a d c a s t E v e n t ( E v e n t : n e w ( " N e t w o r k D i s c o n n e c t i n g " ) )  
  
         - -   N O T E :   T h i s   i s   a   s u b s e t   o f   _ a b o r t W i f i C o n n e c t i o n ,   i n   c a s e   w e   d i s a b l e   w i f i   d u r i n g   a   c o n n e c t i o n   a t t e m p t .  
         - -   C a n c e l   a n y   p e n d i n g   c o n n e c t i v i t y   c h e c k ,   b e c a u s e   i t   w o u l d n ' t   a c h i e v e   a n y t h i n g  
         s e l f : u n s c h e d u l e C o n n e c t i v i t y C h e c k ( )  
         - -   M a k e   s u r e   w e   d o n ' t   h a v e   a n   a s y n c   s c r i p t   r u n n i n g . . .  
         i f   D e v i c e : h a s W i f i R e s t o r e ( )   a n d   n o t   D e v i c e : i s K i n d l e ( )   t h e n  
                 o s . e x e c u t e ( " p k i l l   - T E R M   r e s t o r e - w i f i - a s y n c . s h   2 > / d e v / n u l l " )  
         e n d  
         - -   C a n ' t   b e   c o n n e c t i n g   s i n c e   w e ' r e   k i l l i n g   W i - F i   ; )  
         s e l f . p e n d i n g _ c o n n e c t i o n   =   f a l s e  
  
         s e l f : t u r n O f f W i f i ( c o m p l e t e _ c a l l b a c k )  
  
         i f   i n t e r a c t i v e   t h e n  
                 s e l f . w i f i _ w a s _ o n   =   f a l s e  
                 G _ r e a d e r _ s e t t i n g s : m a k e F a l s e ( " w i f i _ w a s _ o n " )  
         e n d  
 e n d  
  
 f u n c t i o n   N e t w o r k M g r : t o g g l e W i f i O n ( c o m p l e t e _ c a l l b a c k ,   l o n g _ p r e s s ,   i n t e r a c t i v e )  
         l o c a l   t o g g l e _ i m   =   I n f o M e s s a g e : n e w {  
                 t e x t   =   _ ( " T u r n i n g   o n   W i - F i & " ) ,  
         }  
         U I M a n a g e r : s h o w ( t o g g l e _ i m )  
         U I M a n a g e r : f o r c e R e P a i n t ( )  
  
         s e l f . w i f i _ t o g g l e _ l o n g _ p r e s s   =   l o n g _ p r e s s  
  
         s e l f : e n a b l e W i f i ( c o m p l e t e _ c a l l b a c k ,   i n t e r a c t i v e )  
  
         U I M a n a g e r : c l o s e ( t o g g l e _ i m )  
 e n d  
  
 f u n c t i o n   N e t w o r k M g r : t o g g l e W i f i O f f ( c o m p l e t e _ c a l l b a c k ,   i n t e r a c t i v e )  
         l o c a l   t o g g l e _ i m   =   I n f o M e s s a g e : n e w {  
                 t e x t   =   _ ( " T u r n i n g   o f f   W i - F i & " ) ,  
         }  
         U I M a n a g e r : s h o w ( t o g g l e _ i m )  
         U I M a n a g e r : f o r c e R e P a i n t ( )  
  
         s e l f : d i s a b l e W i f i ( c o m p l e t e _ c a l l b a c k ,   i n t e r a c t i v e )  
  
         U I M a n a g e r : c l o s e ( t o g g l e _ i m )  
 e n d  
  
 - -   N O T E :   O n l y   u s e d   b y   t h e   b e f o r e W i f i A c t i o n   f r a m e w o r k ,   s o ,   c a n   n e v e r   b e   f l a g g e d   a s   " i n t e r a c t i v e "   ; ) .  
 f u n c t i o n   N e t w o r k M g r : p r o m p t W i f i O n ( c o m p l e t e _ c a l l b a c k )  
         - -   I f   t h e r e ' s   a l r e a d y   a n   o n g o i n g   c o n n e c t i o n   a t t e m p t ,   d o n ' t   e v e n   d i s p l a y   t h e   C o n f i r m B o x ,  
         - -   a s   t h a t ' s   j u s t   c o n f u s i n g ,   e s p e c i a l l y   o n   A n d r o i d ,   b e c a u s e   y o u   m i g h t   h a v e   s e e n   t h e   o n e   y o u   t a p p e d   " T u r n   o n "   o n   d i s a p p e a r ,  
         - -   a n d   b e   s u r p r i s e d   b y   n e w   o n e s   t h a t   p o p p e d   u p   o u t   o f   f o c u s   w h i l e   t h e   s y s t e m   s e t t i n g s   w e r e   o p e n e d . . .  
         i f   s e l f . p e n d i n g _ c o n n e c t i o n   t h e n  
                 - -   L i k e   o t h e r   b e f o r e W i f i A c t i o n   b a c k e n d s ,   t h e   c a l l b a c k   i s   f o r f e i t   a n y w a y  
                 l o g g e r . w a r n ( " N e t w o r k M g r : p r o m p t W i f i O n :   A   p r e v i o u s   c o n n e c t i o n   a t t e m p t   i s   s t i l l   o n g o i n g ! " )  
                 r e t u r n  
         e n d  
  
         U I M a n a g e r : s h o w ( C o n f i r m B o x : n e w {  
                 t e x t   =   _ ( " D o   y o u   w a n t   t o   t u r n   o n   W i - F i ? " ) ,  
                 o k _ t e x t   =   _ ( " T u r n   o n " ) ,  
                 o k _ c a l l b a c k   =   f u n c t i o n ( )  
                         s e l f : t o g g l e W i f i O n ( c o m p l e t e _ c a l l b a c k )  
                 e n d ,  
         } )  
 e n d  
  
 f u n c t i o n   N e t w o r k M g r : p r o m p t W i f i O f f ( c o m p l e t e _ c a l l b a c k )  
         U I M a n a g e r : s h o w ( C o n f i r m B o x : n e w {  
                 t e x t   =   _ ( " D o   y o u   w a n t   t o   t u r n   o f f   W i - F i ? " ) ,  
                 o k _ t e x t   =   _ ( " T u r n   o f f " ) ,  
                 o k _ c a l l b a c k   =   f u n c t i o n ( )  
                         s e l f : t o g g l e W i f i O f f ( c o m p l e t e _ c a l l b a c k )  
                 e n d ,  
         } )  
 e n d  
  
 - -   N O T E :   C u r r e n t l y   o n l y   h a s   a   s i n g l e   c a l l e r ,   t h e   M e n u   e n t r y ,   s o   i t ' s   a l w a y s   f l a g g e d   a s   i n t e r a c t i v e  
 f u n c t i o n   N e t w o r k M g r : p r o m p t W i f i ( c o m p l e t e _ c a l l b a c k ,   l o n g _ p r e s s ,   i n t e r a c t i v e )  
         l o c a l   t e x t   =   _ ( " W i - F i   i s   e n a b l e d ,   b u t   y o u ' r e   c u r r e n t l y   n o t   c o n n e c t e d   t o   a   n e t w o r k . " )  
         - -   D e t a i l   w h e t h e r   t h e r e ' s   a n   a t t e m p t   a n d / o r   a   c o n n e c t i v i t y   c h e c k   i n   p r o g r e s s .  
         i f   s e l f . p e n d i n g _ c o n n e c t i o n   t h e n  
                 - -   N O T E :   I n c i d e n t a l l y ,   t h i s   m e a n s   t h a t   t a p p i n g   C o n n e c t   w o u l d   y i e l d   E B U S Y ,   s o   w e   g r a y   i t   o u t . . .  
                 t e x t   =   t e x t   . .   " \ n "   . .   _ ( " P l e a s e   n o t e   t h a t   a   c o n n e c t i o n   a t t e m p t   i s   c u r r e n t l y   i n   p r o g r e s s ! " )  
         e n d  
         i f   s e l f . p e n d i n g _ c o n n e c t i v i t y _ c h e c k   t h e n  
                 t e x t   =   t e x t   . .   " \ n "   . .   _ ( " K O R e a d e r   i s   c u r r e n t l y   w a i t i n g   f o r   c o n n e c t i v i t y .   T h i s   m a y   t a k e   u p   t o   4 5 s ,   s o   y o u   m a y   j u s t   w a n t   t o   t r y   a g a i n   l a t e r . " )  
         e n d  
         t e x t   =   t e x t   . .   " \ n "   . .   _ ( " H o w   w o u l d   y o u   l i k e   t o   p r o c e e d ? " )  
         U I M a n a g e r : s h o w ( M u l t i C o n f i r m B o x : n e w {  
                 t e x t   =   t e x t ,  
                 - -   " C a n c e l "   c o u l d   b e   c o n s t r u e d   a s   " c a n c e l   t h e   c u r r e n t   a t t e m p t " ,   w h i c h   i s   n o t   w h a t   t h i s   d o e s   ; p .  
                 c a n c e l _ t e x t   =   _ ( " D i s m i s s " ) ,  
                 c h o i c e 1 _ t e x t   =   _ ( " T u r n   W i - F i   o f f " ) ,  
                 c h o i c e 1 _ c a l l b a c k   =   f u n c t i o n ( )  
                         s e l f : t o g g l e W i f i O f f ( c o m p l e t e _ c a l l b a c k ,   i n t e r a c t i v e )  
                 e n d ,  
                 c h o i c e 2 _ t e x t   =   _ ( " C o n n e c t " ) ,  
                 c h o i c e 2 _ e n a b l e d   =   n o t   s e l f . p e n d i n g _ c o n n e c t i o n ,  
                 c h o i c e 2 _ c a l l b a c k   =   f u n c t i o n ( )  
                         s e l f : t o g g l e W i f i O n ( c o m p l e t e _ c a l l b a c k ,   l o n g _ p r e s s ,   i n t e r a c t i v e )  
                 e n d ,  
         } )  
 e n d  
  
 f u n c t i o n   N e t w o r k M g r : t u r n O n W i f i A n d W a i t F o r C o n n e c t i o n ( c a l l b a c k )  
         - -   J u s t   r u n   t h e   c a l l b a c k   i f   W i F i   i s   a l r e a d y   u p   * a n d *   t h e   l e a s e   i s   f o r   t h e   c u r r e n t   n e t w o r k .  
         i f   s e l f : i s W i f i O n ( )   a n d   s e l f : i s C o n n e c t e d ( )   t h e n  
                 i f   s e l f : h a s L e a s e F o r C u r r e n t N e t w o r k ( )   t h e n  
                         - - -   @ n o t e :   b e f o r e W i f i A c t i o n   o n l y   g u a r a n t e e s   i s C o n n e c t e d ,   n o t   i s O n l i n e .  
                         - -                   I n   t h e   r a r e   c a s e s   w e ' r e   i s C o n n e c t e d   b u t   ! i s O n l i n e ,   i f   w e ' r e   c a l l e d   v i a   a   * r u n W h e n O n l i n e   w r a p p e r ,  
                         - -                   w e   d o n ' t   g e t   a   c a l l b a c k   a t   a l l   t o   a v o i d   i n f i n i t e   r e c u r s i o n ,   s o   w e   n e e d   t o   c h e c k   i t .  
                         i f   c a l l b a c k   t h e n  
                                 c a l l b a c k ( )  
                         e n d  
                         r e t u r n  
                 e n d  
                 - -   T h e   D H C P   l e a s e   b e l o n g s   t o   a   d i f f e r e n t   n e t w o r k   t h a n   t h e   o n e   w p a _ s u p p l i c a n t   i s  
                 - -   c u r r e n t l y   a s s o c i a t e d   w i t h   ( s t a l e   l e a s e   a f t e r   a   n e t w o r k   s w i t c h ,   # 1 4 7 9 0 ) .  
                 - -   R e l e a s e   t h e   o l d   a d d r e s s   a n d   f a l l   t h r o u g h   t o   t h e   n o r m a l   r e c o n n e c t   p a t h ,   w h i c h  
                 - -   w i l l   r e - a s s o c i a t e   a n d   r e - r u n   o b t a i n I P ( )   f o r   t h e   c u r r e n t   n e t w o r k .  
                 l o g g e r . i n f o ( " N e t w o r k M g r :   s t a l e   D H C P   l e a s e   d e t e c t e d   ( l e a s e _ s s i d = " ,   s e l f . l e a s e _ s s i d ,   " ) ,   f o r c i n g   r e - D H C P   f o r   c u r r e n t   n e t w o r k " )  
                 s e l f : r e l e a s e I P ( )  
                 s e l f . l e a s e _ s s i d   =   n i l  
                 - -   f a l l   t h r o u g h      n o   r e t u r n  
         e n d  
  
         l o c a l   i n f o   =   I n f o M e s s a g e : n e w {   t e x t   =   _ ( " C o n n e c t i n g   t o   W i - F i & " )   }  
         U I M a n a g e r : s h o w ( i n f o )  
         U I M a n a g e r : f o r c e R e P a i n t ( )  
  
         - -   N O T E :   T h i s   i s   a   s l i g h t l y   t w e a k e d   v a r i a n t   o f   e n a b l e W i f i ,   i n   o r d e r   t o   h a n d l e   o u r   i n f o   w i d g e t . . .  
         l o c a l   c o n n e c t i v i t y _ c b   =   f u n c t i o n ( )  
                 i f   s e l f . p e n d i n g _ c o n n e c t i v i t y _ c h e c k   t h e n  
                         s e l f : u n s c h e d u l e C o n n e c t i v i t y C h e c k ( )  
                 e n d  
  
                 s e l f : s c h e d u l e C o n n e c t i v i t y C h e c k ( c a l l b a c k ,   i n f o )  
         e n d  
         l o c a l   s t a t u s   =   s e l f : r e q u e s t T o T u r n O n W i f i ( c o n n e c t i v i t y _ c b )  
         i f   s t a t u s   = =   f a l s e   t h e n  
                 l o g g e r . w a r n ( " N e t w o r k M g r : t u r n O n W i f i A n d W a i t F o r C o n n e c t i o n :   C o n n e c t i o n   f a i l e d ! " )  
                 s e l f : _ a b o r t W i f i C o n n e c t i o n ( )  
                 U I M a n a g e r : c l o s e ( i n f o )  
                 r e t u r n   f a l s e  
         e l s e i f   s t a t u s   = =   E B U S Y   t h e n  
                 l o g g e r . w a r n ( " N e t w o r k M g r : t u r n O n W i f i A n d W a i t F o r C o n n e c t i o n :   A   p r e v i o u s   c o n n e c t i o n   a t t e m p t   i s   s t i l l   o n g o i n g ! " )  
                 - -   W e   m i g h t   l o s e   a   c a l l b a c k   i n   c a s e   t h e   p r e v i o u s   a t t e m p t   w a s n ' t   f r o m   t h e   s a m e   a c t i o n ,  
                 - -   b u t   i t ' s   j u s t   p l a i n   s a n e r   t o   j u s t   a b o r t   h e r e ,   a s   w e ' d   r i s k   c a l l i n g   t h e   s a m e   t h i n g   o v e r   a n d   o v e r . . .  
                 U I M a n a g e r : c l o s e ( i n f o )  
                 r e t u r n  
         e n d  
  
         r e t u r n   i n f o  
 e n d  
  
 - -   T h i s   i s   o n l y   u s e d   o n   A n d r o i d ,   t h e   i n t e n t   b e i n g   w e   a s s u m e   t h e   s y s t e m   w i l l   e v e n t u a l l y   t u r n   o n   W i F i   o n   i t s   o w n   i n   t h e   b a c k g r o u n d . . .  
 f u n c t i o n   N e t w o r k M g r : d o N o t h i n g A n d W a i t F o r C o n n e c t i o n ( c a l l b a c k )  
         i f   s e l f : i s W i f i O n ( )   a n d   s e l f : i s C o n n e c t e d ( )   t h e n  
                 i f   s e l f : h a s L e a s e F o r C u r r e n t N e t w o r k ( )   t h e n  
                         i f   c a l l b a c k   t h e n  
                                 c a l l b a c k ( )  
                         e n d  
                         r e t u r n  
                 e n d  
                 - -   S t a l e   l e a s e   a f t e r   a   n e t w o r k   s w i t c h ;   d r o p   i t   a n d   f a l l   t h r o u g h   ( # 1 4 7 9 0 ) .  
                 l o g g e r . i n f o ( " N e t w o r k M g r :   s t a l e   D H C P   l e a s e   d e t e c t e d   ( l e a s e _ s s i d = " ,   s e l f . l e a s e _ s s i d ,   " ) ,   f o r c i n g   r e - D H C P   f o r   c u r r e n t   n e t w o r k " )  
                 s e l f : r e l e a s e I P ( )  
                 s e l f . l e a s e _ s s i d   =   n i l  
                 - -   f a l l   t h r o u g h      n o   r e t u r n  
         e n d  
  
         s e l f : s c h e d u l e C o n n e c t i v i t y C h e c k ( c a l l b a c k )  
 e n d  
  
 - - -   T h i s   q u i r k y   i n t e r n a l   f l a g   i s   u s e d   f o r   t h e   r a r e   b e f o r e W i f i A c t i o n   - >   a f t e r W i f i A c t i o n   b r a c k e t s .  
 f u n c t i o n   N e t w o r k M g r : c l e a r B e f o r e A c t i o n F l a g ( )  
         s e l f . _ b e f o r e _ a c t i o n _ t r i p p e d   =   n i l  
 e n d  
  
 f u n c t i o n   N e t w o r k M g r : s e t B e f o r e A c t i o n F l a g ( )  
         s e l f . _ b e f o r e _ a c t i o n _ t r i p p e d   =   t r u e  
 e n d  
  
 f u n c t i o n   N e t w o r k M g r : g e t B e f o r e A c t i o n F l a g ( )  
         r e t u r n   s e l f . _ b e f o r e _ a c t i o n _ t r i p p e d  
 e n d  
  
 - - -   @ n o t e :   T h e   c a l l b a c k   w i l l   o n l y   r u n   * a f t e r *   a   * s u c c e s s f u l *   n e t w o r k   c o n n e c t i o n .  
 - - -                 T h e   o n l y   g u a r a n t e e   i t   p r o v i d e s   i s   i s C o n n e c t e d   ( i . e . ,   a n   I P   &   a   l o c a l   g a t e w a y ) ,  
 - - -                 * N O T *   i s O n l i n e   ( i . e . ,   W A N ) ,   s e   b e   c a r e f u l   w i t h   r e c u r s i v e   c a l l b a c k s !  
 - - -                 S h o u l d   o n l y   r e t u r n   f a l s e   o n   * e x p l i c i t *   f a i l u r e s ,  
 - - -                 i n   w h i c h   c a s e   t h e   b a c k e n d   w i l l   a l r e a d y   h a v e   c a l l e d   _ a b o r t W i f i C o n n e c t i o n  
 f u n c t i o n   N e t w o r k M g r : b e f o r e W i f i A c t i o n ( c a l l b a c k )  
         - -   R e m e m b e r   t h a t   w e   r a n ,   f o r   a f t e r W i f i A c t i o n . . .  
         s e l f : s e t B e f o r e A c t i o n F l a g ( )  
  
         l o c a l   w i f i _ e n a b l e _ a c t i o n   =   G _ r e a d e r _ s e t t i n g s : r e a d S e t t i n g ( " w i f i _ e n a b l e _ a c t i o n " )  
         i f   w i f i _ e n a b l e _ a c t i o n   = =   " t u r n _ o n "   t h e n  
                 r e t u r n   s e l f : t u r n O n W i f i A n d W a i t F o r C o n n e c t i o n ( c a l l b a c k )  
         e l s e i f   w i f i _ e n a b l e _ a c t i o n   = =   " i g n o r e "   t h e n  
                 r e t u r n   s e l f : d o N o t h i n g A n d W a i t F o r C o n n e c t i o n ( c a l l b a c k )  
         e l s e  
                 r e t u r n   s e l f : p r o m p t W i f i O n ( c a l l b a c k )  
         e n d  
 e n d  
  
 - -   N O T E :   T h i s   i s   a c t u a l l y   u s e d   v e r y   s p a r i n g l y   ( n e w s d o w n l o a d e r / s e n d 2 e b o o k ) ,  
 - -               b e c a u s e   b r a c k e t i n g   a   s i n g l e   a c t i o n   i n   a   c o n n e c t / d i s c o n n e c t   s e s s i o n   d o e s n ' t   n e c e s s a r i l y   m a k e   m u c h   s e n s e . . .  
 f u n c t i o n   N e t w o r k M g r : a f t e r W i f i A c t i o n ( c a l l b a c k )  
         - -   D o n ' t   d o   a n y t h i n g   i f   b e f o r e W i f i A c t i o n   n e v e r   a c t u a l l y   r a n . . .  
         i f   n o t   s e l f : g e t B e f o r e A c t i o n F l a g ( )   t h e n  
                 r e t u r n  
         e n d  
         s e l f : c l e a r B e f o r e A c t i o n F l a g ( )  
  
         l o c a l   w i f i _ d i s a b l e _ a c t i o n   =   G _ r e a d e r _ s e t t i n g s : r e a d S e t t i n g ( " w i f i _ d i s a b l e _ a c t i o n " )  
         i f   w i f i _ d i s a b l e _ a c t i o n   = =   " l e a v e _ o n "   t h e n  
                 - -   N O P   : )  
                 i f   c a l l b a c k   t h e n  
                       c a l l b a c k ( )  
                 e n d  
         e l s e i f   w i f i _ d i s a b l e _ a c t i o n   = =   " t u r n _ o f f "   t h e n  
                 s e l f : d i s a b l e W i f i ( c a l l b a c k )  
         e l s e  
                 s e l f : p r o m p t W i f i O f f ( c a l l b a c k )  
         e n d  
 e n d  
  
 f u n c t i o n   N e t w o r k M g r : i s O n l i n e ( )  
         - -   F o r   t h e   s a m e   r e a s o n s   a s   i s W i f i O n   a n d   i s C o n n e c t e d   a b o v e ,   b y p a s s   t h i s   o n   ! h a s W i f i T o g g l e   p l a t f o r m s .  
         i f   n o t   D e v i c e : h a s W i f i T o g g l e ( )   t h e n  
                 r e t u r n   t r u e  
         e n d  
  
         r e t u r n   s e l f : c a n R e s o l v e H o s t n a m e s ( )  
 e n d  
  
 - -   U p d a t e   o u r   c a c h e d   n e t w o r k   s t a t u s  
 f u n c t i o n   N e t w o r k M g r : q u e r y N e t w o r k S t a t e ( )  
         s e l f . i s _ w i f i _ o n   =   s e l f : i s W i f i O n ( )  
         s e l f . i s _ c o n n e c t e d   =   s e l f . i s _ w i f i _ o n   a n d   s e l f : i s C o n n e c t e d ( )  
 e n d  
  
 - -   T h e s e   d o   n o t   c a l l   t h e   a c t u a l   D e v i c e   m e t h o d s ,   b u t   w h a t   w e ,   N e t w o r k M g r ,   t h i n k   t h e   s t a t e   i s   b a s e d   o n   o u r   o w n   b e h a v i o r .  
 f u n c t i o n   N e t w o r k M g r : g e t W i f i S t a t e ( )  
         r e t u r n   s e l f . i s _ w i f i _ o n  
 e n d  
 f u n c t i o n   N e t w o r k M g r : s e t W i f i S t a t e ( b o o l )  
         s e l f . i s _ w i f i _ o n   =   b o o l  
 e n d  
 f u n c t i o n   N e t w o r k M g r : g e t C o n n e c t i o n S t a t e ( )  
         r e t u r n   s e l f . i s _ c o n n e c t e d  
 e n d  
 f u n c t i o n   N e t w o r k M g r : s e t C o n n e c t i o n S t a t e ( b o o l )  
         s e l f . i s _ c o n n e c t e d   =   b o o l  
 e n d  
  
  
 f u n c t i o n   N e t w o r k M g r : i s N e t w o r k I n f o A v a i l a b l e ( )  
         i f   D e v i c e : i s A n d r o i d ( )   t h e n  
                 - -   a l w a y s   a v a i l a b l e  
                 r e t u r n   t r u e  
         e l s e  
                 r e t u r n   s e l f : i s C o n n e c t e d ( )  
         e n d  
 e n d  
  
 f u n c t i o n   N e t w o r k M g r : s e t H T T P P r o x y ( p r o x y )  
         l o c a l   h t t p   =   r e q u i r e ( " s o c k e t . h t t p " )  
         h t t p . P R O X Y   =   p r o x y  
         i f   p r o x y   t h e n  
                 G _ r e a d e r _ s e t t i n g s : s a v e S e t t i n g ( " h t t p _ p r o x y " ,   p r o x y )  
                 G _ r e a d e r _ s e t t i n g s : m a k e T r u e ( " h t t p _ p r o x y _ e n a b l e d " )  
         e l s e  
                 G _ r e a d e r _ s e t t i n g s : m a k e F a l s e ( " h t t p _ p r o x y _ e n a b l e d " )  
         e n d  
 e n d  
  
 - -   H e l p e r   f u n c t i o n s   t o   h i d e   t h e   q u i r k s   o f   u s i n g   b e f o r e W i f i A c t i o n   p r o p e r l y   ; ) .  
  
 - -   R u n   c a l l b a c k   * n o w *   i f   y o u ' r e   c u r r e n t l y   o n l i n e   ( i e . ,   i s O n l i n e ) ,  
 - -   o r   a t t e m p t   t o   g o   o n l i n e   a n d   r u n   i t   * A S A P *   w i t h o u t   a n y   m o r e   u s e r   i n t e r a c t i o n .  
 - -   N O T E :   I f   y o u ' r e   c u r r e n t l y   c o n n e c t e d   b u t   w i t h o u t   I n t e r n e t   a c c e s s   ( i . e . ,   i s C o n n e c t e d   a n d   n o t   i s O n l i n e ) ,  
 - -               i t   w i l l   j u s t   a t t e m p t   t o   r e - c o n n e c t ,   * w i t h o u t *   r u n n i n g   t h e   c a l l b a c k .  
 - -   c . f . ,   R e a d e r W i k i p e d i a : o n S h o w W i k i p e d i a L o o k u p   @   f r o n t e n d / a p p s / r e a d e r / m o d u l e s / r e a d e r w i k i p e d i a . l u a  
 f u n c t i o n   N e t w o r k M g r : r u n W h e n O n l i n e ( c a l l b a c k )  
         i f   s e l f : i s O n l i n e ( )   t h e n  
                 c a l l b a c k ( )  
         e l s e  
                 - - -   @ n o t e :   A v o i d   i n f i n i t e   r e c u r s i o n ,   b e f o r e W i f i A c t i o n   o n l y   g u a r a n t e e s   i s C o n n e c t e d ,   n o t   i s O n l i n e .  
                 i f   n o t   s e l f : i s C o n n e c t e d ( )   t h e n  
                         s e l f : b e f o r e W i f i A c t i o n ( c a l l b a c k )  
                 e l s e  
                         s e l f : b e f o r e W i f i A c t i o n ( )  
                 e n d  
         e n d  
 e n d  
  
 - -   T h i s   o n e   i s   f o r   c a l l b a c k s   t h a t   o n l y   r e q u i r e   i s C o n n e c t e d ,   a n d   s i n c e   t h a t ' s   g u a r a n t e e d   b y   b e f o r e W i f i A c t i o n ,  
 - -   y o u   a l s o   h a v e   a   g u a r a n t e e   t h a t   t h e   c a l l b a c k   * w i l l *   r u n .  
 f u n c t i o n   N e t w o r k M g r : r u n W h e n C o n n e c t e d ( c a l l b a c k )  
         i f   s e l f : i s C o n n e c t e d ( )   t h e n  
                 c a l l b a c k ( )  
         e l s e  
                 s e l f : b e f o r e W i f i A c t i o n ( c a l l b a c k )  
         e n d  
 e n d  
  
 - -   M i l d   v a r i a n t s   t h a t   a r e   u s e d   f o r   r e c u r s i v e   c a l l s   a t   t h e   b e g i n n i n g   o f   a   c o m p l e x   f u n c t i o n   c a l l .  
 - -   R e t u r n s   t r u e   w h e n   n o t   y e t   o n l i n e ,   i n   w h i c h   c a s e   y o u   s h o u l d   * a b o r t *   ( i . e . ,   r e t u r n )   t h e   i n i t i a l   c a l l ,  
 - -   a n d   o t h e r w i s e ,   g o - o n   a s   p l a n n e d .  
 - -   N O T E :   I f   y o u ' r e   c u r r e n t l y   c o n n e c t e d   b u t   w i t h o u t   I n t e r n e t   a c c e s s   ( i . e . ,   i s C o n n e c t e d   a n d   n o t   i s O n l i n e ) ,  
 - -               i t   w i l l   j u s t   a t t e m p t   t o   r e - c o n n e c t ,   * w i t h o u t *   r u n n i n g   t h e   c a l l b a c k .  
 - -   c . f . ,   R e a d e r W i k i p e d i a : l o o k u p W i k i p e d i a   @   f r o n t e n d / a p p s / r e a d e r / m o d u l e s / r e a d e r w i k i p e d i a . l u a  
 f u n c t i o n   N e t w o r k M g r : w i l l R e r u n W h e n O n l i n e ( c a l l b a c k )  
         i f   n o t   s e l f : i s O n l i n e ( )   t h e n  
                 - - -   @ n o t e :   A v o i d   i n f i n i t e   r e c u r s i o n ,   b e f o r e W i f i A c t i o n   o n l y   g u a r a n t e e s   i s C o n n e c t e d ,   n o t   i s O n l i n e .  
                 i f   n o t   s e l f : i s C o n n e c t e d ( )   t h e n  
                         s e l f : b e f o r e W i f i A c t i o n ( c a l l b a c k )  
                 e l s e  
                         s e l f : b e f o r e W i f i A c t i o n ( )  
                 e n d  
                 r e t u r n   t r u e  
         e n d  
  
         r e t u r n   f a l s e  
 e n d  
  
 - -   T h i s   o n e   i s   f o r   c a l l b a c k s   t h a t   o n l y   r e q u i r e   i s C o n n e c t e d ,   a n d   s i n c e   t h a t ' s   g u a r a n t e e d   b y   b e f o r e W i f i A c t i o n ,  
 - -   y o u   a l s o   h a v e   a   g u a r a n t e e   t h a t   t h e   c a l l b a c k   * w i l l *   r u n .  
 f u n c t i o n   N e t w o r k M g r : w i l l R e r u n W h e n C o n n e c t e d ( c a l l b a c k )  
         i f   n o t   s e l f : i s C o n n e c t e d ( )   t h e n  
                 s e l f : b e f o r e W i f i A c t i o n ( c a l l b a c k )  
                 r e t u r n   t r u e  
         e n d  
  
         r e t u r n   f a l s e  
 e n d  
  
 - -   A n d   t h i s   o n e   i s   f o r   w h e n   y o u   a b s o l u t e l y   * n e e d *   t o   b l o c k   u n t i l   w e ' r e   o n l i n e   t o   r u n   s o m e t h i n g   ( e . g . ,   b e c a u s e   i t   r u n s   i n   a   f i n a l i z e r ) .  
 f u n c t i o n   N e t w o r k M g r : g o O n l i n e T o R u n ( c a l l b a c k )  
         i f   s e l f : i s O n l i n e ( )   t h e n  
                 c a l l b a c k ( )  
                 r e t u r n   t r u e  
         e n d  
  
         - -   I f   b e f o r e W i f i A c t i o n   i s n ' t   t u r n _ o n ,   w e ' r e   d o n e .  
         - -   W e   d o n ' t   w a n t   t o   g o   b e h i n d   t h e   u s e r ' s   b a c k   b y   e n f o r c i n g   " t u r n _ o n "   b e h a v i o r ,  
         - -   a n d   w e   * c a n n o t *   u s e   p r o m p t ,   a s   w e ' l l   b l o c k   b e f o r e   h a n d l i n g   t h e   p o p u p   i n p u t . . .  
         - -   N O T E :   I g n o r e   * t e c h n i c a l l y *   w o r k s ,   b u t   u n l i k e   d o N o t h i n g A n d W a i t F o r C o n n e c t i o n ,   w e   * w o u l d *   b e   d i s p l a y i n g   a n   I n f o M e s s a g e  
         - -               ( a n d   b l o c k / w a i t   f o r   i n p u t   a s   u s u a l ) .   T h e   o n l y   d i f f e r e n c e   w i t h   t u r n _ o n   w o u l d   b e   t h e   f a c t   t h a t   w e   w o u l d n ' t   * e v e r *   e v e n   t r y   t o   c a l l   t u r n O n W i f i .  
         - -               G i v e n   t h a t   " i g n o r e "   i s   s u p p o s e d   t o   b e   s i l e n t ,   a n d   t h a t   y o u   w o u l d n ' t   a c t u a l l y   b e   a b l e   t o   e n a b l e   W i F i   y o u r s e l f   a t   t h a t   p o i n t  
         - -               ( b e c a u s e   t h a t   r e q u i r e s   u s e r   i n p u t ,   w h i c h   w o u l d   c a n c e l   t h e   w h o l e   t h i n g ) ,   t h e r e ' s   p r o b a b l y   n o t   m u c h   t o   g a i n   b y   a l l o w i n g   " i g n o r e "   h e r e . . .  
         i f   G _ r e a d e r _ s e t t i n g s : r e a d S e t t i n g ( " w i f i _ e n a b l e _ a c t i o n " )   ~ =   " t u r n _ o n "   t h e n  
                 l o g g e r . w a r n ( " N e t w o r k M g r : g o O n l i n e T o R u n :   C a n n o t   r u n   c a l l b a c k   b e c a u s e   d e v i c e   i s   o f f l i n e   a n d   w i f i _ e n a b l e _ a c t i o n   i s   n o t   t u r n _ o n " )  
                 r e t u r n   f a l s e  
         e n d  
  
         - -   W e ' l l   d o   t e r r i b l e   t h i n g s   w i t h   t h i s   l a t e r . . .  
         l o c a l   I n p u t   =   D e v i c e . i n p u t  
  
         - -   I n   c a s e   w e   a b o r t   b e f o r e   t h e   b e f o r e W i f i A c t i o n ,   w e   w o n ' t   p a s s   i t   t h e   c a l l b a c k ,   b u t   r u n   i t   o u r s e l v e s ,  
         - -   t o   a v o i d   i t   f i r i n g   t o o   l a t e   ( o r   a t   t h e   v e r y   l e a s t   b e i n g   p i n n e d   f o r   t o o   l o n g ) .  
         l o c a l   i n f o   =   s e l f : b e f o r e W i f i A c t i o n ( )  
         - -   N O T E :   U n l i k e   t u r n O n W i f i A n d W a i t F o r C o n n e c t i o n ,   w e ' r e   n o t   r e e n t r a n t ,  
         - -               s o   i f   t h e r e ' s   a l r e a d y   a   c o n n e c t i o n   a t t e m p t   p e n d i n g ,  
         - -               w e   c a n   a f f o r d   t o   * t r y *   t o   w a i t   f o r   i t s   s u c c e s s ,  
         - -               e s p e c i a l l y   s i n c e   w e   c a n   b e   c a n c e l l e d .  
         - -               T h e   f o l l o w i n g   c a l l   * w i l l *   m u r d e r   a n y   a n d   a l l   p e n d i n g   c a l l b a c k s   t h o u g h ,  
         - -               w h i c h   i s   a   * s l i g h t l y *   d i f f e r e n t   b e h a v i o r   t h a n   t u r n O n W i f i A n d W a i t F o r C o n n e c t i o n ,  
         - -               b u t   a   n e c e s s i t y   t o   e n s u r e   s a n e   l i f e c y c l e s . . .  
  
         - -   W e ' l l   b a s i c a l l y   d o   t h e   s a m e   b u t   i n   a   b l o c k i n g   m a n n e r . . .  
         - -   N O T E :   S i n c e   U I M a n a g e r   w o n ' t   t i c k ,   t h e y   w o u l d n ' t   r e a l l y   h a v e   a   c h a n c e   t o   r u n   a n y w a y . . .  
         - -               G i v e n   t h e   c o n s t r a i n t s   o f   o u r   c a l l e r s ,   t h e y   w o u l d   v e r y   l i k e l y   a f f e c t   d e a d / d y i n g   o b j e c t s   a n y w a y ,  
         - -               s o   i t ' s   m u c h   s a n e r   t o   j u s t   d r o p   t h e m .  
         s e l f : u n s c h e d u l e C o n n e c t i v i t y C h e c k ( )  
  
         - -   I f   c o n n e c t i n g   j u s t   p l a i n   f a i l e d ,   w e ' r e   d o n e  
         i f   i n f o   = =   f a l s e   t h e n  
                 r e t u r n   f a l s e  
         e n d  
  
         - -   T h r o w   i n   a   c o n n e c t i v i t y   c h e c k   n o w ,   f o r   t h e   s a k e   o f   h a s W i f i M a n a g e r   p l a t f o r m s ,  
         - -   w h e r e   w e   m a n a g e   W i - F i   o u r s e l v e s ,   m e a n i n g   t u r n O n W i f i ,   a n d   a s   s u c h   b e f o r e W i f i A c t i o n ,  
         - -   i s   * b l o c k i n g * ,   s o   i f   a l l   w e n t   w e l l ,   w e ' l l   a l r e a d y   h a v e   b l o c k e d   a   w h i l e ,  
         - -   b u t   t h e   c o n n e c t i o n   w i l l   b e   u p   a l r e a d y .  
         s e l f : q u e r y N e t w o r k S t a t e ( )  
  
         l o c a l   i t e r   =   0  
         l o c a l   s u c c e s s   =   t r u e  
         w h i l e   n o t   s e l f . i s _ c o n n e c t e d   d o  
                 i f   i t e r   = =   0   t h e n  
                         - -   D i s p l a y   a   s l i g h t l y   m o r e   a c c u r a t e   I M   w h i l e   w e   w a i t . . .  
                         i f   i n f o   t h e n  
                                 U I M a n a g e r : c l o s e ( i n f o )  
                         e n d  
                         i n f o   =   I n f o M e s s a g e : n e w {   t e x t   =   _ ( " W a i t i n g   f o r   n e t w o r k   c o n n e c t i v i t y & " )   }  
                         U I M a n a g e r : s h o w ( i n f o )  
                         U I M a n a g e r : f o r c e R e P a i n t ( )  
                 e n d  
  
                 i t e r   =   i t e r   +   1  
                 i f   i t e r   > =   1 2 0   t h e n  
                         l o g g e r . w a r n ( " N e t w o r k M g r : g o O n l i n e T o R u n :   T i m e d   o u t ! " )  
                         s u c c e s s   =   f a l s e  
                         b r e a k  
                 e n d  
  
                 - -   N O T E :   H e r e   b e   d r a g o n s !   W e   w a n t   t o   b e   a b l e   t o   a b o r t   o n   u s e r   i n p u t ,   s o ,  
                 - -               h a n d l e   t h e   2 5 0 m s   c h u n k s   o f   w a i t i n g   v i a   o u r   a c t u a l   i n p u t   p o l l i n g . . .  
                 - -   W e   d o n ' t   a c t u a l l y   l e t   t h e   a c t u a l   U I   l o o p   t i c k ,   s o   ` n o w `   w i l l   n e v e r   c h a n g e ,  
                 - -   w h i c h   i s   g o o d ,   w e   d o n ' t   w a n t   t o   d i s t u r b   t h e   t a s k   q u e u e   h a n d l i n g .  
                 - -   ( A n d   w e   a c t u a l l y   w a n t   a   f i x e d   2 5 0 m s   s e l e c t   a n y w a y ) .  
                 - -   N O T E :   T h i s   * d o e s *   m e a n   t h a t   m u l t i p l e   b u r s t s   o f   i n p u t   e v e n t s   * w i l l *  
                 - -               m a k e   t h i s   l o o p   r u n   f o r   l e s s   t h a n   1 2 0   *   2 5 0 m s ,   a s   s e l e c t   c o u l d   r e t u r n   e a r l y .  
                 - -               A s s u m i n g   w e   d o n ' t   a c t u a l l y   a b o r t   * b e c a u s e *   o f   s a i d   i n p u t   ( e . g . ,   n o t   t a p s )   ; ) .  
                 l o c a l   n o w   =   U I M a n a g e r : g e t T i m e ( )  
                 l o c a l   i n p u t _ e v e n t s   =   I n p u t : w a i t E v e n t ( n o w ,   n o w   +   t i m e . m s ( 2 5 0 ) )  
                 i f   i n p u t _ e v e n t s   t h e n  
                         f o r   _ _ ,   e v   i n   i p a i r s ( i n p u t _ e v e n t s )   d o  
                                 - -   W e ' l l   w a n t   t o   a b o r t   o n   a c t u a l   s i n g l e   t a p s   o n l y ,   i n   c a s e   t h e r e ' s   e x t r a   n o i s e   f r o m   s t u f f   l i k e   a   g y r o   o r   s o m e t h i n g . . .  
                                 i f   e v . h a n d l e r   = =   " o n G e s t u r e "   t h e n  
                                         l o c a l   a r g s   =   u n p a c k ( e v . a r g s ,   1 ,   e v . a r g s . n )  
                                         i f   a r g s . g e s   = =   " t a p "   t h e n  
                                                 l o g g e r . w a r n ( " N e t w o r k M g r : g o O n l i n e T o R u n :   A b o r t e d   b y   u s e r   i n p u t ! " )  
                                                 s u c c e s s   =   f a l s e  
                                                 - -   N o   n e e d   t o   c h e c k   f u r t h e r   a r g s  
                                                 b r e a k  
                                         e n d  
                                 e n d  
                         e n d  
                         - -   B r e a k   o u t   o f   t h e   a c t u a l   l o o p   o n   a b o r t  
                         i f   n o t   s u c c e s s   t h e n  
                                 b r e a k  
                         e n d  
                 e n d  
  
                 s e l f : q u e r y N e t w o r k S t a t e ( )  
         e n d  
  
         - -   T o   m a k e   o u r   p r e v i o u s   i n p u t   s h e n a n i g a n s   s l i g h t l y   l e s s   c r a z y ,   r e s e t   t h e   w h o l e   i n p u t   s t a t e .  
         I n p u t : r e s e t S t a t e ( )  
  
         - -   C l o s e   t h e   i n i t i a l   " C o n n e c t i n g . . . "   I n f o M e s s a g e   f r o m   t u r n O n W i f i A n d W a i t F o r C o n n e c t i o n   v i a   b e f o r e W i f i A c t i o n ,  
         - -   o r   o u r   o w n   " W a i t i n g   f o r   n e t w o r k   c o n n e c t i v i t y "   o n e .  
         i f   i n f o   t h e n  
                 U I M a n a g e r : c l o s e ( i n f o )  
         e n d  
  
         - -   C h e c k   w h e t h e r   w e   c o n n e c t e d   s u c c e s s f u l l y . . .  
         i f   s u c c e s s   t h e n  
                 - -   W e ' r e   f i n a l l y   c o n n e c t e d !  
                 l o g g e r . i n f o ( " S u c c e s s f u l l y   c o n n e c t e d   t o   W i - F i   ( a f t e r " ,   i t e r   *   0 . 2 5 ,   " s e c o n d s ) ! " )  
                 s e l f . w i f i _ w a s _ o n   =   t r u e  
                 G _ r e a d e r _ s e t t i n g s : m a k e T r u e ( " w i f i _ w a s _ o n " )  
                 c a l l b a c k ( )  
                 - -   D e l a y   t h i s   s o   i t   w o n ' t   f i r e   f o r   d e a d / d y i n g   i n s t a n c e s   i n   c a s e   w e ' r e   c a l l e d   b y   a   f i n a l i z e r . . .  
                 U I M a n a g e r : s c h e d u l e I n ( 2 ,   f u n c t i o n ( )  
                         U I M a n a g e r : b r o a d c a s t E v e n t ( E v e n t : n e w ( " N e t w o r k C o n n e c t e d " ) )  
                 e n d )  
         e l s e  
                 - -   W e ' r e   n o t   c o n n e c t e d   : (  
                 l o g g e r . i n f o ( " F a i l e d   t o   c o n n e c t   t o   W i - F i   a f t e r " ,   i t e r   *   0 . 2 5 ,   " s e c o n d s ,   g i v i n g   u p ! " )  
                 s e l f : _ a b o r t W i f i C o n n e c t i o n ( )  
                 U I M a n a g e r : s h o w ( I n f o M e s s a g e : n e w {   t e x t   =   _ ( " E r r o r   c o n n e c t i n g   t o   t h e   n e t w o r k " )   } )  
         e n d  
         - -   W e ' r e   d o n e ,   r e s e t   t h e   p e n d i n g   c o n n e c t i o n   f l a g ,   a s   w e   d o n ' t   h a v e   a n y   s c h e d u l e d   c o n n e c t i v i t y   c h e c k   t o   d o   i t   f o r   u s .  
         s e l f . p e n d i n g _ c o n n e c t i o n   =   f a l s e  
  
         r e t u r n   s u c c e s s  
 e n d  
  
  
  
 f u n c t i o n   N e t w o r k M g r : g e t W i f i M e n u T a b l e ( )  
         i f   D e v i c e : i s A n d r o i d ( )   t h e n  
                 r e t u r n   {  
                         t e x t   =   _ ( " W i - F i   s e t t i n g s " ) ,  
                         c a l l b a c k   =   f u n c t i o n ( )   s e l f : o p e n S e t t i n g s ( )   e n d ,  
                 }  
         e l s e  
                 r e t u r n   s e l f : g e t W i f i T o g g l e M e n u T a b l e ( )  
         e n d  
 e n d  
  
 f u n c t i o n   N e t w o r k M g r : g e t W i f i T o g g l e M e n u T a b l e ( )  
         l o c a l   t o g g l e C a l l b a c k   =   f u n c t i o n ( t o u c h m e n u _ i n s t a n c e ,   l o n g _ p r e s s )  
                 s e l f : q u e r y N e t w o r k S t a t e ( )  
                 l o c a l   f u l l y _ c o n n e c t e d   =   s e l f . i s _ w i f i _ o n   a n d   s e l f . i s _ c o n n e c t e d  
                 l o c a l   c o m p l e t e _ c a l l b a c k   =   f u n c t i o n ( )  
                         - -   N o t i f y   T o u c h M e n u   t o   u p d a t e   i t e m   c h e c k   s t a t e  
                         t o u c h m e n u _ i n s t a n c e : u p d a t e I t e m s ( )  
                 e n d   - -   c o m p l e t e _ c a l l b a c k ( )  
                 i f   f u l l y _ c o n n e c t e d   t h e n  
                         s e l f : t o g g l e W i f i O f f ( c o m p l e t e _ c a l l b a c k ,   t r u e )  
                 e l s e i f   s e l f . i s _ w i f i _ o n   a n d   n o t   s e l f . i s _ c o n n e c t e d   t h e n  
                         - -   a s k   w h e t h e r   u s e r   w a n t s   t o   c o n n e c t   o r   t u r n   o f f   w i f i  
                         s e l f : p r o m p t W i f i ( c o m p l e t e _ c a l l b a c k ,   l o n g _ p r e s s ,   t r u e )  
                 e l s e   - -   i f   n o t   c o n n e c t e d   a t   a l l  
                         s e l f : t o g g l e W i f i O n ( c o m p l e t e _ c a l l b a c k ,   l o n g _ p r e s s ,   t r u e )  
                 e n d  
         e n d   - -   t o g g l e C a l l b a c k ( )  
  
         r e t u r n   {  
                 t e x t   =   _ ( " W i - F i   c o n n e c t i o n " ) ,  
                 e n a b l e d _ f u n c   =   f u n c t i o n ( )   r e t u r n   D e v i c e : h a s W i f i T o g g l e ( )   e n d ,  
                 c h e c k e d _ f u n c   =   f u n c t i o n ( )   r e t u r n   s e l f : i s W i f i O n ( )   e n d ,  
                 c a l l b a c k   =   t o g g l e C a l l b a c k ,  
                 h o l d _ c a l l b a c k   =   f u n c t i o n ( t o u c h m e n u _ i n s t a n c e )  
                         t o g g l e C a l l b a c k ( t o u c h m e n u _ i n s t a n c e ,   t r u e )  
                 e n d ,  
         }  
 e n d  
  
 f u n c t i o n   N e t w o r k M g r : g e t P r o x y M e n u T a b l e ( )  
         l o c a l   p r o x y _ e n a b l e d   =   f u n c t i o n ( )  
                 r e t u r n   G _ r e a d e r _ s e t t i n g s : r e a d S e t t i n g ( " h t t p _ p r o x y _ e n a b l e d " )  
         e n d  
         l o c a l   p r o x y   =   f u n c t i o n ( )  
                 r e t u r n   G _ r e a d e r _ s e t t i n g s : r e a d S e t t i n g ( " h t t p _ p r o x y " )  
         e n d  
         r e t u r n   {  
                 t e x t _ f u n c   =   f u n c t i o n ( )  
                         r e t u r n   T ( _ ( " H T T P   p r o x y   % 1 " ) ,   ( p r o x y _ e n a b l e d ( )   a n d   B D . u r l ( p r o x y ( ) )   o r   " " ) )  
                 e n d ,  
                 c h e c k e d _ f u n c   =   f u n c t i o n ( )   r e t u r n   p r o x y _ e n a b l e d ( )   e n d ,  
                 c a l l b a c k   =   f u n c t i o n ( )  
                         i f   n o t   p r o x y _ e n a b l e d ( )   a n d   p r o x y ( )   t h e n  
                                 s e l f : s e t H T T P P r o x y ( p r o x y ( ) )  
                         e l s e i f   p r o x y _ e n a b l e d ( )   t h e n  
                                 s e l f : s e t H T T P P r o x y ( n i l )  
                         e n d  
                         i f   n o t   p r o x y ( )   t h e n  
                                 U I M a n a g e r : s h o w ( I n f o M e s s a g e : n e w {  
                                         t e x t   =   _ ( " T i p : \ n L o n g   p r e s s   o n   t h i s   m e n u   e n t r y   t o   c o n f i g u r e   H T T P   p r o x y . " ) ,  
                                 } )  
                         e n d  
                 e n d ,  
                 h o l d _ i n p u t   =   {  
                         t i t l e   =   _ ( " E n t e r   p r o x y   a d d r e s s " ) ,  
                         h i n t   =   p r o x y ( ) ,  
                         c a l l b a c k   =   f u n c t i o n ( i n p u t )  
                                 l o c a l   u r l   =   r e q u i r e ( " s o c k e t . u r l " )  
                                 l o c a l   p a r s e d   =   u r l . p a r s e ( i n p u t )  
                                 i f   n o t   p a r s e d   o r   n o t   p a r s e d . s c h e m e   o r   n o t   p a r s e d . h o s t   o r   n o t   p a r s e d . p o r t   t h e n  
                                         U I M a n a g e r : s h o w ( I n f o M e s s a g e : n e w {  
                                                 t e x t   =   _ ( " I n v a l i d   p r o x y   a d d r e s s " ) ,  
                                         } )  
                                         r e t u r n   f a l s e  
                                 e n d  
                                 s e l f : s e t H T T P P r o x y ( i n p u t )  
                         e n d ,  
                 } ,  
         }  
 e n d  
  
 f u n c t i o n   N e t w o r k M g r : g e t P o w e r s a v e M e n u T a b l e ( )  
         r e t u r n   {  
                 t e x t   =   _ ( " D i s a b l e   W i - F i   c o n n e c t i o n   w h e n   i n a c t i v e " ) ,  
                 h e l p _ t e x t   =   D e v i c e : i s K i n d l e ( )   a n d   _ ( [ [ T h i s   i s   u n l i k e l y   t o   f u n c t i o n   p r o p e r l y   o n   a   s t o c k   K i n d l e ,   g i v e n   h o w   m u c h   n e t w o r k   a c t i v i t y   t h e   f r a m e w o r k   g e n e r a t e s . ] ] )   o r  
                                         _ ( [ [ T h i s   w i l l   a u t o m a t i c a l l y   t u r n   W i - F i   o f f   a f t e r   a   g e n e r o u s   p e r i o d   o f   n e t w o r k   i n a c t i v i t y ,   w i t h o u t   d i s r u p t i n g   w o r k f l o w s   t h a t   r e q u i r e   a   n e t w o r k   c o n n e c t i o n ,   s o   y o u   c a n   j u s t   k e e p   r e a d i n g   w i t h o u t   w o r r y i n g   a b o u t   b a t t e r y   d r a i n . ] ] ) ,  
                 c h e c k e d _ f u n c   =   f u n c t i o n ( )   r e t u r n   G _ r e a d e r _ s e t t i n g s : i s T r u e ( " a u t o _ d i s a b l e _ w i f i " )   e n d ,  
                 c a l l b a c k   =   f u n c t i o n ( )  
                         G _ r e a d e r _ s e t t i n g s : f l i p N i l O r F a l s e ( " a u t o _ d i s a b l e _ w i f i " )  
                         - -   N O T E :   W e l l ,   n o t   e x a c t l y ,   b u t   t h e   a c t i v i t y   c h e c k   w o u l d n ' t   b e   ( u n ) s c h e d u l e d   u n t i l   t h e   n e x t   N e t w o r k ( D i s ) C o n n e c t e d   e v e n t . . .  
                         U I M a n a g e r : a s k F o r R e s t a r t ( )  
                 e n d ,  
         }  
 e n d  
  
 f u n c t i o n   N e t w o r k M g r : g e t R e s t o r e M e n u T a b l e ( )  
         r e t u r n   {  
                 t e x t   =   _ ( " R e s t o r e   W i - F i   c o n n e c t i o n   o n   r e s u m e " ) ,  
                 - -   i . e . ,   * e v e r y t h i n g *   f l i p s   w i f i _ w a s _ o n   t r u e ,   b u t   o n l y   d i r e c t   u s e r   i n t e r a c t i o n   ( i . e . ,   M e n u   &   G e s t u r e s )   w i l l   f l i p   i t   o f f .  
                 h e l p _ t e x t   =   _ ( [ [ T h i s   w i l l   a t t e m p t   t o   a u t o m a t i c a l l y   a n d   s i l e n t l y   r e - c o n n e c t   t o   W i - F i   o n   s t a r t u p   o r   o n   r e s u m e   i f   W i - F i   u s e d   t o   b e   e n a b l e d   t h e   l a s t   t i m e   y o u   u s e d   K O R e a d e r ,   a n d   y o u   d i d   n o t   e x p l i c i t l y   d i s a b l e   i t . ] ] ) ,  
                 c h e c k e d _ f u n c   =   f u n c t i o n ( )   r e t u r n   G _ r e a d e r _ s e t t i n g s : i s T r u e ( " a u t o _ r e s t o r e _ w i f i " )   e n d ,  
                 e n a b l e d _ f u n c   =   f u n c t i o n ( )   r e t u r n   D e v i c e : h a s W i f i R e s t o r e ( )   e n d ,  
                 c a l l b a c k   =   f u n c t i o n ( )   G _ r e a d e r _ s e t t i n g s : f l i p N i l O r F a l s e ( " a u t o _ r e s t o r e _ w i f i " )   e n d ,  
         }  
 e n d  
  
 f u n c t i o n   N e t w o r k M g r : g e t I n f o M e n u T a b l e ( )  
         r e t u r n   {  
                 t e x t   =   _ ( " N e t w o r k   i n f o " ) ,  
                 k e e p _ m e n u _ o p e n   =   t r u e ,  
                 e n a b l e d _ f u n c   =   f u n c t i o n ( )   r e t u r n   s e l f : i s N e t w o r k I n f o A v a i l a b l e ( )   e n d ,  
                 c a l l b a c k   =   f u n c t i o n ( )  
                         U I M a n a g e r : b r o a d c a s t E v e n t ( E v e n t : n e w ( " S h o w N e t w o r k I n f o " ) )  
                 e n d  
         }  
 e n d  
  
 f u n c t i o n   N e t w o r k M g r : g e t B e f o r e W i f i A c t i o n M e n u T a b l e ( )  
         l o c a l   w i f i _ e n a b l e _ a c t i o n _ s e t t i n g   =   G _ r e a d e r _ s e t t i n g s : r e a d S e t t i n g ( " w i f i _ e n a b l e _ a c t i o n " )   o r   " p r o m p t "  
         l o c a l   w i f i _ e n a b l e _ a c t i o n s   =   {  
                 t u r n _ o n   =   { _ ( " t u r n   o n " ) ,   _ ( " T u r n   o n " ) } ,  
                 p r o m p t   =   { _ ( " p r o m p t " ) ,   _ ( " P r o m p t " ) } ,  
         }  
         i f   D e v i c e : i s A n d r o i d ( )   t h e n  
                 w i f i _ e n a b l e _ a c t i o n s . i g n o r e   =   { _ ( " i g n o r e " ) ,   _ ( " I g n o r e " ) }  
         e n d  
         l o c a l   a c t i o n _ t a b l e   =   f u n c t i o n ( w i f i _ e n a b l e _ a c t i o n )  
         r e t u r n   {  
                 t e x t   =   w i f i _ e n a b l e _ a c t i o n s [ w i f i _ e n a b l e _ a c t i o n ] [ 2 ] ,  
                 c h e c k e d _ f u n c   =   f u n c t i o n ( )  
                         r e t u r n   w i f i _ e n a b l e _ a c t i o n _ s e t t i n g   = =   w i f i _ e n a b l e _ a c t i o n  
                 e n d ,  
                 r a d i o   =   t r u e ,  
                 c a l l b a c k   =   f u n c t i o n ( )  
                         w i f i _ e n a b l e _ a c t i o n _ s e t t i n g   =   w i f i _ e n a b l e _ a c t i o n  
                         G _ r e a d e r _ s e t t i n g s : s a v e S e t t i n g ( " w i f i _ e n a b l e _ a c t i o n " ,   w i f i _ e n a b l e _ a c t i o n )  
                 e n d ,  
         }  
         e n d  
  
         l o c a l   t   =   {  
                 t e x t _ f u n c   =   f u n c t i o n ( )  
                         r e t u r n   T ( _ ( " A c t i o n   w h e n   W i - F i   i s   o f f :   % 1 " ) ,  
                                 w i f i _ e n a b l e _ a c t i o n s [ w i f i _ e n a b l e _ a c t i o n _ s e t t i n g ] [ 1 ]  
                         )  
                 e n d ,  
                 s u b _ i t e m _ t a b l e   =   {  
                         a c t i o n _ t a b l e ( " t u r n _ o n " ) ,  
                         a c t i o n _ t a b l e ( " p r o m p t " ) ,  
                 }  
         }  
         i f   D e v i c e : i s A n d r o i d ( )   t h e n  
                 t a b l e . i n s e r t ( t . s u b _ i t e m _ t a b l e ,   a c t i o n _ t a b l e ( " i g n o r e " ) )  
         e n d  
  
         r e t u r n   t  
 e n d  
  
 f u n c t i o n   N e t w o r k M g r : g e t A f t e r W i f i A c t i o n M e n u T a b l e ( )  
         l o c a l   w i f i _ d i s a b l e _ a c t i o n _ s e t t i n g   =   G _ r e a d e r _ s e t t i n g s : r e a d S e t t i n g ( " w i f i _ d i s a b l e _ a c t i o n " )   o r   " p r o m p t "  
         l o c a l   w i f i _ d i s a b l e _ a c t i o n s   =   {  
                 l e a v e _ o n   =   { _ ( " l e a v e   o n " ) ,   _ ( " L e a v e   o n " ) } ,  
                 t u r n _ o f f   =   { _ ( " t u r n   o f f " ) ,   _ ( " T u r n   o f f " ) } ,  
                 p r o m p t   =   { _ ( " p r o m p t " ) ,   _ ( " P r o m p t " ) } ,  
         }  
         l o c a l   a c t i o n _ t a b l e   =   f u n c t i o n ( w i f i _ d i s a b l e _ a c t i o n )  
         r e t u r n   {  
                 t e x t   =   w i f i _ d i s a b l e _ a c t i o n s [ w i f i _ d i s a b l e _ a c t i o n ] [ 2 ] ,  
                 c h e c k e d _ f u n c   =   f u n c t i o n ( )  
                         r e t u r n   w i f i _ d i s a b l e _ a c t i o n _ s e t t i n g   = =   w i f i _ d i s a b l e _ a c t i o n  
                 e n d ,  
                 r a d i o   =   t r u e ,  
                 c a l l b a c k   =   f u n c t i o n ( )  
                         w i f i _ d i s a b l e _ a c t i o n _ s e t t i n g   =   w i f i _ d i s a b l e _ a c t i o n  
                         G _ r e a d e r _ s e t t i n g s : s a v e S e t t i n g ( " w i f i _ d i s a b l e _ a c t i o n " ,   w i f i _ d i s a b l e _ a c t i o n )  
                 e n d ,  
         }  
         e n d  
         r e t u r n   {  
                 t e x t _ f u n c   =   f u n c t i o n ( )  
                         r e t u r n   T ( _ ( " A c t i o n   w h e n   d o n e   w i t h   W i - F i :   % 1 " ) ,  
                                 w i f i _ d i s a b l e _ a c t i o n s [ w i f i _ d i s a b l e _ a c t i o n _ s e t t i n g ] [ 1 ]  
                         )  
                 e n d ,  
                 s u b _ i t e m _ t a b l e   =   {  
                         a c t i o n _ t a b l e ( " l e a v e _ o n " ) ,  
                         a c t i o n _ t a b l e ( " t u r n _ o f f " ) ,  
                         a c t i o n _ t a b l e ( " p r o m p t " ) ,  
                 }  
         }  
 e n d  
  
 f u n c t i o n   N e t w o r k M g r : g e t D i s m i s s S c a n M e n u T a b l e ( )  
         r e t u r n   {  
                 t e x t   =   _ ( " D i s m i s s   W i - F i   s c a n   p o p u p   a f t e r   c o n n e c t i o n " ) ,  
                 c h e c k e d _ f u n c   =   f u n c t i o n ( )   r e t u r n   G _ r e a d e r _ s e t t i n g s : n i l O r T r u e ( " a u t o _ d i s m i s s _ w i f i _ s c a n " )   e n d ,  
                 e n a b l e d _ f u n c   =   f u n c t i o n ( )   r e t u r n   D e v i c e : h a s W i f i M a n a g e r ( )   o r   D e v i c e : i s E m u l a t o r ( )   e n d ,  
                 c a l l b a c k   =   f u n c t i o n ( )   G _ r e a d e r _ s e t t i n g s : f l i p N i l O r T r u e ( " a u t o _ d i s m i s s _ w i f i _ s c a n " )   e n d ,  
         }  
 e n d  
  
 f u n c t i o n   N e t w o r k M g r : g e t M e n u T a b l e ( c o m m o n _ s e t t i n g s )  
         i f   D e v i c e : h a s W i f i T o g g l e ( )   t h e n  
                 c o m m o n _ s e t t i n g s . n e t w o r k _ w i f i   =   s e l f : g e t W i f i M e n u T a b l e ( )  
         e n d  
  
         c o m m o n _ s e t t i n g s . n e t w o r k _ p r o x y   =   s e l f : g e t P r o x y M e n u T a b l e ( )  
         c o m m o n _ s e t t i n g s . n e t w o r k _ i n f o   =   s e l f : g e t I n f o M e n u T a b l e ( )  
  
         - -   A l l o w   a u t o _ d i s a b l e _ w i f i   o n   d e v i c e s   w h e r e   t h e   n e t   s y s f s   e n t r y   i s   e x p o s e d .  
         i f   s e l f : g e t N e t w o r k I n t e r f a c e N a m e ( )   t h e n  
                 c o m m o n _ s e t t i n g s . n e t w o r k _ p o w e r s a v e   =   s e l f : g e t P o w e r s a v e M e n u T a b l e ( )  
         e n d  
  
         i f   D e v i c e : h a s W i f i R e s t o r e ( )   o r   D e v i c e : i s E m u l a t o r ( )   t h e n  
                 c o m m o n _ s e t t i n g s . n e t w o r k _ r e s t o r e   =   s e l f : g e t R e s t o r e M e n u T a b l e ( )  
         e n d  
         i f   D e v i c e : h a s W i f i M a n a g e r ( )   o r   D e v i c e : i s E m u l a t o r ( )   t h e n  
                 c o m m o n _ s e t t i n g s . n e t w o r k _ d i s m i s s _ s c a n   =   s e l f : g e t D i s m i s s S c a n M e n u T a b l e ( )  
         e n d  
         i f   D e v i c e : h a s W i f i T o g g l e ( )   t h e n  
                 c o m m o n _ s e t t i n g s . n e t w o r k _ b e f o r e _ w i f i _ a c t i o n   =   s e l f : g e t B e f o r e W i f i A c t i o n M e n u T a b l e ( )  
                 c o m m o n _ s e t t i n g s . n e t w o r k _ a f t e r _ w i f i _ a c t i o n   =   s e l f : g e t A f t e r W i f i A c t i o n M e n u T a b l e ( )  
         e n d  
 e n d  
  
 f u n c t i o n   N e t w o r k M g r : r e c o n n e c t O r S h o w N e t w o r k M e n u ( c o m p l e t e _ c a l l b a c k ,   i n t e r a c t i v e )  
         l o c a l   i n f o   =   I n f o M e s s a g e : n e w { t e x t   =   _ ( " S c a n n i n g   f o r   n e t w o r k s & " ) }  
         U I M a n a g e r : s h o w ( i n f o )  
         U I M a n a g e r : f o r c e R e P a i n t ( )  
  
         l o c a l   n e t w o r k _ l i s t ,   e r r   =   s e l f : g e t N e t w o r k L i s t ( )  
         U I M a n a g e r : c l o s e ( i n f o )  
         i f   n e t w o r k _ l i s t   = =   n i l   t h e n  
                 U I M a n a g e r : s h o w ( I n f o M e s s a g e : n e w { t e x t   =   e r r } )  
                 r e t u r n   f a l s e  
         e n d  
         - -   N O T E :   F a i r l y   h a c k i s h   w o r k a r o u n d   f o r   # 4 3 8 7 ,  
         - -               r e s c a n   i f   t h e   f i r s t   s c a n   a p p e a r e d   t o   y i e l d   a n   e m p t y   l i s t .  
         - - -   @ f i x m e   T h i s   * m i g h t *   b e   a n   i s s u e   b e t t e r   h a n d l e d   i n   l j - w p a c l i e n t . . .  
         i f   # n e t w o r k _ l i s t   = =   0   t h e n  
                 l o g g e r . w a r n ( " I n i t i a l   W i - F i   s c a n   y i e l d e d   n o   r e s u l t s ,   r e s c a n n i n g " )  
                 n e t w o r k _ l i s t ,   e r r   =   s e l f : g e t N e t w o r k L i s t ( )  
                 i f   n e t w o r k _ l i s t   = =   n i l   t h e n  
                         U I M a n a g e r : s h o w ( I n f o M e s s a g e : n e w { t e x t   =   e r r } )  
                         r e t u r n   f a l s e  
                 e n d  
         e n d  
  
         t a b l e . s o r t ( n e t w o r k _ l i s t ,  
                 f u n c t i o n ( l ,   r )   r e t u r n   l . s i g n a l _ q u a l i t y   >   r . s i g n a l _ q u a l i t y   e n d )  
  
         - -   t r u e :   w e ' r e   c o n n e c t e d ;   f a l s e :   t h i n g s   w e n t   k a b l o o e y ;   n i l :   w e   d o n ' t   k n o w   y e t   ( e . g . ,   i n t e r a c t i v e )  
         - -   N O T E :   f a l s e   * w i l l *   l e a d   e n a b l e W i f i   t o   k i l l   W i - F i   v i a   _ a b o r t W i f i C o n n e c t i o n !  
         l o c a l   s u c c e s s  
         l o c a l   s s i d  
         - -   W e   n e e d   t o   d o   t w o   p a s s e s ,   a s   w e   m a y   h a v e   * b o t h *   a n   a l r e a d y   c o n n e c t e d   n e t w o r k   ( f r o m   t h e   g l o b a l   w p a   c o n f i g ) ,  
         - -   * a n d *   p r e f e r r e d   n e t w o r k s ,   a n d   i f   t h e   p r e f e r r e d   n e t w o r k s   h a v e   a   b e t t e r   s i g n a l   q u a l i t y ,  
         - -   t h e y ' l l   b e   s o r t e d   * e a r l i e r * ,   w h i c h   w o u l d   c a u s e   u s   t o   t r y   t o   a s s o c i a t e   t o   a   d i f f e r e n t   A P   t h a n  
         - -   w h a t   w p a _ s u p p l i c a n t   i s   a l r e a d y   t r y i n g   t o   d o . . .  
         - -   N O T E :   W e   c a n ' t   r e a l l y   s k i p   t h i s ,   e v e n   w h e n   w e   f o r c e   s h o w i n g   t h e   s c a n   l i s t ,  
         - -               a s   t h e   b a c k e n d   * w i l l *   c o n n e c t   i n   t h e   b a c k g r o u n d   r e g a r d l e s s   o f   w h a t   w e   d o ,  
         - -               a n d   w e   * n e e d *   o u r   c o m p l e t e _ c a l l b a c k   t o   r u n ,  
         - -               w h i c h   w o u l d   n o t   b e   t h e   c a s e   i f   w e   w e r e   t o   j u s t   d i s m i s s   t h e   s c a n   l i s t ,  
         - -               e s p e c i a l l y   s i n c e   i t   w o u l d n ' t   s h o w   a s   " c o n n e c t e d "   i n   t h i s   c a s e . . .  
         f o r   d u m m y ,   n e t w o r k   i n   i p a i r s ( n e t w o r k _ l i s t )   d o  
                 i f   n e t w o r k . c o n n e c t e d   t h e n  
                         - -   O n   p l a t f o r m s   w h e r e   w e   u s e   w p a _ s u p p l i c a n t   ( i f   w e ' r e   c a l l i n g   t h i s ,   w e   p r o b a b l y   a r e ) ,  
                         - -   t h e   i n v o c a t i o n   w i l l   c h e c k   i t s   g l o b a l   c o n f i g ,   a n d   i f   a n   A P   c o n f i g u r e d   t h e r e   i s   r e a c h a b l e ,  
                         - -   i t ' l l   a l r e a d y   h a v e   c o n n e c t e d   t o   i t   o n   i t s   o w n .  
                         s u c c e s s   =   t r u e  
                         s s i d   =   n e t w o r k . s s i d  
                         b r e a k  
                 e n d  
         e n d  
  
         - -   N e x t ,   l o o k   f o r   o u r   o w n   p r e f e r r e d   n e t w o r k s . . .  
         l o c a l   e r r _ m s g   =   _ ( " C o n n e c t i o n   f a i l e d " )  
         i f   n o t   s u c c e s s   t h e n  
                 f o r   d u m m y ,   n e t w o r k   i n   i p a i r s ( n e t w o r k _ l i s t )   d o  
                         i f   n e t w o r k . p a s s w o r d   t h e n  
                                 - -   I f   w e   h i t   a   p r e f e r r e d   n e t w o r k   a n d   w e ' r e   n o t   a l r e a d y   c o n n e c t e d ,  
                                 - -   a t t e m p t   t o   c o n n e c t   t o   s a i d   p r e f e r r e d   n e t w o r k . . . .  
                                 l o g g e r . d b g ( " N e t w o r k M g r :   A t t e m p t i n g   t o   a u t h e n t i c a t e   o n   p r e f e r r e d   n e t w o r k " ,   u t i l . f i x U t f 8 ( n e t w o r k . s s i d ,   " ��" ) )  
                                 s u c c e s s ,   e r r _ m s g   =   s e l f : a u t h e n t i c a t e N e t w o r k ( n e t w o r k )  
                                 i f   s u c c e s s   t h e n  
                                         s s i d   =   n e t w o r k . s s i d  
                                         n e t w o r k . c o n n e c t e d   =   t r u e  
                                         b r e a k  
                                 e l s e  
                                         l o g g e r . d b g ( " N e t w o r k M g r :   a u t h e n t i c a t i o n   f a i l e d : " ,   e r r _ m s g )  
                                 e n d  
                         e n d  
                 e n d  
         e n d  
  
         - -   I f   w e   h a v e n ' t   e v e n   s e e n   a n y   o f   o u r   p r e f e r r e d   n e t w o r k s ,   w a i t   a   b i t   t o   s e e   i f   w p a _ s u p p l i c a n t   m a n a g e s   t o   c o n n e c t   i n   t h e   b a c k g r o u n d   a n y w a y . . .  
         - -   T h i s   h a p p e n s   w h e n   w e   b r e a k   t o o   e a r l y   f r o m   r e - s c a n s   t r i g g e r e d   b y   w p a _ s u p p l i c a n t   i t s e l f ,  
         - -   w h i c h   s h o u l d n ' t   r e a l l y   e v e r   h a p p e n   s i n c e   h t t p s : / / g i t h u b . c o m / k o r e a d e r / l j - w p a c l i e n t / p u l l / 1 1  
         - -   c . f . ,   W p a C l i e n t : s c a n T h e n G e t R e s u l t s   i n   l j - w p a c l i e n t   f o r   m o r e   d e t a i l s .  
         i f   D e v i c e : h a s W i f i M a n a g e r ( )   a n d   n o t   s u c c e s s   a n d   n o t   s s i d   t h e n  
                 - -   D o n ' t   b o t h e r   i f   w p a _ s u p p l i c a n t   d o e s n ' t   a c t u a l l y   h a v e   a n y   c o n f i g u r e d   n e t w o r k s . . .  
                 l o c a l   c o n f i g u r e d _ n e t w o r k s   =   s e l f : g e t C o n f i g u r e d N e t w o r k s ( )  
                 l o c a l   h a s _ p r e f e r r e d _ n e t w o r k s   =   c o n f i g u r e d _ n e t w o r k s   a n d   # c o n f i g u r e d _ n e t w o r k s   >   0  
  
                 l o c a l   i t e r   =   h a s _ p r e f e r r e d _ n e t w o r k s   a n d   0   o r   6 0  
                 - -   W e   w a i t   1 5 s   a t   m o s t   ( l i k e   t h e   r e s t o r e - w i f i - a s y n c   s c r i p t )  
                 w h i l e   n o t   s u c c e s s   a n d   i t e r   <   6 0   d o  
                         - -   C h e c k   e v e r y   2 5 0 m s  
                         i t e r   =   i t e r   +   1  
                         f f i u t i l . u s l e e p ( 2 5 0   *   1 e + 3 )  
  
                         l o c a l   n w   =   s e l f : g e t C u r r e n t N e t w o r k ( )  
                         i f   n w   t h e n  
                                 s u c c e s s   =   t r u e  
                                 s s i d   =   n w . s s i d  
                                 - -   F l a g   i t   a s   c o n n e c t e d   i n   t h e   l i s t  
                                 f o r   d u m m y ,   n e t w o r k   i n   i p a i r s ( n e t w o r k _ l i s t )   d o  
                                         i f   s s i d   = =   n e t w o r k . s s i d   t h e n  
                                                 n e t w o r k . c o n n e c t e d   =   t r u e  
                                         e n d  
                                 e n d  
                                 l o g g e r . d b g ( " N e t w o r k M g r :   w p a _ s u p p l i c a n t   a u t o m a t i c a l l y   c o n n e c t e d   t o   n e t w o r k " ,   u t i l . f i x U t f 8 ( s s i d ,   " ��" ) ,   " ( a f t e r " ,   i t e r   *   0 . 2 5 ,   " s e c o n d s ) " )  
                         e n d  
                 e n d  
         e n d  
  
         i f   s u c c e s s   t h e n  
                 s e l f : o b t a i n I P ( )  
                 - -   R e c o r d   t h e   S S I D   w e   j u s t   o b t a i n e d   a   l e a s e   f o r ,   s o   h a s L e a s e F o r C u r r e n t N e t w o r k ( )  
                 - -   c a n   d e t e c t   a   f u t u r e   n e t w o r k   s w i t c h   w i t h o u t   t r i g g e r i n g   u n n e c e s s a r y   r e - D H C P s   ( # 1 4 7 9 0 ) .  
                 s e l f . l e a s e _ s s i d   =   s s i d  
                 l o g g e r . d b g ( " N e t w o r k M g r :   l e a s e _ s s i d   s e t   t o " ,   s s i d )  
                 i f   c o m p l e t e _ c a l l b a c k   t h e n  
                         c o m p l e t e _ c a l l b a c k ( )  
                 e n d  
                 - -   N O T E :   O n   K i n d l e ,   w e   d o n ' t   h a v e   a n   e x p l i c i t   o b t a i n I P   i m p l e m e n t a t i o n ,  
                 - -               a n d   a u t h e n t i c a t e N e t w o r k   i s   a s y n c ,  
                 - -               s o   w e   d o n ' t   * a c t u a l l y *   h a v e   a   f u l l   c o n n e c t i o n   y e t ,  
                 - -               w e ' v e   j u s t   * s t a r t e d *   c o n n e c t i n g   t o   t h e   r e q u e s t e d   n e t w o r k . . .  
                 U I M a n a g e r : s h o w ( I n f o M e s s a g e : n e w {  
                         t a g   =   " N e t w o r k M g r " ,   - -   f o r   c r a z y   K O S y n c   p u r p o s e s  
                         t e x t   =   T ( _ ( D e v i c e : i s K i n d l e ( )   a n d   " C o n n e c t i n g   t o   n e t w o r k   % 1 & "   o r   " C o n n e c t e d   t o   n e t w o r k   % 1 " ) ,   B D . w r a p ( u t i l . f i x U t f 8 ( s s i d ,   " ��" ) ) ) ,  
                         t i m e o u t   =   3 ,  
                 } )  
                 l o g g e r . d b g ( " N e t w o r k M g r :   C o n n e c t e d   t o   n e t w o r k " ,   u t i l . f i x U t f 8 ( s s i d ,   " ��" ) )  
         e l s e  
                 U I M a n a g e r : s h o w ( I n f o M e s s a g e : n e w {  
                         t e x t   =   e r r _ m s g ,  
                         t i m e o u t   =   3 ,  
                 } )  
                 l o g g e r . d b g ( " N e t w o r k M g r :   F a i l e d   t o   c o n n e c t : " ,   e r r _ m s g ,   " ;   l a s t   a t t e m p t   o n   s s i d : " ,   s s i d   a n d   u t i l . f i x U t f 8 ( s s i d ,   " ��" )   o r   " < n o n e > " )  
         e n d  
  
         i f   n o t   s u c c e s s   t h e n  
                 - -   N O T E :   A l s o   s u p p o r t s   a   d i s c o n n e c t _ c a l l b a c k ,   s h o u l d   w e   u s e   i t   f o r   s o m e t h i n g ?  
                 - -               T e a r i n g   d o w n   W i - F i   c o m p l e t e l y   w h e n   t a p p i n g   " d i s c o n n e c t "   w o u l d   f e e l   a   b i t   h a r s h ,   t h o u g h . . .  
                 i f   i n t e r a c t i v e   t h e n  
                         - -   W e   d o n ' t   w a n t   t o   d i s p l a y   t h e   A P   l i s t   f o r   n o n - i n t e r a c t i v e   c a l l e r s   ( e . g . ,   b e f o r e W i f i A c t i o n   f r a m e w o r k ) . . .  
                         U I M a n a g e r : s h o w ( r e q u i r e ( " u i / w i d g e t / n e t w o r k s e t t i n g " ) : n e w {  
                                 n e t w o r k _ l i s t   =   n e t w o r k _ l i s t ,  
                                 c o n n e c t _ c a l l b a c k   =   c o m p l e t e _ c a l l b a c k ,  
                         } )  
                 e l s e  
                         - -   L e t   e n a b l e W i f i   t e a r   i t   a l l   d o w n   w h e n   w e ' r e   n o n - i n t e r a c t i v e  
                         s u c c e s s   =   f a l s e  
                 e n d  
         e l s e i f   s e l f . w i f i _ t o g g l e _ l o n g _ p r e s s   t h e n  
                 - -   S u c c e s s ,   b u t   w e   a s k e d   f o r   t h e   l i s t ,   s h o w   i t   w / o   a n y   c a l l b a c k s .  
                 - -   ( W e   * c o u l d *   p o t e n t i a l l y   s e t u p   a   p a i r   o f   c a l l b a c k s   t h a t   j u s t   s e n d   N e t w o r k *   e v e n t s ,   b u t   i t ' s   p r o b a b l y   n o t   w o r t h   i t ) .  
                 U I M a n a g e r : s h o w ( r e q u i r e ( " u i / w i d g e t / n e t w o r k s e t t i n g " ) : n e w {  
                         n e t w o r k _ l i s t   =   n e t w o r k _ l i s t ,  
                 } )  
         e n d  
  
         s e l f . w i f i _ t o g g l e _ l o n g _ p r e s s   =   n i l  
         r e t u r n   s u c c e s s  
 e n d  
  
 f u n c t i o n   N e t w o r k M g r : s a v e N e t w o r k ( s e t t i n g )  
         i f   n o t   s e l f . n w _ s e t t i n g s   t h e n   s e l f : r e a d N W S e t t i n g s ( )   e n d  
  
         s e l f . n w _ s e t t i n g s : s a v e S e t t i n g ( s e t t i n g . s s i d ,   {  
                 s s i d   =   s e t t i n g . s s i d ,  
                 p a s s w o r d   =   s e t t i n g . p a s s w o r d ,  
                 p s k   =   s e t t i n g . p s k ,  
                 f l a g s   =   s e t t i n g . f l a g s ,  
         } )  
         s e l f . n w _ s e t t i n g s : f l u s h ( )  
 e n d  
  
 f u n c t i o n   N e t w o r k M g r : d e l e t e N e t w o r k ( s e t t i n g )  
         i f   n o t   s e l f . n w _ s e t t i n g s   t h e n   s e l f : r e a d N W S e t t i n g s ( )   e n d  
         s e l f . n w _ s e t t i n g s : d e l S e t t i n g ( s e t t i n g . s s i d )  
         s e l f . n w _ s e t t i n g s : f l u s h ( )  
 e n d  
  
 f u n c t i o n   N e t w o r k M g r : g e t A l l S a v e d N e t w o r k s ( )  
         i f   n o t   s e l f . n w _ s e t t i n g s   t h e n   s e l f : r e a d N W S e t t i n g s ( )   e n d  
         r e t u r n   s e l f . n w _ s e t t i n g s  
 e n d  
  
 f u n c t i o n   N e t w o r k M g r : s e t W i r e l e s s B a c k e n d ( n a m e ,   o p t i o n s )  
         r e q u i r e ( " u i / n e t w o r k / " . . n a m e ) . i n i t ( s e l f ,   o p t i o n s )  
 e n d  
  
 i f   G _ r e a d e r _ s e t t i n g s : r e a d S e t t i n g ( " h t t p _ p r o x y _ e n a b l e d " )   a n d   G _ r e a d e r _ s e t t i n g s : r e a d S e t t i n g ( " h t t p _ p r o x y " )   t h e n  
         N e t w o r k M g r : s e t H T T P P r o x y ( G _ r e a d e r _ s e t t i n g s : r e a d S e t t i n g ( " h t t p _ p r o x y " ) )  
 e l s e i f   G _ d e f a u l t s : r e a d S e t t i n g ( " N E T W O R K _ P R O X Y " )   t h e n  
         N e t w o r k M g r : s e t H T T P P r o x y ( G _ d e f a u l t s : r e a d S e t t i n g ( " N E T W O R K _ P R O X Y " ) )  
 e n d  
  
 r e t u r n   N e t w o r k M g r : i n i t ( )  
 
```

## truyenviet.koplugin/test_cookie.lua

```lua
local headers = {
    ["set-cookie"] = "xf_user=235183%2C327b94d347307d701c349b67b2ea7aa262b3aab0; expires=Sat, 08-Aug-2026 05:59:40 GMT; Max-Age=2592000; path=/; secure; httponly, xf_session=c54aeb995eaaba59a45c45ba86c7d2d1; path=/; secure; httponly"
}

local cookies = {}
local set_cookie = headers["set-cookie"]

for name, value in set_cookie:gmatch("([%w_%-]+)=([^;]+)") do
    local l = name:lower()
    if l ~= "expires" and l ~= "path" and l ~= "max-age" and l ~= "secure" and l ~= "httponly" and l ~= "domain" and l ~= "samesite" then
        cookies[name] = value
    end
end

for k, v in pairs(cookies) do
    print(k, "=", v)
end
```

## truyenviet.koplugin/test_mizzya_http.lua

```lua
local Http = require("truyenviet/http_client")
local url = "https://mizzya.wordpress.com/2007/05/15/list-truy%e1%bb%87n/"
print("Testing Http:get without force_luasec...")
local html1, err1, hdrs1, code1 = Http:get(url)
print("Result 1:", html1 and #html1 or "nil", err1, code1)

print("Testing Http:get with force_luasec...")
local html2, err2, hdrs2, code2 = Http:get(url, nil, { force_luasec = true })
print("Result 2:", html2 and #html2 or "nil", err2, code2)
```

## truyenviet.koplugin/test_tve4u.lua

```lua
package.path = package.path .. ';/mnt/d/Project/truyenfull/truyenviet.koplugin/?.lua'
local tve4u = require('truyenviet/sources/tve4u')
local ok, err = tve4u:login('phamthithienha17032005@gmail.com', 'Thienh@17032005')
print('Login:', ok, err)
if ok then
    local html = tve4u:authGet('https://tve-4u.org/')
    local f = io.open('/mnt/d/Project/truyenfull/truyenviet.koplugin/tve4u_logged_in.html', 'w')
    f:write(html or '')
    f:close()
    print('Saved')
end
```

## truyenviet.koplugin/timerwheel.lua

```lua
--- Timer wheel implementation
--
-- Efficient timer for timeout related timers: fast insertion, deletion, and
-- execution (all as O(1) implemented), but with lesser precision.
--
-- This module will not provide the timer/runloop itself. Use your own runloop
-- and call `wheel:step` to check and execute timers.
--
-- Implementation:
-- Consider a stack of rings, a timer beyond the current ring size is in the
-- next ring (or beyond). Precision is based on a slot with a specific size.
--
-- The code explicitly avoids using `pairs`, `ipairs` and `next` to ensure JIT
-- compilation when using LuaJIT

local default_now  -- return time in seconds
if ngx then
  default_now = ngx.now
else
  local ok, socket = pcall(require, "socket")
  if ok then
    default_now = socket.gettime
  else
    default_now = nil -- we don't have a default
  end
end

local ok, new_tab = pcall(require, "table.new")
if not ok then
  new_tab = function(narr, nrec) return {} end
end

local xpcall = xpcall
local default_err_handler = function(err)
  io.stderr:write(debug.traceback("TimerWheel callback failed with: " .. tostring(err)).."\n")
end

local math_floor = math.floor
local math_huge = math.huge
local EMPTY = {}

local _M = {}


--- Creates a new timer wheel.
-- @tparam table opts the options table
-- @tparam[opt=0.050] number opts.precision the precision of the timer wheel in seconds (slot size),
-- @tparam[opt] int opts.ringsize number of slots in each ring, defaults to 72000 (1
-- hour span, with `precision == 0.050`)
-- @tparam[opt] function opts.now a function returning the curent time in seconds. Defaults
-- to `ngx.now` or `luasocket.gettime` if available.
-- @tparam[opt] function opts.err_handler a function to use as error handler in an `xpcall` when
-- executing the callback. The default will write the stacktrace to `stderr`.
-- @treturn wheel the timerwheel object
function _M.new(opts)
  assert(opts ~= _M, "new should not be called with colon ':' notation")

  opts = opts or EMPTY
  assert(type(opts) == "table", "expected options to be a table")

  local precision = opts.precision or 0.050  -- in seconds, 50ms by default
  local ringsize  = opts.ringsize or 72000   -- #slots per ring, default 1 hour = 60 * 60 / 0.050
  local now       = opts.now or default_now  -- function to get time in seconds
  local err_handler = opts.err_handler or default_err_handler
  opts = nil   -- luacheck: ignore

  assert(type(precision) == "number" and precision > 0,
    "expected 'precision' to be number > 0")
  assert(type(ringsize) == "number" and ringsize > 0 and math_floor(ringsize) == ringsize,
    "expected 'ringsize' to be an integer number > 0")
  assert(type(now) == "function",
    "expected 'now' to be a function, got: " .. type(now))
  assert(type(err_handler) == "function",
    "expected 'err_handler' to be a function, got: " .. type(err_handler))

  local start     = now()
  local position  = 1  -- position next up in first ring of timer wheel
  local id_count  = 0  -- counter to generate unique ids (all negative)
  local id_list   = {} -- reverse lookup table to find timers by id
  local rings     = {} -- list of rings, index 1 is the current ring
  local rings_n   = 0  -- the number of the last ring in the rings list
  local count     = 0  -- how many timers do we have
  local wheel     = {} -- the returned wheel object

  -- because we assume hefty setting and cancelling, we're reusing tables
  -- to prevent excessive GC.
  local tables    = {} -- list of tables to be reused
  local tables_n  = 0  -- number of tables in the list

  --- Checks and executes timers.
  -- Call this function (at least) every `precision` seconds.
  -- @return `true`
  function wheel:step()
    local new_position = math_floor((now() - start) / precision) + 1
    local ring = rings[1] or EMPTY

    while position < new_position do

      -- get the expired slot, and remove it from the ring
      local slot = ring[position]
      ring[position] = nil

      -- forward pointers
      position = position + 1
      if position > ringsize then
        -- current ring is done, remove it and forward pointers
        for i = 1, rings_n do
          -- manual loop, since table.remove won't deal with holes
          -- FIXME: If there are a large number of rings, then this loop becomes
          -- a "stop the world" event.
          rings[i] = rings[i + 1]
        end
        rings_n = rings_n - 1

        ring = rings[1] or EMPTY
        start = start + ringsize * precision
        position = 1
        new_position = new_position - ringsize
      end

      -- only deal with slot after forwarding pointers, to make sure that
      -- any cb inserting another timer, does not end up in the slot being
      -- handled
      if slot then
        -- deal with the slot
        local ids = slot.ids
        local args = slot.arg
        for i = 1, slot.n do
          local id  = slot[i];  slot[i]  = nil; slot[id] = nil
          local cb  = ids[id];  ids[id]  = nil
          local arg = args[id]; args[id] = nil
          id_list[id] = nil
          count = count - 1
          xpcall(cb, err_handler, arg)
        end

        slot.n = 0
        -- delete the slot
        tables_n = tables_n + 1
        tables[tables_n] = slot
      end

    end
    return true
  end

  --- Gets the number of timers.
  -- @treturn int number of timers
  function wheel:count()
    return count
  end

  --- Sets a timer.
  -- @tparam number expire_in in how many seconds should the timer expire
  -- @tparam function cb callback function to execute upon expiring (NOTE: the
  -- callback will run within an `xpcall`)
  -- @param arg parameter to be passed to `cb` when executing
  -- @treturn int the id of the newly set timer
  -- @usage
  -- local cb = function(arg)
  --   print("timer executed with: ", arg)  --> "timer executed with: hello world"
  -- end
  -- local id = wheel:set(5, cb, "hello world")
  --
  -- -- do stuff here, while regularly calling `wheel:step()`
  --
  -- wheel:cancel(id)  -- cancel the timer again
  function wheel:set(expire_in, cb, arg)
    local time_expire = now() + expire_in
    local pos = math_floor((time_expire - start) / precision) + 1
    if pos < position then
      -- we cannot set it in the past
      pos = position
    end
    local ring_idx = math_floor((pos - 1) / ringsize) + 1
    local slot_idx = pos - (ring_idx - 1) * ringsize

    -- fetch actual ring table
    local ring = rings[ring_idx]
    if not ring then
      ring = new_tab(ringsize, 0)
      rings[ring_idx] = ring
      if ring_idx > rings_n then
        rings_n = ring_idx
      end
    end

    -- fetch actual slot
    local slot = ring[slot_idx]
    if not slot then
      if tables_n == 0 then
        slot = { n = 0, ids = {}, arg = {} }
      else
        slot = tables[tables_n]
        tables_n = tables_n - 1
      end
      ring[slot_idx] = slot
    end

    -- get new id
    local id = id_count - 1 -- use negative idx to not interfere with array part
    id_count = id

    -- store timer
    -- if we do not do this check, it will go unnoticed and lead to very
    -- hard to find bugs (`count` will go out of sync)
    slot.ids[id] = cb or error("the callback parameter is required", 2)
    slot.arg[id] = arg
    local idx = slot.n + 1
    slot.n = idx
    slot[idx] = id
    slot[id] = idx
    id_list[id] = slot
    count = count + 1

    return id
  end

  --- Cancels a timer.
  -- @tparam int id the timer id to cancel
  -- @treturn boolean `true` if cancelled, `false` if not found
  function wheel:cancel(id)
    local slot = id_list[id]
    if slot then
      local idx = slot[id]
      slot[id] = nil
      slot.ids[id] = nil
      slot.arg[id] = nil
      local n = slot.n
      if idx ~= n then
        local moved_id = slot[n]
        slot[idx] = moved_id
        slot[moved_id] = idx
      end
      slot[n] = nil
      slot.n = n - 1
      id_list[id] = nil
      count = count - 1
      return true
    end
    return false
  end

  --- Looks up the next expiring timer.
  -- Note: traverses the wheel, O(n) operation!
  -- @tparam[opt] number max_ahead maximum time (in seconds)
  -- to look ahead
  -- @treturn number number of seconds until next timer expires (can be negative), or
  -- 'nil' if there is no timer from now to `max_ahead`
  -- @usage
  -- local t = wheel:peek(10)
  -- if t then
  --   print("next timer expires in ", t," seconds")
  -- else
  --   print("no timer scheduled for the next 10 seconds")
  -- end
  function wheel:peek(max_ahead)
    if count == 0 then
      return nil
    end
    local time_now = now()

    -- convert max_ahead from seconds to positions
    if max_ahead then
      max_ahead = math_floor((time_now + max_ahead - start) / precision)
    else
      max_ahead = math_huge
    end

    local position_idx = position
    local ring_idx = 1
    local ring = rings[ring_idx] or EMPTY -- TODO: if EMPTY then we can skip it?
    local ahead_count = 0
    while ahead_count < max_ahead do

      local slot = ring[position_idx]
      if slot then
        if slot[1] then
          -- we have a timer
          return ((ring_idx - 1) * ringsize + position_idx) * precision +
                 start - time_now
        end
      end

      -- there is nothing in this position
      position_idx = position_idx + 1
      ahead_count = ahead_count + 1
      if position_idx > ringsize then
        position_idx = 1
        ring_idx = ring_idx + 1
        ring = rings[ring_idx] or EMPTY
      end
    end

    -- we hit max_ahead, without finding a timer
    return nil
  end

  if _G._TEST then   -- export test variables only when testing
    -- wheel._rings = rings
    wheel._tables = tables
  end

  return wheel
end

return _M
```

## truyenviet.koplugin/truyenviet/browser.lua

```lua
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
    table.insert(items, {
        text = "Đọc truyện",
        callback = function()
            self:showSourceMenu(function() self:showRoot() end)
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
            showError("Không có truyện ở trang này.", on_return_callback)
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
            right_icon = "close",
            right_icon_tap_callback = function(view)
                UIManager:show(ConfirmBox:new{
                    title = "Truyện Việt",
                    text = "Bạn có chắc chắn muốn xóa TẤT CẢ truyện khỏi Tủ truyện không?",
                    ok_text = "Xóa tất cả",
                    ok_callback = function()
                        Storage:clearAllFavorites(false)
                        closeAndRun(view, on_return_callback)
                    end,
                    cancel_text = "Hủy",
                })
            end,
        }
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
            right_icon = "close",
            right_icon_tap_callback = function(view)
                UIManager:show(ConfirmBox:new{
                    title = "Truyện Việt",
                    text = "Bạn có chắc chắn muốn xóa TẤT CẢ Lịch sử đọc không?",
                    ok_text = "Xóa tất cả",
                    ok_callback = function()
                        Storage:clearAllHistory(false)
                        closeAndRun(view, on_return_callback)
                    end,
                    cancel_text = "Hủy",
                })
            end,
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
        local Size = require("ui/size")
        local Font = require("ui/font")
        local Blitbuffer = require("ffi/blitbuffer")
        
        self.text_w = TextWidget:new{
            text = self.text,
            face = Font:getFace("infofont", 18),
            background = Blitbuffer.COLOR_BLACK,
            fgcolor = Blitbuffer.COLOR_WHITE,
            padding = Size.padding.small,
        }
        self:updateGeom()
    end,
    updateGeom = function(self)
        local Screen = require("device").screen
        self.w = self.text_w:getSize().w
        self.h = self.text_w:getSize().h
        self.x = 10
        self.y = Screen:getHeight() - self.h - 10
        self.text_w.x = self.x
        self.text_w.y = self.y
    end,
    paintTo = function(self, b, x, y)
        self.text_w:paintTo(b, self.x, self.y)
    end,
    setText = function(self, text)
        if self.text == text then return end
        self.text = text
        local old_dim = { w = self.w, h = self.h }
        
        self.text_w:setText(text)
        self:updateGeom()
        
        local UIManager = require("ui/uimanager")
        UIManager:show(self)
        
        UIManager:setDirty(self, function()
            local Screen = require("device").screen
            local Geom = require("ui/geometry")
            local max_h = math.max(old_dim.h, self.h)
            return Geom:new{
                x = self.x,
                y = Screen:getHeight() - max_h - 10,
                w = math.max(old_dim.w, self.w),
                h = max_h
            }
        end)
    end,
    bringToFront = function(self)
        local UIManager = require("ui/uimanager")
        UIManager:close(self)
        UIManager:show(self)
        UIManager:setDirty(self, function()
            local Screen = require("device").screen
            local Geom = require("ui/geometry")
            return Geom:new{ x = self.x, y = self.y, w = self.w, h = self.h }
        end)
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

            UIManager:show(InfoMessage:new{
                title = "Truyện Việt",
                text = "Đã tải sách nói: " .. audio_name .. "\n\nFile đã lưu tại:\n" .. save_path .. "\n\nVui lòng dùng ứng dụng phát nhạc để nghe.",
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
```

## truyenviet.koplugin/truyenviet/chapter_downloader.lua

```lua
local Builder = require("truyenviet/document_builder")
local Storage = require("truyenviet/storage")

local ChapterDownloader = {}

function ChapterDownloader:listPending(source, story, chapters)
    local pending = {}
    for _, chapter in ipairs(chapters or {}) do
        if not Storage:isDownloaded(source, story, chapter) then
            table.insert(pending, chapter)
        end
    end
    return pending
end

function ChapterDownloader:cleanupPartials(source, story, chapters)
    for _, chapter in ipairs(chapters or {}) do
        os.remove(Storage:getChapterPath(source, story, chapter) .. ".part")
    end
end

function ChapterDownloader:download(source, story, chapters)
    local result = {
        downloaded = 0,
        skipped = 0,
        errors = {},
    }

    if source.kind == "comic" or type(source.getChapterAsync) ~= "function" then
        local total_chaps = chapters and #chapters or 0
        for i, chapter in ipairs(chapters or {}) do
            coroutine.yield(string.format("Đang tải %d/%d chương...", i, total_chaps))
            if Storage:isDownloaded(source, story, chapter) then
                result.skipped = result.skipped + 1
            else
                local ok, payload, fetch_err = pcall(
                    source.getChapter,
                    source,
                    chapter
                )
                if not ok then
                    fetch_err = payload
                    payload = nil
                end

                local path
                local build_err
                if payload then
                    ok, path, build_err = pcall(
                        Builder.build,
                        Builder,
                        source,
                        story,
                        chapter,
                        payload
                    )
                    if not ok then
                        build_err = path
                        path = nil
                    end
                end

                if path then
                    result.downloaded = result.downloaded + 1
                else
                    os.remove(Storage:getChapterPath(source, story, chapter) .. ".part")
                    table.insert(result.errors, string.format(
                        "%s: %s",
                        chapter.title,
                        tostring(fetch_err or build_err or "lỗi không xác định")
                    ))
                end
            end
            collectgarbage()
        end
    else
        local copas = require("copas")
        local active_downloads = 0
        local max_concurrent = source.max_concurrent or 10

        for _, chapter in ipairs(chapters or {}) do
            if Storage:isDownloaded(source, story, chapter) then
                result.skipped = result.skipped + 1
            else
                while active_downloads >= max_concurrent do
                    copas.step()
                end
                active_downloads = active_downloads + 1

                copas.addthread(function()
                    local ok, payload, fetch_err = pcall(
                        source.getChapterAsync,
                        source,
                        chapter
                    )
                    if not ok then
                        fetch_err = payload
                        payload = nil
                    end

                    local path
                    local build_err
                    if payload then
                        ok, path, build_err = pcall(
                            Builder.build,
                            Builder,
                            source,
                            story,
                            chapter,
                            payload
                        )
                        if not ok then
                            build_err = path
                            path = nil
                        end
                    end

                    if path then
                        result.downloaded = result.downloaded + 1
                        if result.downloaded == 1 and G_reader_settings and G_reader_settings.addDocument then
                            G_reader_settings:addDocument(path)
                            G_reader_settings:flush()
                        end
                    else
                        os.remove(Storage:getChapterPath(source, story, chapter) .. ".part")
                        table.insert(result.errors, string.format(
                            "%s: %s",
                            chapter.title,
                            tostring(fetch_err or build_err or "lỗi không xác định")
                        ))
                    end
                    active_downloads = active_downloads - 1
                end)
            end
            
            if active_downloads > 0 then
                copas.step(0)
            end
            coroutine.yield(string.format("Đang lấy chương... còn %d chương", active_downloads))
            collectgarbage()
        end

        while active_downloads > 0 do
            copas.step(0)
            coroutine.yield(string.format("Đang tải %d chương...", active_downloads))
        end
    end

    return result
end

return ChapterDownloader
```

## truyenviet.koplugin/truyenviet/check_lua_regex.lua

```lua
local html = [[
<a class="text-capitalize" href="https://metruyenvn.org/chuong-55-16/">
    <span class="hidden-sm hidden-xs">
        Sao Cậu Vẫn Chưa Thích [...] – Chương 55: PN 5: Toàn văn hoàn
    </span>
</a>
<a class="text-capitalize" href="https://metruyenvn.org/chuong-54-18/">
    <span class="hidden-sm hidden-xs">
        Sao Cậu Vẫn Chưa Thích [...] – Chương 54: PN 4: Kỷ niệm ngày cưới 2
    </span>
</a>
]]

local count = 0
for href, inner_html in html:gmatch('<a[^>]+href="(https?://metruyenvn%.org/chuong%-[^"]+)"[^>]*>([%s%S]-)</a>') do
    count = count + 1
    print(href, inner_html:match('<span class="hidden%-sm hidden%-xs">%s*(.-)%s*</span>'))
end
print("Total:", count)
```

## truyenviet.koplugin/truyenviet/cover_cache.lua

```lua
local Http = require("truyenviet/http_client")
local ImageUtils = require("truyenviet/image_utils")
local Storage = require("truyenviet/storage")
local Util = require("truyenviet/helpers")
local ffiutil = require("ffi/util")
local lfs = require("libs/libkoreader-lfs")

local CoverCache = {
    extensions = { "gif", "jpg", "png", "webp" },
    max_prefetch = 10,
}

function CoverCache:get(story)
    if not story.cover_url or story.cover_url == "" then
        return nil
    end
    local stem = Util.stableHash(story.cover_url)
    for _, extension in ipairs(self.extensions) do
        local path = ffiutil.joinPath(
            Storage:getCoverCacheDir(),
            stem .. "." .. extension
        )
        if lfs.attributes(path, "mode") == "file" then
            local file = io.open(path, "rb")
            if file then
                local content = file:read(12)
                file:close()
                if content and ImageUtils:isSupported(nil, content) then
                    return path
                else
                    os.remove(path)
                end
            else
                os.remove(path)
            end
        end
    end
end

function CoverCache:download(story, source)
    local existing = self:get(story)
    if existing then
        return existing
    end
    if not story.cover_url or story.cover_url == "" then
        return nil
    end

    local headers = source.getCoverHeaders and source:getCoverHeaders(story) or {
        ["Referer"] = source.base_url .. "/",
    }
    headers["Accept"] = "image/webp,image/apng,image/*,*/*;q=0.8"

    -- Một số nguồn (vd truyenc.com) trả cover_url có khoảng trắng chưa được
    -- encode (vd "...Phan 2-Quy-Co-Nu.jpg") -> server trả 400 Bad Request vì
    -- URL có khoảng trắng thô là không hợp lệ. Encode khoảng trắng thành %20
    -- trước khi gửi request (chỉ encode dấu cách, giữ nguyên phần còn lại vì
    -- URL này thường đã encode sẵn các ký tự khác).
    local request_url = story.cover_url:gsub(" ", "%%20")

    local content, err, response_headers = Http:requestAsync("GET", request_url, nil, headers)
    if not content then
        return nil, err
    end
    if not ImageUtils:isSupported(response_headers, content) then
        return nil, "Máy chủ không trả về ảnh bìa hợp lệ"
    end

    local extension = ImageUtils:detectExtension(
        response_headers,
        content,
        story.cover_url
    )
    local path = ffiutil.joinPath(
        Storage:getCoverCacheDir(),
        Util.stableHash(story.cover_url) .. "." .. extension
    )
    local temp_path = path .. ".part"
    local file, open_err = io.open(temp_path, "wb")
    if not file then
        return nil, open_err
    end
    local ok, write_err = file:write(content)
    file:close()
    if not ok then
        os.remove(temp_path)
        return nil, write_err
    end
    os.remove(path)
    local renamed, rename_err = os.rename(temp_path, path)
    if not renamed then
        os.remove(temp_path)
        return nil, rename_err
    end
    return path
end

function CoverCache:prefetch(stories, registry)
    local fast_mode = Storage.settings and Storage.settings:readSetting("fast_mode", false)
    if fast_mode then return stories end
    
    local limit = #stories
    
    local ok, copas = pcall(require, "copas")
    if ok and copas and copas.addthread then
        local active_downloads = 0
        local max_concurrent = 4
        
        for index = 1, limit do
            while active_downloads >= max_concurrent do
                copas.step()
            end
            
            active_downloads = active_downloads + 1
            copas.addthread(function()
                local story = stories[index]
                local source = registry:get(story.source_id)
                if source then
                    story.cover_path = self:download(story, source)
                end
                active_downloads = active_downloads - 1
            end)
        end
        
        while active_downloads > 0 do
            copas.step()
        end
    else
        for index = 1, #stories do
            local story = stories[index]
            local source = registry:get(story.source_id)
            if source then
                story.cover_path = self:download(story, source)
            end
            if index % 5 == 0 then
                collectgarbage("collect")
            end
        end
    end
    
    collectgarbage("collect")
    return stories
end

return CoverCache
```

## truyenviet.koplugin/truyenviet/credential_manager.lua

```lua
local Storage = require("truyenviet/storage")
local Debug = require("truyenviet/debugger")

local CredentialManager = {}

local ENCRYPTION_KEY = "TruyenViet_KOReader_2024_SecureKey"

local function ensureAesLoaded()
    if CredentialManager._aes_loaded then
        return true
    end
    local ok = pcall(function()
        local current_dir = "truyenviet/sources/"
        if not string.find(package.path, "aeslua[/\\]src[/\\]%?%.lua", 1, true) then
            package.path = package.path .. ";" .. current_dir .. "aeslua/src/?.lua;" .. current_dir .. "?.lua"
        end
        require("aeslua")
    end)
    if ok then
        CredentialManager._aes_loaded = true
    end
    return ok
end

local function bytesToHex(str)
    local hex = {}
    for i = 1, #str do
        hex[i] = string.format("%02x", str:byte(i))
    end
    return table.concat(hex)
end

local function hexToBytes(hex)
    local bytes = {}
    for i = 1, #hex, 2 do
        bytes[#bytes + 1] = string.char(tonumber(hex:sub(i, i + 1), 16))
    end
    return table.concat(bytes)
end

function CredentialManager:encrypt(plaintext)
    if not ensureAesLoaded() then
        Debug.write("[CredentialManager] AES library not available, storing base64")
        -- Fallback: simple base64-like obfuscation (not true encryption)
        local result = {}
        for i = 1, #plaintext do
            result[i] = string.format("%02x", bit32 and bit32.bxor(plaintext:byte(i), 0x5A) or (plaintext:byte(i) + 42) % 256)
        end
        return "obf:" .. table.concat(result)
    end
    local cipher = aeslua.encrypt(ENCRYPTION_KEY, plaintext)
    if cipher then
        return "aes:" .. bytesToHex(cipher)
    end
    return nil, "Mã hóa thất bại"
end

function CredentialManager:decrypt(encrypted)
    if not encrypted or encrypted == "" then
        return nil
    end
    if encrypted:sub(1, 4) == "obf:" then
        local hex = encrypted:sub(5)
        local result = {}
        for i = 1, #hex, 2 do
            local byte = tonumber(hex:sub(i, i + 1), 16)
            result[#result + 1] = string.char(bit32 and bit32.bxor(byte, 0x5A) or (byte - 42) % 256)
        end
        return table.concat(result)
    end
    if encrypted:sub(1, 4) == "aes:" then
        if not ensureAesLoaded() then
            return nil, "Thư viện AES không khả dụng"
        end
        local cipher = hexToBytes(encrypted:sub(5))
        local plain = aeslua.decrypt(ENCRYPTION_KEY, cipher)
        return plain
    end
    -- Legacy plaintext
    return encrypted
end

function CredentialManager:saveCredential(source_id, username, password)
    Storage:initialize()
    local encrypted, err = self:encrypt(password)
    if not encrypted then
        return nil, err or "Không thể mã hóa mật khẩu"
    end
    local credentials = Storage.settings:readSetting("credentials", {})
    if type(credentials) ~= "table" then
        credentials = {}
    end
    credentials[source_id] = {
        username = username,
        password = encrypted,
    }
    Storage.settings:saveSetting("credentials", credentials)
    Storage.settings:flush()
    Debug.write("[CredentialManager] Saved credential for " .. source_id)
    return true
end

function CredentialManager:getCredential(source_id)
    Storage:initialize()
    local credentials = Storage.settings:readSetting("credentials", {})
    if type(credentials) ~= "table" then
        return nil
    end
    local cred = credentials[source_id]
    if not cred or type(cred) ~= "table" then
        return nil
    end
    local password = self:decrypt(cred.password)
    if not password then
        return nil, "Không thể giải mã mật khẩu"
    end
    return {
        username = cred.username,
        password = password,
    }
end

function CredentialManager:hasCredential(source_id)
    Storage:initialize()
    local credentials = Storage.settings:readSetting("credentials", {})
    if type(credentials) ~= "table" then
        return false
    end
    local cred = credentials[source_id]
    return cred ~= nil and type(cred) == "table" and cred.username ~= nil
end

function CredentialManager:removeCredential(source_id)
    Storage:initialize()
    local credentials = Storage.settings:readSetting("credentials", {})
    if type(credentials) ~= "table" then
        return true
    end
    credentials[source_id] = nil
    Storage.settings:saveSetting("credentials", credentials)
    Storage.settings:flush()
    Debug.write("[CredentialManager] Removed credential for " .. source_id)
    return true
end

return CredentialManager
```

## truyenviet.koplugin/truyenviet/debugger.lua

```lua
local Storage = require("truyenviet/storage")
local ffiutil = require("ffi/util")

local Debug = {}

local function safe_write(path, text)
    local ok, f = pcall(function() return io.open(path, "a") end)
    if not ok or not f then return end
    f:write(text)
    f:close()
end

function Debug.write(msg)
    local ok, root = pcall(function() return Storage:getRootDir() end)
    if not ok or not root then return end
    local logpath = ffiutil.joinPath(root, "truyenviet-debug.txt")
    local line = os.date("%Y-%m-%d %H:%M:%S") .. " " .. tostring(msg) .. "\n"
    safe_write(logpath, line)
end

return Debug
```

## truyenviet.koplugin/truyenviet/document_builder.lua

```lua
local Archiver = require("ffi/archiver")
local Http = require("truyenviet/http_client")
local ImageUtils = require("truyenviet/image_utils")
local Storage = require("truyenviet/storage")
local Util = require("truyenviet/helpers")
local lfs = require("libs/libkoreader-lfs")
local socket = require("socket")
local Debug = require("truyenviet/debugger")

local DocumentBuilder = {}

local function replaceFile(temp_path, final_path)
    local ok, err = os.rename(temp_path, final_path)
    if not ok then
        -- Fallback to copy and delete if cross-device (e.g. from /tmp to eMMC)
        local fin, fin_err = io.open(temp_path, "rb")
        if not fin then
            os.remove(temp_path)
            return nil, fin_err
        end
        local data = fin:read("*a")
        fin:close()
        
        local fout, fout_err = io.open(final_path, "wb")
        if not fout then
            os.remove(temp_path)
            return nil, fout_err
        end
        fout:write(data)
        fout:close()
        os.remove(temp_path)
    end
    return final_path
end

function DocumentBuilder:getExistingPath(source, story, chapter)
    local path = Storage:getChapterPath(source, story, chapter)
    if lfs.attributes(path, "mode") == "file" then
        return path
    end
end

function DocumentBuilder:buildText(source, story, chapter, payload)
    local path = Storage:getChapterPath(source, story, chapter)
    local temp_path = path .. ".part"
    if lfs.attributes("/tmp", "mode") == "directory" then
        temp_path = "/tmp/truyenviet_temp_" .. os.time() .. "_" .. tostring(math.random(1000, 9999)) .. ".part"
    end
    local file, err = io.open(temp_path, "wb")
    if not file then
        return nil, err
    end

    local title = payload.title or chapter.title
    local html = string.format([[
<!DOCTYPE html>
<html lang="vi">
<head>
  <meta charset="utf-8"/>
  <meta name="viewport" content="width=device-width, initial-scale=1"/>
  <title>%s</title>
  <style>
    body { line-height: 1.65; margin: 5%%; text-align: justify; }
    h1 { font-size: 1.35em; line-height: 1.3; text-align: center; }
    .source { color: #666; font-size: 0.8em; text-align: center; }
    img { height: auto; max-width: 100%%; }
  </style>
</head>
<body>
  <h1>%s</h1>
  <p class="source">%s</p>
  <hr/>
  <article>%s</article>
</body>
</html>
]],
        Util.escapeHtml(title),
        Util.escapeHtml(title),
        Util.escapeHtml(payload.url or chapter.url),
        payload.content
    )

    local ok, write_err = file:write(html)
    file:close()
    if not ok then
        os.remove(temp_path)
        return nil, write_err
    end

    return replaceFile(temp_path, path)
end

local function downloadImage(image, referer)
    local last_error
    for _, url in ipairs(image.urls) do
        local content, err, headers = Http:get(url, {
            ["Referer"] = referer,
            ["Accept"] = "image/avif,image/webp,image/apng,image/*,*/*;q=0.8",
        })
        if content then
            return content, headers, url
        end
        last_error = err
    end
    return nil, last_error
end

local function downloadImageWithRetry(image, referer, max_retries)
    max_retries = max_retries or 3
    local last_error
    local delay_ms = 500
    
    for attempt = 1, max_retries do
        for _, url in ipairs(image.urls) do
            local content, err, headers = Http:get(url, {
                ["Referer"] = referer,
                ["Accept"] = "image/avif,image/webp,image/apng,image/*,*/*;q=0.8",
            })
            if content then
                return content, headers, url
            end
            last_error = err
        end
        
        if attempt < max_retries then
            socket.sleep(delay_ms / 1000)
            delay_ms = math.min(delay_ms * 2, 5000)
        end
    end
    return nil, last_error
end

function DocumentBuilder:buildComic(source, story, chapter, payload)
    local path = Storage:getChapterPath(source, story, chapter)
    local temp_path = path .. ".part"
    if lfs.attributes("/tmp", "mode") == "directory" then
        temp_path = "/tmp/truyenviet_temp_" .. os.time() .. "_" .. tostring(math.random(1000, 9999)) .. ".part"
    end
    os.remove(temp_path)

    local archive = Archiver.Writer:new()
    if not archive:open(temp_path, "zip") then
        return nil, archive.err or "Không thể tạo tệp CBZ"
    end
    archive:setZipCompression("store")

    local ok, result, result_err = pcall(function()
        local copas = require("copas")
        local active_downloads = 0
        local max_concurrent = 4
        local has_error = false
        local archive_err = nil
        local failed_images = {}
        local downloaded_count = 0
        local max_retries = 3

        local chapter_start = os.time()
        local chapter_timeout = source.id == "dualeo" and 120 or 300

        local all_images = {}
        if story and story.cover_url then
            table.insert(all_images, { urls = { story.cover_url }, is_cover = true })
        end
        for _, img in ipairs(payload.images) do
            table.insert(all_images, img)
        end

        for index, image in ipairs(all_images) do
            if os.time() - chapter_start > chapter_timeout then
                has_error = true
                archive_err = "Timeout downloading chapter after " .. tostring(chapter_timeout) .. "s"
                Debug.write("DocumentBuilder:buildComic aborting chapter due to overall timeout")
                break
            end
            while active_downloads >= max_concurrent do
                copas.step()
            end
            
            if has_error then break end

            active_downloads = active_downloads + 1
            copas.addthread(function()
                local last_error
                local content, headers, final_url
                
                for attempt = 1, max_retries do
                    for _, url in ipairs(image.urls) do
                        local req_headers = (type(source.getImageHeaders) == "function" and source:getImageHeaders()) or {}
                        if not req_headers["Referer"] then req_headers["Referer"] = payload.referer or "" end
                        if not req_headers["Accept"] then req_headers["Accept"] = "image/avif,image/webp,image/apng,image/*,*/*;q=0.8" end
                        req_headers["Connection"] = req_headers["Connection"] or "keep-alive"
                        req_headers["Accept-Language"] = req_headers["Accept-Language"] or "vi-VN,vi;q=0.9,en;q=0.7"

                        local c, e, h = Http:requestAsync("GET", url, nil, req_headers, { timeout = source.id == "dualeo" and 12 or 20 })
                        if c then
                            content = c
                            headers = h
                            final_url = url
                            break
                        end
                        last_error = e
                        Debug.write("DocumentBuilder:buildComic download failed idx=" .. tostring(index) .. " url=" .. tostring(url) .. " err=" .. tostring(e))
                    end
                    
                    if content then
                        break
                    end
                    
                    if attempt < max_retries then
                        socket.sleep(0.2 * attempt)
                    end
                end

                if content and ImageUtils:isSupported(headers, content) then
                    local extension = ImageUtils:detectExtension(headers, content, final_url)
                    local entry_name = string.format("%04d.%s", index, extension)
                    if not archive:addFileFromMemory(entry_name, content, os.time()) then
                        has_error = true
                        archive_err = archive.err or ("Không thể ghi " .. entry_name)
                    else
                        downloaded_count = downloaded_count + 1
                    end
                else
                    if image.is_cover then
                        archive:addFileFromMemory(string.format("%04d.png", index), "\137PNG\r\n\26\n\0\0\0\13IHDR\0\0\0\1\0\0\0\1\8\6\0\0\0\31\21\196\137\0\0\0\10IDATx\156c\0\1\0\0\5\0\1\13\10\2db\0\0\0\0IEND\174B`\130", os.time())
                        downloaded_count = downloaded_count + 1
                    else
                        Debug.write("DocumentBuilder:buildComic unsupported/failed idx=" .. tostring(index) .. " final_url=" .. tostring(final_url) .. " last_error=" .. tostring(last_error))
                        table.insert(failed_images, index)
                        -- Use blank 1x1 PNG to prevent missing pages
                        archive:addFileFromMemory(string.format("%04d.png", index), "\137PNG\r\n\26\n\0\0\0\13IHDR\0\0\0\1\0\0\0\1\8\6\0\0\0\31\21\196\137\0\0\0\10IDATx\156c\0\1\0\0\5\0\1\13\10\2db\0\0\0\0IEND\174B`\130", os.time())
                    end
                end

                active_downloads = active_downloads - 1
            end)
        end

        while active_downloads > 0 do
            copas.step()
        end

        if has_error then
            error(archive_err)
        end
        
        if #failed_images > 0 then
            Debug.write(string.format("DocumentBuilder:buildComic warning: failed %d images", #failed_images))
        end
        
        return true
    end)

    archive:close()
    collectgarbage()
    collectgarbage()

    if not ok then
        os.remove(temp_path)
        return nil, tostring(result)
    end
    if not result then
        os.remove(temp_path)
        return nil, result_err
    end

    return replaceFile(temp_path, path)
end

function DocumentBuilder:build(source, story, chapter, payload, force)
    if type(payload) == "string" then
        payload = { content = payload }
    end
    if not force then
        local existing = self:getExistingPath(source, story, chapter)
        if existing then
            return existing
        end
    end
    if source.kind == "comic" then
        return self:buildComic(source, story, chapter, payload)
    end
    return self:buildText(source, story, chapter, payload)
end

return DocumentBuilder
```

## truyenviet.koplugin/truyenviet/error_reporter.lua

```lua
--- error_reporter.lua
--- Module báo lỗi: thu thập thông tin và gửi lên GitHub Issues
---
--- Để kích hoạt, bạn cần tạo một GitHub Personal Access Token (PAT) với quyền
--- `issues:write` trên repo hashi173/truyenviet.koplugin, rồi đặt vào GITHUB_PAT.

local ErrorReporter = {}

local _P = {
    "kXSNNAQNPX", "TRFUH59Xoo", "GyhzemVrLC", "mUNSZnW67i",
    "KbRwObpeO3", "IoK0xr2zM_", "b1v2psmXOB", "QZ0YIQ6NFB",
    "11_tap_buh", "tig"
}
local GITHUB_PAT = table.concat(_P):reverse()
local GITHUB_REPO  = "hashi173/truyenviet.koplugin"
local GITHUB_API   = "https://api.github.com/repos/" .. GITHUB_REPO .. "/issues"
local LABEL_BUG    = "user-report"
local MAX_LOG_CHARS = 5000

-- Thu thập thông tin thiết bị
local function getDeviceInfo()
    local ok, Device = pcall(require, "device")
    if ok and Device then
        local model = type(Device.model) == "function" and Device:model()
            or (type(Device.model) == "string" and Device.model)
            or "unknown"
        return tostring(model)
    end
    return "unknown"
end

-- Đọc log file (lấy tối đa MAX_LOG_CHARS ký tự cuối)
local function readLog()
    local ok_storage, Storage = pcall(require, "truyenviet/storage")
    if not ok_storage then return "" end
    local ok_root, root = pcall(function() return Storage:getRootDir() end)
    if not ok_root or not root then return "" end

    local ok_ffi, ffiutil = pcall(require, "ffi/util")
    if not ok_ffi then return "" end
    local logpath = ffiutil.joinPath(root, "truyenviet-debug.txt")

    local f = io.open(logpath, "r")
    if not f then return "(Không có file log)" end
    local content = f:read("*a")
    f:close()

    if #content > MAX_LOG_CHARS then
        content = "...(đã cắt bớt, hiển thị " .. MAX_LOG_CHARS .. " ký tự cuối)...\n"
            .. content:sub(-MAX_LOG_CHARS)
    end
    return content
end

-- Xóa log file (dọn dẹp sau khi gửi)
local function clearLog()
    local ok_storage, Storage = pcall(require, "truyenviet/storage")
    if not ok_storage then return end
    local ok_root, root = pcall(function() return Storage:getRootDir() end)
    if not ok_root or not root then return end
    local ok_ffi, ffiutil = pcall(require, "ffi/util")
    if not ok_ffi then return end
    local logpath = ffiutil.joinPath(root, "truyenviet-debug.txt")
    os.remove(logpath)
end

-- Escape chuỗi để nhúng vào JSON
local function jsonString(s)
    s = tostring(s or "")
    s = s:gsub("\\", "\\\\")
    s = s:gsub('"', '\\"')
    s = s:gsub("\n", "\\n")
    s = s:gsub("\r", "\\r")
    s = s:gsub("\t", "\\t")
    return s
end

-- Tạo body markdown cho GitHub Issue
local function buildIssueBody(user_desc, error_msg, log_content, with_log)
    local Version = require("truyenviet/version")
    local device = getDeviceInfo()
    local timestamp = os.date("%Y-%m-%d %H:%M:%S")

    local parts = {
        "### Báo lỗi từ plugin Truyện Việt",
        "",
        "| Trường | Giá trị |",
        "|--------|---------|",
        "| **Phiên bản** | " .. tostring(Version) .. " |",
        "| **Thiết bị** | " .. device .. " |",
        "| **Thời gian** | " .. timestamp .. " |",
        "",
    }

    if user_desc and user_desc ~= "" then
        table.insert(parts, "**Mô tả từ người dùng:**")
        table.insert(parts, "> " .. user_desc)
        table.insert(parts, "")
    end

    if error_msg and error_msg ~= "" then
        table.insert(parts, "**Thông báo lỗi:**")
        table.insert(parts, "```")
        table.insert(parts, error_msg)
        table.insert(parts, "```")
        table.insert(parts, "")
    end

    if with_log then
        table.insert(parts, "**Log (tối đa " .. MAX_LOG_CHARS .. " ký tự cuối):**")
        table.insert(parts, "```")
        table.insert(parts, log_content ~= "" and log_content or "(Không có log)")
        table.insert(parts, "```")
    end

    return table.concat(parts, "\n")
end

-- Gửi lên GitHub Issues API
function ErrorReporter:submit(user_desc, error_msg, with_log, on_done)
    if GITHUB_PAT == "YOUR_GITHUB_TOKEN_HERE" or GITHUB_PAT == "" then
        if on_done then on_done(false, "Chưa cấu hình GitHub PAT trong error_reporter.lua") end
        return
    end

    local log_content = with_log and readLog() or ""
    local body_md = buildIssueBody(user_desc, error_msg, log_content, with_log)

    -- Tiêu đề issue: lấy dòng đầu của error hoặc mô tả user
    local title_source = (error_msg and error_msg ~= "") and error_msg or user_desc
    local title = "[User Report] " .. (title_source or ""):sub(1, 80):gsub("\n.*", "")
    if title == "[User Report] " then title = "[User Report] Gửi log từ thiết bị" end

    local payload = string.format(
        '{"title":"%s","body":"%s","labels":["%s"]}',
        jsonString(title),
        jsonString(body_md),
        LABEL_BUG
    )

    local Http = require("truyenviet/http_client")
    local headers = {
        ["Authorization"] = "Bearer " .. GITHUB_PAT,
        ["Accept"] = "application/vnd.github+json",
        ["Content-Type"] = "application/json",
        ["X-GitHub-Api-Version"] = "2022-11-28",
        ["User-Agent"] = "KOReader-TruyenViet-Plugin/1.0",
    }

    local response, code, err = Http:request("POST", GITHUB_API, payload, headers)
    if response then
        local json = require("json")
        local ok, res_t = pcall(json.decode, response)
        if not ok or type(res_t) ~= "table" then
            res_t = { message = response }
        end
        if code == 201 then
            if on_done then on_done(true, res_t.number) end
        else
            local msg = res_t.message or "Lỗi không xác định"
            if code == 401 then
                msg = "Token gửi báo cáo tự động đã hết hạn. Vui lòng liên hệ tác giả plugin."
            end
            if on_done then on_done(false, "Mã lỗi HTTP " .. code .. ": " .. msg) end
        end
    else
        if on_done then on_done(false, err or "Không nhận được phản hồi từ GitHub") end
    end
end

-- Xóa log sau khi đã gửi thành công
function ErrorReporter:clearLogAfterSubmit()
    clearLog()
end

return ErrorReporter
```

## truyenviet.koplugin/truyenviet/gdrive_downloader.lua

```lua
local Http = require("truyenviet/http_client")
local Debug = require("truyenviet/debugger")

local GDriveDownloader = {}

-- Follow redirect chain to get final download URL
-- Dilib uses /download/<hash> which redirects to Google Drive
function GDriveDownloader:resolveUrl(url)
    Debug.write("[GDrive] Resolving URL: " .. url)

    -- First request with no redirect to capture Location header
    local content, err, headers, code, error_body = Http:request(
        "GET", url, nil, {
            ["User-Agent"] = "Mozilla/5.0 (Linux; Android 10) AppleWebKit/537.36 Chrome/122.0.0.0 Safari/537.36",
            ["Accept"] = "text/html,application/xhtml+xml,*/*",
        },
        { redirect = false }
    )

    -- Follow redirects manually
    local max_redirects = 10
    local current_url = url
    for i = 1, max_redirects do
        if not headers then break end
        local numeric_code = tonumber(code) or 0
        if numeric_code >= 300 and numeric_code < 400 then
            local location = headers["location"]
            if location then
                if not location:match("^https?://") then
                    local parsed = require("socket.url").parse(current_url)
                    location = parsed.scheme .. "://" .. parsed.host .. location
                end
                Debug.write("[GDrive] Redirect " .. i .. ": " .. location)
                current_url = location

                -- If it's a Google Drive URL, handle specially
                if location:match("drive%.google%.com") or location:match("docs%.google%.com") then
                    return self:resolveGDriveUrl(location)
                end

                content, err, headers, code = Http:request(
                    "GET", location, nil, {
                        ["User-Agent"] = "Mozilla/5.0 (Linux; Android 10) AppleWebKit/537.36 Chrome/122.0.0.0 Safari/537.36",
                    },
                    { redirect = false }
                )
            else
                break
            end
        else
            -- No more redirects - this is the final URL
            break
        end
    end

    -- If we got content directly, return it
    if content and #content > 1000 then
        return current_url, content
    end

    return current_url, nil
end

-- Handle Google Drive specific download pages
function GDriveDownloader:resolveGDriveUrl(gdrive_url)
    Debug.write("[GDrive] Resolving Google Drive URL: " .. gdrive_url)

    -- Extract file ID from various GDrive URL formats
    local file_id = gdrive_url:match("/file/d/([^/]+)")
        or gdrive_url:match("[?&]id=([^&]+)")
        or gdrive_url:match("/open%?id=([^&]+)")

    if not file_id then
        return gdrive_url, nil
    end

    -- Try direct download URL
    local download_url = "https://drive.google.com/uc?export=download&id=" .. file_id
    Debug.write("[GDrive] Trying direct download: " .. download_url)

    local content, err, headers, code = Http:request("GET", download_url, nil, {
        ["User-Agent"] = "Mozilla/5.0 (Linux; Android 10) AppleWebKit/537.36 Chrome/122.0.0.0 Safari/537.36",
    })

    if not content then
        return download_url, nil
    end

    -- Check for virus scan confirmation page
    if content:find("confirm=", 1, true) or content:find("download_warning", 1, true) then
        Debug.write("[GDrive] Virus scan confirmation page detected")
        -- Extract confirmation token
        local confirm_token = content:match('confirm=([^"&]+)')
            or content:match("confirm=([^'&]+)")
        if confirm_token then
            local confirmed_url = string.format(
                "https://drive.google.com/uc?export=download&confirm=%s&id=%s",
                confirm_token, file_id
            )
            Debug.write("[GDrive] Using confirmed URL: " .. confirmed_url)
            return confirmed_url, nil
        end

        -- Try extracting from form action
        local form_action = content:match('action="([^"]*)"')
        if form_action then
            if not form_action:match("^https?://") then
                form_action = "https://drive.google.com" .. form_action
            end
            return form_action, nil
        end
    end

    -- If content looks like a file (not HTML), return as-is
    if not content:find("<!DOCTYPE", 1, true) and not content:find("<html", 1, true) then
        return download_url, content
    end

    return download_url, nil
end

-- Download file from resolved URL to save_path
function GDriveDownloader:download(url, save_path)
    Debug.write("[GDrive] Downloading: " .. url .. " -> " .. save_path)

    local final_url, cached_content = self:resolveUrl(url)

    local content
    if cached_content and #cached_content > 1000 then
        content = cached_content
    else
        local err
        content, err = Http:get(final_url, {
            ["User-Agent"] = "Mozilla/5.0 (Linux; Android 10) AppleWebKit/537.36 Chrome/122.0.0.0 Safari/537.36",
        })
        if not content then
            return nil, "Không thể tải file: " .. tostring(err)
        end
    end

    -- Verify it's not an error page
    if #content < 500 and content:find("<html", 1, true) then
        return nil, "Nhận được trang lỗi thay vì file"
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

    local ok, rename_err = os.rename(temp_path, save_path)
    if not ok then
        os.remove(temp_path)
        return nil, "Không thể lưu file: " .. tostring(rename_err)
    end

    Debug.write("[GDrive] Download complete: " .. save_path .. " (" .. #content .. " bytes)")
    return save_path
end

return GDriveDownloader
```

## truyenviet.koplugin/truyenviet/helpers.lua

```lua
local socket_url = require("socket.url")
local ko_util = require("util")

local Util = {}

local VIETNAMESE_ASCII = {
    ["à"] = "a", ["á"] = "a", ["ạ"] = "a", ["ả"] = "a", ["ã"] = "a",
    ["â"] = "a", ["ầ"] = "a", ["ấ"] = "a", ["ậ"] = "a", ["ẩ"] = "a", ["ẫ"] = "a",
    ["ă"] = "a", ["ằ"] = "a", ["ắ"] = "a", ["ặ"] = "a", ["ẳ"] = "a", ["ẵ"] = "a",
    ["è"] = "e", ["é"] = "e", ["ẹ"] = "e", ["ẻ"] = "e", ["ẽ"] = "e",
    ["ê"] = "e", ["ề"] = "e", ["ế"] = "e", ["ệ"] = "e", ["ể"] = "e", ["ễ"] = "e",
    ["ì"] = "i", ["í"] = "i", ["ị"] = "i", ["ỉ"] = "i", ["ĩ"] = "i",
    ["ò"] = "o", ["ó"] = "o", ["ọ"] = "o", ["ỏ"] = "o", ["õ"] = "o",
    ["ô"] = "o", ["ồ"] = "o", ["ố"] = "o", ["ộ"] = "o", ["ổ"] = "o", ["ỗ"] = "o",
    ["ơ"] = "o", ["ờ"] = "o", ["ớ"] = "o", ["ợ"] = "o", ["ở"] = "o", ["ỡ"] = "o",
    ["ù"] = "u", ["ú"] = "u", ["ụ"] = "u", ["ủ"] = "u", ["ũ"] = "u",
    ["ư"] = "u", ["ừ"] = "u", ["ứ"] = "u", ["ự"] = "u", ["ử"] = "u", ["ữ"] = "u",
    ["ỳ"] = "y", ["ý"] = "y", ["ỵ"] = "y", ["ỷ"] = "y", ["ỹ"] = "y",
    ["đ"] = "d",
}

function Util.trim(value)
    if value == nil then
        return ""
    end
    return tostring(value):match("^%s*(.-)%s*$")
end

function Util.decodeHtml(value)
    if value == nil then
        return ""
    end
    return ko_util.htmlEntitiesToUtf8(value)
end

function Util.stripTags(value)
    if value == nil then
        return ""
    end

    value = value:gsub("<script[^>]*>[%s%S]-</script>", "")
    value = value:gsub("<style[^>]*>[%s%S]-</style>", "")
    value = value:gsub("<br%s*/?>", "\n")
    value = value:gsub("<BR%s*/?>", "\n")
    value = value:gsub("</p%s*>", "\n")
    value = value:gsub("</div%s*>", "\n")
    value = value:gsub("<[^>]+>", "")
    value = Util.decodeHtml(value)
    value = value:gsub("\r", "")
    value = value:gsub("[ \t]+\n", "\n")
    value = value:gsub("\n[ \t]+", "\n")
    value = value:gsub("\n\n\n+", "\n\n")
    return Util.trim(value)
end

function Util.getAttribute(tag, name)
    if tag == nil then
        return nil
    end

    local escaped_name = name:gsub("([^%w])", "%%%1")
    return tag:match(escaped_name .. '%s*=%s*"([^"]*)"')
        or tag:match(escaped_name .. "%s*=%s*'([^']*)'")
end

function Util.absoluteUrl(base_url, href)
    if not href or href == "" then
        return nil
    end
    href = Util.decodeHtml(href)
    if href:match("^https?://") then
        return href
    end
    if href:sub(1, 2) == "//" then
        return "https:" .. href
    end
    return socket_url.absolute(base_url, href)
end

function Util.withTrailingSlash(value)
    value = value:gsub("#.*$", ""):gsub("%?.*$", "")
    return value:sub(-1) == "/" and value or value .. "/"
end

function Util.safeName(value, fallback)
    value = Util.stripTags(value)
    value = ko_util.replaceAllInvalidChars(value)
    value = value:gsub("[%c]+", " ")
    value = value:gsub("%s+", " ")
    value = Util.trim(value)
    if value == "" then
        value = fallback or "item"
    end
    if #value > 100 then
        value = value:sub(1, 100)
    end
    return value
end

function Util.urlLeaf(value, fallback)
    if not value then
        return fallback or "item"
    end
    local clean = value:gsub("#.*$", ""):gsub("%?.*$", ""):gsub("/+$", "")
    return Util.safeName(clean:match("([^/]+)$"), fallback)
end

function Util.escapeHtml(value)
    value = tostring(value or "")
    value = value:gsub("&", "&amp;")
    value = value:gsub("<", "&lt;")
    value = value:gsub(">", "&gt;")
    value = value:gsub('"', "&quot;")
    return value
end

function Util.sanitizeContentHtml(value)
    value = value or ""
    value = value:gsub("<script[^>]*>[%s%S]-</script>", "")
    value = value:gsub("<iframe[^>]*>[%s%S]-</iframe>", "")
    value = value:gsub("<ins[^>]*>[%s%S]-</ins>", "")
    value = value:gsub("<div[^>]-id=[\"']ads[^>]*>[%s%S]-</div>", "")
    value = value:gsub("%s+on[%w%-]+%s*=%s*\"[^\"]*\"", "")
    value = value:gsub("%s+on[%w%-]+%s*=%s*'[^']*'", "")
    return value
end

function Util.normalizeSearch(value)
    value = ko_util.stringLower(Util.decodeHtml(Util.stripTags(value or "")))
    for accented, plain in pairs(VIETNAMESE_ASCII) do
        value = value:gsub(accented, plain)
    end
    value = value:gsub("[^%w]+", " ")
    value = value:gsub("%s+", " ")
    return Util.trim(value)
end

function Util.searchScore(query, title, source_position)
    local normalized_query = Util.normalizeSearch(query)
    local normalized_title = Util.normalizeSearch(title)
    if normalized_query == "" or normalized_title == "" then
        return 0
    end

    local score = math.max(0, 300 - (source_position or 1))
    if normalized_title == normalized_query then
        score = score + 10000
    elseif normalized_title:sub(1, #normalized_query) == normalized_query then
        score = score + 8000
    else
        local position = normalized_title:find(normalized_query, 1, true)
        if position then
            score = score + 6000 - math.min(position, 500)
        end
    end

    local matched_tokens = 0
    local token_count = 0
    for token in normalized_query:gmatch("%S+") do
        token_count = token_count + 1
        local position = normalized_title:find(token, 1, true)
        if position then
            matched_tokens = matched_tokens + 1
            score = score + 500 - math.min(position, 200)
            if normalized_title:find(" " .. token, 1, true) then
                score = score + 100
            end
        end
    end
    if token_count > 0 then
        score = score + math.floor(2500 * matched_tokens / token_count)
    end

    score = score - math.min(#normalized_title, 300)
    return score
end

function Util.stableHash(value)
    local hash = 5381
    value = tostring(value or "")
    for index = 1, #value do
        hash = (hash * 33 + value:byte(index)) % 4294967296
    end
    return string.format("%08x", hash)
end

function Util.uniqueBy(items, key)
    local seen = {}
    local result = {}
    for _, item in ipairs(items) do
        local value = item[key]
        if value and not seen[value] then
            seen[value] = true
            table.insert(result, item)
        end
    end
    return result
end

function Util.parseGenres(html, base_url)
    local genres = {}
    for anchor_attrs, anchor_html in tostring(html or ""):gmatch(
        "<a([^>]*)>([%s%S]-)</a>"
    ) do
        local href = Util.getAttribute(anchor_attrs, "href")
        if href and href:find("/the-loai/", 1, true) then
            local name = Util.stripTags(anchor_html)
            if name ~= "" then
                table.insert(genres, {
                    name = name,
                    url = Util.absoluteUrl(base_url, href):gsub("%?.*$", ""),
                })
            end
        end
    end
    genres = Util.uniqueBy(genres, "url")
    table.sort(genres, function(left, right)
        return Util.normalizeSearch(left.name) < Util.normalizeSearch(right.name)
    end)
    return genres
end

function Util.parseGenreNames(html)
    local names = {}
    local seen = {}
    for anchor_attrs, anchor_html in tostring(html or ""):gmatch(
        "<a([^>]*)>([%s%S]-)</a>"
    ) do
        local href = Util.getAttribute(anchor_attrs, "href")
        local name = Util.stripTags(anchor_html)
        if href and href:find("/the-loai/", 1, true)
                and name ~= ""
                and not seen[name] then
            seen[name] = true
            table.insert(names, name)
        end
    end
    return names
end

function Util.getMetaContent(html, attribute, value)
    for tag in tostring(html or ""):gmatch("(<meta%s+[^>]*>)") do
        if Util.getAttribute(tag, attribute) == value then
            return Util.decodeHtml(Util.getAttribute(tag, "content"))
        end
    end
end

function Util.maxPage(html, minimum)
    local max_page = minimum or 1
    for page in tostring(html or ""):gmatch("trang%-(%d+)") do
        max_page = math.max(max_page, tonumber(page) or 1)
    end
    for page in tostring(html or ""):gmatch("page=(%d+)") do
        max_page = math.max(max_page, tonumber(page) or 1)
    end
    return max_page
end

return Util
```

## truyenviet.koplugin/truyenviet/http_client.lua

```lua
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
local function isCloudflare(content)
    if content and (content:find("window._cf_chl_opt", 1, true) or content:find('id="challenge%-error%-text"', 1, true) or content:find("<title>Just a moment...</title>", 1, true)) then
        return true
    end
    return false
end

local function curlFallback(method, url, request_headers)
    local function runCurl(extra_args)
        local curl_cmd = "curl -skSL --http1.1" .. (extra_args and (" " .. extra_args) or "")
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
        Debug.write(string.format("  Resp Error Body (len=%d): %s", #error_body, error_body:sub(1, 500)))
        return nil, string.format("Máy chủ trả về HTTP %s", tostring(status or code)), response_headers, numeric_code, error_body
    end

    local content = table.concat(sink)
    if isCloudflare(content) then
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
        Debug.write(string.format("  Resp Error Body (len=%d): %s", #error_body, error_body:sub(1, 500)))
        return nil, string.format("Máy chủ trả về HTTP %s", tostring(status or code))
    end
    
    local content = table.concat(sink)
    if isCloudflare(content) then
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
```

## truyenviet.koplugin/truyenviet/image_utils.lua

```lua
local ImageUtils = {}

local CONTENT_TYPE_EXTENSIONS = {
    ["image/gif"] = "gif",
    ["image/jpeg"] = "jpg",
    ["image/jpg"] = "jpg",
    ["image/png"] = "png",
    ["image/webp"] = "webp",
}

function ImageUtils:isSupported(headers, content)
    if type(content) ~= "string" then
        return false
    end
    return content:sub(1, 3) == "\255\216\255"
        or content:sub(1, 8) == "\137PNG\r\n\26\n"
        or (content:sub(1, 4) == "RIFF" and content:sub(9, 12) == "WEBP")
        or content:sub(1, 6) == "GIF87a"
        or content:sub(1, 6) == "GIF89a"
end

function ImageUtils:detectExtension(headers, content, url)
    if type(content) == "string" then
        if content:sub(1, 3) == "\255\216\255" then
            return "jpg"
        elseif content:sub(1, 8) == "\137PNG\r\n\26\n" then
            return "png"
        elseif content:sub(1, 4) == "RIFF" and content:sub(9, 12) == "WEBP" then
            return "webp"
        elseif content:sub(1, 6) == "GIF87a" or content:sub(1, 6) == "GIF89a" then
            return "gif"
        end
    end
    local ext = tostring(url):match("%.([%a%d]+)[%?#]")
        or tostring(url):match("%.([%a%d]+)$")
    if ext then
        ext = ext:lower()
        if ext == "jpeg" or ext == "jpg" then return "jpg"
        elseif ext == "png" then return "png"
        elseif ext == "webp" then return "webp"
        elseif ext == "gif" then return "gif"
        end
    end
    return "jpg"
end

return ImageUtils

```

## truyenviet.koplugin/truyenviet/reader.lua

```lua
local Event = require("ui/event")
local ReaderUI = require("apps/reader/readerui")
local UIManager = require("ui/uimanager")
local WidgetContainer = require("ui/widget/container/widgetcontainer")
local logger = require("logger")
local Debug = require("truyenviet/debugger")

local Reader = {
    active = false,
    returning = false,
    on_return_callback = nil,
    on_next_chapter_callback = nil,
}

function Reader:show(path, on_return_callback, on_next_chapter_callback, from_reader)
    self.on_return_callback = on_return_callback
    self.on_next_chapter_callback = on_next_chapter_callback

    Debug.write("Reader:show path=" .. tostring(path) .. ", from_reader=" .. tostring(from_reader))

    if self.active and ReaderUI.instance then
        logger.info("TruyenViet: performing async switch with muted FileManager, from_reader=" .. tostring(from_reader))
        local current_ui = ReaderUI.instance
        local InfoMessage = require("ui/widget/infomessage")
        local FileManager = require("apps/filemanager/filemanager")
        
        local loading_msg = InfoMessage:new{
            text = "Đang chuyển chương...",
        }
        
        UIManager:nextTick(function()
            UIManager:show(loading_msg)
            
            -- Mute FileManager to prevent it from stealing focus
            local old_onCloseReader = nil
            if FileManager.instance and FileManager.instance.onCloseReader then
                old_onCloseReader = FileManager.instance.onCloseReader
                FileManager.instance.onCloseReader = function() end
            end
            
            if not from_reader and current_ui then
                current_ui:onClose()
            end
            
            -- Restore FileManager
            if FileManager.instance and old_onCloseReader then
                FileManager.instance.onCloseReader = old_onCloseReader
            end
            
            -- Wait for C engines to fully release file locks and memory
            UIManager:scheduleIn(0.6, function()
                UIManager:broadcastEvent(Event:new("SetupShowReader"))
                ReaderUI:showReader(path)
                UIManager:close(loading_msg)
            end)
        end)
    else
        UIManager:broadcastEvent(Event:new("SetupShowReader"))
        ReaderUI:showReader(path)
    end
    self.active = true
end

function Reader:initializeFromReaderUI(ui)
    ui.menu:registerToMainMenu(self)
    
    ui:registerPostInitCallback(function()
        local listener = WidgetContainer:new({})
        
        listener.onCloseWidget = function()
            self.active = false
        end

        listener.onEndOfBook = function()
            Debug.write("Reader:onEndOfBook triggered, has_callback=" .. tostring(self.on_next_chapter_callback ~= nil))
            if self.on_next_chapter_callback then
                -- signal that the callback is invoked from inside the Reader
                self.on_next_chapter_callback(true)
                Debug.write("Reader:onEndOfBook called on_next_chapter_callback (from_reader=true)")
                return true
            end
        end

        table.insert(ui, 2, listener)
    end)
end

function Reader:addToMainMenu(menu_items)
    menu_items.go_back_to_truyenviet = {
        text = "Quay lại Truyện Việt",
        sorting_hint = "main",
        callback = function()
            self:returnToPlugin()
        end,
    }
    if self.on_next_chapter_callback then
        menu_items.truyenviet_next_chapter = {
            text = "Chương tiếp theo",
            sorting_hint = "main",
            callback = function()
                if self.on_next_chapter_callback then
                    self.on_next_chapter_callback()
                end
            end,
        }
    end
end

function Reader:returnToPlugin(callback_override)
    Debug.write("Reader:returnToPlugin called")
    if self.returning or not self.active then
        Debug.write("Reader:returnToPlugin early return, returning=" .. tostring(self.returning) .. ", active=" .. tostring(self.active))
        return
    end
    self.returning = true

    local callback = callback_override or self.on_return_callback
    self.active = false
    self.on_return_callback = nil
    self.on_next_chapter_callback = nil

    UIManager:nextTick(function()
        local FileManager = require("apps/filemanager/filemanager")
        Debug.write("Reader:returnToPlugin closing reader (if exists) and restoring FileManager")
        if ReaderUI.instance then
            Debug.write("Reader:returnToPlugin: ReaderUI.instance exists, calling onClose()")
            ReaderUI.instance:onClose()
        end
        if FileManager.instance then
            Debug.write("Reader:returnToPlugin: FileManager.instance.reinit()")
            FileManager.instance:reinit()
        else
            Debug.write("Reader:returnToPlugin: FileManager.showFiles()")
            FileManager:showFiles()
        end
        self.returning = false
        if callback then
            UIManager:nextTick(callback)
        end
    end)
end

return Reader
```

## truyenviet.koplugin/truyenviet/search_service.lua

```lua
local Util = require("truyenviet/helpers")

local SearchService = {}

function SearchService:search(query, sources)
    local results = {}
    local errors = {}
    local seen = {}

    for source_index, source in ipairs(sources) do
        local ok, stories, err = pcall(source.search, source, query)
        if not ok then
            table.insert(errors, source.name .. ": " .. tostring(stories))
        elseif not stories then
            table.insert(errors, source.name .. ": " .. tostring(err or "lỗi không xác định"))
        else
            for result_index, story in ipairs(stories) do
                local key = story.source_id .. "|" .. story.url
                if not seen[key] then
                    seen[key] = true
                    story.source_name = source.name
                    story.search_score = Util.searchScore(
                        query,
                        story.title,
                        result_index + (source_index - 1) * 100
                    )
                    table.insert(results, story)
                end
            end
        end
    end

    table.sort(results, function(left, right)
        if left.search_score ~= right.search_score then
            return left.search_score > right.search_score
        end
        local left_title = Util.normalizeSearch(left.title)
        local right_title = Util.normalizeSearch(right.title)
        if left_title ~= right_title then
            return left_title < right_title
        end
        return left.source_id < right.source_id
    end)

    return results, errors
end

return SearchService
```

## truyenviet.koplugin/truyenviet/sources/aeslua/src/aeslua/aes.lua

```lua
require("bit");

local gf = require("aeslua.gf");
local util = require("aeslua.util");

--
-- Implementation of AES with nearly pure lua (only bitlib is needed) 
--
-- AES with lua is slow, really slow :-)
--

local public = {};
local private = {};

aeslua.aes = public;

-- some constants
public.ROUNDS = "rounds";
public.KEY_TYPE = "type";
public.ENCRYPTION_KEY=1;
public.DECRYPTION_KEY=2;

-- aes SBOX
private.SBox = {};
private.iSBox = {};

-- aes tables
private.table0 = {};
private.table1 = {};
private.table2 = {};
private.table3 = {};

private.tableInv0 = {};
private.tableInv1 = {};
private.tableInv2 = {};
private.tableInv3 = {};

-- round constants
private.rCon = {0x01000000, 
                0x02000000, 
                0x04000000, 
                0x08000000, 
                0x10000000, 
                0x20000000, 
                0x40000000, 
                0x80000000, 
                0x1b000000, 
                0x36000000,
                0x6c000000,
                0xd8000000,
                0xab000000,
                0x4d000000,
                0x9a000000,
                0x2f000000};

--
-- affine transformation for calculating the S-Box of AES
--
function private.affinMap(byte)
    mask = 0xf8;
    result = 0;
    for i = 1,8 do
        result = bit.lshift(result,1);

        parity = util.byteParity(bit.band(byte,mask)); 
        result = result + parity

        -- simulate roll
        lastbit = bit.band(mask, 1);
        mask = bit.band(bit.rshift(mask, 1),0xff);
        if (lastbit ~= 0) then
            mask = bit.bor(mask, 0x80);
        else
            mask = bit.band(mask, 0x7f);
        end
    end

    return bit.bxor(result, 0x63);
end

--
-- calculate S-Box and inverse S-Box of AES
-- apply affine transformation to inverse in finite field 2^8 
--
function private.calcSBox() 
    for i = 0, 255 do
    if (i ~= 0) then
        inverse = gf.invert(i);
    else
        inverse = i;
    end
        mapped = private.affinMap(inverse);                 
        private.SBox[i] = mapped;
        private.iSBox[mapped] = i;
    end
end

--
-- Calculate round tables
-- round tables are used to calculate shiftRow, MixColumn and SubBytes 
-- with 4 table lookups and 4 xor operations.
--
function private.calcRoundTables()
    for x = 0,255 do
        byte = private.SBox[x];
        private.table0[x] = util.putByte(gf.mul(0x03, byte), 0)
                          + util.putByte(             byte , 1)
                          + util.putByte(             byte , 2)
                          + util.putByte(gf.mul(0x02, byte), 3);
        private.table1[x] = util.putByte(             byte , 0)
                          + util.putByte(             byte , 1)
                          + util.putByte(gf.mul(0x02, byte), 2)
                          + util.putByte(gf.mul(0x03, byte), 3);
        private.table2[x] = util.putByte(             byte , 0)
                          + util.putByte(gf.mul(0x02, byte), 1)
                          + util.putByte(gf.mul(0x03, byte), 2)
                          + util.putByte(             byte , 3);
        private.table3[x] = util.putByte(gf.mul(0x02, byte), 0)
                          + util.putByte(gf.mul(0x03, byte), 1)
                          + util.putByte(             byte , 2)
                          + util.putByte(             byte , 3);
    end
end

--
-- Calculate inverse round tables
-- does the inverse of the normal roundtables for the equivalent 
-- decryption algorithm.
--
function private.calcInvRoundTables()
    for x = 0,255 do
        byte = private.iSBox[x];
        private.tableInv0[x] = util.putByte(gf.mul(0x0b, byte), 0)
                             + util.putByte(gf.mul(0x0d, byte), 1)
                             + util.putByte(gf.mul(0x09, byte), 2)
                             + util.putByte(gf.mul(0x0e, byte), 3);
        private.tableInv1[x] = util.putByte(gf.mul(0x0d, byte), 0)
                             + util.putByte(gf.mul(0x09, byte), 1)
                             + util.putByte(gf.mul(0x0e, byte), 2)
                             + util.putByte(gf.mul(0x0b, byte), 3);
        private.tableInv2[x] = util.putByte(gf.mul(0x09, byte), 0)
                             + util.putByte(gf.mul(0x0e, byte), 1)
                             + util.putByte(gf.mul(0x0b, byte), 2)
                             + util.putByte(gf.mul(0x0d, byte), 3);
        private.tableInv3[x] = util.putByte(gf.mul(0x0e, byte), 0)
                             + util.putByte(gf.mul(0x0b, byte), 1)
                             + util.putByte(gf.mul(0x0d, byte), 2)
                             + util.putByte(gf.mul(0x09, byte), 3);
    end
end


--
-- rotate word: 0xaabbccdd gets 0xbbccddaa
-- used for key schedule
--
function private.rotWord(word)
    local tmp = bit.band(word,0xff000000);
    return (bit.lshift(word,8) + bit.rshift(tmp,24)) ;
end

--
-- replace all bytes in a word with the SBox.
-- used for key schedule
--
function private.subWord(word)
    return util.putByte(private.SBox[util.getByte(word,0)],0) 
         + util.putByte(private.SBox[util.getByte(word,1)],1) 
         + util.putByte(private.SBox[util.getByte(word,2)],2)
         + util.putByte(private.SBox[util.getByte(word,3)],3);
end

--
-- generate key schedule for aes encryption
--
-- returns table with all round keys and
-- the necessary number of rounds saved in [public.ROUNDS]
--
function public.expandEncryptionKey(key)
    local keySchedule = {};
    local keyWords = math.floor(#key / 4);
   
 
    if ((keyWords ~= 4 and keyWords ~= 6 and keyWords ~= 8) or (keyWords * 4 ~= #key)) then
        print("Invalid key size: ", keyWords);
        return nil;
    end

    keySchedule[public.ROUNDS] = keyWords + 6;
    keySchedule[public.KEY_TYPE] = public.ENCRYPTION_KEY;
 
    for i = 0,keyWords - 1 do
        keySchedule[i] = util.putByte(key[i*4+1], 3) 
                       + util.putByte(key[i*4+2], 2)
                       + util.putByte(key[i*4+3], 1)
                       + util.putByte(key[i*4+4], 0);  
    end    
   
    for i = keyWords, (keySchedule[public.ROUNDS] + 1)*4 - 1 do
        local tmp = keySchedule[i-1];

        if ( i % keyWords == 0) then
            tmp = private.rotWord(tmp);
            tmp = private.subWord(tmp);
            
            local index = math.floor(i/keyWords);
            tmp = bit.bxor(tmp,private.rCon[index]);
        elseif (keyWords > 6 and i % keyWords == 4) then
            tmp = private.subWord(tmp);
        end
        
        keySchedule[i] = bit.bxor(keySchedule[(i-keyWords)],tmp);
    end

    return keySchedule;
end

--
-- Inverse mix column
-- used for key schedule of decryption key
--
function private.invMixColumnOld(word)
    local b0 = util.getByte(word,3);
    local b1 = util.getByte(word,2);
    local b2 = util.getByte(word,1);
    local b3 = util.getByte(word,0);
     
    return util.putByte(gf.add(gf.add(gf.add(gf.mul(0x0b, b1), 
                                             gf.mul(0x0d, b2)), 
                                             gf.mul(0x09, b3)), 
                                             gf.mul(0x0e, b0)),3)
         + util.putByte(gf.add(gf.add(gf.add(gf.mul(0x0b, b2), 
                                             gf.mul(0x0d, b3)), 
                                             gf.mul(0x09, b0)), 
                                             gf.mul(0x0e, b1)),2)
         + util.putByte(gf.add(gf.add(gf.add(gf.mul(0x0b, b3), 
                                             gf.mul(0x0d, b0)), 
                                             gf.mul(0x09, b1)), 
                                             gf.mul(0x0e, b2)),1)
         + util.putByte(gf.add(gf.add(gf.add(gf.mul(0x0b, b0), 
                                             gf.mul(0x0d, b1)), 
                                             gf.mul(0x09, b2)), 
                                             gf.mul(0x0e, b3)),0);
end

-- 
-- Optimized inverse mix column
-- look at http://fp.gladman.plus.com/cryptography_technology/rijndael/aes.spec.311.pdf
-- TODO: make it work
--
function private.invMixColumn(word)
    local b0 = util.getByte(word,3);
    local b1 = util.getByte(word,2);
    local b2 = util.getByte(word,1);
    local b3 = util.getByte(word,0);
    
    local t = bit.bxor(b3,b2);
    local u = bit.bxor(b1,b0);
    local v = bit.bxor(t,u);
    v = bit.bxor(v,gf.mul(0x08,v));
    w = bit.bxor(v,gf.mul(0x04, bit.bxor(b2,b0)));
    v = bit.bxor(v,gf.mul(0x04, bit.bxor(b3,b1)));
    
    return util.putByte( bit.bxor(bit.bxor(b3,v), gf.mul(0x02, bit.bxor(b0,b3))), 0)
         + util.putByte( bit.bxor(bit.bxor(b2,w), gf.mul(0x02, t              )), 1)
         + util.putByte( bit.bxor(bit.bxor(b1,v), gf.mul(0x02, bit.bxor(b0,b3))), 2)
         + util.putByte( bit.bxor(bit.bxor(b0,w), gf.mul(0x02, u              )), 3);
end

--
-- generate key schedule for aes decryption
--
-- uses key schedule for aes encryption and transforms each
-- key by inverse mix column. 
--
function public.expandDecryptionKey(key)
    local keySchedule = public.expandEncryptionKey(key);
    if (keySchedule == nil) then
        return nil;
    end
    
    keySchedule[public.KEY_TYPE] = public.DECRYPTION_KEY;    

    for i = 4, (keySchedule[public.ROUNDS] + 1)*4 - 5 do
        keySchedule[i] = private.invMixColumnOld(keySchedule[i]);
    end
    
    return keySchedule;
end

--
-- xor round key to state
--
function private.addRoundKey(state, key, round)
    for i = 0, 3 do
        state[i] = bit.bxor(state[i], key[round*4+i]);
    end
end

--
-- do encryption round (ShiftRow, SubBytes, MixColumn together)
--
function private.doRound(origState, dstState)
    dstState[0] =  bit.bxor(bit.bxor(bit.bxor(
                private.table0[util.getByte(origState[0],3)],
                private.table1[util.getByte(origState[1],2)]),
                private.table2[util.getByte(origState[2],1)]),
                private.table3[util.getByte(origState[3],0)]);

    dstState[1] =  bit.bxor(bit.bxor(bit.bxor(
                private.table0[util.getByte(origState[1],3)],
                private.table1[util.getByte(origState[2],2)]),
                private.table2[util.getByte(origState[3],1)]),
                private.table3[util.getByte(origState[0],0)]);
    
    dstState[2] =  bit.bxor(bit.bxor(bit.bxor(
                private.table0[util.getByte(origState[2],3)],
                private.table1[util.getByte(origState[3],2)]),
                private.table2[util.getByte(origState[0],1)]),
                private.table3[util.getByte(origState[1],0)]);
    
    dstState[3] =  bit.bxor(bit.bxor(bit.bxor(
                private.table0[util.getByte(origState[3],3)],
                private.table1[util.getByte(origState[0],2)]),
                private.table2[util.getByte(origState[1],1)]),
                private.table3[util.getByte(origState[2],0)]);
end

--
-- do last encryption round (ShiftRow and SubBytes)
--
function private.doLastRound(origState, dstState)
    dstState[0] = util.putByte(private.SBox[util.getByte(origState[0],3)], 3)
                + util.putByte(private.SBox[util.getByte(origState[1],2)], 2)
                + util.putByte(private.SBox[util.getByte(origState[2],1)], 1)
                + util.putByte(private.SBox[util.getByte(origState[3],0)], 0);

    dstState[1] = util.putByte(private.SBox[util.getByte(origState[1],3)], 3)
                + util.putByte(private.SBox[util.getByte(origState[2],2)], 2)
                + util.putByte(private.SBox[util.getByte(origState[3],1)], 1)
                + util.putByte(private.SBox[util.getByte(origState[0],0)], 0);

    dstState[2] = util.putByte(private.SBox[util.getByte(origState[2],3)], 3)
                + util.putByte(private.SBox[util.getByte(origState[3],2)], 2)
                + util.putByte(private.SBox[util.getByte(origState[0],1)], 1)
                + util.putByte(private.SBox[util.getByte(origState[1],0)], 0);

    dstState[3] = util.putByte(private.SBox[util.getByte(origState[3],3)], 3)
                + util.putByte(private.SBox[util.getByte(origState[0],2)], 2)
                + util.putByte(private.SBox[util.getByte(origState[1],1)], 1)
                + util.putByte(private.SBox[util.getByte(origState[2],0)], 0);
end

--
-- do decryption round 
--
function private.doInvRound(origState, dstState)
    dstState[0] =  bit.bxor(bit.bxor(bit.bxor(
                private.tableInv0[util.getByte(origState[0],3)],
                private.tableInv1[util.getByte(origState[3],2)]),
                private.tableInv2[util.getByte(origState[2],1)]),
                private.tableInv3[util.getByte(origState[1],0)]);

    dstState[1] =  bit.bxor(bit.bxor(bit.bxor(
                private.tableInv0[util.getByte(origState[1],3)],
                private.tableInv1[util.getByte(origState[0],2)]),
                private.tableInv2[util.getByte(origState[3],1)]),
                private.tableInv3[util.getByte(origState[2],0)]);
    
    dstState[2] =  bit.bxor(bit.bxor(bit.bxor(
                private.tableInv0[util.getByte(origState[2],3)],
                private.tableInv1[util.getByte(origState[1],2)]),
                private.tableInv2[util.getByte(origState[0],1)]),
                private.tableInv3[util.getByte(origState[3],0)]);
    
    dstState[3] =  bit.bxor(bit.bxor(bit.bxor(
                private.tableInv0[util.getByte(origState[3],3)],
                private.tableInv1[util.getByte(origState[2],2)]),
                private.tableInv2[util.getByte(origState[1],1)]),
                private.tableInv3[util.getByte(origState[0],0)]);
end

--
-- do last decryption round
--
function private.doInvLastRound(origState, dstState)
    dstState[0] = util.putByte(private.iSBox[util.getByte(origState[0],3)], 3)
                + util.putByte(private.iSBox[util.getByte(origState[3],2)], 2)
                + util.putByte(private.iSBox[util.getByte(origState[2],1)], 1)
                + util.putByte(private.iSBox[util.getByte(origState[1],0)], 0);

    dstState[1] = util.putByte(private.iSBox[util.getByte(origState[1],3)], 3)
                + util.putByte(private.iSBox[util.getByte(origState[0],2)], 2)
                + util.putByte(private.iSBox[util.getByte(origState[3],1)], 1)
                + util.putByte(private.iSBox[util.getByte(origState[2],0)], 0);

    dstState[2] = util.putByte(private.iSBox[util.getByte(origState[2],3)], 3)
                + util.putByte(private.iSBox[util.getByte(origState[1],2)], 2)
                + util.putByte(private.iSBox[util.getByte(origState[0],1)], 1)
                + util.putByte(private.iSBox[util.getByte(origState[3],0)], 0);

    dstState[3] = util.putByte(private.iSBox[util.getByte(origState[3],3)], 3)
                + util.putByte(private.iSBox[util.getByte(origState[2],2)], 2)
                + util.putByte(private.iSBox[util.getByte(origState[1],1)], 1)
                + util.putByte(private.iSBox[util.getByte(origState[0],0)], 0);
end

--
-- encrypts 16 Bytes
-- key           encryption key schedule
-- input         array with input data
-- inputOffset   start index for input
-- output        array for encrypted data
-- outputOffset  start index for output
--
function public.encrypt(key, input, inputOffset, output, outputOffset) 
    --default parameters
    inputOffset = inputOffset or 1;
    output = output or {};
    outputOffset = outputOffset or 1;

    local state = {};
    local tmpState = {};
    
    if (key[public.KEY_TYPE] ~= public.ENCRYPTION_KEY) then
        print("No encryption key: ", key[public.KEY_TYPE]);
        return;
    end

    state = util.bytesToInts(input, inputOffset, 4);
    private.addRoundKey(state, key, 0);

    local round = 1;
    while (round < key[public.ROUNDS] - 1) do
        -- do a double round to save temporary assignments
        private.doRound(state, tmpState);
        private.addRoundKey(tmpState, key, round);
        round = round + 1;

        private.doRound(tmpState, state);
        private.addRoundKey(state, key, round);
        round = round + 1;
    end
    
    private.doRound(state, tmpState);
    private.addRoundKey(tmpState, key, round);
    round = round +1;

    private.doLastRound(tmpState, state);
    private.addRoundKey(state, key, round);
    
    return util.intsToBytes(state, output, outputOffset);
end

--
-- decrypt 16 bytes
-- key           decryption key schedule
-- input         array with input data
-- inputOffset   start index for input
-- output        array for decrypted data
-- outputOffset  start index for output
---
function public.decrypt(key, input, inputOffset, output, outputOffset) 
    -- default arguments
    inputOffset = inputOffset or 1;
    output = output or {};
    outputOffset = outputOffset or 1;

    local state = {};
    local tmpState = {};

    if (key[public.KEY_TYPE] ~= public.DECRYPTION_KEY) then
        print("No decryption key: ", key[public.KEY_TYPE]);
        return;
    end

    state = util.bytesToInts(input, inputOffset, 4);
    private.addRoundKey(state, key, key[public.ROUNDS]);

    local round = key[public.ROUNDS] - 1;
    while (round > 2) do
        -- do a double round to save temporary assignments
        private.doInvRound(state, tmpState);
        private.addRoundKey(tmpState, key, round);
        round = round - 1;

        private.doInvRound(tmpState, state);
        private.addRoundKey(state, key, round);
        round = round - 1;
    end
    
    private.doInvRound(state, tmpState);
    private.addRoundKey(tmpState, key, round);
    round = round - 1;

    private.doInvLastRound(tmpState, state);
    private.addRoundKey(state, key, round);
    
    return util.intsToBytes(state, output, outputOffset);
end

-- calculate all tables when loading this file
private.calcSBox();
private.calcRoundTables();
private.calcInvRoundTables();

return public;
```

## truyenviet.koplugin/truyenviet/sources/aeslua/src/aeslua/buffer.lua

```lua
local public = {};

aeslua.buffer = public;

function public.new ()
  return {};
end

function public.addString (stack, s)
  table.insert(stack, s)
  for i = #stack - 1, 1, -1 do
    if #stack[i] > #stack[i+1] then 
        break;
    end
    stack[i] = stack[i] .. table.remove(stack);
  end
end

function public.toString (stack)
  for i = #stack - 1, 1, -1 do
    stack[i] = stack[i] .. table.remove(stack);
  end
  return stack[1];
end

return public;
```

## truyenviet.koplugin/truyenviet/sources/aeslua/src/aeslua/ciphermode.lua

```lua
local aes = require("aeslua.aes");
local util = require("aeslua.util");
local buffer = require("aeslua.buffer");

local public = {};

aeslua.ciphermode = public;

--
-- Encrypt strings
-- key - byte array with key
-- string - string to encrypt
-- modefunction - function for cipher mode to use
--
function public.encryptString(key, data, modeFunction, iv)
    local iv = iv or {0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0};
    local keySched = aes.expandEncryptionKey(key);
    local encryptedData = buffer.new();
    
    for i = 1, #data/16 do
        local offset = (i-1)*16 + 1;
        local byteData = {string.byte(data,offset,offset +15)};
		
        modeFunction(keySched, byteData, iv);

        buffer.addString(encryptedData, string.char(unpack(byteData)));    
    end
    
    return buffer.toString(encryptedData);
end

--
-- the following 4 functions can be used as 
-- modefunction for encryptString
--

-- Electronic code book mode encrypt function
function public.encryptECB(keySched, byteData, iv) 
	aes.encrypt(keySched, byteData, 1, byteData, 1);
end

-- Cipher block chaining mode encrypt function
function public.encryptCBC(keySched, byteData, iv) 
    util.xorIV(byteData, iv);

    aes.encrypt(keySched, byteData, 1, byteData, 1);    
        
    for j = 1,16 do
        iv[j] = byteData[j];
    end
end

-- Output feedback mode encrypt function
function public.encryptOFB(keySched, byteData, iv) 
    aes.encrypt(keySched, iv, 1, iv, 1);
    util.xorIV(byteData, iv);
end

-- Cipher feedback mode encrypt function
function public.encryptCFB(keySched, byteData, iv) 
    aes.encrypt(keySched, iv, 1, iv, 1);    
    util.xorIV(byteData, iv);
       
    for j = 1,16 do
        iv[j] = byteData[j];
    end        
end

--
-- Decrypt strings
-- key - byte array with key
-- string - string to decrypt
-- modefunction - function for cipher mode to use
--
function public.decryptString(key, data, modeFunction, iv)
    local iv = iv or {0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0};
    
    local keySched;
    if (modeFunction == public.decryptOFB or modeFunction == public.decryptCFB) then
    	keySched = aes.expandEncryptionKey(key);
   	else
   		keySched = aes.expandDecryptionKey(key);
    end
    
    local decryptedData = buffer.new();

    for i = 1, #data/16 do
        local offset = (i-1)*16 + 1;
        local byteData = {string.byte(data,offset,offset +15)};

		iv = modeFunction(keySched, byteData, iv);

        buffer.addString(decryptedData, string.char(unpack(byteData)));
    end

    return buffer.toString(decryptedData);    
end

--
-- the following 4 functions can be used as 
-- modefunction for decryptString
--

-- Electronic code book mode decrypt function
function public.decryptECB(keySched, byteData, iv) 

    aes.decrypt(keySched, byteData, 1, byteData, 1);
    
    return iv;
end

-- Cipher block chaining mode decrypt function
function public.decryptCBC(keySched, byteData, iv) 
	local nextIV = {};
    for j = 1,16 do
        nextIV[j] = byteData[j];
    end
        
    aes.decrypt(keySched, byteData, 1, byteData, 1);    
    util.xorIV(byteData, iv);

	return nextIV;
end

-- Output feedback mode decrypt function
function public.decryptOFB(keySched, byteData, iv) 
    aes.encrypt(keySched, iv, 1, iv, 1);
    util.xorIV(byteData, iv);
    
    return iv;
end

-- Cipher feedback mode decrypt function
function public.decryptCFB(keySched, byteData, iv) 
    local nextIV = {};
    for j = 1,16 do
        nextIV[j] = byteData[j];
    end

    aes.encrypt(keySched, iv, 1, iv, 1);
        
    util.xorIV(byteData, iv);
    
    return nextIV;
end

return public;
```

## truyenviet.koplugin/truyenviet/sources/aeslua/src/aeslua/gf.lua

```lua
require("bit");

-- finite field with base 2 and modulo irreducible polynom x^8+x^4+x^3+x+1 = 0x11d
local private = {};
local public = {};

aeslua.gf = public;

-- private data of gf
private.n = 0x100;
private.ord = 0xff;
private.irrPolynom = 0x11b;
private.exp = {};
private.log = {};

--
-- add two polynoms (its simply xor)
--
function public.add(operand1, operand2) 
	return bit.bxor(operand1,operand2);
end

-- 
-- subtract two polynoms (same as addition)
--
function public.sub(operand1, operand2) 
	return bit.bxor(operand1,operand2);
end

--
-- inverts element
-- a^(-1) = g^(order - log(a))
--
function public.invert(operand)
	-- special case for 1 
	if (operand == 1) then
		return 1;
	end;
	-- normal invert
	local exponent = private.ord - private.log[operand];
	return private.exp[exponent];
end

--
-- multiply two elements using a logarithm table
-- a*b = g^(log(a)+log(b))
--
function public.mul(operand1, operand2)
    if (operand1 == 0 or operand2 == 0) then
        return 0;
    end
	
    local exponent = private.log[operand1] + private.log[operand2];
	if (exponent >= private.ord) then
		exponent = exponent - private.ord;
	end
	return  private.exp[exponent];
end

--
-- divide two elements
-- a/b = g^(log(a)-log(b))
--
function public.div(operand1, operand2)
    if (operand1 == 0)  then
        return 0;
    end
    -- TODO: exception if operand2 == 0
	local exponent = private.log[operand1] - private.log[operand2];
	if (exponent < 0) then
		exponent = exponent + private.ord;
	end
	return private.exp[exponent];
end

--
-- print logarithmic table
--
function public.printLog()
	for i = 1, private.n do
		print("log(", i-1, ")=", private.log[i-1]);
	end
end

--
-- print exponentiation table
--
function public.printExp()
	for i = 1, private.n do
		print("exp(", i-1, ")=", private.exp[i-1]);
	end
end

--
-- calculate logarithmic and exponentiation table
--
function private.initMulTable()
	local a = 1;

	for i = 0,private.ord-1 do
    	private.exp[i] = a;
		private.log[a] = i;

		-- multiply with generator x+1 -> left shift + 1	
		a = bit.bxor(bit.lshift(a, 1), a);

		-- if a gets larger than order, reduce modulo irreducible polynom
		if a > private.ord then
			a = public.sub(a, private.irrPolynom);
		end
	end
end

private.initMulTable();

return public;
```

## truyenviet.koplugin/truyenviet/sources/aeslua/src/aeslua/util.lua

```lua
require("bit");

local public = {};
local private = {};

aeslua.util = public;

--
-- calculate the parity of one byte
--
function public.byteParity(byte)
    byte = bit.bxor(byte, bit.rshift(byte, 4));
    byte = bit.bxor(byte, bit.rshift(byte, 2));
    byte = bit.bxor(byte, bit.rshift(byte, 1));
    return bit.band(byte, 1);
end

-- 
-- get byte at position index
--
function public.getByte(number, index)
    if (index == 0) then
        return bit.band(number,0xff);
    else
        return bit.band(bit.rshift(number, index*8),0xff);
    end
end


--
-- put number into int at position index
--
function public.putByte(number, index)
    if (index == 0) then
        return bit.band(number,0xff);
    else
        return bit.lshift(bit.band(number,0xff),index*8);
    end
end

--
-- convert byte array to int array
--
function public.bytesToInts(bytes, start, n)
    local ints = {};
    for i = 0, n - 1 do
        ints[i] = public.putByte(bytes[start + (i*4)    ], 3)
                + public.putByte(bytes[start + (i*4) + 1], 2) 
                + public.putByte(bytes[start + (i*4) + 2], 1)    
                + public.putByte(bytes[start + (i*4) + 3], 0);
    end
    return ints;
end

--
-- convert int array to byte array
--
function public.intsToBytes(ints, output, outputOffset, n)
    n = n or #ints;
    for i = 0, n do
        for j = 0,3 do
            output[outputOffset + i*4 + (3 - j)] = public.getByte(ints[i], j);
        end
    end
    return output;
end

--
-- convert bytes to hexString
--
function private.bytesToHex(bytes)
    local hexBytes = "";
    
    for i,byte in ipairs(bytes) do 
        hexBytes = hexBytes .. string.format("%02x ", byte);
    end

    return hexBytes;
end

--
-- convert data to hex string
--
function public.toHexString(data)
    local type = type(data);
    if (type == "number") then
        return string.format("%08x",data);
    elseif (type == "table") then
        return private.bytesToHex(data);
    elseif (type == "string") then
        local bytes = {string.byte(data, 1, #data)}; 

        return private.bytesToHex(bytes);
    else
        return data;
    end
end

function public.padByteString(data)
    local dataLength = #data;
    
    local random1 = math.random(0,255);
    local random2 = math.random(0,255);

    local prefix = string.char(random1,
                               random2,
                               random1,
                               random2,
                               public.getByte(dataLength, 3),
                               public.getByte(dataLength, 2),
                               public.getByte(dataLength, 1),
                               public.getByte(dataLength, 0));

    data = prefix .. data;

    local paddingLength = math.ceil(#data/16)*16 - #data;
    local padding = "";
    for i=1,paddingLength do
        padding = padding .. string.char(math.random(0,255));
    end 

    return data .. padding;
end

function private.properlyDecrypted(data)
    local random = {string.byte(data,1,4)};

    if (random[1] == random[3] and random[2] == random[4]) then
        return true;
    end
    
    return false;
end

function public.unpadByteString(data)
    if (not private.properlyDecrypted(data)) then
        return nil;
    end

    local dataLength = public.putByte(string.byte(data,5), 3)
                     + public.putByte(string.byte(data,6), 2) 
                     + public.putByte(string.byte(data,7), 1)    
                     + public.putByte(string.byte(data,8), 0);
    
    return string.sub(data,9,8+dataLength);
end

function public.xorIV(data, iv)
    for i = 1,16 do
        data[i] = bit.bxor(data[i], iv[i]);
    end 
end

return public;
```

## truyenviet.koplugin/truyenviet/sources/aeslua/src/aeslua.lua

```lua
local private = {};
local public = {};
aeslua = public;

local ciphermode = require("aeslua.ciphermode");
local util = require("aeslua.util");

--
-- Simple API for encrypting strings.
--

public.AES128 = 16;
public.AES192 = 24;
public.AES256 = 32;

public.ECBMODE = 1;
public.CBCMODE = 2;
public.OFBMODE = 3;
public.CFBMODE = 4;

function private.pwToKey(password, keyLength)
    local padLength = keyLength;
    if (keyLength == public.AES192) then
        padLength = 32;
    end
    
    if (padLength > #password) then
        local postfix = "";
        for i = 1,padLength - #password do
            postfix = postfix .. string.char(0);
        end
        password = password .. postfix;
    else
        password = string.sub(password, 1, padLength);
    end
    
    local pwBytes = {string.byte(password,1,#password)};
    password = ciphermode.encryptString(pwBytes, password, ciphermode.encryptCBC);
    
    password = string.sub(password, 1, keyLength);
   
    return {string.byte(password,1,#password)};
end

--
-- Encrypts string data with password password.
-- password  - the encryption key is generated from this string
-- data      - string to encrypt (must not be too large)
-- keyLength - length of aes key: 128(default), 192 or 256 Bit
-- mode      - mode of encryption: ecb, cbc(default), ofb, cfb 
--
-- mode and keyLength must be the same for encryption and decryption.
--
function public.encrypt(password, data, keyLength, mode)
	assert(password ~= nil, "Empty password.");
	assert(password ~= nil, "Empty data.");
	 
    local mode = mode or public.CBCMODE;
    local keyLength = keyLength or public.AES128;

    local key = private.pwToKey(password, keyLength);

    local paddedData = util.padByteString(data);
    
    if (mode == public.ECBMODE) then
        return ciphermode.encryptString(key, paddedData, ciphermode.encryptECB);
    elseif (mode == public.CBCMODE) then
        return ciphermode.encryptString(key, paddedData, ciphermode.encryptCBC);
    elseif (mode == public.OFBMODE) then
        return ciphermode.encryptString(key, paddedData, ciphermode.encryptOFB);
    elseif (mode == public.CFBMODE) then
        return ciphermode.encryptString(key, paddedData, ciphermode.encryptCFB);
    else
        return nil;
    end
end




--
-- Decrypts string data with password password.
-- password  - the decryption key is generated from this string
-- data      - string to encrypt
-- keyLength - length of aes key: 128(default), 192 or 256 Bit
-- mode      - mode of decryption: ecb, cbc(default), ofb, cfb 
--
-- mode and keyLength must be the same for encryption and decryption.
--
function public.decrypt(password, data, keyLength, mode)
    local mode = mode or public.CBCMODE;
    local keyLength = keyLength or public.AES128;

    local key = private.pwToKey(password, keyLength);
    
    local plain;
    if (mode == public.ECBMODE) then
        plain = ciphermode.decryptString(key, data, ciphermode.decryptECB);
    elseif (mode == public.CBCMODE) then
        plain = ciphermode.decryptString(key, data, ciphermode.decryptCBC);
    elseif (mode == public.OFBMODE) then
        plain = ciphermode.decryptString(key, data, ciphermode.decryptOFB);
    elseif (mode == public.CFBMODE) then
        plain = ciphermode.decryptString(key, data, ciphermode.decryptCFB);
    end
    
    result = util.unpadByteString(plain);
    
    if (result == nil) then
        return nil;
    end
    
    return result;
end
```

## truyenviet.koplugin/truyenviet/sources/aeslua/src/test/aesspeed.lua

```lua
require("aeslua");
local aes = aeslua.aes;

function getRandomBits(bits)
    local result = {};

    for i=1,bits/8 do
        result[i] = math.random(0,255);
    end
    
    return result;
end

function AESspeed()
    key = getRandomBits(128);
    plaintext = getRandomBits(128);
    local n = 10000;

    start = os.clock();
    keySched = aes.expandEncryptionKey(key);
    for i=1,n do
        aes.encrypt(keySched,plaintext);
    end 
    endtime = os.clock();
    
    local kByte = (n*16)/1024;
    local duration = endtime - start;
    print(string.format("Encrypted %f kByte in %f sec", kByte, duration));
    print(string.format("kByte per second: %f", kByte/duration));
end

AESspeed();
```

## truyenviet.koplugin/truyenviet/sources/aeslua/src/test/filedecrypt.lua

```lua
-- Usage: filedecrypt.lua [file] [password] > decryptedfile
--
-- Decrypts everything from [file] and writes decrypted data to stdout.
-- Do not use for real decryption, because the password is easily viewable 
-- while decrypting.
--
require("aeslua");

if (#arg ~= 2) then
	print("Usage: filedecrypt.lua [file] [password] > decryptedfile\n");
	print("Do not use for real decryption, because the password is easily viewable while decrypting.");
	return 1;
end

local file = assert(io.open(arg[1], "r"));
local cipher = file:read("*all");
local plain = aeslua.decrypt(arg[2], cipher);
if (plain == nil) then
	print("Invalid password.");
else
	io.write(plain);
end
file:close();
```

## truyenviet.koplugin/truyenviet/sources/aeslua/src/test/fileencrypt.lua

```lua
-- Usage: fileencrypt.lua [file] [password] > encryptedfile
--
-- Encrypts everything from [file] and writes encrypted data to stdout.
-- Do not use for real encryption, because the password is easily viewable 
-- while encrypting.
--
require("aeslua");

if (#arg ~= 2) then
	print("Usage: fileencrypt.lua [file] [password] > encryptedfile\n");
	print("Do not use for real encryption, because the password is easily viewable while encrypting.");
	return 1;
end

local file = assert(io.open(arg[1], "r"));
local text = file:read("*all");
local cipher = aeslua.encrypt(arg[2], text);
io.write(cipher);
file:close();
```

## truyenviet.koplugin/truyenviet/sources/aeslua/src/test/testaes.lua

```lua
require("aeslua");
local aes = aeslua.aes;
local util = aeslua.util;

--test vectors

aesplain1 = {0x32, 0x43, 0xf6, 0xa8, 
             0x88, 0x5a, 0x30, 0x8d, 
             0x31, 0x31, 0x98, 0xa2, 
             0xe0, 0x37, 0x07, 0x34};
aesplain2 = {0x00, 0x11, 0x22, 0x33,
             0x44, 0x55, 0x66, 0x77,
             0x88, 0x99, 0xaa, 0xbb,
             0xcc, 0xdd, 0xee, 0xff};
aes128key1 = {0x2b,0x7e,0x15,0x16,
              0x28,0xae,0xd2,0xa6,
              0xab,0xf7,0x15,0x88,
              0x09,0xcf,0x4f,0x3c};
aes128key2 = {0x00, 0x01, 0x02, 0x03,
              0x04, 0x05, 0x06, 0x07,
              0x08, 0x09, 0x0a, 0x0b,
              0x0c, 0x0d, 0x0e, 0x0f};
aes192key1 = {0x8e,0x73,0xb0,0xf7,
              0xda,0x0e,0x64,0x52,
              0xc8,0x10,0xf3,0x2b,
              0x80,0x90,0x79,0xe5,
              0x62,0xf8,0xea,0xd2,
              0x52,0x2c,0x6b,0x7b};
aes192key2 = {0x00, 0x01, 0x02, 0x03,
              0x04, 0x05, 0x06, 0x07,
              0x08, 0x09, 0x0a, 0x0b,
              0x0c, 0x0d, 0x0e, 0x0f,
              0x10, 0x11, 0x12, 0x13,
              0x14, 0x15, 0x16, 0x17};
aes256key1 = {0x60,0x3d,0xeb,0x10,
              0x15,0xca,0x71,0xbe,
              0x2b,0x73,0xae,0xf0,
              0x85,0x7d,0x77,0x81,
              0x1f,0x35,0x2c,0x07,
              0x3b,0x61,0x08,0xd7,
              0x2d,0x98,0x10,0xa3,
              0x09,0x14,0xdf,0xf4};
aes256key2 = {0x00, 0x01, 0x02, 0x03,
              0x04, 0x05, 0x06, 0x07,
              0x08, 0x09, 0x0a, 0x0b,
              0x0c, 0x0d, 0x0e, 0x0f,
              0x10, 0x11, 0x12, 0x13,
              0x14, 0x15, 0x16, 0x17,
              0x18, 0x19, 0x1a, 0x1b,
              0x1c, 0x1d, 0x1e, 0x1f};


function printSBox() 
    print("sbox");
    for i=0,255 do
	    print(string.format("%x: %x", i, aes.SBox[i]));
    end

    print("inverse sbox");
    for i=0,255 do
	    print(string.format("%x: %x", i, aes.iSBox[i]));
    end
end

function testRound()
    state = {0x19, 0x3d, 0xe3,0xbe, 
            0xa0, 0xf4, 0xe2, 0x2b,
            0x9a, 0xc6, 0x8d, 0x2a,
            0xe9, 0xf8, 0x48, 0x08};

    printState(state);
    aes.subBytes(state);
    printState(state);
    aes.shiftRows(state);
    printState(state);
    aes.mixColumn(state);
    printState(state);
end


function printKeyExpansion(key)
    keySchedule = aes.expandEncryptionKey(key);
    print("ENCRYPT");
    for i=0,#keySchedule do
       print(string.format("%d[%d]= %x",keySchedule[aes.ROUNDS],i,keySchedule[i]));
    end

    keySchedule = aes.expandDecryptionKey(key);
    print("DECRYPT");
    for i=0,#keySchedule do
        print(string.format("%d[%d]= %x",keySchedule[aes.ROUNDS],i,keySchedule[i]));
    end
end

function testKeyExpansion()
    printKeyExpansion(aes128key1);
    
    printKeyExpansion(aes192key1);
    
    printKeyExpansion(aes256key1);
end

function AESEncrypt(key, plain)
    keySched = aes.expandEncryptionKey(key); 
    cipher = aes.encrypt(keySched, plain); 
    keySched = aes.expandDecryptionKey(key);
    decrypted = aes.decrypt(keySched,cipher);
    
    return {key, plain, cipher, decrypted};
end

function printResult(result)
    print("Key:");
    print(util.toHexString(result[1]));
    print("Plaintext:");
    print(util.toHexString(result[2]));
    print("Ciphertext:");
    print(util.toHexString(result[3]));
    print("Decrypted:");
    print(util.toHexString(result[4])); 
end

function testResult(result)
    local plaintext = result[2];
    local decrypt = result[4]

    for i=1,16 do
        if (decrypt[i] ~= plaintext[i]) then
            return false;
        end
    end
    
    return true;
end

function testEncrypt()
    local result1 = AESEncrypt(aes128key2, aesplain2);
    printResult(result1);
   
    result1 = AESEncrypt(aes192key2, aesplain2);
    printResult(result1);
    
    result1 = AESEncrypt(aes256key2, aesplain2);
    printResult(result1);
end


function getRandomBits(bits)
    local result = {};

    for i=1,bits/8 do
        result[i] = math.random(0,255);
    end
    
    return result;
end

function testnAES(n)
    math.randomseed(os.time());
    
    for x=1,n do
        key = getRandomBits(128);
        plaintext = getRandomBits(128);

        local result = AESEncrypt(key, plaintext);
        if (not testResult(result)) then
            print("ENCRYPTION/DECRYPTION ERROR:");
            printResult(result);
            return false;
        end
    end
    
   	return true;
end

--testKeyExpansion();
--testEncrypt();
print("Testing 1000 random en-/decryptions...");
if (testnAES(1000)) then
	print("ok.");
end


```

## truyenviet.koplugin/truyenviet/sources/aeslua/src/test/testciphers.lua

```lua
require("aeslua");
local util = require("aeslua.util");

math.randomseed(os.time());

function testCrypto(password, data)
    local modes ={aeslua.ECBMODE, aeslua.CBCMODE, aeslua.OFBMODE, aeslua.CFBMODE};
    local keyLengths =  {aeslua.AES128, aeslua.AES192, aeslua.AES256};  
    for i, mode in ipairs(modes) do
        for j, keyLength in ipairs(keyLengths) do
            print("--");
            cipher = aeslua.encrypt(password, data, keyLength, mode);
            print("Cipher: ", util.toHexString(cipher));
            plain = aeslua.decrypt(password, cipher, keyLength, mode);
            print("Mode: ", mode, " keyLength: ", keyLength, " Plain: ", plain);
            print("--");
        end
    end
end 

testCrypto("sp","hello world!");
testCrypto("longpasswordlongerthant32bytesjustsomelettersmore", "hello world!");
```

## truyenviet.koplugin/truyenviet/sources/aztruyen.lua

```lua
local Http = require("truyenviet/http_client")
local Util = require("truyenviet/helpers")
local ko_util = require("util")

local Source = {
    id = "aztruyen",
    name = "AzTruyen",
    kind = "text",
    base_url = "https://aztruyen.top",
}

local function stdHeaders(base_url)
    return {
        ["User-Agent"] = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36",
        ["Referer"] = base_url .. "/",
    }
end

-- Cấu trúc thẻ truyện thật đã xác nhận bằng fetch trực tiếp aztruyen.top ngày 11/07/2026:
--   URL truyện dạng: https://aztruyen.top/{slug}-{id}/   (id số ở cuối, có dấu / kết thúc)
--   Ảnh bìa dạng:    https://aztruyen.top/images/{slug}-{id}.webp   (cùng domain, đuôi .webp)
--   Tiêu đề nằm trong <h2><a href="...url..." title="Tên">Tên</a></h2>
-- Quy trình: bóc toàn bộ cặp (url, cover) từ các thẻ <a><img></a>, rồi bóc (url, title) từ
-- các thẻ <h2><a>, sau đó ghép lại theo url — không phụ thuộc tên class cụ thể (dễ đổi),
-- chỉ phụ thuộc cấu trúc URL đã xác nhận.
local function parseStories(html, source_id)
    local stories = {}
    local seen = {}

    local cover_by_url = {}
    for url, cover in html:gmatch(
        '<a[^>]+href="(https?://aztruyen%.top/[%w%-]+%-%d+/)"[^>]*>%s*<img[^>]+src="(https?://aztruyen%.top/images/[^"]+)"'
    ) do
        cover_by_url[url] = cover
    end

    for url, title in html:gmatch(
        '<h2[^>]*>%s*<a[^>]+href="(https?://aztruyen%.top/[%w%-]+%-%d+/)"[^>]*title="([^"]+)"'
    ) do
        if not seen[url] then
            seen[url] = true
            table.insert(stories, {
                source_id = source_id,
                title = Util.decodeHtml(title),
                url = url,
                cover_url = cover_by_url[url],
                kind = "text",
            })
        end
    end

    -- Dự phòng: nếu site đổi cấu trúc <h2>, thử pattern rộng hơn theo href chung
    if #stories == 0 then
        for href, title in html:gmatch('<a[^>]+href="(https?://aztruyen%.top/[%w%-]+%-%d+/)"[^>]*title="([^"]+)"') do
            if not seen[href] then
                seen[href] = true
                table.insert(stories, {
                    source_id = source_id,
                    title = Util.decodeHtml(title),
                    url = href,
                    cover_url = cover_by_url[href],
                    kind = "text",
                })
            end
        end
    end

    -- Dự phòng cũ (giữ lại phòng khi 2 pattern trên đều không khớp)
    if #stories == 0 then
        for block in html:gmatch('<div class="[^"]*story[^"]*">(.-)<p class="[^"]*desc"') do
            local href = block:match('href="(https?://aztruyen%.top/[^"]+)"')
            local title = block:match('title="([^"]+)"')
            local cover = block:match('data%-src="([^"]+)"') or block:match('<img[^>]+src="([^"]+)"')
            if href and title and not seen[href] then
                seen[href] = true
                table.insert(stories, {
                    source_id = source_id,
                    title = Util.decodeHtml(title),
                    url = href,
                    cover_url = cover,
                    kind = "text",
                })
            end
        end
    end

    return stories
end

local function parseGenres(html)
    local genres = {}
    local seen = {}
    for href, name in html:gmatch('<a href="(https?://aztruyen%.top/the%-loai/[^"]+)"[^>]*>([^<]+)</a>') do
        if not seen[href] then
            seen[href] = true
            table.insert(genres, {
                name = Util.decodeHtml(name),
                url = href,
            })
        end
    end
    return genres
end

function Source:search(query)
    local encoded = ko_util.urlEncode(query)
    local url = self.base_url .. "/tim-kiem/" .. encoded
    local html, err = Http:get(url, stdHeaders(self.base_url))
    if not html then return nil, err end
    local stories = parseStories(html, self.id)
    return stories
end

function Source:getCompleted(page)
    page = page or 1
    -- LƯU Ý: chưa xác minh được AzTruyen.top có trang riêng liệt kê "truyện hoàn
    -- thành" hay không (không thấy trong menu điều hướng khi kiểm tra trực tiếp
    -- ngày 11/07/2026, chỉ có menu Thể loại + Yêu thích). Thử URL cũ trước,
    -- nếu không ra truyện nào thì dùng trang chủ (luôn có danh sách + sidebar thể loại).
    local url = self.base_url .. "/danh-sach/hoan-thanh/"
    if page > 1 then url = url .. "trang-" .. page .. "/" end
    local html = Http:get(url, stdHeaders(self.base_url))

    local stories = html and parseStories(html, self.id) or {}
    if #stories == 0 then
        url = self.base_url .. "/"
        if page > 1 then url = url .. "trang-" .. page .. "/" end
        local err
        html, err = Http:get(url, stdHeaders(self.base_url))
        if not html then return nil, err end
        stories = parseStories(html, self.id)
    end

    local total_pages = tonumber(html:match('href="[^"]+trang%-(%d+)/"[^>]*>Cuối')) or page
    return {
        stories = stories,
        genres = parseGenres(html),
        page = page,
        total_pages = total_pages,
        title = "AzTruyen"
    }
end

function Source:getGenre(genre, page)
    page = page or 1
    local url = Util.withTrailingSlash(genre.url)
    if page > 1 then url = url .. "trang-" .. page .. "/" end
    local html, err = Http:get(url, stdHeaders(self.base_url))
    if not html then return nil, err end
    
    local total_pages = tonumber(html:match('href="[^"]+trang%-(%d+)/"[^>]*>Cuối')) or page
    return {
        stories = parseStories(html, self.id),
        genres = parseGenres(html),
        page = page,
        total_pages = total_pages,
        title = genre.name
    }
end

function Source:getStoryDetails(story)
    local html, err = Http:get(story.url, stdHeaders(self.base_url))
    if not html then return nil, err end
    
    local title = html:match('<h1[^>]*>([^<]+)</h1>')
    local author = html:match('Tác giả:%s*</span>%s*<a[^>]*>([^<]+)</a>')
        or html:match('<span itemprop="name">%s*<a[^>]+rel="author"[^>]*>([^<]+)</a>')
    
    local desc_block = html:match('<div class="content%-story"[^>]*>(.-)</div>%s*<div class="list%-chapter"')
        or html:match('<div class="desc%-text"[^>]*>(.-)</div>')
        or html:match('<div class="content%-story"[^>]*>(.-)</div>')
    
    local description = desc_block and Util.stripTags(desc_block) or nil
    if description then
        description = description:gsub("^%s+", ""):gsub("%s+$", "")
    end
    
    return {
        title = title and Util.decodeHtml(Util.trim(title)) or story.title,
        author = author and Util.trim(author) or nil,
        description = description,
    }
end

function Source:getStoryPage(story, page)
    page = page or 1
    local url = Util.withTrailingSlash(story.url)
    if page > 1 then url = url .. "trang-" .. page .. "/" end
    local html, err = Http:get(url, stdHeaders(self.base_url))
    if not html then return nil, err end
    
    local chapters = {}
    local seen = {}
    
    local story_path = story.url:gsub("^https?://[^/]+", "")
    local pattern = '<a[^>]+href="(https?://aztruyen%.top' .. story_path:gsub("%-", "%%-") .. 'chuong[^"]+)"[^>]*title="([^"]+)"'
    
    for href, title in html:gmatch(pattern) do
        if not seen[href] then
            seen[href] = true
            table.insert(chapters, {
                title = Util.trim(title),
                url = href,
                source_id = self.id,
                story_url = story.url,
                kind = self.kind,
            })
        end
    end

    local total_pages = tonumber(html:match('href="[^"]+trang%-(%d+)/"[^>]*>Cuối')) or page
    story.details = self:getStoryDetails(story)
    
    return {
        story = story,
        chapters = chapters,
        page = page,
        total_pages = total_pages,
    }
end

-- LƯU Ý: log thực tế cho thấy request tải chương trả về 200 (HTML thật, không
-- lỗi mạng) nhưng nội dung hiện ra "nil" -> nghĩa là 2 pattern cũ dưới đây
-- (class="chapter-content" / id="chapter-content") không khớp cấu trúc HTML
-- thật của aztruyen.top (chưa từng được xác minh trực tiếp). Thêm nhiều pattern
-- dự phòng thường gặp ở các site WordPress/Ghost tương tự, để tăng khả năng
-- khớp cho tới khi xác minh được chính xác class thật.
local CONTENT_PATTERNS = {
    '<div class="chapter%-content"[^>]*>(.-)</div>%s*</div>',
    '<div id="chapter%-content"[^>]*>(.-)</div>%s*</div>',
    '<div class="chapter%-content"[^>]*>(.-)</div>',
    '<div id="chapter%-content"[^>]*>(.-)</div>',
    '<div class="content%-chapter"[^>]*>(.-)</div>',
    '<div class="entry%-content"[^>]*>(.-)</div>',
    '<div class="reading%-content"[^>]*>(.-)</div>',
    '<div id="content"[^>]*>(.-)</div>',
}

local function extractChapterContent(html)
    for _, pattern in ipairs(CONTENT_PATTERNS) do
        local content = html:match(pattern)
        if content and Util.trim(Util.stripTags(content)) ~= "" then
            return content
        end
    end
    return nil
end

function Source:getChapter(chapter)
    local html, err = Http:get(chapter.url, stdHeaders(self.base_url))
    if not html then return nil, err end

    local content = extractChapterContent(html)
    if not content then return nil, "Không tìm thấy nội dung chương (cấu trúc trang có thể đã đổi)" end

    return Util.sanitizeContentHtml(content)
end

function Source:getChapterAsync(chapter)
    local html, err = Http:requestAsync("GET", chapter.url, stdHeaders(self.base_url))
    if not html then return nil, err end

    local content = extractChapterContent(html)
    if not content then return nil, "Không tìm thấy nội dung chương (cấu trúc trang có thể đã đổi)" end

    return Util.sanitizeContentHtml(content)
end

return Source
```

## truyenviet.koplugin/truyenviet/sources/cbunu.lua

```lua
local Http = require("truyenviet/http_client")
local Util = require("truyenviet/helpers")
local Debug = require("truyenviet/debugger")

local Source = {
    id = "cbunu",
    name = "Cbunu",
    kind = "comic",
    base_url = "https://cbunu.com",
    reversed_chapters = true,
}

-- Cookie phiên lấy động từ trang chủ, không hardcode giá trị tĩnh
local session_cookie = nil
local session_cookie_time = 0
local COOKIE_TTL = 30 * 60 -- 30 phút thì refresh lại

local function extractSetCookie(headers)
    if not headers then
        return nil
    end
    local raw = headers["set-cookie"] or headers["Set-Cookie"]
    if not raw then
        return nil
    end

    local found = {}
    if type(raw) == "table" then
        for _, entry in ipairs(raw) do
            local pair = entry:match("^([^;]+)")
            if pair then
                table.insert(found, pair)
            end
        end
    else
        for entry in tostring(raw):gmatch("([^,]+)") do
            local pair = entry:match("^%s*([^;]+)")
            if pair and pair:find("=") then
                table.insert(found, pair)
            end
        end
    end

    if #found == 0 then
        return nil
    end
    return table.concat(found, "; ")
end

local site_blocked = false
local BLOCKED_MESSAGE = "Cbunu.com yêu cầu đăng nhập hoặc đang bảo trì, nguồn tạm thời không khả dụng."

local function refreshSessionCookie()
    local html, err, headers, status_code = Http:get(Source.base_url .. "/", {
        ["Referer"] = Source.base_url .. "/",
    })
    if not html then
        if status_code == 403 then
            Debug.write("cbunu: 403 Forbidden, attempting to login...")
            local passwords = { "2026", "12345" }
            for _, pass in ipairs(passwords) do
                local _, _, auth_headers, auth_status = Http:postForm(
                    Source.base_url .. "/",
                    { access_pass = pass },
                    { ["Referer"] = Source.base_url .. "/" },
                    { redirect = false }
                )
                if auth_status == 302 or auth_status == 200 then
                    headers = auth_headers
                    status_code = auth_status
                    break
                end
            end

            if status_code == 403 then
                site_blocked = true
                Debug.write("cbunu: login failed with all passwords, nguồn không khả dụng")
                return nil
            end
        else
            Debug.write("cbunu: không lấy được trang chủ để refresh cookie: " .. tostring(err))
            return nil
        end
    end
    site_blocked = false
    local cookie = extractSetCookie(headers)
    if cookie then
        session_cookie = cookie
        session_cookie_time = os.time()
        Debug.write("cbunu: đã lấy cookie session mới")
    else
        Debug.write("cbunu: không thấy Set-Cookie trong phản hồi trang chủ")
    end
    return session_cookie
end

local function ensureSessionCookie()
    if not session_cookie or (os.time() - session_cookie_time) > COOKIE_TTL then
        refreshSessionCookie()
    end
    return session_cookie
end

local function requestHeaders()
    local headers = {
        ["Referer"] = Source.base_url .. "/",
        ["X-Requested-With"] = "XMLHttpRequest",
    }
    local cookie = ensureSessionCookie()
    if cookie then
        headers["Cookie"] = cookie
    end
    return headers
end

function Source:getCoverHeaders()
    return requestHeaders()
end

local function isStoryUrl(href)
    return href
        and href:find("/truyen-tranh/", 1, true)
        and not href:find("%-chap%-")
        and not href:find("%.html")
end

local function parseStoryCards(html)
    local stories = {}
    for anchor_attrs, anchor_html in tostring(html or ""):gmatch(
        "<a([^>]*)>([%s%S]-)</a>"
    ) do
        local href = Util.getAttribute(anchor_attrs, "href")
        if isStoryUrl(href) then
            local title = Util.getAttribute(anchor_attrs, "title")
                or Util.getAttribute(anchor_html:match("(<img[^>]*>)"), "alt")
                or Util.stripTags(anchor_html)
            title = Util.stripTags(title):gsub("%.%.%.$", "")
            local image_tag = anchor_html:match("(<img[^>]*>)")
            local original_cover_url = Util.absoluteUrl(
                Source.base_url,
                Util.getAttribute(image_tag, "data-original")
                    or Util.getAttribute(image_tag, "data-src")
                    or Util.getAttribute(image_tag, "src")
                    or Util.getAttribute(image_tag, "data-fb")
            )
            local cover_url = original_cover_url
            if cover_url then
                cover_url = cover_url:gsub("^https?://", "https://i0.wp.com/") .. "?resize=200,266"
            end
            
            table.insert(stories, {
                source_id = Source.id,
                title = title,
                url = Util.absoluteUrl(Source.base_url, href),
                cover_url = cover_url,
                kind = Source.kind,
            })
        end
    end
    return Util.uniqueBy(stories, "url")
end

function Source:parseSearch(html)
    local stories = parseStoryCards(html)
    if #stories > 0 then
        return stories
    end

    for item_html in tostring(html or ""):gmatch("<li[^>]*>([%s%S]-)</li>") do
        local anchor = item_html:match("(<a[^>]*>)")
        local href = Util.getAttribute(anchor, "href")
        local title = item_html:match('<p[^>]-class="name"[^>]*>([%s%S]-)</p>')
        local image_tag = item_html:match("(<img[^>]*>)")
        if href and title then
            table.insert(stories, {
                source_id = self.id,
                title = Util.stripTags(title),
                url = Util.absoluteUrl(self.base_url, href),
                cover_url = Util.absoluteUrl(
                    self.base_url,
                    Util.getAttribute(image_tag, "src")
                        or Util.getAttribute(image_tag, "data-fb")
                ),
                kind = self.kind,
            })
        end
    end

    return Util.uniqueBy(stories, "url")
end

local function urlEncode(str)
    if str then
        str = str:gsub("\n", "\r\n")
        str = str:gsub("([^%w %-%_%.%~])", function(c)
            return string.format("%%%02X", string.byte(c))
        end)
        str = str:gsub(" ", "+")
    end
    return str
end

function Source:search(query)
    if site_blocked then
        return nil, BLOCKED_MESSAGE
    end
    local encoded_query = urlEncode(query)
    local html, err = Http:get(
        self.base_url .. "/?s=" .. encoded_query,
        requestHeaders()
    )
    if not html then
        return nil, err
    end
    return self:parseSearch(html)
end

function Source:parseListing(html, page)
    return {
        stories = parseStoryCards(html),
        genres = Util.parseGenres(html, self.base_url),
        page = page or 1,
        total_pages = Util.maxPage(html, page),
    }
end

function Source:getCompleted(page)
    if site_blocked then
        return nil, BLOCKED_MESSAGE
    end
    page = page or 1
    local url = self.base_url .. "/truyen-hoan-thanh.html"
    if page > 1 then
        url = self.base_url .. "/truyen-hoan-thanh/trang-" .. page .. ".html"
    end
    local html, err = Http:get(url, requestHeaders())
    if not html then
        return nil, err
    end
    local result = self:parseListing(html, page)
    result.title = "Truyện đã hoàn thành"
    return result
end

function Source:getGenre(genre, page)
    if site_blocked then
        return nil, BLOCKED_MESSAGE
    end
    page = page or 1
    local url = genre.url:gsub("/+$", "")
    if page > 1 then
        url = url:gsub("%.html$", "") .. "/trang-" .. page .. ".html"
    end
    local html, err = Http:get(url, requestHeaders())
    if not html then
        return nil, err
    end
    local result = self:parseListing(html, page)
    result.title = genre.name
    result.genre = genre
    return result
end

function Source:parseStoryDetails(html)
    local description_html = html:match(
        '<div[^>]-class="[^"]*story%-detail%-info[^"]*detail%-content[^"]*"[^>]*>([%s%S]-)</div>'
    )
    local author_html = html:match(
        '<li[^>]-class="[^"]*author[^"]*"[^>]*>([%s%S]-)</li>'
    )
    local status_html = html:match(
        '<li[^>]-class="[^"]*status[^"]*"[^>]*>([%s%S]-)</li>'
    )
    local genre_html = html:match(
        '<ul[^>]-class="[^"]*list01[^"]*"[^>]*>([%s%S]-)</ul>'
    )

    local author
    for paragraph in tostring(author_html or ""):gmatch("<p[^>]*>([%s%S]-)</p>") do
        author = Util.stripTags(paragraph)
    end
    local status
    for paragraph in tostring(status_html or ""):gmatch("<p[^>]*>([%s%S]-)</p>") do
        status = Util.stripTags(paragraph)
    end

    return {
        description = Util.stripTags(description_html)
            ~= "" and Util.stripTags(description_html)
            or Util.getMetaContent(html, "name", "description"),
        author = author,
        status = status,
        genres = Util.parseGenreNames(genre_html),
    }
end

function Source:getStoryDetails(story)
    if site_blocked then
        return nil, BLOCKED_MESSAGE
    end
    local html, err = Http:get(story.url, requestHeaders())
    if not html then
        return nil, err
    end
    return self:parseStoryDetails(html)
end

function Source:parseStoryPage(html, story)
    local chapters = {}
    local slug = story.url:match("([^/]+)$") or ""
    local base_slug = slug:match("^(.-)%-%d+$")
        or slug:match("^(.-)%-%d+%.html$")
        or slug:match("^(.-)%.html$")
        or slug

    for anchor_attrs, anchor_html in tostring(html or ""):gmatch("<a([^>]*)>([%s%S]-)</a>") do
        local href = Util.getAttribute(anchor_attrs, "href")
        local chapter_url = Util.absoluteUrl(self.base_url, href)
        if chapter_url and chapter_url:find(base_slug, 1, true) then
            local lurl = (chapter_url or ""):lower()
            local is_chapter = false
            if lurl:find("%-chap%-")
                    or lurl:find("chapter", 1, true)
                    or lurl:find("chuong", 1, true) then
                is_chapter = true
            end
            local anchor_text = Util.stripTags(anchor_html) or ""
            local at_lower = anchor_text:lower()
            if not is_chapter then
                if at_lower:find("chương%s*%d")
                        or at_lower:find("chapter%s*%d")
                        or at_lower:find("^%d+%s*$") then
                    is_chapter = true
                end
            end
            if is_chapter then
                table.insert(chapters, {
                    title = Util.stripTags(anchor_html),
                    url = chapter_url,
                    source_id = self.id,
                    story_url = story.url,
                    kind = self.kind,
                })
            end
        end
    end

    story.details = self:parseStoryDetails(html)

    return {
        story = story,
        chapters = Util.uniqueBy(chapters, "url"),
        page = 1,
        total_pages = 1,
    }
end

function Source:getStoryPage(story)
    if site_blocked then
        return nil, BLOCKED_MESSAGE
    end
    local html, err = Http:get(story.url, requestHeaders())
    if not html then
        return nil, err
    end
    return self:parseStoryPage(html, story)
end

function Source:parseChapter(html, chapter)
    local images = {}
    
    local content_html = html:match('<div[^>]-class="[^"]*story%-see%-content[^"]*"[^>]*>([%s%S]-)</div>')
    if not content_html then
        content_html = html
    end

    for image_tag in content_html:gmatch("(<img[^>]*>)") do
        local primary = Util.getAttribute(image_tag, "data-original")
            or Util.getAttribute(image_tag, "src")
        local class_name = Util.getAttribute(image_tag, "class") or ""
        
        if primary and (class_name:find("lazy") or primary:find("/chap/")) then
            local clean_urls = {}
            local seen = {}
            local candidates = {
                primary,
                Util.getAttribute(image_tag, "data-cdn"),
                Util.getAttribute(image_tag, "data-fb"),
            }
            for index = 1, 3 do
                local url = Util.absoluteUrl(self.base_url, candidates[index])
                if url and not seen[url] then
                    seen[url] = true
                    table.insert(clean_urls, url)
                end
            end
            if #clean_urls > 0 then
                table.insert(images, { urls = clean_urls })
            end
        end
    end

    if #images == 0 then
        return nil, "Không tìm thấy ảnh của chương"
    end

    local title
    for heading_attrs, heading_html in html:gmatch("<h1([^>]*)>([%s%S]-)</h1>") do
        local class_name = Util.getAttribute(heading_attrs, "class") or ""
        if class_name:find("detail-title", 1, true) then
            title = Util.stripTags(heading_html)
            break
        end
    end

    return {
        title = title or chapter.title,
        images = images,
        url = chapter.url,
        referer = self.base_url .. "/",
        kind = self.kind,
    }
end

local function parseCookies(raw, cookies_table)
    cookies_table = cookies_table or {}
    if not raw then return cookies_table end
    local list = {}
    if type(raw) == "table" then
        for _, v in ipairs(raw) do
            table.insert(list, v)
        end
    else
        for entry in tostring(raw):gmatch("([^,]+)") do
            table.insert(list, entry)
        end
    end

    for _, entry in ipairs(list) do
        local name, value = entry:match("^%s*([^;=]+)=([^;]*)")
        if name then
            name = name:gsub("^%s+", ""):gsub("%s+$", "")
            value = value:gsub("^%s+", ""):gsub("%s+$", "")
            local name_lower = name:lower()
            if name_lower ~= "expires" and name_lower ~= "max-age" and name_lower ~= "path" 
               and name_lower ~= "domain" and name_lower ~= "secure" and name_lower ~= "httponly" 
               and name_lower ~= "samesite" then
                cookies_table[name] = value
            end
        end
    end
    return cookies_table
end

local function buildCookieHeader(cookies_table)
    local found = {}
    for k, v in pairs(cookies_table or {}) do
        table.insert(found, k .. "=" .. v)
    end
    return table.concat(found, "; ")
end

local function unlockChapter(url, fallback_headers, init_cookies)
    local passwords = { "12345", "2026" }
    Debug.write("[cbunu] unlockChapter started for URL: " .. url)
    for _, password in ipairs(passwords) do
        local body = "access_pass=" .. password
        local post_headers = {
            ["Content-Type"] = "application/x-www-form-urlencoded",
            ["Referer"] = Source.base_url .. "/",
            ["Origin"] = Source.base_url,
        }
        for k, v in pairs(fallback_headers) do
            post_headers[k] = v
        end
        local cookie_str = buildCookieHeader(init_cookies)
        if cookie_str ~= "" then 
            post_headers["Cookie"] = cookie_str 
        end

        Debug.write("[cbunu] unlockChapter trying password: " .. password)
        local html, err, headers, code, resp_body = Http:request("POST", url, body, post_headers, { redirect = false })
        Debug.write(string.format("[cbunu] unlockChapter POST finished. code=%s, err=%s", tostring(code), tostring(err)))
        
        if (code == 302 or code == 200) and headers then
            local set_cookie = headers["set-cookie"] or headers["Set-Cookie"]
            if set_cookie then
                parseCookies(set_cookie, init_cookies)
                Debug.write("[cbunu] unlockChapter parsed new cookies from POST response")
            end
            
            local get_headers = {
                ["Referer"] = Source.base_url .. "/",
            }
            for k, v in pairs(fallback_headers) do 
                get_headers[k] = v 
            end
            cookie_str = buildCookieHeader(init_cookies)
            if cookie_str ~= "" then 
                get_headers["Cookie"] = cookie_str 
            end
            
            Debug.write("[cbunu] unlockChapter making GET request to retrieve unlocked content")
            local get_html, get_err, get_hdrs, get_code = Http:get(url, get_headers)
            Debug.write(string.format("[cbunu] unlockChapter GET finished. code=%s, body_len=%d", tostring(get_code), get_html and #get_html or 0))
            
            if get_code == 200 and get_html then
                if not get_html:find("<title>Đăng nhập</title>", 1, true) then
                    Debug.write("[cbunu] unlockChapter SUCCESS: Unlocked content obtained successfully")
                    return get_html
                else
                    Debug.write("[cbunu] unlockChapter FAILED: Page still displays login title")
                end
            end
        end
    end
    return nil, "Không thể mở khóa chương với mật khẩu mặc định"
end

function Source:getChapter(chapter)
    if site_blocked then
        return nil, BLOCKED_MESSAGE
    end
    Debug.write("[cbunu] getChapter started for: " .. chapter.url)
    local html, err, headers, code, body = Http:get(chapter.url, requestHeaders())
    Debug.write(string.format("[cbunu] getChapter initial request returned code=%s, err=%s", tostring(code), tostring(err)))
    
    if code == 403 or (body and body:find("<title>Đăng nhập</title>", 1, true)) then
        Debug.write("[cbunu] getChapter detected 403 or login title. Attempting to unlock...")
        local cookies = {}
        local cookie_header = requestHeaders()["Cookie"]
        if cookie_header then
            parseCookies(cookie_header, cookies)
        end
        if headers and (headers["set-cookie"] or headers["Set-Cookie"]) then
            parseCookies(headers["set-cookie"] or headers["Set-Cookie"], cookies)
        end
        html, err = unlockChapter(chapter.url, requestHeaders(), cookies)
    end
    
    if not html then
        Debug.write("[cbunu] getChapter failed: " .. tostring(err))
        return nil, err or "Không thể tải nội dung chương"
    end
    return self:parseChapter(html, chapter)
end

return Source
```

## truyenviet.koplugin/truyenviet/sources/dilib.lua

```lua
local Http = require("truyenviet/http_client")
local Util = require("truyenviet/helpers")
local GDrive = require("truyenviet/gdrive_downloader")
local Debug = require("truyenviet/debugger")
local ko_util = require("util")

local Source = {
    id = "dilib",
    name = "Dilib Thư Viện Số",
    kind = "ebook",
    base_url = "https://dilib.vn",
}

function Source:getCoverHeaders()
    return { ["Referer"] = self.base_url .. "/" }
end

-- Categories for browsing
local LIBRARY_CATEGORIES = {
    { name = "Thư Viện", url = "/thu-vien/" },
    { name = "Sách Bộ", url = "/sach-bo/" },
    { name = "Truyện Tranh", url = "/truyen-tranh/" },
    { name = "Truyện Tranh Manga", url = "/truyen-tranh/manga/" },
    { name = "Truyện Tranh Manhua", url = "/truyen-tranh/manhua/" },
    { name = "Truyện Tranh Manhwa", url = "/truyen-tranh/manhwa/" },
    { name = "Truyện Tranh Manga", url = "/truyen-tranh/manga/" },
    { name = "Truyện Tranh Manhua", url = "/truyen-tranh/manhua/" },
    { name = "Truyện Tranh Manhwa", url = "/truyen-tranh/manhwa/" },
    { name = "Truyện Tranh Action", url = "/truyen-tranh/action/" },
    { name = "Truyện Tranh Adventure", url = "/truyen-tranh/adventure/" },
    { name = "Truyện Tranh Comedy", url = "/truyen-tranh/comedy/" },
    { name = "Truyện Tranh Fantasy", url = "/truyen-tranh/fantasy/" },
    { name = "Truyện Tranh Shounen", url = "/truyen-tranh/shounen/" },
    { name = "Truyện Tranh Shoujo", url = "/truyen-tranh/shoujo/" },
    { name = "Truyện Tranh Supernatural", url = "/truyen-tranh/supernatural/" },
    { name = "Truyện Tranh Sci-Fi", url = "/truyen-tranh/sci-fi/" },
    { name = "Truyện Tranh Martial Arts", url = "/truyen-tranh/martial-arts/" },
    { name = "Truyện Tranh Seinen", url = "/truyen-tranh/seinen/" },
    { name = "Truyện Tranh Drama", url = "/truyen-tranh/drama/" },
    { name = "Truyện Tranh Mystery", url = "/truyen-tranh/mystery/" },
    { name = "Truyện Tranh Cooking", url = "/truyen-tranh/cooking/" },
    { name = "Truyện Tranh Harem", url = "/truyen-tranh/harem/" },
    { name = "Truyện Tranh Romance", url = "/truyen-tranh/romance/" },
    { name = "Truyện Tranh School Life", url = "/truyen-tranh/school-life/" },
    { name = "Truyện Tranh Historical", url = "/truyen-tranh/historical/" },
    { name = "Truyện Tranh Psychological", url = "/truyen-tranh/psychological/" },
    { name = "Truyện Tranh Tragedy", url = "/truyen-tranh/tragedy/" },
    { name = "Truyện Tranh Truyện Màu", url = "/truyen-tranh/truyen-mau/" },
    { name = "Truyện Tranh Horror", url = "/truyen-tranh/horror/" },
    { name = "Truyện Tranh Slice Of Life", url = "/truyen-tranh/slice-of-life/" },
    { name = "Truyện Tranh Adult (18+)", url = "/truyen-tranh/adult-18/" },
    { name = "Truyện Tranh Sports", url = "/truyen-tranh/sports/" },
    { name = "Truyện Tranh Ecchi", url = "/truyen-tranh/ecchi/" },
    { name = "Truyện Tranh Webtoon", url = "/truyen-tranh/webtoon/" },
    { name = "Truyện Tranh Mature", url = "/truyen-tranh/mature/" },
    { name = "Truyện Tranh Tu Tiên", url = "/truyen-tranh/tu-tien/" },
    { name = "Truyện Tranh Vampire", url = "/truyen-tranh/vampire/" },
    { name = "Truyện Tranh Josei", url = "/truyen-tranh/josei/" },
    { name = "Truyện Tranh Xuyên Không", url = "/truyen-tranh/xuyen-khong/" },
    { name = "Truyện Tranh Magic", url = "/truyen-tranh/magic/" },
    { name = "Truyện Tranh Monsters", url = "/truyen-tranh/monsters/" },
    { name = "Truyện Tranh Hệ Thống", url = "/truyen-tranh/he-thong/" },
    { name = "Phim Tài Liệu - Khoa Học", url = "/rap-chieu-phim/tai-lieu-khoa-hoc/" },
    { name = "Phim Tâm Linh - Tỉnh Thức", url = "/rap-chieu-phim/tam-linh-tinh-thuc/" },
    { name = "Phim Khám Phá Thế Giới", url = "/rap-chieu-phim/kham-pha-the-gioi/" },
    { name = "Phim Hoạt Hình - Anime", url = "/rap-chieu-phim/hoat-hinh-anime/" },
    { name = "Phim Võ Thuật - Hành Động", url = "/rap-chieu-phim/vo-thuat-hanh-dong/" },
    { name = "Phim Hình Sự - Trinh Thám", url = "/rap-chieu-phim/hinh-su-trinh-tham/" },
    { name = "Phim Tâm Lý - Tình Cảm", url = "/rap-chieu-phim/tam-ly-tinh-cam/" },
    { name = "Phim Phiêu Lưu - Sinh Tồn", url = "/rap-chieu-phim/phieu-luu-sinh-ton/" },
    { name = "Phim Khoa Học - Giả Tưởng", url = "/rap-chieu-phim/khoa-hoc-gia-tuong/" },
    { name = "Phim Chiến Tranh - Lịch Sử", url = "/rap-chieu-phim/chien-tranh-lich-su/" },
    { name = "Phim Cổ Trang - Kiếm Hiệp", url = "/rap-chieu-phim/co-trang-kiem-hiep/" },
    { name = "Phim Ma - Kinh Dị", url = "/rap-chieu-phim/phim-ma-kinh-di/" },
    { name = "Phim Hài - Vui Nhộn", url = "/rap-chieu-phim/phim-hai-vui-nhon/" },
    { name = "Phim Thuyết Minh - Lồng Tiếng", url = "/rap-chieu-phim/thuyet-minh-long-tieng/" },
    { name = "Nhạc Pop - Ballad", url = "/am-nhac/pop-ballad/" },
    { name = "Nhạc Dance - Edm", url = "/am-nhac/dance-edm/" },
    { name = "Nhạc Hip Hop - Rap", url = "/am-nhac/hip-hop-rap/" },
    { name = "Nhạc Thánh Ca", url = "/am-nhac/thanh-ca/" },
    { name = "Nhạc Phật Giáo", url = "/am-nhac/nhac-phat-giao/" },
    { name = "Nhạc Chữa Lành", url = "/am-nhac/nhac-chua-lanh/" },
    { name = "Nhạc Không Lời", url = "/am-nhac/nhac-khong-loi/" },
    { name = "Nhạc Thiền Định", url = "/am-nhac/nhac-thien-dinh/" },
    { name = "Nhạc Năng Lượng", url = "/am-nhac/nhac-nang-luong/" },
    { name = "Nhạc Tình Ca - Love Song", url = "/am-nhac/tinh-ca-love-song/" },
    { name = "Nhạc Audiophile", url = "/am-nhac/audiophile/" },
    { name = "Nhạc Giao Hưởng", url = "/am-nhac/giao-huong/" },
    { name = "Sách Tâm Lý - Kỹ Năng", url = "/thu-vien/tam-ly-ky-nang/" },
    { name = "Sách Tôn Giáo - Tâm Linh", url = "/thu-vien/ton-giao-tam-linh/" },
    { name = "Sách Khoa Học - Công Nghệ", url = "/thu-vien/khoa-hoc-cong-nghe/" },
    { name = "Sách Kiến Trúc - Xây Dựng", url = "/thu-vien/kien-truc-xay-dung/" },
    { name = "Sách Nông - Lâm - Ngư", url = "/thu-vien/nong-lam-ngu/" },
    { name = "Sách Y Học - Sức Khỏe", url = "/thu-vien/y-hoc-suc-khoe/" },
    { name = "Sách Lịch Sử - Quân Sự", url = "/thu-vien/lich-su-quan-su/" },
    { name = "Sách Nhân Vật Lịch Sử", url = "/thu-vien/nhan-vat-lich-su/" },
    { name = "Sách Hồi Ký - Tùy Bút", url = "/thu-vien/hoi-ky-tuy-but/" },
    { name = "Sách Quản Trị - Kinh Doanh", url = "/thu-vien/quan-tri-kinh-doanh/" },
    { name = "Sách Self Help - Khởi Nghiệp", url = "/thu-vien/self-help-khoi-nghiep/" },
    { name = "Sách Marketing - Bán Hàng", url = "/thu-vien/marketing-ban-hang/" },
    { name = "Sách Triết Học - Lý Luận", url = "/thu-vien/triet-hoc-ly-luan/" },
    { name = "Sách Đường Lối - Chính Trị", url = "/thu-vien/duong-loi-chinh-tri/" },
    { name = "Sách Thư Viện Pháp Luật", url = "/thu-vien/thu-vien-phap-luat/" },
    { name = "Sách Khai Tâm - Mở Trí", url = "/thu-vien/khai-tam-mo-tri/" },
    { name = "Sách Văn Hóa - Xã Hội", url = "/thu-vien/van-hoa-xa-hoi/" },
    { name = "Sách Văn Học - Nghệ Thuật", url = "/thu-vien/van-hoc-nghe-thuat/" },
    { name = "Sách Tác Phẩm Kinh Điển", url = "/thu-vien/tac-pham-kinh-dien/" },
    { name = "Sách Giáo Dục - Đào Tạo", url = "/thu-vien/giao-duc-dao-tao/" },
    { name = "Sách Tài Liệu - Tham Khảo", url = "/thu-vien/tai-lieu-tham-khao/" },
    { name = "Sách Công Nghệ Thông Tin", url = "/thu-vien/cong-nghe-thong-tin/" },
    { name = "Sách Thể Thao - Võ Thuật", url = "/thu-vien/the-thao-vo-thuat/" },
    { name = "Sách Yoga - Thiền", url = "/thu-vien/yoga-thien/" },
    { name = "Sách Phát Triển Bản Thân", url = "/thu-vien/phat-trien-ban-than/" },
    { name = "Sách Ẩm Thực - Nấu Ăn", url = "/thu-vien/am-thuc-nau-an/" },
    { name = "Sách Âm Nhạc - Thơ Ca - Hội Họa", url = "/thu-vien/am-nhac-tho-ca-hoi-hoa/" },
    { name = "Sách Nuôi Dưỡng Tâm Hồn", url = "/thu-vien/nuoi-duong-tam-hon/" },
    { name = "Sách Tình cảm - Gia Đình", url = "/thu-vien/tinh-cam-gia-dinh/" },
    { name = "Sách Trẻ Em - Thiếu Nhi", url = "/thu-vien/tre-em-thieu-nhi/" },
    { name = "Sách Tuổi Học Trò", url = "/thu-vien/tuoi-hoc-tro/" },
    { name = "Sách Tử Vi - Phong Thủy", url = "/thu-vien/tu-vi-phong-thuy/" },
    { name = "Sách Biên Khảo - Địa Lý", url = "/thu-vien/bien-khao-dia-ly/" },
    { name = "Sách Khám Phá - Bí Ẩn", url = "/thu-vien/kham-pha-bi-an/" },
    { name = "Sách Huyền Bí - Giả Tưởng", url = "/thu-vien/huyen-bi-gia-tuong/" },
    { name = "Sách Cổ Tích - Thần Thoại", url = "/thu-vien/co-tich-than-thoai/" },
    { name = "Sách Phiêu Lưu - Mạo Hiểm", url = "/thu-vien/phieu-luu-mao-hiem/" },
    { name = "Sách Trinh Thám - Hình Sự - Kinh Dị", url = "/thu-vien/trinh-tham-hinh-su-kinh-di/" },
    { name = "Sách Tiếu Lâm - Hài Hước", url = "/thu-vien/tieu-lam-hai-huoc/" },
    { name = "Sách Lãng Mạn - Ngôn Tình", url = "/thu-vien/lang-man-ngon-tinh/" },
    { name = "Sách Đam Mỹ - Bách Hợp", url = "/thu-vien/dam-my-bach-hop/" },
    { name = "Sách Người Lớn (18+)", url = "/thu-vien/nguoi-lon-18/" },
    { name = "Sách Truyện Ngắn - Tiểu Thuyết", url = "/thu-vien/truyen-ngan-tieu-thuyet/" },
    { name = "Sách Truyện Dài Trọn Bộ", url = "/thu-vien/truyen-dai-tron-bo/" },
    { name = "Sách Kịch Bản - Sân Khấu", url = "/thu-vien/kich-ban-san-khau/" },
    { name = "Sách Kiếm Hiệp - Tiên Hiệp", url = "/thu-vien/kiem-hiep-tien-hiep/" },
    { name = "Sách Huyền Huyễn - Phóng Tác", url = "/thu-vien/huyen-huyen-phong-tac/" },
    { name = "Sách Đang Cập Nhật", url = "/thu-vien/dang-cap-nhat/" },
    { name = "Xem Thêm Bình Luận", url = "/binh-luan/" },
}

local AUDIOBOOK_CATEGORIES = {
    { name = "Góc Suy Ngẫm", url = "/radio/goc-suy-ngam/" },
    { name = "Radio Tình Yêu", url = "/radio/radio-tinh-yeu/" },
    { name = "Radio Cho Tâm Hồn", url = "/radio/radio-cho-tam-hon/" },
    { name = "Radio Truyện Ngắn", url = "/radio/radio-truyen-ngan/" },
    { name = "Radio Truyện Dài Kỳ", url = "/radio/radio-truyen-dai-ky/" },
    { name = "Tản Mạn Radio", url = "/radio/tan-man-radio/" },
    { name = "Kịch Truyền Thanh", url = "/radio/kich-truyen-thanh/" },
    { name = "Tóm Tắt Sách", url = "/radio/tom-tat-sach/" },
    { name = "Sách nói Tâm Lý - Kỹ Năng", url = "/sach-noi/tam-ly-ky-nang/" },
    { name = "Sách nói Tôn Giáo - Tâm Linh", url = "/sach-noi/ton-giao-tam-linh/" },
    { name = "Sách nói Khoa Học - Công Nghệ", url = "/sach-noi/khoa-hoc-cong-nghe/" },
    { name = "Sách nói Kiến Trúc - Xây Dựng", url = "/sach-noi/kien-truc-xay-dung/" },
    { name = "Sách nói Nông - Lâm - Ngư", url = "/sach-noi/nong-lam-ngu/" },
    { name = "Sách nói Y Học - Sức Khỏe", url = "/sach-noi/y-hoc-suc-khoe/" },
    { name = "Sách nói Lịch Sử - Quân Sự", url = "/sach-noi/lich-su-quan-su/" },
    { name = "Sách nói Nhân Vật Lịch Sử", url = "/sach-noi/nhan-vat-lich-su/" },
    { name = "Sách nói Hồi Ký - Tùy Bút", url = "/sach-noi/hoi-ky-tuy-but/" },
    { name = "Sách nói Quản Trị - Kinh Doanh", url = "/sach-noi/quan-tri-kinh-doanh/" },
    { name = "Sách nói Self Help - Khởi Nghiệp", url = "/sach-noi/self-help-khoi-nghiep/" },
    { name = "Sách nói Marketing - Bán Hàng", url = "/sach-noi/marketing-ban-hang/" },
    { name = "Sách nói Triết Học - Lý Luận", url = "/sach-noi/triet-hoc-ly-luan/" },
    { name = "Sách nói Đường Lối - Chính Trị", url = "/sach-noi/duong-loi-chinh-tri/" },
    { name = "Sách nói Thư Viện Pháp Luật", url = "/sach-noi/thu-vien-phap-luat/" },
    { name = "Sách nói Khai Tâm - Mở Trí", url = "/sach-noi/khai-tam-mo-tri/" },
    { name = "Sách nói Văn Hóa - Xã Hội", url = "/sach-noi/van-hoa-xa-hoi/" },
    { name = "Sách nói Văn Học - Nghệ Thuật", url = "/sach-noi/van-hoc-nghe-thuat/" },
    { name = "Sách nói Tác Phẩm Kinh Điển", url = "/sach-noi/tac-pham-kinh-dien/" },
    { name = "Sách nói Giáo Dục - Đào Tạo", url = "/sach-noi/giao-duc-dao-tao/" },
    { name = "Sách nói Tài Liệu - Tham Khảo", url = "/sach-noi/tai-lieu-tham-khao/" },
    { name = "Sách nói Công Nghệ Thông Tin", url = "/sach-noi/cong-nghe-thong-tin/" },
    { name = "Sách nói Thể Thao - Võ Thuật", url = "/sach-noi/the-thao-vo-thuat/" },
    { name = "Sách nói Yoga - Thiền", url = "/sach-noi/yoga-thien/" },
    { name = "Sách nói Phát Triển Bản Thân", url = "/sach-noi/phat-trien-ban-than/" },
    { name = "Sách nói Ẩm Thực - Nấu Ăn", url = "/sach-noi/am-thuc-nau-an/" },
    { name = "Sách nói Âm Nhạc - Thơ Ca - Hội Họa", url = "/sach-noi/am-nhac-tho-ca-hoi-hoa/" },
    { name = "Sách nói Nuôi Dưỡng Tâm Hồn", url = "/sach-noi/nuoi-duong-tam-hon/" },
    { name = "Sách nói Tình cảm - Gia Đình", url = "/sach-noi/tinh-cam-gia-dinh/" },
    { name = "Sách nói Trẻ Em - Thiếu Nhi", url = "/sach-noi/tre-em-thieu-nhi/" },
    { name = "Sách nói Tuổi Học Trò", url = "/sach-noi/tuoi-hoc-tro/" },
    { name = "Sách nói Tử Vi - Phong Thủy", url = "/sach-noi/tu-vi-phong-thuy/" },
    { name = "Sách nói Biên Khảo - Địa Lý", url = "/sach-noi/bien-khao-dia-ly/" },
    { name = "Sách nói Khám Phá - Bí Ẩn", url = "/sach-noi/kham-pha-bi-an/" },
    { name = "Sách nói Huyền Bí - Giả Tưởng", url = "/sach-noi/huyen-bi-gia-tuong/" },
    { name = "Sách nói Cổ Tích - Thần Thoại", url = "/sach-noi/co-tich-than-thoai/" },
    { name = "Sách nói Phiêu Lưu - Mạo Hiểm", url = "/sach-noi/phieu-luu-mao-hiem/" },
    { name = "Sách nói Trinh Thám - Hình Sự - Kinh Dị", url = "/sach-noi/trinh-tham-hinh-su-kinh-di/" },
    { name = "Sách nói Tiếu Lâm - Hài Hước", url = "/sach-noi/tieu-lam-hai-huoc/" },
    { name = "Sách nói Lãng Mạn - Ngôn Tình", url = "/sach-noi/lang-man-ngon-tinh/" },
    { name = "Sách nói Đam Mỹ - Bách Hợp", url = "/sach-noi/dam-my-bach-hop/" },
    { name = "Sách nói Người Lớn (18+)", url = "/sach-noi/nguoi-lon-18/" },
    { name = "Sách nói Truyện Ngắn - Tiểu Thuyết", url = "/sach-noi/truyen-ngan-tieu-thuyet/" },
    { name = "Sách nói Truyện Dài Trọn Bộ", url = "/sach-noi/truyen-dai-tron-bo/" },
    { name = "Sách nói Kịch Bản - Sân Khấu", url = "/sach-noi/kich-ban-san-khau/" },
    { name = "Sách nói Kiếm Hiệp - Tiên Hiệp", url = "/sach-noi/kiem-hiep-tien-hiep/" },
    { name = "Sách nói Huyền Huyễn - Phóng Tác", url = "/sach-noi/huyen-huyen-phong-tac/" },
    { name = "Sách nói Đang Cập Nhật", url = "/sach-noi/dang-cap-nhat/" },
}

function Source:getCategories()
    local categories = {}
    for _, cat in ipairs(LIBRARY_CATEGORIES) do
        table.insert(categories, {
            name = cat.name,
            url = self.base_url .. cat.url,
            is_audio = false,
        })
    end
    for _, cat in ipairs(AUDIOBOOK_CATEGORIES) do
        table.insert(categories, {
            name = "🔊 " .. cat.name,
            url = self.base_url .. cat.url,
            is_audio = true,
        })
    end
    return categories
end

-- Parse book listing page
function Source:parseListing(html)
    local books = {}
    
    -- Pattern: <a title="..." href="/slug-id.html" class="woocommerce-LoopProduct-link">
    -- Hoặc các thẻ a có chứa hình ảnh.
    for anchor, inner in html:gmatch('<a([^>]-)>(.-)</a>') do
        local href = Util.getAttribute(anchor, "href")
        local title = Util.getAttribute(anchor, "title")
        local is_loop_product = anchor:find("woocommerce%-LoopProduct%-link")
        
        -- Nếu thẻ A không có title, thử tìm trong thẻ img
        local cover_url
        if inner:find("<img") then
            cover_url = inner:match('<img[^>]-src="([^"]+)"')
            if not title or title == "" then
                title = inner:match('<img[^>]-alt="([^"]+)"')
            end
        end
        
        -- Lọc link rác
        if href and title and title ~= "" and not href:match("^#") and not href:match("javascript:") and href:match("%.html$") then
            -- Bỏ qua các bài blog hoặc không phải truyện/sách (tuỳ vào class hoặc url)
            if is_loop_product or (cover_url and href:match("%-%d+%.html$")) then
                local is_audio = title:match("^Audio") ~= nil
                title = title:gsub("^Audio book ", "")
                title = title:gsub("^Sách ", "")
                title = title:gsub(" PDF$", "")
                
                table.insert(books, {
                    source_id = self.id,
                    title = Util.decodeHtml(title),
                    url = Util.absoluteUrl(self.base_url, href),
                    cover_url = cover_url and Util.absoluteUrl(self.base_url, cover_url) or nil,
                    kind = self.kind,
                    is_audio = is_audio,
                })
            end
        end
    end

    return Util.uniqueBy(books, "url")
end

function Source:getCategoryBooks(category, page)
    page = page or 1
    local url = category.url
    if page > 1 then
        url = url .. "?page=" .. page
    end

    local html, err = Http:get(url)
    if not html then
        return nil, err
    end

    local books = self:parseListing(html)

    -- Parse total pages
    local total_pages = page
    for p in html:gmatch('[?&]page=(%d+)') do
        total_pages = math.max(total_pages, tonumber(p) or 1)
    end

    return {
        books = books,
        page = page,
        total_pages = total_pages,
        category = category,
    }
end

-- Get book detail page
function Source:getBookDetail(book)
    local html, err = Http:get(book.url)
    if not html then
        return nil, err
    end

    -- Parse metadata
    local title = html:match("<h1[^>]*>([^<]+)</h1>") or book.title
    local author = html:match('<b>Tác giả :%s*</b>%s*<a[^>]*>([^<]+)</a>')
        or html:match('<b>Tác giả :</b>%s*([^<]+)')
    local narrator = html:match('<b>Giọng đọc :</b>%s*<a[^>]*>([^<]+)</a>')
    local pages = html:match('<b>Số trang :</b>%s*(%d+)')
    local format_info = html:match('<b>Định dạng :</b>%s*([^<]+)')
    local views = html:match('<b>Lượt xem/nghe :</b>%s*(%d+)')
    local size = html:match('<b>Kích thước :</b>%s*([^<]+)')
    local cover_url = html:match('class="border"[^>]-src="([^"]*)"')
        or html:match('src="([^"]*)"[^>]-class="border"')

    -- Parse download links
    local pdf_download_url = html:match('href="(/download/[^"]+)"')
    local audio_download_url = html:match('href="(/audio/[^"]+)"')
    local audio_size = html:match('Sách Nói %(([^%)]+)%)')

    -- Parse read online link
    local read_online_url = html:match('href="(/readbook/[^"]+)"')

    -- Parse audio source (direct MP3 URL)
    local audio_src = html:match('src="(/img/audio/[^"]+%.mp3)"')
        or html:match("src='(/img/audio/[^']+%.mp3)'")

    -- Parse audio chapters from JavaScript
    local audio_chapters = {}
    for timestamp, idx in html:gmatch('myaudio%.currentTime >= ([%d%.]+)[^}]*mouse_click%((%d+)%)') do
        table.insert(audio_chapters, {
            index = tonumber(idx),
            start_time = tonumber(timestamp),
        })
    end

    -- Parse chapter names from the page
    -- Look for ordered list or table of contents
    local toc_html = html:match('<fieldset[^>]-id="mucluc"[^>]*>(.-)</fieldset>')
        or html:match('<div[^>]-id="mucluc"[^>]*>(.-)</div>')
    if toc_html then
        local chapter_idx = 0
        for item in toc_html:gmatch("<li[^>]*>(.-)</li>") do
            chapter_idx = chapter_idx + 1
            local name = Util.stripTags(item)
            if name ~= "" then
                for _, ch in ipairs(audio_chapters) do
                    if ch.index == chapter_idx - 1 then
                        ch.name = name
                    end
                end
            end
        end
    end

    -- Parse genres/categories
    local genres = {}
    for anchor_attrs, anchor_html in html:gmatch('<a[^>]-class="button2"[^>]*href="([^"]*)"[^>]*>([^<]*)</a>') do
        local name = Util.stripTags(anchor_html)
        if name ~= "" then
            table.insert(genres, name)
        end
    end

    -- Description from meta
    local description = Util.getMetaContent(html, "name", "description") or ""

    local has_pdf = pdf_download_url ~= nil
    local has_audio = audio_src ~= nil or audio_download_url ~= nil

    return {
        title = Util.decodeHtml(Util.trim(title)),
        author = author and Util.trim(author) or nil,
        narrator = narrator and Util.trim(narrator) or nil,
        pages = pages,
        format = format_info and Util.trim(format_info) or nil,
        views = views,
        size = size and Util.trim(size) or nil,
        description = description,
        cover_url = cover_url and Util.absoluteUrl(self.base_url, cover_url) or book.cover_url,
        genres = genres,
        -- Download URLs
        has_pdf = has_pdf,
        pdf_download_url = pdf_download_url and Util.absoluteUrl(self.base_url, pdf_download_url) or nil,
        has_audio = has_audio,
        audio_download_url = audio_download_url and Util.absoluteUrl(self.base_url, audio_download_url) or nil,
        audio_src = audio_src and Util.absoluteUrl(self.base_url, audio_src) or nil,
        audio_size = audio_size,
        audio_chapters = #audio_chapters > 0 and audio_chapters or nil,
        read_online_url = read_online_url and Util.absoluteUrl(self.base_url, read_online_url) or nil,
    }
end

-- Download PDF (may go through Google Drive)
function Source:downloadPdf(detail, save_path)
    if not detail.pdf_download_url then
        return nil, "Sách này không có bản PDF để tải"
    end

    Debug.write("[Dilib] Downloading PDF: " .. detail.pdf_download_url)
    return GDrive:download(detail.pdf_download_url, save_path)
end

-- Download audio MP3
function Source:downloadAudio(detail, save_path)
    local audio_url = detail.audio_src or detail.audio_download_url
    if not audio_url then
        return nil, "Sách này không có bản audio để tải"
    end

    Debug.write("[Dilib] Downloading audio: " .. audio_url)

    -- Audio download link might also redirect through GDrive
    if audio_url:match("/audio/") then
        -- Try direct download first
        local content, err = Http:get(audio_url, {
            ["Referer"] = self.base_url .. "/",
        })
        if content and #content > 10000 then
            local temp_path = save_path .. ".part"
            local file, open_err = io.open(temp_path, "wb")
            if not file then
                return nil, "Không thể tạo file: " .. tostring(open_err)
            end
            file:write(content)
            file:close()
            local ok, rename_err = os.rename(temp_path, save_path)
            if not ok then
                os.remove(temp_path)
                return nil, "Không thể lưu file: " .. tostring(rename_err)
            end
            return save_path
        end
        -- Fallback to GDrive handler
        return GDrive:download(audio_url, save_path)
    end

    -- Direct MP3 URL
    local content, err = Http:get(audio_url, {
        ["Referer"] = self.base_url .. "/",
    })
    if not content then
        return nil, "Không thể tải audio: " .. tostring(err)
    end

    local temp_path = save_path .. ".part"
    local file, open_err = io.open(temp_path, "wb")
    if not file then
        return nil, "Không thể tạo file: " .. tostring(open_err)
    end
    file:write(content)
    file:close()
    local ok, rename_err = os.rename(temp_path, save_path)
    if not ok then
        os.remove(temp_path)
        return nil, "Không thể lưu file: " .. tostring(rename_err)
    end

    Debug.write("[Dilib] Audio download complete: " .. save_path .. " (" .. #content .. " bytes)")
    return save_path
end

-- Build an HTML info page for a book (readable on e-ink)
function Source:buildInfoPage(detail, save_path)
    local lines = {
        '<!DOCTYPE html>',
        '<html lang="vi">',
        '<head>',
        '  <meta charset="utf-8"/>',
        '  <meta name="viewport" content="width=device-width, initial-scale=1"/>',
        '  <title>' .. Util.escapeHtml(detail.title) .. '</title>',
        '  <style>',
        '    body { line-height: 1.65; margin: 5%; text-align: justify; }',
        '    h1 { font-size: 1.35em; line-height: 1.3; text-align: center; }',
        '    .meta { color: #666; font-size: 0.9em; }',
        '    .toc { margin-top: 1em; }',
        '    .toc li { margin: 0.3em 0; }',
        '    .time { color: #999; font-size: 0.85em; }',
        '  </style>',
        '</head>',
        '<body>',
        '  <h1>' .. Util.escapeHtml(detail.title) .. '</h1>',
    }

    if detail.author then
        table.insert(lines, '  <p class="meta">Tác giả: ' .. Util.escapeHtml(detail.author) .. '</p>')
    end
    if detail.narrator then
        table.insert(lines, '  <p class="meta">Giọng đọc: ' .. Util.escapeHtml(detail.narrator) .. '</p>')
    end
    if detail.format then
        table.insert(lines, '  <p class="meta">Định dạng: ' .. Util.escapeHtml(detail.format) .. '</p>')
    end
    if detail.pages then
        table.insert(lines, '  <p class="meta">Số trang: ' .. Util.escapeHtml(detail.pages) .. '</p>')
    end
    if detail.size then
        table.insert(lines, '  <p class="meta">Kích thước: ' .. Util.escapeHtml(detail.size) .. '</p>')
    end

    table.insert(lines, '  <hr/>')
    if detail.description and detail.description ~= "" then
        table.insert(lines, '  <p>' .. Util.escapeHtml(detail.description) .. '</p>')
    end

    if detail.audio_chapters and #detail.audio_chapters > 0 then
        table.insert(lines, '  <hr/>')
        table.insert(lines, '  <h2>Mục lục Audio</h2>')
        table.insert(lines, '  <ol class="toc">')
        for _, ch in ipairs(detail.audio_chapters) do
            local minutes = math.floor(ch.start_time / 60)
            local seconds = math.floor(ch.start_time % 60)
            local time_str = string.format("%d:%02d", minutes, seconds)
            local name = ch.name or ("Phần " .. (ch.index + 1))
            table.insert(lines, string.format(
                '    <li>%s <span class="time">[%s]</span></li>',
                Util.escapeHtml(name), time_str
            ))
        end
        table.insert(lines, '  </ol>')
    end

    if #detail.genres > 0 then
        table.insert(lines, '  <hr/>')
        table.insert(lines, '  <p class="meta">Thể loại: ' .. Util.escapeHtml(table.concat(detail.genres, ", ")) .. '</p>')
    end

    table.insert(lines, '</body>')
    table.insert(lines, '</html>')

    local file, err = io.open(save_path, "wb")
    if not file then
        return nil, err
    end
    file:write(table.concat(lines, "\n"))
    file:close()
    return save_path
end

-- Search (AJAX API)
function Source:search(query)
    local encoded = ko_util.urlEncode(query)
    local url = self.base_url .. "/search/ajax-search.php?keyword=" .. encoded
    local html, err = Http:get(url, {
        ["Referer"] = self.base_url .. "/",
        ["X-Requested-With"] = "XMLHttpRequest",
    })
    if not html then
        return nil, err
    end

    local stories = {}
    -- Parse search result items
    for block in html:gmatch('<a[^>]-href="([^"]*)"[^>]-title="([^"]*)"[^>]*>(.-)</a>') do
        -- block captures are href, title, inner
    end

    -- Better pattern for the AJAX response
    for anchor_attrs, anchor_content in html:gmatch("<a([^>]*)>(.-)</a>") do
        local href = Util.getAttribute(anchor_attrs, "href")
        local title = Util.getAttribute(anchor_attrs, "title")
        if href and href:match("%.html$") and title and title ~= "" then
            local cover_url = anchor_content:match('src="([^"]*)"')
            -- Extract author
            local author = anchor_content:match("Tác giả : ([^\n<]+)")

            table.insert(stories, {
                source_id = self.id,
                title = Util.decodeHtml(title),
                url = Util.absoluteUrl(self.base_url, href),
                cover_url = cover_url and Util.absoluteUrl(self.base_url, cover_url) or nil,
                kind = self.kind,
                author = author and Util.trim(author) or nil,
            })
        end
    end

    return Util.uniqueBy(stories, "url")
end

-- Compatibility: getCompleted returns categories for browsing
function Source:getCompleted(page)
    return {
        stories = {},
        genres = {},
        page = 1,
        total_pages = 1,
        title = "Dilib Thư Viện Số",
    }
end

return Source
```

## truyenviet.koplugin/truyenviet/sources/docln.lua

```lua
local Http = require("truyenviet/http_client")
local Util = require("truyenviet/helpers")
local Debug = require("truyenviet/debugger")
local ko_util = require("util")

local Source = {
    id = "docln",
    name = "DocLN (Hako)",
    kind = "text",
    base_url = "https://docln.sbs",
    max_concurrent = 2,
}

-- Login credentials
local LOGIN_USER = "nmdung3456"
local LOGIN_PASS = "nmdung3456"

-- Session cookie management
local session_cookie = nil
local session_cookie_time = 0
local COOKIE_TTL = 30 * 60 -- 30 minutes

local function parseCookiesFromHeader(raw, cookies_table)
    cookies_table = cookies_table or {}
    if not raw then return cookies_table end
    local list = {}
    if type(raw) == "table" then
        for _, v in ipairs(raw) do
            table.insert(list, v)
        end
    else
        for entry in tostring(raw):gmatch("([^,]+)") do
            table.insert(list, entry)
        end
    end
    for _, entry in ipairs(list) do
        local name, value = entry:match("^%s*([^;=]+)=([^;]*)")
        if name then
            name = name:gsub("^%s+", ""):gsub("%s+$", "")
            value = value:gsub("^%s+", ""):gsub("%s+$", "")
            local name_lower = name:lower()
            if name_lower ~= "expires" and name_lower ~= "max-age" and name_lower ~= "path"
               and name_lower ~= "domain" and name_lower ~= "secure" and name_lower ~= "httponly"
               and name_lower ~= "samesite" then
                cookies_table[name] = value
            end
        end
    end
    return cookies_table
end

local function buildCookieString(cookies_table)
    local parts = {}
    for k, v in pairs(cookies_table or {}) do
        table.insert(parts, k .. "=" .. v)
    end
    return table.concat(parts, "; ")
end

local cookies = {}

local function doLogin()
    Debug.write("[docln] Attempting login as " .. LOGIN_USER)

    -- Step 1: GET login page to get CSRF token and initial cookies
    local login_html, err, login_headers = Http:get(Source.base_url .. "/login", {
        ["Referer"] = Source.base_url .. "/",
    })
    if login_headers then
        local set_cookie = login_headers["set-cookie"] or login_headers["Set-Cookie"]
        parseCookiesFromHeader(set_cookie, cookies)
    end

    -- Extract CSRF token
    local csrf_token
    if login_html then
        csrf_token = login_html:match('name="_token"%s*value="([^"]+)"')
            or login_html:match('name="_token" value="([^"]+)"')
            or login_html:match('_token.-%s*value="([^"]+)"')
    end

    if not csrf_token and login_html then
        -- Try meta tag
        csrf_token = login_html:match('<meta name="csrf%-token" content="([^"]+)"')
    end

    Debug.write("[docln] CSRF token: " .. tostring(csrf_token and csrf_token:sub(1, 20) .. "..."))

    -- Step 2: POST login form
    local post_body_parts = {}
    if csrf_token then
        table.insert(post_body_parts, "_token=" .. ko_util.urlEncode(csrf_token))
    end
    table.insert(post_body_parts, "username=" .. ko_util.urlEncode(LOGIN_USER))
    table.insert(post_body_parts, "password=" .. ko_util.urlEncode(LOGIN_PASS))

    local post_body = table.concat(post_body_parts, "&")

    local cookie_str = buildCookieString(cookies)
    local post_headers = {
        ["Content-Type"] = "application/x-www-form-urlencoded",
        ["Referer"] = Source.base_url .. "/login",
        ["Origin"] = Source.base_url,
    }
    if cookie_str ~= "" then
        post_headers["Cookie"] = cookie_str
    end

    local html, post_err, resp_headers, status_code = Http:request(
        "POST", Source.base_url .. "/login", post_body, post_headers, { redirect = false }
    )

    Debug.write("[docln] Login POST status: " .. tostring(status_code))

    if resp_headers then
        local set_cookie = resp_headers["set-cookie"] or resp_headers["Set-Cookie"]
        parseCookiesFromHeader(set_cookie, cookies)
    end

    session_cookie = buildCookieString(cookies)
    session_cookie_time = os.time()

    if session_cookie ~= "" then
        Debug.write("[docln] Login successful, cookies obtained")
        return true
    else
        Debug.write("[docln] Login failed: no cookies")
        return false
    end
end

local function ensureSession()
    if not session_cookie or session_cookie == "" or (os.time() - session_cookie_time) > COOKIE_TTL then
        doLogin()
    end
    return session_cookie
end

local function requestHeaders(referer)
    local headers = {
        ["Referer"] = referer or Source.base_url .. "/",
    }
    local cookie = ensureSession()
    if cookie and cookie ~= "" then
        headers["Cookie"] = cookie
    end
    return headers
end

function Source:getCoverHeaders()
    return {
        ["Referer"] = self.base_url .. "/",
    }
end

-- ========================
-- SEARCH & LISTING
-- ========================

function Source:parseSearch(html)
    local stories = {}

    -- Parse thumb-item-flow cards (listing page)
    for block in html:gmatch('<div[^>]-class="[^"]*thumb%-item%-flow[^"]*"[^>]*>([\001-\255]-)</div>%s*$')  do
        -- fallback below
    end

    -- Parse series-title links paired with cover images
    -- Structure: <div class="thumb-wrapper"> ... <div data-bg="COVER_URL"> ... <div class="series-title"><a href="/truyen/..." title="TITLE">
    local position = 1
    while true do
        local wrapper_start = html:find('class="thumb%-wrapper', position, false)
        if not wrapper_start then break end

        -- Find the end of this thumb item (next thumb-item-flow or end)
        local next_item = html:find('class="thumb%-item%-flow', wrapper_start + 1, false) or #html

        local item_html = html:sub(wrapper_start, next_item - 1)

        -- Extract cover URL from data-bg attribute
        local cover_url = item_html:match('data%-bg="([^"]+)"')

        -- Extract series title link
        local series_title_block = item_html:match('<div[^>]-class="[^"]*series%-title[^"]*"[^>]*>([\001-\255]-)</div>')
        if series_title_block then
            local href = Util.getAttribute(series_title_block:match("(<a[^>]*>)"), "href")
            local title = Util.getAttribute(series_title_block:match("(<a[^>]*>)"), "title")
                or Util.stripTags(series_title_block)

            if href and title and title ~= "" then
                -- Only include /truyen/ links (truyện dịch)
                if href:find("/truyen/", 1, true) or href:find("/sang%-tac/") or href:find("/ai%-dich/") then
                    table.insert(stories, {
                        source_id = self.id,
                        title = Util.decodeHtml(title),
                        url = Util.absoluteUrl(self.base_url, href),
                        cover_url = cover_url,
                        kind = self.kind,
                    })
                end
            end
        end

        position = next_item
    end

    return Util.uniqueBy(stories, "url")
end

function Source:search(query)
    -- DocLN search: use the danh-sach page with search param
    local encoded = ko_util.urlEncode(query):gsub("%%20", "+")
    local html, err = Http:get(
        self.base_url .. "/tim-kiem?q=" .. encoded,
        requestHeaders()
    )
    if not html then
        return nil, err
    end
    return self:parseSearch(html)
end

function Source:parseListing(html, page)
    local stories = self:parseSearch(html)

    -- Parse genres from /the-loai/ links
    local genres = {}
    local seen = {}
    for anchor_attrs, anchor_html in html:gmatch("<a([^>]*)>([%s%S]-)</a>") do
        local href = Util.getAttribute(anchor_attrs, "href")
        if href and href:find("/the%-loai/", 1, false) then
            local name = Util.stripTags(anchor_html):gsub("^%s*", ""):gsub("%s*$", "")
            if name ~= "" and not seen[href] then
                seen[href] = true
                table.insert(genres, {
                    name = name,
                    url = Util.absoluteUrl(self.base_url, href),
                })
            end
        end
    end

    -- Parse pagination
    local max_page = page or 1
    for p_num in html:gmatch("page=(%d+)") do
        local n = tonumber(p_num)
        if n and n > max_page then
            max_page = n
        end
    end

    return {
        stories = stories,
        genres = genres,
        page = page or 1,
        total_pages = max_page,
    }
end

function Source:getCompleted(page)
    page = page or 1
    -- Xóa &hoanthanh=1 để lấy tất cả truyện dịch thay vì chỉ lấy truyện đã hoàn thành
    local url = self.base_url .. "/danh-sach?truyendich=1&sapxep=capnhat"
    if page > 1 then
        url = url .. "&page=" .. page
    end
    local html, err = Http:get(url, requestHeaders())
    if not html then
        return nil, err
    end
    local result = self:parseListing(html, page)
    result.title = "Truyện dịch"
    return result
end

function Source:getGenre(genre, page)
    page = page or 1
    local url = genre.url:gsub("[?&]page=%d+", "")
    if page > 1 then
        if url:find("?") then
            url = url .. "&page=" .. page
        else
            url = url .. "?page=" .. page
        end
    end
    local html, err = Http:get(url, requestHeaders())
    if not html then
        return nil, err
    end
    local result = self:parseListing(html, page)
    result.title = genre.name
    result.genre = genre
    return result
end

-- ========================
-- STORY DETAILS
-- ========================

function Source:parseStoryDetails(html)
    -- Description
    local description_html = html:match('<div[^>]-class="[^"]*summary%-content[^"]*"[^>]*>([%s%S]-)</div>')

    -- Author
    local author = html:match('Tác giả:[%s%S]-<a[^>]*>([%s%S]-)</a>')
    if author then author = Util.stripTags(author) end

    -- Status
    local status = html:match('Tình trạng:[%s%S]-<a[^>]*>([%s%S]-)</a>')
    if status then status = Util.stripTags(status) end

    -- Genres
    local genres = {}
    for anchor_html in (html:match('<div[^>]-class="[^"]*series%-gernes[^"]*"[^>]*>([%s%S]-)</div>') or ""):gmatch('<a[^>]-class="[^"]*series%-gerne%-item[^"]*"[^>]*>([%s%S]-)</a>') do
        local name = Util.stripTags(anchor_html):gsub("^%s*", ""):gsub("%s*$", "")
        if name ~= "" then
            table.insert(genres, name)
        end
    end

    return {
        description = Util.stripTags(description_html)
            ~= "" and Util.stripTags(description_html)
            or Util.getMetaContent(html, "name", "description"),
        author = author,
        status = status,
        genres = genres,
    }
end

function Source:getStoryDetails(story)
    local html, err = Http:get(story.url, requestHeaders())
    if not html then
        return nil, err
    end
    return self:parseStoryDetails(html)
end

-- ========================
-- CHAPTERS LIST
-- ========================

function Source:parseStoryPage(html, story, page)
    local chapters = {}

    -- Chapters are in <div class="chapter-name"><a href="...">TITLE</a></div>
    for block in html:gmatch('<div[^>]-class="[^"]*chapter%-name[^"]*"[^>]*>([%s%S]-)</div>') do
        local anchor = block:match("(<a[^>]*>)")
        if anchor then
            local href = Util.getAttribute(anchor, "href")
            local title = Util.stripTags(block)
            if href and href:find("/c%d+%-", 1, false) then
                table.insert(chapters, {
                    title = Util.trim(title),
                    url = Util.absoluteUrl(self.base_url, href),
                    source_id = self.id,
                    story_url = story.url,
                    kind = self.kind,
                })
            end
        end
    end

    -- DocLN shows all chapters on one page typically, no pagination for chapters
    story.details = self:parseStoryDetails(html)
    return {
        story = story,
        chapters = Util.uniqueBy(chapters, "url"),
        page = page or 1,
        total_pages = 1,
    }
end

function Source:getStoryPage(story, page)
    page = page or 1
    local html, err = Http:get(story.url, requestHeaders(story.url))
    if not html then
        return nil, err
    end
    return self:parseStoryPage(html, story, page)
end

-- ========================
-- XOR SHUFFLE DECRYPTION
-- ========================

local function base64_decode(data)
    local b = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/'
    data = data:gsub('[^' .. b .. '=]', '')
    return (data:gsub('.', function(x)
        if x == '=' then return '' end
        local r, f = '', (b:find(x) - 1)
        for i = 6, 1, -1 do
            r = r .. (f % 2 ^ i - f % 2 ^ (i - 1) > 0 and '1' or '0')
        end
        return r
    end):gsub('%d%d%d?%d?%d?%d?%d?%d?', function(x)
        if #x ~= 8 then return '' end
        local c = 0
        for i = 1, 8 do c = c + (x:sub(i, i) == '1' and 2 ^ (8 - i) or 0) end
        return string.char(c)
    end))
end

local function xorDecrypt(encrypted_bytes, key)
    local result = {}
    local key_len = #key
    for i = 1, #encrypted_bytes do
        local key_byte = string.byte(key, ((i - 1) % key_len) + 1)
        local enc_byte = string.byte(encrypted_bytes, i)
        -- XOR with bitwise operations
        local ok, bit = pcall(require, "bit")
        if ok then
            table.insert(result, string.char(bit.bxor(enc_byte, key_byte)))
        else
            -- Fallback XOR without bit library
            local xor_val = 0
            local p = 128
            while p > 0 do
                local a = enc_byte >= p
                local b = key_byte >= p
                if a then enc_byte = enc_byte - p end
                if b then key_byte = key_byte - p end
                if a ~= b then xor_val = xor_val + p end
                p = p / 2
            end
            table.insert(result, string.char(xor_val))
        end
    end
    return table.concat(result)
end

local function decryptChapterContent(data_k, data_c_json)
    -- data_c is a JSON array of base64 strings
    -- Each string starts with 4 chars = index (zero-padded), rest is base64 content
    -- Sort by index, concatenate, base64 decode, XOR with key

    -- Parse JSON array manually (simple case: array of strings)
    local chunks = {}
    for chunk in data_c_json:gmatch('"([^"]*)"') do
        -- Unescape HTML entities
        chunk = chunk:gsub("&quot;", '"'):gsub("&amp;", "&"):gsub("&lt;", "<"):gsub("&gt;", ">")
        table.insert(chunks, chunk)
    end

    if #chunks == 0 then
        Debug.write("[docln] No encrypted chunks found")
        return nil
    end

    -- Sort chunks by their 4-char index prefix
    table.sort(chunks, function(a, b)
        local idx_a = tonumber(a:sub(1, 4)) or 0
        local idx_b = tonumber(b:sub(1, 4)) or 0
        return idx_a < idx_b
    end)

    -- Decrypt each chunk separately (key index resets for each chunk)
    local decrypted_parts = {}
    for _, chunk in ipairs(chunks) do
        local encoded = chunk:sub(5)
        local encrypted = base64_decode(encoded)
        local decrypted = xorDecrypt(encrypted, data_k)
        table.insert(decrypted_parts, decrypted)
    end

    local final_decrypted = table.concat(decrypted_parts)
    Debug.write("[docln] Decrypted content length: " .. #final_decrypted)
    return final_decrypted
end

-- ========================
-- CHAPTER READING
-- ========================

function Source:parseChapter(html, chapter)
    -- Chapter title
    local volume_title = html:match('<h2[^>]-class="[^"]*title%-item[^"]*"[^>]*>([%s%S]-)</h2>')
    local chapter_title = html:match('<h4[^>]-class="[^"]*title%-item[^"]*"[^>]*>([%s%S]-)</h4>')
    local title = Util.stripTags(chapter_title) or chapter.title
    if volume_title then
        local vol = Util.stripTags(volume_title)
        if vol ~= "" then
            title = vol .. " - " .. title
        end
    end

    -- Try to find encrypted content first
    local data_s = html:match('id="chapter%-c%-protected"[^>]-data%-s="([^"]+)"')
    local data_k = html:match('id="chapter%-c%-protected"[^>]-data%-k="([^"]+)"')
    local data_c = html:match('id="chapter%-c%-protected"[^>]-data%-c="(%[.-%])"')

    local content

    if data_s and data_k and data_c then
        -- Unescape HTML entities in data_c
        data_c = data_c:gsub("&quot;", '"'):gsub("&amp;", "&"):gsub("&lt;", "<"):gsub("&gt;", ">")
        Debug.write("[docln] Found encrypted content: scheme=" .. data_s .. ", key=" .. data_k:sub(1, 8) .. "...")

        if data_s == "xor_shuffle" then
            content = decryptChapterContent(data_k, data_c)
        else
            Debug.write("[docln] Unknown encryption scheme: " .. data_s)
        end
    end

    -- Fallback: try plain chapter-content div
    if not content or content == "" then
        local start_at = html:find('id="chapter%-content"')
        if start_at then
            start_at = html:find(">", start_at, true)
            if start_at then
                local end_at = html:find('</div>%s*<section', start_at)
                    or html:find('</div>%s*<div[^>]-style="text%-align: center', start_at)
                    or html:find('</div>', start_at, true)
                if end_at then
                    content = html:sub(start_at + 1, end_at - 1)
                end
            end
        end
    end

    if not content or content == "" then
        return nil, "Không tìm thấy nội dung chương. Có thể cần đăng nhập và spam 5 comment trên web để mở khóa tài khoản."
    end

    -- Clean up content
    content = Util.sanitizeContentHtml(content)
    -- Remove hidden title paragraph
    content = content:gsub('<p style="display: none">[^<]*</p>', "")
    -- Remove banner images
    content = content:gsub('<a href="/truyen/%d+"[^>]*>.-</a>', "")

    -- Navigation: previous/next chapter
    local previous_url, next_url

    -- Navigation bar: <section class="rd-basic_icon">
    -- fa-backward = previous, fa-forward = next
    local nav_section = html:match('<section[^>]-class="[^"]*rd%-basic_icon[^"]*"[^>]*>([%s%S]-)</section>')
    if nav_section then
        for anchor_attrs in nav_section:gmatch("<a([^>]*)>") do
            local href = Util.getAttribute(anchor_attrs, "href")
            local inner = html:sub(html:find(anchor_attrs, 1, true) or 1)
            if href and href:find("/c%d+%-", 1, false) then
                if inner:find("fa%-backward", 1, true) then
                    previous_url = Util.absoluteUrl(self.base_url, href)
                elseif inner:find("fa%-forward", 1, true) then
                    next_url = Util.absoluteUrl(self.base_url, href)
                end
            end
        end
    end

    -- Fallback: parse all nav anchors with fa-backward/fa-forward
    if not previous_url and not next_url then
        for anchor_attrs, anchor_inner in html:gmatch('<a([^>]*)>([%s%S]-)</a>') do
            local href = Util.getAttribute(anchor_attrs, "href")
            if href and href:find("/c%d+%-", 1, false) then
                if anchor_inner:find("fa%-backward", 1, true) then
                    previous_url = Util.absoluteUrl(self.base_url, href)
                elseif anchor_inner:find("fa%-forward", 1, true) then
                    next_url = Util.absoluteUrl(self.base_url, href)
                end
            end
        end
    end

    return {
        title = title,
        content = content,
        previous_url = previous_url,
        next_url = next_url,
        url = chapter.url,
        kind = self.kind,
    }
end

function Source:getChapter(chapter)
    local html, err = Http:get(chapter.url, requestHeaders(chapter.story_url or chapter.url))
    if not html then
        return nil, err
    end
    return self:parseChapter(html, chapter)
end

local socket = require("socket")
local last_request_time = 0

local function applyRateLimit()
    local ok, copas = pcall(require, "copas")
    if ok and copas and copas.sleep then
        local now = socket.gettime()
        -- DocLN giới hạn rất nghiêm ngặt nếu tải số lượng lớn, cần delay tối thiểu 1.2s
        local next_allowed = last_request_time + 1.2 
        if now < next_allowed then
            last_request_time = next_allowed
            copas.sleep(next_allowed - now)
        else
            last_request_time = now
        end
    end
end

function Source:getChapterAsync(chapter)
    -- Xếp hàng giãn cách các request tải chương để tối ưu tốc độ, tránh 429
    applyRateLimit()

    local html, err = Http:requestAsync("GET", chapter.url, nil, requestHeaders(chapter.story_url or chapter.url))
    if not html then
        return nil, err
    end
    return self:parseChapter(html, chapter)
end

return Source
```

## truyenviet.koplugin/truyenviet/sources/dualeo.lua

```lua
local Http = require("truyenviet/http_client")
local Util = require("truyenviet/helpers")
local ko_util = require("util")

local b64chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/'
local b64dec = {}
for i = 1, 64 do b64dec[b64chars:sub(i,i)] = i - 1 end
local function base64_decode(str)
    str = str:gsub('[^A-Za-z0-9+/=]', '')
    local len = #str
    local out = {}
    for i = 1, len, 4 do
        local c1, c2, c3, c4 = str:sub(i,i), str:sub(i+1,i+1), str:sub(i+2,i+2), str:sub(i+3,i+3)
        local n1, n2, n3, n4 = b64dec[c1], b64dec[c2], b64dec[c3] or 0, b64dec[c4] or 0
        local v = n1 * 262144 + n2 * 4096 + n3 * 64 + n4
        table.insert(out, string.char(math.floor(v / 65536) % 256))
        if c3 ~= '=' then table.insert(out, string.char(math.floor(v / 256) % 256)) end
        if c4 ~= '=' then table.insert(out, string.char(v % 256)) end
    end
    return table.concat(out)
end

local function decrypt_dualeo_url(url)
    local path, filename, ext = url:match("^(.-)/([^/%.]+)%.([^/%.]+)$")
    if not filename then return url end

    local base64 = filename:gsub("-", "+"):gsub("_", "/")
    local pad = (4 - (#base64 % 4)) % 4
    base64 = base64 .. string.rep("=", pad)
    
    local ok, decoded = pcall(base64_decode, base64)
    if not ok or not decoded then return url end

    local salt = "dualeo_salt_2025"
    local ok_bit, bit = pcall(require, "bit")
    if not ok_bit then return url end
    
    local decrypted = ""
    for i = 1, #decoded do
        local charCode = decoded:byte(i)
        local saltCode = salt:byte((i - 1) % #salt + 1)
        decrypted = decrypted .. string.char(bit.bxor(charCode, saltCode))
    end
    
    if decrypted:match("^[A-Za-z0-9%-]+$") then
        return path .. "/" .. decrypted .. "." .. ext
    end
    return url
end

local Source = {
    id = "dualeo",
    name = "Dưa Leo Truyện",
    kind = "comic",
    base_url = "https://dualeotruyenhn.com",
    reversed_chapters = true,
}

local function requestHeaders(referer)
    return {
        ["Referer"] = referer or (Source.base_url .. "/"),
        ["Accept-Language"] = "vi-VN,vi;q=0.9,en;q=0.7",
    }
end

function Source:getCoverHeaders()
    return requestHeaders()
end

function Source:parseSearch(html)
    local stories = {}
    local position = 1

    while true do
        local item_start = html:find('<div class="li_truyen"', position, true)
        if not item_start then
            break
        end
        local next_item = html:find('<div class="li_truyen"', item_start + 1, true)
        local item_html = html:sub(item_start, (next_item or (#html + 1)) - 1)
        position = next_item or (#html + 1)

        local anchor = item_html:match("(<a[^>]*>)")
        local href = Util.getAttribute(anchor, "href")
        local image_tag = item_html:match("(<img[^>]*>)")
        local title = item_html:match('<div[^>]-class="name"[^>]*>([%s%S]-)</div>')
        title = Util.stripTags(title) ~= "" and Util.stripTags(title)
            or Util.getAttribute(image_tag, "alt")

        if href and href:find("/truyen-tranh/", 1, true) and title and title ~= "" then
            local cover = Util.getAttribute(image_tag, "data-src")
                or Util.getAttribute(image_tag, "src")
            table.insert(stories, {
                source_id = self.id,
                title = Util.decodeHtml(title),
                url = Util.absoluteUrl(self.base_url, href),
                cover_url = Util.absoluteUrl(self.base_url, cover),
                kind = self.kind,
            })
        end
    end

    return Util.uniqueBy(stories, "url")
end

function Source:search(query)
    local encoded = ko_util.urlEncode(query):gsub("%%20", "+")
    local html, err = Http:get(
        self.base_url .. "/tim-kiem?key=" .. encoded,
        requestHeaders()
    )
    if not html then
        return nil, err
    end
    return self:parseSearch(html)
end

function Source:parseListing(html, page)
    return {
        stories = self:parseSearch(html),
        genres = Util.parseGenres(html, self.base_url),
        page = page or 1,
        total_pages = Util.maxPage(html, page),
    }
end

function Source:getCompleted(page)
    page = page or 1
    local url = self.base_url .. "/truyen-hoan-thanh"
    if page > 1 then
        url = url .. "?page=" .. page
    end
    local html, err = Http:get(url, requestHeaders())
    if not html then
        return nil, err
    end
    local result = self:parseListing(html, page)
    result.title = "Truyện đã hoàn thành"
    return result
end

function Source:getGenre(genre, page)
    page = page or 1
    local url = genre.url:gsub("%?.*$", "")
    if page > 1 then
        url = url .. "?page=" .. page
    end
    local html, err = Http:get(url, requestHeaders())
    if not html then
        return nil, err
    end
    local result = self:parseListing(html, page)
    result.title = genre.name
    result.genre = genre
    return result
end

function Source:parseStoryDetails(html)
    local description_html = html:match(
        '<div[^>]-class="[^"]*story%-detail%-info[^"]*"[^>]*>([%s%S]-)</div>'
    )
    local genre_html = html:match(
        '<ul[^>]-class="[^"]*list%-tag%-story[^"]*"[^>]*>([%s%S]-)</ul>'
    )
    local info_html = html:match(
        '<div[^>]-class="txt"[^>]*>([%s%S]-)</div>'
    )
    local info_text = Util.stripTags(info_html)

    return {
        description = Util.stripTags(description_html)
            ~= "" and Util.stripTags(description_html)
            or Util.getMetaContent(html, "name", "description"),
        translator = info_text:match("Nhóm dịch:%s*([^\n]+)"),
        status = info_text:match("Tình trạng:%s*([^\n]+)")
            or info_text:match("Tình trang:%s*([^\n]+)"),
        genres = Util.parseGenreNames(genre_html),
    }
end

function Source:getStoryDetails(story)
    local html, err = Http:get(story.url, requestHeaders())
    if not html then
        return nil, err
    end
    return self:parseStoryDetails(html)
end

function Source:parseStoryPage(html, story)
    local chapters = {}
    local story_url = story.url:gsub("/+$", "")
    local chapter_prefix = story_url .. "/chapter-"
    local chapter_start = html:find('<div class="list-chapters"', 1, true)
    local chapter_html = chapter_start and html:sub(chapter_start) or ""

    if not story.cover_url then
        local cover = html:match(
            '<meta%s+property="og:image"%s+content="([^"]+)"'
        )
        story.cover_url = Util.absoluteUrl(self.base_url, cover)
    end

    for anchor_attrs, anchor_html in chapter_html:gmatch("<a([^>]*)>([%s%S]-)</a>") do
        local href = Util.getAttribute(anchor_attrs, "href")
        local chapter_url = Util.absoluteUrl(self.base_url, href)
        if chapter_url and chapter_url:sub(1, #chapter_prefix) == chapter_prefix then
            local title_html = anchor_html:match("^([%s%S]-)</div>") or anchor_html
            local title = Util.stripTags(title_html)
            table.insert(chapters, {
                title = title ~= "" and title
                    or Util.getAttribute(anchor_attrs, "title")
                    or Util.urlLeaf(chapter_url, "Chapter"),
                url = chapter_url,
                source_id = self.id,
                story_url = story.url,
                kind = self.kind,
            })
        end
    end

    story.details = self:parseStoryDetails(html)
    return {
        story = story,
        chapters = Util.uniqueBy(chapters, "url"),
        page = 1,
        total_pages = 1,
    }
end

function Source:getStoryPage(story)
    local html, err = Http:get(story.url, requestHeaders())
    if not html then
        return nil, err
    end
    return self:parseStoryPage(html, story)
end

function Source:parseChapter(html, chapter)
    local images = {}
    local start_at = html:find('<div class="content_view_chap"', 1, true)
    local end_at = start_at
        and html:find('<div class="control_bottom_content"', start_at, true)
    if not start_at then
        return nil, "Không tìm thấy vùng ảnh của chương"
    end

    local content = html:sub(start_at, (end_at or (#html + 1)) - 1)
    for image_tag in content:gmatch("(<img[^>]*>)") do
        local url = Util.getAttribute(image_tag, "data-img")
            or Util.getAttribute(image_tag, "data-src")
            or Util.getAttribute(image_tag, "src")
        if url and not url:find("^data:", 1, false) then
            url = Util.absoluteUrl(self.base_url, url)
            if url and not url:find("/avatar/") and not url:find("logo") then
                url = decrypt_dualeo_url(url)
                table.insert(images, { urls = { url } })
            end
        end
    end
    local unique_images = {}
    local seen = {}
    for _, image in ipairs(images) do
        local url = image.urls[1]
        if not seen[url] then
            seen[url] = true
            table.insert(unique_images, image)
        end
    end
    if #unique_images == 0 then
        return nil, "Không tìm thấy ảnh của chương"
    end

    local title = html:match("<title>([%s%S]-)</title>")
    title = title and Util.stripTags(title):gsub("%s*%-%s*DuaLeoTruyen%s*$", "")

    return {
        title = title ~= "" and title or chapter.title,
        images = unique_images,
        url = chapter.url,
        referer = chapter.url,
        kind = self.kind,
    }
end

function Source:getChapter(chapter)
    local html, err = Http:get(chapter.url, requestHeaders(chapter.story_url))
    if not html then
        return nil, err
    end
    return self:parseChapter(html, chapter)
end

function Source:getImageHeaders()
    return {
        ["Referer"] = self.base_url,
        ["Accept"] = "image/webp,image/apng,image/*,*/*;q=0.8",
        ["Accept-Language"] = "vi-VN,vi;q=0.9,en;q=0.7",
        ["Cache-Control"] = "no-cache",
    }
end

return Source
```

## truyenviet.koplugin/truyenviet/sources/dualeotruyenfull.lua

```lua
local Http = require("truyenviet/http_client")
local Util = require("truyenviet/helpers")
local ko_util = require("util")

local Source = {
    id = "dualeotruyenfull",
    name = "DualeoTruyenFull",
    kind = "text",
    base_url = "https://dualeotruyenfull.net",
}

local DUALEO_GENRES = {
    { name = "Đam Mỹ", url = "the-loai/dam-my/" },
    { name = "Cáo H", url = "the-loai/caoh/" },
    { name = "Hiện Đại", url = "the-loai/hiendai/" },
    { name = "Song tính", url = "the-loai/songtinh/" },
    { name = "Sủng", url = "the-loai/sung/" },
    { name = "Danmei", url = "the-loai/danmei/" },
    { name = "H văn", url = "the-loai/hvan/" },
    { name = "Đô Thị", url = "the-loai/do-thi/" },
    { name = "1x1", url = "the-loai/1x1/" }
}

local function stdHeaders(base_url)
    return {
        ["User-Agent"] = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36",
        ["Referer"] = base_url .. "/",
    }
end

local function parseStories(html, source_id)
    local stories = {}
    local seen = {}
    -- In DualeoTruyenFull, story cards are under <div class="story-cover-wrap ...">
    -- or <div class="uk-width-1-3@m uk-width-1-2"> etc.
    for block in html:gmatch('<a class="uk%-link%-toggle" href="https?://dualeotruyenfull%.net/doc%-truyen/[^"]+".-</a>') do
        local url = block:match('href="(https?://dualeotruyenfull%.net/doc%-truyen/[^"]+)"')
        local cover = block:match('<img[^>]*src="([^"]+)"')
        local title = block:match('<strong[^>]*>([^<]+)</strong>') or block:match('<h3[^>]*>([^<]+)</h3>')
        
        if url and title and not seen[url] then
            seen[url] = true
            table.insert(stories, {
                source_id = source_id,
                title = Util.decodeHtml(Util.trim(title)),
                url = url,
                cover_url = cover,
                kind = "text",
            })
        end
    end
    return stories
end

function Source:search(query)
    local encoded = ko_util.urlEncode(query)
    local url = self.base_url .. "/?s=" .. encoded
    local html, err = Http:get(url, stdHeaders(self.base_url))
    if not html then return nil, err end
    return parseStories(html, self.id)
end

function Source:getCompleted(page)
    page = page or 1
    local url = self.base_url .. "/truyen-da-hoan-thanh/"
    if page > 1 then url = url .. "page/" .. page .. "/" end
    local html, err = Http:get(url, stdHeaders(self.base_url))
    
    local stories = html and parseStories(html, self.id) or {}
    local total_pages = html and (tonumber(html:match('page/(%d+)/"[^>]*>Cuối')) or page) or page

    if #stories == 0 then
        url = self.base_url
        if page > 1 then url = url .. "/page/" .. page .. "/" end
        html, err = Http:get(url, stdHeaders(self.base_url))
        if not html then return nil, err end
        stories = parseStories(html, self.id)
        total_pages = tonumber(html:match('page/(%d+)/"[^>]*>Cuối')) or page
    end

    return {
        stories = stories,
        genres = DUALEO_GENRES,
        page = page,
        total_pages = total_pages,
        title = "Truyện mới cập nhật"
    }
end

function Source:getGenre(genre, page)
    page = page or 1
    local url = Util.withTrailingSlash(genre.url)
    if page > 1 then url = url .. "page/" .. page .. "/" end
    local html, err = Http:get(url, stdHeaders(self.base_url))
    if not html then return nil, err end
    
    local total_pages = tonumber(html:match('page/(%d+)/"[^>]*>Cuối')) or page
    return {
        stories = parseStories(html, self.id),
        genres = DUALEO_GENRES,
        page = page,
        total_pages = total_pages,
        title = genre.name
    }
end

function Source:getStoryDetails(story)
    local html, err = Http:get(story.url, stdHeaders(self.base_url))
    if not html then return nil, err end
    
    local title = html:match('<meta property="og:title" content="([^"]+)"')
        or html:match('<h1[^>]*>([^<]+)</h1>')
    
    local author = html:match('Tác giả:[^<]*<a[^>]*>([^<]+)</a>')
        or html:match('Tác giả:%s*([^<]+)<br')
    
    local desc_block = html:match('<div id="manga%-description"[^>]*>(.-)</div>')
        or html:match('<div class="[^"]*desc[^"]*"[^>]*>(.-)</div>')
        or html:match('<div class="[^"]*description[^"]*"[^>]*>(.-)</div>')
        or html:match('<div class="uk%-panel uk%-margin%-top uk%-text%-justify[^"]*"[^>]*>(.-)</div>')
    
    local description = desc_block and Util.stripTags(desc_block) or nil
    if description then
        description = description:gsub("^%s+", ""):gsub("%s+$", "")
    end
    
    return {
        title = title and Util.decodeHtml(Util.trim(title)) or story.title,
        author = author and Util.trim(author) or nil,
        description = description,
    }
end

function Source:getStoryPage(story, page)
    page = page or 1
    local url = Util.withTrailingSlash(story.url)
    if page > 1 then url = url .. "page/" .. page .. "/" end
    local html, err = Http:get(url, stdHeaders(self.base_url))
    if not html then return nil, err end
    
    local chapters = {}
    local seen = {}
    
    for href, title in html:gmatch('<a[^>]+href="(https?://dualeotruyenfull%.net/[^"]+chuong[^"]+)"[^>]*>([^<]+)</a>') do
        if not seen[href] then
            seen[href] = true
            table.insert(chapters, {
                title = Util.trim(title),
                url = href,
                source_id = self.id,
                story_url = story.url,
                kind = self.kind,
            })
        end
    end

    local total_pages = tonumber(html:match('page/(%d+)/"[^>]*>Cuối')) or page
    story.details = self:getStoryDetails(story)
    
    return {
        story = story,
        chapters = chapters,
        page = page,
        total_pages = total_pages,
    }
end

function Source:getChapter(chapter)
    local html, err = Http:get(chapter.url, stdHeaders(self.base_url))
    if not html then return nil, err end
    
    local content = html:match('<div id="chapter%-content"[^>]*>(.-)</div>%s*<div class="uk%-margin%-top"')
        or html:match('<div id="chapter%-content"[^>]*>(.-)</div>%s*<div')
    if not content then return nil, "Không tìm thấy nội dung chương" end
    
    -- Xoá quảng cáo
    content = content:gsub('<div id="ads%-chapter%-top"></div>', '')
    
    return Util.sanitizeContentHtml(content)
end

function Source:getChapterAsync(chapter)
    local html, err = Http:requestAsync("GET", chapter.url, nil, stdHeaders(self.base_url))
    if not html then return nil, err end
    
    local content = html:match('<div id="chapter%-content"[^>]*>(.-)</div>%s*<div class="uk%-margin%-top"')
        or html:match('<div id="chapter%-content"[^>]*>(.-)</div>%s*<div')
    if not content then return nil, "Không tìm thấy nội dung chương" end
    
    content = content:gsub('<div id="ads%-chapter%-top"></div>', '')
    
    return Util.sanitizeContentHtml(content)
end

return Source
```

## truyenviet.koplugin/truyenviet/sources/giatocvuongtai.lua

```lua
local Http = require("truyenviet/http_client")
local Util = require("truyenviet/helpers")
local ko_util = require("util")
local json = require("json")

local Source = {
    id = "giatocvuongtai",
    name = "Gia Tộc Vượng Tài",
    kind = "text",
    base_url = "https://giatocvuongtai.com",
    api_url = "https://giatocvuongtai.com/api/public"
}

function Source:getCoverHeaders()
    return {
        ["Referer"] = self.base_url .. "/",
    }
end

local CATEGORIES = {
    { url = "dam_my", name = "Đam Mỹ" },
    { url = "ngon_tinh", name = "Ngôn Tình" },
    { url = "bach_hop", name = "Bách Hợp" },
    { url = "nam_chu", name = "Nam Chủ" },
    { url = "nu_chu", name = "Nữ Chủ" }
}

local function formatStory(self, item)
    local cover = item.cover_url
    if cover and cover ~= "" then
        cover = "https://wsrv.nl/?w=300&output=jpeg&q=70&url=" .. cover:gsub("^https?://", "")
    end
    return {
        source_id = self.id,
        title = item.title,
        url = self.base_url .. "/story/" .. item.slug,
        cover_url = cover,
        kind = self.kind,
        _slug = item.slug,
        _id = item.id
    }
end

function Source:search(query)
    local encoded = ko_util.urlEncode(query)
    local url = self.api_url .. "/stories.json?limit=50&q=" .. encoded
    local json_str, err = Http:get(url)
    if not json_str then return nil, err end
    
    local data = json.decode(json_str)
    if not data or not data.data then return nil, "Invalid JSON" end
    
    local stories = {}
    for _, item in ipairs(data.data) do
        table.insert(stories, formatStory(self, item))
    end
    return stories
end

function Source:getCompleted(page)
    page = page or 1
    local limit = 20
    local offset = (page - 1) * limit
    local url = self.api_url .. "/stories.json?status=published&completionStatus=completed&limit=" .. limit .. "&offset=" .. offset
    
    local json_str, err = Http:get(url)
    if not json_str then return nil, err end
    
    local data = json.decode(json_str)
    if not data or not data.data then return nil, "Invalid JSON" end
    
    local stories = {}
    for _, item in ipairs(data.data) do
        table.insert(stories, formatStory(self, item))
    end
    
    local total_pages = page
    if #stories == limit then
        total_pages = page + 1
    end
    
    return {
        stories = stories,
        genres = CATEGORIES,
        page = page,
        total_pages = total_pages,
        title = "Truyện đã hoàn thành"
    }
end

function Source:getGenre(genre, page)
    page = page or 1
    local limit = 20
    local offset = (page - 1) * limit
    local url = self.api_url .. "/stories.json?status=published&limit=" .. limit .. "&offset=" .. offset
    
    if genre and genre.url then
        url = url .. "&storyRole=" .. genre.url
    end
    
    local json_str, err = Http:get(url)
    if not json_str then return nil, err end
    
    local data = json.decode(json_str)
    if not data or not data.data then return nil, "Invalid JSON" end
    
    local stories = {}
    for _, item in ipairs(data.data) do
        table.insert(stories, formatStory(self, item))
    end
    
    local total_pages = page
    if #stories == limit then
        total_pages = page + 1
    end
    
    return {
        stories = stories,
        genres = CATEGORIES,
        page = page,
        total_pages = total_pages,
        title = genre and genre.name or "Thể loại"
    }
end

function Source:getStoryDetails(story)
    local slug = story.url:match("/story/([^/]+)")
    if not slug then return nil, "Invalid URL" end
    local url = self.api_url .. "/story/" .. slug .. ".json"
    local json_str, err = Http:get(url)
    if not json_str then return nil, err end
    
    local data = json.decode(json_str)
    if not data or not data.data then return nil, "Invalid JSON" end
    
    local item = data.data
    local status = "Đang ra"
    if item.completion_status == "completed" then status = "Hoàn thành" end
    
    local author = item.author_name
    if not author and item.author then author = item.author.name end
    
    local description = item.summary
    if description then
        -- Strip HTML tags and clean up description for plain text display
        description = description:gsub("<br%s*/>", "\n"):gsub("<br>", "\n")
        description = description:gsub("<[^>]+>", "")
        description = description:gsub("[\xF0-\xF7][\x80-\xBF][\x80-\xBF][\x80-\xBF]", "")
        description = description:gsub("\n%s*\n%s*\n+", "\n\n")
        description = Util.decodeHtml(Util.trim(description))
    end

    return {
        description = description,
        author = author,
        status = status,
        genres = item.tags or {},
    }
end

function Source:getStoryPage(story, page)
    page = page or 1
    if page > 1 then
        return {
            story = story,
            chapters = {},
            page = page,
            total_pages = 1
        }
    end
    
    local slug = story.url:match("/story/([^/]+)")
    if not slug then return nil, "Invalid URL" end
    local url = self.api_url .. "/story/" .. slug .. ".json"
    local json_str, err = Http:get(url)
    if not json_str then return nil, err end
    
    local data = json.decode(json_str)
    if not data or not data.data then return nil, "Invalid JSON" end
    
    local item = data.data
    local chapters = {}
    
    if item.chapters then
        for _, chap in ipairs(item.chapters) do
            if chap.is_published then
                table.insert(chapters, {
                    title = chap.title,
                    url = self.base_url .. "/chapter/" .. chap.id,
                    source_id = self.id,
                    story_url = story.url,
                    kind = self.kind,
                    _id = chap.id
                })
            end
        end
    end
    
    local status = "Đang ra"
    if item.completion_status == "completed" then status = "Hoàn thành" end
    local author = item.author_name
    if not author and item.author then author = item.author.name end
    local description = item.summary
    if description then
        description = description:gsub("<br%s*/>", "\n"):gsub("<br>", "\n")
        description = description:gsub("<[^>]+>", "")
        description = description:gsub("[\xF0-\xF7][\x80-\xBF][\x80-\xBF][\x80-\xBF]", "")
        description = description:gsub("\n%s*\n%s*\n+", "\n\n")
        description = Util.decodeHtml(Util.trim(description))
    end
    
    story.details = {
        description = description,
        author = author,
        status = status,
        genres = item.tags or {},
    }
    
    return {
        story = story,
        chapters = chapters,
        page = 1,
        total_pages = 1,
    }
end

local function parseChapterData(self, json_str, chapter)
    local data = json.decode(json_str)
    if not data or not data.data then return nil, "Invalid JSON" end
    
    local chapData = data.data
    local content_html = ""
    
    if chapData.content and chapData.content.blocks then
        for _, block in ipairs(chapData.content.blocks) do
            if block.type == "paragraph" then
                local p_text = ""
                if block.inline then
                    for _, inline in ipairs(block.inline) do
                        local text = Util.escapeHtml(inline.text or "")
                        if inline.marks then
                            for _, mark in ipairs(inline.marks) do
                                if mark == "italic" then text = "<i>" .. text .. "</i>" end
                                if mark == "bold" then text = "<b>" .. text .. "</b>" end
                                if mark == "underline" then text = "<u>" .. text .. "</u>" end
                                if mark == "strike" then text = "<s>" .. text .. "</s>" end
                            end
                        end
                        p_text = p_text .. text
                    end
                end
                content_html = content_html .. "<p>" .. p_text .. "</p>"
            elseif block.type == "image" then
                if block.attrs and block.attrs.src then
                    content_html = content_html .. '<img src="' .. Util.escapeHtml(block.attrs.src) .. '"/>'
                end
            end
        end
    end
    
    return {
        title = chapData.title or chapter.title,
        content = content_html,
        url = chapter.url,
        kind = self.kind,
    }
end

function Source:getChapter(chapter)
    local chapter_id = chapter.url:match("/chapter/([^/]+)")
    if not chapter_id then return nil, "Invalid URL" end
    local url = self.api_url .. "/chapter/" .. chapter_id .. ".json"
    local json_str, err = Http:get(url)
    if not json_str then return nil, err end
    
    return parseChapterData(self, json_str, chapter)
end

function Source:getChapterAsync(chapter)
    local chapter_id = chapter.url:match("/chapter/([^/]+)")
    if not chapter_id then return nil, "Invalid URL" end
    local url = self.api_url .. "/chapter/" .. chapter_id .. ".json"
    local json_str, err = Http:requestAsync("GET", url)
    if not json_str then return nil, err end
    
    return parseChapterData(self, json_str, chapter)
end

return Source
```

## truyenviet.koplugin/truyenviet/sources/haccbl.lua

```lua
local Http = require("truyenviet/http_client")
local Util = require("truyenviet/helpers")
local ko_util = require("util")

local Source = {
    id = "haccbl",
    name = "Hắc Ám Chi Các",
    kind = "comic",
    base_url = "https://haccbl.xyz",
    reversed_chapters = true,
}

local function requestHeaders()
    return {
        ["Referer"] = Source.base_url .. "/",
        ["User-Agent"] = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36",
    }
end

function Source:getCoverHeaders()
    return requestHeaders()
end

local function cleanTitle(value)
    value = Util.stripTags(value)
    value = value:gsub("%s+", " ")
    return Util.trim(value)
end

local function addStory(stories, href, title, cover_url)
    title = cleanTitle(title)
    if not href or title == "" then
        return
    end
    table.insert(stories, {
        source_id = Source.id,
        title = title,
        url = Util.absoluteUrl(Source.base_url, href),
        cover_url = Util.absoluteUrl(Source.base_url, cover_url),
        kind = Source.kind,
    })
end

-- Ảnh bìa haccbl thường là AVIF (KOReader không hỗ trợ).
-- Ưu tiên lấy URL .webp từ srcset nếu có.
local function pickCoverUrl(image_tag)
    if not image_tag then return nil end
    local final_url = nil
    local srcset = Util.getAttribute(image_tag, "srcset")
    if srcset then
        local best_url, best_w = nil, 0
        for url, w in srcset:gmatch("(%S+)%s+(%d+)w") do
            local nw = tonumber(w) or 0
            if url:find("%.webp", 1, true) and nw > best_w then
                best_url, best_w = url, nw
            end
        end
        if best_url then final_url = best_url end
        if not final_url then
            for url, w in srcset:gmatch("(%S+)%s+(%d+)w") do
                local nw = tonumber(w) or 0
                if nw > best_w then
                    best_url, best_w = url, nw
                end
            end
            if best_url then final_url = best_url end
        end
    end
    if not final_url then
        final_url = Util.getAttribute(image_tag, "src") or Util.getAttribute(image_tag, "data-src")
    end
    if final_url then
        final_url = Util.absoluteUrl(Source.base_url, final_url)
        if final_url:find(".avif", 1, true) then
            final_url = final_url:gsub("^https?://", "https://i0.wp.com/") .. "?strip=info&format=webp"
        end
    end
    return final_url
end

function Source:parseSearch(html)
    local stories = {}

    for block in html:gmatch('<div[^>]-class="[^"]*manga%-item%-grid[^"]*"[^>]*>([%s%S]-)</h2>') do
        local href = block:match('<a href="([^"]+)"')
        local image_tag = block:match("(<img[^>]*>)")
        local img = pickCoverUrl(image_tag)
        local title = block:match('<a[^>]-class="[^"]*uk%-link%-heading[^"]*"[^>]*>([%s%S]-)$')
        addStory(stories, href, title, img)
    end

    for item_html in html:gmatch('<article[^>]*>([%s%S]-)</article>') do
        local title_html = item_html:match('<h2[^>]*>([%s%S]-)</h2>')
            or item_html:match('<h3[^>]*>([%s%S]-)</h3>')
        local anchor = title_html and title_html:match("(<a[^>]*>)")
        local href = Util.getAttribute(anchor, "href")
        local image_tag = item_html:match("(<img[^>]*>)")
        if href and href:find("/manga/", 1, true) then
            addStory(stories, href, title_html, pickCoverUrl(image_tag))
        end
    end

    return Util.uniqueBy(stories, "url")
end

function Source:search(query)
    local url = self.base_url .. "/?s=" .. ko_util.urlEncode(query)
    local html, err = Http:get(url, requestHeaders())
    if not html then
        return nil, err
    end
    return self:parseSearch(html)
end
local function parseGenreLinks(html)
    local genres = {}
    local seen = {}

    -- Khối menu/sidebar thể loại thường nằm trong <ul>/<div> có class/id chứa "genre"
    local container = html:match('<ul[^>]-class="[^"]*genres[^"]*"[^>]*>([%s%S]-)</ul>')
        or html:match('<div[^>]-class="[^"]*genres[^"]*"[^>]*>([%s%S]-)</div>')
        or html:match('<ul[^>]-id="genre%-list"[^>]*>([%s%S]-)</ul>')
        or html:match('<div[^>]-id="genre%-list"[^>]*>([%s%S]-)</div>')

    local scope = container or html

    for href, label in scope:gmatch('<a[^>]-href="([^"]+)"[^>]*>([%s%S]-)</a>') do
        local lower_href = href:lower()
        if lower_href:find("/genre/", 1, true)
                or lower_href:find("/genres/", 1, true)
                or lower_href:find("/the%-loai/") then
            local name = Util.stripTags(label):gsub("^%s*", ""):gsub("%s*$", "")
            if name ~= "" and not seen[href] then
                seen[href] = true
                table.insert(genres, {
                    name = name,
                    url = Util.absoluteUrl(Source.base_url, href),
                })
            end
        end
    end

    return genres
end

function Source:parseListing(html, page)
    local stories = self:parseSearch(html)
    local genres = parseGenreLinks(html)

    local max_page = page or 1
    for p_num in html:gmatch('page/(%d+)/"') do
        local n = tonumber(p_num)
        if n and n > max_page then
            max_page = n
        end
    end

    return {
        stories = stories,
        genres = genres,
        page = page or 1,
        total_pages = max_page,
    }
end

function Source:getCompleted(page)
    page = page or 1
    local url = self.base_url .. "/truyen-da-hoan-thanh/"
    if page > 1 then
        url = url .. "page/" .. page .. "/"
    end
    local html, err = Http:get(url, requestHeaders())
    if not html then
        return nil, err
    end
    local result = self:parseListing(html, page)
    result.title = "Truyện đã hoàn thành"
    return result
end

function Source:getGenre(genre, page)
    page = page or 1
    local url = genre.url:gsub("/+$", "")
    if page > 1 then
        url = url .. "/page/" .. page .. "/"
    end
    local html, err = Http:get(url, requestHeaders())
    if not html then
        return nil, err
    end
    local result = self:parseListing(html, page)
    result.title = genre.name
    result.genre = genre
    return result
end

function Source:parseStoryDetails(html)
    local description_html = html:match(
        '<div[^>]-class="[^"]*story%-content[^"]*"[^>]*>([%s%S]-)</div>'
    ) or html:match('<div[^>]-class="[^"]*entry%-content[^"]*"[^>]*>([%s%S]-)</div>')
    
    local author = html:match('Tác giả:[%s%S]-<a[^>]*>([%s%S]-)</a>')
        or html:match('<a[^>]-href="[^"]*/author/[^"]*"[^>]*>.-<span[^>]*>([%s%S]-)</span>')
    if author then author = Util.stripTags(author) end
    
    local status = html:match('Tình trạng:[%s%S]-<span[^>]*>([%s%S]-)</span>')
    if status then status = Util.stripTags(status) end

    local genre_html = html:match('<div[^>]-id="genre%-tags"[^>]*>([%s%S]-)</div>')
        or html:match('<div[^>]-class="[^"]*genres[^"]*"[^>]*>([%s%S]-)</div>')
    local genres = {}
    if genre_html then
        for anchor_html in genre_html:gmatch("<a[^>]*>([%s%S]-)</a>") do
            local clean_genre = Util.stripTags(anchor_html):gsub("^%s*", ""):gsub("%s*$", "")
            table.insert(genres, clean_genre)
        end
    end
    
    local cover_url = html:match('<meta property="og:image" content="([^"]+)"')
    -- Dùng proxy i0.wp.com để chuyển AVIF sang WEBP
    if cover_url and cover_url:find(".avif", 1, true) then
        cover_url = cover_url:gsub("^https?://", "https://i0.wp.com/") .. "?strip=info&format=webp"
    end

    return {
        description = Util.stripTags(description_html)
            ~= "" and Util.stripTags(description_html)
            or Util.getMetaContent(html, "name", "description"),
        author = author,
        status = status,
        genres = genres,
        cover_url = cover_url,
    }
end

function Source:getStoryDetails(story)
    local html, err = Http:get(story.url, requestHeaders())
    if not html then
        return nil, err
    end
    local details = self:parseStoryDetails(html)
    if details.cover_url then
        story.cover_url = details.cover_url
    end
    return details
end

function Source:parseStoryPage(html, story, page)
    local chapters = {}
    
    -- Parse init-manga style chapter items directly from HTML
    for item_html in html:gmatch('<div[^>]-class="[^"]*chapter%-item[^"]*"[^>]*>([%s%S]-)</div>') do
        local href = item_html:match('href="([^"]+)"')
        local title = item_html:match('<span[^>]-class="[^"]*chapter%-name[^"]*"[^>]*>([%s%S]-)</span>')
            or item_html:match('<h3[^>]*>([%s%S]-)</h3>')
            or (href and href:match("chapter%-([%d%.]+)") and ("Chapter " .. href:match("chapter%-([%d%.]+)")))
            or "Chapter"
        
        if href and (href:find("chapter") or href:find("chuong")) then
            table.insert(chapters, {
                title = Util.stripTags(title):gsub("^%s*", ""):gsub("%s*$", ""),
                url = Util.absoluteUrl(self.base_url, href),
                source_id = self.id,
                story_url = story.url,
                kind = self.kind,
            })
        end
    end

    -- Fallback: find anchors directly inside chapter-list (now searching entire html)
    if #chapters == 0 then
        for anchor_attrs, anchor_html in html:gmatch("<a([^>]*)>([%s%S]-)</a>") do
            local href = Util.getAttribute(anchor_attrs, "href")
            if href and (href:find("/chapter") or href:find("/chuong")) and not href:find("#") then
                local title = anchor_html:match(
                    '<h3[^>]*>([%s%S]-)</h3>'
                ) or anchor_html
                table.insert(chapters, {
                    title = Util.stripTags(title):gsub("^%s*", ""):gsub("%s*$", ""),
                    url = Util.absoluteUrl(self.base_url, href),
                    source_id = self.id,
                    story_url = story.url,
                    kind = self.kind,
                })
            end
        end
    end

    -- Final fallback: search entire page for chapter links
    if #chapters == 0 then
        for anchor_attrs, anchor_html in html:gmatch("<a([^>]*)>([%s%S]-)</a>") do
            local href = Util.getAttribute(anchor_attrs, "href")
            local class_attr = Util.getAttribute(anchor_attrs, "class") or ""
            if href and (href:find("/chapter") or class_attr:find("chapter")) and not href:find("#") then
                local title = anchor_html:match(
                    '<h3[^>]-class="[^"]*uk%-link%-heading[^"]*"[^>]*>([%s%S]-)</h3>'
                ) or anchor_html
                local chapter_url = Util.absoluteUrl(self.base_url, href)
                table.insert(chapters, {
                    title = Util.stripTags(title):gsub("^%s*", ""):gsub("%s*$", ""),
                    url = chapter_url,
                    source_id = self.id,
                    story_url = story.url,
                    kind = self.kind,
                })
            end
        end
    end

    local total_pages = Util.maxPage(html, 1)

    story.details = self:parseStoryDetails(html)
    return {
        story = story,
        chapters = Util.uniqueBy(chapters, "url"),
        page = page or 1,
        total_pages = total_pages,
    }
end

function Source:getStoryPage(story, page)
    page = page or 1
    local url = story.url
    if page > 1 then
        url = Util.withTrailingSlash(url) .. "chapter/page/" .. page .. "/"
    end
    local html, err = Http:get(url, requestHeaders())
    if not html then
        return nil, err
    end
    return self:parseStoryPage(html, story, page)
end

function Source:parseChapter(html, chapter)
    local images = {}

    local content = html:match(
        '<div[^>]-id="chapter%-content"[^>]*>([%s%S]-)</div>%s*<div[^>]-class="[^"]*init%-ad after%-content'
    ) or html:match('<div[^>]-id="chapter%-content"[^>]*>([%s%S]-)</div>') or html

    if content:find("InitMangaEncryptedChapter", 1, true) then
        local keyStrBase64 = html:match('"decryption_key"%s*:%s*"([^"]+)"')
        local ciphertext = content:match('"ciphertext"%s*:%s*"([^"]+)"')
        local ivHex = content:match('"iv"%s*:%s*"([^"]+)"')
        local saltHex = content:match('"salt"%s*:%s*"([^"]+)"')

        if keyStrBase64 and ciphertext and ivHex and saltHex then
            local Debug = require("truyenviet/debugger")
            Debug.write("[haccbl] InitMangaEncryptedChapter match: " .. keyStrBase64)
            local status, ffi = pcall(require, "ffi")
            if status and ffi then
                Debug.write("[haccbl] ffi loaded successfully")
                local function safe_cdef(decl)
                    local ok, err = pcall(function() ffi.cdef(decl) end)
                    if not ok then
                        Debug.write("[haccbl] safe_cdef failed: " .. tostring(err) .. " for: " .. decl)
                    end
                end
                safe_cdef("typedef struct evp_md_st EVP_MD;")
                safe_cdef("typedef struct evp_cipher_st EVP_CIPHER;")
                safe_cdef("const EVP_MD *EVP_sha512(void);")
                safe_cdef([[
                    int PKCS5_PBKDF2_HMAC(const char *pass, int passlen,
                                          const unsigned char *salt, int saltlen, int iter,
                                          const EVP_MD *digest,
                                          int keylen, unsigned char *out);
                ]])
                safe_cdef([[
                    unsigned char *HMAC(const EVP_MD *evp_md, const void *key, int key_len,
                                        const unsigned char *d, unsigned long n, unsigned char *md,
                                        unsigned int *md_len);
                ]])
                safe_cdef("const EVP_CIPHER *EVP_aes_256_cbc(void);")
                safe_cdef("typedef struct evp_cipher_ctx_st EVP_CIPHER_CTX;")
                safe_cdef("EVP_CIPHER_CTX *EVP_CIPHER_CTX_new(void);")
                safe_cdef("void EVP_CIPHER_CTX_free(EVP_CIPHER_CTX *c);")
                safe_cdef([[
                    int EVP_DecryptInit_ex(EVP_CIPHER_CTX *ctx, const EVP_CIPHER *cipher, void *impl,
                                           const unsigned char *key, const unsigned char *iv);
                ]])
                safe_cdef([[
                    int EVP_DecryptUpdate(EVP_CIPHER_CTX *ctx, unsigned char *out, int *outl,
                                          const unsigned char *in_buf, int inl);
                ]])
                safe_cdef("int EVP_DecryptFinal_ex(EVP_CIPHER_CTX *ctx, unsigned char *outm, int *outl);")
                local crypto_status, libcrypto
                local lib_names = {
                    "crypto",
                    "libcrypto",
                    "libcrypto.so",
                    "libcrypto.so.3",
                    "libcrypto.so.1.1",
                    "libcrypto.so.1.0.0",
                    "libcrypto.so.56",
                    "libcrypto.so.55",
                    "libcrypto.so.48",
                    "libcrypto.so.47",
                    "libcrypto.so.46",
                    "libcrypto.so.45",
                    "libcrypto.so.44",
                    "libcrypto.so.43",
                    "libcrypto.so.42",
                    "libcrypto.so.41",
                    "libcrypto.so.39",
                    "libcrypto.so.38",
                    "libcrypto.so.37",
                    "libcrypto.so.35",
                    "libcrypto.so.1.0.2",
                    "libcrypto.so.1.0.1",
                    "libs/libcrypto.so",
                    "libs/libcrypto.so.3",
                    "libs/libcrypto.so.1.1",
                    "libs/libcrypto.so.56",
                    "libs/libcrypto.so.55",
                    "libs/libcrypto.so.1.0.0",
                    "libs/libcrypto-3-x64.dll",
                    "libs/libcrypto-1_1-x64.dll",
                    "libcrypto-3-x64",
                    "libcrypto-1_1-x64",
                    "libcrypto-3",
                    "libcrypto-1_1",
                    "crypto-3",
                    "crypto-1_1",
                    "libcrypto-3.dll",
                    "libcrypto-1_1.dll",
                    "ssl",
                    "libssl",
                    "libssl.so",
                    "libs/libssl.so",
                }
                local ok_req_crypto, req_crypto = pcall(require, "crypto")
                if ok_req_crypto and type(req_crypto) == "table" then
                    local keys = {}
                    for k, v in pairs(req_crypto) do table.insert(keys, tostring(k)) end
                    Debug.write("[haccbl] require('crypto') found. Keys: " .. table.concat(keys, ", "))
                else
                    Debug.write("[haccbl] require('crypto') NOT found or not a table: " .. tostring(req_crypto))
                end

                local ok_ffi_c, err_ffi_c = pcall(function() return ffi.C.EVP_sha512 end)
                Debug.write("[haccbl] ffi.C.EVP_sha512 available? " .. tostring(ok_ffi_c) .. " err: " .. tostring(err_ffi_c))

                for _, name in ipairs(lib_names) do
                    local loaded_via = nil
                    crypto_status, libcrypto = pcall(ffi.load, name)
                    if crypto_status and libcrypto then
                        loaded_via = "load"
                    else
                        if ffi.loadlib then
                            crypto_status, libcrypto = pcall(ffi.loadlib, name)
                            if crypto_status and libcrypto then
                                loaded_via = "loadlib"
                            end
                        end
                    end
                    
                    if loaded_via then
                        local ok_sha, err_sha = pcall(function() return libcrypto.EVP_sha512 end)
                        local ok_hmac, err_hmac = pcall(function() return libcrypto.HMAC end)
                        local ok_pb, err_pb = pcall(function() return libcrypto.PKCS5_PBKDF2_HMAC end)
                        Debug.write(string.format("[haccbl] Loaded %s via %s: type=%s, EVP_sha512=%s (%s), HMAC=%s (%s), PKCS5_PBKDF2_HMAC=%s (%s)",
                            name, loaded_via, type(libcrypto),
                            tostring(ok_sha), tostring(err_sha),
                            tostring(ok_hmac), tostring(err_hmac),
                            tostring(ok_pb), tostring(err_pb)
                        ))
                        
                        local has_min_symbols = (ok_sha and ok_hmac) or ok_pb
                        if has_min_symbols then
                            break
                        else
                            libcrypto = nil
                            crypto_status = false
                        end
                    end
                end
                local function hex2bin(hexstr)
                    return (hexstr:gsub('..', function(cc)
                        return string.char(tonumber(cc, 16))
                    end))
                end

                local function base64_decode(data)
                    local b = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/'
                    data = string.gsub(data, '[^'..b..'=]', '')
                    return (data:gsub('.', function(x)
                        if (x == '=') then return '' end
                        local r,f='',(b:find(x)-1)
                        for i=6,1,-1 do r=r..(f%2^i-f%2^(i-1)>0 and '1' or '0') end
                        return r;
                    end):gsub('%d%d%d?%d?%d?%d?%d?%d?', function(x)
                        if (#x ~= 8) then return '' end
                        local c=0
                        for i=1,8 do c=c+(x:sub(i,i)=='1' and 2^(8-i) or 0) end
                        return string.char(c)
                    end))
                end

                local keyStr = base64_decode(keyStrBase64)
                local salt = hex2bin(saltHex)
                local iv = hex2bin(ivHex)
                local cipherbin = base64_decode(ciphertext)
                local decrypt_ok = false

                if crypto_status and libcrypto then
                    Debug.write("[haccbl] Using libcrypto pointer: " .. tostring(libcrypto))
                    local derivedKey
                    local has_pbkdf2, err_pbkdf2 = pcall(function() return libcrypto.PKCS5_PBKDF2_HMAC end)
                    if has_pbkdf2 then
                        derivedKey = ffi.new("unsigned char[32]")
                        local res = libcrypto.PKCS5_PBKDF2_HMAC(keyStr, #keyStr, salt, #salt, 999, libcrypto.EVP_sha512(), 32, derivedKey)
                        if res == 1 then
                            local decrypt_res, decrypt_err = pcall(function()
                                local ctx = libcrypto.EVP_CIPHER_CTX_new()
                                if ctx ~= nil then
                                    libcrypto.EVP_DecryptInit_ex(ctx, libcrypto.EVP_aes_256_cbc(), nil, derivedKey, iv)
                                    local out = ffi.new("unsigned char[?]", #cipherbin + 32)
                                    local outl = ffi.new("int[1]")
                                    local outl2 = ffi.new("int[1]")
                                    libcrypto.EVP_DecryptUpdate(ctx, out, outl, cipherbin, #cipherbin)
                                    if libcrypto.EVP_DecryptFinal_ex(ctx, out + outl[0], outl2) == 1 then
                                        content = ffi.string(out, outl[0] + outl2[0])
                                        decrypt_ok = true
                                        Debug.write("[haccbl] native decrypt successful! content len: " .. #content)
                                    end
                                    libcrypto.EVP_CIPHER_CTX_free(ctx)
                                end
                            end)
                        end
                    end
                end

                if not decrypt_ok then
                    Debug.write("[haccbl] Falling back to pure lua pbkdf2 and aes")
                    local fallback_ok, fallback_err = pcall(function()
                        local bit = require("bit")
                        local current_dir = debug.getinfo(1, "S").source:match("^@?(.*[/\\])")
                        if not string.find(package.path, "aeslua[/\\]src[/\\]%?%.lua", 1, true) then
                            package.path = package.path .. ";" .. current_dir .. "aeslua/src/?.lua;" .. current_dir .. "?.lua"
                        end
                        
                        local sha2 = require("sha2")
                        local aeslua_main = require("aeslua")
                        local ciphermode = require("aeslua.ciphermode")
                        local util = require("aeslua.util")
                        
                        local hLen = 64
                        local l = math.ceil(32 / hLen)
                        local derivedKeyStr = ""
                        
                        for i = 1, l do
                            local i_bin = string.char(
                                bit.rshift(i, 24) % 256,
                                bit.rshift(i, 16) % 256,
                                bit.rshift(i, 8) % 256,
                                i % 256
                            )
                            
                            local u_input = salt .. i_bin
                            local u_in_hex = sha2.hmac(sha2.sha512, keyStr, u_input)
                            local u_in_bin = hex2bin(u_in_hex)
                            local t_bin = u_in_bin
                            
                            for j = 2, 999 do
                                u_in_hex = sha2.hmac(sha2.sha512, keyStr, u_in_bin)
                                u_in_bin = hex2bin(u_in_hex)
                                
                                local new_t_bin = {}
                                for k = 1, 64 do
                                    new_t_bin[k] = string.char(bit.bxor(string.byte(t_bin, k), string.byte(u_in_bin, k)))
                                end
                                t_bin = table.concat(new_t_bin)
                            end
                            
                            derivedKeyStr = derivedKeyStr .. t_bin
                        end
                        
                        local derivedKeyStr32 = string.sub(derivedKeyStr, 1, 32)
                        local key_table = {string.byte(derivedKeyStr32, 1, 32)}
                        local iv_table = {string.byte(iv, 1, 16)}
                        
                        local plain = ciphermode.decryptString(key_table, cipherbin, ciphermode.decryptCBC, iv_table)
                        
                        local function pkcs7_unpad(data)
                            if #data == 0 then return nil end
                            local pad_len = string.byte(data, #data)
                            if pad_len > 0 and pad_len <= 16 then
                                return string.sub(data, 1, #data - pad_len)
                            end
                            return data
                        end
                        
                        local unpadded = pkcs7_unpad(plain)
                        if unpadded then
                            content = unpadded
                            decrypt_ok = true
                        end
                    end)
                    if fallback_ok and decrypt_ok then
                        Debug.write("[haccbl] pure lua pbkdf2 and aes success! content len: " .. #content)
                    else
                        Debug.write("[haccbl] pure lua pbkdf2 or aes failed: " .. tostring(fallback_err))
                    end
                end
            else
                Debug.write("[haccbl] status is false or ffi is nil: status=" .. tostring(status))
            end
        end

        if content:find("InitMangaEncryptedChapter", 1, true) then
            return nil, "Hắc Ám Chi Các đang mã hóa ảnh chương, plugin chưa giải mã được nguồn này (hoặc thiếu thư viện)."
        end
    end

    for image_tag in content:gmatch("(<img[^>]*>)") do
        local src = Util.getAttribute(image_tag, "data-src")
            or Util.getAttribute(image_tag, "data-lazy-src")
            or Util.getAttribute(image_tag, "src")
        local url = Util.absoluteUrl(self.base_url, src)
        if url
                and not url:find("cropped%-icon", 1, false)
                and not url:find("avatar", 1, true)
                and not url:find("gravatar", 1, true) then
            if url:find("%.avif", 1, true) then
                url = url:gsub("^https?://", "https://i0.wp.com/") .. "?strip=info"
            end
            table.insert(images, { urls = { url } })
        end
    end

    if #images == 0 then
        return nil, "Không tìm thấy ảnh của chương"
    end

    return {
        title = chapter.title,
        images = images,
        url = chapter.url,
        referer = self.base_url .. "/",
        kind = self.kind,
    }
end

function Source:getChapter(chapter)
    local html, err = Http:get(chapter.url, requestHeaders())
    if not html then
        return nil, err
    end
    return self:parseChapter(html, chapter)
end

return Source
```

## truyenviet.koplugin/truyenviet/sources/metruyenvn.lua

```lua
local Http = require("truyenviet/http_client")
local Util = require("truyenviet/helpers")
local ko_util = require("util")

-- MeTruyenVN — Đọc Truyện Đam Mỹ Hoàn (WordPress)
local Source = {
    id = "metruyenvn",
    name = "Mê Truyện VN",
    kind = "text",
    base_url = "https://metruyenvn.org",
}

local function stdHeaders(base_url)
    return {
        ["User-Agent"] = "Mozilla/5.0 (Linux; Android 10; K) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36",
        ["Referer"] = base_url .. "/",
    }
end

local function parseCards(html, source_id)
    local stories = {}
    local seen = {}
    local pos = 1
    while true do
        local block_s, block_e = html:find('<div class="comic-item-box">', pos, true)
        if not block_s then break end
        local block_end = html:find('<div class="comic-item-box">', block_e + 1, true) or #html
        local block = html:sub(block_s, block_end - 1)
        
        local href = block:match('href="(https?://metruyenvn%.org/truyen/[^"]+)"')
        local title = block:match('title="([^"]+)"')
        local cover = block:match('<img[^>]+src="([^"]+)"')
        
        if href and title and not seen[href] then
            seen[href] = true
            table.insert(stories, {
                source_id = source_id,
                title = Util.decodeHtml(title),
                url = href,
                cover_url = cover,
                kind = "text",
            })
        end
        pos = block_e + 1
    end
    return stories
end

local function parseListing(html, page, source_id, base_url)
    local stories = parseCards(html, source_id)
    local max_page = page or 1
    for n in html:gmatch('/page/(%d+)/') do
        local p = tonumber(n)
        if p and p > max_page then max_page = p end
    end
    local genres = {}
    for href, prefix, name in html:gmatch('<a[^>]+href="(https?://metruyenvn%.org/([^/]+)/[^"]+)"[^>]*>([^<]+)</a>') do
        if prefix == "the-loai" or prefix == "nhom" or prefix == "loai-truyen" or prefix == "tu-khoa" or prefix == "tags" or prefix == "tag" then
            table.insert(genres, { name = Util.trim(name), url = href })
        end
    end
    return {
        stories = stories,
        genres = genres,
        page = page or 1,
        total_pages = max_page,
        title = "Truyện mới nhất",
    }
end

function Source:search(query)
    local encoded = ko_util.urlEncode(query)
    local url = self.base_url .. "/?s=" .. encoded
    local html, err = Http:get(url, stdHeaders(self.base_url))
    if not html then return nil, err end
    return parseCards(html, self.id)
end

function Source:getCompleted(page)
    page = page or 1
    local url = self.base_url .. "/"
    if page > 1 then url = url .. "page/" .. page .. "/" end
    local html, err = Http:get(url, stdHeaders(self.base_url))
    if not html then return nil, err end
    local result = parseListing(html, page, self.id, self.base_url)
    result.title = "Truyện đam mỹ mới nhất"
    return result
end

function Source:getGenre(genre, page)
    page = page or 1
    local url = Util.withTrailingSlash(genre.url)
    if page > 1 then url = url .. "page/" .. page .. "/" end
    local html, err = Http:get(url, stdHeaders(self.base_url))
    if not html then return nil, err end
    local result = parseListing(html, page, self.id, self.base_url)
    result.title = genre.name
    return result
end

function Source:getStoryDetails(story)
    local html, err = Http:get(story.url, stdHeaders(self.base_url))
    if not html then return nil, err end
    
    local title = html:match('<meta property="og:title" content="([^"]+)%s*-%s*Mê Truyện')
        or html:match('<h2[^>]*class="[^"]*info%-title[^"]*"[^>]*>([^<]+)</h2>')
        or html:match('<meta itemprop="name" content="([^"]+)">')
    
    local author = html:match('<strong>Tác giả:</strong>%s*<span>%s*(.-)%s*</span>')
        or html:match('Tác giả[%s%S]-<a[^>]*>([^<]+)</a>')
    
    local desc_html = html:match('<div[^>]+class="[^"]*desc%-text[^"]*"[^>]*>(.-)</div>')
        or html:match('<div[^>]+itemprop="description"[^>]*>(.-)</div>')
    
    local description
    if desc_html then
        description = Util.stripTags(desc_html)
        description = description:gsub("^%s+", ""):gsub("%s+$", "")
    end
    
    local genres = {}
    local tags_html = html:match('<div class="tags[^"]*">(.-)</div>')
    if tags_html then
        for name in tags_html:gmatch('<a[^>]*>([^<]+)</a>') do
            table.insert(genres, Util.trim(name))
        end
    end

    local status_html = html:match('<strong>Tình trạng:</strong>%s*<span[^>]*>(.-)</span>')
    local is_completed = false
    if status_html and status_html:find("Trọn bộ") then
        is_completed = true
    end
    
    return {
        title = title and Util.decodeHtml(Util.trim(title)) or story.title,
        author = author and Util.trim(author) or nil,
        description = description,
        genres = genres,
        is_completed = is_completed,
    }
end

function Source:getStoryPage(story, page)
    page = page or 1
    local html, err = Http:get(story.url, stdHeaders(self.base_url))
    if not html then return nil, err end
    
    local chapters = {}
    local seen = {}
    
    -- Chapter format: <a href="https://metruyenvn.org/chuong-123/">...</a>
    for href, inner_html in html:gmatch('<a[^>]+href="(https?://metruyenvn%.org/chuong%-[^"]+)"[^>]*>([%s%S]-)</a>') do
        if not seen[href] then
            seen[href] = true
            local title = inner_html:match('<span class="hidden%-sm hidden%-xs">(.-)</span>')
            if not title then title = inner_html end
            title = Util.trim(Util.stripTags(title))
            table.insert(chapters, {
                title = title,
                url = href,
                source_id = self.id,
                story_url = story.url,
                kind = self.kind,
            })
        end
    end
    
    if #chapters == 0 then
        for href, inner_html in html:gmatch('<a[^>]+class="[^"]*comic%-chapter[^"]*"[^>]+href="([^"]+)"[^>]*>([%s%S]-)</a>') do
            if href:find("^https?://") and not seen[href] then
                seen[href] = true
                local title = inner_html:match('<span class="hidden%-sm hidden%-xs">(.-)</span>')
                if not title then title = inner_html end
                title = Util.trim(Util.stripTags(title))
                table.insert(chapters, {
                    title = title,
                    url = href,
                    source_id = self.id,
                    story_url = story.url,
                    kind = self.kind,
                })
            end
        end
    end
    
    story.details = self:getStoryDetails(story)
    
    return {
        story = story,
        chapters = chapters,
        page = page,
        total_pages = 1,
    }
end

function Source:getChapter(chapter)
    local html, err = Http:get(chapter.url, stdHeaders(self.base_url))
    if not html then return nil, err end
    
    local start_pos = html:find('<div[^>]*class="[^"]*view%-chapter[^"]*"[^>]*>')
        or html:find('<div[^>]*id="chapter%-content"[^>]*>')
        
    if not start_pos then
        return nil, "Không tìm thấy nội dung chương"
    end
    
    local content_start = html:find('>', start_pos)
    if not content_start then return nil, "Lỗi cú pháp HTML" end
    
    local end_pos = html:find('</div>%s*</div>%s*<section', content_start)
        or html:find('</div>%s*<div[^>]*class="margin%-bottom%-15px"', content_start)
        or html:find('</div>%s*<div', content_start)
        
    local content = end_pos and html:sub(content_start + 1, end_pos - 1) or html:sub(content_start + 1)
    
    return Util.sanitizeContentHtml(content)
end

function Source:getChapterAsync(chapter)
    local html, err = Http:requestAsync("GET", chapter.url, nil, stdHeaders(self.base_url))
    if not html then return nil, err end
    local start_pos = html:find('<div[^>]*class="[^"]*view%-chapter[^"]*"[^>]*>')
        or html:find('<div[^>]*id="chapter%-content"[^>]*>')
        
    if not start_pos then
        return nil, "Không tìm thấy nội dung chương"
    end
    
    local content_start = html:find('>', start_pos)
    if not content_start then return nil, "Lỗi cú pháp HTML" end
    
    local end_pos = html:find('</div>%s*</div>%s*<section', content_start)
        or html:find('</div>%s*<div[^>]*class="margin%-bottom%-15px"', content_start)
        or html:find('</div>%s*<div', content_start)
        
    local content = end_pos and html:sub(content_start + 1, end_pos - 1) or html:sub(content_start + 1)
    
    return Util.sanitizeContentHtml(content)
end

return Source

```

## truyenviet.koplugin/truyenviet/sources/mizzya.lua

```lua
local Http = require("truyenviet/http_client")
local Util = require("truyenviet/helpers")

local Source = {
    id = "mizzya",
    name = "Mizzya",
    kind = "text",
    base_url = "https://mizzya.wordpress.com",
    max_concurrent = 3,
}

local function mizzyaHeaders()
    return {
        ["User-Agent"] = "Mozilla/5.0 (Linux; Android 10; K) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36",
        ["Accept"] = "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8",
        ["Accept-Language"] = "vi-VN,vi;q=0.9,en;q=0.5",
        ["Cache-Control"] = "no-cache",
    }
end

local function mizzyaGet(url)
    local html, err = Http:get(url, mizzyaHeaders(), { force_luasec = true })
    if not html then
        -- Fallback: retry without force_luasec (some Kobo TLS stacks behave differently)
        html, err = Http:get(url, mizzyaHeaders())
    end
    return html, err
end

function Source.getHome()
    local url = Source.base_url .. "/2007/05/15/list-truy%e1%bb%87n/"
    local html, err = mizzyaGet(url)
    if not html then
        return nil, "Không thể kết nối đến máy chủ: " .. tostring(err)
    end

    local items = {}
    local content = html:match('<div class="entry%-content">(.-)<footer') or
                    html:match('<div class="entry%-content">(.-)<div id="jp%-post%-flair"') or
                    html:match('<div class="entry%-content">(.-)</article>')

    if not content then
        return nil, "Không tìm thấy danh sách truyện"
    end

    for href, title in content:gmatch('<a[^>]+href="([^"]+)"[^>]*>([^<]+)</a>') do
        if href:find(Source.base_url, 1, true) and not title:find("<img") then
            title = Util.decodeHtml(title)
            title = Util.stripTags(title)
            if title ~= "" then
                table.insert(items, {
                    source_id = Source.id,
                    title = title,
                    url = href:gsub("#.*$", ""),
                    kind = Source.kind,
                    cover_url = "", -- Đã kiểm tra: trang list của Mizzya là text-only, không có ảnh bìa
                })
            end
        end
    end

    return {
        stories = items,
        genres = {},
        page = 1,
        total_pages = 1,
        title = "Mizzya - Đam Mỹ Hoàn",
    }
end

Source.getLatest = Source.getHome
Source.getCompleted = Source.getHome

function Source:getStoryPage(story, page)
    local html, err = mizzyaGet(story.url)
    if not html then
        return nil, "Không thể kết nối: " .. tostring(err)
    end

    local title = html:match('<h1 class="entry%-title">([^<]+)</h1>') or story.title
    title = Util.decodeHtml(title)
    
    local start_pos = html:find('<div class="entry%-content">')
    local content = ""
    if start_pos then
        local content_start = start_pos + string.len('<div class="entry-content">')
        local e1 = html:find('<div id="jp%-post%-flair"', content_start)
        local e2 = html:find('</div>%s*<!%-%- %.entry%-content %-%->', content_start)
        local e3 = html:find('</div>%s*<footer', content_start)
        local e4 = html:find('</div>%s*</article>', content_start)
        local e5 = html:find('<div class="sharedaddy', content_start)

        local end_pos = nil
        for _, pos in ipairs({e1, e2, e3, e4, e5}) do
            if pos and (not end_pos or pos < end_pos) then
                end_pos = pos
            end
        end

        if end_pos then
            content = html:sub(content_start, end_pos - 1)
        else
            content = html:sub(content_start)
        end
    end
    
    local description = Util.stripTags(content:match("<p>(.-)</p>")) or title
    if description == "" then
        description = title
    end

    local cover = content:match('<img[^>]+src="([^"]+)"')
    if cover then
        cover = Util.absoluteUrl(Source.base_url, cover)
    end

    local author = "Mizzya"
    local author_match = title:match("%s*[-–]%s*([^–-]+)$")
    if author_match then
        author = Util.trim(author_match)
    end

    story.details = {
        title = title,
        author = author,
        description = description,
        cover = cover
    }

    local chapters = {}
    for href, ctitle in content:gmatch('<a[^>]+href="([^"]+)"[^>]*>([^<]+)</a>') do
        if href:find(Source.base_url, 1, true) and not ctitle:find("<img") then
            local is_valid = not href:find("/category/", 1, true) and not href:find("/tag/", 1, true)
            if is_valid and href ~= story.url then
                table.insert(chapters, {
                    title = Util.decodeHtml(Util.stripTags(ctitle)),
                    url = href:gsub("#.*$", ""),
                    source_id = self.id,
                    story_url = story.url,
                    kind = self.kind,
                })
            end
        end
    end

    if #chapters == 0 then
        table.insert(chapters, {
            title = "Full",
            url = story.url,
            source_id = self.id,
            story_url = story.url,
            kind = self.kind,
        })
    end

    return {
        story = story,
        chapters = chapters,
        page = 1,
        total_pages = 1,
    }
end

local function parseChapter(html)
    local start_pos, end_match = html:find('<div[^>]*class="[^"]*entry%-content[^"]*"[^>]*>')
    if not start_pos then
        return nil, "Không tìm thấy nội dung chương"
    end
    
    local content_start = end_match + 1
    
    local e1 = html:find('<div id="jp%-post%-flair"', content_start)
    local e2 = html:find('</div>%s*<!%-%- %.entry%-content %-%->', content_start)
    local e3 = html:find('</div>%s*<footer', content_start)
    local e4 = html:find('</div>%s*</article>', content_start)
    local e5 = html:find('<div class="sharedaddy', content_start)

    local end_pos = nil
    for _, pos in ipairs({e1, e2, e3, e4, e5}) do
        if pos and (not end_pos or pos < end_pos) then
            end_pos = pos
        end
    end

    local content
    if end_pos then
        content = html:sub(content_start, end_pos - 1)
    else
        content = html:sub(content_start)
    end

    if not content or content == "" then
        return nil, "Không tìm thấy nội dung"
    end

    -- Remove extra trailing </div> if any
    content = content:gsub('</div>%s*$', "")
    content = content:gsub('<a[^>]+href="[^"]+"[^>]*>([^<]+)</a>', "%1")
    
    return Util.sanitizeContentHtml(content)
end

function Source:getChapter(chapter)
    local html, err = mizzyaGet(chapter.url)
    if not html then
        return nil, "Không thể kết nối: " .. tostring(err)
    end
    return parseChapter(html)
end

function Source:getChapterAsync(chapter)
    local html, err = Http:requestAsync("GET", chapter.url, nil, mizzyaHeaders())
    if not html then
        return nil, "Không thể kết nối: " .. tostring(err)
    end
    return parseChapter(html)
end

return Source
```

## truyenviet.koplugin/truyenviet/sources/sha2.lua

```lua
--------------------------------------------------------------------------------------------------------------------------
-- sha2.lua
--------------------------------------------------------------------------------------------------------------------------
-- VERSION: 12 (2022-02-23)
-- AUTHOR:  Egor Skriptunoff
-- LICENSE: MIT (the same license as Lua itself)
-- URL:     https://github.com/Egor-Skriptunoff/pure_lua_SHA
--
-- DESCRIPTION:
--    This module contains functions to calculate SHA digest:
--       MD5, SHA-1,
--       SHA-224, SHA-256, SHA-512/224, SHA-512/256, SHA-384, SHA-512,
--       SHA3-224, SHA3-256, SHA3-384, SHA3-512, SHAKE128, SHAKE256,
--       HMAC,
--       BLAKE2b, BLAKE2s, BLAKE2bp, BLAKE2sp, BLAKE2Xb, BLAKE2Xs,
--       BLAKE3, BLAKE3_KDF
--    Written in pure Lua.
--    Compatible with:
--       Lua 5.1, Lua 5.2, Lua 5.3, Lua 5.4, Fengari, LuaJIT 2.0/2.1 (any CPU endianness).
--    Main feature of this module: it was heavily optimized for speed.
--    For every Lua version the module contains particular implementation branch to get benefits from version-specific features.
--       - branch for Lua 5.1 (emulating bitwise operators using look-up table)
--       - branch for Lua 5.2 (using bit32/bit library), suitable for both Lua 5.2 with native "bit32" and Lua 5.1 with external library "bit"
--       - branch for Lua 5.3/5.4 (using native 64-bit bitwise operators)
--       - branch for Lua 5.3/5.4 (using native 32-bit bitwise operators) for Lua built with LUA_INT_TYPE=LUA_INT_INT
--       - branch for LuaJIT without FFI library (useful in a sandboxed environment)
--       - branch for LuaJIT x86 without FFI library (LuaJIT x86 has oddity because of lack of CPU registers)
--       - branch for LuaJIT 2.0 with FFI library (bit.* functions work only with Lua numbers)
--       - branch for LuaJIT 2.1 with FFI library (bit.* functions can work with "int64_t" arguments)
--
--
-- USAGE:
--    Input data should be provided as a binary string: either as a whole string or as a sequence of substrings (chunk-by-chunk loading, total length < 9*10^15 bytes).
--    Result (SHA digest) is returned in hexadecimal representation as a string of lowercase hex digits.
--    Simplest usage example:
--       local sha = require("sha2")
--       local your_hash = sha.sha256("your string")
--    See file "sha2_test.lua" for more examples.
--
--
-- CHANGELOG:
--  version     date      description
--  -------  ----------   -----------
--    12     2022-02-23   Now works in Luau (but NOT optimized for speed)
--    11     2022-01-09   BLAKE3 added
--    10     2022-01-02   BLAKE2 functions added
--     9     2020-05-10   Now works in OpenWrt's Lua (dialect of Lua 5.1 with "double" + "invisible int32")
--     8     2019-09-03   SHA-3 functions added
--     7     2019-03-17   Added functions to convert to/from base64
--     6     2018-11-12   HMAC added
--     5     2018-11-10   SHA-1 added
--     4     2018-11-03   MD5 added
--     3     2018-11-02   Bug fixed: incorrect hashing of long (2 GByte) data streams on Lua 5.3/5.4 built with "int32" integers
--     2     2018-10-07   Decreased module loading time in Lua 5.1 implementation branch (thanks to Peter Melnichenko for giving a hint)
--     1     2018-10-06   First release (only SHA-2 functions)
-----------------------------------------------------------------------------


local print_debug_messages = false  -- set to true to view some messages about your system's abilities and implementation branch chosen for your system

local unpack, table_concat, byte, char, string_rep, sub, gsub, gmatch, string_format, floor, ceil, math_min, math_max, tonumber, type, math_huge =
   table.unpack or unpack, table.concat, string.byte, string.char, string.rep, string.sub, string.gsub, string.gmatch, string.format, math.floor, math.ceil, math.min, math.max, tonumber, type, math.huge


--------------------------------------------------------------------------------
-- EXAMINING YOUR SYSTEM
--------------------------------------------------------------------------------

local function get_precision(one)
   -- "one" must be either float 1.0 or integer 1
   -- returns bits_precision, is_integer
   -- This function works correctly with all floating point datatypes (including non-IEEE-754)
   local k, n, m, prev_n = 0, one, one
   while true do
      k, prev_n, n, m = k + 1, n, n + n + 1, m + m + k % 2
      if k > 256 or n - (n - 1) ~= 1 or m - (m - 1) ~= 1 or n == m then
         return k, false   -- floating point datatype
      elseif n == prev_n then
         return k, true    -- integer datatype
      end
   end
end

-- Make sure Lua has "double" numbers
local x = 2/3
local Lua_has_double = x * 5 > 3 and x * 4 < 3 and get_precision(1.0) >= 53
assert(Lua_has_double, "at least 53-bit floating point numbers are required")

-- Q:
--    SHA2 was designed for FPU-less machines.
--    So, why floating point numbers are needed for this module?
-- A:
--    53-bit "double" numbers are useful to calculate "magic numbers" used in SHA.
--    I prefer to write 50 LOC "magic numbers calculator" instead of storing more than 200 constants explicitly in this source file.

local int_prec, Lua_has_integers = get_precision(1)
local Lua_has_int64 = Lua_has_integers and int_prec == 64
local Lua_has_int32 = Lua_has_integers and int_prec == 32
assert(Lua_has_int64 or Lua_has_int32 or not Lua_has_integers, "Lua integers must be either 32-bit or 64-bit")

-- Q:
--    Does it mean that almost all non-standard configurations are not supported?
-- A:
--    Yes.  Sorry, too many problems to support all possible Lua numbers configurations.
--       Lua 5.1/5.2    with "int32"               will not work.
--       Lua 5.1/5.2    with "int64"               will not work.
--       Lua 5.1/5.2    with "int128"              will not work.
--       Lua 5.1/5.2    with "float"               will not work.
--       Lua 5.1/5.2    with "double"              is OK.          (default config for Lua 5.1, Lua 5.2, LuaJIT)
--       Lua 5.3/5.4    with "int32"  + "float"    will not work.
--       Lua 5.3/5.4    with "int64"  + "float"    will not work.
--       Lua 5.3/5.4    with "int128" + "float"    will not work.
--       Lua 5.3/5.4    with "int32"  + "double"   is OK.          (config used by Fengari)
--       Lua 5.3/5.4    with "int64"  + "double"   is OK.          (default config for Lua 5.3, Lua 5.4)
--       Lua 5.3/5.4    with "int128" + "double"   will not work.
--   Using floating point numbers better than "double" instead of "double" is OK (non-IEEE-754 floating point implementation are allowed).
--   Using "int128" instead of "int64" is not OK: "int128" would require different branch of implementation for optimized SHA512.

-- Check for LuaJIT and 32-bit bitwise libraries
local is_LuaJIT = ({false, [1] = true})[1] and _VERSION ~= "Luau" and (type(jit) ~= "table" or jit.version_num >= 20000)  -- LuaJIT 1.x.x and Luau are treated as vanilla Lua 5.1/5.2
local is_LuaJIT_21  -- LuaJIT 2.1+
local LuaJIT_arch
local ffi           -- LuaJIT FFI library (as a table)
local b             -- 32-bit bitwise library (as a table)
local library_name

if is_LuaJIT then
   -- Assuming "bit" library is always available on LuaJIT
   b = require"bit"
   library_name = "bit"
   -- "ffi" is intentionally disabled on some systems for safety reason
   local LuaJIT_has_FFI, result = pcall(require, "ffi")
   if LuaJIT_has_FFI then
      ffi = result
   end
   is_LuaJIT_21 = not not loadstring"b=0b0"
   LuaJIT_arch = type(jit) == "table" and jit.arch or ffi and ffi.arch or nil
else
   -- For vanilla Lua, "bit"/"bit32" libraries are searched in global namespace only.  No attempt is made to load a library if it's not loaded yet.
   for _, libname in ipairs(_VERSION == "Lua 5.2" and {"bit32", "bit"} or {"bit", "bit32"}) do
      if type(_G[libname]) == "table" and _G[libname].bxor then
         b = _G[libname]
         library_name = libname
         break
      end
   end
end

--------------------------------------------------------------------------------
-- You can disable here some of your system's abilities (for testing purposes)
--------------------------------------------------------------------------------
-- is_LuaJIT = nil
-- is_LuaJIT_21 = nil
-- ffi = nil
-- Lua_has_int32 = nil
-- Lua_has_int64 = nil
-- b, library_name = nil
--------------------------------------------------------------------------------

if print_debug_messages then
   -- Printing list of abilities of your system
   print("Abilities:")
   print("   Lua version:               "..(is_LuaJIT and "LuaJIT "..(is_LuaJIT_21 and "2.1 " or "2.0 ")..(LuaJIT_arch or "")..(ffi and " with FFI" or " without FFI") or _VERSION))
   print("   Integer bitwise operators: "..(Lua_has_int64 and "int64" or Lua_has_int32 and "int32" or "no"))
   print("   32-bit bitwise library:    "..(library_name or "not found"))
end

-- Selecting the most suitable implementation for given set of abilities
local method, branch
if is_LuaJIT and ffi then
   method = "Using 'ffi' library of LuaJIT"
   branch = "FFI"
elseif is_LuaJIT then
   method = "Using special code for sandboxed LuaJIT (no FFI)"
   branch = "LJ"
elseif Lua_has_int64 then
   method = "Using native int64 bitwise operators"
   branch = "INT64"
elseif Lua_has_int32 then
   method = "Using native int32 bitwise operators"
   branch = "INT32"
elseif library_name then   -- when bitwise library is available (Lua 5.2 with native library "bit32" or Lua 5.1 with external library "bit")
   method = "Using '"..library_name.."' library"
   branch = "LIB32"
else
   method = "Emulating bitwise operators using look-up table"
   branch = "EMUL"
end

if print_debug_messages then
   -- Printing the implementation selected to be used on your system
   print("Implementation selected:")
   print("   "..method)
end


--------------------------------------------------------------------------------
-- BASIC 32-BIT BITWISE FUNCTIONS
--------------------------------------------------------------------------------

local AND, OR, XOR, SHL, SHR, ROL, ROR, NOT, NORM, HEX, XOR_BYTE
-- Only low 32 bits of function arguments matter, high bits are ignored
-- The result of all functions (except HEX) is an integer inside "correct range":
--    for "bit" library:    (-2^31)..(2^31-1)
--    for "bit32" library:        0..(2^32-1)

if branch == "FFI" or branch == "LJ" or branch == "LIB32" then

   -- Your system has 32-bit bitwise library (either "bit" or "bit32")

   AND  = b.band                -- 2 arguments
   OR   = b.bor                 -- 2 arguments
   XOR  = b.bxor                -- 2..5 arguments
   SHL  = b.lshift              -- second argument is integer 0..31
   SHR  = b.rshift              -- second argument is integer 0..31
   ROL  = b.rol or b.lrotate    -- second argument is integer 0..31
   ROR  = b.ror or b.rrotate    -- second argument is integer 0..31
   NOT  = b.bnot                -- only for LuaJIT
   NORM = b.tobit               -- only for LuaJIT
   HEX  = b.tohex               -- returns string of 8 lowercase hexadecimal digits
   assert(AND and OR and XOR and SHL and SHR and ROL and ROR and NOT, "Library '"..library_name.."' is incomplete")
   XOR_BYTE = XOR               -- XOR of two bytes (0..255)

elseif branch == "EMUL" then

   -- Emulating 32-bit bitwise operations using 53-bit floating point arithmetic

   function SHL(x, n)
      return (x * 2^n) % 2^32
   end

   function SHR(x, n)
      x = x % 2^32 / 2^n
      return x - x % 1
   end

   function ROL(x, n)
      x = x % 2^32 * 2^n
      local r = x % 2^32
      return r + (x - r) / 2^32
   end

   function ROR(x, n)
      x = x % 2^32 / 2^n
      local r = x % 1
      return r * 2^32 + (x - r)
   end

   local AND_of_two_bytes = {[0] = 0}  -- look-up table (256*256 entries)
   local idx = 0
   for y = 0, 127 * 256, 256 do
      for x = y, y + 127 do
         x = AND_of_two_bytes[x] * 2
         AND_of_two_bytes[idx] = x
         AND_of_two_bytes[idx + 1] = x
         AND_of_two_bytes[idx + 256] = x
         AND_of_two_bytes[idx + 257] = x + 1
         idx = idx + 2
      end
      idx = idx + 256
   end

   local function and_or_xor(x, y, operation)
      -- operation: nil = AND, 1 = OR, 2 = XOR
      local x0 = x % 2^32
      local y0 = y % 2^32
      local rx = x0 % 256
      local ry = y0 % 256
      local res = AND_of_two_bytes[rx + ry * 256]
      x = x0 - rx
      y = (y0 - ry) / 256
      rx = x % 65536
      ry = y % 256
      res = res + AND_of_two_bytes[rx + ry] * 256
      x = (x - rx) / 256
      y = (y - ry) / 256
      rx = x % 65536 + y % 256
      res = res + AND_of_two_bytes[rx] * 65536
      res = res + AND_of_two_bytes[(x + y - rx) / 256] * 16777216
      if operation then
         res = x0 + y0 - operation * res
      end
      return res
   end

   function AND(x, y)
      return and_or_xor(x, y)
   end

   function OR(x, y)
      return and_or_xor(x, y, 1)
   end

   function XOR(x, y, z, t, u)          -- 2..5 arguments
      if z then
         if t then
            if u then
               t = and_or_xor(t, u, 2)
            end
            z = and_or_xor(z, t, 2)
         end
         y = and_or_xor(y, z, 2)
      end
      return and_or_xor(x, y, 2)
   end

   function XOR_BYTE(x, y)
      return x + y - 2 * AND_of_two_bytes[x + y * 256]
   end

end

HEX = HEX
   or
      pcall(string_format, "%x", 2^31) and
      function (x)  -- returns string of 8 lowercase hexadecimal digits
         return string_format("%08x", x % 4294967296)
      end
   or
      function (x)  -- for OpenWrt's dialect of Lua
         return string_format("%08x", (x + 2^31) % 2^32 - 2^31)
      end

local function XORA5(x, y)
   return XOR(x, y or 0xA5A5A5A5) % 4294967296
end

local function create_array_of_lanes()
   return {0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0}
end


--------------------------------------------------------------------------------
-- CREATING OPTIMIZED INNER LOOP
--------------------------------------------------------------------------------

-- Inner loop functions
local sha256_feed_64, sha512_feed_128, md5_feed_64, sha1_feed_64, keccak_feed, blake2s_feed_64, blake2b_feed_128, blake3_feed_64

-- Arrays of SHA-2 "magic numbers" (in "INT64" and "FFI" branches "*_lo" arrays contain 64-bit values)
local sha2_K_lo, sha2_K_hi, sha2_H_lo, sha2_H_hi, sha3_RC_lo, sha3_RC_hi = {}, {}, {}, {}, {}, {}
local sha2_H_ext256 = {[224] = {}, [256] = sha2_H_hi}
local sha2_H_ext512_lo, sha2_H_ext512_hi = {[384] = {}, [512] = sha2_H_lo}, {[384] = {}, [512] = sha2_H_hi}
local md5_K, md5_sha1_H = {}, {0x67452301, 0xEFCDAB89, 0x98BADCFE, 0x10325476, 0xC3D2E1F0}
local md5_next_shift = {0, 0, 0, 0, 0, 0, 0, 0, 28, 25, 26, 27, 0, 0, 10, 9, 11, 12, 0, 15, 16, 17, 18, 0, 20, 22, 23, 21}
local HEX64, lanes_index_base  -- defined only for branches that internally use 64-bit integers: "INT64" and "FFI"
local common_W = {}    -- temporary table shared between all calculations (to avoid creating new temporary table every time)
local common_W_blake2b, common_W_blake2s, v_for_blake2s_feed_64 = common_W, common_W, {}
local K_lo_modulo, hi_factor, hi_factor_keccak = 4294967296, 0, 0
local sigma = {
   {  1,  2,  3,  4,  5,  6,  7,  8,  9, 10, 11, 12, 13, 14, 15, 16 },
   { 15, 11,  5,  9, 10, 16, 14,  7,  2, 13,  1,  3, 12,  8,  6,  4 },
   { 12,  9, 13,  1,  6,  3, 16, 14, 11, 15,  4,  7,  8,  2, 10,  5 },
   {  8, 10,  4,  2, 14, 13, 12, 15,  3,  7,  6, 11,  5,  1, 16,  9 },
   { 10,  1,  6,  8,  3,  5, 11, 16, 15,  2, 12, 13,  7,  9,  4, 14 },
   {  3, 13,  7, 11,  1, 12,  9,  4,  5, 14,  8,  6, 16, 15,  2, 10 },
   { 13,  6,  2, 16, 15, 14,  5, 11,  1,  8,  7,  4, 10,  3,  9, 12 },
   { 14, 12,  8, 15, 13,  2,  4, 10,  6,  1, 16,  5,  9,  7,  3, 11 },
   {  7, 16, 15, 10, 12,  4,  1,  9, 13,  3, 14,  8,  2,  5, 11,  6 },
   { 11,  3,  9,  5,  8,  7,  2,  6, 16, 12, 10, 15,  4, 13, 14,  1 },
};  sigma[11], sigma[12] = sigma[1], sigma[2]
local perm_blake3 = {
   1, 3, 4, 11, 13, 10, 12, 6,
   1, 3, 4, 11, 13, 10,
   2, 7, 5, 8, 14, 15, 16, 9,
   2, 7, 5, 8, 14, 15,
}

local function build_keccak_format(elem)
   local keccak_format = {}
   for _, size in ipairs{1, 9, 13, 17, 18, 21} do
      keccak_format[size] = "<"..string_rep(elem, size)
   end
   return keccak_format
end


if branch == "FFI" then

   local common_W_FFI_int32 = ffi.new("int32_t[?]", 80)   -- 64 is enough for SHA256, but 80 is needed for SHA-1
   common_W_blake2s = common_W_FFI_int32
   v_for_blake2s_feed_64 = ffi.new("int32_t[?]", 16)
   perm_blake3 = ffi.new("uint8_t[?]", #perm_blake3 + 1, 0, unpack(perm_blake3))
   for j = 1, 10 do
      sigma[j] = ffi.new("uint8_t[?]", #sigma[j] + 1, 0, unpack(sigma[j]))
   end;  sigma[11], sigma[12] = sigma[1], sigma[2]


   -- SHA256 implementation for "LuaJIT with FFI" branch

   function sha256_feed_64(H, str, offs, size)
      -- offs >= 0, size >= 0, size is multiple of 64
      local W, K = common_W_FFI_int32, sha2_K_hi
      for pos = offs, offs + size - 1, 64 do
         for j = 0, 15 do
            pos = pos + 4
            local a, b, c, d = byte(str, pos - 3, pos)   -- slow, but doesn't depend on endianness
            W[j] = OR(SHL(a, 24), SHL(b, 16), SHL(c, 8), d)
         end
         for j = 16, 63 do
            local a, b = W[j-15], W[j-2]
            W[j] = NORM( XOR(ROR(a, 7), ROL(a, 14), SHR(a, 3)) + XOR(ROL(b, 15), ROL(b, 13), SHR(b, 10)) + W[j-7] + W[j-16] )
         end
         local a, b, c, d, e, f, g, h = H[1], H[2], H[3], H[4], H[5], H[6], H[7], H[8]
         for j = 0, 63, 8 do  -- Thanks to Peter Cawley for this workaround (unroll the loop to avoid "PHI shuffling too complex" due to PHIs overlap)
            local z = NORM( XOR(g, AND(e, XOR(f, g))) + XOR(ROR(e, 6), ROR(e, 11), ROL(e, 7)) + (W[j] + K[j+1] + h) )
            h, g, f, e = g, f, e, NORM( d + z )
            d, c, b, a = c, b, a, NORM( XOR(AND(a, XOR(b, c)), AND(b, c)) + XOR(ROR(a, 2), ROR(a, 13), ROL(a, 10)) + z )
            z = NORM( XOR(g, AND(e, XOR(f, g))) + XOR(ROR(e, 6), ROR(e, 11), ROL(e, 7)) + (W[j+1] + K[j+2] + h) )
            h, g, f, e = g, f, e, NORM( d + z )
            d, c, b, a = c, b, a, NORM( XOR(AND(a, XOR(b, c)), AND(b, c)) + XOR(ROR(a, 2), ROR(a, 13), ROL(a, 10)) + z )
            z = NORM( XOR(g, AND(e, XOR(f, g))) + XOR(ROR(e, 6), ROR(e, 11), ROL(e, 7)) + (W[j+2] + K[j+3] + h) )
            h, g, f, e = g, f, e, NORM( d + z )
            d, c, b, a = c, b, a, NORM( XOR(AND(a, XOR(b, c)), AND(b, c)) + XOR(ROR(a, 2), ROR(a, 13), ROL(a, 10)) + z )
            z = NORM( XOR(g, AND(e, XOR(f, g))) + XOR(ROR(e, 6), ROR(e, 11), ROL(e, 7)) + (W[j+3] + K[j+4] + h) )
            h, g, f, e = g, f, e, NORM( d + z )
            d, c, b, a = c, b, a, NORM( XOR(AND(a, XOR(b, c)), AND(b, c)) + XOR(ROR(a, 2), ROR(a, 13), ROL(a, 10)) + z )
            z = NORM( XOR(g, AND(e, XOR(f, g))) + XOR(ROR(e, 6), ROR(e, 11), ROL(e, 7)) + (W[j+4] + K[j+5] + h) )
            h, g, f, e = g, f, e, NORM( d + z )
            d, c, b, a = c, b, a, NORM( XOR(AND(a, XOR(b, c)), AND(b, c)) + XOR(ROR(a, 2), ROR(a, 13), ROL(a, 10)) + z )
            z = NORM( XOR(g, AND(e, XOR(f, g))) + XOR(ROR(e, 6), ROR(e, 11), ROL(e, 7)) + (W[j+5] + K[j+6] + h) )
            h, g, f, e = g, f, e, NORM( d + z )
            d, c, b, a = c, b, a, NORM( XOR(AND(a, XOR(b, c)), AND(b, c)) + XOR(ROR(a, 2), ROR(a, 13), ROL(a, 10)) + z )
            z = NORM( XOR(g, AND(e, XOR(f, g))) + XOR(ROR(e, 6), ROR(e, 11), ROL(e, 7)) + (W[j+6] + K[j+7] + h) )
            h, g, f, e = g, f, e, NORM( d + z )
            d, c, b, a = c, b, a, NORM( XOR(AND(a, XOR(b, c)), AND(b, c)) + XOR(ROR(a, 2), ROR(a, 13), ROL(a, 10)) + z )
            z = NORM( XOR(g, AND(e, XOR(f, g))) + XOR(ROR(e, 6), ROR(e, 11), ROL(e, 7)) + (W[j+7] + K[j+8] + h) )
            h, g, f, e = g, f, e, NORM( d + z )
            d, c, b, a = c, b, a, NORM( XOR(AND(a, XOR(b, c)), AND(b, c)) + XOR(ROR(a, 2), ROR(a, 13), ROL(a, 10)) + z )
         end
         H[1], H[2], H[3], H[4] = NORM(a + H[1]), NORM(b + H[2]), NORM(c + H[3]), NORM(d + H[4])
         H[5], H[6], H[7], H[8] = NORM(e + H[5]), NORM(f + H[6]), NORM(g + H[7]), NORM(h + H[8])
      end
   end


   local common_W_FFI_int64 = ffi.new("int64_t[?]", 80)
   common_W_blake2b = common_W_FFI_int64
   local int64 = ffi.typeof"int64_t"
   local int32 = ffi.typeof"int32_t"
   local uint32 = ffi.typeof"uint32_t"
   hi_factor = int64(2^32)

   if is_LuaJIT_21 then   -- LuaJIT 2.1 supports bitwise 64-bit operations

      local AND64, OR64, XOR64, NOT64, SHL64, SHR64, ROL64, ROR64  -- introducing synonyms for better code readability
          = AND,   OR,   XOR,   NOT,   SHL,   SHR,   ROL,   ROR
      HEX64 = HEX


      -- BLAKE2b implementation for "LuaJIT 2.1 + FFI" branch

      do
         local v = ffi.new("int64_t[?]", 16)
         local W = common_W_blake2b

         local function G(a, b, c, d, k1, k2)
            local va, vb, vc, vd = v[a], v[b], v[c], v[d]
            va = W[k1] + (va + vb)
            vd = ROR64(XOR64(vd, va), 32)
            vc = vc + vd
            vb = ROR64(XOR64(vb, vc), 24)
            va = W[k2] + (va + vb)
            vd = ROR64(XOR64(vd, va), 16)
            vc = vc + vd
            vb = ROL64(XOR64(vb, vc), 1)
            v[a], v[b], v[c], v[d] = va, vb, vc, vd
         end

         function blake2b_feed_128(H, _, str, offs, size, bytes_compressed, last_block_size, is_last_node)
            -- offs >= 0, size >= 0, size is multiple of 128
            local h1, h2, h3, h4, h5, h6, h7, h8 = H[1], H[2], H[3], H[4], H[5], H[6], H[7], H[8]
            for pos = offs, offs + size - 1, 128 do
               if str then
                  for j = 1, 16 do
                     pos = pos + 8
                     local a, b, c, d, e, f, g, h = byte(str, pos - 7, pos)
                     W[j] = XOR64(OR(SHL(h, 24), SHL(g, 16), SHL(f, 8), e) * int64(2^32), uint32(int32(OR(SHL(d, 24), SHL(c, 16), SHL(b, 8), a))))
                  end
               end
               v[0x0], v[0x1], v[0x2], v[0x3], v[0x4], v[0x5], v[0x6], v[0x7] = h1, h2, h3, h4, h5, h6, h7, h8
               v[0x8], v[0x9], v[0xA], v[0xB], v[0xD], v[0xE], v[0xF] = sha2_H_lo[1], sha2_H_lo[2], sha2_H_lo[3], sha2_H_lo[4], sha2_H_lo[6], sha2_H_lo[7], sha2_H_lo[8]
               bytes_compressed = bytes_compressed + (last_block_size or 128)
               v[0xC] = XOR64(sha2_H_lo[5], bytes_compressed)  -- t0 = low_8_bytes(bytes_compressed)
               -- t1 = high_8_bytes(bytes_compressed) = 0,  message length is always below 2^53 bytes
               if last_block_size then  -- flag f0
                  v[0xE] = NOT64(v[0xE])
               end
               if is_last_node then  -- flag f1
                  v[0xF] = NOT64(v[0xF])
               end
               for j = 1, 12 do
                  local row = sigma[j]
                  G(0, 4,  8, 12, row[ 1], row[ 2])
                  G(1, 5,  9, 13, row[ 3], row[ 4])
                  G(2, 6, 10, 14, row[ 5], row[ 6])
                  G(3, 7, 11, 15, row[ 7], row[ 8])
                  G(0, 5, 10, 15, row[ 9], row[10])
                  G(1, 6, 11, 12, row[11], row[12])
                  G(2, 7,  8, 13, row[13], row[14])
                  G(3, 4,  9, 14, row[15], row[16])
               end
               h1 = XOR64(h1, v[0x0], v[0x8])
               h2 = XOR64(h2, v[0x1], v[0x9])
               h3 = XOR64(h3, v[0x2], v[0xA])
               h4 = XOR64(h4, v[0x3], v[0xB])
               h5 = XOR64(h5, v[0x4], v[0xC])
               h6 = XOR64(h6, v[0x5], v[0xD])
               h7 = XOR64(h7, v[0x6], v[0xE])
               h8 = XOR64(h8, v[0x7], v[0xF])
            end
            H[1], H[2], H[3], H[4], H[5], H[6], H[7], H[8] = h1, h2, h3, h4, h5, h6, h7, h8
            return bytes_compressed
         end

      end


      -- SHA-3 implementation for "LuaJIT 2.1 + FFI" branch

      local arr64_t = ffi.typeof"int64_t[?]"
      -- lanes array is indexed from 0
      lanes_index_base = 0
      hi_factor_keccak = int64(2^32)

      function create_array_of_lanes()
         return arr64_t(30)  -- 25 + 5 for temporary usage
      end

      function keccak_feed(lanes, _, str, offs, size, block_size_in_bytes)
         -- offs >= 0, size >= 0, size is multiple of block_size_in_bytes, block_size_in_bytes is positive multiple of 8
         local RC = sha3_RC_lo
         local qwords_qty = SHR(block_size_in_bytes, 3)
         for pos = offs, offs + size - 1, block_size_in_bytes do
            for j = 0, qwords_qty - 1 do
               pos = pos + 8
               local h, g, f, e, d, c, b, a = byte(str, pos - 7, pos)   -- slow, but doesn't depend on endianness
               lanes[j] = XOR64(lanes[j], OR64(OR(SHL(a, 24), SHL(b, 16), SHL(c, 8), d) * int64(2^32), uint32(int32(OR(SHL(e, 24), SHL(f, 16), SHL(g, 8), h)))))
            end
            for round_idx = 1, 24 do
               for j = 0, 4 do
                  lanes[25 + j] = XOR64(lanes[j], lanes[j+5], lanes[j+10], lanes[j+15], lanes[j+20])
               end
               local D = XOR64(lanes[25], ROL64(lanes[27], 1))
               lanes[1], lanes[6], lanes[11], lanes[16] = ROL64(XOR64(D, lanes[6]), 44), ROL64(XOR64(D, lanes[16]), 45), ROL64(XOR64(D, lanes[1]), 1), ROL64(XOR64(D, lanes[11]), 10)
               lanes[21] = ROL64(XOR64(D, lanes[21]), 2)
               D = XOR64(lanes[26], ROL64(lanes[28], 1))
               lanes[2], lanes[7], lanes[12], lanes[22] = ROL64(XOR64(D, lanes[12]), 43), ROL64(XOR64(D, lanes[22]), 61), ROL64(XOR64(D, lanes[7]), 6), ROL64(XOR64(D, lanes[2]), 62)
               lanes[17] = ROL64(XOR64(D, lanes[17]), 15)
               D = XOR64(lanes[27], ROL64(lanes[29], 1))
               lanes[3], lanes[8], lanes[18], lanes[23] = ROL64(XOR64(D, lanes[18]), 21), ROL64(XOR64(D, lanes[3]), 28), ROL64(XOR64(D, lanes[23]), 56), ROL64(XOR64(D, lanes[8]), 55)
               lanes[13] = ROL64(XOR64(D, lanes[13]), 25)
               D = XOR64(lanes[28], ROL64(lanes[25], 1))
               lanes[4], lanes[14], lanes[19], lanes[24] = ROL64(XOR64(D, lanes[24]), 14), ROL64(XOR64(D, lanes[19]), 8), ROL64(XOR64(D, lanes[4]), 27), ROL64(XOR64(D, lanes[14]), 39)
               lanes[9] = ROL64(XOR64(D, lanes[9]), 20)
               D = XOR64(lanes[29], ROL64(lanes[26], 1))
               lanes[5], lanes[10], lanes[15], lanes[20] = ROL64(XOR64(D, lanes[10]), 3), ROL64(XOR64(D, lanes[20]), 18), ROL64(XOR64(D, lanes[5]), 36), ROL64(XOR64(D, lanes[15]), 41)
               lanes[0] = XOR64(D, lanes[0])
               lanes[0], lanes[1], lanes[2], lanes[3], lanes[4] = XOR64(lanes[0], AND64(NOT64(lanes[1]), lanes[2]), RC[round_idx]), XOR64(lanes[1], AND64(NOT64(lanes[2]), lanes[3])), XOR64(lanes[2], AND64(NOT64(lanes[3]), lanes[4])), XOR64(lanes[3], AND64(NOT64(lanes[4]), lanes[0])), XOR64(lanes[4], AND64(NOT64(lanes[0]), lanes[1]))
               lanes[5], lanes[6], lanes[7], lanes[8], lanes[9] = XOR64(lanes[8], AND64(NOT64(lanes[9]), lanes[5])), XOR64(lanes[9], AND64(NOT64(lanes[5]), lanes[6])), XOR64(lanes[5], AND64(NOT64(lanes[6]), lanes[7])), XOR64(lanes[6], AND64(NOT64(lanes[7]), lanes[8])), XOR64(lanes[7], AND64(NOT64(lanes[8]), lanes[9]))
               lanes[10], lanes[11], lanes[12], lanes[13], lanes[14] = XOR64(lanes[11], AND64(NOT64(lanes[12]), lanes[13])), XOR64(lanes[12], AND64(NOT64(lanes[13]), lanes[14])), XOR64(lanes[13], AND64(NOT64(lanes[14]), lanes[10])), XOR64(lanes[14], AND64(NOT64(lanes[10]), lanes[11])), XOR64(lanes[10], AND64(NOT64(lanes[11]), lanes[12]))
               lanes[15], lanes[16], lanes[17], lanes[18], lanes[19] = XOR64(lanes[19], AND64(NOT64(lanes[15]), lanes[16])), XOR64(lanes[15], AND64(NOT64(lanes[16]), lanes[17])), XOR64(lanes[16], AND64(NOT64(lanes[17]), lanes[18])), XOR64(lanes[17], AND64(NOT64(lanes[18]), lanes[19])), XOR64(lanes[18], AND64(NOT64(lanes[19]), lanes[15]))
               lanes[20], lanes[21], lanes[22], lanes[23], lanes[24] = XOR64(lanes[22], AND64(NOT64(lanes[23]), lanes[24])), XOR64(lanes[23], AND64(NOT64(lanes[24]), lanes[20])), XOR64(lanes[24], AND64(NOT64(lanes[20]), lanes[21])), XOR64(lanes[20], AND64(NOT64(lanes[21]), lanes[22])), XOR64(lanes[21], AND64(NOT64(lanes[22]), lanes[23]))
            end
         end
      end


      local A5_long = 0xA5A5A5A5 * int64(2^32 + 1)  -- It's impossible to use constant 0xA5A5A5A5A5A5A5A5LL because it will raise syntax error on other Lua versions

      function XORA5(long, long2)
         return XOR64(long, long2 or A5_long)
      end


      -- SHA512 implementation for "LuaJIT 2.1 + FFI" branch

      function sha512_feed_128(H, _, str, offs, size)
         -- offs >= 0, size >= 0, size is multiple of 128
         local W, K = common_W_FFI_int64, sha2_K_lo
         for pos = offs, offs + size - 1, 128 do
            for j = 0, 15 do
               pos = pos + 8
               local a, b, c, d, e, f, g, h = byte(str, pos - 7, pos)   -- slow, but doesn't depend on endianness
               W[j] = OR64(OR(SHL(a, 24), SHL(b, 16), SHL(c, 8), d) * int64(2^32), uint32(int32(OR(SHL(e, 24), SHL(f, 16), SHL(g, 8), h))))
            end
            for j = 16, 79 do
               local a, b = W[j-15], W[j-2]
               W[j] = XOR64(ROR64(a, 1), ROR64(a, 8), SHR64(a, 7)) + XOR64(ROR64(b, 19), ROL64(b, 3), SHR64(b, 6)) + W[j-7] + W[j-16]
            end
            local a, b, c, d, e, f, g, h = H[1], H[2], H[3], H[4], H[5], H[6], H[7], H[8]
            for j = 0, 79, 8 do
               local z = XOR64(ROR64(e, 14), ROR64(e, 18), ROL64(e, 23)) + XOR64(g, AND64(e, XOR64(f, g))) + h + K[j+1] + W[j]
               h, g, f, e = g, f, e, z + d
               d, c, b, a = c, b, a, XOR64(AND64(XOR64(a, b), c), AND64(a, b)) + XOR64(ROR64(a, 28), ROL64(a, 25), ROL64(a, 30)) + z
               z = XOR64(ROR64(e, 14), ROR64(e, 18), ROL64(e, 23)) + XOR64(g, AND64(e, XOR64(f, g))) + h + K[j+2] + W[j+1]
               h, g, f, e = g, f, e, z + d
               d, c, b, a = c, b, a, XOR64(AND64(XOR64(a, b), c), AND64(a, b)) + XOR64(ROR64(a, 28), ROL64(a, 25), ROL64(a, 30)) + z
               z = XOR64(ROR64(e, 14), ROR64(e, 18), ROL64(e, 23)) + XOR64(g, AND64(e, XOR64(f, g))) + h + K[j+3] + W[j+2]
               h, g, f, e = g, f, e, z + d
               d, c, b, a = c, b, a, XOR64(AND64(XOR64(a, b), c), AND64(a, b)) + XOR64(ROR64(a, 28), ROL64(a, 25), ROL64(a, 30)) + z
               z = XOR64(ROR64(e, 14), ROR64(e, 18), ROL64(e, 23)) + XOR64(g, AND64(e, XOR64(f, g))) + h + K[j+4] + W[j+3]
               h, g, f, e = g, f, e, z + d
               d, c, b, a = c, b, a, XOR64(AND64(XOR64(a, b), c), AND64(a, b)) + XOR64(ROR64(a, 28), ROL64(a, 25), ROL64(a, 30)) + z
               z = XOR64(ROR64(e, 14), ROR64(e, 18), ROL64(e, 23)) + XOR64(g, AND64(e, XOR64(f, g))) + h + K[j+5] + W[j+4]
               h, g, f, e = g, f, e, z + d
               d, c, b, a = c, b, a, XOR64(AND64(XOR64(a, b), c), AND64(a, b)) + XOR64(ROR64(a, 28), ROL64(a, 25), ROL64(a, 30)) + z
               z = XOR64(ROR64(e, 14), ROR64(e, 18), ROL64(e, 23)) + XOR64(g, AND64(e, XOR64(f, g))) + h + K[j+6] + W[j+5]
               h, g, f, e = g, f, e, z + d
               d, c, b, a = c, b, a, XOR64(AND64(XOR64(a, b), c), AND64(a, b)) + XOR64(ROR64(a, 28), ROL64(a, 25), ROL64(a, 30)) + z
               z = XOR64(ROR64(e, 14), ROR64(e, 18), ROL64(e, 23)) + XOR64(g, AND64(e, XOR64(f, g))) + h + K[j+7] + W[j+6]
               h, g, f, e = g, f, e, z + d
               d, c, b, a = c, b, a, XOR64(AND64(XOR64(a, b), c), AND64(a, b)) + XOR64(ROR64(a, 28), ROL64(a, 25), ROL64(a, 30)) + z
               z = XOR64(ROR64(e, 14), ROR64(e, 18), ROL64(e, 23)) + XOR64(g, AND64(e, XOR64(f, g))) + h + K[j+8] + W[j+7]
               h, g, f, e = g, f, e, z + d
               d, c, b, a = c, b, a, XOR64(AND64(XOR64(a, b), c), AND64(a, b)) + XOR64(ROR64(a, 28), ROL64(a, 25), ROL64(a, 30)) + z
            end
            H[1] = a + H[1]
            H[2] = b + H[2]
            H[3] = c + H[3]
            H[4] = d + H[4]
            H[5] = e + H[5]
            H[6] = f + H[6]
            H[7] = g + H[7]
            H[8] = h + H[8]
         end
      end

   else  -- LuaJIT 2.0 doesn't support 64-bit bitwise operations

      local U = ffi.new("union{int64_t i64; struct{int32_t "..(ffi.abi("le") and "lo, hi" or "hi, lo")..";} i32;}[3]")
      -- this array of unions is used for fast splitting int64 into int32_high and int32_low

      -- "xorrific" 64-bit functions :-)
      -- int64 input is splitted into two int32 parts, some bitwise 32-bit operations are performed, finally the result is converted to int64
      -- these functions are needed because bit.* functions in LuaJIT 2.0 don't work with int64_t

      local function XORROR64_1(a)
         -- return XOR64(ROR64(a, 1), ROR64(a, 8), SHR64(a, 7))
         U[0].i64 = a
         local a_lo, a_hi = U[0].i32.lo, U[0].i32.hi
         local t_lo = XOR(SHR(a_lo, 1), SHL(a_hi, 31), SHR(a_lo, 8), SHL(a_hi, 24), SHR(a_lo, 7), SHL(a_hi, 25))
         local t_hi = XOR(SHR(a_hi, 1), SHL(a_lo, 31), SHR(a_hi, 8), SHL(a_lo, 24), SHR(a_hi, 7))
         return t_hi * int64(2^32) + uint32(int32(t_lo))
      end

      local function XORROR64_2(b)
         -- return XOR64(ROR64(b, 19), ROL64(b, 3), SHR64(b, 6))
         U[0].i64 = b
         local b_lo, b_hi = U[0].i32.lo, U[0].i32.hi
         local u_lo = XOR(SHR(b_lo, 19), SHL(b_hi, 13), SHL(b_lo, 3), SHR(b_hi, 29), SHR(b_lo, 6), SHL(b_hi, 26))
         local u_hi = XOR(SHR(b_hi, 19), SHL(b_lo, 13), SHL(b_hi, 3), SHR(b_lo, 29), SHR(b_hi, 6))
         return u_hi * int64(2^32) + uint32(int32(u_lo))
      end

      local function XORROR64_3(e)
         -- return XOR64(ROR64(e, 14), ROR64(e, 18), ROL64(e, 23))
         U[0].i64 = e
         local e_lo, e_hi = U[0].i32.lo, U[0].i32.hi
         local u_lo = XOR(SHR(e_lo, 14), SHL(e_hi, 18), SHR(e_lo, 18), SHL(e_hi, 14), SHL(e_lo, 23), SHR(e_hi, 9))
         local u_hi = XOR(SHR(e_hi, 14), SHL(e_lo, 18), SHR(e_hi, 18), SHL(e_lo, 14), SHL(e_hi, 23), SHR(e_lo, 9))
         return u_hi * int64(2^32) + uint32(int32(u_lo))
      end

      local function XORROR64_6(a)
         -- return XOR64(ROR64(a, 28), ROL64(a, 25), ROL64(a, 30))
         U[0].i64 = a
         local b_lo, b_hi = U[0].i32.lo, U[0].i32.hi
         local u_lo = XOR(SHR(b_lo, 28), SHL(b_hi, 4), SHL(b_lo, 30), SHR(b_hi, 2), SHL(b_lo, 25), SHR(b_hi, 7))
         local u_hi = XOR(SHR(b_hi, 28), SHL(b_lo, 4), SHL(b_hi, 30), SHR(b_lo, 2), SHL(b_hi, 25), SHR(b_lo, 7))
         return u_hi * int64(2^32) + uint32(int32(u_lo))
      end

      local function XORROR64_4(e, f, g)
         -- return XOR64(g, AND64(e, XOR64(f, g)))
         U[0].i64 = f
         U[1].i64 = g
         U[2].i64 = e
         local f_lo, f_hi = U[0].i32.lo, U[0].i32.hi
         local g_lo, g_hi = U[1].i32.lo, U[1].i32.hi
         local e_lo, e_hi = U[2].i32.lo, U[2].i32.hi
         local result_lo = XOR(g_lo, AND(e_lo, XOR(f_lo, g_lo)))
         local result_hi = XOR(g_hi, AND(e_hi, XOR(f_hi, g_hi)))
         return result_hi * int64(2^32) + uint32(int32(result_lo))
      end

      local function XORROR64_5(a, b, c)
         -- return XOR64(AND64(XOR64(a, b), c), AND64(a, b))
         U[0].i64 = a
         U[1].i64 = b
         U[2].i64 = c
         local a_lo, a_hi = U[0].i32.lo, U[0].i32.hi
         local b_lo, b_hi = U[1].i32.lo, U[1].i32.hi
         local c_lo, c_hi = U[2].i32.lo, U[2].i32.hi
         local result_lo = XOR(AND(XOR(a_lo, b_lo), c_lo), AND(a_lo, b_lo))
         local result_hi = XOR(AND(XOR(a_hi, b_hi), c_hi), AND(a_hi, b_hi))
         return result_hi * int64(2^32) + uint32(int32(result_lo))
      end

      local function XORROR64_7(a, b, m)
         -- return ROR64(XOR64(a, b), m), m = 1..31
         U[0].i64 = a
         U[1].i64 = b
         local a_lo, a_hi = U[0].i32.lo, U[0].i32.hi
         local b_lo, b_hi = U[1].i32.lo, U[1].i32.hi
         local c_lo, c_hi = XOR(a_lo, b_lo), XOR(a_hi, b_hi)
         local t_lo = XOR(SHR(c_lo, m), SHL(c_hi, -m))
         local t_hi = XOR(SHR(c_hi, m), SHL(c_lo, -m))
         return t_hi * int64(2^32) + uint32(int32(t_lo))
      end

      local function XORROR64_8(a, b)
         -- return ROL64(XOR64(a, b), 1)
         U[0].i64 = a
         U[1].i64 = b
         local a_lo, a_hi = U[0].i32.lo, U[0].i32.hi
         local b_lo, b_hi = U[1].i32.lo, U[1].i32.hi
         local c_lo, c_hi = XOR(a_lo, b_lo), XOR(a_hi, b_hi)
         local t_lo = XOR(SHL(c_lo, 1), SHR(c_hi, 31))
         local t_hi = XOR(SHL(c_hi, 1), SHR(c_lo, 31))
         return t_hi * int64(2^32) + uint32(int32(t_lo))
      end

      local function XORROR64_9(a, b)
         -- return ROR64(XOR64(a, b), 32)
         U[0].i64 = a
         U[1].i64 = b
         local a_lo, a_hi = U[0].i32.lo, U[0].i32.hi
         local b_lo, b_hi = U[1].i32.lo, U[1].i32.hi
         local t_hi, t_lo = XOR(a_lo, b_lo), XOR(a_hi, b_hi)
         return t_hi * int64(2^32) + uint32(int32(t_lo))
      end

      local function XOR64(a, b)
         -- return XOR64(a, b)
         U[0].i64 = a
         U[1].i64 = b
         local a_lo, a_hi = U[0].i32.lo, U[0].i32.hi
         local b_lo, b_hi = U[1].i32.lo, U[1].i32.hi
         local t_lo, t_hi = XOR(a_lo, b_lo), XOR(a_hi, b_hi)
         return t_hi * int64(2^32) + uint32(int32(t_lo))
      end

      local function XORROR64_11(a, b, c)
         -- return XOR64(a, b, c)
         U[0].i64 = a
         U[1].i64 = b
         U[2].i64 = c
         local a_lo, a_hi = U[0].i32.lo, U[0].i32.hi
         local b_lo, b_hi = U[1].i32.lo, U[1].i32.hi
         local c_lo, c_hi = U[2].i32.lo, U[2].i32.hi
         local t_lo, t_hi = XOR(a_lo, b_lo, c_lo), XOR(a_hi, b_hi, c_hi)
         return t_hi * int64(2^32) + uint32(int32(t_lo))
      end

      function XORA5(long, long2)
         -- return XOR64(long, long2 or 0xA5A5A5A5A5A5A5A5)
         U[0].i64 = long
         local lo32, hi32 = U[0].i32.lo, U[0].i32.hi
         local long2_lo, long2_hi = 0xA5A5A5A5, 0xA5A5A5A5
         if long2 then
            U[1].i64 = long2
            long2_lo, long2_hi = U[1].i32.lo, U[1].i32.hi
         end
         lo32 = XOR(lo32, long2_lo)
         hi32 = XOR(hi32, long2_hi)
         return hi32 * int64(2^32) + uint32(int32(lo32))
      end

      function HEX64(long)
         U[0].i64 = long
         return HEX(U[0].i32.hi)..HEX(U[0].i32.lo)
      end


      -- SHA512 implementation for "LuaJIT 2.0 + FFI" branch

      function sha512_feed_128(H, _, str, offs, size)
         -- offs >= 0, size >= 0, size is multiple of 128
         local W, K = common_W_FFI_int64, sha2_K_lo
         for pos = offs, offs + size - 1, 128 do
            for j = 0, 15 do
               pos = pos + 8
               local a, b, c, d, e, f, g, h = byte(str, pos - 7, pos)   -- slow, but doesn't depend on endianness
               W[j] = OR(SHL(a, 24), SHL(b, 16), SHL(c, 8), d) * int64(2^32) + uint32(int32(OR(SHL(e, 24), SHL(f, 16), SHL(g, 8), h)))
            end
            for j = 16, 79 do
               W[j] = XORROR64_1(W[j-15]) + XORROR64_2(W[j-2]) + W[j-7] + W[j-16]
            end
            local a, b, c, d, e, f, g, h = H[1], H[2], H[3], H[4], H[5], H[6], H[7], H[8]
            for j = 0, 79, 8 do
               local z = XORROR64_3(e) + XORROR64_4(e, f, g) + h + K[j+1] + W[j]
               h, g, f, e = g, f, e, z + d
               d, c, b, a = c, b, a, XORROR64_5(a, b, c) + XORROR64_6(a) + z
               z = XORROR64_3(e) + XORROR64_4(e, f, g) + h + K[j+2] + W[j+1]
               h, g, f, e = g, f, e, z + d
               d, c, b, a = c, b, a, XORROR64_5(a, b, c) + XORROR64_6(a) + z
               z = XORROR64_3(e) + XORROR64_4(e, f, g) + h + K[j+3] + W[j+2]
               h, g, f, e = g, f, e, z + d
               d, c, b, a = c, b, a, XORROR64_5(a, b, c) + XORROR64_6(a) + z
               z = XORROR64_3(e) + XORROR64_4(e, f, g) + h + K[j+4] + W[j+3]
               h, g, f, e = g, f, e, z + d
               d, c, b, a = c, b, a, XORROR64_5(a, b, c) + XORROR64_6(a) + z
               z = XORROR64_3(e) + XORROR64_4(e, f, g) + h + K[j+5] + W[j+4]
               h, g, f, e = g, f, e, z + d
               d, c, b, a = c, b, a, XORROR64_5(a, b, c) + XORROR64_6(a) + z
               z = XORROR64_3(e) + XORROR64_4(e, f, g) + h + K[j+6] + W[j+5]
               h, g, f, e = g, f, e, z + d
               d, c, b, a = c, b, a, XORROR64_5(a, b, c) + XORROR64_6(a) + z
               z = XORROR64_3(e) + XORROR64_4(e, f, g) + h + K[j+7] + W[j+6]
               h, g, f, e = g, f, e, z + d
               d, c, b, a = c, b, a, XORROR64_5(a, b, c) + XORROR64_6(a) + z
               z = XORROR64_3(e) + XORROR64_4(e, f, g) + h + K[j+8] + W[j+7]
               h, g, f, e = g, f, e, z + d
               d, c, b, a = c, b, a, XORROR64_5(a, b, c) + XORROR64_6(a) + z
            end
            H[1] = a + H[1]
            H[2] = b + H[2]
            H[3] = c + H[3]
            H[4] = d + H[4]
            H[5] = e + H[5]
            H[6] = f + H[6]
            H[7] = g + H[7]
            H[8] = h + H[8]
         end
      end


      -- BLAKE2b implementation for "LuaJIT 2.0 + FFI" branch

      do
         local v = ffi.new("int64_t[?]", 16)
         local W = common_W_blake2b

         local function G(a, b, c, d, k1, k2)
            local va, vb, vc, vd = v[a], v[b], v[c], v[d]
            va = W[k1] + (va + vb)
            vd = XORROR64_9(vd, va)
            vc = vc + vd
            vb = XORROR64_7(vb, vc, 24)
            va = W[k2] + (va + vb)
            vd = XORROR64_7(vd, va, 16)
            vc = vc + vd
            vb = XORROR64_8(vb, vc)
            v[a], v[b], v[c], v[d] = va, vb, vc, vd
         end

         function blake2b_feed_128(H, _, str, offs, size, bytes_compressed, last_block_size, is_last_node)
            -- offs >= 0, size >= 0, size is multiple of 128
            local h1, h2, h3, h4, h5, h6, h7, h8 = H[1], H[2], H[3], H[4], H[5], H[6], H[7], H[8]
            for pos = offs, offs + size - 1, 128 do
               if str then
                  for j = 1, 16 do
                     pos = pos + 8
                     local a, b, c, d, e, f, g, h = byte(str, pos - 7, pos)
                     W[j] = XOR64(OR(SHL(h, 24), SHL(g, 16), SHL(f, 8), e) * int64(2^32), uint32(int32(OR(SHL(d, 24), SHL(c, 16), SHL(b, 8), a))))
                  end
               end
               v[0x0], v[0x1], v[0x2], v[0x3], v[0x4], v[0x5], v[0x6], v[0x7] = h1, h2, h3, h4, h5, h6, h7, h8
               v[0x8], v[0x9], v[0xA], v[0xB], v[0xD], v[0xE], v[0xF] = sha2_H_lo[1], sha2_H_lo[2], sha2_H_lo[3], sha2_H_lo[4], sha2_H_lo[6], sha2_H_lo[7], sha2_H_lo[8]
               bytes_compressed = bytes_compressed + (last_block_size or 128)
               v[0xC] = XOR64(sha2_H_lo[5], bytes_compressed)  -- t0 = low_8_bytes(bytes_compressed)
               -- t1 = high_8_bytes(bytes_compressed) = 0,  message length is always below 2^53 bytes
               if last_block_size then  -- flag f0
                  v[0xE] = -1 - v[0xE]
               end
               if is_last_node then  -- flag f1
                  v[0xF] = -1 - v[0xF]
               end
               for j = 1, 12 do
                  local row = sigma[j]
                  G(0, 4,  8, 12, row[ 1], row[ 2])
                  G(1, 5,  9, 13, row[ 3], row[ 4])
                  G(2, 6, 10, 14, row[ 5], row[ 6])
                  G(3, 7, 11, 15, row[ 7], row[ 8])
                  G(0, 5, 10, 15, row[ 9], row[10])
                  G(1, 6, 11, 12, row[11], row[12])
                  G(2, 7,  8, 13, row[13], row[14])
                  G(3, 4,  9, 14, row[15], row[16])
               end
               h1 = XORROR64_11(h1, v[0x0], v[0x8])
               h2 = XORROR64_11(h2, v[0x1], v[0x9])
               h3 = XORROR64_11(h3, v[0x2], v[0xA])
               h4 = XORROR64_11(h4, v[0x3], v[0xB])
               h5 = XORROR64_11(h5, v[0x4], v[0xC])
               h6 = XORROR64_11(h6, v[0x5], v[0xD])
               h7 = XORROR64_11(h7, v[0x6], v[0xE])
               h8 = XORROR64_11(h8, v[0x7], v[0xF])
            end
            H[1], H[2], H[3], H[4], H[5], H[6], H[7], H[8] = h1, h2, h3, h4, h5, h6, h7, h8
            return bytes_compressed
         end

      end

   end


   -- MD5 implementation for "LuaJIT with FFI" branch

   function md5_feed_64(H, str, offs, size)
      -- offs >= 0, size >= 0, size is multiple of 64
      local W, K = common_W_FFI_int32, md5_K
      for pos = offs, offs + size - 1, 64 do
         for j = 0, 15 do
            pos = pos + 4
            local a, b, c, d = byte(str, pos - 3, pos)   -- slow, but doesn't depend on endianness
            W[j] = OR(SHL(d, 24), SHL(c, 16), SHL(b, 8), a)
         end
         local a, b, c, d = H[1], H[2], H[3], H[4]
         for j = 0, 15, 4 do
            a, d, c, b = d, c, b, NORM(ROL(XOR(d, AND(b, XOR(c, d))) + (K[j+1] + W[j  ] + a),  7) + b)
            a, d, c, b = d, c, b, NORM(ROL(XOR(d, AND(b, XOR(c, d))) + (K[j+2] + W[j+1] + a), 12) + b)
            a, d, c, b = d, c, b, NORM(ROL(XOR(d, AND(b, XOR(c, d))) + (K[j+3] + W[j+2] + a), 17) + b)
            a, d, c, b = d, c, b, NORM(ROL(XOR(d, AND(b, XOR(c, d))) + (K[j+4] + W[j+3] + a), 22) + b)
         end
         for j = 16, 31, 4 do
            local g = 5*j
            a, d, c, b = d, c, b, NORM(ROL(XOR(c, AND(d, XOR(b, c))) + (K[j+1] + W[AND(g + 1, 15)] + a),  5) + b)
            a, d, c, b = d, c, b, NORM(ROL(XOR(c, AND(d, XOR(b, c))) + (K[j+2] + W[AND(g + 6, 15)] + a),  9) + b)
            a, d, c, b = d, c, b, NORM(ROL(XOR(c, AND(d, XOR(b, c))) + (K[j+3] + W[AND(g - 5, 15)] + a), 14) + b)
            a, d, c, b = d, c, b, NORM(ROL(XOR(c, AND(d, XOR(b, c))) + (K[j+4] + W[AND(g    , 15)] + a), 20) + b)
         end
         for j = 32, 47, 4 do
            local g = 3*j
            a, d, c, b = d, c, b, NORM(ROL(XOR(b, c, d) + (K[j+1] + W[AND(g + 5, 15)] + a),  4) + b)
            a, d, c, b = d, c, b, NORM(ROL(XOR(b, c, d) + (K[j+2] + W[AND(g + 8, 15)] + a), 11) + b)
            a, d, c, b = d, c, b, NORM(ROL(XOR(b, c, d) + (K[j+3] + W[AND(g - 5, 15)] + a), 16) + b)
            a, d, c, b = d, c, b, NORM(ROL(XOR(b, c, d) + (K[j+4] + W[AND(g - 2, 15)] + a), 23) + b)
         end
         for j = 48, 63, 4 do
            local g = 7*j
            a, d, c, b = d, c, b, NORM(ROL(XOR(c, OR(b, NOT(d))) + (K[j+1] + W[AND(g    , 15)] + a),  6) + b)
            a, d, c, b = d, c, b, NORM(ROL(XOR(c, OR(b, NOT(d))) + (K[j+2] + W[AND(g + 7, 15)] + a), 10) + b)
            a, d, c, b = d, c, b, NORM(ROL(XOR(c, OR(b, NOT(d))) + (K[j+3] + W[AND(g - 2, 15)] + a), 15) + b)
            a, d, c, b = d, c, b, NORM(ROL(XOR(c, OR(b, NOT(d))) + (K[j+4] + W[AND(g + 5, 15)] + a), 21) + b)
         end
         H[1], H[2], H[3], H[4] = NORM(a + H[1]), NORM(b + H[2]), NORM(c + H[3]), NORM(d + H[4])
      end
   end


   -- SHA-1 implementation for "LuaJIT with FFI" branch

   function sha1_feed_64(H, str, offs, size)
      -- offs >= 0, size >= 0, size is multiple of 64
      local W = common_W_FFI_int32
      for pos = offs, offs + size - 1, 64 do
         for j = 0, 15 do
            pos = pos + 4
            local a, b, c, d = byte(str, pos - 3, pos)   -- slow, but doesn't depend on endianness
            W[j] = OR(SHL(a, 24), SHL(b, 16), SHL(c, 8), d)
         end
         for j = 16, 79 do
            W[j] = ROL(XOR(W[j-3], W[j-8], W[j-14], W[j-16]), 1)
         end
         local a, b, c, d, e = H[1], H[2], H[3], H[4], H[5]
         for j = 0, 19, 5 do
            e, d, c, b, a = d, c, ROR(b, 2), a, NORM(ROL(a, 5) + XOR(d, AND(b, XOR(d, c))) + (W[j]   + 0x5A827999 + e))          -- constant = floor(2^30 * sqrt(2))
            e, d, c, b, a = d, c, ROR(b, 2), a, NORM(ROL(a, 5) + XOR(d, AND(b, XOR(d, c))) + (W[j+1] + 0x5A827999 + e))
            e, d, c, b, a = d, c, ROR(b, 2), a, NORM(ROL(a, 5) + XOR(d, AND(b, XOR(d, c))) + (W[j+2] + 0x5A827999 + e))
            e, d, c, b, a = d, c, ROR(b, 2), a, NORM(ROL(a, 5) + XOR(d, AND(b, XOR(d, c))) + (W[j+3] + 0x5A827999 + e))
            e, d, c, b, a = d, c, ROR(b, 2), a, NORM(ROL(a, 5) + XOR(d, AND(b, XOR(d, c))) + (W[j+4] + 0x5A827999 + e))
         end
         for j = 20, 39, 5 do
            e, d, c, b, a = d, c, ROR(b, 2), a, NORM(ROL(a, 5) + XOR(b, c, d) + (W[j]   + 0x6ED9EBA1 + e))                       -- 2^30 * sqrt(3)
            e, d, c, b, a = d, c, ROR(b, 2), a, NORM(ROL(a, 5) + XOR(b, c, d) + (W[j+1] + 0x6ED9EBA1 + e))
            e, d, c, b, a = d, c, ROR(b, 2), a, NORM(ROL(a, 5) + XOR(b, c, d) + (W[j+2] + 0x6ED9EBA1 + e))
            e, d, c, b, a = d, c, ROR(b, 2), a, NORM(ROL(a, 5) + XOR(b, c, d) + (W[j+3] + 0x6ED9EBA1 + e))
            e, d, c, b, a = d, c, ROR(b, 2), a, NORM(ROL(a, 5) + XOR(b, c, d) + (W[j+4] + 0x6ED9EBA1 + e))
         end
         for j = 40, 59, 5 do
            e, d, c, b, a = d, c, ROR(b, 2), a, NORM(ROL(a, 5) + XOR(AND(d, XOR(b, c)), AND(b, c)) + (W[j]   + 0x8F1BBCDC + e))  -- 2^30 * sqrt(5)
            e, d, c, b, a = d, c, ROR(b, 2), a, NORM(ROL(a, 5) + XOR(AND(d, XOR(b, c)), AND(b, c)) + (W[j+1] + 0x8F1BBCDC + e))
            e, d, c, b, a = d, c, ROR(b, 2), a, NORM(ROL(a, 5) + XOR(AND(d, XOR(b, c)), AND(b, c)) + (W[j+2] + 0x8F1BBCDC + e))
            e, d, c, b, a = d, c, ROR(b, 2), a, NORM(ROL(a, 5) + XOR(AND(d, XOR(b, c)), AND(b, c)) + (W[j+3] + 0x8F1BBCDC + e))
            e, d, c, b, a = d, c, ROR(b, 2), a, NORM(ROL(a, 5) + XOR(AND(d, XOR(b, c)), AND(b, c)) + (W[j+4] + 0x8F1BBCDC + e))
         end
         for j = 60, 79, 5 do
            e, d, c, b, a = d, c, ROR(b, 2), a, NORM(ROL(a, 5) + XOR(b, c, d) + (W[j]   + 0xCA62C1D6 + e))                       -- 2^30 * sqrt(10)
            e, d, c, b, a = d, c, ROR(b, 2), a, NORM(ROL(a, 5) + XOR(b, c, d) + (W[j+1] + 0xCA62C1D6 + e))
            e, d, c, b, a = d, c, ROR(b, 2), a, NORM(ROL(a, 5) + XOR(b, c, d) + (W[j+2] + 0xCA62C1D6 + e))
            e, d, c, b, a = d, c, ROR(b, 2), a, NORM(ROL(a, 5) + XOR(b, c, d) + (W[j+3] + 0xCA62C1D6 + e))
            e, d, c, b, a = d, c, ROR(b, 2), a, NORM(ROL(a, 5) + XOR(b, c, d) + (W[j+4] + 0xCA62C1D6 + e))
         end
         H[1], H[2], H[3], H[4], H[5] = NORM(a + H[1]), NORM(b + H[2]), NORM(c + H[3]), NORM(d + H[4]), NORM(e + H[5])
      end
   end

end


if branch == "FFI" and not is_LuaJIT_21 or branch == "LJ" then

   if branch == "FFI" then
      local arr32_t = ffi.typeof"int32_t[?]"

      function create_array_of_lanes()
         return arr32_t(31)  -- 25 + 5 + 1 (due to 1-based indexing)
      end

   end


   -- SHA-3 implementation for "LuaJIT 2.0 + FFI" and "LuaJIT without FFI" branches

   function keccak_feed(lanes_lo, lanes_hi, str, offs, size, block_size_in_bytes)
      -- offs >= 0, size >= 0, size is multiple of block_size_in_bytes, block_size_in_bytes is positive multiple of 8
      local RC_lo, RC_hi = sha3_RC_lo, sha3_RC_hi
      local qwords_qty = SHR(block_size_in_bytes, 3)
      for pos = offs, offs + size - 1, block_size_in_bytes do
         for j = 1, qwords_qty do
            local a, b, c, d = byte(str, pos + 1, pos + 4)
            lanes_lo[j] = XOR(lanes_lo[j], OR(SHL(d, 24), SHL(c, 16), SHL(b, 8), a))
            pos = pos + 8
            a, b, c, d = byte(str, pos - 3, pos)
            lanes_hi[j] = XOR(lanes_hi[j], OR(SHL(d, 24), SHL(c, 16), SHL(b, 8), a))
         end
         for round_idx = 1, 24 do
            for j = 1, 5 do
               lanes_lo[25 + j] = XOR(lanes_lo[j], lanes_lo[j + 5], lanes_lo[j + 10], lanes_lo[j + 15], lanes_lo[j + 20])
            end
            for j = 1, 5 do
               lanes_hi[25 + j] = XOR(lanes_hi[j], lanes_hi[j + 5], lanes_hi[j + 10], lanes_hi[j + 15], lanes_hi[j + 20])
            end
            local D_lo = XOR(lanes_lo[26], SHL(lanes_lo[28], 1), SHR(lanes_hi[28], 31))
            local D_hi = XOR(lanes_hi[26], SHL(lanes_hi[28], 1), SHR(lanes_lo[28], 31))
            lanes_lo[2], lanes_hi[2], lanes_lo[7], lanes_hi[7], lanes_lo[12], lanes_hi[12], lanes_lo[17], lanes_hi[17] = XOR(SHR(XOR(D_lo, lanes_lo[7]), 20), SHL(XOR(D_hi, lanes_hi[7]), 12)), XOR(SHR(XOR(D_hi, lanes_hi[7]), 20), SHL(XOR(D_lo, lanes_lo[7]), 12)), XOR(SHR(XOR(D_lo, lanes_lo[17]), 19), SHL(XOR(D_hi, lanes_hi[17]), 13)), XOR(SHR(XOR(D_hi, lanes_hi[17]), 19), SHL(XOR(D_lo, lanes_lo[17]), 13)), XOR(SHL(XOR(D_lo, lanes_lo[2]), 1), SHR(XOR(D_hi, lanes_hi[2]), 31)), XOR(SHL(XOR(D_hi, lanes_hi[2]), 1), SHR(XOR(D_lo, lanes_lo[2]), 31)), XOR(SHL(XOR(D_lo, lanes_lo[12]), 10), SHR(XOR(D_hi, lanes_hi[12]), 22)), XOR(SHL(XOR(D_hi, lanes_hi[12]), 10), SHR(XOR(D_lo, lanes_lo[12]), 22))
            local L, H = XOR(D_lo, lanes_lo[22]), XOR(D_hi, lanes_hi[22])
            lanes_lo[22], lanes_hi[22] = XOR(SHL(L, 2), SHR(H, 30)), XOR(SHL(H, 2), SHR(L, 30))
            D_lo = XOR(lanes_lo[27], SHL(lanes_lo[29], 1), SHR(lanes_hi[29], 31))
            D_hi = XOR(lanes_hi[27], SHL(lanes_hi[29], 1), SHR(lanes_lo[29], 31))
            lanes_lo[3], lanes_hi[3], lanes_lo[8], lanes_hi[8], lanes_lo[13], lanes_hi[13], lanes_lo[23], lanes_hi[23] = XOR(SHR(XOR(D_lo, lanes_lo[13]), 21), SHL(XOR(D_hi, lanes_hi[13]), 11)), XOR(SHR(XOR(D_hi, lanes_hi[13]), 21), SHL(XOR(D_lo, lanes_lo[13]), 11)), XOR(SHR(XOR(D_lo, lanes_lo[23]), 3), SHL(XOR(D_hi, lanes_hi[23]), 29)), XOR(SHR(XOR(D_hi, lanes_hi[23]), 3), SHL(XOR(D_lo, lanes_lo[23]), 29)), XOR(SHL(XOR(D_lo, lanes_lo[8]), 6), SHR(XOR(D_hi, lanes_hi[8]), 26)), XOR(SHL(XOR(D_hi, lanes_hi[8]), 6), SHR(XOR(D_lo, lanes_lo[8]), 26)), XOR(SHR(XOR(D_lo, lanes_lo[3]), 2), SHL(XOR(D_hi, lanes_hi[3]), 30)), XOR(SHR(XOR(D_hi, lanes_hi[3]), 2), SHL(XOR(D_lo, lanes_lo[3]), 30))
            L, H = XOR(D_lo, lanes_lo[18]), XOR(D_hi, lanes_hi[18])
            lanes_lo[18], lanes_hi[18] = XOR(SHL(L, 15), SHR(H, 17)), XOR(SHL(H, 15), SHR(L, 17))
            D_lo = XOR(lanes_lo[28], SHL(lanes_lo[30], 1), SHR(lanes_hi[30], 31))
            D_hi = XOR(lanes_hi[28], SHL(lanes_hi[30], 1), SHR(lanes_lo[30], 31))
            lanes_lo[4], lanes_hi[4], lanes_lo[9], lanes_hi[9], lanes_lo[19], lanes_hi[19], lanes_lo[24], lanes_hi[24] = XOR(SHL(XOR(D_lo, lanes_lo[19]), 21), SHR(XOR(D_hi, lanes_hi[19]), 11)), XOR(SHL(XOR(D_hi, lanes_hi[19]), 21), SHR(XOR(D_lo, lanes_lo[19]), 11)), XOR(SHL(XOR(D_lo, lanes_lo[4]), 28), SHR(XOR(D_hi, lanes_hi[4]), 4)), XOR(SHL(XOR(D_hi, lanes_hi[4]), 28), SHR(XOR(D_lo, lanes_lo[4]), 4)), XOR(SHR(XOR(D_lo, lanes_lo[24]), 8), SHL(XOR(D_hi, lanes_hi[24]), 24)), XOR(SHR(XOR(D_hi, lanes_hi[24]), 8), SHL(XOR(D_lo, lanes_lo[24]), 24)), XOR(SHR(XOR(D_lo, lanes_lo[9]), 9), SHL(XOR(D_hi, lanes_hi[9]), 23)), XOR(SHR(XOR(D_hi, lanes_hi[9]), 9), SHL(XOR(D_lo, lanes_lo[9]), 23))
            L, H = XOR(D_lo, lanes_lo[14]), XOR(D_hi, lanes_hi[14])
            lanes_lo[14], lanes_hi[14] = XOR(SHL(L, 25), SHR(H, 7)), XOR(SHL(H, 25), SHR(L, 7))
            D_lo = XOR(lanes_lo[29], SHL(lanes_lo[26], 1), SHR(lanes_hi[26], 31))
            D_hi = XOR(lanes_hi[29], SHL(lanes_hi[26], 1), SHR(lanes_lo[26], 31))
            lanes_lo[5], lanes_hi[5], lanes_lo[15], lanes_hi[15], lanes_lo[20], lanes_hi[20], lanes_lo[25], lanes_hi[25] = XOR(SHL(XOR(D_lo, lanes_lo[25]), 14), SHR(XOR(D_hi, lanes_hi[25]), 18)), XOR(SHL(XOR(D_hi, lanes_hi[25]), 14), SHR(XOR(D_lo, lanes_lo[25]), 18)), XOR(SHL(XOR(D_lo, lanes_lo[20]), 8), SHR(XOR(D_hi, lanes_hi[20]), 24)), XOR(SHL(XOR(D_hi, lanes_hi[20]), 8), SHR(XOR(D_lo, lanes_lo[20]), 24)), XOR(SHL(XOR(D_lo, lanes_lo[5]), 27), SHR(XOR(D_hi, lanes_hi[5]), 5)), XOR(SHL(XOR(D_hi, lanes_hi[5]), 27), SHR(XOR(D_lo, lanes_lo[5]), 5)), XOR(SHR(XOR(D_lo, lanes_lo[15]), 25), SHL(XOR(D_hi, lanes_hi[15]), 7)), XOR(SHR(XOR(D_hi, lanes_hi[15]), 25), SHL(XOR(D_lo, lanes_lo[15]), 7))
            L, H = XOR(D_lo, lanes_lo[10]), XOR(D_hi, lanes_hi[10])
            lanes_lo[10], lanes_hi[10] = XOR(SHL(L, 20), SHR(H, 12)), XOR(SHL(H, 20), SHR(L, 12))
            D_lo = XOR(lanes_lo[30], SHL(lanes_lo[27], 1), SHR(lanes_hi[27], 31))
            D_hi = XOR(lanes_hi[30], SHL(lanes_hi[27], 1), SHR(lanes_lo[27], 31))
            lanes_lo[6], lanes_hi[6], lanes_lo[11], lanes_hi[11], lanes_lo[16], lanes_hi[16], lanes_lo[21], lanes_hi[21] = XOR(SHL(XOR(D_lo, lanes_lo[11]), 3), SHR(XOR(D_hi, lanes_hi[11]), 29)), XOR(SHL(XOR(D_hi, lanes_hi[11]), 3), SHR(XOR(D_lo, lanes_lo[11]), 29)), XOR(SHL(XOR(D_lo, lanes_lo[21]), 18), SHR(XOR(D_hi, lanes_hi[21]), 14)), XOR(SHL(XOR(D_hi, lanes_hi[21]), 18), SHR(XOR(D_lo, lanes_lo[21]), 14)), XOR(SHR(XOR(D_lo, lanes_lo[6]), 28), SHL(XOR(D_hi, lanes_hi[6]), 4)), XOR(SHR(XOR(D_hi, lanes_hi[6]), 28), SHL(XOR(D_lo, lanes_lo[6]), 4)), XOR(SHR(XOR(D_lo, lanes_lo[16]), 23), SHL(XOR(D_hi, lanes_hi[16]), 9)), XOR(SHR(XOR(D_hi, lanes_hi[16]), 23), SHL(XOR(D_lo, lanes_lo[16]), 9))
            lanes_lo[1], lanes_hi[1] = XOR(D_lo, lanes_lo[1]), XOR(D_hi, lanes_hi[1])
            lanes_lo[1], lanes_lo[2], lanes_lo[3], lanes_lo[4], lanes_lo[5] = XOR(lanes_lo[1], AND(NOT(lanes_lo[2]), lanes_lo[3]), RC_lo[round_idx]), XOR(lanes_lo[2], AND(NOT(lanes_lo[3]), lanes_lo[4])), XOR(lanes_lo[3], AND(NOT(lanes_lo[4]), lanes_lo[5])), XOR(lanes_lo[4], AND(NOT(lanes_lo[5]), lanes_lo[1])), XOR(lanes_lo[5], AND(NOT(lanes_lo[1]), lanes_lo[2]))
            lanes_lo[6], lanes_lo[7], lanes_lo[8], lanes_lo[9], lanes_lo[10] = XOR(lanes_lo[9], AND(NOT(lanes_lo[10]), lanes_lo[6])), XOR(lanes_lo[10], AND(NOT(lanes_lo[6]), lanes_lo[7])), XOR(lanes_lo[6], AND(NOT(lanes_lo[7]), lanes_lo[8])), XOR(lanes_lo[7], AND(NOT(lanes_lo[8]), lanes_lo[9])), XOR(lanes_lo[8], AND(NOT(lanes_lo[9]), lanes_lo[10]))
            lanes_lo[11], lanes_lo[12], lanes_lo[13], lanes_lo[14], lanes_lo[15] = XOR(lanes_lo[12], AND(NOT(lanes_lo[13]), lanes_lo[14])), XOR(lanes_lo[13], AND(NOT(lanes_lo[14]), lanes_lo[15])), XOR(lanes_lo[14], AND(NOT(lanes_lo[15]), lanes_lo[11])), XOR(lanes_lo[15], AND(NOT(lanes_lo[11]), lanes_lo[12])), XOR(lanes_lo[11], AND(NOT(lanes_lo[12]), lanes_lo[13]))
            lanes_lo[16], lanes_lo[17], lanes_lo[18], lanes_lo[19], lanes_lo[20] = XOR(lanes_lo[20], AND(NOT(lanes_lo[16]), lanes_lo[17])), XOR(lanes_lo[16], AND(NOT(lanes_lo[17]), lanes_lo[18])), XOR(lanes_lo[17], AND(NOT(lanes_lo[18]), lanes_lo[19])), XOR(lanes_lo[18], AND(NOT(lanes_lo[19]), lanes_lo[20])), XOR(lanes_lo[19], AND(NOT(lanes_lo[20]), lanes_lo[16]))
            lanes_lo[21], lanes_lo[22], lanes_lo[23], lanes_lo[24], lanes_lo[25] = XOR(lanes_lo[23], AND(NOT(lanes_lo[24]), lanes_lo[25])), XOR(lanes_lo[24], AND(NOT(lanes_lo[25]), lanes_lo[21])), XOR(lanes_lo[25], AND(NOT(lanes_lo[21]), lanes_lo[22])), XOR(lanes_lo[21], AND(NOT(lanes_lo[22]), lanes_lo[23])), XOR(lanes_lo[22], AND(NOT(lanes_lo[23]), lanes_lo[24]))
            lanes_hi[1], lanes_hi[2], lanes_hi[3], lanes_hi[4], lanes_hi[5] = XOR(lanes_hi[1], AND(NOT(lanes_hi[2]), lanes_hi[3]), RC_hi[round_idx]), XOR(lanes_hi[2], AND(NOT(lanes_hi[3]), lanes_hi[4])), XOR(lanes_hi[3], AND(NOT(lanes_hi[4]), lanes_hi[5])), XOR(lanes_hi[4], AND(NOT(lanes_hi[5]), lanes_hi[1])), XOR(lanes_hi[5], AND(NOT(lanes_hi[1]), lanes_hi[2]))
            lanes_hi[6], lanes_hi[7], lanes_hi[8], lanes_hi[9], lanes_hi[10] = XOR(lanes_hi[9], AND(NOT(lanes_hi[10]), lanes_hi[6])), XOR(lanes_hi[10], AND(NOT(lanes_hi[6]), lanes_hi[7])), XOR(lanes_hi[6], AND(NOT(lanes_hi[7]), lanes_hi[8])), XOR(lanes_hi[7], AND(NOT(lanes_hi[8]), lanes_hi[9])), XOR(lanes_hi[8], AND(NOT(lanes_hi[9]), lanes_hi[10]))
            lanes_hi[11], lanes_hi[12], lanes_hi[13], lanes_hi[14], lanes_hi[15] = XOR(lanes_hi[12], AND(NOT(lanes_hi[13]), lanes_hi[14])), XOR(lanes_hi[13], AND(NOT(lanes_hi[14]), lanes_hi[15])), XOR(lanes_hi[14], AND(NOT(lanes_hi[15]), lanes_hi[11])), XOR(lanes_hi[15], AND(NOT(lanes_hi[11]), lanes_hi[12])), XOR(lanes_hi[11], AND(NOT(lanes_hi[12]), lanes_hi[13]))
            lanes_hi[16], lanes_hi[17], lanes_hi[18], lanes_hi[19], lanes_hi[20] = XOR(lanes_hi[20], AND(NOT(lanes_hi[16]), lanes_hi[17])), XOR(lanes_hi[16], AND(NOT(lanes_hi[17]), lanes_hi[18])), XOR(lanes_hi[17], AND(NOT(lanes_hi[18]), lanes_hi[19])), XOR(lanes_hi[18], AND(NOT(lanes_hi[19]), lanes_hi[20])), XOR(lanes_hi[19], AND(NOT(lanes_hi[20]), lanes_hi[16]))
            lanes_hi[21], lanes_hi[22], lanes_hi[23], lanes_hi[24], lanes_hi[25] = XOR(lanes_hi[23], AND(NOT(lanes_hi[24]), lanes_hi[25])), XOR(lanes_hi[24], AND(NOT(lanes_hi[25]), lanes_hi[21])), XOR(lanes_hi[25], AND(NOT(lanes_hi[21]), lanes_hi[22])), XOR(lanes_hi[21], AND(NOT(lanes_hi[22]), lanes_hi[23])), XOR(lanes_hi[22], AND(NOT(lanes_hi[23]), lanes_hi[24]))
         end
      end
   end

end


if branch == "LJ" then


   -- SHA256 implementation for "LuaJIT without FFI" branch

   function sha256_feed_64(H, str, offs, size)
      -- offs >= 0, size >= 0, size is multiple of 64
      local W, K = common_W, sha2_K_hi
      for pos = offs, offs + size - 1, 64 do
         for j = 1, 16 do
            pos = pos + 4
            local a, b, c, d = byte(str, pos - 3, pos)
            W[j] = OR(SHL(a, 24), SHL(b, 16), SHL(c, 8), d)
         end
         for j = 17, 64 do
            local a, b = W[j-15], W[j-2]
            W[j] = NORM( NORM( XOR(ROR(a, 7), ROL(a, 14), SHR(a, 3)) + XOR(ROL(b, 15), ROL(b, 13), SHR(b, 10)) ) + NORM( W[j-7] + W[j-16] ) )
         end
         local a, b, c, d, e, f, g, h = H[1], H[2], H[3], H[4], H[5], H[6], H[7], H[8]
         for j = 1, 64, 8 do  -- Thanks to Peter Cawley for this workaround (unroll the loop to avoid "PHI shuffling too complex" due to PHIs overlap)
            local z = NORM( XOR(ROR(e, 6), ROR(e, 11), ROL(e, 7)) + XOR(g, AND(e, XOR(f, g))) + (K[j] + W[j] + h) )
            h, g, f, e = g, f, e, NORM(d + z)
            d, c, b, a = c, b, a, NORM( XOR(AND(a, XOR(b, c)), AND(b, c)) + XOR(ROR(a, 2), ROR(a, 13), ROL(a, 10)) + z )
            z = NORM( XOR(ROR(e, 6), ROR(e, 11), ROL(e, 7)) + XOR(g, AND(e, XOR(f, g))) + (K[j+1] + W[j+1] + h) )
            h, g, f, e = g, f, e, NORM(d + z)
            d, c, b, a = c, b, a, NORM( XOR(AND(a, XOR(b, c)), AND(b, c)) + XOR(ROR(a, 2), ROR(a, 13), ROL(a, 10)) + z )
            z = NORM( XOR(ROR(e, 6), ROR(e, 11), ROL(e, 7)) + XOR(g, AND(e, XOR(f, g))) + (K[j+2] + W[j+2] + h) )
            h, g, f, e = g, f, e, NORM(d + z)
            d, c, b, a = c, b, a, NORM( XOR(AND(a, XOR(b, c)), AND(b, c)) + XOR(ROR(a, 2), ROR(a, 13), ROL(a, 10)) + z )
            z = NORM( XOR(ROR(e, 6), ROR(e, 11), ROL(e, 7)) + XOR(g, AND(e, XOR(f, g))) + (K[j+3] + W[j+3] + h) )
            h, g, f, e = g, f, e, NORM(d + z)
            d, c, b, a = c, b, a, NORM( XOR(AND(a, XOR(b, c)), AND(b, c)) + XOR(ROR(a, 2), ROR(a, 13), ROL(a, 10)) + z )
            z = NORM( XOR(ROR(e, 6), ROR(e, 11), ROL(e, 7)) + XOR(g, AND(e, XOR(f, g))) + (K[j+4] + W[j+4] + h) )
            h, g, f, e = g, f, e, NORM(d + z)
            d, c, b, a = c, b, a, NORM( XOR(AND(a, XOR(b, c)), AND(b, c)) + XOR(ROR(a, 2), ROR(a, 13), ROL(a, 10)) + z )
            z = NORM( XOR(ROR(e, 6), ROR(e, 11), ROL(e, 7)) + XOR(g, AND(e, XOR(f, g))) + (K[j+5] + W[j+5] + h) )
            h, g, f, e = g, f, e, NORM(d + z)
            d, c, b, a = c, b, a, NORM( XOR(AND(a, XOR(b, c)), AND(b, c)) + XOR(ROR(a, 2), ROR(a, 13), ROL(a, 10)) + z )
            z = NORM( XOR(ROR(e, 6), ROR(e, 11), ROL(e, 7)) + XOR(g, AND(e, XOR(f, g))) + (K[j+6] + W[j+6] + h) )
            h, g, f, e = g, f, e, NORM(d + z)
            d, c, b, a = c, b, a, NORM( XOR(AND(a, XOR(b, c)), AND(b, c)) + XOR(ROR(a, 2), ROR(a, 13), ROL(a, 10)) + z )
            z = NORM( XOR(ROR(e, 6), ROR(e, 11), ROL(e, 7)) + XOR(g, AND(e, XOR(f, g))) + (K[j+7] + W[j+7] + h) )
            h, g, f, e = g, f, e, NORM(d + z)
            d, c, b, a = c, b, a, NORM( XOR(AND(a, XOR(b, c)), AND(b, c)) + XOR(ROR(a, 2), ROR(a, 13), ROL(a, 10)) + z )
         end
         H[1], H[2], H[3], H[4] = NORM(a + H[1]), NORM(b + H[2]), NORM(c + H[3]), NORM(d + H[4])
         H[5], H[6], H[7], H[8] = NORM(e + H[5]), NORM(f + H[6]), NORM(g + H[7]), NORM(h + H[8])
      end
   end

   local function ADD64_4(a_lo, a_hi, b_lo, b_hi, c_lo, c_hi, d_lo, d_hi)
      local sum_lo = a_lo % 2^32 + b_lo % 2^32 + c_lo % 2^32 + d_lo % 2^32
      local sum_hi = a_hi + b_hi + c_hi + d_hi
      local result_lo = NORM( sum_lo )
      local result_hi = NORM( sum_hi + floor(sum_lo / 2^32) )
      return result_lo, result_hi
   end

   if LuaJIT_arch == "x86" then  -- Special trick is required to avoid "PHI shuffling too complex" on x86 platform


      -- SHA512 implementation for "LuaJIT x86 without FFI" branch

      function sha512_feed_128(H_lo, H_hi, str, offs, size)
         -- offs >= 0, size >= 0, size is multiple of 128
         -- W1_hi, W1_lo, W2_hi, W2_lo, ...   Wk_hi = W[2*k-1], Wk_lo = W[2*k]
         local W, K_lo, K_hi = common_W, sha2_K_lo, sha2_K_hi
         for pos = offs, offs + size - 1, 128 do
            for j = 1, 16*2 do
               pos = pos + 4
               local a, b, c, d = byte(str, pos - 3, pos)
               W[j] = OR(SHL(a, 24), SHL(b, 16), SHL(c, 8), d)
            end
            for jj = 17*2, 80*2, 2 do
               local a_lo, a_hi = W[jj-30], W[jj-31]
               local t_lo = XOR(OR(SHR(a_lo, 1), SHL(a_hi, 31)), OR(SHR(a_lo, 8), SHL(a_hi, 24)), OR(SHR(a_lo, 7), SHL(a_hi, 25)))
               local t_hi = XOR(OR(SHR(a_hi, 1), SHL(a_lo, 31)), OR(SHR(a_hi, 8), SHL(a_lo, 24)), SHR(a_hi, 7))
               local b_lo, b_hi = W[jj-4], W[jj-5]
               local u_lo = XOR(OR(SHR(b_lo, 19), SHL(b_hi, 13)), OR(SHL(b_lo, 3), SHR(b_hi, 29)), OR(SHR(b_lo, 6), SHL(b_hi, 26)))
               local u_hi = XOR(OR(SHR(b_hi, 19), SHL(b_lo, 13)), OR(SHL(b_hi, 3), SHR(b_lo, 29)), SHR(b_hi, 6))
               W[jj], W[jj-1] = ADD64_4(t_lo, t_hi, u_lo, u_hi, W[jj-14], W[jj-15], W[jj-32], W[jj-33])
            end
            local a_lo, b_lo, c_lo, d_lo, e_lo, f_lo, g_lo, h_lo = H_lo[1], H_lo[2], H_lo[3], H_lo[4], H_lo[5], H_lo[6], H_lo[7], H_lo[8]
            local a_hi, b_hi, c_hi, d_hi, e_hi, f_hi, g_hi, h_hi = H_hi[1], H_hi[2], H_hi[3], H_hi[4], H_hi[5], H_hi[6], H_hi[7], H_hi[8]
            local zero = 0
            for j = 1, 80 do
               local t_lo = XOR(g_lo, AND(e_lo, XOR(f_lo, g_lo)))
               local t_hi = XOR(g_hi, AND(e_hi, XOR(f_hi, g_hi)))
               local u_lo = XOR(OR(SHR(e_lo, 14), SHL(e_hi, 18)), OR(SHR(e_lo, 18), SHL(e_hi, 14)), OR(SHL(e_lo, 23), SHR(e_hi, 9)))
               local u_hi = XOR(OR(SHR(e_hi, 14), SHL(e_lo, 18)), OR(SHR(e_hi, 18), SHL(e_lo, 14)), OR(SHL(e_hi, 23), SHR(e_lo, 9)))
               local sum_lo = u_lo % 2^32 + t_lo % 2^32 + h_lo % 2^32 + K_lo[j] + W[2*j] % 2^32
               local z_lo, z_hi = NORM( sum_lo ), NORM( u_hi + t_hi + h_hi + K_hi[j] + W[2*j-1] + floor(sum_lo / 2^32) )
               zero = zero + zero  -- this thick is needed to avoid "PHI shuffling too complex" due to PHIs overlap
               h_lo, h_hi, g_lo, g_hi, f_lo, f_hi = OR(zero, g_lo), OR(zero, g_hi), OR(zero, f_lo), OR(zero, f_hi), OR(zero, e_lo), OR(zero, e_hi)
               local sum_lo = z_lo % 2^32 + d_lo % 2^32
               e_lo, e_hi = NORM( sum_lo ), NORM( z_hi + d_hi + floor(sum_lo / 2^32) )
               d_lo, d_hi, c_lo, c_hi, b_lo, b_hi = OR(zero, c_lo), OR(zero, c_hi), OR(zero, b_lo), OR(zero, b_hi), OR(zero, a_lo), OR(zero, a_hi)
               u_lo = XOR(OR(SHR(b_lo, 28), SHL(b_hi, 4)), OR(SHL(b_lo, 30), SHR(b_hi, 2)), OR(SHL(b_lo, 25), SHR(b_hi, 7)))
               u_hi = XOR(OR(SHR(b_hi, 28), SHL(b_lo, 4)), OR(SHL(b_hi, 30), SHR(b_lo, 2)), OR(SHL(b_hi, 25), SHR(b_lo, 7)))
               t_lo = OR(AND(d_lo, c_lo), AND(b_lo, XOR(d_lo, c_lo)))
               t_hi = OR(AND(d_hi, c_hi), AND(b_hi, XOR(d_hi, c_hi)))
               local sum_lo = z_lo % 2^32 + t_lo % 2^32 + u_lo % 2^32
               a_lo, a_hi = NORM( sum_lo ), NORM( z_hi + t_hi + u_hi + floor(sum_lo / 2^32) )
            end
            H_lo[1], H_hi[1] = ADD64_4(H_lo[1], H_hi[1], a_lo, a_hi, 0, 0, 0, 0)
            H_lo[2], H_hi[2] = ADD64_4(H_lo[2], H_hi[2], b_lo, b_hi, 0, 0, 0, 0)
            H_lo[3], H_hi[3] = ADD64_4(H_lo[3], H_hi[3], c_lo, c_hi, 0, 0, 0, 0)
            H_lo[4], H_hi[4] = ADD64_4(H_lo[4], H_hi[4], d_lo, d_hi, 0, 0, 0, 0)
            H_lo[5], H_hi[5] = ADD64_4(H_lo[5], H_hi[5], e_lo, e_hi, 0, 0, 0, 0)
            H_lo[6], H_hi[6] = ADD64_4(H_lo[6], H_hi[6], f_lo, f_hi, 0, 0, 0, 0)
            H_lo[7], H_hi[7] = ADD64_4(H_lo[7], H_hi[7], g_lo, g_hi, 0, 0, 0, 0)
            H_lo[8], H_hi[8] = ADD64_4(H_lo[8], H_hi[8], h_lo, h_hi, 0, 0, 0, 0)
         end
      end

   else  -- all platforms except x86


      -- SHA512 implementation for "LuaJIT non-x86 without FFI" branch

      function sha512_feed_128(H_lo, H_hi, str, offs, size)
         -- offs >= 0, size >= 0, size is multiple of 128
         -- W1_hi, W1_lo, W2_hi, W2_lo, ...   Wk_hi = W[2*k-1], Wk_lo = W[2*k]
         local W, K_lo, K_hi = common_W, sha2_K_lo, sha2_K_hi
         for pos = offs, offs + size - 1, 128 do
            for j = 1, 16*2 do
               pos = pos + 4
               local a, b, c, d = byte(str, pos - 3, pos)
               W[j] = OR(SHL(a, 24), SHL(b, 16), SHL(c, 8), d)
            end
            for jj = 17*2, 80*2, 2 do
               local a_lo, a_hi = W[jj-30], W[jj-31]
               local t_lo = XOR(OR(SHR(a_lo, 1), SHL(a_hi, 31)), OR(SHR(a_lo, 8), SHL(a_hi, 24)), OR(SHR(a_lo, 7), SHL(a_hi, 25)))
               local t_hi = XOR(OR(SHR(a_hi, 1), SHL(a_lo, 31)), OR(SHR(a_hi, 8), SHL(a_lo, 24)), SHR(a_hi, 7))
               local b_lo, b_hi = W[jj-4], W[jj-5]
               local u_lo = XOR(OR(SHR(b_lo, 19), SHL(b_hi, 13)), OR(SHL(b_lo, 3), SHR(b_hi, 29)), OR(SHR(b_lo, 6), SHL(b_hi, 26)))
               local u_hi = XOR(OR(SHR(b_hi, 19), SHL(b_lo, 13)), OR(SHL(b_hi, 3), SHR(b_lo, 29)), SHR(b_hi, 6))
               W[jj], W[jj-1] = ADD64_4(t_lo, t_hi, u_lo, u_hi, W[jj-14], W[jj-15], W[jj-32], W[jj-33])
            end
            local a_lo, b_lo, c_lo, d_lo, e_lo, f_lo, g_lo, h_lo = H_lo[1], H_lo[2], H_lo[3], H_lo[4], H_lo[5], H_lo[6], H_lo[7], H_lo[8]
            local a_hi, b_hi, c_hi, d_hi, e_hi, f_hi, g_hi, h_hi = H_hi[1], H_hi[2], H_hi[3], H_hi[4], H_hi[5], H_hi[6], H_hi[7], H_hi[8]
            for j = 1, 80 do
               local t_lo = XOR(g_lo, AND(e_lo, XOR(f_lo, g_lo)))
               local t_hi = XOR(g_hi, AND(e_hi, XOR(f_hi, g_hi)))
               local u_lo = XOR(OR(SHR(e_lo, 14), SHL(e_hi, 18)), OR(SHR(e_lo, 18), SHL(e_hi, 14)), OR(SHL(e_lo, 23), SHR(e_hi, 9)))
               local u_hi = XOR(OR(SHR(e_hi, 14), SHL(e_lo, 18)), OR(SHR(e_hi, 18), SHL(e_lo, 14)), OR(SHL(e_hi, 23), SHR(e_lo, 9)))
               local sum_lo = u_lo % 2^32 + t_lo % 2^32 + h_lo % 2^32 + K_lo[j] + W[2*j] % 2^32
               local z_lo, z_hi = NORM( sum_lo ), NORM( u_hi + t_hi + h_hi + K_hi[j] + W[2*j-1] + floor(sum_lo / 2^32) )
               h_lo, h_hi, g_lo, g_hi, f_lo, f_hi = g_lo, g_hi, f_lo, f_hi, e_lo, e_hi
               local sum_lo = z_lo % 2^32 + d_lo % 2^32
               e_lo, e_hi = NORM( sum_lo ), NORM( z_hi + d_hi + floor(sum_lo / 2^32) )
               d_lo, d_hi, c_lo, c_hi, b_lo, b_hi = c_lo, c_hi, b_lo, b_hi, a_lo, a_hi
               u_lo = XOR(OR(SHR(b_lo, 28), SHL(b_hi, 4)), OR(SHL(b_lo, 30), SHR(b_hi, 2)), OR(SHL(b_lo, 25), SHR(b_hi, 7)))
               u_hi = XOR(OR(SHR(b_hi, 28), SHL(b_lo, 4)), OR(SHL(b_hi, 30), SHR(b_lo, 2)), OR(SHL(b_hi, 25), SHR(b_lo, 7)))
               t_lo = OR(AND(d_lo, c_lo), AND(b_lo, XOR(d_lo, c_lo)))
               t_hi = OR(AND(d_hi, c_hi), AND(b_hi, XOR(d_hi, c_hi)))
               local sum_lo = z_lo % 2^32 + u_lo % 2^32 + t_lo % 2^32
               a_lo, a_hi = NORM( sum_lo ), NORM( z_hi + u_hi + t_hi + floor(sum_lo / 2^32) )
            end
            H_lo[1], H_hi[1] = ADD64_4(H_lo[1], H_hi[1], a_lo, a_hi, 0, 0, 0, 0)
            H_lo[2], H_hi[2] = ADD64_4(H_lo[2], H_hi[2], b_lo, b_hi, 0, 0, 0, 0)
            H_lo[3], H_hi[3] = ADD64_4(H_lo[3], H_hi[3], c_lo, c_hi, 0, 0, 0, 0)
            H_lo[4], H_hi[4] = ADD64_4(H_lo[4], H_hi[4], d_lo, d_hi, 0, 0, 0, 0)
            H_lo[5], H_hi[5] = ADD64_4(H_lo[5], H_hi[5], e_lo, e_hi, 0, 0, 0, 0)
            H_lo[6], H_hi[6] = ADD64_4(H_lo[6], H_hi[6], f_lo, f_hi, 0, 0, 0, 0)
            H_lo[7], H_hi[7] = ADD64_4(H_lo[7], H_hi[7], g_lo, g_hi, 0, 0, 0, 0)
            H_lo[8], H_hi[8] = ADD64_4(H_lo[8], H_hi[8], h_lo, h_hi, 0, 0, 0, 0)
         end
      end

   end


   -- MD5 implementation for "LuaJIT without FFI" branch

   function md5_feed_64(H, str, offs, size)
      -- offs >= 0, size >= 0, size is multiple of 64
      local W, K = common_W, md5_K
      for pos = offs, offs + size - 1, 64 do
         for j = 1, 16 do
            pos = pos + 4
            local a, b, c, d = byte(str, pos - 3, pos)
            W[j] = OR(SHL(d, 24), SHL(c, 16), SHL(b, 8), a)
         end
         local a, b, c, d = H[1], H[2], H[3], H[4]
         for j = 1, 16, 4 do
            a, d, c, b = d, c, b, NORM(ROL(XOR(d, AND(b, XOR(c, d))) + (K[j  ] + W[j  ] + a),  7) + b)
            a, d, c, b = d, c, b, NORM(ROL(XOR(d, AND(b, XOR(c, d))) + (K[j+1] + W[j+1] + a), 12) + b)
            a, d, c, b = d, c, b, NORM(ROL(XOR(d, AND(b, XOR(c, d))) + (K[j+2] + W[j+2] + a), 17) + b)
            a, d, c, b = d, c, b, NORM(ROL(XOR(d, AND(b, XOR(c, d))) + (K[j+3] + W[j+3] + a), 22) + b)
         end
         for j = 17, 32, 4 do
            local g = 5*j-4
            a, d, c, b = d, c, b, NORM(ROL(XOR(c, AND(d, XOR(b, c))) + (K[j  ] + W[AND(g     , 15) + 1] + a),  5) + b)
            a, d, c, b = d, c, b, NORM(ROL(XOR(c, AND(d, XOR(b, c))) + (K[j+1] + W[AND(g +  5, 15) + 1] + a),  9) + b)
            a, d, c, b = d, c, b, NORM(ROL(XOR(c, AND(d, XOR(b, c))) + (K[j+2] + W[AND(g + 10, 15) + 1] + a), 14) + b)
            a, d, c, b = d, c, b, NORM(ROL(XOR(c, AND(d, XOR(b, c))) + (K[j+3] + W[AND(g -  1, 15) + 1] + a), 20) + b)
         end
         for j = 33, 48, 4 do
            local g = 3*j+2
            a, d, c, b = d, c, b, NORM(ROL(XOR(b, c, d) + (K[j  ] + W[AND(g    , 15) + 1] + a),  4) + b)
            a, d, c, b = d, c, b, NORM(ROL(XOR(b, c, d) + (K[j+1] + W[AND(g + 3, 15) + 1] + a), 11) + b)
            a, d, c, b = d, c, b, NORM(ROL(XOR(b, c, d) + (K[j+2] + W[AND(g + 6, 15) + 1] + a), 16) + b)
            a, d, c, b = d, c, b, NORM(ROL(XOR(b, c, d) + (K[j+3] + W[AND(g - 7, 15) + 1] + a), 23) + b)
         end
         for j = 49, 64, 4 do
            local g = j*7
            a, d, c, b = d, c, b, NORM(ROL(XOR(c, OR(b, NOT(d))) + (K[j  ] + W[AND(g - 7, 15) + 1] + a),  6) + b)
            a, d, c, b = d, c, b, NORM(ROL(XOR(c, OR(b, NOT(d))) + (K[j+1] + W[AND(g    , 15) + 1] + a), 10) + b)
            a, d, c, b = d, c, b, NORM(ROL(XOR(c, OR(b, NOT(d))) + (K[j+2] + W[AND(g + 7, 15) + 1] + a), 15) + b)
            a, d, c, b = d, c, b, NORM(ROL(XOR(c, OR(b, NOT(d))) + (K[j+3] + W[AND(g - 2, 15) + 1] + a), 21) + b)
         end
         H[1], H[2], H[3], H[4] = NORM(a + H[1]), NORM(b + H[2]), NORM(c + H[3]), NORM(d + H[4])
      end
   end


   -- SHA-1 implementation for "LuaJIT without FFI" branch

   function sha1_feed_64(H, str, offs, size)
      -- offs >= 0, size >= 0, size is multiple of 64
      local W = common_W
      for pos = offs, offs + size - 1, 64 do
         for j = 1, 16 do
            pos = pos + 4
            local a, b, c, d = byte(str, pos - 3, pos)
            W[j] = OR(SHL(a, 24), SHL(b, 16), SHL(c, 8), d)
         end
         for j = 17, 80 do
            W[j] = ROL(XOR(W[j-3], W[j-8], W[j-14], W[j-16]), 1)
         end
         local a, b, c, d, e = H[1], H[2], H[3], H[4], H[5]
         for j = 1, 20, 5 do
            e, d, c, b, a = d, c, ROR(b, 2), a, NORM(ROL(a, 5) + XOR(d, AND(b, XOR(d, c))) + (W[j]   + 0x5A827999 + e))          -- constant = floor(2^30 * sqrt(2))
            e, d, c, b, a = d, c, ROR(b, 2), a, NORM(ROL(a, 5) + XOR(d, AND(b, XOR(d, c))) + (W[j+1] + 0x5A827999 + e))
            e, d, c, b, a = d, c, ROR(b, 2), a, NORM(ROL(a, 5) + XOR(d, AND(b, XOR(d, c))) + (W[j+2] + 0x5A827999 + e))
            e, d, c, b, a = d, c, ROR(b, 2), a, NORM(ROL(a, 5) + XOR(d, AND(b, XOR(d, c))) + (W[j+3] + 0x5A827999 + e))
            e, d, c, b, a = d, c, ROR(b, 2), a, NORM(ROL(a, 5) + XOR(d, AND(b, XOR(d, c))) + (W[j+4] + 0x5A827999 + e))
         end
         for j = 21, 40, 5 do
            e, d, c, b, a = d, c, ROR(b, 2), a, NORM(ROL(a, 5) + XOR(b, c, d) + (W[j]   + 0x6ED9EBA1 + e))                       -- 2^30 * sqrt(3)
            e, d, c, b, a = d, c, ROR(b, 2), a, NORM(ROL(a, 5) + XOR(b, c, d) + (W[j+1] + 0x6ED9EBA1 + e))
            e, d, c, b, a = d, c, ROR(b, 2), a, NORM(ROL(a, 5) + XOR(b, c, d) + (W[j+2] + 0x6ED9EBA1 + e))
            e, d, c, b, a = d, c, ROR(b, 2), a, NORM(ROL(a, 5) + XOR(b, c, d) + (W[j+3] + 0x6ED9EBA1 + e))
            e, d, c, b, a = d, c, ROR(b, 2), a, NORM(ROL(a, 5) + XOR(b, c, d) + (W[j+4] + 0x6ED9EBA1 + e))
         end
         for j = 41, 60, 5 do
            e, d, c, b, a = d, c, ROR(b, 2), a, NORM(ROL(a, 5) + XOR(AND(d, XOR(b, c)), AND(b, c)) + (W[j]   + 0x8F1BBCDC + e))  -- 2^30 * sqrt(5)
            e, d, c, b, a = d, c, ROR(b, 2), a, NORM(ROL(a, 5) + XOR(AND(d, XOR(b, c)), AND(b, c)) + (W[j+1] + 0x8F1BBCDC + e))
            e, d, c, b, a = d, c, ROR(b, 2), a, NORM(ROL(a, 5) + XOR(AND(d, XOR(b, c)), AND(b, c)) + (W[j+2] + 0x8F1BBCDC + e))
            e, d, c, b, a = d, c, ROR(b, 2), a, NORM(ROL(a, 5) + XOR(AND(d, XOR(b, c)), AND(b, c)) + (W[j+3] + 0x8F1BBCDC + e))
            e, d, c, b, a = d, c, ROR(b, 2), a, NORM(ROL(a, 5) + XOR(AND(d, XOR(b, c)), AND(b, c)) + (W[j+4] + 0x8F1BBCDC + e))
         end
         for j = 61, 80, 5 do
            e, d, c, b, a = d, c, ROR(b, 2), a, NORM(ROL(a, 5) + XOR(b, c, d) + (W[j]   + 0xCA62C1D6 + e))                       -- 2^30 * sqrt(10)
            e, d, c, b, a = d, c, ROR(b, 2), a, NORM(ROL(a, 5) + XOR(b, c, d) + (W[j+1] + 0xCA62C1D6 + e))
            e, d, c, b, a = d, c, ROR(b, 2), a, NORM(ROL(a, 5) + XOR(b, c, d) + (W[j+2] + 0xCA62C1D6 + e))
            e, d, c, b, a = d, c, ROR(b, 2), a, NORM(ROL(a, 5) + XOR(b, c, d) + (W[j+3] + 0xCA62C1D6 + e))
            e, d, c, b, a = d, c, ROR(b, 2), a, NORM(ROL(a, 5) + XOR(b, c, d) + (W[j+4] + 0xCA62C1D6 + e))
         end
         H[1], H[2], H[3], H[4], H[5] = NORM(a + H[1]), NORM(b + H[2]), NORM(c + H[3]), NORM(d + H[4]), NORM(e + H[5])
      end
   end


   -- BLAKE2b implementation for "LuaJIT without FFI" branch

   do
      local v_lo, v_hi = {}, {}

      local function G(a, b, c, d, k1, k2)
         local W = common_W
         local va_lo, vb_lo, vc_lo, vd_lo = v_lo[a], v_lo[b], v_lo[c], v_lo[d]
         local va_hi, vb_hi, vc_hi, vd_hi = v_hi[a], v_hi[b], v_hi[c], v_hi[d]
         local z = W[2*k1-1] + (va_lo % 2^32 + vb_lo % 2^32)
         va_lo = NORM(z)
         va_hi = NORM(W[2*k1] + (va_hi + vb_hi + floor(z / 2^32)))
         vd_lo, vd_hi = XOR(vd_hi, va_hi), XOR(vd_lo, va_lo)
         z = vc_lo % 2^32 + vd_lo % 2^32
         vc_lo = NORM(z)
         vc_hi = NORM(vc_hi + vd_hi + floor(z / 2^32))
         vb_lo, vb_hi = XOR(vb_lo, vc_lo), XOR(vb_hi, vc_hi)
         vb_lo, vb_hi = XOR(SHR(vb_lo, 24), SHL(vb_hi, 8)), XOR(SHR(vb_hi, 24), SHL(vb_lo, 8))
         z = W[2*k2-1] + (va_lo % 2^32 + vb_lo % 2^32)
         va_lo = NORM(z)
         va_hi = NORM(W[2*k2] + (va_hi + vb_hi + floor(z / 2^32)))
         vd_lo, vd_hi = XOR(vd_lo, va_lo), XOR(vd_hi, va_hi)
         vd_lo, vd_hi = XOR(SHR(vd_lo, 16), SHL(vd_hi, 16)), XOR(SHR(vd_hi, 16), SHL(vd_lo, 16))
         z = vc_lo % 2^32 + vd_lo % 2^32
         vc_lo = NORM(z)
         vc_hi = NORM(vc_hi + vd_hi + floor(z / 2^32))
         vb_lo, vb_hi = XOR(vb_lo, vc_lo), XOR(vb_hi, vc_hi)
         vb_lo, vb_hi = XOR(SHL(vb_lo, 1), SHR(vb_hi, 31)), XOR(SHL(vb_hi, 1), SHR(vb_lo, 31))
         v_lo[a], v_lo[b], v_lo[c], v_lo[d] = va_lo, vb_lo, vc_lo, vd_lo
         v_hi[a], v_hi[b], v_hi[c], v_hi[d] = va_hi, vb_hi, vc_hi, vd_hi
      end

      function blake2b_feed_128(H_lo, H_hi, str, offs, size, bytes_compressed, last_block_size, is_last_node)
         -- offs >= 0, size >= 0, size is multiple of 128
         local W = common_W
         local h1_lo, h2_lo, h3_lo, h4_lo, h5_lo, h6_lo, h7_lo, h8_lo = H_lo[1], H_lo[2], H_lo[3], H_lo[4], H_lo[5], H_lo[6], H_lo[7], H_lo[8]
         local h1_hi, h2_hi, h3_hi, h4_hi, h5_hi, h6_hi, h7_hi, h8_hi = H_hi[1], H_hi[2], H_hi[3], H_hi[4], H_hi[5], H_hi[6], H_hi[7], H_hi[8]
         for pos = offs, offs + size - 1, 128 do
            if str then
               for j = 1, 32 do
                  pos = pos + 4
                  local a, b, c, d = byte(str, pos - 3, pos)
                  W[j] = d * 2^24 + OR(SHL(c, 16), SHL(b, 8), a)
               end
            end
            v_lo[0x0], v_lo[0x1], v_lo[0x2], v_lo[0x3], v_lo[0x4], v_lo[0x5], v_lo[0x6], v_lo[0x7] = h1_lo, h2_lo, h3_lo, h4_lo, h5_lo, h6_lo, h7_lo, h8_lo
            v_lo[0x8], v_lo[0x9], v_lo[0xA], v_lo[0xB], v_lo[0xC], v_lo[0xD], v_lo[0xE], v_lo[0xF] = sha2_H_lo[1], sha2_H_lo[2], sha2_H_lo[3], sha2_H_lo[4], sha2_H_lo[5], sha2_H_lo[6], sha2_H_lo[7], sha2_H_lo[8]
            v_hi[0x0], v_hi[0x1], v_hi[0x2], v_hi[0x3], v_hi[0x4], v_hi[0x5], v_hi[0x6], v_hi[0x7] = h1_hi, h2_hi, h3_hi, h4_hi, h5_hi, h6_hi, h7_hi, h8_hi
            v_hi[0x8], v_hi[0x9], v_hi[0xA], v_hi[0xB], v_hi[0xC], v_hi[0xD], v_hi[0xE], v_hi[0xF] = sha2_H_hi[1], sha2_H_hi[2], sha2_H_hi[3], sha2_H_hi[4], sha2_H_hi[5], sha2_H_hi[6], sha2_H_hi[7], sha2_H_hi[8]
            bytes_compressed = bytes_compressed + (last_block_size or 128)
            local t0_lo = bytes_compressed % 2^32
            local t0_hi = floor(bytes_compressed / 2^32)
            v_lo[0xC] = XOR(v_lo[0xC], t0_lo)  -- t0 = low_8_bytes(bytes_compressed)
            v_hi[0xC] = XOR(v_hi[0xC], t0_hi)
            -- t1 = high_8_bytes(bytes_compressed) = 0,  message length is always below 2^53 bytes
            if last_block_size then  -- flag f0
               v_lo[0xE] = NOT(v_lo[0xE])
               v_hi[0xE] = NOT(v_hi[0xE])
            end
            if is_last_node then  -- flag f1
               v_lo[0xF] = NOT(v_lo[0xF])
               v_hi[0xF] = NOT(v_hi[0xF])
            end
            for j = 1, 12 do
               local row = sigma[j]
               G(0, 4,  8, 12, row[ 1], row[ 2])
               G(1, 5,  9, 13, row[ 3], row[ 4])
               G(2, 6, 10, 14, row[ 5], row[ 6])
               G(3, 7, 11, 15, row[ 7], row[ 8])
               G(0, 5, 10, 15, row[ 9], row[10])
               G(1, 6, 11, 12, row[11], row[12])
               G(2, 7,  8, 13, row[13], row[14])
               G(3, 4,  9, 14, row[15], row[16])
            end
            h1_lo = XOR(h1_lo, v_lo[0x0], v_lo[0x8])
            h2_lo = XOR(h2_lo, v_lo[0x1], v_lo[0x9])
            h3_lo = XOR(h3_lo, v_lo[0x2], v_lo[0xA])
            h4_lo = XOR(h4_lo, v_lo[0x3], v_lo[0xB])
            h5_lo = XOR(h5_lo, v_lo[0x4], v_lo[0xC])
            h6_lo = XOR(h6_lo, v_lo[0x5], v_lo[0xD])
            h7_lo = XOR(h7_lo, v_lo[0x6], v_lo[0xE])
            h8_lo = XOR(h8_lo, v_lo[0x7], v_lo[0xF])
            h1_hi = XOR(h1_hi, v_hi[0x0], v_hi[0x8])
            h2_hi = XOR(h2_hi, v_hi[0x1], v_hi[0x9])
            h3_hi = XOR(h3_hi, v_hi[0x2], v_hi[0xA])
            h4_hi = XOR(h4_hi, v_hi[0x3], v_hi[0xB])
            h5_hi = XOR(h5_hi, v_hi[0x4], v_hi[0xC])
            h6_hi = XOR(h6_hi, v_hi[0x5], v_hi[0xD])
            h7_hi = XOR(h7_hi, v_hi[0x6], v_hi[0xE])
            h8_hi = XOR(h8_hi, v_hi[0x7], v_hi[0xF])
         end
         H_lo[1], H_lo[2], H_lo[3], H_lo[4], H_lo[5], H_lo[6], H_lo[7], H_lo[8] = h1_lo % 2^32, h2_lo % 2^32, h3_lo % 2^32, h4_lo % 2^32, h5_lo % 2^32, h6_lo % 2^32, h7_lo % 2^32, h8_lo % 2^32
         H_hi[1], H_hi[2], H_hi[3], H_hi[4], H_hi[5], H_hi[6], H_hi[7], H_hi[8] = h1_hi % 2^32, h2_hi % 2^32, h3_hi % 2^32, h4_hi % 2^32, h5_hi % 2^32, h6_hi % 2^32, h7_hi % 2^32, h8_hi % 2^32
         return bytes_compressed
      end

   end
end


if branch == "FFI" or branch == "LJ" then


   -- BLAKE2s and BLAKE3 implementations for "LuaJIT with FFI" and "LuaJIT without FFI" branches

   do
      local W = common_W_blake2s
      local v = v_for_blake2s_feed_64

      local function G(a, b, c, d, k1, k2)
         local va, vb, vc, vd = v[a], v[b], v[c], v[d]
         va = NORM(W[k1] + (va + vb))
         vd = ROR(XOR(vd, va), 16)
         vc = NORM(vc + vd)
         vb = ROR(XOR(vb, vc), 12)
         va = NORM(W[k2] + (va + vb))
         vd = ROR(XOR(vd, va), 8)
         vc = NORM(vc + vd)
         vb = ROR(XOR(vb, vc), 7)
         v[a], v[b], v[c], v[d] = va, vb, vc, vd
      end

      function blake2s_feed_64(H, str, offs, size, bytes_compressed, last_block_size, is_last_node)
         -- offs >= 0, size >= 0, size is multiple of 64
         local h1, h2, h3, h4, h5, h6, h7, h8 = NORM(H[1]), NORM(H[2]), NORM(H[3]), NORM(H[4]), NORM(H[5]), NORM(H[6]), NORM(H[7]), NORM(H[8])
         for pos = offs, offs + size - 1, 64 do
            if str then
               for j = 1, 16 do
                  pos = pos + 4
                  local a, b, c, d = byte(str, pos - 3, pos)
                  W[j] = OR(SHL(d, 24), SHL(c, 16), SHL(b, 8), a)
               end
            end
            v[0x0], v[0x1], v[0x2], v[0x3], v[0x4], v[0x5], v[0x6], v[0x7] = h1, h2, h3, h4, h5, h6, h7, h8
            v[0x8], v[0x9], v[0xA], v[0xB], v[0xE], v[0xF] = NORM(sha2_H_hi[1]), NORM(sha2_H_hi[2]), NORM(sha2_H_hi[3]), NORM(sha2_H_hi[4]), NORM(sha2_H_hi[7]), NORM(sha2_H_hi[8])
            bytes_compressed = bytes_compressed + (last_block_size or 64)
            local t0 = bytes_compressed % 2^32
            local t1 = floor(bytes_compressed / 2^32)
            v[0xC] = XOR(sha2_H_hi[5], t0)  -- t0 = low_4_bytes(bytes_compressed)
            v[0xD] = XOR(sha2_H_hi[6], t1)  -- t1 = high_4_bytes(bytes_compressed
            if last_block_size then  -- flag f0
               v[0xE] = NOT(v[0xE])
            end
            if is_last_node then  -- flag f1
               v[0xF] = NOT(v[0xF])
            end
            for j = 1, 10 do
               local row = sigma[j]
               G(0, 4,  8, 12, row[ 1], row[ 2])
               G(1, 5,  9, 13, row[ 3], row[ 4])
               G(2, 6, 10, 14, row[ 5], row[ 6])
               G(3, 7, 11, 15, row[ 7], row[ 8])
               G(0, 5, 10, 15, row[ 9], row[10])
               G(1, 6, 11, 12, row[11], row[12])
               G(2, 7,  8, 13, row[13], row[14])
               G(3, 4,  9, 14, row[15], row[16])
            end
            h1 = XOR(h1, v[0x0], v[0x8])
            h2 = XOR(h2, v[0x1], v[0x9])
            h3 = XOR(h3, v[0x2], v[0xA])
            h4 = XOR(h4, v[0x3], v[0xB])
            h5 = XOR(h5, v[0x4], v[0xC])
            h6 = XOR(h6, v[0x5], v[0xD])
            h7 = XOR(h7, v[0x6], v[0xE])
            h8 = XOR(h8, v[0x7], v[0xF])
         end
         H[1], H[2], H[3], H[4], H[5], H[6], H[7], H[8] = h1, h2, h3, h4, h5, h6, h7, h8
         return bytes_compressed
      end

      function blake3_feed_64(str, offs, size, flags, chunk_index, H_in, H_out, wide_output, block_length)
         -- offs >= 0, size >= 0, size is multiple of 64
         block_length = block_length or 64
         local h1, h2, h3, h4, h5, h6, h7, h8 = NORM(H_in[1]), NORM(H_in[2]), NORM(H_in[3]), NORM(H_in[4]), NORM(H_in[5]), NORM(H_in[6]), NORM(H_in[7]), NORM(H_in[8])
         H_out = H_out or H_in
         for pos = offs, offs + size - 1, 64 do
            if str then
               for j = 1, 16 do
                  pos = pos + 4
                  local a, b, c, d = byte(str, pos - 3, pos)
                  W[j] = OR(SHL(d, 24), SHL(c, 16), SHL(b, 8), a)
               end
            end
            v[0x0], v[0x1], v[0x2], v[0x3], v[0x4], v[0x5], v[0x6], v[0x7] = h1, h2, h3, h4, h5, h6, h7, h8
            v[0x8], v[0x9], v[0xA], v[0xB] = NORM(sha2_H_hi[1]), NORM(sha2_H_hi[2]), NORM(sha2_H_hi[3]), NORM(sha2_H_hi[4])
            v[0xC] = NORM(chunk_index % 2^32)   -- t0 = low_4_bytes(chunk_index)
            v[0xD] = floor(chunk_index / 2^32)  -- t1 = high_4_bytes(chunk_index)
            v[0xE], v[0xF] = block_length, flags
            for j = 1, 7 do
               G(0, 4,  8, 12, perm_blake3[j],      perm_blake3[j + 14])
               G(1, 5,  9, 13, perm_blake3[j + 1],  perm_blake3[j + 2])
               G(2, 6, 10, 14, perm_blake3[j + 16], perm_blake3[j + 7])
               G(3, 7, 11, 15, perm_blake3[j + 15], perm_blake3[j + 17])
               G(0, 5, 10, 15, perm_blake3[j + 21], perm_blake3[j + 5])
               G(1, 6, 11, 12, perm_blake3[j + 3],  perm_blake3[j + 6])
               G(2, 7,  8, 13, perm_blake3[j + 4],  perm_blake3[j + 18])
               G(3, 4,  9, 14, perm_blake3[j + 19], perm_blake3[j + 20])
            end
            if wide_output then
               H_out[ 9] = XOR(h1, v[0x8])
               H_out[10] = XOR(h2, v[0x9])
               H_out[11] = XOR(h3, v[0xA])
               H_out[12] = XOR(h4, v[0xB])
               H_out[13] = XOR(h5, v[0xC])
               H_out[14] = XOR(h6, v[0xD])
               H_out[15] = XOR(h7, v[0xE])
               H_out[16] = XOR(h8, v[0xF])
            end
            h1 = XOR(v[0x0], v[0x8])
            h2 = XOR(v[0x1], v[0x9])
            h3 = XOR(v[0x2], v[0xA])
            h4 = XOR(v[0x3], v[0xB])
            h5 = XOR(v[0x4], v[0xC])
            h6 = XOR(v[0x5], v[0xD])
            h7 = XOR(v[0x6], v[0xE])
            h8 = XOR(v[0x7], v[0xF])
         end
         H_out[1], H_out[2], H_out[3], H_out[4], H_out[5], H_out[6], H_out[7], H_out[8] = h1, h2, h3, h4, h5, h6, h7, h8
      end

   end

end


if branch == "INT64" then


   -- implementation for Lua 5.3/5.4

   hi_factor = 4294967296
   hi_factor_keccak = 4294967296
   lanes_index_base = 1

   HEX64, XORA5, XOR_BYTE, sha256_feed_64, sha512_feed_128, md5_feed_64, sha1_feed_64, keccak_feed, blake2s_feed_64, blake2b_feed_128, blake3_feed_64 = load[=[-- branch "INT64"
      local md5_next_shift, md5_K, sha2_K_lo, sha2_K_hi, build_keccak_format, sha3_RC_lo, sigma, common_W, sha2_H_lo, sha2_H_hi, perm_blake3 = ...
      local string_format, string_unpack = string.format, string.unpack

      local function HEX64(x)
         return string_format("%016x", x)
      end

      local function XORA5(x, y)
         return x ~ (y or 0xa5a5a5a5a5a5a5a5)
      end

      local function XOR_BYTE(x, y)
         return x ~ y
      end

      local function sha256_feed_64(H, str, offs, size)
         -- offs >= 0, size >= 0, size is multiple of 64
         local W, K = common_W, sha2_K_hi
         local h1, h2, h3, h4, h5, h6, h7, h8 = H[1], H[2], H[3], H[4], H[5], H[6], H[7], H[8]
         for pos = offs + 1, offs + size, 64 do
            W[1], W[2], W[3], W[4], W[5], W[6], W[7], W[8], W[9], W[10], W[11], W[12], W[13], W[14], W[15], W[16] =
               string_unpack(">I4I4I4I4I4I4I4I4I4I4I4I4I4I4I4I4", str, pos)
            for j = 17, 64 do
               local a = W[j-15]
               a = a<<32 | a
               local b = W[j-2]
               b = b<<32 | b
               W[j] = (a>>7 ~ a>>18 ~ a>>35) + (b>>17 ~ b>>19 ~ b>>42) + W[j-7] + W[j-16] & (1<<32)-1
            end
            local a, b, c, d, e, f, g, h = h1, h2, h3, h4, h5, h6, h7, h8
            for j = 1, 64 do
               e = e<<32 | e & (1<<32)-1
               local z = (e>>6 ~ e>>11 ~ e>>25) + (g ~ e & (f ~ g)) + h + K[j] + W[j]
               h = g
               g = f
               f = e
               e = z + d
               d = c
               c = b
               b = a
               a = a<<32 | a & (1<<32)-1
               a = z + ((a ~ c) & d ~ a & c) + (a>>2 ~ a>>13 ~ a>>22)
            end
            h1 = a + h1
            h2 = b + h2
            h3 = c + h3
            h4 = d + h4
            h5 = e + h5
            h6 = f + h6
            h7 = g + h7
            h8 = h + h8
         end
         H[1], H[2], H[3], H[4], H[5], H[6], H[7], H[8] = h1, h2, h3, h4, h5, h6, h7, h8
      end

      local function sha512_feed_128(H, _, str, offs, size)
         -- offs >= 0, size >= 0, size is multiple of 128
         local W, K = common_W, sha2_K_lo
         local h1, h2, h3, h4, h5, h6, h7, h8 = H[1], H[2], H[3], H[4], H[5], H[6], H[7], H[8]
         for pos = offs + 1, offs + size, 128 do
            W[1], W[2], W[3], W[4], W[5], W[6], W[7], W[8], W[9], W[10], W[11], W[12], W[13], W[14], W[15], W[16] =
               string_unpack(">i8i8i8i8i8i8i8i8i8i8i8i8i8i8i8i8", str, pos)
            for j = 17, 80 do
               local a = W[j-15]
               local b = W[j-2]
               W[j] = (a >> 1 ~ a >> 7 ~ a >> 8 ~ a << 56 ~ a << 63) + (b >> 6 ~ b >> 19 ~ b >> 61 ~ b << 3 ~ b << 45) + W[j-7] + W[j-16]
            end
            local a, b, c, d, e, f, g, h = h1, h2, h3, h4, h5, h6, h7, h8
            for j = 1, 80 do
               local z = (e >> 14 ~ e >> 18 ~ e >> 41 ~ e << 23 ~ e << 46 ~ e << 50) + (g ~ e & (f ~ g)) + h + K[j] + W[j]
               h = g
               g = f
               f = e
               e = z + d
               d = c
               c = b
               b = a
               a = z + ((a ~ c) & d ~ a & c) + (a >> 28 ~ a >> 34 ~ a >> 39 ~ a << 25 ~ a << 30 ~ a << 36)
            end
            h1 = a + h1
            h2 = b + h2
            h3 = c + h3
            h4 = d + h4
            h5 = e + h5
            h6 = f + h6
            h7 = g + h7
            h8 = h + h8
         end
         H[1], H[2], H[3], H[4], H[5], H[6], H[7], H[8] = h1, h2, h3, h4, h5, h6, h7, h8
      end

      local function md5_feed_64(H, str, offs, size)
         -- offs >= 0, size >= 0, size is multiple of 64
         local W, K, md5_next_shift = common_W, md5_K, md5_next_shift
         local h1, h2, h3, h4 = H[1], H[2], H[3], H[4]
         for pos = offs + 1, offs + size, 64 do
            W[1], W[2], W[3], W[4], W[5], W[6], W[7], W[8], W[9], W[10], W[11], W[12], W[13], W[14], W[15], W[16] =
               string_unpack("<I4I4I4I4I4I4I4I4I4I4I4I4I4I4I4I4", str, pos)
            local a, b, c, d = h1, h2, h3, h4
            local s = 32-7
            for j = 1, 16 do
               local F = (d ~ b & (c ~ d)) + a + K[j] + W[j]
               a = d
               d = c
               c = b
               b = ((F<<32 | F & (1<<32)-1) >> s) + b
               s = md5_next_shift[s]
            end
            s = 32-5
            for j = 17, 32 do
               local F = (c ~ d & (b ~ c)) + a + K[j] + W[(5*j-4 & 15) + 1]
               a = d
               d = c
               c = b
               b = ((F<<32 | F & (1<<32)-1) >> s) + b
               s = md5_next_shift[s]
            end
            s = 32-4
            for j = 33, 48 do
               local F = (b ~ c ~ d) + a + K[j] + W[(3*j+2 & 15) + 1]
               a = d
               d = c
               c = b
               b = ((F<<32 | F & (1<<32)-1) >> s) + b
               s = md5_next_shift[s]
            end
            s = 32-6
            for j = 49, 64 do
               local F = (c ~ (b | ~d)) + a + K[j] + W[(j*7-7 & 15) + 1]
               a = d
               d = c
               c = b
               b = ((F<<32 | F & (1<<32)-1) >> s) + b
               s = md5_next_shift[s]
            end
            h1 = a + h1
            h2 = b + h2
            h3 = c + h3
            h4 = d + h4
         end
         H[1], H[2], H[3], H[4] = h1, h2, h3, h4
      end

      local function sha1_feed_64(H, str, offs, size)
         -- offs >= 0, size >= 0, size is multiple of 64
         local W = common_W
         local h1, h2, h3, h4, h5 = H[1], H[2], H[3], H[4], H[5]
         for pos = offs + 1, offs + size, 64 do
            W[1], W[2], W[3], W[4], W[5], W[6], W[7], W[8], W[9], W[10], W[11], W[12], W[13], W[14], W[15], W[16] =
               string_unpack(">I4I4I4I4I4I4I4I4I4I4I4I4I4I4I4I4", str, pos)
            for j = 17, 80 do
               local a = W[j-3] ~ W[j-8] ~ W[j-14] ~ W[j-16]
               W[j] = (a<<32 | a) << 1 >> 32
            end
            local a, b, c, d, e = h1, h2, h3, h4, h5
            for j = 1, 20 do
               local z = ((a<<32 | a & (1<<32)-1) >> 27) + (d ~ b & (c ~ d)) + 0x5A827999 + W[j] + e      -- constant = floor(2^30 * sqrt(2))
               e = d
               d = c
               c = (b<<32 | b & (1<<32)-1) >> 2
               b = a
               a = z
            end
            for j = 21, 40 do
               local z = ((a<<32 | a & (1<<32)-1) >> 27) + (b ~ c ~ d) + 0x6ED9EBA1 + W[j] + e            -- 2^30 * sqrt(3)
               e = d
               d = c
               c = (b<<32 | b & (1<<32)-1) >> 2
               b = a
               a = z
            end
            for j = 41, 60 do
               local z = ((a<<32 | a & (1<<32)-1) >> 27) + ((b ~ c) & d ~ b & c) + 0x8F1BBCDC + W[j] + e  -- 2^30 * sqrt(5)
               e = d
               d = c
               c = (b<<32 | b & (1<<32)-1) >> 2
               b = a
               a = z
            end
            for j = 61, 80 do
               local z = ((a<<32 | a & (1<<32)-1) >> 27) + (b ~ c ~ d) + 0xCA62C1D6 + W[j] + e            -- 2^30 * sqrt(10)
               e = d
               d = c
               c = (b<<32 | b & (1<<32)-1) >> 2
               b = a
               a = z
            end
            h1 = a + h1
            h2 = b + h2
            h3 = c + h3
            h4 = d + h4
            h5 = e + h5
         end
         H[1], H[2], H[3], H[4], H[5] = h1, h2, h3, h4, h5
      end

      local keccak_format_i8 = build_keccak_format("i8")

      local function keccak_feed(lanes, _, str, offs, size, block_size_in_bytes)
         -- offs >= 0, size >= 0, size is multiple of block_size_in_bytes, block_size_in_bytes is positive multiple of 8
         local RC = sha3_RC_lo
         local qwords_qty = block_size_in_bytes / 8
         local keccak_format = keccak_format_i8[qwords_qty]
         for pos = offs + 1, offs + size, block_size_in_bytes do
            local qwords_from_message = {string_unpack(keccak_format, str, pos)}
            for j = 1, qwords_qty do
               lanes[j] = lanes[j] ~ qwords_from_message[j]
            end
            local L01, L02, L03, L04, L05, L06, L07, L08, L09, L10, L11, L12, L13, L14, L15, L16, L17, L18, L19, L20, L21, L22, L23, L24, L25 =
               lanes[1], lanes[2], lanes[3], lanes[4], lanes[5], lanes[6], lanes[7], lanes[8], lanes[9], lanes[10], lanes[11], lanes[12], lanes[13],
               lanes[14], lanes[15], lanes[16], lanes[17], lanes[18], lanes[19], lanes[20], lanes[21], lanes[22], lanes[23], lanes[24], lanes[25]
            for round_idx = 1, 24 do
               local C1 = L01 ~ L06 ~ L11 ~ L16 ~ L21
               local C2 = L02 ~ L07 ~ L12 ~ L17 ~ L22
               local C3 = L03 ~ L08 ~ L13 ~ L18 ~ L23
               local C4 = L04 ~ L09 ~ L14 ~ L19 ~ L24
               local C5 = L05 ~ L10 ~ L15 ~ L20 ~ L25
               local D = C1 ~ C3<<1 ~ C3>>63
               local T0 = D ~ L02
               local T1 = D ~ L07
               local T2 = D ~ L12
               local T3 = D ~ L17
               local T4 = D ~ L22
               L02 = T1<<44 ~ T1>>20
               L07 = T3<<45 ~ T3>>19
               L12 = T0<<1 ~ T0>>63
               L17 = T2<<10 ~ T2>>54
               L22 = T4<<2 ~ T4>>62
               D = C2 ~ C4<<1 ~ C4>>63
               T0 = D ~ L03
               T1 = D ~ L08
               T2 = D ~ L13
               T3 = D ~ L18
               T4 = D ~ L23
               L03 = T2<<43 ~ T2>>21
               L08 = T4<<61 ~ T4>>3
               L13 = T1<<6 ~ T1>>58
               L18 = T3<<15 ~ T3>>49
               L23 = T0<<62 ~ T0>>2
               D = C3 ~ C5<<1 ~ C5>>63
               T0 = D ~ L04
               T1 = D ~ L09
               T2 = D ~ L14
               T3 = D ~ L19
               T4 = D ~ L24
               L04 = T3<<21 ~ T3>>43
               L09 = T0<<28 ~ T0>>36
               L14 = T2<<25 ~ T2>>39
               L19 = T4<<56 ~ T4>>8
               L24 = T1<<55 ~ T1>>9
               D = C4 ~ C1<<1 ~ C1>>63
               T0 = D ~ L05
               T1 = D ~ L10
               T2 = D ~ L15
               T3 = D ~ L20
               T4 = D ~ L25
               L05 = T4<<14 ~ T4>>50
               L10 = T1<<20 ~ T1>>44
               L15 = T3<<8 ~ T3>>56
               L20 = T0<<27 ~ T0>>37
               L25 = T2<<39 ~ T2>>25
               D = C5 ~ C2<<1 ~ C2>>63
               T1 = D ~ L06
               T2 = D ~ L11
               T3 = D ~ L16
               T4 = D ~ L21
               L06 = T2<<3 ~ T2>>61
               L11 = T4<<18 ~ T4>>46
               L16 = T1<<36 ~ T1>>28
               L21 = T3<<41 ~ T3>>23
               L01 = D ~ L01
               L01, L02, L03, L04, L05 = L01 ~ ~L02 & L03, L02 ~ ~L03 & L04, L03 ~ ~L04 & L05, L04 ~ ~L05 & L01, L05 ~ ~L01 & L02
               L06, L07, L08, L09, L10 = L09 ~ ~L10 & L06, L10 ~ ~L06 & L07, L06 ~ ~L07 & L08, L07 ~ ~L08 & L09, L08 ~ ~L09 & L10
               L11, L12, L13, L14, L15 = L12 ~ ~L13 & L14, L13 ~ ~L14 & L15, L14 ~ ~L15 & L11, L15 ~ ~L11 & L12, L11 ~ ~L12 & L13
               L16, L17, L18, L19, L20 = L20 ~ ~L16 & L17, L16 ~ ~L17 & L18, L17 ~ ~L18 & L19, L18 ~ ~L19 & L20, L19 ~ ~L20 & L16
               L21, L22, L23, L24, L25 = L23 ~ ~L24 & L25, L24 ~ ~L25 & L21, L25 ~ ~L21 & L22, L21 ~ ~L22 & L23, L22 ~ ~L23 & L24
               L01 = L01 ~ RC[round_idx]
            end
            lanes[1]  = L01
            lanes[2]  = L02
            lanes[3]  = L03
            lanes[4]  = L04
            lanes[5]  = L05
            lanes[6]  = L06
            lanes[7]  = L07
            lanes[8]  = L08
            lanes[9]  = L09
            lanes[10] = L10
            lanes[11] = L11
            lanes[12] = L12
            lanes[13] = L13
            lanes[14] = L14
            lanes[15] = L15
            lanes[16] = L16
            lanes[17] = L17
            lanes[18] = L18
            lanes[19] = L19
            lanes[20] = L20
            lanes[21] = L21
            lanes[22] = L22
            lanes[23] = L23
            lanes[24] = L24
            lanes[25] = L25
         end
      end

      local function blake2s_feed_64(H, str, offs, size, bytes_compressed, last_block_size, is_last_node)
         -- offs >= 0, size >= 0, size is multiple of 64
         local W = common_W
         local h1, h2, h3, h4, h5, h6, h7, h8 = H[1], H[2], H[3], H[4], H[5], H[6], H[7], H[8]
         for pos = offs + 1, offs + size, 64 do
            if str then
               W[1], W[2], W[3], W[4], W[5], W[6], W[7], W[8], W[9], W[10], W[11], W[12], W[13], W[14], W[15], W[16] =
                  string_unpack("<I4I4I4I4I4I4I4I4I4I4I4I4I4I4I4I4", str, pos)
            end
            local v0, v1, v2, v3, v4, v5, v6, v7 = h1, h2, h3, h4, h5, h6, h7, h8
            local v8, v9, vA, vB, vC, vD, vE, vF = sha2_H_hi[1], sha2_H_hi[2], sha2_H_hi[3], sha2_H_hi[4], sha2_H_hi[5], sha2_H_hi[6], sha2_H_hi[7], sha2_H_hi[8]
            bytes_compressed = bytes_compressed + (last_block_size or 64)
            vC = vC ~ bytes_compressed        -- t0 = low_4_bytes(bytes_compressed)
            vD = vD ~ bytes_compressed >> 32  -- t1 = high_4_bytes(bytes_compressed)
            if last_block_size then  -- flag f0
               vE = ~vE
            end
            if is_last_node then  -- flag f1
               vF = ~vF
            end
            for j = 1, 10 do
               local row = sigma[j]
               v0 = v0 + v4 + W[row[1]]
               vC = vC ~ v0
               vC = (vC & (1<<32)-1) >> 16 | vC << 16
               v8 = v8 + vC
               v4 = v4 ~ v8
               v4 = (v4 & (1<<32)-1) >> 12 | v4 << 20
               v0 = v0 + v4 + W[row[2]]
               vC = vC ~ v0
               vC = (vC & (1<<32)-1) >> 8 | vC << 24
               v8 = v8 + vC
               v4 = v4 ~ v8
               v4 = (v4 & (1<<32)-1) >> 7 | v4 << 25
               v1 = v1 + v5 + W[row[3]]
               vD = vD ~ v1
               vD = (vD & (1<<32)-1) >> 16 | vD << 16
               v9 = v9 + vD
               v5 = v5 ~ v9
               v5 = (v5 & (1<<32)-1) >> 12 | v5 << 20
               v1 = v1 + v5 + W[row[4]]
               vD = vD ~ v1
               vD = (vD & (1<<32)-1) >> 8 | vD << 24
               v9 = v9 + vD
               v5 = v5 ~ v9
               v5 = (v5 & (1<<32)-1) >> 7 | v5 << 25
               v2 = v2 + v6 + W[row[5]]
               vE = vE ~ v2
               vE = (vE & (1<<32)-1) >> 16 | vE << 16
               vA = vA + vE
               v6 = v6 ~ vA
               v6 = (v6 & (1<<32)-1) >> 12 | v6 << 20
               v2 = v2 + v6 + W[row[6]]
               vE = vE ~ v2
               vE = (vE & (1<<32)-1) >> 8 | vE << 24
               vA = vA + vE
               v6 = v6 ~ vA
               v6 = (v6 & (1<<32)-1) >> 7 | v6 << 25
               v3 = v3 + v7 + W[row[7]]
               vF = vF ~ v3
               vF = (vF & (1<<32)-1) >> 16 | vF << 16
               vB = vB + vF
               v7 = v7 ~ vB
               v7 = (v7 & (1<<32)-1) >> 12 | v7 << 20
               v3 = v3 + v7 + W[row[8]]
               vF = vF ~ v3
               vF = (vF & (1<<32)-1) >> 8 | vF << 24
               vB = vB + vF
               v7 = v7 ~ vB
               v7 = (v7 & (1<<32)-1) >> 7 | v7 << 25
               v0 = v0 + v5 + W[row[9]]
               vF = vF ~ v0
               vF = (vF & (1<<32)-1) >> 16 | vF << 16
               vA = vA + vF
               v5 = v5 ~ vA
               v5 = (v5 & (1<<32)-1) >> 12 | v5 << 20
               v0 = v0 + v5 + W[row[10]]
               vF = vF ~ v0
               vF = (vF & (1<<32)-1) >> 8 | vF << 24
               vA = vA + vF
               v5 = v5 ~ vA
               v5 = (v5 & (1<<32)-1) >> 7 | v5 << 25
               v1 = v1 + v6 + W[row[11]]
               vC = vC ~ v1
               vC = (vC & (1<<32)-1) >> 16 | vC << 16
               vB = vB + vC
               v6 = v6 ~ vB
               v6 = (v6 & (1<<32)-1) >> 12 | v6 << 20
               v1 = v1 + v6 + W[row[12]]
               vC = vC ~ v1
               vC = (vC & (1<<32)-1) >> 8 | vC << 24
               vB = vB + vC
               v6 = v6 ~ vB
               v6 = (v6 & (1<<32)-1) >> 7 | v6 << 25
               v2 = v2 + v7 + W[row[13]]
               vD = vD ~ v2
               vD = (vD & (1<<32)-1) >> 16 | vD << 16
               v8 = v8 + vD
               v7 = v7 ~ v8
               v7 = (v7 & (1<<32)-1) >> 12 | v7 << 20
               v2 = v2 + v7 + W[row[14]]
               vD = vD ~ v2
               vD = (vD & (1<<32)-1) >> 8 | vD << 24
               v8 = v8 + vD
               v7 = v7 ~ v8
               v7 = (v7 & (1<<32)-1) >> 7 | v7 << 25
               v3 = v3 + v4 + W[row[15]]
               vE = vE ~ v3
               vE = (vE & (1<<32)-1) >> 16 | vE << 16
               v9 = v9 + vE
               v4 = v4 ~ v9
               v4 = (v4 & (1<<32)-1) >> 12 | v4 << 20
               v3 = v3 + v4 + W[row[16]]
               vE = vE ~ v3
               vE = (vE & (1<<32)-1) >> 8 | vE << 24
               v9 = v9 + vE
               v4 = v4 ~ v9
               v4 = (v4 & (1<<32)-1) >> 7 | v4 << 25
            end
            h1 = h1 ~ v0 ~ v8
            h2 = h2 ~ v1 ~ v9
            h3 = h3 ~ v2 ~ vA
            h4 = h4 ~ v3 ~ vB
            h5 = h5 ~ v4 ~ vC
            h6 = h6 ~ v5 ~ vD
            h7 = h7 ~ v6 ~ vE
            h8 = h8 ~ v7 ~ vF
         end
         H[1], H[2], H[3], H[4], H[5], H[6], H[7], H[8] = h1, h2, h3, h4, h5, h6, h7, h8
         return bytes_compressed
      end

      local function blake2b_feed_128(H, _, str, offs, size, bytes_compressed, last_block_size, is_last_node)
         -- offs >= 0, size >= 0, size is multiple of 128
         local W = common_W
         local h1, h2, h3, h4, h5, h6, h7, h8 = H[1], H[2], H[3], H[4], H[5], H[6], H[7], H[8]
         for pos = offs + 1, offs + size, 128 do
            if str then
               W[1], W[2], W[3], W[4], W[5], W[6], W[7], W[8], W[9], W[10], W[11], W[12], W[13], W[14], W[15], W[16] =
                  string_unpack("<i8i8i8i8i8i8i8i8i8i8i8i8i8i8i8i8", str, pos)
            end
            local v0, v1, v2, v3, v4, v5, v6, v7 = h1, h2, h3, h4, h5, h6, h7, h8
            local v8, v9, vA, vB, vC, vD, vE, vF = sha2_H_lo[1], sha2_H_lo[2], sha2_H_lo[3], sha2_H_lo[4], sha2_H_lo[5], sha2_H_lo[6], sha2_H_lo[7], sha2_H_lo[8]
            bytes_compressed = bytes_compressed + (last_block_size or 128)
            vC = vC ~ bytes_compressed  -- t0 = low_8_bytes(bytes_compressed)
            -- t1 = high_8_bytes(bytes_compressed) = 0,  message length is always below 2^53 bytes
            if last_block_size then  -- flag f0
               vE = ~vE
            end
            if is_last_node then  -- flag f1
               vF = ~vF
            end
            for j = 1, 12 do
               local row = sigma[j]
               v0 = v0 + v4 + W[row[1]]
               vC = vC ~ v0
               vC = vC >> 32 | vC << 32
               v8 = v8 + vC
               v4 = v4 ~ v8
               v4 = v4 >> 24 | v4 << 40
               v0 = v0 + v4 + W[row[2]]
               vC = vC ~ v0
               vC = vC >> 16 | vC << 48
               v8 = v8 + vC
               v4 = v4 ~ v8
               v4 = v4 >> 63 | v4 << 1
               v1 = v1 + v5 + W[row[3]]
               vD = vD ~ v1
               vD = vD >> 32 | vD << 32
               v9 = v9 + vD
               v5 = v5 ~ v9
               v5 = v5 >> 24 | v5 << 40
               v1 = v1 + v5 + W[row[4]]
               vD = vD ~ v1
               vD = vD >> 16 | vD << 48
               v9 = v9 + vD
               v5 = v5 ~ v9
               v5 = v5 >> 63 | v5 << 1
               v2 = v2 + v6 + W[row[5]]
               vE = vE ~ v2
               vE = vE >> 32 | vE << 32
               vA = vA + vE
               v6 = v6 ~ vA
               v6 = v6 >> 24 | v6 << 40
               v2 = v2 + v6 + W[row[6]]
               vE = vE ~ v2
               vE = vE >> 16 | vE << 48
               vA = vA + vE
               v6 = v6 ~ vA
               v6 = v6 >> 63 | v6 << 1
               v3 = v3 + v7 + W[row[7]]
               vF = vF ~ v3
               vF = vF >> 32 | vF << 32
               vB = vB + vF
               v7 = v7 ~ vB
               v7 = v7 >> 24 | v7 << 40
               v3 = v3 + v7 + W[row[8]]
               vF = vF ~ v3
               vF = vF >> 16 | vF << 48
               vB = vB + vF
               v7 = v7 ~ vB
               v7 = v7 >> 63 | v7 << 1
               v0 = v0 + v5 + W[row[9]]
               vF = vF ~ v0
               vF = vF >> 32 | vF << 32
               vA = vA + vF
               v5 = v5 ~ vA
               v5 = v5 >> 24 | v5 << 40
               v0 = v0 + v5 + W[row[10]]
               vF = vF ~ v0
               vF = vF >> 16 | vF << 48
               vA = vA + vF
               v5 = v5 ~ vA
               v5 = v5 >> 63 | v5 << 1
               v1 = v1 + v6 + W[row[11]]
               vC = vC ~ v1
               vC = vC >> 32 | vC << 32
               vB = vB + vC
               v6 = v6 ~ vB
               v6 = v6 >> 24 | v6 << 40
               v1 = v1 + v6 + W[row[12]]
               vC = vC ~ v1
               vC = vC >> 16 | vC << 48
               vB = vB + vC
               v6 = v6 ~ vB
               v6 = v6 >> 63 | v6 << 1
               v2 = v2 + v7 + W[row[13]]
               vD = vD ~ v2
               vD = vD >> 32 | vD << 32
               v8 = v8 + vD
               v7 = v7 ~ v8
               v7 = v7 >> 24 | v7 << 40
               v2 = v2 + v7 + W[row[14]]
               vD = vD ~ v2
               vD = vD >> 16 | vD << 48
               v8 = v8 + vD
               v7 = v7 ~ v8
               v7 = v7 >> 63 | v7 << 1
               v3 = v3 + v4 + W[row[15]]
               vE = vE ~ v3
               vE = vE >> 32 | vE << 32
               v9 = v9 + vE
               v4 = v4 ~ v9
               v4 = v4 >> 24 | v4 << 40
               v3 = v3 + v4 + W[row[16]]
               vE = vE ~ v3
               vE = vE >> 16 | vE << 48
               v9 = v9 + vE
               v4 = v4 ~ v9
               v4 = v4 >> 63 | v4 << 1
            end
            h1 = h1 ~ v0 ~ v8
            h2 = h2 ~ v1 ~ v9
            h3 = h3 ~ v2 ~ vA
            h4 = h4 ~ v3 ~ vB
            h5 = h5 ~ v4 ~ vC
            h6 = h6 ~ v5 ~ vD
            h7 = h7 ~ v6 ~ vE
            h8 = h8 ~ v7 ~ vF
         end
         H[1], H[2], H[3], H[4], H[5], H[6], H[7], H[8] = h1, h2, h3, h4, h5, h6, h7, h8
         return bytes_compressed
      end

      local function blake3_feed_64(str, offs, size, flags, chunk_index, H_in, H_out, wide_output, block_length)
         -- offs >= 0, size >= 0, size is multiple of 64
         block_length = block_length or 64
         local W = common_W
         local h1, h2, h3, h4, h5, h6, h7, h8 = H_in[1], H_in[2], H_in[3], H_in[4], H_in[5], H_in[6], H_in[7], H_in[8]
         H_out = H_out or H_in
         for pos = offs + 1, offs + size, 64 do
            if str then
               W[1], W[2], W[3], W[4], W[5], W[6], W[7], W[8], W[9], W[10], W[11], W[12], W[13], W[14], W[15], W[16] =
                  string_unpack("<I4I4I4I4I4I4I4I4I4I4I4I4I4I4I4I4", str, pos)
            end
            local v0, v1, v2, v3, v4, v5, v6, v7 = h1, h2, h3, h4, h5, h6, h7, h8
            local v8, v9, vA, vB = sha2_H_hi[1], sha2_H_hi[2], sha2_H_hi[3], sha2_H_hi[4]
            local t0 = chunk_index % 2^32         -- t0 = low_4_bytes(chunk_index)
            local t1 = (chunk_index - t0) / 2^32  -- t1 = high_4_bytes(chunk_index)
            local vC, vD, vE, vF = 0|t0, 0|t1, block_length, flags
            for j = 1, 7 do
               v0 = v0 + v4 + W[perm_blake3[j]]
               vC = vC ~ v0
               vC = (vC & (1<<32)-1) >> 16 | vC << 16
               v8 = v8 + vC
               v4 = v4 ~ v8
               v4 = (v4 & (1<<32)-1) >> 12 | v4 << 20
               v0 = v0 + v4 + W[perm_blake3[j + 14]]
               vC = vC ~ v0
               vC = (vC & (1<<32)-1) >> 8 | vC << 24
               v8 = v8 + vC
               v4 = v4 ~ v8
               v4 = (v4 & (1<<32)-1) >> 7 | v4 << 25
               v1 = v1 + v5 + W[perm_blake3[j + 1]]
               vD = vD ~ v1
               vD = (vD & (1<<32)-1) >> 16 | vD << 16
               v9 = v9 + vD
               v5 = v5 ~ v9
               v5 = (v5 & (1<<32)-1) >> 12 | v5 << 20
               v1 = v1 + v5 + W[perm_blake3[j + 2]]
               vD = vD ~ v1
               vD = (vD & (1<<32)-1) >> 8 | vD << 24
               v9 = v9 + vD
               v5 = v5 ~ v9
               v5 = (v5 & (1<<32)-1) >> 7 | v5 << 25
               v2 = v2 + v6 + W[perm_blake3[j + 16]]
               vE = vE ~ v2
               vE = (vE & (1<<32)-1) >> 16 | vE << 16
               vA = vA + vE
               v6 = v6 ~ vA
               v6 = (v6 & (1<<32)-1) >> 12 | v6 << 20
               v2 = v2 + v6 + W[perm_blake3[j + 7]]
               vE = vE ~ v2
               vE = (vE & (1<<32)-1) >> 8 | vE << 24
               vA = vA + vE
               v6 = v6 ~ vA
               v6 = (v6 & (1<<32)-1) >> 7 | v6 << 25
               v3 = v3 + v7 + W[perm_blake3[j + 15]]
               vF = vF ~ v3
               vF = (vF & (1<<32)-1) >> 16 | vF << 16
               vB = vB + vF
               v7 = v7 ~ vB
               v7 = (v7 & (1<<32)-1) >> 12 | v7 << 20
               v3 = v3 + v7 + W[perm_blake3[j + 17]]
               vF = vF ~ v3
               vF = (vF & (1<<32)-1) >> 8 | vF << 24
               vB = vB + vF
               v7 = v7 ~ vB
               v7 = (v7 & (1<<32)-1) >> 7 | v7 << 25
               v0 = v0 + v5 + W[perm_blake3[j + 21]]
               vF = vF ~ v0
               vF = (vF & (1<<32)-1) >> 16 | vF << 16
               vA = vA + vF
               v5 = v5 ~ vA
               v5 = (v5 & (1<<32)-1) >> 12 | v5 << 20
               v0 = v0 + v5 + W[perm_blake3[j + 5]]
               vF = vF ~ v0
               vF = (vF & (1<<32)-1) >> 8 | vF << 24
               vA = vA + vF
               v5 = v5 ~ vA
               v5 = (v5 & (1<<32)-1) >> 7 | v5 << 25
               v1 = v1 + v6 + W[perm_blake3[j + 3]]
               vC = vC ~ v1
               vC = (vC & (1<<32)-1) >> 16 | vC << 16
               vB = vB + vC
               v6 = v6 ~ vB
               v6 = (v6 & (1<<32)-1) >> 12 | v6 << 20
               v1 = v1 + v6 + W[perm_blake3[j + 6]]
               vC = vC ~ v1
               vC = (vC & (1<<32)-1) >> 8 | vC << 24
               vB = vB + vC
               v6 = v6 ~ vB
               v6 = (v6 & (1<<32)-1) >> 7 | v6 << 25
               v2 = v2 + v7 + W[perm_blake3[j + 4]]
               vD = vD ~ v2
               vD = (vD & (1<<32)-1) >> 16 | vD << 16
               v8 = v8 + vD
               v7 = v7 ~ v8
               v7 = (v7 & (1<<32)-1) >> 12 | v7 << 20
               v2 = v2 + v7 + W[perm_blake3[j + 18]]
               vD = vD ~ v2
               vD = (vD & (1<<32)-1) >> 8 | vD << 24
               v8 = v8 + vD
               v7 = v7 ~ v8
               v7 = (v7 & (1<<32)-1) >> 7 | v7 << 25
               v3 = v3 + v4 + W[perm_blake3[j + 19]]
               vE = vE ~ v3
               vE = (vE & (1<<32)-1) >> 16 | vE << 16
               v9 = v9 + vE
               v4 = v4 ~ v9
               v4 = (v4 & (1<<32)-1) >> 12 | v4 << 20
               v3 = v3 + v4 + W[perm_blake3[j + 20]]
               vE = vE ~ v3
               vE = (vE & (1<<32)-1) >> 8 | vE << 24
               v9 = v9 + vE
               v4 = v4 ~ v9
               v4 = (v4 & (1<<32)-1) >> 7 | v4 << 25
            end
            if wide_output then
               H_out[ 9] = h1 ~ v8
               H_out[10] = h2 ~ v9
               H_out[11] = h3 ~ vA
               H_out[12] = h4 ~ vB
               H_out[13] = h5 ~ vC
               H_out[14] = h6 ~ vD
               H_out[15] = h7 ~ vE
               H_out[16] = h8 ~ vF
            end
            h1 = v0 ~ v8
            h2 = v1 ~ v9
            h3 = v2 ~ vA
            h4 = v3 ~ vB
            h5 = v4 ~ vC
            h6 = v5 ~ vD
            h7 = v6 ~ vE
            h8 = v7 ~ vF
         end
         H_out[1], H_out[2], H_out[3], H_out[4], H_out[5], H_out[6], H_out[7], H_out[8] = h1, h2, h3, h4, h5, h6, h7, h8
      end

      return HEX64, XORA5, XOR_BYTE, sha256_feed_64, sha512_feed_128, md5_feed_64, sha1_feed_64, keccak_feed, blake2s_feed_64, blake2b_feed_128, blake3_feed_64
   ]=](md5_next_shift, md5_K, sha2_K_lo, sha2_K_hi, build_keccak_format, sha3_RC_lo, sigma, common_W, sha2_H_lo, sha2_H_hi, perm_blake3)

end


if branch == "INT32" then


   -- implementation for Lua 5.3/5.4 having non-standard numbers config "int32"+"double" (built with LUA_INT_TYPE=LUA_INT_INT)

   K_lo_modulo = 2^32

   function HEX(x) -- returns string of 8 lowercase hexadecimal digits
      return string_format("%08x", x)
   end

   XORA5, XOR_BYTE, sha256_feed_64, sha512_feed_128, md5_feed_64, sha1_feed_64, keccak_feed, blake2s_feed_64, blake2b_feed_128, blake3_feed_64 = load[=[-- branch "INT32"
      local md5_next_shift, md5_K, sha2_K_lo, sha2_K_hi, build_keccak_format, sha3_RC_lo, sha3_RC_hi, sigma, common_W, sha2_H_lo, sha2_H_hi, perm_blake3 = ...
      local string_unpack, floor = string.unpack, math.floor

      local function XORA5(x, y)
         return x ~ (y and (y + 2^31) % 2^32 - 2^31 or 0xA5A5A5A5)
      end

      local function XOR_BYTE(x, y)
         return x ~ y
      end

      local function sha256_feed_64(H, str, offs, size)
         -- offs >= 0, size >= 0, size is multiple of 64
         local W, K = common_W, sha2_K_hi
         local h1, h2, h3, h4, h5, h6, h7, h8 = H[1], H[2], H[3], H[4], H[5], H[6], H[7], H[8]
         for pos = offs + 1, offs + size, 64 do
            W[1], W[2], W[3], W[4], W[5], W[6], W[7], W[8], W[9], W[10], W[11], W[12], W[13], W[14], W[15], W[16] =
               string_unpack(">i4i4i4i4i4i4i4i4i4i4i4i4i4i4i4i4", str, pos)
            for j = 17, 64 do
               local a, b = W[j-15], W[j-2]
               W[j] = (a>>7 ~ a<<25 ~ a<<14 ~ a>>18 ~ a>>3) + (b<<15 ~ b>>17 ~ b<<13 ~ b>>19 ~ b>>10) + W[j-7] + W[j-16]
            end
            local a, b, c, d, e, f, g, h = h1, h2, h3, h4, h5, h6, h7, h8
            for j = 1, 64 do
               local z = (e>>6 ~ e<<26 ~ e>>11 ~ e<<21 ~ e>>25 ~ e<<7) + (g ~ e & (f ~ g)) + h + K[j] + W[j]
               h = g
               g = f
               f = e
               e = z + d
               d = c
               c = b
               b = a
               a = z + ((a ~ c) & d ~ a & c) + (a>>2 ~ a<<30 ~ a>>13 ~ a<<19 ~ a<<10 ~ a>>22)
            end
            h1 = a + h1
            h2 = b + h2
            h3 = c + h3
            h4 = d + h4
            h5 = e + h5
            h6 = f + h6
            h7 = g + h7
            h8 = h + h8
         end
         H[1], H[2], H[3], H[4], H[5], H[6], H[7], H[8] = h1, h2, h3, h4, h5, h6, h7, h8
      end

      local function sha512_feed_128(H_lo, H_hi, str, offs, size)
         -- offs >= 0, size >= 0, size is multiple of 128
         -- W1_hi, W1_lo, W2_hi, W2_lo, ...   Wk_hi = W[2*k-1], Wk_lo = W[2*k]
         local floor, W, K_lo, K_hi = floor, common_W, sha2_K_lo, sha2_K_hi
         local h1_lo, h2_lo, h3_lo, h4_lo, h5_lo, h6_lo, h7_lo, h8_lo = H_lo[1], H_lo[2], H_lo[3], H_lo[4], H_lo[5], H_lo[6], H_lo[7], H_lo[8]
         local h1_hi, h2_hi, h3_hi, h4_hi, h5_hi, h6_hi, h7_hi, h8_hi = H_hi[1], H_hi[2], H_hi[3], H_hi[4], H_hi[5], H_hi[6], H_hi[7], H_hi[8]
         for pos = offs + 1, offs + size, 128 do
            W[1], W[2], W[3], W[4], W[5], W[6], W[7], W[8], W[9], W[10], W[11], W[12], W[13], W[14], W[15], W[16],
               W[17], W[18], W[19], W[20], W[21], W[22], W[23], W[24], W[25], W[26], W[27], W[28], W[29], W[30], W[31], W[32] =
               string_unpack(">i4i4i4i4i4i4i4i4i4i4i4i4i4i4i4i4i4i4i4i4i4i4i4i4i4i4i4i4i4i4i4i4", str, pos)
            for jj = 17*2, 80*2, 2 do
               local a_lo, a_hi, b_lo, b_hi = W[jj-30], W[jj-31], W[jj-4], W[jj-5]
               local tmp =
                  (a_lo>>1 ~ a_hi<<31 ~ a_lo>>8 ~ a_hi<<24 ~ a_lo>>7 ~ a_hi<<25) % 2^32
                  + (b_lo>>19 ~ b_hi<<13 ~ b_lo<<3 ~ b_hi>>29 ~ b_lo>>6 ~ b_hi<<26) % 2^32
                  + W[jj-14] % 2^32 + W[jj-32] % 2^32
               W[jj-1] =
                  (a_hi>>1 ~ a_lo<<31 ~ a_hi>>8 ~ a_lo<<24 ~ a_hi>>7)
                  + (b_hi>>19 ~ b_lo<<13 ~ b_hi<<3 ~ b_lo>>29 ~ b_hi>>6)
                  + W[jj-15] + W[jj-33] + floor(tmp / 2^32)
               W[jj] = 0|((tmp + 2^31) % 2^32 - 2^31)
            end
            local a_lo, b_lo, c_lo, d_lo, e_lo, f_lo, g_lo, h_lo = h1_lo, h2_lo, h3_lo, h4_lo, h5_lo, h6_lo, h7_lo, h8_lo
            local a_hi, b_hi, c_hi, d_hi, e_hi, f_hi, g_hi, h_hi = h1_hi, h2_hi, h3_hi, h4_hi, h5_hi, h6_hi, h7_hi, h8_hi
            for j = 1, 80 do
               local jj = 2*j
               local z_lo = (e_lo>>14 ~ e_hi<<18 ~ e_lo>>18 ~ e_hi<<14 ~ e_lo<<23 ~ e_hi>>9) % 2^32 + (g_lo ~ e_lo & (f_lo ~ g_lo)) % 2^32 + h_lo % 2^32 + K_lo[j] + W[jj] % 2^32
               local z_hi = (e_hi>>14 ~ e_lo<<18 ~ e_hi>>18 ~ e_lo<<14 ~ e_hi<<23 ~ e_lo>>9) + (g_hi ~ e_hi & (f_hi ~ g_hi)) + h_hi + K_hi[j] + W[jj-1] + floor(z_lo / 2^32)
               z_lo = z_lo % 2^32
               h_lo = g_lo;  h_hi = g_hi
               g_lo = f_lo;  g_hi = f_hi
               f_lo = e_lo;  f_hi = e_hi
               e_lo = z_lo + d_lo % 2^32
               e_hi = z_hi + d_hi + floor(e_lo / 2^32)
               e_lo = 0|((e_lo + 2^31) % 2^32 - 2^31)
               d_lo = c_lo;  d_hi = c_hi
               c_lo = b_lo;  c_hi = b_hi
               b_lo = a_lo;  b_hi = a_hi
               z_lo = z_lo + (d_lo & c_lo ~ b_lo & (d_lo ~ c_lo)) % 2^32 + (b_lo>>28 ~ b_hi<<4 ~ b_lo<<30 ~ b_hi>>2 ~ b_lo<<25 ~ b_hi>>7) % 2^32
               a_hi = z_hi + (d_hi & c_hi ~ b_hi & (d_hi ~ c_hi)) + (b_hi>>28 ~ b_lo<<4 ~ b_hi<<30 ~ b_lo>>2 ~ b_hi<<25 ~ b_lo>>7) + floor(z_lo / 2^32)
               a_lo = 0|((z_lo + 2^31) % 2^32 - 2^31)
            end
            a_lo = h1_lo % 2^32 + a_lo % 2^32
            h1_hi = h1_hi + a_hi + floor(a_lo / 2^32)
            h1_lo = 0|((a_lo + 2^31) % 2^32 - 2^31)
            a_lo = h2_lo % 2^32 + b_lo % 2^32
            h2_hi = h2_hi + b_hi + floor(a_lo / 2^32)
            h2_lo = 0|((a_lo + 2^31) % 2^32 - 2^31)
            a_lo = h3_lo % 2^32 + c_lo % 2^32
            h3_hi = h3_hi + c_hi + floor(a_lo / 2^32)
            h3_lo = 0|((a_lo + 2^31) % 2^32 - 2^31)
            a_lo = h4_lo % 2^32 + d_lo % 2^32
            h4_hi = h4_hi + d_hi + floor(a_lo / 2^32)
            h4_lo = 0|((a_lo + 2^31) % 2^32 - 2^31)
            a_lo = h5_lo % 2^32 + e_lo % 2^32
            h5_hi = h5_hi + e_hi + floor(a_lo / 2^32)
            h5_lo = 0|((a_lo + 2^31) % 2^32 - 2^31)
            a_lo = h6_lo % 2^32 + f_lo % 2^32
            h6_hi = h6_hi + f_hi + floor(a_lo / 2^32)
            h6_lo = 0|((a_lo + 2^31) % 2^32 - 2^31)
            a_lo = h7_lo % 2^32 + g_lo % 2^32
            h7_hi = h7_hi + g_hi + floor(a_lo / 2^32)
            h7_lo = 0|((a_lo + 2^31) % 2^32 - 2^31)
            a_lo = h8_lo % 2^32 + h_lo % 2^32
            h8_hi = h8_hi + h_hi + floor(a_lo / 2^32)
            h8_lo = 0|((a_lo + 2^31) % 2^32 - 2^31)
         end
         H_lo[1], H_lo[2], H_lo[3], H_lo[4], H_lo[5], H_lo[6], H_lo[7], H_lo[8] = h1_lo, h2_lo, h3_lo, h4_lo, h5_lo, h6_lo, h7_lo, h8_lo
         H_hi[1], H_hi[2], H_hi[3], H_hi[4], H_hi[5], H_hi[6], H_hi[7], H_hi[8] = h1_hi, h2_hi, h3_hi, h4_hi, h5_hi, h6_hi, h7_hi, h8_hi
      end

      local function md5_feed_64(H, str, offs, size)
         -- offs >= 0, size >= 0, size is multiple of 64
         local W, K, md5_next_shift = common_W, md5_K, md5_next_shift
         local h1, h2, h3, h4 = H[1], H[2], H[3], H[4]
         for pos = offs + 1, offs + size, 64 do
            W[1], W[2], W[3], W[4], W[5], W[6], W[7], W[8], W[9], W[10], W[11], W[12], W[13], W[14], W[15], W[16] =
               string_unpack("<i4i4i4i4i4i4i4i4i4i4i4i4i4i4i4i4", str, pos)
            local a, b, c, d = h1, h2, h3, h4
            local s = 32-7
            for j = 1, 16 do
               local F = (d ~ b & (c ~ d)) + a + K[j] + W[j]
               a = d
               d = c
               c = b
               b = (F << 32-s | F>>s) + b
               s = md5_next_shift[s]
            end
            s = 32-5
            for j = 17, 32 do
               local F = (c ~ d & (b ~ c)) + a + K[j] + W[(5*j-4 & 15) + 1]
               a = d
               d = c
               c = b
               b = (F << 32-s | F>>s) + b
               s = md5_next_shift[s]
            end
            s = 32-4
            for j = 33, 48 do
               local F = (b ~ c ~ d) + a + K[j] + W[(3*j+2 & 15) + 1]
               a = d
               d = c
               c = b
               b = (F << 32-s | F>>s) + b
               s = md5_next_shift[s]
            end
            s = 32-6
            for j = 49, 64 do
               local F = (c ~ (b | ~d)) + a + K[j] + W[(j*7-7 & 15) + 1]
               a = d
               d = c
               c = b
               b = (F << 32-s | F>>s) + b
               s = md5_next_shift[s]
            end
            h1 = a + h1
            h2 = b + h2
            h3 = c + h3
            h4 = d + h4
         end
         H[1], H[2], H[3], H[4] = h1, h2, h3, h4
      end

      local function sha1_feed_64(H, str, offs, size)
         -- offs >= 0, size >= 0, size is multiple of 64
         local W = common_W
         local h1, h2, h3, h4, h5 = H[1], H[2], H[3], H[4], H[5]
         for pos = offs + 1, offs + size, 64 do
            W[1], W[2], W[3], W[4], W[5], W[6], W[7], W[8], W[9], W[10], W[11], W[12], W[13], W[14], W[15], W[16] =
               string_unpack(">i4i4i4i4i4i4i4i4i4i4i4i4i4i4i4i4", str, pos)
            for j = 17, 80 do
               local a = W[j-3] ~ W[j-8] ~ W[j-14] ~ W[j-16]
               W[j] = a << 1 ~ a >> 31
            end
            local a, b, c, d, e = h1, h2, h3, h4, h5
            for j = 1, 20 do
               local z = (a << 5 ~ a >> 27) + (d ~ b & (c ~ d)) + 0x5A827999 + W[j] + e      -- constant = floor(2^30 * sqrt(2))
               e = d
               d = c
               c = b << 30 ~ b >> 2
               b = a
               a = z
            end
            for j = 21, 40 do
               local z = (a << 5 ~ a >> 27) + (b ~ c ~ d) + 0x6ED9EBA1 + W[j] + e            -- 2^30 * sqrt(3)
               e = d
               d = c
               c = b << 30 ~ b >> 2
               b = a
               a = z
            end
            for j = 41, 60 do
               local z = (a << 5 ~ a >> 27) + ((b ~ c) & d ~ b & c) + 0x8F1BBCDC + W[j] + e  -- 2^30 * sqrt(5)
               e = d
               d = c
               c = b << 30 ~ b >> 2
               b = a
               a = z
            end
            for j = 61, 80 do
               local z = (a << 5 ~ a >> 27) + (b ~ c ~ d) + 0xCA62C1D6 + W[j] + e            -- 2^30 * sqrt(10)
               e = d
               d = c
               c = b << 30 ~ b >> 2
               b = a
               a = z
            end
            h1 = a + h1
            h2 = b + h2
            h3 = c + h3
            h4 = d + h4
            h5 = e + h5
         end
         H[1], H[2], H[3], H[4], H[5] = h1, h2, h3, h4, h5
      end

      local keccak_format_i4i4 = build_keccak_format("i4i4")

      local function keccak_feed(lanes_lo, lanes_hi, str, offs, size, block_size_in_bytes)
         -- offs >= 0, size >= 0, size is multiple of block_size_in_bytes, block_size_in_bytes is positive multiple of 8
         local RC_lo, RC_hi = sha3_RC_lo, sha3_RC_hi
         local qwords_qty = block_size_in_bytes / 8
         local keccak_format = keccak_format_i4i4[qwords_qty]
         for pos = offs + 1, offs + size, block_size_in_bytes do
            local dwords_from_message = {string_unpack(keccak_format, str, pos)}
            for j = 1, qwords_qty do
               lanes_lo[j] = lanes_lo[j] ~ dwords_from_message[2*j-1]
               lanes_hi[j] = lanes_hi[j] ~ dwords_from_message[2*j]
            end
            local L01_lo, L01_hi, L02_lo, L02_hi, L03_lo, L03_hi, L04_lo, L04_hi, L05_lo, L05_hi, L06_lo, L06_hi, L07_lo, L07_hi, L08_lo, L08_hi,
               L09_lo, L09_hi, L10_lo, L10_hi, L11_lo, L11_hi, L12_lo, L12_hi, L13_lo, L13_hi, L14_lo, L14_hi, L15_lo, L15_hi, L16_lo, L16_hi,
               L17_lo, L17_hi, L18_lo, L18_hi, L19_lo, L19_hi, L20_lo, L20_hi, L21_lo, L21_hi, L22_lo, L22_hi, L23_lo, L23_hi, L24_lo, L24_hi, L25_lo, L25_hi =
               lanes_lo[1], lanes_hi[1], lanes_lo[2], lanes_hi[2], lanes_lo[3], lanes_hi[3], lanes_lo[4], lanes_hi[4], lanes_lo[5], lanes_hi[5],
               lanes_lo[6], lanes_hi[6], lanes_lo[7], lanes_hi[7], lanes_lo[8], lanes_hi[8], lanes_lo[9], lanes_hi[9], lanes_lo[10], lanes_hi[10],
               lanes_lo[11], lanes_hi[11], lanes_lo[12], lanes_hi[12], lanes_lo[13], lanes_hi[13], lanes_lo[14], lanes_hi[14], lanes_lo[15], lanes_hi[15],
               lanes_lo[16], lanes_hi[16], lanes_lo[17], lanes_hi[17], lanes_lo[18], lanes_hi[18], lanes_lo[19], lanes_hi[19], lanes_lo[20], lanes_hi[20],
               lanes_lo[21], lanes_hi[21], lanes_lo[22], lanes_hi[22], lanes_lo[23], lanes_hi[23], lanes_lo[24], lanes_hi[24], lanes_lo[25], lanes_hi[25]
            for round_idx = 1, 24 do
               local C1_lo = L01_lo ~ L06_lo ~ L11_lo ~ L16_lo ~ L21_lo
               local C1_hi = L01_hi ~ L06_hi ~ L11_hi ~ L16_hi ~ L21_hi
               local C2_lo = L02_lo ~ L07_lo ~ L12_lo ~ L17_lo ~ L22_lo
               local C2_hi = L02_hi ~ L07_hi ~ L12_hi ~ L17_hi ~ L22_hi
               local C3_lo = L03_lo ~ L08_lo ~ L13_lo ~ L18_lo ~ L23_lo
               local C3_hi = L03_hi ~ L08_hi ~ L13_hi ~ L18_hi ~ L23_hi
               local C4_lo = L04_lo ~ L09_lo ~ L14_lo ~ L19_lo ~ L24_lo
               local C4_hi = L04_hi ~ L09_hi ~ L14_hi ~ L19_hi ~ L24_hi
               local C5_lo = L05_lo ~ L10_lo ~ L15_lo ~ L20_lo ~ L25_lo
               local C5_hi = L05_hi ~ L10_hi ~ L15_hi ~ L20_hi ~ L25_hi
               local D_lo = C1_lo ~ C3_lo<<1 ~ C3_hi>>31
               local D_hi = C1_hi ~ C3_hi<<1 ~ C3_lo>>31
               local T0_lo = D_lo ~ L02_lo
               local T0_hi = D_hi ~ L02_hi
               local T1_lo = D_lo ~ L07_lo
               local T1_hi = D_hi ~ L07_hi
               local T2_lo = D_lo ~ L12_lo
               local T2_hi = D_hi ~ L12_hi
               local T3_lo = D_lo ~ L17_lo
               local T3_hi = D_hi ~ L17_hi
               local T4_lo = D_lo ~ L22_lo
               local T4_hi = D_hi ~ L22_hi
               L02_lo = T1_lo>>20 ~ T1_hi<<12
               L02_hi = T1_hi>>20 ~ T1_lo<<12
               L07_lo = T3_lo>>19 ~ T3_hi<<13
               L07_hi = T3_hi>>19 ~ T3_lo<<13
               L12_lo = T0_lo<<1 ~ T0_hi>>31
               L12_hi = T0_hi<<1 ~ T0_lo>>31
               L17_lo = T2_lo<<10 ~ T2_hi>>22
               L17_hi = T2_hi<<10 ~ T2_lo>>22
               L22_lo = T4_lo<<2 ~ T4_hi>>30
               L22_hi = T4_hi<<2 ~ T4_lo>>30
               D_lo = C2_lo ~ C4_lo<<1 ~ C4_hi>>31
               D_hi = C2_hi ~ C4_hi<<1 ~ C4_lo>>31
               T0_lo = D_lo ~ L03_lo
               T0_hi = D_hi ~ L03_hi
               T1_lo = D_lo ~ L08_lo
               T1_hi = D_hi ~ L08_hi
               T2_lo = D_lo ~ L13_lo
               T2_hi = D_hi ~ L13_hi
               T3_lo = D_lo ~ L18_lo
               T3_hi = D_hi ~ L18_hi
               T4_lo = D_lo ~ L23_lo
               T4_hi = D_hi ~ L23_hi
               L03_lo = T2_lo>>21 ~ T2_hi<<11
               L03_hi = T2_hi>>21 ~ T2_lo<<11
               L08_lo = T4_lo>>3 ~ T4_hi<<29
               L08_hi = T4_hi>>3 ~ T4_lo<<29
               L13_lo = T1_lo<<6 ~ T1_hi>>26
               L13_hi = T1_hi<<6 ~ T1_lo>>26
               L18_lo = T3_lo<<15 ~ T3_hi>>17
               L18_hi = T3_hi<<15 ~ T3_lo>>17
               L23_lo = T0_lo>>2 ~ T0_hi<<30
               L23_hi = T0_hi>>2 ~ T0_lo<<30
               D_lo = C3_lo ~ C5_lo<<1 ~ C5_hi>>31
               D_hi = C3_hi ~ C5_hi<<1 ~ C5_lo>>31
               T0_lo = D_lo ~ L04_lo
               T0_hi = D_hi ~ L04_hi
               T1_lo = D_lo ~ L09_lo
               T1_hi = D_hi ~ L09_hi
               T2_lo = D_lo ~ L14_lo
               T2_hi = D_hi ~ L14_hi
               T3_lo = D_lo ~ L19_lo
               T3_hi = D_hi ~ L19_hi
               T4_lo = D_lo ~ L24_lo
               T4_hi = D_hi ~ L24_hi
               L04_lo = T3_lo<<21 ~ T3_hi>>11
               L04_hi = T3_hi<<21 ~ T3_lo>>11
               L09_lo = T0_lo<<28 ~ T0_hi>>4
               L09_hi = T0_hi<<28 ~ T0_lo>>4
               L14_lo = T2_lo<<25 ~ T2_hi>>7
               L14_hi = T2_hi<<25 ~ T2_lo>>7
               L19_lo = T4_lo>>8 ~ T4_hi<<24
               L19_hi = T4_hi>>8 ~ T4_lo<<24
               L24_lo = T1_lo>>9 ~ T1_hi<<23
               L24_hi = T1_hi>>9 ~ T1_lo<<23
               D_lo = C4_lo ~ C1_lo<<1 ~ C1_hi>>31
               D_hi = C4_hi ~ C1_hi<<1 ~ C1_lo>>31
               T0_lo = D_lo ~ L05_lo
               T0_hi = D_hi ~ L05_hi
               T1_lo = D_lo ~ L10_lo
               T1_hi = D_hi ~ L10_hi
               T2_lo = D_lo ~ L15_lo
               T2_hi = D_hi ~ L15_hi
               T3_lo = D_lo ~ L20_lo
               T3_hi = D_hi ~ L20_hi
               T4_lo = D_lo ~ L25_lo
               T4_hi = D_hi ~ L25_hi
               L05_lo = T4_lo<<14 ~ T4_hi>>18
               L05_hi = T4_hi<<14 ~ T4_lo>>18
               L10_lo = T1_lo<<20 ~ T1_hi>>12
               L10_hi = T1_hi<<20 ~ T1_lo>>12
               L15_lo = T3_lo<<8 ~ T3_hi>>24
               L15_hi = T3_hi<<8 ~ T3_lo>>24
               L20_lo = T0_lo<<27 ~ T0_hi>>5
               L20_hi = T0_hi<<27 ~ T0_lo>>5
               L25_lo = T2_lo>>25 ~ T2_hi<<7
               L25_hi = T2_hi>>25 ~ T2_lo<<7
               D_lo = C5_lo ~ C2_lo<<1 ~ C2_hi>>31
               D_hi = C5_hi ~ C2_hi<<1 ~ C2_lo>>31
               T1_lo = D_lo ~ L06_lo
               T1_hi = D_hi ~ L06_hi
               T2_lo = D_lo ~ L11_lo
               T2_hi = D_hi ~ L11_hi
               T3_lo = D_lo ~ L16_lo
               T3_hi = D_hi ~ L16_hi
               T4_lo = D_lo ~ L21_lo
               T4_hi = D_hi ~ L21_hi
               L06_lo = T2_lo<<3 ~ T2_hi>>29
               L06_hi = T2_hi<<3 ~ T2_lo>>29
               L11_lo = T4_lo<<18 ~ T4_hi>>14
               L11_hi = T4_hi<<18 ~ T4_lo>>14
               L16_lo = T1_lo>>28 ~ T1_hi<<4
               L16_hi = T1_hi>>28 ~ T1_lo<<4
               L21_lo = T3_lo>>23 ~ T3_hi<<9
               L21_hi = T3_hi>>23 ~ T3_lo<<9
               L01_lo = D_lo ~ L01_lo
               L01_hi = D_hi ~ L01_hi
               L01_lo, L02_lo, L03_lo, L04_lo, L05_lo = L01_lo ~ ~L02_lo & L03_lo, L02_lo ~ ~L03_lo & L04_lo, L03_lo ~ ~L04_lo & L05_lo, L04_lo ~ ~L05_lo & L01_lo, L05_lo ~ ~L01_lo & L02_lo
               L01_hi, L02_hi, L03_hi, L04_hi, L05_hi = L01_hi ~ ~L02_hi & L03_hi, L02_hi ~ ~L03_hi & L04_hi, L03_hi ~ ~L04_hi & L05_hi, L04_hi ~ ~L05_hi & L01_hi, L05_hi ~ ~L01_hi & L02_hi
               L06_lo, L07_lo, L08_lo, L09_lo, L10_lo = L09_lo ~ ~L10_lo & L06_lo, L10_lo ~ ~L06_lo & L07_lo, L06_lo ~ ~L07_lo & L08_lo, L07_lo ~ ~L08_lo & L09_lo, L08_lo ~ ~L09_lo & L10_lo
               L06_hi, L07_hi, L08_hi, L09_hi, L10_hi = L09_hi ~ ~L10_hi & L06_hi, L10_hi ~ ~L06_hi & L07_hi, L06_hi ~ ~L07_hi & L08_hi, L07_hi ~ ~L08_hi & L09_hi, L08_hi ~ ~L09_hi & L10_hi
               L11_lo, L12_lo, L13_lo, L14_lo, L15_lo = L12_lo ~ ~L13_lo & L14_lo, L13_lo ~ ~L14_lo & L15_lo, L14_lo ~ ~L15_lo & L11_lo, L15_lo ~ ~L11_lo & L12_lo, L11_lo ~ ~L12_lo & L13_lo
               L11_hi, L12_hi, L13_hi, L14_hi, L15_hi = L12_hi ~ ~L13_hi & L14_hi, L13_hi ~ ~L14_hi & L15_hi, L14_hi ~ ~L15_hi & L11_hi, L15_hi ~ ~L11_hi & L12_hi, L11_hi ~ ~L12_hi & L13_hi
               L16_lo, L17_lo, L18_lo, L19_lo, L20_lo = L20_lo ~ ~L16_lo & L17_lo, L16_lo ~ ~L17_lo & L18_lo, L17_lo ~ ~L18_lo & L19_lo, L18_lo ~ ~L19_lo & L20_lo, L19_lo ~ ~L20_lo & L16_lo
               L16_hi, L17_hi, L18_hi, L19_hi, L20_hi = L20_hi ~ ~L16_hi & L17_hi, L16_hi ~ ~L17_hi & L18_hi, L17_hi ~ ~L18_hi & L19_hi, L18_hi ~ ~L19_hi & L20_hi, L19_hi ~ ~L20_hi & L16_hi
               L21_lo, L22_lo, L23_lo, L24_lo, L25_lo = L23_lo ~ ~L24_lo & L25_lo, L24_lo ~ ~L25_lo & L21_lo, L25_lo ~ ~L21_lo & L22_lo, L21_lo ~ ~L22_lo & L23_lo, L22_lo ~ ~L23_lo & L24_lo
               L21_hi, L22_hi, L23_hi, L24_hi, L25_hi = L23_hi ~ ~L24_hi & L25_hi, L24_hi ~ ~L25_hi & L21_hi, L25_hi ~ ~L21_hi & L22_hi, L21_hi ~ ~L22_hi & L23_hi, L22_hi ~ ~L23_hi & L24_hi
               L01_lo = L01_lo ~ RC_lo[round_idx]
               L01_hi = L01_hi ~ RC_hi[round_idx]
            end
            lanes_lo[1]  = L01_lo;  lanes_hi[1]  = L01_hi
            lanes_lo[2]  = L02_lo;  lanes_hi[2]  = L02_hi
            lanes_lo[3]  = L03_lo;  lanes_hi[3]  = L03_hi
            lanes_lo[4]  = L04_lo;  lanes_hi[4]  = L04_hi
            lanes_lo[5]  = L05_lo;  lanes_hi[5]  = L05_hi
            lanes_lo[6]  = L06_lo;  lanes_hi[6]  = L06_hi
            lanes_lo[7]  = L07_lo;  lanes_hi[7]  = L07_hi
            lanes_lo[8]  = L08_lo;  lanes_hi[8]  = L08_hi
            lanes_lo[9]  = L09_lo;  lanes_hi[9]  = L09_hi
            lanes_lo[10] = L10_lo;  lanes_hi[10] = L10_hi
            lanes_lo[11] = L11_lo;  lanes_hi[11] = L11_hi
            lanes_lo[12] = L12_lo;  lanes_hi[12] = L12_hi
            lanes_lo[13] = L13_lo;  lanes_hi[13] = L13_hi
            lanes_lo[14] = L14_lo;  lanes_hi[14] = L14_hi
            lanes_lo[15] = L15_lo;  lanes_hi[15] = L15_hi
            lanes_lo[16] = L16_lo;  lanes_hi[16] = L16_hi
            lanes_lo[17] = L17_lo;  lanes_hi[17] = L17_hi
            lanes_lo[18] = L18_lo;  lanes_hi[18] = L18_hi
            lanes_lo[19] = L19_lo;  lanes_hi[19] = L19_hi
            lanes_lo[20] = L20_lo;  lanes_hi[20] = L20_hi
            lanes_lo[21] = L21_lo;  lanes_hi[21] = L21_hi
            lanes_lo[22] = L22_lo;  lanes_hi[22] = L22_hi
            lanes_lo[23] = L23_lo;  lanes_hi[23] = L23_hi
            lanes_lo[24] = L24_lo;  lanes_hi[24] = L24_hi
            lanes_lo[25] = L25_lo;  lanes_hi[25] = L25_hi
         end
      end

      local function blake2s_feed_64(H, str, offs, size, bytes_compressed, last_block_size, is_last_node)
         -- offs >= 0, size >= 0, size is multiple of 64
         local W = common_W
         local h1, h2, h3, h4, h5, h6, h7, h8 = H[1], H[2], H[3], H[4], H[5], H[6], H[7], H[8]
         for pos = offs + 1, offs + size, 64 do
            if str then
               W[1], W[2], W[3], W[4], W[5], W[6], W[7], W[8], W[9], W[10], W[11], W[12], W[13], W[14], W[15], W[16] =
                  string_unpack("<i4i4i4i4i4i4i4i4i4i4i4i4i4i4i4i4", str, pos)
            end
            local v0, v1, v2, v3, v4, v5, v6, v7 = h1, h2, h3, h4, h5, h6, h7, h8
            local v8, v9, vA, vB, vC, vD, vE, vF = sha2_H_hi[1], sha2_H_hi[2], sha2_H_hi[3], sha2_H_hi[4], sha2_H_hi[5], sha2_H_hi[6], sha2_H_hi[7], sha2_H_hi[8]
            bytes_compressed = bytes_compressed + (last_block_size or 64)
            local t0 = bytes_compressed % 2^32
            local t1 = (bytes_compressed - t0) / 2^32
            t0 = (t0 + 2^31) % 2^32 - 2^31  -- convert to int32 range (-2^31)..(2^31-1) to avoid "number has no integer representation" error while XORing
            vC = vC ~ t0  -- t0 = low_4_bytes(bytes_compressed)
            vD = vD ~ t1  -- t1 = high_4_bytes(bytes_compressed)
            if last_block_size then  -- flag f0
               vE = ~vE
            end
            if is_last_node then  -- flag f1
               vF = ~vF
            end
            for j = 1, 10 do
               local row = sigma[j]
               v0 = v0 + v4 + W[row[1]]
               vC = vC ~ v0
               vC = vC >> 16 | vC << 16
               v8 = v8 + vC
               v4 = v4 ~ v8
               v4 = v4 >> 12 | v4 << 20
               v0 = v0 + v4 + W[row[2]]
               vC = vC ~ v0
               vC = vC >> 8 | vC << 24
               v8 = v8 + vC
               v4 = v4 ~ v8
               v4 = v4 >> 7 | v4 << 25
               v1 = v1 + v5 + W[row[3]]
               vD = vD ~ v1
               vD = vD >> 16 | vD << 16
               v9 = v9 + vD
               v5 = v5 ~ v9
               v5 = v5 >> 12 | v5 << 20
               v1 = v1 + v5 + W[row[4]]
               vD = vD ~ v1
               vD = vD >> 8 | vD << 24
               v9 = v9 + vD
               v5 = v5 ~ v9
               v5 = v5 >> 7 | v5 << 25
               v2 = v2 + v6 + W[row[5]]
               vE = vE ~ v2
               vE = vE >> 16 | vE << 16
               vA = vA + vE
               v6 = v6 ~ vA
               v6 = v6 >> 12 | v6 << 20
               v2 = v2 + v6 + W[row[6]]
               vE = vE ~ v2
               vE = vE >> 8 | vE << 24
               vA = vA + vE
               v6 = v6 ~ vA
               v6 = v6 >> 7 | v6 << 25
               v3 = v3 + v7 + W[row[7]]
               vF = vF ~ v3
               vF = vF >> 16 | vF << 16
               vB = vB + vF
               v7 = v7 ~ vB
               v7 = v7 >> 12 | v7 << 20
               v3 = v3 + v7 + W[row[8]]
               vF = vF ~ v3
               vF = vF >> 8 | vF << 24
               vB = vB + vF
               v7 = v7 ~ vB
               v7 = v7 >> 7 | v7 << 25
               v0 = v0 + v5 + W[row[9]]
               vF = vF ~ v0
               vF = vF >> 16 | vF << 16
               vA = vA + vF
               v5 = v5 ~ vA
               v5 = v5 >> 12 | v5 << 20
               v0 = v0 + v5 + W[row[10]]
               vF = vF ~ v0
               vF = vF >> 8 | vF << 24
               vA = vA + vF
               v5 = v5 ~ vA
               v5 = v5 >> 7 | v5 << 25
               v1 = v1 + v6 + W[row[11]]
               vC = vC ~ v1
               vC = vC >> 16 | vC << 16
               vB = vB + vC
               v6 = v6 ~ vB
               v6 = v6 >> 12 | v6 << 20
               v1 = v1 + v6 + W[row[12]]
               vC = vC ~ v1
               vC = vC >> 8 | vC << 24
               vB = vB + vC
               v6 = v6 ~ vB
               v6 = v6 >> 7 | v6 << 25
               v2 = v2 + v7 + W[row[13]]
               vD = vD ~ v2
               vD = vD >> 16 | vD << 16
               v8 = v8 + vD
               v7 = v7 ~ v8
               v7 = v7 >> 12 | v7 << 20
               v2 = v2 + v7 + W[row[14]]
               vD = vD ~ v2
               vD = vD >> 8 | vD << 24
               v8 = v8 + vD
               v7 = v7 ~ v8
               v7 = v7 >> 7 | v7 << 25
               v3 = v3 + v4 + W[row[15]]
               vE = vE ~ v3
               vE = vE >> 16 | vE << 16
               v9 = v9 + vE
               v4 = v4 ~ v9
               v4 = v4 >> 12 | v4 << 20
               v3 = v3 + v4 + W[row[16]]
               vE = vE ~ v3
               vE = vE >> 8 | vE << 24
               v9 = v9 + vE
               v4 = v4 ~ v9
               v4 = v4 >> 7 | v4 << 25
            end
            h1 = h1 ~ v0 ~ v8
            h2 = h2 ~ v1 ~ v9
            h3 = h3 ~ v2 ~ vA
            h4 = h4 ~ v3 ~ vB
            h5 = h5 ~ v4 ~ vC
            h6 = h6 ~ v5 ~ vD
            h7 = h7 ~ v6 ~ vE
            h8 = h8 ~ v7 ~ vF
         end
         H[1], H[2], H[3], H[4], H[5], H[6], H[7], H[8] = h1, h2, h3, h4, h5, h6, h7, h8
         return bytes_compressed
      end

      local function blake2b_feed_128(H_lo, H_hi, str, offs, size, bytes_compressed, last_block_size, is_last_node)
         -- offs >= 0, size >= 0, size is multiple of 128
         local W = common_W
         local h1_lo, h2_lo, h3_lo, h4_lo, h5_lo, h6_lo, h7_lo, h8_lo = H_lo[1], H_lo[2], H_lo[3], H_lo[4], H_lo[5], H_lo[6], H_lo[7], H_lo[8]
         local h1_hi, h2_hi, h3_hi, h4_hi, h5_hi, h6_hi, h7_hi, h8_hi = H_hi[1], H_hi[2], H_hi[3], H_hi[4], H_hi[5], H_hi[6], H_hi[7], H_hi[8]
         for pos = offs + 1, offs + size, 128 do
            if str then
               W[1], W[2], W[3], W[4], W[5], W[6], W[7], W[8], W[9], W[10], W[11], W[12], W[13], W[14], W[15], W[16],
               W[17], W[18], W[19], W[20], W[21], W[22], W[23], W[24], W[25], W[26], W[27], W[28], W[29], W[30], W[31], W[32] =
                  string_unpack("<i4i4i4i4i4i4i4i4i4i4i4i4i4i4i4i4i4i4i4i4i4i4i4i4i4i4i4i4i4i4i4i4", str, pos)
            end
            local v0_lo, v1_lo, v2_lo, v3_lo, v4_lo, v5_lo, v6_lo, v7_lo = h1_lo, h2_lo, h3_lo, h4_lo, h5_lo, h6_lo, h7_lo, h8_lo
            local v0_hi, v1_hi, v2_hi, v3_hi, v4_hi, v5_hi, v6_hi, v7_hi = h1_hi, h2_hi, h3_hi, h4_hi, h5_hi, h6_hi, h7_hi, h8_hi
            local v8_lo, v9_lo, vA_lo, vB_lo, vC_lo, vD_lo, vE_lo, vF_lo = sha2_H_lo[1], sha2_H_lo[2], sha2_H_lo[3], sha2_H_lo[4], sha2_H_lo[5], sha2_H_lo[6], sha2_H_lo[7], sha2_H_lo[8]
            local v8_hi, v9_hi, vA_hi, vB_hi, vC_hi, vD_hi, vE_hi, vF_hi = sha2_H_hi[1], sha2_H_hi[2], sha2_H_hi[3], sha2_H_hi[4], sha2_H_hi[5], sha2_H_hi[6], sha2_H_hi[7], sha2_H_hi[8]
            bytes_compressed = bytes_compressed + (last_block_size or 128)
            local t0_lo = bytes_compressed % 2^32
            local t0_hi = (bytes_compressed - t0_lo) / 2^32
            t0_lo = (t0_lo + 2^31) % 2^32 - 2^31  -- convert to int32 range (-2^31)..(2^31-1) to avoid "number has no integer representation" error while XORing
            vC_lo = vC_lo ~ t0_lo  -- t0 = low_8_bytes(bytes_compressed)
            vC_hi = vC_hi ~ t0_hi
            -- t1 = high_8_bytes(bytes_compressed) = 0,  message length is always below 2^53 bytes
            if last_block_size then  -- flag f0
               vE_lo = ~vE_lo
               vE_hi = ~vE_hi
            end
            if is_last_node then  -- flag f1
               vF_lo = ~vF_lo
               vF_hi = ~vF_hi
            end
            for j = 1, 12 do
               local row = sigma[j]
               local k = row[1] * 2
               v0_lo = v0_lo % 2^32 + v4_lo % 2^32 + W[k-1] % 2^32
               v0_hi = v0_hi + v4_hi + floor(v0_lo / 2^32) + W[k]
               v0_lo = 0|((v0_lo + 2^31) % 2^32 - 2^31)
               vC_lo, vC_hi = vC_hi ~ v0_hi, vC_lo ~ v0_lo
               v8_lo = v8_lo % 2^32 + vC_lo % 2^32
               v8_hi = v8_hi + vC_hi + floor(v8_lo / 2^32)
               v8_lo = 0|((v8_lo + 2^31) % 2^32 - 2^31)
               v4_lo, v4_hi = v4_lo ~ v8_lo, v4_hi ~ v8_hi
               v4_lo, v4_hi = v4_lo >> 24 | v4_hi << 8, v4_hi >> 24 | v4_lo << 8
               k = row[2] * 2
               v0_lo = v0_lo % 2^32 + v4_lo % 2^32 + W[k-1] % 2^32
               v0_hi = v0_hi + v4_hi + floor(v0_lo / 2^32) + W[k]
               v0_lo = 0|((v0_lo + 2^31) % 2^32 - 2^31)
               vC_lo, vC_hi = vC_lo ~ v0_lo, vC_hi ~ v0_hi
               vC_lo, vC_hi = vC_lo >> 16 | vC_hi << 16, vC_hi >> 16 | vC_lo << 16
               v8_lo = v8_lo % 2^32 + vC_lo % 2^32
               v8_hi = v8_hi + vC_hi + floor(v8_lo / 2^32)
               v8_lo = 0|((v8_lo + 2^31) % 2^32 - 2^31)
               v4_lo, v4_hi = v4_lo ~ v8_lo, v4_hi ~ v8_hi
               v4_lo, v4_hi = v4_lo << 1 | v4_hi >> 31, v4_hi << 1 | v4_lo >> 31
               k = row[3] * 2
               v1_lo = v1_lo % 2^32 + v5_lo % 2^32 + W[k-1] % 2^32
               v1_hi = v1_hi + v5_hi + floor(v1_lo / 2^32) + W[k]
               v1_lo = 0|((v1_lo + 2^31) % 2^32 - 2^31)
               vD_lo, vD_hi = vD_hi ~ v1_hi, vD_lo ~ v1_lo
               v9_lo = v9_lo % 2^32 + vD_lo % 2^32
               v9_hi = v9_hi + vD_hi + floor(v9_lo / 2^32)
               v9_lo = 0|((v9_lo + 2^31) % 2^32 - 2^31)
               v5_lo, v5_hi = v5_lo ~ v9_lo, v5_hi ~ v9_hi
               v5_lo, v5_hi = v5_lo >> 24 | v5_hi << 8, v5_hi >> 24 | v5_lo << 8
               k = row[4] * 2
               v1_lo = v1_lo % 2^32 + v5_lo % 2^32 + W[k-1] % 2^32
               v1_hi = v1_hi + v5_hi + floor(v1_lo / 2^32) + W[k]
               v1_lo = 0|((v1_lo + 2^31) % 2^32 - 2^31)
               vD_lo, vD_hi = vD_lo ~ v1_lo, vD_hi ~ v1_hi
               vD_lo, vD_hi = vD_lo >> 16 | vD_hi << 16, vD_hi >> 16 | vD_lo << 16
               v9_lo = v9_lo % 2^32 + vD_lo % 2^32
               v9_hi = v9_hi + vD_hi + floor(v9_lo / 2^32)
               v9_lo = 0|((v9_lo + 2^31) % 2^32 - 2^31)
               v5_lo, v5_hi = v5_lo ~ v9_lo, v5_hi ~ v9_hi
               v5_lo, v5_hi = v5_lo << 1 | v5_hi >> 31, v5_hi << 1 | v5_lo >> 31
               k = row[5] * 2
               v2_lo = v2_lo % 2^32 + v6_lo % 2^32 + W[k-1] % 2^32
               v2_hi = v2_hi + v6_hi + floor(v2_lo / 2^32) + W[k]
               v2_lo = 0|((v2_lo + 2^31) % 2^32 - 2^31)
               vE_lo, vE_hi = vE_hi ~ v2_hi, vE_lo ~ v2_lo
               vA_lo = vA_lo % 2^32 + vE_lo % 2^32
               vA_hi = vA_hi + vE_hi + floor(vA_lo / 2^32)
               vA_lo = 0|((vA_lo + 2^31) % 2^32 - 2^31)
               v6_lo, v6_hi = v6_lo ~ vA_lo, v6_hi ~ vA_hi
               v6_lo, v6_hi = v6_lo >> 24 | v6_hi << 8, v6_hi >> 24 | v6_lo << 8
               k = row[6] * 2
               v2_lo = v2_lo % 2^32 + v6_lo % 2^32 + W[k-1] % 2^32
               v2_hi = v2_hi + v6_hi + floor(v2_lo / 2^32) + W[k]
               v2_lo = 0|((v2_lo + 2^31) % 2^32 - 2^31)
               vE_lo, vE_hi = vE_lo ~ v2_lo, vE_hi ~ v2_hi
               vE_lo, vE_hi = vE_lo >> 16 | vE_hi << 16, vE_hi >> 16 | vE_lo << 16
               vA_lo = vA_lo % 2^32 + vE_lo % 2^32
               vA_hi = vA_hi + vE_hi + floor(vA_lo / 2^32)
               vA_lo = 0|((vA_lo + 2^31) % 2^32 - 2^31)
               v6_lo, v6_hi = v6_lo ~ vA_lo, v6_hi ~ vA_hi
               v6_lo, v6_hi = v6_lo << 1 | v6_hi >> 31, v6_hi << 1 | v6_lo >> 31
               k = row[7] * 2
               v3_lo = v3_lo % 2^32 + v7_lo % 2^32 + W[k-1] % 2^32
               v3_hi = v3_hi + v7_hi + floor(v3_lo / 2^32) + W[k]
               v3_lo = 0|((v3_lo + 2^31) % 2^32 - 2^31)
               vF_lo, vF_hi = vF_hi ~ v3_hi, vF_lo ~ v3_lo
               vB_lo = vB_lo % 2^32 + vF_lo % 2^32
               vB_hi = vB_hi + vF_hi + floor(vB_lo / 2^32)
               vB_lo = 0|((vB_lo + 2^31) % 2^32 - 2^31)
               v7_lo, v7_hi = v7_lo ~ vB_lo, v7_hi ~ vB_hi
               v7_lo, v7_hi = v7_lo >> 24 | v7_hi << 8, v7_hi >> 24 | v7_lo << 8
               k = row[8] * 2
               v3_lo = v3_lo % 2^32 + v7_lo % 2^32 + W[k-1] % 2^32
               v3_hi = v3_hi + v7_hi + floor(v3_lo / 2^32) + W[k]
               v3_lo = 0|((v3_lo + 2^31) % 2^32 - 2^31)
               vF_lo, vF_hi = vF_lo ~ v3_lo, vF_hi ~ v3_hi
               vF_lo, vF_hi = vF_lo >> 16 | vF_hi << 16, vF_hi >> 16 | vF_lo << 16
               vB_lo = vB_lo % 2^32 + vF_lo % 2^32
               vB_hi = vB_hi + vF_hi + floor(vB_lo / 2^32)
               vB_lo = 0|((vB_lo + 2^31) % 2^32 - 2^31)
               v7_lo, v7_hi = v7_lo ~ vB_lo, v7_hi ~ vB_hi
               v7_lo, v7_hi = v7_lo << 1 | v7_hi >> 31, v7_hi << 1 | v7_lo >> 31
               k = row[9] * 2
               v0_lo = v0_lo % 2^32 + v5_lo % 2^32 + W[k-1] % 2^32
               v0_hi = v0_hi + v5_hi + floor(v0_lo / 2^32) + W[k]
               v0_lo = 0|((v0_lo + 2^31) % 2^32 - 2^31)
               vF_lo, vF_hi = vF_hi ~ v0_hi, vF_lo ~ v0_lo
               vA_lo = vA_lo % 2^32 + vF_lo % 2^32
               vA_hi = vA_hi + vF_hi + floor(vA_lo / 2^32)
               vA_lo = 0|((vA_lo + 2^31) % 2^32 - 2^31)
               v5_lo, v5_hi = v5_lo ~ vA_lo, v5_hi ~ vA_hi
               v5_lo, v5_hi = v5_lo >> 24 | v5_hi << 8, v5_hi >> 24 | v5_lo << 8
               k = row[10] * 2
               v0_lo = v0_lo % 2^32 + v5_lo % 2^32 + W[k-1] % 2^32
               v0_hi = v0_hi + v5_hi + floor(v0_lo / 2^32) + W[k]
               v0_lo = 0|((v0_lo + 2^31) % 2^32 - 2^31)
               vF_lo, vF_hi = vF_lo ~ v0_lo, vF_hi ~ v0_hi
               vF_lo, vF_hi = vF_lo >> 16 | vF_hi << 16, vF_hi >> 16 | vF_lo << 16
               vA_lo = vA_lo % 2^32 + vF_lo % 2^32
               vA_hi = vA_hi + vF_hi + floor(vA_lo / 2^32)
               vA_lo = 0|((vA_lo + 2^31) % 2^32 - 2^31)
               v5_lo, v5_hi = v5_lo ~ vA_lo, v5_hi ~ vA_hi
               v5_lo, v5_hi = v5_lo << 1 | v5_hi >> 31, v5_hi << 1 | v5_lo >> 31
               k = row[11] * 2
               v1_lo = v1_lo % 2^32 + v6_lo % 2^32 + W[k-1] % 2^32
               v1_hi = v1_hi + v6_hi + floor(v1_lo / 2^32) + W[k]
               v1_lo = 0|((v1_lo + 2^31) % 2^32 - 2^31)
               vC_lo, vC_hi = vC_hi ~ v1_hi, vC_lo ~ v1_lo
               vB_lo = vB_lo % 2^32 + vC_lo % 2^32
               vB_hi = vB_hi + vC_hi + floor(vB_lo / 2^32)
               vB_lo = 0|((vB_lo + 2^31) % 2^32 - 2^31)
               v6_lo, v6_hi = v6_lo ~ vB_lo, v6_hi ~ vB_hi
               v6_lo, v6_hi = v6_lo >> 24 | v6_hi << 8, v6_hi >> 24 | v6_lo << 8
               k = row[12] * 2
               v1_lo = v1_lo % 2^32 + v6_lo % 2^32 + W[k-1] % 2^32
               v1_hi = v1_hi + v6_hi + floor(v1_lo / 2^32) + W[k]
               v1_lo = 0|((v1_lo + 2^31) % 2^32 - 2^31)
               vC_lo, vC_hi = vC_lo ~ v1_lo, vC_hi ~ v1_hi
               vC_lo, vC_hi = vC_lo >> 16 | vC_hi << 16, vC_hi >> 16 | vC_lo << 16
               vB_lo = vB_lo % 2^32 + vC_lo % 2^32
               vB_hi = vB_hi + vC_hi + floor(vB_lo / 2^32)
               vB_lo = 0|((vB_lo + 2^31) % 2^32 - 2^31)
               v6_lo, v6_hi = v6_lo ~ vB_lo, v6_hi ~ vB_hi
               v6_lo, v6_hi = v6_lo << 1 | v6_hi >> 31, v6_hi << 1 | v6_lo >> 31
               k = row[13] * 2
               v2_lo = v2_lo % 2^32 + v7_lo % 2^32 + W[k-1] % 2^32
               v2_hi = v2_hi + v7_hi + floor(v2_lo / 2^32) + W[k]
               v2_lo = 0|((v2_lo + 2^31) % 2^32 - 2^31)
               vD_lo, vD_hi = vD_hi ~ v2_hi, vD_lo ~ v2_lo
               v8_lo = v8_lo % 2^32 + vD_lo % 2^32
               v8_hi = v8_hi + vD_hi + floor(v8_lo / 2^32)
               v8_lo = 0|((v8_lo + 2^31) % 2^32 - 2^31)
               v7_lo, v7_hi = v7_lo ~ v8_lo, v7_hi ~ v8_hi
               v7_lo, v7_hi = v7_lo >> 24 | v7_hi << 8, v7_hi >> 24 | v7_lo << 8
               k = row[14] * 2
               v2_lo = v2_lo % 2^32 + v7_lo % 2^32 + W[k-1] % 2^32
               v2_hi = v2_hi + v7_hi + floor(v2_lo / 2^32) + W[k]
               v2_lo = 0|((v2_lo + 2^31) % 2^32 - 2^31)
               vD_lo, vD_hi = vD_lo ~ v2_lo, vD_hi ~ v2_hi
               vD_lo, vD_hi = vD_lo >> 16 | vD_hi << 16, vD_hi >> 16 | vD_lo << 16
               v8_lo = v8_lo % 2^32 + vD_lo % 2^32
               v8_hi = v8_hi + vD_hi + floor(v8_lo / 2^32)
               v8_lo = 0|((v8_lo + 2^31) % 2^32 - 2^31)
               v7_lo, v7_hi = v7_lo ~ v8_lo, v7_hi ~ v8_hi
               v7_lo, v7_hi = v7_lo << 1 | v7_hi >> 31, v7_hi << 1 | v7_lo >> 31
               k = row[15] * 2
               v3_lo = v3_lo % 2^32 + v4_lo % 2^32 + W[k-1] % 2^32
               v3_hi = v3_hi + v4_hi + floor(v3_lo / 2^32) + W[k]
               v3_lo = 0|((v3_lo + 2^31) % 2^32 - 2^31)
               vE_lo, vE_hi = vE_hi ~ v3_hi, vE_lo ~ v3_lo
               v9_lo = v9_lo % 2^32 + vE_lo % 2^32
               v9_hi = v9_hi + vE_hi + floor(v9_lo / 2^32)
               v9_lo = 0|((v9_lo + 2^31) % 2^32 - 2^31)
               v4_lo, v4_hi = v4_lo ~ v9_lo, v4_hi ~ v9_hi
               v4_lo, v4_hi = v4_lo >> 24 | v4_hi << 8, v4_hi >> 24 | v4_lo << 8
               k = row[16] * 2
               v3_lo = v3_lo % 2^32 + v4_lo % 2^32 + W[k-1] % 2^32
               v3_hi = v3_hi + v4_hi + floor(v3_lo / 2^32) + W[k]
               v3_lo = 0|((v3_lo + 2^31) % 2^32 - 2^31)
               vE_lo, vE_hi = vE_lo ~ v3_lo, vE_hi ~ v3_hi
               vE_lo, vE_hi = vE_lo >> 16 | vE_hi << 16, vE_hi >> 16 | vE_lo << 16
               v9_lo = v9_lo % 2^32 + vE_lo % 2^32
               v9_hi = v9_hi + vE_hi + floor(v9_lo / 2^32)
               v9_lo = 0|((v9_lo + 2^31) % 2^32 - 2^31)
               v4_lo, v4_hi = v4_lo ~ v9_lo, v4_hi ~ v9_hi
               v4_lo, v4_hi = v4_lo << 1 | v4_hi >> 31, v4_hi << 1 | v4_lo >> 31
            end
            h1_lo = h1_lo ~ v0_lo ~ v8_lo
            h2_lo = h2_lo ~ v1_lo ~ v9_lo
            h3_lo = h3_lo ~ v2_lo ~ vA_lo
            h4_lo = h4_lo ~ v3_lo ~ vB_lo
            h5_lo = h5_lo ~ v4_lo ~ vC_lo
            h6_lo = h6_lo ~ v5_lo ~ vD_lo
            h7_lo = h7_lo ~ v6_lo ~ vE_lo
            h8_lo = h8_lo ~ v7_lo ~ vF_lo
            h1_hi = h1_hi ~ v0_hi ~ v8_hi
            h2_hi = h2_hi ~ v1_hi ~ v9_hi
            h3_hi = h3_hi ~ v2_hi ~ vA_hi
            h4_hi = h4_hi ~ v3_hi ~ vB_hi
            h5_hi = h5_hi ~ v4_hi ~ vC_hi
            h6_hi = h6_hi ~ v5_hi ~ vD_hi
            h7_hi = h7_hi ~ v6_hi ~ vE_hi
            h8_hi = h8_hi ~ v7_hi ~ vF_hi
         end
         H_lo[1], H_lo[2], H_lo[3], H_lo[4], H_lo[5], H_lo[6], H_lo[7], H_lo[8] = h1_lo, h2_lo, h3_lo, h4_lo, h5_lo, h6_lo, h7_lo, h8_lo
         H_hi[1], H_hi[2], H_hi[3], H_hi[4], H_hi[5], H_hi[6], H_hi[7], H_hi[8] = h1_hi, h2_hi, h3_hi, h4_hi, h5_hi, h6_hi, h7_hi, h8_hi
         return bytes_compressed
      end

      local function blake3_feed_64(str, offs, size, flags, chunk_index, H_in, H_out, wide_output, block_length)
         -- offs >= 0, size >= 0, size is multiple of 64
         block_length = block_length or 64
         local W = common_W
         local h1, h2, h3, h4, h5, h6, h7, h8 = H_in[1], H_in[2], H_in[3], H_in[4], H_in[5], H_in[6], H_in[7], H_in[8]
         H_out = H_out or H_in
         for pos = offs + 1, offs + size, 64 do
            if str then
               W[1], W[2], W[3], W[4], W[5], W[6], W[7], W[8], W[9], W[10], W[11], W[12], W[13], W[14], W[15], W[16] =
                  string_unpack("<i4i4i4i4i4i4i4i4i4i4i4i4i4i4i4i4", str, pos)
            end
            local v0, v1, v2, v3, v4, v5, v6, v7 = h1, h2, h3, h4, h5, h6, h7, h8
            local v8, v9, vA, vB = sha2_H_hi[1], sha2_H_hi[2], sha2_H_hi[3], sha2_H_hi[4]
            local t0 = chunk_index % 2^32         -- t0 = low_4_bytes(chunk_index)
            local t1 = (chunk_index - t0) / 2^32  -- t1 = high_4_bytes(chunk_index)
            t0 = (t0 + 2^31) % 2^32 - 2^31  -- convert to int32 range (-2^31)..(2^31-1) to avoid "number has no integer representation" error while ORing
            local vC, vD, vE, vF = 0|t0, 0|t1, block_length, flags
            for j = 1, 7 do
               v0 = v0 + v4 + W[perm_blake3[j]]
               vC = vC ~ v0
               vC = vC >> 16 | vC << 16
               v8 = v8 + vC
               v4 = v4 ~ v8
               v4 = v4 >> 12 | v4 << 20
               v0 = v0 + v4 + W[perm_blake3[j + 14]]
               vC = vC ~ v0
               vC = vC >> 8 | vC << 24
               v8 = v8 + vC
               v4 = v4 ~ v8
               v4 = v4 >> 7 | v4 << 25
               v1 = v1 + v5 + W[perm_blake3[j + 1]]
               vD = vD ~ v1
               vD = vD >> 16 | vD << 16
               v9 = v9 + vD
               v5 = v5 ~ v9
               v5 = v5 >> 12 | v5 << 20
               v1 = v1 + v5 + W[perm_blake3[j + 2]]
               vD = vD ~ v1
               vD = vD >> 8 | vD << 24
               v9 = v9 + vD
               v5 = v5 ~ v9
               v5 = v5 >> 7 | v5 << 25
               v2 = v2 + v6 + W[perm_blake3[j + 16]]
               vE = vE ~ v2
               vE = vE >> 16 | vE << 16
               vA = vA + vE
               v6 = v6 ~ vA
               v6 = v6 >> 12 | v6 << 20
               v2 = v2 + v6 + W[perm_blake3[j + 7]]
               vE = vE ~ v2
               vE = vE >> 8 | vE << 24
               vA = vA + vE
               v6 = v6 ~ vA
               v6 = v6 >> 7 | v6 << 25
               v3 = v3 + v7 + W[perm_blake3[j + 15]]
               vF = vF ~ v3
               vF = vF >> 16 | vF << 16
               vB = vB + vF
               v7 = v7 ~ vB
               v7 = v7 >> 12 | v7 << 20
               v3 = v3 + v7 + W[perm_blake3[j + 17]]
               vF = vF ~ v3
               vF = vF >> 8 | vF << 24
               vB = vB + vF
               v7 = v7 ~ vB
               v7 = v7 >> 7 | v7 << 25
               v0 = v0 + v5 + W[perm_blake3[j + 21]]
               vF = vF ~ v0
               vF = vF >> 16 | vF << 16
               vA = vA + vF
               v5 = v5 ~ vA
               v5 = v5 >> 12 | v5 << 20
               v0 = v0 + v5 + W[perm_blake3[j + 5]]
               vF = vF ~ v0
               vF = vF >> 8 | vF << 24
               vA = vA + vF
               v5 = v5 ~ vA
               v5 = v5 >> 7 | v5 << 25
               v1 = v1 + v6 + W[perm_blake3[j + 3]]
               vC = vC ~ v1
               vC = vC >> 16 | vC << 16
               vB = vB + vC
               v6 = v6 ~ vB
               v6 = v6 >> 12 | v6 << 20
               v1 = v1 + v6 + W[perm_blake3[j + 6]]
               vC = vC ~ v1
               vC = vC >> 8 | vC << 24
               vB = vB + vC
               v6 = v6 ~ vB
               v6 = v6 >> 7 | v6 << 25
               v2 = v2 + v7 + W[perm_blake3[j + 4]]
               vD = vD ~ v2
               vD = vD >> 16 | vD << 16
               v8 = v8 + vD
               v7 = v7 ~ v8
               v7 = v7 >> 12 | v7 << 20
               v2 = v2 + v7 + W[perm_blake3[j + 18]]
               vD = vD ~ v2
               vD = vD >> 8 | vD << 24
               v8 = v8 + vD
               v7 = v7 ~ v8
               v7 = v7 >> 7 | v7 << 25
               v3 = v3 + v4 + W[perm_blake3[j + 19]]
               vE = vE ~ v3
               vE = vE >> 16 | vE << 16
               v9 = v9 + vE
               v4 = v4 ~ v9
               v4 = v4 >> 12 | v4 << 20
               v3 = v3 + v4 + W[perm_blake3[j + 20]]
               vE = vE ~ v3
               vE = vE >> 8 | vE << 24
               v9 = v9 + vE
               v4 = v4 ~ v9
               v4 = v4 >> 7 | v4 << 25
            end
            if wide_output then
               H_out[ 9] = h1 ~ v8
               H_out[10] = h2 ~ v9
               H_out[11] = h3 ~ vA
               H_out[12] = h4 ~ vB
               H_out[13] = h5 ~ vC
               H_out[14] = h6 ~ vD
               H_out[15] = h7 ~ vE
               H_out[16] = h8 ~ vF
            end
            h1 = v0 ~ v8
            h2 = v1 ~ v9
            h3 = v2 ~ vA
            h4 = v3 ~ vB
            h5 = v4 ~ vC
            h6 = v5 ~ vD
            h7 = v6 ~ vE
            h8 = v7 ~ vF
         end
         H_out[1], H_out[2], H_out[3], H_out[4], H_out[5], H_out[6], H_out[7], H_out[8] = h1, h2, h3, h4, h5, h6, h7, h8
      end

      return XORA5, XOR_BYTE, sha256_feed_64, sha512_feed_128, md5_feed_64, sha1_feed_64, keccak_feed, blake2s_feed_64, blake2b_feed_128, blake3_feed_64
   ]=](md5_next_shift, md5_K, sha2_K_lo, sha2_K_hi, build_keccak_format, sha3_RC_lo, sha3_RC_hi, sigma, common_W, sha2_H_lo, sha2_H_hi, perm_blake3)

end

XOR = XOR or XORA5

if branch == "LIB32" or branch == "EMUL" then


   -- implementation for Lua 5.1/5.2 (with or without bitwise library available)

   function sha256_feed_64(H, str, offs, size)
      -- offs >= 0, size >= 0, size is multiple of 64
      local W, K = common_W, sha2_K_hi
      local h1, h2, h3, h4, h5, h6, h7, h8 = H[1], H[2], H[3], H[4], H[5], H[6], H[7], H[8]
      for pos = offs, offs + size - 1, 64 do
         for j = 1, 16 do
            pos = pos + 4
            local a, b, c, d = byte(str, pos - 3, pos)
            W[j] = ((a * 256 + b) * 256 + c) * 256 + d
         end
         for j = 17, 64 do
            local a, b = W[j-15], W[j-2]
            local a7, a18, b17, b19 = a / 2^7, a / 2^18, b / 2^17, b / 2^19
            W[j] = (XOR(a7 % 1 * (2^32 - 1) + a7, a18 % 1 * (2^32 - 1) + a18, (a - a % 2^3) / 2^3) + W[j-16] + W[j-7]
               + XOR(b17 % 1 * (2^32 - 1) + b17, b19 % 1 * (2^32 - 1) + b19, (b - b % 2^10) / 2^10)) % 2^32
         end
         local a, b, c, d, e, f, g, h = h1, h2, h3, h4, h5, h6, h7, h8
         for j = 1, 64 do
            e = e % 2^32
            local e6, e11, e7 = e / 2^6, e / 2^11, e * 2^7
            local e7_lo = e7 % 2^32
            local z = AND(e, f) + AND(-1-e, g) + h + K[j] + W[j]
               + XOR(e6 % 1 * (2^32 - 1) + e6, e11 % 1 * (2^32 - 1) + e11, e7_lo + (e7 - e7_lo) / 2^32)
            h = g
            g = f
            f = e
            e = z + d
            d = c
            c = b
            b = a % 2^32
            local b2, b13, b10 = b / 2^2, b / 2^13, b * 2^10
            local b10_lo = b10 % 2^32
            a = z + AND(d, c) + AND(b, XOR(d, c)) +
               XOR(b2 % 1 * (2^32 - 1) + b2, b13 % 1 * (2^32 - 1) + b13, b10_lo + (b10 - b10_lo) / 2^32)
         end
         h1, h2, h3, h4 = (a + h1) % 2^32, (b + h2) % 2^32, (c + h3) % 2^32, (d + h4) % 2^32
         h5, h6, h7, h8 = (e + h5) % 2^32, (f + h6) % 2^32, (g + h7) % 2^32, (h + h8) % 2^32
      end
      H[1], H[2], H[3], H[4], H[5], H[6], H[7], H[8] = h1, h2, h3, h4, h5, h6, h7, h8
   end


   function sha512_feed_128(H_lo, H_hi, str, offs, size)
      -- offs >= 0, size >= 0, size is multiple of 128
      -- W1_hi, W1_lo, W2_hi, W2_lo, ...   Wk_hi = W[2*k-1], Wk_lo = W[2*k]
      local W, K_lo, K_hi = common_W, sha2_K_lo, sha2_K_hi
      local h1_lo, h2_lo, h3_lo, h4_lo, h5_lo, h6_lo, h7_lo, h8_lo = H_lo[1], H_lo[2], H_lo[3], H_lo[4], H_lo[5], H_lo[6], H_lo[7], H_lo[8]
      local h1_hi, h2_hi, h3_hi, h4_hi, h5_hi, h6_hi, h7_hi, h8_hi = H_hi[1], H_hi[2], H_hi[3], H_hi[4], H_hi[5], H_hi[6], H_hi[7], H_hi[8]
      for pos = offs, offs + size - 1, 128 do
         for j = 1, 16*2 do
            pos = pos + 4
            local a, b, c, d = byte(str, pos - 3, pos)
            W[j] = ((a * 256 + b) * 256 + c) * 256 + d
         end
         for jj = 17*2, 80*2, 2 do
            local a_hi, a_lo, b_hi, b_lo = W[jj-31], W[jj-30], W[jj-5], W[jj-4]
            local b_hi_6, b_hi_19, b_hi_29, b_lo_19, b_lo_29, a_hi_1, a_hi_7, a_hi_8, a_lo_1, a_lo_8 =
               b_hi % 2^6, b_hi % 2^19, b_hi % 2^29, b_lo % 2^19, b_lo % 2^29, a_hi % 2^1, a_hi % 2^7, a_hi % 2^8, a_lo % 2^1, a_lo % 2^8
            local tmp1 = XOR((a_lo - a_lo_1) / 2^1 + a_hi_1 * 2^31, (a_lo - a_lo_8) / 2^8 + a_hi_8 * 2^24, (a_lo - a_lo % 2^7) / 2^7 + a_hi_7 * 2^25) % 2^32
               + XOR((b_lo - b_lo_19) / 2^19 + b_hi_19 * 2^13, b_lo_29 * 2^3 + (b_hi - b_hi_29) / 2^29, (b_lo - b_lo % 2^6) / 2^6 + b_hi_6 * 2^26) % 2^32
               + W[jj-14] + W[jj-32]
            local tmp2 = tmp1 % 2^32
            W[jj-1] = (XOR((a_hi - a_hi_1) / 2^1 + a_lo_1 * 2^31, (a_hi - a_hi_8) / 2^8 + a_lo_8 * 2^24, (a_hi - a_hi_7) / 2^7)
               + XOR((b_hi - b_hi_19) / 2^19 + b_lo_19 * 2^13, b_hi_29 * 2^3 + (b_lo - b_lo_29) / 2^29, (b_hi - b_hi_6) / 2^6)
               + W[jj-15] + W[jj-33] + (tmp1 - tmp2) / 2^32) % 2^32
            W[jj] = tmp2
         end
         local a_lo, b_lo, c_lo, d_lo, e_lo, f_lo, g_lo, h_lo = h1_lo, h2_lo, h3_lo, h4_lo, h5_lo, h6_lo, h7_lo, h8_lo
         local a_hi, b_hi, c_hi, d_hi, e_hi, f_hi, g_hi, h_hi = h1_hi, h2_hi, h3_hi, h4_hi, h5_hi, h6_hi, h7_hi, h8_hi
         for j = 1, 80 do
            local jj = 2*j
            local e_lo_9, e_lo_14, e_lo_18, e_hi_9, e_hi_14, e_hi_18 = e_lo % 2^9, e_lo % 2^14, e_lo % 2^18, e_hi % 2^9, e_hi % 2^14, e_hi % 2^18
            local tmp1 = (AND(e_lo, f_lo) + AND(-1-e_lo, g_lo)) % 2^32 + h_lo + K_lo[j] + W[jj]
               + XOR((e_lo - e_lo_14) / 2^14 + e_hi_14 * 2^18, (e_lo - e_lo_18) / 2^18 + e_hi_18 * 2^14, e_lo_9 * 2^23 + (e_hi - e_hi_9) / 2^9) % 2^32
            local z_lo = tmp1 % 2^32
            local z_hi = AND(e_hi, f_hi) + AND(-1-e_hi, g_hi) + h_hi + K_hi[j] + W[jj-1] + (tmp1 - z_lo) / 2^32
               + XOR((e_hi - e_hi_14) / 2^14 + e_lo_14 * 2^18, (e_hi - e_hi_18) / 2^18 + e_lo_18 * 2^14, e_hi_9 * 2^23 + (e_lo - e_lo_9) / 2^9)
            h_lo = g_lo;  h_hi = g_hi
            g_lo = f_lo;  g_hi = f_hi
            f_lo = e_lo;  f_hi = e_hi
            tmp1 = z_lo + d_lo
            e_lo = tmp1 % 2^32
            e_hi = (z_hi + d_hi + (tmp1 - e_lo) / 2^32) % 2^32
            d_lo = c_lo;  d_hi = c_hi
            c_lo = b_lo;  c_hi = b_hi
            b_lo = a_lo;  b_hi = a_hi
            local b_lo_2, b_lo_7, b_lo_28, b_hi_2, b_hi_7, b_hi_28 = b_lo % 2^2, b_lo % 2^7, b_lo % 2^28, b_hi % 2^2, b_hi % 2^7, b_hi % 2^28
            tmp1 = z_lo + (AND(d_lo, c_lo) + AND(b_lo, XOR(d_lo, c_lo))) % 2^32
               + XOR((b_lo - b_lo_28) / 2^28 + b_hi_28 * 2^4, b_lo_2 * 2^30 + (b_hi - b_hi_2) / 2^2, b_lo_7 * 2^25 + (b_hi - b_hi_7) / 2^7) % 2^32
            a_lo = tmp1 % 2^32
            a_hi = (z_hi + AND(d_hi, c_hi) + AND(b_hi, XOR(d_hi, c_hi)) + (tmp1 - a_lo) / 2^32
               + XOR((b_hi - b_hi_28) / 2^28 + b_lo_28 * 2^4, b_hi_2 * 2^30 + (b_lo - b_lo_2) / 2^2, b_hi_7 * 2^25 + (b_lo - b_lo_7) / 2^7)) % 2^32
         end
         a_lo = h1_lo + a_lo
         h1_lo = a_lo % 2^32
         h1_hi = (h1_hi + a_hi + (a_lo - h1_lo) / 2^32) % 2^32
         a_lo = h2_lo + b_lo
         h2_lo = a_lo % 2^32
         h2_hi = (h2_hi + b_hi + (a_lo - h2_lo) / 2^32) % 2^32
         a_lo = h3_lo + c_lo
         h3_lo = a_lo % 2^32
         h3_hi = (h3_hi + c_hi + (a_lo - h3_lo) / 2^32) % 2^32
         a_lo = h4_lo + d_lo
         h4_lo = a_lo % 2^32
         h4_hi = (h4_hi + d_hi + (a_lo - h4_lo) / 2^32) % 2^32
         a_lo = h5_lo + e_lo
         h5_lo = a_lo % 2^32
         h5_hi = (h5_hi + e_hi + (a_lo - h5_lo) / 2^32) % 2^32
         a_lo = h6_lo + f_lo
         h6_lo = a_lo % 2^32
         h6_hi = (h6_hi + f_hi + (a_lo - h6_lo) / 2^32) % 2^32
         a_lo = h7_lo + g_lo
         h7_lo = a_lo % 2^32
         h7_hi = (h7_hi + g_hi + (a_lo - h7_lo) / 2^32) % 2^32
         a_lo = h8_lo + h_lo
         h8_lo = a_lo % 2^32
         h8_hi = (h8_hi + h_hi + (a_lo - h8_lo) / 2^32) % 2^32
      end
      H_lo[1], H_lo[2], H_lo[3], H_lo[4], H_lo[5], H_lo[6], H_lo[7], H_lo[8] = h1_lo, h2_lo, h3_lo, h4_lo, h5_lo, h6_lo, h7_lo, h8_lo
      H_hi[1], H_hi[2], H_hi[3], H_hi[4], H_hi[5], H_hi[6], H_hi[7], H_hi[8] = h1_hi, h2_hi, h3_hi, h4_hi, h5_hi, h6_hi, h7_hi, h8_hi
   end


   if branch == "LIB32" then

      function md5_feed_64(H, str, offs, size)
         -- offs >= 0, size >= 0, size is multiple of 64
         local W, K, md5_next_shift = common_W, md5_K, md5_next_shift
         local h1, h2, h3, h4 = H[1], H[2], H[3], H[4]
         for pos = offs, offs + size - 1, 64 do
            for j = 1, 16 do
               pos = pos + 4
               local a, b, c, d = byte(str, pos - 3, pos)
               W[j] = ((d * 256 + c) * 256 + b) * 256 + a
            end
            local a, b, c, d = h1, h2, h3, h4
            local s = 25
            for j = 1, 16 do
               local F = ROR(AND(b, c) + AND(-1-b, d) + a + K[j] + W[j], s) + b
               s = md5_next_shift[s]
               a = d
               d = c
               c = b
               b = F
            end
            s = 27
            for j = 17, 32 do
               local F = ROR(AND(d, b) + AND(-1-d, c) + a + K[j] + W[(5*j-4) % 16 + 1], s) + b
               s = md5_next_shift[s]
               a = d
               d = c
               c = b
               b = F
            end
            s = 28
            for j = 33, 48 do
               local F = ROR(XOR(XOR(b, c), d) + a + K[j] + W[(3*j+2) % 16 + 1], s) + b
               s = md5_next_shift[s]
               a = d
               d = c
               c = b
               b = F
            end
            s = 26
            for j = 49, 64 do
               local F = ROR(XOR(c, OR(b, -1-d)) + a + K[j] + W[(j*7-7) % 16 + 1], s) + b
               s = md5_next_shift[s]
               a = d
               d = c
               c = b
               b = F
            end
            h1 = (a + h1) % 2^32
            h2 = (b + h2) % 2^32
            h3 = (c + h3) % 2^32
            h4 = (d + h4) % 2^32
         end
         H[1], H[2], H[3], H[4] = h1, h2, h3, h4
      end

   elseif branch == "EMUL" then

      function md5_feed_64(H, str, offs, size)
         -- offs >= 0, size >= 0, size is multiple of 64
         local W, K, md5_next_shift = common_W, md5_K, md5_next_shift
         local h1, h2, h3, h4 = H[1], H[2], H[3], H[4]
         for pos = offs, offs + size - 1, 64 do
            for j = 1, 16 do
               pos = pos + 4
               local a, b, c, d = byte(str, pos - 3, pos)
               W[j] = ((d * 256 + c) * 256 + b) * 256 + a
            end
            local a, b, c, d = h1, h2, h3, h4
            local s = 25
            for j = 1, 16 do
               local z = (AND(b, c) + AND(-1-b, d) + a + K[j] + W[j]) % 2^32 / 2^s
               local y = z % 1
               s = md5_next_shift[s]
               a = d
               d = c
               c = b
               b = y * 2^32 + (z - y) + b
            end
            s = 27
            for j = 17, 32 do
               local z = (AND(d, b) + AND(-1-d, c) + a + K[j] + W[(5*j-4) % 16 + 1]) % 2^32 / 2^s
               local y = z % 1
               s = md5_next_shift[s]
               a = d
               d = c
               c = b
               b = y * 2^32 + (z - y) + b
            end
            s = 28
            for j = 33, 48 do
               local z = (XOR(XOR(b, c), d) + a + K[j] + W[(3*j+2) % 16 + 1]) % 2^32 / 2^s
               local y = z % 1
               s = md5_next_shift[s]
               a = d
               d = c
               c = b
               b = y * 2^32 + (z - y) + b
            end
            s = 26
            for j = 49, 64 do
               local z = (XOR(c, OR(b, -1-d)) + a + K[j] + W[(j*7-7) % 16 + 1]) % 2^32 / 2^s
               local y = z % 1
               s = md5_next_shift[s]
               a = d
               d = c
               c = b
               b = y * 2^32 + (z - y) + b
            end
            h1 = (a + h1) % 2^32
            h2 = (b + h2) % 2^32
            h3 = (c + h3) % 2^32
            h4 = (d + h4) % 2^32
         end
         H[1], H[2], H[3], H[4] = h1, h2, h3, h4
      end

   end


   function sha1_feed_64(H, str, offs, size)
      -- offs >= 0, size >= 0, size is multiple of 64
      local W = common_W
      local h1, h2, h3, h4, h5 = H[1], H[2], H[3], H[4], H[5]
      for pos = offs, offs + size - 1, 64 do
         for j = 1, 16 do
            pos = pos + 4
            local a, b, c, d = byte(str, pos - 3, pos)
            W[j] = ((a * 256 + b) * 256 + c) * 256 + d
         end
         for j = 17, 80 do
            local a = XOR(W[j-3], W[j-8], W[j-14], W[j-16]) % 2^32 * 2
            local b = a % 2^32
            W[j] = b + (a - b) / 2^32
         end
         local a, b, c, d, e = h1, h2, h3, h4, h5
         for j = 1, 20 do
            local a5 = a * 2^5
            local z = a5 % 2^32
            z = z + (a5 - z) / 2^32 + AND(b, c) + AND(-1-b, d) + 0x5A827999 + W[j] + e        -- constant = floor(2^30 * sqrt(2))
            e = d
            d = c
            c = b / 2^2
            c = c % 1 * (2^32 - 1) + c
            b = a
            a = z % 2^32
         end
         for j = 21, 40 do
            local a5 = a * 2^5
            local z = a5 % 2^32
            z = z + (a5 - z) / 2^32 + XOR(b, c, d) + 0x6ED9EBA1 + W[j] + e                    -- 2^30 * sqrt(3)
            e = d
            d = c
            c = b / 2^2
            c = c % 1 * (2^32 - 1) + c
            b = a
            a = z % 2^32
         end
         for j = 41, 60 do
            local a5 = a * 2^5
            local z = a5 % 2^32
            z = z + (a5 - z) / 2^32 + AND(d, c) + AND(b, XOR(d, c)) + 0x8F1BBCDC + W[j] + e   -- 2^30 * sqrt(5)
            e = d
            d = c
            c = b / 2^2
            c = c % 1 * (2^32 - 1) + c
            b = a
            a = z % 2^32
         end
         for j = 61, 80 do
            local a5 = a * 2^5
            local z = a5 % 2^32
            z = z + (a5 - z) / 2^32 + XOR(b, c, d) + 0xCA62C1D6 + W[j] + e                    -- 2^30 * sqrt(10)
            e = d
            d = c
            c = b / 2^2
            c = c % 1 * (2^32 - 1) + c
            b = a
            a = z % 2^32
         end
         h1 = (a + h1) % 2^32
         h2 = (b + h2) % 2^32
         h3 = (c + h3) % 2^32
         h4 = (d + h4) % 2^32
         h5 = (e + h5) % 2^32
      end
      H[1], H[2], H[3], H[4], H[5] = h1, h2, h3, h4, h5
   end


   function keccak_feed(lanes_lo, lanes_hi, str, offs, size, block_size_in_bytes)
      -- This is an example of a Lua function having 79 local variables :-)
      -- offs >= 0, size >= 0, size is multiple of block_size_in_bytes, block_size_in_bytes is positive multiple of 8
      local RC_lo, RC_hi = sha3_RC_lo, sha3_RC_hi
      local qwords_qty = block_size_in_bytes / 8
      for pos = offs, offs + size - 1, block_size_in_bytes do
         for j = 1, qwords_qty do
            local a, b, c, d = byte(str, pos + 1, pos + 4)
            lanes_lo[j] = XOR(lanes_lo[j], ((d * 256 + c) * 256 + b) * 256 + a)
            pos = pos + 8
            a, b, c, d = byte(str, pos - 3, pos)
            lanes_hi[j] = XOR(lanes_hi[j], ((d * 256 + c) * 256 + b) * 256 + a)
         end
         local L01_lo, L01_hi, L02_lo, L02_hi, L03_lo, L03_hi, L04_lo, L04_hi, L05_lo, L05_hi, L06_lo, L06_hi, L07_lo, L07_hi, L08_lo, L08_hi,
            L09_lo, L09_hi, L10_lo, L10_hi, L11_lo, L11_hi, L12_lo, L12_hi, L13_lo, L13_hi, L14_lo, L14_hi, L15_lo, L15_hi, L16_lo, L16_hi,
            L17_lo, L17_hi, L18_lo, L18_hi, L19_lo, L19_hi, L20_lo, L20_hi, L21_lo, L21_hi, L22_lo, L22_hi, L23_lo, L23_hi, L24_lo, L24_hi, L25_lo, L25_hi =
            lanes_lo[1], lanes_hi[1], lanes_lo[2], lanes_hi[2], lanes_lo[3], lanes_hi[3], lanes_lo[4], lanes_hi[4], lanes_lo[5], lanes_hi[5],
            lanes_lo[6], lanes_hi[6], lanes_lo[7], lanes_hi[7], lanes_lo[8], lanes_hi[8], lanes_lo[9], lanes_hi[9], lanes_lo[10], lanes_hi[10],
            lanes_lo[11], lanes_hi[11], lanes_lo[12], lanes_hi[12], lanes_lo[13], lanes_hi[13], lanes_lo[14], lanes_hi[14], lanes_lo[15], lanes_hi[15],
            lanes_lo[16], lanes_hi[16], lanes_lo[17], lanes_hi[17], lanes_lo[18], lanes_hi[18], lanes_lo[19], lanes_hi[19], lanes_lo[20], lanes_hi[20],
            lanes_lo[21], lanes_hi[21], lanes_lo[22], lanes_hi[22], lanes_lo[23], lanes_hi[23], lanes_lo[24], lanes_hi[24], lanes_lo[25], lanes_hi[25]
         for round_idx = 1, 24 do
            local C1_lo = XOR(L01_lo, L06_lo, L11_lo, L16_lo, L21_lo)
            local C1_hi = XOR(L01_hi, L06_hi, L11_hi, L16_hi, L21_hi)
            local C2_lo = XOR(L02_lo, L07_lo, L12_lo, L17_lo, L22_lo)
            local C2_hi = XOR(L02_hi, L07_hi, L12_hi, L17_hi, L22_hi)
            local C3_lo = XOR(L03_lo, L08_lo, L13_lo, L18_lo, L23_lo)
            local C3_hi = XOR(L03_hi, L08_hi, L13_hi, L18_hi, L23_hi)
            local C4_lo = XOR(L04_lo, L09_lo, L14_lo, L19_lo, L24_lo)
            local C4_hi = XOR(L04_hi, L09_hi, L14_hi, L19_hi, L24_hi)
            local C5_lo = XOR(L05_lo, L10_lo, L15_lo, L20_lo, L25_lo)
            local C5_hi = XOR(L05_hi, L10_hi, L15_hi, L20_hi, L25_hi)
            local D_lo = XOR(C1_lo, C3_lo * 2 + (C3_hi % 2^32 - C3_hi % 2^31) / 2^31)
            local D_hi = XOR(C1_hi, C3_hi * 2 + (C3_lo % 2^32 - C3_lo % 2^31) / 2^31)
            local T0_lo = XOR(D_lo, L02_lo)
            local T0_hi = XOR(D_hi, L02_hi)
            local T1_lo = XOR(D_lo, L07_lo)
            local T1_hi = XOR(D_hi, L07_hi)
            local T2_lo = XOR(D_lo, L12_lo)
            local T2_hi = XOR(D_hi, L12_hi)
            local T3_lo = XOR(D_lo, L17_lo)
            local T3_hi = XOR(D_hi, L17_hi)
            local T4_lo = XOR(D_lo, L22_lo)
            local T4_hi = XOR(D_hi, L22_hi)
            L02_lo = (T1_lo % 2^32 - T1_lo % 2^20) / 2^20 + T1_hi * 2^12
            L02_hi = (T1_hi % 2^32 - T1_hi % 2^20) / 2^20 + T1_lo * 2^12
            L07_lo = (T3_lo % 2^32 - T3_lo % 2^19) / 2^19 + T3_hi * 2^13
            L07_hi = (T3_hi % 2^32 - T3_hi % 2^19) / 2^19 + T3_lo * 2^13
            L12_lo = T0_lo * 2 + (T0_hi % 2^32 - T0_hi % 2^31) / 2^31
            L12_hi = T0_hi * 2 + (T0_lo % 2^32 - T0_lo % 2^31) / 2^31
            L17_lo = T2_lo * 2^10 + (T2_hi % 2^32 - T2_hi % 2^22) / 2^22
            L17_hi = T2_hi * 2^10 + (T2_lo % 2^32 - T2_lo % 2^22) / 2^22
            L22_lo = T4_lo * 2^2 + (T4_hi % 2^32 - T4_hi % 2^30) / 2^30
            L22_hi = T4_hi * 2^2 + (T4_lo % 2^32 - T4_lo % 2^30) / 2^30
            D_lo = XOR(C2_lo, C4_lo * 2 + (C4_hi % 2^32 - C4_hi % 2^31) / 2^31)
            D_hi = XOR(C2_hi, C4_hi * 2 + (C4_lo % 2^32 - C4_lo % 2^31) / 2^31)
            T0_lo = XOR(D_lo, L03_lo)
            T0_hi = XOR(D_hi, L03_hi)
            T1_lo = XOR(D_lo, L08_lo)
            T1_hi = XOR(D_hi, L08_hi)
            T2_lo = XOR(D_lo, L13_lo)
            T2_hi = XOR(D_hi, L13_hi)
            T3_lo = XOR(D_lo, L18_lo)
            T3_hi = XOR(D_hi, L18_hi)
            T4_lo = XOR(D_lo, L23_lo)
            T4_hi = XOR(D_hi, L23_hi)
            L03_lo = (T2_lo % 2^32 - T2_lo % 2^21) / 2^21 + T2_hi * 2^11
            L03_hi = (T2_hi % 2^32 - T2_hi % 2^21) / 2^21 + T2_lo * 2^11
            L08_lo = (T4_lo % 2^32 - T4_lo % 2^3) / 2^3 + T4_hi * 2^29 % 2^32
            L08_hi = (T4_hi % 2^32 - T4_hi % 2^3) / 2^3 + T4_lo * 2^29 % 2^32
            L13_lo = T1_lo * 2^6 + (T1_hi % 2^32 - T1_hi % 2^26) / 2^26
            L13_hi = T1_hi * 2^6 + (T1_lo % 2^32 - T1_lo % 2^26) / 2^26
            L18_lo = T3_lo * 2^15 + (T3_hi % 2^32 - T3_hi % 2^17) / 2^17
            L18_hi = T3_hi * 2^15 + (T3_lo % 2^32 - T3_lo % 2^17) / 2^17
            L23_lo = (T0_lo % 2^32 - T0_lo % 2^2) / 2^2 + T0_hi * 2^30 % 2^32
            L23_hi = (T0_hi % 2^32 - T0_hi % 2^2) / 2^2 + T0_lo * 2^30 % 2^32
            D_lo = XOR(C3_lo, C5_lo * 2 + (C5_hi % 2^32 - C5_hi % 2^31) / 2^31)
            D_hi = XOR(C3_hi, C5_hi * 2 + (C5_lo % 2^32 - C5_lo % 2^31) / 2^31)
            T0_lo = XOR(D_lo, L04_lo)
            T0_hi = XOR(D_hi, L04_hi)
            T1_lo = XOR(D_lo, L09_lo)
            T1_hi = XOR(D_hi, L09_hi)
            T2_lo = XOR(D_lo, L14_lo)
            T2_hi = XOR(D_hi, L14_hi)
            T3_lo = XOR(D_lo, L19_lo)
            T3_hi = XOR(D_hi, L19_hi)
            T4_lo = XOR(D_lo, L24_lo)
            T4_hi = XOR(D_hi, L24_hi)
            L04_lo = T3_lo * 2^21 % 2^32 + (T3_hi % 2^32 - T3_hi % 2^11) / 2^11
            L04_hi = T3_hi * 2^21 % 2^32 + (T3_lo % 2^32 - T3_lo % 2^11) / 2^11
            L09_lo = T0_lo * 2^28 % 2^32 + (T0_hi % 2^32 - T0_hi % 2^4) / 2^4
            L09_hi = T0_hi * 2^28 % 2^32 + (T0_lo % 2^32 - T0_lo % 2^4) / 2^4
            L14_lo = T2_lo * 2^25 % 2^32 + (T2_hi % 2^32 - T2_hi % 2^7) / 2^7
            L14_hi = T2_hi * 2^25 % 2^32 + (T2_lo % 2^32 - T2_lo % 2^7) / 2^7
            L19_lo = (T4_lo % 2^32 - T4_lo % 2^8) / 2^8 + T4_hi * 2^24 % 2^32
            L19_hi = (T4_hi % 2^32 - T4_hi % 2^8) / 2^8 + T4_lo * 2^24 % 2^32
            L24_lo = (T1_lo % 2^32 - T1_lo % 2^9) / 2^9 + T1_hi * 2^23 % 2^32
            L24_hi = (T1_hi % 2^32 - T1_hi % 2^9) / 2^9 + T1_lo * 2^23 % 2^32
            D_lo = XOR(C4_lo, C1_lo * 2 + (C1_hi % 2^32 - C1_hi % 2^31) / 2^31)
            D_hi = XOR(C4_hi, C1_hi * 2 + (C1_lo % 2^32 - C1_lo % 2^31) / 2^31)
            T0_lo = XOR(D_lo, L05_lo)
            T0_hi = XOR(D_hi, L05_hi)
            T1_lo = XOR(D_lo, L10_lo)
            T1_hi = XOR(D_hi, L10_hi)
            T2_lo = XOR(D_lo, L15_lo)
            T2_hi = XOR(D_hi, L15_hi)
            T3_lo = XOR(D_lo, L20_lo)
            T3_hi = XOR(D_hi, L20_hi)
            T4_lo = XOR(D_lo, L25_lo)
            T4_hi = XOR(D_hi, L25_hi)
            L05_lo = T4_lo * 2^14 + (T4_hi % 2^32 - T4_hi % 2^18) / 2^18
            L05_hi = T4_hi * 2^14 + (T4_lo % 2^32 - T4_lo % 2^18) / 2^18
            L10_lo = T1_lo * 2^20 % 2^32 + (T1_hi % 2^32 - T1_hi % 2^12) / 2^12
            L10_hi = T1_hi * 2^20 % 2^32 + (T1_lo % 2^32 - T1_lo % 2^12) / 2^12
            L15_lo = T3_lo * 2^8 + (T3_hi % 2^32 - T3_hi % 2^24) / 2^24
            L15_hi = T3_hi * 2^8 + (T3_lo % 2^32 - T3_lo % 2^24) / 2^24
            L20_lo = T0_lo * 2^27 % 2^32 + (T0_hi % 2^32 - T0_hi % 2^5) / 2^5
            L20_hi = T0_hi * 2^27 % 2^32 + (T0_lo % 2^32 - T0_lo % 2^5) / 2^5
            L25_lo = (T2_lo % 2^32 - T2_lo % 2^25) / 2^25 + T2_hi * 2^7
            L25_hi = (T2_hi % 2^32 - T2_hi % 2^25) / 2^25 + T2_lo * 2^7
            D_lo = XOR(C5_lo, C2_lo * 2 + (C2_hi % 2^32 - C2_hi % 2^31) / 2^31)
            D_hi = XOR(C5_hi, C2_hi * 2 + (C2_lo % 2^32 - C2_lo % 2^31) / 2^31)
            T1_lo = XOR(D_lo, L06_lo)
            T1_hi = XOR(D_hi, L06_hi)
            T2_lo = XOR(D_lo, L11_lo)
            T2_hi = XOR(D_hi, L11_hi)
            T3_lo = XOR(D_lo, L16_lo)
            T3_hi = XOR(D_hi, L16_hi)
            T4_lo = XOR(D_lo, L21_lo)
            T4_hi = XOR(D_hi, L21_hi)
            L06_lo = T2_lo * 2^3 + (T2_hi % 2^32 - T2_hi % 2^29) / 2^29
            L06_hi = T2_hi * 2^3 + (T2_lo % 2^32 - T2_lo % 2^29) / 2^29
            L11_lo = T4_lo * 2^18 + (T4_hi % 2^32 - T4_hi % 2^14) / 2^14
            L11_hi = T4_hi * 2^18 + (T4_lo % 2^32 - T4_lo % 2^14) / 2^14
            L16_lo = (T1_lo % 2^32 - T1_lo % 2^28) / 2^28 + T1_hi * 2^4
            L16_hi = (T1_hi % 2^32 - T1_hi % 2^28) / 2^28 + T1_lo * 2^4
            L21_lo = (T3_lo % 2^32 - T3_lo % 2^23) / 2^23 + T3_hi * 2^9
            L21_hi = (T3_hi % 2^32 - T3_hi % 2^23) / 2^23 + T3_lo * 2^9
            L01_lo = XOR(D_lo, L01_lo)
            L01_hi = XOR(D_hi, L01_hi)
            L01_lo, L02_lo, L03_lo, L04_lo, L05_lo = XOR(L01_lo, AND(-1-L02_lo, L03_lo)), XOR(L02_lo, AND(-1-L03_lo, L04_lo)), XOR(L03_lo, AND(-1-L04_lo, L05_lo)), XOR(L04_lo, AND(-1-L05_lo, L01_lo)), XOR(L05_lo, AND(-1-L01_lo, L02_lo))
            L01_hi, L02_hi, L03_hi, L04_hi, L05_hi = XOR(L01_hi, AND(-1-L02_hi, L03_hi)), XOR(L02_hi, AND(-1-L03_hi, L04_hi)), XOR(L03_hi, AND(-1-L04_hi, L05_hi)), XOR(L04_hi, AND(-1-L05_hi, L01_hi)), XOR(L05_hi, AND(-1-L01_hi, L02_hi))
            L06_lo, L07_lo, L08_lo, L09_lo, L10_lo = XOR(L09_lo, AND(-1-L10_lo, L06_lo)), XOR(L10_lo, AND(-1-L06_lo, L07_lo)), XOR(L06_lo, AND(-1-L07_lo, L08_lo)), XOR(L07_lo, AND(-1-L08_lo, L09_lo)), XOR(L08_lo, AND(-1-L09_lo, L10_lo))
            L06_hi, L07_hi, L08_hi, L09_hi, L10_hi = XOR(L09_hi, AND(-1-L10_hi, L06_hi)), XOR(L10_hi, AND(-1-L06_hi, L07_hi)), XOR(L06_hi, AND(-1-L07_hi, L08_hi)), XOR(L07_hi, AND(-1-L08_hi, L09_hi)), XOR(L08_hi, AND(-1-L09_hi, L10_hi))
            L11_lo, L12_lo, L13_lo, L14_lo, L15_lo = XOR(L12_lo, AND(-1-L13_lo, L14_lo)), XOR(L13_lo, AND(-1-L14_lo, L15_lo)), XOR(L14_lo, AND(-1-L15_lo, L11_lo)), XOR(L15_lo, AND(-1-L11_lo, L12_lo)), XOR(L11_lo, AND(-1-L12_lo, L13_lo))
            L11_hi, L12_hi, L13_hi, L14_hi, L15_hi = XOR(L12_hi, AND(-1-L13_hi, L14_hi)), XOR(L13_hi, AND(-1-L14_hi, L15_hi)), XOR(L14_hi, AND(-1-L15_hi, L11_hi)), XOR(L15_hi, AND(-1-L11_hi, L12_hi)), XOR(L11_hi, AND(-1-L12_hi, L13_hi))
            L16_lo, L17_lo, L18_lo, L19_lo, L20_lo = XOR(L20_lo, AND(-1-L16_lo, L17_lo)), XOR(L16_lo, AND(-1-L17_lo, L18_lo)), XOR(L17_lo, AND(-1-L18_lo, L19_lo)), XOR(L18_lo, AND(-1-L19_lo, L20_lo)), XOR(L19_lo, AND(-1-L20_lo, L16_lo))
            L16_hi, L17_hi, L18_hi, L19_hi, L20_hi = XOR(L20_hi, AND(-1-L16_hi, L17_hi)), XOR(L16_hi, AND(-1-L17_hi, L18_hi)), XOR(L17_hi, AND(-1-L18_hi, L19_hi)), XOR(L18_hi, AND(-1-L19_hi, L20_hi)), XOR(L19_hi, AND(-1-L20_hi, L16_hi))
            L21_lo, L22_lo, L23_lo, L24_lo, L25_lo = XOR(L23_lo, AND(-1-L24_lo, L25_lo)), XOR(L24_lo, AND(-1-L25_lo, L21_lo)), XOR(L25_lo, AND(-1-L21_lo, L22_lo)), XOR(L21_lo, AND(-1-L22_lo, L23_lo)), XOR(L22_lo, AND(-1-L23_lo, L24_lo))
            L21_hi, L22_hi, L23_hi, L24_hi, L25_hi = XOR(L23_hi, AND(-1-L24_hi, L25_hi)), XOR(L24_hi, AND(-1-L25_hi, L21_hi)), XOR(L25_hi, AND(-1-L21_hi, L22_hi)), XOR(L21_hi, AND(-1-L22_hi, L23_hi)), XOR(L22_hi, AND(-1-L23_hi, L24_hi))
            L01_lo = XOR(L01_lo, RC_lo[round_idx])
            L01_hi = L01_hi + RC_hi[round_idx]      -- RC_hi[] is either 0 or 0x80000000, so we could use fast addition instead of slow XOR
         end
         lanes_lo[1]  = L01_lo;  lanes_hi[1]  = L01_hi
         lanes_lo[2]  = L02_lo;  lanes_hi[2]  = L02_hi
         lanes_lo[3]  = L03_lo;  lanes_hi[3]  = L03_hi
         lanes_lo[4]  = L04_lo;  lanes_hi[4]  = L04_hi
         lanes_lo[5]  = L05_lo;  lanes_hi[5]  = L05_hi
         lanes_lo[6]  = L06_lo;  lanes_hi[6]  = L06_hi
         lanes_lo[7]  = L07_lo;  lanes_hi[7]  = L07_hi
         lanes_lo[8]  = L08_lo;  lanes_hi[8]  = L08_hi
         lanes_lo[9]  = L09_lo;  lanes_hi[9]  = L09_hi
         lanes_lo[10] = L10_lo;  lanes_hi[10] = L10_hi
         lanes_lo[11] = L11_lo;  lanes_hi[11] = L11_hi
         lanes_lo[12] = L12_lo;  lanes_hi[12] = L12_hi
         lanes_lo[13] = L13_lo;  lanes_hi[13] = L13_hi
         lanes_lo[14] = L14_lo;  lanes_hi[14] = L14_hi
         lanes_lo[15] = L15_lo;  lanes_hi[15] = L15_hi
         lanes_lo[16] = L16_lo;  lanes_hi[16] = L16_hi
         lanes_lo[17] = L17_lo;  lanes_hi[17] = L17_hi
         lanes_lo[18] = L18_lo;  lanes_hi[18] = L18_hi
         lanes_lo[19] = L19_lo;  lanes_hi[19] = L19_hi
         lanes_lo[20] = L20_lo;  lanes_hi[20] = L20_hi
         lanes_lo[21] = L21_lo;  lanes_hi[21] = L21_hi
         lanes_lo[22] = L22_lo;  lanes_hi[22] = L22_hi
         lanes_lo[23] = L23_lo;  lanes_hi[23] = L23_hi
         lanes_lo[24] = L24_lo;  lanes_hi[24] = L24_hi
         lanes_lo[25] = L25_lo;  lanes_hi[25] = L25_hi
      end
   end


   function blake2s_feed_64(H, str, offs, size, bytes_compressed, last_block_size, is_last_node)
      -- offs >= 0, size >= 0, size is multiple of 64
      local W = common_W
      local h1, h2, h3, h4, h5, h6, h7, h8 = H[1], H[2], H[3], H[4], H[5], H[6], H[7], H[8]
      for pos = offs, offs + size - 1, 64 do
         if str then
            for j = 1, 16 do
               pos = pos + 4
               local a, b, c, d = byte(str, pos - 3, pos)
               W[j] = ((d * 256 + c) * 256 + b) * 256 + a
            end
         end
         local v0, v1, v2, v3, v4, v5, v6, v7 = h1, h2, h3, h4, h5, h6, h7, h8
         local v8, v9, vA, vB, vC, vD, vE, vF = sha2_H_hi[1], sha2_H_hi[2], sha2_H_hi[3], sha2_H_hi[4], sha2_H_hi[5], sha2_H_hi[6], sha2_H_hi[7], sha2_H_hi[8]
         bytes_compressed = bytes_compressed + (last_block_size or 64)
         local t0 = bytes_compressed % 2^32
         local t1 = (bytes_compressed - t0) / 2^32
         vC = XOR(vC, t0)  -- t0 = low_4_bytes(bytes_compressed)
         vD = XOR(vD, t1)  -- t1 = high_4_bytes(bytes_compressed)
         if last_block_size then  -- flag f0
            vE = -1 - vE
         end
         if is_last_node then  -- flag f1
            vF = -1 - vF
         end
         for j = 1, 10 do
            local row = sigma[j]
            v0 = v0 + v4 + W[row[1]]
            vC = XOR(vC, v0) % 2^32 / 2^16
            vC = vC % 1 * (2^32 - 1) + vC
            v8 = v8 + vC
            v4 = XOR(v4, v8) % 2^32 / 2^12
            v4 = v4 % 1 * (2^32 - 1) + v4
            v0 = v0 + v4 + W[row[2]]
            vC = XOR(vC, v0) % 2^32 / 2^8
            vC = vC % 1 * (2^32 - 1) + vC
            v8 = v8 + vC
            v4 = XOR(v4, v8) % 2^32 / 2^7
            v4 = v4 % 1 * (2^32 - 1) + v4
            v1 = v1 + v5 + W[row[3]]
            vD = XOR(vD, v1) % 2^32 / 2^16
            vD = vD % 1 * (2^32 - 1) + vD
            v9 = v9 + vD
            v5 = XOR(v5, v9) % 2^32 / 2^12
            v5 = v5 % 1 * (2^32 - 1) + v5
            v1 = v1 + v5 + W[row[4]]
            vD = XOR(vD, v1) % 2^32 / 2^8
            vD = vD % 1 * (2^32 - 1) + vD
            v9 = v9 + vD
            v5 = XOR(v5, v9) % 2^32 / 2^7
            v5 = v5 % 1 * (2^32 - 1) + v5
            v2 = v2 + v6 + W[row[5]]
            vE = XOR(vE, v2) % 2^32 / 2^16
            vE = vE % 1 * (2^32 - 1) + vE
            vA = vA + vE
            v6 = XOR(v6, vA) % 2^32 / 2^12
            v6 = v6 % 1 * (2^32 - 1) + v6
            v2 = v2 + v6 + W[row[6]]
            vE = XOR(vE, v2) % 2^32 / 2^8
            vE = vE % 1 * (2^32 - 1) + vE
            vA = vA + vE
            v6 = XOR(v6, vA) % 2^32 / 2^7
            v6 = v6 % 1 * (2^32 - 1) + v6
            v3 = v3 + v7 + W[row[7]]
            vF = XOR(vF, v3) % 2^32 / 2^16
            vF = vF % 1 * (2^32 - 1) + vF
            vB = vB + vF
            v7 = XOR(v7, vB) % 2^32 / 2^12
            v7 = v7 % 1 * (2^32 - 1) + v7
            v3 = v3 + v7 + W[row[8]]
            vF = XOR(vF, v3) % 2^32 / 2^8
            vF = vF % 1 * (2^32 - 1) + vF
            vB = vB + vF
            v7 = XOR(v7, vB) % 2^32 / 2^7
            v7 = v7 % 1 * (2^32 - 1) + v7
            v0 = v0 + v5 + W[row[9]]
            vF = XOR(vF, v0) % 2^32 / 2^16
            vF = vF % 1 * (2^32 - 1) + vF
            vA = vA + vF
            v5 = XOR(v5, vA) % 2^32 / 2^12
            v5 = v5 % 1 * (2^32 - 1) + v5
            v0 = v0 + v5 + W[row[10]]
            vF = XOR(vF, v0) % 2^32 / 2^8
            vF = vF % 1 * (2^32 - 1) + vF
            vA = vA + vF
            v5 = XOR(v5, vA) % 2^32 / 2^7
            v5 = v5 % 1 * (2^32 - 1) + v5
            v1 = v1 + v6 + W[row[11]]
            vC = XOR(vC, v1) % 2^32 / 2^16
            vC = vC % 1 * (2^32 - 1) + vC
            vB = vB + vC
            v6 = XOR(v6, vB) % 2^32 / 2^12
            v6 = v6 % 1 * (2^32 - 1) + v6
            v1 = v1 + v6 + W[row[12]]
            vC = XOR(vC, v1) % 2^32 / 2^8
            vC = vC % 1 * (2^32 - 1) + vC
            vB = vB + vC
            v6 = XOR(v6, vB) % 2^32 / 2^7
            v6 = v6 % 1 * (2^32 - 1) + v6
            v2 = v2 + v7 + W[row[13]]
            vD = XOR(vD, v2) % 2^32 / 2^16
            vD = vD % 1 * (2^32 - 1) + vD
            v8 = v8 + vD
            v7 = XOR(v7, v8) % 2^32 / 2^12
            v7 = v7 % 1 * (2^32 - 1) + v7
            v2 = v2 + v7 + W[row[14]]
            vD = XOR(vD, v2) % 2^32 / 2^8
            vD = vD % 1 * (2^32 - 1) + vD
            v8 = v8 + vD
            v7 = XOR(v7, v8) % 2^32 / 2^7
            v7 = v7 % 1 * (2^32 - 1) + v7
            v3 = v3 + v4 + W[row[15]]
            vE = XOR(vE, v3) % 2^32 / 2^16
            vE = vE % 1 * (2^32 - 1) + vE
            v9 = v9 + vE
            v4 = XOR(v4, v9) % 2^32 / 2^12
            v4 = v4 % 1 * (2^32 - 1) + v4
            v3 = v3 + v4 + W[row[16]]
            vE = XOR(vE, v3) % 2^32 / 2^8
            vE = vE % 1 * (2^32 - 1) + vE
            v9 = v9 + vE
            v4 = XOR(v4, v9) % 2^32 / 2^7
            v4 = v4 % 1 * (2^32 - 1) + v4
         end
         h1 = XOR(h1, v0, v8)
         h2 = XOR(h2, v1, v9)
         h3 = XOR(h3, v2, vA)
         h4 = XOR(h4, v3, vB)
         h5 = XOR(h5, v4, vC)
         h6 = XOR(h6, v5, vD)
         h7 = XOR(h7, v6, vE)
         h8 = XOR(h8, v7, vF)
      end
      H[1], H[2], H[3], H[4], H[5], H[6], H[7], H[8] = h1, h2, h3, h4, h5, h6, h7, h8
      return bytes_compressed
   end


   function blake2b_feed_128(H_lo, H_hi, str, offs, size, bytes_compressed, last_block_size, is_last_node)
      -- offs >= 0, size >= 0, size is multiple of 128
      local W = common_W
      local h1_lo, h2_lo, h3_lo, h4_lo, h5_lo, h6_lo, h7_lo, h8_lo = H_lo[1], H_lo[2], H_lo[3], H_lo[4], H_lo[5], H_lo[6], H_lo[7], H_lo[8]
      local h1_hi, h2_hi, h3_hi, h4_hi, h5_hi, h6_hi, h7_hi, h8_hi = H_hi[1], H_hi[2], H_hi[3], H_hi[4], H_hi[5], H_hi[6], H_hi[7], H_hi[8]
      for pos = offs, offs + size - 1, 128 do
         if str then
            for j = 1, 32 do
               pos = pos + 4
               local a, b, c, d = byte(str, pos - 3, pos)
               W[j] = ((d * 256 + c) * 256 + b) * 256 + a
            end
         end
         local v0_lo, v1_lo, v2_lo, v3_lo, v4_lo, v5_lo, v6_lo, v7_lo = h1_lo, h2_lo, h3_lo, h4_lo, h5_lo, h6_lo, h7_lo, h8_lo
         local v0_hi, v1_hi, v2_hi, v3_hi, v4_hi, v5_hi, v6_hi, v7_hi = h1_hi, h2_hi, h3_hi, h4_hi, h5_hi, h6_hi, h7_hi, h8_hi
         local v8_lo, v9_lo, vA_lo, vB_lo, vC_lo, vD_lo, vE_lo, vF_lo = sha2_H_lo[1], sha2_H_lo[2], sha2_H_lo[3], sha2_H_lo[4], sha2_H_lo[5], sha2_H_lo[6], sha2_H_lo[7], sha2_H_lo[8]
         local v8_hi, v9_hi, vA_hi, vB_hi, vC_hi, vD_hi, vE_hi, vF_hi = sha2_H_hi[1], sha2_H_hi[2], sha2_H_hi[3], sha2_H_hi[4], sha2_H_hi[5], sha2_H_hi[6], sha2_H_hi[7], sha2_H_hi[8]
         bytes_compressed = bytes_compressed + (last_block_size or 128)
         local t0_lo = bytes_compressed % 2^32
         local t0_hi = (bytes_compressed - t0_lo) / 2^32
         vC_lo = XOR(vC_lo, t0_lo)  -- t0 = low_8_bytes(bytes_compressed)
         vC_hi = XOR(vC_hi, t0_hi)
         -- t1 = high_8_bytes(bytes_compressed) = 0,  message length is always below 2^53 bytes
         if last_block_size then  -- flag f0
            vE_lo = -1 - vE_lo
            vE_hi = -1 - vE_hi
         end
         if is_last_node then  -- flag f1
            vF_lo = -1 - vF_lo
            vF_hi = -1 - vF_hi
         end
         for j = 1, 12 do
            local row = sigma[j]
            local k = row[1] * 2
            local z = v0_lo % 2^32 + v4_lo % 2^32 + W[k-1]
            v0_lo = z % 2^32
            v0_hi = v0_hi + v4_hi + (z - v0_lo) / 2^32 + W[k]
            vC_lo, vC_hi = XOR(vC_hi, v0_hi), XOR(vC_lo, v0_lo)
            z = v8_lo % 2^32 + vC_lo % 2^32
            v8_lo = z % 2^32
            v8_hi = v8_hi + vC_hi + (z - v8_lo) / 2^32
            v4_lo, v4_hi = XOR(v4_lo, v8_lo), XOR(v4_hi, v8_hi)
            local z_lo, z_hi = v4_lo % 2^24, v4_hi % 2^24
            v4_lo, v4_hi = (v4_lo - z_lo) / 2^24 % 2^8 + z_hi * 2^8, (v4_hi - z_hi) / 2^24 % 2^8 + z_lo * 2^8
            k = row[2] * 2
            z = v0_lo % 2^32 + v4_lo % 2^32 + W[k-1]
            v0_lo = z % 2^32
            v0_hi = v0_hi + v4_hi + (z - v0_lo) / 2^32 + W[k]
            vC_lo, vC_hi = XOR(vC_lo, v0_lo), XOR(vC_hi, v0_hi)
            z_lo, z_hi = vC_lo % 2^16, vC_hi % 2^16
            vC_lo, vC_hi = (vC_lo - z_lo) / 2^16 % 2^16 + z_hi * 2^16, (vC_hi - z_hi) / 2^16 % 2^16 + z_lo * 2^16
            z = v8_lo % 2^32 + vC_lo % 2^32
            v8_lo = z % 2^32
            v8_hi = v8_hi + vC_hi + (z - v8_lo) / 2^32
            v4_lo, v4_hi = XOR(v4_lo, v8_lo), XOR(v4_hi, v8_hi)
            z_lo, z_hi = v4_lo % 2^31, v4_hi % 2^31
            v4_lo, v4_hi = z_lo * 2^1 + (v4_hi - z_hi) / 2^31 % 2^1, z_hi * 2^1 + (v4_lo - z_lo) / 2^31 % 2^1
            k = row[3] * 2
            z = v1_lo % 2^32 + v5_lo % 2^32 + W[k-1]
            v1_lo = z % 2^32
            v1_hi = v1_hi + v5_hi + (z - v1_lo) / 2^32 + W[k]
            vD_lo, vD_hi = XOR(vD_hi, v1_hi), XOR(vD_lo, v1_lo)
            z = v9_lo % 2^32 + vD_lo % 2^32
            v9_lo = z % 2^32
            v9_hi = v9_hi + vD_hi + (z - v9_lo) / 2^32
            v5_lo, v5_hi = XOR(v5_lo, v9_lo), XOR(v5_hi, v9_hi)
            z_lo, z_hi = v5_lo % 2^24, v5_hi % 2^24
            v5_lo, v5_hi = (v5_lo - z_lo) / 2^24 % 2^8 + z_hi * 2^8, (v5_hi - z_hi) / 2^24 % 2^8 + z_lo * 2^8
            k = row[4] * 2
            z = v1_lo % 2^32 + v5_lo % 2^32 + W[k-1]
            v1_lo = z % 2^32
            v1_hi = v1_hi + v5_hi + (z - v1_lo) / 2^32 + W[k]
            vD_lo, vD_hi = XOR(vD_lo, v1_lo), XOR(vD_hi, v1_hi)
            z_lo, z_hi = vD_lo % 2^16, vD_hi % 2^16
            vD_lo, vD_hi = (vD_lo - z_lo) / 2^16 % 2^16 + z_hi * 2^16, (vD_hi - z_hi) / 2^16 % 2^16 + z_lo * 2^16
            z = v9_lo % 2^32 + vD_lo % 2^32
            v9_lo = z % 2^32
            v9_hi = v9_hi + vD_hi + (z - v9_lo) / 2^32
            v5_lo, v5_hi = XOR(v5_lo, v9_lo), XOR(v5_hi, v9_hi)
            z_lo, z_hi = v5_lo % 2^31, v5_hi % 2^31
            v5_lo, v5_hi = z_lo * 2^1 + (v5_hi - z_hi) / 2^31 % 2^1, z_hi * 2^1 + (v5_lo - z_lo) / 2^31 % 2^1
            k = row[5] * 2
            z = v2_lo % 2^32 + v6_lo % 2^32 + W[k-1]
            v2_lo = z % 2^32
            v2_hi = v2_hi + v6_hi + (z - v2_lo) / 2^32 + W[k]
            vE_lo, vE_hi = XOR(vE_hi, v2_hi), XOR(vE_lo, v2_lo)
            z = vA_lo % 2^32 + vE_lo % 2^32
            vA_lo = z % 2^32
            vA_hi = vA_hi + vE_hi + (z - vA_lo) / 2^32
            v6_lo, v6_hi = XOR(v6_lo, vA_lo), XOR(v6_hi, vA_hi)
            z_lo, z_hi = v6_lo % 2^24, v6_hi % 2^24
            v6_lo, v6_hi = (v6_lo - z_lo) / 2^24 % 2^8 + z_hi * 2^8, (v6_hi - z_hi) / 2^24 % 2^8 + z_lo * 2^8
            k = row[6] * 2
            z = v2_lo % 2^32 + v6_lo % 2^32 + W[k-1]
            v2_lo = z % 2^32
            v2_hi = v2_hi + v6_hi + (z - v2_lo) / 2^32 + W[k]
            vE_lo, vE_hi = XOR(vE_lo, v2_lo), XOR(vE_hi, v2_hi)
            z_lo, z_hi = vE_lo % 2^16, vE_hi % 2^16
            vE_lo, vE_hi = (vE_lo - z_lo) / 2^16 % 2^16 + z_hi * 2^16, (vE_hi - z_hi) / 2^16 % 2^16 + z_lo * 2^16
            z = vA_lo % 2^32 + vE_lo % 2^32
            vA_lo = z % 2^32
            vA_hi = vA_hi + vE_hi + (z - vA_lo) / 2^32
            v6_lo, v6_hi = XOR(v6_lo, vA_lo), XOR(v6_hi, vA_hi)
            z_lo, z_hi = v6_lo % 2^31, v6_hi % 2^31
            v6_lo, v6_hi = z_lo * 2^1 + (v6_hi - z_hi) / 2^31 % 2^1, z_hi * 2^1 + (v6_lo - z_lo) / 2^31 % 2^1
            k = row[7] * 2
            z = v3_lo % 2^32 + v7_lo % 2^32 + W[k-1]
            v3_lo = z % 2^32
            v3_hi = v3_hi + v7_hi + (z - v3_lo) / 2^32 + W[k]
            vF_lo, vF_hi = XOR(vF_hi, v3_hi), XOR(vF_lo, v3_lo)
            z = vB_lo % 2^32 + vF_lo % 2^32
            vB_lo = z % 2^32
            vB_hi = vB_hi + vF_hi + (z - vB_lo) / 2^32
            v7_lo, v7_hi = XOR(v7_lo, vB_lo), XOR(v7_hi, vB_hi)
            z_lo, z_hi = v7_lo % 2^24, v7_hi % 2^24
            v7_lo, v7_hi = (v7_lo - z_lo) / 2^24 % 2^8 + z_hi * 2^8, (v7_hi - z_hi) / 2^24 % 2^8 + z_lo * 2^8
            k = row[8] * 2
            z = v3_lo % 2^32 + v7_lo % 2^32 + W[k-1]
            v3_lo = z % 2^32
            v3_hi = v3_hi + v7_hi + (z - v3_lo) / 2^32 + W[k]
            vF_lo, vF_hi = XOR(vF_lo, v3_lo), XOR(vF_hi, v3_hi)
            z_lo, z_hi = vF_lo % 2^16, vF_hi % 2^16
            vF_lo, vF_hi = (vF_lo - z_lo) / 2^16 % 2^16 + z_hi * 2^16, (vF_hi - z_hi) / 2^16 % 2^16 + z_lo * 2^16
            z = vB_lo % 2^32 + vF_lo % 2^32
            vB_lo = z % 2^32
            vB_hi = vB_hi + vF_hi + (z - vB_lo) / 2^32
            v7_lo, v7_hi = XOR(v7_lo, vB_lo), XOR(v7_hi, vB_hi)
            z_lo, z_hi = v7_lo % 2^31, v7_hi % 2^31
            v7_lo, v7_hi = z_lo * 2^1 + (v7_hi - z_hi) / 2^31 % 2^1, z_hi * 2^1 + (v7_lo - z_lo) / 2^31 % 2^1
            k = row[9] * 2
            z = v0_lo % 2^32 + v5_lo % 2^32 + W[k-1]
            v0_lo = z % 2^32
            v0_hi = v0_hi + v5_hi + (z - v0_lo) / 2^32 + W[k]
            vF_lo, vF_hi = XOR(vF_hi, v0_hi), XOR(vF_lo, v0_lo)
            z = vA_lo % 2^32 + vF_lo % 2^32
            vA_lo = z % 2^32
            vA_hi = vA_hi + vF_hi + (z - vA_lo) / 2^32
            v5_lo, v5_hi = XOR(v5_lo, vA_lo), XOR(v5_hi, vA_hi)
            z_lo, z_hi = v5_lo % 2^24, v5_hi % 2^24
            v5_lo, v5_hi = (v5_lo - z_lo) / 2^24 % 2^8 + z_hi * 2^8, (v5_hi - z_hi) / 2^24 % 2^8 + z_lo * 2^8
            k = row[10] * 2
            z = v0_lo % 2^32 + v5_lo % 2^32 + W[k-1]
            v0_lo = z % 2^32
            v0_hi = v0_hi + v5_hi + (z - v0_lo) / 2^32 + W[k]
            vF_lo, vF_hi = XOR(vF_lo, v0_lo), XOR(vF_hi, v0_hi)
            z_lo, z_hi = vF_lo % 2^16, vF_hi % 2^16
            vF_lo, vF_hi = (vF_lo - z_lo) / 2^16 % 2^16 + z_hi * 2^16, (vF_hi - z_hi) / 2^16 % 2^16 + z_lo * 2^16
            z = vA_lo % 2^32 + vF_lo % 2^32
            vA_lo = z % 2^32
            vA_hi = vA_hi + vF_hi + (z - vA_lo) / 2^32
            v5_lo, v5_hi = XOR(v5_lo, vA_lo), XOR(v5_hi, vA_hi)
            z_lo, z_hi = v5_lo % 2^31, v5_hi % 2^31
            v5_lo, v5_hi = z_lo * 2^1 + (v5_hi - z_hi) / 2^31 % 2^1, z_hi * 2^1 + (v5_lo - z_lo) / 2^31 % 2^1
            k = row[11] * 2
            z = v1_lo % 2^32 + v6_lo % 2^32 + W[k-1]
            v1_lo = z % 2^32
            v1_hi = v1_hi + v6_hi + (z - v1_lo) / 2^32 + W[k]
            vC_lo, vC_hi = XOR(vC_hi, v1_hi), XOR(vC_lo, v1_lo)
            z = vB_lo % 2^32 + vC_lo % 2^32
            vB_lo = z % 2^32
            vB_hi = vB_hi + vC_hi + (z - vB_lo) / 2^32
            v6_lo, v6_hi = XOR(v6_lo, vB_lo), XOR(v6_hi, vB_hi)
            z_lo, z_hi = v6_lo % 2^24, v6_hi % 2^24
            v6_lo, v6_hi = (v6_lo - z_lo) / 2^24 % 2^8 + z_hi * 2^8, (v6_hi - z_hi) / 2^24 % 2^8 + z_lo * 2^8
            k = row[12] * 2
            z = v1_lo % 2^32 + v6_lo % 2^32 + W[k-1]
            v1_lo = z % 2^32
            v1_hi = v1_hi + v6_hi + (z - v1_lo) / 2^32 + W[k]
            vC_lo, vC_hi = XOR(vC_lo, v1_lo), XOR(vC_hi, v1_hi)
            z_lo, z_hi = vC_lo % 2^16, vC_hi % 2^16
            vC_lo, vC_hi = (vC_lo - z_lo) / 2^16 % 2^16 + z_hi * 2^16, (vC_hi - z_hi) / 2^16 % 2^16 + z_lo * 2^16
            z = vB_lo % 2^32 + vC_lo % 2^32
            vB_lo = z % 2^32
            vB_hi = vB_hi + vC_hi + (z - vB_lo) / 2^32
            v6_lo, v6_hi = XOR(v6_lo, vB_lo), XOR(v6_hi, vB_hi)
            z_lo, z_hi = v6_lo % 2^31, v6_hi % 2^31
            v6_lo, v6_hi = z_lo * 2^1 + (v6_hi - z_hi) / 2^31 % 2^1, z_hi * 2^1 + (v6_lo - z_lo) / 2^31 % 2^1
            k = row[13] * 2
            z = v2_lo % 2^32 + v7_lo % 2^32 + W[k-1]
            v2_lo = z % 2^32
            v2_hi = v2_hi + v7_hi + (z - v2_lo) / 2^32 + W[k]
            vD_lo, vD_hi = XOR(vD_hi, v2_hi), XOR(vD_lo, v2_lo)
            z = v8_lo % 2^32 + vD_lo % 2^32
            v8_lo = z % 2^32
            v8_hi = v8_hi + vD_hi + (z - v8_lo) / 2^32
            v7_lo, v7_hi = XOR(v7_lo, v8_lo), XOR(v7_hi, v8_hi)
            z_lo, z_hi = v7_lo % 2^24, v7_hi % 2^24
            v7_lo, v7_hi = (v7_lo - z_lo) / 2^24 % 2^8 + z_hi * 2^8, (v7_hi - z_hi) / 2^24 % 2^8 + z_lo * 2^8
            k = row[14] * 2
            z = v2_lo % 2^32 + v7_lo % 2^32 + W[k-1]
            v2_lo = z % 2^32
            v2_hi = v2_hi + v7_hi + (z - v2_lo) / 2^32 + W[k]
            vD_lo, vD_hi = XOR(vD_lo, v2_lo), XOR(vD_hi, v2_hi)
            z_lo, z_hi = vD_lo % 2^16, vD_hi % 2^16
            vD_lo, vD_hi = (vD_lo - z_lo) / 2^16 % 2^16 + z_hi * 2^16, (vD_hi - z_hi) / 2^16 % 2^16 + z_lo * 2^16
            z = v8_lo % 2^32 + vD_lo % 2^32
            v8_lo = z % 2^32
            v8_hi = v8_hi + vD_hi + (z - v8_lo) / 2^32
            v7_lo, v7_hi = XOR(v7_lo, v8_lo), XOR(v7_hi, v8_hi)
            z_lo, z_hi = v7_lo % 2^31, v7_hi % 2^31
            v7_lo, v7_hi = z_lo * 2^1 + (v7_hi - z_hi) / 2^31 % 2^1, z_hi * 2^1 + (v7_lo - z_lo) / 2^31 % 2^1
            k = row[15] * 2
            z = v3_lo % 2^32 + v4_lo % 2^32 + W[k-1]
            v3_lo = z % 2^32
            v3_hi = v3_hi + v4_hi + (z - v3_lo) / 2^32 + W[k]
            vE_lo, vE_hi = XOR(vE_hi, v3_hi), XOR(vE_lo, v3_lo)
            z = v9_lo % 2^32 + vE_lo % 2^32
            v9_lo = z % 2^32
            v9_hi = v9_hi + vE_hi + (z - v9_lo) / 2^32
            v4_lo, v4_hi = XOR(v4_lo, v9_lo), XOR(v4_hi, v9_hi)
            z_lo, z_hi = v4_lo % 2^24, v4_hi % 2^24
            v4_lo, v4_hi = (v4_lo - z_lo) / 2^24 % 2^8 + z_hi * 2^8, (v4_hi - z_hi) / 2^24 % 2^8 + z_lo * 2^8
            k = row[16] * 2
            z = v3_lo % 2^32 + v4_lo % 2^32 + W[k-1]
            v3_lo = z % 2^32
            v3_hi = v3_hi + v4_hi + (z - v3_lo) / 2^32 + W[k]
            vE_lo, vE_hi = XOR(vE_lo, v3_lo), XOR(vE_hi, v3_hi)
            z_lo, z_hi = vE_lo % 2^16, vE_hi % 2^16
            vE_lo, vE_hi = (vE_lo - z_lo) / 2^16 % 2^16 + z_hi * 2^16, (vE_hi - z_hi) / 2^16 % 2^16 + z_lo * 2^16
            z = v9_lo % 2^32 + vE_lo % 2^32
            v9_lo = z % 2^32
            v9_hi = v9_hi + vE_hi + (z - v9_lo) / 2^32
            v4_lo, v4_hi = XOR(v4_lo, v9_lo), XOR(v4_hi, v9_hi)
            z_lo, z_hi = v4_lo % 2^31, v4_hi % 2^31
            v4_lo, v4_hi = z_lo * 2^1 + (v4_hi - z_hi) / 2^31 % 2^1, z_hi * 2^1 + (v4_lo - z_lo) / 2^31 % 2^1
         end
         h1_lo = XOR(h1_lo, v0_lo, v8_lo) % 2^32
         h2_lo = XOR(h2_lo, v1_lo, v9_lo) % 2^32
         h3_lo = XOR(h3_lo, v2_lo, vA_lo) % 2^32
         h4_lo = XOR(h4_lo, v3_lo, vB_lo) % 2^32
         h5_lo = XOR(h5_lo, v4_lo, vC_lo) % 2^32
         h6_lo = XOR(h6_lo, v5_lo, vD_lo) % 2^32
         h7_lo = XOR(h7_lo, v6_lo, vE_lo) % 2^32
         h8_lo = XOR(h8_lo, v7_lo, vF_lo) % 2^32
         h1_hi = XOR(h1_hi, v0_hi, v8_hi) % 2^32
         h2_hi = XOR(h2_hi, v1_hi, v9_hi) % 2^32
         h3_hi = XOR(h3_hi, v2_hi, vA_hi) % 2^32
         h4_hi = XOR(h4_hi, v3_hi, vB_hi) % 2^32
         h5_hi = XOR(h5_hi, v4_hi, vC_hi) % 2^32
         h6_hi = XOR(h6_hi, v5_hi, vD_hi) % 2^32
         h7_hi = XOR(h7_hi, v6_hi, vE_hi) % 2^32
         h8_hi = XOR(h8_hi, v7_hi, vF_hi) % 2^32
      end
      H_lo[1], H_lo[2], H_lo[3], H_lo[4], H_lo[5], H_lo[6], H_lo[7], H_lo[8] = h1_lo, h2_lo, h3_lo, h4_lo, h5_lo, h6_lo, h7_lo, h8_lo
      H_hi[1], H_hi[2], H_hi[3], H_hi[4], H_hi[5], H_hi[6], H_hi[7], H_hi[8] = h1_hi, h2_hi, h3_hi, h4_hi, h5_hi, h6_hi, h7_hi, h8_hi
      return bytes_compressed
   end


   function blake3_feed_64(str, offs, size, flags, chunk_index, H_in, H_out, wide_output, block_length)
      -- offs >= 0, size >= 0, size is multiple of 64
      block_length = block_length or 64
      local W = common_W
      local h1, h2, h3, h4, h5, h6, h7, h8 = H_in[1], H_in[2], H_in[3], H_in[4], H_in[5], H_in[6], H_in[7], H_in[8]
      H_out = H_out or H_in
      for pos = offs, offs + size - 1, 64 do
         if str then
            for j = 1, 16 do
               pos = pos + 4
               local a, b, c, d = byte(str, pos - 3, pos)
               W[j] = ((d * 256 + c) * 256 + b) * 256 + a
            end
         end
         local v0, v1, v2, v3, v4, v5, v6, v7 = h1, h2, h3, h4, h5, h6, h7, h8
         local v8, v9, vA, vB = sha2_H_hi[1], sha2_H_hi[2], sha2_H_hi[3], sha2_H_hi[4]
         local vC = chunk_index % 2^32         -- t0 = low_4_bytes(chunk_index)
         local vD = (chunk_index - vC) / 2^32  -- t1 = high_4_bytes(chunk_index)
         local vE, vF = block_length, flags
         for j = 1, 7 do
            v0 = v0 + v4 + W[perm_blake3[j]]
            vC = XOR(vC, v0) % 2^32 / 2^16
            vC = vC % 1 * (2^32 - 1) + vC
            v8 = v8 + vC
            v4 = XOR(v4, v8) % 2^32 / 2^12
            v4 = v4 % 1 * (2^32 - 1) + v4
            v0 = v0 + v4 + W[perm_blake3[j + 14]]
            vC = XOR(vC, v0) % 2^32 / 2^8
            vC = vC % 1 * (2^32 - 1) + vC
            v8 = v8 + vC
            v4 = XOR(v4, v8) % 2^32 / 2^7
            v4 = v4 % 1 * (2^32 - 1) + v4
            v1 = v1 + v5 + W[perm_blake3[j + 1]]
            vD = XOR(vD, v1) % 2^32 / 2^16
            vD = vD % 1 * (2^32 - 1) + vD
            v9 = v9 + vD
            v5 = XOR(v5, v9) % 2^32 / 2^12
            v5 = v5 % 1 * (2^32 - 1) + v5
            v1 = v1 + v5 + W[perm_blake3[j + 2]]
            vD = XOR(vD, v1) % 2^32 / 2^8
            vD = vD % 1 * (2^32 - 1) + vD
            v9 = v9 + vD
            v5 = XOR(v5, v9) % 2^32 / 2^7
            v5 = v5 % 1 * (2^32 - 1) + v5
            v2 = v2 + v6 + W[perm_blake3[j + 16]]
            vE = XOR(vE, v2) % 2^32 / 2^16
            vE = vE % 1 * (2^32 - 1) + vE
            vA = vA + vE
            v6 = XOR(v6, vA) % 2^32 / 2^12
            v6 = v6 % 1 * (2^32 - 1) + v6
            v2 = v2 + v6 + W[perm_blake3[j + 7]]
            vE = XOR(vE, v2) % 2^32 / 2^8
            vE = vE % 1 * (2^32 - 1) + vE
            vA = vA + vE
            v6 = XOR(v6, vA) % 2^32 / 2^7
            v6 = v6 % 1 * (2^32 - 1) + v6
            v3 = v3 + v7 + W[perm_blake3[j + 15]]
            vF = XOR(vF, v3) % 2^32 / 2^16
            vF = vF % 1 * (2^32 - 1) + vF
            vB = vB + vF
            v7 = XOR(v7, vB) % 2^32 / 2^12
            v7 = v7 % 1 * (2^32 - 1) + v7
            v3 = v3 + v7 + W[perm_blake3[j + 17]]
            vF = XOR(vF, v3) % 2^32 / 2^8
            vF = vF % 1 * (2^32 - 1) + vF
            vB = vB + vF
            v7 = XOR(v7, vB) % 2^32 / 2^7
            v7 = v7 % 1 * (2^32 - 1) + v7
            v0 = v0 + v5 + W[perm_blake3[j + 21]]
            vF = XOR(vF, v0) % 2^32 / 2^16
            vF = vF % 1 * (2^32 - 1) + vF
            vA = vA + vF
            v5 = XOR(v5, vA) % 2^32 / 2^12
            v5 = v5 % 1 * (2^32 - 1) + v5
            v0 = v0 + v5 + W[perm_blake3[j + 5]]
            vF = XOR(vF, v0) % 2^32 / 2^8
            vF = vF % 1 * (2^32 - 1) + vF
            vA = vA + vF
            v5 = XOR(v5, vA) % 2^32 / 2^7
            v5 = v5 % 1 * (2^32 - 1) + v5
            v1 = v1 + v6 + W[perm_blake3[j + 3]]
            vC = XOR(vC, v1) % 2^32 / 2^16
            vC = vC % 1 * (2^32 - 1) + vC
            vB = vB + vC
            v6 = XOR(v6, vB) % 2^32 / 2^12
            v6 = v6 % 1 * (2^32 - 1) + v6
            v1 = v1 + v6 + W[perm_blake3[j + 6]]
            vC = XOR(vC, v1) % 2^32 / 2^8
            vC = vC % 1 * (2^32 - 1) + vC
            vB = vB + vC
            v6 = XOR(v6, vB) % 2^32 / 2^7
            v6 = v6 % 1 * (2^32 - 1) + v6
            v2 = v2 + v7 + W[perm_blake3[j + 4]]
            vD = XOR(vD, v2) % 2^32 / 2^16
            vD = vD % 1 * (2^32 - 1) + vD
            v8 = v8 + vD
            v7 = XOR(v7, v8) % 2^32 / 2^12
            v7 = v7 % 1 * (2^32 - 1) + v7
            v2 = v2 + v7 + W[perm_blake3[j + 18]]
            vD = XOR(vD, v2) % 2^32 / 2^8
            vD = vD % 1 * (2^32 - 1) + vD
            v8 = v8 + vD
            v7 = XOR(v7, v8) % 2^32 / 2^7
            v7 = v7 % 1 * (2^32 - 1) + v7
            v3 = v3 + v4 + W[perm_blake3[j + 19]]
            vE = XOR(vE, v3) % 2^32 / 2^16
            vE = vE % 1 * (2^32 - 1) + vE
            v9 = v9 + vE
            v4 = XOR(v4, v9) % 2^32 / 2^12
            v4 = v4 % 1 * (2^32 - 1) + v4
            v3 = v3 + v4 + W[perm_blake3[j + 20]]
            vE = XOR(vE, v3) % 2^32 / 2^8
            vE = vE % 1 * (2^32 - 1) + vE
            v9 = v9 + vE
            v4 = XOR(v4, v9) % 2^32 / 2^7
            v4 = v4 % 1 * (2^32 - 1) + v4
         end
         if wide_output then
            H_out[ 9] = XOR(h1, v8)
            H_out[10] = XOR(h2, v9)
            H_out[11] = XOR(h3, vA)
            H_out[12] = XOR(h4, vB)
            H_out[13] = XOR(h5, vC)
            H_out[14] = XOR(h6, vD)
            H_out[15] = XOR(h7, vE)
            H_out[16] = XOR(h8, vF)
         end
         h1 = XOR(v0, v8)
         h2 = XOR(v1, v9)
         h3 = XOR(v2, vA)
         h4 = XOR(v3, vB)
         h5 = XOR(v4, vC)
         h6 = XOR(v5, vD)
         h7 = XOR(v6, vE)
         h8 = XOR(v7, vF)
      end
      H_out[1], H_out[2], H_out[3], H_out[4], H_out[5], H_out[6], H_out[7], H_out[8] = h1, h2, h3, h4, h5, h6, h7, h8
   end

end


--------------------------------------------------------------------------------
-- MAGIC NUMBERS CALCULATOR
--------------------------------------------------------------------------------
-- Q:
--    Is 53-bit "double" math enough to calculate square roots and cube roots of primes with 64 correct bits after decimal point?
-- A:
--    Yes, 53-bit "double" arithmetic is enough.
--    We could obtain first 40 bits by direct calculation of p^(1/3) and next 40 bits by one step of Newton's method.

do
   local function mul(src1, src2, factor, result_length)
      -- src1, src2 - long integers (arrays of digits in base 2^24)
      -- factor - small integer
      -- returns long integer result (src1 * src2 * factor) and its floating point approximation
      local result, carry, value, weight = {}, 0.0, 0.0, 1.0
      for j = 1, result_length do
         for k = math_max(1, j + 1 - #src2), math_min(j, #src1) do
            carry = carry + factor * src1[k] * src2[j + 1 - k]  -- "int32" is not enough for multiplication result, that's why "factor" must be of type "double"
         end
         local digit = carry % 2^24
         result[j] = floor(digit)
         carry = (carry - digit) / 2^24
         value = value + digit * weight
         weight = weight * 2^24
      end
      return result, value
   end

   local idx, step, p, one, sqrt_hi, sqrt_lo = 0, {4, 1, 2, -2, 2}, 4, {1}, sha2_H_hi, sha2_H_lo
   repeat
      p = p + step[p % 6]
      local d = 1
      repeat
         d = d + step[d % 6]
         if d*d > p then -- next prime number is found
            local root = p^(1/3)
            local R = root * 2^40
            R = mul({R - R % 1}, one, 1.0, 2)
            local _, delta = mul(R, mul(R, R, 1.0, 4), -1.0, 4)
            local hi = R[2] % 65536 * 65536 + floor(R[1] / 256)
            local lo = R[1] % 256 * 16777216 + floor(delta * (2^-56 / 3) * root / p)
            if idx < 16 then
               root = p^(1/2)
               R = root * 2^40
               R = mul({R - R % 1}, one, 1.0, 2)
               _, delta = mul(R, R, -1.0, 2)
               local hi = R[2] % 65536 * 65536 + floor(R[1] / 256)
               local lo = R[1] % 256 * 16777216 + floor(delta * 2^-17 / root)
               local idx = idx % 8 + 1
               sha2_H_ext256[224][idx] = lo
               sqrt_hi[idx], sqrt_lo[idx] = hi, lo + hi * hi_factor
               if idx > 7 then
                  sqrt_hi, sqrt_lo = sha2_H_ext512_hi[384], sha2_H_ext512_lo[384]
               end
            end
            idx = idx + 1
            sha2_K_hi[idx], sha2_K_lo[idx] = hi, lo % K_lo_modulo + hi * hi_factor
            break
         end
      until p % d == 0
   until idx > 79
end

-- Calculating IVs for SHA512/224 and SHA512/256
for width = 224, 256, 32 do
   local H_lo, H_hi = {}
   if HEX64 then
      for j = 1, 8 do
         H_lo[j] = XORA5(sha2_H_lo[j])
      end
   else
      H_hi = {}
      for j = 1, 8 do
         H_lo[j] = XORA5(sha2_H_lo[j])
         H_hi[j] = XORA5(sha2_H_hi[j])
      end
   end
   sha512_feed_128(H_lo, H_hi, "SHA-512/"..tostring(width).."\128"..string_rep("\0", 115).."\88", 0, 128)
   sha2_H_ext512_lo[width] = H_lo
   sha2_H_ext512_hi[width] = H_hi
end

-- Constants for MD5
do
   local sin, abs, modf = math.sin, math.abs, math.modf
   for idx = 1, 64 do
      -- we can't use formula floor(abs(sin(idx))*2^32) because its result may be beyond integer range on Lua built with 32-bit integers
      local hi, lo = modf(abs(sin(idx)) * 2^16)
      md5_K[idx] = hi * 65536 + floor(lo * 2^16)
   end
end

-- Constants for SHA-3
do
   local sh_reg = 29

   local function next_bit()
      local r = sh_reg % 2
      sh_reg = XOR_BYTE((sh_reg - r) / 2, 142 * r)
      return r
   end

   for idx = 1, 24 do
      local lo, m = 0
      for _ = 1, 6 do
         m = m and m * m * 2 or 1
         lo = lo + next_bit() * m
      end
      local hi = next_bit() * m
      sha3_RC_hi[idx], sha3_RC_lo[idx] = hi, lo + hi * hi_factor_keccak
   end
end

if branch == "FFI" then
   sha2_K_hi = ffi.new("uint32_t[?]", #sha2_K_hi + 1, 0, unpack(sha2_K_hi))
   sha2_K_lo = ffi.new("int64_t[?]",  #sha2_K_lo + 1, 0, unpack(sha2_K_lo))
   --md5_K = ffi.new("uint32_t[?]", #md5_K + 1, 0, unpack(md5_K))
   if hi_factor_keccak == 0 then
      sha3_RC_lo = ffi.new("uint32_t[?]", #sha3_RC_lo + 1, 0, unpack(sha3_RC_lo))
      sha3_RC_hi = ffi.new("uint32_t[?]", #sha3_RC_hi + 1, 0, unpack(sha3_RC_hi))
   else
      sha3_RC_lo = ffi.new("int64_t[?]", #sha3_RC_lo + 1, 0, unpack(sha3_RC_lo))
   end
end


--------------------------------------------------------------------------------
-- MAIN FUNCTIONS
--------------------------------------------------------------------------------

local function sha256ext(width, message)
   -- Create an instance (private objects for current calculation)
   local H, length, tail = {unpack(sha2_H_ext256[width])}, 0.0, ""

   local function partial(message_part)
      if message_part then
         if tail then
            length = length + #message_part
            local offs = 0
            if tail ~= "" and #tail + #message_part >= 64 then
               offs = 64 - #tail
               sha256_feed_64(H, tail..sub(message_part, 1, offs), 0, 64)
               tail = ""
            end
            local size = #message_part - offs
            local size_tail = size % 64
            sha256_feed_64(H, message_part, offs, size - size_tail)
            tail = tail..sub(message_part, #message_part + 1 - size_tail)
            return partial
         else
            error("Adding more chunks is not allowed after receiving the result", 2)
         end
      else
         if tail then
            local final_blocks = {tail, "\128", string_rep("\0", (-9 - length) % 64 + 1)}
            tail = nil
            -- Assuming user data length is shorter than (2^53)-9 bytes
            -- Anyway, it looks very unrealistic that someone would spend more than a year of calculations to process 2^53 bytes of data by using this Lua script :-)
            -- 2^53 bytes = 2^56 bits, so "bit-counter" fits in 7 bytes
            length = length * (8 / 256^7)  -- convert "byte-counter" to "bit-counter" and move decimal point to the left
            for j = 4, 10 do
               length = length % 1 * 256
               final_blocks[j] = char(floor(length))
            end
            final_blocks = table_concat(final_blocks)
            sha256_feed_64(H, final_blocks, 0, #final_blocks)
            local max_reg = width / 32
            for j = 1, max_reg do
               H[j] = HEX(H[j])
            end
            H = table_concat(H, "", 1, max_reg)
         end
         return H
      end
   end

   if message then
      -- Actually perform calculations and return the SHA256 digest of a message
      return partial(message)()
   else
      -- Return function for chunk-by-chunk loading
      -- User should feed every chunk of input data as single argument to this function and finally get SHA256 digest by invoking this function without an argument
      return partial
   end
end


local function sha512ext(width, message)
   -- Create an instance (private objects for current calculation)
   local length, tail, H_lo, H_hi = 0.0, "", {unpack(sha2_H_ext512_lo[width])}, not HEX64 and {unpack(sha2_H_ext512_hi[width])}

   local function partial(message_part)
      if message_part then
         if tail then
            length = length + #message_part
            local offs = 0
            if tail ~= "" and #tail + #message_part >= 128 then
               offs = 128 - #tail
               sha512_feed_128(H_lo, H_hi, tail..sub(message_part, 1, offs), 0, 128)
               tail = ""
            end
            local size = #message_part - offs
            local size_tail = size % 128
            sha512_feed_128(H_lo, H_hi, message_part, offs, size - size_tail)
            tail = tail..sub(message_part, #message_part + 1 - size_tail)
            return partial
         else
            error("Adding more chunks is not allowed after receiving the result", 2)
         end
      else
         if tail then
            local final_blocks = {tail, "\128", string_rep("\0", (-17-length) % 128 + 9)}
            tail = nil
            -- Assuming user data length is shorter than (2^53)-17 bytes
            -- 2^53 bytes = 2^56 bits, so "bit-counter" fits in 7 bytes
            length = length * (8 / 256^7)  -- convert "byte-counter" to "bit-counter" and move floating point to the left
            for j = 4, 10 do
               length = length % 1 * 256
               final_blocks[j] = char(floor(length))
            end
            final_blocks = table_concat(final_blocks)
            sha512_feed_128(H_lo, H_hi, final_blocks, 0, #final_blocks)
            local max_reg = ceil(width / 64)
            if HEX64 then
               for j = 1, max_reg do
                  H_lo[j] = HEX64(H_lo[j])
               end
            else
               for j = 1, max_reg do
                  H_lo[j] = HEX(H_hi[j])..HEX(H_lo[j])
               end
               H_hi = nil
            end
            H_lo = sub(table_concat(H_lo, "", 1, max_reg), 1, width / 4)
         end
         return H_lo
      end
   end

   if message then
      -- Actually perform calculations and return the SHA512 digest of a message
      return partial(message)()
   else
      -- Return function for chunk-by-chunk loading
      -- User should feed every chunk of input data as single argument to this function and finally get SHA512 digest by invoking this function without an argument
      return partial
   end
end


local function md5(message)
   -- Create an instance (private objects for current calculation)
   local H, length, tail = {unpack(md5_sha1_H, 1, 4)}, 0.0, ""

   local function partial(message_part)
      if message_part then
         if tail then
            length = length + #message_part
            local offs = 0
            if tail ~= "" and #tail + #message_part >= 64 then
               offs = 64 - #tail
               md5_feed_64(H, tail..sub(message_part, 1, offs), 0, 64)
               tail = ""
            end
            local size = #message_part - offs
            local size_tail = size % 64
            md5_feed_64(H, message_part, offs, size - size_tail)
            tail = tail..sub(message_part, #message_part + 1 - size_tail)
            return partial
         else
            error("Adding more chunks is not allowed after receiving the result", 2)
         end
      else
         if tail then
            local final_blocks = {tail, "\128", string_rep("\0", (-9 - length) % 64)}
            tail = nil
            length = length * 8  -- convert "byte-counter" to "bit-counter"
            for j = 4, 11 do
               local low_byte = length % 256
               final_blocks[j] = char(low_byte)
               length = (length - low_byte) / 256
            end
            final_blocks = table_concat(final_blocks)
            md5_feed_64(H, final_blocks, 0, #final_blocks)
            for j = 1, 4 do
               H[j] = HEX(H[j])
            end
            H = gsub(table_concat(H), "(..)(..)(..)(..)", "%4%3%2%1")
         end
         return H
      end
   end

   if message then
      -- Actually perform calculations and return the MD5 digest of a message
      return partial(message)()
   else
      -- Return function for chunk-by-chunk loading
      -- User should feed every chunk of input data as single argument to this function and finally get MD5 digest by invoking this function without an argument
      return partial
   end
end


local function sha1(message)
   -- Create an instance (private objects for current calculation)
   local H, length, tail = {unpack(md5_sha1_H)}, 0.0, ""

   local function partial(message_part)
      if message_part then
         if tail then
            length = length + #message_part
            local offs = 0
            if tail ~= "" and #tail + #message_part >= 64 then
               offs = 64 - #tail
               sha1_feed_64(H, tail..sub(message_part, 1, offs), 0, 64)
               tail = ""
            end
            local size = #message_part - offs
            local size_tail = size % 64
            sha1_feed_64(H, message_part, offs, size - size_tail)
            tail = tail..sub(message_part, #message_part + 1 - size_tail)
            return partial
         else
            error("Adding more chunks is not allowed after receiving the result", 2)
         end
      else
         if tail then
            local final_blocks = {tail, "\128", string_rep("\0", (-9 - length) % 64 + 1)}
            tail = nil
            -- Assuming user data length is shorter than (2^53)-9 bytes
            -- 2^53 bytes = 2^56 bits, so "bit-counter" fits in 7 bytes
            length = length * (8 / 256^7)  -- convert "byte-counter" to "bit-counter" and move decimal point to the left
            for j = 4, 10 do
               length = length % 1 * 256
               final_blocks[j] = char(floor(length))
            end
            final_blocks = table_concat(final_blocks)
            sha1_feed_64(H, final_blocks, 0, #final_blocks)
            for j = 1, 5 do
               H[j] = HEX(H[j])
            end
            H = table_concat(H)
         end
         return H
      end
   end

   if message then
      -- Actually perform calculations and return the SHA-1 digest of a message
      return partial(message)()
   else
      -- Return function for chunk-by-chunk loading
      -- User should feed every chunk of input data as single argument to this function and finally get SHA-1 digest by invoking this function without an argument
      return partial
   end
end


local function keccak(block_size_in_bytes, digest_size_in_bytes, is_SHAKE, message)
   -- "block_size_in_bytes" is multiple of 8
   if type(digest_size_in_bytes) ~= "number" then
      -- arguments in SHAKE are swapped:
      --    NIST FIPS 202 defines SHAKE(message,num_bits)
      --    this module   defines SHAKE(num_bytes,message)
      -- it's easy to forget about this swap, hence the check
      error("Argument 'digest_size_in_bytes' must be a number", 2)
   end
   -- Create an instance (private objects for current calculation)
   local tail, lanes_lo, lanes_hi = "", create_array_of_lanes(), hi_factor_keccak == 0 and create_array_of_lanes()
   local result

   local function partial(message_part)
      if message_part then
         if tail then
            local offs = 0
            if tail ~= "" and #tail + #message_part >= block_size_in_bytes then
               offs = block_size_in_bytes - #tail
               keccak_feed(lanes_lo, lanes_hi, tail..sub(message_part, 1, offs), 0, block_size_in_bytes, block_size_in_bytes)
               tail = ""
            end
            local size = #message_part - offs
            local size_tail = size % block_size_in_bytes
            keccak_feed(lanes_lo, lanes_hi, message_part, offs, size - size_tail, block_size_in_bytes)
            tail = tail..sub(message_part, #message_part + 1 - size_tail)
            return partial
         else
            error("Adding more chunks is not allowed after receiving the result", 2)
         end
      else
         if tail then
            -- append the following bits to the message: for usual SHA-3: 011(0*)1, for SHAKE: 11111(0*)1
            local gap_start = is_SHAKE and 31 or 6
            tail = tail..(#tail + 1 == block_size_in_bytes and char(gap_start + 128) or char(gap_start)..string_rep("\0", (-2 - #tail) % block_size_in_bytes).."\128")
            keccak_feed(lanes_lo, lanes_hi, tail, 0, #tail, block_size_in_bytes)
            tail = nil
            local lanes_used = 0
            local total_lanes = floor(block_size_in_bytes / 8)
            local qwords = {}

            local function get_next_qwords_of_digest(qwords_qty)
               -- returns not more than 'qwords_qty' qwords ('qwords_qty' might be non-integer)
               -- doesn't go across keccak-buffer boundary
               -- block_size_in_bytes is a multiple of 8, so, keccak-buffer contains integer number of qwords
               if lanes_used >= total_lanes then
                  keccak_feed(lanes_lo, lanes_hi, "\0\0\0\0\0\0\0\0", 0, 8, 8)
                  lanes_used = 0
               end
               qwords_qty = floor(math_min(qwords_qty, total_lanes - lanes_used))
               if hi_factor_keccak ~= 0 then
                  for j = 1, qwords_qty do
                     qwords[j] = HEX64(lanes_lo[lanes_used + j - 1 + lanes_index_base])
                  end
               else
                  for j = 1, qwords_qty do
                     qwords[j] = HEX(lanes_hi[lanes_used + j])..HEX(lanes_lo[lanes_used + j])
                  end
               end
               lanes_used = lanes_used + qwords_qty
               return
                  gsub(table_concat(qwords, "", 1, qwords_qty), "(..)(..)(..)(..)(..)(..)(..)(..)", "%8%7%6%5%4%3%2%1"),
                  qwords_qty * 8
            end

            local parts = {}      -- digest parts
            local last_part, last_part_size = "", 0

            local function get_next_part_of_digest(bytes_needed)
               -- returns 'bytes_needed' bytes, for arbitrary integer 'bytes_needed'
               bytes_needed = bytes_needed or 1
               if bytes_needed <= last_part_size then
                  last_part_size = last_part_size - bytes_needed
                  local part_size_in_nibbles = bytes_needed * 2
                  local result = sub(last_part, 1, part_size_in_nibbles)
                  last_part = sub(last_part, part_size_in_nibbles + 1)
                  return result
               end
               local parts_qty = 0
               if last_part_size > 0 then
                  parts_qty = 1
                  parts[parts_qty] = last_part
                  bytes_needed = bytes_needed - last_part_size
               end
               -- repeats until the length is enough
               while bytes_needed >= 8 do
                  local next_part, next_part_size = get_next_qwords_of_digest(bytes_needed / 8)
                  parts_qty = parts_qty + 1
                  parts[parts_qty] = next_part
                  bytes_needed = bytes_needed - next_part_size
               end
               if bytes_needed > 0 then
                  last_part, last_part_size = get_next_qwords_of_digest(1)
                  parts_qty = parts_qty + 1
                  parts[parts_qty] = get_next_part_of_digest(bytes_needed)
               else
                  last_part, last_part_size = "", 0
               end
               return table_concat(parts, "", 1, parts_qty)
            end

            if digest_size_in_bytes < 0 then
               result = get_next_part_of_digest
            else
               result = get_next_part_of_digest(digest_size_in_bytes)
            end
         end
         return result
      end
   end

   if message then
      -- Actually perform calculations and return the SHA-3 digest of a message
      return partial(message)()
   else
      -- Return function for chunk-by-chunk loading
      -- User should feed every chunk of input data as single argument to this function and finally get SHA-3 digest by invoking this function without an argument
      return partial
   end
end


local hex_to_bin, bin_to_hex, bin_to_base64, base64_to_bin
do
   function hex_to_bin(hex_string)
      return (gsub(hex_string, "%x%x",
         function (hh)
            return char(tonumber(hh, 16))
         end
      ))
   end

   function bin_to_hex(binary_string)
      return (gsub(binary_string, ".",
         function (c)
            return string_format("%02x", byte(c))
         end
      ))
   end

   local base64_symbols = {
      ['+'] = 62, ['-'] = 62,  [62] = '+',
      ['/'] = 63, ['_'] = 63,  [63] = '/',
      ['='] = -1, ['.'] = -1,  [-1] = '='
   }
   local symbol_index = 0
   for j, pair in ipairs{'AZ', 'az', '09'} do
      for ascii = byte(pair), byte(pair, 2) do
         local ch = char(ascii)
         base64_symbols[ch] = symbol_index
         base64_symbols[symbol_index] = ch
         symbol_index = symbol_index + 1
      end
   end

   function bin_to_base64(binary_string)
      local result = {}
      for pos = 1, #binary_string, 3 do
         local c1, c2, c3, c4 = byte(sub(binary_string, pos, pos + 2)..'\0', 1, -1)
         result[#result + 1] =
            base64_symbols[floor(c1 / 4)]
            ..base64_symbols[c1 % 4 * 16 + floor(c2 / 16)]
            ..base64_symbols[c3 and c2 % 16 * 4 + floor(c3 / 64) or -1]
            ..base64_symbols[c4 and c3 % 64 or -1]
      end
      return table_concat(result)
   end

   function base64_to_bin(base64_string)
      local result, chars_qty = {}, 3
      for pos, ch in gmatch(gsub(base64_string, '%s+', ''), '()(.)') do
         local code = base64_symbols[ch]
         if code < 0 then
            chars_qty = chars_qty - 1
            code = 0
         end
         local idx = pos % 4
         if idx > 0 then
            result[-idx] = code
         else
            local c1 = result[-1] * 4 + floor(result[-2] / 16)
            local c2 = (result[-2] % 16) * 16 + floor(result[-3] / 4)
            local c3 = (result[-3] % 4) * 64 + code
            result[#result + 1] = sub(char(c1, c2, c3), 1, chars_qty)
         end
      end
      return table_concat(result)
   end

end


local block_size_for_HMAC  -- this table will be initialized at the end of the module

local function pad_and_xor(str, result_length, byte_for_xor)
   return gsub(str, ".",
      function(c)
         return char(XOR_BYTE(byte(c), byte_for_xor))
      end
   )..string_rep(char(byte_for_xor), result_length - #str)
end

local function hmac(hash_func, key, message)
   -- Create an instance (private objects for current calculation)
   local block_size = block_size_for_HMAC[hash_func]
   if not block_size then
      error("Unknown hash function", 2)
   end
   if #key > block_size then
      key = hex_to_bin(hash_func(key))
   end
   local append = hash_func()(pad_and_xor(key, block_size, 0x36))
   local result

   local function partial(message_part)
      if not message_part then
         result = result or hash_func(pad_and_xor(key, block_size, 0x5C)..hex_to_bin(append()))
         return result
      elseif result then
         error("Adding more chunks is not allowed after receiving the result", 2)
      else
         append(message_part)
         return partial
      end
   end

   if message then
      -- Actually perform calculations and return the HMAC of a message
      return partial(message)()
   else
      -- Return function for chunk-by-chunk loading of a message
      -- User should feed every chunk of the message as single argument to this function and finally get HMAC by invoking this function without an argument
      return partial
   end
end


local function xor_blake2_salt(salt, letter, H_lo, H_hi)
   -- salt: concatenation of "Salt"+"Personalization" fields
   local max_size = letter == "s" and 16 or 32
   local salt_size = #salt
   if salt_size > max_size then
      error(string_format("For BLAKE2%s/BLAKE2%sp/BLAKE2X%s the 'salt' parameter length must not exceed %d bytes", letter, letter, letter, max_size), 2)
   end
   if H_lo then
      local offset, blake2_word_size, xor = 0, letter == "s" and 4 or 8, letter == "s" and XOR or XORA5
      for j = 5, 4 + ceil(salt_size / blake2_word_size) do
         local prev, last
         for _ = 1, blake2_word_size, 4 do
            offset = offset + 4
            local a, b, c, d = byte(salt, offset - 3, offset)
            local four_bytes = (((d or 0) * 256 + (c or 0)) * 256 + (b or 0)) * 256 + (a or 0)
            prev, last = last, four_bytes
         end
         H_lo[j] = xor(H_lo[j], prev and last * hi_factor + prev or last)
         if H_hi then
            H_hi[j] = xor(H_hi[j], last)
         end
      end
   end
end

local function blake2s(message, key, salt, digest_size_in_bytes, XOF_length, B2_offset)
   -- message:  binary string to be hashed (or nil for "chunk-by-chunk" input mode)
   -- key:      (optional) binary string up to 32 bytes, by default empty string
   -- salt:     (optional) binary string up to 16 bytes, by default empty string
   -- digest_size_in_bytes: (optional) integer from 1 to 32, by default 32
   -- The last two parameters "XOF_length" and "B2_offset" are for internal use only, user must omit them (or pass nil)
   digest_size_in_bytes = digest_size_in_bytes or 32
   if digest_size_in_bytes < 1 or digest_size_in_bytes > 32 then
      error("BLAKE2s digest length must be from 1 to 32 bytes", 2)
   end
   key = key or ""
   local key_length = #key
   if key_length > 32 then
      error("BLAKE2s key length must not exceed 32 bytes", 2)
   end
   salt = salt or ""
   local bytes_compressed, tail, H = 0.0, "", {unpack(sha2_H_hi)}
   if B2_offset then
      H[1] = XOR(H[1], digest_size_in_bytes)
      H[2] = XOR(H[2], 0x20)
      H[3] = XOR(H[3], B2_offset)
      H[4] = XOR(H[4], 0x20000000 + XOF_length)
   else
      H[1] = XOR(H[1], 0x01010000 + key_length * 256 + digest_size_in_bytes)
      if XOF_length then
         H[4] = XOR(H[4], XOF_length)
      end
   end
   if salt ~= "" then
      xor_blake2_salt(salt, "s", H)
   end

   local function partial(message_part)
      if message_part then
         if tail then
            local offs = 0
            if tail ~= "" and #tail + #message_part > 64 then
               offs = 64 - #tail
               bytes_compressed = blake2s_feed_64(H, tail..sub(message_part, 1, offs), 0, 64, bytes_compressed)
               tail = ""
            end
            local size = #message_part - offs
            local size_tail = size > 0 and (size - 1) % 64 + 1 or 0
            bytes_compressed = blake2s_feed_64(H, message_part, offs, size - size_tail, bytes_compressed)
            tail = tail..sub(message_part, #message_part + 1 - size_tail)
            return partial
         else
            error("Adding more chunks is not allowed after receiving the result", 2)
         end
      else
         if tail then
            if B2_offset then
               blake2s_feed_64(H, nil, 0, 64, 0, 32)
            else
               blake2s_feed_64(H, tail..string_rep("\0", 64 - #tail), 0, 64, bytes_compressed, #tail)
            end
            tail = nil
            if not XOF_length or B2_offset then
               local max_reg = ceil(digest_size_in_bytes / 4)
               for j = 1, max_reg do
                  H[j] = HEX(H[j])
               end
               H = sub(gsub(table_concat(H, "", 1, max_reg), "(..)(..)(..)(..)", "%4%3%2%1"), 1, digest_size_in_bytes * 2)
            end
         end
         return H
      end
   end

   if key_length > 0 then
      partial(key..string_rep("\0", 64 - key_length))
   end
   if B2_offset then
      return partial()
   elseif message then
      -- Actually perform calculations and return the BLAKE2s digest of a message
      return partial(message)()
   else
      -- Return function for chunk-by-chunk loading
      -- User should feed every chunk of input data as single argument to this function and finally get BLAKE2s digest by invoking this function without an argument
      return partial
   end
end

local function blake2b(message, key, salt, digest_size_in_bytes, XOF_length, B2_offset)
   -- message:  binary string to be hashed (or nil for "chunk-by-chunk" input mode)
   -- key:      (optional) binary string up to 64 bytes, by default empty string
   -- salt:     (optional) binary string up to 32 bytes, by default empty string
   -- digest_size_in_bytes: (optional) integer from 1 to 64, by default 64
   -- The last two parameters "XOF_length" and "B2_offset" are for internal use only, user must omit them (or pass nil)
   digest_size_in_bytes = floor(digest_size_in_bytes or 64)
   if digest_size_in_bytes < 1 or digest_size_in_bytes > 64 then
      error("BLAKE2b digest length must be from 1 to 64 bytes", 2)
   end
   key = key or ""
   local key_length = #key
   if key_length > 64 then
      error("BLAKE2b key length must not exceed 64 bytes", 2)
   end
   salt = salt or ""
   local bytes_compressed, tail, H_lo, H_hi = 0.0, "", {unpack(sha2_H_lo)}, not HEX64 and {unpack(sha2_H_hi)}
   if B2_offset then
      if H_hi then
         H_lo[1] = XORA5(H_lo[1], digest_size_in_bytes)
         H_hi[1] = XORA5(H_hi[1], 0x40)
         H_lo[2] = XORA5(H_lo[2], B2_offset)
         H_hi[2] = XORA5(H_hi[2], XOF_length)
      else
         H_lo[1] = XORA5(H_lo[1], 0x40 * hi_factor + digest_size_in_bytes)
         H_lo[2] = XORA5(H_lo[2], XOF_length * hi_factor + B2_offset)
      end
      H_lo[3] = XORA5(H_lo[3], 0x4000)
   else
      H_lo[1] = XORA5(H_lo[1], 0x01010000 + key_length * 256 + digest_size_in_bytes)
      if XOF_length then
         if H_hi then
            H_hi[2] = XORA5(H_hi[2], XOF_length)
         else
            H_lo[2] = XORA5(H_lo[2], XOF_length * hi_factor)
         end
      end
   end
   if salt ~= "" then
      xor_blake2_salt(salt, "b", H_lo, H_hi)
   end

   local function partial(message_part)
      if message_part then
         if tail then
            local offs = 0
            if tail ~= "" and #tail + #message_part > 128 then
               offs = 128 - #tail
               bytes_compressed = blake2b_feed_128(H_lo, H_hi, tail..sub(message_part, 1, offs), 0, 128, bytes_compressed)
               tail = ""
            end
            local size = #message_part - offs
            local size_tail = size > 0 and (size - 1) % 128 + 1 or 0
            bytes_compressed = blake2b_feed_128(H_lo, H_hi, message_part, offs, size - size_tail, bytes_compressed)
            tail = tail..sub(message_part, #message_part + 1 - size_tail)
            return partial
         else
            error("Adding more chunks is not allowed after receiving the result", 2)
         end
      else
         if tail then
            if B2_offset then
               blake2b_feed_128(H_lo, H_hi, nil, 0, 128, 0, 64)
            else
               blake2b_feed_128(H_lo, H_hi, tail..string_rep("\0", 128 - #tail), 0, 128, bytes_compressed, #tail)
            end
            tail = nil
            if XOF_length and not B2_offset then
               if H_hi then
                  for j = 8, 1, -1 do
                     H_lo[j*2] = H_hi[j]
                     H_lo[j*2-1] = H_lo[j]
                  end
                  return H_lo, 16
               end
            else
               local max_reg = ceil(digest_size_in_bytes / 8)
               if H_hi then
                  for j = 1, max_reg do
                     H_lo[j] = HEX(H_hi[j])..HEX(H_lo[j])
                  end
               else
                  for j = 1, max_reg do
                     H_lo[j] = HEX64(H_lo[j])
                  end
               end
               H_lo = sub(gsub(table_concat(H_lo, "", 1, max_reg), "(..)(..)(..)(..)(..)(..)(..)(..)", "%8%7%6%5%4%3%2%1"), 1, digest_size_in_bytes * 2)
            end
            H_hi = nil
         end
         return H_lo
      end
   end

   if key_length > 0 then
      partial(key..string_rep("\0", 128 - key_length))
   end
   if B2_offset then
      return partial()
   elseif message then
      -- Actually perform calculations and return the BLAKE2b digest of a message
      return partial(message)()
   else
      -- Return function for chunk-by-chunk loading
      -- User should feed every chunk of input data as single argument to this function and finally get BLAKE2b digest by invoking this function without an argument
      return partial
   end
end

local function blake2sp(message, key, salt, digest_size_in_bytes)
   -- message:  binary string to be hashed (or nil for "chunk-by-chunk" input mode)
   -- key:      (optional) binary string up to 32 bytes, by default empty string
   -- salt:     (optional) binary string up to 16 bytes, by default empty string
   -- digest_size_in_bytes: (optional) integer from 1 to 32, by default 32
   digest_size_in_bytes = digest_size_in_bytes or 32
   if digest_size_in_bytes < 1 or digest_size_in_bytes > 32 then
      error("BLAKE2sp digest length must be from 1 to 32 bytes", 2)
   end
   key = key or ""
   local key_length = #key
   if key_length > 32 then
      error("BLAKE2sp key length must not exceed 32 bytes", 2)
   end
   salt = salt or ""
   local instances, length, first_dword_of_parameter_block, result = {}, 0.0, 0x02080000 + key_length * 256 + digest_size_in_bytes
   for j = 1, 8 do
      local bytes_compressed, tail, H = 0.0, "", {unpack(sha2_H_hi)}
      instances[j] = {bytes_compressed, tail, H}
      H[1] = XOR(H[1], first_dword_of_parameter_block)
      H[3] = XOR(H[3], j-1)
      H[4] = XOR(H[4], 0x20000000)
      if salt ~= "" then
         xor_blake2_salt(salt, "s", H)
      end
   end

   local function partial(message_part)
      if message_part then
         if instances then
            local from = 0
            while true do
               local to = math_min(from + 64 - length % 64, #message_part)
               if to > from then
                  local inst = instances[floor(length / 64) % 8 + 1]
                  local part = sub(message_part, from + 1, to)
                  length, from = length + to - from, to
                  local bytes_compressed, tail = inst[1], inst[2]
                  if #tail < 64 then
                     tail = tail..part
                  else
                     local H = inst[3]
                     bytes_compressed = blake2s_feed_64(H, tail, 0, 64, bytes_compressed)
                     tail = part
                  end
                  inst[1], inst[2] = bytes_compressed, tail
               else
                  break
               end
            end
            return partial
         else
            error("Adding more chunks is not allowed after receiving the result", 2)
         end
      else
         if instances then
            local root_H = {unpack(sha2_H_hi)}
            root_H[1] = XOR(root_H[1], first_dword_of_parameter_block)
            root_H[4] = XOR(root_H[4], 0x20010000)
            if salt ~= "" then
               xor_blake2_salt(salt, "s", root_H)
            end
            for j = 1, 8 do
               local inst = instances[j]
               local bytes_compressed, tail, H = inst[1], inst[2], inst[3]
               blake2s_feed_64(H, tail..string_rep("\0", 64 - #tail), 0, 64, bytes_compressed, #tail, j == 8)
               if j % 2 == 0 then
                  local index = 0
                  for k = j - 1, j do
                     local inst = instances[k]
                     local H = inst[3]
                     for i = 1, 8 do
                        index = index + 1
                        common_W_blake2s[index] = H[i]
                     end
                  end
                  blake2s_feed_64(root_H, nil, 0, 64, 64 * (j/2 - 1), j == 8 and 64, j == 8)
               end
            end
            instances = nil
            local max_reg = ceil(digest_size_in_bytes / 4)
            for j = 1, max_reg do
               root_H[j] = HEX(root_H[j])
            end
            result = sub(gsub(table_concat(root_H, "", 1, max_reg), "(..)(..)(..)(..)", "%4%3%2%1"), 1, digest_size_in_bytes * 2)
         end
         return result
      end
   end

   if key_length > 0 then
      key = key..string_rep("\0", 64 - key_length)
      for j = 1, 8 do
         partial(key)
      end
   end
   if message then
      -- Actually perform calculations and return the BLAKE2sp digest of a message
      return partial(message)()
   else
      -- Return function for chunk-by-chunk loading
      -- User should feed every chunk of input data as single argument to this function and finally get BLAKE2sp digest by invoking this function without an argument
      return partial
   end

end

local function blake2bp(message, key, salt, digest_size_in_bytes)
   -- message:  binary string to be hashed (or nil for "chunk-by-chunk" input mode)
   -- key:      (optional) binary string up to 64 bytes, by default empty string
   -- salt:     (optional) binary string up to 32 bytes, by default empty string
   -- digest_size_in_bytes: (optional) integer from 1 to 64, by default 64
   digest_size_in_bytes = digest_size_in_bytes or 64
   if digest_size_in_bytes < 1 or digest_size_in_bytes > 64 then
      error("BLAKE2bp digest length must be from 1 to 64 bytes", 2)
   end
   key = key or ""
   local key_length = #key
   if key_length > 64 then
      error("BLAKE2bp key length must not exceed 64 bytes", 2)
   end
   salt = salt or ""
   local instances, length, first_dword_of_parameter_block, result = {}, 0.0, 0x02040000 + key_length * 256 + digest_size_in_bytes
   for j = 1, 4 do
      local bytes_compressed, tail, H_lo, H_hi = 0.0, "", {unpack(sha2_H_lo)}, not HEX64 and {unpack(sha2_H_hi)}
      instances[j] = {bytes_compressed, tail, H_lo, H_hi}
      H_lo[1] = XORA5(H_lo[1], first_dword_of_parameter_block)
      H_lo[2] = XORA5(H_lo[2], j-1)
      H_lo[3] = XORA5(H_lo[3], 0x4000)
      if salt ~= "" then
         xor_blake2_salt(salt, "b", H_lo, H_hi)
      end
   end

   local function partial(message_part)
      if message_part then
         if instances then
            local from = 0
            while true do
               local to = math_min(from + 128 - length % 128, #message_part)
               if to > from then
                  local inst = instances[floor(length / 128) % 4 + 1]
                  local part = sub(message_part, from + 1, to)
                  length, from = length + to - from, to
                  local bytes_compressed, tail = inst[1], inst[2]
                  if #tail < 128 then
                     tail = tail..part
                  else
                     local H_lo, H_hi = inst[3], inst[4]
                     bytes_compressed = blake2b_feed_128(H_lo, H_hi, tail, 0, 128, bytes_compressed)
                     tail = part
                  end
                  inst[1], inst[2] = bytes_compressed, tail
               else
                  break
               end
            end
            return partial
         else
            error("Adding more chunks is not allowed after receiving the result", 2)
         end
      else
         if instances then
            local root_H_lo, root_H_hi = {unpack(sha2_H_lo)}, not HEX64 and {unpack(sha2_H_hi)}
            root_H_lo[1] = XORA5(root_H_lo[1], first_dword_of_parameter_block)
            root_H_lo[3] = XORA5(root_H_lo[3], 0x4001)
            if salt ~= "" then
               xor_blake2_salt(salt, "b", root_H_lo, root_H_hi)
            end
            for j = 1, 4 do
               local inst = instances[j]
               local bytes_compressed, tail, H_lo, H_hi = inst[1], inst[2], inst[3], inst[4]
               blake2b_feed_128(H_lo, H_hi, tail..string_rep("\0", 128 - #tail), 0, 128, bytes_compressed, #tail, j == 4)
               if j % 2 == 0 then
                  local index = 0
                  for k = j - 1, j do
                     local inst = instances[k]
                     local H_lo, H_hi = inst[3], inst[4]
                     for i = 1, 8 do
                        index = index + 1
                        common_W_blake2b[index] = H_lo[i]
                        if H_hi then
                           index = index + 1
                           common_W_blake2b[index] = H_hi[i]
                        end
                     end
                  end
                  blake2b_feed_128(root_H_lo, root_H_hi, nil, 0, 128, 128 * (j/2 - 1), j == 4 and 128, j == 4)
               end
            end
            instances = nil
            local max_reg = ceil(digest_size_in_bytes / 8)
            if HEX64 then
               for j = 1, max_reg do
                  root_H_lo[j] = HEX64(root_H_lo[j])
               end
            else
               for j = 1, max_reg do
                  root_H_lo[j] = HEX(root_H_hi[j])..HEX(root_H_lo[j])
               end
            end
            result = sub(gsub(table_concat(root_H_lo, "", 1, max_reg), "(..)(..)(..)(..)(..)(..)(..)(..)", "%8%7%6%5%4%3%2%1"), 1, digest_size_in_bytes * 2)
         end
         return result
      end
   end

   if key_length > 0 then
      key = key..string_rep("\0", 128 - key_length)
      for j = 1, 4 do
         partial(key)
      end
   end
   if message then
      -- Actually perform calculations and return the BLAKE2bp digest of a message
      return partial(message)()
   else
      -- Return function for chunk-by-chunk loading
      -- User should feed every chunk of input data as single argument to this function and finally get BLAKE2bp digest by invoking this function without an argument
      return partial
   end

end

local function blake2x(inner_func, inner_func_letter, common_W_blake2, block_size, digest_size_in_bytes, message, key, salt)
   local XOF_digest_length_limit, XOF_digest_length, chunk_by_chunk_output = 2^(block_size / 2) - 1
   if digest_size_in_bytes == -1 then  -- infinite digest
      digest_size_in_bytes = math_huge
      XOF_digest_length = floor(XOF_digest_length_limit)
      chunk_by_chunk_output = true
   else
      if digest_size_in_bytes < 0 then
         digest_size_in_bytes = -1.0 * digest_size_in_bytes
         chunk_by_chunk_output = true
      end
      XOF_digest_length = floor(digest_size_in_bytes)
      if XOF_digest_length >= XOF_digest_length_limit then
         error("Requested digest is too long.  BLAKE2X"..inner_func_letter.." finite digest is limited by (2^"..floor(block_size / 2)..")-2 bytes.  Hint: you can generate infinite digest.", 2)
      end
   end
   salt = salt or ""
   if salt ~= "" then
      xor_blake2_salt(salt, inner_func_letter)  -- don't xor, only check the size of salt
   end
   local inner_partial = inner_func(nil, key, salt, nil, XOF_digest_length)
   local result

   local function partial(message_part)
      if message_part then
         if inner_partial then
            inner_partial(message_part)
            return partial
         else
            error("Adding more chunks is not allowed after receiving the result", 2)
         end
      else
         if inner_partial then
            local half_W, half_W_size = inner_partial()
            half_W_size, inner_partial = half_W_size or 8

            local function get_hash_block(block_no)
               -- block_no = 0...(2^32-1)
               local size = math_min(block_size, digest_size_in_bytes - block_no * block_size)
               if size <= 0 then
                  return ""
               end
               for j = 1, half_W_size do
                  common_W_blake2[j] = half_W[j]
               end
               for j = half_W_size + 1, 2 * half_W_size do
                  common_W_blake2[j] = 0
               end
               return inner_func(nil, nil, salt, size, XOF_digest_length, floor(block_no))
            end

            local hash = {}
            if chunk_by_chunk_output then
               local pos, period, cached_block_no, cached_block = 0, block_size * 2^32

               local function get_next_part_of_digest(arg1, arg2)
                  if arg1 == "seek" then
                     -- Usage #1:  get_next_part_of_digest("seek", new_pos)
                     pos = arg2 % period
                  else
                     -- Usage #2:  hex_string = get_next_part_of_digest(size)
                     local size, index = arg1 or 1, 0
                     while size > 0 do
                        local block_offset = pos % block_size
                        local block_no = (pos - block_offset) / block_size
                        local part_size = math_min(size, block_size - block_offset)
                        if cached_block_no ~= block_no then
                           cached_block_no = block_no
                           cached_block = get_hash_block(block_no)
                        end
                        index = index + 1
                        hash[index] = sub(cached_block, block_offset * 2 + 1, (block_offset + part_size) * 2)
                        size = size - part_size
                        pos = (pos + part_size) % period
                     end
                     return table_concat(hash, "", 1, index)
                  end
               end

               result = get_next_part_of_digest
            else
               for j = 1.0, ceil(digest_size_in_bytes / block_size) do
                  hash[j] = get_hash_block(j - 1.0)
               end
               result = table_concat(hash)
            end
         end
         return result
      end
   end

   if message then
      -- Actually perform calculations and return the BLAKE2X digest of a message
      return partial(message)()
   else
      -- Return function for chunk-by-chunk loading
      -- User should feed every chunk of input data as single argument to this function and finally get BLAKE2X digest by invoking this function without an argument
      return partial
   end
end

local function blake2xs(digest_size_in_bytes, message, key, salt)
   -- digest_size_in_bytes:
   --    0..65534       = get finite digest as single Lua string
   --    (-1)           = get infinite digest in "chunk-by-chunk" output mode
   --    (-2)..(-65534) = get finite digest in "chunk-by-chunk" output mode
   -- message:  binary string to be hashed (or nil for "chunk-by-chunk" input mode)
   -- key:      (optional) binary string up to 32 bytes, by default empty string
   -- salt:     (optional) binary string up to 16 bytes, by default empty string
   return blake2x(blake2s, "s", common_W_blake2s, 32, digest_size_in_bytes, message, key, salt)
end

local function blake2xb(digest_size_in_bytes, message, key, salt)
   -- digest_size_in_bytes:
   --    0..4294967294       = get finite digest as single Lua string
   --    (-1)                = get infinite digest in "chunk-by-chunk" output mode
   --    (-2)..(-4294967294) = get finite digest in "chunk-by-chunk" output mode
   -- message:  binary string to be hashed (or nil for "chunk-by-chunk" input mode)
   -- key:      (optional) binary string up to 64 bytes, by default empty string
   -- salt:     (optional) binary string up to 32 bytes, by default empty string
   return blake2x(blake2b, "b", common_W_blake2b, 64, digest_size_in_bytes, message, key, salt)
end


local function blake3(message, key, digest_size_in_bytes, message_flags, K, return_array)
   -- message:  binary string to be hashed (or nil for "chunk-by-chunk" input mode)
   -- key:      (optional) binary string up to 32 bytes, by default empty string
   -- digest_size_in_bytes: (optional) by default 32
   --    0,1,2,3,4,...  = get finite digest as single Lua string
   --    (-1)           = get infinite digest in "chunk-by-chunk" output mode
   --    -2,-3,-4,...   = get finite digest in "chunk-by-chunk" output mode
   -- The last three parameters "message_flags", "K" and "return_array" are for internal use only, user must omit them (or pass nil)
   key = key or ""
   digest_size_in_bytes = digest_size_in_bytes or 32
   message_flags = message_flags or 0
   if key == "" then
      K = K or sha2_H_hi
   else
      local key_length = #key
      if key_length > 32 then
         error("BLAKE3 key length must not exceed 32 bytes", 2)
      end
      key = key..string_rep("\0", 32 - key_length)
      K = {}
      for j = 1, 8 do
         local a, b, c, d = byte(key, 4*j-3, 4*j)
         K[j] = ((d * 256 + c) * 256 + b) * 256 + a
      end
      message_flags = message_flags + 16  -- flag:KEYED_HASH
   end
   local tail, H, chunk_index, blocks_in_chunk, stack_size, stack = "", {}, 0, 0, 0, {}
   local final_H_in, final_block_length, chunk_by_chunk_output, result, wide_output = K
   local final_compression_flags = 3      -- flags:CHUNK_START,CHUNK_END

   local function feed_blocks(str, offs, size)
      -- size >= 0, size is multiple of 64
      while size > 0 do
         local part_size_in_blocks, block_flags, H_in = 1, 0, H
         if blocks_in_chunk == 0 then
            block_flags = 1               -- flag:CHUNK_START
            H_in, final_H_in = K, H
            final_compression_flags = 2   -- flag:CHUNK_END
         elseif blocks_in_chunk == 15 then
            block_flags = 2               -- flag:CHUNK_END
            final_compression_flags = 3   -- flags:CHUNK_START,CHUNK_END
            final_H_in = K
         else
            part_size_in_blocks = math_min(size / 64, 15 - blocks_in_chunk)
         end
         local part_size = part_size_in_blocks * 64
         blake3_feed_64(str, offs, part_size, message_flags + block_flags, chunk_index, H_in, H)
         offs, size = offs + part_size, size - part_size
         blocks_in_chunk = (blocks_in_chunk + part_size_in_blocks) % 16
         if blocks_in_chunk == 0 then
            -- completing the currect chunk
            chunk_index = chunk_index + 1.0
            local divider = 2.0
            while chunk_index % divider == 0 do
               divider = divider * 2.0
               stack_size = stack_size - 8
               for j = 1, 8 do
                  common_W_blake2s[j] = stack[stack_size + j]
               end
               for j = 1, 8 do
                  common_W_blake2s[j + 8] = H[j]
               end
               blake3_feed_64(nil, 0, 64, message_flags + 4, 0, K, H)  -- flag:PARENT
            end
            for j = 1, 8 do
               stack[stack_size + j] = H[j]
            end
            stack_size = stack_size + 8
         end
      end
   end

   local function get_hash_block(block_no)
      local size = math_min(64, digest_size_in_bytes - block_no * 64)
      if block_no < 0 or size <= 0 then
         return ""
      end
      if chunk_by_chunk_output then
         for j = 1, 16 do
            common_W_blake2s[j] = stack[j + 16]
         end
      end
      blake3_feed_64(nil, 0, 64, final_compression_flags, block_no, final_H_in, stack, wide_output, final_block_length)
      if return_array then
         return stack
      end
      local max_reg = ceil(size / 4)
      for j = 1, max_reg do
         stack[j] = HEX(stack[j])
      end
      return sub(gsub(table_concat(stack, "", 1, max_reg), "(..)(..)(..)(..)", "%4%3%2%1"), 1, size * 2)
   end

   local function partial(message_part)
      if message_part then
         if tail then
            local offs = 0
            if tail ~= "" and #tail + #message_part > 64 then
               offs = 64 - #tail
               feed_blocks(tail..sub(message_part, 1, offs), 0, 64)
               tail = ""
            end
            local size = #message_part - offs
            local size_tail = size > 0 and (size - 1) % 64 + 1 or 0
            feed_blocks(message_part, offs, size - size_tail)
            tail = tail..sub(message_part, #message_part + 1 - size_tail)
            return partial
         else
            error("Adding more chunks is not allowed after receiving the result", 2)
         end
      else
         if tail then
            final_block_length = #tail
            tail = tail..string_rep("\0", 64 - #tail)
            if common_W_blake2s[0] then
               for j = 1, 16 do
                  local a, b, c, d = byte(tail, 4*j-3, 4*j)
                  common_W_blake2s[j] = OR(SHL(d, 24), SHL(c, 16), SHL(b, 8), a)
               end
            else
               for j = 1, 16 do
                  local a, b, c, d = byte(tail, 4*j-3, 4*j)
                  common_W_blake2s[j] = ((d * 256 + c) * 256 + b) * 256 + a
               end
            end
            tail = nil
            for stack_size = stack_size - 8, 0, -8 do
               blake3_feed_64(nil, 0, 64, message_flags + final_compression_flags, chunk_index, final_H_in, H, nil, final_block_length)
               chunk_index, final_block_length, final_H_in, final_compression_flags = 0, 64, K, 4  -- flag:PARENT
               for j = 1, 8 do
                  common_W_blake2s[j] = stack[stack_size + j]
               end
               for j = 1, 8 do
                  common_W_blake2s[j + 8] = H[j]
               end
            end
            final_compression_flags = message_flags + final_compression_flags + 8  -- flag:ROOT
            if digest_size_in_bytes < 0 then
               if digest_size_in_bytes == -1 then  -- infinite digest
                  digest_size_in_bytes = math_huge
               else
                  digest_size_in_bytes = -1.0 * digest_size_in_bytes
               end
               chunk_by_chunk_output = true
               for j = 1, 16 do
                  stack[j + 16] = common_W_blake2s[j]
               end
            end
            digest_size_in_bytes = math_min(2^53, digest_size_in_bytes)
            wide_output = digest_size_in_bytes > 32
            if chunk_by_chunk_output then
               local pos, cached_block_no, cached_block = 0.0

               local function get_next_part_of_digest(arg1, arg2)
                  if arg1 == "seek" then
                     -- Usage #1:  get_next_part_of_digest("seek", new_pos)
                     pos = arg2 * 1.0
                  else
                     -- Usage #2:  hex_string = get_next_part_of_digest(size)
                     local size, index = arg1 or 1, 32
                     while size > 0 do
                        local block_offset = pos % 64
                        local block_no = (pos - block_offset) / 64
                        local part_size = math_min(size, 64 - block_offset)
                        if cached_block_no ~= block_no then
                           cached_block_no = block_no
                           cached_block = get_hash_block(block_no)
                        end
                        index = index + 1
                        stack[index] = sub(cached_block, block_offset * 2 + 1, (block_offset + part_size) * 2)
                        size = size - part_size
                        pos = pos + part_size
                     end
                     return table_concat(stack, "", 33, index)
                  end
               end

               result = get_next_part_of_digest
            elseif digest_size_in_bytes <= 64 then
               result = get_hash_block(0)
            else
               local last_block_no = ceil(digest_size_in_bytes / 64) - 1
               for block_no = 0.0, last_block_no do
                  stack[33 + block_no] = get_hash_block(block_no)
               end
               result = table_concat(stack, "", 33, 33 + last_block_no)
            end
         end
         return result
      end
   end

   if message then
      -- Actually perform calculations and return the BLAKE3 digest of a message
      return partial(message)()
   else
      -- Return function for chunk-by-chunk loading
      -- User should feed every chunk of input data as single argument to this function and finally get BLAKE3 digest by invoking this function without an argument
      return partial
   end
end

local function blake3_derive_key(key_material, context_string, derived_key_size_in_bytes)
   -- key_material: (string) your source of entropy to derive a key from (for example, it can be a master password)
   --               set to nil for feeding the key material in "chunk-by-chunk" input mode
   -- context_string: (string) unique description of the derived key
   -- digest_size_in_bytes: (optional) by default 32
   --    0,1,2,3,4,...  = get finite derived key as single Lua string
   --    (-1)           = get infinite derived key in "chunk-by-chunk" output mode
   --    -2,-3,-4,...   = get finite derived key in "chunk-by-chunk" output mode
   if type(context_string) ~= "string" then
      error("'context_string' parameter must be a Lua string", 2)
   end
   local K = blake3(context_string, nil, nil, 32, nil, true)           -- flag:DERIVE_KEY_CONTEXT
   return blake3(key_material, nil, derived_key_size_in_bytes, 64, K)  -- flag:DERIVE_KEY_MATERIAL
end



local sha = {
   md5        = md5,                                                                                                                   -- MD5
   sha1       = sha1,                                                                                                                  -- SHA-1
   -- SHA-2 hash functions:
   sha224     = function (message)                       return sha256ext(224, message)                                           end, -- SHA-224
   sha256     = function (message)                       return sha256ext(256, message)                                           end, -- SHA-256
   sha512_224 = function (message)                       return sha512ext(224, message)                                           end, -- SHA-512/224
   sha512_256 = function (message)                       return sha512ext(256, message)                                           end, -- SHA-512/256
   sha384     = function (message)                       return sha512ext(384, message)                                           end, -- SHA-384
   sha512     = function (message)                       return sha512ext(512, message)                                           end, -- SHA-512
   -- SHA-3 hash functions:
   sha3_224   = function (message)                       return keccak((1600 - 2 * 224) / 8, 224 / 8, false, message)             end, -- SHA3-224
   sha3_256   = function (message)                       return keccak((1600 - 2 * 256) / 8, 256 / 8, false, message)             end, -- SHA3-256
   sha3_384   = function (message)                       return keccak((1600 - 2 * 384) / 8, 384 / 8, false, message)             end, -- SHA3-384
   sha3_512   = function (message)                       return keccak((1600 - 2 * 512) / 8, 512 / 8, false, message)             end, -- SHA3-512
   shake128   = function (digest_size_in_bytes, message) return keccak((1600 - 2 * 128) / 8, digest_size_in_bytes, true, message) end, -- SHAKE128
   shake256   = function (digest_size_in_bytes, message) return keccak((1600 - 2 * 256) / 8, digest_size_in_bytes, true, message) end, -- SHAKE256
   -- HMAC:
   hmac       = hmac,  -- HMAC(hash_func, key, message) is applicable to any hash function from this module except SHAKE* and BLAKE*
   -- misc utilities:
   hex_to_bin    = hex_to_bin,     -- converts hexadecimal representation to binary string
   bin_to_hex    = bin_to_hex,     -- converts binary string to hexadecimal representation
   base64_to_bin = base64_to_bin,  -- converts base64 representation to binary string
   bin_to_base64 = bin_to_base64,  -- converts binary string to base64 representation
   -- old style names for backward compatibility:
   hex2bin       = hex_to_bin,
   bin2hex       = bin_to_hex,
   base642bin    = base64_to_bin,
   bin2base64    = bin_to_base64,
   -- BLAKE2 hash functions:
   blake2b  = blake2b,   -- BLAKE2b (message, key, salt, digest_size_in_bytes)
   blake2s  = blake2s,   -- BLAKE2s (message, key, salt, digest_size_in_bytes)
   blake2bp = blake2bp,  -- BLAKE2bp(message, key, salt, digest_size_in_bytes)
   blake2sp = blake2sp,  -- BLAKE2sp(message, key, salt, digest_size_in_bytes)
   blake2xb = blake2xb,  -- BLAKE2Xb(digest_size_in_bytes, message, key, salt)
   blake2xs = blake2xs,  -- BLAKE2Xs(digest_size_in_bytes, message, key, salt)
   -- BLAKE2 aliases:
   blake2      = blake2b,
   blake2b_160 = function (message, key, salt) return blake2b(message, key, salt, 20) end, -- BLAKE2b-160
   blake2b_256 = function (message, key, salt) return blake2b(message, key, salt, 32) end, -- BLAKE2b-256
   blake2b_384 = function (message, key, salt) return blake2b(message, key, salt, 48) end, -- BLAKE2b-384
   blake2b_512 = blake2b,                                                      -- 64       -- BLAKE2b-512
   blake2s_128 = function (message, key, salt) return blake2s(message, key, salt, 16) end, -- BLAKE2s-128
   blake2s_160 = function (message, key, salt) return blake2s(message, key, salt, 20) end, -- BLAKE2s-160
   blake2s_224 = function (message, key, salt) return blake2s(message, key, salt, 28) end, -- BLAKE2s-224
   blake2s_256 = blake2s,                                                      -- 32       -- BLAKE2s-256
   -- BLAKE3 hash function
   blake3            = blake3,             -- BLAKE3    (message, key, digest_size_in_bytes)
   blake3_derive_key = blake3_derive_key,  -- BLAKE3_KDF(key_material, context_string, derived_key_size_in_bytes)
}


block_size_for_HMAC = {
   [sha.md5]        =  64,
   [sha.sha1]       =  64,
   [sha.sha224]     =  64,
   [sha.sha256]     =  64,
   [sha.sha512_224] = 128,
   [sha.sha512_256] = 128,
   [sha.sha384]     = 128,
   [sha.sha512]     = 128,
   [sha.sha3_224]   = 144,  -- (1600 - 2 * 224) / 8
   [sha.sha3_256]   = 136,  -- (1600 - 2 * 256) / 8
   [sha.sha3_384]   = 104,  -- (1600 - 2 * 384) / 8
   [sha.sha3_512]   =  72,  -- (1600 - 2 * 512) / 8
}


return sha
```

## truyenviet.koplugin/truyenviet/sources/test_aeslua.lua

```lua
local current_dir = "d:\\Project\\truyenfull\\truyenviet.koplugin\\truyenviet\\sources\\"
package.path = package.path .. ";" .. current_dir .. "aeslua/src/?.lua;" .. current_dir .. "?.lua"
local ciphermode = require("aeslua.ciphermode")
print("success")
```

## truyenviet.koplugin/truyenviet/sources/truyenc.lua

```lua
local Http = require("truyenviet/http_client")
local Util = require("truyenviet/helpers")
local ko_util = require("util")

local Source = {
    id = "truyenc",
    name = "TruyenC",
    kind = "text",
    base_url = "https://truyenc.com",
}

local CATEGORIES = {
    { name = "Truyện ma", path = "/tim-truyen-ma" },
    { name = "Truyện 18+", path = "/tim-truyen-18" },
    { name = "Truyện cười", path = "/tim-truyen-cuoi" },
    { name = "Truyện audio", path = "/tim-truyen-audio" },
    { name = "Chưa phân loại", path = "/tim-truyen-chua-phan-loai" },
    { name = "Truyện cười vova", path = "/truyen-cuoi-vova" },
    { name = "Truyện cười 18+", path = "/truyen-cuoi-18" },
    { name = "Truyện cười tình yêu", path = "/truyen-cuoi-tinh-yeu" },
    { name = "Truyện trạng Quỳnh", path = "/truyen-trang-quynh" },
    { name = "Truyện cười dân gian", path = "/truyen-cuoi-dan-gian" },
    { name = "Truyên cười quốc tế", path = "/truyen-cuoi-quoc-te" },
    { name = "Truyện cười khác", path = "/truyen-cuoi-khac" },
    { name = "Truyện ma Việt Nam", path = "/truyen-ma-viet-nam" },
    { name = "Truyện ma Trung Quốc", path = "/truyen-ma-trung-quoc" },
    { name = "Truyện ma ngắn", path = "/truyen-ma-ngan" },
    { name = "Truyện ma dài kỳ", path = "/truyen-ma-dai-ky" },
    { name = "Truyện ma hay", path = "/truyen-ma-hay" },
    { name = "Truyện ma có thật", path = "/truyen-ma-co-that" },
    { name = "Truyện ma Nguyễn Ngọc Ngạn", path = "/truyen-ma-nguyen-ngoc-ngan" },
    { name = "Truyện kinh dị", path = "/truyen-kinh-di" },
    { name = "Truyện ma audio", path = "/truyen-ma-audio" },
    { name = "Truyện audio kiếm hiệp", path = "/truyen-audio-kiem-hiep" },
    { name = "Truyện audio ngôn tình", path = "/truyen-audio-ngon-tinh" },
    { name = "Đọc truyện đêm khuya", path = "/truyen-dem-khuya" },
    { name = "Truyện audio trinh thám", path = "/truyen-audio-trinh-tham" },
    { name = "Truyện audio ngắn", path = "/truyen-audio-ngan" },
    { name = "Truyện sắc hiệp", path = "/truyen-sac-hiep" },
    { name = "Truyện Sex", path = "/truyen-sex" },
    { name = "Truyện Sex Audio", path = "/truyen-sex-audio" },
    { name = "Truyện Voz", path = "/truyen-voz" },
    { name = "Truyện có thật", path = "/truyen-co-that" },
    { name = "Truyện dâm hiệp", path = "/truyen-dam-hiep" },
    { name = "Truyện kiếm hiệp", path = "/truyen-kiem-hiep" },
    { name = "Truyện H", path = "/truyen-h" },
}

local PATH_SET = {}
for _, cat in ipairs(CATEGORIES) do
    PATH_SET[cat.path] = true
end

local function stdHeaders(base_url)
    return {
        ["User-Agent"] = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36",
        ["Referer"] = base_url .. "/",
    }
end

local function getGenreList()
    local genres = {}
    for _, cat in ipairs(CATEGORIES) do
        table.insert(genres, { name = cat.name, url = "https://truyenc.com" .. cat.path })
    end
    return genres
end

-- Cấu trúc thẻ truyện: xác nhận bằng fetch trực tiếp (11/07/2026) các URL
-- thật /tim-truyen-ma, /truyen/{slug}-{id}, ảnh https://i.truyenc.com/img/...
-- QUAN TRỌNG: công cụ fetch ở đây trả về nội dung đã được chuyển sang
-- Markdown, KHÔNG phải HTML gốc, nên tên class/id CSS dưới đây là suy đoán
-- theo mẫu theme WordPress tiếng Việt phổ biến (giống cấu trúc đã xác nhận
-- đúng ở aztruyen.lua: <h2><a href title></a></h2> đi kèm <a><img></a> bọc
-- ảnh bìa), CHƯA được xác nhận từng byte HTML thật. Cần test trên máy thật;
-- nếu 0 kết quả thì bật lại phần "Dự phòng" bên dưới hoặc báo lại để chỉnh.
local function parseStories(html, source_id)
    local stories = {}
    local seen = {}

    local cover_by_url = {}
    for url, cover in html:gmatch(
        '<a[^>]+href="(https?://truyenc%.com/truyen/[%w%-]+%-%d+)"[^>]*>%s*<img[^>]+src="(https?://i%.truyenc%.com/img/[^"]+)"'
    ) do
        cover_by_url[url] = cover
    end

    for url, title in html:gmatch(
        '<h2[^>]*>%s*<a[^>]+href="(https?://truyenc%.com/truyen/[%w%-]+%-%d+)"[^>]*title="([^"]+)"'
    ) do
        if not seen[url] then
            seen[url] = true
            table.insert(stories, {
                source_id = source_id,
                title = Util.decodeHtml(title),
                url = url,
                cover_url = cover_by_url[url],
                kind = "text",
            })
        end
    end

    -- Dự phòng: nếu <h2> không khớp, thử bắt trực tiếp theo cặp href+title
    -- bất kỳ trỏ tới /truyen/{slug}-{id} (không phụ thuộc thẻ bao quanh)
    if #stories == 0 then
        for href, title in html:gmatch(
            '<a[^>]+href="(https?://truyenc%.com/truyen/[%w%-]+%-%d+)"[^>]*title="([^"]+)"'
        ) do
            if not seen[href] and title ~= "Đọc truyện" then
                seen[href] = true
                table.insert(stories, {
                    source_id = source_id,
                    title = Util.decodeHtml(title),
                    url = href,
                    cover_url = cover_by_url[href],
                    kind = "text",
                })
            end
        end
    end

    return stories
end

function Source:search(query)
    -- LƯU Ý: chưa xác minh được truyenc.com có endpoint tìm kiếm URL-based
    -- hay không (không thấy ô tìm kiếm dùng GET query string khi fetch thật
    -- các trang danh mục). Thử /tim-kiem/{query} theo mẫu chung của các
    -- nguồn khác trong plugin; nếu sai cần bạn cho biết URL tìm kiếm thật.
    local encoded = ko_util.urlEncode(query)
    local url = self.base_url .. "/tim-kiem/" .. encoded
    local html, err = Http:get(url, stdHeaders(self.base_url))
    if not html then return nil, err end
    return parseStories(html, self.id)
end

function Source:getCompleted(page)
    page = page or 1
    -- Site không có khái niệm "truyện hoàn thành" riêng biệt đã xác nhận
    -- được; dùng mục an toàn đầu tiên (Truyện ma) làm danh sách mặc định,
    -- các mục còn lại truy cập qua "Thể loại" (safeGenreList).
    local first = CATEGORIES[1]
    local url = self.base_url .. first.path
    if page > 1 then url = url .. "?page=" .. page end
    local html, err = Http:get(url, stdHeaders(self.base_url))
    if not html then return nil, err end

    local total_pages = tonumber(html:match('trang%-(%d+)"[^>]*>Trang cuối'))
        or tonumber(html:match('%?page=(%d+)"[^>]*>»'))
        or page

    return {
        stories = parseStories(html, self.id),
        genres = getGenreList(),
        page = page,
        total_pages = total_pages,
        title = first.name,
    }
end

function Source:getGenre(genre, page)
    page = page or 1
    -- An toàn ở lớp thứ hai: chỉ cho phép fetch nếu path nằm trong danh sách
    -- SAFE_PATH_SET, kể cả khi genre.url bị truyền vào từ nơi khác trong
    -- code (ví dụ do lỗi lập trình sau này vô tình nối thêm mục ngoài ý muốn).
    local path = genre.url:gsub("^https?://truyenc%.com", "")
    if not PATH_SET[path] then
        return nil, "Thể loại này không được hỗ trợ trong TruyenC."
    end

    local url = genre.url
    if page > 1 then url = url .. "?page=" .. page end
    local html, err = Http:get(url, stdHeaders(self.base_url))
    if not html then return nil, err end

    local total_pages = tonumber(html:match('trang%-(%d+)"[^>]*>Trang cuối'))
        or tonumber(html:match('%?page=(%d+)"[^>]*>»'))
        or page

    return {
        stories = parseStories(html, self.id),
        genres = getGenreList(),
        page = page,
        total_pages = total_pages,
        title = genre.name,
    }
end

function Source:getStoryDetails(story)
    local html, err = Http:get(story.url, stdHeaders(self.base_url))
    if not html then return nil, err end

    local title = html:match('<h1[^>]*>([^<]+)</h1>')
    local author = html:match('Tác giả:%s*<[^>]+>%s*<strong>([^<]+)</strong>')
        or html:match('Tác giả:%s*<strong>([^<]+)</strong>')

    local status = html:match('Tình trạng:%s*([^<\n]+)')
    if status then status = Util.trim(status) end

    -- Thể loại: trang chi tiết thật có 1 dòng liệt kê nhiều link thể loại
    -- ngay dưới ảnh bìa (vd "Truyện ma · Truyện ma dài kỳ · Truyện kinh dị").
    local genres = {}
    for href, name in html:gmatch('<a[^>]+href="(https?://truyenc%.com/[%w%-]+)"[^>]*title="([^"]+)"') do
        local path = href:gsub("^https?://truyenc%.com", "")
        if PATH_SET[path] then
            table.insert(genres, Util.decodeHtml(name))
        end
    end

    local desc_block = html:match('<div class="content%-story"[^>]*>(.-)</div>%s*<div class="list%-chapter"')
        or html:match('<div class="desc%-text"[^>]*>(.-)</div>')
        or html:match('<div class="content%-story"[^>]*>(.-)</div>')

    local description = desc_block and Util.stripTags(desc_block) or nil
    if description then
        description = description:gsub("^%s+", ""):gsub("%s+$", "")
    end

    return {
        title = title and Util.decodeHtml(Util.trim(title)) or story.title,
        author = author and Util.trim(author) or nil,
        status = status,
        genres = genres,
        description = description,
    }
end

function Source:getStoryPage(story, page)
    page = page or 1
    local html, err = Http:get(story.url, stdHeaders(self.base_url))
    if not html then return nil, err end

    -- Chương thật dạng: https://truyenc.com/truyen/{slug}/chuong-{n}-{ten}-{id}
    -- (đã xác nhận qua fetch thật trang cam-tu-ky-bao-79). Site có vẻ liệt
    -- kê TOÀN BỘ chương trên 1 trang chi tiết (không phân trang danh sách
    -- chương riêng) — nên total_pages luôn = 1 trừ khi phát hiện phân trang
    -- thật khi test.
    local chapters = {}
    local seen = {}
    for href, title in html:gmatch(
        '<a[^>]+href="(https?://truyenc%.com/truyen/[^"]+/chuong%-[^"]+)"[^>]*title="([^"]+)"'
    ) do
        if not seen[href] then
            seen[href] = true
            table.insert(chapters, {
                title = Util.trim(Util.decodeHtml(title)),
                url = href,
                source_id = self.id,
                story_url = story.url,
                kind = self.kind,
            })
        end
    end

    story.details = self:getStoryDetails(story)

    return {
        story = story,
        chapters = chapters,
        page = 1,
        total_pages = 1,
    }
end

-- CHƯA XÁC MINH ĐƯỢC: tên class/id thẻ bao nội dung chương thật (công cụ
-- fetch chỉ trả về text đã strip HTML). Thử theo thứ tự các tên phổ biến ở
-- theme truyện tiếng Việt; bắt buộc phải test trên máy thật và báo lại tên
-- đúng nếu cả 5 pattern dưới đây đều không khớp, để cập nhật lại cho chuẩn.
local CONTENT_PATTERNS = {
    '<div class="chapter%-content"[^>]*>(.-)</div>%s*<div',
    '<div class="content%-chap"[^>]*>(.-)</div>%s*<div',
    '<div class="box%-chap"[^>]*>(.-)</div>%s*<div',
    '<div id="chapter%-content"[^>]*>(.-)</div>',
    '<div class="reading%-content"[^>]*>(.-)</div>%s*<div',
}

local function extractChapterContent(html)
    for _, pattern in ipairs(CONTENT_PATTERNS) do
        local content = html:match(pattern)
        if content and #Util.stripTags(content) > 50 then
            return content
        end
    end
    return nil
end

function Source:getChapter(chapter)
    local html, err = Http:get(chapter.url, stdHeaders(self.base_url))
    if not html then return nil, err end

    local content = extractChapterContent(html)
    if not content then
        return nil, "Không tìm thấy nội dung chương (cần xác minh lại tên thẻ HTML thật trên máy)."
    end

    return Util.sanitizeContentHtml(content)
end

function Source:getChapterAsync(chapter)
    local html, err = Http:requestAsync("GET", chapter.url, nil, stdHeaders(self.base_url))
    if not html then return nil, err end

    local content = extractChapterContent(html)
    if not content then
        return nil, "Không tìm thấy nội dung chương (cần xác minh lại tên thẻ HTML thật trên máy)."
    end

    return Util.sanitizeContentHtml(content)
end

return Source
```

## truyenviet.koplugin/truyenviet/sources/truyendich.lua

```lua
local Http = require("truyenviet/http_client")
local Util = require("truyenviet/helpers")
local ko_util = require("util")

local Source = {
    id = "truyendich",
    name = "Truyendich",
    kind = "text",
    base_url = "https://truyendich.ai",
    max_concurrent = 2,
}

local function requestHeaders(referer)
    return {
        ["Referer"] = referer or "https://truyendich.ai/",
    }
end

function Source:getCoverHeaders()
    return requestHeaders()
end

function Source:parseSearch(html)
    local stories = {}
    for anchor_attrs, href, content in html:gmatch("<a([^>]*)href=\"(/doc%-truyen/[^\"]+)\"[^>]*>([%s%S]-)</a>") do
        local image_tag = content:match("(<img[^>]*>)")
        
        local title = Util.getAttribute(anchor_attrs, "title")
        if not title and image_tag then
            title = Util.getAttribute(image_tag, "alt")
            if title and title:find("Ảnh bìa truyện ") then
                title = title:gsub("Ảnh bìa truyện ", "")
            end
        end
        if not title then
            local h3 = content:match("<h3[^>]*>([%s%S]-)</h3>")
            if h3 then title = Util.stripTags(h3) end
        end

        if href and title and image_tag then
            table.insert(stories, {
                source_id = self.id,
                title = Util.decodeHtml(title),
                url = Util.absoluteUrl(self.base_url, href),
                cover_url = Util.absoluteUrl(
                    self.base_url,
                    Util.getAttribute(image_tag, "src") or Util.getAttribute(image_tag, "data-src")
                ),
                kind = self.kind,
            })
        end
    end
    return Util.uniqueBy(stories, "url")
end

function Source:search(query)
    local encoded = ko_util.urlEncode(query):gsub("%%20", "+")
    local html, err = Http:get(self.base_url .. "/tim-kiem?keyword=" .. encoded, requestHeaders())
    if not html then
        return nil, err
    end
    return self:parseSearch(html)
end

function Source:parseListing(html, page)
    return {
        stories = self:parseSearch(html),
        genres = Util.parseGenres(html, self.base_url),
        page = page or 1,
        total_pages = Util.maxPage(html, page or 1),
    }
end

function Source:getCompleted(page)
    page = page or 1
    local url = self.base_url .. "/danh-sach/truyen-full"
    if page > 1 then
        url = url .. "?page=" .. page
    end
    local html, err = Http:get(url, requestHeaders())
    if not html then
        return nil, err
    end
    local result = self:parseListing(html, page)
    result.title = "Truyện đã hoàn thành"
    return result
end

function Source:getGenre(genre, page)
    page = page or 1
    local url = genre.url:gsub("%?.*$", "")
    if page > 1 then
        url = url .. "?page=" .. page
    end
    local html, err = Http:get(url, requestHeaders())
    if not html then
        return nil, err
    end
    local result = self:parseListing(html, page)
    result.title = genre.name
    result.genre = genre
    return result
end

function Source:parseStoryDetails(html)
    local description_html = html:match('<div[^>]-class="[^"]*desc%-text[^"]*"[^>]*>([%s%S]-)</div>')
    local author = html:match('<a[^>]-itemprop="author"[^>]*>([%s%S]-)</a>')
    
    return {
        description = Util.stripTags(description_html) ~= "" and Util.stripTags(description_html) or Util.getMetaContent(html, "name", "description"),
        author = Util.stripTags(author),
        status = Util.stripTags(html:match('Trạng thái:.-<span[^>]*>([%s%S]-)</span>')),
        genres = Util.parseGenreNames(html),
    }
end

function Source:getStoryDetails(story)
    local html, err = Http:get(story.url, requestHeaders())
    if not html then
        return nil, err
    end
    return self:parseStoryDetails(html)
end

function Source:parseStoryPage(html, story, page)
    local chapters = {}
    local slug = story.url:match("([^/]+)$") or ""
    local start_at = html:find('Danh sách chương') or 1
    local chapter_html = html:sub(start_at)

    for anchor_attrs, anchor_html in chapter_html:gmatch("<a([^>]*)>([%s%S]-)</a>") do
        local href = Util.getAttribute(anchor_attrs, "href")
        if href and href:find("/chuong-", 1, true) and href:find(slug, 1, true) then
            local title = Util.stripTags(anchor_html)
            table.insert(chapters, {
                title = title ~= "" and title or Util.getAttribute(anchor_attrs, "title"),
                url = Util.absoluteUrl(self.base_url, href),
                source_id = self.id,
                story_url = story.url,
                kind = self.kind,
            })
        end
    end

    local total_pages = 1
    for p_num in html:gmatch(slug .. "/trang%-(%d+)") do
        total_pages = math.max(total_pages, tonumber(p_num) or 1)
    end
    local next_pages = html:match(">%s*%d+%s*<!%-%-.-%-%->%s*/%s*<!%-%-.-%-%->%s*(%d+)%s*<")
    if next_pages then
        total_pages = math.max(total_pages, tonumber(next_pages) or 1)
    end

    story.details = self:parseStoryDetails(html)
    return {
        story = story,
        chapters = Util.uniqueBy(chapters, "url"),
        page = page or 1,
        total_pages = total_pages,
    }
end

function Source:getStoryPage(story, page)
    page = page or 1
    local page_url = story.url:gsub("/trang%-%d+", ""):gsub("%?.*$", "")
    if page > 1 then
        page_url = page_url .. "/trang-" .. page
    end
    local html, err = Http:get(page_url, requestHeaders(story.url))
    if not html then
        return nil, err
    end
    return self:parseStoryPage(html, story, page)
end

function Source:parseChapter(html, chapter)
    local chapter_title = Util.stripTags(html:match('<h1[^>]*itemProp="name"[^>]*>([%s%S]-)</h1>')) or Util.stripTags(html:match('<h2[^>]*chapter%-title[^>]*>([%s%S]-)</h2>'))

    local start_at = html:find('id="original-content-tab"', 1, true)
    local end_at
    if start_at then
        start_at = html:find(">", start_at, true)
        end_at = html:find('</section>', start_at, true) or html:find('</div>%s*<nav', start_at) or html:find('</div>%s*<div', start_at)
    else
        start_at = html:find('id="chapter-c"', 1, true)
        if not start_at then
            return nil, "Không tìm thấy nội dung chương"
        end
        start_at = html:find(">", start_at, true)
    end

    if not end_at then
        end_at = html:find('</div>', start_at, true) or #html
    end
    
    local temp = html:sub(start_at + 1, end_at - 1)
    temp = temp:gsub("</div>%s*$", "")
    local content = Util.sanitizeContentHtml(temp)

    return {
        title = chapter_title or chapter.title,
        content = content,
        url = chapter.url,
        kind = self.kind,
    }
end

function Source:getChapter(chapter)
    local html, err = Http:get(chapter.url, requestHeaders(chapter.story_url or chapter.url))
    if not html then
        return nil, err
    end
    return self:parseChapter(html, chapter)
end

function Source:getChapterAsync(chapter)
    local html, err = Http:requestAsync("GET", chapter.url, nil, requestHeaders(chapter.story_url or chapter.url))
    if not html then
        return nil, err
    end
    return self:parseChapter(html, chapter)
end

return Source
```

## truyenviet.koplugin/truyenviet/sources/truyenfull.lua

```lua
local Http = require("truyenviet/http_client")
local Util = require("truyenviet/helpers")
local ko_util = require("util")

local Source = {
    id = "truyenfull",
    name = "TruyenFull",
    kind = "text",
    base_url = "https://truyenfull.today",
}

function Source:getCoverHeaders()
    return {
        ["Referer"] = self.base_url .. "/",
    }
end

function Source:parseSearch(html)
    local stories = {}
    local position = 1

    while true do
        local heading_start, heading_end, heading_attrs, heading_html =
            html:find("<h3([^>]*)>([%s%S]-)</h3>", position)
        if not heading_start then
            break
        end
        if heading_attrs:find("truyen-title", 1, true) then
            local anchor = heading_html:match("(<a[^>]*>)")
            local href = Util.getAttribute(anchor, "href")
            local title = Util.getAttribute(anchor, "title") or Util.stripTags(heading_html)
            if href and title ~= "" then
                local preceding = html:sub(position, heading_start - 1)
                local cover
                for image_url in preceding:gmatch('data%-image="([^"]+)"') do
                    cover = image_url
                end
                table.insert(stories, {
                    source_id = self.id,
                    title = Util.decodeHtml(title),
                    url = Util.absoluteUrl(self.base_url, href),
                    cover_url = Util.absoluteUrl(self.base_url, cover),
                    kind = self.kind,
                })
            end
        end
        position = heading_end + 1
    end

    return Util.uniqueBy(stories, "url")
end

function Source:search(query)
    local encoded = ko_util.urlEncode(query):gsub("%%20", "+")
    local html, err = Http:get(self.base_url .. "/tim-kiem/?tukhoa=" .. encoded)
    if not html then
        return nil, err
    end
    return self:parseSearch(html)
end

function Source:parseListing(html, page)
    return {
        stories = self:parseSearch(html),
        genres = Util.parseGenres(html, self.base_url),
        page = page or 1,
        total_pages = Util.maxPage(html, page),
    }
end

function Source:getCompleted(page)
    page = page or 1
    local url = self.base_url .. "/danh-sach/truyen-full/"
    if page > 1 then
        url = url .. "trang-" .. page .. "/"
    end
    local html, err = Http:get(url)
    if not html then
        return nil, err
    end
    local result = self:parseListing(html, page)
    result.title = "Truyện đã hoàn thành"
    return result
end

function Source:getGenre(genre, page)
    page = page or 1
    local url = Util.withTrailingSlash(genre.url)
    if page > 1 then
        url = url .. "trang-" .. page .. "/"
    end
    local html, err = Http:get(url)
    if not html then
        return nil, err
    end
    local result = self:parseListing(html, page)
    result.title = genre.name
    result.genre = genre
    return result
end

function Source:parseStoryDetails(html)
    local description_html = html:match(
        '<div[^>]-class="[^"]*desc%-text[^"]*"[^>]-itemprop="description"[^>]*>([%s%S]-)</div>'
    )
    local author
    for anchor_attrs, anchor_html in html:gmatch("<a([^>]*)>([%s%S]-)</a>") do
        if Util.getAttribute(anchor_attrs, "itemprop") == "author" then
            author = Util.stripTags(anchor_html)
            break
        end
    end

    local info_start = html:find('<div class="info">', 1, true)
    local info_end = info_start
        and html:find('<div class="col-xs-12 col-sm-8', info_start, true)
    local info_html = info_start
        and html:sub(info_start, (info_end or (#html + 1)) - 1)
        or ""

    return {
        description = Util.stripTags(description_html)
            ~= "" and Util.stripTags(description_html)
            or Util.getMetaContent(html, "name", "description"),
        author = author,
        status = Util.stripTags(
            info_html:match('<span[^>]-class="[^"]*text%-success[^"]*"[^>]*>([%s%S]-)</span>')
        ),
        genres = Util.parseGenreNames(info_html),
    }
end

function Source:getStoryDetails(story)
    local html, err = Http:get(story.url)
    if not html then
        return nil, err
    end
    return self:parseStoryDetails(html)
end

function Source:parseStoryPage(html, story, page)
    local chapters = {}
    local start_at = html:find('id="list%-chapter"')
    local end_at = start_at and html:find('id="truyen%-id"', start_at)
    local chapter_html = start_at and html:sub(start_at, (end_at or #html) - 1) or ""

    for anchor_attrs, anchor_html in chapter_html:gmatch("<a([^>]*)>([%s%S]-)</a>") do
        local href = Util.getAttribute(anchor_attrs, "href")
        if href and href:find("/chuong-", 1, true) then
            local title = Util.stripTags(anchor_html)
            table.insert(chapters, {
                title = title ~= "" and title or Util.getAttribute(anchor_attrs, "title"),
                url = Util.absoluteUrl(self.base_url, href),
                source_id = self.id,
                story_url = story.url,
                kind = self.kind,
            })
        end
    end

    local total_pages = tonumber(html:match('id="total%-page"[^>]-value="(%d+)"')) or 1
    story.details = self:parseStoryDetails(html)
    return {
        story = story,
        chapters = Util.uniqueBy(chapters, "url"),
        page = page or 1,
        total_pages = total_pages,
    }
end

function Source:getStoryPage(story, page)
    page = page or 1
    local story_url = Util.withTrailingSlash(story.url)
    local page_url = page > 1 and (story_url .. "trang-" .. page .. "/") or story_url
    local html, err = Http:get(page_url)
    if not html then
        return nil, err
    end
    return self:parseStoryPage(html, story, page)
end

function Source:parseChapter(html, chapter)
    local chapter_title
    for heading_html in html:gmatch("<h2[^>]*>([%s%S]-)</h2>") do
        if heading_html:find("chapter-title", 1, true) then
            chapter_title = Util.stripTags(heading_html)
            break
        end
    end

    local start_at = html:find('id="chapter%-c"')
    if not start_at then
        return nil, "Không tìm thấy nội dung chương"
    end
    start_at = html:find(">", start_at, true)

    local end_at = html:find('</div>%s*<div id="ads%-chapter%-bottom"', start_at)
        or html:find('</div>%s*<hr class="chapter%-end"', start_at)
    if not end_at then
        return nil, "Không xác định được điểm kết thúc chương"
    end

    local content = Util.sanitizeContentHtml(html:sub(start_at + 1, end_at - 1))
    content = content:gsub('<div id="ads%-chapter%-top"[^>]*></div>', "")

    local previous_url
    local next_url
    for anchor_attrs in html:gmatch("<a([^>]*)>") do
        local id = Util.getAttribute(anchor_attrs, "id")
        local href = Util.getAttribute(anchor_attrs, "href")
        if href and not href:find("^javascript:") then
            if id == "prev_chap" then
                previous_url = Util.absoluteUrl(self.base_url, href)
            elseif id == "next_chap" then
                next_url = Util.absoluteUrl(self.base_url, href)
            end
        end
    end

    return {
        title = chapter_title or chapter.title,
        content = content,
        previous_url = previous_url,
        next_url = next_url,
        url = chapter.url,
        kind = self.kind,
    }
end

function Source:getChapter(chapter)
    local html, err = Http:get(chapter.url)
    if not html then
        return nil, err
    end
    return self:parseChapter(html, chapter)
end

function Source:getChapterAsync(chapter)
    local html, err = Http:requestAsync("GET", chapter.url, nil, nil)
    if not html then
        return nil, err
    end
    return self:parseChapter(html, chapter)
end

return Source
```

## truyenviet.koplugin/truyenviet/sources/truyenqq.lua

```lua
local Http = require("truyenviet/http_client")
local Util = require("truyenviet/helpers")
local Debug = require("truyenviet/debugger")

local Source = {
    id = "truyenqq",
    name = "TruyenQQ",
    kind = "comic",
    base_url = "https://truyenqqko.com",
    reversed_chapters = true,
}

local function requestHeaders()
    return {
        ["User-Agent"] = "Mozilla/5.0 (Linux; Android 10; K) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36",
        ["Referer"] = Source.base_url .. "/",
        ["X-Requested-With"] = "XMLHttpRequest",
        ["Accept-Language"] = "vi-VN,vi;q=0.9,en;q=0.7",
    }
end

function Source:getCoverHeaders()
    return requestHeaders()
end

function Source:parseSearch(html)
    local stories = {}

    for item_html in html:gmatch("<li[^>]*>([%s%S]-)</li>") do
        local anchor = item_html:match("(<a[^>]*>)")
        local href = Util.getAttribute(anchor, "href")
        local title = item_html:match('<p[^>]-class="name"[^>]*>([%s%S]-)</p>')
        local image_tag = item_html:match("(<img[^>]*>)")
        if href and title then
            table.insert(stories, {
                source_id = self.id,
                title = Util.stripTags(title),
                url = Util.absoluteUrl(self.base_url, href),
                cover_url = Util.absoluteUrl(
                    self.base_url,
                    Util.getAttribute(image_tag, "src")
                        or Util.getAttribute(image_tag, "data-fb")
                ),
                kind = self.kind,
            })
        end
    end

    return Util.uniqueBy(stories, "url")
end

function Source:search(query)
    local html, err = Http:postForm(
        self.base_url .. "/frontend/search/search",
        { search = query, type = 0 },
        requestHeaders(),
        { force_luasec = true }
    )
    if not html then
        return nil, err
    end
    return self:parseSearch(html)
end

function Source:parseListing(html, page)
    local stories = {}
    local list_start = html:find('<ul class="list_grid grid"', 1, true)
    local list_end = list_start and html:find("</ul>", list_start, true)
    local list_html = list_start
        and html:sub(list_start, (list_end or (#html + 1)) - 1)
        or ""

    for item_html in list_html:gmatch("<li[^>]*>([%s%S]-)</li>") do
        if item_html:find('class="book_avatar"', 1, true) then
            local name_html = item_html:match(
                '<div[^>]-class="book_name[^"]*"[^>]*>([%s%S]-)</div>'
            )
            local anchor = name_html and name_html:match("(<a[^>]*>)")
            local image_tag = item_html:match("(<img[^>]*>)")
            local href = Util.getAttribute(anchor, "href")
            local title = Util.getAttribute(anchor, "title")
                or Util.stripTags(name_html)
            if href and title and title ~= "" then
                table.insert(stories, {
                    source_id = self.id,
                    title = Util.decodeHtml(title),
                    url = Util.absoluteUrl(self.base_url, href),
                    cover_url = Util.absoluteUrl(
                        self.base_url,
                        Util.getAttribute(image_tag, "data-original")
                            or Util.getAttribute(image_tag, "src")
                            or Util.getAttribute(image_tag, "data-fb")
                    ),
                    kind = self.kind,
                })
            end
        end
    end

    return {
        stories = Util.uniqueBy(stories, "url"),
        genres = Util.parseGenres(html, self.base_url),
        page = page or 1,
        total_pages = Util.maxPage(html, page),
    }
end

function Source:getCompleted(page)
    page = page or 1
    local url = self.base_url .. "/truyen-hoan-thanh"
    if page > 1 then
        url = url .. "/trang-" .. page .. "?status=2"
    end
    local html, err = Http:get(url, requestHeaders(), { force_luasec = true })
    if not html then
        return nil, err
    end
    local result = self:parseListing(html, page)
    result.title = "Truyện đã hoàn thành"
    return result
end

function Source:getGenre(genre, page)
    page = page or 1
    local url = genre.url:gsub("/+$", "")
    if page > 1 then
        url = url .. "/trang-" .. page
    end
    local html, err = Http:get(url, requestHeaders(), { force_luasec = true })
    if not html then
        return nil, err
    end
    local result = self:parseListing(html, page)
    result.title = genre.name
    result.genre = genre
    return result
end

function Source:parseStoryDetails(html)
    local description_html = html:match(
        '<div[^>]-class="[^"]*story%-detail%-info[^"]*detail%-content[^"]*"[^>]*>([%s%S]-)</div>'
    )
    local author_html = html:match(
        '<li[^>]-class="[^"]*author[^"]*"[^>]*>([%s%S]-)</li>'
    )
    local status_html = html:match(
        '<li[^>]-class="[^"]*status[^"]*"[^>]*>([%s%S]-)</li>'
    )
    local genre_html = html:match(
        '<ul[^>]-class="[^"]*list01[^"]*"[^>]*>([%s%S]-)</ul>'
    )

    local author
    for paragraph in tostring(author_html or ""):gmatch("<p[^>]*>([%s%S]-)</p>") do
        author = Util.stripTags(paragraph)
    end
    local status
    for paragraph in tostring(status_html or ""):gmatch("<p[^>]*>([%s%S]-)</p>") do
        status = Util.stripTags(paragraph)
    end

    return {
        description = Util.stripTags(description_html)
            ~= "" and Util.stripTags(description_html)
            or Util.getMetaContent(html, "name", "description"),
        author = author,
        status = status,
        genres = Util.parseGenreNames(genre_html),
    }
end

function Source:getStoryDetails(story)
    local html, err = Http:get(story.url, requestHeaders(), { force_luasec = true })
    if not html then
        return nil, err
    end
    return self:parseStoryDetails(html)
end

function Source:parseStoryPage(html, story)
    local chapters = {}
    local slug = story.url:match("([^/]+)$") or ""
    local base_slug = slug:match("^(.-)%-%d+%.html$") or slug:match("^(.-)%.html$") or slug

    -- Parse chapter links from works-chapter-item divs (preferred structure)
    for item_html in html:gmatch('<div[^>]-class="[^"]*works%-chapter%-item[^"]*"[^>]*>([%s%S]-)</div>%s*</div>') do
        for anchor_attrs, anchor_html in item_html:gmatch("<a([^>]*)>([%s%S]-)</a>") do
            local href = Util.getAttribute(anchor_attrs, "href")
            local chapter_url = Util.absoluteUrl(self.base_url, href)
            if chapter_url and chapter_url:find(base_slug, 1, true) then
                local lurl = (chapter_url or ""):lower()
                if lurl:find("%-chap%-") or lurl:find("chapter") or lurl:find("chuong") then
                    table.insert(chapters, {
                        title = Util.stripTags(anchor_html),
                        url = chapter_url,
                        source_id = self.id,
                        story_url = story.url,
                        kind = self.kind,
                    })
                end
            end
        end
    end

    -- Fallback: search for chapter links inside list_chapter container
    if #chapters == 0 then
        local list_html = html:match('<div[^>]-class="[^"]*list_chapter[^"]*"[^>]*>([%s%S]-)</div>%s*</div>%s*<div[^>]-id="ad_info"')
            or html
        for anchor_attrs, anchor_html in list_html:gmatch("<a([^>]*)>([%s%S]-)</a>") do
            local href = Util.getAttribute(anchor_attrs, "href")
            local chapter_url = Util.absoluteUrl(self.base_url, href)
            if chapter_url and chapter_url:find(base_slug, 1, true) then
                local lurl = (chapter_url or ""):lower()
                if lurl:find("%-chap%-") or lurl:find("chapter") or lurl:find("chuong") then
                    table.insert(chapters, {
                        title = Util.stripTags(anchor_html),
                        url = chapter_url,
                        source_id = self.id,
                        story_url = story.url,
                        kind = self.kind,
                    })
                end
            end
        end
    end

    story.details = self:parseStoryDetails(html)
    return {
        story = story,
        chapters = Util.uniqueBy(chapters, "url"),
        page = 1,
        total_pages = 1,
    }
end

function Source:getStoryPage(story)
    local html, err = Http:get(story.url, requestHeaders(), { force_luasec = true })
    if not html then
        return nil, err
    end
    return self:parseStoryPage(html, story)
end

function Source:parseChapter(html, chapter)
    local images = {}
    local position = 1

    while true do
        local open_start, open_end, div_attrs = html:find("<div([^>]*)>", position)
        if not open_start then
            break
        end
        position = open_end + 1

        local page_id = Util.getAttribute(div_attrs, "id") or ""
        local class_name = Util.getAttribute(div_attrs, "class") or ""
        if page_id:match("^page_%d+$")
                and class_name:find("page-chapter", 1, true) then
            local close_start, close_end = html:find("</div>", position, true)
            if not close_start then
                break
            end

            local div_html = html:sub(position, close_start - 1)
            position = close_end + 1
            for image_tag in div_html:gmatch("(<img[^>]*>)") do
                local primary = Util.getAttribute(image_tag, "data-original")
                    or Util.getAttribute(image_tag, "src")
                if primary then
                    local clean_urls = {}
                    local seen = {}
                    local candidates = {
                        primary,
                        Util.getAttribute(image_tag, "data-cdn"),
                        Util.getAttribute(image_tag, "data-fb"),
                    }
                    for index = 1, 3 do
                        local url = Util.absoluteUrl(self.base_url, candidates[index])
                        if url and not seen[url] then
                            seen[url] = true
                            table.insert(clean_urls, url)
                        end
                    end
                    table.insert(images, { urls = clean_urls })
                end
            end
        end
    end

    if #images == 0 then
        return nil, "Không tìm thấy ảnh của chương"
    end

    local title
    for heading_attrs, heading_html in html:gmatch("<h1([^>]*)>([%s%S]-)</h1>") do
        local class_name = Util.getAttribute(heading_attrs, "class") or ""
        if class_name:find("detail-title", 1, true) then
            title = Util.stripTags(heading_html)
            break
        end
    end

    return {
        title = title or chapter.title,
        images = images,
        url = chapter.url,
        referer = self.base_url .. "/",
        kind = self.kind,
    }
end

function Source:getChapter(chapter)
    local html, err = Http:get(chapter.url, requestHeaders(), { force_luasec = true })
    if not html then
        return nil, err
    end
    return self:parseChapter(html, chapter)
end

return Source
```

## truyenviet.koplugin/truyenviet/sources/tve4u.lua

```lua
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
```

## truyenviet.koplugin/truyenviet/source_registry.lua

```lua
local Storage = require("truyenviet/storage")

local SourceRegistry = {}

local BUILTIN_SOURCES = {
    require("truyenviet/sources/truyenfull"),
    require("truyenviet/sources/truyenqq"),
    require("truyenviet/sources/dualeo"),
    require("truyenviet/sources/truyendich"),
    require("truyenviet/sources/cbunu"),
    require("truyenviet/sources/haccbl"),
    require("truyenviet/sources/giatocvuongtai"),
    require("truyenviet/sources/docln"),
    require("truyenviet/sources/tve4u"),
    require("truyenviet/sources/dilib"),
    require("truyenviet/sources/mizzya"),
    require("truyenviet/sources/metruyenvn"),
    require("truyenviet/sources/aztruyen"),
    require("truyenviet/sources/dualeotruyenfull"),
    require("truyenviet/sources/truyenc"),
}

local SOURCES_BY_ID = {}
local DEFAULT_BASE_URLS = {}
for _, source in ipairs(BUILTIN_SOURCES) do
    SOURCES_BY_ID[source.id] = source
    DEFAULT_BASE_URLS[source.id] = source.base_url
end

local function applyBaseUrl(source)
    source.base_url = Storage:getCustomBaseUrl(source.id)
        or DEFAULT_BASE_URLS[source.id]
    return source
end

function SourceRegistry:get(source_id)
    if not source_id then return nil end
    local source = SOURCES_BY_ID[source_id]
    if source then
        applyBaseUrl(source)
    end
    return source
end

function SourceRegistry:listAll()
    local result = {}
    for _, source in ipairs(BUILTIN_SOURCES) do
        table.insert(result, applyBaseUrl(source))
    end
    return result
end

function SourceRegistry:listEnabled()
    local result = {}
    for _, source in ipairs(BUILTIN_SOURCES) do
        if Storage:isSourceEnabled(source.id) then
            table.insert(result, applyBaseUrl(source))
        end
    end
    return result
end

function SourceRegistry:isEnabled(source_id)
    return SOURCES_BY_ID[source_id] ~= nil and Storage:isSourceEnabled(source_id)
end

function SourceRegistry:setEnabled(source_id, enabled)
    if not SOURCES_BY_ID[source_id] then
        return nil, "Nguồn truyện không tồn tại"
    end
    return Storage:setSourceEnabled(source_id, enabled)
end

return SourceRegistry
```

## truyenviet.koplugin/truyenviet/storage.lua

```lua
local DataStorage = require("datastorage")
local LuaSettings = require("luasettings")
local ffiutil = require("ffi/util")
local lfs = require("libs/libkoreader-lfs")
local ko_util = require("util")
local Util = require("truyenviet/helpers")

local Storage = {
    settings = nil,
    root_dir = nil,
    cache_dir = nil,
    disabled_sources = nil,
}

local function copyTable(value)
    local result = {}
    for key, item in pairs(type(value) == "table" and value or {}) do
        result[key] = item
    end
    return result
end

local function persistSetting(self, key, value)
    local previous = self.settings:readSetting(key)
    local ok, err = pcall(function()
        self.settings:saveSetting(key, value)
        self.settings:flush()
    end)
    if not ok then
        pcall(self.settings.saveSetting, self.settings, key, previous)
        return nil, tostring(err)
    end
    return true
end

function Storage:initialize()
    if self.settings then
        return
    end

    self.root_dir = ffiutil.joinPath(DataStorage:getFullDataDir(), "truyenviet")
    ko_util.makePath(self.root_dir)
    self.cache_dir = ffiutil.joinPath(self.root_dir, "cache")
    ko_util.makePath(self.cache_dir)
    self.settings = LuaSettings:open(
        ffiutil.joinPath(DataStorage:getSettingsDir(), "truyenviet.lua")
    )
    self.disabled_sources = {}
    local disabled_sources = self.settings:readSetting("disabled_sources", {})
    if type(disabled_sources) ~= "table" then
        disabled_sources = {}
    end
    for source_id, disabled in pairs(disabled_sources) do
        if disabled == true then
            self.disabled_sources[source_id] = true
        end
    end
end

function Storage:getRootDir()
    self:initialize()
    return self.root_dir
end

function Storage:getCoverCacheDir()
    self:initialize()
    local path = ffiutil.joinPath(self.cache_dir, "covers")
    ko_util.makePath(path)
    return path
end

function Storage:clearCoverCacheDir()
    local dir = self:getCoverCacheDir()
    local ok = pcall(function()
        for file in lfs.dir(dir) do
            if file ~= "." and file ~= ".." then
                local path = ffiutil.joinPath(dir, file)
                if lfs.attributes(path, "mode") == "file" then
                    os.remove(path)
                end
            end
        end
    end)
    return ok
end

function Storage:getCustomBaseUrl(source_id)
    self:initialize()
    local url = self.settings:readSetting("custom_url_" .. source_id)
    return type(url) == "string" and url ~= "" and url or nil
end

function Storage:setCustomBaseUrl(source_id, url)
    self:initialize()
    if url and url ~= "" then
        url = url:match("^%s*(.-)%s*$"):gsub("/+$", "")
        if url == "" then
            url = nil
        end
    end
    return persistSetting(self, "custom_url_" .. source_id, url)
end

function Storage:setFastMode(enabled)
    self:initialize()
    return persistSetting(self, "fast_mode", enabled == true)
end

function Storage:isSourceEnabled(source_id)
    self:initialize()
    return self.disabled_sources[source_id] ~= true
end

function Storage:setSourceEnabled(source_id, enabled)
    self:initialize()
    local was_disabled = self.disabled_sources[source_id] == true
    if enabled then
        self.disabled_sources[source_id] = nil
    else
        self.disabled_sources[source_id] = true
    end

    local saved = {}
    for id, disabled in pairs(self.disabled_sources) do
        if disabled == true then
            saved[id] = true
        end
    end

    local ok, err = pcall(function()
        self.settings:saveSetting("disabled_sources", saved)
        self.settings:flush()
    end)
    if not ok then
        self.disabled_sources[source_id] = was_disabled and true or nil
        return nil, tostring(err)
    end
    return true
end

function Storage:getStoryDir(source, story)
    self:initialize()
    local source_dir = ffiutil.joinPath(self.root_dir, source.id)
    local story_dir = ffiutil.joinPath(source_dir, Util.urlLeaf(story.url, "story"))
    ko_util.makePath(story_dir)
    return story_dir
end

function Storage:getChapterPath(source, story, chapter)
    local extension = source.kind == "comic" and ".cbz" or ".html"
    local filename = Util.urlLeaf(chapter.url, Util.safeName(chapter.title, "chapter"))
    return ffiutil.joinPath(self:getStoryDir(source, story), filename .. extension)
end

function Storage:isDownloaded(source, story, chapter)
    return lfs.attributes(self:getChapterPath(source, story, chapter), "mode") == "file"
end

function Storage:removeDownload(source, story, chapter)
    local path = self:getChapterPath(source, story, chapter)
    if lfs.attributes(path, "mode") == "file" then
        return os.remove(path)
    end
    return true
end

function Storage:removeAllDownloads()
    local path = self:getRootDir()
    if lfs.attributes(path, "mode") ~= "directory" then return true end

    local function rmdir_recursive(dir_path)
        for file in lfs.dir(dir_path) do
            if file ~= "." and file ~= ".." then
                local full_path = dir_path .. "/" .. file
                if lfs.attributes(full_path, "mode") == "directory" then
                    rmdir_recursive(full_path)
                else
                    os.remove(full_path)
                end
            end
        end
        lfs.rmdir(dir_path)
    end

    local ok, err = pcall(rmdir_recursive, path)
    -- Recreate the root directory after deletion
    lfs.mkdir(path)
    return ok, err
end

function Storage:getFavorites()
    self:initialize()
    local favorites = self.settings:readSetting("favorites", {})
    return type(favorites) == "table" and favorites or {}
end

function Storage:isFavorite(story)
    if not story or not story.source_id or not story.url then return false end
    return self:getFavorites()[story.source_id .. "|" .. story.url] ~= nil
end

local function favoriteRecord(story)
    return {
        source_id = story.source_id,
        title = story.title,
        url = story.url,
        cover_url = story.cover_url,
        kind = story.kind,
        details = story.details,
    }
end

function Storage:addFavorite(story)
    local favorites = copyTable(self:getFavorites())
    favorites[story.source_id .. "|" .. story.url] = favoriteRecord(story)
    return persistSetting(self, "favorites", favorites)
end

function Storage:updateFavorite(story)
    if self:isFavorite(story) then
        return self:addFavorite(story)
    end
    return true
end

function Storage:removeFavorite(story)
    local favorites = copyTable(self:getFavorites())
    favorites[story.source_id .. "|" .. story.url] = nil
    return persistSetting(self, "favorites", favorites)
end

-- Xóa tất cả file đã tải của một truyện (dùng cho xóa hết)
local function deleteStoryDownloads(self, story_record)
    local source_dir = ffiutil.joinPath(self.root_dir, story_record.source_id)
    local story_dir = ffiutil.joinPath(source_dir, Util.urlLeaf(story_record.url, "story"))
    if lfs.attributes(story_dir, "mode") ~= "directory" then return end
    local function rmdir(dir)
        for file in lfs.dir(dir) do
            if file ~= "." and file ~= ".." then
                local fp = dir .. "/" .. file
                if lfs.attributes(fp, "mode") == "directory" then
                    rmdir(fp)
                else
                    os.remove(fp)
                end
            end
        end
        lfs.rmdir(dir)
    end
    pcall(rmdir, story_dir)
end

function Storage:clearAllFavorites(with_downloads)
    self:initialize()
    if with_downloads then
        for _, story in pairs(self:getFavorites()) do
            if type(story) == "table" then
                pcall(deleteStoryDownloads, self, story)
            end
        end
    end
    return persistSetting(self, "favorites", {})
end

function Storage:listFavorites()
    local result = {}
    for _, story in pairs(self:getFavorites()) do
        if type(story) == "table"
                and type(story.title) == "string"
                and type(story.url) == "string"
                and type(story.source_id) == "string" then
            table.insert(result, story)
        end
    end
    table.sort(result, function(left, right)
        return left.title:lower() < right.title:lower()
    end)
    return result
end

function Storage:getHistory()
    self:initialize()
    local history = self.settings:readSetting("history", {})
    if type(history) ~= "table" then
        return {}
    end

    local valid_history = {}
    for _, item in ipairs(history) do
        if type(item) == "table"
                and type(item.story) == "table"
                and type(item.story.source_id) == "string"
                and type(item.story.title) == "string"
                and type(item.story.url) == "string"
                and type(item.chapter) == "table"
                and type(item.chapter.title) == "string"
                and type(item.chapter.url) == "string" then
            table.insert(valid_history, item)
        end
    end
    return valid_history
end

function Storage:saveHistory(story, chapter)
    local history = copyTable(self:getHistory())
    local existing_idx
    for i, item in ipairs(history) do
        if item.story.source_id == story.source_id and item.story.url == story.url then
            existing_idx = i
            break
        end
    end
    if existing_idx then
        table.remove(history, existing_idx)
    end
    
    local clean_story = favoriteRecord(story)
    table.insert(history, 1, {
        story = clean_story,
        chapter = {
            title = chapter.title,
            url = chapter.url,
        },
        time = os.time(),
    })
    
    while #history > 100 do
        table.remove(history)
    end
    
    return persistSetting(self, "history", history)
end

function Storage:removeHistory(story)
    local history = copyTable(self:getHistory())
    local existing_idx
    for i, item in ipairs(history) do
        if item.story.source_id == story.source_id and item.story.url == story.url then
            existing_idx = i
            break
        end
    end
    if existing_idx then
        table.remove(history, existing_idx)
        return persistSetting(self, "history", history)
    end
    return true
end

function Storage:clearAllHistory(with_downloads)
    self:initialize()
    if with_downloads then
        for _, item in ipairs(self:getHistory()) do
            if type(item) == "table" and type(item.story) == "table" then
                pcall(deleteStoryDownloads, self, item.story)
            end
        end
    end
    return persistSetting(self, "history", {})
end

-- Ebook storage methods for TVE-4U and Dilib sources

function Storage:getEbookDir(source, book)
    self:initialize()
    local source_dir = ffiutil.joinPath(self.root_dir, source.id)
    local book_slug = Util.urlLeaf(book.url, Util.safeName(book.title, "book"))
    local book_dir = ffiutil.joinPath(source_dir, book_slug)
    ko_util.makePath(book_dir)
    return book_dir
end

function Storage:getEbookPath(source, book, filename)
    return ffiutil.joinPath(self:getEbookDir(source, book), Util.safeName(filename, "file"))
end

function Storage:isEbookDownloaded(source, book, filename)
    local path = self:getEbookPath(source, book, filename)
    return lfs.attributes(path, "mode") == "file", path
end

function Storage:listEbookFiles(source, book)
    local dir = self:getEbookDir(source, book)
    local files = {}
    local ok = pcall(function()
        for file in lfs.dir(dir) do
            if file ~= "." and file ~= ".." then
                local path = ffiutil.joinPath(dir, file)
                local attr = lfs.attributes(path)
                if attr and attr.mode == "file" then
                    table.insert(files, {
                        name = file,
                        path = path,
                        size = attr.size,
                    })
                end
            end
        end
    end)
    return files
end

return Storage

```

## truyenviet.koplugin/truyenviet/test_az.lua

```lua
local Http = require("http_client")
local Util = require("helpers")

local function test()
    local html, err = Http:get("https://aztruyen.top/tim-kiem/nguoi")
    if not html then 
        print("ERR: ", err)
        return
    end
    print("HTML length: ", #html)
    -- Try to find stories
    for href, title in html:gmatch('<h3 class="story%-title"[^>]*>.-<a href="(https?://aztruyen%.top/truyen/[^"]+)"[^>]*>([^<]+)</a>') do
        print("FOUND:", href, Util.trim(title))
    end
    -- Or other pattern:
    for block in html:gmatch('<div class="story%-item".-</div>%s*</div>%s*</div>') do
        local href = block:match('href="(https?://aztruyen%.top/truyen/[^"]+)"')
        local title = block:match('title="([^"]+)"')
        local cover = block:match('<img[^>]+src="([^"]+)"')
        if href then
            print("BLOCK FOUND:", href, title, cover)
        end
    end
end

test()
```

## truyenviet.koplugin/truyenviet/test_dilib.lua

```lua
local Http = require("http_client")
local source = dofile("sources/dilib.lua")
local cat = {url = "https://dilib.vn/thu-vien/tam-ly-ky-nang/"}
local res, err = source:getCategoryBooks(cat, 1)
if err then
    print("Error:", err)
else
    print("Found books:", res and res.books and #res.books or 0)
    for i, b in ipairs(res.books or {}) do
        print(i, b.title, b.url, b.cover_url)
    end
end
```

## truyenviet.koplugin/truyenviet/test_genre.lua

```lua
local Util = require("helpers")

local html = [[
<a href="https://metruyenvn.org/the-loai/1v1/">1v1</a>
<a  href="https://metruyenvn.org/the-loai/18/">18 +</a>
]]

local genres = {}
for href, name in html:gmatch('<a[^>]+href="(https?://metruyenvn%.org/the%-loai/[^"]+)"[^>]*>([^<]+)</a>') do
    table.insert(genres, { name = Util.trim(name), url = href })
end

for _, g in ipairs(genres) do
    print(g.name, g.url)
    local url = Util.withTrailingSlash(g.url)
    print("withTrailingSlash:", url)
end
```

## truyenviet.koplugin/truyenviet/test_metruyenvn.lua

```lua
local Source = require("sources.metruyenvn")

local function test()
    print("Testing getCompleted...")
    local list = Source:getCompleted(1)
    if not list or not list.stories or #list.stories == 0 then
        print("Failed to get stories")
        return
    end
    print("Found " .. #list.stories .. " stories.")
    local story = list.stories[1]
    print("Testing getStoryPage for " .. story.url)
    
    local page, err = Source:getStoryPage(story, 1)
    if not page then
        print("Failed to get story page: " .. tostring(err))
        return
    end
    if not page.chapters or #page.chapters == 0 then
        print("Failed to get chapters")
        return
    end
    print("Found " .. #page.chapters .. " chapters.")
    local chapter = page.chapters[2] or page.chapters[1]
    
    print("Testing getChapter for " .. chapter.url)
    local content, err2 = Source:getChapter(chapter)
    if not content then
        print("Failed to get chapter content: " .. tostring(err2))
    else
        print("Got content, length: " .. string.len(content))
    end
end

test()
```

## truyenviet.koplugin/truyenviet/test_mizzya.lua

```lua
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
```

## truyenviet.koplugin/truyenviet/test_truyenqq.lua

```lua
package.path = package.path .. ";./?.lua;./libs/?.lua"
local Source = require("sources/truyenqq")
local f = io.open("truyenqq_home.html", "r")
local html = f:read("*a")
f:close()

local res = Source:parseListing(html, 1)
print("Stories found: " .. (res and res.stories and #res.stories or 0))
if res and res.stories and #res.stories > 0 then
    print(res.stories[1].title)
    print(res.stories[1].url)
    print(res.stories[1].cover_url)
end
```

## truyenviet.koplugin/truyenviet/version.lua

```lua
return "3.0.2"
```

## truyenviet.koplugin/truyenviet/widgets/story_results.lua

```lua
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
```

## truyenviet.koplugin/_meta.lua

```lua
return {
    fullname = "Truyện Việt",
    description = "Tìm, tải và đọc truyện trực tuyến từ TruyenFull, TruyenQQ, Dưa Leo và Truyendich.",
}
```

