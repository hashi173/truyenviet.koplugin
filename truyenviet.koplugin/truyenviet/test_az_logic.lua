local html = io.open('scratch_aztruyen_chap.html', 'r'):read('*a')

local CONTENT_PATTERNS = {
    '<div class="chapter%-content"[^>]*>(.-)</div>%s*</div>',
    '<div id="chapter%-content"[^>]*>(.-)</div>%s*</div>',
    '<div class="chapter%-content"[^>]*>(.-)</div>',
    '<div id="chapter%-content"[^>]*>(.-)</div>',
    '<div class="content%-chapter"[^>]*>(.-)</div>',
    '<div class="entry%-content"[^>]*>(.-)</div>',
    '<div class="reading%-content"[^>]*>(.-)</div>'
}

for _, pattern in ipairs(CONTENT_PATTERNS) do
    local content = html:match(pattern)
    if content then
        print("MATCHED PATTERN: " .. pattern)
        print("LENGTH: " .. #content)
        break
    end
end
