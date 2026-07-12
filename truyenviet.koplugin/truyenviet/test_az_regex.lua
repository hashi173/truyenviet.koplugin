local html = io.open('scratch_aztruyen_chap.html', 'r'):read('*a')
local content = html:match('<div class="chapter%-content"[^>]*>(.-)</div>')
if content then
    print("MATCHED: length = " .. #content)
    print("END CHARS: " .. content:sub(-50))
else
    print("NO MATCH")
end
