local root = "."
package.path = table.concat({ root .. "/truyenviet.koplugin/?.lua", root .. "/truyenviet.koplugin/?/init.lua", package.path }, ";")

package.preload["socket.url"] = function() return { absolute = function(base, href) if href:match("^https?://") then return href end return base:gsub("/+$", "") .. "/" .. href:gsub("^/+", "") end } end
package.preload["truyenviet/debugger"] = function() return { write = function() end } end
package.preload["util"] = function() return { htmlEntitiesToUtf8 = function(v) return v end, replaceAllInvalidChars = function(v) return v:gsub('[\\/:*?"<>|]', "_") end, urlEncode = function(v) return v:gsub(" ", "%%20") end } end
package.preload["truyenviet/http_client"] = function()
    return {
        downloadToFile = function(_, _, path)
            local file = assert(io.open(path, "wb"))
            assert(file:write("%PDF-1.7\nbody"))
            file:close()
            return path, nil, { ["content-type"] = "application/pdf" }, 200
        end,
    }
end

local Dilib = require("truyenviet/sources/dilib")
local Downloader = require("truyenviet/ebook_downloader")
local n = 0
local function equal(a, b, message) n = n + 1; if a ~= b then error(message .. ": expected " .. tostring(a) .. ", got " .. tostring(b)) end end

local pdf = "%PDF-1.7\nbody"
equal("pdf", assert(Downloader.validate(pdf, { ["content-type"] = "application/pdf" }, "demo.pdf")), "PDF signature")
local epub = "PK\003\004mimetypeapplication/epub+zip"
equal("epub", assert(Downloader.validate(epub, { ["content-type"] = "application/epub+zip" }, "demo.epub")), "EPUB signature")
local mobi = string.rep("\0", 60) .. "BOOKMOBI" .. "payload"
equal("mobi", assert(Downloader.validate(mobi, {}, "demo.mobi")), "MOBI signature")
equal("azw3", assert(Downloader.validate(mobi, {}, "demo.azw3")), "AZW3 signature")
local bad_mobi, bad_mobi_err = Downloader.validate("not-a-mobi-file", {}, "demo.mobi")
equal(nil, bad_mobi, "Rejects invalid MOBI file")
equal("Tệp MOBI/AZW3 không có chữ ký hợp lệ", bad_mobi_err, "Invalid MOBI error")
local zip_ok, zip_err = Downloader.validate("PK\003\004not-an-epub", { ["content-type"] = "application/epub+zip" }, "demo.epub")
equal(nil, zip_ok, "Rejects a generic ZIP presented as EPUB")
equal("Tệp EPUB không có cấu trúc hợp lệ", zip_err, "Invalid EPUB error")
local ok, err = Downloader.validate("<html>blocked</html>", { ["content-type"] = "text/html" }, "demo.pdf")
equal(nil, ok, "Rejects HTML download")
equal("Máy chủ trả về HTML thay vì tệp ebook", err, "HTML error")

-- GDriveDownloader tests: direct stream, confirm retry, and HTML rejection
local gdrive_mock_responses = {}
local http_mod = package.loaded["truyenviet/http_client"]
http_mod.downloadToFile = function(_, req_url, path)
    local next_resp = table.remove(gdrive_mock_responses, 1)
    if next_resp and next_resp.write then
        local f = assert(io.open(path, "wb"))
        assert(f:write(next_resp.write))
        f:close()
        return path, nil, next_resp.headers or {}, next_resp.code or 200
    end
    local f = assert(io.open(path, "wb"))
    assert(f:write("%PDF-1.7\nbody"))
    f:close()
    return path, nil, { ["content-type"] = "application/pdf" }, 200
end
local GDrive = require("truyenviet/gdrive_downloader")

local gdrive_ok_path = "/tmp/truyenviet-gdrive-ok.pdf"
os.remove(gdrive_ok_path)
os.remove(gdrive_ok_path .. ".part")
gdrive_mock_responses = {
    { write = "%PDF-1.7\nstreamed", headers = { ["content-type"] = "application/pdf" } },
}
equal(gdrive_ok_path, assert(GDrive:download("https://dilib.vn/download/e31c23", gdrive_ok_path)), "GDrive streams PDF")
assert(io.open(gdrive_ok_path, "rb")):close()
os.remove(gdrive_ok_path)

local gdrive_confirm_path = "/tmp/truyenviet-gdrive-confirm.pdf"
os.remove(gdrive_confirm_path)
os.remove(gdrive_confirm_path .. ".part")
local seen_confirm_urls = {}
local base_dl = http_mod.downloadToFile
http_mod.downloadToFile = function(self_arg, req_url, path, hdrs, opts)
    table.insert(seen_confirm_urls, req_url)
    return base_dl(self_arg, req_url, path, hdrs, opts)
end
gdrive_mock_responses = {
    {
        write = "<html><body>download_warning <form action=\"https://drive.google.com/uc?export=download&confirm=tok9&id=fid1\"></form></body></html>",
        headers = { ["content-type"] = "text/html" },
    },
    { write = "%PDF-1.6\nconfirmed", headers = { ["content-type"] = "application/pdf" } },
}
equal(gdrive_confirm_path, assert(GDrive:download("https://drive.google.com/file/d/fid1/view", gdrive_confirm_path)), "GDrive confirm retry saves PDF")
equal("https://drive.google.com/uc?export=download&id=fid1", seen_confirm_urls[1], "GDrive normalizes /file/d/ URL")
equal("https://drive.google.com/uc?export=download&confirm=tok9&id=fid1", seen_confirm_urls[2], "GDrive follows confirm token")
os.remove(gdrive_confirm_path)

local gdrive_readbook_path = "/tmp/truyenviet-gdrive-readbook.pdf"
os.remove(gdrive_readbook_path)
os.remove(gdrive_readbook_path .. ".part")
seen_confirm_urls = {}
gdrive_mock_responses = {
    {
        write = [[<!DOCTYPE html><html><head><meta property="og:url" content="https://drive.google.com/file/d/rbFile99/view"></head><body>Viewer</body></html>]],
        headers = { ["content-type"] = "text/html; charset=utf-8" },
    },
    {
        write = [[<html><body><form id="download-form" action="https://drive.usercontent.google.com/download" method="get"><input type="hidden" name="id" value="rbFile99"><input type="hidden" name="export" value="download"><input type="hidden" name="confirm" value="t"></form></body></html>]],
        headers = { ["content-type"] = "text/html; charset=utf-8" },
    },
    { write = "%PDF-1.7\nfrom-readbook", headers = { ["content-type"] = "application/pdf" } },
}
equal(gdrive_readbook_path, assert(GDrive:download("https://dilib.vn/readbook/only99", gdrive_readbook_path)), "GDrive resolves Dilib /readbook/ viewer HTML + virus scan form to PDF")
equal("https://dilib.vn/readbook/only99", seen_confirm_urls[1], "GDrive attempt 1 hits readbook URL")
equal("https://drive.google.com/uc?export=download&id=rbFile99", seen_confirm_urls[2], "GDrive attempt 2 converts viewer file ID to uc download URL")
equal("https://drive.usercontent.google.com/download?id=rbFile99&export=download&confirm=t", seen_confirm_urls[3], "GDrive attempt 3 serializes hidden form inputs")
os.remove(gdrive_readbook_path)

local gdrive_bad_path = "/tmp/truyenviet-gdrive-bad.pdf"
os.remove(gdrive_bad_path)
os.remove(gdrive_bad_path .. ".part")
gdrive_mock_responses = {
    { write = string.rep("<html>quota exceeded</html>", 40), headers = { ["content-type"] = "text/html; charset=utf-8" } },
}
local bad_res, bad_err = GDrive:download("https://dilib.vn/download/bad", gdrive_bad_path)
equal(nil, bad_res, "GDrive rejects HTML response even when >500 bytes")
equal("Máy chủ trả về HTML thay vì tệp hợp lệ", bad_err, "GDrive HTML rejection message")
equal(nil, io.open(gdrive_bad_path, "rb"), "GDrive does not leave corrupt target")
equal(nil, io.open(gdrive_bad_path .. ".part", "rb"), "GDrive cleans .part on failure")
http_mod.downloadToFile = base_dl

local output_path = "/tmp/truyenviet-dtv-test.pdf"
os.remove(output_path)
os.remove(output_path .. ".part")
local saved, download_err, downloaded_format = Downloader.download(
    Dilib,
    { url = "https://files.example/demo.pdf", filename = "demo.pdf", format = "pdf" },
    output_path
)
equal(output_path, saved, download_err or "Streams ebook to destination")
equal("pdf", downloaded_format, "Reports downloaded format")
assert(io.open(output_path, "rb"), "Creates final ebook file")
os.remove(output_path)
print(string.format("Ebook & GDrive downloader tests passed: %d assertions", n))
