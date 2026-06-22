local html = [[
<div class="manga-item-grid">
    <div class="uk-panel uk-position-relative " >
        <div class="uk-overflow-hidden uk-border-rounded uk-position-relative scale-up-hover">
            <a href="https://haccbl.xyz/manga/alpha-thi-co-sao/">
                <img class="image-3-4 "
                     src="https://haccbl.xyz/wp-content/uploads/2026/06/xxlarge-2-1-200x267.avif" width="200" height="267">
            </a>
        </div>
        <h2 class="uk-h5 uk-margin-small-top uk-margin-remove-bottom uk-text-bold uk-text-capitalize min-height-45 max-2-line">
            <a class="uk-link-heading" href="https://haccbl.xyz/manga/alpha-thi-co-sao/">
                Alpha thì có sao                                    <span class="uk-text-success" uk-icon="icon: check"></span>
                            </a>
        </h2>
]]

for block in html:gmatch('class="manga%-item%-grid"(.-)</h2>') do
    local href = block:match('<a href="([^"]+)"')
    local img = block:match('<img[^>]-src="([^"]+)"')
    local title = block:match('<h2[^>]*>.-<a[^>]*>(.-)</a>') or block:match('<a class="uk%-link%-heading"[^>]*>([^<]+)')
    print(href, img, title)
end
