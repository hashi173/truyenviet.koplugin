local plugin_path = (... and (...):match("^(.*)[/\\]spec[/\\]")) or "."
package.path = table.concat({
    plugin_path .. "/truyenviet.koplugin/?.lua",
    plugin_path .. "/truyenviet.koplugin/?/init.lua",
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
    }
end

local TruyenFull = require("truyenviet/sources/truyenfull")
local TruyenQQ = require("truyenviet/sources/truyenqq")
local DuaLeo = require("truyenviet/sources/dualeo")
local SearchService = require("truyenviet/search_service")

describe("TruyenFull parser", function()
    it("parses search results", function()
        local html = [[
            <div data-image="https://img.example/text-cover.jpg"></div>
            <h3 class="truyen-title">
              <a href="https://truyenfull.today/demo/" title="Truyện Demo">Truyện Demo</a>
            </h3>
        ]]
        local stories = TruyenFull:parseSearch(html)
        assert.are.equal(1, #stories)
        assert.are.equal("Truyện Demo", stories[1].title)
        assert.are.equal("https://img.example/text-cover.jpg", stories[1].cover_url)

        local listing = TruyenFull:parseListing(html .. [[
            <a href="/the-loai/tien-hiep/">Tiên Hiệp</a>
            <a href="/danh-sach/truyen-full/trang-5/">5</a>
        ]], 1)
        assert.are.equal(5, listing.total_pages)
        assert.are.equal(1, #listing.genres)

        local details = TruyenFull:parseStoryDetails([[
            <div class="info">
              <a itemprop="author">Tác Giả Demo</a>
              <span class="text-success">Full</span>
            </div>
            <div class="col-xs-12 col-sm-8 desc">
              <div class="desc-text desc-text-full" itemprop="description">
                Mô tả truyện chữ.
              </div>
            </div>
        ]])
        assert.are.equal("Tác Giả Demo", details.author)
        assert.are.equal("Full", details.status)
        assert.is_truthy(details.description:find("Mô tả truyện chữ", 1, true))
    end)

    it("parses paginated chapters", function()
        local story = { title = "Truyện Demo", url = "https://truyenfull.today/demo/" }
        local html = [[
            <div class="col-xs-12" id="list-chapter">
              <a href="/demo/chuong-1/" title="Truyện Demo - Chương 1">
                <span>Chương </span>1
              </a>
            </div>
            <input class="metadata" id="truyen-id" value="1">
            <input id="total-page" type="hidden" value="3">
        ]]
        local page = TruyenFull:parseStoryPage(html, story, 1)
        assert.are.equal(1, #page.chapters)
        assert.are.equal(3, page.total_pages)
    end)

    it("extracts chapter content", function()
        local html = [[
            <h2><a class="chapter-title">Chương 1</a></h2>
            <div class="chapter-c" id="chapter-c"><div id="ads-chapter-top"></div>
              Nội dung<br/><br/>Đoạn hai
            </div><div id="ads-chapter-bottom"></div><hr class="chapter-end">
        ]]
        local payload = TruyenFull:parseChapter(html, { title = "Chương 1" })
        assert.is_truthy(payload.content:find("Nội dung", 1, true))
        assert.is_falsy(payload.content:find("ads-chapter-top", 1, true))
    end)
end)

describe("DuaLeo parser", function()
    it("parses search, chapters and lazy images", function()
        local search = [[
          <div class="li_truyen">
            <a href="/truyen-tranh/anh-duong">
              <img data-src="https://cover.example/anh-duong.webp" alt="Vết Tích Của Ánh Dương">
              <div class="name">Vết Tích Của Ánh Dương</div>
            </a>
          </div>
        ]]
        local stories = DuaLeo:parseSearch(search)
        assert.are.equal(1, #stories)
        assert.are.equal("https://cover.example/anh-duong.webp", stories[1].cover_url)

        local listing = DuaLeo:parseListing(search .. [[
          <a href="/the-loai/manga">Manga</a>
          <a href="/truyen-hoan-thanh?page=9">9</a>
        ]], 1)
        assert.are.equal(9, listing.total_pages)
        assert.are.equal(1, #listing.genres)

        local details = DuaLeo:parseStoryDetails([[
          <div class="txt">
            <p>Nhóm dịch: Vồn Vã Team</p>
            <p>Tình trang: Đang cập nhật</p>
          </div>
          <div class="story-detail-info"><p>Mô tả truyện Dưa Leo.</p></div>
        ]])
        assert.are.equal("Vồn Vã Team", details.translator)
        assert.are.equal("Đang cập nhật", details.status)
        assert.is_truthy(details.description:find("Dưa Leo", 1, true))

        local detail = [[
          <a href="/truyen-tranh/anh-duong/chapter-1">Đọc từ đầu</a>
          <div class="list-chapters">
            <a href="/truyen-tranh/anh-duong/chapter-2">Chapter 2</a>
            <a href="/truyen-tranh/anh-duong/chapter-1">Chapter 1</a>
          </div>
        ]]
        local page = DuaLeo:parseStoryPage(detail, {
            title = "Vết Tích Của Ánh Dương",
            url = "https://dualeotruyenbs.com/truyen-tranh/anh-duong",
        })
        assert.are.equal(2, #page.chapters)
        assert.are.equal("Chapter 2", page.chapters[1].title)

        local chapter = [[
          <title>Vết Tích Của Ánh Dương - Chapter 2 - DuaLeoTruyen</title>
          <div class="content_view_chap">
            <img src="https://img.example/1.webp">
            <img src="data:image/gif;base64,placeholder" data-img="/uploads/2.webp">
          </div>
          <div class="control_bottom_content"></div>
        ]]
        local payload = DuaLeo:parseChapter(chapter, page.chapters[1])
        assert.are.equal(2, #payload.images)
        assert.are.equal(
            "https://dualeotruyenbs.com/uploads/2.webp",
            payload.images[2].urls[1]
        )
    end)
end)

describe("Search ranking", function()
    it("normalizes Vietnamese titles and ranks exact matches first", function()
        local results = SearchService:search("pham nhan", {
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
        assert.are.equal("Phàm Nhân", results[1].title)
    end)
end)

describe("TruyenQQ parser", function()
    it("parses AJAX search results", function()
        local html = [[
          <li>
            <a href="/truyen-tranh/demo-123">
              <div class="search_info"><p class="name">Manga Demo</p></div>
            </a>
          </li>
        ]]
        local stories = TruyenQQ:parseSearch(html)
        assert.are.equal(1, #stories)
        assert.are.equal("Manga Demo", stories[1].title)
    end)

    it("parses completed and genre listings", function()
        local listing = TruyenQQ:parseListing([[
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
        assert.are.equal(1, #listing.stories)
        assert.are.equal(12, listing.total_pages)
        assert.are.equal(1, #listing.genres)

        local details = TruyenQQ:parseStoryDetails([[
          <li class="author row"><p>Tác giả</p><p><a>TruyenQQ</a></p></li>
          <li class="status row"><p>Tình trạng</p><p>Đang ra</p></li>
          <div class="story-detail-info detail-content">
            <p>Một anh hùng trở lại.</p>
          </div>
        ]])
        assert.are.equal("TruyenQQ", details.author)
        assert.are.equal("Đang ra", details.status)
        assert.is_truthy(details.description:find("anh hùng", 1, true))
    end)

    it("parses chapter links and page images", function()
        local story = { title = "Manga Demo", url = "https://truyenqqko.com/truyen-tranh/demo-123" }
        local detail = [[
          <a href="/truyen-tranh/other-456-chap-9">Truyện khác</a>
          <a href="/truyen-tranh/demo-123-chap-2">Chương 2</a>
          <a href="/truyen-tranh/demo-123-chap-1">Chương 1</a>
        ]]
        local page = TruyenQQ:parseStoryPage(detail, story)
        assert.are.equal(2, #page.chapters)

        local chapter = [[
          <h1 class="detail-title">Manga Demo - Chapter 2</h1>
          <div id="page_0" class="page-chapter">
            <img data-original="https://img.example/0.jpg" data-cdn="https://img2.example/0.jpg">
          </div>
        ]]
        local payload = TruyenQQ:parseChapter(chapter, page.chapters[1])
        assert.are.equal(1, #payload.images)
        assert.are.equal(2, #payload.images[1].urls)
    end)
end)
