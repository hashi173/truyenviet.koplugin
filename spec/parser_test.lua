local root = "."
package.path = table.concat({
    root .. "/truyenviet.koplugin/?.lua",
    root .. "/truyenviet.koplugin/?/init.lua",
    package.path,
}, ";")

package.preload["truyenviet/http_client"] = function()
    return {}
end

package.preload["socket.url"] = function()
    return {
        absolute = function(base, href)
            if href:match("^https?://") then
                return href
            end
            return base:gsub("/+$", "") .. "/" .. href:gsub("^/+", "")
        end,
    }
end

local mock_json = {}
package.preload["json"] = function()
    return {
        decode = setmetatable({}, {
            __call = function(_, value)
                return mock_json[value]
            end,
        }),
    }
end

package.preload["socket"] = function()
    return { gettime = function() return 0 end }
end

package.preload["util"] = function()
    return {
        htmlEntitiesToUtf8 = function(value)
            return value
                :gsub("&amp;", "&")
                :gsub("&quot;", '"')
                :gsub("&#39;", "'")
        end,
        replaceAllInvalidChars = function(value)
            return value:gsub('[\\/:*?"<>|]', "_")
        end,
        stringLower = function(value)
            return value:lower()
        end,
        urlEncode = function(value)
            return value:gsub(" ", "%%20")
        end,
        jsonDecode = function(value)
            return mock_json[value]
        end,
    }
end

local source_states = {}
local custom_urls = {}
package.preload["truyenviet/storage"] = function()
    return {
        getCustomBaseUrl = function(_, source_id)
            return custom_urls[source_id]
        end,
        setCustomBaseUrl = function(_, source_id, url)
            custom_urls[source_id] = url
            return true
        end,
        isSourceEnabled = function(_, source_id)
            return source_states[source_id] ~= false
        end,
        setSourceEnabled = function(_, source_id, enabled)
            source_states[source_id] = enabled
            return true
        end,
    }
end

package.preload["truyenviet/debugger"] = function()
    return {
        write = function() end,
    }
end

local TruyenFull = require("truyenviet/sources/truyenfull")
local TruyenQQ = require("truyenviet/sources/truyenqq")
local DuaLeo = require("truyenviet/sources/dualeo")
local TruyenDich = require("truyenviet/sources/truyendich")
local Haccbl = require("truyenviet/sources/haccbl")
local SearchService = require("truyenviet/search_service")
local SourceRegistry = require("truyenviet/source_registry")
local Util = require("truyenviet/helpers")
local Http = require("truyenviet/http_client")

local tests_run = 0

local function assertEqual(expected, actual, message)
    tests_run = tests_run + 1
    if expected ~= actual then
        error(string.format(
            "%s: expected %s, got %s",
            message,
            tostring(expected),
            tostring(actual)
        ))
    end
end

local function assertContains(value, expected, message)
    tests_run = tests_run + 1
    if not value or not value:find(expected, 1, true) then
        error(message .. ": missing " .. expected)
    end
end

local text_search = [[
    <div data-image="https://img.example/text-cover.jpg"></div>
    <h3 class="truyen-title">
      <a href="https://truyenfull.today/demo/" title="Truyện Demo">Truyện Demo</a>
    </h3>
]]
local text_stories = TruyenFull:parseSearch(text_search)
assertEqual(1, #text_stories, "TruyenFull search count")
assertEqual("Truyện Demo", text_stories[1].title, "TruyenFull search title")
assertEqual(
    "https://img.example/text-cover.jpg",
    text_stories[1].cover_url,
    "TruyenFull search cover"
)
local text_listing = TruyenFull:parseListing(text_search .. [[
    <a href="/the-loai/tien-hiep/">Tiên Hiệp</a>
    <a href="/danh-sach/truyen-full/trang-5/">5</a>
]], 1)
assertEqual(5, text_listing.total_pages, "TruyenFull listing pages")
assertEqual(1, #text_listing.genres, "TruyenFull listing genres")

local text_picture_search = [[
    <div class="navbar"><img src="/logo.png"></div>
    <div class="row" itemscope itemtype="https://schema.org/Book">
      <div class="col-xs-3"><picture><source media="(max-width: 568px)" srcset="https://static.truyenfull.live/cover/portrait-60x85.webp" width="60" height="85"><img src="https://static.truyenfull.live/cover/landscape-180x80.webp" class="cover" width="180" height="80" itemprop="image"></picture></div>
      <div class="col-xs-7"><h3 class="truyen-title"><a href="https://truyenfull.live/new/" title="Truyện Mới">Truyện Mới</a></h3><span class="label-title label-new"></span><span class="label-title label-full"></span></div>
    </div>
    <div class="row">
      <div class="col-xs-7"><h3 class="truyen-title"><a href="https://truyenfull.live/no-cover/" title="Không Bìa">Không Bìa</a></h3><span class="label-title label-new"></span></div>
    </div>
]]
local text_picture_stories = TruyenFull:parseSearch(text_picture_search)
assertEqual(2, #text_picture_stories, "TruyenFull picture search count")
assertEqual(
    "https://static.truyenfull.live/cover/portrait-60x85.webp",
    text_picture_stories[1].cover_url,
    "TruyenFull prefers portrait <source srcset> over landscape <img src>"
)
assertEqual(true, text_picture_stories[1].is_full, "TruyenFull detects label-full completed badge")
assertEqual(nil, text_picture_stories[2].cover_url, "TruyenFull coverless item stays nil")
assertEqual(nil, text_picture_stories[2].is_full, "TruyenFull ongoing item has nil is_full")

local text_details = TruyenFull:parseStoryDetails([[
    <div class="info">
      <a itemprop="author" href="/tac-gia/demo/">Tác Giả Demo</a>
      <a itemprop="genre" href="/the-loai/tien-hiep/">Tiên Hiệp</a>
      <span class="text-success">Full</span>
    </div>
    <div class="col-xs-12 col-sm-8 col-md-8 desc">
      <div class="desc-text desc-text-full" itemprop="description">
        Mô tả <b>truyện chữ</b>.<br>Đoạn tiếp theo.
      </div>
    </div>
]])
assertContains(text_details.description, "Mô tả truyện chữ", "TruyenFull details")
assertEqual("Tác Giả Demo", text_details.author, "TruyenFull author")
assertEqual("Full", text_details.status, "TruyenFull status")
assertEqual("Tiên Hiệp", text_details.genres[1], "TruyenFull detail genre")

local text_story = {
    title = "Truyện Demo",
    url = "https://truyenfull.today/demo/",
}
local text_detail = [[
    <div class="col-xs-12" id="list-chapter">
      <a href="/demo/chuong-1/"><span>Chương </span>1</a>
    </div>
    <input class="metadata" id="truyen-id" value="1">
    <input id="total-page" type="hidden" value="3">
]]
local text_page = TruyenFull:parseStoryPage(text_detail, text_story, 1)
assertEqual(1, #text_page.chapters, "TruyenFull chapter count")
assertEqual(3, text_page.total_pages, "TruyenFull page count")

local text_chapter = [[
    <h2><a class="chapter-title">Chương 1</a></h2>
    <div class="chapter-c" id="chapter-c"><div id="ads-chapter-top"></div>
      Nội dung<br/><br/>Đoạn hai
    </div>
    <div id="ads-chapter-bottom"></div>
    <hr class="chapter-end">
]]
local text_payload = assert(TruyenFull:parseChapter(
    text_chapter,
    { title = "Chương 1", url = "https://truyenfull.today/demo/chuong-1/" }
))
assertContains(text_payload.content, "Nội dung", "TruyenFull chapter content")
assertEqual(
    nil,
    text_payload.content:find("ads-chapter-top", 1, true),
    "TruyenFull removes chapter ads"
)

local comic_search = [[
  <li>
    <a href="/truyen-tranh/demo-123">
      <img src="/cover/demo.jpg">
      <div class="search_info"><p class="name">Manga Demo</p></div>
    </a>
  </li>
]]
local comic_stories = TruyenQQ:parseSearch(comic_search)
assertEqual(1, #comic_stories, "TruyenQQ search count")
assertEqual(
    "https://truyenqqko.com/cover/demo.jpg",
    comic_stories[1].cover_url,
    "TruyenQQ cover URL"
)
local comic_listing = TruyenQQ:parseListing([[
  <ul class="list_grid grid">
    <li>
      <div class="book_avatar">
        <a href="/truyen-tranh/demo-123"><img src="/cover/demo.jpg"></a>
      </div>
      <div class="book_info">
        <div class="book_name qtip">
          <h3><a title="Manga Demo" href="/truyen-tranh/demo-123">Manga Demo</a></h3>
        </div>
      </div>
    </li>
  </ul>
  <a href="/the-loai/action-26">Action</a>
  <a href="/truyen-hoan-thanh/trang-12">12</a>
]], 1)
assertEqual(1, #comic_listing.stories, "TruyenQQ listing count")
assertEqual(12, comic_listing.total_pages, "TruyenQQ listing pages")
assertEqual(1, #comic_listing.genres, "TruyenQQ listing genres")

local comic_details = TruyenQQ:parseStoryDetails([[
  <li class="author row">
    <p class="name">Tác giả</p><p class="col-xs-9"><a>TruyenQQ</a></p>
  </li>
  <li class="status row">
    <p class="name">Tình trạng</p><p class="col-xs-9">Đang ra</p>
  </li>
  <ul class="list01"><li><a href="/the-loai/action-26">Action</a></li></ul>
  <div class="story-detail-info detail-content">
    <p>Một anh hùng trở lại sau nhiều năm.</p>
  </div>
]])
assertContains(comic_details.description, "anh hùng", "TruyenQQ details")
assertEqual("TruyenQQ", comic_details.author, "TruyenQQ author")
assertEqual("Đang ra", comic_details.status, "TruyenQQ status")
assertEqual("Action", comic_details.genres[1], "TruyenQQ detail genre")

local comic_story = {
    title = "Manga Demo",
    url = "https://truyenqqko.com/truyen-tranh/demo-123",
}
local comic_detail = [[
  <a href="/truyen-tranh/other-456-chap-9">Truyện khác</a>
  <a href="/truyen-tranh/demo-123-chap-2">Chương 2</a>
  <a href="/truyen-tranh/demo-123-chap-1">Chương 1</a>
]]
local comic_page = TruyenQQ:parseStoryPage(comic_detail, comic_story)
assertEqual(2, #comic_page.chapters, "TruyenQQ filters unrelated chapters")

local comic_chapter = [[
  <h1 class="detail-title">Manga Demo - Chapter 2</h1>
  <div id="page_0" class="page-chapter">
    <img data-original="https://img.example/0.jpg"
         data-cdn="https://img2.example/0.jpg">
  </div>
  <div class="page-chapter" id="page_1">
    <img src="/images/1.webp" data-fb="https://fallback.example/1.webp">
  </div>
]]
local comic_payload = assert(TruyenQQ:parseChapter(
    comic_chapter,
    comic_page.chapters[1]
))
assertEqual(2, #comic_payload.images, "TruyenQQ image count")
assertEqual(2, #comic_payload.images[1].urls, "TruyenQQ CDN fallbacks")
assertEqual(
    "https://truyenqqko.com/images/1.webp",
    comic_payload.images[2].urls[1],
    "TruyenQQ relative image URL"
)

local dualeo_search = [[
  <div class="li_truyen">
    <a href="/truyen-tranh/anh-duong">
      <img data-src="https://cover.example/anh-duong.webp" alt="Vết Tích Của Ánh Dương">
      <div class="name">Vết Tích Của Ánh Dương</div>
    </a>
  </div>
]]
local dualeo_stories = DuaLeo:parseSearch(dualeo_search)
assertEqual(1, #dualeo_stories, "DuaLeo search count")
assertEqual(
    "https://cover.example/anh-duong.webp",
    dualeo_stories[1].cover_url,
    "DuaLeo search cover"
)
local dualeo_listing = DuaLeo:parseListing(dualeo_search .. [[
  <a href="/the-loai/manga">Manga</a>
  <a href="/truyen-hoan-thanh?page=9">9</a>
]], 1)
assertEqual(9, dualeo_listing.total_pages, "DuaLeo listing pages")
assertEqual(1, #dualeo_listing.genres, "DuaLeo listing genres")

local dualeo_details = DuaLeo:parseStoryDetails([[
  <ul class="list-tag-story list-orange">
    <li><a href="/the-loai/manhwa">Manhwa</a></li>
  </ul>
  <div class="txt">
    <p>Nhóm dịch: Vồn Vã Team</p>
    <p>Tình trang: Đang cập nhật</p>
  </div>
  <div class="story-detail-info">
    <p>Mô tả truyện tranh Dưa Leo.</p>
  </div>
]])
assertContains(dualeo_details.description, "Dưa Leo", "DuaLeo details")
assertEqual("Vồn Vã Team", dualeo_details.translator, "DuaLeo translator")
assertEqual("Đang cập nhật", dualeo_details.status, "DuaLeo status")
assertEqual("Manhwa", dualeo_details.genres[1], "DuaLeo detail genre")

local dualeo_story = {
    title = "Vết Tích Của Ánh Dương",
    url = "https://dualeotruyenbg.com/truyen-tranh/anh-duong",
}
local dualeo_detail = [[
  <a href="/truyen-tranh/anh-duong/chapter-1">Đọc từ đầu</a>
  <div class="list-chapters">
    <a href="/truyen-tranh/anh-duong/chapter-2">Chapter 2</a>
    <a href="/truyen-tranh/anh-duong/chapter-1">Chapter 1</a>
  </div>
]]
local dualeo_page = DuaLeo:parseStoryPage(dualeo_detail, dualeo_story)
assertEqual(2, #dualeo_page.chapters, "DuaLeo chapter count")
assertEqual("Chapter 2", dualeo_page.chapters[1].title, "DuaLeo chapter order")

local dualeo_chapter = [[
  <title>Vết Tích Của Ánh Dương - Chapter 2 - DuaLeoTruyen</title>
  <div class="content_view_chap">
    <img src="https://img.example/1.webp">
    <img src="data:image/gif;base64,placeholder" data-img="/uploads/2.webp">
  </div>
  <div class="control_bottom_content"></div>
]]
local dualeo_payload = assert(DuaLeo:parseChapter(
    dualeo_chapter,
    dualeo_page.chapters[1]
))
assertEqual(2, #dualeo_payload.images, "DuaLeo image count")
assertEqual(
    "https://dualeotruyenbg.com/uploads/2.webp",
    dualeo_payload.images[2].urls[1],
    "DuaLeo lazy image URL"
)

local dualeo_api_genres_raw = "dualeo_api_genres"
mock_json[dualeo_api_genres_raw] = {
    { genre = "BoyLove", count = 4000 },
    { genre = "18+", count = 4800 },
}
local dualeo_api_genres = DuaLeo:parseApiGenres(dualeo_api_genres_raw)
assertEqual(2, #dualeo_api_genres, "DuaLeo API genres count")

local dualeo_api_list_raw = "dualeo_api_list"
mock_json[dualeo_api_list_raw] = {
    page = 1,
    pages = 12,
    data = {
        { slug = "tay-mo-lua-gau", title = "TAY MƠ LỪA GẤU", cover_url = "https://cover.imgdualeo1.com/a.webp" },
    },
}
local dualeo_api_listing = assert(DuaLeo:parseApiListing(dualeo_api_list_raw, 1, dualeo_api_genres))
assertEqual(1, #dualeo_api_listing.stories, "DuaLeo API listing count")
assertEqual(12, dualeo_api_listing.total_pages, "DuaLeo API listing pages")
assertEqual("https://dualeotruyenbg.com/truyen-tranh/tay-mo-lua-gau", dualeo_api_listing.stories[1].url, "DuaLeo API story URL")

local dualeo_api_story_raw = "dualeo_api_story"
mock_json[dualeo_api_story_raw] = {
    slug = "tay-mo-lua-gau",
    title = "TAY MƠ LỪA GẤU",
    cover_url = "https://cover.imgdualeo1.com/a.webp",
    description = "Mô tả API Dưa Leo.",
    team_name = "Team Demo",
    status = "Full",
    genres = { "BoyLove", "Manhwa" },
    chapters = {
        { chapter_slug = "16", title = "Chapter 16\n  1 giờ trước", locked = false },
        { chapter_slug = "17", title = "Chapter 17", locked = true },
    },
}
local dualeo_api_page = assert(DuaLeo:parseApiStory(dualeo_api_story_raw, {
    title = "TAY MƠ LỪA GẤU",
    url = "https://dualeotruyenbg.com/truyen-tranh/tay-mo-lua-gau",
}))
assertEqual(1, #dualeo_api_page.chapters, "DuaLeo API skips locked chapters")
assertEqual("Chapter 16", dualeo_api_page.chapters[1].title, "DuaLeo API cleans newline suffix")
assertEqual("Full", dualeo_api_page.story.details.status, "DuaLeo API status")

local dualeo_api_chap_raw = "dualeo_api_chap"
mock_json[dualeo_api_chap_raw] = {
    { page_index = 2, image_url = "https://cdn7.imgdualeo1.com/2.webp", src = "/img/2.webp" },
    { page_index = 1, image_url = "https://cdn7.imgdualeo1.com/1.webp", src = "/img/1.webp" },
}
local dualeo_api_chap = assert(DuaLeo:parseApiChapter(dualeo_api_chap_raw, dualeo_api_page.chapters[1]))
assertEqual(2, #dualeo_api_chap.images, "DuaLeo API chapter image count")
assertEqual("https://cdn7.imgdualeo1.com/1.webp", dualeo_api_chap.images[1].urls[1], "DuaLeo API sorts by page_index")
assertEqual("https://dualeotruyenbg.com/img/1.webp", dualeo_api_chap.images[1].urls[2], "DuaLeo API includes proxy fallback")



local hacc_listing = Haccbl:parseListing([[
  <div class="manga-item-grid">
    <a href="https://haccbl.xyz/manga/alpha-thi-co-sao/">
      <img class="image-3-4" src="https://haccbl.xyz/wp-content/uploads/alpha.avif">
    </a>
    <h2 class="uk-h5">
      <a class="uk-link-heading" href="https://haccbl.xyz/manga/alpha-thi-co-sao/">
        Alpha thì có sao <span uk-icon="icon: check"></span>
      </a>
    </h2>
  </div>
  <a href="https://haccbl.xyz/truyen-da-hoan-thanh/page/6/">6</a>
]], 1)
assertEqual(1, #hacc_listing.stories, "Haccbl listing count")
assertEqual("Alpha thì có sao", hacc_listing.stories[1].title, "Haccbl listing title")
assertEqual(6, hacc_listing.total_pages, "Haccbl listing pages")

local hacc_search = Haccbl:parseSearch([[
  <article>
    <a href="https://haccbl.xyz/manga/how-to-chase-an-alpha-kimnyeong/">
      <img src="https://haccbl.xyz/wp-content/uploads/alpha.webp">
    </a>
    <h2><a class="uk-link-heading" href="https://haccbl.xyz/manga/how-to-chase-an-alpha-kimnyeong/">
      How to Chase an <mark>Alpha</mark> | Kimnyeong
    </a></h2>
  </article>
]])
assertEqual(1, #hacc_search, "Haccbl search count")
assertEqual("How to Chase an Alpha | Kimnyeong", hacc_search[1].title, "Haccbl search title")

local hacc_page = Haccbl:parseStoryPage([[
  <div class="chapter-list">
    <div class="chapter-item">
      <a class="uk-link-toggle" href="https://haccbl.xyz/manga/nhan-vien-moi-zec/chapter-45/">
        <h3 class="uk-link-heading">Nhân viên mới [...] - Chương 45</h3>
      </a>
    </div>
  </div>
]], {
    title = "Nhân viên mới | Zec",
    url = "https://haccbl.xyz/manga/nhan-vien-moi-zec/",
})
assertEqual(1, #hacc_page.chapters, "Haccbl chapter count")
assertContains(hacc_page.chapters[1].title, "Chương 45", "Haccbl chapter title")

local hacc_payload, hacc_err = Haccbl:parseChapter([[
  <div id="chapter-content">
    <script>var InitMangaEncryptedChapter = {"ciphertext":"abc"};</script>
  </div>
]], hacc_page.chapters[1])
assertEqual(nil, hacc_payload, "Haccbl encrypted chapter is not guessed")
assertContains(hacc_err, "mã hóa", "Haccbl encrypted chapter error")

local hacc_json_raw = "hacc_json_fixture"
mock_json[hacc_json_raw] = {
    {
        title = "Tình <mark>Yêu</mark> Demo",
        url = "https://haccbl.xyz/manga/tinh-yeu-demo/",
        thumb = "https://haccbl.xyz/wp-content/uploads/thumb.avif",
    },
}
Http.getJson = function(_, url)
    assertContains(url, "/wp-json/initlise/v1/search?term=", "Haccbl uses initlise live search JSON")
    return hacc_json_raw
end
local hacc_json_stories = Haccbl:search("yêu")
assertEqual(1, #hacc_json_stories, "Haccbl JSON search count")
assertEqual("Tình Yêu Demo", hacc_json_stories[1].title, "Haccbl JSON strips mark tag")
assertEqual(
    "https://i0.wp.com/haccbl.xyz/wp-content/uploads/thumb.avif?strip=info&format=webp",
    hacc_json_stories[1].cover_url,
    "Haccbl JSON rewrites AVIF cover"
)
Http.getJson = nil

local hacc_b64_blocked, hacc_b64_err = Haccbl:parseChapter([[
  <div id="chapter-content">
    <script type="rocketlazyloadscript" src="data:text/javascript;base64,dmFyIEluaXRNYW5nYUVuY3J5cHRlZENoYXB0ZXIgPSB7ImNpcGhlcnRleHQiOiJhYmMifTs="></script>
  </div>
]], hacc_page.chapters[1])
assertEqual(nil, hacc_b64_blocked, "Haccbl decoded script without key reports encrypted error")
assertContains(hacc_b64_err, "mã hóa", "Haccbl decoded script missing key message")

local hacc_b64_ok = assert(Haccbl:parseChapter([[
  <script type="rocketlazyloadscript" src="data:text/javascript;base64,dmFyIEluaXRNYW5nYURhdGEgPSB7ImRlY3J5cHRpb25fa2V5IjoiZEdWemRDMXJaWGs9In07"></script>
  <div id="chapter-content">
    <script type="rocketlazyloadscript" src="data:text/javascript;base64,dmFyIEluaXRNYW5nYUVuY3J5cHRlZENoYXB0ZXIgPSB7ImNpcGhlcnRleHQiOiJoVDBpaURBQk1xT0dndFEwWWxJTjhaT0xnR3BDZE92ZXVKbUZTYUZxem5GMmsyRE1RQUR3RWtGbEwrenlWL3VyeFBzc0h2NW85TXp3M1pwQktoTE1TQT09IiwiaXYiOiIwMTAyMDMwNDA1MDYwNzA4MDkwYTBiMGMwZDBlMGYxMCIsInNhbHQiOiIwMDExMjIzMzQ0NTU2Njc3ODg5OWFhYmJjY2RkZWVmZiJ9Ow=="></script>
  </div>
]], hacc_page.chapters[1]))
assertEqual(1, #hacc_b64_ok.images, "Haccbl decrypts embedded base64 encrypted script")
assertEqual(
    "https://i0.wp.com/haccbl.xyz/wp-content/uploads/test-1.avif?strip=info",
    hacc_b64_ok.images[1].urls[1],
    "Haccbl decrypted image URL"
)

local DocLN = require("truyenviet/sources/docln")
local docln_listing_html = [[
  <div class="thumb-item-flow">
    <div class="thumb-wrapper"><div data-bg="https://img.example/ln.webp"></div></div>
    <div class="series-title"><a href="/truyen/1-demo-ln" title="Light Novel Demo">Light Novel Demo</a></div>
  </div>
  <a href="/the-loai/fantasy">Fantasy</a>
  <a href="?page=4">4</a>
]]
local docln_listing = DocLN:parseListing(docln_listing_html, 1)
assertEqual(1, #docln_listing.stories, "DocLN listing count")
assertEqual("Light Novel Demo", docln_listing.stories[1].title, "DocLN listing title")
assertEqual("https://img.example/ln.webp", docln_listing.stories[1].cover_url, "DocLN cover URL")
local docln_search_url
Http.request = function() return "<html></html>", nil, {} end
Http.get = function(_, url)
    if url:find("/tim%-kiem") then
        docln_search_url = url
        return docln_listing_html
    end
    return "<html></html>", nil, {}
end
local docln_search = DocLN:search("tiên")
assertContains(docln_search_url, "/tim-kiem?keywords=", "DocLN search uses keywords parameter")
assertEqual(1, #docln_search, "DocLN search count")
Http.get = nil
Http.request = nil

local docln_details = DocLN:parseStoryDetails([[
  <div class="summary-content"><p>Tóm tắt LN.</p></div>
  <div>Tác giả: <a href="/tac-gia/a">Tác Giả LN</a></div>
  <div>Tình trạng: <a href="/tinh-trang/full">Hoàn thành</a></div>
  <div class="series-gernes"><a class="series-gerne-item">Fantasy</a></div>
]])
assertEqual("Tác Giả LN", docln_details.author, "DocLN author")
assertEqual("Hoàn thành", docln_details.status, "DocLN status")
assertContains(docln_details.description, "Tóm tắt LN", "DocLN summary")
local docln_story = { title = "Light Novel Demo", url = "https://docln.sbs/truyen/1-demo-ln" }
local docln_page = DocLN:parseStoryPage([[
  <div class="chapter-name"><a href="/truyen/1-demo-ln/c10-chuong-1">Chương 1</a></div>
]], docln_story)
assertEqual(1, #docln_page.chapters, "DocLN chapter count")
local docln_chap = assert(DocLN:parseChapter([[
  <div id="chapter-content"><p>Đoạn mở đầu LN.</p></div>
]], docln_page.chapters[1]))
assertContains(docln_chap.content, "Đoạn mở đầu LN", "DocLN chapter content")

local MeTruyenVN = require("truyenviet/sources/metruyenvn")
local mtv_json_raw = "mtv_search_fixture"
mock_json[mtv_json_raw] = {
    success = true,
    data = {
        {
            title = "Truyện <mark>Test</mark> &amp; 1",
            img = "https://metruyenvn.org/wp-content/uploads/mtv.webp",
            link = "https://metruyenvn.org/truyen/truyen-test-1/",
        },
    },
}
Http.postForm = function(_, url, fields)
    assertContains(url, "/wp-admin/admin-ajax.php", "MeTruyenVN search posts to admin-ajax")
    assertEqual("searchtax", fields.action, "MeTruyenVN searchtax action")
    assertEqual("test", fields.keyword, "MeTruyenVN search keyword")
    return mtv_json_raw
end
local mtv_search = MeTruyenVN:search("test")
assertEqual(1, #mtv_search, "MeTruyenVN search count")
assertEqual("Truyện Test & 1", mtv_search[1].title, "MeTruyenVN search title sanitized")
assertEqual("https://metruyenvn.org/wp-content/uploads/mtv.webp", mtv_search[1].cover_url, "MeTruyenVN search cover")
Http.postForm = nil

Http.get = function(_, url)
    if url:find("/chuong%-") then
        return [[<div class="view-chapter"><p>Nội dung Mê Truyện.</p></div><div class="margin-bottom-15px"></div>]]
    elseif url:find("/truyen/") then
        return [[
          <meta property="og:title" content="Truyện MTV - Mê Truyện">
          <strong>Tác giả:</strong><span>TacGiaMTV</span>
          <div class="desc-text">Mô tả MTV.</div>
          <a href="https://metruyenvn.org/chuong-1/">Chương 1</a>
        ]]
    end
    return [[
      <div class="comic-item-box">
        <a href="https://metruyenvn.org/truyen/truyen-mtv/" title="Truyện MTV">
          <img src="https://metruyenvn.org/c.webp">
        </a>
      </div>
      <a href="https://metruyenvn.org/truyen-hoan-thanh/page/2/">2</a>
    ]]
end
local mtv_list = MeTruyenVN:getCompleted(1)
assertEqual(1, #mtv_list.stories, "MeTruyenVN listing count")
assertEqual(2, mtv_list.total_pages, "MeTruyenVN total pages")
local mtv_page = MeTruyenVN:getStoryPage(mtv_list.stories[1], 1)
assertEqual(1, #mtv_page.chapters, "MeTruyenVN chapter count")
assertEqual("TacGiaMTV", mtv_page.story.details.author, "MeTruyenVN author")
local mtv_ch = MeTruyenVN:getChapter(mtv_page.chapters[1])
assertContains(mtv_ch, "Nội dung Mê Truyện", "MeTruyenVN chapter content")
Http.get = nil

local DualeoTruyenFull = require("truyenviet/sources/dualeotruyenfull")
local dltf_json_raw = "dltf_search_fixture"
mock_json[dltf_json_raw] = {
    {
        title = "Trúc <mark>Mã</mark>",
        url = "https://dualeotruyenfull.net/doc-truyen/truc-ma/",
        thumb = "https://dualeotruyenfull.net/thumb.webp",
    },
}
Http.getJson = function(_, url)
    assertContains(url, "/wp-json/initlise/v1/search?term=", "DualeoTruyenFull uses initlise JSON")
    return dltf_json_raw
end
local dltf_search = DualeoTruyenFull:search("ma")
assertEqual(1, #dltf_search, "DualeoTruyenFull search count")
assertEqual("Trúc Mã", dltf_search[1].title, "DualeoTruyenFull search title")
Http.getJson = nil

Http.get = function(_, url)
    if url:find("chuong%-1") then
        return [[<div id="chapter-content"><p>Chương 1 DLTF.</p></div><div class="uk-margin-top"></div>]]
    elseif url:find("/doc%-truyen/") then
        return [[
          <h1>Trúc Mã</h1>
          <div class="story-detail-info"><p>Giới thiệu DLTF.</p></div><div class="sep"></div>
          <a href="https://dualeotruyenfull.net/doc-truyen/truc-ma/chuong-2/">Chương 2</a>
          <a href="https://dualeotruyenfull.net/doc-truyen/truc-ma/chuong-1/">Chương 1</a>
        ]]
    end
    return [[
      <a class="uk-link-toggle" href="https://dualeotruyenfull.net/doc-truyen/truc-ma/"><img src="https://dualeotruyenfull.net/c.webp"><strong>Trúc Mã</strong></a>
    ]]
end
local dltf_list = DualeoTruyenFull:getCompleted(1)
assertEqual(1, #dltf_list.stories, "DualeoTruyenFull listing count")
local dltf_page = DualeoTruyenFull:getStoryPage(dltf_list.stories[1], 1)
assertEqual(2, #dltf_page.chapters, "DualeoTruyenFull chapter count")
assertEqual("Chương 1", dltf_page.chapters[1].title, "DualeoTruyenFull chapter ascending order")
local dltf_chap = DualeoTruyenFull:getChapter(dltf_page.chapters[1])
assertContains(dltf_chap, "Chương 1 DLTF", "DualeoTruyenFull chapter content")
Http.get = nil

local Mizzya = require("truyenviet/sources/mizzya")
Http.get = function(_, url)
    if url:find("/chap%-1/") then
        return [[<div class="entry-content"><p>Đoạn Mizzya.</p></div><footer class="entry-footer"></footer>]]
    elseif url:find("/truyen%-miz/") then
        return [[
          <h1 class="entry-title">Truyện Miz</h1>
          <div class="entry-content"><p>Mở đầu</p><a href="https://mizzya.wordpress.com/chap-1/">Chương 1</a></div><footer class="entry-footer"></footer>
        ]]
    end
    return [[<div class="entry-content"><a href="https://mizzya.wordpress.com/truyen-miz/">Truyện Miz</a></div><footer class="entry-footer"></footer>]]
end
local miz_list = Mizzya:getHome()
assertEqual(1, #miz_list.stories, "Mizzya listing count")
assertEqual(nil, miz_list.stories[1].cover_url, "Mizzya cover_url is nil rather than empty string")
local miz_found = Mizzya:search("truyen miz")
assertEqual(1, #miz_found, "Mizzya diacritic-insensitive search")
local miz_page = Mizzya:getStoryPage(miz_list.stories[1], 1)
assertEqual(1, #miz_page.chapters, "Mizzya chapter count")
local miz_details = Mizzya:getStoryDetails(miz_list.stories[1])
assertEqual("Truyện Miz", miz_details.title, "Mizzya getStoryDetails")
local miz_chap = Mizzya:getChapter(miz_page.chapters[1])
assertContains(miz_chap, "Đoạn Mizzya", "Mizzya chapter content")
Http.get = nil

-- Haccbl multi-page chapter list auto-aggregation (fixes 100+ chapter TOC truncation)
local hacc_multi_p1 = [[
  <div id="chapter-list">
    <div class="chapter-item"><a href="https://haccbl.xyz/manga/jinx-mingwa/chapter-3/"><h3>Chương 3</h3></a></div>
    <div class="chapter-item"><a href="https://haccbl.xyz/manga/jinx-mingwa/chapter-2/"><h3>Chương 2</h3></a></div>
  </div>
  <ul class="uk-pagination">
    <li><a href="https://haccbl.xyz/manga/jinx-mingwa/chapter/page/1/#chapter-list">1</a></li>
    <li><a href="https://haccbl.xyz/manga/jinx-mingwa/chapter/page/2/#chapter-list">2</a></li>
  </ul>
]]
local hacc_multi_p2 = [[
  <div id="chapter-list">
    <div class="chapter-item"><a href="https://haccbl.xyz/manga/jinx-mingwa/chapter-1/"><h3>Chương 1</h3></a></div>
  </div>
]]
local hacc_parsed_p1 = Haccbl:parseStoryPage(hacc_multi_p1, { title = "Jinx", url = "https://haccbl.xyz/manga/jinx-mingwa/" }, 1)
assertEqual(2, hacc_parsed_p1.total_pages, "Haccbl parseStoryPage detects chapter/page/N total_pages")
Http.get = function(_, url)
    if url:find("chapter/page/2/", 1, true) then
        return hacc_multi_p2
    end
    return hacc_multi_p1
end
local hacc_full_toc = Haccbl:getStoryPage({ title = "Jinx", url = "https://haccbl.xyz/manga/jinx-mingwa/" }, 1)
assertEqual(3, #hacc_full_toc.chapters, "Haccbl getStoryPage aggregates all chapter pages on page 1")
assertEqual(1, hacc_full_toc.total_pages, "Haccbl aggregated TOC sets total_pages to 1")
Http.get = nil

-- AzTruyen non-chuong chapter slugs and mid-slug trang-ID safety
local AzTruyen = require("truyenviet/sources/aztruyen")
local az_story = { title = "Baby Not Sugar", url = "https://aztruyen.top/kth-jjk-baby-not-sugar-286712803/" }
local az_page = AzTruyen:parseStoryPage([[
  <h1>Baby Not Sugar</h1>
  <div class="desc-text">Mô tả AzTruyen.</div>
  <a href="https://aztruyen.top/tinh-yeu-thuy-trang-370627771/" title="Thùy Trang">Thùy Trang</a>
  <a href="https://aztruyen.top/kth-jjk-baby-not-sugar-286712803/extra-1-1151989718/" title="Extra 1">Extra 1</a>
  <a href="https://aztruyen.top/kth-jjk-baby-not-sugar-286712803/van-an-1151956982/" title="Văn Án">Văn Án</a>
]], az_story, 1)
assertEqual(2, #az_page.chapters, "AzTruyen parses non-chuong chapter slugs")
assertEqual(1, az_page.total_pages, "AzTruyen ignores mid-slug -trang-<id> in total_pages")

-- TruyenC search /?s= and audio embed warning
local TruyenC = require("truyenviet/sources/truyenc")
local tc_search_url
Http.get = function(_, url)
    tc_search_url = url
    return [[<a href="https://truyenc.com/truyen/ma-15" title="Truyện Ma 15"><img src="https://i.truyenc.com/img/a.jpg"></a>]]
end
local tc_results = TruyenC:search("ma")
assertContains(tc_search_url, "/?s=ma", "TruyenC search uses /?s= query parameter")
assertEqual(1, #tc_results, "TruyenC search count")
Http.get = function()
    return [[<html><body><iframe src="https://www.youtube.com/embed/abc"></iframe></body></html>]]
end
local tc_audio_ch, tc_audio_err = TruyenC:getChapter({ title = "Audio 1", url = "https://truyenc.com/truyen/ma-15/chuong-1" })
assertEqual(nil, tc_audio_ch, "TruyenC audio-only chapter returns nil")
assertContains(tc_audio_err, "Audio / YouTube", "TruyenC explains YouTube/Audio embed")
Http.get = nil

local Dilib = require("truyenviet/sources/dilib")
local dilib_books = Dilib:parseListing([[
  <div id="woo-main">
    <a title="Sách Tâm Linh PDF" href="/sach-tam-linh-123.html" class="woocommerce-LoopProduct-link">
      <img src="/img/tam-linh.jpg">
      <div style="background:#1e1e1e;">2 quyển</div>
    </a>
  </div>
  <aside id="secondary">
    <a title="Sách Rác Sidebar PDF" href="/sach-rac-999.html" class="woocommerce-LoopProduct-link">
      <img src="/img/rac.jpg">
    </a>
  </aside>
]])
assertEqual(1, #dilib_books, "Dilib listing scopes to #woo-main")
assertEqual("Tâm Linh", dilib_books[1].title, "Dilib strips book prefix/suffix")
assertEqual("2 quyển", dilib_books[1].badge, "Dilib extracts volume badge")
assertEqual("https://dilib.vn/img/tam-linh.jpg", dilib_books[1].cover_url, "Dilib cover URL")
assertEqual(426, Dilib:parseTotalPages([[<nav class="woocommerce-pagination"><b>Trang </b>1/426 <a href="/thu-vien/page/2">2</a></nav>]], 1), "Dilib parses Trang 1/426 pagination")

local dilib_cat_url
Http.get = function(_, url)
    dilib_cat_url = url
    return [[<div id="woo-main"></div><nav class="woocommerce-pagination"><b>Trang </b>2/10</nav>]]
end
local dilib_cat_page2 = Dilib:getCategoryBooks({ name = "Thư Viện", url = "https://dilib.vn/thu-vien/" }, 2)
assertEqual("https://dilib.vn/thu-vien/page/2", dilib_cat_url, "Dilib uses /page/N URL")
assertEqual(10, dilib_cat_page2.total_pages, "Dilib category total_pages")

Http.get = function()
    return [[
      <h1>Tâm Linh</h1>
      <b>Tác giả :</b><a href="/a">Tác Giả Dilib</a>
      <b>Định dạng :</b> PDF, EPUB</p>
      <a href="/readbook/e31c23">Đọc Sách</a>
      <a href="/download/e31c23">Tải PDF</a>
      <a href="/download/epub/e31c23">Tải EPUB</a>
      <a href="/sach-cung-bo-tap-2-124.html">Tâm Linh - Tập 2</a>
      <fieldset id="tsh"></fieldset>
      <meta name="description" content="Mô tả Dilib">
    ]]
end
local dilib_detail = Dilib:getBookDetail(dilib_books[1])
assertEqual("Tác Giả Dilib", dilib_detail.author, "Dilib author")
assertEqual(true, dilib_detail.has_pdf, "Dilib has_pdf")
assertEqual(true, dilib_detail.has_epub, "Dilib has_epub")
assertEqual("https://dilib.vn/download/e31c23", dilib_detail.pdf_download_url, "Dilib PDF URL")
assertEqual("https://dilib.vn/download/epub/e31c23", dilib_detail.epub_download_url, "Dilib EPUB URL")
assertEqual(1, #dilib_detail.related_books, "Dilib related series books")

-- Dilib smart fallback: book with ONLY "Đọc Sách" (/readbook/...) and no /download/...
local dilib_readbook_only = Dilib:parseBookDetail([[
  <h1>Sách Chỉ Có Nút Đọc</h1>
  <a href="/readbook/only99">Đọc Sách</a>
]], { title = "Sách Chỉ Có Nút Đọc", url = "https://dilib.vn/sach-99.html" })
assertEqual(true, dilib_readbook_only.has_pdf, "Dilib captures /readbook/ as PDF source when /download/ is absent")
assertEqual(true, dilib_readbook_only.pdf_from_readbook, "Dilib marks pdf_from_readbook")
assertEqual("https://dilib.vn/readbook/only99", dilib_readbook_only.pdf_download_url, "Dilib pdf_download_url uses readbook link")

-- Dilib DMCA & Audio-only detection
local dilib_dmca = Dilib:parseBookDetail([[
  <h1>Sách Bản Quyền</h1>
  <button>Khiếu Nại Bản Quyền</button>
]], { title = "Sách Bản Quyền", url = "https://dilib.vn/dmca-1.html" })
assertEqual(true, dilib_dmca.is_dmca, "Dilib detects Khiếu Nại Bản Quyền takedown")
assertEqual("dmca", dilib_dmca.content_kind, "Dilib content_kind is dmca")

local dilib_radio = Dilib:parseBookDetail([[
  <h1>Kịch Truyền Thanh Demo</h1>
  <audio id="audio1" src="/img/audio/1-demo.mp3"></audio>
  <div id="mucluc0" onclick="jumptime('0'); mouse_click('0');" class="mucluc"><div>00:00:00 </div><div>Phần 1: Mở đầu</div></div>
]], { title = "Kịch Truyền Thanh Demo", url = "https://dilib.vn/radio-1.html" })
assertEqual("audio_only", dilib_radio.content_kind, "Dilib content_kind is audio_only")
assertEqual(1, #dilib_radio.audio_chapters, "Dilib parses modern div#muclucN audio chapters")
assertEqual("Phần 1: Mở đầu", dilib_radio.audio_chapters[1].name, "Dilib cleans timestamp from audio chapter name")
Http.get = nil

-- TruyenDich (truyendich.us)
local td_listing_html = [[
  <a href="/doc-truyen/tien-y" title="Tiên Y">
    <img src="https://img.example/tien-y.webp" alt="Ảnh bìa truyện Tiên Y">
  </a>
  <a href="/the-loai/tien-hiep">Tiên Hiệp</a>
  <a href="/danh-sach/truyen-full?page=5">5</a>
]]
local td_listing = TruyenDich:parseListing(td_listing_html, 1)
assertEqual(1, #td_listing.stories, "TruyenDich listing count")
assertEqual("https://truyendich.us/doc-truyen/tien-y", td_listing.stories[1].url, "TruyenDich default domain")
assertEqual(5, td_listing.total_pages, "TruyenDich total pages")
local td_search_url
Http.get = function(_, url)
    td_search_url = url
    return td_listing_html
end
local td_search = TruyenDich:search("tiên")
assertContains(td_search_url, "/tim-kiem?q=", "TruyenDich search uses ?q= parameter")
assertEqual(1, #td_search, "TruyenDich search count")
Http.get = nil

local td_page = TruyenDich:parseStoryPage([[
  <div class="desc-text">Mô tả Tiên Y.</div>
  <a itemprop="author">Tác Giả TD</a>
  <div>Danh sách chương</div>
  <a href="/doc-truyen/tien-y/chuong-1">Chương 1</a>
  <a href="/doc-truyen/tien-y/trang-3">3</a>
]], td_listing.stories[1], 1)
assertEqual(1, #td_page.chapters, "TruyenDich chapter count")
assertEqual(3, td_page.total_pages, "TruyenDich chapter pages")
assertEqual("Tác Giả TD", td_page.story.details.author, "TruyenDich author")
local td_chap = assert(TruyenDich:parseChapter([[
  <h1 itemProp="name">Chương 1: Mở đầu</h1>
  <div id="original-content-tab"><p>Nội dung Truyendich.</p></div></section>
]], td_page.chapters[1]))
assertContains(td_chap.content, "Nội dung Truyendich", "TruyenDich chapter content")

-- XTruyen (xtruyen.vn)
local XTruyen = require("truyenviet/sources/xtruyen")
local xtruyen_list_html = [[
  <div class="popular-item-wrap">
    <div class="popular-img">
      <a title="Thần Y Trở Lại" href="https://xtruyen.vn/truyen/than-y-tro-lai/">
        <img src="https://thumb.xtruyen.vn/than-y-tro-lai.webp" alt="Thần Y Trở Lại">
      </a>
    </div>
    <h5 class="widget-title"><a title="Thần Y Trở Lại" href="https://xtruyen.vn/truyen/than-y-tro-lai/">Thần Y Trở Lại (MP3)</a></h5>
  </div>
  <!-- <a href="https://xtruyen.vn/theloai/commented/">Bị ẩn</a> -->
  <a href="https://xtruyen.vn/theloai/do-thi/">Đô Thị</a>
  <a href="?m_orderby=latest&amp;page=8">8</a>
]]
local xtruyen_listing = XTruyen:parseListing(xtruyen_list_html, 1)
assertEqual(1, #xtruyen_listing.stories, "XTruyen listing count")
assertEqual("Thần Y Trở Lại", xtruyen_listing.stories[1].title, "XTruyen uses clean title attribute")
assertEqual("https://thumb.xtruyen.vn/than-y-tro-lai.webp", xtruyen_listing.stories[1].cover_url, "XTruyen cover URL")
assertEqual(1, #xtruyen_listing.genres, "XTruyen ignores commented genres")
assertEqual("Đô Thị", xtruyen_listing.genres[1].name, "XTruyen genre name")
assertEqual(8, xtruyen_listing.total_pages, "XTruyen listing pages")

local xtruyen_search_url
Http.get = function(_, url)
    xtruyen_search_url = url
    return xtruyen_list_html
end
local xtruyen_found = XTruyen:search("tiên")
assertContains(xtruyen_search_url, "post_type=wp-manga", "XTruyen search uses wp-manga post_type")
assertEqual(1, #xtruyen_found, "XTruyen search count")
Http.get = nil

local xtruyen_story_html = [[
  <div class="summary_image"><img src="https://img.xtruyen.vn/than-y-tro-lai.webp"></div>
  <div class="author-content"><a href="/tacgia/tieu-tinh/">Tiểu Tinh</a></div>
  <div class="genres-content"><!-- <a href="/theloai/sac/">Sắc</a> --><a href="/theloai/do-thi/">Đô Thị</a></div>
  <div class="description-summary"><div class="summary__content"><p>Giới thiệu XTruyện.</p></div></div>
  <script>var manga = {"manga_id":"1905049"};</script>
  <li class="has-child " data-value="1-to-200">
    <ul class="sub-chap-list">
      <li class="wp-manga-chapter"><a href="https://xtruyen.vn/truyen/than-y-tro-lai/chuong-1/">Chương 1</a></li>
    </ul>
  </li>
  <li class="has-child " data-value="201-to-400"></li>
]]
local xtruyen_story = { title = "Thần Y Trở Lại", url = "https://xtruyen.vn/truyen/than-y-tro-lai/" }
local xtruyen_page = XTruyen:parseStoryPage(xtruyen_story_html, xtruyen_story, 1)
assertEqual(1, #xtruyen_page.chapters, "XTruyen page 1 chapters")
assertEqual(2, xtruyen_page.total_pages, "XTruyen range groups become total_pages")
assertEqual("Tiểu Tinh", xtruyen_page.story.details.author, "XTruyen author")
assertEqual(1, #xtruyen_page.story.details.genres, "XTruyen skips commented detail genre")
assertEqual("Đô Thị", xtruyen_page.story.details.genres[1], "XTruyen detail genre")

local xtruyen_range_raw = "xtruyen_range_201_400"
mock_json[xtruyen_range_raw] = {
    { s = "chuong-201", n = "Chương 201", e = "Khởi đầu mới" },
    { s = "chuong-202", n = "Chương 202", e = "" },
}
Http.postForm = function(_, url, fields)
    assertContains(url, "/api/api-chapters.php", "XTruyen page 2 calls api-chapters.php")
    assertEqual("1905049", fields.manga_id, "XTruyen passes manga_id")
    assertEqual("201", fields.from, "XTruyen passes range from")
    assertEqual("400", fields.to, "XTruyen passes range to")
    return xtruyen_range_raw
end
local xtruyen_page2 = XTruyen:getStoryPage(xtruyen_story, 2)
assertEqual(2, #xtruyen_page2.chapters, "XTruyen page 2 chapter count")
assertEqual("Chương 201 - Khởi đầu mới", xtruyen_page2.chapters[1].title, "XTruyen joins chapter subtitle")
assertEqual("https://xtruyen.vn/truyen/than-y-tro-lai/chuong-202/", xtruyen_page2.chapters[2].url, "XTruyen builds chapter URL")
Http.postForm = nil

-- Short XTruyen story with lazy data-value="1-to-1m" range (empty inline list on page 1)
local xtruyen_short_raw = "xtruyen_range_1_1m"
mock_json[xtruyen_short_raw] = {
    { s = "chuong-1", n = "Chương 1:", e = "Mở màn" },
}
Http.get = function()
    return [[
      <script>var manga = {"manga_id":"2001"};</script>
      <li class="has-child " data-value="1-to-1m"><ul class="sub-chap-list"></ul></li>
    ]]
end
Http.postForm = function(_, _, fields)
    assertEqual("1", fields.from, "XTruyen 1-to-1m from")
    assertEqual("1m", fields.to, "XTruyen 1-to-1m to")
    return xtruyen_short_raw
end
local xtruyen_short_page = XTruyen:getStoryPage({ title = "Truyện Ngắn", url = "https://xtruyen.vn/truyen/ngan/" }, 1)
assertEqual(1, #xtruyen_short_page.chapters, "XTruyen loads lazy 1-to-1m range on page 1")
assertEqual("Chương 1 - Mở màn", xtruyen_short_page.chapters[1].title, "XTruyen trims colon before subtitle")
Http.get = nil
Http.postForm = nil

local seen_zlib_header
package.preload["ffi/zlib"] = function()
    return {
        zlib_uncompress = function(compressed)
            seen_zlib_header = string.format("%02x%02x%02x%02x", compressed:byte(1, 4))
            return "<p><p>Chương 1</p><br /><p>Nội dung XTruyện demo.</p></p>"
        end,
    }
end
local xtruyen_chap_payload = assert(XTruyen:parseChapter([[
  <h1 id="chapter-heading"><a href="/truyen/than-y-tro-lai/">THẦN Y TRỞ LẠI</a></h1>
  <h2>Chương 1</h2>
  <div id="chapter-reading-content" data-seo-preview="1"><p>Ngô...</p></div>
  <script>window.readingChapterConfig = { encodedData: "iWjbk_Rbk_NbbV0e9SVRU7fafIXKdyNlgv3TlLVU9im4Hfd--ORW0WR0csP7MKUbaaWlCYor8nPp6ppRawiY" };</script>
]], xtruyen_page.chapters[1]))
assertEqual("789cb329", seen_zlib_header, "XTruyen decodes custom alphabet into valid zlib stream")
assertContains(xtruyen_chap_payload.content, "Nội dung XTruyện demo.", "XTruyen chapter content decoded")

local ranked = SearchService:search("pham nhan", {
    {
        id = "one",
        name = "One",
        search = function()
            return {
                { source_id = "one", title = "Ngoại Truyện Phàm Nhân", url = "one" },
                { source_id = "one", title = "Phàm Nhân", url = "two" },
            }
        end,
    },
})
assertEqual("Phàm Nhân", ranked[1].title, "Search ranks exact title first")
assertEqual(8, #Util.stableHash("https://example.com/cover.webp"), "Cover cache hash")

assertEqual(13, #SourceRegistry:listAll(), "Registry includes all 13 active built-in sources")
assertEqual(nil, SourceRegistry:get("cbunu"), "Removed cbunu is not in registry")
assertEqual(nil, SourceRegistry:get("giatocvuongtai"), "Removed giatocvuongtai is not in registry")
assertEqual(nil, SourceRegistry:get("dtv"), "Removed dtv is not in registry")
assertEqual(nil, SourceRegistry:get("tve4u"), "Removed tve4u is not in registry")
assertEqual(true, SourceRegistry:isEnabled("dualeo"), "DuaLeo starts enabled")
assertEqual(true, SourceRegistry:setEnabled("dualeo", false), "DuaLeo can be disabled")
assertEqual(false, SourceRegistry:isEnabled("dualeo"), "DuaLeo disabled state")
assertEqual(12, #SourceRegistry:listEnabled(), "Disabled source leaves enabled list")
assertEqual(true, SourceRegistry:setEnabled("dualeo", true), "DuaLeo can be enabled again")
assertEqual(true, SourceRegistry:isEnabled("dualeo"), "DuaLeo enabled state restored")

custom_urls.truyenfull = "https://mirror.example"
assertEqual(
    custom_urls.truyenfull,
    SourceRegistry:get("truyenfull").base_url,
    "Registry applies custom base URL"
)
custom_urls.truyenfull = "https://truyenfull.today"
assertEqual(
    "https://truyenfull.live",
    SourceRegistry:get("truyenfull").base_url,
    "Registry auto-migrates retired truyenfull.today custom URL to truyenfull.live"
)
assertEqual(nil, custom_urls.truyenfull, "Registry clears retired truyenfull.today from storage")

custom_urls.dualeo = "https://dualeotruyenhn.com"
assertEqual(
    "https://dualeotruyenbg.com",
    SourceRegistry:get("dualeo").base_url,
    "Registry auto-migrates retired dualeotruyenhn.com custom URL to dualeotruyenbg.com"
)
assertEqual(nil, custom_urls.dualeo, "Registry clears retired dualeotruyenhn.com from storage")

print(string.format("Parser tests passed: %d assertions", tests_run))
