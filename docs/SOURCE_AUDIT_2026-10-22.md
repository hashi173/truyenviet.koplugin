# Source audit — 2026-10-22

This is an evidence log, not a claim that end-to-end downloads passed.  The
homepage checks were deliberately limited to one request per source group.

| Source ID | Kind | Adapter contract | Homepage result | Status / action |
|---|---|---|---|---|
| truyenfull | text | listing, search, details, chapters | Served current HTML | Needs KOReader flow test |
| truyenqq | comic | listing, search, details, chapters/images | HTTP 403 in test environment | BLOCKED; do not alter parser from a block page |
| dualeo | comic | listing, search, details, chapters/images | Redirected `dualeotruyenhn.com` to `dualeotruyenpet.com` | P1: base URL/custom-domain migration required |
| truyendich | text | listing, search, details, chapters | Redirected `.ai` to `.fit` | P1: base URL/custom-domain migration required |
| cbunu | comic | listing, search, details, chapters/images | HTTP 403 in test environment | BLOCKED |
| haccbl | comic | listing, search, details, chapters/images | Host unavailable to test client | BLOCKED |
| giatocvuongtai | text | listing, search, details, chapters | HTTP 403 in test environment | BLOCKED |
| docln | text | listing, search, details, chapters | Served current HTML | Needs KOReader flow test |
| tve4u | ebook | forums, authenticated attachment download | Served current HTML | Requires authenticated attachment test |
| dilib | ebook | categories, search, PDF/audio | Served current HTML | Needs direct-file validation test |
| mizzya | text | legacy chapter methods only | Homepage is unrelated blog, but the adapter's list page `/2007/05/15/list-truyện/` still returns 200 "List truyện" (re-checked 2026-11-12) | Kept enabled; needs KOReader flow test before any change |
| metruyenvn | text | listing, search, details, chapters | Served current HTML | Needs KOReader flow test |
| aztruyen | text | listing, search, details, chapters | Served current HTML | Needs KOReader flow test |
| dualeotruyenfull | text | listing, search, details, chapters | Served current HTML | Needs KOReader flow test |
| truyenc | text | listing, search, details, chapters | Served current HTML | Needs KOReader flow test |
| dtv | ebook | catalogue, detail, original EPUB/PDF links | HTTP 403 Cloudflare managed challenge (re-checked 2026-11-12) | BLOCKED; adapter + streaming downloader tested with fixtures only; `default_enabled = false` |

## Runtime evidence supplied by user

- KOReader 2026.03 loaded the plugin on Linux.
- `browser.lua:280` crashed on `InfoMessage:show()`; fixed to use
  `UIManager:show(...)`.
- DTV response was a Cloudflare challenge page (`403`), not catalogue HTML.
- The log showed stale hostnames for Dưa Leo and TruyenDich. Stored custom base
  URLs must be inspected before changing defaults, because registry settings
  override adapter defaults.

## Next verification order

1. Reproduce and regression-test the fixed UI notification in KOReader.
2. Add safe base-URL migration/fallback for Dưa Leo and TruyenDich without
   overwriting a user-selected custom URL.
3. Disable the stale Mizzya adapter by default after a fixture test preserves
   existing settings behaviour.
4. Use one small representative work per reachable source for search, details,
   chapter/image parsing and document opening; record each result separately.
5. Keep DTV as an ebook-catalog adapter. It needs accessible, legitimate page
   fixtures or a successful non-challenge request before its parser/download
   flow can be implemented or claimed as working.

## Re-audit — 2026-11-13 (`tools/source_audit.lua`, KOReader LuaJIT)

Full live run against each adapter's default URL (`AUDIT_QUERY="tiên"`, without
bypassing Cloudflare, CAPTCHA, or login walls). All reachable text/comic
reading flows and `dilib` streaming PDF verification were exercised directly in
KOReader's bundled LuaJIT environment.

| Source ID | Default | Listing | Search | Details | Chapters | Content / Ebook | Cover | Outcome |
|---|---|---|---|---|---|---|---|---|
| truyenfull | on | OK 27 | OK 27 | OK | OK 50/2tr | OK 3766 chars | OK webp 5378B | Working (`parseSearch` updated for `<picture><img class="cover">`) |
| truyenqq | on | OK 42 | OK 20 | OK | OK 99 | OK 6 imgs (jpg) | OK jpg 132834B | Working |
| haccbl | on | OK 24 | OK 3 | OK | OK 15 | OK 8 imgs (webp) | OK webp 80522B | Working (fixed `/wp-json/initlise/v1/search`, WP Rocket base64 `<script>` expansion, `.avif` proxy match) |
| docln | on | OK 42 | OK 24 | OK | OK 106 | OK 23520 chars | OK webp 37114B | Working (fixed `/tim-kiem?keywords=`) |
| metruyenvn | on | OK 20 | OK 7 | OK | OK 16 | OK 5353 chars | OK webp 14378B | Working (fixed AJAX `admin-ajax.php` `action=searchtax`) |
| dualeotruyenfull | on | OK 10 | OK 10 | OK | OK 5/3tr | OK 4612 chars | OK webp 13908B | Working (fixed `/wp-json/initlise/v1/search`) |
| mizzya | on | OK 149 | N/A | N/A | OK 29 | OK 10465 chars | none (`nil`) | Working (text-only; empty `cover_url` changed to `nil`) |
| aztruyen | on | OK 23 | EMPTY | OK | OK 92 | OK 16508 chars | OK jpg 18381B | Reading works; upstream `/tim-kiem/*` returns error page for search terms including its own homepage tag links |
| truyenc | on | OK 24 | EMPTY | OK | OK 50 | OK 21268 chars | FAIL (HTTP 525) | Reading works; no site search on origin, `i.truyenc.com` fails origin SSL handshake (525) |
| dilib | on | OK 29 | OK 10 | OK (pdf+audio) | N/A | OK PDF 27663KB | OK jpg 28607B | Working (`GDriveDownloader` refactored to stream via `.part` + `%PDF-` magic check) |
| tve4u | on | LOGIN | LOGIN | LOGIN | N/A | N/A | SKIP | Homepage returns HTTP 200; forum/attachment access requires user XenForo credentials |
| dtv | off | BLOCKED (403) | BLOCKED (403) | SKIP | N/A | N/A | none | Cloudflare managed challenge on public pages; kept `default_enabled = false` |
| giatocvuongtai | off | OK 20 | OK 50 | BLOCKED (403) | BLOCKED (403) | SKIP | OK jpg 29057B | `/stories/<slug>/` and `/api/public/story/<slug>.json` return HTTP 403 Forbidden; set `default_enabled = false` |
| dualeo | off | FAIL (reset) | FAIL (reset) | SKIP | SKIP | SKIP | - | `dualeotruyenpet.com` (and `dualeotruyenhn.com`) reset TLS connection; set `default_enabled = false`, custom URL preserved |
| truyendich | off | FAIL (reset) | FAIL (reset) | SKIP | SKIP | SKIP | - | `truyendich.fit` (and `truyendich.ai`) reset TLS connection; set `default_enabled = false`, custom URL preserved |
| cbunu | off | FAIL (DNS) | FAIL (DNS) | SKIP | SKIP | SKIP | - | `cbunu.com` fails DNS resolution; set `default_enabled = false`, custom URL preserved |

## Re-audit — 2026-11-21 (13 active sources; removed `cbunu`, `giatocvuongtai`, `dtv`, `tve4u`)

Full live run via `tools/source_audit.lua` (`AUDIT_QUERY="tiên"`, KOReader LuaJIT). Added automatic migration of retired default domains stored in `custom_url_<id>` (`truyenfull.today` -> `truyenfull.live`, `dualeotruyenhn.com` -> `dualeotruyenbg.com`, `truyendich.ai` -> `truyendich.us`) and curated `dilib.vn` categories to prioritize categories with active EPUB/PDF download links and filter out 100%-DMCA folders.

| Source ID | Default | URL | Listing | Search | Details | Chapters | Content / Ebook | Cover | Outcome |
|---|---|---|---|---|---|---|---|---|---|
| truyenfull | on | `https://truyenfull.live` | OK 27 | OK 27 | OK | OK 50/20tr | OK 7663 chars | OK webp 4160B | Working (auto-migrates stale `truyenfull.today` custom URL & saved story URLs) |
| truyenqq | on | `https://truyenqqko.com` | OK 42 | OK 20 | OK | OK 99 | OK 6 imgs (jpg) | OK jpg 132834B | Working |
| dualeo | on | `https://dualeotruyenbg.com` | OK 20 | OK 20 | OK | OK 17 | OK 34 imgs (webp) | OK webp 24402B | Working via canonical REST JSON API (auto-migrates stale `dualeotruyenhn.com` custom URL) |
| truyendich | on | `https://truyendich.us` | OK 32 | OK 24 | OK | OK 50/59tr | OK 11542 chars | OK webp 56146B | Working (`truyendich.us`, `/tim-kiem?q=`, hyphenated slug pagination) |
| haccbl | on | `https://haccbl.xyz` | OK 24 | OK 4 | OK | OK 108 (auto-merged 5 pages) | OK 8 imgs (webp) | OK webp 93910B | Working (multi-page `/chapter/page/N/` TOC auto-aggregation for 100+ chapter manga) |
| docln | on | `https://docln.sbs` | OK 42 | OK 24 | OK | OK 12 | OK 14640 chars | OK webp 24876B | Working (fixed prev/next chapter nav parsing) |
| dilib | on | `https://dilib.vn` | OK 24 (426tr) | OK 10 | OK (epub+pdf+readbook+audio+series) | N/A | OK EPUB 71KB + PDF 84KB | OK webp 18884B | Working (curated active categories, added EPUB download, smart `/readbook/` -> Google Drive PDF capture, `/page/N` pagination, in-place DMCA notice without losing list position) |
| mizzya | on | `https://mizzya.wordpress.com` | OK 149 | OK 2 | OK | OK 29 | OK 10465 chars | none (`nil`) | Working (diacritic-insensitive `search` and `getStoryDetails`) |
| metruyenvn | on | `https://metruyenvn.org` | OK 20 | OK 7 | OK | OK 16 | OK 5353 chars | OK webp 14378B | Working (deduplicated genres, single-fetch story page) |
| aztruyen | on | `https://aztruyen.top` | OK 24 | OK 19 | OK | OK 50..140 | OK 3280 chars | OK jpg 20680B | Working (supports non-`chuong` chapter slugs, fixed async headers & `-trang-<id>` pagination false match) |
| dualeotruyenfull | on | `https://dualeotruyenfull.net` | OK 10 | OK 10 | OK | OK 30/7tr | OK 4612 chars | OK webp 13908B | Working (eliminated 2 redundant HTTP requests per story page, fixed `uk-pagination` maxPage) |
| truyenc | on | `https://truyenc.com` | OK 24 (4tr) | OK 20 (`/?s=`) | OK | OK 51 | OK 21268 chars | FAIL (HTTP 525) | Working (fixed `/?s=` search, `?page=N` pagination, filtered duplicate `"Đọc truyện"` link, YouTube/Audio embed notice) |
| xtruyen | on | `https://xtruyen.vn` | OK 20 | OK 24 | OK | OK 10 (`1-to-1m`) / 100/17tr | OK 11168 chars | OK webp 2306B | Working (`ffi/zlib` decode + `/api/api-chapters.php` + EPUB 3 export verified) |

Removed sources per user request: `cbunu`, `giatocvuongtai`, `dtv`, `tve4u`.
