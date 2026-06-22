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
local MangaDex = require("truyenviet/sources/mangadex")
local Cbunu = require("truyenviet/sources/cbunu")
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
    url = "https://dualeotruyenbs.com/truyen-tranh/anh-duong",
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
    "https://dualeotruyenbs.com/uploads/2.webp",
    dualeo_payload.images[2].urls[1],
    "DuaLeo lazy image URL"
)

mock_json.mangadex_completed = {
    result = "ok",
    data = {},
    total = 0,
    limit = 20,
}
local captured_mangadex_url
Http.get = function(_, url)
    captured_mangadex_url = url
    return "mangadex_completed"
end
local mangadex_ok, mangadex_listing = pcall(function()
    return MangaDex:getCompleted(1)
end)
assertEqual(true, mangadex_ok, "MangaDex completed URL does not crash")
assertEqual(0, #mangadex_listing.stories, "MangaDex parses empty response")
assertContains(
    captured_mangadex_url,
    "status%5B%5D=completed",
    "MangaDex keeps encoded array params"
)

local cbunu_listing = Cbunu:parseListing([[
  <ul class="list-stories grid-6">
    <li><div class="story-item">
      <a href="https://cbunu.com/truyen-tranh/cnt-ga-deo-kinh-ky-la-phai-long-toi-291"
         title="[CNT] Gã đeo kính kỳ lạ phải lòng tôi">
        <img class="story-cover lazy_cover"
             src="https://cbunu.com/page/upload/story/190x247/cnt.png">
      </a>
      <h3 class="title-book">
        <a href="https://cbunu.com/truyen-tranh/cnt-ga-deo-kinh-ky-la-phai-long-toi-291"
           title="[CNT] Gã đeo kính kỳ lạ phải lòng tôi">[CNT] Gã đeo kính...</a>
      </h3>
      <a href="https://cbunu.com/truyen-tranh/cnt-ga-deo-kinh-ky-la-phai-long-toi-291-chap-7.html">Chương 7</a>
    </div></li>
  </ul>
  <a href="https://cbunu.com/the-loai/bl-.html">BL</a>
  <a href="https://cbunu.com/truyen-hoan-thanh/trang-4.html">4</a>
]], 1)
assertEqual(1, #cbunu_listing.stories, "Cbunu listing count")
assertEqual(
    "[CNT] Gã đeo kính kỳ lạ phải lòng tôi",
    cbunu_listing.stories[1].title,
    "Cbunu full title from attribute"
)
assertEqual(4, cbunu_listing.total_pages, "Cbunu listing pages")
assertEqual(1, #cbunu_listing.genres, "Cbunu listing genres")

local cbunu_page = Cbunu:parseStoryPage([[
  <div class="works-chapter-list">
    <div class="works-chapter-item row">
      <a href="https://cbunu.com/truyen-tranh/am-giu-linh-hon-139-chap-68.html">Chương 68</a>
    </div>
    <div class="works-chapter-item row">
      <a href="https://cbunu.com/truyen-tranh/am-giu-linh-hon-139-chap-67.html">Chương 67</a>
    </div>
  </div>
]], {
    title = "Ám Giữ Linh Hồn",
    url = "https://cbunu.com/truyen-tranh/am-giu-linh-hon-139",
})
assertEqual(2, #cbunu_page.chapters, "Cbunu chapter count")
assertEqual("Chương 68", cbunu_page.chapters[1].title, "Cbunu chapter title")

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

assertEqual(7, #SourceRegistry:listAll(), "Registry keeps seven built-in sources")
assertEqual(true, SourceRegistry:isEnabled("dualeo"), "DuaLeo starts enabled")
assertEqual(true, SourceRegistry:setEnabled("dualeo", false), "DuaLeo can be disabled")
assertEqual(false, SourceRegistry:isEnabled("dualeo"), "DuaLeo disabled state")
assertEqual(6, #SourceRegistry:listEnabled(), "Disabled source leaves enabled list")
assertEqual(true, SourceRegistry:setEnabled("dualeo", true), "DuaLeo can be enabled again")
assertEqual(true, SourceRegistry:isEnabled("dualeo"), "DuaLeo enabled state restored")

custom_urls.truyenfull = "https://mirror.example"
assertEqual(
    custom_urls.truyenfull,
    SourceRegistry:get("truyenfull").base_url,
    "Registry applies custom base URL"
)
custom_urls.truyenfull = nil
assertEqual(
    "https://truyenfull.today",
    SourceRegistry:get("truyenfull").base_url,
    "Registry restores default base URL"
)

print(string.format("Parser tests passed: %d assertions", tests_run))
