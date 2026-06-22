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
            local status, ffi = pcall(require, "ffi")
            if status and ffi then
                pcall(function()
                    ffi.cdef[[
                        typedef struct evp_md_st EVP_MD;
                        typedef struct evp_cipher_st EVP_CIPHER;
                        const EVP_MD *EVP_sha512(void);
                        int PKCS5_PBKDF2_HMAC(const char *pass, int passlen,
                                              const unsigned char *salt, int saltlen, int iter,
                                              const EVP_MD *digest,
                                              int keylen, unsigned char *out);
                        const EVP_CIPHER *EVP_aes_256_cbc(void);
                        typedef struct evp_cipher_ctx_st EVP_CIPHER_CTX;
                        EVP_CIPHER_CTX *EVP_CIPHER_CTX_new(void);
                        void EVP_CIPHER_CTX_free(EVP_CIPHER_CTX *c);
                        int EVP_DecryptInit_ex(EVP_CIPHER_CTX *ctx, const EVP_CIPHER *cipher, void *impl,
                                               const unsigned char *key, const unsigned char *iv);
                        int EVP_DecryptUpdate(EVP_CIPHER_CTX *ctx, unsigned char *out, int *outl,
                                              const unsigned char *in_buf, int inl);
                        int EVP_DecryptFinal_ex(EVP_CIPHER_CTX *ctx, unsigned char *outm, int *outl);
                    ]]
                end)
                local crypto_status, libcrypto = pcall(ffi.load, "crypto")
                if crypto_status and libcrypto then
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

                    local derivedKey = ffi.new("unsigned char[32]")
                    local res = libcrypto.PKCS5_PBKDF2_HMAC(keyStr, #keyStr, salt, #salt, 999, libcrypto.EVP_sha512(), 32, derivedKey)
                    if res == 1 then
                        local ctx = libcrypto.EVP_CIPHER_CTX_new()
                        if ctx ~= nil then
                            libcrypto.EVP_DecryptInit_ex(ctx, libcrypto.EVP_aes_256_cbc(), nil, derivedKey, iv)
                            local out = ffi.new("unsigned char[?]", #cipherbin + 32)
                            local outl = ffi.new("int[1]")
                            local outl2 = ffi.new("int[1]")
                            libcrypto.EVP_DecryptUpdate(ctx, out, outl, cipherbin, #cipherbin)
                            local final_res = libcrypto.EVP_DecryptFinal_ex(ctx, out + outl[0], outl2)
                            if final_res == 1 then
                                content = ffi.string(out, outl[0] + outl2[0])
                            end
                            libcrypto.EVP_CIPHER_CTX_free(ctx)
                        end
                    end
                end
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
